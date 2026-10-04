"""The frames round an item's square, drawn as letter rows of pixels (the user's design, 2026-10-04).

Every rarity above common wears a thin ring in its colour -- two pixels, lit from the top left, its
corners rounded -- and a cap on each top corner, longer a step up the ladder. A unique wears the
elite's cap in gold, and a crest on the middle of its top edge, a spike on swept wings after League of
Legends' rank borders, which grows with the unique's rank: 0 is a starter, which has no rank (the spike
alone), then I to IV.

Plain Python, no Godot. Run with no arguments it writes only the preview, `tools/qa/item_frames.png`
(every frame on a square on the cream and on the doll's wood, at 4x); `--export` also writes
`Assets/UI/item_frame_<rarity>.png` and `item_frame_unique_<rank>.png`. Each is the square's 40 wide and
`HEAD` taller, the square's top at row `HEAD`: the crest and the caps stand up into the gutter between
two rows of squares, and nothing stands past the sides, where a scroll as wide as the grid would clip
it. `ItemSlot` lays it over its socket `ItemRarity.FRAME_HEAD` above the square.

Every colour is ENDESGA 64's, and each frame still goes through `hexlib.to_e64` with the rest of the
interface.
"""
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SIDE = 40
# How far a frame stands above its square: the crest's tip and the caps' lip. The bag's gutter is 5.
HEAD = 4
# The ring is two pixels wide, its outer corner a quarter circle of this radius.
RING = 2
RADIUS = 3.5
SOCKET = "#e69c69"
CREAM = "#f6ca9f"
WOOD = "#bf6f4a"

# Each ramp: d dark, m the rarity's own colour, l light, h glint, a a stone.
RAMPS = {
    "uncommon": {"d": "#0069aa", "m": "#0098dc", "l": "#00cdf9", "h": "#94fdff", "a": "#94fdff"},
    "rare": {"d": "#622461", "m": "#93388f", "l": "#ca52c9", "h": "#f389f5", "a": "#f389f5"},
    "elite": {"d": "#891e2b", "m": "#c42430", "l": "#ea323c", "h": "#f68187", "a": "#f68187"},
    "unique": {"d": "#c64524", "m": "#ed7614", "l": "#ffa214", "h": "#ffc825", "a": "#ea323c"},
}
# The letters the art is written in: x the rarity, h its light, g a glint, d dark, a a stone.
LETTERS = {"x": "m", "h": "l", "g": "h", "d": "d", "a": "a"}

# The cap on the top-left corner, its rows from y -3 (in the gutter) down and its columns from the
# square's left edge; the top-right is its mirror. Longer arms a step up, a stone from rare, and from
# elite a lip standing up off the corner. A unique wears the elite's.
CAPS = {
    "uncommon": """
        ......
        ......
        hhhd..
        ga....
        hd....
        d.....
    """,
    "rare": """
        ........
        ........
        hhhhhd..
        gax.....
        hx......
        h.......
        hd......
        d.......
    """,
    "elite": """
        ..........
        hh........
        hxhhhhhd..
        gax.......
        hx........
        h.........
        h.........
        hd........
        d.........
    """,
}
CAPS["unique"] = CAPS["elite"]
CAP_TOP = -3

# A unique's crest by rank: its left half, the last column the one beside the middle (x 19, mirrored
# onto x 20), rows y -4 to 3 with the ring's two rows (y 0 and 1) left blank. Each rank adds a piece.
CRESTS = [
    # 0, a starter: the spike alone.
    """
    ............
    ...........h
    ..........hx
    .........hxd
    """,
    # I: the spike on short swept wings.
    """
    ............
    ......h....h
    ......xhh.hx
    .......dxxxd
    """,
    # II: the wings reach out and up, the spike stands taller and its point shows under the line.
    """
    ....h......h
    ....xh....hx
    .....xhh.hxx
    ......dxxxxd
    ............
    ............
    ...........x
    ............
    """,
    # III: a blade out along the line each side, a stone in the spike, the point longer.
    """
    ....h......h
    .h..xh....hx
    .xh..xhh.hax
    ..dx..dxxxad
    ............
    ............
    ...........x
    ...........d
    """,
    # IV: a second blade standing inside each wing, stones in the wings, glints on every tip.
    """
    ....g...g..g
    .g..xh..xh.x
    .xh..xah.hax
    ..dx..dxxxad
    ............
    ............
    ...........x
    ...........a
    """,
]
CREST_TOP = -4


def _rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def _rows(text):
    rows = [line.strip() for line in text.strip().splitlines()]
    assert all(len(row) == len(rows[0]) for row in rows), "ragged art: %s" % rows
    return rows


def _inside(x, y, inset, radius):
    """Whether pixel (x, y)'s middle is inside the square inset by `inset`, its corners rounded."""
    px, py = x + 0.5, y + 0.5
    lo, hi = inset, SIDE - inset
    if not (lo <= px <= hi and lo <= py <= hi):
        return False
    cx, cy = min(max(px, lo + radius), hi - radius), min(max(py, lo + radius), hi - radius)
    return (px - cx) ** 2 + (py - cy) ** 2 <= radius ** 2


