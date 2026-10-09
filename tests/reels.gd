extends "res://tests/trailer.gd"
## Ten short upright reels, one mechanic each, for a phone's feed. Recorded by `python tools/reels.py`
## at 360x640 (ui_scale 1, the narrow layout) and blown up to 1080x1920; run on its own with
## `--resolution 360x640 -s res://tests/reels.gd -- --reel=<name>` it plays in a window.
##
## Built on the trailer's helpers, but timed in seconds rather than its 80 BPM beats: `_seconds` and
## `_beats` are the identity here, so every `_until`, `_caption` and `_point_at` reads in seconds from
## `_roll()`, which each reel calls once its staging is done (the film is cut from there). Each reel
## prints `REEL_HIT <seconds>` at its punch, which `tools/reels.py` lays a hit of the music on.
##
## The hero is a level 42 in a full set of rare gear (`_gear_up`), and every fight is armed from it, so
## the character panel and the blows agree; the bodies are given a few blows of health (`_open`).

const REEL_INVENTORY := "user://reels_inventory.json"
const REEL_MAP := "user://reels_map.json"
## Caption sizes on the 360 px window: Pixellari at whole multiples of its 16.
const BIG := 48
const SMALL := 32
## Where a caption stands: over the dirt under the fight, clear of the fighters.
const LOW := 0.74
## Frames between taps at the steady rate: ten a second, under the fight's cap of fifteen.
const TAP := 6

var _hit_at := -1.0


func _run() -> void:
	var reel := "click"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--reel="):
			reel = arg.get_slice("=", 1)
	_rng.seed = WORLD_SEED
	for path in [REEL_INVENTORY, REEL_MAP]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_build_overlay()
	_black.hide()
	await _stage_main(MAP_SEED)
	_main.inventory.level = 42
	_gear_up(12, ItemRarity.Rarity.RARE)
	# What the gear earns, earned quietly: its banner would stand over the reel's own.
	Achievements.earn(_main.inventory)
	_start = Engine.get_process_frames()
	await call("_reel_" + reel)
	print("REEL_END ", Engine.get_frames_drawn())
	print("REEL_HIT ", _hit_at)
	quit()


## The game, on `map_seed`, with every tip read and the map's pointers and hover outline off.
func _stage_main(map_seed: int) -> void:
	_main = load("res://Scenes/main_scene.tscn").instantiate()
	_main.world_seed = WORLD_SEED
	_main.map_seed = map_seed
	_main.inventory_path = REEL_INVENTORY
	_main.map_path = REEL_MAP
	root.add_child(_main)
	for i in 3:
		await process_frame
	_cursor.scale = Vector2.ONE * _main.ui_scale
	AudioServer.set_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS), true)
	for tip: Array in _main.get_script().get_script_constant_map()["TIPS"]:
		if not str(tip[0]) in _main.inventory.tips:
			_main.inventory.tips.append(tip[0])
	_main._hero_pointer.process_mode = Node.PROCESS_MODE_DISABLED
	_main._hero_pointer.hide()
	_main._chest_pointer.process_mode = Node.PROCESS_MODE_DISABLED
	_main._chest_pointer.hide()
	_main.map.highlight.hide()


## The frame the reel is cut from: everything before it is staging.
func _roll() -> void:
	_start = Engine.get_process_frames()
	print("REEL_START ", Engine.get_frames_drawn())


## The punch, which the music's hit is laid on.
func _hit() -> void:
	_hit_at = _beats_since(0.0)


func _seconds(beats: float) -> float:
	return beats


func _beats(seconds: float) -> float:
	return seconds


# ---- the reels

## Every click counts: a farm run tapped faster and faster, each body hitting harder than the last.
func _reel_click() -> void:
	_fight_here(Encounter.farm(CELL, "forest"), "forest", "plain", 2)
	var fight := _combat.fight
	# The numbers climbing are the whole genre: each kill makes the next blows three times as big.
	fight.enemy_died.connect(func(_index: int) -> void: fight.damage *= 3.0)
	_roll()
	_hand_on_enemy()
	_say("TAP", 0.2, 1.2)
	_say("TAP", 1.2, 2.2)
	_say("TAP!!", 2.2, 3.4, Palette.GOLD)
	await _tap_until(2.2, 12)
	await _tap_until(3.4, 8)
	await _tap_until(5.0, 5)
	_hit()
	_say("EVERY CLICK", 5.0, 7.5)
	_say("COUNTS", 5.4, 7.5, Palette.GOLD, LOW + 0.08)
	await _tap_until(7.5, 5)


