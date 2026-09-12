"""PIL previews used only for visual QA (not part of the deliverable)."""
import random

from PIL import Image

from buildlib import ceil_div
from hexlib import H, PALETTE, ROW_OFFSET, STEP_X, STEP_Y, W


def _rgba(hexstr):
    h = hexstr.lstrip("#")
    if len(h) == 8:
        return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4, 6))
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


RGBA = [_rgba(h) for _, h in PALETTE]


def tile_image(tile):
    img = Image.new("RGBA", (getattr(tile, "w", W), getattr(tile, "h", H)))
    img.putdata([RGBA[c] if c else (0, 0, 0, 0) for c in tile.flat()])
    return img


def nine_slice(tile, w, h, cell=8):
    """Stretch a 9-slice sprite to w x h the way Godot's StyleBoxTexture does with
    AXIS_STRETCH_MODE_TILE: corners once, edges and centre repeated in whole `cell` steps."""
    src = tile_image(tile)
    w, h = max(w, 2 * cell), max(h, 2 * cell)
    out = Image.new("RGBA", (w, h))
    mid_w, mid_h = w - 2 * cell, h - 2 * cell
    xs = [(0, cell, 0, cell), (cell, mid_w, cell, cell), (w - cell, cell, 2 * cell, cell)]
    ys = [(0, cell, 0, cell), (cell, mid_h, cell, cell), (h - cell, cell, 2 * cell, cell)]
    for dx, span_w, sx, sw in xs:
        for dy, span_h, sy, sh in ys:
            piece = src.crop((sx, sy, sx + sw, sy + sh))
            for ox in range(0, span_w, sw):                       # repeat, clipping the last step
                for oy in range(0, span_h, sh):
                    box = piece.crop((0, 0, min(sw, span_w - ox), min(sh, span_h - oy)))
                    out.alpha_composite(box, (dx + ox, dy + oy))
    return out


def contact_sheet(tiles, path, cols=8, scale=3, bg=(40, 40, 48, 255)):
    rows = ceil_div(len(tiles), cols)
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
