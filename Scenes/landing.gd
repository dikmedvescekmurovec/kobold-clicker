extends Control
## The landing page: the cover's loop (`Assets/Landing/cover.ogv`) until a click, then the game.

const GAME := "res://Scenes/main_scene.tscn"


func _ready() -> void:
	# The game's files load behind the video, so the click only has to start it.
	ResourceLoader.load_threaded_request(GAME)
	# A headless run is a test or a quick check of the game itself: straight through.
	if DisplayServer.get_name() == "headless":
		_start.call_deferred()


func _input(event: InputEvent) -> void:
	# On the release, so the click that leaves this page never lands on the map behind it.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_start()


func _start() -> void:
	set_process_input(false)
	# Waits out the rest of the load when the click comes before it is done.
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME))
