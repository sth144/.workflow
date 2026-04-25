#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)

usage() {
    cat <<'EOF'
Usage:
  restore_local_backup.sh verify <snapshot-dir>
  restore_local_backup.sh extract-home <snapshot-dir> <target-dir>
  restore_local_backup.sh extract-etc <snapshot-dir> <target-dir>
  restore_local_backup.sh restore-packages <snapshot-dir>
  restore_local_backup.sh show-manifest <snapshot-dir>

Notes:
  - <snapshot-dir> should point at one snapshot directory under snapshots/ or current/.
  - extract-home and extract-etc unpack the archived trees into <target-dir>.
  - restore-packages restores apt sources/keyrings and package selections. Review the
    snapshot before running it on a live system.
EOF
}

log() {
    printf '%s\n' "$*" >&2
}

fail() {
    log "ERROR: $*"
    exit 1
}

pick_tar_flags() {
    local archive_path="$1"
    case "$archive_path" in
        *.tar.zst)
            if ! command -v zstd >/dev/null 2>&1; then
                fail "zstd is required to restore $archive_path"
            fi
            TAR_FLAG=(-I "zstd -d")
            ;;
        *.tar.gz)
            TAR_FLAG=(-z)
            ;;
        *)
            fail "Unsupported archive type: $archive_path"
            ;;
    esac
}

find_archive() {
    local snapshot_dir="$1"
    local archive_type="$2"
    local archive_path

    archive_path=$(find "$snapshot_dir/$archive_type" -maxdepth 1 -type f \( -name '*.tar.zst' -o -name '*.tar.gz' \) | sort | head -n 1)
    if [[ -z "$archive_path" ]]; then
        fail "Could not find archived $archive_type data in $snapshot_dir/$archive_type"
    fi
    printf '%s\n' "$archive_path"
}

verify_snapshot() {
    local snapshot_dir="$1"

    [[ -d "$snapshot_dir" ]] || fail "Snapshot directory not found: $snapshot_dir"
    [[ -f "$snapshot_dir/SHA256SUMS" ]] || fail "Missing SHA256SUMS in $snapshot_dir"

    (
        cd "$snapshot_dir"
        sha256sum -c SHA256SUMS
    )
}

extract_archive() {
    local snapshot_dir="$1"
    local archive_type="$2"
    local target_dir="$3"
    local archive_path

    [[ -d "$target_dir" ]] || fail "Target directory does not exist: $target_dir"
    archive_path=$(find_archive "$snapshot_dir" "$archive_type")
    pick_tar_flags "$archive_path"

    tar -C "$target_dir" "${TAR_FLAG[@]}" -xpf "$archive_path"
}

restore_packages() {
    local snapshot_dir="$1"
    local package_dir="$snapshot_dir/packages"

    [[ -f "$package_dir/Package.list" ]] || fail "Missing Package.list in $package_dir"
    [[ -d "$package_dir/etc-apt" ]] || fail "Missing etc-apt directory in $package_dir"

    cp -a "$package_dir/etc-apt/." /etc/apt/

    if [[ -f "$package_dir/trusted.gpg" ]]; then
        cp -a "$package_dir/trusted.gpg" /etc/apt/trusted.gpg
    fi
    if [[ -d "$package_dir/trusted.gpg.d" ]]; then
        mkdir -p /etc/apt/trusted.gpg.d
        cp -a "$package_dir/trusted.gpg.d/." /etc/apt/trusted.gpg.d/
    fi
    if [[ -d "$package_dir/keyrings" ]]; then
        mkdir -p /etc/apt/keyrings
        cp -a "$package_dir/keyrings/." /etc/apt/keyrings/
    fi

    apt-get update
    dpkg --set-selections <"$package_dir/Package.list"
    apt-get -y dselect-upgrade
}

show_manifest() {
    local snapshot_dir="$1"
    [[ -f "$snapshot_dir/manifest.json" ]] || fail "Missing manifest.json in $snapshot_dir"
    cat "$snapshot_dir/manifest.json"
}

main() {
    local command_name="${1:-}"
    local snapshot_dir="${2:-}"
    local target_dir="${3:-}"

    case "$command_name" in
        verify)
            [[ -n "$snapshot_dir" ]] || fail "verify requires <snapshot-dir>"
            verify_snapshot "$snapshot_dir"
            ;;
        extract-home)
            [[ -n "$snapshot_dir" && -n "$target_dir" ]] || fail "extract-home requires <snapshot-dir> <target-dir>"
            verify_snapshot "$snapshot_dir"
            extract_archive "$snapshot_dir" "home" "$target_dir"
            ;;
        extract-etc)
            [[ -n "$snapshot_dir" && -n "$target_dir" ]] || fail "extract-etc requires <snapshot-dir> <target-dir>"
            verify_snapshot "$snapshot_dir"
            extract_archive "$snapshot_dir" "etc" "$target_dir"
            ;;
        restore-packages)
            [[ -n "$snapshot_dir" ]] || fail "restore-packages requires <snapshot-dir>"
            verify_snapshot "$snapshot_dir"
            restore_packages "$snapshot_dir"
            ;;
        show-manifest)
            [[ -n "$snapshot_dir" ]] || fail "show-manifest requires <snapshot-dir>"
            show_manifest "$snapshot_dir"
            ;;
        -h|--help|help|"")
            usage
            ;;
        *)
            fail "Unknown command: $command_name"
            ;;
    esac
}

main "$@"
