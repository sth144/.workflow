#!/bin/bash
# daybook-interview.sh — launchd-side launcher for the morning Daybook interview.
#
# Invoked by com.workflow.daybook-interview (via run_once_daily.sh) on weekday
# mornings. launchd has no TTY, so it can't run an interactive CLI directly; it
# opens Alacritty with the session script, which runs in a real TTY and seeds an
# interactive Claude session.
#
# Schedule: weekdays 08:30 (also fires on login if 08:30 was missed).

set -euo pipefail

# Ensure the log dir exists (the plist's StandardOutPath/StandardErrorPath point
# here; launchd won't create missing parents).
mkdir -p "$HOME/.claude/routines/logs"

# launchd's PATH is minimal, so resolve the Alacritty binary directly (cask path)
# rather than relying on `alacritty` being on PATH. Alacritty runs the executable
# session script via -e (it does not open .command documents the way iTerm did).
#
# dynamic_title=false pins the window title to "Daybook" so the running Claude
# session can't rename it — this is what the Cmd+Ctrl+B Hammerspoon hotkey matches
# on to jump back to this window.
ALACRITTY="$(command -v alacritty 2>/dev/null || echo /Applications/Alacritty.app/Contents/MacOS/alacritty)"
exec "$ALACRITTY" --title "Daybook" -o window.dynamic_title=false -e "$HOME/.claude/routines/daybook-interview-session.command"
