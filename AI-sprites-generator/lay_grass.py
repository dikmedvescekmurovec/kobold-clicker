"""Where the grass puts what it builds: twelve plans, four to a variant.

One culture at three scales. The village is half-timbered gables in a meadow; the town is the same
framing jettied out over limestone ground floors, packed tight, with round stair-turrets on its
corners; the fortress is limestone gone green on a crag above a valley full of haze.

The turret is the thread. One on a village hall, three across a town, and the castle's drums are
the same cone at twice the height -- so a player who has seen the village knows whose castle that
is without being told.

This place and the mountains both build in stone, which makes them the pair most in danger of
reading alike, and they are kept apart on three counts: the stone is cool cream against warm tan,
the roofs are steep against flat, and the cones are tall slate needles against short red caps.
"""
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- village: the meadow houses
# Half-timbered gables spread out in long grass. This is the gentlest place in the set and the
# plans are allowed to be loose -- everywhere else packs its buildings, and the openness is part
# of what says this is the easy country.

GREEN = Plan("green", 296, 252, 160, (                # houses loose around an open middle
    Land("patch", half=160, depth=8),
    Row(span=(-152, -34), pieces=(("house", 1.0),), w=(32, 46), h=(36, 52), gap=(0, 12), y=-2,
        jitter=4),
    Row(span=(32, 156), pieces=(("house", 1.0),), w=(32, 46), h=(36, 52), gap=(0, 12), y=-2,
        jitter=4),
    Fix("hall", x=-4, y=-12, w=62, h=54),             # the hall, set back across the green
    Fix("spire", x=40, y=-6, w=13, h=48),             # and its turret, so the mark is here too
    Fix("yard", span=(-32, 30), y=2, h=4),
    Belt(span=(-250, 250), y=6, count=7, scrub=1.2),
))

LANE = Plan("lane", 290, 252, 175, (                  # strung along the track, gables to the road
    Land("ridge", half=240, h=12),
    Land("patch", half=175, depth=8),
    Row(span=(-178, 166), pieces=(("house", 0.8), ("tree", 0.2)), w=(30, 44), h=(34, 48),
        gap=(2, 16), y=0, jitter=5),
    Fix("spire", x=-66, y=-4, w=12, h=42),
    Fix("yard", span=(96, 152), y=3, h=4),
    Belt(span=(-250, 250), y=6, count=8, scrub=1.3),
))

MILL = Plan("mill", 284, 252, 180, (                  # the hall big, the rest gathered round it
    Land("patch", half=180, depth=9),
    Row(span=(-158, -50), pieces=(("house", 1.0),), w=(30, 42), h=(32, 46), gap=(0, 10), y=2),
    Fix("hall", x=32, y=-6, w=64, h=52),
    Fix("spire", x=84, y=-8, w=15, h=58),
    Row(span=(116, 176), pieces=(("house", 1.0),), w=(26, 36), h=(28, 40), gap=(2, 12), y=3),
    Fix("stair", span=(-14, 10), y=2, h=14),
    Belt(span=(-250, 250), y=6, count=7, scrub=1.2),
))

CHAPEL = Plan("chapel", 272, 252, 170, (              # a few houses and one thing worth looking at
    Land("patch", half=170, depth=9),
    Row(span=(-150, 142), pieces=(("house", 0.74), ("tree", 0.26)), w=(34, 50), h=(40, 56),
        gap=(6, 24), y=0, jitter=5),
    Fix("wall", span=(-40, 36), y=2, h=8),            # a walled churchyard
    Fix("spire", x=-2, y=-2, w=16, h=72),             # the tallest thing for a mile
    Belt(span=(-250, 260), y=7, count=9, scrub=1.4),
))

# ---------------------------------------------------------------- town: the timbered street
# Limestone below, timber above, jettied over the street and packed until the fronts touch. The
# turrets on the corners are what stop a row of gables reading as a terrace of sheds.

BURGH = Plan("burgh", 288, 252, 210, (                # the street, and the gate that shuts it
    Land("ridge", half=245, h=12),
    Land("patch", half=210, depth=8),
    Row(span=(-182, -44), pieces=(("street", 1.0),), w=(26, 38), h=(38, 56), gap=(-2, 4), y=0,
        jitter=2),
    Row(span=(46, 188), pieces=(("street", 1.0),), w=(26, 38), h=(38, 56), gap=(-2, 4), y=0,
        jitter=2),
    Fix("spire", x=-52, y=-4, w=15, h=66),
    Fix("spire", x=56, y=-2, w=13, h=54),
    Fix("gate", x=0, y=2, w=38, h=26),
    Fix("stair", span=(-96, -72), y=2, h=16),
    Belt(span=(-250, 255), y=5, count=4, scrub=0.8),
))

MARKET = Plan("market", 292, 252, 210, (              # a square, with the hall on one side of it
    Land("ridge", half=245, h=14),
    Land("patch", half=210, depth=8),
    Row(span=(-190, -66), pieces=(("street", 1.0),), w=(26, 38), h=(34, 50), gap=(-2, 6), y=0),
    Fix("hall", x=6, y=-6, w=76, h=62),
    Fix("spire", x=50, y=-8, w=17, h=82),             # the town's own tower, over its market
    Row(span=(112, 190), pieces=(("street", 1.0),), w=(26, 36), h=(32, 46), gap=(0, 8), y=1),
    Fix("yard", span=(-58, -12), y=3, h=5),
    Fix("stair", span=(-70, -46), y=2, h=15),
    Belt(span=(-250, 255), y=5, count=5, scrub=0.9),
))

