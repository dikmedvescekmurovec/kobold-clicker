"""The frames round an item's square, one per rarity above common, drawn as letter rows of pixels.

Plain Python, no Godot. Run with no arguments it writes only the preview, `tools/qa/item_frames.png`
(each frame on the tan socket with a piece in it, on cream and on wood, old ring beside it);
`--export` also writes `Assets/UI/item_frame_<rarity>.png`, 40x40 with a clear middle, which is what
`ItemSlot` lays over its socket.

Every colour is a `hexlib.py` hex except lilac's two neighbours and brick's light one, which the palette
does not have. The ramp runs cold to hot -- blue, lilac, brick, gold -- and green is a set's.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIDE = 40
SOCKET = "#cda677"

# Each ramp: o outline, d dark, m the rarity's own colour (ItemRarity.BORDER_COLORS), l light, h glint,
# g the gem set in a unique's corners.
RAMPS = {
    "uncommon": {"o": "#3f6fa6", "d": "#3f6fa6", "m": "#72a8d6", "l": "#acd6ee", "h": "#e8f5fb"},
    "rare": {"o": "#3d2a5e", "d": "#6e4a9a", "m": "#a77fcf", "l": "#d3b8ee", "h": "#f4eedc"},
    "elite": {"o": "#3a2521", "d": "#7a2a36", "m": "#c0443a", "l": "#e58a78", "h": "#efdcaa"},
    "unique": {"o": "#3a2521", "d": "#d57a39", "m": "#e9b640", "l": "#efdcaa", "h": "#f4eedc",
               "g": "#c0443a", "G": "#7a2a36"},
    # A set piece is a unique in every way but its colour: the unique's frame in leaf, its gems amber.
    "set": {"o": "#1b3328", "d": "#58a046", "m": "#86c25a", "l": "#c3de7c", "h": "#f4eedc",
            "g": "#e9b640", "G": "#d57a39"},
}
# The frames that are another's drawing in their own ramp.
SHAPES = {"set": "unique"}

# One corner each, top-left, as letter rows; the other three are this one mirrored. `.` is clear.
CORNERS = {
    # A bevelled ring with its corner pixel cut.
    "uncommon": """
        .ooo
        olll
        olmm
        olmd
    """,
    # The same ring, a stud riveted on each corner.
    "rare": """
        .oooo.
        ollhlo
        olhmmo
        ohmmdo
        olmddo
        .oooo.
    """,
    # A stud, and a bracket of filigree running off it along both edges.
    "elite": """
        .oooo.....
        olhhlooooo
        ohlmmlllmo
        ohmmdoooo.
        olmddo....
        .olooo....
        .olo......
        .olo......
        .omo......
        ..o.......
    """,
    # A gem in a gold claw, the claw's arms curling in along both edges.
    "unique": """
        ..oooo......
        .ohhlloooooo
        ohlggmllllmo
        ohgGgmoooooo
        olggmdo.omo.
        olmmddo..o..
        .oldoo......
        .olo........
        .olo.o......
        .olooo......
        .omom.......
        .ooo........
    """,
}

# What stands in the middle of an edge, pointing in, as letter rows for the TOP edge.
EDGES = {
    "elite": """
        ooooooo
        olhmmdo
        .olmdo.
        ..omo..
        ...o...
    """,
    "unique": """
        ..o.....o..
        .oho.o.oho.
        .olooloolo.
        ollmlhlmllo
        omgmmGmmgmo
        .oddddddo..
        ..oooooo...
    """,
}
# A unique wears its crest on top only and a plain point on the other three.
UNIQUE_POINT = """
    ooooooo
    olhmmdo
    .olgdo.
    ..omo..
    ...o...
