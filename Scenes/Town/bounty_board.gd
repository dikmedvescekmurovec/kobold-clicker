class_name BountyBoard
extends RefCounted
## The work a settlement's board has posted. Static and node-free, on the plain drawer `TownState.visit`
## hands back: postings are rolled, so they are written down with their town, never worked out again.
##
## A posting is `{enemy, need, have, gold, xp, orb, item, accepted, done, level}`. Only an accepted one
## counts kills, and only one posting anywhere may be accepted at a time, until it is handed in. `have`
## stops at `need`; a `done` posting stays on the board, spent, until the whole board is `cleared`.

## The drawer's keys: the postings, and whether the player has stood at this board (which is what puts
## the journal in the corner).
const BOUNTIES := "bounties"
const SEEN := "board_seen"

## A posting's keys. Absent, as in an older save, `xp` and `item` are none, `accepted` is not and
## `level` asks nothing.
const ENEMY := "enemy"
const NEED := "need"
const HAVE := "have"
const GOLD := "gold"
const XP := "xp"
## The orbs paid, a list of names, one a draw. An older save's single name, or "", is read back as a
## list by `bounties`.
const ORB := "orb"
## A piece paid besides the gold, as `{kind, rarity, plus}`: the card's promise only. The piece is
## rolled at the hand-in (`reward_item`), so what it is exactly is written nowhere the player could
## read. A unique's `kind` is "".
const ITEM := "item"
const ITEM_KIND := "kind"
const ITEM_RARITY := "rarity"
const ITEM_PLUS := "plus"
const DONE := "done"
const ACCEPTED := "accepted"
## The level of the town that posted it: a kill counts only on land of that level or deeper.
const LEVEL := "level"

## How many of each tier a board posts.
const COMMONS := 2
const ELITES := 1

## How many bodies a posting asks for, by the board's tier (`_at`).
const TIER_NEED_COMMON := [5, 8, 12]
const TIER_NEED_ELITE := [1, 2, 3]

## What a posting pays, in purses of the monster it asks for at the town's cell, so a deep board pays
## deep money with no second curve (the user's dials, 2026-09-23); and the same in bodies' experience.
const REWARD_COMMON := 100.0
const REWARD_ELITE := 20.0
const XP_COMMON := 50
const XP_ELITE := 10
## How many orbs a posting pays, each drawn as a vendor's shelf draws one (`OrbTable.roll_favoured`).
const ORBS := {EnemyRoster.Tier.COMMON: 1, EnemyRoster.Tier.ELITE: 3}

## How often a posting carries a piece besides its gold, by the posting's tier; then how often that
## piece is a unique, by the board's tier (the user's, 2026-10-03). The rarity is otherwise the best of
## `RARITY_ROLLS` of a boss's own draw (`ItemRarity.roll` on the BOSS row). Dials, unplayed.
const ITEM_CHANCE := {EnemyRoster.Tier.COMMON: 0.5, EnemyRoster.Tier.ELITE: 1.0}
const UNIQUE_CHANCE := {EnemyRoster.Tier.COMMON: [0.02, 0.03, 0.05], EnemyRoster.Tier.ELITE: [0.1, 0.15, 0.25]}
const RARITY_ROLLS := {EnemyRoster.Tier.COMMON: 2, EnemyRoster.Tier.ELITE: 3}
## How likely a promised piece is to be at least +1, +2, +3, ...: past the list, each step is
## `PLUS_TAIL` as likely as the one before, with no ceiling.
const PLUS_CHANCES := [0.25, 0.05, 0.01, 0.001]
const PLUS_TAIL := 0.1

## A board's tier is I to `BOARD_TIERS`: one more for every board this town has cleared (`CLEARS`), a
## record kept per town (the user's, 2026-10-03). These multiply or add to the dials above, by the
## board's tier (`_at`). Dials, unplayed.
const BOARD_TIERS := 3
const TIER_PAY := [1.0, 2.5, 6.0]
const TIER_ORBS := [0, 1, 2]
const TIER_RARITY_ROLLS := [0, 1, 2]
## Divides the draw `plus_of` reads, which multiplies the chance of every ascension step: at least +1
## at 25%, 33% and 50% (the user's, 2026-10-03).
const TIER_PLUS := [1.0, 4.0 / 3.0, 2.0]

