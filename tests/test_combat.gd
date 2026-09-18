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
	_check(_test_health() == true, "health tests ran to the end")
	_check(_test_a_won_fight() == true, "won fight tests ran to the end")
	_check(_test_the_ice_wall() == true, "ice wall tests ran to the end")
	_check(_test_a_lost_fight() == true, "lost fight tests ran to the end")
	_check(_test_hits_only_land_on_a_waiting_enemy() == true, "hit timing tests ran to the end")
	_check(_test_what_a_hit_is_worth() == true, "damage tests ran to the end")
	_check(_test_the_weapon_swings_itself() == true, "attack speed tests ran to the end")
	_check(_test_bleed() == true, "bleed tests ran to the end")
	_check(_test_capstone_effects() == true, "capstone effect tests ran to the end")
	_check(_test_unique_drops() == true, "unique drop tests ran to the end")
	_check(_test_unique_effects() == true, "unique effect tests ran to the end")
	_check(_test_more_unique_effects() == true, "second batch unique effect tests ran to the end")
	_check(_test_home_clauses() == true, "home clause tests ran to the end")
	_check(_test_uniques_keep_the_edge() == true, "unique ceiling tests ran to the end")
	_check(_test_backdrops() == true, "backdrop tests ran to the end")
	_check(_test_backdrop_layouts() == true, "backdrop layout tests ran to the end")
	_check(_test_a_farm_run_never_ends() == true, "farm run tests ran to the end")
	_check(_test_a_settlement_is_a_set_piece() == true, "settlement fight tests ran to the end")
	_check(_test_a_chest_is_a_mimic() == true, "chest fight tests ran to the end")
	_check(_test_gold() == true, "gold tests ran to the end")
	_check(_test_experience() == true, "experience tests ran to the end")
	_check(_test_coins() == true, "coin tests ran to the end")
	_check(_test_orb_drops() == true, "orb drop tests ran to the end")
	_check(_test_drop_rate_finds_everything() == true, "drop rate tests ran to the end")
	await _test_thrown_finds()
	await _test_settings()
	await _test_the_nameplate_wears_the_tier()
	await _test_the_map_hands_over_and_takes_back()
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

	# Restless dead: a body that gets back up gets up whole.
	var grave := _standing(["restless:dirt"], {"damage": 19.0, "bleed": 50.0}, 30.0, "dirt")
	grave.hit()
	_check(grave._bleed == 10.0, "the wound is open when it falls")
	grave.hit()
	# Forced rather than rolled for: the rising is one body in ten, and this is about the wound.
	grave._rise = true
	grave.advance(Encounter.DEATH)
	_check(grave._has_risen and grave._bleed == 0.0, "a body that gets back up gets up whole")
	grave.advance(Encounter.WALK_IN)
	var risen := grave.hp
	grave.advance(1.0)
	_check(grave.hp == risen, "and loses nothing standing there (%s of %s)" % [grave.hp, risen])

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


