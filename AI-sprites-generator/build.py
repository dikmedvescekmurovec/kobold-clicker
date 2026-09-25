"""Final build: generate all tiles, export indexed PNGs + spritesheet through Aseprite,
write spritesheet JSON metadata, then verify every exported file against the source data."""
import json
import os
from collections import Counter

from blends import PRIORITY, all_blends
from buildlib import HERE, OUT, ceil_div, report, verify, write_and_emit
from hexlib import EDGE_NAMES, H, HEX_PIXELS, PALETTE, ROW_OFFSET, STEP_X, STEP_Y, W, in_hex
from roads import MATERIAL_ENVS, all_roads
from terrain import ADJACENT, all_environments
from towns import all_towns

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
        row += ceil_div(len(members), COLS)
    sheet_w, sheet_h = COLS * W, row * H

    palette = [h for _, h in PALETTE]
    data = {"palette": palette, "tile_w": W, "tile_h": H,
            "sheet": {"image": SHEET, "width": sheet_w, "height": sheet_h},
            "tiles": [dict(name=t.name, group=t.group, x=e["x"], y=e["y"], pixels=t.flat()) for t, e in entries]}
    for sub in GROUPS + ("spritesheet",):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    write_and_emit(data, os.path.join(HERE, "build_data.json"))

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
            "road_materials": MATERIAL_ENVS,
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
    def hex_shape(problems, t):
        # Environments and towns fill the hex; nothing may spill outside it.
        if t.group not in ("roads", "blends"):
            problems["holes in hex"] += sum(t.px[y][x] == 0 for x, y in HEX_PIXELS)
        problems["outside hex"] += sum(t.px[y][x] != 0 for y in range(H) for x in range(W) if not in_hex(x, y))

    problems, sheet = verify(entries, palette, os.path.join(OUT, "spritesheet", SHEET),
                             lambda t: os.path.join(OUT, t.group), hex_shape)
    counts = {g: len([f for f in os.listdir(os.path.join(OUT, g)) if f.endswith(".png")]) for g in GROUPS}
    print("tiles:", Counter(t.group for t in tiles))
    report(problems, palette, tiles, sheet, counts)


if __name__ == "__main__":
    main()
