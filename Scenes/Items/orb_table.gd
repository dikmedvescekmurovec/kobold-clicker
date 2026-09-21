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
## One job an orb: Transmutation, Alchemy and Exalted each make a piece their rarity or reroll one
## already there, Augmentation adds a modifier, Divine rerolls the numbers and Chaos the tiers.
##
## Two things a smith leaves on a piece are the orbs' business, and both are handled in one place
## each. A **broken** piece refuses every orb, so the branches below never see one. A **locked**
## modifier survives all six: `_reroll_at` puts it back and fills the rest around it, and Divine and
## Chaos step over it.

const ROOT := "res://Assets/Orbs/"

## The order the tray draws them in, and it never changes: six fixed squares whose places the
## player learns. Cheap and frequent first, running to the rare.
##
## `does` is the sentence the hover card reads out, written as a whole statement rather than a
## fragment, because it is the only explanation of an orb anywhere in the game.
##
## The weights are relative and flat -- no depth gating. Fighting deeper buys better *modifiers*,
## which is what a tile's level ceiling already decides; an orb rate that climbed with it would make
## the frontier the only place worth farming, and the frontier is the part the player cannot reach.
const ORBS := {
	"Orb of Transmutation": {
		"icon": "Orb of Transmutation.png", "weight": 24,
		"does": "Makes a piece uncommon with fresh modifiers, or rerolls an uncommon one's.",
	},
	"Orb of Augmentation": {
		"icon": "Orb of Augmentation.png", "weight": 10,
		"does": "Adds one more modifier, at any rarity.",
	},
	"Orb of Alchemy": {
		"icon": "Orb of Alchemy.png", "weight": 8,
		"does": "Makes a piece rare with fresh modifiers, or rerolls a rare one's.",
	},
	"Orb of Divine": {
		"icon": "Orb of Divine.png", "weight": 7,
		"does": "Rerolls the value of every modifier, keeping the modifiers and their tiers.",
	},
	"Orb of Chaos": {
		"icon": "Orb of Chaos.png", "weight": 4,
		"does": "Rerolls the tier and value of every modifier, keeping the modifiers themselves.",
	},
	"Orb of Exalted": {
		"icon": "Orb of Exalted.png", "weight": 3,
		"does": "Makes a piece elite with fresh modifiers, or rerolls an elite one's.",
	},
}

## Kills the player makes, across every fight, before the first orb can fall. Orbs change gear, so
## they wait until the player has had time to find some.
const FIRST_ORB_KILLS := 50

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
	"Orb of Exalted": ItemRarity.Rarity.ELITE,
}

static var _icons := {}


## Every orb, in the tray's order.
static func orbs() -> Array:
	return ORBS.keys()


static func icon_path(orb: String) -> String:
	return ROOT + str(ORBS[orb]["icon"])


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
	# A unique's modifiers are its row's and stay: only their numbers may move, which is Divine and Chaos.
	if item.rarity == ItemRarity.Rarity.UNIQUE and orb not in ["Orb of Divine", "Orb of Chaos"]:
		return false
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exalted":
			# No orb lowers a rarity: each makes its own, or rerolls a piece already there.
			return item.rarity <= RARITY_OF[orb]
		"Orb of Augmentation":
			return item.mods.size() < _room(item)
		"Orb of Divine", "Orb of Chaos":
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
	var piece := "%s %s" % [item.rarity_name(), item.display_name()]
	if item.broken:
		return "A broken piece cannot be changed"
	if item.rarity == ItemRarity.Rarity.UNIQUE:
		return "Only an Orb of Divine or Chaos can change a unique"
	match orb:
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exalted":
			return "A %s piece cannot be made %s" % [item.rarity_name().to_lower(),
					ItemRarity.NAMES[RARITY_OF[orb]].to_lower()]
		"Orb of Augmentation":
			if _room(item) == 0:
				return "A common piece cannot carry a modifier"
			return "This %s already carries all it can" % piece
		"Orb of Divine", "Orb of Chaos":
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
		"Orb of Transmutation", "Orb of Alchemy", "Orb of Exalted":
			_reroll_at(item, RARITY_OF[orb], rng)
		"Orb of Augmentation":
			var extra := ModifierTable.add_one(item.type, item.mods, rng, item.mod_level())
			if extra.is_empty():
				return false
			item.mods.append(extra)
		"Orb of Divine":
			reroll_values(item, rng)
		"Orb of Chaos":
			reroll_tiers(item, rng)
	return true


## Rolls every modifier's number again in its own tier's band (`Item.tier_of`), leaving the ids and
## the tiers alone:
## that is the whole difference between a Divine and a Chaos, and the reason a piece with the right
## modifiers and poor rolls is worth keeping. **The smith's upgrade calls this too** (`Blacksmith`),
## which is why it is a function rather than a branch: a band read at two levels in two files is two
## places to drift apart.
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
## question in this game -- ItemRarity.MOD_COUNT is the join, and nothing else may answer it.
##
## A locked modifier is one of that handful rather than an extra on top: it is put back first and the
## draw fills what is left around it, so the rarity's ceiling holds exactly as it does on a piece
## with no lock. `ModifierTable.add_one` already draws only what the piece is not carrying, which is
## what keeps the lock from being rolled a second time.
static func _reroll_at(item: Item, rarity: ItemRarity.Rarity, rng: RandomNumberGenerator) -> void:
	item.rarity = rarity
	var count := ItemRarity.mod_count(rarity, rng) + int(item.extra_slot)
	# The smith's lock and an Orb of Binding's: two at most, and both are of the handful.
	var mods: Array[Dictionary] = []
	mods.assign(item.mods.filter(Item.held_fast))
	if mods.is_empty():
		item.mods = ModifierTable.roll(item.type, count, rng, item.mod_level())
		return
	for i in count - mods.size():
		var extra := ModifierTable.add_one(item.type, mods, rng, item.mod_level())
		if extra.is_empty():
			break
		mods.append(extra)
	item.mods = mods


## The most modifiers this piece's rarity allows. A common's is zero, which is what makes a common
## with a modifier a contradiction rather than a rare event.
static func _room(item: Item) -> int:
	return int(ItemRarity.MOD_COUNT[item.rarity][1]) + int(item.extra_slot)


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
		orb_find := 0.0) -> String:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, orb_find):
		return ""
	return _weighted(rng)


## An orb a vendor would have on its shelf: two draws, and the rarer of the two. What a shop is for
## is the orb nobody has seen fall, so the shelf leans up the table -- and it leans by drawing twice
## rather than by carrying a second set of weights, so tuning a drop rate tunes the shelf with it.
static func roll_favoured(rng: RandomNumberGenerator) -> String:
	var first := _weighted(rng)
	var second := _weighted(rng)
	return first if int(ORBS[first]["weight"]) <= int(ORBS[second]["weight"]) else second


## An orb picked by weight. Integer weights, so walking the table cannot drift.
static func _weighted(rng: RandomNumberGenerator) -> String:
	var total := 0
	for orb: String in ORBS:
		total += int(ORBS[orb]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for orb: String in ORBS:
		pick -= int(ORBS[orb]["weight"])
		if pick < 0:
			return orb
	return orbs()[0]