## Every place the world can send the player to has a backdrop, and anything else falls back rather
## than leaving a fight with nothing behind it.
func _test_backdrops() -> bool:
	for env in _environments():
		var fight := Encounter.for_tile(Vector2i(1, 2), env)
		_check(fight.env == env, "the fight on %s knows its terrain" % env)
		for variant in ["plain", "road", "village", "town", "fortress"]:
			for layout in range(1, CombatScene.AREA_LAYOUTS + 1):
				var path: String = CombatScene.AREA_PATH % [env, variant, layout]
				_check(ResourceLoader.exists(path),
						"%s has a %s backdrop (%d)" % [env, variant, layout])
				# One at a time, and never cached: a backdrop is 2304x1296, and holding all of them
				# at once would be over a gigabyte of texture for a size check.
				var art: Texture2D = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
				# The fighters are placed as a share of the picture, so every backdrop is the same
				# shape: one that was not would stand them off the ground.
				_check(art != null and art.get_size() == Vector2(2304, 1296),
						"%s/%s/%d is the standard size" % [env, variant, layout])
			_check(CombatScene.backdrop_for(env, variant) != null, "%s/%s loads" % [env, variant])

	var fallback := CombatScene.backdrop_for("swamp", "plain")
	_check(fallback == load(CombatScene.AREA_FALLBACK), "terrain with no art falls back")
	# A layout number that was never drawn is clamped rather than left as a missing file: the number
	# comes out of a hash, and a fight with no picture behind it would be unplayable.
	_check(CombatScene.backdrop_for("grass", "village", 99) != null, "a layout past the end clamps")
	_check(CombatScene.backdrop_for("grass", "village", 0) != null, "and so does one before it")
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

	# A tile is worth about a quarter of a level: charting outward ring by ring, every level up to
	# 30 takes three to six tiles.
	var level := 1
	var held := 0
	var tiles_this_level := 0
	var ring := 1
	while level <= 30:
		var cell := MapBuilder.CENTER + Vector2i(ring, 0)
		for tile in 6 * ring:
			var tile_fight := Encounter.for_tile(cell, "grass")
			for body in tile_fight.lineup:
				held += Encounter.xp_of(body, cell)
			tiles_this_level += 1
			while held >= PlayerLevel.xp_to_next(level):
				held -= PlayerLevel.xp_to_next(level)
				_check(tiles_this_level >= 3 and tiles_this_level <= 6,
						"level %d took %d tiles" % [level, tiles_this_level])
				level += 1
				tiles_this_level = 0
		ring += 1

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
	_check(combat._pips._pips[elite].texture == KillPips.BODY[EnemyRoster.Tier.ELITE],
			"the pip standing for the elite is green, like the frame over its head")

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
	_check(town._pips._pips.size() == siege.enemies,
			"a village's bar stands %d pips, not %d" % [siege.enemies, town._pips._pips.size()])
	_check(town._pips._pips[siege.enemies - 1].texture == KillPips.BODY[EnemyRoster.Tier.BOSS],
			"and the pip at its far end is the boss's gold")
	_check(town._pips._tail.texture == KillPips.TAIL[EnemyRoster.Tier.BOSS],
			"which the bar closes in, the way it closes in whatever is at its end")
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
	var before := combat.get_child_count()
	combat._on_loot_dropped(0, _thrown_piece(ItemRarity.Rarity.COMMON))
	_check(combat._finds_shown == 1, "a kept find is thrown")
	_check(combat.get_child_count() == before + 1, "and it is a node in the arena")
	var plain := combat.get_child(combat.get_child_count() - 1)
	_check(plain is Sprite2D, "drawn as a sprite, like a coin")
	_check(plain.get_child_count() == 0, "with no beam over a common piece")

	# A rare one carries the wash of its own colour behind it.
	var rare := _thrown_piece(ItemRarity.Rarity.RARE)
	combat._on_loot_dropped(1, rare)
	_check(combat._finds_shown == 2, "and so is the next")
	var lit := combat.get_child(combat.get_child_count() - 1)
	_check(lit.get_child_count() == 1, "a rare piece is thrown with a beam over it")
	if lit.get_child_count() == 1:
		var beam := lit.get_child(0) as AnimatedSprite2D
		_check(beam != null, "the pack's own flame, playing")
		if beam != null:
			# The white colourway tinted, which is the whole reason one sheet serves the ramp: white
			# times a colour is that colour, and any other colourway would come back muddied.
			var want: Color = ItemRarity.BORDER_COLORS[rare.rarity]
			_check(is_equal_approx(beam.modulate.r, want.r) and is_equal_approx(beam.modulate.g, want.g)
					and is_equal_approx(beam.modulate.b, want.b), "in the rarity's own colour")
			_check(beam.is_playing() and beam.animation == "burn", "and it burns")
			_check(is_equal_approx(beam.rotation, LootBeam.RISE), "stood up out of the pack's comet")
			_check(beam.z_index < 0 and beam.position.y < 0.0, "behind the piece and over it")

	# The sheet's geometry, measured rather than guessed, the way the coin's is.
	var burn := LootBeam.frames()
	_check(burn.has_animation("burn"), "the beam has a burn")
	_check(burn.get_frame_count("burn") == LootBeam.FRAMES,
			"of %d frames, not %d" % [LootBeam.FRAMES, burn.get_frame_count("burn")])
	_check(burn.get_animation_loop("burn"), "and it loops")
	_check(LootBeam.SHEET.get_width() == LootBeam.FRAMES * LootBeam.SIZE
			and LootBeam.SHEET.get_height() == LootBeam.SIZE,
			"one row of %d square frames: %dx%d" % [LootBeam.FRAMES,
					LootBeam.SHEET.get_width(), LootBeam.SHEET.get_height()])
	_check(LootBeam.frames() == LootBeam.frames(), "and it is built once")

	# An orb is thrown the same way and plain: it has no rarity to borrow.
	combat._on_orb_dropped(2, OrbTable.ORBS.keys()[0])
	_check(combat._finds_shown == 3, "an orb is thrown too")
	_check(combat.get_child(combat.get_child_count() - 1).get_child_count() == 0,
			"and never carries a beam")

	# The toasts are gone, so nothing may still be reaching for them.
	_check(not ("_toasts" in combat), "there is no toast left to raise")
	combat.queue_free()
	await process_frame


