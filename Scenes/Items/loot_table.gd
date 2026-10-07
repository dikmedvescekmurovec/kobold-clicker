class_name LootTable
extends RefCounted
## What a dead monster leaves behind, and how often.
##
## The same shape as EnemyRoster: const tables and static accessors, no nodes, so a test can roll
## twenty thousand drops in a loop. And the same philosophy -- the drop chance is not written per
## enemy. TIER_CHANCE and SIZE_CHANCE multiply into `chance_for`, so the whole curve is tuned from
## two small tables rather than by editing thirty numbers. The one table that is not written out is
## ITEMS, and it is built from KINDS for the same reason: seventy-one pieces written by hand are
## seventy-one places for a number to go stale.
##
## A drop is not just a name any more: it rolls a rarity off the enemy that carried it and modifiers
## off ItemRarity's band, and every one is its own Item. What a worn set adds up to is
## `Equipment.totals`; this file is only what the world hands over.

const ROOT := "res://Assets/Gear/"
## What a replaced base icon looked like before (`tools/ui_kit.py`'s `BASE_OLD`), for `Settings.old_icons`.
const OLD_ROOT := ROOT + "Old/"

## Every kind of gear the world holds, and the materials each kind is found in. Path of Exile's
## shape: a slot is not one piece with a level on it but several *kinds* that play differently -- a
## dagger is quick and weak where a greatsword is slow and heavy -- and each kind comes in four
## materials, the better ones only on ground deep enough to roll them.
##
## `tiers` names the pieces, weakest first, and each name is the item: a base has a name of its own
## rather than a number after a shared one. `weight` is the *kind's*, not a tier's, because which
## kind drops is one draw and which of its materials is another (`_weighted`) -- so the weights below
## are shares of a slot, and the slots' own shares of all drops are what they always were.
##
## Three stat lists, and the difference between them is the whole rule.
##
## `stats` is what the piece *is* -- the handful of numbers it shows, and the only stats a PERCENT
## modifier can scale, because "+14% increased Armour" needs armour to increase. `affixes` is what
## the piece can *carry*: stats it does not show and has none of, but can still roll a flat modifier
## for. A helm has no time on hit of its own and still rolls "+1s Time on Hit", which is how Path of Exile has
## always done it, and it is what keeps a stat block two lines long while the modifier pool stays deep.
## `globals` is what the piece can carry a *global* percent for -- a percentage of what the whole set
## is worth rather than of anything the piece has, which is the only way "+14% increased Damage" can
## mean anything on a ring. Only the jewellery has one, so "the jewellery carries the global offence"
## is a property of this table rather than a rule about slots written somewhere else.
##
## `power` is a per-stat factor on top of all that, and it is applied *after* the level has done its
## work (`power_of`, `Item.scaled_stats`). It is written here rather than into `stats` because
## LEVEL_FLAT adds the same damage a level to every weapon alike: a dagger written as
## `damage: 0.6` would be within a tenth of a sword by level 10 and the kinds would level themselves
## out. Three more keys are optional: `two_handed` closes the offhand while the piece is worn,
## `tier_levels` names the levels a kind's materials unlock at where it has fewer than five (the torch,
## and the greaves, which begin at iron), and `tier_stats` is the torch's alone, stating each
## material's Sight outright rather than multiplying a number. `needs` is the attribute a piece of the
## kind asks for past `NEEDS_FROM` (`requirement`); the jewellery asks for none.
##
## Stats span pieces on purpose. Base `damage` lives on the weapons -- a click's damage comes from
## what is held, or that stops being the interesting slot -- while armour and dodge roll nearly
## everywhere, because a stat that adds up across what the player wears is what makes swapping any
## single piece worth doing. Four stay locked by what a piece is: `move_speed` is the boots',
## `block` belongs to a thing you hold, `bleed` is what a mace leaves behind, and `sight` is
## the whole reason to hold a torch. The jewellery is the exception to the weapons' monopoly, and
## carries its offence as modifiers rather than as base stats: a ring is worth something to a fight
## without ever being the thing that swings.
##
## Defence is spent on the fight clock, which is what an enemy's blow takes off (`Encounter.taken`):
## armour takes a share of a hit, block a flat amount after it, dodge now and then all of it, and
## time on hit wins back what the blows took. Health, energy shield, regen, leech and the
## resistances went with the kinds built on them -- the clock is the one pool there is to defend.
##
## None of it depends on rarity: an elite sword hits like a common one and simply carries more on
## top.
const KINDS := {
	# --- Helmet: a half each, and the two ways a head keeps a blow off the clock -- armour, which
	# takes a share of every hit, and dodge, which now and then takes all of one. The head's own lines
	# are the mind's: a later first blow, less from the big ones, weaker land, thinner bodies, a tree's
	# skills a rank higher, and experience.
	"helm": {
		"slot": "helmet", "weight": 18, "needs": "strength",
		"stats": {"armor": 3},
		"affixes": ["time_on_hit", "strength", "intelligence", "xp_more", "blow_delay", "elite_ward",
			"tile_ward", "less_health", "power_skills", "fortune_skills", "guard_skills"],
		"tiers": ["Leather Helmet", "Iron Helmet", "Steel Helm", "Golden Helm", "Masterwork Helm"],
	},
	"hood": {
		"slot": "helmet", "weight": 18, "needs": "dexterity",
		"stats": {"dodge": 3},
		"affixes": ["armor", "dexterity", "intelligence", "xp_more", "blow_delay", "elite_ward",
			"tile_ward", "less_health", "power_skills", "fortune_skills", "guard_skills"],
		"tiers": ["Hide Hood", "Leather Hood", "Studded Hood", "Shadow Hood", "Masterwork Hood"],
	},
	# --- Boots: every one of them keeps Move Speed, because that is what a boot is for.
	"boot": {
		"slot": "boots", "weight": 24, "needs": "dexterity",
		"stats": {"move_speed": 5, "dodge": 2},
		"affixes": ["armor", "dexterity"],
		"tiers": ["Leather Boots", "Studded Boots", "Ranger's Boots", "Shadow Boots", "Masterwork Boots"],
	},
	# No first material: the Bronze Greaves went (the user's call, 2026-09-24), so the boots' tier one is
	# the Leather Boots alone, and a greaves roll under level 3 is dealt as one (`_tier_at`).
	"greaves": {
		"slot": "boots", "weight": 24, "needs": "strength",
		"stats": {"move_speed": 4, "armor": 3},
		"affixes": ["dodge", "strength"],
		"tier_levels": [3, 5, 7, 9],
		"tiers": ["Iron Greaves", "Steel Greaves", "Golden Greaves", "Masterwork Greaves"],
	},
	# --- Weapon: the same base damage on all four, and a factor apiece. On its own swings the dagger,
	# the sword and the greatsword come out about even; the dagger is the idler's weapon and the
	# greatsword the clicker's, since a click deals `damage` and pays for it with the offhand. The mace
	# sits between the sword and the greatsword, idle or clicking, at every level and material -- it
	# carries crit chance for that, because crits are what grow and bleed only takes a point a level.
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
	# The player's first find and nothing else's (FIRST_DROP): weight 0, so no roll ever deals one.
	"broken_sword": {
		"slot": "weapon", "weight": 0, "needs": "strength",
		"stats": {"damage": 1},
		"affixes": ["time_on_hit", "strength",
			"click_damage", "swing_damage", "elite_damage", "first_blow", "double_strike"],
		"tiers": ["Broken Sword"],
	},
	# --- Offhand: the shield is the commonest thing to find in the hand, and the torch the rarest,
	# because Sight is worth more than any number on it. Block lives here and nowhere else: a
	# greatsword gives it up with the hand it closes.
	# The shield's own line is what a blow its block stops whole wins back; the buckler's, the crit a
	# dodge hands the next blow.
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
	# Sight is the whole piece and it has only three values, so the torch has three materials rather
	# than five and names its own unlock levels: the masterwork's is the others', and its third tile is
	# the whole of what it is. Its affixes are all flat: with no base number but Sight,
	# there is nothing on it for a percent modifier to scale. Crit chance sits beside the crit damage
	# it already rolled, and is what makes its pool deep enough for an elite piece. A torch burns what
	# it strikes, and is the map's piece and the intelligence's: move speed, experience and orbs.
	"torch": {
		"slot": "offhand", "weight": 18, "needs": "intelligence",
		"tier_levels": [1, 5, 9],
		"tier_stats": [{"sight": 1}, {"sight": 2}, {"sight": 3}],
		"affixes": ["block", "crit_chance", "crit_damage", "intelligence", "burn", "move_speed",
			"xp_more", "orb_find"],
		"tiers": ["Wooden Torch", "Blazing Torch", "Masterwork Torch"],
	},
	# What a world under the Thick Fog begins with and nothing else hands out (BROKEN_TORCH): weight
	# 0, like the Broken Sword. A Wooden Torch's Sight and nothing more, so holding it buys back what
	# the curse took and costs the hand a shield would have had.
	"broken_torch": {
		"slot": "offhand", "weight": 0, "needs": "intelligence",
		"stats": {"sight": 1},
		"affixes": ["block", "crit_chance", "crit_damage", "intelligence", "burn", "move_speed",
			"xp_more", "orb_find"],
		"tiers": ["Broken Torch"],
	},
	# --- Body: the biggest numbers in the table, and the same two-way split as the head. The body's own
	# lines are the long haul's: a camp's pay, more or fewer bodies a fight, blows struck back, and time
	# a blow took coming back.
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
	# --- Jewellery: one material apiece, the way Path of Exile's is. The kinds are gem and metal
	# pieces rather than a ladder, and all eight carry the global offence.
	#
	# The rings are where a stat of the player's own is a base stat: a ring is worn for what it
	# finds -- gold on the Gold Ring, rarity on the Opal, orbs on the Pearl -- or for a little defence,
	# which the Iron Band and the Jade Ring scale for the whole set (a global on a stat the piece shows
	# takes the place of its own percent: `ModifierTable.pool_for`). What offence a ring carries is all
	# modifiers -- flat damage and crit among the affixes, the increases in `globals` -- so a ring is worth
	# something to a fight without ever being the thing that swings. Every ring may roll every finder but
	# drop rate, which is the amulets', and the elite chance that only a ring carries.
	# Five rings share the three rings' old weight of 24, so the slot drops as often as it always did.
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
	# Item rarity as a base stat, where every other jewel only rolls it: the middle of
	# `added_item_rarity`'s band, the way the Ruby Amulet's crit damage is the middle of its own.
	"opal_ring": {
		"slot": "ring", "weight": 5,
		"stats": {"item_rarity": 15},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"gold_find", "orb_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage"],
		"tiers": ["Opal Ring"],
	},
	# The one piece that shows orb find, which only the Fortune tree gave before; a skill's rank is 10.
	# The middle of `added_orb_find`'s band, which the other rings roll.
	"pearl_ring": {
		"slot": "ring", "weight": 4,
		"stats": {"orb_find": 15},
		"affixes": ["damage", "crit_chance", "crit_damage", "strength", "dexterity", "intelligence",
			"item_rarity", "gold_find", "time_on_hit", "xp_more", "elite_chance"],
		"globals": ["damage", "attack_speed", "crit_chance", "crit_damage"],
		"tiers": ["Pearl Ring"],
	},
	# The catch-all socket, and the rarest: the widest affix pools in the table, so an amulet is the
	# one piece that can turn up carrying almost anything -- all three attributes in one line among them,
	# and the set's bleed and defence among its globals. The Gold Amulet shows drop rate, the broad
	# finder -- it lifts gear, uniques, orbs and gold alike -- and the Emerald crit chance, the middle
	# of `added_crit`'s band.
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
}

