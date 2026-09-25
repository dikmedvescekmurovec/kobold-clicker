class_name IceOverlay
extends Node2D
## The ice at the edge of the land: the wall ring the player has to break, and the frozen wasteland past
## it, drawn from the generated sheets in `Assets/Ice/` (`AI-sprites-generator/build_ice.py`). Every ice
## cell is wasteland snow; a wall cell carries the wall's band over it, running between its two ring
## neighbours the way a road runs through its tile; a quarter of the wasteland carries something lying on
## the snow; and every drawn land tile beside the ice gets the snow drifting onto it, the way one
## environment's blend runs onto the next. Drawn a hex a cell, like `FogOverlay`; `MapBuilder` puts it
## under `HexMap.chests`, so it sits over the fog and under the outlines.

enum Kind { WALL, WASTE }

const WASTE := preload("res://Assets/Ice/ice_waste.png")
const BAND := preload("res://Assets/Ice/ice_band.png")
const SPILL := preload("res://Assets/Ice/ice_spill.png")
const ACCENTS := preload("res://Assets/Ice/ice_accents.png")
## The snow is one field repeating every WASTE_COLS x WASTE_ROWS cells (the rows even, so the odd rows'
## half-step comes round too), cut into that many tiles: a cell takes the tile at its column and row
## modulo these. The generator's `ice_wall.WASTE_COLS` / `WASTE_ROWS`.
const WASTE_COLS := 6
const WASTE_ROWS := 4
## Versions of each band tile, side by side in blocks of 8 columns (`ice_wall.VARIANTS`).
const BAND_VERSIONS := 3
## Accent kinds across the sheet and versions of each down it (`ice_wall.ACCENT_KINDS`, three each).
const ACCENT_KINDS := 7
const ACCENT_VERSIONS := 3
## How many wasteland cells in a hundred carry an accent (`ice_wall.ACCENT_CHANCE`).
const ACCENT_CHANCE := 25

var _map: HexMap
var _size: Vector2
var _cells: Dictionary[Vector2i, Kind] = {}
var _bands: Dictionary[Vector2i, int] = {}  # a wall cell's ring neighbours, as an edge mask


func _init(map: HexMap) -> void:
	_map = map
	_size = Vector2(map.tileset.tile_size)


## `band` is a wall cell's two neighbours on the same ring, as `HexGrid.edge_mask`; nothing else has one.
func set_cell(cell: Vector2i, kind: Kind, band := 0) -> void:
	_cells[cell] = kind
	if kind == Kind.WALL:
		_bands[cell] = band
	else:
		_bands.erase(cell)
	queue_redraw()


func remove_cell(cell: Vector2i) -> void:
	_bands.erase(cell)
	if _cells.erase(cell):
		queue_redraw()


func kind_at(cell: Vector2i) -> int:
	return _cells.get(cell, -1)


## The edge mask of a drawn land tile's sides that touch the ice, 0 when it touches none.
func spill_mask(cell: Vector2i) -> int:
	if _cells.has(cell) or not _map.has_tile(cell):
		return 0
	var mask := 0
	for edge in HexGrid.EDGES:
		if _cells.has(HexGrid.neighbor(cell, edge)):
			mask |= 1 << edge
	return mask


## Whether a wasteland cell has something lying on it, and which: -1 for bare snow.
static func accent_at(cell: Vector2i) -> int:
	if _roll(cell, 0) % 100 >= ACCENT_CHANCE:
		return -1
	return _roll(cell, 1) % (ACCENT_KINDS * ACCENT_VERSIONS)


## A number fixed by the cell, so the same snow is drawn there every time the map is.
static func _roll(cell: Vector2i, salt: int) -> int:
	return ((cell.x * 73856093) ^ (cell.y * 19349663) ^ (salt * 83492791)) & 0x7fffffff


@warning_ignore("integer_division")
func _draw() -> void:
	var land: Dictionary[Vector2i, bool] = {}
	for cell in _cells:
		_put(WASTE, cell, Vector2i(posmod(cell.x, WASTE_COLS), posmod(cell.y, WASTE_ROWS)))
		if _cells[cell] == Kind.WALL:
			var band := _bands[cell]
			_put(BAND, cell, Vector2i(band % 8 + 8 * (_roll(cell, 2) % BAND_VERSIONS), band / 8))
		else:
			var accent := accent_at(cell)
			if accent >= 0:
				_put(ACCENTS, cell, Vector2i(accent / ACCENT_VERSIONS, accent % ACCENT_VERSIONS))
		for next in HexGrid.neighbors(cell):
			if not _cells.has(next):
				land[next] = true
	for cell in land:
		var mask := spill_mask(cell)
		if mask:
			_put(SPILL, cell, Vector2i(mask % 8, mask / 8))


func _put(sheet: Texture2D, cell: Vector2i, at: Vector2i) -> void:
	var middle := _map.ground_layer.map_to_local(cell)
	draw_texture_rect_region(sheet, Rect2(middle - _size / 2, _size), Rect2(Vector2(at) * _size, _size))
