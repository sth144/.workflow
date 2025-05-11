#!/bin/bash

set -e

BASE_DIR="/mnt/D/Volumes/System/Ubuntu-PC2"

if [ -z "$1" ]; then
  echo "Usage: $0 <symlink-path>"
  exit 1
fi

SYMLINK_PATH="$(realpath -s "$1")"

if [ ! -L "$SYMLINK_PATH" ]; then
  echo "Error: '$SYMLINK_PATH' is not a symlink."
  exit 1
fi

# Resolve actual file/directory path the symlink points to
TARGET_PATH="$(readlink -f "$SYMLINK_PATH")"

# Check that it's under the base dir
if [[ "$TARGET_PATH" != $BASE_DIR/* ]]; then
  echo "Error: Target '$TARGET_PATH' is not under '$BASE_DIR'. Aborting to avoid accidental data loss."
  exit 1
fi

# Remove the symlink
rm "$SYMLINK_PATH"

# Move back to original path
mv "$TARGET_PATH" "$SYMLINK_PATH"

echo "Restored '$SYMLINK_PATH' from '$TARGET_PATH'."
