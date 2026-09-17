class_name BountyBoard
extends RefCounted
## The work a settlement's board has posted: which monsters the town wants dead, how many, and what
## it pays for them.
##
## Three postings a board -- two of the rabble and one of something worse -- drawn only from the
## enemies that live on land the map has **actually generated** near the town, so a target is always
## something the player can walk to and find. Never a boss and never the mimic: a boss is what a set
## piece ends on, and the mimic lives nowhere at all.
##
## Static and node-free like `VendorStock` and `TownPrices`, and it works on the plain Dictionary that
## `TownState.visit` hands back: a board's postings are *rolled*, so they are written down with the
## town they belong to rather than worked out from a seed again. A caller hands in the environments
## and the town's cell rather than a map, so the rules can be read with no world around them.
##
## A posting is `{enemy, need, have, gold, orb, accepted, done}`. Only an **accepted** posting counts
## kills, and only one posting anywhere may be accepted at a time -- a bounty is a job taken on, not a
## tally that runs by itself -- until it is handed in. `have` stops at `need`; `done` is a bounty
## handed in, which stays on the board, spent, until the whole board is `cleared` and posted afresh.

## The drawer's keys, named here because what a board *is* is this file's business.
const BOUNTIES := "bounties"
## Whether the player has stood in front of this board, which is what puts the journal in the corner.
const SEEN := "board_seen"

## A posting's own keys.
const ENEMY := "enemy"
const NEED := "need"
const HAVE := "have"
const GOLD := "gold"
const ORB := "orb"
const DONE := "done"
## Whether the player has taken this posting on. Absent is not.
const ACCEPTED := "accepted"
## The level of the town that posted it. A kill counts only on land of that level or deeper, so a
## deep town's work cannot be done on the doorstep slimes. Absent (an older save) asks nothing.
const LEVEL := "level"

## How many of each tier a board posts. Two of the rabble and one elite: the pair are something to
## work through while walking, the elite is the one worth going out of the way for.
const COMMONS := 2
const ELITES := 1

## How many bodies a posting asks for. A couple of dozen commons is two or three tiles' fighting; a
## handful of elites is the same walk the other way round, since a tile fields one elite in ten.
const NEED_COMMON := 24
const NEED_ELITE := 5

## What a board pays against what the bodies themselves carried: the purse of `need` of that monster,
## this many times over. Quoted in the monster's own worth rather than in gold, so a deep town's board
## pays deep-town money without a second curve to keep in step. The dial for what a bounty is worth.
const REWARD_MULT := 3.0

## How far from the town its board looks for land to post monsters from, in hex steps. Far enough
## that a town has several environments to draw on, near enough that "where it lives" is a walk rather
## than an expedition.
const BOUNTY_RANGE := 4


## Posts a fresh board of `COMMONS` + `ELITES`, and only over one that is `cleared`: new work comes
## when the old work is done, not on a clock. Says whether anything was posted.
##
## `envs` is the land near the town (`MapBuilder.envs_within`) and `cell` the town's own cell, which
## is what the reward is priced against.
static func restock(drawer: Dictionary, envs: PackedStringArray, cell: Vector2i,
		rng: RandomNumberGenerator) -> bool:
	if not cleared(drawer):
		return false
	var posted := []
	var taken := {}
	for tier: int in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE]:
		for i in (ELITES if tier == EnemyRoster.Tier.ELITE else COMMONS):
			var enemy := _target(envs, tier, taken, rng)
			if enemy.is_empty():
				continue
			taken[enemy] = true
			posted.append(_posting(enemy, tier, cell, rng))
	drawer[BOUNTIES] = posted
	return not posted.is_empty()


## Whether every posting on the board has been handed in, which is what brings new work. A board
## with nothing on it -- never posted, or posted where nothing lives -- is cleared too.
static func cleared(drawer: Dictionary) -> bool:
	for bounty: Dictionary in bounties(drawer):
		if not bool(bounty.get(DONE, false)):
			return false
	return true


## What is posted on a board, with anything that is not a posting stepped over -- a save edited by
## hand is a board with less on it, never a crash. The postings themselves are the saved ones, so
## counting a kill against one writes it into the drawer where it stands.
static func bounties(drawer: Dictionary) -> Array:
	var posted := []
	var saved: Variant = drawer.get(BOUNTIES, null)
	if typeof(saved) != TYPE_ARRAY:
		return posted
	for entry: Variant in saved as Array:
		if typeof(entry) == TYPE_DICTIONARY:
			posted.append(entry)
	return posted


