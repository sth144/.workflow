#!/bin/bash

export DISPLAY=':1'

if [ $# -ne 0 ]
then
	# can pass display name as first (optional) argument
	i3-msg "focus output $1"
fi

~/bin/i3_util/i3_run_scratchpad.sh work \
	"/usr/bin/google-chrome-stable --app=https://trello.com/b/1IvnG5Ql/work" \
	7 \
	".*Work | Trello.*" \
	1917 \
	1096