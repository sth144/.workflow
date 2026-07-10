# Daybook Update Instructions

Before stopping, check and update today's daybook note using the `mcp__joplin__*` tools.

Prefer delegating this maintenance to the `daybook-logger` subagent when
available. Ask it to update the Journal daybook note with the hook time and a one-sentence
summary of the completed task, then use only its compact status in the final
task response.

Keep this maintenance step quiet in chat: do not quote note contents, copied to-do
items, search results, or full Joplin tool responses unless the user asked for
them. After the note is updated, continue with the normal final task response.

## Find or Create Today's Note

1. Search Joplin for today's note in `Areas / Journal` (title format: `DD Mon, YYYY`)
2. If it exists, read it (`mcp__joplin__get_note`) and append any work not already covered
3. If it doesn't exist, create it:
   - Search `notebook:Journal` and find the MOST RECENT dated note (compare dates, don't assume first result)
   - Extract ALL unchecked items (`- [ ] ...`) from that note — count them explicitly
   - Create new note with sections: `# To Do ✅` and `# Worklog 📝`
   - Paste ALL unchecked items under To Do (preserve exact text and indentation)
   - Verify the count matches before proceeding

## Worklog Entry

Add under `# Worklog 📝`: `- HH:MM — <one-sentence summary>`

Use the time from the hook message. Always read the full note body first, then append —
never overwrite existing content.

Skip logging if the session was trivial (casual chat, read-only, no code/config changes).
