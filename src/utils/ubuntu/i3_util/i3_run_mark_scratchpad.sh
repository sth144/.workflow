#!/bin/bash


# params
LAUNCH_CMD=$1
MARK=$2
DELAY=$3
WIDTH=$4
HEIGHT=$5

LOCKFILE="$HOME/.cache/.workflow/mark-lock.$MARK"

if test -f $LOCKFILE;
then
	echo "Lockfile exists, exiting"
	exit 1
fi

touch $LOCKFILE
echo "." > $LOCKFILE

i3-msg [con_mark="$MARK"] scratchpad show

LAUNCH_NEW=$?

echo "Launch new? $LAUNCH_NEW"

if (( $LAUNCH_NEW != 0 ))
then
	$LAUNCH_CMD &

	sleep $DELAY

	i3-msg "mark --add $MARK"
	i3-msg [con_mark="$MARK"] focus
   	i3-msg [con_mark="$MARK"] floating enable
    i3-msg [con_mark="$MARK"] border pixel 4
    i3-msg [con_mark="$MARK"] resize set $WIDTH $HEIGHT
    i3-msg [con_mark="$MARK"] move scratchpad
	i3-msg [con_mark="$MARK"] focus
fi

i3-msg [con_mark="$MARK"] move position center
sleep 0.4
i3-msg [con_mark="$MARK"] move up 16px
# i3-msg [con_mark="$MARK"] move up 

echo "Done, removing lockfile"

rm $LOCKFILE
