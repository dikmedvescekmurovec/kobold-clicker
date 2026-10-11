extends "res://tests/combat_base.gd"
## Headless checks for the tile fight. Run from the project folder:
##   python tests/run_all.py combat_blows
## Plays whole encounters through Encounter.advance and Encounter.hit, with no scene and no window.


func _run() -> void:
	_clear_saves()
	_check(_test_lineup() == true, "lineup tests ran to the end")
	_check(_test_the_dreadmask() == true, "dreadmask tests ran to the end")
	_check(_test_what_a_hit_is_worth() == true, "damage tests ran to the end")
	_check(_test_the_weapon_swings_itself() == true, "attack speed tests ran to the end")
	_check(_test_the_hand_is_capped() == true, "click cap tests ran to the end")
	_check(_test_spawn_speed() == true, "spawn speed tests ran to the end")
	_check(_test_bleed() == true, "bleed tests ran to the end")
	_check(_test_weapon_lines() == true, "weapon line tests ran to the end")
	_check(_test_elite_chance() == true, "elite chance tests ran to the end")
	_check(_test_defence_lines() == true, "helmet, body and offhand line tests ran to the end")
	_check(_test_capstone_effects() == true, "capstone effect tests ran to the end")
	_check(_test_backdrops() == true, "backdrop tests ran to the end")
	_check(_test_backdrop_layouts() == true, "backdrop layout tests ran to the end")
	_check(_test_skies() == true, "sky tests ran to the end")
	_check(_test_gold() == true, "gold tests ran to the end")
	_check(_test_experience() == true, "experience tests ran to the end")
	_check(_test_coins() == true, "coin tests ran to the end")
	_check(_test_sounds() == true, "sound tests ran to the end")
	_check(await _test_thrown_finds() == true, "thrown finds tests ran to the end")
	_check(await _test_the_longest_stop_wins() == true, "the longest stop wins tests ran to the end")
	_check(await _test_settings() == true, "settings tests ran to the end")
	_check(await _test_the_nameplate_wears_the_tier() == true, "the nameplate wears the tier tests ran to the end")
	_check(await _test_the_backdrop_goes_by() == true, "the backdrop goes by tests ran to the end")
	_report("combat: blows")


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
## The weapon's lines: each on the blow it names and no other, one sum, and what a blow is worth on
## average says so.
func _test_weapon_lines() -> bool:
	var top := 1.0e9
	# Click Damage on the hand's blow, Swing Damage on the weapon's own.
	var both := _standing([], {"damage": 9.0, "click_damage": 50.0, "swing_damage": 100.0, "attack_speed": 1.0})
	both.hit()
	_check(both.hp == top - 15.0, "a click of 10 at +50%% is 15 (%s)" % (top - both.hp))
	both.advance(1.0)
	_check(both.hp == top - 35.0, "and a swing of 10 at +100%% is 20 (%s)" % (top - both.hp - 15.0))
	# Elite Damage on an elite and not on a common; First Blow Damage on a body's first blow alone.
	var big := _standing([], {"damage": 9.0, "elite_damage": 100.0})
	big.hit()
	_check(big.hp == top - 10.0, "a common takes the plain blow")
	big.index = big.enemies - 1
	big.hp = big.health[big.index]
	var before := big.hp
	big.hit()
	_check(big.on_elite() and big.hp == before - 20.0, "the elite takes twice it")
	var opener := _standing([], {"damage": 9.0, "first_blow": 100.0, "click_damage": 50.0})
	opener.hit()
	_check(opener.hp == top - 25.0, "the first blow adds its share to the click's, one sum (%s)" % (top - opener.hp))
	opener.hit()
	_check(opener.hp == top - 40.0, "and the second has only the click's")
	# Double Strike: capped at certainty, where every blow lands twice; with none, nothing is drawn.
	var twice := _standing([], {"damage": 9.0, "double_strike": 150.0})
	_check(twice.double_strike == 100.0, "a chance is at most certain")
	twice.hit()
	_check(twice.hp == top - 20.0, "a blow of 10 lands as 20 (%s)" % (top - twice.hp))
	var plain := _standing([], {"damage": 9.0})
	var drawn := plain.crit_rng.state
	plain.hit()
	_check(plain.crit_rng.state == drawn, "with no chance at all the generator is left alone")
	# The average blow counts the hand's or the weapon's line and the double strike, and nothing of the
	# elite's or the first blow's.
	var average := _standing([], {"damage": 9.0, "click_damage": 50.0, "swing_damage": 100.0,
		"double_strike": 50.0, "elite_damage": 300.0, "first_blow": 300.0})
	_check(is_equal_approx(average.average_blow(false), 22.5) and is_equal_approx(average.average_blow(true), 30.0),
			"a click averages 22.5 and a swing 30 (%s, %s)" % [average.average_blow(false), average.average_blow(true)])
	return true


