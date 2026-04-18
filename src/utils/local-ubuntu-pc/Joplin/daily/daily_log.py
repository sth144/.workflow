#!/usr/bin/env python3
import base64
import datetime as dt
import json
import os
from pathlib import Path
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Any, Optional
from zoneinfo import ZoneInfo

import requests

# Optional deps (install if you want these features)
# pip install google-api-python-client google-auth
try:
    from google.oauth2 import service_account  # type: ignore
    from googleapiclient.discovery import build  # type: ignore
except Exception:
    service_account = None
    build = None

AUTOGEN_START = "<!-- JOPLIN_DAILY_AUTOGEN_START -->"
AUTOGEN_END = "<!-- JOPLIN_DAILY_AUTOGEN_END -->"


class JoplinAPIError(RuntimeError):
    pass


@dataclass
class Config:
    # Core
    timezone: str
    state_path: str

    # Joplin
    joplin_token: str
    joplin_base_url: str
    joplin_notebook: str
    note_title_fmt: str
    note_time_window: str  # "day" or "next24h"

    # Trello
    trello_key: Optional[str]
    trello_token: Optional[str]
    trello_board_id: Optional[str]
    trello_board_name: str
    trello_limit: int
    trello_todo_list_name: str
    trello_todo_limit: int

    # Headlines
    headlines_enabled: bool
    headlines_url: str
    headlines_limit: int

    # Google Calendar
    google_calendar_id: Optional[str]
    google_service_account_file: Optional[str]
    google_service_account_json: Optional[str]

    # Home Assistant
    ha_base_url: Optional[str]
    ha_token: Optional[str]
    ha_entities: list[str]
    ha_include_history: bool
    ha_history_max: int

    # Git
    git_enable: bool
    git_repos_csv: str

    # Docker snapshot
    docker_enable: bool
    docker_base_url: str  # usually http://localhost (talks to socket via requests-unixsocket? we keep simple)

    # Network map
    network_map_enable: bool
    network_map_target: str
    network_map_host_limit: int


def must_env(name: str) -> str:
    value = os.getenv(name, "").strip()
    if not value:
        raise RuntimeError(f"Missing required env var: {name}")
    return value


def getenv_int(name: str, default: int) -> int:
    raw = os.getenv(name, "").strip()
    if not raw:
        return default
    try:
        return int(raw)
    except ValueError:
        raise RuntimeError(f"Env var {name} must be an int (got {raw!r})")


def getenv_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name, "").strip().lower()
    if not raw:
        return default
    return raw in ("1", "true", "yes", "y", "on")


def load_config() -> Config:
    entities_csv = os.getenv("HA_ENTITIES", "").strip()
    entities = [x.strip() for x in entities_csv.split(",") if x.strip()]

    joplin_base_url = (
        os.getenv("JOPLIN_BASE_URL", "http://127.0.0.1:41184").strip().rstrip("/")
    )

    return Config(
        timezone=os.getenv("TIMEZONE", "UTC").strip(),
        state_path=os.getenv("STATE_PATH", "/state/state.json").strip(),
        joplin_token=must_env("JOPLIN_TOKEN"),
        joplin_base_url=joplin_base_url,
        joplin_notebook=os.getenv("JOPLIN_NOTEBOOK", "Areas/Journal/").strip(),
        note_title_fmt=os.getenv("NOTE_TITLE_FMT", "%-d %b, %Y").strip() or "%-d %b, %Y",
        note_time_window=os.getenv("NOTE_TIME_WINDOW", "day").strip().lower(),
        trello_key=os.getenv("TRELLO_KEY"),
        trello_token=os.getenv("TRELLO_TOKEN"),
        trello_board_id=os.getenv("TRELLO_BOARD_ID"),
        trello_board_name=os.getenv("TRELLO_BOARD_NAME", "ToDo").strip() or "ToDo",
        trello_limit=getenv_int("TRELLO_LIMIT", 25),
        trello_todo_list_name=os.getenv("TRELLO_TODO_LIST_NAME", "Today").strip()
        or "Today",
        trello_todo_limit=getenv_int("TRELLO_TODO_LIMIT", 20),
        headlines_enabled=getenv_bool("HEADLINES_ENABLE", True),
        headlines_url=os.getenv(
            "HEADLINES_URL",
            "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en",
        ).strip(),
        headlines_limit=getenv_int("HEADLINES_LIMIT", 5),
        google_calendar_id=os.getenv("GOOGLE_CALENDAR_ID"),
        google_service_account_file=os.getenv("GOOGLE_SERVICE_ACCOUNT_FILE"),
        google_service_account_json=os.getenv("GOOGLE_SERVICE_ACCOUNT_JSON")
        or os.getenv("GOOGLE_SERVICE_ACCOUNT_JSON_B64"),
        ha_base_url=os.getenv("HA_BASE_URL"),
        ha_token=os.getenv("HA_TOKEN"),
        ha_entities=entities,
        ha_include_history=getenv_bool("HA_INCLUDE_HISTORY", False),
        ha_history_max=getenv_int("HA_HISTORY_MAX", 60),
        git_enable=getenv_bool("GIT_ENABLE", False),
        git_repos_csv=os.getenv("GIT_REPOS", "").strip(),
        docker_enable=getenv_bool("DOCKER_ENABLE", False),
        docker_base_url=os.getenv("DOCKER_BASE_URL", "http://localhost").strip(),
        network_map_enable=getenv_bool("NETWORK_MAP_ENABLE", True),
        network_map_target=os.getenv("NETWORK_MAP_TARGET", "").strip(),
        network_map_host_limit=getenv_int("NETWORK_MAP_HOST_LIMIT", 24),
    )


