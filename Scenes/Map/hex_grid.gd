class_name HexGrid
extends RefCounted
## Pointy-top hex grid math in offset coordinates with odd rows shifted half a tile right,
## the same layout the map's TileMapLayers use.

## Hex edges, in the order used by the sprite generator's JSON.
enum Edge { E, SE, SW, W, NW, NE }

## Offset to the neighbor across each Edge, for even and odd rows.
const _EVEN_ROW_OFFSETS := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1)]
const _ODD_ROW_OFFSETS := [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]


## Corners of a pointy-top tile around its middle, clockwise from the top. The slanted edges span the top and
## bottom quarter of the tile.
static func corners(tile_size: Vector2) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -tile_size.y / 2), Vector2(tile_size.x / 2, -tile_size.y / 4), Vector2(tile_size.x / 2, tile_size.y / 4),
		Vector2(0, tile_size.y / 2), Vector2(-tile_size.x / 2, tile_size.y / 4), Vector2(-tile_size.x / 2, -tile_size.y / 4),
	])


static func neighbor(cell: Vector2i, edge: int) -> Vector2i:
	var offsets: Array = _ODD_ROW_OFFSETS if cell.y & 1 else _EVEN_ROW_OFFSETS
	return cell + offsets[edge]


## The six neighbors, in Edge order.
static func neighbors(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for edge in 6:
		result.append(neighbor(cell, edge))
	return result


## Number of steps between two cells.
@warning_ignore("integer_division")
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := _to_axial(a) - _to_axial(b)
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


@warning_ignore("integer_division")
static func _to_axial(cell: Vector2i) -> Vector2i:
	return Vector2i(cell.x - (cell.y - (cell.y & 1)) / 2, cell.y)
