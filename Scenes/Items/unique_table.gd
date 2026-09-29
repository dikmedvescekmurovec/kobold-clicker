class_name UniqueTable
extends RefCounted
## The unique items: what each one is, the rule it changes, and where it is found.
##
## The same shape as OrbTable and LootTable -- a const table and static accessors, no nodes and no
## state. A unique is hand-written where every other piece is rolled: its base piece, its modifiers and
## its effect are all in its row, so every Metronome carries the same lines. Only the *values* of those
## modifiers roll, inside the band any modifier rolls in at the piece's level, which is what leaves an
## Orb of Divine something to do and makes a well-rolled one a second thing to hunt.
##
## A unique is worn in an ordinary socket and is meant to lose to a crafted elite on raw numbers: two
## or three modifiers against five or six. What it is worn for is its `effect`, which changes how a
## fight plays rather than a number -- `Encounter` reads it, exactly as it reads a capstone skill's.
##
## They never come out of `ItemRarity.roll`: UNIQUE stays weighted zero in every row there. They are
## rolled here, beside the gear and on a generator of their own, the way orbs are, so the rate can be
## tuned without moving anything else.

const ROOT := "res://Assets/Gear/Unique/"
## What a replaced icon looked like before (`tools/ui_kit.py`'s `UNIQUE_OLD`), for `Settings.old_icons`.
const OLD_ROOT := ROOT + "Old/"

## Lifetime kills before any unique can fall. After that it is chance alone: nothing is promised.
const FIRST_UNIQUE_KILLS := 100

## How often a body is carrying one, by what it was, before its size and the player's drop rate: any
## monster can, and the rabble almost never does. One common in two thousand, one elite in a hundred,
## one boss in ten.
const TIER_CHANCE := {
	EnemyRoster.Tier.COMMON: 0.0005,
	EnemyRoster.Tier.ELITE: 0.01,
	EnemyRoster.Tier.BOSS: 0.10,
}

## What every unique in the collection log adds to the player's damage, in percent, worn or not
## (`Inventory.collection_bonus`).
const COLLECTION_DAMAGE := 1

## The most modifiers a row may carry, which a test holds: a unique is not an elite with a rule on top.
const MOST_MODS := 3

