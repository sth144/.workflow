#!/bin/bash

MEM_USED=$(nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits)
MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits)

echo "scale=1; 100 * $MEM_USED / $MEM_TOTAL" | bc