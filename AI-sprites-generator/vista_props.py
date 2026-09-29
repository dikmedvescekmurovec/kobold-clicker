"""The open land of the vista backdrops: roads, water and the one thing that makes each of a
place's four plains its own (an oak, a pond, standing stones, a dead tree...).

Roads come in two pieces so that a hill can hide the middle of one: `far_road` is painted on the
middle distance right after it is filled, `near_road` on the ground the fighters stand on, and
the stretch between is behind the crest -- the road goes over the rise and comes back.
"""
import math
import random

import numpy as np

import vista as v
import vista_build as b
from vista import H, W, mix, rgb, shade


# ---------------------------------------------------------------- roads

def road_path(seed, x_near, y_near, x_far, y_far, horizon=200, k=0.14):
    """A road's centre and half-width per column, from a near point low in the frame to a far one
    on the crest: it bends as it goes, and its width falls with distance from the horizon."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    lo, hi = min(x_near, x_far), max(x_near, x_far)
    u = np.clip((xs - x_near) / (x_far - x_near), 0, 1)
    s = u * u * (3 - 2 * u)
    y = y_near + (y_far - y_near) * (0.35 * u + 0.65 * s)
    y += np.sin(u * math.pi * rng.uniform(1.5, 2.2)) * rng.uniform(3, 6) * (1 - u)
    hw = np.maximum(1.0, (y - horizon) * k)
    # over the crest it narrows to nothing rather than stopping square
    hw *= np.clip(np.abs(x_far - xs) / 18.0, 0, 1) ** 0.6
    inside = (xs >= lo) & (xs <= hi) & (hw >= 0.6)
    return y, hw, inside


def near_road(cv, seed, y, hw, inside, pal, edge=None):
    """The road on the fighting ground: packed earth with two ruts following its curve, a dark
    lip on its far edge, tufts creeping over its near one, a few stones."""
    lit, mid, shd, dark = pal
    rng = random.Random(seed)
    top = np.floor(y - hw).astype(int)
    bot = np.floor(y + hw).astype(int)
    m = (v.YY >= top[None, :]) & (v.YY <= bot[None, :]) & inside[None, :]
    cv.fill(m, mid)
    n = v.noise2(seed + 2, W, H, 9)
    cv.fill(m & (n > 0.66), lit)
    cv.fill(m & (n < 0.3), shd)
    for off in (-0.38, 0.3):
        ry = np.floor(y + hw * off).astype(int)
        cv.fill(m & (v.YY == ry[None, :]), shd)
        cv.fill(m & (v.YY == ry[None, :] + 1) & (hw[None, :] > 6), dark)
    cv.fill(m & (v.YY == top[None, :]), dark)
    cv.fill(m & (v.YY == top[None, :] + 1), shd)
    for _ in range(90):
        x = rng.randrange(W)
        if not inside[x]:
            continue
        yy = rng.randint(top[x] + 2, max(top[x] + 2, bot[x] - 1))
        cv.px(x, yy, lit)
        cv.px(x + 1, yy, shd)
    if edge is not None:
        for x in range(W):
            if inside[x] and rng.random() < 0.7:
                for k in range(rng.randint(1, 4)):
                    cv.px(x, bot[x] - k + 1, edge[rng.randrange(len(edge))])
            if inside[x] and rng.random() < 0.35:
                for k in range(rng.randint(1, 2)):
                    cv.px(x, top[x] - k, edge[rng.randrange(len(edge))])
    return m


def far_road(cv, seed, line, x0, pal, width=7, turn=1):
    """The road again beyond the rise, climbing the middle distance and thinning as it goes."""
    lit, mid, shd, dark = pal
    y_top = int(line[int(min(W - 1, max(0, x0)))]) - 14
    for y in range(y_top, H):
        u = (y - y_top) / 26.0
        cx = x0 + turn * (math.sin(u * 2.4) * 10 + u * 8)
        half = 0.6 + u * width
        for x in range(int(cx - half), int(cx + half) + 1):
            if 0 <= x < W and y >= line[x]:
                cv.px(x, y, mid if x < cx + half * 0.4 else shd)


def signpost(cv, x, base, wood, sign):
    """A fingerpost: a squared post, two arms pointing opposite ways, a cap on top."""
    lit, mid, shd, dark = wood
    b.rect(cv, x, base - 34, x + 2, base, mid)
    for k in range(base - 34, base + 1):
        b.P(cv, x, k, lit)
        b.P(cv, x + 2, k, shd)
    b.rect(cv, x - 1, base - 36, x + 3, base - 35, dark)
    for (y, d) in ((base - 32, 1), (base - 24, -1)):
        xa = x + 3 if d > 0 else x - 16
        b.rect(cv, xa, y, xa + 13, y + 4, sign)
        b.hline(cv, xa, xa + 13, y, shade(sign, 0.3))
        b.hline(cv, xa, xa + 13, y + 5, dark)
        for k in range(3):
            tip = xa + 14 + k if d > 0 else xa - 1 - k
            b.rect(cv, tip, y + k, tip, y + 4 - k, sign)
        for k in range(xa + 3, xa + 11, 2):
            b.P(cv, k, y + 2, shade(sign, -0.35))


def milestone(cv, x, base, stone):
    """A roadside stone with a rounded head and a number cut into it."""
    lit, mid, shd, dark = stone
    for y in range(base - 16, base + 1):
        r_ = y - (base - 16)
        half = 5 if r_ > 3 else (4 if r_ > 1 else 3)
        b.hline(cv, x - half, x + half, y, mid)
        b.P(cv, x - half, y, lit)
        b.P(cv, x - half + 1, y, lit)
        b.P(cv, x + half - 1, y, shd)
        b.P(cv, x + half, y, dark)
    for k in range(3):
        b.hline(cv, x - 2, x + 2, base - 11 + k * 3, shd)


def cart(cv, x, base, wood, wheel, load=None):
    """A two-wheeled hand cart left by the road, shafts down, a sack or two in it."""
    lit, mid, shd, dark = wood
    b.rect(cv, x, base - 20, x + 32, base - 10, mid)
    b.hline(cv, x, x + 32, base - 20, lit)
    b.hline(cv, x, x + 32, base - 15, shd)
    b.hline(cv, x, x + 32, base - 10, dark)
    for k in range(x, x + 33, 8):
        b.rect(cv, k, base - 20, k, base - 10, shd)
    if load is not None:
        for (lx, lw) in ((x + 3, 12), (x + 15, 11)):
            for yy in range(base - 27, base - 20):
                u = (yy - (base - 27)) / 7
                half = int(lw / 2 * min(1.0, 0.6 + u))
                b.hline(cv, lx + lw // 2 - half, lx + lw // 2 + half, yy, load)
            b.hline(cv, lx + 2, lx + lw - 2, base - 27, shade(load, 0.3))
    for k in range(18):
        b.P(cv, x + 33 + k, base - 11 + k // 2, shd)
        b.P(cv, x + 33 + k, base - 12 + k // 2, mid)
    cx, cy, r = x + 12, base - 8, 8
    for a in range(0, 360, 6):
        for rr in (r, r - 1):
            b.P(cv, int(round(cx + math.cos(math.radians(a)) * rr)),
                int(round(cy + math.sin(math.radians(a)) * rr)), wheel)
    for a in range(0, 180, 30):
        for t in range(r):
            b.P(cv, int(round(cx + math.cos(math.radians(a)) * t)),
                int(round(cy + math.sin(math.radians(a)) * t)), wheel)
            b.P(cv, int(round(cx - math.cos(math.radians(a)) * t)),
                int(round(cy - math.sin(math.radians(a)) * t)), wheel)
    b.rect(cv, cx - 1, cy - 1, cx + 1, cy + 1, lit)


def fence(cv, x0, x1, line, wood, gap=14, h=14):
    """A split-rail fence along a line: posts, and two rails between them."""
    lit, mid, shd, dark = wood
    for x in range(int(x0), int(x1)):
        base = int(line[min(W - 1, max(0, x))]) + 1
        for ry in (base - h + 3, base - h // 2 + 1):
            b.P(cv, x, ry, lit)
            b.P(cv, x, ry + 1, mid)
            b.P(cv, x, ry + 2, dark)
    for x in range(int(x0), int(x1), gap):
        base = int(line[min(W - 1, max(0, x))]) + 1
        for k in range(h):
            b.P(cv, x, base - k, lit)
            b.P(cv, x + 1, base - k, mid)
            b.P(cv, x + 2, base - k, shd)


# ---------------------------------------------------------------- water

def pond(cv, seed, cx, y, half, depth, sky_c, deep_c, rim_c, glint):
    """Still water: an ellipse of reflected sky darkening toward its near shore, glints on it,
    a lip of bank along its far edge."""
    rng = random.Random(seed)
    for yy in range(y, y + depth):
        u = (yy - y) / max(1, depth - 1)
        hw = half * math.sqrt(max(0.0, 1 - (2 * u - 1) ** 2)) * (1.0 if u < 0.5 else 1.0)
        a, bb = int(cx - hw), int(cx + hw)
        c = mix(sky_c, deep_c, u * 0.9)
        b.hline(cv, a, bb, yy, c)
        b.P(cv, a, yy, rim_c)
        b.P(cv, bb, yy, rim_c)
    b.hline(cv, int(cx - half * 0.7), int(cx + half * 0.7), y - 1, rim_c)
    for _ in range(int(half / 3)):
        gy = rng.randrange(y + 1, y + depth - 1)
        gx = rng.uniform(cx - half * 0.6, cx + half * 0.6)
        b.hline(cv, int(gx), int(gx) + rng.randint(2, 6), gy, glint)


# ---------------------------------------------------------------- landmarks

def oak(cv, rng, cx, base, r, leaf, trunk):
    """A single great tree: a wide crown of many lobes on a short thick trunk with a root flare."""
    lit, mid, shd = leaf
    tl, tm, ts, td = trunk
    th = int(r * 1.0)
    for k in range(th):
        half = r * 0.12 + max(0, 4 - k) * 0.8
        b.hline(cv, int(cx - half), int(cx + half), base - k, tm)
        b.P(cv, int(cx - half), base - k, tl)
        b.P(cv, int(cx + half), base - k, td)
    for side in (-1, 1):
        for k in range(int(r * 0.6)):
            b.P(cv, int(cx + side * (2 + k * 0.8)), base - th - k // 2 + 2, ts)
    top = base - th
    for i in range(int(r * 1.8)):
        a = rng.uniform(0, math.pi)
        d = rng.uniform(0, r * 0.95)
        lx = cx + math.cos(a) * d * 1.3
        ly = top - math.sin(a) * d * 0.85 - r * 0.35
        lr = rng.uniform(r * 0.32, r * 0.5)
        for yy in range(int(ly - lr), int(ly + lr) + 1):
            for xx in range(int(lx - lr), int(lx + lr) + 1):
                dx, dy = xx - lx, yy - ly
                if dx * dx + dy * dy <= lr * lr:
                    nd = (-dx * 0.4 - dy * 0.9) / lr
                    c = lit if nd > 0.45 else (shd if nd < -0.4 else mid)
                    b.P(cv, xx, yy, c)
    # the crown's underside in shade
    for xx in range(int(cx - r * 1.3), int(cx + r * 1.3)):
        for yy in range(top - int(r * 0.25), top + 2):
            if 0 <= xx < W and 0 <= yy < H and tuple(cv.a[yy, xx]) in (lit, mid):
                cv.a[yy, xx] = shd


def dead_tree(cv, rng, cx, base, h, c, c2):
    """Bare branches forking up from a crooked trunk."""
    def limb(x, y, ang, ln, w):
        for i in range(int(ln)):
            x += math.cos(ang)
            y -= math.sin(ang)
            for k in range(w):
                b.P(cv, int(round(x)) + k, int(round(y)), c if k == 0 else c2)
            ang += rng.uniform(-0.12, 0.12)
        if ln > 4:
            for d in (-0.55, 0.5):
                limb(x, y, ang + d + rng.uniform(-0.2, 0.2), ln * rng.uniform(0.5, 0.7),
                     max(1, w - 1))
    limb(cx, base, math.pi / 2 + rng.uniform(-0.1, 0.1), h * 0.42, 5)


def standing_stones(cv, rng, cx, line, n, stone, spread=15):
    """A ring of standing stones seen side on; the middle pair carries a lintel."""
    lit, mid, shd, dark = stone
    mid_i = n // 2 - 1
    tops = {}
    for i in range(n):
        x = int(cx + (i - n / 2) * spread + rng.randint(-2, 2))
        base = int(line[min(W - 1, max(0, x))]) + 2
        h = 34 if i in (mid_i, mid_i + 1) else rng.randint(18, 28)
        w = rng.randint(7, 9)
        for r_ in range(h):
            y = base - r_
            inset = 1 if r_ > h - 3 else 0
            b.hline(cv, x + inset, x + w - 1 - inset, y, mid)
            b.P(cv, x + inset, y, lit)
            b.P(cv, x + inset + 1, y, lit)
            b.P(cv, x + w - 2 - inset, y, shd)
            b.P(cv, x + w - 1 - inset, y, dark)
        for _ in range(h // 4):
            b.P(cv, rng.randint(x + 2, x + w - 3), base - rng.randint(2, h - 2), shd)
        tops[i] = (x, w, base - h + 1)
    if n >= 2:
        (xa, wa, ta), (xb, wb, tb) = tops[mid_i], tops[mid_i + 1]
        top = min(ta, tb)
        b.rect(cv, xa - 2, top - 5, xb + wb + 1, top - 1, mid)
        b.hline(cv, xa - 2, xb + wb + 1, top - 5, lit)
        b.hline(cv, xa - 2, xb + wb + 1, top - 1, dark)
        b.P(cv, xb + wb + 1, top - 3, dark)


def ruin(cv, rng, cx, line, stone, n=4):
    """A colonnade nobody remembers: fluted columns broken off at different heights, one still
    carrying a stretch of its entablature, drums fallen in the grass."""
    lit, mid, shd, dark = stone
    spots = []
    for i in range(n):
        x = int(cx + (i - n / 2) * 20)
        base = int(line[min(W - 1, max(0, x))]) + 2
        h = rng.randint(14, 48) if i not in (1, 2) else rng.randint(48, 58)
        b.rect(cv, x - 2, base - 3, x + 9, base, mid)
        b.hline(cv, x - 2, x + 9, base - 3, lit)
        b.P(cv, x + 9, base - 1, dark)
        for r_ in range(3, h):
            y = base - r_
            b.hline(cv, x, x + 7, y, mid)
            b.P(cv, x, y, lit)
            b.P(cv, x + 1, y, lit)
            b.P(cv, x + 4, y, shd)
            b.P(cv, x + 6, y, shd)
            b.P(cv, x + 7, y, dark)
        # a broken top, jagged
        for k in range(8):
            for d in range(rng.randint(0, 3)):
                b.P(cv, x + k, base - h + d, cv.a[max(0, base - h - 6), x + k])
        spots.append((x, base - h))
        if i in (1, 2):
            b.rect(cv, x - 2, base - h - 3, x + 9, base - h, mid)
            b.hline(cv, x - 2, x + 9, base - h - 3, lit)
    (xa, ta), (xb, tb) = spots[1], spots[2]
    top = min(ta, tb) - 3
    b.rect(cv, xa - 2, top - 6, xb + 9, top - 1, mid)
    b.hline(cv, xa - 2, xb + 9, top - 6, lit)
    b.hline(cv, xa - 2, xb + 9, top - 3, shd)
    b.hline(cv, xa - 2, xb + 9, top - 1, dark)
    # fallen drums
    base = int(line[min(W - 1, max(0, int(cx)))]) + 6
    for dx in (-44, 36, 50):
        x = int(cx + dx)
        b.rect(cv, x, base - 5, x + 10, base, mid)
        b.hline(cv, x, x + 10, base - 5, lit)
        b.hline(cv, x, x + 10, base, dark)
        b.rect(cv, x + 11, base - 5, x + 12, base, shd)


def shards(cv, rng, cx, line, n, ice):
    """Crystals of ice driven up out of the snow at angles, the tallest in the middle."""
    lit, mid, shd, dark = ice
    for i in range(n):
        u = (i + 0.5) / n
        x = cx + (u - 0.5) * 90 + rng.uniform(-6, 6)
        base = int(line[min(W - 1, max(0, int(x)))]) + 3
        h = int(rng.uniform(18, 30) + 44 * (1 - abs(u - 0.5) * 2) ** 1.5)
        lean = (u - 0.5) * 0.7 + rng.uniform(-0.12, 0.12)
        half = rng.uniform(3.5, 7)
        for k in range(h):
            u = k / h
            hw = half * (1 - u)
            c0 = x + lean * k
            b.hline(cv, int(round(c0 - hw)), int(round(c0 + hw)), base - k, mid)
            b.P(cv, int(round(c0 - hw)), base - k, lit)
            b.P(cv, int(round(c0 + hw)), base - k, dark)
            if hw > 1:
                b.P(cv, int(round(c0)), base - k, lit if k % 2 else mid)


def cairn(cv, rng, cx, base, stone, k=1.0):
    """Flat stones stacked by travellers, each laid a little off the one below."""
    lit, mid, shd, dark = stone
    y = base
    for w in (22, 18, 15, 12, 9, 7, 5):
        w = max(3, int(w * k))
        h = max(2, int(4 * k))
        off = rng.randint(-1, 1)
        x0, x1 = int(cx - w / 2) + off, int(cx + w / 2) + off
        for r_ in range(h):
            inset = 1 if r_ in (0, h - 1) else 0
            b.hline(cv, x0 + inset, x1 - inset, y - r_, mid)
            b.P(cv, x1 - inset, y - r_, dark)
        b.hline(cv, x0 + 1, x1 - 1, y - h + 1, lit)
        b.hline(cv, x0 + 1, x1 - 1, y, shd)
        y -= h


def log(cv, x, base, ln, bark, cut, h=9):
    """A fallen trunk lying across the clearing, its cut end toward the viewer's right."""
    lit, mid, shd, dark = bark
    b.rect(cv, x, base - h, x + ln, base, mid)
    b.hline(cv, x, x + ln, base - h, lit)
    b.hline(cv, x, x + ln, base - h + 1, lit)
    b.hline(cv, x, x + ln, base - 1, shd)
    b.hline(cv, x, x + ln, base, dark)
    for k in range(x + 3, x + ln - 2, 5):
        b.hline(cv, k, k + 2, base - h // 2 + (k % 3) - 1, shd)
    for yy in range(base - h, base + 1):
        u = (yy - (base - h)) / h
        half = int(2 * (1 - abs(2 * u - 1) ** 2)) + 1
        b.hline(cv, x + ln + 1, x + ln + half, yy, cut)
    b.P(cv, x + ln + 1, base - h // 2, shade(cut, -0.35))
    b.P(cv, x + ln + 2, base - h // 2, shade(cut, -0.2))
    # a broken branch stub
    for k in range(5):
        b.P(cv, x + 10 + k, base - h - k, mid)
        b.P(cv, x + 11 + k, base - h - k, shd)


def mushrooms(cv, rng, x0, x1, base, cap, stem):
    for _ in range(rng.randint(5, 8)):
        x = rng.randint(x0, x1)
        h = rng.randint(2, 5)
        for k in range(h):
            b.P(cv, x, base - k, stem)
        b.hline(cv, x - 2, x + 2, base - h, cap)
        b.hline(cv, x - 1, x + 1, base - h - 1, cap)
        b.P(cv, x - 1, base - h - 1, shade(cap, 0.35))
        b.P(cv, x + 2, base - h, shade(cap, -0.3))
        b.P(cv, x, base - h, rgb("f8f0e0"))
