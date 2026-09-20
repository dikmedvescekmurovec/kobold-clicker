extends "res://tests/harness.gd"
## The ice wall balance table. Prints only, asserts nothing: run it before and after moving
## `Encounter.WALL_HP`, `HP_GROWTH`, `LootTable.LEVEL_GROWTH` or a drop rate.
##
## Two answers. First the wall against whole reference sets (the test suite's `_farmed` sets, median
## of seven) by rarity, item level and player level: what has to be worn. Then a fresh player played
## out to the wall with the real `Encounter` and the real drops, at a steady click rate: how many
## kills and how long it takes to be wearing it.
##
## ponytail: the played-out player walks one straight line of grass, puts every point in Power, wears
## whatever raises wall damage and ignores uniques, orbs, vendors and the smith -- so its kill counts
## are a ceiling on the farming, not a forecast. Teach it a system when that system is being tuned.

const RUNS := 15
const RATES: Array[float] = [3.0, 5.0, 7.0]
## Kills farmed between two looks at the next tile.
const BATCH := 25
## A run that has not got through by now never will: drops top out at the farmed tile's level.
const GIVE_UP := 60000
const WALL_RING := MapBuilder.START_LAND_RADIUS + 1
## What `Encounter.WALL_HP` could be instead, each played out at SWEEP_RATE clicks a second. A wall
## Giant Slayer did nothing to is the row at twice the figure. Past 50 it is a cliff: the Power tree is
## full by level 24 and drops top out at the farmed tile's level, so only rarity is left to grow.
const SWEEP: Array[float] = [6.0, 25.0, 33.0, 35.0, 50.0, 60.0]
const SWEEP_RATE := 5.0
const SWEEP_RUNS := 7
## Kills at which the player walking on to the second wall is looked at.
const NEXT_STOPS: Array[int] = [5000, 20000, 60000]


func _run() -> void:
	var wall := Encounter.for_wall(Vector2i(WALL_RING, 0))
	var spare := wall.seconds - Encounter.WALK_IN - Encounter.DEATH
	print("The wall on ring %d: %s health in %.1f s, so %.0f damage a second. Tile level inside it: %d"
			% [WALL_RING, BigNumber.format(wall.hp), spare, wall.hp / spare,
			MapBuilder.level_of(Vector2i(WALL_RING - 1, 0))])
	_print_sets()
	for rate in RATES:
		_print_played(rate)
	_print_sweep()
	_print_next_wall()
	quit()


## The same player kept going to the wall after: where they are, and what that wall wants of them,
## at a few stops along the way. Nothing past the first wall is theirs until it falls.
func _print_next_wall() -> void:
	var ring := WALL_RING + MapBuilder.WALL_STEP
	var wall := _wall(Encounter.WALL_HP, ring)
	print("
The wall after, on ring %d: %s health. One player at %.0f clicks a second, all the way out"
			% [ring, BigNumber.format(wall.hp), SWEEP_RATE])
	print("    kills  minutes  level  ring held  gear level  rares  elites  clicks/s that wall wants")
	for stop: int in NEXT_STOPS:
		var run := _play_out(SWEEP_RATE, 0, Encounter.WALL_HP, ring, stop)
		print("  %7d  %7.0f  %5d  %9d  %10.1f  %5d  %6d  %s" % [run["kills"], run["minutes"], run["level"],
				run["ring"], run["gear_level"], run["rares"], run["elites"],
				"through" if run["won"] else "%.1f" % run["needs"]])


