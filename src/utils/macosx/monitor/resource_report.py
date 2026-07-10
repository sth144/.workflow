#!/usr/bin/env python3
"""Generate an interactive resource report — floating widget or browser.

Usage:
    resmon                  # floating semi-transparent widget (default)
    resmon --last 6h        # last 6 hours
    resmon --windowed       # normal window with title bar
    resmon --browser        # open in browser
    resmon --no-open        # generate HTML only

On first run, creates a venv and installs dependencies automatically.
"""

import argparse
import json
import math
import os
import subprocess
import sys
import webbrowser
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

VENV_DIR = Path.home() / ".cache" / ".workflow" / "resource-monitor" / ".venv"
LOG_FILE = Path.home() / ".cache" / ".workflow" / "resource-monitor" / "resources.jsonl"
REPORT_FILE = Path.home() / ".cache" / ".workflow" / "resource-monitor" / "report.html"
DISK_REPORT = Path.home() / "tmp" / "disk_report.txt"
DISK_CACHE = Path.home() / ".cache" / ".workflow" / "resource-monitor" / "disk_summary.json"
VENV_DEPS = ["plotly", "pywebview"]
MAX_TRACES = 8
TREEMAP_MIN_BYTES = 50_000_000  # 50 MB
TREEMAP_MAX_DEPTH = 4

WIDGET_TEMPLATE = """\
<!DOCTYPE html>
<html>
<head>
<style>
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  html, body {{
    height: 100%; overflow: hidden;
    background: transparent;
    font-family: -apple-system, sans-serif;
  }}
  #widget {{
    height: 100%;
    background: rgba(30, 30, 30, 0.55);
    border-radius: 12px;
    overflow-y: auto;
    transition: background 0.3s ease;
  }}
  #widget:hover {{ background: rgba(30, 30, 30, 0.95); }}
  #close-btn {{
    position: fixed; top: 8px; right: 12px; z-index: 9999;
    background: rgba(255,255,255,0.15); color: #aaa;
    border: none; border-radius: 50%;
    width: 24px; height: 24px; font-size: 14px;
    cursor: pointer; opacity: 0; transition: opacity 0.3s;
    line-height: 24px; text-align: center;
  }}
  #widget:hover #close-btn {{ opacity: 1; }}
  #close-btn:hover {{ background: rgba(255,70,70,0.8); color: white; }}
  .modebar {{ opacity: 0; transition: opacity 0.3s; }}
  #widget:hover .modebar {{ opacity: 1; }}
</style>
</head>
<body>
<div id="widget">
  <button id="close-btn" onclick="pywebview.api.close()">&times;</button>
  {content}
</div>
<script>
document.addEventListener('keydown', function(e) {{
  if (e.key === 'Escape') pywebview.api.close();
}});
</script>
</body>
</html>
"""


# ---------------------------------------------------------------------------
# Venv bootstrap
# ---------------------------------------------------------------------------

def _ensure_venv() -> None:
    """Create venv and install deps if not present, then re-exec."""
    venv_python = VENV_DIR / "bin" / "python3"
    if not venv_python.exists():
        print(f"Creating venv at {VENV_DIR} ...", file=sys.stderr)
        subprocess.check_call([sys.executable, "-m", "venv", str(VENV_DIR)])
        subprocess.check_call(
            [str(venv_python), "-m", "pip", "install", "-q"] + VENV_DEPS,
        )
    os.execv(str(venv_python), [str(venv_python)] + sys.argv)


try:
    import plotly  # noqa: F401
    import webview  # noqa: F401
except ImportError:
    _ensure_venv()

import plotly.graph_objects as go  # noqa: E402
from plotly.subplots import make_subplots  # noqa: E402


# ---------------------------------------------------------------------------
# Data loading
# ---------------------------------------------------------------------------

def parse_duration(s: str) -> timedelta:
    """Parse a duration string like '6h', '30m', '1d'."""
    units = {"m": "minutes", "h": "hours", "d": "days"}
    unit = s[-1].lower()
    if unit not in units:
        raise ValueError(f"Unknown duration unit '{unit}'. Use m, h, or d.")
    return timedelta(**{units[unit]: int(s[:-1])})


def load_entries(log_file: Path, since: datetime | None = None) -> list[dict]:
    """Load log entries, converting UTC timestamps to local time."""
    if not log_file.exists():
        return []
    local_tz = datetime.now().astimezone().tzinfo
    entries = []
    for line in log_file.read_text().splitlines():
        if not line.strip():
            continue
        try:
            entry = json.loads(line)
            ts = datetime.fromisoformat(entry["ts"])
            if since and ts < since:
                continue
            entry["ts"] = ts.astimezone(local_tz).isoformat()
            entries.append(entry)
        except (json.JSONDecodeError, KeyError, ValueError):
            continue
    return entries


