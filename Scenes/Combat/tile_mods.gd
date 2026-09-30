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
## `enemies` / `seconds` (added to the profile's), `elite_every` (put in its place, `value`) and
## `elite_last` (the elite moves to the end of however many there now are), `hp`, `hit` and
## `attack` (shares **added** to every other lift of that kind, never compounded), `armor`, `dodge`,
## `block`, `time_on_hit`, `swing` and `walk_in` (factors), and the four it pays in -- `drop_rate`,
## `item_rarity`, `gold_find`, `xp`, all in percent. Barren and Gilded are asked for by id.
## `farm` is whether it can bite where there is no clock and nothing strikes: a farm run and a camp
## carry those and no others, reward and all.

## How many walls have to stand between a tile and the middle of the map before it carries any.
const FROM_WALLS := 2
## What Wild Tiles lifts every reward by, as a factor.
const WILD_REWARD := 1.1

## A row's `text` names its dials in braces, and `describe` writes in what they come to at the tile's
## tier; what it pays is written from the pay keys. `once` is a row that never climbs a tier: a boon
## (Sparse) and the two trades, whose "no gold" has no second step.
const MODS := {
	"thick_skinned": {"name": "Thick-skinned", "text": "Enemies have {hp}% more health.",
		"weight": 10, "farm": true, "hp": 0.5, "gold_find": 20.0},
	# A tier makes elites come sooner (`value`), never later than every second body.
	"elite_ground": {"name": "Elite Ground", "text": "One enemy in {elite_every} is an elite.",
		"weight": 10, "farm": true, "elite_every": 5, "item_rarity": 25.0,
		"not_with": ["horde", "sparse"]},
	# More of the rabble: the elite moves to the end with them (`elite_last`), so the fight still ends on it.
	"horde": {"name": "Horde", "text": "{enemies} more enemies on the same clock.",
		"weight": 10, "enemies": 5, "elite_last": true, "drop_rate": 15.0,
		"not_with": ["sparse", "elite_ground"]},
	# A boon: it takes one of the tile's places and pays nothing, four fewer bodies being its price.
	"sparse": {"name": "Sparse", "text": "{enemies} fewer enemies on the same clock.",
		"weight": 6, "once": true, "enemies": -4, "elite_last": true,
		"not_with": ["horde", "elite_ground"]},
	"short_day": {"name": "Dusk", "text": "{seconds} seconds less on the clock.",
		"weight": 10, "seconds": -8.0, "xp": 25.0},
	"savage": {"name": "Brutal", "text": "Enemies hit {hit}% harder.",
		"weight": 10, "hit": 0.5, "drop_rate": 20.0},
	"frenzied": {"name": "Frenzied", "text": "Enemies attack {attack}% faster.",
		"weight": 10, "attack": 0.3, "drop_rate": 15.0},
	"piercing": {"name": "Piercing", "text": "Only {armor}% of your armour counts.",
		"weight": 8, "armor": 0.5, "gold_find": 25.0},
	"keen_eyed": {"name": "Keen-eyed", "text": "Only {dodge}% of your dodge counts.",
		"weight": 8, "dodge": 0.5, "gold_find": 25.0},
	"sundering": {"name": "Sundering", "text": "Only {block}% of your block counts.",
		"weight": 8, "block": 0.5, "gold_find": 25.0},
	# Cut and not taken away: it is the defence that wins back what the blows took.
	"timeless": {"name": "Miserly", "text": "Only {time_on_hit}% of your Time on Hit counts.",
		"weight": 4, "time_on_hit": 0.5, "xp": 30.0},
	"mire": {"name": "Mire", "text": "Enemies spawn {walk_in} times slower.",
		"weight": 10, "walk_in": 2.0, "xp": 15.0},
	"stillness": {"name": "Stillness", "text": "Your weapon swings {swing}% slower on its own.",
		"weight": 10, "swing": 0.7, "drop_rate": 25.0},
	# The two trades, rare and never on one tile.
	"barren": {"name": "Barren", "text": "Enemies carry no gold.",
		"weight": 2, "once": true, "farm": true, "item_rarity": 60.0,
		"not_with": ["gilded"]},
	"gilded": {"name": "Gilded", "text": "Enemies drop no gear.",
		"weight": 2, "once": true, "farm": true, "gold_find": 150.0,
		"not_with": ["barren"]},
}
## The keys that multiply, so a tier raises them to its power rather than adding them again.
const FACTORS := ["armor", "dodge", "block", "time_on_hit", "swing", "walk_in"]
## What each pay key is called on the tile panel, in the order it is written.
const PAYS := {"drop_rate": "drop rate", "item_rarity": "item rarity", "gold_find": "gold", "xp": "experience"}
const NUMERALS := ["", "", " II", " III", " IV", " V", " VI", " VII", " VIII", " IX", " X"]


## The modifiers on `cell`, standing in `ring` (`MapBuilder.ring_of`: the land between the ring-th
## wall and the next, so it follows the Ring of Walls' closer walls): none short of `FROM_WALLS`, then
## one draw in the first ring past it and one more in every ring after. Draws are put back, and **a
## modifier drawn again is listed again: its tier** (`describe`), which every dial reads by adding or
## multiplying once per listing. `wild` is the Wild Tiles curse: a wall sooner, and one more everywhere.
static func for_cell(map_seed: int, cell: Vector2i, ring: int, wild := false) -> Array[String]:
	var out: Array[String] = []
	var band := ring - (FROM_WALLS - 1 if wild else FROM_WALLS)
	if band < 0:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([map_seed, "mods", cell])
	var count := band + 1 + (1 if wild else 0)
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
				if MODS[id].get("once", false):
					pool.erase(id)
				for other: String in MODS[id].get("not_with", []):
					pool.erase(other)
				break
	return out


## What `key` of modifier `id` comes to at `tier`: added once a tier, a factor raised to it, and
## Elite Ground's spacing divided by it.
static func value(id: String, key: String, tier: int) -> float:
	var base := float(MODS[id][key])
	if key in FACTORS:
		return pow(base, tier)
	if key == "elite_every":
		return maxi(2, ceili(base / tier))
	return base * tier


## One modifier as the tile panel writes it, at `tier`: its name (with the tier past the first), what
## it does and what it pays, the last "" for one that pays nothing.
static func describe(id: String, tier: int) -> PackedStringArray:
	var mod: Dictionary = MODS[id]
	var text := str(mod["text"])
	for key: String in mod:
		if not text.contains("{%s}" % key):
			continue
		var number := value(id, key, tier)
		if key in ["hp", "hit", "attack", "armor", "dodge", "block", "time_on_hit"]:
			number *= 100.0
		elif key == "swing":
			number = (1.0 - number) * 100.0
		text = text.replace("{%s}" % key, str(roundi(absf(number))))
	var pays := PackedStringArray()
	for key: String in PAYS:
		if mod.has(key):
			pays.append("+%d%% %s" % [roundi(value(id, key, tier)), PAYS[key]])
	var numeral: String = NUMERALS[tier] if tier < NUMERALS.size() else " %d" % tier
	return PackedStringArray([str(mod["name"]) + numeral, text, ", ".join(pays)])


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

