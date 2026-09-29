"""Vista: the second-generation battle backdrops, drawn in layers of depth.

A scene is painted back to front -- sky, clouds, far range, middle hills, the settlement, the near
ground, the foreground -- and every layer further back is pulled toward the sky's haze colour, so
depth reads from value alone. Each layer publishes its surface line (`Layer.top`), and anything
built on a layer is seated on that line by construction: a footprint reaches down to the lowest
ground under it, so nothing can hang in the air.

Native size is 576x324 (exported at 4x), the same grid as the first backdrops.
"""
import math
import random

import numpy as np
from PIL import Image

W, H = 576, 324
SCALE = 4

BAYER = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0
_BY = np.tile(BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]


# ---------------------------------------------------------------- colour

def rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(round(int(a[i]) + (int(b[i]) - int(a[i])) * t)) for i in range(3))


def shade(c, k):
    """k < 0 darkens toward a cool shadow, k > 0 lightens toward a warm light."""
    if k < 0:
        return mix(c, (24, 20, 48), -k)
    return mix(c, (255, 250, 228), k)


# ---------------------------------------------------------------- noise

def smooth(seed, n, k, wrap=False):
    rng = random.Random(seed)
    pts = [rng.random() for _ in range(k + 2)]
    out = np.empty(n)
    for i in range(n):
        t = i / n * k
        a = int(t)
        f = t - a
        f = f * f * (3 - 2 * f)
        b = (a + 1) % k if wrap else a + 1
        out[i] = pts[a] * (1 - f) + pts[b] * f
    return out


def fbm(seed, n, octaves):
    """octaves = ((lattice points, amplitude), ...) -> array in 0..1."""
    out = np.zeros(n)
    tot = 0.0
    for i, (k, a) in enumerate(octaves):
        out += smooth(seed * 977 + i * 31, n, k) * a
        tot += a
    return out / tot


