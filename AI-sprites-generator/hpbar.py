"""The combat nameplate's health bar: a bordered trough, drawn rather than cut.

This is the one piece of interface the generator draws. Everything else in Assets/UI comes off the
bought Craftpix pack through tools/ui_kit.py, and this would too if the pack held it: it does not.
Pixel UI pack 3 ships flat capsules (06.png, which the kill pips are cut from -- its three tier bands
differ only in colour) and sheared glossy bars (04.png, already on disk as Assets/bars.png and
already turned down by CombatScene._bar for being "a glossier style than the rest of the
interface"). Neither has an elite's frame or a boss's, which is the whole point of this bar.

Like slimes.py this skips Aseprite and the hex atlas: the parts ship as ordinary RGBA PNGs under
Assets/UI/, loose, the way the pip parts do. They are drawn at their own size and never stretched,
so they have no nine-slice and no business in ui_sheet.png.

The bar is three parts butted together at runtime -- a left cap, a run of track, a right cap -- for
the same reason the pip bar is: one sprite would fix its length. Scenes/UI/health_bar.gd assembles
them and lays the red fill over the channel, which stays a drawn rectangle so it can be any width to
the pixel.

Geometry, 8 rows, the same in every tier:

    y0       ink frame
    y1       the tier's lit rim
    y2 - y5  the channel, where the fill goes
    y6       the tier's shadow rim
    y7       ink frame

and the tiers differ only in the frame around that channel. The trough is EXACTLY as long in all
three -- a cap's last column is a channel column, so the channel is always 1 + SEGMENTS*4 + 1 wide
however wide the caps are. What grows is the ornament, outward: an elite's bar is wider overall than
a common's and a boss's wider still, which is the threat read twice, once in the gold and once in
the size.
"""
import os

from PIL import Image

from hexlib import PALETTE

## How many track pieces stand between the two caps. The channel comes to 2 + 4 * SEGMENTS px, which
## at health_bar.gd's PIXEL of 2 is the width the nameplate's bar has always been drawn at.
SEGMENTS = 13
HEIGHT = 8

_PAL = {n: tuple(int(h.lstrip("#")[i:i + 2], 16) for i in (0, 2, 4)) + (255,) for n, h in PALETTE[1:]}
CLEAR = (0, 0, 0, 0)

## The legend the art below is written in. Five of the eight are the same palette entry in every tier
## -- a frame is a frame -- and five take the tier's own, which is what "which colourway is which
## tier" means here. The names match the pip bar's reading: brown common, green elite, gold boss.
##
##   K  ink frame          D  the channel (covered by the fill)
##   T  lit rim            U  shadow rim
##   V  ornament outline   G  ornament body      H  ornament highlight
##   .  transparent
SHARED = {"K": "ink", "D": "earth_dk"}
TIERS = {
    "common": {"T": "soil_lt", "U": "earth",   "G": "soil",  "H": "soil_lt"},
    "elite":  {"T": "leaf_lt", "U": "leaf_dk", "G": "leaf",  "H": "leaf_hi"},
    "boss":   {"T": "amber",   "U": "rust",    "G": "amber", "H": "sand_lt"},
}

## One piece of track per tier. The channel rows are bare in all three -- the fill covers them -- so
## the rails above and below it are the only place a run of track can say anything, and that is where
## the tiers part company along the bar's length rather than only at its ends. A common's rail is one
## smooth run; an elite's is divided into links; a boss's is beaded as well as divided. The piece
## repeats every 4 px, so whatever is written here becomes the rhythm of the whole bar.
TRACKS = {
    "common": [
        "KKKK",
        "TTTT",
        "DDDD",
        "DDDD",
        "DDDD",
        "DDDD",
        "UUUU",
        "KKKK",
    ],
    "elite": [
        "KKKK",
        "TTTV",
        "DDDD",
        "DDDD",
        "DDDD",
        "DDDD",
        "UUUV",
        "KKKK",
    ],
    "boss": [
        "KKKK",
        "THTV",
        "DDDD",
        "DDDD",
        "DDDD",
        "DDDD",
        "UHUV",
        "KKKK",
    ],
}

