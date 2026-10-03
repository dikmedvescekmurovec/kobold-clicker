class_name CharacterPanel
extends Control
## The player in the top-left corner: the pack's character frame with the kobold in its circle, the
## name and level in the dark band beside it, and the experience bar under them.
##
## The pack's frame has health and mana troughs; the player has neither, so `tools/ui_kit.py` paints
## them into the one band the name line stands in, in the small font. The frame widens to fit a line
## longer than "Adventurer Lvl 230" by repeating one plain column of the band, and the bar under it by
## repeating one of its own, so a longer name buys a longer bar. A name past NAME_ROOM is cut short
## with an ellipsis.
##
## Parts are cut loose by `tools/ui_kit.py` and drawn at PIXEL, two panel pixels a sprite pixel -- the
## scale the fight's kill pips had until 2026-10-03. The bar empties by being **clipped**, never stretched,
## and the clip is snapped to whole sprite pixels -- the frame's empty trough shows through what is
## left. Everything ignores the mouse: this stands over the map and over a fight, and a Control that
## took a press would eat a tile click or a swing.

const PIXEL := 2
const FRAME := preload("res://Assets/UI/ui_char_frame.png")
const PORTRAIT := preload("res://Assets/UI/ui_char_portrait.png")
const XP_BAR := preload("res://Assets/UI/ui_char_bar_xp.png")
## Where the portrait's top-left sits in the frame, in sprite pixels. Printed by ui_kit.py.
const PORTRAIT_AT := Vector2i(4, 4)
## Where the experience bar lies in the frame, in sprite pixels -- ui_kit.CHAR_BARS, which measured it.
const XP_AT := Vector2i(29, 18)
## The frame's column that is repeated to widen it, in sprite pixels: inside the band, clear of the
## circle and of the slant. The bar repeats its own column at the same x.
const STRETCH_AT := 40
## Where the name line's top-left sits, in panel pixels: the band's left edge (sprite x 29) and a
## little air, and the height that centres Ark Pixel's capitals in the band (sprite rows 7 to 15).
const TEXT_AT := Vector2(61, 17)
## How wide a line the band holds at the frame's own width, in panel pixels: from TEXT_AT to the
## slant's nearest step beside a descender (sprite x 77), less the same air.
const TEXT_ROOM := 90
## How wide a name is let run, in panel pixels, before it is cut short: with "Lvl 9999" beside it the
## frame then keeps clear of a fight's centred pips and clock (never more than ten pips, 90 px) on the
## narrowest window not held upright, 576 panel pixels.
const NAME_ROOM := 88
## Space between the name and the level: one of the small font's spaces.
const NAME_GAP := 5
## What the experience bar brightens to as gems land in it, and how long that takes to fade.
const FLASH := Color(1.8, 1.8, 1.8)
const FLASH_TIME := 0.25
## The "+n" that rises off the bar's filled end as gems land in it: how far, in panel pixels, and how long.
const GAIN_RISE := 8.0
const GAIN_TIME := 0.9

var level := 1
var xp := 0
## Over the experience bar, carrying its "held / needed" tooltip. The panel takes no mouse, so the
## owner parents this under whatever does (the main scene's `_character_button`, which is out of a
## fight's way); `_lay_out` keeps its rect, in the owner's pixels, and its text.
var xp_hover := Control.new()

var _plate: NinePatchRect
var _line: HBoxContainer
var _name_label: Label
var _level_label: Label
var _bar: NinePatchRect
var _fill: Control
var _flash: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()
	_plate = _patch(FRAME, STRETCH_AT)
	add_child(_plate)
	var portrait := _texture(PORTRAIT)
	portrait.position = Vector2(PORTRAIT_AT * PIXEL)
	add_child(portrait)

	_fill = Control.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.clip_contents = true
	_fill.position = Vector2(XP_AT * PIXEL)
	_bar = _patch(XP_BAR, STRETCH_AT - XP_AT.x)
	_fill.add_child(_bar)
	add_child(_fill)

	# Two labels rather than one line, the way the fight's place and level are: a name in bone and a
	# number in gold. The band is dark, so neither needs the outline they carried over the map. The
	# small font, because Pixellari's line ran the frame half as long again.
	_line = HBoxContainer.new()
	_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line.position = TEXT_AT
	_line.add_theme_constant_override("separation", NAME_GAP)
	add_child(_line)
	_name_label = UITheme.label(Inventory.DEFAULT_NAME, Palette.BONE, true)
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_line.add_child(_name_label)
	_level_label = UITheme.label("", Palette.GOLD, true)
	_line.add_child(_level_label)
	set_state(1, 0)


