#!/bin/bash
# openisland-wrapper.sh — Platform-safe wrapper for OpenIslandHooks
# Delegates to host-relay-client for Docker-to-host execution.
# Falls back to direct binary check for legacy/uninstalled cases.

RELAY_CLIENT="/usr/local/bin/os/host_relay_client.sh"
HOOK_BIN="$HOME/Library/Application Support/OpenIsland/bin/OpenIslandHooks"

if [ -x "$RELAY_CLIENT" ]; then
		exec "$RELAY_CLIENT" openisland-hooks "$@" 2>/dev/null
fi

if [ -f "$HOOK_BIN" ] && [ -x "$HOOK_BIN" ]; then
		exec "$HOOK_BIN" "$@"
fi

exit 0
