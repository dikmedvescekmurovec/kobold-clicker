extends "res://tests/combat_base.gd"
## Headless checks for the tile fight. Run from the project folder:
##   python tests/run_all.py combat_curses
## Plays whole encounters through Encounter.advance and Encounter.hit, with no scene and no window.


func _run() -> void:
	_clear_saves()
	_check(_test_orb_drops() == true, "orb drop tests ran to the end")
	_check(_test_drop_rate_finds_everything() == true, "drop rate tests ran to the end")
	_check(_test_even_loot() == true, "even loot tests ran to the end")
	_check(_test_starter_rules() == true, "starter unique tests ran to the end")
	_check(_test_fight_tally() == true, "fight tally tests ran to the end")
	_check(_test_tile_mods() == true, "tile modifier tests ran to the end")
	_check(_test_curses() == true, "curse tests ran to the end")
	_check(_test_more_curses() == true, "second batch curse tests ran to the end")
	_check(_test_no_defence_holds_the_clock() == true, "unlosable fight tests ran to the end")
	_check(_test_a_warded_modifier_wears_off() == true, "warded modifier tests ran to the end")
	_check(_test_a_death_beats_the_clock() == true, "death and clock tests ran to the end")
	_check(_test_a_kill_is_paid_after_its_loot() == true, "kill paid tests ran to the end")
	_check(_test_the_panel_says_what_a_tile_pays() == true, "tile pay tests ran to the end")
	_check(_test_the_fight_names_what_the_tables_have() == true, "table name tests ran to the end")
	_check(await _test_the_arena_follows_the_window() == true, "arena layout tests ran to the end")
	_check(await _test_a_world_under_the_fog() == true, "a world under the fog tests ran to the end")
	_check(await _test_the_way_down() == true, "the way down tests ran to the end")
	_report("combat: curses")


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
	_check(dry.tally.get("dry_streak") == 12 and not dry.tally.has("crits"),
			"twelve blows with no crit (%s)" % [dry.tally])

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

	# The shape of the fight, each from its own row's dials.
	var rows := TileMods.MODS
	var plain := Encounter.for_tile(here, "grass", "plain")
	var more := int(rows["horde"]["enemies"])
	var horde := Encounter.for_tile(here, "grass", "plain", false, ["horde"])
	_check(horde.enemies == plain.enemies + more and horde.lineup.size() == horde.enemies
			and horde.seconds == plain.seconds,
			"a Horde is its row's more on the same clock (%d)" % horde.enemies)
	_check(Encounter.tier_in(horde, horde.enemies - 1) == EnemyRoster.Tier.ELITE
			and Encounter.tier_in(horde, plain.enemies - 1) == EnemyRoster.Tier.COMMON,
			"more of the rabble, and still ending on its elite")
	var sparse := Encounter.for_tile(here, "grass", "plain", false, ["sparse"])
	_check(sparse.lineup.size() == plain.enemies + int(rows["sparse"]["enemies"])
			and Encounter.tier_in(sparse, sparse.lineup.size() - 1) == EnemyRoster.Tier.ELITE,
			"a Sparse tile is its row's fewer, the last of them the elite (%d)" % sparse.lineup.size())
	var short := Encounter.for_tile(here, "grass", "plain", false, ["short_day"])
	_check(is_equal_approx(short.seconds, plain.seconds + float(rows["short_day"]["seconds"]))
			and short.time_left == short.seconds,
			"a Dusk is its row's seconds off the clock (%s)" % short.seconds)
	var pace := int(rows["elite_ground"]["elite_every"])
	var elites := Encounter.for_tile(here, "grass", "plain", false, ["elite_ground"])
	_check(Encounter.tier_in(elites, pace - 1) == EnemyRoster.Tier.ELITE
			and Encounter.tier_in(elites, 2 * pace - 1) == EnemyRoster.Tier.ELITE, "Elite Ground fields one at its row's pace")
	# A modifier drawn twice is its second tier: tougher and paying more, and written so.
	var hordes := Encounter.for_tile(here, "grass", "plain", false, ["horde", "horde"])
	_check(hordes.enemies == plain.enemies + 2 * more
			and Encounter.tier_in(hordes, hordes.enemies - 1) == EnemyRoster.Tier.ELITE
			and Encounter.tier_in(hordes,
					horde.enemies - 1) == EnemyRoster.Tier.COMMON, "Horde II is as many more again, still ending on its elite")
	var more_elites := Encounter.for_tile(here, "grass", "plain", false, ["elite_ground", "elite_ground"])
	_check(more_elites.elite_every == maxi(2, ceili(pace / 2.0)) and more_elites.elite_every < elites.elite_every,
			"Elite Ground II fields them twice as close (%d)" % more_elites.elite_every)
	var brutal: Dictionary = rows["savage"]
	_check(TileMods.describe("savage", 2) == PackedStringArray([str(brutal["name"]) + " II",
			str(brutal["text"]).replace("{hit}", str(roundi(float(brutal["hit"]) * 2.0 * 100.0))),
			"+%d%% %s" % [roundi(float(brutal["drop_rate"]) * 2.0), TileMods.PAYS["drop_rate"]]]),
			"Brutal II reads its own numbers (%s)" % [TileMods.describe("savage", 2)])
	_check(TileMods.describe("piercing", 2)[1] == str(rows["piercing"]["text"]).replace("{armor}",
			str(roundi(pow(float(rows["piercing"]["armor"]), 2.0) * 100.0))), "a factor tier compounds")
	_check(TileMods.describe("sparse", 1)[1] == str(rows["sparse"]["text"]).replace("{enemies}",
			str(absi(int(rows["sparse"]["enemies"])))) and TileMods.describe("sparse", 1)[2] == "",
			"Sparse reads as the boon it is")
	for id: String in rows:
		for tier: int in [1, 2]:
			_check(not "{" in TileMods.describe(id, tier)[1], "%s is written out at tier %d" % [id, tier])
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
	_check(is_equal_approx(thick.health[0], roundf(plain.health[0] * (1.0 + float(rows["thick_skinned"]["hp"])))),
			"Thick-skinned is its row's more health (%s against %s)" % [thick.health[0], plain.health[0]])
	var mire := Encounter.for_tile(here, "grass", "plain", false, ["mire"])
	_check(is_equal_approx(mire.walk_in, Encounter.WALK_IN * float(rows["mire"]["walk_in"]))
			and mire.phase_left == mire.walk_in,
			"a Mire is its row's times the walk-in")
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
	_check(is_equal_approx(wild_pay.drop_rate,
			float(stats["drop_rate"]) + float(brutal["drop_rate"]) * TileMods.WILD_REWARD),
			"Wild Tiles lifts what a tile pays")

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
	_check(is_equal_approx(blows["savage"][0], blows[""][0] * (1.0 + float(brutal["hit"]))),
			"and a Brutal one its row's share harder")

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
	_check(run.mods == TileMods.farmable(every) and not run.mods.is_empty(),
			"a run keeps the farmable ones %s" % [run.mods])
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
		# A sentence's figures are written in from the constants the rules read (`Curses.CURSES`), and
		# none is left a blank to fill.
		for line: String in [str(curse["text"]), str(curse["reward"])]:
			_check(not "{" in line and not "%d" in line and not "%s" in line and not "%." in line,
					"%s is written out (%s)" % [id, line])
		for stat: String in curse.get("stats", {}):
			_check(stat == "xp_more" or LootTable.STAT_LABELS.has(stat), "%s pays in a stat there is (%s)" % [id, stat])
			_check(("+%d%%" % roundi(float(curse["stats"][stat]))) in str(curse["reward"]),
					"%s says the %s it pays (%s)" % [id, stat, curse["reward"]])
	var thick := float(TileMods.MODS["thick_skinned"]["hp"])
	var iron := Encounter.for_tile(here, "grass", "plain", false, ["thick_skinned"])
	iron.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(iron.health[3],
			roundf(Encounter.hp_of(iron.lineup[3], here) * (1.0 + thick + Encounter.IRON_HP)))
			and iron.hp == iron.health[0], "Iron Foes adds to a tile's own, never compounds (%s)" % iron.health[3])
	iron.wear([Curses.effect(Curses.IRON_FOES)])
	_check(is_equal_approx(iron.health[3],
			roundf(Encounter.hp_of(iron.lineup[3], here) * (1.0 + thick + Encounter.IRON_HP))),
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
	var brutal := 1.0 + float(TileMods.MODS["savage"]["hit"])
	_check(is_equal_approx(blows[1] / blows[0], (brutal + Encounter.BLOODTHIRST_HIT) / brutal),
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
	_check(is_equal_approx(LootTable.chance_for(some, Encounter._lifted(20.0, 0.5)),
			LootTable.chance_for(some, 20.0) * 0.5),
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


## The dungeon from the main scene: no way down until the third wall has fallen in some world (Gollux's
## unlock, `WallUnlocks`), then the world's cave, entered stood on; the hero feels it at the map's edge until it is
## seen; a descent pays nothing
## and counts no kill, and a depth is written down only once its Gollux is dead.
func _test_the_way_down() -> bool:
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
	# Two walls once broken in some world: still none, Gollux being the third wall's.
	main.inventory.farthest_land = MapBuilder.START_LAND_RADIUS + 2 * MapBuilder.WALL_STEP
	main._credit_walls()
	_check(view.cave == HexMap.NO_CELL, "no cave before the third wall has fallen in any world")
	# The third: with no wall broken in this world yet, still none.
	main.inventory.farthest_land = MapBuilder.START_LAND_RADIUS + 3 * MapBuilder.WALL_STEP
	main._credit_walls()
	_check(view.cave == HexMap.NO_CELL, "Gollux unlocked, no cave until a wall is broken in this world")
	# A wall tile due east broken (`chart` says where): the cave goes down beside it, and is saved.
	var breach := Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0)
	view.breach = breach
	main._credit_walls()
	var cave: Vector2i = view.cave
	_check(cave != HexMap.NO_CELL and HexGrid.distance(breach, cave) <= MapBuilder.CAVE_NEAR
			and MapSave.load_from(SCRATCH_MAP).cave == cave,
			"the wall broken puts the world's cave down beside the breach, and the map is saved with it (%s)" % cave)

	# The cave felt from the hero: nothing while the wall in front of it stands -- the land here has not
	# moved out yet -- then a red light at the map's edge, and the hero says so.
	_check(not main._cave_sense.shown() and not main._tip_due("first_sense"),
			"a cave behind a wall still standing is not felt")
	view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	_check(main._cave_sense.shown(), "with the wall in front of it broken, the hero feels the cave at the map's edge")
	_check(main._tip_due("first_sense"), "and says so")
	# From the hero out: the light stands where the line toward the cave leaves the map.
	var area := Rect2(0, 0, 100, 60)
	_check(CaveSense.leaving(Vector2(50, 30), Vector2(1, 0), area) == Vector2(100, 30),
			"a cave east lights the right edge")
	_check(CaveSense.leaving(Vector2(50, 30), Vector2(-1, -1), area) == Vector2(20, 0),
			"one up and to the left the top edge, where the line from the hero meets it")
	_check(CaveSense.leaving(Vector2(-40, 30), Vector2(0, 1), area) == Vector2(0, 60),
			"and a hero panned off the map feels it from the edge nearest them")

	# The wall down and the land charted, stood on the cave: Enter cave, and nowhere else.
	view.land_radius = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	view._cover()
	view.reveal_all()
	main.map.select_cell(MapBuilder.CENTER)
	main.tile_panel.update_buttons()
	_check(not main.tile_panel.cave_button.visible, "no way down from anywhere but the cave")
	view.player_cell = cave
	main.map.select_cell(cave)
	main._on_tile_clicked(cave, main.map.get_tile_info(cave))
	_check(main.tile_panel.cave_button.visible and "depth 1" in main.tile_panel.cave_button.tooltip_text
			and main.tile_panel.level_label.text.begins_with("Cave"),
			"stood on the cave, Enter cave goes down to depth 1 (%s)" % main.tile_panel.cave_button.tooltip_text)
	_check(not main._cave_sense.shown() and not main._tip_due("first_sense"), "and seen, the light goes out")
	main._on_cave_pressed()
	var fight: Encounter = main._combat.fight if main._combat != null else null
	_check(fight != null and fight.dungeon and main._combat.place == main.DUNGEON_NAME and not main.map.visible,
			"it opens the dungeon over the map")
	if fight == null:
		return true
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
	_check("depth 3" in main.tile_panel.cave_button.tooltip_text, "Enter cave says where that leaves the player (%s)"
			% main.tile_panel.cave_button.tooltip_text)
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
	return true


func _test_a_world_under_the_fog() -> bool:
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
	_check(main.tile_panel.panel.visible and main.tile_panel.title.text == "Unknown land"
			and main.tile_panel.level_label.text == "Level %d" % main.view.level_of(blind),
			"a tile under the fog reads as unknown land, and its level is the walk's (%s)" % main.tile_panel.title.text)
	_check(main.tile_panel.env_rows.get_child_count() == 0 and main.tile_panel.service_rows.get_child_count() == 0
			and main.tile_panel.mod_rows.get_child_count() == 0, "with nothing said of what is on it")
	_check(main.view.to_save().names.get(blind, "") == "", "and looking at it has not named it")
	_check(main.tile_panel.chart_button.visible, "Chart is offered on it")
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
	_check(main.inventory.equip(torch, Equipment.Socket.OFFHAND) and main._sight() == 1,
			"the Broken Torch in hand is a ring of sight")
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
	return true


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
	_check(raw._raw(unique).rarity == ItemRarity.Rarity.UNIQUE and not unique.mods.is_empty(),
			"a unique is left as it fell")
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
	_check(bool(long["full"]) and is_equal_approx(float(long["seconds"]), Camp.RESTLESS_SECONDS),
			"and is full after two hours")
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


## No defence can bank time: a struck fight against a body that cannot be killed is lost inside its
## clock and its saves, whatever wins time back -- Recoup, time on hit, a block's seconds, a dodge.
func _test_no_defence_holds_the_clock() -> bool:
	var step := 1.0 / 60.0
	# A ring by the start, where a blow is small, and one past the first wall, where it is not.
	var cells := [Vector2i(1, 0), MapBuilder.CENTER + Vector2i(MapBuilder.START_LAND_RADIUS + 2, 0)]
	var mixes := [
		[{}, []],
		[{"recoup": 20.0}, []],
		[{"recoup": 100.0, "armor": Encounter.ARMOUR_K}, []],
		[{"recoup": 50.0, "time_on_hit": 10.0, "attack_speed": 4.0}, []],
		[{"recoup": 100.0, "block": 2.0, "time_on_block": 10.0, "attack_speed": 2.0}, ["riposte"]],
		[{"recoup": 100.0, "dodge": Encounter.DODGE_K, "time_on_hit": 5.0, "attack_speed": 10.0},
				["afterimage", "second_wind", "worry_stone"]],
	]
	for cell: Vector2i in cells:
		for mix: Array in mixes:
			var worn: Array = mix[1]
			var fight := Encounter.for_tile(cell, "grass")
			fight.strikes = true
			fight.effects = worn
			fight.crit_rng.seed = WORLD_SEED
			fight.arm(mix[0])
			fight.health[0] = 1.0e15
			fight.hp = 1.0e15
			fight.start()
			var saves := worn.count("second_wind") + worn.count("worry_stone")
			var most := fight.seconds + Encounter.SECOND_WIND_SECONDS * saves
			var spent := 0.0
			while not fight.finished and spent < most + 1.0:
				fight.hit()
				fight.advance(step)
				spent += step
			# A step of slack for the one the clock ran out in, and one for each save.
			_check(fight.finished and not fight.victory and spent <= most + step * (saves + 2),
					"%s at %s is lost inside its %.0f s (%.2f s in, %.3f on the clock)"
					% [mix, cell, most, spent, fight.time_left])
	return true


## A modifier that wears off a run takes the whole of its health with it, whatever the helmet's Tile
## Modifier Reduction had taken back of it: the bodies after are a tile's that never had it.
func _test_a_warded_modifier_wears_off() -> bool:
	var cell := Vector2i(8, 0)
	var stats := {"tile_ward": Encounter.WARD_MOST}
	var fresh := Encounter.farm(cell, "grass")
	fresh.arm(stats)
	var body := fresh.lineup[0]
	var worn := Encounter.farm(cell, "grass", "", ["thick_skinned", "thick_skinned", "thick_skinned"])
	worn.arm(stats)
	_check(worn._health_of(body) > fresh._health_of(body), "under the ward a Thick-skinned III is still thicker")
	for tier in 3:
		worn.forget_mod("thick_skinned")
	_check(worn._health_of(body) == fresh._health_of(body), "worn off, the next body is a plain tile's (%s against %s)"
			% [worn._health_of(body), fresh._health_of(body)])
	return true


## A body whose health ran out before the clock did is a kill however the frames fall: the last one
## felled with less than its death's time on the clock wins in small steps as in one long one, and no
## save is spent on it; Gollux felled there is a depth won; and a fight ended mid-death counts the body.
func _test_a_death_beats_the_clock() -> bool:
	for worn: Array in [[], ["second_wind"]]:
		for step: float in [Encounter.DEATH / 30.0, Encounter.DEATH * 4.0]:
			var fight := _on_last(_standing(worn, {"damage": 1.0e12}), 1.0)
			var results: Array = []
			fight.won.connect(func() -> void: results.append(true))
			fight.lost.connect(func() -> void: results.append(false))
			fight.time_left = Encounter.DEATH / 2.0
			_check(fight.hit() and fight.phase == Encounter.Phase.DYING,
					"the last body is felled with half its death's time left")
			var spent := 0.0
			while not fight.finished and spent < Encounter.DEATH * 8.0:
				fight.advance(step)
				spent += step
			_check(results == [true] and fight.kills() == fight.enemies,
					"in steps of %.3f s the fight is won, every body counted (%s, %s)" % [step, results, worn])
			_check(fight._saves_used == 0 and fight.time_left == 0.0, "with no save spent on it and the clock at nothing")

	# Gollux, the last floor of his depth, felled the same way: the descent ends a depth to the good.
	var block := int(Encounter.DUNGEON["enemies"])
	var down := Encounter.for_dungeon()
	down.arm({"damage": 1.0e15})
	down.start()
	while down.index < block - 1:
		down.advance(down.walk_in)
		down.hit()
		down.advance(Encounter.DEATH)
	down.advance(down.walk_in)
	down.time_left = Encounter.DEATH / 2.0
	_check(down.hit() and down.phase == Encounter.Phase.DYING and down.cleared() == 0,
			"Gollux is going down as the clock runs out")
	for i in 60:
		down.advance(Encounter.DEATH / 30.0)
	_check(down.finished and down.victory and down.cleared() == 1, "and his depth is won (%d)" % down.cleared())

	# Ended by hand as a body falls: a run counts it, and so does a tile given up -- which is won where
	# the body was its last.
	var run := Encounter.farm(Vector2i(3, 0), "grass")
	run.arm({"damage": 1.0e12})
	run.start()
	run.advance(run.walk_in)
	_check(run.hit() and run.phase == Encounter.Phase.DYING and run.kills() == 0, "a run's body is going down")
	run.stop()
	_check(run.finished and run.victory and run.kills() == 1, "and the run ended there counts it")
	for last: bool in [false, true]:
		var tile := _standing([], {"damage": 1.0e12}, 1.0)
		if last:
			_on_last(tile, 1.0)
		var before := tile.kills()
		tile.hit()
		tile.give_up()
		_check(tile.finished and tile.victory == last and tile.kills() == before + 1,
				"a tile given up as a body falls counts it, and is %s" % ("won" if last else "lost"))
	return true


## `kill_paid` closes a body's account: once a body, after everything it left has gone out -- its finds,
## purse, experience and orb on the land, its rune in the cave -- which `enemy_died` comes too early for.
func _test_a_kill_is_paid_after_its_loot() -> bool:
	var heard: Array = []
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	fight.always_drop = true
	fight.always_orb = true
	fight.loot_rng.seed = WORLD_SEED
	fight.orb_rng.seed = WORLD_SEED
	fight.enemy_died.connect(func(i: int) -> void: heard.append(["died", i]))
	fight.loot_dropped.connect(func(i: int, _item: Item) -> void: heard.append(["left", i]))
	fight.gold_dropped.connect(func(i: int, _amount: float) -> void: heard.append(["left", i]))
	fight.xp_dropped.connect(func(i: int, _amount: int) -> void: heard.append(["left", i]))
	fight.orb_dropped.connect(func(i: int, _orb: String) -> void: heard.append(["left", i]))
	fight.kill_paid.connect(func(i: int) -> void: heard.append(["paid", i]))
	fight.arm({"damage": 1.0e12})
	fight.start()
	_play(fight, 1000)
	_check(fight.finished and fight.victory, "the fight was won")
	_paid_in_order(heard, fight.enemies, 4, "a tile's body")

	var runes: Array = []
	var down := Encounter.for_dungeon()
	down.runes_drop = true
	down.loot_rng.seed = WORLD_SEED
	down.enemy_died.connect(func(i: int) -> void: runes.append(["died", i]))
	down.rune_dropped.connect(func(i: int, _rune: String) -> void: runes.append(["left", i]))
	down.kill_paid.connect(func(i: int) -> void: runes.append(["paid", i]))
	down.arm({"damage": 1.0e15})
	down.start()
	while down.cleared() == 0 and not down.finished:
		down.advance(down.walk_in)
		down.hit()
		down.advance(Encounter.DEATH)
	_check(down.cleared() == 1 and ["left", down.enemies - 1] in runes, "Gollux fell and left his rune")
	_paid_in_order(runes, down.enemies, 0, "a floor's body")
	return true


## What the tile panel says a modifier pays is what the fight adds for it, tier by tier, and in a
## world under Wild Tiles as in one that is not.
func _test_the_panel_says_what_a_tile_pays() -> bool:
	var here := Vector2i(4, 6)
	var paid_in := {"drop_rate": "drop_rate", "item_rarity": "item_rarity", "gold_find": "gold_find", "xp": "xp_more"}
	for wild: bool in [false, true]:
		var worn: Array = [Curses.effect(Curses.WILD_TILES)] if wild else []
		var bare := Encounter.for_tile(here, "grass", "plain")
		bare.wear(worn)
		bare.arm({})
		for id: String in TileMods.MODS:
			for tier: int in [1, 2]:
				var listed: Array = []
				listed.resize(tier)
				listed.fill(id)
				var fight := Encounter.for_tile(here, "grass", "plain", false, listed)
				fight.wear(worn)
				fight.arm({})
				var written := {}
				for part: String in TileMods.describe(id, tier, wild)[2].split(", ", false):
					written[part.get_slice("% ", 1)] = float(part.get_slice("%", 0).trim_prefix("+"))
				for key: String in TileMods.PAYS:
					var pays := float(fight.get(paid_in[key])) - float(bare.get(paid_in[key]))
					_check(is_equal_approx(float(written.get(TileMods.PAYS[key], 0.0)), pays),
							"%s at tier %d%s says the %s the fight pays (%s for %s)" % [id, tier,
							" under Wild Tiles" if wild else "", TileMods.PAYS[key], written, pays])
	# And the lift itself is felt: the same tile says more under the curse.
	_check(TileMods.describe("savage", 1, true)[2] != TileMods.describe("savage", 1)[2], "Wild Tiles is on the panel")
	return true


## The fight names its uniques, effects, stats and tile dials by string, and a string no table has is a
## rule that silently never fires. Read off the source: every one the combat scripts name is one its
## table has, and a tile modifier's dial that a run can lose mid-run is one `forget_mod` undoes.
func _test_the_fight_names_what_the_tables_have() -> bool:
	var effects := {}
	for id: String in UniqueTable.UNIQUES:
		effects[UniqueTable.effect_of(id)] = true
	for id: String in SkillTree.CAPSTONES:
		effects[str(SkillTree.CAPSTONES[id]["effect"])] = true
	var dials := RegEx.create_from_string(r'_dial\("(\w+)", "(\w+)"\)')
	var peaks := RegEx.create_from_string(r'_peak\("(\w+)"\)')
	var worn := RegEx.create_from_string(r'"([\w:]+)" (?:not )?in (?:\w+\.)?effects|effects\.count\("([\w:]+)"\)')
	var seen := [0, 0, 0]
	for file: String in DirAccess.get_files_at("res://Scenes/Combat"):
		if not file.ends_with(".gd"):
			continue
		var source := FileAccess.get_file_as_string("res://Scenes/Combat/" + file)
		for found: RegExMatch in dials.search_all(source):
			seen[0] += 1
			var row: Dictionary = UniqueTable.UNIQUES.get(found.get_string(1), {})
			_check(row.get("ranks", {}).has(found.get_string(2)),
					"%s: %s is a dial some unique has" % [file, found.get_string()])
		for found: RegExMatch in peaks.search_all(source):
			seen[1] += 1
			_check(not UniqueTable.peak_text(found.get_string(1)).is_empty() if UniqueTable.UNIQUES.has(found.get_string(1))
					else false,
					"%s: %s is a unique with a rank IV line" % [file, found.get_string()])
		for found: RegExMatch in worn.search_all(source):
			seen[2] += 1
			var effect := found.get_string(1) + found.get_string(2)
			_check(effects.has(effect), "%s: \"%s\" is an effect some unique or capstone has" % [file, effect])
	_check(seen.min() > 0, "the scripts were read: dials, rank IV lines and effects (%s)" % [seen])

	# What `arm` reads of the player is what `Inventory.stats()` hands over: a stat a piece can carry
	# (`LootTable.STAT_LABELS`), or one of the counts it writes in beside them.
	var encounter := FileAccess.get_file_as_string("res://Scenes/Combat/encounter.gd")
	var handed := Inventory.new().stats()
	var read := RegEx.create_from_string(r'stats\.get\("(\w+)"').search_all(_body_of(encounter, "arm"))
	_check(not read.is_empty(), "arm was read")
	for found: RegExMatch in read:
		var stat := found.get_string(1)
		_check(LootTable.STAT_LABELS.has(stat) or handed.has(stat), "arm reads %s, which the inventory hands it" % stat)

	# A tile modifier's row: every key is a word about the row, what it pays, a factor on the player's
	# numbers, or a dial `_take_mods` takes on -- and one of those on a row a run can carry (`farm`),
	# and so lose as a rune wears off, is one `forget_mod` takes back.
	var quoted := RegEx.create_from_string(r'"(\w+)"')
	var taken := quoted.search_all(_body_of(encounter, "_take_mods")).map(
			func(found: RegExMatch) -> String: return found.get_string(1))
	var undone := quoted.search_all(_body_of(encounter, "forget_mod")).map(
			func(found: RegExMatch) -> String: return found.get_string(1))
	_check(not taken.is_empty() and not undone.is_empty(), "the tile's two functions were read")
	var words := ["name", "text", "weight", "farm", "once", "not_with"]
	for id: String in TileMods.MODS:
		var row: Dictionary = TileMods.MODS[id]
		for key: String in row:
			_check(key in words or key in taken or key in TileMods.FACTORS or TileMods.PAYS.has(key),
					"%s's %s is a key the fight reads" % [id, key])
			if bool(row.get("farm", false)) and key in taken:
				_check(key in undone, "%s can wear off a run, and forget_mod takes its %s back" % [id, key])
	return true


## The arena follows the window: turned or resized mid-fight, the backdrop, both fighters and the
## ground they stand on are where a fight opened on that window would have them -- wide, and upright,
## where the fight stands mid-window over its own foot.
func _test_the_arena_follows_the_window() -> bool:
	var window := root.size
	var cell := Vector2i(4, 0)
	# A phone's scale, on a phone's two shapes.
	var scale := 3.0
	var wide := Vector2i(2304, 648)
	var upright := Vector2i(648, 1152)
	root.size = wide
	await process_frame
	var combat: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	root.add_child(combat)
	combat.begin(Encounter.for_tile(cell, "grass"), cell, scale, "plain", 1, "noon")
	await process_frame
	_check(not UITheme.narrow(combat._size(), scale), "the fight opens across a wide window")
	# The land has slid a little by the time the window turns.
	for layer: Sprite2D in combat._layers:
		layer.region_rect.position.x += 10.0 * combat._rates[combat._layers.find(layer)]
	for shape: Vector2i in [upright, wide]:
		var before := combat._size()
		root.size = shape
		await process_frame
		var view := combat._size()
		_check(view != before and UITheme.narrow(view, scale) == (shape == upright),
				"the window is turned %s (%s)" % ["upright" if shape == upright else "on its side", view])
		var fresh: CombatScene = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
		root.add_child(fresh)
		fresh.begin(Encounter.for_tile(cell, "grass"), cell, scale, "plain", 1, "noon")
		await process_frame
		_check(combat._player.position.is_equal_approx(fresh._player.position)
				and combat._player.position.is_equal_approx(Vector2(view.x * CombatScene.PLAYER_X, view.y * combat._ground()))
				and combat._player.scale.is_equal_approx(fresh._player.scale),
				"the hero stands where and as tall as that window has him (%s, %s)" % [combat._player.position,
						combat._player.scale])
		_check(is_equal_approx(combat._enemy.position.y, fresh._enemy.position.y)
				and combat._enemy.scale.is_equal_approx(fresh._enemy.scale) and combat._enemy_scale == combat._enemy.scale,
				"and so does the enemy (%s, %s)" % [combat._enemy.position, combat._enemy.scale])
		var is_layer := func(node: Node) -> bool: return node is Sprite2D
		var laid: Array = combat._arena.get_children().filter(is_layer)
		var wanted: Array = fresh._arena.get_children().filter(is_layer)
		_check(laid.size() == wanted.size() and is_equal_approx(combat._pixel, fresh._pixel),
				"every layer is there, on one grid")
		for at in mini(laid.size(), wanted.size()):
			var layer: Sprite2D = laid[at]
			var want: Sprite2D = wanted[at]
			_check(layer.position.is_equal_approx(want.position) and layer.scale.is_equal_approx(want.scale),
					"layer %d covers the window as a fresh one does (%s, %s)" % [at, layer.position, layer.scale])
			# Short of the window's foot it has its own rows under it, and in step with it.
			var under: Sprite2D = layer.get_child(0) if layer.get_child_count() > 0 else null
			var short := want.get_child_count() > 0
			_check((under != null and under.visible) == short,
					"layer %d is filled in under its foot only where it stops short" % at)
			if short and under != null:
				_check(is_equal_approx(under.region_rect.size.y, (want.get_child(0) as Sprite2D).region_rect.size.y)
						and under.region_rect.position.x == layer.region_rect.position.x,
						"to the window's foot, and sliding with it")
		fresh.queue_free()
		await process_frame
	combat.queue_free()
	root.size = window
	await process_frame
	return true
