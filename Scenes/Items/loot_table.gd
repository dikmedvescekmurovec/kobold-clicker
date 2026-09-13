class_name LootTable
extends RefCounted
## What a dead monster leaves behind, and how often.
##
## The same shape as EnemyRoster: const tables and static accessors, no nodes, so a test can roll
## twenty thousand drops in a loop. And the same philosophy -- the drop chance is not written per
## enemy. TIER_CHANCE and SIZE_CHANCE multiply into `chance_for`, so the whole curve is tuned from
## two small tables rather than by editing thirty numbers.
##
## A drop is not just a name any more: it rolls a rarity off the enemy that carried it and modifiers
## off ItemRarity's band, and every one is its own Item. Nothing reads any of it for gameplay yet --
## a click still does one point of damage. This is what the world hands over; what it is worth comes
## later.

const ROOT := "res://Assets/Gear/"

## Every item a monster can leave, how often it is the one that drops, and what it is worth. The
## weights are relative, not percentages: the armour is the trophy of the set, and the boot the thing
## you end up with six of.
##
## `stats` is the piece's own -- one role each, so a sword reads as a sword and a boot as a boot.
## They do not depend on rarity: an elite sword hits like a common one and simply carries more on
## top. Nothing reads these numbers for gameplay yet; they are shown and saved, and the chunk that
## makes a click do `damage` will be the one to retune them. Armour is on two pieces on purpose --
## it is the stat that should add up across what the player wears.
const ITEMS := {
	"Leather Boot": {
		"icon": "Leather Boot.png", "weight": 4,
		"stats": {"move_speed": 10, "dodge_chance": 4},
	},
	"Wooden Sword": {
		"icon": "Wooden Sword.png", "weight": 3,
		"stats": {"damage": 5, "crit_chance": 5, "attack_speed": 1.0},
	},
	"Wooden Shield": {
		"icon": "Wooden Shield.png", "weight": 3,
		"stats": {"armor": 6, "block_chance": 10},
	},
	"Wooden Armor": {
		"icon": "Wooden Armor.png", "weight": 2,
		"stats": {"armor": 10, "health": 20},
	},
}

## Whether a body carries anything at all, by what it was. Drops are meant to be rare: a fight of
## nine commons and an elite comes to about a third of an item, so most fights give nothing and a
## drop is an event. If that plays too mean, raise the common line; the shape is in SIZE_CHANCE.
const TIER_CHANCE := {
	EnemyRoster.Tier.COMMON: 0.03,
	EnemyRoster.Tier.ELITE: 0.15,
	EnemyRoster.Tier.BOSS: 0.40,
}

## What the body itself is worth against that: a slime rarely carries gear, something huge usually does.
const SIZE_CHANCE := {
	EnemyRoster.Size.TINY: 0.5,
	EnemyRoster.Size.SMALL: 0.8,
	EnemyRoster.Size.MEDIUM: 1.0,
	EnemyRoster.Size.LARGE: 1.3,
	EnemyRoster.Size.HUGE: 1.6,
}

## How each stat is written, and which of them are percentages. One place, so a stat block and a
## modifier line always spell a stat the same way.
const STAT_LABELS := {
	"damage": "Damage",
	"crit_chance": "Crit Chance",
	"attack_speed": "Attack Speed",
	"armor": "Armour",
	"block_chance": "Block Chance",
	"health": "Health",
	"move_speed": "Move Speed",
	"dodge_chance": "Dodge Chance",
}
const PERCENT_STATS := ["crit_chance", "block_chance", "move_speed", "dodge_chance"]
## Attacks a second, the one stat that is neither a plain number nor a percentage.
const RATE_STATS := ["attack_speed"]

## Icons are loaded once and kept, the way UITheme keeps its Theme: the panel rebuilds every square
## whenever something drops, and reloading four textures each time would be work for nothing.
static var _icons := {}


## Every item, in the order written above, which is also the order the inventory panel lists them in.
static func items() -> PackedStringArray:
	var all := PackedStringArray()
	for item: String in ITEMS:
		all.append(item)
	return all


static func icon_path(item: String) -> String:
	return ROOT + ITEMS[item]["icon"]


static func icon(item: String) -> Texture2D:
	if not _icons.has(item):
		_icons[item] = load(icon_path(item))
	return _icons[item]


## What this piece is worth before anything is rolled on top of it.
static func stats_of(item: String) -> Dictionary:
	return ITEMS[item]["stats"]


static func has_stat(item: String, stat: String) -> bool:
	return ITEMS.has(item) and ITEMS[item]["stats"].has(stat)


## A stat written for a person: "Damage 5", "Crit Chance 5%", "Attack Speed 1.0/s".
static func stat_line(stat: String, value: float) -> String:
	var label: String = STAT_LABELS.get(stat, stat)
	if stat in PERCENT_STATS:
		return "%s %d%%" % [label, roundi(value)]
	if stat in RATE_STATS:
		return "%s %.1f/s" % [label, value]
	return "%s %d" % [label, roundi(value)]


## How often this enemy leaves anything at all: its tier times its body, and never more than certain.
## Unlike health, a chance has a ceiling.
static func chance_for(enemy_name: String) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	return minf(tier * size, 1.0)


## One kill's worth of loot: null for nothing, or the item that dropped, rarity and modifiers and
## all. `rng` belongs to the caller, the way EnemyRoster.pick's does, so what is deterministic is the
## caller's business. `guaranteed` skips the chance and drops something whatever the roll -- the one
## promised elite drop goes through here too, so there is no second idea of what a drop looks like,
## and it rolls its rarity off the elite row like anything else: the promise is about getting
## something, not about what.
##
## The chance is drawn first and on its own, so a kill that leaves nothing still costs exactly one
## draw. That is what keeps the drop rate comparable to before rarities existed.
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false) -> Item:
	if not guaranteed and rng.randf() >= chance_for(enemy_name):
		return null
	var type := _weighted(rng)
	var rarity := ItemRarity.roll(EnemyRoster.tier_of(enemy_name), rng)
	return Item.rolled(type, rarity, rng)


## An item picked by weight. Integer weights, so walking the table cannot drift.
static func _weighted(rng: RandomNumberGenerator) -> String:
	var total := 0
	for item: String in ITEMS:
		total += int(ITEMS[item]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for item: String in ITEMS:
		pick -= int(ITEMS[item]["weight"])
		if pick < 0:
			return item
	return items()[0]
