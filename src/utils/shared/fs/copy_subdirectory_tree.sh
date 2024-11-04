#!/bin/bash

input_directory=$1
output_directory=$2

# Function to recursively create subdirectories in the output directory
create_subdirectories() {
    local input_dir=$1
    local output_dir=$2

    # Find all directories within the input directory
    find "$input_dir" -type d -not -path "$input_dir" | while read -r dir; do
        # Replace the input directory path with the output directory path
        sub_dir="${dir/$input_directory/$output_directory}"

        # Create the subdirectory in the output directory
        mkdir -p "$sub_dir"
    done
}

# Create subdirectories in the output directory
create_subdirectories "$input_directory" "$output_directory" 