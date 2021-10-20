#!/bin/bash

docker ps --format '- targets: ["{{.ID}}"]\n  labels:\n    container_name: "{{.Names}}"' > /etc/promtail/promtail-targets.yaml