## Elite Chance: commons come on as elites of their ground, sized as elites, once a fight -- and a run's
## later bodies as they join. Never in the dungeon, and with none nothing is drawn.
func _test_elite_chance() -> bool:
	var cell := Vector2i(12, 0)
	var plain := Encounter.for_tile(cell, "grass")
	var none := Encounter.for_tile(cell, "grass")
	var untouched := none.elite_rng.state
	none.arm({})
	_check(none.lineup == plain.lineup and none.elite_rng.state == untouched,
			"with no chance the lineup is the cell's and nothing is drawn")
	var promoted := Encounter.for_tile(cell, "grass")
	promoted.elite_rng.seed = WORLD_SEED
	promoted.arm({"elite_chance": 250.0})
	_check(promoted.elite_chance == 100.0, "a chance is at most certain")
	for at in promoted.lineup.size():
		var enemy := promoted.lineup[at]
		_check(Encounter.tier_in(promoted, at) == EnemyRoster.Tier.ELITE
				and "grass" in EnemyRoster.environments_of(enemy),
				"%s at %d comes on as an elite of the grass" % [enemy, at])
		_check(promoted.health[at] == Encounter.hp_of(enemy, cell), "%s is sized as the elite it is" % enemy)
	_check(promoted.hp == promoted.health[0], "the first body out is the promoted one")
	var kept := promoted.lineup.duplicate()
	promoted.arm({"elite_chance": 100.0})
	_check(promoted.lineup == kept and promoted.enemies == plain.enemies, "armed again it promotes nothing more")
	# A run asks each body as it joins.
	var run := Encounter.farm(cell, "grass")
	run.arm({"elite_chance": 100.0, "damage": 1.0e9})
	run.start()
	for i in 4:
		run.advance(Encounter.WALK_IN)
		run.hit()
		run.advance(Encounter.DEATH)
	_check(run.lineup.size() > 4, "the run went on (%d)" % run.lineup.size())
	for enemy in run.lineup:
		_check(EnemyRoster.tier_of(enemy) == EnemyRoster.Tier.ELITE, "%s joined the run as an elite" % enemy)
	# The dungeon's floors are counted, and the wall is a wall.
	var deep := Encounter.for_dungeon()
	deep.arm({"elite_chance": 100.0})
	_check(EnemyRoster.tier_of(deep.lineup[0]) == EnemyRoster.Tier.COMMON, "the dungeon's first floor stays rabble")
	var wall := Encounter.for_wall(cell)
	wall.arm({"elite_chance": 100.0})
	_check(wall.lineup[0] == Encounter.WALL_NAME, "and the wall stays the wall")
	return true


