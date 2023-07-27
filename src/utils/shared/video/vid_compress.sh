
#!/bin/bash

# check if file path has been provided
if [ $# -eq 0 ]; then
  echo "Please provide input video file path as an argument"
  exit 1
fi

# set input file path
input_file="$1"

# extract filename and extension from input file path
filename=$(basename -- "$input_file")
extension="${filename##*.}"
filename="${filename%.*}"

# set output file path
output_file="${filename}_compressed.mp4"

# run FFmpeg command to compress video
ffmpeg -i "$input_file" -c:v libx264 -crf 23 "/home/<USER>/tmp/$output_file"

# check if FFmpeg command was successful
if [ $? -eq 0 ]; then
  echo "Video compressed successfully: $output_file"
else
  echo "Error compressing video: $input_file"
  exit 1
fi