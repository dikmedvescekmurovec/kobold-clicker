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
const START_LAND_RADIUS := 10
## The ring just outside the land is the ice wall, and beating any one tile of it brings the whole ring
## down: the land then reaches this many rings further, to the next wall.
const WALL_STEP := 10
## And how many under the Ring of Walls curse (`wall_step`).
const RING_OF_WALLS_STEP := 5
## How far past the wall the map is generated: the frozen wasteland the player can see out there, and
## real land under it for the wall to blend against and for the day the wall falls.
const WASTE_DEPTH := 5
## What a wall tile and a wasteland tile are called. Never saved: the land under them gets its own
## name once the wall is down.
const WALL_NAME := "The Ice Wall"
const WASTE_NAME := "Frozen Wasteland"
## Cell the map is centered on, and the only one visible together with its neighbors at the start.
const CENTER := Vector2i.ZERO
## About 1 in 10 environment tiles use the accent sprite (JSON meta accent_frequency: 1 in 8-12).
const ACCENT_CHANCE := 0.1
## The first town sits exactly this many steps from the center cell, and no town is closer.
const START_TOWN_DISTANCE := 5
## How many open tiles hold a treasure chest, and how close to the start the nearest may be. The mimic
## waits in it: charting the tile fights it alone, and winning the tile takes the chest off the map.
const CHEST_CHANCE := 0.03
const CHEST_MIN_DISTANCE := 3
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
## The cell the player stands on, which only changes once they have walked there.
var player_cell := CENTER
## Whether the player is on their way somewhere, and so can't be sent anywhere else.
var walking: bool:
	get: return map.player.is_walking()

var _envs: Dictionary[Vector2i, String] = {}
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
		if is_wasteland(cell):
			_ice.set_cell(cell, IceOverlay.Kind.WASTE)
			continue
		map.place_ground(cell, _tiles[cell])
		_draw_road(cell)
		if is_wall(cell):
			_ice.set_cell(cell, IceOverlay.Kind.WALL)
		if _states[cell] == State.UNCHARTED:
			map.fog.add_cell(cell)
		_draw_chest(cell)
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


## The ice over the land's edge. Made after `clear_map`, which frees whatever stands under `chests`.
func _add_ice() -> void:
	_ice = IceOverlay.new(map)
	_ice.name = "Ice"
	map.chests.add_child(_ice)


## Whether `cell` is on the ice wall, the ring just outside the land.
func is_wall(cell: Vector2i) -> bool:
	return HexGrid.distance(CENTER, cell) == land_radius + 1


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
			TownWorld.TIER_NAMES[tier] if tier != -1 else "")
	return _names[cell]


## The road edges on a cell, as a mask, and 0 where there is no road. Towns carry none: roads stop at their edge.
func road_at(cell: Vector2i) -> int:
	if towns.has_town(_spot(cell)):
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
	if not _envs.has(cell) or not is_land(cell) or charted(cell) or towns.has_town(_spot(cell)) 			or HexGrid.distance(CENTER, cell) < CHEST_MIN_DISTANCE:
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([env_seed, "chest", cell])
	return rng.randf() < CHEST_CHANCE


## What the land on `cell` does to its own fight (`TileMods`): open land past the second wall, and
## nothing where the fight is a set piece -- a settlement, a chest, the wall. Derived from the seed the
## way `has_chest` is, so nothing is saved. `wild` is the Wild Tiles curse, which the builder cannot
## know: whoever asks passes it.
func mods_of(cell: Vector2i, wild := false) -> Array[String]:
	if not _envs.has(cell) or not is_land(cell) or towns.has_town(_spot(cell)) or has_chest(cell):
		return []
	return TileMods.for_cell(env_seed, cell, Encounter.walls_inside(cell), wild)


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


