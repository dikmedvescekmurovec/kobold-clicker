class_name TileNames
extends RefCounted
## What a tile is called. Every tile the player lays eyes on is named the moment it comes out of the
## fog, and the name never changes again -- the fight fought on it says the name, so a tile the
## player has beaten is a place they can talk about rather than a pair of coordinates.
##
## A name is two words: a made-up proper word built from a head and a tail syllable, and a feature
## word taken from what the world put there -- the environment, or the settlement's tier where there
## is one, because "Bralmere Keep" says more about a fortress than "Bralmere Meadow" does. The
## syllable tables give five hundred propers, which is enough that two tiles of one environment
## sharing a name is a curiosity rather than a confusion.
##
## `generate` is a pure function of the map seed and the cell, so it gives the same name every time
## it is asked -- and the name is written into the save all the same, for the reason the town world
## is: being a pure function of its seed is a property of these tables today and not a promise to
## the player. Retuning them must not rename a place somebody has already been.
##
## Nothing here names MapBuilder or TownWorld: the caller passes the environment and the tier's
## name, so this file is a table and a dice roll and nothing else.

## The two halves of the proper word. Kept apart rather than written out as five hundred names
## because the pair is what makes them cheap: a head is a sound and a tail is a landscape word worn
## down into one, which is how English place names are built.
const HEADS := [
	"Bral", "Car", "Dun", "Eld", "Fen", "Gor", "Hal", "Ith", "Kor", "Lun", "Mar", "Nor",
	"Orl", "Pel", "Quel", "Ras", "Sar", "Tor", "Ul", "Var", "Wyn", "Yr", "Zan", "Bel",
]
const TAILS := [
	"ath", "bury", "dale", "fell", "ford", "gard", "hearth", "holt", "mere", "moor",
	"reach", "rift", "shade", "span", "stead", "thorn", "vale", "watch", "wick", "wold",
]

## The second word, per environment. Each list is what that land is called by somebody who lives on
## it, so the name says what the player is looking at before the picture loads.
const FEATURES := {
	"grass": ["Meadow", "Pasture", "Downs", "Green", "Flats", "Commons", "Lea"],
	"dirt": ["Barrens", "Furrows", "Hollow", "Scrub", "Diggings", "Waste"],
	"desert": ["Dunes", "Sands", "Expanse", "Wastes", "Drift", "Basin"],
	"ice": ["Drifts", "Floes", "Frostfield", "Glacier", "Tundra", "Rime"],
	"forest": ["Woods", "Thicket", "Grove", "Wilds", "Canopy", "Coppice"],
	"mountains": ["Peaks", "Crags", "Ridge", "Spire", "Pass", "Heights"],
}
## What a tile is called when a settlement stands on it, whatever the ground under it is: a place
## with people in it is named for them. Keyed by TownWorld.TIER_NAMES, passed in as a string so this
## file needs no opinion about that enum's order.
const TOWN_FEATURES := {
	"small": ["Village", "Hamlet", "Cross", "Row"],
	"medium": ["Town", "Market", "Quarter", "Gate"],
	"fortress": ["Keep", "Hold", "Bastion", "Citadel"],
}
## What the Gollux cave's tile is called, whatever ground it opens in: passed as `generate`'s `tier`,
## the way a settlement's tier is, since the cave is a place with a thing in it too.
const CAVE := "cave"
const CAVE_FEATURES := ["Cave", "Hollow", "Deep", "Maw"]
## What a tile falls back to when its environment has no list -- a sheet grown a seventh terrain
## names its tiles plainly rather than leaving them nameless.
const PLAIN_FEATURES := ["Reach", "Bounds", "Country", "March"]


## The name of the tile at `cell`. `env` is its environment and `tier` the name of the settlement
## standing on it, or "" for open land.
static func generate(cell: Vector2i, env: String, map_seed: int, tier := "") -> String:
	var rng := RandomNumberGenerator.new()
	# Under its own tag, the way the backdrop and the tile variant are, so what a place is called has
	# nothing to do with which sprite it is drawn with or which picture it fights on.
	rng.seed = hash([map_seed, "name", cell])
	var proper: String = HEADS[rng.randi() % HEADS.size()] + TAILS[rng.randi() % TAILS.size()]
	var features: Array = features_for(env, tier)
	return "%s %s" % [proper, features[rng.randi() % features.size()]]


## The words a tile of this kind can take for its second half. A settlement's own list wins over the
## ground it stands on.
static func features_for(env: String, tier := "") -> Array:
	if tier == CAVE:
		return CAVE_FEATURES
	if tier != "" and TOWN_FEATURES.has(tier):
		return TOWN_FEATURES[tier]
	return FEATURES.get(env, PLAIN_FEATURES)
