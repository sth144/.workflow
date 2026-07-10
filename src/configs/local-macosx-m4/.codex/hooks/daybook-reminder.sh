#!/bin/bash
# daybook-reminder.sh — Stop hook for Codex CLI
# Mirrors the Claude Code daybook Stop hook: reminds Codex to log completed
# work to the Joplin daybook before ending the turn.
#
# Codex Stop-hook contract: emitting {"decision":"block","reason":"..."} turns
# the reason into a continuation prompt (re-engaging the model), exactly like
# Claude's blocking Stop hook. When Codex has already continued the turn it
# sets stop_hook_active=true on the next Stop — we honor that to avoid looping.

LOG="$HOME/.cache/codex.log"
mkdir -p "$(dirname "$LOG")"

log() {
		echo "$(date '+%Y-%m-%d %H:%M:%S') [daybook-reminder] $*" >> "$LOG"
}

log "Hook triggered"

INPUT=$(cat)

# Pull the fields we need. Parsing is read-only — transcript/message content is
# never expanded into a shell context.
TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path') or '')" 2>/dev/null)
STOP_ACTIVE=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('stop_hook_active'))" 2>/dev/null)
log "stop_hook_active=$STOP_ACTIVE transcript=${TRANSCRIPT_PATH:-<empty>}"

# Already continued once this turn — let the stop through (prevents a loop).
if [ "$STOP_ACTIVE" = "True" ]; then
		log "stop_hook_active — allowing stop"
		exit 0
fi

# If we can't find the transcript, allow the stop.
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
		log "Transcript not found — allowing stop"
		exit 0
fi

LINE_COUNT=$(wc -l < "$TRANSCRIPT_PATH")
log "Transcript line count: $LINE_COUNT"

# Short conversations are likely trivial — don't block.
if [ "$LINE_COUNT" -lt 50 ]; then
		log "Short conversation ($LINE_COUNT lines) — allowing stop"
		exit 0
fi

# Only nag if the session actually changed something. Codex records file edits
# as apply_patch and shell work as exec_command in the JSONL transcript.
# grep -c prints "0" and exits non-zero when there are no matches, so a
# `|| echo 0` fallback would double the value ("0\n0"). Capture directly and
# default only when grep produced no output (e.g. unreadable file).
TOOL_HITS=$(grep -c -E '"(apply_patch|exec_command)"' "$TRANSCRIPT_PATH" 2>/dev/null)
[ -z "$TOOL_HITS" ] && TOOL_HITS=0
log "Tool-use hits: $TOOL_HITS"

if [ "$TOOL_HITS" -lt 1 ]; then
		log "No file-modifying tool use detected — allowing stop"
		exit 0
fi

NOW=$(date '+%H:%M')
log "Non-trivial session ($LINE_COUNT lines, $TOOL_HITS tool uses) — reminding to log/update daybook"

cat <<EOF
{"decision":"block","reason":"Daybook log due. Delegate to the daybook-logger subagent if available; otherwise follow ~/.codex/hooks/daybook-instructions.md silently. Keep chat output to final task status. Time: $NOW"}
EOF
exit 0
