#!/bin/bash

HOME_DIR=$(cat ./config.json \
	| grep "home directory" \
	| sed 's/\t"home_directory":"//g' \
	| sed 's/",$//g')

install_configs() {
	cp -r ./configs/ ~/.config/
}

