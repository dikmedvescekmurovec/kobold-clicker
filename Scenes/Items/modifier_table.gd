class_name ModifierTable
extends RefCounted
## What an item can carry on top of what it is.
##
## Three shapes of modifier, and each is let onto a piece by a different rule.
##
## A PERCENT one scales a stat the item already has, so it needs that *base* stat: a boot has no
## damage to increase. A FLAT one adds a stat outright, so it needs only that the piece be allowed to
## carry it -- LootTable's `affixes` -- which is how a ring with no health of its own rolls "+8
## Health". A PLAYER one is a buff to the player rather than the item, and can land on anything; the
## pool of those is deliberately small and every one of them names something this game already has,
## rather than inventing a currency or a resistance for a system nobody has written.
##
## Which modifiers an item can roll is decided by building the list of candidates first and drawing
## from that, never by rolling and checking: a modifier the item cannot carry is never a candidate,
## so there is no check to forget and no reroll loop that can spin.
##
## Every value is a whole number on purpose. It means one randi_range per modifier, it means the save
## file holds 14 rather than 14.0, and it means a test can compare a round-tripped item with == .
## Nothing here wants half a percent.

enum Kind {
	PERCENT,  ## scales a base stat the item has: "+14% increased Damage"
	FLAT,     ## adds a stat the item is allowed to carry: "+2 Damage"
	PLAYER,   ## a buff to the player, and so at home on any item at all: "+6% item find"
}

