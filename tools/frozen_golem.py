"""The Frozen Golem: the Stone Golem pack's sheets recoloured into ENDESGA 64 ice (the user's pick, "icebound",
2026-10-29), with snow on every surface that faces the sky and icicles under the arms and chin.

Only colours change and only empty pixels gain icicles, so every frame keeps the Stone Golem's `frame` and `bounds`.
The pack draws the loincloth and the wrist bands in the same three browns, so both turn to ice: a recolour cannot
tell them apart. Icicles start above `FEET` so none hang from the ground line, inside the roster's crop.

No arguments writes the preview `tools/qa/frozen_golem.png` (the pack's golem over the frozen one, five frames).
`--export` writes `Assets/Enemies/Stone Golem/frozen/<SHEET>.png`. Run the Godot import after it.
"""
import argparse
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Assets/Enemies/Stone Golem/new version/Sprites/outline"
OUT = ROOT / "Assets/Enemies/Stone Golem/frozen"
SHEETS = ("IDLE", "WALK", "ATTACK", "HURT", "DEATH")
W, H = 220, 96  # EnemyRoster's frame for the golem
FEET = 74


def _rgb(s):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


INK = _rgb("131313")
# The pack's colours -> ENDESGA 64: frost-lit stone, ice bands and cloth, ice-lit eyes, the swing's arc in ice.
ICEBOUND = {_rgb(a): _rgb(b) for a, b in {
    "3d3d3d": "424c6e", "5d5d5d": "657392", "858585": "92a1b9", "b4b4b4": "c7cfdd", "636162": "657392",
    "512b28": "0069aa", "804b38": "0098dc", "b27b59": "00cdf9",
    "ffc825": "94fdff", "ffa214": "0cf1ff", "c7cfdd": "ffffff", "92a1b9": "94fdff",
}.items()}
SNOW, FROST = _rgb("ffffff"), _rgb("c7cfdd")
ICICLE = (_rgb("94fdff"), _rgb("00cdf9"))


def freeze(frame):
    src = frame.load()
    out = frame.copy()
    px = out.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = src[x, y]
            if a and (r, g, b) in ICEBOUND:
                px[x, y] = ICEBOUND[(r, g, b)] + (a,)

    def body(x, y):
        return 0 <= x < W and 0 <= y < H and src[x, y][3] and src[x, y][:3] != INK

    def clear(x, y):
        return not (0 <= x < W and 0 <= y < H) or src[x, y][3] == 0

    for x in range(W):
        for y in range(2, H - 4):
            # Snow: a body pixel under its outline with open air above, two rows of white and one of frost.
            if body(x, y) and src[x, y - 1][:3] == INK and clear(x, y - 2):
                for k, colour in enumerate((SNOW, SNOW, FROST)):
                    if body(x, y + k):
                        px[x, y + k] = colour + (255,)
            # An icicle under a body pixel whose outline hangs over open air, at every third such spot.
            if (y < FEET and body(x, y) and src[x, y + 1][:3] == INK and clear(x, y + 2)
                    and (x * 7 + y * 3) % 3 == 0 and clear(x - 1, y + 2) and clear(x + 1, y + 2)):
                n = 3 + (x * 13 + y) % 4
                for k in range(n):
                    yy = y + 2 + k
                    if yy >= H or not clear(x, yy):
                        break
                    px[x, yy] = ICICLE[k * 2 // n] + (255,)
                    for side in (x - 1, x + 1):
                        if k < n - 1 and clear(side, yy):
                            px[side, yy] = INK + (255,)
                    if yy + 1 < H and clear(x, yy + 1):
                        px[x, yy + 1] = INK + (255,)
    return out


def frozen_sheet(name):
    sheet = Image.open(SRC / f"{name}.png").convert("RGBA")
    out = Image.new("RGBA", sheet.size)
    for i in range(sheet.width // W):
        out.paste(freeze(sheet.crop((i * W, 0, i * W + W, H))), (i * W, 0))
    return out


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--export", action="store_true", help="write the sheets into Assets/")
    args = parser.parse_args()
    if args.export:
        OUT.mkdir(exist_ok=True)
        for name in SHEETS:
            frozen_sheet(name).save(OUT / f"{name}.png")
            print("wrote", OUT / f"{name}.png")
        return
    samples = (("IDLE", 0), ("WALK", 3), ("ATTACK", 6), ("ATTACK", 10), ("DEATH", 6))
    preview = Image.new("RGBA", (W * len(samples), H * 2), (0x1a, 0x19, 0x32, 255))
    for c, (name, i) in enumerate(samples):
        frame = Image.open(SRC / f"{name}.png").convert("RGBA").crop((i * W, 0, i * W + W, H))
        preview.alpha_composite(frame, (c * W, 0))
        preview.alpha_composite(freeze(frame), (c * W, H))
    path = ROOT / "tools/qa/frozen_golem.png"
    preview.resize((preview.width * 3, preview.height * 3), Image.NEAREST).save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
