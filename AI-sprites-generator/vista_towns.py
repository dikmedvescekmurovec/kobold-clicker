"""The settlements in the vista backdrops: where one stands, the ground it stands on, and each
people's buildings.

A `Site` is decided before the middle distance is painted, because a town on a hill needs the hill:
`Site.shape(line)` raises the ground under it, and `Site.build(cv, line)` then seats every
building on that same line (`vista.seat`), so a piece's foot is always on the lowest ground under
it. Nothing is placed by a fixed row.
"""
import math
import random

import numpy as np

import vista as v
import vista_build as b
from vista import H, W, mix, rgb, shade


def m4(lit, mid, shd, dark):
    return (rgb(lit), rgb(mid), rgb(shd), rgb(dark))


# ---------------------------------------------------------------- the site

class Site:
    """Where a settlement stands and how big it is. `layout` (1..4) moves it and changes its plan."""

    def __init__(self, env, variant, layout, seed):
        self.env, self.variant, self.layout = env, variant, layout
        self.rng = random.Random(seed * 7919 + layout)
        r = self.rng
        centres = {1: 0.5, 2: 0.47, 3: 0.53, 4: 0.5}
        self.cx = W * centres[layout] + r.uniform(-12, 12)
        if variant == "village":
            self.half, self.mound = r.uniform(70, 100), (0 if layout % 2 else r.uniform(6, 10))
        elif variant == "town":
            self.half = r.uniform(100, 130)
            self.mound = r.uniform(20, 32) if layout in (2, 4) else r.uniform(4, 8)
        elif variant == "fortress":
            self.half = r.uniform(110, 150)
            self.mound = r.uniform(26, 40) if layout != 2 else r.uniform(8, 12)
        else:
            self.half, self.mound = 0, 0

    @property
    def built(self):
        return self.variant in ("village", "town", "fortress")

    def shape(self, line):
        """The ground raised into a broad hill under the settlement."""
        if not self.built or self.mound <= 0:
            return line
        xs = np.arange(W)
        t = (xs - self.cx) / (self.half * 1.25)
        bump = np.where(np.abs(t) < 1, (1 - t * t) ** 1.6, 0)
        return np.minimum(line, line[int(self.cx)] - self.mound * bump)

    def build(self, cv, line, hz, haze=0.1):
        if not self.built:
            return
        before = cv.a.copy()
        _BEFORE[0] = before
        if self.env not in KITS:
            import vista_kits
            KITS.update(vista_kits.KITS)
        KITS[self.env](self, cv, line)
        changed = np.any(cv.a != before, axis=2)
        if haze:
            cv.tint(changed, hz, haze, levels=1)


_BEFORE = [None]


def background():
    """The picture as it was before the settlement went up, for a piece that has to cut back
    into it (a ruin's broken crown)."""
    return _BEFORE[0]


def row(site, cv, line, x0, x1, pieces, gap=(1, 4)):
    """Lays pieces left to right from x0 to x1, each one seated on the line. `pieces` is a list of
    (weight, width range, draw(cv, rng, x, base, w)). Returns the placed (x, w, base)."""
    r = site.rng
    placed = []
    x = x0
    while True:
        tot = sum(p[0] for p in pieces)
        k = r.uniform(0, tot)
        for p in pieces:
            k -= p[0]
            if k <= 0:
                break
        w = r.randint(*p[1])
        if x + w > x1:
            break
        placed.append((x, w, p[2]))
        x += w + r.randint(*gap)
    out = []
    # the higher on the hill, the further back: draw those first
    for (x, w, fn) in sorted(placed, key=lambda q: v.seat(line, q[0], q[0] + q[1])):
        base = v.seat(line, x, x + w - 1) + 1
        fn(cv, r, x, base, w)
        out.append((x, w, base))
    return out


def trees_between(site, cv, line, x0, x1, count, pal, trunk=None, kind="round"):
    r = site.rng
    for _ in range(count):
        x = r.uniform(x0, x1)
        base = int(line[int(min(W - 1, max(0, x)))]) + 1
        if kind == "fir":
            v.conifer(cv, int(x), base, r.randint(8, 14), pal)
        else:
            v.broadleaf(cv, r, x, base, r.uniform(3, 5.5), pal, trunk=trunk)


# ---------------------------------------------------------------- grass: timber and plaster, slate cones

