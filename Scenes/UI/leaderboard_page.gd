class_name LeaderboardPage
extends Control
## The Gollux leaderboard as a page against the left edge, opened from the corner and the cave's tile
## panel: the player's own place -- or Sign in, or a name to choose, until they have one -- over the top
## of the board, which anyone may read. A score is what the player's cloud saves vouched for (the
## server's `saves.vouched`), so floors beaten before signing in are not on it.
##
## Built like the other left-hand pages (`SettingsPage`): `open()` redraws it, syncs and reads the board
## again, `layout()` fits it to the window, `closed` is its X. Everything it shows is the `Cloud`'s, and
## it redraws whenever that says something changed.

## The page's X was pressed.
signal closed

const WIDTH := 180.0
const ROW_GAP := 6
## The player's own row on the board.
const ME_COLOUR := Palette.ICE_DK
## The top three's trophies, cut by `tools/ui_kit.py`; every other place is its number in their column.
const TROPHIES: Array[String] = ["res://Assets/UI/ui_icon_trophy_gold.png",
		"res://Assets/UI/ui_icon_trophy_silver.png", "res://Assets/UI/ui_icon_trophy_bronze.png"]
const PLACE_WIDTH := 14
## The depth's column and the floor's, each wide enough for its heading.
const NUMBER_WIDTH := 28

var _board: Cloud
## The best the save holds, in floors: shown at once, before the server has answered.
var _best: Callable
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
var _refresh: Button
## What was typed into the name field, kept across the redraws a call makes.
var _typed := ""


func _init(board: Cloud, best: Callable, ui_scale: float) -> void:
	_board = board
	_best = best
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Leaderboard", "Close the leaderboard", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(ROW_GAP, WIDTH)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	# Pinned under the scroll, so a long board never pushes it out of reach.
	_refresh = UITheme.button("Refresh", "LightButton", "Read the board again")
	_refresh.pressed.connect(func() -> void: _board.refresh())
	UITheme.body_of(_panel).add_child(_refresh)
	_board.changed.connect(func() -> void:
		if visible:
			_draw())
	_draw()


## Redraws it and reads the board again, after sending the save if it has moved since the cloud last took it.
func open() -> void:
	_draw()
	_board.sync(true)
	_board.refresh()


func _draw() -> void:
	UITheme.clear(_rows)
	_refresh.visible = _board.enabled()
	_refresh.disabled = _board.busy()
	if not _board.enabled():
		_rows.add_child(BountyList.wrapped("The leaderboard is not set up in this build.", WIDTH))
		return
	_rows.add_child(UITheme.section("You"))
	if not _board.signing_check.is_empty():
		_rows.add_child(check_letters(_board.signing_check))
		var cancel := UITheme.button("Cancel", "LightButton", "Stop signing in")
		cancel.pressed.connect(_board.cancel_sign_in)
		_rows.add_child(cancel)
	elif not _board.signed_in():
		var sign_in := UITheme.button("Sign in", UITheme.GO_BUTTON,
				"Put your descents on the board: your save goes to the cloud, where it is checked. You sign in with Google or Discord, in your browser")
		sign_in.disabled = _board.busy()
		sign_in.pressed.connect(func() -> void: _board.sign_in())
		_rows.add_child(sign_in)
	elif _board.player_name.is_empty():
		_draw_join()
	else:
		_draw_me()
	_draw_board()
	if not _board.problem.is_empty():
		_rows.add_child(BountyList.wrapped(_board.problem, WIDTH, Palette.BRICK))


## A name and Choose. The server says whether it will have it; the field only stops what it never would.
func _draw_join() -> void:
	var field := LineEdit.new()
	field.max_length = 16
	field.placeholder_text = "Your name"
	field.text = _typed
	field.custom_minimum_size.x = WIDTH
	# The cream panel's own white box, so the field reads as something to write in.
	for state: String in ["normal", "focus", "read_only"]:
		field.add_theme_stylebox_override(state, UITheme.theme().get_stylebox("panel", "TextPanel"))
	field.add_theme_color_override("font_color", Palette.TEXT)
	field.add_theme_color_override("font_placeholder_color", Palette.TEXT_SOFT)
	field.add_theme_color_override("caret_color", Palette.TEXT)
	_rows.add_child(field)
	var join := UITheme.button("Choose name", UITheme.GO_BUTTON, "Put this name on the board")
	var ready_to_join := func() -> void:
		join.disabled = _board.busy() or _typed.strip_edges().length() < 3
	field.text_changed.connect(func(now: String) -> void:
		_typed = now
		ready_to_join.call())
	var send := func() -> void:
		if not join.disabled:
			await _board.choose_name(_typed)
			if not _board.player_name.is_empty():
				open()
	join.pressed.connect(send)
	field.text_submitted.connect(func(_text: String) -> void: send.call())
	ready_to_join.call()
	_rows.add_child(join)


