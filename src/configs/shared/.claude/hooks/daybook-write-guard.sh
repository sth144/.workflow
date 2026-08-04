#!/bin/bash
# daybook-write-guard.sh — PreToolUse guard for Joplin note writes.
#
# The Joplin MCP `update_note` tool is a WHOLE-BODY REPLACE: there is no append
# mode and no diff safety, so a single malformed `body` argument silently destroys
# everything already in the note. This actually happened — a daybook agent sent a
# placeholder string as `body` and wiped a full day of worklog; it was recoverable
# only because the agent still had the original text in context.
#
# This hook re-reads the target note straight from the Joplin API and refuses the
# write when it would destroy content rather than add to it. Three checks:
#
#   1. worklog append-only — every `- HH:MM — ...` entry already in the note must
#      still be present. This is the invariant the trello-daybook-sync skill also
#      states ("Never overwrite existing worklog entries").
#   2. no catastrophic truncation — a body that drops below half the note's size.
#   3. no structure loss — the `# To Do` / `# Worklog` headings must survive.
#
# Deliberately NOT checked: removal of `- [ ]` To Do items. trello-daybook-sync
# removes trello-marked items whose cards left the Today list, so policing that
# would block a legitimate flow.
#
# Scope: only notes that already look like a daybook note (they carry a To Do or
# Worklog heading). Every other Joplin note — LESSONS.md, Areas/Agents pages,
# anything under a different notebook — is passed straight through, so this never
# turns into a general write gate on Joplin.
#
# FAILS OPEN by design. No token, unreachable API, unparseable payload, missing
# note: the write is allowed. A guard that blocked every Joplin write whenever
# Joplin was down would be worse than the data-loss risk it protects against.
#
# Escape hatch: DAYBOOK_GUARD_OFF=1 skips the guard entirely, for a deliberate
# rewrite or cleanup of a note.
#
# PreToolUse payload arrives on stdin as JSON: { tool_name, tool_input, ... }
# The decision is returned as JSON on stdout (permissionDecision allow|deny).

set -u

[ "${DAYBOOK_GUARD_OFF:-}" = "1" ] && exit 0

payload=$(cat)
tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null)

# Only ever gate the Joplin note-update tool; defer on everything else.
case "$tool_name" in
  mcp__joplin__update_note) ;;
  *) exit 0 ;;
esac

# A title-only or metadata-only update carries no body and cannot destroy text.
printf '%s' "$payload" | jq -e '.tool_input | has("body")' >/dev/null 2>&1 || exit 0

note_id=$(printf '%s' "$payload" | jq -r '.tool_input.note_id // empty' 2>/dev/null)
[ -n "$note_id" ] || exit 0

token="${JOPLIN_TOKEN:-}"
[ -n "$token" ] || exit 0

# Match the base-URL logic in .claude/mcp.json: the API lives on the host, so a
# containerised session has to reach it through host.docker.internal.
if [ -n "${JOPLIN_BASE_URL:-}" ]; then
  base="${JOPLIN_BASE_URL%/}"
elif [ -f /.dockerenv ]; then
  base="http://host.docker.internal:41184"
else
  base="http://127.0.0.1:41184"
fi

tmp=$(mktemp -d) || exit 0
trap 'rm -rf "$tmp"' EXIT

# Current (about to be replaced) body, straight from the API — not from context.
curl -sf -m 5 "$base/notes/$note_id?fields=body&token=$token" 2>/dev/null \
  | jq -r '.body // empty' > "$tmp/old" 2>/dev/null || exit 0
[ -s "$tmp/old" ] || exit 0

# Only guard notes that already look like a daybook note.
grep -qE '^#+[[:space:]]*(To Do|Worklog)' "$tmp/old" || exit 0

printf '%s' "$payload" | jq -r '.tool_input.body // empty' > "$tmp/new" 2>/dev/null || exit 0

old_len=$(wc -c < "$tmp/old" | tr -d ' ')
new_len=$(wc -c < "$tmp/new" | tr -d ' ')

problems=""

# 1. Worklog entries are append-only: every existing one must survive verbatim.
missing=0
total=0
while IFS= read -r line; do
  [ -n "$line" ] || continue
  total=$((total + 1))
  grep -Fq -- "$line" "$tmp/new" || missing=$((missing + 1))
done < <(grep -E '^[[:space:]]*-[[:space:]]+[0-9]{1,2}:[0-9]{2}[[:space:]]' "$tmp/old" 2>/dev/null)

if [ "$missing" -gt 0 ]; then
  problems="${problems}- drops ${missing} of ${total} existing worklog entries
"
fi

# 2. Catastrophic truncation.
if [ "$old_len" -ge 200 ] && [ "$new_len" -lt $((old_len / 2)) ]; then
  problems="${problems}- shrinks the note from ${old_len} to ${new_len} bytes
"
fi

# 3. Structure loss.
for heading in "To Do" "Worklog"; do
  if grep -qE "^#+[[:space:]]*${heading}" "$tmp/old" \
     && ! grep -qE "^#+[[:space:]]*${heading}" "$tmp/new"; then
    problems="${problems}- loses the '${heading}' heading
"
  fi
done

[ -n "$problems" ] || exit 0

reason="Blocked: this update_note call would destroy existing daybook content.

${problems}
update_note REPLACES the whole body. Do not construct the body from scratch:
call get_note(${note_id}) first, take the body it returns verbatim, append your
new entry to it, and send that combined text.

If you genuinely intend to rewrite or shrink this note, re-run with
DAYBOOK_GUARD_OFF=1 in the environment."

jq -nc --arg r "$reason" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
