#!/bin/bash

# get home directory (needed for sed to work)
HOME_ABS=~

# get the base directory
BASE_REL=$(dirname $0)
BASE_ABS=$(cd $BASE_REL && pwd)

install() {
    echo "WARNING: If the following files exist, they will be overwritten"
    find "$BASE_ABS/build" -type f | sed 's/\/home.*build/~\/.config/g'
    read -p "Proceed? (y/n) " RESPONSE

    if [ $RESPONSE = "y" ]; then

        # copy config build to ~/.config dot directory
        cp -r $BASE_ABS/build/* ~/.config/

        # add .workflow base directory to path in ~/.bashrc
        # this allows scripts in other locations, as well as within .workflow, to call
        # workflow scripts without using relative paths 
        if [ ! -z "$(cat ~/.bashrc | grep WORKFLOW_BASE)" ]; then
            sed -i -e "s@export WORKFLOW_BASE=.*@export WORKFLOW_BASE=$BASE_ABS@g" "$HOME_ABS/.bashrc"	
        else
            echo "export WORKFLOW_BASE=$BASE_ABS" >> ~/.bashrc
        fi
    fi
}

refresh() {
    i3-msg restart
}

$1 "${@:2}"