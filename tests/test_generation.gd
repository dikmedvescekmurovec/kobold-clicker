extends "res://tests/harness.gd"
## Headless checks for environment and town generation. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_generation.gd

const ENV_SEEDS := 200
## Never MapSave.SAVE_PATH: these tests write and delete, and that is the player's own map.
const TEST_MAP_PATH := "user://test_generation_map.json"
const SCRATCH_INVENTORY := "user://test_generation_inventory.json"


func _run() -> void:
	_check(_test_hex_grid() == true, "hex grid tests ran to the end")
	_check(_test_environments() == true, "environment tests ran to the end")
	_check(_test_environment_growth() == true, "environment growth tests ran to the end")
	_check(_test_region_weights() == true, "region weight tests ran to the end")
	_check(_test_towns() == true, "town tests ran to the end")
	_check(_test_roads() == true, "road tests ran to the end")
	_check(_test_map_builder() == true, "map builder tests ran to the end")
	_check(_test_sight() == true, "sight tests ran to the end")
	_check(_test_tile_levels() == true, "tile level tests ran to the end")
	_check(_test_map_saving() == true, "map save tests ran to the end")
	_check(await _test_the_map_comes_back() == true, "map reload tests ran to the end")
	_report("generation")


## A tile's level, in bands that widen as they go: band n is n tiles wide, so level n begins at the
## nth triangular number. It is what the panel shows and the ceiling on what can drop on a tile.
func _test_tile_levels() -> bool:
	_check(MapBuilder.level_of(MapBuilder.CENTER) == 1, "the middle of the map is level 1")

	# Band n starts exactly at n(n-1)/2 and is exactly n tiles wide. This is the whole curve: if it
	# holds out to level 10 it holds everywhere, because the formula has no other moving part.
	for n in range(1, 11):
		var starts: int = n * (n - 1) / 2
		for steps in range(starts, starts + n):
			_check(MapBuilder.level_of(Vector2i(steps, 0)) == n,
					"%d steps out is level %d, not %d" % [steps, n, MapBuilder.level_of(Vector2i(steps, 0))])
		_check(MapBuilder.level_of(Vector2i(starts - 1, 0)) == n - 1 if n > 1 else true,
				"the tile before band %d belongs to the one under it" % n)

	# The same answer in every direction, because it is a function of hex distance and nothing else.
	for edge: HexGrid.Edge in HexGrid.EDGES:
		var cell := MapBuilder.CENTER
		for steps in range(1, 30):
			cell = HexGrid.neighbor(cell, edge)
			_check(MapBuilder.level_of(cell) == MapBuilder.level_of(Vector2i(steps, 0)),
					"%s is level %d going edge %d, not %d" % [cell, MapBuilder.level_of(cell), edge,
							MapBuilder.level_of(Vector2i(steps, 0))])

	# Never falls as the walk gets longer, and never jumps: one step can cost at most one level, which
	# is what lets the number on the panel mean anything as the player moves.
	for steps in range(1, 60):
		var here := MapBuilder.level_of(Vector2i(steps, 0))
		var back := MapBuilder.level_of(Vector2i(steps - 1, 0))
		_check(here == back or here == back + 1, "step %d went from level %d to %d" % [steps, back, here])
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(7, 0), Vector2i(-3, 6)]:
		for next in HexGrid.neighbors(cell):
			_check(absi(MapBuilder.level_of(cell) - MapBuilder.level_of(next)) <= 1,
					"%s and its neighbour %s are more than one level apart" % [cell, next])
	return true


func _test_hex_grid() -> bool:
	for cell: Vector2i in [Vector2i(4, 4), Vector2i(4, 5)]:
		for next in HexGrid.neighbors(cell):
			_check(HexGrid.distance(cell, next) == 1, "neighbor %s of %s is 1 step away" % [next, cell])
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(3, 0)) == 3, "distance along a row")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(1, 2)) == 2, "distance two steps SE")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(-1, 2)) == 2, "distance two steps SW")
	_check(HexGrid.distance(Vector2i(0, 0), Vector2i(0, 4)) == 4, "distance zigzag down")
	return true


func _test_environments() -> bool:
	var cells := MapBuilder.START_RECT
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


