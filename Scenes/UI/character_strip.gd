class_name CharacterStrip
extends Control
## The character panel's damage line alone, its two figures stacked, on the panel's own band cut loose
## from the circle: the frame's rows, the dark band run on by `DARK_ROWS` with its slant carried down to
## match, the left end off the window's edge. In the panel's corner of a window held upright while a
## page hides the panel -- over a town's bag too (the user's, 2026-10-30) -- so a piece put on or taken
## off still says what it did (`main_scene._place_character`). Ignores the mouse, as the panel does.

const PIXEL := CharacterPanel.PIXEL
## The frame's band, in its sprite pixels: its first column (where the circle's rim ends), the rows it
## keeps over the dark run (outline, lit row, the band's first dark rows -- dark from `BAND_FROM`), the
## dark row that is run on, and the rows it keeps under it (the trough's lit foot, shade, outline).
const LEFT := CharacterPanel.XP_AT.x
const TOP_ROWS := Vector2i(5, 10)
const BAND_FROM := 7
const RUN_ROW := 10
const FOOT_ROWS := Vector2i(21, 24)
## How many dark rows run on under the top ones, each a sprite pixel further in at the slant: two
## figures and their marks, at either text size. At least 11, the rows the frame's own run has.
const DARK_ROWS := 16
## The plain columns cut out of the band's middle, so it starts as narrow as its slant allows and widens
## to the figures; and the column that repeats to widen it, both counted from `LEFT`.
const CUT := 20
const PLAIN := CharacterPanel.STRETCH_AT - LEFT
## Where the figures start, in panel pixels; the air kept between them and the slant; between the rows.
const TEXT_X := 4
const AIR := 2
const ROW_GAP := 2
## How wide the slant's rim is at each row's end, in sprite pixels: lit, shade, outline.
const RIM := 3
const MARK_GAP := 3

## Built once from the frame: the band, and each row's last pixel inside the rim.
static var _band: ImageTexture
static var _inside: PackedInt32Array

var _plate: NinePatchRect
var _rows: VBoxContainer
var _click_label: Label
var _second_label: Label
var _per_click := 0.0
var _per_second := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()
	var band := _cut()
	_plate = NinePatchRect.new()
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_plate.texture = band
	_plate.patch_margin_left = PLAIN
	_plate.patch_margin_right = band.get_width() - PLAIN - 1
	_plate.scale = Vector2(PIXEL, PIXEL)
	_plate.size = band.get_size()
	add_child(_plate)
	_rows = VBoxContainer.new()
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rows.add_theme_constant_override("separation", ROW_GAP)
	add_child(_rows)
	_click_label = _pair(CharacterPanel.CLICK_MARK)
	_second_label = _pair(CharacterPanel.SWING_MARK)
	set_damage(0.0, 0.0)


## The figures can only be measured once the font is reachable -- in the tree, through the theme.
func _ready() -> void:
	_lay_out()


## `CharacterPanel.set_damage`'s figures, flashing and floating a change the same way with `announce`.
func set_damage(per_click: float, per_second: float, announce := false) -> void:
	if announce:
		_announce(_click_label, _per_click, per_click)
		_announce(_second_label, _per_second, per_second)
	_per_click = per_click
	_per_second = per_second
	_click_label.text = BigNumber.format(per_click)
	_second_label.text = BigNumber.format(per_second) + "/s"
	if is_inside_tree():
		_lay_out()


## The figures centred in the dark band, and the band widened until the slant clears them on the
## lowest row they reach, which is its nearest step to them.
func _lay_out() -> void:
	var lines := _rows.get_combined_minimum_size()
	var band_top := (BAND_FROM - TOP_ROWS.x) * PIXEL
	var band_height := (TOP_ROWS.y - BAND_FROM + DARK_ROWS) * PIXEL
	_rows.position = Vector2(TEXT_X, roundf(band_top + (band_height - lines.y) / 2.0))
	_rows.size = lines
	var lowest := clampi(ceili((_rows.position.y + lines.y) / PIXEL) - 1, 0, _inside.size() - 1)
	var room := (_inside[lowest] + 1) * PIXEL - AIR
	var stretch := maxi(0, ceili((_rows.position.x + lines.x - room) / PIXEL))
	_plate.size = Vector2(_band.get_width() + stretch, _band.get_height())
	size = _plate.size * PIXEL


