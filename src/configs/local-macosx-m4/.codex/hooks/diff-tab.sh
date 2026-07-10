#!/bin/bash
# diff-tab.sh — open VS Code diffs for Codex file edits.
#
# Wired as both a PreToolUse hook and a PostToolUse hook:
# - pre snapshots files targeted by apply_patch
# - post opens `code --diff <before> <after>` for those same files

set -u

phase="${1:-}"
[ "$phase" = "pre" ] || [ "$phase" = "post" ] || exit 0

# Toggle: skip if disabled.
[ -f "$HOME/.codex/hooks/diff-tab.disabled" ] && exit 0

SNAPSHOT_DIR="${TMPDIR:-/tmp}/codex-diff-snapshots"
mkdir -p "$SNAPSHOT_DIR"
find "$SNAPSHOT_DIR" -type f -mmin +60 -delete 2>/dev/null || true

payload=$(cat)

json_get() {
	local filter="$1"
	printf '%s' "$payload" | jq -r "$filter" 2>/dev/null
}

tool_name=$(json_get '.tool_name // .toolName // .name // .tool // empty')
case "$tool_name" in
	apply_patch|functions.apply_patch) ;;
	*) exit 0 ;;
esac

cwd=$(json_get '.cwd // .current_working_directory // .workdir // empty')
[ -n "$cwd" ] && [ "$cwd" != "null" ] || cwd="$PWD"

patch_text=$(json_get '
	if .tool_input? then
		if (.tool_input | type) == "string" then .tool_input
		else (.tool_input.patch // .tool_input.input // .tool_input.command // .tool_input.cmd // "")
		end
	elif .input? then
		if (.input | type) == "string" then .input
		else (.input.patch // .input.input // .input.command // .input.cmd // "")
		end
	elif .arguments? then
		if (.arguments | type) == "string" then .arguments
		else (.arguments.patch // .arguments.input // "")
		end
	else ""
	end
')

[ -n "$patch_text" ] && [ "$patch_text" != "null" ] || exit 0

paths=$(
	printf '%s\n' "$patch_text" |
		awk '
			/^\*\*\* (Add|Update|Delete) File: / {
				sub(/^\*\*\* (Add|Update|Delete) File: /, "")
				print
			}
			/^\*\*\* Move to: / {
				sub(/^\*\*\* Move to: /, "")
				print
			}
		' |
		awk 'NF && !seen[$0]++'
)

[ -n "$paths" ] || exit 0

resolve_path() {
	case "$1" in
		/*) printf '%s\n' "$1" ;;
		*) printf '%s\n' "$cwd/$1" ;;
	esac
}

path_hash() {
	if command -v md5 >/dev/null 2>&1; then
		printf '%s' "$1" | md5
	else
		printf '%s' "$1" | md5sum | awk '{print $1}'
	fi
}

snapshot_path() {
	local abs="$1"
	printf '%s/%s.before\n' "$SNAPSHOT_DIR" "$(path_hash "$abs")"
}

if [ "$phase" = "pre" ]; then
	while IFS= read -r path; do
		[ -n "$path" ] || continue
		abs=$(resolve_path "$path")
		snapshot=$(snapshot_path "$abs")
		if [ -f "$abs" ]; then
			cp "$abs" "$snapshot" 2>/dev/null || : > "$snapshot"
		else
			: > "$snapshot"
		fi
	done <<EOF
$paths
EOF
	exit 0
fi

code_bin=""
if [ -n "${VSCODE_GIT_ASKPASS_NODE:-}" ]; then
	vscode_dir=$(dirname "$(dirname "$VSCODE_GIT_ASKPASS_NODE")")
	candidate="$vscode_dir/bin/remote-cli/code"
	[ -x "$candidate" ] && code_bin="$candidate"
fi

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

[ -n "$code_bin" ] || exit 0

while IFS= read -r path; do
	[ -n "$path" ] || continue
	abs=$(resolve_path "$path")
	snapshot=$(snapshot_path "$abs")
	[ -f "$snapshot" ] || continue

	base=$(basename "$abs")
	if [[ "$base" == *.* ]]; then
		name="${base%.*}"
		ext="${base##*.}"
		labeled="$SNAPSHOT_DIR/$name.before.$ext"
	else
		labeled="$SNAPSHOT_DIR/$base.before"
	fi
	cp "$snapshot" "$labeled" 2>/dev/null || labeled="$snapshot"

	right="$abs"
	if [ ! -e "$right" ]; then
		after="$SNAPSHOT_DIR/$base.after.deleted"
		: > "$after"
		right="$after"
	fi

	"$code_bin" --diff "$labeled" "$right" >/dev/null 2>&1 &
	rm -f "$snapshot"
done <<EOF
$paths
EOF

exit 0
