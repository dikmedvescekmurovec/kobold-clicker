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

# The unique items' icons, keyed by `UniqueTable`'s ids and written to Assets/Gear/Unique. Nine come
# straight off the RPG pack, which draws more gear than the eight base pieces use. The pack draws no
# ring and no amulet, and Icons.png draws one of each, so the four unique jewels are those two
# recoloured -- and recoloured by *part*, not whole: turning the whole ring's hue makes a band no
# metal is. Each recolour names the band of hues it moves (the ring's gold is 0.05-0.17, its stone
# 0.55-0.72; the amulet's stone and setting are 0.95-0.12), what it adds to the hue, and what it
# multiplies the saturation and the lightness by.
#
# id -> (a source 6-tuple, [(hue_low, hue_high, hue_add, sat_mul, light_mul), ...][, (grey_hue, grey_sat)])
_RING = ("2D Pixel UI/PNG/Icons", 82, 130, 12, 12, 2)
_AMULET = ("2D Pixel UI/PNG/Icons", 3, 146, 10, 12, 2)
_RPG = "Pixel Art Icon Pack - RPG/"
UNIQUE_GEAR = {
    "metronome": ((_RPG + "Weapon & Tool/Silver Sword", 0, 0, 32, 32, 1), []),
    "headsman": ((_RPG + "Weapon & Tool/Axe", 0, 0, 32, 32, 1), []),
    # A band of bone: the gold drained and lifted, the stone left as it is.
    "knucklebone_ring": (_RING, [(0.0, 0.2, 0.0, 0.25, 1.35)]),
    # Gold with a ruby in it, where the plain ring carries a sapphire.
    "the_tithe": (_RING, [(0.5, 0.75, 0.38, 1.0, 1.0)]),
    # Glass and pale sand.
    "hourglass_amulet": (_AMULET, [(0.9, 1.0, 0.5, 0.8, 1.1), (0.0, 0.15, 0.5, 0.8, 1.1)]),
    "meadowstriders": ((_RPG + "Equipment/Iron Boot", 0, 0, 32, 32, 1), []),
    "hunters_lantern": ((_RPG + "Misc/Lantern", 0, 0, 32, 32, 1), []),
    "sunscorched_cowl": ((_RPG + "Equipment/Helm", 0, 0, 32, 32, 1), []),
    "rimeplate": ((_RPG + "Equipment/Iron Armor", 0, 0, 32, 32, 1), []),
    "stonebreaker": ((_RPG + "Weapon & Tool/Hammer", 0, 0, 32, 32, 1), []),
    # Grave-violet.
    "gravediggers_charm": (_AMULET, [(0.9, 1.0, 0.78, 0.9, 0.85), (0.0, 0.15, 0.78, 0.9, 0.85)]),
    # --- the second batch ---
    # Blood-red iron, the sapphire left in it.
    "berserkers_band": (_RING, [(0.0, 0.2, -0.09, 1.2, 0.9)]),
    # The pack's plain iron sword with its greys turned to pale blue glass: a third element is
    # (hue, saturation) for the pixels `_shift` otherwise leaves alone.
    "glass_edge": ((_RPG + "Weapon & Tool/Iron Sword", 0, 0, 32, 32, 1), [], (0.55, 0.5)),
    # No pack draws a die: a green stone, the gambler's colour.
    "gamblers_die": (_AMULET, [(0.9, 1.0, 0.33, 0.9, 1.0), (0.0, 0.15, 0.33, 0.9, 1.0)]),
    "ascetics_cord": ((_RPG + "Material/Rope", 0, 0, 32, 32, 1), []),
    "last_gasp": ((_RPG + "Monster Part/Skull", 0, 0, 32, 32, 1), []),
    "duelists_buckler": ((_RPG + "Weapon & Tool/Iron Shield", 0, 0, 32, 32, 1), []),
    # The nearest thing to a chalice running over.
    "overflowing_chalice": ((_RPG + "Food/Beer", 0, 0, 32, 32, 1), []),
    # Off Icons.png like the ring and the amulet, measured and doubled: row 7's blue boots, row 6's
    # steel cuirass and row 8's steel shield.
    "dominoes": (("2D Pixel UI/PNG/Icons", 50, 113, 12, 14, 2), []),
    "snowball": (("2D Pixel UI/PNG/Icons", 82, 98, 12, 12, 2), []),
    "packmule": ((_RPG + "Equipment/Bag", 0, 0, 32, 32, 1), []),
    "bulwark": (("2D Pixel UI/PNG/Icons", 19, 130, 10, 12, 2), []),
    # The base piece's own wood, stained to the red of the heart of the tree.
    "heartwood_plate": ((_RPG + "Equipment/Wooden Armor", 0, 0, 32, 32, 1), [(0.0, 0.2, -0.06, 1.35, 0.8)]),
    "spiked_helm": ((_RPG + "Equipment/Iron Helmet", 0, 0, 32, 32, 1), []),
    # Black and white, as the bird is: the gold drained and darkened.
    "magpies_band": (_RING, [(0.0, 0.2, 0.0, 0.15, 0.5)]),
    "lucky_wound": ((_RPG + "Misc/Candle", 0, 0, 32, 32, 1), []),
    # The pack calls this strapped pack its leather armour; it is drawn as a sack.
    "rag_and_bone_sack": ((_RPG + "Equipment/Leather Armor", 0, 0, 32, 32, 1), []),
}
UNIQUE_OUT = "Assets/Gear/Unique"
# The ten of those that are doubled Icons.png art -- four rings, three amulets, the boots, the
# cuirass and the shield -- drawn instead by AI-sprites-generator/gear.py (its UNIQUES, by the same
# ids), the way the base jewels were and for the same reason. They were approved on their own flag,
# which is on: the drawn ones are what is written, and their ten entries in UNIQUE_GEAR are kept only
# so tools/qa/ui_kit_uniques_drawn.png can still show what each one replaced.
UNIQUE_DRAWN = ["knucklebone_ring", "the_tithe", "berserkers_band", "magpies_band", "hourglass_amulet",
                "gravediggers_charm", "gamblers_die", "dominoes", "snowball", "bulwark"]
