#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${JOPLIN_DAILY_IMAGE_NAME:-workflow-joplin-daily}"
CONTAINER_NAME="${JOPLIN_DAILY_CONTAINER_NAME:-workflow-joplin-daily-run}"
ENV_FILE="${JOPLIN_DAILY_ENV_FILE:-$HOME/.env.joplin_daily}"
LOCAL_GOOGLE_CREDS="$HOME/.config/google_service_account.json"
CONTAINER_GOOGLE_CREDS="/run/secrets/google_service_account.json"
SSH_PID=""

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

# Load env vars for wrapper behavior (tunnel flags, overrides) as well as container runtime.
set -a
source "${ENV_FILE}"
set +a

TUNNEL_ENABLED="${JOPLIN_TUNNEL_ENABLED:-0}"
TUNNEL_SSH_TARGET="${JOPLIN_TUNNEL_SSH_TARGET:-}"
TUNNEL_LOCAL_PORT="${JOPLIN_TUNNEL_LOCAL_PORT:-41185}"
TUNNEL_REMOTE_HOST="${JOPLIN_TUNNEL_REMOTE_HOST:-127.0.0.1}"
TUNNEL_REMOTE_PORT="${JOPLIN_TUNNEL_REMOTE_PORT:-41184}"

docker build \
  -f "${SCRIPT_DIR}/Dockerfile.joplin_daily" \
  -t "${IMAGE_NAME}" \
  "${SCRIPT_DIR}"

cleanup() {
  docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  if [[ -n "${SSH_PID}" ]] && kill -0 "${SSH_PID}" >/dev/null 2>&1; then
    kill "${SSH_PID}" >/dev/null 2>&1 || true
    wait "${SSH_PID}" >/dev/null 2>&1 || true
  fi
}

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
trap cleanup EXIT

docker_args=(
  --rm
  --name "${CONTAINER_NAME}"
  --env-file "${ENV_FILE}"
)

if [[ "${TUNNEL_ENABLED}" == "1" || "${TUNNEL_ENABLED}" == "true" ]]; then
  if [[ -z "${TUNNEL_SSH_TARGET}" ]]; then
    echo "Missing JOPLIN_TUNNEL_SSH_TARGET for tunnel mode" >&2
    exit 1
  fi

  ssh -N \
    -o ExitOnForwardFailure=yes \
    -o ServerAliveInterval=30 \
    -o ServerAliveCountMax=3 \
    -L "${TUNNEL_LOCAL_PORT}:${TUNNEL_REMOTE_HOST}:${TUNNEL_REMOTE_PORT}" \
    "${TUNNEL_SSH_TARGET}" &
  SSH_PID="$!"
  sleep 1
  if ! kill -0 "${SSH_PID}" >/dev/null 2>&1; then
    echo "Failed to establish SSH tunnel" >&2
    exit 1
  fi

  docker_args+=(
    --network host
    -e "JOPLIN_BASE_URL=http://127.0.0.1:${TUNNEL_LOCAL_PORT}"
  )
fi

if [[ -f "${LOCAL_GOOGLE_CREDS}" ]]; then
  docker_args+=(
    -v "${LOCAL_GOOGLE_CREDS}:${CONTAINER_GOOGLE_CREDS}:ro"
    -e "GOOGLE_SERVICE_ACCOUNT_FILE=${CONTAINER_GOOGLE_CREDS}"
  )
fi

docker run "${docker_args[@]}" "${IMAGE_NAME}"
