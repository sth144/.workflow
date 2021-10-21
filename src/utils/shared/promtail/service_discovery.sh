#!/bin/bash

HOSTNAME=$(hostname)

docker ps --format "- targets: [\"{{.ID}}\"]\n  labels:\n    container_name: \"{{.Names}}\"\n    host: $HOSTNAME" > /etc/promtail/promtail-targets.yaml