"""Where the forest puts what it builds: twelve plans, four to a variant.

One culture at three scales. The village is Wae Rebo -- thatch cones on a green terrace; the town
is longhouses on posts over brown water; the fortress is a Balinese temple of split gates and meru
towers. They share a material (thatch over dark timber), a rule (everything steps inward as it
rises) and a mark (a finial on every apex), so a player who fights at all three should read them as
one people without ever being told so.

The four plans of a variant are written to four different briefs rather than four seeds of one
idea: a different ground, a different landmark, a different place for the eye to go. That is what
`qa.py areas`' twins check is for, and the check is tight enough to catch a reshuffle.
"""
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- village: the cone houses
# Seven cones and a green. What has to read is the cone itself -- there is no wall, no roofline,
# no street, just a row of tall banded triangles with a spike on top, which is a silhouette no
# other place in the set owns.

WAE_RING = Plan("wae_ring", 292, 250, 150, (          # cones loose around an open middle
    Land("patch", half=150, depth=8),
    Row(span=(-140, -34), pieces=(("house", 1.0),), w=(22, 30), h=(30, 42), gap=(4, 14), y=-3,
        jitter=3),
    Row(span=(38, 150), pieces=(("house", 1.0),), w=(22, 31), h=(30, 44), gap=(4, 14), y=-3,
        jitter=3),
    Fix("house", x=-6, y=-6, w=32, h=46),             # the big one, set back across the green
    Fix("shrine", x=-44, y=1, w=6, h=10),
    Fix("yard", span=(-30, 30), y=1, h=3),            # the ring of stones the green is edged with
    Belt(span=(-230, 240), y=5, count=7, scrub=0.9),
))

WAE_TERRACE = Plan("wae_terrace", 286, 252, 190, (    # the village climbing its own hill
    Land("patch", half=190, depth=9),
    Land("mesa", at=-16, half=150, h=62),
    Course(span=(-108, 140), piece="house", w=(17, 26), h=(24, 36), drop=(4, 9), step=(20, 28)),
    Fix("house", x=-40, y=-2, w=30, h=44, on="land"),
    Fix("shrine", x=6, y=2, w=6, h=11, on="land"),
    Fix("yard", span=(-104, -60), x=-82, y=8, h=3, on="land"),
    Belt(span=(-240, 250), y=6, count=8, scrub=1.0),
))

WAE_RIVER = Plan("wae_river", 300, 238, 200, (        # cones on the bank, upside down underneath
    Land("patch", half=200, depth=7),
    Row(span=(-150, 130), pieces=(("house", 0.78), ("tree", 0.22)), w=(18, 27), h=(24, 34),
        gap=(8, 20), y=-2, jitter=2),
    Fix("house", x=56, y=-5, w=31, h=44),
    Fix("shrine", x=-118, y=0, w=5, h=9),
    Land("water", at=-24, half=300, h=17, depth=1),   # last: a reflection is after everything
))

WAE_CLEARING = Plan("wae_clearing", 268, 252, 160, (  # fewer, bigger, with the jungle closing in
    Land("patch", half=160, depth=9),
    Row(span=(-124, 118), pieces=(("house", 1.0),), w=(28, 38), h=(38, 54), gap=(12, 30), y=0,
        jitter=4),
    Fix("wall", span=(-60, 18), y=1, h=6),            # a fragment of old temple wall, reused
    Fix("shrine", x=-72, y=1, w=6, h=12),
    Fix("shrine", x=40, y=2, w=5, h=9),
    Row(span=(-250, 260), pieces=(("tree", 1.0),), w=(14, 20), h=(20, 30), gap=(70, 130), y=-2),
    Belt(span=(-250, 260), y=6, count=10, scrub=1.2),
))

# ---------------------------------------------------------------- town: the river longhouses
# All frame and roof. The water is what makes this tier its own place rather than a bigger village:
# a settlement standing in its own reflection is a thing no other environment here can draw.

