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

## Cells the map covers to begin with: 20x11 around cell (0, 0), which the camera puts at the middle of the
## screen. It grows from there as the player travels; `rect` is what the map covers now.
const START_RECT := Rect2i(-10, -5, 20, 11)
## The map grows once the player is this close to its edge, by this much on the side they are heading for.
const EXPAND_MARGIN := 4
const EXPAND_BY := Vector2i(10, 5)
## Cell the map is centered on, and the only one visible together with its neighbors at the start.
const CENTER := Vector2i.ZERO
## About 1 in 10 environment tiles use the accent sprite (JSON meta accent_frequency: 1 in 8-12).
const ACCENT_CHANCE := 0.1
## The first town sits exactly this many steps from the center cell, and no town is closer.
const START_TOWN_DISTANCE := 5

var map: HexMap
var towns: TownWorld
## What the map covers now, in cells. It starts as START_RECT and grows towards the player.
var rect := START_RECT
## Seed the environments are generated from; kept, since the map is generated in pieces as it grows.
var env_seed: int
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
var _roads: Dictionary[Vector2i, int] = {}  # road edge mask per world spot
var _routed_links: Dictionary[String, bool] = {}  # town links already routed, so a road is never laid twice
var _states: Dictionary[Vector2i, State] = {}
var _drawn_roads: Dictionary[Vector2i, int] = {}  # road mask each drawn cell shows, to spot the ones that change


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

	# The one road that doesn't end at a town: the first town's road to the center cell. It is laid before any
	# other, so the rest of the network gives way to it however the map later grows.
	builder.env_seed = env_seed
	RoadNetwork.route_to_cell(towns, builder.start_town, origin, map.tileset.legal_road_masks(), builder._roads)
	builder._generate(START_RECT)

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


## The world spot a map cell shows. `_envs`, `_tiles`, `_states` and `_drawn_roads` are keyed by cell;
## `_roads` and everything reached through `towns` are keyed by spot.
func _spot(cell: Vector2i) -> Vector2i:
	return origin + cell


## The environment generated for a cell, drawn or not, and "" outside the map.
func env_at(cell: Vector2i) -> String:
	return _envs.get(cell, "")


## The road edges on a cell, as a mask, and 0 where there is no road. Towns carry none: roads stop at their edge.
func road_at(cell: Vector2i) -> int:
	if towns.has_town(_spot(cell)):
		return 0
	return _roads.get(_spot(cell), 0)


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
## `arrived` is emitted. Returns the tiles they will cross, empty if the walk didn't start.
func move_to(cell: Vector2i) -> Array[Vector2i]:
	if walking or not discovered(cell) or cell == player_cell:
		return []
	var route := route_to(cell)
	map.player.walk(route)
	return route


func _on_player_arrived(cell: Vector2i) -> void:
	player_cell = cell
	expand_if_needed()
	arrived.emit(cell)


## Grows the map on whichever sides the player has come within EXPAND_MARGIN of, generating the new land (and
## the roads and towns on it) without touching what is already there. Returns whether the map grew.
func expand_if_needed() -> bool:
	var grown := rect
	for axis in 2:
		# How much this axis grows by, as a vector: (EXPAND_BY.x, 0) for x, (0, EXPAND_BY.y) for y.
		var step := Vector2i.ZERO
		step[axis] = EXPAND_BY[axis]
		if player_cell[axis] - rect.position[axis] < EXPAND_MARGIN:
			grown = Rect2i(grown.position - step, grown.size + step)
		if rect.end[axis] - 1 - player_cell[axis] < EXPAND_MARGIN:
			grown.size += step
	if grown == rect:
		return false
	var was := rect
	rect = grown
	_generate(rect)
	for cell in _states:
		# Tiles on the old edge had nothing beyond them to blend with; now they do.
		for next in HexGrid.neighbors(cell):
			if not was.has_point(next) and _envs.has(next):
				map.refresh_blends(cell)
				break
		# A road laid to one of the new towns can join a road already drawn, which then becomes a junction.
		if _drawn_roads.get(cell, 0) != road_at(cell):
			_draw_road(cell)
	return true


## Fills in everything the map needs for `area`: the environments of the cells it doesn't have yet, the tile
## each one is drawn with, and the roads of the town links it brings into reach. Cells already generated are
## left exactly as they are, so the land the player has seen never changes under them.
func _generate(area: Rect2i) -> void:
	EnvironmentGenerator.extend(_envs, area, hash([env_seed, area]))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not _tiles.has(cell) and _envs.has(cell):
				_tiles[cell] = _tile_name(cell)
	RoadNetwork.extend(towns, Rect2i(_spot(area.position), area.size), map.tileset.legal_road_masks(),
			_roads, _routed_links)


## Draws the road on a cell, or takes it off when there is none.
func _draw_road(cell: Vector2i) -> void:
	var mask := road_at(cell)
	_drawn_roads[cell] = mask
	if mask == 0:
		map.set_road(cell, "")
		return
	var material := map.tileset.road_material_for(_envs[cell])
	map.set_road(cell, map.tileset.road_name(material, HexGrid.mask_edges(mask)))


## The tile a cell is drawn with: the town of its environment where the world has one, otherwise the
## environment itself in one of its variants. Seeded per cell, so it never depends on when the cell was reached.
func _tile_name(cell: Vector2i) -> String:
	var env: String = _envs[cell]
	var tier := towns.tier_at(_spot(cell))
	if tier != -1:
		return "town_%s_%s" % [env, TownWorld.TIER_NAMES[tier]]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "variant", cell])
	var variant := "accent" if rng.randf() < ACCENT_CHANCE else "v%d" % rng.randi_range(1, 3)
	return "env_%s_%s" % [env, variant]


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
	for y in range(START_RECT.position.y, START_RECT.end.y):
		for x in range(START_RECT.position.x, START_RECT.end.x):
			if HexGrid.distance(CENTER, Vector2i(x, y)) == START_TOWN_DISTANCE:
				cells.append(Vector2i(x, y))
	return cells


## Draws a cell, or just changes what the player knows about one that is already drawn.
func _show(cell: Vector2i, to: State) -> void:
	if not _tiles.has(cell) or state(cell) == to:
		return
	if not seen(cell):
		map.set_ground(cell, _tiles[cell])
		_draw_road(cell)
	_states[cell] = to
	if to == State.UNDISCOVERED:
		map.fog.add_cell(cell)
	else:
		map.fog.remove_cell(cell)
