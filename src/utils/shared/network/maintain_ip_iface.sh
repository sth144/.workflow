#!/bin/bash

INTERFACE=$1

STATUS=$(ip addr | grep $INTERFACE | awk '{ print $9 }')

if [ "$STATUS" = "DOWN" ]; then
    /bin/systemctl restart NetworkManager
fi