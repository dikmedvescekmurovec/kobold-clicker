"""The pips every bar of them is made of -- the fight's kill bar and a bounty board's postings -- drawn as
letter rows, each lit and spent.

Plain Python and Pillow, no Godot. With no arguments it writes the previews only: `tools/qa/pips.png` (the
fight's bar over three backdrops and a board's heading, put into the game's own screenshots) and
`tools/qa/pips_sheet.png` (every sprite at 8x on cream and on a night sky). `--export` also writes
`Assets/UI/ui_pip_<tier>[_spent].png`, which `KillPips` loads. Run the Godot import after it.

The user's design (2026-10-03, from their sketch): a round pip for the rabble, a skull for an elite and a
crowned skull for a boss, every skull in bone, one size for every bar. The skull is the user's pick of the
first round and the boss wears the "Scowl"'s eyes (the brow drawn down over the sockets). Every sprite is
`WIDTH` across, the round one centred in it, so the round pips stand two pixels apart with no gap between
sprites and a bar's width is arithmetic on its count. A spent pip is its own shape in dark greys, one step
above the ink so a dead skull still shows its face. Drawn at the interface's own pixel, every colour one of
ENDESGA 64.
"""
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
QA = os.path.join(ROOT, "tools", "qa")
OUT = os.path.join(ROOT, "Assets", "UI")
SHOTS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Incremendal Side Scroller")

OUTLINE = "#1c121c"
# Ramps, glint to dark: g h l m d.
RAMPS = {
    "common": {"g": "#f6ca9f", "h": "#e69c69", "l": "#bf6f4a", "m": "#8a4836", "d": "#5d2c28"},
    "bone": {"g": "#ffffff", "h": "#ffffff", "l": "#c7cfdd", "m": "#92a1b9", "d": "#657392"},
    "gold": {"g": "#ffeb57", "h": "#ffc825", "l": "#ffa214", "m": "#ed7614", "d": "#c64524"},
    "red": {"g": "#f68187", "h": "#f5555d", "l": "#ea323c", "m": "#c42430", "d": "#891e2b"},
    # One step lighter than the ink, so a spent skull still shows its eyes and teeth.
    "spent": {"g": "#5d5d5d", "h": "#5d5d5d", "l": "#3d3d3d", "m": "#272727", "d": "#1b1b1b"},
}
RUBY = "#ff0040"
RUBY_SPENT = "#272727"


