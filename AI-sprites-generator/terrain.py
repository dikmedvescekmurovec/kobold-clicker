"""Phase 1: environments, 56x64.

Seamless rule: everything within the shared band (details anchored at BORDER < BAND, and the
noise edge band from blend_fields) comes from env-seeded, lattice-periodic data identical for
every variant. Per-variant noise and details only appear deeper inside the tile.
`objects=False` renders ground only (no trees/peaks/accent), used under towns.

Every ground is a height field lit from the top-left (`relief`), not flat noise: the light is what
makes grass read as a meadow and sand as dunes. Tall things -- peaks, mesas -- are height fields too,
drawn raised in 3/4 view by `raised`, so they stand up off the ground with a lit and a shaded face.
"""
import math
import random

from hexlib import BORDER, C, DARKER, H as TILE_H, HEX_PIXELS, W as TILE_W, Tile, bayer, blend_fields, fbm, \
    in_hex, interior_weight, periodic_noise, ramp_pick, wrap
from stamps import dome, line_pixels, scatter, seg_dist, shadow_set

VARIANTS = ["v1", "v2", "v3", "accent", "accent2", "accent3"]
ACCENTS = [v for v in VARIANTS if v.startswith("accent")]
ENV_ORDER = ["grass", "dirt", "desert", "ice", "forest", "mountains"]
ENV_SEED = {"grass": 100, "dirt": 200, "desert": 300, "ice": 400, "forest": 500, "mountains": 600}

# Which environments may border each other (symmetric; the same environment is always allowed).
_BORDERS = {
    "grass": ("dirt", "ice", "forest", "mountains"),
    "dirt": ("grass", "desert", "forest", "mountains"),
    "desert": ("dirt", "mountains"),
    "ice": ("grass", "mountains"),
    "forest": ("grass", "dirt", "mountains"),
    "mountains": ("grass", "dirt", "desert", "ice", "forest"),
}
ADJACENT = {env: {env} for env in ENV_ORDER}
for _env, _others in _BORDERS.items():
    for _other in _others:
        ADJACENT[_env].add(_other)
        ADJACENT[_other].add(_env)
ENV_CHAIN = ["desert", "dirt", "forest", "grass", "ice", "mountains"]   # a legal order for side-by-side bands


def can_border(a, b):
    return b in ADJACENT[a]


BAND = 6.0     # shared detail anchors
INNER = 9.0    # per-variant detail anchors
CALM = ((24, 0.7), (7, 0.3))
LIGHT = (-0.62, -0.5, 0.6)     # towards the light: left, up, and above
# A raised shape shows its south faces most, so it is lit from the front-left instead: the same sun
# on the screen, but a top-left light would leave every face the viewer sees in shade.
RAISED_LIGHT = (-0.72, 0.18, 0.67)


def R(*names):
    return [C[n] for n in names]


GRASS = R("gr0", "gr1", "gr2", "gr3", "gr4", "gr5")
CONIFER = R("fo1", "co1", "co2", "co3", "co4")
EARTH = R("di0", "di1", "di2", "di3", "di4", "di5")
SAND = R("de0", "de1", "de2", "de3", "de4", "de5")
SNOW = R("sn0", "sn1", "sn2", "sn3", "sn4", "sn5")
ROCK = R("ro0", "ro1", "ro2", "ro3", "ro4", "ro5")
SCREE = R("ro1", "sc1", "sc2", "sc3", "ro4")
WATER = R("wa0", "wa1", "wa2", "wa3")
LIGHTER = {}
for _ramp in (GRASS, CONIFER, EARTH, SAND, SNOW, ROCK, SCREE):
    for _lo, _hi in zip(_ramp, _ramp[1:]):
        LIGHTER.setdefault(_lo, _hi)


def lighter(c):
    return LIGHTER.get(c, c)


def vseed(env, variant):
    return ENV_SEED[env] * 10 + VARIANTS.index(variant) + 1


def is_accent(variant):
    return variant.startswith("accent")


def new_tile(env, variant):
    return Tile(f"env_{env}_{variant}", "environments")


def mix(variant, base, own):
    """Shared edge band + per-variant interior. The "base" pseudo-variant (used by blends.py) is
    the shared field everywhere, which every real variant matches near the border."""
    return base if variant == "base" else blend_fields(base, own())


def ground_field(env, variant, salt=0, weights=CALM):
    return mix(variant, fbm(ENV_SEED[env] + salt, weights), lambda: fbm(vseed(env, variant) * 13 + salt, weights))


def details(env, variant, shared_count, own_count, spacing, salt=0):
    shared = scatter(ENV_SEED[env] * 7 + salt, shared_count, spacing, max_border=BAND)
    if variant == "base":
        return shared
    own = scatter(vseed(env, variant) * 7 + salt, own_count, spacing, min_border=INNER, avoid=shared)
    return shared + own


