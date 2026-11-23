# Skill: Gmail ⭐ → Daybook To Do

## When to Use
Use this skill when the user wants starred Gmail messages pulled into their To
Do list. Trigger phrases include: "pull my starred emails", "gmail stars",
"what have I starred", "import starred mail".

## Prerequisites
- The google-docs MCP login at `~/.config/google-docs-mcp/token.json`. Its
  refresh token must carry a Gmail scope (`gmail.modify` or `gmail.readonly`).
- `GOOGLE_CLIENT_SECRET` in the environment (`~/.config/.env.GOOGLE_CLIENT_SECRET`)
- The Gmail API turned on in the Google Cloud project that owns that client.
  `PERMISSION_DENIED ... has not been used in project` means it is off.
- `JOPLIN_TOKEN` set, and Joplin desktop running (REST API on port 41184)
- `~/.claude/skills/slack-eyes/eyes.py` and
  `~/.claude/skills/trello-daybook-sync/sync.py` present — `stars.py` imports
  the daybook note and To Do helpers from them
- Python 3.11+ with `requests`

## How It Works

`stars.py` (same directory as this file):

1. Exchanges the refresh token for a short-lived access token.
2. Lists starred message IDs (`is:starred`, up to 1000).
3. Skips IDs already in `~/.claude/routines/state/gmail-stars.json`.
4. Reads the Subject and From headers of the rest, and appends one item per
   message to the end of the `# To Do ✅` section of today's daybook note:

   ```
   - [ ] ⭐ Q3 budget review (Pat Lee [link to Gmail thread])
   ```

5. Records every starred ID in the state file, so an item is never added twice.

It is read-only on Gmail. It never unstars or relabels anything.

Subjects and sender names come from whoever sent the mail, so the script strips
`<`, `>`, `[`, `]`, backticks, `|` and leading list markup before it writes the
line. That stops a subject such as `<!-- trello:ID -->` from posing as a Trello
card marker for `sync.py`. Only the sender's display name is kept, never the
address.

**First-run guard**: with no state file, only stars on mail received in the
last `--since-days` (default 7) are imported. Gmail does not record when a
message was starred, so the received date is the best available proxy. Older
stars are recorded as seen. After the first run, any newly starred message is
imported, however old the mail is.

## Instructions

### Preview without writing anything

```bash
export JOPLIN_TOKEN=$(cat ~/.config/.env.JOPLIN_TOKEN)
export GOOGLE_CLIENT_SECRET=$(cat ~/.config/.env.GOOGLE_CLIENT_SECRET)
/usr/bin/python3 ~/.claude/skills/gmail-stars/stars.py --dry-run
```

| Flag | Effect |
|------|--------|
| `--dry-run` | Print lines; write nothing |
| `--since-days N` | First-run age window (default 7) |
| `--all` | No age window on a first run |

Report the counts and the new lines. Do not paste the daybook note back.

## Scheduling

`trello-daybook-sync.sh` (weekdays 07:00) runs `stars.py` before `sync.py`, so
the new items become Trello Today cards in the same run. A Gmail failure does
not stop the Trello sync; it goes to the log and adds a warning line to the
Slack post.

Logs: `~/.claude/routines/logs/trello-daybook-sync.log`

## Notes
- Unstarring does not remove the To Do item. Delete the line or the Trello card.
- Links use `mail.google.com/mail/u/0`, so they open in the first signed-in
  Google account.
