extends SceneTree
## Headless checks for environment and town generation. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_generation.gd

const ENV_SEEDS := 200
const WORLD_SEED := 12345

var _failures := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# A script error aborts a test function and makes it return null instead of true.
	_check(_test_hex_grid() == true, "hex grid tests ran to the end")
	_check(_test_adjacency_matches_sprites() == true, "adjacency tests ran to the end")
	_check(_test_environments() == true, "environment tests ran to the end")
	_check(_test_region_weights() == true, "region weight tests ran to the end")
	_check(_test_towns() == true, "town tests ran to the end")
	_check(_test_map_builder() == true, "map builder tests ran to the end")
	if _failures == 0:
		print("All generation tests passed")
	else:
		printerr("%d generation check(s) failed" % _failures)
	quit(1 if _failures else 0)


func _test_hex_grid() -> bool:
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(4, 5)]:
		for next in HexGrid.neighbors(cell):
			_check(HexGrid.distance(cell, next) == 1, "neighbor %s of %s is 1 step away" % [next, cell])
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(3, 0)) == 3, "distance along a row")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(1, 2)) == 2, "distance two steps SE")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(-1, 2)) == 2, "distance two steps SW")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(0, 4)) == 4, "distance zigzag down")
	return true


## EnvironmentGenerator.ALLOWED must stay equal to the sprite generator's table (JSON meta env_adjacency).
func _test_adjacency_matches_sprites() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HexTileset.SHEET_JSON))
	var table: Dictionary = data["meta"]["env_adjacency"]
	_check(table.size() == EnvironmentGenerator.ALLOWED.size(), "same environments in ALLOWED and env_adjacency")
	for env: String in EnvironmentGenerator.ALLOWED:
		var ours: Array = EnvironmentGenerator.ALLOWED[env] + [env]
		ours.sort()
		var theirs: Array = table.get(env, []).duplicate()
		theirs.sort()
		_check(ours == theirs, "%s borders match env_adjacency (%s vs %s)" % [env, ours, theirs])
	return true


func _test_environments() -> bool:
	var size := MapBuilder.SIZE
	var forbidden := 0
	var small_regions := 0
	var pairs := 0
	var same_pairs := 0
	var total_envs := 0
	var total_regions := 0
	var start := Time.get_ticks_msec()
	for seed_value in range(1, ENV_SEEDS + 1):
		var envs := EnvironmentGenerator.generate(size, seed_value)
		_check(envs.size() == size.x * size.y, "seed %d fills the map" % seed_value)
		for cell in envs:
			for next in HexGrid.neighbors(cell):
				if envs.has(next):
					pairs += 1
					if envs[next] == envs[cell]:
						same_pairs += 1
					elif not EnvironmentGenerator.can_border(envs[cell], envs[next]):
						forbidden += 1
		var regions := EnvironmentGenerator.find_regions(envs)
		small_regions += regions.filter(func(region: Array) -> bool: return region.size() < EnvironmentGenerator.MIN_REGION_SIZE).size()
		total_regions += regions.size()
		var distinct := {}
		for env in envs.values():
			distinct[env] = true
		total_envs += distinct.size()

	print("Environments over %d maps: %.1f ms/map, %.2f environments and %.2f regions per map, %.1f%% same-env neighbors, %d small regions" % [
		ENV_SEEDS, float(Time.get_ticks_msec() - start) / ENV_SEEDS, float(total_envs) / ENV_SEEDS,
		float(total_regions) / ENV_SEEDS, 100.0 * same_pairs / pairs, small_regions])
	_check(forbidden == 0, "no forbidden neighbors (found %d)" % forbidden)
	# Cleanup can't merge a small region wedged between environments that may not touch each other (e.g. grass
	# between ice and dirt), so allow it on at most 1% of maps.
	_check(small_regions <= ENV_SEEDS / 100, "at most 1%% of maps keep a region under MIN_REGION_SIZE (found %d)" % small_regions)
	_check(float(same_pairs) / pairs > 0.8, "neighbors mostly share an environment")
	_check(EnvironmentGenerator.generate(size, 7) == EnvironmentGenerator.generate(size, 7), "same seed gives the same map")
	_check(EnvironmentGenerator.generate(size, 7) != EnvironmentGenerator.generate(size, 8), "different seeds give different maps")
	return true


