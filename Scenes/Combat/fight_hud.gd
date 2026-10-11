class_name FightHud
extends Control
## Everything `CombatScene` stands over its arena, on the one Control named "HUD": the place, the pips
## and the clock top centre, the enemy's nameplate bottom centre, the loot counter and Terminate in two
## corners, and the two panels that come up in the middle, the loot popup and the verdict. It reads the
## Encounter it is built for and nothing of the scene's; the scene tells it what happened (`keep`,
## `dress_nameplate`, `flash_clock`, `show_verdict`). Why it is laid out as it is: `DESIGN.md`.

## A find the player threw away by hand, from the verdict.
signal drop_discarded(item: Item)
## The loot popup or the verdict has come up: the main scene puts its bag away, which would otherwise
## stand over either (the pages are drawn on a layer above the fight's).
signal panel_up
## The verdict left by Collect or the back arrow, or by Retry, once it has shrunk away.
signal back_pressed
signal retry_pressed

## Held upright (`UITheme.narrow`) the nameplate stands this many panel pixels under the fighters' feet,
## which are at `CombatScene.GROUND_UPRIGHT`, rather than at the window's foot.
const PLATE_UNDER := 16.0

const BAR_BACK := Color(Palette.INK, 0.85)
## The damage red, the health bar's own: the crit numbers and the end of the clock's ramp are keyed to it.
const BAR_HEALTH := HealthBar.FILL
const BAR_TIME := Palette.LEAF_LT
## The clock's dark border, in panel pixels. The HUD stands on the backdrop with no panel behind it, and
## a bar with no border disappears into about half of them.
const BAR_BORDER := 2
## The outline the HUD's own words carry, for the same reason: a whole multiple of Pixellari's pixel.
const LABEL_OUTLINE := 4
## Panel pixels. Under a pip bar whose crown stands 13 px, a six-pixel ribbon read as an afterthought.
const CLOCK_HEIGHT := 8
## Where the clock's colour turns, as shares of the clock and not seconds: plain green above
## `CLOCK_GREEN`, ambering through the middle, reddening under `CLOCK_AMBER`.
const CLOCK_GREEN := 0.6
const CLOCK_AMBER := 0.3
## What the clock turns as an enemy's blow lands on it, and how long it takes to fade back. Over-bright,
## because it is multiplied over the clock's own ramp.
const CLOCK_STRUCK := Color(2.2, 0.6, 0.6)
const CLOCK_STRUCK_TIME := 0.35
## The loot counter's face as the bag fills: a tint multiplied over the square button's art, so
## `FACE_BROWN` has to be what `ui_kit.py` draws (the base step of `ui_btn_brown_normal`). `FACE_DANGER`
## is the pack's own red, the key its danger button is played in.
const FACE_BROWN := Palette.BUTTON_BROWN
const FACE_DANGER := Color("c42430")
## How bright the counter flashes as a coin reaches it.
const BUMP_FLASH := Color(1.6, 1.6, 1.6)
## How far the HUD's corners stand off the window's edge, in screen pixels.
const HUD_MARGIN := 8.0
## The air between the clock's column and a verdict, and between a popup and the window, in panel pixels.
const RESULT_GAP := 4
const SACK_ICON := preload("res://Assets/UI/ui_icon_sack.png")
const FLAG_ICON := preload("res://Assets/UI/ui_icon_flag.png")
## The verdict's kill mark: two swords crossed, never a skull, which is also what a curse costs and
## what marks an elite.
const KILLS_MARK := preload("res://Assets/UI/ui_icon_kills_brown.png")
## What the nameplate says a tier in: the name's colour -- the pips' and the health bar's own green and
## gold -- and the mark either side of it, cut cream by tools/ui_kit.py.
const TIER_COLOUR := {
	EnemyRoster.Tier.COMMON: Palette.BONE,
	EnemyRoster.Tier.ELITE: Palette.LEAF_LT,
	EnemyRoster.Tier.BOSS: Palette.GOLD,
}
const TIER_MARK := {
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_icon_skull.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_icon_crown.png"),
}
## A boss's name is written at twice Pixellari's native size, the one other size it stays crisp at,
## and pops in from `BOSS_POP` times that over `BOSS_POP_TIME`, white before it is gold.
const NAME_FONT := 16
const BOSS_FONT := 32
const BOSS_POP := 1.5
const BOSS_POP_TIME := 0.35

