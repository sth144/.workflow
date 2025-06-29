#!/bin/bash

HOSTNAME=$(hostname)

OUTFILE=/etc/promtail/promtail-targets.yaml
echo "" >$OUTFILE

/usr/local/bin/docker ps --format "- targets: [\"{{.ID}}\"]\n  labels:\n    container_name: \"{{.Names}}\"\n    host: $HOSTNAME" >>$OUTFILE