## A piece to throw. The type is any real one -- what is being checked is the throw, not the roll.
## The settings: they come back off their file, a fight with animations off throws nothing and still
## fills the bar, and a detailed modifier line carries the band it rolled in. Every static is put back,
## since the suites after this one in the file read them.
func _test_settings() -> void:
	Settings.path = "user://test_settings.cfg"
	Settings.sfx = false
	Settings.animations = Settings.Anim.LOW
	Settings.item_details = true
	Settings.save()
	Settings.sfx = true
	Settings.animations = Settings.Anim.DEFAULT
	Settings.item_details = false
	Settings.load_settings()
	_check(not Settings.sfx and Settings.animations == Settings.Anim.LOW and Settings.item_details,
			"settings come back off their file")
	Settings.apply_audio()
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.SFX_BUS)), "a muted SFX bus is muted")
	_check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(Settings.MUSIC_BUS)), "and music is not")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Settings.path))
	Settings.path = ""

	var piece := _thrown_piece(ItemRarity.Rarity.COMMON)
	piece.mods = [{"id": "increased_damage", "value": 14}]
	var band := ModifierTable.band_for("increased_damage", piece.level)
	_check(piece.mod_lines(true)[0] == "+14(%d-%d)%% increased Damage" % band,
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
	_check(combat.get_child_count() == before and combat._finds_shown == 0, "and nothing is thrown")
	_check(combat._drops.size() == 1, "though the find is still kept")
	Settings.animations = Settings.Anim.LOW
	combat._on_gold_dropped(0, 1000.0)
	_check(combat.get_child_count() == before + 1, "on low a purse is one coin")
	combat.queue_free()
	await process_frame
	Settings.sfx = true
	Settings.animations = Settings.Anim.DEFAULT
	Settings.item_details = false
	Settings.apply_audio()


func _thrown_piece(rarity: ItemRarity.Rarity) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = 1
	item.stats = Item.scaled_stats(item.type, 1)
	return item


## Health grows with the walk from the middle of the map, and with the enemy's own size and tier.
func _test_health() -> bool:
	var near := Vector2i(1, 0)
	var far := Vector2i(20, 0)
	_check(HexGrid.distance(MapBuilder.CENTER, near) == 1, "the near cell is the first ring")
	_check(Encounter.base_hp(MapBuilder.CENTER) == Encounter.BASE_HP, "an ordinary body in the middle")
	_check(Encounter.base_hp(far) > Encounter.base_hp(near), "and a tougher one at the edge")

	# Health is exponential in the walk, not a flat sum: every step multiplies by HP_GROWTH, so the
	# frontier pulls away from whatever the player is carrying. Checked step by step out to the edge,
	# with the slack that rounding to whole points of health allows.
	for steps in range(1, 21):
		var here := Vector2i(steps, 0)
		var back := Vector2i(steps - 1, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		_check(Encounter.base_hp(here) > Encounter.base_hp(back),
				"step %d is tougher than step %d" % [steps, steps - 1])
		var want := Encounter.BASE_HP * pow(Encounter.HP_GROWTH, steps)
		_check(absf(Encounter.base_hp(here) - want) <= 0.5,
				"step %d is %d, not the curve's %.1f" % [steps, Encounter.base_hp(here), want])

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

	# How much of the clock is actually spent fighting: the rest goes on enemies walking in and
	# dying. At SECONDS that overhead is a third of the fight, which is what makes the frontier the
	# problem it is below.
	var spare := Encounter.SECONDS - Encounter.ENEMIES * (Encounter.WALK_IN + Encounter.DEATH)
	# The first ring stays beatable with nothing on at all: it is where a new player starts, and it
	# must never need gear they have not been given a chance to find.
	var bare := _click_rate(Encounter.for_tile(Vector2i(1, 0), "grass"), spare,
			Encounter.BARE_DAMAGE, 0.0)
	_check(bare < 8.0, "the first ring is beatable with nothing on (%.1f/s)" % bare)

	# The far edge is meant to be hard but possible, and since the clock came down to SECONDS it is
	# no longer possible in the plain gear a tile hands over. That is the design, not a regression:
	# the frontier is past what unmodified pieces carry, and reaching it means farming for better
	# rolls. Farming cannot raise the level a tile drops at -- that ceiling is the tile's own -- so
	# what a long run actually buys is modifiers, which is what `_farmed` builds. Both halves are
	# pinned here, because either one alone would let the map drift out of reach or into a walkover.
	var edge := Vector2i(20, 0)
	var level := MapBuilder.level_of(edge)
	var plain := _rate_for(edge, _commons(level), spare)
	_check(plain >= 8.0, "the far edge is past a plain set of commons (%.1f/s)" % plain)

	# The other half of what "plain" means now that a slot has materials: the same set in the best one
	# the edge's own level unlocks, the second of four. The design's line is the one above -- a
	# plain set is past what a person can click -- and the best material comes in just under it, at
	# 7.7/s against the wooden set's 9.2. It is pinned here rather than smoothed over: LootTable's
	# TIER_POWER would have to come down from 0.20 to 0.10 for a top-material sword set to want eight
	# clicks again, and that is a dial in another file and a decision of its own.
	var best := _rate_for(edge, _best_commons(level), spare)
	_check(best < plain, "the best material at the edge is worth finding (%.1f/s against %.1f)"
			% [best, plain])
	_check(best > 7.0, "and the far edge is still past a plain set whatever it is made of (%.1f/s)"
			% best)
	# What each kind of weapon wants in that same plain set, reported rather than pinned: the mace's
	# bleed counted as the free damage it is, and the greatsword without the offhand it costs.
	for kind: String in ["sword", "dagger", "mace", "greatsword"]:
		var held := Encounter.for_tile(edge, "grass")
		held.arm(_best_commons(level, kind).totals())
		var blow := held.damage * (1.0 + held.crit_chance / 100.0 * held.crit_damage / 100.0)
		print("Edge fight in top-material commons, %s: %.1f a blow, %.1f swings/s, %d%% bleed, %.1f clicks/s"
				% [kind, blow, held.attack_speed, held.bleed,
					_click_rate(held, spare, blow, held.attack_speed + held.bleed / 100.0)])

	var far := Encounter.for_tile(edge, "grass")
	far.arm(_typical_farmed(edge, ItemRarity.Rarity.RARE).totals())
	var per_hit := far.damage * (1.0 + far.crit_chance / 100.0 * far.crit_damage / 100.0)
	var rate := _click_rate(far, spare, per_hit, far.attack_speed)
	print("Edge fight in a farmed set of rares: %d health, %.2f a hit, %.1f swings/s free, %.1f clicks/s"
			% [_total_health(far), per_hit, far.attack_speed, rate])
	_check(rate < 8.0, "the far edge is beatable in farmed gear at a human click rate (%.1f/s)" % rate)
	# And gear has to be worth wearing: the same fight must want fewer clicks than bare hands.
	_check(rate < _click_rate(far, spare, Encounter.BARE_DAMAGE, 0.0), "gear beats bare hands there")
	_check(rate > 1.0, "and is not a walkover in farmed gear either (%.1f/s)" % rate)

	# Skills on top of that set. A player at the edge's own level has a point a level past the first to
	# spend, and all of it in Power is the most skills can do there: it has to help, and it must not
	# make the edge a fight nobody clicks in. A whole tree is 23 points -- a player at level 24 is
	# nowhere near a level-6 tile's gear, so the whole tree is only held to helping.
	var budget := Skills.earned(level)
	var early := _power_rate(edge, spare, budget)
	var whole := _power_rate(edge, spare, SkillTree.capacity("power"))
	print("Edge fight with Power skills too: %.2f clicks/s on %d points, %.2f on the whole tree"
			% [early, budget, whole])
	_check(early < rate, "a level's worth of Power makes the edge easier (%.2f/s)" % early)
	_check(early > 0.5, "and still wants clicking (%.2f/s)" % early)
	_check(whole <= early, "the whole tree helps at least as much (%.2f/s)" % whole)
	return true


## The click rate at `edge` in a farmed set of rares with `points` spent down the Power tree's damage
## path first -- the root, the middle, the flat damage chain -- and then the rest.
func _power_rate(edge: Vector2i, spare: float, points: int) -> float:
	const ORDER := ["sharpened_edge", "keen_eye", "battle_rhythm", "might", "titan", "quick_hands",
		"flurry", "whirlwind", "deadly_strikes", "assassin"]
	var skills := Skills.new()
	var guard := 0
	while skills.spent() < points and guard < 100:
		guard += 1
		for id: String in ORDER:
			if skills.rank_up(id, points + 1):
				break
	var fight := Encounter.for_tile(edge, "grass")
	fight.arm(_typical_farmed(edge, ItemRarity.Rarity.RARE).totals(skills.flat(), skills.percent()))
	var per_hit := fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0)
	return _click_rate(fight, spare, per_hit, fight.attack_speed)


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
	_check(main._combat != null, "pressing Chart starts a fight")
	_check(not main.map.visible and main.map.process_mode == Node.PROCESS_MODE_DISABLED,
			"the map stops while the fight is on")
	main._combat.fight.give_up()
	_check(main._combat._lost_row.visible and not main._combat._collect.visible,
			"a lost fight offers the arrow and Retry, and nothing to collect")
	# Retry is a loss left and the same tile's fight opened again, in one press.
	var first: CombatScene = main._combat
	first.retry.emit()
	_check(main._combat != null and main._combat != first and main._combat.cell == target,
			"Retry opens the same tile's fight afresh")
	_check(not main.view.charted(target) and not main.map.visible, "with nothing charted by the loss")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	_check(main._combat == null, "the fight is torn down")
	_check(main.map.visible and main.map.process_mode == Node.PROCESS_MODE_INHERIT, "and the map is back")
	_check(not main.view.charted(target), "a lost tile stays uncharted")
	_check(main.view.can_chart(target), "and can be fought for again straight away")

	# Winning charts it, exactly as pressing Chart used to.
	main._on_chart_pressed()
	var fight: Encounter = main._combat.fight
	_play(fight, 10000)
	_check(fight.victory, "the rematch is won")
	_check(main._combat._collect.visible and not main._combat._lost_row.visible,
			"and a won tile leaves by Collect")
	main._combat._on_back_pressed()
	await process_frame
	_check(main.view.charted(target), "a won tile is charted")
	_check(main.map.visible, "and the map is back")

	# Escape: Terminate on a run, Back under its verdict, then the tile panel's X.
	main.map.player.finish_walk()
	main._on_farm_pressed()
	main.map.player.finish_walk()
	_check(main._combat != null and main._combat.fight.endless, "a run starts on the won tile")
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(main._combat != null and main._combat.fight.finished, "Escape ends a farm run")
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
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

	# A tile away from the player: they walk to the charted tile beside it first, and the fight opens there.
	main.map.player.finish_walk()
	var far_side := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.W)
	main.map.select_cell(far_side)
	_check(main._chart_button.visible and not main._chart_button.disabled and not main._move_button.visible and not main._farm_button.visible, "only the buttons that can be pressed show")
	main._on_chart_pressed()
	_check(main._combat == null and main.view.walking, "charting a tile out of reach walks there first")
	_check(not main._chart_button.visible, "and hides the buttons on the way")
	main.map.player.finish_walk()
	_check(main.view.player_cell == MapBuilder.CENTER and main._combat != null, "the fight opens on arrival")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame
	main.queue_free()


