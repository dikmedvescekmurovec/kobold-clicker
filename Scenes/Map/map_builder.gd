class_name MapBuilder
extends RefCounted
## Generates a window of the world and draws it as the player charts it: procedural environments, the world's
## towns drawn as the town sprite of the environment they stand on, and the roads between connected towns.
## Blend overlays follow automatically, since HexMap.set_ground redraws them.
##
## Every cell is in one of three states. HIDDEN cells are the fog of war: nothing is drawn for them at all.
## UNCHARTED cells are drawn under a grey veil (HexMap.fog): the player can see the land but hasn't looked at
## it, and can't go there. CHARTED cells are drawn plainly and can be walked to and over.
##
## The player starts on the center cell (0, 0), the only charted one, with its six neighbors uncharted
## around it. They chart a tile next to any charted one, which lifts the fog off the tiles behind it
## and sends them walking onto it; they can also walk back to any tile they have charted. Everything is generated up front, so what a tile turns out to be never depends on
## when it is found.

## The player has finished walking to `cell`.
signal arrived(cell: Vector2i)

## What the player knows about a cell.
enum State { HIDDEN, UNCHARTED, CHARTED }

## The land is a hexagon: every cell within `land_radius` steps of cell (0, 0). It starts this wide.
## So the first wall stands on ring 12 (the user's, 2026-09-28).
const START_LAND_RADIUS := 11
## The ring just outside the land is the ice wall, and beating any one tile of it brings the whole ring
## down: the land then reaches this many rings further, to the next wall. A multiple of `LEVEL_TILES`,
## with the first wall on one too, so every wall's ring starts a level: the land just past a wall is
## a level above the land just inside it (the user's, 2026-09-28).
const WALL_STEP := 12
## And how many under the Ring of Walls curse (`wall_step`).
const RING_OF_WALLS_STEP := 6
## How many rings of distance one tile level spans: level 1 is rings 0-3, level 2 rings 4-7, and on.
const LEVEL_TILES := 4
## How far past the wall the map is generated: the frozen wasteland the player can see out there, and
## real land under it for the wall to blend against and for the day the wall falls.
const WASTE_DEPTH := 5
## What a wall tile and a wasteland tile are called. Never saved: the land under them gets its own
## name once the wall is down.
const WALL_NAME := "The Ice Wall"
const WASTE_NAME := "Frozen Wasteland"
## The whole wall coming down (`_break_wall`).
const WALL_FALL_SOUND := preload("res://Sounds/Sfx/ice_wall_fall.ogg")
## Cell the map is centered on, and the only one visible together with its neighbors at the start.
const CENTER := Vector2i.ZERO
## About 1 in 10 environment tiles use an accent sprite (JSON meta accent_frequency: 1 in 8-12). The
## roll is a little over that because a cell beside a lower roll gives its accent up (`_tile_name`).
const ACCENT_CHANCE := 0.12
## The accent sprites every environment has, one picked per accent cell.
const ACCENT_KINDS: Array[String] = ["accent", "accent2", "accent3"]
## The first town sits exactly this many steps from the center cell, and no town is closer.
const START_TOWN_DISTANCE := 5
## How many open tiles hold a treasure chest, and how close to the start the nearest may be. The mimic
## waits in it: charting the tile fights it alone, and winning the tile takes the chest off the map.
const CHEST_CHANCE := 0.03
const CHEST_MIN_DISTANCE := 3
## The Gollux cave, the one way down into the dungeon: one a world, never inside the first wall. The
## nearest ring it may stand on is one past the first wall's own, so it is always behind the ice.
const CAVE_FIRST_RING := START_LAND_RADIUS + 2
## The closed brown chest, top-left of the pack's sheet.
const CHEST_TEXTURE := "res://Assets/Chests/Chests.png"
const CHEST_REGION := Rect2(2, 12, 28, 20)

var map: HexMap
var towns: TownWorld
## What the map has generated, in cells: the land, the wall and WASTE_DEPTH of wasteland. It only
## ever grows, when the wall falls.
var rect := Rect2i()
## How far the land reaches from cell (0, 0); ring `land_radius + 1` is the ice wall.
var land_radius := START_LAND_RADIUS
## How many rings a fallen wall opens: `WALL_STEP`, or fewer under the Ring of Walls, which the main
## scene says as the world is built. Never saved: it is the curse's, and the curse is the inventory's.
## **Only where the next wall stands moves with it** -- `Encounter.walls_inside`, which sizes every
## body, goes on counting in `WALL_STEP`s, so the land is as hard as it ever was and the extra walls
## are extra gates at the health their own ring gives them.
var wall_step := WALL_STEP
## Seed the environments are generated from; kept, since the map is generated in pieces as it grows.
var env_seed: int
## World spot at the center cell (0, 0).
var origin: Vector2i
## The small town START_TOWN_DISTANCE steps out, which a road connects to the center cell.
var start_town: Vector2i
## Where this world's Gollux cave stands, or `HexMap.NO_CELL` while there is none -- before any wall
## has fallen in any world (`place_cave`). Saved: the land it is chosen on is generated as the walls
## fall, and generation is never repeated.
var cave := HexMap.NO_CELL
## The cell the player stands on, which only changes once they have walked there.
var player_cell := CENTER
## Whether the player is on their way somewhere, and so can't be sent anywhere else.
var walking: bool:
	get: return map.player.is_walking()
