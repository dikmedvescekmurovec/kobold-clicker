"""The Gollux cave's mouth on the map, one picture for each of the six grounds.

The dungeon behind it is the same wherever it stands; only its door wears the ground it stands on. It
is a sprite of the settlements' size and anchor (towns.py), drawn by Godot over the fog on their layer,
and like them it is a few big two-tone shapes in the terrain's own ramps. Unlike a settlement it has **no
ground tile of its own**: it stands on whatever variant of its land the cell already has.

The first drawing -- a knoll with a door in its face -- read as a hut at map scale (the user: "they look
like huts, not like an entrance to a cave"): a roof-shaped silhouette with a small door *is* a building,
whatever it is made of. A crag split by a black mouth was drawn beside the pit for the user to choose
from, and they chose the pit, bigger: **a hole in the ground** nearly as wide as the tile, a ragged rim
of rock, the lit back wall falling into the dark, and steps going down from the near side. Nothing
stands up, so nothing can be read as a roof. The dark red light out of it is not in the picture: it is
`Scenes/Map/cave_glow.gdshader`, laid over the hole at `HOLE` (which `HexMap.CAVE_GLOW_AT` must match).
"""
import math

import towns as T
from hexlib import C, DARKER, bayer
from terrain import CONIFER, ENV_ORDER, pine

W, H = T.SPRITE_W, T.SPRITE_H
CX, CY = T.ANCHOR            # the cell's centre in the sprite
# The hole: its centre in the sprite, and its half-width and half-depth. The rim round it takes the
# tile to within a few pixels of its sides.
HOLE = (CX, CY + 2)
RX, RY = 22.0, 13.0


def L(*names):
    return tuple(C[n] for n in names)


# rim lit, rim mid, rim dark, wall lit, wall shade, dark 1, dark 2 (the deepest)
LOOKS = {
    "grass": L("ro4", "ro3", "ro2", "ro3", "ro2", "ro1", "ink"),
    "dirt": L("di4", "di3", "di2", "di2", "di1", "di0", "ink"),
    "desert": L("de4", "de3", "de2", "de2", "de1", "di1", "ink"),
    "ice": L("sn5", "sn4", "sn3", "ice", "ice_dk", "abyss", "ink"),
    "forest": L("ro3", "ro2", "ro1", "ro2", "ro1", "fo1", "fo0"),
    "mountains": L("ro4", "ro3", "ro2", "ro3", "ro2", "ro1", "ink"),
}


