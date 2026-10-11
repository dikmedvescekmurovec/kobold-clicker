class_name CombatScene
extends CanvasLayer
## The view of one Encounter: the backdrop, the player on the left, the tile's enemies walking in one at
## a time from the right, and what a blow and a body throw up. Everything on a panel or a button -- the
## place, the pips, the clock, the nameplate, the loot counter, its popup, the verdict -- is `hud`
## (`FightHud`). It owns no rules: it asks the Encounter what is happening and shows it. Everything is
## built in code, so the .tscn stays a stub.

signal finished(won: bool)
## Retry under a lost verdict: leave as `finished(false)` would, and open the same tile's fight again.
signal retry
## What the rest of the game hears in place of `Encounter.loot_dropped`: the autodiscard rule is applied
## here and nowhere else (`_on_loot_dropped`).
signal loot_kept(index: int, item: Item)
## A find the player's own rule threw away on sight, for whoever keeps the ledger -- a piece left behind
## still spends the promised Broken Sword. Never drawn.
signal loot_discarded(index: int, item: Item)
## `Encounter`'s `gold_dropped`, `orb_dropped`, `rune_dropped` and `xp_dropped`, re-emitted for
## `loot_kept`'s reason: the fight is the one thing downstream listens to. Each goes out as the body
## falls, so the ledger is right however the player leaves; the dungeon has no ledger, so a rune is the
## main scene's to put away.
signal gold_gained(amount: float)
signal orb_gained(orb: String)
signal rune_gained(rune: String)
signal xp_gained(amount: int)
## The last gem of one body's experience has reached the character panel, carrying the whole amount:
## what the panel's bar fills on.
signal xp_absorbed(amount: int)

## Where the fighters stand, as shares of the viewport; an enemy starts its run-in at `OFFSCREEN_X`.
## Anything placed on the ground asks `_ground()`, never `GROUND`.
const GROUND := 0.86
const PLAYER_X := 0.24
const ENEMY_X := 0.72
const OFFSCREEN_X := 1.15
## How tall an ordinary fighter stands, as a share of the viewport's height, and never more than
## `ACTOR_WIDE` of its width, so on a window held upright the two stay apart. Sheets vary wildly, so
## nobody is drawn at their sheet's scale.
const ACTOR_HEIGHT := 0.33
const ACTOR_WIDE := 0.3
## What each size band is worth against that.
const SIZE_HEIGHT := {
	EnemyRoster.Size.TINY: 0.45,
	EnemyRoster.Size.SMALL: 0.80,
	EnemyRoster.Size.MEDIUM: 1.00,
	EnemyRoster.Size.LARGE: 1.25,
	EnemyRoster.Size.HUGE: 1.55,
}
## How far the fighters are pulled toward the light they stand in (a multiply, so a little goes a long
## way): the sky's (`SKY_LIGHT`), or down the dungeon `CAVE_HAZE`.
const SCENE_LIGHT := 0.4
const CAVE_HAZE := Color("8a7fa0")

## A place's backdrop is layers on the fighters' 384x216 grid (`AI-sprites-generator/sideview.py`,
## `backdrop_layers`). The ground: one per environment, variant and layout, its strip's top where
## `GROUND` puts the fighters' feet.
const AREA_PATH := "res://Assets/Area/%s_%s_%d.png"
## Environment, layout, band (1 the farthest): the same under every variant of a layout. As many bands
## as there are files.
const LAND_PATH := "res://Assets/Area/land/%s_%d_%d.png"
const SKY_PATH := "res://Assets/Area/sky/%s.png"
## The hour (the player's own, 0-23) each sky comes up at. Before the first, it is still the last.
const SKY_HOURS := [[5, "morning"], [10, "noon"], [14, "alpine"], [17, "golden"], [19, "twilight"],
		[21, "night"]]
## What each sky's light does to the land under it: a multiply on every layer but the sky's own. Must
## agree with `sideview.LIGHT`.
const SKY_LIGHT := {
	"morning": Color.WHITE,
	"noon": Color.WHITE,
	"alpine": Color.WHITE,
	"golden": Color(1.0, 0.86, 0.74),
	"twilight": Color(0.74, 0.68, 0.9),
	"night": Color(0.45, 0.52, 0.72),
}
## The land's farthest and nearest bands' shares of the ground's pace. Must agree with `sideview.speeds`.
const BAND_SLOWEST := 0.2
const BAND_FASTEST := 0.6
## How many ways each place was drawn. Must agree with `sideview.LAYOUTS`; `_test_backdrops` sweeps
## every path to hold it. Changing it only re-rolls which backdrop a tile fights on: nothing is saved
## about the one it had.
const AREA_LAYOUTS := 4
const AREA_FALLBACK := "res://Assets/Area/grass_plain_1.png"
## The cave's layers (`tools/cave_dungeon.py`), numbered from the nearest: 1 stands in front of the
## fighters and 7 is the flat dark behind everything.
const CAVE_PATH := "res://Assets/Area/cave/%d.png"
const CAVE_NEAREST := 1
const CAVE_FARTHEST := 7
## The cave's floor lies lower than a backdrop's grass band: at `GROUND` everyone floated.
const CAVE_GROUND := 0.915
## Held upright (`UITheme.narrow`) the fight stands this far down the window rather than at its foot:
## every layer is lifted to put it there (`_lift`), its own bottom `UNDERFOOT_ROWS` repeating under it to
## the window's foot (`_underfoot`), and the nameplate stands under the feet (`FightHud.PLATE_UNDER`).
const GROUND_UPRIGHT := 0.6
const UNDERFOOT_ROWS := 16
## Backdrop pixels a second the ground (or the cave's nearest rock) slides while the hero walks on to
## the next enemy. Each layer behind it goes slower and the farthest not at all.
const WALK_SPEED := 90.0
## The backdrop is drawn this much larger than the window, so a shake never shows its edge.
const BACKDROP_BLEED := 1.05

