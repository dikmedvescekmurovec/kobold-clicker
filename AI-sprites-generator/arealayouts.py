"""The settlement catalogue: which plans each style builds, per variant.

`LAYOUTS[style][variant]` is a tuple of plans, one per layout index. A place with four entries is
four different settlements; a place whose entries repeat one plan is that plan under four seeds,
which the engine makes four arrangements of but not four ideas. `qa.py areas` tells the two apart
with its "layouts are twins" check, and the entries here that repeat are the worklist.

Every plan below is transcribed from the hand-written settlement it replaces, so the first build
after the engine lands should look like the one before it.
"""
import lay_forest as _forest
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- the north
# Timber, gables and stone: what grass builds with, and what the other northern places used before
# their own references were read.

HAMLET = Plan("hamlet", 300, 252, 130, (
    Land("patch", half=130, depth=9),
    # The far row is thinner and one house in three is a tree, so the cluster has a back edge
    # rather than a wall of roofs.
    Row(span=(-92, 96), pieces=(("house", 0.65), ("tree", 0.35)), w=(18, 24), h=(12, 15),
        gap=(18, 38), y=-14, jitter=6),
    Row(span=(-104, 116), w=(26, 34), h=(17, 22), gap=(20, 34), y=0, jitter=3),
    Fix("yard", span=(-128, -106), y=1, h=4),
    Fix("yard", span=(132, 164), y=1, h=4),
    Row(span=(-150, 172), pieces=(("tree", 1.0),), w=(12, 16), h=(14, 19), gap=(120, 180), y=-2),
))

WALLED = Plan("walled", 290, 250, 205, (
    Land("patch", half=205, depth=11),
    Row(span=(-150, 150), w=(22, 26), h=(15, 18), gap=(18, 34), y=-26),
    Fix("spire", x=78, y=-22, w=15, h=54),
    # The halls are the middle of the town: long, low and few, so the roofs behind them read as
    # roofs rather than as more of the same.
    Row(span=(-96, 116), pieces=(("hall", 1.0),), w=(40, 54), h=(20, 26), gap=(22, 40), y=-13),
    Row(span=(-166, 170), w=(24, 28), h=(16, 18), gap=(30, 60), y=-2),
    Fix("wall", span=(-200, -34), y=2, h=14),
    Fix("wall", span=(34, 200), y=2, h=14),
    Fix("gate", x=0, y=2, w=40, h=18),
))

KEEP_ON_A_RISE = Plan("keep on a rise", 288, 250, 60, (
    Land("ridge", half=240, h=14),
    Land("patch", half=60, depth=10),
    Fix("wall", span=(-178, -40), y=0, h=30),
    Fix("wall", span=(40, 178), y=0, h=30),
    Fix("tower", x=-186, y=0, w=20, h=52),
    Fix("tower", x=186, y=0, w=20, h=52),
    Fix("keep", x=0, y=-26, w=140, h=44),
    Fix("spire", x=0, y=-44, w=26, h=86),          # the great tower over the gate
    Fix("gate", x=0, y=2, w=46, h=30),
    # The outliers live on the flanks, and their spans are cut so the walk cannot reach the middle:
    # this row is drawn last, so anything landing near cx would be a hut on top of the gatehouse.
    Row(span=(-254, -230), w=(18, 24), h=(12, 16), gap=(40, 60), y=6),
    Row(span=(240, 290), w=(18, 24), h=(12, 16), gap=(2, 10), y=6),
))

# ---------------------------------------------------------------- grass, the half-timbered north
# From the references: cottages along a lane with the gable ends facing it, a stone tower or a
# turret standing over them, and steep roofs throughout. Four ideas a tier, not one idea reseeded --
# what separates them is the plan of the place, not the size of the houses.

GREEN = Plan("green", 300, 252, 132, (                     # cottages loose around an open middle
    Land("patch", half=132, depth=9),
    Row(span=(-96, 100), pieces=(("house", 0.6), ("tree", 0.4)), w=(16, 22), h=(11, 14),
        gap=(20, 40), y=-15, jitter=6),
    Row(span=(-110, -30), w=(22, 30), h=(15, 20), gap=(14, 26), y=0, jitter=4),
    Row(span=(40, 120), w=(22, 30), h=(15, 20), gap=(14, 26), y=0, jitter=4),
    Fix("yard", span=(-26, 34), y=1, h=4),                 # the green itself, fenced not built on
    Row(span=(-152, 170), pieces=(("tree", 1.0),), w=(12, 16), h=(14, 19), gap=(120, 180), y=-2),
))

LANE = Plan("lane", 296, 252, 140, (                       # a tight street, one hall over it
    Land("patch", half=140, depth=10),
    Row(span=(-104, 108), pieces=(("house", 0.75), ("tree", 0.25)), w=(15, 20), h=(10, 13),
        gap=(10, 22), y=-16, jitter=4),
    Fix("hall", x=-14, y=0, w=34, h=24),
    Row(span=(-118, -40), w=(20, 26), h=(14, 18), gap=(2, 9), y=0, jitter=2),
    Row(span=(22, 126), w=(20, 26), h=(14, 18), gap=(2, 9), y=0, jitter=2),
    Fix("yard", span=(130, 162), y=1, h=4),
    Row(span=(-160, 176), pieces=(("tree", 1.0),), w=(12, 16), h=(15, 20), gap=(130, 190), y=-2),
))

CROFTS = Plan("crofts", 304, 252, 150, (                   # few houses, much fence, many trees
    Land("patch", half=150, depth=8),
    Row(span=(-110, 120), pieces=(("tree", 0.55), ("house", 0.45)), w=(16, 22), h=(11, 15),
        gap=(24, 52), y=-14, jitter=7),
    Fix("yard", span=(-136, -88), y=1, h=4),
    Row(span=(-76, 30), w=(22, 28), h=(14, 19), gap=(30, 58), y=0, jitter=5),
    Fix("yard", span=(52, 104), y=1, h=4),
    Row(span=(60, 130), w=(20, 26), h=(13, 17), gap=(34, 60), y=1, jitter=4),
    Row(span=(-170, 180), pieces=(("tree", 1.0),), w=(12, 17), h=(15, 21), gap=(70, 130), y=-2),
))

CHAPEL = Plan("chapel", 292, 252, 146, (                   # the stone tower the reference stands behind
    Land("patch", half=146, depth=9),
    Row(span=(-104, 96), pieces=(("house", 0.7), ("tree", 0.3)), w=(15, 21), h=(10, 14),
        gap=(16, 34), y=-16, jitter=5),
    Fix("tower", x=48, y=-12, w=13, h=40),
    Row(span=(-116, 24), w=(21, 28), h=(14, 19), gap=(8, 20), y=0, jitter=3),
    Row(span=(74, 134), w=(19, 25), h=(13, 17), gap=(12, 26), y=0, jitter=3),
    Row(span=(-156, 172), pieces=(("tree", 1.0),), w=(12, 16), h=(14, 19), gap=(110, 170), y=-2),
))

BURGH = Plan("burgh", 290, 250, 205, (                     # walled, the turret over the gate
    Land("patch", half=205, depth=11),
    Row(span=(-150, 150), w=(18, 24), h=(13, 17), gap=(14, 30), y=-27),
    Fix("spire", x=64, y=-22, w=13, h=44),
    Row(span=(-100, 116), pieces=(("hall", 1.0),), w=(30, 42), h=(20, 26), gap=(16, 32), y=-13),
    Row(span=(-166, 170), w=(20, 26), h=(15, 19), gap=(26, 52), y=-2),
    Fix("wall", span=(-200, -34), y=2, h=14),
    Fix("wall", span=(34, 200), y=2, h=14),
    Fix("gate", x=0, y=2, w=40, h=18),
))

MARKET = Plan("market", 288, 250, 196, (                   # no wall: a dense knot round a turret
    Land("patch", half=196, depth=11),
    Row(span=(-140, 144), w=(17, 23), h=(12, 16), gap=(8, 20), y=-28),
    Fix("spire", x=-8, y=-16, w=15, h=52),
    Row(span=(-150, -28), pieces=(("hall", 1.0),), w=(28, 40), h=(19, 25), gap=(4, 14), y=-12),
    Row(span=(26, 150), pieces=(("hall", 1.0),), w=(28, 40), h=(19, 25), gap=(4, 14), y=-12),
    Row(span=(-176, 180), w=(20, 27), h=(14, 19), gap=(10, 26), y=0),
    Fix("yard", span=(-200, -180), y=1, h=4),
))

