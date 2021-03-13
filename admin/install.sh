#!/bin/bash

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)

stage() {
	EXTRA_INCLUDES=$(cat $BASE_ABS/admin/config/settings.json | jq .build.include | jq -r '.[]')

	# echo "staging configs (with preference for local)"
	cp -r $BASE_ABS/src/configs/shared/. $BASE_ABS/stage
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/configs/$include ];
		then
			cp -r $BASE_ABS/src/configs/$include/. $BASE_ABS/stage
		fi
	done
	cp -r $BASE_ABS/src/configs/local/. $BASE_ABS/stage
	
	echo "staging utils (with preference for local utils)"
	cp -r $BASE_ABS/src/utils/shared/. $BASE_ABS/stage/bin
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/utils/$include ];
		then
			cp -r $BASE_ABS/src/utils/$include/. $BASE_ABS/stage
		fi
	done
	cp -r $BASE_ABS/src/utils/local/. $BASE_ABS/stage/bin
	
	# echo "staging cron jobs (with preference for local)"
	cp -r $BASE_ABS/src/cronjobs/shared/. $BASE_ABS/stage/cronjobs
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/cronjobs/$include ];
		then
			cp -r $BASE_ABS/src/cronjobs/$include/. $BASE_ABS/stage/cronjobs
		fi
	done
	cp -r $BASE_ABS/src/cronjobs/local/. $BASE_ABS/stage/cronjobs
	
	# echo "staging systemd services (with preference for local)"
	cp -r $BASE_ABS/src/systemd/shared/. $BASE_ABS/stage/systemd
	for include in $EXTRA_INCLUDES;
	do
		if [ -d $BASE_ABS/src/systemd/$include ];
		then
			cp -r $BASE_ABS/src/systemd/$include/. $BASE_ABS/stage/systemd
		fi
	done
	cp -r $BASE_ABS/src/systemd/local/. $BASE_ABS/stage/systemd
}

update_home() {
	echo "WARNING: If the following files exist, they will be overwritten"
	find "$BASE_ABS/stage" -type f | sed 's/.*stage/\~/g' | grep -v ".keep"
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

	sudo systemctl daemon-reload
}

refresh() {
	if [ -d $BASE_ABS/stage/.config/i3 ];
	then
	    i3-msg restart
	fi
}

$1 "${@:2}"
