"""Five of the six peoples' buildings for the vista settlements (grass lives in vista_towns.py,
where the site and the placer are). Each kit keeps its culture's wall, roof and signature, and no
two share any of the three -- see the README's *Battle backdrops*."""
import random

import vista as v
import vista_build as b
from vista import H, W, rgb
from vista_towns import m4, row, trees_between, PENNANT, background


# ---------------------------------------------------------------- dirt: daub, thatch cones, rubble

D_DAUB = m4("d49a66", "b07a4c", "88583a", "4a3026")
D_THATCH = m4("f4d080", "d4a458", "a67a3c", "5a4028")
D_RUBBLE = m4("d0a47c", "a87e5a", "80593e", "46302a")
D_POLE = rgb("4a3222")
D_DARK = rgb("2e2224")
D_SHRUB = (rgb("a8a05a"), rgb("7c7a44"), rgb("545634"))


def d_hut(cv, r, x, base, w):
    h = r.randint(6, 8)
    b.wall(cv, x + 1, base, w - 2, h, D_DAUB, rough=0.15)
    b.door(cv, x + w // 2, base, 3, 4, D_DARK)
    tip = b.cone(cv, x + (w - 1) / 2, base - h + 1, w / 2 + 1.5, int(w * 0.72), D_THATCH)
    # the crossed poles over the apex
    cx = int(x + (w - 1) / 2)
    for k in range(1, 4):
        b.P(cv, cx - k, tip - k + 2, D_POLE)
        b.P(cv, cx + k, tip - k + 2, D_POLE)
    for xx in range(x - 1, x + w + 1, 2):
        b.P(cv, xx, base - h + 1, D_THATCH[2])


def d_house(cv, r, x, base, w):
    """A flat-roofed rubble house, crenellated, with grouped lancets."""
    h = r.randint(9, 13)
    b.wall(cv, x, base, w, h, D_RUBBLE, courses=3, rough=0.2)
    b.crenels(cv, x, x + w - 1, base - h + 1, 2, D_RUBBLE, step=3)
    b.lancets(cv, x + w // 2, base - h + 4, 3, D_DARK, n=3 if w > 9 else 2)
    b.door(cv, x + 2 + r.randint(0, max(0, w - 6)), base, 2, 3, D_DARK)


def d_tower(cv, r, x, base, w, h=None):
    h = h or r.randint(22, 32)
    b.wall(cv, x, base, w, h, D_RUBBLE, courses=3, rough=0.25, batter=0.03)
    b.crenels(cv, x, x + w - 1, base - h + 1, 3, D_RUBBLE, step=3)
    for k in range(5, h - 4, 9):
        b.lancets(cv, x + w // 2, base - h + k, 3, D_DARK, n=2 if w < 9 else 3)


def d_keep(cv, r, cx, base, w, h):
    """The grimmest of them: a box with its top taken off. Two squat corner towers stand a
    little proud of it, the crown between them is broken down in a ragged bite, and the top
    storey's windows are empty holes onto the sky; below, only arrow slits."""
    x = int(cx - w / 2)
    bg = background()
    b.wall(cv, x, base, w, h, D_RUBBLE, courses=4, rough=0.3)
    # buttressing corner towers, a little taller, their tops ragged too
    for tx in (x - 3, x + w - 6):
        th = h + r.randint(4, 8)
        b.wall(cv, tx, base, 9, th, D_RUBBLE, courses=4, rough=0.3)
        for i in range(9):
            for d in range(r.randint(0, 3)):
                yy = base - th + 1 + d
                if 0 <= yy < H and 0 <= tx + i < W:
                    cv.a[yy, tx + i] = bg[yy, tx + i]
        for k2 in range(10, th - 6, 10):
            b.P(cv, tx + 4, base - th + k2, D_DARK)
            b.P(cv, tx + 4, base - th + k2 + 1, D_DARK)
            b.P(cv, tx + 4, base - th + k2 + 2, D_DARK)
    # the broken crown: a bite taken out of the middle of the wall's top
    y0 = base - h + 1
    for i in range(6, w - 6):
        u = (i - 6) / max(1, w - 13)
        depth = int(4 + 14 * (1 - abs(2 * u - 1)) ** 0.7 + r.randint(-2, 2))
        for d in range(depth):
            yy = y0 + d
            if 0 <= yy < H and 0 <= x + i < W:
                cv.a[yy, x + i] = bg[yy, x + i]
        b.P(cv, x + i, y0 + depth, D_RUBBLE[0])
    # the top storey's empty windows, sky showing through
    for k2 in range(3):
        wx = x + 8 + k2 * (w - 18) // 2
        wy = y0 + 20
        for yy in range(wy, wy + 7):
            for xx in range(wx, wx + 4):
                if 0 <= yy < H and 0 <= xx < W:
                    cv.a[yy, xx] = bg[yy, xx]
        b.hline(cv, wx, wx + 3, wy + 7, D_RUBBLE[3])
    for row_y in range(y0 + 34, base - 8, 10):
        for k2 in range(4):
            sx = x + 6 + k2 * (w - 12) // 3
            for d in range(4):
                b.P(cv, sx, row_y + d, D_DARK)
    b.door(cv, cx, base, 6, 10, D_DARK)


def d_palisade(cv, x0, x1, line, h):
    for x in range(int(x0), int(x1) + 1):
        base = int(line[min(W - 1, max(0, x))]) + 2
        hh = h + (1 if x % 2 else 0)
        for y in range(base - hh + 1, base + 1):
            b.P(cv, x, y, D_POLE if x % 2 else D_DAUB[2])
        b.P(cv, x, base - hh, D_DAUB[0] if x % 2 == 0 else D_POLE)


def dirt_kit(site, cv, line):
    s, r = site, site.rng
    x0, x1 = int(s.cx - s.half), int(s.cx + s.half)
    if s.variant == "village":
        trees_between(s, cv, line, x0 - 20, x1 + 20, 5, D_SHRUB)
        row(s, cv, line, x0, x1, [(1, (16, 22), d_hut)], gap=(1, 8))
        if s.layout in (2, 4):
            d_palisade(cv, x0 - 8, x1 + 8, line + 4, 4)
    elif s.variant == "town":
        row(s, cv, line, int(s.cx - s.half * 0.6), int(s.cx + s.half * 0.6),
            [(2, (9, 13), d_house), (1, (12, 16), d_hut)], gap=(0, 2))
        d_tower(cv, r, int(s.cx) - 5, v.seat(line, s.cx - 5, s.cx + 5) + 1, 11)
        row(s, cv, line + 4, x0, x1, [(1, (13, 18), d_hut), (1, (9, 12), d_house)], gap=(0, 4))
        if s.layout in (1, 3):
            d_palisade(cv, x0 - 8, x1 + 8, line + 7, 5)
    else:
        top = int(line[int(s.cx)]) + 3
        for side in (-1, 1):
            tx = int(s.cx + side * r.uniform(30, 44))
            d_tower(cv, r, tx - 5, v.seat(line, tx - 5, tx + 5) + 1, 11, r.randint(34, 46))
        d_keep(cv, r, s.cx, top, r.randint(46, 56), r.randint(62, 74))
        # a low curtain of rubble round the foot, crenellated, with a squat gate tower
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            base = int(line[x]) + 4
            for y in range(base - 8, base + 1):
                c = D_RUBBLE[1]
                if (base - y) % 3 == 2 and (x + (base - y) // 3 * 3) % 7 < 5:
                    c = D_RUBBLE[2]
                b.P(cv, x, y, c)
            b.P(cv, x, base - 8, D_RUBBLE[0])
            if (x - x0) % 4 < 2:
                b.P(cv, x, base - 9, D_RUBBLE[0])
                b.P(cv, x, base - 10, D_RUBBLE[1])
        d_tower(cv, r, int(s.cx) - 7, int(line[int(s.cx)]) + 6, 14, 18)
        row(s, cv, line + 14, x0 - 40, x0 + 10, [(1, (12, 16), d_hut)], gap=(1, 4))
        row(s, cv, line + 14, x1 - 10, x1 + 40, [(1, (12, 16), d_hut)], gap=(1, 4))


# ---------------------------------------------------------------- forest: posts on mossy stone, meru

F_THATCH = m4("7a6c5c", "524538", "3a3129", "201a18")
F_TIMBER = m4("b07a50", "8a5a3a", "683f2a", "3a2418")
F_STONE = m4("c2c4a6", "9c9e84", "767a62", "3c4034")
F_MOSS = rgb("6a8a4a")
F_GOLD = rgb("e8c060")
F_DARK = rgb("241e1c")
F_TREE = (rgb("5f9e4a"), rgb("3e7a3c"), rgb("275331"))


def f_plinth(cv, r, x, base, w, h):
    b.wall(cv, x, base, w, h, F_STONE, courses=2)
    for _ in range(max(1, w // 4)):
        b.P(cv, r.randint(x, x + w - 1), base - r.randint(0, h - 1), F_MOSS)
        b.P(cv, r.randint(x, x + w - 1), base - h + 1, F_MOSS)


def f_house(cv, r, x, base, w):
    """A timber house on posts over a mossy stone footing, under a steep dark thatch whose
    ridge carries a gold finial."""
    f_plinth(cv, r, x, base, w, 2)
    posts = base - 2
    for px_ in (x + 1, x + w // 2, x + w - 2):
        for k in range(3):
            b.P(cv, px_, posts - k, F_TIMBER[2])
    body = posts - 3
    h = r.randint(6, 9)
    b.wall(cv, x + 1, body, w - 2, h, F_TIMBER)
    b.windows(cv, x + 3, x + w - 4, body - h + 3, 2, F_DARK, step=4)
    rh = int(w * 0.62)
    top = b.gable(cv, x + 1, body - h + 1, w - 2, rh, F_THATCH, over=2, slope=1.2)
    cx = x + w // 2
    for k in range(1, 4):
        b.P(cv, cx, top - k + 1, F_GOLD)


def f_meru(cv, r, x, base, w, n=None):
    """The signature: a stone base under a stack of receding thatch tiers, a gold finial on top."""
    n = n or r.randint(3, 7)
    f_plinth(cv, r, x, base, w, 4)
    cx = x + (w - 1) / 2
    b.rect(cv, int(cx) - 2, base - 7, int(cx) + 2, base - 4, F_TIMBER[1])
    b.tiers(cv, cx, base - 7, w / 2 + 1, n, 3, F_THATCH, step=max(0.7, w / 2 / (n + 1)),
            finial=F_GOLD, post=F_TIMBER[2], gap=2)


def f_gate(cv, r, cx, base, half, h):
    """A split gate: two stepped stone towers, mirror halves with the sky between them."""
    for side in (-1, 1):
        for k in range(5):
            w = half - k
            if w < 2:
                break
            y1 = base - k * (h // 5)
            y0 = y1 - h // 5 + 1
            xa = int(cx + 2) if side > 0 else int(cx - 2 - w + 1)
            b.rect(cv, xa, y0, xa + w - 1, y1, F_STONE[1] if side < 0 else F_STONE[2])
            b.hline(cv, xa, xa + w - 1, y0, F_STONE[0])
        b.P(cv, int(cx + side * 3), base - h, F_GOLD)


def forest_kit(site, cv, line):
    s, r = site, site.rng
    x0, x1 = int(s.cx - s.half), int(s.cx + s.half)
    if s.variant == "village":
        row(s, cv, line, x0, x1, [(4, (15, 20), f_house), (1, (11, 14), f_meru)], gap=(2, 9))
        trees_between(s, cv, line, x0 - 10, x1 + 10, 4, F_TREE)
    elif s.variant == "town":
        row(s, cv, line, int(s.cx - s.half * 0.6), int(s.cx + s.half * 0.6),
            [(2, (12, 15), f_house), (2, (10, 14), f_meru)], gap=(1, 3))
        f_meru(cv, r, int(s.cx) - 8, v.seat(line, s.cx - 8, s.cx + 8) + 1, 17, 9)
        row(s, cv, line + 4, x0, x1, [(3, (12, 16), f_house), (1, (9, 12), f_meru)], gap=(1, 5))
        if s.layout in (1, 3):
            f_gate(cv, r, s.cx + r.choice((-1, 1)) * (s.half + 12), int(line[int(s.cx)]) + 8, 7,
                   26)
    else:
        # a temple on stepped terraces: the tallest meru at the centre, lesser ones stepping down
        foot = int(line[int(s.cx)]) + 14
        levels = ((s.half * 0.95, 10), (s.half * 0.72, 10), (s.half * 0.48, 10), (s.half * 0.26, 9))
        y = foot
        for hw, hh in levels:
            xa = int(s.cx - hw)
            f_plinth(cv, r, xa, y, int(hw * 2), hh)
            y -= hh
        for side in (-1, 1):
            for j, off in enumerate((0.8, 0.57)):
                w = 11 + j * 2
                mx = int(s.cx + side * s.half * off) - w // 2
                f_meru(cv, r, mx, foot - 10 * (j + 1), w, 5 + j * 2)
        f_meru(cv, r, int(s.cx) - 13, y, 27, 13)
        for side in (-1, 1):
            gx = s.cx + side * (s.half + 14)
            f_gate(cv, r, gx, int(line[int(min(W - 1, max(0, gx)))]) + 4, 7, 30)


# ---------------------------------------------------------------- desert: rammed earth, teeth

S_EARTH = m4("eeaa74", "cf7f52", "a65c3c", "5e3026")
S_DARK = rgb("3a2020")
S_TRUNK = m4("b08860", "8a6440", "6a4a30", "3a2818")
S_LEAF = (rgb("8ab85a"), rgb("5a8c42"), rgb("3e6636"))


def s_cube(cv, r, x, base, w, h=None):
    h = h or r.randint(8, 13)
    b.wall(cv, x, base, w, h, S_EARTH, batter=0.06)
    b.crenels(cv, x + 1, x + w - 2, base - h + 1, 1, S_EARTH, step=2, teeth=True)
    for k in range(3, h - 2, 5):
        b.windows(cv, x + 2, x + w - 3, base - h + 1 + k, 2, S_DARK, step=4)


def s_tower(cv, r, x, base, w, h=None):
    """A battered tower with toothed merlons and an incised lattice band under its crown."""
    h = h or r.randint(26, 38)
    b.wall(cv, x, base, w, h, S_EARTH, batter=0.05)
    inset = int(h * 0.05)
    y = base - h + 5
    for i in range(x + inset + 1, x + w - inset - 1):
        b.P(cv, i, y + (i % 2), S_EARTH[2])
        b.P(cv, i, y + 2 - (i % 2), S_EARTH[2])
    b.crenels(cv, x + inset, x + w - 1 - inset, base - h + 1, 2, S_EARTH, step=2, teeth=True)
    b.P(cv, x + w // 2, base - h + 10, S_DARK)
    b.P(cv, x + w // 2, base - h + 11, S_DARK)


def s_palms(site, cv, line, x0, x1, n):
    for _ in range(n):
        x = site.rng.uniform(x0, x1)
        b.palm(cv, site.rng, int(x), int(line[int(min(W - 1, max(0, x)))]) + 3,
               site.rng.randint(9, 15), S_TRUNK, S_LEAF)


def desert_kit(site, cv, line):
    s, r = site, site.rng
    x0, x1 = int(s.cx - s.half), int(s.cx + s.half)
    if s.variant == "village":
        s_palms(s, cv, line, x0 - 10, x1 + 10, 5)
        row(s, cv, line, x0, x1, [(1, (12, 17), s_cube)], gap=(1, 7))
        s_palms(s, cv, line + 4, x0, x1, 4)
    elif s.variant == "town":
        # a ksar climbing its rock: rows of cubes, higher ones further back
        for k in range(4):
            span = s.half * (0.9 - k * 0.18)
            row(s, cv, line - k * 7, int(s.cx - span), int(s.cx + span), [(1, (8, 12), s_cube)],
                gap=(0, 1))
        tx = int(s.cx) + r.randint(-20, 20)
        s_tower(cv, r, tx, v.seat(line, tx, tx + 9) - 20, 9)
        s_palms(s, cv, line + 5, x0 - 10, x1 + 10, 8)
    else:
        top = int(line[int(s.cx)]) + 4
        row(s, cv, line - 6, int(s.cx - s.half * 0.6), int(s.cx + s.half * 0.6),
            [(1, (10, 14), s_cube)], gap=(0, 1))
        s_tower(cv, r, int(s.cx) - 9, top, 18, r.randint(80, 96))
        for side in (-1, 1):
            tx = int(s.cx + side * s.half * 0.4) - 5
            s_tower(cv, r, tx, v.seat(line, tx, tx + 10) + 1, 10, r.randint(36, 46))
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            base = int(line[x]) + 4
            for y in range(base - 12, base + 1):
                b.P(cv, x, y, S_EARTH[0] if x == x0 else S_EARTH[1])
            if x % 2 == 0:
                b.P(cv, x, base - 13, S_EARTH[1])
                b.P(cv, x, base - 14, S_EARTH[0])
        for tx in (x0 - 5, x1 - 5, int(s.cx) - 6):
            s_tower(cv, r, tx, int(line[min(W - 1, max(0, tx + 5))]) + 5, 11, 22)
        b.door(cv, s.cx, int(line[int(s.cx)]) + 5, 5, 9, S_DARK)
        s_palms(s, cv, line + 7, x0 - 30, x1 + 30, 10)


# ---------------------------------------------------------------- mountains: ashlar, galleries, red cones

M_ASHLAR = m4("f4e2bc", "d9c29a", "b09a76", "5e4e3a")
M_TIMBER = m4("9a6a44", "74482c", "54321e", "2e1c14")
M_RED = m4("f4886a", "d44a3a", "a2362e", "5a1e1e")
M_DARK = rgb("2c2630")
M_FIR = (rgb("4f8a5a"), rgb("2f6444"), rgb("1f4838"))


def m_house(cv, r, x, base, w, h=None):
    """An ashlar block with a timber gallery bolted on under its flat parapet deck."""
    h = h or r.randint(11, 16)
    b.wall(cv, x, base, w, h, M_ASHLAR, courses=3)
    gy = base - h + 3
    b.rect(cv, x - 1, gy, x + w, gy + 2, M_TIMBER[1])
    b.hline(cv, x - 1, x + w, gy, M_TIMBER[0])
    for px_ in range(x, x + w + 1, 3):
        b.P(cv, px_, gy + 3, M_TIMBER[2])
    b.hline(cv, x - 1, x + w, gy + 3, M_TIMBER[3])
    b.windows(cv, x + 2, x + w - 3, gy + 6, 2, M_DARK, step=4)
    b.hline(cv, x - 1, x + w, base - h, M_ASHLAR[0])
    b.hline(cv, x - 1, x + w, base - h - 1, M_ASHLAR[1])
    b.P(cv, x + w, base - h - 1, M_ASHLAR[3])


def m_tower(cv, r, x, base, w, h=None):
    """The signature: a tall ashlar tower under a red cone and a pennant."""
    h = h or r.randint(26, 36)
    b.wall(cv, x, base, w, h, M_ASHLAR, courses=3)
    for k in range(5, h - 4, 7):
        b.P(cv, x + w // 2, base - h + k, M_DARK)
        b.P(cv, x + w // 2, base - h + k + 1, M_DARK)
    b.cone(cv, x + (w - 1) / 2, base - h + 1, w / 2 + 1.5, int(w * 1.4) + 2, M_RED,
           pennant=PENNANT)


def m_viaduct(cv, x0, x1, deck, line, span=8):
    """An arcaded viaduct: a level deck at row `deck` from x0 to x1, carried on piers down to
    the ground wherever the land falls away beneath it -- so its arches grow taller as it
    strides off the hill, and it is only ever as tall as the drop it crosses."""
    bg = background()
    xs = range(max(0, int(x0)), min(W - 1, int(x1)) + 1)
    for x in xs:
        base = int(line[x]) + 2
        if base <= deck + 3:
            continue
        for y in range(deck, base + 1):
            c = M_ASHLAR[1] if (y - deck) % 3 else M_ASHLAR[2]
            b.P(cv, x, y, c)
        b.P(cv, x, deck, M_ASHLAR[0])
        b.P(cv, x, deck + 1, M_ASHLAR[0])
        b.P(cv, x, deck + 3, M_ASHLAR[3])
        if x % 3 == 0:
            b.P(cv, x, deck - 1, M_ASHLAR[1])
    # the arches: each opening's crown three rows under the deck, its sides down to the ground
    x = int(x0) + 3
    while x + span < x1:
        r = span / 2
        cx = x + r - 0.5
        for xx in range(x, x + span):
            if not 0 <= xx < W:
                continue
            base = int(line[xx]) + 2
            if base - deck < 9:
                continue
            dx = (xx - cx) / r
            rise = r * (1 - dx * dx) ** 0.5
            for y in range(int(deck + 4 + r - rise), base + 1):
                b.P(cv, xx, y, bg[y, xx])
        x += span + 3


def mountains_kit(site, cv, line):
    s, r = site, site.rng
    x0, x1 = int(s.cx - s.half), int(s.cx + s.half)
    if s.variant == "village":
        trees_between(s, cv, line, x0 - 20, x1 + 20, 6, M_FIR, kind="fir")
        row(s, cv, line, x0, x1, [(4, (14, 18), m_house), (1, (8, 10), m_tower)], gap=(2, 10))
    elif s.variant == "town":
        for k in range(3):
            span = s.half * (0.85 - k * 0.22)
            row(s, cv, line - k * 9, int(s.cx - span), int(s.cx + span),
                [(4, (10, 14), m_house), (1, (7, 9), m_tower)], gap=(0, 2))
        if s.layout in (2, 4):
            deck = int(line[int(s.cx)]) + 6
            if s.layout == 2:
                m_viaduct(cv, s.cx + s.half * 0.6, W + 10, deck, line)
            else:
                m_viaduct(cv, -10, s.cx - s.half * 0.6, deck, line)
        trees_between(s, cv, line + 6, x0 - 30, x1 + 30, 6, M_FIR, kind="fir")
    else:
        top = int(line[int(s.cx)]) + 3
        for side in (-1, 1):
            for j, off in enumerate((0.75, 0.5, 0.25)):
                tx = int(s.cx + side * s.half * off) - 5
                m_tower(cv, r, tx, v.seat(line, tx, tx + 10) + 1, 8 + j,
                        r.randint(26, 36) + j * 8)
        m_house(cv, r, int(s.cx) - 22, top, 44, 30)
        m_tower(cv, r, int(s.cx) - 8, top - 24, 16, r.randint(50, 60))
        # the approach: a viaduct striding off the hill toward one edge of the frame
        deck = int(line[int(s.cx + (1 if s.layout % 2 else -1) * s.half * 0.55)]) + 2
        if s.layout % 2:
            m_viaduct(cv, s.cx + s.half * 0.55, W + 10, deck, line, span=9)
        else:
            m_viaduct(cv, -10, s.cx - s.half * 0.55, deck, line, span=9)
        trees_between(s, cv, line + 12, x0 - 50, x1 + 50, 8, M_FIR, kind="fir")


# ---------------------------------------------------------------- ice: dark timber, snow loads, warm light

I_TIMBER = m4("6e6078", "4c405a", "362c44", "1e1828")
I_ROOF = m4("5a5270", "3e3654", "2c263e", "18141e")
I_SNOW = (rgb("fbf2f6"), rgb("c4bce0"))
I_ICE = m4("eef8ff", "b4dcf4", "7eaedc", "3a5c94")
I_LIGHT = rgb("ffc860")
I_LIGHT_DK = rgb("e08a3a")
I_FIR = (rgb("4a5a86"), rgb("323e68"), rgb("222a4c"))


def i_house(cv, r, x, base, w):
    h = r.randint(8, 11)
    b.wall(cv, x, base, w, h, I_TIMBER)
    for xx in range(x + 2, x + w - 2, 3):
        b.P(cv, xx, base - h + 1, I_TIMBER[2])
    b.windows(cv, x + 2, x + w - 3, base - h + 3, 2, I_LIGHT, step=4, w=2)
    b.door(cv, x + w // 2, base, 2, 4, I_LIGHT_DK, arch=False)
    rh = max(5, int(w * 0.5))
    b.gable(cv, x, base - h, w, rh, I_ROOF, over=2, slope=1.0, upswept=2, snow=I_SNOW)


def i_hall(cv, r, x, base, w):
    """A long hall: tall timber walls, a double roof of upswept eaves, every opening lit."""
    h = r.randint(10, 13)
    b.wall(cv, x, base, w, h, I_TIMBER)
    b.windows(cv, x + 2, x + w - 3, base - h + 3, 3, I_LIGHT, step=4, w=2)
    b.door(cv, x + w // 2, base, 4, 6, I_LIGHT_DK)
    top = b.gable(cv, x, base - h, w, 5, I_ROOF, over=3, slope=1.0, upswept=3, snow=I_SNOW)
    b.wall(cv, x + 4, top, w - 8, 4, I_TIMBER)
    b.windows(cv, x + 6, x + w - 7, top - 2, 1, I_LIGHT, step=3, w=1)
    b.gable(cv, x + 4, top - 4, w - 8, int((w - 8) * 0.45), I_ROOF, over=2, slope=1.0,
            upswept=2, snow=I_SNOW)


def i_needle(cv, r, cx, base, half, h):
    """A spire of carved ice: a slender cone, ribbed, with warm slits up its shaft."""
    for k in range(h):
        y = base - k
        u = k / h
        hw = half * (1 - u) ** 0.8
        a, bb = int(round(cx - hw)), int(round(cx + hw))
        b.hline(cv, a, bb, y, I_ICE[1])
        b.hline(cv, a, int(cx) - 1, y, I_ICE[0])
        b.hline(cv, int(cx) + int(hw * 0.4) + 1, bb, y, I_ICE[2])
        b.P(cv, bb, y, I_ICE[3])
        if k % 7 == 0 and hw > 2:
            b.hline(cv, a, bb, y, I_ICE[2])
    for k in range(8, int(h * 0.6), 9):
        b.P(cv, int(cx), base - k, I_LIGHT)
        b.P(cv, int(cx), base - k - 1, I_LIGHT)


def ice_kit(site, cv, line):
    s, r = site, site.rng
    x0, x1 = int(s.cx - s.half), int(s.cx + s.half)
    if s.variant == "village":
        trees_between(s, cv, line, x0 - 20, x1 + 20, 6, I_FIR, kind="fir")
        row(s, cv, line, x0, x1, [(1, (15, 20), i_house)], gap=(2, 9))
    elif s.variant == "town":
        row(s, cv, line, int(s.cx - s.half * 0.6), int(s.cx + s.half * 0.6),
            [(2, (12, 16), i_house), (1, (18, 24), i_hall)], gap=(0, 2))
        nx = s.cx + r.randint(-20, 20)
        i_needle(cv, r, nx, v.seat(line, nx - 4, nx + 4) + 1, 4, 44)
        row(s, cv, line + 4, x0, x1, [(3, (12, 17), i_house), (1, (20, 26), i_hall)], gap=(0, 4))
        trees_between(s, cv, line + 6, x0 - 20, x1 + 20, 5, I_FIR, kind="fir")
    else:
        top = int(line[int(s.cx)]) + 3
        for side in (-1, 1):
            for j, off in enumerate((0.88, 0.66, 0.42, 0.2)):
                nx = s.cx + side * s.half * off
                i_needle(cv, r, nx, v.seat(line, nx - 4, nx + 4) + 1, 2.8 + j * 0.7,
                         int(r.uniform(70, 90) * (0.4 + j * 0.2)))
        i_needle(cv, r, s.cx, top, 7, r.randint(110, 125))
        i_hall(cv, r, int(s.cx) - 20, top + 2, 40)
        # a wall of carved ice blocks along the foot, lit doorways cut through it
        for x in range(max(0, x0), min(W - 1, x1) + 1):
            base = int(line[x]) + 5
            for y in range(base - 13, base + 1):
                c = I_ICE[1]
                if (base - y) % 5 == 4 or (x + ((base - y) // 5) * 4) % 9 == 0:
                    c = I_ICE[2]
                b.P(cv, x, y, c)
            b.P(cv, x, base - 13, I_ICE[0])
            b.P(cv, x, base - 12, I_ICE[0])
        for gx in range(x0 + 14, x1 - 10, 22):
            gb = int(line[min(W - 1, max(0, gx))]) + 5
            b.door(cv, gx, gb, 5, 9, I_LIGHT_DK)
            b.door(cv, gx, gb, 3, 7, I_LIGHT)
        trees_between(s, cv, line + 8, x0 - 40, x1 + 40, 6, I_FIR, kind="fir")


KITS = dict(dirt=dirt_kit, forest=forest_kit, desert=desert_kit, mountains=mountains_kit,
            ice=ice_kit)
