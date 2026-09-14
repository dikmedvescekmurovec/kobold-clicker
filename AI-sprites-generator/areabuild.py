"""The things that stand in a backdrop: roads, huts, walls, towers, keeps and trees.

Everything takes its colours from the environment's palette, so a village is the same village in
snow or sand, built out of whatever that place builds with. Light comes from the top left, as in
the hex tiles: left faces lit, right faces one ramp step down, 1 px ink outline on every silhouette.
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


def flat_roof(px, x0, x1, y, roof, roof_dk, ink):
    for x in range(x0, x1 + 1):
        _px(px, x, y, roof if (x - x0) % 4 else roof_dk)
    outline(px, x0, y, x1, y, ink)


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

def hut(px, cx, base, w, h, p, rng):
    """One dwelling: walls, a pitched roof, a door and a lit window."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["wall"], p["wall_dk"], p["ink"])
    gable(px, cx, base - h - 1, w // 2 + 2, max(3, h // 2 + 1), p["roof"], p["roof_dk"], p["ink"])
    door = cx + rng.randint(-1, 1)
    rect(px, door - 1, base - max(3, h // 2), door, base, p["ink"])
    if w >= 9 and h >= 8:
        wx = x0 + 2 if door > cx else x1 - 3
        rect(px, wx, base - h + 2, wx + 1, base - h + 3, p["glow"])


def longhouse(px, cx, base, w, h, p, rng):
    """A bigger building: two storeys, a long roof and a row of windows."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["wall"], p["wall_dk"], p["ink"])
    for x in range(x0, x1 + 1, 5):
        rect(px, x + 1, base - h + 2, x + 2, base - h + 3, p["glow"])
    gable(px, cx, base - h - 1, w // 2 + 2, max(4, h // 3 + 2), p["roof"], p["roof_dk"], p["ink"])
    rect(px, cx - 1, base - h // 2, cx, base, p["ink"])


def tower(px, cx, base, w, h, p, crenels=True, roofed=False):
    """A round-ish tower, either crenellated or capped with a cone."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=6)
    if roofed:
        gable(px, cx, base - h - 1, w // 2 + 2, w, p["roof"], p["roof_dk"], p["ink"])
    elif crenels:
        battlement(px, x0 - 1, x1 + 1, base - h - 1, p["stone"], p["stone_dk"], p["ink"])
    rect(px, cx - 1, base - h + 3, cx, base - h + 5, p["ink"])


def wall_run(px, x0, x1, base, h, p, crenels=True):
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=6)
    if crenels:
        battlement(px, x0, x1, base - h - 1, p["stone"], p["stone_dk"], p["ink"])


def gatehouse(px, cx, base, w, h, p):
    wall_run(px, cx - w // 2, cx + w // 2, base, h, p)
    arch = max(3, w // 5)
    rect(px, cx - arch, base - h // 2, cx + arch, base, p["ink"])
    rect(px, cx - arch + 1, base - h // 2 + 1, cx + arch - 1, base, p["dark"])
    tower(px, cx - w // 2 - 2, base, 7, h + 6, p)
    tower(px, cx + w // 2 + 2, base, 7, h + 6, p)


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
        _px(px, tx + 2, y, p["mud_sh"])
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
        _px(px, tx + rng.randint(-3, 3), ty + rng.randint(1, 4), p["mud_dk"])


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

def keep(px, cx, base, w, h, p, rng=None):
    """The northern keep: one long hall block set back, with a tower on each shoulder.

    The towers overhang the block rather than sitting inside it, which is what stops the keep
    reading as a single wide bar behind the curtain.
    """
    half = w // 2
    wall_run(px, cx - half, cx + half, base, h, p)
    tower(px, cx - half - 6, base, 22, h + 28, p)
    tower(px, cx + half + 6, base, 22, h + 28, p)


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


def hedgerow(im, seed, x0, x1, base, p, count=6, scrub=1.0):
    """What a northern settlement sits in instead of palms: scrub and a few standing trees."""
    from arealib import clump_layer
    rng = random.Random(seed)
    px = im.load()
    if scrub:
        clump_layer(im, seed + 3, base - 3, base + 5, [p["crown_dk"], p["crown"]],
                    density=0.8 * scrub, size=(2, 5), leaves=(3, 7), width=(6, 13), body=(1, 3))
    for i in range(count):
        x = int(x0 + (x1 - x0) * (i + rng.random()) / count)
        tree(px, x, base + rng.randint(0, 4), rng.randint(20, 30), p, rng)


# ---------------------------------------------------------------- the half-timbered north
# Grass builds in plaster between dark uprights, on a stone footing, under steep clay tile. The
# references are all of the same thing: a gable end facing the lane, a chimney off the ridge, and
# the frame drawn dark enough that the panels between it read as panels.

def timbered(px, x0, y0, x1, y1, p, brace=True):
    """A half-timbered panel: pale plaster, dark uprights, a sill line and a gable brace.

    The uprights are what carries it at this size. Below about four pixels a panel has room for
    one upright and nothing else, so the spacing is taken from the width rather than fixed -- an
    even four-pixel grid on a narrow house reads as a fence.
    """
    rect(px, x0, y0, x1, y1, p["plaster"])
    rect(px, x1 - 1, y0, x1, y1, p["plaster_sh"])          # the shaded right cheek
    # Roughly one upright every seven, not every five. On a cottage barely twenty wide the tighter
    # spacing left no panel between the posts and the wall read as stripes rather than as framing.
    span = max(6, (x1 - x0) // max(1, (x1 - x0) // 7))
    for x in range(x0, x1 + 1, span):
        rect(px, x, y0, x, y1, p["beam"])
    rect(px, x0, y0, x1, y0, p["beam"])                    # the plate under the eaves
    rect(px, x0, y1, x1, y1, p["beam"])                    # and the sill
    if brace and y1 - y0 >= 5:                             # one diagonal, the signature of the set
        for i in range(min(x1 - x0, y1 - y0) - 1):
            _px(px, x0 + 1 + i, y1 - 1 - i, p["beam"])


def chimney(px, cx, top, h, p):
    """A stone stack off the ridge, with a lip at the head."""
    rect(px, cx, top - h, cx + 1, top, p["stone"])
    rect(px, cx + 1, top - h, cx + 1, top, p["stone_dk"])
    rect(px, cx - 1, top - h, cx + 2, top - h, p["stone_lit"])
    outline(px, cx, top - h, cx + 1, top, p["ink"])


def cottage(px, cx, base, w, h, p, rng):
    """A gable-end cottage: stone footing, half-timbered storey, steep tile roof.

    The gable faces the lane, because at this size the triangle and its brace are the whole read --
    a cottage turned side-on is a box with a line on top of it. The roof oversails the wall by two,
    which is the one detail that stops it looking like a box with a hat.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    foot = max(2, h // 5)
    box(px, x0, base - foot, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=3)
    timbered(px, x0 + 1, base - h, x1 - 1, base - foot - 1, p, brace=(w >= 16))
    outline(px, x0, base - h, x1, base - foot, p["ink"])
    # The roof takes more of the height than the wall does, as it does in every reference: a
    # cottage split evenly between the two reads as a box wearing a hat.
    roof_h = max(6, int(w * 0.64))
    gable(px, cx, base - h - 1, w // 2 + 2, roof_h, p["tile"], p["tile_dk"], p["ink"],
          courses=p["tile_lit"] if w >= 14 else None)
    if w >= 15:
        chimney(px, cx + w // 4, base - h - roof_h + 2, max(3, roof_h // 3), p)
    door = cx + rng.randint(-1, 1)
    rect(px, door - 1, base - max(4, h // 2), door, base, p["beam_dk"])
    _px(px, door - 1, base - max(4, h // 2), p["beam"])        # the arch over it
    _px(px, door, base - max(4, h // 2), p["beam"])
    if w >= 13:
        wx = x0 + 3 if door > cx else x1 - 4
        rect(px, wx, base - h + 2, wx + 1, base - h + 3, p["glow"])


def townhouse(px, cx, base, w, h, p, rng):
    """The taller sort: a stone lower storey, a timbered upper one jettied over it, a dark roof.

    The jetty -- the upper floor standing a pixel proud of the lower -- is what says town rather
    than farm, and it costs one pixel either side.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    low = base - int(h * 0.55)
    box(px, x0, low, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"], courses=4)
    timbered(px, x0 - 1, base - h, x1 + 1, low - 1, p, brace=(w >= 14))
    outline(px, x0 - 1, base - h, x1 + 1, low - 1, p["ink"])
    roof_h = max(5, int(w * 0.48))
    gable(px, cx, base - h - 1, w // 2 + 3, roof_h, p["shingle"], p["shingle_dk"], p["ink"],
          courses=p["shingle_lit"] if w >= 14 else None)
    if w >= 13:
        chimney(px, x0 + 2, base - h - roof_h + 3, max(4, roof_h // 2), p)
    rect(px, cx - 1, base - max(4, h // 3), cx, base, p["beam_dk"])
    for wx in range(x0 + 2, x1 - 1, 5):                    # the upper floor's lit row of windows
        rect(px, wx, base - h + 3, wx + 1, base - h + 4, p["glow"])


def stair(px, x0, x1, base, rise, p):
    """An external timber stair up a stone flank, as every town reference has."""
    n = max(3, (x1 - x0) // 3)
    for i in range(n):
        x = x0 + (x1 - x0) * i // n
        y = base - rise * i // n
        rect(px, x, y, x + (x1 - x0) // n, y, p["beam"])
        _px(px, x, y + 1, p["beam_dk"])
    for i in range(0, n, 2):                               # the handrail posts
        x = x0 + (x1 - x0) * i // n
        rect(px, x, base - rise * i // n - 4, x, base - rise * i // n, p["beam_dk"])


def turret(px, cx, base, w, h, p):
    """A round stair turret under a tall cone -- the thing the town reference puts on its corner."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=5)
    gable(px, cx, base - h - 1, w // 2 + 1, int(w * 1.5), p["shingle"], p["shingle_dk"], p["ink"])
    for y in range(base - h + 4, base - 3, 6):             # slit windows up the stair
        rect(px, cx, y, cx, y + 1, p["dark"])


def mossy(px, x0, y0, x1, y1, p, rng, density=0.10):
    """Moss creeping over old stone. Every grass reference is green where the stone is oldest."""
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            if rng.random() < density * (1.0 if y < y0 + (y1 - y0) // 3 else 0.45):
                _px(px, x, y, p["moss"] if rng.random() < 0.6 else p["moss_dk"])


def great_hall(px, cx, base, w, h, p, rng):
    """The keep as the grass references draw it: a stone hall under a steep roof, not a blank slab.

    A crenellated block this wide is a grey bar across the shot -- what the reference castles have
    instead is a roof line, a row of tall windows, and moss where the stone is oldest.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=5)
    mossy(px, x0, base - h, x1, base - h + max(2, h // 3), p, rng, density=0.12)
    for wx in range(x0 + 4, x1 - 3, 8):                    # tall lancet windows along the hall
        rect(px, wx, base - h + 4, wx + 1, base - h + max(6, h // 2), p["dark"])
        _px(px, wx, base - h + 3, p["ink"])
        _px(px, wx + 1, base - h + 3, p["ink"])
    gable(px, cx, base - h - 1, w // 2 + 2, max(6, int(w * 0.34)), p["shingle"], p["shingle_dk"],
          p["ink"], courses=p["shingle_lit"])


# ---------------------------------------------------------------- the alpine mountains
# The reference village is built on a rock and climbs it: steep dark gables packed tight at a dozen
# heights, stone below and timber above, smoke off every second chimney. What reads at this size is
# the sawtooth of the roofline, so the roofs are steeper than anything else in the set and the walls
# under them are barely more than a footing.

def chalet(px, cx, base, w, h, p, rng):
    """A steep-gabled mountain house: stone footing, timbered storey, a roof taller than the wall."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    foot = max(2, h // 4)
    box(px, x0, base - foot, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=3)
    timbered(px, x0 + 1, base - h, x1 - 1, base - foot - 1, p, brace=(w >= 17))
    outline(px, x0, base - h, x1, base - foot, p["ink"])
    roof_h = max(7, int(w * 0.78))                         # steeper than anywhere else in the set
    gable(px, cx, base - h - 1, w // 2 + 2, roof_h, p["shingle"], p["shingle_dk"], p["ink"],
          courses=p["shingle_lit"] if w >= 15 else None)
    if w >= 13:
        cx_ch = cx - w // 4
        chimney(px, cx_ch, base - h - roof_h + 3, max(3, roof_h // 4), p)
        if rng.random() < 0.5:                             # smoke, which every reference has
            for i in range(rng.randint(2, 5)):
                _px(px, cx_ch + i // 2, base - h - roof_h - i, p["plaster_sh"])
    door = cx + rng.randint(-1, 1)
    rect(px, door - 1, base - max(3, h // 2), door, base, p["beam_dk"])
    if w >= 14:
        rect(px, x0 + 3, base - h + 2, x0 + 4, base - h + 3, p["glow"])


def gallery(px, cx, base, w, h, p, rng):
    """A terrace block with a timber gallery across it -- the town reference is stacks of these."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=4)
    rail = base - max(4, h // 2)
    rect(px, x0 - 1, rail, x1 + 1, rail, p["beam"])        # the gallery deck, proud of the wall
    rect(px, x0 - 1, rail - 3, x1 + 1, rail - 3, p["beam_dk"])
    for x in range(x0, x1 + 1, 4):                         # its posts
        rect(px, x, rail - 3, x, rail, p["beam_dk"])
    roof_h = max(5, int(w * 0.42))
    gable(px, cx, base - h - 1, w // 2 + 2, roof_h, p["shingle"], p["shingle_dk"], p["ink"],
          courses=p["shingle_lit"] if w >= 15 else None)
    for wx in range(x0 + 2, x1 - 1, 6):
        rect(px, wx, base - h + 3, wx + 1, base - h + 4, p["glow"])


def palisade(px, x0, x1, base, p, h=10):
    """A run of sharpened stakes, the fence the mountain village is closed off with."""
    for x in range(x0, x1 + 1, 3):
        rect(px, x, base - h, x + 1, base, p["beam"])
        _px(px, x, base - h, p["beam_dk"])
        _px(px, x + 1, base - h + 1, p["beam_dk"])
    rect(px, x0, base - h + 4, x1, base - h + 4, p["beam_dk"])


# ---------------------------------------------------------------- cones, thatch and snow
# Three of the remaining references build round rather than square: iron-age roundhouses, snow
# domes, and the cone-thatch houses of Wae Rebo. A cone is not a gable -- its sides swell out as
# they fall, and at this size that curve is the whole difference between thatch and a tent.

def cone_roof(px, cx, base, half, h, face, dark, ink, band=None, fill=1.35):
    """A conical thatch roof: rows narrowing to a point on a curve, not a straight slope."""
    for i in range(h):
        t = i / max(1, h)
        w = int(half * (1 - t ** fill))
        y = base - i
        for x in range(cx - w, cx + w + 1):
            c = face if x <= cx else dark
            if band is not None and i % 4 == 0 and i < h - 2:
                c = band
            _px(px, x, y, c)
        _px(px, cx - w - 1, y, ink)
        _px(px, cx + w + 1, y, ink)
    _px(px, cx, base - h, ink)


def roundhouse(px, cx, base, w, h, p, rng):
    """An iron-age roundhouse: a low wattle drum under a thatch cone that reaches nearly to it."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    drum = max(3, h // 3)
    box(px, x0, base - drum, x1, base, p["plaster"], p["plaster_sh"], p["ink"])
    for x in range(x0 + 1, x1, 3):                          # wattle, the one mark on a bare drum
        rect(px, x, base - drum + 1, x, base - 1, p["plaster_sh"])
    cone_roof(px, cx, base - drum - 1, w // 2 + 2, max(8, int(w * 0.95)),
              p["thatch"], p["thatch_dk"], p["ink"],
              band=p["thatch_lit"] if w >= 13 else None)
    door = cx + rng.randint(-1, 1)
    rect(px, door - 1, base - drum + 1, door, base, p["dark"])


def ruin(px, cx, base, w, h, p, rng):
    """A roofless keep, majestic in the way only something enormous and broken is.

    The break is worked out FIRST and the wall is then drawn only up to it. Painting the missing
    part dark instead -- which is what the first version did -- puts a black slab on the skyline
    where there should be nothing but sky.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    bite = max(4, h // 7)
    lean = rng.choice((-1, 1))
    jag = [rng.randint(0, 3) for _ in range(x1 - x0 + 1)]
    top = {}
    for i, x in enumerate(range(x0, x1 + 1)):
        t = i / max(1, x1 - x0)
        edge = t if lean > 0 else 1 - t
        top[x] = base - h + int(bite * (0.25 + 1.15 * edge ** 1.6)) + jag[i]
    lo = min(top.values())
    for x in range(x0, x1 + 1):
        face = p["stone_lit"] if x == x0 else p["stone_dk"] if x >= x1 - 1 else p["stone"]
        rect(px, x, top[x], x, base, face)
        for y in range(top[x] + 4, base, 5):               # coursing, on every column
            _px(px, x, y, p["stone_dk"] if (x + y) % 6 else p["stone"])
        _px(px, x, top[x], p["ink"])                       # the raw broken edge
        _px(px, x, top[x] + 1, p["dark"])
    for y in range(lo, base + 1):                          # the two standing corners
        _px(px, x0 - 1, y, p["ink"])
        _px(px, x1 + 1, y, p["ink"])
    mossy(px, x0, lo, x1, lo + max(6, h // 3), p, rng, density=0.18)
    crack = cx + rng.randint(-w // 4, w // 4)              # a split running down from the break
    y = top.get(crack, lo) + 3
    while y < base - h // 3:
        _px(px, crack, y, p["dark"])
        _px(px, crack + 1, y, p["stone_dk"])
        y += 1
        crack += rng.choice((-1, 0, 0, 1))
    # Openings, in two storeys. Tall thin ones every seven pixels are not windows, they are
    # stripes -- at this size a window is five or six pixels and there are not many of them.
    for wx in range(x0 + 5, x1 - 4, 13):
        for storey in (0, 1):
            wy = top.get(wx, lo) + 8 + storey * max(14, h // 4)
            if wy + 6 < base - 2:
                rect(px, wx, wy, wx + 1, wy + 5, p["dark"])
                _px(px, wx, wy - 1, p["ink"])
                _px(px, wx + 1, wy - 1, p["ink"])


def igloo(px, cx, base, w, h, p, rng):
    """A snow dome with a timber door: the ice village reference, more or less exactly."""
    r = max(4, w // 2)
    for dy in range(r + 1):
        half = int((r * r - dy * dy) ** 0.5)
        y = base - dy
        for x in range(cx - half, cx + half + 1):
            c = p["cap"] if (x - cx) - dy < -r // 2 else p["thatch"] if x <= cx else p["thatch_dk"]
            _px(px, x, y, c)
        _px(px, cx - half - 1, y, p["ink"])
        _px(px, cx + half + 1, y, p["ink"])
    for i in range(1, r, 3):                                # the courses of cut blocks
        half = int((r * r - i * i) ** 0.5)
        for x in range(cx - half + 1, cx + half):
            _px(px, x, base - i, p["cap_sh"])
    dw = max(2, r // 3)
    rect(px, cx - dw, base - dw - 2, cx + dw, base, p["cap"])
    rect(px, cx - dw + 1, base - dw - 1, cx + dw - 1, base, p["beam"])
    outline(px, cx - dw, base - dw - 2, cx + dw, base, p["ink"])


def snowhouse(px, cx, base, w, h, p, rng):
    """Dark timber under a thick cap of settled snow, with the one warm window that carries it."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["beam"], p["beam_dk"], p["ink"])
    for y in range(base - h + 1, base, 2):                  # log courses
        rect(px, x0 + 1, y, x1 - 1, y, p["beam_dk"])
    roof_h = max(6, int(w * 0.6))
    gable(px, cx, base - h - 1, w // 2 + 3, roof_h, p["shingle"], p["shingle_dk"], p["ink"])
    for i in range(max(2, roof_h // 3)):                    # snow lying on it, thickest at the eaves
        t = i / max(1, roof_h)
        half = int((w // 2 + 3) * (1 - t)) - i
        for x in range(cx - half, cx + half + 1):
            _px(px, x, base - h - 1 - i, p["cap"] if x <= cx else p["cap_sh"])
    rect(px, cx - 1, base - max(3, h // 2), cx, base, p["dark"])
    if w >= 12:
        rect(px, x0 + 2, base - h + 2, x0 + 3, base - h + 3, p["glow"])
        rect(px, x1 - 3, base - h + 2, x1 - 2, base - h + 3, p["glow"])


def ice_spire(px, cx, base, w, h, p, rng=None):
    """A needle of carved ice: the palace reference is a dozen of these at a dozen heights."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["tile_lit"], p["tile"], p["ink"], lit=p["thatch_lit"])
    for y in range(base - h + 3, base - 2, 5):              # the facets catching the light
        rect(px, x0 + 1, y, x1 - 1, y, p["tile"])
    cone_roof(px, cx, base - h - 1, w // 2 + 1, int(w * 2.6), p["thatch_lit"], p["tile_lit"],
              p["ink"], fill=2.2)


def cone_house(px, cx, base, w, h, p, rng):
    """Wae Rebo: a thatch cone that comes almost to the ground, banded, on a low stone ring."""
    r = max(4, w // 2)
    rect(px, cx - r, base, cx + r, base + 1, p["stone_dk"])
    cone_roof(px, cx, base, r + 1, max(12, int(w * 1.5)), p["thatch"], p["thatch_dk"], p["ink"],
              band=p["thatch_lit"], fill=1.9)
    dw = max(1, r // 3)
    rect(px, cx - dw, base - max(4, r), cx + dw, base, p["dark"])
    _px(px, cx, base - max(5, r) - 1, p["beam_dk"])         # the finial every one of them has


def stilt_house(px, cx, base, w, h, p, rng):
    """A longhouse standing on posts over the water, under a low hipped thatch."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    legs = max(3, h // 3)
    for x in range(x0 + 1, x1, 4):
        rect(px, x, base - legs, x, base, p["beam_dk"])
    rect(px, x0, base - legs - 1, x1, base - legs, p["beam"])
    box(px, x0, base - h, x1, base - legs - 1, p["plaster"], p["plaster_sh"], p["ink"])
    for x in range(x0 + 2, x1 - 1, 5):
        rect(px, x, base - h + 2, x + 1, base - h + 3, p["dark"])
    roof_h = max(5, int(w * 0.36))
    gable(px, cx, base - h - 1, w // 2 + 4, roof_h, p["thatch"], p["thatch_dk"], p["ink"],
          courses=p["thatch_lit"] if w >= 16 else None)


def meru(px, cx, base, w, h, p, rng):
    """A tiered temple tower: stacked thatch roofs, each smaller, on a stone plinth.

    The tiers are what says temple. Below three they read as a lumpy roof, so a meru narrow enough
    to fit only two is not drawn as one -- it is drawn as a gate instead.
    """
    tiers = max(3, min(7, h // 7))
    box(px, cx - w // 2, base - max(4, h // 5), cx + w // 2, base, p["stone"], p["stone_dk"],
        p["ink"], lit=p["stone_lit"], courses=3)
    y = base - max(4, h // 5)
    for t in range(tiers):
        half = int((w // 2 + 3) * (1 - t / (tiers + 0.6)))
        th = max(3, (h // tiers) // 2 + 2)
        for i in range(th):
            ww = int(half * (1 - i / max(1, th)) ** 0.7)
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y - i, p["thatch"] if x <= cx else p["thatch_dk"])
            _px(px, cx - ww - 1, y - i, p["ink"])
            _px(px, cx + ww + 1, y - i, p["ink"])
        for x in range(cx - half - 1, cx + half + 2):       # the eaves line of each tier
            _px(px, x, y + 1, p["ink"])
        y -= th + max(1, h // (tiers * 4))
    rect(px, cx, y - 2, cx, y, p["beam_dk"])


def split_gate(px, cx, base, w, h, p, rng=None):
    """Candi bentar: one tower cut down the middle and pulled apart, the path running between."""
    gap = max(3, w // 5)
    for side in (-1, 1):
        x0 = cx + side * gap
        x1 = x0 + side * max(4, w // 3)
        lo, hi = min(x0, x1), max(x0, x1)
        for i in range(h):
            t = i / max(1, h)
            inset = int(t * (hi - lo) * 0.32)
            a, b = (lo + inset, hi) if side < 0 else (lo, hi - inset)
            for x in range(a, b + 1):
                c = p["stone"] if x <= cx else p["stone_dk"]
                if i % 4 == 0:
                    c = p["stone_dk"]
                _px(px, x, base - i, c)
            _px(px, a - 1, base - i, p["ink"])
            _px(px, b + 1, base - i, p["ink"])
        mossy(px, lo, base - h, hi, base - h // 2, p, random.Random(cx + side), density=0.18)


# ---------------------------------------------------------------- majesty
# A fortress is the one thing in a backdrop allowed to dominate it. The first pass built them wide
# and low -- dirt's rose twenty-nine pixels above the horizon -- and wide and low is a compound, not
# a stronghold. What makes a castle majestic at this size is height against the sky, a silhouette
# that steps rather than runs flat, and a base you cannot see the bottom of.

def pennant(px, x, top, p, colour=None, drop=7):
    """A staff and a swallow-tail flag. Two of these on a skyline do more than another tower."""
    c = colour or p["tile"]
    rect(px, x, top - drop - 4, x, top, p["ink"])
    for i in range(drop):
        run = max(1, int((drop - i) * 0.9))
        for dx in range(1, run + 1):
            _px(px, x + dx, top - drop - 3 + i, c if dx < run else p["ink"])
    _px(px, x, top - drop - 5, p["ink"])


def machicolation(px, x0, x1, y, p):
    """The corbelled band a wall-head stands proud on. One row of teeth under a jutting course --
    it is what tells you a wall is high, because you are being shown its underside."""
    for x in range(x0 - 1, x1 + 2):
        _px(px, x, y, p["stone_lit"])
        _px(px, x, y + 1, p["ink"] if (x - x0) % 3 == 0 else p["stone_dk"])


def grand_tower(px, cx, base, w, h, p, rng=None, roofed=False, flag=False, tiers=True):
    """A tower built to be seen from a long way off.

    Everything here is about reading height: courses all the way up, a string course every third of
    it, windows that get smaller as they climb, a machicolated head, and a cone or a crown on top.
    A plain box at this height reads as a chimney.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=5)
    if tiers:
        for k in (1, 2):                                   # string courses, dividing the shaft
            y = base - h * k // 3
            rect(px, x0 - 1, y, x1 + 1, y, p["stone_lit"])
            rect(px, x0 - 1, y + 1, x1 + 1, y + 1, p["stone_dk"])
    step = max(9, h // 6)
    for i, y in enumerate(range(base - h + 6, base - 4, step)):
        ww = 1 if i < 2 else 0                             # the openings narrow as they climb
        rect(px, cx - ww, y, cx + ww, y + min(4, step // 2), p["dark"])
    machicolation(px, x0, x1, base - h - 1, p)
    if roofed:
        cone_roof(px, cx, base - h - 2, w // 2 + 2, int(w * 1.9), p["tile"], p["tile_dk"],
                  p["ink"], fill=1.8)
        if flag:
            pennant(px, cx, base - h - 2 - int(w * 1.9), p)
    else:
        battlement(px, x0 - 1, x1 + 1, base - h - 2, p["stone"], p["stone_dk"], p["ink"])
        if flag:
            pennant(px, cx, base - h - 5, p)


def curtain(px, x0, x1, base, h, p, machicolated=True):
    """A high curtain: coursed stone, a corbel band, battlements. The wall between the towers."""
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=5)
    if machicolated and h >= 18:
        machicolation(px, x0, x1, base - h - 1, p)
        battlement(px, x0, x1, base - h - 3, p["stone"], p["stone_dk"], p["ink"])
    else:
        battlement(px, x0, x1, base - h - 1, p["stone"], p["stone_dk"], p["ink"])
    for x in range(x0 + 6, x1 - 4, 14):                    # arrow loops along its length
        rect(px, x, base - h + 5, x, base - h + 9, p["dark"])


def great_gate(px, cx, base, w, h, p, rng=None):
    """The way in: a pointed arch under a high block, with a drum tower hard against each side."""
    half = w // 2
    curtain(px, cx - half, cx + half, base, h, p)
    arch = max(4, w // 6)
    for i in range(h - 6):                                 # a pointed arch, not a square hole
        t = i / max(1, h - 6)
        ww = int(arch * (1 - max(0.0, t - 0.55) / 0.45) ** 0.6) if t > 0.55 else arch
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
        _px(px, cx - ww - 1, base - i, p["ink"])
        _px(px, cx + ww + 1, base - i, p["ink"])
    grand_tower(px, cx - half - 5, base, 13, h + 24, p, flag=True)
    grand_tower(px, cx + half + 5, base, 13, h + 18, p)


def grand_steps(px, cx, base, w, rise, p):
    """The flight up to the gate. Nothing says the way in like a stair you can see from here."""
    n = max(4, rise // 3)
    for i in range(n):
        y = base - rise * i // n
        half = int(w / 2 * (1 - 0.45 * i / n))
        rect(px, cx - half, y, cx + half, y, p["stone_lit"] if i % 2 else p["stone"])
        _px(px, cx - half - 1, y, p["ink"])
        _px(px, cx + half + 1, y, p["ink"])


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
