class_name Inventory
extends RefCounted
## Everything the player holds, the stats a fight is armed with, and the save, whose file's shape is
## `InventorySave`'s. Plain data with no nodes, and it never saves itself: the main scene owns it and
## says when, and the path is always a parameter.

const SAVE_PATH := "user://inventory.json"
## The save's shape. `InventorySave` lists what each step changed and reads every older one.
const VERSION := 35

## Loose items the bag holds (`capacity()` is what it holds now). Worn gear is outside it, so putting a
## piece on frees a square.
const CAPACITY := 40
## An overencumbered player's pace on the map, as a share of the usual.
const ENCUMBERED_SPEED := 0.5

## What an unnamed character is called, and the most letters a name keeps.
const DEFAULT_NAME := "Adventurer"
const NAME_MOST := 24

## Ids kept in `tips`, each once for the player: the first rune found (the bag's rune row stays once
## seen), the first skill point spent (until then the skills page's root breathes: the user's,
## 2026-10-10), and the promised Orb of Augmentation and skill node dropped (`promised`, `FightLedger`).
const FIRST_RUNE := "first_rune"
const FIRST_POINT := "first_skill_point"
const FIRST_AUGMENT := "had_augment"
const FIRST_NODE := "had_node"
## The first tile fight lost, the main scene's tip: Farm stands only from then on (the user's, 2026-10-29).
const FIRST_DEATH := "first_death"

## The starter uniques' numbers; the Novice's Cap stops paying at level `NOVICE_UNTIL`.
const SQUIRE_DAMAGE := 3.0
const COURIER_SPAWN := 30.0
const NOVICE_XP := 100.0
const NOVICE_UNTIL := 20

## What a point of each attribute is worth, in percent of the stat it names. Intelligence adds to
## `xp_more`, a percentage already; the other two multiply.
const ATTRIBUTE_PERCENT := 0.2
const ATTRIBUTE_GIVES := {"strength": "damage", "dexterity": "attack_speed", "intelligence": "xp_more"}
## An amulet's line of all three (`ModifierTable`'s `added_all_attributes`): read only in `_points`,
## counted as an attribute line, and erased from `stats()`.
const ALL_ATTRIBUTES := "all_attributes"
## What an attribute is followed by in the stat a helmet's line rolls for it: `strength_stones`, ranks
## more on every strength stone holding a point (`_tree`).
const SKILL_RANKS := "_stones"

## Rings a charted tile shows round it with no torch held; the Thick Fog takes all of it (`sight`).
const BASE_SIGHT := 2

## How close the Crown of Accord asks the three to be: the lowest against the highest. Every other
## number a unique reads here is its rank's (`_dial`, `UniqueTable`), so the card and the rule agree.
const ACCORD_WITHIN := 0.9
## What the lines a unique gains at rank IV are tuned by (`UniqueTable`'s `peak` says each in words).
const ACCORD_WITHIN_PEAK := 0.8   ## a fifth instead of a tenth, Crown of Accord
const ZEALOT_GIFT := 1.25         ## what each attribute's gift is multiplied by, Zealot's Brand
const SCHOLAR_CRIT := 10.0        ## intelligence a point of crit damage, Scholar's Circlet
const PACKMULE_ROOM := 20         ## pieces more the bag holds, Packmule's Harness
const SALVAGE_ORB := 0.05         ## of the pieces thrown away that leave an orb, Rag and Bone Sack
const PURIST_MODS := 1.25         ## what a pure piece's modifiers count for, Purist's Seal
const HOARD_DIGIT := 10.0         ## percent more damage a digit of the gold held, Hoardheart

## Pacifist Hands: swings a second the hands make on their own, before everything is doubled.
const PACIFIST_SWINGS := 1.5
const PACIFIST_FASTER := 2.0

## Gold changed hands: something was bought (any drop in the purse) or sold (`sell_for`).
signal traded
## Said at the end of every `save`, written or not: its listeners (the achievements' check, a fight
## armed again, the corner redrawn) follow the player as they are, which a refused write has not changed.
signal save_written

## The bag, in the order picked up. An index into it is how a piece is named, whatever the bag is
## sorted by (`order()`); what is worn is in `equipment`, never here.
var items: Array[Item] = []
var equipment := Equipment.new()

## Whether the Broken Sword, the player's first piece, and the first orb (`OrbTable.FIRST_ORB`) have
## dropped. Until then each is promised (`promised`).
var first_sword_taken := false
var first_orb_taken := false

## The first-time pop-ups already shown and the buttons already pressed once, by id. The main scene
## decides what they mean.
var tips: Array[String] = []

## The player's name for their character; empty is `DEFAULT_NAME` (`hero()` is what is shown).
var hero_name := ""

## The heroes bought (`Characters` ids; the first is everyone's and never listed) and the one the player
## is. Carried through a transcension, as the name is.
var owned_characters: Array[String] = []
var character := Characters.FIRST

## A whole number in a double, as every growing quantity is (`BigNumber`). Every drop in it is a
## purchase, and says so.
var gold := 0.0:
	set(value):
		var paid := value < gold
		gold = value
		if paid:
			traded.emit()

## Every enemy ever killed: what holds orbs and uniques back (`OrbTable.FIRST_ORB_KILLS`,
## `UniqueTable.FIRST_UNIQUE_KILLS`) and what a promised find is counted in (`promised`).
var kills := 0

## Seconds the game has been open on this save; the main scene adds each frame's delta.
var play_seconds := 0.0

## The next four are the player's, not the world's: each only ever rises, and `transcended()` carries it.
## Depths of the dungeon won, one a Gollux killed (`Encounter.cleared`): where the next descent begins.
var dungeon_depth := 0
## Every floor of the dungeon ever beaten in one go, counted from the top: the leaderboard's score
## (`Cloud.depth_and_floor` reads 44 as depth 3, floor 14).
var dungeon_floors := 0
## How far the land has ever reached, in steps from the middle, in any world (`reach`, `walls_ever`).
var farthest_land := MapBuilder.START_LAND_RADIUS
## The level of the deepest tile ever charted, in any world: a leaderboard's score (`chart`).
var deepest_level := 1

