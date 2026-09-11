"""QA for each phase. Usage: python qa.py <phase1|phase2|phase3|showcase> <tag>
Images are written to qa/<name>_<tag>.png so every run can be viewed under a fresh filename."""
import os
import random
import sys
import time
from collections import Counter

from hexlib import BORDER, EDGE_MID, EDGE_NAMES, H, HEX_PIXELS, W, in_hex
from preview import contact_sheet, tiled_map

os.makedirs("qa", exist_ok=True)
RING = [(x, y) for x, y in HEX_PIXELS if BORDER[y][x] < 1.5]
OPP = {0: 3, 1: 4, 2: 5, 3: 0, 4: 1, 5: 2}


def containment(tiles, solid=True):
    spill = sum(1 for t in tiles for y in range(H) for x in range(W) if not in_hex(x, y) and t.px[y][x])
    holes = sum(1 for t in tiles for x, y in HEX_PIXELS if t.px[y][x] == 0) if solid else 0
    return spill, holes


def neighbor(r, c, e):
    odd = r % 2
    return {0: (r, c + 1), 3: (r, c - 1), 5: (r - 1, c + odd), 4: (r - 1, c - 1 + odd),
            1: (r + 1, c + odd), 2: (r + 1, c - 1 + odd)}[e]


def road_network(rows, cols, valid, seed, density, blocked=()):
    rng = random.Random(seed)
    links = set()
    for r in range(rows):
        for c in range(cols):
            for e in (0, 1, 2):
                n = neighbor(r, c, e)
                if 0 <= n[0] < rows and 0 <= n[1] < cols and (r, c) not in blocked and n not in blocked \
                        and rng.random() < density:
                    links.add(frozenset({(r, c, e), (n[0], n[1], OPP[e])}))

    def edges_of(r, c):
        return frozenset(EDGE_NAMES[e] for link in links for (lr, lc, e) in link if (lr, lc) == (r, c))
    changed = True
    while changed:
        changed = False
        for r in range(rows):
            for c in range(cols):
                es = edges_of(r, c)
                if es and es not in valid:
                    links.discard(rng.choice([l for l in links if any((a, b) == (r, c) for a, b, _ in l)]))
                    changed = True
    return edges_of


def phase1(tag):
    from terrain import ENV_ORDER, VARIANTS, all_environments
    t0 = time.time()
    tiles = all_environments()
    by = {t.name: t for t in tiles}
    print(f"environments: {len(tiles)} in {time.time() - t0:.1f}s")
    for env in ENV_ORDER:
        ref = by[f"env_{env}_v1"]
        ring = [sum(ref.px[y][x] != by[f"env_{env}_{v}"].px[y][x] for x, y in RING) for v in VARIANTS[1:]]
        total = [sum(ref.px[y][x] != by[f"env_{env}_{v}"].px[y][x] for x, y in HEX_PIXELS) for v in VARIANTS[1:]]
        print(f"  {env:9s} ring diffs {ring}  interior diffs {total}")
    print("  spill/holes:", containment(tiles))
    contact_sheet(tiles, f"qa/p1_sheet_{tag}.png", cols=8, scale=3)

    def layer(r, c, rng):
        v = "accent" if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
        return [by[f"env_{ENV_ORDER[c // 3]}_{v}"]]
    tiled_map([layer], f"qa/p1_map_{tag}.png", cols=18, rows=6, scale=1, seed=7)