TERRACE = Plan("terrace", 286, 250, 200, (                 # a stepped street with its outside stair
    Land("patch", half=200, depth=11),
    Row(span=(-146, 150), w=(17, 22), h=(12, 16), gap=(6, 16), y=-30),
    Row(span=(-130, 40), pieces=(("hall", 1.0),), w=(26, 36), h=(22, 28), gap=(2, 10), y=-14),
    Fix("stair", span=(46, 76), y=-2, h=16),
    Fix("spire", x=96, y=-14, w=14, h=46),
    Row(span=(-170, -60), w=(20, 26), h=(14, 18), gap=(8, 20), y=0),
    Row(span=(112, 178), w=(20, 26), h=(14, 18), gap=(8, 20), y=0),
    Fix("wall", span=(-200, -150), y=2, h=12),
    Fix("wall", span=(150, 200), y=2, h=12),
))

WHARF = Plan("wharf", 292, 250, 202, (                     # a long row, gapped, two turrets
    Land("patch", half=202, depth=10),
    Row(span=(-152, 156), w=(18, 24), h=(12, 17), gap=(16, 38), y=-26),
    Fix("spire", x=-118, y=-10, w=13, h=42),
    Fix("spire", x=122, y=-12, w=14, h=46),
    Row(span=(-96, 104), pieces=(("hall", 1.0),), w=(30, 44), h=(20, 27), gap=(10, 26), y=-12),
    Row(span=(-180, 184), w=(19, 25), h=(13, 18), gap=(20, 44), y=0),
    Fix("yard", span=(-206, -178), y=1, h=4),
    Fix("yard", span=(180, 208), y=1, h=4),
))

## The four grass castles. What the references have and the old transcription did not is a stepped
## skyline: towers at four heights and a roof line over the hall, so the silhouette climbs instead
## of running flat across the shot. A keep wider than about eighty is a grey bar whatever is drawn
## on it, so the mass comes from stacking, never from one big block.

MOTTE = Plan("motte", 288, 250, 76, (                      # the hall on the mound, gate below it
    Land("ridge", half=240, h=18),
    Land("patch", half=76, depth=10),
    Fix("wall", span=(-166, -38), y=0, h=24),
    Fix("wall", span=(38, 166), y=0, h=24),
    Fix("tower", x=-174, y=0, w=18, h=40),
    Fix("tower", x=174, y=0, w=18, h=44),
    Fix("keep", x=-10, y=-22, w=72, h=32),
    Fix("spire", x=44, y=-26, w=17, h=62),
    Fix("gate", x=0, y=2, w=40, h=22),
    Row(span=(-248, -224), w=(18, 24), h=(12, 16), gap=(40, 60), y=6),
))

SPUR_CASTLE = Plan("spur castle", 288, 250, 80, (          # everything pushed to one flank
    Land("ridge", half=240, h=16),
    Land("patch", half=80, depth=10),
    Fix("wall", span=(-152, -30), y=0, h=22),
    Fix("wall", span=(30, 180), y=0, h=28),
    Fix("tower", x=-160, y=0, w=16, h=36),
    Fix("tower", x=188, y=0, w=20, h=52),
    Fix("keep", x=-66, y=-20, w=64, h=30),
    Fix("tower", x=-104, y=-18, w=16, h=54),
    Fix("spire", x=86, y=-26, w=19, h=70),
    Fix("gate", x=0, y=2, w=40, h=24),
    Row(span=(-246, -222), w=(18, 24), h=(12, 16), gap=(40, 60), y=6),
))

BAILEY = Plan("bailey", 288, 250, 150, (                   # a low curtain with a yard full of roofs
    Land("ridge", half=250, h=11),
    Land("patch", half=150, depth=10),
    Row(span=(-118, 122), w=(17, 23), h=(12, 16), gap=(12, 28), y=-22),
    Fix("keep", x=-6, y=-20, w=68, h=28),
    Fix("tower", x=-52, y=-20, w=16, h=50),
    Fix("wall", span=(-184, -34), y=0, h=18),
    Fix("wall", span=(34, 184), y=0, h=18),
    Fix("tower", x=-192, y=0, w=18, h=38),
    Fix("tower", x=192, y=0, w=18, h=34),
    Fix("gate", x=0, y=2, w=42, h=20),
    Row(span=(-250, -226), w=(18, 24), h=(12, 16), gap=(40, 60), y=6),
    Row(span=(232, 284), w=(18, 24), h=(12, 16), gap=(2, 10), y=6),
))

TWIN_WARD = Plan("twin ward", 288, 250, 88, (              # two halls, neither the same height
    Land("ridge", half=244, h=15),
    Land("patch", half=88, depth=10),
    Fix("wall", span=(-170, -44), y=0, h=24),
    Fix("wall", span=(44, 170), y=0, h=24),
    Fix("keep", x=-88, y=-22, w=58, h=30),
    Fix("keep", x=84, y=-16, w=52, h=24),
    Fix("tower", x=-178, y=0, w=18, h=46),
    Fix("tower", x=178, y=0, w=18, h=38),
    Fix("spire", x=-2, y=-30, w=20, h=72),
    Fix("gate", x=0, y=2, w=44, h=26),
    Row(span=(-248, -224), w=(18, 24), h=(12, 16), gap=(40, 60), y=6),
))


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




# ---------------------------------------------------------------- mountains, built on the rock
# The reference village is not on a flat -- it is on a crag, and it climbs it. So all three tiers
# take the same two land steps the ksar does: a patch for the foot, then a mesa that publishes a
# standing line for a Course to walk down. What differs from the desert is the roof: steep dark
# shingle at a dozen heights, which is the sawtooth the whole silhouette is made of.

CRAGTOP = Plan("cragtop", 288, 252, 190, (
    Land("patch", half=190, depth=9),
    Land("mesa", at=-16, half=150, h=62),
    Course(span=(-104, 130), piece="house", w=(14, 22), h=(10, 15), drop=(2, 7), step=(11, 16)),
    Fix("yard", span=(120, 186), y=1, h=6),
    Row(span=(-190, -140), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 18), gap=(30, 60), y=-2),
    Row(span=(150, 200), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 18), gap=(30, 60), y=-2),
))

SHELF = Plan("shelf", 292, 252, 200, (
    Land("patch", half=200, depth=10),
    Land("mesa", at=10, half=132, h=40),
    Course(span=(-86, 120), piece="house", w=(15, 23), h=(11, 16), drop=(3, 9), step=(13, 19)),
    Row(span=(-176, -110), w=(15, 21), h=(11, 15), gap=(14, 30), y=0, jitter=4),
    Fix("yard", span=(-200, -180), y=1, h=6),
    Row(span=(140, 194), pieces=(("tree", 1.0),), w=(11, 15), h=(14, 19), gap=(26, 50), y=-2),
))

SADDLE = Plan("saddle", 286, 252, 196, (
    Land("patch", half=196, depth=9),
    Land("mesa", at=-92, half=86, h=54),
    Land("mesa", at=96, half=78, h=44),
    Course(span=(-160, -30), piece="house", w=(14, 20), h=(10, 14), drop=(2, 6), step=(10, 15)),
    Course(span=(40, 160), piece="house", w=(14, 20), h=(10, 14), drop=(2, 6), step=(10, 15)),
    Row(span=(-24, 30), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 17), gap=(24, 44), y=-1),
    Fix("yard", span=(168, 206), y=1, h=6),
))

STEADING = Plan("steading", 296, 252, 180, (
    Land("patch", half=180, depth=8),
    Land("mesa", at=24, half=104, h=36),
    Course(span=(-30, 116), piece="house", w=(16, 24), h=(12, 17), drop=(3, 9), step=(14, 20)),
    Row(span=(-166, -50), pieces=(("house", 0.5), ("tree", 0.5)), w=(15, 21), h=(11, 16),
        gap=(22, 46), y=0, jitter=5),
    Fix("yard", span=(-188, -140), y=1, h=6),
    Row(span=(132, 194), pieces=(("tree", 1.0),), w=(11, 16), h=(14, 20), gap=(22, 44), y=-2),
))

GALLERIES = Plan("galleries", 286, 254, 206, (
    Land("patch", half=206, depth=10),
    Land("mesa", at=-24, half=164, h=72),
    Course(span=(-108, 150), piece="hall", w=(22, 34), h=(14, 22), drop=(3, 8), step=(15, 22)),
    Fix("spire", x=-52, y=6, w=16, h=44, on="crest"),
    Fix("wall", span=(-108, -62), y=16, h=10, on="crest"),
    Fix("tower", x=128, y=-4, w=16, h=46),
    Fix("gate", x=18, y=2, w=36, h=20),
    Row(span=(160, 208), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 18), gap=(26, 48), y=-2),
))

