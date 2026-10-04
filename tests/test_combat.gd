extends "res://tests/harness.gd"
## Headless checks for the tile fight. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_combat.gd
## Plays whole encounters through Encounter.advance and Encounter.hit, with no scene and no window.

## Never the player's own two saves: the scene test fights, drops loot and explores. They are cleared
## at the *start* of a run rather than the end, because the scene writes its map from _exit_tree,
## which fires as the tree comes down after the last line of _run -- so a run always leaves one
## behind, and only the next run starting clean can be relied on. A map left over from last time
## would be loaded, and the fight would be handed a tile that had already been taken.
const SCRATCH_INVENTORY := "user://test_combat_inventory.json"
const SCRATCH_MAP := "user://test_combat_map.json"


func _run() -> void:
	_clear_saves()
	_check(_test_lineup() == true, "lineup tests ran to the end")
	_check(_test_the_dreadmask() == true, "dreadmask tests ran to the end")
	_check(_test_health() == true, "health tests ran to the end")
	_check(_test_a_won_fight() == true, "won fight tests ran to the end")
	_check(_test_the_ice_wall() == true, "ice wall tests ran to the end")
	_check(_test_the_dungeon() == true, "dungeon tests ran to the end")
	_check(_test_a_lost_fight() == true, "lost fight tests ran to the end")
	_check(_test_enemy_strikes() == true, "enemy strike tests ran to the end")
	_check(_test_guard_capstones() == true, "guard capstone tests ran to the end")
	_check(_test_hits_only_land_on_a_waiting_enemy() == true, "hit timing tests ran to the end")
	_check(_test_what_a_hit_is_worth() == true, "damage tests ran to the end")
	_check(_test_the_weapon_swings_itself() == true, "attack speed tests ran to the end")
	_check(_test_the_hand_is_capped() == true, "click cap tests ran to the end")
	_check(_test_spawn_speed() == true, "spawn speed tests ran to the end")
	_check(_test_bleed() == true, "bleed tests ran to the end")
	_check(_test_capstone_effects() == true, "capstone effect tests ran to the end")
	_check(_test_unique_drops() == true, "unique drop tests ran to the end")
	_check(_test_unique_effects() == true, "unique effect tests ran to the end")
	_check(_test_more_unique_effects() == true, "second batch unique effect tests ran to the end")
	_check(_test_dominoes() == true, "dominoes tests ran to the end")
	_check(_test_unique_ranks() == true, "unique rank tests ran to the end")
	_check(_test_rank_four() == true, "rank IV tests ran to the end")
	_check(_test_backdrops() == true, "backdrop tests ran to the end")
	_check(_test_backdrop_layouts() == true, "backdrop layout tests ran to the end")
	_check(_test_skies() == true, "sky tests ran to the end")
	_check(_test_a_farm_run_never_ends() == true, "farm run tests ran to the end")
	_check(_test_a_settlement_is_a_set_piece() == true, "settlement fight tests ran to the end")
	_check(_test_a_chest_is_a_mimic() == true, "chest fight tests ran to the end")
	_check(_test_gold() == true, "gold tests ran to the end")
	_check(_test_experience() == true, "experience tests ran to the end")
	_check(_test_coins() == true, "coin tests ran to the end")
	_check(_test_orb_drops() == true, "orb drop tests ran to the end")
	_check(_test_drop_rate_finds_everything() == true, "drop rate tests ran to the end")
	_check(_test_even_loot() == true, "even loot tests ran to the end")
	_check(_test_starter_rules() == true, "starter unique tests ran to the end")
	_check(_test_fight_tally() == true, "fight tally tests ran to the end")
	_check(_test_tile_mods() == true, "tile modifier tests ran to the end")
	_check(_test_curses() == true, "curse tests ran to the end")
	_check(_test_more_curses() == true, "second batch curse tests ran to the end")
	_check(_test_sounds() == true, "sound tests ran to the end")
	await _test_thrown_finds()
	await _test_the_longest_stop_wins()
	await _test_settings()
	await _test_the_nameplate_wears_the_tier()
	await _test_the_backdrop_goes_by()
	await _test_the_map_hands_over_and_takes_back()
	await _test_the_nightwalkers_fight_their_way()
	await _test_a_world_under_the_fog()
	await _test_the_way_down()
	_report("combat")


func _clear_saves() -> void:
	for path in [SCRATCH_INVENTORY, SCRATCH_MAP]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _environments() -> PackedStringArray:
	var envs := PackedStringArray()
	for env: String in SheetMeta.env_adjacency():
		envs.append(env)
	return envs


## Spawn speed is a share taken off the walk-in, and at the cap there is no walk-in at all.
func _test_spawn_speed() -> bool:
	var half := Encounter.for_tile(Vector2i(3, 0), "grass")
	half.arm({"spawn_speed": 50.0})
	half.arm({"spawn_speed": 50.0})
	half.start()
	_check(is_equal_approx(half.walk_in, Encounter.WALK_IN * 0.5),
			"50%% halves the walk-in, armed twice or once (%.2f)" % half.walk_in)
	half.advance(Encounter.WALK_IN * 0.5)
	_check(half.phase == Encounter.Phase.WAITING, "and the enemy is there in half the time")

	var instant := Encounter.for_tile(Vector2i(3, 0), "grass")
	instant.arm({"spawn_speed": 250.0})
	instant.start()
	_check(instant.spawn_speed == 100.0 and instant.walk_in == 0.0, "past 100%% is 100%%, and no walk-in")
	instant.advance(0.001)
	_check(instant.phase == Encounter.Phase.WAITING, "the first enemy is simply there")
	instant.hp = 1.0
	instant.hit()
	instant.advance(Encounter.DEATH + 0.001)
	_check(instant.index == 1 and instant.phase == Encounter.Phase.WAITING,
			"and the next is there the moment the death has played")
	return true


## What a click takes off, and what a crit turns it into.
func _test_what_a_hit_is_worth() -> bool:
	var fight := Encounter.for_tile(Vector2i(3, 0), "grass")
	fight.start()
	fight.advance(Encounter.WALK_IN)
	_check(fight.damage == Encounter.BARE_DAMAGE, "an unarmed fight does %d a click" % Encounter.BARE_DAMAGE)
	_check(fight.attack_speed == 0.0, "and nothing swings on its own")
	var before := fight.hp
	fight.hit()
	_check(fight.hp == before - Encounter.BARE_DAMAGE, "a bare-handed click takes one point off")

	# Gear is read once, and a sword is worth its damage on top of the fist, never instead of it.
	var armed := Encounter.for_tile(Vector2i(3, 0), "grass")
	armed.arm({"damage": 4.0, "crit_chance": 0.0, "crit_damage": 50.0, "attack_speed": 0.0})
	armed.start()
	armed.advance(Encounter.WALK_IN)
	var landed: Array = []
	armed.hit_landed.connect(func(amount: float, crit: bool, auto: bool) -> void:
		landed.append([amount, crit, auto]))
	var full := armed.hp
	armed.hit()
	_check(armed.damage == 5, "four points of gear plus the fist is five")
	_check(armed.hp == full - 5, "and five comes off")
	_check(landed.size() == 1 and landed[0] == [5.0, false, false],
			"the blow is reported as a click for five")

	# A certain crit adds its crit damage, and no more: 50 is half again, not fifty times.
	var critting := Encounter.for_tile(Vector2i(3, 0), "grass")
	critting.arm({"damage": 3.0, "crit_chance": 100.0, "crit_damage": 50.0, "attack_speed": 0.0})
	critting.start()
	critting.advance(Encounter.WALK_IN)
	var crits: Array = []
	critting.hit_landed.connect(func(_a: float, crit: bool, _auto: bool) -> void: crits.append(crit))
	var start_hp := critting.hp
	critting.hit()
	_check(critting.hp == start_hp - 6, "a crit on four damage at +50%% is six, not %d"
			% (start_hp - critting.hp))
	_check(crits == [true], "and says it crit")

	# Crit chance is a percentage, so zero never crits however many times it is asked.
	var never := Encounter.for_tile(Vector2i(0, 0), "grass")
	never.arm({"damage": 1.0, "crit_chance": 0.0, "crit_damage": 500.0, "attack_speed": 0.0})
	never.start()
	never.advance(Encounter.WALK_IN)
	var any := [false]
	never.hit_landed.connect(func(_a: float, crit: bool, _auto: bool) -> void: any[0] = any[0] or crit)
	for i in 200:
		never.hit()
		if never.phase != Encounter.Phase.WAITING:
			never.advance(Encounter.DEATH + Encounter.WALK_IN)
	_check(not any[0], "no crit chance never crits")

	# And a chance in between is a chance: a quarter crits about a quarter of the time, not always.
	# Loose bounds on purpose -- this holds that the roll happens at all, not that the RNG is fair.
	var sometimes := Encounter.farm(Vector2i(0, 0), "grass")
	sometimes.arm({"damage": 1.0, "crit_chance": 25.0, "crit_damage": 50.0, "attack_speed": 0.0})
	sometimes.start()
	sometimes.advance(Encounter.WALK_IN)
	var tally := [0, 0]
	sometimes.hit_landed.connect(func(_a: float, crit: bool, _auto: bool) -> void:
		tally[0] += 1
		tally[1] += 1 if crit else 0)
	for i in 2000:
		sometimes.hit()
		if sometimes.phase != Encounter.Phase.WAITING:
			sometimes.advance(Encounter.DEATH + Encounter.WALK_IN)
	var share := 100.0 * float(tally[1]) / float(maxi(int(tally[0]), 1))
	_check(share > 15.0 and share < 35.0, "a quarter crit chance crits about a quarter (%.0f%%)" % share)

	# Gear that adds up past certainty is still a chance, not a promise: a save written before a
	# probability stopped taking the level multiplier holds pieces that do exactly that.
	var piled := Encounter.for_tile(Vector2i(0, 0), "grass")
	piled.arm({"damage": 1.0, "crit_chance": 400.0, "crit_damage": 50.0, "attack_speed": 0.0})
	_check(piled.crit_chance == Encounter.CRIT_CAP, "crit chance is capped at %d%%" % Encounter.CRIT_CAP)
	return true


## The weapon swinging on its own: it lands, it counts, and it earns nothing while there is nobody
## standing there to hit.
func _test_the_weapon_swings_itself() -> bool:
	var fight := Encounter.for_tile(Vector2i(40, 0), "grass")
	fight.arm({"damage": 0.0, "crit_chance": 0.0, "crit_damage": 0.0, "attack_speed": 2.0})
	fight.start()
	var automatic := [0]
	fight.hit_landed.connect(func(_a: float, _c: bool, auto: bool) -> void:
		if auto:
			automatic[0] += 1)

	# Nothing swings while the first enemy is still walking in.
	fight.advance(Encounter.WALK_IN * 0.5)
	_check(automatic[0] == 0, "the weapon waits for something to hit")
	fight.advance(Encounter.WALK_IN * 0.5)
	_check(fight.phase == Encounter.Phase.WAITING, "the enemy is up")

	# Two a second means two in a second, whether that second arrives in one step or in many.
	fight.advance(1.0)
	_check(automatic[0] == 2, "two swings in a second, not %d" % automatic[0])
	for i in 10:
		fight.advance(0.1)
	_check(automatic[0] == 4, "and two more across ten tenths, not %d" % (automatic[0] - 2))

	# A fight with a weapon and no hands at all still gets somewhere, which is what idle damage is.
	var idle := Encounter.for_tile(Vector2i(1, 0), "grass")
	idle.arm({"damage": 9.0, "crit_chance": 0.0, "crit_damage": 0.0, "attack_speed": 8.0})
	idle.start()
	for i in int(Encounter.SECONDS / 0.05):
		idle.advance(0.05)
	_check(idle.finished and idle.victory, "a fast weapon wins the first ring on its own")

	var piled := Encounter.for_tile(Vector2i(1, 0), "grass")
	piled.arm({"attack_speed": Encounter.SWING_CAP * 4.0})
	_check(piled.attack_speed == Encounter.SWING_CAP, "speed past the cap swings at the cap")
	return true


## The hand's allowance: a burst lands whole, then it fills at `CLICK_CAP` a second, so a hand a
## click a second too fast loses only the clicks past the cap and one under it loses nothing.
## `hit()` is never capped. Counted by the tally, which counts every click that gets through.
func _test_the_hand_is_capped() -> bool:
	var spam := Encounter.farm(Vector2i(0, 0), "grass")
	spam.start()
	for i in 10:
		spam.click()
	_check(spam.tally.get("clicks") == int(Encounter.CLICK_BURST),
			"a burst gets its allowance through, not %d" % spam.tally.get("clicks"))
	for i in 10:
		spam.hit()
	_check(spam.tally.get("clicks") == int(Encounter.CLICK_BURST) + 10, "and a hit is never capped")

	for rate: float in [Encounter.CLICK_CAP - 1.0, Encounter.CLICK_CAP + 1.0]:
		var hand := Encounter.farm(Vector2i(0, 0), "grass")
		hand.start()
		var n := int(rate * 60.0)
		for i in n:
			hand.click()
			hand.advance(1.0 / rate)
		var through: int = hand.tally.get("clicks")
		var most := mini(n, int(Encounter.CLICK_BURST + Encounter.CLICK_CAP * (n - 1) / rate))
		_check(absi(through - most) <= 1, "%d a second for a minute: %d of %d through, not %d"
				% [rate, most, n, through])
	return true


## The mace's Bleed: a share of the blow that goes on coming off while the body stands there, the
## deepest wound and never a pile of them, and a death it can bring about on its own.
func _test_bleed() -> bool:
	# Twenty points at a quarter is five a second, and the bar moves with it.
	var mace := _standing([], {"damage": 19.0, "bleed": 25.0}, 1000.0)
	_check(mace.bleed == 25.0, "the fight is armed with what the mace leaves behind")
	mace.hit()
	_check(mace.hp == 980.0 and mace._bleed == 5.0,
			"a blow of 20 at a quarter leaves 5 a second (%s)" % mace._bleed)
	var left: Array = []
	mace.enemy_hit.connect(func(hp_left: float) -> void: left.append(hp_left))
	mace.advance(2.0)
	_check(is_equal_approx(mace.hp, 970.0), "two seconds of it cost ten (%s)" % (980.0 - mace.hp))
	_check(left == [970.0], "and the bar is told once (%s)" % [left])

	# A wound is deepened, never stacked: only a bigger blow than the one that opened it counts.
	mace.hit()
	_check(mace._bleed == 5.0, "an equal blow neither stacks nor deepens (%s)" % mace._bleed)
	mace.damage = 5.0
	mace.hit()
	_check(mace._bleed == 5.0, "and a weaker one leaves the deeper wound alone (%s)" % mace._bleed)
	mace.damage = 20.0
	mace.crit_chance = 100.0
	mace.crit_damage = 100.0
	mace.hit()
	_check(mace._bleed == 10.0, "a crit's bigger blow does deepen it (%s)" % mace._bleed)

	# It kills with nobody swinging, and that death pays exactly what any other death pays.
	var last := _standing([], {"damage": 9.0, "bleed": 100.0}, 30.0)
	last.always_drop = true
	last.loot_rng.seed = WORLD_SEED
	var finds: Array = []
	var purses: Array = []
	var earned: Array = []
	var deaths: Array = []
	last.loot_dropped.connect(func(_i: int, item: Item) -> void: finds.append(item))
	last.gold_dropped.connect(func(_i: int, amount: float) -> void: purses.append(amount))
	last.xp_dropped.connect(func(_i: int, amount: int) -> void: earned.append(amount))
	last.enemy_died.connect(func(i: int) -> void: deaths.append(i))
	last.hit()
	_check(last.hp == 20.0 and last._bleed == 10.0, "ten a second on a body with twenty left")
	last.advance(2.0)
	_check(last.hp <= 0.0 and last.phase == Encounter.Phase.DYING,
			"the wound finishes it with nobody swinging (%s left)" % last.hp)
	_check(deaths == [0] and finds.size() == 1 and purses.size() == 1 and earned.size() == 1,
			"and the body pays out like any other (%d find(s), %d purse(s))" % [finds.size(), purses.size()])
	_check(last.gold == purses[0] and last.xp == earned[0], "into the fight's own sums")
	last.advance(Encounter.DEATH)
	_check(last.kills() == 1, "it counts as a kill (%d)" % last.kills())

	# The wound belongs to that body: the next one walks in whole and bleeds nothing until it is cut.
	_check(last._bleed == 0.0, "the wound does not follow the body off the field")
	last.advance(Encounter.WALK_IN)
	var fresh := last.hp
	last.advance(1.0)
	_check(last.hp == fresh, "and the next one loses nothing until it is cut (%s of %s)" % [last.hp, fresh])

	# Nothing comes off a body already going down, nor off one still running in.
	var dying := _standing([], {"damage": 19.0, "bleed": 50.0}, 30.0)
	dying.hit()
	dying.hit()
	_check(dying.phase == Encounter.Phase.DYING and dying._bleed == 10.0,
			"the wound outlives the blow that killed")
	var spilt := dying.hp
	dying.advance(Encounter.DEATH * 0.5)
	_check(dying.hp == spilt, "a body going down loses nothing more")
	dying.advance(Encounter.DEATH * 0.5)
	dying._bleed = 10.0
	var coming := dying.hp
	dying.advance(Encounter.WALK_IN * 0.5)
	_check(dying.phase == Encounter.Phase.WALKING_IN and dying.hp == coming,
			"and neither does one still running in")

	# The wound is the body's own: the next one comes on whole.
	var grave := _standing([], {"damage": 19.0, "bleed": 50.0}, 30.0)
	grave.hit()
	_check(grave._bleed == 10.0, "the wound is open when it falls")
	grave.hit()
	grave.advance(Encounter.DEATH)
	_check(grave._bleed == 0.0, "the next body comes on whole")
	grave.advance(Encounter.WALK_IN)
	var whole := grave.hp
	grave.advance(1.0)
	_check(grave.hp == whole, "and loses nothing standing there (%s of %s)" % [grave.hp, whole])

	# A weapon with no bleed on it fights exactly the fight this was -- a stat at zero is a stat
	# absent -- and one with bleed on it gets there sooner. The same seeded tile, blow for blow.
	var scores := []
	for worn: Dictionary in [{}, {"bleed": 0.0}, {"bleed": 100.0}]:
		var stats := {"damage": 4.0, "crit_chance": 50.0, "crit_damage": 50.0, "attack_speed": 1.0}
		stats.merge(worn)
		var fight := Encounter.for_tile(Vector2i(4, 0), "grass")
		fight.arm(stats)
		fight.crit_rng.seed = WORLD_SEED
		fight.loot_rng.seed = WORLD_SEED
		fight.orb_rng.seed = WORLD_SEED
		fight.start()
		var clicks := _play(fight, 4000)
		scores.append([clicks, fight.time_left, fight.gold, fight.xp, fight.victory])
	_check(scores[0] == scores[1],
			"no bleed is the fight this always was (%s against %s)" % [scores[0], scores[1]])
	# Fewer clicks, which is what a bleed is for. Not less clock: the walk-ins and the deaths are
	# eleven of those seconds whatever the player does, so the clock is no measure of the fighting.
	_check(int(scores[2][0]) < int(scores[0][0]) and bool(scores[2][4]),
			"and a bleeding weapon wins it in fewer (%s against %s)" % [scores[2], scores[0]])
	return true


## The last row of each skill tree changes the fight rather than a number.
func _test_capstone_effects() -> bool:
	var cell := Vector2i(12, 0)
	# Execute: a blow that leaves a sliver finishes the body.
	var exe := Encounter.for_tile(cell, "grass")
	exe.effects = ["execute"]
	exe.start()
	exe.advance(Encounter.WALK_IN)
	exe.arm({"damage": float(exe.hp - int(exe.enemy_max_hp() * 0.05) - Encounter.BARE_DAMAGE)})
	exe.hit()
	_check(exe.phase == Encounter.Phase.DYING, "Execute kills under a tenth (%d left)" % exe.hp)

	# Cleave: what a kill does past the body comes off the next one.
	var cleave := Encounter.for_tile(cell, "grass")
	cleave.effects = ["cleave"]
	cleave.start()
	cleave.advance(Encounter.WALK_IN)
	cleave.arm({"damage": float(cleave.hp + 2 - Encounter.BARE_DAMAGE)})
	cleave.hit()
	cleave.advance(Encounter.DEATH)
	_check(cleave.hp == maxf(1.0, cleave.health[1] - 2), "Cleave carries 2 into the next (%d of %d)"
			% [cleave.hp, cleave.health[1]])

	# Giant Slayer: an elite takes twice the blow, a common does not.
	var slayer := Encounter.for_tile(cell, "grass")
	slayer.effects = ["giant_slayer"]
	slayer.arm({"damage": 0.0})
	slayer.start()
	slayer.advance(Encounter.WALK_IN)
	var before := slayer.hp
	slayer.hit()
	_check(slayer.hp == before - 1, "a common takes one")
	slayer.index = slayer.enemies - 1
	slayer.hp = slayer.health[slayer.index]
	before = slayer.hp
	slayer.hit()
	_check(slayer.on_elite() and slayer.hp == before - 2, "the elite takes two")

	# Trophy: the elite always leaves something, with no drop rate at all.
	var drops := [0]
	for i in 20:
		var trophy := Encounter.for_tile(cell, "grass")
		trophy.effects = ["trophy"]
		trophy.loot_rng.seed = WORLD_SEED + i
		trophy.index = trophy.enemies - 1
		trophy.hp = 1
		trophy.phase = Encounter.Phase.WAITING
		trophy.loot_dropped.connect(func(_i: int, _item: Item) -> void: drops[0] += 1)
		trophy.hit()
	_check(drops[0] == 20, "Trophy makes every elite drop (%d of 20)" % drops[0])

	# Jackpot and Transmute: over many kills, some purses are fivefold and some orbs come in pairs.
	var gold := {"plain": 0, "lucky": 0}
	var orbs := {"plain": 0, "lucky": 0}
	for kind: String in gold:
		var run := Encounter.farm(cell, "grass")
		run.always_orb = true
		run.arm({"damage": 100000.0})
		if kind == "lucky":
			run.effects = ["jackpot", "transmute"]
		run.loot_rng.seed = WORLD_SEED
		run.orb_rng.seed = WORLD_SEED
		run.start()
		for i in 400:
			run.advance(Encounter.WALK_IN)
			run.hit()
			run.advance(Encounter.DEATH)
		gold[kind] = run.gold
		var total := 0
		for orb: String in run.orbs:
			total += int(run.orbs[orb])
		orbs[kind] = total
	_check(gold["lucky"] > gold["plain"] * 1.2, "Jackpot fills purses (%s)" % [gold])
	_check(orbs["plain"] == 400 and orbs["lucky"] > 450, "Transmute doubles some orbs (%s)" % [orbs])
	return true


## Every place the world can send the player to has a backdrop -- a sky, its land and its ground --
## and anything else falls back rather than leaving a fight with nothing behind it.
func _test_backdrops() -> bool:
	for env in _environments():
		var fight := Encounter.for_tile(Vector2i(1, 2), env)
		_check(fight.env == env, "the fight on %s knows its terrain" % env)
		for variant in ["plain", "road", "village", "town", "fortress"]:
			for layout in range(1, CombatScene.AREA_LAYOUTS + 1):
				var path: String = CombatScene.AREA_PATH % [env, variant, layout]
				_check(ResourceLoader.exists(path),
						"%s has a %s backdrop (%d)" % [env, variant, layout])
				var layers := CombatScene.backdrop_layers(env, variant, layout, "noon")
				_check(layers.size() >= 4 and layers[-1][0] == load(path),
						"%s/%s/%d is a sky, two bands of land or more, and its ground in front"
								% [env, variant, layout])
				# The fighters are placed as a share of the picture and snap to its pixel, so every
				# layer is the one grid: one that was not would stand them off the ground.
				var grid := true
				var rising := true
				for i in layers.size():
					grid = grid and layers[i][0] != null and layers[i][0].get_size() == Vector2(384, 216)
					rising = rising and (i == 0 or float(layers[i][1]) > float(layers[i - 1][1]))
				_check(grid, "%s/%s/%d: every layer on the fighters' grid" % [env, variant, layout])
				# Nearer goes faster, or the depth reads inside out.
				_check(rising and layers[0][1] == 0.0 and layers[-1][1] == 1.0,
						"%s/%s/%d: from the still sky to the ground at walking pace" % [env, variant, layout])

	var fallback := CombatScene.backdrop_layers("swamp", "plain", 1, "noon")
	_check(fallback[-1][0] == load(CombatScene.AREA_FALLBACK) and fallback.size() >= 4,
			"terrain with no art falls back, land and all")
	# A layout number that was never drawn is clamped rather than left as a missing file: the number
	# comes out of a hash, and a fight with no picture behind it would be unplayable.
	_check(CombatScene.backdrop_layers("grass", "village", 99, "noon")[-1][0]
			== load(CombatScene.AREA_PATH % ["grass", "village", CombatScene.AREA_LAYOUTS]),
			"a layout past the end clamps")
	_check(CombatScene.backdrop_layers("grass", "village", 0, "noon")[-1][0]
			== load(CombatScene.AREA_PATH % ["grass", "village", 1]), "and so does one before it")
	_check(CombatScene.backdrop_layers("grass", "plain", 1, "purple")[0][0]
			== load(CombatScene.SKY_PATH % CombatScene.SKY_HOURS[0][1]), "and a sky with no picture")
	return true


