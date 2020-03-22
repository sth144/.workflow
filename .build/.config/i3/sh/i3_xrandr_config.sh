#!/bin/sh
xrandr --output VGA-0 --off \
	--output HDMI-1-1 --mode 1920x1080 --pos 2858x272 --rotate normal \
	--output DVI-0 --mode 1680x1050 --pos 0x0 --rotate left \
	--output HDMI-1 --primary --mode 1680x1050 --pos 1106x272 --rotate normal
