# Source recipes

Query patterns and known gotchas for each source the `understand` skill sweeps.
Read this before writing subagent prompts.

---

## Slack

Full API reference: `~/.claude/skills/slack/SKILL.md`. Helpers:
`~/.claude/routines/lib/slack.sh`. Token: `~/.config/.env.SLACK_USER_TOKEN`.

**Gotcha — `search.messages` does not work.** The user token lacks the
`search:read` scope. It has `search:read.mpim` only, which is not enough. Any
agent that reaches for `search.messages` burns a turn on `missing_scope`.

Use channel enumeration instead:

```bash
TOKEN=$(cat ~/.config/.env.SLACK_USER_TOKEN)
# find channels by name fragment
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://slack.com/api/conversations.list?types=public_channel,private_channel&limit=1000" \
  | python3 -c "import json,sys; [print(c['id'], c['name']) for c in json.load(sys.stdin)['channels'] if TERM in c['name']]"

# read history (oldest is a unix timestamp)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://slack.com/api/conversations.history?channel=$CID&oldest=$TS&limit=200"
```

For a DM, resolve the channel with `conversations.open -F users=<UID>`. Find
user IDs by paginating `users.list` with `cursor` — one page does not cover the
workspace.

Replies live in threads. A message with `reply_count` needs
`conversations.replies?channel=$CID&ts=$TS` to get the real discussion.

Permalinks for the note: `chat.getPermalink?channel=$CID&message_ts=$TS`.

---

## Jira

Tools: `mcp__atlassian__searchJiraIssuesUsingJql`, `mcp__atlassian__getJiraIssue`.
Get `cloudId` from `mcp__atlassian__getAccessibleAtlassianResources` first.

Workstream sweep patterns:

```
# everything active on a label or component
labels = "<topic>" AND resolution = Unresolved ORDER BY updated DESC

# epic and its children
"Epic Link" = APPS-12345 ORDER BY status

# what moved recently — finds the live workstreams
project = APPS AND labels = "<topic>" AND updated >= -14d ORDER BY updated DESC

# blocked work
project = APPS AND labels = "<topic>" AND status = Blocked
```

For relationships between workstreams, read `issuelinks` on each epic. That is
where "blocks" and "depends on" live. Status alone will not show you the
structure.

Project key is `APPS`.

---

## Confluence

Tools: `mcp__atlassian__searchConfluenceUsingCql`, `mcp__atlassian__getConfluencePage`.

```
text ~ "<topic>" AND type = page ORDER BY lastmodified DESC
space = "ENG" AND text ~ "<topic>"
```

`getConfluencePageDescendants` pulls a whole doc tree when the topic has its own
page hierarchy. Prefer it over many single-page fetches.

---

## Egnyte

Tools: `mcp__claude_ai_Egnyte__*`. Requires OAuth — if only `authenticate` and
`complete_authentication` are exposed, the server is not connected. Report that
and move on. Do not start the OAuth flow mid-sweep without asking.

Customer data drops and deliverable documents live here. Worth searching when
the topic is customer-facing.

---

## Joplin

Tools: `mcp__joplin__search_notes` (hybrid mode by default), then
`mcp__joplin__get_note` for the full body of anything relevant.

Sean's own notes are a strong source. Meeting notes in `Meetings`, daily
worklogs in `Areas / Daybook`, project notes in topic notebooks.

Raise `keyword_weight` to about 0.7 for identifier queries (ticket keys, version
strings). Leave it at the default for conceptual queries.

**Gotcha — the clipper API on port 41184 must be running.** Joplin can be open
while the Web Clipper service is off, which makes every call time out. Check
with `curl -s -m 5 http://localhost:41184/ping` — it returns `JoplinClipperServer`
when healthy. If it hangs, tell Sean to enable Web Clipper in Joplin settings.

---

## Local filesystem

Ask which paths matter, or use the ones named in the prompt. Do not sweep all of
`~/Projects` — it is slow and returns noise.

Highest-value files first:

- `HANDOFF.md`, `HANDOFF-*.md` — written when work changed hands. Dense.
- `README.md`, `FEATURES.md` — intent.
- `desc.txt`, `*.json` manifests — what is actually configured.
- `git log --oneline -30` and `git log --since=14.days` — who did what, when.

Use ripgrep for content, not find:

```bash
rg -l "<term>" ~/Projects/<repo> --max-depth 4
git -C ~/Projects/<repo> log --oneline --since=30.days
```

Read excerpts. Do not paste whole files into the findings.
