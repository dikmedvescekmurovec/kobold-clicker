class_name CloudQuestion
extends Control
## The cloud's question over the whole window (`Cloud.question`): two saves that both moved on, side by
## side, to keep one of. No X and no Escape: one of its two buttons is the answer, and nothing under it
## can be pressed meanwhile, by the mouse or by a key. Built as the bag's question is (`BagPage._ask`):
## a holder under a titled panel, which `Juice.popup` pops in and stands over the whole window however
## it is resized or turned.

## `keep_cloud`: the cloud's save comes down over this device's; otherwise this device's goes up.
signal answered(keep_cloud: bool)

## A save's column, and so half the panel.
const COLUMN := 175.0
const GAP := 8
const MONTHS := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

var _question: Dictionary
var _ui_scale: float


func _init(question: Dictionary, ui_scale: float) -> void:
	_question = question
	_ui_scale = ui_scale
	theme = UITheme.theme()


func _ready() -> void:
	var panel := UITheme.titled_panel("Cloud save", "", Callable())
	add_child(panel)
	var body := UITheme.body_of(panel)
	# Held upright the two saves stand one over the other, and the words over them are one column wide.
	var narrow := UITheme.narrow(get_viewport_rect().size, _ui_scale)
	var asked := BountyList.wrapped("Keep which save?", COLUMN if narrow else 2 * COLUMN + GAP)
	body.add_child(asked)
	var sides := BoxContainer.new()
	sides.vertical = narrow
	sides.add_theme_constant_override("separation", GAP)
	sides.add_child(_side("This device", _question.get("local", {})))
	sides.add_child(_side("The cloud", _question.get("cloud", {})))
	body.add_child(sides)
	var buttons := BoxContainer.new()
	buttons.vertical = narrow
	buttons.add_theme_constant_override("separation", GAP)
	var mine := UITheme.button("Keep this device's", "LightButton",
			"This device's save goes to the cloud in the other's place")
	var theirs := UITheme.button("Keep the cloud's", "LightButton", "The cloud's save replaces this device's")
	for made: Button in [mine, theirs]:
		made.custom_minimum_size.x = COLUMN
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(made)
	mine.pressed.connect(answered.emit.bind(false))
	theirs.pressed.connect(answered.emit.bind(true))
	body.add_child(buttons)
	# Turned while it is up -- a phone in the hand -- it is arranged again for the window it is now in.
	resized.connect(func() -> void:
		var upright := UITheme.narrow(get_viewport_rect().size, _ui_scale)
		if upright != sides.vertical:
			asked.custom_minimum_size.x = COLUMN if upright else 2 * COLUMN + GAP
			sides.vertical = upright
			buttons.vertical = upright
			panel.reset_size())
	Juice.popup(self, panel, _ui_scale)


## Every key stops here, Escape and a phone's back among them: no hotkey opens a page under the
## question, and nothing closes one. In `_input`, before anything under it has the key, whatever
## stands where in the tree.
func _input(event: InputEvent) -> void:
	if event is InputEventKey or event.is_action("ui_cancel"):
		get_viewport().set_input_as_handled()


## One save as the question shows it: a heading and four rows.
func _side(title: String, summary: Variant) -> VBoxContainer:
	var column := UITheme.vbox(0, COLUMN)
	# Spread over whatever width the buttons under them left the panel.
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(UITheme.section(title))
	var known: Dictionary = summary if summary is Dictionary else {}
	if known.is_empty():
		column.add_child(UITheme.label("Unknown", Palette.TEXT_SOFT, true))
		return column
	var rows := [
		["Level", str(int(known.get("level", 0)))],
		["Played", played(int(known.get("play_seconds", 0)))],
		["Saved", when(int(known.get("saved_at", 0)))],
		["Deepest", Cloud.score_text(int(known.get("dungeon_floors", 0)))],
	]
	for at in rows.size():
		column.add_child(UITheme.table_row(rows[at][0], rows[at][1], at % 2 == 1, COLUMN))
	return column


static func played(seconds: int) -> String:
	return "%dh %dm" % [seconds / 3600, seconds % 3600 / 60] if seconds >= 3600 \
			else "%dm %ds" % [seconds / 60, seconds % 60]


## A save's hour on this computer's clock: "30 Sep 15:32".
static func when(unix: int) -> String:
	if unix <= 0:
		return "Never"
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var at := Time.get_datetime_dict_from_unix_time(unix + bias)
	return "%d %s %02d:%02d" % [at.day, MONTHS[at.month - 1], at.hour, at.minute]
