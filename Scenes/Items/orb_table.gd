class_name OrbTable
extends RefCounted
## The six orbs, one job each: what each does to a piece, which exist behind which wall, and their
## drop and shelf rolls. An orb is a count by name in `Inventory.orbs`, never an `Item`.
##
## The rule for each is written once, in `why_not`: `can_apply` is it, empty, and `apply` refuses on
## it, so the square that lights, the act and the sentence for a refusal cannot disagree. No orb
## touches a piece's level or base stats. A broken piece refuses every orb, and a held-fast modifier
## survives all six (`_reroll_at` fills around it; Divinity and Chaos step over it).

const ROOT := "res://Assets/Orbs/"

## An orb's name in an older save -> its name now (`current`, asked wherever a save is read).
const RENAMED := {
	"Orb of Alteration": "Orb of Transmutation",
	"Orb of Exalted": "Orb of Exaltation",
	"Orb of Divine": "Orb of Divinity",
}


static func current(orb: String) -> String:
	return RENAMED.get(orb, orb)


## The six, in the tray's order, which never changes and which `unlocked` and `upscale_from` read.
##   icon    its file under `ROOT`.
##   glow    its colour off its icon, in ENDESGA 64: the light behind the card of a piece it goes into
##           (`ItemCard.shine`) and the colour of its drop beam.
##   beam    the rarity whose `LootBeam` a good one stands in as it drops; absent, it drops plain.
##   weight  how often it is drawn against the others: flat, with no depth gating (DESIGN.md).
##   does    the hover card's sentence, whole: the only explanation of an orb in the game.
const ORBS := {
	"Orb of Transmutation": {
		"icon": "Orb of Transmutation.png", "glow": Color("0069aa"), "weight": 24,
		"does": "Makes an item uncommon with fresh modifiers, or rerolls an uncommon one's.",
	},
	"Orb of Augmentation": {
		"icon": "Orb of Augmentation.png", "glow": Color("00cdf9"), "weight": 10,
		"does": "Adds one more modifier, at any rarity.",
	},
	"Orb of Alchemy": {
		"icon": "Orb of Alchemy.png", "glow": Color("c64524"), "weight": 8,
		"does": "Makes an item rare with fresh modifiers, or rerolls a rare one's.",
	},
	"Orb of Divinity": {
		"icon": "Orb of Divinity.png", "weight": 7, "beam": ItemRarity.Rarity.RARE, "glow": Color("b4b4b4"),
		"does": "Rerolls the value of every modifier, keeping the modifiers and their tiers.",
	},
	"Orb of Chaos": {
		"icon": "Orb of Chaos.png", "weight": 4, "beam": ItemRarity.Rarity.RARE, "glow": Color("ff5000"),
		"does": "Rerolls the tier and value of every modifier, keeping the modifiers themselves.",
	},
	"Orb of Exaltation": {
		"icon": "Orb of Exaltation.png", "weight": 3, "beam": ItemRarity.Rarity.ELITE, "glow": Color("ffc825"),
		"does": "Makes an item epic with fresh modifiers, or rerolls an epic one's.",
	},
}

## Lifetime kills before an orb can fall by luck.
const FIRST_ORB_KILLS := 20

## The orb a new player is promised before then (`Encounter.PROMISED`'s `TRANSMUTE`,
## `Inventory.first_orb_taken`), with the Broken Sword already in hand to spend it on.
const FIRST_ORB := "Orb of Transmutation"
## The one promised next (`Encounter.PROMISED`'s `AUGMENT`, `Inventory.FIRST_AUGMENT`). After the
## first, since a common takes no modifier and the uncommon the first makes has room for one.
const SECOND_ORB := "Orb of Augmentation"

## How often a body carries an orb, by its tier (`chance_for`).
const TIER_CHANCE := {
	EnemyRoster.Tier.COMMON: 0.05,
	EnemyRoster.Tier.ELITE: 0.22,
	EnemyRoster.Tier.BOSS: 0.50,
}

## The rarity each of the three rarity orbs makes. UNIQUE must stay unreachable.
const RARITY_OF := {
	"Orb of Transmutation": ItemRarity.Rarity.UNCOMMON,
	"Orb of Alchemy": ItemRarity.Rarity.RARE,
	"Orb of Exaltation": ItemRarity.Rarity.ELITE,
}

