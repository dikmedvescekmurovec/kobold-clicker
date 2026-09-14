"""Snow, dark timber and lamplight: what the ice builds with, and nothing anywhere else does.

The references are a snow-block village with warm wooden doors, a blue mountain town of upswept
eaves under heavy snow with orange windows and hanging lanterns, and a palace cut from a berg --
needle spires round a ribbed dome. One culture runs through them:

  * dark timber and white ice, with a thick cap of settled snow on every horizontal thing;
  * eaves that curl *up* at the ends, which no other place here does and which is legible at four
    pixels because the flick breaks the roofline;
  * a warm light in every opening.

The last is the whole environment. Everything else in this palette is a blue between 130 and 250,
and blue on blue at 576 px wide is a grey smear -- what makes an ice scene read as a place people
live in rather than as weather is the handful of amber pixels in it. Spend them.
"""
import random

from areabuild import _px, box, outline, rect
from arealib import H, W


def lantern(px, x, y, p, hang=0):
    """One warm light. Four pixels, and the most valuable four in the environment."""
    if hang:
        rect(px, x, y - hang, x, y - 1, p["ink"])
    rect(px, x - 1, y, x + 1, y + 2, p["lantern_dk"])
    rect(px, x, y, x, y + 1, p["lantern"])
    _px(px, x - 1, y + 1, p["lantern"])
    _px(px, x + 1, y + 1, p["lantern"])
    _px(px, x, y + 3, p["ink"])


def snow_cap(px, tops, p, deep=2):
    """The snow lying on a roof. `tops` is x -> the roof's own top row.

    Drawn as its own band above the roof rather than by tinting the roof pale, because what the
    reference shows is a *load* of snow with a lip standing over the eaves -- a roof painted white
    is a white roof, which is not the same thing and reads as nothing at all against a white sky.
    """
    for x, t in tops.items():
        for d in range(deep):
            _px(px, x, t - d, p["cap"] if d else p["cap_sh"])
        _px(px, x, t - deep, p["ink"])


