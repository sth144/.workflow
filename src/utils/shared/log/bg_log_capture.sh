#!/bin/bash

LOGFILE_PATTERN="$1"
shift
COMMAND="$@"

echo "CMD $COMMAND"

shopt -s nullglob
LOGFILES=( $LOGFILE_PATTERN )

echo "IN ${LOGFILES[@]}"

# Launching the background tail process
tail -f "${LOGFILES[@]}" > ~/Data/log/capture.log &

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
echo "Output saved to: ~/Data/log/capture.log"