UNIQUE_DRAWN_EXPORT = True
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
_RPG_ZIP = "Pixel Art Icon Pack - RPG.zip!"
BASE_KINDS = {
    # The pack draws an iron sword and a golden one, plain and jewelled, and the wooden one is on
    # disk; the steel one between them is drawn -- fullered, wrapped, a knobbed guard. (The pack's
    # Silver Sword is the obvious steel and is left alone: it is metronome, unrecoloured.)
    "sword": ("Weapon", [
        ("Wooden Sword", (_RPG_ZIP + "Weapon & Tool/Wooden Sword", 0, 0, 32, 32, 1)), ("Iron Sword", (_RPG + "Weapon & Tool/Iron Sword", 0, 0, 32, 32, 1)),
        ("Steel Sword", DRAWN), ("Golden Sword", (_RPG + "Weapon & Tool/Golden Sword", 0, 0, 32, 32, 1))]),
    # All four drawn, and short. The pack's Knife was the iron tier until it stood in the row: it
    # is 28 px corner to corner, the same as the sword above it, and a dagger has to read small
    # before it reads as anything else.
    "dagger": ("Weapon", [
        ("Bone Knife", DRAWN), ("Iron Dagger", DRAWN), ("Steel Stiletto", DRAWN), ("Golden Kris", DRAWN)]),
    # Four heads, because the four names promise four weapons. The pack's Hammer is stonebreaker.
    "mace": ("Weapon", [
        ("Wooden Club", DRAWN), ("Iron Mace", DRAWN), ("Steel Morningstar", DRAWN), ("Golden Sceptre", DRAWN)]),
    # The pack's swords already run corner to corner, so a two-hander cannot be longer: it is
    # heavier -- half again the blade, a grip for two hands, a guard right across the square.
    "greatsword": ("Weapon", [
        ("Wooden Greatsword", DRAWN), ("Iron Claymore", DRAWN),
        ("Steel Zweihander", DRAWN), ("Golden Greatsword", DRAWN)]),

    "shield": ("Offhand", [
        ("Wooden Shield", (_RPG_ZIP + "Weapon & Tool/Wooden Shield", 0, 0, 32, 32, 1)), ("Iron Shield", DRAWN), ("Steel Kite Shield", DRAWN), ("Golden Aegis", DRAWN)]),
    "buckler": ("Offhand", [
        ("Hide Buckler", DRAWN), ("Iron Buckler", DRAWN), ("Steel Targe", DRAWN), ("Golden Buckler", DRAWN)]),
    # Two tiers. The second was the pack torch with its own flame grown by code (`_blaze`), and was
    # turned down twice for still being the first one: it is drawn now, a caged brand with a fire
    # three times the size.
    "torch": ("Offhand", [("Wooden Torch", (_RPG + "Weapon & Tool/Torch", 0, 0, 32, 32, 1)), ("Blazing Torch", DRAWN)]),

    # The pack's three helmets are a ladder as they stand -- a cap, an open-faced helmet, a great
    # helm -- and the gold one is the user's own 32 px pixellab piece, golden-helm.png.
    "helm": ("Helmet", [
        ("Leather Helmet", (_RPG + "Equipment/Leather Helmet", 0, 0, 32, 32, 1)), ("Iron Helmet", (_RPG + "Equipment/Iron Helmet", 0, 0, 32, 32, 1)),
        ("Steel Helm", (_RPG + "Equipment/Helm", 0, 0, 32, 32, 1)), ("Golden Helm", ("golden-helm", 0, 0, 32, 32, 1))]),
    "hood": ("Helmet", [
        ("Hide Hood", DRAWN), ("Leather Hood", DRAWN), ("Studded Hood", DRAWN), ("Shadow Hood", DRAWN)]),
    # The pack's one hat is the second rung, dyed the blue its name has always meant here; the
    # drawn ones are built the way it is, shorter below it and taller and busier above.
    "hat": ("Helmet", [
        ("Apprentice Hat", DRAWN), ("Wizard Hat", (_RPG + "Equipment/Wizard Hat", 0, 0, 32, 32, 1), "silk"),
        ("Sage's Hat", DRAWN), ("Archmage's Hat", DRAWN)]),

    "plate": ("Body", [
        ("Wooden Armor", (_RPG + "Equipment/Wooden Armor", 0, 0, 32, 32, 1)), ("Iron Armor", (_RPG + "Equipment/Iron Armor", 0, 0, 32, 32, 1)),
        ("Steel Plate", DRAWN), ("Golden Plate", DRAWN)]),
    # The pack calls a strapped backpack its leather armour (it is rag_and_bone_sack), so all drawn.
    "jerkin": ("Body", [
        ("Hide Jerkin", DRAWN), ("Leather Jerkin", DRAWN), ("Studded Jerkin", DRAWN), ("Shadow Leathers", DRAWN)]),
    "robe": ("Body", [
        ("Linen Robe", DRAWN), ("Silk Robe", DRAWN), ("Sage's Robe", DRAWN), ("Archmage's Robe", DRAWN)]),

    "boot": ("Boots", [
        ("Leather Boot", (_RPG + "Equipment/Leather Boot", 0, 0, 32, 32, 1)), ("Studded Boot", DRAWN), ("Ranger's Boot", DRAWN), ("Shadow Boot", DRAWN)]),
    "greaves": ("Boots", [
        ("Bronze Greaves", DRAWN), ("Iron Greaves", (_RPG + "Equipment/Iron Boot", 0, 0, 32, 32, 1)),
        ("Steel Greaves", DRAWN), ("Golden Greaves", DRAWN)]),
    "slippers": ("Boots", [
        ("Linen Slippers", DRAWN), ("Silk Slippers", DRAWN), ("Sage's Slippers", DRAWN),
        ("Archmage's Slippers", DRAWN)]),

    # Untiered, so here the drawing parts one piece from the next rather than one tier from the
    # last: a stone on a gold band, a broad riveted band, a ring cut from jade; four pendants of
    # four shapes.
    "ring": ("Ring", [("Gold Ring", DRAWN), ("Iron Band", DRAWN), ("Jade Ring", DRAWN)]),
    "amulet": ("Amulet", [
        ("Ruby Amulet", DRAWN), ("Gold Amulet", DRAWN), ("Sapphire Amulet", DRAWN), ("Emerald Amulet", DRAWN)]),
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

# The six orbs, off "OreAndGem" -- a 10x5 grid of 50 gems on an exact 32 px pitch, so an entry is
# only ever a cell of it. The picks are made for distinctness across the tray as much as for the
# colours Path of Exile trained the idea into: the six stand side by side in one row, so no two of
# them may read as the same stone at a glance.
#
# name -> (sheet under Assets/Potential, x, y, w, h, scale), a source 6-tuple
ORBS = {
    "Orb of Transmutation": ("OreAndGem/OreGemSpritesheet", 9 * 32, 1 * 32, 32, 32, 1),
    "Orb of Alteration": ("OreAndGem/OreGemSpritesheet", 7 * 32, 1 * 32, 32, 32, 1),
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
# The doll is the pack's own silhouette, brown on brown so it reads as the panel rather than as a
# picture on it; the sockets are laid over it. The other two are the pack's empty-socket marks, and
# it is no accident that it draws exactly these two: which socket is the weapon and which the boots
# is obvious from where it sits on a body, and which is a ring is not.
PARTS = {
    "ui_doll": ("2D Pixel UI/PNG/Equipment", 50, 336, 43, 46, 1),
    "ui_socket_amulet": ("2D Pixel UI/PNG/Equipment", 99, 337, 10, 13, 1),
    "ui_socket_ring": ("2D Pixel UI/PNG/Equipment", 99, 354, 11, 12, 1),
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
}

# The skill trees' icons, off "Ability Icons" -- loose 16 px files that carry their own framed square,
# so an entry is a whole file and nothing is trimmed. One colourway a tree, so a tree reads as one
# thing: red for Power, and the gold-orange for Fortune, which is the colour loot already speaks in.
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
}
SKILL_LOCKS = {"power_locked": "RedLocked", "fortune_locked": "YellowLocked"}

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


def _outlined(art):
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
    if 2 * len(ring) < len(edge):
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
        # The seventeen off the RPG pack take the bases' finish, so the collection log and the bag
        # are one look. The ten doubled off Icons.png carry a dark line of their own, and the drawn
        # ones below are written over them: see UNIQUE_DRAWN.
        out[name] = _squared(name, _shift(art if _doubled(art) else _outlined(art), *entry[1:]))
    if UNIQUE_DRAWN_EXPORT:
        out.update(unique_drawn())
    return out


def unique_drawn():
    """The ten drawn unique icons, finished the way every base is."""
    draw = _generator().UNIQUES
    out = {}
    for name in UNIQUE_DRAWN:
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


def unique_drawn_preview(drawn):
    """The ten doubled unique icons as they are cut now and, under each, as drawn -- both in the gold
    ring a unique wears, at 3x, and the ten again at 1x along the bottom, cut then drawn."""
    socket, gold, ink = (0x8A, 0x6F, 0x4E, 0xFF), (0xE8, 0xB8, 0x3C, 0xFF), (0x3B, 0x2A, 0x1E, 0xFF)
    now = {name: _squared(name, _shift(_cut(UNIQUE_GEAR[name][0]), *UNIQUE_GEAR[name][1:])) for name in drawn}
    zoom, side, pad = 3, GEAR_SIDE + 8, 6
    top = (2 * side + 3 * pad) * zoom + 14
    out = Image.new("RGBA", (pad * zoom + len(drawn) * (side + pad) * zoom, top + 2 * (side + pad) + pad),
                    (0xE8, 0xDC, 0xC0, 0xFF))
    draw = ImageDraw.Draw(out)
    for i, name in enumerate(drawn):
        x = (pad + i * (side + pad)) * zoom
        for j, art in enumerate((now[name], drawn[name])):
            cell = Image.new("RGBA", (side, side), gold)
            cell.paste(Image.new("RGBA", (side - 4, side - 4), socket), (2, 2))
            cell.alpha_composite(art, (4, 4))
            out.paste(cell.resize((side * zoom,) * 2, Image.NEAREST), (x, (pad + j * (side + pad)) * zoom))
            out.paste(cell, (pad * zoom + i * (side + pad), top + j * (side + pad)))
        draw.text((x, (2 * side + 3 * pad) * zoom - 2), name, fill=ink)
    return out


def base_gear():
    """All sixty-nine bases, cut or drawn as BASE_KINDS says, every one through `_outlined`.

    Nothing is read out of Assets/Gear, which is where these are written. A doubled icon stops the
    build, and so does one whose edge is not outline ink: see `_doubled` and `outline_share`.
    """
    generator = _generator()
    out = {}
    for _slot, tiers in BASE_KINDS.values():
        for tier in tiers:
            name, source = tier[0], tier[1]
            if source == DRAWN:
                art = generator.ICONS[name]()
            else:
                art = _cut(source)
            art = _outlined(art)
            if len(tier) > 2:
                art = _shift(art, *BASE_TINTS[tier[2]])
            if _doubled(art):
                raise SystemExit("%s is doubled art: every 2x2 block of it is one colour" % name)
            if outline_share(art) < OUTLINE_FLOOR:
                raise SystemExit("%s: only %d%% of its edge is outline ink" % (name, 100 * outline_share(art)))
            out[name] = _squared(name, art.crop(art.getbbox()))
    return out


def base_preview(cut):
    """All sixty-nine bases: a row to a kind, a column to a tier, grouped under their slot.

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
            draw.text((x, y + side + 13), "drawn" if source == DRAWN else "cut from the pack", fill=faint)
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
    """Every skill icon and both locked marks, whole files at their own 16 px."""
    out = {}
    for name, (_tree, src) in SKILLS.items():
        out[name] = _cut((SKILL_ROOT + src, 0, 0, SKILL_SIDE, SKILL_SIDE, 1), trim=False)
    for name, src in SKILL_LOCKS.items():
        out[name] = _cut((SKILL_LOCKED + src, 0, 0, SKILL_SIDE, SKILL_SIDE, 1), trim=False)
    for name, image in out.items():
        if image.size != (SKILL_SIDE, SKILL_SIDE):
            raise SystemExit("%s is %dx%d, not %d square" % (name, image.width, image.height, SKILL_SIDE))
    return out


def skill_preview(cut):
    """Both trees on the cream panel at the 2x they are drawn at, laid out as the sketch is.

    Each tree is shown twice: the left copy fresh, where only the root is open and everything else
    wears the locked mark, and the right copy part-spent, which is the only state worth judging whether
    twenty icons read as twenty different skills.
    """
    cream, ink, lit = (0xE5, 0xD6, 0xA1, 0xFF), (0x3B, 0x2A, 0x1E, 0xFF), (0xE8, 0xB7, 0x3A, 0xFF)
    side, gap_x, gap_y, pad = SKILL_SIDE * 2, 18, 18, 12
    tree_w = 3 * side + 2 * gap_x
    tree_h = 5 * side + 4 * gap_y
    learned = {"sharpened_edge", "keen_eye", "battle_rhythm", "flurry",
               "scavenger", "appraiser", "prospector", "fortunes_favour", "greed", "midas"}
    out = Image.new("RGBA", (pad + 4 * (tree_w + pad), tree_h + 2 * pad), cream)
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
            if open_ and name not in ranked:
                icon = Image.blend(icon, Image.new("RGBA", icon.size, (0x60, 0x60, 0x60, 0xFF)), 0.45)
                icon.putalpha(cut[name].getchannel("A"))
            x, y = centre(ox, row, col)
            out.alpha_composite(icon.resize((side, side), Image.NEAREST), (x - side // 2, y - side // 2))
    return out.resize((out.width * 2, out.height * 2), Image.NEAREST)


def parts():
    """The equipment screen's furniture, each at its own size -- nothing here sits in a grid."""
    return {name: _cut(entry) for name, entry in PARTS.items()}


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
    out = {}
    for name, art in marks.items():
        art = _map_colors(art, table)
        if art.width > ICON_SIDE or art.height > ICON_SIDE:
            raise SystemExit("%s is %dx%d, too big for a %d square"
                             % (name, art.width, art.height, ICON_SIDE))
        square = Image.new("RGBA", (ICON_SIDE, ICON_SIDE), (0, 0, 0, 0))
        square.alpha_composite(art, ((ICON_SIDE - art.width) // 2, (ICON_SIDE - art.height) // 2))
        out[name] = square
    return out


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

    unique_drawn_preview(unique_drawn()).save(os.path.join(QA, "ui_kit_uniques_drawn.png"))

    bases = base_gear()
    base_preview(bases).save(os.path.join(QA, "ui_kit_bases.png"))
    if BASES_EXPORT:
        for name, image in bases.items():
            image.save(os.path.join(GEAR_OUT, name + ".png"))

    # Loose as well, and for the same reason the parts are: a mark is drawn at its own size and the
    # face behind it is what stretches.
    mark = icons()
    icon_preview(mark, sprites, margins).save(os.path.join(QA, "ui_kit_icons.png"))
    for name, image in mark.items():
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
    for name, src in FORTUNE.items():
        _cut((SKILL_ROOT + src, 0, 0, SKILL_SIDE, SKILL_SIDE, 1), trim=False).save(
                os.path.join(FORTUNE_OUT, name + ".png"))

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


if __name__ == "__main__":
    main()
