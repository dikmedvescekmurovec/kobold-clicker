extends Control
## The landing page, the project's main scene, and the page that sells the game (the user's ask,
## 2026-10-11): the cover's loop (`Assets/Landing/cover.ogv`, or `cover_tall.ogv` on a screen held
## upright) fixed behind a page that scrolls. Its first screen is the cover with the waiting list's
## email field and Join at its foot and, under them, "Golden door", whose password is asked once a
## device (`Settings.door_open`). Under that, on a flat ground that hides the cover as it comes up, a
## row a feature -- a short or a still of the game beside a heading and two sentences -- and the form
## again. `Scenes/DESIGN.md`, "Landing page", has the why.

const GAME := "res://Scenes/main_scene.tscn"
## What "Golden door" takes, in any case.
const PASSWORDS := ["goldenkey", "golden key"]
## How long `_start` waits for the window to come back from under a phone's keyboard, in seconds.
const KEYBOARD_GONE := 1.5
## The first form's air below it, which the chevron stands in, and the field's width, in panel pixels.
const FOOT := 44
const FIELD_WIDTH := 160
## Each loop: its stream, its size in the cover's own pixels, and the middle of it that must stay
## on screen (`AI-sprites-generator/cover.py`'s `crop_916`). Whole for the 16:9 one; the upright
## one is drawn 9:19.5 and may lose sky and grass down to 9:16, and a little off each side.
const WIDE := [preload("res://Assets/Landing/cover.ogv"), Vector2(256, 144), Vector2(256, 144)]
const TALL := [preload("res://Assets/Landing/cover_tall.ogv"), Vector2(180, 390), Vector2(168, 320)]

## Every picture is this wide in its own pixels, and none taller than a short (`tools/landing_media.py`).
const PICTURE := Vector2(360, 636)
## The page's measures, in panel pixels: its margin, the air between two features, between a picture and
## its words, and the words' column where they stand beside the picture.
const MARGIN := 12
const FEATURE_GAP := 32
const WORDS_GAP := 12
const WORDS_WIDTH := 200
## A heading is Pixellari at its own 16 px, drawn this many times over: the font breaks up at any
## other size (the root CLAUDE.md), so the Label is scaled inside a holder that takes its room.
const HEADING_SCALE := 2.0
## Each feature: its heading's lines (the reels' own captions, none over twelve letters: the longest
## sets every heading's size on a phone), its few short lines, its picture (a short or a still), and
## for a short that is not `PICTURE.y` rows tall (a clip's: `tools/landing_media.py` prints it) its rows.
## The copy sells, in the reels' voice -- short, cocky, said to the player -- because the first draft
## read as a list of features (the user's, 2026-10-11: "not hype at all"). Every claim in it is still
## true of the game: a tile is ten bodies in thirty seconds, a chest is a mimic, Gollux is the third
## wall's, there are 48 uniques.
const FEATURES := [
	[["EVERY CLICK", "COUNTS"], "Thirty seconds to drop ten monsters. Your sword swings by itself and it's "
			+ "nowhere near enough. Start clicking.", preload("res://Assets/Landing/click.ogv")],
	[["LOOT"], "Trash. Trash. More trash. Then a gold beam hits the dirt and your whole build changes. "
			+ "48 uniques, and every one breaks a rule.", preload("res://Assets/Landing/loot.ogv")],
	[["CRAFT"], "Wrong stats? Throw an orb at it. Still wrong? Throw another. Keep going until that junk sword "
			+ "is the best thing you own.", preload("res://Assets/Landing/craft.ogv"), 480],
	[["CHART", "THE FOG"], "A new world every time, and you start out blind. Fight for every tile. Find the "
			+ "towns. Never trust a chest.", preload("res://Assets/Landing/map.png")],
	[["THE ICE WALL"], "The world stops at a wall of ice. The wall has a health bar. Kill it and there's more "
			+ "world behind it, plus an unlock that's yours for good.", preload("res://Assets/Landing/wall.ogv")],
	[["BUILD YOUR", "SKILL TREE"], "Nobody hands you a skill tree here. The nodes drop off monsters and you bolt "
			+ "them together yourself. Good luck.", preload("res://Assets/Landing/tree.png")],
	[["HOW DEEP", "CAN YOU GO?"], "Past the third wall there's a cave, and something called Gollux at the bottom "
			+ "of it. There's always another bottom. The leaderboard keeps score.",
			preload("res://Assets/Landing/descent.ogv")],
	[["BEGIN AGAIN", "STRONGER"], "Throw the whole world away and keep one item. Then curse the next world on "
			+ "purpose, because clearly this one was too easy.", preload("res://Assets/Landing/transcend.png")],
	[["LOOT WHILE", "YOU SLEEP"], "Close the game. Your kobold keeps hunting. Come back to gold, levels and a "
			+ "bag of loot you slept through. Break more walls and it hunts longer.",
			preload("res://Assets/Landing/camp.png")],
]
const CLOSING := ["WANT IN?"]
## The chevron at the first screen's foot, stamped here: gold (`g`) in an ink outline (`o`).
const CHEVRON: Array[String] = [
	"ooo.........ooo",
	"oggo.......oggo",
	"ogggo.....ogggo",
	".ogggo...ogggo.",
	"..ogggo.ogggo..",
	"...ogggogggo...",
	"....ogggggo....",
	".....ogggo.....",
	"......ogo......",
	".......o.......",
]
## Its room to be pressed in, its air below, and how far and how long it bobs.
const CHEVRON_SIZE := Vector2(40, 24)
const CHEVRON_FOOT := 8
const CHEVRON_BOB := 3.0
const CHEVRON_SECONDS := 0.6

