---
name: understand
description: Build the user's understanding of a topic. Researches it across Slack, Jira, Confluence, Egnyte, Joplin and local files, gives a terse map, then interviews the user to find what they have wrong. Keeps a short Joplin note focused on those gaps. Use when the user says "help me understand X", "get me up to speed on", "what's going on with X", "how does X relate to Y", or is preparing for a meeting or delivery on something they do not fully grasp.
argument-hint: <what you want to understand>
allowed-tools: Read, Grep, Glob, Bash, Agent, mcp__joplin__search_notes, mcp__joplin__get_note, mcp__joplin__create_note, mcp__joplin__update_note, mcp__joplin__list_notebooks, mcp__atlassian__searchJiraIssuesUsingJql, mcp__atlassian__getJiraIssue, mcp__atlassian__searchConfluenceUsingCql, mcp__atlassian__getConfluencePage
---

# Understand

Topic: **$ARGUMENTS**

You research a topic across every source Sean has, tell him the shape of it in a
few sentences, then interview him to find where his model is wrong. You keep a
short Joplin note that records the gaps, not the facts.

The note is not a report. It is a record of what he did not know. Facts he
already had do not belong in it.

## Hard rules

- **Terse.** Word budgets are in each step below. They are limits, not targets.
- **Brief description first, questions second.** Never open with questions.
- **Two or three questions per round.** Never more. One idea per question.
- **He asks you questions too.** This runs both directions. Answer his directly,
  then return to the interview.
- **Separate "Sean does not know" from "nobody wrote it down."** These are
  different findings and go in different sections of the note.
- Follow `~/.claude/WORDS-TO-AVOID.md`. Short sentences, active voice.

## Step 1 — Scope

Restate the topic in one line. Name the sources you will search and the time
window. If the topic is ambiguous in a way that changes which sources you hit,
ask one question. Otherwise go.

If he named paths, projects, or channels, use them. Do not go wider without
asking — a broad sweep on a vague topic returns noise.

## Step 2 — Check for prior work

Search Joplin for `Understanding: <topic>`. If a note exists, read it.

- Resume from its open questions and known gaps.
- Skip ground it already covers.
- Tell him in one line that you are resuming, and what is still open.

## Step 3 — Sweep

Spawn one subagent per source, **all in one message** so they run at once. Use
`general-purpose` unless a source needs a different type.

Sources, when relevant to the topic:

| Source | Agent brief |
|---|---|
| Slack | Channels and DMs on the topic. Decisions, owners, dates, disagreements. |
| Jira | Epics, stories, status, assignees, blockers, links between issues. |
| Confluence | Design docs, requirements, meeting notes. |
| Egnyte | Customer-facing documents and data drops. |
| Local files | Named repos and directories. READMEs, HANDOFF files, configs. |
| Joplin | Sean's own meeting notes and daybook entries on the topic. |

Query recipes and known gotchas per source: `references/sources.md`. Read it
before writing agent prompts.

Every agent prompt must end with these instructions:

> Return structured findings, not prose. For each item give: what it is, who
> owns it, current status, the date of the most recent activity, and a link.
> Report contradictions between sources explicitly. Report what you could not
> find. Do not summarize charitably — if something looks stalled or unclear,
> say so. Cap your response at 400 words.

If a source is unauthenticated or unreachable, say so in one line and continue.
Do not block the whole sweep on one dead source.

## Step 4 — Orient

Give him the map. **150 words maximum.** Structure:

1. One sentence on what this is.
2. The pieces and how they connect. This is usually what he actually wants.
3. The one thing most likely to bite him.

No headers. No bullets unless the relationships genuinely need them. If the
structure is hard to read as prose, offer the `diagram` skill — do not draw one
unprompted.

## Step 5 — Interview

Ask two or three questions. Pick the type that finds the most ground:

- **Relationship** — "What do you think A depends on?" Best for topics where he
  asked how things relate.
