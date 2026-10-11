class_name TranscendPage
extends Control
## The black screen between two worlds, where the player is paid for the world they are leaving. Its
## faces, one up at a time: the choice (four cards and the way on), the curses' table, and behind three
## of the cards a `BagPage` built for it (`transcending` true). Each goes back to the choice by the
## arrow beside it, its X, or Escape.
##
## **Nothing here is written to a file.** Everything it changes it changes in the inventory it was
## given, and `finished` is the main scene's cue to write `Inventory.transcended()` over the save in
## the one write a transcension has always been: a game closed on this screen has not transcended.

## The player has pressed on into the new world.
signal finished

const CROWN_ICON := "res://Assets/UI/ui_icon_crown.png"
const CHEST_ICON := "res://Assets/UI/ui_icon_chest.png"
const SKULL_ICON := "res://Assets/UI/ui_icon_skull.png"
## The curses' table, in panel pixels a column: the tick box and the name, the skulls, what it costs
## and what it pays. A budget, like every width here: the four and their gaps stay inside a 576 px window.
const CURSE_NAME_WIDTH := 116.0
const CURSE_SKULLS_WIDTH := 28.0
const CURSE_COST_WIDTH := 190.0
const CURSE_PAYS_WIDTH := 140.0
## A skull in the table: the pack's 16 px mark at half size, the orb tray's 2:1.
const SKULL_SIDE := 8
## Panel pixels of black left above and below the curses' panel when the table is taller than the window.
const CURSE_MARGIN := 6.0
## Seconds the world takes to go dark, where animations are on at all.
const FADE := 1.5
const CARD_WIDTH := 164.0
## A card's button: its picture over its words, and both cards one size whatever they wear.
const CARD_HEIGHT := 76.0
## How tall a card's picture stands, padded to it (`_padded`).
const CARD_MARK := 32.0
const CARD_GAP := 12

var _inventory: Inventory
var _ui_scale: float
## Whether this world's one heirloom has been made.
var _made := false
## Whether the world was lost rather than left (No Second Chances): then nothing of it may be kept,
## and the way on asks nothing.
var lost := false
## The skulls the curses may add up to: the dungeon's depths won (`skull_allowance`).
var _budget := 0
## The way on has been pressed once with the heirloom still unmade, and asked if that was meant.
var _warned := false

var _choice: VBoxContainer
var _create_page: BagPage
var _upgrade_page: BagPage
## The skill tree's: the bag's stones placed and crafted with the orbs left over (`BagPage`'s stones mode).
var _stones_page: BagPage
var _back: Button
## Under the arrow on the make-an-heirloom screen, while heirlooms are held: the crown turns the page to
## the heirlooms, to weigh the piece against them, and the chest turns it back to the items.
var _swap: Button
var _swapping := false
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
	_budget = inventory.skull_allowance()
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
	_stones_page = BagPage.new(_inventory, "", _ui_scale, false, true, true)
	_create_page.heirloom_made.connect(_name_heirloom)
	for page: BagPage in _pages():
		page.hide()
		page.closed.connect(_show_choice)
		page.laid_out.connect(_place_back.bind(page))
		add_child(page)
	_back = UITheme.icon_button(load(UITheme.BACK_ICON), "Back to the choice", _ui_scale)
	_back.pressed.connect(_show_choice)
	_back.hide()
	add_child(_back)
	_swap = UITheme.icon_button(load(CROWN_ICON), "Your heirlooms", _ui_scale)
	_swap.pressed.connect(func() -> void:
		_open(_upgrade_page if _create_page.visible else _create_page, true))
	_swap.hide()
	add_child(_swap)
	get_viewport().size_changed.connect(_layout)
	if Settings.animations == Settings.Anim.NONE:
		_show_choice()
		return
	shade.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(shade, "modulate:a", 1.0, FADE)
	fade.tween_callback(_show_choice)


func _pages() -> Array[BagPage]:
	return [_create_page, _upgrade_page, _stones_page]


## How many heirlooms are held, in the stash and on its doll.
func _heirlooms_held() -> int:
	return _inventory.stash().total() + _inventory.stash().equipment.worn.size()


## Takes a face out of the tree at once: a queued one would still be found, and pressed, this frame.
func _drop(face: Control) -> void:
	if face != null:
		remove_child(face)
		face.queue_free()


## The cards and the way on, built again each time: what they say moves with what was done.
func _show_choice() -> void:
	for page: BagPage in _pages():
		page.hide()
	_back.hide()
	_swapping = false
	_swap.hide()
	_drop(_curse_face)
	_curse_face = null
	_drop(_choice)
	_choice = UITheme.vbox(CARD_GAP)
	_choice.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_choice)
	# Two by two, or one over another on a window held upright, where two do not fit across.
	var cards := GridContainer.new()
	cards.columns = 1 if UITheme.narrow(get_viewport_rect().size, _ui_scale) else 2
	cards.add_theme_constant_override("h_separation", CARD_GAP)
	cards.add_theme_constant_override("v_separation", CARD_GAP)
	_choice.add_child(cards)

	var held := _heirlooms_held()
	var orbs := _inventory.super_orbs
	cards.add_child(_card("Create an heirloom", load(CROWN_ICON), not _made and not lost,
			"Lost to No Second Chances" if lost else "Done" if _made else "",
			_open.bind(_create_page, true)))
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
	# Always open: with no stone to place, the orbs left over still go into the placed ones.
	var stones := _inventory.items.filter(func(item: Item) -> bool: return item.is_stone()).size()
	cards.add_child(_card(SkillsPage.TITLE, SkillTree.icon("root"), true,
			"None to place" if stones == 0 else "%d to place" % stones, _open.bind(_stones_page)))

	var on := UITheme.button("Leave without an heirloom" if _warned and not _made
			else "Enter the new world", "LightButton", "")
	on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	on.pressed.connect(_on_finish_pressed)
	_choice.add_child(on)
	_layout()
	_layout.call_deferred()


