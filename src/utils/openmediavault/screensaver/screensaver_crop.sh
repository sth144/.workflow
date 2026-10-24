#!/bin/bash
# Regenerate the 16:10 screensaver images served by the `screensaver` nginx
# container, and prune outputs whose source painting is gone.
#
# Runs from the sthinds crontab every 15 minutes. Incremental: a normal tick
# only stats the sources and exits, so drop a painting into the source
# directory and it reaches the tablet within the interval.
#
# The cropper runs in a container because this host is Debian buster with
# Python 3.7 and no pillow/numpy; the image carries the deps, the script is
# bind-mounted so editing it needs no rebuild.

set -euo pipefail

IMAGES_ROOT="${SCREENSAVER_ROOT:-/home/sthinds/data/Images/Purpose-Based}"
APP_DIR="${SCREENSAVER_APP:-/home/sthinds/Projects/screensaver-crop}"
IMAGE="${SCREENSAVER_IMAGE:-screensaver-crop:latest}"

SRC_NAME="Screensaver"
DST_NAME="Screensaver-1920x1200"

if [ ! -d "$IMAGES_ROOT/$SRC_NAME" ]; then
  echo "$(date '+%F %T') error: source directory missing: $IMAGES_ROOT/$SRC_NAME" >&2
  exit 1
fi

# The monthly docker-prune clears the builder cache, and an image can be lost
# to a manual cleanup; rebuild on demand so the job is self-healing.
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "$(date '+%F %T') image $IMAGE missing, rebuilding"
  docker build -q -t "$IMAGE" "$APP_DIR"
fi

# Run as sthinds:users so the outputs stay writable over the SMB share.
if ! output="$(docker run --rm \
  --user 1000:100 \
  -v "$IMAGES_ROOT:/work" \
  -v "$APP_DIR:/app:ro" \
  "$IMAGE" \
  /app/crop_to_aspect.py \
    --src "/work/$SRC_NAME" \
    --dst "/work/$DST_NAME" \
    --prune 2>&1)"; then
  echo "--- $(date '+%F %T') FAILED ---"
  echo "$output"
  exit 1
fi

# Ticks that changed nothing are the common case; stay silent so the log holds
# only real events.
if grep -qE '^ +(crop|fill) |^pruned ' <<<"$output"; then
  echo "--- $(date '+%F %T') ---"
  echo "$output"
fi
