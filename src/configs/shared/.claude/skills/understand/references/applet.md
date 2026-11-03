# Interactive Learning Applet

How to turn an understanding note into a self-contained learning tool. Single HTML file,
opens in a browser. No build step, no CDN, no network dependency.

## It is a learning tool, not a reference sheet

The infographic is a cheat sheet — static, printable, meant for lookup. The applet is for
active recall and exploration. A reader works through it, not just reads it.

- **No first or second person.** Same rule as the infographic.
- **No trace of the conversation.** Same transforms: "What I had wrong" becomes content
  for flashcards and quiz questions. "Open questions" becomes "Not yet documented".
- **Self-contained.** One `.html` file. All CSS and JS inline. No imports, no fetch calls,
  no external fonts. Must work from a `file://` URL.

## Component library

Use only these components. Do not invent new interaction types. Pick the ones that match
the content — most topics need two or three, not all of them.

### Flashcard deck

Best for: terminology, distinctions, misconceptions, "easily confused" pairs.

- Front: a question, a term, or a misconception statement.
- Back: the corrected understanding, 40 words max.
- Source each card from a specific finding — the "What I had wrong" entries, key terms
  from the map, or distinctions the interview surfaced.
- Controls: flip (click or spacebar), next/previous (arrow keys), shuffle button.
- Progress: show `N / total` and track which cards the user has seen.
- Confidence rating: after flipping, three buttons — "still shaky", "getting it", "solid".
  Colour-code the card's progress dot accordingly.

### Concept explorer

Best for: topics with 4+ interconnected components, dependency chains, system maps.

- Render the "Map" section as clickable nodes in an SVG.
- Click a node to expand a detail panel below the diagram. Panel shows: what it is, what
  it connects to, one sentence on why it matters.
- Highlight connected nodes when one is selected. Dim unrelated ones.
- Keep the SVG hand-drawn — no libraries. Same `viewBox` scaling rule as the infographic.

### Step-through

Best for: workflows, processes, sequences with 4+ steps.

- Render the step chain from the infographic spec, but animated.
- Start with all steps dimmed. Advance one at a time (click or right arrow).
- Each step lights up with its domain colour (same palette as the infographic step chain).
- A detail panel below shows: what happens at this step, which system, what artifact is
  produced or consumed.
- Back arrow to revisit. Step indicator shows position: `Step 3 of 7`.
- Optional: a "play" button that auto-advances at 2-second intervals.

### Quiz mode

Best for: testing recall after the other components, or when the topic has clear
right/wrong boundaries.

- Draw questions from the same source material as flashcards.
- Format: multiple choice, 3–4 options. One correct. Distractors must be plausible — pull
  them from the misconceptions or from adjacent concepts.
- Immediate feedback: highlight the correct answer green, the wrong pick red. Show a
  one-sentence explanation.
- Score: track correct/total. Show final score at the end with a breakdown of which
  questions were missed.
- Allow retry of missed questions only.

## Layout and navigation

The applet is a single-page app with a tab bar or sidebar for switching between
components. Do not stack all components in a scroll — the user picks one mode at a time.

```
┌─────────────────────────────────────────────┐
│  Topic Title                                │
│  ─────────────────────────────────────────  │
│  [Explore]  [Flashcards]  [Steps]  [Quiz]  │
│                                             │
│  ┌───────────────────────────────────────┐  │
│  │                                       │  │
│  │         Active component here         │  │
│  │                                       │  │
│  └───────────────────────────────────────┘  │
│                                             │
│  Progress bar / status                      │
│  Sources · Date                             │
└─────────────────────────────────────────────┘
```

Only show tabs for components that exist in this applet. If the topic has no step chain,
omit the Steps tab.

## Gamification

Keep it light. The goal is recall, not points.

- **Progress tracking**: a thin bar at the bottom showing overall completion across all
  components. "Completion" means: all flashcards seen, all explorer nodes visited, all
  steps walked through, quiz attempted.
- **Streak counter**: for flashcards, count consecutive "solid" ratings. Show it small.
  Reset on "still shaky". No fanfare, no animations.
- **Quiz score badge**: after completing the quiz, show the score as a badge on the Quiz
  tab. Colour: green for 80%+, orange for 50–79%, red for below 50%.
- **Revisit prompt**: if the user rated any flashcards "still shaky", show a small banner
  at the bottom: "3 cards marked shaky — review them?" with a button to filter to those
  cards.

Do not add: sounds, confetti, leaderboards, timers, XP, levels, streaks longer than the
current session, or anything that requires persistent storage. The file must work the same
way every time it is opened.

