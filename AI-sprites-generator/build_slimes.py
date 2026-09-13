"""Writes the per-environment slimes into Assets/Enemies/, then reads every file back and checks it.

Unlike build.py and build_ui.py this one does not go through Aseprite: the source is already a PNG
pack rather than pixel data authored here, and these frames ship as ordinary RGBA sprites under
Assets/ instead of joining the hex atlas, so there is no indexed sheet to emit. The verification pass
is the same idea though -- every file on disk is compared pixel by pixel against what slimes.py built.

Run `python qa.py slimes <tag>` first and look at the images; this overwrites the folders.
"""
import os
from collections import Counter

from PIL import Image

import slimes

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Enemies")

## Folder (and roster) name per environment. "Mountain Slime" reads better than "Mountains Slime".
FOLDER = {"grass": "Grass Slime", "dirt": "Dirt Slime", "desert": "Desert Slime",
          "ice": "Ice Slime", "forest": "Forest Slime", "mountains": "Mountain Slime"}


def main():
    written = []
    for env, name, img in slimes.variants():
        folder = os.path.join(OUT, FOLDER[env])
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, name + ".png")
        img.save(path)
        written.append((path, img))

    problems = Counter()
    for path, img in written:
        back = Image.open(path).convert("RGBA")
        problems["wrong size"] += back.size != img.size
        problems["pixel mismatch"] += sum(a != b for a, b in
                                          zip(back.get_flattened_data(), img.get_flattened_data()))

    print("files written:", len(written), "in", len(FOLDER), "folders")
    print("problems:", dict(problems))


if __name__ == "__main__":
    main()
