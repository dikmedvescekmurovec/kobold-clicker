"""The six places, painted with vista.py. One function per environment; `variant` and `layout`
choose what stands in the middle distance."""
import random
import sys

import numpy as np

import vista as v
import vista_props as props
import vista_towns as towns
from vista import rgb, mix, shade, W, H

ENVS = ("grass", "forest", "dirt", "desert", "mountains", "ice")
VARIANTS = ("plain", "road", "village", "town", "fortress")
## Each (environment, variant) comes in this many layouts: `CombatScene.AREA_LAYOUTS` must match.
LAYOUTS = 4


# ---------------------------------------------------------------- grass: a bright late morning

GRASS = dict(
    sky=[rgb("3d7fc4"), rgb("4f97d6"), rgb("72b3e3"), rgb("a6d3ee"), rgb("d9eef2")],
    hz=rgb("bcdcea"),
    cloud=(rgb("fffdf4"), rgb("eef3f5"), rgb("c3d6e6"), rgb("a9bfd6")),
    range=rgb("6d86b3"),
    snow=(rgb("f4f6fb"), rgb("c7cfe6")),
    far=rgb("5f9a6a"), far_rim=rgb("8cc27a"),
    mid=rgb("4f9a45"), mid_rim=rgb("9fd26a"), mid_dk=rgb("3c7d3c"),
    tree=(rgb("7cc257"), rgb("4c9a3c"), rgb("2f6b35")),
    trunk=rgb("5a4432"),
    near=rgb("5aa843"), near_dk=rgb("3f8a3a"), near_lt=rgb("86c957"),
    tufts=[rgb("7cc255"), rgb("4a963c"), rgb("9bd865"), rgb("3a8038")],
    blade=[rgb("2f6e33"), rgb("3a8038"), rgb("275e2e")],
    flowers=[(rgb("f5f0e0"), rgb("f3c94a")), (rgb("f08aa0"), rgb("fbe3a0")),
             (rgb("f3c94a"), rgb("e08c2c")), (rgb("9cc4f0"), rgb("f5f0e0"))],
)


def grass(variant, layout, seed):
    p = GRASS
    rng = random.Random(seed)
    cv = v.Canvas()
    v.sky(cv, p["sky"], 196, bands=10)
    # clouds: a few big heaps high, small ones sinking into the haze near the horizon
    for i in range(3):
        v.cumulus(cv, rng, rng.uniform(40, W - 40), int(rng.uniform(70, 110)), rng.uniform(70, 120),
                  rng.uniform(16, 24), p["cloud"])
    for i in range(6):
        v.cumulus(cv, rng, rng.uniform(0, W), int(rng.uniform(150, 175)), rng.uniform(26, 50),
                  rng.uniform(6, 10), p["cloud"], haze=0.35, hz=p["hz"])
    for i in range(4):
        v.cirrus(cv, rng, rng.uniform(0, W), int(rng.uniform(18, 50)), int(rng.uniform(30, 80)),
                 rgb("d8ecf4"), rgb("a8d0ea"))
    # far blue range
    line, who, apex = v.peaks_line(seed + 1, 196, 46, 7, spread=(0.55, 0.9))
    v.range_fill(cv, line, who, apex, 196, p["range"], p["hz"], 0.45, snow=p["snow"],
                 snowline=160, seed=seed + 1)
    # far hills with a hazed wood along them
    far = v.hills_line(seed + 2, 204, 12)
    v.treeline(cv, seed + 3, far, 7, p["tree"], p["hz"], 0.55, density=0.8)
    v.hills_fill(cv, far, H, p["far"], p["far_rim"], p["hz"], 0.42)
    far2 = v.hills_line(seed + 9, 214, 16, ((2, 1.0), (5, 0.5), (12, 0.1)))
    v.hills_fill(cv, far2, H, p["far"], p["far_rim"], p["hz"], 0.25)
    for x in range(0, W, 3):
        if random.Random(seed * 7 + x).random() < 0.18:
            v.broadleaf(cv, rng, x, int(far2[x]) + 1, rng.uniform(2.5, 3.5), p["tree"], p["hz"],
                        0.3)
    # middle hills with hedgerow trees, and whoever lives there
    site = towns.Site("grass", variant, layout, seed)
    mid = site.shape(v.hills_line(seed + 4, 230, 18, ((2, 1.0), (5, 0.5), (13, 0.1))))
    v.hills_fill(cv, mid, H, p["mid"], p["mid_rim"], p["hz"], 0.12, dark=p["mid_dk"], grad=0.5)
    for _ in range(rng.randint(3, 6)):
        x = rng.uniform(10, W - 10)
        if site.built and abs(x - site.cx) < site.half + 20:
            continue
        v.broadleaf(cv, rng, x, int(mid[int(x)]) + 1, rng.uniform(4, 7), p["tree"], p["hz"], 0.12,
                    trunk=p["trunk"])
    site.build(cv, mid, p["hz"], 0.08)
    land("mid", cv, "grass", variant, layout, seed, mid)
    # near ground
    near = v.hills_line(seed + 5, 236, 5, ((2, 1.0), (6, 0.3)))
    v.hills_fill(cv, near, H, p["near"], p["near_lt"], p["hz"], 0.0, dark=p["near_dk"],
                 grad=0.0)
    v.leaf_clumps(cv, seed + 6, 236, H + 6, (p["near_lt"], p["near"], p["near_dk"]), 1.3,
                  alt=(rgb("a6d86a"), rgb("78bf4e"), rgb("58a444")),
                  dark=(rgb("4f9a3e"), rgb("3a7f36"), rgb("2c6430")))
    v.flowers(cv, seed + 7, 250, H - 4, 120, p["flowers"])
    land("near", cv, "grass", variant, layout, seed, near)
    return cv


