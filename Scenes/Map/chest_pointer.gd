class_name ChestPointer
extends Polygon2D
## A four-point glimmer pinned to the window's edge in the direction of the nearest treasure chest.
## It hints that something is out there; the chest itself is only drawn once its tile is seen.

## How far in from the window's edge it sits, in screen pixels.
const MARGIN := 40.0
const TWINKLE_SECONDS := 1.2

## The chest pointed at, HexMap.NO_CELL for none. Set on arrival, the only time the player moves.
var target := HexMap.NO_CELL
var _map: HexMap
var _view: MapBuilder
var _ui_scale: float


func _init(map: HexMap, view: MapBuilder, ui_scale: float) -> void:
	_map = map
	_view = view
	_ui_scale = ui_scale
	polygon = PackedVector2Array([Vector2(0, -6), Vector2(1, -1), Vector2(6, 0), Vector2(1, 1),
			Vector2(0, 6), Vector2(-1, 1), Vector2(-6, 0), Vector2(-1, -1)])
	color = Color(1.0, 0.95, 0.7)
	hide()


## Twinkles by growing, turning and fading. Started here because a tween needs the tree.
func _ready() -> void:
	var small := Vector2.ONE * _ui_scale * 0.4
	var twinkle := create_tween().set_loops()
	twinkle.tween_property(self, "scale", Vector2.ONE * _ui_scale * 1.3, TWINKLE_SECONDS).from(small)
	twinkle.parallel().tween_property(self, "rotation", PI / 4.0, TWINKLE_SECONDS).from(0.0)
	twinkle.parallel().tween_property(self, "modulate:a", 1.0, TWINKLE_SECONDS).from(0.3)
	twinkle.tween_property(self, "scale", small, TWINKLE_SECONDS)
	twinkle.parallel().tween_property(self, "modulate:a", 0.3, TWINKLE_SECONDS)


## Where the line from the middle of the window to the chest leaves it. A chest already on screen and
## seen needs no pointer; one still in the fog gets it over its own tile.
func _process(_delta: float) -> void:
	visible = target != HexMap.NO_CELL and _map.visible
	if not visible:
		return
	var screen := get_viewport_rect().size
	var at := get_viewport().get_canvas_transform() * _map.ground_layer.to_global(
			_map.ground_layer.map_to_local(target))
	visible = not (Rect2(Vector2.ZERO, screen).grow(-MARGIN).has_point(at) and _view.seen(target))
	if not visible:
		return
	var center := screen / 2.0
	var ray := at - center
	var fit := 1.0
	for axis in 2:
		if absf(ray[axis]) > center[axis] - MARGIN:
			fit = minf(fit, (center[axis] - MARGIN) / absf(ray[axis]))
	position = center + ray * fit
