class_name Encounter
extends RefCounted
## One tile's fight: ten enemies, one clock, one point of damage per click.
##
## Enemies come out one at a time. Each runs in, stands to be hit, and dies; the next follows. Nine of
## them are wandering rabble and the tenth is an elite, so every fight ends on something worth the
## name. Bosses are never rolled here -- they are saved for set pieces.
##
## Nothing the enemies do can hurt the player: the clock is the only way to lose. Beat all ten inside
## SECONDS and the tile is discovered; run out and nothing happens, the tile stays grey and can be
## tried again. A tile's ten are seeded from its cell, so the same tile always fields the same fight,
## the way everything else about a tile is decided before the player ever reaches it.
##
## The rules live here with no nodes in sight, so a test can play a whole fight in a few lines --
## `advance(delta)` steps the clock the way PlayerToken.advance steps a walk. CombatScene draws it.

## A new enemy has walked in and can be hit. `index` counts from 0, so the elite is ENEMIES - 1.
signal enemy_spawned(index: int, enemy_name: String, hp: int)
## The enemy took a hit and has this much health left.
signal enemy_hit(hp_left: int)
## The enemy's health reached zero; its death plays before the next one comes out.
signal enemy_died(index: int)
## All ten are down, with time to spare.
signal won()
## The clock ran out.
signal lost()

## Enemies to beat: the first ENEMIES - 1 are common, the last is the elite.
const ENEMIES := 10
## How long for all ten together. One clock, running from the first spawn and never stopping.
const SECONDS := 60.0
## Health of an ordinary body on a tile next to the start, before the enemy's own size and tier.
const BASE_HP := 3
## Added to that per hex step from the middle of the map, so the frontier is where fights get hard.
const HP_PER_STEP := 1
## Seconds an enemy spends running in, before it can be hit.
const WALK_IN := 0.6
## Seconds its death plays out, before the next one comes on.
const DEATH := 0.5

## What the current enemy is doing. Hits only land while it is WAITING.
enum Phase { WALKING_IN, WAITING, DYING, OVER }

## The ten enemies of this fight, in the order they come out.
var lineup: PackedStringArray = []
## The health each of them starts with, in the same order.
var health: PackedInt32Array = []

## Which of the ten is out, from 0. Reaches ENEMIES once the last one is down.
var index := 0
## The current enemy's remaining health.
var hp := 0
var phase := Phase.WALKING_IN
## Seconds left on the clock.
var time_left := SECONDS
## Whether the fight ended, and how. `finished` is set for a loss as well as a win.
var finished := false
var victory := false

var _phase_left := WALK_IN


## The fight waiting on `cell`, whose terrain is `env`. Nine commons and an elite, drawn from the
## enemies that live on that terrain and seeded from the cell, so the tile always fields the same ten.
static func for_tile(cell: Vector2i, env: String) -> Encounter:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["combat", cell])
	var fight := Encounter.new()
	for i in ENEMIES:
		var tier := EnemyRoster.Tier.ELITE if i == ENEMIES - 1 else EnemyRoster.Tier.COMMON
		var picked := EnemyRoster.pick(env, tier, rng)
		if picked.is_empty():
			# No enemy of that tier lives here. test_enemies guarantees there is one for every
			# environment the map can generate, so this only fires on terrain that isn't real.
			push_error("No tier %d enemy lives on %s" % [tier, env])
			picked = EnemyRoster.names()[0]
		fight.lineup.append(picked)
		fight.health.append(hp_of(picked, cell))
	fight.hp = fight.health[0]
	return fight


## What one enemy is worth on this tile: an ordinary body grows with the distance from the middle of
## the map, and the enemy's own size and tier multiply it (a slime halves it, an elite trebles it).
static func hp_of(enemy_name: String, cell: Vector2i) -> int:
	return maxi(1, roundi(base_hp(cell) * EnemyRoster.hp_modifier(enemy_name)))


## The health of an ordinary common body on this tile, before the enemy's own multiplier.
static func base_hp(cell: Vector2i) -> int:
	return BASE_HP + HP_PER_STEP * HexGrid.distance(MapBuilder.CENTER, cell)


## The name of the enemy that is out, or "" once the fight is over.
func enemy_name() -> String:
	return "" if index >= ENEMIES else lineup[index]


## The health the current enemy started with, for drawing a bar against `hp`.
func enemy_max_hp() -> int:
	return 0 if index >= ENEMIES else health[index]


## Whether the enemy out now is the elite that ends the fight.
func on_elite() -> bool:
	return index == ENEMIES - 1


## Enemies still to beat, the one out now included.
func remaining() -> int:
	return ENEMIES - index


## A click. Takes a point off the enemy in front of the player, and kills it at zero. Ignored while
## one is running in or dying, and once the fight is over. Returns whether it landed.
func hit() -> bool:
	if finished or phase != Phase.WAITING:
		return false
	hp -= 1
	enemy_hit.emit(hp)
	if hp <= 0:
		phase = Phase.DYING
		_phase_left = DEATH
		enemy_died.emit(index)
	return true


## Runs the clock, and the walking-in and dying that the clock runs through. Called every frame by
## CombatScene; tests drive it themselves.
func advance(delta: float) -> void:
	if finished:
		return
	time_left = maxf(time_left - delta, 0.0)
	while not finished and phase != Phase.WAITING and delta > 0.0:
		# A phase that ends part-way through the frame hands the rest of the frame to the next one.
		if delta < _phase_left:
			_phase_left -= delta
			break
		delta -= _phase_left
		_advance_phase()
	if time_left <= 0.0 and not finished:
		_finish(false)


## Ends the fight at once, however much of it is left. For tests and for leaving early.
func give_up() -> void:
	if not finished:
		_finish(false)


## The walking-in or dying that just ran out: the enemy either takes its stand or leaves the field.
func _advance_phase() -> void:
	if phase == Phase.WALKING_IN:
		phase = Phase.WAITING
		enemy_spawned.emit(index, lineup[index], hp)
		return
	index += 1
	if index >= ENEMIES:
		_finish(true)
		return
	hp = health[index]
	phase = Phase.WALKING_IN
	_phase_left = WALK_IN


func _finish(win: bool) -> void:
	finished = true
	victory = win
	phase = Phase.OVER
	if win:
		won.emit()
	else:
		lost.emit()
