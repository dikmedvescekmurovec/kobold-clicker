class_name LootTable
extends RefCounted
## The kinds of gear and the pieces built from them, the gear roll, what a level does to a number, and
## how every stat is spelled. Const tables and statics, no nodes.

const ROOT := "res://Assets/Gear/"
## The icons `tools/ui_kit.py` replaced (`BASE_OLD`), shown under `Settings.show_old_icons()`.
const OLD_ROOT := ROOT + "Old/"

## kind -> its row. Which kind drops is one weighted draw, and which of its materials another
## (`weighted`). Rarity changes none of it: an epic sword hits like a common one.
##   slot         where it is worn (`Equipment.TAKES`); "stone" is never worn.
##   weight       the kind's share of the gear draw; 0 is never dealt. The weights' sum keeps each
##                slot's share of drops (CLAUDE.md).
##   needs        the attribute a piece asks for past `NEEDS_FROM` (`requirement`); absent: none.
##   stats        what the piece shows, and all a PERCENT modifier can scale.
##   affixes      stats it shows none of and may roll a FLAT modifier for; never one of `stats`.
##   globals      stats it may roll a GLOBAL modifier for: the jewellery's alone.
##   tiers        its pieces by name, weakest material first.
##   power        stat -> factor, applied after the level (`power_of`), never written into `stats`.
##   two_handed   closes the offhand while worn.
##   tier_levels  the tile levels its materials unlock at, where not `TIER_MIN_LEVEL`'s.
##   tier_stats   each material's stats stated outright, in place of `stats` (the torch's alone).
##   icons        a skill stone's picture by tier (`icon_path`).
## Every stat named needs a modifier that reaches it (`test_inventory`'s `_test_items`), and
## `_test_slot_locks` pins which kinds may carry, and which show, damage, move speed, block, bleed and
## sight. The why: DESIGN.md.
const KINDS := {
	# --- Helmets
	"helm": {
		"slot": "helmet", "weight": 18, "needs": "strength",
		"stats": {"armor": 3},
		"affixes": ["time_on_hit", "strength", "intelligence", "xp_more", "blow_delay", "elite_ward",
			"tile_ward", "less_health", "strength_stones", "intelligence_stones", "dexterity_stones"],
		"tiers": ["Leather Helmet", "Iron Helmet", "Steel Helm", "Golden Helm", "Masterwork Helm"],
	},
	"hood": {
		"slot": "helmet", "weight": 18, "needs": "dexterity",
		"stats": {"dodge": 3},
		"affixes": ["armor", "dexterity", "intelligence", "xp_more", "blow_delay", "elite_ward",
			"tile_ward", "less_health", "strength_stones", "intelligence_stones", "dexterity_stones"],
		"tiers": ["Hide Hood", "Leather Hood", "Studded Hood", "Shadow Hood", "Masterwork Hood"],
	},
	# --- Boots
	"boot": {
		"slot": "boots", "weight": 24, "needs": "dexterity",
		"stats": {"move_speed": 5, "dodge": 2},
		"affixes": ["armor", "dexterity"],
		"tiers": ["Leather Boots", "Studded Boots", "Ranger's Boots", "Shadow Boots", "Masterwork Boots"],
	},
	# No first material (the Bronze Greaves went: the user's, 2026-09-24), so a greaves roll under level 3
	# is dealt as the Leather Boots (`tier_at`).
	"greaves": {
		"slot": "boots", "weight": 24, "needs": "strength",
		"stats": {"move_speed": 4, "armor": 3},
		"affixes": ["dodge", "strength"],
		"tier_levels": [3, 5, 7, 9],
		"tiers": ["Iron Greaves", "Steel Greaves", "Golden Greaves", "Masterwork Greaves"],
	},
	# --- Weapons: one base damage and a `power` factor apiece. Every number of the mace's sits between
	# the sword's and the greatsword's (the user's ruling, 2026-09-24; DESIGN.md).
	"sword": {
		"slot": "weapon", "weight": 12, "needs": "strength",
		"stats": {"damage": 1, "crit_chance": 5, "crit_damage": 50, "attack_speed": 1.0},
		"affixes": ["time_on_hit", "strength",
			"click_damage", "swing_damage", "elite_damage", "first_blow", "double_strike"],
		"tiers": ["Wooden Sword", "Iron Sword", "Steel Sword", "Golden Sword", "Masterwork Sword"],
	},
	"dagger": {
		"slot": "weapon", "weight": 9, "needs": "dexterity",
		"stats": {"damage": 1, "crit_chance": 8, "crit_damage": 50, "attack_speed": 1.8},
		"affixes": ["time_on_hit", "dexterity",
			"click_damage", "swing_damage", "elite_damage", "first_blow", "double_strike"],
		"power": {"damage": 0.6},
		"tiers": ["Bone Knife", "Iron Dagger", "Steel Stiletto", "Golden Kris", "Masterwork Dagger"],
	},
	"mace": {
		"slot": "weapon", "weight": 9, "needs": "strength",
		"stats": {"damage": 1, "crit_chance": 5, "crit_damage": 60, "attack_speed": 0.75, "bleed": 20},
		"affixes": ["time_on_hit", "strength",
			"click_damage", "swing_damage", "elite_damage", "first_blow", "double_strike"],
		"power": {"damage": 1.3},
		"tiers": ["Wooden Club", "Iron Mace", "Steel Morningstar", "Golden Sceptre", "Masterwork Mace"],
	},
	"greatsword": {
		"slot": "weapon", "weight": 6, "needs": "strength", "two_handed": true,
		"stats": {"damage": 1, "crit_chance": 5, "crit_damage": 75, "attack_speed": 0.5},
		"affixes": ["time_on_hit", "strength",
			"click_damage", "swing_damage", "elite_damage", "first_blow", "double_strike"],
		"power": {"damage": 2.2},
		"tiers": ["Wooden Greatsword", "Iron Claymore", "Steel Zweihander", "Golden Greatsword", "Masterwork Greatsword"],
	},
	# `FIRST_DROP` and nothing else: weight 0, so no roll deals one.
	"broken_sword": {
		"slot": "weapon", "weight": 0, "needs": "strength",
		"stats": {"damage": 1},
		"affixes": ["time_on_hit", "strength",
			"click_damage", "swing_damage", "elite_damage", "first_blow", "double_strike"],
		"tiers": ["Broken Sword"],
	},
	# --- Offhand
	"shield": {
		"slot": "offhand", "weight": 30, "needs": "strength",
		"stats": {"armor": 3, "block": 2},
		"affixes": ["strength", "time_on_block"],
		"tiers": ["Wooden Shield", "Iron Shield", "Steel Kite Shield", "Golden Aegis", "Masterwork Shield"],
	},
	"buckler": {
		"slot": "offhand", "weight": 24, "needs": "dexterity",
		"stats": {"dodge": 3, "block": 2},
		"affixes": ["armor", "dexterity", "parry"],
		"tiers": ["Hide Buckler", "Iron Buckler", "Steel Targe", "Golden Buckler", "Masterwork Buckler"],
	},
	# Sight is the whole piece: three materials on levels of their own, each stated outright. With no
	# base number for a PERCENT modifier to scale every affix is flat, and there are enough of them for an
	# epic's six lines.
	"torch": {
		"slot": "offhand", "weight": 18, "needs": "intelligence",
		"tier_levels": [1, 5, 9],
		"tier_stats": [{"sight": 1}, {"sight": 2}, {"sight": 3}],
		"affixes": ["block", "crit_chance", "crit_damage", "intelligence", "burn", "move_speed",
			"xp_more", "orb_find"],
		"tiers": ["Wooden Torch", "Blazing Torch", "Masterwork Torch"],
	},
	# `BROKEN_TORCH`: weight 0, a Wooden Torch's Sight, handed out only by `Inventory.transcended()`.
	"broken_torch": {
		"slot": "offhand", "weight": 0, "needs": "intelligence",
		"stats": {"sight": 1},
		"affixes": ["block", "crit_chance", "crit_damage", "intelligence", "burn", "move_speed",
			"xp_more", "orb_find"],
		"tiers": ["Broken Torch"],
	},
	# --- Body
	"plate": {
		"slot": "body", "weight": 12, "needs": "strength",
		"stats": {"armor": 5},
		"affixes": ["time_on_hit", "dodge", "strength", "camp_earnings", "extra_enemies", "thorns", "recoup"],
		"tiers": ["Wooden Armour", "Iron Armour", "Steel Plate", "Golden Plate", "Masterwork Plate"],
	},
	"jerkin": {
		"slot": "body", "weight": 12, "needs": "dexterity",
		"stats": {"dodge": 5},
		"affixes": ["armor", "time_on_hit", "dexterity", "camp_earnings", "extra_enemies", "thorns", "recoup"],
		"tiers": ["Hide Jerkin", "Leather Jerkin", "Studded Jerkin", "Shadow Leathers", "Masterwork Jerkin"],
	},
	# --- Jewellery: one material apiece, no `needs`, and the only `globals`. Offence is all modifiers
	# here. A global on a stat the piece shows takes the place of its own percent
	# (`ModifierTable.pool_for`). The five rings share the slot's weight of 24; every ring may roll every
	# finder but drop rate, which is the amulets'.
	"gold_ring": {
		"slot": "ring", "weight": 5,
		"stats": {"gold_find": 20},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"item_rarity", "orb_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage"],
		"tiers": ["Gold Ring"],
	},
	"iron_band": {
		"slot": "ring", "weight": 5,
		"stats": {"armor": 2},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"item_rarity", "gold_find", "orb_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage", "armor"],
		"tiers": ["Iron Band"],
	},
	"jade_ring": {
		"slot": "ring", "weight": 5,
		"stats": {"dodge": 2},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"item_rarity", "gold_find", "orb_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage", "dodge"],
		"tiers": ["Jade Ring"],
	},
	"opal_ring": {
		"slot": "ring", "weight": 5,
		"stats": {"item_rarity": 15},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"gold_find", "orb_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage"],
		"tiers": ["Opal Ring"],
	},
	"pearl_ring": {
		"slot": "ring", "weight": 4,
		"stats": {"orb_find": 15},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"item_rarity", "gold_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage"],
		"tiers": ["Pearl Ring"],
	},
	# The amulets: the widest pools in the table.
	"ruby_amulet": {
		"slot": "amulet", "weight": 4,
		"stats": {"crit_damage": 10},
		"affixes": ["crit_chance", "damage", "drop_rate", "time_on_hit", "strength", "dexterity",
			"intelligence", "item_rarity", "all_attributes"],
		"globals": ["damage", "attack_speed", "bleed", "armor", "dodge", "time_on_hit"],
		"tiers": ["Ruby Amulet"],
	},
	"gold_amulet": {
		"slot": "amulet", "weight": 4,
		"stats": {"drop_rate": 5},
		"affixes": ["crit_chance", "crit_damage", "damage", "time_on_hit", "strength",
			"dexterity", "intelligence", "item_rarity", "all_attributes"],
		"globals": ["damage", "attack_speed", "bleed", "armor", "dodge", "time_on_hit"],
		"tiers": ["Gold Amulet"],
	},
	"emerald_amulet": {
		"slot": "amulet", "weight": 4,
		"stats": {"crit_chance": 3},
		"affixes": ["crit_damage", "damage", "drop_rate", "time_on_hit", "strength",
			"dexterity", "intelligence", "item_rarity", "all_attributes"],
		"globals": ["damage", "attack_speed", "bleed", "armor", "dodge", "time_on_hit"],
		"tiers": ["Emerald Amulet"],
	},
	# --- Skill stones (the user's, 2026-10-08): never worn, placed in the skill tree. Weight 0, so the
	# gear's draw, the shelves and the bounties pass them by; `SkillTree.roll` drops them. Their lines are
	# `SkillTree.LINES`, not `affixes`. `icons` are `tools/skill_stones.py`'s discs, one a tier.
	"strength_stone": {
		"slot": "stone", "weight": 0,
		"stats": {"strength": 5},
		"affixes": [],
		"tiers": ["Strength Node"],
		"icons": "res://Assets/Skills/Stones/str_%d.png",
	},
	"dexterity_stone": {
		"slot": "stone", "weight": 0,
		"stats": {"dexterity": 5},
		"affixes": [],
		"tiers": ["Dexterity Node"],
		"icons": "res://Assets/Skills/Stones/dex_%d.png",
	},
	"intelligence_stone": {
		"slot": "stone", "weight": 0,
		"stats": {"intelligence": 5},
		"affixes": [],
		"tiers": ["Intelligence Node"],
		"icons": "res://Assets/Skills/Stones/int_%d.png",
	},
}

