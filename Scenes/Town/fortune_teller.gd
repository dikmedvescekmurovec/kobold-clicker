class_name FortuneTeller
extends RefCounted
## The fortuneteller: what she can be asked, and what she answers.
##
## Every settlement has her, and she is the one counter that sells nothing to carry: what she sells is
## knowledge the game used to give away or never gave at all. Three **readings** -- where the nearest
## settlements lie, where a chest is, and what a piece could still roll -- each asked as often as the
## player will pay for it; and two **great spells**, one a settlement:
## a patch of the map lifted out of the dark, and the road home walked in no time at all.
##
## Static and node-free like `Blacksmith`, so the tests need no interface. What a spell costs is
## `TownPrices.fortune_price`'s business. What was bought is written where it belongs: what a town has
## sold in that town's drawer (`ASKED`), and what belongs to the
## player rather than to a town -- the chest, the uniques banished -- in `inventory.fortunes`, a plain Dictionary this file
## holds the keys of, because
## `Inventory` must not name a class that names `Item`'s tables back at it.

## The readings, which are also the keys of `TownPrices.FORTUNE_BODIES`.
const ROADS := "roads"
const TREASURE := "treasure"
const APPRAISE := "appraise"
const SCOUR := "scour"
const HOMECOMING := "homecoming"
## Not a reading at all but the way out of the world: everything is left behind but the heirlooms
## (`Inventory.transcended`). She offers it only once a wall has fallen, and it is priced against the
## ground behind the first wall rather than the town's (`TownPrices.fortune_price`).
const TRANSCEND := "transcend"
## Neither a reading nor a great spell: a unique the player picks is kept out of the drops for as long
## as this world lasts (`dropping`), each one paid for costing twice the last (`TownPrices.fortune_price`).
## She offers it only once `BANISH_FROM` uniques are unlocked, and never lets fewer than `BANISH_LEAVES` drop.
const BANISH := "banish"
## The order her buttons stand in: the readings first, then the great spells, the way out and the banishing.
const READINGS := [ROADS, TREASURE, APPRAISE, SCOUR, HOMECOMING, TRANSCEND, BANISH]

## Her list is in two halves, and which half a spell is in is the whole of its rule.
##
## A **reading** is asked as often as the player likes, anywhere, at the town's own price every time.
## A **great spell** is one a settlement, the way every reading
## used to be: it is written in that town's drawer under `ASKED` and refused there from then on.
##
## Written out rather than derived from `READINGS`, which is the grid's order; `test_town` holds the
## three lists together.
const COMMON := [ROADS, TREASURE, APPRAISE]
const GREAT := [SCOUR, HOMECOMING]

## What each reading's button says.
const LABELS := {
	ROADS: "Roads",
	TREASURE: "Treasure",
	APPRAISE: "Appraise",
	SCOUR: "Scour",
	# "Homecoming" is two letters wider than a shelf square, and a name on her grid is clipped rather
	# than allowed to widen the page.
	HOMECOMING: "Return",
	TRANSCEND: "Transcend",
	BANISH: "Banish",
}

## The town drawer's key, before a spell's name: a `GREAT` spell is sold once a settlement and refused
## there from then on. The roads write it too: bought once a town, the same way.
const ASKED := "fortune_"
## `inventory.fortunes`' keys: the chest the star is over, the uniques banished from this world's drops,
## and how many banishings have been paid for here -- the price's exponent, which bringing one back never
## lowers. All three go with the world: a transcension carries no `fortunes`.
const CHEST := "chest"
const BANISHED := "banished"
const BANISH_PAID := "banish_paid"

## How many uniques must be unlocked (the starters count) before she offers to banish one, and how many
## she always leaves to drop. Dials, the user's (2026-10-10).
const BANISH_FROM := 24
const BANISH_LEAVES := 10

## How near the hero feels the Gollux cave (`CaveSense`), coldest first, and the most steps from it each
## warmer band holds: Burning at two or fewer, Hot at five, Warm at ten, Cool at sixteen, Cold past that.
## Bands rather than the distance, so the light at the map's edge says roughly how far and never which tile.
const WARMTH := ["Cold", "Cool", "Warm", "Hot", "Burning"]
const WARMTH_STEPS := [16, 10, 5, 2]

## How far round the chosen tile the scour reaches: the tile and two rings, nineteen in all.
const SCOUR_RADIUS := 2
## How far round each settlement the roads show: the town and the six beside it (the user's, 2026-10-02).
const ROADS_RADIUS := 1

