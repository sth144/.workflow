#!/usr/bin/env python

import os
import subprocess
import sys
from datetime import datetime

def smooth_video(input_file):
    # Create output file name with timestamp
    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    out_file = os.path.join(os.path.expanduser("~/tmp"), f"smoothed.{timestamp}." + os.path.basename(input_file))

    # Command to run ffmpeg with frame interpolation
    command = [
        'ffmpeg',
        '-i', input_file,
        '-filter:v', 'minterpolate=fps=60',
        '-c:a', 'copy',
        out_file
    ]

    # Run ffmpeg command
    try:
        output = subprocess.check_output(command, stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as e:
        print(e.output)
        sys.exit()

    print("Output file saved to:", out_file)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Please provide input video file path")
        sys.exit()
    input_file = sys.argv[1]
    smooth_video(input_file)
