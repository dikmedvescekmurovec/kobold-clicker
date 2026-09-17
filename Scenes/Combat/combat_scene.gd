class_name CombatScene
extends CanvasLayer
## Draws one Encounter: the player on the left, the tile's enemies walking in one at a time from the
## right, and a click doing a point of damage to whichever is standing there. When it is over, a
## panel says whether the lineup was beaten and lists what it dropped.
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
## else: a pip an enemy in its tier colour, draining from the left as the enemies go down. A
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
signal gold_gained(amount: float)
## An orb off a body. Re-emitted from `Encounter.orb_dropped` for the reason `gold_gained` is: the
## fight is the one thing downstream listens to. Nothing here can refuse it -- there is no cap and no
## rule that filters currency -- so unlike a find it has no `kept`/`discarded` pair.
signal orb_gained(orb: String)
## A body's experience, re-emitted from `Encounter.xp_dropped` for `gold_gained`'s reason. Emitted the
## moment the body falls, so the ledger is right however the player leaves.
signal xp_gained(amount: int)
## The last gem of one body's experience has reached the character panel. What the panel's bar fills
## on, so it visibly fills as the gems land rather than before they have set off.
signal xp_absorbed(amount: int)

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
## Where a swing re-triggered mid-swing cuts back in: past the wind-up, at the blow. Two frames at
## CombatActor.FPS is 0.2s, so the picture and the sound come back in at the same instant -- move one
## and move the other.
const SWING_RESTART_FRAME := 2
const SWING_RESTART_SECONDS := 0.2

