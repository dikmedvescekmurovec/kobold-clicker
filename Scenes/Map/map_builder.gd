class_name MapBuilder
extends RefCounted
## Generates a window of the world and draws it as the player discovers it: procedural environments, the world's
## towns drawn as the town sprite of the environment they stand on, and the roads between connected towns.
## Blend overlays follow automatically, since HexMap.set_ground redraws them.
##
## Only the hexagon around the center cell (0, 0) is visible at the start; discovering a tile shows the tiles
## around it. Everything is generated up front, so what a tile turns out to be never depends on when it is found.

## Cells the map covers: 20x11 around cell (0, 0), which the camera puts at the middle of the screen.
const RECT := Rect2i(-10, -5, 20, 11)
## Cell the map is centered on, and the only one visible together with its neighbors at the start.
const CENTER := Vector2i.ZERO
## About 1 in 10 environment tiles use the accent sprite (JSON meta accent_frequency: 1 in 8-12).
const ACCENT_CHANCE := 0.1
## The first town sits exactly this many steps from the center cell, and no town is closer.
const START_TOWN_DISTANCE := 5

var map: HexMap
var towns: TownWorld
## World spot at the center cell (0, 0).
var origin: Vector2i
## The small town START_TOWN_DISTANCE steps out, which a road connects to the center cell.
var start_town: Vector2i

var _envs: Dictionary[Vector2i, String] = {}
var _tiles: Dictionary[Vector2i, String] = {}  # ground tile name per cell
var _roads: Dictionary[Vector2i, int] = {}  # road edge mask per cell
var _discovered: Dictionary[Vector2i, bool] = {}


## Generates the window and shows the starting tiles. `origin` is the world spot at the center cell (0, 0); its
## row must be even, or odd rows of the world would be drawn as even rows and world neighbors wouldn't match
## map neighbors.
static func create(map: HexMap, towns: TownWorld, origin: Vector2i, env_seed: int) -> MapBuilder:
	assert(origin.y % 2 == 0, "MapBuilder origin row must be even")
	var builder := MapBuilder.new()
	builder.map = map
	builder.towns = towns
	builder.origin = origin

	# The center is where the player starts, so clear the towns around it and put one on the ring.
	towns.clear_towns_near(origin, START_TOWN_DISTANCE)
	var start_spots: Array[Vector2i] = []
	for cell in start_town_cells():
		start_spots.append(origin + cell)
	builder.start_town = towns.ensure_small_town(start_spots)

	builder._envs = EnvironmentGenerator.generate(RECT, env_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "variants"])
	for cell in builder._envs:
		var env := builder._envs[cell]
		var tier := towns.tier_at(origin + cell)
		if tier != -1:
			builder._tiles[cell] = "town_%s_%s" % [env, TownWorld.TIER_NAMES[tier]]
		else:
			var variant := "accent" if rng.randf() < ACCENT_CHANCE else "v%d" % rng.randi_range(1, 3)
			builder._tiles[cell] = "env_%s_%s" % [env, variant]

	# Roads come from the town links and stop at town edges, so they never cover a town sprite. The first town
	# also gets a road to the center cell.
	var roads := RoadNetwork.build(towns, Rect2i(origin + RECT.position, RECT.size),
			map.tileset.legal_road_masks(), {}, builder.start_town, origin)
	for cell in builder._envs:
		var mask: int = roads.get(origin + cell, 0)
		if mask != 0 and towns.tier_at(origin + cell) == -1:
			builder._roads[cell] = mask

	map.clear_map()
	for cell in start_cells():
		builder._show(cell)
	return builder


## The hexagon visible at the start: the center cell and its six neighbors, in rows of 2, 3 and 2.
static func start_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [CENTER]
	cells.append_array(HexGrid.neighbors(CENTER))
	return cells


func discovered(cell: Vector2i) -> bool:
	return _discovered.has(cell)


## Whether discovering this cell would show anything new.
func can_discover(cell: Vector2i) -> bool:
	if not discovered(cell):
		return false
	for next in HexGrid.neighbors(cell):
		if _tiles.has(next) and not discovered(next):
			return true
	return false


## Shows the tiles around `cell`, which has to be discovered itself. Returns how many were newly shown.
func discover(cell: Vector2i) -> int:
	if not discovered(cell):
		return 0
	var shown := 0
	for next in HexGrid.neighbors(cell):
		if _tiles.has(next) and not discovered(next):
			_show(next)
			shown += 1
	return shown


## Shows the whole window at once, for tests and screenshots.
func reveal_all() -> void:
	for cell in _tiles:
		_show(cell)


## Map cells exactly START_TOWN_DISTANCE steps from the center cell (0, 0), where the guaranteed small town may go.
static func start_town_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(RECT.position.y, RECT.end.y):
		for x in range(RECT.position.x, RECT.end.x):
			if HexGrid.distance(CENTER, Vector2i(x, y)) == START_TOWN_DISTANCE:
				cells.append(Vector2i(x, y))
	return cells


func _show(cell: Vector2i) -> void:
	if discovered(cell) or not _tiles.has(cell):
		return
	_discovered[cell] = true
	map.set_ground(cell, _tiles[cell])
	if _roads.has(cell):
		var material := map.tileset.road_material_for(_envs[cell])
		map.set_road(cell, map.tileset.road_name(material, RoadNetwork.mask_edges(_roads[cell])))
