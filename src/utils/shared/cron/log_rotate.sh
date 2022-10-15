#!/bin/bash

mv /home/<USER>/.cache/.workflow/cronjob.log /home/<USER>/.cache/.workflow/cronjob.yesterday.log
touch /home/<USER>/.cache/.workflow/cronjob.log

mv /home/<USER>/.cache/.workflow/rsync.log /home/<USER>/.cache/.workflow/rsync.yesterday.log
touch /home/<USER>/.cache/.workflow/rsync.log



