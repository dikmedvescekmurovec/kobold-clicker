class_name TownPrices
extends RefCounted
## What everything in a town costs, in bodies' worth of gold.
##
## One file, because a price the player pays and a price the player is paid have to be read against
## each other or a town turns into a loop that prints money. Everything here is built on
## `gold_at_level`, which is what a body on the first tile of that level band carries
## (`Encounter.gold_at_steps`, and level `n` starts at the nth triangular number of steps -- see
## `MapBuilder.level_of`). So every number below is "this many bodies", and the dials are the
## multipliers rather than the gold, which means retuning the purse retunes the shops with it.
##
## Static and node-free like `OrbTable`, so the tests need no interface to read a price off.

## What a common piece at its own level fetches, in bodies. A bag of forty pieces at the level the
## player is fighting is worth a couple of minutes' farming, which is meant to be worth the walk and
## never worth farming *for*: the gear is the prize and the gold is what is left of the gear you
## already have.
const SELL_BODIES := 3.0

## What a vendor pays against what it asks, so buying back what you sold costs five times what it
## paid and there is no loop at one counter. It is the one dial that moves the two directions against
## each other: down, a shelf is dearer and a bag of finds fetches less, which is both halves of
## "selling is a side income and a shelf is an errand".
const SELL_SHARE := 0.20

## What one level off the smith's hammer costs, in bodies at the piece's **own** level -- so walking
## a piece up the map gets dearer with every step, the way the ground it is walking towards does.
## Twenty bodies is a little more than buying a plain piece off a shelf (twelve) and a fraction of
## buying a good one, which is the shape it should have: an upgrade is worth doing to a piece you
## already want, and never worth doing to one you would otherwise sell.
const UPGRADE_BODIES := 20.0

## And what a lock costs. The largest dial in the game by a distance: a locked modifier is the only
## thing in it that cannot be rolled away, so paying for one has to be a season's farming rather than
## an afternoon's, or every piece ends up carrying one and the orbs stop meaning anything. Two and a
## half thousand bodies is about 250 ordinary tile fights at any depth (`tests/balance_town.gd`).
const LOCK_BODIES := 2500.0

## What the commonest orb is worth, in bodies, at the town it is sold in. The rarer orbs climb off it
## by `orb_value`, so the whole table is this one number and `OrbTable`'s own weights.
const ORB_BODIES := 4.0

## What clearing a town's shelves for fresh stock costs the first time, in bodies at the town's level,
## and what every reroll this town has ever sold multiplies that by (the count is never reset). Thirty bodies is two plain
## pieces off the shelf being thrown away; doubling is what stops a purse being stood at a counter and
## turned into the one piece it wants -- the sixth reroll costs what thirty-two firsts do.
const REROLL_BODIES := 30.0
const REROLL_GROWTH := 2.0

## What each rarity step multiplies a piece's price by, indexed by `ItemRarity.Rarity`'s own order:
## common, uncommon, rare, elite, unique. A list rather than a Dictionary keyed by the enum, because a
## `const` naming another class's enum is where Godot's cycle checker bites (see `Scenes/Items/CLAUDE.md`).
##
## It climbs far faster than the modifier count does, roughly two and a half times a step, because
## what a player is paid for a rare has to feel like the find it was and because this is also what a
## shelf charges: a common is a crafting base worth a fight, an elite off a shelf is a fortnight's
## errand. A common is meant to be worth selling in bulk rather than one at a time.
const RARITY_MULT := [1.0, 2.0, 5.0, 14.0, 24.0]

## The largest weight in `OrbTable.ORBS`, which is the orb every other orb's price is read against.
## Worked out once: the tray is redrawn on every kill.
static var _commonest := 0.0


## What a body on the first tile of level `level` carries. The unit every price in a town is quoted in.
static func gold_at_level(level: int) -> float:
	var at := maxi(level, 1)
	@warning_ignore("integer_division")  # n(n - 1) is always even, so the triangular number is whole
	var steps := at * (at - 1) / 2
	return Encounter.gold_at_steps(steps)


