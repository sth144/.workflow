#!/usr/bin/env bash
#
# build_scratchpad_icons.sh — regenerate the scratchpad .icns files from their SVG
# sources. This is a DEV/build-time tool: run it after editing any SVG so the
# committed .icns stay in sync. The .icns are checked in so end-user installs need
# no rasterizer.
#
# Usage:
#   build_scratchpad_icons.sh [ICONS_DIR]
#
# ICONS_DIR defaults to this repo's src/configs/macosx/.config/scratchpad-icons.
# It must contain an svg/ subdir; .icns are written alongside it.
#
# Requires: rsvg-convert (brew install librsvg) and iconutil (built into macOS).

set -euo pipefail

# `cd ... >/dev/null` so a CDPATH set in the user's profile can't echo the target
# dir into the command substitution (which would corrupt the resolved path).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
DEFAULT_DIR="$SCRIPT_DIR/../../../configs/macosx/.config/scratchpad-icons"
ICONS_DIR="${1:-$DEFAULT_DIR}"
SVG_DIR="$ICONS_DIR/svg"

command -v rsvg-convert >/dev/null 2>&1 || { echo "error: rsvg-convert not found (brew install librsvg)" >&2; exit 1; }
command -v iconutil    >/dev/null 2>&1 || { echo "error: iconutil not found (macOS only)" >&2; exit 1; }
[ -d "$SVG_DIR" ] || { echo "error: no svg dir at $SVG_DIR" >&2; exit 1; }

# iconset members: "filename:pixel-size"
SPECS=(
  "icon_16x16.png:16"   "icon_16x16@2x.png:32"
  "icon_32x32.png:32"   "icon_32x32@2x.png:64"
  "icon_128x128.png:128" "icon_128x128@2x.png:256"
  "icon_256x256.png:256" "icon_256x256@2x.png:512"
  "icon_512x512.png:512" "icon_512x512@2x.png:1024"
)

built=0
for svg in "$SVG_DIR"/*.svg; do
  [ -e "$svg" ] || { echo "no SVGs found in $SVG_DIR" >&2; exit 1; }
  name="$(basename "$svg" .svg)"
  iconset="$(mktemp -d)/$name.iconset"
  mkdir -p "$iconset"
  for spec in "${SPECS[@]}"; do
    file="${spec%%:*}"; size="${spec##*:}"
    rsvg-convert -w "$size" -h "$size" "$svg" -o "$iconset/$file"
  done
  iconutil -c icns "$iconset" -o "$ICONS_DIR/$name.icns"
  rm -rf "$(dirname "$iconset")"
  echo "  built $name.icns"
  built=$((built + 1))
done

echo "built $built icns into $ICONS_DIR"
