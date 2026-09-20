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
## it always carries, its effect and the sentence that says so, and the environments it is found on
## (none = anywhere). `effect` is what `Encounter` reads; a home piece's also names its ground and its
## second rule, and reaches the fight as "home:<env>" and "<clause>:<env>".
const UNIQUES := {
	"metronome": {
		"name": "Metronome", "base": "Wooden Sword",
		"mods": ["increased_attack_speed", "increased_damage", "added_damage"],
		"effect": "metronome",
		"effect_text": "Your weapon's own swings deal triple damage. Your clicks deal none.",
		"envs": ["desert", "mountains"],
	},
	"headsman": {
		"name": "Headsman", "base": "Wooden Sword",
		"mods": ["increased_damage", "increased_crit_damage", "added_crit_damage"],
		"effect": "headsman",
		"effect_text": "A blow that leaves an enemy under 25% health kills it. Adds to Execute.",
		"envs": ["forest", "dirt"],
	},
	"knucklebone_ring": {
		"name": "Knucklebone Ring", "base": "Gold Ring",
		"mods": ["added_damage", "added_crit"],
		"effect": "knucklebone",
		"effect_text": "Each click within a second of the last adds 2% to your clicks, up to 50%.",
		"envs": [],
	},
	"the_tithe": {
		"name": "The Tithe", "base": "Gold Ring",
		"mods": ["added_gold_find", "global_increased_damage"],
		"effect": "tithe",
		"effect_text": "Enemies drop no ordinary gear. Their purses are three times as full.",
		"envs": ["grass", "dirt"],
	},
	"hourglass_amulet": {
		"name": "Hourglass Amulet", "base": "Ruby Amulet",
		"mods": ["global_increased_attack_speed", "added_crit"],
		"effect": "hourglass",
		"effect_text": "Each kill but a boss puts a second back on the clock, never past its start.",
		"envs": ["ice", "desert"],
	},
	"meadowstriders": {
		"name": "Meadowstriders", "base": "Leather Boot",
		"mods": ["increased_move_speed", "added_drop_rate"],
		"effect": "home", "home": "grass", "clause": "grazing",
		"effect_text": "Double damage on grass. Two more enemies join every fight there.",
		"envs": ["grass"],
	},
	"hunters_lantern": {
		"name": "Hunter's Lantern", "base": "Wooden Torch",
		"mods": ["added_crit_damage", "added_crit"],
		"effect": "home", "home": "forest", "clause": "flush_out",
		"effect_text": "Double damage in forest. On open land there the elite comes first.",
		"envs": ["forest"],
	},
	"sunscorched_cowl": {
		"name": "Sunscorched Cowl", "base": "Leather Helmet",
		"mods": ["added_crit", "increased_armor"],
		"effect": "home", "home": "desert", "clause": "heatstroke",
		"effect_text": "Double damage in desert. Enemies there lose 2% of their health every second they stand.",
		"envs": ["desert"],
	},
	"rimeplate": {
		"name": "Rimeplate", "base": "Wooden Armor",
		"mods": ["added_damage", "increased_health"],
		"effect": "home", "home": "ice", "clause": "frozen_clock",
		"effect_text": "Double damage on ice. The clock there stands still while an enemy walks in.",
		"envs": ["ice"],
	},
	# A weapon, not the shield it first was: the Hunter's Lantern is held in the off hand too, and two
	# home pieces in one socket meant a Pilgrim's set could never be whole.
	"stonebreaker": {
		"name": "Stonebreaker", "base": "Wooden Sword",
		"mods": ["added_damage", "increased_crit_damage"],
		"effect": "home", "home": "mountains", "clause": "giantsbane",
		"effect_text": "Double damage in mountains. Elites and bosses there take triple.",
		"envs": ["mountains"],
	},
	"gravediggers_charm": {
		"name": "Gravedigger's Charm", "base": "Ruby Amulet",
		"mods": ["global_increased_damage", "added_crit_damage"],
		"effect": "home", "home": "dirt", "clause": "restless",
		"effect_text": "Double damage on dirt. One ordinary enemy in ten there rises again at half health and pays again.",
		"envs": ["dirt"],
	},
	# --- Trade-offs ---
	"berserkers_band": {
		"name": "Berserker's Band", "base": "Gold Ring",
		"mods": ["added_damage", "added_crit_damage"],
		"effect": "berserk",
		"effect_text": "Your clicks deal triple damage. Your weapon never swings on its own.",
		"envs": ["mountains", "ice"],
	},
	"glass_edge": {
		"name": "Glass Edge", "base": "Wooden Sword",
		"mods": ["increased_damage", "increased_crit"],
		"effect": "glass_edge",
		"effect_text": "Double damage against the clock, which runs a third faster.",
		"envs": ["ice", "desert"],
	},
	"gamblers_die": {
		"name": "Gambler's Die", "base": "Ruby Amulet",
		"mods": ["added_crit", "added_drop_rate"],
		"effect": "gamble",
		"effect_text": "Every blow deals anywhere from almost nothing to three times its worth.",
		"envs": [],
	},
	"ascetics_cord": {
		"name": "Ascetic's Cord", "base": "Ruby Amulet",
		"mods": ["global_increased_damage"],
		"effect": "ascetic",
		"effect_text": "15% more damage for every place on you that is bare.",
		"envs": ["desert", "mountains"],
	},
	# --- The clock ---
	"last_gasp": {
		"name": "Last Gasp", "base": "Leather Helmet",
		"mods": ["added_crit", "increased_health"],
		"effect": "last_gasp",
		"effect_text": "Triple damage while five seconds or fewer remain.",
		"envs": ["dirt", "forest"],
	},
	# --- Crits and the lineup ---
	"duelists_buckler": {
		"name": "Duelist's Buckler", "base": "Wooden Shield",
		"mods": ["added_crit_damage", "increased_block"],
		"effect": "opening_strike",
		"effect_text": "Your first blow against every enemy is a critical strike.",
		"envs": ["grass", "forest"],
	},
	"overflowing_chalice": {
		"name": "Overflowing Chalice", "base": "Wooden Torch",
		"mods": ["added_crit", "added_crit_damage"],
		"effect": "overcrit",
		"effect_text": "Critical chance past the most you can have becomes critical damage.",
		"envs": [],
	},
	"dominoes": {
		"name": "Dominoes", "base": "Leather Boot",
		"mods": ["added_damage", "increased_move_speed"],
		"effect": "domino",
		"effect_text": "An enemy felled in one blow costs the next a fifth of its health.",
		"envs": ["grass", "dirt"],
	},
	"snowball": {
		"name": "Snowball", "base": "Wooden Armor",
		"mods": ["increased_armor", "added_damage"],
		"effect": "momentum",
		"effect_text": "2% more damage for every kill this fight, up to double.",
		"envs": ["ice"],
	},
	"packmule": {
		"name": "Packmule's Harness", "base": "Wooden Armor",
		"mods": ["increased_health", "added_drop_rate"],
		"effect": "packmule",
		"effect_text": "1% more damage for every piece in your bag.",
		"envs": ["mountains", "dirt"],
	},
	# --- Dead stats given a job (armour, health and block do nothing otherwise) ---
	"bulwark": {
		"name": "Bulwark", "base": "Wooden Shield",
		"mods": ["increased_block", "added_block"],
		"effect": "riposte",
		"effect_text": "Your chance to block is your chance to swing again at once.",
		"envs": ["mountains"],
	},
	"heartwood_plate": {
		"name": "Heartwood Plate", "base": "Wooden Armor",
		"mods": ["increased_health", "added_health"],
		"effect": "heartwood",
		"effect_text": "Every hundred health you have is a second more on the clock, up to ten.",
		"envs": ["forest"],
	},
	"spiked_helm": {
		"name": "Spiked Helm", "base": "Leather Helmet",
		"mods": ["increased_armor", "added_armor"],
		"effect": "spikes",
		"effect_text": "A hundredth of your armour is added to your damage.",
		"envs": ["desert", "mountains"],
	},
	# --- Loot ---
	"magpies_band": {
		"name": "Magpie's Band", "base": "Gold Ring",
		"mods": ["added_drop_rate", "added_gold_find"],
		"effect": "magpie",
		"effect_text": "One purse in twenty is a piece of gear instead.",
		"envs": ["forest", "grass"],
	},
	"lucky_wound": {
		"name": "Lucky Wound", "base": "Wooden Torch",
		"mods": ["added_crit", "added_drop_rate"],
		"effect": "lucky_wound",
		"effect_text": "An enemy you have struck critically rolls its drop twice and keeps the better.",
		"envs": [],
	},
	"rag_and_bone_sack": {
		"name": "Rag and Bone Sack", "base": "Wooden Armor",
		"mods": ["added_gold_find", "increased_health"],
		"effect": "salvage",
		"effect_text": "Gear you throw away pays a quarter of what a trader would give.",
		"envs": ["dirt"],
	},
}

