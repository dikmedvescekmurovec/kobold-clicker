class_name Equipment
extends RefCounted
## What is worn, and what it adds up to: `totals` is the one answer to what a set is worth. A worn
## piece is here and not in the bag; `Inventory.equip` / `unequip` move it between the two.

## In the order the panel draws them down the two columns beside the doll.
enum Socket { HELMET, AMULET, WEAPON, OFFHAND, BODY, RING_LEFT, RING_RIGHT, BOOTS }

## What a save holds: names, never enum positions.
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

## What the screen says. The rings are named by hand only so Equip can say which finger it fills.
const LABELS := {
	Socket.HELMET: "Helmet",
	Socket.AMULET: "Amulet",
	Socket.WEAPON: "Weapon",
	Socket.OFFHAND: "Offhand",
	Socket.BODY: "Body",
	Socket.RING_LEFT: "Left ring",
	Socket.RING_RIGHT: "Right ring",
	Socket.BOOTS: "Boots",
}

## Socket -> the `LootTable.slot_of` it accepts: the one place that knows a ring fits either hand and
## that a shield and a torch compete for the one offhand.
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

## Socket -> Item, holding only the sockets with something in them: `worn.size()` is the pieces on.
var worn := {}


static func sockets() -> Array:
	var all := []
	for socket: Socket in NAMES:
		all.append(socket)
	return all


static func fits(socket: Socket, item: Item) -> bool:
	return item != null and TAKES[socket] == LootTable.slot_of(item.type)


## The sockets this piece could go in, the empty ones first: a bare ring finger before a swap.
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


## Whether the weapon worn takes both hands, which closes the offhand.
func two_handed_worn() -> bool:
	var weapon: Item = worn.get(Socket.WEAPON)
	return weapon != null and LootTable.two_handed(weapon.type)


## Everything that would come off if `item` went into `socket`, in socket order: the socket's own
## piece, and the offhand under a two-hander or the two-hander over an offhand. The one answer for the
## tooltip, the comparison and `equip`, so the button that greys and the call that refuses agree.
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


## Puts `item` on and hands back everything that came off (`displaced_by`'s list), which the caller
## owes the bag. A piece the socket does not take changes nothing.
func equip(socket: Socket, item: Item) -> Array[Item]:
	var removed := displaced_by(socket, item)
	if not fits(socket, item):
		return removed
	for piece: Item in removed:
		worn.erase(worn.find_key(piece))
	worn[socket] = item
	return removed


func unequip(socket: Socket) -> Item:
	var removed: Item = worn.get(socket)
	worn.erase(socket)
	return removed


## Everything worn, in socket order.
func items() -> Array[Item]:
	var all: Array[Item] = []
	for socket: Socket in NAMES:
		if worn.has(socket):
			all.append(worn[socket])
	return all


## What the set is worth, stat -> number, built in this order:
##   1. every worn piece's `effective_stats`, added -- `also`'s too, a second doll worn as well (the
##      heirlooms');
##   2. `skill_flat`, added, so the percents below scale a skill's point as they do the gear's;
##   3. each doll's GLOBAL percents, summed over the doll and applied once: +20% on each of two dolls
##      is x1.44, not x1.4;
##   4. `skill_percent`, a multiplier of its own: a skill's 10% and a ring's make 21%, not 20%.
## The globals go on after every piece is in, so the answer never depends on the order the sockets
## were read in, and one on a stat nothing carries scales zero. With no arguments it is the gear alone.
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


## What the worn uniques change about a fight: one `UniqueTable.effect_of` a piece, so two of one ring
## are two entries and the fight can count them.
func effects() -> Array:
	var out := []
	for item in items():
		if not item.unique.is_empty():
			out.append(UniqueTable.effect_of(item.unique))
	return out


## The save's shape: socket name -> the piece in it, empty sockets left out.
func to_dict() -> Dictionary:
	var out := {}
	for socket: Socket in NAMES:
		if worn.has(socket):
			out[NAMES[socket]] = worn[socket].to_dict()
	return out


## Read back. A socket this build has not got, a piece `Item.from_dict` cannot read and a piece that no
## longer fits where it was saved are dropped, never the whole file; each is named in `lost`.
static func from_dict(data: Variant, lost: Array = []) -> Equipment:
	var gear := Equipment.new()
	if typeof(data) != TYPE_DICTIONARY:
		return gear
	for socket: Socket in NAMES:
		var key: String = NAMES[socket]
		if not data.has(key):
			continue
		var item := Item.from_dict(data[key], lost)
		if item != null and fits(socket, item):
			gear.worn[socket] = item
		elif item != null:
			lost.append(item.type)
	# An offhand saved beside a two-hander goes: the weapon is what the player chose.
	if gear.two_handed_worn() and gear.worn.has(Socket.OFFHAND):
		lost.append(gear.worn[Socket.OFFHAND].type)
		gear.worn.erase(Socket.OFFHAND)
	return gear
