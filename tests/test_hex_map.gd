extends SceneTree
## Headless checks for the hex map. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_hex_map.gd

## Pixel offset to the neighbor across each HexGrid.Edge.
const EDGE_OFFSETS := [
	Vector2(56, 0), Vector2(28, 48), Vector2(-28, 48), Vector2(-56, 0), Vector2(-28, -48), Vector2(28, -48),
]

var _failures := 0


func _initialize() -> void:
	# The root only enters the tree after _initialize, so nodes added here would not get _ready yet.
	_run.call_deferred()


func _run() -> void:
	var map: HexMap = load("res://Scenes/Map/hex_map.tscn").instantiate()
	root.add_child(map)
	# A script error aborts a test function and makes it return null instead of true.
	_check(_test_tileset(map.tileset) == true, "tileset tests ran to the end")
	_check(_test_geometry(map) == true, "geometry tests ran to the end")
	_check(_test_roads(map.tileset) == true, "road tests ran to the end")
	_check(_test_blend_lookups(map.tileset) == true, "blend lookup tests ran to the end")
	_check(_test_map_api(map) == true, "map API tests ran to the end")
	_check(_test_blends_on_map(map) == true, "blend placement tests ran to the end")
	_check(_test_mouse(map) == true, "mouse tests ran to the end")
	if _failures == 0:
		print("All hex map tests passed")
	else:
		printerr("%d hex map check(s) failed" % _failures)
	quit(1 if _failures else 0)


func _test_tileset(tileset: HexTileset) -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(HexTileset.SHEET_JSON))
	var source := tileset.tile_set.get_source(HexTileset.SOURCE_ID) as TileSetAtlasSource
	_check(source.get_tiles_count() == data["tiles"].size(), "every JSON tile is in the atlas")
	_check(tileset.environments.size() == 6, "six environments")
	for entry: Dictionary in data["tiles"]:
		var coords := tileset.atlas_coords(entry["name"])
		_check(coords == Vector2i(int(entry["col"]), int(entry["row"])), "%s atlas coords" % entry["name"])
		if source.has_tile(coords):
			var tile := source.get_tile_data(coords, 0)
			_check(tile.get_custom_data("name") == entry["name"] and tile.get_custom_data("group") == entry["group"],
					"%s custom data" % entry["name"])
	return true


func _test_geometry(map: HexMap) -> bool:
	var layer := map.ground_layer
	var origin := layer.map_to_local(Vector2i.ZERO)
	_check(layer.map_to_local(Vector2i(1, 0)) - origin == Vector2(56, 0), "column step is 56")
	_check(layer.map_to_local(Vector2i(0, 1)) - origin == Vector2(28, 48), "odd rows shift 28, row step 48")
	_check(layer.map_to_local(Vector2i(0, 2)) - origin == Vector2(0, 96), "even rows line up")
	for cell: Vector2i in [Vector2i(2, 2), Vector2i(3, 3), Vector2i(-3, -1)]:
		var center := layer.map_to_local(cell)
		_check(map.cell_at(center) == cell, "center of %s maps to it" % [cell])
		for edge in 6:
			var neighbor := map.neighbor(cell, edge)
			_check(layer.map_to_local(neighbor) - center == EDGE_OFFSETS[edge],
					"edge %d of %s points at the right neighbor" % [edge, cell])
			_check(layer.get_neighbor_cell(cell, _godot_neighbor(edge)) == neighbor, "HexGrid matches Godot for edge %d of %s" % [edge, cell])
		# Just inside and just outside the NE slanted edge: midpoint (14, -24), outward normal along (16, -28).
		var edge_mid := center + Vector2(14, -24)
		var normal := Vector2(16, -28).normalized() * 2
		_check(map.cell_at(edge_mid - normal) == cell, "point inside NE edge of %s" % [cell])
		_check(map.cell_at(edge_mid + normal) == map.neighbor(cell, HexGrid.Edge.NE), "point outside NE edge of %s" % [cell])
	return true


