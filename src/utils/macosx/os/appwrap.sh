#!/usr/bin/env bash
#
# appwrap — launch any binary as a macOS .app bundle with a custom icon and title
#
# Usage:
#   appwrap --binary /path/to/bin --title "My App" --icon /path/to/icon.icns
#   appwrap --binary /path/to/bin --title "My App" --icon /path/to/icon.png
#   appwrap --binary /path/to/App.app --title "My App" --icon /path/to/icon.icns
#
# Options:
#   --binary, -b    Path to executable or .app bundle (required)
#   --title, -t     Display name for dock/app switcher (required)
#   --icon, -i      Path to .icns or .png icon file (required)
#   --args, -a      Additional arguments to pass to the binary (optional)
#   --keep, -k      Keep the wrapper .app after exit (don't auto-cleanup)
#   --help, -h      Show this help message
#
# The wrapper bundle is created under /tmp and cleaned up on exit unless --keep is set.

set -euo pipefail

WRAP_DIR="/tmp/appwrap"
CLEANUP=true
EXTRA_ARGS=()

usage() {
  sed -n '3,16p' "$0" | sed 's/^# \?//'
  exit "${1:-0}"
}

die() {
  echo "appwrap: error: $1" >&2
  exit 1
}

parse_args() {
  BINARY=""
  TITLE=""
  ICON=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --binary|-b)  BINARY="$2"; shift 2 ;;
      --title|-t)   TITLE="$2"; shift 2 ;;
      --icon|-i)    ICON="$2"; shift 2 ;;
      --args|-a)    shift; EXTRA_ARGS+=("$@"); break ;;
      --keep|-k)    CLEANUP=false; shift ;;
      --help|-h)    usage 0 ;;
      *)            die "unknown option: $1" ;;
    esac
  done

  [[ -n "$BINARY" ]] || die "--binary is required"
  [[ -n "$TITLE" ]]  || die "--title is required"
  [[ -n "$ICON" ]]   || die "--icon is required"
  [[ -e "$BINARY" ]] || die "binary not found: $BINARY"
  [[ -f "$ICON" ]]   || die "icon not found: $ICON"
}

resolve_binary() {
  # If the target is an .app bundle, find the actual executable inside it
  if [[ "$BINARY" == *.app && -d "$BINARY" ]]; then
    local plist="$BINARY/Contents/Info.plist"
    if [[ -f "$plist" ]]; then
      local exec_name
      exec_name=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$plist" 2>/dev/null) || true
      if [[ -n "$exec_name" && -x "$BINARY/Contents/MacOS/$exec_name" ]]; then
        BINARY="$BINARY/Contents/MacOS/$exec_name"
        return
      fi
    fi
    # Fallback: first executable in Contents/MacOS
    local first_exec
    first_exec=$(find "$BINARY/Contents/MacOS" -type f -perm +111 | head -1)
    [[ -n "$first_exec" ]] || die "no executable found in $BINARY"
    BINARY="$first_exec"
  fi
}

prepare_icon() {
  # Convert to .icns if needed; output path in ICNS_PATH
  local ext="${ICON##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  if [[ "$ext" == "icns" ]]; then
    ICNS_PATH="$ICON"
    return
  fi

  # Convert png/jpg/etc to icns via iconutil (requires iconset)
  local iconset_dir
  iconset_dir=$(mktemp -d "${TMPDIR:-/tmp}/appwrap_iconset.XXXXXX")
  iconset_dir="$iconset_dir/icon.iconset"
  mkdir -p "$iconset_dir"

  local sizes=(16 32 128 256 512)
  for size in "${sizes[@]}"; do
    sips -z "$size" "$size" "$ICON" --out "$iconset_dir/icon_${size}x${size}.png" >/dev/null 2>&1
    local double=$((size * 2))
    sips -z "$double" "$double" "$ICON" --out "$iconset_dir/icon_${size}x${size}@2x.png" >/dev/null 2>&1
  done

  ICNS_PATH="${iconset_dir%/*}/icon.icns"
  iconutil -c icns "$iconset_dir" -o "$ICNS_PATH"
}

build_bundle() {
  # Sanitize title for filesystem use
  local safe_name
  safe_name=$(echo "$TITLE" | tr -cs '[:alnum:]._-' '_')

  BUNDLE_PATH="$WRAP_DIR/${safe_name}_$$.app"
  local contents="$BUNDLE_PATH/Contents"

  mkdir -p "$contents/MacOS" "$contents/Resources"

  # Copy icon
  cp "$ICNS_PATH" "$contents/Resources/appwrap.icns"

  # Write Info.plist
  cat > "$contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>${TITLE}</string>
  <key>CFBundleDisplayName</key>
  <string>${TITLE}</string>
  <key>CFBundleExecutable</key>
  <string>launcher</string>
  <key>CFBundleIconFile</key>
  <string>appwrap</string>
  <key>CFBundleIdentifier</key>
  <string>com.appwrap.${safe_name}</string>
  <key>CFBundleVersion</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSUIElement</key>
  <false/>
</dict>
</plist>
PLIST

  # Write launcher script
  local binary_abs
  binary_abs=$(cd "$(dirname "$BINARY")" && pwd)/$(basename "$BINARY")

  cat > "$contents/MacOS/launcher" <<LAUNCHER
#!/usr/bin/env bash
exec "$binary_abs" $(printf '"%s" ' "${EXTRA_ARGS[@]}" 2>/dev/null)"\$@"
LAUNCHER
  chmod +x "$contents/MacOS/launcher"

  # Remove quarantine so Gatekeeper doesn't block it
  xattr -dr com.apple.quarantine "$BUNDLE_PATH" 2>/dev/null || true
}

cleanup() {
  if $CLEANUP && [[ -d "$BUNDLE_PATH" ]]; then
    rm -rf "$BUNDLE_PATH"
  fi
}

main() {
  parse_args "$@"
  resolve_binary
  prepare_icon
  mkdir -p "$WRAP_DIR"
  build_bundle

  if $CLEANUP; then
    trap cleanup EXIT INT TERM
  fi

  echo "appwrap: launching '$TITLE' from $BUNDLE_PATH"
  if $CLEANUP; then
    echo "appwrap: wrapper will be removed on exit (use --keep to preserve)"
  else
    echo "appwrap: wrapper preserved at $BUNDLE_PATH"
  fi

  open -W "$BUNDLE_PATH"
}

main "$@"
