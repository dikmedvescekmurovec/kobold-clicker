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
## weights are relative, not percentages: the amulet is the trophy of the set, and the boot the thing
## you end up with six of.
##
## Two lists, and the difference between them is the whole rule.
##
## `stats` is what the piece *is* -- the handful of numbers it shows, and the only stats a PERCENT
## modifier can scale, because "+14% increased Armour" needs armour to increase. `affixes` is what
## the piece can *carry*: stats it does not show and has none of, but can still roll a flat modifier
## for. A ring has no health of its own and still rolls "+8 Health", which is how Path of Exile has
## always done it, and it is what keeps a stat block two lines long while the modifier pool stays deep.
##
## Stats span pieces on purpose. Offence lives on the weapon -- `damage` is the sword's alone, or the
## sword stops being the interesting slot -- while health, armour and the resistances roll nearly
## everywhere, because a stat that adds up across what the player wears is what makes swapping any
## single piece worth doing. Two stay locked to one piece by what they are: `move_speed` is the
## boot's and `block_chance` belongs to a thing you hold.
##
## None of it depends on rarity: an elite sword hits like a common one and simply carries more on
## top. And nothing reads these numbers for gameplay yet; they are shown and saved, and the chunk
## that makes a click do `damage` will be the one to retune every one of them.
const ITEMS := {
	"Leather Boot": {
		"icon": "Leather Boot.png", "weight": 4,
		"stats": {"move_speed": 10, "dodge_chance": 4},
		"affixes": ["armor", "health", "fire_resist", "cold_resist", "lightning_resist", "dexterity"],
	},
	"Wooden Sword": {
		"icon": "Wooden Sword.png", "weight": 3,
		"stats": {"damage": 5, "crit_chance": 5, "crit_damage": 50, "attack_speed": 1.0},
		"affixes": ["leech", "life_on_hit", "strength"],
	},
	"Wooden Shield": {
		"icon": "Wooden Shield.png", "weight": 3,
		"stats": {"armor": 6, "block_chance": 10},
		"affixes": ["health", "energy_shield", "fire_resist", "cold_resist", "lightning_resist",
			"strength"],
	},
	"Wooden Torch": {
		"icon": "Wooden Torch.png", "weight": 3,
		"stats": {"energy_shield": 8, "health_regen": 2.0, "crit_damage": 20},
		"affixes": ["block_chance", "fire_resist", "cold_resist", "lightning_resist", "intelligence"],
	},
	"Wooden Armor": {
		"icon": "Wooden Armor.png", "weight": 2,
		"stats": {"armor": 10, "health": 20},
		"affixes": ["energy_shield", "dodge_chance", "fire_resist", "cold_resist",
			"lightning_resist", "strength"],
	},
	"Gold Ring": {
		"icon": "Gold Ring.png", "weight": 2,
		"stats": {"fire_resist": 5, "life_on_hit": 1},
		"affixes": ["health", "health_regen", "cold_resist", "lightning_resist", "strength",
			"dexterity", "intelligence"],
	},
	# The catch-all slot, and the rarest: the widest affix pool in the table, so an amulet is the one
	# piece that can turn up carrying almost anything.
	"Ruby Amulet": {
		"icon": "Ruby Amulet.png", "weight": 1,
		"stats": {"health": 15, "crit_damage": 20},
		"affixes": ["energy_shield", "health_regen", "crit_chance", "leech", "fire_resist",
			"cold_resist", "lightning_resist", "strength", "dexterity", "intelligence"],
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
	# Offence, which lives on the weapon.
	"damage": "Damage",
	"crit_chance": "Crit Chance",
	"crit_damage": "Crit Damage",
	"attack_speed": "Attack Speed",
	# Defence, which rolls nearly everywhere.
	"armor": "Armour",
	"energy_shield": "Energy Shield",
	"health": "Health",
	"health_regen": "Health Regen",
	"block_chance": "Block Chance",
	"dodge_chance": "Dodge Chance",
	"fire_resist": "Fire Resistance",
	"cold_resist": "Cold Resistance",
	"lightning_resist": "Lightning Resistance",
	# What a hit gives back.
	"leech": "Life Leech",
	"life_on_hit": "Life on Hit",
	# Utility.
	"move_speed": "Move Speed",
	# The attributes, which fit any piece because they say nothing about what the piece is.
	"strength": "Strength",
	"dexterity": "Dexterity",
	"intelligence": "Intelligence",
}
const PERCENT_STATS := ["crit_chance", "crit_damage", "block_chance", "move_speed", "dodge_chance",
	"fire_resist", "cold_resist", "lightning_resist", "leech"]
## Per second: attacks in one case and health in the other. The two stats that are neither a plain
## number nor a percentage.
const RATE_STATS := ["attack_speed", "health_regen"]

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


## Whether the piece has this as a base stat -- a number it shows, and so a number a PERCENT
## modifier has something to scale.
static func has_stat(item: String, stat: String) -> bool:
	return ITEMS.has(item) and ITEMS[item]["stats"].has(stat)


## The stats this piece can roll a flat modifier for without having any of its own.
static func affixes_of(item: String) -> Array:
	return ITEMS[item]["affixes"]


## Whether this piece can carry this stat at all, as a base stat or as an affix. The gate on a FLAT
## modifier, where `has_stat` is the gate on a PERCENT one.
static func can_roll(item: String, stat: String) -> bool:
	return has_stat(item, stat) or (ITEMS.has(item) and stat in ITEMS[item]["affixes"])


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