## id -> its name, the `LootTable.ITEMS` piece it is (slot, base stats, level scaling), the modifiers
## it always carries, and its effect and the sentence that says so. `effect` is what `Encounter` reads;
## a home piece's also names the ground its damage counts on, and reaches the fight as "home:<env>".
## Every unique is carried anywhere, once unlocked (`Achievements.unlocked`).
##
## A unique an achievement unlocks has **ranks** (`Achievements`): `ranks` is its numbers, a dial ->
## [I, II, III, IV], and `effect_text` writes them through `{dial}` -- or is four sentences, one a
## rank, where rank I reads differently ("a second" against "2 seconds"). `dial` is how the fight and
## the inventory read a number, so a card and the rule it describes are one figure. The starters have
## no ranks: their rules are fixed.
const UNIQUES := {
	# --- The starters (`Achievements.STARTERS`): in the pool from the first unique on, one a socket with
	# Snowball and the Magpie's Band. Each is plainly good early and runs out -- a flat number, a floor, a
	# level, one save a fight -- so none of them is still worn at the frontier.
	"squires_blade": {
		"name": "Squire's Blade", "base": "Wooden Sword",
		"mods": ["increased_damage", "increased_attack_speed"],
		"effect": "squire",
		"effect_text": "Every blow deals 3 more damage.",
	},
	# A stat stick with no rule of its own: three attributes on one piece is the whole of it.
	"wayfarers_torch": {
		"name": "Wayfarer's Torch", "base": "Wooden Torch",
		"mods": ["added_strength", "added_dexterity", "added_intelligence"],
		"effect": "",
		"effect_text": "",
	},
	"novices_cap": {
		"name": "Novice's Cap", "base": "Leather Helmet",
		"mods": ["added_intelligence", "increased_armor"],
		"effect": "novice",
		"effect_text": "Double experience while you are under level 20.",
	},
	"couriers_boots": {
		"name": "Courier's Boots", "base": "Leather Boot",
		"mods": ["increased_move_speed", "added_spawn_speed", "added_dodge"],
		"effect": "courier",
		"effect_text": "Enemies walk in 30% sooner.",
	},
	"beginners_luck": {
		"name": "Beginner's Luck", "base": "Jade Ring",
		"mods": ["added_crit_damage", "added_damage"],
		"effect": "beginners_luck",
		"effect_text": "Your critical strike chance is 25%.",
	},
	"worry_stone": {
		"name": "Worry Stone", "base": "Emerald Amulet",
		"mods": ["added_damage", "added_time_on_hit"],
		"effect": "worry_stone",
		"effect_text": "Once a fight, running out of time gives back 5 seconds.",
	},
	"metronome": {
		"name": "Metronome", "base": "Wooden Sword",
		"mods": ["increased_attack_speed", "increased_damage", "added_damage"],
		"effect": "metronome",
		"effect_text": "Your weapon's own swings deal {times} times damage. Your clicks deal none.",
		"ranks": {"times": [3, 3.5, 4, 5]},
		"peak": "A swing that kills starts the next swing at once.",
	},
	"headsman": {
		"name": "Headsman", "base": "Wooden Sword",
		"mods": ["increased_damage", "increased_crit_damage", "added_crit_damage"],
		"effect": "headsman",
		"effect_text": "A blow that leaves an enemy under {share}% health kills it. Adds to Execute.",
		"ranks": {"share": [25, 30, 35, 45]},
		"peak": "An execution's leftover damage carries to the next enemy.",
	},
	"knucklebone_ring": {
		"name": "Knucklebone Ring", "base": "Jade Ring",
		"mods": ["added_damage", "added_crit"],
		"effect": "knucklebone",
		"effect_text": "Each click within a second of the last adds {step}% to your clicks, up to {most}%.",
		"ranks": {"step": [2, 3, 4, 5], "most": [50, 100, 150, 250]},
		"peak": "At the full bonus, your weapon's swings get it too.",
	},
	"the_tithe": {
		"name": "The Tithe", "base": "Gold Ring",
		"mods": ["added_gold_find", "global_increased_damage"],
		"effect": "tithe",
		"effect_text": "Enemies drop no ordinary gear. Their purses are {times} times as full.",
		"ranks": {"times": [3, 5, 8, 15]},
		"peak": "Elites and bosses still drop ordinary gear.",
	},
	"hourglass_amulet": {
		"name": "Hourglass Amulet", "base": "Ruby Amulet",
		"mods": ["global_increased_attack_speed", "added_crit"],
		"effect": "hourglass",
		"effect_text": ["Each kill but a boss puts a second back on the clock, never past its start.",
				"Each kill but a boss puts {seconds} seconds back on the clock, never past its start.",
				"Each kill but a boss puts {seconds} seconds back on the clock, never past its start.",
				"Each kill but a boss puts {seconds} seconds back on the clock, never past its start."],
		"ranks": {"seconds": [1, 1.5, 2, 3]},
		"peak": "A boss kill puts 5 seconds back, never past the clock's start.",
	},
	# The home pieces: each is found anywhere, and its damage counts on its own ground alone.
	"meadowstriders": {
		"name": "Meadowstriders", "base": "Leather Boot",
		"mods": ["increased_move_speed", "added_drop_rate"],
		"effect": "home", "home": "grass",
		"effect_text": "Deals {times} times the damage on grass.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Fights on grass give double experience.",
	},
	"hunters_lantern": {
		"name": "Hunter's Lantern", "base": "Wooden Torch",
		"mods": ["added_crit_damage", "added_crit"],
		"effect": "home", "home": "forest",
		"effect_text": "Deals {times} times the damage in forest.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Elites in forest always drop a piece of gear.",
	},
	"sunscorched_cowl": {
		"name": "Sunscorched Cowl", "base": "Leather Helmet",
		"mods": ["added_crit", "increased_armor"],
		"effect": "home", "home": "desert",
		"effect_text": "Deals {times} times the damage in desert.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Purses in desert are twice as full.",
	},
	"rimeplate": {
		"name": "Rimeplate", "base": "Wooden Armor",
		"mods": ["added_damage", "increased_armor"],
		"effect": "home", "home": "ice",
		"effect_text": "Deals {times} times the damage on ice.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "The clock on ice runs at half speed.",
	},
	"stonebreaker": {
		"name": "Stonebreaker", "base": "Wooden Sword",
		"mods": ["added_damage", "increased_crit_damage"],
		"effect": "home", "home": "mountains",
		"effect_text": "Deals {times} times the damage in mountains.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Bosses in mountains roll their unique chance twice.",
	},
	"gravediggers_charm": {
		"name": "Gravedigger's Charm", "base": "Ruby Amulet",
		"mods": ["global_increased_damage", "added_crit_damage"],
		"effect": "home", "home": "dirt",
		"effect_text": "Deals {times} times the damage on dirt.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Orbs drop twice as often on dirt.",
	},
	# --- Trade-offs ---
	"berserkers_band": {
		"name": "Berserker's Band", "base": "Iron Band",
		"mods": ["added_damage", "added_crit_damage"],
		"effect": "berserk",
		"effect_text": "Your clicks deal {times} times damage. Your weapon never swings on its own.",
		"ranks": {"times": [3, 3.5, 4, 5]},
		"peak": "Every tenth click strikes twice.",
	},
	"glass_edge": {
		"name": "Glass Edge", "base": "Wooden Sword",
		"mods": ["increased_damage", "increased_crit"],
		"effect": "glass_edge",
		"effect_text": "Deals {times} times the damage against the clock, which runs a third faster.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Its damage works in farm runs too.",
	},
	"gamblers_die": {
		"name": "Gambler's Die", "base": "Emerald Amulet",
		"mods": ["added_crit", "added_drop_rate"],
		"effect": "gamble",
		"effect_text": "Every blow deals anywhere from almost nothing to {top} times its worth.",
		"ranks": {"top": [3, 3.5, 4, 5]},
		"peak": "Your first blow against every enemy rolls twice and keeps the better.",
	},
	"ascetics_cord": {
		"name": "Ascetic's Cord", "base": "Ruby Amulet",
		"mods": ["global_increased_damage"],
		"effect": "ascetic",
		"effect_text": "{more}% more damage for every place on you that is bare.",
		"ranks": {"more": [15, 20, 25, 35]},
		"peak": "Each bare place also gives 5% dodge.",
	},
	# --- The clock ---
	"last_gasp": {
		"name": "Last Gasp", "base": "Leather Helmet",
		"mods": ["added_crit", "increased_armor"],
		"effect": "last_gasp",
		"effect_text": "Triple damage while {seconds} seconds or fewer remain.",
		"ranks": {"seconds": [5, 6, 8, 10]},
		"peak": "In the last seconds, enemies' blows take nothing from the clock.",
	},
	# --- Crits and the lineup ---
	"duelists_buckler": {
		"name": "Duelist's Buckler", "base": "Wooden Shield",
		"mods": ["added_crit_damage", "increased_block"],
		"effect": "opening_strike",
		"effect_text": ["Your first blow against every enemy is a critical strike.",
				"Your first {blows} blows against every enemy are critical strikes.",
				"Your first {blows} blows against every enemy are critical strikes.",
				"Your first {blows} blows against every enemy are critical strikes."],
		"ranks": {"blows": [1, 2, 3, 4]},
		"peak": "The opening blows against an elite or boss deal double critical damage.",
	},
	"overflowing_chalice": {
		"name": "Overflowing Chalice", "base": "Wooden Torch",
		"mods": ["added_crit", "added_crit_damage"],
		"effect": "overcrit",
		"effect_text": "Each point of critical chance past the most you can have becomes {times} points of critical damage.",
		"ranks": {"times": [2, 3, 4, 6]},
		"peak": "One crit in ten strikes twice.",
	},
	# The crit that never stays away: a miss builds the chance, a crit spends it. One on each doll
	# builds twice as fast (the user's ruling, 2026-09-24).
	"serpents_eye": {
		"name": "Serpent's Eye", "base": "Emerald Amulet",
		"mods": ["added_crit_damage", "global_increased_attack_speed"],
		"effect": "serpent",
		"effect_text": "Every blow that does not crit adds {step}% to your crit chance until one does.",
		"ranks": {"step": [5, 7, 10, 15]},
		"peak": "A crit keeps half the chance built up instead of losing it all.",
	},
	# What a one-blow kill had left over goes on into the next body, and a body it fells passes its own
	# leftover on in turn (the user's, 2026-09-29) -- never into an elite or a boss.
	"dominoes": {
		"name": "Dominoes", "base": "Leather Boot",
		"mods": ["added_damage", "increased_move_speed"],
		"effect": "domino",
		"effect_text": "An enemy felled in one blow carries {share}% of the damage left over into the next, and on through any it fells. Never into an elite or a boss.",
		"ranks": {"share": [20, 30, 40, 50]},
		"peak": "The carry-over reaches elites and bosses too, at half.",
	},
	"snowball": {
		"name": "Snowball", "base": "Wooden Armor",
		"mods": ["increased_armor", "added_damage"],
		"effect": "momentum",
		"effect_text": "2% more damage for every kill this fight, up to double.",
	},
	"packmule": {
		"name": "Packmule's Harness", "base": "Wooden Armor",
		"mods": ["increased_armor", "added_drop_rate"],
		"effect": "packmule",
		"effect_text": "{more}% more damage for every piece in your bag.",
		"ranks": {"more": [1, 1.5, 2, 3]},
		"peak": "Your bag holds 20 more pieces.",
	},
	# --- Defence given a second job, on top of keeping blows off the clock ---
	"bulwark": {
		"name": "Bulwark", "base": "Wooden Shield",
		"mods": ["increased_block", "added_block"],
		"effect": "riposte",
		"effect_text": "A blow your block stops entirely is answered at once with a swing of your own, at {share}% damage.",
		"ranks": {"share": [100, 150, 200, 300]},
		"peak": "The answering swing is always a critical strike.",
	},
	"heartwood_plate": {
		"name": "Heartwood Plate", "base": "Wooden Armor",
		"mods": ["increased_armor", "added_armor"],
		"effect": "heartwood",
		"effect_text": "Every fifty armour you have is a second more on the clock, up to {most}.",
		"ranks": {"most": [10, 15, 20, 25]},
		"peak": "The first blow of every enemy is blocked entirely.",
	},
	"spiked_helm": {
		"name": "Spiked Helm", "base": "Leather Helmet",
		"mods": ["increased_armor", "added_armor"],
		"effect": "spikes",
		"effect_text": "{share}% of your armour is added to your damage.",
		"ranks": {"share": [1, 2, 4, 10]},
		"peak": "A blow you dodge or block sends a tenth of your armour back as damage.",
	},
	# --- Loot ---
	"magpies_band": {
		"name": "Magpie's Band", "base": "Opal Ring",
		"mods": ["added_drop_rate", "added_gold_find"],
		"effect": "magpie",
		"effect_text": "One purse in twenty is a piece of gear instead.",
	},
	"lucky_wound": {
		"name": "Lucky Wound", "base": "Wooden Torch",
		"mods": ["added_crit", "added_drop_rate"],
		"effect": "lucky_wound",
		"effect_text": "An enemy killed by a critical strike rolls its drop {rolls} times and keeps the best.",
		"ranks": {"rolls": [2, 3, 4, 5]},
		"peak": "A crit kill rolls its unique chance twice as well.",
	},
	"rag_and_bone_sack": {
		"name": "Rag and Bone Sack", "base": "Wooden Armor",
		"mods": ["added_gold_find", "increased_armor"],
		"effect": "salvage",
		"effect_text": "Gear you throw away pays {share}% of what a trader would give.",
		"ranks": {"share": [20, 30, 40, 50]},
		"peak": "One piece in twenty thrown away leaves an orb.",
	},
	# --- The attributes, made worth building for: every point is counted over both dolls
	# (`Inventory.attributes`), and the Crown, the Brand and the Echo change what every other one reads.
	"ogres_knuckle": {
		"name": "Ogre's Knuckle", "base": "Iron Band",
		"mods": ["added_strength", "added_damage"],
		"effect": "ogre",
		"effect_text": "{share}% of your strength is added to your damage.",
		"ranks": {"share": [10, 20, 33, 50]},
		"peak": "Every hundred strength is 1% Execute, up to 25%.",
	},
	"fencers_signet": {
		"name": "Fencer's Signet", "base": "Jade Ring",
		"mods": ["added_dexterity", "added_time_on_hit"],
		"effect": "fencer",
		"effect_text": "Every {dexterity} dexterity is a tenth of a second of Time on Hit.",
		"ranks": {"dexterity": [10, 6, 4, 2]},
		"peak": "Your dexterity is added to your dodge.",
	},
	"scholars_circlet": {
		"name": "Scholar's Circlet", "base": "Leather Helmet",
		"mods": ["added_intelligence", "increased_armor"],
		"effect": "scholar",
		"effect_text": "Your intelligence gives damage instead of experience, at {times} times the rate.",
		"ranks": {"times": [5, 6, 8, 10]},
		"peak": "Every ten intelligence is 1% critical damage.",
	},
	"sages_abacus": {
		"name": "Sage's Abacus", "base": "Gold Amulet",
		"mods": ["added_intelligence", "added_crit"],
		"effect": "abacus",
		"effect_text": "Your skills are 1% stronger for every {intelligence} intelligence.",
		"ranks": {"intelligence": [5, 4, 3, 2]},
		"peak": "Every skill you have learned counts one rank higher.",
	},
	"crown_of_accord": {
		"name": "Crown of Accord", "base": "Hide Hood",
		"mods": ["added_strength", "added_dexterity", "added_intelligence"],
		"effect": "accord",
		"effect_text": "While your three attributes are within a tenth of each other, each counts {times} times over.",
		"ranks": {"times": [5, 6, 8, 10]},
		"peak": "Your attributes may differ by a fifth instead of a tenth.",
	},
	# The lower two brought up to the highest, and past it with rank (the user's, 2026-09-29): it was the
	# highest four times over and the other two nothing.
	"zealots_brand": {
		"name": "Zealot's Brand", "base": "Ruby Amulet",
		"mods": ["global_increased_damage", "added_crit_damage"],
		"effect": "zealot",
		"effect_text": ["Your two lower attributes count as much as your highest.",
				"Your two lower attributes count {times} times your highest.",
				"Your two lower attributes count {times} times your highest.",
				"Your two lower attributes count {times} times your highest."],
		"ranks": {"times": [1, 2, 3, 4]},
		"peak": "What each attribute gives counts a quarter more.",
	},
	"patchwork_coat": {
		"name": "Patchwork Coat", "base": "Hide Jerkin",
		"mods": ["added_strength", "added_dexterity", "added_intelligence"],
		"effect": "patchwork",
		"effect_text": "{more}% more damage for every attribute line you wear.",
		"ranks": {"more": [2, 4, 6, 8]},
		"peak": "You may wear any piece, whatever attribute it needs.",
	},
	"purists_seal": {
		"name": "Purist's Seal", "base": "Pearl Ring",
		"mods": ["added_damage", "global_increased_damage"],
		"effect": "purist",
		"effect_text": "{more}% more damage for every piece you wear without an attribute line.",
		"ranks": {"more": [10, 15, 20, 30]},
		"peak": "The modifiers on pieces without an attribute line count a quarter higher.",
	},
	"brawlers_wraps": {
		"name": "Brawler's Wraps", "base": "Opal Ring",
		"mods": ["added_strength", "added_dexterity"],
		"effect": "brawler",
		"effect_text": "{more}% more damage for every point of strength on your clicks, and of dexterity on your weapon's swings.",
		"ranks": {"more": [1, 1.5, 2, 3]},
		"peak": "Strength and dexterity each count on both clicks and swings.",
	},
	"butchers_cleaver": {
		"name": "Butcher's Cleaver", "base": "Wooden Sword",
		"mods": ["added_strength", "increased_damage"],
		"effect": "butcher",
		"effect_text": "Every {strength} strength is 1% Bleed.",
		"ranks": {"strength": [20, 15, 12, 10]},
		"peak": "An enemy that dies bleeding passes its wound to the next.",
	},
	"quickdraw_boots": {
		"name": "Quickdraw Boots", "base": "Leather Boot",
		"mods": ["added_dexterity", "increased_move_speed"],
		"effect": "quickdraw",
		"effect_text": "Every point of dexterity is {times} Spawn Speed.",
		"ranks": {"times": [1, 1.5, 2, 2]},
		"peak": "Spawn Speed past 100% becomes attack speed.",
	},
	"heirlooms_echo": {
		"name": "Heirloom's Echo", "base": "Emerald Amulet",
		"mods": ["added_intelligence", "added_crit"],
		"effect": "echo",
		"effect_text": "The attributes on your heirlooms' doll count {times} times.",
		"ranks": {"times": [2, 2.5, 3, 4]},
		"peak": "Every heirloom counts as one plus higher.",
	},
}

