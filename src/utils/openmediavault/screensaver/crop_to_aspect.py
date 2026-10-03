#!/usr/bin/env -S uv run --quiet --script
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "pillow>=10.0",
#     "numpy>=1.26",
#     "opencv-python-headless>=4.8",
#     "pillow-heif>=0.15",
# ]
# ///
"""Fit a directory of images to one aspect ratio, with no letterboxing.

Images whose aspect is close enough to the target are smart-cropped: a saliency
map (gradient energy weighted by saturation) chooses the crop window, and any
faces Apple Vision finds are kept whole inside it.  Images too far off the
target to crop without gutting the composition are instead scaled to fit, with
the leftover space filled by a blurred, darkened zoom of the image itself.

Incremental by default -- an output is rebuilt only when its source is newer --
so this is cheap to run on a timer over a directory that grows.

    ./crop_to_aspect.py                       # cwd -> <cwd>-16x10, 1920x1200
    ./crop_to_aspect.py --src A --dst B
    ./crop_to_aspect.py --size 2560x1600 --max-crop 0.6
"""

from __future__ import annotations

import argparse
import os
import sys
from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter, ImageOps

try:  # optional: without it, cropping falls back to pure saliency
    # Mute the backend-selection notice OpenCV prints on every load.
    os.environ.setdefault("OPENCV_LOG_LEVEL", "ERROR")
    import cv2
except ImportError:
    cv2 = None

try:  # optional: lets the cropper read iPhone HEIC/HEIF files
    import pillow_heif

    pillow_heif.register_heif_opener()
except ImportError:
    pass

# Saliency is computed on a thumbnail; 384px is plenty to find the busy region
# and keeps the whole run well under a second per image.
PROFILE_PX = 384

# Saturation counts for something, but edges dominate -- a flat red field is
# not as interesting as a face or a horizon.
SATURATION_WEIGHT = 0.3

# Pull the crop toward the middle when saliency is nearly flat, so that ties
# resolve to a sane framing instead of an arbitrary edge.
CENTER_BIAS = 0.25

# For vertical crops, aim slightly above centre: in tall compositions the
# subject usually sits in the upper half.
VERTICAL_BIAS_TARGET = 0.45

# YuNet returns a tight box around the face only; pad it so hair and chin
# survive the crop too.
FACE_PADDING = 0.5

# YuNet weights (OpenCV zoo). Searched next to this script, then /opt/models.
FACE_MODEL_NAME = "face_detection_yunet_2023mar.onnx"
FACE_SCORE_THRESHOLD = 0.6

# YuNet is trained on modest inputs and a 4000px painting only slows it down;
# detect on a downscaled copy and scale the boxes back up.
FACE_DETECT_MAX_SIDE = 1024

# Warn when the chosen crop is this much smaller than the output size, i.e.
# the source is too low-resolution to fill the panel honestly.
LOWRES_RATIO = 0.75

IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp", ".gif", ".tif", ".tiff", ".bmp",
                  ".heic", ".heif"}


@dataclass
class Result:
    name: str
    mode: str
    detail: str


# --------------------------------------------------------------------------
# discovery
# --------------------------------------------------------------------------

def is_visible(path: Path) -> bool:
    """False for dotfiles and the ``._name`` AppleDouble sidecars that macOS
    scatters over SMB shares -- those shadow real names and must never be
    treated as either input or output."""
    return not path.name.startswith(".")


def discover_sources(src: Path) -> list[Path]:
    """Image files in *src*, skipping AppleDouble and dotfile noise."""
    return [
        path
        for path in sorted(src.iterdir())
        if path.is_file() and is_visible(path) and path.suffix.lower() in IMAGE_SUFFIXES
    ]


def output_path(source: Path, dst: Path) -> Path:
    return dst / f"{source.stem}.jpg"


def needs_rebuild(source: Path, target: Path, force: bool) -> bool:
    if force or not target.exists():
        return True
    return source.stat().st_mtime > target.stat().st_mtime


