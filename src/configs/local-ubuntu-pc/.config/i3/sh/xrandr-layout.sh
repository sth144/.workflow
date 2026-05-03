#!/bin/bash

set -u

export DISPLAY=:1

xrandr_state=$(xrandr --query)

declare -a connected_outputs=()
declare -A output_modes=()
declare -A used_outputs=()

while IFS= read -r line; do
  if [[ $line =~ ^([A-Za-z0-9-]+)[[:space:]]connected ]]; then
    current_output=${BASH_REMATCH[1]}
    connected_outputs+=("$current_output")
    output_modes["$current_output"]=""
    continue
  fi

  if [[ $line =~ ^([A-Za-z0-9-]+)[[:space:]]disconnected ]]; then
    current_output=""
    continue
  fi

  if [[ -n ${current_output:-} && $line =~ ^[[:space:]]+([0-9]+x[0-9]+) ]]; then
    output_modes["$current_output"]+="${BASH_REMATCH[1]} "
  fi
done <<< "$xrandr_state"

output_supports_mode() {
  local output=$1
  local mode=$2

  [[ " ${output_modes[$output]:-} " == *" ${mode} "* ]]
}

find_output() {
  local expected_mode=$1
  shift
  local alias
  local output

  for alias in "$@"; do
    if [[ -n $alias && -n ${output_modes[$alias]:-} ]] && output_supports_mode "$alias" "$expected_mode"; then
      if [[ -z ${used_outputs[$alias]:-} ]]; then
        echo "$alias"
        return 0
      fi
    fi
  done

  for output in "${connected_outputs[@]}"; do
    if [[ -z ${used_outputs[$output]:-} ]] && output_supports_mode "$output" "$expected_mode"; then
      echo "$output"
      return 0
    fi
  done

  return 1
}

dell_output=$(find_output "1680x1050" "HDMI-1-0" "HDMI-1" "DVI-D-1-0" || true)
if [[ -n $dell_output ]]; then
  used_outputs["$dell_output"]=1
fi

ktc_output=$(find_output "3840x2160" "HDMI-1" "HDMI-1-0" "DVI-D-1-0" || true)
if [[ -n $ktc_output ]]; then
  used_outputs["$ktc_output"]=1
fi

aoc_output=$(find_output "2560x1440" "DVI-D-1-0" "HDMI-1-0" "HDMI-1" || true)
if [[ -n $aoc_output ]]; then
  used_outputs["$aoc_output"]=1
fi

cmd=(xrandr)

# Known monitor targets on this host:
# Dell P2210 = 1680x1050, rotated left, leftmost
# KTC        = 3840x2160, primary, middle
# AOC        = 2560x1440, rightmost
if [[ -n $ktc_output ]]; then
  cmd+=(--output "$ktc_output" --primary --mode 3840x2160 --rotate normal)
fi

if [[ -n $dell_output ]]; then
  if [[ -n $ktc_output ]]; then
    cmd+=(--output "$dell_output" --mode 1680x1050 --rotate left --left-of "$ktc_output")
  elif [[ -n $aoc_output ]]; then
    cmd+=(--output "$dell_output" --primary --mode 1680x1050 --rotate left --left-of "$aoc_output")
  else
    cmd+=(--output "$dell_output" --primary --mode 1680x1050 --rotate left)
  fi
fi

if [[ -n $aoc_output ]]; then
  if [[ -n $ktc_output ]]; then
    cmd+=(--output "$aoc_output" --mode 2560x1440 --rotate normal --right-of "$ktc_output")
  elif [[ -n $dell_output ]]; then
    cmd+=(--output "$aoc_output" --mode 2560x1440 --rotate normal --right-of "$dell_output")
  else
    cmd+=(--output "$aoc_output" --primary --mode 2560x1440 --rotate normal)
  fi
fi

for output in "${connected_outputs[@]}"; do
  if [[ -z ${used_outputs[$output]:-} ]]; then
    cmd+=(--output "$output" --off)
  fi
done

"${cmd[@]}"
