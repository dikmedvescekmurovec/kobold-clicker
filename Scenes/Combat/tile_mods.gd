class_name TileMods
extends RefCounted
## What the land past the second ice wall does to the fight on it, and what it pays for that. Rules
## only, no nodes: `for_cell` says which modifiers a tile carries and `Encounter` reads their numbers
## off `MODS`.
##
## **Nothing is saved.** A tile's modifiers are a pure function of the map's seed and the cell, the
## way its chest and its variant are, so a world always fields the same ones and the next world
## others.
##
## A row's numbers are the dials, and `Encounter` knows each key by name:
## `enemies` / `seconds` (added to the profile's), `elite_every` (put in its place), `hp`, `hit` and
## `attack` (shares **added** to every other lift of that kind, never compounded), `armor`, `dodge`,
## `block`, `time_on_hit`, `swing` and `walk_in` (factors), and the four it pays in -- `drop_rate`,
## `item_rarity`, `gold_find`, `xp`, all in percent. Barren and Gilded are asked for by id.
## `farm` is whether it can bite where there is no clock and nothing strikes: a farm run and a camp
## carry those and no others, reward and all.

## How many walls have to stand between a tile and the middle of the map before it carries any.
const FROM_WALLS := 2
## What Wild Tiles lifts every reward by, as a factor.
const WILD_REWARD := 1.1

const MODS := {
	"thick_skinned": {"name": "Thick-skinned", "text": "Enemies have 50% more health.",
		"reward": "+20% gold", "weight": 10, "farm": true, "hp": 0.5, "gold_find": 20.0},
	"elite_ground": {"name": "Elite Ground", "text": "An elite every fifth enemy.",
		"reward": "+25% item rarity", "weight": 10, "farm": true, "elite_every": 5, "item_rarity": 25.0,
		"not_with": ["horde", "sparse"]},
	# Five more of the rabble: the elite moves to the end with them, so the fight still ends on it.
	"horde": {"name": "Horde", "text": "Fifteen enemies on the same clock.",
		"reward": "+15% drop rate", "weight": 10, "enemies": 5, "elite_every": 15, "drop_rate": 15.0,
		"not_with": ["sparse", "elite_ground"]},
	# A boon: it takes one of the tile's places and pays nothing, four fewer bodies being its price.
	"sparse": {"name": "Sparse", "text": "Six enemies on the same clock.",
		"reward": "", "weight": 6, "enemies": -4, "elite_every": 6,
		"not_with": ["horde", "elite_ground"]},
	"short_day": {"name": "Short Day", "text": "8 seconds less on the clock.",
		"reward": "+25% experience", "weight": 10, "seconds": -8.0, "xp": 25.0},
	"savage": {"name": "Savage", "text": "Enemies hit 50% harder.",
		"reward": "+20% drop rate", "weight": 10, "hit": 0.5, "drop_rate": 20.0},
	"frenzied": {"name": "Frenzied", "text": "Enemies attack 30% faster.",
		"reward": "+15% drop rate", "weight": 10, "attack": 0.3, "drop_rate": 15.0},
	"piercing": {"name": "Piercing", "text": "Your armour counts for half.",
		"reward": "+25% gold", "weight": 8, "armor": 0.5, "gold_find": 25.0},
	"keen_eyed": {"name": "Keen-eyed", "text": "Your dodge counts for half.",
		"reward": "+25% gold", "weight": 8, "dodge": 0.5, "gold_find": 25.0},
	"sundering": {"name": "Sundering", "text": "Your block counts for half.",
		"reward": "+25% gold", "weight": 8, "block": 0.5, "gold_find": 25.0},
	# Halved and not taken away: it is the defence that wins back what the blows took.
	"timeless": {"name": "Timeless", "text": "Your time on hit counts for half.",
		"reward": "+30% experience", "weight": 4, "time_on_hit": 0.5, "xp": 30.0},
	"mire": {"name": "Mire", "text": "Enemies take twice as long to walk in.",
		"reward": "+15% experience", "weight": 10, "walk_in": 2.0, "xp": 15.0},
	"stillness": {"name": "Stillness", "text": "Your weapon swings 30% slower on its own.",
		"reward": "+25% drop rate", "weight": 10, "swing": 0.7, "drop_rate": 25.0},
	# The two trades, rare and never on one tile.
	"barren": {"name": "Barren", "text": "Enemies carry no gold.",
		"reward": "+60% item rarity", "weight": 2, "farm": true, "item_rarity": 60.0,
		"not_with": ["gilded"]},
	"gilded": {"name": "Gilded", "text": "Enemies drop no gear.",
		"reward": "+150% gold", "weight": 2, "farm": true, "gold_find": 150.0,
		"not_with": ["barren"]},
}


## The modifiers on `cell`, with `walls` walls between it and the middle of the map: none short of
## `FROM_WALLS`, one in the first band past it, one or two in the next, two or three from there on.
## `wild` is the Wild Tiles curse: a wall sooner, and one more everywhere.
static func for_cell(map_seed: int, cell: Vector2i, walls: int, wild := false) -> Array[String]:
	var out: Array[String] = []
	var band := walls - (FROM_WALLS - 1 if wild else FROM_WALLS)
	if band < 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map_seed, "mods", cell])
	var count := (1 if band < 2 else 2) + (0 if band == 0 else rng.randi_range(0, 1)) \
			+ (1 if wild else 0)
	var pool: Array = MODS.keys()
	while out.size() < count and not pool.is_empty():
		var total := 0
		for id: String in pool:
			total += int(MODS[id]["weight"])
		var pick := rng.randi_range(0, total - 1)
		for id: String in pool:
			pick -= int(MODS[id]["weight"])
			if pick < 0:
				out.append(id)
				pool.erase(id)
				for other: String in MODS[id].get("not_with", []):
					pool.erase(other)
				break
	return out


## The ones a farm run and a camp carry: those that change the bodies and not the clock.
static func farmable(mods: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in mods:
		if bool(MODS[id].get("farm", false)):
			out.append(id)
	return out


## What a tile's modifiers add up to on one dial, for the keys that add.
static func total(mods: Array, key: String) -> float:
	var sum := 0.0
	for id: String in mods:
		sum += float(MODS[id].get(key, 0.0))
	return sum


## What they multiply one of the player's numbers by, for the keys that are factors.
static func factor(mods: Array, key: String) -> float:
	var product := 1.0
	for id: String in mods:
		product *= float(MODS[id].get(key, 1.0))
	return product


## The tile panel's tooltip for one: what it does, and under it what it pays.
static func tip(id: String) -> String:
	var mod: Dictionary = MODS[id]
	return str(mod["text"]) if str(mod["reward"]).is_empty() else "%s\n%s" % [mod["text"], mod["reward"]]
