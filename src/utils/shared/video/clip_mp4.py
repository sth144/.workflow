#!/usr/bin/env python

import cv2
import sys

def main():
    # Check if the input file is provided
    if len(sys.argv) < 2:
        print("Usage: python clip_video.py <filename.mp4>")
        sys.exit(1)

    filename = sys.argv[1]
    vidcap = cv2.VideoCapture(filename)

    # Check if the input file exists
    if not vidcap.isOpened():
        print("Could not open the input file.\n")
        sys.exit(1)


    # Get the frame dimension and total number of frames
    fps = vidcap.get(cv2.CAP_PROP_FPS)
    total_frames = int(vidcap.get(cv2.CAP_PROP_FRAME_COUNT))
    frame_width = int(vidcap.get(cv2.CAP_PROP_FRAME_WIDTH))
    frame_height = int(vidcap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    video_length = total_frames / fps

    # Loop to collect the start and end percentage points
    clipmarks = []
    while len(clipmarks) < 2:
        # Get the percentage from the user
        clipmark = input(f"Enter time to clip (0s-{video_length}s): ")
        try:
            clipmark = float(clipmark)
            if clipmark < 0 or clipmark > 100:
                print(f"Must be between 0 and {video_length}")
                continue
        except ValueError:
            print("Invalid clip time")
            continue

        # Compute the corresponding frame index and read the frame
        frame_idx = int(clipmark * fps)
        vidcap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
        success, frame = vidcap.read()
        if not success:
            print(f"Could not read a frame for clip mark {clipmark}")
            continue

        # Show the frame to the user and collect their input
        #cv2.imshow("Frame", frame)

        from PIL import Image

        # Convert the cv2 frame to PIL Image
        pil_image = Image.fromarray(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))

        # Display the frame in a new window
        pil_image.show()
        
        key = input("y/n")
        if key.lower() != 'y':
            continue

        clipmarks.append(clipmark)

    # Release the video capture object and close the image window
    vidcap.release()
    cv2.destroyAllWindows()

    # Sort the percentage points and clip the video
    clipmarks.sort()
    start_frame = int(fps * clipmarks[0])
    end_frame = int(fps * clipmarks[1])

    import datetime
    now = datetime.datetime.now()
    import os

    out_filename = os.path.expanduser(f"~/tmp/clipped.{now.strftime('%Y%m%d_%H%M%S')}.mp4")

    # Initialize a new video writer object with the output filename and video codec
    fourcc = cv2.VideoWriter_fourcc(*'mp4v')
    out = cv2.VideoWriter(out_filename, fourcc, fps, (frame_width, frame_height))

    # Re-open the video capture object and set the frame index to the start frame
    vidcap.open(filename)
    vidcap.set(cv2.CAP_PROP_POS_FRAMES, start_frame)

    # Loop over the frames between the start and end frames and write them to the output file
    for i in range(start_frame, end_frame + 1):
        success, frame = vidcap.read()
        if success:
            out.write(frame)
        else:
            print(f"Could not read frame {i} from the input file")

    # Release the input and output video resources
    vidcap.release()
    out.release()

    print(f"Clipped video saved to '{out_filename}'.")


if __name__ == "__main__":
    main()