## What she says about a piece whose modifiers are its row's and nothing else's.
const WRITTEN := "Its lines are already written"


## How warm the cave feels `steps` from it: an index into `WARMTH`, 0 the coldest.
static func warmth(steps: int) -> int:
	var band := 0
	for most: int in WARMTH_STEPS:
		if steps <= most:
			band += 1
	return band


## Why she will not appraise this piece, or "" when she will.
static func why_not_appraise(item: Item) -> String:
	if item == null:
		return "Open an item in your bag"
	return WRITTEN if not item.unique.is_empty() else ""


## Every modifier this piece's kind can roll, commonest first: `{id, line, weight, share}`, where
## `line` is the modifier written with the band it rolls in at the piece's level and `share` is its
## weight as a percentage of the whole pool. The whole pool rather than what the piece lacks: a
## reroll draws from all of it, and an Exalted's smaller pool is this one less what is on the card.
static func odds(item: Item) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not why_not_appraise(item).is_empty():
		return rows
	var total := 0.0
	var pool := ModifierTable.pool_for(item.type, item.stone_tier)
	for id in pool:
		total += ModifierTable.weight_of(id, item.stone_tier)
	for id in pool:
		var weight := ModifierTable.weight_of(id, item.stone_tier)
		rows.append({"id": id, "line": ModifierTable.band_line(id, item.mod_level()), "weight": weight,
				"share": 100.0 * weight / total})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["weight"] > b["weight"])
	return rows


## The tiles a scour on `center` reaches.
static func scour_cells(center: Vector2i, radius := SCOUR_RADIUS) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(center.y - radius, center.y + radius + 1):
		for x in range(center.x - radius, center.x + radius + 1):
			if HexGrid.distance(center, Vector2i(x, y)) <= radius:
				cells.append(Vector2i(x, y))
	return cells


## The world spot of the chest the star was bought for, `TownWorld.NO_SPOT` for none. Read through
## `int()`, because JSON hands whole numbers back as floats.
static func chest(fortunes: Dictionary) -> Vector2i:
	var saved: Variant = fortunes.get(CHEST, null)
	if typeof(saved) != TYPE_ARRAY or (saved as Array).size() != 2:
		return TownWorld.NO_SPOT
	return Vector2i(int(saved[0]), int(saved[1]))


## The uniques banished from this world's drops, by id.
static func banished(fortunes: Dictionary) -> Array:
	var saved: Variant = fortunes.get(BANISHED, null)
	if typeof(saved) != TYPE_ARRAY:
		return []
	return (saved as Array).filter(func(id: Variant) -> bool: return typeof(id) == TYPE_STRING)


## How many banishings have been paid for in this world: what the next one's price doubles by.
static func banishes(fortunes: Dictionary) -> int:
	return maxi(0, int(fortunes.get(BANISH_PAID, 0)))


## `unlocked` less what is banished: the uniques a body, a chest or a bounty may hand over. Every source
## of one is handed this rather than `Achievements.unlocked`.
static func dropping(unlocked: Array, fortunes: Dictionary) -> Array:
	var gone := banished(fortunes)
	return unlocked.filter(func(id: String) -> bool: return not gone.has(id))


## Why she will not banish `id`, or "" when she will. She always leaves `BANISH_LEAVES` to drop -- which
## also keeps the list from ever emptying under `BountyBoard`, which draws straight out of it.
static func why_not_banish(id: String, unlocked: Array, fortunes: Dictionary) -> String:
	if banished(fortunes).has(id):
		return "Already banished"
	if dropping(unlocked, fortunes).size() <= BANISH_LEAVES:
		return "You need at least %d uniques in the drop pool" % BANISH_LEAVES
	return ""


## `id` out of the drops, and one more banishing paid for. Whether she would is `why_not_banish`'s.
static func banish(fortunes: Dictionary, id: String) -> void:
	fortunes[BANISHED] = banished(fortunes) + [id]
	fortunes[BANISH_PAID] = banishes(fortunes) + 1


## `id` back in the drops, for nothing; what was paid stays paid.
static func restore(fortunes: Dictionary, id: String) -> void:
	var gone := banished(fortunes)
	gone.erase(id)
	fortunes[BANISHED] = gone


## Whether `reading` has been paid for in the town whose drawer this is: a great spell spent here, or
## the roads already bought here.
static func asked(drawer: Dictionary, reading: String) -> bool:
	return bool(drawer.get(ASKED + reading, false))
