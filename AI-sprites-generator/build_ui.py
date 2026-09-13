"""Build the 9-slice UI sprites: export indexed PNGs + sheet through Aseprite, write the sheet JSON,
then verify every exported file against the source data.

The UI ships in its own sheet (AI-sprites/ui/) rather than the hex atlas: the sprites are 24x24
rather than 56x64 hexes, and keeping them out of hex_tileset.json means no existing atlas coordinate
ever moves. Run build.py for the hex tiles and this for the UI; they share emit.lua.
"""
import json
import os

from buildlib import HERE, OUT, ceil_div, report, verify, write_and_emit
from hexlib import PALETTE
from ui import CELL, SIZE, all_ui, describe

SHEET = "ui_sheet.png"
GROUP = "ui"
COLS = 6


def main():
    tiles = all_ui()
    names = [t.name for t in tiles]
    assert len(set(names)) == len(names), "duplicate sprite names"
    assert all((t.w, t.h) == (SIZE, SIZE) for t in tiles), "every UI sprite must be SIZE x SIZE"

    entries = []
    for i, t in enumerate(tiles):
        r, c = i // COLS, i % COLS
        entries.append((t, dict(name=t.name, group=GROUP, col=c, row=r, x=c * SIZE, y=r * SIZE,
                                w=t.w, h=t.h, **describe(t))))
    rows = ceil_div(len(tiles), COLS)
    sheet_w, sheet_h = COLS * SIZE, rows * SIZE

    palette = [h for _, h in PALETTE]
    data = {"palette": palette, "tile_w": SIZE, "tile_h": SIZE,
            "sheet": {"image": SHEET, "dir": GROUP, "width": sheet_w, "height": sheet_h},
            "tiles": [dict(name=t.name, group=GROUP, x=e["x"], y=e["y"], w=t.w, h=t.h, pixels=t.flat())
                      for t, e in entries]}
    os.makedirs(os.path.join(OUT, GROUP), exist_ok=True)
    write_and_emit(data, os.path.join(HERE, "build_ui_data.json"))

    meta = {
        "meta": {
            "image": SHEET, "sprite_size": [SIZE, SIZE], "slice": CELL, "min_size": [2 * CELL, 2 * CELL],
            "columns": COLS, "rows": rows, "sheet_size": [sheet_w, sheet_h],
            "color_mode": "indexed", "transparent_index": 0, "palette": palette[1:],
            "nine_slice": "StyleBoxTexture with texture_margin %d on every side; tile the edges and "
                          "centre, never stretch them - the interior art is periodic in %d px"
                          % (CELL, CELL),
            "states": "a Button needs all four styles: normal, hover, pressed, disabled. pressed is "
                      "the hover face with the bevel inverted, so sink the label 1 px with it",
            "surfaces": "wood buttons sit on ui_panel_wood, light buttons on ui_panel_white",
            "texture_filter": "nearest",
        },
        "sprites": [e for _, e in entries],
    }
    with open(os.path.join(OUT, GROUP, "ui_sheet.json"), "w") as f:
        json.dump(meta, f, indent=2)

    # ---- verification pass
    problems, sheet = verify(entries, palette, os.path.join(OUT, GROUP, SHEET),
                             lambda t: os.path.join(OUT, GROUP))
    files = len([f for f in os.listdir(os.path.join(OUT, GROUP)) if f.endswith(".png") and f != SHEET])
    print("sprites:", len(tiles))
    report(problems, palette, tiles, sheet, files)


if __name__ == "__main__":
    main()
