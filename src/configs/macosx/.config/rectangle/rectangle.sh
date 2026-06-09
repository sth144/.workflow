#!/usr/bin/env bash
# rectangle.sh — configure Rectangle window manager with i3-style gaps
#
# Run this script after installing Rectangle to set up gaps.
# Re-runnable; uses `defaults write` so it's idempotent.
#
# Usage: ./rectangle.sh [inner_gap] [outer_gap]
#   inner_gap: gap between windows (default: 10)
#   outer_gap: margin at screen edges (default: 10)

set -euo pipefail

INNER_GAP="${1:-2}"
OUTER_GAP="${2:-4}"

echo "Configuring Rectangle gaps..."
echo "  Inner gap (between windows): ${INNER_GAP}px"
echo "  Outer gap (screen edges):    ${OUTER_GAP}px"

# i3 "gaps inner" — gap between snapped windows
defaults write com.knollsoft.Rectangle gapSize -float "$INNER_GAP"

# i3 "gaps outer" — margins at screen edges
defaults write com.knollsoft.Rectangle screenEdgeGapTop    -float "$OUTER_GAP"
defaults write com.knollsoft.Rectangle screenEdgeGapBottom -float "$OUTER_GAP"
defaults write com.knollsoft.Rectangle screenEdgeGapLeft   -float "$OUTER_GAP"
defaults write com.knollsoft.Rectangle screenEdgeGapRight  -float "$OUTER_GAP"

# Restart Rectangle to apply
if pgrep -x "Rectangle" > /dev/null; then
  echo "Restarting Rectangle..."
  killall Rectangle 2>/dev/null || true
  sleep 0.5
fi

open -a Rectangle
echo "Done. Gaps configured."
