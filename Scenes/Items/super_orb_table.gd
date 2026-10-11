class_name SuperOrbTable
extends RefCounted
## The six super orbs: what each does to an heirloom, on `TranscendPage` and nowhere else. They never
## drop, stand on a shelf or sell, and there is **one count for all six** (`Inventory.super_orbs`),
## spent on whichever is pressed. `why_not` is the one rule, as `OrbTable`'s is.
##
## What they leave on a piece (`Item.plus`, `Item.extra_slot`, a modifier's `"perfect"` and `"bound"`)
## is saved with it, and the ordinary orbs and the smith honour it ever after through
## `Item.held_fast`, `Item.refresh_perfect` and `Item.mod_level`.

const REPLACEMENT := "Orb of Replacement"
const ASCENSION := "Orb of Ascension"
const PERFECTION := "Orb of Perfection"
const EXPANSION := "Orb of Expansion"
const MENDING := "Orb of Mending"
const BINDING := "Orb of Binding"

## In the tray's order. `aimed`: it works on one modifier, which the player chooses (`can_aim`,
## `apply`'s `index`). `glow` and `does` are as `OrbTable.ORBS`'. The icons are `OrbTable.ROOT`'s
## "<name>.png", cut by `tools/ui_kit.py`.
const ORBS := {
	REPLACEMENT: {
		"glow": Color("93388f"),
		"aimed": true,
		"does": "Replaces the modifier you choose with another, freshly rolled.",
	},
	ASCENSION: {
		"glow": Color("ffc825"),
		"aimed": false,
		"does": "Takes the item toward its next +1: +1 takes one, +2 two more, +3 three more, and so on. "
				+ "Each + rolls every modifier on it as if the item were %d levels higher, for good.",
	},
	PERFECTION: {
		"glow": Color("c7cfdd"),
		"aimed": true,
		"does": "Puts the modifier you choose at the top of its range, and it stays there whatever is done "
				+ "to the item afterwards.",
	},
	EXPANSION: {
		"glow": Color("5ac54f"),
		"aimed": false,
		"does": "Adds one modifier more than the item's rarity allows. Once per item.",
	},
	MENDING: {
		"glow": Color("f68187"),
		"aimed": false,
		"does": "Makes a broken item whole again.",
	},
	BINDING: {
		"glow": Color("0098dc"),
		"aimed": true,
		"does": "Locks the modifier you choose so that no orb can move it, beside whatever a smith has "
				+ "locked. Once per item.",
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


## `why_not`, empty: for an aimed orb, whether any line of the piece will take it.
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


## Why this orb is greyed out, "" when it is not. The one rule.
static func why_not(orb: String, item: Item) -> String:
	if item == null or not ORBS.has(orb):
		return "Nothing to use it on"
	if orb == MENDING:
		return "" if item.broken else "This item is not broken"
	if item.broken:
		return "A broken item cannot be changed"
	if item.mods.is_empty() and orb != EXPANSION:
		return "This item has no modifiers"
	# A unique's modifiers never change, so all even a Binding could do is refuse the player's own Divine.
	if item.rarity == ItemRarity.Rarity.UNIQUE and orb in [REPLACEMENT, EXPANSION, BINDING]:
		return "A unique's modifiers are its own"
	match orb:
		EXPANSION:
			if item.rarity == ItemRarity.Rarity.COMMON:
				return "A common item cannot carry a modifier"
			if item.extra_slot:
				return "This item has already been expanded"
		BINDING:
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


## Spends the orb's work on the piece, in place; `index` is the modifier an aimed orb is pointed at.
## False where there was nothing for it to do: the piece is untouched, and the caller must not spend a
## count.
static func apply(orb: String, item: Item, rng: RandomNumberGenerator, index := -1) -> bool:
	if not can_apply(orb, item) or (aimed(orb) and not can_aim(orb, item, index)):
		return false
	match orb:
		REPLACEMENT:
			# Drawn from what the piece does not carry, the one being replaced included, so it is
			# never itself again. A fresh dictionary: what was perfect about the old line goes with it.
			var fresh := item.extra_mod(item.mods, rng)
			if fresh.is_empty():
				return false
			item.mods[index] = fresh
		ASCENSION:
			# One orb fed in; the plus comes when the last of its cost is, and the next costs one more.
			item.ascension += 1
			if item.ascension >= item.ascension_cost():
				item.ascension = 0
				item.ascend()
		PERFECTION:
			item.mods[index]["perfect"] = true
			item.refresh_perfect()
		EXPANSION:
			var extra := item.extra_mod(item.mods, rng)
			if extra.is_empty():
				return false
			item.extra_slot = true
			item.mods.append(extra)
		MENDING:
			item.broken = false
		BINDING:
			item.hold(index, "bound")
	return true
