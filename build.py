#!/usr/bin/python

import os

def link_config(filepath):
	shared=""
	local=""
	output=""
	sharedfilename="./shared/configs/" + filepath
	localfilename="./local/configs/" + filepath
	outputfilename="./build/configs/" + filepath
	with open(sharedfilename, "r") as sharedfile:
		shared=sharedfile.read()
	with open(localfilename, "r") as localfile:
		local=localfile.read()
	output=shared+"\n\n"+local

	if not os.path.exists(os.path.dirname(outputfilename)):
		try:
			os.makedirs(os.path.dirname(outputfilename))
		except OSError as exc:	# Guard against race condition
			if exc.errno != errno.EEXIST:
				raise
	with open(outputfilename, "w") as outputfile:
		outputfile.write(output)

link_config("i3/config")