## The helmet's, the body's and the offhand's lines (2026-10-07): each does what its sentence says, on
## the fights it says, and the "less" ones stop at `WARD_MOST`.
func _test_defence_lines() -> bool:
	var top := 1.0e9
	# A later first blow: half an interval late, and the blows after it on their own rhythm.
	var late := _struck_standing(EnemyRoster.Tier.COMMON, {"blow_delay": 50.0})
	var blows: Array = []
	late.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: blows.append(t))
	late.advance(1.499)
	_check(blows.is_empty(), "the first blow waits half an interval more (%d)" % blows.size())
	late.advance(0.002)
	_check(blows.size() == 1, "and then lands")
	late.advance(1.0)
	_check(blows.size() == 2, "and the next a whole interval after it")

	# Less off an elite's or a boss's blow, nothing off a common's, and never past the most.
	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE]:
		var warded := _struck_standing(tier, {"elite_ward": 50.0})
		var taken: Array = []
		warded.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: taken.append(t))
		warded.advance(float(Encounter.ATTACK_EVERY[tier]) + 0.001)
		var whole := Encounter.hit_of(warded.enemy_name(), warded.cell)
		var want := whole * (0.5 if tier == EnemyRoster.Tier.ELITE else 1.0)
		_check(taken.size() == 1 and is_equal_approx(float(taken[0]), want),
				"tier %d's blow takes %.3f (%s)" % [tier, want, taken])
	var most := Encounter.new()
	most.arm({"elite_ward": 500.0, "tile_ward": 500.0, "less_health": 500.0, "recoup": 500.0})
	_check(most.elite_ward == Encounter.WARD_MOST and most.tile_ward == Encounter.WARD_MOST
			and most.less_health == Encounter.WARD_MOST and most.recoup == 100.0, "each stops at its most")

	# Weaker tile modifiers: half of a Piercing tile's armour back, half a Dusk's seconds, half a
	# Thick-skinned tile's health and half a Brutal tile's blow; what the tile pays is untouched.
	var here := Vector2i(4, 6)
	var mods := ["piercing", "short_day", "thick_skinned", "savage"]
	var bitten := Encounter.for_tile(here, "grass", "plain", false, mods)
	bitten.arm({"armor": 100.0})
	var softer := Encounter.for_tile(here, "grass", "plain", false, mods)
	softer.arm({"armor": 100.0, "tile_ward": 50.0})
	var rows := TileMods.MODS
	var pierced := float(rows["piercing"]["armor"])
	_check(is_equal_approx(bitten.armor, 100.0 * pierced)
			and is_equal_approx(softer.armor, 100.0 * (1.0 + (pierced - 1.0) * 0.5)),
			"a Piercing tile cuts the armour, and half as deep with half its bite gone (%s)" % softer.armor)
	_check(is_equal_approx(softer.seconds, bitten.seconds - float(rows["short_day"]["seconds"]) * 0.5)
			and is_equal_approx(softer.time_left, softer.seconds),
			"a Dusk takes half its seconds (%s, %s)" % [bitten.seconds, softer.seconds])
	var thicker := float(rows["thick_skinned"]["hp"])
	for at in bitten.lineup.size():
		var plain := Encounter.hp_of(bitten.lineup[at], here)
		_check(softer.health[at] == maxf(1.0, roundf(plain * (1.0 + thicker * 0.5)))
				and bitten.health[at] == maxf(1.0, roundf(plain * (1.0 + thicker))),
				"%s has half of Thick-skinned's more health" % bitten.lineup[at])
	_check(softer.gold_find == bitten.gold_find and softer.drop_rate == bitten.drop_rate, "and the tile pays as much")
	# Armed again with no armour, so the blows are the tile's alone.
	bitten.arm({})
	softer.arm({"tile_ward": 50.0})
	for fight: Encounter in [bitten, softer]:
		fight.strikes = true
		fight.lineup[0] = _enemy_of(EnemyRoster.Tier.COMMON)
		fight.hp = top
		fight.start()
		fight.advance(fight.walk_in)
	var sizes: Array = []
	for fight: Encounter in [bitten, softer]:
		fight.player_hit.connect(func(t: float, _d: bool, _b: bool) -> void: sizes.append(t))
		fight.advance(1.001)
	var bare_hit := Encounter.hit_of(bitten.lineup[0], here)
	var harder := float(rows["savage"]["hit"])
	_check(sizes.size() == 2 and is_equal_approx(float(sizes[0]) / float(sizes[1]), (1.0 + harder) / (1.0 + harder * 0.5)),
			"a Brutal tile's blow is half as much harder (%s against %s)" % [sizes, bare_hit])

	# Less health: on every body of a tile, on the wall, and on the dungeon's floors as they come.
	var cell := Vector2i(12, 0)
	var full := Encounter.for_tile(cell, "grass")
	var thin := Encounter.for_tile(cell, "grass")
	thin.arm({"less_health": 20.0})
	for at in full.lineup.size():
		_check(thin.health[at] == maxf(1.0, roundf(full.health[at] * 0.8)), "%s has a fifth less health" % full.lineup[at])
	_check(thin.hp == thin.health[0], "the first body out is the thinner one")
	var wall := Encounter.for_wall(cell)
	var thin_wall := Encounter.for_wall(cell)
	thin_wall.arm({"less_health": 20.0})
	_check(thin_wall.hp == roundf(wall.hp * 0.8), "the wall too (%s of %s)" % [thin_wall.hp, wall.hp])
	var deep := Encounter.for_dungeon()
	var thin_deep := Encounter.for_dungeon()
	thin_deep.arm({"less_health": 20.0, "damage": 1.0e12})
	thin_deep.start()
	thin_deep.advance(Encounter.WALK_IN)
	thin_deep.hit()
	thin_deep.advance(Encounter.DEATH + Encounter.WALK_IN)
	deep._append_enemy(deep.roster_rng)
	_check(thin_deep.health[1] == maxf(1.0, roundf(deep.health[1] * 0.8)),
			"and a floor joined later (%s)" % thin_deep.health[1])

	# More or fewer bodies on a tile: commons at the front, the elite still last, the same each time;
	# never the last body, and never a run's, a wall's or the dungeon's count.
	for extra: int in [2, -2]:
		var shaped := Encounter.for_tile(cell, "grass")
		shaped.arm({"extra_enemies": float(extra)})
		var again := Encounter.for_tile(cell, "grass")
		again.arm({"extra_enemies": float(extra)})
		_check(shaped.lineup.size() == full.lineup.size() + extra and shaped.enemies == shaped.lineup.size(),
				"%+d is %d bodies (%d)" % [extra, full.lineup.size() + extra, shaped.lineup.size()])
		_check(EnemyRoster.tier_of(shaped.lineup[-1]) == EnemyRoster.Tier.ELITE, "and the fight still ends on its elite")
		_check(shaped.lineup == again.lineup, "the same bodies every time")
		_check(shaped.hp == shaped.health[0], "the first out is the first in line")
	var lone := Encounter.for_tile(cell, "grass")
	lone.arm({"extra_enemies": -50.0})
	_check(lone.lineup.size() == 1 and EnemyRoster.tier_of(lone.lineup[0]) == EnemyRoster.Tier.ELITE,
			"the commons can all go, never the elite (%s)" % [lone.lineup])
	var run := Encounter.farm(cell, "grass")
	run.arm({"extra_enemies": 2.0})
	_check(run.lineup.size() == 1, "a run has no count to change")
	var still := Encounter.for_wall(cell)
	still.arm({"extra_enemies": 2.0})
	_check(still.lineup == PackedStringArray([Encounter.WALL_NAME]), "a wall is one body")

	# Thorns: a blow that lands strikes back a share of the damage, and a dodged one nothing.
	var spiky := _struck_standing(EnemyRoster.Tier.COMMON, {"damage": 9.0, "thorns": 50.0})
	spiky.advance(1.001)
	_check(spiky.hp == 1.0e9 - 5.0, "half of 10 struck back (%s)" % (1.0e9 - spiky.hp))
	var slippery := _standing([], {"damage": 9.0, "thorns": 50.0, "dodge": 1.0e15})
	slippery._struck_by(1.0)
	_check(slippery.hp == top, "a dodged blow strikes nothing back")

	# Recoup: half of a 4 s blow back over four seconds, a second's share at a time.
	var mended := _standing([], {"recoup": 50.0})
	var start := mended.time_left
	mended._struck_by(4.0)
	mended.advance(2.0)
	_check(is_equal_approx(mended.time_left, start - 4.0 - 2.0 + 1.0), "half of it is back after two seconds (%.3f)"
			% (mended.time_left - start))
	mended.advance(10.0)
	_check(is_equal_approx(mended.time_left, start - 4.0 - 12.0 + 2.0) and is_equal_approx(mended.wounds, 2.0),
			"and all of the half after four, and no more (%.3f)" % (mended.time_left - start))

	# A dodge hands the next blow its crit chance, and the blow after it has none.
	var parried := _standing([], {"damage": 9.0, "crit_damage": 100.0, "parry": 100.0, "dodge": 1.0e15})
	parried._struck_by(1.0)
	parried.hit()
	_check(parried.hp == top - 20.0, "the blow after a dodge crits (%s)" % (top - parried.hp))
	parried.hit()
	_check(parried.hp == top - 30.0, "and the next does not")

	# Burn: 30% of a blow of 10 over three seconds is a point a second, the deepest burn, for three seconds.
	var burnt := _standing([], {"damage": 9.0, "burn": 30.0})
	burnt.hit()
	burnt.advance(1.0)
	_check(is_equal_approx(burnt.hp, top - 11.0), "a point burns in the first second (%s)" % (top - burnt.hp))
	burnt.advance(5.0)
	_check(is_equal_approx(burnt.hp, top - 13.0), "and three in all (%s)" % (top - burnt.hp))

	# Time on block: a blow the block stops whole wins back its seconds out of the wounds, one that gets
	# through wins nothing.
	var blocker := _standing([], {"block": 100.0, "time_on_block": 10.0})
	blocker.wounds = 5.0
	blocker.time_left = 20.0
	blocker._struck_by(1.0)
	_check(is_equal_approx(blocker.time_left, 21.0) and is_equal_approx(blocker.wounds, 4.0),
			"a second back for a blow stopped whole (%.2f)" % blocker.time_left)
	var through := _standing([], {"time_on_block": 10.0})
	through.wounds = 5.0
	through.time_left = 20.0
	through._struck_by(1.0)
	_check(is_equal_approx(through.time_left, 19.0), "and nothing for one that got through (%.2f)" % through.time_left)
	return true


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
	_check(Encounter.base_gold(MapBuilder.CENTER) == Encounter.BASE_GOLD,
			"a body in the middle carries the base purse, which is where the curve is pinned")

	# Linear *and* exponential: every step adds GOLD_PER_STEP and multiplies by GOLD_GROWTH. Checked
	# step by step out to the edge, with the slack rounding to whole gold allows.
	for steps in range(0, 21):
		var here := Vector2i(steps, 0)
		_check(HexGrid.distance(MapBuilder.CENTER, here) == steps, "cell %d is %d steps out" % [steps, steps])
		var want: float = (Encounter.BASE_GOLD + Encounter.GOLD_PER_STEP * steps) \
				* pow(Encounter.GOLD_GROWTH, steps)
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
		_check(Encounter.gold_of(enemy, far) == maxf(1.0, roundf(Encounter.base_gold(far) * EnemyRoster.hp_modifier(enemy))),
				"%s carries the tile's purse times what its body is worth" % enemy)

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
	var far := Vector2i(12, 0)
	for cell: Vector2i in [MapBuilder.CENTER, far]:
		_check(Encounter.base_xp(cell) == maxi(1, roundi(Encounter.XP_PER_LEVEL * MapBuilder.level_of(cell))),
				"a body is worth so much experience a level of its tile (%s)" % cell)
	for enemy in EnemyRoster.names():
		_check(Encounter.xp_of(enemy, MapBuilder.CENTER) >= 1, "%s is never worth less than one" % enemy)
		_check(Encounter.xp_of(enemy, far) > Encounter.xp_of(enemy, MapBuilder.CENTER),
				"%s is worth more further out" % enemy)
		_check(Encounter.xp_of(enemy, far) == maxi(1, roundi(Encounter.base_xp(far) * EnemyRoster.hp_modifier(enemy))),
				"%s is worth the tile's experience times what its body is worth" % enemy)

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
	# The promised orbs come through that gate: `test_inventory`'s promised finds.
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
func _test_the_backdrop_goes_by() -> bool:
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
	return true