def hashf(x, y, k=0):
    return ((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) % 1000 / 1000.0


def smooth(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3 - 2 * t)


# --------------------------------------------------------------------------- light
def lambert(Hf, x, y, light=LIGHT):
    """How much a height-field pixel faces the light, 0..1 (flat ground is light[2])."""
    gx = (Hf[wrap(x + 1, y)] - Hf[wrap(x - 1, y)]) * 0.5
    gy = (Hf[wrap(x, y + 1)] - Hf[wrap(x, y - 1)]) * 0.5
    n = math.sqrt(gx * gx + gy * gy + 1.0)
    return max(0.0, (-gx * light[0] - gy * light[1] + light[2]) / n)


def cast_shadow(Hf, x, y, rise=0.75, reach=18):
    """True when something between this pixel and the light stands above the light's ray."""
    h0 = Hf[(x, y)]
    for k in range(1, reach):
        if Hf[wrap(round(x - k * 0.78), round(y - k * 0.62))] > h0 + k * rise:
            return True
    return False


def relief(t, Hf, albedo, ramp, light_w=1.0, band=0.25, shadows=False):
    """Paint ground from a height field and an albedo field (both lattice periodic)."""
    for x, y in HEX_PIXELS:
        v = albedo[(x, y)] + light_w * (lambert(Hf, x, y) - LIGHT[2])
        if shadows and cast_shadow(Hf, x, y):
            v -= 0.22
        t.px[y][x] = ramp_pick(v, ramp, x, y, band)


def raised(t, Hf, colour, lift=1.0, keep=6.5):
    """Draw a height field raised in 3/4 view: each ground pixel is lifted by its height, drawn
    near-to-far per column so what stands in front hides what is behind. `colour(x, y, lit, depth)`
    picks the colour of ground pixel (x, y) drawn `depth` rows under the top of its span. Only
    pixels further than `keep` from the border change, so the shared band is never touched."""
    for x in range(TILE_W):
        column = [y for y in range(TILE_H) if in_hex(x, y)]
        ybuf = column[-1] + 1
        for y in reversed(column):
            h = Hf[(x, y)] * lift
            sy = int(round(y - h))
            if sy >= ybuf:
                continue
            if h > 0.05:
                lit = lambert(Hf, x, y, RAISED_LIGHT) * (0.72 if cast_shadow(Hf, x, y, rise=0.9) else 1.0)
                for yy in range(max(sy, 0), ybuf):
                    if in_hex(x, yy) and BORDER[yy][x] >= keep:
                        t.px[yy][x] = colour(x, y, lit, yy - sy)
            ybuf = sy


# --------------------------------------------------------------------------- props
def ground_shadow(t, cx, cy, rx, ry, steps=1, wrapped=True):
    """A soft oval shadow on the ground, offset to the bottom-right of what casts it."""
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            e = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if e < 1.0 and (e < 0.7 or bayer(x, y) < 0.5):
                t.darken(x, y, wrapped=wrapped, steps=steps)


def canopy(t, cx, cy, r, ramp, seed, wrapped=True, shadow=True):
    """A broadleaf crown from above: a dark mass with lit clumps stacked towards the top-left.
    `ramp` runs outline, shade, body, lit, highlight. Draws with put/darken only (blends.py
    replays it through a shifted proxy)."""
    rng = random.Random(seed)
    blob = dome(cx + 0.5, cy + 0.5, r, r * 0.9, seed=seed, lump=0.16, lobes=5)
    shape = set(blob)
    if shadow:
        for q in shadow_set(shape, 3, 3):
            t.darken(*q, wrapped=wrapped, steps=2)
    for (x, y) in shape:
        t.put(x, y, ramp[1], wrapped=wrapped)
    n = max(4, int(r * r * 0.32))
    clumps = []
    for _ in range(n):
        a, d = rng.uniform(0, math.tau), r * math.sqrt(rng.random()) * 0.78
        clumps.append((cx + 0.5 + math.cos(a) * d, cy + 0.5 + math.sin(a) * d * 0.9, r * rng.uniform(0.34, 0.46)))
    # far (bottom-right) clumps first so the lit top-left ones sit on top
    for px, py, rc in sorted(clumps, key=lambda c: c[0] + c[1], reverse=True):
        glob = -((px - cx) + (py - cy)) / (r * 1.4)             # -1 bottom-right .. 1 top-left
        for y in range(int(py - rc) - 1, int(py + rc) + 2):
            for x in range(int(px - rc) - 1, int(px + rc) + 2):
                if (x, y) not in shape:
                    continue
                dx, dy = (x + 0.5 - px) / rc, (y + 0.5 - py) / rc
                dd = dx * dx + dy * dy
                if dd > 1.0:
                    continue
                side = -(dx + dy) / 1.414                       # this clump's own lit side
                v = 0.5 + 0.28 * side + 0.3 * glob + 0.12 * (1 - dd)
                k = 1 + int(min(max(v, 0.0), 0.999) * (len(ramp) - 1))
                if dd > 0.72 and side < 0:
                    k = 1                                       # the clump's shaded underside
                t.put(x, y, ramp[min(k, len(ramp) - 1)], wrapped=wrapped)
    for x, y in shape:                                          # outline on the shaded side only
        if (x - cx) + (y - cy) > -r * 0.6 and any((x + dx, y + dy) not in shape
                                                   for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))):
            t.put(x, y, ramp[0], wrapped=wrapped)


def pine(t, bx, by, h, ramp, snow=False, wrapped=True, shadow=True):
    """A conifer in 3/4 view standing on (bx, by): stacked tiers, lit on the left.
    `ramp` runs outline, shade, body, lit, highlight."""
    tiers = 3 if h >= 9 else 2
    w_max = h * 0.42
    if shadow:
        ground_shadow(t, bx + h * 0.35, by + 0.5, h * 0.42, h * 0.2, steps=2, wrapped=wrapped)
    t.put(bx, by, C["di1"], wrapped=wrapped)
    top = by - h
    for y in range(top, by):
        f = (y - top) / h                                       # 0 at the tip, 1 at the foot
        tier = min(int(f * tiers), tiers - 1)
        tf = f * tiers - tier                                   # 0..1 within a tier
        half = max(w_max * (0.35 + 0.65 * (tier + 1) / tiers) * (0.25 + 0.75 * tf), 0.6)
        x0, x1 = int(round(bx + 0.5 - half)), int(round(bx + 0.5 + half)) - 1
        for x in range(x0, x1 + 1):
            u = (x - bx) / max(half, 1)                         # -1 left .. 1 right
            if x == x1 or (tf > 0.8 and u > -0.2):
                c = ramp[0]
            elif u < -0.35:
                c = ramp[3] if tf < 0.75 else ramp[2]
            elif u < 0.25:
                c = ramp[2]
            else:
                c = ramp[1]
            if snow and tf < 0.5 and u < 0.55 and c != ramp[0]:
                c = C["sn5"] if u < -0.1 else C["sn3"]
            t.put(x, y, c, wrapped=wrapped)
        if tf < 0.2 and x0 == x1:
            t.put(x0, y, C["sn5"] if snow else ramp[4], wrapped=wrapped)


