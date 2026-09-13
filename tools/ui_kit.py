"""Cut the game's 9-slice UI sprites out of the Craftpix "2D Pixel UI" pack.

The pack ships finished panels and buttons, not a slice kit, so this is the file that says which
rectangle of which sheet is which sprite and where its nine-slice margins fall. Every margin here
was measured off the pixels, not guessed: a StyleBoxTexture tiles the edge and centre cells, so a
margin is only correct if the rows and columns it leaves in the centre are uniform. `check()` holds
that -- it re-reads each sprite and fails on a single row or column that is not.

Both panels are the pack's own art, cut whole. The one thing that is not is the button: the pack has
one colour and three states, so the danger and disabled faces are palette swaps of it, the way
slimes.py recolours the blue slime -- the ramp is mapped by hue and saturation with the lightness of
each step kept, so a red button is the green button's shading in another key.

Run from the project folder:  python tools/ui_kit.py
Writes Assets/UI/ (the sheet, the loose sprites and ui_sheet.json) and tools/qa/ui_kit_tiling.png.
"""

import colorsys
import json
import os

from PIL import Image

SRC = "Assets/Potential/2D Pixel UI/PNG"
OUT = "Assets/UI"
QA = "tools/qa"
SHEET = "ui_sheet.png"

# name -> (sheet, x, y, w, h, (left, top, right, bottom))
#
# Main_tiles is laid out as a family: four colourways (brown or green header, over a cream or a brown
# body) by three frame weights, plus header-less versions and a set of loose parts. These are the two
# header-less bodies, which is what a plain PanelContainer wants. The pack gives the cream body a
# darker, thicker frame than the brown one -- that is its design, not an oversight, so the two are cut
# at different margins rather than forced to match.
PANELS = {
    "ui_panel_wood": ("Main_tiles", 107, 144, 26, 37, (4, 4, 4, 4)),
    "ui_panel_white": ("Main_tiles", 208, 196, 48, 40, (5, 5, 5, 5)),
    # The green title bar, cut off the headered panel rather than taken with it. The pack draws the
    # bar and its body as one sprite, which fixes the bar at 13 px -- and Pixellari needs 16 px to
    # stay legible, so a fixed 13 px bar could never hold a title. Cut on its own the bar is a
    # nine-slice like any other and grows to whatever the title needs, with the body panel under it.
    "ui_bar_green": ("Main_tiles", 203, 0, 26, 13, (4, 2, 4, 2)),
}

# The blank buttons, four to a row 48 px apart: normal, pressed, hover, hover-pressed. The pack
# draws each one twice, once with a brown drop shadow to stand on wood and once with a bone one to
# stand on the light panel -- which is exactly the project's two button surfaces.
BUTTON_ROW = {"wood": 96, "light": 112}
BUTTON_STATE_X = {"normal": 3, "pressed": 51, "hover": 99}
BUTTON_SIZE = (42, 16)
BUTTON_MARGIN = (4, 5, 4, 4)

# The pack's close button, cut off the green title bar. It draws the same 9x10 icon on every panel
# size and tints it to whatever it sits on -- dark green on a green bar, dark brown on a wood header
# -- so this is the green one, for the green bar. Unlike everything else here it is not a nine-slice:
# the X is drawn, not stretched, so it is placed at its own size and never scaled.
CLOSE = ("Main_tiles", 267, 2, 9, 10)
# The bar's face shows through the button's cut corners, so in the crop those pixels are background.
BAR_FACE = (0x50, 0xA9, 0x78, 0xFF)
# What the pack brightens by on hover, measured off its own button: the face steps #50a978 -> #68c97e
# and the shade #478773 -> #50a978, which is the same lift in lightness to within a rounding. The X's
# frame is its surface darkened, so on hover it is the brighter surface darkened by the same amount.
HOVER_LIFT = 1.22
GREEN_FAMILY = ["#38605b", "#478773"]

# The green face, shading and all, as the pack draws it. Anything not in here -- the outline, the
# drop shadow -- is terrain the recolours leave alone.
GREEN_RAMP = ["#50a978", "#57c767", "#478773", "#6ae356", "#68c97e", "#80e87c", "#a1f28d"]
# The key each recolour plays that ramp in. DANGER is the pack's own red (#c0443a sits between its
# #b82b28 and #d74427); DISABLED is grey, and drops the lightness a little so a dead button reads as
# further away rather than merely paler.
DANGER_HUE, DANGER_SAT = 0.017, 0.55
DISABLED_HUE, DISABLED_SAT, DISABLED_DIM = 0.62, 0.06, 0.80


def _recolor(hue, sat, dim=1.0):
    """A colour map over GREEN_RAMP: the same lightness, another hue and saturation."""
    table = {}
    for text in GREEN_RAMP:
        r, g, b = (int(text[i:i + 2], 16) for i in (1, 3, 5))
        _, light, _ = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        out = colorsys.hls_to_rgb(hue, min(1.0, light * dim), sat)
        table[(r, g, b, 255)] = tuple(round(v * 255) for v in out) + (255,)
    return table