## How many steps from the charted land a tile can be charted, as a Callable returning an int: 1, the
## tile beside it, unless the main scene says otherwise (the Nightwalker's Boots). Asked, not told,
## so taking the boots off is felt at the next hover.
var dark_reach := Callable()
## Every tile that can be charted now (`can_chart`), worked out once for the map as it stands and the
## reach it was worked out at: the hover asks on every move of the mouse.
var _chartable: Dictionary[Vector2i, bool] = {}
var _chartable_reach := 0

var _envs: Dictionary[Vector2i, String] = {}
## The land past the wall being fought for, generated on another thread (`_generate_ahead`): the
## WorkerThreadPool task (-1 when there is none), the area it fills and the copy of `_envs` it fills.
var _ahead_task := -1
var _ahead_area := Rect2i()
var _ahead_envs: Dictionary[Vector2i, String] = {}
var _tiles: Dictionary[Vector2i, String] = {}  # ground tile name per cell
## What each tile the player has seen is called, from the moment they first saw it. Not derived and
## not regenerated: see `name_of`.
var _names: Dictionary[Vector2i, String] = {}
var _roads: Dictionary[Vector2i, int] = {}  # road edge mask per world spot
var _routed_links: Dictionary[String, bool] = {}  # town links already routed, so a road is never laid twice
var _states: Dictionary[Vector2i, State] = {}
var _drawn_roads: Dictionary[Vector2i, int] = {}  # road mask each drawn cell shows, to spot the ones that change
var _chest_sprites: Dictionary[Vector2i, Sprite2D] = {}
var _ice: IceOverlay
var _edge_fog: EdgeFog


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
	builder._cover()

	map.clear_map()
	builder._add_ice()
	# Blends read the environment of every generated cell, not just the drawn ones, so a tile is drawn with the
	# same overlays whether its neighbors are already charted or still hidden.
	map.hidden_env = builder.env_at
	map.can_pick = builder.can_chart
	# Rebuilding the map hands the player over to the new builder, so any earlier one lets go.
	for connection in map.player.arrived.get_connections():
		map.player.arrived.disconnect(connection["callable"])
	map.player.arrived.connect(builder._on_player_arrived)
	# The player knows the tile they stand on and can see the ring around it, without having looked at it yet.
	builder._show(CENTER, State.CHARTED)
	for cell in HexGrid.neighbors(CENTER):
		builder._show(cell, State.UNCHARTED)
	builder.player_cell = CENTER
	map.set_player_cell(CENTER)
	return builder


## The map as plain data, for `MapSave` to write. Everything here either cannot be regenerated (the
## land and the roads are order-dependent, see MapSave) or must not be (the towns). `_tiles` is left
## out because `_tile_name` seeds per cell, so it is derived and cannot disagree with what it is
## derived from; so are `_drawn_roads` and the fog, which the drawing puts back.
##
## Nothing here touches `map`: this is called from the main scene's _exit_tree, where the HexMap
## child may already be gone -- which is also why `walking` is not asked about. A walk in progress
## is not part of a save. `player_cell` is the last tile actually reached, so a game closed
## mid-step resumes on the tile behind; the tile being walked to was set CHARTED before the walk
## started, so it costs the step and nothing else.
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


