#!/bin/bash
# daybook-interview-session.command
#
# Opened in an iTerm window each weekday morning by daybook-interview.sh (via
# launchd). It sets up the environment and launches Claude Code seeded with the
# Daybook interview prompt, then hands over an interactive session.
#
# Why iTerm runs this: launchd has no TTY, so it can't run the interactive CLI
# itself. It opens iTerm, and iTerm runs this script in a real TTY.

ROUTINES_DIR="$HOME/.claude/routines"
PROMPT_FILE="$ROUTINES_DIR/daybook-interview-prompt.md"

# Load secrets (JOPLIN_TOKEN, TRELLO_API_KEY, TRELLO_TOKEN) from ~/.env* files.
# launchd does NOT load a login profile, so source the helper explicitly. This
# also feeds the Joplin/Trello MCP servers their tokens when claude starts.
if [ -f /usr/local/bin/os/source_env_files.sh ]; then
		source /usr/local/bin/os/source_env_files.sh
fi
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

pause_and_exit() {
		echo ""
		echo "Press any key to close."
		read -r -n1 -s
		exit 1
}

if ! command -v claude >/dev/null 2>&1; then
		echo "Daybook: 'claude' not found on PATH."
		pause_and_exit
fi

if [ -z "${JOPLIN_TOKEN:-}" ]; then
		echo "Daybook: JOPLIN_TOKEN is not set (expected in ~/.env* via source_env_files.sh)."
		pause_and_exit
fi

if [ ! -f "$PROMPT_FILE" ]; then
		echo "Daybook: prompt file not found at $PROMPT_FILE"
		pause_and_exit
fi

# Launch Claude Code interactively, seeded with the interview prompt.
# --dangerously-skip-permissions: this is an unattended, self-launched morning
# session, so don't stop to confirm every tool call (Joplin/Trello/subagents).
# The session inherits the user's normal global MCP config (Joplin + Trello). If
# those tools are ever missing here, add: --mcp-config "$HOME/.claude/mcp.json"
exec claude --dangerously-skip-permissions "$(cat "$PROMPT_FILE")"
