#!/bin/bash

OUTPUT=$(netstat -ntp | awk '{printf "%-11s %-5s %-18s %-18s %-11s\n", $7, $1, $4, $5, $6 }')
echo "$OUTPUT" | tail -n +3 | head -9 | column -t | sort -k5