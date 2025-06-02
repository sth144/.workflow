#!/bin/bash

sudo apt update
sudo apt install -y wget curl xz-utils -y

wget https://github.com/laurent22/joplin/releases/download/v3.3.12/Joplin-3.3.12.AppImage
chmod +x Joplin-3.3.12.AppImage
mkdir -p ~/bin/Joplin
mv Joplin-3.3.12.AppImage ~/bin/Joplin/Joplin.AppImage

mkdir -p ~/.local/share/applications
echo "[Desktop Entry]
Name=Joplin
Comment=Open-source note-taking and to-do application
Exec=~/bin/Joplin/Joplin.AppImage
Icon=~/bin/Joplin/Joplin.AppImage
Terminal=false
Type=Application
Categories=Utility;" > ~/.local/share/applications/joplin.desktop