## Clicks the fight to its end at a steady rate, stepping the clock between clicks. Returns the clicks
## it took. `limit` stops a broken encounter from looping forever.
## Every point of health in a fight, the whole ten.
func _total_health(fight: Encounter) -> float:
	var total := 0.0
	for hp: float in fight.health:
		total += hp
	return total


## How many clicks a second this fight needs, given what a hit is worth and what the weapon swings
## for free. The automatic swings come off the top: they are damage the player does not have to ask
## for, which is exactly what attack speed buys.
func _click_rate(fight: Encounter, seconds: float, per_hit: float, swings: float) -> float:
	var left := maxf(0.0, _total_health(fight) - seconds * swings * per_hit)
	return left / per_hit / seconds


## The ice wall round the first land: one body on the ice, a wall nobody walks through bare-handed,
## and one a player who has farmed the land inside it for rares can bring down. `WALL_HP` is the dial.
func _test_the_ice_wall() -> bool:
	var cell := Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0)
	var fight := Encounter.for_wall(cell)
	_check(fight.lineup == PackedStringArray([Encounter.WALL_NAME]) and fight.env == "ice" and fight.enemies == 1,
			"the wall stands alone, on the ice")
	_check(EnemyRoster.tier_of(Encounter.WALL_NAME) == EnemyRoster.Tier.BOSS, "and is a boss")
	for env in ["grass", "dirt", "desert", "forest", "ice", "mountains"]:
		_check(not (Encounter.WALL_NAME in EnemyRoster.in_environment(env)), "the wall lives nowhere, not on %s" % env)
	var spare := fight.seconds - (Encounter.WALK_IN + Encounter.DEATH)
	var bare := _click_rate(fight, spare, Encounter.BARE_DAMAGE, 0.0)
	var level_gear := _typical_farmed(Vector2i(MapBuilder.START_LAND_RADIUS, 0), ItemRarity.Rarity.RARE)
	var armed := Encounter.for_wall(cell)
	armed.arm(level_gear.totals())
	var per_hit := armed.damage * (1.0 + armed.crit_chance / 100.0 * armed.crit_damage / 100.0)
	var farmed := _click_rate(armed, spare, per_hit, armed.attack_speed)
	print("The ice wall: %s health, %.1f clicks/s bare, %.1f in farmed rares"
			% [BigNumber.format(fight.hp), bare, farmed])
	_check(bare > 50.0, "nobody walks through the wall bare-handed (%.1f/s)" % bare)
	_check(farmed > 3.0 and farmed < 8.0, "farmed rares from inside it bring it down, harder than any tile (%.1f/s)" % farmed)
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


