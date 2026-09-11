"""Phase 1: environments, 56x64.

Seamless rule: everything within the shared band (details anchored at BORDER < BAND, and the
noise edge band from blend_fields) comes from env-seeded, lattice-periodic data identical for
v1/v2/v3/accent. Per-variant noise and details only appear deeper inside the tile.
`objects=False` renders ground only (no trees/peaks/accent), used under towns.
"""
import math
import random

from hexlib import C, DARKER, HEX_PIXELS, LATTICE_SHIFTS, Tile, bayer, blend_fields, fbm, light, \
    periodic_noise, ramp_pick, wrap
from stamps import boulder, dome, line_pixels, pebble, scatter, shade_dome, tuft

VARIANTS = ["v1", "v2", "v3", "accent"]
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


def vseed(env, variant):
    return ENV_SEED[env] * 10 + VARIANTS.index(variant) + 1


def new_tile(env, variant):
    return Tile(f"env_{env}_{variant}", "environments")


def mix(variant, base, own):
    """Shared edge band + per-variant interior. The "base" pseudo-variant (used by blends.py) is
    the shared field everywhere, which every real variant matches near the border."""
    return base if variant == "base" else blend_fields(base, own())


def ground_field(env, variant, salt=0):
    return mix(variant, fbm(ENV_SEED[env] + salt), lambda: fbm(vseed(env, variant) * 13 + salt))


def paint_field(tile, field, ramp, band=0.3):
    for x, y in HEX_PIXELS:
        tile.px[y][x] = ramp_pick(field[(x, y)], ramp, x, y, band)


def details(env, variant, shared_count, own_count, spacing, salt=0):
    shared = scatter(ENV_SEED[env] * 7 + salt, shared_count, spacing, max_border=BAND)
    if variant == "base":
        return shared
    own = scatter(vseed(env, variant) * 7 + salt, own_count, spacing, min_border=INNER, avoid=shared)
    return shared + own


def accent_center(env, jitter=3):
    rng = random.Random(ENV_SEED[env] * 3)
    return 28 + rng.randint(-jitter, jitter), 32 + rng.randint(-jitter, jitter)


def hashf(x, y, k=0):
    return ((x * 73856093) ^ (y * 19349663) ^ (k * 83492791)) % 1000 / 1000.0


# --------------------------------------------------------------------------- grass
def flowering_bush(t, cx, cy, seed):
    rng = random.Random(seed)
    blob = dome(cx + 0.5, cy + 0.5, 7.5, 5.5, seed=seed, lump=0.22)
    shade_dome(t, blob, [C["leaf_dk"], C["leaf"], C["leaf_lt"]], outline=C["pine"], shadow_offset=(2, 2))
    spots = [p for p in blob if blob[p][0] > 0.35]
    rng.shuffle(spots)
    placed = []
    for p in spots:
        if len(placed) == 12:
            break
        if all(abs(p[0] - q[0]) + abs(p[1] - q[1]) >= 3 for q in placed):
            placed.append(p)
    colors = [C["amber"], C["bone"], C["lilac"], C["rust"]]
    for i, (x, y) in enumerate(placed):
        col = colors[i % len(colors)]
        t.put(x, y, col)
        t.put(x + 1, y, col)
        t.put(x, y + 1, DARKER[col])
        t.put(x + 1, y + 1, C["leaf_dk"])


def grass(variant, objects=True):
    t = new_tile("grass", variant)
    paint_field(t, ground_field("grass", variant),
                [C["leaf_dk"], C["leaf"], C["leaf"], C["leaf"], C["leaf_lt"]])
    for x, y in details("grass", variant, 40, 14, 6):
        hi = C["leaf_hi"] if (x + y) % 4 == 0 else C["leaf_lt"]
        tuft(t, x, y, hi, C["leaf_lt"], C["leaf_dk"], big=(x * 7 + y * 3) % 3 == 0)
    for x, y in details("grass", variant, 18, 6, 5, salt=1):
        t.put(x, y, C["leaf_hi"])
    if variant == "accent" and objects:
        flowering_bush(t, *accent_center("grass"), seed=vseed("grass", variant))
    return t