## Orbs and runes held, name -> how many (`OrbTable`, `RuneTable`). Counts, not items: outside
## `CAPACITY`, never autodiscarded or sorted.
var orbs := {}
var runes := {}
## What runes have done to this world's tiles, by world spot as "x,y" (the towns' key): each a
## `RuneTable` state.
var runed := {}

## `PlayerLevel` says what a level costs; every level past the first is a skill point (`Skills.earned`).
var level := 1
var xp := 0
var skills := Skills.new()

## What the settlements the player has walked into hold.
var towns := TownState.new()

## Every unique ever found, by `UniqueTable` id, in the order found: the collection log. Selling one
## takes nothing off it.
var uniques_found: Array[String] = []
## The found ones not yet hovered in the log: what makes its button and their squares shine.
var uniques_new: Array[String] = []
## The achievements earned, `Achievements` id -> the rank reached (1..`UniqueTable.PEAK`).
var achievements := {}
## The earned ones the achievements page has not been opened on since: what makes its button shine.
var achievements_new: Array[String] = []
## What the achievements count, key -> number (`Achievements` names the keys): lifetime sums, and the
## longest of each streak.
var tally := {}

## What the fortuneteller has sold that is the player's rather than a town's. A plain Dictionary whose
## keys are that class's, read through its statics: this file never names it (a test holds that).
var fortunes := {}

## The unix time of the last `save` that got there: what the main scene pays a camp from at start-up.
## 0 is owed nothing.
var saved_at := 0.0
## What the last `load_from` could not keep, by name; said in the log, since the next save writes it
## away. Never saved.
var lost: Array[String] = []

## The levels the player has told the game to stop bringing, elite included. A rule only filters what
## arrives (`leaves_behind`); what is already held is `discard_level`'s.
var autodiscard: Array[int] = []

## The heirlooms: a second inventory of which only `items` and `equipment` are used, worn as well as
## the ordinary doll. Read through `stash()`, which makes it: an Inventory that made one as it was made
## would never finish being made.
## ponytail: it shares CAPACITY, 40 heirlooms; one is made a transcension, and nobody transcends forty times.
var heirlooms: Inventory
## How many of this world's fallen walls have been counted (`credit_walls`): the curses' pay per wall.
var walls_credited := 0
## The curses this world is played under, by `Curses` id, until the next transcension.
var curses: Array[String] = []
## The ones chosen on the black screen for the world to come. **In memory only:** `transcended()` is
## what makes them the next world's.
var pending_curses: Array[String] = []
## The Homeland curse's two lands, by environment. Empty, and no land leaves gear, until the main scene
## chooses them once the new world's map exists (`_settle_homeland`).
var homeland: Array[String] = []
## Every unique first found in a Forgotten world, which counts twice in the log from then on
## (`collection_bonus`).
var uniques_doubled: Array[String] = []
## On the heirlooms only, set by `stash()` each time they are asked for and never saved: the most
## pieces their doll may wear (-1 for no limit; the Lone Heir's reach into an `Inventory` that knows no
## curses), and the player's own `Inventory`, so their Equip can count the attributes of both dolls. A
## `WeakRef`, or the two would keep each other alive.
var most_worn := -1
var keeper: WeakRef = null


## The finds of `Encounter.PROMISED` still owed, for the next fight: never had, and their kills not yet
## run out -- so a save from before a promise, already past its kills, gets nothing from it. The unique
## is owed while the collection log is empty, so one a chest or a bounty paid spends it. None after a
## transcension.
func promised() -> Array:
	if int(tally.get("transcended", 0)) > 0:
		return []
	var had := {
		Encounter.SWORD: first_sword_taken,
		Encounter.TRANSMUTE: first_orb_taken,
		Encounter.AUGMENT: FIRST_AUGMENT in tips,
		Encounter.UNIQUE: not uniques_found.is_empty(),
		Encounter.NODE: FIRST_NODE in tips,
	}
	return had.keys().filter(func(id: String) -> bool:
		return not had[id] and kills < int(Encounter.PROMISED[id][1]))


## Into the bag, full or not: past `capacity()` the player is `encumbered`, and nothing is destroyed.
func add(item: Item) -> void:
	items.append(item)


## How many of that piece are held, whatever their rarities.
func count(type: String) -> int:
	return items.filter(func(item: Item) -> bool: return item.type == type).size()


func total() -> int:
	return items.size()


## `CAPACITY`, the walls' squares (`WallUnlocks.bag_slots` of `walls_ever()`), and `PACKMULE_ROOM` more
## while a rank IV Packmule's Harness is worn on either doll. The heirlooms' stash keeps to `CAPACITY`.
func capacity() -> int:
	if keeper != null:
		return CAPACITY
	var room := CAPACITY + WallUnlocks.bag_slots(walls_ever())
	if "packmule" in effects() and _peak("packmule"):
		room += PACKMULE_ROOM
	return room


## How many steps from the charted land a tile can be charted (`MapBuilder.dark_reach`): 1, or the
## Nightwalkers' rank's while they are worn on either doll.
func dark_reach() -> int:
	return int(_dial("nightwalkers", "tiles")) if "nightwalker" in effects() else 1


func hero() -> String:
	return hero_name if not hero_name.is_empty() else DEFAULT_NAME


## Names the character `text`, trimmed and cut to `NAME_MOST`. False, and nothing changed, when that
## leaves nothing or the name it already has.
func rename(text: String) -> bool:
	var called := text.strip_edges().left(NAME_MOST)
	if called.is_empty() or called == hero_name:
		return false
	hero_name = called
	return true


func owns(id: String) -> bool:
	return id == Characters.FIRST or id in owned_characters


## Buys the hero `id`. False, and nothing changed, for one owned already or one the roster has not got.
func buy_character(id: String) -> bool:
	if not Characters.has(id) or owns(id):
		return false
	owned_characters.append(id)
	return true


