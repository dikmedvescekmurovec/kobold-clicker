"""The footprints that lead in to each boss's lair on the map (`MapBuilder.trail_of`), drawn, not cut.

One sheet a boss, `CELL` px a print: twelve across, the six hex directions (`k * 60` degrees on screen, 0 east
and 60 south-east, y down) each as a left foot then a right. Every print is its boss's own shape, set down in
the local frame of its walk (`u` forward, `v` to the right, in map pixels from the print's middle), filled
at `SUPER` samples a side and kept where over half of a pixel is inside: hard edges, as map art has.

The map's own rule (no ink outlines, few shapes) holds: a print is one dark imprint, the golem's dusted with
frost. The user asked for them without a look to confirm (2026-10-29).

No arguments writes the preview `tools/qa/boss_tracks.png` (each boss's twelve, and a trail of each on its
ground). `--export` writes `Assets/Map/Tracks/<boss>.png`, the boss lower-cased with `_` for a space, which
is how `MapBuilder.tracks_path` finds it. Run the Godot import after it.
"""
import argparse
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "Assets/Map/Tracks"
CELL = 16
SUPER = 8
# The shapes below are written small and drawn this much larger: at the map's zoom the first size read as
# rocks in the ground's own texture.
GROW = 1.45
# The ground's far lip catching the light, a pixel under each print: what makes a print read as pressed in.
LIP = ("ffffff", 110)


def _rgba(s, a=255):
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4)) + (a,)


# Shapes, each a test of (u, v) -> inside.
def ellipse(cu, cv, ru, rv):
    return lambda u, v: ((u - cu) / ru) ** 2 + ((v - cv) / rv) ** 2 <= 1.0


def capsule(u1, v1, u2, v2, r):
    def inside(u, v):
        du, dv = u2 - u1, v2 - v1
        t = max(0.0, min(1.0, ((u - u1) * du + (v - v1) * dv) / (du * du + dv * dv)))
        return (u - u1 - t * du) ** 2 + (v - v1 - t * dv) ** 2 <= r * r
    return inside


def box(u1, v1, u2, v2):
    return lambda u, v: u1 <= u <= u2 and v1 <= v <= v2


# Each boss: the shapes of its right foot (`v` > 0 is outward), its imprint's colour and alpha, and
# whether it is frosted.
BOSSES = {
    # A sabaton: a long sole, a separate heel, a pointed toe.
    "Huge Knight": {
        "shapes": [box(-1.0, -1.6, 3.5, 1.6), capsule(3.5, 0.0, 5.0, 0.0, 1.2), box(-4.5, -1.5, -2.5, 1.5)],
        "colour": "272727", "alpha": 215,
    },
    # A hound's paw: a pad behind, four toes in an arc before it.
    "Cerberus": {
        "shapes": [ellipse(-1.6, 0.0, 1.7, 2.2), ellipse(2.0, -2.8, 0.9, 0.9), ellipse(2.9, -1.0, 0.9, 0.9),
                   ellipse(2.9, 1.0, 0.9, 0.9), ellipse(2.0, 2.8, 0.9, 0.9)],
        "colour": "1a1932", "alpha": 215,
    },
    # A cloven hoof: two halves with a split between them.
    "Minotaur": {
        "shapes": [ellipse(0.4, -1.9, 3.4, 1.1), ellipse(0.4, 1.9, 3.4, 1.1)],
        "colour": "391f21", "alpha": 215,
    },
    # A giant's bare foot: a long sole and five toes, the big one inside.
    "Cyclops": {
        "shapes": [ellipse(-0.6, 0.2, 4.0, 2.2), ellipse(4.2, -1.8, 1.1, 1.1), ellipse(4.6, -0.2, 0.9, 0.9),
                   ellipse(4.4, 1.2, 0.8, 0.8), ellipse(3.9, 2.4, 0.7, 0.7), ellipse(3.2, 3.2, 0.6, 0.6)],
        "colour": "391f21", "alpha": 215,
    },
    # Three talons splayed forward and a spur behind.
    "Dragon": {
        "shapes": [ellipse(0.0, 0.0, 1.6, 1.6), capsule(0.5, 0.0, 5.5, 0.0, 0.7), capsule(0.5, -0.5, 4.2, -3.4, 0.7),
                   capsule(0.5, 0.5, 4.2, 3.4, 0.7), capsule(-0.5, 0.0, -3.8, 0.0, 0.6)],
        "colour": "5d2c28", "alpha": 220,
    },
    # A square stone foot and three blunt toes, rimed with frost.
    "Frozen Golem": {
        "shapes": [box(-3.5, -2.5, 2.0, 2.5), box(2.0, -2.5, 4.0, -1.2), box(2.0, -0.6, 4.2, 0.6),
                   box(2.0, 1.2, 4.0, 2.5)],
        "colour": "2a2f4e", "alpha": 220, "frost": "c7cfdd",
    },
}