"""
# How many rings of solid colour the frame is, outside in, by letter.
RINGS = {"uncommon": "lmd", "rare": "olmd", "elite": "olmd", "unique": "olmdo"}


def _rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _rows(text):
    return [line.strip() for line in text.strip().splitlines()]


def _stamp(art, rows, ramp, x, y):
    for dy, line in enumerate(rows):
        for dx, char in enumerate(line):
            if char != "." and 0 <= x + dx < SIDE and 0 <= y + dy < SIDE:
                art.putpixel((x + dx, y + dy), _rgb(ramp[char]))


def frame(rarity):
    """One rarity's frame on a clear 40x40."""
    ramp = RAMPS[rarity]
    rarity = SHAPES.get(rarity, rarity)
    art = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    rings = RINGS[rarity]
    for inset, char in enumerate(rings):
        # Lit from the top left: the light ring's bottom and right run a step darker.
        for i in range(inset, SIDE - inset):
            shade = {"l": "m", "m": "d"}.get(char, char)
            art.putpixel((i, inset), _rgb(ramp[char]))
            art.putpixel((inset, i), _rgb(ramp[char]))
            art.putpixel((i, SIDE - 1 - inset), _rgb(ramp[shade]))
            art.putpixel((SIDE - 1 - inset, i), _rgb(ramp[shade]))
    if rarity in EDGES:
        top = _rows(EDGES[rarity])
        point = _rows(UNIQUE_POINT) if rarity == "unique" else top
        mark = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
        _stamp(mark, point, ramp, (SIDE - len(point[0])) // 2, 0)
        for turn in (90, 180, 270):
            art.alpha_composite(mark.rotate(turn))
        if rarity == "unique":
            mark = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
            _stamp(mark, top, ramp, (SIDE - len(top[0])) // 2, 0)
        art.alpha_composite(mark)
    corner = Image.new("RGBA", (SIDE, SIDE), (0, 0, 0, 0))
    rows = _rows(CORNERS[rarity])
    # Clear the ring under the corner first, so a cut corner pixel stays cut.
    for dy in range(len(rows)):
        for dx in range(len(rows[0])):
            for fx, fy in ((dx, dy), (SIDE - 1 - dx, dy), (dx, SIDE - 1 - dy), (SIDE - 1 - dx, SIDE - 1 - dy)):
                if dx < len(rings) or dy < len(rings):
                    art.putpixel((fx, fy), (0, 0, 0, 0))
    _stamp(corner, rows, ramp, 0, 0)
    for flip in (corner, corner.transpose(Image.FLIP_LEFT_RIGHT), corner.transpose(Image.FLIP_TOP_BOTTOM),
                 corner.transpose(Image.ROTATE_180)):
        art.alpha_composite(flip)
    return art


def preview():
    pieces = ["Leather Boots", "Wooden Sword", "Wooden Armour", "Gold Ring", "Ruby Amulet"]
    scale, pad = 4, 6
    rarities = list(RAMPS)
    sheet = Image.new("RGBA", ((SIDE + pad) * len(rarities) * 2 + pad, (SIDE + pad) * 2 + pad), _rgb("#f4ecc6"))
    wood = Image.new("RGBA", (sheet.width, SIDE + pad * 2 - pad // 2), _rgb("#825c2f"))
    sheet.alpha_composite(wood, (0, SIDE + pad + pad // 2))
    for col, rarity in enumerate(rarities):
        icon = Image.open(os.path.join(ROOT, "Assets", "Gear", pieces[col] + ".png")).convert("RGBA")
        for row in range(2):
            for old in range(2):
                square = Image.new("RGBA", (SIDE, SIDE), _rgb(SOCKET))
                if old:
                    for inset in range(2):
                        for i in range(inset, SIDE - inset):
                            for at in ((i, inset), (inset, i), (i, SIDE - 1 - inset), (SIDE - 1 - inset, i)):
                                square.putpixel(at, _rgb(RAMPS[rarity]["m"]))
                square.alpha_composite(icon, ((SIDE - icon.width) // 2, (SIDE - icon.height) // 2))
                if not old:
                    square.alpha_composite(frame(rarity))
                sheet.alpha_composite(square, (pad + (col * 2 + (1 - old)) * (SIDE + pad), pad + row * (SIDE + pad)))
    out = os.path.join(ROOT, "tools", "qa", "item_frames.png")
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(out)
    print("wrote", out)


if __name__ == "__main__":
    preview()
    if "--export" in sys.argv:
        for name in RAMPS:
            frame(name).save(os.path.join(ROOT, "Assets", "UI", "item_frame_%s.png" % name))
        print("wrote %d frames to Assets/UI/" % len(RAMPS))
