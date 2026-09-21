class_name Inventory
extends RefCounted
## Everything the player has picked up, and the file it is kept in.
##
## A plain data object with no nodes: it holds items and reads and writes its own JSON, and that is
## all. It never saves itself -- the main scene owns it and decides when to write, which keeps the
## rules tests off the disk and the save policy a one-line change.
##
## Items do not stack. Each one rolled its own rarity and its own modifiers, so two Wooden Swords are
## two different swords and this is a list, not a tally.
##
## The save is the first file this game keeps. It has to survive being missing, half-written, edited
## by hand or written by a build that no longer exists, because a bad save must never be the reason
## the game won't start.
##
## The bag has a bottom to it: CAPACITY loose items. Nothing is ever destroyed to keep to it -- a drop
## into a full bag goes in anyway and leaves the player overencumbered (`encumbered`): slow on the
## map and unable to start a fight until the bag is cleared back down.

const SAVE_PATH := "user://inventory.json"
## 1 was the tally of names this kept before items had rarities. 2 is the list of items. 3 adds what
## the player is wearing, which is a second list rather than a flag on an item: a piece is either in
## the bag or in a socket, never both, so there is nothing to keep in step. 4 gives every item its
## level and the stats it rolled at that level, which is what makes a piece the same piece on every
## load: before this its numbers were looked up from the tables and moved whenever they were tuned.
## A version 3 save still reads -- its pieces come back at level 1 carrying the tables unscaled,
## which is exactly what they were worth when it was written. 5 adds the autodiscard rules, which a
## version 4 save simply has none of -- an absent key and an empty list read the same, the way
## version 3's `equipped` did. 6 adds the purse, which a version 5 save simply has none of and comes
## back from empty-handed -- which is exactly what every bag had until gold was a thing at all. 7
## adds the orbs, which are counts and not items, and which a version 6 save has none of for the same
## reason it has no gold: they did not exist when it was written. 8 adds the player's level and the
## experience held towards the next one; a version 7 save comes back at level 1 with none. 9 adds the
## skills, which a version 8 save has none of -- it comes back with every level's point unspent. 10
## adds the towns the player has walked into, which a version 9 save simply has none of: an absent key
## and no town visited read the same, the way version 4's `autodiscard` did. 11 adds the uniques the
## player has ever found, the collection log's list; a version 10 save has found none. 12 adds what
## the fortuneteller has sold the player (`fortunes`); a version 11 save has bought nothing. 13 adds
## `first_sword_taken`; a version 12 save is already under way, so it reads as taken. The same version
## drops `first_elite_taken`, which the sword's flag now does the work of; an older save's is ignored.
## 14 adds the heirlooms -- a second stash and a second doll under `heirlooms` -- with
## `heirloom_picks` and `walls_credited`; a version 13 save has none, and the main scene's first
## `credit_walls` pays it a pick for every wall it had already brought down. 15 makes the picks
## `super_orbs` -- a wall pays an orb now, and an heirloom is made at transcension, one a world -- and
## a version 14 save's unspent picks are read as that many orbs. 16 adds `play_seconds`, the time
## the game has been open on this save; a version 15 save has none counted and starts from nothing.
## 17 adds `camp`, the tile the hero is resting on and what that rest earns an hour; a version 16
## save is simply not camped anywhere. 18 adds `curses`, what the player took on at the last
## transcension; a version 17 save is a world under none. 19 adds `skill_sunk` and `skill_transcends`,
## what transcending the skill trees took and how often it has been done; a version 18 save has done
## neither.
## 20 adds what two of the curses have to remember: `homeland`, the two lands that still leave gear,
## and `uniques_doubled`, the finds a Forgotten world made count twice; a version 19 save has neither.
## 21 adds `skull_budget`; a version 20 save has none, and earns it at its next transcension.
const VERSION := 21

## How many loose items the bag holds. Worn gear is *not* in this: a piece is in the bag or in a
## socket and never both, so putting a piece on frees a square, which is the whole reason the cap is
## a pressure to choose rather than a pressure to hoard nothing.
const CAPACITY := 40

## How fast an overencumbered player walks the map, as a share of their usual pace.
const ENCUMBERED_SPEED := 0.5

## The Spiked Helm: how much of the set's armour is added to its damage.
const SPIKES_SHARE := 0.01

## What is held, in the order it was picked up. The panel does not show it in this order -- `order()`
## does that -- and nothing outside here should: an index into this array is how a piece is named,
## and it stays the same piece however the bag is sorted. What is *worn* is not in here at all --
## `equipment` has it.
var items: Array[Item] = []

