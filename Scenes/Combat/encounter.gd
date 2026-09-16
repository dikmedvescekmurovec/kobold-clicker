class_name Encounter
extends RefCounted
## One tile's fight: a lineup of enemies, one clock, one point of damage per click -- or a farm run,
## which is the same fight with the count and the clock taken off it.
##
## Enemies come out one at a time. Each runs in, stands to be hit, and dies; the next follows. Most
## of them are wandering rabble, with an elite every `elite_every`, so every fight ends on something
## worth the name.
##
## How long the lineup is, how long the clock runs and how the tiers fall are the tile's own, from
## PROFILES: open land and roads field ten in thirty seconds ending on an elite, and a settlement is
## a set piece -- fifteen in a minute, an elite every fifth and a boss last. That is the only place a
## boss is ever rolled.
##
## Each kill rolls for loot against LootTable, and what drops is kept whatever the fight does next.
## Every kill also hands over a purse, which is not rolled for at all -- see `gold_of`.
##
## Nothing the enemies do can hurt the player: the clock is the only way to lose. Beat the lineup
## inside `seconds` and the tile is discovered; run out and nothing happens, the tile stays grey and
## can be tried again. A tile's lineup is seeded from its cell, so the same tile always fields the
## same fight, the way everything else about a tile is decided before the player ever reaches it.
##
## A farm run (`farm()`) is `endless`: the lineup grows an enemy at a time and is never done, the
## clock never runs, and the only ways out are `stop()` and `give_up()`. Nothing about it is seeded
## from the cell -- a tile always fields the same lineup, and never the same run twice. It keeps the
## tile's elite rhythm and never its boss.
##
## The rules live here with no nodes in sight, so a test can play a whole fight in a few lines --
## `advance(delta)` steps the clock the way PlayerToken.advance steps a walk. CombatScene draws it.

## The next enemy has started running in, and is not yet in reach. `index` counts from 0, so the
## elite is at each `elite_every`. The first one is announced by `start()`.
signal enemy_coming(index: int, enemy_name: String, hp: int)
## That enemy has arrived and can now be hit.
signal enemy_spawned(index: int, enemy_name: String, hp: int)
## The enemy took a hit and has this much health left.
signal enemy_hit(hp_left: int)
## A blow landed, for whoever is drawing the fight: how much it was worth, whether it crit, and
## whether the weapon swung it rather than the player. Separate from `enemy_hit` because that one
## says what the enemy has left and this one says what the player just did.
signal hit_landed(amount: int, crit: bool, automatic: bool)
## The enemy's health reached zero; its death plays before the next one comes out.
signal enemy_died(index: int)
## That enemy was carrying something. Emitted with the death, so the drop reads as coming off the
## body, and kept whatever the fight does afterwards: running out of time loses the tile, not what is
## already on the ground.
signal loot_dropped(index: int, item: Item)
## That enemy was carrying a purse, which every one of them is. Emitted with the death beside
## `loot_dropped`, and kept for the same free reason: nothing is rolled when the clock runs out, so
## what came off a body before it is the player's however the fight ends.
signal gold_dropped(index: int, amount: int)
## That enemy was carrying an orb, which about one in twenty is. Rolled beside the gear rather than
## against it, so one body can hand over both, and kept for the reason the other two are: nothing is
## rolled when the clock runs out, so what came off a body before it is the player's.
signal orb_dropped(index: int, orb: String)
## That enemy's experience, which every one of them carries the way it carries a purse. Emitted with
## the death beside `gold_dropped` and kept for the same reason.
signal xp_dropped(index: int, amount: int)
## The whole lineup is down, with time to spare.
signal won()
## The clock ran out.
signal lost()

## Enemies to beat on an ordinary tile: the first ENEMIES - 1 are common, the last is the elite.
const ENEMIES := 10
## One elite every this many enemies on an ordinary tile. It is what makes the tenth of a tile fight
## the elite, and it carries that rhythm on forever through a farm run.
const ELITE_EVERY := 10
## How long an ordinary tile's fight runs. One clock, from the first spawn and never stopping.
const SECONDS := 30.0

