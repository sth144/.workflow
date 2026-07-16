#!/usr/bin/env python3
"""cad-tutor helper: capture a CAD app window and draw annotations on it.

Subcommands
-----------
shot
    Capture a screenshot of a CAD app window (FreeCAD/Blender) via macOS
    ``screencapture``. Falls back to the full main display when the window
    bounds can't be read (e.g. Accessibility permission not granted).
annotate
    Draw highlight boxes, arrows, and text labels onto an image with PIL and
    write the result to ``--out``.

Coordinates are in *pixels of the target image*. On Retina displays a
screenshot is 2x its point size, so always estimate coordinates from the
captured PNG itself, then annotate that same PNG so the coordinate spaces
match.

Examples
--------
    cad_tutor.py shot --app FreeCAD --out /tmp/cad-tutor/shot.png
    cad_tutor.py annotate --in /tmp/cad-tutor/shot.png --out ~/cad-tutor.png \\
        --box "820,140,64,64:Pad tool" --arrow "700,300,815,170:click here"
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from typing import Dict, List, Optional, Tuple

try:
    from PIL import Image, ImageDraw, ImageFont
except ImportError:  # pragma: no cover - surfaced as a clear runtime error
    Image = ImageDraw = ImageFont = None  # type: ignore

# App name -> macOS process name used by System Events.
APP_PROCESS = {
    "freecad": "FreeCAD",
    "blender": "Blender",
}

HIGHLIGHT = (255, 92, 0, 255)      # bright orange outline
FILL = (255, 92, 0, 48)            # translucent orange fill
LABEL_BG = (20, 20, 20, 210)
LABEL_FG = (255, 255, 255, 255)


def _expand(path: str) -> str:
    """Expand ``~`` and environment variables in a path."""
    return os.path.expanduser(os.path.expandvars(path))


def _window_region(app: str) -> Optional[str]:
    """Return ``x,y,w,h`` for the app's front window, or None if unavailable."""
    process = APP_PROCESS.get(app.lower())
    if not process:
        return None
    script = (
        f'tell application "System Events" to tell process "{process}"\n'
        "  set p to position of window 1\n"
        "  set s to size of window 1\n"
        '  return ((item 1 of p) as text) & "," & ((item 2 of p) as text) '
        '& "," & ((item 1 of s) as text) & "," & ((item 2 of s) as text)\n'
        "end tell"
    )
    try:
        out = subprocess.run(
            ["osascript", "-e", script],
            capture_output=True, text=True, check=True, timeout=10,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutError) as exc:
        print(f"warn: could not read {process} window bounds: {exc}", file=sys.stderr)
        return None
    region = out.stdout.strip()
    return region if region.count(",") == 3 else None


def _capture(out_path: str, region: Optional[str]) -> None:
    """Run ``screencapture`` for the given region (or full screen if None)."""
    cmd = ["screencapture", "-x"]
    if region:
        cmd += ["-R", region]
    cmd.append(out_path)
    subprocess.run(cmd, check=True, timeout=30)


def _parse_region(region: str) -> Tuple[int, int, int, int]:
    """Parse an ``x,y,w,h`` region string into four ints."""
    parts = [int(round(float(p))) for p in region.split(",")]
    if len(parts) != 4:
        raise ValueError(f"region needs 4 numbers, got: {region!r}")
    return parts[0], parts[1], parts[2], parts[3]


def _resolve_region(args: argparse.Namespace) -> Optional[Tuple[int, int, int, int]]:
    """Decide the capture region (points), or None for full-screen."""
    if args.region:
        return _parse_region(args.region)
    if not args.full and args.app:
        raw = _window_region(args.app)
        if raw is None:
            print("warn: falling back to full-screen capture", file=sys.stderr)
            return None
        return _parse_region(raw)
    return None


def _image_size(path: str) -> Optional[Tuple[int, int]]:
    """Return the pixel (width, height) of an image, or None if PIL is absent."""
    if Image is None:
        return None
    with Image.open(path) as img:
        return img.size


def _main_screen_size_pt() -> Optional[Tuple[int, int]]:
    """Return the main display size in points via the Hammerspoon CLI."""
    if not shutil.which("hs"):
        return None
    script = "local f=hs.screen.mainScreen():frame(); print(math.floor(f.w)..','..math.floor(f.h))"
    try:
        out = subprocess.run(
            ["hs", "-c", script], capture_output=True, text=True, check=True, timeout=10
        )
    except subprocess.SubprocessError:
        return None
    parts = out.stdout.strip().split(",")
    return (int(parts[0]), int(parts[1])) if len(parts) == 2 else None


