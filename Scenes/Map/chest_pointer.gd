class_name ChestPointer
extends Node2D
## A badge pinned to the window's edge in the direction of the chest a fortuneteller was paid to
## find: the chest's own picture on a dark disc ringed with gold, and a gold arrow beating towards it.
##
## It was a pale four-point glimmer while it was free, and that was too quiet for something bought:
## cream on sand or ice disappears, and a sparkle does not say "chest" or "that way". The disc is what
## makes it read on any ground, the picture says what it is, and the arrow says where.

## How far in from the window's edge the badge's middle sits, in screen pixels: room for the arrow at the
## far end of its beat, which reaches 33 badge pixels out at `ui_scale` 2.
const MARGIN := 76.0
## The disc behind the chest, and the ring round it, in the badge's own pixels (drawn at `ui_scale`).
const DISC_RADIUS := 17.0
const RING_WIDTH := 2.0
## The arrow: how far out from the badge's middle it rests, how far it beats, and how long a beat is.
const ARROW_REST := 21.0
const ARROW_BEAT := 5.0
const BEAT_SECONDS := 0.45

## The chest pointed at, HexMap.NO_CELL for none. The main scene sets it (`_sync_chest`).
var target := HexMap.NO_CELL
var _map: HexMap
var _view: MapBuilder
## Turned to face the chest; the arrow is its child, so the beat runs along the way it points.
var _needle := Node2D.new()


func _init(map: HexMap, view: MapBuilder, ui_scale: float) -> void:
	_map = map
	_view = view
	# Whole, like everything else drawn at `ui_scale`, so the chest's pixels stay square.
	scale = Vector2(ui_scale, ui_scale)
	# Over the panels: a chest to the east would otherwise put it behind the tile panel or the town
	# page it was bought on.
	z_index = 1
	add_child(_disc(DISC_RADIUS + RING_WIDTH, Palette.GOLD))
	add_child(_disc(DISC_RADIUS, Palette.INK))
	var chest := Sprite2D.new()
	var texture := AtlasTexture.new()
	texture.atlas = load(MapBuilder.CHEST_TEXTURE)
	texture.region = MapBuilder.CHEST_REGION
	chest.texture = texture
	chest.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(chest)
	add_child(_needle)
	# Ink under gold, a pixel larger all round, so the arrow keeps its edge on light ground too.
	_needle.add_child(_arrow(1.5, Palette.INK))
	_needle.add_child(_arrow(0.0, Palette.GOLD))
	hide()


## The arrow beats outward and back. Started here because a tween needs the tree.
func _ready() -> void:
	var beat := create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	for arrow: Node2D in _needle.get_children():
		arrow.position.x = ARROW_REST
	beat.tween_method(_set_beat, 0.0, ARROW_BEAT, BEAT_SECONDS)
	beat.tween_method(_set_beat, ARROW_BEAT, 0.0, BEAT_SECONDS)


func _set_beat(out: float) -> void:
	for arrow: Node2D in _needle.get_children():
		arrow.position.x = ARROW_REST + roundf(out)


## Where the line from the middle of the window to the chest leaves it. A chest already on screen and
## seen needs no pointer; one on screen but still in the dark gets the badge over its own tile, with
## no arrow, since there is nowhere further to point.
func _process(_delta: float) -> void:
	visible = target != HexMap.NO_CELL and _map.visible
	if not visible:
		return
	var screen := get_viewport_rect().size
	var at := get_viewport().get_canvas_transform() * _map.ground_layer.to_global(
			_map.ground_layer.map_to_local(target))
	var on_screen := Rect2(Vector2.ZERO, screen).grow(-MARGIN).has_point(at)
	visible = not (on_screen and _view.seen(target))
	if not visible:
		return
	var center := screen / 2.0
	var ray := at - center
	var fit := 1.0
	for axis in 2:
		if absf(ray[axis]) > center[axis] - MARGIN:
			fit = minf(fit, (center[axis] - MARGIN) / absf(ray[axis]))
	position = (center + ray * fit).round()
	_needle.visible = not on_screen
	_needle.rotation = ray.angle()


static func _disc(radius: float, color: Color) -> Polygon2D:
	var disc := Polygon2D.new()
	var points := PackedVector2Array()
	for i in 24:
		points.append(Vector2.from_angle(TAU * i / 24.0) * radius)
	disc.polygon = points
	disc.color = color
	return disc


## A triangle pointing along +x, `grow` pixels larger all round.
static func _arrow(grow: float, color: Color) -> Polygon2D:
	var arrow := Polygon2D.new()
	arrow.polygon = PackedVector2Array([Vector2(7 + grow * 1.5, 0), Vector2(-grow, -6 - grow * 1.5),
			Vector2(-grow, 6 + grow * 1.5)])
	arrow.color = color
	return arrow
