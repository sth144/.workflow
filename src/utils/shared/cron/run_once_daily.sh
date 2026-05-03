#!/bin/bash
# run_once_daily.sh — Ensures a command runs at most once per calendar day.
# Usage: run_once_daily.sh <command> [args...]
#
# Creates a lock file in /tmp/ keyed on the command basename and today's date.
# First invocation runs the command; subsequent invocations exit 0 silently.
# Lock files naturally expire when /tmp/ is cleaned or the date rolls over.

set -euo pipefail

if [ $# -eq 0 ]; then
	echo "Usage: run_once_daily.sh <command> [args...]" >&2
	exit 1
fi

# Derive lock name from the last path component that isn't "bash" or "sh"
LOCK_NAME=""
for arg in "$@"; do
	base="$(basename "$arg")"
	case "$base" in
		bash|sh|zsh) continue ;;
		-*) continue ;;
		*) LOCK_NAME="$base"; break ;;
	esac
done

if [ -z "$LOCK_NAME" ]; then
	LOCK_NAME="$(basename "$1")"
fi

LOCK="/tmp/.run_once.${LOCK_NAME}.$(date +%Y%m%d)"

if [ -f "$LOCK" ]; then
	exit 0
fi

touch "$LOCK"
exec "$@"
