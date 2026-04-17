#!/usr/bin/env bash
# docker-reset.sh — force-kill all Docker processes and restart Docker Desktop

set -euo pipefail

echo "🐳 Docker Reset"
echo "==============="

# Patterns to match against process names/paths
PATTERNS=(
    "Docker Desktop"
    "com.docker.docker"
    "com.docker.backend"
    "com.docker.build"
    "com.docker.virtualization"
    "docker-credential-desktop"
    "dockerd"
    "/Applications/Docker.app"
    "docker-mcp"
)

echo ""
echo "→ Finding Docker processes..."

PIDS=()
for pattern in "${PATTERNS[@]}"; do
    while IFS= read -r pid; do
        [[ -n "$pid" ]] && PIDS+=("$pid")
    done < <(pgrep -f "$pattern" 2>/dev/null || true)
done

# Deduplicate
PIDS=($(printf '%s\n' "${PIDS[@]}" | sort -u))

# Exclude our own PID
SELF=$$
PIDS=($(printf '%s\n' "${PIDS[@]}" | grep -v "^${SELF}$" || true))

if [[ ${#PIDS[@]} -eq 0 ]]; then
    echo "  No Docker processes found."
else
    echo "  Found ${#PIDS[@]} process(es): ${PIDS[*]}"
    echo ""
    echo "→ Killing processes..."
    for pid in "${PIDS[@]}"; do
        name=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        if kill -9 "$pid" 2>/dev/null; then
            echo "  killed $pid ($name)"
        else
            echo "  skipped $pid ($name) — already gone or no permission"
        fi
    done
fi

echo ""
echo "→ Cleaning up stale sockets and pid files..."
rm -f ~/Library/Containers/com.docker.docker/Data/docker.pid
rm -f ~/Library/Containers/com.docker.docker/Data/vms/0/docker.sock
rm -f /var/run/docker.pid 2>/dev/null || true

echo ""
echo "→ Waiting 2 seconds before restart..."
sleep 2

echo ""
echo "→ Launching Docker Desktop..."
open -a Docker

echo ""
echo "✓ Done. Docker Desktop is starting up."
echo "  Run 'docker ps' in ~15-20 seconds to confirm the daemon is ready."
