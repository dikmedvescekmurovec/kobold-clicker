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
## The packs draw at every resolution, so a fighter scaled to its height alone wears pixels of its own
## size -- a crab five times the backdrop's, a flying eye finer than it. Given the scene's pixel, the
## scale is snapped to steps of `PIXEL_STEP` of it, no finer than one and no coarser than
## `PIXEL_MOST`: three pixel sizes at most on screen, and a band's height kept to within about a sixth.
## Whole steps only were tried on paper and turned down: a Satyr Archer came out taller than a Cyclops.
const PIXEL_STEP := 0.5
const PIXEL_MOST := 2.0
## The dark under a fighter's feet, so it stands on the ground rather than over it: this share wider
## than what it draws at its feet (never past `SHADOW_MOST_WIDE` of its height, so a long tail does
## not stretch it), a quarter as deep, in the fighter's own pixels.
const SHADOW_WIDE := 0.9
const SHADOW_MOST_WIDE := 1.2
const SHADOW_COLOUR := Color(0.06, 0.04, 0.09, 0.32)

## The part of a frame this fighter draws, in its own sheet pixels.
var bounds: Rect2i
## The part the fighter fills while standing still, which is what it is scaled and placed by: a wild
## attack or a death sprawl must not shrink the character or shove it off its feet.
var standing: Rect2i
var _shadow: Sprite2D


## The player, facing right. `height` is how tall to draw them on screen, in scene pixels; `pixel`, the
## backdrop's pixel in scene pixels, snaps the scale to it (0 leaves it free).
func setup_player(height: float, pixel := 0.0) -> void:
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
	_finish(built, height, false, pixel)


## The enemy named in EnemyRoster, turned to face left towards the player. The packs disagree about
## which way they drew their creature, so only the ones EnemyRoster records as facing right are
## mirrored -- mirroring every enemy sends half of them running in backwards. An `elite` is drawn a
## pixel step coarser than its body alone would be, past `PIXEL_MOST` if it has to, so it always looms.
func setup_enemy(enemy_name: String, height: float, pixel := 0.0, elite := false) -> void:
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
	_finish(built, height, EnemyRoster.facing_of(enemy_name) == EnemyRoster.Facing.RIGHT, pixel, elite)


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


## Scales the fighter so that standing still it is `height` scene pixels tall (snapped to `pixel`'s
## steps when one is given), and puts the middle of its feet on `position`. Measured off the idle
## frames, so `position` means the same thing for a slime and a werewolf, and an attack that swings
## outside the body changes neither.
func _finish(built: SpriteFrames, height: float, mirror: bool, pixel := 0.0, elite := false) -> void:
	sprite_frames = built
	var factor := height / float(standing.size.y)
	if pixel > 0.0:
		factor = clampf(snappedf(factor / pixel, PIXEL_STEP), 1.0, PIXEL_MOST) * pixel
		if elite:
			factor += PIXEL_STEP * pixel
	scale = Vector2(factor, factor)
	# The drawn region is centred on the node, so shift it until the feet of the standing pose land there.
	var middle := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var feet := Vector2(standing.position.x + standing.size.x / 2.0, standing.end.y)
	offset = middle - feet
	# `flip_h` mirrors the picture inside its box but leaves `offset` alone, so a mirrored fighter's
	# feet would land as far to the other side of `position` as they are from the frame's middle.
	if mirror:
		offset.x = -offset.x
	flip_h = mirror
	_lay_shadow()
	play("idle")


## An ellipse under the feet, drawn in the fighter's own pixels (it is a child, so it takes the
## fighter's scale, fade and flash) and behind it. It is laid under what the first idle frame draws in
## the bottom quarter of the body, not under the middle of the whole standing box, which a trident
## held out drags off to one side.
func _lay_shadow() -> void:
	var span := Vector2(standing.position.x, standing.end.x)
	var image := sprite_frames.get_frame_texture("idle", 0).get_image()
	if image != null and not image.is_empty():
		if image.is_compressed():
			image.decompress()
		var low := Vector2(INF, -INF)
		var bottom := standing.end.y - bounds.position.y
		for y in range(maxi(0, bottom - maxi(1, standing.size.y / 4)), mini(bottom, image.get_height())):
			for x in image.get_width():
				if image.get_pixel(x, y).a > 0.5:
					low = Vector2(minf(low.x, x), maxf(low.y, x + 1))
		if low.x < low.y:
			span = low + Vector2(bounds.position.x, bounds.position.x)
	var shift := (span.x + span.y) / 2.0 - (standing.position.x + standing.size.x / 2.0)
	var wide := maxi(4, roundi(minf((span.y - span.x) * SHADOW_WIDE, standing.size.y * SHADOW_MOST_WIDE)))
	if _shadow == null:
		_shadow = Sprite2D.new()
		_shadow.show_behind_parent = true
		add_child(_shadow)
	_shadow.texture = shadow_texture(wide)
	# A child is not mirrored with its parent's picture, so the shift is.
	_shadow.position.x = -shift if flip_h else shift


## A hard-edged ellipse `wide` pixels across and a quarter as deep, in `colour`. The map's token
## lays the same one under its feet.
static func shadow_texture(wide: int, colour := SHADOW_COLOUR) -> ImageTexture:
	var deep := maxi(2, roundi(wide / 4.0))
	var shade := Image.create(wide, deep, false, Image.FORMAT_RGBA8)
	var half := Vector2(wide, deep) / 2.0
	for y in deep:
		for x in wide:
			var at := (Vector2(x, y) + Vector2(0.5, 0.5) - half) / half
			if at.length_squared() <= 1.0:
				shade.set_pixel(x, y, colour)
	return ImageTexture.create_from_image(shade)


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