def load_state(cfg: Config) -> dict[str, Any]:
    try:
        with open(cfg.state_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except Exception:
        return {}


def save_state(cfg: Config, state: dict[str, Any]) -> None:
    os.makedirs(os.path.dirname(cfg.state_path) or ".", exist_ok=True)
    tmp = cfg.state_path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2, sort_keys=True)
    os.replace(tmp, cfg.state_path)


def day_window(cfg: Config) -> tuple[dt.datetime, dt.datetime, dt.date]:
    tz = ZoneInfo(cfg.timezone)
    now = dt.datetime.now(tz)
    today = now.date()
    start = dt.datetime(today.year, today.month, today.day, 0, 0, 0, tzinfo=tz)
    end = start + dt.timedelta(days=1)
    if cfg.note_time_window == "next24h":
        start = now
        end = now + dt.timedelta(hours=24)
    return start, end, today


def joplin_get(cfg: Config, path: str, **params: Any) -> dict[str, Any]:
    params["token"] = cfg.joplin_token
    return _joplin_request("get", cfg, path, params=params)


def joplin_post(cfg: Config, path: str, payload: dict[str, Any]) -> dict[str, Any]:
    return _joplin_request(
        "post", cfg, path, params={"token": cfg.joplin_token}, json=payload
    )


def joplin_put(cfg: Config, path: str, payload: dict[str, Any]) -> dict[str, Any]:
    return _joplin_request(
        "put", cfg, path, params={"token": cfg.joplin_token}, json=payload
    )


def _joplin_request(
    method: str, cfg: Config, path: str, **kwargs: Any
) -> dict[str, Any]:
    url = f"{cfg.joplin_base_url}{path}"
    last_error: Exception | None = None
    for attempt in range(3):
        try:
            resp = requests.request(method, url, timeout=30, **kwargs)
            resp.raise_for_status()
            return resp.json()
        except requests.RequestException as exc:
            last_error = exc
            if attempt < 2:
                time.sleep(attempt + 1)
                continue
            raise JoplinAPIError(
                f"Unable to reach Joplin API at {url}: {exc}"
            ) from exc
        except ValueError as exc:
            raise JoplinAPIError(f"Invalid JSON returned by Joplin API at {url}") from exc
    raise JoplinAPIError(f"Unable to reach Joplin API at {url}: {last_error}")


def ensure_notebook(cfg: Config) -> str:
    parts = [p for p in cfg.joplin_notebook.strip("/").split("/") if p]
    if not parts:
        raise RuntimeError("JOPLIN_NOTEBOOK must not be empty")

    parent_id = ""
    for part in parts:
        folders = joplin_get(
            cfg, "/folders", fields="id,title,parent_id", limit=100
        ).get("items", [])
        matching = next(
            (
                f
                for f in folders
                if f.get("title") == part and (f.get("parent_id") or "") == parent_id
            ),
            None,
        )
        if matching:
            parent_id = matching["id"]
            continue

        payload = {"title": part}
        if parent_id:
            payload["parent_id"] = parent_id
        created = joplin_post(cfg, "/folders", payload)
        parent_id = created["id"]

    return parent_id


def find_note_by_title(cfg: Config, folder_id: str, title: str) -> str | None:
    # Simple: first 100 notes in folder
    notes = joplin_get(
        cfg, f"/folders/{folder_id}/notes", fields="id,title", limit=100
    ).get("items", [])
    for n in notes:
        if n.get("title") == title:
            return n["id"]
    return None


def get_note_body(cfg: Config, note_id: str) -> str:
    note = joplin_get(cfg, f"/notes/{note_id}", fields="id,body")
    return str(note.get("body", ""))


