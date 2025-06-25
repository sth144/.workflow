#!/bin/bash

export DISPLAY=:1

# xrandr --addmode DVI-D-0 1680x1050
# xrandr --addmode HDMI-0 1920x1080
# xrandr --addmode DP-5 1920x1080
#xrandr --addmode HDMI-1-0 1920x1080
xrandr  --output DP-5 --primary \
				--output HDMI-0 --left-of DP-5  --mode 1680x1050  --rotate left \
				--output DVI-D-0 --right-of DP-5 --mode 1920x1080 --rotate normal
	# --output DP-3 --left-of DP-5 --rotate left --mode 1680x1050  \
#xrandr  --output HDMI-0 --primary --mode 1920x1080 \
#        --output DVI-D-0 --rotate left --left-of HDMI-0 --mode 1920x1080 --pos -2x0 
# --output HDMI-1 --right-of HDMI-1-0 --mode 1920x1080
