class_name VendorStock
extends RefCounted
## What a vendor has on its shelf. It gets more one way only: the player pays for a `reroll`.
##
## Six pieces or six orbs, rolled out of the drop tables leaning the player's way, written into the
## town's own drawer in `TownState` and never worked out from a seed again. A shelf is *rolled*, and
## the project's rule for rolled things is that they are written down: what a vendor happens to have
## is not a property of the world, it is something that happened to the player, and the next build's
## tables must not quietly restock a town they have already walked out of.
##
## Static and node-free like `OrbTable` and `TownPrices`, and it works on the plain Dictionary that
## `TownState.visit` hands back rather than on a class of its own -- so the shelf goes into the save
## with the town it belongs to, and nothing here has to know there is an `Inventory` above it.
##
## A bought square is emptied, not closed up: the shelf is always `SIZE` squares, and the empty one
## is what says the vendor has been shopped and is out of that thing until a reroll is paid for.

## How many things a vendor has. Six of each, so the shelf is a choice rather than a list: enough
## that there is something worth walking to, few enough that every square can be read at a glance.
const SIZE := 6

## The drawer's keys. Named here rather than in `TownState`, because what a shelf *is* is this file's
## business and the drawer is only where it sleeps.
const ITEMS := "items"
const ORBS := "orbs"
## How many times each shelf has ever been rerolled for gold, as `{ITEMS: n, ORBS: n}`. It is never
## reset -- a town remembers what it has been paid for the whole playthrough, so the price only
## climbs -- and the two vendors are two counters, and what one has been paid is not the
## other's price.
const REROLLS := "rerolls"


## Fills a town's shelves the first time it is walked into, and never again for free: a shelf turns
## over when the player pays for it (`reroll`) and at no other time. Says whether it did, so the
## caller knows whether the save has to be written.
##
## `tier` is a `TownWorld.Tier` and `cell` the town's own cell (what it is worth is what the ground
## around it is worth).
static func restock(drawer: Dictionary, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator) -> bool:
	if drawer.has(ITEMS):
		return false
	_fill(drawer, ITEMS, tier, cell, rng)
	_fill(drawer, ORBS, tier, cell, rng)
	return true


## One fresh shelf (`key` is `ITEMS` or `ORBS`), bought, which is the only way a shelf is ever new
## again. That shelf's own count goes up, which is what makes its next one dearer (`TownPrices.reroll_price`). The other vendor's shelf and
## price are untouched. The caller takes the gold; the purse is not this file's business.
static func reroll(drawer: Dictionary, key: String, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator) -> void:
	_fill(drawer, key, tier, cell, rng)
	var counts: Variant = drawer.get(REROLLS, null)
	if typeof(counts) != TYPE_DICTIONARY:
		counts = {}
		drawer[REROLLS] = counts
	(counts as Dictionary)[key] = rerolls(drawer, key) + 1


## How many times the `key` shelf has been rerolled for gold, ever.
static func rerolls(drawer: Dictionary, key: String) -> int:
	var counts: Variant = drawer.get(REROLLS, null)
	if typeof(counts) != TYPE_DICTIONARY:
		return 0
	var count: Variant = (counts as Dictionary).get(key, 0)
	return maxi(0, int(count)) if typeof(count) in [TYPE_INT, TYPE_FLOAT] else 0


## Six of one kind. One shelf at a time, in a fixed order on the first stocking, so a seed deals the
## same town twice.
static func _fill(drawer: Dictionary, key: String, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var shelf := []
	for i in SIZE:
		shelf.append(roll_item(tier, cell, rng).to_dict() if key == ITEMS else OrbTable.roll_favoured(rng))
	drawer[key] = shelf


## One piece for the shelf: the drop tables, leaning the player's way.
##
## Three leans, and all three are the tables already there rather than a second set of numbers. The
## type is drawn off `LootTable`'s own weights, so a shop deals in the same kinds a body does. The
## rarity is rolled off the tier *above* the rabble around the town -- a village trades as well as
## its elites do, a town and a fortress as well as a boss does -- so a vendor is a better class of
## luck rather than a different game. And the level is the **better of two rolls** under what that
## tier could drop here, which lifts the middle of the band without ever passing the ceiling the
## ground itself sets.
##
## What it is made of is the town's tile level's, the way a drop's is its tile's.
static func roll_item(tier: int, cell: Vector2i, rng: RandomNumberGenerator) -> Item:
	var carried := EnemyRoster.Tier.ELITE if tier == TownWorld.Tier.SMALL else EnemyRoster.Tier.BOSS
	var rarity := ItemRarity.roll(carried, rng)
	var ceiling := maxi(1, MapBuilder.level_of(cell) + int(LootTable.TIER_LEVEL[carried]))
	var level := maxi(ItemRarity.roll_level(rarity, ceiling, rng),
			ItemRarity.roll_level(rarity, ceiling, rng))
	return Item.rolled(LootTable._weighted(rng, MapBuilder.level_of(cell)), rarity, rng, level)


## The six pieces on the shelf, with a `null` where one has been bought. Empty for a town that has
## not been stocked, so a caller draws no squares at all rather than six ghosts.
static func items(drawer: Dictionary) -> Array:
	var shelf := []
	for entry: Variant in _shelf(drawer, ITEMS):
		shelf.append(Item.from_dict(entry))
	return shelf


## The six orbs, with "" where one has been bought. Duplicates are allowed and ordinary: an orb is a
## count, so two of the same on one shelf is two of the same thing to sell.
static func orbs(drawer: Dictionary) -> PackedStringArray:
	var shelf := PackedStringArray()
	for entry: Variant in _shelf(drawer, ORBS):
		shelf.append(str(entry) if OrbTable.ORBS.has(str(entry)) else "")
	return shelf


## Takes what was bought off the shelf. The square stays and is simply empty until a reroll --
## a shelf that closed up behind a purchase would say six were never there.
##
## One emptying for both shelves: "" is not a piece and not an orb this build has, so both readers
## already give back nothing for it.
static func take(drawer: Dictionary, key: String, index: int) -> void:
	var saved: Variant = drawer.get(key, null)
	if typeof(saved) != TYPE_ARRAY or index < 0 or index >= (saved as Array).size():
		return
	(saved as Array)[index] = ""


## Writes a shelf piece back where it stood, after the player has spent an orb of their own on it.
## `items` hands out fresh `Item`s every time, so a change to one is lost unless it is put back.
static func put(drawer: Dictionary, index: int, item: Item) -> void:
	var shelf := _shelf(drawer, ITEMS)
	if index >= 0 and index < shelf.size():
		shelf[index] = item.to_dict()


## A saved shelf, or nothing at all when the file does not hold one of the right size -- a town never
## visited, or a save edited by hand. Nothing here guesses at a half-written shelf: the vendor is out
## of stock until a reroll, which is the one state that needs no repair.
static func _shelf(drawer: Dictionary, key: String) -> Array:
	var saved: Variant = drawer.get(key, null)
	if typeof(saved) != TYPE_ARRAY or (saved as Array).size() != SIZE:
		return []
	return saved
