#!/usr/bin/env python

import os
import cv2
import moviepy.editor as mp

def overlay_audio(input_dir, target_dir, output_dir):
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Iterate over the videos in the target directory
    for target_file in os.listdir(target_dir):
        target_filepath = os.path.join(target_dir, target_file)
        output_filepath = os.path.join(output_dir, target_file)

        # Check if the file is a video
        if target_filepath.endswith(".mp4"):
            # Get the corresponding video file from the input directory
            input_filepath = os.path.join(input_dir, target_file)

            # Load the video file from the target directory using moviepy
            target_clip = mp.VideoFileClip(target_filepath)

            # Get the audio from the input video file
            audio_clip = mp.AudioFileClip(input_filepath)

            # Set the audio of the target video clip with the input audio
            target_clip = target_clip.set_audio(audio_clip)

            # Write the final video with audio to the output file
            target_clip.write_videofile(output_filepath, codec="libx264")

            # Close the clips and delete the readers to release resources
            target_clip.close()
            audio_clip.close()
            del target_clip.reader
            del audio_clip.reader

            print(f"Video '{target_file}' processed successfully.")

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