## The item level each material is found from, and what one is worth on top of the kind's own
## numbers: half again of every quantity for each step up the materials, so the masterwork is worth
## 3 times the plainest (0.2 until 2026-09-28, when the user made the pieces that ask for an attribute
## -- every one with materials; the jewellery has one -- worth the asking). Both are dials. A kind may name levels of its own (`tier_levels`), as
## the torch and the greaves do. A piece's step (`material`) counts up from the material its kind
## begins at, so the greaves' first piece takes iron's step, not the plainest's.
##
## A material every two levels **of the tile the piece drops on**, never of the piece itself (the
## user's, 2026-09-28): tiles of level 1-2 deal wood alone, 3-4 wood and iron, 5-6 wood, iron and
## steel, and on to the masterwork from 9 (`_tier_at` draws evenly among everything unlocked). A
## masterwork with no art yet wears `tools/ui_kit.py`'s "!" (`MISSING`).
const TIER_MIN_LEVEL := [1, 3, 5, 7, 9]
const TIER_POWER := 0.5
## What wearing a piece asks for (the user's, 2026-09-28): nothing up to item level `NEEDS_FROM`, the
## first circle's ground, because commons carry no lines and a fresh player has no attributes at all;
## past it, its kind's `needs` at about one middling attribute line of its level -- `NEEDS_LINE` is
## the middle of `added_strength`'s level-1 band, grown by `scale` as the line is. Both are dials.
const NEEDS_FROM := 5
const NEEDS_LINE := 5.0
## The player's first piece of gear, whatever the roll said it was: `Encounter.first_sword` swaps it
## in at level 1, keeping the rarity, so it is always 1 Damage and the modifiers that rarity carries.
const FIRST_DROP := "Broken Sword"
## What a transcension under the Thick Fog puts in the new world's bag (`Inventory.transcended`).
const BROKEN_TORCH := "Broken Torch"
## Pieces a save may name under an older name -> the name they carry now: the house spelling is
## British, and a pair of boots is plural like the greaves beside them (2026-09-30).
const RENAMED := {
	"Wooden Armor": "Wooden Armour",
	"Iron Armor": "Iron Armour",
	"Leather Boot": "Leather Boots",
	"Studded Boot": "Studded Boots",
	"Ranger's Boot": "Ranger's Boots",
	"Shadow Boot": "Shadow Boots",
	"Masterwork Boot": "Masterwork Boots",
}


