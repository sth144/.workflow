#!/bin/bash

get_cpu_model() {
    RESULT=""
    
    CMD_OUTPUT=$(lscpu | grep "Model name" | awk '{print $3, $4, $5, $7, $8}')

    if (( $? == 0 )); 
    then
        RESULT="$CMD_OUTPUT"
    fi

    echo $RESULT

    exit 0
}

get_sensor_info() {
    RESULT=0
    
    CMD_OUTPUT=$(sensors | grep 'Core 0' | awk '{print $3}' | cut -b2,3)

    if (( $? == 0 )); 
    then
        RESULT=$CMD_OUTPUT
    fi

    echo $RESULT

    exit 0
}

$1