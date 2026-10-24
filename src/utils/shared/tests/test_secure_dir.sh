#!/usr/bin/env bash

set -euo pipefail

SCRIPT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)/secure-dir.sh
TEST_ROOT=$(mktemp -d)
trap 'rm -rf "$TEST_ROOT"' EXIT

export HOME=$TEST_ROOT/home
export SECURE_DIR_STATE_ROOT=$TEST_ROOT/state
export SECURE_DIR_PORTAL_ROOT=$TEST_ROOT/portals
export SECURE_DIR_TEST_MOUNT_STATE=$TEST_ROOT/mounted
export SECURE_DIR_TTY=/dev/null
mkdir -p "$HOME" "$TEST_ROOT/bin"

cat > "$TEST_ROOT/bin/encfs" <<'EOF'
#!/usr/bin/env bash
set -eu
if [ "${1:-}" = --standard ]; then
  shift
  mkdir -p "$1" "$2"
  touch "$1/.encfs6.xml"
fi
touch "$SECURE_DIR_TEST_MOUNT_STATE"
EOF

cat > "$TEST_ROOT/bin/mountpoint" <<'EOF'
#!/usr/bin/env bash
test -e "$SECURE_DIR_TEST_MOUNT_STATE"
EOF

cat > "$TEST_ROOT/bin/fusermount3" <<'EOF'
#!/usr/bin/env bash
rm -f "$SECURE_DIR_TEST_MOUNT_STATE"
EOF

cat > "$TEST_ROOT/bin/umount" <<'EOF'
#!/usr/bin/env bash
rm -f "$SECURE_DIR_TEST_MOUNT_STATE"
EOF

chmod +x "$TEST_ROOT/bin/encfs" "$TEST_ROOT/bin/mountpoint" \
	"$TEST_ROOT/bin/fusermount3" "$TEST_ROOT/bin/umount"
export PATH=$TEST_ROOT/bin:/usr/bin:/bin

"$SCRIPT" init example
test -f "$SECURE_DIR_STATE_ROOT/example/cipher/.encfs6.xml"
test -f "$SECURE_DIR_PORTAL_ROOT/example/.envrc"
test ! -e "$SECURE_DIR_TEST_MOUNT_STATE"
grep -F 'secure-dir.sh unlock example "$PWD"' "$SECURE_DIR_PORTAL_ROOT/example/.envrc" >/dev/null

test "$("$SCRIPT" status example)" = 'example: locked'
"$SCRIPT" unlock example
test "$("$SCRIPT" status example)" = "example: unlocked ($SECURE_DIR_PORTAL_ROOT/example/files)"
"$SCRIPT" unlock example
"$SCRIPT" lock example
test "$("$SCRIPT" status example)" = 'example: locked'

if "$SCRIPT" status missing >/dev/null 2>&1; then
	echo "expected an uninitialized vault status to be non-zero" >&2
	exit 1
fi

echo "secure-dir tests passed"
