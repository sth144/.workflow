#!/usr/bin/env python3
"""Spool and render mermaid diagrams drawn by an agent, for viewing on demand.

Diagram source never goes in the chat: a wall of mermaid syntax in the middle
of an answer is worse to read than the prose it was meant to illustrate. The
agent (usually a background subagent, so none of the drafting reaches the main
thread) pipes the source to ``--save``, which spools it to a file and prints the
path. The visible cost in chat is one line.

Display is pull-based from there: ⌘⌃V in Hammerspoon runs this with no
arguments, which renders the newest spooled diagram to HTML and prints the path
for a floating webview to load. A diagram nobody asks to see costs one line of
chat and a file that gets pruned.

Usage:
  render_mermaid.py --save TITLE    # spool mermaid source from stdin -> path
  render_mermaid.py                 # render newest spooled diagram -> HTML path
  render_mermaid.py --file DIAGRAM  # render a specific .mmd file
  render_mermaid.py --print         # print the newest mermaid source instead
  render_mermaid.py --list          # list spooled diagrams, newest first

Exits 2 when nothing has been spooled.
"""

from __future__ import annotations

import argparse
import html
import re
import sys
import tempfile
import time
import urllib.error
import urllib.request
from pathlib import Path

WORKFLOW_CACHE = Path.home() / ".cache" / ".workflow"
# Not $TMPDIR: launchd gives Hammerspoon a different per-process temp directory
# than the shell an agent runs in, so the two sides would spool to and read from
# different places. A fixed path plus pruning gets the same "gone unless you
# copied it somewhere" behaviour without depending on the environment.
SPOOL_DIR = WORKFLOW_CACHE / "diagrams"
MERMAID_JS = WORKFLOW_CACHE / "mermaid" / "mermaid.min.js"
MERMAID_CDN = "https://cdn.jsdelivr.net/npm/mermaid@11/dist/mermaid.min.js"

FENCE_RE = re.compile(r"```mermaid[^\n]*\n(.*?)```", re.DOTALL)
SLUG_RE = re.compile(r"[^a-z0-9]+")
DOWNLOAD_TIMEOUT = 20
KEEP_FILES = 20
KEEP_SECONDS = 24 * 3600


# -- Spool --


def spooled(newest_first: bool = True) -> list[Path]:
    """Every spooled diagram, newest first by default."""
    if not SPOOL_DIR.is_dir():
        return []
    files = [p for p in SPOOL_DIR.glob("*.mmd") if p.is_file()]
    return sorted(files, key=lambda p: p.stat().st_mtime, reverse=newest_first)


def prune() -> None:
    """Drop diagrams past the keep count or the keep window.

    Spooled diagrams are scratch by design — the durable copy is whatever got
    written into the daybook. The cached .png the viewer renders next to each
    .mmd goes with it, so those cannot outlive their source.
    """
    cutoff = time.time() - KEEP_SECONDS
    for index, path in enumerate(spooled()):
        if index >= KEEP_FILES or path.stat().st_mtime < cutoff:
            path.with_suffix(".png").unlink(missing_ok=True)
            path.unlink(missing_ok=True)


def slugify(title: str) -> str:
    """Filename-safe form of a diagram title."""
    slug = SLUG_RE.sub("-", title.lower()).strip("-")
    return slug[:60] or "diagram"


def save(title: str, source: str) -> Path:
    """Spool mermaid source under a timestamped filename and return its path.

    A fence is tolerated around the source so the caller can pipe either the raw
    diagram or the markdown block it would have written.
    """
    fenced = FENCE_RE.search(source)
    if fenced:
        source = fenced.group(1)

    SPOOL_DIR.mkdir(parents=True, exist_ok=True)
    stamp = time.strftime("%Y%m%d-%H%M%S")
    target = SPOOL_DIR / f"{stamp}-{slugify(title)}.mmd"
    target.write_text(source.strip() + "\n", encoding="utf-8")
    prune()
    return target


# -- Mermaid runtime --


def ensure_mermaid_js() -> Path | None:
    """Local mermaid.min.js, fetched once and cached; None if unavailable.

    Cached rather than vendored so the config repo stays free of a 3MB blob,
    and fetched once rather than per-render so the viewer works offline after
    the first use.
    """
    if MERMAID_JS.is_file() and MERMAID_JS.stat().st_size > 0:
        return MERMAID_JS

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    try:
        with urllib.request.urlopen(MERMAID_CDN, timeout=DOWNLOAD_TIMEOUT) as resp:
            payload = resp.read()
    except (urllib.error.URLError, OSError, TimeoutError):
        return None

    tmp = MERMAID_JS.with_suffix(".tmp")
    tmp.write_bytes(payload)
    tmp.replace(MERMAID_JS)
    return MERMAID_JS


