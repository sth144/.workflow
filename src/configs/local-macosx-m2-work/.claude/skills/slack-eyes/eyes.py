#!/usr/bin/env python3
"""Turn Slack :eyes: reactions into daybook To Do items.

Lists every message the authenticated Slack user has reacted to with 👀
(``reactions.list``, user token, ``reactions:read`` scope), drops the ones
already recorded in the state file, and appends the rest as unchecked items to
the "# To Do ✅" section of today's Joplin daybook note.

Trello is deliberately absent here: ``trello-daybook-sync``'s phase 1b already
promotes unchecked ``- [ ]`` lines without a trello marker into Today cards on
its next run, so 👀 items reach Trello for free.

Required env vars:
  SLACK_USER_TOKEN  xoxp-... token carrying the reactions:read user scope
  JOPLIN_TOKEN      read by trello-daybook-sync/sync.py at import time

Optional env vars:
  JOPLIN_BASE_URL        default http://127.0.0.1:41184 (via sync.py)
  SLACK_EYES_STATE_FILE  default ~/.claude/routines/state/slack-eyes.json
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

# sync.py owns the Joplin client, the daybook notebook ID and the To Do section
# parser. Import rather than duplicate — both skills install side by side under
# ~/.claude/skills/, and sync.py guards its entrypoint with __main__.
SYNC_SKILL_DIR = os.path.expanduser("~/.claude/skills/trello-daybook-sync")
if SYNC_SKILL_DIR not in sys.path:
    sys.path.insert(0, SYNC_SKILL_DIR)

try:
    from sync import (  # noqa: E402
        DAYBOOK_NOTEBOOK_ID,
        JOPLIN_TOKEN,
        find_daybook_note,
        get_note_body,
        joplin_post,
        joplin_put,
        parse_todo_section,
        today_title,
    )
except ImportError as exc:  # pragma: no cover - install-time misconfiguration
    print(
        json.dumps(
            {
                "status": "error",
                "error": f"cannot import {SYNC_SKILL_DIR}/sync.py: {exc}",
            }
        )
    )
    raise SystemExit(1)

# -- Constants --

SLACK_API = "https://slack.com/api"
SLACK_USER_TOKEN = os.getenv("SLACK_USER_TOKEN", "").strip()

EYES_EMOJI = "eyes"
EYES_MARK = "👀"

DEFAULT_STATE_FILE = "~/.claude/routines/state/slack-eyes.json"
STATE_FILE = os.path.expanduser(
    os.getenv("SLACK_EYES_STATE_FILE", DEFAULT_STATE_FILE)
)

# reactions.list pages at 100; 20 pages is far more history than a daily run
# needs and stops a pathological account from looping forever.
MAX_PAGES = 20
STATE_KEEP = 500
SUMMARY_LIMIT = 90

LABELLED_LINK_RE = re.compile(r"<([^|>]+)\|([^>]+)>")
BARE_LINK_RE = re.compile(r"<([^>]+)>")
WHITESPACE_RE = re.compile(r"\s+")
# A message that itself starts with list or checkbox markup would fight the
# checkbox markup of the To Do line it gets embedded in.
LEADING_MARKUP_RE = re.compile(r"^(?:[-*+]\s+)?(?:\[[ xX]\]\s*)?")


class SlackError(RuntimeError):
    """A Slack API call returned ok=false."""


# -- Slack API --


def slack_get(method: str, **params: Any) -> dict[str, Any]:
    resp = requests.get(
        f"{SLACK_API}/{method}",
        headers={"Authorization": f"Bearer {SLACK_USER_TOKEN}"},
        params=params,
        timeout=30,
    )
    resp.raise_for_status()
    data = resp.json()
    if not data.get("ok"):
        raise SlackError(f"{method}: {data.get('error', 'unknown_error')}")
    return data


def extract_eyed(item: dict[str, Any], user_id: str) -> dict[str, Any] | None:
    """Return message metadata if this user put 👀 on it, else None.

    reactions.list returns everything the user reacted to with any emoji, and
    each message carries the reactions of *all* users — so both the emoji name
    and our own user ID have to match.
    """
    if item.get("type") != "message":
        return None

    message = item.get("message") or {}
    channel = item.get("channel")
    ts = message.get("ts")
    if not channel or not ts:
        return None

    for reaction in message.get("reactions") or []:
        if reaction.get("name") != EYES_EMOJI:
            continue
        if user_id not in (reaction.get("users") or []):
            continue
        return {
            "key": f"{channel}:{ts}",
            "channel": channel,
            "ts": ts,
            "text": message.get("text") or "",
            "permalink": message.get("permalink") or "",
        }
    return None


def fetch_eyed_messages(user_id: str) -> list[dict[str, Any]]:
    """Every 👀'd message, newest first."""
    found: list[dict[str, Any]] = []
    cursor = ""
    for _ in range(MAX_PAGES):
        params: dict[str, Any] = {"limit": 100, "full": "true"}
        if cursor:
            params["cursor"] = cursor
        data = slack_get("reactions.list", **params)

        for item in data.get("items", []):
            message = extract_eyed(item, user_id)
            if message:
                found.append(message)

        cursor = (data.get("response_metadata") or {}).get("next_cursor") or ""
        if not cursor:
            break
    return found


