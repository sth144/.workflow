#!/usr/bin/env bash

# One-way, additive backup for content shared by several machines.  In
# particular, do not add --delete or remove --ignore-existing: this job must
# never remove or replace files already present on the NAS.

set -euo pipefail

SOURCE_DOCUMENTS="$HOME/Documents"
SOURCE_PICTURES="$HOME/Pictures"
NAS_ROOT="$HOME/Drive/NAS"
DESTINATION_DOCUMENTS="$NAS_ROOT/Documents"
DESTINATION_PICTURES="$NAS_ROOT/Pictures"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/workflow"
LOCK_DIR="$LOG_DIR/backup-documents-pictures.lock"

mkdir -p "$LOG_DIR"

if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    printf '%s backup already running; skipping\n' "$(date '+%Y-%m-%d %H:%M:%S')" >>"$LOG_DIR/backup-documents-pictures.log"
    exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG_DIR/backup-documents-pictures.log"
}

if [[ ! -d "$NAS_ROOT" ]]; then
    log "NAS is unavailable at $NAS_ROOT; skipping backup."
    exit 0
fi

backup_directory() {
    local source="$1"
    local destination="$2"

    if [[ ! -d "$source" ]]; then
        log "source is unavailable at $source; skipping."
        return 0
    fi

    mkdir -p "$destination"
    log "adding missing files from $source to $destination"
    rsync -a --ignore-existing --human-readable --itemize-changes "$source/" "$destination/"
}

backup_directory "$SOURCE_DOCUMENTS" "$DESTINATION_DOCUMENTS"
backup_directory "$SOURCE_PICTURES" "$DESTINATION_PICTURES"
log "backup complete"
