#!/bin/bash

# Run ncdu and save the output to a file
sudo ncdu / > "$HOME/tmp/disk_usage.txt"

# Send the file as an email attachment
echo "See attached file for PC disk usage" \
  | mutt -s "Disk Usage Report" -a "$HOME/tmp/disk_usage.txt" sthinds144@gmail.com