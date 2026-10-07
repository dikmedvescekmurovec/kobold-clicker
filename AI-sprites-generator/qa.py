"""QA for each phase. Usage: python qa.py <phase1|phase2|phase3|showcase|blends|ui|slimes|hpbar|gear> <tag>
Images are written to qa/<name>_<tag>.png so every run can be viewed under a fresh filename."""
import math
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
    from terrain import ACCENTS, ENV_CHAIN, ENV_ORDER, VARIANTS, all_environments
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
        v = rng.choice(ACCENTS) if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
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
    from terrain import ACCENTS, ENVS, VARIANTS
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
        variant = rng.choice(ACCENTS) if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
        return [envs[env]["v1" if es else variant]] + ([lut[mat[env]][es]] if es else [])
    tiled_map([cell], f"qa/showcase_{tag}.png", cols=cols, rows=rows, scale=2)


def blends(tag):
    from PIL import Image
    from blends import RANK, all_blends, blend_tile, edge_dist
    from preview import tiled_image
    from terrain import ACCENTS, ENV_CHAIN, ENV_ORDER, ENVS, VARIANTS
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
            v = rng.choice(ACCENTS) if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
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
             ("mountains", "ice"), ("desert", "grass"), ("ice", "dirt"), ("forest", "desert"),
             ("forest", "ice")]
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
    row(24, 104, "wood", "normal", "Chart")
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


def hpbar(tag):
    """The combat nameplate's health bar: palette and geometry checks, plus every tier draining."""
    import hpbar as B
    from PIL import Image, ImageDraw
    from hexlib import PALETTE
    font = _ui_font(12)

    pal = {tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for _, h in PALETTE[1:]}
    made = B.parts()
    problems = Counter()
    for name, im in made.items():
        problems["off-palette"] += len({p[:3] for p in im.get_flattened_data() if p[3]} - pal)
        problems["wrong height"] += im.height != B.HEIGHT
    # The trough has to come out the same length in every tier, or the fill means a different number
    # of hit points depending on what is standing there.
    widths = {t: B.bar(t, 1.0, made).width - 2 * (B.cap_width(t) - 1) for t in B.TIERS}
    problems["trough differs by tier"] += len(set(widths.values())) != 1
    # And the ornament has to actually grow, which is the whole promise of the elite and boss frames.
    caps = [B.cap_width(t) for t in ("common", "elite", "boss")]
    problems["ornament does not grow"] += caps != sorted(set(caps))
    print("problems:", dict(problems))
    print("  trough %d px, caps %s" % (B.trough(), dict(zip(B.TIERS, caps))))

    # ---- every tier at every state the player will see it in, on the wood panel it stands over
    shares = [1.0, 0.75, 0.5, 0.25, 0.06, 0.0]
    scale, pad, gap = 5, 60, 6
    tiers = ["common", "elite", "boss"]
    widest = max(B.bar(t, 1.0, made).width for t in tiers)
    sheet = Image.new("RGBA", (pad + widest * scale + 12,
                               len(tiers) * len(shares) * (B.HEIGHT + gap) * scale),
                      (0x6B, 0x4A, 0x32, 255))
    draw = ImageDraw.Draw(sheet)
    row = 0
    for tier in tiers:
        for share in shares:
            im = B.bar(tier, share, made)
            y = row * (B.HEIGHT + gap) * scale
            sheet.alpha_composite(im.resize((im.width * scale, im.height * scale), Image.NEAREST),
                                  (pad, y))
            if font:
                draw.text((4, y + 8), "%s %d%%" % (tier[:5], round(share * 100)),
                          font=font, fill=(240, 238, 220, 255))
            row += 1
    sheet.save(f"qa/hpbar_{tag}.png")

    # ---- the parts themselves, blown up, so a bad pixel is visible before it is assembled
    names = B.names()
    cell = max(im.width for im in made.values()) + 2
    board = Image.new("RGBA", (len(names) * cell * scale * 2, (B.HEIGHT + 10) * scale * 2),
                      (28, 30, 40, 255))
    draw = ImageDraw.Draw(board)
    for i, n in enumerate(names):
        im = made[n]
        board.alpha_composite(im.resize((im.width * scale * 2, im.height * scale * 2), Image.NEAREST),
                              (i * cell * scale * 2, 0))
        if font:
            draw.text((i * cell * scale * 2 + 2, B.HEIGHT * scale * 2 + 6),
                      n.replace("ui_hpbar_", ""), font=font, fill=(220, 220, 230, 255))
    board.save(f"qa/hpbar_parts_{tag}.png")
    print(f"  wrote qa/hpbar_{tag}.png and qa/hpbar_parts_{tag}.png")