## Rebuilds the map a save holds and draws it, the mirror of `create()` -- and shorter than it,
## because the saved town world already has `clear_towns_near` and `ensure_small_town` in it and the
## start town's road is already among the saved roads. Nothing is generated and no town is touched.
##
## `towns` is the world out of the same save, through TownWorld.from_dict.
static func restore(map: HexMap, towns: TownWorld, save: MapSave) -> MapBuilder:
	assert(save.origin.y % 2 == 0, "MapBuilder origin row must be even")
	var builder := MapBuilder.new()
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
	# A save written before names existed brings back land the player has seen and no names for it.
	# They are filled in here rather than left to whatever asks first, so one load is all it takes
	# and the map on disk is whole again: a tile the player has looked at has a name.
	for cell in builder._states:
		builder.name_of(cell)

	map.clear_map()
	builder._add_ice()
	# Before anything is drawn, or the first cells get their blends worked out against land that
	# reads as empty. Same reason create() sets it before its own first _show.
	map.hidden_env = builder.env_at
	map.can_pick = builder.can_chart
	for connection in map.player.arrived.get_connections():
		map.player.arrived.disconnect(connection["callable"])
	map.player.arrived.connect(builder._on_player_arrived)
	builder._draw_saved()
	builder.player_cell = save.player_cell
	map.set_player_cell(save.player_cell)
	return builder


## Draws every cell the save had drawn, in one pass. `_show` is right for one tile appearing and
## wrong for a whole map arriving at once: it goes through HexMap.set_ground, which refreshes the
## blends of the cell *and its six neighbors*, so drawing N cells costs 7N refreshes of which all
## but N are repeats. The ground and the roads go down first and the blends are refreshed once per
## cell instead, which comes to the same picture -- a neighbor that isn't drawn has no ground, and
## refresh_blends does nothing to a cell with no ground.
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
		_draw_road(cell)
		if is_wall(cell):
			_ice.set_cell(cell, IceOverlay.Kind.WALL, _ring_edges(cell))
		if _states[cell] == State.UNCHARTED:
			map.fog.add_cell(cell)
		_draw_chest(cell)
		_draw_town(cell)
		_draw_cave(cell)
	for cell in _states:
		if _tiles.has(cell):
			map.refresh_blends(cell)


## The hexagon drawn at the start, in rows of 2, 3 and 2: the charted center cell and its six uncharted
## neighbors.
static func start_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = [CENTER]
	cells.append_array(HexGrid.neighbors(CENTER))
	return cells


## A save written before the wall has no radius: the wall goes on the first ring, counted the way the
## walls fall, that lies beyond everything the player has already seen, so nothing they knew is iced over.
static func migrated_radius(states: Dictionary) -> int:
	var farthest := 0
	for cell in states:
		if states[cell] != State.HIDDEN:
			farthest = maxi(farthest, HexGrid.distance(CENTER, cell))
	var falls := ceili(maxi(farthest - START_LAND_RADIUS, 0) / float(WALL_STEP))
	return START_LAND_RADIUS + WALL_STEP * falls


## The ice over the land's edge, and the fog lapping onto it. Made after `clear_map`, which frees
## whatever stands under `chests`.
func _add_ice() -> void:
	_ice = IceOverlay.new(map)
	_ice.name = "Ice"
	map.chests.add_child(_ice)
	_edge_fog = EdgeFog.new(map)
	_edge_fog.name = "EdgeFog"
	map.chests.add_child(_edge_fog)


## Whether `cell` is on the ice wall, the ring just outside the land.
func is_wall(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) == land_radius + 1


## A wall cell's two neighbours on its own ring, as `HexGrid.edge_mask`: where the wall's band runs.
func _ring_edges(cell: Vector2i) -> int:
	var mask := 0
	for edge in HexGrid.EDGES:
		if is_wall(HexGrid.neighbor(cell, edge)):
			mask |= 1 << edge
	return mask


## How many walls have come down in this world. What heirloom picks are paid against
## (`Inventory.credit_walls`), and what the fortuneteller waits for before she offers the way out.
func walls_fallen() -> int:
	return maxi(0, (land_radius - START_LAND_RADIUS) / wall_step)


## Whether `cell` lies past the wall, in the frozen wasteland: seen as snow, never walked on.
func is_wasteland(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) > land_radius + 1


## Whether `cell` is land the player can have: inside the wall.
func is_land(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) <= land_radius


## The world spot a map cell shows. `_envs`, `_tiles`, `_states` and `_drawn_roads` are keyed by cell;
## `_roads` and everything reached through `towns` are keyed by spot.
func _spot(cell: Vector2i) -> Vector2i:
	return origin + cell


## The environment generated for a cell, drawn or not, and "" outside the map.
func env_at(cell: Vector2i) -> String:
	return _envs.get(cell, "")


## What a tile is called. A tile is named the first time it is asked about, which `_show` makes the
## first time the player sees it, and the name is kept from then on -- in `_names` and in the save.
##
## It is stored rather than worked out again each time even though `TileNames.generate` is a pure
## function of the seed and the cell, for the same reason the town world is written down: that is a
## property of today's tables, not a promise, and a place the player has fought over must not be
## renamed by a later build widening a word list. Cells the map has never generated have no name --
## there is nothing there to call anything.
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


