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
## A posting is `{enemy, need, have, gold, orb, item, accepted, done, level, located}`. Only an **accepted** posting counts
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
## The experience the hand-in pays. Absent (an older save) is none.
const XP := "xp"
## The orbs the hand-in pays, as a list of names, one a draw. An older save's single name, or "", is
## read back as a list by `bounties`.
const ORB := "orb"
## A piece of gear the posting pays besides its gold, as `{kind, rarity, plus}` -- the card's promise
## and nothing more: the piece itself is rolled when the work is handed in (`reward_item`), so what
## it is exactly is not written anywhere the player could read. A unique's `kind` is "": the card
## says "a unique piece" and shows no kind at all. Absent is none.
const ITEM := "item"
const ITEM_KIND := "kind"
const ITEM_RARITY := "rarity"
const ITEM_PLUS := "plus"
const DONE := "done"
## Whether the player has taken this posting on. Absent is not.
const ACCEPTED := "accepted"
## The level of the town that posted it. A kill counts only on land of that level or deeper, so a
## deep town's work cannot be done on the doorstep slimes. Absent (an older save) asks nothing.
const LEVEL := "level"
## Whether a fortuneteller has been paid to say where this monster lives, which is what puts the
## land and the nearest tile of it on the card. Absent is not.
const LOCATED := "located"

## How many of each tier a board posts. Two of the rabble and one elite: the pair are something to
## work through while walking, the elite is the one worth going out of the way for.
const COMMONS := 2
const ELITES := 1

## How many bodies a posting asks for. Five commons is a tile's fighting or less; one elite is a
## tile or so of looking, since a tile fields one elite in ten.
const NEED_COMMON := 5
const NEED_ELITE := 1

## What a board pays, in purses of the monster it asks for. Quoted in the monster's own worth rather
## than in gold, so a deep town's board pays deep-town money without a second curve to keep in step.
## The dials for what a bounty is worth (the user's, 2026-09-23).
const REWARD_COMMON := 100.0
const REWARD_ELITE := 20.0
## The same in experience: bodies of that monster's own worth at the town's cell.
const XP_COMMON := 50
const XP_ELITE := 10
## How many orbs a posting pays, each drawn as a vendor's shelf draws one (`OrbTable.roll_favoured`).
const ORBS := {EnemyRoster.Tier.COMMON: 1, EnemyRoster.Tier.ELITE: 3}

## How often a posting carries a piece of gear besides its gold, by the posting's tier; then how often
## that piece is a unique. The rarity is otherwise a boss's own draw (`ItemRarity.roll` on the BOSS
## row), the best of `RARITY_ROLLS` of them. Dials, unplayed.
const ITEM_CHANCE := {EnemyRoster.Tier.COMMON: 0.5, EnemyRoster.Tier.ELITE: 1.0}
const UNIQUE_CHANCE := {EnemyRoster.Tier.COMMON: 0.05, EnemyRoster.Tier.ELITE: 0.2}
const RARITY_ROLLS := {EnemyRoster.Tier.COMMON: 2, EnemyRoster.Tier.ELITE: 3}
## How likely a promised piece is to be at least +1, +2, +3, ...: past the list, each step is
## `PLUS_TAIL` as likely as the one before, with no ceiling.
const PLUS_CHANCES := [0.25, 0.05, 0.01, 0.001]
const PLUS_TAIL := 0.1

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
			# An orb this build no longer has is looked up by name wherever the reward is drawn, so it
			# is renamed here, by `Inventory.load_from`'s rule: Alteration's job is Transmutation's now,
			# and anything else retired pays no orb.
			# A save from before a posting paid several reads its one name as a list of one.
			var saved_orbs: Variant = entry.get(ORB, [])
			if typeof(saved_orbs) != TYPE_ARRAY:
				saved_orbs = [] if str(saved_orbs).is_empty() else [str(saved_orbs)]
			var orbs := []
			for orb: Variant in saved_orbs:
				var name := "Orb of Transmutation" if str(orb) == "Orb of Alteration" else str(orb)
				if OrbTable.ORBS.has(name):
					orbs.append(name)
			entry[ORB] = orbs
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


## The world spot (`TownState.key`) of the town whose posting the player is working on, or "" when no
## work is out. The main scene names that town in the banner a filled bounty raises.
static func active_spot(state: TownState) -> String:
	for at: String in state.towns:
		for bounty: Dictionary in bounties(state.towns[at]):
			if is_active(bounty):
				return at
	return ""