def _h(x, y, seed):
    """A repeatable hash in [0, 1)."""
    n = (x * 374761393 + y * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    return (n ^ (n >> 16)) / 4294967296.0


def _put(cv, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        cv.px[y][x] = c


def _blob(cv, cx, cy, r, lit, mid, dark, squash=1.0):
    """A boulder: a round shape lit from the upper left, its lower right in the dark step."""
    for y in range(int(cy - r) - 1, int(cy + r) + 2):
        for x in range(int(cx - r) - 1, int(cx + r) + 2):
            dx, dy = x + 0.5 - cx, (y + 0.5 - cy) / squash
            d = math.hypot(dx, dy)
            if d > r:
                continue
            side = (dx + dy) / max(r, 1)
            _put(cv, x, y, dark if side > 0.55 or d > r - 0.8 and side > 0 else mid if side > -0.2 else lit)


# --------------------------------------------------------------------------- the pit
def pit(cv, env, look):
    rl, rm, rd, wl, ws, d1, d2 = look
    (cx, cy), rx, ry = HOLE, RX, RY

    def rim_r(a):                       # a ragged rim: the ellipse's radius wobbles with the angle
        return 1.0 + 0.08 * math.sin(a * 5 + 1) + 0.05 * math.sin(a * 11 + 2)

    def inside(x, y, grow=0.0):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        return math.hypot(dx, dy) < rim_r(math.atan2(dy, dx)) + grow

    # The ring of rock round the hole, then the hole itself.
    for y in range(H):
        for x in range(W):
            if inside(x, y, 0.22) and not inside(x, y):
                dx, dy = x + 0.5 - cx, y + 0.5 - cy
                lit = (dx / rx + dy / ry) < -0.2
                c = rl if lit else rm if dy < ry * 0.3 else rd
                if _h(x, y, 3) < 0.12:
                    c = DARKER[c]
                _put(cv, x, y, c)
    for y in range(H):
        for x in range(W):
            if not inside(x, y):
                continue
            # The far wall: its top is the rim's back edge, and it falls into the dark below it.
            top = y
            while top > 0 and inside(x, top - 1):
                top -= 1
            depth = y - top
            if depth < 8:
                c = wl if x < cx - rx * 0.2 else ws
                if depth % 3 == 2:
                    c = ws                                  # the strata
            elif depth < 11:
                c = ws if bayer(x, y) < 0.5 else d1
            elif depth < 15:
                c = d1 if bayer(x, y) < 0.5 else d2
            else:
                c = d2
            _put(cv, x, y, c)
    # Steps down from the near left, each a slab and its riser, darker as they go.
    lit, riser = rl, rd
    for k in range(6):
        sx, sy = int(cx - 17 + k * 3), int(cy + 10 - k * 2)
        for dx in range(8):
            _put(cv, sx + dx, sy, lit)
            _put(cv, sx + dx, sy + 1, riser)
        lit, riser = DARKER[lit], DARKER[riser]
    return cx, cy, rx, ry


# --------------------------------------------------------------------------- dressing
def dress(cv, env, look, at):
    rl, rm, rd = look[:3]
    cx, cy, rx, ry = at
    # Boulders on the rim, a couple of them bigger.
    for a, r in ((3.6, 4.0), (5.4, 3.0), (0.3, 3.4), (2.4, 2.2)):
        _blob(cv, cx + math.cos(a) * rx * 1.12, cy + math.sin(a) * ry * 1.2, r, rl, rm, rd)
    if env == "dirt" or env == "mountains":           # a mine's frame over the stairs
        for px in (int(cx - 17), int(cx - 7)):
            for k in range(11):
                _put(cv, px, int(cy + 7 - k), C["di3"] if px < cx - 12 else C["di2"])
        for x in range(int(cx - 18), int(cx - 5)):
            _put(cv, x, int(cy - 4), C["di4"])
    if env == "desert":                               # two broken pillars flanking the stairs
        for px, h in ((int(cx - 20), 12), (int(cx - 6), 8)):
            for k in range(h):
                for dx in range(3):
                    _put(cv, px + dx, int(cy + 8 - k), C["de4"] if dx == 0 else C["de2"])
    if env == "ice":                                  # icicles off the far rim
        for x in range(int(cx - 16), int(cx + 16), 3):
            top = int(cy - ry) + 1
            for k in range(2 + x % 3):
                _put(cv, x, top + k, C["ice_lt"])
    if env == "forest":                               # pines behind it
        pine(cv, int(cx + 15), int(cy - 11), 17, CONIFER, wrapped=False, shadow=False)
        pine(cv, int(cx - 12), int(cy - 13), 14, CONIFER, wrapped=False, shadow=False)
    if env == "grass":                                # tufts on the rim
        for x in range(int(cx - 20), int(cx + 21), 5):
            y = int(cy - ry * 1.05 + (x % 3))
            _put(cv, x, y, C["gr4"])
            _put(cv, x + 1, y - 1, C["gr3"])


def build(env):
    """The cave's sprite, a `towns.Canvas`."""
    cv, look = T.Canvas(), LOOKS[env]
    dress(cv, env, look, pit(cv, env, look))
    return cv


def sprites():
    """Every cave sprite as an RGBA image, by name: `cave_<env>`."""
    from PIL import Image
    from preview import RGBA
    out = {}
    for env in ENV_ORDER:
        cv = build(env)
        img = Image.new("RGBA", (W, H))
        img.putdata([RGBA[c] if c else (0, 0, 0, 0) for row in cv.px for c in row])
        out[f"cave_{env}"] = img
    return out
