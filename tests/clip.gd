extends "res://tests/harness.gd"
## The base of the upright marketing clips (`*_video.gd`) that `tools/clip_video.py` records with Movie
## Maker: the real main scene on a scratch save, a cursor drawn into the picture, captions centred in what
## the clip shows, and the frame numbers the encoder cuts at. Needs a window and the mouse and keyboard
## left alone: the game reads where the system's cursor is, so the clip moves it.

const GLIDE := 0.3
## What a clip shows of the 360x640 window, in game pixels: 9:16, blown up 4x to 1080x1920.
const FRAME := Vector2(270, 480)
## A close-up to end on: 9:16, blown up 6x.
const CLOSEUP := Vector2(180, 320)

var main: Node
var _pointer := Vector2.ZERO
var _cursor := Sprite2D.new()
var _caption := Label.new()
var _sub := Label.new()
## What the clip shows of the window (`_show`, then `_close_up`): the captions are centred in it.
var _frame := Rect2()
## How far down the window the captions' middle stands, where the frame's own middle would cover the
## action; 0 for the frame's middle.
var _caption_middle := 0.0


## The main scene on a fresh scratch save of the clip's own `name`, every tip read so none stands over
## the shot, two walls down in some world so every orb exists. Its inventory.
func _open_main(name: String) -> Inventory:
	var save := "user://%s_video_inventory.json" % name
	var map := "user://%s_video_map.json" % name
	for scratch in [save, map]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	Settings.animations = Settings.Anim.DEFAULT
	main = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = save
	main.map_path = map
	root.add_child(main)
	await process_frame
	var inventory: Inventory = main.inventory
	for tip: Array in main.TIPS:
		inventory.tips.append(str(tip[0]))
	inventory.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP * 2
	_overlay()
	DisplayServer.window_move_to_foreground()
	return inventory


## What the clip shows from here on: the encoder crops to it.
func _show(frame: Rect2) -> void:
	_frame = frame
	print("FRAME %d %d %d %d" % [frame.position.x, frame.position.y, frame.size.x, frame.size.y])


## Everything before this is the scene settling, and the encoder cuts it.
func _start() -> void:
	print("CLIP_START ", Engine.get_frames_drawn())


## From this frame on the encoder shows `view` instead (any 9:16, blown up to the same 1080x1920: a
## `CLOSEUP` 6x), once a clip; the captions move into it, at the size a close-up's narrower frame has
## room for unless `small` is false.
func _close_up(view: Rect2, small := true) -> void:
	print("CLOSEUP %d %d %d %d %d" % [Engine.get_frames_drawn(), view.position.x, view.position.y,
			view.size.x, view.size.y])
	_frame = view
	_caption_middle = 0.0
	if not small:
		return
	_caption.add_theme_font_size_override("font_size", UITheme.FONT_SIZE)
	_caption.add_theme_constant_override("outline_size", 6)
	_caption.add_theme_constant_override("shadow_outline_size", 6)


func _end() -> void:
	print("CLIP_END ", Engine.get_frames_drawn())
	main.queue_free()
	await process_frame
	quit()


## The cursor drawn into the picture (Movie Maker records none of the system's) and the captions, above
## everything the game draws.
func _overlay() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	root.add_child(layer)
	for label: Label in [_caption, _sub]:
		label.add_theme_font_override("font", load(UITheme.FONT))
		label.add_theme_color_override("font_color", Palette.PANEL_CREAM)
		label.add_theme_color_override("font_outline_color", Color("131313"))
		# A hard drop shadow under the outline, so the words stand off whatever is behind them.
		label.add_theme_color_override("font_shadow_color", Color(Color("131313"), 0.7))
		label.add_theme_constant_override("shadow_offset_x", 2)
		label.add_theme_constant_override("shadow_offset_y", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		layer.add_child(label)
	# Placed by `_say`, in the middle of the frame.
	_caption.add_theme_font_size_override("font_size", UITheme.FONT_SIZE * 2)
	_caption.add_theme_constant_override("outline_size", 8)
	_caption.add_theme_constant_override("shadow_outline_size", 8)
	_sub.add_theme_font_size_override("font_size", UITheme.FONT_SIZE)
	_sub.add_theme_constant_override("outline_size", 6)
	_sub.add_theme_constant_override("shadow_outline_size", 6)
	_cursor.centered = false
	layer.add_child(_cursor)
	process_frame.connect(_follow)


## Each frame: the system's cursor where the clip's is, and the drawn one wearing whatever the game has
## asked the system for -- the arrow, the hand, the sword, the orb in hand, tilted while a press twitches it.
func _follow() -> void:
	root.warp_mouse(_pointer)
	# An Alt-Tab away from the recording leaves Alt held, which stands a worn piece's card beside a hovered one.
	if Input.is_key_pressed(KEY_ALT):
		var alt := InputEventKey.new()
		alt.keycode = KEY_ALT
		Input.parse_input_event(alt)
	var shape := Input.get_current_cursor_shape()
	var pair: Array = Cursors._held if shape == Cursors.ARROW and Cursors.holding() else Cursors._drawn.get(shape, [])
	if pair.is_empty():
		return
	var tilted := int(Cursors._twitched == shape) * 2
	_cursor.texture = pair[tilted]
	_cursor.position = (_pointer - pair[tilted + 1]).round()


func _glide(to: Vector2, time: float) -> void:
	var tween := create_tween()
	tween.tween_method(func(at: Vector2) -> void: _pointer = at, _pointer, to, time) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	await create_timer(0.1).timeout


func _click(hold := 0.08, after := 0.15, button := MOUSE_BUTTON_LEFT) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = button
	press.button_mask = MOUSE_BUTTON_MASK_LEFT if button == MOUSE_BUTTON_LEFT else MOUSE_BUTTON_MASK_RIGHT
	press.position = _pointer
	press.global_position = _pointer
	press.pressed = true
	Input.parse_input_event(press)
	await create_timer(hold).timeout
	var release: InputEventMouseButton = press.duplicate()
	release.pressed = false
	release.button_mask = 0
	Input.parse_input_event(release)
	await create_timer(after).timeout


## A caption popping in, the lines centred in the middle of `_frame`: `big` alone when `small` is empty,
## nothing at all when both are. `big` may run to more than one line, broken where it says "\n".
func _say(big: String, small: String) -> void:
	var changed := [_caption.text != big, _sub.text != small]
	_caption.text = big
	_sub.text = small
	var tall := [(_caption.get_theme_font_size("font_size") + 4.0) * (big.count("\n") + 1),
			20.0 if small != "" else 0.0]
	var middle := _caption_middle if _caption_middle > 0.0 else _frame.get_center().y
	var top: float = middle - (tall[0] + tall[1]) / 2.0
	for i in 2:
		var label: Label = [_caption, _sub][i]
		label.size = Vector2(_frame.size.x, maxf(tall[i], 1.0))
		label.position = Vector2(_frame.position.x, top + (tall[0] if i == 1 else 0.0))
		label.pivot_offset = label.size / 2.0
		if changed[i]:
			label.scale = Vector2.ONE * 0.5
			create_tween().tween_property(label, "scale", Vector2.ONE, 0.18) \
					.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
