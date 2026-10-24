---
name: diagram
description: Draw a mermaid diagram of something complex — a bug's causal chain, a sequence of events across components, a state machine — and spool it for viewing with ⌘⌃V instead of printing it in chat. Use when the user says "draw that", "diagram this", "show me a diagram", or when an explanation involves three or more components with an ordering or state dependency between them that prose alone renders badly.
argument-hint: (what to diagram; defaults to what was just explained)
---

# Diagram

Turn something you just explained into a diagram, without putting diagram
syntax in the chat.

## The Rule That Matters

**Never print mermaid source in your response.** A wall of syntax in the middle
of an answer is harder to read than the prose it was supposed to illustrate.
Source goes to the spool; the chat gets one line.

## When To Draw One

Draw when the thing being explained has **three or more actors with an ordering
or state dependency between them**. That is the shape prose genuinely fails at,
because the reader has to hold a sequence in their head while parsing sentences.

Good candidates:

- A bug whose cause is a race, an ordering, or a "who got there first"
- A sequence crossing process/service/schedule boundaries
- A lifecycle with states and transitions
- A retry/fallback path with more than one failure branch

Do **not** draw for:

- A list of independent findings ("these three scripts share a bug") — that is a
  list, and a diagram of it is noise
- A two-actor call ("the script calls the API")
- Anything the prose already made clear in a sentence or two
- Restating a file tree or a package layout

When in doubt, don't. An unwanted diagram costs the user attention; a missing
one costs them nothing they can't ask for.

## Diagram Types

Six types, each the natural shape for something specific:

| Type | Use for |
| --- | --- |
| `sequenceDiagram` | ordering across components — who did what, when, and what it broke |
| `stateDiagram-v2` | lifecycles: states and transitions, including nested states and fork/join |
| `mindmap` | decomposing a concept, where the structure is hierarchy rather than flow |
| `flowchart` | a pipeline or decision path that genuinely branches |
| `C4Deployment` | what runs where, and which piece talks to which |
| `erDiagram` | data shape: entities and the relationships between them |

A longer type list does not mean more diagrams. The rule above still decides
*whether* to draw; this only decides *what shape* once that rule says yes.

Be most suspicious of `flowchart`. It is what a model reaches for when it has
nothing specific to show, and a flowchart of steps that never branch is just a
numbered list drawn badly — write the list instead.

Mermaid supports plenty more (gantt, timeline, kanban, journey, pie, quadrant,
sankey, class, requirement, gitGraph, treemap, radar, and so on). Those are
reporting formats rather than explanations: use them only when the user asks
for one by name.

## How To Draw One

Do the drafting in a **subagent** so neither the reasoning nor the source
reaches the main thread. Run it in the background (`run_in_background: true`)
when the diagram falls out of other work; run it synchronously when the user
asked for a diagram and is sitting there waiting for it.

Tell the subagent not to validate in a browser. The viewer already falls back to
showing source plus the parse error, so a broken diagram is visible, not silent
— one `--file` render is all the checking that is warranted. Drafting should
take a handful of tool calls, not twenty.

Give the subagent the facts it needs and have it run:

```bash
/usr/local/bin/diagram/render_mermaid.py --save "<short title>" <<'MERMAID'
sequenceDiagram
    participant a as First actor
    ...
MERMAID
```

It prints the spooled path. The subagent's whole reply back to you should be
that path or a one-word status.

Then your visible output is one line, after the conclusion, never before it:

```
◈ diagram: carry-forward timeline — ⌘⌃V
```

If the user asked for the diagram explicitly, that line is the whole response.

## Syntax Gotchas

- Do not use `note`, `end`, `activate`, or `state` as a participant id — they
  collide with keywords and the diagram will not parse. Alias instead:
  `participant nb as Daybook note`.
- In `timeline` and anywhere else that uses `:` as a separator, a label
  containing a colon (`07:00`) breaks the parse. Inside a `sequenceDiagram`
  participant alias it is fine.
- Keep labels short. They are read at a glance, and long ones force mermaid
  into wide layouts that need scrolling.
- Times and colons inside an alias are fine (`as slack-eyes 08:25`).

## Viewing

⌘⌃V (Hammerspoon) shows the newest spooled diagram in a floating native window.
While it is up:

| Key | Does |
| --- | --- |
| `⌘C` | copy the diagram as an image |
| `⌘⇧C` | copy the mermaid source |
| click, `escape`, `⌘⌃V` | dismiss |

The first view rasterises the mermaid to a PNG and caches it next to the `.mmd`,
so later views are just an image. A malformed diagram falls back to showing its
source and the parse error rather than failing — a broken illustration should
never become a problem to deal with.

The spool lives in `~/.cache/.workflow/diagrams/`, pruned to the last 20 and to
24 hours. It is scratch: the durable copy of a diagram is whatever gets written
into the daybook.

## Putting One In The Daybook

When a diagram explains something worth keeping — a bug's causal chain, a design
decision — embed it in that day's worklog entry, indented under the entry it
belongs to. Joplin renders mermaid in its markdown viewer.

Follow the write-safety rules in `~/.claude/hooks/daybook-instructions.md`:
`get_note` first, append to the body verbatim, never retype it.
