# PR interactive page

How to turn a pull request into a single-file walkthrough. One `.html`, opens in
a browser. No build step, no CDN, no network dependency.

## It is a walkthrough, not a diff viewer

The PDF is a briefing to read once. This is a thing to click through — the
reader drives, and the point is that they *watch the bug happen* before they see
the fix.

- **No first or second person.** Same rule as the PDF. No author or reviewer
  names.
- **Self-contained.** All CSS and JS inline. No imports, no fetch calls, no
  external fonts. Must work from a `file://` URL.
- **No persistent storage.** No `localStorage`. The file behaves the same way
  every time it is opened.

## Component library

Use only these. Pick the ones that match the change — most PRs need two or
three, not all of them.

### Before/after toggle — the signature component

Every bug-fix explainer has one. It is the interactive form of the failure trace.

- A single prominent switch: **Before** / **After**. Nothing else on the page
  moves when it flips except the trace.
- Flipping re-renders the same diagram with the other path lit: the before path
  in `#c2410c`, the after path in `#059669`.
- The step nodes stay in the same screen positions across both states. Only the
  colours, the final outcome node and the detail text change. If nodes move, the
  reader loses the comparison — this is the one rule that cannot bend.
- Show the triggering input above the switch, fixed across both states.
- Show the concrete outcome below: the actual error or the actual value, not a
  verdict.
- Default to **Before**. The reader should meet the bug first.

### Failure stepper

Best when the bug needs more than one step to understand.

- Walk the trace one step at a time, forward and back.
- Each step lights up and a panel below says what happens at that step, in which
  function, with what value.
- At the divergence step, the panel splits in two: what the old code did, what
  the new code does. Tint the halves with the before and after colours.
- Step indicator: `Step 3 of 6`. Arrow keys and buttons both work.
- After the last step, offer "replay as fixed" — the same walk down the after
  path.

### Change explorer

Best for PRs touching 4+ modules.

- Render the change map as clickable nodes in an SVG, sized by churn.
- Click a node for a panel: what the file does, what changed in it, why. One
  sentence each.
- Highlight nodes that call each other when one is selected. Dim the rest.
- Collapse mechanical churn into one node labelled "mechanical" that expands to
  a plain list. Do not let a lockfile dominate the layout.
- Hand-drawn SVG, no libraries. Same `viewBox` scaling rule as the PDF.

### Diff walkthrough

Best when the change really is in the code and the reader needs to see it.

- One hunk per card, ordered by importance, not by file path.
- Before and after side by side within the card. Six lines each, elided with
  `…`.
- A plain-language caption above each card saying what the change does.
- Next/previous through the hunks. Show `Hunk 2 of 7`.
- A "skip mechanical" toggle that filters to the hunks that change behaviour.

### Review quiz

Best for teaching a change to a team, or for a PR whose risk is easy to miss.

- Three to six questions, drawn from the real consequences of the change.
- Format: multiple choice, 3–4 options, one correct. Distractors must be
  plausible — pull them from the old behaviour, or from the approach that was
  considered and rejected.
- Favour prediction over recall: "Given input X, what did the old code return?"
  beats "Which file changed?".
- Immediate feedback: correct answer in the after colour, wrong pick in the
  before colour, with a one-sentence explanation.
- Track score. Show it as a badge on the tab afterwards.

## Layout

A single page with a tab bar. The reader picks one mode at a time — do not stack
every component in one scroll.

```
┌─────────────────────────────────────────────┐
│  {repo} #{id} — one-line summary            │
│  ─────────────────────────────────────────  │
│  [What broke]  [Walk it]  [Changes]  [Quiz] │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │         Active component here         │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Progress bar                               │
│  Base ref · commit sha · date               │
└─────────────────────────────────────────────┘
```

The first tab is the before/after toggle, and it is open on load. A reader who
clicks nothing still sees the bug.

Only show tabs for components that exist. A refactor with no bug has no "What
broke" tab — lead with the structure map instead.

## Palette

Same as the PDF. Screen display, so no `print-color-adjust` rule needed.

| Role | Hex | Usage |
|---|---|---|
| Ink | `#1a2332` | Body text, headings |
| Muted text | `#5b6b7f` | Captions, metadata, source citations |
| Hairline | `#d9e0e8` | Borders, dividers, inactive tabs |
| Panel tint | `#f5f7fa` | Card backgrounds, detail panels |
| Primary | `#2563eb` | Active tab, selected node, buttons |
| **After** | `#059669` on `#ecfdf5` | Fixed path, correct answers, added behaviour |
| **Before** | `#c2410c` on `#fff8f4` | Broken path, wrong answers, the failure |
| Caution | `#b45309` on `#fffbeb` | Inferred, not covered, follow-up work |

