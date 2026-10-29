class_name Camp
extends RefCounted
## The camp held while the game is shut, all rules and no nodes. It pays gold and experience, and what
## its bodies dropped (`finds`). Nobody sets one up: `main_scene` makes it at start-up, from the hour
## the save was last written, on `MapBuilder.best_farm()`, and pays it there and then.
##
## **A camp is not a second economy.** What it pays is the tile's own farm run played actively --
## `Encounter.farm` armed from what the player wears, clicked at `CLICK_RATE` -- sampled here (`rates`)
## and cut to `IDLE_SHARE` of it. So every dial that moves what a tile is worth moves a camp with it,
## and the one figure here is the share.
##
## `ponytail:` gold and experience are sampled, not played out: an average night, at a flat cost. The
## finds cannot be averaged, so `finds` plays the run on for the camp's own bodies, about 225 s of run
## an hour camped: some 35 ms of start-up an hour (measured 2026-10-11), so a second at thirty walls.
## If that drags, count the sample's bodies towards them, or play the pass over the camp's first frames.

## What the sample plays out: at least this long, and on past it until the hunt has this many bodies
## to average, because a deep tile against thin gear can take a minute a kill. `SAMPLE_MOST` is the
## end of it either way, so a hunt that kills nothing cannot loop.
const SAMPLE_SECONDS := 120.0
const SAMPLE_KILLS := 5
const SAMPLE_MOST := 1800.0
## The step the sample is played at. A kill drops whatever is left of the step it died in, so it is
## small enough that the crumbs stay crumbs.
const SAMPLE_STEP := 1.0 / 30.0

## The clicks a second the sample plays at: an attentive player.
const CLICK_RATE := 5.0
## The step `finds` plays at, a click a step. It plays to a count of bodies and not for a time, so the
## crumbs cost it nothing, and it is most of that pass's start-up cost at the sample's step.
const FINDS_STEP := 1.0 / CLICK_RATE
## What a camped second pays of an active one: an hour away is 3 min 45 s of play. The user's eight
## hours for half an hour (2026-09-29: an hour for eight took a level-30 hero to 70 in a night), kept
## as it was when the hours a camp holds became the walls' (`WallUnlocks.camp_hours`, 2026-10-11).
const IDLE_SHARE := 1.0 / 16.0

## The Restless curse: a camp full in `RESTLESS_SHARE` of its hours that pays its gold and experience
## `RESTLESS_PAY` times over (not its bodies: the user's, 2026-10-11). Both are written into the camp
## as it is made (`MOST`), so a camp is still arithmetic.
const RESTLESS_SHARE := 0.25
const RESTLESS_PAY := 2.0

## The keys of the camp `make` builds. `GOLD`, `XP` and `KILLS` are a second's worth there, and what
## the camp came to in `earned`'s answer.
const MOST := "most"
const SINCE := "since"
const CELL := "cell"
const PLACE := "place"
const GOLD := "gold"
const XP := "xp"
const KILLS := "kills"
## The keys of `finds`' answer.
const ITEMS := "items"
const ORBS := "orbs"


## One `step` of `fight` played actively: the clicks it holds, then the clock. `click` is the part of
## a click owed from the step before, and the answer the part owed to the next.
static func _play(fight: Encounter, click: float, step: float) -> float:
	click += step * CLICK_RATE
	while click >= 1.0:
		fight.hit()
		click -= 1.0
	fight.advance(step)
	return click


## What `fight` earns a second, played actively and cut to `IDLE_SHARE`: gold, experience and bodies.
## It plays the fight out, so hand it one that is armed and endless and then throw it away.
static func rates(fight: Encounter) -> Dictionary:
	var spent := 0.0
	var click := 0.0
	while spent < SAMPLE_MOST and (spent < SAMPLE_SECONDS or fight.kills() < SAMPLE_KILLS):
		click = _play(fight, click, SAMPLE_STEP)
		spent += SAMPLE_STEP
	var share := IDLE_SHARE / spent
	return {GOLD: fight.gold * share, XP: float(fight.xp) * share, KILLS: float(fight.kills()) * share}


