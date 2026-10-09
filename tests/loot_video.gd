extends "res://tests/clip.gd"
## A farm run clicked through to a unique: bodies falling to one click each, four of them throwing out a
## piece or an orb -- each one "Trash.", bigger every time -- and on the last body the Sage's Abacus, slowed
## down and raised on the collection log's banner: "FINALLY". The hero is a late one (`HERO`: drop rate and
## item rarity a jeweller's worth, every unique unlocked); the rolls are the game's own, on seeds picked up
## front (`_loot_seed`, `_orb_seed`, `_unique_seed`).

## The bodies the clip kills; the unique falls off the last.
const KILLS := 14
## The unique it falls to.
const PRIZE := "sages_abacus"
## How many bodies leave something before it, each said to be trash: all but one a piece, that one an orb.
const TRASH := 4
## What the hero brings besides a blow that fells anything on the tile: finders, and bodies walking in
## quickly. Auto-swings slow, so the clicks do the killing.
const HERO := {"drop_rate": 300.0, "item_rarity": 300.0, "spawn_speed": 60.0, "attack_speed": 0.3,
		"crit_chance": 25.0, "crit_damage": 150.0}
const SEEDS := 200000
## The ground farmed: the first charted tile on it this many steps out, past the first wall (level 6,
## and no tile modifiers short of the second).
const DISTANCE := 21
const ENV := "forest"

var fight: Encounter
## How many times "Trash." has come up.
var _trashed := 0
## Whether the unique has fallen, which ends the clicking at once: its slow motion would stretch any wait.
var _finally := false


func _run() -> void:
	var inventory: Inventory = await _open_main("loot")
	# Long past the first sword, the first orb and the kills a unique waits for.
	inventory.first_sword_taken = true
	inventory.first_orb_taken = true
	inventory.kills = 5000
	# Deep enough into the levels that a few bodies' experience raises no "Level up" over the captions.
	inventory.level = 60
	main._sync_character()
	# The first wall down and every tile inside the second charted.
	main.view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	main.view._cover()
	main.view.reveal_all()
	var cell := _farm_cell()
	main.view.player_cell = cell
	main.map.set_player_cell(cell)
	fight = Encounter.farm(cell, ENV, main.view.area_variant(cell), main._mods_of(cell))
	# A run's lineup is drawn on an unseeded generator: drawn again here on a seeded one, every body the
	# clip fights up front, so the same monsters come every time and the seeds below mean the same thing.
	fight.roster_rng.seed = WORLD_SEED
	fight.lineup.clear()
	fight.health.clear()
	while fight.lineup.size() < KILLS + 3:
		fight._append_enemy(fight.roster_rng)
	fight.hp = fight.health[0]
	main._open_fight(fight, cell, true)
	# Armed by hand below, and kept so: a save mid-run would arm it again off the scratch inventory.
	main.inventory.save_written.disconnect(main._rearm)
	fight.stone_drops = false
	fight.unlocked = UniqueTable.UNIQUES.keys()
	var stats := inventory.stats()
	stats.merge(HERO, true)
	stats["damage"] = Array(fight.health.slice(0, KILLS)).max() * 1.2
	fight.arm(stats)
	var seeds := _drop_seeds()
	fight.loot_rng.seed = seeds[0]
	fight.orb_rng.seed = seeds[1]
	fight.unique_rng.seed = _unique_seed()
	print("Loot seed %d, orb seed %d, unique seed %d" % [fight.loot_rng.seed, fight.orb_rng.seed,
			fight.unique_rng.seed])
	fight.crit_rng.seed = WORLD_SEED
	fight.loot_dropped.connect(_on_find)
	fight.orb_dropped.connect(func(_index: int, _orb: String) -> void: _trash())

	# The whole window, blown up 3x: the unique's banner is wider than `FRAME`. The captions in the sky
	# between that banner and the fighters' heads.
	_show(Rect2(Vector2.ZERO, root.size))
	_caption_middle = 256.0
	while fight.phase != Encounter.Phase.WAITING:
		await process_frame
	var home := _enemy_spot()
	_pointer = home + Vector2(60, 90)
	await create_timer(0.3).timeout

	_start()
	await _glide(home, 0.35)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = WORLD_SEED
	while not _finally:
		_pointer = home + Vector2(jitter.randf_range(-4, 4), jitter.randf_range(-4, 4)).round()
		await _click(0.04, 0.08)
	# Seconds of the clip, not of the unique's slowed-down game.
	await create_timer(2.0, true, false, true).timeout
	_size(UITheme.FONT_SIZE * 2)
	_say("", "")
	_say("Kobold Clicker", "")
	await create_timer(1.5, true, false, true).timeout
	await _end()


## Each find as it falls: trash, whatever it is, until the unique.
func _on_find(_index: int, item: Item) -> void:
	if item.rarity != ItemRarity.Rarity.UNIQUE:
		_trash()
		return
	_finally = true
	# As big as the frame has room for, a whole step of the font at a time.
	var size := UITheme.FONT_SIZE * 2
	while _width("FINALLY", size + UITheme.FONT_SIZE) <= _frame.size.x - 24.0:
		size += UITheme.FONT_SIZE
	_size(size)
	print("FINALLY at %d px, frame %d" % [size, Engine.get_frames_drawn()])
	_say("", "")
	_say("FINALLY", "")