## Land can be added to a generated map, over and over, without the old land changing.
func _test_environment_growth() -> bool:
	var kept := 0
	var illegal := 0
	var missing := 0
	var elapsed := 0
	var seeds := 0
	for env_seed in range(1, 21):
		var envs := EnvironmentGenerator.generate(MapBuilder.START_RECT, env_seed)
		var before := envs.duplicate()
		var rect := MapBuilder.START_RECT
		# Two steps east, then one north: the sides grow one after another, as the player wanders.
		for growth: Rect2i in [rect.grow_individual(0, 0, 10, 0), rect.grow_individual(0, 0, 20, 0),
				rect.grow_individual(0, 5, 20, 0)]:
			var start := Time.get_ticks_msec()
			EnvironmentGenerator.extend(envs, growth, hash([env_seed, growth]))
			elapsed += Time.get_ticks_msec() - start
			rect = growth
		seeds += 1

		for cell: Vector2i in before:
			if envs[cell] == before[cell]:
				kept += 1
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell := Vector2i(x, y)
				if not envs.has(cell):
					missing += 1
					continue
				for next in HexGrid.neighbors(cell):
					if envs.has(next) and not EnvironmentGenerator.can_border(envs[cell], envs[next]):
						illegal += 1
		# The same growth, from the same map, has to come out the same.
		var again := before.duplicate()
		EnvironmentGenerator.extend(again, MapBuilder.START_RECT.grow_individual(0, 0, 10, 0), hash([env_seed, MapBuilder.START_RECT.grow_individual(0, 0, 10, 0)]))
		var repeats := true
		for cell: Vector2i in again:
			if envs[cell] != again[cell]:
				repeats = false
		_check(repeats, "seed %d grows the same way twice" % env_seed)

	print("Environment growth over %d maps: 220 -> %d cells, %d ms total" % [
			seeds, (MapBuilder.START_RECT.grow_individual(0, 5, 20, 0)).get_area(), elapsed])
	_check(kept == 220 * seeds, "growing the map never changes the land already there (%d of %d kept)" % [kept, 220 * seeds])
	_check(missing == 0, "every cell of the grown map has an environment (%d missing)" % missing)
	_check(illegal == 0, "every neighbor pair is one the sprites allow (%d bad)" % illegal)
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

	_check(_test_chests(map, view) == true, "chest tests ran to the end")
	_check(_test_start_state(map, view) == true, "starting state tests ran to the end")
	_check(_test_charting(map, view) == true, "charting tests ran to the end")
	_check(_test_tile_names(view, world) == true, "tile name tests ran to the end")
	_check(_test_blends_stay(map, view) == true, "blend stability tests ran to the end")
	_check(_test_drawn_window(map, view, world, origin, env_seed, start_town, build_ms) == true,
			"drawn window tests ran to the end")
	_check(_test_start_town(map, world, origin, start_town) == true, "first town tests ran to the end")
	_check(_test_growth(map, view) == true, "map growth tests ran to the end")
	_check(_test_area_variants(view, world) == true, "backdrop variant tests ran to the end")
	_check(view.nearest_chest() == HexMap.NO_CELL, "a map charted end to end has no chest left")

	map.queue_free()
	return true


## Chests sit on open land away from the start, are drawn once seen, and go once the tile is charted.
func _test_chests(map: HexMap, view: MapBuilder) -> bool:
	var chests := 0
	for cell in view.to_save().envs:
		if not view.has_chest(cell):
			continue
		chests += 1
		_check(not view.towns.has_town(view.origin + cell), "no chest on a town")
		_check(HexGrid.distance(MapBuilder.CENTER, cell) >= MapBuilder.CHEST_MIN_DISTANCE, "no chest by the start")
	_check(chests > 0, "the map has chests (%d)" % chests)
	var nearest := view.nearest_chest()
	_check(nearest != HexMap.NO_CELL and view.has_chest(nearest), "the nearest chest is a chest")
	for chest in map.chests.get_children():
		_check(view.seen(map.ground_layer.local_to_map(chest.position)), "only a seen chest is drawn")
	# A folder Godot does not import loads as nothing and only logs it: the chest drew invisible.
	_check(load(MapBuilder.CHEST_TEXTURE) is Texture2D, "the chest's picture loads")
	return true


## A tile is named when the player first lays eyes on it, and never again. The three things that
## have to hold: only seen tiles are named, a name is the same every time it is asked for, and it is
## the name the tables give for that cell.
func _test_tile_names(view: MapBuilder, world: TownWorld) -> bool:
	var named: Dictionary = view.to_save().names
	var seen := 0
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			if view.seen(Vector2i(x, y)):
				seen += 1
	_check(seen > 0 and named.size() == seen,
			"every tile the player has seen is named, and only those (%d of %d)"
			% [named.size(), seen])

	for cell: Vector2i in named:
		var place: String = view.name_of(cell)
		_check(not place.is_empty(), "%s has a name" % cell)
		_check(place.split(" ").size() == 2, "%s is named in two words (%s)" % [cell, place])
		_check(view.name_of(cell) == place, "%s is called the same thing when asked again" % cell)
		var tier := world.tier_at(view.origin + cell)
		var tier_name: String = TownWorld.TIER_NAMES[tier] if tier != -1 else ""
		_check(place == TileNames.generate(cell, view.env_at(cell), view.env_seed, tier_name),
				"%s carries the name its cell and its seed give (%s)" % [cell, place])
		# The second word says what the place is: a settlement is named for the people on it and
		# open land for the ground.
		_check(TileNames.features_for(view.env_at(cell), tier_name).has(place.split(" ")[1]),
				"%s is called after what is on it (%s)" % [cell, place])

	# Nothing is named before it is looked at. A cell still in the fog of war has no name, and the
	# tiles a charting lifts the fog off are named as they appear -- uncharted land is land the
	# player can see, so seeing it is the encounter, not walking onto it.
	var hidden := Vector2i.ZERO
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			var cell := Vector2i(x, y)
			if not view.seen(cell) and view.env_at(cell) != "":
				hidden = cell
				break
	_check(hidden != Vector2i.ZERO and not named.has(hidden),
			"%s is nameless while it is still in the fog" % hidden)

	for cell in HexGrid.neighbors(view.player_cell):
		if not view.can_chart(cell):
			continue
		view.chart(cell)
		view.map.player.finish_walk()
		var after: Dictionary = view.to_save().names
		var shown := 0
		for y in range(view.rect.position.y, view.rect.end.y):
			for x in range(view.rect.position.x, view.rect.end.x):
				if view.seen(Vector2i(x, y)):
					shown += 1
		_check(after.size() == shown and shown > seen,
				"charting %s names everything it brought into view (%d of %d)"
				% [cell, after.size(), shown])
		break
	return true


