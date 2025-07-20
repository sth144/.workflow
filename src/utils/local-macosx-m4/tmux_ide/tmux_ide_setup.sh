#!/bin/bash

# Select the first pane (pane indices start at 0)
tmux select-pane -t 1

# Send a command to the first pane
tmux send-keys 'ranger' C-m

# Select the second pane
tmux select-pane -t 2

tmux send-keys '/bin/bash' C-m

tmux select-pane -t 3

# Send another command to the second pane
tmux send-keys 'ssh sthinds@sthinds.local' C-m

tmux select-pane -t 4

tmux send-keys 'ssh pi@raspberrypi.local' C-m

tmux select-pane -t 5

tmux send-keys 'ssh picocluster@pc0' C-m

tmux select-pane -t 7

tmux send-keys 'ssh sthinds@openmediavault.local' C-m

tmux select-pane -t 8

tmux send-keys 'htop' C-m
