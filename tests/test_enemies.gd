extends "res://tests/harness.gd"
## Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_enemies.gd
## Checks EnemyRoster against the sprites on disk and the environments the spritesheet defines, so a
## renamed folder, a missing sheet or a typo'd environment fails here rather than at spawn time.


func _run() -> void:
	_check(_test_every_entry_names_a_known_environment(), "environments are the spritesheet's")
	_check(_test_every_environment_has_every_tier(), "each environment can roll each tier")
	_check(_test_sheets_exist(), "every named sheet is on disk")
	_check(_test_frame_packs_have_frames(), "frame-per-file packs resolve their frames")
	_check(_test_pick_stays_in_environment(), "pick only returns enemies of that terrain")
	_check(_test_hp_rises_with_size_and_tier(), "health follows size and tier")
	_check(_test_frames_divide_their_sheets(), "every sheet is a whole number of frames")
	_check(_test_frames_fall_on_gutters(), "no frame boundary cuts through a sprite")
	_check(_test_bounds_hold_every_frame(), "the shared crop holds every frame of every animation")
	_report("enemy roster")


func _environments() -> PackedStringArray:
	var envs := PackedStringArray()
	for env: String in SheetMeta.env_adjacency():
		envs.append(env)
	return envs


func _test_every_entry_names_a_known_environment() -> bool:
	var known := _environments()
	for name in EnemyRoster.names():
		var envs := EnemyRoster.environments_of(name)
		_check(not envs.is_empty(), name + " lives somewhere")
		for env in envs:
			_check(env in known, name + " names a real environment, not " + env)
	return true


## Every terrain needs something to meet at each tier, or a tile there rolls an empty encounter.
func _test_every_environment_has_every_tier() -> bool:
	for env in _environments():
		for tier: EnemyRoster.Tier in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
			var found := EnemyRoster.in_environment(env, tier)
			_check(not found.is_empty(), "%s has a tier %d enemy" % [env, tier])
	return true


func _test_sheets_exist() -> bool:
	for name in EnemyRoster.names():
		for animation in EnemyRoster.ANIMATIONS:
			var path := EnemyRoster.sheet_path(name, animation)
			if path.is_empty():
				continue
			_check(ResourceLoader.exists(path), "missing sheet " + path)
	return true


func _test_frame_packs_have_frames() -> bool:
	for name in EnemyRoster.names():
		if not EnemyRoster.ENEMIES[name].has("frames"):
			continue
		for animation in EnemyRoster.ANIMATIONS:
			var frames := EnemyRoster.frame_paths(name, animation)
			_check(not frames.is_empty(), "%s has %s frames" % [name, animation])
	return true


## A frame size that doesn't divide the sheet leaves a sliver of the next frame hanging off the last one.
func _test_frames_divide_their_sheets() -> bool:
	for name in EnemyRoster.names():
		var frame := EnemyRoster.frame_size(name)
		_check(frame.x > 0 and frame.y > 0, name + " has a frame size")
		for animation in EnemyRoster.ANIMATIONS:
			var path := EnemyRoster.sheet_path(name, animation)
			if path.is_empty():
				continue
			var image := _image(path)
			_check(image.get_width() % frame.x == 0,
					"%s %s is %d wide, not a multiple of %d" % [name, animation, image.get_width(), frame.x])
			_check(image.get_height() == frame.y,
					"%s %s is %d tall, not %d" % [name, animation, image.get_height(), frame.y])
			_check(EnemyRoster.frame_count(name, animation) > 0, "%s has %s frames" % [name, animation])
	return true


## The packs leave a transparent gutter between frames, so a boundary landing on an opaque column means the
## frame width is wrong and the sprite is being sliced in two. This is what pins the measured numbers down.
func _test_frames_fall_on_gutters() -> bool:
	for name in EnemyRoster.names():
		var width := EnemyRoster.frame_size(name).x
		for animation in EnemyRoster.ANIMATIONS:
			var path := EnemyRoster.sheet_path(name, animation)
			if path.is_empty():
				continue
			var image := _image(path)
			var opaque := _opaque_columns(image)
			for k in range(1, image.get_width() / width):
				_check(not opaque[k * width] or not opaque[k * width - 1],
						"%s %s frame %d starts mid-sprite" % [name, animation, k])
	return true