## The lands a loot run cuts between, one a kill: environment, variant, layout.
const LOOT_LANDS := [["desert", "village", 3], ["ice", "town", 4], ["grass", "village", 1]]
## The unique the last body drops.
const LOOT_PRIZE := "berserkers_band"


## Loot: three bodies in three lands, each throwing a better find -- rare, epic, and a unique in the
## game's own slow motion under its banner.
func _reel_loot() -> void:
	_farm_on(LOOT_LANDS[0])
	_roll()
	_hand_on_enemy()
	_say("LOOT", 0.1, 1.0)
	for rarity: int in [ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
		await _tap_to_kill()
		_combat.fight.phase_left = 10.0
		var piece := LootTable.roll(_combat.fight.enemy_name(), _rng, true, 8, 0.0, 0.0, rarity)
		_combat._on_loot_dropped(0, piece)
		var now := _beats_since(0.0)
		_say(ItemRarity.label_of(rarity).to_upper(), now, now + 1.4, ItemRarity.BORDER_COLORS[rarity])
		await _until(now + 1.4)
		_close_fight()
		_farm_on(LOOT_LANDS[2 if rarity == ItemRarity.Rarity.ELITE else 1])
	await _tap_to_kill()
	_cursor.hide()
	_combat.fight.phase_left = 10.0
	_main._combat = _combat
	_main.inventory.uniques_found.erase(LOOT_PRIZE)
	var prize := Item.rolled_unique(LOOT_PRIZE, _rng, 8)
	_combat._on_loot_dropped(0, prize)
	_main._on_loot_dropped(0, prize)
	_hit()
	var at := _beats_since(0.0)
	_say("UNIQUE!", at, at + 3.4, ItemRarity.BORDER_COLORS[ItemRarity.Rarity.UNIQUE], 0.86)
	await _until(at + 3.6)


## Beat the clock: the end of a village's set piece, its last commons felled a blow each and then its
## boss, the clock running down under him and gone with a sliver left.
func _reel_boss() -> void:
	var fight := Encounter.for_tile(CELL, "grass", "village")
	fight.strikes = false
	_fight_here(fight, "grass", "village", 3, 0.5)
	# The boss, whenever he comes, stands for the whole of the reel's clicking.
	const FALLS := 5.0
	fight.enemy_coming.connect(func(index: int, _enemy: String, _hp: float) -> void:
		if Encounter.tier_in(fight, index) == EnemyRoster.Tier.BOSS:
			fight.health[index] = roundf(_blow(fight) * (FALLS - _beats_since(0.0)) * 60.0 / TAP * 1.1)
			fight.hp = fight.health[index])
	await _skip_to(fight, fight.enemies - 5)
	_roll()
	_hand_on_enemy()
	_say("BEAT", 0.2, 2.0)
	_say("THE CLOCK", 0.5, 2.0, Palette.GOLD, LOW + 0.08)
	var hold := func(_frame: int) -> void:
		fight.time_left = lerpf(14.0, 0.3, clampf(_beats_since(0.0) / FALLS, 0.0, 1.0))
		if Encounter.tier_in(fight, fight.index) == EnemyRoster.Tier.BOSS:
			fight.hp = maxf(fight.hp, fight.health[fight.index] * 0.06)
	var struck := func() -> void:
		for at: float in [2.6, 4.1]:
			await _until(at)
			_combat._on_player_hit(2.0, false, false)
	struck.call()
	await _clicking_hand(FALLS, hold)
	fight.hp = 1.0
	_tap()
	_hit()
	_say("0.3s LEFT!", FALLS, FALLS + 2.4, Palette.GOLD, 0.84)
	await _until(FALLS + 2.6)


## Explore: three tiles charted out from the start, each showing more of the land than the last, the
## fog sweeping off it from the hero, and the camera pulling out over what has come out of the dark.
func _reel_explore() -> void:
	var view: MapBuilder = _main.view
	var map: HexMap = _main.map
	var camera: Camera2D = _main.camera
	var zoom := camera.zoom
	camera.position = map.ground_layer.map_to_local(view.player_cell)
	await process_frame
	_roll()
	_say("EXPLORE", 0.2, 1.8)
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.7, 0.75)
	_cursor.show()
	var cell := view.player_cell
	# When each step starts and how far the hero sees from the tile it takes.
	for step: Array in [[0.3, 2], [2.4, 3], [4.4, 7]]:
		await _until(step[0])
		while view.walking:
			await process_frame
		var next := _upward(view, cell)
		await _point_to(_on_screen(next), 0.5)
		_tap_look()
		map.select_cell(next)
		_main._on_tile_clicked(next, map.get_tile_info(next))
		await _until(step[0] + 0.8)
		await _point_at(_main._chart_button, 0.45)
		_tap_look()
		await _until(step[0] + 1.45)
		_main._on_close_pressed()
		view.chart(next, step[1])
		cell = next
	_hit()
	_cursor.hide()
	var out := camera.create_tween()
	out.tween_property(camera, "zoom", zoom * 0.5, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_say("CHART", 5.0, 8.4)
	_say("THE FOG", 5.4, 8.4, Palette.GOLD, LOW + 0.08)
	await _until(8.4)


## Craft: a plain sword in the bag taken up a rarity at a time with orbs, the card beside it after each.
func _reel_craft() -> void:
	var inventory: Inventory = _main.inventory
	# Every orb unlocked: the walls they come with broken in some world (`OrbTable.unlocked`).
	inventory.farthest_land = MapBuilder.START_LAND_RADIUS + OrbTable.EVERY_WALL * MapBuilder.WALL_STEP
	for pair: Array in [["Orb of Transmutation", 6], ["Orb of Augmentation", 4], ["Orb of Alchemy", 3],
			["Orb of Chaos", 9], ["Orb of Exaltation", 1]]:
		inventory.add_orb(pair[0], pair[1])
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for spec: Array in [["Leather Boots", ItemRarity.Rarity.RARE], ["Gold Ring", ItemRarity.Rarity.UNCOMMON],
			["Wooden Shield", ItemRarity.Rarity.COMMON]]:
		inventory.add(Item.rolled(spec[0], spec[1], rng, 10))
	var sword := Item.rolled(_weapon_type(), ItemRarity.Rarity.COMMON, rng, 14)
	inventory.add(sword)
	await _light_start()
	_main._on_bag_pressed()
	for i in 3:
		await process_frame
	_roll()
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.5, 0.35)
	_cursor.show()
	_say("CRAFT", 0.1, 1.4, Palette.BONE, 0.2)
	await _point_at(_bag_square(sword), 0.6)
	_card_over(_bag_square(sword))
	# Each orb: picked up off the tray, pressed on the sword, and the card read a moment.
	var orbs := [["Orb of Transmutation", 1.1], ["Orb of Alchemy", 2.6], ["Orb of Chaos", 4.0],
			["Orb of Exaltation", 5.4]]
	for pair: Array in orbs:
		await _until(pair[1])
		_card_over(null)
		await _point_at(_orb_square(pair[0]), 0.35)
		await _click()
		await _point_at(_bag_square(sword), 0.35)
		await _click()
		_card_over(_bag_square(sword))
		var now := _beats_since(0.0)
		var word := "REROLL" if pair[0] == "Orb of Chaos" else ItemRarity.label_of(sword.rarity).to_upper()
		_say(word, now, now + 1.2, ItemRarity.BORDER_COLORS[sword.rarity], 0.2)
		if pair[0] == "Orb of Exaltation":
			_hit()
	await _until(_hit_at + 2.4)


