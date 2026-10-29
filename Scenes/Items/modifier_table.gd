class_name ModifierTable
extends RefCounted
## The modifier pool and its three kinds, each line's tiers and bands, and how a line is rolled and
## written. A pool is built of legal candidates only (`pool_for`), never rolled and then checked.
## Every value is a whole number: one `randi_range` a line, `14` in a save, `==` on a round trip.

enum Kind {
	PERCENT,  ## scales a base stat the item has: "+14% increased Damage"
	FLAT,     ## adds a stat the item is allowed to carry: "+2 Damage", "+5% to Crit Chance"
	GLOBAL,   ## scales what the whole set is worth, not the piece: a ring's "+14% increased Damage"
}

## id -> its row. A saved line holds the id: a retired one loads through `RENAMED`, or is lost.
##   kind, stat  what it does, to what. One stat a line; a line with no `text` is built from the
##               stat's label (`_written`).
##   range       the band it rolls in at level 1, both ends inclusive.
##   weight      how often it is drawn against the rest of its pool (`weight_of`).
##   level_flat  what a level adds to the band, in place of the stat's own `LootTable.LEVEL_FLAT`.
##   text        the sentence it writes, `{n}` the number, in place of the stat's label; `text_one`
##               for a number of one. Never opens on a name (the user's; CLAUDE.md).
##   per_tier    [low, high] added to the band a tier past the first, in place of growing by level.
##   signed      the band is `range` either side of nothing, never 0, and `wide` from tier `wide_from`.
## Attack speed has no FLAT line: "+0.2 attacks a second" would be the one fraction in the file.
## Bands and weights are the user's dials; what each was sized against is in DESIGN.md.
const MODS := {
	"increased_damage": {"kind": Kind.PERCENT, "stat": "damage", "range": [8, 20], "weight": 10},
	# A quarter of the weapon's step a level: four sockets roll it (DESIGN.md).
	"added_damage": {"kind": Kind.FLAT, "stat": "damage", "range": [1, 2], "weight": 10,
		"level_flat": 0.1},
	"increased_crit": {"kind": Kind.PERCENT, "stat": "crit_chance", "range": [10, 30], "weight": 10},
	"added_crit": {"kind": Kind.FLAT, "stat": "crit_chance", "range": [1, 4], "weight": 10},
	"increased_attack_speed": {"kind": Kind.PERCENT, "stat": "attack_speed", "range": [5, 12], "weight": 10},
	# A whole swing a second at every level: only the Broken Sword's Augmentation puts it on (`DORMANT`).
	"added_attack_speed": {"kind": Kind.FLAT, "stat": "attack_speed", "range": [1, 1], "per_tier": [0, 0],
			"weight": 10},
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
	# The mace's alone: bleed is its kind's.
	"increased_bleed": {"kind": Kind.PERCENT, "stat": "bleed", "range": [10, 25], "weight": 10},
	"added_bleed": {"kind": Kind.FLAT, "stat": "bleed", "range": [3, 8], "weight": 10},
	# The weapons' lines: more of one kind of blow, summed in `Encounter.gear_more` and applied once.
	"added_click_damage": {"kind": Kind.FLAT, "stat": "click_damage", "range": [10, 25], "weight": 8},
	"added_swing_damage": {"kind": Kind.FLAT, "stat": "swing_damage", "range": [10, 25], "weight": 8},
	"added_elite_damage": {"kind": Kind.FLAT, "stat": "elite_damage", "range": [15, 35], "weight": 6},
	"added_first_blow": {"kind": Kind.FLAT, "stat": "first_blow", "range": [20, 50], "weight": 6},
	"added_double_strike": {"kind": Kind.FLAT, "stat": "double_strike", "range": [2, 5], "weight": 6},
	"added_time_on_hit": {"kind": Kind.FLAT, "stat": "time_on_hit", "range": [1, 2], "weight": 8},
	"added_strength": {"kind": Kind.FLAT, "stat": "strength", "range": [2, 8], "weight": 8},
	"added_dexterity": {"kind": Kind.FLAT, "stat": "dexterity", "range": [2, 8], "weight": 8},
	"added_intelligence": {"kind": Kind.FLAT, "stat": "intelligence", "range": [2, 8], "weight": 8},
	# All three attributes at once, the amulets' alone.
	"added_all_attributes": {"kind": Kind.FLAT, "stat": "all_attributes", "range": [1, 4], "weight": 4},
	"added_drop_rate": {"kind": Kind.FLAT, "stat": "drop_rate", "range": [3, 10], "weight": 4},
	"added_item_rarity": {"kind": Kind.FLAT, "stat": "item_rarity", "range": [10, 25], "weight": 4},
	# `level_flat` 0: the band was sized for The Tithe, a share of a purse already exponential in the walk.
	"added_gold_find": {"kind": Kind.FLAT, "stat": "gold_find", "range": [20, 40], "weight": 1,
		"level_flat": 0.0},
	"added_orb_find": {"kind": Kind.FLAT, "stat": "orb_find", "range": [10, 20], "weight": 4},
	# The rings' two lines. Elite chance is one band at every level, as spawn speed is.
	"added_experience": {"kind": Kind.FLAT, "stat": "xp_more", "range": [5, 15], "weight": 4},
	"added_elite_chance": {"kind": Kind.FLAT, "stat": "elite_chance", "range": [3, 8], "weight": 4},
	# The helmet's, the body's and the offhand's lines (2026-10-07), each saying what it does (`text`).
	# The helmet's:
	"added_blow_delay": {"kind": Kind.FLAT, "stat": "blow_delay", "range": [10, 25], "weight": 6,
		"text": "Enemies' first blows come {n}% later"},
	"added_elite_ward": {"kind": Kind.FLAT, "stat": "elite_ward", "range": [10, 25], "weight": 6,
		"text": "{n}% less time lost to elites' and bosses' blows"},
	"added_tile_ward": {"kind": Kind.FLAT, "stat": "tile_ward", "range": [10, 25], "weight": 4,
		"text": "Tile modifiers are {n}% weaker"},
	"added_less_health": {"kind": Kind.FLAT, "stat": "less_health", "range": [5, 12], "weight": 6,
		"text": "Enemies have {n}% less health"},
	"added_strength_stones": {"kind": Kind.FLAT, "stat": "strength_stones", "range": [1, 1], "weight": 2,
		"text": "+{n} rank to every Strength Node holding a point"},
	"added_intelligence_stones": {"kind": Kind.FLAT, "stat": "intelligence_stones", "range": [1, 1],
		"weight": 2, "text": "+{n} rank to every Intelligence Node holding a point"},
	"added_dexterity_stones": {"kind": Kind.FLAT, "stat": "dexterity_stones", "range": [1, 1], "weight": 2,
		"text": "+{n} rank to every Dexterity Node holding a point"},
	# A skill stone's (the user's, 2026-10-08): the points it takes past the one every stone takes
	# (`Skills`). Its bands are written by the tier (`per_tier`, the user's, 2026-10-09): tier 1 is 1-2
	# and each tier lifts the top by two. Drawn at `SkillTree.ranks_weight(tier)`, never at this weight.
	"added_stone_ranks": {"kind": Kind.FLAT, "stat": "stone_ranks", "range": [1, 2], "weight": 4,
		"per_tier": [0, 2], "text": "+{n} ranks", "text_one": "+{n} rank"},
	# The body's. `added_enemies` is one more or fewer, up to two from tier `wide_from`, never none.
	"added_camp_earnings": {"kind": Kind.FLAT, "stat": "camp_earnings", "range": [10, 25], "weight": 4,
		"text": "Camps earn {n}% more"},
	"added_enemies": {"kind": Kind.FLAT, "stat": "extra_enemies", "range": [-1, 1], "weight": 4,
		"signed": true, "wide": [-2, 2], "wide_from": 9,
		"text": "{n} enemies in each fight", "text_one": "{n} enemy in each fight"},
	"added_thorns": {"kind": Kind.FLAT, "stat": "thorns", "range": [15, 35], "weight": 6,
		"text": "Blows that land on you strike back for {n}% of your damage"},
	"added_recoup": {"kind": Kind.FLAT, "stat": "recoup", "range": [10, 25], "weight": 6,
		"text": "{n}% of the time a blow takes comes back over 4 seconds"},
	# The offhand: the buckler's crit after a dodge, the torch's burn, the shield's time on a block.
	"added_parry": {"kind": Kind.FLAT, "stat": "parry", "range": [20, 50], "weight": 6,
		"text": "A dodged blow adds {n}% crit chance to your next blow"},
	"added_burn": {"kind": Kind.FLAT, "stat": "burn", "range": [10, 30], "weight": 6,
		"text": "Blows burn for {n}% of their damage over 3 seconds"},
	"added_time_on_block": {"kind": Kind.FLAT, "stat": "time_on_block", "range": [2, 5], "weight": 6,
		"text": "A blow your block stops entirely wins back {n}"},
	# On any piece (`LootTable.ANY_AFFIXES`), and the same band at every level: the cap is a set's worth.
	"added_spawn_speed": {"kind": Kind.FLAT, "stat": "spawn_speed", "range": [5, 15], "weight": 4,
		"level_flat": 0.0},
	# The globals, which only the jewellery carries. Each rolls a little under its PERCENT band: a share
	# of the whole set is worth more than a share of one piece.
	"global_increased_damage": {"kind": Kind.GLOBAL, "stat": "damage", "range": [5, 12], "weight": 8},
	"global_increased_attack_speed": {"kind": Kind.GLOBAL, "stat": "attack_speed", "range": [5, 12], "weight": 8},
	"global_increased_crit": {"kind": Kind.GLOBAL, "stat": "crit_chance", "range": [6, 15], "weight": 6},
	"global_increased_crit_damage": {"kind": Kind.GLOBAL, "stat": "crit_damage", "range": [5, 12], "weight": 6},
	"global_increased_bleed": {"kind": Kind.GLOBAL, "stat": "bleed", "range": [5, 12], "weight": 6},
	"global_increased_armor": {"kind": Kind.GLOBAL, "stat": "armor", "range": [5, 12], "weight": 6},
	"global_increased_dodge": {"kind": Kind.GLOBAL, "stat": "dodge", "range": [5, 12], "weight": 6},
	"global_increased_time_on_hit": {"kind": Kind.GLOBAL, "stat": "time_on_hit", "range": [5, 12], "weight": 6},
	# Tenths of a second (`LootTable.SECONDS_STATS`): 1.0-4.0s, on any piece and the same at every level,
	# since a clock that grew with the level would delete the only way to lose. `Encounter.CLOCK_MOST`
	# caps what a set adds.
	"added_fight_clock": {"kind": Kind.FLAT, "stat": "fight_clock", "range": [10, 40], "weight": 4},
}

