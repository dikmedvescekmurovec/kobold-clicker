class_name PlayerToken
extends AnimatedSprite2D
## The player's hero on the map (`Characters`; `dress` says which): idles on a cell, and walks from tile
## to tile when told to. One crop cuts every frame of both animations, so the hero stays still as the
## animation changes.

const FPS := 8.0
## How tall a hero stands, in map pixels: about half a tile, so the terrain stays readable underneath.
## The kobold's 62 px at half size, and every other hero scaled to stand as tall.
const TALL := 31.0
## How far below the middle of the tile the hero's feet stand, in map pixels.
const FOOT_OFFSET := 6
## The shadow under the feet, as a share of the hero's standing height (36 px under the kobold's 62).
## Darker than a fighter's, to read on the map's busy ground.
const SHADOW_SHARE := 36.0 / 62.0
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
## How far the crop is shifted to put the hero's marked feet (`Characters.feet`) on the token while it
## faces east, in the sprite's own pixels: `flip_h` does not mirror `offset`, so `_face` does.
var _feet_shift := 0.0


func setup(map: HexMap) -> void:
	_map = map
	# A child, so it walks, hides and scales with the token, and behind it, so the feet stand on it.
	_shadow = Sprite2D.new()
	_shadow.show_behind_parent = true
	add_child(_shadow)
	dress(Characters.FIRST)
	for i in FOOTSTEPS:
		_footsteps.append(load("res://Sounds/Footsteps/footstep%02d.ogg" % i))
	_sound = AudioStreamPlayer.new()
	_sound.bus = Settings.SFX_BUS
	add_child(_sound)


## Draws the token as the hero `id`: its idle and its walk under one crop, scaled to stand `TALL`, the
## feet the user marked for it (2026-10-11) on the tile's foot point and its shadow under them. A hero
## dressed mid-walk walks on at its pace.
func dress(id: String) -> void:
	var walking := sprite_frames != null and is_playing()
	var playing := animation if walking else &"idle"
	var pace := get_playing_speed() if walking else 1.0
	var crop := Characters.bounds(id)
	var stand := CombatActor.player_standing(id)
	sprite_frames = _frames(id, crop)
	var by := TALL / stand.size.y
	scale = Vector2(by, by)
	# The crop is drawn centred on the token. `offset` is in the sprite's own pixels, which `scale`
	# shrinks, so the foot's drop is divided to land FOOT_OFFSET map pixels below the middle of the tile.
	var middle := Vector2(crop.position) + Vector2(crop.size) / 2.0
	_feet_shift = middle.x - Characters.feet(id)
	offset.y = middle.y - stand.end.y + FOOT_OFFSET / by
	_shadow.texture = CombatActor.shadow_texture(maxi(4, roundi(stand.size.y * SHADOW_SHARE)), SHADOW_COLOUR)
	_shadow.position = Vector2(0, FOOT_OFFSET / by)
	_face(flip_h)
	play(playing, pace)


## Turns the hero to face west or east, its feet staying where they stand.
func _face(west: bool) -> void:
	flip_h = west
	offset.x = -_feet_shift if west else _feet_shift


func _process(delta: float) -> void:
	if is_walking():
		advance(delta)
		_kick_dust(delta)
		_tread(delta)


## Dust at the feet, put under the character. Driven from `_process` rather than `advance`, so a test
## walking the token by hand makes no particles.
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


## Walks the cells of `path` in order, at SECONDS_PER_TILE each over one plus `move_speed`. The path
## starts at a neighbor of the cell the token stands on and ends on the destination; an empty path does
## nothing.
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


## Whether there is a walk to cut short: more of it is left than the step being walked.
func can_stop() -> bool:
	return _path.size() > 1


## Cuts the walk short: the step being walked is its last, so `arrived` fires on that tile.
## (Not `stop`, which is the sprite's own and stops the animation.)
func stop_walk() -> void:
	if can_stop():
		_path.resize(1)


func _start_step() -> void:
	_from = _map.ground_layer.map_to_local(cell)
	_to = _map.ground_layer.map_to_local(_path[0])
	_step = 0.0
	# The art faces east, so a step that leads west is mirrored.
	_face(_to.x < _from.x)


func _finish_step() -> void:
	cell = _path.pop_front()
	position = _to
	_step = 0.0
	if is_walking():
		_start_step()
	else:
		play("idle")
		arrived.emit(cell)


func _frames(id: String, crop: Rect2i) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.rename_animation("default", "idle")
	frames.add_animation("run")
	var wide := Characters.frame(id).x
	# The sheet a fight plays as "walk" is the map's run.
	for named: Array in [["idle", "idle"], ["run", "walk"]]:
		frames.set_animation_speed(named[0], FPS)
		frames.set_animation_loop(named[0], true)
		var sheet: Texture2D = load(Characters.path(id, named[1]))
		for i in sheet.get_width() / wide:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(Vector2i(i * wide, 0) + crop.position, crop.size)
			frames.add_frame(named[0], atlas)
	return frames