VARIANTS = {
    "normal": {},
    "danger": _recolor(DANGER_HUE, DANGER_SAT),
}
DISABLED = _recolor(DISABLED_HUE, DISABLED_SAT, DISABLED_DIM)


def _lift(colors, factor):
    """A colour map that raises each colour's lightness, keeping its hue and saturation."""
    table = {}
    for text in colors:
        r, g, b = (int(text[i:i + 2], 16) for i in (1, 3, 5))
        hue, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        out = colorsys.hls_to_rgb(hue, min(1.0, light * factor), sat)
        table[(r, g, b, 255)] = tuple(round(v * 255) for v in out) + (255,)
    return table


def _grey(image):
    """Every colour drained to its own lightness, for a dead icon."""
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, alpha = pixels[x, y]
            if alpha == 0:
                continue
            _, light, _ = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            grey = colorsys.hls_to_rgb(DISABLED_HUE, light * DISABLED_DIM, DISABLED_SAT)
            pixels[x, y] = tuple(round(v * 255) for v in grey) + (alpha,)
    return out


def _sink(icon):
    """Pressed, the pack's way: the face drawn a pixel lower with its drop shadow gone."""
    out = Image.new("RGBA", icon.size, (0, 0, 0, 0))
    out.paste(icon.crop((0, 0, icon.width, icon.height - 1)), (0, 1))
    return out


def _cut_out(image, background):
    """The background showing through a cut corner is not part of the sprite."""
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            if pixels[x, y] == background:
                pixels[x, y] = (0, 0, 0, 0)
    return out


def _map_colors(image, table):
    if not table:
        return image.copy()
    out = image.copy()
    pixels = out.load()
    for y in range(out.height):
        for x in range(out.width):
            pixels[x, y] = table.get(pixels[x, y], pixels[x, y])
    return out


def check(name, image, margin):
    """Every row and column a StyleBoxTexture tiles has to be uniform, or the seams show."""
    left, top, right, bottom = margin
    pixels = image.load()
    mid_x = range(left, image.width - right)
    mid_y = range(top, image.height - bottom)
    bad = []
    for y in range(image.height):
        if len({pixels[x, y] for x in mid_x}) > 1:
            bad.append("row %d" % y)
    for x in range(image.width):
        if len({pixels[x, y] for y in mid_y}) > 1:
            bad.append("column %d" % x)
    if bad:
        raise SystemExit("%s does not tile: %s is not one colour" % (name, ", ".join(bad)))


def build():
    sources = {}
    sprites = {}
    margins = {}

    def sheet(name):
        if name not in sources:
            sources[name] = Image.open(os.path.join(SRC, name + ".png")).convert("RGBA")
        return sources[name]

    for name, (src, x, y, w, h, margin) in PANELS.items():
        sprites[name] = sheet(src).crop((x, y, x + w, y + h))
        margins[name] = margin

    w, h = BUTTON_SIZE
    for surface, row in BUTTON_ROW.items():
        for variant, table in VARIANTS.items():
            for state, x in BUTTON_STATE_X.items():
                crop = sheet("Buttons").crop((x, row, x + w, row + h))
                name = "ui_btn_%s_%s_%s" % (surface, variant, state)
                sprites[name] = _map_colors(crop, table)
                margins[name] = BUTTON_MARGIN
            # The pack has no dead face, so it is the normal one drained of colour.
            x = BUTTON_STATE_X["normal"]
            name = "ui_btn_%s_%s_disabled" % (surface, variant)
            sprites[name] = _map_colors(sheet("Buttons").crop((x, row, x + w, row + h)), DISABLED)
            margins[name] = BUTTON_MARGIN

    src, x, y, w, h = CLOSE
    close = _cut_out(sheet("Buttons" if src == "Buttons" else src).crop((x, y, x + w, y + h)), BAR_FACE)
    icons = {
        "ui_close_normal": close,
        "ui_close_hover": _map_colors(close, _lift(GREEN_FAMILY, HOVER_LIFT)),
        "ui_close_pressed": _sink(close),
        "ui_close_disabled": _grey(close),
    }

    # An icon is drawn, never stretched, so it has no margins and nothing to check for tiling.
    for name, image in sprites.items():
        check(name, image, margins[name])
    for name, image in icons.items():
        sprites[name] = image
        margins[name] = (0, 0, 0, 0)
    return sprites, margins