## Grow: the skill tree lit stone by stone, and the last point into the capstone under the pointer.
func _reel_skills() -> void:
	var presses := _grown_tree()
	var skills: Skills = _main.inventory.skills
	_main._resetting = true
	await _light_start()
	_main._on_skills_pressed()
	for i in 3:
		await process_frame
	_roll()
	var page: SkillsPage = _main.skills_page
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.55, 0.9)
	_cursor.show()
	_say("GROW", 0.1, 1.4, Palette.BONE, 0.2)
	const LAST := 5.0
	for i in presses.size():
		var at := LAST if i == presses.size() - 1 else 0.9 + i * 0.5
		var lead := 1.0 if i == presses.size() - 1 else 0.3
		await _until(at - lead)
		await _point_at(_slot(page, presses[i]), lead)
		await _until(at)
		var had := skills.rank_of(presses[i])
		await _click()
		if skills.rank_of(presses[i]) == had:
			page._on_stone_pressed(presses[i])
	_hit()
	_say("LIGHT IT UP", LAST, LAST + 2.6, Palette.GOLD, 0.2)
	await _until(LAST + 0.8)
	_cursor.hide()
	await _until(LAST + 2.8)
	Achievements.earn(_main.inventory)
	_main._resetting = false


## The wall: the hero walked up to the ice, the wall charted and fought, felled, and the ice coming
## down on the map with the land behind it sweeping out of the dark.
func _reel_wall() -> void:
	var view: MapBuilder = _main.view
	var map: HexMap = _main.map
	var edge := _wall_side(view)
	await _walk_far(view, edge)
	var wall := Vector2i.ZERO
	for cell: Vector2i in HexGrid.neighbors(edge):
		if view.is_wall(cell):
			wall = cell
	_main.camera.position = map.ground_layer.map_to_local(edge)
	for i in 30:
		await process_frame
	_roll()
	_say("THE ICE WALL", 0.1, 1.8, Palette.BONE, 0.2)
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.7, 0.75)
	_cursor.show()
	await _point_to(_on_screen(wall), 0.5)
	_tap_look()
	map.select_cell(wall)
	_main._on_tile_clicked(wall, map.get_tile_info(wall))
	await _until(1.0)
	await _point_at(_main._chart_button, 0.45)
	await _click()
	while _main._combat == null:
		await process_frame
	_combat = _main._combat
	var fight := _combat.fight
	const FALLS := 5.6
	# About the blows the clicking has time for, and a little more, so it stands to the end.
	var from := _beats_since(0.0)
	fight.health[0] = roundf(_blow(fight) * (FALLS - from - 0.4) * 60.0 / TAP * 1.15)
	fight.hp = fight.health[0]
	while fight.phase != Encounter.Phase.WAITING:
		await process_frame
	_hand_on_enemy()
	var hold := func(_frame: int) -> void:
		fight.hp = maxf(fight.hp, fight.health[0] * 0.05)
	await _clicking_hand(FALLS, hold)
	fight.hp = 1.0
	_tap()
	_cursor.hide()
	_say("SMASH IT", FALLS, FALLS + 1.2, Palette.GOLD)
	await _until(FALLS + 1.2)
	# Back on the map with the ice still standing a moment, then down: the verdict's way out charts it.
	var camera: Camera2D = _main.camera
	camera.position = map.ground_layer.map_to_local(wall)
	_combat.visible = false
	_main._panel.hide()
	map.show()
	await _until(FALLS + 1.7)
	_main._resetting = true
	_combat._on_back_pressed()
	while _main._combat != null:
		await process_frame
	_hit()
	_flash()
	_shake(camera, 10.0)
	_main._on_close_pressed()
	view._reveal_around(wall, 6)
	var out := camera.create_tween()
	out.tween_property(camera, "zoom", camera.zoom * 0.7, 3.0).set_trans(Tween.TRANS_SINE) \
			.set_ease(Tween.EASE_IN_OUT)
	var at := _beats_since(0.0)
	_say("NEW LANDS", at + 0.2, at + 3.0, Palette.BONE, 0.2)
	await _until(at + 3.0)