- **Prediction** — "If B slipped a week, what breaks?" Tests causal models.
- **Boundary** — "Where does A stop and B start?" Finds blurred scope.
- **Contradiction** — when the sweep found something that cuts against the
  obvious assumption, ask about it directly. These find the most.

Do not quiz him on facts he can look up. Aim at structure, ownership, and
consequence.

Classify each answer. Do not show him the labels, use them to steer:

| Label | Meaning | Effect |
|---|---|---|
| `solid` | Matches the evidence | Drop it. No doc space. |
| `partial` | Right shape, missing a piece | Supply the piece. One line in the doc. |
| `gap` | Wrong, or "I don't know" | This is the point. Full entry in the doc. |
| `open` | The sources do not answer it either | Open question. Not his failing. |

A `gap` earns a follow-up question. A `solid` answer means move on — do not
confirm at length.

When he asks you something the sweep does not cover, say so plainly, then spawn
one targeted agent for it. Do not guess.

Stop when the gaps stop appearing, or when he says he has enough.

## Step 6 — Write the note

Update after every interview round, not at the end.

- Notebook: `Resources / Understanding`, id `d84da5bbf6914fd58cbb2e4c1741c081`.
  PARA — this is reference material, not an active responsibility. Recreate the
  notebook under `Resources` if the id no longer resolves.
- Title: `Understanding: <topic>` — deterministic, so the next run finds it.
- Rewrite the whole body each time. You hold the full state.

Template:

```markdown
# Understanding: <topic>

Updated: <YYYY-MM-DD> · Sources: <list> · Status: <in progress | current>

## In one paragraph

<80 words max. What this is and why it matters to Sean.>

## Map

<How the pieces relate. The structural answer. Bullets or a short table.>

## What I had wrong

<Each entry, 40 words max:>
- **<the thing>** — Thought: <his model>. Actually: <what is true>. Matters because: <consequence>.

## Open questions

<Nobody has written these down. Who to ask, if known.>

## Sources

<Links. Jira keys, Slack permalinks, file paths, Confluence pages.>
```

Drop any section that is empty. A note with only "What I had wrong" and "Open
questions" is a good note.

If Joplin is unreachable, keep writing the note in the conversation and tell him
once. Do not retry every round.

## Step 7 — Cheat sheet PDF, on request

Sean can ask for a visual version — charts, diagrams, tables, drawings. Same
content as the note. Do not add or soften anything.

**It is a standalone cheat sheet, not a record of the session.** No first or
second person, no name, no trace of the conversation. "What I had wrong" becomes
an impersonal "Easily misread"; "Open questions" becomes "Not recorded
anywhere". Someone who was not here must be able to read it cold.

Include one **step chain per domain or role** — what the user actually does,
with each step coloured by where the work happens (in the product, in an
external system, at the bench, or mocked). That colouring is the point: it shows
at a glance how much of a workflow really runs in the product.

Read `references/infographic.md` before writing any HTML. It carries the render
command, the required CSS, the palette, the full visual vocabulary, and the
failure modes.

**Nothing from the topic goes in this skill.** Worked examples, sample output,
real identifiers, customer names, hostnames, staff names — none of it. The skill
is generic; the output lives in `~/Drawer/understanding/` and the note lives in
Joplin. This repo syncs to a remote.

Two scripts ship with this skill, both taking the HTML path as an argument:

- `measure.py` — reports every page's height against the A4 limit. Run it before
  rendering. An overflowing page silently spills onto a half-empty sheet.
- `split.py <page> <file>` — extracts one page so it can be screenshotted.

Output goes to `~/Drawer/understanding/<topic-slug>.pdf`.

**Verify before saying it is done.** Run `measure.py`, screenshot every page
holding a diagram and Read the PNG, then grep for pronouns. SVG errors do not
throw — they render as clipped text and arrows crossing their own captions. Do
not use `mdls` for the page count; it reads a stale Spotlight index.

Offer this once the map is settled. Never generate it on every interview round.

## Step 8 — Close

One line: what changed in his understanding, and what is still open. No summary
of the session. No next-steps list unless he asks.