## The rank at which a unique is all it will be.
const PEAK := 4

## What the cards write each unique's numbers at: the player's rank of it, id -> 1..PEAK (the main
## scene's, set as the save loads and whenever an achievement climbs). Read where a card is written,
## never passed round, the way `Settings` is. Empty -- every test and screenshot unless it sets it --
## writes rank I; a test that sets it puts it back.
static var ranks := {}

static var _icons := {}


## Every unique's id, in the order written above, which is the order the collection log draws them in.
static func ids() -> Array:
	return UNIQUES.keys()


## What the fight is told a worn unique does: its effect id, with a home piece's ground on the end.
static func effect_of(id: String) -> String:
	var row: Dictionary = UNIQUES.get(id, {})
	var effect := str(row.get("effect", ""))
	return "home:%s" % row["home"] if effect == "home" else effect


## The home piece whose damage counts on `env`, or "".
static func home_piece(env: String) -> String:
	for id: String in UNIQUES:
		if str(UNIQUES[id].get("home", "")) == env:
			return id
	return ""


## Whether `id` grows with its achievement's rank.
static func is_ranked(id: String) -> bool:
	return UNIQUES.get(id, {}).has("ranks")


## One of a ranked unique's numbers at `rank` (clamped to I..PEAK), as its row writes it -- a percent
## is 25, not 0.25, so the card and the rule read the one figure and the rule does the dividing.
static func dial(id: String, key: String, rank := 1) -> float:
	var ladder: Array = UNIQUES[id]["ranks"][key]
	return float(ladder[clampi(rank, 1, ladder.size()) - 1])


