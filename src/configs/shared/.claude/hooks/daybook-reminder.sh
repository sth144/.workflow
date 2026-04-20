#!/bin/bash
# daybook-reminder.sh — Stop hook for Claude Code
# Reminds Claude to log completed work to the Joplin daybook.
# Blocks the stop if the transcript suggests non-trivial work was done
# but no daybook entry was made.

LOG="$HOME/.cache/claude.log"
mkdir -p "$(dirname "$LOG")"

log() {
		echo "$(date '+%Y-%m-%d %H:%M:%S') [daybook-reminder] $*" >> "$LOG"
}

log "Hook triggered"

INPUT=$(cat)
log "Raw input: $INPUT"

TRANSCRIPT_PATH=$(echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('transcript_path',''))" 2>/dev/null)
log "Transcript path: ${TRANSCRIPT_PATH:-<empty>}"

# If we can't find the transcript, allow the stop
if [ -z "$TRANSCRIPT_PATH" ] || [ ! -f "$TRANSCRIPT_PATH" ]; then
		log "Transcript not found or empty — allowing stop"
		exit 0
fi

LINE_COUNT=$(wc -l < "$TRANSCRIPT_PATH")
log "Transcript line count: $LINE_COUNT"

# Short conversations are likely trivial — don't block
if [ "$LINE_COUNT" -lt 50 ]; then
		log "Short conversation ($LINE_COUNT lines) — allowing stop"
		exit 0
fi

# Check whether the session actually changed anything (edits, writes, bash).
# A long read-only or chat-only session doesn't need a daybook entry.
TOOL_HITS=$(grep -c -E '"(Edit|Write|Bash|NotebookEdit)"' "$TRANSCRIPT_PATH" 2>/dev/null || echo 0)
log "Tool-use hits: $TOOL_HITS"

if [ "$TOOL_HITS" -lt 1 ]; then
		log "No file-modifying tool use detected — allowing stop"
		exit 0
fi

# Use a marker file keyed to this transcript so we only block once.
# After the agent has been reminded and checks the daybook, the second
# stop attempt will find the marker and pass through — no infinite loop.
MARKER_DIR="$HOME/.cache/claude-daybook-markers"
mkdir -p "$MARKER_DIR"
MARKER_HASH=$(echo -n "$TRANSCRIPT_PATH" | md5 2>/dev/null || echo -n "$TRANSCRIPT_PATH" | md5sum 2>/dev/null | cut -d' ' -f1)
MARKER="$MARKER_DIR/$MARKER_HASH"

if [ -f "$MARKER" ]; then
		log "Already reminded this session — allowing stop"
		exit 0
fi

touch "$MARKER"
NOW=$(date '+%H:%M')
log "Non-trivial session ($LINE_COUNT lines, $TOOL_HITS tool uses) — reminding to log/update daybook"
python3 -c "
import json
reason = (
    'Before stopping, check the daybook. Search Joplin for today\'s note '
    'in Areas / Daybook (title format: DD Mon, YYYY). '
    'If it exists, read it and append any work from this session that is not '
    'already covered. If it does not exist, create it with two sections: '
    '## To Do and ## Worklog. '
    'When creating a new note, look at the most recent Daybook entry and copy '
    'over any incomplete checklist items (- [ ] ...) into the ## To Do section. '
    'Then add worklog entries under ## Worklog in the format: '
    '- HH:MM \u2014 <one-sentence summary>. '
    'The current time is $NOW. Use that for the timestamp \u2014 do NOT call date. '
    'Include a screenshot link if visual changes were made. '
    'If this session was actually trivial (casual chat, no code/config changes), '
    'you may stop without logging.'
)
print(json.dumps({'decision': 'block', 'reason': reason}))
"
exit 0
