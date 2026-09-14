"""The primitives, and the things that grow or lie about: roads, rock, water, trees, haze.

What is *built* is not here. Each of the six places builds in its own way out of its own pieces,
and those live in bld_<env>.py -- one file apiece, so that a piece belonging to one culture cannot
be reached by another. That separation is the point rather than the filing: this module used to
hold every building in the game, and what came out of it was six versions of the same castle.

What is left is what every place genuinely shares. A rectangle is a rectangle; a road is a road;
a tree, a rock and a bank of haze belong to the landscape rather than to whoever settled on it.

Light comes from the top left, as in the hex tiles: left faces lit, right faces one ramp step
down, 1 px ink outline on every silhouette.
"""
import random

from arealib import H, W, fbm


def _px(px, x, y, c):
    if 0 <= x < W and 0 <= y < H:
        px[x, y] = c


def rect(px, x0, y0, x1, y1, c):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            _px(px, x, y, c)


def outline(px, x0, y0, x1, y1, c):
    for x in range(x0 - 1, x1 + 2):
        _px(px, x, y0 - 1, c)
        _px(px, x, y1 + 1, c)
    for y in range(y0 - 1, y1 + 2):
        _px(px, x0 - 1, y, c)
        _px(px, x1 + 1, y, c)


def box(px, x0, y0, x1, y1, face, side, ink, lit=None, courses=0):
    """A block seen slightly from the left: lit face, darker right cheek, ink outline.

    `courses` lays a darker line every n rows -- the stone coursing that keeps a big wall from
    reading as a flat grey rectangle at this size.
    """
    rect(px, x0, y0, x1, y1, face)
    rect(px, max(x0, x1 - 1), y0, x1, y1, side)
    if courses:
        for i, y in enumerate(range(y1, y0, -courses)):
            off = 2 * (i % 2)
            for x in range(x0, x1 + 1):
                if (x + off) % 6:
                    _px(px, x, y, side)
    if lit:
        rect(px, x0, y0, x0, y1, lit)
    outline(px, x0, y0, x1, y1, ink)


# ---------------------------------------------------------------- roofs

def gable(px, cx, base, half, h, roof, roof_dk, ink, courses=None):
    """A pitched roof: rows narrowing to a ridge, right slope one step down.

    `courses` lays a darker line every third row, which is what turns a flat triangle into laid
    tile or shingle. Left None the roof is one flat colour a side, which is what the plain hut
    wants -- a small roof with courses on it is just noise.
    """
    for i in range(h):
        w = int(half * (1 - i / max(1, h)))
        y = base - i
        for x in range(cx - w, cx + w + 1):
            c = roof if x <= cx else roof_dk
            if courses is not None and i % 3 == 0:
                c = courses
            _px(px, x, y, c)
        _px(px, cx - w - 1, y, ink)
        _px(px, cx + w + 1, y, ink)
    for x in range(cx - half - 1, cx + half + 2):
        _px(px, x, base + 1, ink)


def battlement(px, x0, x1, y, face, side, ink):
    """Crenellations: a merlon every three pixels along the top of a wall."""
    for x in range(x0, x1 + 1):
        if (x - x0) % 4 < 2:
            _px(px, x, y, face)
            _px(px, x, y - 1, face if (x - x0) % 4 == 0 else side)
            _px(px, x, y - 2, ink)
        else:
            _px(px, x, y - 1, ink)
    _px(px, x0 - 1, y, ink)
    _px(px, x1 + 1, y, ink)


# ---------------------------------------------------------------- buildings


def signpost(px, x, base, p, arm=16, h=30):
    """A post with a plank on it, to say the road goes somewhere."""
    rect(px, x, base - h, x + 1, base, p["fence"])
    rect(px, x - 2, base - h + 1, x + arm, base - h + 8, p["wall"])
    rect(px, x - 2, base - h + 7, x + arm, base - h + 8, p["wall_dk"])
    outline(px, x - 2, base - h + 1, x + arm, base - h + 8, p["ink"])
    for i in range(1, arm - 2, 3):                             # a scratch of writing on the plank
        rect(px, x + i, base - h + 4, x + i, base - h + 4, p["ink"])


