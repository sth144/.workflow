#!/usr/bin/env python3
import base64
import datetime as dt
import json
import os
import sys
import tempfile
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
    trello_limit: int

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
        note_title_fmt="%-d %b, %Y",
        note_time_window=os.getenv("NOTE_TIME_WINDOW", "day").strip().lower(),
        trello_key=os.getenv("TRELLO_KEY"),
        trello_token=os.getenv("TRELLO_TOKEN"),
        trello_board_id=os.getenv("TRELLO_BOARD_ID"),
        trello_limit=getenv_int("TRELLO_LIMIT", 25),
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
    resp = requests.get(f"{cfg.joplin_base_url}{path}", params=params, timeout=30)
    resp.raise_for_status()
    return resp.json()


def joplin_post(cfg: Config, path: str, payload: dict[str, Any]) -> dict[str, Any]:
    resp = requests.post(
        f"{cfg.joplin_base_url}{path}",
        params={"token": cfg.joplin_token},
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


def joplin_put(cfg: Config, path: str, payload: dict[str, Any]) -> dict[str, Any]:
    resp = requests.put(
        f"{cfg.joplin_base_url}{path}",
        params={"token": cfg.joplin_token},
        json=payload,
        timeout=30,
    )
    resp.raise_for_status()
    return resp.json()


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
def fetch_trello_cards(cfg: Config) -> list[dict[str, str]]:
    if not (cfg.trello_key and cfg.trello_token):
        return []
    if cfg.trello_board_id:
        url = f"https://api.trello.com/1/boards/{cfg.trello_board_id}/cards/open"
        params = {
            "key": cfg.trello_key,
            "token": cfg.trello_token,
            "fields": "name,shortUrl,due,idList",
        }
    else:
        # fallback: all open cards assigned to me
        url = "https://api.trello.com/1/members/me/cards"
        params = {
            "key": cfg.trello_key,
            "token": cfg.trello_token,
            "filter": "open",
            "fields": "name,shortUrl,due",
        }

    resp = requests.get(url, params=params, timeout=30)
    resp.raise_for_status()
    cards = resp.json() or []
    out: list[dict[str, str]] = []
    for c in cards[: cfg.trello_limit]:
        out.append(
            {
                "name": c.get("name", "Untitled"),
                "url": c.get("shortUrl", ""),
                "due": c.get("due") or "",
            }
        )
    return out


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
def fetch_home_assistant_snapshot(cfg: Config) -> list[dict[str, str]]:
    if not (cfg.ha_base_url and cfg.ha_token and cfg.ha_entities):
        return []
    base = cfg.ha_base_url.rstrip("/")
    headers = {"Authorization": f"Bearer {cfg.ha_token}"}

    rows: list[dict[str, str]] = []
    for entity_id in cfg.ha_entities:
        resp = requests.get(
            f"{base}/api/states/{entity_id}", headers=headers, timeout=20
        )
        if resp.status_code != 200:
            continue
        data = resp.json() or {}
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
    cfg: Config, start: dt.datetime
) -> list[dict[str, str]]:
    """
    Pulls state changes since `start` (best-effort). Uses HA history API:
    /api/history/period/<iso>?filter_entity_id=a,b,c&minimal_response
    """
    if not (cfg.ha_base_url and cfg.ha_token and cfg.ha_entities):
        return []
    base = cfg.ha_base_url.rstrip("/")
    headers = {"Authorization": f"Bearer {cfg.ha_token}"}

    # HA expects local-ish ISO; timezone offset is fine.
    start_iso = start.isoformat()

    params = {
        "filter_entity_id": ",".join(cfg.ha_entities),
        "minimal_response": "1",
        "significant_changes_only": "1",
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
    # Data format: list per entity, each is list of states
    out: list[dict[str, str]] = []
    for entity_states in data:
        # keep only last few changes per entity
        for st in entity_states[-5:]:
            out.append(
                {
                    "entity_id": str(st.get("entity_id", "")),
                    "state": str(st.get("state", "")),
                    "last_changed": str(st.get("last_changed", "")),
                }
            )
    # cap
    out = out[-cfg.ha_history_max :]
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

    repos = [p.strip() for p in cfg.git_repos_csv.split(",") if p.strip()]
    out: list[dict[str, str]] = []
    # Use ISO ranges (git is happy with these)
    since = start.isoformat()
    until = end.isoformat()

    for repo in repos:
        try:
            r = subprocess.run(
                [
                    "git",
                    "-C",
                    repo,
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
                    "repo": repo,
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


# ---------- Markdown rendering ----------
def build_generated_md(
    cfg: Config,
    today: dt.date,
    window_label: str,
    trello_cards: list[dict[str, str]],
    events: list[dict[str, str]],
    ha_snapshot: list[dict[str, str]],
    ha_history: list[dict[str, str]],
    git_summary: list[dict[str, str]],
    docker_rows: list[dict[str, str]],
) -> str:
    lines: list[str] = []

    lines += [
        f"# Daily Log — {today.isoformat()}",
        "",
        f"_Autogenerated: {window_label}_",
        "",
        "## Plan",
        "- [ ] Top priorities",
        "- [ ] One annoying thing to fix",
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
        lines.append("- (No events fetched)")
    lines.append("")

    lines += ["## Trello"]
    if trello_cards:
        for c in trello_cards:
            due = f" (due: {c['due']})" if c.get("due") else ""
            lines.append(f"- [{c['name']}]({c['url']}){due}")
    else:
        lines.append("- (No cards fetched)")
    lines.append("")

    lines += ["## Home Assistant — Snapshot"]
    if ha_snapshot:
        for r in ha_snapshot:
            lines.append(f"- {r['friendly_name']}: `{r['state']}`")
    else:
        lines.append("- (No entities configured)")
    lines.append("")

    if cfg.ha_include_history:
        lines += ["## Home Assistant — Recent changes"]
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

    trello_cards = fetch_trello_cards(cfg)
    events = fetch_google_events(cfg, start, end)
    ha_snapshot = fetch_home_assistant_snapshot(cfg)
    ha_history = (
        fetch_home_assistant_history(cfg, start) if cfg.ha_include_history else []
    )
    git_summary = fetch_git_summary(cfg, start, end)
    docker_rows = fetch_docker_snapshot(cfg)

    generated_md = build_generated_md(
        cfg,
        today,
        window_label,
        trello_cards,
        events,
        ha_snapshot,
        ha_history,
        git_summary,
        docker_rows,
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
    except Exception as exc:
        print(json.dumps({"status": "error", "error": str(exc)}), file=sys.stderr)
        raise
