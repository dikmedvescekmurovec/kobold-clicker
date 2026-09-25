"""Phase 4: blend overlays (56x64), soft transitions between environments.

Where environment A borders a tile of lower PRIORITY, a transparent overlay of A is drawn over that
tile: fully covered along the edges it shares with A, breaking up into patches and loose details
towards the interior. A's ground repeats on the hex lattice, so A at local pixel (x, y) of any tile
is A's own pixel (x, y). The overlay copies A's "base" look (the shared data every A variant uses
near its border), so it meets A pixel-exactly. Coverage depends only on the distance to A's hexes
plus lattice-periodic noise, so the tiles on both sides of every seam and corner agree.
Overlays are named by the edges that touch A, like roads; every edge set is pre-rendered.
Which environments may meet at all is terrain.ADJACENT.
"""
from functools import lru_cache
from itertools import combinations

from hexlib import C, EDGE_NAMES, HEX_PIXELS, LATTICE_SHIFTS, Tile, bayer, periodic_noise
from stamps import pebble, scatter, seg_dist, tuft
from terrain import CONIFER, ENV_SEED, ENVS, FOREST_LEAF, canopy, forest_shared_trees, forest_tree, hashf, pine, rock

PRIORITY = ["dirt", "grass", "desert", "ice", "forest", "mountains"]   # low -> high, higher draws over lower
RANK = {env: i for i, env in enumerate(PRIORITY)}
FULL = 4.0        # fully covered this close to A
DEPTH = 26.0      # ground coverage has faded out by here
DETAIL_DEPTH = DEPTH + 8.0   # loose details reach a little further
WOBBLE = 7.0      # noise displacement of the front in px, zero at the seam itself
TREE_KEEP = 13.0  # forest trees this close to A reach the seam with canopy or shadow, so they are drawn whole

# Continuous outline of each edge (0=E 1=SE 2=SW 3=W 4=NW 5=NE) and the neighbour hex across it.
SEGS = [((56, 16), (56, 48)), ((56, 48), (28, 64)), ((28, 64), (0, 48)),
        ((0, 48), (0, 16)), ((0, 16), (28, 0)), ((28, 0), (56, 16))]
NEIGHBOR_OFFSET = [(56, 0), (28, 48), (-28, 48), (-56, 0), (-28, -48), (28, -48)]
_EDGE_DIST = [{(x, y): seg_dist((x + 0.5, y + 0.5), *SEGS[e])[0] for x, y in HEX_PIXELS} for e in range(6)]
_WOBBLE_NOISE = periodic_noise(7001, 20)


def edge_dist(e, x, y):
    """Distance from a pixel centre to edge e, which for pixels in the hex is the distance to that neighbour."""
    return _EDGE_DIST[e][(x, y)]


def hex_dist(px, py, offset=(0, 0)):
    """Distance from a point to the hex at a lattice offset; 0 inside."""
    x, y = px - offset[0], py - offset[1]
    slant = abs(x - 28) * 16 / 28
    if 0 <= x <= 56 and slant <= y <= 64 - slant:
        return 0.0
    return min(seg_dist((x, y), a, b)[0] for a, b in SEGS)


def _smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


def coverage(d):
    return 1.0 - _smooth((d - FULL) / (DEPTH - FULL))


def detail_chance(d):
    return 1.0 - _smooth((d - FULL) / (DETAIL_DEPTH - FULL))


def front(mask):
    """Distance to the neighbouring A hexes, displaced by noise away from the seam."""
    out = {}
    for p in HEX_PIXELS:
        d = min(_EDGE_DIST[e][p] for e in mask)
        out[p] = d + WOBBLE * (_WOBBLE_NOISE[p] - 0.5) * min(max((d - 1.5) / 4.0, 0.0), 1.0)
    return out


@lru_cache(maxsize=None)
def base_ground(env):
    # forest trees are drawn whole in _forest_trees instead of being cut up by the coverage mask
    return ENVS[env]("base", objects=env != "forest")


@lru_cache(maxsize=None)
def _clump(env):
    """Coverage threshold noise: big patches that break away from the front, plus finer clumps."""
    s = ENV_SEED[env] + 7000
    big, fine, grain = periodic_noise(s + 2, 10), periodic_noise(s, 4), periodic_noise(s + 1, 1)
    return {p: 0.55 * big[p] + 0.25 * (0.65 * fine[p] + 0.35 * grain[p]) for p in HEX_PIXELS}


class _Shifted:
    """Draws a lattice copy of a stamp: every pixel offset, clipped to this hex instead of wrapped."""

    def __init__(self, tile, dx, dy):
        self.tile, self.dx, self.dy = tile, dx, dy

    def put(self, x, y, c, wrapped=True):
        self.tile.put(x + self.dx, y + self.dy, c, wrapped=False)

    def darken(self, x, y, wrapped=True, steps=1):
        self.tile.darken(x + self.dx, y + self.dy, wrapped=False, steps=steps)


def _forest_trees(t, mask):
    """The forest's shared border trees near A, in the same order as terrain.forest draws them."""
    for x, y in sorted(forest_shared_trees(), key=lambda p: (p[1], p[0])):
        for sx, sy in LATTICE_SHIFTS:
            cx, cy = x + 0.5 + sx, y + 0.5 + sy
            if hex_dist(cx, cy) < TREE_KEEP and min(hex_dist(cx, cy, NEIGHBOR_OFFSET[e]) for e in mask) < TREE_KEEP:
                forest_tree(_Shifted(t, sx, sy), x, y)