# --------------------------------------------------------------------------
# face detection (YuNet, via OpenCV)
# --------------------------------------------------------------------------

def find_face_model() -> Path | None:
    """Locate the YuNet weights, or None if they are not deployed."""
    override = os.environ.get("SCREENSAVER_FACE_MODEL")
    candidates = [Path(override)] if override else [
        Path(__file__).resolve().parent / FACE_MODEL_NAME,
        Path("/opt/models") / FACE_MODEL_NAME,
    ]
    return next((path for path in candidates if path.is_file()), None)


def build_face_detector():
    """A YuNet detector, or None when OpenCV or the weights are missing.

    Face detection refines the crop rather than enabling it: without a
    detector the framing falls back to pure saliency, which already puts
    faces in shot most of the time because faces are high-contrast.
    """
    if cv2 is None:
        return None

    model = find_face_model()
    if model is None:
        return None

    try:
        return cv2.FaceDetectorYN.create(
            str(model), "", (320, 320), score_threshold=FACE_SCORE_THRESHOLD
        )
    except cv2.error as exc:
        print(f"  ! face detector unavailable: {exc}", file=sys.stderr)
        return None


def detect_faces(image: Image.Image, detector) -> list[dict]:
    """Face boxes in *image*, in its own pixel coordinates."""
    if detector is None:
        return []

    frame = cv2.cvtColor(np.asarray(image), cv2.COLOR_RGB2BGR)
    height, width = frame.shape[:2]

    scale = min(1.0, FACE_DETECT_MAX_SIDE / max(width, height))
    if scale < 1.0:
        frame = cv2.resize(
            frame,
            (round(width * scale), round(height * scale)),
            interpolation=cv2.INTER_AREA,
        )

    detector.setInputSize((frame.shape[1], frame.shape[0]))
    try:
        _, found = detector.detect(frame)
    except cv2.error:
        return []

    if found is None:
        return []

    return [
        {
            "x": float(face[0]) / scale,
            "y": float(face[1]) / scale,
            "w": float(face[2]) / scale,
            "h": float(face[3]) / scale,
            "conf": float(face[-1]),
        }
        for face in found
    ]


def face_spans(faces: list[dict], axis: str, span: float) -> list[tuple[float, float]]:
    """Face extents along *axis*, padded and normalised to [0, 1]."""
    spans = []
    for face in faces:
        if axis == "x":
            start, size = face["x"], face["w"]
        else:
            start, size = face["y"], face["h"]
        pad = size * FACE_PADDING
        lo = max(0.0, (start - pad) / span)
        hi = min(1.0, (start + size + pad) / span)
        spans.append((lo, hi))
    return spans


# --------------------------------------------------------------------------
# saliency
# --------------------------------------------------------------------------

def energy_profile(image: Image.Image, axis: str) -> np.ndarray:
    """1-D saliency profile along *axis* ('x' -> per column, 'y' -> per row)."""
    thumb = image.copy()
    thumb.thumbnail((PROFILE_PX, PROFILE_PX), Image.Resampling.BILINEAR)

    arr = np.asarray(thumb, dtype=np.float32) / 255.0
    gray = arr.mean(axis=2)

    gx = np.zeros_like(gray)
    gy = np.zeros_like(gray)
    gx[:, 1:] = np.abs(np.diff(gray, axis=1))
    gy[1:, :] = np.abs(np.diff(gray, axis=0))

    saturation = arr.max(axis=2) - arr.min(axis=2)
    energy = gx + gy + SATURATION_WEIGHT * saturation

    return energy.sum(axis=0 if axis == "x" else 1)


def window_sums(profile: np.ndarray, width: int) -> np.ndarray:
    """Sum of *profile* over every window of *width* consecutive entries."""
    cumulative = np.concatenate(([0.0], np.cumsum(profile, dtype=np.float64)))
    return cumulative[width:] - cumulative[:-width]


def centre_bias(centres: np.ndarray, axis: str) -> np.ndarray:
    target = 0.5 if axis == "x" else VERTICAL_BIAS_TARGET
    return 1.0 - CENTER_BIAS * np.abs(centres - target) * 2.0


