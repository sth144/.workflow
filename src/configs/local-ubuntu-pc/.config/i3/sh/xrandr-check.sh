#!/bin/bash

export DISPLAY=:1

# Run the saved layout whenever two or more monitors are visible.
num_monitors=$(xrandr --listmonitors | grep -c "^ ")

if [ "$num_monitors" -ge 2 ]; then
  /home/<USER>/.config/i3/sh/xrandr-layout.sh
fi