SWITCHBACK = Plan("switchback", 290, 252, 200, (
    Land("patch", half=200, depth=10),
    Land("mesa", at=8, half=140, h=58),
    Course(span=(-70, 134), piece="hall", w=(20, 30), h=(13, 20), drop=(3, 9), step=(14, 20)),
    Fix("stair", span=(-116, -74), y=-4, h=22),
    Row(span=(-186, -124), w=(15, 21), h=(11, 16), gap=(12, 26), y=0, jitter=3),
    Fix("spire", x=62, y=4, w=15, h=40, on="crest"),
    Fix("yard", span=(150, 198), y=1, h=6),
))

HIGH_STREET = Plan("high street", 288, 250, 202, (
    Land("patch", half=202, depth=11),
    Land("mesa", at=0, half=112, h=30),
    Row(span=(-130, 136), w=(16, 22), h=(11, 16), gap=(8, 20), y=-26),
    Course(span=(-74, 92), piece="hall", w=(22, 32), h=(14, 20), drop=(2, 7), step=(14, 20)),
    Fix("spire", x=-96, y=-14, w=16, h=50),
    Fix("wall", span=(-192, -32), y=2, h=14),
    Fix("wall", span=(32, 192), y=2, h=14),
    Fix("gate", x=0, y=2, w=38, h=18),
))

CLIFF_ROW = Plan("cliff row", 292, 252, 206, (
    Land("patch", half=206, depth=9),
    Land("mesa", at=-40, half=126, h=88),
    Course(span=(-130, 60), piece="hall", w=(20, 30), h=(13, 19), drop=(2, 6), step=(12, 18)),
    Fix("spire", x=-70, y=4, w=17, h=52, on="crest"),
    Row(span=(96, 180), w=(16, 22), h=(11, 16), gap=(12, 28), y=0, jitter=3),
    Fix("yard", span=(188, 214), y=1, h=6),
    Row(span=(-206, -170), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 18), gap=(30, 54), y=-2),
))

EYRIE = Plan("eyrie", 288, 250, 120, (
    Land("ridge", half=250, h=12),
    Land("patch", half=120, depth=10),
    Land("mesa", at=0, half=168, h=30),
    Fix("keep", x=-8, y=2, w=64, h=26, on="crest"),
    Fix("spire", x=48, y=8, w=18, h=56, on="crest"),
    Fix("wall", span=(-170, -40), y=0, h=22),
    Fix("wall", span=(40, 170), y=0, h=22),
    Fix("tower", x=-178, y=0, w=18, h=42),
    Fix("tower", x=178, y=0, w=18, h=38),
    Fix("gate", x=0, y=2, w=40, h=22),
    Row(span=(-248, -224), w=(16, 22), h=(11, 15), gap=(40, 60), y=6),
))

WATCH = Plan("watch", 288, 250, 110, (
    Land("ridge", half=246, h=15),
    Land("patch", half=110, depth=10),
    Land("mesa", at=-70, half=150, h=34),
    Fix("keep", x=-78, y=4, w=54, h=24, on="crest"),
    Fix("spire", x=-34, y=10, w=17, h=50, on="crest"),
    Fix("wall", span=(10, 168), y=0, h=26),
    Fix("tower", x=176, y=0, w=20, h=48),
    Fix("tower", x=-160, y=0, w=16, h=34),
    Fix("gate", x=-18, y=2, w=38, h=24),
    Row(span=(236, 286), w=(16, 22), h=(11, 15), gap=(2, 10), y=6),
))

BARBICAN = Plan("barbican", 288, 250, 150, (
    Land("ridge", half=250, h=10),
    Land("patch", half=150, depth=10),
    Row(span=(-114, 118), w=(16, 22), h=(11, 16), gap=(10, 24), y=-24),
    Fix("keep", x=-4, y=-20, w=66, h=26),
    Fix("spire", x=-48, y=-20, w=17, h=54),
    Fix("wall", span=(-182, -32), y=-8, h=16),
    Fix("wall", span=(32, 182), y=-8, h=16),
    Fix("wall", span=(-196, -36), y=4, h=14),
    Fix("wall", span=(36, 196), y=4, h=14),
    Fix("tower", x=-200, y=4, w=18, h=40),
    Fix("tower", x=200, y=4, w=18, h=36),
    Fix("gate", x=0, y=4, w=42, h=20),
))

CRAG_HOLD = Plan("crag hold", 288, 250, 130, (
    Land("ridge", half=246, h=14),
    Land("patch", half=130, depth=10),
    Land("mesa", at=-96, half=132, h=32),
    Land("mesa", at=96, half=118, h=24),
    Fix("keep", x=-98, y=4, w=50, h=24, on="crest"),
    Fix("tower", x=96, y=-30, w=18, h=52),
    Fix("wall", span=(-46, 46), y=0, h=24),
    Fix("spire", x=0, y=-22, w=19, h=62),
    Fix("gate", x=0, y=2, w=42, h=24),
    Row(span=(-248, -224), w=(16, 22), h=(11, 15), gap=(40, 60), y=6),
))


# ---------------------------------------------------------------- dirt, the old country
# Roundhouses on an open flat, a stone street where there is anything worth walling, and a keep
# that fell long ago. What dates the place is the ruin: nothing else in the set is already broken.

ROUNDS = Plan("rounds", 298, 252, 144, (
    Land("patch", half=144, depth=9),
    Row(span=(-98, 104), pieces=(("house", 0.7), ("tree", 0.3)), w=(13, 18), h=(9, 13),
        gap=(16, 34), y=-15, jitter=5),
    Row(span=(-112, 112), w=(18, 25), h=(12, 17), gap=(14, 30), y=0, jitter=4),
    Fix("yard", span=(-140, -112), y=1, h=4),
    Fix("yard", span=(118, 152), y=1, h=4),
    Row(span=(-172, 176), pieces=(("tree", 1.0),), w=(12, 16), h=(13, 18), gap=(110, 170), y=-2),
))

HEARTH = Plan("hearth", 294, 252, 136, (
    Land("patch", half=136, depth=10),
    Row(span=(-86, 92), w=(14, 19), h=(10, 14), gap=(12, 26), y=-16, jitter=4),
    Fix("yard", span=(-34, 36), y=1, h=4),
    Row(span=(-120, -44), w=(19, 26), h=(13, 18), gap=(8, 18), y=0, jitter=3),
    Row(span=(48, 126), w=(19, 26), h=(13, 18), gap=(8, 18), y=0, jitter=3),
    Row(span=(-164, 170), pieces=(("tree", 1.0),), w=(12, 16), h=(14, 19), gap=(120, 180), y=-2),
))

DROVE = Plan("drove", 302, 252, 156, (
    Land("patch", half=156, depth=8),
    Row(span=(-104, 118), pieces=(("house", 0.5), ("tree", 0.5)), w=(14, 20), h=(10, 14),
        gap=(22, 46), y=-14, jitter=6),
    Fix("yard", span=(-150, -96), y=1, h=4),
    Row(span=(-70, 60), w=(18, 24), h=(12, 17), gap=(26, 52), y=0, jitter=5),
    Fix("yard", span=(88, 148), y=1, h=4),
    Row(span=(-178, 182), pieces=(("tree", 1.0),), w=(12, 17), h=(14, 20), gap=(60, 120), y=-2),
))

BARROW = Plan("barrow", 290, 252, 150, (
    Land("ridge", half=210, h=10),
    Land("patch", half=150, depth=9),
    Row(span=(-100, 96), w=(13, 18), h=(9, 13), gap=(14, 30), y=-16, jitter=5),
    Fix("keep", x=64, y=-6, w=30, h=26),
    Row(span=(-124, 30), w=(19, 26), h=(13, 18), gap=(10, 24), y=0, jitter=3),
    Fix("yard", span=(-152, -128), y=1, h=4),
    Row(span=(-176, 178), pieces=(("tree", 1.0),), w=(12, 16), h=(13, 18), gap=(110, 170), y=-2),
))

WYND = Plan("wynd", 288, 250, 198, (
    Land("patch", half=198, depth=11),
    Row(span=(-138, 142), w=(15, 21), h=(11, 15), gap=(10, 24), y=-27),
    Fix("spire", x=72, y=-20, w=14, h=46),
    Row(span=(-104, 110), pieces=(("hall", 1.0),), w=(26, 36), h=(19, 25), gap=(10, 24), y=-13),
    Row(span=(-168, 172), w=(18, 24), h=(13, 18), gap=(22, 46), y=-2),
    Fix("wall", span=(-196, -34), y=2, h=14),
    Fix("wall", span=(34, 196), y=2, h=14),
    Fix("gate", x=0, y=2, w=38, h=18),
))

