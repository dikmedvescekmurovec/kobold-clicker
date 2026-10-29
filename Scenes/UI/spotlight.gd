class_name Spotlight
extends Control
## The window shaded but for one Control, the next thing a first step makes the player press (the
## user's ask, 2026-10-29): a press inside `target`'s rect falls through to it (`_has_point`), every
## other press and every key is eaten. The main scene puts it up, moves it on and takes it down
## (`_spotlight`), setting `target` before this draws each frame.

const SHADE := Color(Palette.INK, 0.7)
## How far the lit hole stands round the target, in panel pixels. Only the target's own rect lets a
## press through, so a press on this rim never reaches the map.
const RIM := 2

var target: Control
var _ui_scale := 1.0
## The target's rect in this Control's coordinates, measured once a frame: a press can land after the
## page has redrawn the target out of the tree.
var _hole := Rect2()


func _init(lit: Control, final: float) -> void:
	target = lit
	_ui_scale = final
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	_measure()
	if Settings.animations != Settings.Anim.NONE:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, Juice.POP_TIME)


## Every frame: the target moves on with the step, glides after a page and moves with the window.
func _process(_delta: float) -> void:
	_measure()
	queue_redraw()


func _measure() -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		_hole = (get_global_transform_with_canvas().affine_inverse() * target.get_global_transform_with_canvas()
				* Rect2(Vector2.ZERO, target.size))


func _draw() -> void:
	var hole := _hole.grow(RIM * _ui_scale)
	draw_rect(Rect2(0, 0, size.x, hole.position.y), SHADE)
	draw_rect(Rect2(0, hole.end.y, size.x, size.y - hole.end.y), SHADE)
	draw_rect(Rect2(0, hole.position.y, hole.position.x, hole.size.y), SHADE)
	draw_rect(Rect2(hole.end.x, hole.position.y, size.x - hole.end.x, hole.size.y), SHADE)


func _has_point(point: Vector2) -> bool:
	return not _hole.has_point(point)


## Before the main scene's hotkeys and Escape, which are `_unhandled_input`'s.
func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