STILT_ROW = Plan("stilt_row", 288, 236, 210, (
    Land("patch", half=210, depth=7),
    Row(span=(-172, -52), pieces=(("hall", 1.0),), w=(30, 44), h=(20, 30), gap=(6, 16), y=1,
        jitter=3),
    Fix("hall", x=-16, y=-6, w=62, h=50),             # the big house, off centre and standing up
    Row(span=(38, 162), pieces=(("hall", 1.0),), w=(30, 46), h=(22, 34), gap=(6, 16), y=0,
        jitter=3),
    Fix("tower", x=-74, y=-26, w=15, h=70),           # merus back on dry land behind the row
    Fix("tower", x=96, y=-22, w=12, h=48),
    Land("water", at=0, half=300, h=18, depth=1),
))

TWO_BANKS = Plan("two_banks", 288, 234, 210, (        # the river between, the town on both sides
    Land("patch", half=210, depth=7),
    Row(span=(-186, -52), pieces=(("hall", 1.0),), w=(30, 44), h=(18, 34), gap=(6, 14), y=-4,
        jitter=4),
    Row(span=(64, 190), pieces=(("hall", 1.0),), w=(30, 44), h=(18, 34), gap=(6, 14), y=-4,
        jitter=4),
    Fix("gate", x=6, y=-2, w=30, h=48),               # the crossing, marked the way they mark one
    Fix("tower", x=-120, y=-24, w=13, h=56),
    Fix("house", x=-40, y=-1, w=22, h=32),
    Land("water", at=0, half=300, h=19, depth=2),
))

LANDING = Plan("landing", 296, 238, 200, (            # one long house, a jetty, the village behind
    Land("patch", half=200, depth=8),
    Row(span=(-166, -70), pieces=(("house", 1.0),), w=(17, 24), h=(22, 30), gap=(12, 24), y=-14),
    Fix("hall", x=44, y=-2, w=76, h=46),               # the dominant mass, well off centre
    Fix("hall", x=-38, y=-2, w=40, h=26),
    Fix("tower", x=132, y=-18, w=15, h=54),
    Fix("stair", x=-2, y=2, w=22, h=9),
    Land("water", at=30, half=280, h=17, depth=1),
))

UPRIVER = Plan("upriver", 280, 240, 190, (            # the town stepping up off its own landing
    Land("patch", half=190, depth=8),
    Land("mesa", at=24, half=140, h=56),
    Course(span=(-40, 150), piece="hall", w=(30, 44), h=(20, 28), drop=(5, 10), step=(30, 40)),
    Fix("tower", x=70, y=-4, w=17, h=66, on="land"),
    Fix("hall", x=-110, y=0, w=44, h=28),
    Fix("wall", span=(-150, -66), y=3, h=7),
    Land("water", at=-150, half=190, h=16, depth=1),
))

# ---------------------------------------------------------------- fortress: the temple
# The rules a fortress is composed to, in this place's own terms. One dominant mass with everything
# stepping down from it. The base hidden, so you cannot see where it meets the ground. And the
# tallest thing carries this culture's crown, which is a gold finial rather than a pennant --
# nothing here is defended, it is venerated, and that is the whole difference from a castle.

KORI_AGUNG = Plan("kori_agung", 288, 250, 215, (      # the reference, more or less exactly
    Land("ridge", half=250, h=16),
    Land("patch", half=215, depth=9),
    Fix("wall", span=(-210, -54), y=2, h=15),
    Fix("wall", span=(54, 212), y=2, h=15),
    Fix("tower", x=-104, y=-14, w=20, h=112),         # merus standing up behind the wall
    Fix("tower", x=96, y=-12, w=17, h=94),
    Fix("keep", x=0, y=-20, w=26, h=150),             # the one that dominates, dead centre
    Fix("gate", x=-54, y=2, w=42, h=64),
    Fix("gate", x=54, y=2, w=42, h=64),
    Fix("gate", x=0, y=2, w=52, h=86),                # the tall middle one, the way in
    Fix("stair", x=0, y=3, w=40, h=13),
    Fix("shrine", x=-30, y=2, w=6, h=13),
    Fix("shrine", x=30, y=2, w=6, h=13),
    Belt(span=(-250, 250), y=6, count=6, scrub=0.7),
    Land("mist", at=0, half=250, h=10, depth=5),
))

