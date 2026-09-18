"""The generated item-base icons, one function to a kind and one tier to a call. gearlib.py holds
the kit they are painted with and everything that was measured off the pack to build it.

Which bases are drawn here and which are cut from the pack is tools/ui_kit.py's business
(BASE_KINDS); this file only knows how to draw the ones it is asked for. A kind's tiers share their
construction and each adds parts to the one before, so the ladder is read in the drawing first and
in the material second.
"""
import math

import numpy as np

from gearlib import (SIDE, Canvas, Frame, blade, capsule, curve, ellipse, facet, gem, grip, part, poly, ring,
                     rivet, volume)

## Where a full-length weapon's pommel sits; its point lands near (28, 4).
HILT = (3.6, 28.4)
## What a garment drawn square to the canvas is turned by, clockwise. The pack leans everything.
LEAN = 7.0


def _sword(tier):
    """Only the Steel Sword is drawn: the wooden one is on disk and the pack draws an iron and a
    golden one. It is the pack's iron sword made with more care -- a fuller, a wrapped grip, a long
    straight guard with knobbed ends and a wheel pommel."""
    c, f = Canvas(), Frame(HILT)
    blade(c, f, 11.0, 24.0, 6.4, "steel", tip=4.4, fuller=True)
    grip(c, f, 3.0, 8.0, 3.0, "leather", wraps=3)
    part(c, f.capsule((10.6, -6.0), (10.6, 6.0), 2.8), "iron", 0.6, 0.4, 0.9)
    for side in (-6.0, 6.0):
        part(c, f.ellipse(10.6, side, 1.9), "iron", 0.62, 0.45, 0.9, seam=0.8)
    part(c, f.ellipse(2.4, 0, 2.5), "iron", 0.6, 0.45, 1.0)
    return c.icon("Steel Sword")


def _dagger(tier):
    """Short: 29 px of the diagonal against a sword's 35 and a narrower blade, so it reads small
    before it reads sharp. A sliver of bone lashed to a stick; a plain iron blade on a wooden grip;
    a needle with a long guard; a waved kris on a gold hilt."""
    c, f = Canvas(), Frame((5.6, 26.4))
    if tier == "bone":
        c.paint(f.poly((9.0, -3.2), (19.0, -3.8), (27.0, -1.2), (29.0, 0.8), (20.0, 3.0), (9.0, 2.8)),
                "bone", facet(0.78, 0.012))
        c.shade(f.poly((9.0, 0.3), (29.0, 0.8), (20.0, 3.0), (9.0, 2.8)), 0.78)
        c.shade(f.capsule((10.5, -2.6), (24.5, -2.0), 0.6), 1.4)
        c.shade(f.capsule((15.0, 0.6), (16.4, 2.6), 0.45), 0.6)
        c.shade(f.capsule((21.0, -2.8), (21.8, -1.2), 0.45), 0.7)
        grip(c, f, 1.0, 9.0, 3.8, "wood")
        for at in (6.8, 8.4, 10.0):
            part(c, f.capsule((at, -2.4), (at + 0.6, 2.4), 1.2), "cloth", 0.7, 0.3, 0.5, seam=0.7)
    elif tier == "iron":
        blade(c, f, 10.0, 19.0, 5.0, "iron", tip=5.0, mid=0.7)
        grip(c, f, 1.6, 8.0, 3.4, "wood")
        part(c, f.capsule((10.0, -3.4), (10.0, 3.4), 2.4), "darkiron", 0.62, 0.4, 0.8)
    elif tier == "steel":
        blade(c, f, 10.5, 18.5, 3.6, "steel", tip=8.0)
        grip(c, f, 2.4, 7.8, 3.0, "leather", wraps=4)
        part(c, f.capsule((10.2, -5.0), (10.2, 5.0), 2.6), "iron", 0.62, 0.4, 0.8)
        part(c, f.ellipse(10.2, 0, 1.8), "steel", 0.8, 0.3, 0.6, seam=0.8)
        part(c, f.ellipse(1.8, 0, 2.4), "iron", 0.6, 0.45, 0.9)
    else:
        def across(a):
            return 2.2 * math.sin((a - 10.5) * 0.72) * (1 - (a - 10.5) / 30.0)

        def half(a):
            return 3.3 * (1 - ((a - 10.5) / 19.0) ** 1.6)
        steps = [10.5 + i * 0.5 for i in range(38)]
        spine = [(a, across(a)) for a in steps]
        c.paint(f.poly(*([(a, across(a) - half(a)) for a in steps] + spine[::-1])), "steel", facet(0.88, 0.004))
        c.paint(f.poly(*(spine + [(a, across(a) + half(a)) for a in steps][::-1])), "steel", facet(0.6, 0.004),
                seam=1.0)
        c.shade(curve([f.at(a, b) for a, b in spine], 0.5), 0.85)
        grip(c, f, 2.4, 7.8, 3.4, "gold", wraps=3)
        part(c, f.poly((8.8, -5.4), (12.0, -3.6), (12.0, 3.6), (8.8, 5.4)), "gold", 0.62, 0.4, 0.8)
        gem(c, *f.at(10.4, 0), 1.7, "ruby")
        part(c, f.ellipse(1.8, 0, 2.7), "gold", 0.62, 0.45, 0.9)
    return c.icon(tier + " dagger")


def _haft(c, f, start, end, width, ramp="wood"):
    part(c, f.capsule((start, 0), (end, 0), width), ramp, 0.5, 0.4, width * 0.45)
    c.shade(f.capsule((start + 1, 0.5), (end - 1, 0.5), 0.35), 0.8)


def _mace(tier):
    """Four different heads, because the four names promise four weapons: a knotted club, a flanged
    mace, a spiked ball, and a rod with a crowned jewel on it."""
    c, f = Canvas(), Frame(HILT)
    if tier == "wood":
        part(c, f.capsule((2.0, 0), (27.5, 0), 3.2, 10.5), "wood", 0.5, 0.42, 2.4)
        for along, across, r in ((24.0, -2.2, 1.5), (19.5, 1.8, 1.3), (27.5, 1.6, 1.2)):
            c.shade(f.ellipse(along + 0.3, across + 0.3, r), 0.72)
            c.shade(f.ellipse(along - 0.2, across - 0.3, r * 0.5), 1.25)
        for at in (4.0, 5.8, 7.6):
            c.shade(f.capsule((at, -1.6), (at + 0.5, 1.6), 0.5), 0.6)
        return c.icon("Wooden Club")
    if tier == "iron":
        _haft(c, f, 2.0, 21.0, 3.0)
        part(c, f.ellipse(2.4, 0, 2.2), "iron", 0.55, 0.4, 0.9)
        part(c, f.capsule((19.0, -2.4), (19.0, 2.4), 2.2), "iron", 0.6, 0.4, 0.7)
        # Three flanges seen edge on: plates side by side down the haft's line, the middle one
        # longest and each a step darker than the one above it, parted by their own seams.
        for across, tone, reach in ((3.5, 0.4, 0.0), (-3.5, 0.74, 0.0), (0.0, 0.58, 1.6)):
            part(c, f.poly((20.5 - reach, across), (23.0, across - 1.9), (28.0 + reach, across - 1.9),
                           (30.2 + reach, across), (28.0 + reach, across + 1.9), (23.0, across + 1.9)),
                 "iron", tone, 0.4, 0.7, seam=0.5)
        part(c, f.ellipse(32.4, 0, 1.5), "iron", 0.7, 0.4, 0.6)
        return c.icon("Iron Mace")
    if tier == "steel":
        _haft(c, f, 2.0, 21.0, 2.8)
        for at in (3.0, 9.0, 18.5):
            part(c, f.capsule((at, -1.5), (at, 1.5), 1.6), "iron", 0.6, 0.4, 0.6)
        centre = f.at(25.5, 0)
        for k in range(8):
            turn = math.radians(k * 45 + 22.5)
            tip = (centre[0] + 8.6 * math.cos(turn), centre[1] + 8.6 * math.sin(turn))
            left = (centre[0] + 5.0 * math.cos(turn - 0.33), centre[1] + 5.0 * math.sin(turn - 0.33))
            right = (centre[0] + 5.0 * math.cos(turn + 0.33), centre[1] + 5.0 * math.sin(turn + 0.33))
            c.paint(poly(left, tip, right), "steel", facet(0.62 - 0.3 * math.sin(turn), 0.0), seam=1.0)
        part(c, ellipse(*centre, 5.8), "steel", 0.56, 0.5, 2.6, seam=0.7)
        for dx, dy in ((-1.8, -1.8), (2.2, 0.4), (-0.4, 2.6)):
            c.paint(ellipse(centre[0] + dx, centre[1] + dy, 1.0), "steel", facet(0.92), seam=0.6)
        return c.icon("Steel Morningstar")
    part(c, f.capsule((2.0, 0), (23.0, 0), 3.0), "gold", 0.55, 0.4, 1.0)
    for at in (2.4, 8.0, 13.0, 21.5):
        part(c, f.capsule((at, -1.7), (at, 1.7), 1.7), "gold", 0.7, 0.4, 0.6)
    part(c, f.poly((22.0, -2.0), (26.5, -5.0), (25.5, -2.2), (29.0, -2.6), (27.0, 0), (29.0, 2.6),
                   (25.5, 2.2), (26.5, 5.0), (22.0, 2.0)), "gold", 0.62, 0.45, 0.9)
    gem(c, *f.at(27.6, 0), 3.4, "ruby")
    part(c, f.ellipse(31.8, 0, 1.3), "gold", 0.75, 0.4, 0.5)
    return c.icon("Golden Sceptre")