## The player's own line: what the board counts for them, which is only the floors beaten under the
## server's checks and so can be less than the save's best.
func _draw_me() -> void:
	var rank: Variant = _board.me.get("rank")
	_table().add_child(_place_row(int(rank) if rank != null else 0, _board.player_name,
			int(_board.me.get("floors", 0)), false, true))


## The top of the board, a framed table.
func _draw_board() -> void:
	_rows.add_child(UITheme.section("Deepest"))
	if _board.top.is_empty():
		_rows.add_child(UITheme.label("Asking the board..." if _board.busy()
				else "Nobody has beaten a floor yet.", Palette.TEXT_SOFT, true))
		return
	var table := _table()
	table.add_child(_heads())
	for at in _board.top.size():
		var row: Dictionary = _board.top[at]
		var line := _place_row(int(row.get("rank", at + 1)), str(row.get("name", "")),
				int(row.get("floors", 0)), at % 2 == 1, str(row.get("name")) == _board.player_name)
		line.tooltip_text = "Reached %s" % Time.get_datetime_string_from_unix_time(
				int(row.get("reached_at", 0)) / 1000, true)
		table.add_child(line)


## A framed block with no gap, as the character page's stats: the page's row gap would part the stripes.
func _table() -> VBoxContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", BountyList.flat(Color.TRANSPARENT, 1))
	var body := UITheme.vbox(0)
	frame.add_child(body)
	_rows.add_child(frame)
	return body


## One line of the board: the place in a column before the name -- a trophy for the top three, else the
## number (nothing while the server has not placed the player) -- then the depth and the floor of it in
## two columns of their own. One figure, "3.14", read as a decimal: is 3.9 more or less?
func _place_row(place: int, player: String, floors: int, striped: bool, mine: bool) -> PanelContainer:
	var colour: Variant = ME_COLOUR if mine else null
	var cell: Control
	if place >= 1 and place <= TROPHIES.size():
		var trophy := TextureRect.new()
		trophy.texture = load(TROPHIES[place - 1])
		trophy.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		cell = trophy
	else:
		var number := UITheme.label(str(place) if place > 0 else "", colour, true)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell = number
	var at := Cloud.depth_and_floor(floors)
	return _columns(cell, player, str(at.x), str(at.y), striped, colour)


## The board's column heads, over its first line.
func _heads() -> PanelContainer:
	return _columns(Control.new(), "", "Depth", "Floor", false, Palette.TEXT_SOFT)


## `UITheme.table_row` laid out as the board's columns: `place` first, the name taking what is left, and
## `depth` and `level` right-aligned at `NUMBER_WIDTH` each, so they stand in columns down the board.
func _columns(place: Control, player: String, depth: String, level: String, striped: bool,
		colour: Variant) -> PanelContainer:
	var row := UITheme.table_row(player, depth, striped, WIDTH - 2, colour, colour)
	var cells := row.get_child(0)
	place.custom_minimum_size.x = PLACE_WIDTH
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cells.add_child(place)
	cells.move_child(place, 0)
	var floor_cell := UITheme.label(level, colour, true)
	floor_cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cells.add_child(floor_cell)
	for number: Label in [cells.get_node(UITheme.TABLE_VALUE) as Label, floor_cell]:
		number.custom_minimum_size.x = NUMBER_WIDTH
	# The name wraps in what the three columns leave it.
	(cells.get_child(1) as Label).custom_minimum_size.x = maxf(WIDTH - 2 - 2 * UITheme.TABLE_PAD.x
			- PLACE_WIDTH - 2 * NUMBER_WIDTH - 3 * UITheme.TABLE_GAP, 0.0)
	return row


## The four letters a sign-in under way shows, big and centred: the sign-in page in the browser shows
## them too, and says to stop if they differ. What they are for is in the tooltip.
static func check_letters(check: String) -> Label:
	var letters := UITheme.label(check)
	letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letters.mouse_filter = Control.MOUSE_FILTER_PASS
	letters.tooltip_text = "Signing in, in your browser. It shows these letters too: if they differ, close it"
	return letters


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale)
