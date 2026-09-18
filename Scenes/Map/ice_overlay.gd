class_name IceOverlay
extends Node2D
## The ice at the edge of the land: the wall ring the player has to break, and the frozen wasteland past
## it. A stand-in drawn in the sprite palette's ice ramp until the wall has art of its own. Drawn as a
## hex over each cell, like `FogOverlay`; `MapBuilder` puts it under `HexMap.chests`, so it sits over
## the fog and under the outlines.

enum Kind { WALL, WASTE }

const ICE_DK := Color("3f6fa6")
const ICE := Color("72a8d6")
const ICE_LT := Color("acd6ee")
const SNOW := Color("e8f5fb")

var _map: HexMap
var _corners: PackedVector2Array
var _cells: Dictionary[Vector2i, Kind] = {}


func _init(map: HexMap) -> void:
	_map = map
	_corners = HexGrid.corners(Vector2(map.tileset.tile_size))


func set_cell(cell: Vector2i, kind: Kind) -> void:
	_cells[cell] = kind
	queue_redraw()


func remove_cell(cell: Vector2i) -> void:
	if _cells.erase(cell):
		queue_redraw()


func kind_at(cell: Vector2i) -> int:
	return _cells.get(cell, -1)


func _draw() -> void:
	var outline := _corners.duplicate()
	outline.append(_corners[0])
	var inner := PackedVector2Array()
	for corner in outline:
		inner.append(corner * 0.7)
	for cell in _cells:
		draw_set_transform(_map.ground_layer.map_to_local(cell))
		if _cells[cell] == Kind.WALL:
			draw_colored_polygon(_corners, ICE)
			draw_polyline(inner, ICE_LT, 2.0)
			draw_polyline(outline, ICE_DK, 1.0)
		else:
			draw_colored_polygon(_corners, SNOW)
			draw_polyline(outline, ICE_LT, 1.0)
