class_name TownState
extends RefCounted
## What the player has left behind in the settlements they have walked into, kept inside the
## inventory's own save (`inventory.towns`) the way `skills` is.
##
## One save and one write, because a purchase moves the purse, the bag and a town's shelf together and
## two files would be two ways for them to disagree. Keyed by **world spot** written "x,y" rather than
## by map cell: a cell is a place in the drawn window and the window moves, and a spot is where the
## town actually is.
##
## A drawer is a plain Dictionary and this file does not read what is in it. `VendorStock` puts a
## vendor's shelf there (`items`, `orbs`, `rerolls`) and knows that shape, and `BountyBoard` its postings; a drawer from a save
## written before there was anything to put in one simply has none of those keys, and the reader is
## what turns an absent key into "not stocked yet" rather than into a repair. So a later counter
## needs a key of its own here and nothing else, and nothing has to migrate.
##
## It must never name `Inventory`, which names it: that is where Godot's cycle checker bites.

## World spot key -> what that town holds. Only towns the player has actually been in, the way
## `Skills.ranks` holds only skills with points in them.
var towns := {}


## The key a spot is filed under. One place, because a key written two ways is a town visited twice.
static func key(spot: Vector2i) -> String:
	return "%d,%d" % [spot.x, spot.y]


## The spot behind a key, the mirror of `key`, for whoever is reading the drawers back rather than
## looking one up -- the bounty journal, which has to say which town posted what. Anything that is not
## a pair of numbers is the middle of the world, which is nowhere a town of the player's can stand.
static func spot(at: String) -> Vector2i:
	var parts := at.split(",")
	if parts.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(parts[0]), int(parts[1]))


## Marks a town as visited and hands back what it holds, making the drawer if this is the first time.
func visit(spot: Vector2i) -> Dictionary:
	var at := key(spot)
	if not towns.has(at):
		towns[at] = {}
	return towns[at]


func visited(spot: Vector2i) -> bool:
	return towns.has(key(spot))


func to_dict() -> Dictionary:
	return towns.duplicate(true)


## Read back. Anything that is not a town's worth of data is stepped over rather than guessed at, the
## same pruning the rest of the save does, and the wrong shape entirely is no towns visited -- which is
## exactly what a save written before towns existed has.
static func from_dict(data: Variant) -> TownState:
	var state := TownState.new()
	if typeof(data) != TYPE_DICTIONARY:
		return state
	for spot: Variant in data:
		if typeof(data[spot]) == TYPE_DICTIONARY:
			state.towns[str(spot)] = (data[spot] as Dictionary).duplicate(true)
	return state