## The road edges on a cell, as a mask, and 0 where there is no road. Towns carry none, and nor does the
## cave: roads stop at their edge.
func road_at(cell: Vector2i) -> int:
	if towns.has_town(_spot(cell)) or cell == cave:
		return 0
	return _roads.get(_spot(cell), 0)


## Which battle backdrop a cell fights on: what the world put there, read in the order it matters.
## A town is what you see whether or not a road runs to it, so it is asked about first.
func area_variant(cell: Vector2i) -> String:
	# Whatever stands under the ice, the wall is fought in the open.
	if is_wall(cell):
		return "plain"
	match towns.tier_at(_spot(cell)):
		TownWorld.Tier.SMALL:
			return "village"
		TownWorld.Tier.MEDIUM:
			return "town"
		TownWorld.Tier.FORTRESS:
			return "fortress"
	return "road" if road_at(cell) != 0 else "plain"


## Whether a treasure chest still stands on `cell`: open land (no town, not near the start) picked by a
## per-cell roll, until the tile is charted. Derived from the seed rather than saved, the way `_tile_name`
## is, and a won tile is charted, so nothing about an opened chest needs writing down.
func has_chest(cell: Vector2i) -> bool:
	if not _envs.has(cell) or not is_land(cell) or charted(cell) or towns.has_town(_spot(cell)) \
			or cell == cave or HexGrid.distance(CENTER, cell) < CHEST_MIN_DISTANCE:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "chest", cell])
	return rng.randf() < CHEST_CHANCE


## What the land on `cell` does to its own fight (`TileMods`): open land past the second wall, and
## nothing where the fight is a set piece -- a settlement, a chest, the wall, the cave. Derived from the seed the
## way `has_chest` is, so nothing is saved. `wild` is the Wild Tiles curse, which the builder cannot
## know: whoever asks passes it.
func mods_of(cell: Vector2i, wild := false) -> Array[String]:
	if not _envs.has(cell) or not is_land(cell) or towns.has_town(_spot(cell)) or has_chest(cell) \
			or on_wall_ring(cell) or cell == cave:
		return []
	return TileMods.for_cell(env_seed, cell, ring_of(cell), wild)


## The closest chest to the player anywhere on the generated map, fog or not; NO_CELL when there is none.
## `unseen_only` leaves out a chest whose tile the player can already see: it is drawn there, so a
## fortuneteller pointing at it would be selling what is in plain sight.
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


## Every environment the map has actually generated within `steps` of `cell`, however little of it the
## player has seen. What it is for is a bounty board: a town only posts monsters that live on land
## that is really out there, so a target is always something that can be walked to and found.
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


## Puts the chest sprite on a drawn cell that has one, and takes it off one that no longer does.
## Under the dev's `Settings.show_all_chests` a hidden cell's chest is drawn too.
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


## The level of a tile, in even bands of `LEVEL_TILES` rings: rings 0-3 are level 1, 4-7 level 2,
## and on. The walls stand on band edges, so beating one steps the level up. (It was bands that
## widened by one a level, which left a whole circle two levels deep past the first wall; replaced
## by the user, 2026-09-28.)
##
## It is what the side panel shows and the ceiling on what can drop here. Note it is not the whole
## story of how hard a tile is: enemy health is smooth in the distance while this is banded, so two
## tiles at opposite ends of one band read the same number and do not fight the same.
static func level_of(cell: Vector2i) -> int:
	return _level_at(HexGrid.distance(CENTER, cell))


@warning_ignore("integer_division")
static func _level_at(steps: int) -> int:
	return 1 + steps / LEVEL_TILES


## The first ring of level `level`: where its band begins.
static func first_step(level: int) -> int:
	return (maxi(level, 1) - 1) * LEVEL_TILES


## The deepest level of land in `cell`'s circle: the level of its outer ring, the one just inside the
## next wall. Every tile in a circle answers the same, so what is gated on it moves a wall at a time.
static func circle_level(cell: Vector2i) -> int:
	return _level_at(START_LAND_RADIUS + (circle_of(cell) - 1) * WALL_STEP)


## Which circle of land `cell` is in: 1 inside the first ice wall, 2 out to the second, and so on. A
## wall's own ring counts with the land its fall opens. Counted by distance in plain `WALL_STEP`s, the
## way the Ring of Walls goes on counting, so that curse moves no circle. What a circle is for:
## the smith's cap (`circle_level`).
static func circle_of(cell: Vector2i) -> int:
	return 1 + maxi(0, ceili((HexGrid.distance(CENTER, cell) - START_LAND_RADIUS) / float(WALL_STEP)))


