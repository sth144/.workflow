#!/bin/bash

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)
BUILD_CONFIG=$(cat $BASE_ABS/admin/config/settings.json | jq .build)
OS=$(uname)
CP=cp
if [ "$OS" = "Darwin" ]; then
	CP=gcp
fi

reset_stage() {
	rm -rf "$BASE_ABS/stage"
	mkdir -p "$BASE_ABS/stage"
}

copy_layer_contents() {
	local src="$1"
	local dest="$2"

	[ -d "$src" ] || return 0
	mkdir -p "$dest"
	$CP -r "$src"/. "$dest"/
}

copy_layer_dir() {
	local src="$1"
	local dest="$2"

	[ -d "$src" ] || return 0
	mkdir -p "$dest"
	$CP -r "$src" "$dest"/
}

copy_utils_layer() {
	mkdir -p "$BASE_ABS/stage/bin"
	rsync -a \
		--exclude='.venv/' \
		--exclude='__pycache__/' \
		--exclude='*.pyc' \
		"$1"/ "$BASE_ABS/stage/bin"/
}

echo "BASE_ABS ${BASE_ABS}"

stage() {
	reset_stage

	echo "emptied stage/"
	ls -lA $BASE_ABS/stage/

	EXTRA_INCLUDES=$(echo $BUILD_CONFIG | jq .include | jq -r '.[]')
	USE_SHARED=$(echo $BUILD_CONFIG | jq .useShared)

	if [ "$USE_SHARED" == "true" ]; then
		copy_layer_contents "$BASE_ABS/src/configs/shared" "$BASE_ABS/stage"
	fi

	echo "copied dotfiles"
	ls -lA $BASE_ABS/stage/

	for include in $EXTRA_INCLUDES; do
		if [ -d $BASE_ABS/src/configs/$include ]; then
			copy_layer_contents "$BASE_ABS/src/configs/$include" "$BASE_ABS/stage"
		fi
	done
	copy_layer_contents "$BASE_ABS/src/configs/local" "$BASE_ABS/stage"

	echo "staging utils (with preference for local utils)"

	if [ "$USE_SHARED" == "true" ]; then
		copy_utils_layer "$BASE_ABS/src/utils/shared"
	fi
	for include in $EXTRA_INCLUDES; do
		if [ -d $BASE_ABS/src/utils/$include ]; then
			echo "Include $BASE_ABS/src/utils/$include"
			copy_utils_layer "$BASE_ABS/src/utils/$include"
		fi
	done
	copy_utils_layer "$BASE_ABS/src/utils/local"

	echo "staging cron jobs (with preference for local)"
	mkdir -p $BASE_ABS/stage/cronjobs
	if [ "$USE_SHARED" == "true" ]; then
		copy_layer_contents "$BASE_ABS/src/cronjobs/shared" "$BASE_ABS/stage/cronjobs"
	fi
	for include in $EXTRA_INCLUDES; do
		if [ -d $BASE_ABS/src/cronjobs/$include ]; then
			copy_layer_contents "$BASE_ABS/src/cronjobs/$include" "$BASE_ABS/stage/cronjobs"
		fi
	done
	copy_layer_contents "$BASE_ABS/src/cronjobs/local" "$BASE_ABS/stage/cronjobs"

	echo "staging systemd services (with preference for local)"

	if [ "$USE_SHARED" == "true" ]; then
		copy_layer_contents "$BASE_ABS/src/systemd/shared" "$BASE_ABS/stage/systemd"
	fi
	for include in $EXTRA_INCLUDES; do
		if [ -d $BASE_ABS/src/systemd/$include ]; then
			copy_layer_contents "$BASE_ABS/src/systemd/$include" "$BASE_ABS/stage/systemd"
		fi
	done
	copy_layer_contents "$BASE_ABS/src/systemd/local" "$BASE_ABS/stage/systemd"

	echo "staging docker-compose.yml files for starting docker services"
	if [ "$USE_SHARED" == "true" ]; then
		copy_layer_dir "$BASE_ABS/src/docker/shared" "$BASE_ABS/stage/docker"
	fi
	for include in $EXTRA_INCLUDES; do
		if [ -d $BASE_ABS/src/docker/$include ]; then
			copy_layer_dir "$BASE_ABS/src/docker/$include" "$BASE_ABS/stage/docker"
		fi
	done
	copy_layer_dir "$BASE_ABS/src/docker/local" "$BASE_ABS/stage/docker"

	echo "staging root"
	mkdir -p $BASE_ABS/stage/root
	if [ "$USE_SHARED" == "true" ]; then
		copy_layer_contents "$BASE_ABS/src/root/shared" "$BASE_ABS/stage/root"
	fi
	for include in $EXTRA_INCLUDES; do
		if [ -d $BASE_ABS/src/root/$include ]; then
			copy_layer_contents "$BASE_ABS/src/root/$include" "$BASE_ABS/stage/root"
		fi
	done
	copy_layer_contents "$BASE_ABS/src/root/local" "$BASE_ABS/stage/root"

	# preprocess staged output
	# change <USER> tag to $USER wherever it appears in files

	if [[ $(uname) == "Darwin" ]]; then
		find "$BASE_ABS/stage" -type f -exec sed -i 's|/home/<USER>|/Users/<USER>|g' {} +
	fi

	find "$BASE_ABS/stage" -type f -exec sed -i -e "s@<USER>@$USER@g" {} +

	find "$BASE_ABS/stage" -type f -name '*-e' -exec rm -f {} +
}