# ---------------------------------------------------------------------------
# Analysis
# ---------------------------------------------------------------------------

def rank_processes(entries: list[dict], metric: str) -> list[str]:
    """Rank process names by cumulative metric value, return top N names."""
    totals: dict[str, float] = defaultdict(float)
    for entry in entries:
        for proc in entry.get(metric, []):
            totals[proc["name"]] += proc["pct"]
    ranked = sorted(totals, key=lambda k: totals[k], reverse=True)
    return ranked[:MAX_TRACES]


def build_timeseries(
    entries: list[dict], metric: str, names: list[str],
) -> dict[str, tuple[list[str], list[float]]]:
    """Build {name: (timestamps, values)} for the top process names."""
    series: dict[str, tuple[list, list]] = {n: ([], []) for n in names}
    for entry in entries:
        ts = entry["ts"]
        snapshot = {p["name"]: p["pct"] for p in entry.get(metric, [])}
        for name in names:
            series[name][0].append(ts)
            series[name][1].append(snapshot.get(name, 0.0))
    return series


def extract_sys_series(entries: list[dict]) -> dict[str, tuple[list, list]]:
    """Extract system-level timeseries from entries with a 'sys' key."""
    keys = {
        "CPU Used %": lambda s: s.get("cpu_user", 0) + s.get("cpu_sys", 0),
        "Mem Used %": lambda s: s.get("pct", 0),
        "Disk Space %": lambda s: s.get("disk", {}).get("pct", 0),
    }
    series: dict[str, tuple[list, list]] = {k: ([], []) for k in keys}
    for entry in entries:
        sys_data = entry.get("sys")
        if not sys_data:
            continue
        ts = entry["ts"]
        for label, fn in keys.items():
            series[label][0].append(ts)
            series[label][1].append(fn(sys_data))
    return series


# ---------------------------------------------------------------------------
# Disk blame — directory growth, per-process writes, open writers
# ---------------------------------------------------------------------------

def _extract_dir_series(entries: list[dict]) -> dict[str, tuple[list, list]]:
    """Extract directory size timeseries (KB -> GB) from 'dirs' field."""
    all_dirs: set[str] = set()
    for entry in entries:
        for d in entry.get("dirs", []):
            all_dirs.add(d["path"])
    if not all_dirs:
        return {}

    # Rank by latest size
    latest: dict[str, int] = {}
    for entry in reversed(entries):
        for d in entry.get("dirs", []):
            latest.setdefault(d["path"], d["kb"])
        if len(latest) >= len(all_dirs):
            break
    top = sorted(latest, key=lambda k: latest[k], reverse=True)[:10]

    series: dict[str, tuple[list, list]] = {d: ([], []) for d in top}
    for entry in entries:
        ts = entry["ts"]
        snap = {d["path"]: d["kb"] for d in entry.get("dirs", [])}
        for d in top:
            if d in snap:
                series[d][0].append(ts)
                series[d][1].append(snap[d] / (1024 * 1024))  # GB
    return series


def _extract_writer_series(
    entries: list[dict],
) -> dict[str, tuple[list, list]]:
    """Build timeseries for top disk writers (fs_usage bytes -> MB)."""
    totals: dict[str, float] = defaultdict(float)
    for entry in entries:
        for w in entry.get("writers", []):
            totals[w["name"]] += w.get("write_bytes", 0)
    top = sorted(totals, key=lambda k: totals[k], reverse=True)[:MAX_TRACES]
    if not top:
        return {}

    series: dict[str, tuple[list, list]] = {n: ([], []) for n in top}
    for entry in entries:
        ts = entry["ts"]
        snap = {w["name"]: w.get("write_bytes", 0)
                for w in entry.get("writers", [])}
        for name in top:
            series[name][0].append(ts)
            series[name][1].append(snap.get(name, 0) / (1024 * 1024))  # MB
    return series


