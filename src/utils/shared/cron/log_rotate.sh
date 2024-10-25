#!/bin/bash

# mv /home/<USER>/.cache/.workflow/cronjob.log /home/<USER>/.cache/.workflow/cronjob.yesterday.log
# touch /home/<USER>/.cache/.workflow/cronjob.log

# mv /home/<USER>/.cache/.workflow/rsync.log /home/<USER>/.cache/.workflow/rsync.yesterday.log
# touch /home/<USER>/.cache/.workflow/rsync.log


LOG_DIR="/home/<USER>/.cache/.workflow"
LOG_PREFIX="cronjob"
LOG_SUFFIX="log"

for i in {9..1}; do
   prev_day=$(date --date="$i days ago" +%Y%m%d)
   prev_log="$LOG_DIR/$LOG_PREFIX.$prev_day.$LOG_SUFFIX"

   if [ -f "$prev_log" ]; then
       mv "$prev_log" "$LOG_DIR/$LOG_PREFIX.$((i + 1)).$LOG_SUFFIX"
   fi
done

mv "$LOG_DIR/$LOG_PREFIX.$LOG_SUFFIX" "$LOG_DIR/$LOG_PREFIX.1.$LOG_SUFFIX"
touch "$LOG_DIR/$LOG_PREFIX.$LOG_SUFFIX"

# Similar part for rsync.log
LOG_PREFIX="rsync"

for i in {9..1}; do
   prev_day=$(date --date="$i days ago" +%Y%m%d)
   prev_log="$LOG_DIR/$LOG_PREFIX.$prev_day.$LOG_SUFFIX"

   if [ -f "$prev_log" ]; then
       mv "$prev_log" "$LOG_DIR/$LOG_PREFIX.$((i + 1)).$LOG_SUFFIX"
   fi
done

mv "$LOG_DIR/$LOG_PREFIX.$LOG_SUFFIX" "$LOG_DIR/$LOG_PREFIX.1.$LOG_SUFFIX"
touch "$LOG_DIR/$LOG_PREFIX.$LOG_SUFFIX"