ELEVEN_MERUS = Plan("eleven_merus", 292, 252, 215, (  # a rank of towers at every height
    Land("ridge", half=250, h=20),
    Land("patch", half=215, depth=9),
    Land("mesa", at=0, half=170, h=44),
    Fix("wall", span=(-168, 172), y=3, h=12),
    Fix("tower", x=-134, y=-6, w=13, h=70, on="land"),
    Fix("tower", x=-92, y=-8, w=15, h=92, on="land"),
    Fix("keep", x=-38, y=-10, w=24, h=138, on="land"),
    Fix("tower", x=16, y=-8, w=17, h=104, on="land"),
    Fix("tower", x=68, y=-6, w=14, h=78, on="land"),
    Fix("tower", x=116, y=-4, w=12, h=58, on="land"),
    Fix("gate", x=-38, y=2, w=44, h=58),
    Fix("stair", x=-38, y=3, w=34, h=11),
    Fix("shrine", x=-72, y=2, w=6, h=12),
    Fix("shrine", x=-4, y=2, w=6, h=12),
    Land("mist", at=0, half=250, h=13, depth=4),
))

GATE_OF_STAIRS = Plan("gate_of_stairs", 282, 252, 215, (   # the climb is the composition
    Land("ridge", half=250, h=22),
    Land("patch", half=215, depth=9),
    Land("mesa", at=16, half=178, h=54),
    # The rock is faced with the temple's own terraces rather than left bare, and the stair runs
    # up that face -- a flight climbing open air beside a hill is a ladder, not an approach.
    Fix("wall", span=(-150, 176), y=3, h=13),
    Fix("wall", span=(-120, 150), y=26, h=9),
    Fix("keep", x=54, y=-10, w=25, h=146, on="land"),
    Fix("tower", x=120, y=-4, w=14, h=88, on="land"),
    Fix("tower", x=-12, y=-6, w=16, h=102, on="land"),
    Fix("tower", x=-86, y=-2, w=12, h=62, on="land"),
    Fix("stair", x=-30, y=26, w=40, h=26),            # up the face, to the gate on the terrace
    Fix("gate", x=-30, y=2, w=44, h=70),
    Fix("shrine", x=-78, y=2, w=6, h=13),
    Fix("shrine", x=18, y=2, w=6, h=13),
    Land("mist", at=20, half=230, h=15, depth=3),
))

JUNGLE_COURT = Plan("jungle_court", 290, 250, 215, (  # one enormous tower over a walled court
    Land("ridge", half=250, h=14),
    Land("patch", half=215, depth=10),
    Fix("wall", span=(-190, 190), y=2, h=18),
    Fix("keep", x=-16, y=-16, w=30, h=162),           # the dominant mass, everything under it
    Fix("tower", x=-96, y=-10, w=13, h=66),
    Fix("tower", x=62, y=-10, w=14, h=74),
    Fix("gate", x=-140, y=2, w=40, h=60),
    Fix("gate", x=118, y=2, w=40, h=56),
    Fix("stair", x=-140, y=3, w=32, h=12),
    Fix("stair", x=118, y=3, w=32, h=11),
    Fix("shrine", x=-16, y=2, w=7, h=15),
    Fix("shrine", x=-48, y=2, w=5, h=10),
    Fix("shrine", x=16, y=2, w=5, h=10),
    Row(span=(-250, -212), pieces=(("house", 1.0),), w=(18, 24), h=(22, 30), gap=(20, 34), y=5),
    Row(span=(214, 252), pieces=(("house", 1.0),), w=(18, 24), h=(22, 30), gap=(20, 34), y=5),
    Land("mist", at=0, half=250, h=11, depth=5),
))


LAYOUTS = {
    "village": (WAE_RING, WAE_TERRACE, WAE_RIVER, WAE_CLEARING),
    "town": (STILT_ROW, TWO_BANKS, LANDING, UPRIVER),
    "fortress": (KORI_AGUNG, ELEVEN_MERUS, GATE_OF_STAIRS, JUNGLE_COURT),
}
