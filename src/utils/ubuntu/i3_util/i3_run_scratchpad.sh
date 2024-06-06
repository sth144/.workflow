#!/bin/bash

_DIR=$(dirname $0)

# needed for sed command file path. Tilde expansion happens before variable expansion
CONTROLLER="$_DIR/../xdotool/window_controller.sh"
SCRATCHPADS="scratchpads"

# params
WINDOW_KEY=$1
LAUNCH_CMD=$2
DELAY=$3
SEARCH_RGX=$4
WIDTH=$5
HEIGHT=$6

WINDOW_EXISTS="$($CONTROLLER window_exists $WINDOW_KEY)"

LAUNCH_NEW="true"
if [ $WINDOW_EXISTS = "true" ]; then
	LAUNCH_NEW="false"
	WINDOW_ID=$($CONTROLLER get_xid_from_key $WINDOW_KEY)
	WINDOW_INFO=$(xwininfo -id $WINDOW_ID)
	if (( $? == 1 )); then 
		LAUNCH_NEW="true"
		$CONTROLLER cache_delete $WINDOW_KEY
	fi
fi

if [ $LAUNCH_NEW = "true" ]; then
	$CONTROLLER launch $WINDOW_KEY "$LAUNCH_CMD" $DELAY $SEARCH_RGX $SCRATCHPADS
fi

WINDOW_ID=$($CONTROLLER get_xid_from_key $WINDOW_KEY)

if [ $LAUNCH_NEW = "true" ]; then
	# configure window
	i3-msg [id="$WINDOW_ID"] focus
 	i3-msg [id="$WINDOW_ID"] floating enable
  i3-msg [id="$WINDOW_ID"] resize set $WIDTH $HEIGHT
  i3-msg [id="$WINDOW_ID"] move scratchpad
  i3-msg [id="$WINDOW_ID"] border pixel 4
fi

i3-msg [id="$WINDOW_ID"] scratchpad show
i3-msg [id="$WINDOW_ID"] move position center
sleep 0.4
i3-msg [id="$WINDOW_ID"] move up 16px