## The band out of the frame, once: each row is the frame's from `LEFT` with `shift` plain columns
## taken out after `PLAIN`, so a row further down the slant is one more in.
static func _cut() -> ImageTexture:
	if _band != null:
		return _band
	var frame := CharacterPanel.FRAME.get_image()
	frame.convert(Image.FORMAT_RGBA8)
	var rows: Array[Vector2i] = []
	for y in range(TOP_ROWS.x, TOP_ROWS.y):
		rows.append(Vector2i(y, CUT))
	for k in DARK_ROWS:
		rows.append(Vector2i(RUN_ROW, CUT + k))
	# The frame's foot is FOOT_ROWS.x - RUN_ROW rows down its slant; here it is DARK_ROWS down.
	for y in range(FOOT_ROWS.x, FOOT_ROWS.y):
		rows.append(Vector2i(y, CUT + DARK_ROWS - (FOOT_ROWS.x - RUN_ROW)))
	var full := frame.get_width() - LEFT
	var image := Image.create_empty(full - CUT, rows.size(), false, Image.FORMAT_RGBA8)
	_inside.resize(rows.size())
	for at in rows.size():
		var y := rows[at].x
		var shift := rows[at].y
		image.blit_rect(frame, Rect2i(LEFT, y, PLAIN, 1), Vector2i(0, at))
		image.blit_rect(frame, Rect2i(LEFT + PLAIN + shift, y, full - PLAIN - shift, 1), Vector2i(PLAIN, at))
		var last := image.get_width() - 1
		while last > 0 and image.get_pixel(last, at).a == 0.0:
			last -= 1
		_inside[at] = last - RIM
	_band = ImageTexture.create_from_image(image)
	return _band


## As `CharacterPanel._announce`: green for more, red for less, fading back to bone, and "+n" rising
## or "-n" sinking past the slant on the figure's row but at `Anim.NONE` -- beside, since the strip
## stands at the top of the window, where a float off the figure's top would leave it.
func _announce(number: Label, was: float, now: float) -> void:
	if BigNumber.format(was) == BigNumber.format(now) or not is_inside_tree():
		return
	var by := roundf(now) - roundf(was)
	var colour := Palette.LEAF_LT if by > 0.0 else Palette.BRICK_LT
	if number.has_meta(CharacterPanel.FLASH_NAME):
		(number.get_meta(CharacterPanel.FLASH_NAME) as Tween).kill()
	number.add_theme_color_override("font_color", colour)
	var fade := number.create_tween()
	fade.tween_method(func(at: Color) -> void: number.add_theme_color_override("font_color", at),
			colour, Palette.BONE, CharacterPanel.GAIN_TIME).set_ease(Tween.EASE_IN)
	number.set_meta(CharacterPanel.FLASH_NAME, fade)
	if Settings.animations != Settings.Anim.NONE:
		_float.call_deferred(number, BigNumber.format(by, true), colour, by > 0.0)


## Once the band has laid the new figure out, so the float stands on its row.
func _float(number: Label, text: String, colour: Color, up: bool) -> void:
	if not is_instance_valid(number):
		return
	var at := get_global_transform().affine_inverse() * number.get_global_transform() \
			* Rect2(Vector2.ZERO, number.size)
	var label := UITheme.label(text, colour, true)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	var shown := label.get_minimum_size()
	var row := clampi(floori(at.get_center().y / PIXEL), 0, _inside.size() - 1)
	var past := (_inside[row] + RIM + 1 + _plate.size.x - _band.get_width()) * PIXEL + MARK_GAP
	label.position = Vector2(past, at.get_center().y - shown.y / 2.0).round()
	var rise := -CharacterPanel.GAIN_RISE if up else CharacterPanel.GAIN_RISE
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + rise, CharacterPanel.GAIN_TIME) \
			.set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, CharacterPanel.GAIN_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## A mark and its figure, a row of the strip; returns the figure's Label.
func _pair(mark: Texture2D) -> Label:
	var pair := HBoxContainer.new()
	pair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pair.add_theme_constant_override("separation", MARK_GAP)
	_rows.add_child(pair)
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = mark
	# The marks differ in width: both in the wider one's column, so the figures line up.
	rect.custom_minimum_size.x = maxi(CharacterPanel.CLICK_MARK.get_width(), CharacterPanel.SWING_MARK.get_width())
	rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pair.add_child(rect)
	var label := UITheme.label("", Palette.BONE, true)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pair.add_child(label)
	return label
