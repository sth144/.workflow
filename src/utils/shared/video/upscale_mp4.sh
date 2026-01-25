#!/bin/bash

# Usage: upscale_mp4.sh input.mp4 [output.mp4]

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 input.mp4 [output.mp4]"
  exit 1
fi

input="$1"

if [ -n "$2" ]; then
  output="$2"
else
  base="${input%.mp4}"
  output="${base}.upscaled.mp4"
fi

workdir="$(mktemp -d)"
input_dir="$workdir/frames-input"
output_dir="$workdir/frames-output"

mkdir -p "$input_dir" "$output_dir"

echo "Extracting frames..."
ffmpeg -y -i "$input" "$input_dir/frame%06d.png"

echo "Upscaling frames with Real-ESRGAN..."
~/src/Real-ESRGAN-ncnn-vulkan/build/realesrgan-ncnn-vulkan \
  -i "$input_dir" \
  -o "$output_dir" \
  -m ~/src/Real-ESRGAN-ncnn-vulkan/models \
  -n realesrgan-x4plus

# Ensure frames exist
shopt -s nullglob
frames=("$output_dir"/*.png)
shopt -u nullglob

if [ ${#frames[@]} -eq 0 ]; then
  echo "ERROR: No upscaled frames produced"
  rm -rf "$workdir"
  exit 1
fi

# Preserve original framerate
fps=$(ffprobe -v error \
  -select_streams v:0 \
  -show_entries stream=r_frame_rate \
  -of csv=p=0 "$input")

echo "Re-encoding video..."

ffmpeg -y \
  -framerate "$fps" \
  -f image2 \
  -pattern_type glob \
  -i "$output_dir"/*.png \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "$output"

rm -rf "$workdir"

echo "Upscaled MP4 saved as $output"

