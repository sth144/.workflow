#!/bin/bash
# diff-tab.sh — open a VSCode diff tab for every Edit/Write so the user can
# review changes even while running in acceptEdits permission mode.
#
# Wired in settings.json as both a PreToolUse hook (snapshots the file before
# the edit) and a PostToolUse hook (opens `code --diff <before> <after>`).
#
# Hook payload arrives on stdin as JSON: { tool_name, tool_input, tool_response?, ... }
# `tool_response` is only present in PostToolUse, which is how we distinguish phase.

set -u

SNAPSHOT_DIR="${TMPDIR:-/tmp}/claude-diff-snapshots"
mkdir -p "$SNAPSHOT_DIR"

# Snapshots older than 1 hour are stale — purge so /tmp doesn't bloat.
find "$SNAPSHOT_DIR" -type f -mmin +60 -delete 2>/dev/null || true

payload=$(cat)
tool_name=$(printf '%s' "$payload" | jq -r '.tool_name // empty')

case "$tool_name" in
  Edit|Write|MultiEdit|NotebookEdit) ;;
  *) exit 0 ;;
esac

if [ "$tool_name" = "NotebookEdit" ]; then
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.notebook_path // empty')
else
  file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')
fi

[ -n "$file_path" ] || exit 0

# Map file_path -> snapshot path. md5sum keeps the filename stable across
# pre/post invocations without colliding on paths with slashes.
hash=$(printf '%s' "$file_path" | md5sum | awk '{print $1}')
snapshot="$SNAPSHOT_DIR/$hash.before"

# Detect phase: PostToolUse payloads include tool_response, PreToolUse don't.
has_response=$(printf '%s' "$payload" | jq -r 'has("tool_response")')

if [ "$has_response" != "true" ]; then
  # PreToolUse: snapshot current file contents (or create empty for new files).
  if [ -f "$file_path" ]; then
    cp "$file_path" "$snapshot" 2>/dev/null || true
  else
    : > "$snapshot"
  fi
  exit 0
fi

# PostToolUse: open the diff. Bail if no snapshot or the edit failed.
[ -f "$snapshot" ] || exit 0
success=$(printf '%s' "$payload" | jq -r '.tool_response.success // .tool_response.type // "ok"')
if [ "$success" = "false" ] || [ "$success" = "error" ]; then
  rm -f "$snapshot"
  exit 0
fi

# Resolve the VSCode CLI.
# Priority order:
# 1. VSCODE_GIT_ASKPASS_NODE points to the active VSCode's node; derive CLI from it
# 2. Remote/devcontainer vscode-server paths
# 3. macOS host app bundle
# 4. PATH fallback
# 5. Dynamic search as last resort
code_bin=""

# Method 1: Derive from VSCODE_GIT_ASKPASS_NODE (most reliable for active connection)
if [ -n "${VSCODE_GIT_ASKPASS_NODE:-}" ]; then
  # Path looks like: ~/.vscode-server/bin/<hash>/node
  # CLI is at:       ~/.vscode-server/bin/<hash>/bin/remote-cli/code
  vscode_dir=$(dirname "$(dirname "$VSCODE_GIT_ASKPASS_NODE")")
  candidate="$vscode_dir/bin/remote-cli/code"
  [ -x "$candidate" ] && code_bin="$candidate"
fi

# Method 2: Check known static paths
if [ -z "$code_bin" ]; then
  for candidate in \
    "$HOME/.vscode-server/bin"/*/bin/remote-cli/code \
    /vscode/vscode-server/bin/*/bin/remote-cli/code \
    "$HOME/.vscode-remote/bin"/*/bin/remote-cli/code \
    "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
    "$(command -v code 2>/dev/null)"; do
    [ -n "$candidate" ] && [ -x "$candidate" ] && { code_bin="$candidate"; break; }
  done
fi

# Method 3: Dynamic search (devcontainers with non-standard user homes)
if [ -z "$code_bin" ]; then
  candidate=$(find /home -maxdepth 5 -path '*/.vscode-server/bin/*/bin/remote-cli/code' -type f 2>/dev/null | head -1)
  [ -n "$candidate" ] && [ -x "$candidate" ] && code_bin="$candidate"
fi

if [ -z "$code_bin" ]; then
  rm -f "$snapshot"
  exit 0
fi

# Stamp the snapshot with a recognizable name so the diff tab title is useful.
# `code --diff` shows the basenames as "<left> ↔ <right>", so we copy the
# snapshot next to a name like `<basename>.before`.
labeled="$SNAPSHOT_DIR/$(basename "$file_path").before"
cp "$snapshot" "$labeled" 2>/dev/null || true

"$code_bin" --diff "$labeled" "$file_path" >/dev/null 2>&1 &

# Don't leave the original-keyed snapshot lying around; the labeled copy is
# what the diff tab now references.
rm -f "$snapshot"
exit 0