update_home() {
	echo "WARNING: If the following files exist, they will be overwritten"

	find ./stage -type f -name '*-e' -delete

	find "$BASE_ABS/stage" -type f | sed 's/.*stage/\~/g' |
		grep -v ".keep" |
		grep -v "cronjobs/" |
		grep -v "systemd/" |
		grep -v "README.md"

	read -p "Proceed? (y/n) " RESPONSE

	if [ $RESPONSE = "y" ]; then
		# NOTE: make sure you copy staged cronjobs and systemd services before running
		#		this function!
		rm -rf $BASE_ABS/stage/README.md
		rm -rf $BASE_ABS/stage/.keep

		# unlock immutable files before overwriting
		chflags nouchg ~/.claude/settings.json 2>/dev/null

		# copy config build and utils to ~
		sudo $CP -rT $BASE_ABS/stage/docker/ ~/.config/docker
		rm -rf $BASE_ABS/stage/docker
		sudo $CP -r $BASE_ABS/stage/ ~/ && sudo chown -R $(whoami) $BASE_ABS/stage
		sudo $CP -r $BASE_ABS/stage/.[^.]* ~/
		sudo $CP $BASE_ABS/stage/.bashrc ~/
		sudo $CP -rT $BASE_ABS/stage/.config ~/.config
		sudo $CP -rT $BASE_ABS/stage/bin/ /usr/local/bin/

		# lock settings.json to prevent Open Island.app from overwriting it
		chflags uchg ~/.claude/settings.json

		rm ~/.keep
		rm ~/README.md
		sudo rm -rf ~/stage
		sudo rm -rf ~/cronjobs
		sudo rm -rf ~/systemd
		echo "Creating workflow cache and log directories"
		mkdir -p ~/.cache/.workflow
		mkdir -p ~/.claude/routines/logs
		echo "Enabling executables"
		find ~/bin/ -type f -exec chmod u+x {} \;
		sudo find /usr/local/bin/ -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
	fi
}

update_root() {
	if [[ $(uname) == "Darwin" ]]; then
		sudo rsync -avh ./stage/root/etc/ /private/etc/
	fi
	sudo rsync -avh ./stage/root/ /
	echo ""
}

update_cronjobs() {
	sudo $CP -r $BASE_ABS/stage/cronjobs/* /etc/cron.d/
	if [[ $(uname) == "Darwin" ]]; then
		TMP_CRON="/tmp/workflow_crontab.tmp"
		COMBINED="/etc/cron.d/workflow_crontab"
		# Combine, strip comments/blanks, and remove the "user" field (6th field)

		ALL_CRON=$(find /etc/cron.d -type f ! -name 'workflow_crontab' -exec cat {} + | grep -vE '^($|#)')
		# Variable assignments (PATH=, SHELL=, etc.) go first
		echo "$ALL_CRON" | grep -E '^[A-Z_]+=' | sort -u > "$TMP_CRON"
		# Then cron entries with the user field stripped
		echo "$ALL_CRON" | grep -vE '^[A-Z_]+=' |
			awk 'NF >= 6 { cmd=""; for(i=7;i<=NF;i++) cmd=cmd (i>7?" ":"") $i; print $1,$2,$3,$4,$5,cmd }' |
			sort -u >> "$TMP_CRON"

		# Optional: Save the combined version
		sudo cp "$TMP_CRON" "$COMBINED"
		# Load into current user's crontab
		crontab "$TMP_CRON"
		# Clean up
		rm "$TMP_CRON"
		echo "Crontab updated from /etc/cron.d/*"
	fi
}

update_launchagents() {
	if [[ $(uname) != "Darwin" ]]; then
		echo "Skipping LaunchAgents (not macOS)"
		return
	fi

	AGENTS_DIR="$HOME/Library/LaunchAgents"
	mkdir -p "$AGENTS_DIR"

	for plist in "$BASE_ABS/stage/Library/LaunchAgents/com.workflow."*; do
		[ -f "$plist" ] || continue
		label=$(basename "$plist" .plist)
		# Unload if already loaded (ignore errors for agents not yet registered)
		launchctl bootout "gui/$(id -u)/$label" 2>/dev/null || true
		cp "$plist" "$AGENTS_DIR/"
		launchctl bootstrap "gui/$(id -u)" "$AGENTS_DIR/$(basename "$plist")"
		echo "  loaded: $label"
	done

	echo "LaunchAgents updated"
}

update_systemd_services() {
	if [ -d /etc/systemd ]; then

		sudo $CP -r $BASE_ABS/stage/systemd/* /etc/systemd/system/

		SERVICES=$(ls -lA $BASE_ABS/stage/systemd | awk '{print $9}' | grep -v ".keep")

		for service in $SERVICES; do
			sudo systemctl enable $service
			sudo systemctl start $service
		done

		sudo systemctl daemon-reload
	fi
}

# start_docker_services() {
# 	# TODO: start docker services and call this function

#}

refresh() {

	if [ -d $BASE_ABS/stage/.config/i3/config ]; then
		i3-msg restart
	fi
}

$1 "${@:2}"
