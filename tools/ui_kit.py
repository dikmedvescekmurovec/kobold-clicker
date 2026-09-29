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
import io
import json
import os
import sys
import zipfile

from PIL import Image, ImageDraw

SRC = "Assets/Potential/2D Pixel UI/PNG"
POTENTIAL = "Assets/Potential"
OUT = "Assets/UI"
GEAR_OUT = "Assets/Gear"
ORB_OUT = "Assets/Orbs"
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
# The cream body as it stands *under* the bar in the pack's own composed panels (Inventory.png, the
# blank one at x 7..104): the pack draws bar and body as one sprite, and under the bar there is no
# frame at all -- one dark-green drop line, one tan row, then cream. ui_panel_white stacked under the
# bar put its full top frame there, and the bar's dark bottom over the frame's dark top read as a
# thick seam under every title. This one is assembled from that panel's notch-free stretches: left
# and right bands of columns x0..x1, and the rows of each band (top, middle, bottom) -- the notches
# and the edge's colour shifts (see NOTCHES) lie between them. margin (left, top, right, bottom).
HEADED = ("ui_panel_headed", "Inventory", [(7, 19), (93, 105)], [(13, 16), (48, 64), (95, 101)],
          (5, 3, 5, 6))

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
# BROWN is the pack's own square button, read off it: the pack draws one at Buttons.png (336, 339),
# 11x12, in four states on a 16 px pitch -- and that sprite cannot be used. Its face is a diagonal
# gradient, so no margin leaves a centre flat enough for check() to pass, and at 11x12 it could not
# hold a 12 px icon anyway. What it is good for is its colour: this hue and saturation, at 0.62 of
# the green face's lightness. Played on the green button's flat, tileable face the base step comes
# out #714c2a against the pack's own #70492a -- the pack's brown square, on a face that nine-slices.
BROWN_HUE, BROWN_SAT, BROWN_DIM = 0.08, 0.46, 0.62

# The gear icons are not theme sprites: they go to Assets/Gear as loose PNGs for LootTable.ROOT to
# load by path, and never enter ui_sheet.png or ui_sheet.json. They are assembled here all the same
# (BASE_KINDS, UNIQUE_GEAR), because this is the file that records which rectangle of which bought
# sheet is which sprite, and a second script saying the same thing a second way is how the two drift
# apart. The table that stood here, GEAR, wrote the first four -- two of them a ring and an amulet
# doubled off Icons.png -- and is gone: every base is BASE_KINDS' now, and a second table writing
# the same file names after it would put a bordered or a doubled copy back over the finished one.
#
# a source 6-tuple: (sheet under Assets/Potential, x, y, w, h, scale); see _cut for a sheet in a zip
# Every gear icon is drawn on a square of this side, centred, because ItemSlot draws a fixed 32x32
# rect and a test holds every icon to it.
GEAR_SIDE = 32
# The lightest a recoloured pixel may come out. It was set when every icon wore the pack's white
# border, which had to stay the lightest thing in the sprite; the border is ink now (_outlined), and
# what the ceiling still does is keep a lifted recolour -- glass, bleached bone -- from burning out
# to paper white on the socket.
GREY_CEILING = 0.88
# The lightest the outline ink may be: see _outlined.
OUTLINE_INK = 0.16
# The least of an icon's edge that has to be that ink for a base to be written or shown. Not 1.0:
# the pack leaves the odd edge pixel out of its border, one or two an icon.
OUTLINE_FLOOR = 0.97
_FOUR = ((1, 0), (-1, 0), (0, 1), (0, -1))
_EIGHT = _FOUR + ((1, 1), (1, -1), (-1, 1), (-1, -1))

# The unique items' icons, keyed by `UniqueTable`'s ids and written to Assets/Gear/Unique: every one is
# the user's own pixellab piece.
#
# id -> (a source 6-tuple, [(hue_low, hue_high, hue_add, sat_mul, light_mul), ...][, (grey_hue, grey_sat)])
# The recolour list names the band of hues `_shift` moves, what it adds to the hue, and what it
# multiplies the saturation and the lightness by: a part, never the whole sprite.
_RPG = "Pixel Art Icon Pack - RPG/"
# The user's own 32 px pixellab pieces, one file an id. They come with an outline of their own, which
# `_outlined(own_edge=True)` repaints in ink where it stands: a ring added outside would not fit 32.
PIXELLAB = "Unique/"
# Pixellab paints near-pure accents where the packs grey theirs down, so a piece's saturation is scaled
# (never clamped: a gem's shades stay apart) until 90% of its pixels are at most this -- the bases' own
# 90th percentile (0.68, measured off Assets/Gear, outline left out) lowered by eye: 0.60 still read loud
# once all 27 were pixellab, 0.40 faded into the socket, 0.50 was chosen.
SAT_CEILING = 0.50
_PIXELLAB_IDS = [
    "metronome", "headsman", "knucklebone_ring", "the_tithe", "hourglass_amulet", "meadowstriders", "hunters_lantern",
    "sunscorched_cowl", "rimeplate", "stonebreaker", "gravediggers_charm", "berserkers_band", "glass_edge",
    "gamblers_die", "ascetics_cord", "last_gasp", "duelists_buckler", "overflowing_chalice", "dominoes",
    "snowball", "packmule", "bulwark", "heartwood_plate", "spiked_helm", "magpies_band", "lucky_wound",
    "rag_and_bone_sack", "serpents_eye",
    # The attribute uniques (2026-09-28).
    "ogres_knuckle", "fencers_signet", "scholars_circlet", "sages_abacus", "crown_of_accord", "zealots_brand",
    "patchwork_coat", "purists_seal", "brawlers_wraps", "butchers_cleaver", "quickdraw_boots", "heirlooms_echo",
    # The starters (2026-09-28).
    "squires_blade", "wayfarers_torch", "novices_cap", "couriers_boots", "beginners_luck", "worry_stone",
]
# The uniques whose fire is kept as drawn, as BASE_FIRE keeps a torch's: `_muted` paled the Wayfarer's
# Torch's flame pink. No glow, which would smudge the collection log's black outline.
UNIQUE_FIRE = {"wayfarers_torch"}
UNIQUE_GEAR = {name: ((PIXELLAB + name, 0, 0, 32, 32, 1), []) for name in _PIXELLAB_IDS}
UNIQUE_OUT = "Assets/Gear/Unique"
# What the pixellab pieces replaced, still written beside them for the settings' dev tick "Show old
# unique icons" (`UniqueTable.icon`): RPG pack pieces, and the ten the generator draws.
UNIQUE_OLD = {
    "metronome": ((_RPG + "Weapon & Tool/Silver Sword", 0, 0, 32, 32, 1), []),
    "headsman": ((_RPG + "Weapon & Tool/Axe", 0, 0, 32, 32, 1), []),
    "stonebreaker": ((_RPG + "Weapon & Tool/Hammer", 0, 0, 32, 32, 1), []),
    "glass_edge": ((_RPG + "Weapon & Tool/Iron Sword", 0, 0, 32, 32, 1), [], (0.55, 0.5)),
    "sunscorched_cowl": ((_RPG + "Equipment/Helm", 0, 0, 32, 32, 1), []),
    # The nearest thing to a chalice running over.
    "overflowing_chalice": ((_RPG + "Food/Beer", 0, 0, 32, 32, 1), []),
    # The pack calls this strapped pack its leather armour.
    "rag_and_bone_sack": ((_RPG + "Equipment/Leather Armor", 0, 0, 32, 32, 1), []),
    "meadowstriders": ((_RPG + "Equipment/Iron Boot", 0, 0, 32, 32, 1), []),
    "rimeplate": ((_RPG + "Equipment/Iron Armor", 0, 0, 32, 32, 1), []),
    "ascetics_cord": ((_RPG + "Material/Rope", 0, 0, 32, 32, 1), []),
    "last_gasp": ((_RPG + "Monster Part/Skull", 0, 0, 32, 32, 1), []),
    "duelists_buckler": ((_RPG + "Weapon & Tool/Iron Shield", 0, 0, 32, 32, 1), []),
    "packmule": ((_RPG + "Equipment/Bag", 0, 0, 32, 32, 1), []),
    # The base piece's own wood, stained to the red of the heart of the tree.
    "heartwood_plate": ((_RPG + "Equipment/Wooden Armor", 0, 0, 32, 32, 1), [(0.0, 0.2, -0.06, 1.35, 0.8)]),
    "spiked_helm": ((_RPG + "Equipment/Iron Helmet", 0, 0, 32, 32, 1), []),
    "lucky_wound": ((_RPG + "Misc/Candle", 0, 0, 32, 32, 1), []),
    "hunters_lantern": ((_RPG + "Misc/Lantern", 0, 0, 32, 32, 1), []),
}
# The old ones AI-sprites-generator/gear.py draws (its UNIQUES, by the same ids): what replaced the
# doubled Icons.png art, until the pixellab pieces replaced them in turn.
UNIQUE_OLD_DRAWN = ["knucklebone_ring", "the_tithe", "berserkers_band", "magpies_band", "hourglass_amulet",
                    "gravediggers_charm", "gamblers_die", "dominoes", "snowball", "bulwark"]
UNIQUE_OLD_OUT = UNIQUE_OUT + "/Old"
# Whether the icons are written into the game or only onto the preview. Off until the preview has been
# looked at: `UniqueTable.icon` falls back to the base piece's picture while a file is missing.
UNIQUE_EXPORT = True

# The item bases: fifteen kinds a slot can draw, each in four tiers, plus the torch's two and the
# seven pieces of jewellery. Sixty-nine names in all.
#
# The user chose one look for all of them -- the RPG pack's, which is what the leather and wooden
# pieces the game shipped with are -- and asked two more things of it: no white border, and a higher
# tier that is a more intricate *drawing*, not the same one in another colour. So a cell here comes
# from one of two places and both end the same way, through `_outlined`:
#
#   a 6-tuple  cut from the pack, where it draws the right object at its own resolution. The six
#              leather and wooden pieces the game shipped with are these too, cut from the pack
#              again rather than read back out of Assets/Gear: a build that reads what it wrote
#              outlines an outline on its second run. Two of them, the sword and the shield, are
#              not among the unpacked files any more and come straight out of the pack's zip;
#   DRAWN      generated by AI-sprites-generator/gear.py in the pack's look, measured off the pack
#              (see gearlib.py). The pack draws about twenty pieces of gear, so this is most cells,
#              and it is every ring and amulet: the two on disk are 12 px art doubled, which is the
#              other thing this sheet was sent back for, so they are replaced with the rest.
#
# Two rounds before this one recoloured a single silhouette per kind (`MATERIALS`, `_tighten`) and
# filled the gaps from the Raven Fantasy Icons pack and Icons.png. Both were turned down. Raven's
# 32x32.png is its 16x16.png doubled pixel for pixel, so beside the RPG pack's 1 px art it reads as
# another game, exactly as the doubled Icons.png jewels did; and four colours of one drawing do not
# say four tiers. `_doubled` is asked of every cell now and a build stops on a yes.
#
# A unique may share its base's picture, as it would in the game this borrows its items from: the
# pack's Iron Helmet, Helm, Iron Armor and Iron Boot are also spiked_helm, sunscorched_cowl,
# rimeplate and meadowstriders, which wear a gold frame and a name of their own. Where the pack has
# a second drawing to give the base instead it does -- the shield is drawn, because the pack's one
# shield is duelists_buckler.
#
# kind -> (slot, [(item name, source[, tint]), ...])
DRAWN = "drawn"
# A piece with no art yet: the "!" below, on the square every base stands on, so the game shows the
# gap rather than hiding it. Swapped for a source as the user's art arrives. The masterworks are
# made a piece at a time this way (tools/DESIGN.md, *Pixellab prompts*).
MISSING = "missing"
MISSING_MARK = """
    .ooooo.
    ollccco
    olcccco
    olcccco
    olcccco
    .olccco
    .olcco.
    .olcco.
    .olcco.
    .olcco.
    .olcco.
    ..olco.
    ..olco.
    ..oooo.
    .......
    .......
    ..ooo..
    .olcco.
    .occco.
    ..ooo..
"""
# The user's own pixellab bases, one file an item, finished like the pixellab uniques (`_muted`, then
# `_outlined(own_edge=True)`). They are being made a kind at a time: tools/DESIGN.md, *Pixellab prompts*.
PIXELLAB_BASES = "Bases/"
# Pixellab pieces stretched until their longer side fills the square, before they are finished: on the doll a
# piece that came back small looks lighter than the pieces beside it (the user's call, 2026-09-23). Nearest-neighbour
# at a small factor (the Wooden Armor is x1.19), so a few rows and columns are doubled; kept to the pieces that need it.
BASE_FILL = {"Wooden Armor", "Iron Armor", "Steel Plate", "Golden Plate", "Masterwork Plate",
             "Hide Jerkin", "Leather Jerkin", "Studded Jerkin", "Shadow Leathers", "Masterwork Jerkin"}
