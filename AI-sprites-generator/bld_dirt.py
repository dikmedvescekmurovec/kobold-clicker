"""Daub, thatch and undressed rubble: what the dirt builds with, and nothing anywhere else does.

The references are an iron-age village of thatch roundhouses round a fire, a narrow stone street
with timber balconies over it, and a square keep on a bluff that has already half fallen down. One
culture, and it is the plainest of the six:

  * nothing here is dressed, painted or carved -- mud on a wattle frame, and stone laid as it came
    out of the ground;
  * roofs are fat thatch cones, or they are flat and crenellated, and never anything between;
  * the two marks worth the pixels are the crown of crossed poles over a thatch apex and the
    group of tall narrow lancets in a wall.

That plainness is the risk. A place with no ornament reads as unfinished unless its *shapes* are
strong, so the cone is drawn fatter than any other cone in the set and the keep's top is drawn
dead flat -- the two silhouettes furthest from a steep tiled roof, which is what the grass has.
"""
import random

from areabuild import _px, battlement, box, outline, rect
from arealib import H, W


def pole_crown(px, cx, top, p, rng, n=5, reach=5):
    """The crossed poles standing out of a thatch apex.

    Every roundhouse in the reference has one and it is unmistakable even at four pixels -- a
    spiky asterisk where every other roof in the game has a point, a finial or a chimney. It is
    this environment's signature and it appears on the village, on the town's outbuildings and
    over the fortress's one surviving thatched roof.
    """
    for k in range(n):
        t = -1.0 + 2.0 * k / max(1, n - 1)
        dx = int(t * reach)
        dy = max(3, int(reach * (1.0 - 0.35 * abs(t))))
        for i in range(dy):
            x = cx + int(dx * i / max(1, dy))
            _px(px, x, top - i, p["pole"])
            _px(px, x, top - i - 1, p["ink"] if i >= dy - 2 else p["pole"])


def fat_cone(px, cx, base, half, h, p, band=True):
    """A thatch cone with a belly. Fatter than anything else here builds, on purpose."""
    for i in range(h):
        t = i / max(1, h)
        ww = int(half * (1 - t ** 1.55))                       # holds its width, then goes quickly
        y = base - i
        for x in range(cx - ww, cx + ww + 1):
            _px(px, x, y, p["thatch"] if x <= cx else p["thatch_dk"])
        if band and i % 4 == 2 and i < h - 3:
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y, p["thatch_lit"] if x <= cx else p["thatch"])
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])


