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
## The grid and the details swap rather than stack, the way `BagPage`'s `_scroll` and `_detail` swap on
## the bag: a piece carrying six modifiers is taller than the verdict it would push down.

## How many drops stand in a row. How big a square is belongs to ItemSlot, not here.
const PER_ROW := 4
## How wide a line of an item's details may run before it wraps, in panel pixels.
const INSPECT_WIDTH := 150.0
## The gap between squares. The same seven-to-one proportion the bag's grid keeps.
const GAP := ItemSlot.SIDE / 7
## How many rows of squares show before the rest scroll by the wheel. A half row, so the cut-off
## squares say there is more; sized so the verdict still fits a 648 px window at `ui_scale` 2.
const MAX_ROWS := 3.5
## The fewest rows a short window cuts the box to (`fit_rows`).
const FEWEST_ROWS := 1.5

## How many rows of squares show before the rest scroll: `MAX_ROWS`, or fewer in a short window.
var most_rows := MAX_ROWS

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
var _ground: PanelContainer
var _none: Label
var _grid: VBoxContainer
var _scroll: ScrollContainer
var _orbs: HBoxContainer
var _inspect: PanelContainer
var _inspect_rows: VBoxContainer
var _discard: Button


func _init() -> void:
	add_theme_constant_override("separation", 8)

	# A fight that turned up nothing says so in a plain line, with no ground under it: in the framed
	# ground, the words at half strength read as a dead button.
	_none = UITheme.label("Nothing dropped", Palette.TEXT_SOFT, true)
	_none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_none.hide()
	add_child(_none)

	# The squares, on the bag's own light panel, so a find stands on the ground it will stand on once it is kept.
	_ground = PanelContainer.new()
	_ground.theme_type_variation = "TextPanel"
	add_child(_ground)
	var found := VBoxContainer.new()
	found.add_theme_constant_override("separation", GAP)
	_ground.add_child(found)
	_grid = VBoxContainer.new()
	_grid.add_theme_constant_override("separation", GAP)
	_grid.gui_input.connect(_on_grid_input)
	# No bar, as on the bag: the half row showing is the hint, and the wheel does the rest.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	found.add_child(_scroll)
	_scroll.add_child(_grid)
	# As wide as the box, so a row of one stands in the middle of it rather than against its left edge:
	# a scroll child that does not ask to expand is only as wide as it has to be.
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# The orbs the fight turned up, under the squares as the tray is under the bag. A record only:
	# they take no mouse, because there is nothing here an orb can be pressed to do.
	_orbs = HBoxContainer.new()
	_orbs.add_theme_constant_override("separation", GAP)
	_orbs.alignment = BoxContainer.ALIGNMENT_CENTER
	found.add_child(_orbs)

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
	# One row, the arrow first and Discard taking the rest, as under a piece open in the bag
	# (`BagPage._action_row`) -- and so this arrow never stacks over the verdict's own.
	var actions := HBoxContainer.new()
	rows.add_child(actions)
	var done := UITheme.back_button("Back to what was found")
	done.pressed.connect(inspect.bind(-1))
	actions.add_child(done)
	_discard = Button.new()
	_discard.text = "Discard"
	_discard.theme_type_variation = "LightDangerButton"
	_discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_discard.hide()
	_discard.pressed.connect(_on_discard_pressed)
	actions.add_child(_discard)


## Draws `items` as squares, in the order they fell, and closes whatever was open. Nothing is
## counted together: every drop rolled its own rarity and its own modifiers, so no two are one thing.
## `orbs` is kind -> count, drawn as a row under the squares; the verdict hands them over and the
## mid-run popup does not.
func fill(items: Array[Item], orbs := {}) -> void:
	_items = items.duplicate()
	_none.visible = _items.is_empty() and orbs.is_empty()
	inspect(-1)
	UITheme.clear(_grid)
	UITheme.clear(_orbs)
	for orb: String in orbs:
		var held := OrbSlot.make(orb, int(orbs[orb]), true)
		held.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_orbs.add_child(held)
	_orbs.visible = not orbs.is_empty()
	_scroll.visible = not _items.is_empty()
	if _items.is_empty():
		_fit_scroll()
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
	_fit_scroll()


## Up to `most_rows` the box does not scroll and so is as tall as the grid; past it, it is cut to
## `most_rows` and scrolls. Counted rather than measured: the grid has not been laid out yet.
func _fit_scroll() -> void:
	_scroll.scroll_vertical = 0
	var long := ceili(_items.size() / float(PER_ROW)) > most_rows
	_scroll.vertical_scroll_mode = (ScrollContainer.SCROLL_MODE_SHOW_NEVER if long
			else ScrollContainer.SCROLL_MODE_DISABLED)
	_scroll.custom_minimum_size.y = most_rows * ItemSlot.SIDE + floorf(most_rows) * GAP if long else 0.0


## The box `over` panel pixels too tall for the window its owner stands in: rows are given up until it
## fits, down to `FEWEST_ROWS`, still ending on a half row so the cut-off squares say there is more.
func fit_rows(over: float) -> void:
	var shown := minf(most_rows, ceili(_items.size() / float(PER_ROW)))
	var rows := floorf((shown - over / (ItemSlot.SIDE + GAP)) * 2.0) / 2.0
	if rows == floorf(rows):
		rows -= 0.5
	most_rows = maxf(FEWEST_ROWS, rows)
	_fit_scroll()


## Whether one drop's details are open rather than the grid.
func inspecting() -> bool:
	return _inspect.visible


## How many drops are being shown.
func count() -> int:
	return _items.size()


## A square is a Panel that takes no mouse input at all -- the same rule the bag's grid keeps, and
## for the same reason -- so which one was hit is worked out from where the click landed.
func _on_grid_input(event: InputEvent) -> void:
	Cursors.over_squares(_grid, event)
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	for row: Node in _grid.get_children():
		if not (row is HBoxContainer):
			continue
		for slot: Control in (row as HBoxContainer).get_children():
			if slot.get_global_rect().has_point(event.global_position):
				inspect(slot.get_meta("drop_index", -1))
				return


## Everything on show, orbs first and the finds after them in the order they fell: what a reward
## panel pops in one at a time (`Juice.reveal`).
func pieces() -> Array:
	var shown: Array = _orbs.get_children()
	for row: Node in _grid.get_children():
		if row is HBoxContainer:
			shown.append_array(row.get_children())
	return shown


## Opens what one drop actually is, in the grid's place, or goes back to the grid with -1.
func inspect(index: int) -> void:
	if index < 0 or index >= _items.size():
		_inspect.hide()
		_ground.visible = not _none.visible
	else:
		ItemDetails.fill(_inspect_rows, _items[index], INSPECT_WIDTH)
		_discard.visible = discardable
		_discard.set_meta("drop_index", index)
		_ground.hide()
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
