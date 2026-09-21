extends "res://tests/harness.gd"
## Prints what each tile modifier (`TileMods`) and each world curse (`Curses`) costs the player on the
## first ring past the second ice wall, and what it pays, so their numbers can be read rather than
## guessed at. Nothing is asserted and nothing is saved.
##
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/balance_mods.gd
##
## Deliberately not named `test_*`: `tests/run_all.py` picks those up, and a table is not a verdict.
##
## The measure is the damage a click needs. For each clicking speed the plain tile is played with more
## and more damage until it is won with `SPARE` seconds in hand, and then every modifier is played the
## same way: "x1.40" means the tile wants 40% more damage than the plain one to be won as comfortably.
## The defence is a farmed set's at the tile's level, so the ones that cut it have something to cut. Beside it, what
## the won fight paid against the plain one -- gold and experience as played, gear as the chance a body
## leaves any, which is what the drop rate moves.

## The first ring past the second wall, where tile modifiers begin.
const CELL := Vector2i(MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP + 2, 0)
const ENV := "grass"
const CLICKS := [3.0, 5.0, 7.0]
## Seconds a won fight has to have left to count as won comfortably.
const SPARE := 3.0
## How many times a tile is played at one damage, the dodge falling differently in each.
const TAKES := 5
## What the player stands up in: a whole set of this rarity farmed at the tile's own level, the first
## piece the table names for each socket -- its defence and its weapon's own swing. Only the damage is
## the table's to move, so the modifiers that cut a defence have a real one to cut.
const RARITY := ItemRarity.Rarity.RARE

var _worn := {}


func _run() -> void:
	_worn = _farmed(MapBuilder.level_of(CELL)).totals({}, {})
	# The damage is the table's to move, and a crit is a coin toss that would make one played fight
	# say nothing about the next: the measure is of the tile, so the blows are all plain ones.
	for stat: String in ["damage", "crit_chance", "crit_damage"]:
		_worn.erase(stat)
	var probe := _fight([], [], 1.0)
	var blow := Encounter.hit_of(probe.lineup[0], CELL)
	print("A common's blow here is %.1f s of clock, %.1f s after this set's armour and block, dodged %d%% of the time"
			% [blow, probe.taken(blow), roundi(probe.dodge_chance() * 100.0)])
	print("Worn, a farmed %s set at level %d: %s" % [ItemRarity.NAMES[RARITY], MapBuilder.level_of(CELL), _worn])
	print("Tile modifiers and curses on %s (%d walls inside), %s, won with %s s in hand"
			% [CELL, Encounter.walls_inside(CELL), ENV, SPARE])
	print("Damage wanted against the plain tile's, at %s clicks a second; then what a won fight pays against it." % [CLICKS])
	var plain := {}
	for clicks: float in CLICKS:
		plain[clicks] = _damage_wanted([], [], clicks)
	var paid := _payout([], [], float(plain[CLICKS[1]]))
	print("%-16s %s   gold %s  xp %d  gear %.2f%% a body" % ["plain", _row(plain, plain),
			BigNumber.format(paid["gold"]), paid["xp"], paid["gear"] * 100.0])
	print("-- tile modifiers")
	for id: String in TileMods.MODS:
		_line(str(TileMods.MODS[id]["name"]), [id], [], plain, paid)
	print("-- curses (the ones a tile fight feels)")
	for id: String in Curses.CURSES:
		_line(str(Curses.CURSES[id]["name"]), [], [id], plain, paid)
	quit()


func _line(label: String, mods: Array, curses: Array, plain: Dictionary, plain_paid: Dictionary) -> void:
	var wanted := {}
	for clicks: float in CLICKS:
		wanted[clicks] = _damage_wanted(mods, curses, clicks)
	var paid := _payout(mods, curses, float(wanted[CLICKS[1]]))
	print("%-16s %s   gold x%.2f  xp x%.2f  gear x%.2f" % [label, _row(wanted, plain),
			paid["gold"] / plain_paid["gold"], float(paid["xp"]) / plain_paid["xp"],
			paid["gear"] / plain_paid["gear"]])


func _row(wanted: Dictionary, plain: Dictionary) -> String:
	var cells := PackedStringArray()
	for clicks: float in CLICKS:
		cells.append("x%.2f" % (float(wanted[clicks]) / float(plain[clicks])))
	return "  ".join(cells)


## The stats a curse's own pay adds, so a cursed row is paid what the world would pay it.
func _stats(curses: Array, damage: float) -> Dictionary:
	var stats := _worn.duplicate()
	stats["damage"] = damage
	for id: String in curses:
		var pays: Dictionary = Curses.CURSES[id].get("stats", {})
		for stat: String in pays:
			stats[stat] = float(stats.get(stat, 0.0)) + float(pays[stat])
	return stats


func _fight(mods: Array, curses: Array, damage: float, take := 0) -> Encounter:
	var fight := Encounter.for_tile(CELL, ENV, "plain", false, mods)
	fight.strikes = true
	fight.crit_rng.seed = WORLD_SEED + take
	fight.loot_rng.seed = WORLD_SEED
	fight.wear(curses.map(Curses.effect))
	fight.arm(_stats(curses, damage))
	return fight


func _played(fight: Encounter, clicks: float) -> Encounter:
	fight.start()
	var step := 1.0 / 60.0
	var owed := 0.0
	while not fight.finished:
		fight.advance(step)
		owed += step * clicks
		while owed >= 1.0:
			owed -= 1.0
			fight.hit()
	return fight


## The least damage a click needs for the tile to be won with `SPARE` seconds left, by bisection.
func _damage_wanted(mods: Array, curses: Array, clicks: float) -> float:
	var low := 1.0
	var high := Encounter.base_hp(CELL) * 64.0
	for step in 24:
		var mid := sqrt(low * high)
		# What is left of chance is the dodge, so the tile is played TAKES times and has to be won
		# comfortably in most of them.
		var won := 0
		for take in TAKES:
			var fight := _played(_fight(mods, curses, mid, take), clicks)
			won += 1 if fight.victory and fight.time_left >= SPARE else 0
		if won * 2 > TAKES:
			high = mid
		else:
			low = mid
	return high


## What the won fight paid: the purse and the experience as played, and the chance a common body of
## this lineup leaves gear, which is what the fight's drop rate comes to.
func _payout(mods: Array, curses: Array, damage: float) -> Dictionary:
	var fight := _played(_fight(mods, curses, damage * 4.0), 7.0)
	return {"gold": maxf(fight.gold, 0.001), "xp": maxi(fight.xp, 1),
			"gear": maxf(LootTable.chance_for(fight.lineup[0], fight._gear_rate())
					* (0.0 if "gilded" in mods else 1.0), 0.00001)}


## test_combat's `_farmed`: the same pieces at the same level, carrying the modifiers a rarity buys.
func _farmed(level: int) -> Equipment:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["farmed", level, RARITY, 0])
	var gear := Equipment.new()
	for socket: Equipment.Socket in Equipment.sockets():
		for type in LootTable.items():
			if LootTable.slot_of(type) != Equipment.TAKES[socket]:
				continue
			var item := Item.new()
			item.type = type
			item.rarity = RARITY
			item.level = level
			item.stats = Item.scaled_stats(type, level)
			var band: Array = ItemRarity.MOD_COUNT[RARITY]
			item.mods = ModifierTable.roll(type, rng.randi_range(band[0], band[1]), rng, level)
			gear.equip(socket, item)
			break
	return gear