def frame(rarity, rank=0):
    """One frame on a clear SIDE x (SIDE + HEAD): `rank` matters only to a unique."""
    ramp = RAMPS[rarity]
    art = Image.new("RGBA", (SIDE, SIDE + HEAD), (0, 0, 0, 0))

    def put(x, y, letter):
        if 0 <= x < SIDE and -HEAD <= y < SIDE:
            art.putpixel((x, y + HEAD), _rgb(ramp[LETTERS[letter]]))

    for y in range(SIDE):
        for x in range(SIDE):
            if not _inside(x, y, 0, RADIUS) or _inside(x, y, RING, RADIUS - RING):
                continue
            # The outer pixel lit on the top and left, dark on the bottom and right; the inner the colour.
            outer = not _inside(x, y, 1, RADIUS - 1)
            lit = min(x, y) < min(SIDE - 1 - x, SIDE - 1 - y)
            put(x, y, ("h" if lit else "d") if outer else "x")
    if rarity == "unique":
        rows = _rows(CRESTS[rank])
        for dy, line in enumerate(rows):
            for j, letter in enumerate(line):
                if letter != ".":
                    out = len(line) - j
                    put(SIDE // 2 - out, CREST_TOP + dy, letter)
                    put(SIDE // 2 - 1 + out, CREST_TOP + dy, letter)
    for dy, line in enumerate(_rows(CAPS[rarity])):
        for x, letter in enumerate(line):
            if letter != ".":
                put(x, CAP_TOP + dy, letter)
                put(SIDE - 1 - x, CAP_TOP + dy, letter)
    # In ENDESGA 64 with the rest of the interface (2026-09-30).
    sys.path.insert(0, os.path.join(ROOT, "AI-sprites-generator"))
    import hexlib
    return hexlib.to_e64(art)


def frames():
    """Every frame the game loads, by file name."""
    made = {"item_frame_%s.png" % rarity: frame(rarity) for rarity in ("uncommon", "rare", "elite")}
    for rank in range(len(CRESTS)):
        made["item_frame_unique_%d.png" % rank] = frame("unique", rank)
    return made


def preview():
    """Each frame on a square with a piece in it, on the cream and on the doll's wood, at 4x."""
    steps = [("common", 0, "Leather Boots"), ("uncommon", 0, "Leather Boots"), ("rare", 0, "Leather Hood"),
             ("elite", 0, "Iron Dagger")]
    steps += [("unique", rank, piece) for rank, piece in enumerate(
        ["gamblers_die", "nightwalkers", "hourglass_amulet", "knucklebone_ring", "packmule"])]
    pad, gap, scale = 8, 10, 4
    sheet = Image.new("RGBA", (pad * 2 + len(steps) * (SIDE + gap) - gap, (SIDE + HEAD + pad) * 2 + pad),
                      _rgb(CREAM))
    sheet.paste(_rgb(WOOD), (0, SIDE + HEAD + pad + pad // 2, sheet.width, sheet.height))
    for row, back in enumerate((CREAM, WOOD)):
        for col, (rarity, rank, piece) in enumerate(steps):
            square = Image.new("RGBA", (SIDE, SIDE + HEAD), (0, 0, 0, 0))
            fill = _rgb(SOCKET)
            if back == WOOD:
                # The doll's sockets are washes over the figure (`ItemRarity.SOCKET_ALPHA`).
                fill = tuple(round(_rgb(WOOD)[i] + (fill[i] - _rgb(WOOD)[i]) * 0.55) for i in range(3)) + (255,)
            for y in range(SIDE):
                for x in range(SIDE):
                    # A framed socket's corners are cut where the ring rounds them; a common's are square.
                    if rarity == "common" or _inside(x, y, 0, RADIUS):
                        square.putpixel((x, y + HEAD), fill)
            folder = os.path.join(ROOT, "Assets", "Gear", "Unique" if rarity == "unique" else "")
            icon = Image.open(os.path.join(folder, piece + ".png")).convert("RGBA")
            square.alpha_composite(icon, ((SIDE - icon.width) // 2, HEAD + (SIDE - icon.height) // 2))
            if rarity == "common":
                for i in range(SIDE):
                    for at in ((i, 0), (0, i), (i, SIDE - 1), (SIDE - 1, i)):
                        square.putpixel((at[0], at[1] + HEAD), _rgb("#8a4836"))
            else:
                square.alpha_composite(frame(rarity, rank))
            sheet.alpha_composite(square, (pad + col * (SIDE + gap), pad + row * (SIDE + HEAD + pad)))
    out = os.path.join(ROOT, "tools", "qa", "item_frames.png")
    sheet.resize((sheet.width * scale, sheet.height * scale), Image.NEAREST).save(out)
    print("wrote", out)


if __name__ == "__main__":
    preview()
    if "--export" in sys.argv:
        for name, image in frames().items():
            image.save(os.path.join(ROOT, "Assets", "UI", name))
        print("wrote %d frames to Assets/UI/" % len(frames()))
