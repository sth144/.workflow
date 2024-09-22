#!/bin/bash

if [[ $# -lt 1 ]]; then
  echo "Please provide input video file path"
  exit 1
fi

input_file=$1
timestamp=$(date '+%Y%m%d-%H%M%S')
out_file=$(echo "~/tmp/smoothed.${timestamp}.${input_file##*/}")

touch $out_file

ffmpeg -i "$input_file" -filter:v "minterpolate=fps=60" -c:a copy "$out_file"

echo "Output file saved to: $out_file"

