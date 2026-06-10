#!/usr/bin/env python3
from __future__ import annotations

"""Bidirectional sync between Trello Today list and Joplin daybook.

Phase 1 (Joplin -> Trello): Moves checked items to Done in Trello.
Phase 2 (Trello -> Joplin): Pulls current Today cards into the daybook.

Required env vars:
  TRELLO_API_KEY, TRELLO_TOKEN, JOPLIN_TOKEN

Optional env vars:
  JOPLIN_BASE_URL  (default: http://127.0.0.1:41184)
"""

import datetime as dt
import json
import os
import re
import sys
from typing import Any

import requests

# -- Constants --

JOPLIN_BASE_URL = os.getenv("JOPLIN_BASE_URL", "http://127.0.0.1:41184").rstrip("/")
JOPLIN_TOKEN = os.getenv("JOPLIN_TOKEN", "").strip()
TRELLO_API_KEY = os.getenv("TRELLO_API_KEY", "").strip()
TRELLO_TOKEN = os.getenv("TRELLO_TOKEN", "").strip()

DAYBOOK_NOTEBOOK_ID = "c8ed0dc13a1f4269a66fe7d0d53ea07e"
TODAY_LIST_ID = "637bc2f8722fe72795105471"
DONE_LIST_ID = "637bc2c4c1b37201db9e5b16"

TRELLO_MARKER_RE = re.compile(r"<!--\s*trello:(\w+)\s*-->")
CHECKED_TRELLO_RE = re.compile(
    r"^- \[x\]\s+(.+?)\s*<!--\s*trello:(\w+)\s*-->$"
)
UNCHECKED_TRELLO_RE = re.compile(
    r"^- \[ \]\s+(.+?)\s*<!--\s*trello:(\w+)\s*-->$"
)
TODO_HEADING_RE = re.compile(r"^#{1,2}\s+To\s*Do")
SECTION_HEADING_RE = re.compile(r"^#{1,2}\s+\S")


# -- Joplin API helpers --


