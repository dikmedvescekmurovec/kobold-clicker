class_name PlayerLevel
extends RefCounted
## The player's level, and the one place that knows how much experience a level costs.
##
## Nothing reads the level yet -- it is earned, saved and shown, and waits on the systems that would
## give it something to do. What is settled already is the shape of the curve. A body is worth
## `Encounter.XP_PER_LEVEL` a level of its tile, so a level is written as a number of ordinary bodies
## at a tile of that level -- BASE_KILLS, multiplied by LEVEL_XP_GROWTH every level -- times what one
## of those bodies pays. So the cost grows faster than the drops by construction: a player fighting
## at their own level needs LEVEL_XP_GROWTH times the bodies each level, and one who walks further
## out to fight richer tiles only gains linearly on a cost that grows exponentially.

## Ordinary bodies at a level-1 tile the first level takes: about two fights.
const BASE_KILLS := 20
## What each level multiplies that body count by. The dial for how fast levels thin out.
const LEVEL_XP_GROWTH := 1.25


## The experience it takes to go from `level` to the one after it.
static func xp_to_next(level: int) -> int:
	level = maxi(level, 1)
	return maxi(1, roundi(BASE_KILLS * Encounter.XP_PER_LEVEL * level * pow(LEVEL_XP_GROWTH, level - 1)))


## `amount` experience added to a player at `level` holding `xp` towards the next. Overflow carries,
## so one big purse of experience can pay for more than one level. Returns `level`, `xp` (what is held
## towards the level after the new one) and `gained`, how many levels that was.
static func add(level: int, xp: int, amount: int) -> Dictionary:
	level = maxi(level, 1)
	xp = maxi(xp, 0) + maxi(amount, 0)
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	return {"level": level, "xp": xp, "gained": gained}