## Makes `id` the hero the player is. False, and nothing changed, for one not owned or the one already.
func use_character(id: String) -> bool:
	if not owns(id) or id == character:
		return false
	character = id
	return true


func room_left() -> int:
	return maxi(0, capacity() - items.size())


func is_full() -> bool:
	return items.size() >= capacity()


## Over the cap: slow on the map, and no fight can be started until the bag is back down to it.
func encumbered() -> bool:
	return items.size() > capacity()


## Whether Farm stands: once a tile fight has been lost, or on a save that farmed before it waited for one.
func farm_unlocked() -> bool:
	return FIRST_DEATH in tips or "first_farm" in tips


## The order the bag is read in, as indices into `items`: level, highest first, then rarity, best
## first, then newest first. `held` (Item -> rarity) sorts a piece by the rarity it had then, so one an
## orb has just lifted stays where it was until the bag sorts afresh (`BagPage`).
func order(held := {}) -> Array[int]:
	var by: Array[int] = []
	by.assign(range(items.size()))
	by.sort_custom(func(a: int, b: int) -> bool:
		if items[a].level != items[b].level:
			return items[a].level > items[b].level
		var ra: int = held.get(items[a], items[a].rarity)
		var rb: int = held.get(items[b], items[b].rarity)
		if ra != rb:
			return ra > rb
		return a > b)
	return by


func autodiscards(level: int) -> bool:
	return autodiscard.has(level)


## Whether a find is left behind as it drops (`CombatScene._on_loot_dropped`): its level's rule, or
## once the sixth wall has opened it (`WallUnlocks.FILTER`) the loot filter's (`Settings.filter_*`).
## Never a unique nor a capstone, which the rarity says alike. A skill stone answers to the rarity
## alone: it has no material, and its level is not what it is worth.
func leaves_behind(item: Item) -> bool:
	if item.rarity == ItemRarity.Rarity.UNIQUE:
		return false
	if autodiscards(item.level):
		return true
	if not WallUnlocks.has(walls_ever(), WallUnlocks.FILTER):
		return false
	if item.rarity < Settings.filter_rarity:
		return true
	if item.is_stone():
		return false
	if item.level < Settings.filter_level or (Settings.filter_ascended and item.plus < 1):
		return true
	var materials: Array = LootTable.KINDS[LootTable.kind_of(item.type)]["tiers"]
	return materials.size() > 1 and int(LootTable.ITEMS[item.type]["material"]) < Settings.filter_material


func set_autodiscard(level: int, on: bool) -> void:
	if on and not autodiscard.has(level):
		autodiscard.append(level)
	elif not on:
		autodiscard.erase(level)


## Throws away everything held at one level but what the player has locked, and hands back what went,
## oldest first. With `uniques` false a unique stays: the bag page asks about those on their own. Given
## a `slot` (`LootTable.slot_of`) only that slot's pieces go: a bin takes only what the bag's filter shows.
func discard_level(level: int, uniques := true, slot := "") -> Array[Item]:
	var gone: Array[Item] = []
	for i in range(items.size() - 1, -1, -1):
		var item := items[i]
		# A capstone is spared with the uniques: the rarity says it, where `unique` would not.
		if item.level == level and not item.locked \
				and (uniques or item.rarity != ItemRarity.Rarity.UNIQUE) \
				and (slot.is_empty() or LootTable.slot_of(item.type) == slot):
			gone.append(item)
			items.remove_at(i)
	gone.reverse()
	return gone


## Every level the bag has a section for, highest first: one that holds something, or one that only
## carries a rule -- a rule with no heading would have nowhere left to be turned off.
func levels() -> Array[int]:
	var found: Array[int] = []
	for item in items:
		if not found.has(item.level):
			found.append(item.level)
	for level in autodiscard:
		if not found.has(level):
			found.append(level)
	found.sort()
	found.reverse()
	return found


func count_at(level: int) -> int:
	return items.filter(func(item: Item) -> bool: return item.level == level).size()


## Takes one piece out of the bag. False when it was not in it.
func remove(item: Item) -> bool:
	var at := items.find(item)
	if at < 0:
		return false
	items.remove_at(at)
	return true


func can_equip(item: Item, socket: Equipment.Socket) -> bool:
	return why_not_equip(item, socket).is_empty()


## Why `item` cannot go on at `socket`, or "" where it can: it does not fit, the bag has no room for
## what comes off, this doll is at `most_worn` and the press would add a piece rather than swap one, or
## the player is short of the attribute it asks for (`LootTable.requirement`).
func why_not_equip(item: Item, socket: Equipment.Socket) -> String:
	if not Equipment.fits(socket, item):
		return "It does not go there"
	var displaced := equipment.displaced_by(socket, item)
	var off := displaced.size()
	# One leaves the bag for each coming back, but a two-hander takes the offhand's piece off as well.
	# A bag already over the cap may still swap one for one.
	if items.size() - 1 + off > maxi(capacity(), items.size()):
		return "The bag is full"
	if most_worn >= 0 and equipment.worn.size() - off + 1 > most_worn:
		return "Lone Heir: only one heirloom may be worn"
	var needs := LootTable.requirement(item.type, item.level)
	if not needs.is_empty():
		var player: Inventory = self if keeper == null else keeper.get_ref()
		if player == null:
			player = self
		if not player._needs_waived(displaced) and player.points_without(displaced)[needs[0]] < needs[1]:
			return "Needs %d %s" % [needs[1], LootTable.STAT_LABELS[needs[0]]]
	return ""


## The Giant's Leafwrap, and the Patchwork Coat at rank IV: while one stays worn, on either doll, through
## the swap (it is not in `off`), any piece may be worn whatever attribute it asks for.
func _needs_waived(off: Array[Item]) -> bool:
	var coat := _peak("patchwork_coat")
	for piece: Item in equipment.items() + stash().equipment.items():
		var effect := UniqueTable.effect_of(piece.unique)
		if not piece in off and (effect == "leafwrap" or (coat and piece.unique == "patchwork_coat")):
			return true
	return false


