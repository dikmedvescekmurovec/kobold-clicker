class_name Comic
extends Control
## The comic a first run opens on (the user's story and art, 2026-10-29): a knight dies to Gollux, the
## System makes him a kobold, and the kobold grows strong enough to stand before the ice wall. Its
## pictures and where each stands are `Assets/Comic/` and its `comic.json`, written by
## `AI-sprites-generator/build_comic.py`. A press anywhere brings on the next panel, then the next page;
## past the last, `finished`. Across a window a page stands whole, as drawn; held upright
## (taller than wide) a page's panels go down a column as a webtoon's do, at one zoom, scrolled to the
## newest, and the wall stands at its full height. Skip and Escape (the main scene's) let it go whole.

signal finished

## Marks the comic seen in `inventory.tips`, as it is queued (`owed`).
const ID := "intro_comic"
const FOLDER := "res://Assets/Comic/"
const MANIFEST := FOLDER + "comic.json"
## Held upright, in comic pixels: the zoom is the largest whole one that fits `COLUMN` across; a panel
## stands `SIDE` off one edge or the other, turn about, `GAP` under the last, the first `TOP` down, and
## the newest `GAP` over Skip (the phone mock-up the user passed, `comic.py --phone`).
const COLUMN := 216
const SIDE := 6
const GAP := 6
const TOP := 24
const SCROLL_TIME := 0.3

var _size := Vector2.ZERO
var _pages: Array = []
var _page := 0
## How many of the page's panels are up.
var _shown := 1
var _ui_scale := 1.0
var _ground: ColorRect
var _art: Control
var _skip: Button
## Held upright: how far up the column is scrolled, in window pixels, so the next scroll starts there.
var _scrolled := 0.0


## Whether `inventory` is a first run still owed the comic: no body has ever fallen in it (a
## transcension keeps the count, so never after one) and it was never queued.
static func owed(inventory: Inventory) -> bool:
	return ID not in inventory.tips and inventory.kills == 0


func _init(ui_scale: float) -> void:
	_ui_scale = ui_scale
	theme = UITheme.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# The wall drawn at its full height runs far past the sides of a window held upright.
	clip_contents = true
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
	_size = Vector2(manifest["size"][0], manifest["size"][1])
	_pages = manifest["pages"]
	_ground = ColorRect.new()
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ground)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)
	_skip = UITheme.button("Skip", "LightButton", "")
	_skip.scale = Vector2.ONE * ui_scale
	_skip.pressed.connect(finished.emit)
	add_child(_skip)


func _ready() -> void:
	resized.connect(_lay_out.bind(false))
	_lay_out(true)


## A press: the next panel, the next page's first after a page's last, and past the last `finished`.
func advance() -> void:
	if _shown < (_pages[_page]["panels"] as Array).size():
		_shown += 1
	elif _page + 1 < _pages.size():
		_page += 1
		_shown = 1
		_scrolled = 0.0
	else:
		finished.emit()
		return
	_lay_out(true)


## How many presses go from the first panel to `finished`.
func presses() -> int:
	var panels := 0
	for page: Dictionary in _pages:
		panels += (page["panels"] as Array).size()
	return panels


## Fades away, then goes.
func leave() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Settings.animations == Settings.Anim.NONE:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, Juice.LEAVE_TIME)
	tween.tween_callback(queue_free)


## The page as far as it has come, drawn again whole for the window as it is now; `pop` swells the
## newest panel in.
func _lay_out(pop: bool) -> void:
	var view := get_viewport_rect().size
	# Skip in the bottom-right corner: a page fills the default window to its edges, and its top-right
	# holds the find's window; down there it only ever covers sky, light or snow.
	var safe := UITheme.safe_rect(get_viewport())
	_skip.position = (safe.end - (_skip.get_combined_minimum_size() + Vector2.ONE * UITheme.EDGE) * _ui_scale) \
			.round()
	var page: Dictionary = _pages[_page]
	var panels: Array = page["panels"]
	_ground.color = Palette.BONE if page["paper"] else Palette.INK
	UITheme.clear(_art)
	# Taller than wide, not `UITheme.narrow`: a desktop window stood on end (745x974 at ui_scale 1) is not
	# narrow, and its page fit only at 1x, 23 px short of 2x; the column there stands at 3x.
	var upright := view.y > view.x
	var column := maxf(1.0, floorf(view.x / COLUMN))
	var zoom := maxf(1.0, floorf(minf(view.x / _size.x, view.y / _size.y)))
	var origin := ((view - _size * zoom) / 2.0).round()
	var scroll := 0.0
	if upright and page["paper"]:
		zoom = column
		origin = Vector2.ZERO
		var across := view.x / zoom
		var y := float(TOP)
		for i in _shown:
			var own: Vector2 = load(FOLDER + panels[i]["file"]).get_size()
			var at := Vector2(float(SIDE) if i % 2 == 0 else across - SIDE - own.x, y)
			_picture(panels[i]["file"], (at * zoom).round(), zoom, pop and i == _shown - 1)
			y += own.y + GAP
		scroll = maxf(0.0, y * zoom - _skip.position.y)
	elif upright and page.has("tall"):
		# The wall at its full height, its column about the kobold and its near edge in the middle.
		zoom = maxf(1.0, floorf(view.y / _size.y))
		origin = Vector2(view.x / 2.0 - float(page["tall"]) * zoom, (view.y - _size.y * zoom) / 2.0).round()
		_picture(panels[0]["file"], Vector2.ZERO, zoom, pop)
	else:
		# A caption held upright is at the column's zoom, centred, its black running past the sides.
		if upright:
			zoom = column
			origin = ((view - _size * zoom) / 2.0).round()
		for i in _shown:
			_picture(panels[i]["file"], Vector2(panels[i]["at"][0], panels[i]["at"][1]) * zoom, zoom,
					pop and i == _shown - 1)
	_art.position = origin - Vector2(0.0, _scrolled)
	if scroll != _scrolled and pop and Settings.animations != Settings.Anim.NONE:
		_art.create_tween().tween_property(_art, "position:y", origin.y - scroll, SCROLL_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	else:
		_art.position.y = origin.y - scroll
	_scrolled = scroll


## One of the comic's pictures under `_art`, its top-left at `at`, `zoom` times its size, swelling in
## about its middle if `pop`.
func _picture(file: String, at: Vector2, zoom: float, pop: bool) -> void:
	var picture := TextureRect.new()
	picture.texture = load(FOLDER + file)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size = picture.texture.get_size()
	picture.pivot_offset = picture.size / 2.0
	# Scaled about its middle, a Control is drawn `pivot * (scale - 1)` up and left of its position.
	picture.position = at + picture.pivot_offset * (zoom - 1.0)
	_art.add_child(picture)
	if pop:
		Juice.pop_in(picture, zoom)
	else:
		picture.scale = Vector2.ONE * zoom


func _gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		advance()
