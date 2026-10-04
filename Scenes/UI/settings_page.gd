class_name SettingsPage
extends Control
## What the player has chosen about the game, as a page against the left edge, in small sections:
## Sound (two volumes), Display (full screen on a desktop, screen shake, the animation level), Items
## (detailed descriptions, what a whole level's Sell all and bin do with a unique), the cloud save --
## and, at its foot, Controls, Credits, a debug build's Developer, and the way to start over.
##
## Controls, Credits and Developer each stand in the settings' place under a title of their own, with
## the back arrow at their foot (`_screen`); Developer holds every dev tool there is, and the balancing
## page and the item generator open from it and come back to it.
##
## Built like the other left-hand pages (`BountyList`): `open()` redraws it, `layout()` fits it to the
## window, `closed` is its X, and it carries `UITheme.theme()` because it hangs off a `CanvasLayer`.
## Every change goes straight into `Settings` and its file; the saves are nothing to do with it, which
## is why Reset is a signal -- deleting them and reloading is the main scene's.

## The page's X was pressed.
signal closed
## Delete was pressed under the question Reset asks.
signal reset_pressed
## The debug build's Gold x10 was pressed.
signal cash_pressed
## The debug build's Skill points +10 was pressed.
signal points_pressed
## The debug build's "Show all uniques" was ticked or unticked: the trophy may have come or gone.
signal uniques_toggled
## Dev: the "show all chests" box moved; the main scene redraws the map's chests.
signal chests_toggled
## The panel changed size: the corner buttons beside it move.
signal laid_out

## The other left-hand pages' width, so going from one to the next does not jump.
const WIDTH := float(BagPage.WIDTH)
const ROW_GAP := 6
const TITLE := "Settings"
const DEV_TITLE := "Developer"
const CREDITS_TITLE := "Credits"
const CONTROLS_TITLE := "Controls"
const ANIM_NAMES := ["None", "Low", "Full"]
## `Settings.Uniques` in order: what a heading's Sell all and bin do with a unique among the handful.
const UNIQUES_NAMES := ["Ask", "Sell", "Keep"]
const UNIQUES_TIPS := ["A unique among the handful is asked about on its own",
		"A unique among the handful is sold or discarded with the rest",
		"A unique among the handful is left in the bag"]
const UNIQUES_LABEL := "Uniques when a whole level is sold or discarded"
const DETAILS_TIP := "Shows beside each modifier the lowest and highest it could have rolled at the item's level, like +14(8-20)% increased Damage"
## A volume row: the name's room, the percentage's, and the knob the slider is dragged by, drawn here
## pixel by pixel in the brown buttons' face (`_knob`), lit tan under the mouse.
const VOLUME_NAME := 44.0
const VOLUME_SHOWN := 26.0
const KNOB := Vector2i(6, 10)
const TRACK := 2
## What the effects' slider plays as it is let go, so the new level is heard.
const SAMPLE := preload("res://Sounds/UI/click1.ogg")
## The balancing page's rows, one a `Settings.wall_hp` entry, and the buttons either side of the
## number: [face, what it does to the number].
const WALL_HP_NAMES := ["Inside wall 1", "Wall 1 to wall 2", "Wall 2 to wall 3"]
const HP_NUDGES := [["/10", "Divide by 10"], ["-1", "Take 1 away"], ["+1", "Add 1"], ["x10", "Multiply by 10"]]
const HP_BASE_TIP := "The health of an ordinary body on this circle's first ring. Every body in the circle scales with it"
## The credits' link mark, a bare button after a name that has a link.
const LINK_ICON := preload("res://Assets/UI/ui_icon_linkedin.png")
## The credits whose work was made by AI, each followed by a small "AI" chip (`_ai_badge`).
const AI_MADE := ["PixelLab"]
## The controls screen's mouse keys, after the corner buttons' letters (`hotkeys`): the item card's own
## key pictures (`ItemCard.KEY_ICONS`) and what each does on a square.
const MOUSE_KEYS := [["shift", "Click to equip or unequip"], ["ctrl", "Click to sell or discard"],
		["alt", "Hold to compare"]]
