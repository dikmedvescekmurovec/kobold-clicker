class_name DropsView
extends VBoxContainer
## What a fight has turned up, as a grid of squares you can open.
##
## Two places want exactly this: the panel at the end of a fight, and the loot popup the counter in
## the HUD opens mid-run. They are the same thing -- squares in the order they fell, one of which
## can be clicked to read what it actually is -- so they are one node built twice rather than one
## layout written twice, which is the reason ItemSlot and ItemDetails exist at all.
##
## It draws with the same squares the bag does (ItemSlot) and the same stat block (ItemDetails), so
## a rare piece looks and reads the same in every place the game shows it.
##
## The grid and the details swap rather than stack, the way `_bag_scroll` and `_bag_detail` swap on
## the item panel: a piece carrying six modifiers is taller than the verdict it would push down.

## How many drops stand in a row. How big a square is belongs to ItemSlot, not here.
const PER_ROW := 4
## How wide a line of an item's details may run before it wraps, in panel pixels.
const INSPECT_WIDTH := 150.0
## The gap between squares. The same seven-to-one proportion the bag's grid keeps.
const GAP := ItemSlot.SIDE / 7

## Fired whenever the view changes height -- a drop opened or closed, or the list refilled -- so an
## owner that centres this panel knows to measure it again.
signal resized_contents
## The open drop is to be thrown away. The view does not touch its own list: whoever filled it owns
## what the run is carrying, and two places editing that is how the counter and the pouch come to
## disagree. The owner removes it and fills again.
signal discarded(item: Item)

## Whether an open drop may be thrown away from here. Off by default, so a view that is only a
## record of what happened stays one.
var discardable := false

var _items: Array[Item] = []
var _grid: VBoxContainer
var _inspect: PanelContainer
var _inspect_rows: VBoxContainer
var _discard: Button


func _init() -> void:
	add_theme_constant_override("separation", 8)

	# The squares. Everything stays at the theme's 16 px: Pixellari breaks up below that, so a
	# quieter line is said with words rather than with a smaller font.
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", GAP)
	_grid.gui_input.connect(_on_grid_input)
	add_child(_grid)

	# One drop, looked at properly. On the white panel, because that is the ground the rarity
	# colours were picked to be read against.
	_inspect = PanelContainer.new()
	_inspect.theme_type_variation = "TextPanel"
	_inspect.hide()
	add_child(_inspect)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 2)
	_inspect.add_child(rows)
	_inspect_rows = VBoxContainer.new()
	_inspect_rows.add_theme_constant_override("separation", 2)
	rows.add_child(_inspect_rows)
	# Above Back rather than beside it: the two are not a pair of alternatives, and a destructive
	# button sharing a row with the way out is a button that gets hit on the way out.
	_discard = Button.new()
	_discard.text = "Discard"
	_discard.theme_type_variation = "LightDangerButton"
	_discard.hide()
	_discard.pressed.connect(_on_discard_pressed)
	rows.add_child(_discard)
	var done := Button.new()
	done.text = "Back"
	done.theme_type_variation = "LightButton"
	done.pressed.connect(inspect.bind(-1))
	rows.add_child(done)


## Draws `items` as squares, in the order they fell, and closes whatever was open. Nothing is
## counted together: every drop rolled its own rarity and its own modifiers, so no two are one thing.
func fill(items: Array[Item]) -> void:
	_items = items.duplicate()
	inspect(-1)
	for child: Node in _grid.get_children():
		child.queue_free()
	if _items.is_empty():
		var none := Label.new()
		none.theme_type_variation = "PanelLabel"
		none.text = "Nothing dropped"
		none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none.modulate = Color(1.0, 1.0, 1.0, 0.5)
		_grid.add_child(none)
		return
	var row: HBoxContainer = null
	for i in _items.size():
		if i % PER_ROW == 0:
			row = HBoxContainer.new()
			row.add_theme_constant_override("separation", GAP)
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			_grid.add_child(row)
		var slot := ItemSlot.make(_items[i])
		# Which drop this is, so a click on it can find its way back to the item.
		slot.set_meta("drop_index", i)
		row.add_child(slot)


## Whether one drop's details are open rather than the grid.
func inspecting() -> bool:
	return _inspect.visible


## How many drops are being shown.
func count() -> int:
	return _items.size()


## A square is a Panel that takes no mouse input at all -- the same rule the bag's grid keeps, and
## for the same reason -- so which one was hit is worked out from where the click landed.
func _on_grid_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	for row: Node in _grid.get_children():
		if not (row is HBoxContainer):
			continue
		for slot: Control in (row as HBoxContainer).get_children():
			if slot.get_global_rect().has_point(event.global_position):
				inspect(slot.get_meta("drop_index", -1))
				return


## Opens what one drop actually is, in the grid's place, or goes back to the grid with -1.
func inspect(index: int) -> void:
	if index < 0 or index >= _items.size():
		_inspect.hide()
		_grid.show()
	else:
		ItemDetails.fill(_inspect_rows, _items[index], INSPECT_WIDTH)
		_discard.visible = discardable
		_discard.set_meta("drop_index", index)
		_grid.hide()
		_inspect.show()
	resized_contents.emit()


## Says which drop is to go and shuts the block. What is actually carried is the owner's to change,
## and it will fill this view again -- so this closes rather than waiting to be told to.
func _on_discard_pressed() -> void:
	var index: int = _discard.get_meta("drop_index", -1)
	if index < 0 or index >= _items.size():
		return
	var item := _items[index]
	inspect(-1)
	discarded.emit(item)