## The camp: where it stands, what it is called, when it was made, what it earns a second and the
## `hours` it holds. Everything `earned` needs.
static func make(cell: Vector2i, place: String, fight: Encounter, at: float,
		hours := float(WallUnlocks.camp_hours(0))) -> Dictionary:
	var earns := rates(fight)
	var restless := Curses.effect(Curses.RESTLESS) in fight.effects
	# The body armour's Camp Earnings on top of the sample, which played the run and not the camp: more
	# of everything, the bodies and so the finds too. Restless pays the gold and the experience alone.
	var more := 1.0 + fight.camp_more / 100.0
	var pay := (RESTLESS_PAY if restless else 1.0) * more
	return {
		SINCE: int(at),
		CELL: [cell.x, cell.y],
		PLACE: place,
		GOLD: float(earns[GOLD]) * pay,
		XP: float(earns[XP]) * pay,
		KILLS: float(earns[KILLS]) * more,
		MOST: hours * 3600.0 * (RESTLESS_SHARE if restless else 1.0),
	}


## What a camp has earned by `at`: the seconds it has stood (capped), and the rates times those, in
## whole coins, experience and bodies -- a purse with a fraction in it reads as a coin it cannot pay.
## `full` is whether the cap is what stopped it, which the screen must say.
static func earned(camp: Dictionary, at: float) -> Dictionary:
	var most := float(camp.get(MOST, WallUnlocks.camp_hours(0) * 3600.0))
	var spent := clampf(at - float(camp.get(SINCE, at)), 0.0, most)
	return {
		"seconds": spent,
		"full": spent >= most,
		GOLD: floorf(float(camp.get(GOLD, 0.0)) * spent),
		XP: int(float(camp.get(XP, 0.0)) * spent),
		KILLS: int(float(camp.get(KILLS, 0.0)) * spent),
	}


## What the camp's `kills` bodies dropped: `fight`, the run `make` sampled, played on until that many
## more have fallen, so every rule over a drop is the fight's own (the gear's rates, a crit kill, a
## unique's, a curse's, the tile's). {`ITEMS`: Array[Item], `ORBS`: kind -> count}, judged by nobody:
## the main scene asks the player's rule of each. A fight that drops only what it was handed
## (`main_scene._hand_drops`) is how a camp is kept from a kind of find.
static func finds(fight: Encounter, kills: int) -> Dictionary:
	var items: Array[Item] = []
	var orbs := {}
	# A body going down as the sample ended dropped before anyone listened: it is none of the camp's.
	var until := fight.kills() + kills + (1 if fight.phase == Encounter.Phase.DYING else 0)
	# By its place in the run: a body past the count can fall in the step the last of them leaves in.
	var keep := func(index: int, item: Item) -> void:
		if index < until:
			items.append(item)
	var count := func(index: int, orb: String) -> void:
		if index < until:
			orbs[orb] = int(orbs.get(orb, 0)) + 1
	fight.loot_dropped.connect(keep)
	fight.orb_dropped.connect(count)
	# The slowest pace the sample takes for a hunt, so a run that has stopped killing cannot loop.
	var most := float(kills) * SAMPLE_MOST / SAMPLE_KILLS
	var spent := 0.0
	var click := 0.0
	while fight.kills() < until and spent < most:
		click = _play(fight, click, FINDS_STEP)
		spent += FINDS_STEP
	fight.loot_dropped.disconnect(keep)
	fight.orb_dropped.disconnect(count)
	return {ITEMS: items, ORBS: orbs}


## Where the camp stands. Saved as a pair of numbers because a Vector2i does not survive JSON.
static func cell_of(camp: Dictionary) -> Vector2i:
	var at: Variant = camp.get(CELL, [])
	if typeof(at) != TYPE_ARRAY or at.size() != 2:
		return Vector2i.ZERO
	return Vector2i(int(at[0]), int(at[1]))


## "3h 12m", "12m 30s", "45s".
static func spell_time(seconds: float) -> String:
	var whole := int(seconds)
	if whole >= 3600:
		return "%dh %dm" % [whole / 3600, (whole % 3600) / 60]
	if whole >= 60:
		return "%dm %ds" % [whole / 60, whole % 60]
	return "%ds" % whole
