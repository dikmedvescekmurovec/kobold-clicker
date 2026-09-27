class_name LeaderboardPage
extends Control
## The Gollux leaderboard as a page against the left edge, opened from the cave's tile panel: a name
## to join under until the player has one, then their own best and place, and the top of the board.
##
## Built like the other left-hand pages (`SettingsPage`): `open()` redraws it and asks the server
## again, `layout()` fits it to the window, `closed` is its X. Everything it shows is `Leaderboard`'s,
## and it redraws whenever that says something changed.

## The page's X was pressed.
signal closed

const WIDTH := 180.0
const ROW_GAP := 6
## The player's own row on the board.
const ME_COLOUR := Palette.ICE_DK
const ABOUT := "Your deepest descent is sent each time you leave the cave. 3.14 is depth 3 with 14 of its floors beaten; of two alike, whoever got there first stands higher."

var _board: Leaderboard
## The best the save holds, in floors: shown at once, before the server has answered.
var _best: Callable
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
## What was typed into the name field, kept across the redraws a call makes.
var _typed := ""


func _init(board: Leaderboard, best: Callable, ui_scale: float) -> void:
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
	_board.changed.connect(func() -> void:
		if visible:
			_draw())
	_draw()


## Redraws it and reads the board again. Sends the save's best first, in case the last send failed.
func open() -> void:
	_draw()
	_board.submit(int(_best.call()))
	_board.refresh()


func _draw() -> void:
	UITheme.clear(_rows)
	if not _board.enabled():
		_rows.add_child(BountyList.wrapped("The leaderboard is not set up in this build.", WIDTH))
		return
	if not _board.joined():
		_draw_join()
	else:
		_draw_board()
	if not _board.problem.is_empty():
		_rows.add_child(BountyList.wrapped(_board.problem, WIDTH, Palette.BRICK))
	# Once, before joining: under a long board it would be scrolled past.
	if not _board.joined():
		_rows.add_child(BountyList.wrapped(ABOUT, WIDTH, Palette.TEXT_SOFT))


## A name and Join. The server says whether it will have it; the field only stops what it never would.
func _draw_join() -> void:
	_rows.add_child(BountyList.wrapped("Choose a name to put your descents on the board.", WIDTH))
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
	var join := UITheme.button("Join", UITheme.GO_BUTTON, "Put this name on the board")
	var ready_to_join := func() -> void:
		join.disabled = _board.busy() or _typed.strip_edges().length() < 3
	field.text_changed.connect(func(now: String) -> void:
		_typed = now
		ready_to_join.call())
	var send := func() -> void:
		if not join.disabled:
			await _board.join(_typed)
			if _board.joined():
				open()
	join.pressed.connect(send)
	field.text_submitted.connect(func(_text: String) -> void: send.call())
	ready_to_join.call()
	_rows.add_child(join)


## The player's own line, then the top of the board.
func _draw_board() -> void:
	var best := maxi(int(_best.call()), int(_board.me.get("floors", 0)))
	var rank: Variant = _board.me.get("rank")
	_rows.add_child(UITheme.section("You"))
	_rows.add_child(UITheme.table_row(_board.player_name + ("  #%d" % int(rank) if rank != null else ""),
			Leaderboard.score_text(best), false, WIDTH, ME_COLOUR, ME_COLOUR))
	_rows.add_child(UITheme.section("Deepest"))
	if _board.top.is_empty():
		_rows.add_child(UITheme.label("Asking the board..." if _board.busy()
				else "Nobody has beaten a floor yet.", Palette.TEXT_SOFT, true))
	for at in _board.top.size():
		var row: Dictionary = _board.top[at]
		var mine: bool = str(row.get("name")) == _board.player_name
		var line := UITheme.table_row("%d  %s" % [int(row.get("rank", at + 1)), row.get("name", "")],
				Leaderboard.score_text(int(row.get("floors", 0))), at % 2 == 1, WIDTH,
				ME_COLOUR if mine else null, ME_COLOUR if mine else null)
		line.tooltip_text = "Reached %s" % Time.get_datetime_string_from_unix_time(
				int(row.get("reached_at", 0)) / 1000, true)
		_rows.add_child(line)
	var again := UITheme.button("Refresh", "LightButton", "Read the board again")
	again.disabled = _board.busy()
	again.pressed.connect(_board.refresh)
	_rows.add_child(again)


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x,
			get_viewport_rect().size.y / _ui_scale - 2 * UITheme.EDGE)
	_panel.position = Vector2.ONE * UITheme.EDGE * _ui_scale
