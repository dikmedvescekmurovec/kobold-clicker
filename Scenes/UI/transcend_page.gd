class_name TranscendPage
extends Control
## The black screen between two worlds. The fortuneteller's way out fades the game to it, and on it
## the player is paid for the world they are leaving: **one piece of it made an heirloom, and a super
## orb (`SuperOrbTable`) for every wall they broke**, spent on the heirlooms they hold.
##
## Four faces, one up at a time: the choice (Create an heirloom / Upgrade an heirloom / Take on a
## curse, and the way on under them), the curses (`Curses`: as many skulls as the budget this world earned
## and the dungeon's depth, `Inventory.skull_allowance`, for the world to come,
## kept in `Inventory.pending_curses` and nowhere else until `transcended()` reads them), and behind
## each of the first two cards a `BagPage` built for it (`transcending` true) -- over the bag
## and the ordinary doll to choose the piece to keep, over the heirlooms with the super orbs for its
## tray. Both go back to the choice by the arrow beside them, their X, or Escape.
##
## **Nothing here is written to a file.** Everything it changes it changes in the inventory it was
## given, and `finished` is the main scene's cue to write `Inventory.transcended()` over the save in
## the one write a transcension has always been. A game closed on this screen is a game in which the
## fortuneteller was never asked -- which is also what keeps closing it from being a way to make an
## heirloom and stay.

## The player has pressed on into the new world.
signal finished

const CROWN_ICON := "res://Assets/UI/ui_icon_crown.png"
const SKULL_ICON := "res://Assets/UI/ui_icon_skull.png"
## The curses' table, in panel pixels a column: the tick box and the name, the skulls, what it costs
## and what it pays. A budget, like every width here: the four and their gaps stay inside a 576 px window.
const CURSE_NAME_WIDTH := 116.0
const CURSE_SKULLS_WIDTH := 28.0
const CURSE_COST_WIDTH := 190.0
const CURSE_PAYS_WIDTH := 140.0
const SKULL_SIDE := 8.0
## Panel pixels of black left above and below the curses' panel when the table is taller than the window.
const CURSE_MARGIN := 6.0
## Seconds the world takes to go dark, where animations are on at all.
const FADE := 1.5
const CARD_WIDTH := 164.0
## A card's button: its picture over its words, and both cards one size whatever they wear.
const CARD_HEIGHT := 76.0
const CARD_GAP := 12

var _inventory: Inventory
var _ui_scale: float
## Whether this world's one heirloom has been made.
var _made := false
## Whether the world was lost rather than left (No Second Chances): then nothing of it may be kept,
## and it raises no skulls. Read by the main scene, which hands it to `Inventory.transcended`.
var lost := false
## The skulls the curses may add up to: the budget this world leaves the player and the dungeon's depth
## (`skull_allowance`).
var _budget := 0
## The way on has been pressed once with the heirloom still unmade, and asked if that was meant.
var _warned := false

var _choice: VBoxContainer
var _create_page: BagPage
var _upgrade_page: BagPage
var _back: Button
## The curses' face, built again at every press the way the choice is.
var _curse_face: VBoxContainer
## The table's rows and the scroll they stand in: `_layout` gives the scroll what the window has left,
## so a table longer than the window scrolls under its pinned headings.
var _curse_scroll: ScrollContainer
var _curse_table: Control
## Every line of the curses' table, headings first: what `_fit_curses` narrows.
var _curse_lines: Array[HBoxContainer] = []


func _init(inventory: Inventory, ui_scale: float, world_lost := false) -> void:
	_inventory = inventory
	lost = world_lost
	_budget = inventory.skull_allowance(world_lost)
	_ui_scale = ui_scale
	theme = UITheme.theme()
	# The whole window, and it stops the mouse: the world under it is over.
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	var shade := ColorRect.new()
	shade.color = Color.BLACK
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	# Whatever an earlier black screen left chosen was never the world's: this one starts from none.
	_inventory.pending_curses = []
	_create_page = BagPage.new(_inventory, "", _ui_scale, false, true)
	_upgrade_page = BagPage.new(_inventory, "", _ui_scale, true, true)
	_create_page.heirloom_made.connect(func(_item: Item) -> void:
		_made = true
		_show_choice())
	for page: BagPage in [_create_page, _upgrade_page]:
		page.hide()
		page.closed.connect(_show_choice)
		page.laid_out.connect(_place_back.bind(page))
		add_child(page)
	_back = UITheme.icon_button(load(UITheme.BACK_ICON), "Back to the choice", _ui_scale)
	_back.pressed.connect(_show_choice)
	_back.hide()
	add_child(_back)
	get_viewport().size_changed.connect(_layout)
	if Settings.animations == Settings.Anim.NONE:
		_show_choice()
		return
	shade.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(shade, "modulate:a", 1.0, FADE)
	fade.tween_callback(_show_choice)


