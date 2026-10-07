"""Writes the ice wall and the frozen wasteland into Assets/Ice/, then reads every file back and checks it.

Like build_hpbar.py this skips Aseprite and the hex atlas: `IceOverlay` draws these itself over the
map, one hex a cell, so they ship as plain RGBA sheets of 56x64 cells (the rubble on the map's own
layer, `HexTileset.RUBBLE_ID`):

  ice_waste.png    WASTE_COLS x WASTE_ROWS: the snow, cell (col, row) at column col % WASTE_COLS, row row % WASTE_ROWS
  ice_band.png     24 x 8: the wall's band between its two ring neighbours, edge mask m (HexGrid.edge_mask)
                   of version v at column m % 8 + 8 v, row m / 8
  ice_spill.png    8 x 8, indexed by edge mask: the snow drifting onto a land tile from the edges that touch ice
  ice_accents.png  ACCENT_KINDS across, 3 versions down: the things lying on the snow
  ice_rubble.png   24 x 8 like ice_band: what is left of a wall once it falls, along its ring, on land

Run `python qa.py icewall <tag>` (and `fallen <tag>` for the rubble) first and look at the images; this overwrites the files.
"""
import os
from collections import Counter
from itertools import combinations

from PIL import Image

import ice_wall as iw
from hexlib import H, W
from preview import tile_image

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "Assets", "Ice")


def _sheet(cols, rows, cells):
    """cells: {(col, row): Tile}"""
    sheet = Image.new("RGBA", (cols * W, rows * H))
    for (c, r), tile in cells.items():
        sheet.alpha_composite(tile_image(tile), (c * W, r * H))
    return sheet


def _by_mask(tiles):
    return _sheet(8, 8, {(mask % 8, mask // 8): tile for mask, tile in tiles.items()})


def ring_masks():
    """The two ring neighbours of a wall cell are either across from each other or two edges apart."""
    return [m for m in combinations(range(6), 2) if (m[1] - m[0]) % 6 in (2, 3, 4)]


def sheets():
    mask = lambda edges: sum(1 << e for e in edges)
    return {
        "ice_waste": _sheet(iw.WASTE_COLS, iw.WASTE_ROWS,
                            {(c, r): iw.waste(c, r) for c in range(iw.WASTE_COLS) for r in range(iw.WASTE_ROWS)}),
        "ice_band": _sheet(8 * len(iw.VARIANTS), 8, {(mask(m) % 8 + 8 * v, mask(m) // 8): iw.wall_band(m, name)
                                                      for m in ring_masks() for v, name in enumerate(iw.VARIANTS)}),
        "ice_spill": _by_mask({mask(m): iw.snow_spill(m) for k in range(1, 7) for m in combinations(range(6), k)}),
        "ice_accents": _sheet(len(iw.ACCENT_KINDS), 3, {(i // 3, i % 3): iw.accent(name)
                                                         for i, name in enumerate(iw.ACCENTS)}),
        "ice_rubble": _sheet(8 * len(iw.VARIANTS), 8, {(mask(m) % 8 + 8 * v, mask(m) // 8): iw.rubble(m, name)
                                                        for m in ring_masks() for v, name in enumerate(iw.VARIANTS)}),
    }


def main():
    made = sheets()
    os.makedirs(OUT, exist_ok=True)
    problems = Counter()
    for name, image in made.items():
        path = os.path.join(OUT, name + ".png")
        image.save(path)
        back = Image.open(path).convert("RGBA")
        problems["wrong size"] += back.size != image.size
        problems["pixel mismatch"] += sum(a != b for a, b in zip(back.get_flattened_data(), image.get_flattened_data()))
        print("  %-12s %4d x %-4d" % (name, *image.size))
    print("written to", os.path.normpath(OUT), "problems:", dict(problems))


if __name__ == "__main__":
    main()
