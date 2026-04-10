#!/usr/bin/env python3
"""host_relay.py — HTTP relay for executing registered commands on the macOS host.

Listens on 127.0.0.1:7899 so Docker containers can reach it via
host.docker.internal. Only commands pre-registered in
~/.config/host_relay/commands.json are allowed.
"""

import json
import logging
import os
import subprocess
import sys
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Optional

HOST = "127.0.0.1"
PORT = 7899
DEFAULT_TIMEOUT = 30
MAX_TIMEOUT = 300

REGISTRY_PATH = Path.home() / ".config" / "host_relay" / "commands.json"
TOKEN_PATH = Path.home() / ".config" / ".env.HOST_RELAY_TOKEN"
LOG_PATH = Path.home() / ".cache" / "host_relay.log"


def setup_logging() -> logging.Logger:
    """Configure logging to file and stderr."""
    LOG_PATH.parent.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("host-relay")
    logger.setLevel(logging.INFO)

    fmt = logging.Formatter("%(asctime)s %(levelname)s %(message)s")

    fh = logging.FileHandler(LOG_PATH)
    fh.setFormatter(fmt)
    logger.addHandler(fh)

    sh = logging.StreamHandler()
    sh.setFormatter(fmt)
    logger.addHandler(sh)

    return logger


log = setup_logging()


def load_token() -> Optional[str]:
    """Read optional auth token from env file."""
    try:
        return TOKEN_PATH.read_text().strip()
    except FileNotFoundError:
        return None


def load_registry() -> dict:
    """Load command registry, expanding $HOME in command paths."""
    try:
        raw = REGISTRY_PATH.read_text()
        registry = json.loads(raw)
        home = str(Path.home())
        for key, entry in registry.items():
            if isinstance(entry.get("command"), str):
                entry["command"] = entry["command"].replace("$HOME", home)
        return registry
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        log.error("Failed to load registry %s: %s", REGISTRY_PATH, exc)
        return {}


class RelayHandler(BaseHTTPRequestHandler):
    """Handle /exec and /health endpoints."""

    def log_message(self, format: str, *args: object) -> None:
        """Route default HTTP log messages through our logger."""
        log.info(format, *args)

    def _send_json(self, code: int, data: dict) -> None:
        body = json.dumps(data).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _check_auth(self) -> bool:
        """Validate bearer token if one is configured."""
        token = load_token()
        if token is None:
            return True
        auth = self.headers.get("Authorization", "")
        if auth == f"Bearer {token}":
            return True
        self._send_json(401, {"error": "unauthorized"})
        return False

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self) -> None:
        if self.path != "/exec":
            self._send_json(404, {"error": "not found"})
            return

        if not self._check_auth():
            return

        # Read request body
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            self._send_json(400, {"error": "empty body"})
            return

        try:
            body = json.loads(self.rfile.read(length))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "invalid JSON"})
            return

        command_key = body.get("command")
        args = body.get("args", [])
        stdin_data = body.get("stdin")
        timeout = min(body.get("timeout", DEFAULT_TIMEOUT), MAX_TIMEOUT)

        if not command_key or not isinstance(command_key, str):
            self._send_json(400, {"error": "missing or invalid 'command' key"})
            return

        if not isinstance(args, list):
            self._send_json(400, {"error": "'args' must be a list"})
            return

        # Reload registry on each request (no restart needed to add commands)
        registry = load_registry()
        entry = registry.get(command_key)
        if entry is None:
            log.warning("Unknown command key: %s", command_key)
            self._send_json(404, {"error": f"unknown command: {command_key}"})
            return

        cmd_path = entry["command"]
        prepend = entry.get("prepend_args", [])
        cmd = [cmd_path] + prepend + [str(a) for a in args]

        log.info("Executing: %s", cmd)
        try:
            result = subprocess.run(
                cmd,
                input=stdin_data,
                capture_output=True,
                text=True,
                timeout=timeout,
                shell=False,
            )
            self._send_json(200, {
                "stdout": result.stdout,
                "stderr": result.stderr,
                "exit_code": result.returncode,
            })
        except subprocess.TimeoutExpired:
            log.error("Command timed out after %ds: %s", timeout, cmd)
            self._send_json(504, {"error": "command timed out", "timeout": timeout})
        except FileNotFoundError:
            log.error("Command not found: %s", cmd_path)
            self._send_json(500, {"error": f"command not found: {cmd_path}"})
        except Exception as exc:
            log.error("Command failed: %s", exc)
            self._send_json(500, {"error": str(exc)})


def main() -> None:
    log.info("Starting host-relay on %s:%d", HOST, PORT)
    log.info("Registry: %s", REGISTRY_PATH)

    token = load_token()
    if token:
        log.info("Token auth enabled")
    else:
        log.info("Token auth disabled (no token file)")

    server = HTTPServer((HOST, PORT), RelayHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log.info("Shutting down")
        server.shutdown()


if __name__ == "__main__":
    main()
