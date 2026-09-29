class_name Camp
extends RefCounted
## Resting while the game is shut: the hero camps on the best ground taken so far and holds it until
## the player is back. A camp pays gold and experience and nothing else -- no gear, no orbs, no
## bodies for a bounty board. Those are what going in with a sword in your hand is for.
##
## Nobody sets one up: `main_scene` makes the camp at start-up, from the hour the save was last
## written, on `MapBuilder.best_farm()`, and pays it there and then.
##
## **A camp is not a second economy.** What it pays is the tile's own farm run played actively --
## `Encounter.farm` armed from what the player wears, clicked at `CLICK_RATE` -- sampled here
## (`rates`) and cut to `IDLE_SHARE` of it. So every dial that moves what a tile is worth moves a
## camp with it, and the one figure here is the share: a full camp (`MAX_SECONDS`, 8 h) pays what
## half an hour of that play pays.
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

## How long a hero can hold a camp before rest is needed: a night pays a night, and a fortnight away
## pays a night as well.
const MAX_SECONDS := 8.0 * 3600.0
## The clicks a second the sample plays at: an attentive player, the middle of the balance tables'.
const CLICK_RATE := 5.0
## What a camp pays of that active play: a full camp is worth half an hour of it (an hour until the
## user halved it, 2026-09-29: a night took a level-30 hero to 70).
const IDLE_SHARE := 1800.0 / MAX_SECONDS

## The keys of the drawer `make` builds.
## The Restless curse: a camp that fills in `RESTLESS_SECONDS` and pays `RESTLESS_PAY` times over.
## Both are written into the drawer as the camp is made (`MOST`), so a camp is still arithmetic.
const RESTLESS_SECONDS := 2.0 * 3600.0
const RESTLESS_PAY := 2.0
const MOST := "most"
const SINCE := "since"
const CELL := "cell"
const PLACE := "place"
const GOLD := "gold"
const XP := "xp"
const KILLS := "kills"


## What `fight` earns a second, played actively and cut to `IDLE_SHARE`: gold, experience and bodies.
## It plays the fight out, so hand it one that is armed and endless and then throw it away.
static func rates(fight: Encounter) -> Dictionary:
	var spent := 0.0
	var click := 0.0
	while spent < SAMPLE_MOST and (spent < SAMPLE_SECONDS or fight.kills() < SAMPLE_KILLS):
		click += SAMPLE_STEP * CLICK_RATE
		while click >= 1.0:
			fight.hit()
			click -= 1.0
		fight.advance(SAMPLE_STEP)
		spent += SAMPLE_STEP
	var share := IDLE_SHARE / spent
	return {GOLD: fight.gold * share, XP: float(fight.xp) * share, KILLS: float(fight.kills()) * share}


## The camp: where it stands, what it is called, when it was made and what it earns a second.
## Everything `earned` needs.
static func make(cell: Vector2i, place: String, fight: Encounter, at: float) -> Dictionary:
	var earns := rates(fight)
	var restless := Curses.effect(Curses.RESTLESS) in fight.effects
	var pay := RESTLESS_PAY if restless else 1.0
	return {
		SINCE: int(at),
		CELL: [cell.x, cell.y],
		PLACE: place,
		GOLD: float(earns[GOLD]) * pay,
		XP: float(earns[XP]) * pay,
		KILLS: float(earns[KILLS]),
		MOST: RESTLESS_SECONDS if restless else MAX_SECONDS,
	}


## What a camp has earned by `at`: the seconds it has stood (capped), and the rates times those.
## `full` is whether the cap is what stopped it, which is the one thing the screen must say -- a
## player back after a week is owed an explanation, not a number that looks short.
static func earned(camp: Dictionary, at: float) -> Dictionary:
	# A camp saved before there was a `MOST` fills when camps always did.
	var most := float(camp.get(MOST, MAX_SECONDS))
	var spent := clampf(at - float(camp.get(SINCE, at)), 0.0, most)
	return {
		"seconds": spent,
		"full": spent >= most,
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