# ---------------------------------------------------------------- forest: a misty clearing

FOREST = dict(
    sky=[rgb("a8d8c8"), rgb("cde8c8"), rgb("eef3d2"), rgb("fbf6d8")],
    hz=rgb("b8d8bc"),
    far=(rgb("6ea88a"), rgb("4f8a74"), rgb("3a6e62")),
    mid=(rgb("4f944e"), rgb("357a42"), rgb("245a36")),
    ground=(rgb("8fc25a"), rgb("62a044"), rgb("437f3a")),
    ground_alt=(rgb("b4d46c"), rgb("86b850"), rgb("5c9a42")),
    ground_dk=(rgb("4a8a3c"), rgb("35703a"), rgb("27552f")),
    bark=(rgb("8a6a4a"), rgb("5e4634"), rgb("41302a"), rgb("2a1f1f")),
    leaf=(rgb("5f9e4a"), rgb("3e7a3c"), rgb("275331")),
    shaft=rgb("fff3c0"),
    flowers=[(rgb("f5f0e0"), rgb("f3c94a")), (rgb("e86a5a"), rgb("f5f0e0")),
             (rgb("c9a0f0"), rgb("f5f0e0"))],
)


def forest(variant, layout, seed):
    p = FOREST
    rng = random.Random(seed)
    cv = v.Canvas()
    v.sky(cv, p["sky"], 200, bands=8)
    # walls of wood, each nearer one darker and less veiled
    for k, (base, hgt, haze, dens) in enumerate(((160, 70, 0.62, 0.55), (186, 84, 0.4, 0.5),
                                                  (206, 90, 0.18, 0.45))):
        line = v.hills_line(seed + 20 + k, base, 8)
        v.firs(cv, seed + 30 + k, line, hgt, p["far"], p["hz"], haze, density=dens)
        v.hills_fill(cv, line, H, p["far"][1], p["far"][0], p["hz"], haze)
        v.haze_band(cv, base - 26, base + 4, p["hz"], 0.6, top=False)
    v.shafts(cv, seed + 5, p["shaft"], count=5, strength=0.4, top=20, bottom=240)
    line = v.hills_line(seed + 23, 222, 8)
    v.treeline(cv, seed + 33, line, 26, p["mid"], p["hz"], 0.05, kind="round", density=0.9)
    v.hills_fill(cv, line, H, p["mid"][1], p["mid"][0], p["hz"], 0.05)
    site = towns.Site("forest", variant, layout, seed)
    ground = site.shape(v.hills_line(seed + 25, 232, 6))
    if site.built:
        v.hills_fill(cv, ground, H, p["ground"][1], p["ground"][0], p["hz"], 0.03)
    site.build(cv, ground, p["hz"], 0.05)
    land("mid", cv, "forest", variant, layout, seed, ground)
    near = v.hills_line(seed + 24, 238, 6)
    v.hills_fill(cv, near, H, p["ground"][1], p["ground"][0], p["hz"], 0.0)
    v.leaf_clumps(cv, seed + 6, 238, H + 6, p["ground"], 1.3, alt=p["ground_alt"],
                  dark=p["ground_dk"])
    v.flowers(cv, seed + 7, 250, H - 4, 70, p["flowers"])
    land("near", cv, "forest", variant, layout, seed, near)
    for fx, side in ((44, 1), (W - 50, -1)):
        v.fern(cv, rng, fx, H + 4, rng.uniform(40, 50), p["ground_dk"], side)
    # the wood's roof hanging over the top edge
    v.canopy(cv, seed + 8, 26, p["leaf"])
    return cv


