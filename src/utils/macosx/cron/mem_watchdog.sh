#!/bin/bash
# mem_watchdog.sh — Monitors swap usage and Docker memory pressure.
# Sends a macOS notification when thresholds are exceeded.
# Logs all checks to a logfile for diagnostics.

LOGFILE="$HOME/.cache/mem-watchdog.log"
SWAP_WARN_MB=6000
SWAP_CRIT_MB=10000

mkdir -p "$(dirname "$LOGFILE")"

log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGFILE"
}

# Get swap usage in MB (integer)
SWAP_USED=$(sysctl vm.swapusage 2>/dev/null | awk '{print $7}' | tr -d 'M')
SWAP_USED_INT=${SWAP_USED%%.*}

if [ -z "$SWAP_USED_INT" ]; then
  log "ERROR: Could not parse swap usage"
  exit 1
fi

# Get Docker container memory if Docker is running
DOCKER_MEM=""
if command -v docker &>/dev/null && docker info &>/dev/null 2>&1; then
  DOCKER_MEM=$(docker stats --no-stream --format "{{.Name}}: {{.MemUsage}} ({{.MemPerc}})" 2>/dev/null)
fi

log "swap_used=${SWAP_USED_INT}MB docker=[${DOCKER_MEM}]"

# Trim logfile to last 500 lines periodically
LINES=$(wc -l < "$LOGFILE" 2>/dev/null)
if [ "${LINES:-0}" -gt 1000 ]; then
  tail -500 "$LOGFILE" > "$LOGFILE.tmp" && mv "$LOGFILE.tmp" "$LOGFILE"
  log "Trimmed logfile to 500 lines"
fi

if [ "$SWAP_USED_INT" -gt "$SWAP_CRIT_MB" ]; then
  log "CRITICAL: Swap ${SWAP_USED_INT}MB exceeds ${SWAP_CRIT_MB}MB threshold"
  osascript -e "display notification \"Swap at ${SWAP_USED_INT}MB — system is thrashing. Consider restarting Docker or closing Claude sessions.\" with title \"Memory CRITICAL\" sound name \"Funk\"" 2>/dev/null
elif [ "$SWAP_USED_INT" -gt "$SWAP_WARN_MB" ]; then
  log "WARNING: Swap ${SWAP_USED_INT}MB exceeds ${SWAP_WARN_MB}MB threshold"
  osascript -e "display notification \"Swap at ${SWAP_USED_INT}MB — memory pressure is building.\" with title \"Memory Warning\"" 2>/dev/null
else
  log "OK: Swap ${SWAP_USED_INT}MB within limits"
fi
