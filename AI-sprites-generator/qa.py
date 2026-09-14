"""QA for each phase. Usage: python qa.py <phase1|phase2|phase3|showcase|blends|ui|slimes> <tag>
Images are written to qa/<name>_<tag>.png so every run can be viewed under a fresh filename."""
import hashlib
import os
import random
import sys
import time
from collections import Counter

from buildlib import ceil_div
from hexlib import BORDER, EDGE_MID, EDGE_NAMES, H, HEX_PIXELS, W, in_hex
from preview import contact_sheet, tiled_map

os.makedirs("qa", exist_ok=True)
RING = [(x, y) for x, y in HEX_PIXELS if BORDER[y][x] < 1.5]
## How many distinct colours a backdrop may sample to -- one number per environment rather than one
## for all six. A single ceiling generous enough for the busiest place is no tripwire at all for the
## quietest: at a flat 140 the worst scene in the set sampled 75, which is two and a half times the
## headroom a real runaway needs to hide in. Each of these is that environment's own measured
## maximum plus room for the ramps its culture still wants, and each is re-recorded when its kit
## lands. The check is a tripwire for an un-quantised blend, not a budget to paint up to.
AREA_COLOUR_CEILING = {"grass": 81, "dirt": 88, "desert": 74, "ice": 86, "forest": 100,
                       "mountains": 100}