## The rank a card writes `id` at: the player's (`ranks`), else I.
static func shown_rank(id: String) -> int:
	return int(ranks.get(id, 1))


## The line a unique gains at rank IV (`PEAK`), whatever rank it is asked at: a card writes it only
## once the player has reached it (the user's ruling, 2026-09-29). "" for an unranked unique.
static func peak_text(id: String) -> String:
	return str(UNIQUES[id].get("peak", ""))


## What a card says the piece does, with its numbers at `rank` -- or, at 0, every rank's at once,
## "5/4/3/2" (the collection log under detailed descriptions). Four sentences are read at IV then,
## since rank I's may be worded for its one ("a second").
static func effect_text(id: String, rank := 1) -> String:
	var row: Dictionary = UNIQUES[id]
	var said: Variant = row["effect_text"]
	var text := str(said[clampi(rank if rank > 0 else PEAK, 1, PEAK) - 1]) if said is Array else str(said)
	var numbers := {}
	for key: String in row.get("ranks", {}):
		numbers[key] = _written(dial(id, key, rank)) if rank > 0 else "/".join(
				range(1, PEAK + 1).map(func(at: int) -> String: return _written(dial(id, key, at))))
	return text.format(numbers)


## A dial as a card writes it: a whole number without a point ("3", not "3.0"), else as it is ("2.5").
static func _written(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value)