## The two cards and the way on, built again each time: what they say moves with what was done.
func _show_choice() -> void:
	_create_page.hide()
	_upgrade_page.hide()
	_back.hide()
	if _curse_face != null:
		_curse_face.queue_free()
		_curse_face = null
	if _choice != null:
		_choice.queue_free()
	_choice = UITheme.vbox(CARD_GAP)
	_choice.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_choice)
	# Side by side, or one over another on a window held upright, where three do not fit across.
	var cards := BoxContainer.new()
	cards.vertical = UITheme.narrow(get_viewport_rect().size, _ui_scale)
	cards.add_theme_constant_override("separation", CARD_GAP)
	_choice.add_child(cards)

	var held := _inventory.stash().total() + _inventory.stash().equipment.worn.size()
	var orbs := _inventory.super_orbs
	cards.add_child(_card("Create an heirloom", load(CROWN_ICON), not _made and not lost,
			"Lost to No Second Chances" if lost else "Done" if _made else "",
			_open.bind(_create_page)))
	cards.add_child(_card("Upgrade an heirloom", SuperOrbTable.icon(SuperOrbTable.ASCENSION),
			held > 0 and orbs > 0,
			"None held" if held == 0 else "No orbs left" if orbs == 0 else "%d to spend" % orbs,
			_open.bind(_upgrade_page)))
	var taken := PackedStringArray()
	for id: String in _inventory.pending_curses:
		taken.append(str(Curses.CURSES[id]["name"]))
	var spent := Curses.skulls_of(_inventory.pending_curses)
	cards.add_child(_card("Take on a curse", load(SKULL_ICON), _budget > 0,
			"No skulls" if _budget == 0 else "0 of %d skulls" % _budget if taken.is_empty()
			else "%s: %d of %d skulls" % [", ".join(taken), spent, _budget],
			_show_curses))

	var on := UITheme.button("Leave without an heirloom" if _warned and not _made
			else "Enter the new world", "LightButton", "")
	on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	on.pressed.connect(_on_finish_pressed)
	_choice.add_child(on)
	_layout()
	_layout.call_deferred()


## One card: its button, and under it where it stands (done, what is left to spend), in bone on the
## black -- a status, never what the card is for: the user wants no explaining on a page.
func _card(title: String, mark: Texture2D, live: bool, text: String, pressed: Callable) -> Control:
	var card := UITheme.vbox(4, CARD_WIDTH)
	var button := UITheme.button(title, "LightButton", "")
	button.icon = mark
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	button.disabled = not live
	button.pressed.connect(pressed)
	card.add_child(button)
	if text.is_empty():
		return card
	var words := UITheme.label(text, Palette.BONE, true)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = CARD_WIDTH
	card.add_child(words)
	return card