# --------------------------------------------------------------------------- dirt
def dirt(variant, objects=True):
    t = new_tile("dirt", variant)
    paint_field(t, ground_field("dirt", variant),
                [C["earth"], C["soil"], C["soil"], C["soil"], C["soil_lt"]])
    moist = ground_field("dirt", variant, salt=40)
    for x, y in HEX_PIXELS:
        if moist[(x, y)] + (bayer(x, y) - 0.5) * 0.06 > 0.84:
            t.px[y][x] = DARKER[t.px[y][x]]
    for x, y in details("dirt", variant, 6, 2, 12, salt=2):          # short dry cracks
        cx, cy = x, y
        for step in range(5):
            nx, ny = cx + 1, cy + (1 if (x + step) % 3 == 0 else 0)
            t.put(cx, cy, C["earth"])
            t.put(cx, cy - 1, C["soil_lt"])
            cx, cy = nx, ny
    for x, y in details("dirt", variant, 30, 10, 5):
        if (x + 2 * y) % 5 == 0:
            pebble(t, x, y, C["stone_lt"], C["stone"], C["slate"], big=True)
        else:
            pebble(t, x, y, C["soil_lt"], C["soil"], C["earth"], big=(x + y) % 3 == 0)
    for x, y in details("dirt", variant, 5, 2, 10, salt=3):          # sprouts
        t.put(x, y, C["leaf"])
        t.put(x + 1, y, C["leaf_dk"])
        t.put(x - 1, y + 1, C["leaf_dk"])
    if variant == "accent" and objects:
        cx, cy = accent_center("dirt")
        s = vseed("dirt", variant)
        for px, py in ((cx - 12, cy - 2), (cx + 12, cy - 4), (cx - 3, cy + 9), (cx + 6, cy + 10), (cx - 9, cy + 6)):
            pebble(t, px, py, C["stone_lt"], C["stone"], C["slate"], big=True)
        boulder(t, cx - 7.0, cy + 6.0, 3.0, 2.3, seed=s + 1)
        boulder(t, cx + 0.5, cy + 0.5, 7.0, 5.2, seed=s)
        boulder(t, cx + 10.0, cy + 5.0, 3.4, 2.6, seed=s + 2)
    return t


# --------------------------------------------------------------------------- desert
def cracked_patch(t, cx, cy, seed):
    rng = random.Random(seed)
    cells = [(cx + gx * 7.5 + (3.7 if gy % 2 else 0.0) + rng.uniform(-1.8, 1.8), cy + gy * 6.5 + rng.uniform(-1.4, 1.4))
             for gy in range(-2, 3) for gx in range(-3, 3)]
    crack, plate = set(), set()
    for y in range(cy - 11, cy + 12):
        for x in range(cx - 15, cx + 16):
            e = ((x + 0.5 - cx) / 14.0) ** 2 + ((y + 0.5 - cy) / 10.0) ** 2
            if e > 1.0 or (e > 0.6 and bayer(x, y) < (e - 0.6) / 0.4):
                continue
            ds = sorted(math.hypot(x + 0.5 - px, y + 0.5 - py) for px, py in cells)
            (crack if ds[1] - ds[0] < 0.85 else plate).add((x, y))
    for x, y in plate:
        t.put(x, y, C["sand_lt"])
    for x, y in crack:
        t.put(x, y, C["soil_lt"])
        if (x + 1, y + 1) in plate:
            t.put(x + 1, y + 1, C["sand_dk"])


def desert(variant, objects=True):
    t = new_tile("desert", variant)
    field = ground_field("desert", variant)
    warp = mix(variant, periodic_noise(3011, 30), lambda: periodic_noise(vseed("desert", variant) * 17, 30))
    flat = [C["sand_dk"]] + [C["sand"]] * 6 + [C["sand_lt"]]
    for x, y in HEX_PIXELS:
        # periodic on the lattice: (56,0) -> +2 cycles, (28,48) -> +3 cycles
        s = (x / 28 + y / 24 + 0.45 * warp[(x, y)] + (bayer(x, y) - 0.5) * 0.03) % 1.0
        if s < 0.06:
            c = C["sand_lt"]
        elif s < 0.15:
            c = C["sand_dk"]
        else:
            c = ramp_pick(field[(x, y)], flat, x, y)
        t.px[y][x] = c
    for x, y in details("desert", variant, 18, 6, 8):
        pebble(t, x, y, C["sand_lt"], C["sand_dk"], C["soil_lt"], big=(x + y) % 4 == 0)
    if variant == "accent" and objects:
        cracked_patch(t, *accent_center("desert"), seed=vseed("desert", variant))
    return t


