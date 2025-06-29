#!/bin/bash

# Path to file
ENV_FILE="$HOME/.envrc"

# Extract GRAFANA_API_KEY value safely
GRAFANA_API_KEY=$(grep '^export GRAFANA_API_KEY=' "$ENV_FILE" | sed -E 's/^export GRAFANA_API_KEY=["'\'']?(.*?)["'\'']?$/\1/')

# Fail if not found
if [[ -z "$GRAFANA_API_KEY" ]]; then
  echo "Error: GRAFANA_API_KEY not found in $ENV_FILE" >&2
  exit 1
fi

DASHBOARD_UID="UenQXXggz"
OUTPUT_PATH="$HOME/Projects/monitoring/config/provisioning/dashboards/resource-overview.json"
GRAFANA_HOST="http://localhost:10080"

# Export dashboard JSON
curl -s -H "Authorization: Bearer ${GRAFANA_API_KEY}" \
     "${GRAFANA_HOST}/api/dashboards/uid/${DASHBOARD_UID}" \
  | jq '.dashboard' > "${OUTPUT_PATH}"


