class_name SkillTree
extends RefCounted
## The skill trees: what every skill does, where it stands, what it takes to reach it. Tables and
## rules, no nodes and no state -- what the player has learned is `Skills`, the way what an item is
## worth is `LootTable` and what the player holds is `Inventory`.
##
## Every tree has one shape, the sketch it was designed from: a root, two side skills under it, a
## skill both of them lead to, and three chains of two hanging off that. A skill opens once **any**
## of its parents has a point in it, so the middle skill takes either side and the player chooses.
##
## Depth buys strength twice over. A skill low in the tree does more per point and more kinds of thing
## at once, and it holds fewer points: the root takes five, the bottom row one. So the root is where a
## level-2 player puts a point and gets a little, and the end of a chain is a single decision.
##
## Every skill is passive and adds to the same stats gear does, by two routes. `flat` is added to what
## the worn set adds up to, before anything multiplies it. `percent` is "increased", and multiplies the
## result **separately** from the gear's global percents -- see `Equipment.totals`, which is the one
## place both are applied. The Fortune stats are percentages already (`drop_rate`, `item_rarity`,
## `gold_find`, `orb_find`), so their skills add points of them flat: a multiplier on a drop rate that
## starts near nothing would be a multiplier on nothing.

## How much gold a reset costs per point it gives back, and what each player level multiplies that by.
## A reset has to cost something or the tree is a menu rather than a choice; it grows with the level
## because gold does, and a flat price would be free by the middle of the map.
const RESPEC_GOLD := 5.0
const RESPEC_GROWTH := 1.12

## Points a tree must already hold per row down before that row opens: the capstones need twelve.
const POINTS_PER_ROW := 3

const ICON_ROOT := "res://Assets/Skills/"

## tree id -> what it is called, the locked mark it wears, and its skills. Each skill: its name, the
## skills that lead to it, how many points it holds, where it stands (row down, column across, on a
## three-column grid), and per point what it adds flat and what it increases by percent. The last row
## also carries an `effect`, which changes how a fight plays rather than a number -- `Encounter` reads
## it -- and the `effect_text` that says so.
const TREES := {
	"power": {
		"label": "Power",
		"locked": "power_locked",
		"nodes": {
			"sharpened_edge": {"name": "Sharpened Edge", "parents": [], "max_rank": 5, "row": 0, "col": 1,
				"flat": {"damage": 1}, "percent": {}},
			"keen_eye": {"name": "Keen Eye", "parents": ["sharpened_edge"], "max_rank": 3, "row": 1, "col": 0,
				"flat": {"crit_chance": 1}, "percent": {}},
			"quick_hands": {"name": "Quick Hands", "parents": ["sharpened_edge"], "max_rank": 3, "row": 1, "col": 2,
				"flat": {"attack_speed": 0.05}, "percent": {}},
			"battle_rhythm": {"name": "Battle Rhythm", "parents": ["keen_eye", "quick_hands"], "max_rank": 3,
				"row": 2, "col": 1, "flat": {}, "percent": {"damage": 4}},
			"deadly_strikes": {"name": "Deadly Strikes", "parents": ["battle_rhythm"], "max_rank": 2,
				"row": 3, "col": 0, "flat": {"crit_chance": 1, "crit_damage": 10}, "percent": {}},
			"flurry": {"name": "Flurry", "parents": ["battle_rhythm"], "max_rank": 2, "row": 3, "col": 1,
				"flat": {}, "percent": {"attack_speed": 5}},
			"might": {"name": "Might", "parents": ["battle_rhythm"], "max_rank": 2, "row": 3, "col": 2,
				"flat": {"damage": 1}, "percent": {}},
			"assassin": {"name": "Assassin", "parents": ["deadly_strikes"], "max_rank": 1, "row": 4, "col": 0,
				"flat": {}, "percent": {"crit_damage": 15, "crit_chance": 5},
				"effect": "execute", "effect_text": "Execute: a blow that leaves an enemy under 10% health kills it"},
			"whirlwind": {"name": "Whirlwind", "parents": ["flurry"], "max_rank": 1, "row": 4, "col": 1,
				"flat": {}, "percent": {"attack_speed": 10, "damage": 5},
				"effect": "cleave", "effect_text": "Cleave: damage past a kill carries into the next enemy"},
			"titan": {"name": "Titan", "parents": ["might"], "max_rank": 1, "row": 4, "col": 2,
				"flat": {"damage": 2}, "percent": {"damage": 15},
				"effect": "giant_slayer", "effect_text": "Giant Slayer: double damage against elites and bosses"},
		},
	},
	"fortune": {
		"label": "Fortune",
		"locked": "fortune_locked",
		"nodes": {
			"scavenger": {"name": "Scavenger", "parents": [], "max_rank": 5, "row": 0, "col": 1,
				"flat": {"drop_rate": 3}, "percent": {}},
			"prospector": {"name": "Prospector", "parents": ["scavenger"], "max_rank": 3, "row": 1, "col": 0,
				"flat": {"gold_find": 5}, "percent": {}},
			"appraiser": {"name": "Appraiser", "parents": ["scavenger"], "max_rank": 3, "row": 1, "col": 2,
				"flat": {"item_rarity": 5}, "percent": {}},
			"fortunes_favour": {"name": "Fortune's Favour", "parents": ["prospector", "appraiser"],
				"max_rank": 3, "row": 2, "col": 1, "flat": {"drop_rate": 4, "item_rarity": 3}, "percent": {}},
			"treasure_hunter": {"name": "Treasure Hunter", "parents": ["fortunes_favour"], "max_rank": 2,
				"row": 3, "col": 0, "flat": {"item_rarity": 10}, "percent": {}},
			"greed": {"name": "Greed", "parents": ["fortunes_favour"], "max_rank": 2, "row": 3, "col": 1,
				"flat": {"gold_find": 15}, "percent": {}},
			"orb_seeker": {"name": "Orb Seeker", "parents": ["fortunes_favour"], "max_rank": 2,
				"row": 3, "col": 2, "flat": {"orb_find": 10}, "percent": {}},
			"collector": {"name": "Collector", "parents": ["treasure_hunter"], "max_rank": 1, "row": 4, "col": 0,
				"flat": {"drop_rate": 15, "item_rarity": 15}, "percent": {},
				"effect": "trophy", "effect_text": "Trophy: every elite and boss drops an item"},
			"midas": {"name": "Midas", "parents": ["greed"], "max_rank": 1, "row": 4, "col": 1,
				"flat": {"gold_find": 30, "drop_rate": 5}, "percent": {},
				"effect": "jackpot", "effect_text": "Jackpot: one purse in ten is five times fuller"},
			"alchemist": {"name": "Alchemist", "parents": ["orb_seeker"], "max_rank": 1, "row": 4, "col": 2,
				"flat": {"orb_find": 25, "item_rarity": 10}, "percent": {},
				"effect": "transmute", "effect_text": "Transmute: an orb that falls has a one in four chance to fall twice"},
		},
	},
}