@onready var _video: VideoStreamPlayer = $Video
## Whether this is the game starting, and not a test or a script that built the page to look at it: only
## then are the settings read, the game loaded behind it and a headless run sent straight through.
var _real := false
var _scale := 1.0
## The window as the password prompt opened, before a phone's keyboard took half of it (`_start`).
var _unkeyed := Vector2.ZERO
var _page: ScrollContainer
var _hero: Control
var _form: VBoxContainer
var _chevron: TextureButton
var _chevron_rest := Vector2.ZERO
## Both forms' parts, the first screen's first: joining at one locks both.
var _form_rows: Array[BoxContainer] = []
var _emails: Array[LineEdit] = []
var _joins: Array[Button] = []
var _notes: Array[Label] = []
## A feature's row, its picture (in its frame), the picture's own size, its words and its headings.
var _rows: Array[BoxContainer] = []
var _pictures: Array[Control] = []
var _picture_sizes: Array[Vector2] = []
var _words: Array[VBoxContainer] = []
var _bodies: Array[Label] = []
var _headings: Array[Label] = []
var _shorts: Array[VideoStreamPlayer] = []


func _ready() -> void:
	_real = get_tree().current_scene == self
	var headless := DisplayServer.get_name() == "headless"
	# Drawn at the window's own pixels, as the main scene is (its `_ready`): the stretch would blur the form.
	if not headless:
		get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	# The settings before anything asks them: full screen from the first frame where the player chose
	# it, and whether the door is open already. `Settings.save` writes the whole file, so the door's
	# flag can only be saved after this load.
	if _real and not headless:
		Settings.path = Settings.SAVE_PATH
		Settings.load_settings()
		Settings.apply_window()
	# The game's files load behind the video, so the click only has to start it.
	if _real:
		ResourceLoader.load_threaded_request(GAME)
	_build_page()
	resized.connect(_fit)
	_fit()
	# A headless run is a test or a quick check of the game itself: straight through.
	if _real and headless:
		_start.call_deferred()


## The loop for the screen's way up, as large as fills it without cutting into the part that must
## stay: a phone turned round mid-loop gets the other loop. Then the page over it, in panel pixels.
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

	_scale = UITheme.pick_scale(size)
	var room := size / _scale
	var narrow := UITheme.narrow(size, _scale)
	_hero.custom_minimum_size.y = room.y
	_fit_features(room, narrow)
	for row: BoxContainer in _form_rows:
		row.vertical = narrow
	# The page last, once everything in it has its width: a size is clamped to the minimum of the moment
	# it is set at, and a form's row not yet turned made the page 340 wide in a 324 px window for good.
	_page.scale = Vector2.ONE * _scale
	_page.size = room
	# Back to what it holds: a row that has just turned leaves the form the size it was.
	_form.size = _form.get_combined_minimum_size()
	_form.position = Vector2(floorf((room.x - _form.size.x) / 2.0), room.y - _form.size.y - FOOT)
	_chevron_rest = Vector2(floorf((room.x - CHEVRON_SIZE.x) / 2.0), room.y - CHEVRON_SIZE.y - CHEVRON_FOOT)
	_chevron.position = _chevron_rest
	# After the scroll has laid its children out, which it does on a deferred sort.
	_cull.call_deferred()