## The descent: the red light at the map's edge, the cave come out of the dark, Enter cave, the last
## floors of a depth felled a blow each and Gollux at the foot of it.
func _reel_descent() -> void:
	var view: MapBuilder = _main.view
	var map: HexMap = _main.map
	var inventory: Inventory = _main.inventory
	inventory.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	# Behind the first wall, by hand: Gollux's own unlock is the third wall's (`WallUnlocks.GOLLUX`).
	view.place_cave(inventory.farthest_land)
	_main._credit_walls()
	var cave: Vector2i = view.cave
	view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	view._cover()
	var near := cave
	for step in 2:
		near = HexGrid.neighbor(near, HexGrid.Edge.W)
	view.player_cell = near
	map.set_player_cell(near)
	view._reveal_around(near, 1)
	# Between the two, the cave a step inside the window's right edge, where its light comes from.
	_main.camera.position = map.ground_layer.map_to_local(HexGrid.neighbor(near, HexGrid.Edge.E))
	inventory.dungeon_depth = 4
	# The descent Enter cave opens (`_on_dungeon_pressed`), its first ten floors already behind it.
	var fight := Encounter.for_dungeon(inventory.dungeon_depth)
	_arm_bag(fight)
	await _skip_to(fight, fight.enemies - 5)
	for i in 30:
		await process_frame
	_roll()
	_say("SOMETHING", 0.1, 1.6, Palette.BONE, 0.2)
	_say("BELOW...", 0.4, 1.6, Palette.RUST, 0.28)
	await _until(0.8)
	view._reveal_around(near, 2)
	await _until(1.8)
	view._show(cave, MapBuilder.State.CHARTED, true)
	view._reveal_around(cave, 1)
	view.player_cell = cave
	map.set_player_cell(cave)
	map.select_cell(cave)
	_main._on_tile_clicked(cave, map.get_tile_info(cave))
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.7, 0.6)
	_cursor.show()
	await _point_at(_main._cave_button, 0.4)
	# A press the reel answers itself: the real one would open a descent of its own under this one.
	_tap_look()
	for i in 4:
		await process_frame
	const FALLS := 7.4
	_open(fight, Vector2i.ZERO, "plain", 1, Encounter.DUNGEON_ENV, "The Descent", 0.5)
	_main._combat = _combat
	map.hide()
	_main._panel.hide()
	_main._show_corner(false)
	_main._character.show()
	fight.health[fight.index] = roundf(_blow(fight) * 0.5)
	fight.hp = fight.health[fight.index]
	fight.enemy_coming.connect(func(index: int, _enemy: String, _hp: float) -> void:
		if Encounter.tier_in(fight, index) == EnemyRoster.Tier.BOSS:
			fight.health[index] = roundf(_blow(fight) * (FALLS - _beats_since(0.0)) * 60.0 / TAP * 1.1)
			fight.hp = fight.health[index]
			_say("GOLLUX", _beats_since(0.0), _beats_since(0.0) + 1.6, Palette.RUST, 0.82))
	_hand_on_enemy()
	var hold := func(_frame: int) -> void:
		if Encounter.tier_in(fight, fight.index) == EnemyRoster.Tier.BOSS:
			fight.hp = maxf(fight.hp, fight.health[fight.index] * 0.06)
	await _clicking_hand(FALLS, hold)
	fight.hp = 1.0
	_tap()
	_hit()
	_cursor.hide()
	_say("HOW DEEP", FALLS + 0.3, FALLS + 2.4, Palette.BONE, 0.82)
	_say("CAN YOU GO?", FALLS + 0.6, FALLS + 2.4, Palette.RUST, 0.9)
	await _until(FALLS + 2.4)