## The nameplate's bar drains with the enemy and wears that enemy's tier. Needs a scene rather than an
## Encounter: the encounter knows the hit points and the view is what turns them into a width.
##
## The two halves are one test because they are one claim. The bar and the kill pips both read
## Encounter.tier_in, so what this really holds is that the frame over the enemy's head and the pip
## standing for it are the same answer -- a green-framed bar over a common, or a brown one over the
## elite, would be worse than either of them simply being the wrong colour.
func _test_the_nameplate_wears_the_tier() -> bool:
	var cell := Vector2i(4, 0)
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	var fight := Encounter.for_tile(cell, "grass")
	combat.begin(fight, cell, 2.0)
	await process_frame
	var bar := combat.hud._enemy_bar
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
	combat.hud.refresh()
	var want := float(full) * fight.hp / max_hp
	_check(absf(bar._fill.size.x - want) <= HealthBar.PIXEL,
			"%d of %d hit points is %d px of the bar's %d, wanted about %d"
					% [fight.hp, max_hp, bar._fill.size.x, full, want])
	fight.hp = 1
	combat.hud.refresh()
	_check(bar._fill.size.x > 0.0 and bar._fill.size.x < full / 4.0,
			"one hit point left still shows, and shows as nearly nothing")

	# Walk the lineup to the elite. The frame changes and the trough does not.
	var elite := fight.enemies - 1
	_check(Encounter.tier_in(fight, elite) == EnemyRoster.Tier.ELITE, "the tenth is the elite")
	fight.index = elite
	fight.hp = fight.enemy_max_hp()
	combat.hud.refresh()
	_check(bar._cap_l.texture == HealthBar.CAP_L[EnemyRoster.Tier.ELITE],
			"the elite's own frame is worn when it walks in")
	_check(bar._tracks[0].texture == HealthBar.TRACK[EnemyRoster.Tier.ELITE],
			"and its rail with it, not only its ends")
	_check(bar._fill.size.x == full, "an elite at full health is exactly as much red as a common")
	_check(bar.custom_minimum_size.x > HealthBar.width_of(EnemyRoster.Tier.COMMON),
			"and its bar is the wider one")

	# The pips beside it are drawn in that same tier, which is the whole reason the lookup was shared
	# rather than written out twice. The elite is the last of the ten, so it is the last pip.
	_check(combat.hud._pips._pips[elite].texture == KillPips.texture(EnemyRoster.Tier.ELITE),
			"the pip standing for the elite is the elite's skull")
	_check(combat.hud._pips._pips[0].texture == KillPips.texture(EnemyRoster.Tier.COMMON, true),
			"and those already down are spent")

	# Nothing standing means no nameplate at all, rather than an empty frame.
	fight.index = fight.lineup.size()
	combat.hud.refresh()
	_check(not combat.hud._enemy_panel.visible, "with the lineup spent the nameplate goes")
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
	_check(siege.enemies > KillPips.SHOWN and town.hud._pips._pips.size() == KillPips.SHOWN,
			"a village's bar shows %d of its %d pips, not %d" % [KillPips.SHOWN, siege.enemies, town.hud._pips._pips.size()])
	var pips: Array[TextureRect] = town.hud._pips._pips
	_check(pips[-1].texture == KillPips.MORE, "the last place is the caret while more are to come")
	_check(pips[0].texture == KillPips.texture(Encounter.tier_in(siege, 0)), "and the first is the one being fought")
	siege.index = 1
	town.hud.refresh()
	_check(pips[0].texture == KillPips.texture(Encounter.tier_in(siege, 1)) and pips[-1].texture == KillPips.MORE,
			"a kill drops it off the left and the rest move up a place")
	var last_ten := siege.enemies - KillPips.SHOWN
	siege.index = last_ten
	town.hud.refresh()
	_check(pips[-1].texture == KillPips.texture(EnemyRoster.Tier.BOSS),
			"with the last ten in view the caret goes and the boss's crowned skull ends the bar")
	siege.index = last_ten + 2
	town.hud.refresh()
	_check(pips[1].texture == KillPips.texture(Encounter.tier_in(siege, last_ten + 1), true)
			and pips[2].texture == KillPips.texture(Encounter.tier_in(siege, last_ten + 2)),
			"and from there the bar stays put and drains where it stands")
	siege.index = 0
	town.hud.refresh()
	_check(town.hud._clock_fill.get_parent().size.x
			== KillPips.width_for(siege.enemies) - 2 * FightHud.BAR_BORDER,
			"the clock is cut to the pip bar it stands under")
	town.queue_free()
	await process_frame
	return true


