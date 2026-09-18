"""The item bases' icons that no bought pack draws, generated in the look of the pack that draws the rest.

The gear the game shipped with is cut from "Pixel Art Icon Pack - RPG" by tools/ui_kit.py, and the
user picked that pack's look for all sixty-nine bases. It draws about twenty pieces of gear, so the
other fifty-odd are drawn here. Like slimes.py and hpbar.py this skips Aseprite and the hex atlas:
the icons are ordinary 32x32 RGBA sprites for Assets/Gear/, and hexlib.PALETTE is not used -- the
colours are the pack's own, measured off it, because the thing these have to match is the pack.

What was measured off the pack (its Equipment and Weapon & Tool icons, 29 of them):

  * It is not limited-palette pixel art. An icon holds 235 to 557 distinct colours (Iron Sword 235,
    Leather Boot 379, Iron Helmet 557): painted large with soft gradients and reduced to 32 px. So
    that is how these are made too -- every part is a shape rendered at SUPER times the size with
    smooth shading, averaged down, and cut to a hard alpha. Nothing is dithered, and nothing is
    anti-aliased to transparency: a pixel is in or out.
  * The art is 26 to 28 px on the 32 square and wears a pure white 1 px border, 28 to 30 with it. A
    drawing here keeps to 2 .. 30 and is given the same white ring, so tools/ui_kit.py takes the
    border off a generated icon and a cut one with one function (`_outlined`) and they cannot end
    in two different outlines.
  * Light falls from above and a little from the right on armour (lightness rises about 0.01 a pixel
    rightward and 0.005 upward across a helmet or a cuirass); a blade is two facets, the upper-left
    one light and the lower-right one a step darker, with a pale line down the edge.
  * Every material is warm. Iron is a brown-grey (hue 0.08-0.10, saturation 0.18-0.28), steel is
    the same hue but paler and runs to cream, cloth is a beige. Each ramp turns from red-brown in
    the dark (hue about 0.07) to yellow in the light (about 0.11) and loses saturation as it climbs
    -- gold aside, which keeps 0.9 all the way. RAMPS holds them, twelve stops each, medians of the
    pack's own pixels binned by lightness between the 3rd and 99.5th percentile:
      wood     Wooden Armor, Wood Log, Wooden Plank, Wooden Staff
      leather  Leather Helmet, Leather Boot, Belt, Leather
      iron     Iron Helmet, Iron Armor, Iron Boot, the Hammer's head
      steel    Silver Sword and Iron Sword blades, Silver Ingot, Silver Coin
      gold     Golden Sword's hilt, Golden Ingot, Golden Coin, Golden Key
      copper   Copper Ingot, Copper Coin          cloth  Wizard Hat, Fabric, Wool
      bone     Bone, Skull                         dark   Obsidian, Coal
      ruby, sapphire, emerald, topaz               the four Cut gems
      flame    the Torch's fire
    The pack has no dyed cloth and no dark leather, so TINTS makes those from a measured ramp by
    moving its hue and scaling its saturation and lightness, the shading kept.
  * Parts are told apart by a dark seam where one overlaps another, not by a line round each, and
    small fittings (a rivet, a buckle) are a light dot with a dark one under it to the right.

An icon is a list of parts painted back to front on a Canvas. A part is a mask (a polygon, a
capsule, an ellipse -- drawn at SUPER scale, in 32 px units) plus a ramp and a shading: `volume`
rounds any mask off as if it were a cushion lit from LIGHT, `facet` is a flat plane with a slope
across it. A family shares its construction and a higher tier adds parts to it -- a guard, a
pommel, a fuller, a gem, studs, trim -- which is what "more intricate" means here.

Run `python qa.py gear <tag>` to check them and look at them among the pack's own. Nothing is written
from here: tools/ui_kit.py imports gear.py, outlines what it draws and writes Assets/Gear.
"""
import colorsys
import math
import zlib

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SIDE = 32
SUPER = 8
HI = SIDE * SUPER
## Where the light comes from, as (x, y) on the canvas with y down: above, a little to the right.
LIGHT = (0.35, -0.94)
## How strong the brush blotches are, as a share of a pixel's value at one standard deviation.
MOTTLE = 0.05

