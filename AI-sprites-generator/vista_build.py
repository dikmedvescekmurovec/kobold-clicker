"""Building parts for the vista backdrops: facades, roofs, towers, walls, openings.

Everything is drawn front-on (the facade faces the viewer) with light from the upper left: a
wall's left edge is lit and its right edge carries a dark shaded-side line; a roof is lighter on
its upper courses and casts a one-pixel eave shadow on the wall under it. A part takes its bottom
row (`base`) and grows upward, so seating it is a matter of passing the ground's row -- see
`vista.seat`.

A palette `m` for a material is (lit, mid, shd, dark).
"""
import math
import random

import numpy as np

from vista import H, W, mix, shade


def P(cv, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        cv.a[y, x] = c


def hline(cv, x0, x1, y, c):
    if 0 <= y < H:
        a, b = max(0, int(x0)), min(W - 1, int(x1))
        if b >= a:
            cv.a[y, a:b + 1] = c


def rect(cv, x0, y0, x1, y1, c):
    cv.rect(int(x0), int(y0), int(x1), int(y1), c)


def ramp(c, hz=None, haze=0.0):
    """(lit, mid, shd, dark) from one colour."""
    out = (shade(c, 0.22), c, shade(c, -0.22), shade(c, -0.5))
    if hz is not None and haze:
        out = tuple(mix(q, hz, haze) for q in out)
    return out


# ---------------------------------------------------------------- walls

def wall(cv, x0, base, w, h, m, batter=0.0, courses=0, rough=None):
    """A facade from x0 over w columns, rising h rows from base. `batter` pulls each side in by
    that many pixels per row (a rammed-earth or rubble wall leaning back). `courses` draws a
    darker mortar line every that many rows."""
    lit, mid, shd, dark = m
    rng = random.Random(x0 * 31 + base)
    for r in range(h):
        y = base - r
        inset = int(r * batter)
        a, b = x0 + inset, x0 + w - 1 - inset
        if b < a:
            break
        hline(cv, a, b, y, mid)
        P(cv, a, y, lit)
        P(cv, b, y, dark)
        if courses and r % courses == courses - 1:
            hline(cv, a + 1, b - 1, y, shd)
        if rough and rng.random() < rough:
            P(cv, rng.randint(a + 1, max(a + 1, b - 1)), y, shd)
    return x0, base - h + 1, x0 + w - 1


def timber(cv, x0, base, w, h, c, step=5, braces=True):
    """Oak framing over a plaster facade: sill, rail and wall plate, posts every `step`, and a
    brace in each bay."""
    top = base - h + 1
    for y in (base, top, top + h // 2):
        hline(cv, x0, x0 + w - 1, y, c)
    xs = list(range(x0, x0 + w, step)) + [x0 + w - 1]
    for x in xs:
        for y in range(top, base + 1):
            P(cv, x, y, c)
    if braces:
        for i, x in enumerate(xs[:-1]):
            span = min(step, xs[i + 1] - x)
            for k in range(1, min(span, h // 2)):
                yy = top + h // 2 - k if i % 2 == 0 else top + k
                P(cv, x + k, yy, c)


def windows(cv, x0, x1, y, h, c, frame=None, step=4, w=1, lit=None, seed=0):
    """A row of openings from x0 to x1 with their tops on y. `lit` gives some of them a warm light
    instead of the dark glass."""
    rng = random.Random(seed)
    x = x0
    while x + w - 1 <= x1:
        cc = lit if lit is not None and rng.random() < 0.7 else c
        rect(cv, x, y, x + w - 1, y + h - 1, cc)
        if frame is not None:
            hline(cv, x, x + w - 1, y + h, frame)
        x += step


def door(cv, cx, base, w, h, c, arch=True):
    """A doorway; an arched one keeps its two top corners."""
    x0 = int(cx - w // 2)
    for y in range(base - h + 1, base + 1):
        for x in range(x0, x0 + w):
            if arch and w >= 3 and y == base - h + 1 and x in (x0, x0 + w - 1):
                continue
            P(cv, x, y, c)


def lancets(cv, cx, y, h, c, n=3):
    """Grouped narrow pointed windows, one pixel wide, the middle one taller."""
    for i in range(n):
        x = cx - n + 1 + i * 2
        hh = h + (1 if i == n // 2 else 0)
        for k in range(hh):
            P(cv, x, y + k + (0 if i == n // 2 else 1), c)


# ---------------------------------------------------------------- roofs

def gable(cv, x0, top, w, rh, m, over=1, slope=1.0, ridge=None, upswept=0, snow=None, eave=True):
    """An eaves-front roof over a facade whose top row is `top`: a trapezoid rh rows high, its ends
    raked at `slope` pixels a row. Upper courses lighter; the left rake lit, the right in shade.
    `upswept` curls the eave ends up by that many pixels; `snow` lays a load along the ridge."""
    lit, mid, shd, dark = m
    a, b = x0 - over, x0 + w - 1 + over
    for r in range(rh):
        y = top - 1 - r
        ia = a + int(r * slope)
        ib = b - int(r * slope)
        if ib < ia:
            break
        u = r / max(1, rh - 1)
        c = lit if u > 0.66 else (mid if u > 0.25 else shd)
        hline(cv, ia, ib, y, c)
        P(cv, ia, y, lit)
        P(cv, ib, y, dark)
    if upswept:
        for k in range(1, upswept + 1):
            P(cv, a - k, top - 1 - k, dark)
            P(cv, b + k, top - 1 - k, dark)
    if eave:
        hline(cv, x0, x0 + w - 1, top, dark)
    if snow is not None:
        s_lit, s_shd = snow
        for r in range(rh):
            y = top - 1 - r
            ia = a + int(r * slope)
            ib = b - int(r * slope)
            if ib < ia:
                break
            if r >= rh * 0.45 or r == 0:
                hline(cv, ia, ib, y, s_lit if r > 0 else s_shd)
        hline(cv, a - upswept, b + upswept, top - 1, s_shd)
    return top - rh


def pediment(cv, cx, top, half, rh, m, face=None):
    """A gable end facing the viewer: a triangle of wall (`face`) framed by the roof's rakes."""
    lit, mid, shd, dark = m
    for r in range(rh):
        y = top - 1 - r
        hw = int(half * (1 - r / rh))
        if face is not None:
            hline(cv, cx - hw + 1, cx + hw - 1, y, face)
        P(cv, cx - hw, y, lit)
        P(cv, cx - hw - 1, y, mid)
        P(cv, cx + hw, y, dark)
        P(cv, cx + hw + 1, y, shd)


def cone(cv, cx, top, half, rh, m, finial=None, pennant=None):
    """A turret's cone: lit on the left half, shaded right, a dark rim along the right edge."""
    lit, mid, shd, dark = m
    for r in range(rh):
        y = top - 1 - r
        hw = half * (1 - r / rh)
        a, b = int(round(cx - hw)), int(round(cx + hw))
        hline(cv, a, b, y, mid)
        hline(cv, a, int(cx) - 1, y, lit)
        hline(cv, int(cx) + 1, b, y, shd)
        P(cv, b, y, dark)
    hline(cv, int(cx - half) - 1, int(cx + half) + 1, top, dark)
    tip = top - rh
    if finial is not None:
        P(cv, int(cx), tip - 1, finial)
        P(cv, int(cx), tip - 2, finial)
        tip -= 2
    if pennant is not None:
        pole, cloth = pennant
        for k in range(1, 6):
            P(cv, int(cx), tip - k, pole)
        for k in range(3):
            hline(cv, int(cx) + 1, int(cx) + 4 - k, tip - 5 + k, cloth)
    return tip


def dome(cv, cx, top, r, m):
    lit, mid, shd, dark = m
    for yy in range(-r, 1):
        hw = int(round(math.sqrt(max(0, r * r - yy * yy))))
        y = top - 1 + yy
        hline(cv, cx - hw, cx + hw, y, mid)
        hline(cv, cx - hw, cx - hw // 3, y, lit)
        hline(cv, cx + hw // 2, cx + hw, y, shd)
        P(cv, cx + hw, y, dark)
    return top - r - 1


def crenels(cv, x0, x1, top, h, m, step=3, teeth=False):
    """Merlons along a parapet whose top row is `top`: square blocks, or pointed teeth."""
    lit, mid, shd, dark = m
    x = x0
    while x <= x1:
        if teeth:
            P(cv, x, top - 1, mid)
            P(cv, x + 1, top - 1, shd)
            P(cv, x, top - 2, lit)
        else:
            for k in range(h):
                P(cv, x, top - 1 - k, lit)
                if x + 1 <= x1:
                    P(cv, x + 1, top - 1 - k, mid)
        x += step


def tiers(cv, cx, top, half, n, rh, m, step, finial=None, post=None, gap=2):
    """A meru: n roofs stacked, each narrower by `step`, with a gap of post between them."""
    y = top
    for i in range(n):
        hw = half - i * step
        if hw < 2:
            break
        a = int(cx - hw)
        y = gable(cv, a + 1, y, int(hw * 2) - 1, rh, m, over=1, slope=1.4, eave=True)
        if i < n - 1 and post is not None:
            rect(cv, int(cx) - 1, y - gap, int(cx) + 1, y - 1, post)
            y -= gap
    if finial is not None:
        for k in range(1, 5):
            P(cv, int(cx), y - k, finial)
        P(cv, int(cx), y - 5, shade(finial, 0.3))
        y -= 5
    return y


def arches(cv, x0, x1, base, h, span, c, pier=2):
    """A row of arched openings (an arcade or a viaduct's spans) cut into whatever is behind."""
    x = x0 + pier
    while x + span <= x1 - pier + 1:
        r = span / 2
        cx = x + r - 0.5
        for xx in range(x, x + span):
            dx = (xx - cx) / r
            rise = int(round(r * math.sqrt(max(0.0, 1 - dx * dx))))
            for y in range(base - h + int(r) - rise, base + 1):
                P(cv, xx, y, c)
        x += span + pier


def pennant(cv, x, top, pole, cloth, h=6, length=4):
    for k in range(h):
        P(cv, x, top - k, pole)
    for k in range(3):
        hline(cv, x + 1, x + length - k, top - h + 1 + k, cloth)


def palm(cv, rng, cx, base, h, trunk_m, leaf_m, k=1.0):
    """A date palm: a ringed trunk leaning and curving, a crown of drooping fronds. `k` scales
    the crown and the trunk's thickness for a palm seen close."""
    lean = rng.choice((-1, 1)) * rng.uniform(0.1, 0.3)
    x = float(cx)
    tw = max(1, int(round(k)))
    for i in range(h):
        for d in range(tw):
            c = trunk_m[1] if i % 3 else trunk_m[2]
            if d == 0 and tw > 1:
                c = trunk_m[0] if i % 3 else trunk_m[1]
            P(cv, int(round(x)) + d, base - i, c)
        x += lean * (i / h)
    tx, ty = int(round(x)) + tw // 2, base - h
    for ang in (-165, -140, -115, -90, -65, -40, -15, 190, 215):
        a = math.radians(ang)
        ln = rng.uniform(5, 8) * k
        for i in range(int(ln)):
            t = i / ln
            px_ = tx + math.cos(a) * i
            py_ = ty + math.sin(a) * i * 0.6 + t * t * 4 * k
            c = leaf_m[0] if math.cos(a) < 0 else leaf_m[1]
            P(cv, int(round(px_)), int(round(py_)), c)
            P(cv, int(round(px_)), int(round(py_)) + 1, leaf_m[2])
            if k > 1.5 and 0.2 < t < 0.8:
                P(cv, int(round(px_)), int(round(py_)) + 2, leaf_m[2])
