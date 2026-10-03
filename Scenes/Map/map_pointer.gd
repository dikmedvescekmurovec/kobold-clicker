class_name MapPointer
extends Node2D
## A badge pinned to the window's edge in the direction of a cell: a picture on a dark disc ringed with
## gold, and a gold arrow beating towards the cell. Two stand over the map: the chest a fortuneteller was
## paid to find, and the hero, whose badge is a button that brings the camera back to them.
##
## It was a pale four-point glimmer while it was free, and that was too quiet for something bought:
## cream on sand or ice disappears, and a sparkle does not say "chest" or "that way". The disc is what
## makes it read on any ground, the picture says what it is, and the arrow says where.

## How far in from the window's edge the badge's middle sits, in screen pixels: room for the arrow at the
## far end of its beat, which reaches 33 badge pixels out at `ui_scale` 2.
const MARGIN := 76.0
## The disc behind the picture, and the ring round it, in the badge's own pixels (drawn at `ui_scale`).
const DISC_RADIUS := 17.0
const RING_WIDTH := 2.0
## The arrow: how far out from the badge's middle it rests, how far it beats, and how long a beat is.
const ARROW_REST := 21.0
const ARROW_BEAT := 5.0
const BEAT_SECONDS := 0.45

## The cell pointed at, HexMap.NO_CELL for none. The main scene sets it (`_sync_chest`, `_process`).
var target := HexMap.NO_CELL
## The part of the window, in window pixels, the map is seen through: the target is on screen inside it
## (less `MARGIN`), and the badge stands in it. Empty is the whole window.
var room := Rect2()
var _map: HexMap
var _view: MapBuilder
## Turned to face the target; the arrow is its child, so the beat runs along the way it points.
var _needle := Node2D.new()
## The disc as a button, when the badge was given something to do.
var _button: Button


## `picture` is cut to the disc, so a bigger one is a close-up. A `pressed` makes the disc a button.
func _init(map: HexMap, view: MapBuilder, ui_scale: float, picture: Texture2D, tooltip := "",
		pressed := Callable()) -> void:
	_map = map
	_view = view
	# Whole, like everything else drawn at `ui_scale`, so the picture's pixels stay square.
	scale = Vector2(ui_scale, ui_scale)
	# Under every panel on the interface layer, and over nothing else there: the badge stands for as
	# long as its target does rather than ducking out for whatever page is open, and a panel that
	# happens to lie over it simply covers that corner of it.
	z_index = -1
	add_child(_disc(DISC_RADIUS + RING_WIDTH, Palette.GOLD))
	var disc := _disc(DISC_RADIUS, Palette.INK)
	disc.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(disc)
	var sprite := Sprite2D.new()
	sprite.texture = picture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	disc.add_child(sprite)
	add_child(_needle)
	# Ink under gold, a pixel larger all round, so the arrow keeps its edge on light ground too.
	_needle.add_child(_arrow(1.5, Palette.INK))
	_needle.add_child(_arrow(0.0, Palette.GOLD))
	if pressed.is_valid():
		_button = Button.new()
		_button.flat = true
		_button.focus_mode = Control.FOCUS_NONE
		_button.tooltip_text = tooltip
		_button.size = Vector2.ONE * (DISC_RADIUS + RING_WIDTH) * 2.0
		_button.position = -_button.size / 2.0
		_button.pressed.connect(pressed)
		add_child(_button)
	hide()


## `region` of the sheet at `path`, as a picture for the disc.
static func cut(path: String, region: Rect2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(path)
	texture.region = region
	return texture


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


## Where the line from the middle of the room to the target leaves it. A target already on screen and
## seen needs no pointer; one on screen but still in the dark gets the badge over its own tile, with
## no arrow, since there is nowhere further to point.
##
## A button stands still at the foot of the room instead, and only its arrow turns: running round the
## edge, it went under the character panel and the tile panel, where a press never reached it.
func _process(_delta: float) -> void:
	visible = target != HexMap.NO_CELL and _map.visible
	if not visible:
		return
	var area := room if room.has_area() else get_viewport_rect()
	var at := get_viewport().get_canvas_transform() * _map.ground_layer.to_global(
			_map.ground_layer.map_to_local(target))
	var on_screen := area.grow(-MARGIN).has_point(at)
	visible = not (on_screen and _view.seen(target))
	if not visible:
		return
	if _button != null:
		position = Vector2(area.get_center().x, area.end.y - MARGIN).round()
		_needle.rotation = (at - position).angle()
		return
	var center := area.get_center()
	var ray := at - center
	var fit := 1.0
	for axis in 2:
		var reach := area.size[axis] / 2.0 - MARGIN
		if absf(ray[axis]) > reach:
			fit = minf(fit, reach / absf(ray[axis]))
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
