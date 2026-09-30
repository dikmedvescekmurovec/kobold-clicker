"""Battle backdrops drawn the way the fighters are: side on, in ENDESGA 64 -- the palette every
fighter pack is drawn in, and the Fantasy Forest environment pack beside them
(`Assets/Potential/2D enemies/FULL_Fantasy Forest`) -- with that artist's #131313 ink round
everything that stands on the fighting ground.

The rules are measured off that pack, the fighters' own artist's world:
- far layers are flat, two or three colours each and no ink, and grow darker toward the viewer
  (sky, clouds, blue-grey mountains, green hills, dark teal hills);
- the ground is a strip seen side on: an inked grass lip, the earth's cut face under it;
- whatever stands on it is inked and shaded in three tones lit from the upper left, and a crown
  or a bush is mottled, not built of lit lobes.

The grid is 384x216 drawn 6x into a 2304x1296 file (`CombatScene.AREA_UPSCALE`), so on screen one
backdrop pixel is one of the hero's pixels. The landscapes, the ground, the plains' landmarks and
the road are here; the six peoples' settlements are `sideview_kits.py`.

`python sideview.py <tag> [env...] [variant...] [layout...]` writes `qa/side_<tag>_<env>.png`, a
sheet per place (variants down, layouts across) with the hero and a Masked Orc stood where the
fight puts them; one scene alone comes out at the game's 3x.
"""
import math
import random
import sys

import numpy as np
from PIL import Image

W, H = 384, 216
SCALE = 6
## The row under the fighters' feet: CombatScene.GROUND (0.86) seen through the backdrop's bleed.
FEET = 182
## Where the fight stands them, in backdrop pixels (PLAYER_X 0.24, ENEMY_X 0.72 through the bleed).
PLAYER_X, ENEMY_X = 97, 272

def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def smooth(seed, n, k):
    """1D value noise over n samples with k lattice points, smoothstepped between them."""
    rng = random.Random(seed)
    pts = [rng.random() for _ in range(k + 2)]
    out = np.empty(n)
    for i in range(n):
        t = i / n * k
        a = int(t)
        f = t - a
        f = f * f * (3 - 2 * f)
        out[i] = pts[a] * (1 - f) + pts[a + 1] * f
    return out


def fbm(seed, n, octaves):
    """octaves = ((lattice points, amplitude), ...) -> an array in 0..1."""
    out = np.zeros(n)
    tot = 0.0
    for i, (k, a) in enumerate(octaves):
        out += smooth(seed * 977 + i * 31, n, k) * a
        tot += a
    return out / tot


