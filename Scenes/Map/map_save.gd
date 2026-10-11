class_name MapSave
extends RefCounted
## The explored map on disk, `user://map.json`. Nothing here is regenerated on load, and a save that
## cannot be honoured exactly is refused rather than quietly replaced (`load_from`).
##
## MapSave never names MapBuilder, which names it: that is the class cycle Godot's checker bites on. So
## the states are raw ints here and STATE_NAMES is the legend they are written through; MapBuilder does
## the casting, and a test pins the two lists against each other.

const SAVE_PATH := "user://map.json"
## 2 added `names`; a version 1 save has none, and its tiles are named again as they are asked about.
## 3 added `land_radius`; an older save has none and MapBuilder puts the wall past it. 4 added `cave`;
## an older save has none, and gets one beside the next wall broken in it (`MapBuilder.place_cave`).
const VERSION := 4

## MapBuilder.State by name, lowest value first. Written into every save as the legend its state
## rows index, so reordering the enum can never quietly reinterpret a file already on disk.
const STATE_NAMES := ["hidden", "uncharted", "charted"]
## What the states were called before "discover" became "chart", so older saves still read.
const OLD_STATE_NAMES := {"undiscovered": "uncharted", "discovered": "charted"}
## Sheets a save may have been drawn with, each against the one sheet that still reads it. Only
## `env_adjacency` was widened between the two (every border but desert-ice allowed, 2026-10-03),
## and a map drawn under fewer borders keeps to the wider table. An entry stops matching as soon
## as the sheet changes again, which brings the refusal back.
const WIDENED_SHEETS := {
	"68ae2d02da88d387f09c030963a2938907542675f6f4d407f189209359d20018":
			"82b7069bb4bdaef41496c6c17e76f44817cbb211f6aba52cf5def990a1ad4675",
}

## Indexes the legends, one character per cell.
const ALPHABET := "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
## A cell of the window with no environment, which `MapBuilder._generate` makes impossible. A truncated
## or hand-edited row then degrades to a gap rather than to the wrong tile.
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
## What each tile the player has seen is called. Sparse, so written out in full under "x,y" keys rather
## than as rows against a legend.
var names: Dictionary[Vector2i, String] = {}
## MapBuilder.State per cell, as its raw value.
var states: Dictionary[Vector2i, int] = {}
## Road edge mask per world **spot**, not per cell, and it holds spots outside `rect`: a route
## wanders RoadNetwork.MARGIN beyond its own box. That is why it is a sparse list, not rows.
var roads: Dictionary[Vector2i, int] = {}
var routed_links: Dictionary[String, bool] = {}