## Desert is frozen: it already matches its reference photographs and is the hand-written original
## the layout engine was generalised from. These are md5 of the raw 576x324 pixels of its twenty
## scenes -- before the 4x upscale, before disk, so the check needs no build to have run and no
## file Godot might be holding. Anything that moves one of them moved desert, and says which.
DESERT_HASHES = {
    "fortress_1": "722a27bb9fdc402e69800fb824ce260d",
    "fortress_2": "460ceca2649bc097ffe8155dfe4d5dab",
    "fortress_3": "30a25636c0a898c0e2ed17766491eee8",
    "fortress_4": "6e9d5a5089ec433938576ddec67d9802",
    "plain_1": "0518c9cf329739b7cb47865d4ae42beb",
    "plain_2": "66f8a4713479e4b9d564312308e5442f",
    "plain_3": "d1104120ce618c52fff0c6c86d34bcad",
    "plain_4": "a4feb57ba95f96b6a53a99881e6bbd97",
    "road_1": "b16cb4c99ec65b1d754c30842cd39d96",
    "road_2": "9572573a0c52e177e796730f08463e61",
    "road_3": "390ba3773f0d38a3b081fe6695c4ff34",
    "road_4": "e021bfc782fba5b8e0c22c248dcebcea",
    "town_1": "9d3f389a4c33aa1443eae1fef9070f1f",
    "town_2": "c29d556fbb2339cadf0b1a1b3f5e24b7",
    "town_3": "8a66c82d1959dbddf7cb02ac5c69d43e",
    "town_4": "dde9f38659b640f5c2fb2c6a45d23c2e",
    "village_1": "4f150755295e09c9c6bb5dc1d4cf29da",
    "village_2": "b9a9184dc57e2bd18399d6b536ef22d4",
    "village_3": "7dc8369a43c5529c22fc54e58f50eeca",
    "village_4": "5bfbce253d6462dae80fe1fbbc87ccc8",
}
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
    from roads import MATERIAL_ENVS, MATERIALS, all_roads
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
    columns = list(MATERIAL_ENVS.items())   # one material per four columns, in MATERIAL_ENVS order
    block = lambda c: columns[min(c // 4, len(columns) - 1)]
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
    from roads import MATERIAL_ENVS, MATERIALS, all_roads
    from terrain import ENVS, VARIANTS
    from towns import all_towns
    rows, cols = 7, 12
    rng = random.Random(11)
    envs = {e: {v: ENVS[e](v) for v in VARIANTS} for e in ENVS}
    towns = {t.name: t for t in all_towns()}
    roads = all_roads()
    lut = {m: {frozenset(t.edges): t for t in roads if t.name.startswith(f"road_{m}_")} for m in MATERIALS}
    from roads import ENV_MATERIAL as mat

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


def _ui_font(size=16):
    """Pixellari, only for mockup labels. The mockup is preview-only, never shipped."""
    try:
        from PIL import ImageFont
        return ImageFont.truetype(os.path.join("..", "Assets", "Pixellari.ttf"), size)
    except Exception as exc:
        print("  (no font for labels:", exc, ")")
        return None


def ui(tag):
    from PIL import Image, ImageDraw

    from hexlib import PALETTE
    from preview import RGBA, nine_slice, tile_image
    from ui import CELL, CHAMFER, SIZE, STATES, VARIANTS, all_ui, describe

    tiles = all_ui()
    by = {t.name: t for t in tiles}
    print(f"ui: {len(tiles)} sprites")

    bad_size = [t.name for t in tiles if (t.w, t.h) != (SIZE, SIZE)]
    holes = {t.name: sorted({(x, y) for y in range(t.h) for x in range(t.w)
                             if t.px[y][x] == 0} - set(CHAMFER)) for t in tiles}
    silhouette = {t.name: {(x, y) for y in range(t.h) for x in range(t.w) if t.px[y][x] == 0} for t in tiles}
    print("  wrong size:", bad_size or 0,
          "| unexpected transparent pixels:", {k: v for k, v in holes.items() if v} or 0,
          "| silhouettes identical:", len({frozenset(s) for s in silhouette.values()}) == 1)

    # The one real 9-slice constraint: interior texture must be a pure function of (x % CELL, y % CELL),
    # so repeated centre and edge cells join seamlessly at any size.
    aperiodic = {}
    for t in tiles:
        groups = {}
        for y in range(2, t.h - 2):
            for x in range(2, t.w - 2):
                groups.setdefault((x % CELL, y % CELL), set()).add(t.px[y][x])
        off = {k: sorted(v) for k, v in groups.items() if len(v) > 1}
        if off:
            aperiodic[t.name] = off
    print("  interior not 8-periodic:", aperiodic or 0)

    outlines = {t.name: sorted({t.px[y][x] for x, y in
                                [(x, 0) for x in range(1, SIZE - 1)] + [(x, SIZE - 1) for x in range(1, SIZE - 1)] +
                                [(0, y) for y in range(1, SIZE - 1)] + [(SIZE - 1, y) for y in range(1, SIZE - 1)]})
                for t in tiles}
    print("  multi-colour outlines:", {k: v for k, v in outlines.items() if len(v) > 1} or 0)
    used = sorted({c for t in tiles for c in t.flat() if c})
    print("  palette indices used:", len(used), "of 31:", [PALETTE[i][0] for i in used])

    def lum(i):
        r, g, b = (v / 255 for v in RGBA[i][:3])
        f = lambda u: u / 12.92 if u <= 0.04045 else ((u + 0.055) / 1.055) ** 2.4
        return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b)

    def contrast(a, b):
        la, lb = sorted((lum(a), lum(b)))
        return (lb + 0.05) / (la + 0.05)

    face = lambda name: by[name].px[SIZE // 2][SIZE // 2]
    for surface, panel in (("wood", "ui_panel_wood"), ("light", "ui_panel_white")):
        bg = by[panel].px[SIZE // 2][SIZE // 2]
        for variant in VARIANTS:
            faces = {s: face(f"ui_btn_{surface}_{variant}_{s}") for s in STATES}
            body = lambda s: {by[f"ui_btn_{surface}_{variant}_{s}"].px[y][x]
                              for y in range(2, SIZE - 2) for x in range(2, SIZE - 2)}
            print(f"  {surface}/{variant}: faces {[PALETTE[c][0] for c in faces.values()]} "
                  f"contrast vs panel {[round(contrast(c, bg), 2) for c in faces.values()]} "
                  f"hover differs from normal {body('hover') != body('normal')} "
                  f"pressed keeps the hover face {body('pressed') == body('hover')}")

    # ---- sheet: every sprite at 4x with its name
    font = _ui_font(12)
    cols, scale, pad, lab = 6, 4, 6, 30
    cw, ch = SIZE * scale + pad * 2, SIZE * scale + pad + lab
    rows = ceil_div(len(tiles), cols)
    sheet = Image.new("RGBA", (cols * cw, rows * ch), (40, 40, 48, 255))
    draw = ImageDraw.Draw(sheet)
    for i, t in enumerate(tiles):
        ox, oy = (i % cols) * cw, (i // cols) * ch
        img = tile_image(t).resize((SIZE * scale, SIZE * scale), Image.NEAREST)
        sheet.alpha_composite(img, (ox + pad, oy + pad))
        d = describe(t)
        for line, s in enumerate((f"{d['kind']} {d['surface']}", d["variant"] + " " + d["state"])):
            if font:
                draw.text((ox + pad, oy + pad + SIZE * scale + line * 13), s, font=font,
                          fill=(220, 220, 230, 255))
    sheet.save(f"qa/ui_sheet_{tag}.png")

    # ---- mockup: the kit at realistic sizes, plus stretch proofs
    BW, BH, GAP = 76, 22, 82                                      # button size and column pitch
    mock = Image.new("RGBA", (460, 392), (28, 30, 40, 255))
    draw = ImageDraw.Draw(mock)
    ink, bone = RGBA[1], RGBA[31]

    def text(xy, s, fill):
        if font:
            draw.text(xy, s, font=font, fill=fill)

    def row(x, y, surface, variant, label):
        """One button in each state, with the label colour picked for contrast against the face."""
        for i, state in enumerate(STATES):
            name = f"ui_btn_{surface}_{variant}_{state}"
            mock.alpha_composite(nine_slice(by[name], BW, BH, CELL), (x + i * GAP, y))
            on_dark = lum(face(name)) < 0.35
            text((x + i * GAP + 8, y + 3 + (1 if state == "pressed" else 0)), label, bone if on_dark else ink)

    def headings(x, y, fill):
        for i, state in enumerate(STATES):
            text((x + i * GAP, y), state, fill)

    mock.alpha_composite(nine_slice(by["ui_panel_wood"], 348, 184, CELL), (8, 8))
    mock.alpha_composite(nine_slice(by["ui_panel_white"], 316, 56, CELL), (24, 24))
    text((32, 30), "Blackreach, a small town", ink)
    text((32, 46), "grass 71%   forest 29%", ink)
    headings(24, 88, bone)
    row(24, 104, "wood", "normal", "Discover")
    row(24, 134, "wood", "danger", "Abandon")
    text((24, 164), "buttons on wood", bone)

    mock.alpha_composite(nine_slice(by["ui_panel_white"], 348, 108, CELL), (8, 200))
    headings(24, 212, ink)
    row(24, 228, "light", "normal", "Confirm")
    row(24, 258, "light", "danger", "Delete")
    text((24, 288), "buttons on the white panel", ink)

    text((364, 10), "min 16px", bone)
    mock.alpha_composite(nine_slice(by["ui_panel_wood"], 16, 16, CELL), (364, 26))
    mock.alpha_composite(nine_slice(by["ui_panel_white"], 16, 16, CELL), (388, 26))
    mock.alpha_composite(nine_slice(by["ui_btn_wood_normal_normal"], 16, 16, CELL), (412, 26))
    text((364, 48), "3x detail", bone)
    for i, name in enumerate(("ui_btn_wood_normal_hover", "ui_btn_light_danger_pressed",
                              "ui_btn_wood_normal_disabled")):
        zoom = nine_slice(by[name], 30, 20, CELL)
        mock.alpha_composite(zoom.resize((zoom.width * 3, zoom.height * 3), Image.NEAREST), (364, 64 + i * 66))

    mock.alpha_composite(nine_slice(by["ui_panel_wood"], 444, 72, CELL), (8, 312))
    mock.alpha_composite(nine_slice(by["ui_panel_white"], 428, 24, CELL), (16, 320))
    mock.alpha_composite(nine_slice(by["ui_btn_wood_normal_normal"], 428, 24, CELL), (16, 352))
    text((24, 323), "stretched to 428 px wide", ink)
    text((24, 355), "a very wide button", ink)

    mock.resize((mock.width * 3, mock.height * 3), Image.NEAREST).save(f"qa/ui_mock_{tag}.png")
    print(f"  wrote qa/ui_sheet_{tag}.png and qa/ui_mock_{tag}.png")


def slimes(tag):
    """The per-environment slimes: palette and silhouette checks, plus sheet and terrain previews."""
    import slimes as S
    from PIL import Image, ImageDraw
    from hexlib import PALETTE
    from preview import tile_image
    from terrain import ENVS as TERRAIN
    font = _ui_font(12)

    pal = {tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for _, h in PALETTE[1:]}
    problems = Counter()

    made = {}
    for env, name, img in S.variants():
        made[(env, name)] = img
        base = S.source(name)
        # A pure swap: every pixel keeps its transparency, so outline and animation are untouched.
        problems["silhouette changed"] += sum((a[3] > 0) != (b[3] > 0)
                                              for a, b in zip(base.get_flattened_data(),
                                                              img.get_flattened_data()))
        colours = {p[:3] for p in img.get_flattened_data() if p[3]}
        problems["off-palette"] += len(colours - pal)
        problems["baseline colour left"] += len(colours & ({tuple(c) for c in S.BODY}
                                                           | {tuple(c) for c in S.EYE}))
        # Each frame must use exactly as many colours as the baseline did, or a ramp step collapsed.
        problems["ramp step collapsed"] += len(colours) != len(
            {p[:3] for p in base.get_flattened_data() if p[3]})

    print("problems:", dict(problems))

    # ---- sheet: the baseline on top, then one row per environment, every frame in order
    names = S.frame_names()
    fw, fh, scale = 32, 25, 4
    rows = [("baseline", {n: S.source(n) for n in names})] +            [(env, {n: made[(env, n)] for n in names}) for env in S.ENVS]
    pad = 54
    sheet = Image.new("RGBA", (pad + len(names) * fw * scale, len(rows) * fh * scale),
                      (28, 30, 40, 255))
    draw = ImageDraw.Draw(sheet)
    for r, (label, frames) in enumerate(rows):
        for c, n in enumerate(names):
            im = frames[n].resize((fw * scale, fh * scale), Image.NEAREST)
            sheet.alpha_composite(im, (pad + c * fw * scale, r * fh * scale))
        if font:
            draw.text((4, r * fh * scale + 40), label, font=font, fill=(220, 220, 230, 255))
    sheet.save(f"qa/slimes_{tag}.png")

    # ---- each slime on its own ground (the fight itself draws them on the combat backdrop)
    board = Image.new("RGBA", (len(S.ENVS) * W, H * 2), (20, 20, 24, 255))
    for i, env in enumerate(S.ENVS):
        for j, variant in enumerate(("v1", "v2")):
            board.alpha_composite(tile_image(TERRAIN[env](variant)), (i * W, j * H))
    for i, env in enumerate(S.ENVS):
        for j, n in enumerate(("slime-idle-0", "slime-attack-3")):
            board.alpha_composite(made[(env, n)], (i * W + 12, j * H + 30))
    board.resize((board.width * 4, board.height * 4), Image.NEAREST).save(f"qa/slimes_ground_{tag}.png")
    print(f"  wrote qa/slimes_{tag}.png and qa/slimes_ground_{tag}.png")


def _silhouette(built, bare, y0, y1, step=2):
    """The roofline of a settlement, column by column.

    Taken as the topmost row where the scene differs from the same scene without a settlement in
    it. The two share a seed, so sky, skyline, ground and cover are pixel-identical between them
    and the only thing left to differ is what was built -- which makes this the silhouette exactly,
    with no need to guess which colours are sky and which are roof.
    """
    pb, pn = built.load(), bare.load()
    tops = []
    for x in range(0, 576, step):
        top = y1
        for y in range(y0, y1):
            if pb[x, y] != pn[x, y]:
                top = y
                break
        tops.append(top)
    return tops


def _slopes(tops, y1):
    """How a roofline moves, as four fractions: flat, gentle, steep, vertical.

    This is the roof logic of a culture reduced to a number. A flat-decked kasbah, a steep-gabled
    town and a cone-thatch village produce three quite different distributions however the pieces
    are arranged, which is what makes it a fair test of whether two environments build alike --
    a pixel diff is not, because two palettes always differ and two arrangements always differ.
    """
    # Only what stands proud of the ground. A plan that lays a full-width patch or a river makes
    # almost every column differ from `plain`, so the raw silhouette is mostly the *terrain* line
    # -- and every environment's terrain line is flat, which made two quite different towns look
    # like one roof logic. The lowest built thing is that terrain line; a roof is what clears it.
    on = [t for t in tops if t < y1]
    if not on:
        return None
    floor = max(on) - 5
    buckets = [0, 0, 0, 0]
    for a, b in zip(tops, tops[1:]):
        if a > floor and b > floor:                    # both columns are ground, not roofline
            continue
        d = abs(min(a, floor + 1) - min(b, floor + 1))
        buckets[0 if d == 0 else 1 if d <= 2 else 2 if d <= 6 else 3] += 1
    n = sum(buckets)
    return [b / n for b in buckets] if n else None


def _build_colour(built, bare, y0, y1, step=2):
    """The average colour of what was built, ignoring the ground it was built on.

    Same trick as the silhouette: the two scenes share a seed, so every pixel that differs is one
    somebody put there. What comes back is the material a place builds in, as one number.
    """
    pb, pn = built.load(), bare.load()
    r = g = b = n = 0
    for x in range(0, 576, step):
        for y in range(y0, y1, step):
            if pb[x, y] != pn[x, y]:
                c = pb[x, y]
                r += c[0]; g += c[1]; b += c[2]; n += 1
    return (r / n, g / n, b / n) if n else None


def areas(tag, *only):
    """The battle backdrops: skeleton, variant and layout checks, plus the contact sheets.

    `only` scopes the run to some environments. A full pass renders 120 scenes and takes over two
    minutes, which is past the point where it gets backgrounded and its exit status arrives
    detached; one environment is about ten seconds, which is what iterating on a kit needs.

    The bar is that no counter goes *up* from where it was, not that the dict is empty -- desert is
    frozen and its four fortress layouts are one plan under four seeds, so its two twin pairs are
    today's cost of that and not a regression. The state this was recorded at:

        layouts are twins: 2   (desert_fortress 1/2 and 3/4, both deliberate)
        cousins: 5            (every other counter zero)
        worst colours: grass 56, dirt 63, desert 49, ice 77, forest 84, mountains 75

    The cousins are the whole reason the settlements are being rebuilt, and which ones says why:
    every remaining pair is drawn from grass, dirt and mountains, the three still sharing one
    castle kit and one northern vocabulary. Desert, forest and ice -- the three written from their
    own reference photographs -- are a cousin of nothing. The count comes down as each of the
    other three is rewritten, and zero is the finish line.
    """
    import areas as A
    from arealib import GROUND_TOP, H as AH, HORIZON, W as AW

    envs = [e for e in A.ENVS if e in only] if only else list(A.ENVS)
    assert envs, "no such environment: %s" % (only,)
    problems = Counter()
    worst = Counter()
    made = {}
    for env in envs:
      for layout in range(1, A.LAYOUTS_PER_VARIANT + 1):
        for variant in A.VARIANTS:
            # A kit name a plan asks for and a kit has not got raises from deep inside the render.
            # Unguarded that ends the whole pass, and the five environments that were fine lose
            # their contact sheets along with the one that was not -- which during a rewrite, when
            # half the kits are new, is most days. Draw the wreck and carry on.
            try:
                im = A.scene(env, variant, layout=layout)
            except Exception as exc:
                from PIL import Image
                print("  crashed: %s_%s_%d  %s: %s"
                      % (env, variant, layout, type(exc).__name__, exc))
                problems["scene crashed"] += 1
                im = Image.new("RGB", (AW, AH), (255, 0, 255))
            made[(env, variant, layout)] = im
            px = im.load()
            problems["wrong size"] += im.size != (AW, AH)
            # The skeleton is shared: the land starts on the same row in every scene, so an enemy
            # standing at a given height stands in the same place whatever the backdrop is.
            far = A.PAL[env]["ground"][0][1]
            row = [px[x, GROUND_TOP + 2] for x in range(AW)]
            problems["land starts late"] += far not in row
            problems["land in the sky"] += any(px[x, y] == far
                                               for y in range(0, HORIZON - 10, 3)
                                               for x in range(0, AW, 7))
            # A backdrop is pixel art in one palette, not a photograph. Each environment has its
            # own ceiling, set just above what its art actually samples to, so the check stays a
            # tripwire for an un-quantised blend rather than a budget to paint up to.
            colours = {px[x, y] for y in range(0, AH, 3) for x in range(0, AW, 3)}
            worst[env] = max(worst[env], len(colours))
            if len(colours) > AREA_COLOUR_CEILING[env]:
                problems["too many colours"] += 1
                print("  colours: %s_%s_%d used %d, ceiling %d"
                      % (env, variant, layout, len(colours), AREA_COLOUR_CEILING[env]))
            # Bare ground under the fight: the bottom rows have to carry cover, not a flat band.
            # Bare ground under the fight: the bottom rows carry cover or a road surface, never
            # one flat band. Three is the floor -- a road is only its own three colours.
            floor = {px[x, AH - 1 - d] for d in range(24) for x in range(0, AW, 2)}
            problems["bare floor"] += len(floor) < 3
        # Against plain at the SAME layout: the layout index moves the shared seed identically for
        # every variant, so these two differ only in what was built on top.
        for variant in A.VARIANTS[1:]:
            same = sum(a == b for a, b in zip(made[(env, "plain", layout)].get_flattened_data(),
                                              made[(env, variant, layout)].get_flattened_data()))
            problems["variant drew nothing"] += same == AW * AH

    # A pixel count is too weak a test here: two seeds of one plan already differ in thousands of
    # pixels and still read as one town, and a whole-image diff passes trivially because the sky
    # and the cover are seeded anyway. What says these are two settlements is that the roofline
    # goes somewhere else.
    roof, built = {}, {}
    for env in envs:
        for variant in ("village", "town", "fortress"):
            shapes = [_silhouette(made[(env, variant, L)], made[(env, "plain", L)],
                                  HORIZON - 60, 272)
                      for L in range(1, A.LAYOUTS_PER_VARIANT + 1)]
            twins = []
            for i in range(len(shapes)):
                for j in range(i + 1, len(shapes)):
                    # Out of the columns that have anything built in them, not out of the whole
                    # frame: a settlement covers half the width, and counting the empty sky either
                    # side of it halves every score for no reason.
                    pairs = [(a, b) for a, b in zip(shapes[i], shapes[j]) if a < 272 or b < 272]
                    # ...but not out of a handful either. A quarter of six columns is two, so a
                    # plan that drew almost nothing clears the bar on noise. Something has to have
                    # been built before "these two are different" means anything.
                    if len(pairs) < 60:
                        continue
                    moved = sum(abs(a - b) > 4 for a, b in pairs)
                    if moved < len(pairs) * 0.25:
                        twins.append("%d/%d" % (i + 1, j + 1))
            if twins:
                problems["layouts are twins"] += len(twins)
                print("  twins: %s_%s layouts %s" % (env, variant, ", ".join(twins)))
            for L, tops in enumerate(shapes, 1):
                if sum(t < 272 for t in tops) < 60:
                    problems["settlement too small"] += 1
                    print("  too small: %s_%s_%d" % (env, variant, L))
            # Pool all four layouts into one distribution: a culture's roof logic is the thing that
            # holds across its layouts, so pooling is both steadier and the right question.
            pooled = [0, 0, 0, 0]
            for tops in shapes:
                s = _slopes(tops, 272)
                if s:
                    for k in range(4):
                        pooled[k] += s[k]
            if sum(pooled):
                roof[(env, variant)] = [p / sum(pooled) for p in pooled]
                built[(env, variant)] = _build_colour(made[(env, variant, 1)],
                                                      made[(env, "plain", 1)], HORIZON - 60, 272)

    # Nothing else asks whether two *environments* build alike, and building alike is exactly what
    # shipped: one castle kit injected into every style, six palettes over one silhouette. Two
    # cultures may share a palette or a plot; they may not share the way their roofs move.
    #
    # The bar is calibrated on desert, the one place already built from its own references: its
    # fortress sits 0.41 or further from all five others, so a culture that really is its own
    # clears a quarter comfortably. At 0.15 the check missed grass/ice (0.17) and grass/mountains
    # (0.18), which are visibly the same castle -- the calibration, not the idea, was wrong.
    for variant in ("village", "town", "fortress"):
        have = [e for e in envs if (e, variant) in roof]
        for i, a in enumerate(have):
            for b in have[i + 1:]:
                gap = sum(abs(p - q) for p, q in zip(roof[(a, variant)], roof[(b, variant)]))
                # Two axes, and it takes both. Silhouette alone called a gold tiered temple and a
                # white ice palace one place, because a meru and a needle both taper -- they are
                # not confusable for a second and the check was wrong to say so. Material alone is
                # no better: the four grey castles this was written to catch had four different
                # `stone` values. What makes two places the same place is building the same shape
                # out of the same stuff, and the castles failed on both, which is why they are
                # still caught.
                ca, cb = built.get((a, variant)), built.get((b, variant))
                near = ca and cb and sum((u - v) ** 2 for u, v in zip(ca, cb)) ** 0.5 < 45
                if gap < 0.25 and near:
                    problems["cousins"] += 1
                    print("  cousins: %s_%s and %s_%s build alike (roof %.2f, colour %.0f)"
                          % (a, variant, b, variant, gap,
                             sum((u - v) ** 2 for u, v in zip(ca, cb)) ** 0.5))

    if "desert" in envs and DESERT_HASHES:
        for (env, variant, layout), im in sorted(made.items()):
            if env != "desert":
                continue
            key = "%s_%d" % (variant, layout)
            if hashlib.md5(im.tobytes()).hexdigest() != DESERT_HASHES.get(key):
                problems["desert moved"] += 1
                print("  desert moved: %s" % key)

    print("problems:", dict(problems))
    print("worst colours:", dict(worst))
    print(" ", A.sheet(tag, envs=envs, made=made))
    print(" ", A.layout_sheet(tag, envs=envs, made=made))


def frozen(mode="check"):
    """Desert, which is finished and must not move. `record` prints the table, `check` tests it.

    Hashing the raw 576x324 pixels rather than comparing exported PNGs is the point: no build has
    to have run, nothing Godot may be holding open is touched, and a PNG encoder difference cannot
    be mistaken for an art change. Twenty scenes, about two seconds, so it runs at every step.
    """
    import areas as A

    got = {}
    for variant in A.VARIANTS:
        for layout in range(1, A.LAYOUTS_PER_VARIANT + 1):
            im = A.scene("desert", variant, layout=layout)
            got["%s_%d" % (variant, layout)] = hashlib.md5(im.tobytes()).hexdigest()
    if mode == "record":
        print("DESERT_HASHES = {")
        for k in sorted(got):
            print('    "%s": "%s",' % (k, got[k]))
        print("}")
        return
    assert DESERT_HASHES, "no hashes recorded yet -- run: python qa.py frozen record"
    moved = [k for k in sorted(got) if got[k] != DESERT_HASHES.get(k)]
    for k in moved:
        print("  moved: desert_%s" % k)
    print("desert moved:", len(moved), "of", len(got))


def audit(*_):
    """Every piece name a plan asks for, resolved against the kit that would have to draw it.

    A name a kit has not got raises from inside the render, a hundred scenes deep, with nothing to
    say which plan asked. This is the same question answered statically in under a second, which is
    as close to a type checker as a table of namedtuples is going to get.
    """
    import areaplan as P
    from arealayouts import LAYOUTS

    bad = 0
    # A piece anchored on the crest is drawn at the rock's single highest row, but a mesa is only
    # that high in the middle: its profile is (1 - t**1.7), so a piece placed further out hangs
    # over the shoulder by the difference. A plan can pay that back with a positive `y`, which is
    # exactly what the hand-written ksar does -- its wall sits 14 below the crest so it meets the
    # rock -- so the check has to model the drop and subtract the offset, not just measure across.
    for style, variants in sorted(LAYOUTS.items()):
        for variant, plans in sorted(variants.items()):
            for plan in plans:
                rock = None
                for step in plan.steps:
                    if isinstance(step, P.Land) and step.kind == "mesa":
                        rock = step
                    on = getattr(step, "on", None)
                    if rock is None or on not in ("crest", "land"):
                        continue
                    if not isinstance(step, P.Fix):
                        continue                       # a Course walks the profile by itself
                    if on == "land" and step.span is None:
                        continue                       # a point piece on the land is always right
                    ends = ([step.span[0], step.span[1]] if getattr(step, "span", None)
                            else [step.x])
                    here = 0.0 if on == "crest" else                         (min(1.0, abs(step.x - rock.at) / max(1, rock.half)) ** 1.7) * rock.h * 0.9
                    for e in ends:
                        t = min(1.0, abs(e - rock.at) / max(1, rock.half))
                        gap = (t ** 1.7) * rock.h * 0.9 - here - step.y
                        if gap > 10:
                            print("  %s/%s/%s: %r at %+d floats ~%dpx over the rock"
                                  % (style, variant, plan.name, step.piece, e, gap))
                            bad += 1
                            break
    for style, variants in sorted(LAYOUTS.items()):
        kit = P.KIT.get(style)
        if kit is None:
            print("  no kit for style %r" % style)
            bad += 1
            continue
        for variant, plans in sorted(variants.items()):
            for plan in plans:
                for step in plan.steps:
                    wanted = set()
                    if isinstance(step, P.Row):
                        wanted = {name for name, _ in step.pieces}
                    elif isinstance(step, (P.Course, P.Fix)):
                        wanted = {step.piece}
                    elif isinstance(step, P.Belt):
                        wanted = {"belt"}
                    for name in wanted - set(kit):
                        print("  %s/%s/%s wants %r, which %r has not got"
                              % (style, variant, plan.name, name, style))
                        bad += 1
    print("piece problems:", bad)


if __name__ == "__main__":
    {"phase1": phase1, "phase2": phase2, "phase3": phase3, "showcase": showcase,
     "blends": blends, "ui": ui, "slimes": slimes, "areas": areas,
     "frozen": frozen, "audit": audit}[sys.argv[1]](*sys.argv[2:])
