# Skill: Code Change Report

## When to Use

Use this skill when the user wants a concise markdown report that explains what
code changed, why it changed, what behavior is different, and what deserves
human review. Trigger phrases include: "write a report", "summarize the code
changes", "explain what you did", "handoff report", "audit report", and
"what should I review".

## Goal

Produce an explanation artifact for a human engineer, not a changelog and not
an agent diary.

The report must let the reader answer these questions quickly:

1. What changed?
2. Why did it change?
3. What behavior is different now?
4. What should I inspect closely?

## Output Rules

- Output markdown only.
- Stay aggressively concise.
- Prefer short sections over long prose.
- Use small before/after or focused-after code blocks, not whole files.
- Explain intent and effect, not line-by-line mechanics.
- Omit cosmetic edits unless they materially affect maintainability.
- State uncertainty plainly when behavior or intent is inferred.
- If nothing important changed, say so directly.

## Required Structure

Use this structure unless the user explicitly requests a different format:

```md
# Task Summary

One short paragraph covering the task, the main outcome, and whether the work is complete.

## If You Only Read 3 Things

- Most important change.
- Main behavior impact.
- Highest-value review point.

## Important Changes

### 1. Short change title
Why:
One or two sentences.

Changed:
```language
// minimal snippet
```

Impact:
One or two sentences on behavior, reliability, performance, or maintainability.

Review:
One sentence naming the main thing the human should verify.

## Behavior Changes

- Short bullets describing externally visible or operational differences.

## Risks / Tradeoffs

- Short bullets for meaningful risks, assumptions, or deferred work.

## Tests Run

- Commands run and what they proved.
```

## Selection Rules

- Include only the changes that matter to correctness, behavior, debugging,
  operability, or future maintenance.
- Collapse related low-level edits into one higher-level change.
- If more than three changes matter, include the top three and summarize the rest
  in one line.
- Prefer "after" snippets when the intent is obvious without a "before" snippet.
- Keep each explanation block to one to three sentences.

## Review Heuristics

Call out review points such as:

- edge-case logic
- retries, backoff, or timeout behavior
- migrations or config changes
- security or permission boundaries
- concurrency, ordering, or state transitions
- fallback behavior
- test coverage gaps

## Do Not Do This

- Do not paste raw diffs unless the user explicitly asks for diff format.
- Do not enumerate every touched file unless the file list itself matters.
- Do not explain trivial renames, formatting, or import sorting unless they have
  real impact.
- Do not write in a self-congratulatory tone.
- Do not bury risks after long summaries.

## Default Process

1. Inspect the meaningful code changes and tests run.
2. Group edits by behavioral intent, not by file.
3. Pick the smallest code snippets that prove each important change.
4. Write the markdown report using the required structure.
5. Trim aggressively until every section earns its space.