## How many digits the gold held is written with: 0 for none, 1 up to 9, 2 up to 99. Divided down rather
## than by a logarithm, which reads 1000 as 2.9999.
func gold_digits() -> int:
	var digits := 0
	var left := gold
	while left >= 1.0:
		left /= 10.0
		digits += 1
	return digits


## `attributes()` as they would be with `off` taken off whichever doll wears them: what a piece's
## requirement is met by, since what the swap takes off cannot hold it up (the user's ruling,
## 2026-09-28). Both dolls' sockets are swapped for trimmed copies, `attributes()` read -- so the Crown,
## the Brand and the Echo count as they would -- and put back before anything else can run.
func points_without(off: Array[Item]) -> Dictionary:
	var dolls: Array[Equipment] = [equipment, stash().equipment]
	var kept := dolls.map(func(doll: Equipment) -> Dictionary: return doll.worn)
	for doll in dolls:
		doll.worn = doll.worn.duplicate()
		for piece in off:
			doll.worn.erase(doll.worn.find_key(piece))
	var points := attributes()
	for index in dolls.size():
		dolls[index].worn = kept[index]
	return points


## Takes `item` out of the bag and puts it on, and drops whatever it displaced back into the bag: one
## step, so a piece is never in both places or in neither. Refused, nothing moves at all.
func equip(item: Item, socket: Equipment.Socket) -> bool:
	if not can_equip(item, socket) or not remove(item):
		return false
	for displaced: Item in equipment.equip(socket, item):
		items.append(displaced)
	return true


## Takes the socket's piece off and puts it back in the bag. False if the socket was empty, or the bag
## is full: taking a piece off grows it, and a bag over the cap stops the player fighting.
func unequip(socket: Equipment.Socket) -> bool:
	if is_full():
		return false
	var removed := equipment.unequip(socket)
	if removed == null:
		return false
	items.append(removed)
	return true


func add_orb(orb: String, count := 1) -> void:
	if OrbTable.ORBS.has(orb) and count > 0:
		orbs[orb] = orb_count(orb) + count


func add_rune(rune: String, count := 1) -> void:
	if RuneTable.has(rune) and count > 0:
		runes[rune] = rune_count(rune) + count
		if FIRST_RUNE not in tips:
			tips.append(FIRST_RUNE)


func rune_count(rune: String) -> int:
	return int(runes.get(rune, 0))


## The rune work on the tile at world `spot`, the very Dictionary kept here so a change to it is the
## save's: a fresh one, kept, for a tile with none yet.
func rune_state(spot: Vector2i) -> Dictionary:
	var key := _spot_key(spot)
	if not runed.has(key):
		runed[key] = RuneTable.fresh()
	return runed[key]


## The rune work on the tile at world `spot` to read: a fresh one -- not kept -- for a tile with none.
func rune_work(spot: Vector2i) -> Dictionary:
	return runed.get(_spot_key(spot), RuneTable.fresh())


func has_runes(spot: Vector2i) -> bool:
	return runed.has(_spot_key(spot))


static func _spot_key(spot: Vector2i) -> String:
	return "%d,%d" % [spot.x, spot.y]


## Spends one `rune` on the tile at world `spot`, which carries `own` modifiers of its own. Whether it
## did anything; nothing is spent when it would not.
func use_rune(rune: String, spot: Vector2i, own: Array, rng := RandomNumberGenerator.new()) -> bool:
	# Asked of the work as read first, so a rune refused leaves no empty record on the tile.
	return rune_count(rune) > 0 and RuneTable.can_apply(rune, own, rune_work(spot)) \
			and RuneTable.apply(rune, own, rune_state(spot), rng) and _spend(runes, rune)


func orb_count(orb: String) -> int:
	return int(orbs.get(orb, 0))


## One orb spent. False, and nothing moved, when there was none to spend.
func spend_orb(orb: String) -> bool:
	return _spend(orbs, orb)


## One of `which` out of a name -> count Dictionary. Erased rather than left at zero, so the save holds
## what is carried and not everything ever found and used up.
static func _spend(counts: Dictionary, which: String) -> bool:
	var held := int(counts.get(which, 0))
	if held <= 0:
		return false
	if held == 1:
		counts.erase(which)
	else:
		counts[which] = held - 1
	return true


## Banks `amount` experience and returns how many levels that paid for.
func add_xp(amount: int) -> int:
	var after := PlayerLevel.add(level, xp, amount)
	level = after["level"]
	xp = after["xp"]
	return after["gained"]