CLOSE = Plan("close", 290, 250, 190, (
    Land("patch", half=190, depth=11),
    Row(span=(-130, 134), w=(15, 20), h=(11, 15), gap=(6, 16), y=-29),
    Row(span=(-140, -20), pieces=(("hall", 1.0),), w=(24, 34), h=(20, 27), gap=(2, 10), y=-12),
    Row(span=(24, 144), pieces=(("hall", 1.0),), w=(24, 34), h=(20, 27), gap=(2, 10), y=-12),
    Fix("stair", span=(-16, 16), y=-2, h=18),
    Fix("spire", x=-98, y=-14, w=15, h=48),
    Row(span=(-176, 180), w=(18, 24), h=(13, 17), gap=(16, 36), y=0),
))

TOLL = Plan("toll", 286, 250, 194, (
    Land("patch", half=194, depth=10),
    Row(span=(-134, 138), w=(15, 21), h=(11, 16), gap=(12, 28), y=-26),
    Fix("keep", x=-92, y=-10, w=34, h=34),
    Row(span=(-50, 120), pieces=(("hall", 1.0),), w=(26, 36), h=(18, 24), gap=(10, 26), y=-12),
    Fix("wall", span=(-188, -30), y=2, h=13),
    Fix("wall", span=(30, 188), y=2, h=13),
    Fix("gate", x=0, y=2, w=36, h=17),
    Row(span=(-214, -196), w=(16, 22), h=(12, 16), gap=(40, 60), y=6),
))

MARCH = Plan("march", 292, 250, 200, (
    Land("patch", half=200, depth=10),
    Row(span=(-146, 150), w=(16, 22), h=(11, 16), gap=(18, 40), y=-25),
    Fix("spire", x=-112, y=-8, w=13, h=40),
    Fix("spire", x=116, y=-12, w=14, h=46),
    Row(span=(-88, 96), pieces=(("hall", 1.0),), w=(28, 38), h=(19, 25), gap=(12, 30), y=-12),
    Row(span=(-178, 182), w=(17, 23), h=(12, 17), gap=(20, 44), y=0),
    Fix("yard", span=(-204, -180), y=1, h=4),
))

BROKEN_KEEP = Plan("broken keep", 288, 250, 90, (
    Land("ridge", half=240, h=16),
    Land("patch", half=90, depth=10),
    Fix("wall", span=(-160, -36), y=0, h=20),
    Fix("wall", span=(36, 160), y=0, h=20),
    Fix("tower", x=-168, y=0, w=17, h=36),
    Fix("tower", x=168, y=0, w=17, h=32),
    Fix("keep", x=-4, y=-18, w=74, h=48),
    Fix("gate", x=0, y=2, w=38, h=20),
    Row(span=(-244, -220), w=(15, 21), h=(10, 14), gap=(40, 60), y=6),
))

HILLFORT = Plan("hillfort", 288, 250, 150, (
    Land("ridge", half=246, h=13),
    Land("patch", half=150, depth=10),
    Row(span=(-108, 112), pieces=(("house", 1.0),), w=(14, 19), h=(10, 14), gap=(10, 24), y=-22),
    Fix("keep", x=-6, y=-18, w=56, h=38),
    Fix("yard", span=(-180, -34), y=-6, h=5),
    Fix("yard", span=(34, 180), y=-6, h=5),
    Fix("wall", span=(-192, -34), y=4, h=14),
    Fix("wall", span=(34, 192), y=4, h=14),
    Fix("gate", x=0, y=4, w=40, h=18),
))

TWO_RUINS = Plan("two ruins", 288, 250, 140, (
    Land("ridge", half=244, h=14),
    Land("patch", half=140, depth=10),
    Fix("keep", x=-84, y=-14, w=52, h=42),
    Fix("keep", x=88, y=-8, w=42, h=30),
    Fix("wall", span=(-52, 56), y=0, h=18),
    Fix("tower", x=-160, y=0, w=16, h=30),
    Fix("gate", x=0, y=2, w=36, h=18),
    Row(span=(-240, -216), w=(15, 21), h=(10, 14), gap=(40, 60), y=6),
    Row(span=(200, 250), w=(15, 21), h=(10, 14), gap=(2, 10), y=6),
))

DYKE = Plan("dyke", 288, 250, 160, (
    Land("ridge", half=250, h=9),
    Land("patch", half=160, depth=10),
    Row(span=(-116, 120), w=(14, 20), h=(10, 14), gap=(12, 28), y=-22),
    Fix("keep", x=-50, y=-16, w=48, h=34),
    Fix("spire", x=56, y=-16, w=15, h=48),
    Fix("yard", span=(-186, -36), y=-10, h=5),
    Fix("yard", span=(36, 186), y=-10, h=5),
    Fix("wall", span=(-198, -34), y=4, h=12),
    Fix("wall", span=(34, 198), y=4, h=12),
    Fix("gate", x=0, y=4, w=38, h=16),
))


# ---------------------------------------------------------------- ice, snow and lamplight
# The village is domes on an open snowfield; the town is dark timber under a thick cap, and what
# carries it at this size is the lit window, not the building. The palace is needles of ice.

FLOE = Plan("floe", 296, 252, 150, (
    Land("patch", half=150, depth=8),
    Row(span=(-96, 100), pieces=(("dome", 0.75), ("tree", 0.25)), w=(11, 16), h=(9, 13),
        gap=(18, 38), y=-14, jitter=6),
    Row(span=(-114, 118), pieces=(("dome", 1.0),), w=(15, 22), h=(12, 17), gap=(14, 32), y=0,
        jitter=4),
    Fix("yard", span=(132, 164), y=1, h=4),
    Row(span=(-168, 176), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 18), gap=(110, 170), y=-2),
))

SNOWFIELD = Plan("snowfield", 292, 252, 158, (
    Land("patch", half=158, depth=9),
    Row(span=(-104, 96), pieces=(("dome", 1.0),), w=(12, 17), h=(9, 13), gap=(22, 44), y=-15,
        jitter=6),
    Row(span=(-130, -20), pieces=(("dome", 1.0),), w=(16, 23), h=(12, 17), gap=(10, 24), y=0),
    Row(span=(30, 136), pieces=(("dome", 1.0),), w=(16, 23), h=(12, 17), gap=(10, 24), y=0),
    Fix("yard", span=(-158, -134), y=1, h=4),
    Row(span=(-176, 180), pieces=(("tree", 1.0),), w=(11, 15), h=(14, 19), gap=(120, 180), y=-2),
))

CAMP = Plan("camp", 300, 252, 146, (
    Land("patch", half=146, depth=8),
    Row(span=(-88, 92), pieces=(("dome", 0.6), ("house", 0.4)), w=(13, 19), h=(10, 14),
        gap=(16, 34), y=-15, jitter=5),
    Row(span=(-112, 116), pieces=(("dome", 0.5), ("house", 0.5)), w=(16, 22), h=(12, 17),
        gap=(12, 28), y=0, jitter=4),
    Fix("yard", span=(-144, -114), y=1, h=4),
    Row(span=(-170, 174), pieces=(("tree", 1.0),), w=(11, 15), h=(13, 18), gap=(110, 170), y=-2),
))

LODGE = Plan("lodge", 294, 252, 152, (
    Land("patch", half=152, depth=9),
    Row(span=(-94, 98), pieces=(("house", 0.8), ("tree", 0.2)), w=(14, 19), h=(10, 14),
        gap=(14, 30), y=-16, jitter=5),
    Row(span=(-118, 122), w=(18, 25), h=(13, 18), gap=(10, 24), y=0, jitter=3),
    Fix("yard", span=(-150, -122), y=1, h=4),
    Row(span=(-174, 178), pieces=(("tree", 1.0),), w=(11, 16), h=(14, 19), gap=(100, 160), y=-2),
))

HEARTHS = Plan("hearths", 288, 250, 196, (
    Land("patch", half=196, depth=11),
    Row(span=(-134, 138), w=(15, 21), h=(11, 16), gap=(8, 20), y=-27),
    Fix("spire", x=68, y=-18, w=12, h=42),
    Row(span=(-104, 112), pieces=(("hall", 1.0),), w=(24, 34), h=(18, 24), gap=(10, 24), y=-13),
    Row(span=(-166, 170), w=(18, 24), h=(13, 18), gap=(20, 44), y=-2),
    Fix("wall", span=(-192, -32), y=2, h=13),
    Fix("wall", span=(32, 192), y=2, h=13),
    Fix("gate", x=0, y=2, w=36, h=17),
))