## A plain set at `level`: one common piece in every socket, the modest gear a player would have by
## the time they reached that far out. Nothing rolled, so the reference set cannot drift with the
## dice -- but the pieces are scaled, because a player at the frontier is carrying frontier gear and
## measuring level-1 gear against a frontier fight measures a fight nobody will ever have.
## What a set of gear has to be clicked at to beat the fight on `cell` inside `seconds`. Asked of an
## armed Encounter rather than worked out beside one, so it uses exactly the numbers the fight will.
func _rate_for(cell: Vector2i, gear: Equipment, seconds: float, variant := "") -> float:
	var fight := Encounter.for_tile(cell, "grass", variant)
	fight.arm(gear.totals())
	var per_hit := fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0)
	return _click_rate(fight, seconds, per_hit, fight.attack_speed)


## How many farmed sets the frontier is measured against. An odd handful, so there is a middle one.
const FARMED_SETS := 7

## The set the frontier is actually held to: FARMED_SETS of them rolled at `cell`'s level, and the
## middling one handed back -- the one whose fight wants the median number of clicks a second.
##
## A single seeded set was the reference until a modifier joined the jewellery's pool: the same seed
## then drew a different stream and the set happened to roll +14 flat damage on both jewels, which
## took the far edge from wanting clicks to a walkover (0.56/s) without a single number in the game
## changing. Measured over fifty seeds the edge wants 0.85 to 7.24 clicks a second, median 2.8, and
## that old seed sat below every one of them. A median cannot be moved that way by one lucky draw:
## the pool would have to move the whole distribution, which is exactly when the frontier has really
## changed and the check should have something to say.
func _typical_farmed(cell: Vector2i, rarity: ItemRarity.Rarity, variant := "") -> Equipment:
	var level := MapBuilder.level_of(cell)
	var fight := Encounter.for_tile(cell, "grass", variant)
	var spare := fight.seconds - fight.enemies * (Encounter.WALK_IN + Encounter.DEATH)
	var ranked := []
	for take in FARMED_SETS:
		var gear := _farmed(level, rarity, take)
		ranked.append([_rate_for(cell, gear, spare, variant), gear])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	return ranked[FARMED_SETS / 2][1]


## One set the player has farmed for: the same pieces at the same level, carrying the modifiers a
## rarity buys. Seeded on `take` as well as the level, so a handful of them can be rolled and the
## middle one taken -- see `_typical_farmed`, which is what the frontier is measured against.
func _farmed(level: int, rarity: ItemRarity.Rarity, take := 0) -> Equipment:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["farmed", level, rarity, take])
	var gear := Equipment.new()
	for socket: Equipment.Socket in Equipment.sockets():
		for type in LootTable.items():
			if LootTable.slot_of(type) != Equipment.TAKES[socket]:
				continue
			var item := Item.new()
			item.type = type
			item.rarity = rarity
			item.level = level
			item.stats = Item.scaled_stats(type, level)
			var band: Array = ItemRarity.MOD_COUNT[rarity]
			item.mods = ModifierTable.roll(type, rng.randi_range(band[0], band[1]), rng, level)
			gear.equip(socket, item)
			break
	return gear


func _commons(level := 1) -> Equipment:
	var gear := Equipment.new()
	for socket: Equipment.Socket in Equipment.sockets():
		for type in LootTable.items():
			if LootTable.slot_of(type) != Equipment.TAKES[socket]:
				continue
			var item := Item.new()
			item.type = type
			item.level = level
			item.stats = Item.scaled_stats(type, level)
			gear.equip(socket, item)
			break
	return gear


## The same plain set in the best *material* `level` has unlocked, with `weapon`'s kind in hand. The
## rest of the sockets keep the kind `_commons` picks -- the first the table writes for the slot --
## so the only two things that differ from it are the materials and what is being swung. A two-handed
## weapon leaves the offhand empty, which is what it pays for its damage.
func _best_commons(level: int, weapon := "sword") -> Equipment:
	var gear := Equipment.new()
	var held := _material(weapon, level)
	for socket: Equipment.Socket in Equipment.sockets():
		var slot: String = Equipment.TAKES[socket]
		if slot == "offhand" and LootTable.two_handed(held):
			continue
		var type := held
		if slot != "weapon":
			for plain in LootTable.items():
				if LootTable.slot_of(plain) == slot:
					type = _material(str(LootTable.ITEMS[plain]["kind"]), level)
					break
		var item := Item.new()
		item.type = type
		item.level = level
		item.stats = Item.scaled_stats(type, level)
		gear.equip(socket, item)
	return gear


## The best material of `kind` at `level`: the last of its tiers the level has reached.
func _material(kind: String, level: int) -> String:
	var row: Dictionary = LootTable.KINDS[kind]
	var levels: Array = row.get("tier_levels", LootTable.TIER_MIN_LEVEL)
	var tiers: Array = row["tiers"]
	var best := 0
	for tier in tiers.size():
		if level >= int(levels[tier]):
			best = tier
	return str(tiers[best])


