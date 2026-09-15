class_name CombatScene
extends CanvasLayer
## Draws one Encounter: the player on the left, the tile's enemies walking in one at a time from the
## right, and a click doing a point of damage to whichever is standing there. When it is over, a
## panel says whether the ten were beaten and lists what they dropped.
##
## Everything below the HUD is built in code, so the .tscn stays a stub the editor can hold open --
## the same convention as main_scene._build_ui and HexMap._ready. The scene owns no rules: it asks
## the Encounter what is happening and shows it.
##
## It is a CanvasLayer rather than a scene of its own, so the main scene can put a fight in front of
## the map without unloading it. The map holds a whole generated world in memory that a scene change
## would throw away.
##
## How far through the fight the player is is said by the KillPips bar under the clock and nowhere
## else: ten pips in their enemies' tier colours, draining from the left as the enemies go down. A
## number saying the same thing is the one thing on that panel a player mid-fight has no time to read.

## The fight is over. `won` says whether the tile was taken.
signal finished(won: bool)
## A find that is being kept. This, and not `Encounter.loot_dropped`, is what the rest of the game
## hears: the autodiscard rule is applied here and nowhere else, so the counter, the pouch and the
## bag can never come to different answers about what a run found.
signal loot_kept(index: int, item: Item)
## A find thrown away on sight by the player's own rule. It is counted and named here for whoever is
## keeping the promise of a first elite drop, and it is never drawn.
signal loot_discarded(index: int, item: Item)
## A find the player threw away by hand, from the verdict panel or the mid-run popup.
signal drop_discarded(item: Item)
## A body's purse. Re-emitted from `Encounter.gold_dropped` rather than left for the main scene to
## hear directly, for the reason `loot_kept` is: the fight is the one thing downstream listens to,
## so the first rule that is ever applied to gold has one place to live.
signal gold_gained(amount: int)
## An orb off a body. Re-emitted from `Encounter.orb_dropped` for the reason `gold_gained` is: the
## fight is the one thing downstream listens to. Nothing here can refuse it -- there is no cap and no
## rule that filters currency -- so unlike a find it has no `kept`/`discarded` pair.
signal orb_gained(orb: String)

## Where the fighters stand, as a share of the viewport: the grass band of the backdrop.
const GROUND := 0.86
const PLAYER_X := 0.24
const ENEMY_X := 0.72
## How tall an ordinary fighter stands, as a share of the viewport height. Sheets vary wildly (a
## slime frame is 32x25, a Demon Boss 162x148), so nobody is drawn at their sheet's scale -- they are
## drawn at the size the roster says their body is.
const ACTOR_HEIGHT := 0.33
## What each Size band is worth against that, so a slime is knee-high and a boss looms.
const SIZE_HEIGHT := {
	EnemyRoster.Size.TINY: 0.45,
	EnemyRoster.Size.SMALL: 0.80,
	EnemyRoster.Size.MEDIUM: 1.00,
	EnemyRoster.Size.LARGE: 1.25,
	EnemyRoster.Size.HUGE: 1.55,
}
## The elite at the end stands a little taller than its body alone would, so it reads as the wall it is.
const ELITE_SCALE := 1.15
## Where an enemy starts its run-in, past the right edge.
const OFFSCREEN_X := 1.15
## The backdrops: one per environment and variant under Assets/Area. They are all drawn to the same
## skeleton -- horizon and ground on the same rows -- so GROUND stands the fighters in the same place
## whichever one is behind them.
const AREA_PATH := "res://Assets/Area/%s_%s_%d.png"
## How many ways each place was drawn. A village is four villages: the same environment and the same
## tier, built four ways, so two towns on one map are not the same picture twice. Must agree with
## `areas.LAYOUTS_PER_VARIANT` in the generator; `_test_backdrops` sweeps every path to hold it.
## Changing it re-rolls which backdrop each tile fights on, which is harmless -- nothing is saved
## about the one it had.
const AREA_LAYOUTS := 4
## What to draw when the world asks for a place that has no art: a fight always has a backdrop.
const AREA_FALLBACK := "res://Assets/Area/grass_plain_1.png"
const ATTACK_SOUND := preload("res://Assets/Player/attack.mp3")

## The bar behind the enemy's health and the clock, and the two fills.
const BAR_BACK := Color(0.08, 0.07, 0.11, 0.85)
const BAR_HEALTH := Color("c4453a")
const BAR_TIME := Color("6fa84a")
## How thick a dark border the clock is given, in panel pixels. The HUD stands on the arena itself
## rather than on a wood panel, so what is behind it is a backdrop -- a snow field, a desert noon, a
## night sky -- and a bar with no border round it disappears into about half of them.
const BAR_BORDER := 2
## How thick an outline the HUD's own words carry -- the place's name and level, and the clock's
## number -- for the same reason. Pixellari is a pixel font, so this is kept to a whole multiple of
## the pixel.
const LABEL_OUTLINE := 4
## How tall the clock's bar is drawn, in panel pixels. Taller than it was: it stands under a pip bar
## that is now drawn at KillPips.PIXEL, and a six-pixel ribbon under that reads as an afterthought.
const CLOCK_HEIGHT := 8
## Where the clock's colour turns. Above CLOCK_GREEN it is simply green -- a fight that has barely
## started must not look like one in trouble -- then it ambers through the middle and reddens over
## the last stretch. Shares of the clock, not seconds, so retuning Encounter.SECONDS retunes
## these with it.
const CLOCK_GREEN := 0.6
const CLOCK_AMBER := 0.3

