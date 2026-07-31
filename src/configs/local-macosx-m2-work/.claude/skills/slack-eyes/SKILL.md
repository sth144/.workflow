# Skill: Slack 👀 → Daybook To Do

## When to Use
Use this skill when the user wants Slack messages they marked with the 👀
(`:eyes:`) reaction pulled into their To Do list. Trigger phrases include:
"what have I marked 👀", "slack eyes", "pull my eyes items", "what did I flag
in slack", "check my 👀 backlog".

## Prerequisites
- `SLACK_USER_TOKEN` (an `xoxp-` user token) with the **`reactions:read`** user
  scope. Bot tokens cannot do this — `reactions.list` reports the reactions of
  the authenticated *user*.
- `JOPLIN_TOKEN` set in the environment
- Joplin desktop app must be running (REST API on port 41184)
- `~/.claude/skills/trello-daybook-sync/sync.py` present — `eyes.py` imports its
  Joplin client, daybook notebook ID and To Do section parser
- Python 3.11+ with `requests`

Verify the scope before debugging anything else:

```bash
T=$(cat ~/.config/.env.SLACK_USER_TOKEN)
curl -s "https://slack.com/api/reactions.list?limit=1" -H "Authorization: Bearer $T"
```

`{"ok":false,"error":"missing_scope","needed":"reactions:read"}` means the Slack
app needs `reactions:read` added under **OAuth & Permissions → User Token
Scopes** and reinstalling — which issues a new token to write back to
`~/.config/.env.SLACK_USER_TOKEN`.

## How It Works

`eyes.py` (same directory as this file):

1. Calls `auth.test` for the user ID and workspace URL.
2. Pages `reactions.list` (up to 20 pages) and keeps messages carrying an
   `eyes` reaction **whose user list contains this user** — the API returns
   every emoji you reacted with, and every reaction other people added.
3. Drops keys (`channel:ts`) already in the state file
   `~/.claude/routines/state/slack-eyes.json`.
4. Appends one unchecked item per remaining message to the end of the
   `# To Do ✅` section of today's daybook note:

   ```
   - [ ] 👀 Can someone take a look at the failing nightly ([#eng-builds](https://…))
   ```

5. Records every 👀 seen this run in the state file, so items are never added
   twice even after you check them off.

Trello is intentionally not touched: `trello-daybook-sync` phase 1b turns
unchecked, unmarked `- [ ]` lines into Today cards on its next 07:00 run and
stamps the card ID back onto the line. From then on the item follows the normal
lifecycle — check it off, and phase 1 moves the card to Done.

**First-run guard**: with no state file, `--since-days` (default 7) limits the
import to the last week so a long-standing 👀 history doesn't flood today's
list. Everything older is recorded as seen. The window applies only when the
state file is absent.

## Instructions

### Step 1: Preview without writing anything

```bash
bash ~/.claude/routines/slack-eyes.sh --dry-run
```

Prints the To Do lines it would add as JSON. Touches neither Joplin nor state.

### Step 2: Run it

```bash
bash ~/.claude/routines/slack-eyes.sh
```

The wrapper loads `~/.config/.env.*` secrets and picks an interpreter that
actually has `requests` (launchd's minimal PATH does not).

Useful flags:

| Flag | Effect |
|------|--------|
| `--dry-run` | Print lines; write nothing |
| `--since-days N` | First-run age window (default 7) |
| `--all` | No age window — every unseen 👀 item |

### Step 3: Report

Summarise the JSON: how many 👀 items exist, how many were new, and the To Do
lines added. Don't paste the whole daybook note back.

## Scheduling

`com.workflow.slack-eyes` runs it weekdays at **08:25**, five minutes before
`com.workflow.daybook-interview`. The offset is deliberate — the interview opens
an interactive Claude session that edits the same note, and concurrent
read-modify-write cycles would clobber each other.

Logs: `~/.claude/routines/logs/slack-eyes.log`

## Notes
- Removing the 👀 in Slack does **not** remove the To Do item. The flow is
  one-way by design; delete the line (or the Trello card) to drop it.
- Channels the token can't see (private channels, group DMs — the token has
  `channels:read` only) fall back to showing the raw channel ID.
- Message text is flattened to one line and truncated to 90 characters.
