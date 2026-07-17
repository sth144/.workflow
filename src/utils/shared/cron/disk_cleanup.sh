#!/bin/bash
set -u

log() {
  printf '[%s] %s\n' "$(date -Is)" "$*"
}

run_if_available() {
  local cmd="$1"
  shift

  if command -v "$cmd" >/dev/null 2>&1; then
    log "running: $cmd $*"
    "$cmd" "$@" || log "warning: $cmd failed with status $?"
  fi
}

cleanup_dir_contents() {
  local dir="$1"
  local days="$2"

  [ -d "$dir" ] || return 0
  log "removing entries older than ${days} days from $dir"
  find "$dir" -mindepth 1 -mtime +"$days" -exec rm -rf {} +
}

cleanup_dir_all() {
  local dir="$1"

  [ -d "$dir" ] || return 0
  log "clearing $dir"
  find "$dir" -mindepth 1 -exec rm -rf {} +
}

USER_HOME="${WORKFLOW_CLEANUP_HOME:-/home/<USER>}"
if [ ! -d "$USER_HOME" ]; then
  USER_HOME="${HOME:-}"
fi

log "starting disk cleanup"

run_if_available docker system prune -af
run_if_available docker builder prune -af
run_if_available crictl rmi --prune
run_if_available conda clean -y --all
run_if_available pip cache purge
run_if_available pip3 cache purge

if command -v npm >/dev/null 2>&1 && [ -n "$USER_HOME" ]; then
  NPM_CACHE="$USER_HOME/.npm"
  if [ -d "$NPM_CACHE" ]; then
    log "clearing npm cache at $NPM_CACHE"
    cleanup_dir_all "$NPM_CACHE/_cacache"
    cleanup_dir_contents "$NPM_CACHE/_logs" 7
  fi
fi

if [ -n "$USER_HOME" ]; then
  cleanup_dir_contents "$USER_HOME/.cache/pip" 7
  cleanup_dir_contents "$USER_HOME/.codex/.tmp" 7
  cleanup_dir_contents "$USER_HOME/tmp" 14

  if [ "${WORKFLOW_CLEAN_DOWNLOADS:-0}" = "1" ]; then
    cleanup_dir_contents "$USER_HOME/Downloads" "${WORKFLOW_CLEAN_DOWNLOADS_DAYS:-30}"
  fi
fi

if command -v apt-get >/dev/null 2>&1; then
  log "cleaning apt packages and cache"
  apt-get -y autoremove --purge || log "warning: apt autoremove failed with status $?"
  apt-get clean || log "warning: apt clean failed with status $?"
fi

if command -v journalctl >/dev/null 2>&1; then
  log "vacuuming systemd journal"
  journalctl --vacuum-time=14d --vacuum-size=100M || log "warning: journal vacuum failed with status $?"
fi

if [ -d /var/lib/snapd/cache ]; then
  cleanup_dir_all /var/lib/snapd/cache
fi

log "disk cleanup complete"