## What a saved piece's name is called now (`RENAMED`); a name that never changed is itself.
static func current(type: String) -> String:
	return RENAMED.get(type, type)

## Every piece a monster can leave, keyed by name: the row every caller has always read -- `icon`,
## `weight`, `slot`, `stats`, `affixes` and the jewellery's `globals` -- plus the `kind` it belongs to
## and which `tier` of that kind it is (its place in the kind's list), and its `material`, the step up
## the materials it is worth (`tier` plus the material the kind begins at), which is what `power_of` reads.
##
## Built from KINDS rather than written out, so a kind's numbers are stated once and the four names it
## is found under cannot drift apart. In the order the kinds are written, which is the order the
## panels list them in -- and within each slot the kind the game shipped with is written first, so
## anything asking for "a plain piece for this socket" still picks up the wooden one.
static var ITEMS := _build_items()

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
	# Offence, which lives on what is held.
	"damage": "Damage",
	"crit_chance": "Crit Chance",
	"crit_damage": "Crit Damage",
	"attack_speed": "Attack Speed",
	# What a blow leaves behind: a share of it that goes on hurting. The mace's, and nothing else's.
	"bleed": "Bleed",
	# The weapon's own lines: more of one kind of blow -- the hand's, the weapon's own swing, one at an
	# elite or a boss, the first an enemy takes -- and a chance a blow lands twice. Each a percentage
	# the fight reads (`Encounter.gear_more`), carried and never shown by a piece.
	"click_damage": "Click Damage",
	"swing_damage": "Swing Damage",
	"elite_damage": "Elite Damage",
	"first_blow": "First Blow Damage",
	"double_strike": "Double Strike",
	# Defence, which rolls nearly everywhere: what keeps an enemy's blow off the fight clock.
	"armor": "Armour",
	"dodge": "Dodge",
	"block": "Block",
	# What a blow of the player's wins back of the clock the enemies took.
	"time_on_hit": "Time on Hit",
	# Seconds a fight's clock starts with on top of its own: the one line any piece may roll against
	# losing a fight rather than against a blow (`Encounter.CLOCK_MOST`).
	"fight_clock": "Fight Clock",
	# Utility.
	"move_speed": "Move Speed",
	"drop_rate": "Drop Rate",
	# How many tiles a charted one takes the fog off, which is the torch's whole reason to be held.
	# Not a percentage: it is a number of tiles, and there are only ever one or two of them.
	"sight": "Sight",
	# The attributes, which fit any piece because they say nothing about what the piece is.
	"strength": "Strength",
	"dexterity": "Dexterity",
	"intelligence": "Intelligence",
	# One line of all three, which `Inventory.attributes` adds to each and nothing else reads.
	"all_attributes": "All Attributes",
	# The other two finders. The Fortune tree carries all three; the jewellery rolls item rarity, the
	# Gold Ring shows gold find, the Opal Ring item rarity and the Pearl Ring orb find.
	"item_rarity": "Item Rarity",
	"gold_find": "Gold Find",
	"orb_find": "Orb Find",
	# How much shorter the next enemy's walk-in is. A percentage of the walk, capped at 100 by
	# `Encounter.arm`: at the cap the next body is simply there.
	"spawn_speed": "Spawn Speed",
	# More experience off every body: the intelligence's, the curses', and a ring's, a helmet's and a
	# torch's line.
	"xp_more": "Experience",
	# How often a common comes on as an elite instead (`Encounter.arm`): more to fight, more to find.
	"elite_chance": "Elite Chance",
	# The helmet's lines (`Encounter.arm`): how much later an enemy's first blow comes, how much less an
	# elite's or a boss's blow takes, how much of a tile modifier's bite is gone, how much less health
	# every body has -- and a rank more on every learned skill of one tree (`Skills.flat`).
	"blow_delay": "Enemy First Blow Delay",
	"elite_ward": "Elite Blow Reduction",
	"tile_ward": "Tile Modifier Reduction",
	"less_health": "Enemy Health Reduction",
	"power_skills": "Power Skill Ranks",
	"fortune_skills": "Fortune Skill Ranks",
	"guard_skills": "Guard Skill Ranks",
	# The body armour's: more gold and experience off a camp (`Camp.make`), bodies more or fewer in a
	# fight, a share of the damage struck back at whatever lands a blow, and a share of what a blow took
	# coming back over a few seconds.
	"camp_earnings": "Camp Earnings",
	"extra_enemies": "Enemies per Fight",
	"thorns": "Thorns",
	"recoup": "Recoup",
	# The offhand's: the crit a dodge hands the next blow (the buckler's), a share of a blow burning on
	# (the torch's), and what a blow the block stops whole wins back (the shield's, in tenths).
	"parry": "Crit after a Dodge",
	"burn": "Burn",
	"time_on_block": "Time on Block",
}
const PERCENT_STATS := ["crit_chance", "crit_damage", "move_speed", "drop_rate", "bleed",
	"item_rarity", "gold_find", "orb_find", "spawn_speed", "click_damage", "swing_damage",
	"elite_damage", "first_blow", "double_strike", "xp_more", "elite_chance", "blow_delay",
	"elite_ward", "tile_ward", "less_health", "camp_earnings", "thorns", "recoup", "parry", "burn"]