DRIFT_TOWN = Plan("drift town", 292, 250, 190, (
    Land("patch", half=190, depth=10),
    Row(span=(-128, 132), w=(15, 20), h=(11, 15), gap=(6, 16), y=-29),
    Row(span=(-142, -16), pieces=(("hall", 1.0),), w=(22, 32), h=(19, 25), gap=(2, 10), y=-12),
    Row(span=(22, 146), pieces=(("hall", 1.0),), w=(22, 32), h=(19, 25), gap=(2, 10), y=-12),
    Fix("spire", x=0, y=-16, w=13, h=50),
    Row(span=(-172, 176), w=(17, 23), h=(12, 17), gap=(16, 38), y=0),
))

HARBOUR = Plan("harbour", 286, 250, 198, (
    Land("patch", half=198, depth=10),
    Row(span=(-140, 144), w=(15, 21), h=(11, 16), gap=(14, 32), y=-26),
    Fix("spire", x=-108, y=-10, w=12, h=38),
    Fix("spire", x=112, y=-14, w=13, h=46),
    Row(span=(-84, 92), pieces=(("hall", 1.0),), w=(26, 36), h=(19, 25), gap=(12, 30), y=-12),
    Row(span=(-176, 180), w=(17, 23), h=(12, 17), gap=(18, 40), y=0),
    Fix("yard", span=(-202, -178), y=1, h=4),
))

WINTER_HOLD = Plan("winter hold", 290, 250, 192, (
    Land("patch", half=192, depth=11),
    Row(span=(-132, 136), w=(15, 20), h=(11, 15), gap=(10, 24), y=-28),
    Fix("keep", x=-6, y=-14, w=58, h=26),
    Row(span=(-150, -60), pieces=(("hall", 1.0),), w=(22, 30), h=(18, 24), gap=(6, 18), y=-12),
    Row(span=(66, 152), pieces=(("hall", 1.0),), w=(22, 30), h=(18, 24), gap=(6, 18), y=-12),
    Fix("wall", span=(-188, -32), y=2, h=13),
    Fix("wall", span=(32, 188), y=2, h=13),
    Fix("gate", x=0, y=2, w=36, h=17),
))

GLASS_HALL = Plan("glass hall", 288, 250, 110, (
    Land("patch", half=110, depth=10),
    Fix("wall", span=(-164, -38), y=0, h=22),
    Fix("wall", span=(38, 164), y=0, h=22),
    Fix("keep", x=-4, y=-20, w=62, h=26),
    Fix("spire", x=-56, y=-20, w=15, h=64),
    Fix("spire", x=54, y=-24, w=13, h=76),
    Fix("tower", x=-172, y=0, w=14, h=44),
    Fix("tower", x=172, y=0, w=14, h=38),
    Fix("gate", x=0, y=2, w=40, h=20),
    Row(span=(-244, -220), pieces=(("dome", 1.0),), w=(14, 20), h=(10, 14), gap=(40, 60), y=6),
))

NEEDLES = Plan("needles", 288, 250, 120, (
    Land("patch", half=120, depth=10),
    Fix("wall", span=(-150, -34), y=0, h=18),
    Fix("wall", span=(34, 150), y=0, h=18),
    Fix("spire", x=-96, y=-4, w=14, h=82),
    Fix("spire", x=-42, y=-8, w=12, h=58),
    Fix("spire", x=46, y=-6, w=13, h=70),
    Fix("spire", x=104, y=-2, w=11, h=50),
    Fix("keep", x=0, y=-16, w=50, h=22),
    Fix("gate", x=0, y=2, w=36, h=18),
    Row(span=(-240, -216), pieces=(("dome", 1.0),), w=(14, 20), h=(10, 14), gap=(40, 60), y=6),
))

RIME_WARD = Plan("rime ward", 288, 250, 140, (
    Land("patch", half=140, depth=10),
    Row(span=(-110, 114), w=(15, 20), h=(10, 14), gap=(12, 28), y=-24),
    Fix("keep", x=-70, y=-18, w=48, h=24),
    Fix("keep", x=74, y=-14, w=42, h=20),
    Fix("spire", x=0, y=-26, w=16, h=86),
    Fix("wall", span=(-182, -32), y=2, h=16),
    Fix("wall", span=(32, 182), y=2, h=16),
    Fix("tower", x=-190, y=2, w=14, h=36),
    Fix("gate", x=0, y=2, w=40, h=20),
))

FROST_GATE = Plan("frost gate", 288, 250, 150, (
    Land("patch", half=150, depth=10),
    Row(span=(-112, 116), pieces=(("dome", 1.0),), w=(15, 21), h=(11, 15), gap=(14, 32), y=-22),
    Fix("wall", span=(-176, -40), y=-6, h=16),
    Fix("wall", span=(40, 176), y=-6, h=16),
    Fix("wall", span=(-188, -36), y=4, h=14),
    Fix("wall", span=(36, 188), y=4, h=14),
    Fix("spire", x=-60, y=-18, w=14, h=68),
    Fix("spire", x=64, y=-14, w=12, h=54),
    Fix("keep", x=0, y=-12, w=46, h=22),
    Fix("gate", x=0, y=4, w=40, h=20),
))


# ---------------------------------------------------------------- forest, the warm south
# Cone thatch nearly to the ground, longhouses on posts over the water, and a temple of tiered
# merus behind a split gate. The furthest of the six from anything the set had before.

WAE = Plan("wae", 294, 252, 140, (
    Land("patch", half=140, depth=8),
    Row(span=(-92, 96), pieces=(("house", 0.7), ("tree", 0.3)), w=(12, 17), h=(9, 13),
        gap=(18, 36), y=-14, jitter=5),
    Row(span=(-108, 112), w=(17, 24), h=(12, 17), gap=(14, 30), y=0, jitter=4),
    Fix("yard", span=(126, 156), y=1, h=4),
    Row(span=(-168, 172), pieces=(("tree", 1.0),), w=(12, 17), h=(15, 21), gap=(110, 170), y=-2),
))

CLEARING = Plan("clearing", 300, 252, 146, (
    Land("patch", half=146, depth=8),
    Row(span=(-84, 88), w=(13, 18), h=(10, 14), gap=(14, 30), y=-15, jitter=4),
    Fix("yard", span=(-30, 34), y=1, h=4),
    Row(span=(-118, -40), w=(18, 25), h=(13, 18), gap=(8, 20), y=0, jitter=3),
    Row(span=(44, 124), w=(18, 25), h=(13, 18), gap=(8, 20), y=0, jitter=3),
    Row(span=(-172, 176), pieces=(("tree", 1.0),), w=(12, 17), h=(16, 22), gap=(90, 150), y=-2),
))

KAMPUNG = Plan("kampung", 292, 252, 154, (
    Land("patch", half=154, depth=9),
    Row(span=(-98, 102), pieces=(("house", 0.55), ("hall", 0.45)), w=(16, 24), h=(11, 16),
        gap=(16, 34), y=-15, jitter=5),
    Row(span=(-120, 124), pieces=(("hall", 0.6), ("house", 0.4)), w=(20, 30), h=(14, 20),
        gap=(12, 28), y=0, jitter=4),
    Fix("yard", span=(-152, -124), y=1, h=4),
    Row(span=(-176, 180), pieces=(("tree", 1.0),), w=(12, 17), h=(15, 21), gap=(110, 170), y=-2),
))

SHRINE = Plan("shrine", 288, 252, 150, (
    Land("patch", half=150, depth=9),
    Row(span=(-100, 92), pieces=(("house", 0.75), ("tree", 0.25)), w=(13, 18), h=(9, 13),
        gap=(16, 34), y=-16, jitter=5),
    Fix("tower", x=62, y=-8, w=22, h=42),
    Row(span=(-124, 26), w=(18, 25), h=(13, 18), gap=(10, 24), y=0, jitter=3),
    Row(span=(-172, 176), pieces=(("tree", 1.0),), w=(12, 17), h=(15, 21), gap=(110, 170), y=-2),
))

STILTS = Plan("stilts", 288, 250, 196, (
    Land("patch", half=196, depth=10),
    Row(span=(-132, 136), pieces=(("house", 1.0),), w=(14, 20), h=(10, 15), gap=(12, 28), y=-27),
    Row(span=(-108, 114), pieces=(("hall", 1.0),), w=(28, 40), h=(18, 25), gap=(8, 22), y=-12),
    Fix("spire", x=78, y=-16, w=20, h=46),
    Row(span=(-168, 172), pieces=(("hall", 1.0),), w=(24, 34), h=(16, 22), gap=(20, 44), y=0),
    Fix("gate", x=0, y=2, w=34, h=24),
))

