class_name FortuneTeller
extends RefCounted
## The fortuneteller: what she can be asked, and what she answers.
##
## Every settlement has her, and she is the one counter that sells nothing to carry: what she sells is
## knowledge the game used to give away or never gave at all. Six readings -- where the nearest
## settlements lie, where a chest is, where the accepted bounty's monster lives, what one unique not
## yet found is and where it drops, what a piece could still roll, and, once in a playthrough, a
## patch of the map lifted out of the dark.
##
## Static and node-free like `Blacksmith`, so the tests need no interface. What a reading costs is
## `TownPrices.fortune_price`'s business. What was bought is written where it belongs: the roads in
## that town's drawer, the bounty's location on the posting, and the three that belong to the player
## rather than to a town -- the chest, the peeked uniques, the spent scour -- in `inventory.fortunes`,
## a plain Dictionary this file holds the keys of, because `Inventory` must not name a class that
## names `Item`'s tables back at it.

## The readings, which are also the keys of `TownPrices.FORTUNE_BODIES`.
const ROADS := "roads"
const TREASURE := "treasure"
const QUARRY := "quarry"
const RELIC := "relic"
const APPRAISE := "appraise"
const SCOUR := "scour"
## The order her buttons stand in: the cheap and the often-asked first, the one spell last.
const READINGS := [ROADS, TREASURE, QUARRY, RELIC, APPRAISE, SCOUR]

## What each reading's button says.
const LABELS := {
	ROADS: "Roads",
	TREASURE: "Treasure",
	QUARRY: "Quarry",
	RELIC: "Relic",
	APPRAISE: "Appraise",
	SCOUR: "Scour",
}

## The town drawer's key: the roads were paid for here, so they are told again for nothing.
const ROADS_TOLD := "fortune_roads"
## `inventory.fortunes`' keys.
const CHEST := "chest"
const PEEKED := "peeked"
const SCOURED := "scoured"

## One tile is an hour on foot, and a day's walking is eight of them.
const HOURS_PER_DAY := 8
const DAYS_PER_WEEK := 7
## How far round the chosen tile the scour reaches: the tile and two rings, nineteen in all.
const SCOUR_RADIUS := 2

## The eight winds, clockwise from east, the way `atan2` turns with y pointing down the map.
const WINDS := ["east", "south east", "south", "south west", "west", "north west", "north", "north east"]
## What each `TownWorld.Tier` is called in a sentence, in the enum's own order.
const TIER_WORDS := ["village", "town", "fortress"]

## What she says about a piece whose modifiers are its row's and nothing else's.
const WRITTEN := "Its lines are already written."


## Which wind `to` lies on from `from`, both world spots. Offset rows are put on a plane first (odd
## rows stand half a tile right, rows are 0.866 of a tile apart), or due north would lean.
static func bearing(from: Vector2i, to: Vector2i) -> String:
	var a := Vector2(from.x + 0.5 * (from.y & 1), from.y * 0.866)
	var b := Vector2(to.x + 0.5 * (to.y & 1), to.y * 0.866)
	return WINDS[posmod(roundi((b - a).angle() / (PI / 4.0)), WINDS.size())]


## How long `steps` tiles take on foot, in the largest unit that fits, rounded: "5 hours", "1 day",
## "3 weeks". Rounded before it is compared, so 55 hours is a week and never "7 days".
static func walk_time(steps: int) -> String:
	var hours := maxi(steps, 1)
	if hours < HOURS_PER_DAY:
		return _count(hours, "hour")
	var days := roundi(float(hours) / HOURS_PER_DAY)
	if days < DAYS_PER_WEEK:
		return _count(days, "day")
	return _count(roundi(float(days) / DAYS_PER_WEEK), "week")


static func _count(amount: int, unit: String) -> String:
	return "%d %s%s" % [amount, unit, "" if amount == 1 else "s"]


## The nearest town of each tier to `from`, as tier -> spot, never `from` itself. A tier the world has
## none of is absent. One scan of every town in the world, so ask it on a press and never per frame.
static func nearest_towns(towns: TownWorld, from: Vector2i) -> Dictionary:
	var best := {}
	var best_steps := {}
	for spot in towns.towns():
		if spot == from:
			continue
		var tier := towns.tier_at(spot)
		var steps := HexGrid.distance(from, spot)
		if not best.has(tier) or steps < int(best_steps[tier]):
			best[tier] = spot
			best_steps[tier] = steps
	return best


## The roads reading: one sentence a tier, in the tiers' own order.
static func road_lines(towns: TownWorld, from: Vector2i) -> PackedStringArray:
	var lines := PackedStringArray()
	var nearest := nearest_towns(towns, from)
	for tier in TIER_WORDS.size():
		if not nearest.has(tier):
			lines.append("No other %s stands anywhere." % TIER_WORDS[tier])
			continue
		var spot: Vector2i = nearest[tier]
		lines.append("The nearest %s lies to the %s, about %s on foot." % [TIER_WORDS[tier],
				bearing(from, spot), walk_time(HexGrid.distance(from, spot))])
	return lines


## The uniques she could still show: neither found nor shown already.
static func hidden(found: Array, shown: Array) -> Array:
	var left := []
	for id: String in UniqueTable.ids():
		if not (id in found) and not (id in shown):
			left.append(id)
	return left


## One unique she has not shown and the player has not found, or "" when there is none left to show.
static func peek(found: Array, shown: Array, rng: RandomNumberGenerator) -> String:
	var left := hidden(found, shown)
	return "" if left.is_empty() else str(left[rng.randi_range(0, left.size() - 1)])


## Why she will not appraise this piece, or "" when she will.
static func why_not_appraise(item: Item) -> String:
	if item == null:
		return "Open a piece in your bag."
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
	for id in ModifierTable.pool_for(item.type):
		total += float(ModifierTable.MODS[id]["weight"])
	for id in ModifierTable.pool_for(item.type):
		var weight := int(ModifierTable.MODS[id]["weight"])
		rows.append({"id": id, "line": ModifierTable.band_line(id, item.level), "weight": weight,
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


## The uniques she has shown, by id.
static func peeked(fortunes: Dictionary) -> Array:
	var saved: Variant = fortunes.get(PEEKED, [])
	return saved if typeof(saved) == TYPE_ARRAY else []


static func scoured(fortunes: Dictionary) -> bool:
	return bool(fortunes.get(SCOURED, false))
