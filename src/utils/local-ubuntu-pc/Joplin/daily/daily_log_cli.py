#!/usr/bin/env python3
import datetime as dt
import json
import os
import subprocess
import sys
import time
from typing import Sequence
from zoneinfo import ZoneInfo

import requests

import daily_log as base


def _profile_args() -> list[str]:
    profile = os.getenv("JOPLIN_CLI_PROFILE", "").strip()
    if not profile:
        return []
    return ["--profile", profile]


def _joplin_bin() -> str:
    return os.getenv("JOPLIN_CLI_BIN", "joplin-cli").strip() or "joplin-cli"


def _run_cli_command(args: Sequence[str]) -> str:
    cmd = [_joplin_bin(), *_profile_args(), *args]
    result = subprocess.run(
        cmd,
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        detail = stderr or stdout or f"exit code {result.returncode}"
        raise RuntimeError(f"joplin-cli command failed ({' '.join(args)}): {detail}")
    return (result.stdout or "").strip()


def _get_cli_value(key: str, default: str = "") -> str:
    override_name = f"JOPLIN_CLI_{key.upper().replace('.', '_')}"
    override = os.getenv(override_name, "").strip()
    if override:
        return override

    try:
        value = _run_cli_command(["config", key]).strip()
    except RuntimeError:
        return default

    if not value:
        return default

    first_line = value.splitlines()[0].strip()
    if "=" in first_line:
        first_line = first_line.split("=", 1)[-1].strip()
    return first_line or default


def _ping(url: str) -> bool:
    try:
        resp = requests.get(f"{url.rstrip('/')}/ping", timeout=3)
        return resp.ok and "Joplin" in resp.text
    except requests.RequestException:
        return False


class JoplinCliServer:
    def __init__(self) -> None:
        self.process: subprocess.Popen[str] | None = None
        self.port = int(_get_cli_value("api.port", "41184"))
        self.token = os.getenv("JOPLIN_TOKEN", "").strip() or _get_cli_value("api.token")
        self.base_url = f"http://127.0.0.1:{self.port}"

        if not self.token:
            raise RuntimeError(
                "Unable to determine Joplin API token. Set JOPLIN_TOKEN or configure api.token in joplin-cli."
            )

    def __enter__(self) -> "JoplinCliServer":
        if _ping(self.base_url):
            return self

        cmd = [_joplin_bin(), *_profile_args(), "server", "start"]
        self.process = subprocess.Popen(
            cmd,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            text=True,
        )

        for _ in range(20):
            if _ping(self.base_url):
                return self
            if self.process.poll() is not None:
                raise RuntimeError(
                    "joplin-cli server exited before the API became reachable. "
                    "Run `joplin-cli server start` manually to inspect the error."
                )
            time.sleep(1)

        raise RuntimeError(
            f"Timed out waiting for joplin-cli API at {self.base_url}. "
            "Ensure the Joplin CLI profile is initialized and supports `server start`."
        )

    def __exit__(self, exc_type, exc, tb) -> None:
        if self.process is None:
            return
        if self.process.poll() is not None:
            return
        self.process.terminate()
        try:
            self.process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=5)


def main() -> int:
    cfg = base.load_config()
    with JoplinCliServer() as server:
        cfg.joplin_base_url = server.base_url
        cfg.joplin_token = server.token

        state = base.load_state(cfg)
        start, end, today = base.day_window(cfg)
        window_label = f"{start.isoformat()} -> {end.isoformat()} ({cfg.timezone})"

        headlines = base.fetch_headlines(cfg)
        trello_cards = base.fetch_trello_cards(cfg)
        events = base.fetch_google_events(cfg, start, end)
        ha_snapshot = base.fetch_home_assistant_snapshot(cfg)
        ha_history = (
            base.fetch_home_assistant_history(cfg, start)
            if cfg.ha_include_history
            else []
        )
        git_summary = base.fetch_git_summary(cfg, start, end)
        docker_rows = base.fetch_docker_snapshot(cfg)

        generated_md = base.build_generated_md(
            cfg,
            today,
            window_label,
            headlines,
            trello_cards,
            events,
            ha_snapshot,
            ha_history,
            git_summary,
            docker_rows,
        )

        folder_id = base.ensure_notebook(cfg)
        title = dt.datetime.now(ZoneInfo(cfg.timezone)).strftime(cfg.note_title_fmt)
        note_id, action = base.create_or_update_note(cfg, folder_id, title, generated_md)

        state["last_run"] = dt.datetime.now(dt.UTC).isoformat()
        base.save_state(cfg, state)

        print(
            json.dumps(
                {
                    "status": "ok",
                    "action": action,
                    "note_id": note_id,
                    "title": title,
                    "joplin_mode": "cli_server",
                    "joplin_base_url": server.base_url,
                }
            )
        )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
    except Exception as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        raise