## The bar behind the clock and its fill. The enemy's health is a HealthBar now -- a generated
## sprite frame with a drawn fill -- so the only thing borrowed back from it here is the red, which
## the crit numbers and the end of the clock's ramp are both keyed to.
const BAR_BACK := Color(0.08, 0.07, 0.11, 0.85)
const BAR_HEALTH := HealthBar.FILL
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
## the last stretch. Shares of the clock, not seconds, so a fight with a longer clock than its
## neighbour's -- a settlement's minute -- ambers at the same place in it.
const CLOCK_GREEN := 0.6
const CLOCK_AMBER := 0.3
## The loot counter's face, as the bag fills. It is the brown square the map's corner buttons wear,
## so this is a tint multiplied over that art rather than a colour painted on it: FACE_BROWN is what
## ui_kit.py draws (the base step of `ui_btn_brown_normal`) and FACE_DANGER is the pack's own red, the
## key its danger button is played in -- so an empty bag's counter matches the other square
## buttons and a full one reads as a warning. Gold sits between
## them, and it is a ramp rather than a step at some number of items for the reason the clock ramps:
## it is read out of the corner of an eye, and a reddening counter says go and throw something away
## a good deal earlier than one that changes all at once.
const FACE_BROWN := Color("714c2a")
const FACE_DANGER := Color("c0443a")

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
## Where up the enemy the number starts, as a share of its height. Low on the body, so the whole
## rise is read against the enemy it came off rather than against the sky over it.
const DAMAGE_HEIGHT := 0.45
## The arc everything a body drops is thrown on -- the coins of its purse, the gear off it and the
## orbs. How long the arc takes, how high it goes and how far to either side it may land, all in
## screen pixels. The spread is wider than the damage numbers' because a coin is small and three of
## them landing on one spot reads as one coin.
const THROW_TIME := 0.5
const THROW_RISE := 70.0
const THROW_SPREAD := 90.0
## How long each coin after the first is held back, so a rich body does not throw its whole purse as
## one lump. A find is thrown alone, so it never waits.
const THROW_STAGGER := 0.06
## And what happens after it lands: it lies there for a while and then goes. Something that vanished
## the instant it landed would not be seen at all. The node frees itself at the end of it, so nothing
## piles up on the ground however long a run goes on.
const THROW_FADE := 0.4
const COIN_REST := 0.5
## A find lies there longer than a coin: it is the thing worth looking at, it lands once where a
## purse lands ten, and it is the only sight of it until the player opens the counter.
const FIND_REST := 3.0
## Experience does not lie on the ground: its gems pop out of the body and fly into the character
## panel's bar. How long the pop takes, how high it goes and how far to either side it may land.
const XP_POP_TIME := 0.35
const XP_POP_RISE := 50.0
const XP_POP_SPREAD := 50.0
## How long a gem takes to reach the panel, and the share of that at the end over which it shrinks
## and fades into the bar.
const XP_FLY_TIME := 0.6
const XP_FADE_SHARE := 0.3
## The gem is six pixels; at the panel's own scale it is a speck against a backdrop, so it is drawn
## this many times larger again -- whole numbers only, for the reason `zoom` is.
const XP_GEM_SCALE := 2
const XP_GEM := preload("res://Assets/UI/xp_gem.png")
## The marks on the HUD's square buttons, drawn by tools/ui_kit.py to match the map's bag and skills.
const SACK_ICON := preload("res://Assets/UI/ui_icon_sack.png")
const FLAG_ICON := preload("res://Assets/UI/ui_icon_flag.png")
## How far to either side a find may land. Narrower than the coins' spread, because one sprite has
## nothing to be told apart from and a find belongs by the body that dropped it.
const FIND_SPREAD := 40.0
## The beam standing over a find: the pack's own little flame, turned upright and drawn in the
## rarity's colour, so what came off the body is read without a word on it. A child of the sprite, so
## the arc carries it. Common gets none, the way an ItemSlot rings nothing at common, and neither
## does an orb -- it has no rarity, and borrowing one would say it did.
##
## How big it is drawn against the 16 px the sheet is cut at, how solid, and how far up the icon it
## stands: a beam rises *off* a thing, so its foot is at the piece and its head is over it.
const BEAM_SCALE := 3.0
const BEAM_ALPHA := 0.9
const BEAM_LIFT := 9.0
## What a landed blow does to the body it lands on: a white flash (modulate over 1 brightens), a
## squash on its feet, and how long both take to come back.
const HIT_FLASH := Color(2.5, 2.5, 2.5)
const HIT_SQUASH := Vector2(1.12, 0.88)
const HIT_TIME := 0.12
## How far the arena rattles, in screen pixels: a crit, an ordinary death, and an elite's or a boss's.
## The backdrop is drawn BACKDROP_BLEED larger than the window so a shake never shows its edge.
const SHAKE_CRIT := 4.0
const SHAKE_ELITE := 8.0
const SHAKE_BOSS := 14.0
const BACKDROP_BLEED := 1.05
## How long the game freezes on a kill, by tier. Short: a freeze is felt rather than seen, and a
## ten-kill fight freezes ten times.
const STOP_KILL := 0.04
const STOP_ELITE := 0.08
const STOP_BOSS := 0.15
## The burst a body goes out in.
const DEATH_PIXELS := 28
## A find at ELITE or better slows the fight to STOP_RARE_SPEED for STOP_RARE real seconds, so the
## beam coming up is watched rather than glimpsed.
const STOP_RARE := 0.6
const STOP_RARE_SPEED := 0.25
## A damage number arrives this much larger than it settles, over DAMAGE_POP, and drifts sideways by
## up to DAMAGE_DRIFT as it climbs.
const DAMAGE_POP_SCALE := 1.6
const DAMAGE_POP := 0.12
const DAMAGE_DRIFT := 24.0
## Coins lie for COIN_REST, then fly into the loot counter over COIN_FLY.
const COIN_FLY := 0.45
## How bright the counter flashes as a coin reaches it.
const BUMP_FLASH := Color(1.6, 1.6, 1.6)
## How far the HUD's panels stand off the window edge, in screen pixels.
const HUD_MARGIN := 8.0
## How wide the full-bag warning may run before it wraps, in panel pixels. It is a sentence rather
## than a word, so it is given room to be one.
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
## Where on the screen experience gems fly to -- the character panel's bar, which stands on a layer
## above this one. Negative means nowhere, and the gems fade where they popped.
var xp_target := Vector2(-1, -1)

var _ui_scale := 2.0
## The backdrop and both fighters, which is what a shake rattles -- the HUD stays still over it.
var _arena: Node2D
var _player: CombatActor
var _enemy: CombatActor
## The enemy's own scale, which a squash springs back to, and the tween doing it.
var _enemy_scale := Vector2.ONE
var _enemy_hit: Tween
var _sound: AudioStreamPlayer