func _test_roads(tileset: HexTileset) -> bool:
	_check(tileset._road_names.size() == 63, "all 63 road tiles indexed")
	_check(tileset.road_name("dirt", [HexGrid.Edge.E, HexGrid.Edge.W]) == "road_dirt_straight", "straight E-W")
	_check(tileset.road_name("dirt", [HexGrid.Edge.W, HexGrid.Edge.E]) == "road_dirt_straight", "edge order ignored")
	_check(tileset.road_name("dirt", [HexGrid.Edge.W]) == "road_dirt_stub_r3", "stub facing W")
	_check(tileset.road_name("stone", range(6)) == "road_stone_x6", "six-way crossing")
	_check(tileset.road_name("snow", [HexGrid.Edge.E, HexGrid.Edge.NE]) == "", "no sprite for a sharp turn")
	_check(tileset.road_material_for("ice") == "snow", "ice uses snow roads")

	# Edge masks: bit per HexGrid.Edge. 21 shapes exist, the same set for every material.
	var masks := tileset.legal_road_masks()
	_check(masks.size() == 21, "21 road shapes (got %d)" % masks.size())
	for mask: int in [0b000001, 0b001001, 0b000101, 0b010101, 0b110110, 0b111111]:
		_check(masks.has(mask), "shape %s exists (stub/straight/curve/y3/x4/x6)" % mask)
	for mask: int in [0, 0b000011, 0b111110]:
		_check(not masks.has(mask), "no sprite for shape %s (empty, 60 degree turn, five edges)" % mask)
	return true


func _test_blend_lookups(tileset: HexTileset) -> bool:
	_check(tileset._blend_names.size() == 315, "all 315 blend tiles indexed")
	_check(tileset.blend_name("forest", [HexGrid.Edge.E, HexGrid.Edge.SE]) == "blend_forest_E_SE", "blend name from edges")
	_check(tileset.blend_name("forest", [HexGrid.Edge.SE, HexGrid.Edge.E]) == "blend_forest_E_SE", "blend edge order ignored")
	_check(tileset.blend_name("dirt", [HexGrid.Edge.E]) == "", "dirt has no overlays")
	_check(tileset.env_rank("dirt") == 0 and tileset.env_rank("mountains") == 5, "blend priority ranks")
	_check(not tileset.can_border("ice", "desert") and tileset.can_border("ice", "mountains") and tileset.can_border("desert", "desert"),
			"adjacency from the JSON")

	var hex_pixels := _count(tileset.opaque_mask("env_grass_v1"))
	_check(hex_pixels > 56 * 64 * 0.7 and hex_pixels < 56 * 64, "environment tile mask is a hex (%d pixels)" % hex_pixels)
	for tile_name: String in ["env_desert_v2", "env_ice_accent", "env_mountains_v3"]:
		_check(_count(tileset.opaque_mask(tile_name)) == hex_pixels, "%s covers the same hex" % tile_name)
	var blend_pixels := _count(tileset.opaque_mask("blend_grass_E"))
	_check(blend_pixels > 0 and blend_pixels < hex_pixels, "blend mask covers part of the hex (%d pixels)" % blend_pixels)
	return true


func _test_map_api(map: HexMap) -> bool:
	var cell := Vector2i(3, 3)
	map.clear_map()
	map.set_ground(cell, "town_ice_fortress")
	map.set_road(cell, "road_snow_x6")
	var info := map.get_tile_info(cell)
	_check(info["name"] == "town_ice_fortress" and info["group"] == "towns" and info["env"] == "ice" and info["kind"] == "fortress",
			"ground info")
	_check(info["road"] == "road_snow_x6", "road info")
	_check(info["blends"].is_empty() and info["environments"] == {"ice": 1.0}, "lone town: no blends, all ice")
	map.set_road(cell, "")
	_check(map.get_tile_info(cell)["road"] == "", "road removed")
	_check(map.get_tile_info(Vector2i(-1, -1)).is_empty(), "no info outside the map")

	var clicked: Array[Dictionary] = []
	map.tile_clicked.connect(func(_cell: Vector2i, tile_info: Dictionary) -> void: clicked.append(tile_info))
	map.select_cell(cell)
	_check(map.selected_cell == cell and clicked.size() == 1 and clicked[0]["cell"] == cell,
			"selecting emits tile_clicked with the tile info")
	return true