## What the player knows about a cell. Cells outside the map are HIDDEN.
func state(cell: Vector2i) -> State:
	return _states.get(cell, State.HIDDEN)


func charted(cell: Vector2i) -> bool:
	return state(cell) == State.CHARTED


## Whether anything is drawn for a cell: it is charted, or seen under the fog.
func seen(cell: Vector2i) -> bool:
	return state(cell) != State.HIDDEN


## Whether the player can chart this cell: generated land or wall within `reach()` steps of a charted tile
## -- next to one, but under the Nightwalkers -- across land (`dark_path`, every tile of which the main
## scene has them fight for in turn), and they have to be standing still. **Seen or not:** the first
## tile into the fog can be taken blind, which is how a player under the Thick Fog, whose charts
## uncover nothing round them, moves at all. With a ring of sight or more every tile beside the charted
## land has been seen already, so for everyone else this is the rule it was. Every charted tile is
## reachable, since charting only ever grows out from the start one tile at a time.
func can_chart(cell: Vector2i) -> bool:
	if walking:
		return false
	var steps := reach()
	if steps != _chartable_reach:
		_chartable.clear()
		_chartable_reach = steps
	if _chartable.is_empty():
		_find_chartable(steps)
	return _chartable.has(cell)


## How many steps into the dark a tile can be charted from: `dark_reach`'s answer, 1 without one.
func reach() -> int:
	return maxi(1, int(dark_reach.call())) if dark_reach.is_valid() else 1


## Every tile `steps` or fewer from the charted land, out across the land between, into
## `_chartable`: one walk out from every charted tile at once, a ring of steps at a time.
func _find_chartable(steps: int) -> void:
	var ring: Array[Vector2i] = []
	for cell: Vector2i in _states:
		if charted(cell):
			ring.append(cell)
	for step in steps:
		var next_ring: Array[Vector2i] = []
		for at in ring:
			for next in HexGrid.neighbors(at):
				if _chartable.has(next) or not _tiles.has(next) or charted(next) or is_wasteland(next):
					continue
				_chartable[next] = true
				# Land only goes on: the wall is where a way ends, never what it crosses.
				if is_land(next):
					next_ring.append(next)
		ring = next_ring


## The way to `cell` from the charted land: the charted tile it starts on, the uncharted tiles between,
## each beside the last, and `cell` last -- every one of them fought for in turn (the main scene's
## `_dark_way`). The fewest tiles, and of those the start the player is fewest steps from. Empty when
## no charted tile is within `reach()`.
func dark_path(cell: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary[Vector2i, Vector2i] = {cell: cell}
	var ring: Array[Vector2i] = [cell]
	var steps := reach()
	for step in steps:
		var starts: Array[Vector2i] = []
		var next_ring: Array[Vector2i] = []
		for at in ring:
			for next in HexGrid.neighbors(at):
				if came_from.has(next):
					continue
				if charted(next):
					came_from[next] = at
					starts.append(next)
				elif step + 1 < steps and _tiles.has(next) and is_land(next):
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
	return []


## The charted tile a way onto `cell` starts from, the one the player is fewest steps from: next to it,
## or, into the dark, where the fewest tiles lie between. NO_CELL when none is within `reach()`.
func chart_from(cell: Vector2i) -> Vector2i:
	var path := dark_path(cell)
	return HexMap.NO_CELL if path.is_empty() else path[0]


## Whether the player can farm this cell: a tile already taken, which the player can go back to and
## fight on for as long as they like. Unlike charting, it asks nothing about where they stand --
## a run is a thing you choose to do, not a step you take. Never a settlement or the cave: those are
## taken once and then visited, not hunted.
func can_farm(cell: Vector2i) -> bool:
	return not walking and can_farm_ground(cell)


## The best ground taken so far, where the hero camps while the game is shut: the farmable tile
## farthest out, since a body's worth grows with the distance. NO_CELL before anything is.
func best_farm() -> Vector2i:
	var best := HexMap.NO_CELL
	for cell in _states:
		if can_farm_ground(cell) and (best == HexMap.NO_CELL
				or HexGrid.distance(CENTER, cell) > HexGrid.distance(CENTER, best)):
			best = cell
	return best


## The tier of the settlement on `cell`, or -1 where there is no town. The one place outside this file
## a cell is crossed to a world spot for the towns' sake, so nobody else has to know about `origin`.
func town_tier(cell: Vector2i) -> int:
	# A town under the ice is not there yet as far as anyone can tell.
	return towns.tier_at(_spot(cell)) if is_land(cell) else -1


## Whether `cell` is taken ground a run could be fought on: charted, and neither a settlement nor the cave.
func can_farm_ground(cell: Vector2i) -> bool:
	return charted(cell) and town_tier(cell) == -1 and cell != cave


## Whether the player can go down into the cave on `cell`: the cave, charted, stood on, and no walk
## under way -- Enter town's rule, because going down is being there.
func can_enter_cave(cell: Vector2i) -> bool:
	return not walking and cave != HexMap.NO_CELL and cell == cave and charted(cell) and cell == player_cell


## Puts this world's cave down, once: on a cell from `CAVE_FIRST_RING` out to `reach` -- how far the
## land has ever reached, in any world (`Inventory.farthest_land`) -- never on a ring a wall stands or
## stood on, and never on a settlement. Nothing while `reach` is short of the first ring it may stand
## on, which is every world before the first wall ever falls. Chosen off the map seed, so a world
## reloaded before its first save chooses the same. Returns whether it was put down now.
##
## The land out there need not be generated yet: the cell is chosen by where it lies and nothing else,
## and it is drawn in its ground's picture once the wall over it has fallen and it has been seen.
func place_cave(reach: int) -> bool:
	if cave != HexMap.NO_CELL or reach < CAVE_FIRST_RING:
		return false
	var cells: Array[Vector2i] = []
	for cell in FortuneTeller.scour_cells(CENTER, reach):
		if HexGrid.distance(CENTER, cell) >= CAVE_FIRST_RING and not on_wall_ring(cell) \
				and not towns.has_town(_spot(cell)):
			cells.append(cell)
	if cells.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "cave"])
	cave = cells[rng.randi() % cells.size()]
	_chartable.clear()
	# A road already drawn over it or into it is taken up at its edge, and a cell already seen shows it.
	for cell: Vector2i in [cave] + HexGrid.neighbors(cave):
		if _drawn_roads.has(cell):
			_draw_road(cell)
	_draw_cave(cave)
	return true


