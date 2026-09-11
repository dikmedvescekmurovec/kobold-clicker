"""PIL previews used only for visual QA (not part of the deliverable)."""
import random

from PIL import Image

from hexlib import H, PALETTE, ROW_OFFSET, STEP_X, STEP_Y, W


def _rgba(hexstr):
    h = hexstr.lstrip("#")
    if len(h) == 8:
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


RGBA = [_rgba(h) for _, h in PALETTE]


def tile_image(tile):
    img = Image.new("RGBA", (W, H))
    img.putdata([RGBA[c] if c else (0, 0, 0, 0) for c in tile.flat()])
    return img


def contact_sheet(tiles, path, cols=8, scale=3, bg=(40, 40, 48, 255)):
    rows = (len(tiles) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * (W + 2), rows * (H + 2)), bg)
    for i, t in enumerate(tiles):
        sheet.alpha_composite(tile_image(t), ((i % cols) * (W + 2) + 1, (i // cols) * (H + 2) + 1))
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(path)


def tiled_image(layers, cols=7, rows=6, seed=1, bg=(20, 20, 24, 255)):
    """layers: callables (row, col, rng) -> list of Tiles stacked at that cell, drawn row by row."""
    rng = random.Random(seed)
    img = Image.new("RGBA", (cols * STEP_X + ROW_OFFSET, rows * STEP_Y + (H - STEP_Y)), bg)
    for r in range(rows):
        for c in range(cols):
            ox, oy = c * STEP_X + (ROW_OFFSET if r % 2 else 0), r * STEP_Y
            for layer in layers:
                for t in layer(r, c, rng):
                    img.alpha_composite(tile_image(t), (ox, oy))
    return img


def tiled_map(layers, path, cols=7, rows=6, scale=2, seed=1, bg=(20, 20, 24, 255)):
    img = tiled_image(layers, cols, rows, seed, bg)
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(path)
