class_name MapSave
extends RefCounted
## The explored map on disk: what the world is, how much of it the player has lifted the fog off,
## and where they are standing. Written at `user://map.json` beside the inventory's own save.
##
## Nothing here is regenerated on load. Both map generators are order-dependent rather than
## seed-dependent -- EnvironmentGenerator grows from a frontier seeded by the order cells were
## inserted, and RoadNetwork routes each link into the roads already laid -- so the same seed and
## the same final window do not give back the same land; only replaying the identical sequence of
## windows would, and that would weld every save to one build of the generator. The town world is
## written down too, although it *is* a pure function of its seed today, because that is a property
## of the current code and not a promise to the player.
##
## Which is the rule the whole file follows: nothing on the map can change. A save that cannot be
## honoured exactly is refused rather than quietly replaced -- see `load_from`.
##
## MapSave never names MapBuilder. MapBuilder.restore names MapSave, and a mention the other way is
## the class cycle Godot's checker bites on -- the same reason ItemRarity never mentions Item. So
## the states are raw ints here and STATE_NAMES is the legend they are written through; MapBuilder
## does the casting, and a test pins the two lists against each other.

const SAVE_PATH := "user://map.json"
## 1 is the first shape there has been. 2 added the names of the tiles the player has seen; a
## version 1 save simply has none, and its tiles are named again as they are asked about. 3 added
## `land_radius`, the ice wall's place; an older save has none and MapBuilder puts the wall past it.
## 4 added `cave`, the Gollux cave's cell; an older save has none, and the main scene puts one down.
const VERSION := 4

## MapBuilder.State by name, lowest value first. Written into every save as the legend its state
## rows index, so reordering the enum can never quietly reinterpret a file already on disk.
const STATE_NAMES := ["hidden", "uncharted", "charted"]
## What the states were called before "discover" became "chart", so older saves still read.
const OLD_STATE_NAMES := {"undiscovered": "uncharted", "discovered": "charted"}

## Indexes the legends, one character per cell. Six environments and three states need ten of
## these; the encoder is given sixty-two so it has no ceiling to walk into later.
const ALPHABET := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
## A cell of the window with no environment, which _generate makes impossible. A truncated or
## hand-edited row then degrades to a gap rather than to the wrong tile.
const GAP := "."

var sheet: String
var world_seed: int
var map_seed: int
var origin: Vector2i
var rect: Rect2i
## How far the land reaches before the ice wall; 0 in a save written before there was one.
var land_radius := 0
var start_town: Vector2i
## The Gollux cave's cell, `HexMap.NO_CELL` for a world that has none yet.
var cave := HexMap.NO_CELL
var player_cell: Vector2i
## The whole town world, as TownWorld.to_dict wrote it.
var towns: Dictionary = {}
var envs: Dictionary[Vector2i, String] = {}
## What each tile the player has seen is called. Sparse, and written out in full rather than as rows
## against a legend: a name is a whole word per cell and there is one only for the cells that have
## been looked at, so there is nothing for the alphabet to index.
var names: Dictionary[Vector2i, String] = {}
## MapBuilder.State per cell, as its raw value.
var states: Dictionary[Vector2i, int] = {}
## Road edge mask per world **spot**, not per cell, and it holds spots outside `rect`: a route
## wanders RoadNetwork.MARGIN beyond its own box. That is why it is a sparse list, not rows.
var roads: Dictionary[Vector2i, int] = {}
var routed_links: Dictionary[String, bool] = {}


## What a saved map is *read through*: the three spritesheet tables that decide what its names and
## its bitmasks draw as. A change to any of them means the land does not come back as it was --
## a border the adjacency table no longer allows, an overlay that now spreads the other way, a road
## shape that has lost its sprite. Deliberately only these three: a rebuilt sheet that adds an
## accent variant or retouches a pixel changes nothing a save depends on and must not cost the
## player their map.
##
## SHA-256 of a canonical spelling rather than hash(), whose value is Godot's business and could
## change under a player between one build and the next.
static func fingerprint(tileset: HexTileset) -> String:
	var parts := PackedStringArray()
	var adjacency := SheetMeta.env_adjacency()
	var envs_sorted := adjacency.keys()
	envs_sorted.sort()
	for env: String in envs_sorted:
		var allowed := Array(adjacency[env])
		allowed.sort()
		parts.append("%s>%s" % [env, ",".join(allowed)])
	parts.append("priority=%s" % ",".join(tileset.blend_priority))
	var masks := tileset.legal_road_masks().keys()
	masks.sort()
	parts.append("roads=%s" % ",".join(masks.map(func(mask: int) -> String: return str(mask))))
	return "|".join(parts).sha256_text()


