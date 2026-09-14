"""Thatch and tiers: what the forest builds with, and nothing anywhere else does.

The reference photographs are Indonesian rather than Carpathian -- Wae Rebo's cone houses on a
green terrace, longhouses standing on posts over brown water, and a Balinese temple of split gates
and meru towers. Three photographs of three quite different kinds of place, and one culture runs
through all of them:

  * thatch over dark timber, never a masonry wall;
  * everything steps inward as it rises, in tiers you can count;
  * a finial on every apex -- the one detail small enough to survive at this size and distinctive
    enough to be worth the pixels, and the thing that makes a hut and a temple one people;
  * moss and ferns in every horizontal joint, because in a jungle nothing stays bare.

At 576 px wide a settlement gets about 400 of them and a house about 25, so the cone and the tier
are the whole read. Anything under three pixels is noise at this scale and is not drawn.
"""
import random

from areabuild import _px, box, mossy, rect
from arealib import H, W


def finial(px, cx, top, p, h=5, colour=None):
    """The spike on an apex. Every roof this place builds ends in one.

    Five pixels, and the signature of the whole environment: a cone house, a longhouse ridge and a
    meru all carry it, which is what makes a village and a temple read as built by the same people
    rather than as two unrelated sets of shapes that happen to share a palette.
    """
    c = colour or p["beam_dk"]
    rect(px, cx, top - h, cx, top, c)
    _px(px, cx - 1, top - h + 2, c)                            # the little crossbar
    _px(px, cx + 1, top - h + 2, c)


def fern(px, cx, y, p, rng, n=3):
    """A frond or three in a joint. Drawn on ledges, never on the ground -- scrub does that."""
    for _ in range(n):
        x = cx + rng.randrange(-2, 3)
        up = rng.randrange(2, 4)
        for i in range(up):
            _px(px, x, y - i, p["fern"] if i else p["fern_dk"])
        _px(px, x - 1, y - up + 1, p["fern_dk"])
        _px(px, x + 1, y - up + 1, p["fern_dk"])


