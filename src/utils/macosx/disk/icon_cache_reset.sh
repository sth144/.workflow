#!/usr/bin/env bash
# icon_cache_reset.sh — clear the bloated macOS icon services cache on demand.
#
# The iconservices.store can balloon to hundreds of GB (known macOS bug) and fill
# the boot volume. A LaunchDaemon clears it nightly once it passes 5GB, but when
# the disk is already full you want it gone now — that is what this is for.
#
# This is a thin wrapper, not a second implementation: the actual work lives in
# cron/clear_system_icons_cache.sh, which handles the threshold check, the
# pre-delete diagnostics, the delete, the verify-it-actually-freed-space step and
# the Launch Services rebuild. This script adds the two things a manual run needs
# and a scheduled one does not: sudo elevation, and live progress.
#
# Progress matters more than it sounds. Unlinking ~300k files takes several
# minutes during which the cache directory still looks huge, which reads as "it
# did not work" — that misread already happened once.

set -euo pipefail

CLEANUP="/usr/local/bin/cron/clear_system_icons_cache.sh"
LOGFILE="/var/log/iconservices_cleanup.log"
VOLUME="/System/Volumes/Data"
FORCE=0

usage() {
		cat <<'EOF'
Usage: icon_cache_reset.sh [-f|--force] [-h|--help]

  -f, --force   Clear regardless of size (default: only above the 5GB threshold)
  -h, --help    Show this help

Re-runs itself under sudo; the cache is only readable by root.
EOF
}

while [ $# -gt 0 ]; do
		case "$1" in
				-f|--force) FORCE=1; shift ;;
				-h|--help)  usage; exit 0 ;;
				*) echo "unknown option: $1" >&2; usage >&2; exit 2 ;;
		esac
done

# The cache is mode drwx--x--x owned by _iconservices: unprivileged runs cannot
# even measure it. Re-exec under sudo rather than failing with an instruction.
if [ "$(id -u)" -ne 0 ]; then
		echo "→ Needs root to read the cache; re-running under sudo..."
		exec sudo "$0" "$@"
fi

free_gb() {
		df -g "$VOLUME" 2>/dev/null | awk 'NR==2{print $4}'
}

echo "🧹 Icon Cache Reset"
echo "==================="

if [ ! -x "$CLEANUP" ]; then
		echo ""
		echo "✗ $CLEANUP not found or not executable."
		echo "  Install it first:"
		echo "    cd /usr/local/src/workflow-macos-1095 && make stage && make copy_staged_to_home && make enable_utils"
		exit 1
fi

BEFORE=$(free_gb)
echo ""
echo "→ Free space before: ${BEFORE}GB"
if [ "$FORCE" -eq 1 ]; then
		echo "→ Forcing a clear (ignoring the 5GB threshold)"
fi

# Capture the cleanup's own output so it does not interleave with the progress
# line; it gets printed in full once the run finishes.
OUT=$(mktemp)
trap 'rm -f "$OUT"' EXIT

echo "→ Clearing (unlinking ~300k files takes a few minutes, this is normal)..."
if [ "$FORCE" -eq 1 ]; then
		ICON_CACHE_THRESHOLD_GB=0 "$CLEANUP" >"$OUT" 2>&1 &
else
		"$CLEANUP" >"$OUT" 2>&1 &
fi
CLEANUP_PID=$!

# Poll free space so a long delete visibly makes progress instead of looking hung.
while kill -0 "$CLEANUP_PID" 2>/dev/null; do
		if [ -t 1 ]; then
				printf '\r    freed so far: %sGB → %sGB' "$BEFORE" "$(free_gb)"
		fi
		sleep 3
done
[ -t 1 ] && printf '\n'

set +e
wait "$CLEANUP_PID"
STATUS=$?
set -e

echo ""
echo "→ Cleanup output:"
sed 's/^/    /' "$OUT"

AFTER=$(free_gb)
echo ""
echo "→ Free space after: ${AFTER}GB (was ${BEFORE}GB)"

if [ "$STATUS" -ne 0 ]; then
		echo ""
		echo "✗ Cleanup exited $STATUS. Full log: $LOGFILE"
		exit "$STATUS"
fi

echo ""
echo "✓ Done. Dock and Finder were restarted; icons rebuild over the next minute."
echo "  Full log: $LOGFILE"