## Transcend: the fortuneteller's way out taken, the black screen between worlds, one piece kept as
## an heirloom, and the new world it is carried into.
func _reel_transcend() -> void:
	var view: MapBuilder = _main.view
	var map: HexMap = _main.map
	var inventory: Inventory = _main.inventory
	_main._resetting = true
	view.land_radius += MapBuilder.WALL_STEP
	_main._credit_walls()
	inventory.dungeon_depth = 6
	var keep := LootTable.roll("Imp", _rng, true, 14, 0.0, 0.0, ItemRarity.Rarity.ELITE)
	inventory.add(keep)
	inventory.add(LootTable.roll("Imp", _rng, true, 12, 0.0, 0.0, ItemRarity.Rarity.RARE))
	inventory.super_orbs = 3
	var town := view.start_town - view.origin
	inventory.gold = TownPrices.fortune_price(FortuneTeller.TRANSCEND, town) * 3.0
	Achievements.earn(inventory)
	_main._resetting = false
	await _walk_far(view, town)
	map.select_cell(town)
	_main._on_tile_clicked(town, map.get_tile_info(town))
	_main._on_town_pressed()
	_main.camera.position = map.ground_layer.map_to_local(town)
	for i in 30:
		await process_frame
	_roll()
	var page: TownPage = _main.town_page
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.5, 0.8)
	_cursor.show()
	var tab: Control = null
	for button in page.find_children("*", "Button", true, false):
		if (button as Button).tooltip_text == TownServices.label(TownServices.FORTUNE):
			tab = button
	await _point_at(tab, 0.4)
	await _click()
	await _point_at(page.find_child(FortuneTeller.TRANSCEND, true, false), 0.4)
	await _click()
	await _point_at(await _shown("Transcend"), 0.4)
	await _click()
	_say("LEAVE IT", 2.0, 3.6, Palette.BONE, 0.84)
	_say("ALL BEHIND", 2.3, 3.6, Palette.BONE, 0.92)
	await _point_at(await _shown("Create an heirloom"), 0.4)
	await _click()
	var at := _beats_since(0.0)
	_say("KEEP ONE", at, at + 2.4, Palette.GOLD, 0.14)
	await _point_at(_bag_square(keep), 0.4)
	await _click()
	await _point_at(await _shown("Make heirloom"), 0.35)
	await _click()
	await _point_at(await _shown("Keep"), 0.35)
	await _click()
	await _point_at(await _shown("Enter the new world"), 0.5)
	await _click()
	_cursor.hide()
	_hit()
	# What `_transcend` does after its write is reload the scene, which a script's root cannot: the
	# new world is stood up here the way the reload would stand it.
	_main.queue_free()
	await _stage_main(MAP_SEED + 1)
	var camera: Camera2D = _main.camera
	camera.zoom *= 1.4
	camera.position = _main.map.ground_layer.map_to_local(_main.view.player_cell)
	at = _beats_since(0.0)
	_say("BEGIN AGAIN", at, at + 2.8)
	_say("STRONGER", at + 0.5, at + 2.8, Palette.GOLD, LOW + 0.08)
	camera.create_tween().tween_property(camera, "zoom", camera.zoom / 1.4, 2.6) 			.set_trans(Tween.TRANS_SINE)
	await _until(at + 2.8)


