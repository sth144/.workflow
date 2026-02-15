#!/usr/bin/env python3
import datetime as dt
import json
import os
import sys
from dataclasses import dataclass
from typing import Any

import requests
from google.oauth2 import service_account
from googleapiclient.discovery import build


@dataclass
class Config:
    joplin_token: str
    joplin_base_url: str
    joplin_notebook: str
    trello_key: str | None
    trello_token: str | None
    google_calendar_id: str | None
    google_service_account_file: str | None
    timezone: str
    ha_base_url: str | None
    ha_token: str | None
    ha_entities: list[str]


def load_config() -> Config:
    entities_csv = os.getenv("HA_ENTITIES", "").strip()
    entities = [x.strip() for x in entities_csv.split(",") if x.strip()]
    return Config(
        joplin_token=must_env("JOPLIN_TOKEN"),
        joplin_base_url=os.getenv("JOPLIN_BASE_URL", "http://joplin:41184"),
        joplin_notebook=os.getenv("JOPLIN_NOTEBOOK", "Areas/Journal/"),
        trello_key=os.getenv("TRELLO_KEY"),
        trello_token=os.getenv("TRELLO_TOKEN"),
        google_calendar_id=os.getenv("GOOGLE_CALENDAR_ID"),
        google_service_account_file=os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE"),
        timezone=os.getenv("TIMEZONE", "UTC"),
        ha_base_url=os.getenv("HA_BASE_URL"),
        ha_token=os.getenv("HA_TOKEN"),
        ha_entities=entities,
    )


def must_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required env var: {name}")
    return value


def joplin_get(cfg: Config, path: str, **params: Any) -> dict[str, Any]:
    params["token"] = cfg.joplin_token
    resp = requests.get(f"{cfg.joplin_base_url}{path}", params=params, timeout=20)
    resp.raise_for_status()
    return resp.json()


def joplin_post(cfg: Config, path: str, payload: dict[str, Any]) -> dict[str, Any]:
    params = {"token": cfg.joplin_token}
    resp = requests.post(
        f"{cfg.joplin_base_url}{path}",
        params=params,
        json=payload,
        timeout=20,
    )
    resp.raise_for_status()
    return resp.json()


def ensure_notebook(cfg: Config) -> str:
    path_parts = [part for part in cfg.joplin_notebook.strip("/").split("/") if part]
    if not path_parts:
        raise RuntimeError("JOPLIN_NOTEBOOK must not be empty")

    parent_id = ""
    for part in path_parts:
        folders = joplin_get(cfg, "/folders", fields="id,title,parent_id").get("items", [])
        matching = next(
            (
                folder
                for folder in folders
                if folder.get("title") == part and (folder.get("parent_id") or "") == parent_id
            ),
            None,
        )
        if matching:
            parent_id = matching["id"]
            continue
        created = joplin_post(
            cfg,
            "/folders",
            {"title": part, "parent_id": parent_id} if parent_id else {"title": part},
        )
        parent_id = created["id"]

    return parent_id


def find_note_by_title(cfg: Config, folder_id: str, title: str) -> str | None:
    notes = joplin_get(
        cfg, f"/folders/{folder_id}/notes", fields="id,title,parent_id", limit=100
    ).get("items", [])
    for note in notes:
        if note.get("title") == title:
            return note["id"]
    return None


def fetch_trello_open_cards(cfg: Config) -> list[dict[str, str]]:
    if not cfg.trello_key or not cfg.trello_token:
        return []
    resp = requests.get(
        "https://api.trello.com/1/members/me/cards",
        params={
            "key": cfg.trello_key,
            "token": cfg.trello_token,
            "filter": "open",
            "fields": "name,shortUrl,due",
        },
        timeout=20,
    )
    resp.raise_for_status()
    cards = resp.json()
    return [
        {
            "name": card.get("name", "Untitled"),
            "url": card.get("shortUrl", ""),
            "due": card.get("due") or "",
        }
        for card in cards[:20]
    ]


