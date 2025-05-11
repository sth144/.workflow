#!/bin/bash

# Exit if any command fails
set -e

# Base directory to prepend
BASE_DIR="/mnt/D/Volumes/System/Ubuntu-PC2"

# Check if argument was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <file-or-directory-to-move>"
  exit 1
fi

# Resolve the absolute path of the input
SRC_PATH="$(realpath "$1")"
REL_PATH="${SRC_PATH#/}"  # Remove leading slash
DEST_PATH="$BASE_DIR/$REL_PATH"

# Create the parent directory at the destination
mkdir -p "$(dirname "$DEST_PATH")"

# Move the file or directory
mv "$SRC_PATH" "$DEST_PATH"

# Create a symlink at the original location
ln -s "$DEST_PATH" "$SRC_PATH"

echo "Moved '$SRC_PATH' to '$DEST_PATH' and created symlink at original location."