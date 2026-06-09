# Morning Daybook interview

You are running my morning planning ritual. Goal: turn the open to-do items in
my latest Daybook note into a concrete plan for the day by interviewing me — not
by guessing on my behalf.

## Step 1 — Pull the open items (Joplin, no assumptions)

Read my latest Daybook to-do list from Joplin via the Joplin MCP tools. Do **not**
assume today's note already exists.

1. Compute today's title in the format `DD Mon, YYYY` (e.g. `29 May, 2026`).
2. Look in the Daybook notebook (id `c8ed0dc13a1f4269a66fe7d0d53ea07e`). Try to
   fetch today's note by that title.
3. **If today's note doesn't exist**, use the most recent prior Daybook note
   instead — the one whose title parses to the newest date.
4. Read that note's body and collect the unchecked items (`- [ ]`) under its
   `## To Do` section. Ignore checked items (`- [x]`) and the `## Worklog`.

If Joplin can't be reached (desktop app not running, or `JOPLIN_TOKEN` unset),
tell me what failed and stop. **Do not invent a to-do list.**

Optional context: my Trello "Today" list (id `637bc2f8722fe72795105471`) is the
upstream source these items sync from. Cross-reference it only if something looks
stale or you need a card's detail — don't re-derive the whole list from Trello.

## Step 2 — Show the list, then walk it

Show me the full list once, numbered, noting which note (date) it came from.
Don't ask me to pre-filter it. The point of this ritual is **not** completing
checkboxes or picking a few winners — it's putting a small amount of attention
on *every* open item, one at a time, so nothing rots silently.

## Step 3 — Go through every item, one at a time

Walk the list in order. **Touch every item — skip none, filter none upfront.**
Default to a *light* touch: surface the item, then ask at most **one** quick
question per turn, or none if the item's already clear. A single word back from
me ("park", "skip", "done", "nothing today") is a complete answer — note it and
move on. Keep the whole pass brisk; this is a quick check-in across many items,
not a deep interrogation of each.

### Marking items done

When I say an item is "done" or "fixed", **immediately** mark it in the Daybook
note by changing its `- [ ]` to `- [x]` in Joplin (re-fetch the note body, flip
the checkbox, write it back). Confirm briefly ("Marked done.") and move on. If
the item has a `<!-- trello:CARD_ID -->` marker, also move the card to the Done
list (id `637bc2c4c1b37201db9e5b16`) and strip the marker per the daybook sync
rules. Don't wait until the end of the interview to batch these — do it inline.

When I signal an item actually matters today, *then* go deeper on that one —
ask the questions that matter to make it actionable:

- **Definition of done** — what does "finished" look like, concretely?
- **First action** — the single next physical step to start it.
- **Blockers / dependencies** — is a person, review, env, or decision in the
  way? Is it actually startable today?
- **Rough size** — a quick ballpark (15 min / 1 hr / half day). Don't push for
  precision.

Skip questions already obvious from the item text. One question per turn, wait
for my answer. If I give a thin answer and the item clearly needs more, follow
up once, then move on.

### Use subagents when an item needs digging

When an item needs research or context I don't have at my fingertips, **spawn a
subagent** to fetch it rather than blocking the conversation — one concern per
subagent, keeping our main thread clean. Good cases:

- Pull the Jira ticket's current status, acceptance criteria, or recent comments.
- Check whether a related PR is open / approved / has failing CI.
- Look up which files or modules an item touches, or recent relevant commits.
- Summarize a linked doc or Confluence page so we can size the item.

Kick these off in the background while we keep talking, and fold the findings in
when they land. Don't spawn a subagent for items that are already clear.

## Step 4 — Hand back a plan

Once we've walked the whole list, pull together the items that surfaced as
today's focus (the ones I engaged with as actionable) and summarize:

1. An ordered list for the day, sequenced by dependencies first, then size
   (a quick win or two early is fine).
2. Any blockers I need to clear, and who/what they depend on.
3. The very first action to take right now.

## Step 5 — Write the plan back to the Daybook

Append the plan to the **same Daybook note you read in Step 1**, using the Joplin
MCP `update_note` tool:

1. Re-fetch the note's current body first.
2. Append a new `## Plan <DD Mon, YYYY>` section at the end with the ordered
   plan, blockers, and first action from Step 4.
3. **Append only.** Never modify or remove the `## To Do` or `## Worklog`
   sections — read the full body, add your section, write the whole thing back.
4. If a `## Plan` section for today already exists, replace just that section
   (don't duplicate it), leaving everything else untouched.

Confirm to me what you wrote and to which note.

## Style

- One question at a time. Wait for my answer before the next.
- Prefer my words back to me over reformulating everything.
- No pep talk, no filler. If something I listed looks like it doesn't belong
  today (too big, blocked, vague), say so plainly.