def _greatsword(tier):
    """A sword fills the diagonal already, so a greatsword is not longer but heavier: a blade half
    again as wide, a grip for two hands, a guard that reaches across the square. Wood lashed to
    wood; a claymore's guard sloped to the point with ring ends; a zweihander's ricasso and
    parrying hooks; a gilt hilt with a stone in it and a line engraved up the blade."""
    c, f = Canvas(), Frame((2.8, 29.2))
    if tier == "wood":
        c.paint(f.poly((13.0, -4.2), (33.0, -4.2), (37.0, 0), (13.0, 0)), "wood", facet(0.74, 0.004))
        c.paint(f.poly((13.0, 0), (37.0, 0), (33.0, 4.2), (13.0, 4.2)), "wood", facet(0.5, 0.004), seam=1.0)
        for across in (-2.4, 2.0):
            c.shade(f.capsule((15.0, across), (31.0, across + 0.4), 0.4), 0.82)
        grip(c, f, 2.0, 11.0, 3.4, "wood")
        part(c, f.capsule((12.4, -7.0), (12.4, 7.0), 3.6), "wood", 0.55, 0.4, 1.2)
        for across in (-1.2, 1.2):
            part(c, f.capsule((10.5, across), (14.5, -across), 1.1), "cloth", 0.72, 0.3, 0.5, seam=0.75)
        return c.icon("Wooden Greatsword")
    metal = {"iron": "iron", "steel": "steel", "gold": "steel"}[tier]
    fitting = {"iron": "darkiron", "steel": "iron", "gold": "gold"}[tier]
    blade(c, f, 13.0, 24.5, 8.6, metal, tip=5.6, fuller=tier != "iron", mid=0.66 if tier == "iron" else 0.74)
    grip(c, f, 2.5, 10.5, 3.2, "leather", wraps=5 if tier != "iron" else 3)
    if tier == "iron":
        for side in (-1, 1):
            part(c, f.capsule((12.6, 0), (16.0, side * 7.4), 2.8), fitting, 0.6, 0.4, 0.9)
            c.paint(ring(*f.at(16.4, side * 8.0), 2.2, 0.8), fitting, facet(0.7), seam=0.7)
    else:
        part(c, f.capsule((12.4, -8.2), (12.4, 8.2), 3.0), fitting, 0.62, 0.42, 0.9)
        for side in (-8.2, 8.2):
            part(c, f.ellipse(12.4, side, 2.1), fitting, 0.66, 0.45, 0.9, seam=0.8)
        for side in (-1, 1):
            part(c, f.poly((17.5, side * 3.4), (19.2, side * 6.2), (21.0, side * 3.4)), metal, 0.6, 0.4, 0.6)
    if tier == "gold":
        gem(c, *f.at(12.4, 0), 1.9, "sapphire")
        c.shade(f.capsule((15.0, 1.6), (30.0, 1.6), 0.4), 0.75)
        part(c, f.capsule((7.6, -1.8), (7.6, 1.8), 1.6), fitting, 0.7, 0.4, 0.6)
    part(c, f.ellipse(1.9, 0, 2.7), fitting, 0.6, 0.45, 1.0)
    return c.icon(tier + " greatsword")


def _mirror(half):
    """A symmetric outline from its right half, listed top to bottom as (along, across)."""
    return half + [(a, -b) for a, b in reversed(half)]


def _inset(points, by, centre):
    """The same outline pulled towards `centre`, for a field inside a rim."""
    return [(centre[0] + (a - centre[0]) * by, centre[1] + (b - centre[1]) * by) for a, b in points]


def _shield(tier):
    """Leaning back to the upper left with its far edge showing, the way the pack shield lies:
    top corners near (4, 10) and (21, 2), point near (25, 29). A heater of iron plate, ridged and
    riveted; a long steel kite with a banded cross and a boss; and the aegis -- the biggest of the
    three, eared and peaked at the top, a raised rim round a sunk field, a pair of wings embossed
    on it and a great stone in a clawed boss, in gold that runs from brown shadow to white glint."""
    c, f = Canvas(), Frame((19.4, 29.6), -103.0, 0.88)
    if tier == "iron":
        outline = _mirror([(25.0, 0.0), (25.4, 10.0), (15.0, 10.2), (7.0, 7.0), (0.0, 0.0)])
        centre, rim, field = (14.0, 0.0), "iron", "darkiron"
    elif tier == "steel":
        outline = _mirror([(27.4, 0.0), (26.4, 6.0), (22.5, 9.6), (16.0, 8.6), (7.0, 4.6), (0.0, 0.0)])
        centre, rim, field = (16.0, 0.0), "steel", "iron"
    elif tier == "bulwark":
        # The unique: a tower shield, square-shouldered and as broad at the foot as at the head.
        outline = _mirror([(27.4, 0.0), (26.6, 8.6), (24.4, 10.6), (4.0, 10.6), (1.4, 8.0), (0.0, 0.0)])
        centre, rim, field = (14.0, 0.0), "steel", "iron"
    else:
        outline = _mirror([(27.2, 0.0), (24.6, 2.8), (25.4, 6.6), (27.2, 10.6), (23.0, 12.2), (16.6, 11.8),
                           (10.0, 9.4), (4.4, 4.8), (0.0, 0.0)])
        centre, rim, field = (15.5, 0.0), "gold", "gold"
    # The thickness of the thing, seen along its right-hand edge: the same outline a pixel and a
    # half off to the lower right, in the rim metal and in shadow.
    far = [(a - 0.6, b + 2.0) for a, b in outline]
    c.paint(f.poly(*far), rim, facet(0.3), seam=1.0)
    part(c, f.poly(*outline), rim, 0.72, 0.4, 0.9, seam=0.7)
    inner = f.poly(*_inset(outline, 0.78 if tier == "gold" else 0.76, centre))
    c.paint(inner, field, np.clip(volume(inner, {"iron": 0.62, "steel": 0.46, "bulwark": 0.46, "gold": 0.26}[tier], 0.34, 3.0)
                                  + facet(0.0, 0.012, (1.0, -0.4)), 0, 1), seam=0.55)
    if tier == "iron":
        c.shade(f.poly((3.0, 0.0), (22.0, 0.0), (22.0, -7.6), (14.0, -7.4), (8.0, -4.6)), 0.8)
        c.shade(f.capsule((3.5, 0.4), (22.0, 0.4), 0.5), 1.4)
        for along, across in ((23.2, -8.4), (23.2, 8.4), (13.0, -8.6), (13.0, 8.6), (3.0, 0.0), (23.2, 0.0)):
            rivet(c, *f.at(along, across), "steel", 1.0)
    elif tier == "bulwark":
        for along in (7.0, 20.6):
            part(c, f.capsule((along, -8.6), (along, 8.6), 2.4), "steel", 0.7, 0.3, 0.7, seam=0.6)
            for across in (-7.0, -2.4, 2.4, 7.0):
                rivet(c, *f.at(along, across), "steel", 0.7)
        part(c, f.ellipse(13.8, 0, 3.6), "steel", 0.62, 0.5, 1.6, seam=0.55)
        part(c, f.poly((12.6, -1.0), (17.0, 0.0), (12.6, 1.0)), "steel", 0.85, 0.3, 0.5, seam=0.7)
    elif tier == "steel":
        part(c, f.capsule((4.0, 0), (25.4, 0), 2.2), "steel", 0.7, 0.3, 0.7, seam=0.6)
        part(c, f.capsule((18.5, -7.0), (18.5, 7.0), 2.2), "steel", 0.7, 0.3, 0.7, seam=0.6)
        part(c, f.ellipse(18.5, 0, 3.0), "steel", 0.62, 0.5, 1.4, seam=0.55)
        for along, across in ((23.6, -4.6), (23.6, 4.6), (9.0, 0.0)):
            rivet(c, *f.at(along, across), "steel", 0.7)
    else:
        for side in (-1, 1):
            wing = f.poly((17.0, side * 2.6), (22.6, side * 4.0), (24.4, side * 9.6), (21.0, side * 8.0),
                          (20.4, side * 10.0), (17.6, side * 7.4), (16.4, side * 8.8), (14.6, side * 5.0))
            c.paint(wing, "gold", np.clip(volume(wing, 0.76 - side * 0.06, 0.45, 0.9), 0, 1), seam=0.45)
            for k in range(3):
                c.shade(f.capsule((16.4 + k * 2.0, side * 3.4), (17.4 + k * 2.2, side * (7.6 + k * 0.6)), 0.5), 0.45)
        part(c, f.poly((4.0, 0.0), (9.0, -2.6), (13.0, 0.0), (9.0, 2.6)), "gold", 0.66, 0.5, 0.8, seam=0.5)
        part(c, f.ellipse(18.0, 0, 4.4), "gold", 0.66, 0.5, 1.2, seam=0.5)
        gem(c, *f.at(18.0, 0), 3.1, "sapphire")
        for turn in (45, 135, 225, 315):
            part(c, f.ellipse(18.0 + 3.6 * math.cos(math.radians(turn)), 3.6 * math.sin(math.radians(turn)), 0.9),
                 "gold", 0.86, 0.3, 0.4, seam=0.7)
        # The glint: gold is the one ramp here that runs to white, and an aegis is where it shows.
        c.shade(f.capsule((27.0, -9.6), (24.8, -11.0), 0.7), 1.8)
        c.shade(f.capsule((26.4, -1.6), (27.6, -0.4), 0.7), 1.8)
        c.shade(f.capsule((12.0, -9.2), (16.0, -10.8), 0.6), 1.6)
    return c.icon(tier + " shield")


