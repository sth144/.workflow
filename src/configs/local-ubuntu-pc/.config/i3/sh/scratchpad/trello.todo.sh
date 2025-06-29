#!/bin/bash

export DISPLAY=':1'

if [ $# -ne 0 ]
then
	# can pass display name as first (optional) argument
	i3-msg "focus output $1"
else
	i3-msg "focus output DVI-D-0"
fi

~/bin/i3_util/i3_run_scratchpad.sh trello \
	"/usr/bin/google-chrome-stable --app=https://trello.com/b/cK9nA9nR/to-do" \
	7 \
	".*ToDo.*" \
	1917 \
	1096