"""Shared geometry, palette, noise and tile helpers for the 56x64 hex tileset.

Hex geometry (pointy-top, 56 wide x 64 tall; 56/64 = 0.875, a regular hex is 0.866):
  rows 0-15  : slanted NW/NE edges, half-width round(1.75*y + 0.875) (7 px across per 4 rows)
  rows 16-47 : full width, flat W/E sides touch the frame
  rows 48-63 : slanted SW/SE edges (mirror of the top)
Tiles tessellate exactly with lattice vectors (56, 0) and (28, 48):
column step 56 px, row step 48 px, odd rows shifted +28 px.
"""
import math
import random
from functools import lru_cache

W, H = 56, 64
SLANT = 16
HALF = 28
STEP_X, STEP_Y, ROW_OFFSET = 56, 48, 28
LATTICE_SHIFTS = [(STEP_X * i + ROW_OFFSET * j, STEP_Y * j) for i in (-1, 0, 1) for j in (-1, 0, 1)]

_HW = [round(1.75 * y + 0.875) if y < SLANT else HALF for y in range(H // 2)]
_HW += _HW[::-1]


def half_width(y):
    return _HW[y]


def in_hex(x, y):
    if not (0 <= y < H and 0 <= x < W):
        return False
    return HALF - _HW[y] <= x <= HALF - 1 + _HW[y]


HEX_PIXELS = [(x, y) for y in range(H) for x in range(W) if in_hex(x, y)]


def wrap(x, y):
    """Map any world pixel to the local pixel of the same-type tile covering it."""
    j0 = y // STEP_Y
    for j in (j0, j0 - 1):
        ly = y - STEP_Y * j
        if 0 <= ly < H:
            lx = (x - ROW_OFFSET * j) % STEP_X
            if in_hex(lx, ly):
                return lx, ly
    raise AssertionError((x, y))


# Distance from a pixel centre to the continuous hex outline (convex: min over the 6 edge lines).
_N = math.hypot(16, 28)
_EDGE_LINES = [(1, 0, 0), (-1, 0, W),
               (16 / _N, 28 / _N, -448 / _N), (-16 / _N, 28 / _N, 448 / _N),
               (16 / _N, -28 / _N, 1344 / _N), (-16 / _N, -28 / _N, 2240 / _N)]
BORDER = [[0.0] * W for _ in range(H)]
for _x, _y in HEX_PIXELS:
    BORDER[_y][_x] = min(a * (_x + 0.5) + b * (_y + 0.5) + c for a, b, c in _EDGE_LINES)

CENTER = (28.0, 32.0)
EDGE_NAMES = ["E", "SE", "SW", "W", "NW", "NE"]
EDGE_MID = {"E": (56.0, 32.0), "SE": (42.0, 56.0), "SW": (14.0, 56.0),
            "W": (0.0, 32.0), "NW": (14.0, 8.0), "NE": (42.0, 8.0)}

# --------------------------------------------------------------------------- palette (locked)
PALETTE = [
    ("clear", "#00000000"),
    ("ink", "#14101e"),
    ("pine_dk", "#1b3328"), ("pine", "#2a5236"), ("leaf_dk", "#3d7a3c"),
    ("leaf", "#58a046"), ("leaf_lt", "#86c25a"), ("leaf_hi", "#c3de7c"),
    ("earth_dk", "#3a2521"), ("earth", "#5c3b2b"), ("soil", "#80553a"),
    ("soil_lt", "#a6754b"),
    ("sand_dk", "#c39a61"), ("sand", "#dcbd7f"), ("sand_lt", "#efdcaa"),
    ("slate_dk", "#34374a"), ("slate", "#565a6e"), ("stone", "#7d8196"),
    ("stone_lt", "#a6aabb"), ("mist", "#cfd3de"),
    ("ice_dk", "#3f6fa6"), ("ice", "#72a8d6"), ("ice_lt", "#acd6ee"),
    ("snow", "#e8f5fb"), ("abyss", "#26325e"),
    ("brick", "#c0443a"), ("brick_dk", "#7a2a36"), ("amber", "#e9b640"),
    ("rust", "#d57a39"), ("lilac", "#a77fcf"), ("olive", "#8a8f3e"),
    ("bone", "#f4eedc"),
    # Terrain ramps, appended so the 32 above keep their indices. Each runs dark to light and
    # shifts hue as it goes: shadows cool and deepen, lights warm, which is what makes ground read
    # as lit rather than as a flat texture.
    ("gr0", "#1d3a36"), ("gr1", "#2b573d"), ("gr2", "#3f7643"), ("gr3", "#5a9147"),
    ("gr4", "#7eab4f"), ("gr5", "#b3c865"),                                          # meadow
    ("fo0", "#0d1a20"), ("fo1", "#15302b"),                                          # forest shade
    ("co1", "#1a3a3a"), ("co2", "#265348"), ("co3", "#386f55"), ("co4", "#5b9066"),   # conifer
    ("di0", "#34211e"), ("di1", "#553628"), ("di2", "#754e33"), ("di3", "#94693f"),
    ("di4", "#b3874f"), ("di5", "#cfa86d"),                                          # dry earth
    ("st1", "#8e7a3c"), ("st2", "#c0a45c"),                                          # straw
    ("de0", "#8c5438"), ("de1", "#b37649"), ("de2", "#d19a5a"), ("de3", "#e5b970"),
    ("de4", "#f2d492"), ("de5", "#fbeac0"),                                          # sand
    ("sn0", "#3b4c7c"), ("sn1", "#5a73a8"), ("sn2", "#84a0cb"), ("sn3", "#b0c7e2"),
    ("sn4", "#d8e5f2"), ("sn5", "#f6faff"),                                          # snow
    ("ro0", "#23263a"), ("ro1", "#363b50"), ("ro2", "#4f5568"), ("ro3", "#6c7283"),
    ("ro4", "#8e939d"), ("ro5", "#b9bbbd"),                                          # rock
    ("sc1", "#4a4442"), ("sc2", "#645c55"), ("sc3", "#80776a"),                      # scree
    ("wa0", "#1c3158"), ("wa1", "#2a5586"), ("wa2", "#3f7fb2"), ("wa3", "#8fcbe6"),   # water
    ("rf0", "#5a2a33"), ("rf1", "#86393a"), ("rf2", "#a8513f"), ("rf3", "#c47352"),   # terracotta
    ("pl0", "#8a7662"), ("pl1", "#b29e81"), ("pl2", "#d2c19c"), ("pl3", "#e8dbb8"),   # plaster
]
assert len(PALETTE) <= 256
C = {name: i for i, (name, _) in enumerate(PALETTE)}
# Not a colour: a shadow cast onto whatever ground an overlay is laid over, written as translucent ink. Only
# the ice's own sheets use it (the wall's rubble), which skip the atlas and its indexed palette.
SHADE = -1
SHADE_RGBA = (20, 16, 30, 70)

# ENDESGA 64 (Endesga; lospec.com/palette-list/endesga-64): the palette every fighter pack is drawn in, and
# since 2026-09-30 the whole interface (the user's call): `to_e64` puts an image into it.
E64 = ("ff0040 131313 1b1b1b 272727 3d3d3d 5d5d5d 858585 b4b4b4 ffffff c7cfdd 92a1b9 657392 424c6e "
       "2a2f4e 1a1932 0e071b 1c121c 391f21 5d2c28 8a4836 bf6f4a e69c69 f6ca9f f9e6cf edab50 e07438 "
       "c64524 8e251d ff5000 ed7614 ffa214 ffc825 ffeb57 d3fc7e 99e65f 5ac54f 33984b 1e6f50 134c4c "
       "0c2e44 00396d 0069aa 0098dc 00cdf9 0cf1ff 94fdff fdd2ed f389f5 db3ffd 7a09fa 3003d9 0c0293 "
       "03193f 3b1443 622461 93388f ca52c9 c85086 f68187 f5555d ea323c c42430 891e2b 571c27").split()


def _oklab(rgb):
    """One (r, g, b) in 0-255 as OKLab, the space colours are matched in: its steps are even to the eye."""
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in (v / 255 for v in rgb)]
    lms = [
        (0.4122214708 * lin[0] + 0.5363325363 * lin[1] + 0.0514459929 * lin[2]) ** (1 / 3),
        (0.2119034982 * lin[0] + 0.6806995451 * lin[1] + 0.1073969644 * lin[2]) ** (1 / 3),
        (0.0883024619 * lin[0] + 0.2817188376 * lin[1] + 0.6299787005 * lin[2]) ** (1 / 3),
    ]
    return (0.2104542553 * lms[0] + 0.7936177850 * lms[1] - 0.0040720468 * lms[2],
            1.9779984951 * lms[0] - 2.4285922050 * lms[1] + 0.4505937099 * lms[2],
            0.0259040371 * lms[0] + 0.7827717662 * lms[1] - 0.8086757660 * lms[2])


_E64_RGB = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in E64]
_E64_LAB = [_oklab(c) for c in _E64_RGB]