## The sky is the player's clock's: each comes up at its hour and holds until the next, the small
## hours are still the night before, and every sky has its picture and its light.
func _test_skies() -> bool:
	var hours := CombatScene.SKY_HOURS
	_check(CombatScene.sky_at(0) == hours[-1][1] and CombatScene.sky_at(int(hours[0][0]) - 1) == hours[-1][1],
			"the small hours are still the last sky of the day before")
	for i in hours.size():
		var sky: String = hours[i][1]
		var next := int(hours[i + 1][0]) if i + 1 < hours.size() else 24
		_check(CombatScene.sky_at(int(hours[i][0])) == sky and CombatScene.sky_at(next - 1) == sky,
				"%s is up from %d until %d" % [sky, hours[i][0], next])
		_check(ResourceLoader.exists(CombatScene.SKY_PATH % sky) and CombatScene.SKY_LIGHT.has(sky),
				"%s has its picture and its light" % sky)
	_check(CombatScene.SKY_LIGHT.size() == hours.size(), "and every sky with a light comes up at some hour")
	return true


## A tile always fights on the same backdrop, and neighbouring tiles do not all fight on one.
func _test_backdrop_layouts() -> bool:
	var cell := Vector2i(3, 4)
	var pick := CombatScene.layout_for(cell)
	_check(CombatScene.layout_for(cell) == pick, "a tile keeps its backdrop")
	_check(pick >= 1 and pick <= CombatScene.AREA_LAYOUTS, "and it is one that was drawn")
	var seen := {}
	for x in 40:
		for y in 4:
			seen[CombatScene.layout_for(Vector2i(x, y))] = true
	_check(seen.size() == CombatScene.AREA_LAYOUTS,
			"all %d layouts turn up on a map (saw %d)" % [CombatScene.AREA_LAYOUTS, seen.size()])
	return true


## Nine commons and an elite, never a boss, all of them native to the tile's terrain.
func _test_lineup() -> bool:
	for env in _environments():
		var fight := Encounter.for_tile(Vector2i(3, 4), env)
		# The nameplate's title: nothing for a common, a word for the elite, and the same word twice.
		_check(fight.enemy_title().is_empty(), "%s: a common has no title" % env)
		fight.index = fight.enemies - 1
		_check(Encounter.ELITE_TITLES.has(fight.enemy_title()), "%s: the elite has a title" % env)
		_check(fight.enemy_title() == fight.enemy_title(), "and it is the same one every time")
		_check(Encounter.TITLE_GROUND.has(env), "%s has ground a boss can hold" % env)
		fight.index = 0
		_check(fight.enemies == Encounter.ENEMIES and fight.seconds == Encounter.SECONDS,
				"%s fights open land's own fight: %d in %.0fs" % [env, fight.enemies, fight.seconds])
		_check(fight.lineup.size() == fight.enemies, "%s fields %d enemies" % [env, fight.enemies])
		for i in fight.lineup.size():
			var enemy: String = fight.lineup[i]
			var tier := EnemyRoster.tier_of(enemy)
			var wanted := EnemyRoster.Tier.ELITE if i == fight.enemies - 1 else EnemyRoster.Tier.COMMON
			_check(tier == wanted, "%s sends %s (%s) as number %d" % [env, enemy, tier, i + 1])
			# The HUD's bar draws a farm run's pips before their enemies are rolled, so it asks the
			# position rather than the roster. The two must never drift.
			_check(fight.tier_for(i) == tier,
					"tier_for(%d) agrees with the enemy the lineup put there" % i)
			_check(tier != EnemyRoster.Tier.BOSS, "%s is no boss" % enemy)
			_check(env in EnemyRoster.environments_of(enemy), "%s lives on %s" % [enemy, env])
		_check(EnemyRoster.tier_of(fight.lineup[fight.enemies - 1]) == EnemyRoster.Tier.ELITE,
				"%s ends on an elite" % env)

	# A tile always fields the same fight, however often it is attempted.
	var again := Encounter.for_tile(Vector2i(3, 4), "grass")
	_check(again.lineup == Encounter.for_tile(Vector2i(3, 4), "grass").lineup, "a tile keeps its enemies")
	var differ := 0
	for cell: Vector2i in [Vector2i(1, 0), Vector2i(0, 2), Vector2i(-4, 6), Vector2i(7, -2)]:
		if Encounter.for_tile(cell, "grass").lineup != again.lineup:
			differ += 1
	_check(differ >= 3, "other tiles field other enemies (%d of 4 differ)" % differ)
	return true


## The Dreadmask: its number of commons fewer off the front of a fight on the land, one fewer for every
## wall inside the tile, the elites and the boss still coming, once however often the fight is told;
## never a farm run, the dungeon or the ice wall.
func _test_the_dreadmask() -> bool:
	var tiers := func(fight: Encounter) -> Array:
		return Array(fight.lineup).map(func(enemy: String) -> EnemyRoster.Tier: return EnemyRoster.tier_of(enemy))
	var inside := Vector2i(3, 4)
	var plain := Encounter.for_tile(inside, "grass")
	var dread := Encounter.for_tile(inside, "grass")
	dread.wear(["dread"], {"dreadmask": 2})
	dread.wear(["dread"], {"dreadmask": 2})
	_check(dread.enemies == Encounter.ENEMIES - 4 and dread.lineup.size() == dread.enemies
			and dread.health.size() == dread.enemies, "rank II inside the first wall is four fewer, once (%d)" % dread.enemies)
	_check(dread.lineup == plain.lineup.slice(4) and dread.hp == dread.health[0],
			"the first four commons go and the fight opens on the next")
	_check(tiers.call(dread)[-1] == EnemyRoster.Tier.ELITE, "the elite still ends it")
	# Past two walls, two fewer at rank II; past four, none.
	var two_out := MapBuilder.CENTER + Vector2i(MapBuilder.START_LAND_RADIUS + 1 + MapBuilder.WALL_STEP + 2, 0)
	_check(Encounter.walls_inside(two_out) == 2, "%s is past two walls" % two_out)
	var past := Encounter.for_tile(two_out, "grass")
	past.wear(["dread"], {"dreadmask": 2})
	_check(past.enemies == Encounter.ENEMIES - 2, "two walls in, rank II is two fewer (%d)" % past.enemies)
	var far := Encounter.for_tile(two_out + Vector2i(2 * MapBuilder.WALL_STEP, 0), "grass")
	far.wear(["dread"], {"dreadmask": 2})
	_check(far.enemies == Encounter.ENEMIES, "four walls in, none")
	# Rank IV inside the first wall asks for more commons than there are: the elite alone is left.
	var all := Encounter.for_tile(inside, "grass")
	all.wear(["dread"], {"dreadmask": 4})
	_check(tiers.call(all) == [EnemyRoster.Tier.ELITE], "rank IV leaves the elite alone (%s)" % [tiers.call(all)])
	var siege := Encounter.for_tile(inside, "grass", "village")
	var commons: int = tiers.call(siege).count(EnemyRoster.Tier.COMMON)
	siege.wear(["dread"], {"dreadmask": 4})
	_check(siege.enemies == Encounter.SETTLEMENT["enemies"] - mini(commons, 10)
			and tiers.call(siege)[-1] == EnemyRoster.Tier.BOSS, "a settlement keeps its elites and its boss")
	var run := Encounter.farm(inside, "grass")
	run.wear(["dread"], {"dreadmask": 4})
	var wall := Encounter.for_wall(MapBuilder.CENTER + Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0))
	wall.wear(["dread"], {"dreadmask": 4})
	var down := Encounter.for_dungeon()
	down.wear(["dread"], {"dreadmask": 4})
	_check(run.lineup.size() == 1 and Array(wall.lineup) == [Encounter.WALL_NAME] and down.lineup.size() == 1,
			"a farm run, the ice wall and the dungeon are left as they were")
	return true


## What a body is carrying: one gold at the very middle, growing with the walk both ways at once,
## and worth what the body itself was worth to kill.
func _test_gold() -> bool:
	_check(Encounter.base_gold(MapBuilder.CENTER) == 1, "a body in the middle carries one gold")
	_check(Encounter.gold_of("Skeleton Warrior", MapBuilder.CENTER) == 1,
			"and so does an ordinary common one, which is where the curve is pinned")

	# Linear *and* exponential: every step adds GOLD_PER_STEP and multiplies by GOLD_GROWTH. Checked
	# step by step out to the edge, with the slack rounding to whole gold allows.
	for steps in range(0, 21):
		var here := Vector2i(steps, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		var want: float = (Encounter.BASE_GOLD + Encounter.GOLD_PER_STEP * steps) 				* pow(Encounter.GOLD_GROWTH, steps)
		_check(absf(Encounter.base_gold(here) - want) <= 0.5,
				"step %d carries %d, not the curve's %.1f" % [steps, Encounter.base_gold(here), want])
		if steps > 0:
			_check(Encounter.base_gold(here) > Encounter.base_gold(Vector2i(steps - 1, 0)),
					"step %d pays better than step %d" % [steps, steps - 1])

	# A purse is worth what the body was worth to kill, so it is the same hp_modifier its health is,
	# and nobody keeps a second table in step with the first. Floored at one all the same.
	var far := Vector2i(12, 0)
	for enemy in EnemyRoster.names():
		_check(Encounter.gold_of(enemy, MapBuilder.CENTER) >= 1, "%s carries at least one gold" % enemy)
		_check(Encounter.gold_of(enemy, far) > Encounter.gold_of(enemy, MapBuilder.CENTER),
				"%s carries more further out" % enemy)
	_check(Encounter.gold_of("Grass Slime", far) < Encounter.gold_of("Skeleton Warrior", far),
			"a slime carries the least")
	_check(Encounter.gold_of("Skeleton Warrior", far) < Encounter.gold_of("Medusa", far),
			"and an elite more than a common of the same size")

	# Every body pays, unlike every body dropping something: what the fight has earned is the sum of
	# what fell off it, and nothing is rolled for.
	var fight := Encounter.for_tile(Vector2i(4, 0), "grass")
	var purses: Array = []
	fight.gold_dropped.connect(func(_index: int, amount: float) -> void: purses.append(amount))
	fight.start()
	_play(fight, 4000)
	_check(fight.finished and fight.victory, "the fight was won")
	_check(purses.size() == Encounter.ENEMIES, "all %d bodies paid, not %d"
			% [Encounter.ENEMIES, purses.size()])
	var summed := 0.0
	for purse: float in purses:
		summed += purse
	_check(fight.gold == summed, "the fight holds %d gold, and %d fell" % [fight.gold, summed])

	# A lost fight keeps what fell before the clock ran out, the way its drops do.
	var lost := Encounter.for_tile(Vector2i(4, 0), "grass")
	lost.start()
	_play(lost, 30)
	var banked := lost.gold
	_check(banked > 0, "a body or two went down before giving up")
	lost.give_up()
	_check(lost.gold == banked, "and giving up keeps every purse that fell")
	return true


## Every body's experience: gold's curve on its own dials, summed by the fight, kept by a lost one --
## and a level costing more killing the further out the player has to go to earn it.
func _test_experience() -> bool:
	_check(Encounter.base_xp(MapBuilder.CENTER) == 1, "a body in the middle is worth one experience")
	_check(Encounter.xp_of("Grass Slime", MapBuilder.CENTER) >= 1, "and never less than one")
	var far := Vector2i(12, 0)
	for enemy in EnemyRoster.names():
		_check(Encounter.xp_of(enemy, far) > Encounter.xp_of(enemy, MapBuilder.CENTER),
				"%s is worth more further out" % enemy)
	_check(Encounter.xp_of("Skeleton Warrior", far) < Encounter.xp_of("Medusa", far),
			"an elite is worth more than a common of the same size")

	var fight := Encounter.for_tile(Vector2i(4, 0), "grass")
	var drops: Array = []
	fight.xp_dropped.connect(func(_index: int, amount: int) -> void: drops.append(amount))
	fight.start()
	_play(fight, 4000)
	_check(fight.finished and fight.victory, "the fight was won")
	_check(drops.size() == Encounter.ENEMIES, "every body gave experience, not %d" % drops.size())
	var summed := 0
	for amount: int in drops:
		summed += amount
	_check(fight.xp == summed, "the fight holds %d experience, and %d fell" % [fight.xp, summed])

	var lost := Encounter.for_tile(Vector2i(4, 0), "grass")
	lost.start()
	_play(lost, 30)
	var banked := lost.xp
	_check(banked > 0, "a body or two went down before giving up")
	lost.give_up()
	_check(lost.xp == banked, "and giving up keeps the experience")

	# No orb falls until the player has killed FIRST_ORB_KILLS, across fights.
	var gated := Encounter.farm(MapBuilder.CENTER + Vector2i(1, 0), "grass")
	gated.orbs_after = 30
	gated.damage = 1000000
	gated.orb_rng.seed = WORLD_SEED
	var orb_kills: Array = []
	gated.orb_dropped.connect(func(_i: int, _orb: String) -> void: orb_kills.append(gated.kills()))
	gated.start()
	while gated.kills() < 400:
		gated.hit()
		gated.advance(0.1)
	_check(not orb_kills.is_empty(), "orbs fall once the kills are made: %d" % orb_kills.size())
	_check(orb_kills.is_empty() or orb_kills[0] >= 30, "and never before: first at kill %s" % [orb_kills.slice(0, 1)])

	# The promised orb is the one exception: the first body leaves a Transmutation through the gate,
	# and the gate holds for everything after it.
	var promised := Encounter.farm(MapBuilder.CENTER + Vector2i(1, 0), "grass")
	promised.orbs_after = 30
	promised.first_orb = true
	promised.damage = 1000000
	promised.orb_rng.seed = WORLD_SEED
	var promised_orbs: Array = []
	promised.orb_dropped.connect(func(_i: int, orb: String) -> void:
		promised_orbs.append([promised.kills(), orb]))
	promised.start()
	while promised.kills() < 30:
		promised.hit()
		promised.advance(0.1)
	_check(promised_orbs.size() == 1 and promised_orbs[0][1] == OrbTable.FIRST_ORB
			and promised_orbs[0][0] <= 1, "the promised orb falls off the first body, alone: %s" % [promised_orbs])
	_check(not promised.first_orb, "and the promise is spent")
	return true


## The coins a purse is drawn as: how many of them, and the sheet they are cut from.
func _test_coins() -> bool:
	# 1 + log10, floored. A decade of gold buys one more coin, and nothing else moves the count.
	_check(Coins.count_for(1) == 1, "one gold is one coin")
	_check(Coins.count_for(9) == 1, "and so is nine")
	_check(Coins.count_for(10) == 2, "ten is two")
	_check(Coins.count_for(99) == 2, "and so is ninety-nine")
	_check(Coins.count_for(100) == 3, "a hundred is three")
	_check(Coins.count_for(1000) == 4, "a thousand is four")
	_check(Coins.count_for(1000000) == 7, "and a million is only seven")
	# A body always throws something, whatever nonsense it is handed: gold is floored at one, but
	# nothing downstream should have to know that for a body to be seen to pay.
	_check(Coins.count_for(0) == 1, "an empty purse still throws a coin")
	_check(Coins.count_for(-5) == 1, "and so does an impossible one")
	var last := 0
	for amount in [1, 10, 100, 1000, 10000]:
		_check(Coins.count_for(amount) > last, "%d throws more than the decade under it" % amount)
		last = Coins.count_for(amount)

	# The sheet's geometry, which is measured rather than guessed -- this is what fails loudly if the
	# coin is ever re-exported at another size or with another number of frames in it.
	var spin := Coins.frames()
	_check(spin.has_animation("spin"), "the coin has a spin")
	_check(spin.get_frame_count("spin") == Coins.FRAMES,
			"of %d frames, not %d" % [Coins.FRAMES, spin.get_frame_count("spin")])
	_check(spin.get_animation_loop("spin"), "and it loops")
	_check(Coins.SHEET.get_width() >= Coins.FRAMES * Coins.SIZE,
			"the sheet holds them: %d px" % Coins.SHEET.get_width())
	_check(Coins.SHEET.get_height() == Coins.SIZE,
			"one row of them: %d px" % Coins.SHEET.get_height())
	_check(Coins.icon().region == Rect2(0, 0, Coins.SIZE, Coins.SIZE),
			"the resting coin is the first frame")
	_check(Coins.icon() == Coins.icon(), "and it is built once")
	return true


## A fight is drawn under the sky it is given, its light on the land and a little on the fighters but
## never on the sky itself; while an enemy walks in the hero walks to meet it and the backdrop goes
## by, the nearer the faster, carrying what lies on the ground into his hands; once the enemy stands
## nothing moves, and in a settlement nothing moves at all.
func _test_the_backdrop_goes_by() -> void:
	var animations := Settings.animations
	Settings.animations = Settings.Anim.DEFAULT
	var cell := Vector2i(4, 0)
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	var fight := Encounter.for_tile(cell, "grass")
	combat.begin(fight, cell, 2.0, "plain", 1, "night")
	await process_frame
	var night: Color = CombatScene.SKY_LIGHT["night"]
	var layers := combat._layers
	_check(layers[0].texture == load(CombatScene.SKY_PATH % "night") and layers[0].modulate == Color.WHITE,
			"the night sky at the back, as drawn")
	_check(layers[1].modulate == night and layers[-1].modulate == night, "its light on the land")
	_check(combat._player.self_modulate == Color.WHITE.lerp(night, CombatScene.SCENE_LIGHT),
			"and some of it on the hero")
	_check(fight.phase == Encounter.Phase.WAITING or combat._player.animation == "walk",
			"who walks on to meet the first enemy")

	fight.phase = Encounter.Phase.WALKING_IN
	var before: Array[float] = []
	for layer in layers:
		before.append(layer.region_rect.position.x)
	combat._scroll(0.1)
	var moved: Array[float] = []
	for i in layers.size():
		moved.append(fposmod(layers[i].region_rect.position.x - before[i], 384.0))
	_check(moved[0] == 0.0, "the sky stands still")
	_check(is_equal_approx(moved[-1], CombatScene.WALK_SPEED * 0.1), "the ground goes at walking pace")
	var nearer := true
	for i in range(1, moved.size()):
		nearer = nearer and moved[i] > moved[i - 1]
	_check(nearer, "and each band of land between them the faster the nearer it is (%s)" % [moved])

	# What lies on the ground goes with it, and the hero picks up what he walks into.
	combat._show_find(load(CombatScene.SKY_PATH % "noon"), -1)
	var find: Node2D = combat._ground_drops.get_child(combat._ground_drops.get_child_count() - 1)
	var lying := find.global_position.x
	combat._scroll(0.1)
	_check(is_equal_approx(lying - find.global_position.x, CombatScene.WALK_SPEED * 0.1 * combat._pixel),
			"a find on the ground goes by with it")
	_check(find.get_parent() == combat._ground_drops, "and lies there while the hero is short of it")
	find.position.x = combat._player.position.x - combat._ground_drops.position.x
	combat._scroll(0.01)
	_check(find.get_parent() == combat and not find.has_meta(CombatScene.THROWN),
			"the moment he reaches it, it is picked up and flies to the counter")

	fight.phase = Encounter.Phase.WAITING
	var held := layers[-1].region_rect.position.x
	combat._scroll(0.1)
	_check(layers[-1].region_rect.position.x == held, "while an enemy stands, nothing moves")
	Settings.animations = Settings.Anim.NONE
	fight.phase = Encounter.Phase.WALKING_IN
	combat._scroll(0.1)
	_check(layers[-1].region_rect.position.x == held, "nor with the animations off")
	Settings.animations = Settings.Anim.DEFAULT
	combat.queue_free()
	await process_frame

	# A settlement is held, not walked through: the hero stands, its defenders come to him, and the
	# backdrop stays where it is.
	var town: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(town)
	var siege := Encounter.for_tile(cell, "grass", "village")
	town.begin(siege, cell, 2.0, "village", 1, "noon")
	await process_frame
	_check(siege.phase == Encounter.Phase.WALKING_IN and town._player.animation != "walk",
			"the hero stands his ground in a settlement while an enemy comes in")
	var still := town._layers[-1].region_rect.position.x
	town._scroll(0.1)
	_check(town._layers[-1].region_rect.position.x == still, "and the settlement stays still behind him")
	Settings.animations = animations
	town.queue_free()
	await process_frame


## The nameplate's bar drains with the enemy and wears that enemy's tier. Needs a scene rather than an
## Encounter: the encounter knows the hit points and the view is what turns them into a width.
##
## The two halves are one test because they are one claim. The bar and the kill pips both read
## Encounter.tier_in, so what this really holds is that the frame over the enemy's head and the pip
## standing for it are the same answer -- a green-framed bar over a common, or a brown one over the
## elite, would be worse than either of them simply being the wrong colour.
func _test_the_nameplate_wears_the_tier() -> void:
	var cell := Vector2i(4, 0)
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	var fight := Encounter.for_tile(cell, "grass")
	combat.begin(fight, cell, 2.0)
	await process_frame
	var bar := combat._enemy_bar
	var full := HealthBar.TROUGH * HealthBar.PIXEL

	# A tile fight opens on a common, and opens full.
	_check(Encounter.tier_in(fight, 0) == EnemyRoster.Tier.COMMON, "the first of the ten is a common")
	_check(bar._fill.size.x == full, "a fight opens with the bar full")
	_check(bar._cap_l.texture == HealthBar.CAP_L[EnemyRoster.Tier.COMMON],
			"wearing the common frame")

	# Take the enemy down and the red follows it, in proportion. Set rather than hit, so this measures
	# the bar and not the damage tables -- and measured against the share the fight actually has
	# rather than against a half, because hit points are whole numbers and the first commons have
	# very few of them: half of seven is three, and the bar is honest about that.
	var max_hp := fight.enemy_max_hp()
	fight.hp = floorf(max_hp / 2.0)
	combat._refresh()
	var want := float(full) * fight.hp / max_hp
	_check(absf(bar._fill.size.x - want) <= HealthBar.PIXEL,
			"%d of %d hit points is %d px of the bar's %d, wanted about %d"
					% [fight.hp, max_hp, bar._fill.size.x, full, want])
	fight.hp = 1
	combat._refresh()
	_check(bar._fill.size.x > 0.0 and bar._fill.size.x < full / 4.0,
			"one hit point left still shows, and shows as nearly nothing")

	# Walk the lineup to the elite. The frame changes and the trough does not.
	var elite := fight.enemies - 1
	_check(Encounter.tier_in(fight, elite) == EnemyRoster.Tier.ELITE, "the tenth is the elite")
	fight.index = elite
	fight.hp = fight.enemy_max_hp()
	combat._refresh()
	_check(bar._cap_l.texture == HealthBar.CAP_L[EnemyRoster.Tier.ELITE],
			"the elite's own frame is worn when it walks in")
	_check(bar._tracks[0].texture == HealthBar.TRACK[EnemyRoster.Tier.ELITE],
			"and its rail with it, not only its ends")
	_check(bar._fill.size.x == full, "an elite at full health is exactly as much red as a common")
	_check(bar.custom_minimum_size.x > HealthBar.width_of(EnemyRoster.Tier.COMMON),
			"and its bar is the wider one")

	# The pips beside it are drawn in that same tier, which is the whole reason the lookup was shared
	# rather than written out twice. The elite is the last of the ten, so it is the last pip.
	_check(combat._pips._pips[elite].texture == KillPips.texture(EnemyRoster.Tier.ELITE),
			"the pip standing for the elite is the elite's skull")
	_check(combat._pips._pips[0].texture == KillPips.texture(EnemyRoster.Tier.COMMON, true),
			"and those already down are spent")

	# Nothing standing means no nameplate at all, rather than an empty frame.
	fight.index = fight.lineup.size()
	combat._refresh()
	_check(not combat._enemy_panel.visible, "with the lineup spent the nameplate goes")
	combat.queue_free()
	await process_frame

	# A settlement is a longer fight, so its bar is a longer bar: a pip an enemy, gold at the end,
	# and the clock still cut to exactly the width of the pips above it.
	var town: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(town)
	var siege := Encounter.for_tile(cell, "grass", "village")
	town.begin(siege, cell, 2.0, "village")
	await process_frame
	# Fifteen do not all show: nine from the one being fought and a caret for the rest, moving on a pip
	# a kill until the last ten are in view.
	_check(siege.enemies > KillPips.SHOWN and town._pips._pips.size() == KillPips.SHOWN,
			"a village's bar shows %d of its %d pips, not %d" % [KillPips.SHOWN, siege.enemies, town._pips._pips.size()])
	var pips: Array[TextureRect] = town._pips._pips
	_check(pips[-1].texture == KillPips.MORE, "the last place is the caret while more are to come")
	_check(pips[0].texture == KillPips.texture(Encounter.tier_in(siege, 0)), "and the first is the one being fought")
	siege.index = 1
	town._refresh()
	_check(pips[0].texture == KillPips.texture(Encounter.tier_in(siege, 1)) and pips[-1].texture == KillPips.MORE,
			"a kill drops it off the left and the rest move up a place")
	var last_ten := siege.enemies - KillPips.SHOWN
	siege.index = last_ten
	town._refresh()
	_check(pips[-1].texture == KillPips.texture(EnemyRoster.Tier.BOSS),
			"with the last ten in view the caret goes and the boss's crowned skull ends the bar")
	siege.index = last_ten + 2
	town._refresh()
	_check(pips[1].texture == KillPips.texture(Encounter.tier_in(siege, last_ten + 1), true)
			and pips[2].texture == KillPips.texture(Encounter.tier_in(siege, last_ten + 2)),
			"and from there the bar stays put and drains where it stands")
	siege.index = 0
	town._refresh()
	_check(town._clock_fill.get_parent().size.x
			== KillPips.width_for(siege.enemies) - 2 * CombatScene.BAR_BORDER,
			"the clock is cut to the pip bar it stands under")
	town.queue_free()
	await process_frame


## What a body drops lands in the arena, the way its purse does: a sprite thrown out of it, glowing
## in its rarity above common, and no panel anywhere. Needs a scene rather than an Encounter, because
## the throwing is the view's half of it.
func _test_thrown_finds() -> void:
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.begin(Encounter.for_tile(Vector2i(4, 0), "grass"), Vector2i(4, 0), 2.0)
	await process_frame
	_check(combat._finds_shown == 0, "a fight starts having thrown nothing")

	# A common piece: the icon and nothing else. Counted by what is on the scene rather than only by
	# the tally, so this fails if the throw ever stops reaching the tree.
	var before := combat._ground_drops.get_child_count()
	combat._on_loot_dropped(0, _thrown_piece(ItemRarity.Rarity.COMMON))
	_check(combat._finds_shown == 1, "a kept find is thrown")
	_check(combat._ground_drops.get_child_count() == before + 1, "and it lies on the ground")
	var plain := combat._ground_drops.get_child(combat._ground_drops.get_child_count() - 1) as Node2D
	_check(plain is Sprite2D, "drawn as a sprite, like a coin")
	_check(plain.get_child_count() == 0, "with no beam over a common piece")

	# Uncommon is thrown plain too: a beam is for rare and better.
	combat._on_loot_dropped(1, _thrown_piece(ItemRarity.Rarity.UNCOMMON))
	_check(combat._ground_drops.get_child(combat._ground_drops.get_child_count() - 1).get_child_count() == 0,
			"with no beam over an uncommon piece")

	# A rare one carries a beam of its own colour behind it.
	var rare := _thrown_piece(ItemRarity.Rarity.RARE)
	combat._on_loot_dropped(2, rare)
	_check(combat._finds_shown == 3, "and so is the next")
	var lit := combat._ground_drops.get_child(combat._ground_drops.get_child_count() - 1) as Node2D
	_check(lit.scale.x > plain.scale.x and lit.z_index > plain.z_index,
			"drawn bigger than a common one, and over it")
	_check(lit.get_child_count() == 1, "a rare piece is thrown with a beam over it")
	var heights := []
	if lit.get_child_count() == 1:
		var beam := lit.get_child(0)
		var back := beam.get_node_or_null("Back") as Polygon2D
		var front := beam.get_node_or_null("Front") as Polygon2D
		_check(back != null and front != null and back.material is ShaderMaterial
				and front.material is ShaderMaterial, "drawn by the beam's shader, in two layers")
		if back != null and front != null:
			var want: Color = ItemRarity.BORDER_COLORS[rare.rarity]
			var got: Color = back.material.get_shader_parameter("colour")
			_check(got.is_equal_approx(want), "in the rarity's own colour")
			_check(back.z_index < 0 and front.z_index >= 0, "one behind the piece and one in front of it")
			_check(combat._hud.z_index > lit.z_index + front.z_index, "and the HUD drawn over the lot")
			_check(back.material.get_shader_parameter("cover").x >= 16.0,
					"wide enough at the foot to cover the piece")
			heights.append(back.material.get_shader_parameter("height"))
		var hum := beam.get_node_or_null("Hum") as AudioStreamPlayer
		_check(hum != null and hum.stream.loop, "and hums on a loop while it stands")

	# Each step up stands a taller beam, and a unique's dwarfs the rest.
	for rarity in [ItemRarity.Rarity.ELITE, ItemRarity.Rarity.UNIQUE]:
		var loose := LootBeam.make(rarity, Color.WHITE, 0.0, Vector2(16, 32))
		heights.append(loose.get_node("Back").material.get_shader_parameter("height"))
		loose.free()
	_check(heights.size() == 3 and heights[0] < heights[1] and heights[1] < heights[2],
			"rarer finds stand taller beams: %s" % [heights])
	_check(heights.size() == 3 and heights[2] >= 2.0 * heights[1], "and a unique's dwarfs the rest")

	# Every beam's colour has its bright step picked on the palette, a rarity's and a good orb's alike.
	var glows: Array = LootBeam.LOOKS.keys().map(func(rarity: int) -> Color: return ItemRarity.BORDER_COLORS[rarity])
	for orb: String in OrbTable.ORBS:
		if OrbTable.ORBS[orb].has("beam"):
			glows.append(OrbTable.ORBS[orb].glow)
	for glow: Color in glows:
		_check(LootBeam.HOT.has(glow) and LootBeam.HOT[glow].to_html(false) in Palette.E64,
				"a %s beam has an ENDESGA 64 step above it" % glow.to_html(false))

	# A cheap orb is thrown plain; a good one stands the beam its table names.
	combat._on_orb_dropped(3, "Orb of Transmutation")
	_check(combat._finds_shown == 4, "an orb is thrown too")
	_check(combat._ground_drops.get_child(combat._ground_drops.get_child_count() - 1).get_child_count() == 0,
			"and a cheap one carries no beam")
	combat._on_orb_dropped(4, "Orb of Exaltation")
	var orb := combat._ground_drops.get_child(combat._ground_drops.get_child_count() - 1) as Node2D
	_check(orb.get_child_count() == 1, "but a good one does")

	# Its two layers share one seed, or a ribbon's turns would not meet; picked up, the find leaves
	# its beam on the ground to sink away and free itself, going by with it as it does.
	if orb.get_child_count() == 1:
		var beam := orb.get_child(0) as Node2D
		_check(beam.get_node("Back").material.get_shader_parameter("seed")
				== beam.get_node("Front").material.get_shader_parameter("seed"), "one seed a beam")
		combat._fly_to_counter(orb)
		_check(beam.get_parent() == combat._ground_drops and orb.get_child_count() == 0,
				"a find picked up leaves its beam behind")
		# Polled rather than timed to `FALL`: a headless run's tweens can lag the timer's clock.
		for i in 40:
			if not is_instance_valid(beam):
				break
			await create_timer(0.05).timeout
		_check(not is_instance_valid(beam), "and the beam is gone once it has sunk")

	# The toasts are gone, so nothing may still be reaching for them.
	_check(not ("_toasts" in combat), "there is no toast left to raise")
	combat.queue_free()
	await process_frame


## A unique's long slow motion is not cut short by the kill freezes that land inside it, and it eases
## back to full speed rather than snapping.
func _test_the_longest_stop_wins() -> void:
	Juice.hit_stop(self, 0.3, 0.1, 0.2)
	Juice.hit_stop(self, 0.05)
	_check(is_equal_approx(Engine.time_scale, 0.1), "a short freeze inside a long slow is dropped")
	await create_timer(0.15, true, false, true).timeout
	_check(is_equal_approx(Engine.time_scale, 0.1), "and the slow outlasts it")
	# Watched a frame at a time rather than sampled at set moments, which a slow frame would skip past.
	var between := false
	var guard := 0
	while Engine.time_scale < 1.0 and guard < 600:
		between = between or (Engine.time_scale > 0.1 and Engine.time_scale < 1.0)
		guard += 1
		await process_frame
	_check(between, "then eases back through the speeds between")
	_check(is_equal_approx(Engine.time_scale, 1.0), "to full speed")
	Engine.time_scale = 1.0


## A piece to throw. The type is any real one -- what is being checked is the throw, not the roll.
## The settings: they come back off their file, a fight with animations off throws nothing and still
## fills the bar, and a detailed modifier line carries the band it rolled in. Every static is put back,
## since the suites after this one in the file read them.
func _test_settings() -> void:
	Settings.path = "user://test_settings.cfg"
	Settings.sfx_volume = 0.0
	Settings.music_volume = 0.5
	Settings.shake = false
	Settings.fullscreen = true
	Settings.animations = Settings.Anim.LOW
	Settings.item_details = true
	Settings.uniques = Settings.Uniques.KEEP
	Settings.save()
	Settings.sfx_volume = 1.0
	Settings.music_volume = 1.0
	Settings.shake = true
	Settings.fullscreen = false
	Settings.animations = Settings.Anim.DEFAULT
	Settings.item_details = false
	Settings.uniques = Settings.Uniques.ASK
	Settings.load_settings()
	_check(Settings.sfx_volume == 0.0 and is_equal_approx(Settings.music_volume, 0.5) and not Settings.shake
			and Settings.fullscreen and Settings.animations == Settings.Anim.LOW and Settings.item_details
			and Settings.uniques == Settings.Uniques.KEEP, "settings come back off their file")
	Settings.uniques = Settings.Uniques.ASK
	Settings.shake = true
	Settings.fullscreen = false
	Settings.apply_audio()
	var music := AudioServer.get_bus_index(Settings.MUSIC_BUS)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.SFX_BUS)), "effects at nothing are muted")
	_check(not AudioServer.is_bus_mute(music) and is_equal_approx(AudioServer.get_bus_volume_db(music),
			linear_to_db(0.5)), "and music at half is heard at half (%s dB)" % AudioServer.get_bus_volume_db(music))
	# A file from before there were volumes held whether each was on: on is all, off is nothing.
	var old := ConfigFile.new()
	old.set_value(Settings.SECTION, "music", false)
	old.set_value(Settings.SECTION, "sfx", true)
	old.save(Settings.path)
	Settings.load_settings()
	_check(Settings.music_volume == 0.0 and Settings.sfx_volume == 1.0, "an old file's on and off become full and silent")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = ""
	Settings.music_volume = 1.0

	var piece := _thrown_piece(ItemRarity.Rarity.COMMON)
	piece.mods = [{"id": "increased_damage", "value": 14}]
	var band := ModifierTable.band_for("increased_damage", piece.level)
	_check(piece.mod_lines(true)[0] == "+14(%d-%d)%% increased Damage T1" % band,
			"a detailed line carries its band: %s" % piece.mod_lines(true)[0])

	Settings.animations = Settings.Anim.NONE
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.begin(Encounter.for_tile(Vector2i(4, 0), "grass"), Vector2i(4, 0), 2.0)
	await process_frame
	var absorbed: Array[int] = []
	combat.xp_absorbed.connect(func(amount: int) -> void: absorbed.append(amount))
	var before := combat.get_child_count()
	combat._on_xp_dropped(0, 25)
	combat._on_gold_dropped(0, 1000.0)
	combat._on_loot_dropped(0, piece)
	combat._show_damage(5.0, true)
	_check(absorbed == [25], "with animations off the bar takes its experience at once")
	_check(combat.get_child_count() == before and combat._ground_drops.get_child_count() == 0
			and combat._finds_shown == 0, "and nothing is thrown")
	_check(combat._drops.size() == 1, "though the find is still kept")
	Settings.animations = Settings.Anim.LOW
	combat._on_gold_dropped(0, 1000.0)
	_check(combat._ground_drops.get_child_count() == 1, "on low a purse is one coin")
	combat.queue_free()
	await process_frame
	Settings.sfx_volume = 1.0
	Settings.animations = Settings.Anim.DEFAULT
	Settings.item_details = false
	Settings.apply_audio()


