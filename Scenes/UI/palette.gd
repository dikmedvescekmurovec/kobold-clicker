class_name Palette
extends RefCounted
## The few sprite-palette colours the game draws with in code, rather than through a sprite. They are
## the same hexes the sprite generator uses (AI-sprites-generator/hexlib.py PALETTE), so an outline or
## a label matches the art it sits on.

const INK := Color("14101e")
const BONE := Color("f4eedc")
const GOLD := Color("e9b640")
const EARTH_DK := Color("3a2521")
const SLATE := Color("565a6e")

## The interface's own fills, straight out of the bought UI pack rather than hexlib: the cream a text
## panel is drawn in, and the tan its item slots are. They are here because a slot is drawn in code
## and has to match the panel art it sits on -- the pack draws a slot as one flat square, so a
## StyleBoxFlat in these colours is the art itself and not a stand-in for it.
const PANEL_CREAM := Color("e5d6a1")
const SLOT_TAN := Color("cda677")
## The same slot pressed in: the pack's wood face, which is the next step down its brown ramp.
const SLOT_TAN_DK := Color("825c2f")

## The rarity ramp, one pair per step. The light one is for a border on the dark socket of an item
## square, the dark one for that rarity's name on the bone text panel: a colour that sings on the
## socket is nearly invisible on bone, which is the same reason UITheme keeps two tables of font
## colours. LILAC is dark enough to do both jobs, and GOLD above is the unique step, unrolled so far.
const STONE_LT := Color("a6aabb")
const LEAF_LT := Color("86c25a")
const LEAF := Color("58a046")
const ICE := Color("72a8d6")
const ICE_DK := Color("3f6fa6")
const LILAC := Color("a77fcf")
## What a modifier line is written in. Amber on bone is weak, and keeping GOLD unspent leaves the
## unique step a colour of its own.
const RUST := Color("d57a39")