## Whether the player can walk into the town on `cell`: a charted settlement they are already standing
## on, and no walk under way. Standing on it rather than beside it, because visiting a town is being
## there -- unlike farming, which is a thing you choose to do from anywhere.
func can_visit(cell: Vector2i) -> bool:
	return not walking and charted(cell) and cell == player_cell and town_tier(cell) != -1


## Whether the player can travel to this cell: a charted tile other than the one they stand on, with a route
## of charted tiles leading to it, and no walk under way.
func can_move_to(cell: Vector2i) -> bool:
	return not walking and charted(cell) and cell != player_cell and not route_to(cell).is_empty()


## The tiles the player would cross on the way to `cell`, the destination last and the tile they stand on left
## out. Every tile of the route is charted; the route is empty when none leads there.
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


## Sends the player walking to a charted tile. They arrive a couple of seconds per tile later, when
## `arrived` is emitted. Returns the tiles they will cross, empty if the walk didn't start.
func move_to(cell: Vector2i) -> Array[Vector2i]:
	if walking or not charted(cell) or cell == player_cell:
		return []
	var route := route_to(cell)
	map.player.walk(route)
	return route


## Sends the player onto a tile beside the charted land they are about to fight for: to the charted tile
## beside it (`chart_from`), then the one step onto it, where `player_cell` stands on uncharted land
## until the fight is decided. Returns the tiles they will cross, empty if the walk didn't start -- as
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


## The settlements a homecoming could put the player down on: charted, and not the one they stand on.
## One scan of everything they have seen, so ask it on a press and never per frame.
func homes() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in _states:
		if cell != player_cell and charted(cell) and town_tier(cell) != -1:
			cells.append(cell)
	return cells


## The fortuneteller's homecoming: the player is put down on a settlement they have already charted,
## with no walk and no route -- the one way anybody moves without crossing the ground between. Whether
## it happened, so the spell is never charged for a cell it could not take. `_on_player_arrived` is
## what the end of a walk calls, so everything that follows an arrival follows this too.
func jump_to(cell: Vector2i) -> bool:
	if walking or not charted(cell) or cell == player_cell or town_tier(cell) == -1:
		return false
	map.player.set_cell(cell)
	_on_player_arrived(cell)
	return true


func _on_player_arrived(cell: Vector2i) -> void:
	player_cell = cell
	arrived.emit(cell)


## Makes sure the map reaches WASTE_DEPTH past the wall, generating the new land (and the roads and towns
## on it) without touching what is already there, and redrawing the blends and roads of drawn tiles the new
## land touches. Returns whether the map grew.
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


