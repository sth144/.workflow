#!/usr/bin/env python3
"""Log system and per-process resource usage as JSON lines.

System-level metrics (CPU, memory, disk space, disk I/O) are derived from
node_exporter at localhost:9100. Per-process top-N comes from ps.

Appends one JSON line per invocation. Prunes entries older than 24 hours.
Designed to run every 5 minutes via launchd.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

LOG_DIR = Path.home() / ".cache" / ".workflow" / "resource-monitor"
LOG_FILE = LOG_DIR / "resources.jsonl"
MAX_AGE = timedelta(hours=24)
TOP_N = 5
EXPORTER_URL = "http://localhost:9100/metrics"
SCRAPE_INTERVAL = 1.0  # seconds between two scrapes for rate computation
DISKIO_FILE = Path("/tmp/workflow-diskio.json")

# Directories to track for growth — chosen for fast du (<1s each).
# Skip large trees like ~/Library/Containers (~40 GB, ~30s to du).
_TRACKED_DIRS = [
    "~/Library/Caches",
    "~/.cache",
    "~/.npm",
    "~/tmp",
    "~/Data",
    "~/Movies/Desktop Archive",
]


# ---------------------------------------------------------------------------
# node_exporter helpers
# ---------------------------------------------------------------------------

def _scrape(url: str) -> str:
    """Fetch the metrics page from node_exporter."""
    with urllib.request.urlopen(url, timeout=5) as resp:
        return resp.read().decode()


def _sum_metric(text: str, prefix: str, label_filter: str | None = None) -> float:
    """Sum all values for a metric, optionally filtering by a label substring.

    Example: _sum_metric(text, "node_cpu_seconds_total", 'mode="idle"')
    """
    total = 0.0
    for line in text.splitlines():
        if not line.startswith(prefix):
            continue
        if label_filter and label_filter not in line:
            continue
        parts = line.split()
        if len(parts) >= 2:
            total += float(parts[1])
    return total


def _find_metric(text: str, prefix: str, label_filter: str | None = None) -> float:
    """Find a single metric value, optionally filtered by label."""
    for line in text.splitlines():
        if not line.startswith(prefix):
            continue
        if label_filter and label_filter not in line:
            continue
        parts = line.split()
        if len(parts) >= 2:
            return float(parts[1])
    return 0.0


# ---------------------------------------------------------------------------
# System metrics from node_exporter
# ---------------------------------------------------------------------------

def _cpu_pct(text1: str, text2: str) -> dict:
    """Compute CPU user/sys/idle % from two scrapes of node_cpu_seconds_total."""
    modes = ("user", "system", "idle")
    t1 = {m: _sum_metric(text1, "node_cpu_seconds_total", f'mode="{m}"') for m in modes}
    t2 = {m: _sum_metric(text2, "node_cpu_seconds_total", f'mode="{m}"') for m in modes}

    total_delta = sum(t2[m] - t1[m] for m in modes)
    if total_delta <= 0:
        return {"cpu_user": 0, "cpu_sys": 0, "cpu_idle": 100}

    return {
        "cpu_user": round((t2["user"] - t1["user"]) / total_delta * 100),
        "cpu_sys": round((t2["system"] - t1["system"]) / total_delta * 100),
        "cpu_idle": round((t2["idle"] - t1["idle"]) / total_delta * 100),
    }


def _memory(text: str) -> dict:
    """Extract memory stats from node_exporter gauges."""
    total = _find_metric(text, "node_memory_total_bytes")
    active = _find_metric(text, "node_memory_active_bytes")
    wired = _find_metric(text, "node_memory_wired_bytes")
    used = active + wired
    total_gb = total / (1024 ** 3)
    used_gb = used / (1024 ** 3)
    pct = (used_gb / total_gb * 100) if total_gb else 0.0
    return {"total_gb": round(total_gb, 1), "used_gb": round(used_gb, 1), "pct": round(pct, 1)}


def _filesystem(text: str) -> dict:
    """Extract root filesystem space from node_exporter gauges."""
    size = _find_metric(text, "node_filesystem_size_bytes", 'mountpoint="/"')
    avail = _find_metric(text, "node_filesystem_avail_bytes", 'mountpoint="/"')
    used = size - avail
    total_gb = size / (1024 ** 3)
    used_gb = used / (1024 ** 3)
    pct = (used_gb / total_gb * 100) if total_gb else 0.0
    return {"total_gb": round(total_gb, 1), "used_gb": round(used_gb, 1), "pct": round(pct, 1)}


def _disk_io(text1: str, text2: str, interval: float) -> dict:
    """Compute disk read/write throughput from two scrapes."""
    read1 = _sum_metric(text1, "node_disk_read_bytes_total")
    read2 = _sum_metric(text2, "node_disk_read_bytes_total")
    write1 = _sum_metric(text1, "node_disk_written_bytes_total")
    write2 = _sum_metric(text2, "node_disk_written_bytes_total")
    read_mb_s = (read2 - read1) / interval / (1024 * 1024)
    write_mb_s = (write2 - write1) / interval / (1024 * 1024)
    return {
        "read_mb_s": round(read_mb_s, 2),
        "write_mb_s": round(write_mb_s, 2),
        "mb_s": round(read_mb_s + write_mb_s, 2),
    }


def system_stats() -> dict:
    """Collect system-level stats from node_exporter (two scrapes for rates)."""
    text1 = _scrape(EXPORTER_URL)
    time.sleep(SCRAPE_INTERVAL)
    text2 = _scrape(EXPORTER_URL)

    cpu = _cpu_pct(text1, text2)
    mem = _memory(text2)
    fs = _filesystem(text2)
    disk = _disk_io(text1, text2, SCRAPE_INTERVAL)

    return {
        "sys": {**cpu, **mem, "disk": fs},
        "disk": disk,
    }


# ---------------------------------------------------------------------------
# Per-process metrics from ps
# ---------------------------------------------------------------------------

_INTERPRETER_RE = re.compile(
    r"^(node|deno|bun|python\d?(?:\.\d+)*|ruby|perl|bash|sh|zsh|fish|java)$",
    re.IGNORECASE,
)


def _process_label(cmdline: str) -> str:
    """Derive a descriptive label from a full command line.

    For interpreters, appends the script/module name for context::

        /usr/bin/python3 /path/to/logger.py  ->  python3:logger
        /usr/local/bin/node ./server.js      ->  node:server
        python3 -m pytest                    ->  python3:pytest

    For other executables, returns the basename::

        /Applications/Safari.app/.../Safari  ->  Safari
    """
    parts = cmdline.split()
    if not parts:
        return "?"
    exe = parts[0].rsplit("/", 1)[-1]

    if _INTERPRETER_RE.match(exe) and len(parts) > 1:
        # -c/-e run inline code, not a script — no useful name to extract
        if parts[1] in ("-c", "-e"):
            return exe
        for arg in parts[1:]:
            if arg.startswith("-"):
                continue
            script = arg.rsplit("/", 1)[-1]
            dot = script.rfind(".")
            if dot > 0:
                script = script[:dot]
            if len(script) > 25:
                script = script[:22] + "..."
            return f"{exe}:{script}"

    # Handle macOS .app paths with spaces (e.g. "Google Chrome.app/...")
    # by finding the .app name in the raw command line
    if ".app/" in cmdline:
        match = re.search(r"/([^/]+)\.app/", cmdline)
        if match:
            return match.group(1)

    return exe


def top_cpu(n: int) -> list[dict]:
    """Top N processes by CPU usage."""
    result = subprocess.run(
        ["ps", "-eo", "pid,pcpu,command", "-r"],
        capture_output=True, text=True,
    )
    entries = []
    for line in result.stdout.strip().splitlines()[1 : n + 1]:
        parts = line.split(None, 2)
        if len(parts) >= 3:
            pid = int(parts[0])
            entries.append({
                "pid": pid,
                "pct": float(parts[1]),
                "name": f"{_process_label(parts[2])} [{pid}]",
            })
    return entries


def top_mem(n: int) -> list[dict]:
    """Top N processes by memory usage."""
    result = subprocess.run(
        ["ps", "-eo", "pid,pmem,rss,command", "-m"],
        capture_output=True, text=True,
    )
    entries = []
    for line in result.stdout.strip().splitlines()[1 : n + 1]:
        parts = line.split(None, 3)
        if len(parts) >= 4:
            pid = int(parts[0])
            entries.append({
                "pid": pid,
                "pct": float(parts[1]),
                "rss_kb": int(parts[2]),
                "name": f"{_process_label(parts[3])} [{pid}]",
            })
    return entries


# ---------------------------------------------------------------------------
# Disk blame — directory sizes, open writers (lsof), fs_usage summary
# ---------------------------------------------------------------------------

def dir_sizes() -> list[dict]:
    """Snapshot sizes of key directories (~2s total)."""
    home = str(Path.home())
    paths = [os.path.expanduser(d) for d in _TRACKED_DIRS]
    existing = [p for p in paths if os.path.isdir(p)]
    if not existing:
        return []
    result = subprocess.run(
        ["du", "-s", "-k"] + existing,
        capture_output=True, text=True, timeout=30,
    )
    entries = []
    for line in result.stdout.strip().splitlines():
        parts = line.split("\t", 1)
        if len(parts) != 2:
            continue
        try:
            size_kb = int(parts[0])
        except ValueError:
            continue
        path = parts[1]
        if path.startswith(home):
            path = "~" + path[len(home):]
        entries.append({"path": path, "kb": size_kb})
    return entries


def open_writers() -> list[dict]:
    """Processes with the most regular files open for writing (~1s)."""
    result = subprocess.run(
        ["lsof", "-wnP", "-u", str(os.getuid())],
        capture_output=True, text=True, timeout=15,
    )
    counts: dict[str, int] = defaultdict(int)
    for line in result.stdout.splitlines()[1:]:
        parts = line.split()
        if len(parts) < 5:
            continue
        fd_col, type_col = parts[3], parts[4]
        if type_col == "REG" and (fd_col.endswith("w") or fd_col.endswith("u")):
            cmd, pid = parts[0], parts[1]
            counts[f"{cmd} [{pid}]"] += 1

    ranked = sorted(counts.items(), key=lambda x: x[1], reverse=True)
    return [{"name": n, "open_writes": c} for n, c in ranked[:TOP_N]]


def read_diskio() -> list[dict]:
    """Read per-process write bytes from the privileged fs_usage sampler."""
    if not DISKIO_FILE.exists():
        return []
    try:
        data = json.loads(DISKIO_FILE.read_text())
        return data.get("writers", [])
    except (json.JSONDecodeError, KeyError):
        return []


# ---------------------------------------------------------------------------
# Log management
# ---------------------------------------------------------------------------

def prune_old_entries(log_file: Path, max_age: timedelta) -> None:
    """Remove log entries older than max_age."""
    if not log_file.exists():
        return
    cutoff = datetime.now(timezone.utc) - max_age
    kept = []
    for line in log_file.read_text().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
            ts = datetime.fromisoformat(entry["ts"])
            if ts >= cutoff:
                kept.append(line)
        except (json.JSONDecodeError, KeyError, ValueError):
            continue
    log_file.write_text("\n".join(kept) + "\n" if kept else "")


def main() -> None:
    LOG_DIR.mkdir(parents=True, exist_ok=True)

    try:
        sys_data = system_stats()
    except Exception as e:
        print(f"node_exporter scrape failed: {e}", file=sys.stderr)
        sys.exit(1)

    snapshot = {
        "ts": datetime.now(timezone.utc).isoformat(),
        **sys_data,
        "cpu": top_cpu(TOP_N),
        "mem": top_mem(TOP_N),
        "dirs": dir_sizes(),
        "lsof": open_writers(),
        "writers": read_diskio(),
    }

    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(snapshot) + "\n")

    prune_old_entries(LOG_FILE, MAX_AGE)


if __name__ == "__main__":
    main()
