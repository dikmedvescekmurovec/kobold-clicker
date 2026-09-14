"""Warm ashlar, dark galleries and red cones: what the mountains build with, and nobody else.

This is the environment whose three reference photographs disagree most -- steep dark slate gables
on a ridge, then flat-roofed tan cubes stacked up a crag, then round towers with red conical caps.
Three cultures, and only one of them can be drawn, so the town's read wins:

  * cut stone, warm tan, laid flat-roofed behind a parapet;
  * dark timber galleries and stairs bolted onto the face of it, which is where all the depth
    comes from -- the blocks themselves are plain;
  * arched openings, never square ones.

The fortress then adds what only it has: round drums under **red** conical caps, a corbel band
under every wall-head, pennants, and a long arcaded viaduct going off the edge of the frame. The
red is the only saturated colour in any of the six environments and it is spent here on purpose --
one glance at a red roof and you know which place you are fighting in.

Warm is the other half of it. The grass builds in stone too, so the two have to differ in
something a glance catches, and the temperature of the stone is that thing.
"""
import random

from areabuild import _px, box, outline, rect
from arealib import H, W


def corbel_band(px, x0, x1, y, p):
    """The row of corbels a wall-head stands proud on.

    It is what tells you a wall is high, because you are being shown its underside. Two rows: a
    lit course jutting out, and the teeth under it picked out in ink.
    """
    for x in range(x0 - 1, x1 + 2):
        _px(px, x, y, p["ochre_lit"])
        _px(px, x, y + 1, p["ink"] if (x - x0) % 3 == 0 else p["ochre_dk"])


