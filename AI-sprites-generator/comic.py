"""The intro comic: one page of five panels the game shows on a first run, before the map -- drawn from
the game's own backdrops and sprites at one fighter pixel a pixel, on the battle backdrops' 384x216
grid, so the page is a fight's size and is shown at the same whole zoom.

`python comic.py [tag]` writes qa/comic_<tag>.png (m1 without one) at 3x, the default window's size.
"""
import argparse
import os

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


def sfx(a, text, x, y, k=2, bands=cv.GOLD_BANDS):
    """A sound in the logo's lettering, `k` times Pixellari's size."""
    m = np.kron(cv.text_mask(text, cv.PIXELLARI), np.ones((k, k), bool))
    cv.lettering(a, m, x, y, deep=k + 1, thick=1, bands=bands)


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


def page(upto=len(SCENES)):
    """The page with its first `upto` panels drawn in, the rest blank paper -- how it stands after
    that many clicks."""
    p = np.zeros((H, W, 3), np.uint8)
    p[:] = PAPER
    for (x, y, w, h), scene in list(zip(PANELS, SCENES))[:upto]:
        a, (sx, sy) = scene()
        p[y: y + h, x: x + w] = a[sy: sy + h, sx: sx + w]
        p[y - 1, x - 1: x + w + 1] = p[y + h, x - 1: x + w + 1] = INK
        p[y - 1: y + h + 1, x - 1] = p[y - 1: y + h + 1, x + w] = INK
    return p


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tag", nargs="?", default="m1")
    tag = ap.parse_args().tag
    os.makedirs("qa", exist_ok=True)
    out = f"qa/comic_{tag}.png"
    Image.fromarray(page()).resize((W * 3, H * 3), Image.NEAREST).save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
