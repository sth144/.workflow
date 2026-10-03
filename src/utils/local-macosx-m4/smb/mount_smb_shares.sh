#!/usr/bin/env bash

set -u

STABLE_ROOT="${SMB_STABLE_ROOT:-$HOME/media}"
DRIVE_ROOT="${SMB_DRIVE_ROOT:-$HOME/Drive}"
MOUNT_ROOT="${SMB_MOUNT_ROOT:-$STABLE_ROOT/.mounts}"
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/workflow"
STATE_DIR="$LOG_DIR/smb-state"
NOTIFIER="${SMB_NOTIFIER:-/opt/homebrew/bin/terminal-notifier}"
mkdir -p "$STABLE_ROOT" "$DRIVE_ROOT" "$MOUNT_ROOT" "$LOG_DIR" "$STATE_DIR"

LOCK_DIR="$LOG_DIR/mount_smb_shares.lock"

# A run can outlast the agent's 60s interval when several hosts time out.
# Overlapping runs race each other over mounts and symlinks, so only one wins;
# the loser exits quietly and tries again next cycle.
acquire_lock() {
    local owner

    if mkdir "$LOCK_DIR" 2>/dev/null; then
        printf '%s\n' "$$" >"$LOCK_DIR/pid"
        return 0
    fi

    owner="$(cat "$LOCK_DIR/pid" 2>/dev/null || true)"
    if [[ -n "$owner" ]] && kill -0 "$owner" 2>/dev/null; then
        return 1
    fi

    rm -rf "$LOCK_DIR"
    mkdir "$LOCK_DIR" 2>/dev/null || return 1
    printf '%s\n' "$$" >"$LOCK_DIR/pid"
    return 0
}

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >>"$LOG_DIR/smb-mounts.log"
}

# Banners come from the LaunchAgent, which runs inside the GUI session, so
# terminal-notifier can post directly. osascript is the fallback for a machine
# where the brew binary is missing; argv keeps the text out of the script body
# so a share name can never break the quoting.
notify() {
    local title="$1"
    local message="$2"
    local group="$3"

    if [[ -x "$NOTIFIER" ]]; then
        "$NOTIFIER" -title "$title" -message "$message" -group "$group" \
            >/dev/null 2>&1 && return 0
    fi

    /usr/bin/osascript - "$title" "$message" >/dev/null 2>&1 <<'OSA'
on run argv
    display notification (item 2 of argv) with title (item 1 of argv)
end run
OSA
}

