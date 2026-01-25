#!/bin/bash

if [ $# -eq 0 ]; then
  echo "Usage: $0 input.mp4"
  exit 1
fi

input="$1"
base="${input%.mp4}"
output="${base}.revloop.mp4"

tmp_fwd="$(mktemp --suffix=.mp4)"
tmp_rev="$(mktemp --suffix=.mp4)"

# Forward (no trimming)
ffmpeg -y -i "$input" \
  -vf "setpts=PTS-STARTPTS" \
  -c:v libx264 -pix_fmt yuv420p \
  "$tmp_fwd"

# Reverse
ffmpeg -y -i "$input" \
  -vf "reverse,setpts=PTS-STARTPTS" \
  -c:v libx264 -pix_fmt yuv420p \
  "$tmp_rev"

# Concat (video only)
ffmpeg -y \
  -i "$tmp_fwd" \
  -i "$tmp_rev" \
  -filter_complex "[0:v][1:v]concat=n=2:v=1:a=0[v]" \
  -map "[v]" \
  -movflags +faststart \
  "$output"

rm "$tmp_fwd" "$tmp_rev"

echo "Boomerang MP4 saved as $output"