def _blazing_torch():
    """The pack's torch is a stick with a flame on it, haft from (7, 30) to (20, 14) and the fire
    above that. This is the same stick made into a proper brand: a head of pitch-soaked wrapping
    in an iron cage, and a fire three times the size -- a red-orange body in separate licks, an
    orange one inside it, a white-yellow heart, two sparks gone up off the top -- with its light
    caught on the cage and the top of the haft. It uses the whole height of the square."""
    c, f = Canvas(), Frame((6.8, 28.5), -51.0)
    part(c, f.capsule((0.0, 0), (19.0, 0), 4.2, 4.8), "wood", 0.5, 0.4, 2.0)
    for at in (2.4, 4.0):
        c.shade(f.capsule((at, -2.0), (at + 0.4, 2.0), 0.5), 0.6)
    c.shade(f.capsule((10.0, -1.6), (15.0, -1.8), 0.9), 1.35)
    # Back to front: the red-orange body in three licks, the orange inside it, the pale heart.
    for base, tip, width, ramp, tone in (
            ((19.6, 10.6), (12.6, 3.6), 6.6, "ember", 0.5), ((21.4, 10.0), (21.0, 2.2), 9.4, "ember", 0.62),
            ((24.4, 11.0), (28.8, 4.4), 6.4, "ember", 0.5), ((17.6, 12.6), (10.6, 10.4), 4.0, "ember", 0.4),
            ((26.0, 13.4), (30.2, 11.6), 3.6, "ember", 0.4),
            ((20.0, 10.8), (15.8, 6.6), 4.8, "flame", 0.45), ((21.6, 10.6), (21.0, 4.4), 7.0, "flame", 0.55),
            ((24.0, 11.2), (26.4, 8.0), 4.4, "flame", 0.45)):
        c.paint(capsule(base, tip, width, 1.8), ramp, facet(tone, 0.02, (0.0, 1.0)), seam=1.0)
    c.paint(ellipse(21.8, 11.0, 6.2, 4.8), "flame", facet(0.6, 0.03, (0.0, 1.0)), seam=1.0)
    c.paint(capsule((21.6, 11.6), (21.2, 6.4), 4.6, 1.6), "flame", facet(1.0), seam=1.0)
    for x, y, r in ((16.4, 2.2, 0.8), (25.6, 2.4, 0.7)):
        c.paint(ellipse(x, y, r), "flame", facet(0.8), seam=1.0)
    head = f.capsule((16.0, 0), (20.6, 0), 6.6, 7.8)
    c.paint(head, "wood", np.clip(volume(head, 0.3, 0.4, 2.0), 0.12, 1.0), seam=0.6)
    for at in (16.8, 18.6):
        c.shade(f.capsule((at, -3.4), (at + 0.5, 3.4), 0.5), 0.6)
    for across in (-3.0, 0.0, 3.0):
        part(c, f.capsule((15.2, across * 0.85), (21.6, across * 1.2), 1.3), "iron", 0.64 - across * 0.05, 0.4, 0.5,
             seam=0.7)
    part(c, f.capsule((15.4, -3.0), (15.4, 3.0), 1.7), "iron", 0.6, 0.4, 0.6)
    part(c, f.capsule((21.6, -4.0), (21.6, 4.0), 1.5), "iron", 0.78, 0.4, 0.6)
    c.shade(f.capsule((21.6, -3.6), (21.6, 2.0), 0.7), 1.6)
    return c.icon("Blazing Torch")


def _buckler(tier):
    """A fist's shield: 20 px across against a shield's 27 tall, and round where that one is not.
    Hide laced to a hoop; an iron dish with a boss; a targe ringed with studs round a spike; a gilt
    rim, a ring cut into the face and a stone for a boss."""
    c = Canvas()
    x, y, r = 16.0, 16.2, 10.0
    face, rim = {"hide": ("hide", "wood"), "iron": ("darkiron", "iron"), "steel": ("iron", "steel"),
                 "gold": ("steel", "gold")}[tier]
    part(c, ellipse(x, y, r), rim, 0.62, 0.4, 1.0)
    disc = ellipse(x, y, r - (1.6 if tier == "hide" else 2.2))
    c.paint(disc, face, volume(disc, 0.56, 0.42, 4.0), seam=0.6)
    if tier == "hide":
        for k in range(12):
            turn = math.radians(k * 30 + 10)
            c.shade(capsule((x + 7.0 * math.cos(turn), y + 7.0 * math.sin(turn)),
                            (x + 9.6 * math.cos(turn), y + 9.6 * math.sin(turn)), 0.6), 0.5)
        c.shade(curve([(10.5, 12.0), (13.0, 14.0), (12.5, 17.0)], 0.4), 0.75)
        part(c, ellipse(x, y, 2.4), "wood", 0.6, 0.45, 1.0)
        return c.icon("Hide Buckler")
    if tier == "steel":
        c.shade(ring(x, y, 5.4, 4.8), 0.75)
        for k in range(10):
            turn = math.radians(k * 36)
            rivet(c, x + 6.6 * math.cos(turn), y + 6.6 * math.sin(turn), "steel", 0.75)
    if tier == "gold":
        c.shade(ring(x, y, 6.6, 6.0), 0.7)
        c.shade(ring(x, y, 6.0, 5.5), 1.4)
        for k in range(4):
            turn = math.radians(k * 90 + 45)
            rivet(c, x + 8.9 * math.cos(turn), y + 8.9 * math.sin(turn), "gold", 0.7)
    part(c, ellipse(x, y, 3.6 if tier != "iron" else 3.2), rim, 0.6, 0.5, 1.5)
    if tier == "steel":
        part(c, poly((x - 1.3, y + 0.6), (x + 0.4, y - 3.4), (x + 1.4, y + 0.4)), "steel", 0.85, 0.3, 0.5, seam=0.7)
    if tier == "gold":
        gem(c, x, y, 2.3, "ruby")
    return c.icon(tier + " buckler")


def _golden_helm():
    """The top of the pack helmets' ladder, so it is the pack great helm -- flat crown, sides
    swelling to the cheek, drawn down to a point under the chin, turned a little to the right so
    the upright of its cross stands right of centre -- made in gold plate. Dark gold plates, a
    bright riveted cross over a black eye slit, breaths punched in both cheeks; and on top of the
    pack one a toothed crown with a stone in it and a full red plume falling behind."""
    c = Canvas()
    for spine, width, tone in (([(12.0, 7.0), (6.0, 4.6), (2.8, 9.0), (2.6, 16.0)], 4.6, 0.46),
                               ([(13.0, 6.0), (7.4, 3.4), (4.0, 7.0), (4.2, 13.0)], 3.4, 0.62)):
        plume = curve(spine, width)
        c.paint(plume, "ruby", np.clip(volume(plume, tone - 0.14, 0.4, 1.2), 0.25, 0.62), seam=0.8)
    for x, y in ((3.0, 10.0), (3.4, 13.4), (5.6, 5.6)):
        c.shade(capsule((x, y), (x + 1.6, y + 1.2), 0.45), 0.7)
    body = poly((8.8, 7.0), (24.2, 7.0), (26.8, 12.0), (27.8, 20.0), (25.2, 26.0), (20.8, 30.6), (14.0, 28.2),
                (7.6, 24.2), (5.4, 18.0), (6.4, 11.4))
    c.paint(body, "gold", np.clip(volume(body, 0.34, 0.4, 3.0) + facet(0.0, 0.016, (1.0, 0.0)), 0, 1))
    upright = poly((17.0, 7.0), (21.8, 7.0), (22.6, 29.4), (20.8, 30.6), (18.2, 29.6))
    across = poly((5.8, 13.4), (27.2, 12.6), (27.8, 17.4), (5.4, 18.4))
    part(c, across, "gold", 0.72, 0.35, 0.7, seam=0.5)
    part(c, upright, "gold", 0.8, 0.35, 0.7, seam=0.5)
    for x0, x1 in ((8.2, 16.2), (22.8, 26.6)):
        c.paint(poly((x0, 15.0), (x1, 14.7), (x1, 16.3), (x0, 16.6)), "wood", facet(0.0), seam=1.0)
    for x in (9.4, 11.8, 14.2):
        for y in (21.0, 23.2, 25.4):
            if y < 25.0 or x > 10.0:
                c.shade(ellipse(x, y + (x - 9.4) * 0.12, 0.62), 0.3)
    for y in (21.0, 23.4):
        c.shade(ellipse(25.0, y, 0.62), 0.3)
    for x, y in ((7.0, 13.6), (12.0, 13.4), (24.8, 13.0), (7.0, 18.0), (12.0, 17.8), (25.4, 17.4), (19.4, 9.4),
                 (19.8, 21.0), (20.2, 26.0)):
        rivet(c, x, y, "gold", 0.6)
    crown = [(7.8, 9.6), (8.0, 5.0), (10.0, 6.6), (11.6, 2.4), (13.6, 6.4), (16.4, 1.6), (19.0, 6.4), (21.2, 2.4),
             (22.8, 6.6), (25.0, 5.0), (25.2, 9.6)]
    part(c, poly(*crown), "gold", 0.74, 0.4, 0.7, seam=0.5)
    c.shade(capsule((8.4, 9.0), (24.8, 9.0), 0.6), 0.6)
    gem(c, 16.4, 7.0, 1.5, "sapphire")
    for x in (11.6, 21.2):
        gem(c, x, 7.4, 0.9, "ruby")
    c.shade(capsule((24.6, 10.0), (26.6, 15.0), 0.7), 1.7)
    return c.icon("Golden Helm")


def _hood(tier):
    """A cowl seen from the front: a peak, a dark mouth with no face in it, a mantle over the
    shoulders. Plain hide with a raw hem; leather, seamed down the crown and stitched round the
    mantle; the same studded along the opening with a buckled throat strap; and the thief's one,
    drawn to a point, a mask across the mouth and a stone at the throat."""
    c = Canvas()
    ramp = {"hide": "hide", "leather": "leather", "studded": "studded", "shadow": "shadow"}[tier]
    peak = (12.0, 2.4) if tier == "shadow" else (14.0, 3.2)
    # The point of the hood, fallen over behind: without it a cowl from the front is an archway.
    tail = [(peak[0] + 1.0, peak[1] + 2.0), (8.6, 3.0), (4.8, 5.6), (3.4, 10.0 if tier == "shadow" else 8.6)]
    for (a, b), width in zip(zip(tail, tail[1:]), (4.4, 3.2, 2.0)):
        part(c, capsule(a, b, width, width - 1.0), ramp, 0.5, 0.4, 1.0, seam=1.0)
    mantle = poly((6.0, 21.0), (26.0, 21.0), (29.4, 27.4), (22.0, 29.6), (16.0, 28.4), (10.0, 29.6), (2.6, 27.4))
    if tier != "hide":
        part(c, mantle, ramp, 0.5, 0.4, 2.2)
    cowl = poly(peak, (20.5, 5.0), (25.0, 10.0), (26.4, 17.0), (25.0, 23.6), (16.0, 25.6), (7.0, 23.6), (5.6, 17.0),
                (7.4, 9.4), (11.0, 5.0))
    c.paint(cowl, ramp, volume(cowl, 0.56, 0.45, 3.4))
    mouth_at = [(16.0, 8.4), (19.6, 11.6), (21.4, 16.6), (20.0, 22.4), (16.0, 24.0), (12.0, 22.4), (10.6, 16.6),
                (12.4, 11.6)]
    lip = poly(*[(16 + (x - 16) * 1.24, 16.6 + (y - 16.6) * 1.17) for x, y in mouth_at])
    c.paint(lip * cowl, ramp, volume(lip, 0.74, 0.3, 1.0), seam=0.8)
    mouth = poly(*mouth_at)
    c.paint(mouth, ramp, volume(mouth, 0.06, 0.1, 2.0) * 0.6, seam=0.5, seam_width=0.9)
    c.shade(curve([(8.0, 12.0), (7.4, 17.0), (8.6, 22.0)], 0.6), 0.78)
    c.shade(curve([(23.0, 9.6), (24.6, 15.0), (24.0, 21.0)], 0.6), 1.3)
    if tier == "hide":
        for x in (8.4, 12.2, 16.0, 19.8, 23.6):
            c.erase(poly((x - 1.3, 27.0), (x, 23.0 + abs(x - 16) * 0.2), (x + 1.3, 27.0)))
        for y in (8.0, 11.0, 14.0):
            c.shade(capsule((22.6, y), (24.0, y + 0.8), 0.5), 0.6)
    else:
        c.shade(curve([peak, (16.6, 6.4), (16.2, 9.4)], 0.5), 0.6)
        for x in range(5, 28, 2):
            c.shade(capsule((x, 26.0 + abs(x - 16) * 0.1), (x + 0.9, 26.0 + abs(x - 16) * 0.1), 0.5), 0.55)
    if tier == "studded":
        for turn in range(-150, 181, 30):
            rivet(c, 16.0 + 7.2 * math.cos(math.radians(turn)), 16.6 + 8.8 * math.sin(math.radians(turn)), "steel", 0.8)
        part(c, poly((9.0, 22.4), (23.0, 22.4), (23.0, 24.6), (9.0, 24.6)), "leather", 0.62, 0.3, 0.6)
        part(c, poly((14.6, 21.8), (17.6, 21.8), (17.6, 25.2), (14.6, 25.2)), "steel", 0.7, 0.4, 0.6)
    if tier == "shadow":
        mask = poly((10.6, 17.0), (21.4, 17.0), (20.2, 22.6), (16.0, 24.4), (11.8, 22.6))
        c.paint(mask, "shadow", volume(mask, 0.62, 0.4, 1.6), seam=0.6)
        c.shade(capsule((11.6, 19.4), (20.4, 19.4), 0.45), 0.6)
        part(c, ellipse(16.0, 26.2, 2.2), "gold", 0.66, 0.4, 0.8)
        gem(c, 16.0, 26.2, 1.4, "emerald")
    return c.icon(tier + " hood")


