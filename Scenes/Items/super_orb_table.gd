class_name SuperOrbTable
extends RefCounted
## The six super orbs: what each does to an heirloom, at a transcension and nowhere else.
##
## `OrbTable`'s shape -- a const table and `can_apply` / `why_not` / `apply` as three faces of one
## rule -- and a table of its own rather than six more rows in that one, because nothing `OrbTable`
## does with a row is wanted here: these never drop, never stand on a vendor's shelf, are never sold,
## and are not counted one by one. **There is one count for all six** (`Inventory.super_orbs`, a wall
## broken is one), spent on whichever is pressed.
##
## Three of them are **aimed**: they work on one modifier, which the player chooses, so `apply` takes
## its index and `can_aim` says which lines may be chosen.
##
## What they leave on a piece is the piece's own (`Item.plus`, `Item.extra_slot`, a modifier's
## `"perfect"` and `"bound"`), saved with it, and honoured by the ordinary orbs and the smith ever
## after: that is `OrbTable`'s and `Blacksmith`'s business, through `Item.held_fast`,
## `Item.refresh_perfect` and `Item.mod_level`.

const REPLACEMENT := "Orb of Replacement"
const ASCENSION := "Orb of Ascension"
const PERFECTION := "Orb of Perfection"
const EXPANSION := "Orb of Expansion"
const MENDING := "Orb of Mending"
const BINDING := "Orb of Binding"

## In the tray's order. `does` is the whole explanation of one, as `OrbTable`'s is; `aimed` is whether
## a modifier has to be chosen for it. The icons are `tools/ui_kit.py`'s, the crystals of the sheet
## the ordinary orbs are the stones of.
const ORBS := {
	REPLACEMENT: {
		"aimed": true,
		"does": "Replaces the modifier you choose with another, freshly rolled.",
	},
	ASCENSION: {
		"aimed": false,
		"does": "Makes the item +1 for good: every modifier on it rolls as if the item were %d levels higher. It can be done again and again.",
	},
	PERFECTION: {
		"aimed": true,
		"does": "Puts the modifier you choose at the top of its range, and it stays there whatever is done to the item afterwards.",
	},
	EXPANSION: {
		"aimed": false,
		"does": "Adds one modifier more than the item's rarity allows. Once per item.",
	},
	MENDING: {
		"aimed": false,
		"does": "Makes a broken item whole again.",
	},
	BINDING: {
		"aimed": true,
		"does": "Locks the modifier you choose so that no orb can move it, beside whatever a smith has locked. Once per item.",
	},
}

static var _icons := {}


static func orbs() -> Array:
	return ORBS.keys()


static func has(orb: String) -> bool:
	return ORBS.has(orb)


static func icon(orb: String) -> Texture2D:
	if not _icons.has(orb):
		_icons[orb] = load(OrbTable.ROOT + orb + ".png")
	return _icons[orb]


static func describe(orb: String) -> String:
	var text := str(ORBS[orb]["does"])
	return text % Item.PLUS_LEVELS if "%d" in text else text


static func aimed(orb: String) -> bool:
	return bool(ORBS[orb]["aimed"])


## Whether this orb has anything to do to this piece -- for an aimed one, to any line of it.
static func can_apply(orb: String, item: Item) -> bool:
	return why_not(orb, item).is_empty()


## Whether an aimed orb may be pointed at `item.mods[index]`.
static func can_aim(orb: String, item: Item, index: int) -> bool:
	if item == null or index < 0 or index >= item.mods.size():
		return false
	var mod := item.mods[index]
	match orb:
		REPLACEMENT, BINDING:
			return not Item.held_fast(mod)
		PERFECTION:
			return not bool(mod.get("perfect", false))
	return false


## Why this orb is greyed out, "" when it is not. The one rule: `can_apply` is this, empty.
static func why_not(orb: String, item: Item) -> String:
	if item == null or not ORBS.has(orb):
		return "Nothing to use it on"
	if orb == MENDING:
		return "" if item.broken else "This item is not broken"
	if item.broken:
		return "A broken item cannot be changed"
	if item.mods.is_empty() and orb != EXPANSION:
		return "This item has no modifiers"
	var unique := item.rarity == ItemRarity.Rarity.UNIQUE
	match orb:
		REPLACEMENT:
			if unique:
				return "A unique's modifiers are its own"
		EXPANSION:
			if unique:
				return "A unique's modifiers are its own"
			if item.rarity == ItemRarity.Rarity.COMMON:
				return "A common item cannot carry a modifier"
			if item.extra_slot:
				return "This item has already been expanded"
		BINDING:
			# Its modifiers never change, so all a lock could do is refuse the player's own Divine.
			if unique:
				return "A unique's modifiers are its own"
			for mod in item.mods:
				if bool(mod.get("bound", false)):
					return "This item already has a modifier bound"
	if aimed(orb):
		for i in item.mods.size():
			if can_aim(orb, item, i):
				return ""
		return ("Every modifier on it is already perfect" if orb == PERFECTION
				else "Every modifier on it is locked")
	return ""


## Spends the orb's work on the piece, in place. False when there was nothing for it to do, in which
## case the piece is untouched and the caller must not spend a count. `index` is the modifier an
## aimed orb is pointed at.
static func apply(orb: String, item: Item, rng: RandomNumberGenerator, index := -1) -> bool:
	if not can_apply(orb, item) or (aimed(orb) and not can_aim(orb, item, index)):
		return false
	match orb:
		REPLACEMENT:
			# Drawn from what the piece does not carry, the one being replaced included, so it is
			# never itself again. A fresh dictionary: what was perfect about the old line goes with it.
			var fresh := ModifierTable.add_one(item.type, item.mods, rng, item.mod_level())
			if fresh.is_empty():
				return false
			item.mods[index] = fresh
		ASCENSION:
			item.ascend()
		PERFECTION:
			item.mods[index]["perfect"] = true
			item.refresh_perfect()
		EXPANSION:
			var extra := ModifierTable.add_one(item.type, item.mods, rng, item.mod_level())
			if extra.is_empty():
				return false
			item.extra_slot = true
			item.mods.append(extra)
		MENDING:
			item.broken = false
		BINDING:
			item.hold(index, "bound")
	return true