## The line can only be measured once the font is reachable -- in the tree, through the theme.
func _ready() -> void:
	_lay_out()


## The hover is the owner's to parent; one never parented (a test's panel) goes with the panel.
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and xp_hover.get_parent() == null:
		xp_hover.free()


## Shows the player at `level` holding `new_xp` towards the next one.
func set_state(new_level: int, new_xp: int) -> void:
	level = maxi(new_level, 1)
	xp = maxi(new_xp, 0)
	_level_label.text = "Lvl %d" % level
	if is_inside_tree():
		_lay_out()


func set_player_name(new_name: String) -> void:
	_name_label.text = new_name
	if is_inside_tree():
		_lay_out()

## Adds `amount` to what is shown, levelling up as it pays for, and flashes the bar. The panel keeps
## its own count so the bar can fill as gems arrive while the ledger was settled when they set off;
## the owner puts it back in step with `set_state` when a fight ends. Returns levels gained.
func absorb(amount: int) -> int:
	var after := PlayerLevel.add(level, xp, amount)
	set_state(after["level"], after["xp"])
	if _flash != null:
		_flash.kill()
	_fill.modulate = FLASH
	_flash = create_tween()
	_flash.tween_property(_fill, "modulate", Color.WHITE, FLASH_TIME)
	_float_gain(amount)
	return after["gained"]


## "+n" in green, centred on the bar's filled end, rising and fading. None at `Anim.NONE`, as a fight's
## damage numbers.
func _float_gain(amount: int) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	var label := UITheme.label("+" + BigNumber.format(float(amount)), Palette.LEAF_LT, true)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", 4)
	add_child(label)
	var shown := label.get_minimum_size()
	label.position = (_fill.position + Vector2(_fill.size.x - shown.x / 2.0, -shown.y)).round()
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - GAIN_RISE, GAIN_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, GAIN_TIME).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


## Where on the screen the experience bar's filled end is, which is where a gem flies to.
func xp_point() -> Vector2:
	return get_global_transform() * (_fill.position + Vector2(_fill.size.x, _fill.size.y / 2.0))


## How many sprite pixels of the experience bar are showing. Snapped to whole pixels, and never nothing
## while there is anything at all, so the first point of experience is a pixel the player can see.
func shown_pixels() -> int:
	return roundi(_fill.size.x / PIXEL)


## Widens the frame and the bar to the name line, then fills the bar to the experience held.
func _lay_out() -> void:
	var font := _name_label.get_theme_font("font")
	var name_width := font.get_string_size(_name_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_name_label.get_theme_font_size("font_size")).x
	_name_label.custom_minimum_size.x = minf(name_width, NAME_ROOM)
	var stretch := maxi(0, ceili((_line.get_combined_minimum_size().x - TEXT_ROOM) / PIXEL))
	_plate.size = Vector2(FRAME.get_width() + stretch, FRAME.get_height())
	_bar.size = Vector2(XP_BAR.get_width() + stretch, XP_BAR.get_height())
	custom_minimum_size = _plate.size * PIXEL
	size = custom_minimum_size
	var pixels := roundi(clampf(float(xp) / PlayerLevel.xp_to_next(level), 0.0, 1.0) * _bar.size.x)
	if xp > 0:
		pixels = maxi(pixels, 1)
	_fill.size = Vector2(pixels, _bar.size.y) * PIXEL
	xp_hover.position = Vector2(XP_AT * PIXEL) * scale
	xp_hover.size = _bar.size * PIXEL * scale
	xp_hover.tooltip_text = "%s / %s XP" % [BigNumber.format(float(xp)),
			BigNumber.format(float(PlayerLevel.xp_to_next(level)))]


## A sprite drawn at PIXEL that widens by repeating its column `at` -- a plain one, so the repeat
## draws exactly what was there.
func _patch(texture: Texture2D, at: int) -> NinePatchRect:
	var patch := NinePatchRect.new()
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	patch.texture = texture
	patch.patch_margin_left = at
	patch.patch_margin_right = texture.get_width() - at - 1
	patch.scale = Vector2(PIXEL, PIXEL)
	patch.size = texture.get_size()
	return patch


func _texture(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Before the texture and the size: a TextureRect's minimum is its texture until this says otherwise.
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.texture = texture
	rect.size = texture.get_size() * PIXEL
	return rect
