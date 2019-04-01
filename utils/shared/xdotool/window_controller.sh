#!/bin/bash

xdotool=/usr/bin/xdotool
# store tempfile with key value pairs in user cache
_DIR=$(dirname $0)
_CACHEDIR="$_DIR/../../../.cache"
_TMPFILE="tmp_window_controller.dat"
_CACHE=$_CACHEDIR/$_TMPFILE

# debounce time between keystrokes, in seconds
DEBOUNCE=0.75

# wait 3 seconds for window to open
TIMEOUT=3

get_xid_from_pid() {
	# params	
	CMD_PID=$1

	# this will not work for complex multiprocess apps like chrome
	$xdotool search --pid $CMD_PID | tail -1	#TODO: handle multiples?
}

get_xid_from_rgx() {
	# params
	SEARCH_RGX=$1

	xdotool search --name "$SEARCH_RGX" | tail -1	#TODO: handle multiples?
}

get_pid_from_xid() {
	# params
	WINDOW_XID=$1	

	$xdotool getwindowpid $WINDOW_XID | tail -1 	#TODO: handle multiples?
}

get_xid_from_key() {
	# params
	WINDOW_KEY=$1

	cache_print | grep "^$WINDOW_KEY " | awk '{print $3}' | tail -1	#TODO: handle multiples?
}

get_pid_from_key() {
	# params
	WINDOW_KEY=$1
	
	cache_print | grep "^$WINDOW_KEY " | awk '{print $2}' | tail -1	#TODO: handle multiples?
}

key_exists() {
	# params
	WINDOW_KEY=$1

	RESULT="false"
	if [ ! -z $(cache_print | grep "^$WINDOW_KEY " | awk '{print $2}') ]; then
		RESULT="true"
	fi
	echo $RESULT
}

window_exists() {
	# params
	WINDOW_KEY=$1

	RESULT="false"
	QUERY_PID=$(get_pid_from_key $WINDOW_KEY)
	if [ ! -z "$QUERY_PID" ] && [ "$QUERY_PID" != "NULL" ]; then
		QUERY_XID=$($xdotool search --pid $QUERY_PID)
		if [ ! -z "$QUERY_XID" ] && [ "$QUERY_XID" != "NULL" ]; then
			RESULT="true"
		fi
	fi
	echo $RESULT
}

register_window() {
	# params
	WINDOW_KEY=$1
	WINDOW_XID=$2
	WINDOW_SET=$3

	RECONFD_PID=$(get_pid_from_xid $WINDOW_XID)

	if [ -z "$RECONFD_PID" ] || [ -z "$WINDOW_XID" ]; then
		RECONFD_PID="NULL"
		WINDOW_XID="NULL"
	fi	

	if [ $(key_exists $WINDOW_KEY) = "true" ]; then
		# overwrite expired entry, reconfirm pid
		sed -i "s/$WINDOW_KEY .*/$WINDOW_KEY $RECONFD_PID $WINDOW_XID $WINDOW_SET/g" \
			"$_CACHE"
	else
		# make a new entry in the temp file
		echo "$WINDOW_KEY $RECONFD_PID $WINDOW_XID $WINDOW_SET" >> $_CACHE
	fi
}

focus() {
	# params
	WINDOW_KEY=$1

	$xdotool windowactivate $(get_xid_from_key $WINDOW_KEY)
}

keystrokes_to() {
	# params
	KEYSTROKES=$1
	WINDOW_KEY=$2
	EXPLANATION=$3

	echo $EXPLANATION
	focus $WINDOW_KEY && $xdotool key $KEYSTROKES
	sleep $DEBOUNCE
}

move_to_workspace() {
	# params
	WINDOW_KEY=$1
	WORKSPACE=$2

	i3-msg [id="$(get_xid_from_key $WINDOW_KEY)"] move workspace $2
}

launch() {
	# params
	WINDOW_KEY=$1
	LAUNCH_CMD=$(echo "$2" | sed 's/_s_/ /g')   # translate spaces in command
	LOAD_DELAY=$3
	SEARCH_RGX=$4	
	WINDOW_SET=$5	# optional

	if [ $(window_exists $WINDOW_KEY) = "true" ]; then
		echo "Error: window with key $WINDOW_KEY already exists" >&2 
	else
		# launch app
		$LAUNCH_CMD &
		# get X window ID from PID

		CMD_PID=$(echo $!)

        # use a temp file and background command to implement asynchronous timeout
        WAIT_STAT_FILE="$_CACHEDIR/timout$$"
        touch $WAIT_STAT_FILE
        echo "wait" > $WAIT_STAT_FILE
        (sleep $TIMEOUT && echo "timeout" > $WAIT_STAT_FILE) &
	
		# TODO: make delays shorter (timeout should handle most cases)
		sleep $LOAD_DELAY
		
	        X_ID=""
	        # search for window using pid until window exists or timeout occurs
		while [ $(cat $WAIT_STAT_FILE) = "wait" ] && [ -z "$X_ID" ]; do  
			X_ID=$(get_xid_from_pid $CMD_PID)
            		sleep 0.01
        	done
        	rm $WAIT_STAT_FILE

		if [ -z "$X_ID" ] && [ ! -z "$SEARCH_RGX" ]; then
			X_ID=$(get_xid_from_rgx $SEARCH_RGX)
		fi
		register_window $WINDOW_KEY $X_ID $WINDOW_SET
	fi
}

attach() {
	# params
	WINDOW_KEY=$1
	SEARCH_RGX=$2
	LOAD_DELAY=$3	# optional
	WINDOW_SET=$4	# optional

	if [ ! -z "$3"  ]; then
		sleep $LOAD_DELAY
	fi
	if [ ! -z "$SEARCH_RGX" ]; then
		X_ID=$(get_xid_from_rgx $SEARCH_RGX)
		echo "$X_ID"
		register_window $WINDOW_KEY $X_ID $WINDOW_SET
	fi
}

cache_delete() {
	# params
	WINDOW_KEY=$1
	
	echo "$(cache_print | grep -v "^$WINDOW_KEY ")" > $_CACHE
}

cache_reset() {
	echo -n "" > $_CACHE
}

cache_print() {
	cat $_CACHE
}

cache_prune() {
	KEYS=($(cache_print | awk '{print $1}'))
	for KEY in "${KEYS[@]}"; do
		if [ "$(window_exists $KEY)" = "false" ]; then
			cache_delete $KEY
		fi
	done
}

kill_one() {
	# params
	WINDOW_KEY=$1

	kill -9 $(cache_print | grep "^$WINDOW_KEY " | tail -1 \
		| awk '{print $2}')
	cache_delete $WINDOW_KEY
}

kill_set() {
	#params
	SET_KEY=$1
	
	WINDOW_KEYS=($(cache_print |grep " $SET_KEY" | awk '{print $1}'))
	for WINDOW_KEY in "${WINDOW_KEYS[@]}"; do
		kill_one "$WINDOW_KEY"
	done
}

kill_all() {
	kill_set ".*"
}

touch $_CACHE
cache_prune

$1 "${@:2}"
