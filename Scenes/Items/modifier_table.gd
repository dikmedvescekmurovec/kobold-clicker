class_name ModifierTable
extends RefCounted
## What an item can carry on top of what it is.
##
## Three shapes of modifier, and each is let onto a piece by a different rule.
##
## A PERCENT one scales a stat the item already has, so it needs that *base* stat: a boot has no
## damage to increase. A FLAT one adds a stat outright, so it needs only that the piece be allowed to
## carry it -- LootTable's `affixes` -- which is how a ring with no crit of its own rolls "+2%
## Crit Chance". A GLOBAL one is a percentage of what the *whole set* is worth rather than of anything the
## piece has, so it needs neither: LootTable's `globals` says which pieces may carry one, which today
## is the jewellery and nothing else.
##
## There was a fourth, PLAYER: a sentence about the player that fitted any piece and that nothing
## applied. Two of its three said what a FLAT line already said (move speed, item rarity) and went; the
## third is the fight clock, a FLAT stat any piece may carry (`LootTable.ANY_AFFIXES`). `RENAMED` is
## what a saved one became.
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
}

## id -> what it does, what it touches, the range it rolls in, and how often it is drawn against the
## others in the same pool. Every line is built from the stat's label, so a stat renamed is renamed
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
	"increased_block": {"kind": Kind.PERCENT, "stat": "block", "range": [10, 25], "weight": 10},
	# Block and time on hit are tenths of a second (`LootTable.SECONDS_STATS`): 1-3 is 0.1-0.3s.
	"added_block": {"kind": Kind.FLAT, "stat": "block", "range": [1, 3], "weight": 10},
	"increased_move_speed": {"kind": Kind.PERCENT, "stat": "move_speed", "range": [6, 15], "weight": 10},
	"added_move_speed": {"kind": Kind.FLAT, "stat": "move_speed", "range": [2, 5], "weight": 10},
	"increased_dodge": {"kind": Kind.PERCENT, "stat": "dodge", "range": [8, 20], "weight": 10},
	"added_dodge": {"kind": Kind.FLAT, "stat": "dodge", "range": [2, 6], "weight": 10},
	"increased_crit_damage": {"kind": Kind.PERCENT, "stat": "crit_damage", "range": [8, 20], "weight": 10},
	"added_crit_damage": {"kind": Kind.FLAT, "stat": "crit_damage", "range": [5, 15], "weight": 10},
	# The attributes and what a hit wins back are flat-only: each is a quantity you add up across the
	# set rather than a thing an item has more or less of. That they have no PERCENT form is also what
	# lets them sit in `affixes` on pieces that show none of them.
	"added_time_on_hit": {"kind": Kind.FLAT, "stat": "time_on_hit", "range": [1, 2], "weight": 8},
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
	# On anything (`LootTable.ANY_AFFIXES`), and flat at every level: eight sockets of top rolls is the
	# cap, where the next enemy is there the moment the last one is dead.
	"added_spawn_speed": {"kind": Kind.FLAT, "stat": "spawn_speed", "range": [5, 15], "weight": 4,
		"level_flat": 0.0},
	# The globals, and the jewellery is the only place they land. A percentage of the whole set is
	# worth more than a percentage of one piece, so increased damage rolls the smaller of the two
	# bands here -- the frontier is beaten with what the set adds up to, and test_combat's edge-fight
	# line is where that band is actually read off. Attack speed has no flat form (see below), so
	# this is the whole of what a ring can do to it.
	"global_increased_damage": {"kind": Kind.GLOBAL, "stat": "damage", "range": [5, 12], "weight": 8},
	"global_increased_attack_speed": {"kind": Kind.GLOBAL, "stat": "attack_speed", "range": [5, 12], "weight": 8},
	# Seconds on the fight clock, in tenths (`LootTable.SECONDS_STATS`): 1.0-4.0s, on anything, and the
	# same at every level -- a clock that grew with the level would delete the only way to lose.
	# `Encounter.CLOCK_MOST` caps what a whole set adds.
	"added_fight_clock": {"kind": Kind.FLAT, "stat": "fight_clock", "range": [10, 40], "weight": 4},
}

## Modifiers the table no longer holds -> [what a saved one became, what its number is multiplied by].
## Read by `Item.from_dict` alone. One idea under two names is how the two come to disagree, so the
## player-wide move speed and item rarity went into the FLAT lines that already said them, and the
## clock counts tenths now.
const RENAMED := {
	"walk_speed": ["added_move_speed", 1],
	"item_rarity": ["added_item_rarity", 1],
	"fight_clock": ["added_fight_clock", 10],
}

