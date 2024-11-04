#!/usr/bin/env python 
import os
from PIL import Image, ImageSequence, ImageDraw
import argparse

def crop_gif(gif_filepath, output_filepath):
    # Open the GIF file
    with Image.open(gif_filepath) as im:
        # Extract the first frame of the GIF
        first_frame = im.convert("RGBA").resize(im.size, Image.NEAREST)

        # Get image dimensions
        width, height = first_frame.size

        # Calculate tick mark intervals
        tick_interval_x = int(width / 10)
        tick_interval_y = int(height / 10)

        # Create a drawing object
        draw = ImageDraw.Draw(first_frame)

        # Draw vertical tick marks
        for x in range(0, width, tick_interval_x):
            draw.line([(x, 0), (x, height-1)], fill="blue")

        # Draw horizontal tick marks
        for y in range(0, height, tick_interval_y):
            draw.line([(0, y), (width-1, y)], fill="red")
            
        first_frame.show()

    cropped_frames = []

    # Prompt the user for cropping percentages
    while True:
        try:
            left = float(input("Enter the cropping percentage from the left (0-100): ")) / 100
            right = float(input("Enter the cropping percentage from the right (0-100): ")) / 100
            top = float(input("Enter the cropping percentage from the top (0-100): ")) / 100
            bottom = float(input("Enter the cropping percentage from the bottom (0-100): ")) / 100
        except ValueError:
            print("Invalid input. Please enter a valid percentage.")
            continue

        # Crop the first frame according to the provided percentages
        width, height = first_frame.size
        left_crop = int(width * left)
        right_crop = int(width * (1 - right))
        top_crop = int(height * top)
        bottom_crop = int(height * (1 - bottom))

        cropped_frame = first_frame.crop((left_crop, top_crop, right_crop, bottom_crop))
        cropped_frames.append(cropped_frame)

        # Display the cropped frame and ask for user confirmation
        cropped_frame.show()
        user_input = input("Do you want to proceed with this cropping? (y/n)").lower()

        if user_input == 'n':
            continue  # Prompt again for cropping percentages
        elif user_input == 'y':
            break  # User confirmed; exit the loop
        else:
            print("Invalid input. Please enter 'y' or 'n'.")
            continue

    # Create a directory for the output path (if not exists)
    os.makedirs(os.path.dirname(output_filepath), exist_ok=True)

    # Iterate through all frames of the GIF and apply the cropping to each frame
    with Image.open(gif_filepath) as im:
        for frame in ImageSequence.Iterator(im):
            frame = frame.convert("RGBA").resize(im.size, Image.NEAREST)
            frame = frame.crop((left_crop, top_crop, right_crop, bottom_crop))
            cropped_frames.append(frame)

    print("Saving GIF")

    # Save the cropped frames as a new GIF
    cropped_frames[0].save(output_filepath, format='GIF', append_images=cropped_frames[1:], save_all=True,
                           duration=100, loop=0)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Crop frames of a GIF file.')
    parser.add_argument('file', metavar='file_path', type=str, help='path to the input GIF file')
    parser.add_argument('-o', '--output', type=str, default=os.path.expanduser('~/tmp/output_cropped.gif'),
                        help='output path for the cropped GIF file (default: ~/tmp/output_cropped.gif)')
    args = parser.parse_args()

    input_filepath = args.file
    output_filepath = args.output

    crop_gif(input_filepath, output_filepath)