## The drawer's count of boards this town has cleared, and the options a clear has offered and the
## player has not yet taken (`clear`, `choice`, `take_choice`).
const CLEARS := "boards_cleared"
const CHOICE := "choice"

## What a clear may offer, `CHOICES` different kinds a time: an epic at the town's ceiling, ascended; an
## epic above the ceiling; a unique; an ascended unique; a rare rolled lucky; a handful of one of the
## three dearest orbs; a pile of gold; a pile of experience. "Lucky" is rolled again and the better
## kept (`_lucky`, `LootTable.tier_at`).
const ASCENDED := "ascended"
const HIGH := "high"
const UNIQUE := "unique"
const ASCENDED_UNIQUE := "ascended_unique"
const RARE := "rare"
const ORB_BUNDLE := "orbs"
const GOLD_PILE := "gold_pile"
const XP_PILE := "xp_pile"
const CHOICE_KINDS := [ASCENDED, HIGH, UNIQUE, ASCENDED_UNIQUE, RARE, ORB_BUNDLE, GOLD_PILE, XP_PILE]
const CHOICES := 3
## An option's keys as saved: `{item: Item.to_dict()}`, `{orb, count}`, `{gold}` or `{xp}`.
const CHOICE_ITEM := "item"
const CHOICE_ORB := "orb"
const CHOICE_COUNT := "count"
const CHOICE_GOLD := "gold"
const CHOICE_XP := "xp"
## Dials by the board's tier, unplayed (the user's, 2026-10-03). ASCENDED: its ascensions, and how many
## times each modifier is rolled, the best kept. HIGH: the levels it stands above the ceiling, and how
## many draws its material is the best of. ASCENDED_UNIQUE: its ascensions. RARE: lucky at every tier.
## The bundle: how many of each orb, only ever one the player has unlocked (`OrbTable.unlocked`), and
## no bundle while none is. The piles: bodies at the town's level, one common posting's gold or
## experience at that tier (`REWARD_COMMON` / `XP_COMMON` times `TIER_PAY`).
const EPIC_PLUS := [1, 1, 2]
const EPIC_ROLLS := [1, 2, 2]
const CHOICE_LEVELS := [1, 2, 3]
const HIGH_DRAWS := [2, 3, 4]
const UNIQUE_PLUS := [1, 1, 2]
const RARE_ROLLS := 2
const CHOICE_ORBS := {
	"Orb of Divinity": [6, 10, 15],
	"Orb of Chaos": [4, 7, 10],
	"Orb of Exaltation": [2, 4, 6],
}
const PILE_GOLD := [100.0, 250.0, 600.0]
const PILE_XP := [50, 125, 300]

## How far from the town its board looks for land to post monsters from, in hex steps: far enough that
## a town has several environments to draw on, near enough that "where it lives" is a walk.
const BOUNTY_RANGE := 4


## Posts a fresh board of `COMMONS` + `ELITES`, and only over one that is `cleared`; says whether
## anything was posted. `envs` is the land near the town (`MapBuilder.envs_within`) and `cell` the
## town's own, which the reward is priced against.
static func restock(drawer: Dictionary, envs: PackedStringArray, cell: Vector2i,
		rng: RandomNumberGenerator, walls := OrbTable.EVERY_WALL) -> bool:
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
			posted.append(_posting(enemy, tier, cell, rng, walls, board_tier(drawer)))
	drawer[BOUNTIES] = posted
	return not posted.is_empty()


static func board_tier(drawer: Dictionary) -> int:
	return clampi(1 + int(drawer.get(CLEARS, 0)), 1, BOARD_TIERS)