## What the player is worth in a fight: both dolls' gear (`Equipment.totals`' `also`) with the skills
## folded in, and what the uniques and the curses ask on top.
##
## **A stat is the player's, so whatever reads one reads all sixteen pieces. A count is its own
## side's** (`_side_count`) -- **but the attributes** (the user's ruling, 2026-09-27), which are added
## over both dolls (`attributes`), and with them the attribute lines the Patchwork Coat counts and the
## pieces without one the Purist's Seal does. The attributes written into the result are the counted
## ones, Crown, Brand and Echo done, so the fight and the character page read those.
func stats() -> Dictionary:
	var worn := effects()
	var dolls := _counted_dolls(worn)
	var tree := _tree(worn, dolls)
	var points := attributes(worn, dolls, tree)
	var worth := skill_worth(worn, points)
	var flat := _skills_worth(skills.flat(tree[0], tree[1]), worth)
	var percent := _skills_worth(skills.percent(tree[0], tree[1]), worth)
	# What a unique turns into a flat goes in with the skills', so the percents scale it like any other
	# point. The Spiked Helm's is a share of the set's armour, which takes adding the set up once to read.
	if "spikes" in worn:
		var armour := float(dolls[0].totals(flat, percent, dolls[1]).get("armor", 0.0))
		_add(flat, "damage", armour * _dial("spiked_helm", "share") / 100.0)
	# The attribute uniques' flats. One on each doll counts twice.
	var turned := {
		"damage": points["strength"] * _dial("ogres_knuckle", "share") / 100.0 * worn.count("ogre")
				+ SQUIRE_DAMAGE * worn.count("squire"),
		"time_on_hit": points["dexterity"] / _dial("fencers_signet", "dexterity") * worn.count("fencer"),
		"bleed": points["strength"] / _dial("butchers_cleaver", "strength") * worn.count("butcher"),
		"spawn_speed": points["dexterity"] * _dial("quickdraw_boots", "times") * worn.count("quickdraw")
				+ COURIER_SPAWN * worn.count("courier"),
	}
	# At IV the Fencer's Signet adds the dexterity to dodge and the Scholar's Circlet the intelligence
	# to crit damage, the same way.
	if "fencer" in worn and _peak("fencers_signet"):
		turned["dodge"] = points["dexterity"] * worn.count("fencer")
	if "scholar" in worn and _peak("scholars_circlet"):
		turned["crit_damage"] = points["intelligence"] / SCHOLAR_CRIT * worn.count("scholar")
	for stat: String in turned:
		if turned[stat] > 0.0:
			_add(flat, stat, turned[stat])
	var out := dolls[0].totals(flat, percent, dolls[1])
	# Already in each of the three (`points`), which are written in below.
	out.erase(ALL_ATTRIBUTES)
	out["bare_sockets"] = _side_count("ascetic",
			func(side: Inventory) -> int: return Equipment.NAMES.size() - side.equipment.worn.size())
	out["bag_pieces"] = _side_count("packmule", func(side: Inventory) -> int: return side.items.size())
	# The Patchwork Coat's count and the Purist's Seal's, over all sixteen pieces.
	out["attribute_lines"] = 0
	out["pure_pieces"] = 0
	for piece: Item in equipment.items() + stash().equipment.items():
		var lines := _attribute_lines(piece)
		out["attribute_lines"] += lines
		out["pure_pieces"] += int(lines == 0)
	# The collection log's share is a multiplier of its own, over what gear and skills made.
	_scale(out, "damage", collection_bonus())
	# The Hoardheart: one on each doll counts twice. Read as the stats are, so a purse picked up mid-fight
	# counts from the next save's rearm.
	if "hoard" in worn:
		_scale(out, "damage", HOARD_DIGIT * gold_digits() * worn.count("hoard"))
	for attribute: String in ATTRIBUTE_GIVES:
		if points[attribute] <= 0.0:
			out.erase(attribute)
			continue
		out[attribute] = points[attribute]
		var gift := attribute_gift(attribute, points[attribute], worn)
		if gift[0] == "xp_more":
			_add(out, "xp_more", gift[1])
		else:
			_scale(out, gift[0], gift[1])
	# The Quickdraw Boots at IV: Spawn Speed past 100%, which the walk-in has no more use for, is a
	# percent of attack speed a point.
	if "quickdraw" in worn and _peak("quickdraw_boots"):
		var past := float(out.get("spawn_speed", 0.0)) - 100.0
		if past > 0.0:
			_scale(out, "attack_speed", past)
	# The Novice's Cap: experience, until the player has outgrown it.
	if level < NOVICE_UNTIL and "novice" in worn:
		_add(out, "xp_more", NOVICE_XP * worn.count("novice"))
	# Pacifist Hands: the hands swing for themselves, and then everything that swings swings faster.
	if Curses.PACIFIST_HANDS in curses:
		out["attack_speed"] = (float(out.get("attack_speed", 0.0)) + PACIFIST_SWINGS) * PACIFIST_FASTER
	# What the world's curses pay in numbers, added like any other percent of that kind.
	for curse: String in curses:
		var pays: Dictionary = Curses.CURSES[curse].get("stats", {})
		for stat: String in pays:
			_add(out, stat, float(pays[stat]))
	# A wall-paying curse's damage for every wall down in this world, one multiplier for all of them.
	_scale(out, "damage", Curses.wall_damage(curses) * walls_credited)
	return out


static func _add(sums: Dictionary, stat: String, amount: float) -> void:
	sums[stat] = float(sums.get(stat, 0.0)) + amount


## `percent` more of a `stat` the sums hold; a percent of one they do not hold is nothing.
static func _scale(sums: Dictionary, stat: String, percent: float) -> void:
	if sums.has(stat):
		sums[stat] = float(sums[stat]) * (1.0 + percent / 100.0)


## The percent `points` of an attribute add to what it gives (`ATTRIBUTE_GIVES`).
static func attribute_bonus(points: float) -> float:
	return maxf(0.0, points) * ATTRIBUTE_PERCENT


## What `points` of `attribute` add, as [the stat, the percent]: `ATTRIBUTE_GIVES`' stat at
## `attribute_bonus`, but intelligence gives damage at its rank's times under the Scholar's Circlet --
## and all of it a quarter more under the Zealot's Brand at IV.
func attribute_gift(attribute: String, points: float, worn := effects()) -> Array:
	var gift := [ATTRIBUTE_GIVES[attribute], attribute_bonus(points)]
	if attribute == "intelligence" and "scholar" in worn:
		gift = ["damage", attribute_bonus(points) * _dial("scholars_circlet", "times")]
	if "zealot" in worn and _peak("zealots_brand"):
		gift[1] = float(gift[1]) * ZEALOT_GIFT
	return gift


## How far the player sees from a tile they have just taken: `BASE_SIGHT` rings, none under the Thick
## Fog, and whatever a torch adds. The map's and the character page's one answer.
func sight() -> int:
	return (0 if Curses.THICK_FOG in curses else BASE_SIGHT) + int(stats().get("sight", 0))


## The three attributes as the gear itself adds them up over both dolls, before any unique counts them
## again: what an achievement that asks for an attribute reads (the user's ruling, 2026-09-29).
func gear_attributes() -> Dictionary:
	return _attribute_sums(equipment, stash().equipment)


