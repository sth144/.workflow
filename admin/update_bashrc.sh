#!/bin/bash

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)

export_to_bashrc() {
    # params
    KEY=$1
    VALUE=$2

    if [ ! -z "$(cat ~/.bashrc | grep $KEY)" ]; then
        sed -i -e "s@export $KEY=.*@export $KEY=$VALUE@g" "$HOME/.bashrc"
    else
        echo "\nexport $KEY=$VALUE" >> ~/.bashrc
    fi
}

refresh() {
	source ~/.bashrc
}

# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths
export_to_bashrc "WORKFLOW_BASE" $BASE_ABS
export_to_bashrc "PYTHONPATH" "\"\${PYTHONPATH}:$BASE_ABS\""

refresh
