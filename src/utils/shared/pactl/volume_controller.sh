#!/bin/bash

get_volume() {
    pactl list sinks | grep '^[[:space:]]Volume:' | head -n 1 | tail -n 1 | sed -e 's/.* \([0-9][0-9]*\)%.*/\1/'
}

set_volume() {
    SET_POINT=$1
    pactl set-sink-volume $(get_running_sink) $SET_POINT%
}

inc_volume() {
    PERCENT_INC=$1
    if (( $(get_volume) <= (100 - $PERCENT_INC) ))
    then
        set_volume "+$1"
    fi
}

dec_volume() {
    PERCENT_DEC=$1
    echo "DEC $PERCENT_DEC"
    get_volume
    
    if (( $(get_volume) >= $PERCENT_DEC))
    then
        set_volume "-$1"
    else
        echo "NOPE"
    fi
}

mute() {
    set_volume $(get_running_sink) 0
}

get_running_sink() {
    RES=$(pactl list short | grep RUNNING | sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,')
    if [ "$RES" = "" ]
    then
        RES="@DEFAULT_SINK@"
    fi
    echo $RES
}

$1 "${@:2}"