## The percentages that are a *probability*: how often something happens, rather than how much of it
## there is. They are the ones a level may not multiply -- see `scale`. Crit damage is not one of
## them (500% crit damage is a fine number).
##
## Drop rate is one of them at one remove: it multiplies a probability, so the exponent would walk
## through the same ceiling it walked through on crit chance -- a level-30 ring would be finding four
## times what a level-1 one does. The flat step still grows it, at a pace a chance can hold.
##
## Gold find is here for drop rate's reason and is no more a probability than it is: it multiplies a
## purse that is already exponential in the walk, and an exponent on top of that is gold meaning nothing.
## Item rarity joins them both: it multiplies the weights a drop rolls its rarity on. Orb find too:
## it multiplies the orb chance the way drop rate does the gear chance.
##
## Bleed is a share of a blow, and a share that compounds is a share past everything: 20% of a hit
## would be 530% of it by level 30. The flat step grows it instead, a point a level.
##
## Sight is the odd one out and is here for the arithmetic rather than for the reasoning. It is a
## number of tiles, its step is zero, and the material of the torch is the only thing that moves it --
## so what this list does for it is keep a level from multiplying one tile into twenty-six.
##
## Spawn speed is a share of the walk-in with a hard cap at the whole of it, so it is a chance's shape.
##
## The fight clock is here for Sight's reason: seconds on a thirty-second clock that a level multiplied
## would delete the only way to lose, so no level moves it at all.
##
## Double strike and elite chance are chances, capped at certainty by `Encounter.arm`. Experience is a
## finder's kind of number: a level's multiplier would make a level-30 line thirty times a level-1 one.
##
## The helmet's, the body's and the offhand's shares are here for bleed's reason -- a share that
## compounded would be past everything -- and the three "less" ones (`Encounter.WARD_MOST`) and the
## recoup are capped besides. Camp earnings is a finder's number on a camp. The count of enemies and a
## tree's ranks are whole steps no level moves.
const CHANCE_STATS := ["crit_chance", "drop_rate", "gold_find", "item_rarity", "orb_find", "bleed",
	"sight", "spawn_speed", "fight_clock", "double_strike", "xp_more", "elite_chance", "blow_delay",
	"elite_ward", "tile_ward", "less_health", "power_skills", "fortune_skills", "guard_skills",
	"camp_earnings", "extra_enemies", "thorns", "recoup", "parry", "burn"]
