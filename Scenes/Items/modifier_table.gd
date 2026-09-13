class_name ModifierTable
extends RefCounted
## What an item can carry on top of what it is.
##
## Two shapes of modifier. A PERCENT or FLAT one acts on one of the item's own stats, so it can only
## land on a piece that has that stat -- a boot has no damage to increase. A PLAYER one is a buff to
## the player rather than the item, and can land on anything; the pool of those is deliberately small
## and every one of them names something this game already has, rather than inventing a currency or a
## resistance for a system nobody has written.
##
## Which modifiers an item can roll is decided by building the list of candidates first and drawing
## from that, never by rolling and checking: a modifier the item cannot carry is never a candidate,
## so there is no check to forget and no reroll loop that can spin.
##
## Every value is a whole number on purpose. It means one randi_range per modifier, it means the save
## file holds 14 rather than 14.0, and it means a test can compare a round-tripped item with == .
## Nothing here wants half a percent.

enum Kind {
	PERCENT,  ## scales one of the item's own stats: "+14% increased Damage"
	FLAT,     ## adds to one of them: "+2 Damage"
	PLAYER,   ## a buff to the player, and so at home on any item at all: "+6% item find"
}

## id -> what it does, what it touches, the range it rolls in, and how often it is drawn against the
## others in the same pool. PLAYER modifiers carry their own line because each is a sentence about a
## different thing; the rest build theirs from the stat's label, so a stat renamed is renamed
## everywhere. Percent ranges are wider where the stat is itself a percentage -- a fifth of a 5% crit
## chance is a rounding error -- and a flat roll is worth roughly two percent rolls on the same stat.
const MODS := {
	"increased_damage": {"kind": Kind.PERCENT, "stat": "damage", "range": [8, 20], "weight": 10},
	"added_damage": {"kind": Kind.FLAT, "stat": "damage", "range": [1, 3], "weight": 10},
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
	# The player-wide four. Each points at something that exists: LootTable.chance_for,
	# Encounter.SECONDS, PlayerToken.SECONDS_PER_TILE and ItemRarity.TIER_WEIGHTS. The clock stops at
	# four seconds because four on a minute is already a noticeably easier fight.
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
		if mod["kind"] == Kind.PLAYER or LootTable.has_stat(item_type, mod["stat"]):
			pool.append(id)
	return pool


## The modifiers on one item, as [{"id": ..., "value": ...}] in the order they were drawn. Drawn
## without replacement, so a modifier never appears twice on one piece -- though "+2 Damage" and
## "+14% increased Damage" are two different draws doing two different things, which is the point of
## having both shapes. A pool too thin to fill the count gives everything it has, which cannot happen
## with today's tables and is held to that by a test.
static func roll(item_type: String, count: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var pool := pool_for(item_type)
	var rolled: Array[Dictionary] = []
	for i in count:
		if pool.is_empty():
			break
		var id := _weighted(pool, rng)
		pool.remove_at(pool.find(id))
		var band: Array = MODS[id]["range"]
		rolled.append({"id": id, "value": rng.randi_range(int(band[0]), int(band[1]))})
	return rolled


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
			return "+%d %s" % [value, LootTable.STAT_LABELS[entry["stat"]]]
