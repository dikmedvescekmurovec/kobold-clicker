class_name Accordion
extends VBoxContainer
## A section that folds: its heading in slate with a caret at the far end, and `body` under it, which
## a press anywhere on the heading shows or hides. The caret points right while shut and down while
## open. Fill `body`, never the accordion itself.
##
## Which sections are shut is kept by `id` for the session (`_shut`, not saved), so a page that is
## built again at every redraw -- the character page -- keeps what was folded.

## The caret: a solid triangle in the brown buttons' face, drawn here pixel by pixel -- `CARET_LONG`
## down its long side and half that (rounded up) out to its point.
const CARET_LONG := 9
const CARET_COLOR := Palette.BUTTON_BROWN

## Pointing right while shut and down while open, made once. Two images and not one turned: a
## container sets its children's `rotation` back to 0 whenever it lays them out.
static var _caret_shut: ImageTexture
static var _caret_open: ImageTexture

static var _shut := {}

var body: VBoxContainer
var _id: String
var _caret: TextureRect


## `separation` is the gap between the heading and the body and between the body's own rows.
func _init(title: String, id: String, separation := 2) -> void:
	_id = id
	add_theme_constant_override("separation", separation)
	var heading := HBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_STOP
	Cursors.wear(heading, Cursors.HAND)
	heading.gui_input.connect(_on_heading_input)
	var label := UITheme.label(title, Palette.TEXT_SOFT)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	_caret = TextureRect.new()
	_caret.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_caret)
	add_child(heading)
	body = UITheme.vbox(separation)
	add_child(body)
	_show(not _shut.has(id))


func is_open() -> bool:
	return body.visible


## Folds it or opens it, as a press on the heading does.
func toggle() -> void:
	_show(not body.visible)


## Has the section `id` start folded the next time it is built, as a press on its heading would leave it.
static func fold(id: String) -> void:
	_shut[id] = true


func _show(open: bool) -> void:
	body.visible = open
	if _caret_open == null:
		_caret_shut = _triangle(false)
		_caret_open = _triangle(true)
	_caret.texture = _caret_open if open else _caret_shut
	if open:
		_shut.erase(_id)
	else:
		_shut[_id] = true


## Column `i` of a right-pointing triangle runs from row `i` to row `CARET_LONG - 1 - i`; `down`
## swaps x and y.
static func _triangle(down: bool) -> ImageTexture:
	var deep := (CARET_LONG + 1) / 2
	var size := Vector2i(CARET_LONG, deep) if down else Vector2i(deep, CARET_LONG)
	var image := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGBA8)
	for i in deep:
		for j in range(i, CARET_LONG - i):
			image.set_pixel(j if down else i, i if down else j, CARET_COLOR)
	return ImageTexture.create_from_image(image)


func _on_heading_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		toggle()
		accept_event()
