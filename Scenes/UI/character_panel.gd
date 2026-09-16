class_name CharacterPanel
extends Control
## The player in the top-left corner: a name and a level over the pack's character frame, the kobold
## in its circle, and three bars -- health, mana and experience.
##
## Only experience moves. The player has no health pool and no mana yet, so those two stand full; they
## are drawn because the frame has troughs for them and an empty trough reads as an empty bar.
##
## Parts are cut loose by `tools/ui_kit.py` and drawn at PIXEL, the pips' scale, so a sprite pixel here
## is the same size as one on the fight's HUD. A bar empties by being **clipped**, never stretched,
## and the clip is snapped to whole sprite pixels -- the frame's empty trough shows through what is
## left. Everything ignores the mouse: this stands over the map and over a fight, and a Control that
## took a press would eat a tile click or a swing.

## A placeholder until the player can name their character.
const PLAYER_NAME := "Adventurer"
const PIXEL := 2
const ROOT := "res://Assets/UI/"
const FRAME := preload("res://Assets/UI/ui_char_frame.png")
const PORTRAIT := preload("res://Assets/UI/ui_char_portrait.png")
## Where the portrait's top-left sits in the frame, in sprite pixels. Printed by ui_kit.py.
const PORTRAIT_AT := Vector2i(4, 4)
## Where each bar lies in the frame, in sprite pixels -- the same table as ui_kit.CHAR_BARS, which
## measured it. The textures' own widths are the full bars.
const BARS := {"hp": Vector2i(28, 8), "mana": Vector2i(30, 13), "xp": Vector2i(29, 18)}
## Space between the name line and the frame.
const HEADER_GAP := 2
## What the experience bar brightens to as gems land in it, and how long that takes to fade.
const FLASH := Color(1.8, 1.8, 1.8)
const FLASH_TIME := 0.25
const LABEL_OUTLINE := 4

var level := 1
var xp := 0

var _header: HBoxContainer
var _level_label: Label
var _frame: TextureRect
var _fills := {}
var _flash: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()
	var header := HBoxContainer.new()
	_header = header
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 8)
	add_child(header)
	# Two labels rather than one line, the way the fight's place and level are: a name in bone and a
	# number in gold, each with its dark outline so they read on whatever terrain is behind them.
	header.add_child(_label(PLAYER_NAME, Palette.BONE))
	_level_label = _label("", Palette.GOLD)
	header.add_child(_level_label)

	_frame = _texture(FRAME)
	add_child(_frame)
	var portrait := _texture(PORTRAIT)
	portrait.position = Vector2(PORTRAIT_AT * PIXEL)
	_frame.add_child(portrait)
	for bar: String in BARS:
		var texture: Texture2D = load(ROOT + "ui_char_bar_%s.png" % bar)
		var clip := Control.new()
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.position = Vector2(BARS[bar] * PIXEL)
		clip.size = Vector2(texture.get_size() * PIXEL)
		clip.add_child(_texture(texture))
		_frame.add_child(clip)
		_fills[bar] = clip
	set_state(1, 0)


## The frame hangs under the name line, which can only be measured once the font is reachable -- in
## the tree, through the theme.
func _ready() -> void:
	_frame.position = Vector2(0, _header.get_combined_minimum_size().y + HEADER_GAP)
	custom_minimum_size = Vector2(maxf(_frame.size.x, _header.get_combined_minimum_size().x),
			_frame.position.y + _frame.size.y)
	size = custom_minimum_size


## Shows the player at `level` holding `new_xp` towards the next one.
func set_state(new_level: int, new_xp: int) -> void:
	level = maxi(new_level, 1)
	xp = maxi(new_xp, 0)
	_level_label.text = "Level %d" % level
	_set_share("xp", float(xp) / PlayerLevel.xp_to_next(level))


## Adds `amount` to what is shown, levelling up as it pays for, and flashes the bar. The panel keeps
## its own count so the bar can fill as gems arrive while the ledger was settled when they set off;
## the owner puts it back in step with `set_state` when a fight ends. Returns levels gained.
func absorb(amount: int) -> int:
	var after := PlayerLevel.add(level, xp, amount)
	set_state(after["level"], after["xp"])
	if _flash != null:
		_flash.kill()
	var fill: Control = _fills["xp"]
	fill.modulate = FLASH
	_flash = create_tween()
	_flash.tween_property(fill, "modulate", Color.WHITE, FLASH_TIME)
	return after["gained"]


## Where on the screen the experience bar's filled end is, which is where a gem flies to.
func xp_point() -> Vector2:
	var fill: Control = _fills["xp"]
	return get_global_transform() * (_frame.position + fill.position
			+ Vector2(fill.size.x, fill.size.y / 2.0))


## How many sprite pixels of a bar are showing. Snapped to whole pixels, and never nothing while there
## is anything at all, so the first point of experience is a pixel the player can see.
func shown_pixels(bar: String) -> int:
	return roundi(_fills[bar].size.x / PIXEL)


func _set_share(bar: String, share: float) -> void:
	var clip: Control = _fills[bar]
	var full: float = (clip.get_child(0) as Control).size.x / PIXEL
	var pixels := roundi(clamp(share, 0.0, 1.0) * full)
	if share > 0.0:
		pixels = maxi(pixels, 1)
	clip.size = Vector2(pixels * PIXEL, clip.size.y)


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


func _label(text: String, colour: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = "PanelLabel"
	label.text = text
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	return label