## Every picture at one zoom, in the game's own pixels: the largest whole number of screen pixels to
## one of the picture's that leaves a short inside the window, so no pixel is drawn wider than its
## neighbour. A window too small for one to one (a phone's 360 across, or one on its side) gets the
## fit instead, smoothed. The words stand beside the picture, and under it held upright.
func _fit_features(room: Vector2, narrow: bool) -> void:
	var widest := 0.0
	for heading: Label in _headings:
		widest = maxf(widest, heading.get_combined_minimum_size().x)
	# The words' column: the page's own width held upright, else wide enough for the longest heading.
	var words := room.x - 2.0 * MARGIN if narrow else maxf(WORDS_WIDTH, widest * HEADING_SCALE)
	# On the narrowest phone the longest heading is wider than the page at double size: all at their own then.
	var times := 1.0 if widest * HEADING_SCALE > words else HEADING_SCALE
	var frame := UITheme.theme().get_stylebox("panel", "WoodPanel").get_minimum_size()
	var across := room.x - 2.0 * MARGIN - frame.x - (0.0 if narrow else WORDS_GAP + words)
	var fit := minf(size.y / PICTURE.y, across * _scale / PICTURE.x)
	var whole := fit >= 1.0
	var zoom := floorf(fit) if whole else fit
	for i in _rows.size():
		_pictures[i].custom_minimum_size = (_picture_sizes[i] * zoom / _scale).floor()
		_pictures[i].texture_filter = (CanvasItem.TEXTURE_FILTER_NEAREST if whole
				else CanvasItem.TEXTURE_FILTER_LINEAR)
		_rows[i].vertical = narrow
		# The picture's side alternates down a wide page; held upright it is always over its words.
		_rows[i].move_child(_pictures[i].get_parent(), 1 if not narrow and i % 2 == 1 else 0)
		_bodies[i].custom_minimum_size.x = words
		_bodies[i].horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if narrow else HORIZONTAL_ALIGNMENT_LEFT
		_words[i].alignment = BoxContainer.ALIGNMENT_BEGIN if narrow else BoxContainer.ALIGNMENT_CENTER
	for heading: Label in _headings:
		var holder := heading.get_parent() as Control
		heading.scale = Vector2.ONE * times
		holder.custom_minimum_size = heading.get_combined_minimum_size() * times
		# The closing heading is always centred; a feature's is where its words are.
		var centred := narrow or holder.has_meta("centred")
		holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER if centred else Control.SIZE_SHRINK_BEGIN


## Only what is on screen plays: the cover while any of the first screen shows, a short while any of
## it does. Nine decoders at once is what a phone's browser cannot give.
func _cull() -> void:
	var window := Rect2(Vector2.ZERO, size)
	_video.paused = not window.intersects(_shown(_hero))
	for short: VideoStreamPlayer in _shorts:
		short.paused = not window.intersects(_shown(short))


## A Control's rect in window pixels, its scale and its ancestors' counted.
static func _shown(control: Control) -> Rect2:
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


