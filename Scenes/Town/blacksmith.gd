class_name Blacksmith
extends RefCounted
## The smith: the two things he does to a piece, each as `OrbTable`'s three faces -- the rule
## that lights a button (`can_*`), the act, and the reason it is grey (`why_not_*`). Static and
## node-free; what either act costs is `TownPrices`'s.
##
## He is the one exception to "a piece's level and base stats never change". An **upgrade** raises the
## level by one, rewrites the base stats to what a fresh roll at that level would carry
## (`Item.scaled_stats`), and leaves every modifier as it was, tier and number (the user's ruling,
## 2026-09-28; what does move is `Item.level_up`'s). A **lock** pins one modifier to the piece.
##
## The cap an upgrade stops at is handed in: it is the town's wall circle's, and this file never names
## the map.

## How often the hammer ruins a piece instead: the gold is spent all the same, the level and the stats
## are untouched, and the piece is marked `broken`. There is deliberately no safer, dearer upgrade.
const BREAK_CHANCE := 0.05

## What he says about a piece he has already ruined. `OrbTable` and the black screen's Make heirloom
## (`BagPage`) say the same in their own words on purpose: the items know nothing about towns.
const BROKEN := "It's broken. Not my job to mend it."


## Whether this piece can be taken one level higher here; `cap` is the deepest level this town's wall
## circle allows. An heirloom under its `safe_level` is not his: it climbs there by itself as the land
## is charted (`Inventory.raise_heirlooms`).
static func can_upgrade(item: Item, cap: int) -> bool:
	return item != null and not item.broken and item.level < cap and item.level >= item.safe_level


## Short sentences: the counter is three shelf squares wide and a long one wraps to three lines on it.
static func why_not_upgrade(item: Item, cap: int) -> String:
	if item == null or can_upgrade(item, cap):
		return ""
	if item.broken:
		return BROKEN
	if item.level < item.safe_level:
		return "It climbs to level %d on its own" % item.safe_level
	return "Level %d is the most here" % maxi(cap, 1)


## One blow. True when the piece came out a level higher, false when it broke -- and **the caller pays
## either way**. Ask `can_upgrade` before charging: a refusal comes back false as well, and nothing
## here can tell the two apart afterwards.
static func upgrade(item: Item, cap: int, rng: RandomNumberGenerator) -> bool:
	if not can_upgrade(item, cap):
		return false
	if rng.randf() < BREAK_CHANCE:
		item.broken = true
		return false
	item.level_up()
	return true


## One lock to a piece, and none on a piece with no modifiers or on one the hammer has ruined.
static func can_lock(item: Item) -> bool:
	return (item != null and not item.broken and not item.mods.is_empty()
			and item.locked_mod().is_empty())


static func why_not_lock(item: Item) -> String:
	if item == null or can_lock(item):
		return ""
	if item.broken:
		return BROKEN
	if not item.locked_mod().is_empty():
		return "One lock to an item"
	return "Nothing here to lock"


## Pins one modifier, drawn at random from what the piece carries: the smith picks, not the player, so
## a lock is a bet on the line that came up and never the last step of every craft. Never breaks.
static func lock(item: Item, rng: RandomNumberGenerator) -> bool:
	if not can_lock(item):
		return false
	item.hold(rng.randi_range(0, item.mods.size() - 1), "locked")
	return true