## The frame a swing re-triggered mid-swing cuts back in at: past the wind-up, at the blow (`_swing`).
const SWING_RESTART_FRAME := 2
## A landed blow on the body: a white flash (modulate over 1 brightens) and a squash on its feet, both
## back over `HIT_TIME`.
const HIT_FLASH := Color(2.5, 2.5, 2.5)
const HIT_SQUASH := Vector2(1.12, 0.88)
const HIT_TIME := 0.12
## The player's hop on a swing, in screen pixels and seconds: a click that re-triggers a swing
## mid-animation would otherwise show nothing at all when it is spammed.
const SWING_HOP := 6.0
const SWING_HOP_TIME := 0.16
## How far the arena rattles, in screen pixels: a crit, an elite's death, a boss's.
const SHAKE_CRIT := 4.0
const SHAKE_ELITE := 8.0
const SHAKE_BOSS := 14.0
## Seconds the game freezes on a kill, by tier. Short: a ten-kill fight freezes ten times.
const STOP_KILL := 0.04
const STOP_ELITE := 0.08
const STOP_BOSS := 0.15
## The burst a body goes out in.
const DEATH_PIXELS := 28
## A find at ELITE slows the fight to `STOP_RARE_SPEED` for `STOP_RARE` real seconds, so the beam coming
## up is watched; a unique slows it further and for longer, then eases back over `STOP_UNIQUE_EASE`.
const STOP_RARE := 0.6
const STOP_RARE_SPEED := 0.25
const STOP_UNIQUE := 1.6
const STOP_UNIQUE_SPEED := 0.1
const STOP_UNIQUE_EASE := 0.8
## How long a won verdict stands before `auto_collect` leaves it.
const AUTO_COLLECT_SECONDS := 1.5

## The number that floats off a hit: the seconds it lives, the screen pixels it climbs and may start to
## either side of the enemy, and its font. Pixellari is clean only at whole multiples of its native 16,
## so a hit is 2x and a crit 3x.
const DAMAGE_TIME := 0.7
const DAMAGE_RISE := 40.0
const DAMAGE_SPREAD := 28.0
const DAMAGE_FONT := 32
const CRIT_FONT := 48
## It arrives this much larger than it settles, over `DAMAGE_POP`, and drifts sideways by up to
## `DAMAGE_DRIFT` as it climbs.
const DAMAGE_POP_SCALE := 1.6
const DAMAGE_POP := 0.12
const DAMAGE_DRIFT := 24.0
## The damage red and not `Palette.GOLD`: gold is the unique item step and reads as a reward.
const CRIT_COLOR := FightHud.BAR_HEALTH
## Where up a fighter a number starts, as a share of its height: low on the enemy, so the whole rise is
## read against the body it came off; over the hero's head for what a blow did to the clock.
const DAMAGE_HEIGHT := 0.45
const STRUCK_HEIGHT := 1.05

## The arc everything a body drops is thrown on: the seconds it takes, and the screen pixels it rises
## and may land to either side -- wider than a number's spread, because three coins landing on one spot
## read as one.
const THROW_TIME := 0.5
const THROW_RISE := 70.0
const THROW_SPREAD := 90.0
## A find lands nearer the body that dropped it than a coin may.
const FIND_SPREAD := 40.0
## How long each of a burst after the first is held back, so a rich body does not throw its purse as
## one lump.
const THROW_STAGGER := 0.06
## What landed lies there -- a coin `COIN_REST`, a find `FIND_REST`, it being the thing worth looking at
## -- then flies into the loot counter over `COIN_FLY`, or with nowhere to go fades over `THROW_FADE`.
const COIN_REST := 0.5
const FIND_REST := 3.0
const COIN_FLY := 0.45
const THROW_FADE := 0.4
## The meta a thrown piece keeps its throw's tween under, so a pick-up can cut it short.
const THROWN := &"thrown"
## How big a find is drawn by rarity; a good orb at the rarity its beam borrows, and a plain one (`-1`)
## as uncommon. The rarer is also drawn over the commoner (`_show_find`'s `z_index`).
const FIND_SIZE := {
	-1: 1.0,
	ItemRarity.Rarity.COMMON: 0.85,
	ItemRarity.Rarity.UNCOMMON: 1.0,
	ItemRarity.Rarity.RARE: 1.2,
	ItemRarity.Rarity.ELITE: 1.4,
	ItemRarity.Rarity.UNIQUE: 1.75,
}
## Experience does not lie on the ground: its gems pop out of the body -- how long that takes, how high
## and how far to either side -- and fly to `xp_target` over `XP_FLY_TIME`, shrinking and fading over
## the last `XP_FADE_SHARE` of it.
const XP_POP_TIME := 0.35
const XP_POP_RISE := 50.0
const XP_POP_SPREAD := 50.0
const XP_FLY_TIME := 0.6
const XP_FADE_SHARE := 0.3
## The gem is six pixels, so it is drawn this many times larger than the panel's own scale; a whole
## number.
const XP_GEM_SCALE := 2
const XP_GEM := preload("res://Assets/UI/xp_gem.png")

var fight: Encounter
## Everything that stands over the arena. Made with the scene and not in `begin`, so the main scene
## can set it up first (`hud_top`, `bag_room`, `panel_up`); `begin` builds it.
var hud := FightHud.new()
## The cell being fought for, so the main scene knows what was won.
var cell: Vector2i
## What names the backdrop beside the encounter's environment: what the world put on the cell ("plain",
## "road", "village", "town" or "fortress"), which of that place's layouts, and which sky
## (`SKY_LIGHT`'s names). `begin` sets all three.
var area_variant := "plain"
var area_layout := 1
var area_sky := "morning"

