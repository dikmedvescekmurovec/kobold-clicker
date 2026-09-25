"""The ice wall ring and the frozen wasteland past it, 56x64 like every hex.

The wall is a band a little wider than a road, laid through wasteland snow along the ring the way a
road runs through its tile: a range of faceted ice peaks (a pyramid a peak, so every facet is one
flat shade) rising from both edges of the band to its crest, lit from the top-left like the
mountains. The wasteland is wind-blown snow with drift bumps, lighter and plainer than the ice
environment so the wall stays the edge, and a few rare accents (tracks, a rock, a dead shrub).
"""
import math
import random

from hexlib import BORDER, C, ROW_OFFSET, STEP_X, STEP_Y, CENTER, EDGE_MID, EDGE_NAMES, HEX_PIXELS, in_hex, LATTICE_SHIFTS, Tile, bayer, fbm, light, periodic_noise, ramp_pick, wrap
from stamps import dome, edge_ring, line_pixels, scatter, shadow_set, tuft
from terrain import hashf

VARIANTS = ["v1", "v2", "v3"]
WALL_SEED, WASTE_SEED = 700, 800


def _vseed(base, variant):
    return base * 10 + VARIANTS.index(variant) + 1


def _shard(px, py, radius, amp, seed, wrapped):
    rng = random.Random(seed)
    sides = rng.randint(4, 6)
    turn = rng.random() * math.tau
    # a facet's normal a side, jittered so no two shards are the same polygon
    normals = [(math.cos(a), math.sin(a)) for a in
               (turn + (i + rng.uniform(-0.25, 0.25)) * math.tau / sides for i in range(sides))]
    return px, py, radius, amp, normals, wrapped


def _shard_height(shard, x, y):
    px, py, radius, amp, normals, wrapped = shard
    best = 0.0
    for sx, sy in (LATTICE_SHIFTS if wrapped else [(0, 0)]):
        vx, vy = x + 0.5 - px - sx, y + 0.5 - py - sy
        d = max(vx * nx + vy * ny for nx, ny in normals)
        if d < radius:
            best = max(best, amp * (1 - d / radius))
    return best


# The wasteland is one field over the whole map, repeating only every WASTE_COLS x WASTE_ROWS cells
# (WASTE_ROWS even, so the odd rows' half-step shift comes round too), cut into that many tiles:
# cell (col, row) takes tile (col % WASTE_COLS, row % WASTE_ROWS). A tile of its own shared edge
# repeated every cell, and its drifts made a grid you could see across the whole wasteland.
WASTE_COLS, WASTE_ROWS = 6, 4
PERIOD_X, PERIOD_Y = STEP_X * WASTE_COLS, STEP_Y * WASTE_ROWS
DRIFT_GAIN = 0.75   # how steep a slope has to be before it goes into shade
ACCENT_KINDS = ["tracks", "paws", "rock", "shrub", "ice", "pebbles", "grass"]
ACCENTS = [f"{kind}_{i}" for kind in ACCENT_KINDS for i in (1, 2, 3)]   # overlays on a wasteland tile
ACCENT_CHANCE = 0.25   # of wasteland cells carrying one


def _waves(seed, shortest, longest, count):
    """Cosines whose wavelengths fit the period a whole number of times: a smooth random field
    that repeats exactly on it. Longer waves are stronger, as in any drift."""
    rng = random.Random(seed)
    fits = [(i / PERIOD_X, j / PERIOD_Y) for i in range(-40, 41) for j in range(0, 41)
            if (j > 0 or i > 0) and 1 / longest < math.hypot(i / PERIOD_X, j / PERIOD_Y) < 1 / shortest]
    picked = rng.sample(fits, count)
    return [(kx, ky, rng.random() * math.tau, 1 / math.hypot(kx, ky)) for kx, ky in picked]


_DRIFTS = _waves(WASTE_SEED, 30.0, 160.0, 40)


def _drift_slope(X, Y):
    """The field's slope toward the light at a world pixel (positive: facing away from it)."""
    dx = dy = 0.0
    for kx, ky, ph, amp in _DRIFTS:
        g = -amp * math.tau * math.sin(math.tau * (kx * X + ky * Y) + ph)
        dx += g * kx
        dy += g * ky
    return -light(dx, dy) / len(_DRIFTS)