## The one bounty the player is working on, wherever it was posted, or `{}` when there is none.
static func active(state: TownState) -> Dictionary:
	var at := active_spot(state)
	if at.is_empty():
		return {}
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


## Gives the work up: the posting goes back on its board unaccepted and its kills are lost, so
## another can be taken on. A fortuneteller's word on where it lives is kept -- it was paid for.
## False when it was not out.
static func abandon(bounty: Dictionary) -> bool:
	if not is_active(bounty):
		return false
	bounty.erase(ACCEPTED)
	bounty[HAVE] = 0
	return true


## Whether the card may say where the monster lives.
static func located(bounty: Dictionary) -> bool:
	return bool(bounty.get(LOCATED, false))


## A fortuneteller has said where it lives. False when there was nothing to tell: only work that is
## out can be asked about, and only once.
static func locate(bounty: Dictionary) -> bool:
	if not is_active(bounty) or located(bounty):
		return false
	bounty[LOCATED] = true
	return true


## One body down, counted against the accepted bounty if it wants that monster. Returns whether
## anything moved, so the caller knows whether the save has to be written.
##
## Progress stops at `need`: a bounty is a job of work, not a tally. `tile_level` is the level of the
## tile the body fell on, and one shallower than the posting's town does not count; -1 is a caller
## with no tile to speak of, which is asked nothing.
static func count_kill(state: TownState, enemy: String, times := 1, tile_level := -1) -> bool:
	var bounty := active(state)
	if not takes(bounty, enemy, tile_level):
		return false
	var need := int(bounty.get(NEED, 0))
	var have := int(bounty.get(HAVE, 0))
	bounty[HAVE] = mini(have + maxi(times, 0), need)
	return bounty[HAVE] != have


## Whether a posting wants this body at all: its monster, on land at least as deep as its town. What
## `count_kill` asks before it moves anything, and what a run's ledger asks to say what a pouched body
## will count as without moving anything.
static func takes(bounty: Dictionary, enemy: String, tile_level := -1) -> bool:
	if bounty.is_empty() or str(bounty.get(ENEMY, "")) != enemy:
		return false
	return tile_level == -1 or tile_level >= int(bounty.get(LEVEL, 0))


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


## How many purses of its monster a posting of `tier` pays.
static func reward_of(tier: int) -> float:
	return REWARD_ELITE if tier == EnemyRoster.Tier.ELITE else REWARD_COMMON


## How many bodies' experience a posting of `tier` pays.
static func xp_reward_of(tier: int) -> int:
	return XP_ELITE if tier == EnemyRoster.Tier.ELITE else XP_COMMON


## One posting, priced off what the bodies it asks for are carrying. It carries orbs as well, drawn the
## way a vendor's shelf draws one: what a bounty is for is the thing the ground will not hand over on
## its own.
static func _posting(enemy: String, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator) -> Dictionary:
	var need := NEED_ELITE if tier == EnemyRoster.Tier.ELITE else NEED_COMMON
	var orbs := []
	for i in int(ORBS[tier]):
		orbs.append(OrbTable.roll_favoured(rng))
	return {
		ENEMY: enemy,
		NEED: need,
		HAVE: 0,
		GOLD: maxf(1.0, roundf(Encounter.gold_of(enemy, cell) * reward_of(tier))),
		XP: Encounter.xp_of(enemy, cell) * xp_reward_of(tier),
		ORB: orbs,
		ITEM: _item_promise(tier, rng),
		DONE: false,
		LEVEL: MapBuilder.level_of(cell),
	}


## What the card promises of a piece, or `{}`: the kind and the rarity, and whether it is ascended.
## Drawn at posting so the card can say it; the piece is drawn at the hand-in.
static func _item_promise(tier: int, rng: RandomNumberGenerator) -> Dictionary:
	if rng.randf() >= float(ITEM_CHANCE[tier]):
		return {}
	var plus := plus_of(rng.randf())
	if rng.randf() < float(UNIQUE_CHANCE[tier]):
		return {ITEM_KIND: "", ITEM_RARITY: ItemRarity.name_of(ItemRarity.Rarity.UNIQUE), ITEM_PLUS: plus}
	var rarity := ItemRarity.Rarity.COMMON
	for i in int(RARITY_ROLLS[tier]):
		rarity = maxi(rarity, ItemRarity.roll(EnemyRoster.Tier.BOSS, rng)) as ItemRarity.Rarity
	return {ITEM_KIND: LootTable.roll_kind(rng), ITEM_RARITY: ItemRarity.name_of(rarity), ITEM_PLUS: plus}


