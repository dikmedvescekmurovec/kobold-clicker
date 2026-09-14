"""The settlement layout engine for the battle backdrops.

A settlement used to be a function full of coordinates: `for dx, w, h in ((-92, 20, 13), ...)`,
four houses in four places whatever the seed said. Here a settlement is a **plan** -- an ordered
list of steps -- and the seed picks the widths, the gaps and what each plot turns out to be, so two
seeds give two villages rather than one village jittered.

The split mirrors the one the hex map already uses: `areabuild.py` holds the primitives the way
`town_parts.py` does, this file holds the engine, and `arealayouts.py` holds the catalogue the way
`towns.py` holds its tiers.

Anchors and signs, stated once and held everywhere:
  * `x` and `span` are offsets from `plan.cx`, so a plan can be slid along the frame.
  * `y` is an offset from the anchor named by `on`, **positive downward** -- the same sense as the
    `base - 26` the hand-written settlements used.
  * `on` is "base" (the flat trodden ground), "land" (the standing line under this column, for a
    place built up a rock) or "crest" (the single highest point that land reaches).

The land steps publish a standing line into `Site.top`; every later step can either stand on the
flat or walk down that line. That one hand-off is what lets a ksar terraced up a crag and a village
on an open flat be the same kind of object.
"""
import random
from collections import namedtuple

import areabuild as B
import bld_desert as D
import bld_forest as F
import arealib as A
from arealib import H, W

## A plot centred outside this margin is a sliced building nobody notices until the contact sheet,
## because `areabuild._px` clips in silence. The hand-written settlements put outliers at cx-250
## with cx=288, which is x=38, so this is well clear of anything deliberate.
MARGIN = 10


def patch(im, pal, seed, cx, half, base, depth=8):
    """The trodden ground a settlement stands on -- a low strip, since we look at it almost flat on.

    Anything taller reads as a wall of earth behind the houses rather than as ground.
    """
    rng = random.Random(seed)
    px = im.load()
    n = A.fbm(seed, 2 * half, ((3, 1.0), (11, 0.5)))
    for i, x in enumerate(range(cx - half, cx + half)):
        top = base - depth + int(n[i] * 4)
        for y in range(top, base + 3 + int(n[i] * 2)):
            if 0 <= x < W and 0 <= y < H:
                px[x, y] = pal["road"][rng.randint(0, 2)] if rng.random() < 0.35 else pal["road"][1]


# ---------------------------------------------------------------- the steps

## Ground laid before anything is built on it. "patch" is the flat every settlement stands on;
## "ridge" is the rise a fortress sits above; "mesa" is the rock a kasbah climbs, and it is the one
## that publishes a standing line for later steps to walk down.
Land = namedtuple("Land", "kind half h at depth")
Land.__new__.__defaults__ = ("patch", 130, 0, 0, 9)

## A depth course: a cursor walked along a span, dropping a seeded piece every seeded gap. This is
## the step that replaces the hardcoded tuples, and the one that makes a layout a family.
Row = namedtuple("Row", "span pieces w h gap y on jitter avoid")
Row.__new__.__defaults__ = ((-120, 120), (("house", 1.0),), (20, 26), (13, 18),
                            (6, 16), 0, "base", 3, False)

## Houses walked *down* a published land profile, in courses, and drawn highest first. The only
## fill that has to sort: a house higher up the flank is further back, so its roof line has to be
## laid in before the wall that stands in front of it. That is the whole reason a ksar reads as a
## stack of cubes and not as a pile.
Course = namedtuple("Course", "span piece w h drop step y on")
Course.__new__.__defaults__ = ((-96, 176), "house", (15, 27), (11, 18), (3, 8), (13, 19), 0, "land")

## One thing in one place: a gate, a tower, a keep, a run of wall. `span` makes it a span piece
## rather than a point piece; `keep` reserves the ground it stands on against later rows.
Fix = namedtuple("Fix", "piece x y w h span on keep")
Fix.__new__.__defaults__ = (None, 0, 0, 0, 0, None, "base", None)

