"""Where the ice puts what it builds: twelve plans, four to a variant.

One culture at three scales. The village is snow blocks with a warm door in each; the town is dark
timber under heavy snow, upswept eaves and lanterns, climbing a slope; the fortress is a palace cut
from a berg. What ties them is not a material -- snow, timber and carved ice are three different
things -- but a habit: every roof curls up at its ends, everything horizontal carries a load of
snow, and every opening has a light behind it.

That last one is the environment. In a palette where nothing else leaves the blues, the amber is
the only thing that says people rather than weather, so every plan here spends some.
"""
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- village: the snow houses
# Domes on a white field. The danger is white on white -- what keeps these legible is the ink line
# over each dome, the block seams inside it, and the lit door, so no plan here is allowed to be
# only domes.

FLOE = Plan("floe", 288, 252, 160, (                  # a camp on the flat, and one lamp
    Land("patch", half=160, depth=7),
    Row(span=(-140, -26), pieces=(("dome", 1.0),), w=(32, 46), h=(16, 23), gap=(2, 10), y=0,
        jitter=3),
    Row(span=(24, 148), pieces=(("dome", 1.0),), w=(32, 46), h=(16, 23), gap=(2, 10), y=0,
        jitter=3),
    Fix("house", x=-4, y=-3, w=34, h=34),             # one timber house, the year-rounder
    Fix("lamp", x=-36, y=1, w=3, h=18),
    Belt(span=(-230, 240), y=5, count=5, scrub=0.8),
))

SNOW_ROW = Plan("snow_row", 292, 250, 175, (          # domes below, timber above, along a ridge
    Land("ridge", half=230, h=14),
    Land("patch", half=175, depth=8),
    Row(span=(-158, 20), pieces=(("dome", 1.0),), w=(30, 42), h=(15, 21), gap=(2, 12), y=3),
    Row(span=(-118, 130), pieces=(("house", 1.0),), w=(26, 38), h=(28, 40), gap=(8, 22), y=-14,
        jitter=4),
    Fix("lamp", x=132, y=1, w=3, h=16),
    Belt(span=(-240, 250), y=5, count=6, scrub=0.9),
))

BERG = Plan("berg", 282, 252, 190, (                  # the village up the side of the pack ice
    Land("patch", half=190, depth=8),
    Land("mesa", at=-10, half=148, h=58),
    Course(span=(-110, 138), piece="dome", w=(30, 42), h=(15, 21), drop=(4, 9), step=(26, 36)),
    Fix("house", x=-34, y=-4, w=34, h=38, on="land"),
    Fix("lamp", x=14, y=1, w=3, h=15, on="land"),
    Belt(span=(-240, 250), y=6, count=6, scrub=1.0),
))

LAMPLIGHT = Plan("lamplight", 270, 252, 165, (        # fewer and bigger, and lit
    Land("patch", half=165, depth=9),
    Row(span=(-132, 126), pieces=(("dome", 0.68), ("house", 0.32)), w=(38, 54), h=(19, 27),
        gap=(4, 16), y=0, jitter=4),
    Fix("lamp", x=-8, y=1, w=3, h=22),
    Fix("lamp", x=-124, y=2, w=3, h=14),
    Fix("lamp", x=126, y=2, w=3, h=16),
    Belt(span=(-250, 260), y=6, count=8, scrub=1.3),
))

# ---------------------------------------------------------------- town: the lantern town
# Dark timber packed tight under snow, and the pagoda standing out of it. The reference is a town
# seen at dusk in a snowstorm: the buildings are nearly black and the picture is the snow on them
# and the light out of them.

HEARTHS = Plan("hearths", 288, 252, 210, (            # a dense row with the tower in the middle
    Land("ridge", half=240, h=12),
    Land("patch", half=210, depth=8),
    Row(span=(-172, -34), pieces=(("house", 1.0),), w=(24, 36), h=(24, 38), gap=(2, 10), y=0,
        jitter=3),
    Row(span=(38, 176), pieces=(("house", 1.0),), w=(24, 36), h=(24, 38), gap=(2, 10), y=0,
        jitter=3),
    Fix("spire", x=0, y=-2, w=26, h=78),
    Fix("lamp", x=-28, y=1, w=3, h=18),
    Fix("lamp", x=30, y=1, w=3, h=16),
    Belt(span=(-250, 255), y=5, count=5, scrub=0.7),
))

