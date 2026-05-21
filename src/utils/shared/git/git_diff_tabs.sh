#!/bin/bash
# git_diff_tabs.sh — open all staged/unstaged/untracked git changes as VSCode diff tabs
#
# Usage:
#   git_diff_tabs.sh              Open all changes (staged + unstaged + untracked)
#   git_diff_tabs.sh --staged     Open only staged changes
#   git_diff_tabs.sh --unstaged   Open only unstaged changes
#   git_diff_tabs.sh --untracked  Open only untracked files

set -uo pipefail

SHOW_STAGED=true
SHOW_UNSTAGED=true
SHOW_UNTRACKED=true
REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || {
	echo "Not in a git repository" >&2
	exit 1
}

case "${1:-}" in
	--staged)   SHOW_UNSTAGED=false; SHOW_UNTRACKED=false ;;
	--unstaged) SHOW_STAGED=false; SHOW_UNTRACKED=false ;;
	--untracked) SHOW_STAGED=false; SHOW_UNSTAGED=false ;;
	--help|-h)
		sed -n '2,/^$/{ s/^# \?//; p }' "$0"
		exit 0
		;;
esac

# Resolve the `code` binary — not always on PATH (e.g. Claude Code shell, cron)
CODE_BIN="${VSCODE_GIT_ASKPASS_NODE%/*}/../bin/code"
if [ ! -x "$CODE_BIN" ] 2>/dev/null; then
	CODE_BIN=$(command -v code 2>/dev/null || echo "")
fi
if [ -z "$CODE_BIN" ]; then
	# macOS fallback
	CODE_BIN="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
fi
if [ ! -x "$CODE_BIN" ]; then
	echo "Error: could not find VSCode 'code' binary" >&2
	exit 1
fi

# Use a persistent temp dir — code --diff is async so files must survive the script.
# Clean up previous run's files, then create fresh ones.
DIFFDIR="${HOME}/.cache/.workflow/git-diff-tabs"
rm -rf "$DIFFDIR"
mkdir -p "$DIFFDIR"
count=0

# open_diff base_ref path label
#   base_ref: "HEAD" for staged, ":"  (index) for unstaged
#   path: repo-relative file path
#   label: prefix for the temp file name
open_diff() {
	local ref="$1" path="$2" label="$3"
	local abs_path="$REPO_ROOT/$path"
	local safe_name
	safe_name=$(echo "$path" | tr '/' '_')
	local tmp_file="$DIFFDIR/${label}_${safe_name}"

	# write the "before" version to a temp file
	if git cat-file -e "${ref}${path}" 2>/dev/null; then
		git show "${ref}${path}" > "$tmp_file" 2>/dev/null
	else
		# new file — diff against empty
		: > "$tmp_file"
	fi

	# for staged diffs, the "after" is the index version, not the working tree
	local right="$abs_path"
	if [ "$label" = "staged" ]; then
		right="$DIFFDIR/idx_${safe_name}"
		git show ":${path}" > "$right" 2>/dev/null
	fi

	"$CODE_BIN" --diff "$tmp_file" "$right" </dev/null
	count=$((count + 1))
}

# staged changes (HEAD vs index)
if [ "$SHOW_STAGED" = "true" ]; then
	while IFS= read -r file; do
		[ -z "$file" ] && continue
		open_diff "HEAD:" "$file" "staged"
	done < <(git diff --cached --name-only --diff-filter=d)
fi

# unstaged changes (index vs working tree)
if [ "$SHOW_UNSTAGED" = "true" ]; then
	while IFS= read -r file; do
		[ -z "$file" ] && continue
		open_diff ":" "$file" "unstaged"
	done < <(git diff --name-only --diff-filter=d)
fi

# untracked files (empty vs working tree)
if [ "$SHOW_UNTRACKED" = "true" ]; then
	while IFS= read -r file; do
		[ -z "$file" ] && continue
		# skip directories (git ls-files --others can list them with trailing /)
		[ -f "$REPO_ROOT/$file" ] || continue
		open_diff "NONE:" "$file" "untracked"
	done < <(git ls-files --others --exclude-standard)
fi

if [ "$count" -eq 0 ]; then
	echo "No changes to diff"
else
	echo "Opened $count diff tab(s)"
fi