def channel_label(channel_id: str, cache: dict[str, str]) -> str:
    """Human label for a channel, falling back to the raw ID."""
    if channel_id in cache:
        return cache[channel_id]

    label = channel_id
    try:
        channel = slack_get("conversations.info", channel=channel_id).get(
            "channel", {}
        )
        if channel.get("is_im"):
            label = "DM"
        elif channel.get("name"):
            label = f"#{channel['name']}"
    except (SlackError, requests.RequestException):
        # Private channel or group DM the token can't see — the ID still
        # identifies it well enough to be useful in the To Do line.
        pass

    cache[channel_id] = label
    return label


def permalink_for(message: dict[str, Any], team_url: str) -> str:
    """Prefer Slack's own permalink; otherwise build the archives URL."""
    if message.get("permalink"):
        return message["permalink"]
    if not team_url:
        return ""
    ts = message["ts"].replace(".", "")
    return f"{team_url.rstrip('/')}/archives/{message['channel']}/p{ts}"


# -- Formatting --


def summarize(text: str) -> str:
    """Flatten Slack message text into one short plain-text line."""
    text = LABELLED_LINK_RE.sub(r"\2", text)
    text = BARE_LINK_RE.sub(r"\1", text)
    text = WHITESPACE_RE.sub(" ", text).strip()
    text = LEADING_MARKUP_RE.sub("", text).strip()
    if not text:
        return "(no text)"
    if len(text) > SUMMARY_LIMIT:
        text = text[: SUMMARY_LIMIT - 1].rstrip() + "…"
    return text


def todo_line(message: dict[str, Any], label: str, permalink: str) -> str:
    """Render one To Do item.

    The summary leads so the Trello card name phase 1b derives from this line
    stays readable; the link trails as markdown so Joplin renders it clean.
    """
    summary = summarize(message["text"])
    if permalink:
        return f"- [ ] {EYES_MARK} {summary} ([{label}]({permalink}))"
    return f"- [ ] {EYES_MARK} {summary} ({label})"


# -- State --