def upswept(px, cx, base, half, h, p, snow=True, thick=None):
    """A roof whose eaves curl up at the ends, under a load of snow.

    This is the shape the whole place is built from -- a house, a gatehouse and a five-tier tower
    are all this roof at three sizes. The curl is the point: it costs three pixels at each end and
    it is the only roofline in the set that turns back on itself, so it survives being shrunk when
    a colour scheme does not.
    """
    curl = max(2, half // 4)
    lift = max(2, h // 4)
    flat = max(1, half - curl)
    tops = {}
    for dx in range(-half, half + 1):
        a = abs(dx)
        if a <= flat:
            t = base - h + int(h * (a / flat) ** 1.3)
        else:
            k = (a - flat) / curl                              # past the eave, it flicks up
            t = base - int(lift * k ** 1.4)
        x = cx + dx
        tops[x] = t
        bottom = base if a <= flat else base - int(lift * k ** 1.4) + max(2, thick or 3)
        for y in range(t, bottom + 1):
            _px(px, x, y, p["tile"] if dx <= 0 else p["tile_dk"])
        _px(px, x, bottom + 1, p["ink"])
    if snow:
        snow_cap(px, tops, p, deep=max(2, h // 7))
    return tops


def snow_dome(px, cx, base, w, h, p, rng):
    """A dome of cut snow blocks with a timber door: the village reference, more or less exactly.

    The blocks are what stops it being a white hemisphere on white ground -- they are drawn as a
    shaded seam every few pixels, curving with the surface. The door is the only warm thing and it
    is why the hut reads as occupied.
    """
    half = max(4, w // 2)
    h = max(5, min(h, half))
    for dx in range(-half, half + 1):
        t = base - int((h ** 2 * (1 - (dx / half) ** 2)) ** 0.5)
        x = cx + dx
        for y in range(t, base + 1):
            _px(px, x, y, p["cap"] if dx <= 0 else p["cap_sh"])
        _px(px, x, t - 1, p["ink"])
    for dx in range(-half + 2, half - 1, 4):                   # the seams between blocks
        t = base - int((h ** 2 * (1 - (dx / half) ** 2)) ** 0.5)
        rect(px, cx + dx, t + 1, cx + dx, base - 1, p["stone_dk"])
    for row in range(2, h, 3):
        y = base - row
        span = int(half * (1 - (row / h) ** 2) ** 0.5)
        rect(px, cx - span, y, cx + span, y, p["stone_dk"])
    dw = max(1, half // 3)                                     # the arch, and the warm door in it
    rect(px, cx - dw - 1, base - max(3, h // 2) - 1, cx + dw + 1, base, p["cap"])
    outline(px, cx - dw - 1, base - max(3, h // 2) - 1, cx + dw + 1, base, p["ink"])
    rect(px, cx - dw, base - max(3, h // 2), cx + dw, base, p["beam"])
    rect(px, cx - dw + 1, base - max(3, h // 2) + 1, cx + dw - 1, base - 1, p["glow"])


def timber_block(px, cx, base, w, h, p, rng):
    """A dark timber house under a snow-laden upswept roof, with its windows lit.

    Nearly black walls, which is what the town reference is: the buildings are silhouettes and the
    picture is made of the snow on top of them and the light coming out of them.
    """
    x0, x1 = cx - w // 2, cx - w // 2 + w
    wall = max(4, h // 2)
    box(px, x0, base - wall, x1, base, p["beam"], p["beam_dk"], p["ink"])
    for x in range(x0 + 2, x1 - 1, 5):                         # the lit windows, the whole point
        if rng.random() < 0.72:
            rect(px, x, base - wall + 2, x + 1, base - wall + 4, p["glow"])
            _px(px, x - 1, base - wall + 3, p["lantern_dk"])
    for x in range(x0 + 1, x1, 4):                             # uprights, the frame showing
        rect(px, x, base - wall, x, base - 1, p["beam_dk"])
    upswept(px, cx, base - wall - 1, w // 2 + 3, max(4, h - wall), p)
    if w >= 14 and rng.random() < 0.5:
        lantern(px, x0 + 2, base - wall - 3, p, hang=2)


def pagoda(px, cx, base, w, h, p, rng=None):
    """The tower the town is built around: upswept roofs stacked, each smaller, lanterns beneath.

    Four or five of this environment's one roof shape, piled up. It is the landmark and it is also
    the argument -- if the house and the tower are visibly the same roof at two sizes then the
    place has an architecture rather than a set of props.
    """
    rng = rng or random.Random(cx * 5 + h)
    tiers = max(3, min(6, h // 16))
    step = h // tiers
    y = base
    for t in range(tiers):
        half = max(3, int((w // 2 + 3) * (1 - 0.52 * t / max(1, tiers - 1))))
        wall = max(3, step - max(4, step // 2))
        box(px, cx - half + 2, y - wall, cx + half - 2, y, p["beam"], p["beam_dk"], p["ink"])
        if rng.random() < 0.85:
            rect(px, cx - 1, y - wall + 1, cx + 1, y - wall + 2, p["glow"])
        tops = upswept(px, cx, y - wall - 1, half, max(4, step - wall), p)
        if t < tiers - 1:
            for side in (-1, 1):                               # lanterns hung under the eaves
                lantern(px, cx + side * (half - 1), y - wall + 1, p, hang=1)
        y -= step
    rect(px, cx, y + step - 2, cx, y + step - 7, p["ink"])
    lantern(px, cx, y + step - 6, p)


def lantern_pole(px, x, base, h, p, rng=None):
    """A pole with lights on it. The town reference has these everywhere, and at this size a
    lamp on a stick does more to say "inhabited" than another building would."""
    rng = rng or random.Random(x)
    rect(px, x, base - h, x, base, p["beam_dk"])
    rect(px, x - 2, base - h, x + 2, base - h, p["beam"])
    lantern(px, x - 2, base - h + 2, p, hang=1)
    lantern(px, x + 2, base - h + 3, p, hang=1)


def needle(px, cx, base, w, h, p, rng=None):
    """A spire of carved ice, tapering to a point.

    The palace reference is a dozen of these at a dozen heights and almost nothing else. They want
    to be thin -- three to seven pixels -- and hard-lit down one side, or a tall pale triangle on a
    pale sky is invisible. The facets are drawn as horizontal breaks, which is what says cut ice
    rather than snow.
    """
    half = max(1, w // 2)
    for i in range(h):
        t = i / max(1, h)
        ww = max(0, int(half * (1 - t) ** 0.55))
        y = base - i
        for x in range(cx - ww, cx + ww + 1):
            _px(px, x, y, p["ice_lit"] if x < cx - ww // 2 else
                          (p["ice"] if x <= cx + ww // 2 else p["ice_dk"]))
        _px(px, cx - ww - 1, y, p["ink"])
        _px(px, cx + ww + 1, y, p["ink"])
        if ww and i % 7 == 3:                                  # a facet break
            rect(px, cx - ww, y, cx + ww, y, p["ice_dk"])
    rect(px, cx, base - h - 2, cx, base - h - 1, p["ice_lit"])


def ice_dome(px, cx, base, w, h, p, rng=None):
    """The ribbed dome the spires stand around: the one round thing in the whole set of six."""
    half = max(5, w // 2)
    h = max(6, min(h, int(half * 1.25)))
    for dx in range(-half, half + 1):
        t = base - int((h ** 2 * (1 - (dx / half) ** 2)) ** 0.5)
        x = cx + dx
        for y in range(t, base + 1):
            _px(px, x, y, p["ice_lit"] if dx < -half // 3 else
                          (p["ice"] if dx < half // 3 else p["ice_dk"]))
        _px(px, x, t - 1, p["ink"])
    for dx in range(-half + 2, half - 1, max(3, half // 4)):   # the ribs
        t = base - int((h ** 2 * (1 - (dx / half) ** 2)) ** 0.5)
        rect(px, cx + dx, t + 1, cx + dx, base - 1, p["ice_dk"])
    rect(px, cx - half - 1, base, cx + half + 1, base + 1, p["ice_dk"])
    rect(px, cx, base - h - 5, cx, base - h - 2, p["ice_lit"])
    lantern(px, cx, base - h - 8, p)


def ice_arcade(px, x0, x1, base, h, p):
    """A run of pointed arches in carved ice: the palace's wall, and its terrace fronts.

    Not a curtain wall. The reference has no defence anywhere in it -- it is a building that has
    never expected to be attacked, which is exactly why it must not be drawn with battlements.
    """
    box(px, x0, base - h, x1, base, p["ice"], p["ice_dk"], p["ink"], lit=p["ice_lit"])
    pitch = max(7, h)
    for x in range(x0 + 3, x1 - pitch + 2, pitch):
        aw = max(1, pitch // 3)
        for i in range(h - 2):
            t = i / max(1, h - 2)
            ww = aw if t < 0.5 else int(aw * (1 - (t - 0.5) / 0.5) ** 0.55)
            rect(px, x + aw - ww, base - i - 1, x + aw + ww, base - i - 1, p["dark"])
    rect(px, x0 - 1, base - h - 1, x1 + 1, base - h - 1, p["ice_lit"])
    rect(px, x0 - 1, base - h - 2, x1 + 1, base - h - 2, p["ink"])


def causeway(px, x0, x1, base, p, rng=None, rise=16):
    """The road in: a ramp on piers, curving up out of the frame edge toward the gate.

    The palace reference is an island, and the causeway is what says so. It also does the job the
    haze does elsewhere -- you cannot see where the building meets the ground, because the way in
    crosses something you cannot see the bottom of.
    """
    rng = rng or random.Random(x0)
    n = max(2, abs(x1 - x0) // 22)
    for k in range(n + 1):
        t = k / n
        x = int(x0 + (x1 - x0) * t)
        y = base - int(rise * t ** 1.5)
        rect(px, x, y, x + 1, base + 6, p["ice_dk"])           # the piers, going down out of sight
    for k in range(abs(x1 - x0)):
        t = k / max(1, abs(x1 - x0))
        x = x0 + (1 if x1 > x0 else -1) * k
        y = base - int(rise * t ** 1.5)
        rect(px, x, y - 3, x, y, p["ice"])
        _px(px, x, y - 4, p["ice_lit"])
        _px(px, x, y + 1, p["ink"])


def snow_belt(im, seed, x0, x1, base, p, count=6, scrub=1.0):
    """What an ice settlement sits in: snow-laden spruce, drifts, and a lamp or two on a pole."""
    from areabuild import conifer
    rng = random.Random(seed)
    px = im.load()
    for _ in range(count):
        x = rng.randrange(x0, max(x0 + 1, x1))
        y = base + rng.randrange(0, 5)
        h = rng.randrange(14, 30)
        conifer(px, x, y, h, p)
        for d in range(0, h, 4):                               # snow sitting in the branches
            w = max(1, int((h - d) * 0.22))
            rect(px, x - w, y - d - 1, x + w, y - d - 1, p["cap"])
    for _ in range(int(count * 4 * scrub)):                    # drifts
        x = rng.randrange(x0, max(x0 + 1, x1))
        y = base + rng.randrange(1, 7)
        w = rng.randrange(3, 9)
        rect(px, x - w, y, x + w, y, p["cap"])
        rect(px, x - w + 2, y - 1, x + w - 2, y - 1, p["cap"])
    if rng.random() < 0.6:
        lantern_pole(px, rng.randrange(x0, max(x0 + 1, x1)), base + 2, rng.randrange(12, 20), p, rng)