# ---------------------------------------------------------------- dirt: steppe at golden hour

DIRT = dict(
    sky=[rgb("5a6fa8"), rgb("8a86b0"), rgb("d19a9a"), rgb("f0b47a"), rgb("fbd6a0")],
    hz=rgb("e8b890"),
    sun=(rgb("fff2c8"), rgb("fbdc9a")),
    cloud=(rgb("ffd9a8"), rgb("e8a58c"), rgb("a9809e"), rgb("8a6a90")),
    mesa=(rgb("b8704e"), rgb("e39a62"), rgb("7a4a52"), rgb("8e5446")),
    far=rgb("b98a6a"), far_rim=rgb("e0b07a"),
    mid=rgb("a07048"), mid_rim=rgb("d9a864"), mid_dk=rgb("7c5440"),
    ground=(rgb("d8b06a"), rgb("b08850"), rgb("86643e")),
    ground_alt=(rgb("e6c47a"), rgb("c49a58"), rgb("9a7448")),
    ground_dk=(rgb("9a7448"), rgb("74563a"), rgb("54402e")),
    rock=(rgb("c79a78"), rgb("946c58"), rgb("5e4442")),
    shrub=(rgb("a8a05a"), rgb("7c7a44"), rgb("545634")),
)


def dirt(variant, layout, seed):
    p = DIRT
    rng = random.Random(seed)
    cv = v.Canvas()
    v.sky(cv, p["sky"], 200, bands=11)
    v.glow(cv, 430, 150, 160, rgb("ffe6b0"), 0.55, bottom=200)
    v.sun(cv, 430, 150, 13, *p["sun"])
    for i in range(4):
        v.cumulus(cv, rng, rng.uniform(0, W), int(rng.uniform(50, 120)), rng.uniform(60, 120),
                  rng.uniform(10, 16), p["cloud"])
    line, who, spans = v.mesa_line(seed + 1, 204, 5, (130, 170), (40, 110))
    v.mesa_fill(cv, line, who, spans, 204, p["mesa"][0], p["mesa"][1], p["mesa"][2], p["mesa"][3],
                p["hz"], 0.45, seed=seed)
    far = v.hills_line(seed + 2, 214, 12)
    v.hills_fill(cv, far, H, p["far"], p["far_rim"], p["hz"], 0.35)
    site = towns.Site("dirt", variant, layout, seed)
    mid = site.shape(v.hills_line(seed + 3, 228, 14))
    v.hills_fill(cv, mid, H, p["mid"], p["mid_rim"], p["hz"], 0.15, dark=p["mid_dk"], grad=0.5)
    site.build(cv, mid, p["hz"], 0.04)
    land("mid", cv, "dirt", variant, layout, seed, mid)
    for _ in range(8):
        x = rng.uniform(0, W)
        if site.built and abs(x - site.cx) < site.half + 20:
            continue
        v.broadleaf(cv, rng, x, int(mid[int(min(W - 1, x))]) + 1, rng.uniform(2, 3.5),
                    p["shrub"], p["hz"], 0.2)
    near = v.hills_line(seed + 4, 238, 5)
    v.hills_fill(cv, near, H, p["ground"][1], p["ground"][0], p["hz"], 0.0)
    v.leaf_clumps(cv, seed + 6, 238, H + 6, p["ground"], 1.1, alt=p["ground_alt"],
                  dark=p["ground_dk"])
    for _ in range(6):
        v.rock(cv, rng, rng.uniform(0, W), int(rng.uniform(250, 320)), rng.uniform(3, 8),
               rng.uniform(2, 4), p["rock"])
    land("near", cv, "dirt", variant, layout, seed, near)
    return cv


