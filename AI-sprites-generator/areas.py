"""The battle backdrops: one 576x324 scene per environment, in five variants.

`python areas.py <env> <variant> <tag>` writes a preview to qa/area_<env>_<variant>_<tag>.png and
`python areas.py all <tag>` writes all thirty. build_areas.py exports them at 4x into ../Assets/Area/.

Every scene is the same skeleton, the one measured off the hand-drawn reference
(Assets/Area/Summer2.png): a cloud ceiling, a sky that darkens upward, cumulus sitting on a hazy
horizon at y=200, four land bands, and a dense foreground the fight happens in front of. What
changes per environment is the palette (areapal.py), what stands on the skyline, and what the
ground is covered in. The variants -- road, village, town, fortress -- are placed on the mid band,
behind the cover, so the player and the enemy always have clear ground to stand on.
"""
import os
import random
import sys

import areabuild as B
import arealib as A
import areaplan as P
from arealayouts import LAYOUTS
from areapal import PAL, PEAKS
from arealib import GROUND_TOP, H, HORIZON, W

HERE = os.path.dirname(os.path.abspath(__file__))
QA = os.path.join(HERE, "qa")

ENVS = ("grass", "dirt", "desert", "ice", "forest", "mountains")
VARIANTS = ("plain", "road", "village", "town", "fortress")

## How many ways each place was drawn. A village is four villages: the same environment and the
## same tier, built four ways, so two towns on one map are not the same picture twice.
LAYOUTS_PER_VARIANT = 4
## What one layout moves the shared seed by. It is the *shared* seed, so layout 2 of `plain` and
## layout 2 of `village` get one sky and one cover between them and differ only in the settlement --
## which is what keeps qa's "variant drew nothing" check honest. It also means `plain` and `road`,
## which build nothing, still come in four.
LAYOUT_STEP = 1009


# ---------------------------------------------------------------- skylines

def _mix(a, b, t):
    return tuple(int(x + (y - x) * t) for x, y in zip(a, b))


def peaks(im, seed, pal, env, base, height, haze=0.0, spacing=(42, 110)):
    """Distant mountains, hazed back toward the sky the further off the range is."""
    p = PEAKS[env]
    rock = _mix(p["rock"], p["haze"], haze)
    lit = _mix(p["lit"], p["haze"], haze)
    shade = _mix(p["rock"], (0, 0, 0), 0.12)
    return A.mountain_range(im, seed, base, height, rock, lit,
                            snow=_mix(p["snow"], p["haze"], haze) if p["snow"] else None,
                            shade=_mix(shade, p["haze"], haze), spacing=spacing)


