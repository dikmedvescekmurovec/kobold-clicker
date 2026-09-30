class_name Cursors
extends RefCounted
## The mouse cursors, cut from Kenney's Cursor Pixel Pack (`Assets/Cursor/`, CC0) and blown up by a
## whole number so a sprite pixel stays square.
##
## Godot has no cursor of its own to add, only the system's shapes to redraw, so a sword or a hammer
## takes the place of a shape the game never asks for. Ask for one by the names here, never by the
## shape it sits in.

const ARROW := Input.CURSOR_ARROW
## Anything that can be pressed: every live button (`install` sees to those), a filled square, a map tile.
const HAND := Input.CURSOR_POINTING_HAND
## A press here is a swing: the arena during a fight, and the buttons that start one.
const SWORD := Input.CURSOR_CROSS
## The smith's own work.
const HAMMER := Input.CURSOR_BUSY
## The map held and pulled about.
const GRAB := Input.CURSOR_DRAG
## The button that walks the player somewhere.
const BOOT := Input.CURSOR_MOVE
## Something that only explains itself.
const HELP := Input.CURSOR_HELP

const TILE := "res://Assets/Cursor/Tiles/tile_%04d.png"
## Shape: [tile in the pack, the pixel of it that points, in the tile's own 16 px].
const SHAPES := {
	ARROW: [26, Vector2(1, 1)],
	HAND: [137, Vector2(6, 1)],
	SWORD: [107, Vector2(1, 1)],
	HAMMER: [110, Vector2(4, 4)],
	GRAB: [139, Vector2(8, 8)],
	BOOT: [98, Vector2(8, 8)],
	HELP: [180, Vector2(8, 8)],
}

## How long a press leaves the cursor tilted, and how far to the left it tilts, in degrees.
const TWITCH := 0.07
const TILT := 15.0

## Shape: [as drawn, its hotspot, tilted, the tilted one's hotspot] (`_pair`). Empty until `install`,
## so a test that never installs gets the system's arrow back from `hold` instead.
static var _drawn := {}
## Whether the last press came from a finger rather than a mouse -- a touchscreen, or the mouse Godot
## makes up from one. A finger has no hover, so what hover says with a mouse is said on a tap instead.
static var touched := false
## How far a finger may wobble, in panel pixels, and its press still be a tap rather than a drag.
const TOUCH_SLOP := 8.0
static var _scale := 1
## What stands in the arrow's place (`hold`), as the same pair, or empty.
static var _held: Array = []
## The shape a press tilted and has not yet put back, or -1.
static var _twitched := -1


## Redraws every shape in `SHAPES` at `scale`, and gives every button that joins `tree` from here on
## the hand unless whoever built it chose something else first.
static func install(tree: SceneTree, scale: int) -> void:
	_scale = scale
	for shape: Input.CursorShape in SHAPES:
		_drawn[shape] = _pair(load(TILE % SHAPES[shape][0]).get_image(), SHAPES[shape][1], scale)
		_show(shape, false)
	# The tree outlives a reloaded scene, which installs again.
	if not tree.node_added.is_connected(_on_node_added):
		tree.node_added.connect(_on_node_added)


## Hands the system its own cursors back. The drawn ones are textures `Input` would otherwise still be
## holding when the renderer goes, which it reports as leaks.
static func put_away() -> void:
	_drawn.clear()
	_held.clear()
	_twitched = -1
	for shape: Input.CursorShape in SHAPES:
		Input.set_custom_mouse_cursor(null, shape)
	Input.set_default_cursor_shape(ARROW)


## `shape` over `control`. The one place the two enums Godot keeps for the same list are crossed.
static func wear(control: Control, shape: Input.CursorShape) -> void:
	control.mouse_default_cursor_shape = int(shape) as Control.CursorShape