def phase2(tag):
    from roads import MATERIALS, all_roads
    from terrain import ENVS
    roads = all_roads()
    print("roads:", len(roads), Counter(t.name.split("_")[1] for t in roads), "spill:", containment(roads, solid=False)[0])
    for mat in MATERIALS:
        bad = 0
        for name in EDGE_NAMES:
            mx, my = EDGE_MID[name]
            zone = [(x, y) for x, y in HEX_PIXELS if BORDER[y][x] < 4.0 and abs(x + .5 - mx) + abs(y + .5 - my) < 16]
            sigs = {tuple(t.px[y][x] for x, y in zone) for t in roads if t.name.startswith(f"road_{mat}_") and name in t.edges}
            bad += len(sigs) != 1
        print(f"  {mat}: edges with differing edge zones = {bad}")
    lut = {m: {frozenset(t.edges): t for t in roads if t.name.startswith(f"road_{m}_")} for m in MATERIALS}
    rows, cols = 6, 12
    edges_of = road_network(rows, cols, lut["dirt"], seed=3, density=0.42)
    block = lambda c: ("dirt", ["grass", "forest", "dirt"]) if c < 4 else ("stone", ["desert", "mountains"]) if c < 8 else ("snow", ["ice"])
    rng = random.Random(1)
    terrain = {(r, c): rng.choice(block(c)[1]) for r in range(rows) for c in range(cols)}
    env_cache = {e: ENVS[e]("v1") for e in ENVS}
    tiled_map([lambda r, c, _: [env_cache[terrain[(r, c)]]],
               lambda r, c, _: [lut[block(c)[0]][edges_of(r, c)]] if edges_of(r, c) else []],
              f"qa/p2_map_{tag}.png", cols=cols, rows=rows, scale=2)
    contact_sheet(roads, f"qa/p2_sheet_{tag}.png", cols=21, scale=2, bg=(70, 110, 60, 255))


def phase3(tag):
    from terrain import ENV_ORDER, ENVS
    from towns import TIERS, all_towns
    towns = all_towns()
    by = {t.name: t for t in towns}
    print("towns:", len(towns), "spill/holes:", containment(towns))
    v1 = {e: ENVS[e]("v1") for e in ENV_ORDER}
    for tier in TIERS:
        print(f"  {tier:8s} ring diffs vs v1:",
              {e: sum(by[f"town_{e}_{tier}"].px[y][x] != v1[e].px[y][x] for x, y in RING) for e in ENV_ORDER})
    contact_sheet(towns, f"qa/p3_sheet_{tag}.png", cols=6, scale=4)


def showcase(tag):
    from roads import MATERIALS, all_roads
    from terrain import ENVS, VARIANTS
    from towns import all_towns
    rows, cols = 7, 12
    rng = random.Random(11)
    envs = {e: {v: ENVS[e](v) for v in VARIANTS} for e in ENVS}
    towns = {t.name: t for t in all_towns()}
    roads = all_roads()
    lut = {m: {frozenset(t.edges): t for t in roads if t.name.startswith(f"road_{m}_")} for m in MATERIALS}
    mat = {"grass": "dirt", "dirt": "dirt", "forest": "dirt", "desert": "stone", "mountains": "stone", "ice": "snow"}

    def region(r, c):
        if c < 4:
            return "forest" if (r + c * 2) % 5 == 0 or r > 5 else "grass"
        if c < 8:
            return "mountains" if r < 2 else "dirt" if c < 6 else "desert"
        return "ice"
    towns_at = {(2, 1): "small", (5, 2): "fortress", (4, 6): "medium", (1, 10): "small", (5, 9): "fortress", (3, 4): "small"}
    edges_of = road_network(rows, cols, lut["dirt"], seed=5, density=0.3, blocked=towns_at)

    def cell(r, c, _):
        env = region(r, c)
        if (r, c) in towns_at:
            return [towns[f"town_{env}_{towns_at[(r, c)]}"]]
        es = edges_of(r, c)
        variant = "accent" if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
        return [envs[env]["v1" if es else variant]] + ([lut[mat[env]][es]] if es else [])
    tiled_map([cell], f"qa/showcase_{tag}.png", cols=cols, rows=rows, scale=2)


if __name__ == "__main__":
    {"phase1": phase1, "phase2": phase2, "phase3": phase3, "showcase": showcase}[sys.argv[1]](sys.argv[2])
