#!/bin/bash

set -u

TEMP_LIMIT_C=${WORKFLOW_HEAVY_TEMP_LIMIT_C:-80}
LOAD_LIMIT=${WORKFLOW_HEAVY_LOAD_LIMIT:-}

log() {
  printf '%s workflow-heavy-job: %s\n' "$(date '+%F %T')" "$*" >&2
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

raid_busy() {
  [ -r /proc/mdstat ] || return 1
  grep -Eq 'resync|recovery|reshape|check' /proc/mdstat
}

load_too_high() {
  local limit=${LOAD_LIMIT}
  local load

  if [ -z "$limit" ]; then
    limit=$(nproc 2>/dev/null || printf '1')
  fi

  load=$(awk '{print int($1 + 0.999)}' /proc/loadavg 2>/dev/null) || return 1
  [ "$load" -ge "$limit" ] 2>/dev/null
}

if [ "$#" -eq 0 ]; then
  log "no command provided"
  exit 64
fi

temp=$(cpu_temp_c || true)
if [ -n "${temp:-}" ] && [ "$temp" -ge "$TEMP_LIMIT_C" ] 2>/dev/null; then
  log "skipping '$*': CPU package temperature ${temp}C is at or above ${TEMP_LIMIT_C}C"
  exit 0
fi

if raid_busy; then
  log "skipping '$*': RAID maintenance is active"
  exit 0
fi

if load_too_high; then
  log "skipping '$*': load average is already high"
  exit 0
fi

exec ionice -c3 nice -n 19 "$@"
