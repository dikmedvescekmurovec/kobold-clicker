"""The six peoples' settlements for the side-view backdrops (`sideview.py`): each culture's
buildings at three scales -- village, town, fortress -- side on, inked, in ENDESGA 64.

A settlement is drawn in two stages either side of the ground strip: "back" before it (a mound, a
back row, a citadel on its hill) and "front" after it (what stands on the fighting ground). Every
piece stands on the lowest ground under its footprint (`seat`), so none can float. Within one
people the village, the town and the fortress are the same builders at three scales, and no two
peoples share a wall, a roof or a signature (the README's table):

    grass      plaster in dark oak on limestone, steep gables   round stair-turret, slate cone, pennant
    dirt       daub and warm rubble, fat thatch cones            crossed poles over the thatch, lancets
    forest     timber on posts over mossy stone, dark thatch     stacked meru roofs, gold finials, split gate
    desert     red rammed earth, battered, flat decks            pointed merlon teeth, lattice, palms
    mountains  warm ashlar, timber galleries, flat decks         red cone and pennant, arcaded viaduct
    ice        dark logs, upswept eaves under snow               a warm light in every opening, ice needles
"""
import math
import random

import numpy as np

import sideview as sv
from sideview import FEET, GOLD, INK, LEAF, W, WHITE, XX, YY, disc, inked, noise2, rgb


def ramp(*hexes):
    return tuple(rgb(h) for h in hexes)


## Every material a people builds in, light to dark.
LIME = ramp("c7cfdd", "92a1b9", "657392", "424c6e")
PLASTER = ramp("f9e6cf", "f6ca9f", "e69c69", "bf6f4a")
OAK = ramp("8a4836", "5d2c28", "391f21", "1c121c")
TILE = ramp("e07438", "c64524", "8e251d", "571c27")
SLATE = ramp("92a1b9", "657392", "424c6e", "2a2f4e")
DAUB = ramp("e69c69", "bf6f4a", "8a4836", "5d2c28")
STRAW = ramp("ffc825", "edab50", "bf6f4a", "8a4836")
RUBBLE = ramp("bf6f4a", "8a4836", "5d2c28", "391f21")
DARK_THATCH = ramp("8a4836", "5d2c28", "391f21", "1c121c")
EARTHEN = ramp("edab50", "e07438", "c64524", "8e251d")
ASHLAR = ramp("f6ca9f", "e69c69", "bf6f4a", "8a4836")
RED = ramp("f5555d", "ea323c", "c42430", "891e2b")
ICE = ramp("ffffff", "94fdff", "00cdf9", "0098dc")
ICE_WALL = ramp("ffffff", "c7cfdd", "92a1b9", "657392")
GLOW = ramp("ffeb57", "ffc825", "ffa214", "e07438")
HOLE = rgb("1c121c")
SNOW = (WHITE, rgb("c7cfdd"))

## The bottom row of anything standing on the ground strip: the ground's ink is FEET.
BASE = FEET - 1
MIDDLE = 192


# ---------------------------------------------------------------- placing

def seat(line, x0, x1):
    """The row a footprint from x0 to x1 stands on: the lowest ground under it."""
    a_, b_ = max(0, int(x0)), min(W - 1, int(x1))
    if b_ < a_:
        return int(line[max(0, min(W - 1, a_))])
    return int(np.max(line[a_:b_ + 1]))


def flat():
    return np.full(W, float(BASE))


def row(a, rng, x0, x1, line, pieces, gap=(2, 6)):
    """Lays pieces left to right from x0 to x1, the row centred in that span, each seated on
    `line`: `pieces` are (weight, (least, most) width, draw(a, rng, x, base, w))."""
    placed = []
    x = x0
    while True:
        k = rng.uniform(0, sum(p[0] for p in pieces))
        for p in pieces:
            k -= p[0]
            if k <= 0:
                break
        w = rng.randint(*p[1])
        if x + w > x1:
            break
        placed.append((x, w, p[2]))
        x += w + rng.randint(*gap)
    if not placed:
        return
    shift = (x1 - (placed[-1][0] + placed[-1][1])) // 2
    for (x, w, fn) in sorted(placed, key=lambda q: seat(line, q[0] + shift, q[0] + shift + q[1])):
        fn(a, rng, x + shift, seat(line, x + shift, x + shift + w - 1), w)


# ---------------------------------------------------------------- parts

def block(a, x0, x1, base, h, mat, batter=0.0, cap=False):
    """A wall face from x0 to x1 standing on `base`, h tall and inked: lit down its left edge,
    shaded down its right, drawn in by `batter` a row as it rises; `cap` lights its top row."""
    x0, x1 = int(x0), int(x1)
    inset = np.floor(np.clip(base - YY, 0, None) * batter)
    m = (XX >= x0 + inset) & (XX <= x1 - inset) & (YY > base - h) & (YY <= base)
    inked(a, m)
    hi, lit, body, shd = mat
    a[m] = body
    left = m & ~np.roll(m, 1, axis=1)
    right = m & ~np.roll(m, -1, axis=1)
    a[left | (np.roll(left, 1, axis=1) & m)] = lit
    a[right] = shd
    if cap:
        a[m & ~np.roll(m, 1, axis=0)] = hi
    return m


