class_name CaveSense
extends ColorRect
## The Gollux cave as the hero feels it (the user's, 2026-10-03, in place of the Seeing Stone): a band of
## red light breathing along the edge of the map, thickest where the line from the hero toward this
## world's cave leaves it, reaching further in and along and burning brighter the nearer the cave is
## (`FortuneTeller.warmth`'s bands). Up
## from the moment the wall in front of the cave falls until the cave is seen (`felt`). It says which way and
## roughly how far, never which tile. The light itself is `cave_sense.gdshader`.

const SHADER := preload("res://Scenes/Map/cave_sense.gdshader")
## By `FortuneTeller.WARMTH` band, coldest first: how far in from the edge the band reaches at its heart
## and how far along the edge either side it runs, both as shares of the map's short side, and how
## strong it is at the edge.
const REACH: Array[float] = [0.1, 0.13, 0.17, 0.21, 0.27]
const SPAN: Array[float] = [0.4, 0.44, 0.48, 0.52, 0.6]
const STRENGTH: Array[float] = [0.75, 0.8, 0.85, 0.9, 0.95]
## Breaths a second, as slow as the pit's own light; none with animations off.
const BREATH := 0.25

## The part of the window the map is seen through, in window pixels: the light stands at its edge. Empty
## is the whole window. The main scene sets it, as it does the map's pointers'.
var room := Rect2()
var _map: HexMap
var _view: MapBuilder


func _init(map: HexMap, view: MapBuilder) -> void:
	_map = map
	_view = view
	material = ShaderMaterial.new()
	(material as ShaderMaterial).shader = SHADER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Under every panel on the interface layer, as the map's pointers are.
	z_index = -1
	hide()


func _process(_delta: float) -> void:
	visible = shown()
	if not visible:
		return
	var area := room if room.has_area() else get_viewport_rect()
	position = area.position
	size = area.size
	var to_screen := get_viewport().get_canvas_transform()
	var hero := to_screen * _map.player.global_position
	var cave := to_screen * _map.ground_layer.to_global(_map.ground_layer.map_to_local(_view.cave))
	var band := FortuneTeller.warmth(HexGrid.distance(_view.player_cell, _view.cave))
	var light := material as ShaderMaterial
	var short := minf(area.size.x, area.size.y)
	light.set_shader_parameter("area", area.size)
	light.set_shader_parameter("focus", leaving(hero, cave - hero, area) - area.position)
	light.set_shader_parameter("reach", REACH[band] * short)
	light.set_shader_parameter("span", SPAN[band] * short)
	light.set_shader_parameter("strength", STRENGTH[band])
	light.set_shader_parameter("pixel", maxf(1.0, to_screen.x.x))
	light.set_shader_parameter("breath", 0.0 if Settings.animations == Settings.Anim.NONE else BREATH)


## Whether the light is up: `felt()`, and the map on the screen.
func shown() -> bool:
	return felt() and _map.visible


## Whether the hero feels the cave (the user's, 2026-10-03): put down in this world, the wall in front of
## it broken -- its cell is land now -- and not yet seen. In a world after a transcension the cave is
## down from the start, often walls out, and stays unfelt until the land reaches it.
func felt() -> bool:
	return _view.cave != HexMap.NO_CELL and _view.is_land(_view.cave) and not _view.seen(_view.cave)


## Where the line from `from` along `way` leaves `area`, `from` brought inside it first: a hero panned off
## the screen still feels the cave from the edge nearest them.
static func leaving(from: Vector2, way: Vector2, area: Rect2) -> Vector2:
	from = from.clamp(area.position, area.end)
	var t := INF
	for axis in 2:
		if way[axis] > 0.0:
			t = minf(t, (area.end[axis] - from[axis]) / way[axis])
		elif way[axis] < 0.0:
			t = minf(t, (area.position[axis] - from[axis]) / way[axis])
	return from if is_inf(t) else from + way * t