## A settlement is a set piece: fifteen enemies in a minute, an elite every fifth and a boss last.
## All three tiers fight it -- what makes a town a longer fight is that people live there -- and a
## farm run on one keeps that elite rhythm and never the boss.
## A chest tile fields the mimic alone, which no other lineup ever does, and it always pays out.
func _test_a_chest_is_a_mimic() -> bool:
	for env in _environments():
		for variant in ["plain", "village"]:
			var ordinary := Encounter.for_tile(Vector2i(4, 6), env, variant)
			_check(not Encounter.MIMIC in ordinary.lineup, "no mimic on an ordinary %s %s" % [env, variant])
	var drops := [0]
	for attempt in 20:
		var fight := Encounter.for_tile(Vector2i(4, 6), "grass", "plain", true)
		_check(fight.lineup == PackedStringArray([Encounter.MIMIC]), "a chest fields the mimic alone")
		_check(fight.tier_for(0) == EnemyRoster.Tier.BOSS, "and it is a boss")
		fight.loot_rng.seed = attempt
		var before: int = drops[0]
		fight.loot_dropped.connect(func(_i: int, _item: Item) -> void: drops[0] += 1)
		fight.damage = 1 << 20
		fight.start()
		fight.advance(Encounter.WALK_IN)
		fight.hit()
		_check(drops[0] > before, "the mimic always drops something")
		fight.advance(Encounter.DEATH)
		_check(fight.finished and fight.victory, "beating it takes the tile")
	_check(drops[0] > 20 * 2, "and usually several things (%d over 20)" % drops[0])
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

	# What the set piece actually costs, measured the way the ordinary fight is: the clock less what
	# goes on walking in and dying, against the health the whole lineup carries. A settlement is a
	# step up by design -- a boss is worth twelve commons on its own -- so this is reported at three
	# distances rather than pinned, and only the one claim that has to hold everywhere is checked:
	# the first ring is where a new player starts, and it must never need gear they have not had a
	# chance to find.
	for steps in [1, MapBuilder.START_TOWN_DISTANCE, 12]:
		var at := Vector2i(steps, 0)
		var siege := Encounter.for_tile(at, "grass", "village")
		var spare := siege.seconds - siege.enemies * (Encounter.WALK_IN + Encounter.DEATH)
		var level := MapBuilder.level_of(at)
		print("Village %d step(s) out (level %d): %d health, %.1f clicks/s bare, %.1f in commons, %.1f in farmed rares"
				% [steps, level, _total_health(siege),
					_click_rate(siege, spare, Encounter.BARE_DAMAGE, 0.0),
					_rate_for(at, _commons(level), spare, "village"),
					_rate_for(at, _typical_farmed(at, ItemRarity.Rarity.RARE, "village"), spare,
							"village")])
	var first := Encounter.for_tile(Vector2i(1, 0), "grass", "village")
	var room := first.seconds - first.enemies * (Encounter.WALK_IN + Encounter.DEATH)
	_check(_click_rate(first, room, Encounter.BARE_DAMAGE, 0.0) < 8.0,
			"a village in the first ring is beatable with nothing on (%.1f/s)"
			% _click_rate(first, room, Encounter.BARE_DAMAGE, 0.0))
	return true


## Every unique a fight hands over, gathered off `loot_dropped` as [index, id] pairs.
func _uniques_of(fight: Encounter) -> Array:
	var found := []
	fight.loot_dropped.connect(func(index: int, item: Item) -> void:
		if not item.unique.is_empty():
			found.append([index, item.unique]))
	return found


