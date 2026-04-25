#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)

make_backup() {
    exec "$SCRIPT_DIR/run_local_backup.sh"
}

revert_to_backup() {
    local snapshot_dir="${1:-}"

    if [[ -z "$snapshot_dir" ]]; then
        echo "Usage: $0 revert_to_backup <snapshot-dir>" >&2
        exit 1
    fi

    exec "$SCRIPT_DIR/restore_local_backup.sh" restore-packages "$snapshot_dir"
}

command_name="${1:-make_backup}"
shift || true

case "$command_name" in
    make_backup)
        make_backup "$@"
        ;;
    revert_to_backup)
        revert_to_backup "$@"
        ;;
    *)
        echo "Unknown command: $command_name" >&2
        exit 1
        ;;
esac
