class_name FogOverlay
extends Node2D
## Greys out the tiles the player has seen but not charted yet, so they read as land they know is there
## but hasn't been looked at. Drawn as a translucent hex over each tile, above the terrain and roads but
## below the selection outline, which has to stay readable on a greyed tile.

const FOG_COLOR := Color(0.15, 0.13, 0.19, 0.55)
## How long a charted tile's veil takes to lift.
const LIFT_TIME := 0.8

var _map: HexMap
var _corners: PackedVector2Array
var _cells: Dictionary[Vector2i, bool] = {}
## Veils still lifting, and how much of each is left. Only drawn: a lifting cell is already charted as
## far as `has_cell` and `cells` are concerned.
var _lifting: Dictionary[Vector2i, float] = {}


func setup(map: HexMap) -> void:
	_map = map
	_corners = HexGrid.corners(Vector2(map.tileset.tile_size))


func add_cell(cell: Vector2i) -> void:
	_cells[cell] = true
	_lifting.erase(cell)
	queue_redraw()


func remove_cell(cell: Vector2i) -> void:
	if _cells.erase(cell):
		_lifting[cell] = 1.0
	queue_redraw()


func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)


func cells() -> Array[Vector2i]:
	return _cells.keys()


func clear() -> void:
	_cells.clear()
	_lifting.clear()
	queue_redraw()


func _draw() -> void:
	for cell in _cells:
		draw_set_transform(_map.ground_layer.map_to_local(cell))
		draw_colored_polygon(_corners, FOG_COLOR)
	for cell in _lifting:
		draw_set_transform(_map.ground_layer.map_to_local(cell))
		draw_colored_polygon(_corners, Color(FOG_COLOR, FOG_COLOR.a * _lifting[cell]))


func _process(delta: float) -> void:
	if _lifting.is_empty():
		return
	for cell in _lifting.keys():
		_lifting[cell] -= delta / LIFT_TIME
		if _lifting[cell] <= 0.0:
			_lifting.erase(cell)
	queue_redraw()