## How many orbs each wall unlocks, in tray order, off the deepest wall ever broken in any world
## (`Inventory.walls_ever`; the user's, 2026-10-03, for good since 2026-10-09). Every way an orb is
## had -- a body, a shelf, a bounty, the Sack, a trade up -- draws only from `unlocked`.
const ORBS_A_WALL := 2

## Walls down by which every orb is unlocked: the default for a caller no world stands behind (tests).
const EVERY_WALL := 2

## How many of the orb before it in the tray the orb vendor takes for one orb (`upscale_from`).
const UPSCALE_COST := 3

static var _icons := {}


static func orbs() -> Array:
	return ORBS.keys()


## The orbs that can be had with the `walls`th wall the deepest ever broken, in the tray's order.
static func unlocked(walls: int) -> Array:
	return orbs().slice(0, ORBS_A_WALL * (maxi(walls, 0) + 1))


static func icon_path(orb: String) -> String:
	return ROOT + str(ORBS[orb]["icon"])


## The orb one step before this one in the tray, which the orb vendor trades up to it, or "" for the
## first, which nothing trades up to.
static func upscale_from(orb: String) -> String:
	var at := orbs().find(orb)
	return orbs()[at - 1] if at > 0 else ""


static func icon(orb: String) -> Texture2D:
	if not _icons.has(orb):
		_icons[orb] = load(icon_path(orb))
	return _icons[orb]


static func describe(orb: String) -> String:
	return str(ORBS[orb]["does"])


## `why_not`, empty. No piece, and an orb nobody has heard of, are refused without a word.
static func can_apply(orb: String, item: Item) -> bool:
	return item != null and ORBS.has(orb) and why_not(orb, item).is_empty()


## Why this orb is greyed out, for the hover card; "" when it is not. **The whole rule is here.**
static func why_not(orb: String, item: Item) -> String:
	if item == null or not ORBS.has(orb):
		return ""
	if item.broken:
		return "A broken item cannot be changed"
	# The user's, 2026-10-08.
	if not item.capstone.is_empty():
		return "A capstone cannot be changed"
	# A unique's modifiers are its row's: only their numbers may move.
	if item.rarity == ItemRarity.Rarity.UNIQUE and orb not in ["Orb of Divinity", "Orb of Chaos"]:
		return "Only an Orb of Divinity or Chaos can change a unique"
	var piece := "%s %s" % [item.rarity_label().to_lower(), item.display_name()]
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exaltation":
			# Each makes its own rarity whatever the piece was, lower as well as higher (the user's ruling,
			# 2026-10-02): an epic transmuted is an uncommon with an uncommon's modifiers.
			return ""
		"Orb of Augmentation":
			if item.mods.size() < room(item):
				return ""
			if room(item) == 0:
				return "A common item cannot carry a modifier"
			return "This %s already carries all it can" % piece
		"Orb of Divinity", "Orb of Chaos":
			return "" if not item.mods.is_empty() else "This %s has no modifiers to reroll" % piece
	# An orb the table names and no branch above knows is refused rather than spent on nothing.
	return "Cannot be used on this %s" % piece


## Spends one orb on one piece, in place. False where the orb has nothing to do here: the piece is
## untouched, and the caller must not take one off its count.
static func apply(orb: String, item: Item, rng: RandomNumberGenerator) -> bool:
	if not can_apply(orb, item):
		return false
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exaltation":
			_reroll_at(item, RARITY_OF[orb], rng)
		"Orb of Augmentation":
			var extra := item.extra_mod(item.mods, rng)
			if extra.is_empty():
				return false
			item.mods.append(extra)
		"Orb of Divinity":
			reroll_values(item, rng)
		"Orb of Chaos":
			reroll_tiers(item, rng)
	return true


## Divinity's act: every modifier's number again in its own tier's band (`Item.tier_of`), the ids and
## the tiers staying.
static func reroll_values(item: Item, rng: RandomNumberGenerator) -> void:
	for mod: Dictionary in _rerollable(item):
		mod["value"] = ModifierTable.reroll_value(str(mod["id"]), rng, item.tier_of(mod))


