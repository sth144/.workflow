#!/bin/bash
set -e

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
output="/home/sthinds/tmp/stitched.$timestamp.mp4"

last_arg="${@: -1}"
if [[ "$last_arg" == *.mp4 ]]; then
  output="$last_arg"
  mp4_list=("${@:1:$#-1}")
else
  mp4_list=("$@")
fi

if [ ${#mp4_list[@]} -eq 0 ]; then
  echo "Usage: vid_stitch.sh input1.mp4 input2.mp4 [...] [output.mp4]"
  exit 1
fi

echo "MP4 List:"
printf "  %s\n" "${mp4_list[@]}"

# Create temp concat file
concat_file=$(mktemp)
trap 'rm -f "$concat_file"' EXIT

for f in "${mp4_list[@]}"; do
  printf "file '%s'\n" "$(realpath "$f")" >> "$concat_file"
done

ffmpeg -y \
  -f concat -safe 0 \
  -i "$concat_file" \
  -c copy \
  "$output"

echo "Stitching completed successfully: $output"