## What a fight sounds like is chosen by rule: a find lands by what it is, and a blow and a crit land
## by the weapon in hand.
func _test_sounds() -> bool:
	var first := {}
	for type: String in LootTable.items():
		if not first.has(LootTable.kind_of(type)):
			first[LootTable.kind_of(type)] = type
	var lands := {"sword": "weapon", "mace": "weapon", "gold_ring": "jewel", "ruby_amulet": "jewel",
			"hood": "cloth", "boot": "cloth", "jerkin": "cloth",
			"helm": "base", "greaves": "base", "plate": "base", "shield": "base", "torch": "base"}
	for kind: String in lands:
		var piece := _thrown_piece(ItemRarity.Rarity.RARE)
		piece.type = first[kind]
		_check(CombatScene.drop_sound_of(piece) == lands[kind], "a %s lands as %s" % [kind, lands[kind]])
	_check(CombatScene.drop_sound_of(_thrown_piece(ItemRarity.Rarity.UNIQUE)) == "unique",
			"and a unique with its own, whatever it is")

	var blows := [["", CombatScene.HIT_SOUND, CombatScene.BLUNT_CRIT],
			["mace", CombatScene.BLUNT_HIT, CombatScene.BLUNT_CRIT],
			["sword", CombatScene.HIT_SOUND, CombatScene.SLASH_CRIT],
			["dagger", CombatScene.HIT_SOUND, CombatScene.SLASH_CRIT]]
	for blow: Array in blows:
		var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
		combat.weapon_kind = blow[0]
		root.add_child(combat)
		combat.begin(Encounter.for_tile(Vector2i(4, 0), "grass"), Vector2i(4, 0), 2.0)
		_check(combat._hit_sound.stream == blow[1] and combat._crit_sound.stream == blow[2],
				"a hit with %s lands and crits as it should" % ("bare hands" if blow[0] == "" else "a " + blow[0]))
		combat.free()
	return true


func _thrown_piece(rarity: ItemRarity.Rarity) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = 1
	item.stats = Item.scaled_stats(item.type, 1)
	return item


## Health grows with the walk from the middle of the map, and with the enemy's own size and tier.
func _test_health() -> bool:
	# The settings' balancing page scales a body by the walls inside its tile, and never the ice wall.
	var past_one := Vector2i(MapBuilder.START_LAND_RADIUS + 5, 0)
	var plain := Encounter.hp_of("Centaur", past_one)
	var wall := Encounter.hp_of(Encounter.WALL_NAME, past_one)
	var inner := Encounter.hp_of("Centaur", Vector2i(5, 0))
	var circle := Encounter.walls_inside(past_one)
	Settings.wall_hp[circle] = Encounter.circle_base_hp(circle) * 2.0
	_check(Encounter.hp_of("Centaur", past_one) == roundf(plain * 2.0),
			"a base number twice the formula's doubles this circle's bodies")
	_check(Encounter.hp_of("Centaur", Vector2i(5, 0)) == inner, "and leaves another circle's alone")
	_check(Encounter.hp_of(Encounter.WALL_NAME, past_one) == wall, "and never the ice wall")
	Settings.wall_hp = [0.0, 0.0, 0.0]
	_check(SettingsPage._nudged(5.0, "/10") == 1.0 and SettingsPage._nudged(1.0, "-1") == 1.0
			and SettingsPage._nudged(7.0, "x10") == 70.0 and SettingsPage._nudged(7.0, "+1") == 8.0,
			"the page's buttons step the number and never take it under 1")
	var near := Vector2i(1, 0)
	var far := Vector2i(20, 0)
	_check(HexGrid.distance(MapBuilder.CENTER, near) == 1, "the near cell is the first ring")
	_check(Encounter.base_hp(MapBuilder.CENTER) == Encounter.BASE_HP, "an ordinary body in the middle")
	_check(Encounter.base_hp(far) > Encounter.base_hp(near), "and a tougher one at the edge")

	# Health is exponential in the walk, not a flat sum: every step multiplies by HP_GROWTH, so the
	# frontier pulls away from whatever the player is carrying. Checked step by step out to the wall,
	# with the slack that rounding to whole points of health allows. Only to the wall: past one the
	# curve has a second term, pinned below.
	for steps in range(1, MapBuilder.START_LAND_RADIUS + 2):
		var here := Vector2i(steps, 0)
		var back := Vector2i(steps - 1, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		_check(Encounter.base_hp(here) > Encounter.base_hp(back),
				"step %d is tougher than step %d" % [steps, steps - 1])
		var want := Encounter.BASE_HP * pow(Encounter.HP_GROWTH, steps)
		_check(absf(Encounter.base_hp(here) - want) <= 0.5,
				"step %d is %d, not the curve's %.1f" % [steps, Encounter.base_hp(here), want])

	# The other term: every wall behind a cell multiplies its bodies by WALL_GROWTH, so the land a
	# fallen wall opens is a frontier again rather than a walkover to whoever just broke through. A
	# wall's own ring counts none of itself -- it is the edge of the land inside it -- so the step
	# lands on the first ring past a wall and the wall itself stays what its dial says.
	var wall_ring := MapBuilder.START_LAND_RADIUS + 1
	for steps: int in [1, MapBuilder.START_LAND_RADIUS, wall_ring]:
		_check(Encounter.walls_inside(Vector2i(steps, 0)) == 0,
				"no wall stands inside step %d" % steps)
	for walls: int in [1, 2, 3]:
		var first := wall_ring + (walls - 1) * MapBuilder.WALL_STEP + 1
		for steps in range(first, wall_ring + walls * MapBuilder.WALL_STEP + 1):
			_check(Encounter.walls_inside(Vector2i(steps, 0)) == walls,
					"%d wall(s) stand inside step %d" % [walls, steps])
	for walls in range(0, 4):
		var steps := wall_ring + walls * MapBuilder.WALL_STEP + 1
		var want := Encounter.BASE_HP * pow(Encounter.HP_GROWTH, steps) * pow(Encounter.LAND_GROWTH, walls + 1)
		_check(absf(Encounter.base_hp(Vector2i(steps, 0)) / want - 1.0) < 0.01,
				"step %d is %s, not the curve's %s past %d wall(s)"
				% [steps, BigNumber.format(Encounter.base_hp(Vector2i(steps, 0))),
					BigNumber.format(want), walls + 1])
	# Rounding to whole points of health is why this is a ratio with slack rather than an equality: the
	# first ring past a wall is one step and one whole wall harder than the wall's own ring.
	var across := Encounter.base_hp(Vector2i(wall_ring + 1, 0)) / Encounter.base_hp(Vector2i(wall_ring, 0))
	_check(absf(across / (Encounter.HP_GROWTH * Encounter.LAND_GROWTH) - 1.0) < 0.01,
			"crossing the wall is one step and one wall at once (x%.2f)" % across)

	for enemy in EnemyRoster.names():
		_check(Encounter.hp_of(enemy, near) >= 1, "%s is worth at least one click" % enemy)
		_check(Encounter.hp_of(enemy, far) > Encounter.hp_of(enemy, near), "%s is tougher further out" % enemy)
	_check(Encounter.hp_of("Grass Slime", near) < Encounter.hp_of("Skeleton Warrior", near), "a slime is the softest")

	# The map has no edge, and health is exponential in the walk: an int64 ran out about 250 hexes
	# out and came back negative, which made the frontier a walkover. A double reaches some 4,200.
	var deep := Encounter.base_hp(MapBuilder.CENTER + Vector2i(300, 0))
	var shallower := Encounter.base_hp(MapBuilder.CENTER + Vector2i(299, 0))
	_check(is_finite(deep) and deep > 0.0,
			"a body 300 steps out has real health (%s)" % BigNumber.format(deep))
	_check(deep > shallower, "and more of it than one 299 steps out (%s)"
			% BigNumber.format(shallower))

	# The elite is the wall at the end: it must outlast any common the same tile can send.
	var fight := Encounter.for_tile(near, "grass")
	var elite: float = fight.health[fight.enemies - 1]
	for i in fight.enemies - 1:
		_check(elite > fight.health[i], "the elite outlasts enemy %d" % [i + 1])
	return true


## Ten enemies clicked down inside the minute, with the clock running through every walk-in and death.
func _test_a_won_fight() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	var coming: Array[String] = []
	var spawned: Array[int] = []
	var died: Array[int] = []
	var results: Array[bool] = []
	fight.enemy_coming.connect(func(_i: int, n: String, _hp: float) -> void: coming.append(n))
	fight.enemy_spawned.connect(func(i: int, _n: String, _hp: float) -> void: spawned.append(i))
	fight.enemy_died.connect(func(i: int) -> void: died.append(i))
	fight.won.connect(func() -> void: results.append(true))
	fight.lost.connect(func() -> void: results.append(false))

	_check(not fight.hit(), "no hit lands before the first enemy is on")
	fight.start()
	_check(coming.size() == 1 and coming[0] == fight.lineup[0], "the first enemy is announced on its way in")
	var clicks := _play(fight, 10000)
	_check(fight.finished and fight.victory, "the fight is won")
	_check(results == [true], "winning is reported once")
	_check(spawned.size() == Encounter.ENEMIES and died.size() == Encounter.ENEMIES,
			"all ten came out and all ten went down")
	# Every enemy has to be announced on its way in, or the scene draws the one before it.
	_check(coming.size() == Encounter.ENEMIES, "all ten were announced (%d)" % coming.size())
	_check(PackedStringArray(coming) == fight.lineup, "in the order the fight lists them")
	_check(fight.remaining() == 0, "none are left")
	_check(fight.time_left > 0.0, "with %.1fs to spare" % fight.time_left)
	_check(not fight.hit(), "a hit after the last one does nothing")
	print("First-ring fight: %d clicks, %.1fs left of %ds" % [clicks, fight.time_left, Encounter.SECONDS])

	return true


## The clock is the only way to lose, and it keeps running while enemies walk in and die.
func _test_a_lost_fight() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	var results: Array[bool] = []
	fight.won.connect(func() -> void: results.append(true))
	fight.lost.connect(func() -> void: results.append(false))

	fight.advance(Encounter.SECONDS + 1.0)
	_check(fight.finished and not fight.victory, "standing still loses")
	_check(results == [false], "losing is reported once")
	_check(fight.time_left == 0.0, "the clock is out")
	_check(not fight.hit(), "hits after time do nothing")
	fight.advance(10.0)
	_check(results == [false], "and the clock stays quiet afterwards")

	# The last enemy going down on the final sliver of clock still wins. How long a fight actually
	# takes depends on the ten it rolled, so measure one and then start another that late.
	var measured := Encounter.for_tile(Vector2i(1, 0), "grass")
	_play(measured, 10000)
	var takes := Encounter.SECONDS - measured.time_left

	var close := Encounter.for_tile(Vector2i(1, 0), "grass")
	var won: Array[bool] = []
	close.lost.connect(func() -> void: won.append(false))
	close.won.connect(func() -> void: won.append(true))
	close.advance(Encounter.SECONDS - takes - 0.1)
	_check(not close.finished, "the fight is still on with a sliver of clock left")
	_play(close, 10000)
	_check(close.finished and close.victory, "beating the last one just in time still wins")
	_check(won == [true], "and is reported as a win")
	_check(close.time_left < 1.0, "with almost nothing to spare (%.2fs)" % close.time_left)
	return true


## The enemies strike the clock: every tier on its own rhythm, each blow cut by armour and then block,
## dodged whole now and then, and won back by time on hit -- and never on a run, which has no clock.
func _test_enemy_strikes() -> bool:
	# The user's own example, as the formula: a hundred-second blow against 90% armour and ten seconds
	# of block is nothing. 90% armour is a rating of 9 * ARMOUR_K.
	var sums := Encounter.new()
	sums.arm({"armor": 9.0 * Encounter.ARMOUR_K, "block": 100.0})
	_check(is_equal_approx(sums.taken(100.0), 0.0), "100s against 90%% armour and 10s block is 0 (%.3f)"
			% sums.taken(100.0))
	sums.arm({"armor": 9.0 * Encounter.ARMOUR_K})
	_check(is_equal_approx(sums.taken(100.0), 10.0), "armour alone takes 90%% (%.3f)" % sums.taken(100.0))
	sums.arm({"block": 100.0})
	_check(is_equal_approx(sums.taken(100.0), 90.0), "block alone takes its ten seconds (%.3f)" % sums.taken(100.0))
	# A flat share, so the same armour turns the same part of a small blow as of a big one, and none
	# of it is ever the whole.
	sums.arm({"armor": Encounter.ARMOUR_K})
	_check(is_equal_approx(sums.taken(1.0), 0.5) and is_equal_approx(sums.taken(100.0), 50.0),
			"K armour is half of any blow")
	sums.arm({"armor": 1.0e12})
	_check(sums.taken(1.0) > 0.0, "and never all of one")
	sums.arm({"dodge": 9.0 * Encounter.DODGE_K})
	_check(is_equal_approx(sums.dodge_chance(), 0.9), "dodge is the same share, as a chance")

	# Each tier strikes on its own rhythm, and the first blow waits a whole interval.
	# Common every second, elite every two, boss every four: nothing lands in the first 0.999 s, and in
	# the first 4.001 s that is four, two and one.
	for case: Array in [[EnemyRoster.Tier.COMMON, 4], [EnemyRoster.Tier.ELITE, 2], [EnemyRoster.Tier.BOSS, 1]]:
		var fight := _struck_standing(case[0])
		var blows: Array = []
		fight.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: blows.append(t))
		fight.advance(0.999)
		_check(blows.is_empty(), "tier %d waits out its first interval (%d)" % [case[0], blows.size()])
		fight.advance(3.002)
		_check(blows.size() == case[1], "and strikes %d times in four seconds (%d)" % [case[1], blows.size()])
		var hit := Encounter.hit_of(fight.enemy_name(), fight.cell)
		_check(is_equal_approx(float(blows[-1]), hit), "a blow with nothing on is the whole of it")
		_check(is_equal_approx(fight.time_left, Encounter.SECONDS - Encounter.WALK_IN - 4.001 - hit * blows.size()),
				"and comes off the clock (%.3f)" % fight.time_left)
	# A boss's blow is four commons', which its slower rhythm pays for: every tier takes the same a second.
	var here := Vector2i(12, 0)
	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
		var some := _enemy_of(tier)
		_check(is_equal_approx(Encounter.hit_of(some, here) / float(Encounter.ATTACK_EVERY[tier]),
				Encounter.hit_of(_enemy_of(EnemyRoster.Tier.COMMON), here)
				/ float(Encounter.ATTACK_EVERY[EnemyRoster.Tier.COMMON])), "tier %d takes what a common does a second" % tier)
	# Blows grow by their own HIT_GROWTH a ring and HIT_WALL_GROWTH a wall, not by health's.
	var common := _enemy_of(EnemyRoster.Tier.COMMON)
	var inside := MapBuilder.CENTER + Vector2i(MapBuilder.START_LAND_RADIUS, 0)
	var past := inside + Vector2i(2, 0)
	_check(Encounter.walls_inside(inside) == 0 and Encounter.walls_inside(past) == 1, "one wall between them")
	_check(is_equal_approx(Encounter.hit_of(common, past) / Encounter.hit_of(common, inside),
			Encounter.HIT_GROWTH * Encounter.HIT_GROWTH * Encounter.HIT_WALL_GROWTH), "a blow grows with the walk and its wall's step")

	# Dodge: over a long run of blows, about the share the formula says, and a dodge costs nothing.
	var dodger := _struck_standing(EnemyRoster.Tier.COMMON, {"dodge": 0.5 * Encounter.DODGE_K})
	dodger.crit_rng.seed = WORLD_SEED
	var hit := Encounter.hit_of(dodger.enemy_name(), dodger.cell)
	var chance := dodger.dodge_chance()
	var dodged := [0, 0]
	dodger.player_hit.connect(func(t: float, d: bool, _b: bool) -> void:
		dodged[0 if d else 1] += 1
		if d:
			_check(t == 0.0, "a dodge costs nothing"))
	for i in 2000:
		dodger.time_left = 1000.0
		dodger._struck_by(hit)
	var share := float(dodged[0]) / 2000.0
	_check(absf(share - chance) < 0.04, "dodged %.2f of blows where the formula says %.2f" % [share, chance])

	# Time on hit wins back what the blows took and never more: the clock's own running is not a wound.
	var healer := _struck_standing(EnemyRoster.Tier.COMMON, {"time_on_hit": 10.0})
	var start := healer.time_left
	healer.hit()
	_check(healer.time_left == start, "with no wound, a hit wins nothing back")
	healer._struck_by(2.5)
	healer.hit()
	_check(is_equal_approx(healer.time_left, start - 1.5) and is_equal_approx(healer.wounds, 1.5),
			"a hit wins back its second of the blow (%.2f)" % healer.time_left)
	healer.hit()
	healer.hit()
	_check(is_equal_approx(healer.time_left, start) and healer.wounds == 0.0,
			"and stops once the wound is healed (%.2f)" % healer.time_left)

	# Nobody strikes a run, the wall or a fight nobody told to (`strikes`).
	var run := Encounter.farm(Vector2i(12, 0), "grass")
	run.strikes = true
	var run_blows: Array = []
	run.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: run_blows.append(t))
	run.start()
	run.advance(10.0)
	_check(run_blows.is_empty(), "a farm run is never struck")
	var wall := Encounter.for_wall(Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0))
	wall.strikes = true
	wall.start()
	wall.advance(10.0)
	_check(is_equal_approx(wall.time_left, wall.seconds - 10.0), "the ice wall never strikes")
	var quiet := Encounter.for_tile(Vector2i(12, 0), "grass")
	quiet.start()
	quiet.advance(5.0)
	_check(is_equal_approx(quiet.time_left, Encounter.SECONDS - 5.0), "nor does a fight nobody armed for it")

	return true