# ---------------------------------------------------------------- desert: noon over the dunes

DESERT = dict(
    sky=[rgb("3f8fcc"), rgb("5eaad8"), rgb("92c8e0"), rgb("cfe3dc"), rgb("f2ead0")],
    hz=rgb("eadfc4"),
    cloud=(rgb("fffcf0"), rgb("f2f0e6"), rgb("d8dcd8"), rgb("c6c8c6")),
    dune_far=(rgb("e8c88a"), rgb("c99a6a"), rgb("f6e2b0")),
    dune_mid=(rgb("f0c77e"), rgb("c88a52"), rgb("fbe3a8")),
    ground=(rgb("f6d796"), rgb("e6bb74"), rgb("c99558")),
    ground_alt=(rgb("fbe3a8"), rgb("f0cb86"), rgb("d8a868")),
    ground_dk=(rgb("dcae6c"), rgb("c08c52"), rgb("9c6c42")),
    rock=(rgb("d8a878"), rgb("a8744e"), rgb("6e4a3a")),
    scrub=(rgb("a8a868"), rgb("7e8450"), rgb("56603e")),
)


def desert(variant, layout, seed):
    p = DESERT
    rng = random.Random(seed)
    cv = v.Canvas()
    v.sky(cv, p["sky"], 204, bands=10)
    for i in range(3):
        v.cumulus(cv, rng, rng.uniform(0, W), int(rng.uniform(150, 180)), rng.uniform(30, 60),
                  rng.uniform(5, 8), p["cloud"], haze=0.4, hz=p["hz"])
    for i in range(5):
        v.cirrus(cv, rng, rng.uniform(0, W), int(rng.uniform(20, 80)), int(rng.uniform(40, 120)),
                 rgb("d6ecf2"), rgb("9ccde6"))
    v.glow(cv, 118, 34, 30, rgb("fbf8e8"), 0.9, bottom=204)
    v.sun(cv, 118, 34, 9, rgb("fffff4"), rgb("fbf6d8"))
    for k, (base, hgt, haze) in enumerate(((206, 30, 0.55), (218, 40, 0.3), (232, 30, 0.1))):
        line, who, crests = v.dune_line(seed + 10 + k, base, 3, hgt, wl=(160, 300))
        pal = p["dune_far"] if k == 0 else p["dune_mid"]
        if k == 2:
            pal = (p["ground"][1], rgb("d49a5e"), p["ground"][0])
        v.dune_fill(cv, line, who, crests, H, pal[0], pal[1], pal[2], p["hz"], haze)
    site = towns.Site("desert", variant, layout, seed)
    pan = site.shape(v.hills_line(seed + 12, 232, 5))
    if site.built or variant == "plain":
        v.hills_fill(cv, pan, H, p["dune_mid"][0], p["dune_mid"][2], p["hz"], 0.15)
    site.build(cv, pan, p["hz"], 0.08)
    land("mid", cv, "desert", variant, layout, seed, pan)
    v.drifts(cv, seed + 6, 244, 300, (p["ground_alt"][0], p["ground"][0], p["ground"][1]), 3,
             amp=(8, 16))
    v.ripples(cv, seed + 7, 246, H, [p["ground"][1], p["ground_alt"][0]], 320)
    for _ in range(7):
        v.broadleaf(cv, rng, rng.uniform(0, W), int(rng.uniform(250, 318)), rng.uniform(2, 4),
                    p["scrub"])
    for _ in range(4):
        v.rock(cv, rng, rng.uniform(0, W), int(rng.uniform(255, 320)), rng.uniform(3, 7),
               rng.uniform(2, 3), p["rock"])
    land("near", cv, "desert", variant, layout, seed, None)
    return cv


