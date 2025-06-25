
#!/bin/bash

# Select the first pane (pane indices start at 0)
tmux select-pane -t 1

# Send a command to the first pane 
tmux send-keys 'ranger' C-m

# Select the second pane
tmux select-pane -t 2

# Send another command to the second pane 
tmux send-keys 'k9s' C-m

tmux select-pane -t 3

tmux send-keys 'source venv/bin/activate; python src/chatgpt.py' C-m

tmux select-pane -t 4

tmux send-keys 'htop' C-m

tmux select-pane -t 5

tmux send-keys 'bash' C-m

tmux select-pane -t 6

tmux send-keys 'bash' C-m