## The tile level each material is found from -- the tile's, never the piece's own (the user's,
## 2026-09-28) -- and what each step up the materials adds to every quantity (`power_of`). Both are
## dials. A piece's step is its `material`: where its own unlock level stands in this list, so the
## greaves' first piece takes iron's and the torch's three the plainest's, steel's and the masterwork's.
const TIER_MIN_LEVEL := [1, 3, 5, 7, 9]
const TIER_POWER := 0.5
## What wearing a piece asks for (the user's, 2026-09-28): nothing up to item level `NEEDS_FROM`, and
## past it its kind's `needs` at `NEEDS_LINE` grown by `scale`, about one attribute line of its level
## (`requirement`). Both are dials.
const NEEDS_FROM := 5
const NEEDS_LINE := 5.0
## The player's first piece of gear: while it is owed (`Encounter.PROMISED`'s `SWORD`) the fight swaps
## it in for whatever was rolled, common and level 1.
const FIRST_DROP := "Broken Sword"
## What `Inventory.transcended` puts in a new world's bag under the Thick Fog.
const BROKEN_TORCH := "Broken Torch"
## A piece's name in an older save -> its name now (`current`, which `Item.from_dict` asks).
const RENAMED := {
	"Wooden Armor": "Wooden Armour",
	"Iron Armor": "Iron Armour",
	"Leather Boot": "Leather Boots",
	"Studded Boot": "Studded Boots",
	"Ranger's Boot": "Ranger's Boots",
	"Shadow Boot": "Shadow Boots",
	"Masterwork Boot": "Masterwork Boots",
	# The player calls the skill tree's stones nodes (the user's, 2026-10-09).
	"Strength Stone": "Strength Node",
	"Dexterity Stone": "Dexterity Node",
	"Intelligence Stone": "Intelligence Node",
}


