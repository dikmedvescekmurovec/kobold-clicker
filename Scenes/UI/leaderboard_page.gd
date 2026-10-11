class_name LeaderboardPage
extends Control
## The leaderboards on the left edge: a tab a board (`BOARDS`), and under it the player's own place --
## or Sign in, or a name to choose, until they have one -- over the top of that board, which anyone may
## read. Everything it shows is the `Cloud`'s, and it redraws whenever that says something changed.

signal closed

const WIDTH := 180.0
const ROW_GAP := 6
## The player's own row on the board.
const ME_COLOUR := Palette.ICE_DK
## The top three's trophies, cut by `tools/ui_kit.py`; every other place is its number in their column.
const TROPHIES: Array[String] = ["res://Assets/UI/ui_icon_trophy_gold.png",
		"res://Assets/UI/ui_icon_trophy_silver.png", "res://Assets/UI/ui_icon_trophy_bronze.png"]
const PLACE_WIDTH := 14
## A score's columns (Gollux's depth and floor), each wide enough for its heading.
const NUMBER_WIDTH := 28
## Each of `Cloud.BOARDS`: its tab, the tab's tooltip, and its columns' heads.
const BOARDS := {
	"gollux": ["Gollux", "Deepest descent", ["Depth", "Floor"]],
	"walls": ["Walls", "Ice walls broken, in every world", ["Walls"]],
	"deepest": ["Deepest", "Deepest tile charted, in any world", ["Level"]],
}
## A tab's width: three and their gaps stand in `WIDTH` with room to spare.
const TAB_WIDTH := 50

var area := Rect2()
var _board: Cloud
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
var _refresh: Button
## The name field and the button under it. **The field outlives every redraw while a name is asked for**
## (`_naming`): the cloud says `changed` at every call it makes -- its tick, a burst after a sign-in --
## and a field built again mid-word would drop the cursor, the next letters landing on the corner's
## hotkeys and closing the page.
var _field: LineEdit
var _join: Button
## The board whose tab is open.
var _open: String = Cloud.BOARDS[0]


## `_best` is no longer read: the page draws only what the `Cloud` holds.
func _init(board: Cloud, _best: Callable, ui_scale: float) -> void:
	_board = board
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
	_refresh.pressed.connect(func() -> void: _board.refresh(_open))
	UITheme.body_of(_panel).add_child(_refresh)
	_board.changed.connect(func() -> void:
		if visible:
			_draw())
	_draw()


## Redraws it and reads the board again, once the save has been sent if it has moved since the cloud
## last took it: a board read before the upload lands is a board without the descent just made.
func open() -> void:
	_draw()
	await _board.sync(true)
	_board.refresh(_open)


## Whether the page is asking for a board name: signed in, with none yet.
func _naming() -> bool:
	return _board.enabled() and _board.signing_check.is_empty() and _board.signed_in() \
			and _board.player_name.is_empty()


func _draw() -> void:
	# Everything but the name field, which is put back where it stood (`_draw_join`).
	if not _naming():
		_field = null
	UITheme.clear(_rows, _field)
	_refresh.visible = _board.enabled()
	_refresh.disabled = _board.busy()
	if not _board.enabled():
		_rows.add_child(BountyList.wrapped("The leaderboard is not set up in this build.", WIDTH))
		return
	_rows.add_child(_tabs())
	_rows.add_child(UITheme.section("You"))
	if not _board.signing_check.is_empty():
		_rows.add_child(check_letters(_board.signing_check))
		var cancel := UITheme.button("Cancel", "LightButton", "Stop signing in")
		cancel.pressed.connect(_board.cancel_sign_in)
		_rows.add_child(cancel)
	elif not _board.signed_in():
		var sign_in := UITheme.button("Sign in", UITheme.GO_BUTTON, "Put your descents on the board: your save"
				+ " goes to the cloud. You sign in with Google or Discord, in your browser")
		sign_in.disabled = _board.busy()
		sign_in.pressed.connect(func() -> void: _board.sign_in())
		_rows.add_child(sign_in)
	elif _naming():
		_draw_join()
	else:
		_draw_me()
	_draw_board()
	if not _board.problem.is_empty():
		_rows.add_child(BountyList.wrapped(_board.problem, WIDTH, Palette.BRICK))


## A name and Choose. The server says whether it will have it; the field only stops what it never would.
## The field is made once and moved back under "You" by every redraw after; the button is made again.
func _draw_join() -> void:
	if _field == null:
		_field = UITheme.text_field("Your name", 16, WIDTH)
		_field.text_changed.connect(func(_now: String) -> void: _ready_to_join())
		_field.text_submitted.connect(func(_text: String) -> void: _send_name())
		_rows.add_child(_field)
	else:
		_rows.move_child(_field, -1)
	_join = UITheme.button("Choose name", UITheme.GO_BUTTON, "Put this name on the board")
	_join.pressed.connect(_send_name)
	_ready_to_join()
	_rows.add_child(_join)


func _ready_to_join() -> void:
	_join.disabled = _board.busy() or _field.text.strip_edges().length() < 3