## A tile fight with the enemies striking and the first body of `tier` standing there, armed with
## `stats`. Walked on to the moment it can be hit, so its first blow is a whole interval away.
## The Guard tree's three capstones.
func _test_guard_capstones() -> bool:
	# Afterimage: a dodge wins back up to a second of what blows took, and never more than they took.
	var dodger := _struck_standing(EnemyRoster.Tier.COMMON, {"dodge": 1.0e12})
	dodger.effects = ["afterimage"]
	var start := dodger.time_left
	dodger._struck_by(3.0)
	_check(dodger.time_left == start, "with no wound, a dodge wins nothing back")
	dodger.wounds = 2.5
	dodger.time_left = start - 2.5
	dodger._struck_by(3.0)
	_check(is_equal_approx(dodger.wounds, 1.5) and is_equal_approx(dodger.time_left, start - 1.5),
			"a dodge wins back one second (%.2f)" % dodger.time_left)

	# Shield Wall: block counts double against an elite, and only against one.
	for case: Array in [[EnemyRoster.Tier.COMMON, 2.0], [EnemyRoster.Tier.ELITE, 1.0]]:
		var guard := _struck_standing(case[0], {"block": 10.0})
		guard.effects = ["shieldwall"]
		var before := guard.time_left
		guard._struck_by(3.0)
		_check(is_equal_approx(before - guard.time_left, case[1]),
				"tier %d takes %.1fs of a 3s blow (%.2f)" % [case[0], case[1], before - guard.time_left])

	# Second Wind: the clock running out gives back five seconds, once.
	var winded := Encounter.for_tile(Vector2i(1, 0), "grass")
	winded.health[0] = 1.0e9
	winded.effects = ["second_wind"]
	winded.start()
	winded.advance(Encounter.SECONDS + 0.01)
	_check(not winded.finished and is_equal_approx(winded.time_left, Encounter.SECOND_WIND_SECONDS),
			"the first time out is a second wind (%.2f)" % winded.time_left)
	winded.advance(Encounter.SECOND_WIND_SECONDS + 0.01)
	_check(winded.finished, "and the second is the end")
	return true


func _struck_standing(tier: EnemyRoster.Tier, stats := {}) -> Encounter:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	fight.lineup[0] = _enemy_of(tier)
	fight.health[0] = 1.0e9
	fight.hp = 1.0e9
	fight.strikes = true
	fight.arm(stats)
	fight.start()
	fight.advance(Encounter.WALK_IN)
	return fight


## Some enemy of `tier` that lives on grass.
func _enemy_of(tier: EnemyRoster.Tier) -> String:
	for name: String in EnemyRoster.names():
		if EnemyRoster.tier_of(name) == tier:
			return name
	return ""


## An enemy can only be hit while it is standing in front of the player.
func _test_hits_only_land_on_a_waiting_enemy() -> bool:
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	_check(fight.phase == Encounter.Phase.WALKING_IN, "the first enemy starts by running in")
	fight.advance(Encounter.WALK_IN / 2.0)
	_check(not fight.hit(), "it can't be hit on the way in")
	_check(fight.hp == fight.enemy_max_hp(), "so it has taken no damage")

	fight.advance(Encounter.WALK_IN)
	_check(fight.phase == Encounter.Phase.WAITING, "then it stands to be hit")
	_check(fight.hit() and fight.hp == fight.enemy_max_hp() - 1, "and a click takes a point off")

	while fight.hp > 0:
		fight.hit()
	_check(fight.phase == Encounter.Phase.DYING, "at zero it starts dying")
	_check(not fight.hit(), "a corpse can't be hit")
	_check(fight.index == 0, "and the next one is not out yet")

	fight.advance(Encounter.DEATH + Encounter.WALK_IN)
	_check(fight.index == 1 and fight.phase == Encounter.Phase.WAITING, "the second enemy takes its place")
	_check(fight.remaining() == Encounter.ENEMIES - 1, "nine to go")
	_check(not fight.on_elite(), "the second of ten is no elite")

	fight.give_up()
	_check(fight.finished and not fight.victory, "leaving counts as a loss")
	return true


## Charting a tile goes through a fight now, so the map has to hand over and take back cleanly:
## winning charts the tile as it always did, losing leaves the map exactly as it was.
func _test_the_map_hands_over_and_takes_back() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	# A fight drops loot into whatever inventory the scene was pointed at, so never the player's own.
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame

	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	_check(main.view.can_chart(target), "the tile next door can be fought for")

	# Losing changes nothing.
	main.map.select_cell(target)
	main._on_chart_pressed()
	_check(main._combat == null and main.view.walking, "pressing Chart walks the player onto the tile first")
	main.map.player.finish_walk()
	_check(main.view.player_cell == target, "onto the tile itself")
	_check(main._combat != null, "and the fight starts there")
	_check(not main.map.visible and main.map.process_mode == Node.PROCESS_MODE_DISABLED,
			"the map stops while the fight is on")
	main._combat._on_terminate_pressed()
	_check(main._combat.fight.finished and not main._combat.fight.victory,
			"Terminate gives a tile fight up as a loss")
	_check(main._combat._result_detail.text == "Given up", "and the verdict says it was given up")
	_check(main._combat._lost_row.visible and not main._combat._collect.visible,
			"a lost fight offers the arrow and Retry, and nothing to collect")
	# Retry is a loss left and the same tile's fight opened again, in one press.
	var first: CombatScene = main._combat
	first.retry.emit()
	_check(main._combat != null and main._combat != first and main._combat.cell == target,
			"Retry opens the same tile's fight afresh")
	_check(not main.view.charted(target) and not main.map.visible, "with nothing charted by the loss")
	_check(main.view.player_cell == target and not main.view.walking, "and the player still on the tile")
	# Shut mid-fight, the save has the player back where they set out from, as a loss would.
	main._save_map()
	_check(MapSave.load_from(SCRATCH_MAP, []).player_cell == MapBuilder.CENTER,
			"a save made on the tile being fought for puts the player back where they came from")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	_check(main._combat == null, "the fight is torn down")
	_check(main.map.visible and main.map.process_mode == Node.PROCESS_MODE_INHERIT, "and the map is back")
	_check(not main.view.charted(target), "a lost tile stays uncharted")
	_check(main.view.walking, "and the player runs back off it")
	main.map.player.finish_walk()
	_check(main.view.player_cell == MapBuilder.CENTER, "to the tile they set out from")
	_check(main.view.can_chart(target), "and it can be fought for again")

	# Winning charts it, and the player stays on it.
	main._on_chart_pressed()
	main.map.player.finish_walk()
	var fight: Encounter = main._combat.fight
	_play(fight, 10000)
	_check(fight.victory, "the rematch is won")
	_check(main._combat._collect.visible and not main._combat._lost_row.visible and not main._combat.auto_collect,
			"and a won tile leaves by Collect, pressed: nothing collects by itself without the Nightwalkers")
	main._combat._on_back_pressed()
	await process_frame
	_check(main.view.charted(target), "a won tile is charted")
	_check(main.map.visible, "and the map is back")
	_check(main.view.player_cell == target and not main.view.walking, "with the player staying on it")

	# Escape: Terminate on a run, Back under its verdict, then the tile panel's X.
	main._on_farm_pressed()
	_check(main._combat != null and main._combat.fight.endless, "a run starts on the won tile, where they stand")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(main._combat != null and main._combat.fight.finished, "Escape ends a farm run")
	Input.parse_input_event(escape)
	await process_frame
	# The verdict shrinks away before it goes.
	await create_timer(Juice.LEAVE_TIME + 0.1).timeout
	_check(main._combat == null, "again leaves its verdict")
	_check(main._panel.visible, "with the tile panel still up")
	# A tip that came due with the run is what Escape closes first, one press each.
	for i in main.TIPS.size():
		if main._tip_panel == null:
			break
		Input.parse_input_event(escape)
		await process_frame
		await process_frame
	_check(main._tip_panel == null and main._panel.visible, "a tip takes the press before the panel does")
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(not main._panel.visible and main.map.selected_cell == HexMap.NO_CELL,
			"and once more closes the tile panel")
	main.map.select_cell(target)

	# A tile away from the player: they walk through the charted tile beside it and onto it, and the fight
	# opens there.
	var far_side := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.W)
	main.map.select_cell(far_side)
	_check(main._chart_button.visible and not main._chart_button.disabled and not main._move_button.visible and not main._farm_button.visible, "only the buttons that can be pressed show")
	main._on_chart_pressed()
	_check(main._combat == null and main.view.walking, "charting a tile out of reach walks there first")
	_check(not main._chart_button.visible, "and hides the buttons on the way")
	main.map.player.finish_walk()
	_check(main.view.player_cell == far_side and main._combat != null, "the fight opens on arrival")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	main.map.player.finish_walk()
	# Back to the charted tile they stepped onto it from, not to where the walk began.
	_check(main.view.player_cell == MapBuilder.CENTER and not main.view.walking,
			"and a loss runs them back to the charted tile they stepped onto it from")

	# Farming a tile away from the player walks there too, and they stay when the run ends.
	main.map.select_cell(target)
	main._on_farm_pressed()
	_check(main._combat == null and main.view.walking, "farming a tile away walks there first")
	main.map.player.finish_walk()
	_check(main.view.player_cell == target and main._combat != null and main._combat.fight.endless,
			"and the run opens on arrival")
	main._combat.fight.stop()
	main._combat._on_back_pressed()
	await process_frame
	_check(not main.view.walking and main.view.player_cell == target, "a run ended leaves them where it was")
	main.queue_free()


## The Nightwalkers: Chart on a tile a few steps into the dark fights for every tile of the way in turn,
## each won one collecting its loot and walking on to the next by itself; Retry keeps the way, and a
## loss ends it.
func _test_the_nightwalkers_fight_their_way() -> void:
	_clear_saves()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var boots := Item.rolled_unique("nightwalkers", rng, 1)
	main.inventory.add(boots)
	main.inventory.equip(boots, Equipment.Socket.BOOTS)
	# A veteran's save, every tip read: a tip up holds the fight still, and its automatic Collect with it.
	for tip: Array in main.TIPS:
		main.inventory.tips.append(tip[0])
	var line: Array[Vector2i] = [MapBuilder.CENTER]
	for i in 3:
		line.append(HexGrid.neighbor(line[-1], HexGrid.Edge.E))
	main.map.select_cell(line[3])
	_check(main.view.can_chart(line[3]) and main._chart_button.visible, "three steps into the dark can be charted")
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main.view.player_cell == line[1] and main._combat != null and main._combat.cell == line[1],
			"the first fight is for the first tile of the way")
	_play(main._combat.fight, 10000)
	_check(main._combat.auto_collect and main._combat._collect.visible, "won, the verdict is up")
	await create_timer(CombatScene.AUTO_COLLECT_SECONDS + Juice.LEAVE_TIME + 0.3).timeout
	_check(main.view.charted(line[1]) and main.view.walking and main._combat == null,
			"and with nobody pressing Collect the loot is taken, the tile charted and the hero walks on")
	main.map.player.finish_walk()
	_check(main._combat != null and main._combat.cell == line[2], "and the next tile's fight opens")
	# Retry keeps the way.
	main._combat.fight.give_up()
	main._combat.retry.emit()
	_check(main._combat != null and main._combat.cell == line[2] and main._dark_way == [line[3]],
			"Retry fights the same tile again, the way kept")
	_play(main._combat.fight, 10000)
	await create_timer(CombatScene.AUTO_COLLECT_SECONDS + Juice.LEAVE_TIME + 0.3).timeout
	main.map.player.finish_walk()
	_check(main.view.charted(line[2]) and main._combat != null and main._combat.cell == line[3],
			"won, on to the goal")
	# A loss ends the way, and runs the hero back to the last tile won.
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	main.map.player.finish_walk()
	_check(not main.view.charted(line[3]) and main._dark_way.is_empty() and main._combat == null
			and main.view.player_cell == line[2] and not main.view.walking,
			"a loss leaves the goal uncharted, the way over and the hero on the last tile won")
	main.queue_free()
	await process_frame
	_clear_saves()


## A descent played to the end of its clock with a weapon worth `damage` a swing, `speed` swings a
## second, begun under `won` depths: the fight, finished.
func _descended(damage: float, speed: float, won := 0) -> Encounter:
	var fight := Encounter.for_dungeon(won)
	fight.strikes = true
	fight.arm({"damage": damage, "attack_speed": speed})
	fight.start()
	for i in 100000:
		if fight.finished:
			break
		fight.advance(0.05)
	return fight


func _test_the_dungeon() -> bool:
	var fight := Encounter.for_dungeon()
	var block := int(Encounter.DUNGEON["enemies"])
	_check(fight.dungeon and fight.env == Encounter.DUNGEON_ENV and not fight.endless
			and is_equal_approx(fight.time_left, float(Encounter.DUNGEON["seconds"])),
			"the dungeon is a clocked fight in the cave")
	# Its creatures are the cave's and nobody else's, and no land fields one.
	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
		_check(not EnemyRoster.in_environment(Encounter.DUNGEON_ENV, tier).is_empty(),
				"the cave has a tier %d creature" % tier)
	for name in EnemyRoster.in_environment(Encounter.DUNGEON_ENV):
		_check(EnemyRoster.environments_of(name) == PackedStringArray([Encounter.DUNGEON_ENV]),
				name + " lives in the cave alone")
	# A depth is fifteen floors: an elite every fifth and the boss on the fifteenth, for ever, and a
	# descent begun under depths already won meets them on the same floors.
	for won in [0, 3]:
		var from := Encounter.for_dungeon(won)
		_check(from.first_floor == won * block and from.depth() == won + 1 and from.cleared() == 0,
				"%d depths won begins depth %d, on its first floor" % [won, won + 1])
		for position in 40:
			var want := EnemyRoster.Tier.BOSS if position % block == block - 1 \
					else EnemyRoster.Tier.ELITE if position % 5 == 4 else EnemyRoster.Tier.COMMON
			_check(from.tier_for(position) == want, "floor %d under %d is tier %d" % [position + 1, won, want])
	# A floor's health is the floor and the tier: the same whoever stands there, and one step a floor,
	# so a depth is DUNGEON_GROWTH ^ 15 harder than the one over it.
	_check(is_equal_approx(fight.hp, Encounter.BASE_HP), "the first floor is one ordinary body")
	var deep := Encounter.for_dungeon(2)
	_check(is_equal_approx(deep.hp, roundf(Encounter.BASE_HP * pow(Encounter.DUNGEON_GROWTH, 2 * block))),
			"and the third depth opens thirty steps on (%s)" % BigNumber.format(deep.hp))
	# A world's curse that sizes bodies again leaves a floor the health its floor gives it.
	var cursed := Encounter.for_dungeon(2)
	cursed.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(cursed.hp, deep.hp), "Iron Foes does not reach down the dungeon")
	# The player's own hand lands as it does anywhere, and nothing strikes the clock -- which runs as it
	# does anywhere, through a walk-in too (the user's, 2026-10-03).
	fight.start()
	fight.advance(Encounter.WALK_IN)
	_check(is_equal_approx(fight.time_left, float(Encounter.DUNGEON["seconds"]) - Encounter.WALK_IN),
			"the walk-in costs its seconds down here")
	_check(fight.hit() and fight.hp < Encounter.BASE_HP, "a click lands down here")
	# With no swing at all the whole minute is seen out on the first floor -- and running out is an
	# end, not a loss.
	var bare := _descended(0.0, 0.0)
	_check(bare.finished and bare.victory and bare.depth() == 1 and bare.cleared() == 0 and bare.index == 0,
			"nobody swinging ends on the first floor of the first depth, not lost")
	_check(is_zero_approx(bare.wounds), "and was never struck")
	# It pays nothing, however far it goes.
	var paid: Array = []
	var armed := Encounter.for_dungeon()
	armed.always_drop = true
	armed.always_orb = true
	armed.uniques_after = 0
	armed.effects = ["hourglass"]
	for sent: Signal in [armed.loot_dropped, armed.gold_dropped, armed.orb_dropped, armed.xp_dropped]:
		sent.connect(func(_index: int, _what: Variant) -> void: paid.append(1))
	armed.arm({"damage": 50.0, "attack_speed": 4.0})
	armed.start()
	while not armed.finished:
		armed.advance(0.05)
	_check(armed.kills() > 5 and paid.is_empty() and is_zero_approx(armed.gold) and armed.xp == 0,
			"%d floors cleared and nothing paid" % armed.kills())
	_check(armed.time_left <= 0.0, "and the Hourglass held no clock")
	# A depth is won by killing its Gollux and by nothing short of it: the floor under him is still
	# his depth, and the one after him is the next.
	var under := Encounter.for_dungeon()
	under.arm({"damage": 1e9})
	under.start()
	while under.index < block - 1:
		under.advance(Encounter.WALK_IN)
		under.hit()
		under.advance(Encounter.DEATH)
	_check(under.enemy_name() == "Gollux" and under.depth() == 1 and under.cleared() == 0,
			"fourteen floors down is Gollux, and still the first depth")
	var wall := Encounter.for_wall(Vector2i(MapBuilder.START_LAND_RADIUS + 1 + MapBuilder.WALL_STEP, 0)).hp
	_check(is_equal_approx(under.hp, Encounter.gollux_hp())
			and is_zero_approx(fmod(under.hp, Encounter.GOLLUX_ROUND))
			and absf(under.hp - wall) <= Encounter.GOLLUX_ROUND / 2.0,
			"and he is the second ice wall rounded to the nearest 500k (%s for %s)"
			% [BigNumber.format(under.hp), BigNumber.format(wall)])
	under.advance(Encounter.WALK_IN)
	under.hit()
	_check(under.depth() == 1 and under.cleared() == 0, "he is not dead until he has fallen")
	under.advance(Encounter.DEATH)
	_check(under.depth() == 2 and under.cleared() == 1 and not under.finished,
			"with him dead it is the second depth, and the descent goes on")
	_check(is_equal_approx(Encounter.for_dungeon(1)._health_of("Gollux", block - 1),
			roundf(Encounter.gollux_hp() * pow(Encounter.DUNGEON_GROWTH, block))),
			"and the next Gollux is a depth's growth on")
	# More damage gets deeper, and a depth is a real step: DUNGEON_GROWTH ^ 15 of it.
	var damage := Encounter.gollux_hp() / 100.0
	var weak := _descended(damage, 2.0)
	var strong := _descended(damage * pow(Encounter.DUNGEON_GROWTH, block), 2.0)
	_check(strong.cleared() > weak.cleared(),
			"a depth's worth more damage wins more depths (%d against %d)" % [strong.cleared(), weak.cleared()])
	print("The dungeon: %s damage at 2 swings/s wins %d depth(s) from the top, %s damage %d"
			% [BigNumber.format(damage), weak.cleared(), BigNumber.format(damage * pow(Encounter.DUNGEON_GROWTH, block)), strong.cleared()])
	return true


func _test_the_ice_wall() -> bool:
	var cell := Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0)
	var fight := Encounter.for_wall(cell)
	_check(fight.lineup == PackedStringArray([Encounter.WALL_NAME]) and fight.env == "ice" and fight.enemies == 1,
			"the wall stands alone, on the ice")
	_check(EnemyRoster.tier_of(Encounter.WALL_NAME) == EnemyRoster.Tier.BOSS, "and is a boss")
	for env in ["grass", "dirt", "desert", "forest", "ice", "mountains"]:
		_check(not (Encounter.WALL_NAME in EnemyRoster.in_environment(env)), "the wall lives nowhere, not on %s" % env)
	# A wall is a fixed check on the land inside it and nothing more: WALL_HP over its own body, with
	# no term of its own for the walls already down. That term lives in `base_hp` now, where it makes
	# the land past a fallen wall a frontier again, and a wall's ring counts none of itself -- so the
	# second wall comes out WALL_GROWTH times the first without `for_wall` doing anything about it.
	var second := Encounter.for_wall(Vector2i(cell.x + MapBuilder.WALL_STEP, 0))
	_check(Encounter.walls_inside(cell) == 0 and Encounter.walls_inside(second.cell) == 1,
			"a wall's own ring counts none of itself")
	for wall: Encounter in [fight, second]:
		_check(is_equal_approx(wall.hp, roundf(Encounter.hp_of(Encounter.WALL_NAME, wall.cell, Encounter.WALL_GROWTH) * Encounter.WALL_HP)),
				"the wall on ring %d is WALL_HP over its own body" % HexGrid.distance(MapBuilder.CENTER, wall.cell))
	var by_ring := pow(Encounter.HP_GROWTH, MapBuilder.WALL_STEP)
	_check(absf(second.hp / fight.hp / by_ring / Encounter.WALL_GROWTH - 1.0) < 0.01,
			"the second wall is %.0f times the first on top of its ring (%s health)"
			% [Encounter.WALL_GROWTH, BigNumber.format(second.hp)])
	return true


## A farm run: the same enemies, coming forever, with no clock and no count. The only two ways out
## are the player saying so and give_up(), so everything here is about the ways it does *not* end.
func _test_a_farm_run_never_ends() -> bool:
	var idle := Encounter.farm(Vector2i(3, 0), "grass")
	idle.roster_rng.seed = WORLD_SEED
	idle.start()
	# Twice the budget a tile fight gets, with nobody lifting a finger. A tile fight is long over.
	idle.advance(Encounter.SECONDS * 2.0)
	_check(not idle.finished, "a farm run does not run out of time")
	_check(is_equal_approx(idle.time_left, Encounter.SECONDS), "a farm run never spends the clock")

	var fight := Encounter.farm(Vector2i(3, 0), "grass")
	fight.roster_rng.seed = WORLD_SEED
	fight.arm({"damage": 200.0, "crit_chance": 0.0, "crit_damage": 0.0, "attack_speed": 0.0})
	fight.start()
	_check(fight.lineup.size() == 1, "a run starts with one enemy and finds the rest as it goes")
	var clicks := _play(fight, 300)
	_check(not fight.finished, "%d clicks in, the run is still going" % clicks)
	_check(fight.kills() > Encounter.ENEMIES, "a run runs past what a tile fight is, at %d kills"
			% fight.kills())
	_check(fight.lineup.size() == fight.health.size(),
			"every enemy in the lineup has health: %d against %d"
			% [fight.lineup.size(), fight.health.size()])
	_check(fight.index < fight.lineup.size(), "there is always one more waiting")

	# Elites keep the rhythm a tile fight has: the tenth, the twentieth, and so on forever.
	var elites := 0
	for i in fight.lineup.size():
		var is_elite := EnemyRoster.tier_of(fight.lineup[i]) == EnemyRoster.Tier.ELITE
		if is_elite:
			elites += 1
		_check(is_elite == (i % fight.elite_every == fight.elite_every - 1),
				"slot %d is %s, which is not the elite rhythm" % [i, fight.lineup[i]])
	_check(elites > 0, "a run long enough to pass ten threw up %d elite(s)" % elites)

	# Terminating is not losing. The kills and the loot are the player's either way.
	var results := []
	fight.won.connect(func() -> void: results.append(true))
	fight.lost.connect(func() -> void: results.append(false))
	fight.stop()
	_check(fight.finished and fight.victory, "stopping a run ends it, and not as a loss")
	_check(results == [true], "stopping fires won exactly once, and lost never: %s" % [results])
	fight.stop()
	_check(results == [true], "stopping a stopped run says nothing more")

	# on_elite() asks the roster, so it is the same question in a tile fight as in a run.
	var tile := Encounter.for_tile(Vector2i(3, 0), "grass")
	for i in tile.enemies:
		tile.index = i
		_check(tile.on_elite() == (i == tile.enemies - 1),
				"slot %d of a tile fight reads the wrong way round" % i)
	return true


