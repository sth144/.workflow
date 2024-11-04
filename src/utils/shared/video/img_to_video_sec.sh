#!/bin/bash

# check if file path and duration have been provided
if [ $# -ne 2 ]; then
  echo "Please provide input image file path and duration as arguments"
  exit 1
fi

# set input file path and duration in seconds
input_file="$1"
duration="$2"

# extract filename and extension from input file path
filename=$(basename -- "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# set output file path
output_file="${filename}_${duration}s.mp4"

# run FFmpeg command to create video from image
ffmpeg -loop 1 -i "$input_file" -t "$duration" -pix_fmt yuv420p "/home/<USER>/tmp/$output_file"

# check if FFmpeg command was successful
if [ $? -eq 0 ]; then
  echo "Video created successfully: $output_file"
else
  echo "Error creating video from image: $input_file"
  exit 1
fi