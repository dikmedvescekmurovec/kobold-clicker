"""Where the mountains put what they build: twelve plans, four to a variant.

One culture at three scales. The village is a handful of flat-roofed ashlar blocks on a shelf of
rock; the town is a dozen of them stacked up a crag with dark timber hung off the front; the
fortress is the same stone drawn round instead of square, under red cones, reached along an
arcaded viaduct.

Everything here climbs. It is the only environment in the set where the ground under the settlement
does as much work as the settlement -- half of these plans stand on a `mesa`, and the ones that do
not are on a ridge. A mountain town on the flat is a town somewhere else.
"""
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- village: the rock shelf
# A few blocks, one gallery, one small red cap. The village's job is to be recognisably the same
# people as the fortress at a tenth of the size, which the red cone does on its own.

SHELF = Plan("shelf", 288, 250, 175, (                # blocks along a shelf, timber on the front
    Land("ridge", half=240, h=16),
    Land("patch", half=175, depth=8),
    Row(span=(-140, -24), pieces=(("house", 1.0),), w=(26, 38), h=(24, 38), gap=(-2, 6), y=0,
        jitter=3),
    Row(span=(30, 148), pieces=(("house", 1.0),), w=(26, 38), h=(24, 38), gap=(-2, 6), y=0,
        jitter=3),
    Fix("tower", x=-6, y=-2, w=17, h=44),             # one red cap, so the place has a flag to it
    Fix("gallery", span=(-132, -70), y=-14),
    Fix("stair", span=(14, 34), y=1, h=14),
    Belt(span=(-250, 250), y=5, count=6, scrub=0.9),
))

CRAGTOP = Plan("cragtop", 282, 252, 190, (            # the village up the rock, drawn highest first
    Land("patch", half=190, depth=9),
    Land("mesa", at=-12, half=150, h=64),
    Course(span=(-104, 134), piece="house", w=(24, 36), h=(22, 34), drop=(5, 10), step=(26, 36)),
    Fix("tower", x=-44, y=-2, w=18, h=50, on="land"),
    Fix("gallery", span=(-96, -40), x=-68, y=6, on="land"),
    Fix("stair", span=(-142, -108), y=2, h=22),
    Belt(span=(-250, 250), y=6, count=7, scrub=1.0),
))

SADDLE = Plan("saddle", 292, 250, 185, (              # two shoulders with the path between them
    Land("ridge", half=240, h=22),
    Land("patch", half=185, depth=8),
    Row(span=(-160, -52), pieces=(("house", 1.0),), w=(26, 38), h=(26, 42), gap=(-2, 8), y=-8),
    Row(span=(60, 166), pieces=(("house", 1.0),), w=(26, 38), h=(26, 42), gap=(-2, 8), y=-8),
    Fix("stair", span=(-40, 6), y=2, h=20),
    Fix("tower", x=44, y=-6, w=16, h=40),
    Fix("gallery", span=(70, 132), y=-20),
    Belt(span=(-250, 250), y=5, count=6, scrub=0.9),
))

STEADING = Plan("steading", 270, 252, 180, (          # fewer, lower, and the pines closing in
    Land("patch", half=180, depth=9),
    Row(span=(-134, 126), pieces=(("house", 0.74), ("tree", 0.26)), w=(30, 44), h=(22, 34),
        gap=(10, 28), y=0, jitter=4),
    Fix("yard", span=(-176, -140), y=2, h=6),
    Fix("yard", span=(132, 176), y=2, h=6),
    Fix("tower", x=-70, y=-2, w=15, h=34),
    Belt(span=(-250, 260), y=6, count=9, scrub=1.3),
))

# ---------------------------------------------------------------- town: the stacked crag
# The reference is a dozen cubes at a dozen heights with timber bolted to the front. The blocks
# are deliberately plain; the galleries and the stairs are what give the face any depth.

GALLERIES = Plan("galleries", 284, 252, 205, (        # the reference, as nearly as it can be said
    Land("patch", half=205, depth=8),
    Land("mesa", at=14, half=164, h=72),
    Course(span=(-88, 152), piece="street", w=(28, 42), h=(26, 44), drop=(5, 12), step=(26, 36)),
    Fix("tower", x=94, y=-6, w=22, h=64, on="land"),
    Fix("gallery", span=(-70, 6), x=-32, y=10, on="land"),
    Fix("gallery", span=(30, 104), y=-16),
    Fix("stair", span=(-136, -92), y=2, h=26),
    Fix("street", x=-160, y=0, w=34, h=32),
    Belt(span=(-250, 255), y=6, count=5, scrub=0.8),
))

SWITCHBACK = Plan("switchback", 280, 252, 200, (      # the climb, drawn as the climb
    Land("patch", half=200, depth=9),
    Land("mesa", at=8, half=150, h=88),
    Course(span=(-70, 142), piece="street", w=(26, 38), h=(24, 38), drop=(6, 13), step=(28, 40)),
    Fix("tower", x=56, y=-4, w=20, h=58, on="land"),
    Fix("stair", span=(-126, -84), y=2, h=24),
    Fix("stair", span=(-80, -38), y=-22, h=24),
    Fix("stair", span=(-34, 8), y=-46, h=22),
    Fix("gallery", span=(14, 78), y=-64),
    Belt(span=(-250, 255), y=6, count=6, scrub=0.9),
))