def upsert_autogen_block(existing_body: str, generated_md: str) -> tuple[str, str]:
    block = f"{AUTOGEN_START}\n{generated_md}\n{AUTOGEN_END}"
    start_idx = existing_body.find(AUTOGEN_START)
    end_idx = existing_body.find(AUTOGEN_END)

    if start_idx != -1 and end_idx != -1 and end_idx >= start_idx:
        end_idx = end_idx + len(AUTOGEN_END)
        new_body = (
            f"{existing_body[:start_idx].rstrip()}\n\n{block}\n\n{existing_body[end_idx:].lstrip()}"
        ).strip()
        return new_body, "overwrote_block"

    if existing_body.strip():
        return f"{existing_body.rstrip()}\n\n{block}", "inserted_block"
    return block, "inserted_block"


def create_or_update_note(
    cfg: Config, folder_id: str, title: str, generated_md: str
) -> tuple[str, str]:
    existing_id = find_note_by_title(cfg, folder_id, title)
    if existing_id:
        existing_body = get_note_body(cfg, existing_id)
        updated_body, action = upsert_autogen_block(existing_body, generated_md)
        joplin_put(cfg, f"/notes/{existing_id}", {"body": updated_body})
        return existing_id, action

    created = joplin_post(
        cfg,
        "/notes",
        {
            "title": title,
            "parent_id": folder_id,
            "body": f"{AUTOGEN_START}\n{generated_md}\n{AUTOGEN_END}",
        },
    )
    return created["id"], "created"


# ---------- Trello ----------
def resolve_trello_board_id(cfg: Config) -> str | None:
    if cfg.trello_board_id:
        return cfg.trello_board_id
    if not (cfg.trello_key and cfg.trello_token):
        return None

    resp = requests.get(
        "https://api.trello.com/1/members/me/boards",
        params={
            "key": cfg.trello_key,
            "token": cfg.trello_token,
            "fields": "id,name",
            "filter": "open",
        },
        timeout=30,
    )
    resp.raise_for_status()

    board_name = cfg.trello_board_name.casefold()
    boards = resp.json() or []
    for board in boards:
        if str(board.get("name", "")).strip().casefold() == board_name:
            return str(board.get("id", "")).strip() or None
    return None


def _trello_action_summary(action: dict[str, Any]) -> str:
    data = action.get("data", {}) or {}
    action_type = str(action.get("type", "")).strip() or "action"
    member = str(
        (action.get("memberCreator", {}) or {}).get("fullName", "")
    ).strip()
    card = str((data.get("card", {}) or {}).get("name", "")).strip()
    list_before = str((data.get("listBefore", {}) or {}).get("name", "")).strip()
    list_after = str((data.get("listAfter", {}) or {}).get("name", "")).strip()
    list_name = str((data.get("list", {}) or {}).get("name", "")).strip()
    board_name = str((data.get("board", {}) or {}).get("name", "")).strip()
    text = str(data.get("text", "")).strip()

    if action_type == "commentCard":
        detail = f"commented on {card}" if card else "added a comment"
        if text:
            detail = f'{detail}: "{text}"'
    elif action_type == "createCard":
        detail = f"created {card}" if card else "created a card"
        if list_name:
            detail = f"{detail} in {list_name}"
    elif action_type == "updateCard" and list_before and list_after:
        target = card or "a card"
        detail = f"moved {target} from {list_before} to {list_after}"
    elif action_type == "updateCard" and card:
        detail = f"updated {card}"
    elif action_type == "deleteCard":
        detail = f"deleted {card}" if card else "deleted a card"
    else:
        detail = action_type
        if card:
            detail = f"{detail}: {card}"
        elif list_name:
            detail = f"{detail}: {list_name}"
        elif board_name:
            detail = f"{detail}: {board_name}"

    if member:
        return f"{member} {detail}"
    return detail


def fetch_trello_cards(
    cfg: Config, start: dt.datetime, end: dt.datetime
) -> list[dict[str, str]]:
    if not (cfg.trello_key and cfg.trello_token):
        return []
    board_id = resolve_trello_board_id(cfg)
    if not board_id:
        return []

    url = f"https://api.trello.com/1/boards/{board_id}/actions"
    params = {
        "key": cfg.trello_key,
        "token": cfg.trello_token,
        "filter": "all",
        "limit": str(cfg.trello_limit),
        "since": start.astimezone(dt.UTC).isoformat(),
        "before": end.astimezone(dt.UTC).isoformat(),
        "memberCreator_fields": "fullName,url",
    }

    resp = requests.get(url, params=params, timeout=30)
    resp.raise_for_status()
    actions = resp.json() or []
    out: list[dict[str, str]] = []
    for action in actions[: cfg.trello_limit]:
        action_date = str(action.get("date", "")).strip()
        action_url = str((action.get("memberCreator", {}) or {}).get("url", "")).strip()
        out.append(
            {
                "name": _trello_action_summary(action),
                "url": action_url,
                "due": action_date,
            }
        )
    return out


