class_name HexHighlight
extends Node2D
## Outlines the hovered and selected cells of a HexMap. Each outline is a bright band edged with dark ink,
## so it stands out on light terrain (sand, ice) and dark terrain (forest) alike.

const INK := Palette.INK
const HOVER_COLOR := Palette.BONE
const SELECTED_COLOR := Palette.GOLD

var _map: HexMap
var _corners: PackedVector2Array
var _hover_bands: Array[Dictionary] = []
var _selected_bands: Array[Dictionary] = []


func setup(map: HexMap) -> void:
	_map = map
	_corners = HexGrid.corners(Vector2(map.tileset.tile_size))
	# Bands span from `inner` to `outer` pixels off the tile edge (positive is outward), drawn in order.
	# Selected: 4 px gold with 1 px ink on both sides. Hover: 2 px light line on a softer ink border.
	_hover_bands = [_band(Color(INK, 0.6), -2, 2), _band(HOVER_COLOR, -1, 1)]
	_selected_bands = [_band(INK, -3, 3), _band(SELECTED_COLOR, -2, 2)]


func _draw() -> void:
	if _map == null:
		return
	if _map.hovered_cell != HexMap.NO_CELL and _map.hovered_cell != _map.selected_cell:
		_draw_bands(_map.hovered_cell, _hover_bands)
	if _map.selected_cell != HexMap.NO_CELL:
		_draw_bands(_map.selected_cell, _selected_bands)


func _draw_bands(cell: Vector2i, bands: Array[Dictionary]) -> void:
	draw_set_transform(_map.ground_layer.map_to_local(cell))
	for band in bands:
		for quad: PackedVector2Array in band["quads"]:
			draw_colored_polygon(quad, band["color"])


## One quad per hex edge. Filled quads give clean corners, unlike thick polylines.
func _band(color: Color, inner: float, outer: float) -> Dictionary:
	var inside := _offset_corners(inner)
	var outside := _offset_corners(outer)
	var quads: Array[PackedVector2Array] = []
	for i in _corners.size():
		var j := (i + 1) % _corners.size()
		quads.append(PackedVector2Array([inside[i], outside[i], outside[j], inside[j]]))
	return {"color": color, "quads": quads}


## Corners moved `distance` pixels outward from every edge, with mitered joins.
func _offset_corners(distance: float) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in _corners.size():
		var before := _outward_normal(_corners[i - 1], _corners[i])
		var after := _outward_normal(_corners[i], _corners[(i + 1) % _corners.size()])
		result.append(_corners[i] + (before + after) * distance / (1 + before.dot(after)))
	return result


func _outward_normal(from: Vector2, to: Vector2) -> Vector2:
	return (to - from).orthogonal().normalized()
