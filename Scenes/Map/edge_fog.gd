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
## A tile that has just come out of the fog clears as a front sweeping away from where the player stood:
## how fast it moves in world pixels a second, and how far ahead of it the fog thins from none to full.
const LIFT_SPEED := 60.0
const LIFT_SOFT := 48.0

var _map: HexMap
var _outer: PackedVector2Array
var _inner: PackedVector2Array
var _cells: Dictionary[Vector2i, bool] = {}
## Tiles the fog is still sliding off: where the front started (x, y) and when, on `_clock` (z). While
## a tile lifts, the fog covers what the front hasn't reached, and still laps onto its neighbours' edges.
var _lifting: Dictionary[Vector2i, Vector3] = {}
var _clock := 0.0


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
## `lift_from`, a map spot, has the fog slide off it away from there rather than vanish at once.
func add_cell(cell: Vector2i, lift_from: Variant = null) -> void:
	if not _cells.has(cell):
		_cells[cell] = true
		if lift_from is Vector2:
			_lifting[cell] = Vector3(lift_from.x, lift_from.y, _clock)
		queue_redraw()


func _process(delta: float) -> void:
	if _lifting.is_empty():
		return
	_clock += delta
	var reach := _outer[0].length()
	for cell in _lifting.keys():
		var lift := _lifting[cell]
		if (_clock - lift.z) * LIFT_SPEED >= _map.ground_layer.map_to_local(cell).distance_to(Vector2(lift.x, lift.y)) + reach:
			_lifting.erase(cell)
	queue_redraw()


## How much fog a lift leaves at a map spot: none behind its front, full LIFT_SOFT past it.
func _fog_at(spot: Vector2, lift: Vector3) -> float:
	var front := (_clock - lift.z) * LIFT_SPEED
	return clampf((spot.distance_to(Vector2(lift.x, lift.y)) - front) / LIFT_SOFT, 0.0, 1.0)


func _draw() -> void:
	var clear := Color(1, 1, 1, 0)
	for cell in _cells:
		var at := _map.ground_layer.map_to_local(cell)
		for edge in HexGrid.EDGES:
			var next := HexGrid.neighbor(cell, edge)
			# Edge E runs from corner 1 to corner 2, and each edge after it one corner on.
			var a := (edge + 1) % HexGrid.EDGES
			var b := (edge + 2) % HexGrid.EDGES
			var fog_a := 1.0
			var fog_b := 1.0
			if _cells.has(next):
				if not _lifting.has(next):
					continue
				fog_a = _fog_at(at + _outer[a], _lifting[next])
				fog_b = _fog_at(at + _outer[b], _lifting[next])
				if fog_a <= 0.0 and fog_b <= 0.0:
					continue
			draw_polygon(PackedVector2Array([at + _outer[a], at + _outer[b], at + _inner[b], at + _inner[a]]),
					PackedColorArray([Color(1, 1, 1, fog_a), Color(1, 1, 1, fog_b), clear, clear]))
		if _lifting.has(cell):
			# A fan from the middle, so the front can cross the tile rather than the whole tile thinning at once.
			var lift := _lifting[cell]
			var mid := _fog_at(at, lift)
			for i in HexGrid.EDGES:
				var p := at + _outer[i]
				var q := at + _outer[(i + 1) % HexGrid.EDGES]
				var fog_p := _fog_at(p, lift)
				var fog_q := _fog_at(q, lift)
				if mid > 0.0 or fog_p > 0.0 or fog_q > 0.0:
					draw_polygon(PackedVector2Array([at, p, q]),
							PackedColorArray([Color(1, 1, 1, mid), Color(1, 1, 1, fog_p), Color(1, 1, 1, fog_q)]))
