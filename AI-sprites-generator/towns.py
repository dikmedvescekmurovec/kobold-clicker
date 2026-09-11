"""Phase 3: detailed towns on each environment's v1 terrain (56x64).

The v1 tile stays untouched near the border so towns tile against open terrain. Inside, a
dithered clearing swaps in the object-free ground (no trees / peaks). Ground layers (plaza,
paths, fields) are painted first; everything else is drawn sorted by its bottom edge so
south-facing walls overlap correctly.
"""
import math

import town_parts as tp
from hexlib import BORDER, C, HEX_PIXELS, bayer
from terrain import ENV_ORDER, ENVS

TIERS = ["small", "medium", "fortress"]
CLEARING = {"small": 16.0, "medium": 20.0, "fortress": 24.0}

STYLE = {
    "grass": dict(roof=("rust", "brick", "brick_dk"), wall=("bone", "mist", "stone"), kind="plaster",
                  fort=("stone_lt", "stone", "slate"), fort_kind="stone", ground="soil_lt", flat=False,
                  people=("brick", "ice_dk", "olive", "lilac"), awning=("brick", "bone"), crop="wheat", tree="leaf"),
    "dirt": dict(roof=("sand_lt", "sand_dk", "soil_lt"), wall=("soil_lt", "soil", "earth"), kind="plank",
                 fort=("soil_lt", "soil", "earth"), fort_kind="plank", ground="sand_dk", flat=False,
                 people=("olive", "rust", "ice_dk", "brick"), awning=("rust", "sand_lt"), crop="wheat", tree="leaf"),
    "desert": dict(roof=("bone", "sand_lt", "sand_dk"), wall=("sand_lt", "sand_dk", "soil_lt"), kind="plaster",
                   fort=("sand_lt", "sand_dk", "soil_lt"), fort_kind="stone", ground="sand_dk", flat=True,
                   people=("bone", "lilac", "amber", "ice_dk"), awning=("lilac", "bone"), crop="green", tree="palm"),
    "ice": dict(roof=("snow", "ice_lt", "ice"), wall=("soil_lt", "soil", "earth"), kind="log",
                fort=("mist", "stone_lt", "stone"), fort_kind="stone", ground="mist", flat=False,
                people=("brick", "ice_dk", "amber", "olive"), awning=("ice_dk", "snow"), crop=None, tree="snow"),
    "forest": dict(roof=("sand_dk", "soil_lt", "soil"), wall=("soil_lt", "soil", "earth"), kind="log",
                   fort=("soil_lt", "soil", "earth"), fort_kind="plank", ground="soil", flat=False,
                   people=("leaf", "rust", "amber", "brick"), awning=("leaf_dk", "sand_lt"), crop="cabbage", tree="pine"),
    "mountains": dict(roof=("stone", "slate", "slate_dk"), wall=("mist", "stone_lt", "stone"), kind="stone",
                      fort=("mist", "stone_lt", "stone"), fort_kind="stone", ground="slate", flat=False,
                      people=("brick", "amber", "ice_dk", "olive"), awning=("brick", "stone_lt"), crop="cabbage", tree="pine"),
}


def _clamp01(v):
    return min(max(v, 0.0), 1.0)


def town_base(env, tier):
    full = ENVS[env]("v1")
    bare = ENVS[env]("v1", objects=False)
    t = full.copy(f"town_{env}_{tier}", "towns")
    radius = CLEARING[tier]
    for x, y in HEX_PIXELS:
        d = math.hypot(x + 0.5 - 28, (y + 0.5 - 33) * 1.1)
        k = _clamp01((radius - d) / 3.0) * _clamp01((BORDER[y][x] - 6.0) / 2.0)
        if k > bayer(x, y):
            t.px[y][x] = bare.px[y][x]
    return t


def plaza(t, cx, cy, rx, ry, color):
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            e = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if e <= 1.0 and bayer(x, y) < 0.95 - 0.6 * e:
                tp.P(t, x, y, C[color])


def house(t, st, x0, y0, w, d, dome=False):
    if st["flat"]:
        return (y0 + d + 5, lambda: tp.flat_building(t, x0, y0, w, d, st, dome_roof=dome))
    return (y0 + d + 5, lambda: tp.building(t, x0, y0, w, d, st))


def tree(t, st, x, y):
    if st["tree"] == "palm":
        return (y + 5, lambda: tp.palm(t, x, y))
    return (y + 5, lambda: tp.small_tree(t, x, y, st["tree"]))


def people(t, st, spots):
    return [(y + 3, lambda x=x, y=y, i=i: tp.villager(t, x, y, st["people"][i % len(st["people"])]))
            for i, (x, y) in enumerate(spots)]


def compose(t, ground, objects):
    for fn in ground:
        fn()
    for _, fn in sorted(objects, key=lambda o: o[0]):
        fn()


# --------------------------------------------------------------------------- tiers
def small(t, env, st):
    g = st["ground"]
    ground = [lambda: plaza(t, 28, 36, 9, 5, g),
              lambda: tp.path(t, [(28, 40), (27, 52)], g),
              lambda: tp.path(t, [(36, 36), (47, 34)], g)]
    objs = [house(t, st, 10, 17, 14, 8), house(t, st, 31, 13, 13, 7, dome=True),
            (40, lambda: tp.well(t, 22, 36)), (33, lambda: tp.barrel(t, 49, 29)),
            tree(t, st, 46, 46)]
    objs.append((33, lambda: tp.haystack(t, 46, 31)) if env in ("grass", "dirt") else (32, lambda: tp.crate(t, 44, 28)))
    if env == "ice":
        objs += [(48, lambda: tp.igloo(t, 37, 42)), (47, lambda: tp.ice_hole(t, 14, 45))]
        objs += people(t, st, [(26, 33), (17, 43), (34, 51)])
    else:
        objs.append(house(t, st, 32, 37, 11, 6))
        if st["crop"]:
            ground.append(lambda: tp.crop_field(t, 8, 40, 12, 8, st["crop"]))
        objs += people(t, st, [(26, 33), (35, 51)])
    compose(t, ground, objs)