## Every animation has to fit the one crop, or the creature jumps or loses a limb when the animation changes.
func _test_bounds_hold_every_frame() -> bool:
	for name in EnemyRoster.names():
		var bounds := EnemyRoster.bounds_of(name)
		var frame := EnemyRoster.frame_size(name)
		_check(bounds.size.x > 0 and bounds.size.y > 0, name + " has a crop")
		_check(Rect2i(Vector2i.ZERO, frame).encloses(bounds), name + " crops inside its frame")
		for animation in EnemyRoster.ANIMATIONS:
			var used := _used_rect(name, animation, frame)
			if used.size == Vector2i.ZERO:
				continue
			_check(bounds.encloses(used),
					"%s %s uses %s, outside the crop %s" % [name, animation, used, bounds])
	return true


## The part of a frame an animation actually paints, as a union over its frames.
func _used_rect(name: String, animation: String, frame: Vector2i) -> Rect2i:
	var used := Rect2i()
	var images: Array[Image] = []
	var path := EnemyRoster.sheet_path(name, animation)
	if path.is_empty():
		for file in EnemyRoster.frame_paths(name, animation):
			images.append(_image(file))
	else:
		var sheet := _image(path)
		for k in sheet.get_width() / frame.x:
			images.append(sheet.get_region(Rect2i(Vector2i(k * frame.x, 0), frame)))
	for image in images:
		var box := image.get_used_rect()
		if box.size == Vector2i.ZERO:
			continue
		used = box if used.size == Vector2i.ZERO else used.merge(box)
	return used


func _opaque_columns(image: Image) -> Array[bool]:
	var columns: Array[bool] = []
	columns.resize(image.get_width())
	for x in image.get_width():
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.0:
				columns[x] = true
				break
	return columns


## Textures have no readable image under --headless, so read the file, the way HexTileset does.
func _image(path: String) -> Image:
	var texture: Texture2D = load(path)
	var image := texture.get_image() if texture else null
	if image == null or image.is_empty():
		image = Image.load_from_file(path)
	if image.is_compressed():
		image.decompress()
	return image


func _test_pick_stays_in_environment() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for env in _environments():
		for i in 20:
			var picked := EnemyRoster.pick(env, EnemyRoster.Tier.COMMON, rng)
			_check(picked != "", env + " picked a common enemy")
			if picked != "":
				_check(env in EnemyRoster.environments_of(picked), "%s belongs on %s" % [picked, env])
	_check(EnemyRoster.pick("nowhere", EnemyRoster.Tier.BOSS, rng) == "", "unknown terrain picks nothing")
	return true


## The point of the two tables is that health only ever goes up with body and with tier, and that the
## tiers do not overlap: the toughest common must still be softer than the flimsiest elite.
func _test_hp_rises_with_size_and_tier() -> bool:
	var toughest := {}
	var flimsiest := {}
	for name in EnemyRoster.names():
		var hp := EnemyRoster.hp_modifier(name)
		_check(hp > 0.0, name + " has health")
		var tier := EnemyRoster.tier_of(name)
		toughest[tier] = maxf(toughest.get(tier, 0.0), hp)
		flimsiest[tier] = minf(flimsiest.get(tier, INF), hp)
	_check(toughest[EnemyRoster.Tier.COMMON] < flimsiest[EnemyRoster.Tier.ELITE], "no common outlasts an elite")
	_check(toughest[EnemyRoster.Tier.ELITE] < flimsiest[EnemyRoster.Tier.BOSS], "no elite outlasts a boss")

	var sizes := [
		EnemyRoster.Size.TINY, EnemyRoster.Size.SMALL, EnemyRoster.Size.MEDIUM,
		EnemyRoster.Size.LARGE, EnemyRoster.Size.HUGE,
	]
	for i in sizes.size() - 1:
		_check(EnemyRoster.SIZE_HP[sizes[i]] < EnemyRoster.SIZE_HP[sizes[i + 1]], "bigger bodies hold more")
	_check(EnemyRoster.hp_modifier("Slime") == 0.5, "the slime is the floor")
	return true