def fetch_trello_list_cards(cfg: Config, list_name: str) -> list[dict[str, str]]:
    if not (cfg.trello_key and cfg.trello_token):
        return []
    board_id = resolve_trello_board_id(cfg)
    if not board_id:
        return []

    lists_resp = requests.get(
        f"https://api.trello.com/1/boards/{board_id}/lists",
        params={
            "key": cfg.trello_key,
            "token": cfg.trello_token,
            "fields": "id,name",
            "filter": "open",
        },
        timeout=30,
    )
    lists_resp.raise_for_status()
    target = list_name.strip().casefold()
    trello_lists = lists_resp.json() or []
    matched = next(
        (item for item in trello_lists if str(item.get("name", "")).strip().casefold() == target),
        None,
    )
    if not matched:
        return []

    cards_resp = requests.get(
        f"https://api.trello.com/1/lists/{matched['id']}/cards",
        params={
            "key": cfg.trello_key,
            "token": cfg.trello_token,
            "fields": "id,name,shortUrl,due,dueComplete,pos",
            "filter": "open",
        },
        timeout=30,
    )
    cards_resp.raise_for_status()
    cards = cards_resp.json() or []
    cards.sort(key=lambda card: float(card.get("pos", 0) or 0))
    out: list[dict[str, str]] = []
    for card in cards[: cfg.trello_todo_limit]:
        out.append(
            {
                "name": str(card.get("name", "")).strip() or "(Untitled card)",
                "url": str(card.get("shortUrl", "")).strip(),
                "due": str(card.get("due", "")).strip(),
                "done": "true" if bool(card.get("dueComplete")) else "false",
            }
        )
    return out


# ---------- Headlines ----------
def fetch_headlines(cfg: Config) -> list[dict[str, str]]:
    if not cfg.headlines_enabled or not cfg.headlines_url:
        return []

    try:
        resp = requests.get(
            cfg.headlines_url,
            timeout=20,
            headers={"User-Agent": "workflow-joplin-daily/1.0"},
        )
        resp.raise_for_status()
        root = ET.fromstring(resp.content)
    except Exception:
        return []

    items = root.findall(".//channel/item")
    if not items:
        items = root.findall(".//item")

    headlines: list[dict[str, str]] = []
    for item in items[: cfg.headlines_limit]:
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        if not title:
            continue
        headlines.append({"title": title, "link": link})
    return headlines


# ---------- Google Calendar ----------
def _service_account_creds(cfg: Config):
    if service_account is None:
        raise RuntimeError(
            "Google deps not installed. Install google-auth and google-api-python-client."
        )

    scopes = ["https://www.googleapis.com/auth/calendar.readonly"]

    if cfg.google_service_account_file:
        return service_account.Credentials.from_service_account_file(
            cfg.google_service_account_file, scopes=scopes
        )

    if cfg.google_service_account_json:
        raw = cfg.google_service_account_json.strip()
        # Accept either raw JSON or base64 JSON
        if raw.startswith("{"):
            info = json.loads(raw)
            return service_account.Credentials.from_service_account_info(
                info, scopes=scopes
            )
        try:
            decoded = base64.b64decode(raw).decode("utf-8")
            info = json.loads(decoded)
            return service_account.Credentials.from_service_account_info(
                info, scopes=scopes
            )
        except Exception:
            raise RuntimeError(
                "GOOGLE_SERVICE_ACCOUNT_JSON must be raw JSON or base64-encoded JSON."
            )

    return None


def fetch_google_events(
    cfg: Config, start: dt.datetime, end: dt.datetime
) -> list[dict[str, str]]:
    if not cfg.google_calendar_id:
        return []
    creds = _service_account_creds(cfg)
    if creds is None or build is None:
        return []

    service = build("calendar", "v3", credentials=creds, cache_discovery=False)
    events_result = (
        service.events()
        .list(
            calendarId=cfg.google_calendar_id,
            timeMin=start.astimezone(dt.UTC).isoformat(),
            timeMax=end.astimezone(dt.UTC).isoformat(),
            singleEvents=True,
            orderBy="startTime",
            maxResults=25,
        )
        .execute()
    )
    items = events_result.get("items", []) or []

    out: list[dict[str, str]] = []
    for e in items:
        s = e.get("start", {})
        start_dt = s.get("dateTime") or s.get("date", "")
        out.append(
            {
                "summary": e.get("summary", "(No title)"),
                "start": start_dt,
                "link": e.get("htmlLink", ""),
            }
        )
    return out