def path_of(boss):
    return OUT / (boss.lower().replace(" ", "_") + ".png")


def print_cell(spec, k, left):
    angle = math.radians(k * 60)
    fu, fv = math.cos(angle), math.sin(angle)  # forward, on screen with y down
    ru, rv = -fv, fu                           # its right
    cell = Image.new("RGBA", (CELL, CELL))
    px = cell.load()
    middle = CELL / 2
    for y in range(CELL):
        for x in range(CELL):
            hits = 0
            for sy in range(SUPER):
                for sx in range(SUPER):
                    dx = x + (sx + 0.5) / SUPER - middle
                    dy = y + (sy + 0.5) / SUPER - middle
                    u = (dx * fu + dy * fv) / GROW
                    v = (dx * ru + dy * rv) / GROW
                    if left:
                        v = -v
                    hits += any(shape(u, v) for shape in spec["shapes"])
            if hits * 2 > SUPER * SUPER:
                px[x, y] = _rgba(spec["colour"], spec["alpha"])
    for y in range(CELL - 1, 0, -1):
        for x in range(CELL):
            if px[x, y][3] == 0 and px[x, y - 1][3] and px[x, y - 1][:3] != _rgba(*LIP)[:3]:
                px[x, y] = _rgba(*LIP)
    if "frost" in spec:
        # A pixel of frost on about a quarter of the print, picked off its place so it never flickers.
        for y in range(CELL):
            for x in range(CELL):
                if px[x, y][3] and (x * 7 + y * 13 + k * 3) % 11 < 3:
                    px[x, y] = _rgba(spec["frost"], 200)
    return cell


def sheet(spec):
    out = Image.new("RGBA", (CELL * 12, CELL))
    for k in range(6):
        for foot in range(2):
            out.paste(print_cell(spec, k, foot == 0), ((k * 2 + foot) * CELL, 0))
    return out


GROUNDS = {"Huge Knight": "5ac54f", "Cerberus": "1e6f50", "Minotaur": "bf6f4a", "Cyclops": "edab50",
           "Dragon": "858585", "Frozen Golem": "f6f6f6"}


def preview(sheets):
    rows = []
    for boss, img in sheets.items():
        row = Image.new("RGBA", (CELL * 12, CELL * 3), _rgba(GROUNDS[boss]))
        row.alpha_composite(img, (0, 0))
        # A trail walking east, then south-east: three prints a step, feet in turn, as the map lays them.
        for i in range(6):
            k = 0 if i < 3 else 1
            foot = i % 2
            cut = img.crop(((k * 2 + foot) * CELL, 0, (k * 2 + foot + 1) * CELL, CELL))
            row.alpha_composite(cut, (8 + i * 26, CELL + (4 if foot else -2) + (i - 2) * 6 * (i >= 3)))
        rows.append(row)
    out = Image.new("RGBA", (CELL * 12, CELL * 3 * len(rows)))
    for i, row in enumerate(rows):
        out.alpha_composite(row, (0, i * CELL * 3))
    return out.resize((out.width * 4, out.height * 4), Image.NEAREST)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--export", action="store_true", help="write the sheets into Assets/")
    args = parser.parse_args()
    sheets = {boss: sheet(spec) for boss, spec in BOSSES.items()}
    if args.export:
        OUT.mkdir(parents=True, exist_ok=True)
        for boss, img in sheets.items():
            img.save(path_of(boss))
            print("wrote", path_of(boss))
        return
    path = ROOT / "tools/qa/boss_tracks.png"
    preview(sheets).save(path)
    print("wrote", path)


if __name__ == "__main__":
    main()