# --------------------------------------------------------------------------- ice
def crevasse(t, cx, cy, seed):
    rng = random.Random(seed)
    pts = [(cx - 18, cy - 4)]
    while pts[-1][0] < cx + 16:
        x, y = pts[-1]
        pts.append((x + rng.randint(4, 6), min(max(y + rng.choice((-2, -1, 1, 2, 2)), cy - 7), cy + 7)))
    core = set()
    for i, (a, b) in enumerate(zip(pts, pts[1:])):
        seg = line_pixels(*a, *b)
        core.update(seg)
        if len(pts) // 3 <= i < 2 * len(pts) // 3:
            core.update((x, y + 1) for x, y in seg)
    for i, sign in ((2, 1), (len(pts) - 3, -1)):
        bx, by = pts[i]
        core.update(line_pixels(bx, by, bx + rng.choice((-2, 2)), by + 5 * sign))
    for x, y in core:
        if (x + 1, y + 1) not in core:
            t.put(x + 1, y + 1, C["ice_dk"])
        if (x - 1, y - 1) not in core:
            t.put(x - 1, y - 1, C["snow"])
    for x, y in core:
        t.put(x, y, C["abyss"])


def ice(variant, objects=True):
    t = new_tile("ice", variant)
    field = ground_field("ice", variant)
    drift = ground_field("ice", variant, salt=50)
    ramp = [C["ice"], C["ice_lt"], C["ice_lt"], C["ice_lt"], C["ice_lt"]]
    for x, y in HEX_PIXELS:
        if drift[(x, y)] + (bayer(x, y) - 0.5) * 0.08 > 0.78:
            t.px[y][x] = C["snow"]
        else:
            t.px[y][x] = ramp_pick(field[(x, y)], ramp, x, y)
    for x, y in details("ice", variant, 5, 2, 14, salt=2):           # hairline cracks
        cx, cy = x, y
        for step in range(3):
            nx, ny = cx + 3, cy + (1 if (x + step) % 2 else -1)
            for px, py in line_pixels(cx, cy, nx, ny):
                t.put(px, py, C["ice"])
                t.put(px, py - 1, C["snow"])
            cx, cy = nx, ny
    for x, y in details("ice", variant, 10, 3, 8, salt=1):           # small diagonal glints
        t.put(x, y, C["snow"])
        t.put(x + 1, y - 1, C["snow"])
        t.put(x + 1, y + 1, C["ice"])
    if variant == "accent" and objects:
        crevasse(t, *accent_center("ice"), seed=vseed("ice", variant))
    return t


# --------------------------------------------------------------------------- forest
def broadleaf(t, x, y):
    k = hashf(x, y)
    r = 5.8 + 1.8 * k
    blob = dome(x + 0.5, y + 0.5, r, r * 0.92, seed=x * 31 + y, lump=0.15)
    shade_dome(t, blob, [C["pine"], C["leaf_dk"], C["leaf"], C["leaf_lt"]],
               outline=C["pine_dk"], shadow_offset=(3, 3))
    shape = set(blob)
    for i in range(4):
        ang = hashf(x, y, i + 1) * math.tau
        ox, oy = math.cos(ang) * r * 0.42, math.sin(ang) * r * 0.42 - r * 0.12
        sub = {p: v for p, v in dome(x + 0.5 + ox, y + 0.5 + oy, r * 0.45, r * 0.42).items()
               if p in shape and p not in _ring(shape)}
        shade_dome(t, sub, [C["leaf_dk"], C["leaf"], C["leaf_lt"], C["leaf_hi"]], shadow_offset=None)


