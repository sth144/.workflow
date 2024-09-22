
#!/bin/bash

input_directory=$1
output_directory=$2
command_string=$3

# Create output directory if it doesn't exist
mkdir -p "$output_directory"

# Function to recursively process files in the input directory
process_files() {
    local input_dir=$1
    local output_dir=$2

    for file in "$input_dir"/*; do
        if [ -f "$file" ]; then
            # Get the directory path without the filename
            dir_path=$(dirname "$file")

            echo "DIR PATH $dir_path"

            # Create the directory structure in the output directory
            sub_dir="${dir_path/$input_directory/$output_directory}"
            
            echo "SUB DIR $sub_dir"

            mkdir -p "$sub_dir"

            # Replace placeholders in the command string
            outfile_name=$(basename $file)
            echo "OUTFILE NAME $outfile_name"
            outfile="$sub_dir/$outfile_name"
            echo "OUTFILE PATH $outfile"
            command=${command_string/<INPUT>/$file}
            command=${command/<OUTPUT>/$outfile}

            echo "COMMAND $command"

            # Execute the command
            eval "$command"
        elif [ -d "$file" ]; then
            echo "RECURSE $file $output_directory"
            # Recursively process subdirectories
            process_files "$file" "$output_directory"
    fi
    done
}

# Start processing files in input directory
process_files "$input_directory" "$output_directory"