
#!/bin/bash

TARGET_PANES=7
current_panes=$(tmux list-panes -F '#{pane_id}' | wc -l | tr -d ' ')

if [ "$current_panes" -ne "$TARGET_PANES" ]; then
  if [ "$current_panes" -gt "$TARGET_PANES" ]; then
    while [ "$current_panes" -gt "$TARGET_PANES" ]; do
      pane_to_kill=$(tmux list-panes -F '#{pane_index}:#{pane_id}' | sort -n | tail -n1 | cut -d: -f2)
      tmux kill-pane -t "$pane_to_kill"
      current_panes=$((current_panes - 1))
    done
  fi

  while [ "$current_panes" -lt "$TARGET_PANES" ]; do
    tmux split-window -t 0
    current_panes=$((current_panes + 1))
  done

  tmux select-layout tiled
fi

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