def _hat(tier):
    """Built the way the pack wizard hat is, because it is the second rung of this row: a wide
    brim seen from a little above and tipped down to the right (the pack one runs from (3, 17) to
    (30, 30)), a soft cone standing on the left half of it, creased where it sags, its tip slumped
    over to the left. Drawn upright and turned, like the garments.

    The apprentice hat is that and nothing more, short, with a cord for a band. The sage hat is
    taller, with a leather band and a gold buckle, a sewn patch on the cone, leaves worked along
    the band and a feather in it. The archmage hat is tallest: a gold band with a stone, gold round
    the brim, stars on the cone and a bead on the tip."""
    c = Canvas()
    ramp = {"linen": "linen", "sage": "sage", "archmage": "archmage"}[tier]
    tall = {"linen": 0.0, "sage": 3.4, "archmage": 5.4}[tier]
    brim = np.maximum(ellipse(16.0, 23.6, 13.4, 4.8), ellipse(21.0, 24.6, 8.6, 4.6))
    c.paint(brim, ramp, np.clip(volume(brim, 0.5, 0.45, 1.6) + facet(0.0, 0.01, (1.0, 0.0)), 0, 1))
    if tier == "archmage":
        c.paint(np.clip(brim - np.maximum(ellipse(16.0, 23.0, 12.2, 3.8), ellipse(21.0, 24.0, 7.6, 3.6)), 0, 1),
                "gold", facet(0.72), seam=1.0)
    c.shade(ellipse(15.0, 25.0, 9.6, 2.6), 0.72)
    c.shade(curve([(24.0, 26.6), (27.0, 24.6), (28.6, 22.6)], 0.6), 1.3)
    # The cone as a thick tapering line, so it sags where a polygon would stand to attention.
    spine = [((15.0, 22.6), 15.6), ((14.4, 15.0 - tall * 0.4), 10.4), ((12.6, 8.6 - tall * 0.8), 6.0),
             ((9.4, 5.0 - tall * 0.7), 3.6), ((5.6, 6.6 - tall * 0.5), 2.2), ((4.0, 9.8 - tall * 0.4), 1.4)]
    cone = np.zeros_like(brim)
    for (a, wa), (b, wb) in zip(spine, spine[1:]):
        cone = np.maximum(cone, capsule(a, b, wa, wb))
    cone *= 1 - poly((0.0, 24.4), (32.0, 27.4), (32.0, 32.0), (0.0, 32.0))
    c.paint(cone, ramp, np.clip(volume(cone, 0.5, 0.5, 2.4) + facet(0.0, 0.016, (1.0, -0.2)), 0, 1), seam=0.6)
    for crease in ([(10.4, 9.4 - tall * 0.8), (13.0, 11.4 - tall * 0.7), (15.4, 10.6 - tall * 0.6)],
                   [(9.6, 14.6 - tall * 0.3), (12.6, 17.4 - tall * 0.2), (12.0, 21.0)],
                   [(17.4, 13.0 - tall * 0.3), (19.0, 17.0), (18.4, 20.6)]):
        c.shade(curve(crease, 0.6), 0.74)
    c.shade(curve([(18.6, 11.0 - tall * 0.4), (20.4, 15.6), (21.2, 20.0)], 0.7), 1.25)
    band = poly((7.4, 19.4), (15.0, 21.8), (22.6, 20.4), (23.0, 23.0), (15.0, 24.8), (7.2, 22.2))
    if tier == "linen":
        c.shade(poly((7.4, 20.6), (15.0, 22.8), (22.6, 21.4), (22.8, 22.4), (15.0, 23.8), (7.3, 21.6)) * cone, 0.62)
    else:
        c.paint(band * cone, "leather" if tier == "sage" else "gold",
                np.clip(volume(band, 0.56, 0.4, 0.8), 0, 1), seam=0.55)
    if tier == "sage":
        part(c, poly((16.6, 20.6), (20.0, 20.0), (20.4, 23.6), (17.0, 24.4)), "gold", 0.72, 0.4, 0.5)
        c.shade(poly((17.6, 21.6), (19.2, 21.3), (19.4, 22.8), (17.8, 23.2)), 0.45)
        for x, y in ((9.6, 21.2), (12.4, 22.2)):
            c.paint(poly((x - 1.3, y), (x, y - 0.9), (x + 1.3, y), (x, y + 0.9)), "sage", facet(0.86), seam=0.7)
        patch = poly((10.6, 13.4), (14.2, 12.8), (14.8, 16.2), (11.0, 16.8))
        c.paint(patch * cone, "leather", np.clip(volume(patch, 0.66, 0.3, 0.6), 0, 1), seam=0.6)
        for a, b in (((10.6, 13.4), (14.2, 12.8)), ((14.2, 12.8), (14.8, 16.2)), ((14.8, 16.2), (11.0, 16.8)),
                     ((11.0, 16.8), (10.6, 13.4))):
            c.shade(capsule(((a[0] * 2 + b[0]) / 3, (a[1] * 2 + b[1]) / 3), ((a[0] + b[0] * 2) / 3, (a[1] + b[1] * 2) / 3),
                            0.4), 0.5)
        feather = poly((21.4, 22.0), (23.6, 13.0), (27.4, 6.4), (28.6, 8.0), (27.4, 14.6), (24.0, 22.6))
        c.paint(feather, "emerald", np.clip(volume(feather, 0.56, 0.4, 0.9), 0.3, 1), seam=0.6)
        c.shade(capsule((22.6, 21.6), (27.6, 8.0), 0.45), 0.6)
        for k in range(4):
            c.shade(capsule((24.0 + k * 0.9, 17.6 - k * 2.6), (26.4 + k * 0.5, 16.4 - k * 2.6), 0.35), 0.72)
    if tier == "archmage":
        gem(c, 17.6, 22.6, 2.0, "sapphire")
        for x, y in ((12.4, 13.6 - tall * 0.3), (17.0, 16.6), (11.8, 6.6 - tall * 0.5)):
            c.paint(poly((x, y - 1.6), (x + 0.5, y - 0.5), (x + 1.6, y), (x + 0.5, y + 0.5), (x, y + 1.6),
                         (x - 0.5, y + 0.5), (x - 1.6, y), (x - 0.5, y - 0.5)), "gold", facet(0.88), seam=0.8)
        part(c, ellipse(*spine[-1][0], 1.5), "gold", 0.72, 0.4, 0.5)
    c.turn(11.0, (16.0, 18.0))
    return c.icon(tier + " hat")


