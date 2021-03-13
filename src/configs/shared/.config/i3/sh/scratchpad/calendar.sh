#!/bin/bash

export DISPLAY=':0.0'

if [ $# -ne 0 ]
then
	# can pass display name as first (optional) argument
	i3-msg "focus output $1"
else
	i3-msg "focus output HDMI-1-1"
fi

~/bin/i3/i3_run_scratchpad.sh calendar \
	"/usr/bin/google-chrome-stable --app=https://calendar.google.com/calendar/r" \
	2 \
	".*Calendar.*" \
	1917 \
	1096