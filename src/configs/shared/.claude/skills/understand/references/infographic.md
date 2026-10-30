# Infographic PDF

How to turn an understanding note into a visual cheat sheet. Self-contained HTML,
rendered by headless Chrome. No network, no CDN, no extra dependencies.

## It is a cheat sheet, not a session record

The PDF is a standalone reference. Someone who was not in the conversation must be able
to read it cold.

- **No first or second person.** No "you", "your", "I", "we". No name.
- **No trace of the conversation.** Drop "What I had wrong" — that section belongs in the
  Joplin note, not here. Convert it to an impersonal **"Easily misread"** section: the
  same facts, stated as properties of the subject rather than as someone's mistakes.
- Convert "Open questions" to **"Not recorded anywhere"**. Same content, no implication
  that anyone failed to learn it.
- Date it and cite the sources in the footer. These go stale.

## Render

```bash
mkdir -p ~/Drawer/understanding
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$HOME/Drawer/understanding/<topic-slug>.pdf" \
  "file:///path/to/source.html"
```

Write the HTML to the scratchpad. Only the PDF belongs in `~/Drawer`.

Chrome prints `CVDisplayLinkCreateWithCGDisplay failed` to stderr on macOS. Harmless.

## Verify — three checks, none optional

**1. Measure every page before rendering.** Run `measure.py` from this skill. It injects a
probe, loads the page at true A4 content width, and reports each `.page` height against
the limit:

```
$ python3 measure.py
content width 711px · page limit 1032px
  page 1:   863px   ok   (-169px)
  page 6:  1151px   OVERFLOW   (+119px)
```

An overflowing page silently spills onto a half-empty extra sheet. Move a section to a
page with slack — the report tells you which ones have room.

**Do not use `mdls -name kMDItemNumberOfPages` to check this.** It reads the Spotlight
index, not the file, and returns stale counts after a re-render. It reported 4 pages for
a 7-page document.

**2. Look at every page that contains a diagram.** SVG errors do not throw. They render as
overlapping boxes, clipped text, and arrows that bisect their own captions.

```bash
python3 split.py 3      # writes p3.html from the page-3 div
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless --disable-gpu \
  --screenshot=p3.png --window-size=800,620 --hide-scrollbars "file://$PWD/p3.html"
```

Then Read `p3.png`. Recurring faults to look for:

- **Text clipped at the left edge.** A `text-anchor="middle"` label centred near x=0 runs
  off. Shorten it, split it onto two lines, or anchor it `start`.
- **A connector crossing a caption.** Route the line down a box edge, not its centre.
- **A label colliding with the box it points at.** Markers scale with `stroke-width`, so
  the arrow tip sits further along than `x2` suggests. Leave 8–10 units of clearance.
- **A caption wider than its box.** Shorten it.
- **A long connector cutting through a box or a caption it has nothing to do with.**
  Route it through a gap between boxes, or above the whole row. Check where the gaps
  actually are before picking the x coordinate.
- **A caption that repeats a label already on the diagram.** Delete one. Duplicated text
  is what forces connectors into collisions in the first place.

**3. Check for personal pronouns.**

```bash
grep -oniE "\b(you|your|I|we|our|my)\b" source.html
```

## Required CSS

```css
@page { size: A4 portrait; margin: 12mm 11mm; }
html { -webkit-print-color-adjust: exact; print-color-adjust: exact; }
.page { page-break-after: always; }
.page:last-child { page-break-after: auto; }
.card, .wf { break-inside: avoid; }
svg { display: block; width: 100%; height: auto; }
```

Without `print-color-adjust: exact`, every background fill drops out and the PDF prints
as line art. This is the most common failure.

Size SVGs with `viewBox` and no width/height attributes so they scale to the column.

## Palette

Print-safe, and the hues stay distinguishable in greyscale.

| Role | Hex |
|---|---|
| Ink | `#1a2332` |
| Muted text | `#5b6b7f` |
| Hairline rule | `#d9e0e8` / `#eef2f6` |
| Panel tint | `#f5f7fa` |
| Primary — structure, software links | `#2563eb` |
| Flow — real movement of material or data | `#059669` on `#ecfdf5` |
| The exception to the pattern | `#c2410c` on `#fff8f4` |
| Caution — gaps, deferrals, mocked parts | `#b45309` on `#fffbeb` |

Use the orange deliberately. One thing per page should carry it: the item that breaks the
rule everything else follows. If everything is orange, nothing is.

## Visual vocabulary

Pick the form from the content, not for variety.

| Content | Form |
|---|---|
| Order of events, delivery sequence | Horizontal SVG timeline, dots on a rule |
| How components connect | SVG box-and-arrow. Put the shared layer on a bus or spine; put the exception outside the frame, boxed and dashed |
| Real flow of material or data | Thick arrow in the flow colour, labelled with what moves |
| What a user actually does | Step chain — see below |
| **The layout of a file format** | **File anatomy — see below** |
| **How records chain across tables** | **Box-and-arrow keyed on the identifier that joins them. Put the row and column counts in each box; they show where the volume is** |
| Two things easily confused | Side-by-side contrast cards, different top-border colours |
| Repeating facts across N items | Card grid, same field labels in each card |
| Lookup material, glossary | Plain table |
| Traps and unknowns | Callout list, caution colour on the lead phrase |

### Step chains — one per domain or role

The most useful diagram in a cheat sheet. It answers "what does the person at the bench
actually do, and where does each step happen."

- Header line: the role, and the workgroups or site on the right.
- Boxes of equal width in a row, arrows between. Wrap to a second row with a dashed
  return path when there are more than five steps.
- A caption **below** each box naming the system, artefact, or identifier.
- **Colour each box by where the work happens.** This is what makes the diagram worth
  drawing:

| Fill / border | Meaning |
|---|---|
| white / `#2563eb` solid | the step happens in ESP |
| `#eef2f6` / `#8fa3b8` dashed | an external system does it |
| `#ecfdf5` / `#059669` solid | physical bench work |
| `#fffbeb` / `#b45309` dashed | mocked, deferred, or incomplete |

Repeat that legend under each page of step chains. A reader should be able to see, at a
glance, how much of a workflow actually runs in the product.

### File anatomy

When the topic involves a data format someone has to parse, draw the file as a vertical
stack of bands — header, preamble, section marker, column header, data rows — at roughly
a third of the page width, with annotation callouts arrowed in from the right.

Give every band the fill that matches what it is, and reserve the caution colour for the
part that breaks naive parsers. State the parse rule as a sentence in the annotation, not
just a colour. Readers reach for this page when their importer has silently eaten
something it should have stopped at.

Derive the structure by script rather than by reading one file — section names, column
counts and row counts across the whole set. Put the counts in the diagram. Never put
sample values, record identifiers, or anything from a free-text field into the output;
those carry names and customer data.

Draw SVG by hand. Do not pull in Mermaid or a chart library — a CDN fetch fails in
headless Chrome with no network and the PDF renders empty.

## When to build one

On request only. Never on every interview round — it is slow, and the Joplin note is the
live artefact. Offer once the map is settled and the gaps are recorded.