## The closest tile to the player whose land is one of `envs`, and NO_CELL when they have seen none.
## Only tiles they have laid eyes on: pointing at land under the fog of war would be telling them
## about a place they have not found. A **charted** tile wins a tie, because a charted one can be
## walked to and farmed where a merely seen one is only somewhere to head for.
##
## Measured from where the player stands rather than from whoever is asking, and **never a
## settlement**: a town is a set piece rather than hunting ground, and the one the player is standing
## in would otherwise be the nearest tile of its own land every time it was asked.
##
## `min_level` leaves out land shallower than that: a bounty counts kills only on land as deep as the
## town that posted it, and pointing at a tile that would not count is worse than pointing at none.
## ponytail: scans every seen cell, like `nearest_chest`; it is asked when a page is drawn.
func nearest_env(envs: PackedStringArray, min_level := 0) -> Vector2i:
	var best := HexMap.NO_CELL
	var best_steps := -1
	var best_charted := false
	for cell in _states:
		if not seen(cell) or not is_land(cell) or not (env_at(cell) in envs) or towns.has_town(_spot(cell)) \
				or level_of(cell) < min_level:
			continue
		var steps := HexGrid.distance(player_cell, cell)
		var is_charted := charted(cell)
		if best_steps != -1 and (steps > best_steps
				or (steps == best_steps and not (is_charted and not best_charted))):
			continue
		best = cell
		best_steps = steps
		best_charted = is_charted
	return best


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


## The level of a tile, in bands that widen as they go: the middle tile alone is level 1, the next
## two rings are level 2, the three after that level 3, and so on. Band n is n tiles wide, so level n
## begins at the nth triangular number, and this is that series inverted. Levels come quickly off the
## start, where one step is a real change, and slow down at the frontier, where the walk is long.
##
## It is what the side panel shows and the ceiling on what can drop here. Note it is not the whole
## story of how hard a tile is: enemy health is smooth in the distance while this is banded, so two
## tiles at opposite ends of one band read the same number and do not fight the same.
static func level_of(cell: Vector2i) -> int:
	return int((1.0 + sqrt(1.0 + 8.0 * HexGrid.distance(CENTER, cell))) / 2.0)


## What the player knows about a cell. Cells outside the map are HIDDEN.
func state(cell: Vector2i) -> State:
	return _states.get(cell, State.HIDDEN)


func charted(cell: Vector2i) -> bool:
	return state(cell) == State.CHARTED


## Whether anything is drawn for a cell: it is charted, or seen under the fog.
func seen(cell: Vector2i) -> bool:
	return state(cell) != State.HIDDEN


## Whether the player can chart this cell: generated land or wall next to any charted tile, and they have
## to be standing still. **Seen or not:** the first tile into the fog can be taken blind, which is how
## a player under the Thick Fog, whose charts uncover nothing round them, moves at all. With a ring of
## sight or more every such tile has been seen already, so for everyone else this is the rule it was.
## Every charted tile is reachable, since charting only ever grows out from the start.
func can_chart(cell: Vector2i) -> bool:
	return not walking and _tiles.has(cell) and not charted(cell) and not is_wasteland(cell) \
			and chart_from(cell) != HexMap.NO_CELL


## The charted tile next to `cell` the player is fewest steps from: where they stand if it borders `cell`,
## otherwise where they walk to first. NO_CELL when no charted tile borders it.
func chart_from(cell: Vector2i) -> Vector2i:
	var best := HexMap.NO_CELL
	var best_steps := -1
	for next in HexGrid.neighbors(cell):
		if not charted(next):
			continue
		var steps := 0 if next == player_cell else route_to(next).size()
		if best_steps == -1 or steps < best_steps:
			best = next
			best_steps = steps
	return best


## Whether the player can farm this cell: a tile already taken, which the player can go back to and
## fight on for as long as they like. Unlike charting, it asks nothing about where they stand --
## a run is a thing you choose to do, not a step you take. Never a settlement: a town is taken once
## and then visited, not hunted.
func can_farm(cell: Vector2i) -> bool:
	return not walking and charted(cell) and town_tier(cell) == -1