# ---------- Home Assistant ----------
def _ha_headers(cfg: Config) -> dict[str, str]:
    return {"Authorization": f"Bearer {cfg.ha_token}"}


def _ha_fetch_all_states(cfg: Config) -> list[dict[str, Any]]:
    if not (cfg.ha_base_url and cfg.ha_token):
        return []
    base = cfg.ha_base_url.rstrip("/")
    resp = requests.get(f"{base}/api/states", headers=_ha_headers(cfg), timeout=20)
    if resp.status_code != 200:
        return []
    data = resp.json() or []
    if not isinstance(data, list):
        return []
    return data


def _ha_score_candidate(target: str, candidate: dict[str, Any]) -> int:
    target_norm = target.strip().casefold()
    entity_id = str(candidate.get("entity_id", "")).strip()
    entity_norm = entity_id.casefold()
    friendly_name = str((candidate.get("attributes", {}) or {}).get("friendly_name", "")).strip()
    friendly_norm = friendly_name.casefold()

    if target_norm == entity_norm:
        return 1000
    if target_norm == friendly_norm:
        return 950
    if entity_norm.startswith(target_norm):
        return 900
    if friendly_norm.startswith(target_norm):
        return 850
    if target_norm in entity_norm:
        return 800
    if target_norm in friendly_norm:
        return 750

    target_tail = target_norm.split(".", 1)[-1]
    entity_tail = entity_norm.split(".", 1)[-1]
    if target_tail and target_tail == entity_tail:
        return 700
    if target_tail and entity_tail.startswith(target_tail):
        return 650
    return -1


def _ha_resolve_entities(
    cfg: Config, all_states: list[dict[str, Any]]
) -> tuple[list[dict[str, Any]], list[str]]:
    if not cfg.ha_entities:
        return [], []
    resolved: list[dict[str, Any]] = []
    resolved_ids: list[str] = []
    seen_ids: set[str] = set()

    for target in cfg.ha_entities:
        best_state: dict[str, Any] | None = None
        best_score = -1
        for candidate in all_states:
            score = _ha_score_candidate(target, candidate)
            if score > best_score:
                best_score = score
                best_state = candidate
        if best_state is None or best_score < 0:
            continue
        entity_id = str(best_state.get("entity_id", "")).strip()
        if not entity_id or entity_id in seen_ids:
            continue
        seen_ids.add(entity_id)
        resolved.append(best_state)
        resolved_ids.append(entity_id)
    return resolved, resolved_ids


def fetch_home_assistant_snapshot(cfg: Config) -> list[dict[str, str]]:
    if not (cfg.ha_base_url and cfg.ha_token and cfg.ha_entities):
        return []
    all_states = _ha_fetch_all_states(cfg)
    resolved_states, _ = _ha_resolve_entities(cfg, all_states)
    rows: list[dict[str, str]] = []
    for data in resolved_states:
        entity_id = str(data.get("entity_id", "")).strip()
        rows.append(
            {
                "entity_id": entity_id,
                "friendly_name": str(
                    data.get("attributes", {}).get("friendly_name", entity_id)
                ),
                "state": str(data.get("state", "")),
            }
        )
    return rows


def fetch_home_assistant_history(
    cfg: Config, start: dt.datetime, end: dt.datetime
) -> list[dict[str, str]]:
    """
    Pulls state changes since `start` (best-effort). Uses HA history API:
    /api/history/period/<iso>?filter_entity_id=a,b,c&minimal_response
    """
    if not (cfg.ha_base_url and cfg.ha_token):
        return []
    base = cfg.ha_base_url.rstrip("/")
    headers = _ha_headers(cfg)

    # HA expects local-ish ISO; timezone offset is fine.
    start_iso = start.isoformat()
    end_iso = end.isoformat()

    resolved_ids: list[str] = []
    if cfg.ha_entities:
        _, resolved_ids = _ha_resolve_entities(cfg, _ha_fetch_all_states(cfg))

    if resolved_ids:
        params = {
            "filter_entity_id": ",".join(resolved_ids),
            "minimal_response": "1",
            "significant_changes_only": "1",
            "end_time": end_iso,
        }
        resp = requests.get(
            f"{base}/api/history/period/{start_iso}",
            headers=headers,
            params=params,
            timeout=40,
        )
        if resp.status_code != 200:
            return []

        data = resp.json() or []
        out: list[dict[str, str]] = []
        for entity_states in data:
            fallback_entity_id = ""
            if entity_states:
                fallback_entity_id = str(entity_states[0].get("entity_id", "")).strip()
            for st in entity_states[-5:]:
                out.append(
                    {
                        "entity_id": str(st.get("entity_id", "")).strip()
                        or fallback_entity_id,
                        "state": str(st.get("state", "")),
                        "last_changed": str(st.get("last_changed", "")),
                    }
                )
        return out[-cfg.ha_history_max :]

    resp = requests.get(
        f"{base}/api/logbook/{start_iso}",
        headers=headers,
        params={"end_time": end_iso},
        timeout=40,
    )
    if resp.status_code != 200:
        return []

    data = resp.json() or []
    out: list[dict[str, str]] = []
    for entry in data[-cfg.ha_history_max :]:
        name = str(entry.get("name", "")).strip()
        entity_id = str(entry.get("entity_id", "")).strip()
        message = str(entry.get("message", "")).strip() or "event"
        out.append(
            {
                "entity_id": name or entity_id or "Home Assistant",
                "state": message,
                "last_changed": str(entry.get("when", "")).strip(),
            }
        )
    return out


