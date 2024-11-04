#!/usr/bin/env python
import argparse
from PIL import Image, ImageSequence

def ask_percentage():
    percent = int(input("Enter percentage: "))
    if percent < 0 or percent > 100:
        print("Percentage must be between 0 and 100.")
        return ask_percentage()
    return percent

def ask_y_n():
    answer = input("Enter y/n: ").strip().lower()
    if answer not in ['y', 'n']:
        print("Please enter 'y' or 'n'.")
        return ask_y_n()
    return answer == 'y'

def clip_gif(file_name, frame_a, frame_b):
    with Image.open(file_name) as im:
        frames = []
        for frame in ImageSequence.Iterator(im):
            frames.append(frame.copy())
        clip = frames[int(frame_a):int(frame_b)]
        clip[0].save(f"./tmp/clipped/{frame_a}-{frame_b}.{file_name.split('/')[-1].split('.gif')[0]}.gif", save_all=True, append_images=clip[1:])

def main():
    parser = argparse.ArgumentParser(description='Display frames of a GIF.')
    parser.add_argument('gif', metavar='file', type=str, help='GIF file name')
    args = parser.parse_args()

    with Image.open(args.gif) as im:
        duration = im.info['duration']
        total_frames = im.n_frames

        while True:
            percent = ask_percentage()
            frame_index = int(total_frames * percent / 100)

            frame = None
            for i, f in enumerate(ImageSequence.Iterator(im)):
                if i == frame_index:
                    frame = f.copy()
                    break

            frame.show()
            if ask_y_n():
                frame_a = frame_index
                break

        while True:
            percent = ask_percentage()
            frame_index = int(total_frames * percent / 100) - 1

            frame = None
            for i, f in enumerate(ImageSequence.Iterator(im)):
                if i == frame_index:
                    frame = f.copy()
                    break

            frame.show()
            if ask_y_n():
                frame_b = frame_index
                break

        clip_gif(args.gif, frame_a, frame_b)

if __name__ == '__main__':
    main()
