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
	_check(_test_roads() == true, "road tests ran to the end")
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
	var cells := MapBuilder.RECT
	var forbidden := 0
	var small_regions := 0
	var pairs := 0
	var same_pairs := 0
	var total_envs := 0
	var total_regions := 0
	var start := Time.get_ticks_msec()
	for seed_value in range(1, ENV_SEEDS + 1):
		var envs := EnvironmentGenerator.generate(cells, seed_value)
		_check(envs.size() == cells.size.x * cells.size.y, "seed %d fills the map" % seed_value)
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
	_check(EnvironmentGenerator.generate(cells, 7) == EnvironmentGenerator.generate(cells, 7), "same seed gives the same map")
	_check(EnvironmentGenerator.generate(cells, 7) != EnvironmentGenerator.generate(cells, 8), "different seeds give different maps")
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

	# The guaranteed starting town, on the ring MapBuilder asks about.
	var candidates: Array[Vector2i] = []
	for cell in MapBuilder.start_town_cells():
		candidates.append(Vector2i(40, 40) + cell)
	var before := world.towns().size()
	var chosen := world.ensure_small_town(candidates)
	_check(chosen in candidates and world.tier_at(chosen) == TownWorld.Tier.SMALL, "ensure_small_town leaves a small town on a candidate spot")
	_check(world.towns().size() <= before + 1, "ensure_small_town adds at most one town")
	_check(HexGrid.neighbors(chosen).filter(world.has_town).is_empty(), "the guaranteed town doesn't touch another town")
	_check(not world.connections(chosen).is_empty(), "the guaranteed town is connected")
	for other in world.connections(chosen):
		_check(world.are_connected(other, chosen), "the guaranteed town's links go both ways")
	_check(world.ensure_small_town(candidates) == chosen, "asking again keeps the same town")
	_check(TownWorld.generate(WORLD_SEED).ensure_small_town(candidates) == chosen, "same seed picks the same spot")

	# Clearing the area around a starting point.
	var scratch := TownWorld.generate(WORLD_SEED)
	var center := Vector2i(60, 60)
	var removed := scratch.clear_towns_near(center, MapBuilder.START_TOWN_DISTANCE)
	_check(removed > 0, "clearing removes the towns around the center")
	_check(scratch.towns().filter(func(spot: Vector2i) -> bool:
			return HexGrid.distance(spot, center) < MapBuilder.START_TOWN_DISTANCE).is_empty(),
			"no town is left within %d steps" % MapBuilder.START_TOWN_DISTANCE)
	var dangling := 0
	for spot in scratch.towns():
		for other in scratch.connections(spot):
			if not scratch.has_town(other) or not scratch.are_connected(other, spot):
				dangling += 1
	_check(dangling == 0, "no link points at a removed town (%d)" % dangling)
	return true


