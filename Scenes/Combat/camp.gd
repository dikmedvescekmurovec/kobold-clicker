class_name Camp
extends RefCounted
## Resting on a tile already taken: the hero holds the ground while the game is away, driving off
## whatever wanders past. A camp pays gold and experience and nothing else -- no gear, no orbs, no
## bodies for a bounty board. Those are what going in with a sword in your hand is for.
##
## **A camp is not a second economy.** What it pays is the tile's own farm run with nobody clicking:
## `Encounter.farm` armed from what the player wears, advanced by `advance()` alone, so only the
## weapon's own swings land. That is played out here for a short sample (`rates`), and what the
## sample earned a second is what the camp pays a second from then on. So every dial that moves what
## a tile is worth -- `HP_GROWTH`, `GOLD_GROWTH`, `XP_PER_LEVEL`, a weapon's attack speed -- moves a
## camp with it, and there is no figure here to keep in step with anything.
##
## The rates are worked out **once**, when camp is made, and written into the save beside the hour
## it was made at. From then on a camp is a sum: `earned()` is the rate times the seconds since.
## Nothing accrues in memory and there is nothing to bank on the way out, so a game closed while
## camped needs no exit handling at all -- the next launch reads the same two numbers and finds the
## same answer the open window would have shown.
##
## `ponytail:` sampling rather than playing out the whole night. A night is thousands of kills and
## the run's lineup grows one entry per body; the sample keeps the cost flat at a few thousand
## steps, at the price of a night being an average night rather than its own roll of the dice.

## What the sample plays out: at least this long, and on past it until the hunt has this many bodies
## to average, because a deep tile against thin gear can take a minute a kill. `SAMPLE_MOST` is the
## end of it either way, so a hunt that kills nothing cannot loop.
const SAMPLE_SECONDS := 120.0
const SAMPLE_KILLS := 5
const SAMPLE_MOST := 1800.0
## The step the sample is played at. A kill drops whatever is left of the step it died in -- the
## same crumb a drawn fight loses every frame -- so it is small enough that the crumbs stay crumbs.
const SAMPLE_STEP := 1.0 / 30.0

## How long a hero can hold a camp before rest is needed. The cap is the whole of the overnight
## promise: a night pays a night, and a fortnight away pays a night as well.
const MAX_SECONDS := 12.0 * 3600.0

## The keys of the drawer kept in `inventory.camp`, the way `FortuneTeller`'s live in
## `inventory.fortunes`: `Inventory` never reads what is in one.
const SINCE := "since"
const CELL := "cell"
const PLACE := "place"
const GOLD := "gold"
const XP := "xp"
const KILLS := "kills"


## Whether this fight earns anything with nobody clicking. A weapon that does not swing on its own
## is the one way to camp for nothing, so it is asked before a camp is made rather than found out
## twelve hours later. The two conditions are `Encounter._swing_weapon`'s own.
static func hunts(fight: Encounter) -> bool:
	return fight.attack_speed > 0.0 and not ("berserk" in fight.effects)


## What `fight` earns a second with nobody clicking: gold, experience and bodies. It plays the fight
## out, so hand it one that is armed and endless and then throw it away.
static func rates(fight: Encounter) -> Dictionary:
	if not hunts(fight):
		return {GOLD: 0.0, XP: 0.0, KILLS: 0.0}
	var spent := 0.0
	while spent < SAMPLE_MOST and (spent < SAMPLE_SECONDS or fight.kills() < SAMPLE_KILLS):
		fight.advance(SAMPLE_STEP)
		spent += SAMPLE_STEP
	return {GOLD: fight.gold / spent, XP: float(fight.xp) / spent, KILLS: float(fight.kills()) / spent}


## The drawer a camp is saved as: where it stands, what it is called, when it was made and what it
## earns a second. Everything `earned` needs, so a camp survives any change to the ground under it.
static func make(cell: Vector2i, place: String, fight: Encounter, at: float) -> Dictionary:
	var earns := rates(fight)
	return {
		SINCE: int(at),
		CELL: [cell.x, cell.y],
		PLACE: place,
		GOLD: float(earns[GOLD]),
		XP: float(earns[XP]),
		KILLS: float(earns[KILLS]),
	}


## What a camp has earned by `at`: the seconds it has stood (capped), and the rates times those.
## `full` is whether the cap is what stopped it, which is the one thing the screen must say -- a
## player back after a week is owed an explanation, not a number that looks short.
static func earned(camp: Dictionary, at: float) -> Dictionary:
	var spent := clampf(at - float(camp.get(SINCE, at)), 0.0, MAX_SECONDS)
	return {
		"seconds": spent,
		"full": spent >= MAX_SECONDS,
		GOLD: float(camp.get(GOLD, 0.0)) * spent,
		XP: int(float(camp.get(XP, 0.0)) * spent),
		KILLS: int(float(camp.get(KILLS, 0.0)) * spent),
	}


## Where the camp stands. Saved as a pair of numbers because a Vector2i does not survive JSON.
static func cell_of(camp: Dictionary) -> Vector2i:
	var at: Variant = camp.get(CELL, [])
	if typeof(at) != TYPE_ARRAY or at.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(at[0]), int(at[1]))


## A stretch of time in the words a person uses for one: "3h 12m", "12m 30s", "45s".
static func spell_time(seconds: float) -> String:
	var whole := int(seconds)
	if whole >= 3600:
		return "%dh %dm" % [whole / 3600, (whole % 3600) / 60]
	if whole >= 60:
		return "%dm %ds" % [whole / 60, whole % 60]
	return "%ds" % whole
