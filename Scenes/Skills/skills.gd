class_name Skills
extends RefCounted
## The player's skill tree: the stones placed in it, path -> `Item` (`SkillTree` says what a path is),
## and the points in them, path -> ranks. `SkillTree` is the rules; this is only what stands where, and
## what it adds up to.
##
## The stones are kept from world to world and are changed only on the black screen of a transcension
## (`place`). The ranks are a world's: a level is a point, and a transcension starts the level over.
## The points to spend are not stored. A level is worth one, so the free points are the level less what
## is spent -- which means a save can never disagree with itself about how many there are.

## The placed stones, path -> Item. The root is no stone and is not here. A new hero has none: the root
## alone, its one slot empty (the user's, 2026-10-10; a dexterity stone stood in it until then, and a save
## that holds one keeps it).
var stones := {}
## Only stones with points in them, the way `Inventory.orbs` holds only what is carried, and the root's
## under "" once it holds any.
var ranks := {}

## Points a player at `level` has earned: one a level past the first.
static func earned(level: int) -> int:
	return maxi(level - 1, 0)


func rank_of(path: String) -> int:
	return int(ranks.get(path, 0))


## Points spent: what a Reset gives back.
func spent() -> int:
	var total := 0
	for path: String in ranks:
		total += int(ranks[path])
	return total


## Points still to spend at `level`.
func points(level: int) -> int:
	return maxi(earned(level) - spent(), 0)


func why_not(path: String, level: int) -> String:
	return SkillTree.why_not(path, stones, ranks, points(level))


## One rank into the stone at `path`. Refused, and nothing changes, when `SkillTree.why_not` has
## anything to say.
func rank_up(path: String, level: int) -> bool:
	if not why_not(path, level).is_empty():
		return false
	ranks[path] = rank_of(path) + 1
	return true


## Takes every point back. Whatever that costs is the inventory's business, because the purse is.
func reset() -> void:
	ranks = {}


## Every stat the stones holding points add before anything multiplies -- their base stats and FLAT
## lines, each once a rank -- less the attributes, which `attributes` counts, and a stone's own ranks;
## and the root's damage, a point each (`SkillTree.ROOT_DAMAGE`).
## `extra` is ranks more on every stone holding a point (the Sage's Abacus at IV), and `bases` attribute
## -> ranks more on the stones of that base (a helmet's line).
func flat(extra := 0, bases := {}) -> Dictionary:
	var out := _root_line(SkillTree.ROOT_DAMAGE)
	for path: String in _stones_held():
		var stats := (stones[path] as Item).effective_stats()
		for stat: String in stats:
			if stat != SkillTree.RANKS_STAT and not stat in SkillTree.ATTRIBUTES:
				out[stat] = float(out.get(stat, 0.0)) + float(stats[stat]) * _times(path, extra, bases)
	return out


## Every stat they increase, in percent: their GLOBAL lines, a rank each, and the root's increased damage
## (`SkillTree.ROOT_PERCENT`). Summed, not compounded: two of 10% increased damage are 20%, which is what
## a player adds up in their head.
func percent(extra := 0, bases := {}) -> Dictionary:
	var out := _root_line(SkillTree.ROOT_PERCENT)
	for path: String in _stones_held():
		var lines := (stones[path] as Item).global_percents()
		for stat: String in lines:
			out[stat] = float(out.get(stat, 0.0)) + float(lines[stat]) * _times(path, extra, bases)
	return out


## The three attributes the tree adds: every stone holding a point's, a rank each.
func attributes(extra := 0, bases := {}) -> Dictionary:
	var out := {}
	for attribute: String in SkillTree.ATTRIBUTES:
		out[attribute] = 0.0
	for path: String in _stones_held():
		var stats := (stones[path] as Item).effective_stats()
		for attribute: String in out:
			out[attribute] += float(stats.get(attribute, 0.0)) * _times(path, extra, bases)
	return out


