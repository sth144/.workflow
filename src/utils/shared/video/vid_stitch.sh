#!/bin/bash

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

# store the passed arguments as array
mp4_list=("$@")

# combine the array of mp4 files into a single string
mp4_concat=$(printf "concat:%s|" "${mp4_list[@]}")
mp4_concat=${mp4_concat%?} # remove the trailing pipe symbol

# stitch the passed mp4 files together and save in ~/tmp
ffmpeg -i "$mp4_concat" -c copy /home/<USER>/tmp/stitched.$timestamp.mp4

echo "Stitching completed successfully"