## The green the place sits in -- palms over scrub in the desert, scrub and standing trees in the
## north. Drawn last of a settlement, so it stands in front of what was built.
Belt = namedtuple("Belt", "span y count scrub")
Belt.__new__.__defaults__ = ((-200, 200), 6, 8, 0.6)

Plan = namedtuple("Plan", "name cx base half steps")


def _pick(rng, pieces):
    """One piece name from a ((name, weight), ...) tuple."""
    total = sum(w for _, w in pieces)
    r = rng.random() * total
    for name, w in pieces:
        r -= w
        if r <= 0:
            return name
    return pieces[-1][0]


class Site:
    """The ground a plan is being laid on, and what has been pinned to it so far."""

    def __init__(self, im, pal, env, plan, seed):
        self.im, self.px, self.pal, self.env = im, im.load(), pal, env
        self.rng = random.Random(seed)
        self.seed = seed
        self.plan = plan
        self.cx, self.base = plan.cx, plan.base
        self.kit = KIT[STYLE[env]]
        self.top = {}              # x -> the standing line, where a land step publishes one
        self.crest = plan.base     # the highest that land reaches
        self.keep = []             # spans later rows must not build across

    def next_seed(self):
        """A fresh stream per step, so two steps never share noise."""
        self.seed += 101
        return self.seed

    def line(self, x):
        return self.top.get(x, self.base)

    def anchor(self, on, x):
        return {"base": self.base, "land": self.line(x), "crest": self.crest}[on]

    def free(self, x0, x1):
        return all(x1 < a or x0 > b for a, b in self.keep)

    def draw(self, name, x, y, w, h):
        self.kit[name](self, x, y, w, h)


# ---------------------------------------------------------------- the fills

def _land(s, l):
    if l.kind == "patch":
        patch(s.im, s.pal, s.next_seed(), s.cx, l.half, s.base, depth=l.depth)
    elif l.kind == "ridge":
        A.ridge(s.im, s.next_seed(), s.base + 4, l.h, s.pal["hill"], s.pal["hill_lit"],
                layers=((2, 1.0), (5, 0.3)),
                x0=max(0, s.cx - l.half), x1=min(W, s.cx + l.half))
    elif l.kind == "mist":
        # Drawn like land because it is laid down in order with it: haze at the foot of a crag,
        # which is what stops a tall rock reading as a tall rock rather than as height.
        B.mist(s.im, s.next_seed(), s.cx + l.at, l.half, s.base - l.depth, s.pal, height=l.h)
    elif l.kind == "water":
        # `depth` is where the waterline sits below the plan's base and `h` is how deep the band
        # goes. It belongs last in a plan for the reason its docstring gives.
        B.water(s.im, s.next_seed(), s.cx + l.at, l.half, s.base + l.depth, l.h, s.pal)
    elif l.kind == "mesa":
        tops = B.mesa(s.px, random.Random(s.next_seed()), s.cx + l.at, s.base, l.half, l.h, s.pal)
        s.top.update(tops)
        s.crest = min(tops.values())
        s.keep.append((s.cx + l.at - l.half, s.cx + l.at + l.half))
    else:
        raise AssertionError("no such land: %s" % l.kind)


