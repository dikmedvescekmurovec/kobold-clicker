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


## The counters a settlement draws from by its tier: a village has one of them, a town two, a fortress all three.
const TRADES := [GEAR, ORBS, SMITH]


## Every service a settlement of `tier` (a `TownWorld.Tier`) at `spot` offers; -1 (no town) has none.
## Which trade a village has, or a town lacks, is drawn from the world seed and the spot, so it is the
## same every time the player walks back and needs nothing written down.
static func services_for(tier: int, spot: Vector2i, world_seed: int) -> PackedStringArray:
	if show_all and tier != -1:
		return PackedStringArray(ORDER)
	var offered := {BOUNTIES: true, FORTUNE: true}
	var drawn: String = TRADES[absi(hash([world_seed, spot, "vendor"])) % TRADES.size()]
	match tier:
		TownWorld.Tier.SMALL:
			offered[drawn] = true
		TownWorld.Tier.MEDIUM:
			for trade: String in TRADES:
				if trade != drawn:
					offered[trade] = true
		TownWorld.Tier.FORTRESS:
			for trade: String in TRADES:
				offered[trade] = true
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