TERRACE = Plan("terrace", 282, 252, 200, (            # the town up a limestone bluff
    Land("patch", half=200, depth=8),
    Land("mesa", at=12, half=158, h=62),
    Course(span=(-94, 148), piece="street", w=(26, 38), h=(32, 48), drop=(5, 11), step=(26, 36)),
    Fix("spire", x=46, y=-6, w=16, h=72, on="land"),
    Fix("street", x=-148, y=0, w=32, h=38),
    Fix("stair", span=(-128, -98), y=2, h=20),
    Belt(span=(-250, 255), y=6, count=5, scrub=0.9),
))

WHARF = Plan("wharf", 290, 252, 205, (                # long and low, a wall along its front
    Land("ridge", half=245, h=10),
    Land("patch", half=205, depth=8),
    Fix("wall", span=(-196, 198), y=2, h=14),
    Row(span=(-178, 182), pieces=(("street", 1.0),), w=(26, 38), h=(34, 52), gap=(-2, 6), y=-14,
        jitter=4),
    Fix("spire", x=-110, y=-16, w=15, h=64),
    Fix("spire", x=96, y=-14, w=13, h=52),
    Fix("gate", x=-8, y=2, w=36, h=22),
    Belt(span=(-250, 255), y=5, count=4, scrub=0.8),
))

# ---------------------------------------------------------------- fortress: the green castle
# One dominant mass, the base hidden in the haze of the valley, and the tallest thing carrying this
# culture's crown -- a tall slate cone with a pennant on it. The reference is not a grey castle
# with moss on it, it is a green castle, and every plan here leans on that: the green is what makes
# it old, and old is what makes it worth looking at.

CITADEL = Plan("citadel", 288, 250, 215, (            # the crag, and everything stepping off it
    Land("ridge", half=250, h=20),
    Land("patch", half=215, depth=9),
    Land("mesa", at=-6, half=154, h=64),
    Fix("bulwark", span=(-108, 116), y=3, h=20),
    Fix("great", x=-72, y=-4, w=19, h=92, on="land"),
    Fix("keep", x=-6, y=-6, w=64, h=76, on="land"),
    Fix("great", x=52, y=-6, w=23, h=128, on="land"), # the one that dominates
    Fix("tower", x=104, y=-2, w=16, h=62, on="land"),
    Fix("bulwark", span=(-208, -126), y=2, h=24),
    Fix("bulwark", span=(130, 210), y=2, h=24),
    Fix("tower", x=-204, y=0, w=17, h=54),
    Fix("tower", x=206, y=0, w=16, h=48),
    Fix("gate", x=-46, y=2, w=40, h=26),
    Land("mist", at=0, half=250, h=14, depth=4),
))

CROWN_KEEP = Plan("crown_keep", 286, 252, 215, (      # no rock: a curtain, and towers on it
    Land("ridge", half=250, h=16),
    Land("patch", half=215, depth=9),
    Fix("bulwark", span=(-186, 190), y=2, h=30),
    Fix("great", x=-118, y=-2, w=18, h=88),
    Fix("keep", x=-42, y=-2, w=70, h=84),
    Fix("great", x=26, y=-2, w=24, h=140),            # the mass, and off centre
    Fix("great", x=92, y=-2, w=18, h=96),
    Fix("tower", x=158, y=-2, w=15, h=62),
    Fix("gate", x=-42, y=2, w=42, h=28),
    Row(span=(-250, -204), pieces=(("house", 1.0),), w=(24, 32), h=(24, 34), gap=(8, 18), y=5),
    Land("mist", at=0, half=250, h=11, depth=5),
))

WATERGATE = Plan("watergate", 284, 250, 215, (        # the castle at one end, the approach at the other
    Land("ridge", half=250, h=22),
    Land("patch", half=215, depth=10),
    Land("mesa", at=88, half=132, h=72),
    Fix("bulwark", span=(28, 154), y=4, h=17),
    Fix("great", x=62, y=-4, w=21, h=112, on="land"),
    Fix("keep", x=118, y=-4, w=52, h=70, on="land"),
    Fix("great", x=158, y=-2, w=16, h=76, on="land"),
    Fix("bulwark", span=(-176, -22), y=2, h=22),
    Fix("tower", x=-168, y=0, w=18, h=58),
    Fix("tower", x=-64, y=0, w=16, h=50),
    Fix("gate", x=-116, y=2, w=40, h=26),
    Fix("stair", span=(-20, 24), y=2, h=22),
    Land("mist", at=40, half=250, h=18, depth=3),
))

SEVEN_TOWERS = Plan("seven_towers", 292, 252, 215, (  # a wall of cones, none of them the same
    Land("ridge", half=250, h=18),
    Land("patch", half=215, depth=9),
    Land("mesa", at=0, half=176, h=44),
    Fix("bulwark", span=(-150, 152), y=3, h=18),
    Fix("great", x=-128, y=-2, w=14, h=62, on="land"),
    Fix("great", x=-80, y=-4, w=18, h=98, on="land"),
    Fix("great", x=-28, y=-4, w=16, h=78, on="land"),
    Fix("great", x=24, y=-6, w=25, h=146, on="land"),
    Fix("great", x=78, y=-4, w=17, h=88, on="land"),
    Fix("great", x=126, y=-2, w=14, h=66, on="land"),
    Fix("bulwark", span=(-212, -166), y=2, h=20),
    Fix("bulwark", span=(168, 214), y=2, h=20),
    Fix("gate", x=24, y=2, w=40, h=26),
    Land("mist", at=0, half=250, h=16, depth=4),
))


LAYOUTS = {
    "village": (GREEN, LANE, MILL, CHAPEL),
    "town": (BURGH, MARKET, TERRACE, WHARF),
    "fortress": (CITADEL, CROWN_KEEP, WATERGATE, SEVEN_TOWERS),
}
