#!/bin/bash

if [ -z "$DISPLAY" ];
then
    echo "cpu_conky_exec finds DISPLAY empty, setting to :0"
    export DISPLAY=:1
fi

conky --config=/home/<USER>/.config/conky/cpu.config > /home/<USER>/.cache/.workflow/cpu-conky.log 2>&1
sleep 5
pgrep -n conky > /var/run/user/1000/conky-cpu.pid
