#!/bin/bash
# openisland-wrapper.sh — Platform-safe wrapper for OpenIslandHooks
# Silently exits on Linux/Docker where the binary doesn't exist.

HOOK_BIN="$HOME/Library/Application Support/OpenIsland/bin/OpenIslandHooks"

if [ -x "$HOOK_BIN" ]; then
		exec "$HOOK_BIN" "$@"
fi

exit 0