def medium(t, env, st):
    g, cone = st["ground"], not st["flat"]
    ground = [lambda: plaza(t, 28, 39, 12, 6, g),
              lambda: tp.path(t, [(28, 45), (28, 52)], g),
              lambda: tp.path(t, [(16, 39), (9, 38)], g),
              lambda: tp.path(t, [(40, 39), (47, 39)], g)]
    objs = [(18, lambda: tp.wall_h(t, 16, 40, 11, st)),
            (22, lambda: tp.round_tower(t, 14, 14, 4.2, st, cone=cone)),
            (22, lambda: tp.round_tower(t, 42, 14, 4.2, st, cone=cone, flag="brick")),
            house(t, st, 4, 21, 12, 7),
            house(t, st, 19, 20, 18, 9, dome=True),
            house(t, st, 21, 48, 14, 5),
            (43, lambda: tp.stall(t, 16, 37, st["awning"])),
            (43, lambda: tp.stall(t, 34, 37, st["awning"][::-1]))]
    objs += people(t, st, [(22, 45), (35, 46), (13, 38), (45, 37)])

    # plaza centre-piece
    if env == "desert":
        objs += [(44, lambda: tp.pool(t, 28, 40, 5.5, 3.2)), (47, lambda: tp.palm(t, 21, 43)), (47, lambda: tp.palm(t, 36, 43))]
    elif env == "ice":
        objs += [(42, lambda: tp.ice_hole(t, 28, 40))] + people(t, st, [(31, 38)])
    elif env in ("grass", "mountains"):
        objs.append((44, lambda: tp.fountain(t, 28, 39)))
    else:
        objs.append((43, lambda: tp.well(t, 28, 39)))

    # top-right landmark slot
    if env == "grass":
        objs.append((33, lambda: tp.windmill(t, 46, 24, st)))
    elif env == "mountains":
        objs.append((33, lambda: tp.mine_entrance(t, 44, 26)))
    else:
        objs.append(house(t, st, 40, 21, 12, 7))

    # bottom slots
    if env == "ice":
        objs += [(51, lambda: tp.igloo(t, 12, 46)), (51, lambda: tp.igloo(t, 43, 46))]
    else:
        objs.append(house(t, st, 7, 41, 11, 6))
        if env == "dirt":
            ground.append(lambda: tp.crop_field(t, 38, 42, 12, 8, "wheat"))
            objs += [(49, lambda: tp.haystack(t, 41, 46)), (50, lambda: tp.haystack(t, 47, 47))]
        elif env == "forest":
            objs += [(52, lambda: tp.log_pile(t, 38, 46, 4)), tree(t, st, 47, 43)]
        else:
            objs.append(house(t, st, 38, 41, 11, 6))
    compose(t, ground, objs)


def fortress(t, env, st):
    g, cone = st["ground"], not st["flat"]
    ground = [lambda: plaza(t, 28, 30, 13, 8, g), lambda: tp.path(t, [(28, 50), (28, 54)], g)]
    objs = [(20, lambda: tp.wall_h(t, 13, 43, 14, st)),
            (46, lambda: tp.wall_v(t, 11, 16, 42, st)),
            (46, lambda: tp.wall_v(t, 41, 16, 42, st)),
            (47, lambda: tp.wall_h(t, 13, 22, 40, st)),
            (47, lambda: tp.wall_h(t, 34, 43, 40, st)),
            (50, lambda: tp.gatehouse(t, 28, 36, st)),
            (25, lambda: tp.round_tower(t, 13, 16, 4.5, st, cone=cone, flag="brick")),
            (25, lambda: tp.round_tower(t, 43, 16, 4.5, st, cone=cone, flag="amber")),
            (51, lambda: tp.round_tower(t, 13, 42, 4.5, st, cone=cone)),
            (51, lambda: tp.round_tower(t, 43, 42, 4.5, st, cone=cone)),
            house(t, st, 18, 21, 20, 8, dome=True),
            (35, lambda: tp.round_tower(t, 37, 22, 3.8, st, cone=cone, flag="brick")),
            (38, lambda: tp.crate(t, 15, 34)), (39, lambda: tp.crate(t, 18, 35)),
            (38, lambda: tp.barrel(t, 38, 34)),
            (41, lambda: tp.well(t, 38, 38)),
            tree(t, st, 5, 28), tree(t, st, 51, 30)]
    objs += people(t, st, [(25, 34), (31, 34), (28, 55)])
    compose(t, ground, objs)


RING_KEEP = 2.0   # outer ring restored from v1 so towns always tile against open terrain


def town(env, tier):
    t = town_base(env, tier)
    {"small": small, "medium": medium, "fortress": fortress}[tier](t, env, STYLE[env])
    v1 = ENVS[env]("v1")
    for x, y in HEX_PIXELS:
        if BORDER[y][x] < RING_KEEP:
            t.px[y][x] = v1.px[y][x]
    return t


def all_towns():
    return [town(env, tier) for env in ENV_ORDER for tier in TIERS]