var _hud: Control
var _clock: VBoxContainer
var _clock_fill: ColorRect
var _clock_label: Label
var _tally: VBoxContainer
var _pips: KillPips
var _enemy_panel: VBoxContainer
var _enemy_label: Label
var _enemy_bar: HealthBar
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
## How many finds this fight has thrown into the arena -- gear and orbs both. Nothing is drawn from
## it: the sprites free themselves, and what anybody wants to know is whether something was announced
## at all, which is what `test_inventory` asks of an autodiscarded find.
var _finds_shown := 0
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
## The line inside the counter's own panel, while the bag has no room left.
var _warning: Label
## The counter's four faces, one per button state, each a copy of the theme's own box that this
## scene is free to tint. And the fill they are tinted for, so they are only touched when it moves.
var _loot_faces: Array[StyleBox] = []
var _loot_filled := -1.0
## The line under the verdict's drops saying how many the rule threw away.
var _auto_label: Label
## And the one over it saying what the fight earned. Gold is said once, at the end: it is not a find
## to be chosen between, so there is nothing to open and nothing to decide while the fight is on.
## The coin beside it goes with it, so the row is what is shown and hidden.
var _gold_label: Label
var _orb_label: Label
var _gold_row: HBoxContainer
## What the fight earned in experience, the gem and the number, shown beside the purse.
var _xp_label: Label
var _xp_row: HBoxContainer


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
	fight.xp_dropped.connect(_on_xp_dropped)
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
##
## Escape is the fight's own X: the loot popup if it is up, else Terminate on a run, else Back under a
## verdict. A tile fight has no way out but the clock, so there it does nothing.
func _unhandled_input(event: InputEvent) -> void:
	if fight != null and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _loot_panel.visible:
			_on_loot_closed()
		elif fight.finished:
			_on_back_pressed()
		elif fight.endless:
			_on_terminate_pressed()
		return
	if fight == null or fight.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		_swing()
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
	_arena = arena

	var art := backdrop_for(fight.env if fight != null else "", area_variant, area_layout)
	var backdrop := Sprite2D.new()
	backdrop.texture = art
	backdrop.centered = false
	# Cover the viewport whatever its shape; the ground band stays across the bottom.
	# A little over, so a shake never shows the edge.
	var cover := maxf(view.x / art.get_width(), view.y / art.get_height()) * BACKDROP_BLEED
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
	# of pips draining as the enemies go down, and the clock under it. The
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
	# As many pips as this fight has enemies -- fifteen on a settlement tile, ten on open land -- or,
	# for a run, the cycle it repeats between elites.
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
	# The number under its own bar, so the two bars stay next to each other and the clock still
	# reads as one thing rather than a number wedged between them.
	_clock_label = _hud_label("", BAR_TIME)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_child(_clock_label)

	# Bottom right: what the run has turned up. It is a Control standing in the arena, so it eats the
	# click that lands on it rather than letting it through as a swing -- which is what is wanted
	# here, and exactly why the main scene hides its own corner button while a fight is on.
	_loot_button = _square_button(SACK_ICON)
	_loot_button.scale = Vector2(_ui_scale, _ui_scale)
	_loot_button.tooltip_text = "What this run has turned up"
	_loot_button.pressed.connect(_on_loot_pressed)
	# Its face is the whole of what the HUD says about how full the bag is. A copy of the theme's own
	# box per state, tinted rather than repainted, so the bevel stays the pack's and only its colour
	# moves -- and the tint lands on the box alone, so the newest find's icon and the count beside it
	# keep their own colours.
	for state: String in UITheme.STATES:
		var face: StyleBox = UITheme.theme().get_stylebox(state, "BrownIconButton").duplicate()
		_loot_faces.append(face)
		_loot_button.add_theme_stylebox_override(state, face)
	hud.add_child(_loot_button)
	_refresh_loot_button()
	_tint_loot_button()

	# Leaving a farm run. Up in the top-right corner: the player is clicking hard and fast at the
	# enemy in the middle of the screen, and the button that ends the run has to be somewhere a stray
	# one cannot reach -- which is now a corner rather than the bottom middle, that being where the
	# enemy's health went.
	if fight.endless:
		_terminate = _square_button(FLAG_ICON)
		_terminate.scale = Vector2(_ui_scale, _ui_scale)
		_terminate.tooltip_text = "End the run and keep everything it turned up"
		_terminate.pressed.connect(_on_terminate_pressed)
		hud.add_child(_terminate)

	# Centred on the bottom edge: the enemy's name and health, standing on the arena with no panel
	# behind them -- the same as the place's name and the clock on the top edge, and for the same
	# reason. These are what the player watches; a panel only puts furniture round them. So the name
	# is written the way that one is, in bone with the dark outline that is what carries a word over a
	# snowfield or a noon desert, and the bar brings its own border already.
	_enemy_panel = VBoxContainer.new()
	_enemy_panel.scale = Vector2(_ui_scale, _ui_scale)
	_enemy_panel.add_theme_constant_override("separation", 2)
	hud.add_child(_enemy_panel)
	_enemy_label = _hud_label("", Palette.BONE)
	_enemy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_panel.add_child(_enemy_label)
	# The frame this wears is the enemy's tier, so it changes as the lineup walks in. It is wider for
	# an elite and wider still for a boss, which the column simply grows to hold -- _place_corners
	# centres it and has no opinion about how wide it is.
	_enemy_bar = HealthBar.new()
	_enemy_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enemy_panel.add_child(_enemy_bar)

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
	# The experience beside the purse, in the same row: both are sums, and both are never nothing.
	_xp_row = HBoxContainer.new()
	_xp_row.add_theme_constant_override("separation", 6)
	_xp_row.hide()
	_gold_row.add_child(_xp_row)
	var gem := TextureRect.new()
	gem.texture = XP_GEM
	gem.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gem.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gem.custom_minimum_size = Vector2(XP_GEM.get_width(), XP_GEM.get_height()) * XP_GEM_SCALE
	_xp_row.add_child(gem)
	_xp_label = _label("")
	_xp_row.add_child(_xp_label)
	# What the run turned up in currency, as a count. Which orbs is what the tray in the bag is for,
	# and each was seen falling out of the body that carried it; a verdict wants the score.
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
	var back := UITheme.back_button("Back to the map")
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	# What the counter's reddening face means, in words, in the one place the player has already
	# asked what the run is carrying -- and over the list rather than under it, because it is about
	# the whole of it. Here rather than out in the arena because this is where something can be done
	# about it: every square below carries a Discard.
	_warning = ItemDetails.line(
			"Bag full -- the worst finds will be destroyed", Palette.RUST, WARNING_WIDTH)
	_warning.hide()
	found.add_child(_warning)
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


