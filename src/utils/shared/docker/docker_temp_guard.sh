#!/bin/bash

set -u

STATE_HOME=${XDG_STATE_HOME:-$HOME/.local/state}
STATE_FILE=${WORKFLOW_DOCKER_TEMP_GUARD_STATE:-$STATE_HOME/workflow/docker-temp-guard.state}
DEFAULT_COOLDOWN_C=${WORKFLOW_DOCKER_TEMP_GUARD_COOLDOWN_C:-}

LABEL_PREFIX=workflow.temp_guard
LABEL_ENABLED=$LABEL_PREFIX.enabled
LABEL_MAX_C=$LABEL_PREFIX.max_c
LABEL_ACTION=$LABEL_PREFIX.action
LABEL_COOLDOWN_C=$LABEL_PREFIX.cooldown_c
LABEL_STOP_TIMEOUT=$LABEL_PREFIX.stop_timeout

log() {
  printf '%s docker-temp-guard: %s\n' "$(date '+%F %T')" "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: docker_temp_guard.sh

Stops or pauses Docker containers when CPU package temperature reaches a
per-container cutoff declared with Docker labels.

Docker Compose labels:
  workflow.temp_guard.enabled: "true"
  workflow.temp_guard.max_c: "90"
  workflow.temp_guard.action: "stop"       # stop or pause, default stop
  workflow.temp_guard.cooldown_c: "75"     # optional auto-restore threshold
  workflow.temp_guard.stop_timeout: "30"   # optional docker stop timeout

Example:
  labels:
    workflow.temp_guard.enabled: "true"
    workflow.temp_guard.max_c: "90"
    workflow.temp_guard.action: "stop"
    workflow.temp_guard.cooldown_c: "75"
EOF
}

cpu_temp_c() {
  local temp=
  local zone

  for zone in /sys/class/thermal/thermal_zone*; do
    [ -r "$zone/type" ] || continue
    [ -r "$zone/temp" ] || continue
    if grep -Eq 'x86_pkg_temp|coretemp|k10temp|cpu' "$zone/type"; then
      temp=$(cat "$zone/temp")
      [ "$temp" -gt 0 ] 2>/dev/null || continue
      printf '%s\n' "$((temp / 1000))"
      return 0
    fi
  done

  for temp in /sys/class/hwmon/hwmon*/temp*_input; do
    [ -r "$temp" ] || continue
    case "$temp" in
      */temp1_input)
        local hwmon_dir=${temp%/*}
        if [ -r "$hwmon_dir/name" ] && grep -Eq 'coretemp|k10temp' "$hwmon_dir/name"; then
          local value
          value=$(cat "$temp")
          [ "$value" -gt 0 ] 2>/dev/null || continue
          printf '%s\n' "$((value / 1000))"
          return 0
        fi
        ;;
    esac
  done

  return 1
}

label_value() {
  local container=$1
  local label=$2
  docker inspect --format "{{ index .Config.Labels \"$label\" }}" "$container" 2>/dev/null
}

container_status() {
  docker inspect --format '{{ .State.Status }}' "$1" 2>/dev/null
}

container_name() {
  docker inspect --format '{{ .Name }}' "$1" 2>/dev/null | sed 's#^/##'
}

is_true() {
  case "${1,,}" in
    1|true|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

is_int() {
  case "$1" in
    ''|*[!0-9]*) return 1 ;;
    *) return 0 ;;
  esac
}

remember_action() {
  local id=$1
  local action=$2
  local name=$3

  mkdir -p "$(dirname "$STATE_FILE")"
  touch "$STATE_FILE"
  grep -v "^$id	" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null || true
  printf '%s\t%s\t%s\n' "$id" "$action" "$name" >> "$STATE_FILE.tmp"
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

forget_action() {
  local id=$1

  [ -f "$STATE_FILE" ] || return 0
  grep -v "^$id	" "$STATE_FILE" > "$STATE_FILE.tmp" 2>/dev/null || true
  mv "$STATE_FILE.tmp" "$STATE_FILE"
}

restore_if_cooled() {
  local temp=$1
  local id action name cooldown status

  [ -f "$STATE_FILE" ] || return 0

  while IFS=$'\t' read -r id action name; do
    [ -n "${id:-}" ] || continue
    docker inspect "$id" >/dev/null 2>&1 || {
      forget_action "$id"
      continue
    }

    cooldown=$(label_value "$id" "$LABEL_COOLDOWN_C")
    [ -n "$cooldown" ] || cooldown=$DEFAULT_COOLDOWN_C
    is_int "$cooldown" || continue
    [ "$temp" -le "$cooldown" ] || continue

    status=$(container_status "$id")
    case "$action:$status" in
      stop:exited)
        log "starting $name: CPU package temperature ${temp}C is at or below cooldown ${cooldown}C"
        docker start "$id" >/dev/null && forget_action "$id"
        ;;
      pause:paused)
        log "unpausing $name: CPU package temperature ${temp}C is at or below cooldown ${cooldown}C"
        docker unpause "$id" >/dev/null && forget_action "$id"
        ;;
    esac
  done < "$STATE_FILE"
}

apply_cutoffs() {
  local temp=$1
  local id enabled max_c action timeout status name

  for id in $(docker ps -q); do
    enabled=$(label_value "$id" "$LABEL_ENABLED")
    is_true "$enabled" || continue

    max_c=$(label_value "$id" "$LABEL_MAX_C")
    if ! is_int "$max_c"; then
      log "skipping $(container_name "$id"): missing or invalid $LABEL_MAX_C label"
      continue
    fi

    [ "$temp" -ge "$max_c" ] || continue

    action=$(label_value "$id" "$LABEL_ACTION")
    [ -n "$action" ] || action=stop
    timeout=$(label_value "$id" "$LABEL_STOP_TIMEOUT")
    is_int "$timeout" || timeout=30

    status=$(container_status "$id")
    name=$(container_name "$id")
    case "$action:$status" in
      stop:running)
        log "stopping $name: CPU package temperature ${temp}C is at or above cutoff ${max_c}C"
        docker stop -t "$timeout" "$id" >/dev/null && remember_action "$id" stop "$name"
        ;;
      pause:running)
        log "pausing $name: CPU package temperature ${temp}C is at or above cutoff ${max_c}C"
        docker pause "$id" >/dev/null && remember_action "$id" pause "$name"
        ;;
      stop:*|pause:*)
        ;;
      *)
        log "skipping $name: unsupported $LABEL_ACTION value '$action'"
        ;;
    esac
  done
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  log "docker command not found"
  exit 127
fi

temp=$(cpu_temp_c) || {
  log "could not read CPU package temperature"
  exit 1
}

restore_if_cooled "$temp"
apply_cutoffs "$temp"