# Pixellab sometimes leaves a seam as a see-through slit (the Masterwork Plate had a 2 px and a 3 px one between its
# shoulder guards and chest, 2026-09-23): an enclosed clear patch this small or smaller is filled (`_plugged`). The
# holes a drawing means -- the gap between a pair of boots, a ring's middle -- are far bigger.
BASE_HOLE_MOST = 4
# Every dagger points its tip to the bottom-left, the other way from every sword, so the two read apart at a glance (the
# user's call, 2026-09-24). A pixellab piece that came back tip up-right is mirrored across the top-left diagonal, which
# keeps the light on its upper-left; the source file stays as drawn.
BASE_TRANSPOSE = {"Bone Knife", "Masterwork Dagger"}
# The torches' fire (2026-09-24). `_muted` scales a piece by its most saturated tenth, which on a torch is the flame,
# so every flame came out pale pink: the flame (`_fire`) is left as drawn and only the rest is muted. And the user
# asked for a glow round every flame, which pixellab never drew, so `_glowed` adds it after the outline: apricot
# (the charts' #f5ac5d) at these two alphas on the two pixels outside the flame.
BASE_FIRE = {"Wooden Torch", "Blazing Torch", "Masterwork Torch", "Broken Torch"}
FIRE_GLOW = (245, 172, 93)
FIRE_GLOW_ALPHAS = (150, 70)
_RPG_ZIP = "Pixel Art Icon Pack - RPG.zip!"
BASE_KINDS = {
    # All five the user's pixellab swords (2026-09-24), one silhouette at five strengths; what they replaced -- the
    # pack's wooden, iron and golden swords and the generator's steel one -- is in BASE_OLD.
    "sword": ("Weapon", [
        ("Wooden Sword", (PIXELLAB_BASES + "Wooden Sword", 0, 0, 32, 32, 1)), ("Iron Sword", (PIXELLAB_BASES + "Iron Sword", 0, 0, 32, 32, 1)),
        ("Steel Sword", (PIXELLAB_BASES + "Steel Sword", 0, 0, 32, 32, 1)), ("Golden Sword", (PIXELLAB_BASES + "Golden Sword", 0, 0, 32, 32, 1)),
        ("Masterwork Sword", (PIXELLAB_BASES + "Masterwork Sword", 0, 0, 32, 32, 1))]),
    # The user's pixellab daggers (2026-09-24), told from the swords by pointing the other way (BASE_TRANSPOSE); the
    # generator's four they replaced are in BASE_OLD.
    "dagger": ("Weapon", [
        ("Bone Knife", (PIXELLAB_BASES + "Bone Knife", 0, 0, 32, 32, 1)), ("Iron Dagger", (PIXELLAB_BASES + "Iron Dagger", 0, 0, 32, 32, 1)),
        ("Steel Stiletto", (PIXELLAB_BASES + "Steel Stiletto", 0, 0, 32, 32, 1)),
        ("Golden Kris", (PIXELLAB_BASES + "Golden Kris", 0, 0, 32, 32, 1)),
        ("Masterwork Dagger", (PIXELLAB_BASES + "Masterwork Dagger", 0, 0, 32, 32, 1))]),
    # The user's pixellab maces (2026-09-24); the generator's four they replaced are in BASE_OLD. The Iron Mace is a
    # grey morningstar from the steel tries, picked by the user for the iron.
    "mace": ("Weapon", [
        ("Wooden Club", (PIXELLAB_BASES + "Wooden Club", 0, 0, 32, 32, 1)), ("Iron Mace", (PIXELLAB_BASES + "Iron Mace", 0, 0, 32, 32, 1)),
        ("Steel Morningstar", (PIXELLAB_BASES + "Steel Morningstar", 0, 0, 32, 32, 1)),
        ("Golden Sceptre", (PIXELLAB_BASES + "Golden Sceptre", 0, 0, 32, 32, 1)),
        ("Masterwork Mace", (PIXELLAB_BASES + "Masterwork Mace", 0, 0, 32, 32, 1))]),
    # The user's pixellab greatsword line (2026-09-24), built on the Masterwork's blade that widens to a broad slanted
    # tip; the generator's four they replaced are in BASE_OLD.
    "greatsword": ("Weapon", [
        ("Wooden Greatsword", (PIXELLAB_BASES + "Wooden Greatsword", 0, 0, 32, 32, 1)),
        ("Iron Claymore", (PIXELLAB_BASES + "Iron Claymore", 0, 0, 32, 32, 1)),
        ("Steel Zweihander", (PIXELLAB_BASES + "Steel Zweihander", 0, 0, 32, 32, 1)),
        ("Golden Greatsword", (PIXELLAB_BASES + "Golden Greatsword", 0, 0, 32, 32, 1)),
        ("Masterwork Greatsword", (PIXELLAB_BASES + "Masterwork Greatsword", 0, 0, 32, 32, 1))]),
    # The player's first find (LootTable.FIRST_DROP), which wore the Wooden Sword's picture until the user drew it one
    # (2026-09-24).
    "broken_sword": ("Weapon", [("Broken Sword", (PIXELLAB_BASES + "Broken Sword", 0, 0, 32, 32, 1))]),

    # The user's pixellab shields (2026-09-24): one heater at five strengths, each material a device of its own on the
    # face; the pack's wooden one and the generator's three are in BASE_OLD.
    "shield": ("Offhand", [
        ("Wooden Shield", (PIXELLAB_BASES + "Wooden Shield", 0, 0, 32, 32, 1)), ("Iron Shield", (PIXELLAB_BASES + "Iron Shield", 0, 0, 32, 32, 1)),
        ("Steel Kite Shield", (PIXELLAB_BASES + "Steel Kite Shield", 0, 0, 32, 32, 1)),
        ("Golden Aegis", (PIXELLAB_BASES + "Golden Aegis", 0, 0, 32, 32, 1)),
        ("Masterwork Shield", (PIXELLAB_BASES + "Masterwork Shield", 0, 0, 32, 32, 1))]),
    "buckler": ("Offhand", [
        ("Hide Buckler", (PIXELLAB_BASES + "Hide Buckler", 0, 0, 32, 32, 1)),
        ("Iron Buckler", (PIXELLAB_BASES + "Iron Buckler", 0, 0, 32, 32, 1)),
        ("Steel Targe", (PIXELLAB_BASES + "Steel Targe", 0, 0, 32, 32, 1)),
        ("Golden Buckler", (PIXELLAB_BASES + "Golden Buckler", 0, 0, 32, 32, 1)),
        ("Masterwork Buckler", (PIXELLAB_BASES + "Masterwork Buckler", 0, 0, 32, 32, 1))]),
    # Two tiers. The second was the pack torch with its own flame grown by code (`_blaze`), and was
    # turned down twice for still being the first one: it is drawn now, a caged brand with a fire
    # three times the size.
    "torch": ("Offhand", [
        ("Wooden Torch", (PIXELLAB_BASES + "Wooden Torch", 0, 0, 32, 32, 1)),
        ("Blazing Torch", (PIXELLAB_BASES + "Blazing Torch", 0, 0, 32, 32, 1)),
        ("Masterwork Torch", (PIXELLAB_BASES + "Masterwork Torch", 0, 0, 32, 32, 1))]),
    "broken_torch": ("Offhand", [("Broken Torch", (PIXELLAB_BASES + "Broken Torch", 0, 0, 32, 32, 1))]),

    # The user's own pixellab set (PIXELLAB_BASES): one helmet at four strengths, grown from the
    # leather cap. What it replaced is in BASE_OLD.
    "helm": ("Helmet", [
        ("Leather Helmet", (PIXELLAB_BASES + "Leather Helmet", 0, 0, 32, 32, 1)), ("Iron Helmet", (PIXELLAB_BASES + "Iron Helmet", 0, 0, 32, 32, 1)),
        ("Steel Helm", (PIXELLAB_BASES + "Steel Helm", 0, 0, 32, 32, 1)), ("Golden Helm", (PIXELLAB_BASES + "Golden Helm", 0, 0, 32, 32, 1)),
        ("Masterwork Helm", (PIXELLAB_BASES + "Masterwork Helm", 0, 0, 32, 32, 1))]),
    "hood": ("Helmet", [
        ("Hide Hood", (PIXELLAB_BASES + "Hide Hood", 0, 0, 32, 32, 1)),
        ("Leather Hood", (PIXELLAB_BASES + "Leather Hood", 0, 0, 32, 32, 1)),
        ("Studded Hood", (PIXELLAB_BASES + "Studded Hood", 0, 0, 32, 32, 1)),
        ("Shadow Hood", (PIXELLAB_BASES + "Shadow Hood", 0, 0, 32, 32, 1)),
        ("Masterwork Hood", (PIXELLAB_BASES + "Masterwork Hood", 0, 0, 32, 32, 1))]),

    # Pixellab too, each piece matched to the helmet of its tier. What it replaced is in BASE_OLD.
    "plate": ("Body", [
        ("Wooden Armor", (PIXELLAB_BASES + "Wooden Armor", 0, 0, 32, 32, 1)), ("Iron Armor", (PIXELLAB_BASES + "Iron Armor", 0, 0, 32, 32, 1)),
        ("Steel Plate", (PIXELLAB_BASES + "Steel Plate", 0, 0, 32, 32, 1)), ("Golden Plate", (PIXELLAB_BASES + "Golden Plate", 0, 0, 32, 32, 1)),
        ("Masterwork Plate", (PIXELLAB_BASES + "Masterwork Plate", 0, 0, 32, 32, 1))]),
    # The pack calls a strapped backpack its leather armour (it is rag_and_bone_sack), so all drawn.
    "jerkin": ("Body", [
        ("Hide Jerkin", (PIXELLAB_BASES + "Hide Jerkin", 0, 0, 32, 32, 1)),
        ("Leather Jerkin", (PIXELLAB_BASES + "Leather Jerkin", 0, 0, 32, 32, 1)),
        ("Studded Jerkin", (PIXELLAB_BASES + "Studded Jerkin", 0, 0, 32, 32, 1)),
        ("Shadow Leathers", (PIXELLAB_BASES + "Shadow Leathers", 0, 0, 32, 32, 1)),
        ("Masterwork Jerkin", (PIXELLAB_BASES + "Masterwork Jerkin", 0, 0, 32, 32, 1))]),

    "boot": ("Boots", [
        ("Leather Boot", (PIXELLAB_BASES + "Leather Boot", 0, 0, 32, 32, 1)),
        ("Studded Boot", (PIXELLAB_BASES + "Studded Boot", 0, 0, 32, 32, 1)),
        ("Ranger's Boot", (PIXELLAB_BASES + "Ranger's Boot", 0, 0, 32, 32, 1)),
        ("Shadow Boot", (PIXELLAB_BASES + "Shadow Boot", 0, 0, 32, 32, 1)),
        ("Masterwork Boot", (PIXELLAB_BASES + "Masterwork Boot", 0, 0, 32, 32, 1))]),
    "greaves": ("Boots", [
        ("Iron Greaves", (PIXELLAB_BASES + "Iron Greaves", 0, 0, 32, 32, 1)),
        ("Steel Greaves", (PIXELLAB_BASES + "Steel Greaves", 0, 0, 32, 32, 1)), ("Golden Greaves", (PIXELLAB_BASES + "Golden Greaves", 0, 0, 32, 32, 1)),
        ("Masterwork Greaves", (PIXELLAB_BASES + "Masterwork Greaves", 0, 0, 32, 32, 1))]),

    # Untiered, so here the drawing parts one piece from the next rather than one tier from the
    # last: a stone on a gold band, a broad riveted band, a ring cut from jade, a milky stone on
    # silver, a pearl on a post; three pendants of three shapes. All pixellab (2026-09-24); what the
    # generator drew is in BASE_OLD. (The hat, robe, slippers and Sapphire Amulet went with energy
    # shield, 2026-09-21; their drawings are still in gear.py and their icons still in Assets/Gear, unused.)
    "ring": ("Ring", [("Gold Ring", (PIXELLAB_BASES + "Gold Ring", 0, 0, 32, 32, 1)), ("Iron Band", (PIXELLAB_BASES + "Iron Band", 0, 0, 32, 32, 1)), ("Jade Ring", (PIXELLAB_BASES + "Jade Ring", 0, 0, 32, 32, 1)),
        ("Opal Ring", (PIXELLAB_BASES + "Opal Ring", 0, 0, 32, 32, 1)), ("Pearl Ring", (PIXELLAB_BASES + "Pearl Ring", 0, 0, 32, 32, 1))]),
    "amulet": ("Amulet", [
        ("Ruby Amulet", (PIXELLAB_BASES + "Ruby Amulet", 0, 0, 32, 32, 1)), ("Gold Amulet", (PIXELLAB_BASES + "Gold Amulet", 0, 0, 32, 32, 1)), ("Emerald Amulet", (PIXELLAB_BASES + "Emerald Amulet", 0, 0, 32, 32, 1))]),
}
# The one dye a cut piece takes, as `_shift` wants it: the pack's warm band landed on a hue, and the
# greys given the same. Everything drawn is dyed where it is drawn (gearlib.TINTS).
#
# tint -> ([(hue_low, hue_high, hue_add, sat_mul, light_mul), ...], (grey_hue, grey_sat, grey_light_mul))
BASE_TINTS = {
    "silk": ([(0.0, 0.25, 0.51, 1.9, 1.05)], (0.6, 0.45, 1.05)),
}
# Whether the base icons are written into the game or only onto the preview. It was off through five
# rounds of that preview, which is this project's standing rule for art, and the user turned it on.
# Turn it off again before trying a new look: every source is under Assets/Potential or drawn, never
# a file this writes, so a run is the same the second time as the first.
BASES_EXPORT = True
# What the pixellab bases replaced, still written to Assets/Gear/Old for the settings' dev tick "Show old
# icons" (`LootTable.icon_path`), finished as they were: the pack's three helmets, which were a ladder as
# they stood -- a cap, an open-faced helmet, a great helm -- and an earlier pixellab golden helm; the pack's
# wooden and iron armour, and the steel and golden plate the generator drew.
BASE_OLD = {
    "Leather Helmet": (_RPG + "Equipment/Leather Helmet", 0, 0, 32, 32, 1),
    "Iron Helmet": (_RPG + "Equipment/Iron Helmet", 0, 0, 32, 32, 1),
    "Steel Helm": (_RPG + "Equipment/Helm", 0, 0, 32, 32, 1),
    "Golden Helm": ("golden-helm", 0, 0, 32, 32, 1),
    "Wooden Armor": (_RPG + "Equipment/Wooden Armor", 0, 0, 32, 32, 1),
    "Iron Armor": (_RPG + "Equipment/Iron Armor", 0, 0, 32, 32, 1),
    "Steel Plate": DRAWN,
    "Golden Plate": DRAWN,
    "Leather Boot": (_RPG + "Equipment/Leather Boot", 0, 0, 32, 32, 1),
    "Iron Greaves": (_RPG + "Equipment/Iron Boot", 0, 0, 32, 32, 1),
    "Steel Greaves": DRAWN,
    "Golden Greaves": DRAWN,
    "Gold Ring": DRAWN,
    "Iron Band": DRAWN,
    "Jade Ring": DRAWN,
    "Ruby Amulet": DRAWN,
    "Gold Amulet": DRAWN,
    "Emerald Amulet": DRAWN,
    "Wooden Sword": (_RPG_ZIP + "Weapon & Tool/Wooden Sword", 0, 0, 32, 32, 1),
    "Iron Sword": (_RPG + "Weapon & Tool/Iron Sword", 0, 0, 32, 32, 1),
    "Steel Sword": DRAWN,
    "Golden Sword": (_RPG + "Weapon & Tool/Golden Sword", 0, 0, 32, 32, 1),
    "Wooden Club": DRAWN,
    "Iron Mace": DRAWN,
    "Steel Morningstar": DRAWN,
    "Golden Sceptre": DRAWN,
    "Bone Knife": DRAWN,
    "Iron Dagger": DRAWN,
    "Steel Stiletto": DRAWN,
    "Golden Kris": DRAWN,
    "Wooden Greatsword": DRAWN,
    "Iron Claymore": DRAWN,
    "Steel Zweihander": DRAWN,
    "Golden Greatsword": DRAWN,
    "Wooden Shield": (_RPG_ZIP + "Weapon & Tool/Wooden Shield", 0, 0, 32, 32, 1),
    "Iron Shield": DRAWN,
    "Steel Kite Shield": DRAWN,
    "Golden Aegis": DRAWN,
    "Hide Buckler": DRAWN,
    "Iron Buckler": DRAWN,
    "Steel Targe": DRAWN,
    "Golden Buckler": DRAWN,
    "Wooden Torch": (_RPG + "Weapon & Tool/Torch", 0, 0, 32, 32, 1),
    "Blazing Torch": DRAWN,
    "Hide Jerkin": DRAWN,
    "Leather Jerkin": DRAWN,
    "Studded Jerkin": DRAWN,
    "Shadow Leathers": DRAWN,
    "Hide Hood": DRAWN,
    "Leather Hood": DRAWN,
    "Studded Hood": DRAWN,
    "Shadow Hood": DRAWN,
    "Studded Boot": DRAWN,
    "Ranger's Boot": DRAWN,
    "Shadow Boot": DRAWN,
}
BASE_OLD_OUT = GEAR_OUT + "/Old"