def _plate(tier):
    """Built on the pack cuirass, which is the rung below these: seen from its left front, so the
    near pauldron is a great dome about (9, 10) and the far one a small one flaring off to the
    right at (24, 12); a gorget round a dark neck hole at the top; the breastplate turned to the
    right with its ridge right of centre and the light full on it; the waist drawn in and the
    tassets running down to a point near (19, 31).

    Steel adds to the pack one: the near pauldron in three lames with a rolled rim, fluting fanned
    up the breast from the waist, a riveted gorget, the tassets in lames. Gold adds to that: a fin
    on the near pauldron, every plate edged in bright trim, the fluting turned into an embossed
    sunburst round a set stone, a second stone on the gorget."""
    c = Canvas()
    metal = {"steel": "steel", "gold": "gold", "frost": "frost"}[tier]
    gold = tier == "gold"
    # The steel ramp is pale from end to end, so steel plates sit a step lower on it than gold ones
    # do on theirs, or the lames run together.
    sink = 0.0 if gold else 0.1
    far = np.maximum(ellipse(24.4, 11.6, 4.8, 4.4), poly((24.0, 8.4), (29.6, 12.6), (28.4, 15.6), (24.0, 15.6)))
    c.paint(far, metal, np.clip(volume(far, 0.46 - sink, 0.5, 1.6), 0, 1))
    c.shade(curve([(21.6, 14.4), (25.0, 15.6), (28.6, 14.6)], 0.5), 0.6)
    tassets = poly((12.4, 21.6), (22.8, 21.0), (24.6, 26.4), (19.4, 30.6), (12.4, 28.4), (10.4, 24.6))
    c.paint(tassets, metal, np.clip(volume(tassets, 0.4 - sink, 0.4, 1.8) + facet(0.0, 0.016, (1.0, 0.0)), 0, 1))
    for drop in (0.0, 2.8):
        c.shade(curve([(11.0, 24.2 + drop), (16.0, 25.8 + drop), (23.6, 23.8 + drop)], 0.6), 0.5)
        c.shade(curve([(11.4, 25.0 + drop), (16.0, 26.6 + drop), (23.2, 24.6 + drop)], 0.4), 1.4 if gold else 1.25)
    breast = poly((11.0, 5.6), (21.2, 5.0), (25.6, 10.0), (25.2, 17.0), (22.6, 22.4), (13.2, 23.4), (10.0, 18.0),
                  (9.4, 10.0))
    c.paint(breast, metal, np.clip(volume(breast, 0.5 - sink, 0.55, 3.0) + facet(0.0, 0.024, (1.0, -0.3)), 0, 1), seam=0.45)
    c.shade(curve([(18.6, 7.4), (19.8, 14.0), (19.0, 22.4)], 0.6), 1.4)
    c.shade(curve([(19.6, 7.4), (20.8, 14.0), (20.0, 22.4)], 0.5), 0.72)
    for across in (-5.4, -2.8, 2.4, 4.4):
        fan = [(19.0 + across * 0.35, 21.6), (19.4 + across, 12.6 + abs(across) * 0.5)]
        c.shade(capsule(*fan, 0.6), 0.5)
        c.shade(capsule((fan[0][0] + 0.7, fan[0][1]), (fan[1][0] + 0.7, fan[1][1]), 0.4), 1.5 if gold else 1.3)
    c.shade(curve([(10.6, 19.6), (15.0, 21.6), (22.6, 20.6)], 0.7), 0.55)
    gorget = ellipse(16.4, 5.6, 5.4, 2.8)
    c.paint(gorget, metal, np.clip(volume(gorget, 0.66, 0.4, 0.9), 0, 1), seam=0.55)
    c.paint(ellipse(16.4, 5.0, 3.6, 1.5), "wood", facet(0.04), seam=1.0)
    for x in (12.4, 20.4):
        rivet(c, x, 6.6, metal, 0.6)
    # The near pauldron, lowest lame first so each overlaps the one below it.
    for cx, cy, rx, ry, tone in ((8.6, 16.6, 5.0, 3.4, 0.4), (8.8, 13.8, 6.0, 4.2, 0.5), (9.4, 10.0, 7.0, 6.0, 0.6)):
        lame = ellipse(cx, cy, rx, ry)
        c.paint(lame, metal, np.clip(volume(lame, tone - sink, 0.6, 2.0), 0, 1), seam=0.4, seam_width=0.8)
        c.shade(np.clip(lame - ellipse(cx, cy - 0.9, rx, ry), 0, 1), 1.5 if gold else 1.25)
    rivet(c, 6.0, 11.6, metal, 0.7)
    rivet(c, 12.6, 12.6, metal, 0.7)
    if gold:
        fin = poly((5.0, 7.0), (7.6, 1.6), (9.4, 4.6), (12.0, 2.4), (12.6, 7.0))
        c.paint(fin, "gold", np.clip(volume(fin, 0.7, 0.4, 0.8), 0, 1), seam=0.55)
        c.shade(np.clip(breast - poly((12.0, 6.6), (20.8, 6.0), (24.6, 10.2), (24.2, 16.8), (22.0, 21.4), (13.6, 22.4),
                                      (11.0, 17.8), (10.4, 10.2)), 0, 1), 1.5)
        part(c, ellipse(19.6, 12.0, 3.0), "gold", 0.72, 0.45, 0.9, seam=0.5)
        gem(c, 19.6, 12.0, 2.0, "ruby")
        gem(c, 16.4, 7.6, 1.0, "sapphire")
        c.shade(capsule((4.4, 7.6), (7.0, 5.4), 0.7), 1.8)
    elif tier == "frost":
        # The unique: rime-blue steel, and the ball it is named for packed onto the breast.
        ball = ellipse(19.4, 12.6, 3.4)
        c.paint(ball, "bone", np.clip(volume(ball, 0.86, 0.35, 1.4), 0.5, 1), seam=0.55)
        c.shade(curve([(10.4, 5.6), (16.4, 8.2), (22.0, 5.2)], 0.9), 1.7)
    else:
        rivet(c, 19.4, 10.0, "steel", 0.8)
        for x, y in ((12.8, 22.6), (22.0, 21.8)):
            rivet(c, x, y, "steel", 0.6)
    c.turn(7.0, (16.0, 17.0))
    return c.icon(tier + " plate")


def _jerkin(tier):
    """A sleeveless coat from the front. Raw hide held shut by three thongs; tanned leather, laced
    and belted; the same with capped shoulders and rows of studs; and the dark one, high in the
    collar, crossed with buckled straps, a pouch on the belt."""
    c = Canvas()
    ramp = {"hide": "hide", "leather": "leather", "studded": "studded", "shadow": "shadow"}[tier]
    body = poly((10.4, 3.6), (13.4, 3.0), (16.0, 7.0), (18.6, 3.0), (21.6, 3.6), (25.4, 8.0), (23.4, 13.0),
                (24.6, 28.4), (16.0, 29.8), (7.4, 28.4), (8.6, 13.0), (6.6, 8.0))
    c.paint(body, ramp, np.clip(volume(body, 0.52, 0.45, 3.0) + facet(0.0, 0.012, (1.0, -0.3)), 0, 1))
    c.shade(poly((13.4, 3.0), (16.0, 7.0), (18.6, 3.0), (17.4, 3.0), (16.0, 5.2), (14.6, 3.0)), 0.6)
    c.shade(capsule((16.0, 7.0), (16.0, 29.4), 0.7), 0.6)
    if tier == "hide":
        for y in (11.0, 16.0, 21.0):
            part(c, capsule((13.4, y), (18.6, y + 1.0), 1.0), "cloth", 0.7, 0.3, 0.5, seam=0.7)
        c.shade(curve([(9.6, 18.0), (11.4, 22.0), (10.4, 26.0)], 0.5), 0.75)
        for x in (9.6, 13.0, 19.0, 22.4):
            c.erase(poly((x - 1.0, 30.2), (x, 27.4), (x + 1.0, 30.2)))
        c.turn(LEAN)
        return c.icon("Hide Jerkin")
    for y in (9.0, 12.0, 15.0, 18.0):
        c.shade(capsule((14.2, y), (17.8, y + 1.6), 0.45), 0.5)
        c.shade(capsule((17.8, y), (14.2, y + 1.6), 0.45), 0.5)
    belt = poly((8.0, 21.4), (24.0, 21.4), (24.2, 24.2), (7.8, 24.2))
    part(c, belt, "wood" if tier != "shadow" else "darkiron", 0.42, 0.3, 0.6, seam=0.6)
    part(c, poly((14.2, 20.8), (17.8, 20.8), (17.8, 24.8), (14.2, 24.8)), "gold" if tier != "shadow" else "steel",
         0.7, 0.4, 0.5)
    c.shade(poly((15.2, 21.8), (16.8, 21.8), (16.8, 23.8), (15.2, 23.8)), 0.45)
    if tier in ("studded", "shadow"):
        for side in (-1, 1):
            cap = poly((16 + side * 4.6, 3.0), (16 + side * 10.6, 5.4), (16 + side * 11.6, 10.4), (16 + side * 7.6, 9.4))
            part(c, cap, ramp if tier == "studded" else "darkiron", 0.58 + side * 0.06, 0.45, 1.2)
    if tier == "studded":
        for side in (-1, 1):
            for y in (8.0, 12.0, 16.0, 19.6, 26.6):
                for dx in (4.0, 7.0):
                    if y > 9.0 or dx < 6.0:
                        rivet(c, 16 + side * dx, y, "steel", 0.7)
            rivet(c, 16 + side * 8.6, 6.4, "steel", 0.8)
    if tier == "shadow":
        for side in (-1, 1):
            strap = capsule((16 - side * 8.0, 6.6), (16 + side * 7.4, 20.6), 1.9)
            c.paint(strap * body, "leather", facet(0.4), seam=0.6)
            part(c, ellipse(16 + side * 3.2, 16.6, 1.3), "steel", 0.7, 0.4, 0.5)
        collar = poly((11.4, 1.6), (14.0, 3.6), (16.0, 7.0), (18.0, 3.6), (20.6, 1.6), (21.4, 5.4), (16.0, 9.4), (10.6, 5.4))
        part(c, collar, ramp, 0.62, 0.4, 0.9)
        part(c, poly((19.0, 23.6), (23.4, 23.6), (23.6, 27.8), (19.2, 27.8)), "leather", 0.45, 0.35, 0.7)
        rivet(c, 21.3, 25.0, "steel", 0.6)
    c.turn(LEAN)
    return c.icon(tier + " jerkin")


