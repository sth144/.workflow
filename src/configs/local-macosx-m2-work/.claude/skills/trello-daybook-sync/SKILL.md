# Skill: Sync Trello Today <-> Joplin Daybook

## When to Use
Use this skill when the user wants to sync their Trello "Today" list with
the Joplin daybook. Trigger phrases include: "sync today", "sync trello",
"morning sync", "pull today cards", "update daybook from trello".

## Prerequisites
- Trello API credentials must be available as environment variables:
  `TRELLO_API_KEY` and `TRELLO_TOKEN`
- `JOPLIN_TOKEN` must be set in the environment
- Joplin desktop app must be running (REST API on port 41184)
- Python 3.11+ with `requests` installed

## How It Works

The sync script (`sync.py`, in the same directory as this file) runs these phases:

1. **Phase 1 (Joplin -> Trello)**: Finds checked items in the daybook's
   `# To Do ✅` section that have `<!-- trello:CARD_ID -->` markers, and
   moves those cards to the Done list in Trello. Strips the marker from
   moved items so they're preserved as plain completed items.

2. **Phase 1a (Joplin -> Trello, "punt")**: Finds items marked `- [>]` and
   pushes them onto the Trello **Backlog** list with a due date 14 days out
   (override with the `PUNT_DAYS` env var). The line is removed from the
   daybook checklist — the Trello card becomes the only copy. An item that
   already has a `<!-- trello:CARD_ID -->` marker is moved to Backlog rather
   than duplicated. A failed punt stays in the checklist to retry next run.

3. **Phase 1b (Joplin -> Trello)**: Finds manually-added unchecked items
   (`- [ ]` lines with no `<!-- trello:... -->` marker) and creates a card
   for each in the Today list. Stamps the new card's ID back onto the
   Joplin line so it's tracked on future syncs.

4. **Phase 2 (Trello -> Joplin)**: Fetches the current Today list from
   Trello and merges it into the daybook's `# To Do ✅` section. Adds new
   cards, preserves existing items, removes cards no longer in Today.

If today's daybook note doesn't exist, it creates one and carries forward
incomplete to-do items (`- [ ]` and `- [>]`) from the most recent prior entry.

### Punting an item

To push a to-do out of today and onto the Backlog, change its checkbox to `>`:

```markdown
# To Do ✅

- [ ] Review the APPS-25608 patch
- [>] Write up the Q4 migration plan     <- punt this one
```

The next sync creates a Backlog card due in 14 days and drops the line.

## Instructions

### Step 1: Run the sync script

```bash
# Use an interpreter that has `requests` — bare `python3` may resolve to one
# without it (e.g. Homebrew/pyenv). System python (/usr/bin/python3) ships with it.
/usr/bin/python3 ~/.claude/skills/trello-daybook-sync/sync.py
```

Capture the JSON output.

### Step 2: Present the results

Parse the JSON output and display a human-readable summary. The output
has this structure:

```json
{
  "status": "ok",
  "title": "23 Apr, 2026",
  "note_id": "abc123",
  "created": false,
  "phase1": {
    "moved": 2,
    "failed": []
  },
  "phase1a_punted_to_backlog": {
    "punted": 1,
    "due": "2026-11-07T05:59:00.000Z",
    "failed": []
  },
  "phase1b_new_to_trello": {
    "created": 1,
    "failed": []
  },
  "phase2": {
    "added": 3,
    "kept": 2,
    "removed": 1,
    "checked_preserved": 4
  }
}
```

**Format the summary like this:**

```
Synced Trello <-> Joplin daybook (23 Apr, 2026):

  Joplin -> Trello:
  - 2 completed cards moved to Done
  - 1 punted to Backlog, due 6 Nov
  - 1 new manual item created as a Today card

  Trello -> Joplin:
  - 3 new cards added
  - 2 already present (unchanged)
  - 1 removed (no longer in Today list)
  - 4 checked-off items preserved
```

Omit a phase section if it had no activity. If the note was newly created,
mention that.

## Error Handling

If the script returns `{"status": "error", "error": "..."}`, display the
error message and suggest:
- **Missing env vars**: check that `TRELLO_API_KEY`, `TRELLO_TOKEN`, and
  `JOPLIN_TOKEN` are set
- **Connection errors to Joplin**: verify Joplin desktop app is running
- **401 from Trello**: tokens may have expired, regenerate them
- **Card move failures**: listed in `phase1.failed[]` with card name and ID
