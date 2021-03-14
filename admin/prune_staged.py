#!/usr/bin/python3

import os, sys, shutil, glob

basedir = sys.path[0] + "/.."
exclude_conf_path = basedir + "/admin/config/exclude.conf"

if (os.path.exists(exclude_conf_path)):
    with open(exclude_conf_path) as exclude_file:
        text = exclude_file.readlines()
        for text_line in text:
            text_line = text_line.replace("\n", "")
            for staged_filepath in glob.glob("./stage/"+text_line, recursive=True):
                # remove staged file glob
                print("removing excluded pattern %s from staged build" % text_line)
                if os.path.isfile(staged_filepath):
                    os.remove(staged_filepath)
                elif os.path.isdir(staged_filepath):
                    shutil.rmtree(staged_filepath)