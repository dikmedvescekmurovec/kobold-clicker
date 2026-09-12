class_name PlayerToken
extends AnimatedSprite2D
## The player's character: idles on a map cell, and walks from tile to tile when told to.
##
## The sheet frames are wide, so the character can swing beyond its own body in the attack animation. Only the
## part the character uses is cut out (BOUNDS), otherwise it would sit off to the left of the tile. The same
## crop serves every animation, so the character doesn't jump when it changes, and the frames keep their own
## size, so the art is never resampled.

const IDLE_SHEET := preload("res://Assets/Player/idle.png")
const RUN_SHEET := preload("res://Assets/Player/run.png")
const IDLE_FRAMES := 6
const RUN_FRAMES := 8
## Every frame of every sheet, laid out in one row.
const FRAME_SIZE := Vector2i(148, 96)
## The part of a frame the character occupies across both sheets, so the idle bobbing and the run are kept whole.
const BOUNDS := Rect2i(17, 29, 66, 62)
const FPS := 8.0
## Drawn at half size, so the character takes up about half a tile and the terrain stays readable underneath.
const SCALE := 0.5
## How far below the middle of the tile the character's feet stand, in map pixels.
const FOOT_OFFSET := 6
## How long the character takes to cross one tile.
const SECONDS_PER_TILE := 2.0

## The last tile of a walk has been reached.
signal arrived(cell: Vector2i)

var cell := HexMap.NO_CELL

var _map: HexMap
## Cells still to cross, in order; the first one is the step being walked.
var _path: Array[Vector2i] = []
var _from := Vector2.ZERO
var _to := Vector2.ZERO
## How far along the current step the character is, from 0 to 1.
var _step := 0.0


func setup(map: HexMap) -> void:
	_map = map
	sprite_frames = _frames()
	scale = Vector2(SCALE, SCALE)
	# The offset is in the sprite's own pixels, which `scale` shrinks, so it is divided to land the feet
	# FOOT_OFFSET map pixels below the middle of the tile.
	offset = Vector2(0, FOOT_OFFSET / SCALE - BOUNDS.size.y / 2.0)
	play("idle")


func _process(delta: float) -> void:
	if is_walking():
		advance(delta)


## Puts the token on a cell, or on HexMap.NO_CELL to take it off the map. Any walk in progress is dropped.
func set_cell(value: Vector2i) -> void:
	_path.clear()
	_step = 0.0
	play("idle")
	cell = value
	visible = cell != HexMap.NO_CELL
	if visible:
		position = _map.ground_layer.map_to_local(cell)


## Walks the cells of `path` in order, at SECONDS_PER_TILE each. The path starts at a neighbor of the cell the
## token stands on and ends on the destination; an empty path does nothing.
func walk(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	_path = path.duplicate()
	play("run")
	_start_step()


func is_walking() -> bool:
	return not _path.is_empty()


## Moves along the path by `delta` seconds. Called every frame while walking; tests drive it themselves.
func advance(delta: float) -> void:
	while is_walking():
		_step += delta / SECONDS_PER_TILE
		if _step < 1.0:
			position = _from.lerp(_to, _step)
			return
		# The step is over: stand on the tile, and carry what's left of `delta` into the next one.
		delta = (_step - 1.0) * SECONDS_PER_TILE
		_finish_step()


## Puts the character on the last cell of the path at once, as if the walk had run its course.
func finish_walk() -> void:
	while is_walking():
		_finish_step()


func _start_step() -> void:
	_from = _map.ground_layer.map_to_local(cell)
	_to = _map.ground_layer.map_to_local(_path[0])
	_step = 0.0
	# The art faces east, so a step that leads west is mirrored.
	flip_h = _to.x < _from.x


func _finish_step() -> void:
	cell = _path.pop_front()
	position = _to
	_step = 0.0
	if is_walking():
		_start_step()
	else:
		play("idle")
		arrived.emit(cell)


func _frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.rename_animation("default", "idle")
	_add_animation(frames, "idle", IDLE_SHEET, IDLE_FRAMES)
	frames.add_animation("run")
	_add_animation(frames, "run", RUN_SHEET, RUN_FRAMES)
	return frames


func _add_animation(frames: SpriteFrames, name: String, sheet: Texture2D, count: int) -> void:
	frames.set_animation_speed(name, FPS)
	frames.set_animation_loop(name, true)
	for i in count:
		var atlas := AtlasTexture.new()
		atlas.atlas = sheet
		atlas.region = Rect2(Vector2i(i * FRAME_SIZE.x, 0) + BOUNDS.position, BOUNDS.size)
		frames.add_frame(name, atlas)