## The camp: a run tapped, the game shut, eight hours on the camp's own screen, and breaking camp into
## the level-ups those hours paid for.
func _reel_camp() -> void:
	_fight_here(Encounter.farm(CELL, "grass"), "grass", "plain", 1)
	_roll()
	_hand_on_enemy()
	_say("CLOSE", 0.2, 2.0)
	_say("THE GAME", 0.5, 2.0, Palette.BONE, LOW + 0.08)
	await _tap_until(2.0, TAP)
	_cursor.hide()
	_black.modulate.a = 0.0
	_black.show()
	_black.create_tween().tween_property(_black, "modulate:a", 1.0, 0.4)
	_say("8 HOURS LATER", 2.5, 3.8, Palette.BONE, 0.5, SMALL)
	await _until(3.8)
	_close_fight()
	_main._combat = null
	var inventory: Inventory = _main.inventory
	var fight := Encounter.farm(CELL, "grass")
	_arm_bag(fight)
	var now := Time.get_unix_time_from_system()
	var camp := Camp.make(CELL, TileNames.generate(CELL, "grass", MAP_SEED), fight, now - 8.0 * 3600.0)
	var earned := Camp.earned(camp, now)
	inventory.gold += float(earned[Camp.GOLD])
	# The hours pay at least a level, whatever the sample made of them: the level-up is the shot.
	inventory.xp = PlayerLevel.xp_to_next(inventory.level) - 1
	_main._camp_levels = inventory.add_xp(maxi(int(earned[Camp.XP]), 1))
	var scene := CampScene.new()
	scene.broke_camp.connect(_main._break_camp)
	_main.add_child(scene)
	scene.begin(camp, earned, "grass", "plain", _main.ui_scale)
	_main._camp = scene
	_main.map.hide()
	_main._show_corner(false)
	_main._character.show()
	_black.create_tween().tween_property(_black, "modulate:a", 0.0, 0.3)
	_say("LOOT WHILE", 4.1, 5.8, Palette.BONE, 0.14)
	_say("YOU SLEEP", 4.4, 5.8, Palette.GOLD, 0.22)
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.6, 0.85)
	_cursor.show()
	await _until(5.2)
	await _point_at(_button("Break camp"), 0.5)
	await _click()
	_hit()
	_cursor.hide()
	await _until(8.2)


# ---- staging

## The land round the start out of the fog, so a page has the map lit behind it rather than grey.
func _light_start() -> void:
	_main.view._reveal_around(_main.view.player_cell, 4)
	for i in 90:
		await process_frame


## A white flash over everything, gone in a third of a second.
func _flash() -> void:
	var white := ColorRect.new()
	white.color = Color(1, 1, 1, 0.8)
	white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(white)
	var fade := white.create_tween()
	fade.tween_property(white, "modulate:a", 0.0, 0.35)
	fade.tween_callback(white.queue_free)


