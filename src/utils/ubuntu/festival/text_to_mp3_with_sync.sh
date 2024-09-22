#!/bin/bash

if [[ $# < 1 ]]
then
  echo "Usage: text_to_mp3_with_sync.sh <filepath>"
  exit 1
fi

MP3_PATH="Audio/Text-to-Speech/$1"

text2wave -o ~/Drive/D/$MP3_PATH $HOME/tmp/input.txt -eval "(voice_cmu_us_slt_arctic_hts)"

rsync -rv ~/Drive/D/$MP3_PATH ~/Drive/O/$MP3_PATH