def pole_round(px, cx, base, w, h, p, rng):
    """A roundhouse: a low daub drum under a fat thatch cone, crowned with crossed poles.

    The cone comes down nearly to the ground and is much wider than it is tall, which is the whole
    read -- this is the only settlement in the set whose houses are wider than they are high.
    """
    half = max(4, w // 2)
    drum = max(3, h // 4)
    box(px, cx - half, base - drum, cx + half, base, p["daub"], p["daub_dk"], p["ink"],
        lit=p["daub_lit"])
    dw = max(1, half // 4)
    rect(px, cx - dw, base - drum + 1, cx + dw, base - 1, p["dark"])
    cone = max(h - drum, int(half * 1.35))
    fat_cone(px, cx, base - drum - 1, half + 2, cone, p)
    pole_crown(px, cx, base - drum - cone - 1, p, rng, n=5, reach=max(5, cone // 3))


def daub_hall(px, cx, base, w, h, p, rng):
    """The one long building a village has: daub walls under a hipped thatch, poles at each end."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    wall = max(4, h // 2)
    box(px, x0, base - wall, x1, base, p["daub"], p["daub_dk"], p["ink"], lit=p["daub_lit"])
    for x in range(x0 + 3, x1 - 1, 6):
        rect(px, x, base - wall + 2, x, base - wall + 3, p["dark"])
    rect(px, cx - 1, base - max(3, wall - 1), cx + 1, base - 1, p["dark"])
    roof = max(5, h - wall)
    half = w // 2 + 3
    for i in range(roof):
        t = i / max(1, roof)
        ww = int(half * (1 - t * 0.55))
        y = base - wall - 1 - i
        for x in range(cx - ww, cx + ww + 1):
            _px(px, x, y, p["thatch"] if x <= cx else p["thatch_dk"])
        if i % 4 == 2:
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y, p["thatch_lit"] if x <= cx else p["thatch"])
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
    ridge = int(half * 0.45)
    rect(px, cx - ridge, base - wall - roof, cx + ridge, base - wall - roof, p["ink"])
    for side in (-1, 1):
        pole_crown(px, cx + side * ridge, base - wall - roof, p, rng, n=3, reach=4)


def wattle(px, x0, x1, base, p, rng=None, h=6):
    """A woven hurdle fence: uprights with the weave running through them."""
    rng = rng or random.Random(x0)
    for x in range(x0, x1 + 1, 4):
        rect(px, x, base - h, x, base, p["pole"])
    for i in range(1, h, 2):
        for x in range(x0, x1 + 1):
            _px(px, x, base - i, p["fence"] if (x // 3 + i // 2) % 2 else p["daub_lit"])
        rect(px, x0, base - i + 1, x1, base - i + 1, p["ink"])
    rect(px, x0, base - h - 1, x1, base - h - 1, p["ink"])


def hearth(px, cx, base, p, rng=None, h=26):
    """The fire in the middle of the village, and its smoke going up.

    The reference is built around it -- the houses face it -- and it is the only warm thing in an
    environment of browns and greys, so it does the job the ice's lanterns do.
    """
    rng = rng or random.Random(cx)
    rect(px, cx - 7, base, cx + 7, base, p["rubble_dk"])       # the ring of stones
    for x in range(cx - 6, cx + 7):
        _px(px, x, base - 1, p["rubble"] if (x + cx) % 2 else p["rubble_dk"])
    for i in range(6):                                         # the fire itself, and its glow
        ww = max(0, 4 - i)
        rect(px, cx - ww, base - 2 - i, cx + ww, base - 2 - i,
             p["fire_lit"] if i > 1 else p["fire"])
    for x in range(cx - 8, cx + 9):
        _px(px, x, base + 1, p["fire"] if abs(x - cx) < 5 else p["daub_dk"])
    for side in (-1, 1):                                       # a spit over it
        rect(px, cx + side * 5, base - 9, cx + side * 5, base, p["pole"])
    rect(px, cx - 5, base - 9, cx + 5, base - 9, p["pole"])
    x = cx
    for i in range(5, h):                                      # the smoke, drifting as it rises
        x += rng.choice((-1, 0, 0, 1))
        if rng.random() < 0.72 - 0.4 * i / h:
            _px(px, x, base - i, p["smoke"])
            if rng.random() < 0.4:
                _px(px, x + rng.choice((-1, 1)), base - i, p["smoke"])


def rubble_house(px, cx, base, w, h, p, rng):
    """A street house of undressed stone: an arched door, small windows, a balcony if it is tall.

    The town reference is a canyon of these -- they are packed so tight that what you actually see
    is one wall with holes in it, so they are drawn flat-fronted and flush, and the balconies and
    stairs bolted on are what give the front any depth at all.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["rubble"], p["rubble_dk"], p["ink"], lit=p["rubble_lit"],
        courses=4)
    aw = max(1, w // 6)                                        # the arched doorway
    ah = max(5, h // 3)
    for i in range(ah):
        t = i / max(1, ah)
        ww = aw if t < 0.62 else int(aw * (1 - (t - 0.62) / 0.38) ** 0.55)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
    for row in range(ah + 4, h - 2, 7):                        # small windows, a few of them lit
        for x in range(x0 + 3, x1 - 2, 8):
            lit = rng.random() < 0.3
            rect(px, x, base - row, x + 1, base - row + 2, p["glow"] if lit else p["dark"])
    if h >= 20 and rng.random() < 0.6:
        balcony(px, x0 + 1, x1 - 1, base - ah - 3, p, rng)


def balcony(px, x0, x1, y, p, rng=None):
    """A timber balcony with something growing on it. The one soft thing in a stone street."""
    rng = rng or random.Random(x0 + y)
    rect(px, x0 - 1, y, x1 + 1, y, p["beam_dk"])
    rect(px, x0 - 1, y - 1, x1 + 1, y - 1, p["beam"])
    for x in range(x0, x1 + 1, 3):
        rect(px, x, y - 4, x, y - 2, p["beam_dk"])
    rect(px, x0 - 1, y - 5, x1 + 1, y - 5, p["beam"])
    for _ in range((x1 - x0) // 5):                            # pots along the rail
        x = rng.randrange(x0, max(x0 + 1, x1))
        _px(px, x, y - 1, p["roof_dk"])
        _px(px, x, y - 2, p["crown"])
        _px(px, x - 1, y - 2, p["crown_dk"])


def stone_stair(px, x0, x1, base, rise, p):
    """The outside stair every house in the street has, climbing its neighbour's flank."""
    n = max(3, abs(x1 - x0) // 5)
    for i in range(n):
        x = x0 + (x1 - x0) * i // n
        y = base - rise * i // n
        rect(px, x, y, x + max(1, (x1 - x0) // n), base, p["rubble"] if i % 2 else p["rubble_lit"])
        _px(px, x, y - 1, p["ink"])
    rect(px, x0, base, x1, base, p["rubble_dk"])


def lancets(px, cx, y, h, p, n=3, pitch=5):
    """A group of tall narrow windows. The only ornament this culture has.

    Three of them side by side in a blank wall is the whole face of the fortress reference, and at
    this size it is legible where a rose window or a machicolation would be mud.
    """
    for k in range(n):
        x = cx + (k - (n - 1) / 2) * pitch
        x = int(x)
        rect(px, x, y, x, y + h, p["dark"])
        _px(px, x, y - 1, p["dark"])
        _px(px, x - 1, y, p["rubble_dk"])
        _px(px, x + 1, y, p["rubble_dk"])


def rubble_wall(px, x0, x1, base, h, p, crenels=True):
    """A curtain of undressed stone, laid and not cut, crenellated flat along the top."""
    box(px, x0, base - h, x1, base, p["rubble"], p["rubble_dk"], p["ink"], lit=p["rubble_lit"],
        courses=4)
    for x in range(x0 + 5, x1 - 3, 13):
        rect(px, x, base - h + 4, x, base - h + 8, p["dark"])
    if crenels:
        battlement(px, x0, x1, base - h - 1, p["rubble"], p["rubble_dk"], p["ink"])


def lancet_keep(px, cx, base, w, h, p, rng=None):
    """The square keep of the fortress reference: flat-topped, crenellated, lancets in threes.

    Dead flat on top, which is the point. Every other fortress in the set is crowned -- a cone, a
    needle, a gold finial, a rank of teeth -- and this one is a box with the top taken off. That
    is what makes it read as the oldest and the grimmest of them without drawing a single ruin.
    """
    rng = rng or random.Random(cx + h)
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["rubble"], p["rubble_dk"], p["ink"], lit=p["rubble_lit"],
        courses=5)
    for band in range(1, 3):                                   # the string course between storeys
        y = base - h * band // 3
        rect(px, x0, y, x1, y, p["rubble_dk"])
        rect(px, x0, y + 1, x1, y + 1, p["rubble_lit"])
    if h >= 34:
        lancets(px, cx, base - h + 8, max(8, h // 5), p, n=3, pitch=max(4, w // 7))
        lancets(px, cx, base - h + h // 3 + 8, max(6, h // 6), p, n=3, pitch=max(4, w // 7))
    else:
        lancets(px, cx, base - h + 6, max(6, h // 4), p, n=2, pitch=max(4, w // 6))
    aw = max(1, w // 8)
    for i in range(max(6, h // 5)):
        t = i / max(1, max(6, h // 5))
        ww = aw if t < 0.6 else int(aw * (1 - (t - 0.6) / 0.4) ** 0.55)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
    battlement(px, x0 - 1, x1 + 1, base - h - 1, p["rubble"], p["rubble_dk"], p["ink"])


def broken_tower(px, cx, base, w, h, p, rng=None):
    """A tower with its head gone. Drawn top-first, so the break is sky and not a black slab.

    The profile has to be worked out before a single column is filled, or the missing part gets
    painted in the dark of the inside and the skyline grows a shadow it should not have.
    """
    rng = rng or random.Random(cx * 3 + h)
    x0, x1 = cx - w // 2, cx - w // 2 + w
    lean = rng.choice((-1, 1))
    top = {}
    for x in range(x0, x1 + 1):
        e = (x - x0) / max(1, x1 - x0)
        e = e if lean > 0 else 1 - e
        bite = max(3, h // 6)
        top[x] = base - h + int(bite * (0.2 + 1.3 * e ** 1.7)) + rng.randrange(0, 2)
    for x in range(x0, x1 + 1):
        for y in range(top[x], base + 1):
            _px(px, x, y, p["rubble"] if x <= cx else p["rubble_dk"])
        _px(px, x, top[x] - 1, p["ink"])
        if (base - y) % 5 == 0:
            pass
    for y in range(base - h + 6, base - 3, 5):                 # courses, showing it is laid rubble
        rect(px, x0, y, x1, y, p["rubble_dk"])
    rect(px, x0 - 1, base - h + 1, x0 - 1, base, p["ink"])
    rect(px, x1 + 1, base - h + 1, x1 + 1, base, p["ink"])
    if h >= 26:
        lancets(px, cx, base - h + 14, max(6, h // 5), p, n=2, pitch=max(4, w // 5))


def scrub_belt(im, seed, x0, x1, base, p, count=6, scrub=1.0):
    """Dry ground: bare thorn, a few hurdles, and the odd bush that has given up."""
    from areabuild import tree
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        x = rng.randrange(x0, max(x0 + 1, x1))
        tree(px, x, base + rng.randrange(0, 5), rng.randrange(14, 26), p, rng)
    for _ in range(max(1, count // 3)):
        x = rng.randrange(x0, max(x0 + 1, x1))
        wattle(px, x, x + rng.randrange(14, 30), base + rng.randrange(1, 5), p, rng,
               h=rng.randrange(4, 7))
    for _ in range(int(count * 4 * scrub)):
        x = rng.randrange(x0, max(x0 + 1, x1))
        y = base + rng.randrange(1, 7)
        for k in range(rng.randrange(2, 5)):
            _px(px, x + k - 1, y - rng.randrange(0, 3), p["clumps"][rng.randrange(2, 5)])


def rubble_gate(px, cx, base, w, h, p, rng=None):
    """The way in: a square arch punched through a thickened wall, a squat tower each side.

    Squat on purpose. Everything this culture builds is broader than it is tall, and a slim
    flanking tower would borrow a silhouette from a place that dresses its stone.
    """
    rng = rng or random.Random(cx + w)
    half = w // 2
    rubble_wall(px, cx - half, cx + half, base, h, p)
    aw = max(2, w // 7)
    for i in range(h - 3):
        t = i / max(1, h - 3)
        ww = aw if t < 0.7 else int(aw * (1 - (t - 0.7) / 0.3) ** 0.5)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
        _px(px, cx - ww - 1, base - i, p["ink"])
        _px(px, cx + ww + 1, base - i, p["ink"])
    for side in (-1, 1):
        tw = max(7, w // 5)
        tx = cx + side * (half + tw // 2)
        box(px, tx - tw // 2, base - h - 5, tx + tw // 2, base, p["rubble"], p["rubble_dk"],
            p["ink"], lit=p["rubble_lit"], courses=4)
        lancets(px, tx, base - h - 1, max(4, h // 3), p, n=2, pitch=max(3, tw // 3))
        battlement(px, tx - tw // 2 - 1, tx + tw // 2 + 1, base - h - 6, p["rubble"],
                   p["rubble_dk"], p["ink"])