## The curses for the world to come, as the character page's stats are written: a cream panel, and in
## it a framed table of striped rows -- a tick box and the name, the skulls, what it costs in rust and
## what it pays in leaf. The rows the skulls left cannot pay for stand back and take no press. Built again at every
## tick, so what is ticked and what is faded is never stale.
func _show_curses() -> void:
	_warned = false
	_choice.hide()
	# A tick builds the table again, and must leave it where the player had scrolled it to.
	var scrolled := 0
	if _curse_face != null:
		scrolled = _curse_scroll.scroll_vertical
		_curse_face.queue_free()
	var pending := _inventory.pending_curses
	_curse_lines.clear()
	_curse_face = UITheme.titled_panel("Skulls: %d of %d" % [Curses.skulls_of(pending), _budget],
			"Back to the choice", _show_choice)
	_curse_face.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_curse_face)
	var body := UITheme.body_of(_curse_face)
	# The headings are pinned over the scroll, a pixel in for the frame's border so they stand over
	# their columns.
	var headings := MarginContainer.new()
	headings.add_theme_constant_override("margin_left", 1)
	headings.add_child(_curse_row(_curse_cells(UITheme.label("Name", Palette.TEXT_SOFT, true), null,
			UITheme.label("Curse", Palette.TEXT_SOFT, true), UITheme.label("Boon", Palette.TEXT_SOFT, true)), false))
	body.add_child(headings)
	# A framed block of its own, as the stats are: the panel's row gap would pull a table apart. In a
	# scroll, because the sentences are written to be understood and not to fit, and the list will grow.
	_curse_scroll = ScrollContainer.new()
	_curse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_curse_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(_curse_scroll)
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", BountyList.flat(Color.TRANSPARENT, 1))
	var rows := UITheme.vbox(0)
	table.add_child(rows)
	_curse_scroll.add_child(table)
	_curse_table = table
	for id: String in Curses.CURSES:
		var curse: Dictionary = Curses.CURSES[id]
		# Dead where the skulls left cannot pay for it, or it cannot stand with one taken (`Curses.fits`).
		var full := not id in pending and not Curses.fits(id, pending, _budget)
		var tick := BagPage.check_box(str(curse["name"]))
		var box := tick.get_child(0) as Button
		# Named for the curse, which is how a test finds it; ticked before anything listens.
		box.name = id
		box.button_pressed = id in pending
		box.disabled = full
		box.toggled.connect(_on_curse_toggled.bind(id))
		if full:
			# The name is the box's second handle, and a dead box must have none.
			(tick.get_child(1) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		# How hard it is, in skulls: the pack's 16 px mark at half size, the orb tray's 2:1.
		var skulls := HBoxContainer.new()
		skulls.add_theme_constant_override("separation", 1)
		for i in int(curse["skulls"]):
			var skull := TextureRect.new()
			skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			skull.texture = load(SKULL_ICON)
			skull.custom_minimum_size = Vector2(SKULL_SIDE, SKULL_SIDE)
			skull.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			# The mark is cut pale for a brown face and would wash out on cream: the names' own brown
			# keeps its sockets, where ink made a blot of it.
			skull.modulate = Palette.SLOT_TAN_DK
			skulls.add_child(skull)
		var row := _curse_row(_curse_cells(tick, skulls, UITheme.label(str(curse["text"]), Palette.RUST, true),
				UITheme.label(str(curse["reward"]), Palette.LEAF, true)), rows.get_child_count() % 2 == 0)
		if full:
			row.modulate = TownPage.TAB_REST
		rows.add_child(row)
	_fit_curses()
	_back.show()
	_layout()
	_layout.call_deferred()
	_curse_scroll.set_deferred("scroll_vertical", scrolled)


## A line of the table on its stripe, padded as `UITheme.table_row` pads its own.
func _curse_row(cells: Control, striped: bool) -> PanelContainer:
	var row := PanelContainer.new()
	var stripe := StyleBoxFlat.new()
	stripe.bg_color = UITheme.TABLE_STRIPE if striped else Color.TRANSPARENT
	stripe.set_content_margin_all(UITheme.TABLE_PAD.y)
	stripe.content_margin_left = UITheme.TABLE_PAD.x
	stripe.content_margin_right = UITheme.TABLE_PAD.x
	row.add_theme_stylebox_override("panel", stripe)
	row.add_child(cells)
	return row


## One line of the curses' table, heading or row: four cells at the table's four widths, the words
## wrapped in what their column leaves them.
func _curse_cells(first: Control, skulls: Control, costs: Label, pays: Label) -> HBoxContainer:
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", UITheme.TABLE_GAP)
	var widths := [CURSE_NAME_WIDTH, CURSE_SKULLS_WIDTH, CURSE_COST_WIDTH, CURSE_PAYS_WIDTH]
	var made: Array = [first, skulls if skulls != null else Control.new(), costs, pays]
	_curse_lines.append(cells)
	for i in made.size():
		var cell: Control = made[i]
		cell.custom_minimum_size.x = widths[i]
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if cell is Label:
			(cell as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		cells.add_child(cell)
	return cells


## Too wide for the window -- a phone held upright -- the table's two sentences give up the difference
## between them and wrap in what is left, so no column runs off the screen.
func _fit_curses() -> void:
	var room := get_viewport_rect().size.x / _ui_scale - 2.0 * CURSE_MARGIN
	var over := _curse_face.get_combined_minimum_size().x - room
	if over <= 0.0:
		return
	var words := CURSE_COST_WIDTH + CURSE_PAYS_WIDTH
	var cost := floorf((words - over) * CURSE_COST_WIDTH / words)
	for cells: HBoxContainer in _curse_lines:
		(cells.get_child(2) as Control).custom_minimum_size.x = cost
		(cells.get_child(3) as Control).custom_minimum_size.x = words - over - cost


func _on_curse_toggled(on: bool, id: String) -> void:
	_inventory.pending_curses.erase(id)
	if on and Curses.fits(id, _inventory.pending_curses, _budget):
		_inventory.pending_curses.append(id)
	_show_curses()


func _open(page: BagPage) -> void:
	_warned = false
	_choice.hide()
	_create_page.hide()
	_upgrade_page.hide()
	page.open()
	page.show()
	page.layout()
	_back.show()


## The arrow stands against the open page's top-left corner, outside it.
func _place_back(page: BagPage) -> void:
	if page.visible:
		_back.position = page.panel_corner() - Vector2(
				(_back.get_combined_minimum_size().x + BagPage.WORN_GAP) * _ui_scale, 0.0)
		# A page as wide as the window leaves it nowhere to stand; the page's X is the same way back.
		_back.visible = _back.position.x >= 0.0


func _layout() -> void:
	if _choice != null and is_instance_valid(_choice):
		_choice.size = _choice.get_combined_minimum_size()
		_choice.position = ((get_viewport_rect().size - _choice.size * _ui_scale) / 2.0).floor()
	if _curse_face != null and is_instance_valid(_curse_face):
		# The scroll is as tall as its table, or as what the window has left once the panel's bar,
		# headings and margins have had theirs: measured with the scroll at nothing, so it is all of them.
		_curse_scroll.custom_minimum_size = Vector2(_curse_table.get_combined_minimum_size().x, 0.0)
		var chrome := _curse_face.get_combined_minimum_size().y
		var room := floorf(get_viewport_rect().size.y / _ui_scale) - chrome - CURSE_MARGIN * 2.0
		_curse_scroll.custom_minimum_size.y = minf(_curse_table.get_combined_minimum_size().y, maxf(room, 0.0))
		_curse_face.size = _curse_face.get_combined_minimum_size()
		_curse_face.position = ((get_viewport_rect().size - _curse_face.size * _ui_scale) / 2.0).floor()
		# The arrow against the face's top-left corner, outside it, as it stands against a page's.
		_back.position = _curse_face.position - Vector2(
				(_back.get_combined_minimum_size().x + BagPage.WORN_GAP) * _ui_scale, 0.0)
		# A face as wide as the window leaves the arrow nowhere to stand; its X is the same way back.
		_back.visible = _back.position.x >= 0.0
	for page: BagPage in [_create_page, _upgrade_page]:
		if page.visible:
			page.layout()


## The way on. Asked twice only where it would throw the heirloom away unmade -- an orb unspent is
## kept (`Inventory.transcended`), the heirloom not made is not.
func _on_finish_pressed() -> void:
	if not _made and not _warned and not lost and _can_make_any():
		_warned = true
		_show_choice()
		return
	finish()


## Leaves, whatever has or has not been done. What a test presses.
func finish() -> void:
	finished.emit()


func _can_make_any() -> bool:
	for item: Item in _inventory.items + _inventory.equipment.items():
		if _inventory.can_make_heirloom(item):
			return true
	return false


## Escape is the way back from a page, after the page's own question has had it (`BagPage`), and on
## the choice it is nothing: there is no way back into the world from here.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _back.visible:
		_show_choice()
