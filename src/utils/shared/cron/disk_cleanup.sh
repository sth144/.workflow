#!/bin/bash

docker system prune -af

# Clean up unused Anaconda packages
conda clean -y --all

 # Clean up unnecessary packages from python3.10
pip3 cache purge

# Clean up pip cache
pip cache purge

pip uninstall -y -r <(pip freeze)
pip3 uninstall -y -r <(pip3 freeze)

# Clear snap cache
sh -c 'rm -rf /var/lib/snapd/cache/*'

# Clean up unused packages/libraries in /usr/lib/x86_64-linux-gnu and /usr/lib/python3
apt autoremove --purge -y

# Clear apt cache
apt clean -y

rm -rf /home/<USER>/tmp/*
rm -rf /home/<USER>/Downloads/*

rm -rf /var/log/journal/**/*
