class_name ModifierTable
extends RefCounted
## What an item can carry on top of what it is.
##
## Four shapes of modifier, and each is let onto a piece by a different rule.
##
## A PERCENT one scales a stat the item already has, so it needs that *base* stat: a boot has no
## damage to increase. A FLAT one adds a stat outright, so it needs only that the piece be allowed to
## carry it -- LootTable's `affixes` -- which is how a ring with no health of its own rolls "+8
## Health". A GLOBAL one is a percentage of what the *whole set* is worth rather than of anything the
## piece has, so it needs neither: LootTable's `globals` says which pieces may carry one, which today
## is the jewellery and nothing else. A PLAYER one is a buff to the player rather than the item, and
## can land on anything; the pool of those is deliberately small and every one of them names
## something this game already has, rather than inventing a currency for a system nobody has written.
##
## Where a modifier is *applied* follows from that. A PERCENT and a FLAT one are folded into the
## piece by `Item.effective_stats`, because they are numbers the piece is worth. A GLOBAL one is
## folded in once by `Equipment.totals`, after every worn piece has been added up -- a ring has no
## damage of its own for "+14% increased Damage" to scale, and the sword's is exactly what it means.
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
	GLOBAL,   ## scales what the whole set is worth, not the piece: a ring's "+14% increased Damage"
	PLAYER,   ## a buff to the player, and so at home on any item at all: "+4s on the fight clock"
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
	"added_damage": {"kind": Kind.FLAT, "stat": "damage", "range": [1, 2], "weight": 10,
		"level_flat": 0.25},
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
	# What a body leaves, which is a stat now rather than a player-wide sentence: the Gold Ring shows
	# it and anything allowed to carry it rolls this.
	"added_drop_rate": {"kind": Kind.FLAT, "stat": "drop_rate", "range": [3, 10], "weight": 4},
	# The jewellery's own finder, drawn as often as drop rate and worth two and a half times as much a
	# roll. Drop rate is the broad one -- it lifts gear, uniques, orbs and gold alike -- and item
	# rarity only lifts the weights a piece of gear rolls its rarity on, so the narrow one carries the
	# bigger number.
	"added_item_rarity": {"kind": Kind.FLAT, "stat": "item_rarity", "range": [10, 25], "weight": 4},
	# The Gold Amulet's own stat, and the rarest roll in the table. Its band is written flat
	# (`level_flat` 0) rather than growing a point a level with the stat: it was sized for The Tithe,
	# which is a unique and a percentage of a purse that is already exponential in the walk.
	"added_gold_find": {"kind": Kind.FLAT, "stat": "gold_find", "range": [20, 40], "weight": 1,
		"level_flat": 0.0},
	# The globals, and the jewellery is the only place they land. A percentage of the whole set is
	# worth more than a percentage of one piece, so increased damage rolls the smaller of the two
	# bands here -- the frontier is beaten with what the set adds up to, and test_combat's edge-fight
	# line is where that band is actually read off. Attack speed has no flat form (see below), so
	# this is the whole of what a ring can do to it.
	"global_increased_damage": {"kind": Kind.GLOBAL, "stat": "damage", "range": [5, 12], "weight": 8},
	"global_increased_attack_speed": {"kind": Kind.GLOBAL, "stat": "attack_speed", "range": [5, 12], "weight": 8},
	# The player-wide three, and none of them is read yet. Each points at something that exists:
	# Encounter.seconds, PlayerToken.SECONDS_PER_TILE and ItemRarity.TIER_WEIGHTS. The clock stops at
	# four seconds because four on a thirty-second fight is already a noticeably easier one.
	#
	# There were four: `item_find` was the player-wide way of saying what `drop_rate` now says as a
	# stat, and one idea under two names is how the two would come to disagree.
	"fight_clock": {"kind": Kind.PLAYER, "line": "+%ds on the fight clock", "range": [1, 4], "weight": 4},
	"walk_speed": {"kind": Kind.PLAYER, "line": "+%d%% walk speed", "range": [3, 8], "weight": 4},
	"item_rarity": {"kind": Kind.PLAYER, "line": "+%d%% better item rarity", "range": [3, 10], "weight": 2},
}

## No modifier can be drawn without a stat to hang on, so attack speed has no flat form: "+0.2
## attacks a second" would be the one fraction in the file.

## The modifiers no item can roll today, and that is on purpose rather than an oversight. The
## resistances came off every piece when it became clear nothing can hurt the player, so there is
## nothing for them to defend against -- but a resistance is a system half-written rather than a bad
## idea, and the table keeps them so that putting them back is a word on an item and nothing else.
## Written down here because "unreachable" is exactly what a test would otherwise fail on, and a
## silently unreachable modifier and a deliberately dormant one have to be told apart by name.
const DORMANT := ["added_fire_resist", "added_cold_resist", "added_lightning_resist"]