# The main scene's.
## What the map named this place, for the HUD's heading. Set before `begin`, as `weapon_kind` and
## `autodiscard` are. Empty (the tests, the screenshot scripts) says the level alone.
var place := ""
## The kind of weapon the hero swings (`LootTable.KINDS`), "" bare-handed.
var weapon_kind := ""
## Which hero the player is (`Characters`), set before `begin` as `weapon_kind` is.
var character := Characters.FIRST
## Asked of each find: whether the player has told the game to leave it behind
## (`Inventory.leaves_behind`). Unset keeps everything.
var autodiscard := Callable()
## Asked as Escape is pressed: whether a page of the main scene's (the bag) stands over the fight. The
## key is then the page's, never Terminate.
var page_up := Callable()
## Whether a won tile fight takes its loot and leaves by itself, `AUTO_COLLECT_SECONDS` after its
## verdict is up, as Collect would: while the Nightwalkers are worn or distant charting is open (the
## fourth wall's, the user's 2026-10-09).
var auto_collect := false
## Where on the screen experience gems fly to: the character panel's bar, on a layer above this one.
## Negative means nowhere, and the gems fade where they popped.
var xp_target := Vector2(-1, -1)

var _ui_scale := 2.0
## One of the backdrop's pixels, in screen pixels: what the fighters' scale is snapped to (`_snap`).
var _pixel := 0.0
## The backdrop and both fighters, which is what a shake rattles -- the HUD stays still over it.
var _arena: Node2D
## The backdrop's layers from the back, and the share of `WALK_SPEED` each slides at.
var _layers: Array[Sprite2D] = []
var _rates: Array[float] = []
## What the bodies have thrown, lying on the ground or still in the air on its way there (`_throw`,
## `_scroll`).
var _ground_drops: Node2D
var _player: CombatActor
var _enemy: CombatActor
## The enemy's own scale, which a squash springs back to, and the tween doing it.
var _enemy_scale := Vector2.ONE
var _enemy_hit: Tween
## What the enemy out now was stood up as (`_on_enemy_coming`): its size band's share of a fighter's
## height and whether it is an elite, for standing it up again when the window changes (`_layout`).
var _enemy_band := 1.0
var _enemy_elite := false
var _hop: Tween
var _sounds: FightSounds
## How many finds the player's rule threw away. Said once, under the verdict, and never drawn.
var _auto_discarded := 0
## How many finds this fight has thrown into the arena -- gear and orbs both. Nothing is drawn from it:
## it is how the tests ask whether a find was announced at all.
var _finds_shown := 0


func _init() -> void:
	add_child(hud)


## Starts the fight for `cell`. `ui_scale` matches the map's; `variant` is what the world put on the
## tile, `layout` 0 is the cell's own and `sky` "" the clock's.
func begin(encounter: Encounter, for_cell: Vector2i, ui_scale: float, variant := "plain",
		layout := 0, sky := "") -> void:
	fight = encounter
	# No Control lies over the arena, so the cursor there is the default one: a press is a swing.
	Input.set_default_cursor_shape(Cursors.SWORD)
	cell = for_cell
	area_variant = variant
	area_layout = layout if layout > 0 else layout_for(for_cell)
	area_sky = sky if SKY_LIGHT.has(sky) else sky_at(Time.get_datetime_dict_from_system().hour)
	_ui_scale = ui_scale
	fight.enemy_coming.connect(_on_enemy_coming)
	fight.enemy_spawned.connect(_on_enemy_spawned)
	fight.enemy_hit.connect(_on_enemy_hit)
	fight.hit_landed.connect(_on_hit_landed)
	fight.player_hit.connect(_on_player_hit)
	fight.enemy_died.connect(_on_enemy_died)
	fight.loot_dropped.connect(_on_loot_dropped)
	fight.gold_dropped.connect(_on_gold_dropped)
	fight.orb_dropped.connect(_on_orb_dropped)
	fight.rune_dropped.connect(_on_rune_dropped)
	fight.xp_dropped.connect(_on_xp_dropped)
	fight.won.connect(_on_finished.bind(true))
	fight.lost.connect(_on_finished.bind(false))
	_build()
	get_viewport().size_changed.connect(_layout)
	fight.start()
	hud.refresh()


func _process(delta: float) -> void:
	if fight == null or fight.finished:
		return
	fight.advance(delta)
	_scroll(delta)
	_slide_enemy()
	hud.refresh()


## A click anywhere in the arena is a swing: the clock is the difficulty, so there is no sprite to hit.
## Escape is the fight's own X: the loot popup if it is up, else Back under a verdict, else Terminate on
## a run. A tile fight is given up only by its button, so a stray Escape cannot throw one away. With the
## bag up over the fight (`page_up`) the key is the bag's.
func _unhandled_input(event: InputEvent) -> void:
	if (fight != null and event.is_action_pressed("ui_cancel")
			and not (page_up.is_valid() and page_up.call())):
		get_viewport().set_input_as_handled()
		if hud.loot_open():
			hud.close_loot()
		elif fight.finished:
			hud.leave(_on_back_pressed)
		elif fight.endless:
			hud.terminate()
		return
	if fight == null or fight.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		# Swings whether or not the hand's allowance lets the blow through, so a click past the cap
		# still feels heard.
		_swing()
		fight.click()
		hud.refresh()


func _size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)


# ---- the backdrop's pictures (the camp's and `tests/cover_art.gd`'s too)

