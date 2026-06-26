# Daybook Update Instructions

Before stopping, check and update today's daybook note using the `mcp__joplin__*` tools.

## Find or Create Today's Note

1. Search Joplin for today's note in `Areas / Daybook` (title format: `DD Mon, YYYY`)
2. If it exists, read it (`mcp__joplin__get_note`) and append any work not already covered
3. If it doesn't exist, create it:
   - Search `notebook:Daybook` and find the MOST RECENT dated note (compare dates, don't assume first result)
   - Extract ALL unchecked items (`- [ ] ...`) from that note — count them explicitly
   - Create new note with sections: `# To Do ✅` and `# Worklog 📝`
   - Paste ALL unchecked items under To Do (preserve exact text and indentation)
   - Verify the count matches before proceeding

## Worklog Entry

Add under `# Worklog 📝`: `- HH:MM — <one-sentence summary>`

Use the time from the hook message. Always read the full note body first, then append —
never overwrite existing content.

Skip logging if the session was trivial (casual chat, read-only, no code/config changes).
