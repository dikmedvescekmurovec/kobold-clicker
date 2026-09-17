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
## `ui_scale`. And `TextPanel` rather than the wood the other cards stand on, because the darker half
## of the rarity ramp that `ItemDetails` writes in is picked to be read on cream.

## `OrbCard.WIDTH`: what the game already uses for a block of text that floats.
const WIDTH := 150.0
## The air between the card and the square it describes, in panel pixels.
const GAP := 4

var _ui_scale: float
var _rows: VBoxContainer
var _shown: ItemSlot
## The square last pressed and where, which `hovered` keeps quiet about until the cursor leaves it.
## The square's place rather than its piece: a redraw makes new squares, and a vendor's shelf makes
## new `Item`s too (`VendorStock.items`), so nothing pressed is still there to be compared with.
var _muted := Rect2()
var _pressed_at := Vector2.INF


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
	hide()


func _process(_delta: float) -> void:
	var slot := hovered(get_viewport().get_mouse_position(),
			Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	# A square freed by a redraw compares equal to null, which would read as "still nothing" and leave
	# the card of a square that is gone standing: a vendor's shelf does exactly that on a press.
	if is_instance_valid(_shown) and slot == _shown or (slot == null and not visible):
		return
	_shown = slot
	if slot == null:
		hide()
		return
	UITheme.clear(_rows)
	ItemDetails.fill(_rows, slot.item, WIDTH)
	show()
	# Placed now and again deferred: the first pass measures labels that have not laid out yet.
	_place(slot.get_global_rect())
	_place.call_deferred(slot.get_global_rect())


## The square the card should be describing, or null. Nothing while the button is down: that is a
## drag scrolling the bag or a press opening the piece, and a card flickering from square to square
## under either is in the way. And a press puts the card away for good: the piece pressed says
## nothing more until the cursor has been somewhere else, whether the press opened it, shut it or
## did nothing at all, and neither does whatever a sale slid under a cursor that has not moved.
func hovered(at: Vector2, pressed: bool) -> ItemSlot:
	var slot := slot_at(at, pressed)
	if pressed:
		_muted = slot.get_global_rect() if slot != null else Rect2()
		_pressed_at = at
		return null
	if at == _pressed_at or _muted.has_point(at):
		return null
	_muted = Rect2()
	_pressed_at = Vector2.INF
	return slot


## The square under `at` (in viewport pixels), or null. A square scrolled out of its box is still
## where it was as far as its own rect knows, so every clipping ancestor has to hold the point too;
## and the one that is already open says nothing, because its block is written out beside it --
## unless `open_too` asks for it all the same.
func slot_at(at: Vector2, open_too := false) -> ItemSlot:
	for slot: ItemSlot in get_tree().get_nodes_in_group(ItemSlot.GROUP):
		if slot.item == null or (slot.selected and not open_too) or not slot.is_visible_in_tree() \
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


## To the right of the square, or to its left when the window's edge is in the way, and never off
## the window.
func _place(anchor: Rect2) -> void:
	if not visible:
		return
	reset_size()
	var card := get_combined_minimum_size() * _ui_scale
	var window := get_viewport_rect().size
	var x := anchor.end.x + GAP * _ui_scale
	if x + card.x > window.x:
		x = anchor.position.x - GAP * _ui_scale - card.x
	position = Vector2(x, anchor.position.y).clamp(Vector2.ZERO, (window - card).max(Vector2.ZERO))