func _test_region_weights() -> bool:
	# Cell (10, 5) touches a 50-tile desert on its W edge and a 3-tile mountain region on its E edge.
	var cell := Vector2i(10, 5)
	var layout: Dictionary[Vector2i, String] = {}
	for y in range(3, 8):
		for x in 10:
			layout[Vector2i(x, y)] = "desert"
	for x in range(11, 14):
		layout[Vector2i(x, 5)] = "mountains"
	var weights := _weights_for(cell, layout)
	_check(weights.get("mountains", 0.0) > weights.get("desert", 0.0), "the smaller neighboring region gets more weight")
	_check(weights.get("desert", 0.0) > weights.get("grass", 0.0), "neighboring environments beat new ones")
	_check(not weights.has("grass") and not weights.has("forest") and not weights.has("ice"), "environments that can't border desert are excluded")

	# Touching forest and ice leaves only environments allowed next to both.
	var mixed: Dictionary[Vector2i, String] = {HexGrid.neighbor(cell, HexGrid.Edge.W): "forest", HexGrid.neighbor(cell, HexGrid.Edge.E): "ice"}
	var mixed_options := _weights_for(cell, mixed).keys()
	mixed_options.sort()
	_check(mixed_options == ["grass", "mountains"], "forest + ice neighbors allow only grass and mountains (got %s)" % [mixed_options])
	return true


func _test_towns() -> bool:
	var start := Time.get_ticks_msec()
	var world := TownWorld.generate(WORLD_SEED)
	var elapsed := Time.get_ticks_msec() - start
	var spots := world.size.x * world.size.y
	var counts := [0, 0, 0]
	var links := [0, 0, 0]
	var touching := 0
	var asymmetric := 0
	var too_far := 0
	for spot in world.towns():
		var tier := world.tier_at(spot)
		counts[tier] += 1
		links[tier] += world.connections(spot).size()
		touching += HexGrid.neighbors(spot).filter(world.has_town).size()
		for other in world.connections(spot):
			if not world.are_connected(other, spot):
				asymmetric += 1
			if HexGrid.distance(spot, other) > TownWorld.MAX_LINK_DISTANCE:
				too_far += 1

	var average_links := [0.0, 0.0, 0.0]
	for tier in 3:
		average_links[tier] = float(links[tier]) / maxi(counts[tier], 1)
		var rate := float(counts[tier]) / spots
		var chance: float = TownWorld.TIER_CHANCES[tier]
		_check(rate > chance * 0.7 and rate < chance * 1.1, "%s town rate %.4f is close to %.4f" % [TownWorld.TIER_NAMES[tier], rate, chance])
	print("Towns in %d spots: %d small, %d medium, %d fortress in %d ms; average links %.2f / %.2f / %.2f" % [
		spots, counts[0], counts[1], counts[2], elapsed, average_links[0], average_links[1], average_links[2]])
	_check(touching == 0, "no towns on neighboring spots (found %d)" % touching)
	_check(asymmetric == 0, "connections go both ways")
	_check(too_far == 0, "no connection longer than MAX_LINK_DISTANCE")
	_check(average_links[TownWorld.Tier.FORTRESS] > average_links[TownWorld.Tier.MEDIUM]
			and average_links[TownWorld.Tier.MEDIUM] > average_links[TownWorld.Tier.SMALL], "fortresses have the most links, small towns the fewest")
	_check(TownWorld.generate(WORLD_SEED).towns() == world.towns(), "same seed gives the same towns")
	return true