# The main scene's, set before `CombatScene.begin` and whenever they change.
## How many finds the bag can still take, or -1 when nobody has said (a fight with no bag behind it),
## and how many it holds in all (`Inventory.capacity`): the counter's face is the share.
var bag_room := -1
var bag_size := Inventory.CAPACITY
## How far down the window the top-centre column stands, in screen pixels: under the character panel on
## a window too narrow for the two side by side.
var hud_top := HUD_MARGIN

var fight: Encounter
var _ui_scale := 2.0
## The top-centre column: the place and its level, the pips, the clock.
var _tally: VBoxContainer
## The gold half of the heading, which the dungeon rewrites floor by floor.
var _level_label: Label
var _pips: KillPips
var _clock: VBoxContainer
var _clock_fill: ColorRect
var _clock_label: Label
## The nameplate, bottom centre.
var _enemy_panel: VBoxContainer
var _enemy_label: Label
var _enemy_marks: Array[TextureRect] = []
var _enemy_title: Label
var _enemy_bar: HealthBar
var _enemy_hp_label: Label
## How much larger than it belongs the nameplate is drawn this frame: 1 but for a boss's entrance.
var _plate_pop := 1.0
var _plate_tween: Tween
## The way out, in every fight: a run and a descent are ended by it, a tile fight given up.
var _terminate: Button
var _gave_up := false
## The loot counter in the corner, and the popup it opens with its sums.
var _loot_button: Button
var _loot_panel: VBoxContainer
var _loot_drops: DropsView
var _loot_gold: Label
var _loot_xp: Label
var _loot_kills: Label
## The counter's faces (`_build_corners`), and the fill they are tinted for, so they are only touched
## when it moves.
var _loot_faces: Array[StyleBox] = []
var _loot_filled := -1.0
## The verdict: the word on its bar, a second line, the sums (the gold's and the experience's rows
## hidden at nothing), the finds, the autodiscard footnote, and the way out -- `_collect`, or
## `_lost_row` under a lost tile.
var _result: VBoxContainer
var _result_label: Label
var _result_detail: Label
var _gold_row: HBoxContainer
## Spins while the gold counts up.
var _gold_coin: TextureRect
var _gold_label: Label
var _xp_row: HBoxContainer
var _xp_label: Label
var _kills_label: Label
var _result_drops: DropsView
var _auto_label: Label
var _collect: Button
var _lost_row: HBoxContainer

## What this fight has turned up, in the order it fell (`keep`). Autodiscarded finds are not in here.
var _drops: Array[Item] = []


func _init() -> void:
	name = "HUD"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()
	# Over everything the fight throws -- finds and their beams, coins, gems, numbers, bursts -- whose
	# own `z_index` must never reach it.
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX


## Builds the HUD for `encounter`, once it is in the tree. `level` and `place` are the heading's.
func build(encounter: Encounter, level: int, place: String, ui_scale: float) -> void:
	fight = encounter
	_ui_scale = ui_scale
	_build_tally(place, level)
	_build_corners()
	_build_nameplate()
	_build_verdict()
	_build_loot_panel()