## A settlement is a set piece: fifteen enemies in a minute, an elite every fifth and a boss last.
## All three tiers fight it -- what makes a town a longer fight is that people live there -- and a
## farm run on one keeps that elite rhythm and never the boss.
## A chest tile fields the mimic alone, which no other lineup ever does, and it pays either one
## unique or MIMIC_ROLLS pieces of gear, never both.
func _test_a_chest_is_a_mimic() -> bool:
	for env in _environments():
		for variant in ["plain", "village"]:
			var ordinary := Encounter.for_tile(Vector2i(4, 6), env, variant)
			_check(not Encounter.MIMIC in ordinary.lineup, "no mimic on an ordinary %s %s" % [env, variant])
	var outcomes := {"unique": 0, "gear": 0}
	for attempt in 20:
		var fight := Encounter.for_tile(Vector2i(4, 6), "grass", "plain", true)
		_check(fight.lineup == PackedStringArray([Encounter.MIMIC]), "a chest fields the mimic alone")
		_check(fight.tier_for(0) == EnemyRoster.Tier.BOSS, "and it is a boss")
		fight.loot_rng.seed = attempt
		fight.unique_rng.seed = attempt
		fight.unlocked = Achievements.STARTERS
		var found: Array[Item] = []
		fight.loot_dropped.connect(func(_i: int, item: Item) -> void: found.append(item))
		fight.damage = 1 << 20
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		var uniques := found.filter(func(item: Item) -> bool: return not item.unique.is_empty()).size()
		if uniques > 0:
			outcomes["unique"] += 1
			_check(found.size() == 1, "a chest's unique comes alone (%d finds)" % found.size())
		else:
			outcomes["gear"] += 1
			_check(found.size() == Encounter.MIMIC_ROLLS,
					"otherwise it pays %d pieces (%d)" % [Encounter.MIMIC_ROLLS, found.size()])
		fight.advance(Encounter.DEATH)
		_check(fight.finished and fight.victory, "beating it takes the tile")
	_check(outcomes["unique"] > 0 and outcomes["gear"] > 0, "both halves of the toss come up %s" % outcomes)
	return true


func _test_a_settlement_is_a_set_piece() -> bool:
	for variant in ["village", "town", "fortress"]:
		for env in _environments():
			var fight := Encounter.for_tile(Vector2i(4, 6), env, variant)
			_check(fight.enemies == 15 and fight.seconds == 60.0 and fight.elite_every == 5,
					"a %s on %s fields %d in %.0fs, an elite every %d"
					% [variant, env, fight.enemies, fight.seconds, fight.elite_every])
			_check(fight.time_left == fight.seconds, "and opens with its whole clock")
			_check(fight.lineup.size() == fight.enemies,
					"a %s lines up %d, not %d" % [variant, fight.enemies, fight.lineup.size()])
			_check(fight.remaining() == fight.enemies, "with all of them still to beat")
			var bosses := 0
			var elites := 0
			for i in fight.lineup.size():
				var tier := EnemyRoster.tier_of(fight.lineup[i])
				_check(fight.tier_for(i) == tier,
						"tier_for(%d) agrees with the enemy the lineup put there" % i)
				_check(env in EnemyRoster.environments_of(fight.lineup[i]),
						"%s lives on %s" % [fight.lineup[i], env])
				match tier:
					EnemyRoster.Tier.BOSS:
						bosses += 1
						_check(i == fight.enemies - 1, "the boss is last, not number %d" % [i + 1])
					EnemyRoster.Tier.ELITE:
						elites += 1
						_check(i % fight.elite_every == fight.elite_every - 1,
								"an elite stands at %d, off the rhythm" % i)
			_check(bosses == 1, "a %s on %s ends on exactly one boss (%d)" % [variant, env, bosses])
			# Slots 4 and 9: the boss takes the fifteenth, which would otherwise be the third elite.
			_check(elites == 2, "and two elites before it (%d)" % elites)

	# The same tile, fought twice, fields the same fifteen -- a settlement is decided before the
	# player reaches it, like every other tile.
	_check(Encounter.for_tile(Vector2i(4, 6), "grass", "town").lineup
			== Encounter.for_tile(Vector2i(4, 6), "grass", "town").lineup,
			"a settlement keeps its enemies")

	# A variant this build has never heard of is open land as far as the fight is concerned.
	var plain := Encounter.for_tile(Vector2i(4, 6), "grass", "ruins")
	_check(plain.enemies == Encounter.ENEMIES and plain.seconds == Encounter.SECONDS
			and not plain.boss_last, "an unknown variant fights the ordinary fight")

	# A run on a town: the rhythm comes with it and the boss does not.
	var run := Encounter.farm(Vector2i(4, 6), "grass", "fortress")
	run.roster_rng.seed = WORLD_SEED
	run.start()
	_play(run, 400)
	_check(run.elite_every == 5, "a run on a fortress throws up an elite every %d" % run.elite_every)
	_check(run.lineup.size() > run.elite_every * 2,
			"and runs past two whole cycles of it, at %d" % run.lineup.size())
	var run_elites := 0
	for i in run.lineup.size():
		var tier := EnemyRoster.tier_of(run.lineup[i])
		_check(tier != EnemyRoster.Tier.BOSS, "no boss comes round in a run (slot %d)" % i)
		if tier == EnemyRoster.Tier.ELITE:
			run_elites += 1
		_check((tier == EnemyRoster.Tier.ELITE) == (i % run.elite_every == run.elite_every - 1),
				"slot %d is %s, which is not the settlement rhythm" % [i, run.lineup[i]])
	_check(run_elites > 2, "a long run on a town is thick with elites (%d)" % run_elites)

	return true


## Every unique a fight hands over, gathered off `loot_dropped` as [index, id] pairs.
func _uniques_of(fight: Encounter) -> Array:
	var found := []
	fight.loot_dropped.connect(func(index: int, item: Item) -> void:
		if not item.unique.is_empty():
			found.append([index, item.unique]))
	return found


## Where uniques come from: nothing before the wait is over, chance alone after it, and the rabble
## far less often than what leads it.
func _test_unique_drops() -> bool:
	var cell := Vector2i(6, 0)
	# A drop rate this size caps every chance at certain, so the tally is about the gate and not luck.
	var sure := {"damage": 1.0e9, "drop_rate": 1.0e12}

	var untold := Encounter.farm(cell, "grass")
	untold.arm(sure)
	var none := _uniques_of(untold)
	untold.start()
	_play(untold, 60)
	_check(none.is_empty(), "a fight nobody tells drops no uniques (%s)" % [none])

	var run := Encounter.farm(cell, "grass")
	run.arm(sure)
	run.uniques_after = 30
	run.unlocked = Achievements.STARTERS
	var found := _uniques_of(run)
	run.start()
	_play(run, 60)
	_check(not found.is_empty() and int(found[0][0]) == 30,
			"the first unique falls on the kill the wait ends at (%s)" % [found.slice(0, 2)])
	for pair: Array in found:
		_check(str(pair[1]) in Achievements.STARTERS, "%s is one the player has unlocked" % pair[1])

	# Only what is unlocked falls -- a home piece on any ground, since the Pilgrim's set went.
	for unlocked: Array in [["metronome"], ["rimeplate"], []]:
		var locked := Encounter.farm(cell, "grass")
		locked.arm(sure)
		locked.uniques_after = 0
		locked.unlocked = unlocked
		var fell := _uniques_of(locked)
		locked.start()
		_play(locked, 40)
		var names := fell.map(func(pair: Array) -> String: return pair[1])
		if unlocked.is_empty():
			_check(names.is_empty(), "nothing locked falls (%s)" % [names])
		else:
			_check(not names.is_empty() and names.all(func(id: String) -> bool: return id == unlocked[0]),
					"one unlocked unique is the only one that falls, on grass (%s)" % [names])
	_check(UniqueTable.pool_for(["rimeplate", "metronome", "no_such_unique"]) == ["rimeplate", "metronome"],
			"the pool is what is unlocked and this build has")

	# Not even a boss, at a drop rate that makes every chance certain, jumps the wait.
	var early := Encounter.for_tile(cell, "grass", "village")
	early.arm(sure)
	early.uniques_after = 1000
	var too_soon := _uniques_of(early)
	early.start()
	_play(early, 100)
	_check(early.victory and too_soon.is_empty(), "no unique before the wait is over (%s)" % [too_soon])

	for enemy: String in EnemyRoster.ENEMIES:
		var chance := UniqueTable.chance_for(enemy)
		match EnemyRoster.tier_of(enemy):
			EnemyRoster.Tier.COMMON:
				_check(chance > 0.0 and chance < 0.002, "%s almost never carries one (%f)" % [enemy, chance])
			EnemyRoster.Tier.ELITE:
				_check(chance >= 0.005 and chance < 0.05, "%s sometimes carries one (%f)" % [enemy, chance])
			EnemyRoster.Tier.BOSS:
				_check(chance >= 0.05 and chance <= 0.25, "%s often carries one (%f)" % [enemy, chance])
	# Item rarity lifts it at unique's rung of the ramp, on top of the drop rate.
	var step := float(ItemRarity.RARITY_STEP[ItemRarity.Rarity.UNIQUE])
	var any: String = EnemyRoster.ENEMIES.keys()[0]
	var base := UniqueTable.chance_for(any)
	_check(is_equal_approx(UniqueTable.chance_for(any, 0.0, 50.0), base * (1.0 + 0.5 * step))
			and is_equal_approx(UniqueTable.chance_for(any, 100.0, 50.0), base * 2.0 * (1.0 + 0.5 * step)),
			"item rarity lifts the unique chance")
	return true


## A fight on `env` with `effects` worn, its first enemy standing and given `hp` to soak blows with.
func _standing(effects: Array, stats: Dictionary, hp := 1.0e9, env := "grass") -> Encounter:
	var fight := Encounter.for_tile(Vector2i(12, 0), env)
	fight.effects = effects
	fight.arm(stats)
	fight.start()
	fight.advance(Encounter.WALK_IN)
	fight.health[0] = hp
	fight.hp = hp
	return fight


## What each unique changes about a fight, held to the sentence on its card.
func _test_unique_effects() -> bool:
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))

	# Metronome: the hand does nothing, the weapon does three times as much.
	var metro := _standing(["metronome"], {"damage": 9.0, "attack_speed": 1.0})
	_check(not metro.hit() and metro.hp == 1.0e9, "a click lands nothing beside a Metronome")
	metro.advance(1.0)
	_check(metro.hp == 1.0e9 - 30.0, "and its own swing deals triple (%s)" % (1.0e9 - metro.hp))

	# Headsman: a quarter on its own, and Execute's tenth on top.
	var axe := _standing(["headsman"], {"damage": 69.0}, 100.0)
	axe.hit()
	_check(axe.phase == Encounter.Phase.WAITING and axe.hp == 30.0, "30% left is past the Headsman")
	var axe_kill := _standing(["headsman"], {"damage": 75.0}, 100.0)
	axe_kill.hit()
	_check(axe_kill.phase == Encounter.Phase.DYING, "under 25% the Headsman finishes it")
	var both := _standing(["headsman", "execute"], {"damage": 69.0}, 100.0)
	both.hit()
	_check(both.phase == Encounter.Phase.DYING, "with Execute the line is 35%")
	var over := _standing(["headsman", "execute"], {"damage": 59.0}, 100.0)
	over.hit()
	_check(over.phase == Encounter.Phase.WAITING, "and 40% left is still past it")

	# Knucklebone: two points a click, fifty at most a ring, gone after a pause.
	var ring := _standing(["knucklebone"], {"damage": 99.0})
	listen.call(ring)
	for i in 40:
		ring.hit()
		ring.advance(0.1)
	_check(blows[0] == 100.0 and blows[1] == 102.0, "a streak adds 2 points a click (%s)" % [blows.slice(0, 3)])
	_check(blows[-1] == 150.0, "and stops at half again (%s)" % blows[-1])
	ring.advance(Encounter.KNUCKLE_WINDOW + 0.1)
	ring.hit()
	_check(blows[-1] == 100.0, "a pause loses the streak (%s)" % blows[-1])
	blows.clear()
	var rings := _standing(["knucklebone", "knucklebone"], {"damage": 99.0})
	listen.call(rings)
	for i in 40:
		rings.hit()
	_check(blows[-1] == 200.0, "two rings add, to double and no further (%s)" % blows[-1])
	# A click through a walk-in lands nothing and still keeps the streak.
	var walking := Encounter.for_tile(Vector2i(12, 0), "grass")
	walking.effects = ["knucklebone"]
	walking.start()
	_check(not walking.hit() and walking._click_streak == 1, "a click that lands nothing still counts")

	# Home ground: double there, nothing anywhere else.
	blows.clear()
	var home := _standing(["home:grass"], {"damage": 9.0})
	listen.call(home)
	home.hit()
	var away := _standing(["home:grass"], {"damage": 9.0}, 1.0e9, "desert")
	listen.call(away)
	away.hit()
	_check(blows == [20.0, 10.0], "a home piece doubles a blow at home alone (%s)" % [blows])

	# Hourglass: a second a kill, never past the start, never for a boss, never on a run.
	var glass := Encounter.for_tile(Vector2i(12, 0), "grass")
	glass.effects = ["hourglass"]
	glass.arm({"damage": 1.0e9})
	glass.start()
	glass.advance(Encounter.WALK_IN)
	glass.hit()
	_check(glass.time_left == glass.seconds, "the clock is never pushed past its start (%s)" % glass.time_left)
	glass.advance(5.0)
	var before := glass.time_left
	glass.hit()
	_check(is_equal_approx(glass.time_left, before + 1.0), "a kill puts a second back")
	var boss := Encounter.for_tile(Vector2i(12, 0), "grass", "village")
	boss.effects = ["hourglass"]
	boss.arm({"damage": 1.0e9})
	boss.index = boss.enemies - 1
	boss.hp = 1.0
	boss.phase = Encounter.Phase.WAITING
	boss.time_left = 10.0
	boss.hit()
	_check(boss.time_left == 10.0, "a boss gives no time back")
	var endless := Encounter.farm(Vector2i(12, 0), "grass")
	endless.effects = ["hourglass"]
	endless.arm({"damage": 1.0e9})
	endless.time_left = 10.0
	endless.start()
	_play(endless, 20)
	_check(endless.time_left == 10.0, "a run has no clock for the Hourglass to touch")

	# The Tithe: no ordinary gear however sure the drop, and the purse three times over -- five for two.
	var purses := []
	for worn: Array in [[], ["tithe"], ["tithe", "tithe"]]:
		var fight := Encounter.for_tile(Vector2i(12, 0), "grass")
		fight.effects = worn
		fight.always_drop = true
		fight.arm({"damage": 1.0e9})
		var gear := [0]
		fight.loot_dropped.connect(func(_i: int, _item: Item) -> void: gear[0] += 1)
		fight.start()
		_play(fight, 100)
		purses.append(fight.gold)
		_check((gear[0] == 0) == (not worn.is_empty()), "a Tithe means no ordinary gear (%d with %s)" % [gear[0], worn])
	_check(purses[1] == purses[0] * 3.0 and purses[2] == purses[0] * 5.0,
			"and three times the gold, five for two (%s)" % [purses])
	return true


## The frontier stays a frontier. The best a clicker can wear -- the Glass Edge, a Berserker's Band, a
## Knucklebone Ring, the Gambler's Die, the Packmule's Harness and the ground's own home piece, every
## line at the top of its band, over a farmed set of rares -- is worth a handful of hex steps and no
## more: monsters grow by `HP_GROWTH` a step for ever, and a set that multiplies a blow a fixed number
## of times is caught up.
##
## The steps are counted inside one band of land, from the first ring past a fallen wall out to the
## next wall, because a wall is no longer a step on that curve -- it is a cliff, and the last check
## here is that the set cannot walk over one.
## The second batch of uniques, each held to the sentence on its card.
func _test_more_unique_effects() -> bool:
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))
	var cell := Vector2i(12, 0)

	# One sum, not a product: a Metronome's swing at home is four times a blow, not six.
	var sum := _standing(["metronome", "home:grass"], {"damage": 9.0, "attack_speed": 1.0})
	sum.advance(1.0)
	_check(sum.hp == 1.0e9 - 40.0, "what uniques add to a blow is added up (%s)" % (1.0e9 - sum.hp))

	# Berserker's Band: the hand triples, the weapon stops.
	var bear := _standing(["berserk"], {"damage": 9.0, "attack_speed": 2.0})
	bear.advance(2.0)
	_check(bear.hp == 1.0e9, "the weapon never swings beside a Berserker's Band")
	bear.hit()
	_check(bear.hp == 1.0e9 - 30.0, "and a click deals triple (%s)" % (1.0e9 - bear.hp))

	# Glass Edge: double, paid for in clock -- and neither half on a run, which has none.
	var glass := _standing(["glass_edge"], {"damage": 9.0})
	var clock := glass.time_left
	glass.advance(3.0)
	_check(is_equal_approx(glass.time_left, clock - 4.0), "the Glass Edge spends the clock a third faster")
	glass.hit()
	_check(glass.hp == 1.0e9 - 20.0, "for double damage")
	var run := Encounter.farm(cell, "grass")
	run.effects = ["glass_edge", "last_gasp"]
	run.arm({"damage": 9.0})
	run.time_left = 1.0
	run.start()
	run.advance(Encounter.WALK_IN)
	run.health[0] = 1.0e9
	run.hp = 1.0e9
	run.hit()
	_check(run.hp == 1.0e9 - 10.0, "a run has no clock, so neither clock piece is worth anything on one")

	# Gambler's Die: anywhere from almost nothing to three times, a half more on the whole.
	var die := _standing(["gamble"], {"damage": 999.0})
	die.gamble_rng.seed = WORLD_SEED
	listen.call(die)
	for i in 2000:
		die.hit()
	var total := 0.0
	for amount: float in blows:
		total += amount
		_check(amount >= 10.0 and amount <= 3000.0, "a gambled blow stays inside its sentence (%s)" % amount)
	_check(total / 2000.0 > 1350.0 and total / 2000.0 < 1650.0, "and averages half again (%.0f)" % (total / 2000.0))
	blows.clear()

	# Serpent's Eye: from no crit chance at all, each blow that misses adds 5% until one crits.
	var serpent := _standing(["serpent"], {"damage": 9.0})
	serpent.hit()
	_check(serpent._serpent == UniqueTable.dial("serpents_eye", "step"),
			"a blow that did not crit builds the chance (%s)" % serpent._serpent)
	var crits: Array = []
	serpent.hit_landed.connect(func(_amount: float, crit: bool, _a: bool) -> void:
		crits.append([crit, serpent._serpent]))
	for i in 60:
		serpent.hit()
	var first_crit := crits.find_custom(func(blow: Array) -> bool: return blow[0])
	_check(first_crit >= 0 and first_crit <= 19, "a crit comes by the time the chance is certain (blow %d)" % first_crit)
	_check(crits.all(func(blow: Array) -> bool: return (blow[1] == 0.0) == blow[0]),
			"a crit spends what was built, and only a crit does")
	var twice := _standing(["serpent", "serpent"], {"damage": 9.0})
	twice.hit()
	_check(twice._serpent == 2.0 * UniqueTable.dial("serpents_eye", "step"),
			"one on each doll builds twice as fast (%s)" % twice._serpent)
	var without := _standing([], {"damage": 9.0})
	without.hit()
	_check(without._serpent == 0.0, "and nothing builds without one")

	# Ascetic's Cord and the Packmule's Harness read a count the inventory hands over.
	var bare := _standing(["ascetic"], {"damage": 9.0, "bare_sockets": 4})
	bare.hit()
	_check(bare.hp == 1.0e9 - 16.0, "15%% a bare socket (%s)" % (1.0e9 - bare.hp))
	var mule := _standing(["packmule"], {"damage": 9.0, "bag_pieces": 40})
	mule.hit()
	_check(mule.hp == 1.0e9 - 14.0, "1%% a piece in the bag (%s)" % (1.0e9 - mule.hp))
	# And the Patchwork Coat and the Purist's Seal, theirs.
	var patch := _standing(["patchwork"], {"damage": 9.0, "attribute_lines": 10})
	patch.hit()
	_check(patch.hp == 1.0e9 - 12.0, "2%% an attribute line (%s)" % (1.0e9 - patch.hp))
	var pure := _standing(["purist"], {"damage": 9.0, "pure_pieces": 5})
	pure.hit()
	_check(pure.hp == 1.0e9 - 15.0, "10%% a piece without one (%s)" % (1.0e9 - pure.hp))

	# Brawler's Wraps: strength on the hand, dexterity on the weapon's own swing.
	var brawl := _standing(["brawler"], {"damage": 9.0, "attack_speed": 1.0, "strength": 50.0, "dexterity": 100.0})
	listen.call(brawl)
	brawl.hit()
	brawl.advance(1.0)
	_check(blows == [15.0, 20.0], "a click takes the strength, a swing the dexterity (%s)" % [blows])
	blows.clear()

	# Last Gasp: the last five seconds and not a moment before.
	var gasp := _standing(["last_gasp"], {"damage": 9.0})
	listen.call(gasp)
	gasp.time_left = 5.5
	gasp.hit()
	gasp.time_left = 5.0
	gasp.hit()
	_check(blows == [10.0, 30.0], "Last Gasp triples under five seconds (%s)" % [blows])
	blows.clear()

	# Duelist's Buckler: the first blow on each enemy crits, with no crit chance at all.
	var duel := _standing(["opening_strike"], {"damage": 9.0, "crit_damage": 100.0}, 25.0)
	listen.call(duel)
	duel.hit()
	duel.hit()
	duel.advance(Encounter.DEATH)
	duel.advance(Encounter.WALK_IN)
	duel.hit()
	_check(blows == [20.0, 10.0, 20.0], "the first blow on every enemy is a crit (%s)" % [blows])
	blows.clear()

	# Overflowing Chalice: what the cap throws away comes back as crit damage.
	var chalice := Encounter.for_tile(cell, "grass")
	chalice.effects = ["overcrit"]
	chalice.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(chalice.crit_chance == Encounter.CRIT_CAP
			and chalice.crit_damage == 50.0 + 30.0 * UniqueTable.dial("overflowing_chalice", "times"),
			"crit chance past the cap becomes crit damage (%s)" % chalice.crit_damage)
	var plain := Encounter.for_tile(cell, "grass")
	plain.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(plain.crit_damage == 50.0, "and is simply lost without it")

	# Snowball: 2% a kill, and no further than double.
	var snow := _standing(["momentum"], {"damage": 9.0})
	snow.index = 10
	var ten := snow.unique_more(false)
	snow.index = 500
	var many := snow.unique_more(false)
	_check(is_equal_approx(ten, 0.2) and is_equal_approx(many, 1.0), "momentum builds and stops at double (%s, %s)"
			% [ten, many])

	# Bulwark: a blow block stops entirely is answered with a swing; one it only cuts is not.
	var wall := _standing(["riposte"], {"damage": 0.0, "block": 50.0})
	listen.call(wall)
	wall._struck_by(4.0)
	_check(blows.size() == 1, "a blow blocked whole is answered (%d)" % blows.size())
	wall._struck_by(9.0)
	_check(blows.size() == 1, "and one that gets through is not (%d)" % blows.size())
	blows.clear()

	# Heartwood Plate: a second every HEARTWOOD_ARMOUR armour, its rank's most at most, none on a run.
	for case: Array in [[225.0, 4.0], [50000.0, UniqueTable.dial("heartwood_plate", "most")]]:
		var oak := Encounter.for_tile(cell, "grass")
		oak.effects = ["heartwood"]
		oak.arm({"armor": case[0]})
		_check(oak.seconds == Encounter.SECONDS + float(case[1]) and oak.time_left == oak.seconds,
				"%s armour is %s seconds" % case)
	var oak_run := Encounter.farm(cell, "grass")
	oak_run.effects = ["heartwood"]
	oak_run.arm({"armor": 225.0})
	_check(oak_run.seconds == Encounter.SECONDS, "and a run has no clock to add to")

	# The Fight Clock on gear, in tenths: capped at CLOCK_MOST, and none on a run either.
	for case: Array in [[25.0, 2.5], [400.0, Encounter.CLOCK_MOST]]:
		var clocked := Encounter.for_tile(cell, "grass")
		clocked.arm({"fight_clock": case[0]})
		_check(clocked.seconds == Encounter.SECONDS + float(case[1]) and clocked.time_left == clocked.seconds,
				"%s tenths of Fight Clock are %s seconds (%s)" % [case[0], case[1], clocked.seconds])
	var clocked_run := Encounter.farm(cell, "grass")
	clocked_run.arm({"fight_clock": 25.0})
	_check(clocked_run.seconds == Encounter.SECONDS, "and a run's clock is not lengthened")
	# Armed again mid-fight (gear changed in the bag): the clock moves by what changed, never refills.
	var rearmed := Encounter.for_tile(cell, "grass")
	rearmed.arm({"fight_clock": 25.0})
	rearmed.time_left -= 10.0
	rearmed.arm({"fight_clock": 25.0})
	_check(rearmed.seconds == Encounter.SECONDS + 2.5 and rearmed.time_left == rearmed.seconds - 10.0,
			"arming again with the same gear leaves the clock where it was (%s)" % rearmed.time_left)
	rearmed.arm({})
	_check(rearmed.seconds == Encounter.SECONDS and rearmed.time_left == Encounter.SECONDS - 10.0,
			"and taking the piece off takes its seconds back (%s)" % rearmed.time_left)

	# Magpie's Band: some purses are gear instead -- unless a Tithe says there is no gear.
	for worn: Array in [["magpie"], ["magpie", "tithe"]]:
		var nest := Encounter.farm(cell, "grass")
		nest.effects = worn
		nest.arm({"damage": 1.0e9})
		nest.loot_rng.seed = WORLD_SEED
		# Purses, finds and bodies, counted as they fall: `kills` lags a body still going down.
		var seen := [0, 0, 0]
		nest.gold_dropped.connect(func(_i: int, _g: float) -> void: seen[0] += 1)
		nest.loot_dropped.connect(func(_i: int, _item: Item) -> void: seen[1] += 1)
		nest.enemy_died.connect(func(_i: int) -> void: seen[2] += 1)
		nest.start()
		_play(nest, 400)
		var traded: int = seen[2] - seen[0]
		if "tithe" in worn:
			_check(traded == 0 and seen[1] == 0, "the Tithe keeps every purse a purse")
		else:
			_check(traded >= 5 and traded <= 45 and seen[1] >= traded,
					"about one purse in twenty is gear (%d of %d)" % [traded, seen[2]])

	# Lucky Wound: a body that took a crit leaves the better of two rolls.
	var worth := {}
	for kind: String in ["plain", "lucky", "no crit"]:
		var wound := Encounter.farm(cell, "grass")
		wound.effects = [] if kind == "plain" else ["lucky_wound"]
		wound.always_drop = true
		wound.arm({"damage": 1.0e9, "crit_chance": 0.0 if kind == "no crit" else 100.0})
		wound.loot_rng.seed = WORLD_SEED
		var tally := [0]
		wound.loot_dropped.connect(func(_i: int, item: Item) -> void: tally[0] += int(item.rarity) * 100 + item.level)
		wound.start()
		_play(wound, 300)
		worth[kind] = tally[0]
	_check(worth["lucky"] > worth["plain"], "two rolls and the better kept (%s)" % [worth])
	_check(worth["no crit"] == worth["plain"], "and only where a crit landed")

	# Only the killing blow counts: the Duelist's Buckler crits each body's first blow, and a plain
	# blow finishes it, so the Wound pays nothing over the same fight without it. A tile fight, whose
	# lineup is seeded from the cell, so both meet the same ten bodies.
	var opened := {}
	for kind: String in ["plain", "lucky"]:
		var wound := Encounter.for_tile(cell, "grass")
		wound.effects = ["opening_strike"] if kind == "plain" else ["opening_strike", "lucky_wound"]
		wound.always_drop = true
		wound.arm({"damage": wound.health[0] * 0.6, "crit_chance": 0.0, "crit_damage": 0.0})
		wound.loot_rng.seed = WORLD_SEED
		var tally := [0, 0]
		wound.loot_dropped.connect(func(_i: int, item: Item) -> void:
			tally[0] += int(item.rarity) * 100 + item.level
			tally[1] += 1)
		wound.start()
		_play(wound, 300)
		opened[kind] = tally
	_check(opened["plain"][1] == Encounter.ENEMIES and opened["lucky"] == opened["plain"],
			"a crit that did not kill buys no second roll (%s)" % [opened])
	return true


