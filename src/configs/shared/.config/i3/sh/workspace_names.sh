#!/bin/bash

get_workspace_number() {
    python3 -c "import json; print(next(filter(lambda w: w['focused'], json.loads('$(i3-msg -t get_workspaces)')))['num'])"
}

get_workspace_name() {
    i3-msg -t get_workspaces \
        | jq '.[] | select(.focused==true).name' \
        | cut -d"\"" -f2
}

while true; do
    WIN_CLASS=$(xprop -id $(xprop -root _NET_ACTIVE_WINDOW | cut -d ' ' -f 5) WM_CLASS | cut -d "," -f2 | sed 's/\"//g') 

    if [ -z $LAST_WIN ]; then
        LAST_WIN=$WIN_CLASS
    fi

    if [ "$WIN_CLASS" != "$LAST_WIN" ]; then 
        LAST_WIN=$WIN_CLASS

        if [ "$WIN_CLASS" != "" ]
        then 
            i3-msg "rename workspace \"$(get_workspace_name)\" to \"$(get_workspace_number): $WIN_CLASS\""
        fi
    fi

    echo "CLASS $WIN_CLASS NAME $(get_workspace_name) NUM $(get_workspace_number)"

    sleep 1
done