## No modifier can be drawn without a stat to hang on, so attack speed has no flat form: "+0.2
## attacks a second" would be the one fraction in the file.

## The modifiers no item can roll today on purpose rather than by oversight. Written down because
## "unreachable" is exactly what a test would otherwise fail on, and a silently unreachable modifier
## and a deliberately dormant one have to be told apart by name.
##
## Empty today: the resistances were the dormant ones, and they went when enemies began to strike the
## clock -- there is one thing to defend and no elements to defend it from. The list stays for the
## next modifier that is written ahead of its piece.
const DORMANT: Array[String] = []

## The modifiers no pool holds because only a unique's row may name them (`UniqueTable.UNIQUES`). Named
## for the reason the dormant ones are: a test has to tell this from a modifier nothing can reach.
##
## Empty today. `added_gold_find` was the one, and it is in the Gold Amulet's pool now that the amulet
## shows gold find as a base stat -- a FLAT modifier is let on by `can_roll`, which asks for a base
## stat *or* an affix, and there is no third answer that would hold one back from a piece that has the
## stat outright. The list stays for the next row that wants it.
const UNIQUE_ONLY: Array[String] = []


## Every modifier this piece could carry: the ones that name a stat it has or may carry. This list is the whole rule -- an impossible modifier is never
## in it, so nothing downstream has to know it was impossible.
static func pool_for(item_type: String) -> PackedStringArray:
	var pool := PackedStringArray()
	for id: String in MODS:
		var mod: Dictionary = MODS[id]
		var fits := false
		match mod["kind"]:
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
		rolled.append(rolled_mod(id, rng, level))
	return rolled


## How much likelier each tier is than the one under it, read the other way: at item level L, tier T
## is drawn with weight TIER_FALLOFF^(L - T). The one dial of the tiers. Nearer 1 spreads the draw
## down the tiers and lifts the top tier's band (it settles at (1 - r/g) / (1 - r) of the old band,
## g being `LootTable.LEVEL_GROWTH`: 1.96 at 0.9); nearer 0 is the old single band back.
const TIER_FALLOFF := 0.9


## Whether this modifier's band grows with the level at all. One that does not -- the fight clock,
## and gold find with its `level_flat` of 0 -- is the same band at every tier, so it draws none and
## writes none.
static func tiered(id: String) -> bool:
	return _level_band(id, 1) != _level_band(id, 50)


## How many tiers under the top a fresh modifier lands, at a piece whose bands are read at `level`:
## 0 to level - 1, each step down TIER_FALLOFF times as likely as the one above. One `randf` through
## the inverse of the truncated geometric sum, never a loop of coin tosses -- which would pile what
## is left over onto tier 1.
static func roll_under(level: int, rng: RandomNumberGenerator) -> int:
	var tiers := maxi(level, 1)
	var share := rng.randf() * (1.0 - pow(TIER_FALLOFF, tiers))
	return clampi(floori(log(1.0 - share) / log(TIER_FALLOFF)), 0, tiers - 1)


## A fresh modifier: its id, how far under the top tier it landed (`"under"`, written only above 0,
## the way a lock is) and a number in that tier's band. The tier is kept as a distance from the top
## rather than by its own number so that everything which moves a piece's level -- the smith, an Orb
## of Ascension, the end of a world -- carries the tier along with no code of its own.
static func rolled_mod(id: String, rng: RandomNumberGenerator, level := 1) -> Dictionary:
	var under := roll_under(level, rng) if tiered(id) else 0
	var mod := {"id": id, "value": reroll_value(id, rng, level - under)}
	if under > 0:
		mod["under"] = under
	return mod


## The `"under"` a modifier saved before there were tiers is given: the highest tier whose band
## reaches down to the number it has, so the piece is worth what it was and sits inside a band.
static func fit_under(id: String, value: int, level: int) -> int:
	if not tiered(id):
		return 0
	for under in maxi(level, 1):
		if int(band_for(id, level - under)[0]) <= value:
			return under
	return maxi(level, 1) - 1