## CSS baseline

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  color: #1a2332;
  background: #ffffff;
  line-height: 1.5;
  max-width: 980px;
  margin: 0 auto;
  padding: 24px;
}
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 13px; }
button {
  cursor: pointer;
  border: 1px solid #d9e0e8;
  background: #ffffff;
  color: #1a2332;
  padding: 8px 16px;
  border-radius: 6px;
  font-size: 14px;
  transition: background 0.15s, border-color 0.15s;
}
button:hover { border-color: #2563eb; }
button.active { background: #2563eb; color: #ffffff; border-color: #2563eb; }
.tab-bar {
  display: flex;
  gap: 4px;
  border-bottom: 2px solid #d9e0e8;
  margin-bottom: 24px;
}
.tab-bar button {
  border: none;
  border-bottom: 2px solid transparent;
  border-radius: 0;
  padding: 8px 16px;
  margin-bottom: -2px;
  background: none;
}
.tab-bar button.active {
  border-bottom-color: #2563eb;
  color: #2563eb;
  background: none;
}
.card { background: #f5f7fa; border-radius: 8px; padding: 24px; border: 1px solid #d9e0e8; }
.before { background: #fff8f4; border-color: #c2410c; }
.after  { background: #ecfdf5; border-color: #059669; }
.progress-bar { height: 4px; background: #d9e0e8; border-radius: 2px; margin-top: 24px; }
.progress-bar .fill { height: 100%; background: #2563eb; border-radius: 2px; transition: width 0.3s; }
svg { display: block; width: 100%; height: auto; }
```

## JS patterns

No frameworks, no transpilation.

- State: one plain object at the top of the script. Components read and write
  it. No classes, no stores, no event buses.
- Rendering: a `render()` per component that reads state and updates the DOM.
  Call it after every state change.
- Events: delegate to the component container, one listener per component.
- Keyboard: listen on `document` for arrow keys and spacebar, route to the
  active tab, prevent default on spacebar to stop page scroll.

```js
const state = {
  activeTab: 'broke',
  trace:  { mode: 'before', step: 0 },
  changes:{ selected: null, visited: new Set(), showMechanical: false },
  diff:   { current: 0 },
  quiz:   { current: 0, answers: {}, submitted: false }
};
```

## Data structure

Embed the PR data as a JSON object in a `<script>` tag, separate from the
rendering logic.

```js
const prData = {
  repo: "...", id: 0, title: "...",
  kind: "bugfix|feature|refactor|perf|security",
  baseRef: "...", sha: "...", date: "...",
  summary: "...",

  trace: {
    input: "...",                 // what triggers it, same for both paths
    steps: [
      { label: "...", fn: "...", before: "...", after: "...", diverges: false }
    ],
    beforeOutcome: "...",         // concrete: the actual error or value
    afterOutcome: "...",
    evidence: "test|read|reported"  // how the before state was established
  },

  modules: [
    { id: "m1", path: "...", adds: 0, dels: 0, role: "logic|new|deleted|mechanical",
      detail: "...", calls: ["m2"] }
  ],

  hunks: [
    { path: "...", before: "...", after: "...", caption: "...", mechanical: false }
  ],

  quiz: [
    { question: "...", options: ["..."], correct: 0, explanation: "..." }
  ],

  notes: [ { text: "...", kind: "risk|inferred|followup" } ]
};
```

Set `trace.evidence` honestly. When it is `reported`, render the before lane as
a single caution-coloured box carrying the reported symptom, and say the cause
is not recorded. Never animate a path the diff does not support.

## Verify before done

1. Open the file in a browser. Click every tab and every interactive element.
2. Flip the before/after toggle repeatedly. **Confirm no node moves** — only
   colours, the outcome and the detail text may change.
3. Walk the stepper to the end and back with both the buttons and the arrow keys.
4. Check the quiz scores correctly and that retry works.
5. Grep for pronouns: `grep -oniE "\b(you|your|I|we|our|my)\b" source.html`,
   then grep for each author and reviewer name from the PR metadata.
6. Confirm it works from a `file://` URL with the network off.
7. Read it as a stranger. If the bug is not obvious before touching the fix
   tab, rebuild the trace.

## Output

Write the HTML to the scratchpad. Copy the finished file to
`~/Drawer/pr-explainers/{repo}-{id}.html`.
