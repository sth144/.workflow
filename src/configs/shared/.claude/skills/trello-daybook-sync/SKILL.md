# Skill: Sync Trello Today to Joplin Daybook

## When to Use
Use this skill when the user wants to sync their Trello "Today" list to
the Joplin daybook. Trigger phrases include: "sync today", "sync trello",
"morning sync", "pull today cards", "update daybook from trello".

## Prerequisites
- Trello API credentials must be available as environment variables:
  `TRELLO_API_KEY` and `TRELLO_TOKEN`
- The Joplin MCP server must be connected
- The Trello board is https://trello.com/b/6ojrU8H2/work
  - Board ID (full): `637bc2c4c1b37201db9e5b0d`
  - "Today" list ID: `637bc2f8722fe72795105471`

## Instructions

### Step 1: Fetch Trello "Today" cards

Use `curl` via Bash to fetch cards from the Today list:

```bash
curl -s "https://api.trello.com/1/lists/637bc2f8722fe72795105471/cards?key=${TRELLO_API_KEY}&token=${TRELLO_TOKEN}&fields=name,due,labels,idShort,id"
```

Parse the JSON response. For each card, extract:
- `id` — full card ID (used as hidden marker for idempotency)
- `idShort` — short numeric ID
- `name` — card title
- `due` — due date (may be null)
- `labels` — array of label objects

### Step 2: Find or create today's Joplin daybook note

1. Format today's date as `DD Mon, YYYY` (e.g., `20 Apr, 2026`)
2. Search Joplin for a note with that exact title in `Areas / Daybook`
   (notebook ID: `c8ed0dc13a1f4269a66fe7d0d53ea07e`)
3. If the note does not exist:
   - Find the most recent daybook entry
   - Read its body to get any incomplete To Do items (`- [ ] ...`)
   - Create the new note with the structure below
4. If the note exists, read its full body

### Step 3: Build the To Do section

Generate a `## To Do` section with one checkbox per Trello card:

```markdown
## To Do

- [ ] Card name <!-- trello:CARD_ID -->
- [ ] Another card <!-- trello:CARD_ID -->
```

**Rules for merging:**
- If the daybook note already has a `## To Do` section, merge intelligently:
  - Keep existing checked items (`- [x] ...`) as-is
  - Keep existing unchecked items that have a `<!-- trello:ID -->` marker if that
    card is still in the Today list
  - Add new cards from Trello that aren't already in the list
  - Remove trello-marked items whose cards are no longer in the Today list
    (they were moved to another list)
  - Preserve any manually-added items (lines without `<!-- trello:... -->`)
- If no `## To Do` section exists, create one

### Step 4: Ensure Worklog section exists

If the note doesn't already have a `## Worklog` section, append one:

```markdown
## Worklog

```

The Worklog section should always be below the To Do section.

### Step 5: Update the Joplin note

Write the updated body back to the Joplin note using the update_note tool.
Never overwrite existing worklog entries or other content below `## Worklog`.

### Step 6: Report results

Display a summary:
- How many cards were synced from Trello
- How many were new vs already present
- How many checked-off items were preserved
- Any cards that were removed (no longer in Today)

## Example Output

```
Synced 7 cards from Trello "Today" to daybook (20 Apr, 2026):
  - 3 new cards added
  - 2 already present (unchanged)
  - 2 checked-off items preserved
  - 1 removed (no longer in Today list)
```

## Error Handling
- If Trello API returns 401: suggest updating TRELLO_API_KEY and TRELLO_TOKEN
  environment variables (tokens may have expired)
- If Joplin MCP is unavailable: report the error and suggest checking the server
- If no cards in Today list: create the daybook note with empty To Do section
  and report "No cards in Today list"
