#!/bin/bash

make_backup() {
    BACKUP_TMP_DIR="$HOME/tmp/$(whoami)@$(hostname).apt.$(date +%Y-%m-%d)"
    mkdir -p $BACKUP_TMP_DIR
    dpkg --get-selections > "$BACKUP_TMP_DIR/Package.list"
    sudo cp -R /etc/apt/sources.list* "$BACKUP_TMP_DIR"
    sudo apt-key exportall > "$BACKUP_TMP_DIR/Repo.keys"
    mkdir -p $BACKUP_TMP_DIR/profile
    rsync --progress /home/`whoami` $BACKUP_TMP_DIR/profile
    
    zip -r "$BACKUP_TMP_DIR.zip" $BACKUP_TMP_DIR
    # move zip to backup location
    mkdir -p $HOME/Drive/D/Archives/Backups/$(whoami)@$(hostname)
    mv "$BACKUP_TMP_DIR.zip" $HOME/Drive/D/Archives/Backups/$(whoami)@$(hostname)/
    sudo rm -rf $BACKUP_TMP_DIR
}

revert_to_backup() {
    ARCHIVE_ZIP_NAME=$1

    echo "Revert $ARCHIVE_ZIP_NAME"

    cp $ARCHIVE_ZIP_NAME $HOME/tmp/
    cd $HOME/tmp

    unzip $ARCHIVE_ZIP_NAME -d ./archive

    sudo apt-key add ./archive/Repo.keys
    sudo cp -R ./archive/sources.list* /etc/apt/
    sudo apt-get update
    sudo apt-get install dselect
    sudo dpkg --set-selections < ./archive/Package.list
    sudo dselect

    # TODO: cleanup
    rm -rf archive
    rm -rf $ARCHIVE_ZIP_NAME
}

$1 $2 $3