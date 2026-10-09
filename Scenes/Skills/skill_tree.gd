class_name SkillTree
extends RefCounted
## The skill tree's rules: what a stone is allowed where, what a point needs, what a body leaves and what
## the root is. Tables and rules, no state -- what the player has placed and learned is `Skills`, the way
## what an item is worth is `LootTable` and what the player holds is `Inventory`.
##
## The tree is the player's own (the user's design, 2026-10-08). It grows out of a fixed root from skill
## stones -- items that drop and are crafted like gear (`LootTable.KINDS`' stone kinds) -- placed on the
## black screen of a transcension. A stone has a base (strength, dexterity, intelligence), a tier (the
## deepest it may sit), 0 to 3 connectors (the stones that may hang off it), and lines. A level is a
## skill point, and a point is a rank in a placed stone: every line it carries counts once a rank.
##
## A slot is a **path**: the root's children "0", "1", "2", a child of "1" is "1.0" or "1.1", and so on,
## one digit a level since no stone holds more than three. Its depth is how many steps it has. A slot
## exists while the stone above it has the connector it hangs off, and a path names a place rather than
## a stone, so a swap renames nothing.

## How much gold a reset costs per point it gives back, and what each player level multiplies that by.
## A reset has to cost something or the tree is a menu rather than a choice; it grows with the level
## because gold does, and a flat price would be free by the middle of the map.
const RESPEC_GOLD := 5.0
const RESPEC_GROWTH := 1.12

const ICON_ROOT := "res://Assets/Skills/"
## An empty slot in the tree: the user's grey stone, small (`tools/skill_stones.py`), whose whole self is
## the root (`icon("root")`).
const EMPTY_NODE := "Stones/base_small"

## The slot every skill stone's kind names in `LootTable.KINDS`: no socket takes it.
const SLOT := "stone"
## The deepest tier a stone can be: the user's carved discs go to IX.
const MOST_TIER := 9
## The most child slots a stone can have.
const MOST_CONNECTORS := 3
## The root (path ""): not a stone, never moved, and one slot under it from the start (the user's,
## 2026-10-09; three until then). It takes every point the
## player has, with no most (the user's, 2026-10-09), and each is `ROOT_DAMAGE` damage and `ROOT_PERCENT`%
## increased damage (`Skills.flat`, `Skills.percent`).
const ROOT_DAMAGE := 1.0
const ROOT_PERCENT := 1.0
const ROOT_CONNECTORS := 1
## The root's slots now: `ROOT_CONNECTORS`, and more as the walls broken open them (`WallUnlocks.root_branches`,
## the user's, 2026-10-09). The main scene sets it as the save loads and as a wall falls, the way
## `UniqueTable.ranks` is set; a test that moves it puts it back.
static var root_slots := ROOT_CONNECTORS
## The three attributes, which the tree adds with the gear's rather than at a skill point's worth
## (`Skills.attributes`).
const ATTRIBUTES := ["strength", "dexterity", "intelligence"]
## What a stone's own count of ranks is read off (`most_ranks`): the `added_stone_ranks` line.
const RANKS_STAT := "stone_ranks"
## What `why_not` says of a stone at its most.
const FULL := "Fully learned"
## The capstones (the user's, 2026-10-08): stones that drop as themselves, a leaf each, carrying the
## effect a fight reads (`Encounter.effects`) and the lines their row names, rolled by tier. Keyed by
## the skill each once was, whose badge they wear (`icon`). `base` is the stone kind's item.
const CAPSTONES := {
	"assassin": {"name": "Assassin", "base": "Strength Node",
		"mods": ["global_increased_crit_damage", "global_increased_crit"], "effect": "execute",
		"effect_text": "A blow that leaves an enemy under 10% health kills it."},
	"whirlwind": {"name": "Whirlwind", "base": "Strength Node",
		"mods": ["global_increased_attack_speed", "global_increased_damage"], "effect": "cleave",
		"effect_text": "Damage past a kill carries into the next enemy."},
	"titan": {"name": "Titan", "base": "Strength Node",
		"mods": ["added_damage", "global_increased_damage"], "effect": "giant_slayer",
		"effect_text": "Double damage against elites and bosses."},
	"collector": {"name": "Collector", "base": "Intelligence Node",
		"mods": ["added_drop_rate", "added_item_rarity"], "effect": "trophy",
		"effect_text": "Every elite and boss drops an item."},
	"midas": {"name": "Midas", "base": "Intelligence Node",
		"mods": ["added_gold_find", "added_drop_rate"], "effect": "jackpot",
		"effect_text": "One gold drop in ten is five times bigger."},
	"alchemist": {"name": "Alchemist", "base": "Intelligence Node",
		"mods": ["added_orb_find", "added_item_rarity"], "effect": "transmute",
		"effect_text": "An orb that falls has a one in four chance to fall twice."},
	"phantom": {"name": "Phantom", "base": "Dexterity Node",
		"mods": ["global_increased_dodge"], "effect": "afterimage",
		"effect_text": "A dodge wins back up to 1s of lost time."},
	"bastion": {"name": "Bastion", "base": "Dexterity Node",
		"mods": ["added_block"], "effect": "shieldwall",
		"effect_text": "Block counts double against elites and bosses."},
	"undying": {"name": "Undying", "base": "Dexterity Node",
		"mods": ["added_time_on_hit"], "effect": "second_wind",
		"effect_text": "Once a fight, running out of time gives back 5s."},
}

