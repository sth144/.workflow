#!/bin/bash

HOSTNAME=$(hostname)
OUTFILE=/etc/promtail/promtail-targets.yaml

# Run crictl ps command and extract relevant information

crictl_ps_output=$(crictl ps --output json)
container_ids=($(echo "$crictl_ps_output" | jq -r '.containers[] | .id'))
container_names=($(echo "$crictl_ps_output" | jq -r '.containers[] | .metadata.name'))

echo "" >$OUTFILE

# Loop through each container in the output
for ((i = 0; i < ${#container_ids[@]}; i++)); do
  container_id=${container_ids[$i]}
  container_name=${container_names[$i]}

  # Print YAML list item
  echo "- targets: [\"$container_id\"]" >>$OUTFILE
  echo "  labels:" >>$OUTFILE
  echo "    container_name: $container_name" >>$OUTFILE
  echo "    host: $HOSTNAME" >>$OUTFILE
done

docker ps --format "- targets: [\"{{.ID}}\"]\n  labels:\n    container_name: \"{{.Names}}\"\n    host: $HOSTNAME" >>$OUTFILE
