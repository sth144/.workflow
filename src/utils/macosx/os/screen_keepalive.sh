#!/bin/bash
# screen_keepalive.sh — Keep the MacBook display awake for a given duration.
# Uses macOS's built-in caffeinate(8).
#
# Usage:
#   screen_keepalive.sh [SECONDS]
#   screen_keepalive.sh 3600      # 1 hour
#   screen_keepalive.sh           # defaults to 1 hour

set -euo pipefail

DEFAULT_SECONDS=3600

seconds="${1:-$DEFAULT_SECONDS}"

if ! [[ "$seconds" =~ ^[0-9]+$ ]]; then
		echo "Usage: $(basename "$0") [SECONDS]" >&2
		echo "  SECONDS must be a positive integer (default: $DEFAULT_SECONDS)" >&2
		exit 1
fi

if ! command -v caffeinate &>/dev/null; then
		echo "Error: caffeinate not found (this script requires macOS)" >&2
		exit 1
fi

hours=$(( seconds / 3600 ))
mins=$(( (seconds % 3600) / 60 ))
secs=$(( seconds % 60 ))

start_epoch=$(date +%s)
end_epoch=$(( start_epoch + seconds ))

printf "Keeping display awake for %02d:%02d:%02d (%d seconds)\n" "$hours" "$mins" "$secs" "$seconds"
printf "Started %s, ends %s\n" \
		"$(date -r "$start_epoch" '+%H:%M:%S')" "$(date -r "$end_epoch" '+%H:%M:%S')"
printf "Press Ctrl+C to stop early.\n"

# -d = prevent display from sleeping
# -t = timeout in seconds
caffeinate -d -t "$seconds" &
caffeinate_pid=$!

# Ctrl+C (or any exit) must take caffeinate down with us — backgrounding it
# means it would otherwise outlive the script and keep the display awake.
countdown_active=0
cleanup() {
		kill "$caffeinate_pid" 2>/dev/null || true
		# Close off the in-place countdown line so the shell prompt starts clean.
		[ "$countdown_active" -eq 1 ] && printf '\n'
		return 0
}
trap cleanup EXIT

# Live countdown, repainted in place. Only on a TTY — redirected to a file or
# a log, \r spam is worse than useless, so there we just wait quietly.
if [ -t 1 ]; then
		countdown_active=1
		while kill -0 "$caffeinate_pid" 2>/dev/null; do
				remaining=$(( end_epoch - $(date +%s) ))
				if [ "$remaining" -lt 0 ]; then
						remaining=0
				fi
				# \r + clear-to-EOL keeps this to a single line for the whole run.
				printf '\r\033[K  %02d:%02d:%02d remaining' \
						"$(( remaining / 3600 ))" "$(( (remaining % 3600) / 60 ))" "$(( remaining % 60 ))"
				sleep 1
		done
fi

wait "$caffeinate_pid" 2>/dev/null || true
