"""Where the dirt puts what it builds: twelve plans, four to a variant.

One culture at three scales, and the oldest-looking of the six. The village is roundhouses round a
fire; the town is a canyon of undressed stone with timber bolted to its face; the fortress is a
square keep that has already lost pieces of itself. Nothing in any of them has been dressed,
painted or carved.

What holds them together is two marks and one proportion: the crown of crossed poles over a thatch
apex, the group of tall narrow lancets in a blank wall, and the habit of being broader than it is
tall. The last is what keeps this place away from the grass, which builds the same two materials
into something steep.
"""
from areaplan import Belt, Course, Fix, Land, Plan, Row

# ---------------------------------------------------------------- village: the roundhouses
# Fat thatch cones round an open middle with a fire in it. The fire is not decoration -- it is the
# only warm thing the environment has, and a village plan without one reads as abandoned.

ROUNDS = Plan("rounds", 288, 252, 165, (              # the ring, and the fire it faces
    Land("patch", half=165, depth=8),
    Row(span=(-148, -30), pieces=(("house", 1.0),), w=(36, 50), h=(32, 44), gap=(-4, 6), y=-2,
        jitter=3),
    Row(span=(32, 152), pieces=(("house", 1.0),), w=(36, 50), h=(32, 44), gap=(-4, 6), y=-2,
        jitter=3),
    Fix("hall", x=-2, y=-14, w=64, h=38),             # the long house, set back across the green
    Fix("fire", x=-2, y=8, w=6, h=30),             # out in front of the hall, not behind it
    Fix("yard", span=(-176, -142), y=2, h=7),
    Fix("yard", span=(148, 182), y=2, h=7),
    Belt(span=(-250, 250), y=6, count=5, scrub=0.9),
))

DROVE = Plan("drove", 294, 252, 180, (                # strung along a track, with stock pens
    Land("ridge", half=240, h=12),
    Land("patch", half=180, depth=8),
    Row(span=(-172, 158), pieces=(("house", 0.76), ("tree", 0.24)), w=(32, 46), h=(28, 40),
        gap=(0, 14), y=0, jitter=4),
    Fix("yard", span=(-120, -58), y=3, h=8),
    Fix("yard", span=(28, 104), y=3, h=8),
    Fix("fire", x=-14, y=4, w=6, h=20),
    Belt(span=(-250, 250), y=6, count=7, scrub=1.1),
))

HILLFORT = Plan("hillfort", 284, 252, 195, (          # the village up a bluff behind a rampart
    Land("patch", half=195, depth=9),
    Land("mesa", at=-8, half=152, h=60),
    Fix("wall", span=(-126, 138), y=6, h=10),
    Course(span=(-110, 138), piece="house", w=(32, 46), h=(30, 42), drop=(4, 9), step=(32, 44)),
    Fix("hall", x=-40, y=-4, w=46, h=28, on="land"),
    Fix("fire", x=22, y=2, w=6, h=18, on="land"),
    Fix("gate", x=-30, y=2, w=34, h=14),
    Belt(span=(-250, 250), y=6, count=6, scrub=1.0),
))

HEARTH_CAMP = Plan("hearth_camp", 268, 252, 170, (    # fewer and bigger, and a great fire
    Land("patch", half=170, depth=9),
    Row(span=(-140, 132), pieces=(("house", 1.0),), w=(44, 62), h=(38, 54), gap=(2, 18), y=0,
        jitter=4),
    Fix("fire", x=-4, y=9, w=8, h=38),
    Fix("yard", span=(-172, -132), y=3, h=8),
    Fix("yard", span=(126, 178), y=3, h=8),
    Fix("yard", span=(-52, 44), y=5, h=5),
    Belt(span=(-250, 260), y=7, count=8, scrub=1.3),
))

# ---------------------------------------------------------------- town: the stone street
# Packed so tight the fronts read as one wall with holes in it. The depth comes from what is
# bolted on -- balconies, outside stairs -- and not from the buildings standing apart.

WYND = Plan("wynd", 288, 252, 210, (                  # the street, and the gate at the end of it
    Land("ridge", half=245, h=10),
    Land("patch", half=210, depth=8),
    Row(span=(-186, -40), pieces=(("street", 1.0),), w=(26, 38), h=(28, 46), gap=(-2, 4), y=0,
        jitter=2),
    Row(span=(44, 190), pieces=(("street", 1.0),), w=(26, 38), h=(28, 46), gap=(-2, 4), y=0,
        jitter=2),
    Fix("gate", x=0, y=1, w=42, h=30),
    Fix("stair", span=(-42, -22), y=2, h=15),
    Fix("stair", span=(26, 46), y=2, h=14),
    Belt(span=(-250, 255), y=5, count=4, scrub=0.7),
))

CLOSE = Plan("close", 282, 252, 200, (                # the town stacked up its own bluff
    Land("patch", half=200, depth=8),
    Land("mesa", at=10, half=158, h=64),
    Course(span=(-96, 146), piece="street", w=(26, 38), h=(26, 40), drop=(5, 11), step=(26, 36)),
    Fix("keep", x=48, y=-4, w=30, h=54, on="land"),
    Fix("street", x=-136, y=0, w=32, h=34),
    Fix("stair", span=(-118, -92), y=2, h=18),
    Belt(span=(-250, 255), y=6, count=5, scrub=0.9),
))