LONGHOUSES = Plan("longhouses", 292, 250, 190, (
    Land("patch", half=190, depth=10),
    Row(span=(-126, 130), pieces=(("house", 1.0),), w=(13, 19), h=(10, 14), gap=(8, 20), y=-28),
    Row(span=(-146, -18), pieces=(("hall", 1.0),), w=(26, 36), h=(19, 26), gap=(4, 14), y=-12),
    Row(span=(24, 150), pieces=(("hall", 1.0),), w=(26, 36), h=(19, 26), gap=(4, 14), y=-12),
    Fix("spire", x=0, y=-18, w=22, h=52),
    Row(span=(-176, 180), pieces=(("house", 1.0),), w=(16, 22), h=(12, 17), gap=(18, 40), y=0),
))

WATER_TOWN = Plan("water town", 286, 250, 198, (
    Land("patch", half=198, depth=10),
    Row(span=(-138, 142), pieces=(("house", 1.0),), w=(14, 20), h=(10, 15), gap=(16, 36), y=-26),
    Fix("spire", x=-104, y=-10, w=19, h=40),
    Fix("spire", x=110, y=-14, w=21, h=48),
    Row(span=(-80, 88), pieces=(("hall", 1.0),), w=(28, 38), h=(19, 25), gap=(12, 30), y=-12),
    Row(span=(-174, 178), pieces=(("hall", 1.0),), w=(22, 32), h=(15, 21), gap=(20, 44), y=0),
    Fix("gate", x=0, y=2, w=32, h=22),
))

TERRACES = Plan("terraces", 290, 250, 200, (
    Land("patch", half=200, depth=11),
    Land("mesa", at=6, half=118, h=34),
    Row(span=(-134, 138), pieces=(("house", 1.0),), w=(14, 20), h=(10, 15), gap=(10, 24), y=-28),
    Course(span=(-70, 92), piece="hall", w=(22, 32), h=(14, 20), drop=(2, 7), step=(14, 20)),
    Fix("spire", x=-100, y=-12, w=20, h=44),
    Fix("wall", span=(-190, -32), y=2, h=12),
    Fix("wall", span=(32, 190), y=2, h=12),
    Fix("gate", x=0, y=2, w=34, h=20),
))

CANDI = Plan("candi", 288, 250, 150, (
    Land("ridge", half=240, h=12),
    Land("patch", half=150, depth=10),
    Fix("keep", x=-4, y=-16, w=46, h=62),
    Fix("spire", x=-72, y=-8, w=30, h=48),
    Fix("spire", x=68, y=-10, w=26, h=44),
    Fix("wall", span=(-172, -40), y=2, h=14),
    Fix("wall", span=(40, 172), y=2, h=14),
    Fix("gate", x=0, y=2, w=40, h=30),
    Row(span=(-244, -220), pieces=(("house", 1.0),), w=(14, 20), h=(10, 14), gap=(40, 60), y=6),
))

MERU_HILL = Plan("meru hill", 288, 250, 160, (
    Land("ridge", half=246, h=15),
    Land("patch", half=160, depth=10),
    Land("mesa", at=0, half=120, h=30),
    Fix("keep", x=0, y=4, w=40, h=58, on="crest"),
    Fix("spire", x=-60, y=6, w=26, h=40, on="crest"),
    Fix("spire", x=58, y=8, w=22, h=34, on="crest"),
    Fix("wall", span=(-178, -38), y=2, h=13),
    Fix("wall", span=(38, 178), y=2, h=13),
    Fix("gate", x=0, y=2, w=38, h=28),
))

FIVE_GATES = Plan("five gates", 288, 250, 170, (
    Land("ridge", half=250, h=10),
    Land("patch", half=170, depth=10),
    Row(span=(-116, 120), pieces=(("house", 1.0),), w=(14, 19), h=(10, 14), gap=(12, 28), y=-24),
    Fix("spire", x=-96, y=-14, w=24, h=42),
    Fix("keep", x=-2, y=-18, w=42, h=54),
    Fix("spire", x=94, y=-12, w=22, h=38),
    Fix("wall", span=(-186, -34), y=2, h=12),
    Fix("wall", span=(34, 186), y=2, h=12),
    Fix("gate", x=-140, y=2, w=30, h=22),
    Fix("gate", x=0, y=2, w=38, h=28),
    Fix("gate", x=140, y=2, w=30, h=22),
))

JUNGLE_HOLD = Plan("jungle hold", 288, 250, 156, (
    Land("ridge", half=244, h=13),
    Land("patch", half=156, depth=10),
    Fix("keep", x=-78, y=-12, w=38, h=50),
    Fix("keep", x=82, y=-8, w=32, h=40),
    Fix("wall", span=(-46, 50), y=0, h=18),
    Fix("spire", x=0, y=-14, w=24, h=40),
    Fix("gate", x=0, y=2, w=36, h=24),
    Row(span=(-240, -216), pieces=(("house", 1.0),), w=(14, 20), h=(10, 14), gap=(40, 60), y=6),
    Row(span=(204, 254), pieces=(("house", 1.0),), w=(14, 20), h=(10, 14), gap=(2, 10), y=6),
))


# ---------------------------------------------------------------- the twenty fortresses
# A fortress is the one thing in a backdrop allowed to dominate it, so these are hand-written rather
# than varied off a template. The first pass built them wide and low -- dirt's rose twenty-nine
# pixels above the horizon, which is a compound, not a stronghold. Every one of these now reaches
# a hundred and more above it, and each is a different idea about what a stronghold is.
#
# Three rules they all keep. Height comes from ONE dominant mass with everything else stepping down
# from it, never from several towers of a height. The base is hidden -- in haze, behind a curtain,
# or over a crag -- because a castle you can see the bottom of is a building. And the tallest thing
# carries a pennant, which at this size does more for scale than another fifty pixels of stone.

# ---- grass: mossy green stone on a crag, gothic and many-towered
CITADEL = Plan("citadel", 288, 250, 150, (
    Land("ridge", half=250, h=20),
    Land("patch", half=150, depth=10),
    Land("mesa", at=-6, half=128, h=46),
    Fix("bulwark", span=(-128, 132), y=2, h=34, on="crest"),
    Fix("great", x=-96, y=4, w=20, h=96, on="crest"),
    Fix("keep", x=-14, y=2, w=78, h=52, on="crest"),
    Fix("great", x=52, y=6, w=24, h=128, on="crest"),      # the one that dominates
    Fix("plain_great", x=110, y=6, w=17, h=74, on="crest"),
    Fix("bulwark", span=(-196, -44), y=2, h=26),
    Fix("bulwark", span=(44, 196), y=2, h=26),
    Fix("plain_great", x=-204, y=2, w=18, h=56),
    Fix("plain_great", x=204, y=2, w=18, h=50),
    Fix("barbican", x=0, y=2, w=48, h=30),
    Land("mist", at=0, half=240, h=12, depth=6),
))

CROWN_KEEP = Plan("crown keep", 288, 250, 140, (
    Land("ridge", half=250, h=16),
    Land("patch", half=140, depth=10),
    Fix("bulwark", span=(-186, -40), y=0, h=30),
    Fix("bulwark", span=(40, 186), y=0, h=30),
    Fix("crown", x=-118, y=0, w=20, h=78),
    Fix("crown", x=122, y=0, w=20, h=70),
    Fix("keep", x=-6, y=-28, w=88, h=54),
    Fix("crown", x=-48, y=-28, w=22, h=104),
    Fix("crown", x=44, y=-28, w=26, h=132),                # the great tower over the hall
    Fix("plain_great", x=-196, y=0, w=17, h=48),
    Fix("plain_great", x=196, y=0, w=17, h=44),
    Fix("barbican", x=0, y=2, w=46, h=28),
    Fix("steps", x=0, y=14, w=64, h=12),
    Land("mist", at=0, half=250, h=9, depth=2),
))

WATERGATE = Plan("watergate", 286, 250, 160, (             # a long low ward under one huge donjon
    Land("ridge", half=250, h=12),
    Land("patch", half=160, depth=10),
    Fix("bulwark", span=(-210, -36), y=0, h=24),
    Fix("bulwark", span=(36, 210), y=0, h=24),
    Fix("keep", x=-70, y=-20, w=70, h=44),
    Fix("great", x=-16, y=-22, w=28, h=146),               # everything steps down from this
    Fix("plain_great", x=-120, y=-18, w=18, h=62),
    Fix("crown", x=76, y=-16, w=20, h=84),
    Fix("plain_great", x=-218, y=0, w=16, h=42),
    Fix("plain_great", x=218, y=0, w=16, h=38),
    Fix("barbican", x=0, y=2, w=44, h=26),
    Row(span=(-252, -228), w=(16, 22), h=(11, 15), gap=(40, 60), y=6),
))

