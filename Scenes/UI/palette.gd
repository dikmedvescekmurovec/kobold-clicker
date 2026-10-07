class_name Palette
extends RefCounted
## The colours the game draws with in code, rather than through a sprite. Every one is in ENDESGA 64
## (`E64`), the palette the fighters and the backdrops are drawn in and, since 2026-09-30, the whole
## interface: `tools/ui_kit.py` puts the interface's art into it (`hexlib.to_e64`), so a label or an
## outline drawn here matches the art it sits on. `test_ui_theme` holds every constant to `E64`.
##
## **Text on the cream is held to its contrast** (`test_ui_theme`): a body line (the 10 px font) to
## 4.5:1, and only `GOLD_TEXT`, which writes a unique's name at 16 px, to 3:1. The bright colours --
## `GOLD`, `LEAF_LT`, `ICE`, `STONE_LT` -- are for fills, frames and words outlined on the backdrop,
## never for a line on the cream: gold there was 1.3:1, rust and leaf 2.2:1.

const INK := Color("131313")
const BONE := Color("f9e6cf")
const GOLD := Color("ffc825")
## Gold as a word on the cream: a unique's name, a banner's title, a camp's place. Nothing in ENDESGA
## 64 that still reads as gold is dark enough, so it is the vermilion next to it, for 16 px names alone.
const GOLD_TEXT := Color("c64524")
## A unique's ring (`tools/item_frames.py`): its lit row and the row under it. The card draws the ring's
## top edge in them round a unique's rule (`ItemDetails`).
const FRAME_GOLD := Color("ffa214")
const FRAME_GOLD_DK := Color("ed7614")
const EARTH_DK := Color("391f21")
## A common piece's name: the one grey on the cream (a 16 px name, held to 3:1).
const SLATE := Color("5d5d5d")

## The interface's own fills, as `tools/ui_kit.py` `UI_FIXED` puts the pack's into ENDESGA 64: the cream
## a text panel is drawn in and the tan its item slots are. They are here because a slot is drawn in
## code and has to match the panel art it sits on -- the pack draws a slot as one flat square, so a
## StyleBoxFlat in these colours is the art itself and not a stand-in for it.
## The user's pick of the two creams ENDESGA 64 offers (2026-09-30): the pinker, darker one, for
## more between the panel and its slots than the paler f9e6cf left.
const PANEL_CREAM := Color("f6ca9f")
## What is written on the cream: the frame's darkest brown for a name or a value, the next for a label.
const TEXT := Color("391f21")
const TEXT_SOFT := Color("5d2c28")
const SLOT_TAN := Color("e69c69")
## The same slot pressed in: the wood's brown.
const SLOT_TAN_DK := Color("8a4836")
## The brown button's face (`ui_btn_brown_normal`), for a mark drawn in code that has to read as one.
const BUTTON_BROWN := Color("8a4836")

## The rarity ramp and the accents. STONE_LT, ICE and LILAC frame an item's square; ICE_DK and LILAC
## write a name on the cream (`ItemRarity.TEXT_COLORS`). LEAF is a gain, a boon, a thing to do or a
## modifier at its best, written; LEAF_LT is a green fill. RUST is a modifier, a loss or a warning.
const STONE_LT := Color("b4b4b4")
const LEAF_LT := Color("5ac54f")
const LEAF := Color("134c4c")
const ICE := Color("0098dc")
const ICE_DK := Color("00396d")
const LILAC := Color("93388f")
const RUST := Color("8a4836")
## The epic step, border and name alike, strength's ring on the character page, and a refusal.
const BRICK := Color("891e2b")
## LEAF_LT's twin for a loss: a red for words outlined on the backdrop or the band, never on the cream.
const BRICK_LT := Color("f5555d")

## ENDESGA 64 itself, for `test_ui_theme` to hold the constants above to.
const E64 := ["ff0040", "131313", "1b1b1b", "272727", "3d3d3d", "5d5d5d", "858585", "b4b4b4", "ffffff",
		"c7cfdd", "92a1b9", "657392", "424c6e", "2a2f4e", "1a1932", "0e071b", "1c121c", "391f21", "5d2c28",
		"8a4836", "bf6f4a", "e69c69", "f6ca9f", "f9e6cf", "edab50", "e07438", "c64524", "8e251d", "ff5000",
		"ed7614", "ffa214", "ffc825", "ffeb57", "d3fc7e", "99e65f", "5ac54f", "33984b", "1e6f50", "134c4c",
		"0c2e44", "00396d", "0069aa", "0098dc", "00cdf9", "0cf1ff", "94fdff", "fdd2ed", "f389f5", "db3ffd",
		"7a09fa", "3003d9", "0c0293", "03193f", "3b1443", "622461", "93388f", "ca52c9", "c85086", "f68187",
		"f5555d", "ea323c", "c42430", "891e2b", "571c27"]
