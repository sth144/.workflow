#!/bin/bash

DELETE_PATTERNS=(
	.cargo
	.dbus
	.gdfuse
	.node-spawn-*
	.xsession-errors*
	.octave_hist
	.keras
	.node_repl_history
	.mozilla
	.wget-hsts
	.thunderbird
	tmp/*
)

for i in ${!DELETE_PATTERNS[@]}; do
	echo "Deleting ${DELETE_PATTERNS[$i]}"
	sudo rm -rf ~/${DELETE_PATTERNS[$i]}
done