## The effects of the capstones holding a point, for `Encounter.effects`: once each, however many are
## placed.
func effects() -> Array:
	var out := []
	for path: String in _stones_held():
		var stone: Item = stones[path]
		if not stone.capstone.is_empty():
			var effect: String = SkillTree.CAPSTONES[stone.capstone]["effect"]
			if not effect in out:
				out.append(effect)
	return out


## The paths of the stones holding a point: `ranks` less the root's.
func _stones_held() -> Array:
	return ranks.keys().filter(func(path: String) -> bool: return not path.is_empty())


## The root's damage, `per` a point it holds, or nothing while it holds none.
func _root_line(per: float) -> Dictionary:
	return {"damage": per * rank_of("")} if rank_of("") > 0 else {}


## How many times a stone's lines count: its ranks, and the ranks more the Abacus and a helmet hand
## every stone that has one.
func _times(path: String, extra: int, bases: Dictionary) -> int:
	return rank_of(path) + extra + int(bases.get(SkillTree.base_of(stones[path]), 0))


## Puts `stone` in `path` (`SkillTree.can_place` first; refused, it is handed straight back) and returns
## what that takes out of the tree: the stone that stood there, and every stone under a connector the
## new one does not have -- whole, with all that hangs off it. Their points come back.
func place(stone: Item, path: String) -> Array[Item]:
	var out: Array[Item] = []
	if not SkillTree.can_place(stone, path, stones):
		out.append(stone)
		return out
	if stones.has(path):
		out.append(stones[path])
	stones[path] = stone
	ranks.erase(path)
	for key: String in stones.keys():
		# The step straight under `path` on the way down to `key` says which connector it hangs off.
		var under := key.left(path.length() + 2)
		if key.begins_with(path + ".") and SkillTree.index_of(under) >= stone.connectors:
			out.append(stones[key])
			stones.erase(key)
			ranks.erase(key)
	return out


## The tree for the save: path -> the stone's own save.
func tree_dict() -> Dictionary:
	var out := {}
	for path: String in stones:
		out[path] = (stones[path] as Item).to_dict()
	return out


## Read back for a player at `level`. A save with no tree (from before there was one, or a new game)
## starts with the root alone. Stones are taken shallowest first and only where they may stand, so a
## stone whose parent is gone goes with it. A rank past a stone's most is cut to it; then, if what is
## left is more than the level has earned, or holds a point nothing leads to, every point is handed
## back: after a change there is no honest way to guess which the player would have kept.
static func from_dict(tree: Variant, saved_ranks: Variant, level: int) -> Skills:
	var skills := Skills.new()
	if typeof(tree) != TYPE_DICTIONARY:
		return skills
	var paths: Array = (tree as Dictionary).keys().map(func(key: Variant) -> String: return str(key))
	paths.sort_custom(func(a: String, b: String) -> bool:
		var deep := SkillTree.depth_of(a) - SkillTree.depth_of(b)
		return deep < 0 or deep == 0 and a < b)
	for path: String in paths:
		var stone := Item.from_dict(tree[path])
		if SkillTree.can_place(stone, path, skills.stones):
			skills.stones[path] = stone
	if typeof(saved_ranks) != TYPE_DICTIONARY:
		return skills
	for key: Variant in saved_ranks:
		var path := str(key)
		var value: Variant = saved_ranks[key]
		if not typeof(value) in [TYPE_INT, TYPE_FLOAT] or int(value) <= 0:
			continue
		if path.is_empty():
			skills.ranks[path] = int(value)
		elif skills.stones.has(path):
			skills.ranks[path] = mini(int(value), SkillTree.most_ranks(skills.stones[path]))
	if skills.spent() > earned(level) or skills.ranks.keys().any(
			func(path: String) -> bool: return not SkillTree.is_open(path, skills.ranks)):
		skills.ranks = {}
	return skills