def gear(tag):
    """The generated item-base icons: checks, then every one of them on the bag's socket among the
    pack's own gear, borders off, at 4x and at 1x. The test of the sheet is that the drawn ones
    cannot be picked out from the cut ones at a glance."""
    import gear as G
    from PIL import Image
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
    sys.path.insert(0, os.path.join(root, "tools"))
    import ui_kit as K

    made = G.icons()
    again = G.icons()
    problems = Counter()
    colours = {}
    for name, im in made.items():
        problems["wrong size"] += im.size != (G.SIDE, G.SIDE)
        problems["not the same twice"] += im.tobytes() != again[name].tobytes()
        problems["doubled pixels"] += K._doubled(im)
        # Hard alpha like the pack: a pixel is in or it is out.
        problems["soft alpha"] += sum(0 < p[3] < 255 for p in im.get_flattened_data())
        # The white ring has to be whole for _outlined to know it for a border, so the art
        # itself may not reach the edge of the square.
        bare = K._outlined(im)
        problems["art clipped by the square"] += bare.tobytes() == im.tobytes()
        colours[name] = len({p[:3] for p in bare.get_flattened_data() if p[3]})
    # The pack holds 235 to 557 colours an icon; a dagger is half a sword's pixels and holds about
    # 120. Far under that and a drawing has gone flat.
    thin = {n: k for n, k in colours.items() if k < 100}
    problems["flat (under 100 colours)"] += len(thin)
    # One finish for all sixty-nine, cut and drawn alike: every opaque pixel that touches clear is
    # outline ink. Counted over the whole sheet as tools/ui_kit.py assembles it, so a pack piece is
    # held to the rule a drawn one is. (base_gear itself stops on an icon under the floor.)
    here = os.getcwd()
    os.chdir(root)
    try:
        bases = K.base_gear()
    finally:
        os.chdir(here)
    drawn = {t[0] for _slot, tiers in K.BASE_KINDS.values() for t in tiers if t[1] == K.DRAWN}
    for label, names in (("drawn", drawn), ("cut", set(bases) - drawn)):
        shares = [K.outline_share(bases[n]) for n in names]
        problems["outline under the floor"] += sum(v < K.OUTLINE_FLOOR for v in shares)
        print("  %s: %d icons, edge in outline ink %.0f%%-%.0f%%" % (label, len(shares), 100 * min(shares),
                                                                     100 * max(shares)))
    print("icons:", len(made), " colours an icon: %d-%d" % (min(colours.values()), max(colours.values())))
    print("problems:", dict(problems), thin or "")

    pack = ["Weapon & Tool/Iron Sword", "Equipment/Leather Boot", "Equipment/Iron Helmet", "Weapon & Tool/Knife",
            "Equipment/Wooden Armor", "Equipment/Wizard Hat", "Weapon & Tool/Iron Shield", "Equipment/Iron Boot",
            "Equipment/Leather Helmet", "Weapon & Tool/Golden Sword", "Equipment/Helm", "Weapon & Tool/Hammer"]
    cells = list(made.values())
    for i, name in enumerate(pack):
        cells.insert(i * 5 + 2, Image.open(os.path.join(root, K.POTENTIAL, K._RPG + name + ".png")).convert("RGBA"))
    cols, zoom, cell = 10, 4, 36
    rows = ceil_div(len(cells), cols)
    sheet = Image.new("RGBA", (cols * cell * zoom, rows * (cell * zoom + cell)), (0x8A, 0x6F, 0x4E, 255))
    for i, im in enumerate(cells):
        im = K._outlined(im)
        x, y = (i % cols) * cell * zoom, (i // cols) * (cell * zoom + cell)
        sheet.alpha_composite(im.resize((G.SIDE * zoom,) * 2, Image.NEAREST), (x + 2 * zoom, y + 2 * zoom))
        sheet.alpha_composite(im, (x + (cell * zoom - G.SIDE) // 2, y + cell * zoom))
    sheet.save(f"qa/gear_{tag}.png")
    print(f"  wrote qa/gear_{tag}.png")


def icewall(tag):
    """The wall ring round a patch of land with wasteland past it, and the wasteland block on its own."""
    from ice_wall import ACCENT_CHANCE, ACCENTS, VARIANTS as IV, WASTE_COLS, WASTE_ROWS, accent, snow_spill, wall_band, waste
    from terrain import ENVS, VARIANTS
    wastes = {(c, r): waste(c, r) for c in range(WASTE_COLS) for r in range(WASTE_ROWS)}
    accents = [accent(a) for a in ACCENTS]
    print("spill/holes:", containment(list(wastes.values())), containment(accents, solid=False))
    envs = {e: [ENVS[e](v) for v in VARIANTS[:3]] for e in ("grass", "mountains", "ice")}
    rows, cols, centre = 13, 15, (6, 7)

    def ring(r, c):
        q = lambda r, c: (c - (r - (r & 1)) // 2, r)
        (q1, r1), (q0, r0) = q(r, c), q(*centre)
        dq, dr = q1 - q0, r1 - r0
        return (abs(dq) + abs(dr) + abs(dq + dr)) // 2

    def cell(r, c, rng):
        d = ring(r, c)
        if d < 4:
            env = "mountains" if c < 6 and r < 7 else "ice" if c > 8 else "grass"
            touching = tuple(e for e in range(6) if ring(*neighbor(r, c, e)) >= 4)
            return [rng.choice(envs[env])] + ([snow_spill(touching)] if touching else [])
        out = [wastes[(c % WASTE_COLS, r % WASTE_ROWS)]]
        if d == 4:
            out.append(wall_band(tuple(e for e in range(6) if ring(*neighbor(r, c, e)) == 4), rng.choice(IV)))
        elif rng.random() < ACCENT_CHANCE:
            out.append(rng.choice(accents))
        return out
    tiled_map([cell], f"qa/icewall_band_{tag}.png", cols=cols, rows=rows, scale=2, seed=3)
    tiled_map([lambda r, c, _: [wastes[(c % WASTE_COLS, r % WASTE_ROWS)]]], f"qa/icewall_waste_{tag}.png",
              cols=WASTE_COLS * 2, rows=WASTE_ROWS * 2, scale=2)
    contact_sheet(accents,
                  f"qa/icewall_sheet_{tag}.png", cols=7, scale=3, bg=(232, 245, 251, 255))


def towns(tag):
    """Each settlement as the map shows it: its ground tile among its own land with the building sprite
    over it, then the same under the fog's veil with the sprite dimmed the way HexMap draws it."""
    from PIL import Image
    import towns as T
    from hexlib import H, W, in_hex
    from preview import tile_image
    from terrain import ENVS
    fog, tint = (38, 33, 48, 140), (0.78, 0.76, 0.84)
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    veil.putdata([fog if in_hex(i % W, i // W) else (0, 0, 0, 0) for i in range(W * H)])
    spots = [(56, 0), (-56, 0), (28, 48), (-28, 48), (28, -48), (-28, -48)]

    def scene(env, tile, sprite, fogged):
        img = Image.new("RGBA", (W * 3, H + 96), (20, 20, 24, 255))
        for (dx, dy), v in zip(spots, ("v1", "v2", "v3", "v1", "v2", "v3")):
            img.alpha_composite(tile_image(ENVS[env](v)), (W + dx, 48 + dy))
            if fogged:
                img.alpha_composite(veil, (W + dx, 48 + dy))
        img.alpha_composite(tile_image(tile), (W, 48))
        if fogged:
            img.alpha_composite(veil, (W, 48))
            sprite = sprite.copy()
            sprite.putdata([(int(r * tint[0]), int(g * tint[1]), int(b * tint[2]), a)
                            for r, g, b, a in sprite.get_flattened_data()])
        img.alpha_composite(sprite, (W - T.SHIFT[0], 48 - T.SHIFT[1]))
        return img.crop((W // 2, 24, W * 5 // 2, H + 72))

    shots = []
    for env in T.ENV_ORDER:
        for tier in T.TIERS:
            tile, cv = T.build(env, tier)
            sprite = Image.new("RGBA", (T.SPRITE_W, T.SPRITE_H))
            sprite.putdata([RGBA_OF(c) for row in cv.px for c in row])
            shots += [scene(env, tile, sprite, False), scene(env, tile, sprite, True)]
    cw, ch = shots[0].size
    sheet = Image.new("RGBA", ((cw + 4) * 6, (ch + 4) * 6), (20, 20, 24, 255))
    for i, im in enumerate(shots):
        sheet.alpha_composite(im, ((i % 6) * (cw + 4), (i // 6) * (ch + 4)))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"qa/towns_{tag}.png")
    print(f"  wrote qa/towns_{tag}.png (each settlement clear, then fogged; three tiers a row pair)")


def caves(tag):
    """Each ground's cave as the map shows it, on a plain tile among its own land: bare, lit by its
    glow, lit under the fog's veil, and that ground's village beside it for scale. One ground a row.
    The glow is `Scenes/Map/cave_glow.gdshader`'s arithmetic done here at one moment, mid-breath: the
    game's breathes and flickers, which a still cannot."""
    from PIL import Image
    import caves as CV
    import towns as T
    from hexlib import H, W, in_hex
    from preview import tile_image
    from terrain import ENVS
    fog, tint = (38, 33, 48, 140), (0.78, 0.76, 0.84)
    veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    veil.putdata([fog if in_hex(i % W, i // W) else (0, 0, 0, 0) for i in range(W * H)])
    spots = [(56, 0), (-56, 0), (28, 48), (-28, 48), (28, -48), (-28, -48)]
    glow_rgb, pool, heart, rise, plume_w, steps = (0.62, 0.07, 0.05), (24.0, 13.0), 3.0, 32.0, 15.0, 4.0
    bayer4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    def lit(img, ox, oy, dim):
        """Adds the glow over `img`, its origin at (ox, oy) in `img`'s pixels, as the shader does."""
        px = img.load()
        for ly in range(-34, 20):
            for lx in range(-32, 32):
                x, y = lx + 0.5, ly + 0.5
                held = 1 - math.hypot(x / pool[0], (y - heart) / pool[1])
                up = min(max(-y / rise, 0), 1)
                wide = plume_w * (1 - up * 0.7)
                plume = (1 - up) * (1 - abs(x) / wide) * 0.85 if y < 0 else 0
                light = min(max(max(held, plume), 0), 1)
                b = bayer4[(ly % 4) * 4 + (lx % 4)] / 16 - 0.5
                level = min(max(math.floor(light * 0.85 * 0.96 * steps + b), 0), steps)
                if level < 0.5:
                    continue
                gx, gy = ox + lx, oy + ly
                if 0 <= gx < img.width and 0 <= gy < img.height:
                    r, g, bl, a = px[gx, gy]
                    add = [int(255 * c * level / steps * dim) for c in glow_rgb]
                    px[gx, gy] = (min(r + add[0], 255), min(g + add[1], 255), min(bl + add[2], 255), a)

    def scene(env, tile, sprite, fogged, glow):
        img = Image.new("RGBA", (W * 3, H + 96), (20, 20, 24, 255))
        for (dx, dy), v in zip(spots, ("v1", "v2", "v3", "v1", "v2", "v3")):
            img.alpha_composite(tile_image(ENVS[env](v)), (W + dx, 48 + dy))
            if fogged:
                img.alpha_composite(veil, (W + dx, 48 + dy))
        img.alpha_composite(tile_image(tile), (W, 48))
        if fogged:
            img.alpha_composite(veil, (W, 48))
            sprite = sprite.copy()
            sprite.putdata([(int(r * tint[0]), int(g * tint[1]), int(b * tint[2]), a)
                            for r, g, b, a in sprite.get_flattened_data()])
        at = (W - T.SHIFT[0], 48 - T.SHIFT[1])
        img.alpha_composite(sprite, at)
        if glow:
            lit(img, at[0] + CV.HOLE[0], at[1] + CV.HOLE[1], tint[0] if fogged else 1.0)
        return img.crop((W // 2, 24, W * 5 // 2, H + 72))

    def image(cv):
        sprite = Image.new("RGBA", (T.SPRITE_W, T.SPRITE_H))
        sprite.putdata([RGBA_OF(c) for row in cv.px for c in row])
        return sprite

    shots = []
    for env in T.ENV_ORDER:
        cave = image(CV.build(env))
        tile, town = T.build(env, "small")
        ground = ENVS[env]("v2")
        shots += [scene(env, ground, cave, False, False), scene(env, ground, cave, False, True),
                  scene(env, ground, cave, True, True), scene(env, tile, image(town), False, False)]
    cw, ch = shots[0].size
    sheet = Image.new("RGBA", ((cw + 4) * 4, (ch + 4) * 6), (20, 20, 24, 255))
    for i, im in enumerate(shots):
        sheet.alpha_composite(im, ((i % 4) * (cw + 4), (i // 4) * (ch + 4)))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"qa/caves_{tag}.png")
    print(f"  wrote qa/caves_{tag}.png (a ground a row: bare, lit, lit under the fog, and its village)")


def fallen(tag):
    """Where a wall stood, once it has fallen: a patch of land with the old ring running through all six
    grounds, a road across it (drawn over the rubble) and a village on it (which has none), beside the
    same patch with the wall still standing."""
    from PIL import Image
    import towns as T
    from blends import RANK, blend_tile
    from ice_wall import VARIANTS as IV, WASTE_COLS, WASTE_ROWS, rubble, snow_spill, wall_band, waste
    from preview import tile_image
    from roads import ENV_MATERIAL, all_roads
    from terrain import ACCENTS, ENV_CHAIN, ENVS, VARIANTS
    rows, cols, centre, R = 8, 12, (11, 6), 8
    road_col, town_at = 4, (3, 7)

    def ring(r, c):
        q = lambda r, c: (c - (r - (r & 1)) // 2, r)
        (q1, r1), (q0, r0) = q(r, c), q(*centre)
        dq, dr = q1 - q0, r1 - r0
        return (abs(dq) + abs(dr) + abs(dq + dr)) // 2

    def env_at(r, c):
        return ENV_CHAIN[min(max(c, 0), cols - 1) // 2]
    print("illegal borders:", illegal_borders(env_at, rows, cols))
    envs = {e: {v: ENVS[e](v) for v in VARIANTS} for e in ENV_CHAIN}
    roads = {(t.name.split("_")[1], frozenset(EDGE_NAMES.index(n) for n in t.edges)): t for t in all_roads()}
    road = {}
    for r in range(rows):
        es = (5, 1) if r % 2 == 0 else (4, 2)          # down column road_col, a bend a row
        road[(r, road_col)] = roads[(ENV_MATERIAL[env_at(r, road_col)], frozenset(es))]
    town_tile, town_cv = T.build(env_at(*town_at), "small")
    town_sprite = Image.new("RGBA", (T.SPRITE_W, T.SPRITE_H))
    town_sprite.putdata([RGBA_OF(c) for row in town_cv.px for c in row])
    blends = {}

    def scene(fell):
        rng = random.Random(4)
        img = Image.new("RGBA", (cols * 56 + 28, rows * 48 + 16), (20, 20, 24, 255))
        for r in range(rows):
            for c in range(cols):
                d, own = ring(r, c), env_at(r, c)
                variant = rng.choice(ACCENTS) if rng.random() < 0.1 else rng.choice(VARIANTS[:3])
                ice = not fell and d >= R
                layers = []
                if ice:
                    layers.append(waste(c % WASTE_COLS, r % WASTE_ROWS))
                else:
                    layers.append(town_tile if (r, c) == town_at else envs[own]["v1" if (r, c) in road else variant])
                    near = {}
                    for e in range(6):
                        nr, nc = neighbor(r, c, e)
                        if 0 <= nr < rows and 0 <= nc < cols and RANK[env_at(nr, nc)] > RANK[own]:
                            near.setdefault(env_at(nr, nc), []).append(e)
                    for n, es in sorted(near.items(), key=lambda kv: RANK[kv[0]]):
                        if (n, tuple(es)) not in blends:
                            blends[(n, tuple(es))] = blend_tile(n, tuple(es))
                        layers.append(blends[(n, tuple(es))])
                ring_edges = tuple(e for e in range(6) if ring(*neighbor(r, c, e)) == R)
                version = IV[hash((r, c)) % len(IV)]
                if not fell:
                    if d == R:
                        layers.append(wall_band(ring_edges, version))
                    elif d < R:
                        touching = tuple(e for e in range(6) if ring(*neighbor(r, c, e)) >= R)
                        if touching:
                            layers.append(snow_spill(touching))
                elif d == R and (r, c) != town_at:
                    layers.append(rubble(ring_edges, version))
                if (r, c) in road and not ice:
                    layers.append(road[(r, c)])
                ox, oy = c * 56 + (28 if r % 2 else 0), r * 48
                for t in layers:
                    img.alpha_composite(tile_image(t), (ox, oy))
        ox, oy = town_at[1] * 56 + (28 if town_at[0] % 2 else 0), town_at[0] * 48
        img.alpha_composite(town_sprite, (ox - T.SHIFT[0], oy - T.SHIFT[1]))
        return img.crop((14, 8, img.width - 14, img.height - 8))

    standing, fell = scene(False), scene(True)
    sheet = Image.new("RGBA", (standing.width * 2 + 8, standing.height), (40, 40, 48, 255))
    sheet.paste(standing, (0, 0))
    sheet.paste(fell, (standing.width + 8, 0))
    sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST).save(f"qa/fallen_{tag}.png")
    print(f"  wrote qa/fallen_{tag}.png (the wall standing, then fallen)")


def RGBA_OF(c):
    from preview import RGBA
    return RGBA[c] if c else (0, 0, 0, 0)

if __name__ == "__main__":
    {"phase1": phase1, "phase2": phase2, "phase3": phase3, "showcase": showcase,
     "blends": blends, "ui": ui, "slimes": slimes, "hpbar": hpbar, "gear": gear,
     "icewall": icewall, "towns": towns, "caves": caves, "fallen": fallen}[sys.argv[1]](*sys.argv[2:])