## What a fight is, per what the world put on the tile -- `MapBuilder.area_variant`, which the main
## scene already reads to pick the backdrop and now reads to pick the fight. Open land and a road
## are the ordinary fight; a settlement is a set piece, and the three tiers share one entry because
## what makes a town longer is that people live there, not how many of them.
##
## One table, so "a town is a longer fight" is written down once. `boss_last` is the only thing that
## rolls a boss anywhere in the game: they are saved for this.
const ORDINARY := {"enemies": ENEMIES, "seconds": SECONDS, "elite_every": ELITE_EVERY, "boss_last": false}
const SETTLEMENT := {"enemies": 15, "seconds": 60.0, "elite_every": 5, "boss_last": true}
const PROFILES := {
	"plain": ORDINARY,
	"road": ORDINARY,
	"village": SETTLEMENT,
	"town": SETTLEMENT,
	"fortress": SETTLEMENT,
}
## Health of an ordinary body on a tile next to the start, before the enemy's own size and tier.
## Tuned against a player with nothing on, who does BARE_DAMAGE a click and has no weapon swinging
## for them: ten bodies at this health is a minute of steady clicking and not much room spare. Gear
## is what buys the room, which is the point of it.
const BASE_HP := 7
## What one hex step out from the middle of the map multiplies that by. Exponential rather than a
## flat addition, so the frontier pulls away from whatever the player is carrying and farming a tile
## already taken is the way to catch up. The dial for how fast that happens.
const HP_GROWTH := 1.18

## What a body is carrying, on a tile next to the start. An ordinary common one at the very middle
## of the map is worth exactly BASE_GOLD, which is where the whole curve is pinned.
const BASE_GOLD := 1.0
## The linear half of how a purse grows with the walk: this much more gold a hex step, before the
## exponent. It is what keeps the first few tiles from all paying the same, where an exponent barely
## moves.
const GOLD_PER_STEP := 1.0
## And the exponential half. Set near LootTable.LEVEL_GROWTH rather than near HP_GROWTH, so a purse
## keeps pace with the gear that has to kill for it rather than with the health it has to get
## through. Nothing spends gold yet, so the two above are a starting point and a pair of dials.
const GOLD_GROWTH := 1.12

## What an ordinary common body is worth in experience, per level of the tile it stands on. Off the
## banded `MapBuilder.level_of` rather than the smooth distance gold uses, and linear rather than
## exponential, on purpose: the bands widen, so an exponent per hex step compounds with the square of
## the level and would soon pay for a whole level in one body. Linear in the tile's level is what
## lets `PlayerLevel.xp_to_next` outgrow it everywhere -- see there.
const XP_PER_LEVEL := 1.0

## What a click does with nothing equipped. The floor under `damage`, so a player who has never
## found a sword can still take the first tile -- and so the number a click does is never zero.
const BARE_DAMAGE := 1
## Seconds an enemy spends running in, before it can be hit.
const WALK_IN := 0.6
## Seconds its death plays out, before the next one comes on.
const DEATH := 0.5

## What the current enemy is doing. Hits only land while it is WAITING.
enum Phase { WALKING_IN, WAITING, DYING, OVER }

## What shape of fight this is, from the profile the tile's variant names. Fields rather than consts
## because a settlement fights a longer fight than the meadow next to it; the defaults are the
## ordinary tile's, so a fight nobody tells anything is exactly the fight this has always been --
## which is what every Encounter built by hand (the tests, the screenshot scripts) gets.
## `enemies` and `seconds` mean nothing while `endless`; `elite_every` is the whole rhythm there.
var enemies := ENEMIES
var seconds := SECONDS
var elite_every := ELITE_EVERY
## Whether the last of them is a boss. Never true of a farm run: a run has no last enemy, and a boss
## is the thing a set piece ends on rather than a thing that comes round again.
var boss_last := false

## The enemies of this fight, in the order they come out. `enemies` long for a tile fight; a farm run
## grows it an enemy at a time and it is never finished.
var lineup: PackedStringArray = []
## The health each of them starts with, in the same order. Always as long as `lineup`.
var health: PackedInt32Array = []

## The tile this is fought on. Kept because a farm run picks its enemies as it goes and every one
## of them is sized against the distance from the middle of the map.
var cell := Vector2i.ZERO
## Whether the enemies never run out: no count to beat and no clock to beat it in.
var endless := false

## Which one is out, from 0. Reaches `enemies` once the last of a tile fight is down; endlessly it is
## simply the number already slain.
var index := 0
## The current enemy's remaining health.
var hp := 0
var phase := Phase.WALKING_IN
## Seconds left on the clock. Untouched while `endless` -- a farm run has no clock to spend.
var time_left := SECONDS
## Whether the fight ended, and how. `finished` is set for a loss as well as a win.
var finished := false
var victory := false

