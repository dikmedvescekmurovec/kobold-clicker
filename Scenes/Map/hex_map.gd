class_name HexMap
extends Node2D
## Clickable hex map. Ground tiles (environments, towns) go on GroundLayer, blend overlays on one layer per
## spreading environment above it, and road overlays on RoadLayer.

signal tile_hovered(cell: Vector2i, info: Dictionary)
signal tile_clicked(cell: Vector2i, info: Dictionary)

const NO_CELL := Vector2i(-99999, -99999)

var tileset: HexTileset
var hovered_cell := NO_CELL
var selected_cell := NO_CELL
## Overlay layer of each environment that can spread onto lower-priority neighbors, lowest priority first.
var blend_layers: Dictionary[String, TileMapLayer] = {}

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var highlight: HexHighlight = $Highlight


func _ready() -> void:
	tileset = HexTileset.new()
	ground_layer.tile_set = tileset.tile_set
	road_layer.tile_set = tileset.tile_set
	# The lowest-priority environment never spreads, so it gets no layer. Each layer goes just below the roads.
	for env in tileset.blend_priority.slice(1):
		var layer := TileMapLayer.new()
		layer.name = "Blend_" + env
		layer.tile_set = tileset.tile_set
		add_child(layer)
		move_child(layer, road_layer.get_index())
		blend_layers[env] = layer
	highlight.setup(self)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(cell_at(get_global_mouse_position()))
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := cell_at(get_global_mouse_position())
		if has_tile(cell):
			select_cell(cell)
			get_viewport().set_input_as_handled()


## Sets the ground tile and redraws the blend overlays of the cell and its neighbors.
func set_ground(cell: Vector2i, tile_name: String) -> void:
	ground_layer.set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tile_name))
	var env := _env_at(cell)
	_refresh_blends(cell)
	for next in HexGrid.neighbors(cell):
		var next_env := _env_at(next)
		if env != "" and next_env != "" and not tileset.can_border(env, next_env):
			push_warning("%s at %s borders %s at %s, which env_adjacency doesn't allow" % [env, cell, next_env, next])
		_refresh_blends(next)


## Pass "" to remove the road from a cell.
func set_road(cell: Vector2i, tile_name: String) -> void:
	if tile_name.is_empty():
		road_layer.erase_cell(cell)
	else:
		road_layer.set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tile_name))


func clear_map() -> void:
	ground_layer.clear()
	road_layer.clear()
	for layer: TileMapLayer in blend_layers.values():
		layer.clear()
	hovered_cell = NO_CELL
	selected_cell = NO_CELL
	highlight.queue_redraw()


func has_tile(cell: Vector2i) -> bool:
	return ground_layer.get_cell_source_id(cell) != -1


## Cell under a point in global coordinates (e.g. the mouse).
func cell_at(global_point: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(global_point))


## The cell across the given HexGrid.Edge.
func neighbor(cell: Vector2i, edge: int) -> Vector2i:
	return HexGrid.neighbor(cell, edge)


## Names of the blend overlays drawn on a cell, lowest priority first.
func blends_at(cell: Vector2i) -> Array[String]:
	var result: Array[String] = []
	for env in blend_layers:
		var tile := blend_layers[env].get_cell_tile_data(cell)
		if tile:
			result.append(tile.get_custom_data("name"))
	return result


## Share of the cell's hex pixels that each environment visibly covers, largest first. Each pixel belongs to the
## highest-priority overlay that is opaque there, or to the ground. Empty if the cell has no tile.
func env_weights(cell: Vector2i) -> Dictionary[String, float]:
	var ground := ground_layer.get_cell_tile_data(cell)
	if ground == null:
		return {}
	var ground_env: String = ground.get_custom_data("env")
	var hex := tileset.opaque_mask(ground.get_custom_data("name"))
	var overlay_envs: Array[String] = []
	var overlay_masks: Array[PackedByteArray] = []
	for env in blend_layers:
		var tile := blend_layers[env].get_cell_tile_data(cell)
		if tile:
			overlay_envs.push_front(env)  # Highest priority first.
			overlay_masks.push_front(tileset.opaque_mask(tile.get_custom_data("name")))

	var counts: Dictionary[String, int] = {}
	var total := 0
	for i in hex.size():
		if hex[i] == 0:
			continue
		total += 1
		var owner := ground_env
		for j in overlay_masks.size():
			if overlay_masks[j][i]:
				owner = overlay_envs[j]
				break
		counts[owner] = counts.get(owner, 0) + 1

	var ordered := counts.keys()
	ordered.sort_custom(func(a: String, b: String) -> bool: return counts[a] > counts[b])
	var weights: Dictionary[String, float] = {}
	for env: String in ordered:
		weights[env] = float(counts[env]) / total
	return weights


## Tile name, group, env and kind of the ground, the road name ("" if none), the blend overlay names and the
## environment weights (see env_weights). Empty if the cell has no tile.
func get_tile_info(cell: Vector2i) -> Dictionary:
	var ground := ground_layer.get_cell_tile_data(cell)
	if ground == null:
		return {}
	var road := road_layer.get_cell_tile_data(cell)
	return {
		"cell": cell,
		"name": ground.get_custom_data("name"),
		"group": ground.get_custom_data("group"),
		"env": ground.get_custom_data("env"),
		"kind": ground.get_custom_data("kind"),
		"road": road.get_custom_data("name") if road else "",
		"blends": blends_at(cell),
		"environments": env_weights(cell),
	}


func select_cell(cell: Vector2i) -> void:
	selected_cell = cell
	highlight.queue_redraw()
	tile_clicked.emit(cell, get_tile_info(cell))


func _set_hovered(cell: Vector2i) -> void:
	if not has_tile(cell):
		cell = NO_CELL
	if cell == hovered_cell:
		return
	hovered_cell = cell
	highlight.queue_redraw()
	if cell != NO_CELL:
		tile_hovered.emit(cell, get_tile_info(cell))


func _env_at(cell: Vector2i) -> String:
	var ground := ground_layer.get_cell_tile_data(cell)
	return ground.get_custom_data("env") if ground else ""


## Redraws a cell's overlays per the JSON meta blend_rule: a non-town tile gets blend_<A>_<edges> for every
## neighboring environment A with a higher blend priority than its own.
func _refresh_blends(cell: Vector2i) -> void:
	for layer: TileMapLayer in blend_layers.values():
		layer.erase_cell(cell)
	var ground := ground_layer.get_cell_tile_data(cell)
	if ground == null or ground.get_custom_data("group") == "towns":
		return
	var rank := tileset.env_rank(ground.get_custom_data("env"))
	var edges_by_env: Dictionary[String, Array] = {}
	for edge in 6:
		var env := _env_at(HexGrid.neighbor(cell, edge))
		if env != "" and tileset.env_rank(env) > rank:
			if not edges_by_env.has(env):
				edges_by_env[env] = []
			edges_by_env[env].append(edge)
	for env in edges_by_env:
		blend_layers[env].set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tileset.blend_name(env, edges_by_env[env])))
