#!/usr/bin/env python3
"""Log system and per-process resource usage as JSON lines.

System-level metrics (CPU, memory, disk space, disk I/O) are derived from
node_exporter at localhost:9100. Per-process top-N comes from ps.

Appends one JSON line per invocation. Prunes entries older than 24 hours.
Designed to run every 5 minutes via launchd.
"""

import json
import re
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timedelta, timezone
from pathlib import Path

LOG_DIR = Path.home() / ".cache" / ".workflow" / "resource-monitor"
LOG_FILE = LOG_DIR / "resources.jsonl"
MAX_AGE = timedelta(hours=24)
TOP_N = 5
EXPORTER_URL = "http://localhost:9100/metrics"
SCRAPE_INTERVAL = 1.0  # seconds between two scrapes for rate computation


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

def _short_name(path: str) -> str:
    """Extract the executable basename from a full path."""
    return path.rsplit("/", 1)[-1]


def top_cpu(n: int) -> list[dict]:
    """Top N processes by CPU usage."""
    result = subprocess.run(
        ["ps", "-eo", "pid,pcpu,comm", "-r"],
        capture_output=True, text=True,
    )
    entries = []
    for line in result.stdout.strip().splitlines()[1 : n + 1]:
        parts = line.split(None, 2)
        if len(parts) >= 3:
            entries.append({
                "pid": int(parts[0]),
                "pct": float(parts[1]),
                "name": _short_name(parts[2]),
            })
    return entries


def top_mem(n: int) -> list[dict]:
    """Top N processes by memory usage."""
    result = subprocess.run(
        ["ps", "-eo", "pid,pmem,rss,comm", "-m"],
        capture_output=True, text=True,
    )
    entries = []
    for line in result.stdout.strip().splitlines()[1 : n + 1]:
        parts = line.split(None, 3)
        if len(parts) >= 4:
            entries.append({
                "pid": int(parts[0]),
                "pct": float(parts[1]),
                "rss_kb": int(parts[2]),
                "name": _short_name(parts[3]),
            })
    return entries


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
    }

    with open(LOG_FILE, "a") as f:
        f.write(json.dumps(snapshot) + "\n")

    prune_old_entries(LOG_FILE, MAX_AGE)


if __name__ == "__main__":
    main()
