class_name TileNames
extends RefCounted
## What a tile is called: a made-up proper word (a head and a tail syllable) and a feature word taken
## from the environment, or from the settlement's tier where there is one. `generate` is a pure function
## of the map seed and the cell, and the name is saved all the same (`MapBuilder.name_of`).
## Nothing here names MapBuilder or TownWorld: the caller passes the environment and the tier's name.

## The two halves of the proper word: a head is a sound and a tail is a landscape word worn down into
## one, which is how English place names are built.
const HEADS := [
	"Bral", "Car", "Dun", "Eld", "Fen", "Gor", "Hal", "Ith", "Kor", "Lun", "Mar", "Nor",
	"Orl", "Pel", "Quel", "Ras", "Sar", "Tor", "Ul", "Var", "Wyn", "Yr", "Zan", "Bel",
]
const TAILS := [
	"ath", "bury", "dale", "fell", "ford", "gard", "hearth", "holt", "mere", "moor",
	"reach", "rift", "shade", "span", "stead", "thorn", "vale", "watch", "wick", "wold",
]

## The second word, per environment: what that land is called by somebody who lives on it.
const FEATURES := {
	"grass": ["Meadow", "Pasture", "Downs", "Green", "Flats", "Commons", "Lea"],
	"dirt": ["Barrens", "Furrows", "Hollow", "Scrub", "Diggings", "Waste"],
	"desert": ["Dunes", "Sands", "Expanse", "Wastes", "Drift", "Basin"],
	"ice": ["Drifts", "Floes", "Frostfield", "Glacier", "Tundra", "Rime"],
	"forest": ["Woods", "Thicket", "Grove", "Wilds", "Canopy", "Coppice"],
	"mountains": ["Peaks", "Crags", "Ridge", "Spire", "Pass", "Heights"],
}
## The second word where a settlement stands, whatever the ground under it. Keyed by
## TownWorld.TIER_NAMES, passed in as a string so this file needs no opinion about that enum's order.
const TOWN_FEATURES := {
	"small": ["Village", "Hamlet", "Cross", "Row"],
	"medium": ["Town", "Market", "Quarter", "Gate"],
	"fortress": ["Keep", "Hold", "Bastion", "Citadel"],
}
## What the Gollux cave's tile is called, whatever ground it opens in: passed as `generate`'s `tier`,
## the way a settlement's tier is.
const CAVE := "cave"
const CAVE_FEATURES := ["Cave", "Hollow", "Deep", "Maw"]
## What a tile falls back to when its environment has no list (a sheet grown a seventh terrain).
const PLAIN_FEATURES := ["Reach", "Bounds", "Country", "March"]


## `tier` is the name of the settlement standing on the tile, `CAVE`, or "" for open land.
static func generate(cell: Vector2i, env: String, map_seed: int, tier := "") -> String:
	var rng := RandomNumberGenerator.new()
	# Under its own tag, so what a place is called has nothing to do with which sprite it is drawn with.
	rng.seed = hash([map_seed, "name", cell])
	var proper: String = HEADS[rng.randi() % HEADS.size()] + TAILS[rng.randi() % TAILS.size()]
	var features: Array = features_for(env, tier)
	return "%s %s" % [proper, features[rng.randi() % features.size()]]


## A settlement's own list wins over the ground it stands on.
static func features_for(env: String, tier := "") -> Array:
	if tier == CAVE:
		return CAVE_FEATURES
	if tier != "" and TOWN_FEATURES.has(tier):
		return TOWN_FEATURES[tier]
	return FEATURES.get(env, PLAIN_FEATURES)
