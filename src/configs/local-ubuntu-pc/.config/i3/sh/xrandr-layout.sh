#!/bin/bash

export DISPLAY=:1

is_connected() {
  xrandr --query | grep -q "^$1 connected"
}

cmd=(xrandr)

left_output="HDMI-1-0"
center_output="HDMI-1"
right_output="DVI-D-1-0"

left_connected=false
center_connected=false
right_connected=false

if is_connected "$left_output"; then
  left_connected=true
fi

if is_connected "$center_output"; then
  center_connected=true
fi

if is_connected "$right_output"; then
  right_connected=true
fi

if "$left_connected"; then
  cmd+=(--output "$left_output" --mode 1680x1050 --rotate left)
else
  cmd+=(--output "$left_output" --off)
fi

if "$center_connected"; then
  if "$left_connected"; then
    cmd+=(--output "$center_output" --primary --mode 3840x2160 --rotate normal --right-of "$left_output")
  else
    cmd+=(--output "$center_output" --primary --mode 3840x2160 --rotate normal)
  fi
else
  cmd+=(--output "$center_output" --off)
fi

if "$right_connected"; then
  if "$center_connected"; then
    cmd+=(--output "$right_output" --mode 2560x1440 --rotate normal --right-of "$center_output")
  elif "$left_connected"; then
    cmd+=(--output "$right_output" --mode 2560x1440 --rotate normal --right-of "$left_output")
  else
    cmd+=(--output "$right_output" --primary --mode 2560x1440 --rotate normal)
  fi
else
  cmd+=(--output "$right_output" --off)
fi

"${cmd[@]}"