func _test_blends_on_map(map: HexMap) -> bool:
	var tileset := map.tileset
	var center := Vector2i(5, 4)
	var east := HexGrid.neighbor(center, HexGrid.Edge.E)
	var west := HexGrid.neighbor(center, HexGrid.Edge.W)
	map.clear_map()
	map.set_ground(center, "env_dirt_v1")
	map.set_ground(east, "env_grass_v1")
	map.set_ground(west, "env_forest_v1")
	_check(_names(map.blends_at(center)) == "blend_grass_E,blend_forest_W", "dirt gets grass then forest overlays (got %s)" % _names(map.blends_at(center)))
	_check(map.blends_at(east).is_empty() and map.blends_at(west).is_empty(), "higher-priority neighbors get nothing from dirt")
	_check(map.env_weights(east) == {"grass": 1.0}, "a tile without overlays is all its own environment")

	var weights := map.env_weights(center)
	var keys := weights.keys()
	keys.sort()
	_check(keys == ["dirt", "forest", "grass"], "blended tile reports all three environments (got %s)" % [weights])
	_check(weights.values().all(func(weight: float) -> bool: return weight > 0.0), "every reported weight is above 0")
	_check(absf(_sum(weights.values()) - 1.0) < 0.000001, "weights sum to 1")

	map.set_ground(west, "env_dirt_v2")
	_check(_names(map.blends_at(center)) == "blend_grass_E", "replacing the forest removes its overlay")
	var hex_pixels := _count(tileset.opaque_mask("env_dirt_v1"))
	var expected_grass := float(_count(tileset.opaque_mask("blend_grass_E"))) / hex_pixels
	_check(absf(map.env_weights(center).get("grass", 0.0) - expected_grass) < 0.000001, "single overlay weight is its mask share")

	# A town never receives overlays, but its environment still spreads.
	map.set_ground(east, "town_forest_medium")
	map.set_ground(HexGrid.neighbor(east, HexGrid.Edge.E), "env_mountains_v1")
	_check(map.blends_at(east).is_empty() and map.env_weights(east) == {"forest": 1.0}, "town gets no overlays")
	_check(_names(map.blends_at(center)) == "blend_forest_E", "town's environment spreads onto its dirt neighbor")

	map.clear_map()
	_check(map.blend_layers.values().all(func(layer: TileMapLayer) -> bool: return layer.get_used_cells().is_empty()), "clear_map empties blend layers")
	_check(map.blend_layers.keys() == Array(tileset.blend_priority.slice(1)), "one blend layer per spreading environment, in priority order")
	return true


## A click selects the tile under it; a press that travels drags the map instead.
func _test_mouse(map: HexMap) -> bool:
	map.clear_map()
	var cells := HexGrid.neighbors(Vector2i.ZERO)
	cells.append(Vector2i.ZERO)
	for cell in cells:
		map.set_ground(cell, "env_grass_v1")
	var moves: Array[Vector2] = []
	map.dragged.connect(func(relative: Vector2) -> void: moves.append(relative))
	# This scene has no camera, so viewport positions are world positions.
	var center := map.ground_layer.map_to_local(Vector2i.ZERO)
	var east := map.ground_layer.map_to_local(Vector2i(1, 0))

	map.selected_cell = HexMap.NO_CELL
	map._unhandled_input(_mouse_button(center, true))
	_check(map.selected_cell == HexMap.NO_CELL, "pressing alone selects nothing")
	map._unhandled_input(_mouse_button(center, false))
	_check(map.selected_cell == Vector2i.ZERO and moves.is_empty(), "releasing without moving selects the tile")

	map.selected_cell = HexMap.NO_CELL
	map._unhandled_input(_mouse_button(center, true))
	map._unhandled_input(_mouse_motion(east, east - center))
	map._unhandled_input(_mouse_button(east, false))
	_check(moves.size() == 1 and moves[0] == east - center, "dragging reports the movement (got %s)" % [moves])
	_check(map.selected_cell == HexMap.NO_CELL, "a drag selects nothing")

	# A tiny wobble is still a click.
	map._unhandled_input(_mouse_button(center, true))
	map._unhandled_input(_mouse_motion(center + Vector2(2, 0), Vector2(2, 0)))
	map._unhandled_input(_mouse_button(center + Vector2(2, 0), false))
	_check(moves.size() == 1 and map.selected_cell == Vector2i.ZERO, "a wobble under the threshold still selects")
	return true


func _mouse_button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	return event


func _mouse_motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.relative = relative
	return event


func _count(mask: PackedByteArray) -> int:
	var total := 0
	for value in mask:
		total += value
	return total


func _sum(values: Array) -> float:
	var total := 0.0
	for value: float in values:
		total += value
	return total


func _names(names: Array[String]) -> String:
	return ",".join(PackedStringArray(names))


func _godot_neighbor(edge: int) -> TileSet.CellNeighbor:
	return [
		TileSet.CELL_NEIGHBOR_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_RIGHT_SIDE, TileSet.CELL_NEIGHBOR_BOTTOM_LEFT_SIDE,
		TileSet.CELL_NEIGHBOR_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_LEFT_SIDE, TileSet.CELL_NEIGHBOR_TOP_RIGHT_SIDE,
	][edge]


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)
