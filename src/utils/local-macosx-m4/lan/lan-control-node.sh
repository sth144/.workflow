#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && /bin/pwd -P)
source "$SCRIPT_DIR/lib.sh"

usage() {
    cat <<'EOF'
Usage:
  lan-control-node.sh doctor
  lan-control-node.sh versions
  lan-control-node.sh install [--approve]

`doctor` reports whether the local control-node prerequisites are present.
`install` previews the required Homebrew actions unless `--approve` is supplied.
EOF
}

print_status() {
    local name="$1"
    local path="${2:-}"
    if [ -n "$path" ]; then
        printf 'ok      %-18s %s\n' "$name" "$path"
    else
        printf 'missing %-18s\n' "$name"
    fi
}

doctor() {
    local failure=0
    local cmd path

    for cmd in brew ssh python3 ansible ansible-playbook ansible-inventory; do
        path=$(command -v "$cmd" || true)
        if [ -n "$path" ]; then
            print_status "$cmd" "$path"
        else
            print_status "$cmd"
            failure=1
        fi
    done

    return "$failure"
}

versions() {
    lan_require_cmd python3
    python3 --version

    if command -v brew >/dev/null 2>&1; then
        brew --version | head -1
    fi

    if command -v ansible >/dev/null 2>&1; then
        ansible --version | head -2
    fi

    if command -v ansible-playbook >/dev/null 2>&1; then
        ansible-playbook --version | head -2
    fi
}

install() {
    local approve="${1:-0}"

    lan_require_cmd brew

    if command -v ansible >/dev/null 2>&1 &&
        command -v ansible-playbook >/dev/null 2>&1 &&
        command -v ansible-inventory >/dev/null 2>&1; then
        echo "ansible CLI already installed"
        versions
        return 0
    fi

    echo "plan: brew install ansible"
    if [ "$approve" -ne 1 ]; then
        echo "preview only; re-run with --approve to install"
        return 0
    fi

    brew install ansible
    doctor
    versions
}

subcommand="${1:-}"
[ -n "$subcommand" ] || {
    usage
    exit 1
}
shift || true

case "$subcommand" in
    doctor)
        doctor
        ;;
    versions)
        versions
        ;;
    install)
        approve=0
        while [ "$#" -gt 0 ]; do
            case "$1" in
                --approve|--apply)
                    approve=1
                    shift
                    ;;
                --help|-h)
                    usage
                    exit 0
                    ;;
                *)
                    lan_die "unknown install option: $1"
                    ;;
            esac
        done
        install "$approve"
        ;;
    *)
        usage
        lan_die "unknown subcommand: $subcommand"
        ;;
esac