## Seconds left of the walking-in or dying that is under way. The scene slides the enemy in over it.
var phase_left := WALK_IN

## Loot belongs to the attempt, not to the tile. The enemies are the tile's, decided before the
## player ever reaches it, but what they happen to be carrying is rolled fresh each fight, so a tile
## fought twice is not a fixed payout. Unseeded on purpose: RandomNumberGenerator seeds itself
## randomly, so there is no randomize() to add here. Tests set the seed before they play.
var loot_rng := RandomNumberGenerator.new()

## What this fight has earned. Every body carries a purse -- there is no chance drawn for it and no
## rng behind it -- so unlike the drops this is simply a sum, and the verdict reads it off here.
var gold := 0
## What this fight has earned in experience: a sum, like `gold`.
var xp := 0

## The orb roll, drawn beside the gear roll and never from the same generator: two rates that are
## tuned apart should not be able to shift each other by changing how many numbers one of them draws.
## Unseeded for the same reason `loot_rng` is -- what a body happens to carry belongs to the attempt.
var orb_rng := RandomNumberGenerator.new()

## What currency this fight has turned up: orb name -> how many. The verdict counts it; the bag takes
## it when the fight ends, or as it lands, which is the scene's business rather than this one's.
var orbs := {}

## Which enemy comes next in a farm run. Unseeded for the same reason `loot_rng` is: a tile's lineup
## is decided before the player arrives and a run is not, so two runs on one tile field different
## enemies. A tile fight never touches it -- `for_tile` passes its own seeded generator.
var roster_rng := RandomNumberGenerator.new()

## What the player is worth in a fight -- gear and skills together, `Inventory.stats()` -- read once by
## `arm()` rather than looked up per swing. Only the ones below are read: the rest of what an item
## carries is still rolled, saved and shown, and waits on the systems that would give it something to
## do. Four decide what a blow is worth; the rest decide what a body leaves.
## The ceiling on crit chance: crits stay something that happens sometimes, however much gear is
## piled up. A chance over certainty is every hit critting, which is a crit meaning nothing.
const CRIT_CAP := 100.0
var damage := BARE_DAMAGE
var crit_chance := 0.0
var crit_damage := 0.0
## Swings a second the weapon takes on its own. Zero with nothing equipped, so a bare-handed fight is
## exactly the clicking game this was before gear meant anything.
var attack_speed := 0.0
## How much more often a body leaves something, as a percentage: 50 is half again as much gear. Read
## here and handed to `LootTable.roll`, which is where the cap on a chance already lives.
var drop_rate := 0.0
## What the player's skills add to what a body leaves, all three in percent: how far up the rarity ramp
## a find is pushed, how much fuller a purse is, and how much more often an orb falls.
var item_rarity := 0.0
var gold_find := 0.0
var orb_find := 0.0

## How much of the next automatic swing has been earned. Only runs while an enemy is standing there
## to be hit, so a slow weapon loses nothing to a walk-in and cannot bank swings through a death.
var _swing := 0.0

## Whether crits go the player's way. Unseeded on purpose, like `loot_rng` and for the same reason:
## the tile's enemies are fixed before the player arrives, but how a given attempt goes is not.
var crit_rng := RandomNumberGenerator.new()

## The terrain the fight is on. It picked the enemies, and it picks the backdrop they are drawn on.
var env := ""
## Whether the elite that ends this fight is promised a drop. The main scene turns it on while the
## player has yet to see their first, so the first real fight hands something over.
var guarantee_elite := false

## Whether every body drops something. Nothing in the game turns this on: it is for the tests and the
## screenshot scripts, which want a pouch with several things in it and would otherwise have to grind
## out the hundred-odd kills a 3% chance takes to get there. It goes through LootTable's `guaranteed`
## like the promised elite drop does, so what falls is rolled the ordinary way -- the certainty is
## about getting something, not about what.
var always_drop := false

## The same knob for orbs, and separate from `always_drop` because the two rates are separate: a test
## about crafting wants orbs and no gear, and a test about the pouch wants gear and no orbs.
var always_orb := false


## The profile for an area variant, falling back to the ordinary fight: a variant this build has no
## entry for is open land as far as the fight is concerned, which is what the backdrop does too.
static func profile_for(variant: String) -> Dictionary:
	return PROFILES.get(variant, ORDINARY)


