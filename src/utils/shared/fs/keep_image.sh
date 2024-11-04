#!/bin/bash

# Check if the correct number of arguments are provided
if [ $# -ne 2 ]; then
  echo "Usage: $0 <input_filepath> <output_filepath>"
  exit 1
fi

input_filepath=$1
output_filepath=$2

# Open the image using the display command
display "$input_filepath" &

# Prompt the user for a yes/no answer
read -p "Do you want to keep the image? (y/n): " answer

# Close the display window
killall display

# Check the user's answer
if [ "$answer" == "y" ]; then
  # Ensure the directory of the output file path exists
  mkdir -p "$(dirname "$output_filepath")"

  # Copy the image to the output file path
  cp "$input_filepath" "$output_filepath"
  echo "Image has been copied to $output_filepath"
else
  echo "Image hasn't been copied."
fi