## A board tier as an index into the lists of dials.
static func _at(tier: int) -> int:
	return clampi(tier, 1, BOARD_TIERS) - 1


## The hand-in that cleared the board: writes `CHOICE`, rolled at the tier the board was, and counts the
## clear -- so ask this **before** `restock`, which posts at the new tier. False, and nothing written,
## on a board with work still out or with nothing posted at all.
static func clear(drawer: Dictionary, cell: Vector2i, rng: RandomNumberGenerator,
		unlocked: Array = Achievements.STARTERS, walls := OrbTable.EVERY_WALL) -> bool:
	if bounties(drawer).is_empty() or not cleared(drawer):
		return false
	drawer[CHOICE] = roll_choice(board_tier(drawer), cell, rng, unlocked, walls)
	drawer[CLEARS] = int(drawer.get(CLEARS, 0)) + 1
	return true


## `CHOICES` options of different kinds, as they are saved, the pieces rolled whole at the boss's ceiling
## for the town's cell.
static func roll_choice(tier: int, cell: Vector2i, rng: RandomNumberGenerator,
		unlocked: Array = Achievements.STARTERS, walls := OrbTable.EVERY_WALL) -> Array:
	var orbs := CHOICE_ORBS.keys().filter(func(orb: String) -> bool:
			return orb in OrbTable.unlocked(walls))
	var kinds := CHOICE_KINDS.duplicate()
	if orbs.is_empty():
		kinds.erase(ORB_BUNDLE)
	var at := _at(tier)
	var ceiling := VendorStock.ceiling(cell, EnemyRoster.Tier.BOSS)
	var options := []
	# Drawn by the caller's rng, not `shuffle`, which would ignore it.
	for i in mini(CHOICES, kinds.size()):
		var kind: String = kinds.pop_at(rng.randi_range(0, kinds.size() - 1))
		if kind == ORB_BUNDLE:
			var orb: String = orbs[rng.randi_range(0, orbs.size() - 1)]
			options.append({CHOICE_ORB: orb, CHOICE_COUNT: int(CHOICE_ORBS[orb][at])})
			continue
		if kind == GOLD_PILE:
			options.append({CHOICE_GOLD: pile_gold(tier, cell)})
			continue
		if kind == XP_PILE:
			options.append({CHOICE_XP: pile_xp(tier, cell)})
			continue
		var piece: Item
		if kind == UNIQUE or kind == ASCENDED_UNIQUE:
			piece = _any_unique(unlocked, rng, ceiling)
			if kind == ASCENDED_UNIQUE:
				for n in int(UNIQUE_PLUS[at]):
					piece.ascend()
		elif kind not in [ASCENDED, HIGH, RARE]:
			push_error("BountyBoard: no reward is written for a choice of kind '%s'" % kind)
			continue
		else:
			var level: int = ceiling + (int(CHOICE_LEVELS[at]) if kind == HIGH else 0)
			var base := LootTable.roll_kind(rng)
			var rarity := ItemRarity.Rarity.RARE if kind == RARE else ItemRarity.Rarity.ELITE
			piece = Item.rolled(LootTable.tier_at(base, maxi(level, LootTable.first_level(base)), rng,
					int(HIGH_DRAWS[at]) if kind == HIGH else 1), rarity, rng, level)
			if kind == ASCENDED:
				_lucky(piece, int(EPIC_ROLLS[at]), rng)
				for n in int(EPIC_PLUS[at]):
					piece.ascend()
			elif kind == RARE:
				_lucky(piece, RARE_ROLLS, rng)
		options.append({CHOICE_ITEM: piece.to_dict()})
	return options


## A unique at `level`, any of `unlocked` alike. The list is indexed straight into: it is never empty
## (`Achievements.STARTERS`, and `FortuneTeller.BANISH_LEAVES` is the banishing's floor).
static func _any_unique(unlocked: Array, rng: RandomNumberGenerator, level: int) -> Item:
	return Item.rolled_unique(str(unlocked[rng.randi_range(0, unlocked.size() - 1)]), rng, level)