def rock(t, cx, cy, rx, ry, seed, ramp=None, wrapped=True, moss=None):
    """A small raised stone: lit top-left, dark foot and a cast shadow.
    `ramp` runs outline, shade, body, lit, highlight."""
    ramp = ramp or R("ro0", "ro2", "ro3", "ro4", "ro5")
    blob = dome(cx, cy, rx, ry, seed=seed, lump=0.2)
    for q in shadow_set(set(blob), 2, 1):
        t.darken(*q, wrapped=wrapped, steps=2)
    for (x, y), (h, nx, ny) in blob.items():
        v = 0.45 * h + 0.55 * (0.5 - 0.5 * (nx + ny) / 1.414)
        c = ramp[min(1 + int(min(v, 0.999) * (len(ramp) - 1)), len(ramp) - 1)]
        if moss and nx + ny < -0.3 and hashf(x, y, seed) < 0.6:
            c = moss[int(hashf(x, y, 1) * len(moss))]
        if (ny > 0.55 and h < 0.55) or (nx + ny > 0.9 and h < 0.45):
            c = ramp[0]
        t.put(x, y, c, wrapped=wrapped)


def pebbles(t, pts, ramp):
    """Two-pixel stones: a lit pixel with its shadow to the bottom-right."""
    for x, y in pts:
        t.put(x, y, ramp[2])
        t.put(x + 1, y, ramp[1])
        t.darken(x + 1, y + 1)
        if hashf(x, y, 5) < 0.35:
            t.put(x, y - 1, ramp[3])


def blades(t, x, y, big=False):
    """A grass clump: a few upright blades lit at the tip, a step either side of the ground's tone."""
    g = t.get(x, y)
    hi, lo = lighter(lighter(g)), DARKER[g]
    t.put(x, y + 1, lo)
    t.put(x, y, lighter(g))
    t.put(x, y - 1, hi)
    if big:
        for dx in (-2, 2):
            t.put(x + dx, y + 1, lo)
            t.put(x + dx, y, hi if dx < 0 else lighter(g))
        t.put(x + 1, y + 1, lo)
        t.put(x - 1, y + 1, lo)


def flower_patch(t, cx, cy, seed, count, radius, colours):
    rng = random.Random(seed)
    for _ in range(count):
        a, d = rng.uniform(0, math.tau), radius * math.sqrt(rng.random())
        x, y = int(cx + math.cos(a) * d), int(cy + math.sin(a) * d * 0.8)
        t.darken(x + 1, y + 1)
        t.put(x, y, colours[rng.randrange(len(colours))])


def pond(t, cx, cy, rx, ry, seed, bank, reeds=None, ice=False):
    """Still water from above: dark where the far (top-left) bank shades it, the sky's glint
    across the middle, reeds along the near shore. `ice=True` freezes it over."""
    blob = dome(cx + 0.5, cy + 0.5, rx, ry, seed=seed, lump=0.2)
    shape = set(blob)
    for x, y in {(x + dx, y + dy) for x, y in shape for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1), (1, 1))} - shape:
        t.put(x, y, bank)
    ramp = R("ice_dk", "ice", "ice_lt", "sn4") if ice else WATER
    for (x, y), (h, nx, ny) in blob.items():
        edge = nx + ny
        if ice:
            k = 1 if edge < -0.7 and h < 0.7 else 2 if h < 0.5 else 3 if (x + 2 * y) % 9 else 2
        else:
            k = 0 if edge < -0.8 and h < 0.45 else 1 if edge < -0.3 or h < 0.3 else 2
        t.put(x, y, ramp[k])
    rng = random.Random(seed)
    for _ in range(3):                                           # glints
        gx, gy = int(cx + rng.uniform(-rx * 0.4, rx * 0.3)), int(cy + rng.uniform(-ry * 0.2, ry * 0.4))
        for k in range(rng.randint(2, 4)):
            if (gx + k, gy) in shape:
                t.put(gx + k, gy, C["sn5"] if ice else ramp[-1])
    if reeds:
        rim = sorted(p for p, (h, nx, ny) in blob.items() if nx + ny > 0.8 and h < 0.4)
        for x, y in rng.sample(rim, min(8, len(rim))):
            t.put(x, y + 1, reeds[0])
            t.put(x, y, reeds[1])
            t.put(x, y - 1, reeds[2])
    return shape


def outcrop(t, rocks, seed, ramp):
    """A cluster of big raised stones drawn back to front."""
    for i, (x, y, rx, ry) in enumerate(sorted(rocks, key=lambda r: r[1])):
        rock(t, x + 0.5, y + 0.5, rx, ry, seed + i, ramp=ramp)


# --------------------------------------------------------------------------- grass
MEADOW_FLOWERS = R("bone", "amber", "sn5", "lilac")
BROADLEAF = R("fo1", "gr0", "gr1", "gr2", "gr3", "gr4")


