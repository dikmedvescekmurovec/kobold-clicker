class_name MapBuilder
extends RefCounted
## Generates the map and draws it as the player charts it (DESIGN.md: "map_builder.gd"). `_envs`, `_tiles`,
## `_states`, `_names` and `_drawn_roads` are keyed by map cell; `_roads` and everything reached through
## `towns` by world spot (`_spot`).

## The player is on `cell` now: a walk's end, a chart of the tile underfoot, a homecoming.
signal arrived(cell: Vector2i)

## HIDDEN: the fog of war, nothing drawn. UNCHARTED: drawn under the grey veil, not walkable.
enum State { HIDDEN, UNCHARTED, CHARTED }

## The land's first radius, so the first wall stands on ring 12 (the user's, 2026-09-28).
const START_LAND_RADIUS := 11
## Rings a fallen wall opens. A multiple of `LEVEL_TILES`, as `START_LAND_RADIUS + 1` is, so the land past
## a wall is a level above the land inside it (the user's, 2026-09-28).
const WALL_STEP := 12
## `WALL_STEP` under the Ring of Walls curse (`wall_step`). No multiple of `LEVEL_TILES`: every other wall
## of the curse's stands in the middle of a level.
const RING_OF_WALLS_STEP := 6
## Rings one tile level spans: level 1 is rings 0-3.
const LEVEL_TILES := 4
## Rings generated past the wall: the wasteland the player can see, with real land under it for the wall
## to blend against.
const WASTE_DEPTH := 5
const WALL_NAME := "The Ice Wall"
const WASTE_NAME := "Frozen Wasteland"
const WALL_FALL_SOUND := preload("res://Sounds/Sfx/ice_wall_fall.ogg")
const CENTER := Vector2i.ZERO
## A little over the sheet's `accent_frequency` (1 in 8-12): a cell beside a lower roll gives its accent
## up (`_tile_name`).
const ACCENT_CHANCE := 0.12
const ACCENT_KINDS: Array[String] = ["accent", "accent2", "accent3"]
## The start town stands exactly this many steps from `CENTER`, and no town nearer.
const START_TOWN_DISTANCE := 5
## The share of open tiles that hold a chest, and how near `CENTER` the nearest may be.
const CHEST_CHANCE := 0.03
const CHEST_MIN_DISTANCE := 3
## The cave goes down at most this many steps from the wall tile whose breaking put it there.
const CAVE_NEAR := 3
const CHEST_TEXTURE := "res://Assets/Chests/Chests.png"
const CHEST_REGION := Rect2(2, 12, 28, 20)  # the closed brown chest
## The share of open tiles that hold a boss's lair (`boss_at`), and how near `CENTER` the nearest may be.
const LAIR_CHANCE := 0.01
const LAIR_MIN_DISTANCE := 5
## Tiles of footprints leading in to a lair (`trail_of`): the user's "about five" (2026-10-29).
const TRAIL_LENGTH := 5
## A lair's boss stands this many map pixels tall on its tile, a head over the hero (`PlayerToken.TALL`),
## its feet this far under the tile's middle.
const LAIR_TALL := 40.0
const LAIR_FEET := Vector2(0, 8)
## The footprint sheets (`tools/boss_tracks.py`): `TRACK_CELL` a print, twelve across, the six hex
## directions on screen (`k * 60` degrees, 0 east, y down) each as a left foot then a right.
const TRACKS_ROOT := "res://Assets/Map/Tracks/"
const TRACK_CELL := 16
## Prints a tile's step holds, and how far either side of the way a left and a right fall, in map pixels.
const TRACK_PRINTS := 3
const TRACK_SPREAD := 3.0
## A settlement's `area_variant`, by `TownWorld.Tier`.
const TIER_AREAS: Array[String] = ["village", "town", "fortress"]

var map: HexMap
var towns: TownWorld
## What is generated, in cells: the land, the wall and `WASTE_DEPTH` of wasteland. Grows only as a wall falls.
var rect := Rect2i()
## How far the land reaches from `CENTER`; ring `land_radius + 1` is the ice wall.
var land_radius := START_LAND_RADIUS
## Rings a fallen wall opens in this world: `WALL_STEP`, or `RING_OF_WALLS_STEP` under the curse. Never
## saved: the main scene says it, and to `restore` itself, which draws the fallen walls' rubble.
var wall_step := WALL_STEP
## Seeds the land and every fact derived per cell.
var env_seed: int
## The world spot at `CENTER`.
var origin: Vector2i
## The world spot of the small town `START_TOWN_DISTANCE` out, which a road joins to `CENTER`.
var start_town: Vector2i
## The Gollux cave's cell, `HexMap.NO_CELL` until `place_cave`. Saved.
var cave := HexMap.NO_CELL
## The wall tile charted last, `HexMap.NO_CELL` while none has been this session: what the cave is put
## down beside. Not saved.
var breach := HexMap.NO_CELL
## Changes only once the player has walked there (`_on_player_arrived`).
var player_cell := CENTER
var walking: bool:
	get: return map.player.is_walking()
## How many steps from the charted land a tile can be charted (the Nightwalkers), as a Callable returning
## an int; 1 without one. Asked, not told, so boots taken off are felt at the next hover.
var dark_reach := Callable()
## Every tile that can be charted now (`can_chart`), worked out once for the map as it stands and the
## reach it was worked out at: the hover asks on every move of the mouse.
var _chartable: Dictionary[Vector2i, bool] = {}
var _chartable_reach := 0
## Distant charting (`WallUnlocks.DISTANT`, the user's 2026-10-09): any tile the player has seen can be
## charted, however far, so long as seen land leads to it from the charted. Never an unseen one. The
## main scene says so as the world is built and as a wall falls.
var distant := false:
	set(value):
		if value != distant:
			distant = value
			_chartable.clear()

