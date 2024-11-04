#!/bin/bash

if $(tmux has-session -t IDE);
then
    echo "Attaching to existing IDE session"
    tmux attach -t IDE;
else
    echo "No IDE session found, starting TMUX"
    tmux;
fi 
