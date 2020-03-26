#!/bin/bash

# get home directory (needed for sed to work)
HOME_ABS=~

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)

install() {
	echo "WARNING: If the following files exist, they will be overwritten"
	find "$BASE_ABS/stage" -type f | sed 's/.*stage/\~/g' | grep -v ".keep"
	read -p "Proceed? (y/n) " RESPONSE

	if [ $RESPONSE = "y" ]; then
	# copy config build and utils to ~ 
		cp -r $BASE_ABS/stage/. ~/

        rm ~/.keep
	fi
}

refresh() {
    i3-msg restart
}

$1 "${@:2}"
