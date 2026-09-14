"""Rammed earth: everything the desert builds with, and nothing anywhere else does.

The desert is finished. It was drawn from the Ait Benhaddou photographs, it is the hand-written
original the layout engine was generalised from, and it does not change. That is why it lives
here rather than in areabuild.py beside the shared primitives: `merlons` is a kasbah crown and
not a northern battlement, `relief` is the lattice pressed into a mud wall and not masonry, and
the likeliest way any of this moves is somebody improving one of them while writing another
place's kit. In its own file, that cannot happen by accident.

`qa.py frozen` is the other half: twenty hashes of the raw pixels, which say so if it did.
"""
import random

from areabuild import _px, battlement, box, gable, outline, rect
from arealib import fbm


def _batter(px, cx, base, w, h, p, taper, face=None, side=None, lit=None):
    """A block whose walls lean in as they rise. Returns its top row and its half-width there."""
    face = face or p["mud"]
    side = side or p["mud_dk"]
    lit = lit or p["mud_lit"]
    half = max(1, w // 2)
    top, tophalf = base - h, half
    for i in range(h + 1):
        y = base - i
        hw = half - int(i * taper)
        if hw < 1:
            break
        x0, x1 = cx - hw, cx + hw
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            _px(px, x, y, lit if t < 0.16 else side if t > 0.78 else face)
        _px(px, x0 - 1, y, p["ink"])
        _px(px, x1 + 1, y, p["ink"])
        top, tophalf = y, hw
    return top, tophalf


def relief(px, x0, y0, x1, y1, p, step=4):
    """The lattice pressed into the upper courses: a diamond grid, a shade darker than the wall."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if (x + y) % step == 0 or (x - y) % step == 0:
                _px(px, x, y, p["mud_sh"])


def merlons(px, x0, x1, y, p, step=5):
    """A kasbah crown: little pointed teeth, not the square merlons of a northern wall."""
    for x in range(x0, x1 + 1):
        _px(px, x, y, p["mud_lit"] if (x - x0) % 3 else p["mud"])
        _px(px, x, y + 1, p["mud_sh"])
        _px(px, x, y - 1, p["ink"])
    for x in range(x0 + 1, x1, step):
        _px(px, x, y - 1, p["mud"])
        _px(px, x, y - 2, p["ink"])
    _px(px, x0 - 1, y, p["ink"])
    _px(px, x1 + 1, y, p["ink"])


def parapet(px, x0, x1, y, p, notch=True):
    """The lip a flat roof hides behind: a lit course, the shaded deck under it, the odd notch."""
    for x in range(x0, x1 + 1):
        _px(px, x, y, p["mud_lit"])
        _px(px, x, y + 1, p["mud_sh"])
        _px(px, x, y - 1, p["ink"])
    if notch:
        for x in range(x0 + 2, x1 - 1, 6):
            _px(px, x, y - 1, p["mud"])
            _px(px, x, y - 2, p["ink"])


def openings(px, cx, base, hw, h, p, rng, door=True):
    """Doors and windows: holes punched in the earth, the odd one lit from inside."""
    if door and h >= 8:
        d = cx + rng.randint(-2, 2)
        head = base - max(3, min(6, h // 4))                   # a slot, not a cave mouth
        rect(px, d, head, d + 1, base, p["dark"])
        rect(px, d, head - 1, d + 1, head - 1, p["mud_sh"])
    for row in range(max(1, h // 8)):
        y = base - h + 4 + row * 7
        if y > base - 4:
            break
        for x in range(cx - hw + 3, cx + hw - 2, 6):
            if rng.random() < 0.5:
                rect(px, x, y, x, y + 1, p["glow"] if rng.random() < 0.15 else p["dark"])


def mud_house(px, cx, base, w, h, p, rng, taper=0.10, notch=None):
    """One earth house: a battered cube behind a parapet, a dark door, a few window slots."""
    top, hw = _batter(px, cx, base, w, h, p, taper)
    parapet(px, cx - hw, cx + hw, top - 1, p,
            notch=rng.random() < 0.45 if notch is None else notch)
    openings(px, cx, base, hw, h, p, rng)
    if h >= 14 and w >= 16 and rng.random() < 0.4:
        relief(px, cx - hw + 2, top + 3, cx + hw - 2, top + 5, p, step=5)


def mud_dome(px, cx, base, w, h, p, rng):
    """The domed hut of the second reference: a low earth drum under a mud cupola."""
    drum = max(4, int(h * 0.44))             # a clear cube under the cupola
    top, hw = _batter(px, cx, base, w, drum, p, 0.0)
    cap = max(3, h - drum)
    for dy in range(cap + 1):
        span = int(hw * (1 - (dy / cap) ** 2) ** 0.5) if dy < cap else 0
        y = top - dy
        for x in range(cx - span, cx + span + 1):
            t = (x - cx + span) / max(1, 2 * span)
            _px(px, x, y, p["mud_lit"] if t < 0.32 and dy > 1 else
                p["mud_dk"] if t > 0.78 else p["mud"])
        _px(px, cx - span - 1, y, p["ink"])
        _px(px, cx + span + 1, y, p["ink"])
    arch = max(1, min(2, hw // 5))                             # the arched doorway under the dome
    rect(px, cx - arch, base - drum + 2, cx + arch, base, p["dark"])
    for x in range(cx - arch, cx + arch + 1):
        _px(px, x, base - drum + 1, p["dark"] if abs(x - cx) < arch else p["mud_sh"])
    for y in range(base - drum + 2, base + 1):
        _px(px, cx - arch - 1, y, p["mud_sh"])
        _px(px, cx + arch + 1, y, p["mud_sh"])


def kasbah_tower(px, cx, base, w, h, p, rng=None):
    """The corner tower: a tall battered shaft, a band of relief, a crown of pointed teeth."""
    top, hw = _batter(px, cx, base, w, h, p, 0.055)
    relief(px, cx - hw + 1, top + 4, cx + hw - 1, top + 4 + max(3, h // 7), p, step=4)
    merlons(px, cx - hw - 1, cx + hw + 1, top - 1, p, step=max(3, (2 * hw) // 3))
    for i in range(max(1, h // 16)):                           # slit windows up the shaft
        y = top + 12 + i * 12
        if y < base - 5:
            rect(px, cx - 1, y, cx, y + 2, p["dark"])


def mud_wall(px, x0, x1, base, h, p, taper=0.10, crown=True):
    """A curtain of rammed earth: battered, coursed, and crowned with teeth."""
    for i in range(h + 1):
        y = base - i
        inset = int(i * taper * 0.6)
        for x in range(x0 + inset, x1 - inset + 1):
            t = (x - x0) / max(1, x1 - x0)
            c = p["mud"] if i % 7 else p["mud_dk"]
            _px(px, x, y, p["mud_lit"] if t < 0.04 else p["mud_dk"] if t > 0.97 else c)
        _px(px, x0 + inset - 1, y, p["ink"])
        _px(px, x1 - inset + 1, y, p["ink"])
    for y in range(base - h + 4, base - 4, 9):                 # putlog holes, in rows up the face
        for x in range(x0 + 5, x1 - 3, 11):
            _px(px, x, y, p["mud_sh"])
    inset = int(h * taper * 0.6)
    if crown:
        merlons(px, x0 + inset, x1 - inset, base - h - 1, p, step=6)


def mud_gate(px, cx, base, w, h, p):
    """The gate: a keyhole arch through a thickened block, a tower to either side."""
    mud_wall(px, cx - w // 2, cx + w // 2, base, h, p)
    arch = max(2, w // 9)
    spring = base - h // 2
    rect(px, cx - arch, spring, cx + arch, base, p["dark"])
    for i in range(arch + 1):                                  # the round head over the opening
        span = int((arch * arch - i * i) ** 0.5)
        for x in range(cx - span, cx + span + 1):
            _px(px, x, spring - i, p["dark"])
        _px(px, cx - span - 1, spring - i, p["ink"])
        _px(px, cx + span + 1, spring - i, p["ink"])
    for y in range(spring, base + 1):
        _px(px, cx - arch - 1, y, p["ink"])
        _px(px, cx + arch + 1, y, p["ink"])
    kasbah_tower(px, cx - w // 2 - 5, base, 11, h + 12, p)
    kasbah_tower(px, cx + w // 2 + 5, base, 11, h + 12, p)


def mud_keep(px, cx, base, w, h, p, rng=None):
    """The kasbah keep: one earth block, a band of lattice relief, and the hall's slit windows.

    The relief is what carries it -- a blank mud wall this big is a slab, and the pressed lattice
    is the one thing the reference kasbahs all put on their upper courses.
    """
    half = w // 2
    mud_wall(px, cx - half, cx + half, base, h, p)
    top = base - h
    relief(px, cx - half + 6, top + 10, cx + half - 6, top + 16, p, step=5)
    for dx in range(-(half - 12), half - 11, 13):
        rect(px, cx + dx, top + 22, cx + dx + 1, top + 26, p["dark"])


def mud_cluster(px, cx, base, w, h, p, rng):
    """Domed cells sharing one earth compound, sized to fill a plot `w` wide.

    Separate domes evenly spaced read as a row of beehives; what makes it a place people live in
    is that they touch, differ in size, and are fenced in together by one low wall. `n` comes from
    the plot rather than being asked for, so a cluster drops into an ordinary row slot.
    """
    small = h <= 14
    cell = rng.randint(10, 14) if small else rng.randint(17, 26)
    n = max(2, round(w / cell))
    x = cx - (n - 1) * cell // 2
    left = x - cell // 2 - rng.randint(3, 7)
    for _ in range(n):
        ww = cell + rng.randint(-3, 3)
        hh = int(ww * rng.uniform(0.78, 1.0))
        y = base - rng.randint(0, 3)
        if rng.random() < 0.28:
            mud_house(px, x, y, ww, max(9, hh - 4), p, rng)
        else:
            mud_dome(px, x, y, ww, hh, p, rng)
        x += cell - rng.randint(0, 3)
    if not small and rng.random() < 0.75:                      # the compound wall, part of a run
        end = x - int((x - left) * rng.uniform(0.15, 0.6))
        mud_wall(px, left, end, base + 1, rng.randint(4, 7), p, crown=False)