def meadow_ground(t, variant):
    alb = ground_field("grass", variant)
    swell = ground_field("grass", variant, salt=5)
    Hf = {p: 2.2 * swell[p] for p in HEX_PIXELS}
    relief(t, Hf, {p: 0.62 + 0.2 * (alb[p] - 0.5) for p in HEX_PIXELS}, GRASS, light_w=0.9, band=0.2)
    for x, y in details("grass", variant, 36, 22, 4.2):
        blades(t, x, y, big=hashf(x, y, 3) < 0.4)
    for x, y in details("grass", variant, 10, 5, 7, salt=1):
        if hashf(x, y, 9) < 0.5:
            flower_patch(t, x, y, x * 7 + y, 3, 1.6, MEADOW_FLOWERS)


def grass(variant, objects=True):
    t = new_tile("grass", variant)
    meadow_ground(t, variant)
    if not objects or variant == "base":
        return t
    s = vseed("grass", variant)
    if variant == "v1":
        canopy(t, 20, 38, 4.2, BROADLEAF, s)
        canopy(t, 25, 41, 3.2, BROADLEAF, s + 1)
        rock(t, 36.5, 27.5, 2.4, 1.8, s + 2)
    elif variant == "v2":
        flower_patch(t, 31, 30, s, 16, 6.0, MEADOW_FLOWERS)
        rock(t, 22.5, 38.5, 3.0, 2.2, s + 3)
        rock(t, 26.5, 40.5, 1.8, 1.4, s + 4)
    elif variant == "v3":
        canopy(t, 33, 33, 6.8, BROADLEAF, s)
        canopy(t, 20, 26, 2.8, BROADLEAF, s + 1)
    elif variant == "accent":
        pond(t, 27, 35, 9.5, 6.0, s, C["gr1"], reeds=R("gr1", "gr3", "gr5"))
        canopy(t, 37, 24, 4.6, BROADLEAF, s + 1)
        flower_patch(t, 18, 27, s + 2, 6, 2.5, MEADOW_FLOWERS)
    elif variant == "accent2":
        flower_patch(t, 28, 34, s, 40, 11.0, MEADOW_FLOWERS)
        canopy(t, 25, 30, 8.8, BROADLEAF, s + 1)
    elif variant == "accent3":
        outcrop(t, [(22, 30, 4.8, 3.6), (31, 34, 6.0, 4.4), (26, 40, 3.2, 2.4), (37, 40, 2.4, 1.8)],
                s, R("ro0", "ro2", "ro3", "ro4", "ro5"))
        flower_patch(t, 34, 26, s + 1, 5, 2.0, MEADOW_FLOWERS)
    return t


# --------------------------------------------------------------------------- dirt
def dry_bush(t, cx, cy, seed, r=3.0):
    canopy(t, cx, cy, r, R("di1", "st1", "st1", "st2", "di5"), seed)


def dead_tree(t, cx, cy, seed):
    """A bare tree from above: branches forking out of the trunk, lit on their top-left edge."""
    rng = random.Random(seed)
    ground_shadow(t, cx + 4, cy + 3, 6, 3.5)
    tips = []
    for k in range(5):
        a = k / 5 * math.tau + rng.uniform(-0.3, 0.3)
        ln = rng.uniform(5, 8)
        ex, ey = int(cx + math.cos(a) * ln), int(cy + math.sin(a) * ln * 0.85)
        tips.append((ex, ey, a))
        for x, y in line_pixels(cx, cy, ex, ey):
            t.put(x, y, C["di1"])
            t.put(x - 1, y - 1, C["di3"])
    for ex, ey, a in tips:
        for da in (-0.6, 0.6):
            for x, y in line_pixels(ex, ey, int(ex + math.cos(a + da) * 3), int(ey + math.sin(a + da) * 3)):
                t.put(x, y, C["di1"])
    for dx, dy, c in ((0, 0, "di4"), (-1, 0, "di3"), (1, 0, "di1"), (0, 1, "di1"), (0, -1, "di3")):
        t.put(cx + dx, cy + dy, C[c])


def earth_ground(t, variant, dig=None):
    alb = ground_field("dirt", variant)
    clods = mix(variant, periodic_noise(2203, 2), lambda: periodic_noise(vseed("dirt", variant) * 7, 2))
    swell = ground_field("dirt", variant, salt=5)
    Hf = {p: 2.0 * swell[p] + 0.8 * clods[p] - (dig(*p) if dig else 0.0) for p in HEX_PIXELS}
    relief(t, Hf, {p: 0.55 + 0.22 * (alb[p] - 0.5) for p in HEX_PIXELS}, EARTH, light_w=1.0, band=0.2,
           shadows=bool(dig))
    for x, y in details("dirt", variant, 7, 3, 11, salt=2):             # dry cracks
        cx, cy = x, y
        for step in range(4 + int(hashf(x, y) * 4)):
            t.put(cx, cy, C["di1"])
            t.put(cx, cy - 1, lighter(t.get(cx, cy - 1)))
            cx += 1
            cy += 1 if hashf(cx, cy, step) < 0.4 else 0
    pebbles(t, details("dirt", variant, 16, 12, 5), EARTH[2:])
    for x, y in details("dirt", variant, 12, 6, 6, salt=3):             # dry grass
        t.put(x, y + 1, C["st1"])
        t.put(x, y, C["st2"])
        t.put(x + 1, y + 1, C["st1"])
        if hashf(x, y, 4) < 0.5:
            t.put(x - 1, y, C["st2"])
            t.put(x - 1, y + 1, C["di1"])