## The left cap of each tier. The rightmost three columns are the cap proper in all three -- two ink
## columns of wall and one channel column -- and everything left of that is ornament. The outer
## corners are knocked out so the bar reads as slightly rounded, the way the pack rounds its own.
##
## Common is the wall and nothing else: a border around a bar, which is what a common is.
## Elite brackets a cut green gem into the end -- a pointed stone in an ink surround, top and bottom
## barred, so the end reads as fitted rather than decorated.
## Boss opens that into a three-pronged gold crown: the prongs are separated by ink all the way down,
## which is what carries the silhouette at this size -- a solid gold lump would read as a blob, and
## what makes a shape look worked is the line through it, not the number of colours in it.
CAPS = {
    "common": [
        ".KK",
        "KKT",
        "KKD",
        "KKD",
        "KKD",
        "KKD",
        "KKU",
        ".KK",
    ],
    "elite": [
        "...VVVVKK",
        "..VGHVKKT",
        ".VGHHVKKD",
        "VGHHHVKKD",
        "VGHHHVKKD",
        ".VGHHVKKD",
        "..VGHVKKU",
        "...VVVVKK",
    ],
    "boss": [
        "...V.V.VVVVKK",
        "..VGVGVGGVKKT",
        ".VGHGGGGGVKKD",
        "VGHGGGGGGVKKD",
        "VGGGGGGGGVKKD",
        ".VGGGGGGGVKKD",
        "..VGVGVGGVKKU",
        "...V.V.VVVVKK",
    ],
}


def _image(rows, tier):
    """One part, from its art and the tier's colours."""
    legend = dict(SHARED)
    legend.update(TIERS[tier])
    # The ornament's outline is the frame's ink, not a colour of its own: a gem set into a bar is
    # bounded by the bar's own line, or it reads as a sticker laid over it.
    legend["V"] = "ink"
    width = len(rows[0])
    out = Image.new("RGBA", (width, HEIGHT), CLEAR)
    pixels = out.load()
    for y, row in enumerate(rows):
        if len(row) != width:
            raise SystemExit("%s row %d is %d wide, not %d" % (tier, y, len(row), width))
        for x, ch in enumerate(row):
            pixels[x, y] = CLEAR if ch == "." else _PAL[legend[ch]]
    return out


def _mirror(image):
    """The right cap is the left one flipped. The rims are rows, so they come through untouched."""
    return image.transpose(Image.FLIP_LEFT_RIGHT)


def parts():
    """Every part the game loads, as {name: RGBA image}."""
    out = {}
    for tier in TIERS:
        cap = _image(CAPS[tier], tier)
        out["ui_hpbar_cap_l_" + tier] = cap
        out["ui_hpbar_cap_r_" + tier] = _mirror(cap)
        out["ui_hpbar_track_" + tier] = _image(TRACKS[tier], tier)
    return out


def cap_width(tier):
    return len(CAPS[tier][0])


def trough():
    """How many pixels of channel the fill has, which is the same number in every tier."""
    return 2 + 4 * SEGMENTS


def bar(tier, share, made=None, fill=(196, 69, 58, 255)):
    """The assembled bar at `share` full, exactly as health_bar.gd butts it together.

    The fill is passed in rather than drawn from the palette because the game draws it: it is a
    ColorRect in CombatScene.BAR_HEALTH, so it can be any width to the pixel instead of arriving in
    the fixed steps a sprite fill would.
    """
    made = parts() if made is None else made
    cap_l = made["ui_hpbar_cap_l_" + tier]
    cap_r = made["ui_hpbar_cap_r_" + tier]
    track = made["ui_hpbar_track_" + tier]
    width = cap_l.width + SEGMENTS * track.width + cap_r.width
    out = Image.new("RGBA", (width, HEIGHT), CLEAR)
    out.alpha_composite(cap_l, (0, 0))
    for i in range(SEGMENTS):
        out.alpha_composite(track, (cap_l.width + i * track.width, 0))
    out.alpha_composite(cap_r, (cap_l.width + SEGMENTS * track.width, 0))
    # The channel starts on the cap's last column and runs the same 2 + 4 * SEGMENTS in every tier.
    filled = max(0, min(trough(), round(trough() * share)))
    if filled:
        out.alpha_composite(Image.new("RGBA", (filled, 4), fill), (cap_l.width - 1, 2))
    return out


def names():
    return sorted(parts())
