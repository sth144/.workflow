#!/bin/bash

export DISPLAY=':0.0'

if [ $# -ne 0 ]
then
	# can pass display name as first (optional) argument
	i3-msg "focus output $1"
fi

~/.util/i3/i3_run_scratchpad.sh work \
	"/usr/bin/google-chrome-stable --app=https://trello.com/b/1IvnG5Ql/work" \
	6 \
	".*Work.*" \
	1917 \
	1096