def canopy(im, seed, pal, reach=(16, 62)):
    """Leaves hanging in from the top of the frame, the near tree the trunks belong to.

    Built from overlapping lumps rather than a noise edge: a smooth edge reads as a green bar,
    and what says foliage is a scalloped underside with single leaves hanging past it.
    """
    rng = random.Random(seed)
    px = im.load()
    mask = set()
    x = -20
    while x < W + 20:
        bias = 1.0 - min(1.0, abs(x - W / 2) / (W / 2))         # thinnest over the middle
        r = int(rng.randint(*reach) * (0.45 + 0.8 * (1 - bias)))
        cy = rng.randint(-r // 2, 2)
        for dy in range(-r, r + 1):
            for dx in range(-r, r + 1):
                if dx * dx + dy * dy * 1.5 <= r * r and cy + dy >= 0:
                    mask.add((x + dx, cy + dy))
        x += rng.randint(r // 2, max(2, r))
    A.mask_paint(im, mask, pal["crown"])
    lip = {(x, y) for (x, y) in mask if (x, y + 1) not in mask}
    A.mask_paint(im, {(x, y - d) for (x, y) in lip for d in range(3)}, pal["crown_dk"])
    for (x, y) in lip:                                         # leaves hanging past the edge
        if rng.random() < 0.25 and 0 <= x < W:
            A.leaf(px, x, y + rng.randint(2, 7), rng.randint(3, 7), pal["crown_dk"], 2)
    for _ in range(120):                                       # lit leaves catching the sky
        x = rng.randrange(W)
        y = rng.randint(0, 14)
        A.leaf(px, x, y + rng.randint(0, 6), rng.randint(3, 7), pal["crown_lit"], 2)


def treeline(im, seed, pal, base, height, colour, dark, snow=None):
    """A wall of conifers along the horizon, drawn as one mass rather than as separate trees."""
    rng = random.Random(seed)
    px = im.load()
    x = -6
    while x < W + 6:
        h = int(height * rng.uniform(0.6, 1.45))
        w = max(2, h // 3)
        for i in range(h):
            half = int(w * i / h) + 1
            y = base - h + i
            for xx in range(x - half, x + half + 1):
                if 0 <= xx < W and 0 <= y < H:
                    px[xx, y] = colour if xx < x else dark
        if snow:                                              # a cap of settled snow
            for i in range(rng.randint(1, 3)):
                for xx in range(x - i, x + i + 1):
                    if 0 <= xx < W and 0 <= base - h + i < H:
                        px[xx, base - h + i] = snow
        x += rng.randint(3, 7)


def skyline(im, pal, env, seed):
    if env == "mountains":
        peaks(im, seed + 1, pal, env, HORIZON, 108, haze=0.72, spacing=(70, 150))
        peaks(im, seed + 2, pal, env, HORIZON, 78, haze=0.30, spacing=(50, 110))
        peaks(im, seed + 5, pal, env, HORIZON + 2, 44, haze=0.0, spacing=(36, 80))
    elif env == "ice":
        peaks(im, seed + 1, pal, env, HORIZON, 62, haze=0.6, spacing=(60, 130))
        peaks(im, seed + 2, pal, env, HORIZON, 40, haze=0.05, spacing=(40, 90))
        treeline(im, seed + 3, pal, HORIZON + 2, 15, pal["crown"], pal["crown_dk"],
                 snow=PEAKS[env]["snow"])
    elif env == "forest":
        peaks(im, seed + 1, pal, env, HORIZON, 30, haze=0.8, spacing=(90, 180))
        treeline(im, seed + 3, pal, HORIZON, 22, _mix(pal["crown_dk"], PEAKS[env]["haze"], 0.45),
                 _mix(pal["crown_dk"], PEAKS[env]["haze"], 0.55))
        treeline(im, seed + 6, pal, HORIZON + 4, 17, pal["crown"], pal["crown_dk"])
    elif env == "desert":
        peaks(im, seed + 1, pal, env, HORIZON, 34, haze=0.7, spacing=(80, 160))
        A.ridge(im, seed + 4, HORIZON + 1, 14, pal["hill"], pal["hill_lit"],
                layers=((2, 1.0), (5, 0.5)))
    elif env == "dirt":
        A.ridge(im, seed + 4, HORIZON + 1, 16, pal["hill"], pal["hill_lit"],
                layers=((2, 1.0), (6, 0.4)))
    else:
        A.ridge(im, seed + 4, HORIZON + 1, 10, pal["hill"], pal["hill_lit"],
                layers=((2, 1.0), (5, 0.35)))


# ---------------------------------------------------------------- ground cover

## How many near trunks the shot is framed by. Two of them stand the camera in a clearing; one
## leans the shot without closing it, which is what the grass village reference does -- a single
## tree at the left with its leaves hanging in over the meadow. A table rather than a test against
## one environment's name, because more than one place has a tree in front of it.
FRAMING = {"forest": 2}


def framing(im, pal, seed, trunks=2):
    """The tree the shot is taken from: a trunk at each edge and its leaves hanging in.

    Drawn after everything else, the road included -- it is the nearest thing in the picture.
    """
    rng = random.Random(seed)
    px = im.load()
    B.edge_trunk(px, 12, 306, 32, pal, rng)
    if trunks > 1:
        B.edge_trunk(px, W - 20, 298, 26, pal, rng)
    canopy(im, seed + 2, pal)


def cover(im, pal, env, seed):
    """What the land in front of the horizon is covered in -- the floor the fight stands on."""
    if env in ("grass", "forest"):
        A.clump_layer(im, seed + 15, 244, 268, pal["clumps"][:2], density=1.6, size=(2, 5),
                      leaves=(3, 6), width=(5, 11), body=(2, 4))
        A.clump_layer(im, seed + 21, 262, H + 2, pal["clumps"], density=4.0, size=(4, 8),
                      leaves=(7, 13), width=(10, 20), body=(4, 7))
        A.flowers(im, seed + 31, 280, H - 3, 70 if env == "grass" else 40, pal["blossoms"])
    elif env == "dirt":
        A.patches(im, seed + 9, 216, H, pal["clumps"][:2], count=18, rx=(16, 64), ry=(3, 9),
                  fill=0.4)
        A.furrows(im, seed + 11, 212, H, pal["clumps"][:4])
        A.boulders(im, seed + 17, 246, H + 6, pal["clumps"], count=22, size=(2, 12))
        A.clump_layer(im, seed + 23, 266, H, pal["clumps"][:2], density=0.28, size=(3, 7),
                      leaves=(3, 7), width=(4, 11), body=(1, 3))
        A.flowers(im, seed + 31, 284, H - 3, 16, pal["blossoms"])
    elif env == "desert":
        A.patches(im, seed + 9, 210, H, pal["clumps"][:3], count=20, rx=(24, 90), ry=(4, 12),
                  fill=0.45)
        A.ripple_layer(im, seed + 11, 214, H, pal["clumps"][:3], density=0.45, length=(16, 40))
        A.boulders(im, seed + 17, 250, H + 4, pal["clumps"], count=12, size=(2, 10))
        A.clump_layer(im, seed + 23, 268, H, pal["clumps"][3:], density=0.3, size=(4, 9),
                      leaves=(4, 9), width=(4, 10), body=(1, 3))
    elif env == "ice":
        A.pebble_layer(im, seed + 17, 240, H + 6, pal["clumps"], density=1.6, size=(6, 16),
                       flat=3.2)
        A.scatter(im, seed + 27, 250, H - 2, 260, pal["specks"])
        A.flowers(im, seed + 31, 286, H - 4, 18, pal["blossoms"])
    else:                                                     # mountains: scree and stray tufts
        A.patches(im, seed + 9, 210, H, pal["clumps"][:2], count=20, rx=(20, 70), ry=(3, 10),
                  fill=0.55)
        A.ripple_layer(im, seed + 11, 226, 272, pal["clumps"][:3], density=0.22, length=(6, 20))
        A.boulders(im, seed + 17, 236, H + 8, pal["clumps"], count=20, size=(2, 19))
        A.clump_layer(im, seed + 23, 276, H, pal["clumps"][:3], density=0.22, size=(3, 6),
                      leaves=(3, 6), width=(4, 9), body=(1, 3))


# ---------------------------------------------------------------- settlements
# A settlement is a plan laid by areaplan.run: arealayouts says which plan, and the kit in areaplan
# says what it is built out of, so the same plan is timber and gables in the north and rammed earth
# in the desert. Each one sits on the mid band, behind the cover, so the fight has clear ground in
# front of it.


def settlement(im, pal, env, variant, seed, layout):
    """Lay the variant's `layout`-th plan, in whatever this place builds with."""
    plans = LAYOUTS[P.STYLE[env]].get(variant)
    if not plans:
        return
    P.run(im, pal, env, plans[(layout - 1) % len(plans)], seed)



# ---------------------------------------------------------------- scene

# Weather per environment: how low the cloud ceiling hangs, how many banks, how many cumulus.
# A desert sky is nearly bare and a forest one is busy; the same three clouds everywhere is the
# quickest way to make six places look like one place.
WEATHER = {"grass": ((92, 70), 3, 6), "dirt": ((104, 84), 4, 7), "desert": ((44, 44), 1, 3),
           "ice": ((112, 90), 4, 5), "forest": ((96, 76), 3, 8), "mountains": ((84, 66), 3, 4)}


def sky(im, d, pal, env, seed):
    ceiling, banks, puffs = WEATHER[env]
    A.bands(d, pal["sky"])
    A.overcast(im, seed + 3, pal["cloud_hi"], *ceiling)
    A.cloud_bank(im, seed, pal, 2, ceiling[0] - 24, n=banks)
    A.cumulus_row(im, seed + 5, pal, HORIZON - 2, count=puffs)
    d.line([0, HORIZON, W - 1, HORIZON], fill=pal["horizon"])
    d.line([0, HORIZON + 1, W - 1, HORIZON + 1], fill=pal["horizon"])


# How much of the far field is speckled: a meadow is full of flower heads, a rock plain is not.
SPECKS = {"grass": 1100, "forest": 700, "dirt": 500, "desert": 420, "ice": 180, "mountains": 220}


def ground(im, d, pal, env, seed):
    A.bands(d, pal["ground"] + [(H, None)])
    A.scatter(im, seed + 11, GROUND_TOP + 20, 262, SPECKS[env], pal["specks"])


def scene(env, variant, seed=0, layout=1):
    pal = PAL[env]
    im, d = A.canvas()
    seed += LAYOUT_STEP * (layout - 1)
    sky(im, d, pal, env, seed + 1 + 37 * ENVS.index(env))
    skyline(im, pal, env, seed + 4 + 11 * ENVS.index(env))
    ground(im, d, pal, env, seed + 2)
    # A settlement goes behind the cover so the fight has clear ground in front of it. The desert
    # is the exception: its cover is dune ripples and dust patches drawn right across the mid
    # band, which scribble over a mud wall instead of standing in front of it. Its buildings are
    # laid in after, and the palm belt each of them ends with is what stands in front of them.
    late = env in P.LATE
    if not late:
        settlement(im, pal, env, variant, seed + 7, layout)
    cover(im, pal, env, seed + 2)
    if late:
        settlement(im, pal, env, variant, seed + 7, layout)
    if variant == "road":
        verge = B.road(im, seed + 9, pal, GROUND_TOP)
        A.verge_tufts(im, seed + 13, verge, pal["clumps"][2:])
    if env in FRAMING:
        framing(im, pal, seed + 41, FRAMING[env])     # last: the near tree stands in front of all
    return im


def render(env, variant, tag, seed=0, layout=1):
    os.makedirs(QA, exist_ok=True)
    path = os.path.join(QA, "area_%s_%s_%d_%s.png" % (env, variant, layout, tag))
    scene(env, variant, seed, layout).save(path)
    return path


def _grid(cells, cols, rows, path):
    """Pastes rendered scenes into a padded grid and writes it."""
    from PIL import Image
    pad = 4
    out = Image.new("RGB", ((W + pad) * cols, (H + pad) * rows), (24, 24, 28))
    for (c, r), im in cells.items():
        out.paste(im, (c * (W + pad), r * (H + pad)))
    out.save(path)
    return path


def sheet(tag, envs=ENVS, variants=VARIANTS, made=None, layout=1):
    """Every place in one image, environments down and variants across, for a single look.

    `made` takes the scenes qa has already rendered; without it this re-renders the lot, which at
    four layouts a variant is three times the work for the same picture.
    """
    cells = {(c, r): (made[(env, variant, layout)] if made else scene(env, variant, layout=layout))
             for r, env in enumerate(envs) for c, variant in enumerate(variants)}
    return _grid(cells, len(variants), len(envs), os.path.join(QA, "area_sheet_%s.png" % tag))


def layout_sheet(tag, envs=ENVS, variants=("village", "town", "fortress"), made=None):
    """The settlements down and their layouts across: the one view that shows whether a village is
    four villages or one village with the clouds moved."""
    pairs = [(env, variant) for env in envs for variant in variants]
    cells = {}
    for r, (env, variant) in enumerate(pairs):
        for c in range(LAYOUTS_PER_VARIANT):
            cells[(c, r)] = (made[(env, variant, c + 1)] if made
                             else scene(env, variant, layout=c + 1))
    return _grid(cells, LAYOUTS_PER_VARIANT, len(pairs),
                 os.path.join(QA, "area_layouts_%s.png" % tag))


if __name__ == "__main__":
    args = sys.argv[1:]
    os.makedirs(QA, exist_ok=True)
    if args and args[0] == "all":
        tag = args[1] if len(args) > 1 else "v1"
        for env in ENVS:
            for variant in VARIANTS:
                for layout in range(1, LAYOUTS_PER_VARIANT + 1):
                    print(render(env, variant, tag, layout=layout))
    elif args and args[0] == "sheet":
        print(sheet(args[1] if len(args) > 1 else "v1"))
    elif args and args[0] == "layouts":
        print(layout_sheet(args[1] if len(args) > 1 else "v1"))
    else:
        print(render(args[0], args[1], args[3] if len(args) > 3 else "v1",
                     layout=int(args[2]) if len(args) > 2 else 1))
