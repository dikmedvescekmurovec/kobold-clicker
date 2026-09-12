class_name FogOverlay
extends Node2D
## Greys out the tiles the player has seen but not discovered yet, so they read as land they know is there
## but hasn't been looked at. Drawn as a translucent hex over each tile, above the terrain and roads but
## below the selection outline, which has to stay readable on a greyed tile.

const FOG_COLOR := Color(0.15, 0.13, 0.19, 0.55)

var _map: HexMap
var _corners: PackedVector2Array
var _cells: Dictionary[Vector2i, bool] = {}


func setup(map: HexMap) -> void:
	_map = map
	_corners = HexGrid.corners(Vector2(map.tileset.tile_size))


func add_cell(cell: Vector2i) -> void:
	_cells[cell] = true
	queue_redraw()


func remove_cell(cell: Vector2i) -> void:
	_cells.erase(cell)
	queue_redraw()


func has_cell(cell: Vector2i) -> bool:
	return _cells.has(cell)


func cells() -> Array[Vector2i]:
	return _cells.keys()


func clear() -> void:
	_cells.clear()
	queue_redraw()


func _draw() -> void:
	for cell in _cells:
		var middle := _map.ground_layer.map_to_local(cell)
		var hex := PackedVector2Array()
		for corner in _corners:
			hex.append(corner + middle)
		draw_colored_polygon(hex, FOG_COLOR)