## What a body drops lands in the arena, the way its purse does: a sprite thrown out of it, glowing
## in its rarity above common, and no panel anywhere. Needs a scene rather than an Encounter, because
## the throwing is the view's half of it.
func _test_thrown_finds() -> bool:
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
			_check(combat.hud.z_index > lit.z_index + front.z_index, "and the HUD drawn over the lot")
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
	return true


## A unique's long slow motion is not cut short by the kill freezes that land inside it, and it eases
## back to full speed rather than snapping.
func _test_the_longest_stop_wins() -> bool:
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
	return true


## A piece to throw. The type is any real one -- what is being checked is the throw, not the roll.
## The settings: they come back off their file, a fight with animations off throws nothing and still
## fills the bar, and a detailed modifier line carries the band it rolled in. Every static is put back,
## since the suites after this one in the file read them.
func _test_settings() -> bool:
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
	_check(combat.hud._drops.size() == 1, "though the find is still kept")
	Settings.animations = Settings.Anim.LOW
	combat._on_gold_dropped(0, 1000.0)
	_check(combat._ground_drops.get_child_count() == 1, "on low a purse is one coin")
	combat.queue_free()
	await process_frame
	Settings.sfx_volume = 1.0
	Settings.animations = Settings.Anim.DEFAULT
	Settings.item_details = false
	Settings.apply_audio()
	return true


