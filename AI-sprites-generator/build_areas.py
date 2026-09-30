"""Writes the battle backdrops into ../Assets/Area/, then reads every file back and checks it.

Like build_slimes.py this one skips Aseprite: the backdrops are ordinary RGB PNGs under Assets/
rather than tiles in the indexed hex atlas, so there is nothing to emit and no palette to hold to.
What it does do is the same verification the other builds make -- every file on disk is compared
pixel by pixel against what sideview.py drew, after the 6x upscale.

The art is 384x216 and ships at 2304x1296, nearest-neighbour: one backdrop pixel is one of the
fighters' pixels on screen (`CombatScene.AREA_UPSCALE`).

Run `python sideview.py <tag> ...` first and look at qa/side_<tag>_<env>.png; this overwrites files.
"""
import os
import re
from collections import Counter

from PIL import Image

import sideview as scenes
from sideview import H, SCALE, W

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Area")

## The names this script owns, and the only ones it will ever delete. `Summer2.png` -- the bought
## background the earlier sets were measured off -- and the `Village/` prop pack share
## this folder, and the older one-file-per-pair names (`grass_village.png`) have to go when the
## numbered ones land, because a stale PNG is a backdrop the game can still load and nobody looks
## at again.
MINE = re.compile(r"^(%s)_(%s)(_\d+)?\.png(\.import)?$"
                  % ("|".join(scenes.ENVS), "|".join(scenes.VARIANTS)))


def _locked():
    """Which of the files we are about to overwrite something else is holding open.

    Godot locks the PNGs it has imported, and without this the first one it holds raises part of
    the way through the write loop -- leaving Assets/Area half old and half new, with `_prune`
    possibly already run. A backdrop that is a mix of two builds is worse than no build at all,
    so the question is asked before a single byte is written.
    """
    held = []
    for name in sorted(os.listdir(OUT)):
        if not MINE.match(name) or not name.endswith(".png"):
            continue
        try:
            with open(os.path.join(OUT, name), "r+b"):
                pass
        except OSError:
            held.append(name)
    return held


def _prune(keep):
    """Removes backdrops this script used to write and no longer does."""
    gone = []
    for name in sorted(os.listdir(OUT)):
        if MINE.match(name) and name.split(".png")[0] + ".png" not in keep:
            os.remove(os.path.join(OUT, name))
            gone.append(name)
    return gone


def main():
    os.makedirs(OUT, exist_ok=True)
    held = _locked()
    if held:
        print("refusing to build: %d file(s) are open elsewhere, the first being %s."
              % (len(held), held[0]))
        print("Close the Godot editor -- it locks the PNGs it has imported, and a build that")
        print("dies part of the way through leaves Assets/Area half old and half new.")
        raise SystemExit(1)
    problems = Counter()
    written = []
    # Compared as each one is written rather than at the end: holding all 120 at 2304x1296 would
    # be a gigabyte of RGB for a check that only ever looks at one of them.
    for env in scenes.ENVS:
        for variant in scenes.VARIANTS:
            for layout in range(1, scenes.LAYOUTS + 1):
                im = scenes.render(env, variant, layout).resize((W * SCALE, H * SCALE),
                                                                 Image.NEAREST)
                name = "%s_%s_%d.png" % (env, variant, layout)
                path = os.path.join(OUT, name)
                im.save(path)
                written.append(name)
                back = Image.open(path).convert("RGB")
                problems["wrong size"] += back.size != im.size
                problems["pixel mismatch"] += sum(
                    a != b for a, b in zip(back.get_flattened_data(), im.get_flattened_data()))

    gone = _prune(set(written))
    print("files written:", len(written), "at", "%dx%d" % (W * SCALE, H * SCALE))
    if gone:
        print("stale files removed:", len(gone), "(%s...)" % ", ".join(gone[:3]))
    print("problems:", dict(problems))


if __name__ == "__main__":
    main()
