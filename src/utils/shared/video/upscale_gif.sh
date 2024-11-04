#!/bin/bash

# Check if input gif path is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <input_gif_path>"
    exit 1
fi

# Get the input gif path
input_gif="$1"
# Check if the second argument (output_gif) is provided
if [ -z "$2" ]; then
    # Set output_gif to the default value
    output_gif="${HOME}/tmp/output.gif"
else
    # Set output_gif to the provided value
    output_gif="$2"
fi

# Set the filenames and directories
input_dir="${HOME}/tmp/frames-input"
output_dir="${HOME}/tmp/frames-output"

# Create the input and output directories
mkdir -p "$input_dir"
mkdir -p "$output_dir"

# Step 1: Split input gif into frames
convert "$input_gif" -coalesce "$input_dir/frame%04d.png"

# Step 2: Run your_special_script.sh
a  \
    -i "$input_dir" \
    -o "$output_dir" \
    -m ~/src/Real-ESRGAN-ncnn-vulkan/models \
    -n realesrgan-x4plus

# Step 3: Stitch frames back into a gif
convert -delay 10 -loop 0 "${output_dir}"/*.png "$output_gif"

# Cleanup: Remove temporary frames
rm -rf "$input_dir"
rm -rf "$output_dir"