def mtn_pennant(px, x, top, p, drop=8):
    """A swallow-tail flag, red over pale. Only the fortress flies them, and only its tallest."""
    rect(px, x, top - drop - 5, x, top, p["ink"])
    for i in range(drop):
        run = max(1, int((drop - i) * 0.95))
        for dx in range(1, run + 1):
            _px(px, x + dx, top - drop - 4 + i,
                (p["banner"] if i < drop // 2 else p["banner_pale"]) if dx < run else p["ink"])
    _px(px, x, top - drop - 6, p["ink"])


def parapet_deck(px, x0, x1, y, p, notch=True):
    """The lip a flat roof hides behind: a lit course, the shaded deck under it, the odd gap."""
    rect(px, x0, y, x1, y, p["ochre_lit"])
    rect(px, x0, y + 1, x1, y + 1, p["ochre_dk"])
    rect(px, x0 - 1, y - 1, x1 + 1, y - 1, p["ink"])
    if notch:
        for x in range(x0 + 3, x1 - 2, 7):
            _px(px, x, y, p["ochre_dk"])


def arch_slots(px, cx, base, hw, h, p, rng, rows=None):
    """Arched window slots. Never square -- a square hole here is somebody else's building."""
    for row in range(6, h - 4, rows or 11):
        for x in range(cx - hw + 4, cx + hw - 3, 10):
            lit = rng.random() < 0.2
            rect(px, x, base - row, x, base - row + 3, p["glow"] if lit else p["dark"])
            _px(px, x, base - row + 4, p["dark"])              # the arched head of the slot
            _px(px, x - 1, base - row + 1, p["ochre_dk"])
            _px(px, x + 1, base - row + 1, p["ochre_dk"])


def ashlar_block(px, cx, base, w, h, p, rng):
    """A flat-roofed cube of cut stone behind a parapet: the unit the whole place is built of.

    Deliberately plain. What makes the town reference read is a dozen of these at a dozen heights
    with dark timber hung off them, so an individual block that fought for attention would wreck
    the stack it belongs to.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["ochre"], p["ochre_dk"], p["ink"], lit=p["ochre_lit"],
        courses=5)
    arch_slots(px, cx, base, w // 2, h, p, rng)
    parapet_deck(px, x0, x1, base - h, p)
    if h >= 22 and rng.random() < 0.55:
        timber_gallery(px, x0 + 1, x1 - 1, base - h // 2, p, rng)


def timber_gallery(px, x0, x1, y, p, rng=None):
    """A dark timber gallery bolted onto a stone face, on brackets.

    This is where the depth in the town reference comes from. Without it a stack of ashlar cubes
    is a stack of boxes; with it the front of the town has something in front of the front.
    """
    rng = rng or random.Random(x0 + y)
    rect(px, x0 - 2, y, x1 + 2, y, p["beam_dk"])               # the deck
    rect(px, x0 - 2, y - 1, x1 + 2, y - 1, p["beam"])
    for x in range(x0 - 1, x1 + 2, 4):                         # the rail above it
        rect(px, x, y - 5, x, y - 2, p["beam_dk"])
    rect(px, x0 - 2, y - 6, x1 + 2, y - 6, p["beam"])
    rect(px, x0 - 2, y - 7, x1 + 2, y - 7, p["ink"])
    for x in range(x0, x1 + 1, 6):                             # the brackets under it
        _px(px, x, y + 1, p["beam_dk"])
        _px(px, x + 1, y + 2, p["beam_dk"])


def gallery_stair(px, x0, x1, base, rise, p):
    """An outside timber stair climbing a stone flank, with its own rail."""
    lo, hi = min(x0, x1), max(x0, x1)
    span = max(1, hi - lo)
    up = 1 if x1 >= x0 else -1
    for x in range(lo, hi + 1):
        t = (x - x0) * up / span if up > 0 else (x1 - x) / span
        t = max(0.0, min(1.0, (x - lo) / span if up > 0 else 1 - (x - lo) / span))
        y = base - int(rise * t)
        rect(px, x, y + 1, x, y + 3, p["beam_dk"])             # the stringer under the treads
        _px(px, x, y, p["beam"] if ((x - lo) // 2) % 2 else p["beam_dk"])
        _px(px, x, y - 5, p["beam"])                           # the handrail, parallel to it
        if (x - lo) % 5 == 0:
            rect(px, x, y - 4, x, y - 1, p["beam_dk"])
            rect(px, x, y + 4, x, base, p["beam_dk"])          # a post down to the ground


def red_drum(px, cx, base, w, h, p, rng=None, flag=False, band=True):
    """A round tower under a red conical cap. The mark the fortress is known by.

    The cone is short and wide -- a tall one is a spire and this place does not build spires. It
    is also the only saturated thing in the environment, so it is drawn with three steps of red
    rather than two, because a flat red triangle at this size reads as a warning sign.
    """
    rng = rng or random.Random(cx + h)
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["ochre"], p["ochre_dk"], p["ink"], lit=p["ochre_lit"],
        courses=5)
    for x in (x0 + 1, x1 - 1):                                 # the round-ness, as two shaded edges
        rect(px, x, base - h, x, base, p["ochre_dk"] if x > cx else p["ochre_lit"])
    arch_slots(px, cx, base, w // 2, h, p, rng, rows=max(7, h // 4))
    if band:
        corbel_band(px, x0, x1, base - h - 1, p)
        top = base - h - 2
    else:
        top = base - h
    cone = max(5, int(w * 0.85))
    half = w // 2 + 2
    for i in range(cone):
        t = i / max(1, cone)
        ww = int(half * (1 - t ** 1.25))
        y = top - i
        for x in range(cx - ww, cx + ww + 1):
            _px(px, x, y, p["redtile_lit"] if x < cx - ww // 3 else
                          (p["redtile"] if x <= cx + ww // 3 else p["redtile_dk"]))
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
    rect(px, cx - half - 1, top + 1, cx + half + 1, top + 1, p["ink"])
    if flag:
        mtn_pennant(px, cx, top - cone, p)


def arcade(px, x0, x1, base, h, p, pointed=True):
    """A run of pointed arches in cut stone: a wall, a terrace front, or the deck of a viaduct."""
    box(px, x0, base - h, x1, base, p["ochre"], p["ochre_dk"], p["ink"], lit=p["ochre_lit"],
        courses=5)
    pitch = max(9, h)
    for x in range(x0 + 4, x1 - pitch + 3, pitch):
        aw = max(1, pitch // 3)
        for i in range(h - 3):
            t = i / max(1, h - 3)
            if not pointed:
                ww = aw if t < 0.6 else int(aw * (1 - (t - 0.6) / 0.4) ** 0.5)
            else:
                ww = aw if t < 0.5 else int(aw * (1 - (t - 0.5) / 0.5) ** 0.62)
            rect(px, x + aw - ww, base - i - 1, x + aw + ww, base - i - 1, p["dark"])
    corbel_band(px, x0, x1, base - h - 1, p)


def viaduct(px, x0, x1, base, p, rng=None, rise=14):
    """The long arcaded bridge the fortress is reached by, running off the edge of the frame.

    It does two jobs. It says the castle is on something you cannot walk onto, and it hides where
    that something meets the ground -- which is the second of this project's three fortress rules,
    done with architecture instead of haze.
    """
    rng = rng or random.Random(x0)
    lo, hi = min(x0, x1), max(x0, x1)
    span = max(1, hi - lo)
    for x in range(lo, hi + 1):
        t = (x - x0) / (x1 - x0) if x1 != x0 else 0
        y = base - int(rise * max(0.0, t) ** 1.4)
        rect(px, x, y - 5, x, y, p["ochre"])
        _px(px, x, y - 6, p["ochre_lit"])
        _px(px, x, y - 7, p["ink"])
        _px(px, x, y + 1, p["ochre_dk"])
    pier = max(18, span // 4)
    for k in range(0, span + 1, pier):                         # the piers, going down out of sight
        x = lo + k
        t = (x - x0) / (x1 - x0) if x1 != x0 else 0
        y = base - int(rise * max(0.0, t) ** 1.4)
        rect(px, x - 2, y + 2, x + 2, base + 10, p["ochre_dk"])
        _px(px, x - 3, y + 2, p["ink"])
        _px(px, x + 3, y + 2, p["ink"])
        for i in range(4, pier - 4):                           # the arch between this pier and the
            xx = x + i                                          # next, pointed like everything else
            if xx > hi:
                break
            u = (i - 4) / max(1, pier - 9)
            d = int(9 * (1 - abs(2 * u - 1) ** 1.6))
            tt = (xx - x0) / (x1 - x0) if x1 != x0 else 0
            yy = base - int(rise * max(0.0, tt) ** 1.4)
            rect(px, xx, yy + 2, xx, yy + 2 + d, p["dark"])


def spur_gate(px, cx, base, w, h, p, rng=None):
    """The way in: a pointed arch under a high block, a red-capped drum hard against each side."""
    rng = rng or random.Random(cx + w)
    half = w // 2
    box(px, cx - half, base - h, cx + half, base, p["ochre"], p["ochre_dk"], p["ink"],
        lit=p["ochre_lit"], courses=5)
    corbel_band(px, cx - half, cx + half, base - h - 1, p)
    aw = max(3, w // 7)
    for i in range(h - 4):
        t = i / max(1, h - 4)
        ww = aw if t < 0.52 else int(aw * (1 - (t - 0.52) / 0.48) ** 0.6)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
        _px(px, cx - ww - 1, base - i, p["ink"])
        _px(px, cx + ww + 1, base - i, p["ink"])
    red_drum(px, cx - half - 6, base, 13, h + 20, p, rng, flag=True)
    red_drum(px, cx + half + 6, base, 13, h + 12, p, rng)


def crag_belt(im, seed, x0, x1, base, p, count=6, scrub=1.0):
    """What a mountain settlement sits in: pine, and the rock it has fallen off."""
    from areabuild import conifer
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        x = rng.randrange(x0, max(x0 + 1, x1))
        conifer(px, x, base + rng.randrange(0, 5), rng.randrange(18, 34), p)
    for _ in range(int(count * 3 * scrub)):                    # boulders off the slope above
        x = rng.randrange(x0, max(x0 + 1, x1))
        y = base + rng.randrange(1, 8)
        r = rng.randrange(2, 5)
        for dy in range(-r, 1):
            ww = int((r * r - dy * dy) ** 0.5)
            for dx in range(-ww, ww + 1):
                _px(px, x + dx, y + dy, p["crag_lit"] if dx < 0 and dy < 0 else
                                        (p["crag"] if dx <= 0 else p["crag_dk"]))
        rect(px, x - r, y + 1, x + r, y + 1, p["ink"])
