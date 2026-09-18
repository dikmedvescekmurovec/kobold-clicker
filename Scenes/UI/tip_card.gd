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

var _ui_scale: float
var _line: Label
var _over: Control
var _text := ""
var _held := 0.0


func _init(ui_scale: float) -> void:
	_ui_scale = ui_scale
	theme = UITheme.theme()
	theme_type_variation = "TextPanel"
	scale = Vector2(ui_scale, ui_scale)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line = UITheme.label("", Palette.INK, true)
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_line)
	hide()


func _process(delta: float) -> void:
	var over := get_viewport().gui_get_hovered_control()
	var text := text_of(over, get_viewport().get_mouse_position())
	# A press is the answer to whatever the card would have said, and what it changes is not what was read.
	if text.is_empty() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
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
	show()
	# Placed now and again deferred: the first pass measures a label that has not laid out yet.
	_place()
	_place.call_deferred()


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