# -- HTML --

HTML_TEMPLATE = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  html, body {{ margin: 0; background: #14161a; color: #c8ccd4; }}
  body {{
    font: 13px/1.5 -apple-system, "SF Mono", Menlo, monospace;
    padding: 20px; box-sizing: border-box;
  }}
  #diagram {{ text-align: center; }}
  #diagram.fallback {{
    text-align: left; white-space: pre-wrap; background: #1b1e24;
    padding: 16px; border-radius: 6px; border: 1px solid #2b2f38;
  }}
  #note {{ color: #6b7280; margin-top: 16px; }}
</style>
{script}
</head>
<body>
<pre id="diagram">{source}</pre>
<p id="note">{note}</p>
</body>
</html>
"""

OFFLINE_NOTE = (
    "mermaid.js unavailable offline — showing source. "
    "It caches on the first render with a network connection."
)

# Rendering is best-effort by design: a diagram is an illustration, so one that
# will not parse degrades to its own source rather than to mermaid's error
# graphic. Sequence source is close to readable on its own, which is most of
# why sequence diagrams are the ones worth emitting.
RENDER_SCRIPT = """<script src="{js_uri}"></script>
<script>
window.addEventListener('load', async function () {{
  var el = document.getElementById('diagram');
  var note = document.getElementById('note');
  mermaid.initialize({{
    startOnLoad: false, theme: 'dark', securityLevel: 'strict',
    fontFamily: 'ui-monospace, Menlo, monospace',
    themeVariables: {{
      background: '#14161a', textColor: '#d8dce4', signalTextColor: '#d8dce4',
      labelTextColor: '#d8dce4', noteTextColor: '#1b1e24', lineColor: '#8b93a5'
    }}
  }});
  try {{
    var source = el.textContent;
    await mermaid.parse(source);
    await mermaid.run({{ nodes: [el] }});
  }} catch (err) {{
    el.classList.add('fallback');
    note.textContent = 'This diagram did not parse — showing source. ' +
      String((err && err.message) || err).split('\\n')[0];
  }}
}});
</script>"""


def build_html(source: str, js_path: Path | None) -> str:
    """Full HTML document for one diagram."""
    escaped = html.escape(source)
    if js_path is None:
        return HTML_TEMPLATE.format(script="", source=escaped, note=OFFLINE_NOTE)

    script = RENDER_SCRIPT.format(js_uri=js_path.as_uri())
    return HTML_TEMPLATE.format(script=script, source=escaped, note="")


def write_html(document: str) -> Path:
    """Write the document to a fresh temp dir and return its path.

    Temp by design: the durable copy of a diagram is the mermaid source in the
    transcript (and in the daybook, when it explains something worth keeping).
    """
    tmpdir = Path(tempfile.mkdtemp(prefix="mermaid-"))
    target = tmpdir / "diagram.html"
    target.write_text(document, encoding="utf-8")
    return target


# -- Main --


def read_source(args: argparse.Namespace) -> str | None:
    """The mermaid source to act on, from --file or the newest spooled diagram."""
    if args.file:
        return Path(args.file).read_text(encoding="utf-8").strip() or None

    newest = spooled()
    if not newest:
        return None
    return newest[0].read_text(encoding="utf-8").strip() or None


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--save", metavar="TITLE", help="spool stdin under this title")
    parser.add_argument("--file", help="act on this .mmd file instead")
    parser.add_argument(
        "--print",
        dest="print_only",
        action="store_true",
        help="print the mermaid source instead of rendering it",
    )
    parser.add_argument(
        "--list", action="store_true", help="list spooled diagrams, newest first"
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    if args.save:
        print(save(args.save, sys.stdin.read()))
        return 0

    if args.list:
        for path in spooled():
            print(path)
        return 0

    try:
        source = read_source(args)
    except OSError as exc:
        print(f"cannot read diagram source: {exc}", file=sys.stderr)
        return 1

    if not source:
        print("no diagram has been drawn yet", file=sys.stderr)
        return 2

    if args.print_only:
        print(source)
        return 0

    print(write_html(build_html(source, ensure_mermaid_js())))
    return 0


if __name__ == "__main__":
    sys.exit(main())