def _ring(shape):
    return {(px, py) for px, py in shape
            if any((px + dx, py + dy) not in shape for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))}


def conifer(t, x, y):
    r = 5.0 + 1.5 * hashf(x, y, 9)
    blob = dome(x + 0.5, y + 0.5, r, r, seed=x * 17 + y, lump=0.45, lobes=7)
    shade_dome(t, blob, [C["pine_dk"], C["pine"], C["leaf_dk"], C["leaf"]],
               outline=C["ink"], shadow_offset=(3, 3))
    t.put(x, y, C["leaf_lt"])
    t.put(x - 1, y - 1, C["leaf"])


def fallen_log(t, cx, cy):
    x0, x1 = cx - 11, cx + 10
    for x in range(x0, x1 + 3):
        t.darken(x + 2, cy + 3)
        t.darken(x + 1, cy + 4)
    rows = [(-2, "soil_lt"), (-1, "soil_lt"), (0, "soil"), (1, "soil"), (2, "earth")]
    for x in range(x0, x1 + 1):
        for dy, col in rows:
            c = C[col]
            if (x * 3 + dy * 5) % 7 == 0:                 # bark grooves
                c = DARKER[c]
            t.put(x, cy + dy, c)
    for dy, col in ((-2, "earth"), (-1, "sand_dk"), (0, "sand"), (1, "sand_dk"), (2, "earth")):
        t.put(x1 + 1, cy + dy, C[col])                    # cut end with rings
    t.put(x1 + 1, cy, C["soil_lt"])
    for dy in (-1, 0, 1, 2):
        t.put(x0 - 1, cy + dy, C["earth_dk"])             # broken end
    t.put(x0 - 2, cy, C["earth_dk"])
    for mx in (x0 + 3, x0 + 4, x0 + 9, x0 + 15, x0 + 16):
        t.put(mx, cy - 2, C["leaf_dk"])                   # moss
    t.put(x0 + 4, cy - 2, C["leaf"])


def stump(t, cx, cy):
    blob = dome(cx + 0.5, cy + 0.5, 3.0, 2.6)
    shade_dome(t, blob, [C["earth"], C["soil"], C["soil_lt"]], outline=C["earth_dk"], shadow_offset=(2, 2))
    t.put(cx, cy, C["sand_dk"])
    t.put(cx - 1, cy, C["sand"])


def mushroom(t, x, y):
    for sx, sy in ((2, 2), (1, 2), (2, 1)):
        t.darken(x + sx, y + sy)
    t.put(x, y, C["bone"])
    t.put(x + 1, y, C["brick"])
    t.put(x, y + 1, C["brick"])
    t.put(x + 1, y + 1, C["brick_dk"])


def forest_shared_trees():
    """Tree anchors near the border, identical for every forest variant (also used by blends.py)."""
    return scatter(5007, 60, 10.5, max_border=11.0)


def forest_tree(t, x, y):
    (conifer if hashf(x, y, 5) < 0.35 else broadleaf)(t, x, y)


def forest(variant, objects=True):
    t = new_tile("forest", variant)
    paint_field(t, ground_field("forest", variant),
                [C["pine_dk"], C["pine"], C["pine"], C["pine"], C["earth"]])
    for x, y in details("forest", variant, 20, 6, 6):
        tuft(t, x, y, C["leaf_dk"], C["pine"], C["pine_dk"], big=(x + y) % 3 == 0)
    if not objects:
        return t
    shared = forest_shared_trees()
    own = [] if variant in ("accent", "base") else scatter(vseed("forest", variant) * 7 + 1, 6, 10.5,
                                                           min_border=14.0, avoid=shared)
    if variant == "accent":
        cx, cy = accent_center("forest", jitter=1)
        fallen_log(t, cx, cy)
        stump(t, cx + 9, cy - 9)
        for i in range(6):
            ang = i / 6 * math.tau + 0.4
            mushroom(t, int(cx - 7 + 4.5 * math.cos(ang)), int(cy + 9 + 3.5 * math.sin(ang)))
    for x, y in sorted(shared + own, key=lambda p: (p[1], p[0])):
        forest_tree(t, x, y)
    return t