## The tier of the settlement on `cell`, or -1 where there is no town. The one place outside this file
## a cell is crossed to a world spot for the towns' sake, so nobody else has to know about `origin`.
func town_tier(cell: Vector2i) -> int:
	# A town under the ice is not there yet as far as anyone can tell.
	return towns.tier_at(_spot(cell)) if is_land(cell) else -1


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
	var reach := land_radius + 1 + WASTE_DEPTH
	var area := Rect2i(-reach, -reach, 2 * reach + 1, 2 * reach + 1)
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


## Brings the whole ice wall down: the land reaches WALL_STEP rings further, the next wall stands at its
## edge, and the wasteland the player has already seen inside that thaws into the land it always was,
## uncharted under the fog.
func _break_wall() -> void:
	var old_wall := land_radius + 1
	land_radius += wall_step
	_cover()
	for cell in _states:
		if HexGrid.distance(CENTER, cell) == old_wall:
			_ice.remove_cell(cell)
		elif _ice.kind_at(cell) == IceOverlay.Kind.WASTE and not is_wasteland(cell):
			_ice.remove_cell(cell)
			map.set_ground(cell, _tiles[cell])
			_draw_road(cell)
			map.fog.add_cell(cell)
			if is_wall(cell):
				_ice.set_cell(cell, IceOverlay.Kind.WALL)
			_draw_chest(cell)


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


## Charts a tile the player can see next to them: its grey veil comes off, the land within `sight` steps of
## it comes out of the fog as uncharted, and the player sets off for it, arriving a couple of seconds later.
## `sight` is the one ring behind the tile for a player carrying nothing and further with a torch in hand;
## at none or less -- the Thick Fog's, with no torch held -- only the tile taken comes out of the fog.
## Returns how many tiles newly showed, or -1 if it can't be charted.
##
## The caller reads the torch at the moment it charts and never again, so a torch put on afterwards uncovers
## nothing and one taken off hides nothing: what a tile showed when it was taken is what it showed.
func chart(cell: Vector2i, sight := 1) -> int:
	if not can_chart(cell):
		return -1
	if is_wall(cell):
		_break_wall()
	_show(cell, State.CHARTED)
	var shown := _reveal_around(cell, maxi(sight, 0))
	# Looking at the tile next door is the first half of going there, so the walk follows by itself.
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
			_show(cell, State.UNCHARTED)
			shown += 1
	return shown


## Which ring of land `cell` stands in: 0 inside where the first wall stood, n between the nth wall
## and the next. Counted in `wall_step`s, so under the Ring of Walls a ring is the land between its walls.
func ring_of(cell: Vector2i) -> int:
	return maxi(0, ceili(float(HexGrid.distance(CENTER, cell) - START_LAND_RADIUS) / wall_step))


## The fortuneteller's roads: every settlement in the same ring of land as `cell` that is still in the
## dark comes out of it as uncharted, the way the scour shows land. Returns how many did.
func reveal_ring_towns(cell: Vector2i) -> int:
	var ring := ring_of(cell)
	var shown := 0
	for spot in towns.towns():
		var town := spot - origin
		if is_land(town) and ring_of(town) == ring and _tiles.has(town) and not seen(town):
			_show(town, State.UNCHARTED)
			shown += 1
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


## Draws a cell, or just changes what the player knows about one that is already drawn.
func _show(cell: Vector2i, to: State) -> void:
	if not _tiles.has(cell) or state(cell) == to:
		return
	# Named the moment it is first drawn, uncharted or not: seeing a place is meeting it, and a
	# tile the player has been looking at for an hour should not be nameless when they walk in.
	name_of(cell)
	if is_wasteland(cell):
		# Snow and nothing under it: the land out there is not the player's to see until the wall falls.
		_states[cell] = to
		_ice.set_cell(cell, IceOverlay.Kind.WASTE)
		return
	if not seen(cell):
		map.set_ground(cell, _tiles[cell])
		_draw_road(cell)
		if is_wall(cell):
			_ice.set_cell(cell, IceOverlay.Kind.WALL)
	_states[cell] = to
	if to == State.UNCHARTED:
		map.fog.add_cell(cell)
	else:
		map.fog.remove_cell(cell)
	_draw_chest(cell)