static func current(type: String) -> String:
	return RENAMED.get(type, type)

## name -> the read-only row every caller reads: `icon`, `weight`, `slot`, `stats`, `affixes`, and
## `globals` and `icons` where its kind has them, plus its `kind`, its `tier` (its place in the kind's
## list) and its `material` (its strength step: `power_of`, the loot filter). In `KINDS`' order, which
## the panels list by; within a slot the kind the game shipped with is first (CLAUDE.md).
static var ITEMS := _build_items()

## How often a body leaves gear, by its tier (`chance_for`).
const TIER_CHANCE := {
	EnemyRoster.Tier.COMMON: 0.03,
	EnemyRoster.Tier.ELITE: 0.15,
	EnemyRoster.Tier.BOSS: 0.40,
}

## And by its size. `OrbTable.chance_for` and `UniqueTable.chance_for` multiply by it too.
const SIZE_CHANCE := {
	EnemyRoster.Size.TINY: 0.5,
	EnemyRoster.Size.SMALL: 0.8,
	EnemyRoster.Size.MEDIUM: 1.0,
	EnemyRoster.Size.LARGE: 1.3,
	EnemyRoster.Size.HUGE: 1.6,
}

## stat -> how it is written. Every stat there is has a key here and in `LEVEL_FLAT` (a test holds
## it), and `Item.from_dict` drops a saved stat that has none.
const STAT_LABELS := {
	# Offence.
	"damage": "Damage",
	"crit_chance": "Crit Chance",
	"crit_damage": "Crit Damage",
	"attack_speed": "Attack Speed",
	"bleed": "Bleed",
	# The weapons' lines: percentages of one kind of blow, summed by `Encounter.gear_more`.
	"click_damage": "Click Damage",
	"swing_damage": "Swing Damage",
	"elite_damage": "Elite Damage",
	"first_blow": "First Blow Damage",
	"double_strike": "Double Strike",
	# Defence: what keeps an enemy's blow off the fight clock (`Encounter.taken`).
	"armor": "Armour",
	"dodge": "Dodge",
	"block": "Block",
	"time_on_hit": "Time on Hit",
	"fight_clock": "Fight Clock",
	# Utility.
	"move_speed": "Move Speed",
	"drop_rate": "Drop Rate",
	# A count of tiles, never a percentage.
	"sight": "Sight",
	"strength": "Strength",
	"dexterity": "Dexterity",
	"intelligence": "Intelligence",
	"all_attributes": "All Attributes",
	"item_rarity": "Item Rarity",
	"gold_find": "Gold Find",
	"orb_find": "Orb Find",
	# A share of the next enemy's walk-in, capped at 100 by `Encounter.arm`.
	"spawn_speed": "Spawn Speed",
	"xp_more": "Experience",
	# How often a common comes on as an elite instead (`Encounter.arm`).
	"elite_chance": "Elite Chance",
	# The helmet's lines (`Encounter.arm`; the stone ranks, `Inventory._tree`).
	"blow_delay": "Enemy First Blow Delay",
	"elite_ward": "Elite Blow Reduction",
	"tile_ward": "Tile Modifier Reduction",
	"less_health": "Enemy Health Reduction",
	"strength_stones": "Strength Node Ranks",
	"intelligence_stones": "Intelligence Node Ranks",
	"dexterity_stones": "Dexterity Node Ranks",
	# A skill stone's own: the points it takes past its tier's base (`SkillTree.most_ranks`).
	"stone_ranks": "Skill Points",
	# The body's (`Camp.make`, the fight).
	"camp_earnings": "Camp Earnings",
	"extra_enemies": "Enemies per Fight",
	"thorns": "Thorns",
	"recoup": "Recoup",
	# The offhand's: the buckler's, the torch's, and the shield's (in tenths).
	"parry": "Crit after a Dodge",
	"burn": "Burn",
	"time_on_block": "Time on Block",
}
const PERCENT_STATS := ["crit_chance", "crit_damage", "move_speed", "drop_rate", "bleed",
	"item_rarity", "gold_find", "orb_find", "spawn_speed", "click_damage", "swing_damage",
	"elite_damage", "first_blow", "double_strike", "xp_more", "elite_chance", "blow_delay",
	"elite_ward", "tile_ward", "less_health", "camp_earnings", "thorns", "recoup", "parry", "burn"]
