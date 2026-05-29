#!/bin/bash
# daybook-interview.sh — launchd-side launcher for the morning Daybook interview.
#
# Invoked by com.workflow.daybook-interview (via run_once_daily.sh) on weekday
# mornings. launchd has no TTY, so it can't run an interactive CLI directly; it
# opens iTerm with the session script, which runs in a real TTY and seeds an
# interactive Claude session.
#
# Schedule: weekdays 08:30 (also fires on login if 08:30 was missed).

set -euo pipefail

# Ensure the log dir exists (the plist's StandardOutPath/StandardErrorPath point
# here; launchd won't create missing parents).
mkdir -p "$HOME/.claude/routines/logs"

exec /usr/bin/open -a iTerm "$HOME/.claude/routines/daybook-interview-session.command"