## Dominoes: what a one-blow kill had left over goes into the next body at its rank's share as that body
## takes its stand, a body it fells passes its own leftover on, and nothing of it reaches an elite.
func _test_dominoes() -> bool:
	var share := UniqueTable.dial("dominoes", "share") / 100.0
	# A thousand into a hundred leaves nine hundred over.
	var fall := _standing(["domino"], {"damage": 999.0}, 100.0)
	fall.health[1] = 1.0e6
	fall.hit()
	fall.advance(Encounter.DEATH)
	_check(fall.hp == 1.0e6, "the next comes on whole (%s)" % fall.hp)
	fall.advance(Encounter.WALK_IN)
	_check(is_equal_approx(fall.hp, 1.0e6 - 900.0 * share), "and takes the share as it stands (%s)" % (1.0e6 - fall.hp))

	# A body the carry is enough for falls as it stands, a one-blow kill, and its leftover goes on.
	var chain := _standing(["domino"], {"damage": 999.0}, 100.0)
	chain.health[1] = 900.0 * share - 10.0
	chain.health[2] = 1.0e6
	chain.hit()
	chain.advance(Encounter.DEATH)
	chain.advance(Encounter.WALK_IN)
	_check(chain.index == 1 and chain.phase == Encounter.Phase.DYING, "the carry fells a body it is enough for")
	chain.advance(Encounter.DEATH)
	chain.advance(Encounter.WALK_IN)
	_check(is_equal_approx(chain.hp, 1.0e6 - 10.0 * share),
			"and what that had left over goes on at the same share (%s)" % (1.0e6 - chain.hp))
	_check(chain.tally.get("domino_streak") == 2, "a body it fells is a one-blow kill (%s)" % [chain.tally])

	# Never into an elite: an ordinary fight's last body is its elite.
	var elite := _standing(["domino"], {"damage": 999.0}, 100.0)
	var last := elite.enemies - 1
	elite.index = last - 1
	elite.health[last - 1] = 100.0
	elite.hp = 100.0
	elite.hit()
	elite.advance(Encounter.DEATH)
	elite.advance(Encounter.WALK_IN)
	_check(EnemyRoster.tier_of(elite.lineup[last]) == EnemyRoster.Tier.ELITE and elite.hp == elite.health[last],
			"nothing is carried into an elite")

	# A body that took two blows carries nothing.
	var slow := _standing(["domino"], {"damage": 59.0}, 100.0)
	slow.hit()
	slow.hit()
	slow.advance(Encounter.DEATH)
	slow.advance(Encounter.WALK_IN)
	_check(slow.hp == slow.health[1], "two blows topple nothing")

	# Cleave beside it: the whole of what was over comes off before the body is out, and the share on top.
	var both := _standing(["domino", "cleave"], {"damage": 999.0}, 100.0)
	both.health[1] = 1.0e6
	both.hit()
	both.advance(Encounter.DEATH)
	_check(both.hp == 1.0e6 - 900.0, "Cleave takes all of it off as the body comes on (%s)" % both.hp)
	both.advance(Encounter.WALK_IN)
	_check(is_equal_approx(both.hp, 1.0e6 - 900.0 - 900.0 * share), "and Dominoes its share as it stands")
	return true


## A fight reads every ranked unique's numbers at the rank it was told (`Encounter.wear`), each the
## card's own figure (`UniqueTable.dial`). A fight told nothing is rank I, which every test above plays.
func _test_unique_ranks() -> bool:
	var told := func(worn: Array, ranks: Dictionary, stats: Dictionary, hp := 1.0e9, env := "grass") -> Encounter:
		var fight := Encounter.for_tile(Vector2i(12, 0), env)
		fight.wear(worn, ranks)
		fight.arm(stats)
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.health[0] = hp
		fight.hp = hp
		return fight
	var four := func(id: String, key: String) -> float: return UniqueTable.dial(id, key, UniqueTable.PEAK)
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))

	# A blow of 10, and what each rank IV piece makes of it.
	var metro: Encounter = told.call(["metronome"], {"metronome": 4}, {"damage": 9.0, "attack_speed": 1.0})
	metro.advance(1.0)
	_check(metro.hp == 1.0e9 - 10.0 * four.call("metronome", "times"), "a Metronome at IV (%s)" % (1.0e9 - metro.hp))
	var band: Encounter = told.call(["berserk"], {"berserkers_band": 4}, {"damage": 9.0})
	band.hit()
	_check(band.hp == 1.0e9 - 10.0 * four.call("berserkers_band", "times"), "a Berserker's Band at IV")
	var edge: Encounter = told.call(["glass_edge"], {"glass_edge": 4}, {"damage": 9.0})
	edge.hit()
	_check(edge.hp == 1.0e9 - 10.0 * four.call("glass_edge", "times"), "a Glass Edge at IV")
	var home: Encounter = told.call(["home:grass"], {"meadowstriders": 3}, {"damage": 9.0})
	home.hit()
	_check(home.hp == 1.0e9 - 10.0 * UniqueTable.dial("meadowstriders", "times", 3), "a home piece at III, on its ground")
	var other: Encounter = told.call(["home:grass"], {"rimeplate": 4}, {"damage": 9.0})
	other.hit()
	_check(other.hp == 1.0e9 - 10.0 * UniqueTable.dial("meadowstriders", "times", 1),
			"and another ground's piece's rank is not its own")
	for case: Array in [["ascetic", "ascetics_cord", "bare_sockets", 4], ["packmule", "packmule", "bag_pieces", 40],
			["patchwork", "patchwork_coat", "attribute_lines", 10], ["purist", "purists_seal", "pure_pieces", 5]]:
		var fight: Encounter = told.call([case[0]], {case[1]: 4}, {"damage": 9.0, case[2]: case[3]})
		fight.hit()
		_check(is_equal_approx(fight.hp, 1.0e9 - roundf(10.0 * (1.0 + four.call(case[1], "more") / 100.0 * case[3]))),
				"%s at IV reads its count at its rank (%s)" % [case[1], 1.0e9 - fight.hp])
	var brawl: Encounter = told.call(["brawler"], {"brawlers_wraps": 4}, {"damage": 9.0, "strength": 50.0})
	brawl.hit()
	_check(brawl.hp == 1.0e9 - roundf(10.0 * (1.0 + four.call("brawlers_wraps", "more") / 100.0 * 50.0)),
			"Brawler's Wraps at IV")
	var gasp: Encounter = told.call(["last_gasp"], {"last_gasp": 4}, {"damage": 9.0})
	gasp.time_left = four.call("last_gasp", "seconds")
	gasp.hit()
	_check(gasp.hp == 1.0e9 - 30.0, "Last Gasp's window at IV")

	# Knucklebone at IV: its rank's step a click, and its rank's most.
	var ring: Encounter = told.call(["knucklebone"], {"knucklebone_ring": 4}, {"damage": 99.0})
	listen.call(ring)
	for i in 100:
		ring.hit()
	# The first click lands before it is counted, so the second is the first with the step on it.
	_check(blows[1] == roundf(100.0 * (1.0 + four.call("knucklebone_ring", "step") / 100.0))
			and blows[-1] == roundf(100.0 * (1.0 + four.call("knucklebone_ring", "most") / 100.0)),
			"a Knucklebone Ring at IV (%s, %s)" % [blows[1], blows[-1]])
	blows.clear()

	# The Headsman's line, the Duelist's opening blows, the Serpent's step.
	var line: float = four.call("headsman", "share")
	# A blow of 101 - line leaves line - 1: under the rank IV line, and well over rank I's.
	var axe: Encounter = told.call(["headsman"], {"headsman": 4}, {"damage": 100.0 - line}, 100.0)
	axe.hit()
	_check(axe.phase == Encounter.Phase.DYING, "a Headsman at IV finishes a body under %s%%" % line)
	var duel: Encounter = told.call(["opening_strike"], {"duelists_buckler": 3}, {"damage": 9.0, "crit_damage": 100.0})
	listen.call(duel)
	for i in 5:
		duel.hit()
	var opening := int(UniqueTable.dial("duelists_buckler", "blows", 3))
	_check(blows.count(20.0) == opening and blows.count(10.0) == 5 - opening,
			"a Duelist's Buckler at III crits the first %d blows (%s)" % [opening, blows])
	blows.clear()
	var serpent: Encounter = told.call(["serpent"], {"serpents_eye": 4}, {"damage": 9.0})
	serpent.hit()
	_check(serpent._serpent == four.call("serpents_eye", "step"), "a Serpent's Eye at IV")

	# The Bulwark's answer, at its rank's share of a swing.
	var wall: Encounter = told.call(["riposte"], {"bulwark": 4}, {"damage": 9.0, "block": 50.0})
	listen.call(wall)
	wall._struck_by(4.0)
	_check(blows == [roundf(10.0 * four.call("bulwark", "share") / 100.0)], "a Bulwark at IV answers harder (%s)" % [blows])
	blows.clear()

	# The Gambler's Die reaches its rank's top, and never past it.
	var die: Encounter = told.call(["gamble"], {"gamblers_die": 4}, {"damage": 999.0})
	die.gamble_rng.seed = WORLD_SEED
	listen.call(die)
	for i in 2000:
		die.hit()
	var top: float = 1000.0 * four.call("gamblers_die", "top")
	_check(blows.max() <= top and blows.max() > 1000.0 * UniqueTable.dial("gamblers_die", "top", 1),
			"a Gambler's Die at IV (best %s of %s)" % [blows.max(), top])
	blows.clear()

	# What `arm` reads: the Chalice's overflow and the Heartwood's most.
	var chalice := Encounter.for_tile(Vector2i(12, 0), "grass")
	chalice.wear(["overcrit"], {"overflowing_chalice": 4})
	chalice.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(chalice.crit_damage == 50.0 + 30.0 * four.call("overflowing_chalice", "times"), "an Overflowing Chalice at IV")
	var oak := Encounter.for_tile(Vector2i(12, 0), "grass")
	oak.wear(["heartwood"], {"heartwood_plate": 4})
	oak.arm({"armor": 1.0e6})
	_check(oak.seconds == Encounter.SECONDS + four.call("heartwood_plate", "most"), "a Heartwood Plate at IV")

	# What a kill pays: the Hourglass's seconds, the Tithe's purse, Dominoes' share.
	var glass: Encounter = told.call(["hourglass"], {"hourglass_amulet": 4}, {"damage": 1.0e9}, 1.0)
	glass.advance(5.0)
	var before := glass.time_left
	glass.hit()
	_check(is_equal_approx(glass.time_left, before + four.call("hourglass_amulet", "seconds")), "an Hourglass at IV")
	var purses := []
	for ranks: Dictionary in [{}, {"the_tithe": 4}]:
		var fight: Encounter = told.call(["tithe"] if not ranks.is_empty() else [], ranks, {"damage": 1.0e9}, 1.0)
		fight.hit()
		purses.append(fight.gold)
	_check(purses[1] == purses[0] * four.call("the_tithe", "times"), "The Tithe at IV (%s)" % [purses])
	var fall: Encounter = told.call(["domino"], {"dominoes": 4}, {"damage": 999.0}, 100.0)
	fall.health[1] = 1.0e6
	fall.hit()
	fall.advance(Encounter.DEATH)
	fall.advance(Encounter.WALK_IN)
	_check(is_equal_approx(fall.hp, 1.0e6 - 900.0 * four.call("dominoes", "share") / 100.0), "Dominoes at IV")
	return true


## A fight on `env` told `worn` and the unique `ranks`, its first enemy standing with `hp` to soak.
func _told(worn: Array, ranks: Dictionary, stats: Dictionary, hp := 1.0e9, env := "grass",
		variant := "") -> Encounter:
	var fight := Encounter.for_tile(Vector2i(12, 0), env, variant)
	fight.wear(worn, ranks)
	fight.arm(stats)
	fight.start()
	fight.advance(Encounter.WALK_IN)
	fight.health[0] = hp
	fight.hp = hp
	return fight


## Puts `fight` on its last body -- an elite, or a settlement's boss -- standing with `hp`.
func _on_last(fight: Encounter, hp := 1.0e9) -> Encounter:
	fight.index = fight.enemies - 1
	fight.health[fight.index] = hp
	fight.hp = hp
	return fight


## The line each unique gains at rank IV, and that rank III has not got it. Each held to its card.
func _test_rank_four() -> bool:
	var iv := UniqueTable.PEAK
	var blows: Array = []
	var listen := func(fight: Encounter) -> void:
		fight.hit_landed.connect(func(amount: float, _c: bool, _a: bool) -> void: blows.append(amount))

	# Knucklebone Ring: at the full bonus the weapon's swings get it too.
	for rank in [3, iv]:
		var ring := _told(["knucklebone"], {"knucklebone_ring": rank}, {"damage": 99.0})
		var clicks := int(ceilf(UniqueTable.dial("knucklebone_ring", "most", rank)
				/ UniqueTable.dial("knucklebone_ring", "step", rank)))
		for i in clicks:
			ring.hit()
		var swung := ring.unique_more(true)
		_check(is_equal_approx(swung, UniqueTable.dial("knucklebone_ring", "most", rank) / 100.0 if rank == iv else 0.0),
				"a full Knucklebone reaches the swings only at IV (rank %d: %s)" % [rank, swung])

	# Duelist's Buckler: an opening crit on an elite adds its crit damage twice.
	for rank in [3, iv]:
		var duel := _on_last(_told(["opening_strike"], {"duelists_buckler": rank}, {"damage": 9.0, "crit_damage": 100.0}))
		duel._blows = 0
		listen.call(duel)
		duel.hit()
	_check(blows == [20.0, 30.0], "the Buckler's opening crit on an elite, at III and at IV (%s)" % [blows])
	blows.clear()

	# Serpent's Eye: a crit keeps half of what was built.
	for rank in [3, iv]:
		var serpent := _told(["serpent"], {"serpents_eye": rank}, {"damage": 9.0, "crit_chance": 100.0})
		serpent._serpent = 40.0
		serpent.hit()
		_check(serpent._serpent == (40.0 * Encounter.SERPENT_KEPT if rank == iv else 0.0),
				"a crit leaves the Serpent %s at rank %d" % [serpent._serpent, rank])

	# Spiked Helm: a blow blocked whole, or dodged, sends a tenth of the armour back.
	for stats: Dictionary in [{"armor": 1000.0, "block": 1.0e6}, {"armor": 1000.0, "dodge": 1.0e12}]:
		for rank in [3, iv]:
			var helm := _told(["spikes"], {"spiked_helm": rank}, stats)
			helm._struck_by(1.0)
			_check(helm.hp == (1.0e9 - 1000.0 * Encounter.SPIKES_BACK if rank == iv else 1.0e9),
					"the Helm sends %s back at rank %d (%s)" % [1.0e9 - helm.hp, rank, stats.keys()])

	# Ogre's Knuckle: strength is Execute too, to its most.
	for rank in [3, iv]:
		var ogre := _told(["ogre"], {"ogres_knuckle": rank}, {"damage": 75.0, "strength": 1.0e6}, 100.0)
		ogre.hit()
		_check((ogre.phase == Encounter.Phase.DYING) == (rank == iv), "the Knuckle executes 24 of 100 only at IV")

	# Butcher's Cleaver: a body that dies of its wound hands it to the next.
	for rank in [3, iv]:
		var cleaver := _told(["butcher"], {"butchers_cleaver": rank}, {"damage": 19.0, "bleed": 50.0}, 30.0)
		cleaver.hit()
		cleaver.advance(1.0)
		cleaver.advance(Encounter.DEATH)
		_check(cleaver.index == 1 and cleaver._bleed == (10.0 if rank == iv else 0.0),
				"the wound goes on at rank %d: %s" % [rank, cleaver._bleed])

	# The home pieces, on their own grounds: experience, a promised elite, a purse, the clock.
	var meadow := Encounter.for_tile(Vector2i(12, 0), "grass")
	meadow.wear(["home:grass"], {"meadowstriders": iv})
	meadow.arm({})
	_check(meadow.xp_more == Encounter.HOME_XP, "Meadowstriders at IV: double experience on grass")
	var promised := []
	for rank in [3, iv]:
		var lantern := _on_last(_told(["home:forest"], {"hunters_lantern": rank}, {"damage": 1.0e9}, 1.0e9, "forest"), 1.0)
		var found := [0]
		lantern.loot_dropped.connect(func(_i: int, _item: Item) -> void: found[0] += 1)
		lantern.hit()
		promised.append(found[0])
	_check(promised[1] >= 1, "the Lantern at IV: a forest elite always drops (%s)" % [promised])
	var purses := []
	for rank in [3, iv]:
		var cowl := _told(["home:desert"], {"sunscorched_cowl": rank}, {"damage": 1.0e9}, 1.0, "desert")
		cowl.hit()
		purses.append(cowl.gold)
	_check(purses[1] == purses[0] * Encounter.HOME_PURSE, "the Cowl at IV: desert purses twice as full (%s)" % [purses])
	for rank in [3, iv]:
		var rime := _told(["home:ice"], {"rimeplate": rank}, {}, 1.0e9, "ice")
		var left := rime.time_left
		rime.advance(2.0)
		_check(is_equal_approx(left - rime.time_left, 2.0 * (Encounter.HOME_CLOCK if rank == iv else 1.0)),
				"the clock on ice at rank %d" % rank)

	# A second chance at a unique, drawn only where one is owed: an empty pool keeps it to one draw a roll.
	for case: Array in [[["home:mountains"], {"stonebreaker": iv}, "mountains", {}],
			[["lucky_wound"], {"lucky_wound": iv}, "grass", {"crit_chance": 100.0}]]:
		for rank_of: int in [3, iv]:
			var ranks := {}
			for id: String in case[1]:
				ranks[id] = rank_of
			var stats: Dictionary = {"damage": 1.0e9}
			stats.merge(case[3])
			var fight := _on_last(_told(case[0], ranks, stats, 1.0e9, case[2], "village"), 1.0)
			fight.uniques_after = 0
			fight.unlocked = []
			fight.unique_rng.seed = WORLD_SEED
			var reference := RandomNumberGenerator.new()
			reference.seed = WORLD_SEED
			for draw in (2 if rank_of == iv else 1):
				reference.randf()
			fight.hit()
			_check(fight.unique_rng.state == reference.state,
					"%s draws the unique %d time(s) at rank %d" % [case[0], 2 if rank_of == iv else 1, rank_of])

	# Gravedigger's Charm: orbs twice as often on dirt.
	var orbs := []
	for rank in [3, iv]:
		var run := Encounter.farm(Vector2i(12, 0), "dirt")
		run.wear(["home:dirt"], {"gravediggers_charm": rank})
		run.arm({"damage": 1.0e9})
		run.orb_rng.seed = WORLD_SEED
		run.start()
		_play(run, 600)
		orbs.append(run.orbs.values().reduce(func(a: int, b: int) -> int: return a + b, 0))
	_check(orbs[1] > orbs[0] * 1.5, "the Charm at IV: more orbs on dirt (%s)" % [orbs])

	# Bulwark: the answer is always a crit.
	var wall := _told(["riposte"], {"bulwark": iv}, {"damage": 9.0, "block": 50.0, "crit_damage": 100.0})
	listen.call(wall)
	wall._struck_by(4.0)
	_check(blows == [roundf(20.0 * UniqueTable.dial("bulwark", "share", iv) / 100.0)], "the Bulwark at IV answers with a crit (%s)" % [blows])
	blows.clear()

	# Brawler's Wraps: strength and dexterity both, on clicks and on swings.
	var brawl := _told(["brawler"], {"brawlers_wraps": iv}, {"damage": 9.0, "strength": 50.0, "dexterity": 100.0})
	var each := UniqueTable.dial("brawlers_wraps", "more", iv) / 100.0 * 150.0
	_check(is_equal_approx(brawl.unique_more(false), each) and is_equal_approx(brawl.unique_more(true), each),
			"the Wraps at IV count both on both")

	# Last Gasp: in its last seconds the enemies hold their blows.
	for rank in [3, iv]:
		var gasp := _told(["last_gasp"], {"last_gasp": rank}, {})
		gasp.strikes = true
		gasp.time_left = 3.0
		gasp.advance(2.5)
		_check(gasp.tally.has("blows_taken") == (rank != iv), "blows in the last seconds at rank %d" % rank)

	# Ascetic's Cord: a little dodge a bare place, never past the most.
	for case: Array in [[4, 4 * Encounter.ASCETIC_DODGE], [100, Encounter.DODGE_MOST]]:
		var cord := _told(["ascetic"], {"ascetics_cord": iv}, {"bare_sockets": case[0]})
		_check(is_equal_approx(cord.dodge_chance(), case[1]), "%d bare places at IV dodge %s" % [case[0], cord.dodge_chance()])

	# Dominoes: into an elite, half of the carry.
	var elite := _told(["domino"], {"dominoes": iv}, {"damage": 999.0}, 100.0)
	var last := elite.enemies - 1
	elite.index = last - 1
	elite.health[last - 1] = 100.0
	elite.health[last] = 1.0e6
	elite.hp = 100.0
	elite.hit()
	elite.advance(Encounter.DEATH)
	elite.advance(Encounter.WALK_IN)
	_check(is_equal_approx(elite.hp, elite.health[last] - 900.0 * UniqueTable.dial("dominoes", "share", iv) / 100.0
			* Encounter.DOMINO_BIG), "Dominoes at IV reaches an elite at half")

	# Gambler's Die: the first blow on each enemy is drawn twice and the better kept.
	var die := _told(["gamble"], {"gamblers_die": iv}, {"damage": 999.0})
	die.gamble_rng.seed = WORLD_SEED
	var draws := RandomNumberGenerator.new()
	draws.seed = WORLD_SEED
	var top := UniqueTable.dial("gamblers_die", "top", iv)
	var best := maxf(draws.randf_range(Encounter.GAMBLE_LEAST, top), draws.randf_range(Encounter.GAMBLE_LEAST, top))
	listen.call(die)
	die.hit()
	_check(blows[0] == maxf(1.0, roundf(1000.0 * best)), "the Die at IV draws the first blow twice (%s)" % [blows])
	blows.clear()

	# The Tithe: an elite's gear gets through.
	var through := []
	for rank in [3, iv]:
		var tithe := _on_last(_told(["tithe"], {"the_tithe": rank}, {"damage": 1.0e9}), 1.0)
		tithe.always_drop = true
		var gear := [0]
		tithe.loot_dropped.connect(func(_i: int, _item: Item) -> void: gear[0] += 1)
		tithe.hit()
		through.append(gear[0])
	_check(through[0] == 0 and through[1] >= 1, "the Tithe lets an elite's gear through at IV (%s)" % [through])

	# Heartwood Plate: every enemy's first blow is blocked whole, and a Bulwark answers it.
	var oak := _told(["heartwood", "riposte"], {"heartwood_plate": iv}, {"damage": 9.0})
	listen.call(oak)
	var clock := oak.time_left
	oak._struck_by(5.0)
	_check(oak.time_left == clock and oak.tally.get("blocked") == 1 and blows.size() == 1,
			"the first blow is blocked, counted and answered")
	oak._struck_by(5.0)
	_check(oak.time_left < clock, "and the second is not")
	blows.clear()

	# Hourglass Amulet: a boss kill puts its seconds back.
	for rank in [3, iv]:
		var boss := _on_last(_told(["hourglass"], {"hourglass_amulet": rank}, {"damage": 1.0e9}, 1.0e9, "grass", "village"), 1.0)
		boss.time_left = 10.0
		boss.hit()
		_check(boss.time_left == (10.0 + Encounter.HOURGLASS_BOSS if rank == iv else 10.0), "a boss kill at rank %d" % rank)

	# Metronome: a swing that kills leaves the next swing ready.
	for rank in [3, iv]:
		var metro := _told(["metronome"], {"metronome": rank}, {"damage": 1.0e9, "attack_speed": 1.0}, 1.0)
		metro.advance(1.0)
		_check(metro.phase == Encounter.Phase.DYING and metro._swing == (1.0 if rank == iv else 0.0),
				"the next swing is ready at rank %d" % rank)

	# Berserker's Band: every tenth click strikes twice.
	var band := _told(["berserk"], {"berserkers_band": iv}, {"damage": 9.0})
	listen.call(band)
	for i in Encounter.BERSERK_EVERY:
		band.hit()
	_check(blows[-1] == 2.0 * blows[0] and blows[-2] == blows[0], "the tenth click strikes twice (%s)" % [blows])
	blows.clear()

	# Glass Edge: its damage in a farm run too.
	for rank in [3, iv]:
		var run := Encounter.farm(Vector2i(12, 0), "grass")
		run.wear(["glass_edge"], {"glass_edge": rank})
		_check(is_equal_approx(run.unique_more(false),
				UniqueTable.dial("glass_edge", "times", rank) - 1.0 if rank == iv else 0.0),
				"the Edge in a run at rank %d" % rank)

	# Headsman: what the execution took goes on into the next body.
	var axe := _told(["headsman"], {"headsman": iv}, {"damage": 79.0}, 100.0)
	axe.health[1] = 1.0e6
	axe.hit()
	axe.advance(Encounter.DEATH)
	_check(axe.hp == 1.0e6 - 20.0, "the Headsman at IV carries the 20 it executed (%s)" % (1.0e6 - axe.hp))

	# Overflowing Chalice: about one crit in ten strikes twice.
	var chalice := _told(["overcrit"], {"overflowing_chalice": iv}, {"damage": 9.0, "crit_chance": 100.0})
	chalice.crit_rng.seed = WORLD_SEED
	listen.call(chalice)
	for i in 1000:
		chalice.hit()
	var doubled := blows.count(blows.min() * 2.0)
	_check(doubled > 50 and doubled < 150, "about one crit in ten strikes twice (%d of 1000)" % doubled)
	blows.clear()
	return true