def _row(s, r):
    """Walk a cursor along the span, dropping a piece every gap."""
    x0, x1 = s.cx + r.span[0], s.cx + r.span[1]
    x = x0 + s.rng.randint(0, 8)
    while x < x1:
        w = s.rng.randint(*r.w)
        h = s.rng.randint(*r.h)
        if r.avoid and not s.free(x - w // 2, x + w // 2):
            blocking = [b for a, b in s.keep if a <= x + w // 2 and b >= x - w // 2]
            x = max(blocking) + s.rng.randint(2, 8)
            continue
        if MARGIN < x < W - MARGIN:
            y = s.anchor(r.on, x) + r.y
            s.draw(_pick(s.rng, r.pieces), x + s.rng.randint(-r.jitter, r.jitter),
                   y + s.rng.randint(-1, 1), w, h)
        gap = s.rng.randint(*r.gap)
        x += w + max(gap, -(w // 3))        # a negative gap makes them touch, a third at most
    return


def _course(s, c):
    """Walk down the published land profile in courses, then draw the highest first."""
    spots, x = [], s.cx + c.span[0]
    while x < s.cx + c.span[1]:
        w = s.rng.randint(*c.w)
        y = s.anchor(c.on, x) + c.y + s.rng.randint(*c.drop)
        while y < s.base + 3:
            spots.append((x + s.rng.randint(-3, 3), y, w, s.rng.randint(*c.h)))
            y += s.rng.randint(*c.step)
        x += s.rng.randint(w - 7, w + 5)
    for x, y, w, h in sorted(spots, key=lambda p: p[1]):
        if MARGIN < x < W - MARGIN:
            s.draw(c.piece, x, y, w, h)


def _fix(s, f):
    y = s.anchor(f.on, s.cx + f.x) + f.y
    if f.span is not None:
        s.kit[f.piece](s, s.cx + f.span[0], s.cx + f.span[1], y, f.h)
    else:
        s.draw(f.piece, s.cx + f.x, y, f.w, f.h)
    if f.keep:
        s.keep.append((s.cx + f.keep[0], s.cx + f.keep[1]))


def _belt(s, b):
    s.kit["belt"](s, s.cx + b.span[0], s.cx + b.span[1], s.base + b.y, b.count, b.scrub)


_FILL = {Land: _land, Row: _row, Course: _course, Fix: _fix, Belt: _belt}


def run(im, pal, env, plan, seed):
    """Lay a plan on an image. List order is draw order -- there is no separate z pass."""
    s = Site(im, pal, env, plan, seed)
    for step in plan.steps:
        _FILL[type(step)](s, step)
    return s


# ---------------------------------------------------------------- what a place builds with

## A plan names pieces; the kit says what a piece is made of, so the same plan is timber and gables
## in the north and rammed earth in the desert. A style is a dict, so a new one is a few overrides
## rather than a new table: KIT["cone"] = dict(KIT["north"], house=_roundhouse).
KIT = {
    "north": dict(
        house=lambda s, x, y, w, h: B.hut(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: B.longhouse(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal),
        spire=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal, roofed=True),
        keep=lambda s, x, y, w, h: B.keep(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: B.gatehouse(s.px, x, y, w, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: B.wall_run(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: B.fence(s.px, x0, x1, y, s.pal),
        belt=lambda s, x0, x1, y, n, scrub: B.hedgerow(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                       n, scrub),
    ),
    # Plaster between dark uprights on a stone footing, under steep clay tile: what the grass
    # references are all of. The frame is the read at this size, not the panel between it.
    "timber": dict(
        house=lambda s, x, y, w, h: B.cottage(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: B.townhouse(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal),
        spire=lambda s, x, y, w, h: B.turret(s.px, x, y, w, h, s.pal),
        keep=lambda s, x, y, w, h: B.great_hall(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: B.gatehouse(s.px, x, y, w, h, s.pal),
        stair=lambda s, x0, x1, y, h: B.stair(s.px, x0, x1, y, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: B.wall_run(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: B.fence(s.px, x0, x1, y, s.pal),
        belt=lambda s, x0, x1, y, n, scrub: B.hedgerow(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                       n, scrub),
    ),
    # Steep dark shingle over stone, built on a rock and climbing it. Shares the timber kit's
    # framing and hall; what makes it its own place is the pitch of the roofs and the crag.
    "alpine": dict(
        house=lambda s, x, y, w, h: B.chalet(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: B.gallery(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal),
        spire=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal, roofed=True),
        keep=lambda s, x, y, w, h: B.great_hall(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: B.gatehouse(s.px, x, y, w, h, s.pal),
        stair=lambda s, x0, x1, y, h: B.stair(s.px, x0, x1, y, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: B.wall_run(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: B.palisade(s.px, x0, x1, y, s.pal, max(6, h + 4)),
        belt=lambda s, x0, x1, y, n, scrub: B.hedgerow(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                       n, scrub),
    ),
    # Dirt: iron-age roundhouses on the flat, a stone street with timber galleries, and a keep
    # that has already fallen -- the only ruin in the set, and the thing that makes the place read
    # as older than the others rather than just browner.
    "celtic": dict(
        house=lambda s, x, y, w, h: B.roundhouse(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: B.gallery(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal),
        spire=lambda s, x, y, w, h: B.tower(s.px, x, y, w, h, s.pal, roofed=True),
        keep=lambda s, x, y, w, h: B.ruin(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: B.gatehouse(s.px, x, y, w, h, s.pal),
        stair=lambda s, x0, x1, y, h: B.stair(s.px, x0, x1, y, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: B.wall_run(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: B.fence(s.px, x0, x1, y, s.pal),
        belt=lambda s, x0, x1, y, n, scrub: B.hedgerow(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                       n, scrub),
    ),
    # Ice: snow domes in the village, dark timber under a thick cap in the town, and needles of
    # carved ice for the palace. `dome` is its own piece because the two tiers build differently.
    "snow": dict(
        house=lambda s, x, y, w, h: B.snowhouse(s.px, x, y, w, h, s.pal, s.rng),
        dome=lambda s, x, y, w, h: B.igloo(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: B.snowhouse(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: B.ice_spire(s.px, x, y, w, h, s.pal),
        spire=lambda s, x, y, w, h: B.ice_spire(s.px, x, y, w, h, s.pal),
        keep=lambda s, x, y, w, h: B.great_hall(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: B.gatehouse(s.px, x, y, w, h, s.pal),
        stair=lambda s, x0, x1, y, h: B.stair(s.px, x0, x1, y, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: B.wall_run(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: B.fence(s.px, x0, x1, y, s.pal),
        belt=lambda s, x0, x1, y, n, scrub: B.hedgerow(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                       n, scrub),
    ),
    # Forest: the references are Indonesian, not Carpathian. Cone thatch nearly to the ground,
    # longhouses on posts over water, and a temple of tiered merus behind a split gate.
    "cone": dict(
        house=lambda s, x, y, w, h: B.cone_house(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: B.stilt_house(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: B.meru(s.px, x, y, w, h, s.pal, s.rng),
        spire=lambda s, x, y, w, h: B.meru(s.px, x, y, w, h, s.pal, s.rng),
        keep=lambda s, x, y, w, h: B.meru(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: B.split_gate(s.px, x, y, w, h, s.pal),
        stair=lambda s, x0, x1, y, h: B.stair(s.px, x0, x1, y, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: B.wall_run(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: B.fence(s.px, x0, x1, y, s.pal),
        belt=lambda s, x0, x1, y, n, scrub: B.hedgerow(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                       n, scrub),
    ),
    # Forest, written from its own reference photographs: thatch over dark timber, everything
    # stepping inward as it rises, a finial on every apex. It reaches nothing another place owns
    # and shares no piece with one, which is the point -- see bld_forest.py.
    "forest": dict(
        house=lambda s, x, y, w, h: F.thatch_cone(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: F.stilt_long(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: F.meru_tower(s.px, x, y, w, h, s.pal, s.rng),
        spire=lambda s, x, y, w, h: F.meru_tower(s.px, x, y, w, h, s.pal, s.rng),
        keep=lambda s, x, y, w, h: F.meru_tower(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: F.candi_gate(s.px, x, y, w, h, s.pal, s.rng),
        shrine=lambda s, x, y, w, h: F.shrine(s.px, x, y, w, h, s.pal, s.rng),
        stair=lambda s, x, y, w, h: F.temple_stair(s.px, x, y, w, h, s.pal),
        tree=lambda s, x, y, w, h: _tree(s, x, y, int(h * 1.7)),
        wall=lambda s, x0, x1, y, h: F.temple_wall(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: F.temple_wall(s.px, x0, x1, y, max(2, h), s.pal),
        belt=lambda s, x0, x1, y, n, scrub: F.jungle_belt(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                          n, scrub),
    ),
    "desert": dict(
        house=lambda s, x, y, w, h: D.mud_house(s.px, x, y, w, h, s.pal, s.rng),
        hall=lambda s, x, y, w, h: D.mud_house(s.px, x, y, w, h, s.pal, s.rng, taper=0.06),
        cluster=lambda s, x, y, w, h: D.mud_cluster(s.px, x, y, w, h, s.pal, s.rng),
        tower=lambda s, x, y, w, h: D.kasbah_tower(s.px, x, y, w, h, s.pal),
        spire=lambda s, x, y, w, h: D.kasbah_tower(s.px, x, y, w, h, s.pal),
        keep=lambda s, x, y, w, h: D.mud_keep(s.px, x, y, w, h, s.pal, s.rng),
        gate=lambda s, x, y, w, h: D.mud_gate(s.px, x, y, w, h, s.pal),
        tree=lambda s, x, y, w, h: B.palm(s.px, x, y, int(h * 1.7), s.pal, s.rng),
        wall=lambda s, x0, x1, y, h: D.mud_wall(s.px, x0, x1, y, h, s.pal),
        yard=lambda s, x0, x1, y, h: D.mud_wall(s.px, x0, x1, y, h, s.pal, crown=False),
        belt=lambda s, x0, x1, y, n, scrub: B.palm_belt(s.im, s.next_seed(), x0, x1, y, s.pal,
                                                        n, scrub),
    ),
}

## The grand pieces every fortress draws on. They differ between places only by the palette they are
## handed, so they are injected into each style rather than repeated in six dicts -- and they are
## their own names rather than replacing `wall` and `gate`, because the towns want the modest ones.
_GRAND = dict(
    great=lambda s, x, y, w, h: B.grand_tower(s.px, x, y, w, h, s.pal, s.rng, flag=True),
    plain_great=lambda s, x, y, w, h: B.grand_tower(s.px, x, y, w, h, s.pal, s.rng),
    crown=lambda s, x, y, w, h: B.grand_tower(s.px, x, y, w, h, s.pal, s.rng, roofed=True,
                                              flag=True),
    bulwark=lambda s, x0, x1, y, h: B.curtain(s.px, x0, x1, y, h, s.pal),
    barbican=lambda s, x, y, w, h: B.great_gate(s.px, x, y, w, h, s.pal, s.rng),
    steps=lambda s, x, y, w, h: B.grand_steps(s.px, x, y, w, h, s.pal),
)
## Which styles are still on the shared castle. The list shrinks by one as each place is written
## from its own references, and when it is empty `_GRAND` and its six pieces go. It is an explicit
## list rather than "every style" so that a finished place cannot quietly reach back for a curtain
## wall -- `qa.py audit` fails on the name instead of silently resolving it.
_ON_THE_OLD_CASTLE = ("north", "timber", "alpine", "celtic", "snow", "cone", "desert")
for _name_ in _ON_THE_OLD_CASTLE:
    for _piece_, _fn_ in _GRAND.items():
        KIT[_name_].setdefault(_piece_, _fn_)


## Which vocabulary each place builds with. Grass keeps the northern timber and gables as its own
## style; the reference photographs put the other four somewhere else entirely, and each moves off
## it as its kit is written.
STYLE = {"grass": "timber", "dirt": "celtic", "ice": "snow", "forest": "forest",
         "mountains": "alpine", "desert": "desert"}

## What grows here: spruce in the cold and the woods, broadleaf everywhere else.
TREE = {"grass": "broadleaf", "dirt": "broadleaf", "desert": "palm",
        "ice": "conifer", "forest": "broadleaf", "mountains": "conifer"}

## Places whose ground cover is drawn right across the mid band -- dune ripples scribble over a mud
## wall rather than standing in front of it -- so what is built there goes in after the cover.
LATE = {"desert"}


def _tree(s, x, y, h):
    if TREE[s.env] == "conifer":
        B.conifer(s.px, x, y, h, s.pal)
    elif TREE[s.env] == "palm":
        B.palm(s.px, x, y, h, s.pal, s.rng)
    else:
        B.tree(s.px, x, y, h, s.pal, s.rng)
