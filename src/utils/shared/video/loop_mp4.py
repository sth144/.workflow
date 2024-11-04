#!/usr/bin/env python

import os
import sys
from moviepy.editor import VideoFileClip, concatenate_videoclips

# Get the path to the input file from the command line argument
if len(sys.argv) < 3:
    print("Please provide the path to the input MP4 file as an argument")
    exit(1)

input_file_path = sys.argv[1]
output_file_path = sys.argv[2]
use_defaults = False
if len(sys.argv) > 3:
    if sys.argv[3].lower() == "usedefault":
        use_defaults = True
    
# Prompt the user for the number of times to loop the video
default_loops = 5
loops = default_loops
if not use_defaults:
    loops = input(f"Enter number of loops (default {default_loops}): ")
loops = int(loops) if loops else default_loops

# Apply looping
clip = VideoFileClip(input_file_path)

clips = [clip] * loops
final_clip = concatenate_videoclips(clips)

# Write the output file
final_clip.write_videofile(output_file_path, fps=clip.fps)
print(f"Done! {output_file_path}")
