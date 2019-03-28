#!/bin/bash

FINISHED="false"

HOME_DIR="/home/$(whoami)"

while [ $FINISHED = "false" ]; do
	echo "default home directory is $HOME_DIR"
	read -p "does this look ok? (y/n) " RESPONSE
	
	if [ $RESPONSE = "n" ]; then
		read -p "enter an absolute path: " HOME_DIR
	fi

	echo "home path: $HOME_DIR"
	read -p "does this look OK? (y/n) " RESPONSE

	if [ $RESPONSE = "y" ]; then
		read -p "./config.json will be overwritten, proceed? (y/n) " RESPONSE
	       	if [ $RESPONSE = "y" ]; then	
			FINISHED="true"
		fi
	fi

	if [ $FINISHED = "false" ]; then
		read -p "start over? (y/n) " RESPONSE
		if [ $RESPONSE != "y" ]; then
			exit 1
		fi
	fi
done 

echo "{" > ./config.json
echo "	\"home_directory\": \"$HOME_DIR\"," >> ./config.json
echo "}" >> ./config.json

