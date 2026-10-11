class_name CombatActor
extends AnimatedSprite2D
## A fighter in the combat scene, either side: a horizontal sheet cut into AtlasTexture frames, every
## animation under one crop (`bounds`) so it does not jump as the animation changes. Scaled and stood up
## by its idle frames, so `position` is the middle of its feet whatever the other animations do.

const FPS := 10.0
## Played once, stopping on the last frame; the rest loop.
const ONCE := ["attack", "death", "hurt"]

## The kobold's swing, in frames: no hero's runs longer, so a longer sheet is played faster and the
## scene's cut back into a swing (`CombatScene._swing`) lands on the blow whoever swings.
const SWING_FRAMES := 5
## The packs draw at every resolution, so given the scene's pixel a fighter's scale snaps to steps of
## `PIXEL_STEP` of it, from one to `PIXEL_MOST`: three pixel sizes at most on screen, a band's height
## within about a sixth. Whole steps only were turned down: a Satyr Archer came out taller than a Cyclops.
const PIXEL_STEP := 0.5
const PIXEL_MOST := 2.0
## The shadow under the feet, in the fighter's own pixels: this share of the width of what it draws at
## its feet, never past `SHADOW_MOST_WIDE` of its height (a long tail must not stretch it).
const SHADOW_WIDE := 0.9
const SHADOW_MOST_WIDE := 1.2
const SHADOW_COLOUR := Color(0.06, 0.04, 0.09, 0.32)

## The crop every animation shares, in sheet pixels.
var bounds: Rect2i
## What the idle frames fill, which the fighter is scaled and placed by.
var standing: Rect2i
var _shadow: Sprite2D
## Everything read off a texture's pixels, by what was asked of which texture: reading one back from the
## GPU is slow, and every spawn and death asked again for answers that never change.
static var _read := {}


## The player as the hero `id` (`Characters`), facing right, `height` scene pixels tall; `pixel` is the
## backdrop's pixel in scene pixels, which the scale snaps to (0 leaves it free).
func setup_player(height: float, pixel := 0.0, id := Characters.FIRST) -> void:
	bounds = Characters.bounds(id)
	standing = player_standing(id)
	var frame := Characters.frame(id)
	var built := SpriteFrames.new()
	for animation: String in Characters.ANIMATIONS:
		var sheet: Texture2D = load(Characters.path(id, animation))
		_add(built, animation, _sheet_frames(sheet, frame, bounds, sheet.get_width() / frame.x))
	built.set_animation_speed("attack", FPS * maxf(1.0, built.get_frame_count("attack") / float(SWING_FRAMES)))
	_finish(built, height, false, pixel)


## What the hero `id` fills standing still, in its frame's pixels: its row's own box, else what its idle
## draws. The map's token is scaled by it too.
static func player_standing(id: String) -> Rect2i:
	var own := Characters.stand(id)
	if own.size != Vector2i.ZERO:
		return own
	var idle: Texture2D = load(Characters.path(id, "idle"))
	var frame := Characters.frame(id)
	var read := standing_rect(idle, frame, idle.get_width() / frame.x)
	return Characters.bounds(id) if read.size == Vector2i.ZERO else read


## An enemy of `EnemyRoster`, turned to face left: only one drawn facing right is mirrored. An `elite`
## is drawn a pixel step coarser than its body alone would be, past `PIXEL_MOST` if need be.
func setup_enemy(enemy_name: String, height: float, pixel := 0.0, elite := false) -> void:
	bounds = EnemyRoster.bounds_of(enemy_name)
	var frame := EnemyRoster.frame_size(enemy_name)
	standing = _standing_enemy_rect(enemy_name, frame)
	var built := SpriteFrames.new()
	for animation: String in EnemyRoster.ANIMATIONS:
		var textures := _enemy_frames(enemy_name, animation, frame, bounds)
		if not textures.is_empty():
			_add(built, animation, textures)
	_finish(built, height, EnemyRoster.facing_of(enemy_name) == EnemyRoster.Facing.RIGHT, pixel, elite)


## Empty when the pack has no such animation.
func _enemy_frames(enemy_name: String, animation: String, frame: Vector2i,
		crop: Rect2i) -> Array[AtlasTexture]:
	var path := EnemyRoster.sheet_path(enemy_name, animation)
	if not path.is_empty():
		var sheet: Texture2D = load(path)
		return _sheet_frames(sheet, frame, crop, EnemyRoster.frame_count(enemy_name, animation))
	var textures: Array[AtlasTexture] = []
	for file in EnemyRoster.frame_paths(enemy_name, animation):
		textures.append(_region(load(file), Rect2(crop)))
	return textures


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


## SpriteFrames starts with one animation called "default", so the first one added is a rename.
func _add(built: SpriteFrames, animation: String, textures: Array[AtlasTexture]) -> void:
	if built.has_animation("default"):
		built.rename_animation("default", animation)
	else:
		built.add_animation(animation)
	built.set_animation_speed(animation, FPS)
	built.set_animation_loop(animation, not animation in ONCE)
	for texture in textures:
		built.add_frame(animation, texture)


## Scales the fighter to stand `height` scene pixels tall, snapped to `pixel`'s steps when one is given,
## an `elite` a step coarser. The scene asks again when the window changes.
func fit(height: float, pixel := 0.0, elite := false) -> void:
	var factor := height / float(standing.size.y)
	if pixel > 0.0:
		factor = clampf(snappedf(factor / pixel, PIXEL_STEP), 1.0, PIXEL_MOST) * pixel
		if elite:
			factor += PIXEL_STEP * pixel
	scale = Vector2(factor, factor)