## For a Control that takes the presses meant for the squares inside it, which take no mouse of their
## own: call it with everything that Control hears, and it wears the hand while the cursor is over a
## filled square. Not while `held` -- an orb in the hand is the cursor there.
static func over_squares(control: Control, event: InputEvent, held := false) -> void:
	if not (event is InputEventMouseMotion):
		return
	var on := false
	if not held:
		for slot: ItemSlot in control.get_tree().get_nodes_in_group(ItemSlot.GROUP):
			if slot.item != null and control.is_ancestor_of(slot) and slot.is_visible_in_tree() 					and slot.get_global_rect().has_point(event.global_position):
				on = true
				break
	wear(control, HAND if on else ARROW)


## `mark` in the arrow's place, centred on the point -- an orb in the hand -- or the arrow back for null.
static func hold(mark: Texture2D) -> void:
	_held = [] if mark == null else _pair(mark.get_image(), mark.get_size() / 2.0, 1)
	_show(ARROW, false)


## Whether `event` came from a finger or a mouse (`touched`). Fed every event by the main scene's `_input`.
static func feel(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouse:
		touched = event is InputEventScreenTouch or event.device == InputEvent.DEVICE_ID_EMULATION


## Every event the main scene hears (`_input`, since a Control would eat a press before anything
## later saw it): a left press tilts the cursor under it to the left for `TWITCH`, about the tile's
## bottom right corner. The click lands where it would have. Nothing at `Settings.Anim.NONE`.
static func twitch(tree: SceneTree, event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed) 			or Settings.animations == Settings.Anim.NONE or _drawn.is_empty():
		return
	var shape := Input.get_current_cursor_shape()
	if not _drawn.has(shape):
		return
	if _twitched >= 0:
		_show(_twitched as Input.CursorShape, false)
	_twitched = shape
	_show(shape, true)
	tree.create_timer(TWITCH).timeout.connect(func() -> void:
		# A later press has its own timer, and `put_away` leaves nothing to put back.
		if _twitched == shape and _drawn.has(shape):
			_show(shape, false)
			_twitched = -1)


## `image` as a cursor pointing with `point`, and again turned `TILT` to the left about the tile's
## bottom right corner -- the wrist, so the tip is what dips -- on a canvas padded so no corner swings
## off it. The hotspot keeps its place on that canvas: the click lands where it would have. Blown up by `scale` first and turned in screen pixels:
## turned at 16 px the outlines broke up, and a sprite pixel cannot stay square through a turn anyway.
## Godot has no turn for an Image short of a quarter, so each pixel of the turned one is looked up
## where it came from.
static func _pair(image: Image, point: Vector2, scale: int) -> Array:
	image.resize(image.get_width() * scale, image.get_height() * scale, Image.INTERPOLATE_NEAREST)
	point *= scale
	var turn := deg_to_rad(TILT)
	var pivot := Vector2(image.get_size())
	var pad := ceili(maxi(image.get_width(), image.get_height()) * sin(turn)) + 1
	var tilted := Image.create_empty(image.get_width() + pad * 2, image.get_height() + pad * 2, false, image.get_format())
	for y in tilted.get_height():
		for x in tilted.get_width():
			# From the pixel's centre, back through the turn (y runs down, so left is this way round).
			var from := (Vector2(x - pad, y - pad) + Vector2(0.5, 0.5) - pivot).rotated(turn) + pivot
			if Rect2(Vector2.ZERO, image.get_size()).has_point(from):
				tilted.set_pixel(x, y, image.get_pixel(int(from.x), int(from.y)))
	return [ImageTexture.create_from_image(image), point,
			ImageTexture.create_from_image(tilted), point + Vector2(pad, pad)]


static func _show(shape: Input.CursorShape, tilted: bool) -> void:
	var pair: Array = _held if shape == ARROW and not _held.is_empty() else _drawn.get(shape, [])
	if pair.is_empty():
		Input.set_custom_mouse_cursor(null, shape)
	else:
		Input.set_custom_mouse_cursor(pair[int(tilted) * 2], shape, pair[int(tilted) * 2 + 1])


static func _on_node_added(node: Node) -> void:
	# A button dead as it joins keeps the arrow. One that dies later keeps the hand: the pages here
	# redraw their buttons rather than switch them off, so it has not been worth a watcher.
	if node is BaseButton and not node.disabled 			and node.mouse_default_cursor_shape == Control.CURSOR_ARROW:
		wear(node, HAND)
