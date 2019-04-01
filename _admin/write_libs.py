#!/usr/bin/python

import sys, os, json

from utils.shared.fs import path_tools 

basedir = sys.path[0] + "/.."
admindir = basedir + "/admin"

settings_path = admindir + "/localsettings.json"
settings_exists = os.path.isfile(settings_path)

configs_local_path = basedir + "/configs/local/"
util_local_path = basedir + "/utils/local/"

lib_path = basedir + "/_lib/"

if settings_exists:
    settings = json.loads(open(settings_path).read())
    lib_dir = settings["libdir"]
    for _file in settings["libtracklocalconfigs"]:
        inpath = configs_local_path + _file
        outpath = lib_path + lib_dir + "/configs/" + _file
        path_tools.copy_file_from_to(inpath, outpath)
    for _file in settings["libtracklocalutil"]:
        inpath = util_local_path + _file
        outpath = lib_path + lib_dir + "/utils/" + _file
        path_tools.copy_file_from_to(inpath, outpath)
else:
    generate = input("Local settings file does not exist, copy localsettings.tmpl.json to localsettings.json")
