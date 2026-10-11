class_name PlayerLevel
extends RefCounted
## What a level costs in experience, and banking it. The curve is paced by tiles: charting one is
## worth about a quarter of a level (DESIGN.md).

## Ordinary level-1 bodies the first level takes.
const BASE_KILLS := 85
## What each level multiplies that cost by, up to `LATE_LEVEL`.
const LEVEL_XP_GROWTH := 1.03
## And what each level past `LATE_LEVEL` does (the user's, 2026-09-29): a kill's worth grows only with
## the land, so the late levels have to stay within reach of farming.
const LATE_LEVEL := 70
const LATE_XP_GROWTH := 1.02


## The experience it takes to go from `level` to the one after it.
static func xp_to_next(level: int) -> int:
	level = maxi(level, 1)
	var growth := pow(LEVEL_XP_GROWTH, mini(level, LATE_LEVEL) - 1) \
			* pow(LATE_XP_GROWTH, maxi(level - LATE_LEVEL, 0))
	return maxi(1, roundi(BASE_KILLS * Encounter.XP_PER_LEVEL * growth))


## Banks `amount` for a player at `level` holding `xp` towards the next; overflow carries over as many
## levels as it pays for. Returns `level`, `xp` (held towards the level after) and `gained` (levels).
static func add(level: int, xp: int, amount: int) -> Dictionary:
	level = maxi(level, 1)
	xp = maxi(xp, 0) + maxi(amount, 0)
	var gained := 0
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		gained += 1
	return {"level": level, "xp": xp, "gained": gained}
