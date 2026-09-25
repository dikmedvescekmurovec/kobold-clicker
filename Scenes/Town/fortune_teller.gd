class_name FortuneTeller
extends RefCounted
## The fortuneteller: what she can be asked, and what she answers.
##
## Every settlement has her, and she is the one counter that sells nothing to carry: what she sells is
## knowledge the game used to give away or never gave at all. Five **readings** -- where the nearest
## settlements lie, where a chest is, where the accepted bounty's monster lives, what one unique not
## yet found is and where it drops, and what a piece could still roll -- each asked as often as the
## player will pay for it, the price doubling every time; and two **great spells**, one a settlement:
## a patch of the map lifted out of the dark, and the road home walked in no time at all.
##
## Static and node-free like `Blacksmith`, so the tests need no interface. What a spell costs is
## `TownPrices.fortune_price`'s business. What was bought is written where it belongs: what a town has
## sold in that town's drawer (`ASKED`), the bounty's location on the posting, and what belongs to the
## player rather than to a town -- the chest, the peeked uniques, and how often each reading has been
## asked -- in `inventory.fortunes`, a plain Dictionary this file holds the keys of, because
## `Inventory` must not name a class that names `Item`'s tables back at it.

## The readings, which are also the keys of `TownPrices.FORTUNE_BODIES`.
const ROADS := "roads"
const TREASURE := "treasure"
const QUARRY := "quarry"
const RELIC := "relic"
const APPRAISE := "appraise"
const SCOUR := "scour"
const HOMECOMING := "homecoming"
## Not a reading at all but the way out of the world: everything is left behind but the heirlooms
## (`Inventory.transcended`). She offers it only once a wall has fallen, and it is priced against the
## ground behind the first wall rather than the town's (`TownPrices.fortune_price`).
const TRANSCEND := "transcend"
## The order her buttons stand in: the readings first, then the great spells, then the way out.
const READINGS := [ROADS, TREASURE, QUARRY, RELIC, APPRAISE, SCOUR, HOMECOMING, TRANSCEND]

## Her list is in two halves, and which half a spell is in is the whole of its rule.
##
## A **reading** is asked as often as the player likes, anywhere: the price starts at the town's own
## level and doubles with every casting in this world (`TownPrices.FORTUNE_GROWTH`, the count in
## `inventory.fortunes` under `CAST`). A **great spell** is one a settlement, the way every reading
## used to be: it is written in that town's drawer under `ASKED` and refused there from then on.
##
## Written out rather than derived from `READINGS`, which is the grid's order; `test_town` holds the
## three lists together.
const COMMON := [ROADS, TREASURE, QUARRY, RELIC, APPRAISE]
const GREAT := [SCOUR, HOMECOMING]

## What each reading's button says.
const LABELS := {
	ROADS: "Roads",
	TREASURE: "Treasure",
	QUARRY: "Quarry",
	RELIC: "Relic",
	APPRAISE: "Appraise",
	SCOUR: "Scour",
	# "Homecoming" is two letters wider than a shelf square, and a name on her grid is clipped rather
	# than allowed to widen the page.
	HOMECOMING: "Return",
	TRANSCEND: "Transcend",
}

## The town drawer's key, before a spell's name: a `GREAT` spell is sold once a settlement and refused
## there from then on. The roads write it too, and it means the other thing there: paid for once, they
## are told again for nothing.
const ASKED := "fortune_"
## `inventory.fortunes`' keys.
const CHEST := "chest"
const PEEKED := "peeked"
## reading -> how many times it has been asked in this world, which is what doubles a reading's price.
const CAST := "cast"

## How far round the chosen tile the scour reaches: the tile and two rings, nineteen in all.
const SCOUR_RADIUS := 2

## What she says about a piece whose modifiers are its row's and nothing else's.
const WRITTEN := "Its lines are already written."


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


## The uniques she has shown, by id.
static func peeked(fortunes: Dictionary) -> Array:
	var saved: Variant = fortunes.get(PEEKED, [])
	return saved if typeof(saved) == TYPE_ARRAY else []


## Whether `reading` has been paid for in the town whose drawer this is: a great spell spent here, or
## the roads already told here and so told again for nothing.
static func asked(drawer: Dictionary, reading: String) -> bool:
	return bool(drawer.get(ASKED + reading, false))


## How many times `reading` has been asked in this world. Read through `int()`, because JSON hands
## whole numbers back as floats.
static func cast(fortunes: Dictionary, reading: String) -> int:
	var counts: Variant = fortunes.get(CAST, {})
	return int((counts as Dictionary).get(reading, 0)) if typeof(counts) == TYPE_DICTIONARY else 0


## One more casting of `reading`, which is what makes the next one dearer.
static func note_cast(fortunes: Dictionary, reading: String) -> void:
	if typeof(fortunes.get(CAST, null)) != TYPE_DICTIONARY:
		fortunes[CAST] = {}
	fortunes[CAST][reading] = cast(fortunes, reading) + 1
