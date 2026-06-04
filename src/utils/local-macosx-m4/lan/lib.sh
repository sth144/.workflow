#!/usr/bin/env bash

set -euo pipefail

LAN_LIB_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && /bin/pwd -P)
LAN_HOME="${LAN_HOME:-$LAN_LIB_DIR}"
LAN_INVENTORY_DEFAULT="${LAN_INVENTORY:-$LAN_HOME/inventory/lan.yml}"

lan_die() {
    echo "error: $*" >&2
    exit 1
}

lan_require_cmd() {
    command -v "$1" >/dev/null 2>&1 || lan_die "missing required command: $1"
}

lan_resolve_inventory() {
    local inventory="${1:-$LAN_INVENTORY_DEFAULT}"
    [ -f "$inventory" ] || lan_die "inventory not found: $inventory"
    printf '%s\n' "$inventory"
}

lan_resolve_playbook() {
    local value="$1"
    if [ -f "$value" ]; then
        printf '%s\n' "$value"
        return 0
    fi

    if [ -f "$LAN_HOME/playbooks/$value" ]; then
        printf '%s\n' "$LAN_HOME/playbooks/$value"
        return 0
    fi

    if [ -f "$LAN_HOME/playbooks/$value.yml" ]; then
        printf '%s\n' "$LAN_HOME/playbooks/$value.yml"
        return 0
    fi

    lan_die "playbook not found: $value"
}
