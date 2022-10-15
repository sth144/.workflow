#!/bin/bash

WEATHER=$(echo $(curl wttr.in?format="%c_%t_%w_%h" | tr '_' ' '))

if [ 0 -eq $? ]; 
then 
  echo "$WEATHER"
else
  echo "Failed to Retrieve Weather"
fi;