## Whose work the game is built on, as `credits.md` has it in full -- `test_ui_theme` holds every name
## there to a line here, so the two cannot drift. [section, [[name, what, link], ...]]; a link is optional
## and puts `LINK_ICON` after the name.
const CREDITS := [
	["Development", [
		["Dik Medvešček Murovec", "Lead everything", "https://www.linkedin.com/in/dik-medvescek-murovec"],
	]],
	["Art", [
		["Mattz Art", "The hero, the portraits and the enemies"],
		["Admurin", "The dungeon's creatures, Gollux, the cave and the chest"],
		["rvros", "The slime"],
		["PixelLab", "Made the item, unique, skill and spell icons"],
	]],
	["Interface", [
		["CraftPix.net", "Panels and buttons"],
		["Cainos", "Gear icons and marks"],
		["Kelano Studio", "The orbs"],
		["Dream Mix", "The keyboard keys"],
		["TotusLotus", "The coin"],
		["Kenney", "The cursors"],
	]],
	["Fonts", [
		["Pixellari", "By Zacchary Dempsey-Plante"],
		["Ark Pixel Font", "By TakWolf, under the SIL Open Font License 1.1"],
	]],
	["Sound", [
		["Kenney", "Impact, interface, UI and RPG sounds, and the jingles"],
	]],
	["Music", [
		["alkakrab", "The ambient and action music"],
	]],
]

## The debug build's item generator works on these; the main scene sets them, as it sets a town
## page's `view`. Without them there is no button for it.
var inventory: Inventory
var inventory_path := ""
## The account and cloud save, set by the main scene; its section is left out while it is off.
var cloud: Cloud
## The controls screen's letters, [key, the page it opens], set by the main scene off its corner buttons.
var hotkeys: Array = []

var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer
## The cloud's section, redrawn alone whenever the cloud says something changed.
var _account: VBoxContainer
## When the cloud last took the save ("3 min ago"), kept current while the page is up.
var _synced: Label
## Delete cloud account was pressed and asks its question in place.
var _deleting := false
## The slider's knob, plain and lit, made once.
static var _knobs := {}