var _envs: Dictionary[Vector2i, String] = {}
## The land past the wall being fought for, generated on another thread (`_generate_ahead`): the
## WorkerThreadPool task (-1 when there is none), the area it fills and the copy of `_envs` it fills.
var _ahead_task := -1
var _ahead_area := Rect2i()
var _ahead_envs: Dictionary[Vector2i, String] = {}
var _tiles: Dictionary[Vector2i, String] = {}  # ground tile name per cell, derived (`_tile_name`)
var _names: Dictionary[Vector2i, String] = {}  # what each seen tile is called: saved, never worked out again
var _roads: Dictionary[Vector2i, int] = {}  # road edge mask per world spot
var _routed_links: Dictionary[String, bool] = {}  # town links already routed: a road is never laid twice
var _states: Dictionary[Vector2i, State] = {}
var _drawn_roads: Dictionary[Vector2i, int] = {}  # road mask each drawn cell shows, to spot the ones that change
var _chest_sprites: Dictionary[Vector2i, Sprite2D] = {}
## Every lair's trail by the tiles it crosses: tile -> [[lair, the tile it steps toward, its step from the
## far end], ...]. Derived (`_find_lairs`), and drawn only while its lair still stands (`boss_at`).
var _tracks: Dictionary[Vector2i, Array] = {}
var _lair_sprites: Dictionary[Vector2i, CombatActor] = {}
var _track_sprites: Dictionary[Vector2i, Node2D] = {}
var _ice: IceOverlay
var _edge_fog: EdgeFog


static func create(map: HexMap, towns: TownWorld, origin: Vector2i, env_seed: int) -> MapBuilder:
	assert(origin.y % 2 == 0, "MapBuilder origin row must be even")
	var builder := MapBuilder.new()
	builder.map = map
	builder.towns = towns
	builder.origin = origin
	towns.clear_towns_near(origin, START_TOWN_DISTANCE)
	var start_spots: Array[Vector2i] = []
	for cell in start_town_cells():
		start_spots.append(origin + cell)
	builder.start_town = towns.ensure_small_town(start_spots)
	builder.env_seed = env_seed
	# The start town's road to the centre is laid before any other (`_cover`), so the rest of the network
	# gives way to it however the map later grows.
	RoadNetwork.route_to_cell(towns, builder.start_town, origin, map.tileset.legal_road_masks(), builder._roads)
	builder._cover()
	builder._take_map()
	builder._show(CENTER, State.CHARTED)
	for cell in HexGrid.neighbors(CENTER):
		builder._show(cell, State.UNCHARTED)
	map.set_player_cell(CENTER)
	return builder


## `_tiles`, `_drawn_roads` and the fog are derived, so left out. Touches none of `map`'s children, so
## never `walking`: the main scene calls this from `_exit_tree`, where they may already be gone. A game
## closed mid-walk so resumes on the tile the walk set off from.
func to_save() -> MapSave:
	var save := MapSave.new()
	save.sheet = MapSave.fingerprint(map.tileset)
	save.world_seed = towns.seed_value
	save.map_seed = env_seed
	save.origin = origin
	save.rect = rect
	save.land_radius = land_radius
	save.start_town = start_town
	save.cave = cave
	save.player_cell = player_cell
	save.towns = towns.to_dict()
	save.envs = _envs
	save.names = _names
	save.roads = _roads
	save.routed_links = _routed_links
	for cell in _states:
		save.states[cell] = _states[cell]
	return save


## `towns` is the world out of the same save (`TownWorld.from_dict`), `step` this world's `wall_step`.
static func restore(map: HexMap, towns: TownWorld, save: MapSave, step := WALL_STEP) -> MapBuilder:
	assert(save.origin.y % 2 == 0, "MapBuilder origin row must be even")
	var builder := MapBuilder.new()
	builder.wall_step = step  # before anything is drawn: the rubble lies where the walls fell
	builder.map = map
	builder.towns = towns
	builder.origin = save.origin
	builder.env_seed = save.map_seed
	builder.rect = save.rect
	builder.start_town = save.start_town
	builder.cave = save.cave
	builder._envs = save.envs
	builder._names = save.names
	builder._roads = save.roads
	builder._routed_links = save.routed_links
	for cell in save.states:
		builder._states[cell] = save.states[cell]
	for cell in builder._envs:
		builder._tiles[cell] = builder._tile_name(cell)
	builder.land_radius = save.land_radius if save.land_radius > 0 else migrated_radius(save.states)
	# A save from before the wall may not reach past where the wall now stands.
	builder._cover()
	# A save from before names existed has seen land with none: named here, so one load makes it whole.
	for cell in builder._states:
		builder.name_of(cell)
	builder._find_lairs()
	builder._take_map()
	builder._draw_saved()
	builder.player_cell = save.player_cell
	map.set_player_cell(save.player_cell)
	return builder


## Takes `map` over, cleared: the ice and the edge fog go under `chests` (after `clear_map`, which frees
## whatever stands there), and the token's arrivals are heard here and by no earlier builder.
func _take_map() -> void:
	map.clear_map()
	_ice = IceOverlay.new(map)
	_ice.name = "Ice"
	map.chests.add_child(_ice)
	_edge_fog = EdgeFog.new(map)
	_edge_fog.name = "EdgeFog"
	map.chests.add_child(_edge_fog)
	# Before any cell is drawn: blends read the environment of every generated cell, drawn or not.
	map.hidden_env = env_at
	map.can_pick = can_chart
	for connection in map.player.arrived.get_connections():
		map.player.arrived.disconnect(connection["callable"])
	map.player.arrived.connect(_on_player_arrived)


