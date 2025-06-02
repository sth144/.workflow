#!/bin/bash

# TODO: this is not working yet

# Exit if any command fails
set -e

# Base directory to prepend (only used if second argument is not provided)
BASE_DIR="/mnt/D/Volumes/System/Ubuntu-PC3"

# Check if the first argument was provided
if [ -z "$1" ]; then
  echo "Usage: $0 <file-or-directory-to-move> [destination-path]"
  exit 1
fi

# Resolve the absolute path of the input
SRC_PATH="$(realpath "$1")"
SRC_BASENAME="$(basename "$SRC_PATH")"  # Get the basename of the source (file or directory)

# If a second argument is provided, use it as DEST_PATH, otherwise prepend BASE_DIR
if [ -n "$2" ]; then
  DEST_PATH="$2/$SRC_BASENAME"
else
  DEST_PATH="$BASE_DIR/$SRC_BASENAME"
fi

# Create the parent directory at the destination
mkdir -p "$(dirname "$DEST_PATH")"

# If source is a directory, copy its contents, otherwise just copy the file
if [ -d "$SRC_PATH" ]; then
  # For directories, we want to copy the contents, not the directory itself
  rsync -av --ignore-existing "$SRC_PATH"/ "$DEST_PATH"
else
  # For files, we just copy them as usual
  rsync -av --ignore-existing "$SRC_PATH" "$DEST_PATH"
fi

# Check if rsync was successful and then remove the source file/directory
if [ -e "$DEST_PATH" ]; then
  rm -rf "$SRC_PATH"  # Remove the original file/directory
  echo "Successfully moved '$SRC_PATH' to '$DEST_PATH'."
else
  echo "Error: rsync failed to copy '$SRC_PATH'. Source not deleted."
  exit 1
fi

# Create a symlink at the original location
ln -s "$DEST_PATH" "$SRC_PATH"

echo "Created symlink from '$SRC_PATH' to '$DEST_PATH'."