func _build_page() -> void:
	_page = UITheme.scroll()
	_page.theme = UITheme.theme()
	_page.get_v_scroll_bar().value_changed.connect(func(_at: float) -> void: _cull.call_deferred())
	add_child(_page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_child(column)

	# The first screen: nothing of its own but the form and the chevron, so the cover shows through.
	_hero = _quiet(Control.new())
	column.add_child(_hero)
	_form = _waitlist_form()
	var door := UITheme.button("Golden door", UITheme.GOLD_BUTTON, "")
	door.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	door.pressed.connect(_on_door_pressed)
	_form.add_child(door)
	_hero.add_child(_form)
	_build_chevron()

	var ground := _quiet(PanelContainer.new()) as PanelContainer
	var ink := StyleBoxFlat.new()
	ink.bg_color = Palette.INK
	ink.content_margin_left = MARGIN
	ink.content_margin_right = MARGIN
	ink.content_margin_top = FEATURE_GAP
	ink.content_margin_bottom = FEATURE_GAP
	ground.add_theme_stylebox_override("panel", ink)
	column.add_child(ground)
	var features := VBoxContainer.new()
	features.add_theme_constant_override("separation", FEATURE_GAP)
	ground.add_child(features)
	for feature: Array in FEATURES:
		features.add_child(_feature(feature[0], feature[1], feature[2],
				float(feature[3]) if feature.size() > 3 else PICTURE.y))
	var closing := VBoxContainer.new()
	closing.add_theme_constant_override("separation", WORDS_GAP)
	closing.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var heading := _heading(CLOSING)
	for line: Control in heading.get_children():
		line.set_meta("centred", true)
	closing.add_child(heading)
	closing.add_child(_waitlist_form())
	features.add_child(closing)


## One feature: its picture in a wood frame, and its heading over its lines. `rows` is a short's height.
func _feature(lines: Array, text: String, picture: Resource, rows: float) -> BoxContainer:
	var row := BoxContainer.new()
	row.add_theme_constant_override("separation", WORDS_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var frame := _quiet(PanelContainer.new())
	frame.theme_type_variation = "WoodPanel"
	frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_child(_picture(picture, rows))
	row.add_child(frame)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", 6)
	words.add_child(_heading(lines))
	var body := BountyList.wrapped(text, WORDS_WIDTH, Palette.BONE)
	words.add_child(body)
	row.add_child(words)
	_rows.append(row)
	_words.append(words)
	_bodies.append(body)
	return row


## A short, which plays round and round while it is on screen (`_cull`), or a still. Sized by `_fit`: a
## still by its texture, a short by `rows`, since a stream does not say its size until it plays.
func _picture(source: Resource, rows: float) -> Control:
	var made: Control
	if source is VideoStream:
		var short := VideoStreamPlayer.new()
		short.stream = source
		short.expand = true
		short.loop = true
		short.autoplay = true
		_shorts.append(short)
		_picture_sizes.append(Vector2(PICTURE.x, rows))
		made = short
	else:
		var still := TextureRect.new()
		# The mode before the texture, or the texture's own size is its minimum (the root CLAUDE.md).
		still.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		still.stretch_mode = TextureRect.STRETCH_SCALE
		still.texture = source
		_picture_sizes.append((source as Texture2D).get_size())
		made = still
	_pictures.append(made)
	return _quiet(made)


## A caption in the reels' look: Pixellari, outlined in ink, at `HEADING_SCALE`, the last line gold.
func _heading(lines: Array) -> VBoxContainer:
	var made := VBoxContainer.new()
	made.add_theme_constant_override("separation", 0)
	for i in lines.size():
		var holder := _quiet(Control.new())
		var label := UITheme.label(str(lines[i]), Palette.GOLD if i == lines.size() - 1 else Palette.BONE)
		label.add_theme_constant_override("outline_size", 4)
		label.add_theme_color_override("font_outline_color", Palette.INK)
		holder.add_child(label)
		made.add_child(holder)
		_headings.append(label)
	return made


## The chevron that says there is more below: it bobs, and a press brings the first feature up.
func _build_chevron() -> void:
	_chevron = TextureButton.new()
	_chevron.texture_normal = ImageTexture.create_from_image(
			UITheme.stamp(CHEVRON, {"g": Palette.GOLD, "o": Palette.INK}))
	_chevron.ignore_texture_size = true
	_chevron.stretch_mode = TextureButton.STRETCH_KEEP_CENTERED
	_chevron.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_chevron.size = CHEVRON_SIZE
	_chevron.pressed.connect(_scroll_down)
	_hero.add_child(_chevron)
	if Settings.animations != Settings.Anim.NONE:
		var bob := _chevron.create_tween().set_loops().set_trans(Tween.TRANS_SINE)
		bob.tween_method(_bob, 0.0, CHEVRON_BOB, CHEVRON_SECONDS)
		bob.tween_method(_bob, CHEVRON_BOB, 0.0, CHEVRON_SECONDS)


## In whole pixels, off the place `_fit` gave it.
func _bob(down: float) -> void:
	_chevron.position.y = _chevron_rest.y + roundf(down)


func _scroll_down() -> void:
	var to := int(_hero.size.y)
	if Settings.animations == Settings.Anim.NONE:
		_page.scroll_vertical = to
	else:
		create_tween().tween_property(_page, "scroll_vertical", to, 0.5).set_trans(
				Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Out of the mouse's way, so a wheel or a finger's drag over it reaches the scroll: everything on the
## page that is not a field or a button.
static func _quiet(control: Control) -> Control:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control


## A waiting-list form: the email field beside Join -- over it where the window is narrow, the two
## being wider than a phone -- and the line that answers. The page has two, and joining at one locks both.
func _waitlist_form() -> VBoxContainer:
	var form := VBoxContainer.new()
	var row := BoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var email := UITheme.text_field("Your email", 254, FIELD_WIDTH)
	var join := UITheme.button("Join the waiting list", UITheme.GO_BUTTON, "")
	row.add_child(email)
	row.add_child(join)
	form.add_child(row)
	var note := UITheme.label("", UITheme.FONT_COLOR, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Outlined: the first stands on the moving cover, not on a panel.
	note.add_theme_constant_override("outline_size", 4)
	note.add_theme_color_override("font_outline_color", Palette.INK)
	note.hide()
	form.add_child(note)
	join.pressed.connect(_sign_up.bind(email, note))
	email.text_submitted.connect(func(_typed: String) -> void: _sign_up(email, note))
	_form_rows.append(row)
	_emails.append(email)
	_joins.append(join)
	_notes.append(note)
	return form


## The door stands open on a device that has given its password once.
func _on_door_pressed() -> void:
	if Settings.door_open:
		_start()
	else:
		_ask_password()


## The game's own text box over the cover. A button presses on its release, so the click that leaves
## this page never lands on the map behind it.
func _ask_password() -> void:
	_unkeyed = get_viewport_rect().size
	var prompt := TextPrompt.new("Password", "", "Enter", 32, _scale)
	prompt.entered.connect(func(text: String) -> void:
		if text.strip_edges().to_lower() in PASSWORDS:
			Settings.door_open = true
			Settings.save()
			_start()
		else:
			_say(_notes[0], "That is not the password"))
	add_child(prompt)


## Where Join posts: the Worker the cloud calls, so a run pointed at a local one (`LEADERBOARD_URL`)
## never sends an address to the real list.
static func waitlist() -> String:
	return Cloud.url() + "/waitlist"


func _sign_up(email: LineEdit, note: Label) -> void:
	if _joins[0].disabled:
		return
	_lock(true, true)
	var http := HTTPRequest.new()
	# A server that never answers must not leave Join greyed for ever.
	http.timeout = Cloud.TIMEOUT
	add_child(http)
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray,
			body: PackedByteArray) -> void:
		http.queue_free()
		var answer: Variant = JSON.parse_string(body.get_string_from_utf8())
		var joined := result == HTTPRequest.RESULT_SUCCESS and code == 201
		var said := "Could not reach the list, try again"
		if joined:
			said = "You are on the list!"
		elif answer is Dictionary and answer.has("error"):
			said = str(answer.error)
		_say(note, said)
		_lock(joined, not joined))
	var body := JSON.stringify({"email": email.text.strip_edges()})
	if http.request(waitlist(), ["Content-Type: application/json"], HTTPClient.METHOD_POST, body) != OK:
		http.request_completed.emit(HTTPRequest.RESULT_CANT_CONNECT, 0, PackedStringArray(), PackedByteArray())


## Both forms at once: Join greyed while one is asking and for good once joined, and the fields with it.
func _lock(join_dead: bool, fields_live: bool) -> void:
	for join: Button in _joins:
		join.disabled = join_dead
	for email: LineEdit in _emails:
		email.editable = fields_live


func _say(note: Label, text: String) -> void:
	note.text = text
	note.show()
	_fit()


func _start() -> void:
	# The main scene picks `ui_scale` once, from the window it starts in, and the web page's canvas shrinks
	# to a 16:9 box while a phone's keyboard is up: started at once from the password, the game stayed at
	# scale 1, laid out as across a monitor. A window turned round meanwhile is waited out no longer.
	var waited := 0.0
	while _unkeyed != Vector2.ZERO and get_viewport_rect().size != _unkeyed and waited < KEYBOARD_GONE:
		await get_tree().process_frame
		waited += get_process_delta_time()
	# Waits out the rest of the load when the click comes before it is done.
	get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(GAME))
