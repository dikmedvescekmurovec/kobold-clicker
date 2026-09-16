"""Cuts the loot beam out of the bought effects pack.

    python tools/loot_beam.py

The beam standing over a find in the arena is the "Mini Falem" effect from
``Assets/Potential/Effects``, which ships as loose 16x16 frames in nine colourways. This writes the
**white** one out as one horizontal strip, ``Assets/Effects/loot_beam.png``, which ``LootBeam`` cuts
back into frames the way ``Coins`` cuts the coin.

White, and only white, because the beam is drawn in the rarity's own colour and ``modulate``
multiplies: white times a colour is exactly that colour, where any other colourway would come back
muddied and the game would need one sheet per rarity. This is the same trick ``ui_kit.py`` leans on
for the close button's tint and ``slimes.py`` for its ramps.

It lives here rather than in ``ui_kit.py`` for the reason the gear icons live there: this is where it
is written down which frames of which bought pack are which sprite, and a second script saying that a
second way is how the two drift apart. The beam is not a theme sprite and never enters
``ui_sheet.png``.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
# The pack, the colourway, and what it is called there.
PACK = ROOT / "Assets" / "Potential" / "Effects" / "Mini Falem"
COLOURWAY = "9"
FRAME = "1_%d.png"
FRAMES = 15
SIZE = 16
OUT = ROOT / "Assets" / "Effects" / "loot_beam.png"


def main() -> None:
    strip = Image.new("RGBA", (SIZE * FRAMES, SIZE), (0, 0, 0, 0))
    for i in range(FRAMES):
        frame = Image.open(PACK / COLOURWAY / (FRAME % i)).convert("RGBA")
        if frame.size != (SIZE, SIZE):
            raise SystemExit("frame %d is %dx%d, not %d square" % ((i,) + frame.size + (SIZE,)))
        strip.alpha_composite(frame, (i * SIZE, 0))
    OUT.parent.mkdir(parents=True, exist_ok=True)
    strip.save(OUT)
    print("Wrote %s (%dx%d, %d frames)" % (OUT, strip.width, strip.height, FRAMES))


if __name__ == "__main__":
    main()
