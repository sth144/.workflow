#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${JOPLIN_DAILY_ENV_FILE:-$HOME/.env.joplin_daily}"
STATE_DIR="${JOPLIN_DAILY_STATE_DIR:-$HOME/.local/state/joplin_daily}"
REQUIREMENTS_FILE="${SCRIPT_DIR}/requirements.txt"
VENV_DIR="${JOPLIN_DAILY_VENV_DIR:-${SCRIPT_DIR}/.venv}"
VENV_PYTHON="${VENV_DIR}/bin/python"
VENV_STAMP="${VENV_DIR}/.requirements-installed"
PYTHON_BIN="${JOPLIN_DAILY_PYTHON_BIN:-}"
LOCAL_GOOGLE_CREDS="${HOME}/.config/google_service_account.json"

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

if [[ -n "${GOOGLE_SERVICE_ACCOUNT_FILE:-}" ]]; then
  case "${GOOGLE_SERVICE_ACCOUNT_FILE}" in
    /run/secrets/google_service_account.json|run/secrets/google_service_account.json)
      if [[ -f "${LOCAL_GOOGLE_CREDS}" ]]; then
        export GOOGLE_SERVICE_ACCOUNT_FILE="${LOCAL_GOOGLE_CREDS}"
      else
        unset GOOGLE_SERVICE_ACCOUNT_FILE
      fi
      ;;
  esac
fi

if [[ -z "${PYTHON_BIN}" ]]; then
  if [[ ! -x "${VENV_PYTHON}" ]]; then
    python3 -m venv "${VENV_DIR}"
  fi

  if [[ ! -f "${VENV_STAMP}" || "${REQUIREMENTS_FILE}" -nt "${VENV_STAMP}" ]]; then
    "${VENV_PYTHON}" -m pip install -r "${REQUIREMENTS_FILE}"
    touch "${VENV_STAMP}"
  fi

  PYTHON_BIN="${VENV_PYTHON}"
fi

exec "${PYTHON_BIN}" "${SCRIPT_DIR}/daily_log_joplin_cli.py"
