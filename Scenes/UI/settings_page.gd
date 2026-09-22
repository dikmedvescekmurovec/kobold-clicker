class_name SettingsPage
extends Control
## What the player has chosen about the game, as a page against the left edge: sound, how much a
## fight throws about, how much an item says -- and, at its foot, the way to start over.
##
## Built like the other left-hand pages (`BountyList`): `open()` redraws it, `layout()` fits it to the
## window, `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`.
## Every change goes straight into `Settings` and its file; the saves are nothing to do with it, which
## is why Reset is a signal -- deleting them and reloading is the main scene's.

## The page's X was pressed.
signal closed
## Delete was pressed under the question Reset asks.
signal reset_pressed
## The debug build's Gold x10 was pressed.
signal cash_pressed
## The debug build's "Show all uniques" was ticked or unticked: the trophy may have come or gone.
signal uniques_toggled
## Dev: the "show all chests" box moved; the main scene redraws the map's chests.
signal chests_toggled
## The panel changed width (the generator is wider than the settings): the corner buttons beside it move.
signal laid_out

const WIDTH := 140.0
const ROW_GAP := 6
const ANIM_NAMES := ["None", "Low", "Default"]
## `Settings.Uniques` in order: what a heading's Sell all and bin do with a unique among the handful.
const UNIQUES_NAMES := ["Ask", "Sell", "Keep"]
const UNIQUES_TIPS := ["A unique among the handful is asked about on its own",
		"A unique among the handful is sold or thrown away with the rest",
		"A unique among the handful is left in the bag"]
const DETAILS_TIP := "Shows beside each modifier the lowest and highest it could have rolled at the item's level, like +14(8-20)% increased Damage."

## The debug build's item generator works on these; the main scene sets them, as it sets a town
## page's `view`. Without them there is no button for it.
var inventory: Inventory
var inventory_path := ""

var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
## The time played, redrawn every frame while the page is up so it does not sit still as it is read.
var _played: Label


func _init(ui_scale: float) -> void:
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Settings", "Close the settings", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	_rows = UITheme.vbox(ROW_GAP, WIDTH)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.body_of(_panel).add_child(_rows)
	open()


## Redraws the page from `Settings`, with Reset back to a button: a question left hanging is cancelled
## by closing the page, whichever way it was closed.
func open() -> void:
	UITheme.clear(_rows)
	_rows.add_child(_tick("Music", Settings.music, func(on: bool) -> void: Settings.music = on))
	_rows.add_child(_tick("Sound effects", Settings.sfx, func(on: bool) -> void: Settings.sfx = on))
	_rows.add_child(UITheme.rule(WIDTH))
	_rows.add_child(UITheme.label("Animations"))
	_rows.add_child(_choice(ANIM_NAMES, [], Settings.animations,
			func(level: int) -> void: Settings.animations = level as Settings.Anim))
	_rows.add_child(UITheme.rule(WIDTH))
	var details := _tick("Detailed item descriptions", Settings.item_details,
			func(on: bool) -> void: Settings.item_details = on)
	# On the box and the words both: either is what the cursor may be resting on.
	for part: Control in details.get_children():
		part.tooltip_text = DETAILS_TIP
	_rows.add_child(details)
	_rows.add_child(UITheme.rule(WIDTH))
	_rows.add_child(UITheme.label("Uniques in Sell all"))
	_rows.add_child(_choice(UNIQUES_NAMES, UNIQUES_TIPS, Settings.uniques,
			func(rule: int) -> void: Settings.uniques = rule as Settings.Uniques))
	_rows.add_child(UITheme.rule(WIDTH))
	_played = UITheme.label(_spent(), null, true)
	_rows.add_child(_played)
	_rows.add_child(_foot(false))
	# The generator may have left the panel wider than the settings are.
	layout.call_deferred()


func _process(_delta: float) -> void:
	if _played != null and is_instance_valid(_played) and visible:
		_played.text = _spent()


## How long this save has been played, as words. Hours once there are any, and seconds until then,
## so a fresh game's line moves while it is watched.
func _spent() -> String:
	var seconds := int(inventory.play_seconds) if inventory != null else 0
	if seconds >= 3600:
		return "Time played: %dh %dm" % [seconds / 3600, seconds % 3600 / 60]
	return "Time played: %dm %ds" % [seconds / 60, seconds % 60]


