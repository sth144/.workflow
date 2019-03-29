all: clean build install refresh

# build configs (merge local and shared into build directory)
.PHONY: build
build: 
	@echo "building configs"
	./build_configs.py build

# copy config build to ~/.config dot directory
# add .workflow base directory to path in ~/.bashrc
# this allows scripts in other locations, as well as within .workflow, to call
# workflow scripts without using relative paths 
install: 
	@echo "installing config build"
	./install_configs.sh install

# restart i3
refresh:
	@echo "refreshing i3wm"
	./install_configs.sh refresh &

# clear config build directory
clean:
	@echo "cleaning config build output directory"
	./build_configs.py clean