# ---------- Git (optional) ----------
def fetch_git_summary(
    cfg: Config, start: dt.datetime, end: dt.datetime
) -> list[dict[str, str]]:
    """
    Requires that repos are mounted into the container and `git` is installed.
    GIT_REPOS is a comma-separated list of absolute paths inside container.
    """
    if not cfg.git_enable or not cfg.git_repos_csv.strip():
        return []
    import subprocess

    repo_entries = [p.strip() for p in cfg.git_repos_csv.split(",") if p.strip()]
    out: list[dict[str, str]] = []
    # Use ISO ranges (git is happy with these)
    since = start.isoformat()
    until = end.isoformat()

    cwd = Path.cwd().resolve()
    parent_candidates = [cwd, *cwd.parents]
    root_candidates = [
        Path.home() / "src",
        Path("/usr/local/src"),
    ]

    def resolve_repo_path(repo: str) -> Path | None:
        raw_path = Path(repo).expanduser()
        candidates: list[Path] = []
        if raw_path.is_absolute():
            candidates.append(raw_path)
        else:
            candidates.append((cwd / raw_path).resolve())

        repo_name = raw_path.name
        if repo_name:
            for parent in parent_candidates:
                candidates.append(parent / repo_name)
            for root in root_candidates:
                candidates.append(root / repo_name)

        seen: set[str] = set()
        for candidate in candidates:
            candidate_str = str(candidate)
            if candidate_str in seen:
                continue
            seen.add(candidate_str)
            if candidate.exists() and (candidate / ".git").exists():
                return candidate
        return None

    def discover_repo_paths(repo_entry: str) -> list[Path]:
        resolved = resolve_repo_path(repo_entry)
        if resolved is not None:
            return [resolved]

        raw_path = Path(repo_entry).expanduser()
        dir_candidates: list[Path] = []
        if raw_path.is_absolute():
            dir_candidates.append(raw_path)
        else:
            dir_candidates.append((cwd / raw_path).resolve())

        repo_name = raw_path.name
        if repo_name:
            for parent in parent_candidates:
                dir_candidates.append(parent / repo_name)
            for root in root_candidates:
                dir_candidates.append(root / repo_name)

        seen_dirs: set[str] = set()
        discovered: list[Path] = []
        for candidate in dir_candidates:
            candidate_str = str(candidate)
            if candidate_str in seen_dirs:
                continue
            seen_dirs.add(candidate_str)
            if not candidate.exists() or not candidate.is_dir():
                continue
            if (candidate / ".git").exists():
                discovered.append(candidate)
                continue

            # Treat a plain directory entry as a repo root collection and scan a few levels.
            root_depth = len(candidate.parts)
            for dirpath, dirnames, _filenames in os.walk(candidate):
                current_path = Path(dirpath)
                relative_depth = len(current_path.parts) - root_depth
                if relative_depth > 3:
                    dirnames[:] = []
                    continue
                if ".git" in dirnames:
                    discovered.append(current_path)
                    dirnames[:] = []
                    continue
                dirnames[:] = [
                    dirname
                    for dirname in dirnames
                    if dirname not in {".git", ".venv", "node_modules", "__pycache__"}
                ]

        unique: list[Path] = []
        seen_repo_paths: set[str] = set()
        for repo_path in discovered:
            repo_str = str(repo_path.resolve())
            if repo_str in seen_repo_paths:
                continue
            seen_repo_paths.add(repo_str)
            unique.append(repo_path.resolve())
        return unique

    repo_paths: list[Path] = []
    seen_repo_paths: set[str] = set()
    for repo_entry in repo_entries:
        for repo_path in discover_repo_paths(repo_entry):
            repo_str = str(repo_path)
            if repo_str in seen_repo_paths:
                continue
            seen_repo_paths.add(repo_str)
            repo_paths.append(repo_path)

    for resolved_repo in repo_paths:
        try:
            r = subprocess.run(
                [
                    "git",
                    "-C",
                    str(resolved_repo),
                    "log",
                    f"--since={since}",
                    f"--until={until}",
                    "--pretty=format:%h|%s",
                ],
                check=False,
                capture_output=True,
                text=True,
            )
            if r.returncode != 0:
                continue
            lines = [ln for ln in (r.stdout or "").splitlines() if ln.strip()]
            if not lines:
                continue
            out.append(
                {
                    "repo": str(resolved_repo),
                    "count": str(len(lines)),
                    "top": lines[0].split("|", 1)[-1],
                }
            )
        except Exception:
            continue
    return out