# ---------------------------------------------------------------- mountains: a crisp alpine valley

MOUNTAINS = dict(
    sky=[rgb("2f5fa8"), rgb("3f7cc0"), rgb("6aa2d4"), rgb("a8cde6"), rgb("dcecf0")],
    hz=rgb("b8d2e4"),
    cloud=(rgb("ffffff"), rgb("eef2f6"), rgb("c4d0e0"), rgb("a8b6cc")),
    far=rgb("7c8cb4"), near_rock=rgb("7a7e94"),
    snow=(rgb("fbfcff"), rgb("b8c4e0")),
    meadow=rgb("6aa058"), meadow_rim=rgb("a6cc72"), meadow_dk=rgb("4c8048"),
    fir=(rgb("4f8a5a"), rgb("2f6444"), rgb("1f4838")),
    ground=(rgb("9cc868"), rgb("6ea24e"), rgb("4e8042")),
    ground_alt=(rgb("b8d478"), rgb("8cb85a"), rgb("64984a")),
    ground_dk=(rgb("5e8a4a"), rgb("46703e"), rgb("345634")),
    rock=(rgb("c0c4cc"), rgb("8a8e9c"), rgb("5a5c70")),
    flowers=[(rgb("f5f0e0"), rgb("f3c94a")), (rgb("b89af0"), rgb("f5f0e0")),
             (rgb("f3c94a"), rgb("e08c2c"))],
)


def mountains(variant, layout, seed):
    p = MOUNTAINS
    rng = random.Random(seed)
    cv = v.Canvas()
    v.sky(cv, p["sky"], 190, bands=10)
    for i in range(3):
        v.cumulus(cv, rng, rng.uniform(0, W), int(rng.uniform(40, 80)), rng.uniform(60, 100),
                  rng.uniform(10, 16), p["cloud"])
    line, who, apex = v.peaks_line(seed + 1, 190, 90, 6, spread=(0.9, 1.5))
    v.range_fill(cv, line, who, apex, 200, p["far"], p["hz"], 0.45, snow=p["snow"],
                 snowline=150, seed=seed + 1)
    line, who, apex = v.peaks_line(seed + 2, 206, 70, 4, spread=(1.1, 1.7))
    v.range_fill(cv, line, who, apex, 214, p["near_rock"], p["hz"], 0.12, snow=p["snow"],
                 snowline=170, seed=seed + 2, foot_haze=0.5)
    site = towns.Site("mountains", variant, layout, seed)
    mid = site.shape(v.hills_line(seed + 3, 226, 18))
    v.treeline(cv, seed + 4, mid, 16, p["fir"], p["hz"], 0.15, kind="fir", density=0.6)
    v.hills_fill(cv, mid, H, p["meadow"], p["meadow_rim"], p["hz"], 0.1, dark=p["meadow_dk"],
                 grad=0.4)
    site.build(cv, mid, p["hz"], 0.06)
    land("mid", cv, "mountains", variant, layout, seed, mid)
    near = v.hills_line(seed + 5, 240, 5)
    v.hills_fill(cv, near, H, p["ground"][1], p["ground"][0], p["hz"], 0.0)
    v.leaf_clumps(cv, seed + 6, 240, H + 6, p["ground"], 1.2, alt=p["ground_alt"],
                  dark=p["ground_dk"])
    v.flowers(cv, seed + 7, 250, H - 4, 90, p["flowers"])
    for _ in range(6):
        v.rock(cv, rng, rng.uniform(0, W), int(rng.uniform(250, 322)), rng.uniform(4, 10),
               rng.uniform(2, 5), p["rock"])
    land("near", cv, "mountains", variant, layout, seed, near)
    return cv


# ---------------------------------------------------------------- ice: twilight on the snowfield

