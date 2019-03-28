#!/bin/bash

# get home directory (needed for sed to work)
HOME_ABS=~

# get the base directory
BASE_REL=$(dirname $0)
BASE_ABS=$(cd $BASE_REL && pwd)

# build configs (merge local and shared into build directory)
$BASE_REL/build.py

# copy config build to ~/.config dot directory
cp -r $BASE_REL/configs/build/* ~/.config/

# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths 
if [ ! -z "$(cat ~/.bashrc | grep WORKFLOW_BASE)" ]; then
	sed -i -e "s@export WORKFLOW_BASE=.*@export WORKFLOW_BASE=$BASE_ABS@g" "$HOME_ABS/.bashrc"	
else
	echo "export WORKFLOW_BASE=$BASE_ABS" >> ~/.bashrc
fi
