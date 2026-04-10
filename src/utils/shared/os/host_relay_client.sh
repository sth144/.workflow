#!/usr/bin/env bash

# host_relay_client.sh — Execute registered host commands from Docker or locally.
#
# Usage: host_relay_client.sh <command-key> [args...]
#        echo "text" | host_relay_client.sh <command-key>
#
# Inside Docker: POSTs to host.docker.internal:7899/exec
# On host:       Resolves command from ~/.config/host_relay/commands.json and execs directly
# Fails silently if relay is unreachable (exit 0).
# Supports piped stdin (e.g., for pbcopy).

set -euo pipefail

RELAY_HOST="host.docker.internal"
RELAY_PORT="7899"
REGISTRY="$HOME/.config/host_relay/commands.json"
TOKEN_FILE="$HOME/.config/.env.HOST_RELAY_TOKEN"

COMMAND_KEY="${1:-}"
shift 2>/dev/null || true

if [ -z "$COMMAND_KEY" ]; then
		echo "Usage: host_relay_client.sh <command-key> [args...]" >&2
		exit 1
fi

# Capture stdin if piped (not a terminal)
STDIN_DATA=""
if [ ! -t 0 ]; then
		STDIN_DATA=$(cat)
fi

# Build JSON payload using python3 (always available in our containers)
build_json_payload() {
		python3 -c "
import json, sys
args = sys.argv[2:]
payload = {'command': sys.argv[1], 'args': args}
stdin_data = sys.stdin.read()
if stdin_data:
    payload['stdin'] = stdin_data
print(json.dumps(payload))
" "$COMMAND_KEY" "$@" <<< "$STDIN_DATA"
}

# Docker path: POST to relay server
relay_exec() {
		local payload
		payload=$(build_json_payload "$@")

		local auth_header=""
		if [ -f "$TOKEN_FILE" ]; then
				local token
				token=$(cat "$TOKEN_FILE")
				auth_header="-H Authorization: Bearer $token"
		fi

		# shellcheck disable=SC2086
		local response
		response=$(curl -sf --max-time 30 \
				-X POST \
				-H "Content-Type: application/json" \
				$auth_header \
				-d "$payload" \
				"http://${RELAY_HOST}:${RELAY_PORT}/exec" 2>/dev/null) || return 0

		# Extract exit code and print stdout/stderr
		local exit_code stdout stderr
		exit_code=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('exit_code',0))" 2>/dev/null) || exit_code=0
		stdout=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); s=d.get('stdout',''); print(s,end='')" 2>/dev/null)
		stderr=$(echo "$response" | python3 -c "import json,sys; d=json.load(sys.stdin); s=d.get('stderr',''); print(s,end='')" 2>/dev/null)

		[ -n "$stdout" ] && echo "$stdout"
		[ -n "$stderr" ] && echo "$stderr" >&2
		return "$exit_code"
}

# Local path: resolve command from registry and exec directly
local_exec() {
		if [ ! -f "$REGISTRY" ]; then
				return 0
		fi

		local cmd
		cmd=$(python3 -c "
import json, os, sys
key = sys.argv[1]
reg = json.loads(open(os.path.expanduser('$REGISTRY')).read())
entry = reg.get(key)
if not entry:
    sys.exit(1)
cmd = entry['command'].replace('\$HOME', os.environ.get('HOME', ''))
prepend = entry.get('prepend_args', [])
parts = [cmd] + prepend
print('\n'.join(parts))
" "$COMMAND_KEY" 2>/dev/null) || return 0

		# Read command parts into array
		local -a cmd_parts
		while IFS= read -r line; do
				cmd_parts+=("$line")
		done <<< "$cmd"

		# Pipe stdin data if present, otherwise just exec
		if [ -n "$STDIN_DATA" ]; then
				echo "$STDIN_DATA" | exec "${cmd_parts[@]}" "$@"
		else
				exec "${cmd_parts[@]}" "$@"
		fi
}

# Route based on environment
if [ -f "/.dockerenv" ]; then
		relay_exec "$@"
else
		local_exec "$@"
fi