## id -> what it does, what it touches, the range it rolls in, and how often it is drawn against the
## others in the same pool. PLAYER modifiers carry their own line because each is a sentence about a
## different thing; the rest build theirs from the stat's label, so a stat renamed is renamed
## everywhere. Percent ranges are wider where the stat is itself a percentage -- a fifth of a 5% crit
## chance is a rounding error -- and a flat roll is worth roughly two percent rolls on the same stat.
const MODS := {
	"increased_damage": {"kind": Kind.PERCENT, "stat": "damage", "range": [8, 20], "weight": 10},
	# A point of damage is a lot now that a sword carries one: the whole curve starts at a click for 1
	# and this is the modifier that can double it, so its band is the tightest in the table.
	"added_damage": {"kind": Kind.FLAT, "stat": "damage", "range": [1, 2], "weight": 10},
	"increased_crit": {"kind": Kind.PERCENT, "stat": "crit_chance", "range": [10, 30], "weight": 10},
	"added_crit": {"kind": Kind.FLAT, "stat": "crit_chance", "range": [1, 4], "weight": 10},
	"increased_attack_speed": {"kind": Kind.PERCENT, "stat": "attack_speed", "range": [5, 12], "weight": 10},
	"increased_armor": {"kind": Kind.PERCENT, "stat": "armor", "range": [8, 20], "weight": 10},
	"added_armor": {"kind": Kind.FLAT, "stat": "armor", "range": [2, 6], "weight": 10},
	"increased_block": {"kind": Kind.PERCENT, "stat": "block_chance", "range": [10, 25], "weight": 10},
	"added_block": {"kind": Kind.FLAT, "stat": "block_chance", "range": [2, 5], "weight": 10},
	"increased_health": {"kind": Kind.PERCENT, "stat": "health", "range": [8, 20], "weight": 10},
	"added_health": {"kind": Kind.FLAT, "stat": "health", "range": [5, 15], "weight": 10},
	"increased_move_speed": {"kind": Kind.PERCENT, "stat": "move_speed", "range": [6, 15], "weight": 10},
	"added_move_speed": {"kind": Kind.FLAT, "stat": "move_speed", "range": [2, 5], "weight": 10},
	"increased_dodge": {"kind": Kind.PERCENT, "stat": "dodge_chance", "range": [10, 25], "weight": 10},
	"added_dodge": {"kind": Kind.FLAT, "stat": "dodge_chance", "range": [1, 3], "weight": 10},
	"increased_crit_damage": {"kind": Kind.PERCENT, "stat": "crit_damage", "range": [8, 20], "weight": 10},
	"added_crit_damage": {"kind": Kind.FLAT, "stat": "crit_damage", "range": [5, 15], "weight": 10},
	"increased_energy_shield": {"kind": Kind.PERCENT, "stat": "energy_shield", "range": [8, 20], "weight": 10},
	"added_energy_shield": {"kind": Kind.FLAT, "stat": "energy_shield", "range": [2, 8], "weight": 10},
	"increased_health_regen": {"kind": Kind.PERCENT, "stat": "health_regen", "range": [8, 20], "weight": 10},
	"added_health_regen": {"kind": Kind.FLAT, "stat": "health_regen", "range": [1, 3], "weight": 10},
	# The resistances, the attributes and what a hit gives back are all flat-only: each is a quantity
	# you add up across the set rather than a thing an item has more or less of, so "+35% to Fire
	# Resistance" is the whole idea and "+14% increased Fire Resistance" would be a percentage of a
	# percentage. That they have no PERCENT form is also what lets them sit in `affixes` on pieces
	# that show none of them.
	"added_fire_resist": {"kind": Kind.FLAT, "stat": "fire_resist", "range": [5, 15], "weight": 8},
	"added_cold_resist": {"kind": Kind.FLAT, "stat": "cold_resist", "range": [5, 15], "weight": 8},
	"added_lightning_resist": {"kind": Kind.FLAT, "stat": "lightning_resist", "range": [5, 15], "weight": 8},
	"added_leech": {"kind": Kind.FLAT, "stat": "leech", "range": [1, 3], "weight": 6},
	"added_life_on_hit": {"kind": Kind.FLAT, "stat": "life_on_hit", "range": [1, 4], "weight": 8},
	"added_strength": {"kind": Kind.FLAT, "stat": "strength", "range": [2, 8], "weight": 8},
	"added_dexterity": {"kind": Kind.FLAT, "stat": "dexterity", "range": [2, 8], "weight": 8},
	"added_intelligence": {"kind": Kind.FLAT, "stat": "intelligence", "range": [2, 8], "weight": 8},
	# The player-wide four. Each points at something that exists: LootTable.chance_for,
	# Encounter.seconds, PlayerToken.SECONDS_PER_TILE and ItemRarity.TIER_WEIGHTS. The clock stops at
	# four seconds because four on a thirty-second fight is already a noticeably easier one.
	"item_find": {"kind": Kind.PLAYER, "line": "+%d%% item find", "range": [3, 10], "weight": 4},
	"fight_clock": {"kind": Kind.PLAYER, "line": "+%ds on the fight clock", "range": [1, 4], "weight": 4},
	"walk_speed": {"kind": Kind.PLAYER, "line": "+%d%% walk speed", "range": [3, 8], "weight": 4},
	"item_rarity": {"kind": Kind.PLAYER, "line": "+%d%% better item rarity", "range": [3, 10], "weight": 2},
}

## No modifier can be drawn without a stat to hang on, so attack speed has no flat form: "+0.2
## attacks a second" would be the one fraction in the file.


## Every modifier this piece could carry: the player-wide ones, which fit anything, plus the ones
## that name a stat it actually has. This list is the whole rule -- an impossible modifier is never
## in it, so nothing downstream has to know it was impossible.
static func pool_for(item_type: String) -> PackedStringArray:
	var pool := PackedStringArray()
	for id: String in MODS:
		var mod: Dictionary = MODS[id]
		var fits := false
		match mod["kind"]:
			Kind.PLAYER:
				fits = true
			Kind.PERCENT:
				fits = LootTable.has_stat(item_type, mod["stat"])
			_:
				fits = LootTable.can_roll(item_type, mod["stat"])
		if fits:
			pool.append(id)
	return pool


## The modifiers on one item, as [{"id": ..., "value": ...}] in the order they were drawn. Drawn
## without replacement, so a modifier never appears twice on one piece -- though "+2 Damage" and
## "+14% increased Damage" are two different draws doing two different things, which is the point of
## having both shapes. A pool too thin to fill the count gives everything it has, which cannot happen
## with today's tables and is held to that by a test.
static func roll(item_type: String, count: int, rng: RandomNumberGenerator,
		level := 1) -> Array[Dictionary]:
	var pool := pool_for(item_type)
	var rolled: Array[Dictionary] = []
	for i in count:
		if pool.is_empty():
			break
		var id := _weighted(pool, rng)
		pool.remove_at(pool.find(id))
		rolled.append({"id": id, "value": reroll_value(id, rng, level)})
	return rolled


