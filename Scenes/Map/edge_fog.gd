class_name EdgeFog
extends Node2D
## The fog behind the map lapping a few pixels onto every shown tile's edge that faces the unknown, so
## the land fades into it rather than stopping at a hard hex line. Each such edge is a band in the
## backdrop's own shader, its vertex alpha 1 at the edge and 0 at `DEPTH` inside, which the shader
## dithers into a ragged, drifting edge. `MapBuilder` puts it under `HexMap.chests` beside the ice.

## How far the fog reaches onto a tile, in world pixels, and how far past its edge the band starts: a
## tile's sprite has light rim pixels right on the hex line, which showed through as a dotted outline.
const DEPTH := 12.0
const OVERHANG := 4.0

var _map: HexMap
var _outer: PackedVector2Array
var _inner: PackedVector2Array
var _cells: Dictionary[Vector2i, bool] = {}


func _init(map: HexMap) -> void:
	_map = map
	# The tile's hex is near enough regular (a 28 px apothem) that scaling it moves every edge alike.
	var apothem := map.tileset.tile_size.x / 2.0
	for corner in HexGrid.corners(Vector2(map.tileset.tile_size)):
		_outer.append(corner * (1.0 + OVERHANG / apothem))
		_inner.append(corner * (1.0 - DEPTH / apothem))
	material = ShaderMaterial.new()
	material.shader = HexMap.BACKDROP_SHADER


## A cell the player can see, drawn or not (the wasteland has no ground). Nothing is ever taken back.
func add_cell(cell: Vector2i) -> void:
	if not _cells.has(cell):
		_cells[cell] = true
		queue_redraw()


func _draw() -> void:
	var colors := PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0), Color(1, 1, 1, 0)])
	for cell in _cells:
		var at := _map.ground_layer.map_to_local(cell)
		for edge in HexGrid.EDGES:
			if _cells.has(HexGrid.neighbor(cell, edge)):
				continue
			# Edge E runs from corner 1 to corner 2, and each edge after it one corner on.
			var a := (edge + 1) % HexGrid.EDGES
			var b := (edge + 2) % HexGrid.EDGES
			draw_polygon(PackedVector2Array([at + _outer[a], at + _outer[b], at + _inner[b], at + _inner[a]]), colors)
