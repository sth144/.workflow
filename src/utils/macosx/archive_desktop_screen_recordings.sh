#!/bin/bash

DATE=$(date +%Y-%m-%d)
TARGET_DIR="$HOME/Movies/DesktopArchive/$DATE/"
mkdir -p $TARGET_DIR
find $HOME/Desktop -type f -name '*.mov' -exec mv {} $TARGET_DIR \;
find $HOME/Desktop -type f -name '*.png' -exec mv {} $TARGET_DIR \;