## A retired id -> [the line a saved one became, what its number is multiplied by]. Read by
## `Item.from_dict` alone.
const RENAMED := {
	"walk_speed": ["added_move_speed", 1],
	"item_rarity": ["added_item_rarity", 1],
	"fight_clock": ["added_fight_clock", 10],
	# A helmet's rank on one of the old skill trees became one on a base of stone (2026-10-08).
	"added_power_skills": ["added_strength_stones", 1],
	"added_fortune_skills": ["added_intelligence_stones", 1],
	"added_guard_skills": ["added_dexterity_stones", 1],
}

## Modifiers no item can roll on purpose: `test_inventory` tells one from an unreachable modifier by
## this list. `added_attack_speed` is put on by hand (`OrbTable.apply`, the user's, 2026-10-29): in a
## pool it would be a whole swing a second on every weapon.
const DORMANT: Array[String] = ["added_attack_speed"]

## Modifiers no pool holds because only a unique's row may name them; the same test reads it. Empty
## today, and kept (CLAUDE.md).
const UNIQUE_ONLY: Array[String] = []


## Every modifier the piece could carry, and none it could not. A skill stone's is its base's list as
## far as `tier` unlocks (`SkillTree.lines_for`); every other piece ignores the tier.
static func pool_for(item_type: String, tier := SkillTree.MOST_TIER) -> PackedStringArray:
	if SkillTree.LINES.has(item_type):
		return SkillTree.lines_for(item_type, tier)
	var pool := PackedStringArray()
	for id: String in MODS:
		if id in DORMANT:
			continue
		var mod: Dictionary = MODS[id]
		var fits := false
		match mod["kind"]:
			Kind.PERCENT:
				# Not where the piece may scale the stat for the whole set: the two write the same sentence.
				fits = LootTable.has_stat(item_type, mod["stat"]) \
						and not LootTable.can_globalize(item_type, mod["stat"])
			Kind.GLOBAL:
				fits = LootTable.can_globalize(item_type, mod["stat"])
			_:
				fits = LootTable.can_roll(item_type, mod["stat"])
		if fits:
			pool.append(id)
	return pool


