#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-.}"

[[ -d "$DIR" ]] || {
  echo "Target directory does not exist: $DIR" >&2
  exit 1
}

DIR="$(cd "$DIR" && pwd)"

get_mtime_date() {
  local file="$1"

  if [[ "$(uname)" == "Darwin" ]]; then
    stat -f '%Sm' -t '%Y-%m-%d' "$file"
  else
    stat -c '%y' "$file" | cut -d' ' -f1
  fi
}

for f in "$DIR"/*; do
  [[ -e "$f" ]] || continue
  [[ -f "$f" ]] || continue

  date_dir="$(get_mtime_date "$f")"

  mkdir -p "$DIR/$date_dir"
  mv "$f" "$DIR/$date_dir/"
done
