#!/bin/bash

# make sure every config file in admin/config/templates (under version control) has been copied to
#   admin/config

for filepath in ./admin/config/template/*;
do
    filename="${filepath##*/}"

    QUERY_RESULT=$(find ./admin/config/ -maxdepth 1 -not -type d 2>/dev/null | grep -v ".gitkeep" | grep $filename)

    if [ -z "$QUERY_RESULT" ];
    then
        cp $filepath ./admin/config/$filename
    fi
done