## Which backdrop a tile fights on. A town is what the player sees whether or not a road reaches it,
## so a town cell never reports its road; everything else is a road or open country.
func _test_area_variants(view: MapBuilder, world: TownWorld) -> bool:
	const TIER_VARIANT := {
		TownWorld.Tier.SMALL: "village",
		TownWorld.Tier.MEDIUM: "town",
		TownWorld.Tier.FORTRESS: "fortress",
	}
	var seen: Dictionary[String, int] = {}
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			var cell := Vector2i(x, y)
			var variant := view.area_variant(cell)
			seen[variant] = seen.get(variant, 0) + 1
			var tier := world.tier_at(view.origin + cell)
			if tier in TIER_VARIANT:
				_check(variant == TIER_VARIANT[tier], "%s holds a %s" % [cell, TIER_VARIANT[tier]])
			elif view.road_at(cell) != 0:
				_check(variant == "road", "%s carries a road" % cell)
			else:
				_check(variant == "plain", "%s is open country" % cell)
	# The starting window always has a town on its ring and a road running to the centre, so two of
	# the five are guaranteed; a window of nothing but plains would mean the variants never fire.
	_check(seen.get("plain", 0) > 0, "the window has open country")
	_check(seen.get("road", 0) > 0, "the window has road tiles")
	_check(seen.get("village", 0) > 0, "the window has the starting village")
	return true


## The window as the player first sees it.
func _test_start_state(map: HexMap, view: MapBuilder) -> bool:
	# The start is a hexagon of 7 tiles: the charted center, ringed by uncharted land under the fog.
	var start_tiles := MapBuilder.start_cells()
	var rows := {}
	for cell: Vector2i in start_tiles:
		rows[cell.y] = rows.get(cell.y, 0) + 1
	_check(start_tiles.size() == 7 and rows.get(-1) == 2 and rows.get(0) == 3 and rows.get(1) == 2,
			"the start is a hexagon in rows of 2, 3, 2 (got %s)" % [rows])
	_check(start_tiles.all(func(cell: Vector2i) -> bool: return HexGrid.distance(MapBuilder.CENTER, cell) <= 1),
			"every starting tile is the center or touches it")
	_check(map.ground_layer.get_used_cells().size() == start_tiles.size(), "only the 7 starting tiles are drawn")
	_check(view.state(MapBuilder.CENTER) == MapBuilder.State.CHARTED, "the center is charted")
	_check(view.state(Vector2i(4, 0)) == MapBuilder.State.HIDDEN, "the rest of the map is in the fog")
	for cell in HexGrid.neighbors(MapBuilder.CENTER):
		_check(view.state(cell) == MapBuilder.State.UNCHARTED, "%s starts uncharted" % cell)
		_check(map.fog.has_cell(cell), "%s is greyed out" % cell)
	_check(not map.fog.has_cell(MapBuilder.CENTER) and map.fog.cells().size() == 6, "only uncharted tiles are greyed")
	return true


## Reaching new land: what may be charted, what may be walked to, and what each does.
func _test_charting(map: HexMap, view: MapBuilder) -> bool:
	var start_tiles := MapBuilder.start_cells()
	# Tiles have to be charted before the player can go there, and only next to a tile already charted.
	var arrivals: Array[Vector2i] = []
	view.arrived.connect(func(at: Vector2i) -> void: arrivals.append(at))
	_check(view.player_cell == MapBuilder.CENTER and map.player.cell == MapBuilder.CENTER, "the player starts on the center")
	_check(not view.can_move_to(MapBuilder.CENTER) and view.route_to(MapBuilder.CENTER).is_empty(),
			"there is nowhere to walk on the tile they stand on")
	_check(not view.can_chart(MapBuilder.CENTER) and view.chart(MapBuilder.CENTER) == -1,
			"the tile they stand on is charted already")
	_check(not view.can_chart(Vector2i(4, 0)) and view.chart(Vector2i(4, 0)) == -1, "fog can't be charted")

	var rim := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	var beyond := HexGrid.neighbor(rim, HexGrid.Edge.E)
	_check(not view.can_move_to(rim) and not view.move_to(rim), "an uncharted tile can't be walked to yet")
	_check(not view.can_chart(beyond), "a tile two steps out is out of reach")
	var expected_new := HexGrid.neighbors(rim).filter(func(next: Vector2i) -> bool:
			return view.rect.has_point(next) and not view.seen(next)).size()
	_check(view.can_chart(rim) and expected_new > 0, "the tile next to the player can be charted")
	_check(view.chart(rim) == expected_new, "charting it lifts the fog off the tiles behind it")
	_check(view.state(rim) == MapBuilder.State.CHARTED and not map.fog.has_cell(rim), "the tile is charted and clear")
	_check(map.ground_layer.get_used_cells().size() == start_tiles.size() + expected_new, "the newly shown tiles are drawn")
	for next in HexGrid.neighbors(rim):
		_check(view.state(next) != MapBuilder.State.HIDDEN, "%s is out of the fog" % next)
		_check(view.charted(next) or map.fog.has_cell(next), "%s is charted or greyed" % next)

	# Charting sends the player walking onto the tile by itself.
	_check(view.walking and view.player_cell == MapBuilder.CENTER,
			"the player sets off, and counts as standing where they were until they arrive")
	_check(arrivals.is_empty() and not view.can_chart(HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.W)),
			"nothing can be charted while they are on the way")
	_check(not view.can_move_to(MapBuilder.CENTER), "they can't be sent somewhere else mid-walk")
	map.player.finish_walk()
	_check(view.player_cell == rim and map.player.cell == rim, "arriving puts the player on the tile")
	_check(arrivals == ([rim] as Array[Vector2i]), "arriving is reported")
	_check(map.ground_layer.get_used_cells().size() == start_tiles.size() + expected_new, "arriving charts nothing by itself")

	# A tile beside any charted tile can be charted; the player starts from the nearest one.
	var far_side := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.W)
	_check(view.can_chart(far_side) and view.chart_from(far_side) == MapBuilder.CENTER,
			"a tile away from the player can be charted, from the charted tile beside it")
	_check(view.chart_from(beyond) == rim, "a tile next to the player is charted from where they stand")

	# Walking back is not limited to neighbors, but every tile of the route has to be charted.
	_check(view.can_chart(beyond) and view.chart(beyond) >= 0, "the next tile out can be charted from there")
	map.player.finish_walk()
	_check(view.player_cell == beyond, "and walked to in turn")
	_check(HexGrid.distance(MapBuilder.CENTER, beyond) == 2, "%s is two steps from the center" % beyond)
	var route := view.route_to(MapBuilder.CENTER)
	_check(route.size() == 2 and route.back() == MapBuilder.CENTER,
			"the route back is as short as the distance and ends on the destination")
	_check(route.all(func(cell: Vector2i) -> bool: return view.charted(cell)), "every tile of the route is charted")
	var walked := beyond
	for step: Vector2i in route:
		_check(HexGrid.distance(walked, step) == 1, "%s is next to %s" % [step, walked])
		walked = step
	_check(not view.move_to(MapBuilder.CENTER).is_empty(), "the walk back to the center starts")
	map.player.finish_walk()
	_check(view.player_cell == MapBuilder.CENTER, "the player walks the whole route")
	return true