def waste(col, row):
    """Wasteland tile (col, row) of the WASTE_COLS x WASTE_ROWS block."""
    t = Tile(f"ice_waste_{col}_{row}", "ice")
    ox, oy = STEP_X * col + ROW_OFFSET * (row % 2), STEP_Y * row
    for x, y in HEX_PIXELS:
        shade = _drift_slope(ox + x + 0.5, oy + y + 0.5) * DRIFT_GAIN
        t.px[y][x] = C["ice_lt"] if shade > 1.0 or (shade > 0.55 and bayer(x, y) < 0.5) else C["snow"]
    return t


def accent(name):
    """A thing lying on the wasteland, as an overlay for any wasteland tile."""
    t = Tile(f"ice_waste_{name}", "ice")
    kind = name.rsplit("_", 1)[0]
    rng = random.Random(WASTE_SEED * 13 + ACCENTS.index(name))
    cx, cy = 28 + rng.randint(-6, 6), 32 + rng.randint(-6, 6)
    if kind in ("tracks", "paws"):
        _footprints(t, rng, paws=kind == "paws")
    elif kind == "rock":
        _rock(t, cx, cy, rng.randrange(1 << 30))
    elif kind == "shrub":
        _shrub(t, cx, cy + 2, rng)
    elif kind == "ice":
        _ice_lump(t, cx, cy, rng.randrange(1 << 30))
    elif kind == "pebbles":
        spots = sorted((cx + rng.randint(-8, 8), cy + rng.randint(-6, 6)) for _ in range(rng.randint(3, 4)))
        for px, py in sorted(spots, key=lambda p: p[1]):
            r = rng.uniform(2.2, 3.2)
            _rock(t, px, py, rng.randrange(1 << 30), r, r * 0.75)
    else:
        for _ in range(rng.randint(4, 7)):             # dry grass poking through the snow
            px, py = cx + rng.randint(-7, 7), cy + rng.randint(-5, 5)
            tuft(t, px, py, C["olive"], C["olive"], C["earth"], big=rng.random() < 0.4)
    return t


def _ice_lump(t, cx, cy, seed):
    """A block of clear ice left lying on the snow: two or three faceted shards."""
    rng = random.Random(seed)
    shards = [_shard(cx + rng.uniform(-3, 3) + 0.5, cy + rng.uniform(-2, 2) + 0.5, rng.uniform(3.5, 5.5),
                     rng.uniform(0.8, 1.2), seed + i, False) for i in range(rng.randint(2, 3))]
    h = {(x, y): max(_shard_height(sh, x, y) for sh in shards)
         for x in range(cx - 10, cx + 11) for y in range(cy - 10, cy + 11)}
    ramp = [C["ice_dk"], C["ice"], C["ice"], C["ice_lt"], C["snow"]]
    for (x, y), here in h.items():
        if here > 0.05:
            dx = h.get((x + 1, y), 0) - h.get((x - 1, y), 0)
            dy = h.get((x, y + 1), 0) - h.get((x, y - 1), 0)
            t.put(x, y, ramp_pick(0.55 + 1.2 * light(dx, dy), ramp, x, y, band=0.0), wrapped=False)
        elif any(h.get((x - k, y - k), 0) > 0.1 * k for k in (1, 2)):
            t.put(x, y, C["ice_lt"], wrapped=False)


def _footprints(t, rng, paws=False):
    """A trail across the middle of the tile that fades out where the snow has drifted over it."""
    x, y = 28.0 + rng.uniform(-8, 8), 32.0 + rng.uniform(-8, 8)
    ang = rng.uniform(0, math.tau)
    x -= math.cos(ang) * 18
    y -= math.sin(ang) * 18
    step = 3.0 if paws else 5.0
    for i in range(12 if paws else 9):
        ang += rng.uniform(-0.25, 0.25)
        x, y = x + math.cos(ang) * step, y + math.sin(ang) * step
        side = 1.5 if i % 2 else -1.5
        px, py = int(x - math.sin(ang) * side), int(y + math.cos(ang) * side)
        if not in_hex(px, py) or BORDER[py][px] < 6 or rng.random() < 0.12:
            continue
        if paws:
            t.put(px, py, C["ice"], wrapped=False)
        else:                                     # a boot print: a dent, its wall on the light's side in shade
            for ox, oy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                t.put(px + ox, py + oy, C["ice"] if oy == 0 else C["ice_lt"], wrapped=False)


