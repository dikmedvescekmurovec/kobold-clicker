class_name DialogueBox
extends Control
## Someone in the world speaking: their name and words on the left, their portrait in a tan socket on
## the right behind a rule (the user's sketch, 2026-09-26) -- the hero the other way round, his portrait
## on the left (the user's rule, the same day) -- one page at a time along the window's foot,
## over a shade across the whole window that takes every click. The words come in quickly a letter at
## a time; a click anywhere finishes the page, the next turns it, and past the last it says `finished`.
## Escape is the main scene's, which lets it go whole. The main scene raises one for a tip that names a
## speaker (`TIPS`).

signal finished

## A speaker's portrait: a strip of square frames, their idle, cut by `tools/npc_portraits.py`.
const PORTRAITS := "res://Assets/NPC/%s.png"
## The hero's portrait's name under `PORTRAITS`: the one speaker whose portrait stands on the left.
const PLAYER := "player"
## How wide the words wrap, in panel pixels.
const TEXT_WIDTH := 220
## How fast the words come in, in letters a second.
const LETTERS_PER_SECOND := 60.0
## Seconds a portrait frame is held.
const FRAME_TIME := 0.15
## Air round the face inside its socket: the shoulders run down to its foot, the hat has room above.
const SOCKET_PAD := Vector4i(6, 11, 6, 1)  # left, top, right, bottom
## How far off the window's foot the box stands, in panel pixels.
const FOOT_GAP := 8
## The shade over everything behind the box.
const SHADE := Color(Palette.INK, 0.5)

var _pages: Array
var _page := 0
var _shade: ColorRect
var _panel: PanelContainer
var _words: Label
var _more: Label
var _typing: Tween
var _face: AtlasTexture
var _frames := 1
var _clock := 0.0
var _ui_scale := 1.0


func _init(speaker: String, pages: Array, portrait: Texture2D, left := false) -> void:
	_pages = pages
	theme = UITheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)

	_panel = PanelContainer.new()
	_panel.theme_type_variation = "TextPanel"
	UITheme.notched(_panel)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_panel.add_child(row)

	var column := UITheme.vbox(4, TEXT_WIDTH)
	row.add_child(column)
	column.add_child(UITheme.label(speaker))
	_words = UITheme.label("", null, true)
	_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label has no width of its own, and wrapped at none it stands a letter a line.
	_words.custom_minimum_size.x = TEXT_WIDTH
	_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_words)
	# The page is all there and there is more: a mark in the corner, blinking, the way a letter ends "over".
	_more = UITheme.label(">", Palette.TEXT_SOFT, true)
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_more)

	var rule := ColorRect.new()
	rule.color = Palette.SLOT_TAN_DK
	rule.custom_minimum_size.x = UITheme.RULE_HEIGHT
	row.add_child(rule)

	var socket := PanelContainer.new()
	var style := BountyList.flat(Palette.SLOT_TAN, 0)
	style.content_margin_left = SOCKET_PAD.x
	style.content_margin_top = SOCKET_PAD.y
	style.content_margin_right = SOCKET_PAD.z
	style.content_margin_bottom = SOCKET_PAD.w
	socket.add_theme_stylebox_override("panel", style)
	socket.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(socket)
	var side := portrait.get_height()
	_frames = maxi(1, portrait.get_width() / side)
	_face = AtlasTexture.new()
	_face.atlas = portrait
	_face.region = Rect2(0, 0, side, side)
	var face := TextureRect.new()
	face.texture = _face
	face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	socket.add_child(face)
	if left:
		row.move_child(socket, 0)
		row.move_child(rule, 1)
	# Every click is the shade's, wherever it lands, the box included.
	for child: Node in find_children("*", "Control", true, false):
		(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## The shade fades in and the box swells in at the window's foot, `final` being the interface's scale.
func pop_up(final: float) -> void:
	_ui_scale = final
	_panel.resized.connect(_settle)
	Juice.pop_in(_panel, final)
	_settle()
	if Settings.animations != Settings.Anim.NONE:
		_shade.modulate.a = 0.0
		create_tween().tween_property(_shade, "modulate:a", 1.0, Juice.POP_TIME)
		var blink := _more.create_tween().set_loops()
		blink.tween_property(_more, "modulate:a", 0.25, 0.4)
		blink.tween_property(_more, "modulate:a", 1.0, 0.4)
	_show_page()


## The box shrinks away and the shade fades with it, then all of it goes.
func leave() -> void:
	if Settings.animations != Settings.Anim.NONE:
		create_tween().tween_property(_shade, "modulate:a", 0.0, Juice.LEAVE_TIME)
	Juice.pop_out(_panel, queue_free)


## A click: the page still coming in is finished, a finished one turned, and past the last, `finished`.
func advance() -> void:
	if typing():
		_typing.kill()
		_typed()
	elif _page + 1 < _pages.size():
		_page += 1
		_show_page()
	else:
		finished.emit()


## Whether the page is still coming in.
func typing() -> bool:
	return _typing != null and _typing.is_running()


## Centred across and standing `FOOT_GAP` off the foot, scaled about its own middle as `Juice` pops it.
func _settle() -> void:
	var own := _panel.get_combined_minimum_size()
	var view := get_viewport_rect().size
	_panel.pivot_offset = own / 2.0
	_panel.position = Vector2((view.x - own.x) / 2.0,
			view.y - FOOT_GAP * _ui_scale - own.y * (1.0 + _ui_scale) / 2.0).round()


## The page's words, a letter at a time. The label is laid out whole from the start (only the letters
## drawn change), so the box does not grow line by line.
func _show_page() -> void:
	_words.text = str(_pages[_page])
	var letters := _words.text.length()
	if Settings.animations == Settings.Anim.NONE or letters == 0:
		_typed()
		return
	_more.self_modulate.a = 0.0
	_words.visible_characters = 0
	_typing = create_tween()
	_typing.tween_property(_words, "visible_characters", letters, letters / LETTERS_PER_SECOND)
	_typing.finished.connect(_typed)


func _typed() -> void:
	_words.visible_characters = -1
	_more.self_modulate.a = 1.0


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()


func _process(delta: float) -> void:
	if _frames < 2 or Settings.animations == Settings.Anim.NONE:
		return
	_clock += delta
	var frame := int(_clock / FRAME_TIME) % _frames
	_face.region.position.x = frame * _face.region.size.x