## Every modifier on a fresh piece rolled `rolls` times in all, tier and number, and the higher number
## kept: 2 is lucky.
static func _lucky(piece: Item, rolls: int, rng: RandomNumberGenerator) -> void:
	for i in piece.mods.size():
		for n in rolls - 1:
			var again := ModifierTable.rolled_mod(str(piece.mods[i]["id"]), rng, piece.mod_level())
			if int(again["value"]) > int(piece.mods[i]["value"]):
				piece.mods[i] = again


## The pile of gold a clear of a tier `tier` board offers, at the town on `cell`.
static func pile_gold(tier: int, cell: Vector2i) -> float:
	return maxf(1.0, roundf(TownPrices.gold_at_town(cell) * float(PILE_GOLD[_at(tier)])))


static func pile_xp(tier: int, cell: Vector2i) -> int:
	return Encounter.base_xp(cell) * int(PILE_XP[_at(tier)])


## The Dictionaries of the list saved under `key`, the saved ones themselves. Anything else in a save
## edited by hand is stepped over: less on the board, never a crash.
static func _saved(drawer: Dictionary, key: String) -> Array:
	var saved: Variant = drawer.get(key, null)
	if typeof(saved) != TYPE_ARRAY:
		return []
	return (saved as Array).filter(func(entry: Variant) -> bool: return typeof(entry) == TYPE_DICTIONARY)


## The options a clear has offered and the player has not taken, read back: `{item: Item}`,
## `{orb, count}`, `{gold}` or `{xp}`. One this build cannot read is stepped over.
static func choice(drawer: Dictionary) -> Array:
	var offered := []
	for entry: Dictionary in _saved(drawer, CHOICE):
		if entry.has(CHOICE_ITEM):
			var piece := Item.from_dict(entry[CHOICE_ITEM])
			if piece != null:
				offered.append({CHOICE_ITEM: piece})
		elif entry.has(CHOICE_GOLD):
			if float(entry[CHOICE_GOLD]) > 0.0:
				offered.append({CHOICE_GOLD: float(entry[CHOICE_GOLD])})
		elif entry.has(CHOICE_XP):
			if int(entry[CHOICE_XP]) > 0:
				offered.append({CHOICE_XP: int(entry[CHOICE_XP])})
		elif entry.has(CHOICE_ORB):
			var orb := OrbTable.current(str(entry[CHOICE_ORB]))
			if OrbTable.ORBS.has(orb) and int(entry.get(CHOICE_COUNT, 0)) > 0:
				offered.append({CHOICE_ORB: orb, CHOICE_COUNT: int(entry[CHOICE_COUNT])})
		else:
			push_error("BountyBoard: a saved choice of no kind this build reads (%s)" % [entry.keys()])
	return offered


## Takes option `index` and lets the others go. Returns it read back, or `{}` when there is no such
## option -- and then nothing is spent. The caller pays it: the bag is not this file's business.
static func take_choice(drawer: Dictionary, index: int) -> Dictionary:
	var offered := choice(drawer)
	if index < 0 or index >= offered.size():
		return {}
	drawer.erase(CHOICE)
	return offered[index]


## Whether every posting has been handed in, which is what brings new work. A board with nothing on it
## -- never posted, or posted where nothing lives -- is cleared too.
static func cleared(drawer: Dictionary) -> bool:
	for bounty: Dictionary in bounties(drawer):
		if not bool(bounty.get(DONE, false)):
			return false
	return true