## The square of cells the map must reach while the land reaches `radius`: WASTE_DEPTH past the wall.
static func _cover_area(radius: int) -> Rect2i:
	var reach := radius + 1 + WASTE_DEPTH
	return Rect2i(-reach, -reach, 2 * reach + 1, 2 * reach + 1)


## Sets the land the next wall's fall uncovers generating on another thread, so the walk to the wall
## and the fight for it are spent on what is otherwise seconds of pause when it falls (`_generate`
## picks it up). Only the environments, which are nearly all of the time and touch nothing but a copy
## of `_envs`; a fight lost leaves the copy waiting for the next try, since `_envs` cannot change
## while the wall stands.
func _generate_ahead() -> void:
	if _ahead_task != -1:
		return
	_ahead_area = rect.merge(_cover_area(land_radius + wall_step))
	_ahead_envs = _envs.duplicate()
	_ahead_task = WorkerThreadPool.add_task(EnvironmentGenerator.extend.bind(_ahead_envs, _ahead_area,
			hash([env_seed, _ahead_area])))


## Brings the whole ice wall down: the land reaches WALL_STEP rings further, the next wall stands at its
## edge, and the wasteland the player has already seen inside that thaws into the land it always was,
## uncharted under the fog.
func _break_wall() -> void:
	Juice.sound(WALL_FALL_SOUND)
	var old_wall := land_radius + 1
	land_radius += wall_step
	_chartable.clear()
	_cover()
	for cell in _states:
		if HexGrid.distance(CENTER, cell) == old_wall:
			_ice.remove_cell(cell)
			_draw_town(cell)
			_draw_cave(cell)
		elif _ice.kind_at(cell) == IceOverlay.Kind.WASTE and not is_wasteland(cell):
			_ice.remove_cell(cell)
			map.set_ground(cell, _tiles[cell])
			_draw_road(cell)
			map.fog.add_cell(cell)
			if is_wall(cell):
				_ice.set_cell(cell, IceOverlay.Kind.WALL, _ring_edges(cell))
			_draw_chest(cell)
			_draw_town(cell)
			_draw_cave(cell)


## Fills in everything the map needs for `area`: the environments of the cells it doesn't have yet, the tile
## each one is drawn with, and the roads of the town links it brings into reach. Cells already generated are
## left exactly as they are, so the land the player has seen never changes under them.
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
	var roll := _accent_roll(cell)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "variant_kind", cell])
	var variant := "v%d" % rng.randi_range(1, 3)
	if roll < ACCENT_CHANCE and HexGrid.neighbors(cell).all(func(n: Vector2i) -> bool: return _accent_roll(n) > roll):
		variant = ACCENT_KINDS[rng.randi() % ACCENT_KINDS.size()]
	return "env_%s_%s" % [env, variant]


## A cell's accent roll. A cell takes an accent only when its roll is under ACCENT_CHANCE and lower
## than every neighbour's, so two accents never touch whatever order cells are reached in.
func _accent_roll(cell: Vector2i) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "variant", cell])
	return rng.randf()


## Charts a tile the player can see next to them: its grey veil comes off, the land within `sight` steps of
## it comes out of the fog as uncharted, and the player sets off for it, arriving a couple of seconds later.
## `sight` is the two rings behind the tile for a player carrying nothing (`main_scene.BASE_SIGHT`) and further with a torch in hand;
## at none or less -- the Thick Fog's, with no torch held -- only the tile taken comes out of the fog.
## Returns how many tiles newly showed, or -1 if it can't be charted.
##
## The caller reads the torch at the moment it charts and never again, so a torch put on afterwards uncovers
## nothing and one taken off hides nothing: what a tile showed when it was taken is what it showed.
func chart(cell: Vector2i, sight := 1) -> int:
	if not can_chart(cell):
		return -1
	# Beside the charted land, the tile alone. Further into the dark only the dev's skip comes here,
	# and it takes the whole way at once, so charted land still never stands apart.
	var taken: Array[Vector2i] = dark_path(cell).slice(1)
	if is_wall(cell):
		_break_wall()
	var shown := 0
	for step in taken:
		_show(step, State.CHARTED, true)
	for step in taken:
		shown += _reveal_around(step, maxi(sight, 0))
	# The fight was fought standing on it (`walk_onto`), so that is an arrival. Otherwise -- the dev's
	# skip -- looking at the tile next door is the first half of going there, and the walk follows.
	if cell == player_cell:
		_on_player_arrived(cell)
	else:
		move_to(cell)
	return shown


## The fortuneteller's scour: every tile round `center` that is still in the dark comes out of it as
## uncharted land, to be looked at and walked towards but not yet stood on. Returns how many tiles
## showed, 0 when the spell would do nothing.
func scour(center: Vector2i) -> int:
	return _reveal_around(center, FortuneTeller.SCOUR_RADIUS)