## Its own picture, or its base piece's until one has been cut for it (`tools/ui_kit.py`'s
## `UNIQUE_GEAR`), so a row can be written before its art is. Under `Settings.show_old_icons()` the
## picture it had before, where it had another.
static func icon(id: String) -> Texture2D:
	var path := ROOT + id + ".png"
	if Settings.show_old_icons() and ResourceLoader.exists(OLD_ROOT + id + ".png"):
		path = OLD_ROOT + id + ".png"
	if not _icons.has(path):
		_icons[path] = load(path) if ResourceLoader.exists(path) else LootTable.icon(UNIQUES[id]["base"])
	return _icons[path]


## The uniques a body can be carrying: every one of `unlocked` (`Achievements.unlocked`) this build
## has, on any ground -- a home piece included, since the Pilgrim's set went (the user's, 2026-09-29).
static func pool_for(unlocked: Array) -> Array:
	return unlocked.filter(func(id: String) -> bool: return UNIQUES.has(id))


## How often this enemy is carrying one: `LootTable.chance_for`'s shape on this file's own tier line,
## lifted by the drop rate and then by item rarity at unique's `ItemRarity.RARITY_STEP`.
static func chance_for(enemy_name: String, drop_rate := 0.0, item_rarity := 0.0) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = LootTable.SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	var rarity := 1.0 + maxf(item_rarity, 0.0) / 100.0 \
			* int(ItemRarity.RARITY_STEP[ItemRarity.Rarity.UNIQUE])
	return minf(tier * size * (1.0 + maxf(drop_rate, 0.0) / 100.0) * rarity, 1.0)


## One kill's worth: null almost always, or a unique off the pool of `unlocked`. The chance is drawn first and
## alone, as `LootTable.roll` draws its own, and the level is rolled under the same ceiling any drop's
## is -- with UNIQUE's high floor, so one is never found worthless. `guaranteed` skips the chance: the
## chest's half that holds a unique (`Encounter.MIMIC_UNIQUE`) and nothing else.
static func roll(enemy_name: String, unlocked: Array, rng: RandomNumberGenerator, tile_level := 1,
		drop_rate := 0.0, guaranteed := false, item_rarity := 0.0) -> Item:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, drop_rate, item_rarity):
		return null
	var pool := pool_for(unlocked)
	if pool.is_empty():
		return null
	var ceiling := maxi(1, tile_level + int(LootTable.TIER_LEVEL[EnemyRoster.tier_of(enemy_name)]))
	return Item.rolled_unique(pool[rng.randi_range(0, pool.size() - 1)], rng,
			ItemRarity.roll_level(ItemRarity.Rarity.UNIQUE, ceiling, rng))