## The three attributes two dolls add up to, none below nothing.
static func _attribute_sums(doll: Equipment, other: Equipment) -> Dictionary:
	var sums := doll.totals({}, {}, other)
	var out := {}
	for attribute: String in ATTRIBUTE_GIVES:
		out[attribute] = maxf(0.0, _points(sums, attribute))
	return out


## One attribute out of a doll's totals: its own lines and the lines of all three.
static func _points(totals: Dictionary, attribute: String) -> float:
	return float(totals.get(attribute, 0.0)) + float(totals.get(ALL_ATTRIBUTES, 0.0))


## The three attributes as everything that reads one counts them, **in this order**: added up over both
## dolls like any stat (the user's ruling) with the skill tree's (`Skills.attributes`: here, never at
## `skill_worth`, which the Abacus reads them to work out); then the heirlooms' doll's again for every
## Heirloom's Echo, to its rank's times over; then the Crown of Accord's test of those sums; and the
## Zealot's Brand last, so it can take what the Crown gave. The dolls are the counted ones
## (`_counted_dolls`), so an heirloom the Echo at IV lifts a plus lifts its attribute lines with it.
## `stats` hands over what it has already worked out; anyone else asks with nothing.
func attributes(worn := effects(), dolls := _counted_dolls(worn), tree := _tree(worn, dolls)) -> Dictionary:
	var out := _attribute_sums(dolls[0], dolls[1])
	var grown := skills.attributes(tree[0], tree[1])
	for attribute: String in out:
		out[attribute] += float(grown[attribute])
	if "echo" in worn:
		var echo := dolls[1].totals()
		var again := (_dial("heirlooms_echo", "times") - 1.0) * worn.count("echo")
		for attribute: String in out:
			out[attribute] = maxf(0.0, out[attribute] + _points(echo, attribute) * again)
	var high: float = out.values().max()
	# The Crown of Accord at IV lets them stand further apart.
	var within := ACCORD_WITHIN_PEAK if _peak("crown_of_accord") else ACCORD_WITHIN
	if "accord" in worn and high > 0.0 and out.values().min() >= high * within:
		for attribute: String in out:
			out[attribute] *= 1.0 + (_dial("crown_of_accord", "times") - 1.0) * worn.count("accord")
	# The Zealot's Brand brings the two lower up to its rank's times the highest (the user's,
	# 2026-09-29). One on each doll counts twice, as every attribute unique does.
	if "zealot" in worn:
		var high_now: float = out.values().max()
		var top: String = out.find_key(high_now)
		for attribute: String in out:
			if attribute != top:
				out[attribute] = high_now * _dial("zealots_brand", "times") * worn.count("zealot")
	return out


## What a stone's rank is worth against what it carries: double under Hard Lessons, half again under the
## Specialist, and a percent more for every so much intelligence (its rank's) under each Sage's Abacus.
func skill_worth(worn := effects(), points := {}) -> float:
	var worth := 1.0 + (1.0 if Curses.HARD_LESSONS in curses else 0.0) \
			+ (0.5 if Curses.SPECIALIST in curses else 0.0)
	var abaci := worn.count("abacus")
	if abaci > 0:
		if points.is_empty():
			points = attributes(worn)
		worth *= 1.0 + abaci * float(points["intelligence"]) / _dial("sages_abacus", "intelligence") / 100.0
	return worth


## Why a point cannot go into the stone at `path`, or "" where it can: the tree's own rules, and before
## them the Specialist's -- only one of the root's branches may hold points, the root on none of them.
func why_not_skill(path: String) -> String:
	if Curses.SPECIALIST in curses and not path.is_empty():
		for held: String in skills.ranks:
			if not held.is_empty() and SkillTree.branch_of(held) != SkillTree.branch_of(path):
				return "Specialist: only one branch may hold points"
	return skills.why_not(path, level)


func rank_up_skill(path: String) -> bool:
	if not why_not_skill(path).is_empty() or not skills.rank_up(path, level):
		return false
	if FIRST_POINT not in tips:
		tips.append(FIRST_POINT)
	return true


## What the tree is told on top of its own ranks: [ranks more on every stone holding a point -- the
## Sage's Abacus at IV -- and attribute -> ranks more on the stones of that base, a helmet's line on
## either doll (`<attribute>_stones`)].
func _tree(worn := effects(), dolls := _counted_dolls(worn)) -> Array:
	var extra := 1 if "abacus" in worn and _peak("sages_abacus") else 0
	var gear := dolls[0].totals({}, {}, dolls[1])
	var bases := {}
	for attribute: String in ATTRIBUTE_GIVES:
		bases[attribute] = roundi(float(gear.get(attribute + SKILL_RANKS, 0.0)))
	return [extra, bases]


## Puts a stone from the bag into the tree at `path` (the black screen's, `TranscendPage`); what that
## takes out of the tree goes into the bag, where the new world will not keep it. Refused, and nothing
## moves, when the stone is not in the bag or may not stand there.
func place_stone(stone: Item, path: String) -> bool:
	if not items.has(stone) or not SkillTree.can_place(stone, path, skills.stones):
		return false
	items.erase(stone)
	items.append_array(skills.place(stone, path))
	return true


## What the learned skills add up to at `skill_worth`, as a copy: the capstones' effects are not
## numbers and are not doubled.
func _skills_worth(sums: Dictionary, worth := skill_worth()) -> Dictionary:
	var out := {}
	for stat: String in sums:
		out[stat] = float(sums[stat]) * worth
	return out


## What a unique that counts something is told: `count` of every side -- this inventory, the
## heirlooms -- whose own doll wears `effect`, added up. With it on neither doll this is the ordinary
## side's count, which nothing reads.
func _side_count(effect: String, count: Callable) -> int:
	var total := 0
	var asked := false
	for side: Inventory in [self, stash()]:
		if effect in side.equipment.effects():
			total += int(count.call(side))
			asked = true
	return total if asked else int(count.call(self))


## What throwing `item` away pays: nothing, unless the Rag and Bone Sack is worn -- on either doll,
## and for an heirloom thrown away as much as for a find -- and then its rank's share of a trader's.
func salvage(item: Item) -> float:
	if not "salvage" in effects():
		return 0.0
	return TownPrices.salvage_price(item, _dial("rag_and_bone_sack", "share") / 100.0)


