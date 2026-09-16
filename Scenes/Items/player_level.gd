class_name PlayerLevel
extends RefCounted
## The player's level, and the one place that knows how much experience a level costs.
##
## The curve is paced by tiles: charting one should be worth about a quarter of a level. A tile fight
## pays about ten ordinary bodies times the tile's level, and tile levels come in bands that widen
## as the map spreads out, so what a tile pays climbs very slowly. The cost only has to climb a
## little faster: BASE_KILLS ordinary level-1 bodies, times LEVEL_XP_GROWTH per level. Charting
## outward ring by ring, that holds at about four tiles a level past level 90.

## Ordinary bodies at a level-1 tile the first level takes: about four first-ring tiles.
const BASE_KILLS := 85
## What each level multiplies that cost by. Higher thins the levels out as the map grows.
const LEVEL_XP_GROWTH := 1.03


## The experience it takes to go from `level` to the one after it.
static func xp_to_next(level: int) -> int:
	level = maxi(level, 1)
	return maxi(1, roundi(BASE_KILLS * Encounter.XP_PER_LEVEL * pow(LEVEL_XP_GROWTH, level - 1)))


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
