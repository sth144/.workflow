#!/bin/bash
set -euo pipefail

config_file="${HOME}/.config/conky/cpu.config"
log_file="${HOME}/.cache/.workflow/cpu-conky.log"
pid_file="${XDG_RUNTIME_DIR:-/var/run/user/$(id -u)}/conky-cpu.pid"

mkdir -p "$(dirname "$log_file")" "$(dirname "$pid_file")"

if [ -z "${DISPLAY:-}" ];
then
    echo "cpu_conky_exec finds DISPLAY empty, setting to :0"
    export DISPLAY=:1
fi

existing_pid=$(pgrep -u "$(id -u)" -f "conky --config=${config_file}" || true)
existing_pid=${existing_pid%%$'\n'*}
if [ -n "$existing_pid" ]; then
    echo "CPU conky already running as PID ${existing_pid}"
    echo "$existing_pid" > "$pid_file"
    exit 0
fi

nohup conky --config="$config_file" > "$log_file" 2>&1 &
echo "$!" > "$pid_file"
