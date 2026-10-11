class_name TownServices
extends RefCounted
## Which counters stand in a settlement, by its tier and its place in the world. Static and node-free,
## and nothing here is saved: a town's services cannot drift, unlike its stock, which is rolled and so
## written down.

const BOUNTIES := "bounties"
const GEAR := "gear"
const ORBS := "orbs"
const SMITH := "smith"
const FORTUNE := "fortune"

## What each counter is called, wherever it is named (`label`).
const LABELS := {
	BOUNTIES: "Bounty board",
	GEAR: "Gear merchant",
	ORBS: "Orb vendor",
	SMITH: "Blacksmith",
	FORTUNE: "Fortuneteller",
}

## The order services are ever listed in. The board and the fortuneteller, which every settlement has,
## stand first and last.
const ORDER := [BOUNTIES, GEAR, ORBS, SMITH, FORTUNE]

## Dev: every settlement offers every counter. The main scene and the settings page set it
## (`Settings.show_all_services`); nothing else may, and the tests never see it on.
static var show_all := false


## Every service a settlement of `tier` (a `TownWorld.Tier`) at `spot` offers; -1 (no town) has none.
## A village's one vendor is drawn from the world seed and the spot, so it is the same every time the
## player walks back and needs nothing written down.
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
		-1:
			return PackedStringArray()
		_:
			push_error("TownServices: no counters are written for a settlement of tier %d" % tier)
			return PackedStringArray()
	var found := PackedStringArray()
	for service: String in ORDER:
		if offered.has(service):
			found.append(service)
	return found


## "" for a name this build does not have, rather than a guess.
static func label(service: String) -> String:
	return str(LABELS.get(service, ""))