# The six orbs, off "OreAndGem" -- a 10x5 grid of 50 gems on an exact 32 px pitch, so an entry is
# only ever a cell of it. The picks are made for distinctness across the tray as much as for the
# colours Path of Exile trained the idea into: the six stand side by side in one row, so no two of
# them may read as the same stone at a glance.
#
# name -> (sheet under Assets/Potential, x, y, w, h, scale), a source 6-tuple
ORBS = {
    "Orb of Transmutation": ("OreAndGem/OreGemSpritesheet", 9 * 32, 1 * 32, 32, 32, 1),
    "Orb of Augmentation": ("OreAndGem/OreGemSpritesheet", 7 * 32, 1 * 32, 32, 32, 1),
    "Orb of Alchemy": ("OreAndGem/OreGemSpritesheet", 9 * 32, 3 * 32, 32, 32, 1),
    "Orb of Chaos": ("OreAndGem/OreGemSpritesheet", 6 * 32, 2 * 32, 32, 32, 1),
    "Orb of Exalted": ("OreAndGem/OreGemSpritesheet", 5 * 32, 1 * 32, 32, 32, 1),
    "Orb of Divine": ("OreAndGem/OreGemSpritesheet", 8 * 32, 2 * 32, 32, 32, 1),
    # The six super orbs (`SuperOrbTable`), spent only at a transcension: the sheet's crystals, where
    # the ordinary six are its stones, so the two trays never read as one family.
    "Orb of Replacement": ("OreAndGem/OreGemSpritesheet", 2 * 32, 1 * 32, 32, 32, 1),
    "Orb of Ascension": ("OreAndGem/OreGemSpritesheet", 4 * 32, 0 * 32, 32, 32, 1),
    "Orb of Perfection": ("OreAndGem/OreGemSpritesheet", 7 * 32, 0 * 32, 32, 32, 1),
    "Orb of Expansion": ("OreAndGem/OreGemSpritesheet", 6 * 32, 0 * 32, 32, 32, 1),
    "Orb of Mending": ("OreAndGem/OreGemSpritesheet", 3 * 32, 1 * 32, 32, 32, 1),
    "Orb of Binding": ("OreAndGem/OreGemSpritesheet", 0 * 32, 1 * 32, 32, 32, 1),
}
# What OrbSlot draws an orb at: half the source, which is the whole reason the centring below is
# fussier than the gear's. Written here because the preview has to show that size to be worth looking
# at -- the halving is the only thing about these icons that can go wrong.
ORB_DRAWN = 16

# The equipment screen's own furniture, cut off the UI pack's Equipment.png and written loose to
# Assets/UI for the main scene to load by path -- like the gear icons, and for the same reason: none
# of it is a nine-slice, so none of it belongs in the theme sheet.
#
# The doll is drawn apart (`doll()`, DOLL_SOURCE), brown on brown so it reads as the panel rather than as
# a picture on it; the sockets are laid over it. The other two are the pack's empty-socket marks, and
# it is no accident that it draws exactly these two: which socket is the weapon and which the boots
# is obvious from where it sits on a body, and which is a ring is not.
PARTS = {
    "ui_socket_amulet": ("2D Pixel UI/PNG/Equipment", 99, 337, 10, 13, 1),
    "ui_socket_ring": ("2D Pixel UI/PNG/Equipment", 99, 354, 11, 12, 1),
}

# The pack's frames are not clean: along every edge the outline wobbles, the brown shifts a shade
# for a stretch and swells a pixel or three into the cream, which is what makes its panels look
# torn rather than drawn. A nine-slice cannot carry that (check() refuses a tiled row that is not
# one colour), so the wobbles are cut off the composed Inventory panel as patches -- each the whole
# frame depth plus a little cream -- for UITheme.notched to lay over a panel's edges at a pitch.
# Cut whole, never trimmed: a patch's size is its placement. The frame under them is ui_panel_white's
# own (same five columns, pixel for pixel), so a patch's frame pixels vanish into the frame they
# cover and only the wobble shows. Where the pack chips the outer outline inward (a clear pixel at
# the very edge) the frame's own outline shows through instead: a knot, not a chip.
NOTCHES = {
    "ui_notch_left_a": ("2D Pixel UI/PNG/Inventory", 7, 32, 7, 16, 1),
    "ui_notch_left_b": ("2D Pixel UI/PNG/Inventory", 7, 64, 7, 16, 1),
    "ui_notch_right_a": ("2D Pixel UI/PNG/Inventory", 98, 16, 7, 16, 1),
    "ui_notch_right_b": ("2D Pixel UI/PNG/Inventory", 98, 80, 7, 16, 1),
    "ui_notch_bottom_a": ("2D Pixel UI/PNG/Inventory", 17, 95, 8, 6, 1),
    "ui_notch_bottom_b": ("2D Pixel UI/PNG/Inventory", 36, 95, 12, 6, 1),
    "ui_notch_bottom_c": ("2D Pixel UI/PNG/Inventory", 64, 94, 15, 7, 1),
    # The bar's: its top highlight breaks for two pixels and then drops a row under a run of shade.
    "ui_notch_bar_a": ("2D Pixel UI/PNG/Inventory", 9, 0, 13, 4, 1),
}

# The marks the corner's two square buttons wear, off Icons.png -- the same 6-column, 16 px grid the
# ring and the amulet come off, with rows that are not evenly spaced, so each y and height here is
# that one icon's measured extent rather than a cell. The chest is row 1, column 3 and the star is
# row 2, column 2. Scale 1, unlike the gear: these stand on theme art, which is drawn at one source
# pixel per panel pixel, and doubling them would put a second pitch on the same button.
#
# name -> (sheet under Assets/Potential, x, y, w, h, scale), a source 6-tuple
ICONS = {
    "ui_icon_chest": ("2D Pixel UI/PNG/Icons", 34, 3, 12, 11, 1),
    "ui_icon_star": ("2D Pixel UI/PNG/Icons", 18, 18, 13, 12, 1),
    # The collection log: the pack's own trophy, row 3, column 1.
    "ui_icon_trophy": ("2D Pixel UI/PNG/Icons", 18, 50, 13, 13, 1),
    # Either side of an elite's name on the fight's nameplate: the pack's skull, row 1, column 1.
    "ui_icon_skull": ("2D Pixel UI/PNG/Icons", 3, 2, 11, 11, 1),
}
# Both icons are centred on one square, so both buttons come out the same size whatever they wear.
ICON_SIDE = 14

# The keys the item card names at its foot, off the keyboard pack's extras sheet: a 4 x 8 grid of
# 32 x 16 cells, the top four rows the unpressed keys (white face) and the bottom four the pressed
# ones (blue face). Cut at their own size and never recoloured: they stand on the cream card beside
# 10 px body text, and each is 12 px tall and as wide as its word. name -> (column, row).
KEY_SHEET = "Keyboard/Keyboard Extras"
KEY_CELL = (32, 16)
KEYS = {
    "ui_key_shift": (0, 1),
    "ui_key_ctrl": (0, 2),
    "ui_key_alt": (1, 2),
}

# The marks no pack draws, for the fight's two square buttons and the corner's bounty journal: drawn
# here in Icons.png's own
# brown ramp and shading (a dark outline, light from the top left), so that they go through the
# same BONE_RAMP and the same square as the two cut above and cannot be told apart from them.
# o is the outline, 1-4 the ramp from dark to light, . is clear.
ICON_KEY = {"o": "#3e1f1d", "1": "#603928", "2": "#70492a", "3": "#825c2f", "4": "#88682d",
            # The close button's own colours, which BONE_RAMP leaves alone: its teal frame, its cream
            # face, the light along that face's top left, and the black of its X. For ui_icon_info.
            "t": "#38605b", "c": "#e5d6a1", "l": "#fbf5bd", "k": "#151419"}
ICONS_DRAWN = {
    # Auto (a level's autodiscard): the count's chest struck through -- what drops at this level is not
    # kept. The user's pick of seven candidates (2026-09-25). The pack's chest, whose one 583126 is
    # taken to 1.
    "ui_icon_auto": """
        44o...........
        o44ooooooo....
        .o44o44443o...
        ..o44o44333o..
        .o2o44o33332o.
        .o22o44o3322o.
        .o122o44o221o.
        .o1111o44o11o.
        .o23313o44o2o.
        .o223111o44oo.
        .o1222332o44o.
        ..ooooooooo44o
        ...........o44
        ............o4
    """,
    # Terminate: a flag on its pole -- leave the field and keep the haul.
    "ui_icon_flag": """
        ooo..........
        o4oooooooo...
        o4o444443ooo.
        o4o443333332o
        o3o333333222o
        o3o332222221o
        o3o2222211oo.
        o2o21ooooo...
        o2ooo........
        o2o..........
        o2o..........
        o1o..........
        ooo..........
    """,
    # The loot counter: a tied sack.
    "ui_icon_sack": """
        ...oo..oo...
        ...o4oo3o...
        ....o44o....
        ....o32o....
        ...oo21oo...
        ..o443332o..
        .o44333322o.
        o4433333221o
        o4333333221o
        o3333332221o
        o2222222211o
        .o22222111o.
        ..oooooooo..
    """,
    # The bounty journal: a notice off the board, rolled at both ends with two lines of writing on it.
    # Wider than it is tall, unlike the chest and the star, so it reads as paper rather than as a thing.
    "ui_icon_scroll": """
        ooooooooooooo
        o22222222221o
        ooooooooooooo
        .o444444444o.
        .o4ooooo444o.
        .o444444444o.
        .o4oooooo44o.
        .o444444444o.
        ooooooooooooo
        o22222222221o
        ooooooooooooo
    """,
    # The town's counters, one mark a tab (the board wears the scroll above). Gear: a sword, guard across.
    "ui_icon_sword": """
        ..........ooo
        .........o44o
        ........o443o
        .......o443o.
        .o....o443o..
        o3o..o443o...
        .o3oo443o....
        ..o3443o.....
        ...o33o......
        ..o21o3o.....
        .o21o.o3o....
        o21o...o3o...
        ooo.....oo...
    """,
    # Orbs: a cut gem, table facet over the pavilion.
    "ui_icon_gem": """
        ..ooooooooo..
        .o444o333o2o.
        o4444o333o22o
        ooooooooooooo
        o333o22222o1o
        .o33o2222o1o.
        ..o3o222o1o..
        ...o3o2o1o...
        ....o321o....
        .....o1o.....
        ......o......
    """,
    # The smith: his anvil, horn to the left and the square heel to the right, as a real one is --
    # a symmetrical one reads as an hourglass. A hammer at this size is a letter T.
    "ui_icon_anvil": """
        ....ooooooooo
        oooo44444444o
        o33333333333o
        .ooo3333333oo
        ....oo3333oo.
        .....o3333o..
        .....o3333o..
        ....o222222o.
        ...o22222222o
        ...o11111111o
        ...oooooooooo
    """,
    # Clear a level out of the bag: a bin, lid and ribs.
    "ui_icon_trash": """
        ....ooo....
        ...o444o...
        ooooooooooo
        o444444433o
        ooooooooooo
        .o4o4o3o2o.
        .o4o4o3o2o.
        .o4o4o3o2o.
        .o4o4o3o2o.
        .o4o4o3o2o.
        .o4443322o.
        ..ooooooo..
    """,
    # Sell a level to the merchant, the bin's place at a counter: two stacks of coins, edge on.
    "ui_icon_coins": """
        .......oooo.
        ......o4443o
        ......o2221o
        ......o4443o
        .oooo.o2221o
        o4443oo4443o
        o2221oo2221o
        o4443oo4443o
        o2221oo2221o
        .oooo..oooo.
    """,
    # Auto: a funnel -- what is found at this level is filtered out before it reaches the bag.
    "ui_icon_filter": """
        ooooooooooooo
        o44444444433o
        .o444444332o.
        ..o4444332o..
        ...o44332o...
        ....o432o....
        ....o432o....
        ....o432o....
        ....o32oo....
        ....ooo......
    """,
    # Back, out of an open piece to the bag's grid.
    "ui_icon_back": """
        ....oo.....
        ...o4o.....
        ..o44oooooo
        .o44444443o
        o444333332o
        .o33222221o
        ..o32oooooo
        ...o2o.....
        ....oo.....
    """,
    # Help, on the collection log: a question mark the close button's size (9x10), worn by no button --
    # it stands on the panel and says its piece in a tooltip.
    "ui_icon_help": """
        ..ooooo..
        .o44433o.
        o43ooo32o
        ooo.o332o
        ...o332o.
        ...o32o..
        ...oooo..
        ...o42o..
        ...o21o..
        ...oooo..
    """,
    # Info, on the collection log: an "i" on a disc in the close button's colours (12x12), worn by no
    # button -- it stands on the panel and says its piece in a tooltip. Mockup: qa/info_icon_m2.png, C.
    "ui_icon_info": """
        ....tttt....
        ..ttlllltt..
        .tllckkccct.
        .tlcckkccct.
        tlccccccccct
        tlcckkkcccct
        tlccckkcccct
        tlccckkcccct
        .tlcckkccct.
        .tcckkkkcct.
        ..ttcccctt..
        ....tttt....
    """,
    # Swap, on the bag's comparison: two arrows chasing each other round -- the other ring finger.
    "ui_icon_swap": """
        ....ooooo.....
        ..ooo444oooo..
        .oo44ooo4o4oo.
        .o4ooo.oo444oo
        oo4o...o44444o
        o3oo...ooooooo
        o3o........o3o
        o3o........o3o
        ooooooo...oo3o
        o22222o...o2oo
        oo222oo.ooo2o.
        .oo2o2ooo22oo.
        ..oooo222ooo..
        .....ooooo....
    """,
    # Hide the comparison: a caret pointing back at the bag it folds into.
    "ui_icon_caret_left": """
        ...ooo
        ..oo4o
        .oo44o
        oo44oo
        o33oo.
        oo33oo
        .oo22o
        ..oo2o
        ...ooo
    """,
    # And show it again: the same caret pointing out to where it opens.
    "ui_icon_caret_right": """
        ooo...
        o4oo..
        o44oo.
        oo44oo
        .oo33o
        oo33oo
        o22oo.
        o2oo..
        ooo...
    """,
    # Settings, the corner's fourth button: a cog, four teeth square and four on the slant.
    "ui_icon_cog": """
        .....ooo.....
        ..oo.o4o.oo..
        .o4ooo4ooo3o.
        .o444444333o.
        ..o44ooo33o..
        ooo4o...o3ooo
        o444o...o322o
        ooo3o...o2ooo
        ..o33ooo22o..
        .o333322222o.
        .o3ooo2ooo1o.
        ..oo.o2o.oo..
        .....ooo.....
    """,
    # Either side of a boss's name on the fight's nameplate: a three-pointed crown on its band.
    "ui_icon_crown": """
        .o....o....o.
        o4o..o4o..o3o
        o4oo.o4o.oo3o
        o44oo444oo32o
        o44444433322o
        o44433333222o
        ooooooooooooo
        o33332222211o
        ooooooooooooo
    """,
    # The achievements' tab (2026-09-28): a medal on its ribbon, a stand-in until one is drawn.
    "ui_icon_medal": """
        .oo.......oo.
        .o3o.....o3o.
        ..o3o...o3o..
        ...o3o.o3o...
        ...ooooooo...
        ..o4444433o..
        .o44ooooo32o.
        .o4o44433o2o.
        .o4o43332o2o.
        .o3o33322o1o.
        .o3o32221o1o.
        .o33ooooo11o.
        ..o3222211o..
        ...ooooooo...
    """,
}