HIGH_STREET = Plan("high_street", 290, 252, 210, (    # long and low, with an arcade under it
    Land("ridge", half=245, h=14),
    Land("patch", half=210, depth=8),
    Fix("wall", span=(-190, 192), y=2, h=16),
    Row(span=(-172, 176), pieces=(("street", 1.0),), w=(26, 40), h=(24, 42), gap=(-2, 6), y=-16,
        jitter=4),
    Fix("spire", x=-62, y=-16, w=22, h=70),
    Fix("gallery", span=(4, 82), y=-32),
    Fix("gallery", span=(-160, -92), y=-30),
    Belt(span=(-250, 255), y=5, count=4, scrub=0.7),
))

SPUR = Plan("spur", 286, 252, 200, (                  # the bridge to the arch in the rock
    Land("patch", half=200, depth=9),
    Land("mesa", at=44, half=140, h=66),
    Course(span=(-10, 150), piece="street", w=(28, 40), h=(26, 40), drop=(5, 11), step=(30, 40)),
    Fix("tower", x=112, y=-4, w=19, h=54, on="land"),
    Fix("gate", x=-40, y=2, w=40, h=30),
    Fix("bridge", span=(-236, -58), y=-6, h=14),
    Fix("street", x=-186, y=0, w=30, h=30),
    Belt(span=(-250, 255), y=6, count=5, scrub=0.9),
))

# ---------------------------------------------------------------- fortress: the red crowns
# One dominant mass, the base hidden, and the tallest thing carrying this culture's crown -- which
# here is a red cone with a pennant over it, the only saturated colour in the six environments.
# The base is hidden by a viaduct rather than by haze wherever a viaduct will fit: a way in that
# crosses something you cannot see the bottom of does the job and says something as well.

SKYHOLD = Plan("skyhold", 286, 250, 215, (            # the crag, the drums, the road in
    Land("ridge", half=250, h=20),
    Land("patch", half=215, depth=9),
    Land("mesa", at=18, half=156, h=70),
    Fix("bulwark", span=(-96, 160), y=3, h=17),
    Fix("great", x=-64, y=-4, w=20, h=86, on="land"),
    Fix("keep", x=8, y=-6, w=34, h=132, on="land"),  # the one that dominates
    Fix("tower", x=70, y=-2, w=18, h=74, on="land"),
    Fix("tower", x=126, y=-2, w=15, h=54, on="land"),
    Fix("bulwark", span=(-186, -66), y=2, h=22),
    Fix("tower", x=-176, y=0, w=19, h=62),
    Fix("gate", x=-116, y=2, w=38, h=26),
    Fix("bridge", span=(-262, -126), y=-4, h=18),
    Land("mist", at=20, half=250, h=14, depth=4),
))

PASS_GUARD = Plan("pass_guard", 288, 250, 215, (      # a wall across a gap, and what holds it
    Land("ridge", half=250, h=26),
    Land("patch", half=215, depth=9),
    Fix("bulwark", span=(-206, 208), y=2, h=26),
    Fix("keep", x=-30, y=-2, w=36, h=146),            # the mass, and off centre
    Fix("great", x=44, y=-2, w=24, h=96),
    Fix("tower", x=-114, y=-2, w=20, h=72),
    Fix("tower", x=112, y=-2, w=18, h=64),
    Fix("tower", x=-190, y=0, w=16, h=50),
    Fix("tower", x=194, y=0, w=16, h=46),
    Fix("gate", x=-30, y=2, w=44, h=30),
    Row(span=(-250, -214), pieces=(("house", 1.0),), w=(22, 30), h=(18, 26), gap=(8, 18), y=5),
    Land("mist", at=0, half=250, h=12, depth=5),
))

TWO_CRAGS = Plan("two_crags", 284, 250, 215, (        # two rocks, and the road strung between
    Land("ridge", half=250, h=24),
    Land("patch", half=215, depth=10),
    Land("mesa", at=-104, half=104, h=84),
    Fix("bulwark", span=(-176, -40), y=4, h=15),
    Fix("keep", x=-118, y=-6, w=32, h=138, on="land"),
    Fix("tower", x=-58, y=-2, w=18, h=66, on="land"),
    Fix("bulwark", span=(84, 208), y=2, h=20),
    Fix("great", x=110, y=-2, w=23, h=92),
    Fix("tower", x=182, y=0, w=17, h=58),
    Fix("gate", x=140, y=2, w=36, h=24),
    Fix("bridge", span=(-36, 96), y=-28, h=10),       # the span itself, between the two
    Land("mist", at=0, half=250, h=18, depth=3),
))

CLOUD_GATE = Plan("cloud_gate", 290, 250, 215, (      # high, and mostly in the weather
    Land("ridge", half=250, h=18),
    Land("patch", half=215, depth=10),
    Land("mesa", at=-6, half=172, h=52),
    Fix("bulwark", span=(-168, 174), y=3, h=20),
    Fix("tower", x=-136, y=-2, w=16, h=58, on="land"),
    Fix("great", x=-78, y=-4, w=22, h=94, on="land"),
    Fix("keep", x=-6, y=-8, w=36, h=152, on="land"),
    Fix("great", x=66, y=-4, w=21, h=86, on="land"),
    Fix("tower", x=132, y=-2, w=15, h=56, on="land"),
    Fix("gate", x=-6, y=2, w=42, h=28),
    Fix("stair", span=(-30, 18), y=2, h=18),
    Fix("bulwark", span=(-236, -184), y=2, h=14),
    Land("mist", at=0, half=250, h=22, depth=2),
))


LAYOUTS = {
    "village": (SHELF, CRAGTOP, SADDLE, STEADING),
    "town": (GALLERIES, SWITCHBACK, HIGH_STREET, SPUR),
    "fortress": (SKYHOLD, PASS_GUARD, TWO_CRAGS, CLOUD_GATE),
}