## What the player has on. Owned here so that one load and one save carry the whole of what the
## player has, and the main scene never has to remember there are two files' worth of state.
var equipment := Equipment.new()

## Whether the Broken Sword, the player's first piece of gear, has dropped. Until it has, the first
## elite is promised a drop. It lives in the save, so it is once for the player.
var first_sword_taken := false

## The first-time pop-ups already shown, and the buttons already pressed once, by id. The main scene
## decides what they mean; this only keeps them, so each is once for the player rather than per launch.
var tips: Array[String] = []

## What the player has earned. Not in the bag and not against its cap: a purse is a number rather
## than a thing, so it never weighs the bag down. It lives
## here rather than beside the map because it is carried, not explored. A whole number in a double,
## for the reason every growing quantity is one (`BigNumber`): a purse climbs exponentially with the
## walk and would pass int64 out past the two hundredth hex.
var gold := 0.0

## Every enemy the player has ever killed. It is what holds orbs back until `OrbTable.FIRST_ORB_KILLS`,
## and uniques until `UniqueTable.FIRST_UNIQUE_KILLS`.
var kills := 0

## How long the game has been open on this save, in seconds. The main scene adds each frame's delta;
## it is written whenever anything else is, so a quit loses the seconds since the last save. Carried
## through a transcension, like the kills: it is the player's time, not the world's.
var play_seconds := 0.0

## What currency the player is holding: orb name -> how many. Counts rather than objects, because an
## orb has nothing to tell apart -- two Orbs of Chaos are the same orb, which is exactly what gear
## stopped being when it started rolling modifiers.
##
## Like the purse and unlike the bag: outside CAPACITY, never filtered by an autodiscard rule and
## never sorted into a level section. A count weighs nothing, so it never overencumbers anybody.
var orbs := {}

## The player's level and the experience held towards the next one -- `PlayerLevel` says what a level
## costs. Kept here beside the purse for the purse's reason: it is carried, not explored. Every level
## past the first is a skill point (`Skills.earned`).
var level := 1
var xp := 0

## What the player has learned with the points their level earned. Saved here beside the level for
## the level's reason, and because the points are counted off it.
var skills := Skills.new()

## What the settlements the player has walked into hold. Here rather than beside the map because a
## town's shelf and the purse that empties it move together, and one save is one write.
var towns := TownState.new()

## Every unique the player has ever found, by `UniqueTable` id, in the order they were found. What the
## collection log lights up -- and found is found: selling one takes nothing off this list.
var uniques_found: Array[String] = []
## The found ones the player has not hovered in the log yet: what makes its button and their squares shine.
var uniques_new: Array[String] = []

## What the fortuneteller has sold that belongs to the player rather than to a town: the chest the
## star points at, the uniques she has shown, whether the scour is spent. A plain Dictionary whose
## keys are `FortuneTeller`'s, read through its accessors -- this file never names that class.
var fortunes := {}

## The camp the hero is holding, if any: where it stands, when it was made and what it earns a
## second, as `Camp.make` built it. A plain dictionary read through `Camp`'s statics, the way
## `fortunes` is read through `FortuneTeller`'s -- what is in it is the camp's business, not the
## bag's, and naming `Camp` here is what the cycle checker would bite.
var camp := {}

## The levels the player has told the game to stop bringing. Levels rather than items, because a
## level is what a section of the bag is, and rarity is not consulted: a marked level is done with,
## elite included. A rule only ever filters what *arrives* -- what is already held is cleared by
## `discard_level`, which is a separate button for a separate act.
var autodiscard: Array[int] = []

## The heirlooms: a second inventory of which only `items` and `equipment` are ever used -- its own
## stash and its own doll, worn as well as the ordinary one -- and the one thing that goes with the
## player when the world is left behind (`transcended`). Read through `stash()`, which makes it: an
## Inventory that made one of these as it was made would never finish being made.
## ponytail: it shares CAPACITY, 40 heirlooms; one is made a transcension, and nobody transcends forty times.
var heirlooms: Inventory
## Super orbs the player may still spend at a transcension (`SuperOrbTable`): one for every wall
## broken, in any world, less those spent. One count for all six, spent on whichever is pressed.
var super_orbs := 0
## How many of this world's fallen walls have paid their orb (`credit_walls`).
var walls_credited := 0
## The curses this world is played under, by `Curses` id: what the player chose on the way in, and
## theirs until the next transcension. The fight hears of them through `effects()`, the numbers they
## pay are added by `stats()`.
var curses: Array[String] = []
## How many skulls of curses the player may take into a new world (`Curses.fits`). Raised at every
## transcension to this world's depth plus the skulls carried into it (`skulls_earned`), and never lowered.
var skull_budget := 0
## The ones chosen on the black screen for the world to come. **In memory only**, like everything
## `TranscendPage` does: `transcended()` is what makes them the next world's.
var pending_curses: Array[String] = []
## The Homeland curse's two lands, by environment: the one the world starts on and one other. The
## main scene chooses them once the new world's map exists (`_settle_homeland`), which is the first
## moment anybody knows what the start stands on; until then there are none and no land leaves gear.
var homeland: Array[String] = []
## Every unique first found in a Forgotten world, which counts twice in the log from then on
## (`collection_bonus`). It only grows, and it goes with the player like the log itself.
var uniques_doubled: Array[String] = []
## The most pieces this doll may wear, or -1 for no limit. Never saved and never the player's own:
## `stash()` sets it on the heirlooms each time they are asked for, which is how the Lone Heir
## reaches a second `Inventory` that knows nothing of curses.
var most_worn := -1

