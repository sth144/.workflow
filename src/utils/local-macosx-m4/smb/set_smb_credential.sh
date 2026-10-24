#!/usr/bin/env bash
#
# Save an SMB password to the login keychain, but only after proving the server
# accepts it. mount_smb_shares.sh reads credentials from the keychain and never
# shows UI, so this is how a stale or missing password gets repaired.
#
#   set_smb_credential.sh pi@home.assistant/pi raspberrypi.local 192.168.1.243
#
# The password is read with echo off and is never printed or logged.
set -u

usage() {
    echo "usage: $(basename "$0") <user>@<host>/<share> [alternate-keys...]" >&2
    echo "  alternate-keys: other names the share is reachable by (IP, Bonjour)," >&2
    echo "                  each gets its own keychain entry so lookups hit." >&2
    exit 2
}

[[ $# -ge 1 ]] || usage

TARGET="$1"
shift

[[ "$TARGET" == *@*/* ]] || usage
USER_NAME="${TARGET%%@*}"
REST="${TARGET#*@}"
HOST="${REST%%/*}"
SHARE="${REST#*/}"

TMP="$(mktemp -d)"
trap 'umount "$TMP/mnt" 2>/dev/null; rm -rf "$TMP"' EXIT
mkdir -p "$TMP/mnt"

if ! /usr/bin/nc -G 3 -z "$HOST" 445 >/dev/null 2>&1; then
    echo "$HOST is not accepting SMB on port 445 -- is the server up?" >&2
    exit 1
fi

printf 'Password for %s@%s: ' "$USER_NAME" "$HOST" >&2
read -rs PASSWORD
printf '\n' >&2
[[ -n "$PASSWORD" ]] || { echo "No password entered." >&2; exit 1; }

ENC="$(PW="$PASSWORD" /usr/bin/python3 -c \
    'import os, urllib.parse; print(urllib.parse.quote(os.environ["PW"], safe=""))')"

if ! /sbin/mount -t smbfs -o nobrowse,soft,noowners \
    "//${USER_NAME}:${ENC}@${HOST}/${SHARE}" "$TMP/mnt" 2>"$TMP/err"; then
    echo "Rejected by $HOST: $(sed 's/mount_smbfs: //' "$TMP/err")" >&2
    echo "If the password is definitely right, reset Samba on the box:" >&2
    echo "  sudo smbpasswd -a $USER_NAME" >&2
    exit 1
fi
umount "$TMP/mnt" 2>/dev/null
echo "Accepted by $HOST."

for key in "$HOST" "$@"; do
    while /usr/bin/security delete-internet-password \
        -s "$key" -a "$USER_NAME" -r 'smb ' >/dev/null 2>&1; do :; done
    /usr/bin/security add-internet-password \
        -a "$USER_NAME" -s "$key" -r 'smb ' -p "$SHARE" -D 'Network Password' \
        -w "$PASSWORD" -U \
        -T /System/Library/CoreServices/NetAuthAgent.app \
        -T /usr/bin/security -T /sbin/mount_smbfs -T group://NetAuth \
        && echo "  saved: $key"
done

unset PASSWORD ENC
echo "Done. Next mount cycle will pick it up (or run mount_smb_shares.sh now)."