# --------------------------------------------------------------------------- mountains
def mountains(variant, objects=True):
    t = new_tile("mountains", variant)
    noise = ground_field("mountains", variant)
    crag = mix(variant, periodic_noise(6101, 6), lambda: periodic_noise(vseed("mountains", variant) * 19, 6))
    peaks = []
    if objects:
        for px, py in scatter(6007, 8, 16.0, max_border=9.0):
            k = hashf(px, py)
            peaks.append((px + 0.5, py + 0.5, 12.0 + 4.0 * k, 0.24 + 0.12 * k, k * math.tau, True))
        massif = {"v1": [(1, 17.0, 1.0)], "v2": [(2, 12.0, 0.92)], "v3": [(1, 14.0, 0.95), (1, 9.0, 0.75)]}
        placed = []
        for count, radius, amp in massif.get(variant, []):
            seed = vseed("mountains", variant) * 7 + len(placed)
            for cx, cy in scatter(seed, count, 12.0, min_border=radius + 5.0, avoid=placed):
                placed.append((cx, cy))
                peaks.append((cx + 0.5, cy + 0.5, radius, amp, seed * 0.37, False))

    def height(x, y):
        best = 0.0
        for px, py, radius, amp, phase, wrapped in peaks:
            shifts = LATTICE_SHIFTS if wrapped else [(0, 0)]
            vx, vy = min(((x + 0.5 - px - sx, y + 0.5 - py - sy) for sx, sy in shifts),
                         key=lambda v: v[0] * v[0] + v[1] * v[1])
            ang = math.atan2(vy, vx)
            d = math.hypot(vx, vy) * (1 + 0.2 * math.sin(3 * ang + phase) + 0.1 * math.sin(5 * ang + 2 * phase))
            if d < radius:
                best = max(best, amp * (1 - d / radius) ** 1.25)
        ridge = 1 - abs(2 * crag[(x, y)] - 1)
        return 0.10 * noise[(x, y)] + 0.025 * ridge + best * (0.93 + 0.07 * ridge)

    H = {p: height(*p) for p in HEX_PIXELS}
    rock = [C["slate_dk"], C["slate"], C["stone"], C["stone"], C["stone_lt"], C["mist"]]
    for x, y in HEX_PIXELS:
        dx = H[wrap(x + 1, y)] - H[wrap(x - 1, y)]
        dy = H[wrap(x, y + 1)] - H[wrap(x, y - 1)]
        v = 0.5 + 3.2 * light(dx, dy) + 0.12 * (noise[(x, y)] - 0.5)
        if H[(x, y)] + (bayer(x, y) - 0.5) * 0.06 > 0.62:
            t.px[y][x] = C["snow"] if v > 0.45 else C["ice_lt"] if v > 0.22 else C["ice"]
        else:
            t.px[y][x] = ramp_pick(v, rock, x, y)
    for x, y in details("mountains", variant, 14, 4, 7):
        if H[(x, y)] < 0.22:
            if (x + y) % 3:
                pebble(t, x, y, C["stone_lt"], C["stone"], C["slate"], big=(x % 2 == 0))
            else:
                tuft(t, x, y, C["olive"], C["olive"], C["slate"])
    if variant == "accent" and objects:
        cx, cy = accent_center("mountains")
        s = vseed("mountains", variant)
        rocks = [(cx - 3, cy, 6.0, 4.6), (cx + 6, cy + 5, 4.0, 3.2), (cx - 9, cy + 7, 3.0, 2.4), (cx + 2, cy + 10, 2.2, 1.8)]
        for i, (bx, by, rx, ry) in enumerate(sorted(rocks, key=lambda r: r[1])):
            boulder(t, bx + 0.5, by + 0.5, rx, ry, seed=s + i)
    return t


ENVS = {"grass": grass, "dirt": dirt, "desert": desert, "ice": ice, "forest": forest, "mountains": mountains}


def all_environments():
    return [ENVS[e](v) for e in ENV_ORDER for v in VARIANTS]
