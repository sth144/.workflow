#!/bin/bash

input_directory="$1"
output_directory="$2"

# Iterate through video files in the input directory
for file_path in "$input_directory"/*; do
    if [[ -f "$file_path" ]]; then
        # Extract the filename without extension
        filename=$(basename -- "$file_path")
        filename_without_extension="${filename%.*}"

        # Open the video and extract the first frame as an image
        tmp_img_path="$input_directory/$filename_without_extension.jpg"

        ffmpeg -i "$file_path" -ss 00:00:00 -vframes 1 $tmp_img_path
        xdg-open "$file_path" &
        image_pid=$!

        # Prompt the user for tag strings
        read -p "Enter tags for file $filename: " tags
        
        kill -TERM "$image_pid"
        kill -9 $(pidof eog)
        
        # Copy the video file to subdirectories based on tags
        IFS=' ' read -ra tag_array <<< "$tags"
        for tag in "${tag_array[@]}"; do
            destination_directory="$output_directory/$tag"
            mkdir -p "$destination_directory"
            cp "$file_path" "$destination_directory"
        done

        # Remove the extracted first frame image
        rm $tmp_img_path
    fi
done