class_name SheetMeta
extends RefCounted
## The `meta` block of the generated spritesheet JSON (see AI-sprites-generator/README.md), read once
## per run and shared. It is the single source for the rules the sprites were drawn to — the adjacency
## table, the blend priority and rule, the road materials — so nothing in the game restates them.

const SHEET_JSON := "res://AI-sprites/spritesheet/hex_tileset.json"

static var _data: Dictionary


## The whole parsed JSON: "meta" and "tiles".
static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET_JSON))
		assert(parsed is Dictionary, "Could not read " + SHEET_JSON)
		_data = parsed
	return _data


static func meta() -> Dictionary:
	return data()["meta"]


## Which environments may border each other, without listing an environment as its own neighbor
## (callers handle that case themselves). Built from JSON meta env_adjacency.
static func env_adjacency() -> Dictionary[String, PackedStringArray]:
	var table: Dictionary[String, PackedStringArray] = {}
	for env: String in meta()["env_adjacency"]:
		var others := PackedStringArray()
		for other: String in meta()["env_adjacency"][env]:
			if other != env:
				others.append(other)
		table[env] = others
	return table
