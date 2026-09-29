class_name Skills
extends RefCounted
## What the player has learned: skill id -> how many points are in it. `SkillTree` is what a skill is;
## this is only the counts, and what they add up to.
##
## The points to spend are not stored. A level is worth one, so the free points are the level less
## what is spent -- which means a save can never disagree with itself about how many there are, and
## a level gained anywhere in the game is a point gained without anything having to hand it over.

## Only skills with points in them, the way `Inventory.orbs` holds only what is carried: this tree,
## the one being filled now.
var ranks := {}

## How many times every tree has been filled and burst this world. Each burnt tree still counts as
## every skill at its most -- its stats and its capstones' effects stay -- and each makes a rank of the
## next a point dearer (`rank_cost`). A world's transcension starts it over, with the level.
var bursts := 0

## Points a player at `level` has earned: one a level past the first.
static func earned(level: int) -> int:
	return maxi(level - 1, 0)


func rank_of(id: String) -> int:
	return int(ranks.get(id, 0))


## Ranks in `id`, the burnt trees' included: what its numbers are worth.
func total_of(id: String) -> int:
	return rank_of(id) + bursts * int(SkillTree.node(id)["max_rank"])


## Skill points a rank costs: one, and one more for every burst.
func rank_cost() -> int:
	return 1 + bursts


## Points spent in `tree` of the tree being filled now, or in all of it when `tree` is "". What a
## Reset gives back: a burnt tree is never given back.
func spent(tree := "") -> int:
	var total := 0
	for id: String in ranks:
		if tree.is_empty() or SkillTree.tree_of(id) == tree:
			total += int(ranks[id])
	return total * rank_cost()


## Points the burnt trees took: every rank of every tree, at each burst's own price (1, then 2...).
func sunk() -> int:
	return SkillTree.total_capacity() * bursts * (bursts + 1) / 2


## Points still to spend at `level`.
func points(level: int) -> int:
	return maxi(earned(level) - spent() - sunk(), 0)


func can_rank(id: String, level: int) -> bool:
	return SkillTree.can_rank(id, ranks, points(level), rank_cost())


func why_not(id: String, level: int) -> String:
	return SkillTree.why_not(id, ranks, points(level), rank_cost())


## One rank into `id`. Refused, and nothing changes, when `SkillTree.why_not` has anything to say.
func rank_up(id: String, level: int) -> bool:
	if not can_rank(id, level):
		return false
	ranks[id] = rank_of(id) + 1
	return true


## Whether every tree is full, and so bursts (`burst`). The skills page plays it, then calls `burst`.
func can_burst() -> bool:
	return SkillTree.all_full(ranks)


## Every tree burnt: its ranks are kept as `bursts` and the trees start again, a rank a point dearer.
## Refused, and nothing changes, while a tree has room.
func burst() -> bool:
	if not can_burst():
		return false
	bursts += 1
	ranks = {}
	return true


## Takes every point out of `tree`. Whatever the reset costs is the inventory's business, because the
## purse is.
func reset(tree: String) -> void:
	for id: String in ranks.keys():
		if SkillTree.tree_of(id) == tree:
			ranks.erase(id)


## Every stat the learned skills add before anything multiplies. `extra` is ranks more on every skill
## learned (the Sage's Abacus at IV), never on one that has none.
func flat(extra := 0) -> Dictionary:
	return _sum("flat", extra)


## Every stat the learned skills increase, in percent. Summed, not compounded: two skills of 10%
## increased damage are 20%, which is what a player adds up in their head.
func percent(extra := 0) -> Dictionary:
	return _sum("percent", extra)


## The effects of every learned skill that has one, for `Encounter.effects`: once each, however many
## trees hold it -- a burnt tree's capstones are what the next tree's no longer give.
func effects() -> Array:
	var out := []
	for id: String in _learned():
		if SkillTree.node(id).has("effect"):
			out.append(SkillTree.node(id)["effect"])
	return out


## Every skill with a rank in this tree or a burnt one.
func _learned() -> Array:
	if bursts <= 0:
		return ranks.keys()
	var out := []
	for tree: String in SkillTree.trees():
		out.append_array(SkillTree.nodes_of(tree).keys())
	return out


func _sum(kind: String, extra := 0) -> Dictionary:
	var out := {}
	for id: String in _learned():
		var part: Dictionary = SkillTree.node(id)[kind]
		for stat: String in part:
			out[stat] = float(out.get(stat, 0.0)) + float(part[stat]) * (total_of(id) + extra)
	return out


func to_dict() -> Dictionary:
	return ranks.duplicate()


## Read back for a player at `level`, `burst` times burst. A skill this build no longer has is
## dropped, and a rank past what a skill holds is cut down to it (a save from when ranks went past the
## most gets those points back). Then, if what is left is more than the level has earned, or holds a
## point that nothing leads to any more, the whole allocation is handed back: after a retune there is
## no honest way to guess which points the player would have kept, and a refund of every point costs
## them nothing but a few clicks. Bursts the level cannot have paid for are forgotten with it.
static func from_dict(data: Variant, level: int, burst := 0) -> Skills:
	var skills := Skills.new()
	skills.bursts = maxi(burst, 0)
	if skills.sunk() > earned(level):
		skills.bursts = 0
	if typeof(data) != TYPE_DICTIONARY:
		return skills
	for key: Variant in data:
		var id := str(key)
		var value: Variant = data[key]
		if SkillTree.node(id).is_empty() or not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			continue
		if int(value) > 0:
			skills.ranks[id] = int(value)
	for id: String in skills.ranks:
		skills.ranks[id] = mini(skills.ranks[id], int(SkillTree.node(id)["max_rank"]))
	if skills.spent() + skills.sunk() > earned(level):
		skills.ranks = {}
	for id: String in skills.ranks:
		if not SkillTree.is_open(id, skills.ranks):
			skills.ranks = {}
			break
	return skills
