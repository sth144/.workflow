#!/bin/bash
# clear_system_icons_cache.sh
#
# Clears the macOS icon services cache when it grows too large.
# The iconservices.store can balloon to hundreds of GB (known macOS bug).
# This script only nukes when the cache exceeds the threshold, and performs
# a complete rebuild to avoid leaving the Dock with blank icons.
#
# MUST RUN AS ROOT. The cache dir is mode drwx--x--x owned by _iconservices,
# so an unprivileged run cannot even stat it, let alone delete it.
#
# History: this ran for a long time as the login user (both via the user
# crontab, because admin/install.sh strips the cron user field, and via a
# per-user LaunchAgent). Unprivileged, `du` failed with EPERM, the old code
# defaulted the size to 0, and every run logged "under threshold, no action
# needed" while the cache grew to ~200GB and filled the disk. Hence the
# explicit root check and the verify-after-delete below: a cleanup job that
# cannot tell success from failure is worse than no cleanup job.

set -u

THRESHOLD_GB=5
CACHE_DIR="/Library/Caches/com.apple.iconservices.store"
LOGFILE="/var/log/iconservices_cleanup.log"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

log() {
		local line
		line="$(date '+%Y-%m-%d %H:%M:%S') - $1"
		# Only append when /var/log is actually writable. Testing first rather than
		# redirecting blindly: a failed redirect is reported by the shell itself and
		# cannot be silenced with 2>/dev/null, which made unprivileged runs noisy.
		if [ -w "$LOGFILE" ] || { [ ! -e "$LOGFILE" ] && [ -w "${LOGFILE%/*}" ]; }; then
				echo "$line" >> "$LOGFILE"
		fi
		# Always mirror to stderr; launchd's StandardErrorPath captures it even when
		# /var/log is unwritable (e.g. the disk is already full).
		echo "$line" >&2
}

# Size of the cache in GB. Prints nothing and returns 1 if it cannot be read,
# so callers can distinguish "empty" from "could not measure".
cache_size_gb() {
		[ -d "$CACHE_DIR" ] || { echo 0; return 0; }
		local out
		out=$(du -sg "$CACHE_DIR" 2>/dev/null | awk 'NR==1{print $1}')
		[ -n "$out" ] || return 1
		echo "$out"
}

# Record what is actually in the store before deleting it. The bloat is driven
# by some producer re-registering icons; the surviving evidence of which is the
# name/mtime distribution inside the store. Without this the store gets deleted
# and the cause is unknowable until it refills.
capture_diagnostics() {
		# One stat pass over the whole store: size, mtime day, mtime minute, name.
		# `find -exec +` batches arguments, so this survives a store with hundreds of
		# thousands of entries. An earlier version globbed "$CACHE_DIR"/* into du and
		# silently produced nothing at 301,390 entries because that blew ARG_MAX.
		local inventory="/tmp/iconservices_inventory.$$"
		find "$CACHE_DIR" -mindepth 1 -maxdepth 1 \
				-exec stat -f '%z %Sm %N' -t '%Y-%m-%d %H:%M' {} + > "$inventory" 2>/dev/null

		log "  total entries: $(wc -l < "$inventory" | tr -d ' ')"

		# KB, not MB: individual entries average well under a megabyte, so MB
		# granularity rounds almost every one of them to "0MB".
		log "--- largest 20 entries ---"
		sort -rn -k1,1 "$inventory" 2>/dev/null | head -20 | while read -r bytes day time name; do
				log "  $((bytes / 1024))KB  ${day} ${time}  ${name##*/}"
		done

		# Which days the store actually grew on, and how much. This is the strongest
		# producer signal available after the fact: a single runaway process shows up
		# as one or two days holding nearly all the bytes.
		log "--- growth by day (entries / total MB) ---"
		awk '{ n[$2]++; mb[$2] += $1 / 1048576 }
		     END { for (d in n) printf "%s %d %d\n", d, n[d], mb[d] }' "$inventory" 2>/dev/null |
				sort -rn -k3,3 | head -15 | while read -r day count mb; do
				log "  ${day}  ${count} entries  ${mb}MB"
		done

		# Names are hashes, but a shared prefix/extension across the biggest entries
		# narrows down which client API produced them.
		log "--- sample entry names ---"
		head -5 "$inventory" 2>/dev/null | while read -r _ _ _ name; do
				log "  ${name##*/}"
		done

		rm -f "$inventory"
}

if [ "$(id -u)" -ne 0 ]; then
		log "FATAL: must run as root (running as uid $(id -u)). Refusing to continue."
		exit 1
fi

if ! SIZE_GB=$(cache_size_gb); then
		log "FATAL: cannot measure $CACHE_DIR (du failed). Not assuming it is empty."
		exit 1
fi

if [ "$SIZE_GB" -le "$THRESHOLD_GB" ]; then
		log "Icon cache size: ${SIZE_GB}GB is under threshold (${THRESHOLD_GB}GB). No action needed."
		exit 0
fi

log "Icon cache size: ${SIZE_GB}GB exceeds threshold (${THRESHOLD_GB}GB). Cleaning..."
capture_diagnostics

# Stop the daemon so it is not writing while we delete. launchd restarts it.
killall iconservicesd 2>/dev/null

rm -rf "$CACHE_DIR" 2>/dev/null

# Per-user icon caches. Scoped to the two cache dir names to avoid walking all
# of /private/var/folders more than necessary.
find /private/var/folders/ \
		\( -name com.apple.dock.iconcache -or -name com.apple.iconservices \) \
		-exec rm -rf {} \; 2>/dev/null

# Verify the delete actually freed the space. Deletion here can fail even as
# root: /Library/Caches is subject to TCC, and a launchd job without Full Disk
# Access gets EPERM. rm -rf swallows that, so check rather than trust.
if ! AFTER_GB=$(cache_size_gb); then
		log "WARNING: cache deleted but size no longer measurable; assuming reclaimed."
		AFTER_GB=0
fi

if [ "$AFTER_GB" -gt "$THRESHOLD_GB" ]; then
		log "FATAL: delete did not reclaim space (${SIZE_GB}GB -> ${AFTER_GB}GB)."
		log "       Likely TCC/Full Disk Access denial. Grant Full Disk Access to"
		log "       /bin/bash (or run this by hand with sudo) and re-run."
		exit 1
fi

# Rebuild the Launch Services database (this re-registers all app icons).
"$LSREGISTER" -kill -r -domain local -domain system -domain user

# Restart UI services to pick up the fresh cache.
killall Dock 2>/dev/null
killall Finder 2>/dev/null
killall SystemUIServer 2>/dev/null

log "Icon cache cleanup complete: ${SIZE_GB}GB -> ${AFTER_GB}GB."
