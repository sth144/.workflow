all: clean build install update_bashrc refresh

# build configs (merge local and shared into build directory)
.PHONY: build
build: 
	@echo "building configs"
	./_admin/build_configs.py build

# copy config build to ~/.config dot directory
# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths 
install: 
	@echo "installing config build"
	./_admin/install_configs.sh install

# some commands (like "export WORKFLOW_BASE=...") cannot be hardcoded into conf/shared/.bashrc
# this makefile target will append them to ~/.bashrc
update_bashrc:
	@echo "appending ~/.bashrc"
	./_admin/update_bashrc.sh

# restart i3
refresh:
	@echo "refreshing i3wm"
	./_admin/install_configs.sh refresh &

# clear config build directory
clean:
	@echo "cleaning config build output directory"
	./_admin/build_configs.py clean
