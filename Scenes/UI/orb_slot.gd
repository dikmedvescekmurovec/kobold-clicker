class_name OrbSlot
extends Panel
## One orb, drawn as a square in the bag's tray: its icon on the same tan socket an item sits on.
##
## Its own class rather than a mode on ItemSlot, because the two differ in exactly the thing that
## matters most about a square. ItemSlot takes no mouse input at all, so that the drag which scrolls
## the bag survives a press beginning on a square; an orb square is the opposite -- it is the click
## target and the hover target both, and it stands in the footer where there is no drag to protect.
## One class doing both would be a flag deciding whether it is clickable, which is two classes
## wearing one name.
##
## Three states, because there are three things true of an orb and the player has to tell them apart
## at a glance in a row of eight:
##
##   never found  -- the icon at ItemSlot.EMPTY_MARK_ALPHA, the faintness the empty ring and amulet
##                   sockets already use, so "nothing there" reads one way across the interface
##   held, no use -- drawn grey: it is yours, but it has nothing to do to the piece that is open
##   held, usable -- full colour, and the socket darkens under the cursor
##
## The card that says *why* an orb is grey is the panel's business, not this one's; this emits
## `hovered` and lets whoever owns it put the words somewhere with room for them.

## The square, and the icon in it. Eight of these with SLOT_GAP between them come to exactly
## BagPage.WIDTH, which is what settles both numbers.
const SIDE := 24
## Half the 32 px the icon is cut at. A 2:1 step, so a source pixel stays a square pair of pixels on
## screen; every other scale in this game is a whole number for the same reason `zoom` is.
const ICON := 16
## How far the count hangs off the square's bottom-right corner. It overhangs rather than sitting
## inside because 16 px is the smallest Pixellari draws cleanly and a 16 px numeral is two thirds of
## a 24 px square -- a count laid inside would bury the very gem it is counting.
const COUNT_OVERHANG := 3
## What a held orb with nothing to do is dimmed to. Grey rather than faint: "not for this piece" is a
## different statement from "not found", and two alphas of the same icon would say the same thing
## twice.
const DIM := Color(0.42, 0.42, 0.44)

## The player pressed this orb, and it was lit when they did.
signal pressed(orb: String)
## The cursor is over it. The name rather than the node, because what the card needs is the orb.
signal hovered(orb: String)
signal unhovered()

var orb := ""

var _icon: TextureRect
var _live := false


## Draws this orb held `count` times. `usable` is whether it can do anything to whatever the bag has
## open -- with nothing open every held orb is usable, which is the tray at rest.
func setup(which: String, count: int, usable: bool) -> void:
	orb = which
	_live = count > 0 and usable
	custom_minimum_size = Vector2(SIDE, SIDE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The socket an item square uses, so the tray reads as part of the same bag rather than as a
	# second interface pinned under it. No rarity ring: an orb has no rarity, and borrowing common's
	# borderless style is exactly right rather than a shortcut.
	add_theme_stylebox_override("panel", ItemRarity.slot_style(ItemRarity.Rarity.COMMON))

	_icon = TextureRect.new()
	# The source is 32 and this draws 16, so the texture is stepped down here rather than cut small:
	# nearest keeps the halving square, and the full-size icon stays on disk for whatever wants it --
	# the orb thrown out of a body in a fight draws the same file at its own size.
	#
	# The order of these matters and is the whole reason this is not two lines. A Control's `size` is
	# clamped to its minimum as it is set, and a TextureRect's minimum is the texture's own size until
	# `expand_mode` says otherwise -- so asking for 16 while the mode is still the default gets 32,
	# and lowering the minimum afterwards does not shrink what was already set.
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.texture = OrbTable.icon(which)
	_icon.custom_minimum_size = Vector2(ICON, ICON)
	_icon.size = Vector2(ICON, ICON)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(SIDE - ICON, SIDE - ICON) / 2.0
	if count <= 0:
		_icon.modulate = Color(1, 1, 1, ItemSlot.EMPTY_MARK_ALPHA)
	elif not usable:
		_icon.modulate = DIM
	add_child(_icon)

	# Only past one: a single orb needs no "1" on it, and seven squares wearing a 1 is seven numbers
	# saying nothing. Pixellari at its own 16 -- it breaks up below that -- with an ink outline, which
	# is what makes a light numeral readable over a gem of any colour.
	if count > 1:
		var tally := Label.new()
		tally.theme_type_variation = "PanelLabel"
		tally.text = str(count)
		tally.add_theme_color_override("font_color", Palette.BONE)
		tally.add_theme_color_override("font_outline_color", Palette.INK)
		tally.add_theme_constant_override("outline_size", 4)
		tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tally.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		# Laid over the whole square and aligned into its corner, rather than positioned by a
		# measurement of the glyphs: how wide "12" is at this font is the font's business. The box is
		# then grown past the corner it is aligned to, which is what lifts the numeral off the icon,
		# and grown further to the left so a two-digit count has somewhere to go.
		tally.set_anchors_preset(Control.PRESET_FULL_RECT)
		tally.offset_left = -COUNT_OVERHANG * 2
		tally.offset_right = COUNT_OVERHANG
		tally.offset_bottom = COUNT_OVERHANG
		add_child(tally)

	mouse_entered.connect(func() -> void:
		if _live:
			add_theme_stylebox_override("panel",
					ItemRarity.slot_style(ItemRarity.Rarity.COMMON, true))
		hovered.emit(orb))
	mouse_exited.connect(func() -> void:
		add_theme_stylebox_override("panel", ItemRarity.slot_style(ItemRarity.Rarity.COMMON))
		unhovered.emit())


## A press on a lit square. A grey one still hovers -- the card is where the player finds out why it
## is grey -- and simply does nothing when clicked.
func _gui_input(event: InputEvent) -> void:
	if not _live:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed.emit(orb)
		accept_event()


static func make(which: String, count: int, usable: bool) -> OrbSlot:
	var slot := OrbSlot.new()
	slot.setup(which, count, usable)
	return slot
