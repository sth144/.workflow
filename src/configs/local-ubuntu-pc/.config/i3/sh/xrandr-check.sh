#!/bin/bash

export DISPLAY=:1

# Get the number of monitors
num_monitors=$(xrandr --listmonitors | grep -c "^ ")

# Print "Hello" if there are 2 monitors
if [ $num_monitors -eq 2 ]; then
  /home/<USER>/.config/i3/sh/xrandr-layout.sh
fi