func _init(ui_scale: float) -> void:
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel(TITLE, "Close the settings", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	# Scrolled: the credits run past a 648 px window's foot, and so does all of it held upright.
	# `_rows` is at least as tall as the scroll, so the foot still sinks to the bottom when there is room.
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(ROW_GAP, WIDTH)
	_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	if cloud != null:
		cloud.changed.connect(func() -> void:
			if visible and is_instance_valid(_account):
				_draw_account())
	open()


## Redraws the page from `Settings`, with Reset back to a button: a question left hanging is cancelled
## by closing the page, whichever way it was closed, and so is a screen opened from it.
func open() -> void:
	UITheme.title_of(_panel).text = TITLE
	UITheme.clear(_rows)
	_rows.add_child(UITheme.section("Sound"))
	_rows.add_child(_volume("Music", "music_volume", Settings.music_volume,
			func(now: float) -> void: Settings.music_volume = now))
	_rows.add_child(_volume("Effects", "sfx_volume", Settings.sfx_volume,
			func(now: float) -> void: Settings.sfx_volume = now))
	_rows.add_child(UITheme.section("Display"))
	if Settings.has_window():
		_rows.add_child(_tick("Fullscreen", Settings.fullscreen, func(on: bool) -> void:
			Settings.fullscreen = on
			Settings.apply_window()))
	_rows.add_child(_tick("Screen shake", Settings.shake, func(on: bool) -> void: Settings.shake = on))
	_rows.add_child(UITheme.label("Animations", null, true))
	_rows.add_child(_choice(ANIM_NAMES, [], Settings.animations,
			func(level: int) -> void: Settings.animations = level as Settings.Anim))
	_rows.add_child(UITheme.section("Items"))
	var details := _tick("Detailed item descriptions", Settings.item_details,
			func(on: bool) -> void: Settings.item_details = on)
	# On the box and the words both: either is what the cursor may be resting on.
	for part: Control in details.get_children():
		part.tooltip_text = DETAILS_TIP
	_rows.add_child(details)
	_rows.add_child(BountyList.wrapped(UNIQUES_LABEL, WIDTH))
	_rows.add_child(_choice(UNIQUES_NAMES, UNIQUES_TIPS, Settings.uniques,
			func(rule: int) -> void: Settings.uniques = rule as Settings.Uniques))
	if cloud != null and cloud.enabled():
		_deleting = false
		_account = UITheme.vbox(ROW_GAP, WIDTH)
		_rows.add_child(_account)
		_draw_account()
	_rows.add_child(_foot(false))
	layout.call_deferred()


func _process(_delta: float) -> void:
	if _synced != null and is_instance_valid(_synced) and visible:
		_synced.text = cloud.status_text()


## Cloud save: Sign in, the letters a sign-in under way shows, or the account -- what it was signed in
## with, when the save last reached the cloud, Sign out, and Delete cloud account asking in place.
func _draw_account() -> void:
	UITheme.clear(_account)
	_synced = null
	_account.add_child(UITheme.section("Cloud save"))
	if not cloud.signing_check.is_empty():
		_account.add_child(LeaderboardPage.check_letters(cloud.signing_check))
		_account.add_child(_button("Cancel", "LightButton", "Stop signing in", cloud.cancel_sign_in))
	elif not cloud.signed_in():
		var sign_in := _button("Sign in", UITheme.GO_BUTTON,
				"Keep your save in the cloud and play it on any device. You sign in with Google or Discord, in your browser",
				cloud.sign_in)
		sign_in.disabled = cloud.busy()
		_account.add_child(sign_in)
	elif _deleting:
		_account.add_child(BountyList.wrapped("Delete your cloud account?", WIDTH, Palette.RUST))
		var buttons := HBoxContainer.new()
		buttons.add_theme_constant_override("separation", 2)
		for made: Button in [_button("Cancel", "LightButton", "", func() -> void:
					_deleting = false
					_draw_account()),
				_button("Delete", "LightDangerButton", "", cloud.delete_account)]:
			made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			buttons.add_child(made)
		_account.add_child(buttons)
	else:
		_account.add_child(UITheme.label("Signed in with %s" % cloud.provider.capitalize(), null, true))
		_synced = UITheme.label(cloud.status_text(), Palette.TEXT_SOFT, true)
		_account.add_child(_synced)
		_account.add_child(_button("Sign out", "LightButton", "This device stops saving to the cloud and keeps its save",
				cloud.sign_out))
		_account.add_child(_button("Delete cloud account", "LightDangerButton",
				"Delete your cloud save, your board name and your place on the board. This device keeps its save",
				func() -> void:
					_deleting = true
					_draw_account()))
	if not cloud.problem.is_empty():
		_account.add_child(BountyList.wrapped(cloud.problem, WIDTH, Palette.BRICK))


func _button(text: String, variation: String, tooltip: String, deed: Callable) -> Button:
	var made := UITheme.button(text, variation, tooltip)
	made.pressed.connect(func() -> void: deed.call())
	return made


## A volume: its name, a slider in `Settings.VOLUME_STEP`s from silent to full (named `key`, for the
## tests), and the percentage. Every step is heard at once and written; the wheel scrolls the page, not
## the slider. The effects' plays `SAMPLE` as it is let go.
func _volume(text: String, key: String, value: float, write: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var name_cell := UITheme.label(text, null, true)
	name_cell.custom_minimum_size.x = VOLUME_NAME
	row.add_child(name_cell)
	var slider := HSlider.new()
	slider.name = key
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = Settings.VOLUME_STEP
	slider.value = value
	slider.scrollable = false
	slider.focus_mode = Control.FOCUS_NONE
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var trough := _bar(Palette.INK)
	slider.add_theme_stylebox_override("slider", trough)
	slider.add_theme_stylebox_override("grabber_area", _bar(Palette.LEAF_LT))
	slider.add_theme_stylebox_override("grabber_area_highlight", _bar(Palette.LEAF_LT))
	slider.add_theme_icon_override("grabber", _knob(false))
	slider.add_theme_icon_override("grabber_highlight", _knob(true))
	Cursors.wear(slider, Cursors.HAND)
	row.add_child(slider)
	var shown := UITheme.label(_percent(value), Palette.TEXT_SOFT, true)
	shown.custom_minimum_size.x = VOLUME_SHOWN
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(shown)
	# Connected after the value is set, so drawing the page does not write the file.
	slider.value_changed.connect(func(now: float) -> void:
		write.call(now)
		shown.text = _percent(now)
		Settings.apply_audio()
		Settings.save())
	if key == "sfx_volume":
		slider.drag_ended.connect(func(_changed: bool) -> void: Juice.sound(SAMPLE))
	return row


static func _percent(volume: float) -> String:
	return "%d%%" % roundi(volume * 100.0)


## The slider's track or its filled part: a flat bar `TRACK` above and below its middle.
static func _bar(color: Color) -> StyleBoxFlat:
	var bar := StyleBoxFlat.new()
	bar.bg_color = color
	bar.content_margin_top = TRACK
	bar.content_margin_bottom = TRACK
	return bar


## The knob: the brown buttons' face (tan while lit) inside an ink edge, `KNOB` across, made once.
static func _knob(lit: bool) -> ImageTexture:
	if not _knobs.has(lit):
		var image := Image.create_empty(KNOB.x, KNOB.y, false, Image.FORMAT_RGBA8)
		image.fill(Palette.INK)
		image.fill_rect(Rect2i(Vector2i.ONE, KNOB - Vector2i(2, 2)), Palette.SLOT_TAN if lit else Palette.BUTTON_BROWN)
		_knobs[lit] = ImageTexture.create_from_image(image)
	return _knobs[lit]


## A row of buttons one of which is `picked`, which wears the green face (the pack's held face is one
## pixel, too little to read a choice off). `write` puts the pressed one into `Settings`; `tips`, where
## there are any, go on the buttons in order. The small faces: a choice is not the page's heading.
func _choice(names: Array, tips: Array, picked: int, write: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	# The picked one green, as an open town tab is; the rest a plain live face. Faded, they read as
	# dead buttons rather than as choices not taken.
	for at in names.size():
		var pick := UITheme.button(names[at], "SmallGoButton" if at == picked else "SmallButton",
				tips[at] if at < tips.size() else "")
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(func() -> void:
			write.call(at)
			Settings.save()
			open.call_deferred())
		row.add_child(pick)
	return row


## One tick-box row, the bag's own, already showing `on`. `write` puts a change into `Settings`, which
## is then written.
func _tick(text: String, on: bool, write: Callable) -> HBoxContainer:
	var row := BagPage.check_box(text)
	var box: Button = row.get_node(BagPage.TICK_NAME)
	# Before the handler is connected, so drawing the page does not write the file.
	box.button_pressed = on
	box.toggled.connect(func(now: bool) -> void:
		write.call(now)
		Settings.save())
	return row


## The page's foot: Controls and Credits side by side (no Controls where there is no keyboard), a debug
## build's Developer, and Reset -- or the question Reset asks once pressed, asked in place rather than
## over the window: there is nothing else on the page to press by mistake.
func _foot(asking: bool) -> VBoxContainer:
	var foot := UITheme.vbox(ROW_GAP, WIDTH)
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	if not asking:
		# One row of the small faces, and Reset small too: the settings fit a 648 px window to the foot.
		var pages := HBoxContainer.new()
		pages.add_theme_constant_override("separation", 2)
		if not OS.has_feature("mobile"):
			pages.add_child(_button(CONTROLS_TITLE, "SmallButton", "", _open_controls))
		pages.add_child(_button(CREDITS_TITLE, "SmallButton", "", _open_credits))
		if OS.is_debug_build():
			pages.add_child(_button(DEV_TITLE, "SmallButton", "Dev: the tools a release build has none of", _open_dev))
		for made: Control in pages.get_children():
			made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		foot.add_child(pages)
		foot.add_child(_button("Reset save", "SmallDangerButton", "Delete the saves and start a new game",
				_ask.bind(true)))
		return foot
	foot.add_child(BountyList.wrapped("Delete everything, here and in the cloud, and start over?"
			if cloud != null and cloud.signed_in() else "Delete everything and start over?", WIDTH, Palette.RUST))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 2)
	var cancel := UITheme.button("Cancel", "LightButton", "")
	cancel.pressed.connect(_ask.bind(false))
	var delete := UITheme.button("Delete", "LightDangerButton", "")
	delete.pressed.connect(reset_pressed.emit)
	for made: Button in [cancel, delete]:
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(made)
	foot.add_child(buttons)
	return foot


func _ask(asking: bool) -> void:
	var old := _rows.get_child(-1)
	_rows.remove_child(old)
	old.queue_free()
	_rows.add_child(_foot(asking))


## A screen in the settings' place: `title` on the bar, the back arrow to `back` pinned at the foot;
## returns the column to fill.
func _screen(title: String, back: Callable, back_tip: String) -> VBoxContainer:
	UITheme.clear(_rows)
	UITheme.title_of(_panel).text = title
	var body := UITheme.vbox(ROW_GAP, WIDTH)
	_rows.add_child(body)
	var foot := HBoxContainer.new()
	foot.size_flags_vertical = Control.SIZE_EXPAND | Control.SIZE_SHRINK_END
	var arrow := UITheme.back_button(back_tip)
	arrow.pressed.connect(back)
	foot.add_child(arrow)
	_rows.add_child(foot)
	layout.call_deferred()
	return body


## Each corner button's key beside the page it opens, then the keys a square answers to.
func _open_controls() -> void:
	var body := _screen(CONTROLS_TITLE, open, "Back to the settings")
	if not hotkeys.is_empty():
		body.add_child(UITheme.section("Pages"))
		for pair: Array in hotkeys:
			body.add_child(_key_row(TipCard.KEY_PICTURE % pair[0], str(pair[1])))
	body.add_child(UITheme.section("Items"))
	for pair: Array in MOUSE_KEYS:
		body.add_child(_key_row(ItemCard.KEY_ICONS[pair[0]], str(pair[1])))


## One key: its picture at its own size, and what it does.
static func _key_row(picture: String, what: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	var key := TextureRect.new()
	key.texture = load(picture)
	key.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	key.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(key)
	var label := UITheme.label(what, null, true)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(label)
	return row


## `CREDITS`, a section each, every name over what it gave, a linked name with its mark after it.
func _open_credits() -> void:
	var body := _screen(CREDITS_TITLE, open, "Back to the settings")
	for part: Array in CREDITS:
		body.add_child(UITheme.section(part[0]))
		for entry: Array in part[1]:
			var block := UITheme.vbox(0)
			var name_row := HBoxContainer.new()
			name_row.add_child(UITheme.label(entry[0], null, true))
			if entry.size() > 2:
				var link := UITheme.button("", UITheme.BARE_BUTTON, "LinkedIn")
				link.icon = LINK_ICON
				link.focus_mode = Control.FOCUS_NONE
				link.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				link.pressed.connect(OS.shell_open.bind(entry[2]))
				name_row.add_child(link)
			if entry[0] in AI_MADE:
				name_row.add_child(_ai_badge())
			block.add_child(name_row)
			block.add_child(BountyList.wrapped(entry[1], WIDTH, Palette.TEXT_SOFT))
			body.add_child(block)


## "AI" in bone on a chip in the rule's brown, cut as the character page's attribute chips are.
static func _ai_badge() -> PanelContainer:
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.SLOT_TAN_DK
	box.set_corner_radius_all(CharacterPage.CHIP_CORNER)
	box.anti_aliasing = false
	box.content_margin_left = CharacterPage.CHIP_PAD.x
	box.content_margin_right = CharacterPage.CHIP_PAD.x
	box.content_margin_top = CharacterPage.CHIP_PAD.y
	box.content_margin_bottom = CharacterPage.CHIP_PAD.y
	chip.add_theme_stylebox_override("panel", box)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.add_child(UITheme.label("AI", Palette.BONE, true))
	return chip


## Every dev tool, which a release build has none of: the five switches, the two cheats, the balancing
## page and the item generator, which both come back here.
func _open_dev() -> void:
	var body := _screen(DEV_TITLE, open, "Back to the settings")
	body.add_child(_dev_tick("Show all uniques", Settings.all_uniques,
			"The collection log draws every unique as found", func(on: bool) -> void:
				Settings.all_uniques = on
				uniques_toggled.emit()))
	body.add_child(_dev_tick("Show all chests", Settings.all_chests,
			"Every chest is drawn on the map, fog or not", func(on: bool) -> void:
				Settings.all_chests = on
				chests_toggled.emit()))
	body.add_child(_dev_tick("Show old icons", Settings.old_icons,
			"An item whose icon was replaced wears its old one, from the next time it is drawn",
			func(on: bool) -> void: Settings.old_icons = on))
	body.add_child(_dev_tick("Show all services", Settings.all_services,
			"Every settlement offers every counter, from the next time one is entered", func(on: bool) -> void:
				Settings.all_services = on
				TownServices.show_all = Settings.show_all_services()))
	body.add_child(_dev_tick("Even loot", Settings.even_loot,
			"A body drops loot one time in three, every rarity from common to unique as likely, from the next fight",
			func(on: bool) -> void: Settings.even_loot = on))
	body.add_child(_button("Gold x10", "LightButton", "Multiply the purse by ten", cash_pressed.emit))
	body.add_child(_button("Skill points +10", "LightButton", "Ten levels, and the ten skill points they earn",
			points_pressed.emit))
	body.add_child(_button("Balancing", "LightButton", "Scale enemy health wall by wall", _open_balance))
	if inventory != null:
		body.add_child(_button("Item generator", "LightButton", "Make an item to order", _open_generator))


## A dev switch: a tick row with what it does on the box and the words both.
func _dev_tick(text: String, on: bool, tip: String, write: Callable) -> HBoxContainer:
	var row := _tick(text, on, write)
	for part: Control in row.get_children():
		part.tooltip_text = tip
	return row


## The generator in the settings' place; its back arrow is the developer screen.
func _open_generator() -> void:
	UITheme.clear(_rows)
	_rows.add_child(ItemGenerator.new(inventory, inventory_path, _open_dev))
	layout.call_deferred()


## Dev: enemy health scaled by how many walls stand inside the tile (`Settings.wall_hp`), a row a
## circle of land: its base health (`Encounter.baseline_hp` until changed) between /10 -1 and +1 x10,
## never under 1. Takes hold from the next fight.
func _open_balance() -> void:
	var body := _screen(DEV_TITLE, _open_dev, "Back to the developer tools")
	body.add_child(UITheme.label("Enemy health"))
	for walls in Settings.wall_hp.size():
		body.add_child(UITheme.rule(WIDTH))
		body.add_child(UITheme.label(WALL_HP_NAMES[walls], null, true))
		var now := Settings.hp_base(walls)
		if now <= 0.0:
			now = Encounter.baseline_hp(walls)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		for nudge_of: Array in HP_NUDGES:
			var next := _nudged(now, nudge_of[0])
			# The small face: four buttons and a growing number share the page's width.
			var nudge := UITheme.button(nudge_of[0], "SmallButton", nudge_of[1])
			nudge.disabled = next == now
			nudge.pressed.connect(func() -> void:
				Settings.wall_hp[walls] = next
				Settings.save()
				_open_balance.call_deferred())
			row.add_child(nudge)
		var value := UITheme.label(BigNumber.format(now))
		value.tooltip_text = HP_BASE_TIP
		value.mouse_filter = Control.MOUSE_FILTER_PASS
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(value)
		row.move_child(value, 2)
		body.add_child(row)


## `from` after one of `HP_NUDGES`' faces: whole numbers, never under 1.
static func _nudged(from: float, face: String) -> float:
	match face:
		"/10": return maxf(1.0, roundf(from / 10.0))
		"-1": return maxf(1.0, from - 1.0)
		"+1": return from + 1.0
		_: return from * 10.0


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)
	laid_out.emit()
