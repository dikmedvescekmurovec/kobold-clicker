extends Control
## The landing page: the cover's loop (`Assets/Landing/cover.ogv`, or `cover_tall.ogv` on a screen
## held upright) until a click, then the game.

const GAME := "res://Scenes/main_scene.tscn"
## Each loop: its stream, its size in the cover's own pixels, and the middle of it that must stay
## on screen (`AI-sprites-generator/cover.py`'s `crop_916`). Whole for the 16:9 one; the upright
## one is drawn 9:19.5 and may lose sky and grass down to 9:16, and a little off each side.
const WIDE := [preload("res://Assets/Landing/cover.ogv"), Vector2(256, 144), Vector2(256, 144)]
const TALL := [preload("res://Assets/Landing/cover_tall.ogv"), Vector2(180, 390), Vector2(168, 320)]

@onready var _video: VideoStreamPlayer = $Video


func _ready() -> void:
	# The game's files load behind the video, so the click only has to start it.
	ResourceLoader.load_threaded_request(GAME)
	resized.connect(_fit)
	_fit()
	# A headless run is a test or a quick check of the game itself: straight through.
	if DisplayServer.get_name() == "headless":
		_start.call_deferred()


## The loop for the screen's way up, as large as fills it without cutting into the part that must
## stay: a phone turned round mid-loop gets the other loop.
func _fit() -> void:
	var cover: Array = TALL if size.y > size.x else WIDE
	if _video.stream != cover[0]:
		_video.stream = cover[0]
		_video.play()
	var full: Vector2 = cover[1]
	var keep: Vector2 = cover[2]
	var fill := maxf(size.x / full.x, size.y / full.y)
	var zoom := minf(fill, minf(size.x / keep.x, size.y / keep.y))
	_video.size = full * zoom
	_video.position = (size - _video.size) / 2


func _input(event: InputEvent) -> void:
	# On the release, so the click that leaves this page never lands on the map behind it.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_start()


func _start() -> void:
	set_process_input(false)
	# Waits out the rest of the load when the click comes before it is done.
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME))