def load_state() -> dict[str, Any]:
    try:
        with open(STATE_FILE, encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        return {}
    except (OSError, json.JSONDecodeError):
        # A corrupt state file must not wedge the routine; worst case is one
        # duplicate To Do item.
        return {}


def merge_seen(new_keys: list[str], seen: list[str]) -> list[str]:
    """Newest-first key list, de-duplicated.

    Without the de-dupe every run re-prepends the keys it just saw, so the list
    fills with duplicates and the STATE_KEEP cap starts evicting *distinct*
    keys — which would make old 👀 items reappear as new To Do lines.
    """
    merged: list[str] = []
    known: set[str] = set()
    for key in new_keys + seen:
        if key in known:
            continue
        known.add(key)
        merged.append(key)
    return merged


def save_state(seen: list[str]) -> None:
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    payload = {"seen": seen[:STATE_KEEP]}
    with open(STATE_FILE, "w", encoding="utf-8") as handle:
        json.dump(payload, handle, indent=2)


# -- Joplin --


def ensure_today_note() -> tuple[str, str]:
    """Return (note_id, body) for today's daybook note, creating it if absent.

    trello-daybook-sync normally creates it at 07:00; this only fires when that
    run was skipped or failed. Carrying items forward is that script's job, so
    the fallback note is deliberately empty.
    """
    title = today_title()
    note = find_daybook_note(title)
    if note:
        return note["id"], get_note_body(note["id"])

    body = "# To Do ✅\n\n\n# Worklog 📝\n\n"
    created = joplin_post(
        "/notes",
        {"title": title, "parent_id": DAYBOOK_NOTEBOOK_ID, "body": body},
    )
    return created["id"], body


def append_todo_items(body: str, lines: list[str]) -> str:
    """Append lines to the end of the To Do section, preserving everything else."""
    before, todo_lines, after = parse_todo_section(body)

    if not todo_lines and not before.strip() and not after.strip():
        # No recognisable To Do heading — prepend a section rather than guess.
        return "# To Do ✅\n\n" + "\n".join(lines) + "\n\n" + body.lstrip("\n")

    kept = [line for line in todo_lines if line.strip()]
    section = "# To Do ✅\n\n" + "\n".join(kept + lines)

    parts = []
    if before.strip():
        parts.append(before.rstrip("\n"))
    parts.append(section)
    if after.strip():
        parts.append(after.lstrip("\n"))
    return "\n\n".join(parts) + "\n"


# -- Main --


def select_fresh(
    messages: list[dict[str, Any]], seen: set[str], since_days: int | None
) -> list[dict[str, Any]]:
    """Unseen 👀 items, oldest first, optionally windowed by age.

    The window exists for the very first run: without it, a brand-new state
    file would dump every 👀 you have ever placed into today's To Do list.
    """
    cutoff = 0.0
    if since_days is not None:
        cutoff = time.time() - since_days * 86400

    fresh = []
    for message in messages:
        if message["key"] in seen:
            continue
        if cutoff and float(message["ts"]) < cutoff:
            continue
        fresh.append(message)
    fresh.reverse()
    return fresh


def build_lines(
    fresh: list[dict[str, Any]], team_url: str
) -> list[str]:
    cache: dict[str, str] = {}
    return [
        todo_line(m, channel_label(m["channel"], cache), permalink_for(m, team_url))
        for m in fresh
    ]


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--since-days",
        type=int,
        default=7,
        help="ignore 👀 items older than this on a first run (default: 7)",
    )
    parser.add_argument(
        "--all",
        action="store_true",
        help="no age window — pick up every unseen 👀 item",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="print the To Do lines without touching Joplin or the state file",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    missing = [
        name
        for name, value in (
            ("SLACK_USER_TOKEN", SLACK_USER_TOKEN),
            ("JOPLIN_TOKEN", JOPLIN_TOKEN),
        )
        if not value
    ]
    if missing:
        print(json.dumps({"status": "error", "error": f"missing env: {missing}"}))
        return 1

    auth = slack_get("auth.test")
    state = load_state()
    seen: list[str] = state.get("seen", [])

    messages = fetch_eyed_messages(auth["user_id"])
    since_days = None if args.all else args.since_days
    # An existing state file already bounds the work, so the age window only
    # applies to the first ever run.
    fresh = select_fresh(messages, set(seen), since_days if not seen else None)
    lines = build_lines(fresh, auth.get("url", ""))

    result = {
        "status": "ok",
        "eyed_total": len(messages),
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

    # Record every 👀 seen this run, including ones the age window skipped, so
    # the window never has to be reapplied.
    save_state(merge_seen([m["key"] for m in messages], seen))
    print(json.dumps(result, indent=2, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except SlackError as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        sys.exit(1)
    except requests.RequestException as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        sys.exit(1)
