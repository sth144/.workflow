all: build install

# build configs (merge local and shared into build directory)
.PHONY: build
build: clean 
	@echo "building configs"
	./_admin/build_configs.py build

install: enable_utils copy update_bashrc refresh
	@echo "installing config build"

# copy config build to ~/.config dot directory
# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths 
copy:
	@echo "copying dotfiles to home directory"
	./_admin/install_configs.sh install

# enable utils
enable_utils:
	@echo "enabling utils"
	find ./utils -type f -iname "*.sh" -exec chmod +x {} \;
	find ./utils -type f -iname "*.py" -exec chmod +x {} \;


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
