"""QA for each phase. Usage: python qa.py <phase1|phase2|phase3|showcase|blends> <tag>
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


def illegal_borders(env_at, rows, cols):
    """Neighbouring cells whose environments may not border each other (terrain.ADJACENT)."""
    from terrain import can_border
    bad = Counter()
    for r in range(rows):
        for c in range(cols):
            for e in (0, 1, 2):
                nr, nc = neighbor(r, c, e)
                if 0 <= nr < rows and 0 <= nc < cols and not can_border(env_at(r, c), env_at(nr, nc)):
                    bad["|".join(sorted((env_at(r, c), env_at(nr, nc))))] += 1
    return dict(bad)


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
    from terrain import ENV_CHAIN, ENV_ORDER, VARIANTS, all_environments
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

    def band(r, c):
        return ENV_CHAIN[c // 3]
    print("  illegal borders on map:", illegal_borders(band, 6, 18))

    def layer(r, c, rng):
        v = "accent" if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
        return [by[f"env_{band(r, c)}_{v}"]]
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
        return "mountains" if c == 8 else "ice"   # desert may not border ice
    print("illegal borders:", illegal_borders(region, rows, cols))
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


def blends(tag):
    from PIL import Image
    from blends import RANK, all_blends, blend_tile, edge_dist
    from preview import tiled_image
    from terrain import ENV_CHAIN, ENV_ORDER, ENVS, VARIANTS
    t0 = time.time()
    tiles = all_blends()
    print(f"blends: {len(tiles)} in {time.time() - t0:.1f}s, spill:", containment(tiles, solid=False)[0])
    envs = {e: {v: ENVS[e](v) for v in VARIANTS} for e in ENV_ORDER}
    uncovered, differ = Counter(), Counter()
    for t in tiles:
        ref = envs[t.env]["v1"]
        for x, y in RING:
            if min(edge_dist(e, x, y) for e in t.mask) < 1.5:
                uncovered[t.env] += t.px[y][x] == 0
                differ[t.env] += t.px[y][x] not in (0, ref.px[y][x])
    print("  seam pixels uncovered:", dict(uncovered), "| differing from v1:", dict(differ))

    def layers(env_at, rows, cols, blended):
        def cell(r, c, rng):
            own = env_at(r, c)
            v = "accent" if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
            if not blended:
                return [envs[own][v]]
            near = {}
            for e in range(6):
                nr, nc = neighbor(r, c, e)
                if 0 <= nr < rows and 0 <= nc < cols and RANK[env_at(nr, nc)] > RANK[own]:
                    near.setdefault(env_at(nr, nc), []).append(e)
            return [envs[own][v]] + [blend_tile(n, tuple(es)) for n, es in sorted(near.items(), key=lambda kv: RANK[kv[0]])]
        return [cell]

    pairs = [("forest", "grass"), ("grass", "dirt"), ("desert", "dirt"), ("mountains", "desert"), ("ice", "grass"),
             ("mountains", "ice")]
    shots, illegal = [], {}
    for i, (hi, lo) in enumerate(pairs):
        def env_at(r, c, hi=hi, lo=lo):
            env = hi if c < (3, 2, 3, 4)[r] else lo
            return (lo if env == hi else hi) if (r, c) in ((1, 4), (2, 1)) else env   # one island each way
        illegal.update(illegal_borders(env_at, 4, 6))
        after = tiled_image(layers(env_at, 4, 6, True), 6, 4, seed=i)
        shots.append((tiled_image(layers(env_at, 4, 6, False), 6, 4, seed=i), after))
        after.resize((after.width * 3, after.height * 3), Image.NEAREST).save(f"qa/blend_{hi}_{lo}_{tag}.png")
    w, h = shots[0][0].size
    sheet = Image.new("RGBA", (w * 2 + 8, (h + 8) * len(shots)), (40, 40, 48, 255))
    for i, (before, after) in enumerate(shots):
        sheet.paste(before, (0, i * (h + 8)))
        sheet.paste(after, (w + 8, i * (h + 8)))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"qa/blend_pairs_{tag}.png")

    def band(r, c):
        return ENV_CHAIN[c // 3]
    illegal.update(illegal_borders(band, 6, 18))
    print("  illegal borders on preview maps:", illegal)
    img = tiled_image(layers(band, 6, 18, True), 18, 6, seed=7)
    img.resize((img.width * 2, img.height * 2), Image.NEAREST).save(f"qa/blend_map_{tag}.png")


if __name__ == "__main__":
    {"phase1": phase1, "phase2": phase2, "phase3": phase3, "showcase": showcase,
     "blends": blends}[sys.argv[1]](sys.argv[2])
