#!/bin/bash

backup_dir="/home/<USER>/Drive/D/Archives/Backups/Images"
backup_prefix="backup"
current_date=$(date "+%Y%m%d")
month=$(date "+%b")

# Create backup for each Raspberry Pi
echo "Backup HA Raspberry Pi"
ssh pi@192.168.1.243 "sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -1 -" > $backup_dir/rpi.home-assistant.$backup_prefix-$current_date.img.gz
rsync -av pi@192.168.1.243:/home/pi/ /home/<USER>/Drive/D/Archives/Backups/pi@raspberrypi/home/pi/

echo "Backup pc0"
ssh picocluster@192.168.1.240 "sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -1 -" > $backup_dir/rpi.pc0.$backup_prefix-$current_date.img.gz
rsync -av picocluster@pc0:/home/picocluster/ /home/<USER>/Drive/D/Archives/Backups/picocluster@pc0/home/picocluster/

echo "Backup pc1"
ssh picocluster@192.168.1.241 "sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -1 -" > $backup_dir/rpi.pc1.$backup_prefix-$current_date.img.gz
rsync -av picocluster@pc1:/home/picocluster/ /home/<USER>/Drive/D/Archives/Backups/picocluster@pc1/home/picocluster/

echo "Backup pc2"
ssh picocluster@192.168.1.242 "sudo dd if=/dev/mmcblk0 bs=4M status=progress | gzip -1 -" > $backup_dir/rpi.pc2.$backup_prefix-$current_date.img.gz
rsync -av picocluster@pc2:/home/picocluster/ /home/<USER>/Drive/D/Archives/Backups/picocluster@pc2/home/picocluster/
ls $backup_dir

# Rotate backups to keep last five months
cd $backup_dir
ls -tp | grep "rpi.home-assistant.$backup_prefix" | tail -n +6 | xargs -I {} rm -- {}
ls -tp | grep "rpi.pc0.$backup_prefix" | tail -n +6 | xargs -I {} rm -- {}
ls -tp | grep "rpi.pc1.$backup_prefix" | tail -n +6 | xargs -I {} rm -- {}
ls -tp | grep "rpi.pc2.$backup_prefix" | tail -n +6 | xargs -I {} rm -- {}