def rgb(text):
    text = text.lstrip("#")
    return tuple(int(text[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def rows_of(text):
    return [r.strip() for r in text.strip().splitlines()]


def shaded(mask_text):
    """A filled mask, outlined one pixel round and lit from the top left, as letter rows."""
    inside = [[c == "#" for c in r] for r in rows_of(mask_text)]
    h, w = len(inside), len(inside[0])
    out = [["." for _ in range(w + 2)] for _ in range(h + 2)]
    for y in range(h):
        for x in range(w):
            if inside[y][x]:
                u, v = (x - (w - 1) / 2) / ((w - 1) / 2), (y - (h - 1) / 2) / ((h - 1) / 2)
                t = (-u - v) / 2
                out[y + 1][x + 1] = "h" if t > 0.45 else "l" if t > 0.05 else "m" if t > -0.45 else "d"
    out[int(h * 0.25) + 1][int(w * 0.25) + 1] = "g"
    for y in range(h + 2):
        for x in range(w + 2):
            if out[y][x] == "." and any(0 <= y + dy < h + 2 and 0 <= x + dx < w + 2 and out[y + dy][x + dx] not in ".o"
                                        for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0))):
                out[y][x] = "o"
    return ["".join(r) for r in out]


# Letters: `o` and `e` are ink (the outline, a socket); `g h l m d` the main ramp, `G H L M D` the
# accent's (the crown); `r` the crown's ruby; `.` clear.
WIDTH = 9


def centred(rows):
    """Rows padded with clear columns either side to `WIDTH`."""
    pad = WIDTH - len(rows[0])
    return ["." * (pad // 2) + r + "." * (pad - pad // 2) for r in rows]


SHAPES = {
    # The rabble: a round pip, seven across, on the skull's nine.
    "common": centred(shaded("""
        .###.
        #####
        #####
        #####
        .###.
    """)),
    # The user's skull.
    "elite": rows_of("""
        .ooooooo.
        ohhllllmo
        oleeleemo
        oleeleemo
        .olldlmo.
        .olololo.
        ..ooooo..
    """),
    # The skull under a three-pointed gold crown with a ruby in its band, its brow drawn down.
    "boss": rows_of("""
        .o..o..o.
        oHooHooHo
        oHLLrLLMo
        oDDDDDDDo
        ohhllllmo
        olelllemo
        oleeleemo
        .olldlmo.
        .olololo.
        ..ooooo..
    """),
}
# Standing in the tenth place of a bar longer than ten: more are coming. A caret pointing right, in the
# rabble's brown so it reads as part of the row rather than a button.
MORE = centred(rows_of("""
    .oo....
    ohlo...
    .ohlo..
    ..ohlo.
    .ohlo..
    ohlo...
    .oo....
"""))
# Each tier's main ramp; every crown is gold.
MAIN = {"common": "common", "elite": "bone", "boss": "bone"}
TIERS = ("common", "elite", "boss")


def pip(tier, spent=False):
    return draw(SHAPES[tier], MAIN[tier], spent)


def gift(lit):
    return draw(GIFT, "gold", not lit, "red")


def draw(rows, ramp, spent=False, accent_ramp="gold"):
    assert {len(r) for r in rows} == {WIDTH}, "a pip is not %d across" % WIDTH
    main = RAMPS["spent" if spent else ramp]
    accent = RAMPS["spent" if spent else accent_ramp]
    img = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c == ".":
                continue
            colour = (OUTLINE if c in "oe" else (RUBY_SPENT if spent else RUBY) if c == "r"
                      else accent[c.lower()] if c.isupper() else main[c])
            img.putpixel((x, y), rgb(colour))
    return img


def sprites():
    """Every sprite `KillPips` loads, by file name."""
    out = {}
    for tier in TIERS:
        for spent in (False, True):
            out["ui_pip_%s%s" % (tier, "_spent" if spent else "")] = pip(tier, spent)
    out["ui_pip_more"] = draw(MORE, "common")
    out["ui_pip_reward"] = gift(True)
    out["ui_pip_reward_spent"] = gift(False)
    # The round pip in red: on a corner button whose page has something new (the main scene's `_mark_new`).
    out["ui_pip_new"] = draw(SHAPES["common"], "red")
    return out


# --- Previews.
C, E, B = "common", "elite", "boss"


def row_of(images, gap=0):
    """Pips side by side on one centre line, `gap` apart, the way `KillPips` lays them out."""
    height = max(i.height for i in images)
    width = sum(i.width for i in images) + gap * (len(images) - 1)
    out = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    x = 0
    for img in images:
        out.alpha_composite(img, (x, (height - img.height) // 2))
        x += img.width + gap
    return out


# How many pips a bar shows: a longer one shows nine and the caret, `KillPips`' window.
SHOWN = 10


def bar(spec):
    """`spec` as (tier, alive) pairs, left to right, through `KillPips`' window: past `SHOWN`, the nine
    from the first one alive and the caret, until the last ten are in view."""
    if len(spec) > SHOWN:
        start = min(sum(1 for _, alive in spec if not alive), len(spec) - SHOWN)
        if start < len(spec) - SHOWN:
            return row_of([pip(t, not alive) for t, alive in spec[start:start + SHOWN - 1]] + [draw(MORE, "common")])
        spec = spec[start:]
    return row_of([pip(t, not alive) for t, alive in spec])


HUD = [
    ("combat_layout_grass_village_1.png", [(C, False)] * 3 + [(C, True)] * 6 + [(E, True)]),
    ("combat_area_ice_town_4_golden.png", [(C, True)] * 6 + [(E, True)] + [(C, True)] * 7 + [(B, True)]),
    ("combat_area_mountains_plain_2_night.png", [(C, False)] * 3 + [(C, True)] * 3 + [(E, True)] + [(C, True)] * 7 + [(B, True)]),
    ("combat_area_desert_village_3_alpine.png", [(C, False)] * 6 + [(E, False)] + [(C, False)] + [(C, True)] * 6 + [(B, True)]),
]
# A board's heading: none handed in, one, two, and a reward waiting over a fresh board.
BOARD = [(0, False), (1, False), (2, False), (0, True)]
HUD_BOX = (186, 20, 390, 64)
SCALE = 2


def panel_pixels(name):
    shot = Image.open(os.path.join(SHOTS, name)).convert("RGBA")
    return shot.resize((shot.width // 2, shot.height // 2), Image.NEAREST)


def hud_tile(name, drawn):
    """The fight's top-centre column out of a screenshot, its bar and clock drawn again around `drawn`."""
    shot = panel_pixels(name)
    x0, y0, x1, y1 = HUD_BOX
    for y in range(y0, y1):
        # Just right of the character panel, which is clear sky down this whole band.
        sky = shot.getpixel((x0, y))
        for x in range(x0, x1):
            shot.putpixel((x, y), sky)
    left, top = 288 - drawn.width // 2, 24
    shot.alpha_composite(drawn, (left, top))
    draw = ImageDraw.Draw(shot)
    ct = top + drawn.height + 5
    draw.rectangle((left, ct, left + drawn.width - 1, ct + 11), fill=rgb("#131313"))
    draw.rectangle((left + 2, ct + 2, left + drawn.width - 3, ct + 9), fill=rgb("#5ac54f"))
    return shot.crop((x0, 20, x1, 70))


def in_place():
    hud = [hud_tile(n, bar(s)) for n, s in HUD]
    boards = [board_tile(board_row(done, waiting)) for done, waiting in BOARD]
    gap = 12
    hud_w, hud_h = hud[0].size
    board_w, board_h = boards[0].size
    sheet = Image.new("RGBA", ((hud_w * len(hud) + board_w) * SCALE + gap * (len(hud) + 2),
                               max(hud_h, board_h * len(boards)) * SCALE + 2 * gap), rgb("#2a2f4e"))
    x = gap
    for tile in hud:
        sheet.alpha_composite(tile.resize((tile.width * SCALE, tile.height * SCALE), Image.NEAREST), (x, gap))
        x += tile.width * SCALE + gap
    for i, tile in enumerate(boards):
        sheet.alpha_composite(tile.resize((tile.width * SCALE, tile.height * SCALE), Image.NEAREST),
                              (x, gap + i * board_h * SCALE))
    sheet.save(os.path.join(QA, "pips.png"))


def zoomed(made):
    """Every sprite at 8x, lit then spent, on cream and on a night sky."""
    zoom, gap = 8, 10
    rows = [row_of([made["ui_pip_%s%s" % (t, s)] for s in ("", "_spent") for t in TIERS], 3)]
    cell_w = max(r.width for r in rows) + 6
    cell_h = max(r.height for r in rows) + 4
    sheet = Image.new("RGBA", (2 * (cell_w * zoom + gap) + gap, len(rows) * (cell_h * zoom + gap) + gap),
                      rgb("#2a2f4e"))
    for r, strip in enumerate(rows):
        for b, back in enumerate(("#f6ca9f", "#1a1932")):
            cell = Image.new("RGBA", (cell_w, cell_h), rgb(back))
            cell.alpha_composite(strip, (3, (cell_h - strip.height) // 2))
            sheet.alpha_composite(cell.resize((cell_w * zoom, cell_h * zoom), Image.NEAREST),
                                  (gap + b * (cell_w * zoom + gap), gap + r * (cell_h * zoom + gap)))
    sheet.save(os.path.join(QA, "pips_sheet.png"))


# --- What a board's row ends in, in place of its third pip: a gift, a box under a bow with the ribbon
# down its middle (the user's pick, 2026-10-03, over a star, a gem, a trophy, a money bag and a medal;
# a chest was turned down first -- dark, its lid and seam read as an envelope). Gold under a red bow
# while a cleared board's reward waits, the spent greys otherwise, so its shape alone says "reward".
GIFT = rows_of("""
    .ooo.ooo.
    oHHHoHHHo
    .oHHHHHo.
    ooooHoooo
    ohhlHllmo
    ooooHoooo
    ohllHlmdo
    olmmHmmdo
    .ooooooo.
""")


def board_row(done, waiting):
    """A board's row, as `KillPips.show_board` draws it: two round pips lit by how many postings are in,
    and the gift, lit while a reward waits."""
    return row_of([pip(C, i >= done) for i in range(2)] + [gift(waiting)])


def board_tile(drawn):
    """The board's heading row out of `ui_town_board.png`: "Tier I", its rule, and `drawn` at its end."""
    shot = panel_pixels("ui_town_board.png")
    rule = shot.getpixel((460, 95))
    tile = shot.crop((408, 84, 572, 106))
    draw = ImageDraw.Draw(tile)
    draw.rectangle((36, 0, tile.width - 1, tile.height - 1), fill=rgb("#f6ca9f"))
    bx = tile.width - 6 - drawn.width
    tile.alpha_composite(drawn, (bx, 11 - drawn.height // 2))
    draw.line((37, 11, bx - 5, 11), fill=rule)
    return tile


def main():
    os.makedirs(QA, exist_ok=True)
    made = sprites()
    zoomed(made)
    in_place()
    print("wrote %s/pips.png and pips_sheet.png" % QA)
    if "--export" in sys.argv:
        for name, image in made.items():
            image.save(os.path.join(OUT, name + ".png"))
        print("wrote %d pips to %s/" % (len(made), OUT))


if __name__ == "__main__":
    main()