## The three stones' items, one a base.
const BASES := ["Strength Node", "Dexterity Node", "Intelligence Node"]
## Every line a stone of each base can roll, and the tier that unlocks it (the user's rule, 2026-10-09:
## the good lines are saved for the deep stones). `ModifierTable.pool_for` reads this in place of the
## stone's `LootTable` row. Each line is on the base it belongs to and no other, the ranks line on all
## three (`RANKS_WEIGHTS`). Never a PERCENT line -- a stone has nothing of its own to scale but its
## attribute, and the GLOBAL line is the stone's form of it -- nor one the tree would not count: all
## attributes (`Skills.attributes` reads the three), a helmet's ranks on a base (`Inventory._tree`
## reads gear), and a count of enemies, which ranks would multiply past any sense. The tiers are dials.
const LINES := {
	"Strength Node": {
		"added_strength": 1, "added_damage": 1, "added_armor": 1, "added_stone_ranks": 1,
		"added_block": 2, "added_crit_damage": 2,
		"added_bleed": 3, "added_time_on_block": 3,
		"added_thorns": 4, "global_increased_armor": 4,
		"added_click_damage": 5, "added_elite_ward": 5,
		"global_increased_bleed": 6,
		"global_increased_crit_damage": 7,
		"added_elite_damage": 8,
		"global_increased_damage": 9,
	},
	"Dexterity Node": {
		# Attack speed has no flat form, so its global is the dexterity stone's first line, as the
		# starter's is.
		"added_dexterity": 1, "added_dodge": 1, "global_increased_attack_speed": 1, "added_move_speed": 1,
		"added_stone_ranks": 1,
		"added_time_on_hit": 2, "added_spawn_speed": 2,
		"added_parry": 3, "added_blow_delay": 3,
		"global_increased_dodge": 4, "added_recoup": 4,
		"added_swing_damage": 5,
		"global_increased_time_on_hit": 6,
		"added_first_blow": 7,
		"added_fight_clock": 8,
		"added_double_strike": 9,
	},
	"Intelligence Node": {
		"added_intelligence": 1, "added_crit": 1, "added_experience": 1, "added_stone_ranks": 1,
		"added_gold_find": 2, "added_camp_earnings": 2,
		"added_burn": 3, "added_elite_chance": 3,
		"added_tile_ward": 4,
		"added_orb_find": 5,
		"global_increased_crit": 6,
		"added_item_rarity": 7,
		"added_drop_rate": 8,
		"added_less_health": 9,
	},
}
## How often the ranks line is drawn on a stone of each tier, from I to IX, in place of its weight in
## `ModifierTable.MODS`: common on the shallow stones, rare on the deep ones. A dial.
const RANKS_WEIGHTS := [12, 10, 8, 7, 6, 5, 4, 3, 2]
## What a body's chance of gear is worth as a chance of a stone, on a roll of its own beside the gear's,
## the orbs' and the uniques'. A dial.
const STONE_SHARE := 0.25
## Of the stones that fall, the share that are capstones. A dial.
const CAPSTONE_SHARE := 0.05
## How often a stone falls with 0, 1, 2 and 3 child slots (the user's, 2026-10-09: 10/50/30/10%).
const CONNECTOR_WEIGHTS := [1, 5, 3, 1]

