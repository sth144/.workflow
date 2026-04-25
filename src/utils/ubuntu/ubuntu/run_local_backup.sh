#!/bin/bash

set -eEuo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)
DEFAULT_CONFIG_PATH="$SCRIPT_DIR/workflow-backup.conf"
CONFIG_PATH="${WORKFLOW_BACKUP_CONFIG:-$DEFAULT_CONFIG_PATH}"
LOCK_FILE="${WORKFLOW_BACKUP_LOCK_FILE:-/var/lock/workflow-backup.lock}"

STAGE_NAME="initializing"
FAILURE_RECORDED=0
LOCAL_BACKUP_ROOT=""
REMOTE_BACKUP_ROOT=""
SNAPSHOT_ID=""
SNAPSHOT_DIR=""
REMOTE_SNAPSHOT_DIR=""
LATEST_LOCAL_STATUS=""
LATEST_STATUS=""

log() {
    printf '%s %s\n' "$(date --iso-8601=seconds)" "$*" >&2
}

json_escape() {
    local value=${1//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

write_json_file() {
    local output_path="$1"
    local status="$2"
    local message="$3"
    local completed_at="$4"
    local remote_state="$5"

    mkdir -p "$(dirname "$output_path")"
    cat >"$output_path" <<EOF
{
  "status": "$(json_escape "$status")",
  "stage": "$(json_escape "$STAGE_NAME")",
  "snapshot_id": "$(json_escape "${SNAPSHOT_ID:-}")",
  "local_snapshot_dir": "$(json_escape "${SNAPSHOT_DIR:-}")",
  "remote_snapshot_dir": "$(json_escape "${REMOTE_SNAPSHOT_DIR:-}")",
  "completed_at": "$(json_escape "$completed_at")",
  "remote_state": "$(json_escape "$remote_state")",
  "message": "$(json_escape "$message")"
}
EOF
}

record_failure() {
    local message="$1"
    local timestamp

    if [[ "$FAILURE_RECORDED" -eq 1 ]]; then
        return
    fi
    FAILURE_RECORDED=1
    timestamp="$(date --iso-8601=seconds)"

    if [[ -n "$LOCAL_BACKUP_ROOT" ]]; then
        mkdir -p "$LOCAL_BACKUP_ROOT"
        write_json_file "$LOCAL_BACKUP_ROOT/latest-failure.json" "failed" "$message" "$timestamp" "failed"
    fi
}

on_error() {
    local exit_code="$1"
    local line_no="$2"

    record_failure "Backup failed during ${STAGE_NAME} (line ${line_no}, exit ${exit_code})."
    log "ERROR: Backup failed during ${STAGE_NAME} (line ${line_no}, exit ${exit_code})."
    exit "$exit_code"
}

trap 'on_error $? $LINENO' ERR

load_config() {
    if [[ ! -f "$CONFIG_PATH" ]]; then
        log "ERROR: Missing workflow backup config at $CONFIG_PATH"
        exit 1
    fi

    # shellcheck disable=SC1090
    source "$CONFIG_PATH"

    : "${BACKUP_NAME:?BACKUP_NAME must be set in $CONFIG_PATH}"
    : "${BACKUP_OWNER:?BACKUP_OWNER must be set in $CONFIG_PATH}"
    : "${BACKUP_GROUP:?BACKUP_GROUP must be set in $CONFIG_PATH}"
    : "${BACKUP_HOME:?BACKUP_HOME must be set in $CONFIG_PATH}"
    : "${LOCAL_MOUNTPOINT:?LOCAL_MOUNTPOINT must be set in $CONFIG_PATH}"
    : "${REMOTE_MOUNTPOINT:?REMOTE_MOUNTPOINT must be set in $CONFIG_PATH}"
    : "${LOCAL_BACKUP_ROOT:?LOCAL_BACKUP_ROOT must be set in $CONFIG_PATH}"
    : "${REMOTE_BACKUP_ROOT:?REMOTE_BACKUP_ROOT must be set in $CONFIG_PATH}"
    : "${LOCAL_MIN_FREE_GB:?LOCAL_MIN_FREE_GB must be set in $CONFIG_PATH}"
    : "${REMOTE_MIN_FREE_GB:?REMOTE_MIN_FREE_GB must be set in $CONFIG_PATH}"
    : "${KEEP_DAILY_DAYS:?KEEP_DAILY_DAYS must be set in $CONFIG_PATH}"
    : "${KEEP_WEEKLY_WEEKS:?KEEP_WEEKLY_WEEKS must be set in $CONFIG_PATH}"
    : "${KEEP_MONTHLY_MONTHS:?KEEP_MONTHLY_MONTHS must be set in $CONFIG_PATH}"

    if ! declare -p HOME_INCLUDE_PATHS >/dev/null 2>&1; then
        log "ERROR: HOME_INCLUDE_PATHS must be defined in $CONFIG_PATH"
        exit 1
    fi
    if ! declare -p HOME_EXCLUDE_PATTERNS >/dev/null 2>&1; then
        HOME_EXCLUDE_PATTERNS=()
    fi
    if ! declare -p ETC_INCLUDE_PATHS >/dev/null 2>&1; then
        log "ERROR: ETC_INCLUDE_PATHS must be defined in $CONFIG_PATH"
        exit 1
    fi

    BACKUP_HOSTNAME=${BACKUP_HOSTNAME:-$(hostname)}
    REQUIRE_REMOTE_MIRROR=${REQUIRE_REMOTE_MIRROR:-true}
    RSYNC_BIN=${RSYNC_BIN:-rsync}
    SHA256_BIN=${SHA256_BIN:-sha256sum}
}

acquire_lock() {
    mkdir -p "$(dirname "$LOCK_FILE")"
    exec 9>"$LOCK_FILE"
    if ! flock -n 9; then
        log "ERROR: Another workflow backup run already holds $LOCK_FILE"
        exit 1
    fi
}

pick_tar_compressor() {
    if command -v zstd >/dev/null 2>&1; then
        TAR_COMPRESS_PROGRAM="zstd -T0 -19"
        TAR_EXTENSION="tar.zst"
        return
    fi

    if command -v gzip >/dev/null 2>&1; then
        TAR_COMPRESS_PROGRAM="gzip -9"
        TAR_EXTENSION="tar.gz"
        return
    fi

    log "ERROR: Neither zstd nor gzip is installed; cannot create archives"
    exit 1
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        log "ERROR: Required command '$command_name' is not installed"
        exit 1
    fi
}

require_mountpoint() {
    local mount_path="$1"
    if ! mountpoint -q "$mount_path"; then
        log "ERROR: Required mount point '$mount_path' is not mounted"
        exit 1
    fi
}

require_free_space() {
    local mount_path="$1"
    local required_gb="$2"
    local available_kb
    local available_gb

    available_kb=$(df -Pk "$mount_path" | awk 'NR == 2 { print $4 }')
    available_gb=$((available_kb / 1024 / 1024))

    if (( available_gb < required_gb )); then
        log "ERROR: $mount_path has ${available_gb}GB free; ${required_gb}GB required"
        exit 1
    fi
}

prepare_roots() {
    mkdir -p "$LOCAL_BACKUP_ROOT" "$LOCAL_BACKUP_ROOT/snapshots" "$LOCAL_BACKUP_ROOT/.tmp"
    LATEST_LOCAL_STATUS="$LOCAL_BACKUP_ROOT/latest-local-success.json"
    LATEST_STATUS="$LOCAL_BACKUP_ROOT/latest-success.json"

    if [[ "$REQUIRE_REMOTE_MIRROR" == "true" ]]; then
        mkdir -p "$REMOTE_BACKUP_ROOT" "$REMOTE_BACKUP_ROOT/snapshots" "$REMOTE_BACKUP_ROOT/.incoming"
    fi
}

prepare_snapshot_paths() {
    SNAPSHOT_ID=$(date '+%Y-%m-%d_%H%M%S')
    TMP_SNAPSHOT_DIR="$LOCAL_BACKUP_ROOT/.tmp/$SNAPSHOT_ID"
    SNAPSHOT_DIR="$LOCAL_BACKUP_ROOT/snapshots/$SNAPSHOT_ID"
    REMOTE_SNAPSHOT_DIR="$REMOTE_BACKUP_ROOT/snapshots/$SNAPSHOT_ID"
    mkdir -p "$TMP_SNAPSHOT_DIR"/{bin,checksums,etc,home,metadata,packages,trees}
}

write_snapshot_notes() {
    cat >"$TMP_SNAPSHOT_DIR/RESTORE.txt" <<EOF
Workflow backup snapshot: $SNAPSHOT_ID

Primary restore helper:
  ./bin/restore_local_backup.sh --help

Common workflows:
  ./bin/restore_local_backup.sh verify .
  sudo ./bin/restore_local_backup.sh extract-home . /
  sudo ./bin/restore_local_backup.sh extract-etc . /
  sudo ./bin/restore_local_backup.sh restore-packages .

Archives in this snapshot:
  home/home.$TAR_EXTENSION
  etc/etc.$TAR_EXTENSION

Package metadata:
  packages/Package.list
  packages/Package.versions.tsv
  packages/apt-manual.txt
  packages/etc-apt/
EOF
}

copy_support_files() {
    install -m 0755 "$SCRIPT_DIR/restore_local_backup.sh" "$TMP_SNAPSHOT_DIR/bin/restore_local_backup.sh"
    install -m 0644 "$CONFIG_PATH" "$TMP_SNAPSHOT_DIR/metadata/workflow-backup.conf"
    write_snapshot_notes
}

collect_packages() {
    STAGE_NAME="collecting package metadata"

    dpkg --get-selections >"$TMP_SNAPSHOT_DIR/packages/Package.list"
    dpkg-query -W -f='${binary:Package}\t${Version}\n' >"$TMP_SNAPSHOT_DIR/packages/Package.versions.tsv"
    apt-mark showmanual | sort >"$TMP_SNAPSHOT_DIR/packages/apt-manual.txt"

    mkdir -p "$TMP_SNAPSHOT_DIR/packages/etc-apt"
    "$RSYNC_BIN" -a /etc/apt/ "$TMP_SNAPSHOT_DIR/packages/etc-apt/"

    if [[ -f /etc/apt/trusted.gpg ]]; then
        cp /etc/apt/trusted.gpg "$TMP_SNAPSHOT_DIR/packages/"
    fi
    if [[ -d /etc/apt/trusted.gpg.d ]]; then
        mkdir -p "$TMP_SNAPSHOT_DIR/packages/trusted.gpg.d"
        "$RSYNC_BIN" -a /etc/apt/trusted.gpg.d/ "$TMP_SNAPSHOT_DIR/packages/trusted.gpg.d/"
    fi
    if [[ -d /etc/apt/keyrings ]]; then
        mkdir -p "$TMP_SNAPSHOT_DIR/packages/keyrings"
        "$RSYNC_BIN" -a /etc/apt/keyrings/ "$TMP_SNAPSHOT_DIR/packages/keyrings/"
    fi
    if command -v snap >/dev/null 2>&1; then
        snap list >"$TMP_SNAPSHOT_DIR/packages/snap.list.txt" || true
    fi
}

build_rsync_excludes() {
    RSYNC_EXCLUDES=()
    local pattern
    for pattern in "${HOME_EXCLUDE_PATTERNS[@]}"; do
        RSYNC_EXCLUDES+=(--exclude="$pattern")
    done
}

capture_home_tree() {
    STAGE_NAME="capturing home data"

    local source_path
    local found=()
    local missing=()
    build_rsync_excludes

    mkdir -p "$TMP_SNAPSHOT_DIR/trees/home"

    for source_path in "${HOME_INCLUDE_PATHS[@]}"; do
        if [[ -e "$source_path" ]]; then
            found+=("$source_path")
            "$RSYNC_BIN" -aHAX --numeric-ids --relative "${RSYNC_EXCLUDES[@]}" "$source_path" "$TMP_SNAPSHOT_DIR/trees/home/"
        else
            missing+=("$source_path")
            log "WARN: Skipping missing home path $source_path"
        fi
    done

    printf '%s\n' "${found[@]}" >"$TMP_SNAPSHOT_DIR/metadata/home-includes.found.txt"
    printf '%s\n' "${missing[@]}" >"$TMP_SNAPSHOT_DIR/metadata/home-includes.missing.txt"
}

capture_etc_tree() {
    STAGE_NAME="capturing system config"

    local source_path
    local found=()
    local missing=()

    mkdir -p "$TMP_SNAPSHOT_DIR/trees/etc"

    for source_path in "${ETC_INCLUDE_PATHS[@]}"; do
        if [[ -e "$source_path" ]]; then
            found+=("$source_path")
            "$RSYNC_BIN" -aHAX --numeric-ids --relative "$source_path" "$TMP_SNAPSHOT_DIR/trees/etc/"
        else
            missing+=("$source_path")
            log "WARN: Skipping missing /etc path $source_path"
        fi
    done

    printf '%s\n' "${found[@]}" >"$TMP_SNAPSHOT_DIR/metadata/etc-includes.found.txt"
    printf '%s\n' "${missing[@]}" >"$TMP_SNAPSHOT_DIR/metadata/etc-includes.missing.txt"
}

create_archives() {
    STAGE_NAME="creating archives"

    tar -C "$TMP_SNAPSHOT_DIR/trees" -I "$TAR_COMPRESS_PROGRAM" -cpf "$TMP_SNAPSHOT_DIR/home/home.$TAR_EXTENSION" home
    tar -C "$TMP_SNAPSHOT_DIR/trees" -I "$TAR_COMPRESS_PROGRAM" -cpf "$TMP_SNAPSHOT_DIR/etc/etc.$TAR_EXTENSION" etc
    tar -I "$TAR_COMPRESS_PROGRAM" -tf "$TMP_SNAPSHOT_DIR/home/home.$TAR_EXTENSION" >/dev/null
    tar -I "$TAR_COMPRESS_PROGRAM" -tf "$TMP_SNAPSHOT_DIR/etc/etc.$TAR_EXTENSION" >/dev/null

    rm -rf "$TMP_SNAPSHOT_DIR/trees"
}

write_manifest() {
    STAGE_NAME="writing manifest"

    cat >"$TMP_SNAPSHOT_DIR/manifest.json" <<EOF
{
  "backup_name": "$(json_escape "$BACKUP_NAME")",
  "backup_hostname": "$(json_escape "$BACKUP_HOSTNAME")",
  "snapshot_id": "$(json_escape "$SNAPSHOT_ID")",
  "created_at": "$(json_escape "$(date --iso-8601=seconds)")",
  "backup_owner": "$(json_escape "$BACKUP_OWNER")",
  "backup_home": "$(json_escape "$BACKUP_HOME")",
  "config_path": "$(json_escape "$CONFIG_PATH")",
  "local_backup_root": "$(json_escape "$LOCAL_BACKUP_ROOT")",
  "remote_backup_root": "$(json_escape "$REMOTE_BACKUP_ROOT")",
  "compression_program": "$(json_escape "$TAR_COMPRESS_PROGRAM")",
  "archive_extension": "$(json_escape "$TAR_EXTENSION")"
}
EOF
}

write_checksums() {
    STAGE_NAME="writing checksums"

    (
        cd "$TMP_SNAPSHOT_DIR"
        find . -type f ! -name 'SHA256SUMS' -print0 |
            sort -z |
            xargs -0 "$SHA256_BIN" >SHA256SUMS
        "$SHA256_BIN" -c SHA256SUMS >/dev/null
    )
}

publish_local_snapshot() {
    STAGE_NAME="publishing local snapshot"

    mv "$TMP_SNAPSHOT_DIR" "$SNAPSHOT_DIR"
    if [[ "$(id -u)" -eq 0 ]]; then
        chown -R "$BACKUP_OWNER:$BACKUP_GROUP" "$SNAPSHOT_DIR"
    fi
}

publish_current_copy() {
    local root_path="$1"
    local source_snapshot="$2"
    local tmp_current="$root_path/.current-${SNAPSHOT_ID}.tmp"
    local current_dir="$root_path/current"
    local previous_dir="$root_path/.current-previous"

    STAGE_NAME="updating $(basename "$root_path") current snapshot"

    rm -rf "$tmp_current" "$previous_dir"
    mkdir -p "$tmp_current"
    "$RSYNC_BIN" -a --delete "$source_snapshot/" "$tmp_current/"

    if [[ -e "$current_dir" ]]; then
        mv "$current_dir" "$previous_dir"
    fi
    mv "$tmp_current" "$current_dir"
    rm -rf "$previous_dir"
}

publish_remote_snapshot() {
    local incoming_dir="$REMOTE_BACKUP_ROOT/.incoming/$SNAPSHOT_ID"

    STAGE_NAME="mirroring snapshot to remote"

    rm -rf "$incoming_dir"
    mkdir -p "$incoming_dir"
    "$RSYNC_BIN" -a --delete "$SNAPSHOT_DIR/" "$incoming_dir/"
    mv "$incoming_dir" "$REMOTE_SNAPSHOT_DIR"
}

write_success_markers() {
    local timestamp="$1"

    STAGE_NAME="writing success metadata"

    rm -f "$LOCAL_BACKUP_ROOT/latest-failure.json"
    write_json_file "$LATEST_LOCAL_STATUS" "ok" "Local snapshot created successfully." "$timestamp" "not_synced"

    if [[ "$REQUIRE_REMOTE_MIRROR" == "true" ]]; then
        write_json_file "$LATEST_STATUS" "ok" "Local and remote snapshots created successfully." "$timestamp" "synced"
        cp "$LATEST_LOCAL_STATUS" "$REMOTE_BACKUP_ROOT/latest-local-success.json"
        cp "$LATEST_STATUS" "$REMOTE_BACKUP_ROOT/latest-success.json"
        rm -f "$REMOTE_BACKUP_ROOT/latest-failure.json"
    else
        cp "$LATEST_LOCAL_STATUS" "$LATEST_STATUS"
    fi
}

month_index() {
    local timestamp="$1"
    local year month
    year=$(date -d "$timestamp" '+%Y')
    month=$(date -d "$timestamp" '+%m')
    echo $((10#$year * 12 + 10#$month))
}

prune_snapshots() {
    local root_path="$1"
    local snapshots_dir="$root_path/snapshots"
    local now_epoch now_month
    local -a snapshot_dirs=()
    local snapshot_id snapshot_time snapshot_epoch age_days snapshot_week snapshot_month
    local -A keep_map=()
    local -A weekly_seen=()
    local -A monthly_seen=()

    if [[ ! -d "$snapshots_dir" ]]; then
        return
    fi

    now_epoch=$(date '+%s')
    now_month=$(month_index "now")

    mapfile -t snapshot_dirs < <(find "$snapshots_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort -r)

    for snapshot_id in "${snapshot_dirs[@]}"; do
        snapshot_time=${snapshot_id/_/ }
        if ! snapshot_epoch=$(date -d "$snapshot_time" '+%s' 2>/dev/null); then
            keep_map["$snapshot_id"]=1
            continue
        fi

        age_days=$(( (now_epoch - snapshot_epoch) / 86400 ))
        snapshot_week=$(date -d "$snapshot_time" '+%G-W%V')
        snapshot_month=$(month_index "$snapshot_time")

        if [[ "${#keep_map[@]}" -eq 0 ]]; then
            keep_map["$snapshot_id"]=1
            continue
        fi

        if (( age_days <= KEEP_DAILY_DAYS )); then
            keep_map["$snapshot_id"]=1
            continue
        fi

        if (( age_days <= KEEP_WEEKLY_WEEKS * 7 )); then
            if [[ -z "${weekly_seen[$snapshot_week]:-}" ]]; then
                keep_map["$snapshot_id"]=1
                weekly_seen["$snapshot_week"]=1
            fi
            continue
        fi

        if (( now_month - snapshot_month <= KEEP_MONTHLY_MONTHS )); then
            if [[ -z "${monthly_seen[$snapshot_month]:-}" ]]; then
                keep_map["$snapshot_id"]=1
                monthly_seen["$snapshot_month"]=1
            fi
            continue
        fi
    done

    for snapshot_id in "${snapshot_dirs[@]}"; do
        if [[ -z "${keep_map[$snapshot_id]:-}" ]]; then
            log "Pruning old snapshot $root_path/snapshots/$snapshot_id"
            rm -rf "$root_path/snapshots/$snapshot_id"
        fi
    done
}

main() {
    local completed_at

    load_config
    acquire_lock

    require_command flock
    require_command "$RSYNC_BIN"
    require_command "$SHA256_BIN"
    require_command tar
    require_command dpkg
    require_command apt-mark
    require_command mountpoint
    pick_tar_compressor

    STAGE_NAME="validating destinations"
    require_mountpoint "$LOCAL_MOUNTPOINT"
    require_free_space "$LOCAL_MOUNTPOINT" "$LOCAL_MIN_FREE_GB"

    if [[ "$REQUIRE_REMOTE_MIRROR" == "true" ]]; then
        require_mountpoint "$REMOTE_MOUNTPOINT"
        require_free_space "$REMOTE_MOUNTPOINT" "$REMOTE_MIN_FREE_GB"
    fi

    prepare_roots
    prepare_snapshot_paths
    copy_support_files
    collect_packages
    capture_home_tree
    capture_etc_tree
    create_archives
    write_manifest
    write_checksums
    publish_local_snapshot
    publish_current_copy "$LOCAL_BACKUP_ROOT" "$SNAPSHOT_DIR"

    completed_at=$(date --iso-8601=seconds)
    write_json_file "$LATEST_LOCAL_STATUS" "ok" "Local snapshot created successfully." "$completed_at" "not_synced"

    if [[ "$REQUIRE_REMOTE_MIRROR" == "true" ]]; then
        publish_remote_snapshot
        publish_current_copy "$REMOTE_BACKUP_ROOT" "$REMOTE_SNAPSHOT_DIR"
    fi

    completed_at=$(date --iso-8601=seconds)
    write_success_markers "$completed_at"
    prune_snapshots "$LOCAL_BACKUP_ROOT"
    if [[ "$REQUIRE_REMOTE_MIRROR" == "true" ]]; then
        prune_snapshots "$REMOTE_BACKUP_ROOT"
    fi

    FAILURE_RECORDED=1
    log "Backup complete: $SNAPSHOT_DIR"
    if [[ "$REQUIRE_REMOTE_MIRROR" == "true" ]]; then
        log "Remote mirror complete: $REMOTE_SNAPSHOT_DIR"
    fi
}

main "$@"
