#!/usr/bin/env python3

import os
import sys
import subprocess
from moviepy import VideoFileClip, concatenate_videoclips

# ------------------------
# Defaults (sane + predictable)
# ------------------------
DEFAULT_SLOWDOWN = 0.5   # 0.5 = 2x slower
DEFAULT_LOOPS = 3

# ------------------------
# Argument parsing
# ------------------------
if len(sys.argv) < 3:
    print("Usage:")
    print("  smooth_loop_mp4.py <input.mp4> <output.mp4>")
    print("  smooth_loop_mp4.py <input.mp4> <output.mp4> usedefaults")
    print("  smooth_loop_mp4.py <input.mp4> <output.mp4> <slowdown> [loops]")
    sys.exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]

if not os.path.isfile(input_file):
    print(f"ERROR: Input file does not exist: {input_file}")
    sys.exit(1)

# ------------------------
# Parameter resolution
# ------------------------
slowdown = None
loops = None

# Case 1: scripted defaults
if len(sys.argv) >= 4 and sys.argv[3].lower() == "usedefaults":
    slowdown = DEFAULT_SLOWDOWN
    loops = DEFAULT_LOOPS

# Case 2: scripted explicit values
elif len(sys.argv) >= 4:
    try:
        slowdown = float(sys.argv[3])
        if slowdown <= 0:
            raise ValueError("slowdown must be > 0")
    except ValueError as e:
        print(f"Invalid slowdown value: {sys.argv[3]} ({e})")
        sys.exit(1)

    if len(sys.argv) >= 5:
        try:
            loops = int(sys.argv[4])
            if loops < 1:
                raise ValueError("loops must be >= 1")
        except ValueError as e:
            print(f"Invalid loop count: {sys.argv[4]} ({e})")
            sys.exit(1)
    else:
        loops = DEFAULT_LOOPS

# Case 3: interactive (no extra args)
else:
    try:
        slowdown = float(
            input(f"Slowdown factor (default {DEFAULT_SLOWDOWN}): ").strip()
            or DEFAULT_SLOWDOWN
        )
        loops = int(
            input(f"Loop count (default {DEFAULT_LOOPS}): ").strip()
            or DEFAULT_LOOPS
        )
        if slowdown <= 0 or loops < 1:
            raise ValueError
    except ValueError:
        print("Invalid input")
        sys.exit(1)

print(f"▶ Slowdown: {slowdown}")
print(f"▶ Loops:    {loops}")

# ------------------------
# Temp paths
# ------------------------
tmp_dir = os.path.expanduser("~/tmp")
os.makedirs(tmp_dir, exist_ok=True)

base = os.path.basename(input_file)
norm_path = os.path.join(tmp_dir, f"norm.{base}")
interp_path = os.path.join(tmp_dir, f"interp.{base}")

# ------------------------
# 1️⃣ Timing normalization (NO slowdown)
# ------------------------
subprocess.run(
    [
        "ffmpeg",
        "-y",
        "-i", input_file,
        "-vf", "setpts=PTS-STARTPTS",
        "-an",
        norm_path
    ],
    check=True
)

# ------------------------
# 2️⃣ Motion interpolation (duration preserved)
# ------------------------
subprocess.run(
    [
        "ffmpeg",
        "-y",
        "-i", norm_path,
        "-vf",
        "minterpolate=fps=60:"
        "mi_mode=mci:"
        "mc_mode=aobmc:"
        "me_mode=bidir:"
        "vsbmc=1",
        "-an",
        "-crf", "12",
        interp_path
    ],
    check=True
)

# ------------------------
# 3️⃣ Single slowdown + looping (MoviePy 2.x)
# ------------------------
clip = VideoFileClip(interp_path)

if slowdown != 1.0:
    clip = clip.with_speed_scaled(1 / slowdown)

final = concatenate_videoclips([clip] * loops)

final.write_videofile(
    output_file,
    fps=clip.fps,
    audio=False,
    codec="libx264",
    preset="slow"
)

# ------------------------
# Cleanup
# ------------------------
clip.close()
final.close()

os.remove(norm_path)
os.remove(interp_path)

print(f"✅ Done: {output_file}")

