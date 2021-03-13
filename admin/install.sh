#!/bin/bash

# get the base directory
BASE_ABS=$(cd "$(dirname $0)/.." && pwd)

update_home() {
	echo "WARNING: If the following files exist, they will be overwritten"
	find "$BASE_ABS/stage" -type f | sed 's/.*stage/\~/g' | grep -v ".keep"
	read -p "Proceed? (y/n) " RESPONSE

	if [ $RESPONSE = "y" ]; 
	then
		# TODO: move these to prune?
		rm -rf $BASE_ABS/stage/cronjobs
		rm -rf $BASE_ABS/stage/README.md
		rm -rf $BASE_ABS/stage/.keep

		# TODO: ability to exclude patterns
		# TODO: take into account patterns from admin/config/include.conf
		# TODO: probably move this to Python?
		# TODO: take ignores into account for bin?
		
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