## Where uniques come from: nothing before the wait is over, the first boss whatever the wait says,
## and the rabble far less often than what leads it.
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
	var found := _uniques_of(run)
	run.start()
	_play(run, 60)
	_check(not found.is_empty() and int(found[0][0]) == 30,
			"the first unique falls on the kill the wait ends at (%s)" % [found.slice(0, 2)])
	for pair: Array in found:
		_check(str(pair[1]) in UniqueTable.pool_for("grass"), "%s is found on grass" % pair[1])

	# The promised one: a settlement's boss, with the wait nowhere near over.
	var town := Encounter.for_tile(cell, "grass", "village")
	town.arm({"damage": 1.0e9})
	town.uniques_after = 1000
	town.guarantee_unique = true
	var promised := _uniques_of(town)
	town.start()
	_play(town, 100)
	_check(town.victory and promised.size() == 1 and int(promised[0][0]) == town.enemies - 1,
			"the first boss hands over exactly one unique (%s)" % [promised])
	_check(not town.guarantee_unique, "and the promise is spent")

	var later := Encounter.for_tile(cell, "grass", "village")
	later.arm({"damage": 1.0e9})
	later.uniques_after = 1000
	later.unique_rng.seed = WORLD_SEED
	var unpromised := _uniques_of(later)
	later.start()
	_play(later, 100)
	_check(unpromised.is_empty(), "a boss promises nothing once one has been found")

	for enemy: String in EnemyRoster.ENEMIES:
		var chance := UniqueTable.chance_for(enemy)
		match EnemyRoster.tier_of(enemy):
			EnemyRoster.Tier.COMMON:
				_check(chance > 0.0 and chance < 0.002, "%s almost never carries one (%f)" % [enemy, chance])
			EnemyRoster.Tier.ELITE:
				_check(chance >= 0.005 and chance < 0.05, "%s sometimes carries one (%f)" % [enemy, chance])
			EnemyRoster.Tier.BOSS:
				_check(chance >= 0.05 and chance <= 0.25, "%s often carries one (%f)" % [enemy, chance])
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
func _test_uniques_keep_the_edge() -> bool:
	var edge := Vector2i(20, 0)
	var level := MapBuilder.level_of(edge)
	var gear := _typical_farmed(edge, ItemRarity.Rarity.RARE)
	# The most a clicker can stack: every piece whose rule is more damage on a click, on its home
	# ground, with a full bag for the Harness to count.
	var worn := {
		Equipment.Socket.WEAPON: "glass_edge", Equipment.Socket.BOOTS: "meadowstriders",
		Equipment.Socket.RING_LEFT: "berserkers_band", Equipment.Socket.RING_RIGHT: "knucklebone_ring",
		Equipment.Socket.AMULET: "gamblers_die", Equipment.Socket.BODY: "packmule",
	}
	var rng := RandomNumberGenerator.new()
	for socket: Equipment.Socket in worn:
		var piece := Item.rolled_unique(worn[socket], rng, level)
		for mod in piece.mods:
			mod["value"] = int(ModifierTable.band_for(str(mod["id"]), level)[1])
		gear.equip(socket, piece)
		# Asked of the socket rather than of what `equip` handed back: it returns everything it
		# displaced now, and an empty list means both "it did not fit" and "there was nothing there".
		_check(gear.item_at(socket) == piece, "%s takes a farmed piece's place" % worn[socket])
	var stats := gear.totals()
	stats["bag_pieces"] = Inventory.CAPACITY
	var fight := Encounter.for_tile(edge, "grass")
	fight.wear(gear.effects())
	fight.arm(stats)
	_check("berserk" in fight.effects and "home:grass" in fight.effects and "grazing:grass" in fight.effects,
			"the set's effects reach the fight (%s)" % [fight.effects])
	# What a click is worth with the set on, a full Knucklebone streak included, asked of the fight's own
	# sum so this cannot drift from it -- times the half again the Gambler's Die averages.
	fight._click_streak = Encounter.KNUCKLE_MOST
	var click := fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0) \
			* (1.0 + fight._unique_more(false)) * (Encounter.GAMBLE[0] + Encounter.GAMBLE[1]) / 2.0
	# The rate the same farmed set wants at the edge with no unique on it: what "a fight" means here.
	var ordinary := Encounter.for_tile(edge, "grass")
	var plain := _rate_for(edge, _typical_farmed(edge, ItemRarity.Rarity.RARE),
			ordinary.seconds - ordinary.enemies * (Encounter.WALK_IN + Encounter.DEATH))
	# The map has no edge, so the set cannot be held to one tile. What it can be held to is what it
	# buys: walk outward until the fight wants that many clicks again, and count the steps. The set
	# pays its own prices on the way: the Glass Edge's faster clock, Grazing's two more bodies, and a
	# weapon that never swings beside the Berserker's Band.
	var bought := 0
	var rate := 0.0
	while bought < 40:
		var there := Encounter.for_tile(edge + Vector2i(bought, 0), "grass")
		there.wear(fight.effects)
		var spare := there.seconds / Encounter.GLASS_CLOCK - there.enemies * (Encounter.WALK_IN + Encounter.DEATH)
		rate = _total_health(there) / click / spare
		if rate >= plain:
			break
		bought += 1
	print("The best unique clicker set buys %d hex steps of frontier (%.2f clicks/s there, %.2f plain)"
			% [bought, rate, plain])
	_check(bought > 0, "the set is worth wearing")
	_check(bought <= 14, "and buys a stretch of frontier, not the map (%d steps)" % bought)
	return true


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

	# Ascetic's Cord and the Packmule's Harness read a count the inventory hands over.
	var bare := _standing(["ascetic"], {"damage": 9.0, "bare_sockets": 4})
	bare.hit()
	_check(bare.hp == 1.0e9 - 16.0, "15%% a bare socket (%s)" % (1.0e9 - bare.hp))
	var mule := _standing(["packmule"], {"damage": 9.0, "bag_pieces": 40})
	mule.hit()
	_check(mule.hp == 1.0e9 - 14.0, "1%% a piece in the bag (%s)" % (1.0e9 - mule.hp))

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
	_check(chalice.crit_chance == Encounter.CRIT_CAP and chalice.crit_damage == 50.0 + 30.0 * Encounter.OVERCRIT,
			"crit chance past the cap becomes crit damage (%s)" % chalice.crit_damage)
	var plain := Encounter.for_tile(cell, "grass")
	plain.arm({"crit_chance": Encounter.CRIT_CAP + 30.0, "crit_damage": 50.0})
	_check(plain.crit_damage == 50.0, "and is simply lost without it")

	# Dominoes: a body felled by its first blow costs the next a fifth, before Cleave's change.
	var fall := _standing(["domino", "cleave"], {"damage": 104.0}, 100.0)
	fall.hit()
	fall.advance(Encounter.DEATH)
	_check(fall.hp == roundf(fall.health[1] * 0.8) - 5.0, "a fifth, then the overkill (%s of %s)" % [fall.hp, fall.health[1]])
	var slow := _standing(["domino"], {"damage": 59.0}, 100.0)
	slow.hit()
	slow.hit()
	slow.advance(Encounter.DEATH)
	_check(slow.hp == slow.health[1], "two blows topple nothing")

	# Snowball: 2% a kill, and no further than double.
	var snow := _standing(["momentum"], {"damage": 9.0})
	listen.call(snow)
	snow._rose = 10
	snow.hit()
	snow._rose = 500
	snow.hit()
	_check(blows == [12.0, 20.0], "momentum builds and stops at double (%s)" % [blows])
	blows.clear()

	# Bulwark: block is a second swing, and the second swing is never a third.
	var wall := _standing(["riposte"], {"damage": 0.0, "block_chance": 100.0})
	wall.crit_rng.seed = WORLD_SEED
	listen.call(wall)
	for i in 400:
		wall.hit()
	_check(wall.block_chance == Encounter.RIPOSTE_CAP, "block is read, and capped for this")
	_check(blows.size() > 640 and blows.size() <= 800, "three clicks in four swing again, once (%d)" % blows.size())
	blows.clear()

	# Heartwood Plate: a second a hundred health, ten at most, none on a run.
	for case: Array in [[450.0, 4.0], [50000.0, Encounter.HEARTWOOD_MOST]]:
		var oak := Encounter.for_tile(cell, "grass")
		oak.effects = ["heartwood"]
		oak.arm({"health": case[0]})
		_check(oak.seconds == Encounter.SECONDS + float(case[1]) and oak.time_left == oak.seconds,
				"%s health is %s seconds" % case)
	var oak_run := Encounter.farm(cell, "grass")
	oak_run.effects = ["heartwood"]
	oak_run.arm({"health": 450.0})
	_check(oak_run.seconds == Encounter.SECONDS, "and a run has no clock to add to")

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
	return true