## The number that floats off a hit: how long it lives, how far it climbs, how far either side of the
## enemy it may start, and the two sizes it is drawn at. Pixellari renders cleanly at whole multiples
## of its native 16, so the two sizes are 2x and 3x rather than anything between -- a crit is half
## again as tall as an ordinary hit, which is a difference read at a glance and without the number
## having to be counted against its neighbours.
const DAMAGE_TIME := 0.7
const DAMAGE_RISE := 40.0
const DAMAGE_SPREAD := 28.0
const DAMAGE_FONT := 32
const CRIT_FONT := 48
## A crit is the game's own damage red, the colour the enemy's health bar empties in, rather than
## GOLD -- gold is the unique item step and reads as a reward, and a crit is not one.
const CRIT_COLOR := BAR_HEALTH
## Where up the enemy the number starts, as a share of its height. Low enough that the whole rise
## stays clear of the name panel above it.
const DAMAGE_HEIGHT := 0.45
## The coins a body throws out as its purse lands. How long the arc takes, how high it goes and how
## far to either side it may land, all in screen pixels -- the spread is wider than the damage
## numbers' because a coin is small and three of them landing on one spot reads as one coin.
const COIN_TIME := 0.5
const COIN_RISE := 70.0
const COIN_SPREAD := 90.0
## How long each coin after the first is held back, so a rich body does not throw its whole purse as
## one lump.
const COIN_STAGGER := 0.06
## And what happens after it lands: it lies there spinning for a couple of seconds, then goes. The
## arrive-hold-fade a toast has, for the same reason -- something that vanished the instant it landed
## would not be seen at all. The node frees itself at the end of it, so nothing piles up on the
## ground however long a run goes on.
const COIN_REST := 2.0
const COIN_FADE := 0.4
## How far the HUD's panels stand off the window edge, in screen pixels.
const HUD_MARGIN := 8.0
## How far the Terminate button stands off the bottom edge. Further than HUD_MARGIN: it ends the
## run, and it has to be nowhere near where the player is clicking.
const TERMINATE_MARGIN := 20.0
## How long a drop's toast stands before it starts to go, and how long it takes to go.
const TOAST_TIME := 1.6
const TOAST_FADE := 0.5
## How far it slides in from the right as it arrives, and the gap between two of them.
const TOAST_SLIDE := 24.0
const TOAST_GAP := 4.0
## How wide an item's name may run on a toast before it wraps, in panel pixels.
const TOAST_WIDTH := 110.0
## How wide the full-bag warning may run before it wraps. Wider than a toast: it is a sentence
## rather than a name.
const WARNING_WIDTH := 130.0

var fight: Encounter
## The cell being fought for, so the main scene knows what was won.
var cell: Vector2i
## What the world put on that cell -- "plain", "road", "village", "town" or "fortress". The
## environment comes from the encounter; together they name the backdrop.
var area_variant := "plain"
## Which of that place's layouts this fight is on. `begin` takes 0 to mean "whichever this cell
## fights on", which is what the game always wants; the screenshot script passes one explicitly.
var area_layout := 1
## What this place is called, as the map named it when the player first saw it. Set before `begin`,
## the way `bag_room` and `autodiscard` are, because the HUD is built inside it. Empty is allowed
## and means a fight with no map behind it -- the tests and the screenshot scripts -- which then
## says the level alone.
var place := ""

var _ui_scale := 2.0
var _player: CombatActor
var _enemy: CombatActor
var _sound: AudioStreamPlayer

var _hud: Control
var _clock: VBoxContainer
var _clock_fill: ColorRect
var _clock_label: Label
var _tally: VBoxContainer
var _pips: KillPips
var _enemy_panel: PanelContainer
var _enemy_label: Label
var _enemy_fill: ColorRect
var _result: PanelContainer
var _result_summary: VBoxContainer
var _result_label: Label
var _result_detail: Label
## Where the fight's drops are listed, under the verdict.
var _result_drops: DropsView
## The bag in the corner: what the run has turned up so far, and the popup it opens.
var _loot_button: Button
var _loot_panel: PanelContainer
var _loot_drops: DropsView
## The toasts standing now, newest last. They are placed by their order in here, so one leaving
## closes the gap it left.
var _toasts: Array[Control] = []
## Leaves a farm run. Only built for one -- a tile fight is left by beating it or running out.
var _terminate: Button
## What this fight has turned up, in the order it fell. Autodiscarded finds are not in here.
var _drops: Array[Item] = []
## How many finds the bag can still take before something has to be destroyed to fit them, or -1
## when nobody has said -- a fight with no bag behind it, which is what the screenshot scripts run.
## The scene owns no rules here: it is handed a number and it draws it.
var bag_room := -1
## Asked of each find's level: whether the player has told the game to stop bringing that level.
## An unset Callable keeps everything, so a fight nobody has told anything behaves as it always did.
var autodiscard := Callable()
## How many finds that rule has thrown away. Said once, at the end, and never drawn as a square:
## the whole point of the rule is not having to look at them.
var _auto_discarded := 0
## The standing warning under the counter, while the bag has no room left.
var _warning: PanelContainer
## The line under the verdict's drops saying how many the rule threw away.
var _auto_label: Label
## And the one over it saying what the fight earned. Gold is said once, at the end: it is not a find
## to be chosen between, so there is nothing to open and nothing to decide while the fight is on.
## The coin beside it goes with it, so the row is what is shown and hidden.
var _gold_label: Label
var _orb_label: Label
var _gold_row: HBoxContainer