## Writes the map to `path`, whole or not at all (`SafeFile`). Returns whether it got there; a failed
## write is worth a warning but never worth stopping play for.
func save(path := SAVE_PATH) -> bool:
	var env_names := _env_names()
	var road_list: Array[int] = []
	for spot in roads:
		road_list.append_array([spot.x, spot.y, roads[spot]])
	# Indented, so the save can be read by a person -- and the env rows read as a picture of the map.
	return SafeFile.write(path, JSON.stringify({
		"version": VERSION,
		"sheet": sheet,
		"world_seed": world_seed,
		"map_seed": map_seed,
		"origin": [origin.x, origin.y],
		"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
		"land_radius": land_radius,
		"start_town": [start_town.x, start_town.y],
		"cave": [cave.x, cave.y] if cave != HexMap.NO_CELL else [],
		"player_cell": [player_cell.x, player_cell.y],
		"towns": towns,
		"environments": env_names,
		"env_rows": _rows(func(cell: Vector2i) -> int:
			return env_names.find(envs[cell]) if envs.has(cell) else -1),
		"names": _name_dict(),
		"states": STATE_NAMES,
		"state_rows": _rows(func(cell: Vector2i) -> int: return states.get(cell, 0)),
		"roads": road_list,
		"routed_links": routed_links.keys(),
	}, "\t"))


## The map in `path`, or null. Two different nulls, which the caller has to tell apart:
##
## * `problem` left empty -- there is no file. A first run: generate a new world, say nothing.
## * a reason appended to `problem` -- there is a file and it cannot be honoured. Unreadable,
##   unparseable, the wrong shape, written by a newer build, or drawn against different sprite
##   tables. The caller must **stop** rather than generate: a fresh world would be written over
##   this one on the player's first step, and losing a map to a bad read is worse than an error
##   message. It is the same reason Inventory leaves a newer-version file alone -- the build that
##   wrote it can still read it.
##
## `problem` is an out-parameter because an Array is shared where a String would be copied.
static func load_from(path := SAVE_PATH, problem: Array = [], expect_sheet := "") -> MapSave:
	SafeFile.recover(path)
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		problem.append("it cannot be read")
		return null
	# A JSON instance rather than JSON.parse_string, which pushes an engine error of its own on bad
	# input: a refused save is reported once, in the player's words, not twice in the engine's.
	var reader := JSON.new()
	if reader.parse(text) != OK or typeof(reader.data) != TYPE_DICTIONARY:
		problem.append("it is not a save file")
		return null
	var data: Dictionary = reader.data
	var version := int(data.get("version", 0))
	if version > VERSION:
		problem.append("it was written by a newer version of the game (%d)" % version)
		return null
	if version < 1:
		problem.append("it does not say which version wrote it")
		return null

	var save := MapSave.new()
	save.sheet = str(data.get("sheet", ""))
	if expect_sheet != "" and save.sheet != expect_sheet:
		problem.append("it was drawn with a different set of tiles")
		return null
	save.world_seed = int(data.get("world_seed", 0))
	save.map_seed = int(data.get("map_seed", 0))
	save.origin = _to_vector(data.get("origin", []))
	save.start_town = _to_vector(data.get("start_town", []))
	var saved_cave: Variant = data.get("cave", [])
	if typeof(saved_cave) == TYPE_ARRAY and (saved_cave as Array).size() == 2:
		save.cave = _to_vector(saved_cave)
	save.player_cell = _to_vector(data.get("player_cell", []))
	var saved_rect: Variant = data.get("rect", [])
	if typeof(saved_rect) != TYPE_ARRAY or saved_rect.size() != 4:
		problem.append("it has no window")
		return null
	save.rect = Rect2i(int(saved_rect[0]), int(saved_rect[1]), int(saved_rect[2]), int(saved_rect[3]))
	save.land_radius = int(data.get("land_radius", 0))

	var saved_towns: Variant = data.get("towns", {})
	if typeof(saved_towns) != TYPE_DICTIONARY or TownWorld.from_dict(saved_towns) == null:
		problem.append("its settlements cannot be read")
		return null
	save.towns = saved_towns

	var env_names: Array = data.get("environments", [])
	if typeof(env_names) != TYPE_ARRAY:
		problem.append("it has no environments")
		return null
	if not save._read_rows(data.get("env_rows", []), env_names.size(),
			func(cell: Vector2i, index: int) -> void: save.envs[cell] = str(env_names[index])):
		problem.append("its land does not fit its window")
		return null
	# States are resolved through the save's own legend, so an enum reordered since cannot shift.
	var state_legend: Array[int] = []
	for name: Variant in data.get("states", []):
		state_legend.append(STATE_NAMES.find(OLD_STATE_NAMES.get(str(name), str(name))))
	if state_legend.has(-1):
		problem.append("it records a state this build has no name for")
		return null
	# HIDDEN is the absence of an entry, here as in MapBuilder: a cell nothing is drawn for is one
	# the map has never heard of. Storing it would put every unexplored cell of the window into a
	# dictionary that is meant to hold only what has been seen.
	var hidden := STATE_NAMES.find("hidden")
	if not save._read_rows(data.get("state_rows", []), state_legend.size(),
			func(cell: Vector2i, index: int) -> void:
				if state_legend[index] != hidden:
					save.states[cell] = state_legend[index]):
		problem.append("what it has explored does not fit its window")
		return null

	# Names arrived in version 2. A save without them is not wrong, it is old: its tiles are named
	# again the first time anything asks, and the same tables give the same names back.
	var saved_names: Variant = data.get("names", {})
	if typeof(saved_names) != TYPE_DICTIONARY:
		problem.append("what it has named cannot be read")
		return null
	for key: Variant in saved_names:
		var at := str(key).split(",")
		if at.size() == 2:
			save.names[Vector2i(int(at[0]), int(at[1]))] = str(saved_names[key])

	var road_list: Variant = data.get("roads", [])
	if typeof(road_list) != TYPE_ARRAY or road_list.size() % 3 != 0:
		problem.append("its roads cannot be read")
		return null
	for i in range(0, road_list.size(), 3):
		save.roads[Vector2i(int(road_list[i]), int(road_list[i + 1]))] = int(road_list[i + 2])
	for key: Variant in data.get("routed_links", []):
		save.routed_links[str(key)] = true
	return save