## Chaos's: every modifier's tier again, and its number in the new tier's band. The ids stay, so a
## unique takes it.
static func reroll_tiers(item: Item, rng: RandomNumberGenerator) -> void:
	for mod: Dictionary in _rerollable(item):
		var fresh := ModifierTable.rolled_mod(str(mod["id"]), rng, item.band_level(mod))
		mod["value"] = fresh["value"]
		mod.erase("under")
		if fresh.has("under"):
			mod["under"] = fresh["under"]


## The lines a reroll may move, in their order: a held-fast one stays at the roll it was held at, and
## a perfected one at its band's top.
static func _rerollable(item: Item) -> Array:
	return item.mods.filter(func(mod: Dictionary) -> bool:
		return not (Item.held_fast(mod) or bool(mod.get("perfect", false))))


## Sets the piece to `rarity` with that rarity's fresh handful of modifiers; `ItemRarity.band` alone
## says how many, an Orb of Expansion's one on top. Held-fast lines are of that handful and never
## extras: they are put back first and the draw fills around them.
static func _reroll_at(item: Item, rarity: ItemRarity.Rarity, rng: RandomNumberGenerator) -> void:
	# The first craft is a sure thing (the user's, 2026-10-10): a common Broken Sword transmuted carries
	# "+1 Damage" and nothing else. No orb makes a common, so a common one is on its first Transmutation.
	if item.type == LootTable.FIRST_DROP and item.rarity == ItemRarity.Rarity.COMMON \
			and rarity == ItemRarity.Rarity.UNCOMMON:
		item.rarity = rarity
		var sure := {"id": "added_damage", "value": 1}
		# Tier 1, whose band the 1 is in, on a sword the smith has levelled.
		if item.mod_level() > 1:
			sure["under"] = item.mod_level() - 1
		item.mods = [sure]
		return
	item.rarity = rarity
	var count := ItemRarity.mod_count(rarity, rng, item.type) + int(item.extra_slot)
	# The smith's lock and an Orb of Binding's: two at most, and both are of the handful.
	var mods: Array[Dictionary] = []
	mods.assign(item.mods.filter(Item.held_fast))
	if mods.is_empty():
		item.mods = ModifierTable.roll(item.type, count, rng, item.mod_level(), item.stone_tier)
		return
	for i in count - mods.size():
		var extra := item.extra_mod(mods, rng)
		if extra.is_empty():
			break
		mods.append(extra)
	item.mods = mods


## The most modifiers the piece's rarity allows, an Expansion's included: Augmentation's test, and the
## card's open rows (`ItemDetails.fill`).
static func room(item: Item) -> int:
	return int(ItemRarity.band(item.rarity, item.type)[1]) + int(item.extra_slot)


## How often this enemy leaves an orb, rolled beside the gear and not against it: its tier times its
## size, lifted by `orb_find` percent, capped at 1.
static func chance_for(enemy_name: String, orb_find := 0.0) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = LootTable.SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	return minf(tier * size * (1.0 + maxf(orb_find, 0.0) / 100.0), 1.0)


## One kill's orb, or "". The chance is drawn first and alone, as `LootTable.roll`'s is.
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false,
		orb_find := 0.0, walls := EVERY_WALL) -> String:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, orb_find):
		return ""
	return _weighted(rng, walls)


## An orb for a vendor's shelf: two draws and the rarer kept, so the shops lean on the drop weights
## and have no table of their own.
static func roll_favoured(rng: RandomNumberGenerator, walls := EVERY_WALL) -> String:
	var first := _weighted(rng, walls)
	var second := _weighted(rng, walls)
	return first if int(ORBS[first]["weight"]) <= int(ORBS[second]["weight"]) else second


## An orb picked by weight among those `walls` unlocks (`LootTable.weighted_index`).
static func _weighted(rng: RandomNumberGenerator, walls := EVERY_WALL) -> String:
	var pool := unlocked(walls)
	var weights := pool.map(func(orb: String) -> int: return int(ORBS[orb]["weight"]))
	return pool[LootTable.weighted_index(weights, rng)]