## The stats a level adds a step to and never multiplies (`scale`): chances, shares, finders and whole
## counts, each of which a compounding level would walk through a ceiling. Crit damage is not one. The
## material's share of `power_of` skips them too. Why each is here: DESIGN.md, "Let only
## `LootTable.scale` know what a level does" and "Keep `gold_find`, `item_rarity`, `bleed` and `sight`
## in `CHANCE_STATS`".
const CHANCE_STATS := ["crit_chance", "drop_rate", "gold_find", "item_rarity", "orb_find", "bleed",
	"sight", "spawn_speed", "fight_clock", "double_strike", "xp_more", "elite_chance", "blow_delay",
	"elite_ward", "tile_ward", "less_health", "strength_stones", "intelligence_stones", "dexterity_stones",
	"stone_ranks", "camp_earnings", "extra_enemies", "thorns", "recoup", "parry", "burn"]
## The stats every piece may roll a FLAT modifier for (`can_roll`).
const ANY_AFFIXES := ["spawn_speed", "fight_clock"]
## Per second, and kept to one decimal: the one stat neither whole nor a percentage.
const RATE_STATS := ["attack_speed"]
## Seconds of the fight clock, **stored in tenths**: the one place a stat is not stored as the number it
## shows. A modifier rolls whole numbers, and a whole second of block would stop every early blow.
## Read and written only through `seconds_of` / `seconds_text` (`stat_value`, `stat_delta`,
## `ModifierTable.amount`, `Encounter.arm`).
const SECONDS_STATS := ["block", "time_on_hit", "fight_clock", "time_on_block"]

