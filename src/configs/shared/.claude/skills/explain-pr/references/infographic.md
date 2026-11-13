# PR infographic PDF

How to turn a pull request into a visual one-pager. Self-contained HTML,
rendered by headless Chrome. No network, no CDN, no extra dependencies.

## It is a briefing, not a diff

Someone who has not opened the PR must be able to read it cold and know what
the code now does differently.

- **No first or second person.** No "you", "your", "I", "we". No author or
  reviewer names — attribute to "the review", not to a person.
- **Behaviour over mechanics.** Show what the program does differently. Code
  appears only where the change is the point, and then as the smallest excerpt
  that carries it.
- **Mark inference.** Anything not evidenced by the diff gets the caution colour
  and a word like "inferred" or "not recorded".
- Date it, name the PR and the base ref in the footer, and give the commit sha.
  These go stale the moment someone pushes.

## Page plan

One page is the target. Two is common. Beyond three, the PR is too big for one
artefact — split by concern and say so.

| Page | Content |
|---|---|
| 1 | Title bar, one-paragraph summary, the lead visual for the change kind, change map |
| 2 | Supporting mechanism — call path, data shape, step chain |
| 3 | Review notes, risk, what is not covered |

Lead with the lead visual. For a bug fix that means the failure trace sits above
the fold, not after the file list.

## Render

```bash
mkdir -p ~/Drawer/pr-explainers
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$HOME/Drawer/pr-explainers/{repo}-{id}.pdf" \
  "file:///path/to/source.html"
```

Write the HTML to the scratchpad. Only the PDF belongs in `~/Drawer`.

Chrome prints `CVDisplayLinkCreateWithCGDisplay failed` to stderr on macOS.
Harmless.

## Required CSS

```css
@page { size: A4 portrait; margin: 12mm 11mm; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.page { page-break-after: always; }
.page:last-child { page-break-after: auto; }
.card, .trace, .wf { break-inside: avoid; }
svg { display: block; width: 100%; height: auto; }
code, pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 9.5pt; }
pre { white-space: pre-wrap; word-break: break-word; }
```

Without `print-color-adjust: exact`, every background fill drops out and the PDF
prints as line art. This is the most common failure.

Size SVGs with `viewBox` and no width/height attributes so they scale to the
column. Draw SVG by hand — a Mermaid or chart-library CDN fetch fails in
headless Chrome with no network and the PDF renders empty.

## Palette

Print-safe, and the hues stay distinguishable in greyscale.

| Role | Hex |
|---|---|
| Ink | `#1a2332` |
| Muted text | `#5b6b7f` |
| Hairline rule | `#d9e0e8` / `#eef2f6` |
| Panel tint | `#f5f7fa` |
| Primary — structure, unchanged parts | `#2563eb` |
| **After — the fixed path, added behaviour** | `#059669` on `#ecfdf5` |
| **Before — the broken path, the failure** | `#c2410c` on `#fff8f4` |
| Caution — inferred, deferred, not covered | `#b45309` on `#fffbeb` |

The before/after colour pairing is fixed. Red-orange is always the old broken
behaviour, green is always the new correct behaviour. Never swap them for
variety, and never use green for "removed" just because a diff tool would.

## Visual vocabulary

Pick the form from the content, not for variety.

| Content | Form |
|---|---|
| **A bug, and what it did** | **Failure trace — see below. The signature visual.** |
| Which files and modules moved | Change map — see below |
| A new capability the user can now reach | Step chain, one box per user-visible step |
| Order of calls through the code | Sequence lanes, one lane per module, arrows between |
| A changed payload, schema, or record | Side-by-side field tables, changed rows tinted |
| Cost before and after | Paired horizontal bars with the measured numbers on them |
| An exposure and where it is now blocked | Attack path, with a barrier glyph at the fix |
| Two approaches that were weighed | Contrast cards, different top-border colours |
| Risk, gaps, follow-ups | Callout list, caution colour on the lead phrase |

### Failure trace — the signature visual

This is what the artefact exists for. Everything else supports it.

Two lanes, stacked, sharing one horizontal step axis so the divergence point
lines up vertically:

