#!/bin/bash
set -euo pipefail

pkill -u "$(id -u)" -x conky || true

sleep 1

cd "$HOME/.config/conky"
mkdir -p "$HOME/.cache/.workflow"
"$HOME/bin/conky/cpu_conky_exec.sh"
sleep 1

for config in gpu memory disk net sys trello tail; do
    conky --config="$HOME/.config/conky/${config}.config" \
        > "$HOME/.cache/.workflow/${config}-conky.log" 2>&1 &
done