## How far a charted tile sees: one ring for a player carrying nothing, `sight` rings with a torch in
## hand. On its own map, because it needs land nobody has looked at yet on every side of the tile it
## takes; any origin will do, since the fog has nothing to do with what is on the ground.
func _test_sight() -> bool:
	var map: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(map)
	var world := TownWorld.generate(WORLD_SEED)
	var view := MapBuilder.create(map, world, Vector2i(128, 128), 99)

	# Bare-handed: the six tiles behind the one being taken, and nothing a step further out.
	var rim := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	var ring := _unseen_within(view, rim, 1)
	var second := _unseen_within(view, rim, 2)
	_check(second.size() > ring.size(), "there is unseen land two steps behind %s to find at all" % rim)
	_check(view.chart(rim) == ring.size(), "charting with no torch shows the first ring (%d)" % ring.size())
	map.player.finish_walk()
	for cell in ring:
		_check(view.state(cell) == MapBuilder.State.UNCHARTED, "%s came out of the fog" % cell)
	for cell in second:
		_check(cell in ring or view.state(cell) == MapBuilder.State.HIDDEN,
				"%s is two steps out and stays in the fog" % cell)

	# A torch: every generated tile the player has not seen within its sight, and still nothing beyond.
	var beyond := HexGrid.neighbor(rim, HexGrid.Edge.E)
	var near := _unseen_within(view, beyond, 1)
	var far := _unseen_within(view, beyond, 2)
	var farther := _unseen_within(view, beyond, 3)
	_check(far.size() > near.size() and farther.size() > far.size(),
			"there is unseen land at two and three steps from %s" % beyond)
	# What the player already knows must survive the torch: _show on a seen tile would put a charted
	# one back under the veil, and a second lifting must not be counted twice either.
	var known := {}
	for cell in _cells_within(beyond, 3):
		if view.seen(cell) and cell != beyond:
			known[cell] = view.state(cell)
	_check(known.values().has(MapBuilder.State.CHARTED) and known.values().has(MapBuilder.State.UNCHARTED),
			"the torch's reach covers tiles that are already charted and already seen")
	_check(view.chart(beyond, 2) == far.size(), "a sight of 2 shows every unseen tile within two steps (%d)" % far.size())
	map.player.finish_walk()
	for cell in far:
		_check(view.state(cell) == MapBuilder.State.UNCHARTED, "%s is out of the fog two steps away" % cell)
	for cell in farther:
		_check(cell in far or view.state(cell) == MapBuilder.State.HIDDEN,
				"%s is three steps out and stays in the fog" % cell)
	for cell: Vector2i in known:
		_check(view.state(cell) == known[cell], "%s kept what the player knew about it" % cell)

	# Seen is not taken: the fog is off the far ring, but charting still only ever grows outward from
	# a tile already charted, so those tiles are somewhere to head for rather than somewhere to take.
	var outer := HexMap.NO_CELL
	for cell: Vector2i in far:
		if HexGrid.distance(beyond, cell) == 2 and view.chart_from(cell) == HexMap.NO_CELL:
			outer = cell
			break
	_check(outer != HexMap.NO_CELL, "the torch showed a tile with no charted tile beside it")
	_check(view.state(outer) == MapBuilder.State.UNCHARTED and not view.can_chart(outer),
			"%s can be looked at but not charted until something beside it is" % outer)

	# A tile the torch found is a tile the player has met: it is named as it appears, and the name and
	# the fog over it both come back off the save like any other tile's.
	var save := view.to_save()
	_check(save.names.has(outer) and view.name_of(outer) == save.names[outer],
			"%s was named the moment the torch found it (%s)" % [outer, view.name_of(outer)])
	var other: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(other)
	var restored := MapBuilder.restore(other, TownWorld.from_dict(save.towns), save)
	_check(restored.state(outer) == MapBuilder.State.UNCHARTED and other.fog.has_cell(outer),
			"%s comes back out of the save still under the veil" % outer)
	_check(restored.name_of(outer) == view.name_of(outer), "and still called what it was called")

	# A sight of 0 is a sight of 1: nobody is blinded by carrying nothing.
	var next_out := HexGrid.neighbor(beyond, HexGrid.Edge.E)
	var next_ring := _unseen_within(view, next_out, 1)
	_check(view.can_chart(next_out) and view.chart(next_out, 0) == next_ring.size(),
			"a sight under 1 charts as an empty hand does (%d)" % next_ring.size())
	map.player.finish_walk()

	map.queue_free()
	other.queue_free()
	return true