## "Trash." again, a step of the font bigger than the last: 16, 32, 48, 64.
func _trash() -> void:
	_trashed += 1
	print("TRASH %d at frame %d" % [_trashed, Engine.get_frames_drawn()])
	_size(UITheme.FONT_SIZE * _trashed)
	_say("", "")
	_say("Trash.", "")


## The big caption at `size`, a whole multiple of the font's own 16 so it stays crisp, its outline and
## shadow growing with it.
func _size(size: int) -> void:
	_caption.add_theme_font_size_override("font_size", size)
	_caption.add_theme_constant_override("outline_size", 4 + size / 8)
	_caption.add_theme_constant_override("shadow_outline_size", 4 + size / 8)
	_caption.add_theme_constant_override("shadow_offset_x", 1 + size / 16)
	_caption.add_theme_constant_override("shadow_offset_y", 1 + size / 12)


func _width(text: String, size: int) -> float:
	return _caption.get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x 			+ 4 + size / 8


## The first tile `DISTANCE` steps out on `ENV` that can be farmed.
func _farm_cell() -> Vector2i:
	for cell in FortuneTeller.scour_cells(MapBuilder.CENTER, DISTANCE):
		if HexGrid.distance(MapBuilder.CENTER, cell) == DISTANCE and main.view.env_at(cell) == ENV \
				and main.view.can_farm(cell):
			return cell
	push_error("No %s tile %d steps out to farm" % [ENV, DISTANCE])
	return MapBuilder.CENTER


## Where the standing body's middle is.
func _enemy_spot() -> Vector2:
	var enemy: CombatActor = main._combat._enemy
	return (enemy.global_position - Vector2(0, enemy.drawn_size().y * 0.5)).round()


## The gear one body leaves, rolled as `Encounter._kill` rolls it for a run with no curse or unique worn:
## a chance, and again for as long as it comes up, to `MOST_DROPS`.
func _gear(index: int, rng: RandomNumberGenerator) -> Array[Item]:
	var finds: Array[Item] = []
	var roll := func() -> Item:
		return LootTable.roll(fight.lineup[index], rng, false, fight._level(), fight._gear_rate(), fight.item_rarity)
	var dropped: Item = roll.call()
	while dropped != null:
		finds.append(dropped)
		dropped = null if finds.size() >= Encounter.MOST_DROPS else roll.call()
	return finds


## [loot seed, orb seed]: the two whose drops tell the story -- `TRASH` - 1 bodies leaving one piece each,
## a rare and an epic among them for the beams' sake, and one more body an orb -- every drop two or three
## bodies after the last, the first two or three in, and the unique two or three after the last of them.
func _drop_seeds() -> Array:
	# The first orb seed that drops one orb, off each body, and nothing else.
	var orb_at := {}
	for candidate in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var bodies: Array[int] = []
		for index in KILLS:
			if not OrbTable.roll(fight.lineup[index], rng, false, Encounter._lifted(fight.orb_find
					+ fight.drop_rate, 1.0), fight.walls_down).is_empty():
				bodies.append(index)
		if bodies.size() == 1 and not orb_at.has(bodies[0]):
			orb_at[bodies[0]] = candidate
			if orb_at.size() == KILLS:
				break
	for candidate in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		var bodies: Array[int] = []
		var rarities: Array[int] = []
		for index in KILLS:
			var finds := _gear(index, rng)
			if not finds.is_empty():
				bodies.append(index)
				rarities.append_array(finds.map(func(item: Item) -> int: return item.rarity))
		if bodies.size() != TRASH - 1 or rarities.size() != bodies.size() 				or not ItemRarity.Rarity.RARE in rarities or not ItemRarity.Rarity.ELITE in rarities:
			continue
		for orb: int in orb_at:
			if not orb in bodies and _even(bodies + [orb]):
				return [candidate, orb_at[orb]]
	push_error("No pair of seeds in %d tells the story" % SEEDS)
	return [0, 0]


## Whether drops off these bodies come in an even beat: two or three bodies apart, from the start and up
## to the last body's unique.
func _even(bodies: Array) -> bool:
	var beats: Array = [-1] + bodies + [KILLS - 1]
	beats.sort()
	for i in beats.size() - 1:
		if beats[i + 1] - beats[i] < 2 or beats[i + 1] - beats[i] > 3:
			return false
	return true


## The seed whose first unique falls off the last body, and is `PRIZE`.
func _unique_seed() -> int:
	for candidate in SEEDS:
		var rng := RandomNumberGenerator.new()
		rng.seed = candidate
		for index in KILLS:
			var found := UniqueTable.roll(fight.lineup[index], fight.unlocked, rng, fight._level(),
					Encounter._lifted(fight.drop_rate, 1.0), false, fight.item_rarity)
			if found != null:
				if index == KILLS - 1 and found.unique == PRIZE:
					return candidate
				break
	push_error("No unique seed in %d drops %s off body %d" % [SEEDS, PRIZE, KILLS])
	return 0