ICE = dict(
    sky=[rgb("1c1f4a"), rgb("33306a"), rgb("5c4886"), rgb("a8709a"), rgb("f0a89a"), rgb("fcd2a8")],
    hz=rgb("c8a8c0"),
    aurora=[rgb("7affc0"), rgb("7ae0ff")],
    star=[rgb("fff4d8"), rgb("c8d8ff")],
    peak=rgb("6a6aa0"), snow=(rgb("f6d8dc"), rgb("8c8cc0")),
    fir=(rgb("4a5a86"), rgb("323e68"), rgb("222a4c")), fir_snow=rgb("e8e0f0"),
    far=rgb("a8a0d0"), far_rim=rgb("f4d4dc"),
    mid=rgb("c0bce0"), mid_rim=rgb("fae4e4"), mid_dk=rgb("9a98c8"),
    ground=(rgb("f4eef8"), rgb("d0cce8"), rgb("a8a6d4")),
    ground_alt=(rgb("fff2ec"), rgb("e6dcee"), rgb("c0b8e0")),
    ground_dk=(rgb("c4c0e2"), rgb("9e9cce"), rgb("7a7ab4")),
)


def ice(variant, layout, seed):
    p = ICE
    rng = random.Random(seed)
    cv = v.Canvas()
    v.sky(cv, p["sky"], 200, bands=12)
    v.stars(cv, seed, 110, 120, p["star"])
    v.aurora(cv, seed + 1, 10, 55, p["aurora"], 0.75)
    line, who, apex = v.peaks_line(seed + 2, 196, 60, 7, spread=(0.8, 1.3))
    v.range_fill(cv, line, who, apex, 200, p["peak"], p["hz"], 0.35, snow=p["snow"],
                 snowline=175, seed=seed + 2)
    far = v.hills_line(seed + 3, 210, 10)
    v.treeline(cv, seed + 4, far, 12, p["fir"], p["hz"], 0.35, kind="fir", density=1.0,
               snow=p["fir_snow"])
    v.hills_fill(cv, far, H, p["far"], p["far_rim"], p["hz"], 0.25)
    site = towns.Site("ice", variant, layout, seed)
    mid = site.shape(v.hills_line(seed + 5, 226, 14))
    v.hills_fill(cv, mid, H, p["mid"], p["mid_rim"], p["hz"], 0.08, dark=p["mid_dk"], grad=0.4)
    site.build(cv, mid, p["hz"], 0.04)
    land("mid", cv, "ice", variant, layout, seed, mid)
    for _ in range(5):
        x = rng.uniform(0, W)
        if site.built and abs(x - site.cx) < site.half + 20:
            continue
        v.conifer(cv, int(x), int(mid[int(min(W - 1, x))]) + 2, rng.randint(12, 22), p["fir"],
                  snow=p["fir_snow"])
    v.drifts(cv, seed + 7, 236, 300, (rgb("fff4f0"), rgb("e4e0f4"), rgb("aaa8da")), 4,
             amp=(10, 20))
    v.sparkle(cv, seed + 8, 236, H, 90, rgb("ffffff"))
    land("near", cv, "ice", variant, layout, seed, None)
    return cv


# ---------------------------------------------------------------- the open land: roads and landmarks

def m4(a, b_, c, d):
    return (rgb(a), rgb(b_), rgb(c), rgb(d))


