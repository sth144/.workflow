#!/bin/bash

# Check if the input file path is provided as an argument
if [ $# -eq 0 ]; then
  echo "Usage: $0 input_filepath"
  exit 1
fi

input="$1"
output="${input%.gif}.revloop.gif"

# Execute the ImageMagick command
convert "$input" -coalesce -duplicate 1,-2-1 -layers OptimizePlus "$output"

echo "Reversed loop GIF saved as $output"
