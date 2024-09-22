#!/bin/bash

export DISPLAY=':1'

if [ $# -ne 0 ]
then
	# can pass display name as first (optional) argument
	i3-msg "focus output $1"
else
	i3-msg "focus output DP-5"
fi

~/bin/i3_util/i3_run_mark_scratchpad.sh \
	"/usr/bin/google-chrome-stable --app=https://calendar.google.com/calendar/r" \
	"Calendar" \
	2 \
	1917 \
	1096