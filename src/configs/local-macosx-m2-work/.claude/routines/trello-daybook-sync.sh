#!/bin/bash
# Trello Daybook Sync - Morning sync of Trello Today cards to Joplin daybook
#
# Also the note-creating routine of the day: when today's daybook note does not
# exist yet, sync.py creates it and carries forward yesterday's unchecked items.
#
# Schedule: Weekdays 7am
# Cron: 0 7 * * 1-5

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.claude/routines/logs

# LaunchAgents have a minimal environment — load secrets and PATH.
#
# source_env_files.sh runs commands that legitimately return nonzero, and it has
# to run in *this* shell to export the secrets, so it can't be subshelled away.
# Under `set -e` that nonzero status kills the script at this line, before any
# output — a trailing `|| true` does not help, because errexit fires inside the
# sourced file rather than on the `source` builtin itself. Drop errexit/nounset
# across the call only.
set +eu
source /usr/local/bin/os/source_env_files.sh 2>/dev/null
set -eu
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

# Load Slack helper
source "$SCRIPT_DIR/lib/slack.sh"

PROMPT='You are my morning sync assistant. Sync my Trello "Today" list to my Joplin daybook.

## Steps

1. Fetch all cards from the Trello "Today" list using curl:
   curl -s "https://api.trello.com/1/lists/637bc2f8722fe72795105471/cards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}&fields=name,due,labels,idShort,id"

2. Find or create today'"'"'s Joplin daybook note:
   - Title format: DD Mon, YYYY (e.g., 20 Apr, 2026)
   - Search in Areas / <DAYBOOK_NOTEBOOK> (notebook ID: c8ed0dc13a1f4269a66fe7d0d53ea07e)
   - If it does not exist, find the most recent daybook entry and carry forward
     any incomplete checklist items (- [ ] ...)

3. Build the # To Do ✅ section:
   - One checkbox per Trello card: - [ ] Card name <!-- trello:CARD_ID -->
   - If the note already has a # To Do ✅ section, merge:
     - Keep checked items (- [x] ...) as-is
     - Keep unchecked trello-marked items if the card is still in Today
     - Add new cards not already present
     - Remove trello-marked items whose cards left the Today list
     - Preserve manually-added items (no <!-- trello:... --> marker)

4. Ensure a # Worklog 📝 section exists below # To Do ✅ (create empty if missing,
   never overwrite existing entries)

5. Update the Joplin note with the merged body

## Output

Print a one-line summary: how many cards synced, how many new, how many preserved.
Do NOT print the full note body.'

# Read any additional context from stdin if provided
EXTRA_CONTEXT=""
if [ ! -t 0 ]; then
		EXTRA_CONTEXT=$(cat)
fi

if [ -n "$EXTRA_CONTEXT" ]; then
		PROMPT="$PROMPT

## Additional Context
$EXTRA_CONTEXT"
fi

echo "=== Trello → Daybook Sync - $(date) ==="

# Prefer deterministic sync.py (it syncs BOTH directions, including
# Joplin -> Trello) over the Claude fallback (which only pulls Trello -> Joplin).
# The scheduled PATH resolves bare `python3` to interpreters without `requests`,
# so explicitly pick one that has it — system python (/usr/bin/python3) ships with it.
SYNC_SCRIPT="$HOME/.claude/skills/trello-daybook-sync/sync.py"
PY=""
for cand in /usr/bin/python3 python3 python3.12 python3.11; do
    if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import requests" 2>/dev/null; then
        PY="$cand"
        break
    fi
done

if [ -f "$SYNC_SCRIPT" ] && [ -n "$PY" ]; then
    OUTPUT=$("$PY" "$SYNC_SCRIPT" 2>&1)
    echo "$OUTPUT"
elif [ -f "$SYNC_SCRIPT" ] && command -v uv >/dev/null 2>&1; then
    OUTPUT=$(uv run --with requests "$SYNC_SCRIPT" 2>&1)
    echo "$OUTPUT"
else
    echo "sync.py unavailable (no interpreter with requests), falling back to Claude"
    OUTPUT=$(echo "$PROMPT" | claude --print 2>&1)
    echo "$OUTPUT"
fi

# Post to Slack
slack_post "📋 *Morning Sync* - $(date '+%a %b %d')

$OUTPUT"
