#!/bin/bash

cd /home/<USER>/chatgpt-cli

if [[ -z "$(echo $VIRTUAL_ENV)" ]]; 
then 
  source .venv/bin/activate; 
fi 

python chatgpt.py"