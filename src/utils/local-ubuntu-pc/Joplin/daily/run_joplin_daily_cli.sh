#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${JOPLIN_DAILY_ENV_FILE:-$HOME/.env.joplin_daily}"
PYTHON_BIN="${JOPLIN_DAILY_PYTHON_BIN:-python3}"
STATE_DIR="${JOPLIN_DAILY_STATE_DIR:-$HOME/.local/state/joplin_daily}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "Missing env file: ${ENV_FILE}" >&2
  exit 1
fi

set -a
source "${ENV_FILE}"
set +a

if [[ -z "${STATE_PATH:-}" ]]; then
  mkdir -p "${STATE_DIR}"
  export STATE_PATH="${STATE_DIR}/state.json"
fi

if [[ -z "${JOPLIN_CLI_BIN:-}" ]]; then
  if command -v joplin-cli >/dev/null 2>&1; then
    export JOPLIN_CLI_BIN="joplin-cli"
  elif command -v joplin >/dev/null 2>&1; then
    export JOPLIN_CLI_BIN="joplin"
  else
    echo "Missing joplin-cli executable. Set JOPLIN_CLI_BIN or install joplin-cli." >&2
    exit 1
  fi
fi

exec "${PYTHON_BIN}" "${SCRIPT_DIR}/daily_log_cli.py"