def _robe(tier):
    """A gown from the front, arms hanging. Linen, roped at the waist; silk, faced down the front
    and sashed; the sage's, cowled and hemmed, wider in the sleeve; the archmage's under a short
    cape, gold at every edge, clasped with a stone."""
    c = Canvas()
    ramp = {"linen": "linen", "silk": "silk", "sage": "sage", "archmage": "archmage"}[tier]
    wide = {"linen": 0.0, "silk": 0.6, "sage": 1.6, "archmage": 1.6}[tier]
    for side in (-1, 1):
        sleeve = poly((16 + side * 5.0, 5.0), (16 + side * 9.6, 7.0), (16 + side * (12.4 + wide), 21.0),
                      (16 + side * (7.4 - wide), 22.4), (16 + side * 6.0, 12.0))
        part(c, sleeve, ramp, 0.46 + side * 0.06, 0.45, 1.8)
        c.shade(ellipse(16 + side * 10.0, 21.4, 2.2 + wide * 0.5, 0.9), 0.45)
        if tier in ("sage", "archmage"):
            c.shade(capsule((16 + side * (7.8 - wide), 20.0), (16 + side * (12.0 + wide), 18.8), 0.6),
                    1.6 if tier == "archmage" else 0.6)
    body = poly((11.6, 3.6), (20.4, 3.6), (22.4, 12.0), (25.0, 29.6), (7.0, 29.6), (9.6, 12.0))
    c.paint(body, ramp, np.clip(volume(body, 0.54, 0.45, 3.0) + facet(0.0, 0.012, (1.0, -0.3)), 0, 1))
    for x0, x1 in ((11.0, 9.4), (20.6, 22.6), (14.0, 13.0)):
        c.shade(curve([(x0, 18.0), ((x0 + x1) / 2, 24.0), (x1, 29.4)], 0.6), 0.78)
    c.shade(poly((13.4, 3.4), (16.0, 7.4), (18.6, 3.4)), 0.5)
    if tier == "linen":
        part(c, capsule((9.8, 16.4), (22.2, 16.4), 1.3), "wood", 0.6, 0.35, 0.5, seam=0.6)
        part(c, capsule((13.4, 16.8), (12.6, 22.0), 1.0), "wood", 0.55, 0.35, 0.5, seam=0.7)
        c.turn(LEAN)
        return c.icon("Linen Robe")
    facing = "gold" if tier == "archmage" else ramp
    for side in (-1, 1):
        c.paint(poly((16 + side * 0.6, 7.4), (16 + side * 2.6, 3.6), (16 + side * 4.0, 3.6), (16 + side * 2.0, 9.0),
                     (16 + side * 2.0, 29.6), (16 + side * 0.6, 29.6)) * body, facing, facet(0.78 if side < 0 else 0.62),
                seam=0.6)
    sash = poly((9.6, 15.0), (22.4, 15.0), (22.8, 18.2), (9.2, 18.2))
    part(c, sash, {"silk": "gold", "sage": "leather", "archmage": "gold"}[tier], 0.55, 0.35, 0.7, seam=0.6)
    if tier in ("sage", "archmage"):
        hem = poly((7.4, 27.0), (24.6, 27.0), (25.0, 29.6), (7.0, 29.6))
        c.paint(hem, "gold" if tier == "archmage" else "cloth", facet(0.66), seam=0.6)
    if tier == "sage":
        cowl = poly((10.6, 2.6), (21.4, 2.6), (23.6, 7.4), (16.0, 11.6), (8.4, 7.4))
        part(c, cowl, ramp, 0.62, 0.45, 1.4)
        c.shade(poly((13.0, 3.4), (19.0, 3.4), (16.0, 8.4)), 0.5)
    if tier == "archmage":
        cape = poly((10.0, 2.4), (22.0, 2.4), (27.0, 9.0), (24.0, 12.6), (16.0, 10.0), (8.0, 12.6), (5.0, 9.0))
        part(c, cape, ramp, 0.62, 0.45, 1.6)
        c.shade(curve([(5.6, 9.4), (8.2, 12.0), (16.0, 9.4), (23.8, 12.0), (26.4, 9.4)], 0.8), 1.7)
        part(c, ellipse(16.0, 6.6, 2.4), "gold", 0.7, 0.4, 0.8)
        gem(c, 16.0, 6.6, 1.6, "sapphire")
        for x, y in ((11.6, 22.6), (20.2, 24.4)):
            c.paint(poly((x, y - 1.4), (x + 0.5, y - 0.5), (x + 1.4, y), (x + 0.5, y + 0.5), (x, y + 1.4),
                         (x - 0.5, y + 0.5), (x - 1.4, y), (x - 0.5, y - 0.5)), "gold", facet(0.85), seam=0.8)
    c.turn(LEAN)
    return c.icon(tier + " robe")


def _boot(tier, kind="boot"):
    """Siblings of the two pack pieces that anchor their rows, built to their measurements. The
    pack boot is seen from the front right and a little above: a cuff from (8, 3) to (21, 8), a
    shaft leaning back to an ankle at (9, 18), the foot swung to the lower right and ending in a
    round toe about (22, 25), lacing up the front of the shaft, and no sole line -- the underside
    is only the darkest of the shading. The pack greave is the same last in plate: the mouth seen
    from above as a dark ellipse, a shin plate, a roundel on the ankle, the foot in lames, a domed
    toe cap.

    A boot adds: a studded band for a cuff, an ankle strap and a capped toe; then a cuff turned down
    in green, two buckled straps and the lacing; then dark leather, a steel toe, three clasps and
    a peaked cuff. A greave adds: bronze in two plain plates; steel with a knee cop, three lames
    and the roundel; gold with all that engraved, a wing on the cop, a spur and a stone."""
    c = Canvas()
    plate = kind == "greaves"
    ramp = {"studded": "studded", "ranger": "leather", "shadow": "shadow", "dominoes": "bluedye",
            "bronze": "bronze", "steel": "steel", "gold": "gold"}[tier]
    under = poly((6.6, 22.0), (9.0, 28.0), (18.0, 30.4), (25.0, 30.0), (28.2, 26.0), (22.0, 27.6), (10.0, 25.0))
    c.paint(under, "wood" if not plate else "darkiron", facet(0.16), seam=1.0)
    shaft = poly((7.6, 5.0), (20.6, 5.6), (19.4, 10.0), (18.4, 16.0), (19.6, 20.0), (8.4, 21.0), (7.2, 14.0))
    c.paint(shaft, ramp, np.clip(volume(shaft, 0.5, 0.45, 2.6) + facet(0.0, 0.014, (1.0, 0.0)), 0, 1))
    foot = np.maximum(poly((7.4, 17.6), (18.6, 15.0), (24.0, 19.4), (27.4, 23.6), (26.4, 28.2), (18.0, 29.2),
                           (9.0, 27.0), (6.6, 22.6)), ellipse(21.6, 24.4, 6.0, 5.0))
    c.paint(foot, ramp, np.clip(volume(foot, 0.5, 0.5, 2.6) + facet(0.0, 0.012, (1.0, -0.5)), 0, 1), seam=0.8)
    c.shade(curve([(8.0, 19.0), (12.0, 20.4), (16.0, 19.4), (19.4, 17.0)], 0.6), 0.7)
    c.shade(ellipse(23.4, 22.6, 2.2, 1.6), 1.3)
    if not plate:
        if tier == "studded":
            part(c, poly((7.0, 3.0), (21.4, 3.6), (20.8, 8.4), (7.2, 7.8)), "leather", 0.62, 0.4, 1.0)
            for x in (9.4, 12.6, 15.8, 19.0):
                rivet(c, x, 5.6 + (x - 9.4) * 0.05, "steel", 0.85)
        elif tier == "ranger":
            part(c, poly((6.4, 2.4), (22.0, 3.0), (21.6, 9.6), (14.0, 8.4), (6.8, 9.2)), "ranger", 0.6, 0.45, 1.2)
            c.shade(curve([(7.0, 8.6), (14.0, 7.8), (21.4, 9.0)], 0.5), 0.6)
        elif tier == "dominoes":
            # The unique: blue-dyed, a gold strap, and a black cuff spotted like the tile it is named for.
            part(c, poly((7.0, 3.0), (21.4, 3.6), (20.8, 9.0), (7.2, 8.4)), "night", 0.5, 0.4, 1.0)
            for x, y in ((9.4, 5.0), (12.4, 7.0), (15.6, 5.2), (18.8, 7.2)):
                c.paint(ellipse(x, y, 0.9), "bone", facet(0.98), seam=0.8)
        else:
            part(c, poly((7.0, 2.2), (14.0, 4.6), (21.4, 2.6), (20.8, 8.2), (14.0, 9.6), (7.2, 7.8)), "shadow",
                 0.7, 0.4, 1.0)
        c.shade(ellipse(14.2, 3.4, 5.4, 0.9), 0.45)
        # The lacing the pack boot wears, up the front of the shaft.
        for y in (10.4, 12.8, 15.2) if tier != "shadow" else ():
            c.shade(capsule((14.4, y), (18.0, y + 1.4), 0.45), 0.5)
            c.shade(capsule((18.0, y), (14.4, y + 1.4), 0.45), 0.5)
        straps = {"studded": (17.6,), "ranger": (11.6, 17.4), "shadow": (10.6, 14.2, 17.8),
                  "dominoes": (17.4,)}[tier]
        for y in straps:
            part(c, poly((7.6, y), (19.2, y - 0.8), (19.4, y + 1.4), (7.8, y + 2.2)), "wood" if tier != "shadow"
                 else "leather", 0.42, 0.3, 0.6, seam=0.6)
            part(c, poly((13.0, y - 0.8), (15.8, y - 1.0), (15.8, y + 2.2), (13.0, y + 2.4)),
                 "gold" if tier in ("ranger", "dominoes") else "steel", 0.74, 0.4, 0.5)
        if tier == "dominoes":
            c.shade(curve([(9.0, 26.6), (18.0, 28.8), (26.0, 27.6)], 0.6), 1.6)
        if tier in ("studded", "shadow"):
            cap = ellipse(22.6, 25.0, 5.0, 4.2) * foot
            c.paint(cap, "darkiron" if tier == "studded" else "iron", np.clip(volume(cap, 0.55, 0.5, 1.8), 0, 1),
                    seam=0.55)
            c.shade(ellipse(24.0, 23.2, 1.6, 1.1), 1.5)
    else:
        mouth = ellipse(13.8, 5.4, 6.4, 2.4)
        part(c, ellipse(13.8, 5.4, 7.2, 3.2), ramp, 0.66, 0.4, 0.8)
        c.paint(mouth, ramp, facet(0.06), seam=1.0)
        c.shade(capsule((14.6, 8.6), (13.6, 19.0), 0.6), 1.4)
        c.shade(capsule((15.6, 8.6), (14.6, 19.0), 0.5), 0.7)
        seams = {"bronze": (20.6,), "steel": (18.0, 20.8, 23.6), "gold": (18.0, 20.8, 23.6)}[tier]
        for x in seams:
            c.shade(capsule((x, 16.4 + (x - 18) * 0.75), (x - 2.4, 28.6), 0.7), 0.5)
            c.shade(capsule((x + 0.9, 17.0 + (x - 18) * 0.75), (x - 1.5, 28.6), 0.45), 1.35)
        cap = ellipse(23.0, 25.0, 4.6, 4.0) * foot
        c.paint(cap, ramp, np.clip(volume(cap, 0.62, 0.5, 1.8), 0, 1), seam=0.55)
        c.shade(ellipse(24.2, 23.4, 1.6, 1.1), 1.5)
        if tier != "bronze":
            part(c, ellipse(10.8, 18.6, 3.0), ramp, 0.62, 0.5, 1.2, seam=0.5)
            rivet(c, 10.8, 18.6, ramp, 0.9)
            cop = poly((9.6, 5.6), (15.0, 3.6), (21.6, 5.0), (22.4, 9.6), (16.6, 12.6), (10.4, 10.6))
            part(c, cop, ramp, 0.66, 0.5, 1.6)
            c.shade(curve([(10.6, 10.2), (16.6, 12.0), (22.0, 9.4)], 0.5), 0.6)
        else:
            rivet(c, 10.6, 18.4, ramp, 0.9)
            rivet(c, 17.4, 9.0, ramp, 0.8)
        if tier == "gold":
            part(c, poly((20.6, 5.0), (27.6, 1.6), (25.0, 5.4), (28.4, 5.6), (24.6, 8.2), (26.6, 9.4), (21.6, 10.0)),
                 "gold", 0.76, 0.4, 0.8)
            gem(c, 16.0, 8.0, 1.7, "ruby")
            part(c, poly((7.0, 23.6), (2.6, 24.6), (4.6, 25.6), (2.8, 27.2), (7.6, 26.4)), "gold", 0.7, 0.4, 0.6)
            for y in (13.6, 15.6):
                c.shade(curve([(9.0, y), (12.0, y + 0.8), (17.4, y - 0.4)], 0.4), 0.6)
            c.shade(capsule((8.0, 26.4), (25.0, 29.0), 0.5), 1.5)
        elif tier == "steel":
            rivet(c, 16.0, 8.0, "steel", 0.9)
    # The pack greave leans over towards its toe a good deal further than the pack boot does.
    c.turn(13.0 if plate else 4.0, (16.0, 17.0))
    return c.icon(tier + " " + kind)