## What one level multiplies a scaled number by (`scale`). `Encounter.HP_GROWTH` is the enemies' side.
const LEVEL_GROWTH := 1.12

## What one level adds to each stat on top of the multiplier (`scale`): sized to the stat, since a
## multiplier alone leaves "Damage 1" for four levels. Every key of `STAT_LABELS` has one (a test
## holds it). A 0 on one of `CHANCE_STATS` is a number no level moves; a 0 on any other grows by the
## multiplier alone, as a PERCENT modifier does. Damage's 0.4 is the user's ruling (2026-09-27).
const LEVEL_FLAT := {
	"damage": 0.4,
	"crit_chance": 1.0, "crit_damage": 5.0, "attack_speed": 0.05, "bleed": 1.0,
	"armor": 2.0, "dodge": 2.0, "block": 1.0, "time_on_hit": 1.0,
	"move_speed": 1.0, "drop_rate": 1.0,
	"strength": 1.0, "dexterity": 1.0, "intelligence": 1.0, "all_attributes": 1.0,
	"click_damage": 0.0, "swing_damage": 0.0, "elite_damage": 0.0, "first_blow": 0.0,
	"double_strike": 1.0,
	"xp_more": 1.0, "elite_chance": 0.0,
	"blow_delay": 1.0, "elite_ward": 1.0, "tile_ward": 1.0, "less_health": 1.0,
	"camp_earnings": 1.0, "thorns": 1.0, "recoup": 1.0, "parry": 1.0, "burn": 1.0, "time_on_block": 1.0,
	"extra_enemies": 0.0, "strength_stones": 0.0, "intelligence_stones": 0.0, "dexterity_stones": 0.0,
	"stone_ranks": 0.0,
	"item_rarity": 1.0, "gold_find": 1.0, "orb_find": 1.0,
	"sight": 0.0,
	"spawn_speed": 0.0,
	"fight_clock": 0.0,
}