SEVEN_TOWERS = Plan("seven towers", 288, 250, 150, (       # a ring of towers, none of a height
    Land("ridge", half=250, h=18),
    Land("patch", half=150, depth=10),
    Land("mesa", at=10, half=112, h=34),
    Fix("bulwark", span=(-150, 154), y=4, h=28, on="crest"),
    Fix("plain_great", x=-128, y=6, w=16, h=58, on="crest"),
    Fix("plain_great", x=-74, y=6, w=18, h=86, on="crest"),
    Fix("great", x=-18, y=6, w=25, h=134, on="crest"),
    Fix("plain_great", x=42, y=6, w=17, h=92, on="crest"),
    Fix("crown", x=96, y=6, w=19, h=66, on="crest"),
    Fix("bulwark", span=(-200, -42), y=2, h=22),
    Fix("bulwark", span=(42, 200), y=2, h=22),
    Fix("barbican", x=0, y=2, w=46, h=26),
    Land("mist", at=0, half=248, h=11, depth=5),
))

# ---- mountains: red-coned towers on a crag, the range behind them
SKYHOLD = Plan("skyhold", 288, 250, 150, (
    Land("ridge", half=250, h=18),
    Land("patch", half=150, depth=10),
    Land("mesa", at=-10, half=140, h=68),
    Fix("bulwark", span=(-134, 138), y=4, h=30, on="crest"),
    Fix("crown", x=-92, y=6, w=19, h=76, on="crest"),
    Fix("keep", x=-10, y=4, w=76, h=48, on="crest"),
    Fix("crown", x=54, y=6, w=26, h=116, on="crest"),
    Fix("plain_great", x=112, y=6, w=16, h=62, on="crest"),
    Fix("bulwark", span=(-198, -44), y=2, h=24),
    Fix("bulwark", span=(44, 198), y=2, h=24),
    Fix("barbican", x=0, y=2, w=44, h=26),
    Land("mist", at=0, half=250, h=14, depth=8),
))

PASS_GUARD = Plan("pass guard", 288, 250, 140, (           # it closes the valley: wall to wall
    Land("ridge", half=250, h=15),
    Land("patch", half=140, depth=10),
    Fix("bulwark", span=(-250, -40), y=0, h=36),
    Fix("bulwark", span=(40, 250), y=0, h=36),
    Fix("crown", x=-196, y=0, w=20, h=88),
    Fix("crown", x=200, y=0, w=20, h=80),
    Fix("crown", x=-56, y=-30, w=24, h=124),
    Fix("keep", x=18, y=-30, w=72, h=46),
    Fix("crown", x=82, y=-30, w=19, h=96),
    Fix("barbican", x=0, y=2, w=48, h=32),
    Land("mist", at=0, half=250, h=10, depth=3),
))

TWO_CRAGS = Plan("two crags", 288, 250, 160, (             # a bridge of wall between two rocks
    Land("ridge", half=250, h=14),
    Land("patch", half=160, depth=10),
    Land("mesa", at=-112, half=96, h=84),
    Land("mesa", at=118, half=84, h=54),
    Fix("keep", x=-116, y=4, w=62, h=40, on="crest"),
    Fix("crown", x=-62, y=6, w=24, h=110, on="crest"),
    Fix("plain_great", x=118, y=-40, w=20, h=86),
    Fix("bulwark", span=(-50, 96), y=-14, h=28),
    Fix("crown", x=0, y=-16, w=20, h=88),
    Fix("barbican", x=0, y=2, w=44, h=24),
    Land("mist", at=0, half=250, h=16, depth=10),
))

CLOUD_GATE = Plan("cloud gate", 288, 250, 132, (           # a stair the whole way up to the gate
    Land("ridge", half=250, h=20),
    Land("patch", half=132, depth=10),
    Land("mesa", at=0, half=118, h=58),
    Fix("steps", x=0, y=6, w=88, h=48),
    Fix("bulwark", span=(-120, 124), y=2, h=26, on="crest"),
    Fix("crown", x=-84, y=4, w=18, h=68, on="crest"),
    Fix("keep", x=-2, y=2, w=70, h=44, on="crest"),
    Fix("crown", x=60, y=4, w=25, h=118, on="crest"),
    Fix("plain_great", x=-186, y=2, w=17, h=50),
    Fix("plain_great", x=190, y=2, w=17, h=46),
    Land("mist", at=0, half=250, h=13, depth=6),
))

# ---- dirt: majestic in ruin. Broken and enormous, with nothing left to defend.
OLD_CROWN = Plan("old crown", 288, 250, 150, (
    Land("ridge", half=250, h=18),
    Land("patch", half=150, depth=10),
    Fix("bulwark", span=(-190, -44), y=0, h=22),
    Fix("bulwark", span=(46, 190), y=0, h=22),
    Fix("keep", x=-20, y=-16, w=84, h=156),                # the ruin itself, enormous and open
    Fix("plain_great", x=66, y=-14, w=21, h=112),
    Fix("plain_great", x=-100, y=-12, w=17, h=58),
    Fix("plain_great", x=-200, y=0, w=16, h=38),
    Fix("barbican", x=0, y=2, w=42, h=22),
    Land("mist", at=0, half=250, h=10, depth=4),
))

BROKEN_RING = Plan("broken ring", 288, 250, 158, (         # the wall has fallen; the towers stand
    Land("ridge", half=250, h=14),
    Land("patch", half=158, depth=10),
    Fix("bulwark", span=(-196, -120), y=0, h=20),
    Fix("bulwark", span=(-56, 30), y=0, h=18),
    Fix("bulwark", span=(126, 200), y=0, h=20),
    Fix("plain_great", x=-204, y=0, w=18, h=78),
    Fix("plain_great", x=-108, y=0, w=21, h=126),
    Fix("keep", x=8, y=-14, w=70, h=142),
    Fix("plain_great", x=116, y=0, w=20, h=104),
    Fix("plain_great", x=208, y=0, w=17, h=54),
    Row(span=(-250, -226), pieces=(("house", 1.0),), w=(14, 20), h=(10, 14), gap=(40, 60), y=6),
    Land("mist", at=0, half=250, h=12, depth=5),
))

HOLLOW_KEEP = Plan("hollow keep", 288, 250, 130, (         # one tower, and it is the whole picture
    Land("ridge", half=250, h=22),
    Land("patch", half=130, depth=10),
    Land("mesa", at=-4, half=104, h=52),
    Fix("bulwark", span=(-96, 100), y=4, h=24, on="crest"),
    Fix("keep", x=-2, y=2, w=74, h=132, on="crest"),
    Fix("plain_great", x=-72, y=4, w=16, h=54, on="crest"),
    Fix("plain_great", x=70, y=4, w=16, h=48, on="crest"),
    Fix("bulwark", span=(-180, -40), y=2, h=18),
    Fix("bulwark", span=(40, 180), y=2, h=18),
    Fix("barbican", x=0, y=2, w=40, h=20),
    Land("mist", at=0, half=250, h=14, depth=7),
))

LONG_DYKE = Plan("long dyke", 288, 250, 170, (             # earthworks, and a ruin over them
    Land("ridge", half=250, h=12),
    Land("patch", half=170, depth=10),
    Fix("yard", span=(-200, -40), y=-16, h=6),
    Fix("yard", span=(40, 200), y=-16, h=6),
    Fix("bulwark", span=(-196, -38), y=2, h=20),
    Fix("bulwark", span=(38, 196), y=2, h=20),
    Fix("keep", x=-52, y=-12, w=74, h=148),
    Fix("plain_great", x=28, y=-12, w=22, h=106),
    Fix("plain_great", x=-132, y=-10, w=17, h=52),
    Fix("plain_great", x=206, y=2, w=16, h=40),
    Fix("barbican", x=0, y=2, w=42, h=22),
))

