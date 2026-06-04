#!/bin/bash
set -euo pipefail

timestamp_file="$HOME/.cache/.workflow/cpu_conky.timestamp"
lock_file="${XDG_RUNTIME_DIR:-/tmp}/cpu-conky-check.lock"
config_file="$HOME/.config/conky/cpu.config"

exec 9>"$lock_file"
if ! flock -n 9; then
    echo "CPU conky check is already running."
    exit 0
fi

if pgrep -u "$(id -u)" -f "conky --config=${config_file}" >/dev/null; then
    exit 0
fi

# Check if the timestamp file exists and has valid data
if [[ ! -f "$timestamp_file" ]]; then
    echo "CPU timestamp file '$timestamp_file' not found. Starting process with DISPLAY=${DISPLAY:-}"
    "$HOME/bin/conky/cpu_conky_exec.sh"
    exit 0
fi

CPU_CONKY_TIMESTAMP=$(tail -1 "$timestamp_file")

# Check if the timestamp value is valid
if ! [[ $CPU_CONKY_TIMESTAMP =~ ^[0-9]+$ ]]; then
    echo "Invalid CPU timestamp value in file. Starting process with DISPLAY=${DISPLAY:-}"
    "$HOME/bin/conky/cpu_conky_exec.sh"
    exit 0
fi

CUR=$(date +%s)

SECONDS_SINCE_LAST_REPORT=$((CUR - CPU_CONKY_TIMESTAMP))

# Compare the seconds with the threshold value
if ((SECONDS_SINCE_LAST_REPORT > 5)); then
    echo "CPU check finds no timestamp within the limit. Starting process with DISPLAY=${DISPLAY:-}"
    "$HOME/bin/conky/cpu_conky_exec.sh"
fi