## Every saved cell in one pass: the grounds first, then each cell's blends once. `_show` goes through
## `HexMap.set_ground`, which refreshes seven cells' blends a cell.
func _draw_saved() -> void:
	for cell in _states:
		if not _tiles.has(cell):
			continue
		if _states[cell] != State.HIDDEN:
			_edge_fog.add_cell(cell)
		if is_wasteland(cell):
			_ice.set_cell(cell, IceOverlay.Kind.WASTE)
			continue
		map.place_ground(cell, _tiles[cell])
		_draw_band(cell)
		if _states[cell] == State.UNCHARTED:
			map.fog.add_cell(cell)
		_draw_cell(cell)
	for cell in _states:
		if _tiles.has(cell):
			map.refresh_blends(cell)


## `CENTER` and its six neighbours: what a new map shows.
static func start_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [CENTER]
	cells.append_array(HexGrid.neighbors(CENTER))
	return cells


## Where the start town may go.
static func start_town_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in FortuneTeller.scour_cells(CENTER, START_TOWN_DISTANCE):
		if HexGrid.distance(CENTER, cell) == START_TOWN_DISTANCE:
			cells.append(cell)
	return cells


## `land_radius` for a save from before the wall: the wall goes on the first ring, counted the way the
## walls fall, beyond everything the player has seen, so nothing they knew is iced over.
static func migrated_radius(states: Dictionary) -> int:
	var farthest := 0
	for cell in states:
		if states[cell] != State.HIDDEN:
			farthest = maxi(farthest, HexGrid.distance(CENTER, cell))
	return START_LAND_RADIUS + WALL_STEP * _rings_out(farthest, WALL_STEP)


func is_land(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) <= land_radius


func is_wall(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) == land_radius + 1


func is_wasteland(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) > land_radius + 1


## How many rings of land, each `step` wide, end short of a tile `steps` from `CENTER`: 0 inside the
## first wall, and a wall's own ring counts with the land its fall opens.
static func _rings_out(steps: int, step: int) -> int:
	return maxi(0, ceili(float(steps - START_LAND_RADIUS) / step))


## Which ring of land `cell` stands in: 0 inside where the first wall stood, n between the nth wall and
## the next. Counted in `wall_step`s, so under the Ring of Walls a ring is the land between its walls.
func ring_of(cell: Vector2i) -> int:
	return _rings_out(HexGrid.distance(CENTER, cell), wall_step)


## Whether `cell` is on a ring where a wall stands or stood, counted in `wall_step`s.
func on_wall_ring(cell: Vector2i) -> bool:
	var past := HexGrid.distance(CENTER, cell) - START_LAND_RADIUS - 1
	return past >= 0 and past % wall_step == 0


## A cell's two neighbours on its own ring round the centre, as `HexGrid.edge_mask`: where a wall's
## band runs, or its rubble once it has fallen.
func _ring_edges(cell: Vector2i) -> int:
	var mask := 0
	var ring := HexGrid.distance(CENTER, cell)
	for edge in HexGrid.EDGES:
		if HexGrid.distance(CENTER, HexGrid.neighbor(cell, edge)) == ring:
			mask |= 1 << edge
	return mask


## In this world, not ever (`Inventory.walls_ever`).
func walls_fallen() -> int:
	return maxi(0, (land_radius - START_LAND_RADIUS) / wall_step)


## The level of the deepest charted land. A scan: ask once a tile is charted.
func charted_level() -> int:
	var deepest := 0
	for cell: Vector2i in _states:
		if _states[cell] == State.CHARTED:
			deepest = maxi(deepest, HexGrid.distance(CENTER, cell))
	return _level_at(deepest)


## What the tile panel shows and the ceiling on what can drop there. Banded, while enemy health is smooth
## in the distance: two tiles at the ends of one band read alike and do not fight alike.
static func level_of(cell: Vector2i) -> int:
	return _level_at(HexGrid.distance(CENTER, cell))


@warning_ignore("integer_division")
static func _level_at(steps: int) -> int:
	return 1 + steps / LEVEL_TILES


## The first ring of `level`'s band.
static func first_step(level: int) -> int:
	return (maxi(level, 1) - 1) * LEVEL_TILES


## The level of the outer ring of `cell`'s circle, the one just inside the next wall.
static func circle_level(cell: Vector2i) -> int:
	return _level_at(START_LAND_RADIUS + (circle_of(cell) - 1) * WALL_STEP)


## Which circle of land `cell` is in: 1 inside the first ice wall, 2 out to the second, and so on.
## Counted in plain `WALL_STEP`s, so the Ring of Walls moves no circle.
static func circle_of(cell: Vector2i) -> int:
	return 1 + _rings_out(HexGrid.distance(CENTER, cell), WALL_STEP)


## The world spot a map cell shows.
func _spot(cell: Vector2i) -> Vector2i:
	return origin + cell


## Drawn or not; "" outside the map.
func env_at(cell: Vector2i) -> String:
	return _envs.get(cell, "")


## Names the tile the first time it is asked, which `_show` makes the first time the player sees it,
## and keeps the name from then on (`_names`, saved). The wall's and the wasteland's are never kept.
func name_of(cell: Vector2i) -> String:
	if is_wall(cell):
		return WALL_NAME
	if is_wasteland(cell):
		return WASTE_NAME
	if _names.has(cell):
		return _names[cell]
	if not _envs.has(cell):
		return ""
	var tier := towns.tier_at(_spot(cell))
	_names[cell] = TileNames.generate(cell, _envs[cell], env_seed,
			TownWorld.TIER_NAMES[tier] if tier != -1 else TileNames.CAVE if cell == cave else "")
	return _names[cell]