def courses(a, m, c, base, step=4, joint=8):
    k = base - YY
    rows = m & (k % step == step - 1)
    joints = m & ((XX + (k // step) * (joint // 2)) % joint == 0) & ~rows
    a[rows | joints] = c


def speckle(a, m, seed, c, t=0.72, cell=2):
    a[m & (noise2(seed, W, 216, cell) > t)] = c


def opening(a, x, y, w, h, c=HOLE, arch=False, glow=None):
    """A window or a door: dark, or lit warm from inside (`glow`), round-headed with `arch`."""
    m = (XX >= x) & (XX < x + w) & (YY >= y) & (YY < y + h)
    if arch and w >= 3:
        m &= ~(((XX == x) | (XX == x + w - 1)) & (YY == y))
    if glow is None:
        a[m] = c
    else:
        a[m] = glow[1]
        a[m & (YY == y + h - 1)] = glow[2]
        a[m & (XX == x) & (YY <= y + 1)] = glow[0]
    return m


def lattice(a, x, y, w, h, bars):
    """An incised lattice: a dark grille with the wall's light tone left standing in a grid."""
    m = opening(a, x, y, w, h)
    a[m & ((XX - x) % 2 == 1) & ((YY - y) % 2 == 1)] = bars


def roof(a, x0, x1, eave, rh, mat, over=2, ridge=0.0, lines=3, sweep=0):
    """A pitched roof seen from the side: eaves `over` past each wall at row `eave`, sloping in to a
    ridge `ridge` of the width (0: a gable end, a triangle), `sweep` pixels of upturned eave at each
    end. Lit down its left slope, coursed across its face, the eave in shade. Returns the mask and
    the ridge's row."""
    cx = (x0 + x1) / 2
    half = (x1 - x0) / 2 + over
    v = (eave - YY) / rh
    lw = half * (1 - v * (1 - ridge))
    m = (v >= 0) & (v < 1) & (np.abs(XX - cx) <= lw)
    for k in range(1, sweep + 1):
        for s in (-1, 1):
            m |= (YY == eave - k) & (np.abs(XX - (cx + s * (half + k))) < 0.6)
    inked(a, m)
    hi, lit, body, shd = mat
    a[m] = body
    if ridge < 0.05:
        a[m & (XX < cx)] = lit
    a[m & ((eave - YY) % lines == lines - 1)] = shd
    a[m & (XX - (cx - lw) < 2)] = hi
    a[m & ((cx + lw) - XX < 2)] = shd
    a[m & (YY == eave)] = shd
    return m, int(eave - rh + 1)


def cone(a, cx, eave, half, rh, mat, flare=1.0):
    """A conical roof: lit on its left, a line of shade down its right, the eave in shade. Returns
    the apex row."""
    v = (eave - YY) / rh
    lw = half * np.clip(1 - v, 0, 1) ** flare
    m = (v >= 0) & (v < 1) & (np.abs(XX - cx) <= lw)
    inked(a, m)
    hi, lit, body, shd = mat
    a[m] = body
    a[m & (XX < cx - 0.5)] = lit
    a[m & (XX < cx - lw + 1.5)] = hi
    a[m & (XX > cx + lw * 0.5)] = shd
    a[m & (YY == eave)] = shd
    return int(eave - rh + 1)


def dome(a, cx, eave, half, rh, mat, lines=3):
    """A fat mound of thatch: a half ellipse over the eave, coursed, lit on its left."""
    v = (eave - YY) / rh
    m = (v >= 0) & (v < 1) & (np.abs(XX - cx) <= half * np.sqrt(np.clip(1 - v * v, 0, 1)))
    inked(a, m)
    hi, lit, body, shd = mat
    a[m] = body
    a[m & (XX < cx - half * 0.35)] = lit
    a[m & ((eave - YY) % lines == lines - 1)] = shd
    a[m & (XX > cx + half * 0.55)] = shd
    a[m & (YY == eave)] = shd
    return int(eave - rh + 1)


def crenels(a, x0, x1, top, mat, tooth=2, gap=2, h=3, pointed=False, skip=None):
    """Teeth along a wall head standing on row `top`: square merlons, or pointed ones."""
    m = np.zeros(XX.shape, bool)
    x = int(x0)
    i = 0
    while x + tooth - 1 <= x1:
        if skip is None or i not in skip:
            if pointed:
                for k in range(h):
                    half = (tooth - 1) / 2 * (1 - k / h)
                    m |= (YY == top - 1 - k) & (np.abs(XX - (x + (tooth - 1) / 2)) <= half + 0.01)
            else:
                m |= (XX >= x) & (XX < x + tooth) & (YY >= top - h) & (YY < top)
        x += tooth + gap
        i += 1
    inked(a, m)
    a[m] = mat[1]
    a[m & ~np.roll(m, -1, axis=1)] = mat[3]
    a[m & ~np.roll(m, 1, axis=0)] = mat[0]
    return m


def pennant(a, x, top, pole=7, flag=RED):
    staff = (XX == x) & (YY > top - pole) & (YY <= top)
    cloth = np.zeros(XX.shape, bool)
    for k in range(3):
        cloth |= (YY == top - pole + 1 + k) & (XX > x) & (XX <= x + 6 - 2 * k)
    inked(a, staff | cloth)
    a[staff] = OAK[2]
    a[cloth] = flag[1]
    a[cloth & (YY == top - pole + 1)] = flag[0]
    a[cloth & (YY == top - pole + 3)] = flag[3]


def finial(a, cx, top, h=5):
    """A gold spike on an apex: a stepped foot, a rod, a bright tip."""
    rod = (XX == cx) & (YY > top - h) & (YY <= top)
    foot = (np.abs(XX - cx) <= 1) & (YY > top - 2) & (YY <= top)
    inked(a, rod | foot)
    a[rod | foot] = GOLD[2]
    a[foot & (XX < cx)] = GOLD[1]
    a[top - h + 1, cx] = GOLD[0]


def frame(a, m, x0, top, bot, step, c, braces=True):
    """Timber framing over a plaster face: posts every `step`, a sill, a rail, a plate, and a
    brace across the lower half of every other bay."""
    a[m & ((XX - x0) % step == 0)] = c
    mid = (top + bot) // 2
    a[m & ((YY == top) | (YY == mid) | (YY == bot))] = c
    if braces:
        for px in range(int(x0), int(XX[m].max()) if m.any() else x0, step * 2):
            for i in range(step + 1):
                y = int(round(bot - i * (bot - mid) / step))
                if m[y, min(W - 1, px + i)]:
                    a[y, px + i] = c


def gallery(a, x0, x1, y, wood=OAK):
    """A timber gallery bolted on a wall: a plank floor two past each end, a rail on posts, a strut
    under each end."""
    floor = (XX >= x0 - 2) & (XX <= x1 + 2) & (YY >= y) & (YY <= y + 1)
    rail = (XX >= x0 - 2) & (XX <= x1 + 2) & (YY == y - 4)
    posts = (XX >= x0 - 2) & (XX <= x1 + 2) & (YY > y - 4) & (YY < y) & ((XX - x0) % 3 == 0)
    struts = np.zeros(XX.shape, bool)
    for k in range(3):
        struts |= (YY == y + 2 + k) & ((XX == x0 - 1 + k) | (XX == x1 + 1 - k))
    m = floor | rail | posts | struts
    inked(a, m)
    a[m] = wood[1]
    a[floor & (YY == y)] = wood[0]
    a[struts] = wood[2]


def snow_load(a, m):
    """Snow lying on a roof: a pad two rows deep on its upper surfaces and one over them, inked."""
    top = m & ~np.roll(m, 1, axis=0)
    pad = top | (np.roll(top, 1, axis=0) & m) | np.roll(top, -1, axis=0) | np.roll(top, -2, axis=0)
    inked(a, pad)
    a[pad] = SNOW[1]
    a[pad & ~np.roll(pad, 1, axis=0)] = SNOW[0]


def icicles(a, x0, x1, y, rng):
    for x in range(int(x0), int(x1) + 1, rng.randint(2, 3)):
        for k in range(rng.randint(1, 3)):
            if 0 <= x < W:
                a[y + 1 + k, x] = ICE[1] if k == 0 else ICE[2]


def mound(a, cx, half, height, body, lit, rough=0.0, seed=0):
    """A hill raised behind the ground strip for a settlement to climb, drawn as a far layer (no
    ink). Returns the line a piece is seated on."""
    xs = np.arange(W)
    t = (xs - cx) / half
    line = FEET - height * np.clip(1 - t * t, 0, None) ** 1.3
    if rough:
        line += (sv.fbm(seed, W, ((20, 1.0), (50, 0.5))) - 0.5) * rough * (FEET - line) / height
    line = np.minimum(line, FEET)
    top = np.floor(line).astype(int)
    m = (YY >= top[None, :]) & (YY <= FEET)
    a[m] = body
    slope = np.gradient(line)
    a[m & (YY - top[None, :] < np.clip(-slope, 0, 2)[None, :] * 3 + 1) & (slope[None, :] < -0.05)] = lit
    return np.minimum(line, BASE)


# ---------------------------------------------------------------- grass: plaster in dark oak, slate cones

def g_cottage(a, rng, x, base, w):
    h = rng.randint(15, 19)
    block(a, x, x + w - 1, base, 3, LIME)
    m = block(a, x, x + w - 1, base - 3, h - 3, PLASTER)
    top = base - h + 1
    step = rng.choice((5, 6))
    frame(a, m, x, top, base - 3, step, OAK[2], braces=rng.random() < 0.6)
    bays = list(range(x, x + w - step, step))
    door = rng.choice(bays)
    for bx in bays:
        if bx == door:
            opening(a, bx + 1, base - 9, step - 1, 6, OAK[1])
        elif rng.random() < 0.85:
            opening(a, bx + 2, top + 3, max(2, step - 3), 3, SLATE[3])
            a[top + 3, bx + 2] = SLATE[0]
    mat = TILE if rng.random() < 0.7 else SLATE
    _, ridge = roof(a, x, x + w - 1, top - 1, int(w * 0.42) + 2, mat, over=2, ridge=0.35)
    if rng.random() < 0.6:
        cx = x + rng.randint(3, max(4, w - 6))
        block(a, cx, cx + 2, ridge + 4, 7, LIME, cap=True)


def g_townhouse(a, rng, x, base, w):
    h = rng.randint(26, 34)
    block(a, x, x + w - 1, base, 3, LIME)
    m = block(a, x, x + w - 1, base - 3, h - 3, PLASTER)
    top = base - h + 1
    frame(a, m, x, top, base - 3, 4, OAK[2], braces=False)
    for y in range(top + 3, base - 10, 8):
        for wx in (x + 2, x + w - 4):
            opening(a, wx, y, 2, 3, SLATE[3])
    opening(a, x + w // 2 - 1, base - 8, 3, 5, OAK[1])
    mat = TILE if rng.random() < 0.6 else SLATE
    _, ridge = roof(a, x, x + w - 1, top - 1, int(w * 0.9), mat, over=1)
    a[ridge + int(w * 0.45), x + w // 2] = SLATE[3]


def g_turret(a, rng, x, base, w, h=None):
    """The grass people's signature: a round stair-turret of limestone under a tall slate cone."""
    h = h or rng.randint(32, 44)
    m = block(a, x, x + w - 1, base, h, LIME)
    courses(a, m, LIME[2], base, 4, 6)
    a[m & (XX == x + w - 2)] = LIME[2]
    for y in range(base - h + 5, base - 6, 8):
        opening(a, x + w // 2, y, 1, 3)
    apex = cone(a, x + (w - 1) / 2, base - h, w / 2 + 1.5, int(w * 2.1), SLATE)
    pennant(a, int(x + (w - 1) / 2), apex - 1, 8)


def g_hall(a, rng, x, base, w):
    h = rng.randint(18, 22)
    m = block(a, x, x + w - 1, base, h, LIME)
    courses(a, m, LIME[2], base, 4, 7)
    for wx in range(x + 4, x + w - 5, 6):
        opening(a, wx, base - h + 5, 2, 6, SLATE[3], arch=True)
    opening(a, x + w // 2 - 2, base - 9, 5, 9, OAK[2], arch=True)
    roof(a, x, x + w - 1, base - h, int(w * 0.34), SLATE, over=2, ridge=0.45)
    tx = x - 3 if rng.random() < 0.5 else x + w - 6
    g_turret(a, rng, tx, base, 9, h + rng.randint(12, 18))


def g_keep(a, rng, layout, line):
    """The keep on the crown of the hill, turrets stepping down its flanks, halls between."""
    cx = MIDDLE + rng.randint(-8, 8)
    kw, kh = rng.randint(42, 50), rng.randint(46, 56)
    for side in (-1, 1):
        tx = int(cx + side * rng.uniform(34, 46)) - 5
        g_turret(a, rng, tx, seat(line, tx, tx + 10), 11, rng.randint(46, 58))
    x0 = int(cx - kw / 2)
    base = seat(line, x0, x0 + kw)
    m = block(a, x0, x0 + kw, base, kh, LIME)
    courses(a, m, LIME[2], base, 4, 7)
    for y in range(base - kh + 8, base - 10, 9):
        for wx in range(x0 + 5, x0 + kw - 4, 8):
            opening(a, wx, y, 2, 4, SLATE[3], arch=True)
    opening(a, int(cx) - 3, base - 11, 7, 11, OAK[2], arch=True)
    crenels(a, x0, x0 + kw, base - kh, LIME)
    roof(a, x0 + 5, x0 + kw - 5, base - kh - 3, int(kw * 0.34), SLATE, over=0, ridge=0.3)
    for tx in (x0 - 3, x0 + kw - 4):
        block(a, tx, tx + 7, base - kh + 10, 14, LIME)
        apex = cone(a, tx + 3.5, base - kh - 4, 5, 14, SLATE)
        pennant(a, tx + 3, apex - 1, 6)
    for side in (-1, 1):
        hx = int(cx + side * rng.uniform(58, 72)) - 9
        g_hall(a, rng, hx, seat(line, hx, hx + 18), 18)


def g_curtain(a, rng, x0, x1, base, h=14):
    m = block(a, x0, x1, base, h, LIME)
    courses(a, m, LIME[2], base, 4, 7)
    crenels(a, x0, x1, base - h, LIME)
    gx = MIDDLE + rng.randint(-20, 20)
    opening(a, gx - 4, base - 10, 9, 10, HOLE, arch=True)
    a[(XX >= gx - 3) & (XX <= gx + 3) & (YY > base - 9) & (YY <= base) & ((XX - gx) % 2 == 0)] = LIME[3]
    for tx in (x0 - 5, x1 - 5):
        g_turret(a, rng, tx, base, 10, h + rng.randint(10, 14))


GRASS = dict(
    houses=[(5, (22, 32), g_cottage), (2, (12, 15), g_townhouse)],
    talls=[(3, (12, 15), g_townhouse), (1, (22, 28), g_cottage)],
    hall=g_hall, hall_w=(30, 38),
    tower=lambda a, rng, x, base: g_turret(a, rng, x, base, 11, rng.randint(40, 50)), tower_w=11,
    citadel=g_keep, curtain=g_curtain,
    mound=(rgb("134c4c"), rgb("1e6f50")),
)


# ---------------------------------------------------------------- dirt: daub, rubble, fat thatch

def d_hut(a, rng, x, base, w):
    """A daub drum under a fat cone of thatch, crossed poles over the apex, a round-headed door and
    a pair of slit lancets."""
    h = int(w * 0.58)
    cx = x + w / 2
    wall = (np.abs(XX - cx) <= w / 2 - (base - YY) / h) & (YY > base - h) & (YY <= base)
    inked(a, wall)
    a[wall] = DAUB[2]
    a[wall & (XX < cx - w / 2 + 3)] = DAUB[1]
    a[wall & (XX > cx + w / 2 - 3)] = DAUB[3]
    speckle(a, wall, int(x * 7 + base), DAUB[1], 0.7)
    dx = int(cx + rng.choice((-1, 1)) * w * 0.15)
    opening(a, dx - 2, base - 7, 5, 8, OAK[2], arch=True)
    lx = int(2 * cx - dx)
    for k in (-1, 1):
        a[(XX == lx + k) & (YY >= base - h + 4) & (YY <= base - h + 7)] = OAK[2]
    eave = base - h + 2
    rh = int(w * 0.75)
    v = (eave - YY) / rh
    half = (w / 2 + 4) * np.clip(1 - v, 0, 1) ** 0.6
    top = (v >= 0) & (v <= 1) & (np.abs(XX - cx) <= half)
    inked(a, top)
    a[top] = STRAW[1]
    a[top & (XX < cx - half * 0.3)] = STRAW[0]
    a[top & (XX > cx + half * 0.45)] = STRAW[2]
    a[top & ((eave - YY) % 3 == 2)] = STRAW[2]
    a[top & (YY >= eave - 1)] = STRAW[3]
    poles(a, cx, eave - rh)


def poles(a, cx, apex):
    """The steppe people's signature: two poles crossed over a thatch apex."""
    m = np.zeros(XX.shape, bool)
    for s in (-1, 1):
        for k in range(6):
            m[apex + 2 - k, int(cx + s * (k - 2))] = True
    inked(a, m & (YY < apex))
    a[m] = OAK[1]


def d_longhouse(a, rng, x, base, w):
    h = rng.randint(12, 15)
    m = block(a, x, x + w - 1, base, h, DAUB)
    speckle(a, m, x * 13 + base, DAUB[0], 0.72)
    opening(a, x + w // 3, base - 7, 5, 8, OAK[2], arch=True)
    for k in range(3):
        opening(a, x + w - 12 + k * 2, base - h + 4, 1, 4, OAK[2])
    apex = dome(a, x + (w - 1) / 2, base - h + 1, w / 2 + 3, rng.randint(12, 16), STRAW)
    poles(a, x + w * 0.3, apex + 3)


def d_tower(a, rng, x, base, w, h=None):
    """A tower of warm rubble with a crenellated head and a group of lancets."""
    h = h or rng.randint(28, 38)
    m = block(a, x, x + w - 1, base, h, RUBBLE, cap=True)
    speckle(a, m, x * 3 + h, RUBBLE[0], 0.74)
    speckle(a, m, x * 5 + h, RUBBLE[3], 0.76)
    crenels(a, x, x + w - 1, base - h, RUBBLE, skip={rng.randrange(6)})
    for k in range(3):
        opening(a, x + w // 2 - 2 + k * 2, base - h + 5, 1, 5, HOLE)
    if w >= 14:
        opening(a, x + w // 2 - 2, base - 8, 5, 9, OAK[2], arch=True)


def d_box(a, rng, layout, line):
    """The steppe fortress, the grimmest of the six: one rubble box on the hill with the top bitten
    out of it and its windows open onto the sky -- no crown."""
    cx = MIDDLE + rng.randint(-10, 10)
    w, h = rng.randint(100, 118), rng.randint(58, 70)
    x0, x1 = int(cx - w / 2), int(cx + w / 2)
    base = seat(line, x0, x1)
    before = a.copy()
    bite_x = cx + rng.uniform(-w * 0.25, w * 0.25)
    bite = np.clip(26 - np.abs(XX - bite_x) * 0.7, 0, None) + (noise2(layout * 7 + 1, W, 216, 2) * 5)
    top = base - h + 1
    m = (XX >= x0) & (XX <= x1) & (YY >= top + bite * (XX > x0 + 3) * (XX < x1 - 3)) & (YY <= base)
    inked(a, m)
    a[m] = RUBBLE[1]
    a[m & (XX <= x0 + 1)] = RUBBLE[0]
    a[m & (XX >= x1)] = RUBBLE[3]
    speckle(a, m, layout * 11, RUBBLE[0], 0.74)
    speckle(a, m, layout * 13, RUBBLE[3], 0.74)
    a[m & ~np.roll(m, 1, axis=0)] = RUBBLE[0]
    holes = np.zeros(XX.shape, bool)
    for y in range(top + 12, base - 14, 14):
        for wx in range(x0 + 8, x1 - 8, 12):
            holes |= (XX >= wx) & (XX < wx + 3) & (YY >= y) & (YY < y + 7) & \
                ~(((XX == wx) | (XX == wx + 2)) & (YY == y))
    holes &= m
    a[holes] = before[holes]
    a[np.roll(holes, 1, axis=1) & m & ~holes] = INK
    a[np.roll(holes, -1, axis=1) & m & ~holes] = INK
    a[np.roll(holes, 1, axis=0) & m & ~holes] = INK
    a[np.roll(holes, -1, axis=0) & m & ~holes] = INK
    opening(a, int(cx) - 5, base - 13, 11, 14, HOLE, arch=True)


def d_curtain(a, rng, x0, x1, base, h=10):
    m = block(a, x0, x1, base, h, RUBBLE, cap=True)
    speckle(a, m, x0 + x1, RUBBLE[0], 0.74)
    crenels(a, x0, x1, base - h, RUBBLE, skip=set(rng.sample(range(40), 8)))
    gx = MIDDLE + rng.randint(-20, 20)
    opening(a, gx - 4, base - 8, 9, 9, HOLE)
    lintel = (XX >= gx - 6) & (XX <= gx + 6) & (YY >= base - 10) & (YY <= base - 9)
    inked(a, lintel)
    a[lintel] = OAK[1]
    for tx in (x0 - 4, x1 - 10):
        d_tower(a, rng, tx, base, 14, h + rng.randint(10, 16))


DIRT = dict(
    houses=[(1, (24, 38), d_hut)],
    talls=[(2, (36, 46), d_longhouse), (1, (12, 16), lambda a, rng, x, base, w: d_tower(a, rng, x, base, w))],
    hall=d_longhouse, hall_w=(42, 52),
    tower=lambda a, rng, x, base: d_tower(a, rng, x, base, 16, rng.randint(36, 46)), tower_w=16,
    citadel=d_box, curtain=d_curtain,
    mound=(rgb("571c27"), rgb("8e251d")),
)


# ---------------------------------------------------------------- forest: posts over mossy stone, merus

def moss(a, m, rng):
    top = m & ~np.roll(m, 1, axis=0)
    for y, x in zip(*np.nonzero(top)):
        if rng.random() < 0.55:
            for k in range(rng.randint(1, 3)):
                a[y + k, x] = LEAF[1] if k == 0 else LEAF[2]


def f_stilt(a, rng, x, base, w):
    """A house raised on posts over mossy stone footings, a steep dark thatch over plank walls, a
    gold finial on the apex."""
    lift = rng.randint(5, 7)
    for px in range(x + 1, x + w - 1, max(4, (w - 2) // 3)):
        foot = block(a, px - 1, px + 1, base, 2, LIME)
        post = (XX == px) & (YY > base - lift - 1) & (YY <= base - 2)
        inked(a, post)
        a[post] = OAK[1]
    fl = block(a, x - 1, x + w, base - lift, 2, OAK, cap=True)
    wh = rng.randint(12, 15)
    m = block(a, x, x + w - 1, base - lift - 2, wh, RUBBLE)
    a[m & ((XX - x) % 3 == 2) & (XX > x + 1) & (XX < x + w - 1)] = RUBBLE[2]
    opening(a, x + w // 2 - 2, base - lift - 10, 4, 8, HOLE)
    if w > 22:
        opening(a, x + 3, base - lift - 2 - wh + 4, 3, 3, HOLE)
    _, ridge = roof(a, x, x + w - 1, base - lift - 2 - wh, int(w * 0.45) + 4, DARK_THATCH, over=3,
                    ridge=0.18)
    finial(a, int(x + (w - 1) / 2), ridge - 1, 5)


def terrace(a, x0, x1, base, h, rng):
    """A stone step of mossy limestone: a lit top course, a coursed face, moss over its lip."""
    m = block(a, x0, x1, base, h, LIME, cap=True)
    courses(a, m, LIME[2], base, 4, 7)
    moss(a, m, rng)
    return base - h


def meru(a, cx, base, tiers, w0, w1, fin=6):
    """The forest people's signature: roofs of dark thatch stacked and shrinking, each a slab with a
    lit top, its left end catching the light, a shadow of posts under it, a gold finial above."""
    y = base
    for i in range(tiers):
        u = i / max(1, tiers - 1)
        half = int((w0 + (w1 - w0) * u) / 2)
        post = (np.abs(XX - cx) <= max(1, half - 3)) & (YY > y - 2) & (YY <= y)
        slab = (np.abs(XX - cx) <= half) & (YY > y - 5) & (YY <= y - 2)
        slab |= (np.abs(XX - cx) <= half - 1) & (YY == y - 5)
        inked(a, post | slab)
        a[post] = DARK_THATCH[2]
        a[slab] = DARK_THATCH[1]
        a[slab & (YY <= y - 4)] = DARK_THATCH[0]
        a[slab & (XX <= cx - half + 1)] = DARK_THATCH[0]
        a[slab & (YY == y - 2)] = DARK_THATCH[2]
        y -= 6
    finial(a, cx, y, fin)


def plinth_meru(a, rng, x, base, w, tiers=None):
    """A meru on its stone plinth, its door shut in shadow."""
    cx = x + w // 2
    ph = rng.randint(7, 10)
    m = block(a, cx - w // 4, cx + w // 4, base, ph, LIME, cap=True)
    moss(a, m, rng)
    opening(a, cx - 1, base - ph + 3, 3, ph - 3, HOLE)
    meru(a, cx, base - ph, tiers or rng.randint(4, 7), w, max(6, w // 4))


def split_gate(a, cx, base, h, gap=8, brick=DAUB):
    """The candi bentar: one tower cut in two, a stepped half either side of the way in."""
    for side in (-1, 1):
        m = np.zeros(XX.shape, bool)
        for k in range(4):
            w = 16 - k * 3
            y1, y0 = base - k * h // 4, base - (k + 1) * h // 4
            xa, xb = (cx - gap // 2 - w, cx - gap // 2 - 1) if side < 0 else \
                (cx + gap // 2, cx + gap // 2 + w - 1)
            m |= (XX >= xa) & (XX <= xb) & (YY > y0) & (YY <= y1)
        inked(a, m)
        a[m] = brick[2]
        a[m & ((base - YY) % 3 == 0)] = brick[3]
        a[m & ~np.roll(m, 1, axis=1)] = brick[1]
        a[m & ~np.roll(m, 1, axis=0)] = brick[0]


def f_temple(a, rng, layout, stage):
    """The forest fortress, a temple on the fighting ground: mossy terraces climbing to the merus,
    the split gate at their foot. Layouts: one great meru with two lesser; two great merus; one
    meru with stilt halls on the lower terrace; three merus of a height."""
    if stage != "front":
        return
    cx = MIDDLE + rng.randint(-6, 6)
    y1 = terrace(a, cx - 78, cx + 78, BASE, 12, rng)
    y2 = terrace(a, cx - 58, cx + 58, y1, 11, rng)
    if layout == 1:
        for side in (-1, 1):
            plinth_meru(a, rng, cx + side * 46 - 11, y2, 22, 5)
        y3 = terrace(a, cx - 36, cx + 36, y2, 10, rng)
        plinth_meru(a, rng, cx - 20, y3, 40, 8)
    elif layout == 2:
        for side in (-1, 1):
            plinth_meru(a, rng, cx + side * 26 - 17, y2, 34, 7)
    elif layout == 3:
        for side in (-1, 1):
            f_stilt(a, rng, cx + side * 48 - 11, y1, 22)
        y3 = terrace(a, cx - 30, cx + 30, y2, 10, rng)
        plinth_meru(a, rng, cx - 19, y3, 38, 9)
    else:
        for k in (-1, 0, 1):
            plinth_meru(a, rng, cx + k * 36 - 13, y2, 26, 6)
    split_gate(a, cx, BASE, 30)


def f_curtain(a, rng, x0, x1, base, h=9):
    gx = MIDDLE + rng.randint(-16, 16)
    for xa, xb in ((x0, gx - 18), (gx + 18, x1)):
        m = block(a, xa, xb, base, h, LIME, cap=True)
        courses(a, m, LIME[2], base, 4, 7)
        moss(a, m, rng)
    split_gate(a, gx, base, 30)


def f_town(a, rng, layout, stage):
    hilly = layout in (2, 4)
    if stage == "back":
        line = mound(a, MIDDLE, 150, rng.uniform(14, 22), *FOREST["mound"]) if hilly else flat()
        row(a, rng, 90, 160, line, [(1, (18, 24), f_stilt)], gap=(1, 4))
        row(a, rng, 224, 294, line, [(1, (18, 24), f_stilt)], gap=(1, 4))
        for k, w in ((-1, 24), (1, 30)) if layout % 2 else ((0, 36),):
            x = MIDDLE + k * 20 - w // 2
            plinth_meru(a, rng, x, seat(line, x, x + w), w)
    elif layout in (1, 3):
        f_curtain(a, rng, 104, 280, BASE)
    else:
        row(a, rng, 116, 268, flat(), [(1, (20, 28), f_stilt)], gap=(3, 8))


FOREST = dict(
    houses=[(1, (20, 28), f_stilt)],
    hall=lambda a, rng, x, base, w: plinth_meru(a, rng, x, base, w), hall_w=(30, 38),
    curtain=f_curtain,
    town=f_town, fortress=f_temple,
    mound=(rgb("134c4c"), rgb("1e6f50")),
)


# ---------------------------------------------------------------- desert: battered earth, teeth, lattice

def s_house(a, rng, x, base, w, h=None):
    """Red rammed earth, battered, under a flat deck with pointed teeth; beam ends in a row under
    the deck, a lattice window, a round-headed door."""
    h = h or rng.randint(14, 20)
    m = block(a, x, x + w - 1, base, h, EARTHEN, batter=0.08, cap=True)
    inset = int(h * 0.08)
    crenels(a, x + inset, x + w - 1 - inset, base - h + 1, EARTHEN, tooth=3, gap=1, h=3, pointed=True)
    a[(YY == base - h + 4) & m & ((XX - x) % 4 == 2)] = OAK[1]
    lattice(a, x + w // 2 - 2 + rng.choice((-4, 4)) * (w > 22), base - h + 6, 5, 5, EARTHEN[0])
    opening(a, x + (w // 4 if w > 18 else w // 2 - 2), base - 7, 4, 8, HOLE, arch=True)


def s_tower(a, rng, x, base, w, h=None):
    h = h or rng.randint(28, 38)
    m = block(a, x, x + w - 1, base, h, EARTHEN, batter=0.06, cap=True)
    inset = int(h * 0.06)
    crenels(a, x + inset, x + w - 1 - inset, base - h + 1, EARTHEN, tooth=3, gap=1, h=3, pointed=True)
    for y in range(base - h + 6, base - 10, 11):
        lattice(a, x + w // 2 - 2, y, 5, 5, EARTHEN[0])
    a[(YY == base - h + 3) & m & ((XX - x) % 4 == 1)] = OAK[1]


def s_hall(a, rng, x, base, w):
    s_house(a, rng, x, base, w, rng.randint(16, 20))
    ux = x + rng.randint(3, max(4, w // 3))
    s_house(a, rng, ux, base - 18, w // 2, 12)


def s_citadel(a, rng, layout, line):
    cx = MIDDLE + rng.randint(-8, 8)
    w, h = rng.randint(96, 112), rng.randint(40, 50)
    x0 = int(cx - w / 2)
    base = seat(line, x0, x0 + w)
    for side in (-1, 1):
        sv.palm(a, layout * 5 + side, int(cx + side * (w / 2 + 14)), seat(line, cx + side * (w / 2 + 14) - 2,
                cx + side * (w / 2 + 14) + 2) + 1, rng.randint(54, 66), lean=side)
    m = block(a, x0, x0 + w, base, h, EARTHEN, batter=0.1, cap=True)
    inset = int(h * 0.1)
    crenels(a, x0 + inset, x0 + w - inset, base - h + 1, EARTHEN, tooth=3, gap=1, h=4, pointed=True)
    for y in (base - h + 8, base - h + 20):
        for wx in range(x0 + 12, x0 + w - 12, 14):
            lattice(a, wx, y, 5, 5, EARTHEN[0])
    a[(YY == base - h + 4) & m & ((XX - x0) % 4 == 2)] = OAK[1]
    opening(a, int(cx) - 5, base - 14, 11, 15, HOLE, arch=True)
    for tx in (x0 - 6, x0 + w - 12):
        s_tower(a, rng, tx, base, 18, h + rng.randint(16, 24))
    s_house(a, rng, int(cx) - 16, base - h, 32, 14)


def s_curtain(a, rng, x0, x1, base, h=11):
    block(a, x0, x1, base, h, EARTHEN, batter=0.05, cap=True)
    crenels(a, x0, x1, base - h + 1, EARTHEN, tooth=3, gap=1, h=3, pointed=True)
    gx = MIDDLE + rng.randint(-20, 20)
    opening(a, gx - 4, base - 9, 9, 10, HOLE, arch=True)
    lattice(a, gx - 3, base - 7, 7, 7, OAK[0])
    for tx in (x0 - 5, x1 - 9):
        s_tower(a, rng, tx, base, 14, h + rng.randint(12, 16))


def s_village(a, rng, layout, stage):
    if stage != "front":
        return
    for px, lean in ((rng.randint(150, 160), -1), (rng.randint(222, 232), 1)):
        sv.palm(a, px + layout, px, FEET, rng.randint(50, 62), lean=lean)
    if layout in (2, 4):
        hw = rng.randint(34, 42)
        hx = MIDDLE - hw // 2 + rng.randint(-6, 6)
        row(a, rng, 112, hx - 4, flat(), DESERT["houses"])
        row(a, rng, hx + hw + 4, 272, flat(), DESERT["houses"])
        s_hall(a, rng, hx, BASE, hw)
    else:
        row(a, rng, 118, 266, flat(), DESERT["houses"], gap=(3, 10))


DESERT = dict(
    houses=[(1, (18, 28), s_house)],
    talls=[(2, (12, 16), lambda a, rng, x, base, w: s_tower(a, rng, x, base, w)),
           (1, (20, 26), s_house)],
    hall=s_hall, hall_w=(34, 42),
    tower=lambda a, rng, x, base: s_tower(a, rng, x, base, 16, rng.randint(40, 50)), tower_w=16,
    citadel=s_citadel, curtain=s_curtain, village=s_village,
    mound=(rgb("8a4836"), rgb("e69c69")),
)


# ---------------------------------------------------------------- mountains: ashlar, galleries, red cones

def m_house(a, rng, x, base, w, h=None):
    """Warm ashlar under a flat parapet deck, a timber gallery bolted on its upper storey."""
    h = h or rng.randint(18, 24)
    m = block(a, x, x + w - 1, base, h, ASHLAR, cap=True)
    courses(a, m, ASHLAR[2], base, 4, 6)
    crenels(a, x, x + w - 1, base - h + 1, ASHLAR, tooth=2, gap=1, h=2)
    for wx in range(x + 3, x + w - 3, 6):
        opening(a, wx, base - h + 5, 2, 3)
    opening(a, x + w // 2 - 2, base - 7, 4, 8, OAK[2])
    gallery(a, x, x + w - 1, base - int(h * 0.55))


def m_tower(a, rng, x, base, w=14, h=None):
    """The mountain people's signature: a round ashlar tower under a red cone, its pennant flying."""
    h = h or rng.randint(36, 46)
    m = block(a, x, x + w - 1, base, h, ASHLAR)
    courses(a, m, ASHLAR[2], base, 4, 5)
    a[m & (XX == x + w - 2)] = ASHLAR[2]
    for y in range(base - h + 6, base - 8, 9):
        opening(a, x + w // 2, y, 1, 3)
    apex = cone(a, x + (w - 1) / 2, base - h, w / 2 + 1.5, int(w * 1.6), RED)
    pennant(a, int(x + (w - 1) / 2), apex - 1, 8)


def m_hall(a, rng, x, base, w):
    m_house(a, rng, x, base, w, rng.randint(24, 30))
    m_tower(a, rng, x + w - 8 if rng.random() < 0.5 else x - 6, base, 13, rng.randint(40, 48))


def viaduct(a, rng, x_from, x_to, deck, line):
    """The arcade striding off the crag: a level deck on piers, arches between, each pier running
    down to whatever ground is under it."""
    x0, x1 = sorted((int(x_from), int(x_to)))
    m = (XX >= x0) & (XX <= x1) & (YY >= deck) & (YY <= deck + 4)
    span = 16
    for px in range(x0, x1 + 1, span):
        foot = int(line[min(W - 1, max(0, px + 2))]) + 1
        m |= (XX >= px) & (XX <= px + 4) & (YY >= deck) & (YY <= foot)
    for px in range(x0 + 5, x1, span):
        r = (span - 5) / 2
        c = px + r - 0.5
        m |= (XX >= px) & (XX < px + span - 5) & (YY >= deck) & (YY <= deck + 5 + r - np.sqrt(
            np.clip(r * r - (XX - c) ** 2, 0, None)))
    inked(a, m)
    a[m] = ASHLAR[2]
    a[m & ~np.roll(m, 1, axis=1)] = ASHLAR[1]
    a[m & (YY == deck)] = ASHLAR[0]
    courses(a, m, ASHLAR[3], deck, 4, 5)
    crenels(a, x0, x1, deck, ASHLAR, tooth=2, gap=2, h=2)


def m_castle(a, rng, layout, line):
    cx = MIDDLE + rng.randint(-8, 8)
    kw, kh = rng.randint(40, 48), rng.randint(46, 56)
    x0 = int(cx - kw / 2)
    base = seat(line, x0, x0 + kw)
    right = layout % 2 == 1
    viaduct(a, rng, cx + (kw / 2 if right else -kw / 2), W + 4 if right else -4, base - 22, line)
    for side in (-1, 1):
        tx = int(cx + side * rng.uniform(32, 40)) - 7
        m_tower(a, rng, tx, seat(line, tx, tx + 14), 14, rng.randint(52, 64))
    m = block(a, x0, x0 + kw, base, kh, ASHLAR, cap=True)
    courses(a, m, ASHLAR[2], base, 4, 6)
    crenels(a, x0, x0 + kw, base - kh + 1, ASHLAR, tooth=2, gap=2, h=3)
    for y in range(base - kh + 7, base - 12, 10):
        for wx in range(x0 + 5, x0 + kw - 4, 7):
            opening(a, wx, y, 2, 4, arch=True)
    gallery(a, x0, x0 + kw, base - int(kh * 0.45))
    opening(a, int(cx) - 4, base - 11, 9, 12, OAK[2], arch=True)


def m_curtain(a, rng, x0, x1, base, h=12):
    m = block(a, x0, x1, base, h, ASHLAR, cap=True)
    courses(a, m, ASHLAR[2], base, 4, 6)
    crenels(a, x0, x1, base - h + 1, ASHLAR, tooth=2, gap=2, h=3)
    gx = MIDDLE + rng.randint(-20, 20)
    opening(a, gx - 4, base - 10, 9, 11, OAK[2], arch=True)
    for tx in (x0 - 5, x1 - 6):
        m_tower(a, rng, tx, base, 11, h + rng.randint(12, 16))


MOUNTAINS = dict(
    houses=[(1, (22, 30), m_house)],
    talls=[(1, (14, 18), lambda a, rng, x, base, w: m_house(a, rng, x, base, w, rng.randint(28, 36)))],
    hall=m_hall, hall_w=(32, 40),
    tower=lambda a, rng, x, base: m_tower(a, rng, x, base, 14), tower_w=14,
    citadel=m_castle, curtain=m_curtain,
    mound=(rgb("424c6e"), rgb("657392")), rough=12,
)


# ---------------------------------------------------------------- ice: dark logs, upswept snowy eaves, needles

def i_lodge(a, rng, x, base, w, h=None, storeys=1):
    """Dark logs under an upswept roof bowed with snow, a warm light in every opening, icicles
    along the eave."""
    h = h or rng.randint(11, 15)
    m = block(a, x, x + w - 1, base, h, OAK)
    a[m & ((base - YY) % 3 == 2)] = OAK[2]
    a[m & ((base - YY) % 3 == 0) & ((XX == x) | (XX == x + w - 1))] = OAK[0]
    for s in range(storeys):
        y = base - h + 3 + s * (h // storeys)
        for wx in range(x + 3, x + w - 4, 7):
            opening(a, wx, y, 3, 3, glow=GLOW)
    opening(a, x + w // 2 - 2, base - 7, 4, 8, glow=GLOW)
    r, ridge = roof(a, x, x + w - 1, base - h, int(w * 0.32) + 3, SLATE, over=3, ridge=0.3, sweep=2)
    snow_load(a, r)
    icicles(a, x - 2, x + w + 1, base - h, rng)
    return ridge


def needle(a, cx, base, h, half):
    """The ice people's signature: a needle of carved ice, lit on its left."""
    k = base - YY
    hw = half * np.clip(1 - k / h, 0, 1) ** 0.7
    m = (k >= 0) & (k < h) & (np.abs(XX - cx) <= hw)
    inked(a, m)
    a[m] = ICE[2]
    a[m & (XX < cx)] = ICE[1]
    a[m & (XX < cx - hw + 1)] = ICE[0]
    a[m & (XX > cx + hw - 1)] = ICE[3]


def i_tower(a, rng, x, base, w=14, h=None):
    h = h or rng.randint(30, 40)
    m = block(a, x, x + w - 1, base, h, ICE_WALL, cap=True)
    courses(a, m, ICE_WALL[3], base, 5, 7)
    for y in range(base - h + 6, base - 8, 10):
        opening(a, x + w // 2 - 1, y, 3, 4, glow=GLOW, arch=True)
    needle(a, x + (w - 1) / 2, base - h, int(w * 1.8), w / 2 - 1)


def i_hall(a, rng, x, base, w):
    ridge = i_lodge(a, rng, x, base, w, rng.randint(16, 20), storeys=2)
    i_lodge(a, rng, x + w // 4, ridge + 6, w // 2, 8)


def i_citadel(a, rng, layout, line):
    cx = MIDDLE + rng.randint(-8, 8)
    w, h = rng.randint(100, 116), rng.randint(28, 34)
    x0 = int(cx - w / 2)
    base = seat(line, x0, x0 + w)
    for k, nh in ((-0.42, 1.1), (-0.2, 1.5), (0.2, 1.6), (0.42, 1.2)):
        needle(a, cx + k * w, base - h + 4, int(h * nh + rng.randint(4, 12)), rng.uniform(3.5, 5))
    hall_w = rng.randint(40, 48)
    i_hall(a, rng, int(cx - hall_w / 2), base - h, hall_w)
    m = block(a, x0, x0 + w, base, h, ICE_WALL, batter=0.05, cap=True)
    courses(a, m, ICE_WALL[3], base, 5, 8)
    a[m & ((base - YY) % 5 == 0) & ((XX * 3 + YY) % 11 == 0)] = ICE[1]
    crenels(a, x0 + 2, x0 + w - 2, base - h + 1, ICE_WALL, tooth=3, gap=2, h=3)
    opening(a, int(cx) - 5, base - 13, 11, 14, glow=GLOW, arch=True)
    for tx in (x0 - 8, x0 + w - 8):
        i_tower(a, rng, tx, base, 16, h + rng.randint(14, 20))


def i_curtain(a, rng, x0, x1, base, h=12):
    m = block(a, x0, x1, base, h, ICE_WALL, cap=True)
    courses(a, m, ICE_WALL[3], base, 5, 8)
    crenels(a, x0, x1, base - h + 1, ICE_WALL, tooth=3, gap=2, h=3)
    gx = MIDDLE + rng.randint(-20, 20)
    opening(a, gx - 4, base - 10, 9, 11, glow=GLOW, arch=True)
    for nx in (x0 + 2, x1 - 2):
        needle(a, nx, base - h + 2, rng.randint(22, 30), 4)


ICE_PEOPLE = dict(
    houses=[(1, (24, 34), lambda a, rng, x, base, w: i_lodge(a, rng, x, base, w))],
    talls=[(1, (16, 22), lambda a, rng, x, base, w: i_lodge(a, rng, x, base, w, rng.randint(20, 26), 2))],
    hall=i_hall, hall_w=(36, 44),
    tower=lambda a, rng, x, base: i_tower(a, rng, x, base, 14, rng.randint(34, 42)), tower_w=14,
    citadel=i_citadel, curtain=i_curtain,
    mound=(rgb("92a1b9"), rgb("c7cfdd")),
)

PEOPLES = {"grass": GRASS, "dirt": DIRT, "forest": FOREST, "desert": DESERT,
           "mountains": MOUNTAINS, "ice": ICE_PEOPLE}


# ---------------------------------------------------------------- the three scales, shared

def village(P, a, rng, layout, stage):
    """Houses on the fighting ground between the sides; layouts 2 and 4 set the people's hall in
    their middle."""
    if stage != "front":
        return
    if layout in (2, 4):
        hw = rng.randint(*P["hall_w"])
        hx = MIDDLE - hw // 2 + rng.randint(-6, 6)
        row(a, rng, 108, hx - 4, flat(), P["houses"])
        row(a, rng, hx + hw + 4, 276, flat(), P["houses"])
        P["hall"](a, rng, hx, BASE, hw)
    else:
        row(a, rng, 112, 272, flat(), P["houses"], gap=(3, 10))


def town(P, a, rng, layout, stage):
    """A back row of taller houses round the hall and the people's signature tower -- on a hill in
    layouts 2 and 4 -- and in front of it a wall and gate (1 and 3) or a row of houses (2 and 4)."""
    hilly = layout in (2, 4)
    if stage == "back":
        line = mound(a, MIDDLE, 150, rng.uniform(14, 22), *P["mound"], rough=P.get("rough", 0),
                     seed=layout) if hilly else flat()
        hw = rng.randint(*P["hall_w"])
        hx = MIDDLE - hw // 2 + rng.randint(-8, 8)
        if layout in (1, 4):
            tx = hx + hw + 2
            left_end, right_start = hx - 6, tx + P["tower_w"] + 4
        else:
            tx = hx - P["tower_w"] - 2
            left_end, right_start = tx - 4, hx + hw + 6
        row(a, rng, 88, left_end, line, P["talls"], gap=(0, 3))
        row(a, rng, right_start, 296, line, P["talls"], gap=(0, 3))
        P["tower"](a, rng, tx, seat(line, tx, tx + P["tower_w"]))
        P["hall"](a, rng, hx, seat(line, hx, hx + hw), hw)
    elif layout in (1, 3):
        P["curtain"](a, rng, 104, 280, BASE)
    else:
        row(a, rng, 116, 268, flat(), P["houses"], gap=(2, 8))


def fortress(P, a, rng, layout, stage):
    """The people's stronghold on a hill behind the fighting ground, its curtain wall and gate on
    the ground in front."""
    if stage == "back":
        height = rng.uniform(12, 16) if layout == 2 else rng.uniform(28, 38)
        line = mound(a, MIDDLE + rng.randint(-10, 10), rng.uniform(130, 160), height, *P["mound"],
                     rough=P.get("rough", 0), seed=layout)
        P["citadel"](a, rng, layout, line)
    else:
        P["curtain"](a, rng, 100, 284, BASE)


def settle(a, env, variant, layout, seed, stage):
    """Draws `stage` ("back" or "front") of the settlement `variant` in `env`. The rng is seeded
    from the scene alone, so the back and front stages of one scene agree."""
    P = PEOPLES[env]
    rng = random.Random(seed * 31 + (0 if stage == "back" else 1))
    fn = P.get(variant) or {"village": village, "town": town, "fortress": fortress}[variant]
    if fn in (village, town, fortress):
        fn(P, a, rng, layout, stage)
    else:
        fn(a, rng, layout, stage)
