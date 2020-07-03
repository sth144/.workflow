#!/bin/bash

export DISPLAY=':0.0'

if [ $# -ne 0 ]
then
	# can pass display name as first (optional) argument
	i3-msg "focus output $1"
fi

~/.util/i3/i3_run_scratchpad.sh \
	trello "/usr/bin/google-chrome-stable --app=https://trello.com/b/cK9nA9nR/to-do" 6 ".*ToDo.*" 1917 1096