## The road's edge mask, 0 for none. A town and the cave carry none: roads stop at their edge.
func road_at(cell: Vector2i) -> int:
	if towns.has_town(_spot(cell)) or cell == cave:
		return 0
	return _roads.get(_spot(cell), 0)


## Which battle backdrop a cell fights on. Whatever stands under the ice, the wall is fought in the open.
func area_variant(cell: Vector2i) -> String:
	if is_wall(cell):
		return "plain"
	var tier := towns.tier_at(_spot(cell))
	if tier != -1:
		return TIER_AREAS[tier]
	return "road" if road_at(cell) != 0 else "plain"


## A stream of rolls fixed by `key`: what is derived per cell, and so never saved, is rolled off one.
static func _seeded(key: Array) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	return rng


func _is_open(cell: Vector2i) -> bool:
	return _envs.has(cell) and is_land(cell) and not towns.has_town(_spot(cell)) and cell != cave


## A per-cell roll on open land that holds until the tile is charted. Derived from the seed, never saved.
func has_chest(cell: Vector2i) -> bool:
	if not _is_open(cell) or charted(cell) or HexGrid.distance(CENTER, cell) < CHEST_MIN_DISTANCE:
		return false
	return _seeded([env_seed, "chest", cell]).randf() < CHEST_CHANCE


## The boss whose lair is on `cell` (`EnemyRoster.LAIRS`, its land's), or "": a per-cell roll on open land
## that holds until the tile is charted, as `has_chest`'s does, and never on a chest or a fallen wall's ring.
func boss_at(cell: Vector2i) -> String:
	if not _is_open(cell) or HexGrid.distance(CENTER, cell) < LAIR_MIN_DISTANCE \
			or _seeded([env_seed, "lair", cell]).randf() >= LAIR_CHANCE:
		return ""
	if charted(cell) or has_chest(cell) or on_wall_ring(cell):
		return ""
	return EnemyRoster.lair_boss(_envs[cell])


## The footprints leading in to the lair on `lair`, farthest first: a walk of TRAIL_LENGTH tiles out from
## it across generated land, each a step further from it than the last, picked off the seed. Shorter
## where the land runs out.
func trail_of(lair: Vector2i) -> Array[Vector2i]:
	var rng := _seeded([env_seed, "trail", lair])
	var way: Array[Vector2i] = []
	var at := lair
	for step in TRAIL_LENGTH:
		var next: Array[Vector2i] = []
		for near in HexGrid.neighbors(at):
			if _envs.has(near) and is_land(near) and near != cave and HexGrid.distance(lair, near) == step + 1:
				next.append(near)
		if next.is_empty():
			break
		at = next[rng.randi() % next.size()]
		way.push_front(at)
	return way


## Every lair on generated land and its trail, into `_tracks`. As the land grows (`_generate`) and as a
## save loads.
## ponytail: scans every generated cell, like `nearest_chest`; only start-up and a wall's fall ask.
func _find_lairs() -> void:
	_tracks.clear()
	for lair in _envs:
		if boss_at(lair).is_empty():
			continue
		var way := trail_of(lair)
		for step in way.size():
			var toward := way[step + 1] if step + 1 < way.size() else lair
			_tracks.get_or_add(way[step], []).append([lair, toward, step])


## The footprint sheet of `boss` (`tools/boss_tracks.py`'s `path_of`).
static func tracks_path(boss: String) -> String:
	return TRACKS_ROOT + boss.to_lower().replace(" ", "_") + ".png"


## What the land on `cell` does to its own fight (`TileMods`), derived like `has_chest`: nothing where the
## fight is a set piece. `wild` is the Wild Tiles curse, which the builder cannot know.
func mods_of(cell: Vector2i, wild := false) -> Array[String]:
	if not _is_open(cell) or has_chest(cell) or on_wall_ring(cell) or not boss_at(cell).is_empty():
		return []
	return TileMods.for_cell(env_seed, cell, ring_of(cell), wild)


## The chest nearest the player, fog or not; NO_CELL for none. `unseen_only` leaves out one already drawn:
## a fortuneteller pointing at it would be selling what is in plain sight.
## ponytail: scans every generated cell, so call it on arrival rather than per frame.
func nearest_chest(unseen_only := false) -> Vector2i:
	var best := HexMap.NO_CELL
	var best_steps := -1
	for cell in _envs:
		if not has_chest(cell) or (unseen_only and seen(cell)):
			continue
		var steps := HexGrid.distance(player_cell, cell)
		if best_steps == -1 or steps < best_steps:
			best = cell
			best_steps = steps
	return best


## Every environment generated on land within `steps` of `cell`, seen or not: what a bounty board posts.
## ponytail: scans every generated cell, so ask it on walking into a town rather than per frame.
func envs_within(cell: Vector2i, steps: int) -> PackedStringArray:
	var found := PackedStringArray()
	for near in _envs:
		if is_land(near) and HexGrid.distance(cell, near) <= steps and not (_envs[near] in found):
			found.append(_envs[near])
	return found


## Every cell's chest again, for when the dev's `Settings.show_all_chests` changes.
## ponytail: scans every cell, like `nearest_chest`; only a settings tick and start-up ask.
func redraw_chests() -> void:
	for cell in _envs:
		_draw_chest(cell)


