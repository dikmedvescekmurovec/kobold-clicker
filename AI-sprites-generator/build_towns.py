"""Writes the settlements' building sprites into Assets/Towns/, then reads every file back and checks it.

A settlement is two pictures (towns.py): its ground tile goes into the hex atlas with the rest through
build.py, and its buildings are a sprite of their own, bigger than a hex, which Godot draws over the fog
(`HexMap.towns`). Like build_hpbar.py this skips Aseprite: the sprites are RGBA and ship loose.

Run `python qa.py phase3 <tag>` first and look at the images; this overwrites the files. Run build.py
too, so the ground tiles under them match.
"""
import os
from collections import Counter

from PIL import Image

import towns

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Towns")


def main():
    made = towns.sprites()
    os.makedirs(OUT, exist_ok=True)
    keep = {name + ".png" for name in made}
    for old in os.listdir(OUT):
        if old.endswith(".png") and old not in keep:
            os.remove(os.path.join(OUT, old))
    problems = Counter()
    for name, image in sorted(made.items()):
        path = os.path.join(OUT, name + ".png")
        image.save(path)
        back = Image.open(path).convert("RGBA")
        problems["wrong size"] += back.size != (towns.SPRITE_W, towns.SPRITE_H)
        problems["pixel mismatch"] += sum(a != b for a, b in zip(back.get_flattened_data(), image.get_flattened_data()))
    print("files written:", len(made), "in", os.path.normpath(OUT))
    print("problems:", dict(problems))
    print("anchor (HexMap.TOWN_ANCHOR):", towns.ANCHOR, "size:", (towns.SPRITE_W, towns.SPRITE_H))


if __name__ == "__main__":
    main()
