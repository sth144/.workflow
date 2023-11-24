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

# Check if the input file exists
if [ ! -f "$input_file" ]; then
  echo "File not found!"
  exit 1
fi

FIRST_ITER=true

# Loop until the user says no to compressing another round
while true; do
  if $FIRST_ITER;
  then
    choice="y"
  else
    read -p "Do you want to compress another round? (yes/no): " choice
  fi

  # Check the user's input
  case $choice in
    [Yy]|[Yy][Ee][Ss])
      if ! $FIRST_ITER;
      then
        mv /home/<USER>/tmp/$output_file /home/<USER>/tmp/tmp.$output_file
        input_file=/home/<USER>/tmp/tmp.$output_file
      fi
      # run FFmpeg command to compress video
      ffmpeg -i "$input_file" -c:v libx264 -crf 23 "/home/<USER>/tmp/$output_file"

      # check if FFmpeg command was successful
      if [ $? -eq 0 ]; then
        size=$(du -b "/home/<USER>/tmp/$output_file" | cut -f1)

        echo "Video compressed successfully: $output_file"

        # Print the file size
        echo "File size: $size bytes"
      else
        echo "Error compressing video: $input_file"
        exit 1
      fi
      ;;
    [Nn]|[Nn][Oo])
      echo "Program exited."
      exit 0
      ;;
    *)
      echo "Invalid choice. Please enter yes or no."
      ;;
  esac
  FIRST_ITER=false
done