def _rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4))


def to_e64(image, fixed=None, apart=0.06, reach=0.25):
    """`image` (a PIL image) with every colour in ENDESGA 64 and its alpha untouched, so no shape moves.

    `fixed` maps "#rrggbb" -> the "#rrggbb" it must become: the colours picked by hand (the interface's
    cream, wood and button faces), which nothing moves. Every other colour takes its nearest in OKLab.
    Two colours of one image further apart in lightness than `apart` that would land on one are kept
    apart where they can be: the one farther from it takes its nearest on its own side, if that is
    within `reach` of it -- so a bevel or a ramp's step does not melt into its neighbour, and no brown
    is pushed into a green to stay apart (a wood panel went teal that way before `reach`)."""
    fixed = {_rgb(k): _rgb(v) for k, v in (fixed or {}).items()}
    out = image.convert("RGBA")
    colours = sorted({c[:3] for _, c in out.getcolors(1 << 24) if c[3]})
    lab = {c: _oklab(c) for c in colours}

    def gap(c, i):
        return sum((p - q) ** 2 for p, q in zip(lab[c], _E64_LAB[i])) ** 0.5

    def ranked(c):
        return sorted(range(len(E64)), key=lambda i: gap(c, i))

    def shift(c, i):
        return ((lab[c][0] - _E64_LAB[i][0]) ** 2 + 9 * ((lab[c][1] - _E64_LAB[i][1]) ** 2
                                                          + (lab[c][2] - _E64_LAB[i][2]) ** 2)) ** 0.5

    pick = {c: _E64_RGB.index(fixed[c]) if c in fixed else ranked(c)[0] for c in colours}
    settled = set(fixed)
    for _ in range(8):
        moved = False
        by_target = {}
        for c in colours:
            by_target.setdefault(pick[c], []).append(c)
        for target, group in by_target.items():
            if len(group) < 2:
                continue
            # The one nearest the target keeps it (a hand-picked one always does); the rest go their way.
            keep = min(group, key=lambda c: (c not in fixed, abs(lab[c][0] - _E64_LAB[target][0])))
            for c in group:
                if c == keep or c in settled or abs(lab[c][0] - lab[keep][0]) <= apart:
                    continue
                darker = lab[c][0] < lab[keep][0]
                # Moved by lightness, never by hue: chroma counts three times over, so a brown steps
                # to a lighter or darker brown and not to a green of about its own lightness.
                side = sorted((i for i in range(len(E64)) if i != target and shift(c, i) <= reach
                               and (_E64_LAB[i][0] < _E64_LAB[target][0]) == darker), key=lambda i: shift(c, i))
                settled.add(c)
                if side:
                    pick[c] = side[0]
                    moved = True
        if not moved:
            break
    table = {c: _E64_RGB[pick[c]] for c in colours}
    out.putdata([p if not p[3] else table[p[:3]] + (p[3],) for p in out.get_flattened_data()])
    return out