## A place's backdrop as its layers from the back, each `[texture, rate]` -- the share of `WALK_SPEED`
## it slides at: the sky, still; the land's bands from `BAND_SLOWEST` to `BAND_FASTEST`; the ground, at
## the whole of it. A place or a sky with no art falls back rather than failing: a missing file is a
## build problem, not a reason to lose the tile.
static func backdrop_layers(env: String, variant: String, layout: int, sky: String) -> Array:
	layout = clampi(layout, 1, AREA_LAYOUTS)
	var ground := AREA_PATH % [env, variant, layout]
	if not ResourceLoader.exists(ground):
		push_warning("No backdrop for %s/%s/%d" % [env, variant, layout])
		ground = AREA_FALLBACK
		var named := ground.get_file().get_basename().split("_")
		env = named[0]
		layout = int(named[2])
	var bands: Array[Texture2D] = []
	while ResourceLoader.exists(LAND_PATH % [env, layout, bands.size() + 1]):
		bands.append(load(LAND_PATH % [env, layout, bands.size() + 1]))
	var out := [[load(SKY_PATH % (sky if SKY_LIGHT.has(sky) else SKY_HOURS[0][1])), 0.0]]
	for i in bands.size():
		out.append([bands[i], lerpf(BAND_SLOWEST, BAND_FASTEST, i / maxf(1.0, bands.size() - 1.0))])
	out.append([load(ground), 1.0])
	return out


## The sky over a fight that opens at `hour` (0-23): the last of `SKY_HOURS` to have come up.
static func sky_at(hour: int) -> String:
	var sky: String = SKY_HOURS[-1][1]
	for entry in SKY_HOURS:
		if hour >= int(entry[0]):
			sky = entry[1]
	return sky


## One layer of a backdrop: a region of a texture that repeats, so sliding the region along (`_scroll`)
## is land with no end to it. Placed by `fit_layer`.
static func layer_sprite(art: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, art.get_size())
	return sprite


## Scales and centres a layer to cover `view` whatever its shape, `bleed` over so a shake never shows
## an edge; the ground band stays across the bottom. Returns one of its pixels in screen pixels.
static func fit_layer(sprite: Sprite2D, view: Vector2, bleed: float) -> float:
	var art := Vector2(sprite.texture.get_size())
	var cover := maxf(view.x / art.x, view.y / art.y) * bleed
	sprite.scale = Vector2(cover, cover)
	sprite.position = (view - art * cover) / 2.0
	return cover


## Which of a place's layouts a cell fights on. Seeded from the cell under its own tag, so a tile always
## fights on the same backdrop, and which one has nothing to do with who walks into it.
static func layout_for(for_cell: Vector2i) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["backdrop", for_cell])
	return rng.randi_range(1, AREA_LAYOUTS)


# ---- the arena: backdrop and fighters

func _build() -> void:
	var view := _size()
	_arena = Node2D.new()
	_arena.name = "Arena"
	add_child(_arena)

	if fight.dungeon:
		_build_cave(view)
	else:
		var backdrop := backdrop_layers(fight.env, area_variant, area_layout, area_sky)
		for i in backdrop.size():
			# The sky's light falls on everything but the sky.
			_add_layer(view, backdrop[i][0], backdrop[i][1]).modulate = \
					SKY_LIGHT[area_sky] if i > 0 else Color.WHITE

	var lit: Color = CAVE_HAZE if fight.dungeon else SKY_LIGHT.get(area_sky, Color.WHITE)
	var light := Color.WHITE.lerp(lit, SCENE_LIGHT)
	_player = CombatActor.new()
	_player.name = "Player"
	_arena.add_child(_player)
	_player.setup_player(_actor_height(view), _snap(view), character)
	_player.self_modulate = light
	_player.position = _feet(PLAYER_X)
	_player.animation_finished.connect(func() -> void: _player.play("idle"))

	_enemy = CombatActor.new()
	_enemy.name = "Enemy"
	_enemy.self_modulate = light
	_arena.add_child(_enemy)
	# The cave's nearest rock goes on after them both, so it is what they stand behind.
	if fight.dungeon:
		_add_cave_layer(view, CAVE_NEAREST)

	_ground_drops = Node2D.new()
	_ground_drops.name = "Drops"
	add_child(_ground_drops)

	_sounds = FightSounds.new(weapon_kind)
	add_child(_sounds)
	xp_absorbed.connect(_sounds.xp.play.unbind(1))

	# Last in the tree, as it always was: over the arena, the drops and the sounds.
	move_child(hud, -1)
	hud.build(fight, MapBuilder.level_of(cell), place, _ui_scale)
	hud.back_pressed.connect(_on_back_pressed)
	hud.retry_pressed.connect(retry.emit)


## How tall an ordinary fighter stands in `view`, in screen pixels.
func _actor_height(view: Vector2) -> float:
	return minf(view.y * ACTOR_HEIGHT, view.x * ACTOR_WIDE)


## What a fighter's scale is snapped to: the backdrop's pixel, or half of it on a window held upright,
## whose backdrop is blown up to cover its height and would otherwise draw no fighter smaller than a
## giant. Half, so the two still share a grid.
func _snap(view: Vector2) -> float:
	return _pixel / 2.0 if UITheme.narrow(view, _ui_scale) else _pixel


## Where the fighters' feet are, as a share of the view's height.
func _ground() -> float:
	return GROUND_UPRIGHT if UITheme.narrow(_size(), _ui_scale) else _art_ground()


## Where a backdrop covering the view draws its ground line, as a share of the view's height.
func _art_ground() -> float:
	return CAVE_GROUND if fight != null and fight.dungeon else GROUND


## How far above where `fit_layer` puts it every layer is drawn, in screen pixels: none across a monitor.
func _lift(view: Vector2) -> float:
	return (_art_ground() - _ground()) * view.y


## Where a fighter standing `across` the view has its feet, in screen pixels.
func _feet(across: float) -> Vector2:
	var view := _size()
	return Vector2(view.x * across, view.y * _ground())