## What every home piece's card says under its own sentences: the Pilgrim's set (`Equipment.effects`).
const PILGRIM_TEXT := "Pilgrim's set: worn with another piece of it, each works on the other's ground."

static var _icons := {}


## Every unique's id, in the order written above, which is the order the collection log draws them in.
static func ids() -> Array:
	return UNIQUES.keys()


## What the fight is told a worn unique does: its effect id, with a home piece's ground on the end.
static func effect_of(id: String) -> String:
	var row: Dictionary = UNIQUES.get(id, {})
	var effect := str(row.get("effect", ""))
	return "home:%s" % row["home"] if effect == "home" else effect


## A home piece's second rule as the fight is told it, "<clause>:<env>" -- on its own ground, or on
## `env` when a Pilgrim's set carries it to another. "" for a unique that is not a home piece.
static func clause_of(id: String, env := "") -> String:
	var row: Dictionary = UNIQUES.get(id, {})
	if not row.has("clause"):
		return ""
	return "%s:%s" % [row["clause"], row["home"] if env.is_empty() else env]


## What a card says the piece itself does.
static func effect_text(id: String) -> String:
	return str(UNIQUES[id]["effect_text"])


## What a card says its set does, on a line of its own: the Pilgrim's on a home piece, "" on the rest.
static func set_text(id: String) -> String:
	return PILGRIM_TEXT if UNIQUES[id].has("clause") else ""