def _extract_lsof_series(
    entries: list[dict],
) -> dict[str, tuple[list, list]]:
    """Build timeseries for open-write-FD counts from lsof."""
    totals: dict[str, int] = defaultdict(int)
    for entry in entries:
        for w in entry.get("lsof", []):
            totals[w["name"]] += w.get("open_writes", 0)
    top = sorted(totals, key=lambda k: totals[k], reverse=True)[:MAX_TRACES]
    if not top:
        return {}

    series: dict[str, tuple[list, list]] = {n: ([], []) for n in top}
    for entry in entries:
        ts = entry["ts"]
        snap = {w["name"]: w.get("open_writes", 0)
                for w in entry.get("lsof", [])}
        for name in top:
            series[name][0].append(ts)
            series[name][1].append(snap.get(name, 0))
    return series


def _build_disk_blame_figure(entries: list[dict]) -> "go.Figure | None":
    """Build a figure with directory growth, disk writers, and open-FD panels."""
    dir_series = _extract_dir_series(entries)
    writer_series = _extract_writer_series(entries)
    lsof_series = _extract_lsof_series(entries)

    panels: list[tuple[str, dict, str]] = []
    if dir_series:
        panels.append(("Directory Sizes", dir_series, "GB"))
    if writer_series:
        panels.append(("Disk Writers (fs_usage)", writer_series, "MB/sample"))
    if lsof_series:
        panels.append(("Open Write FDs (lsof)", lsof_series, "count"))
    if not panels:
        return None

    fig = make_subplots(
        rows=len(panels), cols=1,
        subplot_titles=tuple(t for t, _, _ in panels),
        vertical_spacing=0.08,
    )
    for i, (_, series, ylabel) in enumerate(panels, 1):
        for name, (ts_vals, y_vals) in series.items():
            fig.add_trace(
                go.Scatter(x=ts_vals, y=y_vals, name=name,
                           mode="lines+markers", marker=dict(size=4)),
                row=i, col=1,
            )
        fig.update_yaxes(title_text=ylabel, row=i, col=1)

    fig.update_layout(
        title="Disk Blame",
        height=350 * len(panels),
        template="plotly_dark",
        hovermode="x unified",
        legend=dict(groupclick="toggleitem"),
    )
    return fig


# ---------------------------------------------------------------------------
# Disk usage treemap (from ncdu JSON export)
# ---------------------------------------------------------------------------

def _human_size(nbytes: int) -> str:
    """Format byte count as human-readable string."""
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if abs(nbytes) < 1024:
            return f"{nbytes:.1f} {unit}"
        nbytes /= 1024
    return f"{nbytes:.1f} PB"


def _walk_ncdu_node(node: list | dict, parent_id: str, depth: int,
                    records: list) -> int:
    """Walk one ncdu tree node, returning total size in bytes.

    Adds significant entries (>= TREEMAP_MIN_BYTES, depth <= TREEMAP_MAX_DEPTH)
    to *records* as ``(id, parent_id, name, size)`` tuples.
    """
    if isinstance(node, dict):
        return node.get("dsize", node.get("asize", 0))
    if not isinstance(node, list) or not node:
        return 0

    meta = node[0]
    name = meta.get("name", "?")
    node_id = f"{parent_id}/{name}" if parent_id else name
    total = 0

    for child in node[1:]:
        if isinstance(child, list):
            total += _walk_ncdu_node(child, node_id, depth + 1, records)
        elif isinstance(child, dict):
            sz = child.get("dsize", child.get("asize", 0))
            total += sz
            if depth <= TREEMAP_MAX_DEPTH and sz >= TREEMAP_MIN_BYTES:
                cname = child.get("name", "?")
                records.append((f"{node_id}/{cname}", node_id, cname, sz))

    if (total >= TREEMAP_MIN_BYTES and depth <= TREEMAP_MAX_DEPTH) or depth == 0:
        records.append((node_id, parent_id, name, total))

    return total


def _load_disk_summary() -> list[tuple] | None:
    """Load cached disk summary, regenerating from ncdu export if stale."""
    if not DISK_REPORT.exists():
        return None

    # Check cache freshness
    src_mtime = DISK_REPORT.stat().st_mtime
    if DISK_CACHE.exists():
        cache = json.loads(DISK_CACHE.read_text())
        if cache.get("mtime") == src_mtime:
            return [tuple(r) for r in cache["records"]]

    # Parse ncdu JSON and walk the tree
    print("Parsing disk report (first time may be slow)...", file=sys.stderr)
    data = json.loads(DISK_REPORT.read_text())
    root = data[3] if len(data) >= 4 and isinstance(data[3], list) else None
    if not root:
        return None

    records: list[tuple] = []
    _walk_ncdu_node(root, "", 0, records)

    # Cache the result
    DISK_CACHE.parent.mkdir(parents=True, exist_ok=True)
    DISK_CACHE.write_text(json.dumps({"mtime": src_mtime, "records": records}))
    return records


