"""Reusable placement and drawing stamps shared by every phase."""
import math
import random

from hexlib import BORDER, C, HEX_PIXELS, LATTICE_SHIFTS, bayer, in_hex


def lattice_dist(p, q):
    """Distance between two local points, counting neighbouring same-type tiles."""
    return min(math.hypot(p[0] - q[0] - sx, p[1] - q[1] - sy) for sx, sy in LATTICE_SHIFTS)


def scatter(seed, count, spacing, min_border=0.0, max_border=99.0, avoid=(), tries=6000):
    """Poisson-ish points inside a border-distance band, spaced across tile seams too."""
    rng = random.Random(seed)
    candidates = [p for p in HEX_PIXELS if min_border <= BORDER[p[1]][p[0]] < max_border]
    pts = []
    for _ in range(tries):
        if len(pts) >= count or not candidates:
            break
        p = rng.choice(candidates)
        if all(lattice_dist(p, q) >= spacing for q in list(pts) + list(avoid)):
            pts.append(p)
    return pts


def shadow_set(cells, dx, dy):
    """Ground pixels covered by sweeping a shape toward the bottom-right, excluding the shape."""
    cells = set(cells)
    out = set()
    for x, y in cells:
        for k in range(1, max(dx, dy) + 1):
            q = (x + min(k, dx), y + min(k, dy))
            if q not in cells:
                out.add(q)
    return out


def edge_ring(shape):
    """Pixels of a set that touch a pixel outside the set (4-neighbourhood)."""
    return {(x, y) for x, y in shape
            if any((x + dx, y + dy) not in shape for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


def dome(cx, cy, rx, ry, seed=0, lump=0.0, lobes=3):
    """Elliptical blob with height + normalized offset per pixel: {(x,y): (h, nx, ny)}."""
    rng = random.Random(seed)
    phases = [rng.random() * math.tau for _ in range(3)]
    out = {}
    for y in range(int(cy - ry - 3), int(cy + ry + 4)):
        for x in range(int(cx - rx - 3), int(cx + rx + 4)):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            ang = math.atan2(dy, dx)
            wobble = 1.0 + lump * sum(math.sin(ang * (k + lobes) + ph) for k, ph in enumerate(phases)) / 3
            d = math.hypot(dx, dy) / wobble
            if d <= 1.0:
                out[(x, y)] = (math.sqrt(max(0.0, 1 - d * d)), dx, dy)
    return out


def shade_dome(tile, blob, ramp, wrapped=True, outline=None, shadow_offset=(1, 1),
               shadow_steps=1, highlight=None):
    """Shaded blob lit from the top-left, with a cast shadow and optional selective outline."""
    shape = set(blob)
    if shadow_offset:
        for q in shadow_set(shape, *shadow_offset):   # each ground pixel darkened once
            tile.darken(q[0], q[1], wrapped=wrapped, steps=shadow_steps)
    ring = edge_ring(shape)
    for (x, y), (h, nx, ny) in blob.items():
        lit = 0.55 * h + 0.45 * (0.5 - 0.5 * (nx + ny) / 1.4142)
        k = lit * len(ramp)
        idx = int(k)
        if k - idx > 0.6 and idx + 1 < len(ramp) and bayer(x, y) < (k - idx - 0.6) * 2.5:
            idx += 1
        c = ramp[min(idx, len(ramp) - 1)]
        if outline is not None and (x, y) in ring and (nx + ny) > -0.3:
            c = outline
        tile.put(x, y, c, wrapped=wrapped)
    if highlight is not None:
        best = min(blob.items(), key=lambda kv: kv[1][1] + kv[1][2] - 0.6 * kv[1][0])
        hx, hy = best[0]
        tile.put(hx + 1, hy + 1, highlight, wrapped=wrapped)
        tile.put(hx + 2, hy + 1, highlight, wrapped=wrapped)


def boulder(tile, cx, cy, rx, ry, seed, wrapped=True, ramp=None, outline=None, moss=None):
    """A shaded rock. `ramp`/`outline` recolour it (stone by default); `moss` is a list of colours
    sprinkled over its lit top-left half."""
    ramp = ramp or [C["slate"], C["stone"], C["stone_lt"], C["mist"]]
    blob = dome(cx, cy, rx, ry, seed=seed, lump=0.18)
    shade_dome(tile, blob, ramp, wrapped=wrapped, outline=C["slate_dk"] if outline is None else outline,
               shadow_offset=(2, 2), shadow_steps=1)
    # a crack line across bigger rocks
    if rx >= 3.5:
        rng = random.Random(seed + 99)
        x = int(cx - rx * 0.3)
        y = int(cy - ry * 0.2)
        for _ in range(int(rx)):
            if (x, y) in blob:
                tile.put(x, y, ramp[0], wrapped=wrapped)
            x += 1
            y += rng.choice((0, 0, 1))
    if moss:
        rng = random.Random(seed + 7)
        for (x, y), (h, nx, ny) in sorted(blob.items()):
            if nx + ny < -0.2 and h > 0.25 and rng.random() < 0.55:
                tile.put(x, y, moss[(x + y) % len(moss)], wrapped=wrapped)


def tuft(tile, x, y, hi, mid, lo, big=False):
    """Top-down grass/scrub tuft: lit tips top-left, shadow bottom-right."""
    pts = [(0, 0, hi), (1, 0, mid), (-1, 1, mid), (1, 1, lo)]
    if big:
        pts += [(-2, 0, mid), (-1, -1, hi), (2, 1, mid), (0, 2, lo), (2, 2, lo)]
    for dx, dy, c in pts:
        tile.put(x + dx, y + dy, c)


def pebble(tile, x, y, hi, mid, lo, big=False):
    tile.put(x, y, hi)
    if big:
        tile.put(x + 1, y, mid)
        tile.put(x, y + 1, mid)
        tile.put(x + 1, y + 1, mid)
        tile.put(x + 2, y + 1, lo)
        tile.put(x + 1, y + 2, lo)
    else:
        tile.put(x + 1, y + 1, lo)


def line_pixels(x0, y0, x1, y1):
    """Integer Bresenham line."""
    pts = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        pts.append((x0, y0))
        if x0 == x1 and y0 == y1:
            return pts
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def seg_dist(p, a, b):
    """Distance from p to segment ab, and the clamped position t along it."""
    vx, vy = b[0] - a[0], b[1] - a[1]
    L2 = vx * vx + vy * vy
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / L2))
    return math.hypot(p[0] - a[0] - t * vx, p[1] - a[1] - t * vy), t
