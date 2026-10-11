class_name OrbSlot
extends Panel
## One orb, super orb or rune as a square in its tray, on the tan socket an item sits on. Its own class
## and not a mode of `ItemSlot`, which takes no mouse so a drag begun on it still scrolls the bag: an orb
## square is the click target and the hover target both, in a footer with no drag to protect.
##
## Three looks, told apart at a glance in a row of six: never found (the icon at
## `ItemSlot.EMPTY_MARK_ALPHA`, as an empty socket's mark), held with nothing to do (`DIM`), held and
## usable (full colour, the socket darkening under the cursor). Why an orb is grey is its owner's to
## say, from `hovered`.

## Six of these and five `BagPage.ORB_GAP` fit `BagPage.WIDTH` (`test_ui_theme`).
const SIDE := 24
## Half the 32 px the icon is cut at: a whole 2:1 step, so a source pixel stays square on screen.
const ICON := 16
## How far the count hangs off the square's bottom-right corner, so the numeral stands on the gutter
## and not on the gem it counts.
const COUNT_OVERHANG := 3
## A held orb with nothing to do. Grey, not faint: faint already says "not found".
const DIM := Color(0.42, 0.42, 0.44)

## Only a lit square emits it.
signal pressed(orb: String)
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
## open (with nothing open, every held orb). `armed` is the orb the bag holds over the grid: its socket
## stays as dark as an open square's. `side` is `SIDE` in the tray and `ItemSlot.SIDE` on a vendor's
## shelf, where the icon keeps the tray's margin and so is drawn at its own 32.
func setup(which: String, count: int, usable: bool, armed := false, side := SIDE) -> void:
	orb = which
	_live = count > 0 and usable
	Cursors.wear(self, Cursors.HAND if _live else Cursors.ARROW)
	custom_minimum_size = Vector2(side, side)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Common's socket: an orb has no rarity, so no ring.
	var rest := ItemRarity.slot_style(ItemRarity.Rarity.COMMON, armed)
	add_theme_stylebox_override("panel", rest)

	_icon = TextureRect.new()
	# Stepped down from the 32 px file, which a fight's drop draws whole. The modes go before the texture
	# and the size: a Control's `size` is clamped to its minimum as it is set, and a TextureRect's
	# minimum is its texture's size until `expand_mode` says otherwise -- so 16 asked for under the
	# default mode comes back 32, and lowering the minimum afterwards does not shrink what was set.
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

	# Only past one: a "1" on every square is a row of numbers saying nothing.
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


## A press on a lit square. A grey one still hovers (its card says why it is grey) and does nothing
## when clicked.
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
## In the body font with an ink outline, which is what reads over a gem of any colour. Laid over the
## whole square and aligned into its corner, never placed by measuring the glyphs; the box is grown past
## that corner, which lifts the numeral off the icon, and further to the left, for a second digit.
static func count_label(text: String) -> Label:
	var tally := UITheme.label(text, Palette.BONE, true)
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
