"""Writes the health bar's parts into Assets/UI/, then reads every file back and checks it.

Like build_slimes.py this does not go through Aseprite: the parts are drawn straight to RGBA and ship
as ordinary sprites under Assets/, not as indexed tiles in the hex atlas. The verification pass is
the same idea -- every file on disk is compared pixel by pixel against what hpbar.py built.

They go in loose and stay out of ui_sheet.png and ui_sheet.json, the way the pip parts do: a part is
drawn at its own size and never stretched, so it has no nine-slice and no business in the theme
sheet. test_ui_theme also counts that sheet exactly, and a sprite added to it would fail the count.

Run `python qa.py hpbar <tag>` first and look at the images; this overwrites the files.
"""
import os
from collections import Counter

from PIL import Image

import hpbar

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "UI")


def main():
    made = hpbar.parts()
    os.makedirs(OUT, exist_ok=True)
    written = []
    for name, image in sorted(made.items()):
        path = os.path.join(OUT, name + ".png")
        image.save(path)
        written.append((path, image))

    problems = Counter()
    for path, image in written:
        back = Image.open(path).convert("RGBA")
        problems["wrong size"] += back.size != image.size
        problems["pixel mismatch"] += sum(a != b for a, b in
                                          zip(back.get_flattened_data(), image.get_flattened_data()))

    # The two numbers health_bar.gd writes down and asserts against. Printed so a change to the art
    # that moves them is seen here rather than in a failing test.
    caps = {t: hpbar.cap_width(t) for t in hpbar.TIERS}
    print("files written:", len(written), "in", os.path.normpath(OUT))
    print("problems:", dict(problems))
    print("segments: %d, trough: %d px, caps: %s" % (hpbar.SEGMENTS, hpbar.trough(), caps))
    for tier in hpbar.TIERS:
        print("  %-6s bar %d px wide" % (tier, hpbar.bar(tier, 1.0, made).width))


if __name__ == "__main__":
    main()
