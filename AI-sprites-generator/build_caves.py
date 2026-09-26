"""Writes the Gollux cave's six mouths into Assets/Caves/, then reads every file back and checks it.

One picture a ground (caves.py), each the settlements' sprite size and anchor, drawn by Godot over the
fog on the settlements' layer (`HexMap.set_cave`). No ground tile goes with them: a cave stands on its
land's own tile. Like build_towns.py this skips Aseprite: the sprites are RGBA and ship loose.

Run `python qa.py caves <tag>` first and look at the image; this overwrites the files.
"""
import os
from collections import Counter

from PIL import Image

import caves
import towns

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Caves")


def main():
    made = caves.sprites()
    os.makedirs(OUT, exist_ok=True)
    problems = Counter()
    for name, image in sorted(made.items()):
        path = os.path.join(OUT, name + ".png")
        image.save(path)
        back = Image.open(path).convert("RGBA")
        problems["wrong size"] += back.size != (towns.SPRITE_W, towns.SPRITE_H)
        problems["pixel mismatch"] += sum(a != b for a, b in zip(back.get_flattened_data(), image.get_flattened_data()))
    print("files written:", len(made), "in", os.path.normpath(OUT))
    print("problems:", dict(problems))


if __name__ == "__main__":
    main()
