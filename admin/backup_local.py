#!/usr/bin/python3

import os, sys
import zipfile

from datetime import date
today = date.today()

basedir=sys.path[0]+"/.."
confdir=basedir+"/src/configs/local/"
utildir=basedir+"/src/utils/local/"
backupdir=basedir+"/backup/"

def zipdir(path, ziphandle):
    # ziph is zipfile handle
    for root, dirs, files in os.walk(path):
        len_path=len(path)
        for file in files:
            file_path = os.path.join(root, file)
            print(file_path)
            ziphandle.write(file_path, file_path.split("/src/")[1])

if __name__ == '__main__':
    zipf = zipfile.ZipFile(backupdir+str(today)+".backup.zip", 'w', zipfile.ZIP_DEFLATED)
    zipdir(utildir, zipf)
    zipdir(confdir, zipf)
    zipf.close()