func _print_sweep() -> void:
	print("
Other walls at %.0f clicks a second, medians of %d runs" % [SWEEP_RATE, SWEEP_RUNS])
	print("  WALL_HP   through    kills  minutes  level  rares  elites")
	for wall_hp in SWEEP:
		var done := []
		for take in SWEEP_RUNS:
			var run := _play_out(SWEEP_RATE, take, wall_hp)
			if run["won"]:
				done.append(run)
		var row := "  %7.0f   %d of %d" % [wall_hp, done.size(), SWEEP_RUNS]
		if not done.is_empty():
			for key: String in ["kills", "minutes", "level", "rares", "elites"]:
				var values := done.map(func(run: Dictionary) -> float: return float(run[key]))
				values.sort()
				row += "  %7.0f" % values[values.size() / 2]
		print(row)


## The wall with another `WALL_HP`.
func _wall(wall_hp: float, ring := WALL_RING) -> Encounter:
	var fight := Encounter.for_wall(Vector2i(ring, 0))
	fight.health[0] = roundf(fight.health[0] / Encounter.WALL_HP * wall_hp)
	fight.hp = fight.health[0]
	return fight


## Clicks a second the wall wants from a whole set of one rarity and level, all points in Power.
func _print_sets() -> void:
	print("\nClicks a second the wall wants, median of 7 whole sets (item level across, player level down)")
	for rarity: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON,
			ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
		print("  %s, item level      3      4      5      6" % ItemRarity.name_of(rarity))
		for player_level: int in [1, 5, 10, 15, 20]:
			var row := "    player level %2d" % player_level
			for item_level: int in [3, 4, 5, 6]:
				var rates := []
				for take in 7:
					var inv := Inventory.new()
					inv.equipment = _farmed(item_level, rarity, take)
					inv.level = player_level
					_spend_points(inv, 5.0)
					rates.append(_needs(Encounter.for_wall(Vector2i(WALL_RING, 0)), inv))
				rates.sort()
				row += " %6.1f" % rates[3]
			print(row)


func _print_played(rate: float) -> void:
	var runs := []
	for take in RUNS:
		runs.append(_play_out(rate, take))
	var done := runs.filter(func(run: Dictionary) -> bool: return run["won"])
	print("\nA fresh player at %.0f clicks a second: %d of %d runs through the wall" % [rate, done.size(), RUNS])
	if done.is_empty():
		return
	for key: String in ["kills", "farmed", "minutes", "level", "damage", "crit_chance", "crit_damage",
			"attack_speed", "gear_level", "rares", "elites"]:
		var values := done.map(func(run: Dictionary) -> float: return float(run[key]))
		values.sort()
		print("  %-13s median %8.1f   (%.1f to %.1f)" % [key, values[values.size() / 2], values[0], values[-1]])
	var by_ring := PackedFloat64Array()
	by_ring.resize(WALL_RING)
	for run: Dictionary in done:
		for ring in WALL_RING:
			by_ring[ring] += float(run["farm_by_ring"][ring]) / done.size()
	print("  mean kills farmed standing on each ring, 0 to %d: %s" % [WALL_RING - 1,
			", ".join(Array(by_ring).map(func(kills: float) -> String: return "%.0f" % kills))])


## One player from nothing to the far side of the wall: charts a line of tiles outward, farming the
## deepest one it holds whenever the next is out of reach.
func _play_out(rate: float, take: int, wall_hp := Encounter.WALL_HP, last_wall := WALL_RING,
		give_up := GIVE_UP) -> Dictionary:
	var inv := Inventory.new()
	var st := {"kills": 0, "farmed": 0, "seconds": 0.0, "fights": 0, "first_elite": false,
			"farm_by_ring": PackedInt32Array(), "take": take, "won": false}
	st["farm_by_ring"].resize(last_wall)
	var ring := 0
	while st["kills"] < give_up:
		var cell := Vector2i(ring + 1, 0)
		var walled := (ring + 1 - WALL_RING) % MapBuilder.WALL_STEP == 0 and ring + 1 >= WALL_RING
		var next := _wall(wall_hp, ring + 1) if walled else Encounter.for_tile(cell, "grass")
		if _needs(next, inv) <= rate and _fight(next, inv, rate, st):
			ring += 1
			if ring == last_wall:
				st["won"] = true
				break
			continue
		var before: int = st["kills"]
		_fight(Encounter.farm(Vector2i(ring, 0), "grass"), inv, rate, st)
		st["farmed"] += st["kills"] - before
		st["farm_by_ring"][ring] += st["kills"] - before
	var stats := inv.stats()
	var worn := inv.equipment.items()
	var levels := 0.0
	for item: Item in worn:
		levels += item.level
	st["minutes"] = st["seconds"] / 60.0
	st["ring"] = ring
	st["needs"] = _needs(_wall(wall_hp, last_wall), inv)
	st["level"] = inv.level
	st["gear_level"] = levels / maxi(worn.size(), 1)
	st["rares"] = worn.filter(func(item: Item) -> bool: return item.rarity == ItemRarity.Rarity.RARE).size()
	st["elites"] = worn.filter(func(item: Item) -> bool: return item.rarity == ItemRarity.Rarity.ELITE).size()
	for stat: String in ["damage", "crit_chance", "crit_damage", "attack_speed"]:
		st[stat] = float(stats.get(stat, 0.0))
	return st


## Plays one fight at `rate` clicks a second, then banks its experience and wears what it dropped.
func _fight(fight: Encounter, inv: Inventory, rate: float, st: Dictionary) -> bool:
	st["fights"] += 1
	var generators := [fight.loot_rng, fight.crit_rng, fight.roster_rng]
	for i in generators.size():
		generators[i].seed = hash([st["take"], st["fights"], i])
	fight.guarantee_elite = not st["first_elite"]
	var drops := []
	fight.loot_dropped.connect(func(index: int, item: Item) -> void:
		drops.append(item)
		if EnemyRoster.tier_of(fight.lineup[index]) == EnemyRoster.Tier.ELITE:
			st["first_elite"] = true)
	fight.wear(inv.effects())
	fight.arm(inv.stats())
	fight.start()
	var step := 1.0 / rate
	while not fight.finished and not (fight.endless and fight.kills() >= BATCH):
		fight.hit()
		fight.advance(step)
		st["seconds"] += step
	fight.stop()
	st["kills"] += fight.kills()
	inv.add_xp(fight.xp)
	_spend_points(inv, rate)
	for item: Item in drops:
		_wear_if_better(inv, item, rate)
	return fight.victory


## Every free point into Power, each where it does the wall the most harm.
func _spend_points(inv: Inventory, rate: float) -> void:
	while inv.skills.points(inv.level) > 0:
		var best := ""
		var best_worth := -1.0
		for id: String in SkillTree.nodes_of("power"):
			if not inv.skills.can_rank(id, inv.level):
				continue
			inv.skills.ranks[id] = inv.skills.rank_of(id) + 1
			var worth := _wall_dps(inv, rate)
			inv.skills.ranks[id] -= 1
			if inv.skills.ranks[id] == 0:
				inv.skills.ranks.erase(id)
			if worth > best_worth:
				best = id
				best_worth = worth
		if best.is_empty() or not inv.skills.rank_up(best, inv.level):
			return


func _wear_if_better(inv: Inventory, item: Item, rate: float) -> void:
	for socket: Equipment.Socket in inv.equipment.sockets_for(item):
		var before := _wall_dps(inv, rate)
		var worn: Dictionary = inv.equipment.worn.duplicate()
		inv.equipment.equip(socket, item)
		if _wall_dps(inv, rate) > before:
			return
		inv.equipment.worn = worn


## What the player does to the wall in a second at `rate` clicks: the fight's own arithmetic, with a
## crit as its average and the mace's wound open the whole time.
func _wall_dps(inv: Inventory, rate: float) -> float:
	var fight := Encounter.new()
	fight.arm(inv.stats())
	var per_hit := _per_hit(fight) * (2.0 if "giant_slayer" in inv.effects() else 1.0)
	var dps := per_hit * (rate + fight.attack_speed + fight.bleed / 100.0)
	return dps / (0.9 if "execute" in inv.effects() else 1.0)


func _per_hit(fight: Encounter) -> float:
	return fight.damage * (1.0 + fight.crit_chance / 100.0 * fight.crit_damage / 100.0)


## Clicks a second `fight` wants of this player: whole blows a body, the weapon's own swings off the top.
func _needs(fight: Encounter, inv: Inventory) -> float:
	var effects := inv.effects()
	fight.arm(inv.stats())
	var spare := fight.seconds - fight.enemies * (Encounter.WALK_IN + Encounter.DEATH)
	var blows := 0.0
	for i in fight.lineup.size():
		var big := EnemyRoster.tier_of(fight.lineup[i]) != EnemyRoster.Tier.COMMON
		var per_hit := _per_hit(fight) * (2.0 if big and "giant_slayer" in effects else 1.0)
		blows += ceilf(fight.health[i] * (0.9 if "execute" in effects else 1.0) / per_hit)
	return blows / spare - fight.attack_speed


## `test_combat._farmed`: one whole set of a rarity at a level, seeded on `take`.
func _farmed(level: int, rarity: ItemRarity.Rarity, take: int) -> Equipment:
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
