#!/bin/bash
# screen-tutor-consent.sh — time-boxed consent gate for Screen Tutor screen
# captures. Two roles, both guarded by SCREEN_TUTOR_SESSION=1 (set by the
# Hammerspoon launcher), so this never affects any other Claude session:
#
#   reset  (SessionStart hook): clears stored consent, so every new Screen Tutor
#          session prompts at least once.
#   gate   (PreToolUse Bash hook, default): the first screen capture in each
#          30-minute window pops a macOS consent dialog. "Allow" is remembered
#          for 30 minutes (subsequent captures pass silently); "Deny" blocks it.
#
# A PreToolUse "deny" decision overrides the global Bash(*) allow rule, so this
# is what makes the gate effective even though tool calls are otherwise allowed.
#
# PreToolUse payload arrives on stdin as JSON: { tool_name, tool_input, ... }
# The decision is returned as JSON on stdout (permissionDecision allow|deny).

set -u

CONSENT_DIR="$HOME/.cache/.workflow/screen-tutor"
CONSENT_FILE="$CONSENT_DIR/consent"

# Only ever act inside a Screen Tutor session; defer everywhere else.
[ "${SCREEN_TUTOR_SESSION:-}" = "1" ] || exit 0

# SessionStart: forget any prior consent so a fresh session asks again.
if [ "${1:-}" = "reset" ]; then
  rm -f "$CONSENT_FILE" 2>/dev/null || true
  exit 0
fi

payload=$(cat)
tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty')
[ "$tool_name" = "Bash" ] || exit 0

command=$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')

# Only gate commands that actually capture the screen.
case "$command" in
  *screencapture*|*screen_tutor.py*shot*|*screen_tutor.py*locate*) ;;
  *) exit 0 ;;
esac

allow() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

deny() {
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$1"
  exit 0
}

# Consent still fresh (< 30 min)? Pass silently.
if [ -f "$CONSENT_FILE" ] && [ -n "$(find "$CONSENT_FILE" -mmin -30 2>/dev/null)" ]; then
  allow "Screen Tutor consent active"
fi

# Otherwise ask once, and remember the answer for 30 minutes.
answer=$(osascript -e 'display dialog "Allow Screen Tutor to capture your screen for the next 30 minutes?" buttons {"Deny","Allow"} default button "Allow" with title "Screen Tutor" with icon caution giving up after 60' 2>/dev/null)

case "$answer" in
  *"button returned:Allow"*)
    mkdir -p "$CONSENT_DIR"
    touch "$CONSENT_FILE"
    allow "Screen Tutor consent granted for 30 minutes"
    ;;
  *)
    deny "Screen capture consent denied or timed out"
    ;;
esac