## Sizes the fighter (`fit`) and puts the middle of its standing feet on `position`.
func _finish(built: SpriteFrames, height: float, mirror: bool, pixel := 0.0, elite := false) -> void:
	sprite_frames = built
	fit(height, pixel, elite)
	# The drawn region is centred on the node: shift it until the standing feet land there.
	var middle := Vector2(bounds.position) + Vector2(bounds.size) / 2.0
	var feet := Vector2(standing.position.x + standing.size.x / 2.0, standing.end.y)
	offset = middle - feet
	# `flip_h` mirrors the picture inside its box and leaves `offset` alone.
	if mirror:
		offset.x = -offset.x
	flip_h = mirror
	_lay_shadow()
	play("idle")


## An ellipse behind the fighter and its child, so it takes the fighter's scale, fade and flash. Laid
## under what the first idle frame draws in the bottom quarter of the body, not under the middle of the
## standing box, which a trident held out drags off to one side.
func _lay_shadow() -> void:
	var span := Vector2(standing.position.x, standing.end.x)
	var key := _key("feet")
	if not _read.has(key):
		var drawn := Vector2(INF, -INF)
		var image := _idle_image()
		if image != null:
			var bottom := standing.end.y - bounds.position.y
			for y in range(maxi(0, bottom - maxi(1, standing.size.y / 4)), mini(bottom, image.get_height())):
				for x in image.get_width():
					if image.get_pixel(x, y).a > 0.5:
						drawn = Vector2(minf(drawn.x, x), maxf(drawn.y, x + 1))
		_read[key] = drawn
	var low: Vector2 = _read[key]
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


## A hard-edged ellipse `wide` pixels across and a quarter as deep. The map's token lays the same one.
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


## Plays `anim`; asked again while it runs, restarts it at `from_frame` (past the wind-up for a swing,
## the top for a flinch): Godot's `play()` on the animation already playing carries on, so a second
## swing during a swing would draw nothing.
func play_once(anim: String, from_frame := 0) -> void:
	if not sprite_frames.has_animation(anim):
		return
	if is_playing() and animation == anim:
		frame = mini(from_frame, sprite_frames.get_frame_count(anim) - 1)
		frame_progress = 0.0
		return
	play(anim)


## The standing fighter's size on screen.
func drawn_size() -> Vector2:
	return Vector2(standing.size) * scale.x


## The body's own colour, roughly, which a death bursts in: the mean of the first idle frame's solid
## pixels, lightened because a mean is muddier than any pixel it came from.
func tint() -> Color:
	if sprite_frames == null:
		return Palette.BONE
	var key := _key("tint")
	if not _read.has(key):
		_read[key] = _mean_colour()
	return _read[key]


## `_read`'s key for this fighter: its first idle frame says whose pixels they are.
func _key(asked: String) -> String:
	var first := sprite_frames.get_frame_texture("idle", 0) as AtlasTexture
	return "%s|%s|%s" % [asked, first.atlas.resource_path, first.region]


## The first idle frame's pixels, or null where there are none to read.
func _idle_image() -> Image:
	var image := sprite_frames.get_frame_texture("idle", 0).get_image()
	if image == null or image.is_empty():
		return null
	if image.is_compressed():
		image.decompress()
	return image


func _mean_colour() -> Color:
	var image := _idle_image()
	if image == null:
		return Palette.BONE
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


## What an idle sheet's `count` frames fill between them, or `bounds` where they draw nothing.
func _standing_rect(sheet: Texture2D, frame: Vector2i, count: int) -> Rect2i:
	return _or_bounds(standing_rect(sheet, frame, count))


## The same with no fighter to ask: an empty box where the frames draw nothing.
static func standing_rect(sheet: Texture2D, frame: Vector2i, count: int) -> Rect2i:
	var key := "standing|" + sheet.resource_path
	if not _read.has(key):
		var image := EnemyRoster.sheet_image(sheet.resource_path)
		var union := Rect2i()
		for i in count:
			union = _grown(union, image.get_region(Rect2i(Vector2i(i * frame.x, 0), frame)).get_used_rect())
		_read[key] = union
	return _read[key]


## The same for an enemy, whose idle is either a sheet or one file per frame.
func _standing_enemy_rect(enemy_name: String, frame: Vector2i) -> Rect2i:
	var path := EnemyRoster.sheet_path(enemy_name, "idle")
	if not path.is_empty():
		return _standing_rect(load(path), frame, EnemyRoster.frame_count(enemy_name, "idle"))
	var key := "standing|" + enemy_name
	if not _read.has(key):
		var union := Rect2i()
		for file in EnemyRoster.frame_paths(enemy_name, "idle"):
			union = _grown(union, (load(file) as Texture2D).get_image().get_used_rect())
		_read[key] = union
	return _or_bounds(_read[key])


## `union` grown to hold what one more frame uses; a frame that draws nothing adds nothing.
static func _grown(union: Rect2i, used: Rect2i) -> Rect2i:
	if used.size == Vector2i.ZERO:
		return union
	return used if union.size == Vector2i.ZERO else union.merge(used)


func _or_bounds(read: Rect2i) -> Rect2i:
	return bounds if read.size == Vector2i.ZERO else read
