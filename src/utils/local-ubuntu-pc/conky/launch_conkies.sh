#!/bin/bash

kill -9 $(pidof conky)

sleep 1

cd /home/<USER>/.config/conky
# TODO: output PID to a pidfile, create a cronjob to restart when failed
cpu_conky_exec.sh
sleep 1
conky --config=/home/<USER>/.config/conky/gpu.config
conky --config=/home/<USER>/.config/conky/memory.config
conky --config=/home/<USER>/.config/conky/disk.config
conky --config=/home/<USER>/.config/conky/net.config
conky --config=/home/<USER>/.config/conky/sys.config
conky --config=/home/<USER>/.config/conky/trello.config
conky --config=/home/<USER>/.config/conky/tail.config
