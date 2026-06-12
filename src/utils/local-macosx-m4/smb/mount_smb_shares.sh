#!/usr/bin/env bash

set -u

STABLE_ROOT="${SMB_STABLE_ROOT:-$HOME/media}"
DRIVE_ROOT="${SMB_DRIVE_ROOT:-$HOME/Drive}"
MOUNT_ROOT="${SMB_MOUNT_ROOT:-$STABLE_ROOT/.mounts}"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/workflow"
mkdir -p "$STABLE_ROOT" "$DRIVE_ROOT" "$MOUNT_ROOT" "$LOG_DIR"

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_DIR/smb-mounts.log"
}

to_lower() {
    printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

find_mount_path() {
    local host_tokens_csv="$1"
    local share_name="$2"
    local share_lc token token_lc remote path remote_body remote_server remote_share
    local remote_server_lc remote_share_lc

    share_lc="$(to_lower "$share_name")"

    while IFS= read -r line; do
        remote="${line%% on /*}"
        path="${line#* on }"
        path="${path%% (*}"
        remote_body="${remote#//}"
        remote_body="${remote_body#*@}"
        remote_server="${remote_body%%/*}"
        remote_share="${remote_body#*/}"
        remote_server_lc="$(to_lower "$remote_server")"
        remote_share_lc="$(to_lower "$remote_share")"

        [[ "$remote_share_lc" == "$share_lc" ]] || continue

        IFS=',' read -r -a tokens <<<"$host_tokens_csv"
        for token in "${tokens[@]}"; do
            token_lc="$(to_lower "$token")"
            if [[ "$remote_server_lc" == "$token_lc" ]] || [[ "$remote_server_lc" == "$token_lc".* ]]; then
                printf '%s\n' "$path"
                return 0
            fi
        done
    done < <(mount | awk '/ \(smbfs,/{print}')

    return 1
}

refresh_link() {
    local alias_name="$1"
    local mount_path="$2"
    local link_path="$STABLE_ROOT/$alias_name"
    local drive_link_path="$DRIVE_ROOT/$alias_name"

    ln -sfn "$mount_path" "$link_path"
    ln -sfn "$link_path" "$drive_link_path"
}

remove_link() {
    local alias_name="$1"
    local link_path="$STABLE_ROOT/$alias_name"
    local drive_link_path="$DRIVE_ROOT/$alias_name"

    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    fi
    if [[ -L "$drive_link_path" ]]; then
        rm -f "$drive_link_path"
    fi
}

server_reachable() {
    local host_tokens_csv="$1"
    local token
    local -a tokens

    IFS=',' read -r -a tokens <<<"$host_tokens_csv"
    for token in "${tokens[@]}"; do
        if /usr/bin/nc -G 2 -z "$token" 445 >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

smbfs_url() {
    local url="$1"
    printf '//%s\n' "${url#smb://}"
}

mount_share() {
    local alias_name="$1"
    local url="$2"
    local mount_dir="$MOUNT_ROOT/$alias_name"

    mkdir -p "$mount_dir"
    /sbin/mount -t smbfs -o nobrowse,soft,noowners,nopassprompt "$(smbfs_url "$url")" "$mount_dir" >/dev/null 2>&1
}

ensure_share() {
    local alias_name="$1"
    local url="$2"
    local host_tokens_csv="$3"
    local share_name="$4"
    local mount_path

    if mount_path="$(find_mount_path "$host_tokens_csv" "$share_name")"; then
        refresh_link "$alias_name" "$mount_path"
        return 0
    fi

    if ! server_reachable "$host_tokens_csv"; then
        remove_link "$alias_name"
        log "server unavailable for $alias_name"
        return 1
    fi

    if mount_share "$alias_name" "$url" && mount_path="$(find_mount_path "$host_tokens_csv" "$share_name")"; then
        refresh_link "$alias_name" "$mount_path"
        log "mounted $alias_name -> $mount_path"
        return 0
    fi

    remove_link "$alias_name"
    log "mount unavailable for $alias_name"
    return 1
}

shares=(
    "sthinds|smb://sthinds@sthinds.local/sthinds|sthinds.local,sthinds,192.168.1.235|sthinds"
    "D|smb://sthinds@sthinds.local/D|sthinds.local,sthinds,192.168.1.235|D"
    "NAS|smb://sthinds@openmediavault.local/NAS|openmediavault.local,openmediavault,192.168.1.245|NAS"
    "omv|smb://sthinds@openmediavault.local/sthinds|openmediavault.local,openmediavault,192.168.1.245|sthinds"
    "pi|smb://pi@home.assistant/pi|home.assistant,raspberrypi,192.168.1.243|pi"
    "pc0|smb://picocluster@pc0/picocluster|pc0,192.168.1.240|picocluster"
    "pc1|smb://picocluster@pc1/picocluster|pc1,192.168.1.241|picocluster"
    "pc2|smb://picocluster@pc2/picocluster|pc2,192.168.1.242|picocluster"
)

for spec in "${shares[@]}"; do
    IFS='|' read -r alias_name url host_tokens share_name <<<"$spec"
    ensure_share "$alias_name" "$url" "$host_tokens" "$share_name"
done
