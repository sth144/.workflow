#!/bin/bash


# check if file path has been provided
if [ $# -eq 0 ]; then
  echo "Please provide input video file path as an argument"
  exit 1
fi

# extract filename without extension
filename=$(basename -- "$1")
filename="${filename%.*}"

# set output file path
output_file="~/tmp/even.${filename}.mp4"

# run FFmpeg command to resize video
ffmpeg -i $1 -filter_complex
"[0:v]scale='2*trunc(iw/2)':'2*trunc(ih/2)',pad='max(iw,ih)':'max(iw,ih)':(max(iw,ih)-iw)/2:(max(iw,ih)-ih)/2:black"
$output_file

# check if FFmpeg command was successful
if [ $? -eq 0 ]; then
  echo "Video resized successfully: $output_file"
else
  echo "Error resizing video: $1"
  exit 1
fi
