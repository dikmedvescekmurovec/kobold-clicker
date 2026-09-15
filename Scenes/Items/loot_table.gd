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
	"Leather Helmet": {
		"icon": "Leather Helmet.png", "weight": 3, "slot": "helmet",
		"stats": {"armor": 3, "health": 5},
		"affixes": ["energy_shield", "fire_resist", "cold_resist", "lightning_resist", "strength",
			"intelligence"],
	},
	"Leather Boot": {
		"icon": "Leather Boot.png", "weight": 4, "slot": "boots",
		"stats": {"move_speed": 5, "dodge_chance": 2},
		"affixes": ["armor", "health", "fire_resist", "cold_resist", "lightning_resist", "dexterity"],
	},
	"Wooden Sword": {
		"icon": "Wooden Sword.png", "weight": 3, "slot": "weapon",
		"stats": {"damage": 1, "crit_chance": 5, "crit_damage": 50, "attack_speed": 1.0},
		"affixes": ["leech", "life_on_hit", "strength"],
	},
	"Wooden Shield": {
		"icon": "Wooden Shield.png", "weight": 3, "slot": "offhand",
		"stats": {"armor": 3, "block_chance": 5},
		"affixes": ["health", "energy_shield", "fire_resist", "cold_resist", "lightning_resist",
			"strength"],
	},
	"Wooden Torch": {
		"icon": "Wooden Torch.png", "weight": 3, "slot": "offhand",
		"stats": {"energy_shield": 4, "health_regen": 1.0, "crit_damage": 10},
		"affixes": ["block_chance", "fire_resist", "cold_resist", "lightning_resist", "intelligence"],
	},
	"Wooden Armor": {
		"icon": "Wooden Armor.png", "weight": 2, "slot": "body",
		"stats": {"armor": 5, "health": 10},
		"affixes": ["energy_shield", "dodge_chance", "fire_resist", "cold_resist",
			"lightning_resist", "strength"],
	},
	"Gold Ring": {
		"icon": "Gold Ring.png", "weight": 2, "slot": "ring",
		"stats": {"fire_resist": 3, "life_on_hit": 1},
		"affixes": ["health", "health_regen", "cold_resist", "lightning_resist", "strength",
			"dexterity", "intelligence"],
	},
	# The catch-all socket, and the rarest: the widest affix pool in the table, so an amulet is the
	# one piece that can turn up carrying almost anything.
	"Ruby Amulet": {
		"icon": "Ruby Amulet.png", "weight": 1, "slot": "amulet",
		"stats": {"health": 8, "crit_damage": 10},
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
## The percentages that are a *probability*: how often something happens, rather than how much of it
## there is. They are the ones a level may not multiply -- see `scale`. Crit damage is not one of
## them (500% crit damage is a fine number), and neither is leech, which is a share of a hit.
const CHANCE_STATS := ["crit_chance", "block_chance", "dodge_chance"]
## Per second: attacks in one case and health in the other. The two stats that are neither a plain
## number nor a percentage.
const RATE_STATS := ["attack_speed", "health_regen"]

## How much one level multiplies every scaled number by. The dial for how fast gear answers the
## frontier; Encounter.HP_GROWTH is the dial for how fast the frontier pulls away.
const LEVEL_GROWTH := 1.12

## What one level *adds*, on top of that multiplier, per stat.
##
## Per stat because an absolute step has to suit the size of the number it is added to: a point a
## level is the whole story for damage, which starts at 1, and a rounding error for crit damage,
## which starts at 50. A multiplier alone would leave a sword reading "Damage 1" for four levels; a
## flat step alone would do nothing to the large stats. Both together carry the whole range.
##
## Damage is a whole point a level on purpose, so a weapon gains a clean, visible point each time.
## Every key of STAT_LABELS has an entry here and test_inventory holds that, so a new stat cannot be
## added without saying what a level is worth to it.
const LEVEL_FLAT := {
	"damage": 1.0,
	"crit_chance": 1.0, "crit_damage": 5.0, "attack_speed": 0.05,
	"armor": 2.0, "energy_shield": 2.0, "health": 3.0, "health_regen": 0.1,
	"block_chance": 1.0, "dodge_chance": 1.0, "move_speed": 1.0,
	"fire_resist": 1.0, "cold_resist": 1.0, "lightning_resist": 1.0,
	"leech": 0.2, "life_on_hit": 1.0,
	"strength": 1.0, "dexterity": 1.0, "intelligence": 1.0,
}

## What a body's tier adds to the ceiling on what it drops, over the tile's own level. The elite at
## the end of a fight can hand over something the rabble on the same tile never could.
const TIER_LEVEL := {
	EnemyRoster.Tier.COMMON: 0,
	EnemyRoster.Tier.ELITE: 1,
	EnemyRoster.Tier.BOSS: 2,
}

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


## Where on the body this piece goes. `Equipment` turns it into sockets -- two of them take a ring,
## and one takes either a shield or a torch, so the mapping is not one-to-one and does not live here.
static func slot_of(item: String) -> String:
	return ITEMS[item]["slot"]


## The stats this piece can roll a flat modifier for without having any of its own.
static func affixes_of(item: String) -> Array:
	return ITEMS[item]["affixes"]


## Whether this piece can carry this stat at all, as a base stat or as an affix. The gate on a FLAT
## modifier, where `has_stat` is the gate on a PERCENT one.
static func can_roll(item: String, stat: String) -> bool:
	return has_stat(item, stat) or (ITEMS.has(item) and stat in ITEMS[item]["affixes"])


## What `value` of `stat` is worth at `level`. The one place that knows what a level does to a
## number, so a piece's base stats and a modifier's band grow the same way and cannot drift apart.
## Level 1 is the number as written, so a level-1 piece is exactly the piece the table describes.
##
## A CHANCE_STAT takes the flat step alone. A probability has a ceiling that a quantity has not, and
## the exponent walked straight through it: a plain set of commons reached 163% crit chance by level
## 30, which is every hit critting and a stat block that reads as nonsense. The flat step still grows
## it -- a point of crit chance a level -- but at a pace the ceiling can hold.
static func scale(stat: String, value: float, level: int) -> float:
	var steps := maxi(level - 1, 0)
	var grown := value if stat in CHANCE_STATS else value * pow(LEVEL_GROWTH, steps)
	return grown + float(LEVEL_FLAT.get(stat, 0.0)) * steps


## A stat written for a person: "Damage 5", "Crit Chance 5%", "Attack Speed 1.0/s".
static func stat_line(stat: String, value: float) -> String:
	var label: String = STAT_LABELS.get(stat, stat)
	if stat in PERCENT_STATS:
		return "%s %d%%" % [label, roundi(value)]
	if stat in RATE_STATS:
		return "%s %.1f/s" % [label, value]
	return "%s %d" % [label, roundi(value)]


## The same stat as a difference: "Damage +13", "Crit Chance -2%", "Attack Speed +0.3/s".
##
## Here rather than at the panel that shows it, for the reason `stat_line` is: this file is the one
## place a stat is spelled, and a second spelling of "Attack Speed" is a second thing to keep in step.
## The sign is always written, including on a gain -- "Damage 13" and "Damage +13" are two different
## claims, and only one of them is what a comparison means.
static func stat_delta(stat: String, delta: float) -> String:
	var label: String = STAT_LABELS.get(stat, stat)
	if stat in PERCENT_STATS:
		return "%s %+d%%" % [label, roundi(delta)]
	if stat in RATE_STATS:
		return "%s %+.1f/s" % [label, delta]
	return "%s %+d" % [label, roundi(delta)]


## Whether a difference is worth saying at all. A delta that rounds to nothing on the line would read
## as "+0 Armour", which says a stat changed and then says it did not -- so the two pieces are
## compared as the numbers the player can actually see, not as the floats behind them.
static func delta_shows(stat: String, delta: float) -> bool:
	if stat in RATE_STATS:
		return absf(delta) >= 0.05
	return roundi(delta) != 0


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
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false,
		tile_level := 1) -> Item:
	if not guaranteed and rng.randf() >= chance_for(enemy_name):
		return null
	var type := _weighted(rng)
	var tier := EnemyRoster.tier_of(enemy_name)
	var rarity := ItemRarity.roll(tier, rng)
	# The tile's level and the body's tier give a ceiling; the piece rolls its own level under it,
	# so a deep tile is a better place to fight rather than a guaranteed prize.
	var ceiling := maxi(1, tile_level + int(TIER_LEVEL[tier]))
	return Item.rolled(type, rarity, rng, ItemRarity.roll_level(rarity, ceiling, rng))


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
