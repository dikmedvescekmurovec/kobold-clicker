"""The intro comic: one page of five panels the game shows on a first run, before the map -- drawn from
the game's own backdrops and sprites at one fighter pixel a pixel, on the battle backdrops' 384x216
grid, so the page is a fight's size and is shown at the same whole zoom.

`python comic.py [tag]` writes qa/comic_<tag>.png (m1 without one) at 3x, the default window's size.
"""
import argparse
import glob
import os
import random

os.chdir(os.path.dirname(os.path.abspath(__file__)))

import numpy as np  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

import cover as cv  # noqa: E402
import sideview as sv  # noqa: E402

W, H = 384, 216
# cover and sideview draw on module-wide grids; point both at the backdrops' own.
cv.W, cv.H = sv.W, sv.H = W, H
sv.YY, sv.XX = np.mgrid[0:H, 0:W]
sv._BY = np.tile(sv.BAYER, (H // 4 + 1, W // 4 + 1))[:H, :W]
cv.YY, cv.XX, cv.BY = sv.YY, sv.XX, sv._BY
rgb, INK, WHITE, FEET = sv.rgb, sv.INK, sv.WHITE, sv.FEET
AREA = "../Assets/Area/"
PAPER = rgb("f9e6cf")

# The page's panels, each (x, y, w, h) on the 384x216 page, in reading order.
PANELS = ((4, 4, 176, 102), (184, 4, 72, 102), (260, 4, 120, 102),
          (4, 110, 196, 102), (204, 110, 176, 102))


def _rgba(path):
    return np.array(Image.open(path).convert("RGBA"))


def backdrop(env, place, layout, sky, after=None):
    """A place as its fight shows it, layers over the sky in the sky's light; `after(a, band)` draws
    between the layers (band 0 right after the sky), so a thing can stand behind the nearer land."""
    tint = np.array(sv.LIGHT[sky], float)
    a = _rgba(f"{AREA}sky/{sky}.png")[..., :3].copy()
    stack = []
    band = 1
    while os.path.exists(f"{AREA}land/{env}_{layout}_{band}.png"):
        stack.append(_rgba(f"{AREA}land/{env}_{layout}_{band}.png"))
        band += 1
    stack.append(_rgba(f"{AREA}{env}_{place}_{layout}.png"))
    for i, layer in enumerate(stack):
        if after:
            after(a, i)
        lit = (layer[..., :3] * tint).round().astype(np.uint8)
        a[layer[..., 3] > 0] = lit[layer[..., 3] > 0]
    return a


def lit(sprite, sky):
    """A sprite in the sky's light, the way the fight pulls its fighters toward it."""
    s = sprite.astype(float)
    s[..., :3] *= 1 - sv.FIGHTER_LIGHT * (1 - np.array(sv.LIGHT[sky]))
    return s.round().astype(np.uint8)


def stand(a, sprite, cx, sky, foot=FEET):
    """A figure on the ground over the fight's contact shadow."""
    w = sprite.shape[1]
    sw, sh = int(w * 0.55), max(2, int(w * 0.55 / 4))
    m = (((cv.XX - cx) / (sw / 2)) ** 2 + ((cv.YY - foot) / (sh / 2)) ** 2) <= 1
    a[m] = (a[m] * 0.68).astype(np.uint8)
    cv.paste(a, lit(sprite, sky), cx, foot)


def slime(anim, i):
    f = Image.open(f"../Assets/Enemies/Grass Slime/slime-{anim}-{i}.png").convert("RGBA")
    return cv._to_e64(f.crop(f.getbbox()))


# ---------------------------------------------------------------- lettering

def words(lines, lead=11):
    """Lines of Ark Pixel at its native 10 px, as a mask cut to what they draw."""
    img = Image.new("L", (240, lead * len(lines) + 12), 0)
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    for i, t in enumerate(lines):
        w = d.textlength(t, font=cv.ARK)
        d.text(((240 - w) // 2, 2 + i * lead), t, font=cv.ARK, fill=255)
    m = np.array(img) > 127
    ys, xs = np.nonzero(m)
    return m[ys.min(): ys.max() + 1, xs.min(): xs.max() + 1]


def bubble(a, lines, x, y, tail=None):
    """A speech balloon with its top-left at (x, y): white, an ink line round it, corners bitten off,
    and a tail to the point `tail` (the speaker's mouth); the words centred in it."""
    m = words(lines)
    th, tw = m.shape
    w, h = tw + 9, th + 7
    img = Image.new("1", (W, H), 0)
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((x, y, x + w - 1, y + h - 1), radius=3, fill=1)
    if tail and tail[0] < x:
        d.polygon(((x + 1, y + h // 2 - 3), (x + 1, y + h // 2 + 3), tail), fill=1)
    elif tail:
        mid = x + w // 2 + (6 if tail[0] > x + w // 2 else -6)
        d.polygon(((mid - 3, y + h - 2), (mid + 3, y + h - 2), tail), fill=1)
    body = np.array(img)
    a[sv.grow(body) & ~body] = INK
    a[body] = WHITE
    cv.stamp(a, m, x + 5, y + 4, INK)


def sfx(a, text, x, y, k=2, bands=cv.GOLD_BANDS, extrude=rgb("8e251d")):
    """A sound in the logo's lettering, `k` times Pixellari's size."""
    m = np.kron(cv.text_mask(text, cv.PIXELLARI), np.ones((k, k), bool))
    cv.lettering(a, m, x, y, deep=k + 1, thick=1, bands=bands, extrude=extrude)


def burst(a, cx, cy, r0, r1, points=11, fill=rgb("ffeb57"), core=WHITE):
    """The comic's spiky star of a blow landing, inked."""
    ang = np.arange(points * 2) * np.pi / points
    rad = np.where(np.arange(points * 2) % 2 == 0, r1, r0)
    poly = list(zip(cx + rad * np.cos(ang), cy + rad * np.sin(ang) * 0.8))
    img = Image.new("1", (W, H), 0)
    ImageDraw.Draw(img).polygon(poly, fill=1)
    m = np.array(img)
    a[sv.grow(m) & ~m] = INK
    a[m] = fill
    a[m & ((((cv.XX - cx) / r0) ** 2 + ((cv.YY - cy) / (r0 * 0.8)) ** 2) < 0.45)] = core


def fog(a, x0, seed=5):
    """A bank of fog rolling in from the right, thinning by dither toward `x0`."""
    n = sv.noise2(seed, W, H, 10)
    t = np.clip((cv.XX - x0) / 40.0, 0, 1) * (0.55 + 0.6 * n)
    a[(t > 0.2) & (cv.BY < t)] = rgb("c7cfdd")
    a[(t > 0.55) & (cv.BY < t - 0.3)] = WHITE


# ---------------------------------------------------------------- the panels
# Each draws the whole 384x216 scene and says where its panel's window onto it stands.

def hoard():
    """Night. The kobold shows off everything he owns: two coins."""
    a = backdrop("grass", "plain", 1, "night")
    for i, x in enumerate((232, 241)):
        cv.coin(a, x, FEET - 6, (0, 8)[i])
    stand(a, cv.hero("idle", 0), 206, "night")
    bubble(a, ["Behold!", "My hoard!"], 150, 102, tail=(206, 132))
    bubble(a, ["...it's two", "coins."], 240, 128, tail=(228, 144))
    return a, (140, 96)


def beam():
    """Far off over the hills, something drops, and its light goes up into the night."""
    def far(a, band):
        if band == 1:
            cv.beam(a, 286, 150, 30, cv.BEAMS["unique"], w=2)
    a = backdrop("grass", "plain", 1, "night", after=far)
    for x, y in ((270, 64), (300, 52), (279, 90)):
        cv.glint(a, x, y, rgb("ffeb57"), arm=1)
    return a, (250, 40)


def look():
    """Close on the kobold, the gold light in his face."""
    a = backdrop("grass", "plain", 1, "night")
    head = cv.big(cv.head())
    cv.paste(a, lit(head, "night"), 196, 200)
    sfx(a, "!", 244, 100, k=2)
    bubble(a, ["Somebody dropped", "something."], 146, 100, tail=(196, 150))
    bubble(a, ["Dibs."], 222, 132, tail=(240, 172))
    return a, (140, 96)


def whack():
    """Morning. A slime in the way, a swing, and a coin out of it."""
    a = backdrop("grass", "plain", 2, "morning")
    burst(a, 240, 174, 7, 15)
    stand(a, slime("hurt", 1), 240, "morning")
    stand(a, cv.hero("attack", 2), 176, "morning")
    cv.coin(a, 262, 146, 0)
    cv.glint(a, 272, 140, rgb("ffeb57"), arm=1)
    sfx(a, "WHACK!", 182, 102)
    bubble(a, ["Ooh! They", "drop things", "too!"], 106, 102, tail=(170, 136))
    return a, (100, 96)


def edge():
    """The town at his back, the fog ahead: where the first click goes."""
    a = backdrop("grass", "town", 1, "morning")
    fog(a, 342)
    stand(a, cv.hero("idle", 0), 322, "morning")
    bubble(a, ["Bet the good stuff's", "past the fog."], 224, 104, tail=(320, 136))
    return a, (208, 96)


SCENES = (hoard, beam, look, whack, edge)


# ---------------------------------------------------------------- "Monster Selected": the System picks a kobold
# Two pages of four. The System speaks only in its windows, blue, or red for a warning.

E64 = cv.E64
CAVE_FEET = 198  # CombatScene.CAVE_GROUND on the 216 rows
SYSTEM = {"fill": rgb("03193f"), "line": rgb("0cf1ff"), "inner": rgb("0069aa"), "glow": rgb("0098dc"),
          "title": rgb("94fdff"), "text": WHITE, "button": rgb("00396d")}
ALARM = {"fill": rgb("1c121c"), "line": rgb("f5555d"), "inner": rgb("891e2b"), "glow": rgb("ea323c"),
         "title": rgb("f68187"), "text": WHITE, "button": rgb("571c27")}
# The hero's blue ramp, and the other kobolds of his pack in theirs.
BLUE = ("0c2e44", "00396d", "0069aa", "0098dc", "00cdf9")
PACKS = {"green": ("134c4c", "1e6f50", "33984b", "5ac54f", "99e65f"),
         "red": ("571c27", "891e2b", "c42430", "ea323c", "f5555d")}
EYE = ((16, 35), (16, 36), (17, 35), (17, 36), (17, 37), (18, 35), (18, 36), (18, 37), (19, 36), (19, 37))


def snap(c):
    """Colours to their nearest ENDESGA 64."""
    flat = c.reshape(-1, 3).astype(int)
    d = ((flat[:, None, :] - E64[None, :, :]) ** 2).sum(-1)
    return E64[d.argmin(1)].reshape(c.shape).astype(np.uint8)


def cast(a, m, colour, k):
    """The pixels under `m` pulled `k` of the way toward a light's colour."""
    a[m] = snap(a[m] * (1 - k) + np.array(colour) * k)


def kobold(pack, anim="idle", i=0):
    s = cv.hero(anim, i)
    out = s.copy()
    for src, dst in zip(BLUE, PACKS[pack]):
        out[(s[..., :3] == rgb(src)).all(-1)] = (*rgb(dst), 255)
    return out


def adventurer(cid, anim, i, fw):
    sheet = Image.open(f"../Assets/Characters/{cid}/{anim}.png").convert("RGBA")
    f = sheet.crop((i * fw, 0, (i + 1) * fw, sheet.height))
    return cv._to_e64(f.crop(f.getbbox()))


def cave(nearest=False):
    a = _rgba("../Assets/Area/cave/7.png")[..., :3].copy()
    for n in range(6, 0 if nearest else 1, -1):
        layer = _rgba(f"../Assets/Area/cave/{n}.png")
        a[layer[..., 3] > 0] = layer[..., :3][layer[..., 3] > 0]
    return a


def front_rock(a):
    layer = _rgba("../Assets/Area/cave/1.png")
    a[layer[..., 3] > 0] = layer[..., :3][layer[..., 3] > 0]


def window(a, x, y, title, lines=(), tone=SYSTEM, buttons=(), glitch=(), anchor=0.0):
    """A System window, `anchor` of its width left of x (0 its top-left, 1 its top-right) and its top at y:
    a title under a "!" badge, a rule,
    the lines, a row of buttons; glowing round its edge. Returns each button's middle. `glitch` rows
    slip sideways."""
    head = words([title])
    body = words(lines) if lines else np.zeros((0, 0), bool)
    keys = [words([b]) for b in buttons]
    keys_w = sum(k.shape[1] + 12 for k in keys) + 6 * max(0, len(keys) - 1)
    w = max(head.shape[1] + 14, body.shape[1], keys_w) + 14
    h = 5 + head.shape[0] + 5 + (body.shape[0] + 5 if lines else 0) + (15 if keys else 0) + 3
    if not lines and not keys:
        h = head.shape[0] + 9
    x -= int(w * anchor)
    box = (cv.XX >= x) & (cv.XX < x + w) & (cv.YY >= y) & (cv.YY < y + h)
    ring = box.copy()
    for d, cut in ((1, 0.8), (2, 0.45), (3, 0.18)):
        grown = sv.grow(ring)
        a[grown & ~ring & (cv.BY < cut)] = tone["glow"]
        ring = grown
    a[box] = tone["fill"]
    a[box & ~((cv.XX > x) & (cv.XX < x + w - 1) & (cv.YY > y) & (cv.YY < y + h - 1))] = tone["line"]
    for cx, cy in ((x, y), (x + w - 1, y), (x, y + h - 1), (x + w - 1, y + h - 1)):
        for k in range(3):
            for px, py in ((cx + (k if cx == x else -k), cy), (cx, cy + (k if cy == y else -k))):
                a[py, px] = WHITE
    hx = x + (w - head.shape[1] - 12) // 2
    a[y + 4: y + 5 + head.shape[0], hx: hx + 9] = tone["line"]
    a[y + 5: y + 4 + head.shape[0], hx + 1: hx + 8] = tone["fill"]
    a[y + 6: y + 4 + head.shape[0] - 3, hx + 4] = tone["title"]
    a[y + 3 + head.shape[0] - 1, hx + 4] = tone["title"]
    cv.stamp(a, head, hx + 12, y + 5, tone["title"])
    rule = y + 5 + head.shape[0] + 2
    if lines or keys:
        a[rule, x + 4: x + w - 4] = tone["inner"]
    yy = rule + 4
    if lines:
        cv.stamp(a, body, x + (w - body.shape[1]) // 2, yy, tone["text"])
        yy += body.shape[0] + 5
    mids = []
    bx = x + (w - keys_w) // 2
    for k in keys:
        bw = k.shape[1] + 12
        a[yy: yy + 13, bx: bx + bw] = tone["line"]
        a[yy + 1: yy + 12, bx + 1: bx + bw - 1] = tone["button"]
        cv.stamp(a, k, bx + 6, yy + 2, tone["text"])
        mids.append((bx + bw // 2, yy + 6))
        bx += bw + 6
    for r in glitch:
        a[y + r: y + r + 2, x - 3: x + w + 3] = np.roll(a[y + r: y + r + 2, x - 3: x + w + 3], 3, axis=1)
    return mids


def mask_at(sprite, cx, foot):
    """Where a sprite with the middle of its foot on (cx, foot) covers the scene, cut to its edges; and its
    top-left corner."""
    h, w = sprite.shape[:2]
    x0, y0 = int(round(cx - w / 2)), int(foot) - h
    m = np.zeros((H, W), bool)
    ys, xs = np.nonzero(sprite[..., 3] > 0)
    ok = (y0 + ys >= 0) & (y0 + ys < H) & (x0 + xs >= 0) & (x0 + xs < W)
    m[y0 + ys[ok], x0 + xs[ok]] = True
    return m, x0, y0


def backlit(a, sprite, cx, foot, body=rgb("0e071b"), rim=rgb("0cf1ff"), glow=rgb("0098dc"), eyes=True):
    """A figure against the light: its shape in `body`, a rim of the light round all of it, glowing eyes."""
    m, x0, y0 = mask_at(sprite, cx, foot)
    halo = sv.grow(sv.grow(m)) & ~m
    a[halo & (cv.BY < 0.5)] = glow
    a[m] = body
    a[m & sv.grow(~m)] = rim
    if eyes:
        glowing_eye(a, x0, y0)


def glowing_eye(a, x0, y0):
    """The kobold's eye lit up by the System, a trail of light off it; (x0, y0) his idle frame's top-left."""
    for ey, ex in EYE:
        a[y0 + ey, x0 + ex] = rgb("94fdff")
    a[y0 + 17, x0 + 38] = WHITE
    for k in range(1, 9):
        if cv.BY[y0 + 17, x0 + 38 + k] < 1 - k / 9:
            a[y0 + 17 + k // 4, x0 + 38 + k] = rgb("0cf1ff")


def slash_kobolds():
    """A hunter cuts through the pack."""
    a = cave()
    stand(a, cv.big(adventurer("knight_1", "attack", 2, 64)), 100, "noon", foot=CAVE_FEET)
    burst(a, 222, 166, 8, 18, fill=WHITE, core=rgb("94fdff"))
    cv.paste(a, np.rot90(kobold("red"), -1)[:, ::-1], 222, 186)
    cv.paste(a, np.rot90(kobold("green"), 1), 270, 160)
    cv.paste(a, np.rot90(kobold("green", "idle", 2), 2)[:, ::-1], 262, CAVE_FEET + 4)
    sfx(a, "SHHK!", 206, 113, bands=cv.CREAM_BANDS)
    bubble(a, ["Kobolds again?"], 124, 113, tail=(110, 124))
    bubble(a, ["They don't even", "drop anything."], 124, 134, tail=(110, 132))
    return a, (40, 110)


def rude():
    """The hunters gone, the pack on the floor, and one head coming up over a rock."""
    a = cave()
    cv.paste(a, np.rot90(kobold("green"), 1), 288, CAVE_FEET)
    cv.paste(a, np.rot90(kobold("red"), -1), 316, CAVE_FEET + 2)
    stand(a, cv.hero("idle", 0), 338, "noon", foot=CAVE_FEET + 18)
    front_rock(a)
    bubble(a, ["...rude."], 280, 118, tail=(336, 150))
    return a, (264, 110)


def notice():
    """Close on him, alone, as the first window opens in his face."""
    sx, sy = 40, 110
    a = cave()
    a[:] = snap(a * 0.55)
    x, y = sx + 74, sy + 4
    glow = ((cv.XX - (x + 60)) / 110) ** 2 + ((cv.YY - (y + 40)) / 70) ** 2
    cast(a, (glow < 1) & (cv.BY < 1 - glow), rgb("0069aa"), 0.35)
    head = cv.big(cv.head())
    hh, hw = head.shape[:2]
    cv.paste(a, head, 50, H)
    hm = np.zeros((H, W), bool)
    hm[H - hh:, 50 - hw // 2: 50 - hw // 2 + hw] = head[..., 3] > 0
    cast(a, hm & (cv.XX > 60) & ~(a == INK).all(-1) & (cv.BY < 0.5), rgb("0cf1ff"), 0.4)
    window(a, x, y, "NOTICE", ["You are the weakest", "creature in this world.", "", "You qualify",
                                "as a Player."])
    bubble(a, ["...as a", "WHAT?"], sx + 4, sy + 6, tail=(sx + 40, sy + 44))
    return a, (sx, sy)


def accept():
    """Will he? The window waits, a clock running down in it."""
    a = cave()
    a[:] = snap(a * 0.45)
    x, y = 236, 122
    glow = ((cv.XX - 294) / 110) ** 2 + ((cv.YY - 150) / 60) ** 2
    cast(a, (glow < 1) & (cv.BY < 1 - glow), rgb("0069aa"), 0.35)
    yes, no = window(a, x, y, "QUESTION", ["Will you accept?", "0:09"], buttons=("YES", "NO"))
    cv.cursor(a, *cv.HAND, (yes[0] + 4, yes[1] + 3))
    bubble(a, ["Does \"no\" have", "a timer too?"], 216, 182, tail=(212, 214))
    return a, (208, 110)


def registered():
    """Yes. The light comes for him."""
    a = np.zeros((H, W, 3), np.uint8)
    a[:] = rgb("0e071b")
    cv.beam(a, 30, 98, 0, cv.BEAMS["uncommon"], w=13)
    backlit(a, cv.hero("idle", 0), 30, 98)
    for x, y in ((8, 30), (54, 18), (6, 70), (58, 52), (50, 84)):
        cv.glint(a, x, y, rgb("94fdff"), arm=1)
    window(a, 46, 6, "PLAYER REGISTERED", ["Kobold, Lv. 1"])
    sfx(a, "VMMM", 22, 72, bands=cv.BLUE_BANDS)
    bubble(a, ["I feel...", "incredibly", "the same."], 116, 44, tail=(48, 34))
    return a, (0, 0)


def quest():
    """Morning, out in the open. One slime. The quest wants ten."""
    a = backdrop("grass", "plain", 2, "morning")
    for i, x in enumerate((236, 256, 276, 296, 246, 266, 286, 226, 306)):
        foot = FEET - (12 if i < 4 else 6 if i < 7 else 0)
        stand(a, slime("idle", i % 4), x, "morning", foot=foot)
        if i % 3 != 1:
            cv.pattern(a, ("kkk", "kwk", "kwk", "kwk", "kkk", "kwk", "kkk"), x - 1, foot - 23,
                       {"k": INK, "w": WHITE})
    stand(a, slime("idle", 0), 196, "morning")
    stand(a, cv.hero("idle", 0), 126, "morning")
    window(a, 296, 100, "QUEST", ["Defeat 10 enemies.", "Time limit: 0:30"], anchor=1)
    bubble(a, ["Ten?", "There's one."], 102, 100, tail=(130, 134))
    return a, (100, 96)


def loot():
    """The first one bursts, and things come out of it."""
    sx, sy = 70, 96
    a = backdrop("grass", "plain", 2, "morning")
    burst(a, sx + 122, 174, 7, 15)
    stand(a, slime("hurt", 1), sx + 122, "morning")
    stand(a, cv.hero("attack", 2), sx + 42, "morning")
    cv.beam(a, sx + 204, FEET, sy + 44, cv.BEAMS["rare"], w=1)
    sword = cv._to_e64(Image.open("../Assets/Gear/Iron Sword.png").convert("RGBA"))
    cv.paste(a, sword, sx + 204, 172)
    cv.coin(a, sx + 160, 166, 0)
    cv.coin(a, sx + 176, 156, 8)
    cv.glint(a, sx + 168, 150, rgb("ffeb57"), arm=1)
    window(a, sx + 222, sy + 4, "ITEM ACQUIRED", ["Iron Sword"], anchor=1)
    sfx(a, "WHACK!", sx + 86, sy + 50)
    bubble(a, ["They DROP", "things?!"], sx + 4, sy + 4, tail=(sx + 52, sy + 40))
    return a, (sx, sy)


def horizon():
    """Dawn on a rise: the fog, the white wall beyond it, and the System uneasy."""
    sx, sy = 238, 96
    a = _rgba(f"{AREA}sky/golden.png")[..., :3].copy()
    sv.ranges(a, 41, 166, 14, 26, rgb("92a1b9"), WHITE, slope=(1.6, 2.4))
    sv.hills(a, 43, 178, 6, rgb("424c6e"), rgb("657392"))
    fogged = a.copy()
    fog(fogged, sx + 50, seed=9)
    a[164:] = fogged[164:]
    glow = (((cv.XX - 336) / 14) ** 2 + ((cv.YY - 178) / 5) ** 2)
    cast(a, (glow < 1) & (cv.BY < 1 - glow), rgb("ea323c"), 0.6)
    a[(((cv.XX - 336) / 4) ** 2 + ((cv.YY - 178) / 1.6) ** 2) < 1] = rgb("891e2b")
    hill = ((cv.XX - (sx + 4)) / 76) ** 2 + ((cv.YY - (sy + 120)) / 34) ** 2 < 1
    a[sv.grow(hill) & ~hill] = INK
    a[hill] = rgb("33984b")
    a[hill & ~np.roll(hill, 2, axis=0)] = rgb("5ac54f")
    stand(a, cv.hero("idle", 0), sx + 26, "golden", foot=sy + 88)
    window(a, sx + 142, sy + 44, "WARNING", ["???"], tone=ALARM, glitch=(6, 16), anchor=1)
    bubble(a, ["Everything past", "that fog is mine."], sx + 4, sy + 4, tail=(sx + 38, sy + 38))
    return a, (sx, sy)


# ---------------------------------------------------------------- "Reborn": a knight dies to Gollux, wakes a kobold
# Page 1 his death and the System's rebirth, page 2 the kobold's first fights, two black pages, then the wall.

KNIGHT = "knight_2"  # the user's pick (2026-10-29): any hero would do; it pays nothing off later


def tilted(sprite, deg):
    im = Image.fromarray(sprite).rotate(deg, resample=Image.NEAREST, expand=True)
    return np.array(im.crop(im.getbbox()))


def solid(a, sprite, cx, foot, colour):
    """A figure as one flat colour inside its ink: how a blow lands on him (the user's red silhouette)."""
    m, _, _ = mask_at(sprite, cx, foot)
    a[sv.grow(m) & ~m] = INK
    a[m] = colour


def red_cave(dark=0.6):
    """The cave lit red from deeper in, where Gollux is."""
    a = cave()
    a[:] = snap(a * dark)
    cast(a, cv.BY < np.clip((cv.XX - 100) / 260, 0, 1), rgb("891e2b"), 0.45)
    return a


def gear(name):
    g = cv._to_e64(Image.open(f"../Assets/Gear/{name}.png").convert("RGBA"))
    return g[np.ix_(np.nonzero(g[..., 3].any(1))[0], np.nonzero(g[..., 3].any(0))[0])]


def descend():
    """A knight walks into the red-lit dark."""
    sx, sy = 20, 110
    a = red_cave()
    stand(a, adventurer(KNIGHT, "walk", 2, 85), sx + 40, "noon", foot=CAVE_FEET)
    window(a, sx + 108, sy + 6, "Lv. 87", anchor=1)
    return a, (sx, sy)


def smash():
    """...and through everything in it."""
    sx, sy = 120, 110
    a = red_cave()
    stand(a, adventurer(KNIGHT, "attack", 1, 85), sx + 42, "noon", foot=CAVE_FEET)
    burst(a, sx + 92, 170, 6, 14, fill=WHITE, core=rgb("f9e6cf"))
    cv.paste(a, tilted(cv.enemy("Skeleton Warrior", "hurt", 0), -35), sx + 104, 172)
    cv.paste(a, tilted(cv.enemy("Bat", "hurt", 0), 30), sx + 118, 142)
    cv.paste(a, tilted(cv.enemy("Rat", "idle", 0), 160), sx + 110, CAVE_FEET)
    sfx(a, "SMASH!", sx + 10, sy + 6)
    return a, (sx, sy)


def gollux():
    """Something in the red dark that does not care what level he is."""
    sx, sy = 236, 110
    a = red_cave(0.35)
    glow = ((cv.XX - (sx + 96)) / 90) ** 2 + ((cv.YY - 150) / 70) ** 2
    a[(glow < 1) & (cv.BY < (1 - glow) * 3)] = rgb("571c27")
    a[(glow < 0.6) & (cv.BY < (0.6 - glow) * 4)] = rgb("891e2b")
    a[(glow < 0.3) & (cv.BY < (0.3 - glow) * 6)] = rgb("c42430")
    g = cv.big(cv.enemy("Gollux", "attack", 6))
    cx, foot = sx + 104, CAVE_FEET + 20
    backlit(a, g, cx, foot, body=rgb("0e071b"), rim=rgb("f5555d"), glow=rgb("891e2b"), eyes=False)
    _, x0, y0 = mask_at(g, cx, foot)
    for ex, ey in ((46, 50), (60, 48)):  # the pack draws him no face; these are the comic's
        a[y0 + ey: y0 + ey + 2, x0 + ex: x0 + ex + 3] = rgb("ffeb57")
    burst(a, sx + 36, 166, 6, 15, fill=WHITE, core=rgb("f9e6cf"))
    solid(a, tilted(adventurer(KNIGHT, "idle", 0, 85), 25), sx + 32, 186, rgb("ea323c"))
    sfx(a, "KRAK!", sx + 8, sy + 6, bands=(WHITE, rgb("f68187"), rgb("ea323c")))
    return a, (sx, sy)


def black():
    a = np.zeros((H, W, 3), np.uint8)
    a[:] = rgb("0e071b")
    return a


def died():
    """The System, in the dark after."""
    a = black()
    window(a, 54, 10, "YOU HAVE DIED", tone=ALARM, anchor=0.5)
    yes, _ = window(a, 54, 36, "QUESTION", ["Be reborn?", "0:09"], buttons=("YES", "NO"), anchor=0.5)
    cv.cursor(a, *cv.HAND, (yes[0] + 4, yes[1] + 3))
    return a, (0, 0)


def reborn():
    """Yes. The light gives him a body back, and its shape is wrong."""
    a = black()
    cv.beam(a, 30, 98, 0, cv.BEAMS["uncommon"], w=13)
    backlit(a, cv.hero("idle", 0), 30, 98)
    for x, y in ((8, 30), (54, 22), (6, 70), (58, 52)):
        cv.glint(a, x, y, rgb("94fdff"), arm=1)
    window(a, 128, 6, "REBORN", ["Kobold, Lv. 1"], anchor=1)
    sfx(a, "VMM", 58, 70, bands=cv.BLUE_BANDS)
    return a, (0, 0)


def shock():
    """He sees what he is now."""
    a = black()
    a[:] = rgb("03193f")
    ang = np.arctan2(cv.YY - 64, cv.XX - 54)
    far = np.hypot(cv.XX - 54, cv.YY - 64) > 34
    a[far & (np.sin(ang * 22) > 0.8)] = rgb("0069aa")
    a[far & (np.sin(ang * 22) > 0.96)] = rgb("0098dc")
    cv.paste(a, cv.big(cv.head()), 54, 104)
    for x, y in ((100, 34), (112, 50)):
        cv.pattern(a, ("..k..", ".kwk.", "kwwbk", "kwbbk", ".kkk."), x, y, {"k": INK, "w": WHITE, "b": rgb("94fdff")},
                   k=2)
    sfx(a, "!?", 92, 6)
    return a, (0, 0)


def health(a, x, y, w, left):
    a[y: y + 5, x: x + w] = INK
    a[y + 1: y + 4, x + 1: x + w - 1] = rgb("571c27")
    a[y + 1: y + 4, x + 1: x + 1 + left] = rgb("ea323c")
    a[y + 1, x + 1: x + 1 + left] = rgb("f5555d")


def taps():
    """The kobold's blows: a slime shrugs them off, one after another."""
    sx, sy = 96, 96
    a = backdrop("grass", "plain", 2, "morning")
    stand(a, cv.hero("attack", 2), sx + 52, "morning")
    stand(a, slime("idle", 0), sx + 132, "morning")
    health(a, sx + 118, FEET - 24, 28, 25)
    for x, y in ((104, 48), (138, 34), (158, 56), (118, 20), (152, 8)):
        sfx(a, "TAP", sx + x, sy + y, k=1, bands=cv.CREAM_BANDS)
    bubble(a, ["I need to get", "stronger."], sx + 4, sy + 4, tail=(sx + 58, sy + 34))
    return a, (sx, sy)


def broken():
    """His first find."""
    sx, sy = 96, 96
    a = backdrop("grass", "plain", 2, "morning")
    stand(a, cv.hero("idle", 0), sx + 40, "morning")
    cv.beam(a, sx + 128, FEET, sy + 50, cv.BEAMS["common"], w=1)
    cv.paste(a, gear("Broken Sword"), sx + 128, FEET - 2)
    window(a, sx + 180, sy + 4, "ITEM ACQUIRED", ["Broken Sword"], anchor=1)
    bubble(a, ["I had", "a MACE."], sx + 4, sy + 4, tail=(sx + 44, sy + 38))
    return a, (sx, sy)


def haul():
    """Then the next one, and the next: gold, beams, gear."""
    sx, sy = 96, 96
    a = backdrop("grass", "plain", 4, "noon")
    cv.beam(a, sx + 148, FEET, sy + 40, cv.BEAMS["rare"], w=1)
    cv.beam(a, sx + 170, FEET, sy + 24, cv.BEAMS["unique"], w=2)
    burst(a, sx + 98, 168, 6, 13)
    stand(a, cv.enemy("Goblin", "hurt", 0), sx + 98, "noon")
    stand(a, cv.hero("attack", 2), sx + 40, "noon")
    for i, (x, y) in enumerate(((112, 50), (124, 38), (138, 48), (130, 60))):
        cv.coin(a, sx + x, sy + y, (0, 8, 4, 2)[i])
    window(a, sx + 180, sy + 4, "+48 gold", anchor=1)
    return a, (sx, sy)


def level_up():
    """It pays: the world goes dark round him, the System's light bursts out of him, and he levels up."""
    sx, sy, w = 96, 96, 188
    cx, cy = sx + w // 2, FEET - 30
    a = backdrop("grass", "plain", 2, "golden")
    a[:] = snap(a * 0.35)
    cast(a, cv.YY >= 0, rgb("00396d"), 0.35)
    ang = np.arctan2(cv.YY - cy, cv.XX - cx)
    d = np.hypot((cv.XX - cx) / 1.4, cv.YY - cy)
    sky = cv.YY < FEET
    a[sky & (np.sin(ang * 16) > 0.55)] = rgb("0069aa")
    a[sky & (np.sin(ang * 16) > 0.85)] = rgb("0098dc")
    a[sky & (np.sin(ang * 16 + 1.3) > 0.97) & (d > 30)] = rgb("94fdff")
    a[(d < 40) & (cv.BY < (1 - d / 40) * 1.6)] = rgb("94fdff")
    a[(d < 24) & (cv.BY < (1 - d / 24) * 1.8)] = WHITE
    cv.beam(a, cx, FEET, sy - 10, cv.BEAMS["uncommon"], w=16)
    for r, tone in ((52, "0cf1ff"), (36, "94fdff"), (22, "ffffff")):
        ring = ((cv.XX - cx) / r) ** 2 + ((cv.YY - FEET) / (r / 9)) ** 2
        a[(np.abs(ring - 1) < 0.12) & (cv.YY >= FEET - 3)] = rgb(tone)
    hero = cv.hero("idle", 0)
    stand(a, hero, cx, "noon")
    m, _, _ = mask_at(hero, cx, FEET)
    a[sv.grow(m) & ~m & (cv.BY < 0.6)] = rgb("94fdff")
    rng = random.Random(12)
    for _ in range(26):
        x, y = cx + rng.randint(-70, 70), rng.randint(sy + 4, FEET - 4)
        if abs(x - cx) > 20:
            cv.glint(a, x, y, rng.choice((WHITE, rgb("94fdff"), rgb("0cf1ff"))), arm=rng.choice((0, 1, 1, 2)))
    tw = cv.text_mask("LEVEL UP!", cv.PIXELLARI).shape[1] * 2
    sfx(a, "LEVEL UP!", sx + (w - tw) // 2, sy + 5, bands=(WHITE, rgb("94fdff"), rgb("0cf1ff")),
        extrude=rgb("0069aa"))
    return a, (sx, sy)


def caption(text, k):
    def scene():
        a = np.zeros((H, W, 3), np.uint8)
        a[:] = INK
        m = np.kron(cv.text_mask(text, cv.PIXELLARI), np.ones((k, k), bool))
        cv.stamp(a, m, (W - m.shape[1]) // 2, (H - m.shape[0]) // 2, WHITE)
        return a, (0, 0)
    return scene


def the_wall(seed=7, layout=2):
    """The ice wall at night, drawn as the ice backdrops are: its crest is above the page all the way across (sky
    in the corner over it read as a black triangle, the user said) and its face runs away to the right, fluted and
    banded (the user's references: a glacier face and a wall of ice blocks); the kobold squares up to it, small."""
    rng = random.Random(seed)
    near, base = 150, FEET + 4
    t = np.clip((cv.XX - near) / (W - near), 0, 1)
    u = np.log1p(4 * t) / np.log(5)  # along the face: the far end crowds together
    crest = (sv.noise2(seed, W, 1, 16)[0] - 0.5) * 12
    top = -60 + t * 30 + crest[None, :]
    edge = near + (sv.noise2(seed + 1, 1, H, 10)[:, 0] - 0.5) * 8
    face = (cv.XX >= edge[:, None]) & (cv.YY >= top) & (cv.YY < base)
    lands = len(glob.glob(f"{AREA}land/ice_{layout}_*.png"))

    def wall(a, band):
        if band != lands:
            return
        # flutes: noise stretched tall, so each runs a long way down the face
        g = sv.noise2(seed + 2, 300, 28, 4)
        r = cv.YY / H * 27
        lo = np.floor(r).astype(int)
        col = (u * 299).astype(int)
        streak = g[lo, col] * (1 - (r - lo)) + g[np.minimum(lo + 1, 27), col] * (r - lo)
        down = np.clip((cv.YY - top) / np.maximum(1, base - top), 0, 1)
        v = 0.7 * streak + 0.45 * (1 - down) - 0.1 * t
        for cut, tone in ((-9, "0069aa"), (0.36, "0098dc"), (0.58, "94fdff"), (0.8, "ffffff")):
            a[face & (v >= cut)] = rgb(tone)
        a[face & (np.abs(streak - 0.5) < 0.012) & (down > 0.08)] = rgb("00396d")
        seg = sv.noise2(seed + 6, W, 4, 10)
        for i, fr in enumerate((0.2, 0.42, 0.64)):
            row = (top + fr * (base - top)).astype(int)
            a[face & (cv.YY == row) & (seg[i][None, :] > 0.35)] = rgb("0069aa")
            a[face & (cv.YY == row - 1) & (seg[i][None, :] > 0.55)] = WHITE
        cap = face & (cv.YY < top + 3 + 2 * sv.noise2(seed + 3, W, 1, 6)[0][None, :])
        a[cap] = WHITE
        a[face & (cv.XX < edge[:, None] + 2)] = WHITE
        a[sv.grow(face) & ~face & (cv.YY < base - 2)] = INK

    a = backdrop("ice", "plain", layout, "night", after=wall)
    n = sv.noise2(seed + 5, W, H, 14)
    mist = np.clip(1 - np.abs(cv.YY - (base - 6)) / 22, 0, 1) * (0.35 + 0.65 * n) * np.clip((cv.XX - 40) / 80, 0, 1)
    a[cv.BY < mist * 0.8] = rgb("c7cfdd")
    a[cv.BY < mist * 0.45] = WHITE
    # half his size, against the wall's light: small beside it, squared up to it (the user's ask)
    hero = cv.hero("attack", 0)
    small = np.array(Image.fromarray(hero[..., 3]).resize((hero.shape[1] // 2, hero.shape[0] // 2), Image.BOX)) > 100
    sh = np.zeros(small.shape + (4,), np.uint8)
    sh[small] = (*rgb("0e071b"), 255)
    m, x0, y0 = mask_at(sh, 128, FEET)
    a[m] = rgb("0e071b")
    a[m & ~np.roll(m, -1, axis=1)] = rgb("94fdff")
    a[y0 + 9, x0 + 18] = rgb("0cf1ff")
    for _ in range(110):
        fx, fy = rng.randrange(W - 1), rng.randrange(H - 1)
        a[fy, fx] = WHITE
        if rng.random() < 0.3:
            a[fy + 1, fx + 1] = rgb("c7cfdd")
    return a, (0, 0)


FULL = ((0, 0, W, H),)
PAGES_B = (((4, 4, 112, 102), (120, 4, 132, 102), (256, 4, 124, 102),
            (4, 110, 108, 102), (116, 110, 132, 102), (252, 110, 128, 102)),
           ((4, 4, 188, 102), (196, 4, 184, 102), (4, 110, 184, 102), (192, 110, 188, 102)),
           FULL, FULL, FULL)
SCENES_B = ((descend, smash, gollux, died, reborn, shock), (taps, broken, haul, level_up),
            (caption("What's that in the distance?", 1),), (caption("It's HUGE!", 2),), (the_wall,))


# (x, y, w, h) on each page, in reading order.
PAGES_A =(((4, 4, 252, 102), (260, 4, 120, 102), (4, 110, 200, 102), (208, 110, 172, 102)),
           ((4, 4, 176, 102), (184, 4, 196, 102), (4, 110, 226, 102), (234, 110, 146, 102)))
SCENES_A = ((slash_kobolds, rude, notice, accept), (registered, quest, loot, horizon))
STORIES = {"hoard": ((PANELS,), (SCENES,)), "selected": (PAGES_A, SCENES_A), "reborn": (PAGES_B, SCENES_B)}


def page(panels=PANELS, scenes=SCENES, upto=None):
    """The page with its first `upto` panels drawn in, the rest blank paper -- how it stands after
    that many clicks."""
    p = np.zeros((H, W, 3), np.uint8)
    p[:] = PAPER
    for (x, y, w, h), scene in list(zip(panels, scenes))[:upto]:
        a, (sx, sy) = scene()
        p[y: y + h, x: x + w] = a[sy: sy + h, sx: sx + w]
        if w < W:
            p[y - 1, x - 1: x + w + 1] = p[y + h, x - 1: x + w + 1] = INK
            p[y - 1: y + h + 1, x - 1] = p[y - 1: y + h + 1, x + w] = INK
    return p


# ---------------------------------------------------------------- on a phone
# A 1080 x 2340 phone (the 360 x 780 of test_ui_pages at ui_scale 3). Held upright a page of 384 would show only at
# 2x, so the panels go down a column as a webtoon's do, every one at the same whole zoom; on its side it is a page.
PHONE = (1080, 2340)
STRIP_ZOOM = 5


def _blow(a, k):
    return np.kron(a, np.ones((k, k, 1), np.uint8))


def strip(panels, scenes, upto, top=24, gap=6, foot=12):
    """Held upright after `upto` taps: the panels so far down a column, zig-zagging, scrolled to the newest."""
    cw, ch = PHONE[0] // STRIP_ZOOM, PHONE[1] // STRIP_ZOOM
    cuts = []
    for i, ((_, _, w, h), scene) in enumerate(list(zip(panels, scenes))[:upto]):
        a, (sx, sy) = scene()
        cuts.append((a[sy: sy + h, sx: sx + w], 6 if i % 2 == 0 else cw - 6 - w))
    s = np.zeros((ch, cw, 3), np.uint8)
    s[:] = PAPER
    y = top - max(0, top + sum(c.shape[0] + gap for c, _ in cuts) - gap - (ch - foot))
    for c, x in cuts:
        h, w = c.shape[:2]
        for yy in range(max(0, y - 1), min(ch, y + h + 1)):
            row = yy - y
            s[yy, x - 1] = s[yy, x + w] = INK
            s[yy, x: x + w] = c[row] if 0 <= row < h else INK
        y += h + gap
    return _blow(s, STRIP_ZOOM)


def black_page(text, k):
    """A caption page held upright, at the strip's zoom."""
    cw, ch = PHONE[0] // STRIP_ZOOM, PHONE[1] // STRIP_ZOOM
    s = np.zeros((ch, cw, 3), np.uint8)
    s[:] = INK
    m = np.kron(cv.text_mask(text, cv.PIXELLARI), np.ones((k, k), bool))
    ys, xs = np.nonzero(m)
    s[ys + (ch - m.shape[0]) // 2, xs + (cw - m.shape[1]) // 2] = WHITE
    return _blow(s, STRIP_ZOOM)


## The column of the wall splash a window held upright shows, about the kobold and the wall's near edge: what
## `Scenes/UI/comic.gd` centres there (comic.json's "tall", written by build_comic.py).
TALL_CENTRE = 144


def tall_splash():
    """The wall splash held upright: a column of it, its full height filling the screen at twice the strip's zoom."""
    a, _ = the_wall()
    k = PHONE[1] // H
    half = PHONE[0] // k // 2
    cut = a[:, TALL_CENTRE - half: TALL_CENTRE + half]
    s = np.zeros((PHONE[1], PHONE[0], 3), np.uint8)
    s[:] = INK
    s[(PHONE[1] - H * k) // 2:][: H * k] = _blow(cut, k)
    return s


def on_side(panels, scenes):
    """On its side: the page as on a monitor, at the largest whole zoom."""
    k = min(PHONE[1] // W, PHONE[0] // H)
    p = _blow(page(panels, scenes), k)
    s = np.zeros((PHONE[0], PHONE[1], 3), np.uint8)
    s[:] = PAPER
    y, x = (PHONE[0] - p.shape[0]) // 2, (PHONE[1] - p.shape[1]) // 2
    s[y: y + p.shape[0], x: x + p.shape[1]] = p
    return s


def phones(tag):
    """The reborn story on a phone, in qa/: each screen at the phone's own pixels, and all of them in a row."""
    (p1, p2, *_), (s1, s2, *_) = PAGES_B, SCENES_B
    screens = [strip(p1, s1, 4), strip(p1, s1, 6), strip(p2, s2, 4), black_page("It's HUGE!", 2), tall_splash()]
    bezel = 40
    row = np.zeros((PHONE[1] + 2 * bezel, len(screens) * (PHONE[0] + 2 * bezel + 60), 3), np.uint8)
    row[:] = rgb("3d3d3d")
    for i, s in enumerate(screens):
        Image.fromarray(s).save(f"qa/comic_{tag}_phone{i + 1}.png")
        x = i * (PHONE[0] + 2 * bezel + 60) + 30
        row[:, x: x + PHONE[0] + 2 * bezel] = INK
        row[bezel: bezel + PHONE[1], x + bezel: x + bezel + PHONE[0]] = s
    small = (row.shape[1] // 3, row.shape[0] // 3)
    Image.fromarray(row).resize(small, Image.LANCZOS).save(f"qa/comic_{tag}_phones.png")
    Image.fromarray(on_side(p1, s1)).save(f"qa/comic_{tag}_side.png")
    print(f"wrote qa/comic_{tag}_phones.png, _phone1..{len(screens)}.png and _side.png")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tag", nargs="?", default="m1")
    ap.add_argument("--story", choices=STORIES, default="hoard")
    ap.add_argument("--phone", action="store_true", help="the reborn story on a phone instead")
    args = ap.parse_args()
    os.makedirs("qa", exist_ok=True)
    if args.phone:
        phones(args.tag)
        return
    out = f"qa/comic_{args.tag}.png"
    pages = np.vstack([page(p, s) for p, s in zip(*STORIES[args.story])])
    Image.fromarray(pages).resize((W * 3, pages.shape[0] * 3), Image.NEAREST).save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
