#!/bin/bash

path="/mnt/283A97C03A978988/Media/Pictures/Background Slides/"

while true
do
	pics=($(ls "$path" | grep -v " " | sort -R | tail -3 | xargs));
	feh --bg-fill "$path${pics[0]}" \
	    --bg-fill "$path${pics[1]}" \
	    --bg-fill "$path${pics[2]}";
	echo ${pics[@]}
	sleep 30;
done