## The Rag and Bone Sack at rank IV: now and then a piece thrown away leaves an orb as well -- "" when
## it does not. Paid in the same four places as `salvage`.
func salvage_orb(rng := RandomNumberGenerator.new()) -> String:
	if not ("salvage" in effects() and _peak("rag_and_bone_sack")) or rng.randf() >= SALVAGE_ORB:
		return ""
	return OrbTable.roll("", rng, true, 0.0, walls_ever())


## One of a unique's numbers at the rank the player has of it (`Achievements.rank`), rank I for one
## worn and not yet earned -- an old save's find.
func _dial(id: String, key: String) -> float:
	return UniqueTable.dial(id, key, maxi(1, Achievements.rank(self, id)))


## Whether the player has `id` at rank IV, where it gains its last line (`UniqueTable.peak_text`).
## Asked beside whether it is worn, never instead of it.
func _peak(id: String) -> bool:
	return Achievements.rank(self, id) >= UniqueTable.PEAK


## How many of `piece`'s modifiers are attribute lines: the Patchwork Coat's count, and none makes it
## the Purist's Seal's pure piece.
static func _attribute_lines(piece: Item) -> int:
	return piece.mods.filter(func(mod: Dictionary) -> bool:
			var stat: String = ModifierTable.MODS.get(mod["id"], {}).get("stat", "")
			return ATTRIBUTE_GIVES.has(stat) or stat == ALL_ATTRIBUTES).size()


## The two dolls as their totals are read: themselves -- or, while a rank IV Heirloom's Echo or
## Purist's Seal is worn, copies of them with every heirloom one plus higher (`Item.ascend`) and every
## pure piece's modifiers `PURIST_MODS` over. Copies, so nothing the player holds is changed by being
## counted.
func _counted_dolls(worn := effects()) -> Array[Equipment]:
	var echo := "echo" in worn and _peak("heirlooms_echo")
	var purist := "purist" in worn and _peak("purists_seal")
	var dolls: Array[Equipment] = [equipment, stash().equipment]
	if not echo and not purist:
		return dolls
	var counted: Array[Equipment] = []
	for side in dolls.size():
		var copy := Equipment.new()
		for socket: Equipment.Socket in dolls[side].worn:
			var piece := Item.from_dict(dolls[side].worn[socket].to_dict())
			if piece == null:
				continue
			if echo and side == 1:
				piece.ascend()
			if purist and _attribute_lines(piece) == 0:
				for mod in piece.mods:
					mod["value"] = int(roundf(float(mod["value"]) * PURIST_MODS))
			copy.worn[socket] = piece
		counted.append(copy)
	return counted


## What the collection log adds to the player's damage, in percent: `UniqueTable.COLLECTION_DAMAGE`
## for every unique found, whether or not it is still owned.
func collection_bonus() -> int:
	if Curses.FORGOTTEN in curses:
		return 0
	return (uniques_found.size() + uniques_doubled.size()) * UniqueTable.COLLECTION_DAMAGE


## What changes how a fight plays rather than a number: the capstones learned, the uniques worn on each
## doll, the curses and the Homeland's lands, as one list of effect ids for `Encounter.effects`.
func effects() -> Array:
	return skills.effects() + equipment.effects() + stash().equipment.effects() \
			+ curses.map(Curses.effect) \
			+ homeland.map(func(env: String) -> String: return Curses.HOME_PREFIX + env)


func stash() -> Inventory:
	if heirlooms == null:
		heirlooms = Inventory.new()
	heirlooms.most_worn = 1 if Curses.LONE_HEIR in curses else -1
	heirlooms.keeper = weakref(self)
	return heirlooms


## `fallen` is how many walls are down in this world. Every one not yet counted is, so a wall falling
## and an old save's walls are the same sum. True when one was.
func credit_walls(fallen: int) -> bool:
	if fallen <= walls_credited:
		return false
	# Thaw counts every wall ever broken, in every world, where this world's count starts again.
	tick("walls", fallen - walls_credited)
	walls_credited = fallen
	return true


## The land has reached `radius` in this world: remembered if it is the furthest it has reached in any.
## Whether that was news.
func reach(radius: int) -> bool:
	if radius <= farthest_land:
		return false
	farthest_land = radius
	# A wall broken deeper than any before may have grown the skill tree's root.
	SkillTree.root_slots = WallUnlocks.root_branches(walls_ever())
	return true


## The deepest ice wall ever broken, in any world: how far the land has ever reached, in whole wall
## steps from where it starts (so a Ring of Walls' half walls count by the land they opened). What every
## wall's unlock reads (`WallUnlocks`), and Into the Dark's figure.
func walls_ever() -> int:
	return maxi(0, (farthest_land - MapBuilder.START_LAND_RADIUS) / MapBuilder.WALL_STEP)


## A tile of land level `level` is charted: remembered if it is the deepest in any world. Whether that
## was news.
func chart(level: int) -> bool:
	if level <= deepest_level:
		return false
	deepest_level = level
	return true


## Every whole heirloom under the level of the deepest land charted climbs to it, a smith's level at a
## time (`Item.level_up`, so its lines climb back towards their peak tiers too), and never past the
## level it had before its world ended (`Item.safe_level`). True when one moved.
func raise_heirlooms(land_level: int) -> bool:
	var moved := false
	for piece: Item in stash().items + stash().equipment.items():
		while not piece.broken and piece.level < mini(piece.safe_level, land_level):
			piece.level_up()
			moved = true
	return moved


## The skulls the black screen may spend on the next world (`Curses.fits`). **Only Gollux pays them**
## (the user's, 2026-10-03: walls broken pay none): one a depth won, kept through every transcension.
func skull_allowance() -> int:
	return dungeon_depth