## Top centre: the place's name and level over the pips, and the clock under them. A run keeps only
## the pips: it has no clock to spend.
func _build_tally(place: String, level: int) -> void:
	_tally = VBoxContainer.new()
	_tally.add_theme_constant_override("separation", 6)
	_tally.scale = Vector2(_ui_scale, _ui_scale)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tally)
	# Two labels rather than one line: a punctuation glyph between them is one Pixellari may not draw.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally.add_child(header)
	if not place.is_empty():
		header.add_child(hud_label(place, Palette.BONE))
	_level_label = hud_label("Level %d" % level, Palette.GOLD)
	header.add_child(_level_label)
	# As many pips as this fight has enemies or, for a run, the cycle it repeats between elites.
	var slots: int = fight.elite_every if fight.endless else fight.enemies
	_pips = KillPips.new(slots)
	_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tally.add_child(_pips)
	_clock = VBoxContainer.new()
	_clock.add_theme_constant_override("separation", 2)
	_clock.visible = not fight.endless
	_clock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tally.add_child(_clock)
	# The border is drawn outside the track, so the track is cut to leave the whole thing exactly as
	# wide as the pip bar above it: the two are one column and a pixel out would show.
	var clock_bar := _bar(KillPips.width_for(slots) - 2 * BAR_BORDER, CLOCK_HEIGHT, BAR_TIME)
	_clock_fill = clock_bar.get_child(0)
	_clock.add_child(_outlined(clock_bar, BAR_BORDER))
	_clock_label = hud_label("", BAR_TIME)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_child(_clock_label)


## The loot counter, bottom right, and Terminate, top right. Each is a Control standing in the arena, so
## it eats the click that lands on it rather than letting it through as a swing -- wanted here, and why
## the main scene hides its own corner buttons while a fight is on.
func _build_corners() -> void:
	_loot_button = _square_button(SACK_ICON, "What this run has turned up", open_loot)
	# Its face says how full the bag is: a copy of the theme's own box per state, tinted, so the tint
	# lands on the box alone and the icon and the count keep their own colours.
	for state: String in UITheme.STATES:
		var face: StyleBox = UITheme.theme().get_stylebox(state, "BrownIconButton").duplicate()
		_loot_faces.append(face)
		_loot_button.add_theme_stylebox_override(state, face)
	add_child(_loot_button)
	# The dungeon turns nothing up, so it has no counter to show and no finds under its verdict.
	_loot_button.visible = not fight.dungeon
	_refresh_loot_button()
	_tint_loot_button()
	_terminate = _square_button(FLAG_ICON,
			"End the run and keep everything it turned up" if fight.endless
			else "End the descent here" if fight.dungeon
			else "Give up the fight and keep what it already turned up", terminate)
	add_child(_terminate)


## Bottom centre: the enemy's name between its tier's marks, a boss's title under it, the health bar
## (wider for an elite and a boss; the column grows to hold it) and the same health in figures: the
## share alone cannot tell a sliver that is one hit from one that is fifty.
func _build_nameplate() -> void:
	_enemy_panel = VBoxContainer.new()
	_enemy_panel.scale = Vector2(_ui_scale, _ui_scale)
	_enemy_panel.add_theme_constant_override("separation", 2)
	add_child(_enemy_panel)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enemy_panel.add_child(name_row)
	_enemy_label = hud_label("", Palette.BONE)
	for side in 2:
		var mark := TextureRect.new()
		mark.stretch_mode = TextureRect.STRETCH_SCALE
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_marks.append(mark)
		name_row.add_child(mark)
		if side == 0:
			name_row.add_child(_enemy_label)
	_enemy_title = _plate_line()
	_enemy_bar = HealthBar.new()
	_enemy_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enemy_panel.add_child(_enemy_bar)
	_enemy_hp_label = _plate_line()


## A line of the nameplate in the body font, centred.
func _plate_line() -> Label:
	var line := hud_label("", Palette.BONE)
	line.theme_type_variation = "SmallLabel"
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_panel.add_child(line)
	return line