_DARKER = {
    "leaf_hi": "leaf_lt", "leaf_lt": "leaf", "leaf": "leaf_dk", "leaf_dk": "pine",
    "pine": "pine_dk", "pine_dk": "ink",
    "soil_lt": "soil", "soil": "earth", "earth": "earth_dk", "earth_dk": "ink",
    "sand_lt": "sand", "sand": "sand_dk", "sand_dk": "soil_lt",
    "mist": "stone_lt", "stone_lt": "stone", "stone": "slate", "slate": "slate_dk", "slate_dk": "ink",
    "snow": "ice_lt", "ice_lt": "ice", "ice": "ice_dk", "ice_dk": "abyss", "abyss": "ink",
    "bone": "mist", "amber": "rust", "rust": "brick", "brick": "brick_dk",
    "brick_dk": "earth_dk", "lilac": "slate", "olive": "earth", "ink": "ink",
    "st1": "di2", "st2": "st1", "sc1": "ro0", "sc2": "sc1", "sc3": "sc2",
    "gr0": "fo0", "fo0": "ink", "fo1": "fo0", "co1": "fo0", "wa0": "ink",
}
for _ramp in ("gr", "co", "di", "de", "sn", "ro", "wa", "rf", "pl"):
    _steps = [n for n, _ in PALETTE if n[:2] == _ramp and n[2:].isdigit()]
    for _lo, _hi in zip(_steps, _steps[1:]):
        _DARKER[_hi] = _lo
