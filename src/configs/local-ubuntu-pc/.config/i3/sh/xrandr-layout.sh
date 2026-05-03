#!/bin/bash

export DISPLAY=:1

is_connected() {
  xrandr --query | grep -q "^$1 connected"
}

cmd=(xrandr)
aoc_connected=false
dell_connected=false
ktc_connected=false

if is_connected "DVI-D-1-0"; then
  aoc_connected=true
fi

if is_connected "HDMI-1-0"; then
  dell_connected=true
fi

if is_connected "HDMI-1"; then
  ktc_connected=true
fi

# Known monitor mapping on this host:
# HDMI-1-0   = Dell P2210 (left, 1680x1050)
# HDMI-1     = KTC (primary, middle, 3840x2160)
# DVI-D-1-0  = AOC (right, 2560x1440)
if "$ktc_connected"; then
  cmd+=(--output HDMI-1 --primary --mode 3840x2160 --rotate normal)
else
  cmd+=(--output HDMI-1 --off)
fi

if "$dell_connected"; then
  if "$ktc_connected"; then
    cmd+=(--output HDMI-1-0 --mode 1680x1050 --rotate left --left-of HDMI-1)
  elif "$aoc_connected"; then
    cmd+=(--output HDMI-1-0 --primary --mode 1680x1050 --rotate left --left-of DVI-D-1-0)
  else
    cmd+=(--output HDMI-1-0 --primary --mode 1680x1050 --rotate left)
  fi
else
  cmd+=(--output HDMI-1-0 --off)
fi

if "$aoc_connected"; then
  if "$ktc_connected"; then
    cmd+=(--output DVI-D-1-0 --mode 2560x1440 --rotate normal --right-of HDMI-1)
  elif "$dell_connected"; then
    cmd+=(--output DVI-D-1-0 --mode 2560x1440 --rotate normal --right-of HDMI-1-0)
  else
    cmd+=(--output DVI-D-1-0 --primary --mode 2560x1440 --rotate normal)
  fi
else
  cmd+=(--output DVI-D-1-0 --off)
fi

"${cmd[@]}"
