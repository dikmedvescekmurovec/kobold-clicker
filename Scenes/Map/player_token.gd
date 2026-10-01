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
## The shadow under the feet, in the sheet's pixels: about the span of the idle stance's feet, which
## stand SHADOW_SHIFT right of the crop's middle (the tail fills the left). Darker than a fighter's, to
## read on the map's busy ground.
const SHADOW_WIDE := 36
const SHADOW_SHIFT := 7
const SHADOW_COLOUR := Color(0.06, 0.04, 0.09, 0.5)
## How long the character takes to cross one tile with no Move Speed.
const SECONDS_PER_TILE := 2.0
## A puff of dust kicked up every DUST_EVERY seconds while walking, drawn under the character.
const DUST_EVERY := 0.3
const DUST := Color("c8b48a")
## A footstep every FOOTSTEP_EVERY seconds while walking, shortened by Move Speed like a tile's crossing,
## each the next of the footsteps in turn. A running pace, quicker than the legs are drawn.
const FOOTSTEP_EVERY := 0.25
const FOOTSTEPS := 10
## Each footstep leaves a print at the feet, FOOTPRINT_SPREAD map pixels to the side it fell on,
## which stays FOOTPRINT_HOLD seconds and then fades out over FOOTPRINT_LIFE.
const FOOTPRINT := Color(0.1, 0.06, 0.03, 0.85)
const FOOTPRINT_SIZE := Vector2(3, 2)
const FOOTPRINT_SPREAD := 2.0
const FOOTPRINT_HOLD := 1.5
const FOOTPRINT_LIFE := 2.0

## The last tile of a walk has been reached.
signal arrived(cell: Vector2i)

var cell := HexMap.NO_CELL
## The player's Move Speed in percent, asked as each walk sets off (the main scene points it at the worn
## set), so boots put on mid-walk count from the next one. Unset, it is 0.
var move_speed := Callable()

var _map: HexMap
## Cells still to cross, in order; the first one is the step being walked.
var _path: Array[Vector2i] = []
var _from := Vector2.ZERO
var _to := Vector2.ZERO
## How far along the current step the character is, from 0 to 1.
var _step := 0.0
## How long this walk takes per tile: SECONDS_PER_TILE shortened by `move_speed`.
var _seconds := SECONDS_PER_TILE
var _dust_left := 0.0
var _footsteps: Array[AudioStream] = []
var _footstep := 0
var _footstep_left := 0.0
var _sound: AudioStreamPlayer
var _shadow: Sprite2D


func setup(map: HexMap) -> void:
	_map = map
	sprite_frames = _frames()
	scale = Vector2(SCALE, SCALE)
	# The offset is in the sprite's own pixels, which `scale` shrinks, so it is divided to land the feet
	# FOOT_OFFSET map pixels below the middle of the tile.
	offset = Vector2(0, FOOT_OFFSET / SCALE - BOUNDS.size.y / 2.0)
	play("idle")
	# A child, so it walks, hides and scales with the token, and behind it, so the feet stand on it.
	_shadow = Sprite2D.new()
	_shadow.texture = CombatActor.shadow_texture(SHADOW_WIDE, SHADOW_COLOUR)
	_shadow.show_behind_parent = true
	_shadow.position = Vector2(SHADOW_SHIFT, FOOT_OFFSET / SCALE)
	add_child(_shadow)
	for i in FOOTSTEPS:
		_footsteps.append(load("res://Sounds/Footsteps/footstep%02d.ogg" % i))
	_sound = AudioStreamPlayer.new()
	_sound.bus = Settings.SFX_BUS
	add_child(_sound)


func _process(delta: float) -> void:
	if is_walking():
		advance(delta)
		_kick_dust(delta)
		_tread(delta)


## Dust at the feet, on a timer rather than per frame of the run cycle, and put under the character.
## In `_process` rather than `advance`, so a test walking the token by hand makes no particles.
func _kick_dust(delta: float) -> void:
	_dust_left -= delta
	if _dust_left > 0.0:
		return
	_dust_left = DUST_EVERY
	var puff := Juice.burst(get_parent(), position + Vector2(0, FOOT_OFFSET), DUST, 4, 10.0, 1.5, 0.45, -8.0)
	puff.spread = 60.0
	get_parent().move_child(puff, get_index())


func _tread(delta: float) -> void:
	_footstep_left -= delta
	if _footstep_left > 0.0:
		return
	_footstep_left = FOOTSTEP_EVERY * _seconds / SECONDS_PER_TILE
	_sound.stream = _footsteps[_footstep]
	_sound.play()
	_footstep = (_footstep + 1) % FOOTSTEPS
	_leave_print()


## A print under the character, to the left or right of the line walked by turns.
func _leave_print() -> void:
	var across := (_to - _from).normalized().orthogonal()
	var side := FOOTPRINT_SPREAD if _footstep % 2 == 0 else -FOOTPRINT_SPREAD
	var foot := ColorRect.new()
	foot.color = FOOTPRINT
	foot.size = FOOTPRINT_SIZE
	foot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	foot.position = (position + Vector2(0, FOOT_OFFSET) + across * side - FOOTPRINT_SIZE / 2).round()
	get_parent().add_child(foot)
	get_parent().move_child(foot, get_index())
	var fade := foot.create_tween()
	fade.tween_property(foot, "modulate:a", 0.0, FOOTPRINT_LIFE).set_delay(FOOTPRINT_HOLD)
	fade.tween_callback(foot.queue_free)


## Puts the token on a cell, or on HexMap.NO_CELL to take it off the map. Any walk in progress is dropped.
func set_cell(value: Vector2i) -> void:
	_path.clear()
	_step = 0.0
	play("idle")
	cell = value
	visible = cell != HexMap.NO_CELL
	if visible:
		position = _map.ground_layer.map_to_local(cell)


## Walks the cells of `path` in order, at SECONDS_PER_TILE each over one plus `move_speed`. The path starts at a neighbor of the cell the
## token stands on and ends on the destination; an empty path does nothing.
func walk(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	_path = path.duplicate()
	var faster := 1.0 + (float(move_speed.call()) / 100.0 if move_speed.is_valid() else 0.0)
	_seconds = SECONDS_PER_TILE / faster
	# The legs keep up with the ground.
	play("run", faster)
	_start_step()


func is_walking() -> bool:
	return not _path.is_empty()


## Moves along the path by `delta` seconds. Called every frame while walking; tests drive it themselves.
func advance(delta: float) -> void:
	while is_walking():
		_step += delta / _seconds
		if _step < 1.0:
			position = _from.lerp(_to, _step)
			return
		# The step is over: stand on the tile, and carry what's left of `delta` into the next one.
		delta = (_step - 1.0) * _seconds
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
	# A child is not mirrored with its parent's picture, so the shadow's shift is.
	_shadow.position.x = -SHADOW_SHIFT if flip_h else SHADOW_SHIFT


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