# The skill trees' icons, off "Ability Icons" -- loose 16 px files that carry their own framed square,
# so an entry is a whole file and nothing is trimmed. One colourway a tree, so a tree reads as one
# thing: red for Power, the gold-orange for Fortune, which is the colour loot already speaks in, and
# blue for Guard. The pack's blues are water and ice, not shields: stand-ins until something is drawn.
# The pack's Locked mark in each colourway stands in for a node that cannot be learned yet.
#
# node id -> (tree, file under "Ability Icons/Icons (All)")
SKILL_ROOT = "Ability Icons/Icons (All)/"
SKILL_LOCKED = "Ability Icons/Icons (Base & Locked)/"
SKILL_OUT = "Assets/Skills"
SKILL_SIDE = 16
SKILLS = {
    "sharpened_edge": ("power", "Red4"),
    "keen_eye": ("power", "Red9"),
    "quick_hands": ("power", "Red15"),
    "battle_rhythm": ("power", "Red1"),
    "deadly_strikes": ("power", "Red13"),
    "assassin": ("power", "Red2"),
    "flurry": ("power", "Red3"),
    "whirlwind": ("power", "Red8"),
    "might": ("power", "Red10"),
    "titan": ("power", "Red5"),
    "scavenger": ("fortune", "Yellow6"),
    "prospector": ("fortune", "Yellow10"),
    "appraiser": ("fortune", "Yellow7"),
    "fortunes_favour": ("fortune", "Yellow3"),
    "treasure_hunter": ("fortune", "Yellow15"),
    "collector": ("fortune", "Yellow8"),
    "greed": ("fortune", "Yellow14"),
    "midas": ("fortune", "Yellow9"),
    "orb_seeker": ("fortune", "Yellow11"),
    "alchemist": ("fortune", "Yellow12"),
    "toughness": ("guard", "Blue3"),
    "footwork": ("guard", "Blue2"),
    "steady_guard": ("guard", "Blue13"),
    "resolve": ("guard", "Blue7"),
    "evasion": ("guard", "Blue14"),
    "phantom": ("guard", "Blue10"),
    "shield_mastery": ("guard", "Blue8"),
    "bastion": ("guard", "Blue1"),
    "tenacity": ("guard", "Blue12"),
    "undying": ("guard", "Blue5"),
}
SKILL_LOCKS = {"power_locked": "RedLocked", "fortune_locked": "YellowLocked", "guard_locked": "BlueLocked"}
# The user's pixellab skill icons (2026-09-25), replacing the pack's a tree at a time: one grey badge
# (`SKILL_FRAME`, drawn once) with its corners cut, tinted per tree by lightness (`SKILL_TINTS`), and a bone-white
# symbol of what the skill does centred on it. 32 px: SkillSlot draws every icon into the same 32 px square, the
# pack's 16 px ones at 2x and these at 1x. A skill not in `SKILL_SYMBOLS` keeps its pack icon.
SKILL_PIXELLAB = "Skills/"
SKILL_FRAME = SKILL_PIXELLAB + "frame"
SKILL_BADGE = 32
SKILL_SYMBOLS = {"sharpened_edge", "keen_eye", "quick_hands", "battle_rhythm", "deadly_strikes", "flurry", "might",
                 "assassin", "whirlwind", "titan",
                 "scavenger", "prospector", "appraiser", "fortunes_favour", "treasure_hunter", "greed", "orb_seeker",
                 "collector", "midas", "alchemist",
                 "toughness", "footwork", "steady_guard", "resolve", "evasion", "shield_mastery", "tenacity", "phantom",
                 "bastion", "undying"}
# One padlock for every tree's locked mark: the frame's tint says which tree (`Skills/locked.png`).
SKILL_LOCK_SYMBOL = "locked"
# The frame's lightness, measured: its outer ring ~0.06, the field ~0.15, the border's shade ~0.45 and light ~0.73.
# Each tree maps those onto its own chart colours, so the bevel keeps its light and shade and only the hue moves.
SKILL_TINTS = {
    "power": [(0.0, "#2f3236"), (0.06, "#3f0e1d"), (0.15, "#5a1122"), (0.45, "#982a1e"), (0.73, "#ba3423"), (1.0, "#e1828f")],
    "fortune": [(0.0, "#2f3236"), (0.06, "#3a2217"), (0.15, "#4e2d1f"), (0.45, "#9b7227"), (0.73, "#c49e48"), (1.0, "#f9f4d4")],
    "guard": [(0.0, "#2f3236"), (0.06, "#171a2a"), (0.15, "#1a2134"), (0.45, "#3f4a64"), (0.73, "#546783"), (1.0, "#999dd5")],
    # The fortuneteller's spells: purple, hers alone (the user, 2026-09-25), as the pack's placeholders were.
    "teller": [(0.0, "#2f3236"), (0.06, "#221931"), (0.15, "#34264a"), (0.45, "#574175"), (0.73, "#7b70ad"), (1.0, "#c1b5cf")],
}
# Her spells' pixellab symbols (`Fortune/<reading>.png`), laid on the same frame in the "teller" tint; a reading not
# listed keeps its pack icon.
FORTUNE_PIXELLAB = "Fortune/"
FORTUNE_SYMBOLS = {"roads", "treasure", "quarry", "relic", "appraise", "scour", "homecoming", "transcend"}
# How far from each corner the frame's near-black rounding is cleared, and how dark a pixel must be to go.
SKILL_CORNER_REACH = 3
SKILL_CORNER_DARKEST = 0.09

# The fortuneteller's seven spells, off the same pack in the one colourway neither skill tree uses:
# purple is hers alone, so a spell on her grid is never mistaken for a skill. Placeholder art -- the
# pack draws no fortuneteller, and these stand in until something is drawn for her.
#
# reading (FortuneTeller's own names) -> file under "Ability Icons/Icons (All)"
FORTUNE_OUT = "Assets/Fortune"
FORTUNE = {
    "roads": "Purple12",
    "treasure": "Purple14",
    "quarry": "Purple6",
    "relic": "Purple1",
    "appraise": "Purple15",
    "scour": "Purple8",
    # An arch to walk back through, which is the nearest thing in the pack to a road home.
    "homecoming": "Purple11",
    # The way out: the user's own cracked orb (2026-09-25), a pixellab symbol with no pack stand-in.
    "transcend": None,
}
# The sketch's shape, row by row: which node stands in which of three columns, and its parents. Written
# here only so the preview can draw a tree; SkillTree in the game is where it is actually decided.
SKILL_LAYOUT = {
    "power": [
        ("sharpened_edge", 0, 1, []), ("keen_eye", 1, 0, ["sharpened_edge"]),
        ("quick_hands", 1, 2, ["sharpened_edge"]), ("battle_rhythm", 2, 1, ["keen_eye", "quick_hands"]),
        ("deadly_strikes", 3, 0, ["battle_rhythm"]), ("flurry", 3, 1, ["battle_rhythm"]),
        ("might", 3, 2, ["battle_rhythm"]), ("assassin", 4, 0, ["deadly_strikes"]),
        ("whirlwind", 4, 1, ["flurry"]), ("titan", 4, 2, ["might"]),
    ],
    "fortune": [
        ("scavenger", 0, 1, []), ("prospector", 1, 0, ["scavenger"]),
        ("appraiser", 1, 2, ["scavenger"]), ("fortunes_favour", 2, 1, ["prospector", "appraiser"]),
        ("treasure_hunter", 3, 0, ["fortunes_favour"]), ("greed", 3, 1, ["fortunes_favour"]),
        ("orb_seeker", 3, 2, ["fortunes_favour"]), ("collector", 4, 0, ["treasure_hunter"]),
        ("midas", 4, 1, ["greed"]), ("alchemist", 4, 2, ["orb_seeker"]),
    ],
    "guard": [
        ("toughness", 0, 1, []), ("footwork", 1, 0, ["toughness"]),
        ("steady_guard", 1, 2, ["toughness"]), ("resolve", 2, 1, ["footwork", "steady_guard"]),
        ("evasion", 3, 0, ["resolve"]), ("shield_mastery", 3, 1, ["resolve"]),
        ("tenacity", 3, 2, ["resolve"]), ("phantom", 4, 0, ["evasion"]),
        ("bastion", 4, 1, ["shield_mastery"]), ("undying", 4, 2, ["tenacity"]),
    ],
}
# What the face pads its icon by. The game's own copy is UITheme.ICON_FACE_MARGIN -- padding is a
# decision the theme makes, the way UITheme.BUTTON_MARGIN is; this one is here so the preview draws
# the button at the size the game will, which is the only size worth judging the icons at.
ICON_PAD = 4
# Icons.png is drawn in the wood panel's own brown ramp: the pack means these marks to be engraved
# on wood, which is why ui_doll above is cut from the same family. On the brown button face they
# would barely read, so the ramp is mapped onto the pack's cream -- the two lightest steps are the
# cream panel's own #cda677 and #e5d6a1 (Palette.SLOT_TAN and PANEL_CREAM), and the outline stays a
# mid brown rather than going white, so the icon keeps an edge against the face it sits on.
BONE_RAMP = {
    "#3e1f1d": "#6b4a30",
    "#603928": "#a98b5e",
    "#70492a": "#cda677",
    "#825c2f": "#e5d6a1",
    "#88682d": "#f4ecc6",
}
# The marks that stand bare on the cream body, with no face behind them -- the way the pack lays its
# speaker and its note beside the settings' sliders and its three craft tabs on the panel's frame.
# These keep Icons.png's own brown ramp ("_brown"), and the tabs come a second time in the pack's
# green ("_green") for the one that is open: the pack turns the open craft tab's mark green and
# changes nothing else. GREEN_KEY is measured off Icons.png, which draws its T, its pot and its
# scissors in both colourways: 603928 -> 2c4645, 70492a -> 3f7168, 88682d -> 50a978, a07f2d ->
# 57c767 -- the outline to the close button's teal family and the ramp to the bar's green.
BARE = ["ui_icon_auto", "ui_icon_filter", "ui_icon_trash", "ui_icon_coins", "ui_icon_scroll", "ui_icon_sword", "ui_icon_chest",
        "ui_icon_gem", "ui_icon_anvil", "ui_icon_help"]
GREEN_TABS = ["ui_icon_auto", "ui_icon_filter", "ui_icon_scroll", "ui_icon_sword", "ui_icon_gem", "ui_icon_anvil",
              "ui_icon_help"]
GREEN_KEY = {"#3e1f1d": "#2c4645", "#603928": "#3f7168", "#70492a": "#478773", "#825c2f": "#50a978",
             "#88682d": "#57c767"}

# The character panel in the top-left corner, off the UI pack's character_panel.png. The pack draws
# it eight times over -- with and without a portrait, with empty and with filled bars -- so the frame
# is the empty-circle, empty-trough one, and each bar is cut off the filled variant beside it at the
# very rectangle it fills, which is what makes a bar land in its trough to the pixel. The loose bars
# at the foot of the sheet are the same colours but not the same lengths as the troughs, so they are
# not used.
#
# Every x and y here is measured: the frame's bbox in its 96x32 block, and each bar by diffing the
# empty panel against the filled one -- exactly the pixels that change.
CHAR_SHEET = "2D Pixel UI/PNG/character_panel"
CHAR_FRAME = (2, 34, 84, 30)
# name -> (x, y, w) in the frame; every bar is two pixels tall. The filled panel is 96 px to the right.
CHAR_BARS = {"hp": (28, 8, 52), "mana": (30, 13, 43), "xp": (29, 18, 38)}
CHAR_BAR_HEIGHT = 2
CHAR_FILLED_DX = 96
# A point inside the portrait circle; the circle is whatever transparent run is joined to it.
CHAR_CIRCLE_SEED = (14, 14)
# The player's portrait: the kobold's first idle frame, framed so the eye and the tip of the snout sit
# in the circle -- the head is twice the circle's width, and the snout is what says kobold -- on the
# pack's own lilac disc, which the blue hide stands off where the pack's paler blue would not.
CHAR_KOBOLD = ("Assets/Player/idle.png", 58, 38)
CHAR_DISC = (120, 124, 195, 255)
# The XP gem: row 8, column 6 of Icons.png, its whole 6x6 extent.
XP_GEM = ("2D Pixel UI/PNG/Icons", 85, 117, 6, 6, 1)

