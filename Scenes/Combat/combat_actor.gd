class_name CombatActor
extends AnimatedSprite2D
## A fighter in the combat scene: the player on the left, whatever the tile sent on the right.
##
## Both sides are built the same way, from a horizontal sheet cut into AtlasTexture frames, so the
## art is never resampled and nothing is copied (the same trick PlayerToken plays on the map). One
## crop is shared by all of a fighter's animations, so it doesn't jump or slide when the animation
## changes -- the packs draw their creatures anywhere in a wide frame, so this is what puts a
## fighter's feet where the scene wants them.
##
## Enemies come from EnemyRoster, which carries each pack's measured frame and crop; the player's
## three sheets are named here instead. Either way a fighter is scaled and stood up by its idle
## frames, so `position` is the middle of its feet whatever its other animations get up to.

const FPS := 10.0
## Animations that play once and stop on their last frame, rather than looping.
const ONCE := ["attack", "death", "hurt"]

const PLAYER_SHEETS := {
	"idle": "res://Assets/Player/idle.png",
	"walk": "res://Assets/Player/run.png",
	"attack": "res://Assets/Player/attack.png",
}
const PLAYER_FRAME := Vector2i(148, 96)
## The union of idle, run and attack. Much wider than PlayerToken.BOUNDS, which covers idle and run
## only and would cut the sword off the swing.
const PLAYER_BOUNDS := Rect2i(1, 29, 115, 62)

## The part of a frame this fighter draws, in its own sheet pixels.
var bounds: Rect2i
## The part the fighter fills while standing still, which is what it is scaled and placed by: a wild
## attack or a death sprawl must not shrink the character or shove it off its feet.
var standing: Rect2i


## The player, facing right. `height` is how tall to draw them on screen, in scene pixels.
func setup_player(height: float) -> void:
	bounds = PLAYER_BOUNDS
	var idle: Texture2D = load(PLAYER_SHEETS["idle"])
	standing = _standing_rect(idle, PLAYER_FRAME, idle.get_width() / PLAYER_FRAME.x)
	var built := SpriteFrames.new()
	var first := true
	for animation: String in PLAYER_SHEETS:
		var sheet: Texture2D = load(PLAYER_SHEETS[animation])
		var count := sheet.get_width() / PLAYER_FRAME.x
		_add(built, animation, _sheet_frames(sheet, PLAYER_FRAME, PLAYER_BOUNDS, count), first)
		first = false
	_finish(built, height, false)


## The enemy named in EnemyRoster, turned to face left towards the player. The packs disagree about
## which way they drew their creature, so only the ones EnemyRoster records as facing right are
## mirrored -- mirroring every enemy sends half of them running in backwards.
func setup_enemy(enemy_name: String, height: float) -> void:
	bounds = EnemyRoster.bounds_of(enemy_name)
	var frame := EnemyRoster.frame_size(enemy_name)
	standing = _standing_enemy_rect(enemy_name, frame)
	var built := SpriteFrames.new()
	var first := true
	for animation: String in EnemyRoster.ANIMATIONS:
		var textures := _enemy_frames(enemy_name, animation, frame, bounds)
		if textures.is_empty():
			continue
		_add(built, animation, textures, first)
		first = false
	_finish(built, height, EnemyRoster.facing_of(enemy_name) == EnemyRoster.Facing.RIGHT)


## The frames of one enemy animation: cut from its sheet, or one file each for the packs that ship
## separate frames. Empty when the pack has no such animation.
func _enemy_frames(enemy_name: String, animation: String, frame: Vector2i, crop: Rect2i) -> Array[AtlasTexture]:
	var path := EnemyRoster.sheet_path(enemy_name, animation)
	if not path.is_empty():
		var sheet: Texture2D = load(path)
		return _sheet_frames(sheet, frame, crop, EnemyRoster.frame_count(enemy_name, animation))
	var textures: Array[AtlasTexture] = []
	for file in EnemyRoster.frame_paths(enemy_name, animation):
		textures.append(_region(load(file), Rect2(crop)))
	return textures


## `count` frames laid out in one row, each cropped to the shared bounds.
func _sheet_frames(sheet: Texture2D, frame: Vector2i, crop: Rect2i, count: int) -> Array[AtlasTexture]:
	var textures: Array[AtlasTexture] = []
	for i in count:
		textures.append(_region(sheet, Rect2(Vector2i(i * frame.x, 0) + crop.position, crop.size)))
	return textures