def pack(sprites, margins):
    """One grid, cells as wide and tall as the largest sprite. Panels first, then the buttons."""
    order = sorted(sprites, key=lambda n: (not n.startswith("ui_panel"), n))
    cell_w = max(s.width for s in sprites.values())
    cell_h = max(s.height for s in sprites.values())
    columns = 6
    rows = (len(order) + columns - 1) // columns
    out = Image.new("RGBA", (columns * cell_w, rows * cell_h), (0, 0, 0, 0))
    meta = []
    for i, name in enumerate(order):
        col, row = i % columns, i // columns
        x, y = col * cell_w, row * cell_h
        out.paste(sprites[name], (x, y))
        left, top, right, bottom = margins[name]
        meta.append({
            "name": name, "col": col, "row": row,
            "x": x, "y": y, "w": sprites[name].width, "h": sprites[name].height,
            "margin": {"left": left, "top": top, "right": right, "bottom": bottom},
            "kind": _kind(name),
        })
    return out, meta, (cell_w, cell_h, columns, rows)


def _kind(name):
    if name.startswith("ui_panel") or name.startswith("ui_bar"):
        return "panel"
    return "icon" if name.startswith("ui_close") else "button"


def nine_slice(image, margin, size):
    """What Godot's StyleBoxTexture will draw: corners kept, edges and centre tiled."""
    left, top, right, bottom = margin
    w = max(size[0], left + right + 1)
    h = max(size[1], top + bottom + 1)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cuts_x = [(0, left, 0, left),
              (left, image.width - right, left, w - right),
              (image.width - right, image.width, w - right, w)]
    cuts_y = [(0, top, 0, top),
              (top, image.height - bottom, top, h - bottom),
              (image.height - bottom, image.height, h - bottom, h)]
    for sx0, sx1, dx0, dx1 in cuts_x:
        for sy0, sy1, dy0, dy1 in cuts_y:
            piece = image.crop((sx0, sy0, sx1, sy1))
            if piece.width == 0 or piece.height == 0:
                continue
            for dy in range(dy0, dy1, piece.height):
                for dx in range(dx0, dx1, piece.width):
                    out.alpha_composite(piece.crop((0, 0, min(piece.width, dx1 - dx),
                                                    min(piece.height, dy1 - dy))), (dx, dy))
    return out


def preview(sprites, margins):
    """Every sprite stretched to a few shapes, so a seam has somewhere to show."""
    sizes = [(24, 24), (72, 28), (140, 44), (56, 104)]
    pad = 8
    order = sorted(sprites, key=lambda n: (not n.startswith("ui_panel"), n))
    tall = max(h for _, h in sizes)
    out = Image.new("RGBA", (pad + sum(w + pad for w, _ in sizes), pad + len(order) * (tall + pad)),
                    (0x2A, 0x28, 0x32, 0xFF))
    y = pad
    for name in order:
        x = pad
        if _kind(name) == "icon":
            # Drawn at its own size, over the bar it belongs on, so the cut corners have something
            # to show through.
            for size in sizes:
                bar = nine_slice(sprites["ui_bar_green"], margins["ui_bar_green"], size)
                bar.alpha_composite(sprites[name], (2, max(0, (size[1] - sprites[name].height) // 2)))
                out.alpha_composite(bar, (x, y))
                x += size[0] + pad
        else:
            for size in sizes:
                out.alpha_composite(nine_slice(sprites[name], margins[name], size), (x, y))
                x += size[0] + pad
        y += tall + pad
    return out.resize((out.width * 2, out.height * 2), Image.NEAREST)


def main():
    sprites, margins = build()
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(QA, exist_ok=True)
    preview(sprites, margins).save(os.path.join(QA, "ui_kit_tiling.png"))

    sheet_image, meta, (cell_w, cell_h, columns, rows) = pack(sprites, margins)
    sheet_image.save(os.path.join(OUT, SHEET))
    for name, image in sprites.items():
        image.save(os.path.join(OUT, name + ".png"))
    with open(os.path.join(OUT, "ui_sheet.json"), "w") as f:
        json.dump({
            "meta": {
                "image": SHEET,
                "source": "Assets/Potential/2D Pixel UI (Craftpix; see its License.txt)",
                "cell_size": [cell_w, cell_h],
                "columns": columns,
                "rows": rows,
                "sheet_size": [sheet_image.width, sheet_image.height],
                "nine_slice": "StyleBoxTexture with each sprite's own margin; tile the edges and the"
                              " centre, never stretch them",
                "states": "a Button needs all four styles: normal, hover, pressed, disabled. The pack"
                          " draws pressed a pixel lower with its drop shadow gone, so the sprite"
                          " already holds the sink and the style must not add one",
                "surfaces": "wood buttons sit on ui_panel_wood, light buttons on ui_panel_white",
                "texture_filter": "nearest",
            },
            "sprites": meta,
        }, f, indent=2)
    print("wrote %s (%dx%d, %d sprites) and %s/ui_kit_tiling.png"
          % (SHEET, sheet_image.width, sheet_image.height, len(sprites), QA))


if __name__ == "__main__":
    main()