## The stats any piece at all may roll a FLAT modifier for, without being told so kind by kind.
const ANY_AFFIXES := ["spawn_speed", "fight_clock"]
## Per second: attacks. The one stat that is neither a plain number nor a percentage.
const RATE_STATS := ["attack_speed"]
## Seconds of the fight clock: how much of a blow block takes off, and how much a hit wins back.
## Quantities that grow like armour does -- **kept in tenths of a second**, the one place a stat is not
## stored as the number it shows. A blow near the start is a quarter of a second, and a modifier rolls
## whole numbers (`ModifierTable`), so a stat counted in whole seconds would have made the smallest
## "+1 Block" a wall against every blow in the first band. `seconds_of` is the conversion, and every
## place that writes or reads one goes through it: `stat_value`, `stat_delta`, `ModifierTable.amount`
## and `Encounter.arm`.
const SECONDS_STATS := ["block", "time_on_hit", "fight_clock", "time_on_block"]

## How much one level multiplies every scaled number by. The dial for how fast gear answers the
## frontier; Encounter.HP_GROWTH is the dial for how fast the frontier pulls away.
const LEVEL_GROWTH := 1.12

## What one level *adds*, on top of that multiplier, per stat.
##
## Per stat because an absolute step has to suit the size of the number it is added to: a fraction of
## a point a level is most of the story for damage, which starts at 1, and a rounding error for crit
## damage, which starts at 50. A multiplier alone would leave a sword reading "Damage 1" for four
## levels; a flat step alone would do nothing to the large stats. Both together carry the range.
##
## Damage takes 0.4, so a sword gains a visible point about every two and a half levels. It was a
## whole point, and on a base of 1 that made a level-3 weapon three times a level-1 one while the
## first rings' health had grown a fifth: the first drop off an elite one-shot the commons around the
## start (2026-09-27, the user's ruling: a fresh first-circle weapon should want 3-5 clicks a common).
## The flat-damage modifier the jewellery rolls takes a quarter of it (`added_damage`'s `level_flat`
## in ModifierTable): four sockets roll it, and handing all four the whole step put the far edge
## inside a third of a click a second, which is the frontier stopping being one.
##
## Every key of STAT_LABELS has an entry here and test_inventory holds that, so a new stat cannot be
## added without saying what a level is worth to it.
const LEVEL_FLAT := {
	"damage": 0.4,
	"crit_chance": 1.0, "crit_damage": 5.0, "attack_speed": 0.05, "bleed": 1.0,
	# Armour and dodge are the same kind of number -- a rating set against the size of the hit -- so
	# they grow alike. Block and time on hit are tenths of a second (SECONDS_STATS), a tenth a level.
	"armor": 2.0, "dodge": 2.0, "block": 1.0, "time_on_hit": 1.0,
	"move_speed": 1.0, "drop_rate": 1.0,
	"strength": 1.0, "dexterity": 1.0, "intelligence": 1.0, "all_attributes": 1.0,
	# More of one kind of blow is an increase of damage, so it grows the way a PERCENT modifier does:
	# the level's multiplier and no step. A chance a blow lands twice takes a point a level, as crit does.
	"click_damage": 0.0, "swing_damage": 0.0, "elite_damage": 0.0, "first_blow": 0.0,
	"double_strike": 1.0,
	# Experience takes the finders' point a level; elite chance takes none, for spawn speed's reason
	# below: it is reached by wearing it, not by levelling.
	"xp_more": 1.0, "elite_chance": 0.0,
	# The helmet's, the body's and the offhand's shares take a point a level, as bleed does; what a
	# blocked blow wins back takes time on hit's tenth. A count of bodies and a tree's ranks take nothing:
	# they are whole steps, and the count's band is its own (`ModifierTable`'s `signed`).
	"blow_delay": 1.0, "elite_ward": 1.0, "tile_ward": 1.0, "less_health": 1.0,
	"camp_earnings": 1.0, "thorns": 1.0, "recoup": 1.0, "parry": 1.0, "burn": 1.0, "time_on_block": 1.0,
	"extra_enemies": 0.0, "power_skills": 0.0, "fortune_skills": 0.0, "guard_skills": 0.0,
	# The other finders. They take the same point a level drop rate does, which is all a CHANCE_STAT
	# ever takes.
	"item_rarity": 1.0, "gold_find": 1.0, "orb_find": 1.0,
	# And the one a level is worth nothing to: a torch's Sight is one tile or two and the material is
	# what says which.
	"sight": 0.0,
	# Spawn speed reaches its cap by being worn on every socket, not by levelling: a level is worth
	# nothing to it, so the cap is a set's worth of rolls at any level.
	"spawn_speed": 0.0,
	# And the fight clock, whose band is the same at every level (`CHANCE_STATS`).
	"fight_clock": 0.0,
}