WOOD = m4("c89a6a", "9a6e46", "74502e", "3e2a1a")
SIGN = rgb("e8d4a8")
LAND = dict(
    grass=dict(road=m4("dcb67e", "bb8e5a", "96693e", "6a4a30"),
               stone=m4("dcd8cc", "b4ae9e", "8a8474", "4e4a44"),
               edge=[rgb("7cc255"), rgb("4a963c")], water=(rgb("a6d3ee"), rgb("3d7fc4")),
               plain=("oak", "pond", "stones", "ruin")),
    forest=dict(road=m4("a8845a", "86643e", "664a30", "42301f"),
                stone=m4("c2c4a6", "9c9e84", "767a62", "3c4034"),
                edge=[rgb("62a044"), rgb("437f3a")], water=(rgb("b8e0d0"), rgb("2f6a5a")),
                plain=("log", "pond", "stones", "oak")),
    dirt=dict(road=m4("ecc890", "d4a870", "ac804e", "70543a"),
              stone=m4("d8b08c", "b08868", "86604a", "4e3830"),
              edge=[rgb("c49a58"), rgb("9a7448")], water=(rgb("f0b47a"), rgb("7a5a70")),
              plain=("dead", "cairns", "stones", "ruin")),
    desert=dict(road=m4("fae4b8", "e6c48e", "c49e6c", "8a6a48"),
                stone=m4("f4d8a8", "d8b07c", "b08658", "6e5038"),
                edge=[rgb("c99558"), rgb("e6bb74")], water=(rgb("8fd0e0"), rgb("2f7a9a")),
                plain=("oasis", "ruin", "stones", "dead")),
    mountains=dict(road=m4("cfc4ae", "aa9e88", "857a66", "524a3a"),
                   stone=m4("d4d8e0", "a4a8b8", "7a7e90", "4a4c5e"),
                   edge=[rgb("6ea24e"), rgb("4e8042")], water=(rgb("a8cde6"), rgb("2f5fa8")),
                   plain=("pond", "cairns", "oak", "ruin")),
    ice=dict(road=m4("f2eefa", "cfcae6", "a8a4d2", "7c7ab2"),
             stone=m4("9c9cc8", "74749e", "54547a", "34344e"),
             edge=[rgb("fff4f0"), rgb("c4c0e2")], water=(rgb("cfe0f6"), rgb("7888c8")),
             ice=m4("f4fbff", "bfe2f6", "86b6e0", "3e5e96"), plain=("pond", "shards", "dead", "stones")),
)
LEAF = dict(grass=(rgb("7cc257"), rgb("4c9a3c"), rgb("2f6b35")),
            forest=(rgb("6aa84e"), rgb("437f3c"), rgb("2a5832")),
            mountains=(rgb("6aa058"), rgb("3f7a4a"), rgb("27543a")),
            dirt=(rgb("b0a45e"), rgb("857c48"), rgb("5a5636")),
            desert=(rgb("8ab85a"), rgb("5a8c42"), rgb("3e6636")),
            ice=(rgb("e8e0f0"), rgb("a8a4d0"), rgb("6a6aa0")))


