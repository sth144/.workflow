#!/usr/bin/env bash
set -euo pipefail

TARGETS_FILE="${BUCKET_BY_DATE_TARGETS_FILE:-$HOME/.config/.env.BUCKET_BY_DATE_TARGETS}"
BUCKET_SCRIPT="${BUCKET_FILES_BY_DATE_SCRIPT:-/usr/local/bin/fs/bucket_files_by_date.sh}"

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  echo "[$(timestamp)] bucket_files_by_date_targets: $*"
}

trim() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s\n' "$value"
}

if [[ ! -f "$TARGETS_FILE" ]]; then
  log "targets file not found, skipping: $TARGETS_FILE"
  exit 0
fi

if [[ ! -x "$BUCKET_SCRIPT" ]]; then
  log "bucket script not executable, skipping: $BUCKET_SCRIPT"
  exit 0
fi

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  target="$(trim "$raw_line")"

  [[ -n "$target" ]] || continue
  [[ "$target" =~ ^# ]] && continue

  if [[ "$target" != /* ]]; then
    log "skipping non-absolute target: $target"
    continue
  fi

  if [[ ! -d "$target" ]]; then
    log "target directory missing, skipping: $target"
    continue
  fi

  if "$BUCKET_SCRIPT" "$target"; then
    log "bucketized: $target"
  else
    log "bucketize failed, continuing: $target"
  fi
done < "$TARGETS_FILE"