## Knocks `camera` about by up to `strength` pixels, dying away over half a second.
func _shake(camera: Camera2D, strength: float) -> void:
	var shake := camera.create_tween()
	for i in 10:
		var left := strength * (1.0 - i / 10.0)
		shake.tween_property(camera, "offset",
				Vector2(_rng.randf_range(-left, left), _rng.randf_range(-left, left)).round(), 0.05)
	shake.tween_property(camera, "offset", Vector2.ZERO, 0.05)


## The item card up beside `slot`, or put away for null. Filled as the card fills itself
## (`ItemCard._process`), which reads the OS mouse rather than the pushed one.
func _card_over(slot: Control) -> void:
	var card: ItemCard = _main._item_card
	card.process_mode = Node.PROCESS_MODE_DISABLED
	if slot == null:
		card.hide()
		return
	UITheme.clear(card._rows)
	ItemDetails.fill(card._rows, (slot as ItemSlot).item, ItemCard.WIDTH)
	card.show()
	card._place(slot.get_global_rect())
	card._place.call_deferred(slot.get_global_rect())

## A full set of `rarity` gear at `level`, one-handed, put straight on.
func _gear_up(level: int, rarity: ItemRarity.Rarity) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var equipment: Equipment = _main.inventory.equipment
	for socket: Equipment.Socket in Equipment.sockets():
		var kinds := Array(LootTable.items()).filter(func(type: String) -> bool:
			return LootTable.slot_of(type) == Equipment.TAKES[socket] and not LootTable.two_handed(type))
		equipment.equip(socket, Item.rolled(kinds[rng.randi() % kinds.size()], rarity, rng, level))
	_main._sync_character()
	_main._show_damage()


func _weapon_type() -> String:
	var weapon: Item = _main.inventory.equipment.worn[Equipment.Socket.WEAPON]
	return weapon.type


## Armed as `_open_fight` arms a fight: from what the hero has on.
func _arm_bag(fight: Encounter) -> void:
	fight.wear(_main.inventory.effects(), Achievements.ranks(_main.inventory))
	fight.arm(_main.inventory.stats())
	fight.crit_rng.seed = WORLD_SEED


## An average blow, crits at their mean (the trailer's counts the Gambler's Die, which nobody wears here).
func _blow(fight: Encounter) -> float:
	return fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0)


## A fight opened the way the map opens one: the HUD under the character panel, the corner put away.
func _fight_here(fight: Encounter, env: String, variant: String, layout := 1, hits := HITS,
		place := "") -> void:
	_arm_bag(fight)
	_open(fight, CELL, variant, layout, env, place, hits)
	_main._combat = _combat
	_main.map.hide()
	_main._panel.hide()
	_main._show_corner(false)
	_main._character.show()


## A farm run on `land` ([environment, variant, layout]), seeded off the land.
func _farm_on(land: Array) -> void:
	var fight := Encounter.farm(CELL, land[0])
	fight.roster_rng.seed = hash(land)
	_fight_here(fight, land[0], land[1], land[2], HITS,
			TileNames.generate(CELL + Vector2i(land[2] * 3, land[2]), land[0], MAP_SEED, "small"))


## Fells bodies off screen until the one at `index` stands: the film starts at the end of a lineup.
func _skip_to(fight: Encounter, index: int) -> void:
	var blow := fight.damage
	fight.damage = 1e15
	while fight.index < index:
		if not fight.hit():
			fight.advance(0.05)
	fight.damage = blow
	while fight.phase != Encounter.Phase.WAITING:
		fight.advance(0.05)
	fight.health[fight.index] = roundf(_blow(fight) * 0.5)
	fight.hp = fight.health[fight.index]
	# The floating numbers and gems of the skipped kills off the screen before the film starts.
	for i in 60:
		await process_frame


## The far side of the land from the start, on the last ring before the ice: the tile nearest the
## window's top, so the hero walks up the screen to it.
func _wall_side(view: MapBuilder) -> Vector2i:
	var best := MapBuilder.CENTER
	for cell: Vector2i in view._tiles:
		if HexGrid.distance(MapBuilder.CENTER, cell) == view.land_radius \
				and _main.map.ground_layer.map_to_local(cell).y < _main.map.ground_layer.map_to_local(best).y:
			best = cell
	return best