## The verdict, hidden until `show_verdict` fills it. No X: the way out is the button at its foot.
func _build_verdict() -> void:
	_result = _popup("")
	var body := UITheme.body_of(_result)
	_result_label = UITheme.title_of(_result)
	_result_detail = panel_label("")
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(_result_detail)
	var sums := _sums_row(body)
	_gold_label = sums[0]
	_gold_row = _gold_label.get_parent()
	_gold_row.hide()
	_gold_coin = _gold_row.get_child(0)
	_xp_label = sums[1]
	_xp_row = _xp_label.get_parent()
	_xp_row.hide()
	_kills_label = sums[2]
	# Kept even when the fight was lost.
	_result_drops = DropsView.new()
	_result_drops.discardable = true
	_result_drops.discarded.connect(_on_drop_discarded)
	_result_drops.resized_contents.connect(_centre_result)
	body.add_child(_result_drops)
	_auto_label = panel_label("")
	_auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# A footnote: quieter without being another colour, the dark half of the palette being lost on the
	# panel.
	_auto_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_auto_label.hide()
	body.add_child(_auto_label)
	_collect = UITheme.button("Collect", "LightButton", "Take it all back to the map")
	_collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_collect.pressed.connect(leave.bind(back_pressed.emit))
	body.add_child(_collect)
	_lost_row = HBoxContainer.new()
	_lost_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(_lost_row)
	var back := UITheme.back_button("Back to the map")
	back.pressed.connect(leave.bind(back_pressed.emit))
	_lost_row.add_child(back)
	var again := UITheme.button("Retry", "LightButton", "Fight for this tile again")
	again.pressed.connect(leave.bind(retry_pressed.emit))
	_lost_row.add_child(again)


## The counter's popup, built as the verdict is. A summary and nothing more -- every find is in the bag
## already, and the bag is where it is handled (the user's ruling, 2026-10-02) -- so its `DropsView` is
## not `discardable`, and every sum is shown even at nothing.
func _build_loot_panel() -> void:
	_loot_panel = _popup("Loot")
	var body := UITheme.body_of(_loot_panel)
	var sums := _sums_row(body)
	_loot_gold = sums[0]
	_loot_xp = sums[1]
	_loot_kills = sums[2]
	_loot_drops = DropsView.new()
	_loot_drops.resized_contents.connect(_centre_loot)
	body.add_child(_loot_drops)
	var close := UITheme.button("Close", "LightButton", "Back to the fight")
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_loot)
	body.add_child(close)


## One of the pages' own panels in the HUD, hidden: its word on the bar, no X. Fill `UITheme.body_of` it.
func _popup(title: String) -> VBoxContainer:
	var panel := UITheme.titled_panel(title, "", Callable())
	panel.scale = Vector2(_ui_scale, _ui_scale)
	panel.hide()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	UITheme.body_of(panel).add_theme_constant_override("separation", 8)
	return panel


## A fight's earnings as one row of bare numbers behind their marks: gold, experience and bodies, whose
## labels it returns in that order. Centred by shrinking to what it holds: HORIZONTAL_ALIGNMENT_CENTER
## centres text inside a label and says nothing about where the label sits in the column.
func _sums_row(into: Container) -> Array[Label]:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	into.add_child(row)
	var coin := Vector2(Coins.SIZE, Coins.SIZE)
	var gem := CombatScene.XP_GEM
	return [_sum(row, Coins.icon(), coin), _sum(row, gem, gem.get_size() * CombatScene.XP_GEM_SCALE),
			_sum(row, KILLS_MARK, coin)]


## One sum in that row. The mode goes on before the texture, or the minimum stays the texture's (see
## OrbSlot).
func _sum(row: HBoxContainer, icon: Texture2D, mark_size: Vector2) -> Label:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	row.add_child(pair)
	var mark := TextureRect.new()
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture = icon
	mark.custom_minimum_size = mark_size
	pair.add_child(mark)
	var label := panel_label("")
	pair.add_child(label)
	return label


