#!/bin/bash
for file in *.mp4; do
  thumbnail="${file%.mp4}.jpg"
  if [ ! -f "$thumbnail" ]; then
    echo "$file"
    ffmpeg -ss 5 -i "$file" -vframes 1 -q:v 2 "$thumbnail"
  fi
done