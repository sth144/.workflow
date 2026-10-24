#!/bin/bash
# slack-eyes.sh — Turn Slack 👀 reactions into daybook To Do items.
#
# Invoked by com.workflow.slack-eyes (via run_once_daily.sh) on weekday
# mornings at 08:25 — just ahead of the 08:30 daybook interview, so the
# interview session opens with today's 👀 items already in the To Do list.
#
# The 07:00 trello-daybook-sync promotes the items this adds into Trello Today
# cards on its next run.
#
# Schedule: weekdays 08:25

set -euo pipefail

# CDPATH= keeps `cd` from echoing the resolved directory (it does that whenever
# CDPATH is set, which would land in SCRIPT_DIR alongside pwd's output).
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p ~/.claude/routines/logs

# LaunchAgents have a minimal environment — load secrets and PATH.
#
# source_env_files.sh runs commands that legitimately return nonzero (greps that
# match nothing, `[[ ... ]] && continue` chains), and it has to run in *this*
# shell to export the secrets, so it can't be subshelled away. Under `set -e`
# that nonzero status kills the script at this line, before any output — a
# trailing `|| true` does not help, because errexit fires inside the sourced
# file rather than on the `source` builtin itself. Drop errexit/nounset across
# the call only.
set +eu
source /usr/local/bin/os/source_env_files.sh 2>/dev/null
set -eu
export PATH="$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH"

echo "=== Slack 👀 → Daybook To Do - $(date) ==="

EYES_SCRIPT="$SCRIPT_DIR/../skills/slack-eyes/eyes.py"
if [ ! -f "$EYES_SCRIPT" ]; then
	echo "eyes.py not found at $EYES_SCRIPT" >&2
	exit 1
fi

# The scheduled PATH resolves bare `python3` to interpreters without `requests`,
# so explicitly pick one that has it — system python (/usr/bin/python3) ships
# with it. Same trap the trello-daybook-sync routine hit.
PY=""
for cand in /usr/bin/python3 python3 python3.12 python3.11; do
	if command -v "$cand" >/dev/null 2>&1 && "$cand" -c "import requests" 2>/dev/null; then
		PY="$cand"
		break
	fi
done

if [ -n "$PY" ]; then
	"$PY" "$EYES_SCRIPT" "$@"
elif command -v uv >/dev/null 2>&1; then
	uv run --with requests "$EYES_SCRIPT" "$@"
else
	echo "no python3 with requests available" >&2
	exit 1
fi