# The combat HUD's kill-pip bar, and the one thing here off a second bought pack -- "Pixel UI pack
# 3", whose 06.png draws a capsule bar the 2D Pixel UI pack has no equivalent of. The game needs that
# capsule ten pips long and the pack ships it at five, so what is cut here is not the bar but the
# pieces it is built from, and KillPips butts them together at runtime.
#
# The capsule (27x8, the full one at x=66 and the empty one at x=226) is laid out on a rigid 4 px
# segment pitch, which is what makes that possible. Measured off the pixels and checked against both
# the 1/5 and the 5/5 step -- an n-segment fill is always columns 1 .. 4n+1:
#
#     col 0        the black left edge
#     cols 1-4     segment 1, which carries the rounded left shoulder
#     cols 5-8 ..  the repeating interior segment, each with its own left divider
#     col 4n+1     the column that closes the fill off
#     cols 25-26   the rounded right end
#
# So three parts make a bar of any length: a head, a body repeated, and a tail. Each is cut in the
# three tier colourways and in the pack's empty grey, which is the state a pip takes once its enemy
# is down. Named by the tier each stands for rather than by its colour: which tier is brown is a fact
# about the game, and a table saying "brown" would have to be read against a second table saying what
# brown meant.
#
# The pack's fill steps are not used -- a pip is a whole enemy, not a fraction of one -- and neither
# is the silver colourway, because there is no fourth tier.
PIP_SHEET = "Pixel UI pack 3/06"
PIP_HEIGHT = 8
# Where each colourway's capsule row starts, and where the full and the empty one sit along it.
PIP_BANDS = {"common": 116, "elite": 148, "boss": 180}
PIP_FULL_X = 66
PIP_EMPTY_X = 226
# part -> (columns off the capsule, width). The tail is the odd one: its first column is the full
# capsule's closing column and its other two are the rounded right end, which is taken off the EMPTY
# capsule for every colourway -- that is how the pack draws the right-hand end of its own full bar.
PIP_HEAD = (0, 5)
PIP_BODY = (5, 4)
PIP_TAIL_CLOSE = 21
PIP_TAIL_END = (25, 2)
PIP_WIDTHS = {"head": 5, "body": 4, "tail": 3}