## Pacifist Hands: swings a second the hands make on their own, before everything is doubled.
const PACIFIST_SWINGS := 1.5
const PACIFIST_FASTER := 2.0


## Puts `item` in the bag, full or not. Past CAPACITY the player is overencumbered (`encumbered`)
## rather than anything being destroyed, which is what the warning in a fight with a full bag says.
func add(item: Item) -> void:
	items.append(item)


## How many of that piece are held, whatever their rarities.
func count(type: String) -> int:
	var held := 0
	for item in items:
		if item.type == type:
			held += 1
	return held


func total() -> int:
	return items.size()


## How many more loose items fit. Never negative, even for a bag over the cap.
func room_left() -> int:
	return maxi(0, CAPACITY - items.size())


func is_full() -> bool:
	return items.size() >= CAPACITY


## Over the cap: slow on the map, and no fight can be started until the bag is back down to it.
func encumbered() -> bool:
	return items.size() > CAPACITY


## The order the bag is read in: by level, highest first, and inside a level by rarity, best first,
## and inside a rarity newest first -- because the thing just picked up is the thing being looked
## for. Given as indices into `items`, so whoever is holding one (the open stat block) goes on
## holding the same piece across a refresh.
func order() -> Array[int]:
	var by := _indices()
	by.sort_custom(func(a: int, b: int) -> bool:
		if items[a].level != items[b].level:
			return items[a].level > items[b].level
		if items[a].rarity != items[b].rarity:
			return items[a].rarity > items[b].rarity
		return a > b)
	return by


func _indices() -> Array[int]:
	var by: Array[int] = []
	for i in items.size():
		by.append(i)
	return by


## Whether finds at this level are thrown away as they land.
func autodiscards(level: int) -> bool:
	return autodiscard.has(level)


## Turns the rule for a level on or off. It touches nothing already held -- a rule is about what
## arrives, and `discard_level` is the button beside it for what is there.
func set_autodiscard(level: int, on: bool) -> void:
	if on and not autodiscard.has(level):
		autodiscard.append(level)
	elif not on:
		autodiscard.erase(level)


## Throws away everything held at one level, and hands back what went, oldest first.
func discard_level(level: int) -> Array[Item]:
	var gone: Array[Item] = []
	for i in range(items.size() - 1, -1, -1):
		if items[i].level == level:
			gone.append(items[i])
			items.remove_at(i)
	gone.reverse()
	return gone


## Every level the bag has a section for, highest first: one that holds something, or one that
## carries a rule and holds nothing. The second is not an edge case to tidy away -- a rule with no
## heading would be a rule with nowhere left to turn it off.
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


## How many are held at one level.
func count_at(level: int) -> int:
	var held := 0
	for item in items:
		if item.level == level:
			held += 1
	return held


## Takes one piece out of the bag -- a discard or a sale. False when it was not in the bag.
func remove(item: Item) -> bool:
	var at := items.find(item)
	if at < 0:
		return false
	items.remove_at(at)
	return true


## Whether `item` would go into `socket` at all: it has to fit, and the bag has to hold everything
## that comes off. One piece leaving the bag makes room for one coming back, which is why a swap
## never needed a guard -- but a greatsword takes the offhand's piece off as well, and two coming
## back into a full bag would push it over the cap. A bag already over it may still swap one for one.
func can_equip(item: Item, socket: Equipment.Socket) -> bool:
	return why_not_equip(item, socket).is_empty()


## Why `item` cannot go on at `socket`, or "" where it can: it does not fit, the bag has no room for
## what comes off, or this doll is at `most_worn` and the press would add a piece rather than swap one.
func why_not_equip(item: Item, socket: Equipment.Socket) -> String:
	if not Equipment.fits(socket, item):
		return "It does not go there"
	var off := equipment.displaced_by(socket, item).size()
	if items.size() - 1 + off > maxi(CAPACITY, items.size()):
		return "The bag is full"
	if most_worn >= 0 and equipment.worn.size() - off + 1 > most_worn:
		return "Lone Heir: only one heirloom may be worn"
	return ""