static var _icons := {}


## The tree every hero starts with: under the root's one slot, straight down (`SkillTreeView`), a
## dexterity stone (5 dexterity, +1% attack speed), an uncommon leaf of tier 1. Until the root had one
## slot (2026-10-09) a strength stone (+1 damage) and an intelligence one (+1% crit chance) stood beside
## it, the user's; `_starter_stone` makes any of the three.
static func starter() -> Dictionary:
	return {"0": _starter_stone("Dexterity Node", "global_increased_attack_speed")}


static func _starter_stone(type: String, line: String) -> Item:
	var stone := Item.new()
	stone.type = type
	stone.rarity = ItemRarity.Rarity.UNCOMMON
	stone.stone_tier = 1
	stone.stats = Item.scaled_stats(type, 1)
	# Its tier read off its number the way a save reads one (`Item.from_dict`), so it saves as it is.
	var mod := {"id": line, "value": 1}
	var under := ModifierTable.fit_under(line, 1, stone.mod_level())
	if under > 0:
		mod["under"] = under
	stone.mods = [mod]
	return stone


## How deep a slot is: 1 for the root's children.
static func depth_of(path: String) -> int:
	return 0 if path.is_empty() else path.count(".") + 1


## The slot a slot hangs off: "" for the root.
static func parent_of(path: String) -> String:
	var cut := path.rfind(".")
	return "" if cut < 0 else path.left(cut)


## Which of its parent's connectors a slot hangs off.
static func index_of(path: String) -> int:
	return int(path.substr(path.rfind(".") + 1))


## The `index`th slot under `path`.
static func child_of(path: String, index: int) -> String:
	return str(index) if path.is_empty() else "%s.%d" % [path, index]


## Which of the root's branches a slot is on: its first step.
static func branch_of(path: String) -> String:
	return path.get_slice(".", 0)


## How many slots hang off `path` among the placed `stones`: the root's `root_slots`, a stone's connectors, and
## none under an empty slot.
static func connectors_of(path: String, stones: Dictionary) -> int:
	if path.is_empty():
		return root_slots
	return (stones[path] as Item).connectors if stones.has(path) else 0


## Whether a slot is there to be filled: well formed, and under a parent with the connector it needs.
static func exists(path: String, stones: Dictionary) -> bool:
	# The root's branch may run past the third (the walls add them); a stone's are 0 to 2.
	if not RegEx.create_from_string("^\\d+(\\.[0-2])*$").search(path):
		return false
	var parent := parent_of(path)
	return (parent.is_empty() or stones.has(parent)) and index_of(path) < connectors_of(parent, stones)


## Whether `stone` may go in `path`: a slot that is there, no deeper than its tier.
static func can_place(stone: Item, path: String, stones: Dictionary) -> bool:
	return stone != null and stone.is_stone() and exists(path, stones) and depth_of(path) <= stone.stone_tier


## Whether a point can reach `path` at all: the root's children always, anything else once the stone
## above it holds a point.
static func is_open(path: String, ranks: Dictionary) -> bool:
	var parent := parent_of(path)
	return parent.is_empty() or int(ranks.get(parent, 0)) > 0


## How many points a stone takes: one, and its "+N ranks" line.
static func most_ranks(stone: Item) -> int:
	return 1 + roundi(float(stone.effective_stats().get(RANKS_STAT, 0.0)))


## Whether one more point can go into `path`. `can_rank` and `why_not` are two faces of one rule, the
## way OrbTable's are.
static func can_rank(path: String, stones: Dictionary, ranks: Dictionary, free_points: int) -> bool:
	return why_not(path, stones, ranks, free_points).is_empty()


## The sentence explaining why a point cannot go into `path`, or "" when it can. The root has no most
## and is always open, so only the points can stop it.
static func why_not(path: String, stones: Dictionary, ranks: Dictionary, free_points: int) -> String:
	if not path.is_empty() and not stones.has(path):
		return "No node here"
	if not path.is_empty() and int(ranks.get(path, 0)) >= most_ranks(stones[path]):
		return FULL
	if not is_open(path, ranks):
		return "Needs a point in the node before it"
	if free_points <= 0:
		return "No skill points left"
	return ""


## Which attribute a stone is: "strength", "dexterity" or "intelligence".
static func base_of(stone: Item) -> String:
	return LootTable.kind_of(stone.type).trim_suffix("_stone")