## The fight waiting on `cell`, whose terrain is `env` and whose `variant` is what the world put
## there. Commons with an elite at each pitch, drawn from the enemies that live on that terrain and
## seeded from the cell, so the tile always fields the same fight.
static func for_tile(cell: Vector2i, env: String, variant := "") -> Encounter:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["combat", cell])
	var fight := Encounter.new()
	fight.env = env
	fight.cell = cell
	fight._take_profile(profile_for(variant))
	for i in fight.enemies:
		fight._append_enemy(rng)
	fight.hp = fight.health[0]
	return fight


## A farm run on `cell`: the same enemies the tile's terrain fields, coming forever, with no clock
## and no count. It ends when the player says so.
##
## It keeps the tile's own elite rhythm -- a run on a town throws one up every five -- and never its
## boss: a boss is what a set piece ends on, and a run does not end.
static func farm(cell: Vector2i, env: String, variant := "") -> Encounter:
	var fight := Encounter.new()
	fight.env = env
	fight.cell = cell
	fight.endless = true
	fight.elite_every = int(profile_for(variant)["elite_every"])
	fight._append_enemy(fight.roster_rng)
	fight.hp = fight.health[0]
	return fight


## Takes on a profile's numbers, clock included. The one place a fight is told what shape it is.
func _take_profile(profile: Dictionary) -> void:
	enemies = int(profile["enemies"])
	seconds = float(profile["seconds"])
	elite_every = int(profile["elite_every"])
	boss_last = bool(profile["boss_last"])
	time_left = seconds


## What tier belongs at `position` in this fight's lineup: the boss that ends a set piece, an elite
## every `elite_every`, a common otherwise. Asked of the position rather than of an enemy, so it can
## answer for a place a farm run has not filled yet -- which is how the HUD's bar draws the pips of
## a cycle before their enemies exist.
func tier_for(position: int) -> EnemyRoster.Tier:
	if boss_last and position == enemies - 1:
		return EnemyRoster.Tier.BOSS
	if position % elite_every == elite_every - 1:
		return EnemyRoster.Tier.ELITE
	return EnemyRoster.Tier.COMMON


## The tier of whatever stands at `at` in this fight. Asked of the roster where that enemy has been
## rolled, because that is what actually walks in, and of the position otherwise, which is the only
## answer available for the far end of a farm run's lineup. The two agree by construction --
## `_append_enemy` builds the lineup to `tier_at` -- and test_combat pins that they do.
##
## Both things in the HUD that speak in tiers read it here: the kill pips colour their pips by it and
## the nameplate picks its frame by it, and a fight where those two disagreed about what is standing
## in front of the player would be worse than either of them being wrong alone.
static func tier_in(fight: Encounter, at: int) -> EnemyRoster.Tier:
	if at < fight.lineup.size():
		return EnemyRoster.tier_of(fight.lineup[at])
	return fight.tier_for(at)


## Puts one more enemy on the end of the lineup, with the health it starts with. The one place that
## knows how an enemy joins a fight, so a tile's lineup and a farm run's thousandth enemy are built
## the same way -- `tier_for`, and nothing else.
func _append_enemy(rng: RandomNumberGenerator) -> void:
	var tier := tier_for(lineup.size())
	var picked := EnemyRoster.pick(env, tier, rng)
	if picked.is_empty():
		# No enemy of that tier lives here. test_enemies guarantees there is one for every
		# environment the map can generate, so this only fires on terrain that isn't real.
		push_error("No tier %d enemy lives on %s" % [tier, env])
		picked = EnemyRoster.names()[0]
	lineup.append(picked)
	health.append(hp_of(picked, cell))


## Announces the first enemy, so whoever is drawing the fight can put it on the field. Safe to call
## more than once; a fight that is never started simply never announces anyone.
func start() -> void:
	enemy_coming.emit(index, lineup[index], hp)


## What one enemy is worth on this tile: an ordinary body grows with the distance from the middle of
## the map, and the enemy's own size and tier multiply it (a slime halves it, an elite trebles it).
static func hp_of(enemy_name: String, cell: Vector2i) -> int:
	return maxi(1, roundi(base_hp(cell) * EnemyRoster.hp_modifier(enemy_name)))


## The health of an ordinary common body on this tile, before the enemy's own multiplier.
static func base_hp(cell: Vector2i) -> int:
	return maxi(1, roundi(BASE_HP * pow(HP_GROWTH, HexGrid.distance(MapBuilder.CENTER, cell))))


