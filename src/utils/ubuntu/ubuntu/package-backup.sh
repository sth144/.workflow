#!/bin/bash

make_backup() {
    BACKUP_TMP_DIR="$HOME/tmp/$(whoami)@$(hostname)-$(date +%s)"
    mkdir -p $BACKUP_TMP_DIR
    dpkg --get-selections > "$BACKUP_TMP_DIR/Package.list"
    sudo cp -R /etc/apt/sources.list* "$BACKUP_TMP_DIR"
    sudo apt-key exportall > "$BACKUP_TMP_DIR/Repo.keys"
    mkdir -p $BACKUP_TMP_DIR/profile
    rsync --progress /home/`whoami` $BACKUP_TMP_DIR/profile
    
    zip -r "$BACKUP_TMP_DIR.zip" $BACKUP_TMP_DIR
    # TODO: move zip to backup location
    mkdir -p $HOME/Drive/D/Archives/Backups/$(whoami)@$(hostname)
    mv "$BACKUP_TMP_DIR.zip" $HOME/Drive/D/Archives/Backups/$(whoami)@$(hostname)/
    sudo rm -rf $BACKUP_TMP_DIR
}

revert_to_backup() {
    echo "Revert $1"

    cp $1 $HOME/tmp/
    cd tmp

    # TODO: unzip

    # rsync --progress /path/to/user/profile/backup/here /home/`whoami`
    # sudo apt-key add ~/Repo.keys
    # sudo cp -R ~/sources.list* /etc/apt/
    # sudo apt-get update
    # sudo apt-get install dselect
    # sudo dpkg --set-selections < ~/Package.list
    # sudo dselect

    # TODO: cleanup
}

$1 $2 $3