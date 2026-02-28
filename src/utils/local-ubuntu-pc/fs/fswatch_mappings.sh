#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${HOME}/.config/fswatch/mappings.conf"
LATENCY="${FSWATCH_LATENCY:-0.3}"

[[ -f "$CONFIG_FILE" ]] || { echo "Missing $CONFIG_FILE" >&2; exit 1; }

declare -A OUT_BY_SRC
declare -A ARGS_BY_SRC
sources=()

_norm() {
  command -v realpath >/dev/null 2>&1 && realpath -m "$1" || echo "$1"
}

while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line#"${line%%[![:space:]]*}"}"
  line="${line%"${line##*[![:space:]]}"}"
  [[ -z "$line" || "$line" =~ ^# ]] && continue

  IFS=':' read -r src out args <<< "$line"

  [[ -z "$src" || -z "$out" ]] && continue

  src="$(_norm "$src")"
  out="$(_norm "$out")"

  # commas → spaces for pandoc
  args="${args//,/ }"

  OUT_BY_SRC["$src"]="$out"
  ARGS_BY_SRC["$src"]="$args"
  sources+=("$src")
done < "$CONFIG_FILE"

(( ${#sources[@]} > 0 )) || { echo "No valid mappings" >&2; exit 1; }

build_one() {
  local src="$1"
  local out="${OUT_BY_SRC[$src]}"
  local args="${ARGS_BY_SRC[$src]}"

  [[ -f "$src" ]] || return 0
  mkdir -p "$(dirname "$out")"

  # Debounce: ignore repeated triggers within 1s per file
  local stamp_dir="${XDG_RUNTIME_DIR:-/tmp}/fswatch-mappings"
  mkdir -p "$stamp_dir"
  local key
  key="$(echo -n "$src" | md5sum | awk '{print $1}')"
  local stamp="${stamp_dir}/${key}.stamp"
  local now
  now="$(date +%s)"
  if [[ -f "$stamp" ]]; then
    local last
    last="$(cat "$stamp" 2>/dev/null || echo 0)"
    if (( now - last < 1 )); then
      return 0
    fi
  fi
  echo "$now" > "$stamp"

  # Temp file MUST end with .pdf so pandoc knows the output format
  local tmp
  tmp="$(mktemp --suffix=.pdf "$(dirname "$out")/.pandoc_tmp_XXXXXX")"

  echo "[$(date)] $src → $out"
  if [[ -n "$args" ]]; then
    # shellcheck disable=SC2086
    pandoc "$src" -o "$tmp" $args
  else
    pandoc "$src" -o "$tmp"
  fi

  mv -f "$tmp" "$out"
}
fswatch -0 --latency "$LATENCY" "${sources[@]}" |
while IFS= read -r -d '' changed; do
  changed="$(_norm "$changed")"
  [[ -n "${OUT_BY_SRC[$changed]+x}" ]] && build_one "$changed"
done
