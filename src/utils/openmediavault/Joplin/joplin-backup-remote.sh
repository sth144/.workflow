#!/bin/bash

BACKUP_DIR="/home/<USER>/data/Archives/Backups/Joplin/joplin-backup.personal.remote.$(date +%Y-%m)/"

cp -r "/home/<USER>/data/Documents/Notes/Joplin" $BACKUP_DIR 