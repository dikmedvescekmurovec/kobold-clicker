class_name TipCard
extends PanelContainer
## Every `tooltip_text` in the game, written on the cards' own cream panel instead of in Godot's
## tooltip -- which is its own window, cannot inherit `ui_scale`, and so never matched the cards beside
## it (`OrbCard` has the long version). Godot's own is put out of reach by `gui/timers/tooltip_delay_sec`
## in `project.godot`; the text stays on the Control, where the tests find buttons by it.
##
## One card for the whole game, as `ItemCard` is, built by the main scene on the character's layer.
## Unlike the item card it waits: a button's name is wanted by a cursor that has stopped on it, not by
## one passing over a row of them.

## How long the cursor has to stay over one Control before its card comes up, in seconds.
const DELAY := 0.5
## A meta on a Control whose tooltip is the whole of what it is for -- an info mark -- and so does
## not wait: `set_meta(TipCard.NOW, true)`.
const NOW := "tip_now"
## A meta naming the key that presses this Control -- a corner button's hotkey, `set_meta(TipCard.KEY,
## "k")` -- whose picture, cut from the keyboard pack by `tools/ui_kit.py`, the card shows after its words.
const KEY := "tip_key"
const KEY_PICTURE := "res://Assets/UI/ui_key_%s.png"

var _ui_scale: float
var _line: Label
var _key: TextureRect
var _over: Control
var _text := ""
var _held := 0.0


func _init(ui_scale: float) -> void:
	_ui_scale = ui_scale
	theme = UITheme.theme()
	theme_type_variation = "TextPanel"
	scale = Vector2(ui_scale, ui_scale)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_line = UITheme.label("", Palette.TEXT, true)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_line)
	_key = TextureRect.new()
	_key.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.hide()
	row.add_child(_key)
	hide()


func _process(delta: float) -> void:
	var over := get_viewport().gui_get_hovered_control()
	var text := text_of(over, get_viewport().get_mouse_position())
	if text.is_empty() or not _asking(over):
		_over = null
		hide()
		return
	if over != _over or text != _text:
		_over = over
		_text = text
		_held = 0.0
		hide()
	_held += delta
	if visible or (_held < DELAY and not over.has_meta(NOW)):
		return
	# As wide as its words up to the cards' width, and wrapped from there.
	_line.autowrap_mode = TextServer.AUTOWRAP_OFF
	_line.custom_minimum_size.x = 0
	_line.text = text
	if _line.get_minimum_size().x > ItemCard.WIDTH:
		_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_line.custom_minimum_size.x = ItemCard.WIDTH
	var key := str(over.get_meta(KEY, ""))
	_key.visible = not key.is_empty() and not Cursors.touched
	_key.texture = load(KEY_PICTURE % key) if _key.visible else null
	show()
	# A finger held on a button to read it has not pressed it: a button disabled and enabled again
	# forgets the press it was part way through, so letting go does nothing.
	var button := over as BaseButton
	if Cursors.touched and button != null and not button.disabled:
		button.disabled = true
		button.disabled = false
	# Placed now and again deferred: the first pass measures a label that has not laid out yet.
	_place()
	_place.call_deferred()


## Whether the card should be up over `over`. With a mouse, while no press is down: a press is the
## answer to whatever the card would have said, and what it changes is not what was read. A finger has
## no hover, so it asks by being held on the control -- or at once, over an info mark (`NOW`).
func _asking(over: Control) -> bool:
	var down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if Cursors.touched:
		return down or over.has_meta(NOW)
	return not down


## What Godot would have said over `control`: its own tooltip, or the nearest ancestor's the mouse
## gets through to.
static func text_of(control: Control, at: Vector2) -> String:
	while control != null:
		var text := control.get_tooltip(control.get_global_transform_with_canvas().affine_inverse() * at)
		if not text.is_empty() or control.mouse_filter == Control.MOUSE_FILTER_STOP or control.top_level:
			return text
		control = control.get_parent() as Control
	return ""


func _place() -> void:
	if not visible or not is_instance_valid(_over):
		return
	reset_size()
	position = ItemCard.beside(_over.get_global_rect(), get_combined_minimum_size() * _ui_scale,
			get_viewport_rect().size, ItemCard.GAP * _ui_scale)
