extends Control
## The landing page: the cover's loop (`Assets/Landing/cover.ogv`, or `cover_tall.ogv` on a screen
## held upright), with the waiting list's email field and Join along its foot and, under them, "Golden
## door": the password typed into its prompt is the way into the game.

const GAME := "res://Scenes/main_scene.tscn"
const WAITLIST := Cloud.URL + "/waitlist"
## What "Golden door" takes, in any case.
const PASSWORDS := ["goldenkey", "golden key"]
## The form's air below it, and the field's width, in panel pixels.
const FOOT := 12
const FIELD_WIDTH := 160
## Each loop: its stream, its size in the cover's own pixels, and the middle of it that must stay
## on screen (`AI-sprites-generator/cover.py`'s `crop_916`). Whole for the 16:9 one; the upright
## one is drawn 9:19.5 and may lose sky and grass down to 9:16, and a little off each side.
const WIDE := [preload("res://Assets/Landing/cover.ogv"), Vector2(256, 144), Vector2(256, 144)]
const TALL := [preload("res://Assets/Landing/cover_tall.ogv"), Vector2(180, 390), Vector2(168, 320)]

@onready var _video: VideoStreamPlayer = $Video
var _form: VBoxContainer
var _email: LineEdit
var _join: Button
var _note: Label


func _ready() -> void:
	# Drawn at the window's own pixels, as the main scene is (its `_ready`): the stretch would blur the form.
	if DisplayServer.get_name() != "headless":
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# Full screen from the first frame, where the player chose it: the cover plays in what the game will.
	if Settings.has_window():
		Settings.path = Settings.SAVE_PATH
		Settings.load_settings()
		Settings.apply_window()
	# The game's files load behind the video, so the click only has to start it.
	ResourceLoader.load_threaded_request(GAME)
	_build_form()
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
	_form.scale = Vector2.ONE * UITheme.pick_scale(size)
	_form.size = _form.get_combined_minimum_size()
	var drawn := _form.size * _form.scale
	_form.position = Vector2((size.x - drawn.x) / 2, size.y - drawn.y - FOOT * _form.scale.y)


func _build_form() -> void:
	_form = VBoxContainer.new()
	_form.theme = UITheme.theme()
	var row := HBoxContainer.new()
	_email = UITheme.text_field("Your email", 254, FIELD_WIDTH)
	_join = UITheme.button("Join the waiting list", UITheme.GO_BUTTON, "")
	row.add_child(_email)
	row.add_child(_join)
	_form.add_child(row)
	_note = UITheme.label("", UITheme.FONT_COLOR, true)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Outlined: it stands on the moving cover, not on a panel.
	_note.add_theme_constant_override("outline_size", 4)
	_note.add_theme_color_override("font_outline_color", Palette.INK)
	_note.hide()
	_form.add_child(_note)
	var door := UITheme.button("Golden door", UITheme.GOLD_BUTTON, "")
	door.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_form.add_child(door)
	add_child(_form)
	_join.pressed.connect(_sign_up)
	_email.text_submitted.connect(func(_typed: String) -> void: _sign_up())
	door.pressed.connect(_ask_password)


## The game's own text box over the cover. A button presses on its release, so the click that leaves
## this page never lands on the map behind it.
func _ask_password() -> void:
	var prompt := TextPrompt.new("Password", "", "Enter", 32, _form.scale.x)
	prompt.entered.connect(func(text: String) -> void:
		if text.strip_edges().to_lower() in PASSWORDS:
			_start()
		else:
			_say("That is not the password"))
	add_child(prompt)


func _sign_up() -> void:
	if _join.disabled:
		return
	_join.disabled = true
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
		http.queue_free()
		var answer: Variant = JSON.parse_string(body.get_string_from_utf8())
		var joined := result == HTTPRequest.RESULT_SUCCESS and code == 201
		var said := "Could not reach the list, try again"
		if joined:
			said = "You are on the list!"
		elif answer is Dictionary and answer.has("error"):
			said = str(answer.error)
		_say(said)
		_join.disabled = joined
		_email.editable = not joined)
	var body := JSON.stringify({"email": _email.text.strip_edges()})
	if http.request(WAITLIST, ["Content-Type: application/json"], HTTPClient.METHOD_POST, body) != OK:
		http.request_completed.emit(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


func _say(text: String) -> void:
	_note.text = text
	_note.show()
	_fit()


func _start() -> void:
	# Waits out the rest of the load when the click comes before it is done.
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME))
