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
## at a glance in a row of six:
##
##   never found  -- the icon at ItemSlot.EMPTY_MARK_ALPHA, the faintness the empty ring and amulet
##                   sockets already use, so "nothing there" reads one way across the interface
##   held, no use -- drawn grey: it is yours, but it has nothing to do to the piece that is open
##   held, usable -- full colour, and the socket darkens under the cursor
##
## The card that says *why* an orb is grey is the panel's business, not this one's; this emits
## `hovered` and lets whoever owns it put the words somewhere with room for them.

## The square, and the icon in it. Six of these with `BagPage.ORB_GAP` between them come to
## BagPage.WIDTH less under a gap, which is what settles both numbers.
const SIDE := 24
## Half the 32 px the icon is cut at. A 2:1 step, so a source pixel stays a square pair of pixels on
## screen; every other scale in this game is a whole number for the same reason `zoom` is.
const ICON := 16
## How far the count hangs off the square's bottom-right corner, so the numeral stands on the gutter
## rather than on the gem it is counting.
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
## Whether this is an orb to pick up and use on something else (the bag's trays), not one to buy. Under
## a finger a tap then picks it up and says nothing, and its card is a finger held on it for
## `TipCard.DELAY`, which picks nothing up (the user's, 2026-10-10): what is read first is the piece.
var picks_up := false

var _icon: TextureRect
var _live := false
## Under a finger (`Cursors.touched`): whether the tap that put this square's card up has been had, so
## the next one presses it. Forgotten as the finger goes elsewhere.
var _read := false
## How long a finger has been down on an orb that `picks_up`, in seconds, or -1 with none on it.
var _held := -1.0


## Draws this orb held `count` times. `usable` is whether it can do anything to whatever the bag has
## open -- with nothing open every held orb is usable, which is the tray at rest.
## `armed` is the orb the bag is holding over the grid: its socket stays as dark as an open square's.
## `side` is the square's: `SIDE` in the tray, `ItemSlot.SIDE` on a vendor's shelf, where the orb stands
## among pieces -- the icon keeps the tray's margin, so at 40 it is drawn at its own 32.
func setup(which: String, count: int, usable: bool, armed := false, side := SIDE) -> void:
	orb = which
	_live = count > 0 and usable
	Cursors.wear(self, Cursors.HAND if _live else Cursors.ARROW)
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The socket an item square uses, so the tray reads as part of the same bag rather than as a
	# second interface pinned under it. No rarity ring: an orb has no rarity, and borrowing common's
	# borderless style is exactly right rather than a shortcut.
	var rest := ItemRarity.slot_style(ItemRarity.Rarity.COMMON, armed)
	add_theme_stylebox_override("panel", rest)

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
	_icon.texture = SuperOrbTable.icon(which) if SuperOrbTable.has(which) \
			else RuneTable.icon(which) if RuneTable.has(which) else OrbTable.icon(which)
	var icon := side - (SIDE - ICON)
	_icon.custom_minimum_size = Vector2(icon, icon)
	_icon.size = Vector2(icon, icon)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.position = Vector2(side - icon, side - icon) / 2.0
	if count <= 0:
		_icon.modulate = Color(1, 1, 1, ItemSlot.EMPTY_MARK_ALPHA)
	elif not usable:
		_icon.modulate = DIM
	add_child(_icon)

	# Only past one: a single orb needs no "1" on it, and seven squares wearing a 1 is seven numbers
	# saying nothing. The body font at its own 10, with an ink outline, which is what makes a light
	# numeral readable over a gem of any colour. Pixellari's 16 covered half the gem.
	if count > 1:
		add_child(count_label(str(count)))

	mouse_entered.connect(func() -> void:
		if _live:
			add_theme_stylebox_override("panel",
					ItemRarity.slot_style(ItemRarity.Rarity.COMMON, true))
		# A finger's tap is what enters it, and on an orb to pick up that tap says nothing.
		if not (picks_up and Cursors.touched):
			hovered.emit(orb))
	mouse_exited.connect(func() -> void:
		_read = false
		# A finger that slid off it is no longer held on it, and lifts on nothing.
		_held = -1.0
		set_process(false)
		add_theme_stylebox_override("panel", rest)
		unhovered.emit())


## Godot starts whatever has a `_process`; this one runs only while a finger is down (`_finger`).
func _ready() -> void:
	set_process(false)


## A finger held on an orb that `picks_up` puts its card up once it has stayed `TipCard.DELAY`.
func _process(delta: float) -> void:
	_held += delta
	if _held >= TipCard.DELAY:
		set_process(false)
		hovered.emit(orb)


## A press on a lit square. A grey one still hovers -- the card is where the player finds out why it
## is grey -- and simply does nothing when clicked.
func _gui_input(event: InputEvent) -> void:
	if picks_up and Cursors.touched:
		_finger(event)
		return
	if not _live:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()  # Before the emit, which may redraw this slot out of the tree.
		# A finger has no hover: its first tap is what puts the card up, and only the next presses.
		if Cursors.touched and not _read:
			_read = true
			return
		pressed.emit(orb)


## A finger on an orb that `picks_up`, which counts as it lifts: let go at once it presses the square,
## and held until the card came up (`_process`) it only puts the card away again. A grey one is read
## the same way and never pressed.
func _finger(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	accept_event()  # Before the emit, which may redraw this slot out of the tree.
	if event.pressed:
		_held = 0.0
		set_process(true)
		return
	var read := _held >= TipCard.DELAY
	_held = -1.0
	set_process(false)
	if read:
		unhovered.emit()
	elif _live and Rect2(Vector2.ZERO, size).has_point(event.position):
		pressed.emit(orb)


## The numeral hung off a square's bottom-right corner: an orb's count, and an item's `+n` (`ItemSlot`).
## Laid over the whole square and aligned into its corner, rather than positioned by a measurement of
## the glyphs: how wide "12" is at this font is the font's business. The box is then grown past the
## corner it is aligned to, which is what lifts the numeral off the icon, and grown further to the left
## so a two-digit count has somewhere to go.
static func count_label(text: String) -> Label:
	var tally := Label.new()
	tally.theme_type_variation = "SmallLabel"
	tally.text = text
	tally.add_theme_color_override("font_color", Palette.BONE)
	tally.add_theme_color_override("font_outline_color", Palette.INK)
	tally.add_theme_constant_override("outline_size", 4)
	tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tally.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	tally.set_anchors_preset(Control.PRESET_FULL_RECT)
	tally.offset_left = -COUNT_OVERHANG * 2
	tally.offset_right = COUNT_OVERHANG
	tally.offset_bottom = COUNT_OVERHANG
	return tally


static func make(which: String, count: int, usable: bool, armed := false, side := SIDE) -> OrbSlot:
	var slot := OrbSlot.new()
	slot.setup(which, count, usable, armed, side)
	return slot