def _build_treemap() -> "go.Figure | None":
    """Build a plotly Treemap figure from disk usage data."""
    records = _load_disk_summary()
    if not records:
        return None

    ids = [r[0] for r in records]
    parents = [r[1] for r in records]
    labels = [r[2] for r in records]
    values = [r[3] for r in records]
    texts = [_human_size(r[3]) for r in records]
    log_vals = [math.log10(max(v, 1)) for v in values]
    lo, hi = min(log_vals), max(log_vals)
    span = hi - lo if hi > lo else 1
    colors = [(v - lo) / span for v in log_vals]

    fig = go.Figure(go.Treemap(
        ids=ids,
        labels=labels,
        parents=parents,
        values=values,
        text=texts,
        textinfo="label+text",
        hovertemplate="<b>%{label}</b><br>%{text}<extra>%{id}</extra>",
        marker=dict(
            colors=colors,
            colorscale="Tealrose",
            cmid=0.5,
            showscale=False,
        ),
        pathbar=dict(visible=True),
    ))

    report_date = datetime.fromtimestamp(
        DISK_REPORT.stat().st_mtime
    ).strftime("%Y-%m-%d") if DISK_REPORT.exists() else "N/A"

    fig.update_layout(
        title=f"Disk Usage — click to expand (scanned {report_date})",
        template="plotly_dark",
        height=600,
        margin=dict(t=50, b=10, l=10, r=10),
    )
    return fig


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def _add_sys_traces(fig: go.Figure, sys_series: dict, row: int) -> None:
    """Add system overview traces to the figure."""
    colors = {"CPU Used %": "#ef553b", "Mem Used %": "#636efa", "Disk Space %": "#00cc96"}
    for label, (ts_vals, pct_vals) in sys_series.items():
        if not ts_vals:
            continue
        fig.add_trace(
            go.Scatter(x=ts_vals, y=pct_vals, name=label, mode="lines",
                       line=dict(color=colors.get(label), width=2),
                       legendgroup="sys", legendgrouptitle_text="System"),
            row=row, col=1,
        )


def _add_process_traces(fig: go.Figure, series: dict, group: str, row: int) -> None:
    """Add per-process traces to the figure."""
    for name, (ts_vals, pct_vals) in series.items():
        fig.add_trace(
            go.Scatter(x=ts_vals, y=pct_vals, name=name, mode="lines",
                       legendgroup=group, legendgrouptitle_text=group.upper()),
            row=row, col=1,
        )


def _build_figure(entries: list[dict]) -> go.Figure:
    """Build the plotly figure with all panels."""
    sys_series = extract_sys_series(entries)
    has_sys = any(ts for ts, _ in sys_series.values())

    top_cpu_names = rank_processes(entries, "cpu")
    top_mem_names = rank_processes(entries, "mem")
    cpu_series = build_timeseries(entries, "cpu", top_cpu_names)
    mem_series = build_timeseries(entries, "mem", top_mem_names)

    disk_ts = [e["ts"] for e in entries]
    disk_read = [e.get("disk", {}).get("read_mb_s", 0.0) for e in entries]
    disk_write = [e.get("disk", {}).get("write_mb_s", 0.0) for e in entries]
    if not any(disk_read) and not any(disk_write):
        disk_read = [e.get("disk", {}).get("mb_s", 0.0) for e in entries]

    if has_sys:
        titles = ("System Overview", "CPU % by Process",
                  "Memory % by Process", "Disk Throughput (MB/s)")
        fig = make_subplots(rows=4, cols=1, subplot_titles=titles,
                            vertical_spacing=0.06,
                            row_heights=[0.22, 0.28, 0.28, 0.22])
        _add_sys_traces(fig, sys_series, row=1)
        fig.update_yaxes(title_text="%", range=[0, 100], row=1, col=1)
        cpu_row, mem_row, disk_row = 2, 3, 4
    else:
        titles = ("CPU % by Process", "Memory % by Process",
                  "Disk Throughput (MB/s)")
        fig = make_subplots(rows=3, cols=1, subplot_titles=titles,
                            vertical_spacing=0.08,
                            row_heights=[0.38, 0.38, 0.24])
        cpu_row, mem_row, disk_row = 1, 2, 3

    _add_process_traces(fig, cpu_series, "cpu", cpu_row)
    _add_process_traces(fig, mem_series, "mem", mem_row)

    fig.add_trace(
        go.Scatter(x=disk_ts, y=disk_read, name="Read MB/s", mode="lines",
                   line=dict(color="steelblue"), legendgroup="disk",
                   legendgrouptitle_text="Disk I/O"),
        row=disk_row, col=1)
    fig.add_trace(
        go.Scatter(x=disk_ts, y=disk_write, name="Write MB/s", mode="lines",
                   line=dict(color="coral"), legendgroup="disk"),
        row=disk_row, col=1)

    fig.update_yaxes(title_text="%", row=cpu_row, col=1)
    fig.update_yaxes(title_text="%", row=mem_row, col=1)
    fig.update_yaxes(title_text="MB/s", row=disk_row, col=1)

    window_label = entries[-1]["ts"][:16] if entries else "N/A"
    fig.update_layout(
        title=f"Resource Monitor (latest: {window_label})",
        height=1300 if has_sys else 1100,
        template="plotly_dark",
        hovermode="x unified",
        legend=dict(groupclick="toggleitem"),
    )
    return fig