def _write_sidecar(image_path: str, region: Optional[Tuple[int, int, int, int]]) -> None:
    """Record capture geometry so `highlight` can map image pixels to screen points."""
    px = _image_size(image_path)
    if region:
        origin_x, origin_y, w_pt, h_pt = region
    else:
        origin_x, origin_y = 0, 0
        size = _main_screen_size_pt()
        w_pt, h_pt = size if size else (None, None)

    if px and w_pt:
        scale = px[0] / w_pt
    else:
        scale = 2.0
        print("warn: assuming 2x Retina scale for coordinate mapping", file=sys.stderr)

    data = {
        "image": image_path,
        "origin_pt": [origin_x, origin_y],
        "size_pt": [w_pt, h_pt],
        "size_px": list(px) if px else None,
        "scale": scale,
    }
    folder = os.path.dirname(image_path) or "."
    for path in (image_path + ".json", os.path.join(folder, "last-shot.json")):
        with open(path, "w") as handle:
            json.dump(data, handle)


def cmd_shot(args: argparse.Namespace) -> int:
    """Capture a screenshot, write a geometry sidecar, and print the path."""
    out_path = _expand(args.out)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)

    region = _resolve_region(args)
    region_str = ",".join(str(v) for v in region) if region else None
    _capture(out_path, region_str)
    _write_sidecar(out_path, region)
    print(out_path)
    return 0


def _parse_ints(spec: str, count: int, label: str) -> Tuple[List[int], str]:
    """Split ``"a,b,...:text"`` into ``count`` ints plus the trailing text."""
    body, _, text = spec.partition(":")
    parts = [p.strip() for p in body.split(",")]
    if len(parts) != count:
        raise ValueError(f"{label} needs {count} numbers, got: {body!r}")
    return [int(round(float(p))) for p in parts], text.strip()