## A brown square with a cream mark, the same button as the map's bag and skills. The loot counter
## also writes its count on it, so the words are cream to match the mark.
func _square_button(icon: Texture2D) -> Button:
	var button := Button.new()
	button.theme_type_variation = "BrownIconButton"
	button.icon = icon
	button.expand_icon = false
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(item, Palette.PANEL_CREAM)
	button.add_theme_color_override("font_disabled_color", Palette.STONE_LT)
	return button


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
func _on_hit_landed(amount: float, crit: bool, automatic: bool) -> void:
	if automatic:
		_swing()
	_show_damage(amount, crit)
	_jolt_enemy()
	if crit:
		Juice.shake(_arena, SHAKE_CRIT)


## The body taking a blow: a white flash and a squash onto its feet, both springing back. A blow
## landing mid-jolt starts it over rather than stacking on it.
func _jolt_enemy() -> void:
	if _enemy_hit != null and _enemy_hit.is_valid():
		_enemy_hit.kill()
	_enemy.modulate = HIT_FLASH
	_enemy.scale = _enemy_scale * HIT_SQUASH
	_enemy_hit = create_tween().set_parallel(true)
	_enemy_hit.tween_property(_enemy, "modulate", Color.WHITE, HIT_TIME)
	_enemy_hit.tween_property(_enemy, "scale", _enemy_scale, HIT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The player swinging, whether they clicked for it or the weapon did it for them. A swing landing on
## top of one still running does not start over from the wind-up -- it cuts back in at the blow, so
## clicking faster than the animation reads as a run of blows rather than as a stuck first frame.
## One decision serves both halves: the animation's state is what the sound's offset is read from, so
## the two can never disagree about whether this is a fresh swing.
func _swing() -> void:
	var again := _player.is_playing() and _player.animation == "attack"
	_player.play_once("attack", SWING_RESTART_FRAME)
	_sound.play(SWING_RESTART_SECONDS if again else 0.0)


## The number that floats off the enemy. This is the only place the player can read what their gear
## is worth: everything else about a hit looks the same whether it took one point off or nine.
func _show_damage(amount: float, crit: bool) -> void:
	var written := BigNumber.format(amount)
	var label := _label((written + "!") if crit else written)
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
	# Pops in large about its own middle and settles, which is what makes a number land rather than
	# appear. The pivot is in the label's own unscaled pixels, and scaling about it moves the corner,
	# so `from` is shifted back by what the settled scale would move it.
	var font_size := CRIT_FONT if crit else DAMAGE_FONT
	label.pivot_offset = Vector2(width / _ui_scale, font_size) / 2.0
	from += label.pivot_offset * (_ui_scale - 1.0)
	label.position = from
	label.scale = Vector2(_ui_scale, _ui_scale) * DAMAGE_POP_SCALE * (1.25 if crit else 1.0)
	var float_up := create_tween()
	float_up.set_parallel(true)
	float_up.tween_property(label, "scale", Vector2(_ui_scale, _ui_scale), DAMAGE_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drift := randf_range(-DAMAGE_DRIFT, DAMAGE_DRIFT)
	float_up.tween_property(label, "position", from + Vector2(drift, -DAMAGE_RISE), DAMAGE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_up.tween_property(label, "modulate:a", 0.0, DAMAGE_TIME).set_ease(Tween.EASE_IN)
	float_up.chain().tween_callback(label.queue_free)


## Where a body's droppings come from: the middle of the enemy standing there. Rather than ENEMY_X
## the way a damage number is, because a drop lands the same frame the enemy dies and so comes off
## the thing the player just killed. The walked-in position is the fallback for the case where there
## is no sprite -- a fight the tests drive with nobody on the field.
func _drop_origin() -> Vector2:
	var view := _size()
	if _enemy != null and _enemy.sprite_frames != null:
		return _enemy.position - Vector2(0, _enemy.drawn_size().y * 0.5)
	return Vector2(view.x * ENEMY_X, view.y * (GROUND - ACTOR_HEIGHT * DAMAGE_HEIGHT))


## Throws one thing out of the body: an arc onto the ground, a rest where it landed, and a fade.
## Written once because everything a body drops is thrown the same way -- the coins of its purse, the
## gear off it and the orbs -- which is the whole of this change: a kill's takings land in the arena
## rather than being announced in a corner.
##
## `index` is which of a burst this is, so a rich body does not throw its whole purse as one lump;
## `spread` is how far to either side it may land and `rest` how long it lies there.
##
## `collect` is called after the rest instead of the fade, for something that goes somewhere rather
## than lying there -- the coins, which fly into the counter.
func _throw(node: Node2D, index: int, from: Vector2, spread: float, rest: float,
		collect := Callable()) -> void:
	node.z_index = 1
	node.scale = Vector2(_ui_scale, _ui_scale)
	node.position = from
	add_child(node)
	var to := from.x + randf_range(-spread, spread)
	var top := from.y - THROW_RISE
	# An arc, not a rise: across at a steady rate while the height goes up and comes back down.
	# Two hops on y rather than one tween of the whole position, which is what makes it a jump
	# rather than a slide.
	# The hold-back is a delay on each of the three rather than an interval in front of them,
	# because they all run together and a parallel tween's steps are timed from its own start.
	var delay := index * THROW_STAGGER
	var arc := create_tween()
	arc.set_parallel(true)
	arc.tween_property(node, "position:x", to, THROW_TIME).set_delay(delay)
	arc.tween_property(node, "position:y", top, THROW_TIME / 2.0) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(node, "position:y", _size().y * GROUND, THROW_TIME / 2.0) \
			.set_delay(delay + THROW_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# It lies where it fell and then goes.
	arc.chain().tween_interval(rest)
	arc.set_parallel(false)
	if collect.is_valid():
		arc.tween_callback(collect.bind(node))
		return
	arc.tween_property(node, "modulate:a", 0.0, THROW_FADE)
	arc.tween_callback(node.queue_free)


## A coin that has lain its moment flies into the loot counter, gathering speed and shrinking, and
## the counter flashes as it lands.
func _collect_coin(coin: Node2D) -> void:
	var into := _loot_button.position + _loot_button.size * _ui_scale / 2.0
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(coin, "position", into, COIN_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(coin, "scale", coin.scale * 0.5, COIN_FLY)
	fly.chain().tween_callback(coin.queue_free)
	fly.tween_callback(_bump_counter)


## A brightening rather than a swell: `_place_corners` pins the counter by its top-left corner every
## frame, and scaling it about its middle would walk it off the corner.
func _bump_counter() -> void:
	_loot_button.modulate = BUMP_FLASH
	create_tween().tween_property(_loot_button, "modulate", Color.WHITE, HIT_TIME * 2.0)


## The purse coming off a body, as coins thrown out of it. `Coins.count_for` decides how many, so a
## richer body visibly pays more without the arena filling up -- the count is the log of the amount,
## not the amount. They are the only thing thrown that spins: a coin is drawn turning and gear is not.
func _show_coins(amount: float) -> void:
	var from := _drop_origin()
	for i in Coins.count_for(amount):
		var coin := AnimatedSprite2D.new()
		coin.sprite_frames = Coins.frames()
		coin.play("spin")
		_throw(coin, i, from, THROW_SPREAD, COIN_REST, _collect_coin)


## A body's experience, as gems that pop out of it and fly into the character panel. As many as a
## purse of the same size throws coins, for the same reason. `xp_absorbed` goes out with the last one
## to arrive, carrying the whole amount, so the bar takes it in one step as the burst lands.
func _show_xp(amount: int) -> void:
	var from := _drop_origin()
	var count := Coins.count_for(amount)
	for i in count:
		var gem := Sprite2D.new()
		gem.texture = XP_GEM
		gem.z_index = 1
		gem.scale = Vector2.ONE * _ui_scale * XP_GEM_SCALE
		gem.position = from
		add_child(gem)
		var landed := Vector2(from.x + randf_range(-XP_POP_SPREAD, XP_POP_SPREAD), from.y)
		var tween := create_tween()
		tween.tween_interval(i * THROW_STAGGER)
		# Up and out, the first half of a throw -- a gem never comes back down.
		tween.set_parallel(true)
		tween.tween_property(gem, "position:x", landed.x, XP_POP_TIME)
		tween.tween_property(gem, "position:y", from.y - XP_POP_RISE, XP_POP_TIME) 				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.set_parallel(false)
		if xp_target.x >= 0.0:
			# Then into the bar, gathering speed, shrinking and fading over the last stretch.
			var fade := XP_FLY_TIME * XP_FADE_SHARE
			tween.tween_property(gem, "position", xp_target, XP_FLY_TIME) 					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(gem, "scale", gem.scale * 0.5, fade) 					.set_delay(XP_FLY_TIME - fade)
			tween.parallel().tween_property(gem, "modulate:a", 0.0, fade).set_delay(XP_FLY_TIME - fade)
		else:
			tween.tween_property(gem, "modulate:a", 0.0, THROW_FADE)
		if i == count - 1:
			tween.tween_callback(func() -> void: xp_absorbed.emit(amount))
		tween.tween_callback(gem.queue_free)


## A find coming off a body: its own icon, thrown the way the purse is, with the rarity's beam
## standing over it. A transparent `glow` means no beam -- a common piece and an orb are drawn plain.
##
## No name on it. What a find *is* is read in the counter and its list, where there is room for the
## word and time to read it; what the arena has to say is that the body left something, and the
## picture says that the moment it lands.
func _show_find(picture: Texture2D, glow: Color) -> void:
	_finds_shown += 1
	var find := Sprite2D.new()
	find.texture = picture
	if glow.a > 0.0:
		var beam := LootBeam.make(glow, BEAM_ALPHA, BEAM_SCALE)
		beam.position = Vector2(0, -BEAM_LIFT)
		find.add_child(beam)
	_throw(find, 0, _drop_origin(), FIND_SPREAD, FIND_REST)


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
func _on_enemy_coming(_index: int, enemy_name: String, _hp: float) -> void:
	if enemy_name.is_empty():
		_enemy.hide()
		return
	var view := _size()
	_enemy.show()
	var band: float = SIZE_HEIGHT[EnemyRoster.size_of(enemy_name)]
	var elite := ELITE_SCALE if fight.on_elite() else 1.0
	if _enemy_hit != null and _enemy_hit.is_valid():
		_enemy_hit.kill()
	_enemy.modulate = Color.WHITE
	_enemy.setup_enemy(enemy_name, view.y * ACTOR_HEIGHT * band * elite)
	_enemy_scale = _enemy.scale
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
		var share := clampf(fight.time_left / fight.seconds, 0.0, 1.0)
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
	var share := fight.hp / maxf(fight.enemy_max_hp(), 1.0)
	# Encounter.tier_in rather than on_elite(): the pips beside this bar colour themselves through the
	# same call, so the frame over the enemy and the pip standing for it can never disagree.
	_enemy_bar.show_health(Encounter.tier_in(fight, fight.index), maxf(share, 0.0))


func _on_enemy_spawned(_index: int, _enemy_name: String, _hp: float) -> void:
	_enemy.play("idle")
	_slide_enemy()


func _on_enemy_hit(hp_left: float) -> void:
	if hp_left > 0:
		_enemy.play_once("hurt")


## A body going down: it bursts in its own colour, and the game holds its breath for a moment --
## longer, and with the arena rattling, the bigger the thing that fell.
func _on_enemy_died(index: int) -> void:
	_enemy.play_once("death")
	var burst := Juice.burst(self, _drop_origin(), _enemy.tint(), DEATH_PIXELS, 220.0,
			3.0 * _ui_scale, 0.6, 500.0)
	burst.z_index = 1
	match Encounter.tier_in(fight, index):
		EnemyRoster.Tier.BOSS:
			Juice.shake(_arena, SHAKE_BOSS, 0.4)
			Juice.hit_stop(get_tree(), STOP_BOSS)
		EnemyRoster.Tier.ELITE:
			Juice.shake(_arena, SHAKE_ELITE, 0.3)
			Juice.hit_stop(get_tree(), STOP_ELITE)
		_:
			Juice.hit_stop(get_tree(), STOP_KILL)


## The one place a find is looked at. A level the player is done with is counted and passed on to
## whoever is keeping the elite promise, and that is all that happens to it: it does not join
## `_drops`, does not move the counter, is never thrown into the arena and appears in neither list.
## Everything else goes on exactly as it did, and leaves by `loot_kept`.
func _on_loot_dropped(index: int, item: Item) -> void:
	if autodiscard.is_valid() and bool(autodiscard.call(item.level)):
		_auto_discarded += 1
		loot_discarded.emit(index, item)
		return
	_drops.append(item)
	_refresh_loot_button()
	if _loot_panel.visible:
		_loot_drops.fill(_drops)
	# Common is thrown plain, the way an ItemSlot rings nothing at common: a glow means "this one is
	# worth stopping for", and one on everything would mean nothing.
	#
	# The ring's colour rather than the text's. They are the two halves of the same ramp and the
	# choice between them is what is behind the colour: the text half was picked to be read on the
	# bone panel, and a find is thrown against a snowfield or a noon desert, which is exactly what the
	# square's border colour was picked for.
	_show_find(item.icon(), Color.TRANSPARENT if item.rarity == ItemRarity.Rarity.COMMON
			else ItemRarity.BORDER_COLORS[item.rarity])
	# The best finds slow the fight, so the beam coming up is watched rather than glimpsed.
	if item.rarity >= ItemRarity.Rarity.ELITE:
		Juice.hit_stop(get_tree(), STOP_RARE, STOP_RARE_SPEED)
	loot_kept.emit(index, item)


## A body's purse: coins out of it, and the amount on to whoever is keeping the ledger. The running
## total still lives on the Encounter and the verdict still reads it at the end -- what the coins say
## is that something was earned here, which is the half of it a number at the end of the fight cannot
## tell the player while they are fighting.
func _on_gold_dropped(_index: int, amount: float) -> void:
	_show_coins(amount)
	gold_gained.emit(amount)


## A body's experience: gems off it, and the amount on to the ledger straight away.
func _on_xp_dropped(_index: int, amount: int) -> void:
	_show_xp(amount)
	xp_gained.emit(amount)


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
## Green through gold to red as the bag fills, the way the clock ramps as it runs out. Nobody having
## said (`bag_room` at -1) is an empty bag: a fight with no bag behind it has nothing to warn about.
func _tint_loot_button() -> void:
	var fill := 0.0 if bag_room < 0 else clampf(1.0 - float(bag_room) / Inventory.CAPACITY, 0.0, 1.0)
	if is_equal_approx(fill, _loot_filled):
		return
	_loot_filled = fill
	var want := (FACE_BROWN.lerp(Palette.GOLD, fill / 0.5) if fill <= 0.5
			else Palette.GOLD.lerp(FACE_DANGER, (fill - 0.5) / 0.5))
	# A tint multiplies, so what the boxes are given is the colour wanted divided by the colour the
	# pack drew -- worked out that way round so the constants above are the colours that are seen.
	var tint := Color(want.r / FACE_BROWN.r, want.g / FACE_BROWN.g, want.b / FACE_BROWN.b)
	for face: StyleBox in _loot_faces:
		(face as StyleBoxTexture).modulate_color = tint


## The full-bag line inside the counter's panel. Flipped through here rather than set straight,
## because it changes the panel's height and the panel is centred on what it holds.
func _show_warning(showing: bool) -> void:
	if _warning.visible == showing:
		return
	_warning.visible = showing
	if _loot_panel.visible:
		_centre_loot()


func _refresh_loot_button() -> void:
	_loot_button.text = str(_drops.size())
	_loot_button.disabled = _drops.is_empty()


## Puts the HUD's corners where they belong. Done every frame rather than anchored, because every
## one of them is scaled by `_ui_scale` and an anchor knows nothing about that.
func _place_corners(view: Vector2) -> void:
	# The clock and the pips stand in the middle of the top edge. Placed here rather than anchored
	# for the same reason as the rest: the column is scaled by _ui_scale and an anchor knows nothing
	# about that.
	var tally := _tally.get_combined_minimum_size() * _ui_scale
	_tally.position = Vector2((view.x - tally.x) / 2.0, HUD_MARGIN)
	# The enemy's nameplate centred on the bottom edge, under the fight rather than in it: the health
	# of whatever is standing there is the one thing read continuously, and the middle of the bottom
	# edge is where the eye is already going -- it is directly under the pip bar and the clock, so the
	# whole of how the fight is going reads down one column. Centred rather than aligned to an edge
	# because an elite's brackets and a boss's crown widen the panel, and growing it evenly either
	# side keeps the channel where it was, which is what HealthBar's own TROUGH is for.
	var plate := _enemy_panel.get_combined_minimum_size() * _ui_scale
	_enemy_panel.position = Vector2((view.x - plate.x) / 2.0, view.y - plate.y - HUD_MARGIN)
	# The counter in the bottom right, out at the corner so the nameplate has the middle.
	var loot := _loot_button.get_combined_minimum_size() * _ui_scale
	_loot_button.position = Vector2(view.x - loot.x - HUD_MARGIN, view.y - loot.y - HUD_MARGIN)
	_tint_loot_button()
	_show_warning(bag_room == 0)
	if _terminate != null:
		var leave := _terminate.get_combined_minimum_size() * _ui_scale
		_terminate.position = Vector2(view.x - leave.x - HUD_MARGIN, HUD_MARGIN)


## An orb off a body, thrown out of it the way a find is. Plain, with no glow: an orb has no rarity,
## and borrowing a colour from that ramp would say it did.
func _on_orb_dropped(_index: int, orb: String) -> void:
	_show_find(OrbTable.icon(orb), Color.TRANSPARENT)
	orb_gained.emit(orb)


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
	if fight.gold > 0.0:
		_gold_label.text = "+%s" % BigNumber.format(fight.gold)
		_gold_row.show()
	if fight.xp > 0:
		_xp_label.text = "+%s" % BigNumber.format(fight.xp)
		_xp_row.show()
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