## Takes `item` out of the bag and puts it on, and drops whatever it displaced back into the bag.
##
## The two halves move together here rather than at the call site, because the one thing that must
## never happen is a piece being in both places or in neither -- and every caller getting that right
## separately is the same bug waiting in as many places as there are callers. Refused, nothing moves
## at all: the piece is still in the bag and the sockets are as they were.
func equip(item: Item, socket: Equipment.Socket) -> bool:
	if not can_equip(item, socket) or not remove(item):
		return false
	for displaced: Item in equipment.equip(socket, item):
		items.append(displaced)
	return true


## Takes the socket's piece off and puts it back in the bag. False if the socket was empty, and
## false if the bag is full.
##
## Taking a piece off grows the bag, so it has to refuse: going over the cap here would stop the
## player fighting for the sake of a piece they only wanted a closer look at, which is a trap. `equip` refuses for the
## same reason and by the same arithmetic (`can_equip`): one going on usually pays for the one coming
## off, but a two-hander takes two off for one.
func unequip(socket: Equipment.Socket) -> bool:
	if is_full():
		return false
	var removed := equipment.unequip(socket)
	if removed == null:
		return false
	items.append(removed)
	return true


## One orb found. Nothing can refuse it -- there is no cap to hit and no rule that filters it -- so
## unlike `add` this returns nothing: there is never anything destroyed to report.
func add_orb(orb: String, count := 1) -> void:
	if not OrbTable.ORBS.has(orb) or count <= 0:
		return
	orbs[orb] = orb_count(orb) + count


## How many of one orb are held. Zero for an orb never found, which is the tray's third state and
## has to be an ordinary answer rather than a missing key every caller checks for.
func orb_count(orb: String) -> int:
	return int(orbs.get(orb, 0))


## One orb spent. False when there was none to spend, in which case nothing moved -- so a caller can
## apply first and spend second without a piece ever being crafted for free.
func spend_orb(orb: String) -> bool:
	var held := orb_count(orb)
	if held <= 0:
		return false
	if held == 1:
		# Erased rather than left at zero, so the save holds what is carried and not a list of every
		# orb ever found and used up.
		orbs.erase(orb)
	else:
		orbs[orb] = held - 1
	return true


## Banks `amount` experience, levelling up as many times as it pays for. Returns how many levels that
## was, which is almost always none.
func add_xp(amount: int) -> int:
	var after := PlayerLevel.add(level, xp, amount)
	level = after["level"]
	xp = after["xp"]
	return after["gained"]


## What the player is worth in a fight: what they wear, with what they have learned folded in. The one
## question the fight asks, so the rule for how the two combine lives in one place.
##
## Three things a unique asks of it ride along. The Spiked Helm turns a hundredth of the set's armour
## into flat damage, which has to go in with the skills' flat so the percents scale it like any other
## point -- so the set is added up once to read its armour and once more with that in. And two counts
## the fight has no way to see: the sockets with nothing in them and the pieces in the bag.
##
## The heirlooms' doll is worn as well (`Equipment.totals`' `also`). **A stat is the player's, so
## whatever reads one reads all sixteen pieces** -- the helm's armour is. **A count is its own
## side's:** the Ascetic's Cord counts the bare places on the doll it hangs from, and the Packmule's
## Harness the loose pieces beside the doll it is strapped to, so one on each doll counts both and
## one on the heirlooms' says nothing of the ordinary bag.
func stats() -> Dictionary:
	var flat := _skills_worth(skills.flat())
	var percent := _skills_worth(skills.percent())
	var other := stash().equipment
	if "spikes" in effects():
		var armour := float(equipment.totals(flat, percent, other).get("armor", 0.0))
		flat["damage"] = float(flat.get("damage", 0.0)) + armour * SPIKES_SHARE
	var out := equipment.totals(flat, percent, other)
	out["bare_sockets"] = _side_count("ascetic",
			func(side: Inventory) -> int: return Equipment.NAMES.size() - side.equipment.worn.size())
	out["bag_pieces"] = _side_count("packmule", func(side: Inventory) -> int: return side.items.size())
	# The collection log's share, on its own the way the skills' percent is: it multiplies what gear
	# and skills made rather than adding to either.
	if out.has("damage"):
		out["damage"] = float(out["damage"]) * (1.0 + collection_bonus() / 100.0)
	# Pacifist Hands: the hands swing for themselves, and then everything that swings swings faster.
	if Curses.PACIFIST_HANDS in curses:
		out["attack_speed"] = (float(out.get("attack_speed", 0.0)) + PACIFIST_SWINGS) * PACIFIST_FASTER
	# What the world's curses pay in numbers, added like any other percent of that kind.
	for curse: String in curses:
		var pays: Dictionary = Curses.CURSES[curse].get("stats", {})
		for stat: String in pays:
			out[stat] = float(out.get(stat, 0.0)) + float(pays[stat])
	return out