RAMPS = {
    "wood": "2a0202 412510 573518 674327 765132 86633f 96714c a58058 b59264 c0a373 ccb181 d7c195",
    "leather": "3f2415 563521 63402a 734d33 825a3d 8d6647 9b7453 a7805d b48e6b bc9c77 c0aa8b c7b9a1",
    "iron": "3b2719 4b392a 594839 675745 746453 837360 91816e 9e917c ab9d88 b6ac98 c2b8a8 cdc4b3",
    "steel": "352a1d 5e4934 66523b 7a644e 8c7659 9c8a6c ad9d82 bbad92 c7bca4 d7cbb5 e8dec6 f4eedb",
    "gold": "482b09 7f4907 905514 a46820 b8812e c69a3e d5b151 e1c267 ead07a f4df94 fcefb0 f3ecd3",
    "copper": "46220c 693414 773d23 8b4826 9d562f a9663c b4784a c78f56 cea06a d8af78 e7bd83 f2cf93",
    "cloth": "3c2915 5a3f24 69543c 7a6247 8a755c 9a866c ab997f b8aa90 c6baa5 d5cab6 e0d9c8 eee8db",
    "bone": "35291c 5e3f29 684e37 755e47 886d55 937d64 a18d77 ae9f8b b9ae9e c4bcad d2cdc2 e2dfd6",
    "ruby": "510f0e 681916 812621 8f3833 a4433d b35752 c06d67 cb7d77 d68e88 e0aba4 edc9c6 f7e1df",
    "sapphire": "090f49 0e1768 131e90 1f2ea0 2e41b3 3b50c0 5c71c3 7b8bc7 8d9dd2 9fb1e1 bac5e6 cdd7ef",
    "emerald": "1c3b07 325c15 45721e 567b36 638b44 779958 8fae65 a0bb79 aec68a bfd29c d1e0b6 d9e6bc",
    "topaz": "4e2704 733e07 98550b 9f6019 b0762d bc883d c49858 d1ac69 d9ba7d e2c795 e9d4b0 efdfc1",
    "dark": "2d2221 42332c 423d53 504c5f 605c74 6a697e 797594 87859d 999bad a8a8bc b5b8c6 c9d2dc",
    "flame": "b85a05 c86a06 d67b07 d67b07 da8309 df8b0a e69b0d eba710 f1bc13 f5cc22 f9d84a fdf0a0",
}
## name -> (the measured ramp it is made from, hue or None to keep it, saturation x, lightness x)
TINTS = {
    "hide": ("leather", None, 0.7, 1.12),
    "studded": ("leather", 0.055, 1.0, 0.8),
    "shadow": ("leather", 0.72, 0.55, 0.55),
    "ranger": ("leather", 0.25, 0.8, 0.85),
    "linen": ("cloth", None, 0.8, 1.0),
    "silk": ("cloth", 0.6, 1.5, 0.9),
    "sage": ("cloth", 0.33, 1.2, 0.8),
    "archmage": ("cloth", 0.77, 1.4, 0.72),
    "darkiron": ("iron", None, 0.8, 0.72),
    "bronze": ("copper", 0.09, 0.85, 0.9),
    "jade": ("emerald", 0.4, 0.8, 1.0),
    "ember": ("flame", 0.045, 1.0, 0.92),
    # For the unique icons.
    "blood": ("iron", 0.0, 2.6, 0.8),
    "night": ("iron", 0.68, 0.6, 0.42),
    "violet": ("sapphire", 0.78, 0.9, 0.95),
    "glass": ("sapphire", 0.54, 0.45, 1.3),
    "frost": ("steel", 0.57, 0.9, 1.0),
    "bluedye": ("leather", 0.6, 1.3, 0.85),
}


def _ramp(name):
    """A ramp as a 12x3 float array, darkest first."""
    if name in TINTS:
        source, hue, sat_mul, light_mul = TINTS[name]
        out = []
        for r, g, b in _ramp(source) / 255.0:
            h, l, s = colorsys.rgb_to_hls(r, g, b)
            out.append(colorsys.hls_to_rgb(h if hue is None else hue, min(l * light_mul, 0.95),
                                           min(s * sat_mul, 1.0)))
        return np.array(out) * 255.0
    return np.array([[int(c[i:i + 2], 16) for i in (0, 2, 4)] for c in RAMPS[name].split()], float)


# ---------------------------------------------------------------- masks, in 32 px units