def _rgb(text):
    """One "#rrggbb" as the opaque RGBA tuple the images are keyed by."""
    return tuple(int(text[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def _recolor(hue, sat, dim=1.0):
    """A colour map over GREEN_RAMP: the same lightness, another hue and saturation."""
    table = {}
    for text in GREEN_RAMP:
        r, g, b = (int(text[i:i + 2], 16) for i in (1, 3, 5))
        _, light, _ = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
        out = colorsys.hls_to_rgb(hue, min(1.0, light * dim), sat)
        table[(r, g, b, 255)] = tuple(round(v * 255) for v in out) + (255,)
    return table


BROWN = _recolor(BROWN_HUE, BROWN_SAT, BROWN_DIM)
# Every lettered button is played in the icon buttons' brown, so a word and a mark sit on the same
# face; only the destructive ones keep the pack's red.
VARIANTS = {
    "normal": BROWN,
    "danger": _recolor(DANGER_HUE, DANGER_SAT),
}
# The pack's own green, unrecoloured, for the one press a counter is there for (Buy, Accept, Claim,
# Upgrade): brown says "a thing you can do", green says "the thing to do here". Cream surface only --
# no wood panel carries one.
GO_SURFACES = ("light",)
DISABLED = _recolor(DISABLED_HUE, DISABLED_SAT, DISABLED_DIM)
# The order a button's four states are read in, which is the order the previews lay them out in.
STATE_ORDER = ["normal", "hover", "pressed", "disabled"]


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

    name, src, columns, rows, margin = HEADED
    width = sum(x1 - x0 for x0, x1 in columns)
    height = sum(y1 - y0 for y0, y1 in rows)
    headed = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    dy = 0
    for y0, y1 in rows:
        dx = 0
        for x0, x1 in columns:
            headed.paste(sheet(src).crop((x0, y0, x1, y1)), (dx, dy))
            dx += x1 - x0
        dy += y1 - y0
    sprites[name] = headed
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
        if surface in GO_SURFACES:
            for state, x in BUTTON_STATE_X.items():
                name = "ui_btn_%s_go_%s" % (surface, state)
                sprites[name] = sheet("Buttons").crop((x, row, x + w, row + h))
                margins[name] = BUTTON_MARGIN
            x = BUTTON_STATE_X["normal"]
            sprites["ui_btn_%s_go_disabled" % surface] = _map_colors(
                    sheet("Buttons").crop((x, row, x + w, row + h)), DISABLED)
            margins["ui_btn_%s_go_disabled" % surface] = BUTTON_MARGIN

    # The brown face, which is the same rectangle in another key. It has no surface of its own: it
    # stands on the map rather than on a panel, so it takes the wood row's drop shadow and stops
    # there -- one family of four rather than the two-by-two above. Its dead face is the same grey
    # every other family's is, because a switched-off button is not brown any more than it is green.
    for state, x in BUTTON_STATE_X.items():
        name = "ui_btn_brown_%s" % state
        sprites[name] = _map_colors(sheet("Buttons").crop((x, BUTTON_ROW["wood"], x + w,
                                                           BUTTON_ROW["wood"] + h)), BROWN)
        margins[name] = BUTTON_MARGIN
    x = BUTTON_STATE_X["normal"]
    sprites["ui_btn_brown_disabled"] = _map_colors(
            sheet("Buttons").crop((x, BUTTON_ROW["wood"], x + w, BUTTON_ROW["wood"] + h)), DISABLED)
    margins["ui_btn_brown_disabled"] = BUTTON_MARGIN

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


def _cut(entry, trim=True):
    """One rectangle off a pack sheet, trimmed to what is actually drawn and scaled.

    Nothing cut this way is checked for tiling: it is drawn at its own size and never stretched, so
    it has no nine-slice and no rows to keep uniform -- the same reason the close button skips check().

    `trim` is what an icon wants and a pip does not: the pips stand in a row and every one of them
    has to be the same width, whether or not its own art reaches the edge of the rectangle.
    """
    src, x, y, w, h, scale = entry
    if ".zip!" in src:
        # A sheet still inside its pack's zip: "<the zip>!<the path in it>". Nothing is unpacked.
        archive, inner = src.split("!")
        with zipfile.ZipFile(os.path.join(POTENTIAL, archive)) as pack_zip:
            sheet = Image.open(io.BytesIO(pack_zip.read(inner + ".png")))
    else:
        sheet = Image.open(os.path.join(POTENTIAL, src + ".png"))
    art = sheet.convert("RGBA").crop((x, y, x + w, y + h))
    box = art.getbbox() if trim else None
    if box:
        art = art.crop(box)
    if scale != 1:
        art = art.resize((art.width * scale, art.height * scale), Image.NEAREST)
    return art


def _squared(name, art):
    """`art` centred on a GEAR_SIDE square. Centred rather than left where the measurement found it:
    an icon sitting off-centre in its square reads as a mistake once there is a grid of them."""
    if art.width > GEAR_SIDE or art.height > GEAR_SIDE:
        raise SystemExit("%s is %dx%d, too big for a %d square"
                         % (name, art.width, art.height, GEAR_SIDE))
    square = Image.new("RGBA", (GEAR_SIDE, GEAR_SIDE), (0, 0, 0, 0))
    square.alpha_composite(art, ((GEAR_SIDE - art.width) // 2, (GEAR_SIDE - art.height) // 2))
    return square


def _outlined(art, own_edge=False):
    """`art` ending in a dark outline one pixel thick, all the way round: the finish every base wears.

    Where the outline goes is where the RPG pack puts its white border. Measured off all 105 of its
    icons, that border is pure (255, 255, 255), one pixel thick, and it is every opaque pixel that
    touches clear on one of its four sides plus the odd corner fill that touches it only diagonally.
    So it is found from the outside in -- a pure white pixel with clear among its eight neighbours
    -- and never by colour over the whole sprite: the pack also puts pure white on a blade glint and
    in the heart of the torch flame, a handful of pixels an icon, and none of them touches clear.
    Every pixel of that ring is painted ink. The pack ships some pieces without the border (four of
    the six originals in Assets/Gear are those: the sword, the shield, the boot, the wooden armour),
    and a drawing may come with none, so where under half the edge is white the ring is *added*: the
    clear pixels on the four sides of the art. Either way the art inside is never touched and the
    outline stands outside it, inside the 32 square.

    An earlier version cleared a border pixel wherever what it stood against was already dark, to
    keep the line thin. It was turned down: the pack shades towards its edge in mid browns that are
    dark enough to pass that test and nowhere near as dark as ink, so a cut piece ended in 56% ink
    on average (the leather boot in 1%) where a drawn one ended in 88%, and the two read as two
    finishes on one sheet. One rule now, and tools and qa both count it: every opaque pixel that
    touches clear is ink.

    The ink is the sprite's own: the hue and saturation of its darkest twentieth, no lighter than
    OUTLINE_INK -- on the pack's pale pieces (the bow, the skull, the candle) the darkest tone is a
    mid brown, and a mid brown line on a tan socket is no line at all. The pack's few ghost pixels
    (alpha under 14, round the hammer) are cleared first.
    """
    out = art.copy()
    px = out.load()
    w, h = out.size
    for y in range(h):
        for x in range(w):
            if px[x, y][3] < 128:
                px[x, y] = (0, 0, 0, 0)

    def around(x, y, ways):
        return [(x + dx, y + dy) for dx, dy in ways]

    def clear(spot):
        return not (0 <= spot[0] < w and 0 <= spot[1] < h) or px[spot][3] == 0

    solid = {(x, y) for y in range(h) for x in range(w) if px[x, y][3]}
    if not solid:
        return out
    ring = {spot for spot in solid if px[spot][:3] == (255, 255, 255)
            and any(clear(near) for near in around(*spot, _EIGHT))}
    edge = [spot for spot in solid if any(clear(near) for near in around(*spot, _FOUR))]
    if own_edge:
        # The art's own outline, recoloured: see PIXELLAB.
        ring = set(edge)
    elif 2 * len(ring) < len(edge):
        # No border to repaint, so the ring is added -- on a canvas a pixel bigger each way if the
        # art runs to the edge of this one; the callers centre whatever comes back on the square.
        if any(x in (0, w - 1) or y in (0, h - 1) for x, y in solid):
            grown = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
            grown.alpha_composite(out, (1, 1))
            return _outlined(grown)
        ring = {near for spot in edge for near in around(*spot, _FOUR) if near not in solid}
    inside = sorted(solid - ring, key=lambda spot: colorsys.rgb_to_hls(*[v / 255 for v in px[spot][:3]])[1])
    if not inside:
        return out
    dark = inside[:max(1, len(inside) // 20)]
    mean = [sum(px[spot][k] for spot in dark) / len(dark) / 255 for k in range(3)]
    hue, lightness, sat = colorsys.rgb_to_hls(*mean)
    ink = tuple(round(v * 255) for v in colorsys.hls_to_rgb(hue, min(lightness, OUTLINE_INK), sat)) + (255,)
    for spot in ring:
        px[spot] = ink
    return out


def outline_share(art):
    """How much of `art`'s edge -- its opaque pixels that touch clear -- is outline ink, 0 to 1."""
    px = art.load()
    w, h = art.size
    edge = [px[x, y] for y in range(h) for x in range(w) if px[x, y][3] and any(
        not (0 <= x + dx < w and 0 <= y + dy < h) or px[x + dx, y + dy][3] == 0 for dx, dy in _FOUR)]
    inked = [p for p in edge if colorsys.rgb_to_hls(*[v / 255 for v in p[:3]])[1] <= OUTLINE_INK + 0.02]
    return len(inked) / max(1, len(edge))


def _doubled(art):
    """Whether `art` is smaller art blown up: every 2x2 block of it, from its own corner, one colour.

    The preview asks this of every cell, because it is the one thing about a source the eye gets
    wrong at 3x and right at 1x: a doubled icon beside a true one reads as a different game.
    """
    box = art.getbbox()
    if not box:
        return False
    art = art.crop(box)
    if art.width % 2 or art.height % 2:
        return False
    half = art.resize((art.width // 2, art.height // 2), Image.NEAREST)
    return half.resize(art.size, Image.NEAREST).tobytes() == art.tobytes()


def _shift(art, bands, grey=None):
    """`art` with every pixel whose hue falls in a band moved: see UNIQUE_GEAR. Greys are left alone --
    the outline and the amulet's cord have no hue worth the name.

    `grey` is (hue, saturation) and may name a third number, what to multiply those pixels' lightness
    by. Without it an iron piece and a steel one come out the same value wherever a pack drew its
    metal colourless, which is most of the armour in them: the band's own light_mul never reaches
    those pixels, and hue and saturation alone cannot say dark.
    """
    out = art.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            hue, light, sat = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            if a == 0:
                continue
            if sat < 0.2:
                # Steel has no hue to move, so it is given one: only where `grey` asks, and never the
                # white outline or the black line, which a hue would do nothing to anyway.
                if grey and 0.15 < light < 0.95:
                    dim = grey[2] if len(grey) > 2 else 1.0
                    # Never past the white outline: a pack that draws its steel bright already sits
                    # near the ceiling, and a steel recipe that suits the RPG pack turns Raven's
                    # morningstar into a snowball without this.
                    px[x, y] = tuple(round(c * 255) for c in colorsys.hls_to_rgb(
                            grey[0], min(light * dim, GREY_CEILING), grey[1])) + (a,)
                continue
            for low, high, add, sat_mul, light_mul in bands:
                if low <= hue <= high:
                    moved = colorsys.hls_to_rgb((hue + add) % 1.0,
                                                min(light * light_mul, GREY_CEILING),
                                                min(sat * sat_mul, 1.0))
                    px[x, y] = tuple(round(c * 255) for c in moved) + (a,)
                    break
    return out


def _generator():
    """AI-sprites-generator/gear.py, which draws what no pack does."""
    sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "AI-sprites-generator"))
    import gear
    return gear


def unique_gear():
    """The unique items' icons, each on its own GEAR_SIDE square."""
    out = {}
    for name, entry in UNIQUE_GEAR.items():
        art = _cut(entry[0])
        fire = _fire(art) if name in UNIQUE_FIRE else set()
        out[name] = _squared(name, _shift(_outlined(_muted(art, fire), own_edge=True), *entry[1:]))
    return out


def _muted(art, keep=frozenset()):
    """`art` with its saturation scaled down to SAT_CEILING at the 90th percentile: see PIXELLAB. The pixels in
    `keep` (a torch's flame, `_fire`) are left as drawn and not counted."""
    out = art.copy()
    px = out.load()
    spots = [(x, y) for y in range(out.height) for x in range(out.width) if px[x, y][3] and (x, y) not in keep]
    hsv = {spot: colorsys.rgb_to_hsv(*[v / 255 for v in px[spot][:3]]) for spot in spots}
    sats = sorted(s for _, s, v in hsv.values() if v >= 0.2)
    top = sats[len(sats) * 9 // 10] if sats else 0.0
    if top <= SAT_CEILING:
        return out
    for spot, (h, s, v) in hsv.items():
        px[spot] = tuple(round(c * 255) for c in colorsys.hsv_to_rgb(h, s * SAT_CEILING / top, v)) + (px[spot][3],)
    return out


def _fire(art):
    """The flame of a torch: its bright warm pixels (value 0.85 up), grown into the orange beside them, and of those
    only the biggest connected patch, so a lit knot on the haft is not taken for fire. See BASE_FIRE."""
    px = art.load()
    w, h = art.size

    def warm(spot, hue_most, sat_least, value_least):
        if not (0 <= spot[0] < w and 0 <= spot[1] < h) or not px[spot][3]:
            return False
        hue, sat, value = colorsys.rgb_to_hsv(*[v / 255 for v in px[spot][:3]])
        return hue <= hue_most and sat >= sat_least and value >= value_least

    def around(spot):
        return [(spot[0] + dx, spot[1] + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)]

    grown = {(x, y) for y in range(h) for x in range(w) if warm((x, y), 0.17, 0.3, 0.85)}
    frontier = list(grown)
    while frontier:
        for spot in around(frontier.pop()):
            if spot not in grown and warm(spot, 0.14, 0.45, 0.6):
                grown.add(spot)
                frontier.append(spot)
    best, seen = set(), set()
    for start in grown:
        if start in seen:
            continue
        patch, frontier = {start}, [start]
        seen.add(start)
        while frontier:
            for spot in around(frontier.pop()):
                if spot in grown and spot not in seen:
                    seen.add(spot)
                    patch.add(spot)
                    frontier.append(spot)
        best = max(best, patch, key=len)
    return best


def _glowed(art, fire):
    """`art` with FIRE_GLOW on the clear pixels one and two steps outside the flame and its outline, the nearer
    ring the stronger (FIRE_GLOW_ALPHAS)."""
    out = art.copy()
    px = out.load()
    w, h = out.size
    body = {(x + dx, y + dy) for x, y in fire for dx in (-1, 0, 1) for dy in (-1, 0, 1)
            if 0 <= x + dx < w and 0 <= y + dy < h and px[x + dx, y + dy][3] == 255}
    for step, alpha in enumerate(FIRE_GLOW_ALPHAS, 1):
        ring = {(x + dx, y + dy) for x, y in body for dx in range(-step, step + 1) for dy in range(-step, step + 1)}
        for x, y in ring:
            if 0 <= x < w and 0 <= y < h and px[x, y][3] == 0:
                px[x, y] = FIRE_GLOW + (alpha,)
    return out


def unique_old():
    """The icons the pixellab pieces replaced, made as they were: see UNIQUE_OLD."""
    out = {name: _squared(name, _shift(_outlined(_cut(entry[0])), *entry[1:])) for name, entry in UNIQUE_OLD.items()}
    out.update(unique_drawn(UNIQUE_OLD_DRAWN))
    return out


def unique_drawn(names):
    """The drawn unique icons, finished the way every base is."""
    draw = _generator().UNIQUES
    out = {}
    for name in names:
        art = _outlined(draw[name]())
        if _doubled(art) or outline_share(art) < OUTLINE_FLOOR:
            raise SystemExit("%s: doubled, or its edge is not outline ink" % name)
        out[name] = _squared(name, art.crop(art.getbbox()))
    return out


def unique_preview(cut):
    """Every unique icon on the bag's tan socket inside the gold ring a unique wears, and under it the
    same square blacked out, which is how the collection log draws one not yet found."""
    socket, gold = (0x8A, 0x6F, 0x4E, 0xFF), (0xE8, 0xB8, 0x3C, 0xFF)
    side, pad, cols = GEAR_SIDE + 8, 6, 9
    rows = (len(cut) + cols - 1) // cols
    band = 2 * side + 3 * pad
    out = Image.new("RGBA", (pad + cols * (side + pad), rows * band), (0xE8, 0xDC, 0xC0, 0xFF))
    for i, name in enumerate(cut):
        x, y = pad + (i % cols) * (side + pad), (i // cols) * band
        out.paste(Image.new("RGBA", (side, side), gold), (x, y + pad))
        out.paste(Image.new("RGBA", (side - 4, side - 4), socket), (x + 2, y + pad + 2))
        out.alpha_composite(cut[name], (x + 4, y + pad + 4))
        out.paste(Image.new("RGBA", (side, side), socket), (x, y + side + 2 * pad))
        dark = Image.new("RGBA", cut[name].size, (0, 0, 0, 0xFF))
        dark.putalpha(cut[name].getchannel("A"))
        out.alpha_composite(dark, (x + 4, y + side + 2 * pad + 4))
    return out.resize((out.width * 3, out.height * 3), Image.NEAREST)


def base_gear():
    """Every base, cut, drawn or marked missing as BASE_KINDS says, every one through `_outlined`.

    Nothing is read out of Assets/Gear, which is where these are written. A doubled icon stops the
    build, and so does one whose edge is not outline ink: see `_doubled` and `outline_share`.
    """
    generator = _generator()
    out = {}
    for _slot, tiers in BASE_KINDS.values():
        for tier in tiers:
            name, source = tier[0], tier[1]
            if source == DRAWN:
                art = _outlined(generator.ICONS[name]())
            elif source == MISSING:
                art = _outlined(_drawn(MISSING_MARK), own_edge=True)
            elif source[0].startswith(PIXELLAB_BASES):
                art = _plugged(_cut(source), BASE_HOLE_MOST)
                if name in BASE_TRANSPOSE:
                    art = art.transpose(Image.TRANSPOSE)
                if name in BASE_FILL:
                    art = _filled(art)
                fire = _fire(art) if name in BASE_FIRE else set()
                art = _outlined(_muted(art, fire), own_edge=True)
            else:
                art = _outlined(_cut(source))
            if len(tier) > 2:
                art = _shift(art, *BASE_TINTS[tier[2]])
            if _doubled(art):
                raise SystemExit("%s is doubled art: every 2x2 block of it is one colour" % name)
            if outline_share(art) < OUTLINE_FLOOR:
                raise SystemExit("%s: only %d%% of its edge is outline ink" % (name, 100 * outline_share(art)))
            if name in BASE_FIRE:
                # After the ink check: the glow is meant to sit outside the outline.
                art = _glowed(art, fire)
            out[name] = _squared(name, art.crop(art.getbbox()))
    return out


def _plugged(art, most):
    """`art` with every enclosed clear patch of at most `most` pixels filled with the darkest colour beside it: the
    shadow of the seam the drawing meant. A patch that reaches the edge of the art is outside it, and left alone."""
    out = art.copy()
    px = out.load()
    w, h = out.size
    clear = {(x, y) for y in range(h) for x in range(w) if px[x, y][3] < 128}
    seen = set()
    for start in sorted(clear):
        if start in seen:
            continue
        patch, todo, open_edge = [start], [start], False
        seen.add(start)
        while todo:
            x, y = todo.pop()
            if x in (0, w - 1) or y in (0, h - 1):
                open_edge = True
            for dx, dy in _FOUR:
                near = (x + dx, y + dy)
                if near in clear and near not in seen:
                    seen.add(near)
                    patch.append(near)
                    todo.append(near)
        if open_edge or len(patch) > most:
            continue
        rim = [px[x + dx, y + dy] for x, y in patch for dx, dy in _FOUR
               if 0 <= x + dx < w and 0 <= y + dy < h and (x + dx, y + dy) not in clear]
        fill = min(rim, key=lambda c: sum(c[:3]))
        for spot in patch:
            px[spot] = fill[:3] + (255,)
    return out


def _filled(art):
    """`art` stretched, nearest-neighbour, until its longer side is GEAR_SIDE: see BASE_FILL."""
    art = art.crop(art.getbbox())
    factor = GEAR_SIDE / max(art.size)
    return art.resize((round(art.width * factor), round(art.height * factor)), Image.NEAREST)


def base_old():
    """The icons the pixellab bases replaced, made as they were: see BASE_OLD."""
    out = {}
    for name, source in BASE_OLD.items():
        art = _outlined(_generator().ICONS[name]() if source == DRAWN else _cut(source))
        out[name] = _squared(name, art.crop(art.getbbox()))
    return out


def base_preview(cut):
    """Every base: a row to a kind, a column to a tier, grouped under their slot.

    Drawn at this size because the question is whether four tiers of one kind can be told apart at
    the 32 px the bag draws them at, whether a drawn piece can be picked out from a cut one, and
    whether a dagger still reads smaller than a sword. So the rows put a family side by side, and a
    cell says under its name where it came from.

    And at the right of every row the same four again at 1x, on the socket at the size the bag
    actually draws it. That strip is the one that settles it: three times life size flatters a
    drawing, and a tier that only separates when it is enlarged has not separated.
    """
    cream, socket, ink = (0xE8, 0xDC, 0xC0, 0xFF), (0x8A, 0x6F, 0x4E, 0xFF), (0x3B, 0x2A, 0x1E, 0xFF)
    faint = (0x8A, 0x78, 0x60, 0xFF)
    zoom, gutter, pad, label, head = 3, 104, 8, 24, 22
    side, life = (GEAR_SIDE + 8) * zoom, GEAR_SIDE + 8
    cell_w, cell_h = side + pad, side + label + pad
    columns = max(len(tiers) for _s, tiers in BASE_KINDS.values())
    slots = [slot for slot, _t in BASE_KINDS.values()]
    height = pad + len(BASE_KINDS) * cell_h + len(set(slots)) * head
    strip = pad + columns * (life + 2)
    out = Image.new("RGBA", (gutter + columns * cell_w + strip + pad, height), cream)
    draw = ImageDraw.Draw(out)
    y, shown = pad, None
    for kind, (slot, tiers) in BASE_KINDS.items():
        if slot != shown:
            draw.line([(pad, y + head - 6), (out.width - pad, y + head - 6)], fill=ink)
            draw.text((pad, y + 4), slot.upper(), fill=ink)
            draw.text((gutter + columns * cell_w + pad, y + 4), "AT 1X", fill=ink)
            y += head
            shown = slot
        draw.text((pad, y + side // 2 - 4), kind, fill=ink)
        for i, tier in enumerate(tiers):
            name, source = tier[0], tier[1]
            x = gutter + i * cell_w
            out.paste(Image.new("RGBA", (side, side), socket), (x, y))
            art = cut[name]
            out.alpha_composite(art.resize((GEAR_SIDE * zoom,) * 2, Image.NEAREST), (x + 4 * zoom, y + 4 * zoom))
            lx = gutter + columns * cell_w + pad + i * (life + 2)
            ly = y + (side - life) // 2
            out.paste(Image.new("RGBA", (life, life), socket), (lx, ly))
            out.alpha_composite(art, (lx + 4, ly + 4))
            draw.text((x, y + side + 2), name, fill=ink)
            draw.text((x, y + side + 13), {DRAWN: "drawn", MISSING: "no art yet"}.get(source, "cut from the pack")
                      if isinstance(source, str) else "pixellab" if source[0].startswith(PIXELLAB_BASES)
                      else "cut from the pack", fill=faint)
        y += cell_h
    return out


def orbs():
    """The orb icons, on the same GEAR_SIDE square the gear uses -- but centred on an even offset.

    That is the one thing the gear icons do not have to care about. OrbSlot draws an orb at half size, and
    a 2:1 step keeps whichever pixel column is even; an odd offset shifts the art into the other
    phase and the icon loses a column it did not have to lose. So the art is nudged to an even x and
    y, which costs at most one pixel of centring and is invisible beside what it buys.
    """
    out = {}
    for name, entry in ORBS.items():
        art = _cut(entry)
        if art.width > GEAR_SIDE or art.height > GEAR_SIDE:
            raise SystemExit("%s is %dx%d, too big for a %d square"
                             % (name, art.width, art.height, GEAR_SIDE))
        square = Image.new("RGBA", (GEAR_SIDE, GEAR_SIDE), (0, 0, 0, 0))
        square.alpha_composite(art, (((GEAR_SIDE - art.width) // 2) & ~1,
                                     ((GEAR_SIDE - art.height) // 2) & ~1))
        out[name] = square
    return out


def orb_preview(cut):
    """Every orb twice: at source size, and at the 16 px the tray actually draws it.

    Two rows rather than one because the question these icons raise is not whether they look good --
    they are a bought pack -- but whether they survive being halved, and whether eight of them in a
    row still read as eight different stones at that size. Only the bottom row can answer that.
    """
    socket = (0xCD, 0xA6, 0x77, 0xFF)
    order = list(ORBS)
    big, small, pad = GEAR_SIDE + 8, ORB_DRAWN + 8, 6
    width = pad + len(order) * (big + pad)
    out = Image.new("RGBA", (width, big + small + 3 * pad), (0xE5, 0xD6, 0xA1, 0xFF))
    for i, name in enumerate(order):
        x = pad + i * (big + pad)
        out.paste(Image.new("RGBA", (big, big), socket), (x, pad))
        out.alpha_composite(cut[name], (x + 4, pad + 4))
        # The tray's own size, on the tray's own square, centred under the big one.
        half = cut[name].resize((ORB_DRAWN, ORB_DRAWN), Image.NEAREST)
        sx = x + (big - small) // 2
        sy = big + 2 * pad
        out.paste(Image.new("RGBA", (small, small), socket), (sx, sy))
        out.alpha_composite(half, (sx + 4, sy + 4))
    return out.resize((out.width * 3, out.height * 3), Image.NEAREST)


def skills():
    """Every skill icon and the locked marks: the pixellab badge where a symbol has arrived (`SKILL_SYMBOLS`),
    otherwise the pack's whole file at its own 16 px."""
    out = {}
    frame = _corners_cut(_cut((SKILL_FRAME, 0, 0, SKILL_BADGE, SKILL_BADGE, 1), trim=False))
    for name, (tree, src) in SKILLS.items():
        if name in SKILL_SYMBOLS:
            out[name] = _badge(frame, tree, _cut((SKILL_PIXELLAB + name, 0, 0, SKILL_BADGE, SKILL_BADGE, 1)))
        else:
            out[name] = _cut((SKILL_ROOT + src, 0, 0, SKILL_SIDE, SKILL_SIDE, 1), trim=False)
    padlock = _cut((SKILL_PIXELLAB + SKILL_LOCK_SYMBOL, 0, 0, SKILL_BADGE, SKILL_BADGE, 1))
    for name in SKILL_LOCKS:
        out[name] = _badge(frame, name.removesuffix("_locked"), padlock)
    for name, image in out.items():
        if image.width != image.height or image.width not in (SKILL_SIDE, SKILL_BADGE):
            raise SystemExit("%s is %dx%d, not %d or %d square" % (name, image.width, image.height, SKILL_SIDE, SKILL_BADGE))
    return out


def _lightness(pixel):
    return (0.299 * pixel[0] + 0.587 * pixel[1] + 0.114 * pixel[2]) / 255


def _corners_cut(frame):
    """The skill frame with the near-black pixels its rounded corners leave outside the border cleared, flooding
    in from each corner but no further than SKILL_CORNER_REACH along either edge, so the dark ring down the sides
    stays as its edge."""
    out = frame.copy()
    px = out.load()
    w, h = out.size
    for cx, cy in ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1)):
        todo, seen = [(cx, cy)], set()
        while todo:
            x, y = todo.pop()
            if (x, y) in seen or not (0 <= x < w and 0 <= y < h):
                continue
            seen.add((x, y))
            if (abs(x - cx) >= SKILL_CORNER_REACH or abs(y - cy) >= SKILL_CORNER_REACH
                    or _lightness(px[x, y]) > SKILL_CORNER_DARKEST):
                continue
            px[x, y] = (0, 0, 0, 0)
            todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    return out


def _badge(frame, tree, symbol):
    """`symbol` (trimmed) centred on the frame tinted for `tree`: every pixel's lightness mapped along
    SKILL_TINTS[tree], so the bevel keeps its light and shade in the tree's colours."""
    out = frame.copy()
    px = out.load()
    stops = [(at, _rgb(colour)[:3]) for at, colour in SKILL_TINTS[tree]]
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if not a:
                continue
            v = _lightness((r, g, b))
            colour = stops[-1][1]
            for (l0, c0), (l1, c1) in zip(stops, stops[1:]):
                if v <= l1:
                    t = 0.0 if l1 == l0 else min(max((v - l0) / (l1 - l0), 0.0), 1.0)
                    colour = tuple(round(c0[i] + (c1[i] - c0[i]) * t) for i in range(3))
                    break
            px[x, y] = colour + (a,)
    out.alpha_composite(symbol, ((out.width - symbol.width) // 2, (out.height - symbol.height) // 2))
    return out


def skill_preview(cut):
    """Every tree on the cream panel at the 2x they are drawn at, laid out as the sketch is.

    Each tree is shown twice: the left copy fresh, where only the root is open and everything else
    wears the locked mark, and the right copy part-spent, which is the only state worth judging whether
    twenty icons read as twenty different skills.
    """
    cream, ink, lit = (0xE5, 0xD6, 0xA1, 0xFF), (0x3B, 0x2A, 0x1E, 0xFF), (0xE8, 0xB7, 0x3A, 0xFF)
    side, gap_x, gap_y, pad = SKILL_SIDE * 2, 18, 18, 12
    tree_w = 3 * side + 2 * gap_x
    tree_h = 5 * side + 4 * gap_y
    learned = {"sharpened_edge", "keen_eye", "battle_rhythm", "flurry",
               "scavenger", "appraiser", "prospector", "fortunes_favour", "greed", "midas",
               "toughness", "footwork", "resolve", "shield_mastery", "bastion"}
    out = Image.new("RGBA", (pad + 2 * len(SKILL_LAYOUT) * (tree_w + pad), tree_h + 2 * pad), cream)
    draw = ImageDraw.Draw(out)

    def centre(ox, row, col):
        return ox + col * (side + gap_x) + side // 2, pad + row * (side + gap_y) + side // 2

    for copy, (tree, nodes) in [(c, t) for t in SKILL_LAYOUT.items() for c in (0, 1)]:
        index = list(SKILL_LAYOUT).index(tree)
        ox = pad + (index * 2 + copy) * (tree_w + pad)
        ranked = learned if copy else set()
        place = {n: (r, c) for n, r, c, _p in nodes}
        for name, row, col, parents in nodes:
            for parent in parents:
                colour = lit if parent in ranked else ink
                draw.line([centre(ox, *place[parent]), centre(ox, row, col)], fill=colour, width=2)
        for name, row, col, parents in nodes:
            open_ = not parents or any(p in ranked for p in parents)
            icon = cut[name] if open_ else cut[tree + "_locked"]
            if name not in ranked:
                # Greyed like the game's SkillSlot: locked and open alike, until a point goes in.
                shape = icon.getchannel("A")
                icon = Image.blend(icon, Image.new("RGBA", icon.size, (0x60, 0x60, 0x60, 0xFF)), 0.45)
                icon.putalpha(shape)
            x, y = centre(ox, row, col)
            out.alpha_composite(icon.resize((side, side), Image.NEAREST), (x - side // 2, y - side // 2))
    return out.resize((out.width * 2, out.height * 2), Image.NEAREST)


# The doll behind the sockets: the user's pixellab knight (2026-09-23, 128x128, low detail), which took the place
# of the pack's 43x46 figure ("2D Pixel UI/PNG/Equipment", 50, 336) so the backdrop has the new gear's shading.
# It is put onto the old figure's six browns by lightness -- equal shares darkest to lightest, so it keeps its
# relief and loses its colours and its contrast, which a backdrop behind translucent sockets must -- and stretched
# to DOLL_SIDE high, nearest-neighbour (x1.13), so its shield, head, body and feet sit under the sockets. It is
# drawn at 1x (bag_page's DOLL_SCALE), the icons' own pixel size.
DOLL_SOURCE = "doll-pixellab.png"
DOLL_SIDE = 128
DOLL_RAMP = [(0x51, 0x2C, 0x24), (0x58, 0x31, 0x26), (0x60, 0x39, 0x28),
             (0x67, 0x40, 0x28), (0x70, 0x49, 0x2A), (0x78, 0x51, 0x2C)]


def doll():
    """The doll figure: DOLL_SOURCE in DOLL_RAMP's browns, filling a DOLL_SIDE square top to bottom."""
    src = Image.open(os.path.join(POTENTIAL, DOLL_SOURCE)).convert("RGBA")
    px = src.load()
    spots = sorted(((x, y) for y in range(src.height) for x in range(src.width) if px[x, y][3] >= 128),
                   key=lambda spot: colorsys.rgb_to_hls(*[v / 255 for v in px[spot][:3]])[1])
    figure = Image.new("RGBA", src.size, (0, 0, 0, 0))
    for i, spot in enumerate(spots):
        figure.putpixel(spot, DOLL_RAMP[i * len(DOLL_RAMP) // len(spots)] + (255,))
    figure = figure.crop(figure.getbbox())
    factor = DOLL_SIDE / figure.height
    figure = figure.resize((round(figure.width * factor), DOLL_SIDE), Image.NEAREST)
    out = Image.new("RGBA", (DOLL_SIDE, DOLL_SIDE), (0, 0, 0, 0))
    out.alpha_composite(figure, ((DOLL_SIDE - figure.width) // 2, 0))
    return out


def parts():
    """The equipment screen's furniture, each at its own size -- nothing here sits in a grid."""
    out = {name: _cut(entry) for name, entry in PARTS.items()}
    out["ui_doll"] = doll()
    return out


def _drawn(rows):
    """One ICONS_DRAWN mark as an image in Icons.png's colours."""
    lines = [line.strip() for line in rows.strip().splitlines()]
    art = Image.new("RGBA", (max(len(line) for line in lines), len(lines)), (0, 0, 0, 0))
    for y, line in enumerate(lines):
        for x, char in enumerate(line):
            if char != ".":
                art.putpixel((x, y), _rgb(ICON_KEY[char]))
    return art


def icons():
    """The square buttons' marks, recoloured to the pack's cream and centred on one ICON_SIDE square.

    Centred on a shared square rather than left at their measured sizes because a Button takes its
    minimum size from its icon: the chest is 12x11 and the star 13x12, so two buttons wearing them
    raw would be two different sizes standing side by side.
    """
    table = {_rgb(dark): _rgb(light) for dark, light in BONE_RAMP.items()}
    marks = {name: _cut(entry) for name, entry in ICONS.items()}
    marks.update({name: _drawn(rows) for name, rows in ICONS_DRAWN.items()})
    green = {_rgb(dark): _rgb(lit) for dark, lit in GREEN_KEY.items()}
    out = {}
    for name, art in marks.items():
        if art.width > ICON_SIDE or art.height > ICON_SIDE:
            raise SystemExit("%s is %dx%d, too big for a %d square"
                             % (name, art.width, art.height, ICON_SIDE))
        out[name] = _squared_mark(_map_colors(art, table))
        # Bare on cream the mark keeps the pack's own brown, and an open tab turns green.
        if name in BARE:
            out[name + "_brown"] = _squared_mark(art)
        if name in GREEN_TABS:
            out[name + "_green"] = _squared_mark(_map_colors(art, green))
    return out


def _squared_mark(art):
    square = Image.new("RGBA", (ICON_SIDE, ICON_SIDE), (0, 0, 0, 0))
    square.alpha_composite(art, ((ICON_SIDE - art.width) // 2, (ICON_SIDE - art.height) // 2))
    return square


def notches():
    """The frame's wobbles, each patch cut whole at its own size."""
    return {name: _cut(entry, trim=False) for name, entry in NOTCHES.items()}


def bare_preview(cut, sprites, margins):
    """Every bare mark on the cream body, brown over green, at 1x and 3x: do they read with no face?"""
    pad = 4
    names = [name for name in cut if name.endswith("_brown")]
    cell = ICON_SIDE + pad
    out = nine_slice(sprites["ui_panel_white"], margins["ui_panel_white"],
                     (2 * pad + len(names) * cell, 2 * pad + 2 * cell))
    for col, name in enumerate(names):
        out.alpha_composite(cut[name], (pad + col * cell, pad))
        lit = name[:-len("_brown")] + "_green"
        if lit in cut:
            out.alpha_composite(cut[lit], (pad + col * cell, pad + cell))
    big = out.resize((out.width * 3, out.height * 3), Image.NEAREST)
    both = Image.new("RGBA", (out.width + pad + big.width, big.height), (0, 0, 0, 0))
    both.alpha_composite(out, (0, 0))
    both.alpha_composite(big, (out.width + pad, 0))
    return both


# The pitch UITheme.notched lays the patches at, in panel pixels, and this file's copy of the
# arithmetic so the preview shows what the game will: left and right alternate their two patches
# down the edge, staggered against each other, and the bottom cycles its three along. A patch is
# placed only where it fits clear of the corners.
NOTCH_PITCH = 40
NOTCH_STAGGER = 20
NOTCH_BOTTOM_PITCH = 36
NOTCH_START = 10
NOTCH_CLEAR = 8
NOTCH_BAR_PITCH = 56


def notch_places(cut, size, bar=False):
    places = []
    w, h = size
    if bar:
        patch = cut["ui_notch_bar_a"]
        x = NOTCH_START
        while x + patch.width <= w - NOTCH_CLEAR:
            places.append(("ui_notch_bar_a", x, 0))
            x += NOTCH_BAR_PITCH
        return places
    for side, start in (("left", NOTCH_START), ("right", NOTCH_START + NOTCH_STAGGER)):
        y, i = start, 0
        while True:
            name = "ui_notch_%s_%s" % (side, "ab"[i % 2])
            patch = cut[name]
            if y + patch.height > h - NOTCH_CLEAR:
                break
            places.append((name, 0 if side == "left" else w - patch.width, y))
            y += NOTCH_PITCH
            i += 1
    x, i = NOTCH_START, 0
    while True:
        name = "ui_notch_bottom_%s" % "abc"[i % 3]
        patch = cut[name]
        if x + patch.width > w - NOTCH_CLEAR:
            break
        places.append((name, x, h - patch.height))
        x += NOTCH_BOTTOM_PITCH
        i += 1
    return places


def notch_preview(cut, sprites, margins):
    """A headed body under its bar with the patches laid along its edges as UITheme.notched lays
    them, beside the same body bare, at 3x: the one question is whether a patch vanishes into the
    frame it covers."""
    size = (120, 150)
    pad = 6
    out = Image.new("RGBA", (2 * size[0] + 3 * pad, size[1] + 13 + 2 * pad), (0x2A, 0x28, 0x32, 0xFF))
    for col in range(2):
        x = pad + col * (size[0] + pad)
        bar = nine_slice(sprites["ui_bar_green"], margins["ui_bar_green"], (size[0], 13))
        body = nine_slice(sprites["ui_panel_headed"], margins["ui_panel_headed"], size)
        if col == 1:
            for name, dx, dy in notch_places(cut, (size[0], 13), bar=True):
                bar.alpha_composite(cut[name], (dx, dy))
            for name, dx, dy in notch_places(cut, size):
                body.alpha_composite(cut[name], (dx, dy))
        out.alpha_composite(bar, (x, pad))
        out.alpha_composite(body, (x, pad + 13))
    return out.resize((out.width * 3, out.height * 3), Image.NEAREST)


def keys():
    """The item card's keys, trimmed to their own faces."""
    w, h = KEY_CELL
    return {name: _cut((KEY_SHEET, col * w, row * h, w, h, 1)) for name, (col, row) in KEYS.items()}


def key_preview(cut, sprites, margins):
    """Each key on the cream card and on wood, at 1x and 3x: does a dark key read beside body text?"""
    pad = 4
    widest = max(image.width for image in cut.values())
    tallest = max(image.height for image in cut.values())
    cell = (widest + 2 * pad, tallest + 2 * pad)
    out = Image.new("RGBA", (2 * cell[0], len(cut) * cell[1]), (0, 0, 0, 0))
    for col, panel in enumerate(("ui_panel_white", "ui_panel_wood")):
        face = nine_slice(sprites[panel], margins[panel], (cell[0], len(cut) * cell[1]))
        out.alpha_composite(face, (col * cell[0], 0))
        for row, image in enumerate(cut.values()):
            out.alpha_composite(image, (col * cell[0] + pad, row * cell[1] + pad))
    big = out.resize((out.width * 3, out.height * 3), Image.NEAREST)
    both = Image.new("RGBA", (out.width + pad + big.width, big.height), (0, 0, 0, 0))
    both.alpha_composite(out, (0, 0))
    both.alpha_composite(big, (out.width + pad, 0))
    return both


def character():
    """The character panel's frame, portrait and three bars, plus the XP gem, each at its own size."""
    sheet = Image.open(os.path.join(POTENTIAL, CHAR_SHEET + ".png")).convert("RGBA")
    fx, fy, fw, fh = CHAR_FRAME
    frame = sheet.crop((fx, fy, fx + fw, fy + fh))
    out = {"ui_char_frame": frame}
    for name, (x, y, w) in CHAR_BARS.items():
        sx, sy = fx + CHAR_FILLED_DX + x, fy + y
        bar = sheet.crop((sx, sy, sx + w, sy + CHAR_BAR_HEIGHT))
        if bar.getchannel("A").getextrema()[0] == 0:
            raise SystemExit("ui_char_bar_%s has a hole -- the bar rectangle is off" % name)
        if frame.crop((x, y, x + w, y + CHAR_BAR_HEIGHT)).tobytes() == bar.tobytes():
            raise SystemExit("ui_char_bar_%s is the empty trough -- the filled panel moved" % name)
        out["ui_char_bar_" + name] = bar

    # The circle: every transparent pixel joined to the seed.
    alpha = frame.getchannel("A")
    circle, todo = set(), [CHAR_CIRCLE_SEED]
    while todo:
        x, y = todo.pop()
        if (x, y) in circle or not (0 <= x < fw and 0 <= y < fh) or alpha.getpixel((x, y)):
            continue
        circle.add((x, y))
        todo += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
    left = min(x for x, _ in circle)
    top = min(y for _, y in circle)
    width = max(x for x, _ in circle) - left + 1
    height = max(y for _, y in circle) - top + 1
    path, kx, ky = CHAR_KOBOLD
    kobold = Image.open(path).convert("RGBA")
    portrait = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for x, y in circle:
        pixel = Image.new("RGBA", (1, 1), CHAR_DISC)
        pixel.alpha_composite(Image.new("RGBA", (1, 1), kobold.getpixel((kx + x - left, ky + y - top))))
        portrait.putpixel((x - left, y - top), pixel.getpixel((0, 0)))
    out["ui_char_portrait"] = portrait
    out["xp_gem"] = _cut(XP_GEM, trim=False)
    return out, (left, top)


def character_preview(cut, portrait_at):
    """The assembled panel at full, half and nearly empty XP, and the gem at 1x and 4x."""
    frame = cut["ui_char_frame"]
    shares = [1.0, 0.5, 0.05]
    pad = 6
    out = Image.new("RGBA", (frame.width + 2 * pad, len(shares) * (frame.height + pad) + pad + 30),
                    (0x3C, 0x5A, 0x3C, 0xFF))
    for i, share in enumerate(shares):
        y0 = pad + i * (frame.height + pad)
        panel = frame.copy()
        panel.alpha_composite(cut["ui_char_portrait"], portrait_at)
        for name, (x, y, w) in CHAR_BARS.items():
            bar = cut["ui_char_bar_" + name]
            shown = w if name != "xp" else max(1, round(w * share))
            panel.alpha_composite(bar.crop((0, 0, shown, CHAR_BAR_HEIGHT)), (x, y))
        out.alpha_composite(panel, (pad, y0))
    gem = cut["xp_gem"]
    gy = pad + len(shares) * (frame.height + pad)
    out.alpha_composite(gem, (pad, gy))
    out.alpha_composite(gem.resize((gem.width * 4, gem.height * 4), Image.NEAREST), (pad + 12, gy))
    return out.resize((out.width * 4, out.height * 4), Image.NEAREST)


def pips():
    """The three parts a kill-pip bar is built from, in each tier's colourway and in empty grey.

    A tier is cut off the full capsule and "empty" off the empty one, at the same columns: the pack
    draws both to the same geometry, so the parts line up whichever state a pip is in.
    """
    out = {}
    # The empty capsule is the same grey in every band, so it is cut once, off the first one.
    wanted = [(tier, PIP_FULL_X, band) for tier, band in PIP_BANDS.items()]
    wanted.append(("empty", PIP_EMPTY_X, list(PIP_BANDS.values())[0]))
    for key, x, band in wanted:
        out["ui_pip_head_" + key] = _column(x + PIP_HEAD[0], band, PIP_HEAD[1])
        out["ui_pip_body_" + key] = _column(x + PIP_BODY[0], band, PIP_BODY[1])
        out["ui_pip_tail_" + key] = _tail(x, band)
    for name, image in out.items():
        want = PIP_WIDTHS[name.split("_")[2]]
        if image.size != (want, PIP_HEIGHT):
            raise SystemExit("%s is %dx%d, not %dx%d -- the bar would not join up"
                             % (name, image.width, image.height, want, PIP_HEIGHT))
    return out


def _column(x, y, width):
    """A slice of the capsule, full height and never trimmed."""
    return _cut((PIP_SHEET, x, y, width, PIP_HEIGHT, 1), trim=False)


def _tail(x, band):
    """The column that closes a fill off, then the pack's rounded right end behind it.

    The end always comes off the empty capsule, whatever colourway the fill is: the pack leaves that
    stub grey even on its own full bar, and copying it is what makes an assembled bar look drawn
    rather than extended.
    """
    out = Image.new("RGBA", (PIP_WIDTHS["tail"], PIP_HEIGHT), (0, 0, 0, 0))
    out.paste(_column(x + PIP_TAIL_CLOSE, band, 1), (0, 0))
    out.paste(_column(PIP_EMPTY_X + PIP_TAIL_END[0], band, PIP_TAIL_END[1]), (1, 0))
    return out


def pip_bar(cut, tiers):
    """One assembled bar, the way KillPips assembles it: head, bodies, tail.

    `tiers` is one entry a pip, a tier name or None for a pip whose enemy is down.
    """
    parts = [cut["ui_pip_%s_%s" % ("head" if i == 0 else "body", t if t else "empty")]
             for i, t in enumerate(tiers)]
    parts.append(cut["ui_pip_tail_%s" % (tiers[-1] if tiers[-1] else "empty")])
    out = Image.new("RGBA", (sum(p.width for p in parts), PIP_HEIGHT), (0, 0, 0, 0))
    x = 0
    for part in parts:
        out.paste(part, (x, 0))
        x += part.width
    return out


def pip_preview(cut):
    """The assembled bar draining, every state from ten pips down to none.

    The question only eyes can answer is whether the parts butt together without a seam, and whether
    the elite's green at the far end still reads once there is one pip left. Drawn on the wood
    panel's own brown, which is what the HUD stands it on.
    """
    line = ["common"] * 9 + ["elite"]
    bars = [pip_bar(cut, [None] * k + line[k:]) for k in range(len(line) + 1)]
    pad, gap = 4, 2
    out = Image.new("RGBA", (2 * pad + bars[0].width, 2 * pad + len(bars) * (PIP_HEIGHT + gap) - gap),
                    (0x6B, 0x4A, 0x32, 0xFF))
    for i, bar in enumerate(bars):
        out.alpha_composite(bar, (pad, pad + i * (PIP_HEIGHT + gap)))
    return out.resize((out.width * 5, out.height * 5), Image.NEAREST)


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


def icon_preview(cut, sprites, margins):
    """Both marks on the brown face, in all four states, on grass.

    On grass rather than on a flat swatch because that is where these two buttons stand -- the map,
    not a panel -- and the question they raise is whether a cream mark on a brown face reads there.
    The face is nine-sliced to the size the game draws it at, so the preview also shows the one
    thing a wrong margin would give away: a seam down the middle of a square button.
    """
    side = ICON_SIDE + 2 * ICON_PAD
    pad = 6
    names = list(cut)
    out = Image.new("RGBA", (pad + len(STATE_ORDER) * (side + pad), pad + len(names) * (side + pad)),
                    (0x3A, 0x54, 0x34, 0xFF))
    for row, name in enumerate(names):
        for col, state in enumerate(STATE_ORDER):
            sprite = "ui_btn_brown_" + state
            face = nine_slice(sprites[sprite], margins[sprite], (side, side))
            # Pressed draws the face a pixel lower, so the mark on it drops with it.
            face.alpha_composite(cut[name], (ICON_PAD, ICON_PAD + (1 if state == "pressed" else 0)))
            out.alpha_composite(face, (pad + col * (side + pad), pad + row * (side + pad)))
    return out.resize((out.width * 4, out.height * 4), Image.NEAREST)


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

    for name, image in parts().items():
        image.save(os.path.join(OUT, name + ".png"))

    unique = unique_gear()
    unique_preview(unique).save(os.path.join(QA, "ui_kit_uniques.png"))
    if UNIQUE_EXPORT:
        os.makedirs(UNIQUE_OUT, exist_ok=True)
        for name, image in unique.items():
            image.save(os.path.join(UNIQUE_OUT, name + ".png"))
        os.makedirs(UNIQUE_OLD_OUT, exist_ok=True)
        for name, image in unique_old().items():
            image.save(os.path.join(UNIQUE_OLD_OUT, name + ".png"))


    bases = base_gear()
    base_preview(bases).save(os.path.join(QA, "ui_kit_bases.png"))
    if BASES_EXPORT:
        for name, image in bases.items():
            image.save(os.path.join(GEAR_OUT, name + ".png"))
        os.makedirs(BASE_OLD_OUT, exist_ok=True)
        for name, image in base_old().items():
            image.save(os.path.join(BASE_OLD_OUT, name + ".png"))

    # Loose as well, and for the same reason the parts are: a mark is drawn at its own size and the
    # face behind it is what stretches.
    mark = icons()
    icon_preview(mark, sprites, margins).save(os.path.join(QA, "ui_kit_icons.png"))
    bare_preview(mark, sprites, margins).save(os.path.join(QA, "ui_kit_bare.png"))
    for name, image in mark.items():
        image.save(os.path.join(OUT, name + ".png"))

    # Loose too: a patch is laid over a frame at its own size, never stretched.
    notch = notches()
    notch_preview(notch, sprites, margins).save(os.path.join(QA, "ui_kit_notches.png"))
    for name, image in notch.items():
        image.save(os.path.join(OUT, name + ".png"))

    # Loose too, and at their own size: a key is drawn beside a word, never on a button.
    key = keys()
    key_preview(key, sprites, margins).save(os.path.join(QA, "ui_kit_keys.png"))
    for name, image in key.items():
        image.save(os.path.join(OUT, name + ".png"))

    # Their own folder, not Assets/Gear: an orb is not a piece of gear and OrbTable loads it by its
    # own ROOT. Unlike GEAR_OUT this one is made here, because it did not exist before this chunk.
    os.makedirs(ORB_OUT, exist_ok=True)
    orb = orbs()
    orb_preview(orb).save(os.path.join(QA, "ui_kit_orbs.png"))
    for name, image in orb.items():
        image.save(os.path.join(ORB_OUT, name + ".png"))

    # Their own folder too: SkillTree loads them by path, and a skill is neither gear nor an orb.
    os.makedirs(SKILL_OUT, exist_ok=True)
    skill = skills()
    skill_preview(skill).save(os.path.join(QA, "ui_kit_skills.png"))
    for name, image in skill.items():
        image.save(os.path.join(SKILL_OUT, name + ".png"))

    # Hers, in their own folder for the same reason: TownPage loads them by path, and a reading is
    # neither a skill nor an orb. Cut like the skills -- whole files, their own frame, nothing trimmed.
    os.makedirs(FORTUNE_OUT, exist_ok=True)
    frame = _corners_cut(_cut((SKILL_FRAME, 0, 0, SKILL_BADGE, SKILL_BADGE, 1), trim=False))
    for name, src in FORTUNE.items():
        if name in FORTUNE_SYMBOLS:
            spell = _badge(frame, "teller", _cut((FORTUNE_PIXELLAB + name, 0, 0, SKILL_BADGE, SKILL_BADGE, 1)))
        else:
            spell = _cut((SKILL_ROOT + src, 0, 0, SKILL_SIDE, SKILL_SIDE, 1), trim=False)
        spell.save(os.path.join(FORTUNE_OUT, name + ".png"))

    # Loose, like the parts: a pip is drawn at its own size and never stretched, so it has no
    # nine-slice and no business in the theme sheet.
    pip = pips()
    pip_preview(pip).save(os.path.join(QA, "ui_kit_pips.png"))
    for name, image in pip.items():
        image.save(os.path.join(OUT, name + ".png"))

    # Loose as well: the frame and its bars are drawn at their own size, and the bars are clipped
    # rather than stretched as they empty.
    char, portrait_at = character()
    character_preview(char, portrait_at).save(os.path.join(QA, "ui_kit_character.png"))
    for name, image in char.items():
        image.save(os.path.join(OUT, name + ".png"))
    print("character panel: portrait at %s, %s" % (portrait_at, ", ".join(
        "%s %dx%d" % (n, i.width, i.height) for n, i in char.items())))

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
    print("wrote %d unique icons %s and %s/ui_kit_uniques.png"
          % (len(unique), "to %s/" % UNIQUE_OUT if UNIQUE_EXPORT else "to the preview only", QA))
    print("wrote %d base icons %s and %s/ui_kit_bases.png"
          % (len(bases), "to %s/" % GEAR_OUT if BASES_EXPORT else "to the preview only", QA))
    print("wrote %d kill pips to %s/ and %s/ui_kit_pips.png" % (len(pip), OUT, QA))
    print("wrote %d orb icons to %s/ and %s/ui_kit_orbs.png" % (len(orb), ORB_OUT, QA))
    print("wrote %d button marks to %s/ and %s/ui_kit_icons.png" % (len(mark), OUT, QA))
    print("wrote %d keys to %s/ and %s/ui_kit_keys.png" % (len(key), OUT, QA))


if __name__ == "__main__":
    main()
