#!/bin/bash

# Get the command-line arguments
video_path="$1"
start_time="$2"
end_time="$3"

# Get the name and extension of the video file
filename=$(basename "$video_path")
extension="${filename##*.}"
name="${filename%.*}"

# Set up the output filename and path
output_filename="clipped_${name}.${extension}"
output_path="$HOME/tmp/$output_filename"

# Use ffmpeg to clip the video
ffmpeg -i "$video_path" -ss "$start_time" -to "$end_time" -c copy "$output_path"

echo "Clipped video saved to $output_path"
