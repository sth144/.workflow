#!/bin/bash

LOGFILE_PATTERN="$1"
shift
COMMAND="$@"

echo "CMD $COMMAND"

shopt -s nullglob

# Check if LOGFILE_PATTERN is not supplied as an argument
if [ -z "$LOGFILE_PATTERN" ]; then
    # Read LOGFILE_PATTERN from .env.INFILES in the same directory as the script
    LOGFILE_PATTERN=$(cat "$HOME/.config/.env.BG_LOG_INFILES")
fi

LOGFILES=( $LOGFILE_PATTERN )

echo "IN ${LOGFILES[@]}"

# Read the output file path from .env.OUTFILE
read -r OUTFILE < "$HOME/.config/.env.BG_LOG_OUTFILE"

# Launching the background tail process and redirecting output to the specified file
tail -f "${LOGFILES[@]}" > "$OUTFILE" &

# Storing the PID of the background process
TAIL_PID=$!

# Checking if $COMMAND is empty
if [ -z "$COMMAND" ]; then
    echo "Press Enter to kill the script..."
    read -rsn1
else
    # Executing the given command
    $COMMAND
fi

# Killing the background tail process
kill $TAIL_PID

# Printing the location of the output
echo "Output saved to: $OUTFILE"