## A brown square with a cream mark, the same button as the map's bag and skills, at the HUD's scale.
## The loot counter also writes its count on it, so the words are cream to match the mark.
func _square_button(icon: Texture2D, tip: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.theme_type_variation = "BrownIconButton"
	button.icon = icon
	button.expand_icon = false
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(item, Palette.PANEL_CREAM)
	button.add_theme_color_override("font_disabled_color", UITheme.DISABLED_FONT_COLOR)
	button.scale = Vector2(_ui_scale, _ui_scale)
	button.tooltip_text = tip
	button.pressed.connect(on_press)
	return button


## A word standing on the arena rather than on a panel: its own colour, and the dark outline that makes
## it readable over a snowfield or a noon desert. Never a plain `Label` there.
static func hud_label(text: String, colour: Color) -> Label:
	var label := panel_label(text)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	return label


static func panel_label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	return label


## A track with a fill inside it: the fill is the first child, and its width is set as things change.
## Drawn rather than cut from Assets/bars.png, whose bars come in seven fixed steps in a glossier style.
func _bar(width: int, height: int, fill: Color) -> Control:
	var track := ColorRect.new()
	track.color = BAR_BACK
	track.custom_minimum_size = Vector2(width, height)
	var bar := ColorRect.new()
	bar.color = fill
	bar.size = Vector2(width, height)
	bar.position = Vector2.ZERO
	track.add_child(bar)
	return track


## A dark border round something, so it reads on whatever the arena puts behind it. The
## PanelContainer's content margins are the border, so the thing inside is laid out with no inset to
## work out twice.
func _outlined(inner: Control, border: int) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.INK
	box.content_margin_left = border
	box.content_margin_right = border
	box.content_margin_top = border
	box.content_margin_bottom = border
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(inner)
	return panel


func _size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)


func refresh() -> void:
	if fight == null:
		return
	var view := _size()
	if not fight.endless:
		var seconds := ceili(fight.time_left)
		_clock_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
		var share := clampf(fight.time_left / fight.seconds, 0.0, 1.0)
		_clock_fill.size.x = _clock_fill.get_parent().size.x * share
		var tint := _clock_color(share)
		_clock_fill.color = tint
		_clock_label.add_theme_color_override("font_color", tint)
	if fight.dungeon:
		_level_label.text = "Depth %d" % fight.depth()
	_pips.show_fight(fight)
	_place_corners(view)
	if _loot_panel.visible:
		_refresh_loot_sums()

	if fight.index >= fight.lineup.size() or fight.finished:
		_enemy_panel.hide()
		return
	_enemy_panel.show()
	var share := fight.hp / maxf(fight.enemy_max_hp(), 1.0)
	# `tier_in`, the call the pips colour themselves through, so frame and pip cannot disagree.
	_enemy_bar.show_health(Encounter.tier_in(fight, fight.index), maxf(share, 0.0))
	# Rounded up for the reason the bar never empties to nothing: anything still standing reads as at
	# least 1.
	_enemy_hp_label.text = "%s / %s" % [BigNumber.format(ceilf(maxf(fight.hp, 0.0))),
			BigNumber.format(ceilf(fight.enemy_max_hp()))]


## What colour the clock is at `share` of its time left: green, through the palette's gold, to the red
## a hit lands in. A ramp and not a switch: it is read out of the corner of an eye.
func _clock_color(share: float) -> Color:
	if share >= CLOCK_GREEN:
		return BAR_TIME
	if share >= CLOCK_AMBER:
		return Palette.GOLD.lerp(BAR_TIME, (share - CLOCK_AMBER) / (CLOCK_GREEN - CLOCK_AMBER))
	return BAR_HEALTH.lerp(Palette.GOLD, maxf(share, 0.0) / CLOCK_AMBER)


## The bottom of the top-centre column -- place, pips and clock -- in screen pixels, for anything the
## main scene stands over a fight and has to keep off the HUD.
func hud_bottom() -> float:
	return _tally.position.y + _tally.get_combined_minimum_size().y * _ui_scale


## The bottom of the top-right corner's Terminate flag, in screen pixels: the character panel stands
## under it while the bag is up over the fight.
func corner_bottom() -> float:
	return _terminate.position.y + _terminate.get_combined_minimum_size().y * _ui_scale