## The heirloom just made, back on the choice, and asked for a name over it: what is typed goes in its
## name's place from then on (`Item.nickname`); Cancel, or its own name, leaves it be.
func _name_heirloom(item: Item) -> void:
	_made = true
	_show_choice()
	var prompt := TextPrompt.new("Name your heirloom", item.base_name(), "Name", Inventory.NAME_MOST, _ui_scale)
	prompt.entered.connect(func(text: String) -> void:
		var called := text.strip_edges().left(Inventory.NAME_MOST)
		item.nickname = "" if called == item.base_name() else called)
	add_child(prompt)


## One card: its button, and under it in bone where it stands (done, what is left to spend) -- a status,
## never what the card is for: the user wants no explaining on a page.
func _card(title: String, mark: Texture2D, live: bool, text: String, pressed: Callable) -> Control:
	var card := UITheme.vbox(4, CARD_WIDTH)
	var button := UITheme.button(title, "LightButton", "")
	button.icon = _padded(mark)
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


## `mark` with clear rows above and below it to `CARD_MARK` tall, so every card's words stand at one
## height whatever its picture: the crown and the skull are 16 px, the orb and the root 32.
static func _padded(mark: Texture2D) -> Texture2D:
	var padded := AtlasTexture.new()
	padded.atlas = mark
	padded.region = Rect2(Vector2.ZERO, mark.get_size())
	var spare := maxf(0.0, CARD_MARK - mark.get_height())
	padded.margin = Rect2(0.0, floorf(spare / 2.0), 0.0, spare)
	return padded


## The curses for the world to come, as the character page's stats are written: a cream panel, and in
## it a framed table of striped rows. The rows the skulls left cannot pay for stand back and take no
## press. Built again at every tick, so what is ticked and what is faded is never stale.
func _show_curses() -> void:
	_warned = false
	_choice.hide()
	# A tick builds the table again, and must leave it where the player had scrolled it to.
	var scrolled := 0
	if _curse_face != null:
		scrolled = _curse_scroll.scroll_vertical
	_drop(_curse_face)
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
	# In a scroll, because the sentences are written to be understood and not to fit, and the list will grow.
	_curse_scroll = ScrollContainer.new()
	_curse_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_curse_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	body.add_child(_curse_scroll)
	var rows := BountyList.framed()
	_curse_table = rows.get_parent() as Control
	_curse_scroll.add_child(_curse_table)
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
		var skulls := HBoxContainer.new()
		skulls.add_theme_constant_override("separation", 1)
		for i in int(curse["skulls"]):
			var skull := BountyList.icon(load(SKULL_ICON), SKULL_SIDE)
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


## A line of the table on its stripe, in `UITheme.table_row`'s own box.
func _curse_row(cells: Control, striped: bool) -> PanelContainer:
	var row := UITheme.row_panel(striped)
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


## `swap`: the page is the make-an-heirloom screen's, items or heirlooms, and wears the crown or the chest.
func _open(page: BagPage, swap := false) -> void:
	_warned = false
	_choice.hide()
	for each: BagPage in _pages():
		each.hide()
	_swapping = swap and _heirlooms_held() > 0
	_swap.icon = load(CROWN_ICON if page == _create_page else CHEST_ICON)
	_swap.tooltip_text = "Your heirlooms" if page == _create_page else "Items"
	_swap.visible = _swapping
	page.open()
	page.show()
	page.layout()
	_back.show()


## The arrow against `corner`, a page's or a face's top-left, outside it. One as wide as the window
## leaves it nowhere to stand, and it hides: the X is the same way back.
func _stand_back(corner: Vector2) -> void:
	_back.position = corner - Vector2((_back.get_combined_minimum_size().x + BagPage.WORN_GAP) * _ui_scale, 0.0)
	_back.visible = _back.position.x >= 0.0


func _place_back(page: BagPage) -> void:
	if page.visible:
		_stand_back(page.panel_corner())
		_swap.position = _back.position + Vector2(0.0,
				(_back.get_combined_minimum_size().y + BagPage.WORN_GAP) * _ui_scale)
		# ponytail: where the arrow has no room (a phone held upright) the crown goes with it; give it a
		# place in the page's own bar if that turns out to matter.
		_swap.visible = _swapping and _back.visible


## Stands a face in the middle of the window at its own size.
func _centre(face: Control) -> void:
	face.size = face.get_combined_minimum_size()
	face.position = ((get_viewport_rect().size - face.size * _ui_scale) / 2.0).floor()


func _layout() -> void:
	if _choice != null and is_instance_valid(_choice):
		_centre(_choice)
	if _curse_face != null and is_instance_valid(_curse_face):
		# The scroll is as tall as its table, or as what the window has left once the panel's bar,
		# headings and margins have had theirs: measured with the scroll at nothing, so it is all of them.
		_curse_scroll.custom_minimum_size = Vector2(_curse_table.get_combined_minimum_size().x, 0.0)
		var chrome := _curse_face.get_combined_minimum_size().y
		var room := floorf(get_viewport_rect().size.y / _ui_scale) - chrome - CURSE_MARGIN * 2.0
		_curse_scroll.custom_minimum_size.y = minf(_curse_table.get_combined_minimum_size().y, maxf(room, 0.0))
		_centre(_curse_face)
		_stand_back(_curse_face.position)
	for page: BagPage in _pages():
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
## the choice it is nothing: there is no way back into the world from here. Asked of the choice and not
## of the arrow, which has no room to stand beside a face as wide as a phone held upright.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _choice != null and not _choice.visible:
		_show_choice()