## What a body's tier adds to its tile's level as the ceiling on its drop's level (`drop_level`).
const TIER_LEVEL := {
	EnemyRoster.Tier.COMMON: 0,
	EnemyRoster.Tier.ELITE: 2,
	EnemyRoster.Tier.BOSS: 3,
}
## The share of a common body's drops that are a level past its tile outright (the user's "rarely",
## 2026-10-03).
const COMMON_REACH := 0.1

## path -> texture. By path, not by item, so `Settings.show_old_icons()` shows at the next draw.
static var _icons := {}


## Every piece's name, in `KINDS`' order.
static func items() -> PackedStringArray:
	var all := PackedStringArray()
	for item: String in ITEMS:
		all.append(item)
	return all


## Where the piece's picture is. One with no art yet borrows its kind's plainest, then its slot's first
## kind's (`UniqueTable.icon` falls back the same way); under `Settings.show_old_icons()` the picture
## it had before, where it had another. A skill stone's is its tier's (`icons`).
static func icon_path(item: String, tier := 1) -> String:
	var row: Dictionary = ITEMS[item]
	if row.has("icons"):
		return str(row["icons"]) % clampi(tier, 1, SkillTree.MOST_TIER)
	if Settings.show_old_icons() and ResourceLoader.exists(OLD_ROOT + str(row["icon"])):
		return OLD_ROOT + str(row["icon"])
	var tiers: Array = KINDS[kind_of(item)]["tiers"]
	for name: String in [item, str(tiers[0]), _first_of_slot(str(row["slot"]))]:
		var path: String = ROOT + str(ITEMS[name]["icon"])
		if ResourceLoader.exists(path):
			return path
	return ROOT + str(row["icon"])


static func icon(item: String, tier := 1) -> Texture2D:
	var path := icon_path(item, tier)
	if not _icons.has(path):
		_icons[path] = load(path)
	return _icons[path]


## The piece's stats as the table writes them: at level 1, before `power_of`.
static func stats_of(item: String) -> Dictionary:
	return ITEMS[item]["stats"]


## The gate on a PERCENT modifier: a stat the piece shows.
static func has_stat(item: String, stat: String) -> bool:
	return ITEMS.has(item) and ITEMS[item]["stats"].has(stat)


## Its slot, which `Equipment.TAKES` joins to sockets.
static func slot_of(item: String) -> String:
	return ITEMS[item]["slot"]


static func kind_of(item: String) -> String:
	return ITEMS[item]["kind"]


## The factor on `stat` for the piece's kind and material, applied after `scale` by `Item.scaled_stats`
## and nowhere else. The material's share skips chances and rates; the kind's does not (CLAUDE.md).
static func power_of(item: String, stat: String) -> float:
	var power: Dictionary = KINDS[kind_of(item)].get("power", {})
	var factor := float(power.get(stat, 1.0))
	if stat in CHANCE_STATS or stat in RATE_STATS:
		return factor
	return factor * (1.0 + TIER_POWER * int(ITEMS[item]["material"]))


static func two_handed(item: String) -> bool:
	return bool(KINDS[kind_of(item)].get("two_handed", false))


## What a piece of `item` at `level` asks of the player: [attribute, points], or [] for nothing. A
## unique asks what its base does. `Inventory.why_not_equip` is the gate.
static func requirement(item: String, level: int) -> Array:
	var attribute: String = KINDS[kind_of(item)].get("needs", "")
	if attribute.is_empty() or level <= NEEDS_FROM:
		return []
	# ponytail: what it asks is a whole int, which passes int64 near item level 370 -- far past where a
	# monster's health would have; `roundf` then.
	return [attribute, roundi(scale(attribute, NEEDS_LINE, level))]


static func affixes_of(item: String) -> Array:
	return ITEMS[item]["affixes"]


