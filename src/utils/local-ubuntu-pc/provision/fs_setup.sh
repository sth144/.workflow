#!/bin/bash

sudo cp /mnt/T/root/.smbcredentials /root/
sudo cp /mnt/T/root/.smbcredentials.pi /root/
sudo cp /mnt/T/root/.smbcredentials.picocluster /root/

# symlink mounted drives
sudo ln -s /mnt/D $HOME/Drive/D
sudo ln -s /mnt/S $HOME/Drive/S
sudo ln -s /mnt/T $HOME/Drive/T
sudo ln -s /mnt/Th $HOME/Drive/Th
sudo ln -s /mnt/U $HOME/Drive/U
sudo ln -s /mnt/Uh $HOME/Drive/Uh

# TODO: set up network mounts
sudo ln -s /media/NAS $HOME/Drive/O
sudo ln -s /media/pc0 $HOME/Drive/K
sudo ln -s /media/pi $HOME/Drive/Pi

# TODO: set up cloud mounts (GDrive)

# generate symlinks in home directory
rmdir Music
sudo ln -s /mnt/D/Audio $HOME/Audio 
sudo ln -s /usr/local/bin $HOME/bin 
sudo mkdir -p /usr/local/src
sudo ln -s /usr/local/src $HOME/src
sudo ln -s /mnt/D/Coding $HOME/Coding
rmdir Documents
sudo ln -s /mnt/D/Documents $HOME/Documents
rm -rf $HOME/Downloads
sudo ln -s /mnt/D/Downloads $HOME/Downloads
rmdir Inbox
sudo ln -s /mnt/D/Inbox $HOME/Inbox
rmdir Pictures
sudo ln -s /mnt/D/Images $HOME/Pictures
sudo ln -s /mnt/D/Coding/Projects $HOME/Projects
rmdir $HOME/Templates
sudo ln -s /mnt/D/Templates $HOME/Templates
mkdir -p /mnt/D/Volumes/System/Ubuntu-PC3/home/sthinds/tmp
sudo ln -s /mnt/D/Volumes/System/Ubuntu-PC3/home/sthinds/tmp $HOME/tmp
sudo ln -s /mnt/D/Video $HOME/Video