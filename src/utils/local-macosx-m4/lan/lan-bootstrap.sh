#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && /bin/pwd -P)
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<'EOF'
Usage:
  lan-bootstrap.sh --limit PATTERN [--inventory PATH] [--bootstrap-user USER] [--authorized-key-file PATH] [--approve] [-- ARGS...]

Defaults to preview mode using --list-hosts and --list-tasks.
Use --approve to apply the tracked bootstrap playbook.
EOF
}

lan_require_cmd ansible-playbook

inventory=""
limit=""
bootstrap_user=""
authorized_key_file=""
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
        --bootstrap-user)
            bootstrap_user="$2"
            shift 2
            ;;
        --authorized-key-file)
            authorized_key_file="$2"
            shift 2
            ;;
        --approve|--apply)
            approve=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        --)
            shift
            extra_args=("$@")
            break
            ;;
        *)
            lan_die "unknown bootstrap option: $1"
            ;;
    esac
done

[ -n "$limit" ] || {
    usage
    lan_die "bootstrap requires --limit"
}

inventory=$(lan_resolve_inventory "$inventory")
playbook=$(lan_resolve_playbook "bootstrap-host")

playbook_args=("-i" "$inventory" "$playbook" "--limit" "$limit")

if [ -n "$bootstrap_user" ]; then
    playbook_args+=("-e" "bootstrap_manage_user=$bootstrap_user")
fi

if [ -n "$authorized_key_file" ]; then
    [ -f "$authorized_key_file" ] || lan_die "authorized key file not found: $authorized_key_file"
    playbook_args+=("-e" "bootstrap_authorized_key_file=$authorized_key_file")
fi

if [ "$approve" -eq 1 ]; then
    if [ "${#extra_args[@]}" -gt 0 ]; then
        exec ansible-playbook "${playbook_args[@]}" "${extra_args[@]}"
    fi
    exec ansible-playbook "${playbook_args[@]}"
fi

if [ "${#extra_args[@]}" -gt 0 ]; then
    exec ansible-playbook "${playbook_args[@]}" --list-hosts --list-tasks "${extra_args[@]}"
fi

exec ansible-playbook "${playbook_args[@]}" --list-hosts --list-tasks