def _slipper(tier):
    """A boot with the leg taken off it: 13 px tall against a boot's 26, which is what the eye
    counts. A plain linen shoe; silk, pointed and piped; the sage's with its toe curled over and a
    buttoned band; the archmage's curled further, gold at the mouth, a stone on the instep and a
    bead on the toe."""
    c = Canvas()
    ramp = {"linen": "linen", "silk": "silk", "sage": "sage", "archmage": "archmage"}[tier]
    curl = {"linen": 0, "silk": 0, "sage": 1, "archmage": 2}[tier]
    part(c, poly((4.4, 24.6), (26.0, 24.6), (25.6, 26.6), (4.8, 26.6)), "wood", 0.34, 0.3, 0.5)
    if tier == "linen":
        shoe = poly((4.6, 15.0), (13.0, 15.6), (19.0, 18.6), (25.6, 21.4), (26.4, 24.8), (4.2, 24.8))
    else:
        shoe = poly((4.6, 14.6), (13.0, 15.2), (19.0, 18.6), (25.0, 20.6), (29.4, 22.4 - curl * 1.4), (27.0, 24.8), (4.2, 24.8))
    c.paint(shoe, ramp, np.clip(volume(shoe, 0.54, 0.5, 2.2), 0, 1))
    if curl:
        tip = curve([(27.6, 22.6), (29.6, 20.4 - curl), (28.6, 17.6 - curl * 1.6), (26.6, 17.8 - curl * 1.4)], 1.9)
        part(c, tip, ramp, 0.6, 0.4, 0.8, seam=0.85)
    mouth = ellipse(9.4, 16.4, 4.2, 1.5)
    c.paint(mouth * shoe, ramp, facet(0.12), seam=1.0)
    if tier != "linen":
        c.shade(ring(9.4, 16.4, 5.0, 4.1, 0.36), 1.7 if tier == "archmage" else 1.35)
    else:
        c.shade(curve([(14.0, 17.6), (16.0, 21.0), (15.0, 24.0)], 0.5), 0.75)
    if tier in ("sage", "archmage"):
        band = poly((13.6, 16.0), (17.0, 17.6), (16.4, 24.6), (12.6, 24.6))
        part(c, band, "leather" if tier == "sage" else "gold", 0.6, 0.35, 0.7, seam=0.6)
        if tier == "sage":
            rivet(c, 14.8, 20.4, "gold", 0.9)
    if tier == "archmage":
        gem(c, 14.8, 20.2, 1.5, "sapphire")
        part(c, ellipse(26.2, 17.0 - 2.6, 1.3), "gold", 0.72, 0.4, 0.5)
        c.shade(capsule((5.0, 24.2), (26.6, 24.2), 0.5), 1.6)
    return c.icon(tier + " slippers")


def _ring(tier):
    """Seen from a little above, the stone towards us. A gold band with a small sapphire in a
    collet; a broad iron band, no stone, a groove round it and four rivets; a ring carved from one
    piece of jade, thick, with a gold sleeve where a stone would sit."""
    c = Canvas()
    x, y = 16.0, 17.4
    ramp, width = {"gold": ("gold", 2.6), "iron": ("iron", 4.0), "jade": ("jade", 3.4)}[tier]
    band = ring(x, y, 9.6, 9.6 - width, 0.92)
    c.paint(band, ramp, np.clip(volume(band, 0.56, 0.5, width * 0.4) + facet(0.0, 0.012, (0.6, -1.0)), 0, 1))
    c.shade(ring(x, y + 0.6, 9.6 - width + 0.7, 9.6 - width, 0.92), 0.6)
    if tier == "iron":
        c.shade(ring(x, y, 7.9, 7.3, 0.92), 0.6)
        for turn in (-135, -45, 45, 135):
            rivet(c, x + 7.6 * math.cos(math.radians(turn)), y + 7.0 * math.sin(math.radians(turn)), "steel", 0.8)
        part(c, poly((12.6, 6.6), (19.4, 6.6), (20.4, 11.6), (11.6, 11.6)), "iron", 0.7, 0.4, 0.9)
        c.shade(capsule((13.6, 9.2), (18.4, 9.2), 0.5), 0.55)
    elif tier == "gold":
        part(c, poly((12.8, 6.4), (19.2, 6.4), (20.0, 10.6), (16.0, 12.0), (12.0, 10.6)), "gold", 0.7, 0.4, 0.8)
        gem(c, 16.0, 7.4, 3.0, "sapphire", 0.9)
    else:
        part(c, poly((12.0, 6.0), (20.0, 6.0), (20.8, 11.4), (11.2, 11.4)), "gold", 0.68, 0.4, 0.9)
        c.shade(capsule((12.4, 8.6), (19.6, 8.6), 0.5), 0.6)
        c.shade(curve([(8.4, 20.0), (10.4, 23.4), (13.6, 25.2)], 0.6), 1.35)
    return c.icon(tier + " ring")


def _chain(c, ramp="gold"):
    """The two runs of links every amulet hangs from, and the bail they meet in."""
    for side in (-1, 1):
        for t in (0.0, 0.2, 0.4, 0.6, 0.8, 1.0):
            part(c, ellipse(16 + side * (1.2 + 8.4 * t ** 0.8), 13.6 - 11.0 * t, 1.15), ramp, 0.56 - side * 0.08, 0.4,
                 0.5, seam=0.75)
    part(c, ring(16.0, 14.2, 2.2, 0.9), ramp, 0.66, 0.4, 0.5)


def _amulet(tier):
    """A chain to a bail, and four different pendants under it, because on jewellery the drawing is
    the only thing that parts one from another: a round ruby in a bezel; a gold sun-disc with no
    stone; a sapphire drop; an emerald, step-cut and square, clawed at the corners."""
    c = Canvas()
    _chain(c)
    if tier == "ruby":
        part(c, ellipse(16.0, 22.0, 7.0), "gold", 0.62, 0.45, 1.0)
        gem(c, 16.0, 22.0, 5.0, "ruby")
        c.shade(ring(16.0, 22.0, 3.0, 2.6), 1.25)
    elif tier == "gold":
        disc = ellipse(16.0, 22.0, 7.2)
        c.paint(disc, "gold", np.clip(volume(disc, 0.58, 0.45, 1.4), 0, 1))
        c.shade(ring(16.0, 22.0, 5.6, 5.0), 0.62)
        part(c, ellipse(16.0, 22.0, 2.2), "gold", 0.74, 0.4, 0.7, seam=0.6)
        for k in range(8):
            turn = math.radians(k * 45)
            c.shade(capsule((16 + 3.0 * math.cos(turn), 22 + 3.0 * math.sin(turn)),
                            (16 + 4.4 * math.cos(turn), 22 + 4.4 * math.sin(turn)), 0.6), 0.6)
    elif tier == "sapphire":
        drop = [(16.0, 14.8), (19.4, 19.0), (21.4, 23.4), (19.6, 27.6), (16.0, 29.0), (12.4, 27.6), (10.6, 23.4), (12.6, 19.0)]
        part(c, poly(*drop), "gold", 0.62, 0.45, 1.0)
        inner = poly(*[(16 + (px - 16) * 0.7, 22.6 + (py - 22.6) * 0.72) for px, py in drop])
        c.paint(inner, "sapphire", np.clip(volume(inner, 0.5, 0.5, 2.2), 0.28, 1), seam=0.6)
        c.shade(poly((14.4, 19.6), (16.0, 18.4), (16.4, 21.6), (14.6, 22.4)), 1.6)
    else:
        frame = poly((11.6, 15.6), (20.4, 15.6), (22.6, 17.8), (22.6, 26.4), (20.4, 28.6), (11.6, 28.6), (9.4, 26.4), (9.4, 17.8))
        part(c, frame, "gold", 0.62, 0.45, 1.0)
        stone = poly((12.4, 17.4), (19.6, 17.4), (20.8, 18.6), (20.8, 25.6), (19.6, 26.8), (12.4, 26.8), (11.2, 25.6), (11.2, 18.6))
        c.paint(stone, "emerald", np.clip(volume(stone, 0.5, 0.45, 1.6), 0.4, 1), seam=0.6)
        table = poly((13.6, 19.4), (18.4, 19.4), (18.4, 24.8), (13.6, 24.8))
        c.paint(table, "emerald", facet(0.62, 0.03), seam=0.8)
        c.shade(poly((13.6, 19.4), (15.6, 19.4), (13.6, 21.6)), 1.6)
        for px, py in ((10.6, 16.8), (21.4, 16.8), (10.6, 27.4), (21.4, 27.4)):
            part(c, ellipse(px, py, 1.2), "gold", 0.78, 0.4, 0.5, seam=0.7)
    return c.icon(tier + " amulet")


