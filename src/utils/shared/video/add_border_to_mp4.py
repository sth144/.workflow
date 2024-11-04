#!/usr/bin/env python   

import cv2
import argparse

def add_border_to_mp4(input_path, output_path, width_percent, top_percent, bottom_percent):
    # Open the input video file
    video = cv2.VideoCapture(input_path)

    # Create a VideoWriter object to write the output video
    width = int(video.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(video.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = video.get(cv2.CAP_PROP_FPS)
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    output_video = cv2.VideoWriter(output_path, fourcc, fps, (width, height))

    # Calculate border dimensions based on percentages
    border_width = int(width * width_percent / 100)
    border_height_top = int(height * top_percent / 100)
    border_height_bottom = int(height * bottom_percent / 100)

    # Read and process each frame
    while video.isOpened():
        ret, frame = video.read()
        if not ret:
            break

        # Add the border to the frame
        bordered_frame = cv2.copyMakeBorder(
            frame, border_height_top, border_height_bottom, border_width, border_width,
            cv2.BORDER_CONSTANT
        )

        # Resize the frame to match the original size
        bordered_frame = cv2.resize(bordered_frame, (width, height))

        # Write the framed frame to the output video
        output_video.write(bordered_frame)

    # Release the resources
    video.release()
    output_video.release()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('input', help='Input MP4 file path')
    parser.add_argument('output', help='Output MP4 file path')
    parser.add_argument('--top_percent', type=float, default=5, help='Percentage top border')
    parser.add_argument('--bottom_percent', type=float, default=5, help='Percentage bottom border')
    parser.add_argument('--width_percent', type=float, default=5, help='Percentage width border')
    args = parser.parse_args()

    add_border_to_mp4(args.input, args.output, args.width_percent, args.top_percent, args.bottom_percent)