G_PLASTER = m4("fbf3de", "eadcb8", "c9b48e", "6e5040")
G_OAK = rgb("5c3b2a")
G_TILE = m4("f2a070", "d2683f", "a24a30", "5a2a22")
G_SLATE = m4("8e98b6", "626c8a", "474e6a", "2a2e42")
G_STONE = m4("ece6d4", "d0c8b2", "aca28c", "5e5648")
G_GLASS = rgb("3c3a4e")
G_TREE = (rgb("7cc257"), rgb("4c9a3c"), rgb("2f6b35"))
G_TRUNK = rgb("5a4432")
PENNANT = (rgb("4a3a30"), rgb("d8453a"))


def g_cottage(cv, r, x, base, w):
    h = r.randint(8, 11)
    b.wall(cv, x, base, w, h, G_PLASTER)
    b.timber(cv, x, base, w, h, G_OAK, step=r.choice((4, 5)), braces=r.random() < 0.6)
    b.windows(cv, x + 2, x + w - 3, base - h + 3, 3, G_GLASS, step=r.choice((4, 5)), w=2)
    b.door(cv, x + w // 2 + r.randint(-2, 2), base, 3, 5, G_OAK, arch=False)
    roof = G_TILE if r.random() < 0.75 else G_SLATE
    rh = max(5, int(w * 0.5))
    top = b.gable(cv, x, base - h, w, rh, roof, over=1, slope=0.9)
    if r.random() < 0.6:
        cx = x + r.randint(3, w - 5)
        b.rect(cv, cx, top + 1, cx + 1, top + 4, G_STONE[2])
        b.P(cv, cx, top + 1, G_STONE[0])


def g_townhouse(cv, r, x, base, w):
    """A tall gable-front house: two or three storeys under a steep front gable."""
    h = r.randint(15, 21)
    b.wall(cv, x, base, w, h, G_PLASTER)
    b.timber(cv, x, base, w, h, G_OAK, step=r.choice((3, 4)), braces=True)
    for k in range(2, h - 2, 5):
        b.windows(cv, x + 1, x + w - 2, base - h + 1 + k, 2, G_GLASS, step=3)
    b.door(cv, x + w // 2, base, 2, 3, G_OAK, arch=False)
    rh = int(w * 0.8) + 2
    roof = G_TILE if r.random() < 0.6 else G_SLATE
    cx = x + (w - 1) / 2
    b.pediment(cv, int(round(cx)), base - h + 1, w // 2 + 1, rh, roof, face=G_PLASTER[1])
    b.P(cv, int(round(cx)), base - h - rh // 2, G_GLASS)


def g_turret(cv, r, x, base, w, h=None):
    """The signature: a round stair-turret in limestone under a tall slate cone and a pennant."""
    h = h or r.randint(20, 30)
    b.wall(cv, x, base, w, h, G_STONE)
    # roundness: a lit band and a shaded band down the shaft
    for y in range(base - h + 1, base + 1):
        b.P(cv, x + 1, y, G_STONE[0])
        b.P(cv, x + w - 2, y, G_STONE[2])
    for k in range(4, h - 3, 6):
        b.P(cv, x + w // 2, base - h + 1 + k, G_GLASS)
        b.P(cv, x + w // 2, base - h + 2 + k, G_GLASS)
    b.cone(cv, x + (w - 1) / 2, base - h + 1, w / 2 + 1, int(w * 2.2), G_SLATE,
           pennant=PENNANT if r.random() < 0.8 else None)


def g_hall(cv, r, x, base, w):
    """A stone hall or chapel with a steep slate roof, and a turret at one end."""
    h = r.randint(10, 13)
    b.wall(cv, x, base, w, h, G_STONE, courses=3)
    b.windows(cv, x + 3, x + w - 4, base - h + 4, 4, G_GLASS, step=4, w=1)
    b.door(cv, x + w // 2, base, 3, 5, G_GLASS)
    b.gable(cv, x, base - h, w, int(w * 0.45), G_SLATE, over=1, slope=1.0)
    tx = x - 2 if r.random() < 0.5 else x + w - 5
    g_turret(cv, r, tx, base, 7, h + r.randint(10, 16))


def g_wall(cv, x0, x1, base_line, h, gate=None):
    """A curtain along the ground with square merlons, towers at its ends, and a gate."""
    for x in range(int(x0), int(x1) + 1):
        base = int(base_line[min(W - 1, max(0, x))]) + 2
        for y in range(base - h + 1, base + 1):
            c = G_STONE[1]
            if x == int(x0):
                c = G_STONE[0]
            if (base - y) % 3 == 2 and (x + y // 3 * 2) % 5:
                c = G_STONE[2]
            b.P(cv, x, y, c)
        if (x - int(x0)) % 3 == 0:
            b.P(cv, x, base - h, G_STONE[0])
            b.P(cv, x + 1, base - h, G_STONE[1])
        b.P(cv, x, base - h + 1, G_STONE[2] if (x - int(x0)) % 3 == 2 else G_STONE[1])
    if gate is not None:
        base = int(base_line[int(gate)]) + 2
        b.door(cv, gate, base, 5, 7, rgb("2e2a36"))


def g_keep(cv, r, cx, base, w, h):
    x = int(cx - w / 2)
    b.wall(cv, x, base, w, h, G_STONE, courses=4)
    for row_y in range(base - h + 6, base - 8, 8):
        b.windows(cv, x + 4, x + w - 5, row_y, 3, G_GLASS, step=5, w=1)
    b.door(cv, cx, base, 5, 8, rgb("2e2a36"))
    # corbelled parapet then a steep slate roof with dormers
    b.hline(cv, x - 1, x + w, base - h, G_STONE[3])
    b.crenels(cv, x - 1, x + w, base - h, 2, G_STONE)
    top = b.gable(cv, x + 3, base - h - 2, w - 6, int(w * 0.42), G_SLATE, over=0, slope=1.0)
    for dx in (w // 3, 2 * w // 3):
        b.P(cv, x + dx, base - h - 6, rgb("fbe7a0"))
    # corner turrets corbelled out over the parapet
    for tx in (x - 3, x + w - 4):
        b.wall(cv, tx, base - h + 4, 7, 12, G_STONE)
        b.cone(cv, tx + 3, base - h - 7, 4.5, 15, G_SLATE, pennant=PENNANT)


def grass_kit(site, cv, line):
    s, r = site, site.rng
    x0, x1 = int(s.cx - s.half), int(s.cx + s.half)
    if s.variant == "village":
        trees_between(s, cv, line, x0 - 20, x1 + 20, 5, G_TREE, G_TRUNK)
        pieces = [(5, (15, 21), g_cottage), (2, (9, 12), g_townhouse)]
        row(s, cv, line, x0, x1, pieces, gap=(3, 10))
        if s.layout in (2, 4):
            g_hall(cv, r, int(s.cx) - 10, v.seat(line, s.cx - 10, s.cx + 12) + 1, 22)
        trees_between(s, cv, line, x0, x1, 4, G_TREE, G_TRUNK)
    elif s.variant == "town":
        # the back row stands higher up the hill, the front row along its foot
        back = [(3, (9, 12), g_townhouse), (1, (14, 18), g_cottage)]
        row(s, cv, line, int(s.cx - s.half * 0.55), int(s.cx + s.half * 0.55), back, gap=(0, 2))
        g_hall(cv, r, int(s.cx) - 12, v.seat(line, s.cx - 12, s.cx + 14) - int(s.mound * 0.5), 26)
        walled = s.layout in (1, 3)
        front = [(3, (9, 12), g_townhouse)] + ([] if walled else [(2, (14, 18), g_cottage)])
        row(s, cv, line + 4, x0, x1, front, gap=(0, 3))
        if walled:
            g_wall(cv, x0 - 6, x1 + 6, line + 6, 7, gate=s.cx + r.randint(-30, 30))
            for tx in (x0 - 10, x1 + 2):
                g_turret(cv, r, tx, int(line[min(W - 1, max(0, tx + 4))]) + 8, 8, 18)
    else:
        # the keep on the crown of the hill, turrets stepping down, a curtain round the foot
        top = int(line[int(s.cx)]) + 3
        kw, kh = r.randint(36, 44), r.randint(42, 52)
        for side in (-1, 1):
            tx = int(s.cx + side * r.uniform(34, 52))
            g_turret(cv, r, tx - 5, v.seat(line, tx - 5, tx + 5) + 1, 10, r.randint(50, 66))
        g_keep(cv, r, s.cx, top, kw, kh)
        for side in (-1, 1):
            hx = int(s.cx + side * r.uniform(24, 36)) - 6
            g_hall(cv, r, hx, v.seat(line, hx, hx + 16) + 1, 16)
        g_wall(cv, x0, x1, line + 3, 11, gate=s.cx)
        for tx in (x0 - 4, x1 - 3, int(s.cx - s.half * 0.5), int(s.cx + s.half * 0.5)):
            g_turret(cv, r, tx, int(line[min(W - 1, max(0, tx + 4))]) + 6, 9, 22)
        trees_between(s, cv, line + 8, x0 - 30, x1 + 30, 6, G_TREE, G_TRUNK)


KITS = {"grass": grass_kit}
