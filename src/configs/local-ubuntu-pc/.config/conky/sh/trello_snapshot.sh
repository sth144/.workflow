#!/bin/bash

echo "To Do"
~/bin/trello show-cards -b ToDo -l Today | awk '{$1=$2=""; print $0}' | tail -n +2

DOW=$(date +%u)

if (( $DOW < 6 ))
then
    echo "Work"
    ~/bin/trello show-cards -b Work -l Today | awk '{$1=$2=""; print $0}' | tail -n +2
fi