DRIFT_TOWN = Plan("drift_town", 284, 252, 200, (      # the town terraced up the berg
    Land("patch", half=200, depth=8),
    Land("mesa", at=8, half=160, h=66),
    Course(span=(-92, 148), piece="house", w=(22, 34), h=(22, 34), drop=(4, 10), step=(24, 34)),
    Fix("spire", x=40, y=-4, w=24, h=70, on="land"),
    Fix("house", x=-130, y=0, w=30, h=28),
    Fix("lamp", x=-98, y=1, w=3, h=17),
    Belt(span=(-250, 255), y=6, count=6, scrub=0.9),
))

LANTERN_WAY = Plan("lantern_way", 288, 252, 205, (    # a street, lit down its length
    Land("ridge", half=240, h=10),
    Land("patch", half=205, depth=8),
    Row(span=(-186, -52), pieces=(("house", 1.0),), w=(26, 38), h=(26, 40), gap=(2, 8), y=-6),
    Row(span=(56, 190), pieces=(("house", 1.0),), w=(26, 38), h=(26, 40), gap=(2, 8), y=-6),
    Fix("gate", x=0, y=1, w=34, h=30),
    Fix("lamp", x=-44, y=1, w=3, h=20),
    Fix("lamp", x=46, y=1, w=3, h=20),
    Fix("lamp", x=-150, y=2, w=3, h=15),
    Fix("lamp", x=152, y=2, w=3, h=15),
    Fix("spire", x=-96, y=-8, w=20, h=58),
    Belt(span=(-250, 255), y=5, count=4, scrub=0.6),
))

TWO_PAGODAS = Plan("two_pagodas", 292, 252, 205, (    # two towers, neither in the middle
    Land("ridge", half=240, h=16),
    Land("patch", half=205, depth=9),
    Fix("spire", x=-84, y=-2, w=28, h=92),
    Fix("spire", x=74, y=-2, w=22, h=62),
    Row(span=(-46, 50), pieces=(("house", 1.0),), w=(22, 32), h=(22, 32), gap=(4, 12), y=1),
    Row(span=(-186, -122), pieces=(("house", 1.0),), w=(22, 30), h=(20, 30), gap=(6, 16), y=3),
    Row(span=(120, 188), pieces=(("house", 1.0),), w=(22, 30), h=(20, 30), gap=(6, 16), y=3),
    Fix("lamp", x=-6, y=1, w=3, h=19),
    Belt(span=(-250, 255), y=5, count=5, scrub=0.8),
))

# ---------------------------------------------------------------- fortress: the ice palace
# One dominant mass with everything stepping down from it; the base hidden; and the tallest thing
# carrying this culture's crown, which is a needle with a lamp at its foot rather than a pennant.
# Nothing here is fortified -- the reference has no battlement anywhere in it, and it must not
# grow one, because a crenellation is the single most castle-like mark there is.

GLASS_CROWN = Plan("glass_crown", 288, 250, 215, (    # the dome, ringed by its needles
    Land("ridge", half=250, h=18),
    Land("patch", half=215, depth=9),
    Fix("bulwark", span=(-200, -46), y=2, h=18),
    Fix("bulwark", span=(46, 202), y=2, h=18),
    Fix("great", x=-118, y=-8, w=27, h=128),
    Fix("great", x=-64, y=-6, w=18, h=92),
    Fix("keep", x=0, y=-30, w=76, h=46),              # the dome, the one round thing in the set
    Fix("great", x=58, y=-6, w=23, h=110),
    Fix("great", x=116, y=-8, w=31, h=150),           # the one that dominates, off centre
    Fix("great", x=150, y=-4, w=16, h=74),
    Fix("bulwark", span=(-46, 46), y=2, h=26),
    Fix("lamp", x=-30, y=1, w=3, h=16),
    Fix("lamp", x=32, y=1, w=3, h=16),
    Fix("causeway", span=(-262, -150), y=4, h=18),
    Land("mist", at=0, half=250, h=12, depth=5),
))

