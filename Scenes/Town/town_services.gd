class_name TownServices
extends RefCounted
## What a settlement offers: which counters stand in it, by its tier and its place in the world.
##
## Static and node-free, the way `OrbTable` is, so the tile panel, the town page and the tests all ask
## one question and get one answer. Nothing here is written into the save: a town's services are a
## property of its tier and its spot and cannot drift, unlike its stock, which is rolled and so is
## written down.
##
## A village has room for one vendor and the seed decides which, so two villages a day apart are not
## the same errand; a town has both; a fortress has both and a smith. Every settlement has a board
## and a fortuneteller.

const BOUNTIES := "bounties"
const GEAR := "gear"
const ORBS := "orbs"
const SMITH := "smith"
const FORTUNE := "fortune"

## What each counter is called, wherever it is named -- the tile panel's list and the town page's tabs
## both read it here, so a service is spelled one way.
const LABELS := {
	BOUNTIES: "Bounty board",
	GEAR: "Gear merchant",
	ORBS: "Orb vendor",
	SMITH: "Blacksmith",
	FORTUNE: "Fortuneteller",
}

## The order services are ever listed in, so a town reads the same way twice. The board first, because
## it is the one thing every settlement has and so the one thing the player can count on finding. The
## fortuneteller last: every settlement has her too, and she is where a visit ends rather than starts.
const ORDER := [BOUNTIES, GEAR, ORBS, SMITH, FORTUNE]

## Dev: every settlement offers every counter, so each can be looked at from the start village. The
## main scene sets it (`debug_all_services`); nothing else may, and the tests never see it on.
static var show_all := false


## Every service a settlement of `tier` at `spot` offers. `tier` is a `TownWorld.Tier`; -1 (no town)
## has nothing. The village's single vendor is drawn from the world seed and the spot, so it is the
## same vendor every time the player walks back and needs nothing written down.
static func services_for(tier: int, spot: Vector2i, world_seed: int) -> PackedStringArray:
	if show_all and tier != -1:
		return PackedStringArray(ORDER)
	var offered := {BOUNTIES: true, FORTUNE: true}
	match tier:
		TownWorld.Tier.SMALL:
			offered[GEAR if absi(hash([world_seed, spot, "vendor"])) % 2 == 0 else ORBS] = true
		TownWorld.Tier.MEDIUM:
			offered[GEAR] = true
			offered[ORBS] = true
		TownWorld.Tier.FORTRESS:
			offered[GEAR] = true
			offered[ORBS] = true
			offered[SMITH] = true
		_:
			return PackedStringArray()
	var found := PackedStringArray()
	for service: String in ORDER:
		if offered.has(service):
			found.append(service)
	return found


## What a counter is called. "" for a name this build does not have, rather than a guess.
static func label(service: String) -> String:
	return str(LABELS.get(service, ""))