## The gate on a FLAT modifier: a stat the piece shows, an affix of its kind, or one of `ANY_AFFIXES`.
static func can_roll(item: String, stat: String) -> bool:
	return has_stat(item, stat) or (ITEMS.has(item) and (stat in ITEMS[item]["affixes"] or stat in ANY_AFFIXES))


static func globals_of(item: String) -> Array:
	return ITEMS[item].get("globals", []) if ITEMS.has(item) else []


## The gate on a GLOBAL modifier.
static func can_globalize(item: String, stat: String) -> bool:
	return stat in globals_of(item)


## What `value` of `stat` is worth at `level`: the one place that knows what a level does to a number,
## so base stats and modifier bands grow alike. Level 1 is the number as written. One of
## `CHANCE_STATS` takes the step alone. `flat` is the step in place of the stat's own
## (`ModifierTable`'s `level_flat`, its one caller).
static func scale(stat: String, value: float, level: int, flat := NAN) -> float:
	var steps := maxi(level - 1, 0)
	var grown := value if stat in CHANCE_STATS else value * pow(LEVEL_GROWTH, steps)
	var step := float(LEVEL_FLAT.get(stat, 0.0)) if is_nan(flat) else flat
	return grown + step * steps


## "5 Damage", "5% Crit Chance", "1.0/s Attack Speed". The number leads every line an item writes:
## `ItemDetails` splits on the first space.
static func stat_line(stat: String, value: float) -> String:
	return "%s %s" % [stat_value(stat, value), STAT_LABELS.get(stat, stat)]


## The number alone: "5", "5%", "1.0/s".
static func stat_value(stat: String, value: float) -> String:
	if stat in PERCENT_STATS:
		return BigNumber.format(value) + "%"
	if stat in RATE_STATS:
		return "%.1f/s" % value
	if stat in SECONDS_STATS:
		return seconds_text(value)
	return BigNumber.format(value)


## The stat as a difference, its sign always written: "+13 Damage", "-2% Crit Chance", "+0.3/s Attack
## Speed".
static func stat_delta(stat: String, delta: float) -> String:
	var label: String = STAT_LABELS.get(stat, stat)
	if stat in PERCENT_STATS:
		return "%s%% %s" % [BigNumber.format(delta, true), label]
	if stat in RATE_STATS:
		return "%+.1f/s %s" % [delta, label]
	if stat in SECONDS_STATS:
		return "%s %s" % [seconds_text(delta, true), label]
	return "%s %s" % [BigNumber.format(delta, true), label]


## One of `SECONDS_STATS`' stored tenths in seconds; any other stat as it is.
static func seconds_of(stat: String, value: float) -> float:
	return value / 10.0 if stat in SECONDS_STATS else value


## Tenths of a second written as seconds: "0.3s", "+1.2s", and "1.23Ms" from a hundred seconds up.
static func seconds_text(tenths: float, signed := false) -> String:
	var seconds := tenths / 10.0
	if absf(seconds) >= 100.0:
		return BigNumber.format(seconds, signed) + "s"
	return ("%+.1fs" if signed else "%.1fs") % seconds


## Whether a difference is worth a line: one that rounds to nothing would read "+0 Armour".
static func delta_shows(stat: String, delta: float) -> bool:
	if stat in RATE_STATS:
		return absf(delta) >= 0.05
	# `roundf`, not `roundi`: a difference past int64 would come back out of an int as anything.
	return roundf(delta) != 0.0


## How often this enemy leaves gear: its tier times its size, lifted by `drop_rate` percent, capped at 1.
static func chance_for(enemy_name: String, drop_rate := 0.0) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	# Down to nothing and no further: Lean Pickings hands in a lift under zero (`Encounter._gear_rate`).
	return minf(tier * size * (1.0 + maxf(drop_rate, -100.0) / 100.0), 1.0)


## One kill's gear: null, or the `Item` that dropped. The chance is drawn first and alone, so a kill
## that leaves nothing costs exactly one draw. `guaranteed` skips the chance and nothing else. Rarity
## and level are settled before the type. `forced` is a rarity to roll at in place of drawing one (the
## dev's even loot, `Encounter`).
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false,
		tile_level := 1, drop_rate := 0.0, item_rarity := 0.0, forced := -1) -> Item:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, drop_rate):
		return null
	var tier := EnemyRoster.tier_of(enemy_name)
	var rarity := ItemRarity.roll(tier, rng, item_rarity) if forced < 0 else forced as ItemRarity.Rarity
	var level := drop_level(tier, tile_level, rarity, rng)
	# The material is gated by the tile's level, never the piece's own.
	return Item.rolled(weighted(rng, tile_level), rarity, rng, level)