MARCH = Plan("march", 290, 252, 210, (                # a walled town, the wall doing the talking
    Land("ridge", half=245, h=14),
    Land("patch", half=210, depth=9),
    Row(span=(-150, 150), pieces=(("street", 1.0),), w=(24, 36), h=(30, 48), gap=(0, 8), y=-14,
        jitter=3),
    Fix("wall", span=(-196, -34), y=2, h=20),
    Fix("wall", span=(34, 198), y=2, h=20),
    Fix("gate", x=0, y=2, w=44, h=26),
    Fix("tower", x=-196, y=0, w=22, h=46),
    Fix("tower", x=200, y=0, w=20, h=40),
    Belt(span=(-250, 255), y=5, count=4, scrub=0.6),
))

TOLL = Plan("toll", 292, 252, 205, (                  # the crossing, and what grew up round it
    Land("ridge", half=245, h=12),
    Land("patch", half=205, depth=8),
    Fix("tower", x=-92, y=-2, w=26, h=62),            # a broken one, kept because it is useful
    Row(span=(-176, -112), pieces=(("street", 1.0),), w=(24, 34), h=(26, 38), gap=(0, 6), y=1),
    Row(span=(-58, 60), pieces=(("street", 1.0),), w=(26, 38), h=(30, 44), gap=(-2, 4), y=0),
    Row(span=(104, 188), pieces=(("street", 1.0),), w=(24, 34), h=(24, 36), gap=(0, 6), y=2),
    Fix("gate", x=84, y=1, w=38, h=28),
    Fix("stair", span=(-84, -62), y=2, h=16),
    Fix("hall", x=150, y=-2, w=38, h=24),
    Belt(span=(-250, 255), y=5, count=5, scrub=0.8),
))

# ---------------------------------------------------------------- fortress: the square keep
# One dominant mass, the base hidden, and the tallest thing carrying this culture's crown -- which
# is nothing at all. Every other fortress in the set ends in a point, a needle, a gold finial or a
# rank of teeth. This one is a box with the top taken off, and that is exactly what makes it read
# as older and grimmer than any of them without a single stone having to be drawn fallen.

OLD_CROWN = Plan("old_crown", 288, 250, 215, (        # the keep on its bluff, seen from below
    Land("ridge", half=250, h=18),
    Land("patch", half=215, depth=9),
    Land("mesa", at=-4, half=150, h=58),
    Fix("wall", span=(-142, 148), y=4, h=16),
    Fix("keep", x=-16, y=-4, w=74, h=124, on="land"), # the one that dominates
    Fix("tower", x=76, y=-2, w=30, h=72, on="land"),
    Fix("tower", x=-108, y=0, w=24, h=52, on="land"),
    Fix("wall", span=(-214, -110), y=2, h=14),
    Fix("wall", span=(112, 214), y=2, h=14),
    Fix("gate", x=-52, y=2, w=40, h=22),
    Land("mist", at=0, half=250, h=13, depth=5),
))

TWO_KEEPS = Plan("two_keeps", 286, 252, 215, (        # two boxes, neither of them the same box
    Land("ridge", half=250, h=20),
    Land("patch", half=215, depth=9),
    Fix("wall", span=(-160, 164), y=2, h=24),
    Fix("keep", x=-76, y=-2, w=66, h=136),
    Fix("keep", x=62, y=-2, w=52, h=92),
    Fix("tower", x=-8, y=-2, w=26, h=58),
    Fix("gate", x=-8, y=2, w=42, h=26),
    Fix("tower", x=-172, y=0, w=24, h=48),
    Fix("tower", x=178, y=0, w=22, h=44),
    Row(span=(-250, -196), pieces=(("house", 1.0),), w=(24, 32), h=(20, 28), gap=(10, 22), y=5),
    Land("mist", at=0, half=250, h=11, depth=5),
))

LONG_DYKE = Plan("long_dyke", 292, 252, 215, (        # a rampart, not a castle: wide and low
    Land("ridge", half=250, h=16),
    Land("patch", half=215, depth=10),
    Land("mesa", at=14, half=178, h=38),
    Fix("wall", span=(-176, 182), y=3, h=22),
    Fix("keep", x=104, y=-2, w=58, h=106, on="land"), # the mass, pushed right out to one side
    Fix("tower", x=30, y=-2, w=26, h=58, on="land"),
    Fix("tower", x=-48, y=-2, w=24, h=50, on="land"),
    Fix("tower", x=-128, y=0, w=22, h=44, on="land"),
    Fix("gate", x=-92, y=2, w=40, h=24),
    Fix("wall", span=(-232, -148), y=2, h=13),
    Land("mist", at=20, half=250, h=15, depth=4),
))

BROKEN_HOLD = Plan("broken_hold", 282, 252, 215, (    # more of it down than up
    Land("ridge", half=250, h=22),
    Land("patch", half=215, depth=10),
    Land("mesa", at=-16, half=160, h=70),
    Fix("wall", span=(-136, 60), y=5, h=13),
    Fix("keep", x=-52, y=-4, w=62, h=118, on="land"),
    Fix("tower", x=28, y=-2, w=30, h=76, on="land"),
    Fix("tower", x=-120, y=0, w=26, h=44, on="land"),
    Fix("wall", span=(104, 196), y=2, h=11),          # what is left of the outer line
    Fix("tower", x=142, y=-2, w=28, h=54),
    Fix("gate", x=-96, y=2, w=36, h=20),
    Row(span=(196, 250), pieces=(("house", 1.0),), w=(24, 32), h=(20, 28), gap=(8, 18), y=5),
    Land("mist", at=-10, half=250, h=17, depth=3),
))


LAYOUTS = {
    "village": (ROUNDS, DROVE, HILLFORT, HEARTH_CAMP),
    "town": (WYND, CLOSE, MARCH, TOLL),
    "fortress": (OLD_CROWN, TWO_KEEPS, LONG_DYKE, BROKEN_HOLD),
}