```
  BEFORE   ○──────○──────●──────✕        ← #c2410c, ✕ at the wrong outcome
           step   step   HERE   wrong output

  AFTER    ○──────○──────●──────✓        ← #059669, ✓ at the right outcome
           step   step   fix    right output
```

Rules that make it readable:

- **The lanes share an x axis.** The step where behaviour diverges sits at the
  same x in both. That vertical alignment is the whole idea — it shows exactly
  where the two worlds split.
- **Mark the divergence point** with a filled node in both lanes and a vertical
  hairline between them. Label it once, between the lanes.
- **End both lanes with the concrete outcome**, not a verdict. `TypeError on
  line 42` and `returns 0`, not "fails" and "works".
- **Name the input that triggers it** above the pair. A trace without its input
  is a claim, not a demonstration.
- Keep both lanes to the same number of steps. If the fix adds a step, show it
  as an inserted node in the after lane at the divergence x, and leave a gap in
  the before lane.
- Four to six steps. More than that and the reader loses the alignment.

When the bug is a wrong value rather than a wrong path, swap the lanes for a
**value trace**: the same expression evaluated down both columns, one row per
step, with the row where they diverge tinted. Same colours, same rule about
ending on the concrete outcome.

When the cause is not evidenced, draw the after lane in full and replace the
before lane with a single caution-coloured box reading what is known — the
reported symptom — and state that the cause is not recorded. Never draw a trace
you cannot support.

### Change map

Answers "where did this land" in one glance.

- One block per module or directory, sized by churn, laid out as a simple
  treemap or as a row of proportional bars.
- Tint each block by role: changed logic in primary, new files in the after
  colour, deleted in the before colour, mechanical churn in panel tint.
- Label each with the file count and `+adds / −dels`.
- **Collapse the noise.** Lockfiles, generated code and vendored directories get
  one grey block labelled "mechanical", with the total. Do not give them area
  proportional to their line count — they will swamp the real change.

### Code excerpts

Use them sparingly, and only where the change *is* the code.

- Before and after side by side, never a unified diff with `+`/`-` markers.
- Six lines each, maximum. Elide with `…` and keep the lines that matter.
- Tint the changed lines only: before in `#fff8f4`, after in `#ecfdf5`.
- A caption under each pair saying what the change does, in behaviour terms.
- Never paste a hunk header or a line number gutter. They are noise here.

## Verify — four checks, none optional

**1. Measure every page before rendering.**

```
$ python3 measure.py source.html
content width 711px · page limit 1032px
  page 1:   863px   ok   (-169px)
  page 2:  1151px   OVERFLOW   (+119px)
```

An overflowing page silently spills onto a half-empty extra sheet. Move a
section to a page with slack — the report tells you which ones have room.

**Do not use `mdls -name kMDItemNumberOfPages`.** It reads the Spotlight index,
not the file, and returns stale counts after a re-render.

**2. Look at every page that contains a diagram.** SVG errors do not throw. They
render as overlapping boxes, clipped text, and arrows that bisect their own
captions.

```bash
python3 split.py 1 source.html
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --screenshot=p1.png --window-size=800,620 --hide-scrollbars "file://$PWD/p1.html"
```

Then Read `p1.png`. Recurring faults:

- **Lanes out of alignment.** The divergence node sits at a different x in the
  two lanes. This breaks the only idea the diagram carries. Check it first.
- **Text clipped at the left edge.** A `text-anchor="middle"` label centred near
  x=0 runs off. Shorten it, split it, or anchor it `start`.
- **A connector crossing a caption.** Route the line along a box edge.
- **A label colliding with the box it points at.** Markers scale with
  `stroke-width`, so the arrow tip sits further along than `x2` suggests. Leave
  8–10 units of clearance.
- **A caption repeating a label already on the diagram.** Delete one. Duplicated
  text is what forces connectors into collisions.

**3. Check for pronouns and names.**

```bash
grep -oniE "\b(you|your|I|we|our|my)\b" source.html
```

Then read the author and reviewer names out of the PR metadata and grep for each
one.

**4. Read it as a stranger.** Cover the diff. Read the PDF. If you cannot say
what was broken and what now happens instead, the artefact has failed its one
job — rebuild the failure trace before shipping it.