func _test_map_builder() -> bool:
	var map: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(map)
	var tileset := map.tileset
	var world := TownWorld.generate(WORLD_SEED)
	# Put the first town inside the window; the origin row is rounded down to even.
	var town := world.towns()[0]
	var origin := Vector2i(town.x - 5, (town.y - 4) & ~1)
	var env_seed := 99
	var start := Time.get_ticks_msec()
	MapBuilder.build(map, world, origin, env_seed)
	var build_ms := Time.get_ticks_msec() - start
	var envs := EnvironmentGenerator.generate(MapBuilder.SIZE, env_seed)

	var towns_drawn := 0
	var wrong_ground := 0
	var wrong_blends := 0
	var bad_weights := 0
	var blended_cells := 0
	start = Time.get_ticks_msec()
	for cell in envs:
		var info := map.get_tile_info(cell)
		var is_town := world.tier_at(origin + cell) != -1
		if is_town:
			towns_drawn += 1
			if info.get("name") != "town_%s_%s" % [envs[cell], TownWorld.TIER_NAMES[world.tier_at(origin + cell)]]:
				wrong_ground += 1
		elif info.get("group") != "environments" or info.get("env") != envs[cell]:
			wrong_ground += 1

		# Expected overlays, built independently from the generated environments: per higher-priority neighboring
		# environment, blend_<env>_<edge names in edge order>.
		var expected := PackedStringArray()
		if not is_town:
			var edges_by_env := {}
			for edge in 6:
				var next := HexGrid.neighbor(cell, edge)
				if envs.has(next) and tileset.env_rank(envs[next]) > tileset.env_rank(envs[cell]):
					if not edges_by_env.has(envs[next]):
						edges_by_env[envs[next]] = PackedStringArray()
					edges_by_env[envs[next]].append(HexGrid.Edge.keys()[edge])
			for env in tileset.blend_priority:
				if edges_by_env.has(env):
					expected.append("blend_%s_%s" % [env, "_".join(edges_by_env[env])])
		if ",".join(PackedStringArray(info["blends"])) != ",".join(expected):
			wrong_blends += 1
		if not expected.is_empty():
			blended_cells += 1

		# Weights sum to 1 and only name the cell's own environment and its overlay environments.
		var weights: Dictionary = info["environments"]
		var allowed_envs := [envs[cell]]
		for blend in expected:
			allowed_envs.append(blend.split("_")[1])
		var total := 0.0
		for env in weights:
			total += weights[env]
			if not (env in allowed_envs) or weights[env] <= 0.0:
				bad_weights += 1
		if absf(total - 1.0) > 0.000001:
			bad_weights += 1
	var info_ms := Time.get_ticks_msec() - start

	print("Map build %d ms (%d blended cells), tile info with weights for all %d cells %d ms" % [build_ms, blended_cells, envs.size(), info_ms])
	_check(map.ground_layer.get_used_cells().size() == envs.size(), "map fills its window")
	_check(wrong_ground == 0, "every cell shows its environment, or its environment's town (%d wrong)" % wrong_ground)
	_check(towns_drawn > 0, "the window's towns are drawn")
	_check(blended_cells > 0, "the map has blended cells")
	_check(wrong_blends == 0, "every cell has exactly the overlays the blend rule asks for (%d wrong)" % wrong_blends)
	_check(bad_weights == 0, "environment weights are valid on every cell (%d problems)" % bad_weights)
	_check(map.road_layer.get_used_cells().is_empty(), "no roads yet")
	map.queue_free()
	return true


func _weights_for(cell: Vector2i, layout: Dictionary[Vector2i, String]) -> Dictionary[String, float]:
	var envs: Dictionary[Vector2i, String] = {}
	var regions := EnvironmentGenerator.Regions.new()
	for placed in layout:
		envs[placed] = layout[placed]
		regions.add(placed, envs)
	return EnvironmentGenerator.choice_weights(cell, envs, regions)


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)
