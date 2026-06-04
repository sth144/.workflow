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

## Step 2 — Triage before interviewing

Show me the full list once, numbered, noting which note (date) it came from.
Then ask **one** question: which of these are realistically for *today*?
Everything else stays parked — don't interview me about parked items. The point
is a usable plan, not a march through every checkbox.

## Step 3 — Interview, one item at a time

For each item I flagged for today, work through it conversationally. Ask **one
question per turn**, and only the questions that actually matter for that item.
You're trying to surface:

- **Definition of done** — what does "finished" look like, concretely?
- **First action** — the single next physical step to start it.
- **Blockers / dependencies** — is a person, review, env, or decision in the
  way? Is it actually startable today?
- **Rough size** — a quick ballpark (15 min / 1 hr / half day). Don't push for
  precision.

Skip questions already obvious from the item text. Keep it brisk — a sharp
standup, not an interrogation. If I give a thin answer and the item clearly
needs more, follow up once, then move on.

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

When we've been through the today items, summarize:

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
