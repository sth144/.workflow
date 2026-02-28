#!/bin/bash

TARGET_PANES=8
target_pane="${TMUX_PANE}"
if [ -z "$target_pane" ]; then
  target_pane=$(tmux display-message -p '#{pane_id}' 2>/dev/null)
fi
if [ -z "$target_pane" ]; then
  echo "tmux_ide_setup.sh: must be run from inside tmux." >&2
  exit 1
fi

current_panes=$(tmux list-panes -t "$target_pane" -F '#{pane_id}' | wc -l | tr -d ' ')

if [ "$current_panes" -ne 1 ]; then
  tmux list-panes -t "$target_pane" -F '#{pane_id}' | while read -r pane_id; do
    if [ "$pane_id" != "$target_pane" ]; then
      tmux kill-pane -t "$pane_id"
    fi
  done
fi

file_explorer_pane="$target_pane"
right_pane=$(tmux split-window -t "$file_explorer_pane" -h -p 75 -P -F '#{pane_id}')
htop_pane=$(tmux split-window -t "$file_explorer_pane" -v -p 33 -P -F '#{pane_id}')
bottom_pane=$(tmux split-window -t "$right_pane" -v -p 35 -P -F '#{pane_id}')
main_pane="$bottom_pane"
bash_pane=$(tmux split-window -t "$main_pane" -h -p 60 -P -F '#{pane_id}')
codex_pane="$main_pane"
right_col_pane=$(tmux split-window -t "$right_pane" -h -p 50 -P -F '#{pane_id}')
left_col_pane="$right_pane"
left_bottom_pane=$(tmux split-window -t "$left_col_pane" -v -p 50 -P -F '#{pane_id}')
left_top_pane="$left_col_pane"
right_bottom_pane=$(tmux split-window -t "$right_col_pane" -v -p 50 -P -F '#{pane_id}')
right_top_pane="$right_col_pane"

tmux select-pane -t "$file_explorer_pane" -T "Files"
tmux select-pane -t "$codex_pane" -T "Codex"
tmux select-pane -t "$bash_pane" -T "Shell"
tmux select-pane -t "$htop_pane" -T "Monitor"
tmux select-pane -t "$left_top_pane" -T "Mac Mini"
tmux select-pane -t "$left_bottom_pane" -T "Pi"
tmux select-pane -t "$right_top_pane" -T "pc0"
tmux select-pane -t "$right_bottom_pane" -T "OMV"

tmux send-keys -t "$file_explorer_pane" 'ranger' C-m
tmux send-keys -t "$codex_pane" 'codex' C-m
tmux send-keys -t "$bash_pane" '/bin/bash' C-m
tmux send-keys -t "$htop_pane" 'htop' C-m
tmux send-keys -t "$left_top_pane" 'ssh sthinds@sthinds.local' C-m
tmux send-keys -t "$left_bottom_pane" 'ssh pi@192.168.1.243' C-m
tmux send-keys -t "$right_top_pane" 'ssh picocluster@pc0' C-m
tmux send-keys -t "$right_bottom_pane" 'ssh sthinds@openmediavault.local' C-m
