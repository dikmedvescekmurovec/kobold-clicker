"""Phase 2: transparent road overlays (56x64), every orientation pre-rendered.

Centrelines run along centre-to-edge-midpoint lines, which continue straight into the
neighbour, so roads sharing an edge meet pixel-exactly. Width, ruts and texture are functions
of distance-to-centreline plus lattice-periodic data, so they also continue across seams.
"""
import math

from hexlib import C, CENTER, EDGE_MID, EDGE_NAMES, HEX_PIXELS, Tile, bayer, periodic_noise, wrap
from stamps import seg_dist

MATERIALS = ["dirt", "stone", "snow"]
PATTERNS = [   # canonical edge sets (0=E 1=SE 2=SW 3=W 4=NW 5=NE)
    ("stub", (0,)),
    ("straight", (0, 3)),
    ("curve_wide", (0, 2)),
    ("y3", (0, 2, 4)),
    ("x4", (1, 2, 4, 5)),
    ("x6", (0, 1, 2, 3, 4, 5)),
]
HALF_WIDTH = 4.0
FRINGE = 2.0
RUT = 2.0


def rotations(edges):
    """Distinct clockwise 60-degree rotations of an edge set, canonical first."""
    seen, out = set(), []
    for k in range(6):
        rot = tuple(sorted((e + k) % 6 for e in edges))
        if rot not in seen:
            seen.add(rot)
            out.append((k, rot))
    return out


def _lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def _stem(e, inward=0.3):
    m = EDGE_MID[EDGE_NAMES[e]]
    far = _lerp(m, CENTER, -16.0 / math.hypot(m[0] - CENTER[0], m[1] - CENTER[1]))
    return far, _lerp(m, CENTER, inward)


def road_shape(edges):
    """f(px, py) -> (distance to centreline, presence 0..1)."""
    if len(edges) == 1:
        m = EDGE_MID[EDGE_NAMES[edges[0]]]
        far, _ = _stem(edges[0])

        def stub(px, py):
            d_out, _ = seg_dist((px, py), far, m)
            d_in, t = seg_dist((px, py), CENTER, m)
            fade = min(max((t - 0.02) / 0.4, 0.0), 1.0)
            return (d_out, 1.0) if d_out < d_in else (d_in, fade * fade * (3 - 2 * fade))
        return stub

    segs = []
    if len(edges) == 2 and (edges[1] - edges[0]) % 6 in (2, 4):
        a, sa = _stem(edges[0])
        b, sb = _stem(edges[1])
        segs += [(a, sa), (b, sb)]
        pts = [(sa[0] * (1 - t) ** 2 + 2 * CENTER[0] * t * (1 - t) + sb[0] * t * t,
                sa[1] * (1 - t) ** 2 + 2 * CENTER[1] * t * (1 - t) + sb[1] * t * t)
               for t in (i / 60 for i in range(61))]
        segs += list(zip(pts, pts[1:]))
    else:
        for e in edges:
            a, s = _stem(e)
            segs += [(a, s), (s, CENTER)]
    hub = len(edges) >= 3

    def shape(px, py):
        d = min(seg_dist((px, py), a, b)[0] for a, b in segs)
        if hub:
            d = min(d, math.hypot(px - CENTER[0], py - CENTER[1]) - 1.0)
        return d, 1.0
    return shape


_NOISE = periodic_noise(9001, 1)
_SPECK = periodic_noise(9002, 0)


def _cobble(x, y):
    """4x4 cobbles, rows offset by 2. All steps are multiples of 4 on the hex lattice, and the
    tone is sampled at the wrapped cell origin, so the pattern is seamless."""
    row = y // 4
    off = 2 if row % 2 else 0
    lx, ly = (x + off) % 4, y % 4
    if lx == 3 or ly == 3:
        return C["slate"]
    tone = _NOISE[wrap(x - lx, row * 4)]
    if lx == 0 and ly == 0:
        return C["mist"] if tone > 0.55 else C["stone_lt"]
    if lx == 2 and ly == 2:
        return C["stone"]
    return C["stone_lt"] if tone > 0.35 else C["stone"]


def _color(material, x, y, d, w):
    n, s = _NOISE[(x, y)], _SPECK[(x, y)]
    rim = d > w - 1.2
    rut = abs(d - RUT) < 0.55
    if material == "dirt":
        if rim:
            return C["soil"]
        if rut:
            return C["earth"] if n < 0.25 else C["soil"]
        if s > 0.97:
            return C["stone_lt"]
        return C["sand_dk"] if n > 0.8 else C["soil"] if n < 0.08 else C["soil_lt"]
    if material == "stone":
        return C["slate_dk"] if rim else _cobble(x, y)
    if rim:
        return C["snow"]
    if rut:
        return C["mist"] if n < 0.2 else C["stone_lt"]
    return C["snow"] if s > 0.9 else C["mist"]


FRINGE_COLOR = {"dirt": ("soil", 0.8), "stone": ("slate", 0.6), "snow": ("snow", 0.85)}


def road_tile(material, pattern, k, edges):
    t = Tile(f"road_{material}_{pattern}" + ("" if k == 0 else f"_r{k}"), "roads")
    t.edges = [EDGE_NAMES[e] for e in edges]
    shape = road_shape(edges)
    fringe_col, fringe_density = FRINGE_COLOR[material]
    for x, y in HEX_PIXELS:
        d, presence = shape(x + 0.5, y + 0.5)
        w = HALF_WIDTH * (0.55 + 0.45 * presence)
        if d > w + FRINGE:
            continue
        if d > w:
            if (w + FRINGE - d) / FRINGE * fringe_density * presence > bayer(x, y):
                t.px[y][x] = C[fringe_col]
            continue
        if presence < 1.0 and presence <= bayer(x, y) * 0.95:
            continue
        t.px[y][x] = _color(material, x, y, d, w)
    return t


def all_roads():
    return [road_tile(m, name, k, rot)
            for m in MATERIALS for name, edges in PATTERNS for k, rot in rotations(edges)]