## `count` modifiers for a fresh piece, in the order drawn and without replacement. A pool too thin to
## fill the count gives all it has, which a test holds today's tables never to be.
static func roll(item_type: String, count: int, rng: RandomNumberGenerator,
		level := 1, tier := SkillTree.MOST_TIER) -> Array[Dictionary]:
	var pool := pool_for(item_type, tier)
	var rolled: Array[Dictionary] = []
	for i in count:
		if pool.is_empty():
			break
		var id := _weighted(pool, rng, tier)
		pool.remove_at(pool.find(id))
		rolled.append(rolled_mod(id, rng, level))
	return rolled


## The tiers' one dial: at item level L, tier T is drawn with weight TIER_FALLOFF^(L - T). Nearer 1
## spreads the draw down the tiers and lifts the top tier's band; nearer 0 is one band again. The
## arithmetic is in DESIGN.md, "Modifier tiers".
const TIER_FALLOFF := 0.9


## Whether the band grows with the level at all. One that does not (the fight clock, gold find) has
## no tiers: it draws none and writes none.
static func tiered(id: String) -> bool:
	return _level_band(id, 1) != _level_band(id, 50)


## How many tiers under the top a fresh line lands, where bands are read at `level`: 0 to level - 1,
## each step down TIER_FALLOFF times as likely. One `randf` through the inverse of the truncated
## geometric sum; a loop of coin tosses would pile what is left over onto tier 1.
static func roll_under(level: int, rng: RandomNumberGenerator) -> int:
	var tiers := maxi(level, 1)
	var share := rng.randf() * (1.0 - pow(TIER_FALLOFF, tiers))
	return clampi(floori(log(1.0 - share) / log(TIER_FALLOFF)), 0, tiers - 1)