## Puts the HUD where it belongs. Done every frame rather than anchored, because every part of it is
## scaled by `_ui_scale` and an anchor knows nothing about that. The two columns are centred, so a wider
## elite or boss bar grows evenly either side.
func _place_corners(view: Vector2) -> void:
	var tally := _tally.get_combined_minimum_size() * _ui_scale
	_tally.position = Vector2((view.x - tally.x) / 2.0, hud_top)
	# The corners keep to the safe part of the window: on a phone, clear of a notch and its rounded
	# corners.
	var safe := UITheme.safe_rect(get_viewport())
	_enemy_panel.scale = Vector2.ONE * _ui_scale * _plate_pop
	var plate := _enemy_panel.get_combined_minimum_size() * _enemy_panel.scale
	var plate_y := safe.end.y - plate.y - HUD_MARGIN
	# Held upright the fight stands mid-window, and its nameplate under its feet, not at the window's
	# foot.
	if UITheme.narrow(view, _ui_scale):
		plate_y = view.y * CombatScene.GROUND_UPRIGHT + PLATE_UNDER * _ui_scale
	_enemy_panel.position = Vector2((view.x - plate.x) / 2.0, plate_y)
	var loot := _loot_button.get_combined_minimum_size() * _ui_scale
	_loot_button.position = Vector2(safe.end.x - loot.x - HUD_MARGIN, safe.end.y - loot.y - HUD_MARGIN)
	_tint_loot_button()
	var flag := _terminate.get_combined_minimum_size() * _ui_scale
	_terminate.position = Vector2(safe.end.x - flag.x - HUD_MARGIN, safe.position.y + HUD_MARGIN)


## The nameplate for whoever is walking in: an elite's title in front of its name, a boss's under it.
## Once per enemy and never in `refresh`: none of it changes while the enemy stands.
func dress_nameplate() -> void:
	var tier := Encounter.tier_in(fight, fight.index)
	var boss := tier == EnemyRoster.Tier.BOSS
	var title := fight.enemy_title()
	_enemy_label.text = fight.enemy_name() if boss or title.is_empty() \
			else "%s %s" % [title, fight.enemy_name()]
	_enemy_label.add_theme_font_size_override("font_size", BOSS_FONT if boss else NAME_FONT)
	_enemy_title.text = title
	_enemy_title.visible = boss
	for mark in _enemy_marks:
		mark.texture = TIER_MARK.get(tier)
		mark.visible = mark.texture != null
		# A skull stays the bone it is cut in -- tinted green it sank into every meadow -- and only a
		# crown is gilded.
		mark.modulate = Palette.GOLD if boss else Color.WHITE
		if mark.visible:
			mark.custom_minimum_size = mark.texture.get_size() * (2 if boss else 1)
	if _plate_tween != null and _plate_tween.is_valid():
		_plate_tween.kill()
	_plate_pop = 1.0
	_tint_nameplate(TIER_COLOUR[tier])
	if boss and Settings.animations == Settings.Anim.DEFAULT:
		_plate_tween = create_tween().set_parallel()
		_plate_tween.tween_property(self, "_plate_pop", 1.0, BOSS_POP_TIME).from(BOSS_POP) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_plate_tween.tween_method(_tint_nameplate, Color.WHITE, TIER_COLOUR[tier], BOSS_POP_TIME)


func _tint_nameplate(colour: Color) -> void:
	_enemy_label.add_theme_color_override("font_color", colour)


## The clock showing it has just been struck. Not behind the animation level: it is how a player
## without the numbers sees that the time went.
func flash_clock() -> void:
	if _clock == null or fight.endless:
		return
	_clock.modulate = CLOCK_STRUCK
	create_tween().tween_property(_clock, "modulate", Color.WHITE, CLOCK_STRUCK_TIME)


