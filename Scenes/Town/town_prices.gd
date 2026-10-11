class_name TownPrices
extends RefCounted
## What everything in a town costs. One file, so a price paid and a price fetched are read against each
## other and no counter is a loop. Every price is a number of bodies times a dial below, a body being
## `gold_at_level`: nothing here writes a figure in gold, so retuning the purse retunes the shops.
## Why each dial stands where it does is DESIGN.md's ("Everything is priced in bodies").

## What a common piece at its own level fetches, in bodies.
const SELL_BODIES := 3.0

## What a vendor pays against what it asks: the one dial that moves the two directions against each
## other. Buying back what was sold costs five times what it paid.
const SELL_SHARE := 0.20

## One level off the smith's hammer, and a lock, in bodies at the piece's **own** level. The lock was
## cut tenfold from 2500 by the user (2026-09-28).
const UPGRADE_BODIES := 20.0
const LOCK_BODIES := 250.0

## What the commonest orb is worth, in bodies at the town it is sold in; the rarer climb off it by
## `orb_value`.
const ORB_BODIES := 4.0

## A shelf's first reroll, in bodies at the town's level, and what every reroll that shelf has ever sold
## multiplies it by (the count is never reset).
const REROLL_BODIES := 30.0
const REROLL_GROWTH := 2.0

## What the fortuneteller asks for a spell, in bodies at the town's level, the same every time. The keys
## are `FortuneTeller`'s reading names as literals: a `const` naming another class's const is where
## Godot's cycle checker bites (`test_town` holds the two lists together).
## **Transcending and banishing are not at the town's level** but on the ground just behind the first
## wall (`transcend_steps`), the same in every town and world; banishing (the user's, 2026-10-10) is the
## one that climbs, `FORTUNE_GROWTH` times the last for every one paid for in this world.
const FORTUNE_BODIES := {
	"roads": 300.0,
	"treasure": 60.0,
	"appraise": 15.0,
	"scour": 1000.0,
	"homecoming": 200.0,
	"transcend": 2000.0,
	"banish": 200.0,
}
const FORTUNE_GROWTH := 2.0

## What each rarity step multiplies a piece's price by, indexed by `ItemRarity.Rarity`'s own order:
## common, uncommon, rare, elite, unique. A list, not a Dictionary keyed by the enum, for the cycle
## checker's sake again (see `Scenes/Items/CLAUDE.md`).
const RARITY_MULT := [1.0, 2.0, 5.0, 14.0, 24.0]

## `commonest()`, worked out once: the tray is redrawn on every kill.
static var _commonest := 0.0


## What a body on the first tile of level `level` carries. The unit every price in a town is quoted in.
static func gold_at_level(level: int) -> float:
	return Encounter.gold_at_steps(MapBuilder.first_step(level))


## The same at the town on `town_cell`: what an orb, a reroll and a reading are pegged to, having no
## level of their own.
static func gold_at_town(town_cell: Vector2i) -> float:
	return gold_at_level(MapBuilder.level_of(town_cell))


## A price in whole coins, never less than one.
static func _coins(gold: float) -> float:
	return maxf(1.0, roundf(gold))


## What a merchant pays for a piece: its **own** level's body worth, not the town's, times its rarity,
## times the dial. A broken piece fetches half.
static func sell_price(item: Item) -> float:
	if item == null:
		return 0.0
	var step := float(RARITY_MULT[item.rarity]) if item.rarity < RARITY_MULT.size() else 1.0
	if item.broken:
		step *= 0.5
	return _coins(gold_at_level(item.level) * step * SELL_BODIES)


## What the Rag and Bone Sack pays for a piece thrown away: `share` of what a trader would give (its
## rank's). Here because every figure in gold is made here.
static func salvage_price(item: Item, share: float) -> float:
	return _coins(sell_price(item) * share)


## What a merchant asks for a piece off its own shelf: `sell_price` the other way up, never a second
## figure, so the two can never be tuned apart.
static func buy_price(item: Item) -> float:
	var paid := sell_price(item)
	return 0.0 if paid <= 0.0 else _coins(paid / SELL_SHARE)


## What the smith asks to take a piece one level up, off the level it is at, not the one it is going to.
static func upgrade_price(item: Item) -> float:
	return 0.0 if item == null else _coins(gold_at_level(item.level) * UPGRADE_BODIES)


static func lock_price(item: Item) -> float:
	return 0.0 if item == null else _coins(gold_at_level(item.level) * LOCK_BODIES)


## What the town on `town_cell` asks to clear a shelf and fill it again, having done so `rerolls` times
## already.
static func reroll_price(town_cell: Vector2i, rerolls: int) -> float:
	return _coins(gold_at_town(town_cell) * REROLL_BODIES * pow(REROLL_GROWTH, maxi(rerolls, 0)))


## What the fortuneteller in the town on `town_cell` asks for `reading`; 0 for one this build does not
## have. `cast` is how many times it has been paid for already, which only the banishing counts.
static func fortune_price(reading: String, town_cell: Vector2i, cast := 0) -> float:
	if not FORTUNE_BODIES.has(reading):
		return 0.0
	var bodies := float(FORTUNE_BODIES[reading])
	if reading == "transcend" or reading == "banish":
		return _coins(Encounter.gold_at_steps(transcend_steps()) * bodies * pow(FORTUNE_GROWTH, maxi(cast, 0)))
	return _coins(gold_at_town(town_cell) * bodies)


## How far from the middle of the map the ground is that transcending is priced on: one step past
## the ring the first wall stood on. A function, for the cycle checker's sake.
static func transcend_steps() -> int:
	return MapBuilder.START_LAND_RADIUS + 2


## What a whole handful is worth, for the button that sells a level at once.
static func sell_total(items: Array) -> float:
	var total := 0.0
	for item: Item in items:
		total += sell_price(item)
	return total


## What a vendor asks for an orb at the town on `town_cell`: inverse to how often one falls, so the drop
## rates are the only table of orb values there is.
static func orb_value(orb: String, town_cell: Vector2i) -> float:
	if not OrbTable.ORBS.has(orb):
		return 0.0
	var weight := float(OrbTable.ORBS[orb]["weight"])
	if weight <= 0.0:
		return 0.0
	return _coins(gold_at_town(town_cell) * ORB_BODIES * commonest() / weight)


## The largest weight in `OrbTable.ORBS`, which every other orb's price is read against.
static func commonest() -> float:
	if _commonest <= 0.0:
		for orb: String in OrbTable.ORBS:
			_commonest = maxf(_commonest, float(OrbTable.ORBS[orb]["weight"]))
	return _commonest