## The player is standing at the board. Returns whether that is news, so the caller knows to save.
static func see(drawer: Dictionary) -> bool:
	if seen(drawer):
		return false
	drawer[SEEN] = true
	return true


static func seen(drawer: Dictionary) -> bool:
	return bool(drawer.get(SEEN, false))


## Whether any board anywhere has been read yet, which is what puts the journal in the corner: there
## is no page worth opening before the player has stood at one.
static func any_seen(state: TownState) -> bool:
	for at: String in state.towns:
		if seen(state.towns[at]):
			return true
	return false


## Whether a posting has been taken on and not yet handed in.
static func is_active(bounty: Dictionary) -> bool:
	return bool(bounty.get(ACCEPTED, false)) and not bool(bounty.get(DONE, false))


## The one bounty the player is working on, wherever it was posted, or `{}` when there is none.
static func active(state: TownState) -> Dictionary:
	for at: String in state.towns:
		for bounty: Dictionary in bounties(state.towns[at]):
			if is_active(bounty):
				return bounty
	return {}


## Takes a posting on. Refused while another is still out, finished or not: one job at a time, and
## the last one is only over once it has been handed in.
static func accept(state: TownState, bounty: Dictionary) -> bool:
	if bool(bounty.get(DONE, false)) or not active(state).is_empty():
		return false
	bounty[ACCEPTED] = true
	return true


## One body down, counted against the accepted bounty if it wants that monster. Returns whether
## anything moved, so the caller knows whether the save has to be written.
##
## Progress stops at `need`: a bounty is a job of work, not a tally. `tile_level` is the level of the
## tile the body fell on, and one shallower than the posting's town does not count; -1 is a caller
## with no tile to speak of, which is asked nothing.
static func count_kill(state: TownState, enemy: String, times := 1, tile_level := -1) -> bool:
	var bounty := active(state)
	if bounty.is_empty() or str(bounty.get(ENEMY, "")) != enemy:
		return false
	if tile_level != -1 and tile_level < int(bounty.get(LEVEL, 0)):
		return false
	var need := int(bounty.get(NEED, 0))
	var have := int(bounty.get(HAVE, 0))
	bounty[HAVE] = mini(have + maxi(times, 0), need)
	return bounty[HAVE] != have


## Whether a posting is worked off and still waiting to be handed in.
static func ready(bounty: Dictionary) -> bool:
	return is_active(bounty) \
			and int(bounty.get(HAVE, 0)) >= int(bounty.get(NEED, 0))


## Hands a bounty in. False when it is not finished or has been handed in already, and then nothing
## moves -- which is the whole of how a board pays out exactly once. The caller pays what the posting
## says, because the purse is not this file's business.
static func claim(bounty: Dictionary) -> bool:
	if not ready(bounty):
		return false
	bounty[DONE] = true
	return true


## One monster of `tier` that lives on the land around the town and is not already posted, or "" when
## there is none. `EnemyRoster.in_environment` is what keeps the mimic out -- it lives nowhere -- and
## asking by tier is what keeps a boss off a board.
static func _target(envs: PackedStringArray, tier: int, taken: Dictionary,
		rng: RandomNumberGenerator) -> String:
	var candidates := PackedStringArray()
	for env: String in envs:
		for enemy: String in EnemyRoster.in_environment(env, tier):
			if not (enemy in candidates) and not taken.has(enemy):
				candidates.append(enemy)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


## One posting, priced off what the bodies it asks for are carrying. The elite's board work carries an
## orb as well, drawn the way a vendor's shelf draws one: what a bounty is for is the thing the ground
## will not hand over on its own.
static func _posting(enemy: String, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator) -> Dictionary:
	var need := NEED_ELITE if tier == EnemyRoster.Tier.ELITE else NEED_COMMON
	return {
		ENEMY: enemy,
		NEED: need,
		HAVE: 0,
		GOLD: maxf(1.0, roundf(Encounter.gold_of(enemy, cell) * need * REWARD_MULT)),
		ORB: OrbTable.roll_favoured(rng) if tier == EnemyRoster.Tier.ELITE else "",
		DONE: false,
		LEVEL: MapBuilder.level_of(cell),
	}