## Whether `item` can be made an heirloom: a piece the player holds or wears, not a broken one, and
## never a skill stone (the heirlooms' doll has no socket for one). **How many may be made is
## `TranscendPage`'s to count.**
func can_make_heirloom(item: Item) -> bool:
	return item != null and not item.broken and not item.is_stone() \
			and (items.has(item) or equipment.items().has(item))


## The piece leaves the bag, or comes straight off the doll without passing through the bag -- so a
## full bag is no obstacle -- and lies in the heirlooms' stash. It is not put on for the player, and
## it never comes back.
func make_heirloom(item: Item) -> bool:
	if not can_make_heirloom(item):
		return false
	if not remove(item):
		equipment.unequip(equipment.worn.find_key(item))
	# The Lone Heir's pay: the heirloom made at the end of a world played under it is made +1.
	if Curses.LONE_HEIR in curses:
		item.ascend()
	stash().items.append(item)
	return true


## What is left of the player when the world is left behind: what the player knows and has done (the
## log, the achievements, the tips, the name, the heroes, the kills and the clock, and what the dungeon and the land
## reached), the skill tree, and the heirlooms, each gone through
## `Item.transcend`. The kills, with both first finds read as taken, keep a second world from handing
## out the first one's promises again. Everything else is a fresh start.
func transcended() -> Inventory:
	var next := Inventory.new()
	next.tips = tips.duplicate()
	next.hero_name = hero_name
	next.owned_characters = owned_characters.duplicate()
	next.character = character
	next.uniques_found = uniques_found.duplicate()
	next.uniques_new = uniques_new.duplicate()
	next.uniques_doubled = uniques_doubled.duplicate()
	next.achievements = achievements.duplicate()
	next.achievements_new = achievements_new.duplicate()
	next.tally = tally.duplicate()
	next.tick("transcended")
	next.kills = kills
	next.play_seconds = play_seconds
	next.dungeon_depth = dungeon_depth
	next.dungeon_floors = dungeon_floors
	next.farthest_land = farthest_land
	next.deepest_level = deepest_level
	next.first_sword_taken = true
	next.first_orb_taken = true
	# The skill tree, as it was built on the black screen; its points were this world's.
	next.skills = Skills.from_dict(skills.tree_dict(), {}, 1)
	# What was chosen on the black screen is the new world's, and the old world's curses end with it.
	next.curses = Curses.known(pending_curses)
	if Curses.THICK_FOG in next.curses:
		next.items.append(Item.rolled(LootTable.BROKEN_TORCH, ItemRarity.Rarity.COMMON,
				RandomNumberGenerator.new()))
	# Copies, through the save's own shape: this inventory is untouched, so a caller whose write
	# fails is still holding the heirlooms as they were.
	for item in stash().items:
		next.stash().items.append(Item.from_dict(item.to_dict()))
	next.stash().equipment = Equipment.from_dict(stash().equipment.to_dict())
	# The Lone Heir's world begins with the heirlooms' doll bare, so which one is worn is chosen.
	if Curses.LONE_HEIR in next.curses:
		for socket: Equipment.Socket in next.stash().equipment.worn.keys():
			next.stash().items.append(next.stash().equipment.unequip(socket))
	for item: Item in next.stash().items + next.stash().equipment.items():
		item.transcend()
	return next


## Writes a unique into the collection log. Returns whether it was new.
func note_unique(id: String) -> bool:
	if not UniqueTable.UNIQUES.has(id) or uniques_found.has(id):
		return false
	uniques_found.append(id)
	uniques_new.append(id)
	if Curses.FORGOTTEN in curses:
		uniques_doubled.append(id)
	return true


## A sale's takings into the purse. Gold that comes any other way (a fight, a camp, a bounty) is
## added straight on and says nothing.
func sell_for(price: float) -> void:
	gold += price
	traded.emit()


## What giving back every point in the tree would cost now.
func respec_cost() -> float:
	return SkillTree.respec_cost(level, skills.spent())


## Gives back every point in the tree, paid for out of the purse. Refused when there is nothing to give
## back or the purse cannot cover it, and then nothing changes.
func respec() -> bool:
	var cost := respec_cost()
	if skills.spent() <= 0 or gold < cost:
		return false
	gold -= cost
	skills.reset()
	return true


## `n` more of `key` in the achievements' `tally`.
func tick(key: String, n := 1) -> void:
	tally[key] = int(tally.get(key, 0)) + n


## Keeps the larger of what `key` holds in the `tally` and `value`: whole, an int while it fits one and
## a float past it (gold held), so a figure reads back from the save as it was written.
func keep_best(key: String, value: float) -> void:
	var best := floorf(maxf(maxf(float(tally.get(key, 0)), value), 0.0))
	if best < 9e18:
		tally[key] = int(best)
	else:
		tally[key] = best


func total_orbs() -> int:
	var total := 0
	for orb: String in orbs:
		total += int(orbs[orb])
	return total


## Writes the inventory to `path`, whole or not at all (`InventorySave.write`), and returns whether it
## got there. `saved_at` is stamped only where it did; `save_written` is said either way.
func save(path := SAVE_PATH) -> bool:
	var stamp := Time.get_unix_time_from_system()
	var written := InventorySave.write(self, path, stamp)
	if written:
		saved_at = stamp
	save_written.emit()
	return written


## The inventory in `path`, or an empty one when there isn't a usable file there. A missing file is a
## first run and leaves `problem` empty. A file that is there and cannot be honoured also comes back
## empty, with the reason appended to `problem`: the caller must then **never save**, because the first
## write would replace everything the player owns with nothing (`MapSave.load_from`'s rule too).
static func load_from(path := SAVE_PATH, problem: Array = []) -> Inventory:
	return InventorySave.read(path, problem)


## A saved count read back as a whole number, or 0 where a hand-edited file holds anything else. This
## and `_flag` are `Item.from_dict`'s and `InventorySave`'s too.
static func _whole(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0


## A saved flag read back, or `otherwise` where a hand-edited file holds anything but one.
static func _flag(value: Variant, otherwise := false) -> bool:
	return bool(value) if typeof(value) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT] else otherwise