## A fresh line, and the one way one is made: its id, a number in its tier's band, and `"under"`, how
## far under the top tier it landed (written only above 0). A distance from the top, so whatever moves
## a piece's level moves the tier with it.
static func rolled_mod(id: String, rng: RandomNumberGenerator, level := 1) -> Dictionary:
	var under := roll_under(level, rng) if tiered(id) else 0
	var mod := {"id": id, "value": reroll_value(id, rng, level - under)}
	if under > 0:
		mod["under"] = under
	return mod


## The `"under"` given to a line saved before there were tiers: the highest tier whose band reaches
## down to its number.
static func fit_under(id: String, value: int, level: int) -> int:
	if not tiered(id):
		return 0
	for under in maxi(level, 1):
		if int(band_for(id, level - under)[0]) <= value:
			return under
	return maxi(level, 1) - 1


## What a modifier rolls between at `tier`. A tier's band is fixed whatever piece it lands on, and
## built so that the tiers a level-L piece can draw average to `_level_band(id, L)`: with m the old
## band's end, r the falloff and S(n) the sum of r^0..r^(n-1), an end is
## m(T) + r * S(T-1) * (m(T) - m(T-1)).
static func band_for(id: String, tier: int) -> Array:
	tier = maxi(tier, 1)
	# A signed band and one written by the tier (`per_tier`) are as written: no carry, no floor at 1.
	if MODS[id].get("signed", false) or MODS[id].has("per_tier"):
		var ends := _level_band(id, tier)
		return [int(ends[0]), int(ends[1])]
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
	# A signed one widens once, at its tier, and grows no other way.
	if entry.get("signed", false) and level >= int(entry.get("wide_from", level + 1)):
		band = entry["wide"]
	var low := float(band[0])
	var high := float(band[1])
	if entry.get("signed", false):
		return [low, high]
	var steps := maxi(level - 1, 0)
	if entry.has("per_tier"):
		var step: Array = entry["per_tier"]
		return [low + float(step[0]) * steps, high + float(step[1]) * steps]
	match entry["kind"]:
		Kind.FLAT:
			# Grows as the stat's own numbers do, but for a step the entry names (`level_flat`); the
			# multiplier is the stat's either way.
			# ponytail: a band stays whole ints, which pass int64 near item level 370 -- far past
			# where a monster's health would have; retype the pair to float then.
			var step: float = float(entry.get("level_flat",
					LootTable.LEVEL_FLAT.get(entry["stat"], 0.0)))
			low = LootTable.scale(entry["stat"], low, level, step)
			high = LootTable.scale(entry["stat"], high, level, step)
		Kind.PERCENT, Kind.GLOBAL:
			# A percentage of a stat that has already grown: the multiplier, and no step.
			var growth := pow(LootTable.LEVEL_GROWTH, steps)
			low *= growth
			high *= growth
	return [low, high]


## A fresh number in the tier's band, the id and the tier staying: what an Orb of Divinity rerolls.
static func reroll_value(id: String, rng: RandomNumberGenerator, tier := 1) -> int:
	var band := band_for(id, tier)
	# A signed band is drawn one short and stepped over nothing, which no line may be.
	if MODS[id].get("signed", false):
		var drawn := rng.randi_range(int(band[0]), int(band[1]) - 1)
		return drawn + 1 if drawn >= 0 else drawn
	return rng.randi_range(int(band[0]), int(band[1]))


