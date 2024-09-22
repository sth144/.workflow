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
        echo "$WIN_CLASS $LAST_WIN"

        LAST_WIN=$WIN_CLASS

        if [ "$WIN_CLASS" != "" ]; then 
            CUR_WS_NAME=$(get_workspace_name)
            CUR_WS_NUMBER=$(get_workspace_number)

            CHECK_NUMBER_IN_USE=$(i3-msg -t get_workspaces | jq '.[] | .name' | grep -c $CUR_WS_NUMBER)
            if (( $CHECK_NUMBER_IN_USE > 1 ))
            then
                CUR_WS_NUMBER=1
                while (( $CHECK_NUMBER_IN_USE > 1 ))
                do
                    CUR_WS_NUMBER=$(($CUR_WS_NUMBER + 1))
                done
            fi
        
            i3-msg "rename workspace \"$CUR_WS_NAME\" to \"$CUR_WS_NUMBER:$WIN_CLASS\""
        fi
    fi

    sleep 1
done