## How many rows and columns every tree is laid out on.
const ROWS := 5
const COLS := 3

static var _icons := {}


## Every tree id, in the order the page draws them.
static func trees() -> Array:
	return TREES.keys()


static func nodes_of(tree: String) -> Dictionary:
	return TREES[tree]["nodes"]


static func node(id: String) -> Dictionary:
	var tree := tree_of(id)
	return {} if tree.is_empty() else nodes_of(tree)[id]


## Which tree a skill belongs to, or "" for a name this build does not know.
static func tree_of(id: String) -> String:
	for tree: String in TREES:
		if nodes_of(tree).has(id):
			return tree
	return ""


## The most points a tree holds.
static func capacity(tree: String) -> int:
	var total := 0
	for id: String in nodes_of(tree):
		total += int(nodes_of(tree)[id]["max_rank"])
	return total


static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = load(ICON_ROOT + id + ".png")
	return _icons[id]


static func locked_icon(tree: String) -> Texture2D:
	return icon(TREES[tree]["locked"])


## Whether a skill can be reached at all: its row's worth of points in the tree, and the root always,
## anything else once a parent has a point.
static func is_open(id: String, ranks: Dictionary) -> bool:
	return has_parent(id, ranks) and points_in(tree_of(id), ranks) >= points_for_row(id)


static func has_parent(id: String, ranks: Dictionary) -> bool:
	var parents: Array = node(id)["parents"]
	if parents.is_empty():
		return true
	for parent: String in parents:
		if int(ranks.get(parent, 0)) > 0:
			return true
	return false


## Points a tree needs spent before a skill on `id`'s row opens: POINTS_PER_ROW a row down. A learned
## skill never shuts again, because a tree's points only grow until a reset takes them all.
static func points_for_row(id: String) -> int:
	return POINTS_PER_ROW * int(node(id)["row"])


static func points_in(tree: String, ranks: Dictionary) -> int:
	var total := 0
	for id: String in ranks:
		if nodes_of(tree).has(id):
			total += int(ranks[id])
	return total


## Whether one more point can go into `id`, given what is learned and how many points are free.
## `can_rank` and `why_not` are two faces of one rule, the way OrbTable's are, so they are written
## side by side and read the same conditions in the same order.
static func can_rank(id: String, ranks: Dictionary, free_points: int) -> bool:
	return why_not(id, ranks, free_points).is_empty()


## The sentence explaining why a point cannot go into `id`, or "" when it can.
static func why_not(id: String, ranks: Dictionary, free_points: int) -> String:
	var entry := node(id)
	if entry.is_empty():
		return "No such skill"
	if int(ranks.get(id, 0)) >= int(entry["max_rank"]):
		return "Fully learned"
	if not has_parent(id, ranks):
		var names := PackedStringArray()
		for parent: String in entry["parents"]:
			names.append(node(parent)["name"])
		return "Needs a point in %s" % " or ".join(names)
	if not is_open(id, ranks):
		return "Needs %d points in %s" % [points_for_row(id), TREES[tree_of(id)]["label"]]
	if free_points <= 0:
		return "No skill points left"
	return ""


## What one point in `id` does, one clause a stat: "+1 Damage", "6% increased Damage".
static func describe(id: String, points := 1) -> String:
	var entry := node(id)
	var parts := PackedStringArray()
	var flat: Dictionary = entry["flat"]
	for stat: String in flat:
		parts.append(_flat_line(stat, float(flat[stat]) * points))
	var percent: Dictionary = entry["percent"]
	for stat: String in percent:
		parts.append("%d%% increased %s" % [roundi(float(percent[stat]) * points),
				LootTable.STAT_LABELS.get(stat, stat)])
	return ", ".join(parts)


static func _flat_line(stat: String, value: float) -> String:
	var label: String = LootTable.STAT_LABELS.get(stat, stat)
	if stat in LootTable.RATE_STATS:
		return "+%.1f/s %s" % [value, label]
	if stat in LootTable.PERCENT_STATS:
		return "+%d%% %s" % [roundi(value), label]
	return "+%d %s" % [roundi(value), label]


## What resetting a tree with `spent` points in it costs a player at `level`. Nothing, when nothing is
## spent: there is nothing to buy back.
static func respec_cost(level: int, spent: int) -> float:
	if spent <= 0:
		return 0.0
	return maxf(1.0, roundf(RESPEC_GOLD * spent * pow(RESPEC_GROWTH, maxi(level, 1) - 1)))