## Every lair's boss and every trail again, for when the dev's `Settings.show_all_bosses` changes.
## ponytail: scans every cell, like `redraw_chests`; only a settings tick and start-up ask.
func redraw_lairs() -> void:
	for cell in _envs:
		_draw_lair(cell)
	for cell in _tracks:
		_draw_tracks(cell)


func state(cell: Vector2i) -> State:
	return _states.get(cell, State.HIDDEN)


func charted(cell: Vector2i) -> bool:
	return state(cell) == State.CHARTED


func seen(cell: Vector2i) -> bool:
	return state(cell) != State.HIDDEN


## Generated land or wall within `reach()` steps of a charted tile across land, seen or not (the first
## tile into the fog is taken blind), or what `distant` adds; never while walking.
func can_chart(cell: Vector2i) -> bool:
	if walking:
		return false
	var steps := reach()
	if steps != _chartable_reach:
		_chartable.clear()
		_chartable_reach = steps
	if _chartable.is_empty():
		_find_chartable(steps, false)
		if distant:
			_find_chartable(-1, true)
	return _chartable.has(cell)


func reach() -> int:
	return maxi(1, int(dark_reach.call())) if dark_reach.is_valid() else 1


## Into `_chartable`: every tile `steps` or fewer from the charted land, out across the land between --
## or, `seen_only`, every seen tile the charted land reaches across seen land, however far (`steps` -1).
## One walk out from every charted tile at once, a ring of steps at a time.
func _find_chartable(steps: int, seen_only: bool) -> void:
	var ring: Array[Vector2i] = []
	for cell: Vector2i in _states:
		if charted(cell):
			ring.append(cell)
	var found: Dictionary[Vector2i, bool] = {}
	var step := 0
	while not ring.is_empty() and (steps < 0 or step < steps):
		var next_ring: Array[Vector2i] = []
		for at in ring:
			for next in HexGrid.neighbors(at):
				if found.has(next) or not _tiles.has(next) or charted(next) or is_wasteland(next) \
						or (seen_only and not seen(next)):
					continue
				found[next] = true
				_chartable[next] = true
				# Land only goes on: the wall is where a way ends, never what it crosses.
				if is_land(next):
					next_ring.append(next)
		ring = next_ring
		step += 1


## The way onto `cell`: the charted tile it starts on, the uncharted tiles between, `cell` last, each
## fought for in turn (the main scene's `_dark_way`). The fewest tiles, and of those the start the player
## is fewest steps from. Empty when there is no way.
func dark_path(cell: Vector2i) -> Array[Vector2i]:
	var path := _way_in(cell, reach(), false)
	if path.is_empty() and distant and seen(cell):
		path = _way_in(cell, -1, true)
	return path


## `dark_path`'s search: out from `cell` a ring at a time to the charted land, across `steps` - 1 tiles
## of any land, or with `seen_only` across seen land however many (`steps` -1).
func _way_in(cell: Vector2i, steps: int, seen_only: bool) -> Array[Vector2i]:
	var came_from: Dictionary[Vector2i, Vector2i] = {cell: cell}
	var ring: Array[Vector2i] = [cell]
	var step := 0
	while not ring.is_empty() and (steps < 0 or step < steps):
		var starts: Array[Vector2i] = []
		var next_ring: Array[Vector2i] = []
		for at in ring:
			for next in HexGrid.neighbors(at):
				if came_from.has(next):
					continue
				if charted(next):
					came_from[next] = at
					starts.append(next)
				elif _tiles.has(next) and is_land(next) and (seen(next) if seen_only else step + 1 < steps):
					came_from[next] = at
					next_ring.append(next)
		if not starts.is_empty():
			var best := starts[0]
			var best_steps := -1
			for start in starts:
				var walk := 0 if start == player_cell else route_to(start).size()
				if best_steps == -1 or walk < best_steps:
					best = start
					best_steps = walk
			var path: Array[Vector2i] = [best]
			while path[-1] != cell:
				path.append(came_from[path[-1]])
			return path
		ring = next_ring
		step += 1
	return []


## The charted tile `dark_path(cell)` starts from, NO_CELL when there is no way.
func chart_from(cell: Vector2i) -> Vector2i:
	var path := dark_path(cell)
	return HexMap.NO_CELL if path.is_empty() else path[0]


func can_farm(cell: Vector2i) -> bool:
	return not walking and can_farm_ground(cell)


func can_farm_ground(cell: Vector2i) -> bool:
	return charted(cell) and town_tier(cell) == -1 and cell != cave


## The farmable tile farthest out, where the hero camps while the game is shut; NO_CELL before any.
func best_farm() -> Vector2i:
	var best := HexMap.NO_CELL
	for cell in _states:
		if can_farm_ground(cell) and (best == HexMap.NO_CELL
				or HexGrid.distance(CENTER, cell) > HexGrid.distance(CENTER, best)):
			best = cell
	return best


## -1 for no town, and for one under the ice: it is not there yet as far as anyone can tell.
func town_tier(cell: Vector2i) -> int:
	return towns.tier_at(_spot(cell)) if is_land(cell) else -1


func can_enter_cave(cell: Vector2i) -> bool:
	return not walking and cave != HexMap.NO_CELL and cell == cave and charted(cell) and cell == player_cell