## Starts the fight for `cell`. `ui_scale` matches the map's, so the panels are the same size, and
## `variant` is what the world put on the tile, which picks the backdrop with the encounter's terrain.
func begin(encounter: Encounter, for_cell: Vector2i, ui_scale: float, variant := "plain",
		layout := 0) -> void:
	fight = encounter
	cell = for_cell
	area_variant = variant
	area_layout = layout if layout > 0 else layout_for(for_cell)
	_ui_scale = ui_scale
	fight.enemy_coming.connect(_on_enemy_coming)
	fight.enemy_spawned.connect(_on_enemy_spawned)
	fight.enemy_hit.connect(_on_enemy_hit)
	fight.hit_landed.connect(_on_hit_landed)
	fight.enemy_died.connect(_on_enemy_died)
	fight.loot_dropped.connect(_on_loot_dropped)
	fight.gold_dropped.connect(_on_gold_dropped)
	fight.orb_dropped.connect(_on_orb_dropped)
	fight.won.connect(_on_finished.bind(true))
	fight.lost.connect(_on_finished.bind(false))
	_build()
	fight.start()
	_refresh()


func _process(delta: float) -> void:
	if fight == null or fight.finished:
		return
	fight.advance(delta)
	_slide_enemy()
	_refresh()


## A click anywhere in the arena is a swing. The fail state is the clock, so asking the player to
## hit a moving sprite as well would be a second difficulty on top of the one the fight is about.
func _unhandled_input(event: InputEvent) -> void:
	if fight == null or fight.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_player.play_once("attack")
		_sound.play()
		fight.hit()
		_refresh()


## The backdrop for a place. Terrain the art does not cover falls back rather than failing: a fight
## with no picture behind it would be unplayable, and a missing file is a build problem, not a
## reason to lose the tile.
static func backdrop_for(env: String, variant: String, layout := 1) -> Texture2D:
	var path := AREA_PATH % [env, variant, clampi(layout, 1, AREA_LAYOUTS)]
	if not ResourceLoader.exists(path):
		push_warning("No backdrop for %s/%s/%d" % [env, variant, layout])
		path = AREA_FALLBACK
	return load(path)


## Which of a place's layouts a cell fights on. Seeded from the cell, like the tile's enemies, so a
## tile always fights on the same backdrop however many times it is attempted -- and under its own
## tag, so which picture is behind the fight has nothing to do with who walks into it.
static func layout_for(for_cell: Vector2i) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["backdrop", for_cell])
	return rng.randi_range(1, AREA_LAYOUTS)


func _size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)


# ---- building

func _build() -> void:
	var view := _size()
	var arena := Node2D.new()
	arena.name = "Arena"
	add_child(arena)

	var art := backdrop_for(fight.env if fight != null else "", area_variant, area_layout)
	var backdrop := Sprite2D.new()
	backdrop.texture = art
	backdrop.centered = false
	# Cover the viewport whatever its shape; the ground band stays across the bottom.
	var cover := maxf(view.x / art.get_width(), view.y / art.get_height())
	backdrop.scale = Vector2(cover, cover)
	backdrop.position = (view - Vector2(art.get_size()) * cover) / 2.0
	arena.add_child(backdrop)

	_player = CombatActor.new()
	_player.name = "Player"
	arena.add_child(_player)
	_player.setup_player(view.y * ACTOR_HEIGHT)
	_player.position = Vector2(view.x * PLAYER_X, view.y * GROUND)
	_player.animation_finished.connect(func() -> void: _player.play("idle"))

	_enemy = CombatActor.new()
	_enemy.name = "Enemy"
	arena.add_child(_enemy)

	_sound = AudioStreamPlayer.new()
	_sound.stream = ATTACK_SOUND
	add_child(_sound)

	_build_hud()


