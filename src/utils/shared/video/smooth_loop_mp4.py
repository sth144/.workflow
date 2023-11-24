#!/usr/bin/env python

import os
import sys
import subprocess
from moviepy.editor import VideoFileClip, concatenate_videoclips

def get_video_fps(file_path):
    command = ["ffprobe", "-v", "error", "-select_streams", "v", "-of", "default=noprint_wrappers=1:nokey=1", "-show_entries", "stream=r_frame_rate", file_path]
    result = subprocess.run(command, capture_output=True, text=True)
    fps = round(eval(result.stdout))
    return fps

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
    
# Derive the output file path
filename = os.path.basename(input_file_path)

tmp_dir = os.path.expanduser("~/tmp")

tmp_file_path_0 = os.path.join(tmp_dir, f"tmp.0.{filename}")
tmp_file_path_1 = os.path.join(tmp_dir, f"tmp.1.{filename}")

# Prompt the user for the slowdown multiplier
default_slowdown = 6
slowdown = default_slowdown
if not use_defaults:
    slowdown = input(f"Enter slowdown multiplier (default {default_slowdown}): ")
slowdown = float(slowdown) if slowdown else default_slowdown

# Prompt the user for the number of times to loop the video
default_loops = 5
loops = default_loops
if not use_defaults:
    loops = input(f"Enter number of loops (default {default_loops}): ")
loops = int(loops) if loops else default_loops


# convert mp4 file to smooth mp4 format with minterpolate filter
command3 = (
    f'ffmpeg -y -i {input_file_path} -filter:v "setpts=1.2*PTS" {tmp_file_path_0}'
)
subprocess.run(command3, shell=True, check=True)

fps = get_video_fps(tmp_file_path_0)
print(f"The video fps is: {fps}")

command4 = (
    f'ffmpeg -y -i {tmp_file_path_0} -crf 10 '
  + f' -vf "minterpolate=fps=60:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1"'
  + f' {tmp_file_path_1}'
)
subprocess.run(command4, shell=True, check=True)

# Apply slowdown and looping
clip = VideoFileClip(tmp_file_path_1)

clip = clip.fx(clip.speedx, slowdown)
clips = [clip] * loops
final_clip = concatenate_videoclips(clips)

# Write the output file
final_clip.write_videofile(output_file_path, fps=clip.fps)

os.remove(tmp_file_path_0)
os.remove(tmp_file_path_1)

print(f"Done! {output_file_path}")