def _mask(draw_it):
    image = Image.new("L", (HI, HI), 0)
    draw_it(ImageDraw.Draw(image))
    return np.asarray(image, float) / 255.0


def _up(points):
    return [(x * SUPER, y * SUPER) for x, y in points]


def poly(*points):
    return _mask(lambda d: d.polygon(_up(points), fill=255))


def ellipse(cx, cy, rx, ry=None):
    ry = rx if ry is None else ry
    return _mask(lambda d: d.ellipse(_up([(cx - rx, cy - ry), (cx + rx, cy + ry)]), fill=255))


def capsule(a, b, width, width_b=None):
    """A thick line with round ends; `width_b` tapers it."""
    width_b = width if width_b is None else width_b
    (ax, ay), (bx, by) = a, b
    length = math.hypot(bx - ax, by - ay) or 1.0
    nx, ny = (ay - by) / length, (bx - ax) / length
    body = poly((ax + nx * width / 2, ay + ny * width / 2), (bx + nx * width_b / 2, by + ny * width_b / 2),
                (bx - nx * width_b / 2, by - ny * width_b / 2), (ax - nx * width / 2, ay - ny * width / 2))
    return np.maximum(body, np.maximum(ellipse(ax, ay, width / 2), ellipse(bx, by, width_b / 2)))


def curve(points, width):
    """A thick line through several points."""
    out = np.zeros((HI, HI))
    for a, b in zip(points, points[1:]):
        out = np.maximum(out, capsule(a, b, width))
    return out


def ring(cx, cy, r_out, r_in, ry_scale=1.0):
    return np.clip(ellipse(cx, cy, r_out, r_out * ry_scale) - ellipse(cx, cy, r_in, r_in * ry_scale), 0, 1)


class Frame:
    """A slanted object's own axes: `at(along, across)` is a canvas point. Weapons lie on the pack's
    diagonal, grip at the lower left and point at the upper right."""

    def __init__(self, origin, angle=-45.0, narrow=1.0):
        """`narrow` foreshortens the across axis: a broad thing turned partly away from us."""
        self.origin = origin
        turn = math.radians(angle)
        self.u = (math.cos(turn), math.sin(turn))
        self.v = (-math.sin(turn) * narrow, math.cos(turn) * narrow)

    def at(self, along, across=0.0):
        return (self.origin[0] + self.u[0] * along + self.v[0] * across,
                self.origin[1] + self.u[1] * along + self.v[1] * across)

    def poly(self, *pairs):
        return poly(*[self.at(a, b) for a, b in pairs])

    def capsule(self, a, b, width, width_b=None):
        return capsule(self.at(*a), self.at(*b), width, width_b)

    def ellipse(self, along, across, r):
        return ellipse(*self.at(along, across), r)


# ---------------------------------------------------------------- shading, 0 (dark) .. 1 (light)

def _blur(field, radius):
    image = Image.fromarray((np.clip(field, 0, 1) * 255).astype(np.uint8))
    return np.asarray(image.filter(ImageFilter.GaussianBlur(radius * SUPER)), float) / 255.0


def volume(mask, mid=0.55, relief=0.3, roundness=1.6, light=LIGHT):
    """The mask rounded off like a cushion and lit: its blurred self is the height, and the slope of
    that towards the light is what lifts or drops the tone. Flat ground in the middle sits at `mid`."""
    height = _blur(mask, roundness)
    gy, gx = np.gradient(height)
    slope = -(gx * light[0] + gy * light[1]) * SUPER * roundness
    return np.clip(mid + relief * slope * 2.2, 0.0, 1.0)


def facet(mid, slope=0.0, direction=LIGHT):
    """A flat plane at `mid`, lighter towards `direction` by `slope` a pixel."""
    ys, xs = np.mgrid[0:HI, 0:HI] / float(SUPER)
    return np.clip(mid + slope * ((xs - 16) * direction[0] + (ys - 16) * direction[1]), 0.0, 1.0)


# ---------------------------------------------------------------- the canvas