## What one skill point is worth against what the tree says: double under Hard Lessons. A whole
## number, because a skill's card writes it by describing that many points (`SkillCard.fill`).
func skill_worth() -> float:
	return 1.0 + (1.0 if Curses.HARD_LESSONS in curses else 0.0) \
			+ (0.5 if Curses.SPECIALIST in curses else 0.0)


## Why a point cannot go into skill `id`, or "" where it can: the trees' own rules, and before them
## the Specialist's -- only one tree may hold points. The skills page asks here, never `skills`.
func why_not_skill(id: String) -> String:
	if Curses.SPECIALIST in curses:
		for tree: String in SkillTree.trees():
			if tree != SkillTree.tree_of(id) and skills.spent(tree) > 0:
				return "Specialist: only one skill tree may hold points"
	return skills.why_not(id, level)


func rank_up_skill(id: String) -> bool:
	return why_not_skill(id).is_empty() and skills.rank_up(id, level)


## What the learned skills add up to at `skill_worth`, as a copy: the capstones' effects are not
## numbers and are not doubled.
func _skills_worth(sums: Dictionary) -> Dictionary:
	var out := {}
	for stat: String in sums:
		out[stat] = float(sums[stat]) * skill_worth()
	return out


## What a unique that counts something is told: `count` of every side -- this inventory, the
## heirlooms -- whose own doll wears `effect`, added up. With it on neither doll this is the ordinary
## side's count, which is what the figure has always been and nothing reads.
func _side_count(effect: String, count: Callable) -> int:
	var total := 0
	var asked := false
	for side: Inventory in [self, stash()]:
		if effect in side.equipment.effects():
			total += int(count.call(side))
			asked = true
	return total if asked else int(count.call(self))


## What throwing `item` away pays: nothing, unless the Rag and Bone Sack is worn -- on either doll,
## and for an heirloom thrown away as much as for a find.
func salvage(item: Item) -> float:
	return TownPrices.salvage_price(item) if "salvage" in effects() else 0.0


## What the collection log adds to the player's damage, in percent: `UniqueTable.COLLECTION_DAMAGE`
## for every unique found, whether or not it is still owned.
func collection_bonus() -> int:
	if Curses.FORGOTTEN in curses:
		return 0
	return (uniques_found.size() + uniques_doubled.size()) * UniqueTable.COLLECTION_DAMAGE


## What changes how a fight plays rather than a number: the capstones learned and the uniques worn,
## as one list of effect ids for `Encounter.effects`. Each doll answers for itself, which is what
## keeps a Pilgrim's set inside one doll: a home piece on each is two lone pieces.
func effects() -> Array:
	return skills.effects() + equipment.effects() + stash().equipment.effects() \
			+ curses.map(Curses.effect) \
			+ homeland.map(func(env: String) -> String: return Curses.HOME_PREFIX + env)


## The heirlooms, made the first time they are asked for.
func stash() -> Inventory:
	if heirlooms == null:
		heirlooms = Inventory.new()
	heirlooms.most_worn = 1 if Curses.LONE_HEIR in curses else -1
	return heirlooms


## `fallen` is how many walls are down in this world. Every one not yet paid for pays a super orb, so
## a wall falling and a save from before there were heirlooms are the same sum. True when it paid.
func credit_walls(fallen: int) -> bool:
	if fallen <= walls_credited:
		return false
	# The Long Winter's pay: a wall twice as hard is worth two.
	# No Second Chances pays one more, and the two add: three a wall under both.
	super_orbs += (fallen - walls_credited) * (1 + int(Curses.LONG_WINTER in curses)
			+ int(Curses.NO_SECOND_CHANCES in curses))
	walls_credited = fallen
	return true


## The budget the next world is given: this world's depth -- walls broken, counted in ordinary walls
## of `MapBuilder.WALL_STEP` rings, so the Ring of Walls' twice as many count as many as they reach --
## plus the skulls carried into it, or the budget as it was if that is more. **A world lost to No
## Second Chances raises nothing** (`lost`): the gamble is all or nothing, the user's ruling.
func skulls_earned(lost := false) -> int:
	if lost:
		return skull_budget
	var step := MapBuilder.RING_OF_WALLS_STEP if Curses.RING_OF_WALLS in curses else MapBuilder.WALL_STEP
	var depth := walls_credited * step / MapBuilder.WALL_STEP
	return maxi(skull_budget, depth + Curses.skulls_of(curses))


