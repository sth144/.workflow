#!/usr/bin/env python3
"""Sample per-process disk writes using fs_usage (requires root).

Runs fs_usage for a brief window, aggregates write bytes per process,
and writes a JSON summary to /tmp/workflow-diskio.json.

Designed to run every 5 minutes via a root LaunchDaemon.
"""

import json
import os
import re
import signal
import subprocess
import time
from collections import defaultdict
from datetime import datetime, timezone

OUTPUT_FILE = "/tmp/workflow-diskio.json"
SAMPLE_SECONDS = 3


def sample_diskio() -> list[dict]:
    """Run fs_usage for SAMPLE_SECONDS and aggregate per-process writes."""
    proc = subprocess.Popen(
        ["fs_usage", "-f", "diskio", "-w"],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
    )
    time.sleep(SAMPLE_SECONDS)
    proc.send_signal(signal.SIGINT)
    try:
        output, _ = proc.communicate(timeout=5)
    except subprocess.TimeoutExpired:
        proc.kill()
        output, _ = proc.communicate()

    by_process: dict[str, int] = defaultdict(int)

    wr_re = re.compile(r"WrData.*?B=0x([0-9a-fA-F]+)")
    proc_re = re.compile(r"\s+(\S+)\.(\d+)\s*$")

    for line in output.splitlines():
        wr_match = wr_re.search(line)
        if not wr_match:
            continue
        nbytes = int(wr_match.group(1), 16)

        proc_match = proc_re.search(line)
        if proc_match:
            name = proc_match.group(1)
            pid = proc_match.group(2)
            by_process[f"{name} [{pid}]"] += nbytes

    ranked = sorted(by_process.items(), key=lambda x: x[1], reverse=True)
    return [{"name": n, "write_bytes": b} for n, b in ranked[:10]]


def main() -> None:
    writers = sample_diskio()
    summary = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "writers": writers,
    }
    tmp = OUTPUT_FILE + ".tmp"
    with open(tmp, "w") as f:
        json.dump(summary, f)
    os.replace(tmp, OUTPUT_FILE)


if __name__ == "__main__":
    main()
