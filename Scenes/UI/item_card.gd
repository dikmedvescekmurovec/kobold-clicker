class_name ItemCard
extends PanelContainer
## What a piece of gear is, shown while the cursor is over its square: the same `ItemDetails` block
## the bag opens, in the pack's cream text panel, beside the square it describes.
##
## One card for every square in the game rather than one per page. An `ItemSlot` takes no mouse input
## -- the bag's scroll has to see every press -- so no square can say it is hovered; instead every
## square joins `ItemSlot.GROUP` and the card asks, each frame the cursor has moved, which of them it
## is over. The bag's grid, the worn sockets and a vendor's shelf all get it for nothing, and so will
## whatever draws a square next.
##
## Not Godot's tooltip, for `OrbCard`'s reason: a tooltip is its own window and cannot inherit
## `ui_scale`. On `TextPanel`, as every card is, because the darker half of the rarity ramp that
## `ItemDetails` writes in is picked to be read on cream.

## `OrbCard.WIDTH`: what the game already uses for a block of text that floats.
const WIDTH := 150.0
## The air between the card and the square it describes, in panel pixels.
const GAP := 4
## What the second card says under Alt when nothing is worn where the hovered piece would go, the
## socket named by `Equipment.LABELS`.
const BARE := "Nothing is equipped in the %s slot"
## The meta a square may carry naming a Control standing beside it (the bag's buttons): the card is
## placed past the two of them together, so it never covers what the square has to press.
const BESIDE := "beside"
## The meta a square may carry naming the keys a click on it answers to, key -> the word the card
## writes beside that key's picture: `{"shift": "equip", "ctrl": "sell"}`. The page that draws the
## square sets it, since only it knows what its buttons do; Alt is the card's own.
const KEYS := "keys"
## The keys' pictures, cut from the keyboard pack by `tools/ui_kit.py`.
const KEY_ICONS := {
	"alt": "res://Assets/UI/ui_key_alt.png",
	"shift": "res://Assets/UI/ui_key_shift.png",
	"ctrl": "res://Assets/UI/ui_key_ctrl.png",
}

## What the player has on, for the second card. The main scene sets it; without it there is no second card.
var equipment: Equipment
var _ui_scale: float
var _rows: VBoxContainer
var _shown: ItemSlot
## The second card, up while Alt is held: the piece the player is wearing where the hovered one would
## go. A sibling rather than a child, because a PanelContainer would lay a child out inside itself.
var _worn := PanelContainer.new()
var _worn_rows: VBoxContainer
var _alt := false
## The square last pressed and where, which `hovered` keeps quiet about until the cursor leaves it.
## The square's place rather than its piece: a redraw makes new squares, and a vendor's shelf makes
## new `Item`s too (`VendorStock.items`), so nothing pressed is still there to be compared with.
var _muted := Rect2()
var _pressed_at := Vector2.INF
var _unmute := false


func _init(ui_scale: float) -> void:
	_ui_scale = ui_scale
	theme = UITheme.theme()
	theme_type_variation = "TextPanel"
	scale = Vector2(ui_scale, ui_scale)
	# It stands beside the cursor and must never take a press meant for what is under it.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows = UITheme.vbox(2, WIDTH)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rows)
	_worn.theme = theme
	_worn.theme_type_variation = "TextPanel"
	_worn.scale = scale
	_worn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_worn_rows = UITheme.vbox(2, WIDTH)
	_worn_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_worn.add_child(_worn_rows)
	_worn.hide()
	hide()


func _ready() -> void:
	add_sibling.call_deferred(_worn)


func _exit_tree() -> void:
	_worn.queue_free()