def thatch_cone(px, cx, base, w, h, p, rng):
    """Wae Rebo: a thatch cone that comes almost to the ground, on a low ring of stones.

    The cone *is* the house -- there is no wall to speak of -- which is what makes this village
    unmistakable at a glance and unlike every other one in the set. The sides are very slightly
    convex, bellying out low and drawing in to the point: a straight-sided cone reads as a tent,
    and a concave one as a witch's hat.
    """
    half = max(3, w // 2)
    h = max(11, h)
    rect(px, cx - half, base, cx + half, base + 1, p["stone_dk"])          # the ring it stands on
    _px(px, cx - half - 1, base, p["ink"])
    _px(px, cx + half + 1, base, p["ink"])
    for i in range(h):
        t = i / h
        ww = int(half * (1 - t) ** 0.72)                       # convex: a belly low, a point high
        y = base - i
        for x in range(cx - ww, cx + ww + 1):
            left = x <= cx
            _px(px, x, y, p["thatch"] if left else p["thatch_dk"])
        # The courses the thatch is bound in. They are the whole texture of the reference and they
        # are what keeps a cone this size from reading as a tent -- so they are drawn as a lit line
        # over a dark one, which survives at three pixels where a single line does not.
        if i % 4 == 1 and 1 < i < h - 4:
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y, p["thatch_lit"] if x <= cx else p["thatch"])
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y + 1, p["thatch_dk"])
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
    rect(px, cx - half - 1, base - 1, cx + half + 1, base - 1, p["ink"])   # the eave, standing out
    dw = max(1, half // 4)                                     # the one dark slot of a doorway
    rect(px, cx - dw, base - max(5, h // 4), cx + dw, base - 2, p["dark"])
    finial(px, cx, base - h, p, h=max(4, h // 6))


def hip_roof(px, cx, base, half, h, p, band=True):
    """A hipped thatch: four slopes to a short ridge rather than two to a point.

    A gable is a triangle and reads as northern wherever it is drawn. What the river town has is a
    long roof whose ends slope in as well, so the top is a line -- that line, and eaves standing
    well proud of the frame under them, is the entire silhouette.
    """
    for i in range(h):
        t = i / max(1, h)
        ww = int(half * (1 - t * 0.80))
        y = base - i
        lit = band and i % 3 == 0 and i < h - 1
        for x in range(cx - ww, cx + ww + 1):
            left = x <= cx
            _px(px, x, y, (p["thatch_lit"] if left else p["thatch"]) if lit else
                          (p["thatch"] if left else p["thatch_dk"]))
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
    ridge = max(1, int(half * 0.20))
    rect(px, cx - ridge, base - h, cx + ridge, base - h, p["ink"])
    for side in (-1, 1):
        finial(px, cx + side * ridge, base - h, p, h=3)
    return ridge


def stilt_long(px, cx, base, w, h, p, rng):
    """A longhouse on posts over the river, under a long hipped thatch.

    The reference is all frame and roof: a thicket of thin dark posts holding a big pale roof up
    out of the water, with the storey between them open to the air. Walls would make it a shed --
    what carries it is the dark under the roof and the light coming through the gaps.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    legs = max(4, h // 2)
    for x in range(x0 + 1, x1, 3):                             # the thicket of posts
        rect(px, x, base - legs, x, base, p["beam_dk"])
    rect(px, x0, base - legs - 1, x1, base - legs, p["beam"])   # the deck they carry
    rect(px, x0 - 1, base - legs - 2, x1 + 1, base - legs - 2, p["ink"])
    top = base - legs - 3
    storey = max(3, h // 4)
    rect(px, x0 + 1, top - storey, x1 - 1, top, p["dark"])      # the open middle, seen into
    for x in range(x0 + 2, x1 - 1, 4):
        rect(px, x, top - storey, x, top, p["beam"])
    if w >= 18 and rng.random() < 0.75:                        # a lit room along it
        lx = rng.randrange(x0 + 3, max(x0 + 4, x1 - 4))
        rect(px, lx, top - storey + 1, lx + 1, top - 1, p["glow"])
    hip_roof(px, cx, top - storey - 1, w // 2 + 3, max(5, int(w * 0.34)), p)


def meru_tower(px, cx, base, w, h, p, rng=None):
    """A meru: a stone plinth under a stack of thatch roofs, each smaller than the one below.

    The count is the point -- a temple tower is read by counting its tiers -- so they are drawn
    thin and parted by a dark gap rather than packed into a cone, and the gap is what makes them
    countable. The top one carries a gold finial, which is the difference between a temple and a
    very large barn. Anything too short to hold four tiers is drawn as a gate instead.
    """
    rng = rng or random.Random(cx * 7 + h)
    plinth = max(4, h // 6)
    box(px, cx - w // 2, base - plinth, cx + w // 2, base, p["stone"], p["stone_dk"], p["ink"],
        lit=p["stone_lit"], courses=3)
    mossy(px, cx - w // 2, base - plinth, cx + w // 2, base, p, rng, density=0.16)
    # A stack of plates on a pole, not a cone. Each tier is a flat plate two or three pixels deep
    # with daylight under it; it is that gap, not the taper, that makes the tiers countable, and
    # counting them is how a temple tower is read. Taper too fast and it is a fir tree.
    span = h - plinth
    tiers = max(4, min(11, span // 7))
    step = span // tiers
    y = base - plinth - 1
    for t in range(tiers):
        half = max(2, int((w // 2 + 4) * (1 - 0.55 * t / max(1, tiers - 1))))
        th = 2 if step < 8 else 3
        for i in range(th):
            ww = half - i
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y - i, p["thatch"] if x <= cx else p["thatch_dk"])
            _px(px, cx - ww - 1, y - i, p["ink"])
            _px(px, cx + ww + 1, y - i, p["ink"])
        rect(px, cx - half - 1, y + 1, cx + half + 1, y + 1, p["ink"])      # the eave it throws
        if t % 2 == 0:                                         # gilding, caught along an edge
            rect(px, cx - half, y, cx + half, y, p["gold_dk"])
        gap = step - th
        rect(px, cx - 1, y - th - gap + 1, cx + 1, y - th, p["dark"])       # the shaft, in shadow
        _px(px, cx - 2, y - th - gap + 2, p["ink"])
        _px(px, cx + 2, y - th - gap + 2, p["ink"])
        y -= step
    finial(px, cx, y + step - 2, p, h=max(4, h // 12), colour=p["gold"])


def candi_gate(px, cx, base, w, h, p, rng=None):
    """Candi bentar: one gate tower cut down the middle and drawn apart, the path between.

    What makes it Balinese rather than a pair of pillars is the crown, and the crown only works if
    its first course juts out *past* the shaft on both sides. Anchored flush the steps just shrink
    sideways and the thing reads as a post with a hat on. Jutting, they throw a ledge every three
    pixels, the profile becomes a staircase read upward, and every ledge catches moss and fern --
    which is the other half of it, because in the reference nothing has been bare for a century.
    """
    rng = rng or random.Random(cx + h)
    gap = max(3, w // 6)
    limb = max(6, w // 3)
    for side in (-1, 1):
        inner = cx + side * gap
        lc = inner + side * (limb // 2)                         # the limb's own centre
        lh = max(2, limb // 2)
        shaft = int(h * 0.58)
        for i in range(shaft):                                  # the shaft, battered a little
            ww = lh - int(i / max(1, shaft) * lh * 0.22)
            for x in range(lc - ww, lc + ww + 1):
                _px(px, x, base - i, p["stone"] if x <= cx else p["stone_dk"])
            _px(px, lc - ww - 1, base - i, p["ink"])
            _px(px, lc + ww + 1, base - i, p["ink"])
        y = base - shaft
        steps = max(3, (h - shaft) // 3)
        for k in range(steps):
            # The first course is the widest thing on the tower; each one above draws in.
            ww = max(1, int((lh + 2) * (1 - 0.82 * k / max(1, steps - 1))))
            for i in range(3):
                for x in range(lc - ww, lc + ww + 1):
                    _px(px, x, y - i, p["stone_lit"] if i == 2 else
                                      (p["stone"] if x <= cx else p["stone_dk"]))
                _px(px, lc - ww - 1, y - i, p["ink"])
                _px(px, lc + ww + 1, y - i, p["ink"])
            rect(px, lc - ww - 1, y + 1, lc + ww + 1, y + 1, p["ink"])       # the ledge it throws
            if ww > 2 and rng.random() < 0.75:
                fern(px, lc + rng.randrange(-ww, ww + 1), y - 2, p, rng, n=2)
            y -= 4
        mossy(px, lc - lh, base - shaft, lc + lh, base - shaft // 3, p, rng, density=0.22)


def temple_wall(px, x0, x1, base, h, p):
    """The low wall a temple stands behind: coursed stone, sunk panels, moss along the top.

    It is deliberately low. Its job is to give the gates and the merus a line to rise out of, not
    to hide them -- a curtain wall tall enough to defend something would make this a castle, and a
    castle is what every one of these places used to look like.
    """
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=4)
    for x in range(x0 + 4, x1 - 6, 11):                        # the sunk relief panels
        rect(px, x, base - h + 3, x + 5, base - 3, p["stone_dk"])
        rect(px, x + 1, base - h + 4, x + 4, base - 4, p["stone"])
    rect(px, x0 - 1, base - h - 1, x1 + 1, base - h - 1, p["stone_lit"])    # the capping course
    rect(px, x0 - 1, base - h - 2, x1 + 1, base - h - 2, p["ink"])
    mossy(px, x0, base - h, x1, base, p, random.Random(x0 * 3 + h), density=0.22)


def temple_stair(px, cx, base, w, rise, p):
    """The wide flight up to a gate. Every gate in the reference has one and none of them is mean."""
    n = max(3, rise // 2)
    for i in range(n):
        y = base - rise * i // n
        half = int(w / 2 * (1 - 0.3 * i / n))
        rect(px, cx - half, y, cx + half, y, p["stone_lit"] if i % 2 else p["stone"])
        _px(px, cx - half - 1, y, p["ink"])
        _px(px, cx + half + 1, y, p["ink"])


def shrine(px, cx, base, w, h, p, rng=None):
    """A little shrine on a pedestal, with a parasol of tiers on top.

    The reference flanks its stairs with these. They are four pixels wide and they matter: a rank
    of small tiered things at the foot of a big tiered thing is what makes the big one read as
    the middle of something rather than as a tower standing on its own.
    """
    rng = rng or random.Random(cx)
    half = max(1, w // 2)
    box(px, cx - half, base - h, cx + half, base, p["stone"], p["stone_dk"], p["ink"],
        lit=p["stone_lit"])
    y = base - h - 1
    for t in range(max(2, h // 4)):
        ww = max(1, half + 2 - t)                              # wider than its own pedestal, or
        rect(px, cx - ww, y, cx + ww, y, p["thatch"])          # it is a post with a flame on it
        rect(px, cx - ww, y - 1, cx + ww, y - 1, p["thatch_dk"])
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
        y -= 3
    finial(px, cx, y + 2, p, h=3, colour=p["gold"])


def jungle_belt(im, seed, x0, x1, base, p, count=8, scrub=1.0):
    """What a forest settlement sits in: broadleaf, the odd palm, and fern at the foot of it all.

    The other places get a hedgerow. A jungle is not a hedge -- it is a wall of green with things
    of several heights in front of it, which is what stops a row of huts reading as models on a
    table.
    """
    from areabuild import palm, tree
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        x = rng.randrange(x0, max(x0 + 1, x1))
        if rng.random() < 0.28:
            palm(px, x, base + rng.randrange(0, 4), rng.randrange(26, 44), p, rng)
        else:
            tree(px, x, base + rng.randrange(0, 5), rng.randrange(20, 36), p, rng)
    for _ in range(int(count * 5 * scrub)):
        fern(px, rng.randrange(x0, max(x0 + 1, x1)), base + rng.randrange(1, 6), p, rng, n=2)