## A row of buttons one of which is `picked`, with the others faded (the town's tabs' way of saying
## which is open: the pack's held face is one pixel). `write` puts the pressed one into `Settings`;
## `tips`, where there are any, go on the buttons in order.
func _choice(names: Array, tips: Array, picked: int, write: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	for at in names.size():
		var pick := UITheme.button(names[at], "LightButton", tips[at] if at < tips.size() else "")
		if at != picked:
			pick.modulate = TownPage.TAB_REST
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void:
			write.call(at)
			Settings.save()
			open.call_deferred())
		row.add_child(pick)
	return row


## One tick-box row, the bag's own, already showing `on`. `write` puts a change into `Settings`.
func _tick(text: String, on: bool, write: Callable) -> HBoxContainer:
	var row := BagPage.check_box(text)
	var box: Button = row.get_node(BagPage.TICK_NAME)
	# Before the handler is connected, so drawing the page does not write the file.
	box.button_pressed = on
	box.toggled.connect(func(now: bool) -> void:
		write.call(now)
		Settings.apply_audio()
		Settings.save())
	return row


## The page's foot: Reset, or the question it asks once pressed. Asked in place rather than over the
## window: there is nothing else on the page to press by mistake.
func _foot(asking: bool) -> VBoxContainer:
	var foot := UITheme.vbox(ROW_GAP, WIDTH)
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	if not asking:
		if OS.is_debug_build():
			var uniques := _tick("Show all uniques", Settings.all_uniques, func(on: bool) -> void:
				Settings.all_uniques = on
				uniques_toggled.emit())
			for part: Control in uniques.get_children():
				part.tooltip_text = "Dev: the collection log draws every unique as found"
			foot.add_child(uniques)
			var chests := _tick("Show all chests", Settings.all_chests, func(on: bool) -> void:
				Settings.all_chests = on
				chests_toggled.emit())
			for part: Control in chests.get_children():
				part.tooltip_text = "Dev: every chest is drawn on the map, fog or not"
			foot.add_child(chests)
			var services := _tick("Show all services", Settings.all_services, func(on: bool) -> void:
				Settings.all_services = on
				TownServices.show_all = Settings.show_all_services())
			for part: Control in services.get_children():
				part.tooltip_text = "Dev: every settlement offers every counter, from the next time one is entered"
			foot.add_child(services)
			var cash := UITheme.button("Gold x10", "LightButton", "Dev: multiply the purse by ten")
			cash.pressed.connect(cash_pressed.emit)
			foot.add_child(cash)
			if inventory != null:
				var forge := UITheme.button("Item generator", "LightButton", "Dev: make a piece to order")
				forge.pressed.connect(_open_generator)
				foot.add_child(forge)
		var reset := UITheme.button("Reset save", "LightDangerButton", "Delete the saves and start a new game")
		reset.pressed.connect(_ask.bind(true))
		foot.add_child(reset)
		return foot
	foot.add_child(BountyList.wrapped("Delete everything and start over?", WIDTH, Palette.RUST))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 2)
	var cancel := UITheme.button("Cancel", "LightButton", "")
	cancel.pressed.connect(_ask.bind(false))
	var delete := UITheme.button("Delete", "LightDangerButton", "")
	delete.pressed.connect(reset_pressed.emit)
	for made: Button in [cancel, delete]:
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(made)
	foot.add_child(buttons)
	return foot


## The generator in the settings' place, wider than they are; its back arrow is `open()`.
func _open_generator() -> void:
	_played = null
	UITheme.clear(_rows)
	_rows.add_child(ItemGenerator.new(inventory, inventory_path, open))
	layout.call_deferred()


func _ask(asking: bool) -> void:
	var old := _rows.get_child(-1)
	_rows.remove_child(old)
	old.queue_free()
	_rows.add_child(_foot(asking))


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x,
			get_viewport_rect().size.y / _ui_scale - 2 * UITheme.EDGE)
	_panel.position = Vector2.ONE * UITheme.EDGE * _ui_scale
	laid_out.emit()