def _rock(t, cx, cy, seed, rx=6.0, ry=4.4):
    """A rock poking through the snow, a cap of snow on its top."""
    blob = dome(cx + 0.5, cy + 0.5, rx, ry, seed=seed, lump=0.25)
    ring = edge_ring(set(blob))
    for x, y in shadow_set(blob, 2, 2):
        t.put(x, y, C["ice_lt"], wrapped=False)
    for (x, y), (h, nx, ny) in blob.items():
        lit = 0.55 * h + 0.45 * (0.5 - 0.5 * (nx + ny) / 1.4142)
        if ny < -0.25:                                # the cap: snow, edged pale blue so it reads on snow
            c = C["ice_lt"] if (x, y) in ring else C["snow"]
        elif (x, y) in ring:
            c = C["slate_dk"]
        else:
            c = C["stone_lt"] if lit > 0.62 else C["stone"] if lit > 0.4 else C["slate"]
        t.put(x, y, c, wrapped=False)


def _shrub(t, cx, cy, rng):
    """A dead bush: bare twigs fanning up from one root, snow caught on a few of them."""
    for k in range(5):
        ang = -math.pi / 2 + (k - 2) * 0.45 + rng.uniform(-0.15, 0.15)
        length = rng.uniform(6, 11)
        x0, y0 = cx, cy
        x1, y1 = round(cx + math.cos(ang) * length), round(cy + math.sin(ang) * length)
        for i, (x, y) in enumerate(line_pixels(x0, y0, x1, y1)):
            t.put(x, y, C["earth"] if i else C["earth_dk"], wrapped=False)
        t.put(x1, y1 - 1, C["snow"], wrapped=False) if rng.random() < 0.5 else None
    for x in range(cx - 3, cx + 4):
        t.put(x, cy + 1, C["ice_lt"], wrapped=False)


# --------------------------------------------------------------------------- the snow onto the land
SPILL_REACH = 0.6   # of the land blends' depth: the snow reaches about 15 px onto a land tile
_SPILL_CLUMP = None


def snow_spill(mask):
    """An overlay for a land tile whose edges in `mask` touch the ice (the wall's snow or the
    wasteland): snow drifting onto it, full along the seam and breaking into patches and loose
    specks inward, the way one environment's blend runs onto the next. The snow is the wasteland's
    plain white; its drifts are world-placed, so the seam can cut one where it meets the land."""
    from blends import coverage, detail_chance, front
    global _SPILL_CLUMP
    if _SPILL_CLUMP is None:
        big, fine, grain = (periodic_noise(WASTE_SEED + 7002, 10), periodic_noise(WASTE_SEED + 7000, 4),
                            periodic_noise(WASTE_SEED + 7001, 1))
        _SPILL_CLUMP = {p: 0.55 * big[p] + 0.25 * (0.65 * fine[p] + 0.35 * grain[p]) for p in HEX_PIXELS}
    mask = tuple(sorted(mask))
    t = Tile(f"ice_spill_{'_'.join(map(str, mask))}", "ice")
    d = {p: v / SPILL_REACH for p, v in front(mask).items()}
    for x, y in HEX_PIXELS:
        cover = coverage(d[(x, y)])
        if cover > _SPILL_CLUMP[(x, y)] + 0.2 * bayer(x, y):
            t.px[y][x] = C["snow"]
        elif cover > _SPILL_CLUMP[(x, y)] - 0.06:     # the ragged front's shaded lip
            t.px[y][x] = C["ice_lt"]
    for x, y in scatter(WASTE_SEED * 11, 110, 3, min_border=2.0):
        v = detail_chance(d[(x, y)])
        if 0.04 < v < 0.9 and hashf(x, y, 5) < v and not t.px[y][x]:
            t.put(x, y, C["snow"], wrapped=False)
            t.put(x + 1, y + 1, C["ice_lt"], wrapped=False)
    return t


# --------------------------------------------------------------------------- the wall as a band
BAND_HALF = 10.0    # a road is about 4 across the middle
PEAK_STEP = 9.0     # peaks along the crest, this far apart