## What a body's tier adds to the ceiling on what it drops, over the tile's own level. The elite at
## the end of a fight can hand over something the rabble on the same tile never could.
const TIER_LEVEL := {
	EnemyRoster.Tier.COMMON: 0,
	EnemyRoster.Tier.ELITE: 2,
	EnemyRoster.Tier.BOSS: 3,
}
## How often a common body's drop comes out a level past its tile anyway (the user's "rarely",
## 2026-10-03): the rabble's one way over its ceiling.
const COMMON_REACH := 0.1

## Icons are loaded once and kept, the way UITheme keeps its Theme: the panel rebuilds every square
## whenever something drops, and reloading four textures each time would be work for nothing. Kept by
## path, not by item, so the old-icons tick shows from the next time a square is drawn.
static var _icons := {}


## Every item, in the order written above, which is also the order the inventory panel lists them in.
static func items() -> PackedStringArray:
	var all := PackedStringArray()
	for item: String in ITEMS:
		all.append(item)
	return all


## Where this piece's picture lives. While a base has no drawing of its own yet it borrows one --
## first from the plainest of its kind, then from the first kind written for its slot, which is one of
## the eight the game shipped with. The same fallback `UniqueTable.icon` has, and for the same reason:
## a base is playable the day the table names it, and the art follows when it is approved. Under
## `Settings.show_old_icons()` the picture it had before, where it had another.
static func icon_path(item: String) -> String:
	var row: Dictionary = ITEMS[item]
	if Settings.show_old_icons() and ResourceLoader.exists(OLD_ROOT + str(row["icon"])):
		return OLD_ROOT + str(row["icon"])
	var kind: Dictionary = KINDS[row["kind"]]
	var tiers: Array = kind["tiers"]
	for name: String in [item, str(tiers[0]), _first_of_slot(str(row["slot"]))]:
		var path: String = ROOT + str(ITEMS[name]["icon"])
		if ResourceLoader.exists(path):
			return path
	return ROOT + str(row["icon"])


static func icon(item: String) -> Texture2D:
	var path := icon_path(item)
	if not _icons.has(path):
		_icons[path] = load(path)
	return _icons[path]


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


## Which of `KINDS` the piece is.
static func kind_of(item: String) -> String:
	return ITEMS[item]["kind"]


## How much of `stat` this piece is worth for being the kind and the material it is: the kind's own
## factor -- a dagger's 0.6 of a sword's damage -- times `TIER_POWER` more for every material above
## the plainest.
##
## Applied by `Item.scaled_stats` after `scale` and nowhere else, which is what lets the smith's
## upgrade follow it for nothing. *After*, because LEVEL_FLAT adds the same damage a level to
## every weapon alike: a dagger written weaker in the table would be a sword again by level 10.
##
## The material's share skips the chances and the rates -- a steel shield holds more armour than a
## wooden one and blocks exactly as often, which is the ceiling `scale` already refuses to walk
## through. The kind's own factor does not, because no kind names one for a chance.
static func power_of(item: String, stat: String) -> float:
	var row: Dictionary = ITEMS[item]
	var kind: Dictionary = KINDS[row["kind"]]
	var power: Dictionary = kind.get("power", {})
	var factor := float(power.get(stat, 1.0))
	if stat in CHANCE_STATS or stat in RATE_STATS:
		return factor
	return factor * (1.0 + TIER_POWER * int(row["material"]))


## Whether this piece takes both hands, and so leaves no offhand while it is worn. A property of the
## kind rather than of the slot: every greatsword is two-handed and nothing else in the table is.
static func two_handed(item: String) -> bool:
	var kind: Dictionary = KINDS[ITEMS[item]["kind"]]
	return bool(kind.get("two_handed", false))


## What a piece of `item` at `level` asks of the player before it goes on: [attribute, points], or
## [] for nothing. A unique asks what its base does. `Inventory.why_not_equip` is the gate.
static func requirement(item: String, level: int) -> Array:
	var attribute: String = KINDS[ITEMS[item]["kind"]].get("needs", "")
	if attribute.is_empty() or level <= NEEDS_FROM:
		return []
	return [attribute, roundi(scale(attribute, NEEDS_LINE, level))]


## The stats this piece can roll a flat modifier for without having any of its own.
static func affixes_of(item: String) -> Array:
	return ITEMS[item]["affixes"]


## Whether this piece can carry this stat at all, as a base stat or as an affix. The gate on a FLAT
## modifier, where `has_stat` is the gate on a PERCENT one.
static func can_roll(item: String, stat: String) -> bool:
	return has_stat(item, stat) or (ITEMS.has(item) and (stat in ITEMS[item]["affixes"] or stat in ANY_AFFIXES))


## The stats this piece can roll a *global* percent for -- a percentage of what the whole set is
## worth rather than of anything the piece has. Most pieces have none, so the key is optional and a
## missing one is an empty list rather than a crash.
static func globals_of(item: String) -> Array:
	return ITEMS[item].get("globals", []) if ITEMS.has(item) else []