def joplin_get(path: str, **params: Any) -> Any:
    params["token"] = JOPLIN_TOKEN
    resp = requests.get(f"{JOPLIN_BASE_URL}{path}", params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def joplin_put(path: str, payload: dict[str, Any]) -> Any:
    resp = requests.put(
        f"{JOPLIN_BASE_URL}{path}",
        params={"token": JOPLIN_TOKEN},
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def joplin_post(path: str, payload: dict[str, Any]) -> Any:
    resp = requests.post(
        f"{JOPLIN_BASE_URL}{path}",
        params={"token": JOPLIN_TOKEN},
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


# -- Trello API helpers --


def trello_get(path: str, **params: Any) -> Any:
    params["key"] = TRELLO_API_KEY
    params["token"] = TRELLO_TOKEN
    resp = requests.get(
        f"https://api.trello.com/1{path}", params=params, timeout=30
    )
    resp.raise_for_status()
    return resp.json()


def trello_put(path: str, **params: Any) -> bool:
    """Returns True on success."""
    params["key"] = TRELLO_API_KEY
    params["token"] = TRELLO_TOKEN
    resp = requests.put(
        f"https://api.trello.com/1{path}", params=params, timeout=30
    )
    return resp.status_code == 200


# -- Joplin daybook helpers --


def find_daybook_note(title: str) -> dict[str, Any] | None:
    """Search for a daybook note by exact title."""
    results = joplin_get(
        "/search",
        query=title,
        fields="id,title,parent_id",
        limit=20,
    )
    for note in results.get("items", []):
        if note.get("title") == title and note.get("parent_id") == DAYBOOK_NOTEBOOK_ID:
            return note
    return None


def get_note_body(note_id: str) -> str:
    note = joplin_get(f"/notes/{note_id}", fields="id,body")
    return note.get("body", "")


def get_recent_daybook_note() -> dict[str, Any] | None:
    """Get the most recent note in the daybook notebook."""
    result = joplin_get(
        f"/folders/{DAYBOOK_NOTEBOOK_ID}/notes",
        fields="id,title,body",
        order_by="updated_time",
        order_dir="DESC",
        limit=1,
    )
    items = result.get("items", [])
    return items[0] if items else None


def today_title() -> str:
    """Format today's date as 'DD Mon, YYYY'."""
    now = dt.datetime.now()
    return now.strftime("%-d %b, %Y")


# -- Parsing --


def parse_todo_section(body: str) -> tuple[str, list[str], str]:
    """Split body into (before_todo, todo_lines, after_todo).

    Returns the raw lines within the ## To Do section, plus the text
    before and after it.
    """
    lines = body.split("\n")
    todo_start = None
    todo_end = None

    for i, line in enumerate(lines):
        if TODO_HEADING_RE.match(line.strip()):
            todo_start = i
            continue
        if todo_start is not None and SECTION_HEADING_RE.match(line.strip()) and i > todo_start:
            todo_end = i
            break

    if todo_start is None:
        return body, [], ""

    if todo_end is None:
        todo_end = len(lines)

    before = "\n".join(lines[: todo_start])
    todo_lines = lines[todo_start + 1 : todo_end]
    after = "\n".join(lines[todo_end:])

    return before, todo_lines, after


def extract_checked_trello_items(todo_lines: list[str]) -> list[tuple[str, str]]:
    """Return list of (card_name, card_id) for checked trello-marked items."""
    results = []
    for line in todo_lines:
        m = CHECKED_TRELLO_RE.match(line.strip())
        if m:
            results.append((m.group(1).strip(), m.group(2)))
    return results


# -- Phase 1: Push completions to Trello --


def phase1_push_completions(body: str) -> tuple[str, dict[str, Any]]:
    """Move checked trello items to Done. Returns (updated_body, stats)."""
    stats: dict[str, Any] = {"moved": 0, "failed": []}

    before, todo_lines, after = parse_todo_section(body)
    if not todo_lines:
        return body, stats

    checked = extract_checked_trello_items(todo_lines)
    if not checked:
        return body, stats

    moved_ids: set[str] = set()
    for card_name, card_id in checked:
        ok = trello_put(f"/cards/{card_id}", idList=DONE_LIST_ID)
        if ok:
            moved_ids.add(card_id)
            stats["moved"] += 1
        else:
            stats["failed"].append({"name": card_name, "id": card_id})

    # Strip trello markers from successfully moved items
    new_todo_lines = []
    for line in todo_lines:
        m = CHECKED_TRELLO_RE.match(line.strip())
        if m and m.group(2) in moved_ids:
            # Remove the marker, keep the checked item
            card_name = m.group(1).strip()
            new_todo_lines.append(f"- [x] {card_name}")
        else:
            new_todo_lines.append(line)

    updated_body = before + "\n# To Do ✅\n" + "\n".join(new_todo_lines) + "\n" + after
    return updated_body, stats


# -- Phase 0: Flush completions from prior notes --


def flush_prior_completions(exclude_note_id: str | None = None) -> dict[str, Any]:
    """Move checked trello items from recent prior notes to Done in Trello.

    Scans up to 5 recent daybook notes (excluding the given note ID) for
    checked items with trello markers that were never pushed to Trello Done.
    Moves matched cards and strips markers from the source notes.
    """
    stats: dict[str, Any] = {"moved": 0, "failed": [], "notes_cleaned": 0}

    result = joplin_get(
        f"/folders/{DAYBOOK_NOTEBOOK_ID}/notes",
        fields="id,title",
        order_by="updated_time",
        order_dir="DESC",
        limit=6,
    )

    for note_info in result.get("items", []):
        note_id = note_info["id"]
        if note_id == exclude_note_id:
            continue

        body = get_note_body(note_id)
        updated_body, note_stats = phase1_push_completions(body)

        if note_stats["moved"] > 0:
            joplin_put(f"/notes/{note_id}", {"body": updated_body})
            stats["notes_cleaned"] += 1

        stats["moved"] += note_stats["moved"]
        stats["failed"].extend(note_stats["failed"])

    return stats


# -- Phase 2: Pull Today list into Joplin --


def fetch_today_cards() -> list[dict[str, str]]:
    """Fetch cards from the Trello Today list."""
    cards = trello_get(
        f"/lists/{TODAY_LIST_ID}/cards",
        fields="name,due,labels,idShort,id",
    )
    return cards or []


def merge_todo_section(
    todo_lines: list[str], trello_cards: list[dict[str, str]]
) -> tuple[list[str], dict[str, int]]:
    """Merge Trello cards into existing todo lines.

    Returns (merged_lines, stats).
    """
    stats = {"added": 0, "kept": 0, "removed": 0, "checked_preserved": 0}

    # Build a set of current Trello card IDs
    trello_ids = {card["id"] for card in trello_cards}

    # Parse existing lines into categories
    existing_trello_ids: set[str] = set()
    manual_lines: list[str] = []
    checked_lines: list[str] = []
    unchecked_trello_lines: dict[str, str] = {}  # card_id -> line

    for line in todo_lines:
        stripped = line.strip()
        if not stripped or SECTION_HEADING_RE.match(stripped):
            continue

        checked_m = CHECKED_TRELLO_RE.match(stripped)
        unchecked_m = UNCHECKED_TRELLO_RE.match(stripped)

        if checked_m:
            # Checked trello item (marker already stripped by phase 1 if moved,
            # so these are items checked but not yet synced, or manually checked
            # items that weren't in a previous sync run)
            card_id = checked_m.group(2)
            existing_trello_ids.add(card_id)
            checked_lines.append(line)
            stats["checked_preserved"] += 1
        elif unchecked_m:
            card_id = unchecked_m.group(2)
            existing_trello_ids.add(card_id)
            if card_id in trello_ids:
                unchecked_trello_lines[card_id] = line
                stats["kept"] += 1
            else:
                stats["removed"] += 1
        elif stripped.startswith("- [x]"):
            # Checked manual item (no trello marker)
            checked_lines.append(line)
            stats["checked_preserved"] += 1
        elif stripped.startswith("- [") or stripped.startswith("- "):
            # Manual unchecked item
            manual_lines.append(line)
            stats["kept"] += 1

    # Build merged output
    merged: list[str] = []

    # Add new trello cards and existing unchecked trello items (in Trello order)
    for card in trello_cards:
        card_id = card["id"]
        if card_id in unchecked_trello_lines:
            merged.append(unchecked_trello_lines[card_id])
        elif card_id not in existing_trello_ids:
            merged.append(f"- [ ] {card['name']} <!-- trello:{card_id} -->")
            stats["added"] += 1

    # Add manual unchecked items
    merged.extend(manual_lines)

    # Add all checked items at the bottom
    merged.extend(checked_lines)

    return merged, stats


def phase2_pull_today(body: str) -> tuple[str, dict[str, int]]:
    """Pull Trello Today cards into the daybook. Returns (updated_body, stats)."""
    cards = fetch_today_cards()

    before, todo_lines, after = parse_todo_section(body)

    merged_lines, stats = merge_todo_section(todo_lines, cards)

    # Rebuild body
    todo_section = "# To Do ✅\n\n" + "\n".join(merged_lines) if merged_lines else "# To Do ✅\n"

    # Ensure Worklog section exists
    if "# Worklog" not in after and "# Worklog" not in before:
        after = "\n# Worklog 📝\n\n" + after.lstrip("\n")

    parts = []
    if before.strip():
        parts.append(before.rstrip("\n"))
    parts.append(todo_section)
    if after.strip():
        parts.append(after.lstrip("\n"))
    else:
        parts.append("# Worklog 📝\n")

    updated_body = "\n\n".join(parts) + "\n"
    return updated_body, stats


# -- Carry forward incomplete items from the most recent daybook entry --


def carry_forward_items() -> list[str]:
    """Get incomplete to-do items from the most recent daybook note."""
    recent = get_recent_daybook_note()
    if not recent:
        return []

    body = recent.get("body", "")
    if not body:
        # Fetch the full body
        body = get_note_body(recent["id"])

    _, todo_lines, _ = parse_todo_section(body)
    carried: list[str] = []
    for line in todo_lines:
        stripped = line.strip()
        if stripped.startswith("- [ ]"):
            carried.append(stripped)
    return carried


# -- Main --


def main() -> int:
    # Validate env
    missing = []
    if not JOPLIN_TOKEN:
        missing.append("JOPLIN_TOKEN")
    if not TRELLO_API_KEY:
        missing.append("TRELLO_API_KEY")
    if not TRELLO_TOKEN:
        missing.append("TRELLO_TOKEN")
    if missing:
        print(
            json.dumps(
                {"status": "error", "error": f"Missing env vars: {', '.join(missing)}"}
            )
        )
        return 1

    title = today_title()
    note = find_daybook_note(title)

    phase1_stats: dict[str, Any] = {"moved": 0, "failed": []}
    created = False

    if note:
        body = get_note_body(note["id"])
        note_id = note["id"]
    else:
        # Create new note, carry forward incomplete items
        carried = carry_forward_items()
        todo_block = "\n".join(carried) if carried else ""
        body = f"# To Do ✅\n\n{todo_block}\n\n# Worklog 📝\n\n"
        result = joplin_post(
            "/notes",
            {"title": title, "parent_id": DAYBOOK_NOTEBOOK_ID, "body": body},
        )
        note_id = result["id"]
        created = True

    # Phase 0: flush completions from prior notes to Trello
    flush_stats = flush_prior_completions(exclude_note_id=note_id)

    # Phase 1: push completions from today's note
    if not created:
        body, phase1_stats = phase1_push_completions(body)
        if phase1_stats["moved"] > 0:
            joplin_put(f"/notes/{note_id}", {"body": body})

    # Phase 2: pull today list
    body, phase2_stats = phase2_pull_today(body)
    joplin_put(f"/notes/{note_id}", {"body": body})

    # Report
    output = {
        "status": "ok",
        "title": title,
        "note_id": note_id,
        "created": created,
        "phase0_prior_flush": flush_stats,
        "phase1": phase1_stats,
        "phase2": phase2_stats,
    }
    print(json.dumps(output, indent=2))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except requests.RequestException as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        sys.exit(1)
    except Exception as exc:
        print(json.dumps({"status": "error", "error": str(exc)}))
        sys.exit(1)
