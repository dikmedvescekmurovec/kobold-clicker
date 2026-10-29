"""Writes the intro comic (`comic.py`'s reborn story) into Assets/Comic/, then reads every file back and checks it.

Each panel of a page goes in as its own picture at one comic pixel a pixel, framed in its ink line, and a page
that is one picture (the black captions, the wall) goes in whole; comic.json says, page by page, where on the
384x216 page each picture stands, which page is paper and which black, and which column of the wall a window
held upright shows. `Scenes/UI/comic.gd` lays the comic out from that file alone.

Like build_slimes.py this does not go through Aseprite: the pictures ship as ordinary sprites under Assets/.
Run `python comic.py <tag> --story reborn` (and `--phone`) first and look at the images; this overwrites the files.
"""
import argparse
import json
import os

import numpy as np
from PIL import Image

import comic

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Comic")


def framed(cut):
    """A panel with its ink line round it, as the page draws one."""
    h, w = cut.shape[:2]
    out = np.zeros((h + 2, w + 2, 3), np.uint8)
    out[:] = comic.INK
    out[1:-1, 1:-1] = cut
    return out


def main():
    argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter).parse_args()
    os.makedirs(OUT, exist_ok=True)
    pages, written = [], []
    for p, (panels, scenes) in enumerate(zip(comic.PAGES_B, comic.SCENES_B), 1):
        whole = panels == comic.FULL
        page = {"paper": not whole, "panels": []}
        for i, ((x, y, w, h), scene) in enumerate(zip(panels, scenes), 1):
            a, (sx, sy) = scene()
            cut = a[sy: sy + h, sx: sx + w]
            name = f"page{p}.png" if whole else f"page{p}_{i}.png"
            picture = cut if whole else framed(cut)
            Image.fromarray(picture).save(os.path.join(OUT, name))
            written.append((name, picture))
            page["panels"].append({"file": name, "at": [x, y] if whole else [x - 1, y - 1]})
            if scene is comic.the_wall:
                page["tall"] = comic.TALL_CENTRE
        pages.append(page)
    with open(os.path.join(OUT, "comic.json"), "w", encoding="utf-8") as f:
        json.dump({"size": [comic.W, comic.H], "pages": pages}, f, indent="\t")
        f.write("\n")

    wrong = [name for name, picture in written
             if not np.array_equal(np.array(Image.open(os.path.join(OUT, name)).convert("RGB")), picture)]
    print(f"wrote {len(written)} pictures and comic.json to {os.path.normpath(OUT)}")
    if wrong:
        raise SystemExit(f"read back wrong: {', '.join(wrong)}")
    print("every picture read back pixel for pixel")


if __name__ == "__main__":
    main()