## The cave behind the fighters, back to front; `_build` adds the nearest rock once they are in.
func _build_cave(view: Vector2) -> void:
	for n in range(CAVE_FARTHEST, CAVE_NEAREST, -1):
		_add_cave_layer(view, n)


## One layer of the cave, numbered from the nearest, sliding the faster the nearer it is.
func _add_cave_layer(view: Vector2, n: int) -> void:
	_add_layer(view, load(CAVE_PATH % n), float(CAVE_FARTHEST - n) / (CAVE_FARTHEST - CAVE_NEAREST))


## Lays a backdrop layer on the arena over what is there, sliding at `rate` of `WALK_SPEED`.
func _add_layer(view: Vector2, art: Texture2D, rate: float) -> Sprite2D:
	var sprite := layer_sprite(art)
	_arena.add_child(sprite)
	_layers.append(sprite)
	_rates.append(rate)
	_fit(sprite, view)
	return sprite


## Fits a backdrop layer to `view`. Every layer is drawn on the same grid, so any of them gives `_pixel`.
func _fit(layer: Sprite2D, view: Vector2) -> void:
	_pixel = fit_layer(layer, view, BACKDROP_BLEED)
	layer.position.y -= _lift(view)
	_underfoot(layer, view)


## A lifted layer stops short of the window's foot: its own bottom rows (`UNDERFOOT_ROWS`) repeat on
## down to it, on a child drawn straight after it and sliding with it (so it is in `_layers` too) --
## made the first time the layer falls short, and hidden whenever it reaches the foot.
func _underfoot(layer: Sprite2D, view: Vector2) -> void:
	var under: Sprite2D = layer.get_child(0) if layer.get_child_count() > 0 else null
	var foot := layer.position.y + layer.texture.get_height() * layer.scale.y
	if under != null:
		under.visible = foot < view.y
	if foot >= view.y:
		return
	if under == null:
		var art := layer.texture.get_image()
		var rows := art.get_region(
				Rect2i(0, art.get_height() - UNDERFOOT_ROWS, art.get_width(), UNDERFOOT_ROWS))
		under = layer_sprite(ImageTexture.create_from_image(rows))
		under.position = Vector2(0.0, art.get_height())
		# In step with a layer that has slid already.
		under.region_rect.position.x = layer.region_rect.position.x
		layer.add_child(under)
		_layers.append(under)
		_rates.append(_rates[_layers.find(layer)])
	under.region_rect.size.y = ceilf((view.y - foot) / layer.scale.y)


## Lays the arena out to the window again when it changes -- a resize, a phone turned -- as `CampScene`
## does. What a body threw stays where it fell or was falling to: it is gone in a moment.
func _layout() -> void:
	if fight == null:
		return
	var view := _size()
	# A copy: `_underfoot` adds to `_layers`, and its children are fitted with their layers.
	for layer: Sprite2D in _layers.duplicate():
		if layer.get_parent() == _arena:
			_fit(layer, view)
	# A hop or a jolt under way would land on the old ground, at the old size.
	_stop(_hop)
	_stop(_enemy_hit)
	_player.fit(_actor_height(view), _snap(view))
	_player.position = _feet(PLAYER_X)
	if _enemy.sprite_frames != null:
		_enemy.modulate = Color.WHITE
		_enemy.fit(_actor_height(view) * _enemy_band, _snap(view), _enemy_elite)
		_enemy_scale = _enemy.scale
		_enemy.position = _feet(ENEMY_X)
		_slide_enemy()
	hud.refresh()
	hud.recentre()


## The hero walking on: while the next body is coming in the backdrop slides past, each layer wrapped
## round its width, and what lies on the ground goes with the ground; a piece he reaches is picked up
## there and then. Only for show, so it asks the animation level.
func _scroll(delta: float) -> void:
	if fight.phase != Encounter.Phase.WALKING_IN or Settings.animations == Settings.Anim.NONE \
			or not _walks_on():
		return
	for i in _layers.size():
		var region := _layers[i].region_rect
		region.position.x = fposmod(region.position.x + WALK_SPEED * delta * _rates[i], region.size.x)
		_layers[i].region_rect = region
	# Brought back home whenever the ground is bare, so a run of hours never piles up an offset.
	if _ground_drops.get_child_count() == 0:
		_ground_drops.position.x = 0.0
	_ground_drops.position.x -= WALK_SPEED * delta * _pixel
	var reach := _player.position.x + _player.drawn_size().x / 2.0
	for thing: Node2D in _ground_drops.get_children():
		if thing.has_meta(THROWN) and thing.global_position.x <= reach:
			_pick_up(thing)


## Whether the hero walks on to meet each enemy: everywhere but a settlement, which he holds while its
## defenders come at him over a backdrop that stays still.
func _walks_on() -> bool:
	return Encounter.PROFILES.get(area_variant) != Encounter.SETTLEMENT


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


# ---- the enemy coming, and blows

func _on_enemy_coming(_index: int, enemy_name: String, _hp: float) -> void:
	if enemy_name.is_empty():
		_enemy.hide()
		return
	var view := _size()
	_enemy.show()
	_enemy_band = SIZE_HEIGHT[EnemyRoster.size_of(enemy_name)]
	_enemy_elite = fight.on_elite()
	_stop(_enemy_hit)
	_enemy.modulate = Color.WHITE
	_enemy.setup_enemy(enemy_name, _actor_height(view) * _enemy_band, _snap(view), _enemy_elite)
	_enemy_scale = _enemy.scale
	_enemy.position = _feet(OFFSCREEN_X)
	_enemy.play("walk")
	# The hero walks on to meet it, and the backdrop goes by (`_scroll`) -- but holds a settlement.
	if Settings.animations != Settings.Anim.NONE and _walks_on():
		_player.play("walk")
	hud.dress_nameplate()
	_slide_enemy()


