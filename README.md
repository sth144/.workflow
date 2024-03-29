# Workflow
A set of dotfiles and utilities used to configure desktop environments and automate workflows on Linux machines running i3wm with X window systems.

## To Install Configs
* clone repository
* `cd /path/to/directory/.workflow`
* `$ make stage` to merge local and shared configs into stage directory
    * examine the files in stage/. This set of files will be copied into ~/
        * note: if files exist in ~/ (or subdirectories like ~/.config/...), whose filenames
            match those in stage, and whose paths (relative to ~) match those in stage (relative
            to stage), they will be completely overwritten. No other files will be affected. Be
            sure to examine the files in stage before installing
* `$ make install` to copy configs from stage to home directory

## Structure
* Makefile
* admin/
    * installation scripts called by Makefile
* lib/
    * inactive config files for reference, notes
* src/
    * configs/
        * local/
            * configurations specific to local machine, not tracked by Git.
            * if a file exists in both local/ and shared/, the local file will
                be preferred during staging process
        * shared/
            * configurations which can be used by any Linux machine with required
                dependencies installed.
            * note: some configs are incomplete, and will require a partial config
                with the same filename under local/ to work properly when installed
    * utils/
        * local/
            * utility scripts specific to local machine, not tracked by Git
        * shared/
            * utility scripts which can be used on any Linux machine
    * cronjobs/
    * systemd/
* stage/
    * staging for compiled config files, after build, install script copies from this directory to ~/
* cache/
    * temp files used by utils scripts
* log/
    * logs generated by utils scripts for testing/debugging

## Dependencies
Note: to some extent, these are all optional, as local configs/utils can be used to override shared ones. 
* i3-gaps    (window manager)
    * NOTE: as of 29 Feb, 2020, this line requires using this fork of i3-gaps:
    * https://github.com/resloved/i3.git
* i3-blocks  (utility bar)
* i3lock-color https://github.com/Raymo111/i3lock-color
* Gnome desktop environment (used for utilities)
* compton    (X Window compositor)
* ranger     (terminal file manager)
* termite    (terminal emulator)
* rofi 	     (application launcher, window switcher)
* Python 3.x
* Node.js
* npm
* barrier    (keyboard/mouse share)
* jq
* lm-sensors
* feh
* radeontop
* i3help    (https://github.com/glennular/i3help)

## TODO
### Bash
* make sure .bashrc (and other stuff...) works on multiple distros
* useful global scripts
* useful bash aliases, and a way to deal with different aliases for different machinnes
* ability to swap out scripts for different available dependencies (through configuration)
    * generically named script in utils/shared, like 'screenshot.sh' could be overridden with utils/local/screenshot.sh calling a different underlying utility
* fix issue where workspace_names script takes up an entire CPU core
* daemon utils folder for scripts automatically started in .bashrc or i3 config 
    * refactor, workspace names script would go here
### Conky
* see how much of the contents of local/.config/conky can be moved to shared
### Cron
* implement a way to patch in username at build time
* restart conkies from cronjob
* cronjob to restart NetworkManager when WiFi drops
### i3
* fix bug where multiple workspaces end up with same number
* screensaver and/or autolock
* syntax highlighting in VSCode
### i3Blocks
* i3blocks
    * i3blocks scripts directory
    * i3blocks mail notification
### Scratchpads
* organize scratchpad bindings and brainstorm others
    * Google Drive
    * Google Translate
    * browser research window (F10)
    * teams
* Figure out an integrated notetaking solution
* use mod1 for scratchpads???
* scratchpad commands REGISTRY, rather than hardcoding in i3 config
    * could have a default that can be overridden
    * Trello board URLs should be configured, not hardcoded
* multiple scratchpads in view within workspace
    * investigate i3 marks for scratchpads?
* persist scratchpad sizes when changed?
* F12 for calculator
* easy access to scratchpad cache
* fix bug where window controller doesn't attach to scratchpad window (specifically Trello)
* Joplin notes scratchpad
### Vim
* .vimrc
### systemd
* put node_exporter service definition under source control
* install script for systemd services
### Workflow
* need to carry out a thorough round of cleanup, organization, documentation on entire repo
* get rid of hardcoded references to username
* need to work out a good dev workflow where you can modify src/*/shared and continuously update local versions automatically.
    * new Makefile target
* is there really a need for stage/*? Not necessary to figure that out just yet
* is update_bashrc necessary?
* packaging scheme for dependencies
    * feh
    * xdotool
* figure out a way to make .workflow portable and configurable for Ubuntu, Raspberry Pi, & MacOS
    * probably a config file that allows you to select and ignore directories in .workflow/stage before copying
    * figure out a clean way to target certain files for certain OS
* ~~stop copying cronjobs to home directory~~
* cleanup and decluttering scripts for ~, ~/bin, ~/.config, /etc/cron.d/, /etc/systemd/system/
    * look for systemd and other files to bring under version control
* general src/etc folder to be copied recursively to /etc for configs
