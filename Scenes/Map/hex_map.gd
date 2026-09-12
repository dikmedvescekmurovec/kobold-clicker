class_name HexMap
extends Node2D
## Clickable hex map. Ground tiles (environments, towns) go on GroundLayer, blend overlays on one layer per
## spreading environment above it, and road overlays on RoadLayer.

## Part of the node's public surface; nothing listens yet, the main scene only acts on clicks.
signal tile_hovered(cell: Vector2i, info: Dictionary)
signal tile_clicked(cell: Vector2i, info: Dictionary)
## Mouse movement, in screen pixels, while dragging the map. Whoever owns the camera moves it.
signal dragged(relative: Vector2)

const NO_CELL := Vector2i(-99999, -99999)
## A press that travels further than this many pixels drags the map instead of selecting a tile.
const DRAG_THRESHOLD := 6.0

var tileset: HexTileset
var hovered_cell := NO_CELL
var selected_cell := NO_CELL

## Environment of cells that aren't drawn yet, as a Callable taking a cell and returning an environment name
## ("" when there is none). Whoever generates the map sets it, so a tile can blend with land around it that the
## player hasn't discovered, and looks the same however late it is drawn.
var hidden_env := Callable()

var _press_at := Vector2.ZERO
var _pressing := false
var _dragging := false
## Overlay layer of each environment that can spread onto lower-priority neighbors, lowest priority first.
var blend_layers: Dictionary[String, TileMapLayer] = {}

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var highlight: HexHighlight = $Highlight

## Marker for the player's tile, and the grey veil over tiles that aren't discovered yet. Both are created
## here, so the scene file stays untouched while the editor has it open.
var player: PlayerToken
var fog: FogOverlay


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
	fog = FogOverlay.new()
	fog.name = "Fog"
	add_child(fog)
	move_child(fog, highlight.get_index())  # Over the terrain and roads, under the outlines.
	fog.setup(self)
	player = PlayerToken.new()
	player.name = "Player"
	add_child(player)  # Last, so the token draws over the highlight.
	player.setup(self)
	player.set_cell(NO_CELL)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_set_hovered(cell_at(world_position(event.position)))
		if _pressing:
			if _press_at.distance_to(event.position) > DRAG_THRESHOLD:
				_dragging = true
			if _dragging:
				dragged.emit(event.relative)
				get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_at = event.position
		else:
			# A click selects a tile; a press that travelled was a drag, and only moved the map.
			var cell := cell_at(world_position(event.position))
			if _pressing and not _dragging and has_tile(cell):
				select_cell(cell)
				get_viewport().set_input_as_handled()
			_pressing = false
			_dragging = false


## Sets the ground tile and redraws the blend overlays of the cell and its neighbors.
func set_ground(cell: Vector2i, tile_name: String) -> void:
	ground_layer.set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tile_name))
	var env := _env_at(cell)
	refresh_blends(cell)
	for next in HexGrid.neighbors(cell):
		var next_env := _env_at(next)
		if env != "" and next_env != "" and not tileset.can_border(env, next_env):
			push_warning("%s at %s borders %s at %s, which env_adjacency doesn't allow" % [env, cell, next_env, next])
		refresh_blends(next)


## Pass "" to remove the road from a cell.
func set_road(cell: Vector2i, tile_name: String) -> void:
	if tile_name.is_empty():
		road_layer.erase_cell(cell)
	else:
		road_layer.set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tile_name))


## Puts the player token on a cell, or on NO_CELL to take it off the map.
func set_player_cell(cell: Vector2i) -> void:
	player.set_cell(cell)


func clear_map() -> void:
	ground_layer.clear()
	road_layer.clear()
	for layer: TileMapLayer in blend_layers.values():
		layer.clear()
	hovered_cell = NO_CELL
	selected_cell = NO_CELL
	player.set_cell(NO_CELL)
	fog.clear()
	highlight.queue_redraw()


func has_tile(cell: Vector2i) -> bool:
	return ground_layer.get_cell_source_id(cell) != -1


## Where a viewport point, such as a mouse event's position, lands in world coordinates.
func world_position(viewport_point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * viewport_point


## Cell under a point in global coordinates (e.g. the mouse).
func cell_at(global_point: Vector2) -> Vector2i:
	return ground_layer.local_to_map(ground_layer.to_local(global_point))


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


## Clears the selection, so no tile is outlined any more.
func deselect() -> void:
	selected_cell = NO_CELL
	highlight.queue_redraw()


func _set_hovered(cell: Vector2i) -> void:
	if not has_tile(cell):
		cell = NO_CELL
	if cell == hovered_cell:
		return
	hovered_cell = cell
	highlight.queue_redraw()
	if cell != NO_CELL:
		tile_hovered.emit(cell, get_tile_info(cell))


## The environment on a cell: what is drawn there, or what will be, per `hidden_env`.
func _env_at(cell: Vector2i) -> String:
	var ground := ground_layer.get_cell_tile_data(cell)
	if ground:
		return ground.get_custom_data("env")
	return hidden_env.call(cell) if hidden_env.is_valid() else ""


## Redraws a cell's overlays per the JSON meta blend_rule: a non-town tile gets blend_<A>_<edges> for every
## neighboring environment A with a higher blend priority than its own. Called again for a drawn cell when the
## land around it has changed, as it does when the map grows.
func refresh_blends(cell: Vector2i) -> void:
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
