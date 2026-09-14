"""Half-timber, limestone and steep tile: what the grass builds with, and nobody else.

The references are a meadow village of half-timbered gables under terracotta, a town of limestone
ground floors with jettied timber above them and round stair-turrets on the corners, and a castle
gone green with moss on a grass crag. One culture:

  * cream plaster panels in dark oak framing, standing on pale limestone;
  * steep roofs -- the pitch is greater than any other place here builds -- with dormers punched
    through them;
  * a round stair-turret under a tall slender cone, which is the mark: one on a village hall,
    three on the town, and the fortress's drums are the same cone at twice the height.

Everything old is mossy, and the fortress is not a grey castle with moss on it -- it is a green
castle. That is the difference between this place and the mountains, which build in stone too:
theirs is warm tan laid flat, this is cool cream laid steep and then left out in the wet.
"""
import random

from areabuild import _px, battlement, box, gable, mossy, outline, rect
from arealib import H, W


def timbered(px, x0, y0, x1, y1, p, brace=True):
    """A half-timbered panel: pale plaster between dark uprights, a sill, and a brace if it fits.

    The frame is the read at this size, not the plaster between it -- so the uprights are drawn
    first and the panels are what is left over, which is also how the building was put up.
    """
    rect(px, x0, y0, x1, y1, p["plaster"])
    for x in range(x0, x1 + 1, 5):
        rect(px, x, y0, x, y1, p["beam"])
    rect(px, x1, y0, x1, y1, p["beam"])
    mid = (y0 + y1) // 2
    rect(px, x0, mid, x1, mid, p["beam_dk"])                   # the sill course
    rect(px, x0, y1, x1, y1, p["beam_dk"])
    if brace and x1 - x0 > 9:
        for i in range(min(y1 - mid, (x1 - x0) // 2)):         # one diagonal brace, as they all have
            _px(px, x0 + 1 + i, y1 - 1 - i, p["beam_dk"])


def chimney(px, cx, top, h, p):
    """A limestone stack with a lip at the head. Every roof in the village reference has one."""
    rect(px, cx - 1, top - h, cx + 1, top, p["stone"])
    rect(px, cx + 1, top - h, cx + 1, top, p["stone_dk"])
    rect(px, cx - 2, top - h - 1, cx + 2, top - h - 1, p["stone_lit"])
    rect(px, cx - 2, top - h - 2, cx + 2, top - h - 2, p["ink"])


def steep_roof(px, cx, base, half, h, p, roof=None, dark=None, courses=True):
    """A roof at this culture's pitch, which is steeper than anyone else's here.

    The pitch is the signature as much as the turret is: at 576 px wide the difference between a
    45-degree roof and a 60-degree one is the difference between a barn and a townhouse, and it
    survives shrinking where a colour does not.
    """
    roof = roof or p["tile"]
    dark = dark or p["tile_dk"]
    for i in range(h):
        t = i / max(1, h)
        ww = int(half * (1 - t))
        y = base - i
        for x in range(cx - ww, cx + ww + 1):
            _px(px, x, y, roof if x <= cx else dark)
        if courses and i % 3 == 0 and i < h - 2:               # the courses the tiles are laid in
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y, p["tile_lit"] if roof == p["tile"] and x <= cx else
                              (p["slate_lit"] if roof != p["tile"] and x <= cx else dark))
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
    rect(px, cx - half - 1, base + 1, cx + half + 1, base + 1, p["ink"])   # the eaves, proud


def dormer(px, cx, y, p, w=3):
    """A little gabled window standing out of a roof slope. Two or three per roof, never a row."""
    rect(px, cx - w, y, cx + w, y + 3, p["plaster"])
    rect(px, cx - 1, y + 1, cx + 1, y + 2, p["glow"])
    for i in range(w + 1):
        rect(px, cx - w + i, y - 1 - i, cx + w - i, y - 1 - i, p["tile"] if i else p["tile_dk"])
    outline(px, cx - w, y - 1, cx + w, y + 3, p["ink"])


def gable_house(px, cx, base, w, h, p, rng):
    """The village house: a limestone footing, a half-timbered storey, a steep tiled roof."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    foot = max(3, h // 5)
    box(px, x0, base - foot, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=3)
    wall = max(5, h // 2 - foot)
    timbered(px, x0, base - foot - wall, x1, base - foot - 1, p)
    outline(px, x0, base - foot - wall, x1, base - foot - 1, p["ink"])
    dw = max(1, w // 8)
    rect(px, cx - dw, base - foot - 3, cx + dw, base, p["beam_dk"])
    if rng.random() < 0.7:
        rect(px, x0 + 2, base - foot - wall + 2, x0 + 3, base - foot - wall + 3, p["glow"])
    roof = max(6, h - foot - wall)
    steep_roof(px, cx, base - foot - wall - 1, w // 2 + 3, roof, p)
    if w >= 18 and rng.random() < 0.7:
        dormer(px, cx + rng.choice((-1, 1)) * (w // 5), base - foot - wall - roof // 2, p)
    chimney(px, x0 + 2 if rng.random() < 0.5 else x1 - 2, base - foot - wall - roof + 2,
            max(4, roof // 2), p)


def jetty_house(px, cx, base, w, h, p, rng):
    """The town house: a limestone ground floor with a timbered storey jettied out over it.

    The overhang is the whole reason the town reference has depth -- the upper storeys lean out
    over the street and the fronts stop being flat. One pixel of jetty at each side is enough.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    ground = max(6, int(h * 0.42))
    box(px, x0, base - ground, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=4)
    aw = max(1, w // 7)                                        # an arched door, as the street has
    for i in range(max(4, ground - 2)):
        t = i / max(1, ground - 2)
        ww = aw if t < 0.65 else int(aw * (1 - (t - 0.65) / 0.35) ** 0.55)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
    mossy(px, x0, base - ground, x1, base, p, rng, density=0.1)
    jx0, jx1 = x0 - 2, x1 + 2                                  # the storey above, jettied out
    upper = max(5, int(h * 0.3))
    timbered(px, jx0, base - ground - upper, jx1, base - ground - 1, p)
    outline(px, jx0, base - ground - upper, jx1, base - ground - 1, p["ink"])
    for x in range(jx0 + 2, jx1 - 1, 5):
        if rng.random() < 0.5:
            rect(px, x, base - ground - upper + 2, x + 1, base - ground - upper + 3, p["glow"])
    roof = max(6, h - ground - upper)
    steep_roof(px, cx, base - ground - upper - 1, w // 2 + 4, roof, p,
               roof=p["slate"], dark=p["slate_dk"])
    if w >= 20:
        dormer(px, cx - w // 5, base - ground - upper - roof // 2, p)
        if rng.random() < 0.5:
            dormer(px, cx + w // 4, base - ground - upper - roof // 3, p)
    chimney(px, x1 - 2, base - ground - upper - roof + 3, max(4, roof // 2), p)


def stair_turret(px, cx, base, w, h, p, rng=None, flag=False):
    """A round stair-turret under a very tall slender cone. The mark of the place.

    The cone is close to twice the height of the drum it stands on, which is what makes it read at
    a distance and what keeps it away from the mountains' red caps -- those are short, wide and
    saturated, this is tall, narrow and the colour of wet slate.
    """
    rng = rng or random.Random(cx + h)
    drum = int(h * 0.58)
    half = max(2, w // 2)
    box(px, cx - half, base - drum, cx + half, base, p["stone"], p["stone_dk"], p["ink"],
        lit=p["stone_lit"], courses=4)
    rect(px, cx - half + 1, base - drum, cx - half + 1, base, p["stone_lit"])
    rect(px, cx + half - 1, base - drum, cx + half - 1, base, p["stone_dk"])
    for y in range(base - drum + 4, base - 3, 7):              # the slit windows of the stair
        rect(px, cx, y, cx, y + 2, p["dark"])
    mossy(px, cx - half, base - drum, cx + half, base, p, rng, density=0.12)
    cone = max(6, h - drum)
    top = base - drum - 1
    rect(px, cx - half - 1, top, cx + half + 1, top, p["stone_lit"])       # the corbel it sits on
    rect(px, cx - half - 1, top - 1, cx + half + 1, top - 1, p["ink"])
    for i in range(cone):
        t = i / max(1, cone)
        ww = int((half + 1) * (1 - t ** 0.92))
        y = top - 2 - i
        for x in range(cx - ww, cx + ww + 1):
            _px(px, x, y, p["slate_lit"] if x < cx else (p["slate"] if x == cx else p["slate_dk"]))
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
    if flag:
        rect(px, cx, top - 2 - cone - 4, cx, top - 2 - cone, p["ink"])
        for i in range(4):
            rect(px, cx + 1, top - 2 - cone - 4 + i, cx + 1 + (3 - i), top - 2 - cone - 4 + i,
                 p["tile"])


def timber_stair(px, x0, x1, base, rise, p):
    """An outside timber stair against a stone flank, as the town reference has on every corner."""
    lo, hi = min(x0, x1), max(x0, x1)
    span = max(1, hi - lo)
    for x in range(lo, hi + 1):
        t = (x - lo) / span if x1 >= x0 else 1 - (x - lo) / span
        y = base - int(rise * t)
        rect(px, x, y + 1, x, y + 3, p["beam_dk"])
        _px(px, x, y, p["beam"] if ((x - lo) // 2) % 2 else p["beam_dk"])
        _px(px, x, y - 6, p["beam"])
        if (x - lo) % 4 == 0:
            rect(px, x, y - 5, x, y - 1, p["beam_dk"])
            rect(px, x, y + 4, x, base, p["beam_dk"])


def manor(px, cx, base, w, h, p, rng):
    """The hall: limestone, steep slate, dormers and stacks -- a big house, not a blank block."""
    x0, x1 = cx - w // 2, cx - w // 2 + w
    wall = max(8, int(h * 0.52))
    box(px, x0, base - wall, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=5)
    mossy(px, x0, base - wall, x1, base, p, rng, density=0.13)
    for row in range(4, wall - 3, 8):                          # tall windows in pairs
        for x in range(x0 + 4, x1 - 3, 9):
            rect(px, x, base - row - 3, x, base - row, p["glow"] if rng.random() < 0.3
                 else p["dark"])
            _px(px, x, base - row - 4, p["dark"])
    aw = max(2, w // 12)
    for i in range(max(5, wall // 3)):
        t = i / max(1, max(5, wall // 3))
        ww = aw if t < 0.6 else int(aw * (1 - (t - 0.6) / 0.4) ** 0.55)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
    roof = max(8, h - wall)
    steep_roof(px, cx, base - wall - 1, w // 2 + 3, roof, p, roof=p["slate"], dark=p["slate_dk"])
    for k in (-1, 1):
        dormer(px, cx + k * (w // 4), base - wall - roof // 3, p)
    chimney(px, x0 + 3, base - wall - roof + 4, max(5, roof // 2), p)
    chimney(px, x1 - 3, base - wall - roof + 6, max(5, roof // 2), p)


def mossy_curtain(px, x0, x1, base, h, p, crenels=True):
    """A limestone curtain that has gone green at the foot. Square merlons, never pointed.

    The moss is not decoration. The castle in the reference is *green*, and what makes a wall read
    as centuries old rather than newly quarried is that the wet has got into the bottom third of it
    and nothing has ever cleaned it off.
    """
    box(px, x0, base - h, x1, base, p["stone"], p["stone_dk"], p["ink"], lit=p["stone_lit"],
        courses=5)
    rng = random.Random(x0 * 7 + h)
    reach = max(4, (h * 2) // 3)
    for x in range(x0, x1 + 1):                                # the green, thickest at the foot
        for y in range(base - reach, base + 1):
            d = (y - (base - reach)) / max(1, reach)
            if rng.random() < 0.30 + 0.62 * d * d:
                _px(px, x, y, p["moss"] if rng.random() < 0.55 else
                              (p["moss_dk"] if rng.random() < 0.6 else p["moss_lit"]))
    for x in range(x0, x1 + 1):                                # and running down from the head
        if rng.random() < 0.4:
            for y in range(base - h, base - h + rng.randrange(2, max(3, h // 2))):
                if rng.random() < 0.55:
                    _px(px, x, y, p["moss_dk"] if rng.random() < 0.6 else p["moss"])
    for x in range(x0 + 6, x1 - 4, 15):                        # arrow loops
        rect(px, x, base - h + 5, x, base - h + 10, p["dark"])
    if crenels:
        battlement(px, x0, x1, base - h - 1, p["stone"], p["stone_dk"], p["ink"])


def drum_tower(px, cx, base, w, h, p, rng=None, coned=True, flag=False):
    """A round tower of the castle: coursed limestone, mossy, under a cone or a ring of merlons."""
    rng = rng or random.Random(cx * 3 + h)
    half = max(3, w // 2)
    box(px, cx - half, base - h, cx + half, base, p["stone"], p["stone_dk"], p["ink"],
        lit=p["stone_lit"], courses=5)
    rect(px, cx - half + 1, base - h, cx - half + 1, base, p["stone_lit"])
    rect(px, cx + half - 1, base - h, cx + half - 1, base, p["stone_dk"])
    for k in (1, 2):                                           # string courses up the shaft
        y = base - h * k // 3
        rect(px, cx - half - 1, y, cx + half + 1, y, p["stone_lit"])
        rect(px, cx - half - 1, y + 1, cx + half + 1, y + 1, p["stone_dk"])
    step = max(9, h // 5)
    for i, y in enumerate(range(base - h + 7, base - 4, step)):
        ww = 1 if i < 2 else 0
        rect(px, cx - ww, y, cx + ww, y + min(4, step // 2), p["dark"])
    reach = max(4, h // 2)
    for y in range(base - reach, base + 1):                    # the green, at the foot again
        for x in range(cx - half, cx + half + 1):
            d = (y - (base - reach)) / max(1, reach)
            if rng.random() < 0.16 + 0.56 * d * d:
                _px(px, x, y, p["moss"] if rng.random() < 0.55 else
                              (p["moss_dk"] if rng.random() < 0.6 else p["moss_lit"]))
    top = base - h - 1
    rect(px, cx - half - 2, top, cx + half + 2, top, p["stone_lit"])
    rect(px, cx - half - 2, top + 1, cx + half + 2, top + 1, p["ink"])
    if coned:
        cone = max(7, int(w * 1.7))
        for i in range(cone):
            t = i / max(1, cone)
            ww = int((half + 2) * (1 - t ** 0.92))
            y = top - 1 - i
            for x in range(cx - ww, cx + ww + 1):
                _px(px, x, y, p["slate_lit"] if x < cx else
                              (p["slate"] if x == cx else p["slate_dk"]))
            _px(px, cx - ww - 1, y, p["ink"])
            _px(px, cx + ww + 1, y, p["ink"])
        if flag:
            rect(px, cx, top - 1 - cone - 5, cx, top - 1 - cone, p["ink"])
            for i in range(5):
                rect(px, cx + 1, top - 1 - cone - 5 + i, cx + 1 + (4 - i),
                     top - 1 - cone - 5 + i, p["tile"])
    else:
        battlement(px, cx - half - 1, cx + half + 1, top - 1, p["stone"], p["stone_dk"], p["ink"])


def gothic_gate(px, cx, base, w, h, p, rng=None):
    """The way in: a tall pointed arch under a square block, a drum hard against each side.

    Pointed, not round. The arch in the castle reference comes to a point and that one detail is
    what separates this gate from the mountains' -- theirs is pointed too but squat, and the
    dirt's is square. Three gates, three arches, no two alike.
    """
    rng = rng or random.Random(cx + w)
    half = w // 2
    mossy_curtain(px, cx - half, cx + half, base, h, p, crenels=True)
    aw = max(3, w // 7)
    for i in range(h - 2):
        t = i / max(1, h - 2)
        ww = aw if t < 0.42 else int(aw * (1 - (t - 0.42) / 0.58) ** 0.72)
        rect(px, cx - ww, base - i, cx + ww, base - i, p["dark"])
        _px(px, cx - ww - 1, base - i, p["stone_lit"])
        _px(px, cx + ww + 1, base - i, p["stone_dk"])
    drum_tower(px, cx - half - 6, base, 13, h + 26, p, rng, flag=True)
    drum_tower(px, cx + half + 6, base, 13, h + 16, p, rng)


def meadow_belt(im, seed, x0, x1, base, p, count=6, scrub=1.0):
    """What a grass settlement stands in: broadleaf, hedge and a great deal of flowers."""
    from areabuild import fence, tree
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        x = rng.randrange(x0, max(x0 + 1, x1))
        tree(px, x, base + rng.randrange(0, 5), rng.randrange(20, 38), p, rng)
    for _ in range(max(1, count // 3)):
        x = rng.randrange(x0, max(x0 + 1, x1))
        fence(px, x, x + rng.randrange(16, 34), base + rng.randrange(1, 5), p)
    for _ in range(int(count * 7 * scrub)):                    # the meadow itself
        x = rng.randrange(x0, max(x0 + 1, x1))
        y = base + rng.randrange(1, 8)
        petal, centre = p["blossoms"][rng.randrange(len(p["blossoms"]))]
        _px(px, x, y, petal)
        _px(px, x, y - 1, centre if rng.random() < 0.4 else petal)
