"""Shared machinery for the two builds (build.py for the hex tiles, build_ui.py for the UI kit).

Both do the same three things around their own tile lists and metadata: hand the pixels to Aseprite
through emit.lua, then read every PNG back and compare it to the source pixels, then report.
"""
import json
import os
import subprocess
from collections import Counter

from PIL import Image

ASEPRITE = r"C:\Users\Dik\Documents\Git\aseprite\aseprite\build\bin\aseprite.exe"
OUT = r"C:\Users\Dik\Documents\incremendal-side-scroller\AI-sprites"
HERE = os.path.dirname(os.path.abspath(__file__))


def ceil_div(n, d):
    """Rows needed to hold n items d to a row."""
    return (n + d - 1) // d


def write_and_emit(data, data_path):
    """Writes the pixel data Aseprite reads, runs emit.lua over it, and asserts it succeeded."""
    with open(data_path, "w") as f:
        json.dump(data, f)
    proc = subprocess.run([ASEPRITE, "-b", "--script-param", f"data={data_path}", "--script-param",
                           f"out={OUT}", "--script", os.path.join(HERE, "emit.lua")],
                          capture_output=True, text=True)
    print("aseprite:", proc.stdout.strip(), proc.stderr.strip(), "exit", proc.returncode)
    assert proc.returncode == 0


def verify(entries, palette, sheet_path, png_dir, extra=None):
    """Compares every exported PNG, and its patch of the sheet, against the pixels it was built from.

    `entries` are (tile, entry dict) pairs as the builds lay them out; `extra` is an optional
    callback(problems, tile) for checks only one of the builds makes. Returns the problem counter.
    """
    rgba = [tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for h in palette]
    sheet = Image.open(sheet_path)
    spal = sheet.getpalette()
    problems = Counter()

    def mismatch(got, pal, src):
        return sum((g == 0) != (s == 0) or (s and tuple(pal[g * 3:g * 3 + 3]) != rgba[s])
                   for g, s in zip(got, src))

    for t, e in entries:
        im = Image.open(os.path.join(png_dir(t), t.name + ".png"))
        problems["not indexed"] += im.mode != "P"
        problems["wrong size"] += im.size != (e["w"], e["h"])
        src = t.flat()
        problems["pixel mismatch"] += mismatch(list(im.get_flattened_data()), im.getpalette(), src)
        crop = sheet.crop((e["x"], e["y"], e["x"] + e["w"], e["y"] + e["h"]))
        problems["sheet mismatch"] += mismatch(list(crop.get_flattened_data()), spal, src)
        if extra:
            extra(problems, t)
    return problems, sheet


def report(problems, palette, tiles, sheet, counts):
    used = sorted({c for t in tiles for c in t.flat() if c})
    print("files on disk:", counts, "| sheet", sheet.size, sheet.mode)
    print("palette indices used:", len(used), "of", len(palette) - 1)
    print("problems:", dict(problems))