func _send_name() -> void:
	if _join.disabled:
		return
	await _board.choose_name(_field.text)
	if not _board.player_name.is_empty():
		open()


## The boards' folder tabs, the bag's filter tabs in words. Opening one reads that board again.
func _tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	for key: String in Cloud.BOARDS:
		if row.get_child_count() > 0:
			row.add_child(TownPage.tab_line(TownPage.TAB_GAP))
		var tab := UITheme.button(BOARDS[key][0], UITheme.BARE_BUTTON, BOARDS[key][1])
		tab.add_theme_font_override("font", theme.get_font("font", "SmallLabel"))
		tab.add_theme_font_size_override("font_size", UITheme.SMALL_FONT_SIZE)
		for state: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color",
				"font_hover_pressed_color"]:
			tab.add_theme_color_override(state, Palette.TEXT if key == _open else Palette.TEXT_SOFT)
		TownPage.tab_faces(tab, key == _open, TAB_WIDTH)
		tab.pressed.connect(func() -> void:
			_open = key
			_draw()
			_board.refresh(key))
		row.add_child(tab)
	var rest := TownPage.tab_line(0)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rest)
	return row


## The open board as last read: `{top, me}` (`Cloud.boards`), empty until read.
func _read() -> Dictionary:
	return _board.boards.get(_open, {})


func _draw_me() -> void:
	var mine: Dictionary = _read().get("me", {})
	var rank: Variant = mine.get("rank")
	_table().add_child(_place_row(int(rank) if rank != null else 0, _board.player_name,
			int(mine.get("score", 0)), false, true))


func _draw_board() -> void:
	_rows.add_child(UITheme.section("Top"))
	var top: Array = _read().get("top", [])
	if top.is_empty():
		_rows.add_child(UITheme.label("Asking the board..." if _board.busy()
				else "Nobody is on this board yet.", Palette.TEXT_SOFT, true))
		return
	var table := _table()
	table.add_child(_heads())
	for at in top.size():
		var row: Dictionary = top[at]
		var line := _place_row(int(row.get("rank", at + 1)), str(row.get("name", "")),
				int(row.get("score", 0)), at % 2 == 1, str(row.get("name")) == _board.player_name)
		line.tooltip_text = "Reached %s" % Time.get_datetime_string_from_unix_time(
				int(row.get("reached_at", 0)) / 1000, true)
		table.add_child(line)


## A framed table added to the page; returns the column its lines go in.
func _table() -> VBoxContainer:
	var body := BountyList.framed()
	_rows.add_child(body.get_parent())
	return body


## One line of the board: the place in a column before the name -- a trophy for the top three, else the
## number (nothing while the server has not placed the player) -- then the score in the open board's
## columns. Gollux's is the depth and the floor of it in two: one figure, "3.14", read as a decimal: is
## 3.9 more or less?
func _place_row(place: int, player: String, score: int, striped: bool, mine: bool) -> PanelContainer:
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
	if _open != "gollux":
		return _columns(cell, player, [str(score)], striped, colour)
	var at := Cloud.depth_and_floor(score)
	return _columns(cell, player, [str(at.x), str(at.y)], striped, colour)


## The open board's column heads, over its first line.
func _heads() -> PanelContainer:
	return _columns(Control.new(), "", BOARDS[_open][2], false, Palette.TEXT_SOFT)


## `UITheme.table_row` laid out as the board's columns: `place` first, the name taking what is left, and
## each of `numbers` right-aligned at `NUMBER_WIDTH`, so they stand in columns down the board.
func _columns(place: Control, player: String, numbers: Array, striped: bool,
		colour: Variant) -> PanelContainer:
	var row := UITheme.table_row(player, numbers[0], striped, WIDTH - 2, colour, colour)
	var cells := row.get_child(0)
	place.custom_minimum_size.x = PLACE_WIDTH
	place.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cells.add_child(place)
	cells.move_child(place, 0)
	var columns: Array[Label] = [cells.get_node(UITheme.TABLE_VALUE) as Label]
	for more: String in numbers.slice(1):
		var extra := UITheme.label(more, colour, true)
		extra.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cells.add_child(extra)
		columns.append(extra)
	for number: Label in columns:
		number.custom_minimum_size.x = NUMBER_WIDTH
	# The name wraps in what the columns leave it.
	(cells.get_child(1) as Label).custom_minimum_size.x = maxf(WIDTH - 2 - 2 * UITheme.TABLE_PAD.x
			- PLACE_WIDTH - numbers.size() * NUMBER_WIDTH - (numbers.size() + 1) * UITheme.TABLE_GAP, 0.0)
	return row


## The four letters a sign-in under way shows, big and centred: the sign-in page in the browser shows
## them too, and says to stop if they differ. What they are for is in the tooltip.
static func check_letters(check: String) -> Label:
	var letters := UITheme.label(check)
	letters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	letters.mouse_filter = Control.MOUSE_FILTER_PASS
	letters.tooltip_text = "Signing in, in your browser. It shows these letters too: if they differ, close it"
	return letters


func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)