## The home pieces' second rules: each makes a differently shaped fight, on its own ground.
func _test_home_clauses() -> bool:
	var cell := Vector2i(12, 0)
	# Grazing: two more on the front, the same clock, and the fight still ends on its elite.
	var herd := Encounter.for_tile(cell, "grass")
	herd.wear(["home:grass", "grazing:grass"])
	_check(herd.enemies == Encounter.ENEMIES + 2 and herd.lineup.size() == herd.enemies
			and herd.health.size() == herd.enemies, "two more enemies graze (%d)" % herd.enemies)
	_check(herd.seconds == Encounter.SECONDS and herd.hp == herd.health[0], "on the same clock")
	for i in herd.enemies:
		_check(herd.tier_for(i) == EnemyRoster.tier_of(herd.lineup[i]), "slot %d of a grazing fight agrees" % i)
	_check(herd.tier_for(herd.enemies - 1) == EnemyRoster.Tier.ELITE, "and it still ends on its elite")
	var again := Encounter.for_tile(cell, "grass")
	again.wear(["grazing:grass"])
	_check(again.lineup == herd.lineup, "the same tile grazes the same herd")
	var elsewhere := Encounter.for_tile(cell, "desert")
	elsewhere.wear(["grazing:grass"])
	_check(elsewhere.enemies == Encounter.ENEMIES, "only on grass")
	var chest := Encounter.for_tile(cell, "grass", "", true)
	chest.wear(["grazing:grass"])
	_check(chest.lineup.size() == 1, "and a mimic waits alone")

	# Flush out: the elite first on open land; a settlement keeps its order.
	var flushed := Encounter.for_tile(cell, "forest")
	var was := flushed.lineup.duplicate()
	flushed.wear(["flush_out:forest"])
	_check(flushed.lineup[0] == was[-1] and flushed.lineup[-1] == was[0] and flushed.hp == flushed.health[0],
			"the elite comes first")
	for i in flushed.enemies:
		_check(flushed.tier_for(i) == EnemyRoster.tier_of(flushed.lineup[i]), "slot %d of a flushed fight agrees" % i)
	var both := Encounter.for_tile(cell, "forest")
	both.wear(["flush_out:forest", "grazing:forest"])
	for i in both.enemies:
		_check(both.tier_for(i) == EnemyRoster.tier_of(both.lineup[i]), "slot %d of a pilgrim's fight agrees" % i)
	_check(EnemyRoster.tier_of(both.lineup[0]) == EnemyRoster.Tier.ELITE and both.enemies == Encounter.ENEMIES + 2,
			"grazing and flush out together: twelve, elite first")
	var village := Encounter.for_tile(cell, "forest", "village")
	var order := village.lineup.duplicate()
	village.wear(["flush_out:forest"])
	_check(village.lineup == order, "a settlement is a set piece and keeps its order")

	# Heatstroke: the one thing that kills with nobody swinging.
	var sun := Encounter.farm(cell, "desert")
	sun.effects = ["heatstroke:desert"]
	sun.start()
	sun.advance(Encounter.WALK_IN)
	sun.advance(10.0)
	_check(is_equal_approx(sun.hp, sun.enemy_max_hp() * 0.8), "2%% a second it stands (%s of %s)" % [sun.hp, sun.enemy_max_hp()])
	for i in 120:
		sun.advance(1.0)
	_check(sun.kills() >= 2 and sun.gold > 0.0, "the heat kills, and the body pays (%d)" % sun.kills())

	# Frozen clock: a walk-in costs nothing.
	var rime := Encounter.for_tile(cell, "ice")
	rime.effects = ["frozen_clock:ice"]
	rime.start()
	rime.advance(Encounter.WALK_IN)
	_check(rime.time_left == rime.seconds and rime.phase == Encounter.Phase.WAITING, "the clock stands still for a walk-in")
	rime.advance(1.0)
	_check(is_equal_approx(rime.time_left, rime.seconds - 1.0), "and runs once the enemy stands")

	# Giantsbane: triple on big bodies, with Giant Slayer or without, and never both.
	for worn: Array in [["giantsbane:mountains"], ["giantsbane:mountains", "giant_slayer"]]:
		var peak := Encounter.for_tile(cell, "mountains")
		peak.effects = worn
		peak.arm({"damage": 0.0})
		peak.start()
		peak.advance(Encounter.WALK_IN)
		var before := peak.hp
		peak.hit()
		_check(peak.hp == before - 1.0, "a common takes one")
		peak.index = peak.enemies - 1
		peak.hp = peak.health[peak.index]
		before = peak.hp
		peak.hit()
		_check(peak.hp == before - 3.0, "the elite takes three, %s" % [worn])

	# Restless dead: some commons get back up in the slot they fell in, and pay again.
	var grave := Encounter.for_tile(cell, "dirt")
	var seeded := 0
	var risen := 0
	var deaths := [0]
	while risen == 0 and seeded < 20:
		grave = Encounter.for_tile(cell, "dirt")
		grave.effects = ["restless:dirt"]
		grave.arm({"damage": 1.0e9})
		grave.loot_rng.seed = WORLD_SEED + seeded
		deaths[0] = 0
		grave.enemy_died.connect(func(_i: int) -> void: deaths[0] += 1)
		grave.start()
		_play(grave, 200)
		risen = grave.kills() - grave.enemies
		seeded += 1
	_check(grave.victory and risen > 0, "somebody rose (%d)" % risen)
	_check(deaths[0] == grave.kills() and grave.lineup.size() == grave.enemies,
			"every rising is a second death in the same slot (%d deaths, %d slots)" % [deaths[0], grave.enemies])
	return true


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
