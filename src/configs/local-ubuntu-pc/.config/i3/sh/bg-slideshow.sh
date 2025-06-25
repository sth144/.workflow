#!/bin/bash

path="/mnt/D/Images/Background Slides/"

get_random_pic() {
    echo $(ls "$path" | grep -v " " | sort -R | tail -1)
}

while true; do

    # Get the list of available monitors
    monitors=$(xrandr | grep " connected" | awk '{print $1}')
 
    THE_PICTURE=$(get_random_pic)

    # Iterate through each monitor and set the background image
    for monitor in $monitors; do
        feh --bg-fill --no-fehbg --image-bg black --image-path "$path/$THE_PICTURE" --screen "$monitor"
    done

    sleep 30
done

