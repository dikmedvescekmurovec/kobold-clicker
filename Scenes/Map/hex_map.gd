class_name HexMap
extends Node2D
## Clickable hex map. Ground tiles (environments, towns) go on GroundLayer, blend overlays on one layer per
## spreading environment above it, and road overlays on RoadLayer.

## Part of the node's public surface; nothing listens yet, the main scene only acts on clicks.
signal tile_hovered(cell: Vector2i, info: Dictionary)
signal tile_clicked(cell: Vector2i, info: Dictionary)
## Mouse movement, in screen pixels, while dragging the map. Whoever owns the camera moves it.
signal dragged(relative: Vector2)
## A cell was clicked while the map was being aimed at (`aim_radius`), drawn or not.
signal cell_aimed(cell: Vector2i)

const NO_CELL := Vector2i(-99999, -99999)
## A press that travels further than this many panel pixels (`ui_scale` screen pixels each) drags the
## map instead of selecting a tile -- a finger's, further (`Cursors.TOUCH_SLOP`).
const DRAG_THRESHOLD := 3.0
const BACKDROP_SHADER := preload("res://Scenes/Map/backdrop.gdshader")
## How far the backdrop reaches from cell (0, 0) each way, in world pixels: past anywhere the camera can go.
const BACKDROP_REACH := 50000.0

var tileset: HexTileset
var hovered_cell := NO_CELL
var selected_cell := NO_CELL
## -1 but while somebody is choosing land rather than a tile (the fortuneteller's aimed spells): then the
## hover follows the cursor over the dark as well, every cell within this many steps of it is
## outlined, and a click says `cell_aimed` instead of selecting. Dragging still moves the map.
var aim_radius := -1:
	set(value):
		aim_radius = value
		highlight.queue_redraw()

## Environment of cells that aren't drawn yet, as a Callable taking a cell and returning an environment name
## ("" when there is none). Whoever generates the map sets it, so a tile can blend with land around it that the
## player hasn't charted, and looks the same however late it is drawn.
var hidden_env := Callable()
## Whether a cell nothing is drawn on can still be hovered and clicked, as a Callable taking a cell:
## the first tile into the fog, which can be charted blind (`MapBuilder.can_chart`). Whoever owns the
## map sets it; unset, only a drawn tile answers the mouse.
var can_pick := Callable()

## The interface's scale, which a press's travel is measured in. The main scene's.
var ui_scale := 2.0
var _press_at := Vector2.ZERO
var _pressing := false
var _dragging := false
## Overlay layer of each environment that can spread onto lower-priority neighbors, lowest priority first.
var blend_layers: Dictionary[String, TileMapLayer] = {}

@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var highlight: HexHighlight = $Highlight
## The rubble of the walls that have fallen, over the blends and under the roads and the fog: it is the
## land's, and a road runs through it.
var rubble_layer: TileMapLayer

