class_name HexTileset
extends RefCounted
## Builds a hex TileSet from the generated spritesheet and its JSON (see AI-sprites-generator/README.md),
## so rebuilding the sprites updates the game without editing the TileSet by hand.

const SHEET_JSON := "res://AI-sprites/spritesheet/hex_tileset.json"
const SOURCE_ID := 0
const CUSTOM_DATA := ["name", "group", "env", "kind"]

var tile_set: TileSet
var tile_size: Vector2i
var environments: PackedStringArray = []
## Environments from lowest to highest blend priority. A higher one spreads overlays onto lower neighbors.
var blend_priority: PackedStringArray = []

var _coords: Dictionary[String, Vector2i] = {}
var _road_names: Dictionary[String, String] = {}  # _edge_key(material, edges) -> tile name
var _blend_names: Dictionary[String, String] = {}  # _edge_key(env, edges) -> tile name
var _road_material_by_env: Dictionary[String, String] = {}
var _adjacency: Dictionary[String, PackedStringArray] = {}
var _sheet_path: String
var _sheet_image: Image
var _masks: Dictionary[String, PackedByteArray] = {}


func _init() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET_JSON))
	assert(data is Dictionary, "Could not read " + SHEET_JSON)
	var meta: Dictionary = data["meta"]
	tile_size = Vector2i(int(meta["tile_size"][0]), int(meta["tile_size"][1]))
	for road_material: String in meta["road_materials"]:
		for env: String in meta["road_materials"][road_material]:
			_road_material_by_env[env] = road_material
	for env: String in meta["env_adjacency"]:
		_adjacency[env] = PackedStringArray(meta["env_adjacency"][env])
	blend_priority = PackedStringArray(meta["blend_priority"])
	_sheet_path = SHEET_JSON.get_base_dir().path_join(meta["image"])
	_build_tile_set(load(_sheet_path), data["tiles"])


func atlas_coords(tile_name: String) -> Vector2i:
	if not _coords.has(tile_name):
		push_error("Unknown tile: " + tile_name)
		return Vector2i(-1, -1)
	return _coords[tile_name]


## Road overlay connecting exactly these HexGrid.Edge values (any order), or "" if no such sprite exists.
func road_name(road_material: String, edges: Array) -> String:
	return _road_names.get(_edge_key(road_material, edges), "")


## Road material ("dirt", "stone", "snow") that suits an environment.
func road_material_for(env: String) -> String:
	return _road_material_by_env.get(env, "")


## Overlay of `env` for a tile whose given HexGrid.Edge values (any order) touch `env`, or "" if none exists.
func blend_name(env: String, edges: Array) -> String:
	return _blend_names.get(_edge_key(env, edges), "")


## Position in blend_priority, or -1 for an unknown environment.
func env_rank(env: String) -> int:
	return blend_priority.find(env)


## Whether two environments may be neighbors (JSON meta env_adjacency).
func can_border(a: String, b: String) -> bool:
	return a == b or (_adjacency.has(a) and b in _adjacency[a])


## One byte per pixel of the tile, row by row: 1 where the sprite is opaque. Built once per tile.
func opaque_mask(tile_name: String) -> PackedByteArray:
	if _masks.has(tile_name):
		return _masks[tile_name]
	if _sheet_image == null:
		_sheet_image = _load_sheet_image()
	var region := _sheet_image.get_region(Rect2i(atlas_coords(tile_name) * tile_size, tile_size))
	region.convert(Image.FORMAT_RGBA8)
	var rgba := region.get_data()
	var mask := PackedByteArray()
	mask.resize(tile_size.x * tile_size.y)
	for i in mask.size():
		mask[i] = 1 if rgba[i * 4 + 3] > 0 else 0
	_masks[tile_name] = mask
	return mask


func _load_sheet_image() -> Image:
	var texture: Texture2D = tile_set.get_source(SOURCE_ID).texture
	var image := texture.get_image()
	if image == null or image.is_empty():
		# The texture can have no readable image (e.g. under --headless), so read the source PNG instead.
		image = Image.load_from_file(_sheet_path)
	if image.is_compressed():
		image.decompress()
	return image


func _build_tile_set(texture: Texture2D, tiles: Array) -> void:
	tile_set = TileSet.new()
	tile_set.tile_shape = TileSet.TILE_SHAPE_HEXAGON
	tile_set.tile_layout = TileSet.TILE_LAYOUT_STACKED
	tile_set.tile_offset_axis = TileSet.TILE_OFFSET_AXIS_HORIZONTAL
	tile_set.tile_size = tile_size
	for i in CUSTOM_DATA.size():
		tile_set.add_custom_data_layer()
		tile_set.set_custom_data_layer_name(i, CUSTOM_DATA[i])
		tile_set.set_custom_data_layer_type(i, TYPE_STRING)

	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = tile_size
	tile_set.add_source(source, SOURCE_ID)

	for entry: Dictionary in tiles:
		var tile_name: String = entry["name"]
		var coords := Vector2i(int(entry["col"]), int(entry["row"]))
		source.create_tile(coords)
		var tile := source.get_tile_data(coords, 0)
		tile.set_custom_data("name", tile_name)
		tile.set_custom_data("group", entry["group"])
		tile.set_custom_data("env", entry.get("env", ""))
		tile.set_custom_data("kind", entry.get("variant", entry.get("tier", entry.get("pattern", ""))))
		_coords[tile_name] = coords

		match entry["group"]:
			"environments":
				if not (entry["env"] in environments):
					environments.append(entry["env"])
			"roads":
				_road_names[_edge_key(entry["material"], _edge_indices(entry["edges"]))] = tile_name
			"blends":
				_blend_names[_edge_key(entry["env"], _edge_indices(entry["edges"]))] = tile_name


static func _edge_indices(edge_names: Array) -> Array:
	return edge_names.map(func(edge_name: String) -> int: return HexGrid.Edge[edge_name])


static func _edge_key(prefix: String, edges: Array) -> String:
	var mask := 0
	for edge: int in edges:
		mask |= 1 << edge
	return "%s:%d" % [prefix, mask]
