#!/usr/bin/env python3
import argparse
import json
import re
import socket
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from ipaddress import ip_address
from pathlib import Path
from typing import Any


@dataclass
class NetworkContext:
    target_cidr: str
    interface: str
    local_ip: str
    gateway_ip: str


def run_command(command: list[str], timeout: int = 30) -> tuple[int, str, str]:
    result = subprocess.run(
        command,
        check=False,
        capture_output=True,
        text=True,
        timeout=timeout,
    )
    return result.returncode, result.stdout or "", result.stderr or ""


def _candidate_default_context() -> NetworkContext | None:
    code, stdout, _stderr = run_command(["ip", "route", "show"], timeout=10)
    if code != 0:
        return None

    default_iface = ""
    gateway_ip = ""
    local_ip = ""
    target_cidr = ""
    for line in stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("default "):
            gateway_match = re.search(r"\bvia\s+(\S+)", line)
            iface_match = re.search(r"\bdev\s+(\S+)", line)
            if gateway_match:
                gateway_ip = gateway_match.group(1)
            if iface_match:
                default_iface = iface_match.group(1)
            continue
        if default_iface and f" dev {default_iface} " in f" {line} ":
            if " scope link " not in f" {line} ":
                continue
            network = line.split()[0]
            src_match = re.search(r"\bsrc\s+(\S+)", line)
            if src_match:
                local_ip = src_match.group(1)
            if "/" in network and "." in network:
                target_cidr = network
                break

    if not (default_iface and target_cidr):
        return None
    return NetworkContext(
        target_cidr=target_cidr,
        interface=default_iface,
        local_ip=local_ip,
        gateway_ip=gateway_ip,
    )


def detect_context(target_override: str | None = None) -> NetworkContext | None:
    detected = _candidate_default_context()
    if detected is None and not target_override:
        return None
    if detected is None:
        return NetworkContext(
            target_cidr=target_override or "",
            interface="",
            local_ip="",
            gateway_ip="",
        )
    if target_override:
        detected.target_cidr = target_override
    return detected


def parse_arp_scan(stdout: str) -> list[dict[str, str]]:
    hosts: list[dict[str, str]] = []
    for line in stdout.splitlines():
        parts = line.strip().split("\t")
        if len(parts) < 2:
            continue
        ip_value = parts[0].strip()
        mac_value = parts[1].strip()
        if not re.match(r"^\d+\.\d+\.\d+\.\d+$", ip_value):
            continue
        vendor = parts[2].strip() if len(parts) > 2 else ""
        hosts.append(
            {
                "ip": ip_value,
                "mac": mac_value,
                "vendor": vendor,
                "status": "up",
                "source": "arp-scan",
            }
        )
    return hosts


def parse_nmap_xml(stdout: str) -> list[dict[str, str]]:
    hosts: list[dict[str, str]] = []
    if not stdout.strip():
        return hosts
    root = ET.fromstring(stdout)
    for host in root.findall(".//host"):
        status_el = host.find("status")
        status = status_el.get("state", "unknown") if status_el is not None else "unknown"
        if status != "up":
            continue
        ip_value = ""
        mac_value = ""
        vendor = ""
        hostname = ""
        for address in host.findall("address"):
            addr = address.get("addr", "").strip()
            addrtype = address.get("addrtype", "").strip()
            if addrtype == "ipv4":
                ip_value = addr
            elif addrtype == "mac":
                mac_value = addr
                vendor = address.get("vendor", "").strip()
        hostname_el = host.find("./hostnames/hostname")
        if hostname_el is not None:
            hostname = hostname_el.get("name", "").strip()
        if not ip_value:
            continue
        hosts.append(
            {
                "ip": ip_value,
                "mac": mac_value,
                "vendor": vendor,
                "hostname": hostname,
                "status": "up",
                "source": "nmap",
            }
        )
    return hosts


def parse_ip_neigh(stdout: str) -> list[dict[str, str]]:
    hosts: list[dict[str, str]] = []
    for line in stdout.splitlines():
        line = line.strip()
        if not line or ":" in line.split()[0]:
            continue
        ip_match = re.match(r"^(\d+\.\d+\.\d+\.\d+)\s+", line)
        if not ip_match:
            continue
        ip_value = ip_match.group(1)
        mac_match = re.search(r"\blladdr\s+([0-9a-f:]+)", line, re.IGNORECASE)
        state = line.split()[-1]
        if state.upper() in {"INCOMPLETE", "FAILED"}:
            continue
        hosts.append(
            {
                "ip": ip_value,
                "mac": mac_match.group(1) if mac_match else "",
                "status": state.lower(),
                "source": "ip-neigh",
            }
        )
    return hosts


