#!/bin/bash
# Move the gitignored contents of src/*/local/ into the git-crypt encrypted
# src/*/<layer>-vault/ directories so they are tracked (encrypted) in git.
#
# usage: migrate_local_to_vault.sh [layer]
#   layer defaults to the single "local-*" include in admin/config/settings.json

set -euo pipefail

BASE_ABS=$(cd "$(dirname "$0")/.." && pwd)
cd "$BASE_ABS"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

default_layer() {
	local layers
	layers=$(jq -r '.build.include[] | select(startswith("local-"))' admin/config/settings.json)
	[ "$(echo "$layers" | grep -c .)" -eq 1 ] || die "expected exactly one local-* include in settings.json; pass the layer explicitly"
	echo "$layers"
}

LAYER="${1:-$(default_layer)}"
VAULT="$LAYER-vault"

# refuse to move anything unless git would encrypt it on add
[ -d "$(git rev-parse --git-common-dir)/git-crypt/keys" ] || die "git-crypt is not unlocked here (git-crypt unlock ~/.config/git-crypt/workflow.key)"
[ "$(git check-attr filter -- "src/configs/$VAULT/probe" | awk '{print $NF}')" = "git-crypt" ] || die "src/*/$VAULT is not covered by .gitattributes"

moved=0
for localdir in src/*/local; do
	dest="$(dirname "$localdir")/$VAULT"
	while IFS= read -r -d '' entry; do
		mkdir -p "$dest"
		if [ -e "$dest/$(basename "$entry")" ]; then
			echo "SKIP: $entry (already exists in $dest)"
			continue
		fi
		mv "$entry" "$dest"/
		echo "moved $entry -> $dest/"
		moved=$((moved + 1))
	done < <(find "$localdir" -mindepth 1 -maxdepth 1 ! -name .keep ! -name .gitkeep -print0)
done

echo "migrated $moved item(s) into $VAULT; review with: git status src/*/$VAULT && git-crypt status -e"
