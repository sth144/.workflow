#!/bin/bash

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)
BUILD_CONFIG=$(cat $BASE_ABS/admin/config/settings.json | jq .build)

stage() {
	EXTRA_INCLUDES=$(echo $BUILD_CONFIG | jq .include | jq -r '.[]')
	USE_SHARED=$(echo $BUILD_CONFIG | jq .useShared)

	if [ "$USE_SHARED" == "true" ];
	then
		cp -r $BASE_ABS/src/configs/shared/. $BASE_ABS/stage
	fi
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/configs/$include ];
		then
			cp -r $BASE_ABS/src/configs/$include/. $BASE_ABS/stage
		fi
	done
	cp -r $BASE_ABS/src/configs/local/. $BASE_ABS/stage
	
	echo "staging utils (with preference for local utils)"

	if [ "$USE_SHARED" == "true" ];
	then
		cp -r $BASE_ABS/src/utils/shared/. $BASE_ABS/stage/bin
	fi
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/utils/$include ];
		then
			cp -r $BASE_ABS/src/utils/$include/. $BASE_ABS/stage/bin
		fi
	done
	cp -r $BASE_ABS/src/utils/local/. $BASE_ABS/stage/bin
	
	echo "staging cron jobs (with preference for local)"
	if [ "$USE_SHARED" == "true" ];
	then
		cp -r $BASE_ABS/src/cronjobs/shared/. $BASE_ABS/stage/cronjobs
	fi
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/cronjobs/$include ];
		then
			cp -r $BASE_ABS/src/cronjobs/$include/. $BASE_ABS/stage/cronjobs
		fi
	done
	cp -r $BASE_ABS/src/cronjobs/local/. $BASE_ABS/stage/cronjobs
	
	echo "staging systemd services (with preference for local)"
	if [ "$USE_SHARED" == "true" ];
	then
		cp -r $BASE_ABS/src/systemd/shared/. $BASE_ABS/stage/systemd
	fi
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/systemd/$include ];
		then
			cp -r $BASE_ABS/src/systemd/$include/. $BASE_ABS/stage/systemd
		fi
	done
	cp -r $BASE_ABS/src/systemd/local/. $BASE_ABS/stage/systemd

	# preprocess staged output
	# change <USER> tag to $USER wherever it appears in files
	find stage -type f -exec sed -i -e "s@<USER>@$USER@g" {} \;
}

update_home() {
	echo "WARNING: If the following files exist, they will be overwritten"
	find "$BASE_ABS/stage" -type f | sed 's/.*stage/\~/g' \
		| grep -v ".keep" \
		| grep -v "cronjobs/" \
		| grep -v "systemd/" \
		| grep -v "README.md"

	read -p "Proceed? (y/n) " RESPONSE

	if [ $RESPONSE = "y" ]; 
	then
		# NOTE: make sure you copy staged cronjobs and systemd services before running
		#		this function!
		rm -rf $BASE_ABS/stage/cronjobs
		rm -rf $BASE_ABS/stage/systemd
		rm -rf $BASE_ABS/stage/README.md
		rm -rf $BASE_ABS/stage/.keep
		
		# copy config build and utils to ~
		sudo cp -rT $BASE_ABS/stage/ ~/
		sudo cp -rT $BASE_ABS/stage/bin/ /usr/local/bin/

        rm ~/.keep
		rm ~/README.md
	fi

	mkdir -p ~/.cache/.workflow
}

update_cronjobs() {
	sudo cp -r $BASE_ABS/stage/cronjobs/* /etc/cron.d/
}

update_systemd_services() {
	sudo cp -r $BASE_ABS/stage/systemd/* /etc/systemd/system/

	# TODO: enable and start services
	SERVICES=$(ls -lA $BASE_ABS/stage/systemd | awk '{print $9}' | grep -v ".keep")

	for service in $SERVICES;
	do
		sudo systemctl enable $service
		sudo systemctl start $service
	done

	sudo systemctl daemon-reload
}

refresh() {
	if [ -d $BASE_ABS/stage/.config/i3 ];
	then
	    i3-msg restart
	fi
}

$1 "${@:2}"
