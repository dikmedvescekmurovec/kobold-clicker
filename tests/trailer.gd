extends "res://tests/harness.gd"
## The hype trailer, played out shot by shot and cut to the beat of Sounds/Music/battle.mp3. Recorded
## by `python tools/trailer.py`, which runs this under Movie Maker and lays the track under it; run on
## its own (no --headless) it just plays in a window, silent but for the fight's own sounds.
##
## Everything is timed in beats from beat 0 and waits on frames, never on the clock, so a slow machine
## records the same film. battle.mp3 is 80 BPM with its first beat 0.525 s in and a bar starting on
## every fourth beat from beat 2 -- the numbers `tools/trailer.py` starts the track from.

const BPM := 80.0
const FPS := 60
## The last beat the film holds before it cuts to black (`tools/trailer.py` reads the length off it).
const END_BEAT := 68.0
const MAP_SEED := 1
const CELL := Vector2i(6, 0)
const SUBTITLE := "Click.  Loot.  Explore.  Transcend."
const INVENTORY := "user://trailer_inventory.json"
const MAP := "user://trailer_map.json"

var _start := 0
var _main: Node
var _combat: CombatScene
var _layer: CanvasLayer
var _black: ColorRect
var _rng := RandomNumberGenerator.new()


func _run() -> void:
	_rng.seed = WORLD_SEED
	# A fresh world every take, so every take is the same film.
	for path in [INVENTORY, MAP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_build_overlay()
	_black.show()
	_main = load("res://Scenes/main_scene.tscn").instantiate()
	_main.world_seed = WORLD_SEED
	_main.map_seed = MAP_SEED
	_main.inventory_path = INVENTORY
	_main.map_path = MAP
	root.add_child(_main)
	for i in 3:
		await process_frame
	# The track goes under it afterwards; the game's own would fight it.
	AudioServer.set_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS), true)
	_main.inventory.level = 42
	_main._sync_character()
	_start = Engine.get_process_frames()
	print("TRAILER_START ", Engine.get_frames_drawn())

	_caption("Every click", 0.0, 2.0, 0.5)
	await _until(2.0)
	await _fight_and_loot()
	await _explore()
	await _montage()
	await _grow()
	await _descend()
	await _transcend()
	await _title()
	quit()


# ---- the shots

## Beats 2-22: a farm run, clicked hard; loot starts flying at 10 and a unique drops at 18.
func _fight_and_loot() -> void:
	_black.hide()
	_main.map.hide()
	var fight := Encounter.farm(CELL, "grass")
	fight.roster_rng.seed = WORLD_SEED
	fight.arm({"damage": 5.0, "crit_chance": 50.0, "crit_damage": 80.0, "attack_speed": 1.0})
	_open(fight, CELL, "village", 2)
	_caption("counts.", 2.0, 5.5)
	await _clicking(10.0, 9)

	_caption("LOOT", 10.0, 13.0)
	fight.always_orb = true
	fight.orb_rng.seed = WORLD_SEED
	var rarities := [ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]
	for beat in range(10, 18):
		var piece := LootTable.roll(fight.enemy_name(), _rng, true, 8, 0.0, 0.0, rarities[beat % 2])
		_combat._show_find(piece.icon(), piece.rarity, piece.border_color())
		await _clicking(beat + 1.0, 8)
	fight.always_orb = false

	# The real path, so the slow motion and the banner are the game's own.
	_main._combat = _combat
	_main.inventory.uniques_found.erase("stonebreaker")
	var prize := Item.rolled_unique("stonebreaker", _rng, 8)
	_combat._on_loot_dropped(0, prize)
	_main._on_loot_dropped(0, prize)
	await _until(20.5)
	await _clicking(22.0, 10)
	_main._close_banner()
	_main._combat = null
	_close_fight()


## Beats 22-30: the map, the fog lifting off it ring by ring on the beat as the camera pulls back.
func _explore() -> void:
	Engine.time_scale = 1.0
	_main.map.show()
	var view: MapBuilder = _main.view
	var camera: Camera2D = _main.camera
	camera.zoom = Vector2(3, 3)
	camera.position = _main.map.ground_layer.map_to_local(view.player_cell)
	var zoom := camera.create_tween()
	zoom.tween_property(camera, "zoom", Vector2(1.0, 1.0), _seconds(8.0)) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_caption("EXPLORE", 22.0, 26.0)
	for beat in range(22, 26):
		view._reveal_around(view.player_cell, 2 + (beat - 22) * 2)
		await _until(beat + 1.0)
	view.reveal_all()
	await _until(30.0)
	_main.map.hide()