def faces_contained(starts: np.ndarray, ends: np.ndarray, spans: list) -> np.ndarray:
    """How many face spans fall entirely within each candidate window."""
    counts = np.zeros(starts.shape, dtype=np.int32)
    for lo, hi in spans:
        counts += ((starts <= lo) & (ends >= hi)).astype(np.int32)
    return counts


def best_offset(image: Image.Image, axis: str, window_ratio: float, spans: list) -> float:
    """Pick the crop offset, as a fraction of the axis, maximising saliency.

    Windows that hold more faces always beat windows that hold fewer; saliency
    only breaks ties among equally face-complete framings.
    """
    profile = energy_profile(image, axis)
    total = len(profile)
    width = max(1, min(total, round(window_ratio * total)))
    if width >= total:
        return 0.0

    scores = window_sums(profile, width)
    offsets = np.arange(len(scores), dtype=np.float64)
    starts = offsets / total
    ends = (offsets + width) / total

    scores = scores * centre_bias((starts + ends) / 2.0, axis)

    if spans:
        counts = faces_contained(starts, ends, spans)
        scores = np.where(counts == counts.max(), scores, -np.inf)

    return float(starts[int(np.argmax(scores))])


# --------------------------------------------------------------------------
# the two fitting strategies
# --------------------------------------------------------------------------

def crop_geometry(size: tuple[int, int], aspect: float) -> tuple[str, int, int]:
    """Return (axis to slide along, window size on that axis, full axis size)."""
    width, height = size
    if width / height > aspect:
        return "x", round(height * aspect), width
    return "y", round(width / aspect), height


def smart_crop(image: Image.Image, aspect: float, faces: list[dict]) -> Image.Image:
    width, height = image.size
    axis, window, span = crop_geometry(image.size, aspect)
    if window >= span:
        return image

    spans = face_spans(faces, axis, span)
    offset = round(best_offset(image, axis, window / span, spans) * span)
    offset = max(0, min(offset, span - window))

    if axis == "x":
        return image.crop((offset, 0, offset + window, height))
    return image.crop((0, offset, width, offset + window))


