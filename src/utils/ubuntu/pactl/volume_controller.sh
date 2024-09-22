#!/bin/bash


print_volume_for_display() {
    echo "$(get_icon) $(get_volume)"
}

get_volume() {
    pactl list sinks | grep '^[[:space:]]Volume:' | tail -n 1 | sed -e 's/.* \([0-9][0-9]*\)%.*/\1/'
}

set_volume() {
    SET_POINT=$1
    pactl set-sink-volume alsa_output.pci-0000_01_00.1.hdmi-stereo $SET_POINT%
    # pactl set-sink-volume $(get_running_sink) $SET_POINT%
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
    set_volume "-$1"
}

mute() {
    pactl set-sink-mute $(get_running_sink) "toggle"
}

get_running_sink() {
    RES=$(pactl list short | grep RUNNING | awk '{ print $2 }')
    # RES=$(pactl list short | grep RUNNING | sed -e 's,^\([0-9][0-9]*\)[^0-9].*,\1,')
    if [ "$RES" = "" ]
    then
        # RES="@DEFAULT_SINK@"
        RES="alsa_output.pci-0000_01_00.1.hdmi-stereo"
    fi
    echo $RES
}

get_icon() {
    ISMUTED=$(pacmd list-sinks | awk '/muted/ { print $2 }' | tail -1)
    if [ "$ISMUTED" = "yes" ]
    then
        echo 🔇
    else
        echo 🔊
    fi
}

$1 "${@:2}"
