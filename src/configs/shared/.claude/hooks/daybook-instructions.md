# Daybook Update Instructions

Before stopping, check and update today's daybook note.

## Find or Create Today's Note

1. Search Joplin for today's note in `Areas / Daybook` (title format: `DD Mon, YYYY`)
2. If it exists, read it and append any work not already covered
3. If it doesn't exist, create it:
   - Search `notebook:Daybook` and find the MOST RECENT dated note (compare dates, don't assume first result)
   - Extract ALL unchecked items (`- [ ] ...`) from that note — count them explicitly
   - Create new note with sections: `# To Do ✅` and `# Worklog 📝`
   - Paste ALL unchecked items under To Do (preserve exact text and indentation)
   - Verify the count matches before proceeding

## Trello Today Sync (Trello → Joplin)

1. Fetch cards from Trello "Today" list (ID: `637bc2f8722fe72795105471`)
2. For each card, check if it exists in To Do (look for `<!-- trello:CARD_ID -->` markers)
3. Add NEW cards as: `- [ ] Card name <!-- trello:CARD_ID -->`
4. Keep all existing items (trello-marked and manual) as-is
5. Do NOT remove items whose cards left Today list

## Trello Completion Sync (Joplin → Trello)

1. Find CHECKED items with trello markers: `- [x] ... <!-- trello:CARD_ID -->`
2. Move each card to Done list (ID: `637bc2c4c1b37201db9e5b16`) using `trello_update_card`
3. After successful move, strip the `<!-- trello:... -->` marker (keep checkmark)
4. If move fails, leave marker intact for retry

## Worklog Entry

Add under `# Worklog 📝`: `- HH:MM — <one-sentence summary>`

Use the time from the hook message. Include screenshot link if visual changes were made.
Skip logging if session was trivial (casual chat, no code/config changes).
