#!/usr/bin/env python

import cv2
import argparse

def duplicate_frames(input_filepath, output_filepath):
    # Read the input video
    cap = cv2.VideoCapture(input_filepath)

    # Get the input video's width, height, and frames per second
    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS)

    # Create a VideoWriter to save the output video
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(output_filepath, fourcc, fps, (2*width, height))

    # Iterate over each frame in the input video
    while cap.isOpened():
        ret, frame = cap.read()

        if not ret:
            break

        # Create a new frame with duplicated frames side by side
        output_frame = cv2.hconcat([frame, frame])

        # Write the frame to the output video
        out.write(output_frame)

    # Release the video capture and writer objects
    cap.release()
    out.release()

    print("Video processing complete.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Duplicate frames in an input MP4 video.')
    parser.add_argument('input', metavar='input_filepath', type=str, help='path to the input MP4 video')
    parser.add_argument('output', metavar='output_filepath', type=str, help='path to the output MP4 video')
    args = parser.parse_args()

    input_filepath = args.input
    output_filepath = args.output

    duplicate_frames(input_filepath, output_filepath)