## What one modifier rolls between at this level. Its own function because three callers need the
## same answer and any two of them disagreeing would be invisible: `roll` draws a new modifier here,
## `reroll_value` draws a fresh number for one already on a piece, and a test reads the band to check
## that a divined value stayed inside it.
static func band_for(id: String, level: int) -> Array:
	var entry: Dictionary = MODS[id]
	var band: Array = entry["range"]
	var low := int(band[0])
	var high := int(band[1])
	match entry["kind"]:
		Kind.FLAT:
			# An amount of a stat, so it grows exactly the way that stat's own numbers do.
			low = maxi(1, roundi(LootTable.scale(entry["stat"], float(low), level)))
			high = maxi(1, roundi(LootTable.scale(entry["stat"], float(high), level)))
		Kind.PERCENT:
			# A percentage of a stat that has already grown. It takes the multiplier and not the
			# flat step, which is sized for the stat itself rather than for a percentage of it.
			low = maxi(1, roundi(low * pow(LootTable.LEVEL_GROWTH, maxi(level - 1, 0))))
			high = maxi(1, roundi(high * pow(LootTable.LEVEL_GROWTH, maxi(level - 1, 0))))
		_:
			# PLAYER: a buff to the player rather than a stat on the piece, so LEVEL_FLAT has
			# nothing to say about it and it keeps the band as written. One of them is seconds on
			# the fight clock, which scaled would eventually delete the only way to lose.
			pass
	return [low, high]


## A fresh number for one modifier, in the band its level allows. What an Orb of Divine spends
## itself on: the id stays and only the roll moves, which is why it is drawn here rather than by
## rolling the modifier again from scratch.
static func reroll_value(id: String, rng: RandomNumberGenerator, level := 1) -> int:
	var band := band_for(id, level)
	return rng.randi_range(int(band[0]), int(band[1]))


## One more modifier for a piece that already carries some: drawn from what it could take, less what
## it has. Empty when there is nothing left to give it, which today's tables cannot produce and a
## test holds them to.
##
## Augmentation and Exalted are both this -- they differ only in which pieces they are offered on,
## which is `OrbTable.can_apply`'s business and not this function's.
static func add_one(item_type: String, existing: Array[Dictionary], rng: RandomNumberGenerator,
		level := 1) -> Dictionary:
	var held := {}
	for mod in existing:
		held[str(mod.get("id", ""))] = true
	var pool := PackedStringArray()
	for id in pool_for(item_type):
		if not held.has(id):
			pool.append(id)
	if pool.is_empty():
		return {}
	var id := _weighted(pool, rng)
	return {"id": id, "value": reroll_value(id, rng, level)}


## One draw from what is left, by weight -- the same walk LootTable and EnemyRoster use.
static func _weighted(pool: PackedStringArray, rng: RandomNumberGenerator) -> String:
	var total := 0
	for id in pool:
		total += int(MODS[id]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for id in pool:
		pick -= int(MODS[id]["weight"])
		if pick < 0:
			return id
	return pool[0]


## A rolled modifier written for a person.
static func line(mod: Dictionary) -> String:
	var id: String = mod.get("id", "")
	if not MODS.has(id):
		return ""
	var entry: Dictionary = MODS[id]
	var value := int(mod.get("value", 0))
	match entry["kind"]:
		Kind.PLAYER:
			return entry["line"] % value
		Kind.PERCENT:
			return "+%d%% increased %s" % [value, LootTable.STAT_LABELS[entry["stat"]]]
		_:
			# A flat roll on a stat that is itself a percentage adds percentage points, and has to
			# say so: "+10% Fire Resistance", never "+10 Fire Resistance".
			var stat: String = entry["stat"]
			var unit := "%" if stat in LootTable.PERCENT_STATS else ""
			return "+%d%s %s" % [value, unit, LootTable.STAT_LABELS[stat]]
