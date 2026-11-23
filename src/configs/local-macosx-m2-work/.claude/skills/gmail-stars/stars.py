#!/usr/bin/env python3
"""Turn starred Gmail messages into daybook To Do items.

Lists every starred message (Gmail API, ``is:starred``), drops the ones already
recorded in the state file, and appends the rest as unchecked items to the
"# To Do ✅" section of today's Joplin daybook note.

trello-daybook-sync.sh runs this just before sync.py, so phase 1b turns the new
items into Trello Today cards in the same run.

Read-only on Gmail: the script only lists and reads message headers. It never
changes stars, labels or messages.

Credentials come from the google-docs MCP login, which already carries a Gmail
scope. The refresh token is exchanged for a short-lived access token on each
run; neither token is written anywhere or printed.

Required env vars:
  GOOGLE_CLIENT_SECRET  OAuth client secret for the google-docs MCP client
  JOPLIN_TOKEN          read by trello-daybook-sync/sync.py at import time

Optional env vars:
  GOOGLE_CLIENT_ID          overrides the client_id in the token file
  GMAIL_TOKEN_FILE          default ~/.config/google-docs-mcp/token.json
  GMAIL_STARS_STATE_FILE    default ~/.claude/routines/state/gmail-stars.json
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
from typing import Any

import requests

# eyes.py owns the "today's note" and "append to To Do" logic (and imports
# sync.py's Joplin client in turn). Both skills install side by side under
# ~/.claude/skills/.
EYES_SKILL_DIR = os.path.expanduser("~/.claude/skills/slack-eyes")
if EYES_SKILL_DIR not in sys.path:
    sys.path.insert(0, EYES_SKILL_DIR)

try:
    from eyes import (  # noqa: E402
        JOPLIN_TOKEN,
        append_todo_items,
        ensure_today_note,
        joplin_put,
        merge_seen,
    )
except ImportError as exc:  # pragma: no cover - install-time misconfiguration
    print(
        json.dumps(
            {"status": "error", "error": f"cannot import {EYES_SKILL_DIR}/eyes.py: {exc}"}
        )
    )
    raise SystemExit(1)

# -- Constants --

GMAIL_API = "https://gmail.googleapis.com/gmail/v1/users/me"
TOKEN_URL = "https://oauth2.googleapis.com/token"
GMAIL_WEB = "https://mail.google.com/mail/u/0/#all"

TOKEN_FILE = os.path.expanduser(
    os.getenv("GMAIL_TOKEN_FILE", "~/.config/google-docs-mcp/token.json")
)
STATE_FILE = os.path.expanduser(
    os.getenv("GMAIL_STARS_STATE_FILE", "~/.claude/routines/state/gmail-stars.json")
)

STAR_MARK = "⭐"
# messages.list pages at up to 500; 10 pages of 100 is far more than a daily
# run needs and stops a runaway loop.
MAX_PAGES = 10
PAGE_SIZE = 100
# Must stay above MAX_PAGES * PAGE_SIZE: currently starred IDs are kept first,
# so the cap can only ever evict IDs that are no longer starred.
STATE_KEEP = 2000
SUMMARY_LIMIT = 90

# Gmail IDs are lowercase hex. Validating them keeps API paths and the web link
# free of anything the API did not promise.
GMAIL_ID_RE = re.compile(r"^[0-9a-f]{1,32}$")
# Subjects and sender names are written by whoever sent the email. Strip
# anything that could act as markup in the daybook note: angle brackets (an
# HTML comment such as <!-- trello:ID --> would be read by sync.py as a card
# marker), square brackets and backticks (markdown links and code), and
# leading list or checkbox markup.
UNSAFE_CHARS_RE = re.compile(r"[<>\[\]`|]")
WHITESPACE_RE = re.compile(r"\s+")
LEADING_MARKUP_RE = re.compile(r"^(?:[-*+#>]+\s*)+")
TOKEN_PARAM_RE = re.compile(r"((?:token|key)=)[^&\s\"']+")
SENDER_NAME_RE = re.compile(r'^\s*"?([^"<]*?)"?\s*<[^>]*>\s*$')


class GmailError(RuntimeError):
    """A Gmail or Google OAuth call failed."""


# -- Google auth --


def load_credentials() -> dict[str, str]:
    """Client ID, client secret and refresh token, from the file and the env."""
    with open(TOKEN_FILE, encoding="utf-8") as handle:
        saved = json.load(handle)
    return {
        "client_id": os.getenv("GOOGLE_CLIENT_ID", "").strip() or saved.get("client_id", ""),
        "client_secret": os.getenv("GOOGLE_CLIENT_SECRET", "").strip()
        or saved.get("client_secret", ""),
        "refresh_token": saved.get("refresh_token", ""),
    }


def access_token(creds: dict[str, str]) -> str:
    """Exchange the refresh token for a short-lived access token.

    The tokens travel in the POST body, never in the URL, so a requests
    exception message cannot leak them into the log.
    """
    resp = requests.post(
        TOKEN_URL, data={**creds, "grant_type": "refresh_token"}, timeout=30
    )
    if resp.status_code != 200:
        # Report only Google's error code — the body can echo request fields.
        error = resp.json().get("error", "unknown") if resp.content else "empty"
        raise GmailError(f"token refresh failed: HTTP {resp.status_code} {error}")
    return resp.json()["access_token"]


# -- Gmail API --


def gmail_get(token: str, path: str, **params: Any) -> dict[str, Any]:
    resp = requests.get(
        f"{GMAIL_API}/{path}",
        headers={"Authorization": f"Bearer {token}"},
        params=params,
        timeout=30,
    )
    if resp.status_code != 200:
        message = (resp.json().get("error") or {}).get("status", "") if resp.content else ""
        raise GmailError(f"{path}: HTTP {resp.status_code} {message}".strip())
    return resp.json()


def list_starred_ids(token: str) -> list[str]:
    """IDs of every starred message, newest first."""
    ids: list[str] = []
    page_token = ""
    for _ in range(MAX_PAGES):
        params: dict[str, Any] = {"q": "is:starred", "maxResults": PAGE_SIZE}
        if page_token:
            params["pageToken"] = page_token
        data = gmail_get(token, "messages", **params)
        ids.extend(
            m["id"] for m in data.get("messages", []) if GMAIL_ID_RE.match(m.get("id", ""))
        )
        page_token = data.get("nextPageToken", "")
        if not page_token:
            break
    return ids


def fetch_message(token: str, message_id: str) -> dict[str, Any]:
    """Subject, sender name, thread ID and received time of one message."""
    data = gmail_get(
        token,
        f"messages/{message_id}",
        format="metadata",
        metadataHeaders=["Subject", "From"],
    )
    headers = {
        h.get("name", "").lower(): h.get("value", "")
        for h in (data.get("payload") or {}).get("headers", [])
    }
    thread_id = data.get("threadId", "")
    return {
        "id": message_id,
        "thread_id": thread_id if GMAIL_ID_RE.match(thread_id) else message_id,
        "subject": headers.get("subject", ""),
        "sender": headers.get("from", ""),
        "received": int(data.get("internalDate", "0")) / 1000,
    }


# -- Formatting --


def clean(text: str, limit: int) -> str:
    """One line of plain text with no markup, cut to ``limit`` characters."""
    text = UNSAFE_CHARS_RE.sub("", text)
    text = WHITESPACE_RE.sub(" ", text).strip()
    text = LEADING_MARKUP_RE.sub("", text).strip()
    if len(text) > limit:
        text = text[: limit - 1].rstrip() + "…"
    return text


def sender_name(header: str) -> str:
    """Display name from a From header; never the address itself."""
    match = SENDER_NAME_RE.match(header)
    if match and match.group(1).strip():
        return clean(match.group(1), 40).strip('"')
    # A bare address or an odd header: keep only the part before the @.
    return clean(header.split("@")[0], 40).strip('"')


def todo_line(message: dict[str, Any]) -> str:
    """Render one To Do item: subject first, sender and link after."""
    subject = clean(message["subject"], SUMMARY_LIMIT) or "(no subject)"
    sender = sender_name(message["sender"]) or "email"
    link = f"{GMAIL_WEB}/{message['thread_id']}"
    return f"- [ ] {STAR_MARK} {subject} ([{sender}]({link}))"


# -- State --


def load_seen() -> list[str]:
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            return list(json.load(handle).get("seen", []))
    except FileNotFoundError:
        return []
    except (OSError, json.JSONDecodeError, AttributeError):
        # A corrupt state file must not wedge the routine. Treat it like a
        # first run, so the age window stops a flood of old stars.
        return []


def save_seen(seen: list[str]) -> None:
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w", encoding="utf-8") as handle:
        json.dump({"seen": seen[:STATE_KEEP]}, handle, indent=2)


# -- Main --


def select_fresh(
    messages: list[dict[str, Any]], since_days: int | None
) -> list[dict[str, Any]]:
    """Messages to add, oldest first, optionally limited by age.

    Gmail does not record when a message was starred, so the window uses the
    received time. It applies only on the first run, so that run does not
    import every star you have ever set.
    """
    cutoff = time.time() - since_days * 86400 if since_days is not None else 0.0
    fresh = [m for m in messages if m["received"] >= cutoff]
    fresh.sort(key=lambda m: m["received"])
    return fresh


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--since-days",
        type=int,
        default=7,
        help="on a first run, skip stars on mail older than this (default: 7)",
    )
    parser.add_argument(
        "--all", action="store_true", help="no age window on a first run"
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the To Do lines without touching Joplin or the state file",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if not JOPLIN_TOKEN:
        print(json.dumps({"status": "error", "error": "missing env: JOPLIN_TOKEN"}))
        return 1
    creds = load_credentials()
    missing = [name for name, value in creds.items() if not value]
    if missing:
        print(json.dumps({"status": "error", "error": f"missing credentials: {missing}"}))
        return 1

    token = access_token(creds)
    seen = load_seen()
    starred = list_starred_ids(token)
    known = set(seen)
    messages = [fetch_message(token, i) for i in starred if i not in known]

    since_days = None if args.all or seen else args.since_days
    lines = [todo_line(m) for m in select_fresh(messages, since_days)]

    result: dict[str, Any] = {
        "status": "ok",
        "starred_total": len(starred),
        "new": len(lines),
        "dry_run": args.dry_run,
    }
    if args.dry_run:
        result["lines"] = lines
        print(json.dumps(result, indent=2, ensure_ascii=False))
        return 0

    if lines:
        note_id, body = ensure_today_note()
        joplin_put(f"/notes/{note_id}", {"body": append_todo_items(body, lines)})
        result["note_id"] = note_id

    # Record every star seen this run, including ones the age window skipped.
    save_seen(merge_seen(starred, seen))
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (GmailError, requests.RequestException, OSError, KeyError, ValueError) as exc:
        # The Joplin calls put the Joplin token in the URL, and requests copies
        # the URL into its exception text. Redact every error before printing.
        error = TOKEN_PARAM_RE.sub(r"\1REDACTED", f"{type(exc).__name__}: {exc}")
        print(json.dumps({"status": "error", "error": error}))
        sys.exit(1)