## Clicks the fight to its end at a steady rate, stepping the clock between clicks. Returns the clicks
## it took. `limit` stops a broken encounter from looping forever.
func _play(fight: Encounter, limit: int) -> int:
	var clicks := 0
	var step := 1.0 / 8.0   # A brisk but human eight clicks a second.
	while not fight.finished and clicks < limit:
		if not fight.hit():
			fight.advance(step)      # Walking in or dying: let the clock run.
			continue
		clicks += 1
		fight.advance(step)
	return clicks


## Orbs off the bodies: a third draw, on its own generator and its own curve, beside the gear rather
## than instead of it.
func _test_orb_drops() -> bool:
	# Guaranteed, so the tally is the kill count and not a sample of a 5% chance.
	var fight := Encounter.for_tile(Vector2i(4, 0), "grass")
	fight.always_orb = true
	var dropped: Array = []
	fight.orb_dropped.connect(func(_index: int, orb: String) -> void: dropped.append(orb))
	fight.start()
	_play(fight, 4000)
	_check(fight.finished and fight.victory, "the fight was won")
	_check(dropped.size() == Encounter.ENEMIES,
			"all %d bodies carried an orb, not %d" % [Encounter.ENEMIES, dropped.size()])
	var tallied := 0
	for orb: String in fight.orbs:
		_check(OrbTable.ORBS.has(orb), "%s is an orb this build has" % orb)
		tallied += int(fight.orbs[orb])
	_check(tallied == dropped.size(), "the fight's pouch counts what it emitted")

	# Beside the gear, not against it: one body can hand over both, which is what makes the two rates
	# independent numbers rather than one number split in two.
	var both := Encounter.for_tile(Vector2i(4, 0), "grass")
	both.always_drop = true
	both.always_orb = true
	# Gathered into Arrays rather than counted into ints: a lambda captures by value, so a counter
	# incremented inside one never moves outside it.
	var gear: Array = []
	var currency: Array = []
	both.loot_dropped.connect(func(_index: int, item: Item) -> void: gear.append(item))
	both.orb_dropped.connect(func(_index: int, orb: String) -> void: currency.append(orb))
	both.start()
	_play(both, 4000)
	_check(gear.size() == Encounter.ENEMIES and currency.size() == Encounter.ENEMIES,
			"every body left gear (%d) and an orb (%d)" % [gear.size(), currency.size()])

	# Left alone, the rate is the table's: a fight of nine commons and an elite turns up rather less
	# than a fight of ten guaranteed ones, and never nothing over many attempts.
	var quiet := Encounter.for_tile(Vector2i(4, 0), "grass")
	quiet.orb_rng.seed = 31337
	var seen: Array = []
	quiet.orb_dropped.connect(func(_index: int, orb: String) -> void: seen.append(orb))
	quiet.start()
	_play(quiet, 4000)
	_check(seen.size() < Encounter.ENEMIES, "an ordinary fight does not empty the table")
	return true


## Drop rate is the broad finder: gear, uniques, orbs and the purse alike. Where a narrow stat covers
## the same ground the two are **added**, the way two global percents are, so which of them carries
## the number cannot change the answer.
func _test_drop_rate_finds_everything() -> bool:
	var cell := Vector2i(12, 0)
	# One body's purse, with nothing on and with the finders arranged three ways.
	var purses := {}
	for worn: Array in [["none", {}], ["drop", {"drop_rate": 50.0}], ["gold", {"gold_find": 50.0}],
			["both", {"gold_find": 20.0, "drop_rate": 30.0}]]:
		var fight := Encounter.for_tile(cell, "grass")
		var stats: Dictionary = worn[1]
		stats["damage"] = 1.0e9
		fight.arm(stats)
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		purses[worn[0]] = fight.gold
	# Within the half gold the purse is rounded to, which is all a whole-number purse can promise.
	_check(absf(purses["drop"] - purses["none"] * 1.5) <= 0.5,
			"50%% drop rate is half again a purse (%s)" % [purses])
	_check(purses["gold"] == purses["drop"], "and gold find of the same size is the same purse")
	_check(purses["both"] == purses["drop"],
			"20 and 30 add to the same half again, rather than compounding to 56%% (%s)" % [purses])
	_check(purses["none"] == Encounter.gold_of(Encounter.for_tile(cell, "grass").lineup[0], cell),
			"and with neither finder a purse is exactly what the body is worth (%s)" % purses["none"])

	# The orb roll the same way, and equality rather than statistics: the same seeded run with 60% of
	# orb find, of drop rate, or of the two split turns up the very same orbs, because the roll is
	# handed one number. What the rate itself is, is checked against the table underneath.
	var runs := {}
	var bodies: Array = []
	for worn: Array in [["none", {}], ["orb", {"orb_find": 60.0}], ["drop", {"drop_rate": 60.0}],
			["split", {"orb_find": 20.0, "drop_rate": 40.0}]]:
		var run := Encounter.farm(cell, "grass")
		run.roster_rng.seed = WORLD_SEED
		run.orb_rng.seed = WORLD_SEED
		var stats: Dictionary = worn[1]
		stats["damage"] = 1.0e9
		run.arm(stats)
		var orbs: Array = []
		run.orb_dropped.connect(func(_i: int, orb: String) -> void: orbs.append(orb))
		if worn[0] == "split":
			bodies = []
			run.enemy_died.connect(func(i: int) -> void: bodies.append(run.lineup[i]))
		run.start()
		_play(run, 400)
		runs[worn[0]] = orbs
	_check(runs["drop"] == runs["orb"] and runs["split"] == runs["orb"],
			"drop rate reaches the orb roll, added to orb find (%d found, %d, %d)"
			% [runs["orb"].size(), runs["drop"].size(), runs["split"].size()])
	_check(runs["none"].size() < runs["orb"].size(),
			"and with neither, fewer fall (%d against %d)" % [runs["none"].size(), runs["orb"].size()])

	# The rate those bodies were actually rolled at: OrbTable's own answer for the summed figure,
	# summed over the bodies that fell. Seeded, so this is a measurement and not a coin toss.
	var wanted := 0.0
	var bare := 0.0
	for body: String in bodies:
		wanted += OrbTable.chance_for(body, 60.0)
		bare += OrbTable.chance_for(body)
	_check(absf(runs["split"].size() - wanted) < wanted * 0.4,
			"%d orbs off %d bodies, where the summed rate wants %.1f" % [runs["split"].size(),
					bodies.size(), wanted])
	_check(wanted > bare * 1.5, "which is well past what the bare rate would have paid (%.1f)" % bare)
	return true


## The starter uniques that the fight reads: Beginner's Luck sets the crit chance outright, and the
## Worry Stone is a second save beside Second Wind.
func _test_starter_rules() -> bool:
	var lucky := Encounter.for_tile(Vector2i(1, 0), "grass")
	lucky.effects = ["beginners_luck", "overcrit"]
	lucky.arm({"crit_chance": 150.0, "crit_damage": 50.0})
	_check(lucky.crit_chance == Encounter.BEGINNERS_LUCK and lucky.crit_damage == 50.0,
			"Beginner's Luck sets the chance, and leaves the Chalice nothing to overflow (%.0f, %.0f)"
			% [lucky.crit_chance, lucky.crit_damage])
	var low := Encounter.for_tile(Vector2i(1, 0), "grass")
	low.effects = ["beginners_luck"]
	low.arm({})
	_check(low.crit_chance == Encounter.BEGINNERS_LUCK, "and lifts a player with none to it")

	# Second Wind and the Worry Stone are a save each, and the two add up.
	for worn: Array in [["worry_stone"], ["second_wind", "worry_stone"]]:
		var saved := Encounter.for_tile(Vector2i(1, 0), "grass")
		saved.health[0] = 1.0e9
		saved.effects = worn
		saved.start()
		saved.advance(Encounter.SECONDS + 0.01)
		for i in worn.size() - 1:
			saved.advance(Encounter.SECOND_WIND_SECONDS + 0.01)
		_check(not saved.finished and is_equal_approx(saved.time_left, Encounter.SECOND_WIND_SECONDS),
				"%s give back the clock %d times" % [worn, worn.size()])
		saved.advance(Encounter.SECOND_WIND_SECONDS + 0.01)
		_check(saved.finished, "and then it runs out (%s)" % [worn])
	return true


## What a fight counts for the achievements (`Encounter.tally`): clicks, crits and the blows between
## them, one-blow kills, kills by a crit or a bleed, and blows taken or blocked whole.
func _test_fight_tally() -> bool:
	var sweep := Encounter.farm(Vector2i(3, 0), "grass")
	sweep.arm({"damage": 1.0e9, "crit_chance": 100.0})
	sweep.start()
	var clicks := _play(sweep, 20)
	sweep.advance(Encounter.DEATH)
	var kills := sweep.kills()
	_check(kills > 0 and sweep.tally.get("crit_kills") == kills and sweep.tally.get("domino_streak") == kills
			and sweep.tally.get("crits") == clicks, "every blow crit and killed at once (%d kills, %d blows: %s)"
			% [kills, clicks, sweep.tally])
	var counted: int = sweep.tally.get("clicks")
	_check(counted >= clicks, "every click is counted, the ones that land nothing too (%d of %d)" % [counted, clicks])
	sweep.advance(Encounter.KNUCKLE_WINDOW + 0.1)
	sweep.hit()
	_check(sweep.tally.get("clicks") == counted + 1, "and a pause loses none of them")

	var dry := Encounter.for_tile(Vector2i(1, 0), "grass")
	dry.health[0] = 1.0e9
	dry.hp = 1.0e9
	dry.arm({"damage": 1.0})
	dry.start()
	dry.advance(Encounter.WALK_IN)
	for i in 12:
		dry.hit()
	_check(not dry.tally.has("dry_streak"), "a blow that could not crit is no blow without one (%s)" % [dry.tally])
	dry.crit_chance = 1.0e-9
	for i in 12:
		dry.hit()
	_check(dry.tally.get("dry_streak") == 12 and not dry.tally.has("crits"), "twelve blows with no crit (%s)" % [dry.tally])

	var bled := Encounter.for_tile(Vector2i(1, 0), "grass")
	bled.health[0] = 50.0
	bled.hp = 50.0
	bled.arm({"damage": 1.0, "bleed": 1000.0})
	bled.start()
	bled.advance(Encounter.WALK_IN)
	bled.hit()
	for i in 20:
		bled.advance(0.5)
	_check(bled.tally.get("bleed_kills") == 1 and bled.tally.get("domino_streak", 0) == 0,
			"a body the bleed finished is a bleed kill and not a one-blow one (%s)" % [bled.tally])

	var guard := _struck_standing(EnemyRoster.Tier.COMMON, {"block": 1.0e6})
	guard._struck_by(1.0)
	var open := _struck_standing(EnemyRoster.Tier.COMMON)
	open._struck_by(1.0)
	_check(guard.tally.get("blows_taken") == 1 and guard.tally.get("blocked") == 1
			and open.tally.get("blows_taken") == 1 and not open.tally.has("blocked"),
			"a blow taken is counted, and one blocked whole twice over")
	return true


## The dev's even loot: about one body in three leaves one find, and each rarity from common to unique
## is about a fifth of them. Seeded, so this is a measurement and not a coin toss.
func _test_even_loot() -> bool:
	var run := Encounter.farm(Vector2i(12, 0), "grass")
	run.roster_rng.seed = WORLD_SEED
	run.loot_rng.seed = WORLD_SEED
	run.unique_rng.seed = WORLD_SEED
	run.unlocked = Achievements.STARTERS
	run.even_loot = true
	run.arm({"damage": 1.0e9})
	var found: Array = []
	var bodies: Array = []
	run.loot_dropped.connect(func(_i: int, item: Item) -> void: found.append(item.rarity))
	run.enemy_died.connect(func(i: int) -> void: bodies.append(i))
	run.start()
	_play(run, 1500)
	var share := float(found.size()) / maxf(bodies.size(), 1.0)
	_check(absf(share - Encounter.EVEN_LOOT_CHANCE) < 0.06,
			"one body in three leaves a find (%d off %d)" % [found.size(), bodies.size()])
	for rarity in ItemRarity.Rarity.values():
		var part := found.count(rarity) / maxf(found.size(), 1.0)
		_check(absf(part - 0.2) < 0.07, "%s is a fifth of them (%.2f)" % [ItemRarity.NAMES[rarity], part])
	return true


## What the land past the second wall does to its own fight (`TileMods`): which tiles carry anything,
## each dial moving what it says it moves, what it pays, and which of them a farm run keeps.
func _test_tile_mods() -> bool:
	var here := Vector2i(4, 6)
	# Where they are: nowhere short of the second wall, then one more every ring of land; Wild Tiles a
	# wall sooner and one more. The same seed and cell always the same ones, and another seed others.
	var counts := {}
	var differs := false
	for x in 40:
		var cell := Vector2i(x, 3)
		for ring in 6:
			var mods := TileMods.for_cell(1, cell, ring)
			_check(mods == TileMods.for_cell(1, cell, ring), "a tile's modifiers are its seed's and its cell's")
			differs = differs or mods != TileMods.for_cell(2, cell, ring)
			var seen: Dictionary = counts.get(ring, {})
			seen[mods.size()] = true
			counts[ring] = seen
			var wild := TileMods.for_cell(1, cell, ring, true)
			_check(wild.is_empty() == (ring == 0), "Wild Tiles starts a wall sooner (ring %d: %s)" % [ring, wild])
			if ring >= TileMods.FROM_WALLS:
				_check(wild.size() == mods.size() + 2, "a ring's worth sooner and one more (%s)" % [wild])
			for id: String in mods:
				for other: String in TileMods.MODS[id].get("not_with", []):
					_check(not other in mods, "%s never stands with %s" % [id, other])
	_check(differs, "another world's tiles carry other modifiers")
	_check(counts[0].keys() == [0] and counts[1].keys() == [0], "none short of the second wall %s" % counts)
	for ring in range(TileMods.FROM_WALLS, 6):
		var want := ring - TileMods.FROM_WALLS + 1
		_check(counts[ring].keys() == [want], "%d in ring %d, one more each ring %s" % [want, ring, counts[ring].keys()])
	for id: String in TileMods.MODS:
		for other: String in TileMods.MODS[id].get("not_with", []):
			_check(TileMods.MODS.has(other), "%s names a modifier there is (%s)" % [id, other])

	# The shape of the fight.
	var plain := Encounter.for_tile(here, "grass", "plain")
	var horde := Encounter.for_tile(here, "grass", "plain", false, ["horde"])
	_check(horde.enemies == 15 and horde.lineup.size() == 15 and horde.seconds == plain.seconds,
			"a Horde is fifteen on the same clock (%d)" % horde.enemies)
	_check(Encounter.tier_in(horde, 14) == EnemyRoster.Tier.ELITE and Encounter.tier_in(horde, 9) == EnemyRoster.Tier.COMMON,
			"five more of the rabble, and still ending on its elite")
	var sparse := Encounter.for_tile(here, "grass", "plain", false, ["sparse"])
	_check(sparse.lineup.size() == 6 and Encounter.tier_in(sparse, 5) == EnemyRoster.Tier.ELITE,
			"a Sparse tile is six, the last of them the elite (%d)" % sparse.lineup.size())
	var short := Encounter.for_tile(here, "grass", "plain", false, ["short_day"])
	_check(is_equal_approx(short.seconds, plain.seconds - 8.0) and short.time_left == short.seconds,
			"a Short Day is 8 s off the clock (%s)" % short.seconds)
	var elites := Encounter.for_tile(here, "grass", "plain", false, ["elite_ground"])
	_check(Encounter.tier_in(elites, 4) == EnemyRoster.Tier.ELITE
			and Encounter.tier_in(elites, 9) == EnemyRoster.Tier.ELITE, "Elite Ground fields one every fifth")
	# A modifier drawn twice is its second tier: tougher and paying more, and written so.
	var hordes := Encounter.for_tile(here, "grass", "plain", false, ["horde", "horde"])
	_check(hordes.enemies == 20 and Encounter.tier_in(hordes, 19) == EnemyRoster.Tier.ELITE
			and Encounter.tier_in(hordes, 14) == EnemyRoster.Tier.COMMON, "Horde II is twenty, still ending on its elite")
	var more_elites := Encounter.for_tile(here, "grass", "plain", false, ["elite_ground", "elite_ground"])
	_check(more_elites.elite_every == 3, "Elite Ground II fields one every third (%d)" % more_elites.elite_every)
	_check(TileMods.describe("savage", 2) == PackedStringArray(["Brutal II", "Enemies hit 100% harder.", "+40% drop rate"]),
			"Brutal II reads its own numbers (%s)" % [TileMods.describe("savage", 2)])
	_check(TileMods.describe("piercing", 2)[1] == "Only 25% of your armour counts.", "a factor tier compounds")
	_check(TileMods.describe("sparse", 1)[1] == "4 fewer enemies on the same clock." and TileMods.describe("sparse", 1)[2] == "",
			"Sparse reads as the boon it is")
	var repeats := false
	for x in 40:
		var deep := TileMods.for_cell(1, Vector2i(x, 3), 12)
		_check(deep.size() == 11, "every draw is kept (%d)" % deep.size())
		for id: String in deep:
			repeats = repeats or deep.count(id) > 1
			if TileMods.MODS[id].get("once", false):
				_check(deep.count(id) == 1, "%s never climbs a tier" % id)
	_check(repeats, "deep land draws the same modifier again")
	var thick := Encounter.for_tile(here, "grass", "plain", false, ["thick_skinned"])
	_check(thick.lineup == plain.lineup, "a modifier that leaves the count alone leaves the lineup alone")
	_check(is_equal_approx(thick.health[0], roundf(plain.health[0] * 1.5)),
			"Thick-skinned is half again the health (%s against %s)" % [thick.health[0], plain.health[0]])
	var mire := Encounter.for_tile(here, "grass", "plain", false, ["mire"])
	_check(is_equal_approx(mire.walk_in, Encounter.WALK_IN * 2.0) and mire.phase_left == mire.walk_in,
			"a Mire doubles the walk-in")
	mire.start()
	mire.advance(Encounter.WALK_IN)
	_check(mire.phase == Encounter.Phase.WALKING_IN, "so the first enemy is still on its way in")

	# What they do to the player's numbers, and what they pay.
	var stats := {"armor": 100.0, "dodge": 100.0, "block": 20.0, "time_on_hit": 10.0, "attack_speed": 2.0,
			"drop_rate": 10.0, "item_rarity": 10.0, "gold_find": 10.0}
	var bare := Encounter.for_tile(here, "grass", "plain")
	bare.arm(stats)
	var pays := {"piercing": ["armor", "gold_find"], "keen_eyed": ["dodge", "gold_find"],
			"sundering": ["block", "gold_find"], "timeless": ["time_on_hit", "xp_more"],
			"stillness": ["attack_speed", "drop_rate"]}
	for id: String in pays:
		var fight := Encounter.for_tile(here, "grass", "plain", false, [id])
		fight.arm(stats)
		var cut: String = pays[id][0]
		var paid: String = pays[id][1]
		_check(float(fight.get(cut)) < float(bare.get(cut)), "%s cuts %s" % [id, cut])
		_check(float(fight.get(paid)) > float(bare.get(paid)), "%s pays in %s" % [id, paid])
	for id: String in TileMods.MODS:
		var fight := Encounter.for_tile(here, "grass", "plain", false, [id])
		fight.arm(stats)
		var paid := fight.drop_rate + fight.item_rarity + fight.gold_find + fight.xp_more \
				- bare.drop_rate - bare.item_rarity - bare.gold_find - bare.xp_more
		_check((paid > 0.0) == (not TileMods.describe(id, 1)[2].is_empty()),
				"%s pays exactly when its row says so (%s)" % [id, paid])
	var wild_pay := Encounter.for_tile(here, "grass", "plain", false, ["savage"])
	wild_pay.wear([Curses.effect(Curses.WILD_TILES)])
	wild_pay.arm(stats)
	_check(is_equal_approx(wild_pay.drop_rate, 10.0 + 20.0 * TileMods.WILD_REWARD), "Wild Tiles pays a tenth more")

	# The blows: a Savage tile's are half again, a Frenzied one's come round sooner.
	var blows := {}
	for id: String in ["", "savage", "frenzied"]:
		var fight := Encounter.for_tile(here, "grass", "plain", false, [] if id.is_empty() else [id])
		fight.strikes = true
		fight.crit_rng.seed = 1
		var lost: Array[float] = []
		fight.player_hit.connect(func(taken: float, _d: bool, _b: bool) -> void: lost.append(taken))
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.advance(3.2)
		blows[id] = lost
	_check(blows[""].size() == 3 and blows["frenzied"].size() > 3, "a Frenzied tile strikes oftener %s" % [blows])
	_check(is_equal_approx(blows["savage"][0], blows[""][0] * 1.5), "and a Savage one half again as hard")

	# What a body leaves: nothing in a Barren purse, no gear off a Gilded one.
	for id: String in ["barren", "gilded"]:
		var fight := Encounter.for_tile(here, "grass", "plain", false, [id])
		fight.always_drop = true
		var found: Array[Item] = []
		fight.loot_dropped.connect(func(_i: int, item: Item) -> void: found.append(item))
		fight.damage = 1e12
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		_check((fight.gold == 0.0) == (id == "barren"), "%s: the purse is %s" % [id, fight.gold])
		_check(found.is_empty() == (id == "gilded"), "%s: %d find(s)" % [id, found.size()])

	# A farm run has no clock and is never struck, so it carries only what changes the bodies.
	var every: Array = TileMods.MODS.keys()
	var run := Encounter.farm(here, "grass", "plain", every)
	_check(run.mods == TileMods.farmable(every) and not run.mods.is_empty(), "a run keeps the farmable ones %s" % [run.mods])
	for id: String in run.mods:
		_check(bool(TileMods.MODS[id]["farm"]), "%s is one a run can carry" % id)
	_check(not "short_day" in run.mods and not "savage" in run.mods, "and none that needs a clock")
	# Set pieces carry none: the chest is built before the modifiers are looked at.
	var chest := Encounter.for_tile(here, "grass", "plain", true, ["horde", "thick_skinned"])
	_check(chest.lineup.size() == 1 and chest.mods.is_empty(), "a chest is the mimic alone, whatever the land says")
	return true


