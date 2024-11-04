#!/bin/bash

$ cat input.txt | \
		pico2wave -w tmp.pico.wav -l en-US
$ ffmpeg -i tmp.pico.wav -vn -ar 44100 -ac 2 -b:a 192k ~/Drive/D/$MP3_PATH
$ rm tmp.pico.wav

