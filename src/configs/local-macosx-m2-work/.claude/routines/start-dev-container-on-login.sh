#!/bin/bash
# Wrapper script for launchd - waits for Docker, then starts dev environment

LOG_FILE="$HOME/Library/Logs/start-dev-container.log"
START_DEV_SCRIPT="$HOME/Coding/Projects/sthinds/config/start-dev.sh"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

log "=== start-dev-container-on-login started ==="

# Wait for Docker Desktop to launch (up to 5 minutes)
MAX_WAIT=300
WAITED=0
INTERVAL=5

log "Waiting for Docker daemon..."
while ! docker info >/dev/null 2>&1; do
  if [ $WAITED -ge $MAX_WAIT ]; then
    log "ERROR: Docker not ready after ${MAX_WAIT}s, giving up"
    exit 1
  fi
  sleep $INTERVAL
  WAITED=$((WAITED + INTERVAL))
done

log "Docker ready after ${WAITED}s"

# Run the actual start script
log "Running start-dev.sh..."
cd "$(dirname "$START_DEV_SCRIPT")"
"$START_DEV_SCRIPT" >> "$LOG_FILE" 2>&1
EXIT_CODE=$?

log "start-dev.sh exited with code $EXIT_CODE"
exit $EXIT_CODE
