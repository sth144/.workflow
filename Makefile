all: stage install

# stage configs and utils, giving preference to files in local if they exist in both local and shared
.PHONY: stage
stage: clean
	@echo "staging configs (with preference for local"
	cp -r ./src/configs/shared/. ./stage
	cp -r ./src/configs/local/. ./stage
	@echo "staging utils (with preference for local utils)"
	cp -r ./src/utils/shared/. ./stage/.util
	cp -r ./src/utils/local/. ./stage/.util
	@echo "staging cron jobs (with preference for local)"
	cp -r ./src/cronjobs/shared/. ./stage/cronjobs
	cp -r ./src/cronjobs/local/. ./stage/cronjobs

.PHONY: install
install: copy_staged_to_home enable_utils update_bashrc update_cronjobs refresh
	@echo "installing configs and utils"

# copy config build to ~/.config dot directory
# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths
# copy utils to ~/.util directory
copy_staged_to_home:
	@echo "copying dotfiles and utils to home directory"
	./admin/install.sh install

update_cronjobs:
	@echo "installing cronjobs in /etc/cron.d/"
	./admin/install.sh update_cronjobs

# enable utils
enable_utils:
	@echo "enabling utils in ~/.util"
	find ~/.util -type f -iname "*.sh" -exec chmod +x {} \;
	find ~/.util -type f -iname "*.py" -exec chmod +x {} \;

# some commands (like "export WORKFLOW_BASE=...") cannot be hardcoded into conf/shared/.bashrc
# this makefile target will append them to ~/.bashrc
update_bashrc:
	@echo "appending ~/.bashrc"
	@echo "$HOME"
	./admin/update_bashrc.sh

# restart i3
refresh:
	@echo "refreshing i3wm"
	./admin/install.sh refresh &

# clear config build directory
clean:
	@echo "cleaning config build output directory"
	rm -rf ./stage/**/*
	rm -rf ./stage/.util
	rm -rf ./stage/.config

.PHONY: backup
backup:
	@echo "backing up local configs and utils"
	./admin/backup_local.py