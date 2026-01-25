#!/usr/bin/env bash
set -euo pipefail

DIR="${1:-.}"

# Resolve to absolute path (optional but nice)
DIR="$(cd "$DIR" && pwd)"

for f in "$DIR"/*; do
  [[ -f "$f" ]] || continue

  # Get modification date (YYYY-MM-DD)
  date_dir="$(stat -c '%y' "$f" | cut -d' ' -f1)"

  mkdir -p "$DIR/$date_dir"
  mv "$f" "$DIR/$date_dir/"
done

