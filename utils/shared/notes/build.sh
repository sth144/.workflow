#!/bin/bash

#
# note: npm package markdown-pdf must be globally installed
#		$ npm install -g markdown-pdf
#

# executable parameters
NOTES_DIR=$1    # directory containing markdown notes

MD_DIR="$NOTES_DIR/MD"
PDF_DIR="$NOTES_DIR/PDF"
THIS_DIR=$(dirname $0)

echo $MD_DIR
echo $PDF_DIR

MD_FILES=($(find "$MD_DIR" -type f | sed "s@$MD_DIR\/@@g"))
for FILENAME in "${MD_FILES[@]}"; do
    echo "$MD_DIR/$FILENAME"
    markdown-pdf "$MD_DIR/$FILENAME" \
        -s "$THIS_DIR/github-markdown.css" \
        -o "$PDF_DIR/$FILENAME.pdf"
done
