#!/bin/bash

touch i3config.txt
echo -e "				i3wm Keybinding Configuration\n\n" > i3config.txt
echo "Keystroke				Action" >> i3config.txt

cat /home/manager/.config/i3/config | grep "bindsym \$mod" \
	| grep -v "#" | sed -e 's/^[ \t]*//' \
	| awk '{ s = ""; for (i = 3; i<= NF; i++) s = s $i " "; printf("%-26s\t%-45s\n", $2, substr(s, 1, 45)) }' \
	>> i3config.txt
libreoffice --convert-to "pdf" i3config.txt --outdir # TODO

rm i3config.txt