# Alert on a change of state only. A box that stays down for a week costs one
# banner, not one per polling cycle; a share that comes back says so. The first
# sighting of a healthy share is silent -- there is nothing to announce.
report_status() {
    local alias_name="$1"
    local status="$2"
    local message="$3"
    local state_file="$STATE_DIR/$alias_name"
    local previous=""

    if [[ -f "$state_file" ]]; then
        previous="$(cat "$state_file" 2>/dev/null || true)"
    fi
    printf '%s\n' "$status" >"$state_file"

    [[ "$status" == "$previous" ]] && return 0
    [[ -z "$previous" && "$status" == "ok" ]] && return 0

    notify "SMB: $alias_name" "$message" "com.workflow.mount-smb.$alias_name"
    log "alert [$alias_name] ${previous:-unknown} -> $status"
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

# Only consulted once port 445 has already failed, to classify the failure:
# a host that answers ICMP but refuses 445 has lost smbd, not power.
host_pingable() {
    local host_tokens_csv="$1"
    local token
    local -a tokens

    IFS=',' read -r -a tokens <<<"$host_tokens_csv"
    for token in "${tokens[@]}"; do
        if /sbin/ping -c 1 -t 2 "$token" >/dev/null 2>&1; then
            return 0
        fi
    done

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
        # nc's default resolution can stall on mDNS/IPv6 and report a
        # reachable host as closed, so retry the name pinned to IPv4.
        if /usr/bin/nc -G 2 -z "$token" 445 >/dev/null 2>&1 ||
            /usr/bin/nc -4 -G 2 -z "$token" 445 >/dev/null 2>&1; then
            return 0
        fi
    done

    return 1
}

# mount_smbfs has no keychain integration of its own: unauthenticated it only
# succeeds when an authenticated session to that server already exists. So look
# the password up ourselves and pass it explicitly. (The NetAuth/osascript
# "mount volume" fallback this replaced *did* read the keychain, but popped a
# blocking GUI auth dialog whenever a credential was stale -- a nag every
# polling cycle. Nothing here ever shows UI; failures are logged and dropped.)
#
# The password is visible to `ps` for the duration of the mount call. That is
# inherent to mount_smbfs, which only accepts a credential inside the URL.
keychain_password() {
    local user="$1"
    shift
    local key

    for key in "$@"; do
        if /usr/bin/security find-internet-password \
            -s "$key" -a "$user" -r 'smb ' -w 2>/dev/null; then
            return 0
        fi
    done

    return 1
}

url_encode() {
    PW="$1" /usr/bin/python3 -c \
        'import os, urllib.parse; print(urllib.parse.quote(os.environ["PW"], safe=""))'
}

mount_share() {
    local alias_name="$1"
    local url="$2"
    local host_tokens_csv="$3"
    local share_name="$4"
    local mount_dir="$MOUNT_ROOT/$alias_name"
    local body user host password
    local -a keys

    body="${url#smb://}"
    user="${body%%@*}"
    host="${body#*@}"
    host="${host%%/*}"

    IFS=',' read -r -a keys <<<"$host_tokens_csv"
    if ! password="$(keychain_password "$user" "${keys[@]}")"; then
        log "no keychain credential for $alias_name ($user@$host)"
        return 1
    fi

    mkdir -p "$mount_dir"
    if /sbin/mount -t smbfs -o nobrowse,soft,noowners \
        "//${user}:$(url_encode "$password")@${host}/${share_name}" \
        "$mount_dir" >/dev/null 2>&1; then
        return 0
    fi

    log "credential rejected for $alias_name ($user@$host/$share_name)"
    return 1
}

ensure_share() {
    local alias_name="$1"
    local url="$2"
    local host_tokens_csv="$3"
    local share_name="$4"
    local mount_path

    if mount_path="$(find_mount_path "$host_tokens_csv" "$share_name")"; then
        refresh_link "$alias_name" "$mount_path"
        report_status "$alias_name" ok "Mounted again at $mount_path."
        return 0
    fi

    if ! server_reachable "$host_tokens_csv"; then
        remove_link "$alias_name"
        if host_pingable "$host_tokens_csv"; then
            report_status "$alias_name" smb_down \
                "Host is up but port 445 is refusing connections -- smbd is down."
        else
            report_status "$alias_name" host_down "Server is unreachable."
        fi
        log "server unavailable for $alias_name"
        return 1
    fi

    if mount_share "$alias_name" "$url" "$host_tokens_csv" "$share_name" && mount_path="$(find_mount_path "$host_tokens_csv" "$share_name")"; then
        refresh_link "$alias_name" "$mount_path"
        report_status "$alias_name" ok "Mounted again at $mount_path."
        log "mounted $alias_name -> $mount_path"
        return 0
    fi

    remove_link "$alias_name"
    report_status "$alias_name" auth_fail \
        "Reachable, but the saved credential is missing or was rejected. Run set_smb_credential.sh."
    return 1
}

# alias|smb url|keychain/host lookup keys (csv)|share name
#
# Every entry stays enabled. A share whose server is down, or whose credential
# is missing or stale, fails silently and logs a line to smb-mounts.log -- it
# costs one quick attempt per cycle and recovers on its own the moment the box
# or the password comes back. Nothing here can interrupt the user.
shares=(
    "sthinds|smb://sthinds@sthinds.local/sthinds|sthinds.local,sthinds,192.168.1.235,STHINDS._smb._tcp.local|sthinds"
    "D|smb://sthinds@sthinds.local/D|sthinds.local,sthinds,192.168.1.235,STHINDS._smb._tcp.local|D"
    "NAS|smb://sthinds@openmediavault.local/NAS|openmediavault.local,openmediavault,192.168.1.245|NAS"
    "omv|smb://sthinds@openmediavault.local/sthinds|openmediavault.local,openmediavault,192.168.1.245|sthinds"
    "pi|smb://pi@home.assistant/pi|home.assistant,raspberrypi.local,raspberrypi,192.168.1.243|pi"
    "pc0|smb://picocluster@pc0/picocluster|pc0,192.168.1.240,PC0._smb._tcp.local|picocluster"
    "pc1|smb://picocluster@pc1/picocluster|pc1,192.168.1.241,PC1._smb._tcp.local|picocluster"
    "pc2|smb://picocluster@pc2/picocluster|pc2,192.168.1.242,PC2._smb._tcp.local|picocluster"
)

if ! acquire_lock; then
    exit 0
fi
trap 'rm -rf "$LOCK_DIR"' EXIT

for spec in "${shares[@]}"; do
    IFS='|' read -r alias_name url host_tokens share_name <<<"$spec"
    ensure_share "$alias_name" "$url" "$host_tokens" "$share_name"
done
