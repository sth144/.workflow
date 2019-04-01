#!/usr/bin/python

import sys, os, shutil, glob, stat, errno
from utils.shared.fs import path_tools, privelege_tools

basedir=sys.path[0]+"/.."
confdir=basedir+"/configs"

def copy_config_from(fromdir, inputfilename):
    inputfilepath=confdir+"/"+fromdir+"/"+inputfilename
    outputfilepath=basedir+"/.build/"+inputfilename
    path_tools.copy_file_from_to(inputfilepath, outputfilepath)
    privelege_tools.make_executable(outputfilepath)

def merge_copy_config(inputfilename):
    sharedfilepath=confdir+"/shared/"+inputfilename
    localfilepath=confdir+"/local/"+inputfilename
    mergefilepath=basedir+"/.build/"+inputfilename
    sharedcontent=""
    localcontent=""
    with open(sharedfilepath, "r") as sharedfile:
        sharedcontent=sharedfile.read()
    with open(localfilepath, "r") as localfile:
        localcontent=localfile.read()
    mergedcontent=sharedcontent+"\n\n"+localcontent
    path_tools.pave_path_to(mergefilepath)
    with open(mergefilepath, "w") as mergefile:
        mergefile.write(mergedcontent)
    privelege_tools.make_executable(mergefilepath)

def build():
    all_shared_files=[]
    all_local_files=[]
    for root, dirs, files in os.walk(confdir + "/shared", topdown=False):
        for name in files:
            all_shared_files.append(os.path.join(root, name).split(confdir+"/shared/")[1])
    for root, dirs, files in os.walk(confdir + "/local", topdown=False):
        for name in files:
            all_local_files.append(os.path.join(root, name).split(confdir+"/local/")[1])

    shared_files_to_copy=[]
    shared_files_to_merge_copy=[]
    local_files_to_copy=[]

    for file in all_shared_files:
        if file in all_local_files:
            shared_files_to_merge_copy.append(file)
        else:
            shared_files_to_copy.append(file)
    for file in all_local_files:
        if file not in all_shared_files:
            local_files_to_copy.append(file)

    shared_files_to_copy = [
        x for x in shared_files_to_copy if (x.find("README.md") == -1)
    ]
    shared_files_to_merge_copy = [
        x for x in shared_files_to_merge_copy if (x.find("README.md") == -1)
    ]
    local_files_to_copy = [
        x for x in local_files_to_copy if (x.find("README.md") == -1)
    ]
    
    print("building:")
    for file in shared_files_to_copy:
        print("shared/" + file)
    for file in shared_files_to_merge_copy:
        print("(merge) shared/" + file)
    for file in local_files_to_copy:
        print("local/" + file)

    for file in shared_files_to_copy:
        copy_config_from("shared", file)
    for file in shared_files_to_merge_copy:
        merge_copy_config(file)
    for file in local_files_to_copy:
        copy_config_from("local", file)

def clean():
    files = glob.glob(os.path.join(basedir+"/.build/*"))
    files += glob.glob(os.path.join(basedir+"/.build/.*"))
    files = [x for x in files if (x.find(".keep") == -1)]
    for f in files:
        if os.path.isdir(f):
            shutil.rmtree(f)
        else:
            os.remove(f)

if __name__ == "__main__":
    success=False
    if (len(sys.argv) >= 2):
        if (sys.argv[1] == "clean"):
            clean()
            success=True
        elif (sys.argv[1] == "build"):
            build()
            success=True
    if not success:
        print("must supply a command, options:\n\tclean\n\tbuild")
