class_name Equipment
extends RefCounted
## What the player is wearing, and what it adds up to.
##
## Eight sockets over seven places on the body, because two of them do not map one-to-one: a ring
## goes in either hand, and the offhand takes a shield or a torch but not both. That is why a socket
## and an item's `slot` are different things -- `TAKES` is the join between them, and it is the only
## place that knows a ring fits twice.
##
## An equipped piece belongs here and not to the Inventory: equipping moves it out of the bag and
## unequipping moves it back, so one item is in exactly one place and nothing has to be kept in step.
##
## `totals()` is the whole point of the class. Everything else in the game that wants to know what
## the player is worth asks it, so there is one answer rather than one per caller.

## Where a piece can go. The order is the order the panel draws them down the two columns beside the
## doll: helmet and amulet at the head, the hands, the body, and the feet.
enum Socket { HELMET, AMULET, WEAPON, OFFHAND, BODY, RING_LEFT, RING_RIGHT, BOOTS }

## Saved and shown by name, for the reason ItemRarity.NAMES gives: an enum value is only a position,
## and slipping a socket in between two others would quietly reinterpret every save on disk.
const NAMES := {
	Socket.HELMET: "helmet",
	Socket.AMULET: "amulet",
	Socket.WEAPON: "weapon",
	Socket.OFFHAND: "offhand",
	Socket.BODY: "body",
	Socket.RING_LEFT: "ring_left",
	Socket.RING_RIGHT: "ring_right",
	Socket.BOOTS: "boots",
}

## What the socket is called to a person. Both rings are simply "Ring": which hand a ring is on has
## never mattered in any game that has two of them, and numbering them would invite the player to
## wonder whether it does.
const LABELS := {
	Socket.HELMET: "Helmet",
	Socket.AMULET: "Amulet",
	Socket.WEAPON: "Weapon",
	Socket.OFFHAND: "Offhand",
	Socket.BODY: "Body",
	Socket.RING_LEFT: "Ring",
	Socket.RING_RIGHT: "Ring",
	Socket.BOOTS: "Boots",
}

## The join: which `LootTable.slot_of` value each socket accepts. Two sockets naming "ring" is how a
## ring comes to fit twice, and two item types naming "offhand" is how a shield and a torch come to
## compete for one socket.
const TAKES := {
	Socket.HELMET: "helmet",
	Socket.AMULET: "amulet",
	Socket.WEAPON: "weapon",
	Socket.OFFHAND: "offhand",
	Socket.BODY: "body",
	Socket.RING_LEFT: "ring",
	Socket.RING_RIGHT: "ring",
	Socket.BOOTS: "boots",
}

## Socket -> Item, holding only the sockets that have something in them. An empty socket is a missing
## key rather than a null, so `worn.size()` is how many pieces are on.
var worn := {}


## Every socket, in the order the enum declares them.
static func sockets() -> Array:
	var all := []
	for socket: Socket in NAMES:
		all.append(socket)
	return all


## Whether this piece can go in this socket at all.
static func fits(socket: Socket, item: Item) -> bool:
	return item != null and TAKES[socket] == LootTable.slot_of(item.type)


## The sockets this piece could go in, emptiest first, so the caller that wants "somewhere sensible"
## takes the front of the list and fills a bare ring finger before swapping a ring already on.
func sockets_for(item: Item) -> Array:
	var open := []
	var taken := []
	for socket: Socket in NAMES:
		if not fits(socket, item):
			continue
		if worn.has(socket):
			taken.append(socket)
		else:
			open.append(socket)
	return open + taken


func item_at(socket: Socket) -> Item:
	return worn.get(socket)


## Whether what is in the weapon hand takes both of them, which is what closes the offhand.
func two_handed_worn() -> bool:
	var weapon: Item = worn.get(Socket.WEAPON)
	return weapon != null and LootTable.two_handed(weapon.type)


## Everything that would come off if `item` went into `socket`, in the order the sockets are declared
## in. Usually the socket's own piece and nothing else -- but a greatsword needs the hand the offhand
## is in, and an offhand needs the hand a greatsword has both of, so one piece going on can take two
## off. Worked out here rather than at `equip`, so the bag can ask what a swap would cost *before*
## making it, and the button that greys and the call that refuses cannot disagree.
func displaced_by(socket: Socket, item: Item) -> Array[Item]:
	var out: Array[Item] = []
	if not fits(socket, item):
		return out
	if worn.has(socket):
		out.append(worn[socket])
	if socket == Socket.WEAPON and LootTable.two_handed(item.type) and worn.has(Socket.OFFHAND):
		out.append(worn[Socket.OFFHAND])
	elif socket == Socket.OFFHAND and two_handed_worn():
		out.append(worn[Socket.WEAPON])
	return out


