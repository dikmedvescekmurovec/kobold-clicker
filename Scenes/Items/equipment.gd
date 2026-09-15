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


## Puts `item` on and hands back whatever came off, which the caller owes back to the bag. Refuses a
## piece the socket does not take rather than putting a boot on the player's head.
func equip(socket: Socket, item: Item) -> Item:
	if not fits(socket, item):
		return null
	var removed: Item = worn.get(socket)
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


## What the whole set is worth: every worn piece's `effective_stats`, added up stat by stat.
##
## Adding is the only rule. Two rings of +3 Fire Resistance make 6, two pieces of armour add, and a
## second source of crit damage adds to the first -- which is exactly why the tables put health and
## the resistances on nearly every piece. Percent modifiers were already folded into each item
## before it got here, so nothing scales anything across pieces.
func totals() -> Dictionary:
	var out := {}
	for item in items():
		for stat: String in item.effective_stats():
			out[stat] = float(out.get(stat, 0.0)) + float(item.effective_stats()[stat])
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
	return gear