class Canvas:
    def __init__(self):
        self.rgb = np.zeros((HI, HI, 3))
        self.cover = np.zeros((HI, HI))

    def paint(self, mask, ramp, shade=None, seam=0.55, seam_width=0.55):
        """One part over what is there. `seam` darkens a thin rim of what it overlaps, which is how
        the pack parts one piece from another; 1.0 for none."""
        mask = np.clip(mask, 0, 1)
        if shade is None:
            shade = volume(mask)
        if seam < 1.0:
            rim = np.clip(_blur(mask, seam_width) * 2.2, 0, 1) * (1 - mask)
            self.rgb *= (1 - rim * (1 - seam))[..., None]
        stops = _ramp(ramp) if isinstance(ramp, str) else ramp
        at = np.clip(shade, 0, 1) * (len(stops) - 1)
        low = np.floor(at).astype(int)
        high = np.minimum(low + 1, len(stops) - 1)
        colour = stops[low] + (stops[high] - stops[low]) * (at - low)[..., None]
        self.rgb = self.rgb * (1 - mask[..., None]) + colour * mask[..., None]
        self.cover = np.maximum(self.cover, mask)

    def shade(self, mask, factor):
        """What is there, darker (or lighter) under `mask`: a groove, a fold, a glint."""
        mask = np.clip(mask, 0, 1) * self.cover
        if factor <= 1.0:
            self.rgb *= (1 - mask * (1 - factor))[..., None]
        else:
            self.rgb += (255.0 - self.rgb) * (mask * (factor - 1.0))[..., None]

    def erase(self, mask):
        self.cover = self.cover * (1 - np.clip(mask, 0, 1))

    def turn(self, degrees, centre=(16.0, 16.0)):
        """The whole painting turned clockwise about `centre`, at SUPER scale and before it is
        reduced, so nothing is resampled at the size it is seen at. A thing built square to the
        canvas looks built; the pack leans everything a little."""
        at = (centre[0] * SUPER, centre[1] * SUPER)

        def turned(field):
            image = Image.fromarray(field.astype(np.float32), "F")
            return np.asarray(image.rotate(-degrees, Image.BICUBIC, center=at), float)
        self.rgb = np.clip(np.dstack([turned(self.rgb[..., k]) for k in range(3)]), 0, 255)
        self.cover = np.clip(turned(self.cover), 0, 1)

    def icon(self, name):
        """Down to 32 px: each pixel the mean of the painted part of its block, in if half of it is
        painted. Then the pack's grain -- a percent or two of noise, seeded by the name so a build is
        the same twice -- and the pack's white border."""
        # (The blotches above and the grain below are both drawn from the one seeded generator.)
        # The pack's surfaces are not clean: they are painted, and the brush shows as blotches a
        # pixel or two across, a few percent lighter or darker. Smooth noise, laid on before the
        # reduction so it falls across pixels rather than on them.
        rng = np.random.default_rng(zlib.crc32(name.encode()))
        blotch = np.asarray(Image.fromarray(rng.integers(0, 256, (HI // 4, HI // 4), dtype=np.uint8))
                            .resize((HI, HI), Image.BICUBIC).filter(ImageFilter.GaussianBlur(SUPER * 0.6)), float)
        blotch = (blotch - blotch.mean()) / (blotch.std() + 1e-6)
        self.rgb = np.clip(self.rgb * (1.0 + MOTTLE * blotch)[..., None], 0, 255)
        cover = self.cover.reshape(SIDE, SUPER, SIDE, SUPER)
        rgb = (self.rgb.reshape(SIDE, SUPER, SIDE, SUPER, 3) * cover[..., None]).sum((1, 3))
        amount = cover.sum((1, 3))
        rgb /= np.maximum(amount, 1e-6)[..., None]
        inside = amount >= SUPER * SUPER / 2.0
        # The ring needs a clear pixel on every side of the art. A drawing that has drifted to an
        # edge (a turn moves things) is slid back; one too big to slide is refused.
        ys, xs = np.nonzero(inside)
        if xs.max() - xs.min() > SIDE - 3 or ys.max() - ys.min() > SIDE - 3:
            raise SystemExit("%s is %dx%d: no room for its outline on a %d square"
                             % (name, xs.max() - xs.min() + 1, ys.max() - ys.min() + 1, SIDE))
        dx = max(0, 1 - xs.min()) - max(0, xs.max() - (SIDE - 2))
        dy = max(0, 1 - ys.min()) - max(0, ys.max() - (SIDE - 2))
        inside = np.roll(inside, (dy, dx), (0, 1))
        rgb = np.roll(rgb, (dy, dx), (0, 1))
        noise = rng.normal(0.0, 0.018, (SIDE, SIDE))
        rgb = np.clip(rgb * (1.0 + noise[..., None]), 0, 250)
        out = np.zeros((SIDE, SIDE, 4), np.uint8)
        out[..., :3] = np.where(inside[..., None], rgb.round(), 0)
        out[..., 3] = np.where(inside, 255, 0)
        def beside(field, ways, beyond=False):
            """Which pixels have one of `field` next to them, in the directions `ways`; `beyond` is
            what lies off the square."""
            grown = np.zeros_like(field)
            padded = np.pad(field, 1, constant_values=beyond)
            for dx, dy in ways:
                grown |= padded[1 + dy:1 + dy + SIDE, 1 + dx:1 + dx + SIDE]
            return grown
        four = ((1, 0), (-1, 0), (0, 1), (0, -1))
        ring = beside(inside, four) & ~inside
        # A pinhole between two parts would fill with border and leave nothing clear beside it, so
        # tools/ui_kit.py could not know it for border and it would stay white. It is closed
        # instead, with the colour of what is round it.
        pinhole = ring & ~beside(~inside & ~ring, four + ((1, 1), (1, -1), (-1, 1), (-1, -1)), beyond=True)
        for y, x in zip(*np.nonzero(pinhole)):
            near = [out[y + dy, x + dx, :3] for dx, dy in four
                    if 0 <= y + dy < SIDE and 0 <= x + dx < SIDE and inside[y + dy, x + dx]]
            out[y, x] = tuple(np.mean(near, 0).round().astype(int)) + (255,)
        out[ring & ~pinhole] = (255, 255, 255, 255)
        return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------- shared parts

def rivet(canvas, x, y, ramp="iron", r=0.75):
    """A light dot with a dark one under it to the right, the way the pack draws a fitting."""
    canvas.shade(ellipse(x + 0.35, y + 0.4, r), 0.55)
    canvas.paint(ellipse(x, y, r), ramp, facet(0.85), seam=1.0)


def gem(canvas, x, y, r, ramp, squash=1.0):
    """A cut stone: a dark girdle, a lit table, a glint. Never its ramp's darkest steps: the outline
    is painted in the icon's darkest tone, and a ruby's is red."""
    stone = ellipse(x, y, r, r * squash)
    canvas.paint(stone, ramp, np.clip(volume(stone, 0.5, 0.5, r * 0.6), 0.3, 1.0))
    canvas.shade(ellipse(x - r * 0.3, y - r * 0.35 * squash, r * 0.32), 1.75)


def blade(canvas, frame, start, length, width, ramp="steel", tip=3.0, fuller=False, mid=0.72):
    """Two facets meeting on a ridge, the upper-left one in the light, a pale line down that edge."""
    half = width / 2.0
    end = start + length
    canvas.paint(frame.poly((start, -half), (end - tip, -half), (end, 0), (start, 0)), ramp, facet(mid + 0.14, 0.004))
    canvas.paint(frame.poly((start, 0), (end, 0), (end - tip, half), (start, half)), ramp, facet(mid - 0.14, 0.004),
                 seam=1.0)
    canvas.shade(frame.poly((start, -half), (end - tip, -half), (end, 0), (end - 0.6, 0.1),
                            (end - tip - 0.2, -half + 0.7), (start, -half + 0.7)), 1.45)
    canvas.shade(frame.capsule((start, 0.1), (end - 0.5, 0.1), 0.5), 0.9)
    if fuller:
        canvas.shade(frame.capsule((start + 1.0, -0.2), (start + length * 0.62, -0.2), 1.0), 0.72)
        canvas.shade(frame.capsule((start + 1.0, -0.75), (start + length * 0.62, -0.75), 0.35), 1.3)


def grip(canvas, frame, start, length, width, ramp="leather", wraps=0):
    canvas.paint(frame.capsule((start, 0), (start + length, 0), width), ramp,
                 volume(frame.capsule((start, 0), (start + length, 0), width), 0.5, 0.35, width * 0.45))
    for i in range(wraps):
        at = start + (i + 0.5) * length / wraps
        canvas.shade(frame.capsule((at - 0.3, -width / 2), (at + 0.3, width / 2), 0.4), 0.62)


def part(canvas, mask, ramp, mid=0.55, relief=0.32, roundness=1.2, seam=0.55):
    """The usual part: a mask rounded off and lit."""
    canvas.paint(mask, ramp, volume(mask, mid, relief, roundness), seam)