def noise2(seed, w, h, cell):
    """Smooth 2D value noise, 0..1."""
    rng = np.random.default_rng(seed)
    g = rng.random((h // cell + 2, w // cell + 2))
    ys, xs = np.arange(h) / cell, np.arange(w) / cell
    y0, x0 = ys.astype(int), xs.astype(int)
    fy, fx = ys - y0, xs - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b = g[y0][:, x0], g[y0][:, x0 + 1]
    c, d = g[y0 + 1][:, x0], g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


E64 = ("ff0040 131313 1b1b1b 272727 3d3d3d 5d5d5d 858585 b4b4b4 ffffff c7cfdd 92a1b9 657392 424c6e "
       "2a2f4e 1a1932 0e071b 1c121c 391f21 5d2c28 8a4836 bf6f4a e69c69 f6ca9f f9e6cf edab50 e07438 "
       "c64524 8e251d ff5000 ed7614 ffa214 ffc825 ffeb57 d3fc7e 99e65f 5ac54f 33984b 1e6f50 134c4c "
       "0c2e44 00396d 0069aa 0098dc 00cdf9 0cf1ff 94fdff fdd2ed f389f5 db3ffd 7a09fa 3003d9 0c0293 "
       "03193f 3b1443 622461 93388f ca52c9 c85086 f68187 f5555d ea323c c42430 891e2b 571c27").split()
PALETTE = {rgb(h) for h in E64}

INK = rgb("131313")
WHITE, CLOUD = rgb("ffffff"), rgb("c7cfdd")
STONE = (rgb("c7cfdd"), rgb("92a1b9"), rgb("657392"), rgb("424c6e"))
LEAF = (rgb("99e65f"), rgb("5ac54f"), rgb("33984b"), rgb("1e6f50"), rgb("134c4c"))
EARTH = (rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836"), rgb("5d2c28"), rgb("391f21"))
THATCH = (rgb("8a4836"), rgb("5d2c28"), rgb("391f21"))
GOLD = (rgb("ffeb57"), rgb("ffc825"), rgb("edab50"))
RED = (rgb("f5555d"), rgb("ea323c"), rgb("891e2b"))
OAK_BARK = (rgb("8a4836"), rgb("5d2c28"), rgb("391f21"))

YY, XX = np.mgrid[0:H, 0:W]
BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
_BY = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]


# ---------------------------------------------------------------- ink

def grow(m):
    """The mask and its four neighbours: what a one-pixel outline round it covers."""
    g = m.copy()
    g[1:] |= m[:-1]
    g[:-1] |= m[1:]
    g[:, 1:] |= m[:, :-1]
    g[:, :-1] |= m[:, 1:]
    return g


def inked(a, m, ink=INK):
    """Rings a shape in ink, outside it, before its own colours go on -- so a one-pixel blade keeps
    its colour, as the packs' grass does."""
    a[grow(m) & ~m] = ink


def disc(cx, cy, r, sy=1.0):
    return (XX - cx) ** 2 + ((YY - cy) * sy) ** 2 <= r * r


# ---------------------------------------------------------------- far layers: flat, no ink

def sky(a, stops, band=4):
    """Flat bands of colour from the zenith down, each joined to the one above by a short ordered
    dither, as the pack joins its two blues. `stops` is ((colour, first row), ...)."""
    a[:] = stops[0][0]
    for c, row in stops[1:]:
        a[YY >= row] = c
        t = (YY - (row - band)) / band
        a[(YY >= row - band) & (YY < row) & (_BY < t)] = c


def sun(a, cx, cy, r, core, rim, halo=None):
    if halo is not None:
        a[disc(cx, cy, r * 1.8)] = halo
    a[disc(cx, cy, r + 1)] = rim
    a[disc(cx, cy, r)] = core


def stars(a, seed, bottom, count, tones=(WHITE, rgb("fdd2ed"), rgb("c7cfdd"))):
    """Single pixels, a few of them crosses, thinning toward the horizon."""
    rng = random.Random(seed)
    for _ in range(count):
        x, y = rng.randrange(W), int(rng.random() ** 1.6 * bottom)
        c = tones[rng.randrange(len(tones))]
        a[y, x] = c
        if rng.random() < 0.08 and 0 < x < W - 1 and 0 < y < H - 1:
            a[y, x - 1] = a[y, x + 1] = a[y - 1, x] = a[y + 1, x] = tones[-1]


def aurora(a, seed, y0, amp, tones):
    """A curtain of light hanging from a wavy hem: the hem brightest, the drape a dark glow with
    lighter rays standing in it, its top a slow wave that dithers out over its last rows."""
    hem_c, ray_c, body = tones
    hem = y0 + (fbm(seed, W, ((2, 1.0), (5, 0.6), (13, 0.2))) - 0.5) * amp
    tall = 12 + 28 * fbm(seed + 1, W, ((10, 1.0), (26, 0.5), (60, 0.25)))
    up = hem[None, :] - YY
    fade = np.clip((up - (tall[None, :] - 5)) / 5, 0, 1)
    curtain = (up >= 0) & (up <= tall[None, :]) & (_BY >= fade)
    a[curtain] = body
    a[curtain & ((XX // 2) % 3 == 0) & (up < tall[None, :] * 0.7)] = ray_c
    a[(up >= 0) & (up < 2)] = hem_c


def cloud(a, rng, cx, base, w, h, lit=WHITE, body=CLOUD, bump=(6, 11)):
    """A heap of small round bumps in two tones, as the pack's: bumps scattered through a dome,
    the higher painted first so each lower one bites into what is behind it; a bump is grey with
    a white cap toward the upper left, the cap shrinking to nothing toward the heap's foot, so the
    top is white and the underside grey. The base is cut flat, for a range to hide."""
    lobes = []
    for _ in range(int(w * h / 45)):
        u = rng.uniform(-1, 1)
        top = base - h * (1 - u * u) ** 0.8
        y = rng.uniform(top, base)
        r = rng.uniform(*bump) * (1.3 if abs(u) < 0.5 else 1.0)
        lobes.append((cx + u * w / 2, y + r * 0.6, r, (y - top) / max(1.0, base - top)))
    for (x, y, r, v) in sorted(lobes, key=lambda q: q[1]):
        m = disc(x, y, r) & (YY <= base)
        a[m] = body
        k = 0.85 - v * 0.9
        if k > 0.25:
            a[m & disc(x - r * 0.3, y - r * 0.35, r * k)] = lit


def ridge_line(seed, base, height, count, slope=(0.6, 1.0)):
    """Peaks with shoulders, never plain triangles: each summit's two flanks fall at their own
    pitch and bow their own way (sharp and flaring, or rounded and then steep), and a lesser
    summit or two stands down its flanks; the crest is then broken by jagged noise that is
    strongest high up and dies away toward the foot. Returns the line and, per column, the summit
    that owns it."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    summits = []
    for i in range(count):
        px = (i + rng.uniform(0.2, 0.8)) / count * (W + 80) - 40
        h = height * rng.uniform(0.55, 1.0)
        sl, sr = rng.uniform(*slope), rng.uniform(*slope)
        summits.append((px, h, sl, sr))
        for side, pitch in ((-1, sl), (1, sr)):
            if rng.random() < 0.8:
                down = rng.uniform(0.3, 0.6)
                summits.append((px + side * h * down / pitch, h * (1 - down) + h * rng.uniform(0.1, 0.2),
                                pitch * rng.uniform(1.1, 1.6), pitch * rng.uniform(1.1, 1.6)))
    best = np.full(W, float(H))
    ax, ay = np.zeros(W), np.zeros(W)
    for (px, h, sl, sr) in summits:
        run = np.abs(xs - px) * np.where(xs < px, sl, sr) / h
        bow = np.where(xs < px, rng.uniform(0.7, 1.35), rng.uniform(0.7, 1.35))
        y = base - h + h * np.clip(run, 0, None) ** bow
        take = y < best
        best = np.where(take, y, best)
        ax = np.where(take, px, ax)
        ay = np.where(take, base - h, ay)
    alt = np.clip((base - best) / height, 0, 1)
    rough = (fbm(seed + 3, W, ((16, 1.0), (40, 0.55), (100, 0.3))) - 0.5) * height * 0.24 * alt
    return best + rough, ax, ay


def ranges(a, seed, base, height, count, body, lit, snow=None, snowline=0, slope=(0.6, 1.0)):
    """A range in two colours: each peak's left face lit in streaks that run down from the ridge
    and fray as they fall. `snow` (lit, shade) caps it above a ragged `snowline`."""
    line, ax, ay = ridge_line(seed, base, height, count, slope)
    m = YY >= np.floor(line)[None, :]
    a[m] = body
    depth = YY - ay[None, :]
    reach = ax[None, :] - XX
    jag = fbm(seed + 5, H, ((40, 1.0), (90, 0.6)))[:, None]
    face = (reach >= -1) & (reach < depth * (0.12 + 0.28 * jag)) & (depth < height * 0.85)
    streak = (reach > depth * 0.42) & (reach < depth * 0.42 + 2) & (depth > 6) & \
        (depth < height * 0.45)
    # every slope that faces the upper left catches a band of light under the crest
    top = np.floor(line)
    slope_ = np.gradient(line)
    rim = (YY - top[None, :] < np.clip(-slope_, 0, 2.5)[None, :] * 3 + 1) & (slope_[None, :] < -0.15)
    a[m & (face | streak | rim)] = lit
    if snow is not None:
        sl = snowline + (fbm(seed + 7, W, ((24, 1.0), (60, 0.7))) - 0.5) * 18
        cap = m & (YY < sl[None, :])
        # fingers of snow down the gullies: each column's snow runs on a length of its own
        run = np.clip((fbm(seed + 9, W, ((70, 1.0), (150, 0.7))) - 0.5) * 60, 0, 16)
        cap |= m & (YY < sl[None, :] + run[None, :])
        a[cap] = snow[1]
        a[cap & (reach >= -1)] = snow[0]
    return line


def hills(a, seed, base, amp, body, lit, octaves=((2, 1.0), (5, 0.4), (11, 0.12))):
    """A rolling layer in two colours: the slopes that face the light lit from the crest down."""
    f = fbm(seed, W, octaves)
    line = base - (f - f.min()) / max(1e-6, f.max() - f.min()) * amp
    top = np.floor(line).astype(int)
    m = YY >= top[None, :]
    a[m] = body
    slope = np.gradient(line)
    reach = np.clip(-slope, 0, None) * 30 + 1
    a[m & (YY - top[None, :] < reach[None, :]) & (slope[None, :] < -0.05)] = lit
    return line


def wood(a, seed, base, r, body, lit, gap=(0.7, 1.2)):
    """A wall of round crowns in two colours, the lit cap toward the upper left, filled solid below:
    a wood seen from a clearing."""
    rng = random.Random(seed)
    x = rng.uniform(-r, 0)
    m = YY >= base
    caps = np.zeros((H, W), bool)
    while x < W + r:
        rr = r * rng.uniform(0.7, 1.15)
        y = base - rr * rng.uniform(0.2, 0.9)
        d = disc(x, y, rr)
        m |= d
        caps = (caps & ~d) | (d & disc(x - rr * 0.3, y - rr * 0.35, rr * 0.75))
        x += rr * rng.uniform(*gap)
    a[m] = body
    a[caps] = lit


def mesas(a, seed, base, count, tops, widths, body, lit, strata=None):
    """Flat-topped buttes: a table, a sheer cliff, a talus slope out to the plain. The left cliff and
    the table's rim catch the light; `strata` runs dark courses across the cliffs."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    best = np.full(W, float(base))
    who = np.full(W, -1)
    spans = []
    for i in range(count):
        cx = (i + rng.uniform(0.2, 0.8)) / count * (W + 60) - 30
        hw, top, cliff = rng.uniform(*widths) / 2, rng.uniform(*tops), rng.uniform(8, 16)
        d = np.maximum(0, np.abs(xs - cx) - hw)
        y = np.where(d * 5 < cliff, top + d * 5, top + cliff + (d - cliff / 5) * 0.55)
        y = np.minimum(y, base)
        take = y < best
        best, who = np.where(take, y, best), np.where(take, i, who)
        spans.append((cx, hw, top, cliff))
    top_row = np.floor(best).astype(int)
    m = YY >= top_row[None, :]
    a[m] = body
    for i, (cx, hw, top, cliff) in enumerate(spans):
        mine = m & (who[None, :] == i)
        a[mine & (XX < cx - hw * 0.45)] = lit
        a[mine & (YY == top_row[None, :]) & (XX < cx + hw * 0.6)] = lit
        if strata is not None:
            a[mine & ((YY - int(top)) % 5 == 3) & (YY < top + cliff + 6) & (YY > top + 1)] = strata


def dunes(a, seed, base, count, height, body, lit, wl=(90, 170)):
    """Dunes side on: a long windward slope lit up to the crest, the short slip face beyond it in
    shade, the line between them curving back under the dune."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    best = np.full(W, float(base))
    cx_of, ty_of = np.full(W, 1e9), np.zeros(W)
    for i in range(count):
        cx = (i + rng.uniform(0.1, 0.9)) / count * (W + 120) - 60
        h = height * rng.uniform(0.55, 1.0)
        wlh = rng.uniform(*wl)
        wr = wlh * rng.uniform(0.3, 0.4)
        d = np.where(xs < cx, (cx - xs) / wlh, (xs - cx) / wr)
        y = np.where(d < 1, base - h + h * np.where(xs < cx, d ** 1.4, d ** 0.8), base)
        take = y < best
        best = np.where(take, y, best)
        cx_of, ty_of = np.where(take, cx, cx_of), np.where(take, base - h, ty_of)
    m = YY >= np.floor(best)[None, :]
    a[m] = lit
    lean = cx_of[None, :] - (YY - ty_of[None, :]) * 0.8 - (YY - ty_of[None, :]) ** 2 * 0.03
    a[m & (XX > lean)] = body


# ---------------------------------------------------------------- the ground: side on, inked

def ground(a, seed, grass=LEAF, earth=EARTH, top=FEET, lip=6, streaks=True, road=None,
           paved=False):
    """The strip the fight stands on. The ink runs along its top at `top` (a pixel higher over a
    few columns, where blades stand up); the grass lip below it is streaked light over dark (sand
    and snow are not: `streaks`) and hangs over the earth in short drips, inked under them; the
    earth's face is chunks of lit clay over dark, darker the deeper it goes. A `road` (four tones)
    lays packed earth over the lip instead, two ruts along it, or setts where it is `paved`."""
    rng = random.Random(seed)
    hi = (fbm(seed, W, ((120, 1.0),)) > 0.6) & (road is None)
    g = top - hi.astype(int)
    drip = np.clip((fbm(seed + 1, W, ((70, 1.0), (140, 0.8))) - 0.3) * 7, 0, 3).astype(int)
    last = top + lip + drip
    streak = noise2(seed + 2, W, H, 2)
    lt, mid, shd, dk, deep = grass
    for x in range(W):
        a[g[x], x] = INK
        for y in range(g[x] + 1, last[x] + 1):
            k = y - g[x] - 1
            if road is not None:
                c = road[0] if k == 0 else (road[2] if k == 2 else road[1])
                if paved and k > 0 and ((x + (k // 2) * 3) % 6 == 0 or k % 2 == 0):
                    c = road[2]
                if k >= lip - 1:
                    c = road[3]
                a[y, x] = c
                continue
            if streaks:
                c = mid if k < 3 else shd
                slant = (x + k // 2) % 4 == 0
                if slant and streak[y, x] > 0.35 and k < lip - 1:
                    c = lt if k < 3 else mid
            else:
                c = lt if k < 2 else (mid if k < 4 else shd)
            if k >= lip - 1:
                c = dk
            a[y, x] = c
        a[last[x] + 1, x] = INK
    # the earth's face
    face = YY > (last + 1)[None, :]
    elt, lit, body, shade, dark = earth
    a[face] = shade
    n = noise2(seed + 3, W, H * 2, 4)[::2]
    chunk = face & (n > 0.48)
    a[chunk] = body
    rim = chunk & ~np.roll(chunk, 1, axis=0)
    a[rim] = lit
    a[chunk & np.roll(rim, 1, axis=0) & (n > 0.6)] = lit
    a[chunk & ~np.roll(chunk, -1, axis=0)] = shade
    t = (YY - top) / (H - top)
    n2 = noise2(seed + 4, W, H, 4)
    a[face & ~chunk & (n2 < t * 1.1 - 0.15)] = dark
    a[face & chunk & (n2 < t * 0.9 - 0.45)] = shade
    for _ in range(18):
        x, y = rng.randrange(W), rng.randrange(top + lip + 5, H - 2)
        if face[y, x]:
            a[y, x] = elt
            a[y, x + 1 if x + 1 < W else x] = lit
            a[y + 1, x] = dark
    return g


# ---------------------------------------------------------------- what stands on it

def crown_mask(seed, lobes, rough=0.3, sy=1.1):
    """A leafy silhouette: the union of the lobes with a frayed edge, as the pack's crowns."""
    d = np.full((H, W), 9.0)
    for (x, y, r) in lobes:
        d = np.minimum(d, np.sqrt((XX - x) ** 2 + ((YY - y) * sy) ** 2) / r)
    m = d < 1 + (noise2(seed, W, H, 2) - 0.5) * rough
    # a frayed edge leaves specks; a pixel with fewer than two neighbours in the crown goes
    held = sum(np.roll(m, k, axis=ax) for k in (1, -1) for ax in (0, 1))
    return m & (held >= 2)


def mottle(a, m, seed, cx, cy, r, tones):
    """Fills a crown the pack's way: the light tone, clusters of the middle tone breaking it up,
    shade gathering to the lower right, the darkest tone along the bottom."""
    lt, mid, dk = tones
    s = ((XX - cx) * 0.55 + (YY - cy) * 0.85) / r
    n = noise2(seed + 1, W, H, 4)
    n2 = noise2(seed + 2, W, H, 3)
    a[m] = lt
    a[m & (s + (n - 0.5) * 1.2 > 0.1)] = mid
    a[m & (n2 > 0.7) & (s < 0.1)] = mid
    a[m & (s + (n2 - 0.5) * 0.8 > 0.7)] = dk


def tree(a, seed, cx, base, h, w, leaf=LEAF, bark=EARTH):
    """A broadleaf on the ground: a short trunk with a branch or two, under a wide mottled crown."""
    rng = random.Random(seed)
    cy = base - h + w * 0.42
    tw = max(4, int(w * 0.09))
    trunk = (XX >= cx - tw // 2) & (XX <= cx + tw // 2) & (YY > cy) & (YY < base)
    for k in range(1, 4):
        trunk |= (YY == base - k) & (np.abs(XX - cx) <= tw // 2 + (4 - k) // 2 + (k == 1))
    for side in (-1, 1):
        by = int(cy + w * 0.3 + rng.uniform(0, 6))
        for k in range(int(w * 0.18)):
            x = int(cx + side * (tw // 2 + k))
            trunk[by - k // 2: by - k // 2 + 2, x] = True
    _, lit, body, shade, dark = bark
    inked(a, trunk)
    a[trunk] = shade
    a[trunk & (XX <= cx - tw // 2 + 1)] = body
    a[trunk & (XX == cx - tw // 2 + 1) & (YY % 5 < 3)] = lit
    a[trunk & (XX >= cx + tw // 2)] = dark
    lobes = [(cx, cy, w * 0.42)]
    for _ in range(9):
        ang = rng.uniform(math.pi * 0.05, math.pi * 0.95)
        d = rng.uniform(0.2, 0.36) * w
        lobes.append((cx + math.cos(ang) * d * 1.2, cy - math.sin(ang) * d * 0.8 + w * 0.08,
                      w * rng.uniform(0.2, 0.3)))
    crown = crown_mask(seed, lobes)
    inked(a, crown)
    mottle(a, crown, seed, cx, cy, w * 0.5, (leaf[1], leaf[2], leaf[3]))


def ornamental_grass(a, seed, cx, base, h, w, plumes=6, leaf=LEAF,
                     plume=(WHITE, rgb("f9e6cf"), rgb("f6ca9f")), straw=rgb("edab50")):
    """A clump of fountain grass: blades rising from one tuft and arching out to either side, inked
    as one silhouette and stranded inside by alternating tones -- light on the lit side, dark on
    the shaded one; behind them, pampas plumes on straw stems, each feathered head nodding over
    at its tip and inked on its own."""
    rng = random.Random(seed)

    def path(x0, ang, length, droop):
        for i in range(int(length)):
            t = i / length
            yield (t, x0 + math.sin(ang) * i + math.copysign(droop * t ** 3 * length, ang),
                   base - math.cos(ang) * i + droop * 0.8 * t ** 3 * length)

    for _ in range(plumes):
        ang = rng.uniform(-0.4, 0.4)
        stem, head = np.zeros((H, W), bool), np.zeros((H, W), bool)
        for t, x, y in path(cx + rng.uniform(-w * 0.05, w * 0.05), ang, h * rng.uniform(1.15, 1.4),
                            rng.uniform(0.15, 0.3)):
            if t < 0.62:
                stem |= disc(x, y, 0.5)
            else:
                u = (t - 0.62) / 0.38
                head |= disc(x, y, 2.7 * math.sin(math.pi * min(0.97, u * 0.85 + 0.12)) ** 0.7
                             + rng.uniform(-0.3, 0.3))
        inked(a, stem | head)
        a[stem] = straw
        a[head] = plume[1]
        a[head & (~np.roll(head, 1, axis=1) | ~np.roll(head, 1, axis=0))] = plume[0]
        a[head & (~np.roll(head, -1, axis=1) | ~np.roll(head, -1, axis=0))] = plume[2]
    n = int(w / 2.6)
    blades = []
    for i in range(n):
        u = (i + 0.5) / n * 2 - 1
        m = np.zeros((H, W), bool)
        L = h * rng.uniform(0.7, 0.95) * (1 - abs(u) * 0.25)
        for t, x, y in path(cx + u * w * 0.1, u * rng.uniform(1.05, 1.3), L, 0.2 + abs(u) * 0.3):
            m |= disc(x, y, 1.5 * (1 - t) + 0.55)
        blades.append((abs(u), i, u, m))
    clump = np.zeros((H, W), bool)
    for *_, m in blades:
        clump |= m
    inked(a, clump)
    for _, i, u, m in sorted(blades, key=lambda b: (b[0], b[1])):
        if u < -0.25:
            c = leaf[0] if i % 2 else leaf[1]
        elif u > 0.25:
            c = leaf[2] if i % 2 else leaf[3]
        else:
            c = leaf[1] if i % 2 else leaf[2]
        a[m] = c
    a[clump & (YY >= base - 2)] = leaf[3]


def bush(a, seed, cx, base, w, h, tones=(LEAF[1], LEAF[2], LEAF[3])):
    rng = random.Random(seed)
    lobes = [(cx + (i / 3 - 0.5) * w * 0.6, base - h * rng.uniform(0.45, 0.6), h * 0.62)
             for i in range(4)]
    m = crown_mask(seed, lobes, rough=0.25, sy=1.3) & (YY < base)
    inked(a, m)
    mottle(a, m, seed, cx, base - h, max(w, h) * 0.5, tones)


def tufts(a, seed, count, x0=0, x1=W, top=FEET, tones=(LEAF[1], LEAF[2])):
    """Grass rising from the lip, inked blade by blade as the pack's grass sprites are."""
    rng = random.Random(seed)
    for _ in range(count):
        x = rng.randrange(x0, x1)
        m = np.zeros((H, W), bool)
        for i in range(rng.randint(2, 4)):
            bx = x + i * 2 + rng.randint(-1, 0)
            hh = rng.randint(3, 7)
            lean = rng.choice((-1, 0, 1))
            for k in range(hh):
                xx = bx + (lean if k > hh * 0.6 else 0)
                if 0 <= xx < W:
                    m[top - k, xx] = True
        inked(a, m)
        a[m] = tones[1]
        a[m & ~np.roll(m, 1, axis=0) & (YY < top - 2)] = tones[0]


def flower(a, x, base, h, petals=RED, stem=LEAF[3]):
    m_stem = (XX == x) & (YY > base - h) & (YY < base)
    leaves = ((YY == base - 3) & (np.abs(XX - x) <= 2)) | ((YY == base - 4) & (np.abs(XX - x) == 2))
    head = disc(x, base - h, 1.6)
    inked(a, m_stem | leaves | head)
    a[m_stem] = stem
    a[leaves] = LEAF[2]
    a[head] = petals[1]
    a[head & (XX < x) & (YY < base - h)] = petals[0]
    a[head & (XX > x) & (YY > base - h)] = petals[2]


def rock(a, cx, base, w, h, tones=STONE):
    m = (((XX - cx) / (w / 2)) ** 2 + ((YY - base) / h) ** 2 <= 1) & (YY < base)
    inked(a, m)
    hi, body, shd, dk = tones
    s = ((XX - cx) / (w / 2) * 0.6 + (YY - (base - h / 2)) / h * 0.8)
    a[m] = body
    a[m & (s > 0.35)] = shd
    a[m & (YY >= base - 1)] = dk
    a[m & (s < -0.55)] = hi


def fir(a, seed, cx, base, h, tones=(LEAF[2], LEAF[3], LEAF[4]), snow=None, ink=True):
    """A fir of stacked tiers, each a triangle with a ragged hem, lit left of the stem. Without
    `ink` it is a flat far silhouette; `snow` lies along the top of each tier's lit side."""
    rng = random.Random(seed)
    lit, mid, dk = tones
    tiers = max(3, h // 10)
    w = h * 0.3
    m = np.zeros((H, W), bool)
    tops = np.zeros((H, W), bool)
    for i in range(tiers):
        u0 = i / tiers
        bot = base - 3 - u0 * (h - 6)
        tall = (h - 6) / tiers * 1.7
        half = w * (1 - u0 * 0.8)
        v = (bot - YY) / tall
        t = (v >= 0) & (v <= 1) & (np.abs(XX - cx) <= half * (1 - v) + ((XX + i) % 3 == 0) * (v < 0.15))
        tops |= t & (v > 0.55)
        m |= t
    stem = (np.abs(XX - cx) <= 1) & (YY >= base - 4) & (YY < base)
    if ink:
        inked(a, m | stem)
        a[stem] = EARTH[3]
    a[m] = mid
    a[m & (XX < cx - 0.5)] = lit
    a[m & (XX > cx + w * 0.25)] = dk
    if snow is not None:
        cap = m & ~np.roll(m, 1, axis=0)
        cap |= np.roll(cap, 1, axis=0) & m
        a[cap & (XX < cx + 1)] = snow[0]
        a[cap & (XX >= cx + 1)] = snow[1]


def palm(a, seed, cx, base, h, lean=1):
    """A date palm: a ringed trunk bowing to one side, a head of arching fronds, a knot of dates."""
    rng = random.Random(seed)
    trunk = np.zeros((H, W), bool)
    for k in range(h):
        x = cx + lean * (k / h) ** 2 * h * 0.28
        half = 1.5 if k > 3 else 2.5
        trunk |= (YY == base - 1 - k) & (np.abs(XX - x) <= half)
    tx, ty = cx + lean * h * 0.28, base - h
    inked(a, trunk)
    a[trunk] = EARTH[2]
    a[trunk & ((base - YY) % 3 == 0)] = EARTH[3]
    a[trunk & ~np.roll(trunk, 1, axis=1)] = EARTH[1]
    fronds = np.zeros((H, W), bool)
    for ang in (-15, 20, 55, 125, 160, 195):
        L = h * rng.uniform(0.45, 0.6)
        r = math.radians(ang)
        for i in range(int(L)):
            t = i / L
            x = tx + math.cos(r) * i
            y = ty - math.sin(r) * i + (t ** 2) * L * 0.55
            fronds |= disc(x, y, 1.6 * (1 - t) + 0.6)
    inked(a, fronds)
    a[fronds] = LEAF[2]
    a[fronds & ~np.roll(fronds, 1, axis=0)] = LEAF[1]
    a[fronds & ~np.roll(fronds, -1, axis=0)] = LEAF[3]
    dates = disc(tx - 1, ty + 3, 2)
    inked(a, dates & ~fronds)
    a[dates & ~fronds] = EARTH[3]


def cairn(a, seed, cx, base, k=1.0, tones=STONE):
    """Flat stones stacked by travellers, each a little off the one below, each inked."""
    rng = random.Random(seed)
    y = base
    hi, body, shd, dk = tones
    for w in (18, 15, 12, 10, 7, 5):
        w, h = max(3, int(w * k)), max(2, int(4 * k))
        x0 = int(cx - w / 2) + rng.randint(-1, 1)
        m = (XX >= x0) & (XX < x0 + w) & (YY > y - h) & (YY <= y)
        m &= ~(((XX == x0) | (XX == x0 + w - 1)) & ((YY == y) | (YY == y - h + 1)))
        inked(a, m)
        a[m] = body
        a[m & (YY == y - h + 1)] = hi
        a[m & (YY == y)] = shd
        a[m & (XX >= x0 + w - 2)] = dk
        y -= h + 1


def shards(a, seed, cx, base, n, tones=(WHITE, rgb("94fdff"), rgb("0cf1ff"), rgb("0098dc"),
                                         rgb("0069aa"))):
    """Crystals of ice driven up out of the snow at angles, the tallest in the middle, each inked:
    the lit face, the ridge, the shaded face."""
    rng = random.Random(seed)
    hi, lt, mid, shd, dk = tones
    order = sorted(range(n), key=lambda i: -abs(i - (n - 1) / 2))
    for i in order:
        u = (i + 0.5) / n
        x = cx + (u - 0.5) * 70 + rng.uniform(-4, 4)
        h = int(rng.uniform(14, 22) + 34 * (1 - abs(u - 0.5) * 2) ** 1.5)
        lean = (u - 0.5) * 0.6 + rng.uniform(-0.1, 0.1)
        half = rng.uniform(3.5, 5.5)
        k = base - YY
        c0 = x + lean * k
        hw = np.where(k < h * 0.75, half, half * (h - k) / (h * 0.25))
        m = (k >= 0) & (k < h) & (np.abs(XX - c0) <= hw)
        inked(a, m)
        a[m] = shd
        a[m & (XX < c0)] = lt
        a[m & (np.abs(XX - c0) < 0.6)] = hi
        a[m & (XX > c0 + hw - 1.2)] = dk
        a[m & (XX < c0 - hw + 1.2) & (k % 4 == 0)] = hi


def pool(a, x0, x1, top=FEET, depth=5, water=(rgb("94fdff"), rgb("00cdf9"), rgb("0098dc"))):
    """Still water let into the ground strip: a basin cut under the lip, its surface a pale line
    with glints, darkening down, inked round its bed."""
    bed = (XX >= x0) & (XX <= x1) & (YY >= top) & (YY <= top + depth)
    bed &= ~(((XX == x0) | (XX == x1)) & (YY == top + depth))
    a[grow(bed) & ~bed & (YY >= top)] = INK
    a[bed] = water[1]
    a[bed & (YY == top)] = water[0]
    a[bed & (YY >= top + depth - 1)] = water[2]
    a[bed & (YY == top + 3) & ((XX * 7) % 11 < 3)] = water[0]


# ---------------------------------------------------------------- landmarks of the open land

def standing_stones(a, rng, cx, stone=STONE, lichen=None, snow=None, base=FEET):
    """Upright stones side on, rounded at the shoulders, the middle pair carrying a lintel."""
    n = rng.randint(4, 5)
    mid = n // 2 - 1
    hi, body, shd, dk = stone
    tops = {}
    for i in sorted(range(n), key=lambda i: -abs(i - (n - 1) / 2)):
        x = int(cx + (i - n / 2) * 17 + rng.randint(-2, 2))
        h = 34 if i in (mid, mid + 1) else rng.randint(18, 28)
        w = rng.randint(8, 10)
        m = (XX >= x) & (XX < x + w) & (YY >= base - h) & (YY < base)
        m &= ~((YY == base - h) & ((XX == x) | (XX == x + w - 1)))
        inked(a, m)
        a[m] = body
        a[m & (XX <= x + 1)] = hi
        a[m & (XX >= x + w - 2)] = shd
        a[m & (noise2(x, W, H, 2) > 0.76)] = shd if lichen is None else lichen
        if snow is not None:
            a[m & (YY <= base - h + 1)] = snow
        tops[i] = (x, w, base - h)
    (xa, wa, ta), (xb, wb, tb) = tops[mid], tops[mid + 1]
    t = min(ta, tb)
    lintel = (XX >= xa - 2) & (XX <= xb + wb + 1) & (YY >= t - 5) & (YY < t)
    inked(a, lintel)
    a[lintel] = body
    a[lintel & (YY == t - 5)] = hi if snow is None else snow
    a[lintel & (YY == t - 1)] = shd


def ruin(a, rng, cx, stone=STONE, base=FEET):
    """A colonnade nobody remembers: fluted columns broken off at different heights, the middle
    pair still carrying a stretch of entablature, drums fallen in the grass."""
    hi, body, shd, dk = stone
    tops = []
    for i in range(4):
        x = int(cx + (i - 2) * 22 + 4)
        h = rng.randint(50, 56) if i in (1, 2) else rng.randint(16, 36)
        plinth = (XX >= x - 2) & (XX <= x + 9) & (YY >= base - 3) & (YY < base)
        shaft = (XX >= x) & (XX <= x + 7) & (YY >= base - h) & (YY < base - 3)
        if i not in (1, 2):
            jag = noise2(x + 3, W, H, 1) * 4
            shaft &= YY >= base - h + jag
        m = plinth | shaft
        inked(a, m)
        a[m] = body
        a[m & (XX <= x + 1)] = hi
        a[shaft & ((XX == x + 3) | (XX == x + 5))] = shd
        a[m & (XX >= x + 7)] = dk
        a[plinth & (YY == base - 3)] = hi
        tops.append((x, base - h))
    (xa, ta), (xb, tb) = tops[1], tops[2]
    t = min(ta, tb)
    beam = (XX >= xa - 3) & (XX <= xb + 10) & (YY >= t - 7) & (YY < t)
    inked(a, beam)
    a[beam] = body
    a[beam & (YY == t - 7)] = hi
    a[beam & (YY == t - 4)] = shd
    a[beam & (YY == t - 1)] = dk
    for dx in (-58, 50):
        x = int(cx + dx)
        drum = (XX >= x) & (XX < x + 11) & (YY >= base - 6) & (YY < base)
        inked(a, drum)
        a[drum] = body
        a[drum & (YY == base - 6)] = hi
        a[drum & (XX >= x + 9)] = shd


def dead_tree(a, rng, cx, h, bark=(EARTH[1], EARTH[2], EARTH[3]), base=FEET):
    """Bare limbs forking up from a crooked trunk, inked as one."""
    m = np.zeros((H, W), bool)

    def limb(x, y, ang, ln, w):
        nonlocal m
        for _ in range(int(ln)):
            x += math.cos(ang)
            y -= math.sin(ang)
            m |= disc(x, y, w / 2)
            ang += rng.uniform(-0.12, 0.12)
        if ln > 5:
            for d in (-0.6, 0.5):
                limb(x, y, ang + d + rng.uniform(-0.2, 0.2), ln * rng.uniform(0.5, 0.68), max(1.0, w * 0.62))

    limb(cx, base, math.pi / 2 + rng.uniform(-0.1, 0.1), h * 0.42, 6)
    m |= (np.abs(XX - cx) <= 5 - (base - YY)) & (YY < base) & (YY >= base - 4)
    inked(a, m)
    lit, body, shd = bark
    a[m] = body
    a[m & ~np.roll(m, 1, axis=1)] = lit
    a[m & ~np.roll(m, -1, axis=1)] = shd


def log(a, rng, x, ln, bark=OAK_BARK, cut=(rgb("e69c69"), rgb("bf6f4a")), base=FEET):
    """A fallen trunk across the clearing, moss along its back, its cut end ringed, a scatter of
    red toadstools at its foot."""
    h = 12
    m = (XX >= x) & (XX <= x + ln) & (YY >= base - h) & (YY < base)
    m &= ~((XX == x) & ((YY == base - h) | (YY == base - 1)))
    end = (((XX - (x + ln)) / 3.2) ** 2 + ((YY - (base - h / 2 - 0.5)) / (h / 2)) ** 2 <= 1)
    inked(a, m | end)
    lit, body, shd = bark
    a[m] = body
    a[m & (YY <= base - h + 1)] = lit
    a[m & (YY >= base - 2)] = shd
    a[m & ((XX + (YY // 3) * 4) % 9 == 0) & (YY > base - h + 1)] = shd
    a[end] = cut[0]
    a[end & (((XX - (x + ln)) / 2) ** 2 + ((YY - (base - h / 2 - 0.5)) / 3.5) ** 2 <= 1)] = cut[1]
    a[end & disc(x + ln, base - h / 2 - 0.5, 1.1)] = cut[0]
    for k in range(x + 2, x + ln - 2):
        if rng.random() < 0.6:
            a[base - h, k] = LEAF[1]
            if rng.random() < 0.4:
                a[base - h - 1, k] = LEAF[2]
    for _ in range(rng.randint(4, 6)):
        mx = rng.choice((rng.randint(x - 16, x - 3), rng.randint(x + ln + 6, x + ln + 18)))
        mh = rng.randint(3, 5)
        stem = (XX == mx) & (YY > base - mh) & (YY < base)
        cap = ((YY == base - mh) & (np.abs(XX - mx) <= 2)) | ((YY == base - mh - 1) & (np.abs(XX - mx) <= 1))
        inked(a, stem | cap)
        a[stem] = rgb("f9e6cf")
        a[cap] = RED[1]
        a[cap & (XX < mx)] = RED[0]
        a[cap & (YY == base - mh - 1) & (XX == mx)] = WHITE


def cattails(a, rng, x0, x1, n, stem=LEAF[2], head=(EARTH[2], EARTH[3]), base=FEET):
    """Bulrushes at the water's edge: tall stems, a brown head near each top, a blade or two."""
    for _ in range(n):
        x = rng.randint(x0, x1)
        h = rng.randint(11, 19)
        lean = rng.choice((-1, 0, 1))
        m = np.zeros((H, W), bool)
        for k in range(h):
            m[base - 1 - k, x + (lean if k > h * 0.6 else 0)] = True
        tip = x + lean
        cob = (np.abs(XX - tip) <= 1) & (YY >= base - h + 1) & (YY <= base - h + 5)
        blade = np.zeros((H, W), bool)
        side = rng.choice((-1, 1))
        for k in range(rng.randint(6, 10)):
            blade[base - 1 - k, x + side * (k // 3)] = True
        inked(a, m | cob | blade)
        a[m | blade] = stem
        a[cob] = head[0]
        a[cob & (XX > tip)] = head[1]


def pond(a, rng, cx, half, water=(rgb("94fdff"), rgb("00cdf9"), rgb("0098dc")), frozen=False,
         rocks=STONE):
    """Still water let into the ground: bulrushes at its ends, a plank jetty out from one bank, lily
    pads on it -- or, `frozen`, an ice sheet with cracks in it, the rushes gone grey, snow on the
    stones."""
    x0, x1 = int(cx - half), int(cx + half)
    pool(a, x0, x1, water=water)
    if frozen:
        for _ in range(5):
            x, y = rng.randint(x0 + 4, x1 - 8), FEET + rng.randint(1, 3)
            for k in range(rng.randint(3, 6)):
                a[y + (k % 2), x + k] = water[2]
        cattails(a, rng, x0 - 8, x0 + 2, 4, stem=rgb("92a1b9"), head=(WHITE, rgb("c7cfdd")))
        cattails(a, rng, x1 - 2, x1 + 8, 3, stem=rgb("92a1b9"), head=(WHITE, rgb("c7cfdd")))
    else:
        cattails(a, rng, x0 - 8, x0 + 3, 5)
        cattails(a, rng, x1 - 3, x1 + 8, 4)
        jx = x1 - rng.randint(20, 26)
        deck = (XX >= jx) & (XX <= x1 + 6) & (YY >= FEET - 3) & (YY < FEET - 1)
        posts = ((XX == jx + 2) | (XX == jx + 12)) & (YY >= FEET - 1) & (YY <= FEET + 3)
        inked(a, deck | posts)
        a[deck] = EARTH[1]
        a[deck & (YY == FEET - 3)] = EARTH[0]
        a[deck & ((XX - jx) % 4 == 3)] = EARTH[2]
        a[posts] = EARTH[3]
        for x in (x0 + rng.randint(8, 14), x0 + rng.randint(26, 34)):
            pad = (np.abs(XX - x) <= 2) & (YY == FEET - 1)
            inked(a, pad)
            a[pad] = LEAF[2]
            a[pad & (XX < x)] = LEAF[1]
            a[FEET - 2, x] = rgb("f68187")
    rock(a, cx - half - 16, FEET, 10, 6, tones=rocks)
    rock(a, cx + half + 15, FEET, 7, 4, tones=rocks)
    if frozen:
        for rx, rw, rh in ((cx - half - 16, 10, 6), (cx + half + 15, 7, 4)):
            cap = (((XX - rx) / (rw / 2)) ** 2 + ((YY - FEET) / rh) ** 2 <= 1) & (YY < FEET - rh + 2)
            a[cap] = WHITE


# ---------------------------------------------------------------- by the road

def signpost(a, x, wood=EARTH, base=FEET):
    """A fingerpost: a squared post, one arm pointing each way, a cap."""
    post = (XX >= x) & (XX <= x + 2) & (YY >= base - 30) & (YY < base)
    cap = (XX >= x - 1) & (XX <= x + 3) & (YY >= base - 32) & (YY < base - 30)
    arms = np.zeros((H, W), bool)
    for (y, d) in ((base - 27, 1), (base - 19, -1)):
        xa = x + 3 if d > 0 else x - 14
        arms |= (XX >= xa) & (XX <= xa + 11) & (YY >= y) & (YY < y + 5)
        for k in range(3):
            tip = xa + 12 + k if d > 0 else xa - 1 - k
            arms |= (XX == tip) & (YY >= y + k) & (YY < y + 5 - k)
    inked(a, post | cap | arms)
    a[post | cap] = wood[3]
    a[post & (XX == x)] = wood[2]
    a[arms] = wood[1]
    a[arms & ~np.roll(arms, 1, axis=0)] = wood[0]
    a[arms & ~np.roll(arms, -1, axis=0)] = wood[2]
    a[arms & (YY % 5 == 2) & (XX % 2 == 0) & ~((XX >= x) & (XX <= x + 2))] = wood[3]


def milestone(a, x, stone=STONE, base=FEET):
    m = (XX >= x - 4) & (XX <= x + 4) & (YY >= base - 14) & (YY < base)
    m &= ~((YY <= base - 13) & (np.abs(XX - x) >= 3)) & ~((YY == base - 12) & (np.abs(XX - x) == 4))
    inked(a, m)
    hi, body, shd, dk = stone
    a[m] = body
    a[m & (XX <= x - 3)] = hi
    a[m & (XX >= x + 3)] = shd
    for k in range(3):
        a[(YY == base - 10 + k * 3) & (np.abs(XX - x) <= 1)] = dk


def fence(a, x0, x1, wood=EARTH, base=FEET):
    """A split-rail fence: squared posts and two rails between them."""
    rails = (XX >= x0) & (XX <= x1) & (((YY >= base - 11) & (YY < base - 9)) |
                                        ((YY >= base - 6) & (YY < base - 4)))
    posts = np.zeros((H, W), bool)
    for px in range(int(x0), int(x1) + 1, 13):
        posts |= (XX >= px) & (XX <= px + 2) & (YY >= base - 14) & (YY < base)
    inked(a, rails | posts)
    a[rails] = wood[1]
    a[rails & ~np.roll(rails, 1, axis=0)] = wood[0]
    a[posts] = wood[2]
    a[posts & ~np.roll(posts, 1, axis=1)] = wood[1]


def cart(a, x, wood=EARTH, load=(rgb("f6ca9f"), rgb("e69c69")), base=FEET):
    """A two-wheeled hand cart left by the road, its shafts down, two sacks in it."""
    bed = (XX >= x) & (XX <= x + 30) & (YY >= base - 20) & (YY < base - 11)
    shafts = np.zeros((H, W), bool)
    for k in range(16):
        shafts |= (XX == x + 31 + k) & (YY >= base - 12 + k * 11 // 16) & (YY <= base - 11 + k * 11 // 16)
    sacks = disc(x + 8, base - 23, 5, 1.3) | disc(x + 19, base - 22, 4.5, 1.4)
    sacks &= YY < base - 19
    wheel = disc(x + 11, base - 8, 7.5)
    inked(a, bed | shafts | sacks | wheel)
    a[bed] = wood[1]
    a[bed & (YY == base - 20)] = wood[0]
    a[bed & ((XX - x) % 8 == 7)] = wood[2]
    a[shafts] = wood[2]
    a[sacks] = load[0]
    a[sacks & (XX > x + 12)] = load[1]
    a[wheel] = wood[3]
    ring = wheel & ~disc(x + 11, base - 8, 5.6)
    a[ring] = wood[2]
    spokes = wheel & ((np.abs(XX - (x + 11)) < 0.6) | (np.abs(YY - (base - 8)) < 0.6))
    a[spokes] = wood[1]
    a[disc(x + 11, base - 8, 1.2)] = wood[0]


# ---------------------------------------------------------------- the places

PALE = rgb("94fdff")
WARM_STONE = (rgb("f6ca9f"), rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836"))
SAND_ROCK = WARM_STONE
ROAD = (rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836"), rgb("5d2c28"))


def back_grass(a, rng, s):
    """A bright morning: the pack's two blues, heaped cloud, a blue-grey range, green hills
    darkening forward."""
    sky(a, ((rgb("0098dc"), 0), (rgb("00cdf9"), 96)))
    cloud(a, rng, rng.uniform(170, 230), 138, 260, 48, lit=PALE, body=PALE)
    cloud(a, rng, rng.uniform(20, 70), rng.uniform(124, 136), rng.uniform(100, 130), rng.uniform(52, 66))
    cloud(a, rng, rng.uniform(300, 360), rng.uniform(120, 132), rng.uniform(110, 140), rng.uniform(48, 60))
    cloud(a, rng, rng.uniform(120, 280), rng.uniform(34, 50), rng.uniform(36, 56), rng.uniform(12, 18))
    ranges(a, s + 1, 150, 62, 5, rgb("657392"), rgb("92a1b9"))
    hills(a, s + 2, 164, 26, rgb("1e6f50"), rgb("33984b"))
    return hills(a, s + 3, 176, 12, rgb("134c4c"), rgb("1e6f50"), ((3, 1.0), (7, 0.5), (15, 0.15)))


def back_forest(a, rng, s):
    """A clearing in the wood: pale morning over three walls of crowns darkening forward, the
    canopy hanging over the top edge (drawn last, by `dress_forest`)."""
    sky(a, ((rgb("00cdf9"), 0), (rgb("94fdff"), 120)))
    cloud(a, rng, rng.uniform(270, 330), rng.uniform(106, 116), rng.uniform(90, 120), rng.uniform(36, 46))
    cloud(a, rng, rng.uniform(40, 90), rng.uniform(98, 108), rng.uniform(80, 100), rng.uniform(30, 38))
    wood(a, s + 1, 132, 20, rgb("33984b"), rgb("5ac54f"))
    wood(a, s + 2, 152, 18, rgb("1e6f50"), rgb("33984b"))
    wood(a, s + 3, 170, 15, rgb("134c4c"), rgb("1e6f50"))
    return None


def back_dirt(a, rng, s):
    """Golden hour on the steppe: a low sun in bands of plum, rose and amber, buttes of red rock
    darkening forward."""
    sky(a, ((rgb("622461"), 0), (rgb("93388f"), 34), (rgb("c85086"), 70), (rgb("f68187"), 100),
            (rgb("edab50"), 124), (rgb("ffc825"), 142)))
    sun(a, rng.uniform(60, 324), 114, 14, rgb("ffeb57"), rgb("f9e6cf"), halo=rgb("ffc825"))
    cloud(a, rng, rng.uniform(60, 140), rng.uniform(56, 70), 120, 22, lit=rgb("fdd2ed"),
          body=rgb("f68187"), bump=(5, 9))
    cloud(a, rng, rng.uniform(230, 320), rng.uniform(34, 46), 90, 16, lit=rgb("fdd2ed"),
          body=rgb("f68187"), bump=(5, 8))
    mesas(a, s + 1, 162, 4, (112, 136), (50, 110), rgb("93388f"), rgb("c85086"))
    mesas(a, s + 2, 172, 3, (130, 150), (40, 80), rgb("8e251d"), rgb("c64524"), rgb("571c27"))
    return hills(a, s + 3, 178, 8, rgb("571c27"), rgb("8e251d"))


def back_desert(a, rng, s):
    """Noon over the dunes: a hard blue fading to a cream haze, a small white sun, dunes darkening
    forward."""
    sky(a, ((rgb("0098dc"), 0), (rgb("00cdf9"), 76), (rgb("94fdff"), 128), (rgb("f9e6cf"), 150)))
    sun(a, rng.uniform(40, 340), rng.uniform(24, 40), 8, WHITE, rgb("ffeb57"), halo=PALE)
    cloud(a, rng, rng.uniform(60, 320), rng.uniform(50, 66), rng.uniform(50, 70), 14, bump=(4, 7))
    dunes(a, s + 1, 164, 4, 30, rgb("e69c69"), rgb("f9e6cf"))
    dunes(a, s + 2, 174, 3, 24, rgb("bf6f4a"), rgb("f6ca9f"))
    dunes(a, s + 3, 180, 3, 12, rgb("8a4836"), rgb("e69c69"))
    return None


def back_mountains(a, rng, s):
    """A crisp alpine valley: deep blue over two snowy ranges, fir slopes, a meadow."""
    sky(a, ((rgb("0069aa"), 0), (rgb("0098dc"), 58), (rgb("00cdf9"), 112)))
    cloud(a, rng, rng.uniform(40, 120), rng.uniform(62, 76), rng.uniform(80, 110), rng.uniform(26, 32))
    cloud(a, rng, rng.uniform(260, 340), rng.uniform(46, 58), rng.uniform(70, 90), rng.uniform(20, 24))
    snow = (WHITE, rgb("c7cfdd"))
    ranges(a, s + 1, 160, 120, 4, rgb("657392"), rgb("92a1b9"), snow=snow, snowline=92,
           slope=(0.8, 1.3))
    ranges(a, s + 2, 170, 64, 5, rgb("424c6e"), rgb("657392"), snow=snow, snowline=128,
           slope=(0.9, 1.4))
    x = -4.0
    while x < W + 6:
        fir(a, int(s + x), int(x), 176, rng.randint(14, 24), (LEAF[3], LEAF[4], rgb("0c2e44")),
            ink=False)
        x += rng.uniform(4, 9)
    return hills(a, s + 3, 178, 6, rgb("1e6f50"), rgb("33984b"))


def back_ice(a, rng, s):
    """Twilight on the snowfield: night coming down in bands over a rose horizon, stars, the aurora,
    peaks in alpenglow, snowbound firs."""
    sky(a, ((rgb("1a1932"), 0), (rgb("2a2f4e"), 34), (rgb("3b1443"), 70), (rgb("622461"), 98),
            (rgb("93388f"), 120), (rgb("c85086"), 138), (rgb("f68187"), 152)))
    stars(a, s, 110, 110)
    aurora(a, s + 1, rng.uniform(52, 70), 40, (rgb("99e65f"), rgb("5ac54f"), rgb("1e6f50")))
    ranges(a, s + 2, 164, 70, 5, rgb("424c6e"), rgb("657392"),
           snow=(rgb("fdd2ed"), rgb("92a1b9")), snowline=130)
    x = -4.0
    while x < W + 6:
        fir(a, int(s + x), int(x), 174, rng.randint(12, 22),
            (rgb("2a2f4e"), rgb("1a1932"), rgb("0e071b")), snow=(rgb("c7cfdd"), rgb("92a1b9")),
            ink=False)
        x += rng.uniform(5, 11)
    return hills(a, s + 3, 180, 8, rgb("92a1b9"), rgb("c7cfdd"))


def dress_grass(a, rng, s, variant):
    bush(a, s + 6, 22, FEET, 30, 12)
    bush(a, s + 7, 352, FEET, 24, 10)
    for x in (rng.randint(112, 126), rng.randint(258, 262), 320):
        flower(a, x, FEET, rng.randint(5, 8))
    tufts(a, s + 8, 22 if variant != "road" else 10)


def dress_forest(a, rng, s, variant):
    bush(a, s + 6, 30, FEET, 34, 13)
    bush(a, s + 7, 356, FEET, 30, 12)
    for x in (58, rng.randint(318, 326), 336):
        flower(a, x, FEET, rng.randint(5, 7))
    tufts(a, s + 8, 24 if variant != "road" else 10, tones=(LEAF[2], LEAF[3]))
    lobes = []
    for x in range(-10, W + 20, 14):
        edge = abs(x / W - 0.5) * 2
        lobes.append((x, rng.uniform(-8, -2) + edge * 8, rng.uniform(9, 13) + edge * 8))
    can = crown_mask(s + 9, lobes, rough=0.35)
    inked(a, can)
    mottle(a, can, s + 9, W / 2, -40, 60, (LEAF[1], LEAF[2], LEAF[3]))


def dress_dirt(a, rng, s, variant):
    bush(a, s + 8, 24, FEET, 26, 10, tones=(GOLD[2], EARTH[1], EARTH[2]))
    bush(a, s + 9, 352, FEET, 22, 9, tones=(GOLD[2], EARTH[1], EARTH[2]))
    tufts(a, s + 10, 16 if variant != "road" else 8, tones=(GOLD[2], EARTH[1]))


def dress_desert(a, rng, s, variant):
    bush(a, s + 10, 28, FEET, 20, 8, tones=(LEAF[2], LEAF[3], LEAF[4]))
    rock(a, 342, FEET, 9, 5, tones=SAND_ROCK)


def dress_mountains(a, rng, s, variant):
    fir(a, s + 5, 22, FEET, 76)
    fir(a, s + 6, 360, FEET, 64)
    for x, pet in ((rng.randint(118, 130), (WHITE, CLOUD, rgb("92a1b9"))), (300, GOLD),
                   (rng.randint(262, 268), (WHITE, CLOUD, rgb("92a1b9")))):
        flower(a, x, FEET, rng.randint(5, 6), petals=pet)
    tufts(a, s + 10, 20 if variant != "road" else 8)


def dress_ice(a, rng, s, variant):
    dark = (rgb("2a2f4e"), rgb("1a1932"), rgb("0e071b"))
    fir(a, s + 6, 24, FEET, 66, dark, snow=(WHITE, rgb("c7cfdd")))
    fir(a, s + 7, 358, FEET, 58, dark, snow=(WHITE, rgb("c7cfdd")))


def grass_trio(a, rng, s):
    ornamental_grass(a, s + 5, 188, FEET, 38, 70, plumes=6)
    ornamental_grass(a, s + 11, 140, FEET, 24, 40, plumes=3)
    ornamental_grass(a, s + 12, 230, FEET, 26, 40, plumes=3)
    rock(a, 164, FEET, 10, 6)
    rock(a, 258, FEET, 7, 4)


def oasis(a, rng, s):
    pool(a, 160, 232)
    palm(a, s + 5, 150, FEET, 70, lean=-1)
    palm(a, s + 6, 240, FEET, 60, lean=1)
    palm(a, s + 7, 196, FEET - 1, 82, lean=1)
    tufts(a, s + 8, 8, 150, 166)
    tufts(a, s + 9, 8, 226, 244)
    rock(a, 120, FEET, 12, 6, tones=SAND_ROCK)


def cairns(stone):
    def draw(a, rng, s):
        cairn(a, s + 7, 170, FEET, 1.2, tones=stone)
        cairn(a, s + 8, 214, FEET, 0.9, tones=stone)
        cairn(a, s + 9, 246, FEET, 0.7, tones=stone)
        rock(a, 138, FEET, 10, 6, tones=stone)
    return draw


def ice_field(a, rng, s):
    shards(a, s + 5, 192, FEET + 1, 7)
    rock(a, 132, FEET, 11, 6)
    rock(a, 252, FEET, 8, 4)


PLACES = {
    "grass": dict(
        back=back_grass, dress=dress_grass, ground={}, road=ROAD,
        plains=(grass_trio,
                lambda a, rng, s: pond(a, rng, 192, 44),
                lambda a, rng, s: standing_stones(a, rng, 192),
                lambda a, rng, s: ruin(a, rng, 192))),
    "forest": dict(
        back=back_forest, dress=dress_forest,
        ground=dict(grass=(LEAF[1], LEAF[2], LEAF[3], LEAF[4], rgb("0c2e44"))),
        road=(rgb("bf6f4a"), rgb("8a4836"), rgb("5d2c28"), rgb("391f21")),
        plains=(lambda a, rng, s: log(a, rng, 156, 70),
                lambda a, rng, s: pond(a, rng, 192, 44, water=(PALE, rgb("0cf1ff"), rgb("0069aa"))),
                lambda a, rng, s: standing_stones(a, rng, 192, lichen=LEAF[2]),
                lambda a, rng, s: tree(a, s + 5, 190, FEET, 100, 86))),
    "dirt": dict(
        back=back_dirt, dress=dress_dirt,
        ground=dict(grass=(rgb("f6ca9f"), rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836"), None),
                    earth=(rgb("f6ca9f"), rgb("bf6f4a"), rgb("8a4836"), rgb("5d2c28"), rgb("391f21"))),
        road=(rgb("f6ca9f"), rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836")),
        plains=(lambda a, rng, s: dead_tree(a, rng, 190, 96),
                cairns(WARM_STONE),
                lambda a, rng, s: standing_stones(a, rng, 192, stone=WARM_STONE),
                lambda a, rng, s: ruin(a, rng, 192, stone=WARM_STONE))),
    "desert": dict(
        back=back_desert, dress=dress_desert,
        ground=dict(grass=(rgb("f9e6cf"), rgb("f6ca9f"), rgb("e69c69"), rgb("bf6f4a"), None),
                    earth=(rgb("f9e6cf"), rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836"), rgb("5d2c28")),
                    streaks=False),
        road=(rgb("e69c69"), rgb("bf6f4a"), rgb("8a4836"), rgb("5d2c28")),
        plains=(oasis,
                lambda a, rng, s: ruin(a, rng, 192, stone=SAND_ROCK),
                lambda a, rng, s: standing_stones(a, rng, 192, stone=SAND_ROCK),
                lambda a, rng, s: dead_tree(a, rng, 190, 90, bark=(rgb("f6ca9f"), rgb("bf6f4a"),
                                                                   rgb("8a4836"))))),
    "mountains": dict(
        back=back_mountains, dress=dress_mountains,
        ground=dict(earth=(rgb("c7cfdd"), rgb("92a1b9"), rgb("657392"), rgb("424c6e"), rgb("2a2f4e"))),
        road=(rgb("c7cfdd"), rgb("92a1b9"), rgb("657392"), rgb("424c6e")), paved=True,
        plains=(cairns(STONE),
                lambda a, rng, s: pond(a, rng, 192, 44, water=(PALE, rgb("0098dc"), rgb("0069aa"))),
                lambda a, rng, s: fir(a, s + 5, 192, FEET, 104),
                lambda a, rng, s: ruin(a, rng, 192))),
    "ice": dict(
        back=back_ice, dress=dress_ice,
        ground=dict(grass=(WHITE, rgb("c7cfdd"), rgb("92a1b9"), rgb("657392"), None),
                    earth=(PALE, rgb("657392"), rgb("424c6e"), rgb("2a2f4e"), rgb("1a1932")),
                    streaks=False),
        road=(rgb("c7cfdd"), rgb("92a1b9"), rgb("657392"), rgb("424c6e")),
        plains=(ice_field,
                lambda a, rng, s: pond(a, rng, 192, 44, water=(WHITE, PALE, rgb("0098dc")),
                                       frozen=True),
                lambda a, rng, s: dead_tree(a, rng, 190, 90, bark=(rgb("92a1b9"), rgb("657392"),
                                                                   rgb("424c6e"))),
                lambda a, rng, s: standing_stones(a, rng, 192, snow=WHITE))),
}
ENVS = tuple(PLACES)
VARIANTS = ("plain", "road", "village", "town", "fortress")
LAYOUTS = 4


def road_side(a, rng, layout, wood=EARTH, stone=STONE):
    """What stands by the road: a fingerpost; a milestone and a fence; a cart and a milestone; a
    fingerpost and a milestone."""
    if layout == 1:
        signpost(a, 190)
    elif layout == 2:
        fence(a, 124, 254)
        milestone(a, 200, stone)
    elif layout == 3:
        cart(a, 150)
        milestone(a, 236, stone)
    else:
        signpost(a, 176)
        milestone(a, 228, stone)


def render(env, variant="plain", layout=1, seed=0):
    """One backdrop, 384x216. Every (variant, layout) is seeded apart, so each has its own sky and
    land, not only its own settlement."""
    import sideview_kits as kits
    s = seed + layout * 101 + VARIANTS.index(variant) * 17
    P = PLACES[env]
    a = np.zeros((H, W, 3), np.uint8)
    P["back"](a, random.Random(s), s)
    if variant in ("village", "town", "fortress"):
        kits.settle(a, env, variant, layout, s, "back")
    road = dict(road=P["road"], paved=P.get("paved", False)) if variant == "road" else {}
    ground(a, s + 4, **P["ground"], **road)
    rng = random.Random(s + 5)
    if variant == "plain":
        P["plains"][layout - 1](a, rng, s)
    elif variant == "road":
        road_side(a, rng, layout, stone=WARM_STONE if env in ("dirt", "desert") else STONE)
    else:
        kits.settle(a, env, variant, layout, s, "front")
    P["dress"](a, random.Random(s + 6), s, variant)
    stray = {tuple(c) for c in np.unique(a.reshape(-1, 3), axis=0)} - PALETTE
    assert not stray, f"{env} {variant} {layout}: colours outside ENDESGA 64: {sorted(stray)[:5]}"
    return Image.fromarray(a, "RGB")


# ---------------------------------------------------------------- preview

def _idle(path):
    """The first figure on an idle strip, cropped to what it draws."""
    im = Image.open(path).convert("RGBA")
    al = np.array(im)[:, :, 3] > 0
    cols = al.any(axis=0)
    x0 = int(np.argmax(cols))
    x1 = x0
    while x1 < im.width and cols[x1]:
        x1 += 1
    f = im.crop((x0, 0, x1, im.height))
    return f.crop(f.getbbox())


def with_fighters(scene):
    """The hero and a Masked Orc at one backdrop pixel a pixel -- what CombatActor's snap gives
    both on this grid -- their feet on FEET, each over the fight's contact shadow."""
    bg = scene.convert("RGBA")
    for path, cx, flip in (("../Assets/Player/idle.png", PLAYER_X, False),
                           ("../Assets/Enemies/Masked Orc/Sprites/IDLE.png", ENEMY_X, True)):
        f = _idle(path)
        if flip:
            f = f.transpose(Image.FLIP_LEFT_RIGHT)
        sw, sh = int(f.width * 0.55), max(2, int(f.width * 0.55 / 4))
        shadow = Image.new("RGBA", (sw, sh))
        sa = np.zeros((sh, sw, 4), np.uint8)
        yy, xx = np.mgrid[0:sh, 0:sw]
        sa[((xx - sw / 2 + 0.5) / (sw / 2)) ** 2 + ((yy - sh / 2 + 0.5) / (sh / 2)) ** 2 <= 1] = \
            (15, 10, 23, 82)
        shadow = Image.fromarray(sa, "RGBA")
        bg.alpha_composite(shadow, (int(cx - sw / 2), FEET - sh // 2))
        bg.alpha_composite(f, (int(cx - f.width / 2), FEET - f.height))
    return bg.convert("RGB")


if __name__ == "__main__":
    # sideview.py <tag> [env ...] [variant ...] [layout ...]: a sheet per place, variants down and
    # layouts across; one scene alone comes out at the game's 3x
    tag = sys.argv[1] if len(sys.argv) > 1 else "t"
    args = sys.argv[2:]
    envs = [x for x in args if x in PLACES] or list(PLACES)
    variants = [x for x in args if x in VARIANTS] or list(VARIANTS)
    layouts = [int(x) for x in args if x.isdigit()] or list(range(1, LAYOUTS + 1))
    for e in envs:
        cells = [[with_fighters(render(e, vv, l)) for l in layouts] for vv in variants]
        out = Image.new("RGB", (W * len(layouts) + 4 * (len(layouts) - 1),
                                H * len(variants) + 4 * (len(variants) - 1)), (20, 20, 20))
        for r, line in enumerate(cells):
            for c, im in enumerate(line):
                out.paste(im, (c * (W + 4), r * (H + 4)))
        if len(variants) * len(layouts) == 1:
            out = out.resize((out.width * 3, out.height * 3), Image.NEAREST)
        out.save(f"qa/side_{tag}_{e}.png")
        print(f"qa/side_{tag}_{e}.png")