def _wash(x, y):
    """A dry stream bed cut across the tile, deepest down its middle."""
    u = (x + 0.5 - 28) * 0.8 + (y + 0.5 - 32) * 0.6
    v = -(x + 0.5 - 28) * 0.6 + (y + 0.5 - 32) * 0.8 + 3.0 * math.sin(u * 0.28)
    return 6.0 * smooth(1 - abs(v) / 4.5) * interior_weight(x, y, 7, 13)


def _puddles(x, y):
    return 3.0 * max(smooth(1 - math.hypot(x + 0.5 - 24, (y + 0.5 - 34) * 1.5) / 7.0),
                     smooth(1 - math.hypot(x + 0.5 - 34, (y + 0.5 - 40) * 1.5) / 4.0)) * interior_weight(x, y)


def dirt(variant, objects=True):
    t = new_tile("dirt", variant)
    dig = {"accent": _wash, "accent3": _puddles}.get(variant) if objects else None
    earth_ground(t, variant, dig)
    if not objects or variant == "base":
        return t
    s = vseed("dirt", variant)
    stone = R("di0", "sc1", "sc2", "sc3", "ro4")
    if variant == "v1":
        dry_bush(t, 22, 36, s)
        dry_bush(t, 34, 27, s + 1)
    elif variant == "v2":
        rock(t, 29.5, 31.5, 4.2, 3.2, s, ramp=stone)
        rock(t, 23.5, 36.5, 2.2, 1.7, s + 1, ramp=stone)
        rock(t, 35.5, 36.5, 1.6, 1.3, s + 2, ramp=stone)
    elif variant == "v3":
        dead_tree(t, 26, 31, s)
        dry_bush(t, 37, 39, s + 1)
    elif variant == "accent":
        for x, y in HEX_PIXELS:                                          # pale silt on the wash's floor
            if _wash(x, y) > 4.2 and bayer(x, y) < 0.75:
                t.px[y][x] = C["di4"] if hashf(x, y) < 0.8 else C["di5"]
        rock(t, 19.5, 40.5, 2.6, 2.0, s, ramp=R("di0", "di2", "di3", "di4", "di5"))
        dry_bush(t, 37, 23, s + 1)
    elif variant == "accent2":
        outcrop(t, [(24, 30, 5.4, 4.0), (32, 35, 6.8, 5.0), (21, 38, 3.0, 2.3), (38, 28, 2.6, 2.0)], s, stone)
        dry_bush(t, 36, 43, s + 5, r=2.4)
    elif variant == "accent3":
        for x, y in HEX_PIXELS:                                          # water standing in the ruts
            d = _puddles(x, y)
            if d > 1.9:
                t.px[y][x] = C["wa1"] if d < 2.4 else C["wa2"] if hashf(x, y, 2) < 0.85 else C["wa3"]
            elif d > 1.3:
                t.px[y][x] = C["di1"]
        for x, y in ((20, 31), (22, 30), (30, 38)):
            t.put(x, y, C["wa3"])
        dry_bush(t, 36, 28, s)
    return t


# --------------------------------------------------------------------------- desert
DUNES = {}


def dunes(variant):
    """Sand ridges periodic on the lattice ((56,0) -> 2 cycles, (28,48) -> 3): each rises slowly
    towards the light and drops steeply behind its crest."""
    if variant not in DUNES:
        warp = mix(variant, periodic_noise(3011, 22), lambda: periodic_noise(vseed("desert", variant) * 17, 22))
        swell = ground_field("desert", variant, salt=5)
        out = {}
        for x, y in HEX_PIXELS:
            s = (x / 28 + y / 24 + 0.6 * warp[(x, y)]) % 1.0
            ridge = s / 0.66 if s < 0.66 else (1.0 - s) / 0.34        # long windward slope, short slip face
            out[(x, y)] = 2.6 * smooth(ridge) + 1.2 * swell[(x, y)]
        DUNES[variant] = out
    return DUNES[variant]


def sand_ground(t, variant):
    Hf = dunes(variant)
    alb = ground_field("desert", variant)
    relief(t, Hf, {p: 0.62 + 0.12 * (alb[p] - 0.5) for p in HEX_PIXELS}, SAND, light_w=0.7, band=0.18)
    for x, y in HEX_PIXELS:                                          # a bright lip on every crest
        h = Hf[(x, y)]
        if h > Hf[wrap(x + 1, y + 1)] + 0.5 and h >= Hf[wrap(x - 1, y - 1)] and lambert(Hf, x, y) > 0.45:
            t.px[y][x] = C["de4"]
    pebbles(t, details("desert", variant, 6, 4, 10), SAND[1:])


CLIFF = R("di1", "de0", "brick_dk", "rust", "de1", "de2")


def mesa(t, cx, cy, rx, ry, height, seed):
    """A flat-topped sandstone butte with strata, raised in 3/4 view."""
    noise = periodic_noise(seed, 3)

    def h(x, y):
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        ang = math.atan2(dy, dx)
        d = math.hypot(dx, dy) * (1 + 0.12 * math.sin(3 * ang + seed) + 0.1 * (noise[(x, y)] - 0.5))
        return height * smooth((1.0 - d) / 0.22) * interior_weight(x, y, 7, 12)

    Hf = {p: h(*p) for p in HEX_PIXELS}
    for q in {wrap(x + dx, y + dy) for (x, y) in HEX_PIXELS if Hf[(x, y)] > 1 for dx, dy in ((3, 2), (5, 3))}:
        if Hf[q] < 0.5:
            t.darken(*q, steps=2)

    def colour(x, y, lit, depth):
        if Hf[(x, y)] > height * 0.92:                              # the flat top
            return C["de3"] if lit > 0.45 else C["de2"]
        k = int(lit * 4.2) - ((depth + (x % 3 == 0)) % 4 == 0)       # strata on the cliff face
        return CLIFF[max(0, min(k, len(CLIFF) - 1))]

    raised(t, Hf, colour)