## Runs the enemy in over the walk-in, then leaves it standing.
func _slide_enemy() -> void:
	if fight.finished or fight.index >= fight.lineup.size():
		return
	var view := _size()
	var home := view.x * ENEMY_X
	if fight.phase == Encounter.Phase.WALKING_IN:
		# A walk-in of nothing (spawn speed at its cap) is over before the view sees it.
		var left := fight.phase_left / fight.walk_in if fight.walk_in > 0.0 else 0.0
		_enemy.position.x = lerpf(home, view.x * OFFSCREEN_X, left)
	else:
		_enemy.position.x = home


func _on_enemy_spawned(_index: int, _enemy_name: String, _hp: float) -> void:
	_enemy.play("idle")
	# Arrived; a swing struck up on the way in plays out.
	if _player.animation == "walk":
		_player.play("idle")
	_slide_enemy()


## An automatic swing plays the animation and the sound the way a click does; a click has already
## played both, whether or not it landed.
func _on_hit_landed(amount: float, crit: bool, automatic: bool) -> void:
	if automatic:
		_swing()
	_show_damage(amount, crit)
	_jolt_enemy()
	_sounds.blow(crit)
	if crit:
		Juice.shake(_arena, SHAKE_CRIT)


## A blow the enemy survived flinches it -- unless it is swinging at the clock, which a flinch would cut
## off before the blow it stands for had been seen.
func _on_enemy_hit(hp_left: float) -> void:
	if hp_left > 0 and not (_enemy.is_playing() and _enemy.animation == "attack"):
		_enemy.play_once("hurt")