def blur_fill(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Scale to fit, filling the remainder with a blurred zoom of the image."""
    target_w, target_h = size

    # Blur small then upscale: visually identical to a huge-radius blur on the
    # full-size image, and far cheaper.
    small = (max(1, target_w // 8), max(1, target_h // 8))
    background = ImageOps.fit(image, small, Image.Resampling.LANCZOS)
    background = background.filter(ImageFilter.GaussianBlur(radius=10))
    background = background.resize(size, Image.Resampling.BICUBIC)
    background = ImageEnhance.Brightness(background).enhance(0.55)

    scale = min(target_w / image.width, target_h / image.height)
    fitted = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    background.paste(fitted, ((target_w - fitted.width) // 2, (target_h - fitted.height) // 2))
    return background


# --------------------------------------------------------------------------
# per-image pipeline
# --------------------------------------------------------------------------

def keep_fraction(size: tuple[int, int], aspect: float) -> float:
    """Fraction of the cropped axis that a hard crop to *aspect* would retain."""
    source_aspect = size[0] / size[1]
    return aspect / source_aspect if source_aspect > aspect else source_aspect / aspect


def load_image(path: Path) -> Image.Image:
    image = Image.open(path)
    image = ImageOps.exif_transpose(image)
    return image.convert("RGB")


def render(image: Image.Image, size: tuple[int, int], max_crop: float,
           detector) -> tuple[Image.Image, str, float, float, list]:
    """Fit *image* to *size*. Returns the image, the mode used, the fraction of
    the composition kept, the source-to-output resolution ratio, and any faces
    the crop had to work around."""
    aspect = size[0] / size[1]
    keep = keep_fraction(image.size, aspect)

    if keep < max_crop:
        # Source pixels available per output pixel; <1 means we are upscaling.
        fitted = min(size[0] / image.width, size[1] / image.height)
        return blur_fill(image, size), "fill", 1.0, 1.0 / fitted, []

    # Only a crop can cut a face; a blur-fill keeps the whole image regardless,
    # so detection is skipped there.
    faces = detect_faces(image, detector)
    cropped = smart_crop(image, aspect, faces)
    return (cropped.resize(size, Image.Resampling.LANCZOS), "crop", keep,
            cropped.width / size[0], faces)


def describe(mode: str, keep: float, scale: float, faces: list) -> str:
    note = "fits whole" if mode == "fill" else f"kept {keep:.0%}"
    if mode == "crop" and faces:
        note += f", {len(faces)} face{'s' if len(faces) != 1 else ''} held"
    if scale < LOWRES_RATIO:
        note += f"  [LOW-RES: upscaled {1 / max(scale, 1e-6):.1f}x]"
    return note


def process(source: Path, target: Path, size: tuple[int, int], max_crop: float,
            detector, quality: int) -> Result:
    image = load_image(source)
    output, mode, keep, scale, faces = render(image, size, max_crop, detector)
    output.save(target, "JPEG", quality=quality, optimize=True, progressive=True)
    return Result(source.name, mode, describe(mode, keep, scale, faces))


# --------------------------------------------------------------------------
# entry point
# --------------------------------------------------------------------------

def parse_size(text: str) -> tuple[int, int]:
    try:
        width, height = (int(part) for part in text.lower().split("x"))
    except ValueError:
        raise argparse.ArgumentTypeError(f"expected WIDTHxHEIGHT, got {text!r}") from None
    if width < 1 or height < 1:
        raise argparse.ArgumentTypeError("dimensions must be positive")
    return width, height


def parse_args(argv: list[str] | None) -> argparse.Namespace:
    here = Path(__file__).resolve().parent
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", type=Path, default=here, help="source directory")
    parser.add_argument("--dst", type=Path, default=None, help="output directory")
    parser.add_argument("--size", type=parse_size, default=(1920, 1200), help="output WIDTHxHEIGHT")
    parser.add_argument("--max-crop", type=float, default=0.70,
                        help="crop when at least this fraction survives, else blur-fill")
    parser.add_argument("--quality", type=int, default=88, help="JPEG quality")
    parser.add_argument("--no-faces", action="store_true",
                        help="skip face detection and frame on saliency alone")
    parser.add_argument("--force", action="store_true", help="rebuild every image")
    parser.add_argument("--prune", action="store_true", help="delete outputs whose source is gone")
    return parser.parse_args(argv)


def prune_orphans(dst: Path, expected: set[str]) -> int:
    removed = 0
    for path in dst.glob("*.jpg"):
        if is_visible(path) and path.name not in expected:
            path.unlink()
            removed += 1
    return removed


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    src = args.src.resolve()
    dst = (args.dst or src.with_name(f"{src.name}-{args.size[0]}x{args.size[1]}")).resolve()
    if dst == src:
        print("error: --dst must differ from --src", file=sys.stderr)
        return 2
    dst.mkdir(parents=True, exist_ok=True)

    sources = discover_sources(src)
    if not sources:
        print(f"no images found in {src}")
        return 0

    pending = [p for p in sources if needs_rebuild(p, output_path(p, dst), args.force)]
    print(f"{len(sources)} image(s) in {src.name}; {len(pending)} to process -> {dst}")

    detector = None if args.no_faces else build_face_detector()
    if detector is None and not args.no_faces:
        print("  ! no face detector; framing on saliency alone", file=sys.stderr)

    results: list[Result] = []
    for source in pending:
        try:
            results.append(process(source, output_path(source, dst), args.size,
                                   args.max_crop, detector, args.quality))
        except (OSError, ValueError) as exc:
            print(f"  ! {source.name}: {exc}", file=sys.stderr)

    for result in results:
        print(f"  {result.mode:<5} {result.name:<58} {result.detail}")

    if args.prune:
        removed = prune_orphans(dst, {output_path(p, dst).name for p in sources})
        if removed:
            print(f"pruned {removed} orphaned output(s)")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