## Puts this world's cave down, once: within `CAVE_NEAR` steps of `near`, the wall tile just broken
## (`breach`), on the land beyond it -- never on a ring a wall stands or stood on, and never on a
## settlement (the user's, 2026-10-09). Chosen off the map seed. Returns whether it was put down now.
func place_cave(near: Vector2i) -> bool:
	if cave != HexMap.NO_CELL or near == HexMap.NO_CELL:
		return false
	var cells: Array[Vector2i] = []
	var wall := HexGrid.distance(CENTER, near)
	for cell in FortuneTeller.scour_cells(near, CAVE_NEAR):
		if HexGrid.distance(CENTER, cell) > wall and not on_wall_ring(cell) \
				and not towns.has_town(_spot(cell)):
			cells.append(cell)
	if cells.is_empty():
		return false
	cave = cells[_seeded([env_seed, "cave"]).randi() % cells.size()]
	_chartable.clear()
	# A tile already seen was named for its land (`name_of`): it is named again, for the cave.
	_names.erase(cave)
	if seen(cave):
		name_of(cave)
	# A road already drawn into it is taken up at its edge.
	for cell in HexGrid.neighbors(cave):
		if _drawn_roads.has(cell):
			_draw_road(cell)
	_draw_cell(cave)
	return true


func can_visit(cell: Vector2i) -> bool:
	return not walking and charted(cell) and cell == player_cell and town_tier(cell) != -1


func can_move_to(cell: Vector2i) -> bool:
	return not walking and charted(cell) and cell != player_cell and not route_to(cell).is_empty()


## The charted tiles the player would cross to `cell`, `cell` last and the tile they stand on left out.
## Empty when no way leads there.
func route_to(cell: Vector2i) -> Array[Vector2i]:
	if not charted(cell) or cell == player_cell:
		return []
	var came_from: Dictionary[Vector2i, Vector2i] = {player_cell: player_cell}
	var queue: Array[Vector2i] = [player_cell]
	var i := 0
	while i < queue.size():
		var at := queue[i]
		i += 1
		for next in HexGrid.neighbors(at):
			if not charted(next) or came_from.has(next):
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


## Returns the tiles the walk will cross, empty if it didn't start.
func move_to(cell: Vector2i) -> Array[Vector2i]:
	if walking or not charted(cell) or cell == player_cell:
		return []
	var route := route_to(cell)
	map.player.walk(route)
	return route


## Walks to the charted tile beside `cell`, then the one step onto it, where `player_cell` stands on
## uncharted land until the fight is decided. Returns the tiles crossed, empty if the walk didn't start:
## it never does for a tile further into the dark, whose way is fought for a tile at a time.
func walk_onto(cell: Vector2i) -> Array[Vector2i]:
	if not can_chart(cell):
		return []
	var path := dark_path(cell)
	if path.size() != 2:
		return []
	var route := route_to(path[0])
	route.append(cell)
	map.player.walk(route)
	if is_wall(cell):
		_generate_ahead()
	return route


## Every `is_home` but the one underfoot. A scan: ask on a press, never per frame.
func homes() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _states:
		if cell != player_cell and is_home(cell):
			cells.append(cell)
	return cells


## Whether the fortuneteller's homecoming can land on `cell`.
func is_home(cell: Vector2i) -> bool:
	return charted(cell) and (town_tier(cell) != -1 or cell == cave)


## Puts the player down on `cell` with no walk. Returns whether it happened, so the spell is never
## charged for a cell it could not take.
func jump_to(cell: Vector2i) -> bool:
	if walking or cell == player_cell or not is_home(cell):
		return false
	map.player.set_cell(cell)
	_on_player_arrived(cell)
	return true


func _on_player_arrived(cell: Vector2i) -> void:
	player_cell = cell
	arrived.emit(cell)


## Makes sure the map reaches WASTE_DEPTH past the wall: generates the land it lacks, and redraws the
## blends and roads of drawn tiles the new land touches. Returns whether the map grew.
func _cover() -> bool:
	var area := _cover_area(land_radius)
	if rect.encloses(area):
		return false
	var was := rect
	rect = rect.merge(area) if rect.has_area() else area
	_generate(rect)
	for cell in _states:
		# Tiles on the old edge had nothing beyond them to blend with; now they do.
		for next in HexGrid.neighbors(cell):
			if not was.has_point(next) and _envs.has(next):
				map.refresh_blends(cell)
				break
		# A road laid to one of the new towns can join a road already drawn, which then becomes a junction.
		if _drawn_roads.has(cell) and _drawn_roads[cell] != road_at(cell):
			_draw_road(cell)
	return true


## The square of cells the map must reach while the land reaches `radius`.
static func _cover_area(radius: int) -> Rect2i:
	var far := radius + 1 + WASTE_DEPTH
	return Rect2i(-far, -far, 2 * far + 1, 2 * far + 1)


## Sets the land the next wall's fall uncovers generating on another thread, for `_generate` to pick up:
## the environments, nearly all of the fall's time. The task touches only its copy of `_envs` and
## `EnvironmentGenerator`'s statics; a fight lost leaves the copy for the next try, which is sound
## because `_envs` changes nowhere but `_generate`.
func _generate_ahead() -> void:
	if _ahead_task != -1:
		return
	_ahead_area = rect.merge(_cover_area(land_radius + wall_step))
	_ahead_envs = _envs.duplicate()
	_ahead_task = WorkerThreadPool.add_task(EnvironmentGenerator.extend.bind(_ahead_envs, _ahead_area,
			hash([env_seed, _ahead_area])))