## Beats 30-38: every land for a beat, then a settlement's boss felled.
func _montage() -> void:
	_caption("CONQUER", 30.0, 33.0)
	var envs := SheetMeta.env_adjacency().keys()
	var variants := ["town", "village", "fortress", "village", "town", "fortress"]
	for i in envs.size():
		var fight := Encounter.for_tile(CELL, envs[i])
		fight.arm({"damage": 6.0, "crit_chance": 60.0, "crit_damage": 80.0})
		_open(fight, CELL, variants[i % variants.size()], 1 + i % CombatScene.AREA_LAYOUTS, envs[i])
		await _clicking(31.0 + i, 7)
		_close_fight()

	var boss_fight := Encounter.for_tile(CELL, "grass", "village")
	var bosses := EnemyRoster.in_environment("grass", EnemyRoster.Tier.BOSS)
	boss_fight.lineup[0] = bosses[0]
	boss_fight.health[0] = Encounter.hp_of(bosses[0], CELL)
	boss_fight.hp = boss_fight.health[0] * 0.5
	boss_fight.arm({"damage": boss_fight.hp / 5.0, "crit_chance": 100.0, "crit_damage": 20.0})
	_open(boss_fight, CELL, "village", 3)
	await _until(37.0)
	await _clicking(38.0, 8)
	_close_fight()


## Beats 38-47: the skill trees filled on the beat until they burst, the pop on beat 46.
func _grow() -> void:
	Engine.time_scale = 1.0
	_main.map.show()
	var level := SkillTree.total_capacity() + 1
	_main.inventory.level = level
	var order: Array[String] = []
	var full := Skills.new()
	var learned := true
	while learned:
		learned = false
		for tree: String in SkillTree.trees():
			for id: String in SkillTree.nodes_of(tree):
				if full.rank_up(id, level):
					order.append(id)
					learned = true
	const PRESSES := 7
	var skills := Skills.new()
	for id in order.slice(0, order.size() - PRESSES):
		skills.rank_up(id, level)
	_main.inventory.skills = skills
	# Filling the trees earns achievements, and their banner would stand over the burst.
	_main._resetting = true
	_main._on_skills_pressed()
	_caption("GROW", 38.0, 41.5)
	# The burst takes BURST_GLINT + BURST_SHAKE after the last press to pop: 4.8 beats.
	var pop_at := 46.0 - _beats(SkillsPage.BURST_GLINT + SkillsPage.BURST_SHAKE)
	for i in PRESSES:
		await _until(pop_at - (PRESSES - 1 - i) * 0.5)
		_main.skills_page._on_skill_pressed(order[order.size() - PRESSES + i])
		_main.skills_page._stop_holding()
	await _until(47.0)
	# Earned here, quietly, so the next check has nothing left to announce.
	Achievements.earn(_main.inventory)
	_main._resetting = false
	_main._close_left_pages()
	_main.map.hide()


## Beats 47-54: the dungeon, three floors cut down and Gollux on the phrase at 50.
func _descend() -> void:
	var fight := Encounter.for_dungeon(3)
	# Three floors before him, not fourteen: the floor count is what decides where he stands.
	fight.first_floor += fight.enemies - 3
	fight.arm({"damage": 1.0})
	_open(fight, Vector2i.ZERO, "plain", 1, "", "The Descent")
	_caption("DESCEND", 47.0, 50.0)
	var tick := func(_frame: int) -> void:
		# Every blow a share of whatever stands there, so the numbers climb with the depth: a floor
		# dies in two or three, Gollux in six or so.
		var boss := Encounter.tier_in(fight, fight.index) == EnemyRoster.Tier.BOSS
		fight.damage = fight.enemy_max_hp() / (8.0 if boss else 2.5)
		fight.crit_chance = 60.0
		fight.crit_damage = 80.0
	await _clicking(54.0, 7, tick)
	_close_fight()