def _load_font(size: int):
    """Load a legible TrueType font, falling back to PIL's default."""
    for name in ("Helvetica.ttc", "Arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except (OSError, IOError):
            continue
    return ImageFont.load_default()


def _draw_label(draw: "ImageDraw.ImageDraw", x: int, y: int, text: str, font) -> None:
    """Draw text with a solid background box anchored at (x, y)."""
    if not text:
        return
    left, top, right, bottom = draw.textbbox((x, y), text, font=font)
    pad = 4
    draw.rectangle(
        (left - pad, top - pad, right + pad, bottom + pad), fill=LABEL_BG
    )
    draw.text((x, y), text, fill=LABEL_FG, font=font)


def _draw_box(draw: "ImageDraw.ImageDraw", spec: str, font) -> None:
    """Draw a highlight rectangle from ``"x,y,w,h[:label]"``."""
    (x, y, w, h), text = _parse_ints(spec, 4, "box")
    draw.rectangle((x, y, x + w, y + h), outline=HIGHLIGHT, width=4, fill=FILL)
    _draw_label(draw, x, max(0, y - 22), text, font)


def _draw_arrow(draw: "ImageDraw.ImageDraw", spec: str, font) -> None:
    """Draw an arrow from ``"x1,y1,x2,y2[:label]"`` pointing at (x2, y2)."""
    (x1, y1, x2, y2), text = _parse_ints(spec, 4, "arrow")
    draw.line((x1, y1, x2, y2), fill=HIGHLIGHT, width=5)
    head = _arrowhead(x1, y1, x2, y2)
    draw.polygon(head, fill=HIGHLIGHT)
    _draw_label(draw, x1, y1 - 22, text, font)


def _arrowhead(x1: int, y1: int, x2: int, y2: int, size: int = 16) -> List[Tuple[int, int]]:
    """Return the three points of an arrowhead at (x2, y2)."""
    import math
    angle = math.atan2(y2 - y1, x2 - x1)
    left = (x2 - size * math.cos(angle - math.pi / 6),
            y2 - size * math.sin(angle - math.pi / 6))
    right = (x2 - size * math.cos(angle + math.pi / 6),
             y2 - size * math.sin(angle + math.pi / 6))
    return [(x2, y2), (int(left[0]), int(left[1])), (int(right[0]), int(right[1]))]


def cmd_annotate(args: argparse.Namespace) -> int:
    """Draw annotations onto the input image and print the output path."""
    if Image is None:
        print("error: Pillow (PIL) is not installed", file=sys.stderr)
        return 1

    in_path, out_path = _expand(args.inp), _expand(args.out)
    base = Image.open(in_path).convert("RGBA")
    overlay = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    font = _load_font(args.font_size)

    for spec in args.box or []:
        _draw_box(draw, spec, font)
    for spec in args.arrow or []:
        _draw_arrow(draw, spec, font)
    for spec in args.label or []:
        (x, y), text = _parse_ints(spec, 2, "label")
        _draw_label(draw, x, y, text, font)

    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    Image.alpha_composite(base, overlay).convert("RGB").save(out_path)
    print(out_path)
    return 0


def _load_sidecar(path: str) -> Dict:
    """Load the geometry sidecar written by ``shot``."""
    with open(_expand(path)) as handle:
        return json.load(handle)


def _highlight_call(spec: str, origin: List[int], scale: float, duration: int) -> str:
    """Build one Lua ``cadHighlight(...)`` call from an image-pixel box spec."""
    (x, y, w, h), text = _parse_ints(spec, 4, "box")
    point_x = origin[0] + x / scale
    point_y = origin[1] + y / scale
    label = text.replace("]]", "]")
    return "cadHighlight(%.1f,%.1f,%.1f,%.1f,[[%s]],%d)" % (
        point_x, point_y, w / scale, h / scale, label, duration
    )


def cmd_highlight(args: argparse.Namespace) -> int:
    """Draw live on-screen highlights over the CAD app via Hammerspoon."""
    hs_bin = shutil.which("hs")
    if not hs_bin:
        print("error: Hammerspoon 'hs' CLI not found on PATH", file=sys.stderr)
        return 1
    if args.clear and not args.box:
        subprocess.run([hs_bin, "-c", "cadHighlightClear()"], check=True, timeout=10)
        return 0

    meta = _load_sidecar(args.frm)
    origin = meta.get("origin_pt", [0, 0])
    scale = meta.get("scale") or 2.0
    calls = ["cadHighlightClear()"]
    for spec in args.box or []:
        calls.append(_highlight_call(spec, origin, scale, args.duration))
    subprocess.run([hs_bin, "-c", "; ".join(calls)], check=True, timeout=15)
    print(f"highlighted {len(calls) - 1} region(s) for {args.duration}s")
    return 0


def build_parser() -> argparse.ArgumentParser:
    """Construct the argument parser for the two subcommands."""
    parser = argparse.ArgumentParser(prog="cad_tutor.py", description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)

    shot = sub.add_parser("shot", help="capture a CAD app window screenshot")
    shot.add_argument("--app", choices=sorted(APP_PROCESS), help="CAD app to capture")
    shot.add_argument("--region", help="explicit x,y,w,h region (points)")
    shot.add_argument("--full", action="store_true", help="capture the full screen")
    shot.add_argument("--out", default="/tmp/cad-tutor/shot.png", help="output PNG path")
    shot.set_defaults(func=cmd_shot)

    ann = sub.add_parser("annotate", help="draw highlights onto an image")
    ann.add_argument("--in", dest="inp", required=True, help="input image path")
    ann.add_argument("--out", default="~/cad-tutor.png", help="output PNG path")
    ann.add_argument("--box", action="append", help='"x,y,w,h[:label]" (repeatable)')
    ann.add_argument("--arrow", action="append", help='"x1,y1,x2,y2[:label]" (repeatable)')
    ann.add_argument("--label", action="append", help='"x,y:text" (repeatable)')
    ann.add_argument("--font-size", type=int, default=18, help="label font size")
    ann.set_defaults(func=cmd_annotate)

    hl = sub.add_parser("highlight", help="draw live on-screen highlights (Hammerspoon)")
    hl.add_argument("--from", dest="frm", default="/tmp/cad-tutor/last-shot.json",
                    help="geometry sidecar written by `shot`")
    hl.add_argument("--box", action="append", help='"x,y,w,h[:label]" in image pixels (repeatable)')
    hl.add_argument("--duration", type=int, default=5, help="seconds before auto-dismiss (0 = keep)")
    hl.add_argument("--clear", action="store_true", help="remove all highlights and exit")
    hl.set_defaults(func=cmd_highlight)
    return parser


def main(argv: Optional[List[str]] = None) -> int:
    """CLI entry point."""
    args = build_parser().parse_args(argv)
    try:
        return int(args.func(args))
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
