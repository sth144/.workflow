#!/usr/bin/env python

import os
import shutil
import moviepy.editor as mp

def overlay_audio(input_dir, target_dir, output_dir):
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)



    # Walk through the directory tree of the target directory
    for root, dirs, files in os.walk(target_dir):
        # Create corresponding subdirectories in the output directory
        relative_path = os.path.relpath(root, target_dir)
        output_subdir = os.path.join(output_dir, relative_path)
        os.makedirs(output_subdir, exist_ok=True)

        # Iterate over the files in the target directory
        for file in files:
            target_file = os.path.join(root, file)
            input_file = os.path.join(input_dir, relative_path, file)
            output_file = os.path.join(output_dir, relative_path, file)

            print(f"{input_file} -> {target_file} ==> {output_file}")

            # Check if the file is an mp4 video
            if file.endswith(".mp4"):
                # Load the video file from the target directory using moviepy
                target_clip = mp.VideoFileClip(target_file)
                input_clip = mp.VideoFileClip(input_file)

                # Get the audio from the input video file
                input_audio = input_clip.audio

                # If the target video is longer, loop the audio from the input video
                if target_clip.duration > input_clip.duration:
                    input_audio_duration = input_audio.duration
                    input_audio = mp.composite.audio_loop(input_audio, duration=target_clip.duration)

                # Set the audio of the target video clip with the input audio
                target_clip = target_clip.set_audio(input_audio)

                # Write the final video with audio to the output file
                target_clip.write_videofile(output_file, codec="libx264")

                # Close the clips and delete the readers to release resources
                target_clip.close()
                input_clip.close()
                del target_clip.reader
                del input_clip.reader

                print(f"Video '{file}' processed successfully.")

    print("All videos processed successfully.")

if __name__ == '__main__':
    import argparse

    parser = argparse.ArgumentParser(description='Duplicate frames in an input MP4 video.')
    parser.add_argument('input', metavar='input_directory', type=str, help='path to the input MP4 video')
    parser.add_argument('target', metavar='target_directory', type=str, help='path to the output MP4 video')
    parser.add_argument('output', metavar='output_directory', type=str, help='path to the output MP4 video')
    args = parser.parse_args()

    input_directory = args.input
    output_directory = args.output
    target_directory = args.target


    # Call the function to overlay audio from the input directory onto videos in the target directory
    overlay_audio(input_directory, target_directory, output_directory)