## What a saved map is *read through*: the three spritesheet tables that decide what its names and its
## bitmasks draw as. Deliberately only these three: a rebuilt sheet that adds an accent variant or
## retouches a pixel changes nothing a save depends on and must not cost the player their map.
## SHA-256 of a canonical spelling rather than hash(), whose value is Godot's business and could change
## under a player between one build and the next.
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
## * a reason appended to `problem` -- there is a file and it cannot be honoured. The caller must
##   **stop** rather than generate: a fresh world would be written over this one on the player's
##   first step.
##
## `problem` is an out-parameter because an Array is shared where a String would be copied.
##
## **Every value is looked at before it is read** (`TownWorld.is_numbers`, `typeof`): a typed read of
## the wrong thing -- `int()` of a list, a number assigned to an Array -- stops the function where it
## stands, and the null that leaves has no reason in `problem`, which the caller takes for a first run.
static func load_from(path := SAVE_PATH, problem: Array = [], expect_sheet := "") -> MapSave:
	SafeFile.recover(path)
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return _refuse(problem, "it cannot be read")
	# A JSON instance rather than JSON.parse_string, which pushes an engine error of its own on bad
	# input: a refused save is reported once, in the player's words, not twice in the engine's.
	var reader := JSON.new()
	if reader.parse(text) != OK or typeof(reader.data) != TYPE_DICTIONARY:
		return _refuse(problem, "it is not a save file")
	var data: Dictionary = reader.data
	for key: String in ["version", "world_seed", "map_seed", "land_radius"]:
		if not TownWorld.is_numbers([data.get(key, 0)]):
			return _refuse(problem, "its %s is not a number" % key.replace("_", " "))
	for key: String in ["origin", "start_town", "player_cell"]:
		if data.has(key) and not _is_cell(data[key]):
			return _refuse(problem, "its %s is not a place" % key.replace("_", " "))
	var version := int(data.get("version", 0))
	if version > VERSION:
		return _refuse(problem, "it was written by a newer version of the game (%d)" % version)
	if version < 1:
		return _refuse(problem, "it does not say which version wrote it")

	var save := MapSave.new()
	save.sheet = str(data.get("sheet", ""))
	if expect_sheet != "" and save.sheet != expect_sheet and WIDENED_SHEETS.get(save.sheet) != expect_sheet:
		return _refuse(problem, "it was drawn with a different set of tiles")
	save.world_seed = int(data.get("world_seed", 0))
	save.map_seed = int(data.get("map_seed", 0))
	save.origin = _to_vector(data.get("origin", []))
	save.start_town = _to_vector(data.get("start_town", []))
	# `[]` is a world with no cave yet; anything else that is not a cell is a cave this would lose.
	var saved_cave: Variant = data.get("cave", [])
	if _is_cell(saved_cave):
		save.cave = _to_vector(saved_cave)
	elif typeof(saved_cave) != TYPE_ARRAY or not (saved_cave as Array).is_empty():
		return _refuse(problem, "its cave is not a place")
	save.player_cell = _to_vector(data.get("player_cell", []))
	var saved_rect: Variant = data.get("rect", [])
	if not TownWorld.is_numbers(saved_rect) or saved_rect.size() != 4:
		return _refuse(problem, "it has no window")
	save.rect = Rect2i(int(saved_rect[0]), int(saved_rect[1]), int(saved_rect[2]), int(saved_rect[3]))
	save.land_radius = int(data.get("land_radius", 0))

	var saved_towns: Variant = data.get("towns", {})
	if typeof(saved_towns) != TYPE_DICTIONARY or TownWorld.from_dict(saved_towns) == null:
		return _refuse(problem, "its settlements cannot be read")
	save.towns = saved_towns

	# A legend that is missing or empty would read every row under it as gaps: a map of no land at all.
	var saved_envs: Variant = data.get("environments", [])
	if typeof(saved_envs) != TYPE_ARRAY or (saved_envs as Array).is_empty():
		return _refuse(problem, "it has no environments")
	var env_names: Array = saved_envs
	if not save._read_rows(data.get("env_rows", []), env_names.size(),
			func(cell: Vector2i, index: int) -> void: save.envs[cell] = str(env_names[index])):
		return _refuse(problem, "its land does not fit its window")
	var saved_states: Variant = data.get("states", [])
	if typeof(saved_states) != TYPE_ARRAY or (saved_states as Array).is_empty():
		return _refuse(problem, "it does not say what it has explored")
	var state_legend: Array[int] = []
	for name: Variant in saved_states:
		state_legend.append(STATE_NAMES.find(OLD_STATE_NAMES.get(str(name), str(name))))
	if state_legend.has(-1):
		return _refuse(problem, "it records a state this build has no name for")
	# HIDDEN is the absence of an entry, here as in MapBuilder: `states` holds only what has been seen.
	var hidden := STATE_NAMES.find("hidden")
	if not save._read_rows(data.get("state_rows", []), state_legend.size(),
			func(cell: Vector2i, index: int) -> void:
				if state_legend[index] != hidden:
					save.states[cell] = state_legend[index]):
		return _refuse(problem, "what it has explored does not fit its window")

	var saved_names: Variant = data.get("names", {})
	if typeof(saved_names) != TYPE_DICTIONARY:
		return _refuse(problem, "what it has named cannot be read")
	for key: Variant in saved_names:
		var at := str(key).split(",")
		if at.size() == 2:
			save.names[Vector2i(int(at[0]), int(at[1]))] = str(saved_names[key])

	var road_list: Variant = data.get("roads", [])
	var saved_links: Variant = data.get("routed_links", [])
	if not TownWorld.is_numbers(road_list, 3) or typeof(saved_links) != TYPE_ARRAY:
		return _refuse(problem, "its roads cannot be read")
	for i in range(0, road_list.size(), 3):
		save.roads[Vector2i(int(road_list[i]), int(road_list[i + 1]))] = int(road_list[i + 2])
	for key: Variant in saved_links:
		save.routed_links[str(key)] = true
	return save


## Says why the file is refused, and hands back the null `load_from` leaves by.
static func _refuse(problem: Array, reason: String) -> MapSave:
	problem.append(reason)
	return null


func _name_dict() -> Dictionary:
	var out := {}
	for cell in names:
		out["%d,%d" % [cell.x, cell.y]] = names[cell]
	return out


## Every environment on the map, in the order they were first laid down, which is the legend the
## env rows index.
func _env_names() -> Array[String]:
	var legend: Array[String] = []
	for cell in envs:
		if not legend.has(envs[cell]):
			legend.append(envs[cell])
	return legend


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


## Whether `data` is a cell or a spot as the save writes one: `[x, y]`.
static func _is_cell(data: Variant) -> bool:
	return TownWorld.is_numbers(data) and (data as Array).size() == 2


static func _to_vector(data: Variant) -> Vector2i:
	return Vector2i(int(data[0]), int(data[1])) if _is_cell(data) else Vector2i.ZERO
