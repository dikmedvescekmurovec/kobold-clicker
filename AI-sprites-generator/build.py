"""Final build: generate all tiles, export indexed PNGs + spritesheet through Aseprite,
write spritesheet JSON metadata, then verify every exported file against the source data."""
import json
import os
import subprocess
from collections import Counter

from PIL import Image

from blends import PRIORITY, all_blends
from hexlib import EDGE_NAMES, H, HEX_PIXELS, PALETTE, ROW_OFFSET, STEP_X, STEP_Y, W, in_hex
from roads import all_roads
from terrain import ADJACENT, all_environments
from towns import all_towns

ASEPRITE = r"C:\Users\Dik\Documents\Git\aseprite\aseprite\build\bin\aseprite.exe"
OUT = r"C:\Users\Dik\Documents\incremendal-side-scroller\AI-sprites"
HERE = os.path.dirname(os.path.abspath(__file__))
SHEET = "hex_tileset.png"
COLS = 12
GROUPS = ("environments", "roads", "towns", "blends")   # appended groups keep earlier atlas coordinates


def describe(t):
    parts = t.name.split("_")
    if t.group == "environments":
        return {"env": parts[1], "variant": parts[2]}
    if t.group == "towns":
        return {"env": parts[1], "tier": parts[2]}
    if t.group == "blends":
        return {"env": t.env, "edges": t.edges}
    pattern, rotation = parts[2:], 0
    if pattern[-1][0] == "r" and pattern[-1][1:].isdigit():
        rotation = int(pattern[-1][1:])
        pattern = pattern[:-1]
    return {"material": parts[1], "pattern": "_".join(pattern), "rotation": rotation, "edges": t.edges}


def main():
    tiles = all_environments() + all_roads() + all_towns() + all_blends()
    names = [t.name for t in tiles]
    assert len(set(names)) == len(names), "duplicate tile names"

    entries, row = [], 0
    for group in GROUPS:
        members = [t for t in tiles if t.group == group]
        for i, t in enumerate(members):
            r, c = row + i // COLS, i % COLS
            entries.append((t, dict(name=t.name, group=group, col=c, row=r, x=c * W, y=r * H,
                                    w=W, h=H, **describe(t))))
        row += (len(members) + COLS - 1) // COLS
    sheet_w, sheet_h = COLS * W, row * H

    palette = [h for _, h in PALETTE]
    data = {"palette": palette, "tile_w": W, "tile_h": H,
            "sheet": {"image": SHEET, "width": sheet_w, "height": sheet_h},
            "tiles": [dict(name=t.name, group=t.group, x=e["x"], y=e["y"], pixels=t.flat()) for t, e in entries]}
    data_path = os.path.join(HERE, "build_data.json")
    with open(data_path, "w") as f:
        json.dump(data, f)

    for sub in GROUPS + ("spritesheet",):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    proc = subprocess.run([ASEPRITE, "-b", "--script-param", f"data={data_path}", "--script-param", f"out={OUT}",
                           "--script", os.path.join(HERE, "emit.lua")], capture_output=True, text=True)
    print("aseprite:", proc.stdout.strip(), proc.stderr.strip(), "exit", proc.returncode)
    assert proc.returncode == 0

    meta = {
        "meta": {
            "image": SHEET, "tile_size": [W, H], "columns": COLS, "rows": row,
            "sheet_size": [sheet_w, sheet_h], "color_mode": "indexed", "transparent_index": 0,
            "palette": palette[1:],
            "hex": {"orientation": "pointy-top", "column_step_px": STEP_X, "row_step_px": STEP_Y,
                    "odd_row_offset_px": ROW_OFFSET,
                    "note": "56x64 near-regular hex; tiles tessellate exactly with these steps"},
            "draw_order": "environment first, then blend overlays in blend_priority order, then road overlay; "
                          "rows top-to-bottom",
            "edge_order": EDGE_NAMES,
            "road_rotation": "rotation k = canonical edges turned clockwise by k*60 degrees; every "
                             "needed orientation is pre-rendered, never rotate sprites in-engine",
            "road_materials": {"dirt": ["grass", "dirt", "forest"], "stone": ["desert", "mountains"],
                               "snow": ["ice"]},
            "env_adjacency": {env: sorted(ADJACENT[env]) for env in ADJACENT},
            "blend_priority": PRIORITY,
            "blend_rule": "on a non-town tile, for each neighbouring env A later in blend_priority than the tile's "
                          "env, draw blend_<A>_<edges> where edges are the sides touching A",
            "accent_frequency": "use env *_accent on roughly 1 in 8-12 tiles of that environment",
            "texture_filter": "nearest",
        },
        "tiles": [e for _, e in entries],
    }
    with open(os.path.join(OUT, "spritesheet", "hex_tileset.json"), "w") as f:
        json.dump(meta, f, indent=2)

    # ---- verification pass
    rgba = [tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) for h in palette]
    sheet = Image.open(os.path.join(OUT, "spritesheet", SHEET))
    spal = sheet.getpalette()
    problems = Counter()

    def mismatch(got, pal, src):
        return sum((g == 0) != (s == 0) or (s and tuple(pal[g * 3:g * 3 + 3]) != rgba[s]) for g, s in zip(got, src))

    for t, e in entries:
        im = Image.open(os.path.join(OUT, t.group, t.name + ".png"))
        problems["not indexed"] += im.mode != "P"
        problems["wrong size"] += im.size != (W, H)
        src = t.flat()
        problems["pixel mismatch"] += mismatch(list(im.get_flattened_data()), im.getpalette(), src)
        crop = sheet.crop((e["x"], e["y"], e["x"] + W, e["y"] + H))
        problems["sheet mismatch"] += mismatch(list(crop.get_flattened_data()), spal, src)
        if t.group not in ("roads", "blends"):
            problems["holes in hex"] += sum(t.px[y][x] == 0 for x, y in HEX_PIXELS)
        problems["outside hex"] += sum(t.px[y][x] != 0 for y in range(H) for x in range(W) if not in_hex(x, y))
    counts = {g: len([f for f in os.listdir(os.path.join(OUT, g)) if f.endswith(".png")]) for g in GROUPS}
    used = sorted({c for t in tiles for c in t.flat() if c})
    print("tiles:", Counter(t.group for t in tiles), "| files on disk:", counts, "| sheet", sheet.size, sheet.mode)
    print("palette indices used:", len(used), "of", len(palette) - 1)
    print("problems:", dict(problems))


if __name__ == "__main__":
    main()