def cactus(t, x, y):
    ground_shadow(t, x + 2.5, y + 0.5, 3.0, 1.4)
    for yy in range(y - 6, y + 1):
        t.put(x, yy, C["co3"])
        t.put(x + 1, yy, C["co1"])
    t.put(x, y - 7, C["co4"])
    for yy in range(y - 4, y - 1):
        t.put(x - 2, yy, C["co3"])
    t.put(x - 1, y - 2, C["co2"])
    for yy in range(y - 5, y - 2):
        t.put(x + 3, yy, C["co1"])
    t.put(x + 2, y - 3, C["co1"])


def palm(t, x, y, seed, h=9):
    """A palm in 3/4 view: a leaning trunk and a star of fronds."""
    ground_shadow(t, x + 5, y + 1, 5, 2.5)
    lean = 1 if seed % 2 else -1
    tx, ty = x, y
    for k in range(h):
        tx, ty = x + round(lean * k * k / (h * 3.0)), y - k
        t.put(tx, ty, C["di3"] if k % 2 else C["di2"])
    for a in range(6):
        ang = a / 6 * math.tau + 0.3
        for d in range(1, 6):
            fx = tx + round(math.cos(ang) * d)
            fy = ty + round(math.sin(ang) * d * 0.7 + (d * d) / 10)
            t.put(fx, fy, C["gr2"] if math.cos(ang) > 0.2 or math.sin(ang) > 0.3 else C["gr4"])
            if d > 2:
                t.put(fx, fy + 1, C["gr1"])
    t.put(tx, ty, C["gr5"])


def skeleton(t, cx, cy):
    """A bleached animal skeleton half sunk in the sand, head to the right."""
    spine = line_pixels(cx - 8, cy + 2, cx + 5, cy - 1)
    body = set(spine)
    for i, (x, y) in enumerate(spine[2:-3]):
        if i % 2 == 0:
            for k in (1, 2, 3):
                body.add((x - (k == 3), y - k))
                body.add((x - (k == 3), y + k))
    body |= {(cx + 6 + dx, cy - 2 + dy) for dx in range(4) for dy in range(3)}
    for q in shadow_set(body, 1, 1):
        t.darken(*q, steps=2)
    for x, y in body:
        t.put(x, y, C["bone"] if (x + y) % 3 else C["mist"])
    t.put(cx + 7, cy - 1, C["de0"])


def desert(variant, objects=True):
    t = new_tile("desert", variant)
    sand_ground(t, variant)
    if not objects or variant == "base":
        return t
    s = vseed("desert", variant)
    sandstone = R("di1", "de0", "rust", "de1", "de3")
    if variant == "v1":
        rock(t, 21.5, 36.5, 2.4, 1.8, s, ramp=sandstone)
        rock(t, 25.5, 38.5, 1.5, 1.2, s + 1, ramp=sandstone)
    elif variant == "v2":
        cactus(t, 33, 36)
        cactus(t, 22, 28)
    elif variant == "v3":
        outcrop(t, [(30, 34, 4.4, 3.2), (24, 37, 2.6, 2.0), (35, 39, 1.8, 1.4)], s, sandstone)
        cactus(t, 22, 30)
    elif variant == "accent":
        pond(t, 28, 38, 8.0, 4.5, s, C["gr1"], reeds=R("gr1", "gr3", "gr5"))
        for x, y in HEX_PIXELS:                                        # green round the water
            if 8.5 < math.hypot(x + 0.5 - 28, (y + 0.5 - 38) * 1.6) < 12.5 - 2 * bayer(x, y) and t.px[y][x] in SAND:
                t.px[y][x] = C["gr3"] if lambert(dunes(variant), x, y) > 0.55 else C["gr2"]
        palm(t, 20, 36, s)
        palm(t, 35, 33, s + 1, h=11)
        palm(t, 23, 45, s + 2, h=7)
    elif variant == "accent2":
        mesa(t, 29, 38, 12.5, 8.0, 11.0, s)
    elif variant == "accent3":
        skeleton(t, 28, 34)
        rock(t, 20.5, 40.5, 1.8, 1.4, s, ramp=sandstone)
    return t


# --------------------------------------------------------------------------- ice
SNOW_PINE = R("fo1", "co1", "co2", "co3", "co4")