## What a fight sounds like is chosen by rule: a find lands by what it is, and a blow and a crit land
## by the weapon in hand.
func _test_sounds() -> bool:
	var first := {}
	for type: String in LootTable.items():
		if not first.has(LootTable.kind_of(type)):
			first[LootTable.kind_of(type)] = type
	for kind: String in ["sword", "gold_ring", "boot", "plate", "torch"]:
		var piece := _thrown_piece(ItemRarity.Rarity.RARE)
		piece.type = first[kind]
		_check(FightSounds.drop_sound_of(piece) == "gear", "a %s lands as gear" % kind)
	_check(FightSounds.drop_sound_of(_thrown_piece(ItemRarity.Rarity.UNIQUE)) == "unique",
			"and a unique with its own, whatever it is")

	var blows := [["", FightSounds.HIT_SOUND, FightSounds.BLUNT_CRIT, null],
			["mace", FightSounds.BLUNT_HIT, FightSounds.BLUNT_CRIT, null],
			["sword", FightSounds.HIT_SOUND, FightSounds.SLASH_CRIT, FightSounds.GENERAL_CRIT],
			["dagger", FightSounds.HIT_SOUND, FightSounds.SLASH_CRIT, FightSounds.GENERAL_CRIT]]
	for blow: Array in blows:
		var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
		combat.weapon_kind = blow[0]
		root.add_child(combat)
		combat.begin(Encounter.for_tile(Vector2i(4, 0), "grass"), Vector2i(4, 0), 2.0)
		var layer: AudioStream = null if combat._sounds.crit_layer == null else combat._sounds.crit_layer.stream
		_check(combat._sounds.hit.stream == blow[1] and combat._sounds.crit.stream == blow[2] and layer == blow[3],
				"a hit with %s lands and crits as it should" % ("bare hands" if blow[0] == "" else "a " + blow[0]))
		combat.free()
	return true
