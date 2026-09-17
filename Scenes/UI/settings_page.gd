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

const WIDTH := 140.0
const ROW_GAP := 6
const ANIM_NAMES := ["None", "Low", "Default"]
const DETAILS_TIP := "Shows beside each modifier the lowest and highest it could have rolled at the item's level, like +14(8-20)% increased Damage."

var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer


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
	var levels := HBoxContainer.new()
	levels.add_theme_constant_override("separation", 2)
	for level in ANIM_NAMES.size():
		var pick := UITheme.button(ANIM_NAMES[level], "LightButton", "")
		# The town's tabs' way of saying which is open: the pack's held face is one pixel, so the ones
		# not picked fade instead.
		if level != Settings.animations:
			pick.modulate = TownPage.TAB_REST
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void:
			Settings.animations = level as Settings.Anim
			Settings.save()
			open.call_deferred())
		levels.add_child(pick)
	_rows.add_child(levels)
	_rows.add_child(UITheme.rule(WIDTH))
	var details := _tick("Detailed item descriptions", Settings.item_details,
			func(on: bool) -> void: Settings.item_details = on)
	# On the box and the words both: either is what the cursor may be resting on.
	for part: Control in details.get_children():
		part.tooltip_text = DETAILS_TIP
	_rows.add_child(details)
	_rows.add_child(_foot(false))


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


func _ask(asking: bool) -> void:
	var old := _rows.get_child(-1)
	_rows.remove_child(old)
	old.queue_free()
	_rows.add_child(_foot(asking))


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x, get_viewport_rect().size.y / _ui_scale)
	_panel.position = Vector2.ZERO
