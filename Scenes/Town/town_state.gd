class_name TownState
extends RefCounted
## What the player has left behind in the settlements they have walked into, kept inside the
## inventory's own save (`inventory.towns`): a purchase moves the purse, the bag and a shelf in one write.
##
## A drawer is a plain Dictionary this file never reads. `VendorStock` and `BountyBoard` put their own
## keys there and know their shape, and an absent key is theirs to read as "not yet": a later counter
## needs a key of its own and nothing migrates.
##
## It must never name `Inventory`, which names it: that is where Godot's cycle checker bites.

## World spot key -> that town's drawer. Only towns the player has been in.
var towns := {}


## The key a spot is filed under: its **world spot** as "x,y", never a map cell, which moves with the
## drawn window.
static func key(spot: Vector2i) -> String:
	return "%d,%d" % [spot.x, spot.y]


## The spot behind a key, for whoever reads the drawers back (the bounty journal names the town).
## Anything that is not a pair of numbers is the middle of the world, where no town of the player's
## can stand.
static func spot(at: String) -> Vector2i:
	var parts := at.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


## Marks a town as visited and hands back its drawer, made if this is the first time.
func visit(spot: Vector2i) -> Dictionary:
	var at := key(spot)
	if not towns.has(at):
		towns[at] = {}
	return towns[at]


func visited(spot: Vector2i) -> bool:
	return towns.has(key(spot))


func to_dict() -> Dictionary:
	return towns.duplicate(true)


## Anything that is not a town's worth of data is stepped over, and the wrong shape entirely is no
## towns visited, which is what a save from before towns has.
static func from_dict(data: Variant) -> TownState:
	var state := TownState.new()
	if typeof(data) != TYPE_DICTIONARY:
		return state
	for spot: Variant in data:
		if typeof(data[spot]) == TYPE_DICTIONARY:
			state.towns[str(spot)] = (data[spot] as Dictionary).duplicate(true)
	return state