# --------------------------------------------------------------------------- fringe details
@lru_cache(maxsize=None)
def _anchors(env, salt, count, spacing, min_border):
    return tuple(scatter(ENV_SEED[env] * 11 + salt, count, spacing, min_border=min_border))


def _fringe(env, d, salt, count, spacing, min_border, cap=0.9):
    """Detail anchors in the fade band, thinning out away from A. Stamps must fit inside the hex."""
    for x, y in _anchors(env, salt, count, spacing, min_border):
        v = detail_chance(d[(x, y)])
        if 0.04 < v < cap and hashf(x, y, salt + 1) < v:
            yield x, y


def _put_all(t, x, y, cells):
    for dx, dy, c in cells:
        t.put(x + dx, y + dy, C[c])


def _grass_fringe(t, d):
    for x, y in _fringe("grass", d, 1, 140, 3, 3.0):
        tuft(t, x, y, C["gr4"], C["gr3"], C["gr1"], big=hashf(x, y, 7) < 0.45)
    for x, y in _fringe("grass", d, 2, 40, 5, 3.0):               # small grass clumps
        _put_all(t, x, y, ((0, 0, "gr4"), (1, 0, "gr3"), (-1, 1, "gr3"), (0, 1, "gr3"), (1, 1, "gr2"),
                           (2, 1, "gr2"), (0, 2, "gr1")))
    for x, y in _fringe("grass", d, 3, 100, 3, 1.0):
        t.put(x, y, C["gr4"] if hashf(x, y, 4) < 0.5 else C["gr3"])


def _desert_fringe(t, d):
    for x, y in _fringe("desert", d, 1, 60, 5, 3.0):             # sand patches, lit top-left
        cells = [(0, 0, "de4"), (1, 0, "de3"), (0, 1, "de3"), (1, 1, "de2")]
        if hashf(x, y, 7) < 0.5:
            cells += [(-1, 1, "de4"), (2, 1, "de3"), (0, 2, "de2"), (1, 2, "de2")]
        _put_all(t, x, y, cells)
    for x, y in _fringe("desert", d, 2, 60, 4, 3.0):
        pebble(t, x, y, C["de4"], C["de3"], C["de1"], big=hashf(x, y, 7) < 0.35)
    for x, y in _fringe("desert", d, 3, 120, 2, 1.0):
        t.put(x, y, C["de3"])


def _ice_fringe(t, d):
    for x, y in _fringe("ice", d, 1, 110, 3, 2.0):
        t.put(x, y, C["sn5"])
        t.put(x + 1, y, C["sn3"])
    for x, y in _fringe("ice", d, 2, 30, 7, 4.0):                # frozen puddles with a snow rim
        _put_all(t, x, y, ((0, 0, "sn5"), (1, 0, "sn5"), (2, 0, "sn4"),
                           (-1, 1, "sn4"), (0, 1, "sn3"), (1, 1, "sn3"), (2, 1, "sn2"), (3, 1, "sn3"),
                           (0, 2, "sn3"), (1, 2, "sn2"), (2, 2, "sn3")))


def _forest_fringe(t, d):
    for x, y in _fringe("forest", d, 1, 120, 3, 3.0):
        tuft(t, x, y, C["gr2"], C["gr1"], C["fo1"], big=hashf(x, y, 7) < 0.45)
    for x, y in _fringe("forest", d, 2, 24, 7, 8.0, cap=0.7):              # saplings running ahead of the trees
        if hashf(x, y, 8) < 0.5:
            pine(t, x, y + 3, 7, CONIFER, wrapped=False)
        else:
            canopy(t, x, y, 2.8, FOREST_LEAF[0], seed=x * 31 + y, wrapped=False)


def _mountains_fringe(t, d):
    for x, y in _fringe("mountains", d, 1, 100, 4, 3.0):
        pebble(t, x, y, C["sc3"], C["sc2"], C["ro1"], big=hashf(x, y, 7) < 0.45)
    for x, y in _fringe("mountains", d, 2, 24, 7, 7.0, cap=0.7):
        r = 2.2 + hashf(x, y, 9)
        rock(t, x + 0.5, y + 0.5, r, r * 0.78, seed=x * 31 + y, wrapped=False)


FRINGE = {"grass": _grass_fringe, "desert": _desert_fringe, "ice": _ice_fringe,
          "forest": _forest_fringe, "mountains": _mountains_fringe}


# --------------------------------------------------------------------------- tiles
@lru_cache(maxsize=None)
def blend_tile(env, mask):
    """Overlay of `env` for a tile whose edges in `mask` (edge indices) touch env."""
    mask = tuple(sorted(mask))
    t = Tile(f"blend_{env}_" + "_".join(EDGE_NAMES[e] for e in mask), "blends")
    t.env, t.mask, t.edges = env, mask, [EDGE_NAMES[e] for e in mask]
    d, base, clump = front(mask), base_ground(env), _clump(env)
    for x, y in HEX_PIXELS:
        if coverage(d[(x, y)]) > clump[(x, y)] + 0.2 * bayer(x, y):
            t.px[y][x] = base.px[y][x]
    FRINGE[env](t, d)
    if env == "forest":
        _forest_trees(t, mask)
    return t


def all_blends():
    masks = [m for k in range(1, 7) for m in combinations(range(6), k)]
    return [blend_tile(env, m) for env in PRIORITY[1:] for m in masks]