## Marker for the player's tile, and the grey veil over tiles that aren't charted yet. Both are created
## here, so the scene file stays untouched while the editor has it open.
var player: PlayerToken
var fog: FogOverlay
## Where MapBuilder puts the treasure chest sprites: over the fog, so a chest reads on uncharted land.
var chests: Node2D
## A settlement's buildings, one sprite a town from `Assets/Towns/` (`AI-sprites-generator/build_towns.py`),
## over the fog, the ice and the chests: bigger than their hex, so a town reads from across the map, and
## only dimmed while uncharted, so a town the player has heard of stands out before the land round it.
## The ground under them is the town tile on GroundLayer.
var towns: Node2D
## The sprite pixel that sits on a town's cell centre (`towns.ANCHOR` in the generator).
const TOWN_ANCHOR := Vector2(42, 56)
## An uncharted town's buildings: over the fog rather than under it, a little dimmed.
const TOWN_UNCHARTED := Color(0.78, 0.76, 0.84)
## The Gollux cave's mouth, one picture a ground (`AI-sprites-generator/caves.py`), and the one node
## it is drawn as: there is one cave a world.
const CAVE_ART := "res://Assets/Caves/cave_%s.png"
const CAVE_NODE := "Cave"
## The dark red light out of the pit, its own shader over the picture (which leaves it out), with its
## origin on the middle of the hole: `caves.HOLE`, in the sprite's pixels. The polygon is the most of the
## map it may light, round that point.
const CAVE_GLOW := preload("res://Scenes/Map/cave_glow.gdshader")
const CAVE_GLOW_AT := Vector2(42, 58)
const CAVE_GLOW_REACH := Rect2(-32, -34, 64, 54)
var _town_art: Dictionary[String, Texture2D] = {}


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
	rubble_layer = TileMapLayer.new()
	rubble_layer.name = "Rubble"
	rubble_layer.tile_set = tileset.tile_set
	add_child(rubble_layer)
	move_child(rubble_layer, road_layer.get_index())
	highlight.setup(self)
	# The dark under everything, where nothing is drawn yet: drifting cloud, far wider than any map.
	var backdrop := Polygon2D.new()
	backdrop.name = "Backdrop"
	backdrop.polygon = PackedVector2Array([Vector2(-BACKDROP_REACH, -BACKDROP_REACH),
			Vector2(BACKDROP_REACH, -BACKDROP_REACH), Vector2(BACKDROP_REACH, BACKDROP_REACH),
			Vector2(-BACKDROP_REACH, BACKDROP_REACH)])
	backdrop.material = ShaderMaterial.new()
	backdrop.material.shader = BACKDROP_SHADER
	add_child(backdrop)
	move_child(backdrop, 0)
	fog = FogOverlay.new()
	fog.name = "Fog"
	add_child(fog)
	move_child(fog, highlight.get_index())  # Over the terrain and roads, under the outlines.
	fog.setup(self)
	chests = Node2D.new()
	chests.name = "Chests"
	add_child(chests)
	move_child(chests, highlight.get_index())
	towns = Node2D.new()
	towns.name = "Towns"
	add_child(towns)
	move_child(towns, highlight.get_index())
	player = PlayerToken.new()
	player.name = "Player"
	add_child(player)  # Last, so the token draws over the highlight.
	player.setup(self)
	player.set_cell(NO_CELL)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# A finger has no hover, and its motion is only ever the map pulled about: its outline stands
		# where it last tapped (below).
		if not Cursors.touched:
			_set_hovered(cell_at(world_position(event.position)))
		if _pressing:
			var slop := Cursors.TOUCH_SLOP if Cursors.touched else DRAG_THRESHOLD
			if _press_at.distance_to(event.position) > slop * ui_scale:
				_dragging = true
			if _dragging:
				dragged.emit(event.relative)
				get_viewport().set_input_as_handled()
		_point()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressing = true
			_dragging = false
			_press_at = event.position
		else:
			# A click selects a tile; a press that travelled was a drag, and only moved the map.
			var cell := cell_at(world_position(event.position))
			# A tap makes no motion, so it is what moves a finger's outline: onto the tile it chose.
			if _pressing and not _dragging:
				_set_hovered(cell)
			if _pressing and not _dragging and aim_radius >= 0:
				cell_aimed.emit(cell)
				get_viewport().set_input_as_handled()
			elif _pressing and not _dragging and _answers(cell):
				select_cell(cell)
				get_viewport().set_input_as_handled()
			_pressing = false
			_dragging = false
			_point()


## The cursor over bare map, which no Control answers for: the closed hand while the map is pulled
## about, the pointing one over a tile a press would select -- but the arrow, which wears it, while
## something is in the hand (a rune, `Cursors.hold`).
func _point() -> void:
	Input.set_default_cursor_shape(Cursors.GRAB if _dragging
			else Cursors.HAND if hovered_cell != NO_CELL and not Cursors.holding() else Cursors.ARROW)


## Puts a ground tile down without touching the overlays. For a bulk load, where the caller
## refreshes the blends of everything it drew once it is all down: set_ground refreshes a cell and
## its six neighbors, which is seven times the work when a whole map arrives at once.
func place_ground(cell: Vector2i, tile_name: String) -> void:
	ground_layer.set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tile_name))


## Sets the ground tile and redraws the blend overlays of the cell and its neighbors.
func set_ground(cell: Vector2i, tile_name: String) -> void:
	place_ground(cell, tile_name)
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


## Lays a fallen wall's rubble on `cell`, along its ring: `mask` is its two neighbours on the ring
## (`HexGrid.edge_mask`). Which version is fixed by the cell, so the same rubble lies there every load.
@warning_ignore("integer_division")
func set_rubble(cell: Vector2i, mask: int) -> void:
	var version := posmod((cell.x * 73856093) ^ (cell.y * 19349663), HexTileset.RUBBLE_VERSIONS)
	rubble_layer.set_cell(cell, HexTileset.RUBBLE_ID, Vector2i(mask % 8 + 8 * version, mask / 8))