## Its own picture, or its base piece's until one has been cut for it (`tools/ui_kit.py`'s
## `UNIQUE_GEAR`), so a row can be written before its art is.
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		var path := ROOT + id + ".png"
		_icons[id] = load(path) if ResourceLoader.exists(path) else LootTable.icon(UNIQUES[id]["base"])
	return _icons[id]


## The uniques a body on `env` can be carrying: the ones that name it, and the ones that name nowhere.
static func pool_for(env: String) -> Array:
	var pool := []
	for id: String in UNIQUES:
		var envs: Array = UNIQUES[id]["envs"]
		if envs.is_empty() or env in envs:
			pool.append(id)
	return pool


## How often this enemy is carrying one: `LootTable.chance_for`'s shape on this file's own tier line.
static func chance_for(enemy_name: String, drop_rate := 0.0) -> float:
	var tier: float = TIER_CHANCE[EnemyRoster.tier_of(enemy_name)]
	var size: float = LootTable.SIZE_CHANCE[EnemyRoster.size_of(enemy_name)]
	return minf(tier * size * (1.0 + maxf(drop_rate, 0.0) / 100.0), 1.0)


## One kill's worth: null almost always, or a unique off `env`'s pool. The chance is drawn first and
## alone, as `LootTable.roll` draws its own, and the level is rolled under the same ceiling any drop's
## is -- with UNIQUE's high floor, so one is never found worthless. `guaranteed` skips the chance: the
## chest's half that holds a unique (`Encounter.MIMIC_UNIQUE`) and nothing else.
static func roll(enemy_name: String, env: String, rng: RandomNumberGenerator, tile_level := 1,
		drop_rate := 0.0, guaranteed := false) -> Item:
	if not guaranteed and rng.randf() >= chance_for(enemy_name, drop_rate):
		return null
	var pool := pool_for(env)
	if pool.is_empty():
		return null
	var ceiling := maxi(1, tile_level + int(LootTable.TIER_LEVEL[EnemyRoster.tier_of(enemy_name)]))
	return Item.rolled_unique(pool[rng.randi_range(0, pool.size() - 1)], rng,
			ItemRarity.roll_level(ItemRarity.Rarity.UNIQUE, ceiling, rng))
