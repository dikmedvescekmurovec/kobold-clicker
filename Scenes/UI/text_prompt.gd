class_name TextPrompt
extends Control
## A line of text asked for over the whole window (the character's name), built as the cloud's question
## is (`CloudQuestion`): a full-window holder under a titled panel with no X, popped in by `Juice`. The
## field (`UITheme.text_field`) opens holding `text`, all of it selected, ready to type over. The verb
## -- greyed while the field is blank -- and Enter hand back what was typed (`entered`); Cancel and
## Escape hand back nothing. Either way it shrinks away and frees itself.

## What was typed, untrimmed: the caller decides what it will take.
signal entered(text: String)

var _title: String
var _text: String
var _verb: String
var _most: int
var _ui_scale: float
var _panel: VBoxContainer
var _field: LineEdit
var _go: Button


func _init(title: String, text: String, verb: String, most: int, ui_scale: float) -> void:
	_title = title
	_text = text
	_verb = verb
	_most = most
	_ui_scale = ui_scale
	theme = UITheme.theme()


func _ready() -> void:
	# On a CanvasLayer the anchors are the window's, so the holder follows it as it resizes.
	set_anchors_preset(PRESET_FULL_RECT)
	_panel = UITheme.titled_panel(_title, "", Callable())
	add_child(_panel)
	var body := UITheme.body_of(_panel)
	_field = UITheme.text_field("", _most, BagPage.CONFIRM_WIDTH)
	_field.text = _text
	body.add_child(_field)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", BagPage.SLOT_GAP)
	_go = UITheme.button(_verb, UITheme.GO_BUTTON, "")
	for made: Button in [UITheme.button("Cancel", "LightButton", ""), _go]:
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(made)
	body.add_child(buttons)
	(buttons.get_child(0) as Button).pressed.connect(_leave)
	_go.pressed.connect(_submit)
	_field.text_submitted.connect(func(_typed: String) -> void: _submit())
	_field.text_changed.connect(func(now: String) -> void: _go.disabled = now.strip_edges().is_empty())
	_go.disabled = _text.strip_edges().is_empty()
	resized.connect(func() -> void: Juice.centre(_panel, size))
	Juice.popup(self, _panel, _ui_scale)
	_field.edit()
	_field.select_all()


func _submit() -> void:
	if _go.disabled or _panel.has_meta("leaving"):
		return
	entered.emit(_field.text)
	_leave()


func _leave() -> void:
	Juice.pop_out(_panel, queue_free)


## Escape is Cancel, taken before the field sees it (a field being typed in would only stop typing).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave()


## Every other key the field did not take stops here, so a corner's hotkey never opens a page under it.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