NEEDLE_FIELD = Plan("needle_field", 292, 252, 215, (  # a thicket of spires on an arcaded terrace
    Land("ridge", half=250, h=22),
    Land("patch", half=215, depth=9),
    Land("mesa", at=0, half=168, h=40),
    Fix("bulwark", span=(-164, 168), y=3, h=15),
    Fix("great", x=-130, y=-4, w=14, h=66, on="land"),
    Fix("great", x=-96, y=-6, w=23, h=116, on="land"),
    Fix("great", x=-52, y=-4, w=16, h=84, on="land"),
    Fix("great", x=-6, y=-8, w=33, h=158, on="land"),
    Fix("great", x=44, y=-4, w=18, h=96, on="land"),
    Fix("great", x=88, y=-6, w=25, h=124, on="land"),
    Fix("great", x=132, y=-2, w=14, h=62, on="land"),
    Fix("bulwark", span=(-70, 70), y=2, h=24),
    Fix("lamp", x=-84, y=1, w=3, h=15),
    Fix("lamp", x=86, y=1, w=3, h=15),
    Land("mist", at=0, half=250, h=15, depth=4),
))

FROZEN_COURT = Plan("frozen_court", 286, 250, 215, (  # a court, entered along a causeway
    Land("ridge", half=250, h=14),
    Land("patch", half=215, depth=9),
    Fix("bulwark", span=(-70, 200), y=2, h=20),
    Fix("keep", x=104, y=-24, w=62, h=38),
    Fix("great", x=28, y=-6, w=29, h=142),            # the dominant needle, well off centre
    Fix("great", x=66, y=-4, w=18, h=88),
    Fix("great", x=150, y=-6, w=23, h=108),
    Fix("great", x=192, y=-2, w=14, h=64),
    Fix("gate", x=-70, y=1, w=34, h=34),
    Fix("causeway", span=(-250, -74), y=4, h=22),
    Fix("lamp", x=-104, y=2, w=3, h=17),
    Land("mist", at=40, half=230, h=13, depth=5),
))

BERG_PALACE = Plan("berg_palace", 280, 252, 215, (    # the palace on the ice, climbed up to
    Land("ridge", half=250, h=24),
    Land("patch", half=215, depth=10),
    # A low wide plinth rather than a hill. Drawn tall, the berg becomes the subject and the palace
    # clings to its shoulder, which is the wrong way round -- the ice is what the thing stands on,
    # and a mound of near-white has no detail worth looking at on its own account.
    Land("mesa", at=-4, half=172, h=44),
    Fix("bulwark", span=(-150, 160), y=3, h=14),
    Fix("great", x=-108, y=-4, w=16, h=86, on="land"),
    Fix("great", x=-54, y=-6, w=24, h=124, on="land"),
    Fix("keep", x=6, y=-24, w=66, h=40, on="land"),
    Fix("great", x=66, y=-8, w=32, h=162, on="land"),  # the dominant mass, and off centre
    Fix("great", x=118, y=-4, w=17, h=94, on="land"),
    Fix("bulwark", span=(-70, 76), y=2, h=26),
    Fix("causeway", span=(-256, -148), y=4, h=18),
    Fix("lamp", x=-92, y=2, w=3, h=16),
    Fix("lamp", x=96, y=2, w=3, h=14),
    Land("mist", at=0, half=250, h=17, depth=3),
))


LAYOUTS = {
    "village": (FLOE, SNOW_ROW, BERG, LAMPLIGHT),
    "town": (HEARTHS, DRIFT_TOWN, LANTERN_WAY, TWO_PAGODAS),
    "fortress": (GLASS_CROWN, NEEDLE_FIELD, FROZEN_COURT, BERG_PALACE),
}