# ---------------------------------------------------------------- the ten drawn unique icons
#
# tools/ui_kit.py cut these off Icons.png and doubled them, which is the fault the base jewels were
# redrawn for. Each is the base drawing of its kind -- a ring, an amulet, a boot, a cuirass, a
# shield -- given what UNIQUE_GEAR's comments say it is, and enough of its own that it is not its
# base in another colour.

def _unique_ring(kind):
    """A band of bone, cracked, with the sapphire left in it; the Tithe, gold milled like the edge
    of a coin round a ruby; blood-red iron, riveted, the sapphire left in it; the magpie's band,
    black with a white line round it and a white stone."""
    c = Canvas()
    x, y = 16.0, 17.4
    ramp, width, stone = {"bone": ("bone", 3.2, "sapphire"), "tithe": ("gold", 3.6, "ruby"),
                          "blood": ("blood", 3.4, "sapphire"), "magpie": ("night", 3.2, "bone")}[kind]
    band = ring(x, y, 9.6, 9.6 - width, 0.92)
    c.paint(band, ramp, np.clip(volume(band, 0.56, 0.5, width * 0.4) + facet(0.0, 0.012, (0.6, -1.0)), 0.12, 1))
    c.shade(ring(x, y + 0.6, 9.6 - width + 0.7, 9.6 - width, 0.92), 0.6)
    if kind == "tithe":
        for k in range(-3, 22):
            turn = math.radians(k * 12 + 6)
            c.shade(capsule((x + 8.4 * math.cos(turn), y + 7.8 * math.sin(turn)),
                            (x + 9.6 * math.cos(turn), y + 8.9 * math.sin(turn)), 0.5), 0.55)
    if kind == "bone":
        for turn in (20, 75, 160, 215):
            a = math.radians(turn)
            c.shade(capsule((x + 6.8 * math.cos(a), y + 6.2 * math.sin(a)),
                            (x + 9.0 * math.cos(a + 0.1), y + 8.4 * math.sin(a + 0.1)), 0.4), 0.6)
    if kind == "magpie":
        c.shade(ring(x, y, 8.4, 7.7, 0.92), 2.0)
    if kind == "blood":
        for turn in (-150, -30, 40, 140):
            rivet(c, x + 8.0 * math.cos(math.radians(turn)), y + 7.4 * math.sin(math.radians(turn)), "iron", 0.75)
    collet = poly((12.4, 6.2), (19.6, 6.2), (20.4, 10.8), (16.0, 12.2), (11.6, 10.8))
    c.paint(collet, ramp, np.clip(volume(collet, 0.7, 0.4, 0.8), 0.15, 1), seam=0.55)
    gem(c, 16.0, 7.4, 3.2, stone, 0.9)
    return c.icon(kind + " ring")


def _unique_amulet(kind):
    """An hourglass of glass and pale sand between two gold plates; a grave-violet stone clawed into
    dark iron on an iron chain; and, now that one can be drawn, the die itself -- green, three
    faces showing."""
    c = Canvas()
    _chain(c, "gold" if kind != "grave" else "darkiron")
    if kind == "hourglass":
        for py in (16.2, 28.4):
            part(c, poly((10.6, py - 1.1), (21.4, py - 1.1), (21.4, py + 1.1), (10.6, py + 1.1)), "gold", 0.66, 0.4, 0.6)
        for px in (11.4, 20.6):
            part(c, capsule((px, 16.4), (px, 28.2), 1.0), "gold", 0.56, 0.4, 0.4, seam=0.8)
        glass = np.maximum(poly((12.2, 17.2), (19.8, 17.2), (16.7, 22.3), (15.3, 22.3)),
                           poly((15.3, 22.3), (16.7, 22.3), (19.8, 27.4), (12.2, 27.4)))
        c.paint(glass, "glass", np.clip(volume(glass, 0.62, 0.4, 1.0), 0.3, 1), seam=0.6)
        c.paint(poly((13.2, 25.4), (18.8, 25.4), (19.8, 27.4), (12.2, 27.4)), "topaz", facet(0.8), seam=1.0)
        c.paint(poly((14.4, 19.6), (17.6, 19.6), (16.4, 21.6), (15.6, 21.6)), "topaz", facet(0.8), seam=1.0)
        c.shade(capsule((16.0, 22.0), (16.0, 25.2), 0.4), 1.5)
        c.shade(capsule((13.6, 18.0), (14.6, 20.0), 0.45), 1.7)
    elif kind == "grave":
        part(c, ellipse(16.0, 22.0, 7.0, 7.4), "darkiron", 0.6, 0.45, 1.0)
        stone = ellipse(16.0, 22.0, 5.0, 5.6)
        c.paint(stone, "violet", np.clip(volume(stone, 0.46, 0.5, 2.4), 0.25, 1), seam=0.55)
        c.shade(ellipse(14.4, 19.8, 1.5, 1.2), 1.7)
        for turn in (45, 135, 225, 315):
            a = math.radians(turn)
            part(c, ellipse(16.0 + 5.4 * math.cos(a), 22.0 + 5.9 * math.sin(a), 1.3), "iron", 0.74, 0.4, 0.5, seam=0.7)
    else:
        top = poly((16.0, 15.4), (22.6, 18.4), (16.0, 21.4), (9.4, 18.4))
        left = poly((9.4, 18.4), (16.0, 21.4), (16.0, 29.2), (9.4, 26.2))
        right = poly((16.0, 21.4), (22.6, 18.4), (22.6, 26.2), (16.0, 29.2))
        for face, tone in ((top, 0.78), (left, 0.34), (right, 0.56)):
            c.paint(face, "emerald", np.clip(facet(tone, 0.02), 0.3, 1), seam=0.7)
        c.shade(curve([(9.6, 18.4), (16.0, 21.4), (22.4, 18.4)], 0.45), 1.5)
        c.shade(capsule((16.0, 21.6), (16.0, 29.0), 0.45), 1.35)
        for px, py in ((16.0, 18.4), (11.4, 21.8), (14.0, 26.4), (17.8, 23.4), (19.4, 24.4), (21.0, 21.6)):
            c.paint(ellipse(px, py, 0.85, 0.7), "bone", facet(0.98), seam=0.8)
    return c.icon(kind + " amulet")


## UniqueTable id -> its drawing. tools/ui_kit.py names the same ids in UNIQUE_DRAWN.
UNIQUES = {
    "knucklebone_ring": lambda: _unique_ring("bone"),
    "the_tithe": lambda: _unique_ring("tithe"),
    "berserkers_band": lambda: _unique_ring("blood"),
    "magpies_band": lambda: _unique_ring("magpie"),
    "hourglass_amulet": lambda: _unique_amulet("hourglass"),
    "gravediggers_charm": lambda: _unique_amulet("grave"),
    "gamblers_die": lambda: _unique_amulet("die"),
    "dominoes": lambda: _boot("dominoes"),
    "snowball": lambda: _plate("frost"),
    "bulwark": lambda: _shield("bulwark"),
}


ICONS = {
    "Steel Plate": lambda: _plate("steel"),
    "Golden Plate": lambda: _plate("gold"),
    "Hide Jerkin": lambda: _jerkin("hide"),
    "Leather Jerkin": lambda: _jerkin("leather"),
    "Studded Jerkin": lambda: _jerkin("studded"),
    "Shadow Leathers": lambda: _jerkin("shadow"),
    "Linen Robe": lambda: _robe("linen"),
    "Silk Robe": lambda: _robe("silk"),
    "Sage's Robe": lambda: _robe("sage"),
    "Archmage's Robe": lambda: _robe("archmage"),
    "Studded Boot": lambda: _boot("studded"),
    "Ranger's Boot": lambda: _boot("ranger"),
    "Shadow Boot": lambda: _boot("shadow"),
    "Bronze Greaves": lambda: _boot("bronze", "greaves"),
    "Steel Greaves": lambda: _boot("steel", "greaves"),
    "Golden Greaves": lambda: _boot("gold", "greaves"),
    "Linen Slippers": lambda: _slipper("linen"),
    "Silk Slippers": lambda: _slipper("silk"),
    "Sage's Slippers": lambda: _slipper("sage"),
    "Archmage's Slippers": lambda: _slipper("archmage"),
    "Gold Ring": lambda: _ring("gold"),
    "Iron Band": lambda: _ring("iron"),
    "Jade Ring": lambda: _ring("jade"),
    "Ruby Amulet": lambda: _amulet("ruby"),
    "Gold Amulet": lambda: _amulet("gold"),
    "Sapphire Amulet": lambda: _amulet("sapphire"),
    "Emerald Amulet": lambda: _amulet("emerald"),
    "Golden Helm": _golden_helm,
    "Blazing Torch": _blazing_torch,
    "Hide Hood": lambda: _hood("hide"),
    "Leather Hood": lambda: _hood("leather"),
    "Studded Hood": lambda: _hood("studded"),
    "Shadow Hood": lambda: _hood("shadow"),
    "Apprentice Hat": lambda: _hat("linen"),
    "Sage's Hat": lambda: _hat("sage"),
    "Archmage's Hat": lambda: _hat("archmage"),
    "Steel Sword": lambda: _sword("steel"),
    "Bone Knife": lambda: _dagger("bone"),
    "Iron Dagger": lambda: _dagger("iron"),
    "Steel Stiletto": lambda: _dagger("steel"),
    "Golden Kris": lambda: _dagger("gold"),
    "Wooden Club": lambda: _mace("wood"),
    "Iron Mace": lambda: _mace("iron"),
    "Steel Morningstar": lambda: _mace("steel"),
    "Golden Sceptre": lambda: _mace("gold"),
    "Wooden Greatsword": lambda: _greatsword("wood"),
    "Iron Claymore": lambda: _greatsword("iron"),
    "Steel Zweihander": lambda: _greatsword("steel"),
    "Golden Greatsword": lambda: _greatsword("gold"),
    "Iron Shield": lambda: _shield("iron"),
    "Steel Kite Shield": lambda: _shield("steel"),
    "Golden Aegis": lambda: _shield("gold"),
    "Hide Buckler": lambda: _buckler("hide"),
    "Iron Buckler": lambda: _buckler("iron"),
    "Steel Targe": lambda: _buckler("steel"),
    "Golden Buckler": lambda: _buckler("gold"),
}


def icons():
    """name -> 32x32 RGBA, white border and all: the bases, then the uniques under their ids."""
    return {name: draw() for name, draw in list(ICONS.items()) + list(UNIQUES.items())}
