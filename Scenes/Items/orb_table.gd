class_name OrbTable
extends RefCounted
## The six orbs: what each one is, what it does to a piece, and how often a body carries one.
##
## The same shape as LootTable -- const tables and static accessors, no nodes -- and the same
## philosophy about the drop rate: TIER_CHANCE and SIZE_CHANCE multiply into `chance_for`, so the
## whole curve is two small tables rather than a number per enemy.
##
## An orb is not an Item and deliberately not one. It has no rarity, no level, no modifiers and no
## socket; it is a count, the way gold is, and the whole of it lives in Inventory.orbs as a name and
## a number. That is what keeps Item, ItemSlot, DropsView and the bag's ordering untouched by this
## chunk: there is nothing new for them to sort, cap, filter or draw.
##
## What an orb *does* is the one thing here that cannot be a table. Six verbs, six branches of
## one match, in one file -- because the rule that decides whether an orb is offered (`can_apply`),
## the rule that carries it out (`apply`) and the sentence that explains a refusal (`why_not`) are
## three faces of one piece of knowledge, and splitting them is how they come to disagree.
##
## No orb ever touches a piece's level or its base stats. Those are frozen when it is rolled and stay
## frozen; rarity and modifiers are what an orb exists to change. (A blacksmith's upgrade does move
## them, which is the one exception in the game and lives in `Scenes/Town/blacksmith.gd`.)
##
## One job an orb: Transmutation, Alchemy and Exalted each make a piece their rarity -- from below or
## from above -- or reroll one already there, Augmentation adds a modifier, Divine rerolls the numbers
## and Chaos the tiers.
##
## Two things a smith leaves on a piece are the orbs' business, and both are handled in one place
## each. A **broken** piece refuses every orb, so the branches below never see one. A **locked**
## modifier survives all six: `_reroll_at` puts it back and fills the rest around it, and Divine and
## Chaos step over it.

const ROOT := "res://Assets/Orbs/"

## Orbs a save may name under an older name -> the name they carry now: Alteration's job went to
## Transmutation, and Exalted and Divine were adjectives where every other orb is "of" a noun (2026-09-30).
const RENAMED := {
	"Orb of Alteration": "Orb of Transmutation",
	"Orb of Exalted": "Orb of Exaltation",
	"Orb of Divine": "Orb of Divinity",
}


## What a saved orb's name is called now (`RENAMED`); a name that never changed is itself.
static func current(orb: String) -> String:
	return RENAMED.get(orb, orb)


## The order the tray draws them in, and it never changes: six fixed squares whose places the
## player learns. Cheap and frequent first, running to the rare.
##
## `does` is the sentence the hover card reads out, written as a whole statement rather than a
## fragment, because it is the only explanation of an orb anywhere in the game.
##
## The weights are relative and flat -- no depth gating. Fighting deeper buys better *modifiers*,
## which is what a tile's level ceiling already decides; an orb rate that climbed with it would make
## the frontier the only place worth farming, and the frontier is the part the player cannot reach.
## What does move is which orbs exist at all: the deepest wall ever broken unlocks them two at a time
## (`unlocked`, `WallUnlocks`), anywhere on the land and in every world after.
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

## `glow` is the orb's colour, picked off its icon in ENDESGA 64: the light it leaves behind the card of a
## piece it goes into (`ItemCard.shine`), and the `LootBeam` a good one stands in the arena when it drops,
## in the shape of the rarity `beam` names; the cheap ones drop plain.

## Kills the player makes, across every fight, before the first orb can fall. Orbs change gear, so
## they wait until the player has had time to find some.
const FIRST_ORB_KILLS := 20

## The orb a new player is promised before FIRST_ORB_KILLS are made (`Encounter.PROMISED`'s `TRANSMUTE`,
## `Inventory.first_orb_taken`), so crafting is met early, on the cheapest orb there is and with the
## Broken Sword already in hand to spend it on.
const FIRST_ORB := "Orb of Transmutation"
## The one promised next (`Encounter.PROMISED`'s `AUGMENT`, `Inventory.FIRST_AUGMENT`): a common takes no
## modifier, so it comes after the orb that makes the sword uncommon, whose one sure line leaves room for it.
const SECOND_ORB := "Orb of Augmentation"

## How often a body carries an orb at all. Read beside LootTable's own pair: an orb is a little more
## common than a piece of gear off the same body, because one piece of gear is worth a great many
## Transmutation orbs and a currency nobody accumulates is a currency nobody spends.
const TIER_CHANCE := {
	EnemyRoster.Tier.COMMON: 0.05,
	EnemyRoster.Tier.ELITE: 0.22,
	EnemyRoster.Tier.BOSS: 0.50,
}

