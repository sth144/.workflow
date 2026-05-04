#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && /bin/pwd -P)
# Shared helpers keep inventory and playbook resolution consistent.
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<'EOF'
Usage:
  lan-ops.sh inventory [--inventory PATH] [--graph]
  lan-ops.sh list-playbooks
  lan-ops.sh ping <pattern> [--inventory PATH]
  lan-ops.sh facts <pattern> [--inventory PATH]
  lan-ops.sh playbook --playbook NAME_OR_PATH --limit PATTERN [--inventory PATH] [--approve] [-- ARGS...]
  lan-ops.sh ssh-check <host>
EOF
}

subcommand="${1:-}"
[ -n "$subcommand" ] || {
    usage
    exit 1
}
shift || true

case "$subcommand" in
    inventory)
        lan_require_cmd ansible-inventory
        inventory=""
        graph=0
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --inventory)
                    inventory="$2"
                    shift 2
                    ;;
                --graph)
                    graph=1
                    shift
                    ;;
                *)
                    lan_die "unknown inventory option: $1"
                    ;;
            esac
        done

        inventory=$(lan_resolve_inventory "$inventory")
        if [ "$graph" -eq 1 ]; then
            exec ansible-inventory -i "$inventory" --graph
        fi
        exec ansible-inventory -i "$inventory" --list
        ;;
    list-playbooks)
        find "$SCRIPT_DIR/playbooks" -maxdepth 1 -type f -name '*.yml' | sort
        ;;
    ping)
        lan_require_cmd ansible
        pattern="${1:-}"
        [ -n "$pattern" ] || lan_die "ping requires a host or group pattern"
        shift || true
        inventory=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --inventory)
                    inventory="$2"
                    shift 2
                    ;;
                *)
                    lan_die "unknown ping option: $1"
                    ;;
            esac
        done

        inventory=$(lan_resolve_inventory "$inventory")
        exec ansible -i "$inventory" "$pattern" -m ping
        ;;
    facts)
        lan_require_cmd ansible
        pattern="${1:-}"
        [ -n "$pattern" ] || lan_die "facts requires a host or group pattern"
        shift || true
        inventory=""
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --inventory)
                    inventory="$2"
                    shift 2
                    ;;
                *)
                    lan_die "unknown facts option: $1"
                    ;;
            esac
        done

        inventory=$(lan_resolve_inventory "$inventory")
        exec ansible -i "$inventory" "$pattern" -m setup -a 'gather_subset=min'
        ;;
    playbook)
        lan_require_cmd ansible-playbook
        inventory=""
        limit=""
        playbook=""
        approve=0
        extra_args=()

        while [ "$#" -gt 0 ]; do
            case "$1" in
                --inventory)
                    inventory="$2"
                    shift 2
                    ;;
                --limit)
                    limit="$2"
                    shift 2
                    ;;
                --playbook)
                    playbook="$2"
                    shift 2
                    ;;
                --approve|--apply)
                    approve=1
                    shift
                    ;;
                --)
                    shift
                    extra_args=("$@")
                    break
                    ;;
                *)
                    lan_die "unknown playbook option: $1"
                    ;;
            esac
        done

        [ -n "$limit" ] || lan_die "playbook requires --limit"
        [ -n "$playbook" ] || lan_die "playbook requires --playbook"

        inventory=$(lan_resolve_inventory "$inventory")
        playbook=$(lan_resolve_playbook "$playbook")

        if [ "$approve" -eq 1 ]; then
            if [ "${#extra_args[@]}" -gt 0 ]; then
                exec ansible-playbook -i "$inventory" "$playbook" --limit "$limit" --diff "${extra_args[@]}"
            fi
            exec ansible-playbook -i "$inventory" "$playbook" --limit "$limit" --diff
        fi

        if [ "${#extra_args[@]}" -gt 0 ]; then
            exec ansible-playbook -i "$inventory" "$playbook" --limit "$limit" --check --diff "${extra_args[@]}"
        fi

        exec ansible-playbook -i "$inventory" "$playbook" --limit "$limit" --check --diff
        ;;
    ssh-check)
        lan_require_cmd ssh
        host="${1:-}"
        [ -n "$host" ] || lan_die "ssh-check requires a host"
        exec ssh -o BatchMode=yes -o ConnectTimeout=5 "$host" true
        ;;
    *)
        usage
        lan_die "unknown subcommand: $subcommand"
        ;;
esac
