#!/bin/bash

# TODO: idempotent?
BACKUP_PATH="/home/<USER>/Drive/D/Archives/Backups/Joplin/joplin-backup.personal.$(date +%Y-%m)"
JOPLIN_BIN="/usr/bin/joplin-cli"

$JOPLIN_BIN sync
# TODO: set up e2ee?
# $JOPLIN_BIN --profile ~/.config/joplin-desktop e2ee decrypt

rm -f *.md
rm -f resources/*
$JOPLIN_BIN --profile ~/.config/joplin --log-level debug export --format raw "$BACKUP_PATH.raw"
$JOPLIN_BIN --profile ~/.config/joplin --log-level debug export --format jex "$BACKUP_PATH.jex"
