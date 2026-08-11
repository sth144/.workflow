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

Use `sequenceDiagram` or `stateDiagram-v2`. Nothing else.

These two survive being read as plain text, which matters because the source is
what gets stored and what shows if rendering fails. Flowcharts and class
diagrams degrade into unreadable syntax, and they are also the shapes a model
reaches for reflexively when it has nothing real to show.

## How To Draw One

Do the drafting in a **background subagent** (`run_in_background: true`) so
neither the reasoning nor the source reaches the main thread. Give the subagent
the facts it needs and have it run:

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
- Keep labels short. They are read at a glance, and long ones force mermaid
  into wide layouts that need scrolling.
- Times and colons inside an alias are fine (`as slack-eyes 08:25`).

## Viewing

⌘⌃V (Hammerspoon) renders the newest spooled diagram into a floating webview,
and again to dismiss it. The viewer degrades to showing the source with the
parse error if the diagram is malformed — a broken illustration should never
become a problem to deal with.

The spool lives in `~/.cache/.workflow/diagrams/`, pruned to the last 20 and to
24 hours. It is scratch: the durable copy of a diagram is whatever gets written
into the daybook.

## Putting One In The Daybook

When a diagram explains something worth keeping — a bug's causal chain, a design
decision — embed it in that day's worklog entry, indented under the entry it
belongs to. Joplin renders mermaid in its markdown viewer.

Follow the write-safety rules in `~/.claude/hooks/daybook-instructions.md`:
`get_note` first, append to the body verbatim, never retype it.
