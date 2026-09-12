class_name MapBuilder
extends RefCounted
## Generates a window of the world and draws it as the player discovers it: procedural environments, the world's
## towns drawn as the town sprite of the environment they stand on, and the roads between connected towns.
## Blend overlays follow automatically, since HexMap.set_ground redraws them.
##
## Every cell is in one of three states. HIDDEN cells are the fog of war: nothing is drawn for them at all.
## UNDISCOVERED cells are drawn under a grey veil (HexMap.fog): the player can see the land but hasn't looked at
## it, and can't go there. DISCOVERED cells are drawn plainly and can be walked to and over.
##
## The player starts on the center cell (0, 0), the only discovered one, with its six neighbors undiscovered
## around it. They discover a tile next to the one they stand on, which lifts the fog off the tiles behind it
## and sends them walking onto it; they can also walk back to any tile they have discovered. Everything is generated up front, so what a tile turns out to be never depends on
## when it is found.

## The player has finished walking to `cell`.
signal arrived(cell: Vector2i)

## What the player knows about a cell.
enum State { HIDDEN, UNDISCOVERED, DISCOVERED }

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
## The cell the player stands on, which only changes once they have walked there.
var player_cell := CENTER
## Whether the player is on their way somewhere, and so can't be sent anywhere else.
var walking: bool:
	get: return map.player.is_walking()

var _envs: Dictionary[Vector2i, String] = {}
var _tiles: Dictionary[Vector2i, String] = {}  # ground tile name per cell
var _roads: Dictionary[Vector2i, int] = {}  # road edge mask per cell
var _states: Dictionary[Vector2i, State] = {}


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
	# Blends read the environment of every generated cell, not just the drawn ones, so a tile is drawn with the
	# same overlays whether its neighbors are already discovered or still hidden.
	map.hidden_env = builder.env_at
	# Rebuilding the map hands the player over to the new builder, so any earlier one lets go.
	for connection in map.player.arrived.get_connections():
		map.player.arrived.disconnect(connection["callable"])
	map.player.arrived.connect(builder._on_player_arrived)
	# The player knows the tile they stand on and can see the ring around it, without having looked at it yet.
	builder._show(CENTER, State.DISCOVERED)
	for cell in HexGrid.neighbors(CENTER):
		builder._show(cell, State.UNDISCOVERED)
	builder.player_cell = CENTER
	map.set_player_cell(CENTER)
	return builder


## The hexagon drawn at the start, in rows of 2, 3 and 2: the discovered center cell and its six undiscovered
## neighbors.
static func start_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [CENTER]
	cells.append_array(HexGrid.neighbors(CENTER))
	return cells


## The environment generated for a cell, drawn or not, and "" outside the map.
func env_at(cell: Vector2i) -> String:
	return _envs.get(cell, "")


## What the player knows about a cell. Cells outside the map are HIDDEN.
func state(cell: Vector2i) -> State:
	return _states.get(cell, State.HIDDEN)


func discovered(cell: Vector2i) -> bool:
	return state(cell) == State.DISCOVERED


## Whether anything is drawn for a cell: it is discovered, or seen under the fog.
func seen(cell: Vector2i) -> bool:
	return state(cell) != State.HIDDEN


## Whether the player can discover this cell: it has to be a tile they can see next to the one they stand on,
## and they have to be standing still.
func can_discover(cell: Vector2i) -> bool:
	return not walking and state(cell) == State.UNDISCOVERED and HexGrid.distance(cell, player_cell) == 1


## Whether the player can travel to this cell: a discovered tile other than the one they stand on, with a route
## of discovered tiles leading to it, and no walk under way.
func can_move_to(cell: Vector2i) -> bool:
	return not walking and discovered(cell) and cell != player_cell and not route_to(cell).is_empty()


## The tiles the player would cross on the way to `cell`, the destination last and the tile they stand on left
## out. Every tile of the route is discovered; the route is empty when none leads there.
func route_to(cell: Vector2i) -> Array[Vector2i]:
	if not discovered(cell) or cell == player_cell:
		return []
	var came_from: Dictionary[Vector2i, Vector2i] = {player_cell: player_cell}
	var queue: Array[Vector2i] = [player_cell]
	var i := 0
	while i < queue.size():
		var at := queue[i]
		i += 1
		for next in HexGrid.neighbors(at):
			if not discovered(next) or came_from.has(next):
				continue
			came_from[next] = at
			if next == cell:
				var route: Array[Vector2i] = []
				var back := cell
				while back != player_cell:
					route.push_front(back)
					back = came_from[back]
				return route
			queue.append(next)
	return []


## Sends the player walking to a discovered tile. They arrive a couple of seconds per tile later, when
## `arrived` is emitted. Returns whether the walk started.
func move_to(cell: Vector2i) -> bool:
	if not can_move_to(cell):
		return false
	map.player.walk(route_to(cell))
	return true


func _on_player_arrived(cell: Vector2i) -> void:
	player_cell = cell
	arrived.emit(cell)


## Discovers a tile the player can see next to them: its grey veil comes off, the tiles behind it come out of
## the fog as undiscovered land, and the player sets off for it, arriving a couple of seconds later. Returns
## how many tiles newly showed, or -1 if it can't be discovered.
func discover(cell: Vector2i) -> int:
	if not can_discover(cell):
		return -1
	_show(cell, State.DISCOVERED)
	var shown := 0
	for next in HexGrid.neighbors(cell):
		if _tiles.has(next) and not seen(next):
			_show(next, State.UNDISCOVERED)
			shown += 1
	# Looking at the tile next door is the first half of going there, so the walk follows by itself.
	move_to(cell)
	return shown


## Discovers the whole window at once, for tests and screenshots.
func reveal_all() -> void:
	for cell in _tiles:
		_show(cell, State.DISCOVERED)


## Map cells exactly START_TOWN_DISTANCE steps from the center cell (0, 0), where the guaranteed small town may go.
static func start_town_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(RECT.position.y, RECT.end.y):
		for x in range(RECT.position.x, RECT.end.x):
			if HexGrid.distance(CENTER, Vector2i(x, y)) == START_TOWN_DISTANCE:
				cells.append(Vector2i(x, y))
	return cells


## Draws a cell, or just changes what the player knows about one that is already drawn.
func _show(cell: Vector2i, to: State) -> void:
	if not _tiles.has(cell) or state(cell) == to:
		return
	if not seen(cell):
		map.set_ground(cell, _tiles[cell])
		if _roads.has(cell):
			var material := map.tileset.road_material_for(_envs[cell])
			map.set_road(cell, map.tileset.road_name(material, RoadNetwork.mask_edges(_roads[cell])))
	_states[cell] = to
	if to == State.UNDISCOVERED:
		map.fog.add_cell(cell)
	else:
		map.fog.remove_cell(cell)
