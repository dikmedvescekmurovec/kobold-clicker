"""Cover art: the hero facing a horde across a field lit by what the last ones dropped, drawn the way
the battle backdrops are -- ENDESGA 64, pixel by pixel, lit from the upper left, ink round whatever
stands on the near ground -- on a 288x162 grid shown 8x (2304x1296).

The hero and the vanguard are the game's own sprites at one of their pixels a pixel; the horde
behind them is the same sprites cut down to silhouettes, darker and bluer the farther they stand;
the land comes from `sideview`; the beams, the light they throw, the name plate, the cursor and the
logo are drawn here.

`python cover.py [name...]` writes qa/cover_<name>.png for each composition named (all of them
without names).
"""
import random
import re
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import sideview as sv

W, H, SCALE = 288, 162, 8
# sideview draws on its module's grid; point that grid at the cover's.
sv.W, sv.H = W, H
sv.YY, sv.XX = np.mgrid[0:H, 0:W]
sv._BY = np.tile(sv.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
YY, XX, BY = sv.YY, sv.XX, sv._BY
rgb, INK, WHITE = sv.rgb, sv.INK, sv.WHITE
E64 = np.array([rgb(h) for h in sv.E64])

ASSETS = "../Assets/"
PIXELLARI = ImageFont.truetype(ASSETS + "Pixellari.ttf", 16)
ARK = ImageFont.truetype(ASSETS + "ArkPixel10.ttf", 10)

# The rarity ramps a beam is drawn in: core, body, glow.
BEAMS = {
    "common": (WHITE, rgb("c7cfdd"), rgb("92a1b9")),
    "uncommon": (WHITE, rgb("94fdff"), rgb("0cf1ff")),
    "rare": (rgb("fdd2ed"), rgb("f389f5"), rgb("ca52c9")),
    "elite": (rgb("f68187"), rgb("f5555d"), rgb("ea323c")),
    "unique": (WHITE, rgb("ffeb57"), rgb("ffc825")),
}
# One step lighter: what a beam's light does to whatever is behind it or under it.
LIGHTER = {rgb(a): rgb(b) for a, b in (
    ("0c2e44", "134c4c"), ("134c4c", "1e6f50"), ("1e6f50", "33984b"), ("33984b", "5ac54f"),
    ("5ac54f", "99e65f"), ("99e65f", "d3fc7e"), ("391f21", "5d2c28"), ("5d2c28", "8a4836"),
    ("8a4836", "bf6f4a"), ("bf6f4a", "e69c69"), ("e69c69", "f6ca9f"), ("2a2f4e", "424c6e"),
    ("424c6e", "657392"), ("657392", "92a1b9"), ("92a1b9", "c7cfdd"), ("c7cfdd", "ffffff"),
    ("0069aa", "0098dc"), ("0098dc", "00cdf9"), ("00cdf9", "94fdff"), ("94fdff", "ffffff"))}


def lighten(a, m):
    """Every pixel under the mask one step lighter (`LIGHTER`), once."""
    was = a.copy()
    for src, dst in LIGHTER.items():
        a[m & (was == src).all(-1)] = dst


# ---------------------------------------------------------------- sprites

def _roster():
    """Each enemy's sheet folder, frame size, facing and sheets, read off EnemyRoster."""
    text = open("../Scenes/Enemies/enemy_roster.gd", encoding="utf-8").read()
    out = {}
    for m in re.finditer(r'\n\t"([^"]+)": \{(.*?)\n\t\}', text, re.S):
        body = m.group(2)
        d = re.search(r'"dir": "([^"]+)"', body)
        f = re.search(r'"frame": Vector2i\((\d+), (\d+)\)', body)
        s = re.search(r'"sheets": \{([^}]*)\}', body)
        face = re.search(r'"faces": Facing\.(\w+)', body)
        if d and f and s:
            out[m.group(1)] = (d.group(1), (int(f.group(1)), int(f.group(2))),
                               face is not None and face.group(1) == "RIGHT",
                               dict(re.findall(r'"(\w+)": "([^"]+)"', s.group(1))))
    return out


ROSTER = _roster()


def _to_e64(rgba):
    """Every opaque pixel to its nearest ENDESGA 64 colour; alpha to all or nothing."""
    a = np.array(rgba).astype(int)
    solid = a[..., 3] > 127
    cols = a[..., :3][solid]
    d = ((cols[:, None, :] - E64[None, :, :]) ** 2).sum(-1)
    out = np.zeros_like(a)
    out[..., :3][solid] = E64[d.argmin(1)]
    out[..., 3] = solid * 255
    return out.astype(np.uint8)


def enemy(name, anim="idle", i=0):
    """One frame of an enemy, turned to face left, cut to what it draws."""
    d, (fw, fh), right, sheets = ROSTER[name]
    sheet = Image.open(f"{ASSETS}Enemies/{d}/{sheets[anim]}").convert("RGBA")
    f = sheet.crop((i * fw, 0, (i + 1) * fw, fh))
    if right:
        f = f.transpose(Image.FLIP_LEFT_RIGHT)
    return _to_e64(f.crop(f.getbbox()))


def hero(anim="idle", i=0):
    sheet = Image.open(f"{ASSETS}Player/{anim}.png").convert("RGBA")
    f = sheet.crop((i * 148, 0, (i + 1) * 148, 96))
    return _to_e64(f.crop(f.getbbox()))


def paste(a, sprite, cx, foot):
    """A sprite with the middle of its foot on (cx, foot)."""
    h, w = sprite.shape[:2]
    x0, y0 = int(round(cx - w / 2)), int(foot) - h
    for y in range(h):
        for x in range(w):
            if sprite[y, x, 3] and 0 <= y0 + y < H and 0 <= x0 + x < W:
                a[y0 + y, x0 + x] = sprite[y, x, :3]


def silhouette(a, sprite, k, cx, foot, body, rim=None, eyes=None):
    """A sprite cut down `k` times to its shape alone, in `body`, its upper-left edge caught by the
    light in `rim`; `eyes` puts a glint where its brightest warm pixels were."""
    alpha = Image.fromarray(sprite[..., 3])
    w, h = max(1, round(alpha.width / k)), max(1, round(alpha.height / k))
    m = np.array(alpha.resize((w, h), Image.BOX)) > 100
    x0, y0 = int(round(cx - w / 2)), int(foot) - h
    for y in range(h):
        for x in range(w):
            if not m[y, x] or not (0 <= y0 + y < H and 0 <= x0 + x < W):
                continue
            edge = y == 0 or x == 0 or not m[y - 1, x] or not m[y, x - 1]
            a[y0 + y, x0 + x] = rim if (rim is not None and edge) else body
    if eyes is not None:
        c = sprite[..., :3].astype(int)
        warm = (sprite[..., 3] > 0) & (c[..., 0] > 200) & (c[..., 2] < 90) & (c[..., 1] < 200)
        ys, xs = np.nonzero(warm[: sprite.shape[0] // 2])
        if len(xs):
            ex, ey = x0 + int(xs.mean() / k), y0 + int(ys.mean() / k)
            if 0 <= ey < H and 0 <= ex < W:
                a[ey, ex] = eyes


# ---------------------------------------------------------------- light

## Frames in the animated cover's loop, at the fights' own 10 a second (`CombatActor.FPS`).
LOOP = 60


def _fading(t, start, by=None):
    """Solid below `start` of the way up, then dithered away to nothing at the top."""
    return (t < start) | ((BY if by is None else by) < (1 - t) / (1 - start))


def beam(a, x, foot, top, tones, w=1, rng=None, f=None):
    """A pillar of light standing on the ground at (x, foot): a white-hot core and a body in the
    rarity's colour, both solid, thinning out by dither toward the top; round them a halo that lights
    whatever is behind a step (`lighten`), wider toward the foot, its rim dithered; the ground round
    the foot lit, a ring on it; motes rising.

    Given `f`, a frame of the `LOOP`, it is alive: the dither it thins out by climbs a row a frame,
    so the light runs up it; its motes rise, each a whole number of times round a loop; and a wide
    beam (the unique's) sends a ring pulsing out over the ground twice a loop."""
    core, body, glow = tones
    by = None if f is None else np.roll(BY, -(f % 4), axis=0)
    t = np.clip((foot - YY) / max(1, foot - top), 0, 1)
    dx = np.abs(XX - x)
    rows = (YY >= top) & (YY <= foot)
    reach = w + 3 + (1 - t) ** 2 * 5
    halo = rows & (dx <= reach) & ~((dx > reach - 2) & (BY < 0.5)) & _fading(t, 0.7, by)
    lighten(a, halo)
    a[rows & (dx == w + 1) & _fading(t, 0.55, by)] = glow
    a[rows & (dx <= w) & _fading(t, 0.75, by)] = body
    a[rows & (dx <= max(0, w - 1)) & _fading(t, 0.6, by)] = core
    # the ground it lights: an ellipse a step lighter (twice near the middle), a ring on it
    r = w + 14
    pool = ((XX - x) / r) ** 2 + ((YY - foot) / 3.5) ** 2
    near = (YY >= foot - 2) & (YY <= foot + 4)
    lighten(a, near & (pool < 1) & ~((pool > 0.75) & (BY < 0.5)))
    lighten(a, near & (pool < 0.3))
    a[near & (np.abs(pool - 0.5) < 0.09) & (YY >= foot - 1)] = glow
    if f is not None and w >= 2:
        p = (f % (LOOP // 2)) / (LOOP // 2)
        swell = ((XX - x) / (r * (0.5 + 1.1 * p))) ** 2 + ((YY - foot) / (3.5 * (0.5 + 1.1 * p))) ** 2
        a[(YY >= foot - 3) & (YY <= foot + 5) & (np.abs(swell - 1) < 0.12) & (BY > p)] = body
    a[(dx <= w + 1) & (YY >= foot - 1) & (YY <= foot)] = core
    rng = rng or random.Random(x)
    for _ in range(5):
        mx, my = x + rng.choice((-1, 1)) * rng.randint(w + 3, w + 7), rng.randint(max(top, foot - 50), foot - 6)
        c = core if rng.random() < 0.5 else body
        if f is None:
            glint(a, mx, my, c, arm=1)
            continue
        # rising: once, twice or three times up its span in a loop, so the loop is seamless
        span = max(8, foot - 6 - max(top, foot - 50))
        laps = rng.randint(1, 3)
        up = (foot - 6 - my + f * span * laps // LOOP) % span
        glint(a, mx, foot - 6 - up, c, arm=1 if up < span * 0.6 else 0)


def glint(a, x, y, c=WHITE, arm=2):
    """A four-pointed sparkle."""
    for d in range(-arm, arm + 1):
        for (yy, xx) in ((y + d, x), (y, x + d)):
            if 0 <= yy < H and 0 <= xx < W:
                a[yy, xx] = c


def dust(a, seed, x0, x1, foot, height, tones):
    """The cloud a marching army raises: dithered billows over the heads, thinning upward."""
    n = sv.noise2(seed, W, H, 6)
    t = np.clip((foot - YY) / height, 0, 1)
    band = (XX >= x0) & (XX <= x1) & (YY <= foot)
    edge = np.minimum(np.clip((XX - x0) / 20, 0, 1), np.clip((x1 - XX) / 20, 0, 1))
    thick = n * edge * (1 - t)
    a[band & (thick > 0.25) & (BY < thick * 1.6)] = tones[1]
    a[band & (thick > 0.42) & (BY < thick * 1.4)] = tones[0]


def banner(a, x, foot, h, cloth, pole=rgb("391f21")):
    """A war banner: a pole, and a pennant blowing toward the hero."""
    if not 0 <= x < W:
        return
    for y in range(foot - h, foot):
        a[y, x] = pole
    for k in range(6):
        for y in range(foot - h + 1 + k // 2, foot - h + 6 - k // 2):
            if 0 <= x - 1 - k < W:
                a[y, x - 1 - k] = cloth


# ---------------------------------------------------------------- lettering

def text_mask(txt, font):
    img = Image.new("L", (len(txt) * 20 + 20, 40), 0)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    d.text((4, 4), txt, font=font, fill=255)
    m = np.array(img) > 127
    ys, xs = np.nonzero(m)
    return m[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]


def stamp(a, m, x, y, colour):
    ys, xs = np.nonzero(m)
    ok = (y + ys < H) & (x + xs < W)
    a[y + ys[ok], x + xs[ok]] = colour


def outline(m, n=1):
    g = np.pad(m, n)
    for _ in range(n):
        g = sv.grow(g)
    return g


def logo(a, x, y):
    """KOBOLD over CLICKER in Pixellari at twice its size: gold in three bands with a white
    highlight row, a deep extrusion under it, ink round the lot; the subtitle under it in Ark Pixel."""
    lines = [np.kron(text_mask(t, PIXELLARI), np.ones((2, 2), bool)) for t in ("Kobold", "Clicker")]
    top = y
    for m in lines:
        h, w = m.shape
        solid = np.zeros((h + 4, w), bool)
        for k in range(4):
            solid[k: k + h] |= m
        ring = outline(solid)
        stamp(a, ring, x - 1, top - 1, INK)
        stamp(a, solid, x, top, rgb("8e251d"))
        band = np.zeros_like(m, int)
        rows = np.arange(h)[:, None] / h
        band = np.where(rows < 0.34, 0, np.where(rows < 0.66, 1, 2)) + np.zeros_like(m, int)
        for i, c in enumerate((rgb("ffeb57"), rgb("ffc825"), rgb("ed7614"))):
            stamp(a, m & (band == i), x, top, c)
        first = m & ~np.roll(m, 1, axis=0)
        first[0] = m[0]
        stamp(a, first & (band == 0), x, top, WHITE)
        top += h + 6
    sub = text_mask("AN IDLE LOOT RPG", ARK)
    stamp(a, outline(sub), x - 1, top, INK)
    stamp(a, sub, x, top + 1, rgb("f9e6cf"))
    return top + sub.shape[0] + 2


def plate(a, text, cx, bottom):
    """A find's name on an ink plate, gold on dark, edged in the light of the hover. Returns its
    right-hand bottom corner."""
    m = text_mask(text, ARK)
    h, w = m.shape
    x0, y0 = cx - (w + 6) // 2, bottom - (h + 5)
    a[y0: y0 + h + 5, x0: x0 + w + 6] = rgb("f9e6cf")
    a[y0 + 1: y0 + h + 4, x0 + 1: x0 + w + 5] = INK
    stamp(a, m, x0 + 3, y0 + 3, rgb("ffc825"))
    return x0 + w + 6, y0 + h + 5


def cursor(a, tile, hotspot, tip, scale=1):
    sprite = Image.open(f"{ASSETS}Cursor/Tiles/tile_{tile:04d}.png").convert("RGBA")
    sprite = _to_e64(sprite.resize((16 * scale, 16 * scale), Image.NEAREST))
    h, w = sprite.shape[:2]
    x0, y0 = tip[0] - hotspot[0] * scale, tip[1] - hotspot[1] * scale
    for y in range(h):
        for x in range(w):
            if sprite[y, x, 3] and 0 <= y0 + y < H and 0 <= x0 + x < W:
                a[y0 + y, x0 + x] = sprite[y, x, :3]


HAND = (137, (6, 1))


# ---------------------------------------------------------------- land

def meadow(a, seed, top, tones=(rgb("5ac54f"), rgb("33984b"), rgb("1e6f50"), rgb("134c4c"))):
    """Open grass from `top` down, darkening toward the viewer in dithered bands, streaked."""
    m = YY >= top
    t = (YY - top) / max(1, H - top)
    a[m] = tones[0]
    for i, c in enumerate(tones[1:], 1):
        a[m & (t > i / len(tones) - 0.08) & (BY < (t - (i / len(tones) - 0.08)) * 6)] = c
    n = sv.noise2(seed, W, H, 3)
    a[m & (n > 0.72) & ((XX + YY) % 3 == 0)] = tones[0]


def slope(a, seed, x0, y0, x1, y1, tones, bow=0.3):
    """A hillside rising from (x0, y0) to (x1, y1) and running on to the edge: its crest a bowed
    line with a ragged edge, lit along it, grass streaks down its face."""
    xs = np.arange(W, dtype=float)
    u = np.clip((xs - x0) / (x1 - x0), 0, 1)
    crest = y0 + (y1 - y0) * (u - bow * u * (1 - u) * 2)
    crest = np.where(xs < x0, H + 10, crest) + (sv.fbm(seed, W, ((30, 1.0), (70, 0.5))) - 0.5) * 3
    top = np.floor(crest).astype(int)
    m = YY >= top[None, :]
    lt, body, shd, dk = tones
    a[m] = body
    depth = YY - top[None, :]
    a[m & (depth < 3)] = lt
    n = sv.noise2(seed + 1, W, H, 2)
    a[m & (depth > 3) & (n > 0.62) & ((XX + YY // 2) % 4 == 0)] = lt
    a[m & (depth > 22) & (BY < (depth - 22) / 30)] = shd
    a[m & (depth > 46) & (BY < (depth - 46) / 30)] = dk
    return crest


def boulder(a, seed, cx, base, w, h, tones=sv.STONE, turf=True):
    """A great inked rock to stand on, lit from the upper left, cracked, turf along its top.
    Returns its mask."""
    n = sv.noise2(seed, W, H, 5)
    m = ((((XX - cx) / (w / 2)) ** 2 + ((YY - base) / h) ** 2) < 1 + (n - 0.5) * 0.35) & (YY < H)
    sv.inked(a, m)
    hi, body, shd, dk = tones
    s = (XX - cx) / (w / 2) * 0.55 + (YY - (base - h * 0.5)) / h * 0.9
    a[m] = body
    a[m & (s > 0.3)] = shd
    a[m & (s > 0.85)] = dk
    a[m & (s < -0.5)] = hi
    # mottled, as weathered rock is: patches of shade on the lit side, of light on the dark
    n2 = sv.noise2(seed + 9, W, H, 4)
    a[m & (n2 > 0.66) & (s > -0.5) & (s < 0.3)] = shd
    a[m & (n2 < 0.28) & (s > 0.3) & (s < 0.85)] = body
    a[m & (n2 > 0.7) & (s >= 0.3)] = dk
    for k, lean in ((6, 0.4), (-14, -0.3), (22, 0.2)):
        crack = m & (np.abs(XX - cx - k - (YY - base) * lean) < 0.6) & (YY > base - h * 0.75) & \
            (sv.noise2(seed + k + 50, W, H, 3) > 0.35)
        a[crack] = dk
    if turf:
        cap = m & ~np.roll(m, 2, axis=0)
        a[cap] = rgb("33984b")
        a[cap & ~np.roll(m, 1, axis=0)] = rgb("5ac54f")
    return m


def top_of(m, x):
    """The first row of a mask in column x."""
    ys = np.nonzero(m[:, x])[0]
    return int(ys.min()) if len(ys) else H


def grass_front(a, seed, count, y_bottom=None, tones=(rgb("1e6f50"), rgb("134c4c"))):
    """Tall blades along the bottom edge, nearer than anything, dark against the field."""
    rng = random.Random(seed)
    y_bottom = y_bottom or H
    for _ in range(count):
        x = rng.randrange(W)
        hh = rng.randint(6, 16)
        lean = rng.choice((-1, 1)) * rng.uniform(0.1, 0.5)
        for k in range(hh):
            xx = int(x + lean * k * k / hh)
            for dx in (0, 1) if k < hh * 0.5 else (0,):
                if 0 <= xx + dx < W:
                    a[y_bottom - 1 - k, xx + dx] = tones[1] if k < hh * 0.4 else tones[0]


def daylight(a, rng, seed):
    """High noon's blues down to a pale horizon, heaped white cloud, a snowy blue range."""
    sv.sky(a, ((rgb("0069aa"), 0), (rgb("0098dc"), 26), (rgb("00cdf9"), 64), (rgb("94fdff"), 96)))
    sv.cloud(a, rng, 222, 76, 100, 22, lit=WHITE, body=rgb("c7cfdd"), bump=(3, 6))
    sv.cloud(a, rng, 150, 84, 60, 14, lit=WHITE, body=rgb("c7cfdd"), bump=(3, 5))
    sv.cloud(a, rng, 262, 38, 34, 7, lit=WHITE, body=rgb("c7cfdd"), bump=(2, 4))
    sv.ranges(a, seed + 1, 108, 40, 5, rgb("657392"), rgb("92a1b9"), snow=(WHITE, rgb("c7cfdd")),
              snowline=84)


def check(a, name):
    stray = {tuple(c) for c in np.unique(a.reshape(-1, 3), axis=0)} - sv.PALETTE
    assert not stray, f"{name}: colours outside ENDESGA 64: {sorted(stray)[:5]}"


# ---------------------------------------------------------------- the covers

def ridge(seed=11):
    """The hero on a rock at the left; the horde coming down a long ridge from the right, shrinking
    into the distance up it, banners over them; the meadow between lit by beams, the unique's the
    tallest, its name under the cursor."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    daylight(a, rng, seed)
    sv.hills(a, seed + 2, 116, 8, rgb("1e6f50"), rgb("33984b"))
    meadow(a, seed + 3, 116)
    crest = slope(a, seed + 4, 150, 138, 300, 62,
                  (rgb("5ac54f"), rgb("33984b"), rgb("1e6f50"), rgb("134c4c")), bow=0.35)

    # The column down the crest, far to near, growing as it comes; banners among them.
    marchers = ["Stone Golem", "Minotaur", "Skeleton Warrior", "Masked Orc", "Cyclops", "Imp",
                "Werewolf", "Goblin"]
    for i in range(11):
        u = 0.98 - i * 0.07
        x = int(150 + (300 - 150) * u)
        foot = int(crest[min(W - 1, max(0, x))]) + 2
        k = 4.0 - i * 0.2
        tones = (rgb("424c6e"), rgb("657392")) if i < 5 else (rgb("2a2f4e"), rgb("424c6e"))
        silhouette(a, enemy(marchers[i % len(marchers)], "walk", i % 4), k, x, foot, tones[0],
                   tones[1], eyes=rgb("ffc825") if i >= 4 else None)
        if i % 4 == 1:
            banner(a, x + 4, foot - 3, int(12 + i), rgb("c42430"))
    # the vanguard, near enough to be seen whole: one on the hillside, one in the meadow
    paste(a, enemy("Masked Orc", "walk", 2), 238, 128)
    paste(a, enemy("Goblin", "walk", 0), 200, 152)

    beam(a, 96, 122, 58, BEAMS["uncommon"], rng=rng)
    beam(a, 118, 130, 34, BEAMS["rare"], rng=rng)
    beam(a, 138, 139, 44, BEAMS["elite"], rng=rng)
    beam(a, 160, 150, 0, BEAMS["unique"], w=2, rng=rng)

    rock = boulder(a, seed + 5, 40, 186, 110, 40)
    paste(a, hero("idle", 0), 56, top_of(rock, 56) + 2)
    grass_front(a, seed + 6, 60)
    right, bottom = plate(a, "Stonebreaker", 160, 120)
    cursor(a, *HAND, (right - 5, bottom - 2))
    logo(a, 8, 6)
    check(a, "ridge")
    return a


def wall(seed=23):
    """The horde as a wall along the horizon under its own dust, banners up; the hero near and
    large on the left; between them the open field, beams standing in it at every depth."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    daylight(a, rng, seed)
    sv.hills(a, seed + 2, 112, 6, rgb("1e6f50"), rgb("33984b"))
    dust(a, seed + 3, 130, 300, 112, 34, (rgb("c7cfdd"), rgb("92a1b9")))
    marchers = ["Stone Golem", "Minotaur", "Cyclops", "Skeleton Warrior", "Masked Orc", "Goblin",
                "Werewolf", "Imp"]
    for row, (k, foot, tones, gap) in enumerate((
            (3.6, 110, (rgb("424c6e"), rgb("657392")), (13, 19)),
            (2.4, 116, (rgb("2a2f4e"), rgb("424c6e")), (20, 28)))):
        x = 136 + row * 12
        i = row * 3
        while x < W + 10:
            silhouette(a, enemy(marchers[i % len(marchers)], "walk", i % 4), k, x, foot, tones[0],
                       tones[1], eyes=rgb("ffc825") if row else None)
            if i % 3 == 1:
                banner(a, x + 3, foot - 6, 26 - row * 4, rgb("c42430") if row else rgb("891e2b"))
            x += rng.randint(*gap)
            i += 1
    meadow(a, seed + 4, 116)
    beam(a, 126, 130, 30, BEAMS["elite"], rng=rng)
    beam(a, 196, 124, 22, BEAMS["rare"], rng=rng)
    beam(a, 226, 120, 46, BEAMS["uncommon"], rng=rng)
    beam(a, 162, 146, 0, BEAMS["unique"], w=2, rng=rng)
    paste(a, enemy("Goblin", "walk", 1), 250, 150)
    paste(a, hero("idle", 0), 62, 156)
    grass_front(a, seed + 6, 70)
    right, bottom = plate(a, "Stonebreaker", 162, 116)
    cursor(a, *HAND, (right - 5, bottom - 2))
    logo(a, 8, 6)
    check(a, "wall")
    return a


def valley(seed=37):
    """From a cliff above a green valley: the horde winding up the road out of the hills, the valley
    floor dotted with beams where the last of them fell, the hero on the brink at the left."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    sv.sky(a, ((rgb("0069aa"), 0), (rgb("0098dc"), 16), (rgb("00cdf9"), 36), (rgb("94fdff"), 52)))
    sv.cloud(a, rng, 230, 50, 110, 22, lit=WHITE, body=rgb("c7cfdd"), bump=(4, 7))
    sv.ranges(a, seed + 1, 64, 30, 6, rgb("657392"), rgb("92a1b9"), snow=(WHITE, rgb("c7cfdd")),
              snowline=48)
    sv.hills(a, seed + 2, 72, 8, rgb("1e6f50"), rgb("33984b"))
    meadow(a, seed + 3, 72, (rgb("99e65f"), rgb("5ac54f"), rgb("33984b"), rgb("1e6f50")))
    # the road, winding down from the far hills toward the viewer, widening as it comes
    road = np.zeros((H, W), bool)
    edge = np.zeros((H, W), bool)
    for y in range(72, H):
        t = (y - 72) / (H - 72)
        cx = 250 - 60 * t + 38 * np.sin(t * 5.2)
        half = 1.5 + t * 12
        road[y, max(0, int(cx - half)): min(W, int(cx + half) + 1)] = True
    edge = sv.grow(road) & ~road
    a[edge] = rgb("8a4836")
    a[road] = rgb("e69c69")
    a[road & (BY < 0.25)] = rgb("bf6f4a")

    # the column along the road, far to near, the upright ones that read small; its head whole
    marchers = ["Goblin", "Masked Orc", "Skeleton Warrior", "Imp", "Minotaur"]
    for i in range(12):
        t = 0.03 + i * 0.04
        y = int(72 + t * (H - 72))
        cx = 250 - 60 * t + 38 * np.sin(t * 5.2)
        k = 9.0 - t * 10
        tones = (rgb("424c6e"), rgb("657392")) if t < 0.25 else (rgb("2a2f4e"), rgb("424c6e"))
        silhouette(a, enemy(marchers[i % len(marchers)], "walk", i % 4), k, cx, y,
                   tones[0], tones[1], eyes=rgb("ffc825") if t > 0.25 else None)
        if i % 4 == 2:
            banner(a, int(cx) + 3, y - 3, int(8 + t * 16), rgb("c42430"))
    beam(a, 96, 90, 22, BEAMS["uncommon"], rng=rng)
    beam(a, 168, 100, 16, BEAMS["rare"], rng=rng)
    beam(a, 150, 116, 30, BEAMS["elite"], rng=rng)
    beam(a, 128, 132, 0, BEAMS["unique"], w=2, rng=rng)
    for t, who in ((0.5, "Masked Orc"), (0.86, "Goblin")):
        y = int(72 + t * (H - 72))
        paste(a, enemy(who, "walk", 1), 250 - 60 * t + 38 * np.sin(t * 5.2) + 6, y)

    # the crag the hero stands on, bottom left, over the drop into the valley
    crag = boulder(a, seed + 5, 30, 214, 150, 92)
    paste(a, hero("idle", 0), 58, top_of(crag, 58) + 2)
    grass_front(a, seed + 6, 40)
    right, bottom = plate(a, "Stonebreaker", 128, 102)
    cursor(a, *HAND, (right - 5, bottom - 2))
    logo(a, 150, 6)
    check(a, "valley")
    return a


# ---------------------------------------------------------------- the plaque covers
# After the Clicker Heroes key art the user pointed at (2026-09-30): a framed plaque for a logo with a
# sword crossed behind it and the cursor at its side, a bright sky with shafts of light, a round
# green hill, and the characters big and close. These are drawn on a smaller grid than the vistas
# above so that the same sprites, still one pixel a pixel, fill the frame.

def shrink(m, n=1):
    for _ in range(n):
        m = m & np.roll(m, 1, 0) & np.roll(m, -1, 0) & np.roll(m, 1, 1) & np.roll(m, -1, 1)
    return m


def spaced_mask(txt, font, gap):
    """A line of text with `gap` extra pixels between its letters."""
    parts = [text_mask(c, font) if c != " " else np.zeros((1, 4), bool) for c in txt]
    h = max(p.shape[0] for p in parts)
    out = np.zeros((h, sum(p.shape[1] for p in parts) + gap * (len(parts) - 1)), bool)
    x = 0
    for p in parts:
        out[h - p.shape[0]:, x: x + p.shape[1]] = p
        x += p.shape[1] + gap
    return out


GOLD_BANDS = (rgb("ffeb57"), rgb("ffc825"), rgb("ed7614"))


def lettering(a, m, x, y, deep=3, thick=1, bands=GOLD_BANDS, extrude=rgb("8e251d"), shine=WHITE,
              ink=True):
    """Lettering the way the logo wears it: a `shine` top row, three `bands` down it, an `extrude`
    depth `deep` pixels down, ink `thick` pixels round the lot -- thick enough and the letters
    fuse into one shape, which is what lets a word sit over a frame without the frame showing
    between its letters."""
    h, w = m.shape
    solid = np.zeros((h + deep, w), bool)
    for k in range(deep + 1):
        solid[k: k + h] |= m
    if ink:
        stamp(a, outline(solid, thick), x - thick, y - thick, INK)
    stamp(a, solid, x, y, extrude)
    rows = np.arange(h)[:, None] / h + np.zeros_like(m, float)
    for (lo, hi), c in zip(((0, 0.34), (0.34, 0.66), (0.66, 1.01)), bands):
        stamp(a, m & (rows >= lo) & (rows < hi), x, y, c)
    first = m & ~np.roll(m, 1, axis=0)
    first[0] = m[0]
    stamp(a, first & (rows < 0.34), x, y, shine)


def plaque(a, cx, y0, w=138, h=44):
    """The logo's frame: a panel with its corners bitten in, a bevelled gold rim lit from the upper
    left, a deep green face with a sheen across it; KOBOLD spaced out small along the top and
    CLICKER big below, breaking through the bottom of the rim; a sword crossed behind the upper left
    and the cursor at the right. Returns the rectangle it covers."""
    x0, x1, y1 = cx - w // 2, cx + w // 2, y0 + h
    # the sword behind it, mirrored to lean out to the upper left, at twice its size: its hilt
    # behind the corner, its point well out past it
    sword = Image.open(ASSETS + "Gear/Golden Sword.png").convert("RGBA").transpose(Image.FLIP_LEFT_RIGHT)
    sword = _to_e64(sword.resize((64, 64), Image.NEAREST))
    paste(a, sword, x0 + 4, y0 + 42)
    box = (XX >= x0) & (XX < x1) & (YY >= y0) & (YY < y1)
    for px, py in ((x0, y0), (x1 - 1, y0), (x0, y1 - 1), (x1 - 1, y1 - 1)):
        box &= ((XX - px) ** 2 + (YY - py) ** 2) >= 7 * 7
    sv.inked(a, box)
    rims = [box]
    for _ in range(4):
        rims.append(shrink(rims[-1]))
    lit = (rgb("edab50"), rgb("ffeb57"), rgb("ffc825"), INK)
    shade = (rgb("ed7614"), rgb("ffc825"), rgb("edab50"), INK)
    far = (YY > y1 - 6) | (XX > x1 - 6)
    for k in range(4):
        band = rims[k] & ~rims[k + 1]
        a[band] = lit[k]
        a[band & far & (k < 3)] = shade[k]
    face = rims[4]
    a[face] = rgb("134c4c")
    a[face & (YY < y0 + h * 0.5) & (BY < 1.4 - (YY - y0) / (h * 0.5))] = rgb("1e6f50")
    sheen = face & (np.abs((XX - x0) - (YY - y0) * 0.6 - 26) < 5)
    a[sheen & (BY < 0.5)] = rgb("33984b")
    top = spaced_mask("KOBOLD", PIXELLARI, 3)
    lettering(a, top, cx - top.shape[1] // 2, y0 + 7, deep=1)
    big = np.kron(text_mask("CLICKER", PIXELLARI), np.ones((2, 2), bool))
    lettering(a, big, cx - big.shape[1] // 2, y0 + 23, thick=3)
    cursor(a, 26, (1, 1), (x1 - 3, y0 + 18), scale=2)
    return x0, y0, x1, y1 + 6


def bright_sky(a, rng, seed, horizon=110):
    """Clicker-bright: cyan fading to pale toward the hill, shafts of light slanting down from the
    top, white cloud banked low behind the hill."""
    sv.sky(a, ((rgb("0098dc"), 0), (rgb("00cdf9"), 34), (rgb("0cf1ff"), 70), (rgb("94fdff"), 98)))
    for x, wide in ((22, 10), (70, 6), (118, 14), (176, 8), (228, 12)):
        shaft = (np.abs(XX - (x + YY * 0.18)) < wide / 2) & (YY < horizon) & (BY < 1.1 - YY / horizon)
        lighten(a, shaft & ~((np.abs(XX - (x + YY * 0.18)) > wide / 2 - 1.5) & (BY < 0.5)))
    for cx in (20, 90, 170, 240):
        sv.cloud(a, rng, cx + rng.randint(-10, 10), horizon + 4, rng.randint(70, 110), rng.randint(20, 30),
                 lit=WHITE, body=rgb("94fdff"), bump=(4, 7))


def round_hill(a, rng, top=96, radius=360):
    """A round hill of bright grass filling the bottom: its rim bristling with blades against the
    sky, lit along the top, deepening in dithered bands toward the viewer, blade strokes on its face."""
    xs = np.arange(W)
    rim = top + (xs - W / 2) ** 2 / (2 * radius)
    depth = YY - rim[None, :]
    m = depth >= 0
    a[m] = rgb("99e65f")
    a[m & (depth < 2)] = rgb("d3fc7e")
    a[m & (depth > 12) & (BY < (depth - 12) / 16)] = rgb("5ac54f")
    a[m & (depth > 34) & (BY < (depth - 34) / 16)] = rgb("33984b")
    for _ in range(140):
        x = rng.randrange(W)
        y = int(rim[x]) + int(rng.random() ** 1.6 * (H - rim[x]))
        k = rng.randint(2, 4)
        tone = rgb("d3fc7e") if y - rim[x] < 16 else rgb("99e65f")
        for i in range(k):
            yy, xx = y - i, x + (i if rng.random() < 0.5 else -i) // 2
            if 0 <= yy < H and 0 <= xx < W and yy > rim[xx]:
                a[yy, xx] = tone
    for x in range(0, W, 3):
        k = rng.randint(1, 3)
        for i in range(1, k + 1):
            y = int(rim[x]) - i
            if 0 <= y < H:
                a[y, min(W - 1, x + (1 if i == k and rng.random() < 0.5 else 0))] = rgb("99e65f")


def daisy(a, x, y):
    for dx, dy in ((0, -1), (-1, 0), (1, 0), (0, 1)):
        if 0 <= y + dy < H and 0 <= x + dx < W:
            a[y + dy, x + dx] = WHITE
    if 0 <= y < H and 0 <= x < W:
        a[y, x] = rgb("ffc825")


def coin(a, cx, cy, frame=0):
    sheet = Image.open(ASSETS + "coin4_16x16.png").convert("RGBA").crop((frame * 16, 0, frame * 16 + 16, 16))
    paste(a, _to_e64(sheet.crop(sheet.getbbox())), cx, cy + 6)


def flipped(sprite):
    return sprite[:, ::-1]


def standoff(seed=51):
    """The hero leaping in with his blade at a Mimic on the hilltop spilling its coin, a minotaur
    raising his axe behind it, the plaque over them all."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    bright_sky(a, rng, seed)
    round_hill(a, rng, top=98, radius=340)
    for x, y in ((24, 132), (34, 138), (206, 128), (216, 136), (238, 131), (14, 126)):
        daisy(a, x, y)
    paste(a, enemy("Minotaur", "attack", 2), 226, 142)
    paste(a, enemy("Mimic", "idle", 0), 134, 143)
    # coin spat up out of the chest
    for i, (dx, dy) in enumerate(((24, -70), (38, -58), (18, -54))):
        coin(a, 134 + dx, 143 + dy, (0, 1, 8)[i])
    for x, y, c in ((176, 74, WHITE), (150, 70, rgb("ffeb57")), (168, 94, rgb("ffeb57"))):
        glint(a, x, y, c)
    paste(a, hero("attack", 2), 62, 122)
    grass_front(a, seed + 6, 40, tones=(rgb("5ac54f"), rgb("33984b")))
    plaque(a, 128, 16)
    check(a, "standoff")
    return a


def crowd(seed=63):
    """The plaque in the middle of the whole horde crammed round it -- peering over its top, flying
    at its corners, shouldering in at the sides -- the hero at the front with his blade out, coin
    and a chest spilled at their feet."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    bright_sky(a, rng, seed, horizon=96)
    round_hill(a, rng, top=84, radius=420)
    # behind the plaque, over its top
    paste(a, flipped(enemy("Masked Orc", "attack", 0)), 72, 100)
    paste(a, enemy("Stone Golem", "idle", 0), 188, 102)
    paste(a, flipped(enemy("Flying Eye", "idle", 0)), 38, 70)
    paste(a, enemy("Baby Dragon", "idle", 1), 230, 70)
    paste(a, flipped(enemy("Minotaur", "attack", 2)), 16, 136)
    paste(a, enemy("Werewolf", "attack", 1), 246, 140)
    plaque(a, 128, 42)
    # in front of it
    paste(a, enemy("Mimic", "idle", 0), 194, 150)
    paste(a, enemy("Goblin", "attack", 1), 150, 150)
    paste(a, enemy("Imp", "idle", 0), 226, 146)
    chest = _to_e64(Image.open(ASSETS + "Chests/Chests.png").convert("RGBA").crop((0, 128, 48, 160)))
    chest = chest[np.ix_(np.nonzero(chest[..., 3].any(1))[0], np.nonzero(chest[..., 3].any(0))[0])]
    paste(a, chest, 112, 140)
    for i, (x, y) in enumerate(((94, 138), (130, 140), (120, 128))):
        coin(a, x, y, (0, 1, 8)[i])
    paste(a, hero("idle", 0), 64, 150)
    grass_front(a, seed + 6, 50, tones=(rgb("5ac54f"), rgb("33984b")))
    check(a, "crowd")
    return a


# ---------------------------------------------------------------- the hero at twice his size

def _nb(m, dy, dx):
    """m shifted so that out[y, x] = m[y + dy, x + dx], False past the edge."""
    p = np.pad(m, 1)
    return p[1 + dy: 1 + dy + m.shape[0], 1 + dx: 1 + dx + m.shape[1]]


def scale2x(s):
    """Scale2x (AdvMAME2x): twice the size with the stair-steps of its diagonals rounded off and no
    colour it did not have -- a sprite drawn at twice its size, not a sprite blown up."""
    P = np.pad(s, ((1, 1), (1, 1), (0, 0)), mode="edge")
    B, D, E, F, Hh = P[:-2, 1:-1], P[1:-1, :-2], P[1:-1, 1:-1], P[1:-1, 2:], P[2:, 1:-1]

    def eq(p, q):
        return (p == q).all(-1)

    c = ~eq(B, Hh) & ~eq(D, F)
    out = np.zeros((s.shape[0] * 2, s.shape[1] * 2, 4), s.dtype)
    out[0::2, 0::2] = np.where((c & eq(D, B))[..., None], D, E)
    out[0::2, 1::2] = np.where((c & eq(B, F))[..., None], F, E)
    out[1::2, 0::2] = np.where((c & eq(D, Hh))[..., None], D, E)
    out[1::2, 1::2] = np.where((c & eq(Hh, F))[..., None], F, E)
    return out


def thin_outline(s):
    """Scale2x doubles the ink round a sprite; take its outer pixel off wherever the ink behind it
    goes on, so the outline is one pixel again, as the packs draw it."""
    s = s.copy()
    m = s[..., 3] > 0
    ink = m & (s[..., :3] == INK).all(-1)
    drop = np.zeros_like(m)
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        drop |= ink & ~_nb(m, dy, dx) & _nb(ink, -dy, -dx)
    s[drop] = 0
    return s


def big(sprite):
    return thin_outline(scale2x(sprite))


def head():
    """The kobold's head off his dialogue portrait (its first frame), down to the scarf."""
    p = Image.open(ASSETS + "NPC/player.png").convert("RGBA").crop((0, 0, 52, 34))
    return _to_e64(p.crop(p.getbbox()))


def open_chest():
    """The red-and-gold chest of `Chests.png` with its lid thrown back, at twice its size."""
    c = Image.open(ASSETS + "Chests/Chests.png").convert("RGBA").crop((48, 160, 96, 192))
    return big(_to_e64(c.crop(c.getbbox())))


# ---------------------------------------------------------------- six logos
# Asked for 2026-09-30 after the plaque read too much like Clicker Heroes: each is built on
# something of the game's own -- the loot beam, the kobold, the rarities, the tavern, the chest --
# rather than a framed panel with a sword and an arrow.

CREAM_BANDS = (WHITE, rgb("f9e6cf"), rgb("f6ca9f"))
BLUE_BANDS = (rgb("0cf1ff"), rgb("0098dc"), rgb("0069aa"))
RARITY_BANDS = {
    "common": (WHITE, rgb("c7cfdd"), rgb("92a1b9")),
    "uncommon": (rgb("94fdff"), rgb("0cf1ff"), rgb("0098dc")),
    "rare": (rgb("f389f5"), rgb("ca52c9"), rgb("93388f")),
    "elite": (rgb("f68187"), rgb("ea323c"), rgb("891e2b")),
    "unique": GOLD_BANDS,
}
CLAW = [
    ".kkkkk.",
    "kllllbk",
    "kbbbbbk",
    "kbkbkbk",
    ".k.k.k.",
]


def word2x(txt):
    return np.kron(text_mask(txt, PIXELLARI), np.ones((2, 2), bool))


def pattern(a, rows, x, y, inks, k=1):
    """A letter picture, each letter a colour in `inks`, `k` pixels a letter."""
    for dy, row in enumerate(rows):
        for dx, ch in enumerate(row):
            if ch not in inks:
                continue
            for sy in range(k):
                for sx in range(k):
                    py, px = y + dy * k + sy, x + dx * k + sx
                    if 0 <= py < H and 0 <= px < W:
                        a[py, px] = inks[ch]


def stacked(a, cx, y, top_bands, top_extrude, clicker=True):
    """KOBOLD over CLICKER, both twice their size, centred on cx from row y. Returns where each
    word starts and the row under them."""
    k, c = word2x("KOBOLD"), word2x("CLICKER")
    kx = cx - k.shape[1] // 2
    lettering(a, k, kx, y, deep=2, thick=2, bands=top_bands, extrude=top_extrude)
    y2 = y + k.shape[0] + 6
    if clicker:
        lettering(a, c, cx - c.shape[1] // 2, y2, thick=2)
    return kx, y2, y2 + c.shape[0] + 5


def logo_beam(a, cx, y, with_beam=True):
    """The name standing in a unique's beam: KOBOLD in cream over a blue depth, CLICKER in gold,
    the pillar of light behind them both, its ring under them, sparks and coin round it."""
    if with_beam:
        beam(a, cx, y + 64, 0, BEAMS["unique"], w=3)
    stacked(a, cx, y, CREAM_BANDS, rgb("0069aa"))
    for dx, dy, c in ((-70, 6, WHITE), (68, 12, rgb("ffeb57")), (-64, 40, rgb("ffeb57")), (74, 46, WHITE)):
        glint(a, cx + dx, y + dy, c)


def logo_mascot(a, cx, y):
    """KOBOLD in the kobold's own blues with the kobold himself peering over the end of it;
    CLICKER in gold under him. (Claws hooked over the letters were tried and read as umlauts.)"""
    k = word2x("KOBOLD")
    kx = cx - k.shape[1] // 2
    # his head at twice its size, cut off where the letters start so none of him shows through
    # their counters
    paste(a, big(head())[:-16], kx + k.shape[1] - 44, y + 6)
    stacked(a, cx, y, BLUE_BANDS, rgb("03193f"))


def logo_rarity(a, cx, y):
    """CLICKER climbing the rarities letter by letter, common to unique, under a plain KOBOLD, and
    the hand clicking the unique R."""
    k = word2x("KOBOLD")
    lettering(a, k, cx - k.shape[1] // 2, y, deep=2, thick=2, bands=CREAM_BANDS, extrude=rgb("424c6e"))
    y2 = y + k.shape[0] + 6
    letters = [word2x(ch) for ch in "CLICKER"]
    gap = 4
    h = max(m.shape[0] for m in letters)
    whole = np.zeros((h, sum(m.shape[1] for m in letters) + gap * 6), bool)
    xs, x = [], 0
    for m in letters:
        whole[h - m.shape[0]:, x: x + m.shape[1]] |= m
        xs.append(x)
        x += m.shape[1] + gap
    x0 = cx - whole.shape[1] // 2
    lettering(a, whole, x0, y2, thick=2, extrude=rgb("1a1932"))
    for m, off, r in zip(letters, xs, ("common", "uncommon", "uncommon", "rare", "rare", "elite", "unique")):
        bands = RARITY_BANDS[r]
        lettering(a, m, x0 + off, y2 + h - m.shape[0], extrude=rgb("1a1932"), bands=bands,
                  shine=WHITE, ink=False)
    # the hand's fingertip on the R's foot, the click going off round it
    tx, ty = x0 + xs[-1] + letters[-1].shape[1] - 4, y2 + h - 1
    for (dx, dy), (ex, ey) in (((3, -1), (8, -3)), ((3, 3), (8, 6)), ((0, 4), (0, 9))):
        for t in range(4):
            px, py = tx + 8 + dx + (ex - dx) * t // 3, ty + dy + (ey - dy) * t // 3
            if 0 <= py < H and 0 <= px < W:
                a[py, px] = WHITE
    cursor(a, 137, (6, 1), (tx, ty), scale=2)


## The sign's wood tipped toward the light (the bottom swung toward the viewer turns it up to the
## sky) and away from it (the bottom swung away turns it down), a step each way. The wood only: the
## name stays as it is, or it washes out and the swing reads as a flicker.
TIP_UP = {rgb(a): rgb(b) for a, b in (
    ("391f21", "5d2c28"), ("5d2c28", "8a4836"), ("8a4836", "bf6f4a"), ("bf6f4a", "e69c69"))}
TIP_DOWN = {rgb(a): rgb(b) for a, b in (
    ("5d2c28", "391f21"), ("8a4836", "5d2c28"), ("bf6f4a", "8a4836"), ("e69c69", "bf6f4a"))}
_BLANK = (1, 2, 3)


def sign_board(a, cx, y):
    """The sign's board and all on it -- planks, nails, the rope rings and the name. Returns the
    row CLICKER starts on."""
    w, h = 150, 62
    x0 = cx - w // 2
    board = (XX >= x0) & (XX < x0 + w) & (YY >= y) & (YY < y + h)
    board &= ~(((XX - x0) + (YY - y) < 3) | ((x0 + w - 1 - XX) + (YY - y) < 3) |
               ((XX - x0) + (y + h - 1 - YY) < 3) | ((x0 + w - 1 - XX) + (y + h - 1 - YY) < 3))
    sv.inked(a, board)
    a[board] = rgb("bf6f4a")
    plank = (YY - y) % (h // 3)
    a[board & (plank == 0)] = rgb("5d2c28")
    a[board & (plank == 1)] = rgb("e69c69")
    a[board & (plank >= h // 3 - 2)] = rgb("8a4836")
    grain = sv.noise2(7, W, H, 3)
    a[board & (plank > 2) & (plank < h // 3 - 2) & (grain > 0.68) & (XX % 5 != 0)] = rgb("8a4836")
    for k in range(3):
        for nx in (x0 + 5, x0 + w - 6):
            ny = y + k * (h // 3) + h // 6
            a[ny, nx] = rgb("c7cfdd")
            a[ny + 1, nx] = rgb("5d5d5d")
    for rx in (x0 + 24, x0 + w - 26):
        pattern(a, [".kk.", "k..k", "k..k", ".kk."], rx - 1, y - 2, {"k": rgb("657392")})
    _, y2, _ = stacked(a, cx, y + 6, CREAM_BANDS, rgb("391f21"))
    return y2


def tipped(a, cx, y, tilt):
    """The board swung `tilt` rows out of true on its ropes, toward the viewer (the bottom coming
    forward, > 0) or away (< 0): drawn apart, then squashed that many rows by dropping rows evenly
    (a face seen at a slant is shorter), lifted half as much (the ropes lean, so it rides up), its
    wood a step lighter or darker as it tips toward or away from the light (`TIP_UP`, `TIP_DOWN`), the
    board's own thickness showing along the edge that comes toward the eye. Returns the row CLICKER
    stands on at rest."""
    layer = np.empty_like(a)
    layer[:] = _BLANK
    y2 = sign_board(layer, cx, y)
    drawn = (layer != _BLANK).any(-1)
    rows = np.nonzero(drawn.any(1))[0]
    r0, tall = rows[0], rows[-1] - rows[0] + 1
    short, lift = tall - abs(tilt), abs(tilt) // 2
    place = np.zeros_like(drawn)
    for d in range(short):
        src = r0 + min(tall - 1, int((d + 0.5) * tall / short))
        dst = r0 - lift + d
        m = drawn[src]
        a[dst][m] = layer[src][m]
        place[dst] = m
    # a whole step when it is well over, half of one (dithered) on the way
    shade = TIP_UP if tilt > 0 else TIP_DOWN
    strength = 1.0 if abs(tilt) >= 3 else (0.5 if abs(tilt) == 2 else 0.0)
    was = a.copy()
    for src, dst in shade.items():
        a[place & (BY < strength) & (was == src).all(-1)] = dst
    if abs(tilt) >= 2:
        w = 150
        x0 = cx - w // 2
        cols = [x for x in range(x0 + 3, x0 + w - 3)
                if not any(rx - 2 <= x <= rx + 3 for rx in (x0 + 24, x0 + w - 26))]
        for x in cols:
            ys = np.nonzero(place[:, x])[0]
            if not len(ys):
                continue
            if tilt > 0:
                # the underside, come forward into view
                a[ys[-1] + 1, x] = rgb("391f21")
                a[ys[-1] + 2, x] = INK
            else:
                # the top edge, tipped toward the eye
                a[ys[0] - 1, x] = rgb("e69c69")
                a[ys[0] - 2, x] = INK
    return y2


def logo_sign(a, cx, y, pointer=True, press=False, tilt=0):
    """A tavern sign: three planks on two ropes, the name carved and gilded on it, and the mouse
    pointer hovering on CLICKER, its tip on the R's foot so it hides none of the word; `press` is it
    clicking -- pushed in a pixel, the click going off round its tip. `tilt` is the board swung on
    its ropes toward the viewer or away (`tipped`); the pointer stays where it was."""
    w = 150
    x0 = cx - w // 2
    lift = abs(tilt) // 2
    for rx in (x0 + 24, x0 + w - 26):
        for yy in range(0, y + 3 - lift):
            a[yy, rx] = rgb("e69c69") if yy % 3 else rgb("8a4836")
            a[yy, rx + 1] = rgb("bf6f4a") if yy % 3 else rgb("5d2c28")
    # the row CLICKER stands on at rest: the pointer stays there whichever way the board swings
    y2 = tipped(a, cx, y, tilt) if tilt else sign_board(a, cx, y)
    if pointer:
        c = word2x("CLICKER")
        tip = (cx + c.shape[1] // 2 - 4 + press, y2 + c.shape[0] - 11 + press)
        if press:
            for (dx, dy), (ex, ey) in (((-3, -2), (-7, -5)), ((0, -4), (0, -8)), ((-4, 1), (-8, 2))):
                for k in range(4):
                    px, py = tip[0] + dx + (ex - dx) * k // 3, tip[1] + dy + (ey - dy) * k // 3
                    if 0 <= py < H and 0 <= px < W:
                        a[py, px] = WHITE
        cursor(a, 26, (1, 1), tip, scale=2)


def logo_chest(a, cx, y):
    """The name bursting up out of an open treasure chest in a fan of its light, coin and gems
    thrown up round the letters."""
    chest = open_chest()
    base = y + 118
    mouth = base - chest.shape[0] + 14
    fan = (YY < mouth) & (np.abs(XX - cx) < 14 + (mouth - YY) * 0.55) & (BY < 0.25 + (YY / mouth) * 0.9)
    lighten(a, fan)
    lighten(a, fan & (np.abs(XX - cx) < 6 + (mouth - YY) * 0.25))
    stacked(a, cx, y, CREAM_BANDS, rgb("8a4836"))
    paste(a, chest, cx, base)
    for (dx, dy), f in zip(((-60, 70), (58, 64), (-46, 90), (48, 88), (-72, 40)), (0, 1, 8, 2, 7)):
        coin(a, cx + dx, y + dy, f)
    for dx, dy, c in ((-34, 72, rgb("f389f5")), (30, 76, rgb("0cf1ff")), (-80, 60, rgb("ea323c")),
                      (78, 44, rgb("5ac54f"))):
        pattern(a, [".k.", "kck", ".k."], cx + dx, y + dy, {"k": INK, "c": c})
        glint(a, cx + dx + 1, y + dy - 3, WHITE, arm=1)


def logo_crest(a, cx, y):
    """A shield in the kobold's blue with his head on it, a gold rim, and a red ribbon across it
    carrying the name."""
    sw, sh = 68, 76
    rel = YY - y
    half = np.where(rel < 40, sw / 2, sw / 2 * np.sqrt(np.clip(1 - ((rel - 40) / (sh - 40)) ** 2, 0, 1)))
    shield = (np.abs(XX - cx) <= half) & (rel >= 0) & (rel < sh)
    sv.inked(a, shield)
    rims = [shield]
    for _ in range(4):
        rims.append(shrink(rims[-1]))
    lit, shade = (rgb("edab50"), rgb("ffeb57"), rgb("ffc825"), INK), (rgb("ed7614"), rgb("ffc825"), rgb("edab50"), INK)
    far = XX > cx + (rel * 0.1)
    for k in range(4):
        band = rims[k] & ~rims[k + 1]
        a[band] = lit[k]
        a[band & far & (k < 3)] = shade[k]
    a[rims[4]] = rgb("0069aa")
    a[rims[4] & (XX < cx) & (BY < 0.5)] = rgb("0098dc")
    paste(a, head(), cx + 2, y + 42)
    # the ribbon: a band with a light top and dark foot, folded tails behind at both ends
    ry, rh, rw = y + 44, 16, 164
    for side in (-1, 1):
        tx = cx + side * (rw // 2 - 4)
        tail = (np.abs(XX - tx - side * 8) <= 9) & (YY >= ry + 6) & (YY < ry + 6 + rh)
        tail &= ~((np.abs(XX - (tx + side * 17)) + np.abs(YY - (ry + 6 + rh // 2)) * 0.9) < 6)
        sv.inked(a, tail)
        a[tail] = rgb("891e2b")
    band = (np.abs(XX - cx) <= rw // 2) & (YY >= ry) & (YY < ry + rh)
    sv.inked(a, band)
    a[band] = rgb("c42430")
    a[band & (YY == ry)] = rgb("f5555d")
    a[band & (YY >= ry + rh - 2)] = rgb("891e2b")
    name = text_mask("KOBOLD CLICKER", PIXELLARI)
    nx, ny = cx - name.shape[1] // 2, ry + (rh - name.shape[0]) // 2
    stamp(a, outline(name), nx - 1, ny - 1, INK)
    stamp(a, name, nx, ny, rgb("f9e6cf"))
    stamp(a, name & ~np.roll(name, 1, axis=0), nx, ny, WHITE)


def showcase(draw, y):
    """One logo alone on the cover's sky and hill, to be judged where it will stand."""
    def build(seed=71):
        rng = random.Random(seed)
        a = np.zeros((H, W, 3), np.uint8)
        bright_sky(a, rng, seed)
        round_hill(a, rng, top=106, radius=380)
        for x, yy in ((30, 128), (44, 134), (210, 126), (226, 134), (120, 138)):
            daisy(a, x, yy)
        draw(a, W // 2, y)
        check(a, draw.__name__)
        return a
    return build


# ---------------------------------------------------------------- the crowd, upgraded

def crowd2(seed=63):
    """The crowd again with the hero at twice his size in front at the left, the horde massed to the
    right of him, loot beams standing on the hill behind them all and the unique's beam shooting up
    out of an open chest at the front, through the middle of the name."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    bright_sky(a, rng, seed, horizon=96)
    round_hill(a, rng, top=86, radius=420)
    for x, foot, kind in ((96, 92, "rare"), (228, 90, "elite"), (252, 94, "uncommon"), (122, 88, "uncommon")):
        beam(a, x, foot, 0, BEAMS[kind], rng=rng)
    paste(a, enemy("Stone Golem", "idle", 0), 222, 108)
    paste(a, enemy("Minotaur", "attack", 2), 250, 136)
    paste(a, enemy("Masked Orc", "attack", 0), 188, 118)
    beam(a, 160, 138, 0, BEAMS["unique"], w=3, rng=rng)
    logo_beam(a, 160, 8, with_beam=False)
    paste(a, enemy("Mimic", "idle", 0), 216, 150)
    paste(a, enemy("Goblin", "attack", 1), 118, 150)
    paste(a, enemy("Imp", "idle", 0), 250, 148)
    chest = Image.open(ASSETS + "Chests/Chests.png").convert("RGBA").crop((48, 160, 96, 192))
    paste(a, _to_e64(chest.crop(chest.getbbox())), 160, 146)
    # coin flung up out of it, either side of the beam
    for (x, yy), f in zip(((142, 110), (178, 102)), (0, 8)):
        coin(a, x, yy, f)
    paste(a, big(hero("idle", 0)), 46, 150)
    grass_front(a, seed + 6, 50, tones=(rgb("5ac54f"), rgb("33984b")))
    check(a, "crowd2")
    return a


def crowd3(seed=63, doubled=True):
    """The crowd with every monster where `crowd` puts it, the tavern sign in the plaque's place,
    `crowd2`'s loot beams on the hill behind them, the unique's shooting up out of an open chest
    and on behind the sign, and the hero at the front -- at twice his size (`doubled`), or at his
    own where `crowd` stood him."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    bright_sky(a, rng, seed, horizon=96)
    round_hill(a, rng, top=84, radius=420)
    for x, foot, kind in ((96, 92, "rare"), (228, 90, "elite"), (252, 94, "uncommon"), (122, 88, "uncommon")):
        beam(a, x, foot, 0, BEAMS[kind], rng=rng)
    # behind the sign, over its top -- as `crowd`
    paste(a, flipped(enemy("Masked Orc", "attack", 0)), 72, 100)
    paste(a, enemy("Stone Golem", "idle", 0), 188, 102)
    paste(a, flipped(enemy("Flying Eye", "idle", 0)), 38, 70)
    paste(a, enemy("Baby Dragon", "idle", 1), 230, 70)
    paste(a, flipped(enemy("Minotaur", "attack", 2)), 16, 136)
    paste(a, enemy("Werewolf", "attack", 1), 246, 140)
    beam(a, 112, 136, 0, BEAMS["unique"], w=3, rng=rng)
    logo_sign(a, 128, 36)
    # in front of it -- as `crowd`
    paste(a, enemy("Mimic", "idle", 0), 194, 150)
    paste(a, enemy("Goblin", "attack", 1), 150, 150)
    paste(a, enemy("Imp", "idle", 0), 226, 146)
    chest = Image.open(ASSETS + "Chests/Chests.png").convert("RGBA").crop((48, 160, 96, 192))
    paste(a, _to_e64(chest.crop(chest.getbbox())), 112, 140)
    for (x, yy), f in zip(((94, 116), (130, 110)), (0, 8)):
        coin(a, x, yy, f)
    # at twice his size the only place at the front that leaves the sign whole is the left edge:
    # his snout stops at the wood left of the K
    if doubled:
        paste(a, big(hero("idle", 0)), 14, 152)
    else:
        paste(a, hero("idle", 0), 64, 150)
    grass_front(a, seed + 6, 50, tones=(rgb("5ac54f"), rgb("33984b")))
    check(a, "crowd3")
    return a


# ---------------------------------------------------------------- the tavern crowd, three ways
# The user's pick of 2026-09-30: the sign where its showcase hangs it, the kobold at his own size as
# in `crowd3(doubled=False)`, the flying eye and the minotaur gone to free the left, the hero in a
# pose of his own in each.

def puff(a, cx, cy, r):
    """A kicked-up cloud of dust: a pale heap, lit on top, dithered out at its rim."""
    d = np.sqrt(((XX - cx) / r) ** 2 + ((YY - cy) / (r * 0.7)) ** 2)
    m = (d < 1) & ~((d > 0.75) & (BY < 0.5))
    a[m] = rgb("e69c69")
    a[m & (YY < cy)] = rgb("f6ca9f")
    a[m & (YY < cy - r * 0.35) & (d < 0.7)] = rgb("f9e6cf")


def speed_lines(a, x1, y, rows):
    """Streaks trailing to the left of x1: (row offset, length) each, a pale line fading at its tail."""
    for dy, n in rows:
        for i in range(n):
            x = x1 - i
            if 0 <= x < W and 0 <= y + dy < H and (i < n * 0.6 or BY[y + dy, x] < 1 - i / n):
                a[y + dy, x] = WHITE if i < n * 0.3 else rgb("94fdff")


def ground_shadow(a, cx, foot, r):
    m = (((XX - cx) / r) ** 2 + ((YY - foot) / 2.2) ** 2) < 1
    a[m] = rgb("33984b")
    a[m & (((XX - cx) / (r * 0.6)) ** 2 + ((YY - foot) / 1.4) ** 2 < 1)] = rgb("1e6f50")


def slash(a):
    """Mid-swing, the blade's arc sweeping out through the air in front of him."""
    # his body where `leap` puts it: the same cell of the attack sheet, frame 2 in place of 0
    paste(a, hero("attack", 2), 25.5, 132)


def leap(a):
    """In the air with the sword wound back over his head, off the ground in a burst of dust, his
    shadow left on the grass under him."""
    # up off the corner, clear of the sign's letters
    ground_shadow(a, 42, 143, 13)
    puff(a, 20, 141, 7)
    puff(a, 31, 143, 5)
    paste(a, hero("attack", 0), 38, 132)


def charge(a):
    """At a full run toward the horde, dust thrown up behind his heels, speed lines trailing him."""
    puff(a, 30, 140, 8)
    puff(a, 42, 142, 5)
    paste(a, hero("run", 3), 68, 143)
    speed_lines(a, 36, 106, ((0, 16), (7, 22), (14, 12), (21, 18)))


# The pixellab gold is a muted tan, and ENDESGA's nearest to it are its peach and copper: the pieces
# that are gold are re-gilded for the cover, each copper step to the gold step of its lightness.
GILDED = ("crown_of_accord", "overflowing_chalice", "heirlooms_echo")
GILD = {rgb(a): rgb(b) for a, b in (("f6ca9f", "ffeb57"), ("e69c69", "ffc825"), ("bf6f4a", "ffa214"),
                                     ("8a4836", "ed7614"), ("5d2c28", "8e251d"))}


def gild(sprite):
    out = sprite.copy()
    for src, dst in GILD.items():
        out[(sprite[..., :3] == src).all(-1) & (sprite[..., 3] > 0), :3] = dst
    return out


# Who stands where in the tavern covers, back row (behind the sign) and front row, each as
# (name, animation, frame, turned round, x, foot): the frame is the still's pose, and the idle is
# what the animated cover plays in its place.
CAST_BACK = (("Masked Orc", "attack", 0, True, 72, 100), ("Stone Golem", "idle", 0, False, 188, 102),
             ("Baby Dragon", "idle", 1, False, 230, 70), ("Werewolf", "attack", 1, False, 246, 140))
CAST_FRONT = (("Mimic", "idle", 0, False, 194, 150), ("Goblin", "attack", 1, False, 150, 150),
              ("Imp", "idle", 0, False, 226, 146))
## The hero's cell in the animated cover: where the slash's still frame puts it (`slash`, and
## `leap` before it), which every frame of his idle and his swing are drawn in.
HERO_STILL = ("attack", 2, 25.5, 132)
## The frames of the loop he swings on (attack 0..4, the blow held a frame), and the one the
## pointer clicks on just before: the click is what swings him, as it is in the game.
SWING = {40: 0, 41: 1, 42: 2, 43: 2, 44: 3, 45: 4}
CLICK = (39, 40)
## The sign knocked by the click, swinging in depth on its ropes (`tipped`): rows out of true on
## each frame from it, pushed in by the click (its bottom away, < 0), then back and forth a little
## less each time until it hangs still again, well before the loop comes round. Not left and right:
## the user's ruling (2026-09-30).
TILT = dict(zip(range(40, 55), (-2, -4, -4, -2, 1, 3, 3, 1, -1, -2, -2, -1, 1, 1, 0)))


def _cell(sheet_path, fw, fh, i, flip):
    f = Image.open(sheet_path).convert("RGBA").crop((i * fw, 0, (i + 1) * fw, fh))
    return f.transpose(Image.FLIP_LEFT_RIGHT) if flip else f


def enemy_cell(name, anim, i, turned=False):
    """A whole frame cell of an enemy, facing left (and turned round again if `turned`)."""
    d, (fw, fh), right, sheets = ROSTER[name]
    return _cell(f"{ASSETS}Enemies/{d}/{sheets[anim]}", fw, fh, i, right != turned)


def hero_cell(anim, i):
    return _cell(f"{ASSETS}Player/{anim}.png", 148, 96, i, False)


def cell_origin(still, cx, foot):
    """Where `paste` puts the corner of a cell whose drawn part it stood on (cx, foot): every other
    frame of the same sheet goes there too, so a creature idles on the spot instead of jumping about
    with each frame's own bounds."""
    box = still.getbbox()
    w, h = box[2] - box[0], box[3] - box[1]
    return int(round(cx - w / 2)) - box[0], int(foot) - h - box[1]


def paste_cell(a, cell, origin):
    sprite = _to_e64(cell)
    ox, oy = origin
    ys, xs = np.nonzero(sprite[..., 3])
    ok = (oy + ys >= 0) & (oy + ys < H) & (ox + xs >= 0) & (ox + xs < W)
    a[oy + ys[ok], ox + xs[ok]] = sprite[ys[ok], xs[ok], :3]


def frames_of(name, anim):
    d, (fw, fh), right, sheets = ROSTER[name]
    return Image.open(f"{ASSETS}Enemies/{d}/{sheets[anim]}").width // fw


## The slowest an idle may go round, in frames of the loop: every sprite frame held at least
## `IDLE_HOLD` of them, and a whole breath taking at least `IDLE_CYCLE` (1 s). At the game's own
## one-a-frame the three-frame Mimic breathed three times a second, and the user found the lot
## rushed; at 2 and 15 (1.5 s) a bit slow (2026-09-30).
IDLE_HOLD = 1.5
IDLE_CYCLE = 10


def idle_frame(count, f, shift, cycle=IDLE_CYCLE):
    """Which of `count` idle frames shows on frame `f` of the loop: a whole number of turns of it
    in a loop, each turn at least `cycle` frames and every frame held at least `IDLE_HOLD`, so the
    loop never skips; `shift` staggers the cast so they do not all breathe together."""
    turns = max(1, round(LOOP / max(count * IDLE_HOLD, cycle)))
    return (f * turns * count // LOOP + shift) % count


def cast(a, who, f):
    for n, (name, anim, i, turned, x, foot) in enumerate(who):
        if f is None:
            sprite = enemy(name, anim, i)
            paste(a, flipped(sprite) if turned else sprite, x, foot)
            continue
        origin = cell_origin(enemy_cell(name, anim, i, turned), x, foot)
        k = idle_frame(frames_of(name, "idle"), f, n * 2 + len(name))
        paste_cell(a, enemy_cell(name, "idle", k, turned), origin)


def winking(a, spots, f):
    """The sparkles round the find, each (x, y, colour): on the still at full, and on frame `f` of
    the loop each winking on and off on its own beat, growing to full and back."""
    for n, (x, y, c) in enumerate(spots):
        if f is None:
            glint(a, x, y, c)
            continue
        beat = (f + n * 7) % 20
        if beat < 12:
            glint(a, x, y, c, arm=(0, 1, 2, 2, 1, 0)[beat // 2])


def hero_swing(a, f, anim, i, x, foot):
    """The hero on frame `f` of the loop, in the cell where the still's (anim, i) stands on
    (x, foot): idling, and on the `SWING` frames swinging."""
    origin = cell_origin(hero_cell(anim, i), x, foot)
    idle = hero_cell("idle", idle_frame(6, f, 0, cycle=9))
    paste_cell(a, hero_cell("attack", SWING[f]) if f in SWING else idle, origin)


def tavern(pose, seed=63, unique="stonebreaker", f=None, front=True):
    """The tavern cover. `f` (a frame of the `LOOP`) draws the animated one's frame instead of the
    still: the cast idling, the beams alive, the sword's sparkles winking, and once a loop the
    pointer clicks and the hero swings. `front` False leaves off the blades along the bottom, for a
    canvas that goes on below it."""
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    bright_sky(a, rng, seed, horizon=96)
    round_hill(a, rng, top=84, radius=420)
    for x, foot, kind in ((96, 92, "rare"), (228, 90, "elite"), (252, 94, "uncommon"), (122, 88, "uncommon")):
        beam(a, x, foot, 0, BEAMS[kind], rng=rng, f=f)
    cast(a, CAST_BACK, f)
    beam(a, 112, 136, 0, BEAMS["unique"], w=3, rng=rng, f=f)
    logo_sign(a, 128, 26, press=f in CLICK, tilt=TILT.get(f, 0))
    cast(a, CAST_FRONT, f)
    # the unique the beam stands over, lying in the grass at its foot
    paste(a, the_find(unique), 112, 139)
    winking(a, ((96, 112, WHITE), (128, 106, rgb("ffeb57")), (124, 128, WHITE)), f)
    if f is None:
        pose(a)
    else:
        hero_swing(a, f, *HERO_STILL)
    if front:
        grass_front(a, seed + 6, 50, tones=(rgb("5ac54f"), rgb("33984b")))
    check(a, "tavern " + pose.__name__)
    return a


_FINDS = {}


def the_find(unique):
    """A unique's icon for the beam: through the project's own OKLab mapping (`hexlib.to_e64`),
    which keeps a pixellab piece's gold gold -- the plain nearest-in-RGB of `_to_e64` turned the
    crown to copper -- and re-gilded if it is one of the gold ones."""
    if unique not in _FINDS:
        import hexlib
        find = Image.open(ASSETS + "Gear/Unique/%s.png" % unique).convert("RGBA")
        find = _to_e64(hexlib.to_e64(find.crop(find.getbbox())))
        _FINDS[unique] = gild(find) if unique in GILDED else find
    return _FINDS[unique]


TAVERN = {"tavern_" + p.__name__: (lambda p=p: tavern(p)) for p in (slash, leap, charge)}
# The unique in the beam, tried six ways on the slash (asked 2026-09-30).
FINDS = ("crown_of_accord", "glass_edge", "headsman", "dreadmask", "overflowing_chalice", "heirlooms_echo")
TAVERN.update({"slash_" + u: (lambda u=u: tavern(slash, unique=u)) for u in FINDS})


# ---------------------------------------------------------------- the cover upright, for phones
# Asked 2026-10-01: held upright, a phone letterboxes the 16:9 loop to a strip a quarter of its
# height. Each of these is drawn for 9:19.5 (the narrow layout's 360x780); a 9:16 phone shows its
# middle (`crop_916`).

def tall_sky(a, rng, horizon, shafts=((22, 10), (70, 6), (118, 14), (176, 8), (228, 12))):
    """`bright_sky` over a taller sky: its bands where it puts them, measured up from the horizon,
    and over them the deep blue of the zenith; its shafts of light, fading in from the top."""
    sv.sky(a, ((rgb("0069aa"), 0), (rgb("0098dc"), horizon - 170), (rgb("00cdf9"), horizon - 62),
               (rgb("0cf1ff"), horizon - 26), (rgb("94fdff"), horizon + 2)))
    for x, wide in shafts:
        off = np.abs(XX - (x + YY * 0.18))
        shaft = (off < wide / 2) & (YY < horizon) & (BY < 1.1 - YY / horizon)
        lighten(a, shaft & ~((off > wide / 2 - 1.5) & (BY < 0.5)))
    for cx in range(20, W + 40, 70):
        sv.cloud(a, rng, cx + rng.randint(-10, 10), horizon + 4, rng.randint(70, 110), rng.randint(20, 30),
                 lit=WHITE, body=rgb("94fdff"), bump=(4, 7))


def deep_grass(a, top):
    """The hill on below where `round_hill` stops darkening: a step darker again past `top`."""
    m = (a == rgb("33984b")).all(-1) & (YY > top) & (BY < (YY - top) / 40)
    a[m] = rgb("1e6f50")


def tall_stage(seed=63):
    """The cover as it is, untouched, in the middle of a taller sky and a deeper hill: the ropes run
    on up to the top, the shafts of light fade in from it, the grass darkens toward the bottom."""
    grid(256, 144, 9)
    scene = tavern(slash, unique="glass_edge", front=False)
    grid(*GRIDS["tall_stage"])
    # a whole number of the ropes' 3-row pattern and the dither's 4, so both run on unbroken
    oy = 204
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    tall_sky(a, rng, oy + 96, shafts=())
    # the scene's shafts, carried on up and fading in from the top as they come down to it
    for x, wide in ((22, 10), (70, 6), (118, 14), (176, 8), (228, 12)):
        off = np.abs(XX - (x + (YY - oy) * 0.18))
        shaft = (off < wide / 2) & (BY < 1.1 * YY / oy)
        lighten(a, shaft & ~((off > wide / 2 - 1.5) & (BY < 0.5)))
    for rx in (128 - 75 + 24, 128 + 75 - 26):
        for yy in range(oy):
            a[yy, rx] = rgb("e69c69") if (yy - oy) % 3 else rgb("8a4836")
            a[yy, rx + 1] = rgb("bf6f4a") if (yy - oy) % 3 else rgb("5d2c28")
    # the hill on under it, banded as the scene's is, so the seam falls between like rows
    round_hill(a, random.Random(seed + 1), top=oy + 84, radius=420)
    deep_grass(a, oy + 170)
    a[oy: oy + 144] = scene
    grass_front(a, seed + 6, 60, tones=(rgb("5ac54f"), rgb("33984b")))
    check(a, "tall_stage")
    return a


## Who stands where, upright: as `CAST_BACK` and `CAST_FRONT`, each (name, animation, frame,
## turned round, x, foot); the sign's centre and top; the unique (x, foot); the hero's slash (x, foot).
UPRIGHT = {
    # The name high on short ropes, the whole cast under it down a taller hill.
    "tall_poster": dict(
        horizon=150, sign=(90, 40),
        beams=((14, 146, "rare"), (36, 142, "uncommon"), (148, 142, "elite"), (170, 146, "uncommon")),
        back=(("Masked Orc", "attack", 0, True, 36, 206), ("Stone Golem", "idle", 0, False, 110, 214),
              ("Baby Dragon", "idle", 1, False, 158, 180), ("Werewolf", "attack", 1, False, 146, 278)),
        find=(66, 278),
        front=(("Goblin", "attack", 1, False, 106, 324), ("Imp", "idle", 0, False, 166, 306),
               ("Mimic", "idle", 0, False, 146, 348)),
        hero=(25.5, 346),
        glints=((50, 248, WHITE), (82, 242, rgb("ffeb57")), (78, 266, WHITE))),
    # The name in the middle of the horde, as the cover has it: over its top, at its sides, below.
    "tall_crowd": dict(
        horizon=150, sign=(90, 150),
        beams=((14, 146, "rare"), (36, 142, "uncommon"), (148, 142, "elite"), (170, 146, "uncommon")),
        back=(("Masked Orc", "attack", 0, True, 20, 170), ("Stone Golem", "idle", 0, False, 132, 176),
              ("Werewolf", "attack", 1, False, 140, 282)),
        find=(62, 280),
        # the dragon flies nearer than the ropes
        front=(("Baby Dragon", "idle", 1, False, 140, 100), ("Goblin", "attack", 1, False, 108, 324),
               ("Imp", "idle", 0, False, 168, 306), ("Mimic", "idle", 0, False, 146, 348)),
        hero=(25.5, 346),
        glints=((46, 250, WHITE), (78, 244, rgb("ffeb57")), (74, 268, WHITE))),
}


def upright(name, seed=63, unique="glass_edge", f=None):
    """An upright cover from its `UPRIGHT` layout, drawn in the tavern's order; `f` draws frame `f`
    of its loop, animated as the tavern's is."""
    L = UPRIGHT[name]
    rng = random.Random(seed)
    a = np.zeros((H, W, 3), np.uint8)
    tall_sky(a, rng, L["horizon"])
    round_hill(a, rng, top=L["horizon"] - 12, radius=420)
    deep_grass(a, L["horizon"] + 120)
    for x, foot, kind in L["beams"]:
        beam(a, x, foot, 0, BEAMS[kind], rng=rng, f=f)
    cast(a, L["back"], f)
    fx, ffoot = L["find"]
    beam(a, fx, ffoot - 3, 0, BEAMS["unique"], w=3, rng=rng, f=f)
    logo_sign(a, *L["sign"], press=f in CLICK, tilt=TILT.get(f, 0))
    cast(a, L["front"], f)
    paste(a, the_find(unique), fx, ffoot)
    winking(a, L["glints"], f)
    if f is None:
        paste(a, hero("attack", 2), *L["hero"])
    else:
        hero_swing(a, f, "attack", 2, *L["hero"])
    grass_front(a, seed + 6, 36, tones=(rgb("5ac54f"), rgb("33984b")))
    check(a, name)
    return a


UPRIGHTS = {"tall_stage": tall_stage, **{n: (lambda n=n: upright(n)) for n in UPRIGHT}}


def crop_916(h, w):
    """The rows of an upright cover a 9:16 phone shows: its middle."""
    keep = w * 16 // 9
    return (h - keep) // 2, (h - keep) // 2 + keep


def phones(path="qa/cover_phones.png"):
    """Every upright cover as a 360x780 phone shows it, beside today's letterboxed loop, the rows a
    9:16 phone keeps ticked at each frame's sides."""
    grid(*GRIDS[FINAL])
    today = Image.new("RGB", (360, 780))
    shot = Image.fromarray(COVERS[FINAL](), "RGB").resize((360, 202), Image.LANCZOS)
    today.paste(shot, (0, (780 - 202) // 2))
    shots = [("today", today)]
    for name in UPRIGHTS:
        grid(*GRIDS[name])
        shots.append((name, Image.fromarray(UPRIGHTS[name](), "RGB").resize((360, 780), Image.NEAREST)))
    gap, label = 40, 40
    sheet = Image.new("RGB", (gap + len(shots) * (360 + gap), gap + 780 + label), rgb("1a1932"))
    d = ImageDraw.Draw(sheet)
    d.fontmode = "1"
    for i, (name, img) in enumerate(shots):
        x = gap + i * (360 + gap)
        d.rectangle((x - 6, gap - 6, x + 360 + 5, gap + 780 + 5), fill=rgb("2a2f4e"))
        sheet.paste(img, (x, gap))
        y0, y1 = crop_916(780, 360)
        for y in (y0, y1):
            d.line((x - 14, gap + y, x - 7, gap + y), fill=rgb("ffc825"), width=2)
            d.line((x + 366, gap + y, x + 373, gap + y), fill=rgb("ffc825"), width=2)
        d.text((x, gap + 780 + 12), name, font=PIXELLARI, fill=rgb("f9e6cf"))
    sheet.save(path)
    print(path)


LOGOS = {"logo_beam": showcase(logo_beam, 30), "logo_mascot": showcase(logo_mascot, 50),
         "logo_rarity": showcase(logo_rarity, 36), "logo_sign": showcase(logo_sign, 26),
         "logo_chest": showcase(logo_chest, 12), "logo_crest": showcase(logo_crest, 22)}
COVERS = {"ridge": ridge, "wall": wall, "valley": valley, "standoff": standoff, "crowd": crowd,
          "crowd2": crowd2, "crowd3": crowd3,
          "crowd3_small": lambda: crowd3(doubled=False), **TAVERN, **LOGOS, **UPRIGHTS}
# The plaque covers and the logos are drawn on their own grid (set in `main`): the vistas' 288x162
# at 8x, these 256x144 at 9x -- both 2304x1296.
GRIDS = {name: (256, 144, 9) for name in ("standoff", "crowd", "crowd2", "crowd3", "crowd3_small", *TAVERN, *LOGOS)}
# The upright covers: 9:19.5, the stage at the landscape's own width, the others narrower so the
# cast stands bigger on the phone.
GRIDS.update({"tall_stage": (256, 555, 5), "tall_poster": (180, 390, 6), "tall_crowd": (180, 390, 6)})


def grid(w, h, scale):
    """Points the module, and sideview's, at a grid of w x h shown `scale` times."""
    global W, H, SCALE, YY, XX, BY
    W, H, SCALE = w, h, scale
    sv.W, sv.H = w, h
    sv.YY, sv.XX = np.mgrid[0:h, 0:w]
    sv._BY = np.tile(sv.BAYER, (h // 4 + 1, w // 4 + 1))[:h, :w]
    YY, XX, BY = sv.YY, sv.XX, sv._BY


# ---------------------------------------------------------------- the cover, kept
# The user's pick of 2026-09-30: the tavern crowd, the slash, the Glass Edge in the beam. `--export`
# writes it and its animation to store/ (a .gdignore keeps Godot from importing them).

FINAL = "slash_glass_edge"
## The user's pick for a phone held upright (2026-10-01).
FINAL_TALL = "tall_crowd"
STORE = "../store/"
LANDING = "../Assets/Landing/"
## The GIF's size against the grid: 4x is 1024x576, small enough to post; the MP4 is the full 9x.
GIF_SCALE = 4


def animation(tall=False):
    grid(*GRIDS[FINAL_TALL if tall else FINAL])
    if tall:
        return [upright(FINAL_TALL, f=f) for f in range(LOOP)]
    return [tavern(slash, unique="glass_edge", f=f) for f in range(LOOP)]


def write_gif(frames, path, scale):
    """Every colour is ENDESGA 64's, so a GIF's 256 hold them exactly: nothing is dithered or lost."""
    palette = Image.new("P", (1, 1))
    palette.putpalette([v for c in E64 for v in c] + [0] * (768 - 3 * len(E64)))
    shots = [Image.fromarray(a, "RGB").resize((W * scale, H * scale), Image.NEAREST)
             .quantize(palette=palette, dither=Image.Dither.NONE) for a in frames]
    shots[0].save(path, save_all=True, append_images=shots[1:], duration=1000 // 10, loop=0,
                  optimize=False, disposal=1)
    print(path)


def write_mp4(frames, path):
    """The loop at the full 2304x1296, 10 frames a second shown at 30 (each held three), H.264."""
    import subprocess
    import tempfile
    with tempfile.TemporaryDirectory() as tmp:
        for n, a in enumerate(frames):
            Image.fromarray(a, "RGB").resize((W * SCALE, H * SCALE), Image.NEAREST).save(f"{tmp}/{n:03d}.png")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-framerate", "10", "-i", f"{tmp}/%03d.png",
                        "-vf", "fps=30", "-c:v", "libx264", "-preset", "slow", "-crf", "12",
                        "-pix_fmt", "yuv420p", "-movflags", "+faststart", path], check=True)
    print(path)


def export():
    import os
    import subprocess
    os.makedirs(STORE, exist_ok=True)
    open(STORE + ".gdignore", "a").close()
    os.makedirs(LANDING, exist_ok=True)
    for name, tall in (("cover", False), ("cover_tall", True)):
        grid(*GRIDS[FINAL_TALL if tall else FINAL])
        still = COVERS[FINAL_TALL if tall else FINAL]()
        Image.fromarray(still, "RGB").resize((W * SCALE, H * SCALE), Image.NEAREST).save(f"{STORE}{name}.png")
        print(f"{STORE}{name}.png")
        frames = animation(tall)
        if not tall:
            write_gif(frames, STORE + "cover.gif", GIF_SCALE)
        write_mp4(frames, f"{STORE}{name}.mp4")
        # The game's landing page plays the same loop, and Godot plays only Ogg Theora.
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", f"{STORE}{name}.mp4", "-vf", "fps=10",
                        "-c:v", "libtheora", "-q:v", "8", f"{LANDING}{name}.ogv"], check=True)
        print(f"{LANDING}{name}.ogv")


def main(names):
    if "--export" in names:
        export()
        return
    for name in names or COVERS:
        if name in ("animated", "animated_tall"):
            write_gif(animation(name == "animated_tall"), f"qa/cover_{name}.gif", GIF_SCALE)
            continue
        if name == "phones":
            phones()
            continue
        grid(*GRIDS.get(name, (288, 162, 8)))
        a = COVERS[name]()
        img = Image.fromarray(a, "RGB").resize((W * SCALE, H * SCALE), Image.NEAREST)
        img.save(f"qa/cover_{name}.png")
        print(f"qa/cover_{name}.png")


if __name__ == "__main__":
    main(sys.argv[1:])
