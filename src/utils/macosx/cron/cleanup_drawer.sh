#!/bin/bash
# cleanup_drawer.sh
#
# Rolling cleanup of ~/Drawer - removes files not modified in over 30 days.
# Designed to run weekly via cron.
#
# Excludes:
#   - The daybook subdirectory (contains screenshot attachments for notes)
#   - Hidden files/directories

DRAWER_DIR="$HOME/Drawer"
RETENTION_DAYS=30
LOGFILE="$HOME/.cache/.workflow/drawer_cleanup.log"

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

log() {
		echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

if [ ! -d "$DRAWER_DIR" ]; then
		log "Drawer directory does not exist: $DRAWER_DIR"
		exit 0
fi

log "Starting Drawer cleanup (files older than ${RETENTION_DAYS} days)..."

# Count files before cleanup
BEFORE_COUNT=$(find "$DRAWER_DIR" -type f -not -path "$DRAWER_DIR/daybook/*" -not -name ".*" 2>/dev/null | wc -l | tr -d ' ')

# Find and delete files not modified in over 30 days
# Excludes:
#   - daybook/ subdirectory (used by daybook logging)
#   - hidden files (starting with .)
find "$DRAWER_DIR" -type f -mtime +${RETENTION_DAYS} \
		-not -path "$DRAWER_DIR/daybook/*" \
		-not -name ".*" \
		-exec rm -v {} \; >> "$LOGFILE" 2>&1

# Remove empty directories (except daybook and the root Drawer dir)
find "$DRAWER_DIR" -mindepth 1 -type d -empty \
		-not -path "$DRAWER_DIR/daybook" \
		-exec rmdir {} \; 2>/dev/null

# Count files after cleanup
AFTER_COUNT=$(find "$DRAWER_DIR" -type f -not -path "$DRAWER_DIR/daybook/*" -not -name ".*" 2>/dev/null | wc -l | tr -d ' ')

DELETED=$((BEFORE_COUNT - AFTER_COUNT))
log "Cleanup complete. Removed ${DELETED} files. Remaining: ${AFTER_COUNT}"
