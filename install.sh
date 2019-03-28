#!/bin/bash

HOME_DIR=$(cat ./config.json \
	| grep "home directory" \
	| sed 's/\t"home_directory":"//g' \
	| sed 's/",$//g')

if [ -z "$HOME_DIR" ]; then
	echo "home directory not specified, run $ ./configure.sh" > &2
	exit 1
fi

build_configs() {
	#TODO
}

install_configs() {
	#TODO implement build and copy from build directory
	#cp -r ./configs/ ~/.config/
}

