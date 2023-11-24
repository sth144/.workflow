#!/bin/bash

# Function to get the base name of a file without extension
get_file_basename() {
    local fullpath=$1
    echo "$(basename "$fullpath" | cut -f 1 -d '.')"
}

input_file=$1
output_file=${2:-"$HOME/tmp/$(get_file_basename $input_file)_compressed.mp4"}
iterations=${3:-3}

# Compression command
compress_video() {
    local input=$1
    local output=$2

    ffmpeg -i "$input" -c:v libx264 -crf 23 "$output"
  # check if FFmpeg command was successful
  if [ $? -eq 0 ]; then
    size=$(du -b "/home/<USER>/tmp/$output_file" | cut -f1)

    echo "Video compressed successfully: $output_file"

    # Print the file size
    echo "File size: $size bytes"
  fi
}

# Perform initial compression
compress_video "$input_file" "$output_file"

# Perform additional compressions if iterations > 1
if [ "$iterations" -gt 1 ]; then
    for ((i=2; i<="$iterations"; i++)); do
        tmp_output="${output_file}_tmp$i"
        compress_video "$output_file" "$tmp_output"
        mv "$tmp_output" "$output_file"
    done
fi