## Palette

Same as the infographic. Screen display, not print, so the colours work without the
`print-color-adjust` rule.

| Role | Hex | Usage in applet |
|---|---|---|
| Ink | `#1a2332` | Body text, headings |
| Muted text | `#5b6b7f` | Captions, secondary labels, source citations |
| Hairline | `#d9e0e8` | Borders, dividers, inactive tab underlines |
| Panel tint | `#f5f7fa` | Card backgrounds, detail panels, sidebar |
| Primary | `#2563eb` | Active tab, selected node, links, buttons |
| Flow | `#059669` on `#ecfdf5` | Correct answers, "solid" confidence, step highlight |
| Exception | `#c2410c` on `#fff8f4` | Wrong answers, misconception cards, "still shaky" |
| Caution | `#b45309` on `#fffbeb` | "Getting it" confidence, open questions, warnings |

Dark backgrounds for interactive elements that need to pop:

| Element | Background | Text |
|---|---|---|
| Active button / tab | `#2563eb` | `#ffffff` |
| Flashcard front | `#f5f7fa` | `#1a2332` |
| Flashcard back | `#ffffff` | `#1a2332` |
| Quiz option (default) | `#ffffff` border `#d9e0e8` | `#1a2332` |
| Quiz option (correct) | `#ecfdf5` border `#059669` | `#1a2332` |
| Quiz option (wrong) | `#fff8f4` border `#c2410c` | `#1a2332` |

## CSS baseline

```css
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
  color: #1a2332;
  background: #ffffff;
  line-height: 1.5;
  max-width: 900px;
  margin: 0 auto;
  padding: 24px;
}
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
  padding-bottom: 0;
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
.card {
  background: #f5f7fa;
  border-radius: 8px;
  padding: 24px;
  border: 1px solid #d9e0e8;
}
.progress-bar {
  height: 4px;
  background: #d9e0e8;
  border-radius: 2px;
  margin-top: 24px;
}
.progress-bar .fill {
  height: 100%;
  background: #2563eb;
  border-radius: 2px;
  transition: width 0.3s;
}
svg { display: block; width: 100%; height: auto; }
```

## JS patterns

Keep the JavaScript simple and readable. No frameworks, no transpilation.

- State: one plain object at the top of the script. All components read from and write to
  it. No classes, no stores, no event buses.
- Rendering: write a `render()` function per component that reads the state and updates
  the DOM. Call it after every state change.
- Event listeners: attach to the component container using delegation, not to individual
  elements. One listener per component.
- Keyboard: listen on `document` for arrow keys and spacebar. Route to the active
  component. Prevent default on spacebar to avoid page scroll.

```js
const state = {
  activeTab: 'explore',
  flashcards: { current: 0, seen: new Set(), confidence: {} },
  explorer: { selected: null, visited: new Set() },
  steps: { current: 0 },
  quiz: { current: 0, answers: {}, submitted: false }
};
```

## Data structure

Embed the topic data as a JSON object in a `<script>` tag. Keep it separate from the
rendering logic.

```js
const topicData = {
  title: "...",
  date: "...",
  sources: ["..."],

  concepts: [
    { id: "c1", label: "...", detail: "...", connects: ["c2", "c3"] }
  ],

  flashcards: [
    { front: "...", back: "..." }
  ],

  steps: [
    { label: "...", system: "...", detail: "...", domain: "esp|external|bench|mocked" }
  ],

  quiz: [
    {
      question: "...",
      options: ["...", "...", "...", "..."],
      correct: 0,
      explanation: "..."
    }
  ]
};
```

## When to build one

On request only — same rule as the infographic. Offer it when the map is settled and the
interview has surfaced enough material. The applet works best when there are at least 6
flashcard-worthy items or a workflow with 4+ steps.

The user picks between infographic and applet (or both). They serve different purposes:
the infographic is a reference to pin up; the applet is a study session to work through.

## Verify before done

1. Open the file in a browser. Click every tab. Click every interactive element.
2. Test keyboard navigation: arrows, spacebar, enter.
3. Check that the quiz scores correctly.
4. Check that flashcard confidence ratings persist within the session.
5. Grep for personal pronouns: `grep -oniE "\b(you|your|I|we|our|my)\b" source.html`
6. Verify the file works from a `file://` URL with no network.

## Output

Write the HTML to the scratchpad. Copy the finished file to
`~/Drawer/understanding/<topic-slug>-applet.html`.
