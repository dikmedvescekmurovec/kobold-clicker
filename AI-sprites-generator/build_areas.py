"""Writes the battle backdrops' layers into ../Assets/Area/, then reads every file back and checks it.

Like build_slimes.py this one skips Aseprite: the layers are ordinary PNGs under Assets/ rather
than tiles in the indexed hex atlas, so there is nothing to emit and no palette to hold to. What it
does do is the same verification the other builds make -- every file on disk is compared pixel by
pixel against what sideview.py drew -- and every layer's join is checked (`sideview.seam`), since
each one repeats as it scrolls.

Three kinds of file, all on the 384x216 grid the fighters stand on (CombatScene scales them up):
- `sky/<sky>.png`, one a sky, opaque;
- `land/<env>_<layout>_<band>.png`, a place's land in bands from the farthest (1), clear above;
- `<env>_<variant>_<layout>.png`, the ground the fight stands on and all that stands on it.

Run `python sideview.py skies <tag>` (and `scroll`) first and look at the previews; this overwrites
files.
"""
import os
import re
from collections import Counter

import numpy as np
from PIL import Image

import sideview as scenes

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Area")
SKY, LAND = os.path.join(OUT, "sky"), os.path.join(OUT, "land")

## The ground layers' names in OUT, the only ones there this script will ever delete. `Summer2.png`
## -- the bought background the earlier sets were measured off -- the `Village/` prop pack and the
## cave's `cave/` share this folder. `sky/` and `land/` are wholly this script's.
MINE = re.compile(r"^(%s)_(%s)(_\d+)?\.png(\.import)?$"
                  % ("|".join(scenes.ENVS), "|".join(scenes.VARIANTS)))


def _owned():
    """Every PNG this script may overwrite or delete, as (folder, name)."""
    out = [(OUT, n) for n in sorted(os.listdir(OUT)) if MINE.match(n) and n.endswith(".png")]
    for folder in (SKY, LAND):
        if os.path.isdir(folder):
            out += [(folder, n) for n in sorted(os.listdir(folder)) if n.endswith(".png")]
    return out


def _locked():
    """Which of the files we are about to overwrite something else is holding open.

    Godot locks the PNGs it has imported, and without this the first one it holds raises part of
    the way through the write loop -- leaving Assets/Area half old and half new, with `_prune`
    possibly already run. A backdrop that is a mix of two builds is worse than no build at all,
    so the question is asked before a single byte is written.
    """
    held = []
    for folder, name in _owned():
        try:
            with open(os.path.join(folder, name), "r+b"):
                pass
        except OSError:
            held.append(name)
    return held


def _prune(keep):
    """Removes files this script used to write and no longer does, with their .import."""
    gone = []
    for folder, name in _owned():
        path = os.path.join(folder, name)
        if path not in keep:
            for p in (path, path + ".import"):
                if os.path.exists(p):
                    os.remove(p)
            gone.append(name)
    return gone


def main():
    for folder in (OUT, SKY, LAND):
        os.makedirs(folder, exist_ok=True)
    held = _locked()
    if held:
        print("refusing to build: %d file(s) are open elsewhere, the first being %s."
              % (len(held), held[0]))
        print("Close the Godot editor -- it locks the PNGs it has imported, and a build that")
        print("dies part of the way through leaves Assets/Area half old and half new.")
        raise SystemExit(1)
    problems = Counter()
    written = set()

    def write(path, layer, opaque=False):
        score = scenes.seam(layer)
        problems["seam"] += int(score > scenes.SEAM)
        if score > scenes.SEAM:
            print("seam %.2f: %s" % (score, os.path.relpath(path, OUT)))
        im = Image.fromarray(layer[..., :3] if opaque else layer, "RGB" if opaque else "RGBA")
        im.save(path)
        written.add(path)
        back = np.array(Image.open(path).convert(im.mode))
        problems["wrong size"] += back.shape != np.array(im).shape
        problems["pixel mismatch"] += int((back != np.array(im)).any(axis=-1).sum())

    for name in scenes.SKIES:
        write(os.path.join(SKY, "%s.png" % name), scenes.sky_layer(name), opaque=True)
    for env in scenes.ENVS:
        for layout in range(1, scenes.LAYOUTS + 1):
            for variant in scenes.VARIANTS:
                stack = scenes.layers(env, variant, layout)
                # The land is the same under every variant of a layout: written once, with the plain.
                if variant == "plain":
                    for band, layer in enumerate(stack[:-1], 1):
                        write(os.path.join(LAND, "%s_%d_%d.png" % (env, layout, band)), layer)
                write(os.path.join(OUT, "%s_%s_%d.png" % (env, variant, layout)), stack[-1])

    gone = _prune(written)
    print("files written:", len(written), "at %dx%d" % (scenes.W, scenes.H))
    if gone:
        print("stale files removed:", len(gone), "(%s...)" % ", ".join(gone[:3]))
    print("problems:", dict(problems))
    raise SystemExit(1 if any(problems.values()) else 0)


if __name__ == "__main__":
    main()
