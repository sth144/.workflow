#!/bin/bash

timestamp_file="$HOME/.cache/.workflow/cpu_conky.timestamp"

# Check if the timestamp file exists and has valid data
if [[ ! -f "$timestamp_file" ]]; then
    echo "Error: CPU timestamp file '$timestamp_file' not found."
    exit 1
fi

CPU_CONKY_TIMESTAMP=$(tail -1 "$timestamp_file")

# Check if the timestamp value is valid
if ! [[ $CPU_CONKY_TIMESTAMP =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid CPU timestamp value in file."
    exit 1
fi

CUR=$(date +%s)

SECONDS_SINCE_LAST_REPORT=$((CUR - CPU_CONKY_TIMESTAMP))

# Compare the seconds with the threshold value
if ((SECONDS_SINCE_LAST_REPORT > 5)); then
    echo "CPU check finds no timestamp within the limit. Starting process with DISPLAY=$DISPLAY"
    "$HOME/bin/conky/cpu_conky_exec.sh"
fi