def resolve_hostname(ip_value: str) -> str:
    code, stdout, _stderr = run_command(["avahi-resolve", "-a", ip_value], timeout=10)
    if code == 0:
        parts = stdout.strip().split(maxsplit=1)
        if len(parts) == 2:
            hostname = parts[1].strip().rstrip(".")
            if hostname:
                return hostname

    try:
        host, _aliases, _ips = socket.gethostbyaddr(ip_value)
        return host.strip().rstrip(".")
    except Exception:
        return ""


def gather_hosts(context: NetworkContext, host_limit: int) -> dict[str, Any]:
    tools: dict[str, str] = {}
    host_map: dict[str, dict[str, str]] = {}

    arp_scan_bin = Path("/usr/sbin/arp-scan")
    nmap_bin = Path("/usr/bin/nmap")

    if arp_scan_bin.exists():
        command = [
            str(arp_scan_bin),
            "--localnet",
            "--interface",
            context.interface,
        ]
        code, stdout, stderr = run_command(command, timeout=45)
        if code == 0:
            tools["arp-scan"] = "ok"
            for host in parse_arp_scan(stdout):
                host_map[host["ip"]] = {**host_map.get(host["ip"], {}), **host}
        else:
            tools["arp-scan"] = f"error: {stderr.strip() or 'exit code ' + str(code)}"
    else:
        tools["arp-scan"] = "missing"

    if nmap_bin.exists():
        command = [str(nmap_bin), "-sn", context.target_cidr, "-oX", "-"]
        code, stdout, stderr = run_command(command, timeout=90)
        if code == 0:
            tools["nmap"] = "ok"
            for host in parse_nmap_xml(stdout):
                host_map[host["ip"]] = {**host_map.get(host["ip"], {}), **host}
        else:
            tools["nmap"] = f"error: {stderr.strip() or 'exit code ' + str(code)}"
    else:
        tools["nmap"] = "missing"

    code, stdout, stderr = run_command(["ip", "neigh", "show"], timeout=10)
    if code == 0:
        tools["ip-neigh"] = "ok"
        for host in parse_ip_neigh(stdout):
            if host["ip"].startswith("192.168.") or host["ip"] == context.gateway_ip:
                host_map[host["ip"]] = {**host_map.get(host["ip"], {}), **host}
    else:
        tools["ip-neigh"] = f"error: {stderr.strip() or 'exit code ' + str(code)}"

    hosts = list(host_map.values())
    if context.local_ip:
        host_map.setdefault(
            context.local_ip,
            {
                "ip": context.local_ip,
                "mac": "",
                "status": "local",
                "source": "route",
                "hostname": socket.gethostname().strip(),
                "role": "local",
            },
        )
    hosts = list(host_map.values())
    for host in hosts:
        if not host.get("hostname"):
            host["hostname"] = resolve_hostname(host["ip"])
        if host["ip"] == context.local_ip:
            host["role"] = "local"
        elif host["ip"] == context.gateway_ip:
            host["role"] = "gateway"
        else:
            host["role"] = "host"

    hosts.sort(key=lambda item: int(ip_address(item["ip"])))
    return {
        "tools": tools,
        "hosts": hosts[:host_limit],
    }


def _node_id(index: int) -> str:
    return f"h{index}"


def build_plantuml(context: NetworkContext, hosts: list[dict[str, str]]) -> str:
    lines = [
        "@startuml",
        "left to right direction",
        "skinparam shadowing false",
        "skinparam linetype ortho",
        f'cloud "LAN\\n{context.target_cidr}" as lan',
    ]

    for index, host in enumerate(hosts, start=1):
        node_id = _node_id(index)
        role = host.get("role", "host")
        title = host.get("hostname") or host["ip"]
        if role == "gateway" and title == "_gateway":
            title = "Gateway"
        details = [host["ip"]]
        if host.get("vendor"):
            details.append(host["vendor"])
        elif host.get("mac"):
            details.append(host["mac"])
        label = "\\n".join([title, *details])
        if role == "gateway":
            lines.append(f'rectangle "{label}" as {node_id} <<gateway>>')
        elif role == "local":
            lines.append(f'node "{label}" as {node_id} <<local>>')
        else:
            lines.append(f'rectangle "{label}" as {node_id} <<host>>')
        lines.append(f"lan -- {node_id}")

    lines.append("@enduml")
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--target", default="")
    parser.add_argument("--host-limit", type=int, default=24)
    args = parser.parse_args()

    context = detect_context(args.target.strip() or None)
    if context is None:
        print(
            json.dumps(
                {
                    "status": "error",
                    "error": "Unable to determine primary network route.",
                }
            )
        )
        return 1

    data = gather_hosts(context, max(1, args.host_limit))
    plantuml = build_plantuml(context, data["hosts"])
    print(
        json.dumps(
            {
                "status": "ok",
                "target": context.target_cidr,
                "interface": context.interface,
                "local_ip": context.local_ip,
                "gateway_ip": context.gateway_ip,
                "tools": data["tools"],
                "hosts": data["hosts"],
                "plantuml": plantuml,
            }
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
