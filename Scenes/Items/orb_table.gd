class_name OrbTable
extends RefCounted
## The eight orbs: what each one is, what it does to a piece, and how often a body carries one.
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
## What an orb *does* is the one thing here that cannot be a table. Eight verbs, eight branches of
## one match, in one file -- because the rule that decides whether an orb is offered (`can_apply`),
## the rule that carries it out (`apply`) and the sentence that explains a refusal (`why_not`) are
## three faces of one piece of knowledge, and splitting them is how they come to disagree.
##
## No orb ever touches a piece's level or its base stats. Those are frozen when it is rolled and stay
## frozen; rarity and modifiers are what an orb exists to change.

const ROOT := "res://Assets/Orbs/"

## The order the tray draws them in, and it never changes: eight fixed squares whose places the
## player learns. Cheap and frequent first, running to the rare and the destructive.
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
		"does": "Lifts a common piece to uncommon and rolls it fresh modifiers.",
	},
	"Orb of Augmentation": {
		"icon": "Orb of Augmentation.png", "weight": 20,
		"does": "Adds one more modifier to an uncommon piece.",
	},
	"Orb of Alteration": {
		"icon": "Orb of Alteration.png", "weight": 18,
		"does": "Rerolls the modifiers on an uncommon piece.",
	},
	"Orb of Alchemy": {
		"icon": "Orb of Alchemy.png", "weight": 8,
		"does": "Raises a piece one rarity step and rolls it fresh modifiers.",
	},
	"Orb of Chaos": {
		"icon": "Orb of Chaos.png", "weight": 7,
		"does": "Rerolls a piece's modifiers, keeping its rarity.",
	},
	"Orb of Exalted": {
		"icon": "Orb of Exalted.png", "weight": 3,
		"does": "Adds one more modifier, at any rarity.",
	},
	"Orb of Divine": {
		"icon": "Orb of Divine.png", "weight": 4,
		"does": "Rerolls the value of every modifier, keeping the modifiers themselves.",
	},
	"Orb of Scouring": {
		"icon": "Orb of Scouring.png", "weight": 16,
		"does": "Strips a piece back to a bare common.",
	},
}

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

## The highest an orb can carry a piece. UNIQUE is hand-crafted, weighted zero in every drop table,
## and must stay unreachable -- so the ladder Alchemy climbs stops one step short of it.
const TOP_RARITY := ItemRarity.Rarity.ELITE

static var _icons := {}


## Every orb, in the tray's order.
static func orbs() -> Array:
	return ORBS.keys()


static func icon_path(orb: String) -> String:
	return ROOT + str(ORBS[orb]["icon"])


## The sprite, loaded once. The same cache LootTable keeps, for the same reason: eight squares are
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
	match orb:
		"Orb of Transmutation":
			return item.rarity == ItemRarity.Rarity.COMMON
		"Orb of Augmentation":
			return item.rarity == ItemRarity.Rarity.UNCOMMON and item.mods.size() < _room(item)
		"Orb of Alteration":
			return item.rarity == ItemRarity.Rarity.UNCOMMON
		"Orb of Alchemy":
			return item.rarity < TOP_RARITY
		"Orb of Chaos":
			return _room(item) > 0
		"Orb of Exalted":
			return item.mods.size() < _room(item)
		"Orb of Divine":
			return not item.mods.is_empty()
		"Orb of Scouring":
			return item.rarity != ItemRarity.Rarity.COMMON
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
	match orb:
		"Orb of Transmutation":
			return "Only a common piece can be transmuted"
		"Orb of Augmentation":
			if item.rarity != ItemRarity.Rarity.UNCOMMON:
				return "Only an uncommon piece can be augmented"
			return "This %s already carries all it can" % piece
		"Orb of Alteration":
			return "Only an uncommon piece can be altered"
		"Orb of Alchemy":
			return "An elite piece cannot be raised further"
		"Orb of Chaos":
			return "A common piece has no modifiers to reroll"
		"Orb of Exalted":
			if _room(item) == 0:
				return "A common piece cannot carry a modifier"
			return "This %s already carries all it can" % piece
		"Orb of Divine":
			return "This %s has no modifiers to reroll" % piece
		"Orb of Scouring":
			return "This %s is already bare" % piece
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
		"Orb of Transmutation":
			_reroll_at(item, ItemRarity.Rarity.UNCOMMON, rng)
		"Orb of Augmentation", "Orb of Exalted":
			var extra := ModifierTable.add_one(item.type, item.mods, rng, item.level)
			if extra.is_empty():
				return false
			item.mods.append(extra)
		"Orb of Alteration":
			_reroll_at(item, ItemRarity.Rarity.UNCOMMON, rng)
		"Orb of Alchemy":
			_reroll_at(item, (item.rarity + 1) as ItemRarity.Rarity, rng)
		"Orb of Chaos":
			_reroll_at(item, item.rarity, rng)
		"Orb of Divine":
			# The ids stay and only the numbers move: that is the whole difference between this and
			# Chaos, and the reason a piece with the right modifiers and poor rolls is worth keeping.
			for mod in item.mods:
				mod["value"] = ModifierTable.reroll_value(str(mod["id"]), rng, item.level)
		"Orb of Scouring":
			item.rarity = ItemRarity.Rarity.COMMON
			item.mods.clear()
	return true


## Sets the piece to a rarity and gives it that rarity's own fresh handful of modifiers. Four of the
## eight end here, because "what rarity is it now" and "how many modifiers does it carry" are one
## question in this game -- ItemRarity.MOD_COUNT is the join, and nothing else may answer it.
static func _reroll_at(item: Item, rarity: ItemRarity.Rarity, rng: RandomNumberGenerator) -> void:
	item.rarity = rarity
	item.mods = ModifierTable.roll(item.type, ItemRarity.mod_count(rarity, rng), rng, item.level)


## The most modifiers this piece's rarity allows. A common's is zero, which is what makes a common
## with a modifier a contradiction rather than a rare event.
static func _room(item: Item) -> int:
	return int(ItemRarity.MOD_COUNT[item.rarity][1])


## How often this enemy leaves an orb: its tier times its body, and never more than certain. Rolled
## on its own, beside the gear roll rather than against it, so one body can hand over both.
static func chance_for(enemy_name: String) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	return minf(tier * size, 1.0)


## One kill's worth of currency: "" for nothing, or the orb that dropped. The chance is drawn first
## and on its own, so a kill that leaves nothing costs exactly one draw -- LootTable.roll's rule, and
## what keeps the two rates independently tunable.
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false) -> String:
	if not guaranteed and rng.randf() >= chance_for(enemy_name):
		return ""
	return _weighted(rng)


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