## What the body itself is worth against that -- the same spread gear uses, for the same reason.
const SIZE_CHANCE := {
	EnemyRoster.Size.TINY: 0.5,
	EnemyRoster.Size.SMALL: 0.8,
	EnemyRoster.Size.MEDIUM: 1.0,
	EnemyRoster.Size.LARGE: 1.3,
	EnemyRoster.Size.HUGE: 1.6,
}

## The rarity each of the three rarity orbs makes. UNIQUE is hand-crafted, weighted zero in every
## drop table, and must stay unreachable -- so the ladder stops at Exalted's elite.
const RARITY_OF := {
	"Orb of Transmutation": ItemRarity.Rarity.UNCOMMON,
	"Orb of Alchemy": ItemRarity.Rarity.RARE,
	"Orb of Exaltation": ItemRarity.Rarity.ELITE,
}

## How many orbs each wall unlocks, in tray order: Transmutation and Augmentation from the start,
## Alchemy and Divinity behind the first wall, Chaos and Exaltation behind the second (the user's
## ruling, 2026-10-03), for good once broken in any world (`Inventory.walls_ever`, the user's, 2026-10-09). Every way an orb is had -- a body, a shelf, a bounty, the Sack, a
## trade up -- draws only from `unlocked`.
const ORBS_A_WALL := 2

## Walls down by which every orb is unlocked: the default for a caller no world stands behind (tests).
const EVERY_WALL := 2

## How many of the orb before it in the tray the orb vendor takes for one orb (`upscale_from`).
const UPSCALE_COST := 3

static var _icons := {}


## Every orb, in the tray's order.
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


## The sprite, loaded once. The same cache LootTable keeps, for the same reason: six squares are
## rebuilt every time the bag refreshes, and a kill refreshes it.
static func icon(orb: String) -> Texture2D:
	if not _icons.has(orb):
		_icons[orb] = load(icon_path(orb))
	return _icons[orb]


## What the hover card says this orb is for.
static func describe(orb: String) -> String:
	return str(ORBS[orb]["does"])


## Whether this orb has anything to do to this piece. It is the whole rule: the tray lights a square
## when this is true and greys it when it is false, and `apply` refuses on it rather than trusting
## whoever called.
static func can_apply(orb: String, item: Item) -> bool:
	if item == null or not ORBS.has(orb):
		return false
	# One answer for all six: a piece the hammer ruined is out of the game as far as crafting goes.
	if item.broken:
		return false
	# A skill stone's capstone is what it dropped as, and stays it (the user's, 2026-10-08).
	if not item.capstone.is_empty():
		return false
	# A unique's modifiers are its row's and stay: only their numbers may move, which is Divine and Chaos.
	if item.rarity == ItemRarity.Rarity.UNIQUE and orb not in ["Orb of Divinity", "Orb of Chaos"]:
		return false
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exaltation":
			# Each makes its own rarity whatever the piece was, lower as well as higher (the user's ruling,
			# 2026-10-02): an epic transmuted is an uncommon with an uncommon's modifiers.
			return true
		"Orb of Augmentation":
			return item.mods.size() < room(item)
		"Orb of Divinity", "Orb of Chaos":
			return not item.mods.is_empty()
	return false


## Why this orb is greyed out, for the hover card. Empty when it is not -- so a caller can ask this
## one question instead of asking `can_apply` and then inventing a sentence of its own.
##
## It lives here rather than in the panel because the reason an orb is refused is the same knowledge
## as the refusal, and the two written in two files is two places to drift apart.
static func why_not(orb: String, item: Item) -> String:
	if item == null or not ORBS.has(orb) or can_apply(orb, item):
		return ""
	var piece := "%s %s" % [item.rarity_label().to_lower(), item.display_name()]
	if item.broken:
		return "A broken item cannot be changed"
	if not item.capstone.is_empty():
		return "A capstone cannot be changed"
	if item.rarity == ItemRarity.Rarity.UNIQUE:
		return "Only an Orb of Divinity or Chaos can change a unique"
	match orb:
		"Orb of Augmentation":
			if room(item) == 0:
				return "A common item cannot carry a modifier"
			return "This %s already carries all it can" % piece
		"Orb of Divinity", "Orb of Chaos":
			return "This %s has no modifiers to reroll" % piece
	return "Cannot be used on this %s" % piece


## Spends one orb on one piece, in place. False when the orb has nothing to do here, in which case
## the piece is untouched and the caller must not decrement its count.
##
## Level and base stats are never touched by any branch. A piece's numbers were settled when it was
## rolled; what an orb buys is what the piece carries on top of them.
static func apply(orb: String, item: Item, rng: RandomNumberGenerator) -> bool:
	if not can_apply(orb, item):
		return false
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exaltation":
			_reroll_at(item, RARITY_OF[orb], rng)
		"Orb of Augmentation":
			var extra := ModifierTable.add_one(item.type, item.mods, rng, item.mod_level(), item.stone_tier)
			if extra.is_empty():
				return false
			item.mods.append(extra)
		"Orb of Divinity":
			reroll_values(item, rng)
		"Orb of Chaos":
			reroll_tiers(item, rng)
	return true