## The level a body's drop comes out at: rolled under the tile's level plus its tier's `TIER_LEVEL`,
## rarity lifting the floor -- but `COMMON_REACH` of a common body's drops are a level past the tile
## outright. `UniqueTable.roll` asks it too.
static func drop_level(tier: EnemyRoster.Tier, tile_level: int, rarity: ItemRarity.Rarity,
		rng: RandomNumberGenerator) -> int:
	if tier == EnemyRoster.Tier.COMMON and rng.randf() < COMMON_REACH:
		return maxi(1, tile_level + 1)
	return ItemRarity.roll_level(rarity, maxi(1, tile_level + int(TIER_LEVEL[tier])), rng)


## A piece by weight: the kind, then one of its materials. `level` is the tile's, not the piece's own.
static func weighted(rng: RandomNumberGenerator, level := 1) -> String:
	return tier_at(roll_kind(rng), level, rng)


## A kind by weight and nothing more: what a bounty's card promises, its material drawn only as the
## piece is handed over.
static func roll_kind(rng: RandomNumberGenerator) -> String:
	return KINDS.keys()[weighted_index(KINDS.values().map(func(row: Dictionary) -> int: return int(row["weight"])), rng)]


## The index of the weight one `randi_range` over the sum of `weights` falls inside. Every weighted
## pick in the tables is this walk (a kind, a modifier, an orb, a rarity, a rune, a node's
## connectors, an enemy in `EnemyRoster.pick`, a tile's modifier in `TileMods.for_cell`), so a change
## here changes what every seed draws.
static func weighted_index(weights: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight: int in weights:
		total += weight
	var pick := rng.randi_range(0, total - 1)
	for index in weights.size():
		pick -= int(weights[index])
		if pick < 0:
			return index
	return 0


## One of a kind's materials: an even draw among those `level` has unlocked, the plainest included (the
## user's, 2026-09-28), and no draw at all while only one is. A kind whose first material `level` has
## not reached is dealt as its slot's plainest piece. `draws` keeps the best of that many draws (a
## cleared board's piece).
static func tier_at(kind: String, level: int, rng: RandomNumberGenerator, draws := 1) -> String:
	var row: Dictionary = KINDS[kind]
	var tiers: Array = row["tiers"]
	var levels: Array = row.get("tier_levels", TIER_MIN_LEVEL)
	if level < first_level(kind):
		return _first_of_slot(str(row["slot"]))
	var unlocked := 1
	for tier in tiers.size():
		if level >= int(levels[tier]):
			unlocked = tier + 1
	if unlocked == 1:
		return str(tiers[0])
	var best := 0
	for i in draws:
		best = maxi(best, rng.randi_range(0, unlocked - 1))
	return str(tiers[best])


## `ITEMS` out of `KINDS`, each row read-only.
static func _build_items() -> Dictionary:
	var out := {}
	for kind: String in KINDS:
		var row: Dictionary = KINDS[kind]
		var tiers: Array = row["tiers"]
		var levels: Array = row.get("tier_levels", TIER_MIN_LEVEL)
		for tier in tiers.size():
			var name := str(tiers[tier])
			var item := {
				"icon": name + ".png", "weight": int(row["weight"]), "slot": row["slot"],
				"stats": row["tier_stats"][tier] if row.has("tier_stats") else row["stats"],
				"affixes": row["affixes"], "kind": kind, "tier": tier,
				"material": maxi(TIER_MIN_LEVEL.find(int(levels[tier])), 0),
			}
			for key: String in ["globals", "icons"]:
				if row.has(key):
					item[key] = row[key]
			item.make_read_only()
			out[name] = item
	out.make_read_only()
	return out


## The item level a kind's first material unlocks at.
static func first_level(kind: String) -> int:
	return int(KINDS[kind].get("tier_levels", TIER_MIN_LEVEL)[0])


## The plainest piece of the first kind written for `slot`: the picture any base in the slot may
## borrow, and what a roll under its kind's `first_level` is dealt as.
static func _first_of_slot(slot: String) -> String:
	for kind: String in KINDS:
		if KINDS[kind]["slot"] == slot:
			return str(KINDS[kind]["tiers"][0])
	return items()[0]