def land(stage, cv, env, variant, layout, seed, line):
    """What stands in the open: at stage "mid", the plain's landmark and the far half of a lane;
    at "near", the road across the fighting ground and what stands beside it."""
    import vista_build as vb
    import vista_kits as kits
    q = LAND[env]
    r = random.Random(seed * 13 + layout)
    if variant == "plain" and stage == "near":
        # the landmark stands at the back of the fighting ground, between the two sides
        if line is None:
            line = np.full(W, 240.0)
        line = np.minimum(line + 4, 246)
        what = q["plain"][layout - 1]
        cx = W * (0.44, 0.56, 0.48, 0.53)[layout - 1] + r.uniform(-12, 12)
        base = int(line[int(cx)])
        if what == "oak":
            props.oak(cv, r, cx, base, r.uniform(30, 36), LEAF[env], WOOD)
        elif what == "pond":
            props.pond(cv, seed, cx, base - 4, r.uniform(90, 120), 12, q["water"][0],
                       q["water"][1], q["stone"][2], rgb("ffffff"))
        elif what == "stones":
            props.standing_stones(cv, r, cx, line, r.randint(4, 5), q["stone"], spread=15)
        elif what == "ruin":
            props.ruin(cv, r, cx, line, q["stone"], n=r.randint(4, 5))
        elif what == "dead":
            props.dead_tree(cv, r, cx, base, r.randint(80, 96), q["stone"][3], q["stone"][2])
        elif what == "cairns":
            for k in range(3):
                x = cx + (k - 1) * r.uniform(46, 64)
                props.cairn(cv, r, x, int(line[int(x)]) - (k != 1) * 3, q["stone"],
                            k=1.5 if k == 1 else 1.0)
        elif what == "shards":
            props.shards(cv, r, cx, line, r.randint(7, 10), q["ice"])
        elif what == "oasis":
            props.pond(cv, seed, cx, base - 4, r.uniform(70, 90), 10, q["water"][0],
                       q["water"][1], q["stone"][2], rgb("ffffff"))
            for k in range(6):
                x = cx + (k - 2.5) * r.uniform(22, 30)
                vb.palm(cv, r, int(x), base - 2 + r.randint(0, 3), r.randint(24, 34),
                        kits.S_TRUNK, kits.S_LEAF, k=2.0)
        elif what == "log":
            props.log(cv, int(cx) - 40, base + 2, 74, WOOD, rgb("d8b888"), h=13)
            props.mushrooms(cv, r, int(cx) - 50, int(cx) + 44, base + 3, rgb("d84a3a"),
                            rgb("f0e8d8"))
    if variant == "road":
        # the road runs from low on one side up to the crest on the other; odd layouts rise to
        # the right, even ones to the left, and two of the four go on over the hill
        right = layout % 2 == 1
        x_near, x_far = (-30.0, W * 0.78) if right else (W + 30.0, W * 0.22)
        crest = 238.0
        y, hw, inside = props.road_path(seed, x_near, 318, x_far, crest)
        if stage == "mid" and layout in (1, 2):
            props.far_road(cv, seed, line, x_far + (6 if right else -6), q["road"],
                           turn=1 if right else -1)
        if stage == "near":
            props.near_road(cv, seed, y, hw, inside, q["road"], edge=q["edge"])
            def on_road(x, side):
                return int(y[int(x)] + side * hw[int(x)]) + (2 if side > 0 else -1)
            if layout == 1:
                props.signpost(cv, int(W * 0.46), on_road(W * 0.46, -1), WOOD, SIGN)
            elif layout == 2:
                props.milestone(cv, int(W * 0.5), on_road(W * 0.5, -1), q["stone"])
                props.fence(cv, int(W * 0.3), int(W * 0.72),
                            np.array([on_road(min(W - 1, max(0, x)), -1) - 3.0 for x in range(W)]),
                            WOOD)
            elif layout == 3:
                props.cart(cv, int(W * 0.36), on_road(W * 0.4, -1), WOOD, q["road"][3],
                           load=rgb("d8c090"))
                props.milestone(cv, int(W * 0.62), on_road(W * 0.62, -1), q["stone"])
            else:
                props.signpost(cv, int(W * 0.52), on_road(W * 0.52, -1), WOOD, SIGN)
                props.milestone(cv, int(W * 0.4), on_road(W * 0.4, -1), q["stone"])


SCENES = {"grass": grass, "forest": forest, "dirt": dirt, "desert": desert,
          "mountains": mountains, "ice": ice}


def render(env, variant="plain", layout=1, seed=0):
    """One backdrop. Every (variant, layout) gets its own sky and land, not only its own
    settlement."""
    return SCENES[env](variant, layout, seed + layout * 101 + VARIANTS.index(variant) * 17)


def sheet(path, cells, cols=2, k=1, fighters=False):
    from PIL import Image
    tiles = [render(*c).image() for c in cells]
    if fighters:
        import vista_fighters
        tiles = [vista_fighters.with_fighters(t) for t in tiles]
    rows = (len(tiles) + cols - 1) // cols
    out = Image.new("RGB", (W * cols, H * rows))
    for i, t in enumerate(tiles):
        out.paste(t, ((i % cols) * W, (i // cols) * H))
    out.resize((out.width * k, out.height * k), Image.NEAREST).save(path)
    print(path)


if __name__ == "__main__":
    # vista_scenes.py <tag> [env ...] [variant ...] [layout digits]
    tag = sys.argv[1] if len(sys.argv) > 1 else "t"
    args = sys.argv[2:]
    envs = [a for a in args if a in ENVS] or list(SCENES)
    variants = [a for a in args if a in VARIANTS] or ["plain"]
    layouts = [int(a) for a in args if a.isdigit()] or [1]
    cells = [(e, vv, l) for e in envs for vv in variants for l in layouts]
    one = len(cells) == 1
    sheet(f"qa/vista_{tag}.png", cells, cols=1 if one else 2, k=2 if one else 1,
          fighters="fighters" in args)
