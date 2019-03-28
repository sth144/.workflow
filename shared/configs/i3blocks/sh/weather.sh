#!/bin/bash

GREEN="color='green'"

query=$(curl wttr.in?format="%c_%t_%w_%h")

textcolor="#9999ff"

condition=$(echo $query | awk -F "_" '{print $1}')

echo $query | awk -F "_" -v clr="'$textcolor'" '{print "<span color=" clr ">" $1, $2, $3, $4 "</span>"}'