func _jolt_enemy() -> void:
	_stop(_enemy_hit)
	_enemy.modulate = HIT_FLASH
	_enemy.scale = _enemy_scale * HIT_SQUASH
	_enemy_hit = create_tween().set_parallel(true)
	_enemy_hit.tween_property(_enemy, "modulate", Color.WHITE, HIT_TIME)
	_enemy_hit.tween_property(_enemy, "scale", _enemy_scale, HIT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## A swing landing on top of one still running cuts back in at the blow, picture and sound at the same
## instant, so clicking faster than the animation reads as a run of blows, not a stuck first frame.
func _swing() -> void:
	var again := _player.is_playing() and _player.animation == "attack"
	# As far into the swing as the sound is, whatever speed this hero's attack plays at.
	var into := SWING_RESTART_FRAME / CombatActor.FPS
	_player.play_once("attack", roundi(into * _player.sprite_frames.get_animation_speed("attack")))
	_sounds.swing.play(into if again else 0.0)
	_hop_player()


func _hop_player() -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	_stop(_hop)
	var ground := _size().y * _ground()
	_player.position.y = ground
	_hop = create_tween()
	_hop.tween_property(_player, "position:y", ground - SWING_HOP, SWING_HOP_TIME / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop.tween_property(_player, "position:y", ground, SWING_HOP_TIME / 2.0) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _show_damage(amount: float, crit: bool) -> void:
	var written := BigNumber.format(amount)
	_float_text((written + "!") if crit else written, CRIT_COLOR if crit else Palette.BONE,
			CRIT_FONT if crit else DAMAGE_FONT, ENEMY_X, 1.25 if crit else 1.0)


## What an enemy's blow did to the clock, over the hero's head: the seconds it took, or the word for a
## blow that took nothing. Only one that cost something flashes the clock and sounds.
func _on_player_hit(taken: float, dodged: bool, blocked: bool) -> void:
	if _enemy != null and _enemy.sprite_frames != null:
		_enemy.play_once("attack")
	var cost := not dodged and not blocked
	# Over the hero's own head: one drawn taller than the fight's fighter (`CombatActor.PIXEL_STEP`) is not
	# written across its chest.
	var tall := maxf(1.0, _player.drawn_size().y / _actor_height(_size()))
	_float_text("Dodge" if dodged else "Block" if blocked else "-%ss" % _seconds_written(taken),
			FightHud.BAR_HEALTH if cost else Palette.BONE, DAMAGE_FONT, PLAYER_X, 1.0, STRUCK_HEIGHT * tall, true)
	if cost:
		hud.flash_clock()
		_sounds.struck.play()


## Seconds as a blow's number says them: a tenth while it is small enough for a tenth to matter.
static func _seconds_written(seconds: float) -> String:
	return "%.1f" % seconds if seconds < 100.0 else BigNumber.format(seconds)


## A word or a number rising off one of the fighters: across at `across` of the view, `height` of a
## fighter up from the ground, popping in at `pop` times its settled size, and with the HUD's dark
## outline where it asks for one. Everything that floats off a fight comes through here.
func _float_text(text: String, colour: Color, font_size: int, across: float, pop := 1.0,
		height := DAMAGE_HEIGHT, outlined := false) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	# LOW keeps the number and its rise, without the pop or the wander.
	var lively := Settings.animations == Settings.Anim.DEFAULT
	var label := FightHud.hud_label(text, colour) if outlined else FightHud.panel_label(text)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", font_size)
	label.z_index = 1
	label.scale = Vector2(_ui_scale, _ui_scale)
	add_child(label)
	var view := _size()
	# Centred across on its spot, and started a little to the side of it each time so a fast weapon
	# does not stack its numbers into one pile. The width is asked of the font: the label has not been
	# laid out yet.
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * _ui_scale
	var from := Vector2(view.x * across + randf_range(-DAMAGE_SPREAD, DAMAGE_SPREAD) - width * 0.5,
			view.y * _ground() - _actor_height(view) * height)
	# It pops in large about its own middle. The pivot is in the label's own unscaled pixels, and
	# scaling about it moves the corner, so `from` is shifted back by what the settled scale would
	# move it.
	label.pivot_offset = Vector2(width / _ui_scale, font_size) / 2.0
	from += label.pivot_offset * (_ui_scale - 1.0)
	label.position = from
	if lively:
		label.scale = Vector2(_ui_scale, _ui_scale) * DAMAGE_POP_SCALE * pop
	var float_up := create_tween()
	float_up.set_parallel(true)
	float_up.tween_property(label, "scale", Vector2(_ui_scale, _ui_scale), DAMAGE_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drift := randf_range(-DAMAGE_DRIFT, DAMAGE_DRIFT) if lively else 0.0
	float_up.tween_property(label, "position", from + Vector2(drift, -DAMAGE_RISE), DAMAGE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_up.tween_property(label, "modulate:a", 0.0, DAMAGE_TIME).set_ease(Tween.EASE_IN)
	float_up.chain().tween_callback(label.queue_free)


func _on_enemy_died(index: int) -> void:
	_enemy.play_once("death")
	_sounds.death.play()
	if Settings.animations != Settings.Anim.NONE:
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


# ---- what a body drops

## The one listener to `Encounter.loot_dropped`. A find the player has said to leave behind is counted
## and passed on by `loot_discarded`, and that is all that happens to it: it joins no list, moves no
## counter and is never thrown. Everything else leaves by `loot_kept`.
func _on_loot_dropped(index: int, item: Item) -> void:
	# A rule is about ordinary gear: a unique -- or a capstone -- is never thrown away unseen.
	if (item.rarity != ItemRarity.Rarity.UNIQUE and autodiscard.is_valid()
			and bool(autodiscard.call(item))):
		_auto_discarded += 1
		loot_discarded.emit(index, item)
		return
	hud.keep(item)
	# In the ring's colour, the half of the ramp picked to be read on a backdrop.
	_show_find(item.icon(), item.rarity, item.border_color())
	_land(_sounds.drops[FightSounds.drop_sound_of(item)])
	if item.rarity == ItemRarity.Rarity.UNIQUE:
		Juice.hit_stop(get_tree(), STOP_UNIQUE, STOP_UNIQUE_SPEED, STOP_UNIQUE_EASE)
	elif item.rarity == ItemRarity.Rarity.ELITE:
		Juice.hit_stop(get_tree(), STOP_RARE, STOP_RARE_SPEED)
	loot_kept.emit(index, item)


func _on_gold_dropped(_index: int, amount: float) -> void:
	_show_coins(amount)
	gold_gained.emit(amount)


func _on_xp_dropped(_index: int, amount: int) -> void:
	_show_xp(amount)
	xp_gained.emit(amount)


## Thrown as a find is: plain, but for a good orb, which stands the beam of the rarity `OrbTable` names
## for it, in the orb's own colour. It never joins the HUD's `_drops`.
func _on_orb_dropped(_index: int, orb: String) -> void:
	var beam: int = OrbTable.ORBS[orb].get("beam", -1)
	_show_find(OrbTable.icon(orb), beam, OrbTable.ORBS[orb].get("glow", Color.WHITE))
	_land(_sounds.orb)
	hud.loot_changed()
	orb_gained.emit(orb)


## A rune off a body in the cave, thrown as an orb is, in the rare's beam and its own colour.
func _on_rune_dropped(_index: int, rune: String) -> void:
	_show_find(RuneTable.icon(rune), ItemRarity.Rarity.RARE, RuneTable.RUNES[rune]["glow"])
	_land(_sounds.orb)
	rune_gained.emit(rune)


## A drop's sound as it lands: a throw's length on (and `after` more, for one held back in a burst), on
## a tween, so a unique's slow motion slows it with the find and a tip that holds the fight holds it too
## -- or at once, when nothing is thrown at all.
func _land(sound: AudioStreamPlayer, after := 0.0) -> void:
	if Settings.animations == Settings.Anim.NONE:
		sound.play()
	else:
		create_tween().tween_callback(sound.play).set_delay(THROW_TIME + after)


## Where a body's droppings come from: the middle of the enemy, a drop landing the frame it dies. The
## walked-in position is for a fight with no sprite: one the tests drive with nobody on the field.
func _drop_origin() -> Vector2:
	var view := _size()
	if _enemy != null and _enemy.sprite_frames != null:
		return _enemy.position - Vector2(0, _enemy.drawn_size().y * 0.5)
	return Vector2(view.x * ENEMY_X, view.y * _ground() - _actor_height(view) * DAMAGE_HEIGHT)


## How many of a burst a body throws for `amount`: the log of it (`Coins.count_for`), so a richer body
## visibly pays more without the arena filling up -- and one at `LOW`.
func _burst_of(amount: float) -> int:
	return Coins.count_for(amount) if Settings.animations == Settings.Anim.DEFAULT else 1


## Throws one thing out of the body: an arc onto the ground, a rest where it landed, and a fade.
## Everything a body drops is thrown this way. `index` is which of a burst this is, `spread` how far to
## either side it may land and `rest` how long it lies there. `collect` is called after the rest
## instead of the fade, for something that goes somewhere rather than lying there.
func _throw(node: Node2D, index: int, from: Vector2, spread: float, rest: float,
		collect := Callable()) -> void:
	node.z_index = 1
	node.scale = Vector2(_ui_scale, _ui_scale)
	# On the ground, which may have gone by since it was last bare: `from` is a place on the screen.
	node.position = from - _ground_drops.position
	_ground_drops.add_child(node)
	var to := node.position.x + randf_range(-spread, spread)
	var top := from.y - THROW_RISE
	# An arc, not a rise: across at a steady rate while the height goes up and comes back down, in two
	# hops on y. The hold-back is a delay on each of the three rather than an interval in front of
	# them, because a parallel tween's steps are timed from its own start.
	var delay := index * THROW_STAGGER
	var arc := create_tween()
	arc.set_parallel(true)
	arc.tween_property(node, "position:x", to, THROW_TIME).set_delay(delay)
	arc.tween_property(node, "position:y", top, THROW_TIME / 2.0) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(node, "position:y", _size().y * _ground(), THROW_TIME / 2.0) \
			.set_delay(delay + THROW_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	node.set_meta(THROWN, arc)
	arc.chain().tween_interval(rest)
	arc.set_parallel(false)
	if collect.is_valid():
		arc.tween_callback(collect.bind(node))
		return
	# The node frees itself, so nothing piles up on the ground however long a run goes on.
	arc.tween_property(node, "modulate:a", 0.0, THROW_FADE)
	arc.tween_callback(node.queue_free)


## A piece the hero has walked into: its throw and its rest are cut short. Only the picture: what it
## is worth was banked as it dropped.
func _pick_up(thing: Node2D) -> void:
	_stop(thing.get_meta(THROWN))
	_fly_to_counter(thing)


## A coin or a find that has lain its moment, or been picked up, flies into the loot counter. It
## leaves the ground for the screen, so the walk no longer carries it; a find leaves its beam behind on
## the ground, to sink back into it at the find's depth.
func _fly_to_counter(thing: Node2D) -> void:
	thing.remove_meta(THROWN)
	for beam: Node2D in thing.get_children():
		beam.z_index = thing.z_index
		beam.reparent(_ground_drops)
		LootBeam.collapse(beam)
	thing.reparent(self)
	var into := hud.counter_centre()
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(thing, "position", into, COIN_FLY) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(thing, "scale", thing.scale * 0.5, COIN_FLY)
	fly.chain().tween_callback(thing.queue_free)
	fly.tween_callback(hud.bump_counter)


func _show_coins(amount: float) -> void:
	# The amount has already gone to the ledger; the coins only say so. NONE says it with one coin's
	# ring and nothing to see.
	if Settings.animations == Settings.Anim.NONE:
		_land(_sounds.coin)
		return
	var from := _drop_origin()
	for i in _burst_of(amount):
		var coin := AnimatedSprite2D.new()
		coin.sprite_frames = Coins.frames()
		coin.play("spin")
		_throw(coin, i, from, THROW_SPREAD, COIN_REST, _fly_to_counter)
		_land(_sounds.coin, i * THROW_STAGGER)


## A body's experience, as gems that pop out of it and fly into the character panel. `xp_absorbed` goes
## out with the last one to arrive, carrying the whole amount, so the bar takes it in one step.
func _show_xp(amount: int) -> void:
	# With nothing thrown the bar still has to fill, so it takes the amount now.
	if Settings.animations == Settings.Anim.NONE:
		xp_absorbed.emit(amount)
		return
	var from := _drop_origin()
	var count := _burst_of(amount)
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
		tween.tween_property(gem, "position:y", from.y - XP_POP_RISE, XP_POP_TIME) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.set_parallel(false)
		if xp_target.x >= 0.0:
			# Then into the bar, gathering speed, shrinking and fading over the last stretch.
			var fade := XP_FLY_TIME * XP_FADE_SHARE
			tween.tween_property(gem, "position", xp_target, XP_FLY_TIME) \
					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(gem, "scale", gem.scale * 0.5, fade) \
					.set_delay(XP_FLY_TIME - fade)
			tween.parallel().tween_property(gem, "modulate:a", 0.0, fade).set_delay(XP_FLY_TIME - fade)
		else:
			tween.tween_property(gem, "modulate:a", 0.0, THROW_FADE)
		if i == count - 1:
			tween.tween_callback(func() -> void: xp_absorbed.emit(amount))
		tween.tween_callback(gem.queue_free)


## A find coming off a body: its own icon and no name, thrown the way the purse is and drawn at
## `rarity`'s `FIND_SIZE`, with that rarity's `LootBeam` standing over it in `glow`. A `rarity` that
## stands none (`LootBeam.has`: below rare) is drawn plain.
func _show_find(picture: Texture2D, rarity: int = -1, glow := Color.WHITE) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	_finds_shown += 1
	var find := Sprite2D.new()
	find.texture = picture
	var size: float = FIND_SIZE[rarity]
	if LootBeam.has(rarity):
		# The beam is sized on its own, so the find's size is taken back off it -- and handed over as
		# the piece it has to cover instead. Drawn in the fighters' pixels, in the beam's own units.
		var pillar := LootBeam.make(rarity, glow, THROW_TIME,
				picture.get_size() * Vector2(0.5, 1.0) * size, _snap(_size()) / _ui_scale)
		pillar.position = Vector2(0, picture.get_height() / 2.0)
		pillar.scale = Vector2.ONE / size
		find.add_child(pillar)
	_throw(find, 0, _drop_origin(), FIND_SPREAD, FIND_REST, _fly_to_counter)
	find.scale *= size
	find.z_index = 1 + maxi(rarity, 0)


# ---- the end of the fight

func _on_finished(won: bool) -> void:
	Input.set_default_cursor_shape(Cursors.ARROW)
	hud.refresh()
	if won:
		_enemy.hide()
	# Not awaited: the verdict centres itself a frame on, and the timer starts as it comes up.
	hud.show_verdict(won, _auto_discarded)
	if won and auto_collect and not fight.endless and not fight.dungeon:
		# A Timer child, so a pause (a tip) holds it and a scene freed first takes it along.
		var wait := Timer.new()
		wait.one_shot = true
		wait.wait_time = AUTO_COLLECT_SECONDS
		# `pop_out` leaves once however often it is asked, so a Collect pressed first wins.
		wait.timeout.connect(hud.leave.bind(_on_back_pressed))
		add_child(wait)
		wait.start()


## Immediate, where the verdict's buttons leave through `FightHud.leave`: it is what the tests call.
func _on_back_pressed() -> void:
	finished.emit(fight.victory)
