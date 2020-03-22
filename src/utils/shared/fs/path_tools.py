#!/usr/bin/python

import os

def pave_path_to(outputfilepath):
    if not os.path.exists(os.path.dirname(outputfilepath)):
        try:
            os.makedirs(os.path.dirname(outputfilepath))
        except:
            if exc.errno != errno.EEXIST:
                raise

def copy_file_from_to(inpath, outpath):
    pave_path_to(outpath)
    with open(inpath, "r") as fromfile:
        textcontent = fromfile.read()
        if (not os.path.isdir(outpath)):
            with open(outpath, "w") as tofile:
                tofile.write(textcontent)