## Takes the fog off every tile within `radius` steps of `center` that the map has generated and the
## player has not seen yet, and says how many that was. Tiles already seen are left alone -- `_show`
## would put a charted one back under the veil -- and land the map has not generated is not there to
## show. Nothing is left permanently dark by that last rule: the map is generated WASTE_DEPTH rings past
## the wall, and a chart is never further out than the wall, so a few steps of sight cannot reach past it.
func _reveal_around(center: Vector2i, radius: int) -> int:
	var shown := 0
	for cell in FortuneTeller.scour_cells(center, radius):
		if _tiles.has(cell) and not seen(cell):
			_show(cell, State.UNCHARTED, true)
			shown += 1
	return shown


## Whether `cell` is on a ring where a wall stands or stood, counted in `wall_step`s.
func on_wall_ring(cell: Vector2i) -> bool:
	var past := HexGrid.distance(CENTER, cell) - START_LAND_RADIUS - 1
	return past >= 0 and past % wall_step == 0


## Which ring of land `cell` stands in: 0 inside where the first wall stood, n between the nth wall
## and the next. Counted in `wall_step`s, so under the Ring of Walls a ring is the land between its walls.
func ring_of(cell: Vector2i) -> int:
	return maxi(0, ceili(float(HexGrid.distance(CENTER, cell) - START_LAND_RADIUS) / wall_step))


## The fortuneteller's roads: every settlement in the same ring of land as `cell`, and the land
## `FortuneTeller.ROADS_RADIUS` round it, comes out of the dark as uncharted, the way the scour shows
## land. Returns how many tiles did.
func reveal_ring_towns(cell: Vector2i) -> int:
	var ring := ring_of(cell)
	var shown := 0
	for spot in towns.towns():
		var town := spot - origin
		if is_land(town) and ring_of(town) == ring and _tiles.has(town):
			shown += _reveal_around(town, FortuneTeller.ROADS_RADIUS)
	return shown


## Charts the whole land at once, for tests and screenshots, and shows the wall and the wasteland past it.
func reveal_all() -> void:
	for cell in _tiles:
		_show(cell, State.CHARTED if is_land(cell) else State.UNCHARTED)


## Map cells exactly START_TOWN_DISTANCE steps from the center cell (0, 0), where the guaranteed small town may go.
static func start_town_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell in FortuneTeller.scour_cells(CENTER, START_TOWN_DISTANCE):
		if HexGrid.distance(CENTER, cell) == START_TOWN_DISTANCE:
			cells.append(cell)
	return cells


## Draws a cell, or just changes what the player knows about one that is already drawn. `lift` slides
## the fog off a newly seen cell away from the player rather than taking it off at once.
func _show(cell: Vector2i, to: State, lift := false) -> void:
	if not _tiles.has(cell) or state(cell) == to:
		return
	# Named the moment it is first drawn, uncharted or not: seeing a place is meeting it, and a
	# tile the player has been looking at for an hour should not be nameless when they walk in.
	name_of(cell)
	_edge_fog.add_cell(cell, map.player.position if lift else null)
	_chartable.clear()
	if is_wasteland(cell):
		# Snow and nothing under it: the land out there is not the player's to see until the wall falls.
		_states[cell] = to
		_ice.set_cell(cell, IceOverlay.Kind.WASTE)
		return
	if not seen(cell):
		map.set_ground(cell, _tiles[cell])
		_draw_road(cell)
		if is_wall(cell):
			_ice.set_cell(cell, IceOverlay.Kind.WALL, _ring_edges(cell))
		else:
			_ice.queue_redraw()  # land beside the ice takes the snow's drift
	_states[cell] = to
	if to == State.UNCHARTED:
		map.fog.add_cell(cell)
	else:
		map.fog.remove_cell(cell)
	_draw_chest(cell)
	_draw_town(cell)
	_draw_cave(cell)


## A settlement's buildings, over the fog (`HexMap.set_town`), on land the player has seen. None on the
## wall or past it: the ice is over whatever stands there until the wall falls.
func _draw_town(cell: Vector2i) -> void:
	if town_tier(cell) != -1 and seen(cell):
		map.set_town(cell, _tiles[cell], state(cell) == State.CHARTED)


## The cave's mouth, in the picture of the ground it stands on, over the fog the way a settlement's
## buildings are -- on land the player has seen, and never under the ice.
func _draw_cave(cell: Vector2i) -> void:
	if cell == cave and is_land(cell) and seen(cell) and _envs.has(cell):
		map.set_cave(cell, _envs[cell], charted(cell))
