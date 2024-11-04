#!/bin/bash

INPUT_VIDEO=$1
INPUT_AUDIO=$2
OUTPUT_VIDEO=$3

ffmpeg -i $INPUT_VIDEO -i $INPUT_AUDIO -c:v copy -c:a aac -map 0✌0 -map 1🅰0 $OUTPUT_VIDEO
