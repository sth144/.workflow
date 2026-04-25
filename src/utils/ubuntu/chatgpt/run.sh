#!/bin/bash

cd "$HOME/src/chatgpt-cli/"
if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    source .venv/bin/activate
fi
python chatgpt.py
