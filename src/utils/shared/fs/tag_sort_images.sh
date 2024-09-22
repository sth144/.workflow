
#!/bin/bash

input_directory="$1"
output_directory="$2"

# Iterate through image files in the input directory
for file_path in "$input_directory"/*; do
    if [[ -f "$file_path" ]]; then
        # Open the image and store the process ID (PID)
        xdg-open "$file_path" &
        image_pid=$!

        echo "Image PID $image_pid"

        echo "Current tags: "

        # Prompt the user for tag strings
        read -p "Enter tags for file $(basename "$file_path"): " tags

        # Terminate the process gracefully by sending a close signal
        kill -TERM "$image_pid"
        kill -9 $(pidof eog)

        # Copy the file to subdirectories based on tags
        IFS=' ' read -ra tag_array <<< "$tags"
        for tag in "${tag_array[@]}"; do
            destination_directory="$output_directory/$tag"
            mkdir -p "$destination_directory"
            cp "$file_path" "$destination_directory"
        done
    fi
done