## What is posted. The postings are the saved ones themselves, so counting a kill against one writes it
## into the drawer where it stands.
static func bounties(drawer: Dictionary) -> Array:
	var posted := _saved(drawer, BOUNTIES)
	for entry: Dictionary in posted:
		# A save from before a posting paid several holds one name, read as a list of one. An orb this
		# build no longer has is renamed by `Inventory.load_from`'s rule (`OrbTable.current`), and one
		# simply retired pays no orb.
		var saved_orbs: Variant = entry.get(ORB, [])
		if typeof(saved_orbs) != TYPE_ARRAY:
			saved_orbs = [] if str(saved_orbs).is_empty() else [str(saved_orbs)]
		var orbs := []
		for orb: Variant in saved_orbs:
			var name := OrbTable.current(str(orb))
			if OrbTable.ORBS.has(name):
				orbs.append(name)
		entry[ORB] = orbs
	return posted


## The player is standing at the board. Returns whether that is news, so the caller knows to save.
static func see(drawer: Dictionary) -> bool:
	if seen(drawer):
		return false
	drawer[SEEN] = true
	return true


static func seen(drawer: Dictionary) -> bool:
	return bool(drawer.get(SEEN, false))


## Whether any board anywhere has been read yet: there is no journal worth opening before.
static func any_seen(state: TownState) -> bool:
	for at: String in state.towns:
		if seen(state.towns[at]):
			return true
	return false


## Taken on and not yet handed in.
static func is_active(bounty: Dictionary) -> bool:
	return bool(bounty.get(ACCEPTED, false)) and not bool(bounty.get(DONE, false))


## The world spot (`TownState.key`) of the town whose posting the player is working on, or "" when no
## work is out.
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


## Takes a posting on. Refused while another is still out, finished or not: the last one is only over
## once it has been handed in.
static func accept(state: TownState, bounty: Dictionary) -> bool:
	if bool(bounty.get(DONE, false)) or not active(state).is_empty():
		return false
	bounty[ACCEPTED] = true
	return true


## Gives the work up: the posting goes back on its board unaccepted and its kills are lost. False when
## it was not out.
static func abandon(bounty: Dictionary) -> bool:
	if not is_active(bounty):
		return false
	bounty.erase(ACCEPTED)
	bounty[HAVE] = 0
	return true


## One body down, counted against the accepted bounty if it `takes` it, never past `need`. Returns
## whether anything moved, so the caller knows whether to save.
static func count_kill(state: TownState, enemy: String, times := 1, tile_level := -1) -> bool:
	var bounty := active(state)
	if not takes(bounty, enemy, tile_level):
		return false
	var need := int(bounty.get(NEED, 0))
	var have := int(bounty.get(HAVE, 0))
	bounty[HAVE] = mini(have + maxi(times, 0), need)
	return bounty[HAVE] != have


## Whether a posting wants this body at all: its monster, fallen on a tile at least as deep as its
## town. A `tile_level` of -1 is a caller with no tile to speak of, which is asked nothing.
static func takes(bounty: Dictionary, enemy: String, tile_level := -1) -> bool:
	if bounty.is_empty() or str(bounty.get(ENEMY, "")) != enemy:
		return false
	return tile_level == -1 or tile_level >= int(bounty.get(LEVEL, 0))


## Worked off and still waiting to be handed in.
static func ready(bounty: Dictionary) -> bool:
	return is_active(bounty) \
			and int(bounty.get(HAVE, 0)) >= int(bounty.get(NEED, 0))


## Hands a bounty in. False when it is not `ready`, and then nothing moves -- which is the whole of how
## a board pays out exactly once. The caller pays what the posting says.
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


static func _posting(enemy: String, tier: int, cell: Vector2i,
		rng: RandomNumberGenerator, walls: int, board := 1) -> Dictionary:
	var at := _at(board)
	var elite := tier == EnemyRoster.Tier.ELITE
	var need: int = TIER_NEED_ELITE[at] if elite else TIER_NEED_COMMON[at]
	var orbs := []
	for i in int(ORBS[tier]) + int(TIER_ORBS[at]):
		orbs.append(OrbTable.roll_favoured(rng, walls))
	return {
		ENEMY: enemy,
		NEED: need,
		HAVE: 0,
		GOLD: maxf(1.0, roundf(Encounter.gold_of(enemy, cell) * reward_of(tier) * float(TIER_PAY[at]))),
		XP: roundi(Encounter.xp_of(enemy, cell) * xp_reward_of(tier) * float(TIER_PAY[at])),
		ORB: orbs,
		ITEM: _item_promise(tier, rng, board),
		DONE: false,
		LEVEL: MapBuilder.level_of(cell),
	}