def generate_report(entries: list[dict], output: Path, widget: bool = False) -> None:
    """Generate report HTML. Widget mode wraps in a floating template."""
    fig = _build_figure(entries)
    blame_fig = _build_disk_blame_figure(entries)
    treemap_fig = _build_treemap()

    hover_style = dict(
        bgcolor="rgba(40,40,40,0.95)",
        font=dict(color="white", size=12),
        bordercolor="rgba(255,255,255,0.2)",
    )

    if widget:
        for f in (fig, blame_fig, treemap_fig):
            if f is None:
                continue
            f.update_layout(
                paper_bgcolor="rgba(0,0,0,0)",
                plot_bgcolor="rgba(0,0,0,0)",
                hoverlabel=hover_style,
            )
        fig.update_layout(margin=dict(t=40, b=20, l=40, r=20))

    parts = [fig.to_html(include_plotlyjs=True, full_html=False)]
    if blame_fig:
        parts.append(blame_fig.to_html(include_plotlyjs=False, full_html=False))
    if treemap_fig:
        parts.append(treemap_fig.to_html(include_plotlyjs=False, full_html=False))
    content = "\n".join(parts)

    if widget:
        html = WIDGET_TEMPLATE.format(content=content)
    else:
        html = (
            '<!DOCTYPE html><html><head><title>Resource Monitor</title></head>'
            f'<body style="background:#111">{content}</body></html>'
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(html)


# ---------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------

class _WidgetApi:
    """JS-callable API for the floating widget."""

    def __init__(self):
        self._window = None

    def close(self):
        # os._exit avoids the deadlock between JS callback thread and
        # pywebview's main GUI thread — safe for a single-window widget.
        os._exit(0)


def show_widget(html_path: Path) -> None:
    """Open report as a floating, semi-transparent, frameless widget."""
    api = _WidgetApi()
    window = webview.create_window(
        "Resource Monitor",
        str(html_path),
        width=1450,
        height=1000,
        frameless=True,
        transparent=True,
        on_top=True,
        easy_drag=True,
        js_api=api,
    )
    api._window = window
    webview.start()


def show_windowed(html_path: Path) -> None:
    """Open report in a normal native window with title bar."""
    webview.create_window(
        "Resource Monitor",
        str(html_path),
        width=1500,
        height=1050,
    )
    webview.start()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Resource Monitor report")
    parser.add_argument("--last", help="Time window (e.g. 6h, 30m, 1d)")
    parser.add_argument("--windowed", action="store_true",
                        help="Normal window with title bar")
    parser.add_argument("--browser", action="store_true",
                        help="Open in browser")
    parser.add_argument("--no-open", action="store_true",
                        help="Generate HTML only")
    parser.add_argument("--log", type=Path, default=LOG_FILE)
    parser.add_argument("-o", "--output", type=Path, default=REPORT_FILE)
    args = parser.parse_args()

    since = None
    if args.last:
        since = datetime.now(timezone.utc) - parse_duration(args.last)

    entries = load_entries(args.log, since=since)
    if not entries:
        print("No data to report. Is the logger running?", file=sys.stderr)
        sys.exit(1)

    use_widget = not (args.browser or args.windowed or args.no_open)
    generate_report(entries, args.output, widget=use_widget)

    if args.no_open:
        print(f"Report written to {args.output}")
    elif args.browser:
        webbrowser.open(f"file://{args.output}")
    elif args.windowed:
        show_windowed(args.output)
    else:
        show_widget(args.output)


if __name__ == "__main__":
    main()