## The deepest tier a stone can fall at on ground of `tile_level`: each tier lasts a level longer than the
## one before (the user's, 2026-10-09) -- level 1 tier I, levels 2-3 II, 4-6 III, 7-10 IV, 11-15 V, and on
## to `MOST_TIER`.
@warning_ignore("integer_division")
static func deepest(tile_level: int) -> int:
	var tier := 1
	while tier < MOST_TIER and tier * (tier + 1) / 2 < tile_level:
		tier += 1
	return tier


## One kill's stone, or null (`Encounter._kill`): gear's chance (`LootTable.chance_for`) times
## `STONE_SHARE`, a tier evenly up to what the ground allows, and the rarity and the level a piece of gear
## would roll off this body. One in `CAPSTONE_SHARE` is a capstone, any of them alike.
static func roll(enemy_name: String, rng: RandomNumberGenerator, tile_level := 1, drop_rate := 0.0,
		item_rarity := 0.0) -> Item:
	if rng.randf() >= LootTable.chance_for(enemy_name, drop_rate) * STONE_SHARE:
		return null
	var body := EnemyRoster.tier_of(enemy_name)
	var tier := rng.randi_range(1, deepest(tile_level))
	if rng.randf() < CAPSTONE_SHARE:
		var ids := CAPSTONES.keys()
		return Item.rolled_capstone(ids[rng.randi_range(0, ids.size() - 1)], tier, rng,
				LootTable.drop_level(body, tile_level, ItemRarity.Rarity.UNIQUE, rng))
	var rarity := ItemRarity.roll(body, rng, item_rarity)
	var level := LootTable.drop_level(body, tile_level, rarity, rng)
	return Item.rolled(BASES[rng.randi_range(0, BASES.size() - 1)], rarity, rng, level, tier,
			_connectors(rng))


## The lines a stone of `item_type` at `tier` may roll: its base's, as far as the tier unlocks.
static func lines_for(item_type: String, tier: int) -> PackedStringArray:
	var out := PackedStringArray()
	var lines: Dictionary = LINES[item_type]
	for id: String in lines:
		if int(lines[id]) <= tier:
			out.append(id)
	return out


## How often a stone of `tier` draws the ranks line (`RANKS_WEIGHTS`).
static func ranks_weight(tier: int) -> int:
	return RANKS_WEIGHTS[clampi(tier, 1, MOST_TIER) - 1]


## A weighted draw of `CONNECTOR_WEIGHTS`.
static func _connectors(rng: RandomNumberGenerator) -> int:
	var total := 0
	for weight: int in CONNECTOR_WEIGHTS:
		total += weight
	var pick := rng.randi_range(1, total)
	for count in CONNECTOR_WEIGHTS.size():
		pick -= int(CONNECTOR_WEIGHTS[count])
		if pick <= 0:
			return count
	return 0


## A stone's shape as its card writes it: "Tier 3 · 2 connectors", "Tier 2 · Leaf".
static func shape_text(stone: Item) -> String:
	var children := "Leaf" if stone.connectors == 0 else "%d connector%s" % [
			stone.connectors, "" if stone.connectors == 1 else "s"]
	return "Tier %d · %s" % [stone.stone_tier, children]


## A stone as the tree draws it (`SkillTreeView`, the user's, 2026-10-09): its base's small disc, with no
## numeral, or a capstone's badge whole, since at the small disc's 16 px the badges are mush. The bag
## shows the carved disc (`Item.icon`).
static func node_icon(stone: Item) -> Texture2D:
	if not stone.capstone.is_empty():
		return icon(stone.capstone)
	return icon("Stones/%s_small" % base_of(stone).left(3))


## A capstone's badge, the root's grey stone (`"root"`), or a path under `ICON_ROOT` (`node_icon`).
static func icon(id: String) -> Texture2D:
	if not _icons.has(id):
		_icons[id] = load(ICON_ROOT + id + ".png")
	return _icons[id]


## What resetting `spent` points costs a player at `level`. Nothing, when nothing is spent: there is
## nothing to buy back.
static func respec_cost(level: int, spent: int) -> float:
	if spent <= 0:
		return 0.0
	return maxf(1.0, roundf(RESPEC_GOLD * spent * pow(RESPEC_GROWTH, maxi(level, 1) - 1)))