## The gate on a GLOBAL modifier. Deliberately nothing to do with `has_stat` or `can_roll`: a global
## scales the player rather than the piece, so a ring needs no damage of its own to increase damage.
static func can_globalize(item: String, stat: String) -> bool:
	return stat in globals_of(item)


## What `value` of `stat` is worth at `level`. The one place that knows what a level does to a
## number, so a piece's base stats and a modifier's band grow the same way and cannot drift apart.
## Level 1 is the number as written, so a level-1 piece is exactly the piece the table describes.
##
## A CHANCE_STAT takes the flat step alone. A probability has a ceiling that a quantity has not, and
## the exponent walked straight through it: a plain set of commons reached 163% crit chance by level
## 30, which is every hit critting and a stat block that reads as nonsense. The flat step still grows
## it -- a point of crit chance a level -- but at a pace the ceiling can hold.
## `flat` is what one level adds, and defaults to the stat's own step. A modifier band sized for a
## piece other than the one the step was sized for passes its own -- see ModifierTable's
## `level_flat`, which is the only caller that does.
static func scale(stat: String, value: float, level: int, flat := NAN) -> float:
	var steps := maxi(level - 1, 0)
	var grown := value if stat in CHANCE_STATS else value * pow(LEVEL_GROWTH, steps)
	var step := float(LEVEL_FLAT.get(stat, 0.0)) if is_nan(flat) else flat
	return grown + step * steps


## A stat written for a person: "5 Damage", "5% Crit Chance", "1.0/s Attack Speed". The number leads
## on every line an item writes -- a modifier's always did -- so `ItemDetails` can stand them all in
## one column.
static func stat_line(stat: String, value: float) -> String:
	return "%s %s" % [stat_value(stat, value), STAT_LABELS.get(stat, stat)]


## The number alone, for a table that puts the name in a column of its own: "5", "5%", "1.0/s".
static func stat_value(stat: String, value: float) -> String:
	if stat in PERCENT_STATS:
		return BigNumber.format(value) + "%"
	if stat in RATE_STATS:
		return "%.1f/s" % value
	# A quantity, which grows with the walk: written through the one formatter, so a late stat is
	# "1.23M" rather than twenty digits across a panel (`BigNumber`).
	if stat in SECONDS_STATS:
		return seconds_text(value)
	return BigNumber.format(value)


## The same stat as a difference: "+13 Damage", "-2% Crit Chance", "+0.3/s Attack Speed".
##
## Here rather than at the panel that shows it, for the reason `stat_line` is: this file is the one
## place a stat is spelled, and a second spelling of "Attack Speed" is a second thing to keep in step.
## The sign is always written, including on a gain -- "13 Damage" and "+13 Damage" are two different
## claims, and only one of them is what a comparison means.
static func stat_delta(stat: String, delta: float) -> String:
	var label: String = STAT_LABELS.get(stat, stat)
	if stat in PERCENT_STATS:
		return "%s%% %s" % [BigNumber.format(delta, true), label]
	if stat in RATE_STATS:
		return "%+.1f/s %s" % [delta, label]
	# `signed` is what keeps the sign on a gain, which is the whole of what a delta line means.
	if stat in SECONDS_STATS:
		return "%s %s" % [seconds_text(delta, true), label]
	return "%s %s" % [BigNumber.format(delta, true), label]


## What a SECONDS_STAT's stored tenths are worth in seconds of the clock.
static func seconds_of(stat: String, value: float) -> float:
	return value / 10.0 if stat in SECONDS_STATS else value


## Tenths of a second written as seconds: "0.3s", "+1.2s", and "1.23Ms" once it is past the point
## where a tenth means anything.
static func seconds_text(tenths: float, signed := false) -> String:
	var seconds := tenths / 10.0
	if absf(seconds) >= 100.0:
		return BigNumber.format(seconds, signed) + "s"
	return ("%+.1fs" if signed else "%.1fs") % seconds


## Whether a difference is worth saying at all. A delta that rounds to nothing on the line would read
## as "+0 Armour", which says a stat changed and then says it did not -- so the two pieces are
## compared as the numbers the player can actually see, not as the floats behind them.
static func delta_shows(stat: String, delta: float) -> bool:
	if stat in RATE_STATS:
		return absf(delta) >= 0.05
	# Rounded as a float rather than through `roundi`, which is what the line is written with: a
	# difference past int64 would come back out of an int as anything at all.
	return roundf(delta) != 0.0


## How often this enemy leaves anything at all: its tier times its body, lifted by whatever drop rate
## the player is wearing, and never more than certain. Unlike a quantity, a chance has a ceiling.
##
## `drop_rate` is a percentage the way every stat in PERCENT_STATS is, so 50 is half again as much
## gear. It does it here rather than at the caller so there is one answer to "how often does this body drop".
static func chance_for(enemy_name: String, drop_rate := 0.0) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	# Down to nothing and no further: Lean Pickings hands in a lift under zero (`Encounter._gear_rate`).
	return minf(tier * size * (1.0 + maxf(drop_rate, -100.0) / 100.0), 1.0)


