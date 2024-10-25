#!/bin/bash

mkdir -p /home/<USER>/tmp/lock
IMAGE=/home/<USER>/tmp/lock/i3lock.png
rm $IMAGE
SCREENSHOT="scrot $IMAGE" # 0.46s

BLURTYPE="2x8" # 2.90s

# Get the screenshot, add the blur and lock the screen with it
$SCREENSHOT
convert $IMAGE -blur $BLURTYPE $IMAGE

i3lock -i $IMAGE