## Draws a settlement's buildings on `cell` (its tile name, e.g. "town_grass_small"), full colour once
## charted and dimmed before. Called again for the same cell, it only changes that.
func set_town(cell: Vector2i, tile_name: String, charted: bool) -> void:
	var sprite := towns.get_node_or_null(_town_node(cell)) as Sprite2D
	if sprite == null:
		if not _town_art.has(tile_name):
			_town_art[tile_name] = load("res://Assets/Towns/%s.png" % tile_name)
		sprite = Sprite2D.new()
		sprite.name = _town_node(cell)
		sprite.texture = _town_art[tile_name]
		sprite.centered = false
		sprite.position = ground_layer.map_to_local(cell) - TOWN_ANCHOR
		towns.add_child(sprite)
	sprite.modulate = Color.WHITE if charted else TOWN_UNCHARTED


## Draws the Gollux cave's mouth on `cell`, in `env`'s picture, on the settlements' layer and at their
## anchor (`caves.py` draws it to their size), dimmed until charted as a settlement is. Nothing where
## the picture has not been built: the art is exported only once it has been approved.
func set_cave(cell: Vector2i, env: String, charted: bool) -> void:
	var sprite := towns.get_node_or_null(CAVE_NODE) as Sprite2D
	if sprite == null:
		var path := CAVE_ART % env
		if not ResourceLoader.exists(path):
			return
		sprite = Sprite2D.new()
		sprite.name = CAVE_NODE
		sprite.texture = load(path)
		sprite.centered = false
		sprite.position = ground_layer.map_to_local(cell) - TOWN_ANCHOR
		towns.add_child(sprite)
		sprite.add_child(_cave_glow())
	sprite.modulate = Color.WHITE if charted else TOWN_UNCHARTED


## The light out of the pit: a rectangle over the hole drawn by `cave_glow.gdshader`, added onto what is
## under it. A child of the picture, so the fog's dimming of an uncharted cave dims it too. It is only for
## show, so with animations off it holds still.
func _cave_glow() -> Polygon2D:
	var glow := Polygon2D.new()
	glow.name = "Glow"
	var r := CAVE_GLOW_REACH
	glow.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end,
			Vector2(r.position.x, r.end.y)])
	glow.position = CAVE_GLOW_AT
	var material := ShaderMaterial.new()
	material.shader = CAVE_GLOW
	if Settings.animations == Settings.Anim.NONE:
		for still: String in ["breath", "depth", "flicker"]:
			material.set_shader_parameter(still, 0.0)
	glow.material = material
	return glow


func has_town(cell: Vector2i) -> bool:
	return towns.has_node(_town_node(cell))


func _town_node(cell: Vector2i) -> String:
	return "Town_%d_%d" % [cell.x, cell.y]


## Puts the player token on a cell, or on NO_CELL to take it off the map.
func set_player_cell(cell: Vector2i) -> void:
	player.set_cell(cell)


func clear_map() -> void:
	ground_layer.clear()
	road_layer.clear()
	rubble_layer.clear()
	for layer: TileMapLayer in blend_layers.values():
		layer.clear()
	hovered_cell = NO_CELL
	selected_cell = NO_CELL
	player.set_cell(NO_CELL)
	fog.clear()
	for chest in chests.get_children():
		chest.free()
	for town in towns.get_children():
		town.free()
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


## Whether a press or the hover means anything on `cell`: a drawn tile, or one `can_pick` vouches for.
func _answers(cell: Vector2i) -> bool:
	return has_tile(cell) or (can_pick.is_valid() and bool(can_pick.call(cell)))


func _set_hovered(cell: Vector2i) -> void:
	if not _answers(cell) and aim_radius < 0:
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
	for edge in HexGrid.EDGES:
		var env := _env_at(HexGrid.neighbor(cell, edge))
		if env != "" and tileset.env_rank(env) > rank:
			if not edges_by_env.has(env):
				edges_by_env[env] = []
			edges_by_env[env].append(edge)
	for env in edges_by_env:
		blend_layers[env].set_cell(cell, HexTileset.SOURCE_ID, tileset.atlas_coords(tileset.blend_name(env, edges_by_env[env])))