## How many times a promised piece is ascended, for a draw `roll` in [0, 1): the steps of
## `PLUS_CHANCES` and then `PLUS_TAIL` it clears. The chance underflows to 0 long before a float could
## loop for ever, so even a draw of exactly 0 stops.
static func plus_of(roll: float) -> int:
	var plus := 0
	var chance: float = PLUS_CHANCES[0]
	while roll < chance:
		plus += 1
		chance = PLUS_CHANCES[plus] if plus < PLUS_CHANCES.size() else chance * PLUS_TAIL
	return plus


## The orbs a posting pays, as names.
static func orbs_of(bounty: Dictionary) -> Array:
	var orbs: Variant = bounty.get(ORB, [])
	return orbs if typeof(orbs) == TYPE_ARRAY else []


## The piece a posting promises, read back whole or not at all: a kind this build has not got, or a
## rarity it cannot name, is no promise -- a save edited by hand pays gold and nothing else.
static func item_of(bounty: Dictionary) -> Dictionary:
	var promise: Variant = bounty.get(ITEM, null)
	if typeof(promise) != TYPE_DICTIONARY:
		return {}
	var rarity := ItemRarity.from_name(str(promise.get(ITEM_RARITY, "")))
	var kind := str(promise.get(ITEM_KIND, ""))
	if rarity < 0 or (rarity == ItemRarity.Rarity.UNIQUE) != kind.is_empty() \
			or (not kind.is_empty() and not LootTable.KINDS.has(kind)):
		return {}
	return promise


## The promise in words, for a tooltip: "an elite sword +1", "a unique piece", "" for none.
static func reward_text(bounty: Dictionary) -> String:
	var promise := item_of(bounty)
	if promise.is_empty():
		return ""
	var rarity := str(promise[ITEM_RARITY])
	var kind := str(promise[ITEM_KIND])
	var words := "%s %s" % [rarity, kind if not kind.is_empty() else "piece"]
	var plus := int(promise[ITEM_PLUS])
	if plus > 0:
		words += " +%d" % plus
	# "an elite", "an uncommon" -- and "a unique", which is read with a consonant.
	return ("an " if rarity in ["elite", "uncommon"] else "a ") + words


## The piece a finished posting pays, rolled here and now, or null for a posting that promised none.
## Its level is the town's ceiling for the posting's tier, the better of two rolls, as a vendor's
## shelf is; a unique is any unique the game has, at that ceiling. `rng` is the caller's.
static func reward_item(bounty: Dictionary, cell: Vector2i, rng: RandomNumberGenerator) -> Item:
	var promise := item_of(bounty)
	if promise.is_empty():
		return null
	var rarity: ItemRarity.Rarity = ItemRarity.from_name(str(promise[ITEM_RARITY]))
	var enemy := str(bounty.get(ENEMY, ""))
	var tier := EnemyRoster.tier_of(enemy) if EnemyRoster.ENEMIES.has(enemy) else EnemyRoster.Tier.COMMON
	var ceiling := maxi(1, MapBuilder.level_of(cell) + int(LootTable.TIER_LEVEL[tier]))
	var level := maxi(ItemRarity.roll_level(rarity, ceiling, rng),
			ItemRarity.roll_level(rarity, ceiling, rng))
	var item: Item
	if rarity == ItemRarity.Rarity.UNIQUE:
		var ids := UniqueTable.ids()
		item = Item.rolled_unique(str(ids[rng.randi_range(0, ids.size() - 1)]), rng, level)
	else:
		# The card promised this kind, so it is paid in it: a kind that begins past the plainest material
		# (the greaves) lifts a low piece to where its first material unlocks.
		var kind := str(promise[ITEM_KIND])
		level = maxi(level, LootTable.first_level(kind))
		var material := LootTable.material_level(level, MapBuilder.circle_of(cell))
		item = Item.rolled(LootTable._tier_at(kind, material, rng), rarity, rng, level)
	for i in int(promise[ITEM_PLUS]):
		item.ascend()
	return item