## The whole ring falls: the land reaches `wall_step` rings further, and the wasteland already seen
## inside that thaws into the land it always was, uncharted under the fog.
func _break_wall() -> void:
	Juice.sound(WALL_FALL_SOUND)
	var old_wall := land_radius + 1
	land_radius += wall_step
	_chartable.clear()
	_cover()
	# Lairs on the new land may lay their trails across tiles already drawn.
	for cell in _tracks:
		if seen(cell):
			_draw_tracks(cell)
	for cell in _states:
		if HexGrid.distance(CENTER, cell) == old_wall:
			_ice.remove_cell(cell)
			_draw_cell(cell)
		elif _ice.kind_at(cell) == IceOverlay.Kind.WASTE and not is_wasteland(cell):
			_ice.remove_cell(cell)
			map.set_ground(cell, _tiles[cell])
			map.fog.add_cell(cell)
			_draw_band(cell)
			_draw_cell(cell)


## What the map lacks in `area`: the environments, each cell's tile, and the roads of the town links it
## brings into reach. Cells already generated are left exactly as they are.
func _generate(area: Rect2i) -> void:
	var ahead := _ahead_task != -1 and _ahead_area == area
	if _ahead_task != -1:
		# Long done by now, unless the fight was quicker than the generating.
		WorkerThreadPool.wait_for_task_completion(_ahead_task)
		_ahead_task = -1
	if ahead:
		_envs = _ahead_envs
	else:
		EnvironmentGenerator.extend(_envs, area, hash([env_seed, area]))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			var cell := Vector2i(x, y)
			if not _tiles.has(cell) and _envs.has(cell):
				_tiles[cell] = _tile_name(cell)
	RoadNetwork.extend(towns, Rect2i(_spot(area.position), area.size), map.tileset.legal_road_masks(),
			_roads, _routed_links)
	_find_lairs()


## The ground tile a cell is drawn with: its environment's town where the world has one, else one of the
## environment's variants. Seeded per cell, so it never depends on when the cell was reached.
func _tile_name(cell: Vector2i) -> String:
	var env: String = _envs[cell]
	var tier := towns.tier_at(_spot(cell))
	if tier != -1:
		return "town_%s_%s" % [env, TownWorld.TIER_NAMES[tier]]
	var roll := _accent_roll(cell)
	var rng := _seeded([env_seed, "variant_kind", cell])
	var variant := "v%d" % rng.randi_range(1, 3)
	if roll < ACCENT_CHANCE and HexGrid.neighbors(cell).all(
			func(next: Vector2i) -> bool: return _accent_roll(next) > roll):
		variant = ACCENT_KINDS[rng.randi() % ACCENT_KINDS.size()]
	return "env_%s_%s" % [env, variant]


## A cell takes an accent only when its roll is under ACCENT_CHANCE and lower than every neighbour's,
## so two accents never touch whatever order cells are reached in.
func _accent_roll(cell: Vector2i) -> float:
	return _seeded([env_seed, "variant", cell]).randf()


## Charts `cell`, shows the land within `sight` steps of it as uncharted (at none or less, only the tile
## taken), and the player arrives or sets off for it. The caller reads the torch as it charts and never
## again. Returns how many tiles newly showed, or -1 if it can't be charted.
func chart(cell: Vector2i, sight := 1) -> int:
	if not can_chart(cell):
		return -1
	# Beside the charted land, the tile alone. Further into the dark only the dev's skip comes here,
	# and it takes the whole way at once, so charted land still never stands apart.
	var taken: Array[Vector2i] = dark_path(cell).slice(1)
	if is_wall(cell):
		breach = cell
		_break_wall()
	var shown := 0
	for step in taken:
		_show(step, State.CHARTED, true)
	for step in taken:
		shown += _reveal_around(step, maxi(sight, 0))
	# The fight was fought standing on it (`walk_onto`), so that is an arrival. Otherwise -- the dev's
	# skip -- the walk follows.
	if cell == player_cell:
		_on_player_arrived(cell)
	else:
		move_to(cell)
	return shown


## The fortuneteller's scour. Returns how many tiles showed, 0 when the spell would do nothing.
func scour(center: Vector2i) -> int:
	return _reveal_around(center, FortuneTeller.SCOUR_RADIUS)


## Shows every generated, unseen tile within `radius` steps of `center` as uncharted, and returns how
## many. Seen tiles are left alone: `_show` would put a charted one back under the veil. Sight cannot
## outrun generated land: the map reaches WASTE_DEPTH past the wall, and no chart is further out than it.
func _reveal_around(center: Vector2i, radius: int) -> int:
	var shown := 0
	for cell in FortuneTeller.scour_cells(center, radius):
		if _tiles.has(cell) and not seen(cell):
			_show(cell, State.UNCHARTED, true)
			shown += 1
	return shown


## The fortuneteller's roads: every settlement in `cell`'s ring of land, and the land
## `FortuneTeller.ROADS_RADIUS` round it, comes out uncharted. Returns how many tiles did.
func reveal_ring_towns(cell: Vector2i) -> int:
	var ring := ring_of(cell)
	var shown := 0
	for spot in towns.towns():
		var town := spot - origin
		if is_land(town) and ring_of(town) == ring and _tiles.has(town):
			shown += _reveal_around(town, FortuneTeller.ROADS_RADIUS)
	return shown


## For tests and screenshots: the whole land charted, the wall and the wasteland past it shown.
func reveal_all() -> void:
	for cell in _tiles:
		_show(cell, State.CHARTED if is_land(cell) else State.UNCHARTED)