_DARKER.setdefault("di0", "ink")
_DARKER.setdefault("de0", "di1")
_DARKER.setdefault("sn0", "ro0")
_DARKER.setdefault("ro0", "ink")
_DARKER.setdefault("rf0", "di0")
_DARKER.setdefault("pl0", "di1")
DARKER = [0] * len(PALETTE)
for _n, _d in _DARKER.items():
    DARKER[C[_n]] = C[_d]

# --------------------------------------------------------------------------- dither
BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def bayer(x, y):
    """Ordered-dither threshold in (0,1). Lattice steps are multiples of 4, so it is seamless."""
    return (BAYER4[y % 4][x % 4] + 0.5) / 16.0


def ramp_pick(v, ramp, x, y, band=0.3):
    """Quantize v in [0,1] onto palette indices, dithering only near the steps."""
    v = min(max(v, 0.0), 0.99999)
    pos = v * len(ramp)
    lo = int(pos)
    frac = pos - lo
    if frac < band and lo > 0 and (band - frac) / band * 0.5 > bayer(x, y):
        return ramp[lo - 1]
    if frac > 1 - band and lo < len(ramp) - 1 and (frac - (1 - band)) / band * 0.5 > bayer(x, y):
        return ramp[lo + 1]
    return ramp[lo]


# --------------------------------------------------------------------------- noise (lattice periodic)
_INDEX = {p: i for i, p in enumerate(HEX_PIXELS)}
_NBH = [[_INDEX[wrap(x + d, y)] for d in (-1, 0, 1)] for x, y in HEX_PIXELS]
_NBV = [[_INDEX[wrap(x, y + d)] for d in (-1, 0, 1)] for x, y in HEX_PIXELS]


def _equalize(values):
    order = sorted(range(len(values)), key=values.__getitem__)
    out, n = [0.0] * len(values), len(values) - 1
    for rank, i in enumerate(order):
        out[i] = rank / n
    return out


@lru_cache(maxsize=None)
def _noise(seed, passes):
    rng = random.Random(seed)
    f = [rng.random() for _ in HEX_PIXELS]
    for _ in range(passes):
        f = [(f[a] + f[b] + f[c]) / 3.0 for a, b, c in _NBH]
        f = [(f[a] + f[b] + f[c]) / 3.0 for a, b, c in _NBV]
    return tuple(_equalize(f))


def periodic_noise(seed, passes):
    """Smooth, rank-equalized [0,1] noise that tiles seamlessly with itself on the hex lattice."""
    return dict(zip(HEX_PIXELS, _noise(seed, passes)))


@lru_cache(maxsize=None)
def _fbm(seed, weights):
    layers = [(_noise(seed * 31 + k, passes), w) for k, (passes, w) in enumerate(weights)]
    raw = [sum(layer[i] * w for layer, w in layers) for i in range(len(HEX_PIXELS))]
    return tuple(_equalize(raw))


def fbm(seed, weights=((24, 0.55), (7, 0.3), (1, 0.15))):
    return dict(zip(HEX_PIXELS, _fbm(seed, weights)))


def interior_weight(x, y, inner=4.0, outer=10.0):
    """0 inside the shared edge band, 1 deep in the interior."""
    t = min(max((BORDER[y][x] - inner) / (outer - inner), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def blend_fields(base, variant):
    """Edge band from `base` (shared by all variants of an environment), interior from `variant`."""
    return {(x, y): base[(x, y)] * (1 - interior_weight(x, y)) + variant[(x, y)] * interior_weight(x, y)
            for x, y in HEX_PIXELS}


def light(dx, dy):
    """Lambert-ish term for a height gradient, light from the top-left."""
    return (dx + dy) * 0.7071


# --------------------------------------------------------------------------- tile
class Tile:
    def __init__(self, name, group):
        self.name = name
        self.group = group
        self.px = [[0] * W for _ in range(H)]

    def put(self, x, y, c, wrapped=True):
        if wrapped:
            x, y = wrap(x, y)
        elif not in_hex(x, y):
            return
        self.px[y][x] = c

    def get(self, x, y, wrapped=True):
        if wrapped:
            x, y = wrap(x, y)
        elif not in_hex(x, y):
            return 0
        return self.px[y][x]

    def darken(self, x, y, wrapped=True, steps=1):
        if wrapped:
            x, y = wrap(x, y)
        elif not in_hex(x, y):
            return
        c = self.px[y][x]
        for _ in range(steps):
            c = DARKER[c]
        self.px[y][x] = c

    def copy(self, name, group):
        t = Tile(name, group)
        t.px = [row[:] for row in self.px]
        return t

    def flat(self):
        return [c for row in self.px for c in row]
