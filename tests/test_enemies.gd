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