func _process(_delta: float) -> void:
	var slot := hovered(get_viewport().get_mouse_position(),
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	# A square freed by a redraw compares equal to null, which would read as "still nothing" and leave
	# the card of a square that is gone standing: a vendor's shelf does exactly that on a press.
	var alt := Input.is_key_pressed(KEY_ALT)
	if alt == _alt and (is_instance_valid(_shown) and slot == _shown or (slot == null and not visible)):
		return
	_alt = alt
	_shown = slot
	_worn.hide()
	if slot == null:
		hide()
		return
	UITheme.clear(_rows)
	if slot.hint.is_valid():
		slot.hint.call(_rows, WIDTH)
	else:
		ItemDetails.fill(_rows, slot.item, WIDTH)
		var hints := hints_for(slot, alt)
		if not hints.is_empty():
			_rows.add_child(UITheme.rule())
			_rows.add_child(key_row(hints))
		var worn := worn_for(slot.item) if alt else null
		if worn != null:
			UITheme.clear(_worn_rows)
			ItemDetails.fill(_worn_rows, worn, WIDTH)
			# Said on the rarity line, the fill's second, rather than over the name: a heading would
			# push every row a line below its fellow on the first card.
			(_worn_rows.get_child(1) as Label).text += " · worn"
			_worn.show()
		elif alt and bare_for(slot.item):
			# Alt answered, so a bare socket does not read as a key that did nothing.
			UITheme.clear(_worn_rows)
			_worn_rows.add_child(ItemDetails.line(bare_text(slot.item), Palette.SLATE, WIDTH, true))
			_worn.show()
	show()
	var anchor := slot.get_global_rect()
	if slot.has_meta(BESIDE) and (slot.get_meta(BESIDE) as Control).visible:
		anchor = anchor.merge((slot.get_meta(BESIDE) as Control).get_global_rect())
	# Placed now and again deferred: the first pass measures labels that have not laid out yet.
	_place(anchor)
	_place.call_deferred(anchor)


## The square the card should be describing, or null. Nothing while the button is down: that is a
## drag scrolling the bag or a press opening the piece, and a card flickering from square to square
## under either is in the way. And a press puts the card away for good: the piece pressed says
## nothing more until the cursor has been somewhere else, whether the press opened it, shut it or
## did nothing at all, and neither does whatever a sale slid under a cursor that has not moved.
func hovered(at: Vector2, pressed: bool) -> ItemSlot:
	var slot := slot_at(at)
	if pressed:
		_muted = slot.get_global_rect() if slot != null else Rect2()
		_pressed_at = at
		return null
	if _unmute:
		_unmute = false
		_muted = Rect2()
		_pressed_at = Vector2.INF
	if at == _pressed_at or _muted.has_point(at):
		return null
	_muted = Rect2()
	_pressed_at = Vector2.INF
	return slot


## Lets the pressed place speak again without the cursor leaving it: a held orb has just changed the
## piece under it (`BagPage.crafted`), and the new lines are the whole point of that press.
## Taken up once the button is let go, because a socket on the doll crafts on the way down.
func unmute() -> void:
	_unmute = true


## The square under `at` (in viewport pixels), or null. A square scrolled out of its box is still
## where it was as far as its own rect knows, so every clipping ancestor has to hold the point too.
func slot_at(at: Vector2) -> ItemSlot:
	for slot: ItemSlot in get_tree().get_nodes_in_group(ItemSlot.GROUP):
		if slot.item == null or not slot.is_visible_in_tree() \
				or not slot.get_global_rect().has_point(at):
			continue
		var clipped := false
		var above := slot.get_parent()
		while above != null and not clipped:
			clipped = above is Control and (above as Control).clip_contents \
					and not (above as Control).get_global_rect().has_point(at)
			above = above.get_parent()
		if not clipped:
			return slot
	return null


## The piece `item` would take off, or null: it would take nothing off, or `item` is itself what is
## on. The first socket `Equipment.sockets_for` names that has anything to lose, so a ring is held
## against the left finger -- and a shield against the greatsword whose hand it wants, which is worn
## in another socket entirely.
func worn_for(item: Item) -> Item:
	if equipment == null or item in equipment.worn.values():
		return null
	for socket: Equipment.Socket in equipment.sockets_for(item):
		var off := equipment.displaced_by(socket, item)
		if not off.is_empty():
			return off[0]
	return null


## Whether `item` would go on somewhere nothing is worn -- which `worn_for`'s null alone does not say,
## since the worn piece itself gets one too.
func bare_for(item: Item) -> bool:
	return equipment != null and not (item in equipment.worn.values()) and worn_for(item) == null


## `BARE` for the socket `item` would go in: "the ring slot", "the offhand slot".
func bare_text(item: Item) -> String:
	return BARE % str(Equipment.LABELS[equipment.sockets_for(item)[0]]).to_lower()


## The keys a press or a hold on `slot` would answer, for the card's foot: Alt while it is not held
## (held, the second card is the answer) and the card has something to say under it, then whatever
## the square's page says a click does (`KEYS`).
func hints_for(slot: ItemSlot, alt: bool) -> Dictionary:
	var hints := {}
	if not alt and (worn_for(slot.item) != null or bare_for(slot.item)):
		hints["alt"] = "compare"
	hints.merge(slot.get_meta(KEYS, {}))
	return hints


## One row of `[key] word` pairs, the picture at its own size beside the word in the body font. A
## flow rather than a box, so three pairs wrap inside the card's width instead of widening it, and
## each pair a box of its own, so a key never ends one line with its word starting the next.
static func key_row(hints: Dictionary) -> HFlowContainer:
	var row := HFlowContainer.new()
	row.custom_minimum_size = Vector2(WIDTH, 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for key: String in hints:
		var pair := HBoxContainer.new()
		pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var picture := TextureRect.new()
		picture.texture = load(KEY_ICONS[key])
		picture.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(picture)
		var word := UITheme.label(str(hints[key]), Palette.SLATE, true)
		word.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pair.add_child(word)
		row.add_child(pair)
	return row


## Where a card of `card` window pixels stands beside `anchor`: to its right, or to its left when the
## window's edge is in the way, and never off the window. Every floating card is placed by this.
static func beside(anchor: Rect2, card: Vector2, window: Vector2, gap: float) -> Vector2:
	var x := anchor.end.x + gap
	if x + card.x > window.x:
		x = anchor.position.x - gap - card.x
	return Vector2(x, anchor.position.y).clamp(Vector2.ZERO, (window - card).max(Vector2.ZERO))


func _place(anchor: Rect2) -> void:
	if not visible:
		return
	reset_size()
	var card := get_combined_minimum_size() * _ui_scale
	var window := get_viewport_rect().size
	var gap := GAP * _ui_scale
	position = beside(anchor, card, window, gap)
	if not _worn.visible:
		return
	# On past the first card, away from the square; across the square from it where the window ends first.
	_worn.reset_size()
	var worn := _worn.get_combined_minimum_size() * _ui_scale
	var right := position.x > anchor.position.x
	var worn_x := position.x + card.x + gap if right else position.x - gap - worn.x
	if worn_x < 0 or worn_x + worn.x > window.x:
		worn_x = anchor.position.x - gap - worn.x if right else anchor.end.x + gap
	# One top for both, the taller card's: whichever the window's foot pushes up takes the other with it.
	position.y = clampf(anchor.position.y, 0.0, maxf(window.y - maxf(card.y, worn.y), 0.0))
	_worn.position = Vector2(clampf(worn_x, 0.0, maxf(window.x - worn.x, 0.0)), position.y)