## The world's curses as the fight hears them (`"curse:<id>"` in `effects`): each one's handicap, and
## the pay that is the fight's to give. The numbers a curse pays are `Inventory.stats`' (test_inventory).
func _test_curses() -> bool:
	var here := Vector2i(4, 6)
	var plain := Encounter.for_tile(here, "grass", "plain")
	for id: String in Curses.CURSES:
		var curse: Dictionary = Curses.CURSES[id]
		_check(int(curse["skulls"]) in [1, 2, 3] and not str(curse["text"]).is_empty()
				and not str(curse["reward"]).is_empty(), "%s says what it costs and pays" % id)
		for stat: String in curse.get("stats", {}):
			_check(stat == "xp_more" or LootTable.STAT_LABELS.has(stat), "%s pays in a stat there is (%s)" % [id, stat])
	var iron := Encounter.for_tile(here, "grass", "plain", false, ["thick_skinned"])
	iron.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(iron.health[3], roundf(Encounter.hp_of(iron.lineup[3], here) * (1.0 + 0.5 + Encounter.IRON_HP)))
			and iron.hp == iron.health[0], "Iron Foes adds to a tile's own, never compounds (%s)" % iron.health[3])
	iron.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(iron.health[3], roundf(Encounter.hp_of(iron.lineup[3], here) * (1.0 + 0.5 + Encounter.IRON_HP))),
			"and is taken on once however often the fight is dressed")
	var run := Encounter.farm(here, "grass", "plain")
	run.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(run.health[0], roundf(Encounter.hp_of(run.lineup[0], here) * (1.0 + Encounter.IRON_HP))),
			"a farm run's bodies are iron too")
	var days := Encounter.for_tile(here, "grass", "plain")
	days.wear([Curses.effect(Curses.SHORT_DAYS)])
	_check(is_equal_approx(days.seconds, plain.seconds - Encounter.SHORT_DAYS) and days.time_left == days.seconds,
			"Short Days is %s s off every clock" % Encounter.SHORT_DAYS)
	var wall := Encounter.for_wall(Vector2i(11, 0))
	var winter := Encounter.for_wall(Vector2i(11, 0))
	winter.wear([Curses.effect(Curses.LONG_WINTER), Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(winter.health[0], wall.health[0] * Encounter.LONG_WINTER_HP) and winter.hp == winter.health[0],
			"the Long Winter doubles the wall, and Iron Foes leaves it alone (%s)" % winter.health[0])
	var mimic := Encounter.for_tile(here, "grass", "plain", true)
	var hungry := Encounter.for_tile(here, "grass", "plain", true)
	hungry.wear([Curses.effect(Curses.HUNGRY_MIMICS)])
	_check(is_equal_approx(hungry.health[0], roundf(mimic.health[0] * (1.0 + Encounter.HUNGRY_HP))),
			"a Hungry Mimic has three times the health")
	var paid := 0
	for attempt in 20:
		var chest := Encounter.for_tile(here, "grass", "plain", true)
		chest.wear([Curses.effect(Curses.HUNGRY_MIMICS)])
		chest.loot_rng.seed = attempt
		chest.unique_rng.seed = attempt
		var found: Array[Item] = []
		chest.loot_dropped.connect(func(_i: int, item: Item) -> void: found.append(item))
		chest.damage = 1e12
		chest.start()
		chest.advance(Encounter.WALK_IN)
		chest.hit()
		if found.size() > 1:
			paid += 1
			_check(found.size() == Encounter.HUNGRY_ROLLS, "and pays %d pieces (%d)" % [Encounter.HUNGRY_ROLLS, found.size()])
	_check(paid > 0, "some of twenty chests held gear")

	# Bloodthirst, added to a Savage tile's share of the blow.
	var blows := {}
	for worn: Array in [[], [Curses.effect(Curses.BLOODTHIRST)]]:
		var fight := Encounter.for_tile(here, "grass", "plain", false, ["savage"])
		fight.wear(worn)
		fight.strikes = true
		fight.crit_rng.seed = 1
		var lost: Array[float] = []
		fight.player_hit.connect(func(taken: float, _d: bool, _b: bool) -> void: lost.append(taken))
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.advance(1.05)
		blows[worn.size()] = lost[0]
	_check(is_equal_approx(blows[1] / blows[0], (1.5 + Encounter.BLOODTHIRST_HIT) / 1.5),
			"Bloodthirst adds its share to the tile's (%s against %s)" % [blows[1], blows[0]])

	# Pauper halves the purse; Lean Pickings halves the finished chance of gear and ascends some of it.
	var purses := {}
	for worn: Array in [[], [Curses.effect(Curses.PAUPER)]]:
		var fight := Encounter.for_tile(here, "grass", "plain")
		fight.wear(worn)
		fight.damage = 1e12
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		purses[worn.size()] = fight.gold
	_check(is_equal_approx(purses[1], maxf(1.0, roundf(purses[0] * Encounter.PAUPER_PURSE))),
			"a Pauper's purse is half (%s against %s)" % [purses[1], purses[0]])
	_check(is_equal_approx(Encounter._lifted(20.0, 0.5), -40.0) and is_equal_approx(Encounter._lifted(0.0, 2.0), 100.0),
			"a finished chance is halved and doubled through the lift")
	var some := plain.lineup[0]
	_check(is_equal_approx(LootTable.chance_for(some, Encounter._lifted(20.0, 0.5)), LootTable.chance_for(some, 20.0) * 0.5),
			"and half of it is half the drops")
	_check(LootTable.chance_for(some, -500.0) == 0.0, "down to nothing and no further")
	var lean := Encounter.farm(here, "grass", "plain")
	lean.wear([Curses.effect(Curses.LEAN_PICKINGS)])
	lean.always_drop = true
	lean.loot_rng.seed = 7
	var plus := {0: 0, 1: 0, 2: 0}
	lean.loot_dropped.connect(func(_i: int, item: Item) -> void: plus[item.plus] = int(plus.get(item.plus, 0)) + 1)
	lean.damage = 1e12
	lean.start()
	for body in 1500:
		lean.advance(Encounter.WALK_IN)
		lean.hit()
		lean.advance(Encounter.DEATH)
	var all := float(plus[0] + plus[1] + plus[2])
	_check(absf(plus[1] / all - Encounter.LEAN_PLUS[0]) < 0.03 and plus[2] > 0 and plus[2] / all < 0.03,
			"about one find in ten is +1 and one in a hundred +2 %s" % plus)
	_check(plus.size() == 3, "and none is more than +2")
	var kept := Encounter.farm(here, "grass", "plain")
	kept.always_drop = true
	kept.loot_rng.seed = 7
	var ascended := [0]
	kept.loot_dropped.connect(func(_i: int, item: Item) -> void: ascended[0] += item.plus)
	kept.damage = 1e12
	kept.start()
	for body in 200:
		kept.advance(Encounter.WALK_IN)
		kept.hit()
		kept.advance(Encounter.DEATH)
	_check(ascended[0] == 0, "without the curse nothing falls ascended")

	# Hard Lessons: a quarter of the experience, taken off after every "more" has been added.
	var lessons := {}
	for worn: Array in [[], [Curses.effect(Curses.HARD_LESSONS)]]:
		var fight := Encounter.for_tile(Vector2i(30, 0), "grass", "plain")
		fight.wear(worn)
		fight.arm({"xp_more": 100.0})
		fight.damage = 1e12
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		lessons[worn.size()] = fight.xp
	_check(lessons[0] >= 8 and lessons[1] == roundi(lessons[0] * Encounter.LESSONS_XP),
			"Hard Lessons leaves a quarter of the experience (%s against %s)" % [lessons[1], lessons[0]])
	return true


## The dungeon from the main scene: no way down until a wall has fallen in some world, then the world's
## cave, entered stood on; the hero feels it at the map's edge until it is seen; a descent pays nothing
## and counts no kill, and a depth is written down only once its Gollux is dead.
func _test_the_way_down() -> void:
	_clear_saves()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	var view: MapBuilder = main.view
	_check(view.cave == HexMap.NO_CELL, "no cave while no wall has fallen in any world")
	# A wall once broken in some world: this one's cave goes down behind its first wall, and is saved.
	main.inventory.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	main._credit_walls()
	var cave: Vector2i = view.cave
	_check(cave != HexMap.NO_CELL and MapSave.load_from(SCRATCH_MAP).cave == cave,
			"the furthest land ever reached puts the world's cave down, and the map is saved with it (%s)" % cave)

	# The cave felt from the hero: nothing while the wall in front of it stands, then a red light at the
	# map's edge, and the hero says so.
	_check(not main._cave_sense.shown() and not main._tip_due("first_sense"),
			"a cave behind a wall still standing is not felt")
	view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	_check(main._cave_sense.shown(), "with the wall in front of it broken, the hero feels the cave at the map's edge")
	_check(main._tip_due("first_sense"), "and says so")
	# From the hero out: the light stands where the line toward the cave leaves the map.
	var area := Rect2(0, 0, 100, 60)
	_check(CaveSense.leaving(Vector2(50, 30), Vector2(1, 0), area) == Vector2(100, 30), "a cave east lights the right edge")
	_check(CaveSense.leaving(Vector2(50, 30), Vector2(-1, -1), area) == Vector2(20, 0),
			"one up and to the left the top edge, where the line from the hero meets it")
	_check(CaveSense.leaving(Vector2(-40, 30), Vector2(0, 1), area) == Vector2(0, 60),
			"and a hero panned off the map feels it from the edge nearest them")

	# The wall down and the land charted, stood on the cave: Enter cave, and nowhere else.
	view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	view._cover()
	view.reveal_all()
	main.map.select_cell(MapBuilder.CENTER)
	main._update_buttons()
	_check(not main._cave_button.visible, "no way down from anywhere but the cave")
	view.player_cell = cave
	main.map.select_cell(cave)
	main._on_tile_clicked(cave, main.map.get_tile_info(cave))
	_check(main._cave_button.visible and "depth 1" in main._cave_button.tooltip_text
			and main._level_label.text.begins_with("Cave"),
			"stood on the cave, Enter cave goes down to depth 1 (%s)" % main._cave_button.tooltip_text)
	_check(not main._cave_sense.shown() and not main._tip_due("first_sense"), "and seen, the light goes out")
	main._on_cave_pressed()
	var fight: Encounter = main._combat.fight if main._combat != null else null
	_check(fight != null and fight.dungeon and main._combat.place == main.DUNGEON_NAME and not main.map.visible,
			"it opens the dungeon over the map")
	if fight == null:
		return
	var kills_before: int = main.inventory.kills
	var gold_before: float = main.inventory.gold
	# Bare hands at eight clicks a second: some floors, and no Gollux.
	_play(fight, 100000)
	_check(fight.finished and fight.index > 0 and fight.cleared() == 0,
			"bare hands get %d floors down and no further" % fight.index)
	main._combat._on_back_pressed()
	await process_frame
	_check(main._combat == null and main.map.visible, "leaving brings the map back")
	_check(main.inventory.dungeon_depth == 0, "floors short of Gollux win no depth")
	_check(main.inventory.dungeon_floors == fight.index,
			"but the floors beaten are the leaderboard's score (%d)" % main.inventory.dungeon_floors)
	_check(not main.cloud.enabled(), "and a test's main scene never calls the cloud")
	_check(main.inventory.kills == kills_before and is_equal_approx(main.inventory.gold, gold_before),
			"with no kill counted and nothing paid")
	# A Gollux killed is a depth won, written down, and where the next descent begins.
	main._on_cave_pressed()
	fight = main._combat.fight
	fight.damage = 1e9
	while fight.cleared() < 2:
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		fight.advance(Encounter.DEATH)
	fight.stop()
	main._combat._on_back_pressed()
	await process_frame
	_check(main.inventory.dungeon_depth == 2 and Inventory.load_from(SCRATCH_INVENTORY).dungeon_depth == 2,
			"two Golluxes dead is two depths won, and saved")
	_check(main.inventory.dungeon_floors == 30 and Cloud.depth_and_floor(30) == Vector2i(3, 0)
			and Cloud.depth_and_floor(44) == Vector2i(3, 14) and Cloud.depth_and_floor(5) == Vector2i(1, 5),
			"a score is the depth and the floors of it beaten (%d)" % main.inventory.dungeon_floors)
	_check("depth 3" in main._cave_button.tooltip_text, "Enter cave says where that leaves the player (%s)"
			% main._cave_button.tooltip_text)
	main._on_cave_pressed()
	_check(main._combat.fight.depth() == 3 and main._combat.fight.first_floor == 30,
			"and the next descent begins under them")
	main._combat.fight.stop()
	main._combat._on_back_pressed()
	await process_frame
	_check(main.inventory.dungeon_depth == 2 and main.inventory.dungeon_floors == 30,
			"a descent that wins nothing moves nothing")
	_check(main.inventory.transcended().dungeon_depth == 2, "and a transcension carries the depths over")
	main.queue_free()
	await process_frame
	_clear_saves()


func _test_a_world_under_the_fog() -> void:
	_clear_saves()
	var cursed := Inventory.new()
	cursed.curses = [Curses.THICK_FOG, Curses.NO_REST]
	cursed.first_sword_taken = true
	cursed.save(SCRATCH_INVENTORY)
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = SCRATCH_INVENTORY
	main.map_path = SCRATCH_MAP
	root.add_child(main)
	for i in 3:
		await process_frame
	_check(main._sight() == 0, "under the fog, with nothing held, there is no sight at all")
	_check("No Rest" in main._cannot_camp(), "and No Rest is why no camp can be made (%s)" % main._cannot_camp())

	var rim := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	var blind := HexGrid.neighbor(rim, HexGrid.Edge.E)
	main.map.select_cell(rim)
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_play(main._combat.fight, 10000)
	main._combat._on_back_pressed()
	await process_frame
	_check(main.view.charted(rim) and not main.view.seen(blind), "a won tile comes out of the fog alone")

	# The first tile into the fog: nothing drawn, and still a tile to click, read and fight for.
	main.map.select_cell(blind)
	await process_frame
	_check(main._panel.visible and main._tile_title.text == "Unknown land"
			and main._level_label.text == "Level %d" % main.view.level_of(blind),
			"a tile under the fog reads as unknown land, and its level is the walk's (%s)" % main._tile_title.text)
	_check(main._env_rows.get_child_count() == 0 and main._service_rows.get_child_count() == 0
			and main._mod_rows.get_child_count() == 0, "with nothing said of what is on it")
	_check(main.view.to_save().names.get(blind, "") == "", "and looking at it has not named it")
	_check(main._chart_button.visible, "Chart is offered on it")
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main._combat != null and main._combat.fight.env == main.view.env_at(blind) and main._combat.fight.env != "",
			"and the fight is on the land that is really there (%s)" % main._combat.fight.env)
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	main.map.player.finish_walk()

	# The torch: a ring of sight back, read as the tile is charted.
	var torch := Item.rolled(LootTable.BROKEN_TORCH, ItemRarity.Rarity.COMMON, RandomNumberGenerator.new())
	main.inventory.items.append(torch)
	_check(main.inventory.equip(torch, Equipment.Socket.OFFHAND) and main._sight() == 1, "the Broken Torch in hand is a ring of sight")
	main.map.select_cell(blind)
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_play(main._combat.fight, 10000)
	main._combat._on_back_pressed()
	await process_frame
	_check(main.view.charted(blind) and main.view.seen(HexGrid.neighbor(blind, HexGrid.Edge.E)),
			"and the tile taken with it shows the ring behind it")
	main.queue_free()
	await process_frame
	_clear_saves()


## The second batch of curses as the fight hears them: three uniques' rules made a world's (each
## adding to its unique where both are had), Raw Finds, the Homeland, and the Restless camp.
func _test_more_curses() -> bool:
	var here := Vector2i(4, 6)
	var one := func(worn: Array, stats: Dictionary) -> Encounter:
		var fight := Encounter.for_tile(here, "grass", "plain")
		fight.wear(worn)
		fight.arm(stats)
		fight.start()
		fight.advance(Encounter.WALK_IN)
		return fight

	# Pacifist Hands: a click lands nothing, as under the Metronome; the weapon's own swing still does.
	var pacifist: Encounter = one.call([Curses.effect(Curses.PACIFIST_HANDS)], {"damage": 3.0, "attack_speed": 2.0})
	var before := pacifist.hp
	_check(not pacifist.hit() and pacifist.hp == before, "under Pacifist Hands a click deals no damage")
	pacifist.advance(0.6)
	_check(pacifist.hp < before or pacifist.index > 0, "and the weapon goes on swinging for itself")

	# Berserker's World: no swing of its own, clicks doubled, and the Band's share added to it.
	var bare: Encounter = one.call([], {"damage": 3.0, "attack_speed": 2.0})
	var berserk: Encounter = one.call([Curses.effect(Curses.BERSERKERS_WORLD)], {"damage": 3.0, "attack_speed": 2.0})
	_check(bare.swings() and not berserk.swings(), "in a Berserker's World the weapon never swings")
	var full := berserk.hp
	berserk.advance(0.9)
	_check(berserk.hp == full, "a second of standing there costs the enemy nothing")
	_check(is_equal_approx(berserk.unique_more(false), Encounter.BERSERK_WORLD_MORE)
			and is_equal_approx(berserk.unique_more(true), 0.0), "its clicks are worth double, its swings no more")
	var banded: Encounter = one.call([Curses.effect(Curses.BERSERKERS_WORLD), "berserk"], {"damage": 3.0})
	_check(is_equal_approx(banded.unique_more(false),
			Encounter.BERSERK_WORLD_MORE + UniqueTable.dial("berserkers_band", "times") - 1.0),
			"and a Berserker's Band adds its share to the same sum")
	# The average blow the character page heads itself with: 3 and the bare hand's 1, crits half the
	# time adding as much again -- and a click in the Berserker's World worth double that.
	var even: Encounter = one.call([], {"damage": 3.0, "crit_chance": 50.0, "crit_damage": 100.0})
	_check(is_equal_approx(even.average_blow(true), 6.0) and is_equal_approx(even.average_blow(false), 6.0),
			"a blow is its damage with its crits averaged in (%s)" % even.average_blow(true))
	var doubled: Encounter = one.call([Curses.effect(Curses.BERSERKERS_WORLD)],
			{"damage": 3.0, "crit_chance": 50.0, "crit_damage": 100.0})
	_check(is_equal_approx(doubled.average_blow(false), 12.0) and is_equal_approx(doubled.average_blow(true), 6.0),
			"and what the curses and uniques add to a click or a swing goes in on top")
	var still: Encounter = one.call(["metronome"], {"damage": 3.0})
	_check(still.average_blow(false) == 0.0, "a hand that does nothing averages nothing")

	# Glass World: the clock a third faster and +100%, and with the Glass Edge both twice over.
	for case: Array in [[[Curses.effect(Curses.GLASS_WORLD)], 1], [[Curses.effect(Curses.GLASS_WORLD), "glass_edge"], 2]]:
		var glass: Encounter = one.call(case[0], {"damage": 3.0})
		var left := glass.time_left
		glass.advance(0.3)
		_check(is_equal_approx(left - glass.time_left, 0.3 * pow(Encounter.GLASS_CLOCK, case[1])),
				"the glass spends the clock %d time(s) over" % case[1])
		_check(is_equal_approx(glass.unique_more(false), Encounter.GLASS_MORE * case[1]), "and pays for each")
	var run := Encounter.farm(here, "grass", "plain")
	run.wear([Curses.effect(Curses.GLASS_WORLD)])
	_check(is_equal_approx(run.unique_more(false), 0.0), "a run has no clock to spend, and is paid nothing")

	# Raw Finds: gear falls common and bare, a unique as it always did, and orbs three times as often.
	var raw := Encounter.farm(here, "grass", "plain")
	raw.wear([Curses.effect(Curses.RAW_FINDS)])
	raw.always_drop = true
	raw.loot_rng.seed = 3
	var finds: Array[Item] = []
	raw.loot_dropped.connect(func(_i: int, item: Item) -> void: finds.append(item))
	raw.damage = 1e12
	raw.start()
	for body in 60:
		raw.advance(Encounter.WALK_IN)
		raw.hit()
		raw.advance(Encounter.DEATH)
	_check(finds.size() >= 60 and finds.all(func(item: Item) -> bool:
		return item.rarity == ItemRarity.Rarity.COMMON and item.mods.is_empty()), "every raw find is a bare common")
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var unique := Item.rolled_unique(UniqueTable.ids()[0], rng, 5)
	_check(raw._raw(unique).rarity == ItemRarity.Rarity.UNIQUE and not unique.mods.is_empty(), "a unique is left as it fell")
	var some := raw.lineup[0]
	_check(is_equal_approx(OrbTable.chance_for(some, Encounter._lifted(10.0, Encounter.RAW_ORBS)),
			minf(OrbTable.chance_for(some, 10.0) * Encounter.RAW_ORBS, 1.0)), "three times the finished chance of an orb")

	# The Homeland: gear on its two lands and none on the rest, but a chest and the wall still pay.
	var home := [Curses.effect(Curses.HOMELAND), Curses.HOME_PREFIX + "grass", Curses.HOME_PREFIX + "forest"]
	for env: String in ["grass", "desert"]:
		var fight := Encounter.for_tile(here, env, "plain")
		fight.wear(home)
		fight.arm({"item_rarity": 10.0})
		fight.always_drop = true
		var left: Array[Item] = []
		fight.loot_dropped.connect(func(_i: int, item: Item) -> void: left.append(item))
		fight.damage = 1e12
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		_check(left.is_empty() == (env == "desert"), "%s leaves %d piece(s)" % [env, left.size()])
		_check(is_equal_approx(fight.item_rarity, 10.0 + (Encounter.HOME_RARITY if env == "grass" else 0.0)),
				"and %s rarity is %s" % [env, fight.item_rarity])
	var chest := Encounter.for_tile(here, "desert", "plain", true)
	chest.wear(home)
	chest.loot_rng.seed = 1
	var paid: Array[Item] = []
	chest.loot_dropped.connect(func(_i: int, item: Item) -> void: paid.append(item))
	chest.damage = 1e12
	chest.start()
	chest.advance(Encounter.WALK_IN)
	chest.hit()
	_check(not paid.is_empty(), "a chest abroad still pays")

	# Restless: a camp made under it pays twice a second and is full in two hours.
	var rested := {}
	for worn: Array in [[], [Curses.effect(Curses.RESTLESS)]]:
		var camped := Encounter.farm(here, "grass", "plain")
		camped.wear(worn)
		camped.arm({"damage": 50.0, "attack_speed": 2.0})
		# A run's first body is rolled before anybody can seed it, so both camps are handed the same one.
		camped.lineup[0] = bare.lineup[0]
		camped.health[0] = Encounter.hp_of(bare.lineup[0], here)
		camped.hp = camped.health[0]
		camped.crit_rng.seed = 1
		camped.roster_rng.seed = 1
		camped.loot_rng.seed = 1
		rested[worn.size()] = Camp.make(here, "Here", camped, 1000.0)
	_check(is_equal_approx(float(rested[1][Camp.GOLD]), float(rested[0][Camp.GOLD]) * Camp.RESTLESS_PAY)
			and is_equal_approx(float(rested[1][Camp.XP]), float(rested[0][Camp.XP]) * Camp.RESTLESS_PAY),
			"a Restless camp pays double a second")
	var long := Camp.earned(rested[1], 1000.0 + Camp.MAX_SECONDS)
	_check(bool(long["full"]) and is_equal_approx(float(long["seconds"]), Camp.RESTLESS_SECONDS), "and is full after two hours")
	var old_camp: Dictionary = rested[0].duplicate()
	old_camp.erase(Camp.MOST)
	_check(is_equal_approx(float(Camp.earned(old_camp, 1000.0 + Camp.MAX_SECONDS * 2.0)["seconds"]), Camp.MAX_SECONDS),
			"a camp saved before the curse fills when camps always did")

	# Two that cannot stand together, and every row still says what it costs and pays.
	_check(not Curses.allowed(Curses.PACIFIST_HANDS, [Curses.BERSERKERS_WORLD])
			and not Curses.allowed(Curses.BERSERKERS_WORLD, [Curses.PACIFIST_HANDS])
			and Curses.allowed(Curses.GLASS_WORLD, [Curses.PACIFIST_HANDS]), "no damage at all is not a world on offer")
	for id: String in Curses.CURSES:
		for other: String in Curses.CURSES[id].get("not_with", []):
			_check(Curses.CURSES.has(other), "%s names a curse there is (%s)" % [id, other])
	return true