## The names keyed by "x,y", which is a cell written the way a person would write it -- the save is
## indented to be read, and a JSON object's keys are strings whatever is put in them anyway.
func _name_dict() -> Dictionary:
	var out := {}
	for cell in names:
		out["%d,%d" % [cell.x, cell.y]] = names[cell]
	return out


## Every environment on the map, in the order they were first laid down, which is the legend the
## env rows index.
func _env_names() -> Array[String]:
	var names: Array[String] = []
	for cell in envs:
		if not names.has(envs[cell]):
			names.append(envs[cell])
	return names


## One string per row of the window, top row first, one character per cell: `index.call(cell)` into
## the ALPHABET, or GAP where it comes back negative.
func _rows(index: Callable) -> Array[String]:
	var rows: Array[String] = []
	for y in range(rect.position.y, rect.end.y):
		var row := ""
		for x in range(rect.position.x, rect.end.x):
			var at: int = index.call(Vector2i(x, y))
			row += ALPHABET[at] if at >= 0 and at < ALPHABET.length() else GAP
		rows.append(row)
	return rows


## Reads rows written by `_rows` back, calling `set_cell` for every character that indexes a legend
## of `legend_size` entries. Returns whether the rows match the window; a GAP is a cell left unset.
func _read_rows(rows: Variant, legend_size: int, set_cell: Callable) -> bool:
	if typeof(rows) != TYPE_ARRAY or rows.size() != rect.size.y:
		return false
	for y in rect.size.y:
		var row := str(rows[y])
		if row.length() != rect.size.x:
			return false
		for x in rect.size.x:
			var at := ALPHABET.find(row[x])
			if at == -1 or at >= legend_size:
				continue  # A gap, or a character no legend reaches: the cell stays unset.
			set_cell.call(rect.position + Vector2i(x, y), at)
	return true


static func _to_vector(data: Variant) -> Vector2i:
	if typeof(data) != TYPE_ARRAY or data.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(data[0]), int(data[1]))
