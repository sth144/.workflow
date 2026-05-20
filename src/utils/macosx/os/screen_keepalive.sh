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

printf "Keeping display awake for %02d:%02d:%02d (%d seconds)\n" "$hours" "$mins" "$secs" "$seconds"
printf "Press Ctrl+C to stop early.\n"

# -d = prevent display from sleeping
# -t = timeout in seconds
caffeinate -d -t "$seconds"