func _region(sheet: Texture2D, region: Rect2) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	atlas.region = region
	return atlas


## SpriteFrames starts with one animation called "default", so the first one is a rename.
func _add(built: SpriteFrames, animation: String, textures: Array[AtlasTexture], first: bool) -> void:
	if first:
		built.rename_animation("default", animation)
	else:
		built.add_animation(animation)
	built.set_animation_speed(animation, FPS)
	built.set_animation_loop(animation, not animation in ONCE)
	for texture in textures:
		built.add_frame(animation, texture)


## Scales the fighter so that standing still it is `height` scene pixels tall, and puts the middle of
## its feet on `position`. Measured off the idle frames, so `position` means the same thing for a
## slime and a werewolf, and an attack that swings outside the body changes neither.
func _finish(built: SpriteFrames, height: float, mirror: bool) -> void:
	sprite_frames = built
	var factor := height / float(standing.size.y)
	scale = Vector2(factor, factor)
	# The drawn region is centred on the node, so shift it until the feet of the standing pose land there.
	var middle := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var feet := Vector2(standing.position.x + standing.size.x / 2.0, standing.end.y)
	offset = middle - feet
	flip_h = mirror
	play("idle")


## Plays a one-shot animation and returns to idling when it finishes. Looping ones just play.
##
## Re-triggered while it is still running, it restarts at `from_frame` rather than being ignored:
## Godot's `play()` on the animation already playing carries on instead of starting over, so a
## second swing during a swing would otherwise draw nothing at all. `from_frame` is how far in a
## re-trigger picks up -- past the wind-up for a swing, from the top for a flinch.
func play_once(anim: String, from_frame := 0) -> void:
	if not sprite_frames.has_animation(anim):
		return
	if is_playing() and animation == anim:
		frame = mini(from_frame, sprite_frames.get_frame_count(anim) - 1)
		frame_progress = 0.0
		return
	play(anim)


## How wide and tall the fighter is while standing, on screen.
func drawn_size() -> Vector2:
	return Vector2(standing.size) * scale.x


## The body's own colour, roughly: the mean of the solid pixels of its first idle frame, lightened a
## touch because a mean is muddier than any pixel it came from. What a death bursts in.
func tint() -> Color:
	var image := sprite_frames.get_frame_texture("idle", 0).get_image() if sprite_frames != null else null
	if image == null or image.is_empty():
		return Palette.BONE
	if image.is_compressed():
		image.decompress()
	var sum := Color(0, 0, 0, 0)
	var solid := 0
	for y in range(0, image.get_height(), 2):
		for x in range(0, image.get_width(), 2):
			var pixel := image.get_pixel(x, y)
			if pixel.a > 0.5:
				sum += pixel
				solid += 1
	if solid == 0:
		return Palette.BONE
	return Color(sum.r / solid, sum.g / solid, sum.b / solid).lightened(0.2)


## The part of a frame an idle sprite fills, across the animation. Uses Image.get_used_rect, which is
## native, so reading a sheet to measure it costs little.
func _standing_rect(sheet: Texture2D, frame: Vector2i, count: int) -> Rect2i:
	var image := sheet.get_image()
	if image == null or image.is_empty():
		image = Image.load_from_file(sheet.resource_path)
	if image.is_compressed():
		image.decompress()
	var union := Rect2i()
	for i in count:
		var used := image.get_region(Rect2i(Vector2i(i * frame.x, 0), frame)).get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		union = used if union.size == Vector2i.ZERO else union.merge(used)
	return bounds if union.size == Vector2i.ZERO else union


## The same for an enemy, whose idle is either a sheet or one file per frame.
func _standing_enemy_rect(enemy_name: String, frame: Vector2i) -> Rect2i:
	var path := EnemyRoster.sheet_path(enemy_name, "idle")
	if not path.is_empty():
		return _standing_rect(load(path), frame, EnemyRoster.frame_count(enemy_name, "idle"))
	var union := Rect2i()
	for file in EnemyRoster.frame_paths(enemy_name, "idle"):
		var used: Rect2i = (load(file) as Texture2D).get_image().get_used_rect()
		if used.size == Vector2i.ZERO:
			continue
		union = used if union.size == Vector2i.ZERO else union.merge(used)
	return bounds if union.size == Vector2i.ZERO else union