## Where `item` is worn on the ordinary doll, or -1.
func _socket_of(item: Item) -> int:
	for socket: Equipment.Socket in equipment.worn:
		if equipment.worn[socket] == item:
			return socket
	return -1


## Whether `item` can be made an heirloom: a piece the player holds or wears, and not a broken one.
## **How many may be made is not this file's business:** one a transcension, which is
## `TranscendPage`'s to count, because that is the only place one is made.
func can_make_heirloom(item: Item) -> bool:
	return item != null and not item.broken and (items.has(item) or _socket_of(item) >= 0)


## The piece leaves the bag, or comes straight off the doll without passing through the bag -- so a
## full bag is no obstacle -- and lies in the heirlooms' stash. It is not put on for the player, and
## it never comes back.
func make_heirloom(item: Item) -> bool:
	if not can_make_heirloom(item):
		return false
	if not remove(item):
		equipment.unequip(_socket_of(item))
	# The Lone Heir's pay: the heirloom made at the end of a world played under it is made +1.
	if Curses.LONE_HEIR in curses:
		item.ascend()
	stash().items.append(item)
	return true


## What is left of the player when the world is left behind: the heirlooms, each gone through
## `Item.transcend`, the super orbs not yet spent, and what the player *knows* -- the collection log, the
## tips already read, and the kills, which with `first_sword_taken` is what keeps a second world from
## handing out the first one's helping hands again, and the skull budget, raised by this world unless it
## was `lost` (`skulls_earned`). Everything else is a fresh start.
func transcended(lost := false) -> Inventory:
	var next := Inventory.new()
	next.tips = tips.duplicate()
	next.uniques_found = uniques_found.duplicate()
	next.uniques_new = uniques_new.duplicate()
	next.uniques_doubled = uniques_doubled.duplicate()
	next.kills = kills
	next.play_seconds = play_seconds
	next.first_sword_taken = true
	next.super_orbs = super_orbs
	next.skull_budget = skulls_earned(lost)
	# The skill trees' transcensions go with the player; the points they took were this world's level.
	next.skills.transcended = skills.transcended
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


## What resetting `tree` would cost now.
func respec_cost(tree: String) -> float:
	return SkillTree.respec_cost(level, skills.spent(tree))


## Gives back every point in `tree`, paid for out of the purse. Refused when there is nothing to give
## back or the purse cannot cover it, and then nothing changes.
func respec(tree: String) -> bool:
	var cost := respec_cost(tree)
	if skills.spent(tree) <= 0 or gold < cost:
		return false
	gold -= cost
	skills.reset(tree)
	return true


## Every orb held, counted together.
func total_orbs() -> int:
	var total := 0
	for orb: String in orbs:
		total += int(orbs[orb])
	return total


## Writes the inventory to `path`, whole or not at all (`SafeFile`). Returns whether it got there; a
## failed write is worth a warning but never worth stopping play for.
func save(path := SAVE_PATH) -> bool:
	var saved := []
	for item in items:
		saved.append(item.to_dict())
	var kept := []
	for item in stash().items:
		kept.append(item.to_dict())
	# Indented, so the save can be read and edited by a person.
	return SafeFile.write(path, JSON.stringify({
		"version": VERSION,
		"first_sword_taken": first_sword_taken,
		"tips": tips,
		"gold": gold,
		"kills": kills,
		"play_seconds": play_seconds,
		"level": level,
		"xp": xp,
		"skills": skills.to_dict(),
		"skill_sunk": skills.sunk,
		"skill_transcends": skills.transcended,
		"towns": towns.to_dict(),
		"orbs": orbs,
		"items": saved,
		"equipped": equipment.to_dict(),
		"autodiscard": autodiscard,
		"uniques_found": uniques_found,
		"uniques_new": uniques_new,
		"fortunes": fortunes,
		"camp": camp,
		"heirlooms": {"items": kept, "equipped": stash().equipment.to_dict()},
		"super_orbs": super_orbs,
		"walls_credited": walls_credited,
		"curses": curses,
		"skull_budget": skull_budget,
		"homeland": homeland,
		"uniques_doubled": uniques_doubled,
	},"\t"))