func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UITheme.theme()
	add_child(hud)
	_hud = hud

	# Top middle: where the fight is and how it is going -- the place's name and level over the bar
	# of ten pips draining as the enemies go down, and the clock under it. The
	# bar goes first because it is the fight -- the clock is what the fight is measured against, and
	# a measure belongs under the thing it measures. No panel behind them -- the two are what the
	# player watches and a panel only puts furniture round them -- so each carries its own dark
	# border instead, which is what has to read on a backdrop rather than on wood. Centred because
	# with the panel gone there is no corner to hang off, and the fighters are the left and right of
	# the screen. A farm run keeps only the bar: it has no clock to spend, and its bar cycles
	# between elites rather than draining once.
	_tally = VBoxContainer.new()
	_tally.add_theme_constant_override("separation", 6)
	_tally.scale = Vector2(_ui_scale, _ui_scale)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_tally)
	# Over the lot, what the player is fighting for: the tile's name and its level. Two labels rather
	# than one line of text so the two read as two things -- a name in bone and a number in gold --
	# without a punctuation glyph between them that Pixellari may not draw. It never changes while
	# the fight is on, so it is filled here and never refreshed.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally.add_child(header)
	if not place.is_empty():
		header.add_child(_hud_label(place, Palette.BONE))
	header.add_child(_hud_label("Level %d" % MapBuilder.level_of(cell), Palette.GOLD))
	_pips = KillPips.new()
	_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tally.add_child(_pips)
	_clock = VBoxContainer.new()
	_clock.add_theme_constant_override("separation", 2)
	_clock.visible = not fight.endless
	_clock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tally.add_child(_clock)
	# The border is drawn outside the track, so the track is cut to leave the whole thing exactly as
	# wide as the pip bar above it: the two are one column and a pixel out would show.
	var clock_bar := _bar(KillPips.WIDTH - 2 * BAR_BORDER, CLOCK_HEIGHT, BAR_TIME)
	_clock_fill = clock_bar.get_child(0)
	_clock.add_child(_outlined(clock_bar, BAR_BORDER))
	# The number under its own bar, so the two bars stay next to each other and the clock still
	# reads as one thing rather than a number wedged between them.
	_clock_label = _hud_label("", BAR_TIME)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_child(_clock_label)

	# Top right: what the run has turned up. It is a Control standing in the arena, so it eats the
	# click that lands on it rather than letting it through as a swing -- which is what is wanted
	# here, and exactly why the main scene hides its own corner button while a fight is on.
	_loot_button = Button.new()
	_loot_button.theme_type_variation = "WoodButton"
	_loot_button.scale = Vector2(_ui_scale, _ui_scale)
	_loot_button.tooltip_text = "What this run has turned up"
	_loot_button.pressed.connect(_on_loot_pressed)
	hud.add_child(_loot_button)
	_refresh_loot_button()

	# Under it, while the bag has nowhere to put anything: the worst of what is found will be
	# destroyed when it is banked. Said as it happens rather than at the end, because the whole
	# reason to say it is to give the player time to go and throw something away themselves.
	_warning = PanelContainer.new()
	_warning.theme_type_variation = "WoodPanel"
	_warning.scale = Vector2(_ui_scale, _ui_scale)
	_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning.hide()
	hud.add_child(_warning)
	_warning.add_child(ItemDetails.line(
			"Bag full -- the worst finds will be destroyed", Palette.RUST, WARNING_WIDTH))

	# Leaving a farm run. Low and in the middle, well away from the enemy: the player is clicking
	# hard and fast up there, and a stray one must not end the run.
	if fight.endless:
		_terminate = Button.new()
		_terminate.text = "Terminate"
		_terminate.theme_type_variation = "WoodDangerButton"
		_terminate.scale = Vector2(_ui_scale, _ui_scale)
		_terminate.tooltip_text = "End the run and keep everything it turned up"
		_terminate.pressed.connect(_on_terminate_pressed)
		hud.add_child(_terminate)

	# Over the enemy: its name and health.
	_enemy_panel = PanelContainer.new()
	_enemy_panel.theme_type_variation = "WoodPanel"
	_enemy_panel.scale = Vector2(_ui_scale, _ui_scale)
	hud.add_child(_enemy_panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	_enemy_panel.add_child(stack)
	_enemy_label = _label("")
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(_enemy_label)
	var enemy_bar := _bar(120, 6, BAR_HEALTH)
	_enemy_fill = enemy_bar.get_child(0)
	stack.add_child(enemy_bar)

	# The verdict, hidden until there is one.
	_result = PanelContainer.new()
	_result.theme_type_variation = "WoodPanel"
	_result.scale = Vector2(_ui_scale, _ui_scale)
	_result.hide()
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_result)
	var verdict := VBoxContainer.new()
	verdict.add_theme_constant_override("separation", 8)
	_result.add_child(verdict)

	# What happened, and what it left. Swapped out for one item's details when a square is clicked,
	# rather than growing the panel: a piece with six modifiers is taller than the verdict itself.
	_result_summary = VBoxContainer.new()
	_result_summary.add_theme_constant_override("separation", 8)
	verdict.add_child(_result_summary)
	_result_label = _label("")
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary.add_child(_result_label)
	_result_detail = _label("")
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary.add_child(_result_detail)
	# What the fight left behind, under the verdict. Kept even when it was lost, so this is where
	# that promise is visibly kept.
	_result_drops = DropsView.new()
	_result_drops.discardable = true
	_result_drops.discarded.connect(_on_drop_discarded)
	_result_drops.resized_contents.connect(_centre_result)
	_result_summary.add_child(_result_drops)
	# What the fight earned, over the footnote and under the finds: a purse off every body is the one
	# part of the takings that is never nothing, so it reads as part of the verdict rather than as an
	# aside. In the panel's own colour -- Palette.GOLD is the unique item step, and spending it here
	# would put one colour on a currency and on an item's name in the same panel.
	# The coin rather than the word, the same one the bag's footer wears. Centred by the row shrinking
	# to its contents: HORIZONTAL_ALIGNMENT_CENTER centres text inside a label and says nothing about
	# where the label itself sits in the column.
	_gold_row = HBoxContainer.new()
	_gold_row.add_theme_constant_override("separation", 6)
	_gold_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_gold_row.hide()
	_result_summary.add_child(_gold_row)
	var coin := TextureRect.new()
	coin.texture = Coins.icon()
	coin.custom_minimum_size = Vector2(Coins.SIZE, Coins.SIZE)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_gold_row.add_child(coin)
	_gold_label = _label("")
	_gold_row.add_child(_gold_label)
	# What the run turned up in currency, as a count. Which orbs is what the tray in the bag is for,
	# and each was named by its own toast as it landed; a verdict wants the score.
	_orb_label = _label("")
	_orb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_orb_label.hide()
	_result_summary.add_child(_orb_label)
	# What the player's own rule threw away, as a number and nothing else. It is said here because a
	# run that quietly found half as much as it did would be a run the player cannot read.
	_auto_label = _label("")
	_auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Quieter than the verdict without being another colour: the panel is wood, and the dark half of
	# the palette that reads on the bone one disappears into it. The same dimming DropsView gives
	# "Nothing dropped", for the same reason -- it is a footnote, not a finding.
	_auto_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_auto_label.hide()
	_result_summary.add_child(_auto_label)
	var back := Button.new()
	back.text = "Back to the map"
	back.theme_type_variation = "WoodButton"
	back.pressed.connect(_on_back_pressed)
	_result_summary.add_child(back)

	# The same list again, on its own panel, for the counter in the corner to open mid-run. A farm
	# run has no verdict to wait for, so this is the only way to see what it has found.
	_loot_panel = PanelContainer.new()
	_loot_panel.theme_type_variation = "WoodPanel"
	_loot_panel.scale = Vector2(_ui_scale, _ui_scale)
	_loot_panel.hide()
	_loot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_loot_panel)
	var found := VBoxContainer.new()
	found.add_theme_constant_override("separation", 8)
	_loot_panel.add_child(found)
	var found_title := _label("Found")
	found_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	found.add_child(found_title)
	_loot_drops = DropsView.new()
	_loot_drops.discardable = true
	_loot_drops.discarded.connect(_on_drop_discarded)
	_loot_drops.resized_contents.connect(_centre_loot)
	found.add_child(_loot_drops)
	var close := Button.new()
	close.text = "Close"
	close.theme_type_variation = "WoodButton"
	close.pressed.connect(_on_loot_closed)
	found.add_child(close)