## A brightening rather than a swell: `_place_corners` pins the counter by its top-left corner every
## frame, and scaling it about its middle would walk it off the corner.
func counter_centre() -> Vector2:
	return _loot_button.position + _loot_button.size * _ui_scale / 2.0


func bump_counter() -> void:
	_loot_button.modulate = BUMP_FLASH
	create_tween().tween_property(_loot_button, "modulate", Color.WHITE, CombatScene.HIT_TIME * 2.0)


# ---- the loot counter and its popup

## A find being kept: the counter counts it, and the popup lists it if it is open.
func keep(item: Item) -> void:
	_drops.append(item)
	_refresh_loot_button()
	loot_changed()


## Something joined what the popup lists: a find, or an orb, which is never in `_drops`.
func loot_changed() -> void:
	if _loot_panel.visible:
		_fill_loot()


## A find thrown away by hand from the verdict. The popup shows the same drops, so it is filled too.
func _on_drop_discarded(item: Item) -> void:
	_drops.erase(item)
	_refresh_loot_button()
	_fill_loot()
	_result_drops.fill(_drops, fight.orbs)
	drop_discarded.emit(item)


## The counter's face: brown through gold to red as the bag fills, a ramp as the clock's is. Nobody
## having said (`bag_room` at -1) is an empty bag.
func _tint_loot_button() -> void:
	var fill := 0.0 if bag_room < 0 else clampf(1.0 - float(bag_room) / maxi(bag_size, 1), 0.0, 1.0)
	if is_equal_approx(fill, _loot_filled):
		return
	_loot_filled = fill
	var want := (FACE_BROWN.lerp(Palette.GOLD, fill / 0.5) if fill <= 0.5
			else Palette.GOLD.lerp(FACE_DANGER, (fill - 0.5) / 0.5))
	# A tint multiplies, so what the boxes are given is the colour wanted divided by the colour the
	# pack drew.
	var tint := Color(want.r / FACE_BROWN.r, want.g / FACE_BROWN.g, want.b / FACE_BROWN.b)
	for face: StyleBox in _loot_faces:
		(face as StyleBoxTexture).modulate_color = tint


## The counter says how many finds there are. Never disabled: at 0 its popup still says the purse,
## experience and bodies so far.
func _refresh_loot_button() -> void:
	_loot_button.text = str(_drops.size())


## The popup's finds and orbs, and no panel for them at all while there are neither.
func _fill_loot() -> void:
	_loot_drops.fill(_drops, fight.orbs)
	_loot_drops.visible = not (_drops.is_empty() and fight.orbs.is_empty())


func open_loot() -> void:
	_fill_loot()
	_refresh_loot_sums()
	_loot_panel.show()
	Juice.pop_in(_loot_panel, _ui_scale)
	_centre_loot()
	panel_up.emit()


func _refresh_loot_sums() -> void:
	_loot_gold.text = BigNumber.format(fight.gold)
	_loot_xp.text = BigNumber.format(fight.xp)
	_loot_kills.text = str(fight.kills())


func loot_open() -> bool:
	return _loot_panel.visible


func close_loot() -> void:
	_loot_panel.hide()


## The window changed: whichever panel is up goes back to its middle.
func recentre() -> void:
	if _result.visible:
		_centre_result()
	if _loot_panel.visible:
		_centre_loot()


func _centre_loot() -> void:
	await get_tree().process_frame
	_fit_window(_loot_panel, _loot_drops)
	Juice.centre(_loot_panel, _size())


## A popup taller than the window gives up rows of its finds until it fits, and they scroll.
func _fit_window(panel: Control, drops: DropsView) -> void:
	var over := panel.get_combined_minimum_size().y - (_size().y / _ui_scale - 2.0 * RESULT_GAP)
	if over > 0.0 and drops.visible:
		drops.fit_rows(over)
	# And never bigger than what it holds: a find opened is shorter than the grid it was opened from.
	panel.reset_size()


