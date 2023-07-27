#!/usr/bin/env python

import os
import sys
from moviepy.editor import VideoFileClip, concatenate_videoclips

# Get the path to the input file from the command line argument
if len(sys.argv) < 2:
    print("Please provide the path to the input MP4 file as an argument")
    exit(1)

input_file_path = sys.argv[1]
output_dir = os.path.expanduser("~/tmp")

# Prompt the user for the slowdown multiplier
default_slowdown = 10
slowdown = input(f"Enter slowdown multiplier (default {default_slowdown}): ")
slowdown = float(slowdown) if slowdown else default_slowdown

# Prompt the user for the number of times to loop the video
default_loops = 10
loops = input(f"Enter number of loops (default {default_loops}): ")
loops = int(loops) if loops else default_loops

# Apply slowdown and looping
clip = VideoFileClip(input_file_path)

clip = clip.fx(clip.speedx, slowdown)
clips = [clip] * loops
final_clip = concatenate_videoclips(clips)

# Derive the output file path
filename = os.path.basename(input_file_path)
output_file_path = os.path.join(output_dir, f"looped.{filename}")

# Write the output file
final_clip.write_videofile(output_file_path, fps=clip.fps)
print(f"Done! {output_file_path}")