## What the card promises of a piece (`ITEM`), or `{}`. Drawn at posting so the card can say it; the
## piece is drawn at the hand-in.
static func _item_promise(tier: int, rng: RandomNumberGenerator, board := 1) -> Dictionary:
	var at := _at(board)
	if rng.randf() >= float(ITEM_CHANCE[tier]):
		return {}
	var plus := plus_of(rng.randf() / float(TIER_PLUS[at]))
	if rng.randf() < float(UNIQUE_CHANCE[tier][at]):
		return {ITEM_KIND: "", ITEM_RARITY: ItemRarity.name_of(ItemRarity.Rarity.UNIQUE), ITEM_PLUS: plus}
	var rarity := ItemRarity.Rarity.COMMON
	for i in int(RARITY_ROLLS[tier]) + int(TIER_RARITY_ROLLS[at]):
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


static func orbs_of(bounty: Dictionary) -> Array:
	var orbs: Variant = bounty.get(ORB, [])
	return orbs if typeof(orbs) == TYPE_ARRAY else []


## The piece a posting promises, read back whole or not at all: a kind this build has not got, or a
## rarity it cannot name, is no promise.
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


## The promise in words, for a tooltip: "an epic sword +1", "a unique item", "" for none.
static func reward_text(bounty: Dictionary) -> String:
	var promise := item_of(bounty)
	if promise.is_empty():
		return ""
	# The rarity as it is shown ("epic"), not as it is saved.
	var step := ItemRarity.from_name(str(promise[ITEM_RARITY]))
	var rarity := ItemRarity.label_of(step).to_lower() if step >= 0 else str(promise[ITEM_RARITY])
	var kind := str(promise[ITEM_KIND])
	var words := "%s %s" % [rarity, kind if not kind.is_empty() else "item"]
	var plus := int(promise[ITEM_PLUS])
	if plus > 0:
		words += " +%d" % plus
	# "an epic", "an uncommon" -- and "a unique", which is read with a consonant.
	return ("an " if rarity in ["epic", "uncommon"] else "a ") + words


## The piece a finished posting pays, rolled here and now, or null for a posting that promised none.
## Its level is the town's ceiling for the posting's tier, the better of two rolls, as a vendor's
## shelf is; a unique is any of `unlocked` (`Achievements.unlocked`), at that level. `rng` is the caller's.
static func reward_item(bounty: Dictionary, cell: Vector2i, rng: RandomNumberGenerator,
		unlocked: Array = Achievements.STARTERS) -> Item:
	var promise := item_of(bounty)
	if promise.is_empty():
		return null
	var rarity: ItemRarity.Rarity = ItemRarity.from_name(str(promise[ITEM_RARITY]))
	var enemy := str(bounty.get(ENEMY, ""))
	var tier := EnemyRoster.tier_of(enemy) if EnemyRoster.ENEMIES.has(enemy) else EnemyRoster.Tier.COMMON
	var level := VendorStock.roll_level(rarity, VendorStock.ceiling(cell, tier), rng)
	var item: Item
	if rarity == ItemRarity.Rarity.UNIQUE:
		item = _any_unique(unlocked, rng, level)
	else:
		# The card promised this kind, so it is paid in it: the town's tile level picks the material, and
		# a kind that begins past the plainest (the greaves) is lifted to its first.
		var kind := str(promise[ITEM_KIND])
		var material := maxi(MapBuilder.level_of(cell), LootTable.first_level(kind))
		item = Item.rolled(LootTable.tier_at(kind, material, rng), rarity, rng, level)
	for i in int(promise[ITEM_PLUS]):
		item.ascend()
	return item
