#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import socket
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent


def resolve_default_inventory() -> Path:
    return Path(os.environ.get("LAN_INVENTORY", str(SCRIPT_DIR / "inventory" / "lan.yml")))


def load_inventory(inventory_path: Path) -> dict:
    if shutil.which("ansible-inventory") is None:
        print("error: missing required command: ansible-inventory", file=sys.stderr)
        raise SystemExit(1)

    result = subprocess.run(
        ["ansible-inventory", "-i", str(inventory_path), "--list"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        print(result.stderr.strip(), file=sys.stderr)
        raise SystemExit(result.returncode)
    return json.loads(result.stdout)


def collect_hosts(inventory: dict) -> list[dict]:
    hostvars = inventory.get("_meta", {}).get("hostvars", {})
    group_map: dict[str, set[str]] = {host: set() for host in hostvars}

    for group_name, group_data in inventory.items():
        if group_name == "_meta" or not isinstance(group_data, dict):
            continue
        for host_name in group_data.get("hosts", []):
            group_map.setdefault(host_name, set()).add(group_name)

    hosts = []
    for host_name in sorted(hostvars):
        vars_for_host = hostvars.get(host_name, {})
        hosts.append(
            {
                "host": host_name,
                "address": vars_for_host.get("ansible_host", host_name),
                "groups": sorted(group_map.get(host_name, set())),
            }
        )
    return hosts


def probe_tcp(address: str, port: int, timeout: float) -> str:
    try:
        with socket.create_connection((address, port), timeout=timeout):
            return "online"
    except OSError:
        return "offline"


def render_table(hosts: list[dict]) -> None:
    headers = ("HOST", "ADDRESS", "GROUPS", "STATUS")
    rows = [
        (
            host["host"],
            host["address"],
            ",".join(host["groups"]) or "-",
            host["status"],
        )
        for host in hosts
    ]

    widths = [len(header) for header in headers]
    for row in rows:
        for idx, value in enumerate(row):
            widths[idx] = max(widths[idx], len(value))

    fmt = "  ".join(f"{{:{width}}}" for width in widths)
    print(fmt.format(*headers))
    print(fmt.format(*["-" * width for width in widths]))
    for row in rows:
        print(fmt.format(*row))


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize LAN inventory and reachability.")
    parser.add_argument(
        "--inventory",
        default=str(resolve_default_inventory()),
        help="Path to the Ansible inventory file.",
    )
    parser.add_argument(
        "--format",
        choices=("table", "json"),
        default="table",
        help="Output format.",
    )
    parser.add_argument(
        "--probe-mode",
        choices=("tcp", "none"),
        default="tcp",
        help="Probe strategy for reachability.",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=22,
        help="TCP port used for reachability checks.",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=1.5,
        help="Probe timeout in seconds.",
    )
    args = parser.parse_args()

    inventory_path = Path(args.inventory).expanduser().resolve()
    inventory = load_inventory(inventory_path)
    hosts = collect_hosts(inventory)

    for host in hosts:
        if args.probe_mode == "none":
            host["status"] = "unknown"
        else:
            host["status"] = probe_tcp(host["address"], args.port, args.timeout)

    if args.format == "json":
        print(json.dumps(hosts, indent=2, sort_keys=True))
        return 0

    render_table(hosts)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
