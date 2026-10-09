"""The skill-node stones: the user's three pixellab stones (strength red, dexterity green, intelligence blue,
`Assets/Potential/Stones/<attr>.png`) with a Roman numeral I to IX carved into each face, and the tree's small
nodes: each stone at 16 px with no numeral, and the user's fourth, grey stone (`base.png`) as the tree's root.

Plain Python and Pillow, no Godot. With no arguments it writes the previews `tools/qa/skill_stones.png` (every
carved stone at 6x on cream) and `tools/qa/skill_nodes.png` (the small ones and the root at 6x) only; `--export`
also writes `Assets/Skills/Stones/<attr>_<n>.png`, `Assets/Skills/Stones/<attr>_small.png` and `base_small.png`
(an empty slot), and `Assets/Skills/root.png`. Run the Godot import after it.

A numeral is a groove in the stone's own dark colours, deepest on the wall that faces away from the light, with a
broken lit lip on its lower and right side, where light from the top left would catch the far wall of a cut.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "Assets", "Potential", "Stones")
OUT = os.path.join(ROOT, "Assets", "Skills", "Stones")
QA = os.path.join(ROOT, "tools", "qa")
ATTRS = ["str", "dex", "int"]
LEVELS = 9
# The grey stone, of no attribute: the root, whole, and an empty slot, small.
BASE = "base"
# The tree's node, a side: half the carved stone's 32.
SMALL = 16

# Letters as a stonecutter cuts them, 9 rows tall: thick and thin strokes (a V's and an X's left-hand stroke heavy,
# the other a hairline), flared serifs, and no two I's alike -- serifs flared to either side, one cut narrow
# halfway, one short and missing its top serif. Each stroke stays straight: an I stepped sideways read as a Z.
LETTERS = {
    "I1": """
###
.##
.##
.##
..#
.##
.##
.##
###
""",
    "I2": """
###
##.
##.
##.
##.
##.
##.
##.
###
""",
    "I3": """
...
.##
.##
.##
.##
.##
.##
.##
###
""",
    "V": """
###..##
.##...#
.##..#.
..##.#.
..##.#.
..###..
...##..
...##..
...#...
""",
    "X": """
###...##
.##..#..
..##.#..
..###...
...##...
...##...
..#.##..
.#..##..
##...###
""",
}
# Which I goes where, so the I's of one numeral differ.
ROMAN = [["I1"], ["I1", "I2"], ["I1", "I3", "I2"], ["I2", "V"], ["V"], ["V", "I1"], ["V", "I1", "I3"],
         ["V", "I1", "I3", "I2"], ["I1", "X"]]


def rows(text):
    return text.strip().splitlines()


def glyph(letters):
    cells, x0 = set(), 0
    for name in letters:
        r = rows(LETTERS[name])
        cells |= {(x + x0, y) for y, line in enumerate(r) for x, c in enumerate(line) if c == "#"}
        x0 += len(r[0]) + 1
    return cells, x0 - 1, 9


def lightness(px):
    return 0.299 * px[0] + 0.587 * px[1] + 0.114 * px[2]


def carve(stone, letters):
    im = stone.copy()
    w, h = im.size
    cx, cy = (w - 1) / 2, (h - 1) / 2
    # The whole stone's ramp, its outer ring (the outline) left out: a flat face alone has no contrast to carve with.
    body = [im.getpixel((x, y)) for y in range(h) for x in range(w)
            if (x - cx) ** 2 + (y - cy) ** 2 <= 13 ** 2 and im.getpixel((x, y))[3]]
    body.sort(key=lightness)
    deep, dark = body[len(body) * DEEP // 100], body[len(body) * DARK // 100]
    light = body[-len(body) * LIGHT // 100]
    cells, gw, gh = glyph(letters)
    ox, oy = round(cx - (gw - 1) / 2), round(cy - (gh - 1) / 2)
    for x, y in cells:
        for lx, ly in ((x + 1, y), (x, y + 1)):
            # The lit lip breaks off here and there, as a worn edge does.
            if (lx, ly) not in cells and (lx * 5 + ly * 3) % 7:
                im.putpixel((ox + lx, oy + ly), light)
    for x, y in cells:
        # The wall a cut turns to the light-less top left is the deepest; the rest of the groove a step lighter.
        shadowed = (x - 1, y) not in cells or (x, y - 1) not in cells
        im.putpixel((ox + x, oy + y), deep if shadowed else dark)
    return im


def small(stone):
    """`stone` at `SMALL` px: a box filter's average of each square, put back onto the stone's own colours, and its
    outer ring the stone's darkest, so the outline stays one unbroken pixel as the big one's is."""
    palette = sorted({c for c in stone.get_flattened_data() if c[3] == 255}, key=lightness)
    boxed = stone.resize((SMALL, SMALL), Image.BOX)
    out = Image.new("RGBA", (SMALL, SMALL))
    c = SMALL / 2
    for y in range(SMALL):
        for x in range(SMALL):
            d = ((x + 0.5 - c) ** 2 + (y + 0.5 - c) ** 2) ** 0.5
            if d > c:
                continue
            px = boxed.getpixel((x, y))
            out.putpixel((x, y), palette[0] if d > c - 1 else
                         min(palette, key=lambda p: sum((a - b) ** 2 for a, b in zip(p[:3], px[:3]))))
    return out


def nodes_preview(stones, base):
    """The root and the small nodes, each beside its stone, at 6x on cream."""
    scale, pad = 6, 8
    row = [base] + [stones[a] for a in ATTRS]
    sheet = Image.new("RGBA", (pad + len(row) * (32 + SMALL + 2 * pad), 32 + 2 * pad), (246, 202, 159, 255))
    x = pad
    for big in row:
        sheet.alpha_composite(big, (x, pad))
        sheet.alpha_composite(small(big), (x + 32 + pad // 2, pad + (32 - SMALL) // 2))
        x += 32 + SMALL + 2 * pad
    return sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST)


def main():
    stones = {a: Image.open(os.path.join(SRC, a + ".png")).convert("RGBA") for a in ATTRS}
    base = Image.open(os.path.join(SRC, BASE + ".png")).convert("RGBA")
    scale, pad = 6, 8
    cell = 32 * scale + pad
    sheet = Image.new("RGBA", (pad + LEVELS * cell, pad + len(ATTRS) * cell), (246, 202, 159, 255))
    for r, a in enumerate(ATTRS):
        for n in range(LEVELS):
            big = carve(stones[a], ROMAN[n]).resize((32 * scale,) * 2, Image.NEAREST)
            sheet.alpha_composite(big, (pad + n * cell, pad + r * cell))
    os.makedirs(QA, exist_ok=True)
    sheet.save(os.path.join(QA, "skill_stones.png"))
    nodes_preview(stones, base).save(os.path.join(QA, "skill_nodes.png"))
    if "--export" in sys.argv:
        os.makedirs(OUT, exist_ok=True)
        for a in ATTRS:
            for n in range(LEVELS):
                carve(stones[a], ROMAN[n]).save(os.path.join(OUT, f"{a}_{n + 1}.png"))
            small(stones[a]).save(os.path.join(OUT, f"{a}_small.png"))
        small(base).save(os.path.join(OUT, f"{BASE}_small.png"))
        base.save(os.path.join(os.path.dirname(OUT), "root.png"))


# The groove's shadowed wall, the rest of it, and the lip: percentiles of the stone's lightness, from each end.
DEEP, DARK, LIGHT = 3, 14, 4

if __name__ == "__main__":
    main()