## The inventory in `path`, or an empty one when there isn't a usable file there. A missing file is a
## first run and leaves `problem` empty. A file that is there and cannot be honoured -- unreadable,
## unparseable, the wrong shape, from a newer build -- also comes back empty, with the reason appended
## to `problem`: the caller must then **never save**, because the first write would replace everything
## the player owns with nothing. The same rule as `MapSave.load_from`, and an Array for its reason.
static func load_from(path := SAVE_PATH, problem: Array = []) -> Inventory:
	var inventory := Inventory.new()
	SafeFile.recover(path)
	if not FileAccess.file_exists(path):
		return inventory
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		problem.append("it cannot be read")
		return inventory
	# A JSON instance rather than JSON.parse_string, which pushes an engine error of its own.
	var reader := JSON.new()
	if reader.parse(text) != OK or typeof(reader.data) != TYPE_DICTIONARY:
		problem.append("it is not a save file")
		return inventory
	var data: Dictionary = reader.data
	inventory.first_sword_taken = bool(data.get("first_sword_taken", true))
	var seen: Variant = data.get("tips", [])
	if typeof(seen) == TYPE_ARRAY:
		for tip: Variant in seen:
			inventory.tips.append(str(tip))
	var version := int(data.get("version", 1))
	if version > VERSION:
		# A save from a newer build. Guessing at a shape never seen is how a save gets eaten; leaving
		# it alone means the build that wrote it can still read it.
		problem.append("it was written by a newer version of the game (%d)" % version)
		return Inventory.new()
	if version < 2:
		inventory._read_v1(data)
		return inventory
	var saved: Variant = data.get("items", [])
	if typeof(saved) != TYPE_ARRAY:
		problem.append("it has no list of items")
		return Inventory.new()
	for entry: Variant in saved:
		var item := Item.from_dict(entry)
		if item != null:
			inventory.items.append(item)
	# Version 2 knew nothing about wearing anything, so its whole save is bag and the player starts
	# with bare hands. There is nothing to convert: `equipped` is simply absent, and an absent key
	# and an empty set read the same.
	inventory.equipment = Equipment.from_dict(data.get("equipped", {}))
	# Version 4 knew nothing about a rule, and an absent key reads as no rules -- which is what every
	# bag had until now. Anything that is not a number is stepped over rather than guessed at.
	var rules: Variant = data.get("autodiscard", [])
	if typeof(rules) == TYPE_ARRAY:
		for level: Variant in rules:
			if typeof(level) in [TYPE_INT, TYPE_FLOAT]:
				inventory.set_autodiscard(int(level), true)
	# Version 5 knew nothing about gold, and an absent key reads as none -- the way `autodiscard`
	# did. Anything that is not a number is stepped over rather than guessed at, and a negative purse
	# in a hand-edited file comes back as nothing rather than as a debt.
	var purse: Variant = data.get("gold", 0)
	if typeof(purse) in [TYPE_INT, TYPE_FLOAT]:
		inventory.gold = maxf(0.0, float(purse))
	var killed: Variant = data.get("kills", 0)
	if typeof(killed) in [TYPE_INT, TYPE_FLOAT]:
		inventory.kills = maxi(0, int(killed))
	# Version 15 knew nothing about the clock: an absent key is a save that has played no time yet.
	var played: Variant = data.get("play_seconds", 0.0)
	if typeof(played) in [TYPE_INT, TYPE_FLOAT]:
		inventory.play_seconds = maxf(0.0, float(played))
	# Version 7 knew nothing about levels: an absent key reads as a fresh level 1. A level below 1 or
	# experience below nothing in a hand-edited file is clamped rather than guessed at, and experience
	# already worth a level is paid out, so the file comes back obeying the curve.
	var saved_level: Variant = data.get("level", 1)
	var saved_xp: Variant = data.get("xp", 0)
	inventory.level = maxi(1, int(saved_level)) if typeof(saved_level) in [TYPE_INT, TYPE_FLOAT] else 1
	inventory.add_xp(maxi(0, int(saved_xp)) if typeof(saved_xp) in [TYPE_INT, TYPE_FLOAT] else 0)
	# Version 8 knew nothing about skills: an absent key is nothing learned. Read after the level,
	# because what a save may have spent is counted off it.
	# Version 18 knew nothing about transcending the trees: absent keys are none done.
	inventory.skills = Skills.from_dict(data.get("skills", {}), inventory.level,
			_whole(data.get("skill_sunk", 0)), _whole(data.get("skill_transcends", 0)))
	# Version 9 knew nothing about towns, and an absent key reads as no settlement walked into yet --
	# which is what every save had before there was anything in one to do.
	inventory.towns = TownState.from_dict(data.get("towns", {}))
	# Version 6 knew nothing about orbs, and an absent key reads as none. An orb this build no longer
	# has is dropped rather than kept as a name nothing can draw -- the same pruning by name that
	# Item.from_dict does to a retired piece, and the reason orbs are saved by name at all. The one
	# exception is Alteration, whose job Transmutation took over: its count is Transmutation's now.
	var currency: Variant = data.get("orbs", {})
	if typeof(currency) == TYPE_DICTIONARY:
		for orb: Variant in currency:
			var named := "Orb of Transmutation" if str(orb) == "Orb of Alteration" else str(orb)
			if not OrbTable.ORBS.has(named):
				continue
			var held: Variant = currency[orb]
			if typeof(held) in [TYPE_INT, TYPE_FLOAT]:
				inventory.add_orb(named, maxi(0, int(held)))
	# Version 10 knew nothing about uniques: an absent key is none found. An id this build no longer
	# has is dropped by name, the way a retired orb is.
	var found: Variant = data.get("uniques_found", [])
	if typeof(found) == TYPE_ARRAY:
		for id: Variant in found:
			inventory.note_unique(str(id))
	# Absent in an older save: nothing is new. Only what is also found counts.
	inventory.uniques_new.clear()
	var unseen: Variant = data.get("uniques_new", [])
	if typeof(unseen) == TYPE_ARRAY:
		for id: Variant in unseen:
			if inventory.uniques_found.has(str(id)):
				inventory.uniques_new.append(str(id))
	# Version 11 knew nothing about the fortuneteller: an absent key is nothing bought.
	var told: Variant = data.get("fortunes", {})
	if typeof(told) == TYPE_DICTIONARY:
		inventory.fortunes = told
	# Version 16 knew nothing about camping: an absent key is a hero who is not resting anywhere.
	var resting: Variant = data.get("camp", {})
	if typeof(resting) == TYPE_DICTIONARY:
		inventory.camp = resting
	# Version 13 knew nothing about heirlooms: absent keys are none kept, no pick owed and no wall
	# paid for -- which is what lets `credit_walls` pay an old save for the walls it has down.
	var heir: Variant = data.get("heirlooms", {})
	if typeof(heir) == TYPE_DICTIONARY:
		var kept: Variant = heir.get("items", [])
		if typeof(kept) == TYPE_ARRAY:
			for entry: Variant in kept:
				var item := Item.from_dict(entry)
				if item != null:
					inventory.stash().items.append(item)
		inventory.stash().equipment = Equipment.from_dict(heir.get("equipped", {}))
	# Version 14 called them picks and spent them on making heirlooms; what is left of them are orbs.
	inventory.super_orbs = maxi(0, int(data.get("super_orbs", data.get("heirloom_picks", 0))))
	inventory.walls_credited = maxi(0, int(data.get("walls_credited", 0)))
	# Version 17 knew nothing about curses: an absent key is a world under none. One this build no
	# longer has is dropped by name, the way a retired orb is.
	var cursed: Variant = data.get("curses", [])
	if typeof(cursed) == TYPE_ARRAY:
		inventory.curses = Curses.known(cursed)
	inventory.skull_budget = maxi(0, int(data.get("skull_budget", 0)))
	# Version 19 knew nothing of either: no land chosen, no find counted twice. A name that is not a
	# unique's is dropped, and one that is not a land's simply never matches a fight's.
	for entry: Variant in _strings(data.get("homeland", [])):
		inventory.homeland.append(entry)
	for entry: Variant in _strings(data.get("uniques_doubled", [])):
		if UniqueTable.UNIQUES.has(entry) and not inventory.uniques_doubled.has(entry):
			inventory.uniques_doubled.append(entry)
	return inventory


## The strings in a saved list, and nothing else that a hand-edited file put there.
static func _strings(saved: Variant) -> Array[String]:
	var out: Array[String] = []
	if typeof(saved) == TYPE_ARRAY:
		for entry: Variant in saved:
			if typeof(entry) == TYPE_STRING:
				out.append(entry)
	return out


## The old shape: item name -> how many were held. Each becomes that many plain common items with no
## modifiers, which is the honest reading of a save that never knew an item could be anything more.
## Handing them rarities would be handing the player power for having played earlier. The next save
## writes the new shape, so this runs at most once per file.
func _read_v1(data: Dictionary) -> void:
	var counts: Variant = data.get("counts", {})
	if typeof(counts) != TYPE_DICTIONARY:
		return
	for type: String in counts:
		if not LootTable.ITEMS.has(type):
			continue
		for i in int(counts[type]):
			var item := Item.new()
			item.type = type
			items.append(item)


## A saved count read back as a whole number, or 0 where a hand-edited file holds anything else.
static func _whole(value: Variant) -> int:
	return int(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0