## What an ordinary common body on this tile is carrying, before its own multiplier. Grows with the
## walk both ways at once: a step adds GOLD_PER_STEP and multiplies by GOLD_GROWTH.
##
## The distance is the smooth one `base_hp` uses and not the banded `MapBuilder.level_of` -- a purse
## is what this body was worth, and two tiles at opposite ends of one level band are not worth the
## same. At the very middle no steps have been taken, so this is BASE_GOLD exactly.
static func base_gold(cell: Vector2i) -> int:
	var steps := HexGrid.distance(MapBuilder.CENTER, cell)
	return maxi(1, roundi((BASE_GOLD + GOLD_PER_STEP * steps) * pow(GOLD_GROWTH, steps)))


## What one enemy is carrying: the tile's purse times what the body was worth to kill. The same
## `hp_modifier` its health is built from, so a thing that took four times the clicking hands over
## four times the gold and nobody has to keep a second table in step with the first. Floored at 1,
## which is what keeps a slime (half an ordinary body) from rounding away to nothing.
static func gold_of(enemy_name: String, cell: Vector2i) -> int:
	return maxi(1, roundi(base_gold(cell) * EnemyRoster.hp_modifier(enemy_name)))


## What an ordinary common body on this tile is worth in experience: XP_PER_LEVEL a level of the tile.
static func base_xp(cell: Vector2i) -> int:
	return maxi(1, roundi(XP_PER_LEVEL * MapBuilder.level_of(cell)))


## What one enemy is worth in experience: the tile's base times what the body was worth to kill,
## floored at 1 for the reason `gold_of` is.
static func xp_of(enemy_name: String, cell: Vector2i) -> int:
	return maxi(1, roundi(base_xp(cell) * EnemyRoster.hp_modifier(enemy_name)))


## The name of the enemy that is out, or "" once the fight is over.
func enemy_name() -> String:
	return "" if index >= lineup.size() else lineup[index]


## The health the current enemy started with, for drawing a bar against `hp`.
func enemy_max_hp() -> int:
	return 0 if index >= lineup.size() else health[index]


## Whether the enemy out now is an elite -- the one that ends a tile fight, or one of the elites a
## farm run throws up every `elite_every`. Asked of the roster rather than of the position, so it is
## the same question in both fights.
func on_elite() -> bool:
	return index < lineup.size() and EnemyRoster.tier_of(lineup[index]) == EnemyRoster.Tier.ELITE


## Enemies still to beat, the one out now included. Meaningless while `endless`, where `kills()` is
## the number the fight has to show instead.
func remaining() -> int:
	return enemies - index


## How many have been put down. Endlessly this is the whole of the score.
func kills() -> int:
	return index


## A click. Takes a point off the enemy in front of the player, and kills it at zero. Ignored while
## one is running in or dying, and once the fight is over. Returns whether it landed.
func hit() -> bool:
	return _strike(false)


## What the player's gear is worth, from `Equipment.totals()`. Called before the fight starts; a
## fight nobody arms is a bare-handed one, which is what every test that does not care gets.
func arm(stats: Dictionary) -> void:
	damage = maxi(BARE_DAMAGE, roundi(float(stats.get("damage", 0.0))) + BARE_DAMAGE)
	# Clamped, because a chance is not a quantity: eight pieces each adding crit chance can total
	# more than certainty, and a save written before LootTable.CHANCE_STATS holds pieces that do it on
	# their own. Past the cap every hit crit, which is a crit meaning nothing.
	crit_chance = clampf(float(stats.get("crit_chance", 0.0)), 0.0, CRIT_CAP)
	crit_damage = float(stats.get("crit_damage", 0.0))
	attack_speed = maxf(0.0, float(stats.get("attack_speed", 0.0)))
	drop_rate = maxf(0.0, float(stats.get("drop_rate", 0.0)))
	item_rarity = maxf(0.0, float(stats.get("item_rarity", 0.0)))
	gold_find = maxf(0.0, float(stats.get("gold_find", 0.0)))
	orb_find = maxf(0.0, float(stats.get("orb_find", 0.0)))