func _test_map_builder() -> bool:
	var map: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(map)
	var tileset := map.tileset
	var world := TownWorld.generate(WORLD_SEED)
	# Put a town inside the window; the origin row is rounded down to even. The town has to sit far enough from
	# the world's edges that the whole window, including the starting-town ring, stays inside the world.
	var town: Vector2i = world.towns().filter(func(spot: Vector2i) -> bool:
			return spot.x > 20 and spot.y > 20 and spot.x < 230 and spot.y < 230)[0]
	var origin := Vector2i(town.x, town.y & ~1)
	var env_seed := 99
	var start := Time.get_ticks_msec()
	var view := MapBuilder.create(map, world, origin, env_seed)
	var start_town := view.start_town
	var build_ms := Time.get_ticks_msec() - start

	# The start is a hexagon of 7 tiles, and discovering a tile shows the tiles around it.
	var start_tiles := MapBuilder.start_cells()
	var rows := {}
	for cell: Vector2i in start_tiles:
		rows[cell.y] = rows.get(cell.y, 0) + 1
	_check(start_tiles.size() == 7 and rows.get(-1) == 2 and rows.get(0) == 3 and rows.get(1) == 2,
			"the start is a hexagon in rows of 2, 3, 2 (got %s)" % [rows])
	_check(start_tiles.all(func(cell: Vector2i) -> bool: return HexGrid.distance(MapBuilder.CENTER, cell) <= 1),
			"every starting tile is the center or touches it")
	_check(map.ground_layer.get_used_cells().size() == start_tiles.size(), "only the 7 starting tiles are drawn")
	_check(view.discovered(MapBuilder.CENTER) and not view.discovered(Vector2i(4, 0)), "the start covers the hexagon only")
	_check(not view.can_discover(MapBuilder.CENTER), "the center is boxed in by the starting tiles")
	_check(not view.can_discover(Vector2i(4, 0)) and view.discover(Vector2i(4, 0)) == 0, "an undiscovered tile discovers nothing")
	var rim := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	var expected_new := HexGrid.neighbors(rim).filter(func(next: Vector2i) -> bool:
			return MapBuilder.RECT.has_point(next) and not view.discovered(next)).size()
	_check(view.can_discover(rim) and expected_new > 0, "a tile on the rim of the start has more to show")
	_check(view.discover(rim) == expected_new, "discovering shows every undiscovered neighbor")
	_check(map.ground_layer.get_used_cells().size() == start_tiles.size() + expected_new, "the newly shown tiles are drawn")
	for next in HexGrid.neighbors(rim):
		_check(view.discovered(next), "%s is discovered now" % next)

	view.reveal_all()
	var envs := EnvironmentGenerator.generate(MapBuilder.RECT, env_seed)
	var roads := RoadNetwork.build(world, Rect2i(origin + MapBuilder.RECT.position, MapBuilder.RECT.size),
			tileset.legal_road_masks(), {}, start_town, origin)

	var towns_drawn := 0
	var wrong_ground := 0
	var wrong_blends := 0
	var bad_weights := 0
	var blended_cells := 0
	var wrong_roads := 0
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

		# The road tile must match the network, in the material of the tile's environment.
		var mask: int = roads.get(origin + cell, 0)
		var expected_road := "" if mask == 0 or is_town else tileset.road_name(
				tileset.road_material_for(envs[cell]), RoadNetwork.mask_edges(mask))
		if info["road"] != expected_road:
			wrong_roads += 1

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
	_check(wrong_roads == 0, "every cell's road matches the network and its material (%d wrong)" % wrong_roads)
	_check(not map.road_layer.get_used_cells().is_empty(), "the window's roads are drawn")

	# The first town: exactly START_TOWN_DISTANCE out, nothing nearer, and a road to the center cell.
	_check(HexGrid.distance(origin, start_town) == MapBuilder.START_TOWN_DISTANCE
			and world.tier_at(start_town) == TownWorld.Tier.SMALL,
			"the first town is a small town %d steps out (got %s at %d)" % [
				MapBuilder.START_TOWN_DISTANCE, TownWorld.TIER_NAMES[maxi(world.tier_at(start_town), 0)],
				HexGrid.distance(origin, start_town)])
	var nearer := world.towns().filter(func(spot: Vector2i) -> bool:
			return HexGrid.distance(spot, origin) < MapBuilder.START_TOWN_DISTANCE)
	_check(nearer.is_empty(), "no town closer to the center than the first one (%d)" % nearer.size())
	_check(map.get_tile_info(Vector2i.ZERO)["road"] != "", "a road reaches the center cell")
	_check(_roads_join(roads, start_town, origin), "the center cell is connected by road to the first town")

	# Every map has a small town exactly START_TOWN_DISTANCE steps from cell (0, 0).
	var start_cells := MapBuilder.start_town_cells()
	_check(start_cells.all(func(cell: Vector2i) -> bool: return HexGrid.distance(Vector2i.ZERO, cell) == MapBuilder.START_TOWN_DISTANCE),
			"candidate cells are all %d steps out" % MapBuilder.START_TOWN_DISTANCE)
	var start_towns := start_cells.filter(func(cell: Vector2i) -> bool: return world.tier_at(origin + cell) == TownWorld.Tier.SMALL)
	_check(not start_towns.is_empty(), "a small town sits %d steps from cell (0, 0)" % MapBuilder.START_TOWN_DISTANCE)
	if not start_towns.is_empty():
		var drawn: String = map.get_tile_info(start_towns[0]).get("name", "")
		_check(drawn.begins_with("town_") and drawn.ends_with("_small"), "the guaranteed town is drawn as a small town (got %s)" % drawn)
	map.queue_free()
	return true