## Puts `item` on and hands back everything that came off, which the caller owes back to the bag --
## `displaced_by`'s list, so what was promised is exactly what happens. Refuses a piece the socket
## does not take rather than putting a boot on the player's head, and then nothing comes off.
func equip(socket: Socket, item: Item) -> Array[Item]:
	var removed := displaced_by(socket, item)
	if not fits(socket, item):
		return removed
	for piece: Item in removed:
		worn.erase(worn.find_key(piece))
	worn[socket] = item
	return removed


## Takes the socket's piece off and hands it back, or null if there was nothing in it.
func unequip(socket: Socket) -> Item:
	var removed: Item = worn.get(socket)
	worn.erase(socket)
	return removed


## Everything worn, in socket order -- for the caller that wants the pieces and not the places.
func items() -> Array[Item]:
	var all: Array[Item] = []
	for socket: Socket in NAMES:
		if worn.has(socket):
			all.append(worn[socket])
	return all


## What the whole set is worth: every worn piece's `effective_stats`, added up stat by stat, and then
## whatever the set's GLOBAL modifiers ask of the total.
##
## Adding is the rule for the first pass. Two rings of +3 Armour make 6, two pieces of armour add,
## and a second source of crit damage adds to the first -- which is exactly why the tables put armour
## and dodge on nearly every piece. A piece's own percent modifiers were folded into it before it
## got here, so nothing there scales anything across pieces.
##
## The second pass is the one thing that does, and it is why GLOBAL exists as its own kind: a ring's
## "+14% increased Damage" is a percentage of what the player deals, which is the sword's number and
## not the ring's. So the globals are gathered while the stats are added, summed across the set, and
## applied once at the end -- after everything that contributes to the stat is in, which is the only
## point at which the answer does not depend on what order the sockets were read in. A global on a
## stat nothing carries scales zero, which is correct: increased damage is worth nothing bare-handed.
##
## The player's skills come in around that. `skill_flat` is added to the pieces' sum before either
## multiplier, so a skill's point of damage is scaled by a ring's global exactly as the sword's is.
## `skill_percent` is applied last and **on its own**: it multiplies the gear's globals rather than
## adding to them, so a skill and a ring each doing 10% make 21%, not 20%. With neither given this is
## the set alone, which is every caller that is asking about gear and not about the player.
##
## `also` is a second doll worn at the same time -- the heirlooms'. **Flats add and percents
## multiply:** its pieces go into the same sum, and its globals are a multiplier of their own over
## that sum rather than more of this doll's, so +20% on each doll is x1.44 and not x1.4.
func totals(skill_flat := {}, skill_percent := {}, also: Equipment = null) -> Dictionary:
	var out := {}
	var globals: Array[Dictionary] = []
	for doll: Equipment in [self] if also == null else [self, also]:
		var global := {}
		for item in doll.items():
			var stats := item.effective_stats()
			for stat: String in stats:
				out[stat] = float(out.get(stat, 0.0)) + float(stats[stat])
			var percents := item.global_percents()
			for stat: String in percents:
				global[stat] = float(global.get(stat, 0.0)) + float(percents[stat])
		globals.append(global)
	for stat: String in skill_flat:
		out[stat] = float(out.get(stat, 0.0)) + float(skill_flat[stat])
	for global in globals:
		for stat: String in global:
			out[stat] = float(out.get(stat, 0.0)) * (1.0 + float(global[stat]) / 100.0)
	for stat: String in skill_percent:
		out[stat] = float(out.get(stat, 0.0)) * (1.0 + float(skill_percent[stat]) / 100.0)
	return out


## What the worn uniques change about a fight, as `UniqueTable.effect_of` ids for `Encounter.effects`.
## One entry a piece, so two of one ring are two entries and the fight can count them.
func effects() -> Array:
	var out := []
	for item in items():
		if not item.unique.is_empty():
			out.append(UniqueTable.effect_of(item.unique))
	return out


## The save's shape: socket name -> the piece in it. Sockets with nothing in them are left out
## entirely, so an empty set writes `{}` rather than eight nulls.
func to_dict() -> Dictionary:
	var out := {}
	for socket: Socket in NAMES:
		if worn.has(socket):
			out[NAMES[socket]] = worn[socket].to_dict()
	return out


## Read back, skipping anything this build no longer understands -- a socket that has been retired,
## a piece whose type is gone, or a piece that no longer fits where it was saved. The same forgiving
## pruning `Inventory` has always done: a save that has drifted loses a piece, never the whole file.
static func from_dict(data: Variant) -> Equipment:
	var gear := Equipment.new()
	if typeof(data) != TYPE_DICTIONARY:
		return gear
	for socket: Socket in NAMES:
		var key: String = NAMES[socket]
		if not data.has(key):
			continue
		var item := Item.from_dict(data[key])
		if item != null and fits(socket, item):
			gear.worn[socket] = item
	# A file holding an offhand beside a two-hander is a save that has drifted -- from a build before
	# greatswords, or edited by hand. The weapon is what the player chose, so the offhand is the piece
	# that goes, by the same pruning rule as a socket that no longer fits.
	if gear.two_handed_worn():
		gear.worn.erase(Socket.OFFHAND)
	return gear
