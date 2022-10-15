#!/bin/bash

# monkey patch to add mDNS host name to /etc/hosts, because some services can't
#    seem to make use of mDNS host names (ie. Prometheus)

if [ $# == 0 ];
then
    exit 1
fi

cp /etc/hosts /etc/hosts.tmp

TARGET_HOSTNAME=$1

RECORDED_IP=$(cat /etc/hosts.tmp | grep "$TARGET_HOSTNAME" | awk '{ print $1 }')

NEW_IP=$(ping $TARGET_HOSTNAME -4 | head -1 | awk '{print $3}' | sed "s/(//g" | sed "s/)//g")

sed -i "s/$RECORDED_IP/$NEW_IP/g" /etc/hosts.tmp

cp /etc/hosts.tmp /etc/hosts
mv /etc/hosts.tmp /etc/hosts.backup
