"""Where the desert puts what it builds: the three plans, carried over unchanged.

This environment is finished. It was drawn from the Ait Benhaddou photographs before any of
the others, and it is the hand-written original the layout engine was generalised from -- the
proof that a plan said as data could say what a plan written as code said. It does not change,
and `qa.py frozen` holds twenty hashes that say so if it ever does.

Its three plans are still one idea under four seeds apiece, which is why `layouts are twins`
reports two pairs on its fortress. That is the price of freezing it and it is expected rather
than a regression: every other place here has four separate plans to a variant.
"""
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- the desert
# Rammed earth, flat roofs behind a parapet, and the stack of cubes climbing a rock that the
# reference photographs are all of.

DOMES = Plan("domes", 296, 252, 165, (
    Land("patch", half=165, depth=8),
    Row(span=(-124, 108), pieces=(("cluster", 1.0),), w=(24, 40), h=(10, 14),
        gap=(28, 46), y=-22, jitter=6),
    Row(span=(-152, 130), pieces=(("cluster", 1.0),), w=(40, 70), h=(18, 24),
        gap=(10, 26), y=1, jitter=4),
    Fix("yard", span=(-192, -162), y=1, h=6),
    Fix("yard", span=(176, 208), y=1, h=5),
    Belt(span=(-120, 40), y=4, count=3, scrub=0.0),     # no oasis worth the name
))

## The acid test of the plan language: Aït Benhaddou, a ksar terraced up the flank of a crag with a
## watchtower alone on the crest. If this cannot be said as data then the engine cannot hold the
## mountains town either, which the references show is the same structure.
KSAR = Plan("ksar", 286, 254, 215, (
    Land("patch", half=215, depth=9),
    Land("mesa", at=-30, half=172, h=76),               # publishes the standing line
    Course(span=(-96, 176), piece="house", w=(15, 27), h=(11, 18), drop=(3, 8), step=(13, 19)),
    Fix("tower", x=-34, y=6, w=13, h=30, on="crest"),   # the granary alone on the top
    Fix("wall", span=(-96, -54), y=14, h=9, on="crest"),
    Fix("tower", x=118, y=-4, w=15, h=44),              # the corner of the lower quarter
    Fix("tower", x=-88, y=-2, w=13, h=34),
    Fix("gate", x=24, y=2, w=34, h=16),
    Belt(span=(-200, 210), y=6, count=10, scrub=0.9),
))

KASBAH = Plan("kasbah", 288, 252, 215, (
    Land("ridge", half=250, h=13),
    Land("patch", half=215, depth=10),
    Row(span=(-138, 128), w=(24, 32), h=(17, 26), gap=(12, 24), y=-26),
    Fix("keep", x=0, y=-30, w=100, h=42),               # one block, set back
    # Nothing here is mirrored: four towers of a height at an even spacing read as a fence.
    Fix("tower", x=-58, y=-30, w=21, h=74),
    Fix("tower", x=58, y=-30, w=19, h=64),
    Row(span=(-116, 120), w=(22, 26), h=(16, 20), gap=(28, 52), y=-12),
    Fix("wall", span=(-186, -30), y=0, h=26),           # the curtain, the gate cut through
    Fix("wall", span=(30, 190), y=0, h=24),
    Fix("tower", x=-194, y=0, w=23, h=54),
    Fix("tower", x=198, y=0, w=20, h=46),
    Fix("tower", x=-122, y=0, w=15, h=38),              # a bastion partway along each run, at
    Fix("tower", x=146, y=0, w=14, h=34),               # neither the same place nor size
    Fix("gate", x=0, y=2, w=46, h=30),
    Row(span=(-252, -228), w=(18, 24), h=(12, 16), gap=(40, 60), y=6),
    Row(span=(234, 288), w=(18, 24), h=(12, 16), gap=(2, 10), y=6),
    Belt(span=(-220, 230), y=7, count=6, scrub=0.45),
))


LAYOUTS = {
    "village": (DOMES,) * 4,
    "town": (KSAR,) * 4,
    "fortress": (KASBAH,) * 4,
}