# ---- ice: a palace of needles, not a fort. Height is the entire point.
GLASS_CROWN = Plan("glass crown", 288, 250, 140, (
    Land("patch", half=140, depth=10),
    Fix("bulwark", span=(-176, -40), y=0, h=26),
    Fix("bulwark", span=(40, 176), y=0, h=26),
    Fix("keep", x=-8, y=-22, w=78, h=42),
    Fix("spire", x=-58, y=-24, w=15, h=112),
    Fix("spire", x=52, y=-26, w=19, h=158),                # the needle the whole palace hangs off
    Fix("spire", x=104, y=-20, w=13, h=86),
    Fix("spire", x=-112, y=-18, w=14, h=94),
    Fix("great", x=-186, y=0, w=16, h=48),
    Fix("great", x=186, y=0, w=16, h=44),
    Fix("barbican", x=0, y=2, w=44, h=24),
    Land("mist", at=0, half=250, h=12, depth=4),
))

FROZEN_COURT = Plan("frozen court", 288, 250, 150, (       # a court of spires behind a low wall
    Land("patch", half=150, depth=10),
    Fix("bulwark", span=(-190, -38), y=0, h=20),
    Fix("bulwark", span=(38, 190), y=0, h=20),
    Fix("spire", x=-140, y=-6, w=12, h=72),
    Fix("spire", x=-88, y=-10, w=15, h=118),
    Fix("spire", x=-32, y=-8, w=13, h=92),
    Fix("keep", x=6, y=-18, w=56, h=34),
    Fix("spire", x=46, y=-12, w=18, h=146),
    Fix("spire", x=104, y=-8, w=13, h=98),
    Fix("spire", x=152, y=-6, w=11, h=64),
    Fix("barbican", x=0, y=2, w=40, h=20),
))

RIME_HALL = Plan("rime hall", 288, 250, 136, (             # one hall, two needles, nothing else
    Land("patch", half=136, depth=10),
    Fix("bulwark", span=(-150, 154), y=-10, h=22),
    Fix("keep", x=0, y=-30, w=104, h=56),
    Fix("spire", x=-66, y=-32, w=17, h=138),
    Fix("spire", x=64, y=-32, w=17, h=124),
    Fix("bulwark", span=(-196, -40), y=2, h=18),
    Fix("bulwark", span=(40, 196), y=2, h=18),
    Fix("great", x=-204, y=2, w=15, h=42),
    Fix("great", x=204, y=2, w=15, h=38),
    Fix("barbican", x=0, y=2, w=42, h=22),
    Land("mist", at=0, half=250, h=10, depth=3),
))

AURORA_GATE = Plan("aurora gate", 288, 250, 148, (         # a double wall, needles rising behind
    Land("patch", half=148, depth=10),
    Fix("bulwark", span=(-180, -42), y=-14, h=18),
    Fix("bulwark", span=(42, 180), y=-14, h=18),
    Fix("spire", x=-120, y=-16, w=13, h=104),
    Fix("spire", x=-40, y=-16, w=16, h=132),
    Fix("keep", x=22, y=-16, w=52, h=36),
    Fix("spire", x=86, y=-16, w=15, h=116),
    Fix("spire", x=140, y=-14, w=11, h=72),
    Fix("bulwark", span=(-194, -38), y=4, h=18),
    Fix("bulwark", span=(38, 194), y=4, h=18),
    Fix("barbican", x=0, y=4, w=44, h=24),
))

# ---- forest: a temple, not a castle. Majesty by tiers and by the climb up to them.
GREAT_CANDI = Plan("great candi", 288, 250, 160, (
    Land("ridge", half=250, h=14),
    Land("patch", half=160, depth=10),
    Fix("bulwark", span=(-176, -44), y=0, h=20),
    Fix("bulwark", span=(44, 176), y=0, h=20),
    Fix("keep", x=-4, y=-18, w=54, h=124),                 # an eleven-tier meru over everything
    Fix("spire", x=-84, y=-14, w=34, h=76),
    Fix("spire", x=78, y=-16, w=30, h=68),
    Fix("spire", x=-146, y=-8, w=24, h=48),
    Fix("spire", x=142, y=-8, w=22, h=44),
    Fix("gate", x=0, y=2, w=46, h=36),
    Fix("steps", x=0, y=12, w=72, h=10),
    Land("mist", at=0, half=250, h=10, depth=4),
))

TERRACE_TEMPLE = Plan("terrace temple", 288, 250, 170, (   # the whole thing climbs a hillside
    Land("ridge", half=250, h=16),
    Land("patch", half=170, depth=10),
    Land("mesa", at=0, half=140, h=52),
    Fix("steps", x=0, y=8, w=92, h=44),
    Fix("bulwark", span=(-126, 130), y=4, h=20, on="crest"),
    Fix("spire", x=-88, y=6, w=28, h=62, on="crest"),
    Fix("keep", x=0, y=6, w=48, h=112, on="crest"),
    Fix("spire", x=84, y=6, w=26, h=56, on="crest"),
    Fix("gate", x=0, y=2, w=42, h=32),
    Land("mist", at=0, half=250, h=13, depth=6),
))

NINE_MERUS = Plan("nine merus", 288, 250, 180, (           # a forest of towers, none of a height
    Land("ridge", half=250, h=12),
    Land("patch", half=180, depth=10),
    Fix("bulwark", span=(-200, -40), y=0, h=18),
    Fix("bulwark", span=(40, 200), y=0, h=18),
    Fix("spire", x=-168, y=-6, w=20, h=40),
    Fix("spire", x=-118, y=-8, w=26, h=58),
    Fix("spire", x=-64, y=-12, w=32, h=84),
    Fix("keep", x=-6, y=-16, w=46, h=118),
    Fix("spire", x=58, y=-12, w=30, h=76),
    Fix("spire", x=112, y=-8, w=24, h=54),
    Fix("spire", x=164, y=-6, w=19, h=38),
    Fix("gate", x=0, y=2, w=44, h=34),
))

JUNGLE_CROWN = Plan("jungle crown", 288, 250, 164, (       # two courts, the far one higher
    Land("ridge", half=250, h=15),
    Land("patch", half=164, depth=10),
    Land("mesa", at=-84, half=104, h=46),
    Fix("bulwark", span=(-160, -30), y=4, h=18, on="crest"),
    Fix("keep", x=-90, y=4, w=44, h=104, on="crest"),
    Fix("spire", x=-32, y=6, w=26, h=54, on="crest"),
    Fix("spire", x=64, y=-14, w=32, h=86),
    Fix("spire", x=132, y=-10, w=24, h=56),
    Fix("bulwark", span=(20, 196), y=2, h=20),
    Fix("gate", x=-4, y=2, w=42, h=32),
    Land("mist", at=0, half=250, h=14, depth=7),
))


## Four entries a variant. Where they repeat, that pair is still one idea under four seeds and is
## what Phase B replaces, one reference at a time.
LAYOUTS = {
    "timber": {
        "village": (GREEN, LANE, CROFTS, CHAPEL),
        "town": (BURGH, MARKET, TERRACE, WHARF),
        "fortress": (CITADEL, CROWN_KEEP, WATERGATE, SEVEN_TOWERS),
    },
    "alpine": {
        "village": (CRAGTOP, SHELF, SADDLE, STEADING),
        "town": (GALLERIES, SWITCHBACK, HIGH_STREET, CLIFF_ROW),
        "fortress": (SKYHOLD, PASS_GUARD, TWO_CRAGS, CLOUD_GATE),
    },
    "celtic": {
        "village": (ROUNDS, HEARTH, DROVE, BARROW),
        "town": (WYND, CLOSE, TOLL, MARCH),
        "fortress": (OLD_CROWN, BROKEN_RING, HOLLOW_KEEP, LONG_DYKE),
    },
    "snow": {
        "village": (FLOE, SNOWFIELD, CAMP, LODGE),
        "town": (HEARTHS, DRIFT_TOWN, HARBOUR, WINTER_HOLD),
        "fortress": (GLASS_CROWN, FROZEN_COURT, RIME_HALL, AURORA_GATE),
    },
    # Forest builds its own way now; its catalogue is in lay_forest.py.
    "forest": _forest.LAYOUTS,
    "cone": {
        "village": (WAE, CLEARING, KAMPUNG, SHRINE),
        "town": (STILTS, LONGHOUSES, WATER_TOWN, TERRACES),
        "fortress": (GREAT_CANDI, TERRACE_TEMPLE, NINE_MERUS, JUNGLE_CROWN),
    },
    # The old shared kit, kept so the hand-written transcription still has a home to be compared
    # against. Nothing points at it now that all six places build their own way.
    "north": {
        "village": (HAMLET,) * 4,
        "town": (WALLED,) * 4,
        "fortress": (KEEP_ON_A_RISE,) * 4,
    },
    "desert": {
        "village": (DOMES,) * 4,
        "town": (KSAR,) * 4,
        "fortress": (KASBAH,) * 4,
    },
}