## A rolled value carried to another tier: as far up `to_tier`'s band as it stood in `from_tier`'s
## (`Item._set_tier`, `Item.ascend`). A value outside its band is held to the band's ends, and a band
## of one number counts as its top.
static func rescaled(id: String, value: int, from_tier: int, to_tier: int) -> int:
	var from := band_for(id, from_tier)
	var to := band_for(id, to_tier)
	# A signed value keeps its side, held to the new band's ends: a share of its band could land on 0.
	if MODS[id].get("signed", false):
		return clampi(value, int(to[0]), int(to[1]))
	var span := float(int(from[1]) - int(from[0]))
	var place := 1.0 if span <= 0.0 else clampf((value - int(from[0])) / span, 0.0, 1.0)
	return roundi(lerpf(float(to[0]), float(to[1]), place))


## One more modifier for a piece carrying `existing`: drawn from what it could take, less what it has.
## {} when nothing is left, which a test holds today's tables never to give.
static func add_one(item_type: String, existing: Array[Dictionary], rng: RandomNumberGenerator,
		level := 1, tier := SkillTree.MOST_TIER) -> Dictionary:
	var held := {}
	for mod in existing:
		held[str(mod.get("id", ""))] = true
	var pool := PackedStringArray()
	for id in pool_for(item_type, tier):
		if not held.has(id):
			pool.append(id)
	if pool.is_empty():
		return {}
	return rolled_mod(_weighted(pool, rng, tier), rng, level)


## How often `id` is drawn against the rest of its pool: its `weight`, but for a skill stone's ranks
## line, which its tier sets (`SkillTree.ranks_weight`).
static func weight_of(id: String, tier := SkillTree.MOST_TIER) -> int:
	if MODS[id]["stat"] == SkillTree.RANKS_STAT:
		return SkillTree.ranks_weight(tier)
	return int(MODS[id]["weight"])


## One draw from what is left, by weight: the walk every table draws by (`LootTable.weighted_index`).
static func _weighted(pool: PackedStringArray, rng: RandomNumberGenerator,
		tier := SkillTree.MOST_TIER) -> String:
	return pool[LootTable.weighted_index(Array(pool).map(func(id: String) -> int: return weight_of(id, tier)), rng)]


## A rolled modifier as its card writes it; "" for an id the table has not got.
static func line(mod: Dictionary) -> String:
	var id: String = mod.get("id", "")
	if not MODS.has(id):
		return ""
	var value := int(mod.get("value", 0))
	return _written(id, amount(id, value), absi(value) == 1)


## The line with everything it could roll at `level` in the number's place, "+8-20% increased Damage":
## the fortuneteller's appraisal. Written through the same `_written` as `line`.
static func band_line(id: String, level: int) -> String:
	if not MODS.has(id):
		return ""
	# A signed band is as far as it reaches either way: "±2 enemies in each fight".
	if MODS[id].get("signed", false):
		var reach := int(band_for(id, level)[1])
		return _written(id, "±%d" % reach, reach == 1)
	# Everything the piece could roll: the bottom of tier 1 to the top of the tier its level allows.
	var low := amount(id, int(band_for(id, 1)[0]))
	var high := amount(id, int(band_for(id, level)[1]))
	return _written(id, low if low == high else "%s-%s" % [low, high])


## A modifier's number as it is written (`BigNumber`), its unit and its sign with it.
static func amount(id: String, value: int) -> String:
	var entry: Dictionary = MODS[id]
	# Tenths of a second, written as seconds with the unit on: the "s" is the number's, not the line's.
	if entry["kind"] == Kind.FLAT and entry["stat"] in LootTable.SECONDS_STATS:
		return LootTable.seconds_text(value)
	if entry.get("signed", false):
		return BigNumber.format(value, true)
	return BigNumber.format(value)


## The sentence a modifier says, with `amount` in its number's place. `one` is a number of one, which a
## line that counts something writes in the singular (`text_one`).
static func _written(id: String, amount: String, one := false) -> String:
	var entry: Dictionary = MODS[id]
	if entry.has("text"):
		return str(entry["text_one"] if one and entry.has("text_one") else entry["text"]).replace("{n}", amount)
	match entry["kind"]:
		Kind.PERCENT, Kind.GLOBAL:
			return "+%s%% increased %s" % [amount, LootTable.STAT_LABELS[entry["stat"]]]
		_:
			# A flat roll on a stat that is a percentage adds points and says "to": "+10% to Drop Rate",
			# against an increase's "+10% increased Drop Rate". Seconds carry their own "s" (`amount`).
			var stat: String = entry["stat"]
			if stat in LootTable.PERCENT_STATS:
				return "+%s%% to %s" % [amount, LootTable.STAT_LABELS[stat]]
			return "+%s %s" % [amount, LootTable.STAT_LABELS[stat]]
