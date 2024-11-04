#!/usr/bin/env python

import imageio
import argparse

def gif_to_mp4(gif_file, mp4_file):
    # Read the GIF file
    gif = imageio.mimread(gif_file)

    # Convert the GIF frames to a video
    imageio.mimwrite(mp4_file, gif, format="FFMPEG", codec="libx264")

    print(f"GIF '{gif_file}' converted to MP4 '{mp4_file}'")

if __name__ == "__main__":
    # Parse command line arguments
    parser = argparse.ArgumentParser(description="Convert GIF to MP4")
    parser.add_argument("gif_file", help="Path to the input GIF file")
    parser.add_argument("mp4_file", help="Path to the output MP4 file")
    args = parser.parse_args()

    # Convert the GIF to MP4
    gif_to_mp4(args.gif_file, args.mp4_file)