def noise2(seed, w, h, cell):
    """Smooth 2D value noise, 0..1."""
    rng = np.random.default_rng(seed)
    gw, gh = w // cell + 2, h // cell + 2
    g = rng.random((gh, gw))
    ys = np.arange(h) / cell
    xs = np.arange(w) / cell
    y0 = ys.astype(int)
    x0 = xs.astype(int)
    fy = ys - y0
    fx = xs - x0
    fy = fy * fy * (3 - 2 * fy)
    fx = fx * fx * (3 - 2 * fx)
    a = g[y0][:, x0]
    b = g[y0][:, x0 + 1]
    c = g[y0 + 1][:, x0]
    d = g[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bot = c + (d - c) * fx[None, :]
    return top + (bot - top) * fy[:, None]


# ---------------------------------------------------------------- canvas

class Canvas:
    def __init__(self):
        self.a = np.zeros((H, W, 3), np.uint8)

    def fill(self, mask, c):
        self.a[mask] = c

    def dfill(self, mask, c, t):
        """Paints c over the mask where the Bayer threshold falls under t (a scalar or an array)."""
        t = np.broadcast_to(np.asarray(t, float), (H, W))
        self.a[mask & (_BY < t)] = c

    def tint(self, mask, c, t, levels=4, seam=0.18):
        """Pulls the pixels under the mask toward c by t (0..1, scalar or array), in `levels` flat
        steps with only a thin dithered seam between them -- a wash, never a mesh."""
        t = np.broadcast_to(np.asarray(t, float), (H, W))
        q = np.clip(t, 0, 1) * levels
        lvl = np.floor(q)
        f = q - lvl
        up = (f > 1 - seam) & (_BY < (f - (1 - seam)) / seam)
        lvl = np.minimum(levels, lvl + up)
        c = np.array(c, float)
        for k in range(1, levels + 1):
            m = mask & (lvl == k)
            if m.any():
                a = self.a[m].astype(float)
                self.a[m] = np.round(a + (c - a) * (k / levels)).astype(np.uint8)

    def px(self, x, y, c):
        if 0 <= x < W and 0 <= y < H:
            self.a[y, x] = c

    def rect(self, x0, y0, x1, y1, c):
        x0, x1 = max(0, x0), min(W - 1, x1)
        y0, y1 = max(0, y0), min(H - 1, y1)
        if x1 >= x0 and y1 >= y0:
            self.a[y0:y1 + 1, x0:x1 + 1] = c

    def image(self):
        return Image.fromarray(self.a, "RGB")

    def export(self, path):
        self.image().resize((W * SCALE, H * SCALE), Image.NEAREST).save(path)


YY, XX = np.mgrid[0:H, 0:W]


def below(line):
    """Mask of every pixel at or under a per-column surface line."""
    return YY >= np.asarray(line)[None, :]


# ---------------------------------------------------------------- sky

def sky(cv, stops, horizon, bands=9, soft=0.45):
    """Stepped gradient: `stops` are colours from the zenith down to the horizon. It is cut into
    `bands` flat steps, each blending into the next with an ordered dither over its lower part --
    how hand-painted pixel skies are banded."""
    for y in range(H):
        p = min(1.0, y / horizon) * (bands - 1)
        i = int(p)
        f = p - i
        c0 = _grad(stops, i / (bands - 1))
        c1 = _grad(stops, min(1.0, (i + 1) / (bands - 1)))
        t = max(0.0, (f - (1 - soft)) / soft)
        row = np.where(BAYER[y % 4][np.arange(W) % 4] < t, 1, 0)
        cv.a[y] = np.where(row[:, None] == 1, np.array(c1, np.uint8), np.array(c0, np.uint8))


def _grad(stops, t):
    n = len(stops) - 1
    p = t * n
    i = min(int(p), n - 1)
    return mix(stops[i], stops[i + 1], p - i)


def glow(cv, cx, cy, r, c, strength=0.6, top=0, bottom=H):
    """A sun's halo: a dithered radial wash."""
    d = np.sqrt((XX - cx) ** 2 + ((YY - cy) * 1.4) ** 2) / r
    t = np.clip(1 - d, 0, 1) ** 1.6 * strength
    m = (YY >= top) & (YY < bottom)
    cv.tint(m, c, t, levels=5)


def sun(cv, cx, cy, r, core, rim):
    d = np.sqrt((XX - cx) ** 2 + (YY - cy) ** 2)
    cv.fill(d <= r + 1, rim)
    cv.fill(d <= r, core)


# ---------------------------------------------------------------- clouds

def cumulus(cv, rng, cx, base, width, height, pal, haze=0.0, hz=None):
    """A heaped cloud: overlapping puffs, each lit on its upper left and shaded to the lower right,
    painted back to front; the base is cut flat and carries a band of shadow."""
    lit, body, shd, dark = pal
    if hz is not None and haze > 0:
        lit, body, shd, dark = (mix(c, hz, haze) for c in (lit, body, shd, dark))
    puffs = []
    n = max(3, int(width / 7))
    for i in range(n):
        u = (i + 0.5) / n
        x = cx - width / 2 + u * width + rng.uniform(-3, 3)
        hump = math.sin(u * math.pi) ** 0.8
        r = max(3.0, height * (0.35 + 0.65 * hump) * rng.uniform(0.7, 1.0))
        y = base - r * rng.uniform(0.55, 0.95)
        puffs.append((x, y, r))
    # tall ones first so smaller front puffs overlap them
    puffs.sort(key=lambda p: p[1])
    x0 = int(cx - width / 2 - height) - 2
    x1 = int(cx + width / 2 + height) + 2
    y0 = int(base - height * 2) - 2
    region = (slice(max(0, y0), min(H, base + 1)), slice(max(0, x0), min(W, x1)))
    ys, xs = YY[region], XX[region]
    out = cv.a[region]
    whole = np.zeros(ys.shape, bool)
    for (px_, py_, r) in puffs:
        dx, dy = xs - px_, ys - py_
        m = (dx * dx + dy * dy <= r * r) & (ys <= base)
        whole |= m
        # light from above and a little left
        nd = (-dx * 0.3 - dy * 0.95) / r
        tone = np.where(nd > 0.42, 0, np.where(nd > -0.5, 1, 2))
        for k, c in ((0, lit), (1, body), (2, shd)):
            out[m & (tone == k)] = c
    # the flat base in shadow
    band = whole & (ys >= base - max(2, int(height * 0.28)))
    out[band] = shd
    out[whole & (ys >= base - 1)] = dark


def cirrus(cv, rng, cx, y, length, c, c2):
    """A long thin lens of high cloud, two rows at most at its middle."""
    for i in range(length):
        u = i / length
        x = int(cx - length / 2 + i)
        w = math.sin(u * math.pi)
        cv.px(x, y, c if w > 0.25 else c2)
        if w > 0.7:
            cv.px(x + 3, y - 1, c2)


# ---------------------------------------------------------------- terrain lines

def peaks_line(seed, base, height, count, jag=0.18, spread=(0.7, 1.4)):
    """A mountain silhouette: the max of tent-shaped peaks, roughened. Returns (top, which peak,
    peak x) per column so the range can be lit face by face."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    best = np.full(W, float(H))
    who = np.zeros(W, int)
    apex = []
    for i in range(count):
        px_ = (i + rng.uniform(0.1, 0.9)) / count * (W + 120) - 60
        h = height * rng.uniform(0.55, 1.0)
        sl = rng.uniform(*spread) * (0.9 if rng.random() < 0.5 else 1.1)
        sl_l = sl * rng.uniform(0.8, 1.25)
        sl_r = sl * rng.uniform(0.8, 1.25)
        top = base - h
        y = np.where(xs < px_, top + (px_ - xs) * sl_l, top + (xs - px_) * sl_r)
        take = y < best
        best = np.where(take, y, best)
        who = np.where(take, i, who)
        apex.append((px_, top))
    rough = (fbm(seed + 5, W, ((24, 1.0), (60, 0.6))) - 0.5) * height * jag
    return best + rough, who, apex


def hills_line(seed, base, amp, octaves=((3, 1.0), (7, 0.45), (17, 0.15))):
    """A rolling surface whose lowest point sits on `base` and highest `amp` above it."""
    f = fbm(seed, W, octaves)
    f = (f - f.min()) / max(1e-6, f.max() - f.min())
    return base - f * amp


def range_fill(cv, line, who, apex, base, rock, pal_hz, haze, snow=None, snowline=None, seed=0,
               lit_k=0.22, shd_k=-0.25, foot_haze=0.35):
    """Paints a mountain range: each peak's left face lit and its right face in shade, split by a
    wandering ridge; snow above a ragged line; the feet sinking into haze."""
    rng = random.Random(seed)
    top = np.floor(line).astype(int)
    mask = below(top) & (YY <= base)
    rock_h = mix(rock, pal_hz, haze)
    lit = mix(shade(rock, lit_k), pal_hz, haze)
    shd = mix(shade(rock, shd_k), pal_hz, haze)
    # which face: compare x with the dominant peak's apex, the split drifting as it descends
    drift = np.array([rng.uniform(-0.35, 0.35) for _ in apex])
    ax = np.array([a[0] for a in apex])[who]
    ay = np.array([a[1] for a in apex])[who]
    split = ax[None, :] + (YY - ay[None, :]) * drift[who][None, :] \
        + (noise2(seed + 3, W, H, 6) - 0.5) * 7
    left = XX < split
    cv.fill(mask & left, lit)
    cv.fill(mask & ~left, shd)
    # a middle tone gully on the lit faces
    gully = noise2(seed + 9, W, H, 5) > 0.72
    cv.fill(mask & left & gully & (YY > top[None, :] + 4), rock_h)
    if snow is not None:
        sl = snowline + (fbm(seed + 11, W, ((9, 1.0), (31, 0.5))) - 0.5) * 22
        sn = mask & (YY < sl[None, :]) & (YY < split * 0 + ay[None, :] + (base - ay[None, :]) * 0.55)
        s_lit = mix(snow[0], pal_hz, haze * 0.7)
        s_shd = mix(snow[1], pal_hz, haze * 0.7)
        cv.fill(sn & left, s_lit)
        cv.fill(sn & ~left, s_shd)
    # the feet vanish into haze
    t = np.clip((YY - (ay.min() + (base - ay.min()) * 0.45)) / max(1, base - ay.min()) * 1.6, 0,
                1) * foot_haze
    cv.tint(mask, pal_hz, t, levels=3)


def hills_fill(cv, line, bottom, col, rim, hz, haze, dark=None, seed=0, grad=0.0):
    """A rolling layer: flat body, a lit rim along the crest, optionally darkening toward its foot."""
    top = np.floor(line).astype(int)
    mask = below(top) & (YY <= bottom)
    body = mix(col, hz, haze)
    cv.fill(mask, body)
    if dark is not None and grad > 0:
        d = mix(dark, hz, haze)
        t = np.clip((YY - top[None, :]) / 22.0, 0, 1) * grad
        cv.tint(mask, d, t, levels=2)
    r = mix(rim, hz, haze)
    rim_mask = mask & (YY <= top[None, :] + 1)
    # the rim only where the crest faces the light (rising to the left)
    slope = np.gradient(line)
    cv.fill(rim_mask & (slope[None, :] <= 0.25), r)
    return top


def haze_band(cv, y0, y1, c, strength=0.5, top=True):
    """A soft band of mist, thickest at y1 when top is False, at y0 otherwise."""
    for y in range(max(0, y0), min(H, y1)):
        u = (y - y0) / max(1, y1 - y0)
        t = (1 - u if top else u) * strength
        m = np.zeros((H, W), bool)
        m[y] = True
        cv.tint(m, c, t, levels=3)


# ---------------------------------------------------------------- vegetation

def broadleaf(cv, rng, cx, base, r, pal, hz=None, haze=0.0, trunk=None):
    """A round-crowned tree: a cluster of lobes lit top-left, a dark underside, a stub of trunk."""
    lit, mid, shd = pal
    if hz is not None:
        lit, mid, shd = (mix(c, hz, haze) for c in (lit, mid, shd))
    if trunk is not None:
        tc = mix(trunk, hz, haze) if hz is not None else trunk
        th = max(2, int(r * 0.6))
        cv.rect(int(cx), base - th, int(cx) + max(0, int(r / 5)), base, tc)
    cy = base - r * 0.6 - max(2, r * 0.6)
    lobes = [(cx + rng.uniform(-r * 0.55, r * 0.55), cy + rng.uniform(-r * 0.4, r * 0.35),
              r * rng.uniform(0.5, 0.75)) for _ in range(max(3, int(r)))]
    lobes.append((cx, cy, r * 0.8))
    lobes.sort(key=lambda l: -l[1])
    x0, x1 = int(cx - r * 1.6), int(cx + r * 1.6) + 1
    y0, y1 = int(cy - r * 1.6), int(cy + r * 1.3) + 1
    sl = (slice(max(0, y0), min(H, y1)), slice(max(0, x0), min(W, x1)))
    ys, xs = YY[sl], XX[sl]
    out = cv.a[sl]
    whole = np.zeros(ys.shape, bool)
    for (lx, ly, lr) in sorted(lobes, key=lambda l: l[1]):
        dx, dy = xs - lx, ys - ly
        m = dx * dx + dy * dy <= lr * lr
        whole |= m
        nd = (-dx * 0.6 - dy * 0.8) / lr
        out[m] = mid
        out[m & (nd > 0.35)] = lit
        out[m & (nd < -0.45)] = shd
    # underside in shade across the whole crown
    out[whole & (ys > cy + r * 0.45)] = shd


def conifer(cv, cx, base, h, pal, hz=None, haze=0.0, w=None, snow=None):
    """A fir: stacked tiers, the lit half on the left."""
    lit, mid, shd = pal
    if hz is not None:
        lit, mid, shd = (mix(c, hz, haze) for c in (lit, mid, shd))
    w = w or max(2, h * 0.32)
    tiers = max(2, h // 5)
    for y in range(int(base - h), base + 1):
        u = (y - (base - h)) / max(1, h)
        tier_u = (u * tiers) % 1.0
        half = w * (0.25 + 0.75 * u) * (0.65 + 0.35 * tier_u)
        xa, xb = int(round(cx - half)), int(round(cx + half))
        for x in range(xa, xb + 1):
            c = lit if x < cx - 0.5 else shd
            if x == int(cx):
                c = mid
            if snow is not None and tier_u < 0.3 and x < cx + half * 0.3:
                c = snow
            cv.px(x, y, c)
    cv.px(int(cx), int(base - h) - 1, mid)


def treeline(cv, seed, line, height, pal, hz, haze, kind="round", density=1.0, snow=None):
    """A continuous band of crowns along a line -- a wood seen from afar."""
    rng = random.Random(seed)
    x = -8.0
    while x < W + 8:
        base = int(line[int(min(W - 1, max(0, x)))]) + 2
        if kind == "fir":
            h = int(height * rng.uniform(0.6, 1.0))
            conifer(cv, int(x), base, h, pal, hz, haze, snow=snow)
            x += rng.uniform(2.5, 5.0) / density
        else:
            r = height * rng.uniform(0.35, 0.6)
            broadleaf(cv, rng, x, base, max(2.5, r), pal, hz, haze)
            x += rng.uniform(r * 0.8, r * 1.5) / density


def tuft(cv, x, y, h, c, lean=0):
    for i in range(h):
        cv.px(x + (lean if i > h // 2 else 0), y - i, c)


def grass_field(cv, seed, top, bottom, cols, density, rows_dark=None):
    """Near ground: scattered grass tufts in two or three tones, denser and taller toward the
    viewer."""
    rng = random.Random(seed)
    area = W * (bottom - top)
    for _ in range(int(area * density)):
        x = rng.randrange(W)
        y = int(top + (bottom - top) * rng.random() ** 0.7)
        u = (y - top) / max(1, bottom - top)
        h = 1 + int(u * 3 * rng.random())
        c = cols[rng.randrange(len(cols))]
        if h == 1:
            cv.px(x, y, c)
        else:
            tuft(cv, x, y, h, c)
            if rng.random() < 0.6:
                tuft(cv, x - 1, y, max(1, h - 1), c)
            if rng.random() < 0.6:
                tuft(cv, x + 1, y, max(1, h - 1), c)


def blades(cv, seed, y_base, height, cols, density=0.7, x0=0, x1=W):
    """Foreground blades rising from under the frame: long, leaning, dark."""
    rng = random.Random(seed)
    for x in range(x0, x1):
        if rng.random() > density:
            continue
        h = int(height * rng.uniform(0.3, 1.0))
        lean = rng.choice((-1, 0, 0, 1))
        c = cols[rng.randrange(len(cols))]
        for i in range(h):
            xx = x + int(lean * (i / max(1, h)) ** 2 * 3)
            cv.px(xx, y_base - i, c)


def flowers(cv, seed, top, bottom, count, kinds):
    rng = random.Random(seed)
    for _ in range(count):
        x = rng.randrange(W)
        y = rng.randrange(top, bottom)
        petal, centre = kinds[rng.randrange(len(kinds))]
        if (y - top) / max(1, bottom - top) > 0.5 and rng.random() < 0.5:
            for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
                cv.px(x + dx, y + dy, petal)
            cv.px(x, y, centre)
        else:
            cv.px(x, y, petal)


def rock(cv, rng, cx, base, rx, ry, pal):
    lit, mid, shd = pal
    for y in range(int(base - ry * 2), base + 1):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            dx = (x - cx) / rx
            dy = (y - (base - ry)) / ry
            if dx * dx + dy * dy * (1.3 if dy < 0 else 0.6) > 1:
                continue
            c = mid
            if dx + dy < -0.55:
                c = lit
            elif dx + dy > 0.5 or y >= base - 1:
                c = shd
            cv.px(x, y, c)


# ---------------------------------------------------------------- building helpers

def seat(line, x0, x1):
    """The row a footprint from x0 to x1 must reach down to: the lowest ground under it."""
    a, b = max(0, int(x0)), min(W - 1, int(x1))
    if b < a:
        return int(line[max(0, min(W - 1, a))])
    return int(np.max(line[a:b + 1]))


def export(cv, path):
    cv.export(path)


def leaf_clumps(cv, seed, top, bottom, pal, density=1.0, size=(2, 9), alt=None, patch=None,
                dark=None):
    """Ground cover as heaped leafy clumps, small and flat far off, big near the frame: each a
    little mound, its top lit and its foot in shade. Drawn far to near so nearer ones overlap."""
    lit, mid, shd = pal
    rng = random.Random(seed)
    pts = []
    n = int(W * (bottom - top) * 0.02 * density)
    for _ in range(n):
        u = rng.random() ** 0.8
        pts.append((top + u * (bottom - top), rng.uniform(-6, W + 6), u))
    pts.sort()
    pn = noise2(seed + 1, W, H, 34) if alt is not None else None
    for (y, x, u) in pts:
        lit, mid, shd = pal
        xi, yi = int(min(W - 1, max(0, x))), int(min(H - 1, max(0, y)))
        if pn is not None and pn[yi, xi] > (patch or 0.58):
            lit, mid, shd = alt
        if dark is not None and rng.random() < max(0.0, (u - 0.55) / 0.45) * 0.8:
            lit, mid, shd = dark
        w = size[0] + (size[1] - size[0]) * u * rng.uniform(0.6, 1.0)
        h = max(1.0, w * rng.uniform(0.35, 0.55))
        y = int(y)
        for yy in range(int(y - h), y + 1):
            dy = (y - yy) / h
            half = w / 2 * max(0.0, 1 - dy * dy) ** 0.5
            for xx in range(int(x - half), int(x + half) + 1):
                c = mid
                if dy > 0.6 or (dy > 0.3 and xx < x):
                    c = lit
                elif dy < 0.25:
                    c = shd
                cv.px(xx, yy, c)


# ---------------------------------------------------------------- more land shapes

def mesa_line(seed, base, count, top_range, width_range, cliff=(8, 18), talus=0.45):
    """Flat-topped buttes: a table, a sheer cliff, then a talus slope out to the plain. Returns the
    line and, per column, the index of the butte (-1 where there is none) and each butte's span."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    best = np.full(W, float(base))
    who = np.full(W, -1)
    spans = []
    for i in range(count):
        cx = (i + rng.uniform(0.15, 0.85)) / count * (W + 80) - 40
        hw = rng.uniform(*width_range) / 2
        top = rng.uniform(*top_range)
        ch = rng.uniform(*cliff)
        d = np.maximum(0, np.abs(xs - cx) - hw)
        y = np.where(d < ch * 0.25, top + d * 4.0, top + ch + (d - ch * 0.25) * talus)
        y = np.minimum(y, base)
        take = y < best
        best = np.where(take, y, best)
        who = np.where(take, i, who)
        spans.append((cx - hw, cx + hw, top, ch))
    rough = (fbm(seed + 2, W, ((40, 1.0), (90, 0.5))) - 0.5) * 2.0
    return best + rough, who, spans


def mesa_fill(cv, line, who, spans, base, col, lit, shd, strata, hz, haze, seed=0):
    top = np.floor(line).astype(int)
    mask = below(top) & (YY <= base)
    c_mid, c_lit, c_shd, c_str = (mix(c, hz, haze) for c in (col, lit, shd, strata))
    cv.fill(mask, c_mid)
    n = noise2(seed + 4, W, H, 4)
    for i, (x0, x1, t, ch) in enumerate(spans):
        mine = mask & (who[None, :] == i)
        w = x1 - x0
        cv.fill(mine & (XX < x0 + w * 0.22 + (n - 0.5) * 6), c_lit)
        cv.fill(mine & (XX > x1 - w * 0.3 + (n - 0.5) * 6), c_shd)
        # strata: thin dark courses across the cliff
        rows = ((YY - int(t)) % 6 == 4) & (YY < t + ch + 2) & (n > 0.35)
        cv.fill(mine & rows, c_str)
        # talus in shade toward the right, lit on the left
        tal = mine & (YY > t + ch + 2)
        cv.fill(tal & (XX > (x0 + x1) / 2), c_shd)
    # top rim
    cv.fill(mask & (YY == top[None, :]), mix(shade(lit, 0.25), hz, haze))
    cv.tint(mask, hz, np.clip((YY - (base - 14)) / 14.0, 0, 1) * 0.5, levels=2)


def dune_line(seed, base, count, height, wl=(60, 140)):
    """Dunes: a long gentle windward slope up to a crest and a short steep slip face beyond it.
    Returns line, owner and each crest."""
    rng = random.Random(seed)
    xs = np.arange(W, dtype=float)
    best = np.full(W, float(base))
    who = np.full(W, -1)
    crests = []
    for i in range(count):
        cx = (i + rng.uniform(0.1, 0.9)) / count * (W + 160) - 80
        h = height * rng.uniform(0.5, 1.0)
        wl_ = rng.uniform(*wl)
        wr = wl_ * rng.uniform(0.28, 0.4)
        top = base - h
        d = np.where(xs < cx, (cx - xs) / wl_, (xs - cx) / wr)
        y = np.where(d < 1, top + h * np.where(xs < cx, d ** 1.35, d ** 0.8), base)
        take = y < best
        best = np.where(take, y, best)
        who = np.where(take, i, who)
        crests.append((cx, top))
    return best, who, crests


def dune_fill(cv, line, who, crests, bottom, lit, shd, rim, hz, haze):
    top = np.floor(line).astype(int)
    mask = below(top) & (YY <= bottom)
    l, s, r = (mix(c, hz, haze) for c in (lit, shd, rim))
    cv.fill(mask, l)
    cx = np.array([c[0] for c in crests] + [1e9])[who]
    ty = np.array([c[1] for c in crests] + [0])[who]
    # the slip face: a crescent of shade from the crest, its edge curving back under the dune
    lean = cx[None, :] - (YY - ty[None, :]) * 0.9 - ((YY - ty[None, :]) ** 2) * 0.02
    cv.fill(mask & (XX > lean) & (who[None, :] >= 0), s)
    edge = mask & (YY <= top[None, :] + 0) & (XX <= cx[None, :])
    cv.fill(edge, r)


def stars(cv, seed, y1, count, cols):
    rng = random.Random(seed)
    for _ in range(count):
        x, y = rng.randrange(W), int(rng.random() ** 1.5 * y1)
        c = cols[rng.randrange(len(cols))]
        cv.px(x, y, c)
        if rng.random() < 0.08:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv.px(x + dx, y + dy, mix(c, cv.a[max(0, y - 3), x], 0.5))


def aurora(cv, seed, y0, height, cols, strength=0.55):
    """Curtains of light: each hangs from a wavy lower edge, brightest there, its rays rising to
    uneven lengths and fading as they go."""
    rng = random.Random(seed)
    for k, c in enumerate(cols):
        edge = y0 + height + k * 10 + (fbm(seed + k * 7, W, ((2, 1.0), (5, 0.6), (13, 0.2)))
                                        - 0.5) * 70
        ray = height * (0.35 + 0.65 * fbm(seed + k * 13, W, ((40, 1.0), (97, 0.7))))
        u = (edge[None, :] - YY) / ray[None, :]
        t = np.where((u >= 0) & (u <= 1), (1 - u) ** 1.5, 0.0)
        t = np.where((u < 0) & (u > -0.12), 0.6, t)
        cv.tint(np.ones((H, W), bool), c, t * strength * (1 - 0.3 * k), levels=4, seam=0.3)


def shafts(cv, seed, c, count=5, strength=0.22, top=0, bottom=H, slant=0.55):
    """Sun shafts falling from the upper left through a canopy."""
    rng = random.Random(seed)
    t = np.zeros((H, W))
    for _ in range(count):
        x0 = rng.uniform(-80, W * 0.8)
        w = rng.uniform(8, 26)
        u = XX - (x0 + (YY - top) * slant)
        band = (u >= 0) & (u <= w)
        fade = np.clip(1 - (YY - top) / max(1, bottom - top), 0, 1) ** 0.5
        t = np.maximum(t, band * fade * rng.uniform(0.6, 1.0))
    cv.tint((YY >= top) & (YY < bottom), c, t * strength, levels=3, seam=0.4)


def trunk(cv, cx, w, top, base, pal, seed=0, flare=6):
    """A near tree's trunk, the frame of a wood: lit edge on the left, bark furrows, roots
    spreading at its foot."""
    lit, mid, shd, dark = pal
    rng = random.Random(seed)
    fur = [rng.uniform(0.3, 0.85) for _ in range(3)]
    for y in range(max(0, top), min(H, base + 1)):
        u = max(0.0, (y - (base - flare * 2)) / (flare * 2))
        half = w / 2 + u * u * flare
        xa, xb = int(cx - half), int(cx + half)
        for x in range(xa, xb + 1):
            f = (x - xa) / max(1, xb - xa)
            c = mid
            if f < 0.18:
                c = lit
            elif f > 0.62:
                c = shd
            if f > 0.88:
                c = dark
            for k in fur:
                if abs(f - k) < 0.04 and (y * 7 + int(k * 50)) % 11 > 2:
                    c = dark if f > 0.5 else shd
            cv.px(x, y, c)


def canopy(cv, seed, depth, pal, x0=0, x1=W):
    """The underside of a wood's roof along the top edge: heaped lobes hanging to a ragged line."""
    rng = random.Random(seed)
    lit, mid, shd = pal
    edge = depth * (0.5 + 0.5 * fbm(seed, W, ((4, 1.0), (11, 0.6), (29, 0.3))))
    cv.fill((YY <= edge[None, :]) & (XX >= x0) & (XX < x1), shd)
    x = x0 - 6.0
    while x < x1 + 6:
        r = rng.uniform(5, 11)
        cy = edge[int(min(W - 1, max(0, x)))] - r * 0.35
        m = (XX - x) ** 2 + (YY - cy) ** 2 <= r * r
        nd = (-(XX - x) * 0.3 - (YY - cy) * 0.95) / r
        cv.fill(m, mid)
        cv.fill(m & (nd < -0.45), shd)
        cv.fill(m & (nd > 0.55), lit)
        x += rng.uniform(r * 0.8, r * 1.4)


def firs(cv, seed, line, height, pal, hz, haze, density=0.5):
    """A stand of tall narrow firs, spaced so each spire reads, heights varying."""
    rng = random.Random(seed)
    x = rng.uniform(-10, 4)
    while x < W + 10:
        base = int(line[int(min(W - 1, max(0, x)))]) + 3
        h = int(height * rng.uniform(0.55, 1.0))
        conifer(cv, int(x), base, h, pal, hz, haze, w=h * rng.uniform(0.16, 0.22))
        x += rng.uniform(5, 13) / density * 0.5


def drifts(cv, seed, top, bottom, pal, count=6, amp=(4, 10), rim=-0.08):
    """Smooth ground built of overlapping swells, each nearer one covering the last: a lit crest,
    a body, and shade gathering in the hollow under its crest where it dips to the right."""
    lit, body, shd = pal
    rng = random.Random(seed)
    for k in range(count):
        u = k / max(1, count - 1)
        y = top + (bottom - top) * (u ** 1.3)
        line = hills_line(seed * 3 + k, y, rng.uniform(*amp) * (0.6 + 0.8 * u),
                          ((2, 1.0), (5, 0.5), (11, 0.15)))
        t = np.floor(line).astype(int)
        m = below(t)
        cv.fill(m, body)
        slope = np.gradient(line)
        cv.fill(m & (YY <= t[None, :] + 1) & (slope[None, :] < rim), lit)
        depth = (YY - t[None, :])
        reach = np.clip(slope, 0, None) * 40 * (0.5 + u)
        cv.fill(m & (depth >= 1) & (depth <= reach[None, :]), shd)


def ripples(cv, seed, top, bottom, cols, count=140, length=(4, 14)):
    """Wind ripples in sand: short shallow arcs, longer toward the viewer."""
    rng = random.Random(seed)
    for _ in range(count):
        y = int(top + (bottom - top) * rng.random() ** 0.8)
        u = (y - top) / max(1, bottom - top)
        n = int(rng.uniform(*length) * (0.5 + u))
        x0 = rng.uniform(-10, W)
        c = cols[rng.randrange(len(cols))]
        for i in range(n):
            f = i / max(1, n)
            cv.px(int(x0 + i), y - int(round(math.sin(f * math.pi) * (1 + u))), c)


def sparkle(cv, seed, top, bottom, count, c):
    rng = random.Random(seed)
    for _ in range(count):
        x, y = rng.randrange(W), rng.randrange(top, bottom)
        cv.px(x, y, c)
        if rng.random() < 0.15:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                cv.px(x + dx, y + dy, mix(c, tuple(int(q) for q in cv.a[y, x]), 0.4))


def fern(cv, rng, cx, base, size, pal, side=1):
    """A fern's fronds arching out of the ground, each a curved rib with leaflets along it,
    leaning toward `side` (1 = right)."""
    import math as _m
    lit, mid, shd = pal
    for i in range(7):
        ang = _m.radians(100 - i * 22) if side > 0 else _m.radians(80 + i * 22)
        ln = size * rng.uniform(0.6, 1.0)
        x, y = float(cx), float(base)
        for k in range(int(ln)):
            t = k / ln
            x += _m.cos(ang)
            y -= _m.sin(ang)
            ang -= side * 0.035 * (1 + t)
            c = mid if t < 0.7 else lit
            cv.px(int(round(x)), int(round(y)), shd)
            leaf = int((1 - t) * 4) + 1
            if k % 2 == 0:
                nx, ny = -_m.sin(ang), -_m.cos(ang)
                for d in range(1, leaf + 1):
                    cv.px(int(round(x + nx * d)), int(round(y + ny * d)), c)
                    cv.px(int(round(x - nx * d)), int(round(y - ny * d)), mid)
