---
name: explain-pr
description: Explain a pull request as a visual artefact. Takes a Bitbucket or GitHub PR URL, reads the diff, commits, comments and any linked ticket, then builds either an infographic PDF or an interactive HTML page that shows what changed and why. For a bug fix it shows the broken behaviour before the fix next to the fixed behaviour. Use when the user says "explain this PR", "walk me through this pull request", "make a visual for this PR", "what does this PR do", or pastes a PR URL and wants more than a text summary.
argument-hint: <PR URL> [pdf | applet]
allowed-tools: Read, Grep, Glob, Bash, Write, Edit
---

# Explain PR

Pull request: **$ARGUMENTS**

You read a pull request end to end, work out what it actually changes, then build
a visual artefact that someone can understand without opening the diff.

The artefact is not a diff viewer. A reader who cannot read the language should
still come away knowing what the code now does that it did not do before.

## Hard rules

- **The before state is the point.** For a bug fix, the artefact fails if it does
  not show what went wrong before. Not the old code — the old *behaviour*.
- **Explain effects, not line edits.** "Retries now back off exponentially" beats
  "added a `for` loop in `client.py`".
- **Claim only what the diff supports.** When intent is inferred, mark it. Never
  invent a cause for a bug the diff does not evidence.
- **Self-contained output.** No CDN, no network, no build step. It must work from
  a `file://` URL and from a USB stick.
- Follow `~/.claude/WORDS-TO-AVOID.md`. Short sentences, active voice.

## Step 1 — Resolve the PR

Parse the URL into host, organization, repo and id. Both forms are supported:

| Host | URL shape |
|---|---|
| Bitbucket | `https://bitbucket.org/{org}/{repo}/pull-requests/{id}` |
| GitHub | `https://github.com/{org}/{repo}/pull/{id}` |

Fetch metadata, the full diff, the commit list and the review comments. Commands
and auth for both hosts: `references/fetch.md`. Read it before any API call.

If the diff is larger than about 2000 lines, say so and ask which parts matter.
Do not silently explain a quarter of a PR.

## Step 2 — Gather surrounding context

The diff says what changed. These say why. Pull the ones that exist, in parallel:

| Source | What to take |
|---|---|
| Linked ticket | The reported symptom, steps to reproduce, severity. The symptom drives the before state. |
| PR description and commits | The author's own account of the problem. Quote it, then verify it against the diff. |
| Review comments | Disputed decisions, follow-up work, known gaps. |
| The repo itself | Read the changed files at full length, not just the hunks. A three-line diff can change a contract. |
| Tests in the diff | A new test is the clearest statement of the bug. The assertion names the broken behaviour. |

Recipes per source: `references/fetch.md`. If a source is unreachable, note it in
one line and continue.

## Step 3 — Classify the change

Decide which kind this is. It picks the visuals.

| Kind | Signature | Lead visual |
|---|---|---|
| **Bug fix** | Restores intended behaviour | Before/after failure trace |
| **Feature** | Adds behaviour that did not exist | Step chain of the new capability |
| **Refactor** | Same behaviour, different structure | Before/after structure map |
| **Performance** | Same result, different cost | Before/after cost bars with the measured numbers |
| **Security** | Closes an exposure | Attack path, blocked at the fix point |

A PR can be more than one. Lead with the one that carries the most risk for a
reviewer, and give the others a section each.

## Step 4 — Find the before state

This is the step people skip. Do not skip it.

For a bug fix, reconstruct what actually happened before. The sources, strongest
first:

1. **The new test.** Check out the parent commit, apply only the test, run it.
   The failure output is the before state, in the program's own words.
2. **The removed or corrected code.** Trace it by hand. State the input that
   takes the old path to the wrong result.
3. **The ticket.** The reporter's symptom. Weakest — it describes what someone
   saw, not why.

Write the before state as a concrete trace: a specific input, the path it took,
the wrong output. "Empty list returns `None` instead of `0`, so the caller's
`+=` raises `TypeError`." Never "the function was buggy".

If you cannot establish the before state from evidence, say so in the artefact.
A box reading "cause not recorded in the PR" is honest and useful. A guess is
neither.

## Step 5 — Pick the format

Ask which one, unless the arguments already say. Offer both.

- **Infographic PDF** — a reference to read once and keep. Best for a reviewer
  preparing to approve, or a record attached to a ticket.
- **Interactive HTML** — a walkthrough to click through. Best for teaching the
  change to someone who did not write it, or a demo in review.

Read the matching reference before writing any HTML:

- `references/infographic.md` — render command, required CSS, palette, the PR
  visual vocabulary, failure modes.
- `references/applet.md` — component library, interaction patterns, data shape,
  CSS baseline, verification.

Both share the palette and the before/after conventions. Read both only if
building both.

## Step 6 — Build and verify

Write the HTML to the scratchpad. Only the finished artefact goes to
`~/Drawer/pr-explainers/`.

Output names, from the PR identity so a rebuild overwrites cleanly:

- `~/Drawer/pr-explainers/{repo}-{id}.pdf`
- `~/Drawer/pr-explainers/{repo}-{id}.html`

Two scripts ship with this skill, both taking the HTML path as an argument:

- `measure.py` — reports every page height against the A4 limit. Run it before
  rendering a PDF. An overflowing page spills silently onto a half-empty sheet.
- `split.py <page> <file>` — extracts one page so it can be screenshotted.

**Verification is not optional.** The per-format reference lists the checks. For
the PDF, that means running `measure.py`, screenshotting every page with a
diagram and reading the PNG, and grepping for pronouns. SVG errors do not throw;
they render as clipped text and arrows crossing their own captions.

For every format, one check comes before those: **read the artefact as if you
had not seen the diff.** If the before state is not obvious, rebuild it.

## Step 7 — Close

One line: what the PR does, and the one thing a reviewer should look at hardest.
Give the output path. No summary of the build.

## Secrets

The artefact leaves the machine — it gets attached to tickets and shared in chat.

- Never embed tokens, API keys, internal hostnames, customer names, or real user
  data pulled from fixtures or logs.
- Redact them if the diff itself contains them, and say so in the artefact.
- Nothing from any specific PR belongs in this skill directory. The skill is
  generic; the output lives in `~/Drawer/pr-explainers/`. This repo syncs to a
  remote.
