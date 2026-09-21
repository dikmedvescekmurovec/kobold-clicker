class_name Skills
extends RefCounted
## What the player has learned: skill id -> how many points are in it. `SkillTree` is what a skill is;
## this is only the counts, and what they add up to.
##
## The points to spend are not stored. A level is worth one, so the free points are the level less
## what is spent -- which means a save can never disagree with itself about how many there are, and
## a level gained anywhere in the game is a point gained without anything having to hand it over.

## Only skills with points in them, the way `Inventory.orbs` holds only what is carried.
var ranks := {}

## Points this world's level has earned that a transcension of the trees took and never gave back.
var sunk := 0

## How many times the trees have been transcended, in every world: each one makes every skill's
## numbers `SkillTree.TRANSCEND_GAIN` stronger, and every rank a point dearer (`rank_cost`). Kept
## through a world's transcension, like the log.
var transcended := 0


## Points a player at `level` has earned: one a level past the first.
static func earned(level: int) -> int:
	return maxi(level - 1, 0)


func rank_of(id: String) -> int:
	return int(ranks.get(id, 0))


## Skill points one rank costs: one, and one more for every transcension of the trees.
func rank_cost() -> int:
	return 1 + transcended


## Ranks learned in `tree`, or in every tree when it is "".
func spent(tree := "") -> int:
	var total := 0
	for id: String in ranks:
		if tree.is_empty() or SkillTree.tree_of(id) == tree:
			total += int(ranks[id])
	return total


## Points still to spend at `level`.
func points(level: int) -> int:
	return maxi(earned(level) - spent() * rank_cost() - sunk, 0)


func can_rank(id: String, level: int) -> bool:
	return SkillTree.can_rank(id, ranks, points(level), rank_cost())


func why_not(id: String, level: int) -> String:
	return SkillTree.why_not(id, ranks, points(level), rank_cost())


## One point into `id`. Refused, and nothing changes, when `SkillTree.why_not` has anything to say.
func rank_up(id: String, level: int) -> bool:
	if not can_rank(id, level):
		return false
	ranks[id] = rank_of(id) + 1
	return true


## Whether every tree is full, which is when the trees can be transcended.
func can_transcend() -> bool:
	for tree: String in SkillTree.trees():
		if spent(tree) < SkillTree.capacity(tree):
			return false
	return true


## Every skill back to nothing and the points gone with them, for every skill stronger from now on.
## Refused, and nothing changes, while a tree is not full.
func transcend() -> bool:
	if not can_transcend():
		return false
	sunk += spent() * rank_cost()
	ranks = {}
	transcended += 1
	return true


## Takes every point out of `tree`. Whatever the reset costs is the inventory's business, because the
## purse is.
func reset(tree: String) -> void:
	for id: String in ranks.keys():
		if SkillTree.tree_of(id) == tree:
			ranks.erase(id)


## Every stat the learned skills add before anything multiplies.
func flat() -> Dictionary:
	return _sum("flat")


## Every stat the learned skills increase, in percent. Summed, not compounded: two skills of 10%
## increased damage are 20%, which is what a player adds up in their head.
func percent() -> Dictionary:
	return _sum("percent")


## The effects of every learned skill that has one, for `Encounter.effects`.
func effects() -> Array:
	var out := []
	for id: String in ranks:
		if SkillTree.node(id).has("effect"):
			out.append(SkillTree.node(id)["effect"])
	return out


func _sum(kind: String) -> Dictionary:
	var out := {}
	for id: String in ranks:
		var part: Dictionary = SkillTree.node(id)[kind]
		for stat: String in part:
			out[stat] = float(out.get(stat, 0.0)) 					+ SkillTree.scaled(float(part[stat]), transcended) * int(ranks[id])
	return out


func to_dict() -> Dictionary:
	return ranks.duplicate()


## Read back for a player at `level`. A skill this build no longer has is dropped and a rank over what
## a skill holds is cut down to it, the same pruning by name the rest of the save does. Then, if what
## is left is more than the level has earned, or holds a point that nothing leads to any more, the
## whole allocation is handed back: after a retune there is no honest way to guess which points the
## player would have kept, and a refund of every point costs them nothing but a few clicks. What a
## transcension of the trees took is never handed back, only cut to what the level has earned.
static func from_dict(data: Variant, level: int, sunk := 0, transcended := 0) -> Skills:
	var skills := Skills.new()
	skills.sunk = clampi(sunk, 0, earned(level))
	skills.transcended = maxi(transcended, 0)
	if typeof(data) != TYPE_DICTIONARY:
		return skills
	for key: Variant in data:
		var id := str(key)
		var entry := SkillTree.node(id)
		var value: Variant = data[key]
		if entry.is_empty() or not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
			continue
		var rank := clampi(int(value), 0, int(entry["max_rank"]))
		if rank > 0:
			skills.ranks[id] = rank
	if skills.spent() * skills.rank_cost() + skills.sunk > earned(level):
		skills.ranks = {}
	for id: String in skills.ranks:
		if not SkillTree.is_open(id, skills.ranks):
			skills.ranks = {}
			break
	return skills
