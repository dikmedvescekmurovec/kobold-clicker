class_name VendorStock
extends RefCounted
## What a vendor has on its shelf, and when it gets more.
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
## is what says the vendor has been shopped and is out of that thing until the restock.

## How many things a vendor has. Six of each, so the shelf is a choice rather than a list: enough
## that there is something worth walking to, few enough that every square can be read at a glance.
const SIZE := 6

## How many kills stand between one stocking and the next. Ten tiles' worth of fighting
## (`Encounter.ENEMIES` is ten), so a vendor is worth calling on again after a proper session out and
## never worth standing next to and re-rolling. The dial for how often a shelf is new.
const RESTOCK_KILLS := 100

## The drawer's keys. Named here rather than in `TownState`, because what a shelf *is* is this file's
## business and the drawer is only where it sleeps.
const ITEMS := "items"
const ORBS := "orbs"
## The player's lifetime kill count when the shelf was last filled, which is what a restock is
## counted from. An absent key is a town whose shelves have never been filled at all.
const STOCKED_AT := "stocked_at"
## How many times each shelf has ever been rerolled for gold, as `{ITEMS: n, ORBS: n}`. It is never
## reset -- a town remembers what it has been paid for the whole playthrough, so the price only
## climbs -- and the two vendors are two counters, and what one has been paid is not the
## other's price.
const REROLLS := "rerolls"


## Fills a town's shelves if they have never been filled or the restock is due, and says whether it
## did -- so the caller knows whether the save has to be written.
##
## `tier` is a `TownWorld.Tier`, `cell` the town's own cell (what it is worth is what the ground
## around it is worth) and `kills` the player's lifetime count.
static func restock(drawer: Dictionary, tier: int, cell: Vector2i, kills: int,
		rng: RandomNumberGenerator) -> bool:
	if drawer.has(STOCKED_AT) and kills_left(drawer, kills) > 0:
		return false
	_fill(drawer, ITEMS, tier, cell, rng)
	_fill(drawer, ORBS, tier, cell, rng)
	drawer[STOCKED_AT] = maxi(kills, 0)
	# `REROLLS` is left alone: a free restock does not forgive what the town has already been paid.
	return true


## One fresh shelf (`key` is `ITEMS` or `ORBS`) bought rather than waited for. The kills clock is left
## where it was -- paying does not put the free restock off -- and that shelf's own count goes up,
## which is what makes its next one dearer (`TownPrices.reroll_price`). The other vendor's shelf and
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


## Six of one kind. One shelf at a time, in a fixed order on a free restock, so a seed deals the same
## town twice.
static func _fill(drawer: Dictionary, key: String, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator) -> void:
	var shelf := []
	for i in SIZE:
		shelf.append(roll_item(tier, cell, rng).to_dict() if key == ITEMS else OrbTable.roll_favoured(rng))
	drawer[key] = shelf


## One piece for the shelf: the drop tables, leaning the player's way.
##
## Three leans, and all three are the tables already there rather than a second set of numbers. The
## type is drawn off `LootTable`'s own weights, so a shop deals in the same eight pieces a body does.
## The rarity is rolled off the tier *above* the rabble around the town -- a village trades as well
## as its elites do, a town and a fortress as well as a boss does -- so a vendor is a better class of
## luck rather than a different game. And the level is the **better of two rolls** under what that
## tier could drop here, which lifts the middle of the band without ever passing the ceiling the
## ground itself sets.
static func roll_item(tier: int, cell: Vector2i, rng: RandomNumberGenerator) -> Item:
	var carried := EnemyRoster.Tier.ELITE if tier == TownWorld.Tier.SMALL else EnemyRoster.Tier.BOSS
	var rarity := ItemRarity.roll(carried, rng)
	var ceiling := maxi(1, MapBuilder.level_of(cell) + int(LootTable.TIER_LEVEL[carried]))
	var level := maxi(ItemRarity.roll_level(rarity, ceiling, rng),
			ItemRarity.roll_level(rarity, ceiling, rng))
	return Item.rolled(LootTable._weighted(rng), rarity, rng, level)


## How many more kills before the shelves are filled again. 0 the moment they are due, and 0 for a
## town whose shelves have never been filled -- both of which mean "stock it now".
static func kills_left(drawer: Dictionary, kills: int) -> int:
	var since: Variant = drawer.get(STOCKED_AT, null)
	if not (typeof(since) in [TYPE_INT, TYPE_FLOAT]):
		return 0
	return maxi(0, RESTOCK_KILLS - (maxi(kills, 0) - int(since)))


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


## Takes what was bought off the shelf. The square stays and is simply empty until the restock --
## a shelf that closed up behind a purchase would say six were never there.
##
## One emptying for both shelves: "" is not a piece and not an orb this build has, so both readers
## already give back nothing for it.
static func take(drawer: Dictionary, key: String, index: int) -> void:
	var saved: Variant = drawer.get(key, null)
	if typeof(saved) != TYPE_ARRAY or index < 0 or index >= (saved as Array).size():
		return
	(saved as Array)[index] = ""


## A saved shelf, or nothing at all when the file does not hold one of the right size -- a town never
## visited, or a save edited by hand. Nothing here guesses at a half-written shelf: the vendor is out
## of stock until the restock, which is the one state that needs no repair.
static func _shelf(drawer: Dictionary, key: String) -> Array:
	var saved: Variant = drawer.get(key, null)
	if typeof(saved) != TYPE_ARRAY or (saved as Array).size() != SIZE:
		return []
	return saved
