class_name TranscendPage
extends Control
## The black screen between two worlds. The fortuneteller's way out fades the game to it, and on it
## the player is paid for the world they are leaving: **one piece of it made an heirloom, and a super
## orb (`SuperOrbTable`) for every wall they broke**, spent on the heirlooms they hold.
##
## Four faces, one up at a time: the choice (Create an heirloom / Upgrade an heirloom / Take on a
## curse, and the way on under them), the curses (`Curses`: up to `Curses.MOST` for the world to come,
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
## A curse's row on the black: its name on a button that stays down while it is taken, and beside it
## what it costs and what it pays.
const CURSE_NAME_WIDTH := 124.0
const CURSE_TEXT_WIDTH := 220.0
const SKULL_SIDE := 8.0
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
## The way on has been pressed once with the heirloom still unmade, and asked if that was meant.
var _warned := false

var _choice: VBoxContainer
var _create_page: BagPage
var _upgrade_page: BagPage
var _back: Button
## The curses' face, built again at every press the way the choice is.
var _curse_face: VBoxContainer


func _init(inventory: Inventory, ui_scale: float) -> void:
	_inventory = inventory
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
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", CARD_GAP)
	_choice.add_child(cards)

	var held := _inventory.stash().total() + _inventory.stash().equipment.worn.size()
	var orbs := _inventory.super_orbs
	cards.add_child(_card("Create an heirloom", load(CROWN_ICON), not _made,
			"Done. It goes with you." if _made
			else "Choose one piece of this world, carried or worn. It goes with you into every world after this one.",
			_open.bind(_create_page)))
	cards.add_child(_card("Upgrade an heirloom", SuperOrbTable.icon(SuperOrbTable.ASCENSION),
			held > 0 and orbs > 0,
			"You hold no heirloom yet." if held == 0
			else "Every wall you broke is an orb of great power, and none is left." if orbs == 0
			else "Every wall you broke is an orb of great power. You have %d to spend on the heirlooms you hold." % orbs,
			_open.bind(_upgrade_page)))
	var taken := PackedStringArray()
	for id: String in _inventory.pending_curses:
		taken.append(str(Curses.CURSES[id]["name"]))
	cards.add_child(_card("Take on a curse", load(SKULL_ICON), true,
			"A harder world that pays for it, if you want one. None taken." if taken.is_empty()
			else "The new world is under %s." % ", ".join(taken),
			_show_curses))

	var on := UITheme.button("Leave without an heirloom" if _warned and not _made
			else "Enter the new world", "LightButton", "")
	on.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	on.pressed.connect(_on_finish_pressed)
	_choice.add_child(on)
	_layout()
	_layout.call_deferred()


## One card: its button, and under it what pressing it means, in bone on the black.
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
	var words := UITheme.label(text, Palette.BONE, true)
	words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.custom_minimum_size.x = CARD_WIDTH
	card.add_child(words)
	return card


## The curses for the world to come: every one a row, the taken ones held down, and the rest greyed
## once `Curses.MOST` are. Built again at every press, so what is down and what is grey is never stale.
func _show_curses() -> void:
	_warned = false
	_choice.hide()
	if _curse_face != null:
		_curse_face.queue_free()
	_curse_face = UITheme.vbox(4)
	_curse_face.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_curse_face)
	var pending := _inventory.pending_curses
	_curse_face.add_child(UITheme.label("Curses for the new world: %d of %d" % [pending.size(), Curses.MOST],
			Palette.BONE))
	for id: String in Curses.CURSES:
		var curse: Dictionary = Curses.CURSES[id]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var button := UITheme.button(str(curse["name"]), "LightButton", "")
		button.toggle_mode = true
		button.button_pressed = id in pending
		button.disabled = not id in pending and pending.size() >= Curses.MOST
		button.custom_minimum_size.x = CURSE_NAME_WIDTH
		# The pack's pressed face is one pixel, so once anything is taken the rest stand back, the way
		# the settings' unpicked buttons do.
		if not pending.is_empty() and not id in pending:
			button.modulate = TownPage.TAB_REST
		button.name = id
		button.toggled.connect(_on_curse_toggled.bind(id))
		row.add_child(button)
		# How hard it is, in skulls: the pack's 16 px mark at half size, the orb tray's 2:1.
		var skulls := HBoxContainer.new()
		skulls.add_theme_constant_override("separation", 1)
		skulls.custom_minimum_size.x = SKULL_SIDE * 3 + 2
		for i in int(curse["skulls"]):
			var skull := TextureRect.new()
			skull.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			skull.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			skull.texture = load(SKULL_ICON)
			skull.custom_minimum_size = Vector2(SKULL_SIDE, SKULL_SIDE)
			skull.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			skulls.add_child(skull)
		row.add_child(skulls)
		var words := UITheme.vbox(0)
		var costs := UITheme.label(str(curse["text"]), Palette.BONE, true)
		var pays := UITheme.label(str(curse["reward"]), Palette.GOLD, true)
		for line: Label in [costs, pays]:
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			line.custom_minimum_size.x = CURSE_TEXT_WIDTH
			words.add_child(line)
		row.add_child(words)
		_curse_face.add_child(row)
	_back.show()
	_layout()
	_layout.call_deferred()


func _on_curse_toggled(on: bool, id: String) -> void:
	_inventory.pending_curses.erase(id)
	if on and _inventory.pending_curses.size() < Curses.MOST:
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


func _layout() -> void:
	if _choice != null and is_instance_valid(_choice):
		_choice.size = _choice.get_combined_minimum_size()
		_choice.position = ((get_viewport_rect().size - _choice.size * _ui_scale) / 2.0).floor()
	if _curse_face != null and is_instance_valid(_curse_face):
		_curse_face.size = _curse_face.get_combined_minimum_size()
		_curse_face.position = ((get_viewport_rect().size - _curse_face.size * _ui_scale) / 2.0).floor()
		# The arrow against the face's top-left corner, outside it, as it stands against a page's.
		_back.position = _curse_face.position - Vector2(
				(_back.get_combined_minimum_size().x + BagPage.WORN_GAP) * _ui_scale, 0.0)
	for page: BagPage in [_create_page, _upgrade_page]:
		if page.visible:
			page.layout()


## The way on. Asked twice only where it would throw the heirloom away unmade -- an orb unspent is
## kept (`Inventory.transcended`), the heirloom not made is not.
func _on_finish_pressed() -> void:
	if not _made and not _warned and _can_make_any():
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
