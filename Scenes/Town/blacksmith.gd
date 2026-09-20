class_name Blacksmith
extends RefCounted
## The fortress smith: the two things he does to a piece, and the sentence he says when he will not.
##
## The same three faces `OrbTable` keeps in one file -- the rule that lights a button (`can_*`), the
## act itself, and the reason it is grey (`why_not_*`) -- because they are one piece of knowledge and
## splitting them over three files is how they come to disagree. Static and node-free like
## `TownPrices` and `VendorStock`, so the tests need no interface to hammer against; what either act
## costs is `TownPrices`'s business, because a price is made in one place.
##
## He is the one exception to "a piece's level and base stats never change". An **upgrade** raises the
## level by one, rewrites the base stats to exactly what a fresh roll at that level would have carried
## (`Item.scaled_stats`), and **rolls every modifier's number again in its band at the new level**
## (`OrbTable.reroll_values`, the Divine orb's own act) -- so the whole piece comes off the anvil at
## its new level, and the blow is a gamble with the good rolls as well as with the piece. What a lock
## or an Orb of Binding holds fast is not rerolled, which is what a lock is bought for. A **lock**
## pins one modifier to the piece, and every orb then works around it.
##
## The cap an upgrade stops at is handed in rather than worked out here: it belongs to the ground the
## town stands on, the same ceiling a vendor's shelf rolls under, and this file has no business
## knowing what a map is.

## How often the hammer ruins a piece rather than improving it. The upgrade fails, the gold is spent
## all the same, the level and the stats are untouched, and the piece is marked `broken`.
##
## One in twenty is a risk rather than a gamble: an upgrade is worth pressing without thinking about
## it, and a piece walked five levels up the map is a piece that survived a real chance of ruin, which
## is what makes it worth something. It is deliberately not a chance the player can buy off -- there
## is no safer, dearer upgrade, because two buttons would turn every press into a sum.
const BREAK_CHANCE := 0.05

## What he says about a piece he has already ruined. `OrbTable` says the same thing in its own words
## rather than reading it from here: the items know nothing about towns, and that is worth more than
## one shared sentence.
const BROKEN := "This piece is broken."


## Whether this piece can be taken one level higher here. `cap` is the deepest level this ground
## allows, which is what keeps a smith from walking gear past the frontier the player has reached.
static func can_upgrade(item: Item, cap: int) -> bool:
	return item != null and not item.broken and item.level < cap


## Why the hammer is grey, or "" when it is not. Short sentences: the counter is three shelf squares
## wide and a long one wraps to three lines on it.
static func why_not_upgrade(item: Item, cap: int) -> String:
	if item == null or can_upgrade(item, cap):
		return ""
	if item.broken:
		return BROKEN
	return "Level %d is the most here." % maxi(cap, 1)


## How likely the next blow is to ruin this piece. Nothing while an heirloom is being walked back up
## to the level it had in the world it came out of (`Item.safe_level`): that road was paid for once.
## Past it, and for every piece that never was an heirloom, the hammer is the hammer.
static func break_chance(item: Item) -> float:
	return 0.0 if item.level < item.safe_level else BREAK_CHANCE


## One blow. True when the piece came out a level higher, false when it broke -- and **the caller
## pays either way**, which is the whole of what `BREAK_CHANCE` means. Ask `can_upgrade` before
## charging: a refusal comes back false as well, and nothing here can tell the two apart afterwards.
static func upgrade(item: Item, cap: int, rng: RandomNumberGenerator) -> bool:
	if not can_upgrade(item, cap):
		return false
	# No roll at all where nothing can break, so a seeded rng is spent only on a real risk.
	var risk := break_chance(item)
	if risk > 0.0 and rng.randf() < risk:
		item.broken = true
		return false
	item.level += 1
	# Exactly what a fresh roll at the new level would carry, base stats and modifier numbers alike.
	# Both after the level moves, because both are read at it.
	item.stats = Item.scaled_stats(item.type, item.level)
	OrbTable.reroll_values(item, rng)
	item.refresh_perfect()
	return true


## Whether one of this piece's modifiers can be pinned to it. One lock to a piece, and nothing on a
## piece with no modifiers or on one the hammer has ruined.
static func can_lock(item: Item) -> bool:
	return (item != null and not item.broken and not item.mods.is_empty()
			and item.locked_mod().is_empty())


static func why_not_lock(item: Item) -> String:
	if item == null or can_lock(item):
		return ""
	if item.broken:
		return BROKEN
	if not item.locked_mod().is_empty():
		return "One lock to a piece."
	return "Nothing here to lock."


## Pins one modifier, drawn at random from what the piece carries. The smith picks, not the player:
## being able to choose the line would make a lock the last step of every craft rather than a bet on
## the one that came up, and it is priced as the second. Locking never breaks anything.
static func lock(item: Item, rng: RandomNumberGenerator) -> bool:
	if not can_lock(item):
		return false
	item.mods[rng.randi_range(0, item.mods.size() - 1)]["locked"] = true
	return true
