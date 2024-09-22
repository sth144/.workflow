#!/bin/bash

BACKUP_DIR="/home/<USER>/data/Archives/Backups/Joplin/joplin-backup.personal.remote.$(date +%Y-%m)/"

cp -r "/home/<USER>/data/Documents/Notes/Joplin" $BACKUP_DIR

BACKUP_DIR="/home/<USER>/data/Archives/Backups/Joplin-L7/joplin-backup.l7.remote.$(date +%Y-%m)/"

cp -r "/home/<USER>/data/Documents/Notes/Joplin-L7" $BACKUP_DIR



