#!/bin/bash
# clear_system_icons_cache.sh
#
# Clears the macOS icon services cache when it grows too large.
# The iconservices.store can balloon to hundreds of GB (known macOS bug).
# This script only nukes when the cache exceeds the threshold, and performs
# a complete rebuild to avoid leaving the Dock with blank icons.
#
# Must run as root.

THRESHOLD_GB=5
CACHE_DIR="/Library/Caches/com.apple.iconservices.store"
LOGFILE="/var/log/iconservices_cleanup.log"

log() {
		echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOGFILE"
}

# Get cache size in GB (returns 0 if directory doesn't exist)
SIZE_GB=$(du -sg "$CACHE_DIR" 2>/dev/null | awk '{print $1}')
SIZE_GB=${SIZE_GB:-0}

if [ "$SIZE_GB" -gt "$THRESHOLD_GB" ]; then
		log "Icon cache size: ${SIZE_GB}GB exceeds threshold (${THRESHOLD_GB}GB). Cleaning..."

		# Kill the icon services daemon first
		killall iconservicesd 2>/dev/null

		# Remove the main cache directory
		rm -rf "$CACHE_DIR"

		# Remove per-user icon caches
		find /private/var/folders/ \( -name com.apple.dock.iconcache -or -name com.apple.iconservices \) -exec rm -rf {} \; 2>/dev/null

		# Rebuild the Launch Services database (this re-registers all app icons)
		/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user

		# Restart UI services to pick up the fresh cache
		killall Dock 2>/dev/null
		killall Finder 2>/dev/null
		killall SystemUIServer 2>/dev/null

		log "Icon cache cleanup complete."
else
		log "Icon cache size: ${SIZE_GB}GB is under threshold (${THRESHOLD_GB}GB). No action needed."
fi