def fence(px, x0, x1, base, p, step=5, h=4):
    for x in range(x0, x1 + 1, step):
        rect(px, x, base - h, x, base, p["fence"])
    for y in (base - h + 1, base - h + 3):
        for x in range(x0, x1 + 1):
            _px(px, x, y, p["fence"])


def tree(px, cx, base, h, p, rng):
    """A mid-distance broadleaf: a short trunk under a crown of overlapping lumps.

    The crown has to be wide -- roughly as wide as the tree is tall -- or it reads as a lollipop.
    """
    trunk_h = max(3, h // 4)
    rect(px, cx - 1, base - trunk_h, cx + 1, base, p["trunk"])
    r = max(5, int(h * 0.38))
    cy = base - trunk_h - r + 1
    lobes = [(0, 0, r)] + [(rng.randint(-r, r), rng.randint(-r // 2, r // 3), rng.randint(r // 2, r))
                           for _ in range(rng.randint(3, 5))]
    for dx, dy, rr in lobes:
        for y in range(-rr, rr + 1):
            for x in range(-rr, rr + 1):
                if x * x + y * y * 0.8 <= rr * rr:
                    _px(px, cx + dx + x, cy + dy + y,
                        p["crown_dk"] if (x + y * 2) > rr else p["crown"])
    for y in range(-r, r + 1):                                   # a lit cap on the top left
        for x in range(-r, r + 1):
            if x * x + y * y * 0.8 <= (r - 1) ** 2 and x + y * 2 < -r:
                _px(px, cx + x, cy + y, p["crown_lit"])


def edge_trunk(px, cx, base, w, p, rng, top=0):
    """A near tree trunk running off the top of the frame, to frame the shot in the woods.

    Kept to the outer edge: the middle of the screen belongs to the fight.
    """
    bark, dark, lit = p["trunk"], p["dark"], p["crown_lit"]
    for y in range(top, base):
        flare = int(max(0, (y - (base - 24)) / 8))              # the root flare at the bottom
        x0, x1 = cx - w // 2 - flare, cx + w // 2 + flare
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(1, x1 - x0)
            c = bark if t < 0.75 else dark
            if t < 0.16:
                c = lit
            if rng.random() < 0.10:                             # bark grain
                c = dark if t > 0.3 else bark
            _px(px, x, y, c)
        _px(px, x0 - 1, y, p["ink"])
        _px(px, x1 + 1, y, p["ink"])


def conifer(px, cx, base, h, p):
    """A spruce: stacked triangles, for the cold and the wooded places."""
    rect(px, cx, base - h // 5, cx + 1, base, p["trunk"])
    tiers = 3
    for t in range(tiers):
        top = base - h + t * (h // (tiers + 1))
        bot = top + h // 2
        for i, y in enumerate(range(top, bot)):
            w = int((i / max(1, bot - top)) * (h // 3) + 1)
            for x in range(cx - w, cx + w + 2):
                _px(px, x, y, p["crown"] if x <= cx else p["crown_dk"])


# ---------------------------------------------------------------- road

def road(im, seed, p, ground_top, top=274):
    """The road: one track across the front of the shot, another out in the field behind it.

    The fight happens on the near band, so that is where the road has to be -- a track that only
    recedes to a vanishing point leaves the player standing in a meadow, and at this scale a
    vanishing point is four pixels wide and reads as a spike. Roads on the map run town to town,
    across the view rather than into it. Drawn over the foliage: the road is in front of the grass.
    """
    rng = random.Random(seed)
    px = im.load()
    far = fbm(seed * 11, W, ((3, 1.0), (9, 0.4)))              # the same road, out in the field
    for x in range(W):
        y = 228 + int(far[x] * 9)
        thick = 5 + int(far[x] * 5)
        for dy in range(thick):
            c = p["road"][0] if dy < thick // 2 else p["road"][1]
            _px(px, x, y + dy, p["road"][2] if rng.random() < 0.14 else c)
        _px(px, x, y - 1, p["road_edge"])
        if rng.random() < 0.4:
            _px(px, x, y + thick, p["road_edge"])

    edge = fbm(seed * 3, W, ((4, 1.0), (13, 0.5), (37, 0.25)))
    for x in range(W):                                         # the near band, across the shot
        y0 = top + int(edge[x] * 10) - 5
        for y in range(y0, H):
            d = (y - y0) / max(1, H - y0)
            c = p["road"][0] if d < 0.45 else p["road"][1]
            if rng.random() < 0.12:
                c = p["road"][2]
            _px(px, x, y, c)
        _px(px, x, y0 - 1, p["road_edge"])
        _px(px, x, y0, p["road_edge"] if rng.random() < 0.5 else c)

    for lane in (0.34, 0.63):                                  # cart ruts, following the verge
        drift = fbm(seed * 5 + int(lane * 100), W, ((3, 1.0), (11, 0.4)))
        for x in range(W):
            y = top + int(edge[x] * 10) - 5 + int((H - top) * lane) + int(drift[x] * 5)
            for dy in range(2):
                if rng.random() < 0.75:
                    _px(px, x, y + dy, p["road"][2])
    signpost(px, int(W * 0.15), top + 16, p)
    for _ in range(14):                                        # patches of dry, paler dust
        cx, cy = rng.randrange(W), rng.randrange(top + 8, H)
        rx, ry = rng.randint(10, 34), rng.randint(3, 7)
        for y in range(-ry, ry + 1):
            for x in range(-rx, rx + 1):
                if (x / rx) ** 2 + (y / ry) ** 2 <= 1 and rng.random() < 0.6:
                    _px(px, cx + x, cy + y, p["road"][0])
    for _ in range(int(W * 0.7)):                              # stones kicked out of the surface
        x, y = rng.randrange(W), rng.randrange(top + 6, H)
        _px(px, x, y, p["road_edge"] if rng.random() < 0.5 else p["road"][0])
    return [top + int(v * 10) - 5 for v in edge]


def water(im, seed, cx, half, top, depth, p):
    """Still water, with whatever stands in it hanging upside down underneath.

    A reflection is by definition after everything else, so this goes last in a plan: it samples
    the scene above the waterline and mirrors it down. Drawn any earlier it would reflect an empty
    field. It only ever writes below the line, so nothing it covers was meant to be seen -- which
    is also why the posts of a stilt house end exactly on the line and want no drawing below it.

    The mirror dims toward the water in three fixed steps rather than on a curve. A continuous mix
    is how a limited palette stops being one, which is the lesson the haze at the foot of a crag
    already taught once.
    """
    rng = random.Random(seed)
    px = im.load()
    deep, lit = p["water"], p["water_lit"]
    x0, x1 = max(0, cx - half), min(W, cx + half)
    for x in range(x0, x1):
        for d in range(1, depth + 1):
            y, src = top + d, top - d
            if not (0 <= y < H and 0 <= src < H):
                continue
            o = px[x, src]
            t = d / depth
            mix = (0.45, 0.68, 0.86)[0 if t < 0.22 else 1 if t < 0.55 else 2]
            px[x, y] = tuple(int(a + (b - a) * mix) for a, b in zip(o, deep))
    # A few lines drawn straight across, which is what says the surface is flat and horizontal --
    # a reflection alone reads as a smear. They break and restart, because an unbroken rule at this
    # size reads as a shelf.
    for d in range(2, depth, 3):
        for x in range(x0, x1):
            if rng.random() < 0.34:
                _px(px, x, top + d, lit if rng.random() < 0.6 else deep)
    rect(px, x0, top, x1 - 1, top, lit)                        # the waterline itself


# ---------------------------------------------------------------- what grows in a place
# Trees are terrain rather than architecture, so they stay here where every place can reach them
# -- a palm stands in a desert oasis and over a jungle river both. The buildings that used to sit
# under this banner are in bld_desert.py now; see its docstring for why.


def palm(px, cx, base, h, p, rng):
    """A date palm: a leaning ringed trunk under a spray of fronds.

    A frond is a rib that leaves the crown climbing and then falls away under its own weight, so
    each one is drawn on a curve that rises and droops rather than as a straight spoke -- straight
    spokes at this size read as a thistle. The bare trunk has to stay visible under the crown, or
    the whole thing is a bush: nothing is drawn in the top third but the fronds.
    """
    lean = rng.choice((-1, 1)) * rng.uniform(0.2, 0.6)
    tx = cx
    for i in range(h):
        tx = cx + int(lean * (i / max(1, h)) ** 2 * h * 0.35)
        y = base - i
        _px(px, tx - 1, y, p["crown_lit"] if i % 4 else p["crown_dk"])
        _px(px, tx, y, p["trunk"])
        _px(px, tx + 1, y, p["trunk"] if i % 4 else p["crown_dk"])
        _px(px, tx + 2, y, p["trunk_sh"])
    ty = base - h
    n = rng.randint(9, 12)
    for f in range(n):
        side = -1 if f % 2 else 1
        rise = 0.95 - 0.8 * (f // 2) / max(1, (n - 1) // 2)    # the outer fronds hang the lowest
        reach = int(h * rng.uniform(0.46, 0.64))
        for s in range(reach + 1):
            t = s / max(1, reach)
            x = tx + int(side * t * reach)
            y = ty + int(reach * ((rise + 0.75) * t * t - rise * t))
            c = p["crown_lit"] if side < 0 and t < 0.5 else p["crown_dk"] if t > 0.72 \
                else p["crown"]
            _px(px, x, y, c)
            if s:                                              # the leaflets off the rib
                _px(px, x, y - 1, c)
                _px(px, x, y + 1, p["crown_dk"])
                _px(px, x - side, y, c)
            if s > reach // 2:                                 # the frond thickens as it falls
                _px(px, x, y + 2 if side > 0 else y - 2, p["crown_dk"])
    rect(px, tx - 1, ty - 1, tx + 1, ty, p["crown_dk"])
    for _ in range(rng.randint(2, 5)):                         # dates hanging under the crown
        _px(px, tx + rng.randint(-3, 3), ty + rng.randint(1, 4), p["trunk_lit"])


def mesa(px, rng, cx, base, half, h, p):
    """The rock a kasbah climbs: a strata-banded shoulder of stone, worn flat-ish on top."""
    prof = fbm(rng.randint(0, 9999), 2 * half + 1, ((5, 1.0), (17, 0.45), (41, 0.2)))
    tops = {}
    for i, x in enumerate(range(cx - half, cx + half + 1)):
        t = abs(x - cx) / half
        top = base - int((1 - t ** 1.7) * h * (0.70 + 0.44 * prof[i]))
        tops[x] = top
        for y in range(top, base + 4):
            d = (y - top) / max(1, base - top)
            c = p["crag"] if x < cx else p["crag_dk"]
            if d < 0.10:
                c = p["crag_lit"]
            elif (y + int(prof[i] * 7)) % 9 == 0 and rng.random() < 0.7:
                c = p["crag_dk"]                               # a bedding plane in the rock
            elif rng.random() < 0.05:
                c = p["crag_lit"] if x < cx else p["crag"]
            _px(px, x, y, c)
    for _ in range(max(2, half // 14)):                        # a few gullies washed down a flank
        x = rng.randint(cx - half, cx + half)
        y = tops.get(x, base) + rng.randint(2, 8)
        for _ in range(rng.randint(6, 20)):
            if not (cx - half <= x <= cx + half) or y > base:
                break
            _px(px, x, y, p["crag_dk"])
            y += 1
            x += rng.choice((-1, 0, 0, 0, 1))
    return tops


# ---------------------------------------------------------------- composites
# A plan step names one thing (see areaplan.py), so anything a settlement used to build out of
# three calls and a loop lives here as a piece instead.


def palm_belt(im, seed, x0, x1, base, p, count=9, scrub=1.0):
    """The green foot a desert settlement sits in: date palms over a band of scrub.

    The scrub is what says oasis, and it is also what can ruin the shot -- a continuous green
    stripe across a desert reads as a lawn. It is kept broken and low, and a place with no water
    to speak of (the domed village) passes 0 and gets the palms alone.
    """
    from arealib import clump_layer
    rng = random.Random(seed)
    px = im.load()
    if scrub:
        clump_layer(im, seed + 3, base - 4, base + 6, [p["crown_dk"], p["crown"]],
                    density=1.0 * scrub, size=(2, 5), leaves=(3, 7), width=(5, 11), body=(1, 3))
    for i in range(count):
        x = int(x0 + (x1 - x0) * (i + rng.random()) / count)
        palm(px, x, base + rng.randint(0, 6), rng.randint(22, 34), p, rng)


# ---------------------------------------------------------------- the half-timbered north
# Grass builds in plaster between dark uprights, on a stone footing, under steep clay tile. The
# references are all of the same thing: a gable end facing the lane, a chimney off the ridge, and
# the frame drawn dark enough that the panels between it read as panels.


def mossy(px, x0, y0, x1, y1, p, rng, density=0.10):
    """Moss creeping over old stone. Every grass reference is green where the stone is oldest."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rng.random() < density * (1.0 if y < y0 + (y1 - y0) // 3 else 0.45):
                _px(px, x, y, p["moss"] if rng.random() < 0.6 else p["moss_dk"])


# ---------------------------------------------------------------- the alpine mountains
# The reference village is built on a rock and climbs it: steep dark gables packed tight at a dozen
# heights, stone below and timber above, smoke off every second chimney. What reads at this size is
# the sawtooth of the roofline, so the roofs are steeper than anything else in the set and the walls
# under them are barely more than a footing.


# ---------------------------------------------------------------- cones, thatch and snow
# Three of the remaining references build round rather than square: iron-age roundhouses, snow
# domes, and the cone-thatch houses of Wae Rebo. A cone is not a gable -- its sides swell out as
# they fall, and at this size that curve is the whole difference between thatch and a tent.


# ---------------------------------------------------------------- majesty
# A fortress is the one thing in a backdrop allowed to dominate it. The first pass built them wide
# and low -- dirt's rose twenty-nine pixels above the horizon -- and wide and low is a compound, not
# a stronghold. What makes a castle majestic at this size is height against the sky, a silhouette
# that steps rather than runs flat, and a base you cannot see the bottom of.


def mist(im, seed, cx, half, y, p, height=10):
    """Haze lying at the foot of a crag, so you cannot see where the rock meets the ground.

    It has to *blend* with what is behind it, not speckle over it. The first version replaced
    pixels with a pale cloud colour and drew a bright band straight across the curtain wall, which
    read as damage rather than as air. This mixes toward the horizon colour -- the one already
    agreed with the sky -- strongest at the bottom and gone a dozen rows up.
    """
    rng = random.Random(seed)
    px = im.load()
    haze = p["horizon"]
    n = fbm(seed, max(1, 2 * half), ((3, 1.0), (9, 0.5)))
    for i, x in enumerate(range(cx - half, cx + half)):
        top = y - int(n[i] * height)
        span = max(1, y + 4 - top)
        for yy in range(top, y + 4):
            if not (0 <= x < W and 0 <= yy < H):
                continue
            # Snapped to three steps, not a continuous mix. A blend that can take any value is
            # not a limited palette any more, and `qa.py areas` counts colours for exactly this
            # reason -- the first version put six scenes over the ceiling on its own.
            t = 0.42 * (yy - top) / span + 0.10 * n[i]
            step = 0 if t < 0.14 else 1 if t < 0.30 else 2
            if step and rng.random() < 0.75:
                mix = (0.0, 0.25, 0.5)[step]
                o = px[x, yy]
                px[x, yy] = tuple(int(a + (b - a) * mix) for a, b in zip(o, haze))
