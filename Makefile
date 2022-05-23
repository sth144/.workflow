all: commission stage prune install

.PHONY: commission
commission:
	@echo commisioning system
	./admin/commission.sh

.PHONY: prune
prune:
	@echo "pruning ignored file path patterns from staged build output"
	./admin/prune_staged.py

# stage configs and utils, giving preference to files in local if they exist in both local and shared
.PHONY: stage
stage: clean
	@echo "staging"
	./admin/install.sh stage

.PHONY: install
install: update_cronjobs update_systemd_services copy_staged_to_home enable_utils update_bashrc refresh
	@echo "installing configs and utils"

# copy config build to ~/.config dot directory
# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths
# copy utils to ~/bin directory (symlink to /usr/local/bin)
copy_staged_to_home:
	@echo "copying dotfiles and utils to home directory"
	./admin/install.sh update_home

update_cronjobs:
	@echo "installing cronjobs in /etc/cron.d/"
	./admin/install.sh update_cronjobs

update_systemd_services:
	@echo "installing systemd services in /etc/systemd/system/"
	./admin/install.sh update_systemd_services

# enable utils
enable_utils:
	@echo "enabling utils in ~/bin"
	find ~/bin -type f -iname "*.sh" -exec chmod +x {} \;
	find ~/bin -type f -iname "*.py" -exec chmod +x {} \;

# some commands (like "export WORKFLOW_BASE=...") cannot be hardcoded into conf/shared/.bashrc
# this makefile target will append them to ~/.bashrc
update_bashrc:
	@echo "appending ~/.bashrc"
	./admin/update_bashrc.sh

# restart i3
refresh:
	@echo "refreshing (ie. refresh i3wm)"
	./admin/install.sh refresh &

# clear config build directory
clean:
	@echo "cleaning config build output directory"
	rm -rf ./stage/**/*
	rm -rf ./stage/bin
	rm -rf ./stage/.config

.PHONY: backup
backup:
	@echo "backing up local configs and utils"
	./admin/backup_local.py