## Terminate. A run and a descent are ended by it: neither is lost, and the floor a descent reached
## stands. A tile fight is given up: a loss, told apart from running out of time under the verdict.
func terminate() -> void:
	if fight.endless or fight.dungeon:
		fight.stop()
	else:
		_gave_up = true
		fight.give_up()


## The verdict's words and its way out. A run is told what it did rather than how it went, and only a
## loss has a second line -- but for a descent, whose is whether it got any deeper, which only a dead
## Gollux makes it.
func _word_verdict(won: bool, lost: bool) -> void:
	if fight.endless:
		_result_label.text = "Run ended"
	elif fight.dungeon:
		_result_label.text = "Depth %d" % fight.depth()
	else:
		_result_label.text = "Success" if won else "Failed"
	_result_detail.text = "Given up" if _gave_up else "Out of time"
	if fight.dungeon:
		_result_detail.text = "Gollux still stands" if fight.cleared() == 0 \
				else "Gollux fell" if fight.cleared() == 1 else "Gollux fell %d times" % fight.cleared()
		# There is nothing to collect: the dungeon pays nothing.
		_result_drops.hide()
		_collect.text = "Leave"
		_collect.tooltip_text = "Back to the map"
	_result_detail.visible = lost or fight.dungeon
	# A tile lost is headed red, not in the green a win wears; a descent ends rather than fails.
	UITheme.danger_bar(_result, lost and not fight.dungeon)
	_collect.visible = not lost
	_lost_row.visible = lost


func _count_earnings(auto_discarded: int) -> void:
	if fight.gold > 0.0:
		_gold_row.show()
		Juice.count_up(_gold_label, fight.gold, _gold_coin)
	if fight.xp > 0:
		_xp_row.show()
		Juice.count_up(_xp_label, float(fight.xp))
	Juice.count_up(_kills_label, float(fight.kills()))
	if auto_discarded > 0:
		_auto_label.text = ("1 item discarded automatically" if auto_discarded == 1
				else "%d items discarded automatically" % auto_discarded)
		_auto_label.show()


## Shrinks the verdict away, then does what its button was for.
func leave(then: Callable) -> void:
	Juice.pop_out(_result, then)


## The verdict is only as big as what it holds, and what it holds changes when a drop is opened, so it
## is put back in the middle every time -- after a frame, once it knows its new size. A panel that
## would reach up over the clock and the pips, which say how the fight ended, is put down under them
## instead -- but never off the foot of the window, so a run's tall verdict still shows its Collect.
func _centre_result() -> void:
	await get_tree().process_frame
	_fit_window(_result, _result_drops)
	Juice.centre(_result, _size())
	var top := _result.position.y + _result.pivot_offset.y * (1.0 - _ui_scale)
	var bottom := top + _result.get_combined_minimum_size().y * _ui_scale
	var room := _size().y - RESULT_GAP * _ui_scale - bottom
	var drop := minf(hud_bottom() + RESULT_GAP * _ui_scale - top, room)
	if drop > 0.0:
		_result.position.y += drop


## The fight is over: the verdict comes up in the nameplate's and Terminate's place, saying once how
## many finds the player's rule threw away. It centres itself a frame on, so the scene does not wait.
func show_verdict(won: bool, auto_discarded: int) -> void:
	_enemy_panel.hide()
	# A run is not won or lost, only ended.
	var lost := not won and not fight.endless
	_word_verdict(won, lost)
	if lost:
		Juice.sound(FightSounds.DEFEAT_SOUND)
	_loot_panel.hide()
	panel_up.emit()
	_count_earnings(auto_discarded)
	# The way out of a fight goes with the fight: the verdict's button is the one thing left to do.
	_terminate.hide()
	_result_drops.fill(_drops, fight.orbs)
	_result.show()
	Juice.pop_in(_result, _ui_scale)
	Juice.reveal(_result_drops.pieces())
	await _centre_result()
	# A loss is not celebrated; a win, an ended run and a descent are.
	if not lost:
		Juice.celebrate(self, _result, _ui_scale, (_result.get_child(0) as Control).size.y)