## One kill's worth of loot: null for nothing, or the item that dropped, rarity and modifiers and
## all. `rng` belongs to the caller, the way EnemyRoster.pick's does, so what is deterministic is the
## caller's business. `guaranteed` skips the chance and drops something whatever the roll -- the one
## promised elite drop goes through here too, so there is no second idea of what a drop looks like,
## and it rolls its rarity off the elite row like anything else: the promise is about getting
## something, not about what.
##
## The chance is drawn first and on its own, so a kill that leaves nothing still costs exactly one
## draw. That is what keeps the drop rate comparable to before rarities existed.
##
## `forced` is a rarity to roll the piece at instead of drawing one (the dev's even loot, `Encounter`).
static func roll(enemy_name: String, rng: RandomNumberGenerator, guaranteed := false,
		tile_level := 1, drop_rate := 0.0, item_rarity := 0.0, forced := -1) -> Item:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, drop_rate):
		return null
	var tier := EnemyRoster.tier_of(enemy_name)
	var rarity := ItemRarity.roll(tier, rng, item_rarity) if forced < 0 else forced as ItemRarity.Rarity
	var level := drop_level(tier, tile_level, rarity, rng)
	# What it is made of is the tile's alone.
	return Item.rolled(_weighted(rng, tile_level), rarity, rng, level)


## The level a body's drop comes out at. The tile's level and the body's tier give a ceiling and the
## piece rolls its own level under it, rarity lifting the floor, so a deep tile is a better place to
## fight rather than a guaranteed prize -- except that `COMMON_REACH` of a common body's drops are a
## level past its tile outright. `UniqueTable.roll` asks it too.
static func drop_level(tier: EnemyRoster.Tier, tile_level: int, rarity: ItemRarity.Rarity,
		rng: RandomNumberGenerator) -> int:
	if tier == EnemyRoster.Tier.COMMON and rng.randf() < COMMON_REACH:
		return maxi(1, tile_level + 1)
	return ItemRarity.roll_level(rarity, maxi(1, tile_level + int(TIER_LEVEL[tier])), rng)


## A piece picked by weight: which kind, and then which of its materials. Integer weights, so walking
## the table cannot drift.
##
## `level` is the tile's, not the piece's own: a poor roll on deep ground is a low piece of a good
## material.
static func _weighted(rng: RandomNumberGenerator, level := 1) -> String:
	return _tier_at(roll_kind(rng), level, rng)


## One kind by weight, and nothing more: what a bounty's card promises, the material being drawn
## only when the piece is handed over. Integer weights, so walking the table cannot drift.
static func roll_kind(rng: RandomNumberGenerator) -> String:
	var total := 0
	for kind: String in KINDS:
		total += int(KINDS[kind]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for kind: String in KINDS:
		pick -= int(KINDS[kind]["weight"])
		if pick < 0:
			return kind
	return KINDS.keys()[0]


## One of a kind's materials: an even draw among every one `level` has unlocked, the plainest
## included (the user's, 2026-09-28) -- and while only one is unlocked there is no draw at all, which
## is what keeps the shallow game costing exactly the rolls it always did. A kind whose first
## material `level` has not reached (the greaves, which begin at iron) is dealt as its slot's
## plainest piece, so the slot drops as often as ever and never a material under the piece's level.
## `draws` is how many draws the material is the best of: a cleared board's high piece is lucky.
static func _tier_at(kind: String, level: int, rng: RandomNumberGenerator, draws := 1) -> String:
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


## Every kind's materials written out as the rows the rest of the game reads. A tier's own `stats`
## are its kind's, unless the kind states them per material (`tier_stats`, the torch's alone).
##
## Read-only on the way out, the way the const table it replaced was: a piece already in the bag
## carries its own numbers, and a caller that could write into these would be retuning gear the
## player is holding.
static func _build_items() -> Dictionary:
	var out := {}
	for kind: String in KINDS:
		var row: Dictionary = KINDS[kind]
		var tiers: Array = row["tiers"]
		var first := first_material(kind)
		for tier in tiers.size():
			var name := str(tiers[tier])
			var item := {
				"icon": name + ".png", "weight": int(row["weight"]), "slot": row["slot"],
				"stats": row["tier_stats"][tier] if row.has("tier_stats") else row["stats"],
				"affixes": row["affixes"], "kind": kind, "tier": tier, "material": first + tier,
			}
			if row.has("globals"):
				item["globals"] = row["globals"]
			item.make_read_only()
			out[name] = item
	out.make_read_only()
	return out


## Which material a kind begins at, counted from the plainest: 0 for most, 1 for the greaves.
static func first_material(kind: String) -> int:
	return maxi(TIER_MIN_LEVEL.find(int(KINDS[kind].get("tier_levels", TIER_MIN_LEVEL)[0])), 0)


## The item level a kind's first material unlocks at.
static func first_level(kind: String) -> int:
	return int(KINDS[kind].get("tier_levels", TIER_MIN_LEVEL)[0])


## The plainest piece of the first kind written for this slot -- the picture every base in the slot
## can borrow, because each of the eight the game shipped with is the first of its own.
static func _first_of_slot(slot: String) -> String:
	for kind: String in KINDS:
		if KINDS[kind]["slot"] == slot:
			return str(KINDS[kind]["tiers"][0])
	return items()[0]