## What one modifier rolls between at this tier. Its own function because three callers need the
## same answer and any two of them disagreeing would be invisible: `rolled_mod` draws a new modifier
## here, `reroll_value` draws a fresh number for one already on a piece, and a test reads the band to
## check that a divined value stayed inside it.
##
## A tier's band is fixed, whatever piece it lands on, and built so that the tiers a piece of level
## L can draw (`roll_under`'s weights) average out to exactly `_level_band(id, L)` -- what a modifier
## was worth before there were tiers. With m the old band's end, r the falloff and S(n) the sum of
## r^0..r^(n-1), that is m(T) + r * S(T-1) * (m(T) - m(T-1)): tier 1 is the old level-1 band, and
## every tier above is the old band at its level plus a share of how fast that band was growing.
static func band_for(id: String, tier: int) -> Array:
	tier = maxi(tier, 1)
	var here := _level_band(id, tier)
	var before := _level_band(id, tier - 1)
	var carry := TIER_FALLOFF * (1.0 - pow(TIER_FALLOFF, tier - 1)) / (1.0 - TIER_FALLOFF)
	return [maxi(1, roundi(here[0] + carry * (here[0] - before[0]))),
			maxi(1, roundi(here[1] + carry * (here[1] - before[1])))]


## What a modifier was worth at this item level before there were tiers, unrounded: the mean the
## tiers are built to keep.
static func _level_band(id: String, level: int) -> Array[float]:
	var entry: Dictionary = MODS[id]
	var band: Array = entry["range"]
	var low := float(band[0])
	var high := float(band[1])
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
			low = LootTable.scale(entry["stat"], low, level, step)
			high = LootTable.scale(entry["stat"], high, level, step)
		Kind.PERCENT, Kind.GLOBAL:
			# A percentage of a stat that has already grown -- the piece's own or the whole set's,
			# which is the same arithmetic. It takes the multiplier and not the flat step, which
			# is sized for the stat itself rather than for a percentage of it.
			low *= pow(LootTable.LEVEL_GROWTH, maxi(level - 1, 0))
			high *= pow(LootTable.LEVEL_GROWTH, maxi(level - 1, 0))
	return [low, high]


## A fresh number for one modifier, in its tier's band. What an Orb of Divine spends itself on: the
## id and the tier stay and only the roll moves, which is why it is drawn here rather than by
## rolling the modifier again from scratch.
static func reroll_value(id: String, rng: RandomNumberGenerator, tier := 1) -> int:
	var band := band_for(id, tier)
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
## Augmentation is this -- which pieces it is offered on is `OrbTable.can_apply`'s business and not this
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
	return rolled_mod(_weighted(pool, rng), rng, level)


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
	return _written(id, amount(id, int(mod.get("value", 0))))


## A modifier written with the band it rolls in at `level` in the number's place: "+8-20% increased
## Damage". What the fortuneteller reads off a piece; the same sentence `line` writes, so the two
## cannot come to spell a modifier differently.
static func band_line(id: String, level: int) -> String:
	if not MODS.has(id):
		return ""
	# Everything the piece could roll: the bottom of tier 1 to the top of the tier its level allows.
	var low := amount(id, int(band_for(id, 1)[0]))
	var high := amount(id, int(band_for(id, level)[1]))
	return _written(id, low if low == high else "%s-%s" % [low, high])


## A modifier's number as it is written. A flat one is the one number here that grows with the
## level, so it is written the way every other growing quantity is (`BigNumber`) rather than spelled
## out to twenty digits.
static func amount(id: String, value: int) -> String:
	var entry: Dictionary = MODS[id]
	if entry["kind"] != Kind.FLAT:
		return str(value)
	# Tenths of a second, written as seconds with the unit on: the "s" is the number's, not the line's.
	if entry["stat"] in LootTable.SECONDS_STATS:
		return LootTable.seconds_text(value)
	return BigNumber.format(value)


static func _written(id: String, amount: String) -> String:
	var entry: Dictionary = MODS[id]
	match entry["kind"]:
		Kind.PERCENT, Kind.GLOBAL:
			# The same sentence for both, and honestly so: with one weapon between them, a sword's
			# increased damage and a ring's are the same claim about the same number.
			return "+%s%% increased %s" % [amount, LootTable.STAT_LABELS[entry["stat"]]]
		_:
			# A flat roll on a stat that is itself a percentage adds percentage points, and has to
			# say so: "+10% Drop Rate", never "+10 Drop Rate". Seconds carry their own "s" (`amount`).
			var stat: String = entry["stat"]
			var unit := "%" if stat in LootTable.PERCENT_STATS else ""
			return "+%s%s %s" % [amount, unit, LootTable.STAT_LABELS[stat]]