## A word standing on the arena rather than on a panel: its own colour, and the dark outline that is
## what makes it readable over a snowfield or a noon desert.
func _hud_label(text: String, colour: Color) -> Label:
	var label := _label(text)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	return label


func _label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	return label


## A blow landing. An automatic swing plays the animation and the sound the way a click does, so a
## weapon working on its own looks like the player is doing it rather than like the enemy losing
## health for no reason. A click has already played both -- it plays them whether or not it lands,
## because a swing that hit nothing is still feedback that the click was heard.
func _on_hit_landed(amount: int, crit: bool, automatic: bool) -> void:
	if automatic:
		_player.play_once("attack")
		_sound.play()
	_show_damage(amount, crit)


## The number that floats off the enemy. This is the only place the player can read what their gear
## is worth: everything else about a hit looks the same whether it took one point off or nine.
func _show_damage(amount: int, crit: bool) -> void:
	var label := _label(("%d!" % amount) if crit else str(amount))
	label.add_theme_color_override("font_color", CRIT_COLOR if crit else Palette.BONE)
	label.add_theme_font_size_override("font_size", CRIT_FONT if crit else DAMAGE_FONT)
	label.z_index = 1
	label.scale = Vector2(_ui_scale, _ui_scale)
	add_child(label)
	# Started a little to the side of centre each time, so a fast weapon does not stack its numbers
	# into one illegible pile.
	var view := _size()
	# Off the body rather than off the head: the enemy's name and health sit above it, and a number
	# climbing into that panel is unreadable against it.
	# Centred on that spot across rather than started at it: a crit is three times the width the
	# number used to be, so a left corner pinned to the enemy would hang it off the far side. Only
	# across -- the top stays on the anchor, because DAMAGE_HEIGHT is chosen so the whole rise from
	# there clears the name panel. The width is asked of the font rather than read off the label,
	# which has not been laid out yet.
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			CRIT_FONT if crit else DAMAGE_FONT).x * _ui_scale
	var from := Vector2(view.x * ENEMY_X + randf_range(-DAMAGE_SPREAD, DAMAGE_SPREAD) - width * 0.5,
			view.y * (GROUND - ACTOR_HEIGHT * DAMAGE_HEIGHT))
	label.position = from
	var float_up := create_tween()
	float_up.set_parallel(true)
	float_up.tween_property(label, "position", from + Vector2(0, -DAMAGE_RISE), DAMAGE_TIME)
	float_up.tween_property(label, "modulate:a", 0.0, DAMAGE_TIME).set_ease(Tween.EASE_IN)
	float_up.chain().tween_callback(label.queue_free)