## Beats 54-58: the black screen between worlds.
func _transcend() -> void:
	Engine.time_scale = 1.0
	_main.map.show()
	_main.inventory.skull_budget = 6
	var black := TranscendPage.new(_main.inventory, _main.ui_scale)
	_main._ui_layer.add_child(black)
	_main._character.hide()
	_caption("BEGIN AGAIN", 54.0, 56.0, 0.82)
	_caption("STRONGER", 56.0, 58.0, 0.82)
	await _until(58.0)
	black.queue_free()


## Beats 58-68: the title on black, the hero above it.
func _title() -> void:
	_black.show()
	_main.hide()
	var size := Vector2(root.get_visible_rect().size)
	var hero := CombatActor.new()
	hero.setup_player(size.y * 0.4)
	hero.position = Vector2(size.x / 2.0, size.y * 0.47)
	_layer.add_child(hero)
	_caption(ProjectSettings.get_setting("application/config/name"), 58.0, END_BEAT - 1.0, 0.6, 64,
			Palette.GOLD)
	_caption(SUBTITLE, 62.0, END_BEAT - 1.0, 0.72, 32)
	await _until(END_BEAT - 2.0)
	var fade := hero.create_tween().set_ignore_time_scale()
	fade.tween_property(hero, "modulate:a", 0.0, _seconds(1.0))
	await _until(END_BEAT)


# ---- helpers

func _open(fight: Encounter, cell: Vector2i, variant: String, layout: int, env := "grass",
		place := "") -> void:
	_combat = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	_main.add_child(_combat)
	_combat.place = place if place != "" else TileNames.generate(cell, env, MAP_SEED, "small")
	_combat.xp_target = _main._character.xp_point()
	_combat.begin(fight, cell, _main.ui_scale, variant, layout)
	# Straight onto a standing enemy: a cut is no place to wait for one to walk in.
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)


func _close_fight() -> void:
	_combat.queue_free()
	_combat = null


## Clicks the fight every `every` frames until `beat`, the way a player's press does
## (`CombatScene._unhandled_input`). `tick` runs first on every frame.
func _clicking(beat: float, every: int, tick := Callable()) -> void:
	while Engine.get_process_frames() < _frame_of(beat):
		var frame := Engine.get_process_frames() - _start
		if tick.is_valid():
			tick.call(frame)
		if frame % every == 0 and _combat != null and not _combat.fight.finished:
			_combat._swing()
			_combat.fight.hit()
			_combat._refresh()
		await process_frame


func _until(beat: float) -> void:
	while Engine.get_process_frames() < _frame_of(beat):
		await process_frame


func _frame_of(beat: float) -> int:
	return _start + roundi(_seconds(beat) * FPS)


func _seconds(beats: float) -> float:
	return beats * 60.0 / BPM


func _beats(seconds: float) -> float:
	return seconds * BPM / 60.0


func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	root.add_child(_layer)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_black)


## A line punched in on `from` and gone by `to`, its middle at `height` of the window. Pixellari at a
## whole multiple of its native 16 px, so it stays crisp.
func _caption(text: String, from: float, to: float, height := 0.5, font_size := 96,
		colour := Palette.BONE) -> void:
	var label := Label.new()
	label.theme = UITheme.theme()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	label.add_theme_constant_override("outline_size", font_size / 4)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	label.add_theme_constant_override("shadow_offset_x", font_size / 16)
	label.add_theme_constant_override("shadow_offset_y", font_size / 16)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.hide()
	_layer.add_child(label)
	var show := func() -> void:
		var size := Vector2(root.get_visible_rect().size)
		label.size = label.get_combined_minimum_size()
		label.position = Vector2((size.x - label.size.x) / 2.0, size.y * height - label.size.y / 2.0)
		label.pivot_offset = label.size / 2.0
		label.scale = Vector2.ONE * 1.6
		label.show()
		# Blind to the slow motion a unique asks for: a caption keeps the music's time.
		var pop := label.create_tween().set_ignore_time_scale().set_parallel()
		pop.tween_property(label, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK) \
				.set_ease(Tween.EASE_OUT)
		pop.chain().tween_interval(_seconds(to - from) - 0.4)
		pop.chain().tween_property(label, "modulate:a", 0.0, 0.2)
		pop.chain().tween_callback(label.queue_free)
	var wait := func() -> void:
		await _until(from)
		show.call()
	wait.call()