def fetch_google_events(cfg: Config) -> list[dict[str, str]]:
    if not cfg.google_calendar_id or not cfg.google_service_account_file:
        return []
    scopes = ["https://www.googleapis.com/auth/calendar.readonly"]
    credentials = service_account.Credentials.from_service_account_file(
        cfg.google_service_account_file,
        scopes=scopes,
    )
    service = build("calendar", "v3", credentials=credentials, cache_discovery=False)
    now = dt.datetime.now(dt.UTC)
    tomorrow = now + dt.timedelta(days=1)
    events_result = (
        service.events()
        .list(
            calendarId=cfg.google_calendar_id,
            timeMin=now.isoformat(),
            timeMax=tomorrow.isoformat(),
            singleEvents=True,
            orderBy="startTime",
            maxResults=20,
        )
        .execute()
    )
    events = events_result.get("items", [])
    output = []
    for event in events:
        start = event.get("start", {}).get("dateTime") or event.get("start", {}).get(
            "date", ""
        )
        output.append(
            {
                "summary": event.get("summary", "(No title)"),
                "start": start,
                "link": event.get("htmlLink", ""),
            }
        )
    return output


def fetch_home_assistant(cfg: Config) -> list[dict[str, str]]:
    if not cfg.ha_base_url or not cfg.ha_token or not cfg.ha_entities:
        return []
    headers = {"Authorization": f"Bearer {cfg.ha_token}"}
    state_rows: list[dict[str, str]] = []
    for entity_id in cfg.ha_entities:
        resp = requests.get(
            f"{cfg.ha_base_url.rstrip('/')}/api/states/{entity_id}",
            headers=headers,
            timeout=20,
        )
        if resp.status_code == 200:
            data = resp.json()
            state_rows.append(
                {
                    "entity_id": entity_id,
                    "state": str(data.get("state", "")),
                    "friendly_name": str(
                        data.get("attributes", {}).get("friendly_name", entity_id)
                    ),
                }
            )
    return state_rows


def build_note_body(
    today: dt.date,
    trello_cards: list[dict[str, str]],
    events: list[dict[str, str]],
    ha_rows: list[dict[str, str]],
) -> str:
    lines = [f"# Daily Log - {today.isoformat()}", "", "## Plan", "- [ ] Top priorities", ""]
    lines += ["## Trello Open Cards"]
    if trello_cards:
        for card in trello_cards:
            due_text = f" (due: {card['due']})" if card["due"] else ""
            lines.append(f"- [{card['name']}]({card['url']}){due_text}")
    else:
        lines.append("- No cards fetched")
    lines.append("")
    lines += ["## Calendar (Next 24h)"]
    if events:
        for event in events:
            lines.append(f"- {event['start']}: {event['summary']}")
    else:
        lines.append("- No events fetched")
    lines.append("")
    lines += ["## Home Assistant Snapshot"]
    if ha_rows:
        for row in ha_rows:
            lines.append(f"- {row['friendly_name']}: `{row['state']}`")
    else:
        lines.append("- No entities configured")
    lines += ["", "## Notes", "- "]
    return "\n".join(lines)


def create_or_skip_note(cfg: Config, folder_id: str, title: str, body: str) -> str:
    existing_id = find_note_by_title(cfg, folder_id, title)
    if existing_id:
        return existing_id
    created = joplin_post(
        cfg,
        "/notes",
        {
            "title": title,
            "parent_id": folder_id,
            "body": body,
        },
    )
    return created["id"]


def main() -> int:
    cfg = load_config()
    today = dt.date.today()
    trello_cards = fetch_trello_open_cards(cfg)
    events = fetch_google_events(cfg)
    ha_rows = fetch_home_assistant(cfg)
    body = build_note_body(today, trello_cards, events, ha_rows)
    folder_id = ensure_notebook(cfg)
    title = f"{today.isoformat()} Daily Log"
    note_id = create_or_skip_note(cfg, folder_id, title, body)
    print(json.dumps({"status": "ok", "note_id": note_id, "title": title}))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        raise