# ---------- Docker snapshot (optional) ----------
def fetch_docker_snapshot(cfg: Config) -> list[dict[str, str]]:
    """
    Lightweight approach: if you mount /var/run/docker.sock, you can query:
    GET http://localhost/containers/json?all=0  ... BUT that requires a unix-socket transport.
    To keep this script dependency-light, we’ll use docker CLI if present.
    """
    if not cfg.docker_enable:
        return []
    import subprocess

    try:
        r = subprocess.run(
            ["docker", "ps", "--format", "{{.Names}}|{{.Image}}|{{.Status}}"],
            check=False,
            capture_output=True,
            text=True,
        )
        if r.returncode != 0:
            return []
        rows: list[dict[str, str]] = []
        for ln in (r.stdout or "").splitlines():
            name, image, status = (ln.split("|", 2) + ["", "", ""])[:3]
            rows.append({"name": name, "image": image, "status": status})
        return rows[:30]
    except Exception:
        return []


# ---------- Network map ----------
def fetch_network_map(cfg: Config) -> dict[str, Any] | None:
    if not cfg.network_map_enable:
        return None
    import subprocess

    script_path = Path(__file__).resolve().with_name("network_map.py")
    if not script_path.exists():
        return None

    cmd = [sys.executable, str(script_path), "--host-limit", str(cfg.network_map_host_limit)]
    if cfg.network_map_target:
        cmd += ["--target", cfg.network_map_target]

    try:
        result = subprocess.run(
            cmd,
            check=False,
            capture_output=True,
            text=True,
            timeout=120,
        )
    except Exception:
        return None

    if result.returncode != 0:
        return {
            "status": "error",
            "error": (result.stderr or result.stdout or "network map script failed").strip(),
        }

    try:
        payload = json.loads(result.stdout or "{}")
    except json.JSONDecodeError:
        return {
            "status": "error",
            "error": "network map script returned invalid JSON",
        }
    if not isinstance(payload, dict):
        return {
            "status": "error",
            "error": "network map script returned unexpected payload",
        }
    return payload


