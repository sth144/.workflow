#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME="${JOPLIN_DAILY_IMAGE_NAME:-workflow-joplin-daily}"
CONTAINER_NAME="${JOPLIN_DAILY_CONTAINER_NAME:-workflow-joplin-daily-run}"
ENV_FILE="$HOME/.env.joplin_daily"
LOCAL_GOOGLE_CREDS="$HOME/.config/google_service_account.json"
CONTAINER_GOOGLE_CREDS="/run/secrets/google_service_account.json"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

docker build \
  -f "${SCRIPT_DIR}/Dockerfile.joplin_daily" \
  -t "${IMAGE_NAME}" \
  "${SCRIPT_DIR}"

docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
trap 'docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true' EXIT

docker_args=(
  --rm
  --name "${CONTAINER_NAME}"
  --env-file "${ENV_FILE}"
)

if [[ -f "${LOCAL_GOOGLE_CREDS}" ]]; then
  docker_args+=(
    -v "${LOCAL_GOOGLE_CREDS}:${CONTAINER_GOOGLE_CREDS}:ro"
    -e "GOOGLE_SERVICE_ACCOUNT_FILE=${CONTAINER_GOOGLE_CREDS}"
  )
fi

docker run "${docker_args[@]}" "${IMAGE_NAME}"