## The purse coming off a body, as coins thrown out of it. `Coins.count_for` decides how many, so a
## richer body visibly pays more without the arena filling up -- the count is the log of the amount,
## not the amount.
##
## Spawned where the enemy is rather than at ENEMY_X the way a damage number is: the purse lands the
## same frame the enemy dies, so the body is still standing there, and the coins come off the thing
## the player just killed. The walked-in position is the fallback for the case where it is not.
func _show_coins(amount: int) -> void:
	var view := _size()
	var from := Vector2(view.x * ENEMY_X, view.y * (GROUND - ACTOR_HEIGHT * DAMAGE_HEIGHT))
	if _enemy != null and _enemy.sprite_frames != null:
		from = _enemy.position - Vector2(0, _enemy.drawn_size().y * 0.5)
	var ground := view.y * GROUND
	for i in Coins.count_for(amount):
		var coin := AnimatedSprite2D.new()
		coin.sprite_frames = Coins.frames()
		coin.z_index = 1
		coin.scale = Vector2(_ui_scale, _ui_scale)
		coin.position = from
		coin.play("spin")
		add_child(coin)
		var to := from.x + randf_range(-COIN_SPREAD, COIN_SPREAD)
		var top := from.y - COIN_RISE
		# An arc, not a rise: across at a steady rate while the height goes up and comes back down.
		# Two hops on y rather than one tween of the whole position, which is what makes it a jump
		# rather than a slide.
		# The hold-back is a delay on each of the three rather than an interval in front of them,
		# because they all run together and a parallel tween's steps are timed from its own start.
		var delay := i * COIN_STAGGER
		var arc := create_tween()
		arc.set_parallel(true)
		arc.tween_property(coin, "position:x", to, COIN_TIME).set_delay(delay)
		arc.tween_property(coin, "position:y", top, COIN_TIME / 2.0) \
				.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		arc.tween_property(coin, "position:y", ground, COIN_TIME / 2.0) \
				.set_delay(delay + COIN_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# It lies where it fell, still spinning, and then goes.
		arc.chain().tween_interval(COIN_REST)
		arc.set_parallel(false)
		arc.tween_property(coin, "modulate:a", 0.0, COIN_FADE)
		arc.tween_callback(coin.queue_free)


## A track with a fill inside it. The fill is the first child, and its width is set as things change.
## Drawn rather than cut from Assets/bars.png, whose bars come in seven fixed steps in a glossier
## style than the rest of the interface.
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


## A dark border round something, so it reads on whatever the arena puts behind it. A PanelContainer
## rather than a rectangle behind a rectangle: its content margins are the border, so the thing
## inside is laid out and measured without anyone working the inset out twice.
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


## What colour the clock is at `share` of its time left: the green it starts at, through the
## palette's gold, to the red a hit lands in. A ramp rather than a switch at some number of seconds
## -- the player is watching the colour out of the corner of an eye, and a bar that is already going
## amber says "hurry" a good deal earlier than one that turns red all at once.
func _clock_color(share: float) -> Color:
	if share >= CLOCK_GREEN:
		return BAR_TIME
	if share >= CLOCK_AMBER:
		return Palette.GOLD.lerp(BAR_TIME, (share - CLOCK_AMBER) / (CLOCK_GREEN - CLOCK_AMBER))
	return BAR_HEALTH.lerp(Palette.GOLD, maxf(share, 0.0) / CLOCK_AMBER)


# ---- drawing what the encounter is doing

## Puts the enemy that is on its way onto the field, off screen and running.
func _on_enemy_coming(_index: int, enemy_name: String, _hp: int) -> void:
	if enemy_name.is_empty():
		_enemy.hide()
		return
	var view := _size()
	_enemy.show()
	var band: float = SIZE_HEIGHT[EnemyRoster.size_of(enemy_name)]
	var elite := ELITE_SCALE if fight.on_elite() else 1.0
	_enemy.setup_enemy(enemy_name, view.y * ACTOR_HEIGHT * band * elite)
	_enemy.position = Vector2(view.x * OFFSCREEN_X, view.y * GROUND)
	_enemy.play("walk")
	_slide_enemy()


## Runs the enemy in over the walk-in, then leaves it standing.
func _slide_enemy() -> void:
	if fight.finished or fight.index >= fight.lineup.size():
		return
	var view := _size()
	var home := view.x * ENEMY_X
	if fight.phase == Encounter.Phase.WALKING_IN:
		var left := fight.phase_left / Encounter.WALK_IN
		_enemy.position.x = lerpf(home, view.x * OFFSCREEN_X, left)
	else:
		_enemy.position.x = home


func _refresh() -> void:
	if fight == null:
		return
	var view := _size()
	# A farm run has no clock; its bar is the whole of what the HUD says.
	if not fight.endless:
		var seconds := ceili(fight.time_left)
		_clock_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
		var share := clampf(fight.time_left / Encounter.SECONDS, 0.0, 1.0)
		_clock_fill.size.x = _clock_fill.get_parent().size.x * share
		# The number goes with the bar. They are one clock, and the colour is the part of it read
		# without looking straight at it.
		var tint := _clock_color(share)
		_clock_fill.color = tint
		_clock_label.add_theme_color_override("font_color", tint)
	_pips.show_fight(fight)
	_place_corners(view)

	if fight.index >= fight.lineup.size() or fight.finished:
		_enemy_panel.hide()
		return
	_enemy_panel.show()
	_enemy_label.text = fight.enemy_name() + ("  (elite)" if fight.on_elite() else "")
	var share := float(fight.hp) / maxi(fight.enemy_max_hp(), 1)
	_enemy_fill.size.x = _enemy_fill.get_parent().size.x * maxf(share, 0.0)
	# Sit the panel over the enemy's head, wherever it has walked to, but never off the screen edge.
	var panel := _enemy_panel.get_combined_minimum_size() * _ui_scale
	_enemy_panel.position = Vector2(
			clampf(_enemy.position.x - panel.x / 2.0, 8.0, view.x - panel.x - 8.0),
			view.y * GROUND - _enemy.drawn_size().y - panel.y - 8.0)


func _on_enemy_spawned(_index: int, _enemy_name: String, _hp: int) -> void:
	_enemy.play("idle")
	_slide_enemy()


func _on_enemy_hit(hp_left: int) -> void:
	if hp_left > 0:
		_enemy.play_once("hurt")


func _on_enemy_died(_index: int) -> void:
	_enemy.play_once("death")


## The one place a find is looked at. A level the player is done with is counted and passed on to
## whoever is keeping the elite promise, and that is all that happens to it: it does not join
## `_drops`, does not move the counter, raises no toast and appears in neither list. Everything else
## goes on exactly as it did, and leaves by `loot_kept`.
func _on_loot_dropped(index: int, item: Item) -> void:
	if autodiscard.is_valid() and bool(autodiscard.call(item.level)):
		_auto_discarded += 1
		loot_discarded.emit(index, item)
		return
	_drops.append(item)
	_refresh_loot_button()
	if _loot_panel.visible:
		_loot_drops.fill(_drops)
	_toast(item)
	loot_kept.emit(index, item)


## A body's purse: coins out of it, and the amount on to whoever is keeping the ledger. The running
## total still lives on the Encounter and the verdict still reads it at the end -- what the coins say
## is that something was earned here, which is the half of it a number at the end of the fight cannot
## tell the player while they are fighting.
func _on_gold_dropped(_index: int, amount: int) -> void:
	_show_coins(amount)
	gold_gained.emit(amount)


## A find thrown away by hand, from either list. Both show the same drops, so both are filled again
## rather than the one that was clicked.
func _on_drop_discarded(item: Item) -> void:
	_drops.erase(item)
	_refresh_loot_button()
	_loot_drops.fill(_drops)
	_result_drops.fill(_drops)
	drop_discarded.emit(item)


## The counter in the corner: the newest find, and how many there are. It wears the last thing
## that dropped rather than an icon of its own -- no pack here draws a bag, and a picture of what
## was just found says more than one would. With nothing found it is a dead button reading 0.
func _refresh_loot_button() -> void:
	_loot_button.text = str(_drops.size())
	_loot_button.disabled = _drops.is_empty()
	_loot_button.icon = null if _drops.is_empty() else _drops[-1].icon()


## Puts the two corner panels where they belong. Done every frame rather than anchored, because
## both are scaled by `_ui_scale` and an anchor knows nothing about that.
func _place_corners(view: Vector2) -> void:
	# The clock and the pips stand in the middle of the top edge. Placed here rather than anchored
	# for the same reason as the rest: the column is scaled by _ui_scale and an anchor knows nothing
	# about that.
	var tally := _tally.get_combined_minimum_size() * _ui_scale
	_tally.position = Vector2((view.x - tally.x) / 2.0, HUD_MARGIN)
	var loot := _loot_button.get_combined_minimum_size() * _ui_scale
	_loot_button.position = Vector2(view.x - loot.x - HUD_MARGIN, HUD_MARGIN)
	_warning.visible = bag_room == 0
	if _warning.visible:
		var warn := _warning.get_combined_minimum_size() * _ui_scale
		_warning.position = Vector2(view.x - warn.x - HUD_MARGIN, HUD_MARGIN + loot.y + TOAST_GAP)
	if _terminate != null:
		var leave := _terminate.get_combined_minimum_size() * _ui_scale
		_terminate.position = Vector2((view.x - leave.x) / 2.0, view.y - leave.y - TERMINATE_MARGIN)


## A find, announced under the counter and gone again. Nothing stops for it: the run carries on
## underneath, and the counter is where a drop is read properly.
func _toast(item: Item) -> void:
	_toast_of(item.icon(), item.display_name(), item.text_color())


## An orb off a body, announced the same way a find is. Its name in BONE rather than in a rarity
## colour, because an orb has no rarity and borrowing one would say it did -- and not in GOLD either,
## which is the unique item step and has no business on a currency.
func _on_orb_dropped(_index: int, orb: String) -> void:
	_toast_of(OrbTable.icon(orb), orb, Palette.BONE)
	orb_gained.emit(orb)


## One toast: a picture, a name, and the slide-in and fade. Written from an icon and a string rather
## than from an Item, because a find and an orb are the same announcement and only differ in what
## they are announcing.
func _toast_of(picture: Texture2D, name_text: String, color: Color) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = "WoodPanel"
	panel.scale = Vector2(_ui_scale, _ui_scale)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = picture
	icon.custom_minimum_size = Vector2(ItemSlot.ICON, ItemSlot.ICON)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)
	row.add_child(ItemDetails.line(name_text, color, TOAST_WIDTH))
	_toasts.append(panel)
	_stack_toasts()

	# It arrives from the right, the side it belongs to, and leaves by fading where it stands.
	panel.modulate.a = 0.0
	var home := panel.position
	panel.position.x += TOAST_SLIDE
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "modulate:a", 1.0, TOAST_FADE / 2.0)
	tween.tween_property(panel, "position:x", home.x, TOAST_FADE / 2.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(TOAST_TIME)
	tween.tween_property(panel, "modulate:a", 0.0, TOAST_FADE)
	tween.tween_callback(func() -> void:
		_toasts.erase(panel)
		panel.queue_free()
		_stack_toasts())


## Lays the standing toasts down the right edge under the counter, oldest at the top. Placed by
## their order in the array rather than remembered, so one leaving closes the gap it left.
func _stack_toasts() -> void:
	var view := _size()
	var top := HUD_MARGIN + _loot_button.get_combined_minimum_size().y * _ui_scale + TOAST_GAP
	# The warning stands between the counter and the toasts while it is up, so nothing lands on it.
	if _warning != null and _warning.visible:
		top += _warning.get_combined_minimum_size().y * _ui_scale + TOAST_GAP
	for panel: Control in _toasts:
		var size := panel.get_combined_minimum_size() * _ui_scale
		panel.position = Vector2(view.x - size.x - HUD_MARGIN, top)
		top += size.y + TOAST_GAP


func _on_loot_pressed() -> void:
	_loot_drops.fill(_drops)
	_loot_panel.show()
	_centre_loot()


func _on_loot_closed() -> void:
	_loot_panel.hide()


## The run ends because the player says so, which is the only way a farm run ends at all.
func _on_terminate_pressed() -> void:
	fight.stop()


func _on_finished(won: bool) -> void:
	_refresh()
	_enemy_panel.hide()
	if won:
		_enemy.hide()
	# A farm run is not won or lost, only ended, so it is told what it did rather than how it went.
	if fight.endless:
		_result_label.text = "Run ended"
		_result_detail.text = "%d slain" % fight.kills()
	else:
		_result_label.text = "Success" if won else "Failed"
		_result_detail.text = "The tile is yours" if won else "Out of time"
	_loot_panel.hide()
	if fight.gold > 0:
		_gold_label.text = "+%d" % fight.gold
		_gold_row.show()
	var found_orbs := 0
	for orb: String in fight.orbs:
		found_orbs += int(fight.orbs[orb])
	if found_orbs > 0:
		_orb_label.text = "+1 orb" if found_orbs == 1 else "+%d orbs" % found_orbs
		_orb_label.show()
	if _auto_discarded > 0:
		_auto_label.text = ("1 find discarded automatically" if _auto_discarded == 1
				else "%d finds discarded automatically" % _auto_discarded)
		_auto_label.show()
	# The way out of a run goes with the run. Leaving it standing under the verdict would put two
	# buttons on the screen for the one thing left to do.
	if _terminate != null:
		_terminate.hide()
	_result_drops.fill(_drops)
	_result.show()
	await _centre_result()


## The panel is only as big as what it holds, and what it holds changes when a drop is opened, so it
## is put back in the middle every time -- after a frame, once it knows its new size.
func _centre_result() -> void:
	await get_tree().process_frame
	var size := _result.get_combined_minimum_size() * _ui_scale
	_result.position = (_size() - size) / 2.0


## The loot popup, centred the same way and for the same reason.
func _centre_loot() -> void:
	await get_tree().process_frame
	var size := _loot_panel.get_combined_minimum_size() * _ui_scale
	_loot_panel.position = (_size() - size) / 2.0


func _on_back_pressed() -> void:
	finished.emit(fight.victory)