func _test_roads() -> bool:
	var tileset := HexTileset.new()
	var legal := tileset.legal_road_masks()
	var world := TownWorld.generate(WORLD_SEED)
	var illegal := 0
	var on_towns := 0
	var dangling := 0
	var strays := 0
	var unrouted := 0
	var road_tiles := 0
	var routes := 0
	var skipped := 0
	var elapsed := 0
	for origin: Vector2i in [Vector2i(40, 40), Vector2i(90, 120), Vector2i(160, 60)]:
		var rect := Rect2i(origin + MapBuilder.RECT.position, MapBuilder.RECT.size)
		var area := rect.grow(RoadNetwork.MARGIN)
		var stats := {}
		var start := Time.get_ticks_msec()
		var roads := RoadNetwork.build(world, rect, legal, stats)
		elapsed += Time.get_ticks_msec() - start
		road_tiles += roads.size()
		routes += stats["routes"]
		skipped += stats["skipped"]

		for spot in roads:
			if not legal.has(roads[spot]):
				illegal += 1
			if world.has_town(spot):
				on_towns += 1
			# Every edge of a road tile must meet another road, a town, or the border of the built area.
			for edge in RoadNetwork.mask_edges(roads[spot]):
				var other := HexGrid.neighbor(spot, edge)
				var joined: bool = roads.has(other) and (roads[other] & (1 << ((edge + 3) % 6))) != 0
				if not (joined or world.has_town(other) or not area.has_point(other)):
					dangling += 1
		strays += _stray_road_groups(roads, world, area)
		unrouted += _unrouted_links(world, roads, rect)
		_check(RoadNetwork.build(world, rect, legal) == roads, "same world and rect give the same roads")

	print("Roads over 3 windows: %d routes (%d skipped), %d tiles, %d ms" % [routes, skipped, road_tiles, elapsed])
	_check(illegal == 0, "every road mask is a shape the sprites have (%d bad)" % illegal)
	_check(on_towns == 0, "no road on a town spot (%d)" % on_towns)
	_check(dangling == 0, "every road edge meets a road, a town or the area border (%d loose)" % dangling)
	_check(strays == 0, "every road leads to a town (%d groups that don't)" % strays)
	_check(unrouted == 0, "linked towns in the window are joined by road (%d missing)" % unrouted)
	_check(routes > 0 and road_tiles > 0, "roads were built at all")
	return true


## Groups of connected road tiles that reach neither a town nor the border of the built area.
func _stray_road_groups(roads: Dictionary, world: TownWorld, area: Rect2i) -> int:
	var seen := {}
	var strays := 0
	for start in roads:
		if seen.has(start):
			continue
		seen[start] = true
		var queue: Array[Vector2i] = [start]
		var leads_somewhere := false
		var i := 0
		while i < queue.size():
			var spot := queue[i]
			i += 1
			for edge in RoadNetwork.mask_edges(roads[spot]):
				var other := HexGrid.neighbor(spot, edge)
				if world.has_town(other) or not area.has_point(other):
					leads_somewhere = true
				elif roads.has(other) and not seen.has(other):
					seen[other] = true
					queue.append(other)
		if not leads_somewhere:
			strays += 1
	return strays


## Links whose two towns both sit in the window but have no chain of road tiles between them.
func _unrouted_links(world: TownWorld, roads: Dictionary, rect: Rect2i) -> int:
	var missing := 0
	var checked := {}
	for spot in world.towns():
		if not rect.has_point(spot):
			continue
		for other in world.connections(spot):
			if not rect.has_point(other):
				continue
			var key := "%s%s" % ([spot, other] if spot < other else [other, spot])
			if checked.has(key):
				continue
			checked[key] = true
			if not _roads_join(roads, spot, other):
				missing += 1
	return missing


func _roads_join(roads: Dictionary, from_town: Vector2i, to_town: Vector2i) -> bool:
	var queue: Array[Vector2i] = []
	var seen := {}
	for edge in 6:
		var cell := HexGrid.neighbor(from_town, edge)
		if roads.has(cell) and (roads[cell] & (1 << ((edge + 3) % 6))) != 0:
			seen[cell] = true
			queue.append(cell)
	var i := 0
	while i < queue.size():
		var spot := queue[i]
		i += 1
		for edge in RoadNetwork.mask_edges(roads[spot]):
			var other := HexGrid.neighbor(spot, edge)
			if other == to_town:
				return true
			if roads.has(other) and not seen.has(other) and (roads[other] & (1 << ((edge + 3) % 6))) != 0:
				seen[other] = true
				queue.append(other)
	return false


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
