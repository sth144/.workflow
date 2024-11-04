
#!/bin/bash

# Dependencies:
# imagemagick
# i3lock
# scrot (optional but default)

IMAGE=/tmp/i3lock.png
SCREENSHOT="scrot $IMAGE" # 0.46s

BLURTYPE="2x8" # 2.90s

# Get the screenshot, add the blur and lock the screen with it
$SCREENSHOT
convert $IMAGE -blur $BLURTYPE $IMAGE


B='#00000000'  # blank
C='#ffffff22'  # clear ish
D='#5da0c2cc'  s# default
T='#5da0c2ee'  # text
W='#e84f4fbb'  # wrong
V='#fa75fabb'  # verifying

/usr/bin/i3_utillock -i $IMAGE -p default \
    --insidevercolor=$C   \
    --ringvercolor=$V     \
    \
    --insidewrongcolor=$C \
    --ringwrongcolor=$W   \
    \
    --insidecolor=$B      \
    --ringcolor=$D        \
    --linecolor=$B        \
    --separatorcolor=$D   \
    \
    --verifcolor=$T        \
    --wrongcolor=$T        \
    --timecolor=$T        \
    --datecolor=$T        \
    --layoutcolor=$T      \
    --keyhlcolor=$W       \
    --bshlcolor=$W        \
    \
    --screen 1            \
    --blur 5              \
    --clock               \
    --indicator           \
    --timestr="%H:%M:%S"  \
    --datestr="%A, %m %Y" \
    --keylayout 2         \

rm $IMAGE