## Every cell within `steps` of `cell`, spelled out here rather than asked of the map, so the test
## measures the reveal against the grid itself.
func _cells_within(cell: Vector2i, steps: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(cell.y - steps, cell.y + steps + 1):
		for x in range(cell.x - steps, cell.x + steps + 1):
			if HexGrid.distance(cell, Vector2i(x, y)) <= steps:
				cells.append(Vector2i(x, y))
	return cells


## Of those, the ones a chart could show: land the map has generated that the player has not seen.
func _unseen_within(view: MapBuilder, cell: Vector2i, steps: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for near in _cells_within(cell, steps):
		if view.env_at(near) != "" and not view.seen(near):
			cells.append(near)
	return cells


func _test_blends_stay(map: HexMap, view: MapBuilder) -> bool:
	# A tile must be drawn with the blends of all its neighbors, charted or not, so what is on screen never
	# changes as the land around it is found.
	var blends_when_found := {}
	var blended_when_found := 0
	for cell: Vector2i in map.ground_layer.get_used_cells():
		blends_when_found[cell] = map.blends_at(cell)
		if not blends_when_found[cell].is_empty():
			blended_when_found += 1

	view.reveal_all()
	_check(map.fog.cells().is_empty(), "revealing the map takes the fog off every tile")
	for cell: Vector2i in blends_when_found:
		_check(map.blends_at(cell) == blends_when_found[cell],
				"%s keeps its blends once its neighbors are charted (%s, was %s)" % [
						cell, map.blends_at(cell), blends_when_found[cell]])
	print("Blends kept on %d of %d tiles drawn before their neighbors" % [
			blended_when_found, blends_when_found.size()])
	return true


## Everything the builder drew, checked against the same window worked out here from scratch.
func _test_drawn_window(map: HexMap, view: MapBuilder, world: TownWorld, origin: Vector2i, env_seed: int,
		start_town: Vector2i, build_ms: int) -> bool:
	var tileset := map.tileset
	var start := 0
	# The same land and roads, worked out here from scratch, in the order the builder lays them.
	var envs := EnvironmentGenerator.generate(MapBuilder.START_RECT, hash([env_seed, MapBuilder.START_RECT]))
	var roads := _expected_roads(tileset, world, origin, start_town)
	_check(view.rect == MapBuilder.START_RECT, "the map is still the one it started with")

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
			for edge in HexGrid.EDGES:
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
				tileset.road_material_for(envs[cell]), HexGrid.mask_edges(mask))
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
	return true


func _test_start_town(map: HexMap, world: TownWorld, origin: Vector2i, start_town: Vector2i) -> bool:
	var roads := _expected_roads(map.tileset, world, origin, start_town)
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
		_check(drawn.begins_with("town_") and drawn.ends_with("_small"),
				"the guaranteed town is drawn as a small town (got %s)" % drawn)
	return true


## The map grows as the player nears its edge, and none of the land behind them changes.
func _test_growth(map: HexMap, view: MapBuilder) -> bool:
	var before: Dictionary[Vector2i, Array] = {}
	for cell: Vector2i in map.ground_layer.get_used_cells():
		var info := map.get_tile_info(cell)
		before[cell] = [view.env_at(cell), info["name"], info["road"]]
	var was := view.rect
	var toward_edge := Vector2i(was.end.x - MapBuilder.EXPAND_MARGIN, 0)
	_check(view.charted(toward_edge) and not view.move_to(toward_edge).is_empty(),
			"the player sets off for the eastern edge")
	var grow_start := Time.get_ticks_msec()
	map.player.finish_walk()
	var grow_ms := Time.get_ticks_msec() - grow_start
	_check(view.rect.end.x == was.end.x + MapBuilder.EXPAND_BY.x, "the map has grown east")
	_check(view.rect.position == was.position and view.rect.end.y == was.end.y, "and only east")

	var changed := 0
	for cell: Vector2i in before:
		var info := map.get_tile_info(cell)
		if [view.env_at(cell), info["name"], info["road"]] != before[cell]:
			changed += 1
	_check(changed == 0, "the land the player has seen is untouched by the growth (%d changed)" % changed)

	var ungenerated := 0
	var illegal_border := 0
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			var cell := Vector2i(x, y)
			var env := view.env_at(cell)
			if env == "":
				ungenerated += 1
				continue
			for next in HexGrid.neighbors(cell):
				var other := view.env_at(next)
				if other != "" and not EnvironmentGenerator.can_border(env, other):
					illegal_border += 1
	_check(ungenerated == 0, "every cell of the grown map has an environment (%d missing)" % ungenerated)
	_check(illegal_border == 0, "the new land borders the old legally (%d bad borders)" % illegal_border)

	# The new land is drawn like any other once it is charted, roads and all.
	var beyond_old := Vector2i(was.end.x, 0)
	_check(view.state(beyond_old) == MapBuilder.State.HIDDEN, "the new land starts in the fog")
	view.reveal_all()
	_check(view.charted(beyond_old) and map.get_tile_info(beyond_old).get("group", "") != "",
			"and is drawn once revealed")
	print("Map grown from %s to %s (%d cells) in %d ms" % [was.size, view.rect.size, view.rect.get_area(), grow_ms])
	return true


## The roads of the starting window, routed here rather than read off the builder, in the order it lays them:
## the first town's road to the center cell, then the links the window brings into reach.
func _expected_roads(tileset: HexTileset, world: TownWorld, origin: Vector2i, start_town: Vector2i) -> Dictionary[Vector2i, int]:
	var roads: Dictionary[Vector2i, int] = {}
	var routed: Dictionary[String, bool] = {}
	RoadNetwork.route_to_cell(world, start_town, origin, tileset.legal_road_masks(), roads)
	RoadNetwork.extend(world, Rect2i(origin + MapBuilder.START_RECT.position, MapBuilder.START_RECT.size),
			tileset.legal_road_masks(), roads, routed)
	return roads


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
	var changed := 0
	for origin: Vector2i in [Vector2i(40, 40), Vector2i(90, 120), Vector2i(160, 60)]:
		var rect := Rect2i(origin + MapBuilder.START_RECT.position, MapBuilder.START_RECT.size)
		var stats := {}
		var roads: Dictionary[Vector2i, int] = {}
		var routed: Dictionary[String, bool] = {}
		var start := Time.get_ticks_msec()
		RoadNetwork.extend(world, rect, legal, roads, routed, stats)
		elapsed += Time.get_ticks_msec() - start
		road_tiles += roads.size()
		routes += stats.get("routes", 0)
		skipped += stats.get("skipped", 0)

		for spot in roads:
			if not legal.has(roads[spot]):
				illegal += 1
			if world.has_town(spot):
				on_towns += 1
			# Every edge of a road tile must meet another road or a town: routes run from town to town whole.
			for edge in HexGrid.mask_edges(roads[spot]):
				var other := HexGrid.neighbor(spot, edge)
				var joined: bool = roads.has(other) and (roads[other] & (1 << HexGrid.opposite(edge))) != 0
				if not (joined or world.has_town(other)):
					dangling += 1
		strays += _stray_road_groups(roads, world)
		unrouted += _unrouted_links(world, roads, rect)

		var again: Dictionary[Vector2i, int] = {}
		RoadNetwork.extend(world, rect, legal, again, {} as Dictionary[String, bool])
		_check(again == roads, "same world and rect give the same roads")

		# Growing the map only ever adds to the roads already laid, so nothing the player has seen moves.
		var grown := roads.duplicate()
		RoadNetwork.extend(world, rect.grow(10), legal, grown, routed, {})
		for spot: Vector2i in roads:
			if grown[spot] & roads[spot] != roads[spot]:
				changed += 1
		_check(grown.size() > roads.size(), "a bigger window brings more roads")

	print("Roads over 3 windows: %d routes (%d skipped), %d tiles, %d ms" % [routes, skipped, road_tiles, elapsed])
	_check(illegal == 0, "every road mask is a shape the sprites have (%d bad)" % illegal)
	_check(on_towns == 0, "no road on a town spot (%d)" % on_towns)
	_check(dangling == 0, "every road edge meets a road or a town (%d loose)" % dangling)
	_check(changed == 0, "growing the map never takes an edge off a road already laid (%d changed)" % changed)
	_check(strays == 0, "every road leads to a town (%d groups that don't)" % strays)
	_check(unrouted == 0, "linked towns in the window are joined by road (%d missing)" % unrouted)
	_check(routes > 0 and road_tiles > 0, "roads were built at all")
	return true


## Groups of connected road tiles that reach no town at all.
func _stray_road_groups(roads: Dictionary, world: TownWorld) -> int:
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
			for edge in HexGrid.mask_edges(roads[spot]):
				var other := HexGrid.neighbor(spot, edge)
				if world.has_town(other):
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
	for edge in HexGrid.EDGES:
		var cell := HexGrid.neighbor(from_town, edge)
		if roads.has(cell) and (roads[cell] & (1 << HexGrid.opposite(edge))) != 0:
			seen[cell] = true
			queue.append(cell)
	var i := 0
	while i < queue.size():
		var spot := queue[i]
		i += 1
		for edge in HexGrid.mask_edges(roads[spot]):
			var other := HexGrid.neighbor(spot, edge)
			if other == to_town:
				return true
			if roads.has(other) and not seen.has(other) and (roads[other] & (1 << HexGrid.opposite(edge))) != 0:
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



## The map on disk: written, read back and drawn again exactly as it was. Nothing on the map may
## change -- not the land, not the roads, not the settlements, not the fog -- so the round trip is
## checked cell by cell rather than by spot checks, and every refusal is checked to leave the file
## alone.
func _test_map_saving() -> bool:
	_clear_map_save()
	var map: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(map)
	var world := TownWorld.generate(WORLD_SEED)
	var town: Vector2i = world.towns().filter(func(spot: Vector2i) -> bool:
			return spot.x > 20 and spot.y > 20 and spot.x < 230 and spot.y < 230)[0]
	var origin := Vector2i(town.x, town.y & ~1)
	var view := MapBuilder.create(map, world, origin, 99)

	# Walk somewhere, so the save holds a half-explored map rather than the seven starting tiles.
	for step in 6:
		var ahead := Vector2i(view.player_cell.x + 1, 0)
		if view.can_chart(ahead):
			view.chart(ahead)
			map.player.finish_walk()
	_check(view.player_cell != MapBuilder.CENTER, "the player has walked off the middle of the map")
	_check(view.rect != MapBuilder.START_RECT, "and far enough that the window has already grown once")

	var before := _map_fingerprint(map, view)
	_check(view.to_save().save(TEST_MAP_PATH), "the map writes itself to disk")

	var problem: Array = []
	var save := MapSave.load_from(TEST_MAP_PATH, problem, MapSave.fingerprint(map.tileset))
	_check(save != null and problem.is_empty(), "and reads back without complaint")
	if save == null:
		map.queue_free()
		return true

	# A fresh HexMap, so nothing of the first drawing can be left standing behind the second.
	var other: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(other)
	var restored := MapBuilder.restore(other, TownWorld.from_dict(save.towns), save)
	_check(restored.rect == view.rect, "the restored map covers the same window")
	_check(restored.player_cell == view.player_cell, "with the player where they were left")
	_check(restored.start_town == view.start_town, "and the same first town")
	_check(_map_fingerprint(other, restored) == before, "and every cell of it comes back identical")
	# Cell by cell over the window says nothing about cells outside it, and the bulk draw writes
	# straight to the layers rather than through _show's guard.
	_check(other.ground_layer.get_used_cells().size() == map.ground_layer.get_used_cells().size(),
			"with nothing drawn that was not drawn before (%d vs %d)"
			% [other.ground_layer.get_used_cells().size(), map.ground_layer.get_used_cells().size()])
	_check(other.road_layer.get_used_cells().size() == map.road_layer.get_used_cells().size(),
			"and the same roads on it")
	var fog_before := map.fog.cells()
	var fog_after := other.fog.cells()
	fog_before.sort()
	fog_after.sort()
	_check(fog_before == fog_after, "the fog lies over exactly the tiles it did (%d vs %d)"
			% [fog_before.size(), fog_after.size()])

	# Names come out of the save rather than being worked out again, which is the whole reason they
	# are written down: the tables could change under a player and the place must not be renamed.
	var kept := 0
	for cell: Vector2i in view.to_save().names:
		kept += 1
		_check(restored.name_of(cell) == view.name_of(cell),
				"%s comes back as %s" % [cell, view.name_of(cell)])
	_check(kept > 0, "the save carried names at all (%d)" % kept)

	_check(_test_saved_settlements(restored, view) == true, "saved settlement tests ran to the end")
	_check(_test_restored_growth(other, restored, before) == true, "restored growth tests ran to the end")
	_check(_test_save_refusals(map) == true, "save refusal tests ran to the end")

	# The legend the state rows are written through has to line up with the enum it spells, or a
	# save reads its own fog back as something else.
	_check(MapSave.STATE_NAMES.size() == MapBuilder.State.size(),
			"every state has a name in the save's legend")
	for state_name: String in MapBuilder.State:
		_check(MapSave.STATE_NAMES[MapBuilder.State[state_name]] == state_name.to_lower(),
				"%s sits at its own value in the legend" % state_name)

	map.queue_free()
	other.queue_free()
	_clear_map_save()
	return true


## Everything about one cell that a save has to bring back, for every cell of the window: what the
## land is, what is drawn on it, what the player knows about it, and what it would fight on.
func _map_fingerprint(map: HexMap, view: MapBuilder) -> Dictionary:
	var fingerprint := {}
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			var cell := Vector2i(x, y)
			var info := map.get_tile_info(cell)
			fingerprint[cell] = [view.state(cell), view.env_at(cell), view.road_at(cell),
					view.area_variant(cell), info.get("name", ""), info.get("road", ""),
					info.get("blends", [])]
	return fingerprint


## The settlements come out of the save, not out of a seed. Restoring against a town world built
## from a different seed must change nothing: if it did, the towns would be being regenerated.
func _test_saved_settlements(restored: MapBuilder, view: MapBuilder) -> bool:
	var moved := 0
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			var spot := view.origin + Vector2i(x, y)
			if restored.towns.tier_at(spot) != view.towns.tier_at(spot):
				moved += 1
	_check(moved == 0, "every settlement in the window came back where it was (%d moved)" % moved)

	# And the world itself survives a round trip whole, links and all, in both directions.
	var world := TownWorld.generate(WORLD_SEED + 1)
	var copy := TownWorld.from_dict(world.to_dict())
	_check(copy != null and copy.towns().size() == world.towns().size(),
			"a town world round trips with all of its towns")
	var wrong_tier := 0
	var wrong_links := 0
	for spot in world.towns():
		if copy.tier_at(spot) != world.tier_at(spot):
			wrong_tier += 1
		var was := world.connections(spot)
		var now := copy.connections(spot)
		was.sort()
		now.sort()
		if was != now:
			wrong_links += 1
		for other in was:
			if not copy.are_connected(other, spot):
				wrong_links += 1  # A link is symmetric, and both halves have to come back.
	_check(wrong_tier == 0, "every town keeps its tier (%d wrong)" % wrong_tier)
	_check(wrong_links == 0, "and its links, both ways round (%d wrong)" % wrong_links)
	return true


## A restored map is a working map: it still grows, and the growth still leaves what the player has
## already seen alone.
func _test_restored_growth(map: HexMap, view: MapBuilder, before: Dictionary) -> bool:
	var was := view.rect
	view.reveal_all()
	var toward_edge := Vector2i(was.end.x - MapBuilder.EXPAND_MARGIN, 0)
	_check(not view.move_to(toward_edge).is_empty(), "the restored map sends the player east")
	map.player.finish_walk()
	_check(view.rect.end.x > was.end.x, "and grows when they get near the edge")

	var changed := 0
	for cell: Vector2i in before:
		if before[cell][1] != view.env_at(cell) or before[cell][2] != view.road_at(cell):
			changed += 1
	_check(changed == 0, "the land it was restored with is untouched by the growth (%d changed)" % changed)

	var ungenerated := 0
	for y in range(view.rect.position.y, view.rect.end.y):
		for x in range(view.rect.position.x, view.rect.end.x):
			if view.env_at(Vector2i(x, y)) == "":
				ungenerated += 1
	_check(ungenerated == 0, "and the new land is generated like any other (%d missing)" % ungenerated)
	return true


## A save that cannot be honoured is refused, and -- the half that matters -- is left on disk
## exactly as it was. Overwriting is how a save gets eaten, and the build that wrote it can still
## read it.
func _test_save_refusals(map: HexMap) -> bool:
	var problem: Array = []
	var sheet := MapSave.fingerprint(map.tileset)
	var good := FileAccess.get_file_as_string(TEST_MAP_PATH)
	_clear_map_save()
	_check(MapSave.load_from(TEST_MAP_PATH, problem, sheet) == null and problem.is_empty(),
			"no file at all is a first run, not a refusal")

	for bad: Array in [
			["{ not a save file at all", "a file that is not JSON"],
			["{\"version\": 99}", "a save from a newer build"],
			["{\"version\": 1, \"sheet\": \"%s\"}" % sheet, "a save with no window"],
			[good.replace(sheet, "0" + sheet.substr(1)), "a save drawn with other tiles"]]:
		var file := FileAccess.open(TEST_MAP_PATH, FileAccess.WRITE)
		file.store_string(str(bad[0]))
		file.close()
		problem = []
		_check(MapSave.load_from(TEST_MAP_PATH, problem, sheet) == null and not problem.is_empty(),
				"%s is refused" % bad[1])
		_check(FileAccess.get_file_as_string(TEST_MAP_PATH) == str(bad[0]),
				"and left on disk untouched")
	_clear_map_save()
	return true


## Cleared at the *start* of what uses them as well as the end: the scene writes its map from
## _exit_tree, which fires as the tree comes down, so a run always leaves one behind and only the
## next run starting clean can be relied on.
func _clear_map_save() -> void:
	for path in [TEST_MAP_PATH, SCRATCH_INVENTORY]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The whole way round, through the scene that owns the save: play a little, close the game, open it
## again, and find the same map. The round trip above checks MapBuilder and MapSave against each
## other; this checks the wiring between them -- that _exit_tree writes, that _ready reads, and that
## the seed guard lets a save of the world it asks for through.
func _test_the_map_comes_back() -> bool:
	_clear_map_save()
	var main: Node = _open_game()
	for i in 3:
		await process_frame

	# Take a tile, which is what a session of this game consists of.
	var taken := Vector2i(1, 0)
	main.view.chart(taken)
	main.map.player.finish_walk()
	await process_frame
	var before := _map_fingerprint(main.map, main.view)
	var was_rect: Rect2i = main.view.rect
	_check(main.view.player_cell == taken, "the player took a tile before the game was closed")

	main.queue_free()  # _exit_tree writes the map.
	await process_frame
	_check(FileAccess.file_exists(TEST_MAP_PATH), "closing the game leaves a map on disk")

	var reopened: Node = _open_game()
	for i in 3:
		await process_frame
	_check(reopened.view.player_cell == taken, "reopening it stands the player back where they were")
	_check(reopened.view.rect == was_rect, "on a map covering the same window")
	_check(_map_fingerprint(reopened.map, reopened.view) == before, "with every cell of it unchanged")

	# And a seed asking for another world is a deliberate request, which wins over the save.
	reopened.queue_free()
	await process_frame
	var elsewhere: Node = _open_game(MapBuilder.CENTER.x + 4242)
	for i in 3:
		await process_frame
	_check(elsewhere.view.player_cell == MapBuilder.CENTER,
			"a different map seed starts that world instead of loading the save")
	elsewhere.queue_free()
	await process_frame
	_clear_map_save()

	# An inventory that cannot be read stops the game as a bad map does: nothing is generated, and
	# closing the window writes over neither file.
	var file := FileAccess.open(SCRATCH_INVENTORY, FileAccess.WRITE)
	file.store_string("{ not a save")
	file.close()
	var refused: Node = _open_game()
	for i in 3:
		await process_frame
	_check(refused.view == null, "a corrupt inventory builds no map")
	refused.queue_free()
	await process_frame
	_check(FileAccess.get_file_as_string(SCRATCH_INVENTORY) == "{ not a save", "and is left untouched")
	_check(not FileAccess.file_exists(TEST_MAP_PATH), "and no map is written beside it")
	_clear_map_save()
	return true


## The game as the player starts it, pointed away from their own two saves.
func _open_game(map_seed := 7) -> Node:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = map_seed
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	return main