## Rolls every modifier's number again in its own tier's band (`Item.tier_of`), leaving the ids and
## the tiers alone:
## that is the whole difference between a Divine and a Chaos, and the reason a piece with the right
## modifiers and poor rolls is worth keeping.
##
## A locked or bound modifier is locked at the roll it was locked at -- paying the smith and then
## rerolling the number would be paying to keep a line and losing it anyway -- and a perfected one
## sits at the top of its band and stays there (`Item.refresh_perfect` moves it up with the level).
static func reroll_values(item: Item, rng: RandomNumberGenerator) -> void:
	for mod in item.mods:
		if Item.held_fast(mod) or bool(mod.get("perfect", false)):
			continue
		mod["value"] = ModifierTable.reroll_value(str(mod["id"]), rng, item.tier_of(mod))


## Rolls every modifier's tier again, and its number in the new tier's band: a Divine with the band
## itself thrown in, which is why a Chaos is the rarer of the two. The id stays, so a unique takes it.
## Held-fast and perfected lines are stepped over for Divine's reasons.
static func reroll_tiers(item: Item, rng: RandomNumberGenerator) -> void:
	for mod in item.mods:
		if Item.held_fast(mod) or bool(mod.get("perfect", false)):
			continue
		var fresh := ModifierTable.rolled_mod(str(mod["id"]), rng, item.band_level(mod))
		mod["value"] = fresh["value"]
		mod.erase("under")
		if fresh.has("under"):
			mod["under"] = fresh["under"]


## Sets the piece to a rarity and gives it that rarity's own fresh handful of modifiers. Three of the
## six end here, because "what rarity is it now" and "how many modifiers does it carry" are one
## question in this game -- `ItemRarity.band` is the join, and nothing else may answer it.
##
## A locked modifier is one of that handful rather than an extra on top: it is put back first and the
## draw fills what is left around it, so the rarity's ceiling holds exactly as it does on a piece
## with no lock. `ModifierTable.add_one` already draws only what the piece is not carrying, which is
## what keeps the lock from being rolled a second time.
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
		var extra := ModifierTable.add_one(item.type, mods, rng, item.mod_level(), item.stone_tier)
		if extra.is_empty():
			break
		mods.append(extra)
	item.mods = mods


## The most modifiers this piece's rarity allows. A common's is zero, which is what makes a common
## with a modifier a contradiction rather than a rare event. The card writes what is left of it as an
## empty row (`ItemDetails.fill`).
static func room(item: Item) -> int:
	return int(ItemRarity.band(item.rarity, item.type)[1]) + int(item.extra_slot)


## How often this enemy leaves an orb: its tier times its body, and never more than certain. Rolled
## on its own, beside the gear roll rather than against it, so one body can hand over both. `orb_find`
## lifts it the way `drop_rate` lifts the gear chance: 50 is half again as many orbs.
static func chance_for(enemy_name: String, orb_find := 0.0) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	return minf(tier * size * (1.0 + maxf(orb_find, 0.0) / 100.0), 1.0)


## One kill's worth of currency: "" for nothing, or the orb that dropped. The chance is drawn first
## and on its own, so a kill that leaves nothing costs exactly one draw -- LootTable.roll's rule, and
## what keeps the two rates independently tunable.
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false,
		orb_find := 0.0, walls := EVERY_WALL) -> String:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, orb_find):
		return ""
	return _weighted(rng, walls)


## An orb a vendor would have on its shelf: two draws, and the rarer of the two. What a shop is for
## is the orb nobody has seen fall, so the shelf leans up the table -- and it leans by drawing twice
## rather than by carrying a second set of weights, so tuning a drop rate tunes the shelf with it.
static func roll_favoured(rng: RandomNumberGenerator, walls := EVERY_WALL) -> String:
	var first := _weighted(rng, walls)
	var second := _weighted(rng, walls)
	return first if int(ORBS[first]["weight"]) <= int(ORBS[second]["weight"]) else second


## An orb picked by weight among those `walls` unlocks. Integer weights, so walking the table cannot drift.
static func _weighted(rng: RandomNumberGenerator, walls := EVERY_WALL) -> String:
	var pool := unlocked(walls)
	var total := 0
	for orb: String in pool:
		total += int(ORBS[orb]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for orb: String in pool:
		pick -= int(ORBS[orb]["weight"])
		if pick < 0:
			return orb
	return pool[0]