## Draws a cell, or changes what the player knows about one already drawn. `lift` slides the edge fog
## off a newly seen cell away from the player rather than taking it off at once.
func _show(cell: Vector2i, to: State, lift := false) -> void:
	if not _tiles.has(cell) or state(cell) == to:
		return
	name_of(cell)  # named the moment it is first drawn, uncharted or not
	_edge_fog.add_cell(cell, map.player.position if lift else null)
	_chartable.clear()
	if is_wasteland(cell):
		# Snow and nothing under it: the land out there is not the player's to see until the wall falls.
		_states[cell] = to
		_ice.set_cell(cell, IceOverlay.Kind.WASTE)
		return
	if not seen(cell):
		map.set_ground(cell, _tiles[cell])
		_draw_band(cell)
		_ice.queue_redraw()  # land beside the ice takes the snow's drift
	_states[cell] = to
	if to == State.UNCHARTED:
		map.fog.add_cell(cell)
	else:
		map.fog.remove_cell(cell)
	_draw_cell(cell)


## The wall's band of ice over a wall cell's ground, along its ring.
func _draw_band(cell: Vector2i) -> void:
	if is_wall(cell):
		_ice.set_cell(cell, IceOverlay.Kind.WALL, _ring_edges(cell))


## The one list of what stands on a cell's ground, asked again whenever a cell changes: seen, charted,
## loaded, thawed by a falling wall, given the cave. The road and the chest take off what no longer belongs.
func _draw_cell(cell: Vector2i) -> void:
	_draw_road(cell)
	_draw_rubble(cell)
	_draw_chest(cell)
	_draw_tracks(cell)
	_draw_lair(cell)
	_draw_town(cell)
	_draw_cave(cell)


func _draw_road(cell: Vector2i) -> void:
	var mask := road_at(cell)
	_drawn_roads[cell] = mask
	if mask == 0:
		map.set_road(cell, "")
		return
	var material := map.tileset.road_material_for(_envs[cell])
	map.set_road(cell, map.tileset.road_name(material, HexGrid.mask_edges(mask)))


## A fallen wall's rubble, on every tile of its ring but a settlement's: the village stands in the breach.
func _draw_rubble(cell: Vector2i) -> void:
	if is_land(cell) and on_wall_ring(cell) and town_tier(cell) == -1:
		map.set_rubble(cell, _ring_edges(cell))


## Puts the sprite on or takes it off, as the cell now is.
func _draw_chest(cell: Vector2i) -> void:
	var chest := (seen(cell) or Settings.show_all_chests()) and has_chest(cell)
	if chest == _chest_sprites.has(cell):
		return
	if not chest:
		if is_instance_valid(_chest_sprites[cell]):
			_chest_sprites[cell].queue_free()
		_chest_sprites.erase(cell)
		return
	var sprite := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = load(CHEST_TEXTURE)
	texture.region = CHEST_REGION
	sprite.texture = texture
	sprite.position = map.ground_layer.map_to_local(cell)
	map.chests.add_child(sprite)
	_chest_sprites[cell] = sprite


## A lair's boss standing on its tile once seen (anywhere under the dev's `Settings.show_all_bosses()`), in
## its idle; taken off as the lair is won, with its trail.
func _draw_lair(cell: Vector2i) -> void:
	var boss := boss_at(cell) if seen(cell) or Settings.show_all_bosses() else ""
	if boss.is_empty() == not _lair_sprites.has(cell):
		return
	if boss.is_empty():
		if is_instance_valid(_lair_sprites[cell]):
			_lair_sprites[cell].queue_free()
		_lair_sprites.erase(cell)
		for step in trail_of(cell):
			_draw_tracks(step)
		return
	var actor := CombatActor.new()
	actor.setup_enemy(boss, LAIR_TALL)
	actor.position = map.ground_layer.map_to_local(cell) + LAIR_FEET
	map.chests.add_child(actor)
	_lair_sprites[cell] = actor


## The footprints on a seen tile, of every lair still standing whose trail crosses it: TRACK_PRINTS a
## tile, from its middle toward the next, the feet in turn all the way along.
func _draw_tracks(cell: Vector2i) -> void:
	if _track_sprites.has(cell):
		if is_instance_valid(_track_sprites[cell]):
			_track_sprites[cell].queue_free()
		_track_sprites.erase(cell)
	if not (seen(cell) or Settings.show_all_bosses()) or not _tracks.has(cell):
		return
	var prints := Node2D.new()
	var from := map.ground_layer.map_to_local(cell)
	for step: Array in _tracks[cell]:
		var boss := boss_at(step[0])
		if boss.is_empty():
			continue
		var sheet: Texture2D = load(tracks_path(boss))
		var way := map.ground_layer.map_to_local(step[1]) - from
		var heading := posmod(roundi(rad_to_deg(way.angle()) / 60.0), 6)
		var right := Vector2(-way.y, way.x).normalized()
		for at in TRACK_PRINTS:
			var foot := (int(step[2]) * TRACK_PRINTS + at) % 2
			var texture := AtlasTexture.new()
			texture.atlas = sheet
			texture.region = Rect2((heading * 2 + foot) * TRACK_CELL, 0, TRACK_CELL, TRACK_CELL)
			var sprite := Sprite2D.new()
			sprite.texture = texture
			sprite.position = from + way * at / TRACK_PRINTS + right * (TRACK_SPREAD if foot else -TRACK_SPREAD)
			prints.add_child(sprite)
	if prints.get_child_count() == 0:
		prints.free()
		return
	map.chests.add_child(prints)
	_track_sprites[cell] = prints


## Buildings only on land the player has seen: none on the wall or past it (`town_tier`).
func _draw_town(cell: Vector2i) -> void:
	if town_tier(cell) != -1 and seen(cell):
		map.set_town(cell, _tiles[cell], state(cell) == State.CHARTED)


## On land the player has seen, and never under the ice.
func _draw_cave(cell: Vector2i) -> void:
	if cell == cave and is_land(cell) and seen(cell) and _envs.has(cell):
		map.set_cave(cell, _envs[cell], charted(cell))
