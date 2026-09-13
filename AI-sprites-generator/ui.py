"""9-slice UI sprites: panels and buttons, 24x24 with 8 px corner cells.

The sprites are rectangular, not hexes, so they use RectTile instead of hexlib.Tile and ship in
their own sheet (see build_ui.py); the hex atlas is never touched.

Nine-slice rule: a StyleBoxTexture with 8 px texture margins repeats the centre cell on both axes,
the top/bottom cells horizontally and the left/right cells vertically. So all interior texture must
be a pure function of (x % CELL, y % CELL), and everything else must be a function of the distance
to the sprite edge and live inside the outer cells. Both hold by construction below: `interior`
paints the periodic fill everywhere, then the rings and bevels overwrite only the outer 1-2 px.
"""
from hexlib import C, DARKER

CELL = 8
SIZE = 3 * CELL

# The four corner pixels stay transparent, so panels and buttons read as slightly rounded.
CHAMFER = [(0, 0), (SIZE - 1, 0), (0, SIZE - 1), (SIZE - 1, SIZE - 1)]


class RectTile:
    """Same name/group/px/flat() contract as hexlib.Tile, on an arbitrary rectangle."""

    def __init__(self, name, group, w=SIZE, h=SIZE):
        self.name = name
        self.group = group
        self.w = w
        self.h = h
        self.px = [[0] * w for _ in range(h)]

    def put(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return 0

    def darken(self, x, y, steps=1):
        c = self.get(x, y)
        for _ in range(steps):
            c = DARKER[c]
        self.put(x, y, c)

    def copy(self, name, group):
        t = RectTile(name, group, self.w, self.h)
        t.px = [row[:] for row in self.px]
        return t

    def flat(self):
        return [c for row in self.px for c in row]


# --------------------------------------------------------------------------- primitives
def fill(t, c, x0=0, y0=0, w=None, h=None):
    for y in range(y0, y0 + (t.h if h is None else h)):
        for x in range(x0, x0 + (t.w if w is None else w)):
            t.put(x, y, c)


def interior(t, paint):
    """paint(lx, ly) -> palette index, with lx/ly the cell-local coordinates (periodic)."""
    for y in range(t.h):
        for x in range(t.w):
            t.put(x, y, paint(x % CELL, y % CELL))


def ring(t, inset, c, chamfer=False):
    """1 px rectangular ring at `inset` from the edge."""
    lo, hi_x, hi_y = inset, t.w - 1 - inset, t.h - 1 - inset
    for x in range(lo, hi_x + 1):
        for y in (lo, hi_y):
            if not (chamfer and (x, y) in CHAMFER):
                t.put(x, y, c)
    for y in range(lo, hi_y + 1):
        for x in (lo, hi_x):
            if not (chamfer and (x, y) in CHAMFER):
                t.put(x, y, c)


def frame(t, c=None):
    """Outer ink border with the corners knocked out."""
    for x, y in CHAMFER:
        t.put(x, y, 0)
    ring(t, 0, C["ink"] if c is None else c, chamfer=True)


def bevel(t, tl, br, inset=1):
    """Light rows/columns on the top and left, dark on the bottom and right (or inverted)."""
    lo, hi_x, hi_y = inset, t.w - 1 - inset, t.h - 1 - inset
    for x in range(lo, hi_x + 1):          # bottom and right first, so the top-left wins the corner
        t.put(x, hi_y, br)
    for y in range(lo, hi_y + 1):
        t.put(hi_x, y, br)
    for x in range(lo, hi_x + 1):
        t.put(x, lo, tl)
    for y in range(lo, hi_y + 1):
        t.put(lo, y, tl)


# --------------------------------------------------------------------------- panels
def panel_white():
    """Paper panel for text and communication: ink outline, bone face, soft inner shadow."""
    t = RectTile("ui_panel_white", "ui")
    fill(t, C["bone"])
    bevel(t, C["bone"], C["mist"])
    frame(t)
    return t


def panel_wood():
    """Wooden container: ink outline, dark inner rim, one plank seam per cell.

    The grain is a single `earth` row and nothing else. A StyleBoxTexture repeats the centre cell, so
    whatever sits in these 8 px becomes a stripe every 8 px all the way down a panel that runs the
    full height of the window: the seam is the one mark that can afford to. The lit row under it, the
    butt-joint marks and the second dark row it used to carry came out as corduroy that the labels on
    the panel had to be read through.
    """
    t = RectTile("ui_panel_wood", "ui")
    interior(t, lambda lx, ly: C["earth"] if ly == 0 else C["soil"])
    ring(t, 1, C["earth_dk"])
    frame(t)
    return t


# --------------------------------------------------------------------------- buttons
# face, top-left bevel, bottom-right bevel, outline, for the normal and hover states. `light` buttons
# sit on the white panel and so have dark faces; `wood` buttons sit on the brown panel and have light
# faces. Pressed is derived from hover, not authored: same face, bevel inverted, so the button keeps
# its hover colour and simply sinks. Disabled drops the bevel for a single flat dull ring and
# collapses the face toward its own backdrop, so it sits in the panel instead of competing.
#
# The palette's only steps above brick are rust and amber, which both skew orange, so the danger
# ramp runs deep red -> bright red (brick_dk -> brick) rather than reaching for them: the face stays
# unmistakably red in every state, and rust appears only as a 1 px lit rim.
FACES = {
    ("wood", "normal"): {
        "normal": ("stone_lt", "mist", "slate", "ink"),
        "hover":  ("mist", "bone", "stone", "ink"),
    },
    ("wood", "danger"): {
        "normal": ("brick_dk", "brick", "earth_dk", "ink"),
        "hover":  ("brick", "rust", "brick_dk", "ink"),
    },
    ("light", "normal"): {
        "normal": ("slate", "stone", "slate_dk", "ink"),
        "hover":  ("stone", "stone_lt", "slate", "ink"),
    },
    ("light", "danger"): {
        "normal": ("brick_dk", "brick", "earth_dk", "ink"),
        "hover":  ("brick", "rust", "brick_dk", "ink"),
    },
}
DISABLED = {                                     # face, flat ring, outline
    ("wood", "normal"): ("soil_lt", "earth", "earth_dk"),
    ("wood", "danger"): ("soil_lt", "brick_dk", "earth_dk"),
    ("light", "normal"): ("stone_lt", "stone", "slate"),
    ("light", "danger"): ("stone_lt", "brick_dk", "slate"),
}
SURFACES = ("wood", "light")
VARIANTS = ("normal", "danger")
STATES = ("normal", "hover", "pressed", "disabled")


def button(surface, variant, state):
    t = RectTile(f"ui_btn_{surface}_{variant}_{state}", "ui")
    if state == "disabled":
        face, flat, outline = DISABLED[(surface, variant)]
        fill(t, C[face])
        bevel(t, C[flat], C[flat])
        frame(t, C[outline])
        return t
    face, tl, br, outline = FACES[(surface, variant)]["normal" if state == "normal" else "hover"]
    fill(t, C[face])
    bevel(t, *((C[tl], C[br]) if state != "pressed" else (C[br], C[tl])))   # pressed inverts the bevel
    frame(t, C[outline])
    return t


# --------------------------------------------------------------------------- collection
def all_ui():
    tiles = [panel_white(), panel_wood()]
    for surface in SURFACES:
        for variant in VARIANTS:
            for state in STATES:
                tiles.append(button(surface, variant, state))
    return tiles


def describe(t):
    """Metadata for the sheet JSON, derived from the sprite name."""
    parts = t.name.split("_")
    if parts[1] == "panel":
        return {"kind": "panel", "surface": parts[2], "variant": "normal", "state": "normal"}
    return {"kind": "button", "surface": parts[2], "variant": parts[3], "state": parts[4]}
