#!/bin/bash

function writeFile() {
    sudo nmap -sP 192.168.1.0/24 \
        | awk '/Nmap scan report for/{$1=$2=$3=$4=""; printf $0;}/MAC Address:/{$1=$2=$3=""; print $0;}' \
        | awk '{$1=$1;print}' \
        > /home/<USER>/.cache/.workflow/network_devices.dat
}

function readFile() {
    cat /home/<USER>/.cache/.workflow/network_devices.dat
} 

$1 "${@:2}"