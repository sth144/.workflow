#!/bin/bash

# get home directory (needed for sed to work)
HOME_ABS=~

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)

install() {
	echo "WARNING: If the following files exist, they will be overwritten"
	find "$BASE_ABS/.build" -type f | sed 's/.*\.build/\~/g'
	read -p "Proceed? (y/n) " RESPONSE

	if [ $RESPONSE = "y" ]; then
	# copy config build to ~ (and  ~/.config dot directory)
		cp -r $BASE_ABS/.build/. ~/

		# TODO: remove .keep and README's
	fi
}

refresh() {
    i3-msg restart
}

$1 "${@:2}"