# ---------- Markdown rendering ----------
def build_generated_md(
    cfg: Config,
    today: dt.date,
    window_label: str,
    headlines: list[dict[str, str]],
    todo_cards: list[dict[str, str]],
    trello_cards: list[dict[str, str]],
    events: list[dict[str, str]],
    ha_snapshot: list[dict[str, str]],
    ha_history: list[dict[str, str]],
    git_summary: list[dict[str, str]],
    docker_rows: list[dict[str, str]],
    network_map: dict[str, Any] | None,
) -> str:
    lines: list[str] = []

    lines += [
        f"# Daily Log — {today.strftime('%A, %Y-%m-%d')}",
        "",
        f"_Autogenerated: {window_label}_",
        "",
        "## ToDo",
    ]
    if todo_cards:
        for card in todo_cards:
            due = f" ({card['due']})" if card.get("due") else ""
            if card.get("url"):
                lines.append(f"- [ ] [{card['name']}]({card['url']}){due}")
            else:
                lines.append(f"- [ ] {card['name']}{due}")
    else:
        lines.append(f"- (No cards found in `{cfg.trello_todo_list_name}`)")
    lines += [
        "",
        "## Calendar",
    ]
    if events:
        for e in events:
            start = e.get("start", "")
            summ = e.get("summary", "")
            link = e.get("link", "")
            if link:
                lines.append(f"- {start}: [{summ}]({link})")
            else:
                lines.append(f"- {start}: {summ}")
    else:
        if cfg.google_calendar_id == "primary" and (
            cfg.google_service_account_file or cfg.google_service_account_json
        ):
            lines.append(
                "- (No events fetched. `GOOGLE_CALENDAR_ID=primary` uses the service account's own empty primary calendar unless your real calendar is explicitly shared with that service account.)"
            )
        else:
            lines.append("- (No events fetched)")
    lines.append("")

    lines += ["## Top Headlines"]
    if headlines:
        for item in headlines:
            if item.get("link"):
                lines.append(f"- [{item['title']}]({item['link']})")
            else:
                lines.append(f"- {item['title']}")
    else:
        lines.append("- (No headlines fetched)")
    lines.append("")

    lines += [f"## Trello Activity ({cfg.trello_board_name})"]
    if trello_cards:
        for c in trello_cards:
            due = f" ({c['due']})" if c.get("due") else ""
            if c.get("url"):
                lines.append(f"- [{c['name']}]({c['url']}){due}")
            else:
                lines.append(f"- {c['name']}{due}")
    else:
        lines.append("- (No activity fetched)")
    lines.append("")

    if cfg.ha_entities:
        lines += ["## Home Assistant — Snapshot"]
        if ha_snapshot:
            for r in ha_snapshot:
                lines.append(f"- {r['friendly_name']}: `{r['state']}`")
        else:
            lines.append("- (No entities fetched)")
        lines.append("")

    if cfg.ha_include_history:
        lines += ["## Home Assistant — Recent events"]
        if ha_history:
            for h in ha_history:
                lines.append(
                    f"- {h['last_changed']}: `{h['entity_id']}` → `{h['state']}`"
                )
        else:
            lines.append("- (No history fetched)")
        lines.append("")

    if cfg.git_enable:
        lines += ["## Git — Commits"]
        if git_summary:
            for g in git_summary:
                lines.append(
                    f"- {g['repo']}: {g['count']} commit(s) (latest: {g['top']})"
                )
        else:
            lines.append("- (No commits found / repos not mounted)")
        lines.append("")

    if cfg.docker_enable:
        lines += ["## Docker — Running containers"]
        if docker_rows:
            for d in docker_rows:
                lines.append(f"- `{d['name']}` — {d['image']} — {d['status']}")
        else:
            lines.append("- (No snapshot / docker not available)")
        lines.append("")

    if cfg.network_map_enable:
        lines += ["## Network — Diagram"]
        if network_map and network_map.get("status") == "ok" and network_map.get("plantuml"):
            target = str(network_map.get("target", "")).strip()
            interface = str(network_map.get("interface", "")).strip()
            lines.append(
                f"- Scan target: `{target or 'auto'}`"
                + (f" on `{interface}`" if interface else "")
            )
            tools = network_map.get("tools", {})
            if isinstance(tools, dict) and tools:
                tool_status = ", ".join(
                    f"{name}={status}" for name, status in sorted(tools.items())
                )
                lines.append(f"- Tools: `{tool_status}`")
            lines.append("")
            lines.append("```plantuml")
            lines.append(str(network_map["plantuml"]).strip())
            lines.append("```")
        elif network_map and network_map.get("error"):
            lines.append(f"- (Network map unavailable: {network_map['error']})")
        else:
            lines.append("- (Network map unavailable)")
        lines.append("")

    lines += [
        "## Reflection",
        "- What moved forward today?",
        "- What slowed me down?",
        "- First thing tomorrow:",
        "",
    ]
    return "\n".join(lines).strip()


def main() -> int:
    cfg = load_config()
    state = load_state(cfg)

    start, end, today = day_window(cfg)
    window_label = f"{start.isoformat()} → {end.isoformat()} ({cfg.timezone})"

    headlines = fetch_headlines(cfg)
    todo_cards = fetch_trello_list_cards(cfg, cfg.trello_todo_list_name)
    trello_cards = fetch_trello_cards(cfg, start, end)
    events = fetch_google_events(cfg, start, end)
    ha_snapshot = fetch_home_assistant_snapshot(cfg)
    ha_history = (
        fetch_home_assistant_history(cfg, start, end) if cfg.ha_include_history else []
    )
    git_summary = fetch_git_summary(cfg, start, end)
    docker_rows = fetch_docker_snapshot(cfg)
    network_map = fetch_network_map(cfg)

    generated_md = build_generated_md(
        cfg,
        today,
        window_label,
        headlines,
        todo_cards,
        trello_cards,
        events,
        ha_snapshot,
        ha_history,
        git_summary,
        docker_rows,
        network_map,
    )

    folder_id = ensure_notebook(cfg)
    title = dt.datetime.now(ZoneInfo(cfg.timezone)).strftime(cfg.note_title_fmt)

    note_id, action = create_or_update_note(cfg, folder_id, title, generated_md)

    # minimal state example (handy later for cursors)
    state["last_run"] = dt.datetime.now(dt.UTC).isoformat()
    save_state(cfg, state)

    print(
        json.dumps(
            {"status": "ok", "action": action, "note_id": note_id, "title": title}
        )
    )
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        raise SystemExit(1)
    except Exception as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        raise
