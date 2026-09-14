"""Writes the battle backdrops into ../Assets/Area/, then reads every file back and checks it.

Like build_slimes.py this one skips Aseprite: the backdrops are ordinary RGB PNGs under Assets/
rather than tiles in the indexed hex atlas, so there is nothing to emit and no palette to hold to.
What it does do is the same verification the other builds make -- every file on disk is compared
pixel by pixel against what areas.py drew, after the 4x upscale.

The art is 576x324 and ships at 2304x1296, nearest-neighbour, the scale the reference is drawn at.

Run `python areas.py sheet <tag>` first and look at qa/area_sheet_<tag>.png; this overwrites files.
"""
import os
import re
from collections import Counter

from PIL import Image

import areas
from arealib import H, SCALE, W

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Area")

## The names this script owns, and the only ones it will ever delete. `Summer2.png` -- the
## hand-drawn reference the whole skeleton was measured off -- and the `Village/` prop pack share
## this folder, and the older one-file-per-pair names (`grass_village.png`) have to go when the
## numbered ones land, because a stale PNG is a backdrop the game can still load and nobody looks
## at again.
MINE = re.compile(r"^(%s)_(%s)(_\d+)?\.png(\.import)?$"
                  % ("|".join(areas.ENVS), "|".join(areas.VARIANTS)))


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
    problems = Counter()
    written = []
    # Compared as each one is written rather than at the end: holding all 120 at 2304x1296 would
    # be a gigabyte of RGB for a check that only ever looks at one of them.
    for env in areas.ENVS:
        for variant in areas.VARIANTS:
            for layout in range(1, areas.LAYOUTS_PER_VARIANT + 1):
                im = areas.scene(env, variant, layout=layout).resize((W * SCALE, H * SCALE),
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