## Charts the whole way out to `cell` at once, as the dev's skip does, and walks the hero onto it.
func _walk_far(view: MapBuilder, cell: Vector2i) -> void:
	var reach := view.dark_reach
	view.dark_reach = func() -> int: return 99
	view.chart(cell, 1)
	view.dark_reach = reach
	while view.walking or view.player_cell != cell:
		await process_frame


## The chartable tile beside `cell` nearest the window's top.
func _upward(view: MapBuilder, cell: Vector2i) -> Vector2i:
	var best := cell
	for next: Vector2i in HexGrid.neighbors(cell):
		if view.can_chart(next) and (best == cell or _main.map.ground_layer.map_to_local(next).y
				< _main.map.ground_layer.map_to_local(best).y):
			best = next
	return best


# ---- the pointer

## Where `cell`'s middle is on the window.
func _on_screen(cell: Vector2i) -> Vector2:
	var layer: TileMapLayer = _main.map.ground_layer
	return layer.get_global_transform_with_canvas() * layer.map_to_local(cell)


## The hand over the enemy's middle, as a player's rests there.
func _hand_on_enemy() -> void:
	_cursor.position = Vector2(root.get_visible_rect().size) * Vector2(0.72, 0.53) \
			- HAND_POINT * _cursor.scale
	_cursor.show()


## Moves the pointer's tip onto `to` over `seconds`.
func _point_to(to: Vector2, seconds: float) -> void:
	var move := _cursor.create_tween().set_ignore_time_scale()
	move.tween_property(_cursor, "position", to - HAND_POINT * _cursor.scale, seconds) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	while move.is_running():
		_send_motion()
		await process_frame


## The visible button reading `text` (the last, or with `last` false the first, of several).
func _button(text: String, last := false) -> Button:
	var found: Button = null
	for button: Node in root.find_children("*", "Button", true, false):
		if (button as Button).text == text and (button as Button).is_visible_in_tree():
			found = button
			if not last:
				return found
	return found


## `_button(text)` once it stands: a page that fades in builds its buttons late.
func _shown(text: String) -> Button:
	for i in 120:
		var button := _button(text)
		if button != null:
			return button
		await process_frame
	push_warning("No button reading " + text)
	return null


## The visible square holding `item`, in the bag or on a transcension's.
func _bag_square(item: Item) -> Control:
	for slot: Node in root.get_tree().get_nodes_in_group(ItemSlot.GROUP):
		if (slot as Control).is_visible_in_tree() and slot.get("item") == item:
			return slot
	return null


func _orb_square(orb: String) -> Control:
	for slot: Node in _main.bag_page._orb_tray.get_children():
		if slot is OrbSlot and (slot as OrbSlot).orb == orb:
			return slot
	return null


## Taps under the hand every `every` frames until `second`, through the input the game reads.
func _tap_until(second: float, every: int) -> void:
	while Engine.get_process_frames() < _frame_of(second):
		if (Engine.get_process_frames() - _start) % every == 0:
			_tap()
		await process_frame


## Taps the fight in front until its enemy falls.
func _tap_to_kill() -> void:
	var fight := _combat.fight
	while fight.phase != Encounter.Phase.DYING:
		if (Engine.get_process_frames() - _start) % TAP == 0:
			_tap()
		await process_frame


## `_clicking` with the hand: taps every `TAP` frames until `second`, `tick` first on every frame.
func _clicking_hand(second: float, tick: Callable) -> void:
	while Engine.get_process_frames() < _frame_of(second):
		tick.call(Engine.get_process_frames() - _start)
		if (Engine.get_process_frames() - _start) % TAP == 0 and not _combat.fight.finished:
			_tap()
		await process_frame


## One press and release under the hand, without waiting: a fast tap must not hold the loop.
func _tap() -> void:
	var at := _cursor.position + HAND_POINT * _cursor.scale
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		event.position = at
		event.global_position = at
		root.push_input(event)
	_tap_look()


## The hand's tilt alone, for a tap the staging answers by hand.
func _tap_look() -> void:
	_cursor.rotation = deg_to_rad(-Cursors.TILT)
	var back := _cursor.create_tween().set_ignore_time_scale()
	back.tween_interval(0.06)
	back.tween_property(_cursor, "rotation", 0.0, 0.0)


## A caption over the dirt, punched in at `from` and gone by `to`.
func _say(text: String, from: float, to: float, colour := Palette.BONE, height := LOW,
		font_size := BIG) -> void:
	_caption(text, from, to, height, font_size, colour)