## What a merchant pays for a piece: its own level's body worth, times its rarity, times the dial.
## The piece's level and not the town's -- what is being bought is the piece, and carrying a deep find
## back to the village you started at should not be worth less than selling it where you found it.
## A broken piece fetches half: it is still worth wearing and still worth selling, and the merchant
## knows as well as the player does that nothing can be done with it again.
static func sell_price(item: Item) -> float:
	if item == null:
		return 0.0
	var step := float(RARITY_MULT[item.rarity]) if item.rarity < RARITY_MULT.size() else 1.0
	if item.broken:
		step *= 0.5
	return maxf(1.0, roundf(gold_at_level(item.level) * step * SELL_BODIES))


## What a merchant asks for a piece off its own shelf: what it would pay for one, the other way up.
##
## The same `SELL_SHARE` the orbs are quoted at, and the whole of why there is no loop to stand in at
## one counter -- buying back what was just sold costs five times what it fetched. Read off
## `sell_price` rather than written out again, so the two can never be tuned apart.
static func buy_price(item: Item) -> float:
	var paid := sell_price(item)
	return 0.0 if paid <= 0.0 else maxf(1.0, roundf(paid / SELL_SHARE))


## What the smith asks to take a piece one level up: the piece's own level in bodies, times the dial.
## The level it is at rather than the one it is going to, so the quote on the button is read against
## the piece the player is looking at.
static func upgrade_price(item: Item) -> float:
	return 0.0 if item == null else maxf(1.0, roundf(gold_at_level(item.level) * UPGRADE_BODIES))


## And what he asks to pin a modifier to it, off the same level and the same curve -- so a lock is
## always the same number of upgrades, wherever in the map it is bought.
static func lock_price(item: Item) -> float:
	return 0.0 if item == null else maxf(1.0, roundf(gold_at_level(item.level) * LOCK_BODIES))


## What the town on `town_cell` asks to clear its shelves and fill them again, having done so `rerolls`
## times already. Pegged to the town, as an orb is: what is being bought
## is that town's stock.
static func reroll_price(town_cell: Vector2i, rerolls: int) -> float:
	return maxf(1.0, roundf(gold_at_level(MapBuilder.level_of(town_cell)) * REROLL_BODIES
			* pow(REROLL_GROWTH, maxi(rerolls, 0))))


## What a whole handful is worth, for the button that sells a level at once.
static func sell_total(items: Array) -> float:
	var total := 0.0
	for item: Item in items:
		total += sell_price(item)
	return total


## What an orb is worth at the town standing on `town_cell`: inverse to how often one falls, so the
## Exalted orb nobody sees is worth eight Transmutation orbs and the table needs no second set of
## numbers to keep in step with the drop rates.
##
## Pegged to the town rather than to the orb, because an orb has no level of its own -- what makes one
## worth more out at the frontier is that everything out there is.
static func orb_value(orb: String, town_cell: Vector2i) -> float:
	if not OrbTable.ORBS.has(orb):
		return 0.0
	var weight := float(OrbTable.ORBS[orb]["weight"])
	if weight <= 0.0:
		return 0.0
	return maxf(1.0, roundf(gold_at_level(MapBuilder.level_of(town_cell)) * ORB_BODIES * commonest() / weight))


## What a vendor pays for one orb: `SELL_SHARE` of what it asks, the same share gear is sold at.
static func orb_sell_price(orb: String, town_cell: Vector2i) -> float:
	var value := orb_value(orb, town_cell)
	return 0.0 if value <= 0.0 else maxf(1.0, roundf(value * SELL_SHARE))


## The weight of the orb that falls most often, which every other orb's price is a multiple of.
static func commonest() -> float:
	if _commonest <= 0.0:
		for orb: String in OrbTable.ORBS:
			_commonest = maxf(_commonest, float(OrbTable.ORBS[orb]["weight"]))
	return _commonest
