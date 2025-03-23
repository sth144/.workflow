#!/bin/bash

function writeFile() {
    sudo nmap -sP 192.168.1.0/24 \
        | awk '/Nmap scan report for/{$1=$2=$3=$4=""; printf $0;}/MAC Address:/{$1=$2=$3=""; print $0;}' \
        | awk '{$1=$1;print}' \
        > /home/<USER>/.cache/.workflow/network_devices.dat
}

function readFile() {
    OUTSTR=""
    LINE=""
    INSTR=$(cat /home/sthinds/.cache/.workflow/network_devices.dat | tr " " "#" | tr "\n" " ")

    NUM_DEVICES=$(echo $INSTR | wc -w)

    ITEM_IDX=0
    LINE_NUM=0
    LINE_ITEM_IDX=0

    for item in $INSTR;
    do
        item=$(echo $item | tr "#" " ")

        if (( $(expr length "$LINE, $item") < 75 ));
        then
            if (( $LINE_ITEM_IDX == 0 ));
            then
                LINE="$item"
            else
                LINE="$LINE, $item"
            fi
            if (( $ITEM_IDX == $(($NUM_DEVICES - 1)) ));
            then
                OUTSTR="$OUTSTR\n$LINE"
                LINE=""
                LINE_NUM=$((LINE_NUM+1))
                LINE_ITEM_IDX=0
            else
                LINE_ITEM_IDX=$(($LINE_ITEM_IDX+1))
            fi
        else
            if (( $LINE_NUM == 0 ));
            then
                OUTSTR="$LINE,"
            else
                OUTSTR="$OUTSTR\n$LINE,"        
            fi
            LINE="$item"
            LINE_NUM=$((LINE_NUM+1))
            LINE_ITEM_IDX=1
        fi

        ITEM_IDX=$(($ITEM_IDX+1))
    done

    echo -e "$OUTSTR"
} 

$1 "${@:2}"