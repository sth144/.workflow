#!/usr/bin/env python

import cv2
import imageio
import numpy as np
import sys

input_path = sys.argv[1]
output_path = sys.argv[2]


def crop_gif_frames(input_path, output_path, x_start, y_start, x_end, y_end):
    gif = imageio.get_reader(input_path)
    fps = gif.get_meta_data()['fps']
    frames = []

    for frame in gif:
        cropped_frame = frame[y_start:y_end, x_start:x_end]
        frames.append(cropped_frame)

    imageio.mimsave(output_path, frames, fps=fps)

def select_rectangle(event, x, y, flags, param):
    global x_start, y_start, x_end, y_end, cropping

    if event == cv2.EVENT_LBUTTONDOWN:
        x_start, y_start = x, y
        cropping = True
    elif event == cv2.EVENT_LBUTTONUP:
        x_end, y_end = x, y
        cropping = False
        crop_gif_frames(input_path, output_path, x_start, y_start, x_end, y_end)

cv2.namedWindow('Select Rectangle')
cv2.setMouseCallback('Select Rectangle', select_rectangle)

cropping = False
x_start, y_start, x_end, y_end = -1, -1, -1, -1

gif = imageio.get_reader(input_path)
frame = gif.get_next_data()
cv2.imshow('Select Rectangle', frame)

while True:
    if not cropping:
        cv2.imshow('Select Rectangle', frame)
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cv2.destroyAllWindows()