def _centreline(edges):
    """The road's centreline from edge a's midpoint to edge b's, as a polyline."""
    from roads import _stem
    a, b = edges
    ma, mb = EDGE_MID[EDGE_NAMES[a]], EDGE_MID[EDGE_NAMES[b]]
    if (b - a) % 6 == 3:
        return [ma, CENTER, mb]
    _, sa = _stem(a)
    _, sb = _stem(b)
    curve = [(sa[0] * (1 - t) ** 2 + 2 * CENTER[0] * t * (1 - t) + sb[0] * t * t,
              sa[1] * (1 - t) ** 2 + 2 * CENTER[1] * t * (1 - t) + sb[1] * t * t)
             for t in (i / 60 for i in range(61))]
    return [ma] + curve + [mb]


def _along(line, dist):
    for p, q in zip(line, line[1:]):
        seg = math.hypot(q[0] - p[0], q[1] - p[1])
        if dist <= seg:
            k = dist / seg
            return p[0] + (q[0] - p[0]) * k, p[1] + (q[1] - p[1]) * k
        dist -= seg
    return line[-1]


def _seam_seed(edge, inside):
    """A peak half a step from a seam belongs to both tiles: this tile's edge e is the
    neighbour's edge e + 3, and its inside is the neighbour's outside."""
    if edge >= 3:
        edge, inside = edge - 3, not inside
    return WALL_SEED * 100 + edge * 2 + inside


def _peaks(edges, variant):
    line = _centreline(edges)
    length = sum(math.hypot(q[0] - p[0], q[1] - p[1]) for p, q in zip(line, line[1:]))
    half = PEAK_STEP / 2
    n = max(1, round((length - PEAK_STEP) / PEAK_STEP))
    spots = [(_along(line, half + i * (length - PEAK_STEP) / n), None) for i in range(n + 1)]
    spots[0] = (spots[0][0], _seam_seed(edges[0], True))
    spots[-1] = (spots[-1][0], _seam_seed(edges[1], True))
    for e in edges:                                   # the neighbours' first peaks, past each seam
        m = EDGE_MID[EDGE_NAMES[e]]
        ux, uy = m[0] - CENTER[0], m[1] - CENTER[1]
        k = half / math.hypot(ux, uy)
        spots.append(((m[0] + ux * k, m[1] + uy * k), _seam_seed(e, False)))
    out = []
    for i, ((px, py), seed) in enumerate(spots):
        seed = seed if seed is not None else _vseed(WALL_SEED, variant) * 70 + i
        rng = random.Random(seed)
        out.append(_shard(px, py, BAND_HALF + rng.uniform(0.0, 3.0), 1.0 + 0.5 * rng.random(), seed, False))
    return out


def wall_band(edges, variant):
    """An overlay for a wasteland tile: a range of ice peaks along the ring, centred like a road
    between `edges` (the ring's two neighbours), rising from both edges of the band to its crest."""
    from roads import road_shape
    edges = tuple(sorted(edges))
    t = Tile(f"ice_band_{'_'.join(map(str, edges))}_{variant}", "ice")
    shape = road_shape(edges)
    jitter = periodic_noise(WALL_SEED + 5, 8)
    peaks = _peaks(edges, variant)

    def height(x, y):
        # worked out past the hex too, so the shading at a seam sees the neighbour's band
        d, presence = shape(x + 0.5, y + 0.5)
        edge = max(0.0, 1.0 - d / (BAND_HALF + 3.0 * (jitter[wrap(x, y)] - 0.5))) * presence
        return min(max(_shard_height(pk, x, y) for pk in peaks), 3.0 * edge)

    cache = {}

    def at(x, y):
        if (x, y) not in cache:
            cache[(x, y)] = height(x, y)
        return cache[(x, y)]
    h = {p: at(*p) for p in HEX_PIXELS}

    ramp = [C["abyss"], C["ice_dk"], C["ice"], C["ice"], C["ice_lt"], C["snow"]]
    for x, y in HEX_PIXELS:
        here = h[(x, y)]
        if here > 0.04:
            dx, dy = at(x + 1, y) - at(x - 1, y), at(x, y + 1) - at(x, y - 1)
            t.px[y][x] = ramp_pick(0.58 + 1.6 * light(dx, dy), ramp, x, y, band=0.0)
        elif any(at(x - k, y - k) > 0.06 * k + 0.1 for k in range(1, 5)):
            t.px[y][x] = C["ice_lt"]                      # the range's shadow on the snow
    return t