def snow_ground(t, variant):
    drift = ground_field("ice", variant, salt=50)
    fine = mix(variant, periodic_noise(4101, 5), lambda: periodic_noise(vseed("ice", variant) * 5, 5))
    Hf = {p: 3.2 * drift[p] + 0.6 * fine[p] for p in HEX_PIXELS}
    relief(t, Hf, {p: 0.76 for p in HEX_PIXELS}, SNOW, light_w=0.6, band=0.2)
    for x, y in HEX_PIXELS:                                          # blue ice in the hollows
        if drift[(x, y)] + (bayer(x, y) - 0.5) * 0.04 < 0.05:
            t.px[y][x] = C["ice_lt"] if drift[(x, y)] > 0.02 else C["ice"]
    for x, y in details("ice", variant, 3, 4, 12, salt=2):           # sastrugi: wind-cut ridges
        n = 3 + int(hashf(x, y) * 4)
        for k in range(n):
            t.put(x + k, y - (k * 2 // n), C["sn5"])
            t.put(x + k, y - (k * 2 // n) + 1, C["sn2"])


def ice_spire(t, cx, cy, h):
    ground_shadow(t, cx + 3, cy + 1, 3.5, 1.6)
    for yy in range(cy - h, cy + 1):
        f = (yy - (cy - h)) / h
        half = 0.5 + 1.8 * f
        x1 = int(round(cx + 0.5 + half)) - 1
        for x in range(int(round(cx + 0.5 - half)), x1 + 1):
            c = C["sn5"] if x < cx else C["ice_lt"] if x == cx else C["ice"]
            t.put(x, yy, C["ice_dk"] if x == x1 and f > 0.2 else c)


def ice(variant, objects=True):
    t = new_tile("ice", variant)
    snow_ground(t, variant)
    if not objects or variant == "base":
        return t
    s = vseed("ice", variant)
    snowrock = R("ro0", "ro2", "ro3", "sn4", "sn5")
    if variant == "v1":
        rock(t, 31.5, 34.5, 3.2, 2.4, s, ramp=snowrock)
        rock(t, 25.5, 37.5, 1.8, 1.4, s + 1, ramp=snowrock)
    elif variant == "v2":
        pine(t, 30, 38, 11, SNOW_PINE, snow=True)
    elif variant == "v3":
        rock(t, 22.5, 30.5, 2.2, 1.7, s, ramp=snowrock)
        pine(t, 34, 34, 8, SNOW_PINE, snow=True)
    elif variant == "accent":
        lake = pond(t, 28, 34, 11.0, 7.0, s, C["sn3"], ice=True)
        rng = random.Random(s)
        for _ in range(4):                                             # cracks in the sheet
            x, y = 28 + rng.randint(-7, 4), 34 + rng.randint(-3, 3)
            for _ in range(rng.randint(4, 7)):
                t.put(x, y, C["ice_dk"] if (x, y) in lake else C["sn2"])
                x += 1
                y += rng.choice((-1, 0, 1))
        pine(t, 39, 27, 9, SNOW_PINE, snow=True)
    elif variant == "accent2":
        ice_spire(t, 31, 40, 12)
        ice_spire(t, 25, 37, 8)
        ice_spire(t, 36, 43, 6)
        ice_spire(t, 22, 42, 5)
    elif variant == "accent3":
        for bx, by, h in ((22, 32, 10), (36, 30, 9), (30, 38, 13), (21, 43, 7), (38, 43, 8)):
            pine(t, bx, by, h, SNOW_PINE, snow=True)
    return t


# --------------------------------------------------------------------------- forest
FOREST_LEAF = [R("fo1", "gr1", "gr2", "gr3", "gr4"), R("fo1", "gr0", "gr1", "gr2", "gr3"),
               R("fo1", "gr1", "gr2", "gr3", "gr5")]
FLOOR = R("fo0", "fo1", "gr0", "gr1", "di1")


def forest_shared_trees():
    """Tree anchors near the border, identical for every forest variant (also used by blends.py)."""
    return scatter(5007, 70, 9.0, max_border=11.0)


def forest_tree(t, x, y):
    if hashf(x, y, 5) < 0.3:
        pine(t, x, y + 5, 11 + int(hashf(x, y, 6) * 5), CONIFER)
    else:
        canopy(t, x, y, 5.2 + 2.2 * hashf(x, y, 7), FOREST_LEAF[int(hashf(x, y, 8) * 3)], seed=x * 31 + y)


def log(t, cx, cy):
    """A mossy trunk lying diagonally, with a sawn end at the bottom-right."""
    a, b = (cx - 7.0, cy - 4.0), (cx + 6.0, cy + 3.0)
    for y in range(cy - 9, cy + 9):
        for x in range(cx - 11, cx + 11):
            d, s = seg_dist((x + 0.5, y + 0.5), a, b)
            if d < 2.2 and 0 < s < 1:
                qx, qy = a[0] + s * (b[0] - a[0]), a[1] + s * (b[1] - a[1])
                side = (x + 0.5 - qx) + (y + 0.5 - qy)
                c = C["di3"] if side < -1.0 else C["di2"] if side < 0.6 else C["di1"] if side < 1.5 else C["di0"]
                if side < -0.3 and hashf(x, y, 3) < 0.3:
                    c = C["gr2"]
                t.put(x, y, c)
    ex, ey = int(b[0]), int(b[1])
    for dx, dy, c in ((0, 0, "di5"), (1, 0, "di4"), (0, 1, "di4"), (1, 1, "di3"), (-1, 1, "di1"), (1, -1, "di1")):
        t.put(ex + dx, ey + dy, C[c])


def mushrooms(t, pts):
    for x, y in pts:
        t.darken(x + 1, y + 1, steps=2)
        t.put(x, y, C["brick"])
        t.put(x + 1, y, C["brick_dk"])
        t.put(x, y - 1, C["bone"])


def forest(variant, objects=True):
    t = new_tile("forest", variant)
    alb = ground_field("forest", variant)
    relief(t, {p: 4.0 * alb[p] for p in HEX_PIXELS}, {p: 0.42 + 0.3 * (alb[p] - 0.5) for p in HEX_PIXELS}, FLOOR)
    for x, y in details("forest", variant, 18, 8, 6):
        t.put(x, y, C["gr1"])
        t.put(x + 1, y + 1, C["fo1"])
    if not objects:
        return t
    shared = forest_shared_trees()
    own = [] if is_accent(variant) or variant == "base" else scatter(vseed("forest", variant) * 7 + 1, 7, 9.0,
                                                                     min_border=13.0, avoid=shared)
    s = vseed("forest", variant) if variant != "base" else 0

    def clearing(cx, cy, r):
        for x, y in HEX_PIXELS:
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.15)
            if d < r - 2.0 * bayer(x, y):
                t.px[y][x] = ramp_pick(0.55 + 0.25 * (alb[(x, y)] - 0.5) - d / 40, GRASS, x, y, 0.2)

    if variant == "accent":
        clearing(28, 33, 11.0)
        rock(t, 25.5, 33.5, 3.4, 2.6, s, moss=R("gr2", "gr3"))
        flower_patch(t, 31, 38, s, 7, 3.5, R("bone", "amber"))
    elif variant == "accent2":
        clearing(28, 33, 10.0)
        log(t, 28, 33)
        mushrooms(t, [(22, 38), (24, 40), (33, 27)])
    elif variant == "accent3":
        clearing(28, 34, 12.0)
        pond(t, 28, 34, 7.5, 4.8, s, C["gr1"], reeds=R("gr1", "gr3", "gr5"))
    for x, y in sorted(shared + own, key=lambda p: (p[1], p[0])):
        forest_tree(t, x, y)
    return t


# --------------------------------------------------------------------------- mountains
# Each variant's own range: (x, y, radius, height) per peak. Kept to the interior (faded out by
# interior_weight) and placed differently per variant, so a range of tiles is not a grid of cones.
MASSIFS = {
    "v1": [(22, 40, 11.0, 17.0), (34, 36, 12.0, 21.0)],
    "v2": [(28, 40, 15.0, 26.0)],
    "v3": [(20, 38, 8.0, 11.0), (30, 43, 9.0, 13.0), (37, 34, 8.5, 12.0)],
    "accent": [(24, 38, 13.5, 24.0), (36, 42, 8.0, 12.0)],
    "accent2": [(20, 40, 10.0, 18.0), (29, 36, 11.0, 22.0), (38, 41, 9.0, 16.0)],
    "accent3": [(22, 42, 7.0, 8.0), (35, 40, 7.5, 9.0)],
}
SNOWLINE = 11.0


def _peak_height(x, y, px, py, radius, amp, ridges):
    vx, vy = x + 0.5 - px, (y + 0.5 - py) * 1.25
    ang = math.atan2(vy, vx)
    # spurs: the cone is pushed out along a few ridge lines and pinched between them
    d = math.hypot(vx, vy) * (1 + 0.16 * math.sin(4 * ang + px) + 0.08 * math.sin(7 * ang + py)) - ridges[(x, y)] * 2.2
    return amp * (1 - d / radius) ** 1.35 if d < radius else 0.0


def mountain_heights(variant):
    ridges = periodic_noise(vseed("mountains", variant) * 19, 3)
    fine = periodic_noise(vseed("mountains", variant) * 23, 1)
    out = {}
    for x, y in HEX_PIXELS:
        h = max(_peak_height(x, y, *p, ridges) for p in MASSIFS[variant])
        gully = 1 - abs(2 * fine[(x, y)] - 1)                  # ridged: sharp crests, soft gullies
        out[(x, y)] = h * (0.86 + 0.2 * gully) * interior_weight(x, y, 6, 13)
    return out


def mountain_ground(t, variant):
    alb = ground_field("mountains", variant)
    lumps = mix(variant, periodic_noise(6101, 4), lambda: periodic_noise(vseed("mountains", variant) * 3, 4))
    Hf = {p: 2.0 * alb[p] + 1.2 * lumps[p] for p in HEX_PIXELS}
    relief(t, Hf, {p: 0.55 + 0.25 * (alb[p] - 0.5) for p in HEX_PIXELS}, SCREE, light_w=1.0, band=0.2)
    for x, y in HEX_PIXELS:                                         # alpine grass in the hollows
        if alb[(x, y)] + (bayer(x, y) - 0.5) * 0.1 < 0.12:
            t.px[y][x] = C["gr1"] if lambert(Hf, x, y) < 0.6 else C["gr2"]
    pebbles(t, details("mountains", variant, 14, 8, 5), SCREE[1:])


def mountains(variant, objects=True):
    t = new_tile("mountains", variant)
    mountain_ground(t, variant)
    if not objects or variant == "base":
        return t
    Hf = mountain_heights(variant)
    for q in {wrap(x + dx, y + dy) for (x, y) in HEX_PIXELS if Hf[(x, y)] > 1.5
              for dx, dy in ((2, 1), (4, 2), (6, 3))}:
        if Hf[q] < 1.0 and BORDER[q[1]][q[0]] >= 6.5:
            t.darken(*q)

    def colour(x, y, lit, depth):
        h = Hf[(x, y)]
        if h > SNOWLINE - 3.0 * hashf(x, y, 4) and lit > 0.25:
            return C["sn5"] if lit > 0.6 else C["sn4"] if lit > 0.45 else C["sn3"] if lit > 0.3 else C["sn2"]
        k = 1 if lit < 0.22 else 2 if lit < 0.4 else 3 if lit < 0.56 else 4 if lit < 0.72 else 5
        return ROCK[k - 1 if h < 3.0 and k > 1 else k]              # the foot sits in its own shadow

    raised(t, Hf, colour)
    if variant == "accent":
        pond(t, 37, 28, 4.5, 2.6, vseed("mountains", variant), C["ro1"])
    return t


ENVS = {"grass": grass, "dirt": dirt, "desert": desert, "ice": ice, "forest": forest, "mountains": mountains}


def all_environments():
    return [ENVS[e](v) for e in ENV_ORDER for v in VARIANTS]