## The modifiers no pool holds because only a unique's row may name them (`UniqueTable.UNIQUES`). Named
## for the reason the dormant ones are: a test has to tell this from a modifier nothing can reach.
##
## Empty today. `added_gold_find` was the one, and it is in the Gold Amulet's pool now that the amulet
## shows gold find as a base stat -- a FLAT modifier is let on by `can_roll`, which asks for a base
## stat *or* an affix, and there is no third answer that would hold one back from a piece that has the
## stat outright. The list stays for the next row that wants it.
const UNIQUE_ONLY: Array[String] = []


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
			Kind.GLOBAL:
				fits = LootTable.can_globalize(item_type, mod["stat"])
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
			# An amount of a stat, so it grows the way that stat's own numbers do -- unless the entry
			# says otherwise. `level_flat` is there for the one stat whose per-level step was sized for
			# the piece that has it as a base stat: a whole point of damage a level is right for the
			# sword, which is where a click's damage comes from, and four times too much once the
			# jewellery can add a modifier's worth of damage on every finger. Only the absolute step is
			# the entry's; the multiplier is the stat's either way.
			# ponytail: a band stays whole ints, which pass int64 near item level 370 -- far past
			# where a monster's health would have; retype the pair to float then.
			var step: float = float(entry.get("level_flat",
					LootTable.LEVEL_FLAT.get(entry["stat"], 0.0)))
			low = maxi(1, roundi(LootTable.scale(entry["stat"], float(low), level, step)))
			high = maxi(1, roundi(LootTable.scale(entry["stat"], float(high), level, step)))
		Kind.PERCENT, Kind.GLOBAL:
			# A percentage of a stat that has already grown -- the piece's own or the whole set's,
			# which is the same arithmetic. It takes the multiplier and not the flat step, which
			# is sized for the stat itself rather than for a percentage of it.
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


## A rolled value carried to another level: as far up `to_level`'s band as it stood in `from_level`'s.
## What an heirloom's modifiers go through when the world ends (`Item.transcend`). A value outside
## its band -- a line held fast while the level moved sits under it -- is held to the band's
## ends, and a band of one number counts as its top.
static func rescaled(id: String, value: int, from_level: int, to_level: int) -> int:
	var from := band_for(id, from_level)
	var to := band_for(id, to_level)
	var span := float(int(from[1]) - int(from[0]))
	var place := 1.0 if span <= 0.0 else clampf((value - int(from[0])) / span, 0.0, 1.0)
	return roundi(lerpf(float(to[0]), float(to[1]), place))


## One more modifier for a piece that already carries some: drawn from what it could take, less what
## it has. Empty when there is nothing left to give it, which today's tables cannot produce and a
## test holds them to.
##
## Exalted is this -- which pieces it is offered on is `OrbTable.can_apply`'s business and not this
## function's.
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
	return _written(id, _amount(id, int(mod.get("value", 0))))


## A modifier written with the band it rolls in at `level` in the number's place: "+8-20% increased
## Damage". What the fortuneteller reads off a piece; the same sentence `line` writes, so the two
## cannot come to spell a modifier differently.
static func band_line(id: String, level: int) -> String:
	if not MODS.has(id):
		return ""
	var band := band_for(id, level)
	var low := _amount(id, int(band[0]))
	var high := _amount(id, int(band[1]))
	return _written(id, low if low == high else "%s-%s" % [low, high])


## A modifier's number as it is written. A flat one is the one number here that grows with the
## level, so it is written the way every other growing quantity is (`BigNumber`) rather than spelled
## out to twenty digits.
static func _amount(id: String, value: int) -> String:
	return BigNumber.format(value) if MODS[id]["kind"] == Kind.FLAT else str(value)


static func _written(id: String, amount: String) -> String:
	var entry: Dictionary = MODS[id]
	match entry["kind"]:
		Kind.PLAYER:
			return str(entry["line"]).replace("%d", "%s") % amount
		Kind.PERCENT, Kind.GLOBAL:
			# The same sentence for both, and honestly so: with one weapon between them, a sword's
			# increased damage and a ring's are the same claim about the same number.
			return "+%s%% increased %s" % [amount, LootTable.STAT_LABELS[entry["stat"]]]
		_:
			# A flat roll on a stat that is itself a percentage adds percentage points, and has to
			# say so: "+10% Fire Resistance", never "+10 Fire Resistance".
			var stat: String = entry["stat"]
			var unit := "%" if stat in LootTable.PERCENT_STATS else ""
			return "+%s%s %s" % [amount, unit, LootTable.STAT_LABELS[stat]]