## One blow, from a click or from the weapon swinging itself. Takes `damage` off the enemy in front
## of the player, crits at `crit_chance`, and kills it at zero. Ignored while one is running in or
## dying, and once the fight is over. Returns whether it landed.
func _strike(automatic: bool) -> bool:
	if finished or phase != Phase.WAITING:
		return false
	var crit := crit_chance > 0.0 and crit_rng.randf() * 100.0 < crit_chance
	# Crit damage is what a crit adds, not what it multiplies to: 50 means half again, the way Path
	# of Exile's crit multiplier reads once you take its base 100 off.
	var dealt := maxi(1, roundi(damage * (1.0 + crit_damage / 100.0))) if crit else damage
	hp -= dealt
	hit_landed.emit(dealt, crit, automatic)
	enemy_hit.emit(hp)
	if hp <= 0:
		phase = Phase.DYING
		phase_left = DEATH
		_swing = 0.0
		enemy_died.emit(index)
		# The only path to a death, which is why drops survive a loss for free: nothing is rolled
		# when the clock runs out.
		# The tile's level is the ceiling on what can fall here, not what falls -- the drop rolls its
		# own level under it, so fighting deeper improves the odds rather than the prize.
		var dropped := LootTable.roll(lineup[index], loot_rng,
				always_drop or (guarantee_elite and on_elite()), MapBuilder.level_of(cell),
				drop_rate, item_rarity)
		if dropped != null:
			loot_dropped.emit(index, dropped)
		# Every body carries one, which is the whole difference between gold and gear: nine kills in
		# ten leave nothing, and all ten leave this.
		# Gold find lifts the purse here rather than inside `gold_of`, which is what the body is worth
		# and is read by things that have no player in them.
		var purse := maxi(1, roundi(gold_of(lineup[index], cell) * (1.0 + gold_find / 100.0)))
		gold += purse
		gold_dropped.emit(index, purse)
		var worth := xp_of(lineup[index], cell)
		xp += worth
		xp_dropped.emit(index, worth)
		# A third draw, on its own generator and its own curve. Beside the gear rather than instead
		# of it: a body that left a sword can leave an orb too, which is what makes the two rates
		# independent numbers rather than one number split.
		var orb := OrbTable.roll(lineup[index], orb_rng, always_orb, orb_find)
		if not orb.is_empty():
			orbs[orb] = int(orbs.get(orb, 0)) + 1
			orb_dropped.emit(index, orb)
	return true


## Runs the clock, and the walking-in and dying that the clock runs through. Called every frame by
## CombatScene; tests drive it themselves.
func advance(delta: float) -> void:
	if finished:
		return
	if not endless:
		time_left = maxf(time_left - delta, 0.0)
	while not finished and phase != Phase.WAITING and delta > 0.0:
		# A phase that ends part-way through the frame hands the rest of the frame to the next one.
		if delta < phase_left:
			phase_left -= delta
			break
		delta -= phase_left
		_advance_phase()
	_swing_weapon(delta)
	if not endless and time_left <= 0.0 and not finished:
		_finish(false)


## The weapon swinging on its own, `attack_speed` times a second. Only earns while an enemy is
## standing there to be hit, so nothing accrues through a walk-in or a death and a fast weapon
## cannot arrive at the next body with a fistful of banked swings.
func _swing_weapon(delta: float) -> void:
	if attack_speed <= 0.0 or finished or phase != Phase.WAITING:
		return
	_swing += delta * attack_speed
	while _swing >= 1.0 and phase == Phase.WAITING and not finished:
		_swing -= 1.0
		_strike(true)


## Ends the fight at once, however much of it is left. For tests and for leaving early.
func give_up() -> void:
	if not finished:
		_finish(false)


## Ends a run on the player's say-so. Not a loss: a farm run is not something that can be lost, only
## something the player decides is over, and the kills and the loot are theirs either way.
func stop() -> void:
	if not finished:
		_finish(true)


## The walking-in or dying that just ran out: the enemy either takes its stand or leaves the field.
func _advance_phase() -> void:
	if phase == Phase.WALKING_IN:
		phase = Phase.WAITING
		enemy_spawned.emit(index, lineup[index], hp)
		return
	index += 1
	if index >= lineup.size():
		if not endless:
			_finish(true)
			return
		# The next one is decided the moment the last one falls, so a run never runs dry.
		_append_enemy(roster_rng)
	hp = health[index]
	phase = Phase.WALKING_IN
	phase_left = WALK_IN
	enemy_coming.emit(index, lineup[index], hp)


func _finish(win: bool) -> void:
	finished = true
	victory = win
	phase = Phase.OVER
	if win:
		won.emit()
	else:
		lost.emit()
