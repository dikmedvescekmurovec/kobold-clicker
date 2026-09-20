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
## inside `seconds` and the tile is charted; run out and nothing happens, the tile stays grey and
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
signal enemy_coming(index: int, enemy_name: String, hp: float)
## That enemy has arrived and can now be hit.
signal enemy_spawned(index: int, enemy_name: String, hp: float)
## The enemy took a hit and has this much health left.
signal enemy_hit(hp_left: float)
## A blow landed, for whoever is drawing the fight: how much it was worth, whether it crit, and
## whether the weapon swung it rather than the player. Separate from `enemy_hit` because that one
## says what the enemy has left and this one says what the player just did.
signal hit_landed(amount: float, crit: bool, automatic: bool)
## The enemy's health reached zero; its death plays before the next one comes out.
signal enemy_died(index: int)
## That enemy was carrying something. Emitted with the death, so the drop reads as coming off the
## body, and kept whatever the fight does afterwards: running out of time loses the tile, not what is
## already on the ground.
signal loot_dropped(index: int, item: Item)
## That enemy was carrying a purse, which every one of them is. Emitted with the death beside
## `loot_dropped`, and kept for the same free reason: nothing is rolled when the clock runs out, so
## what came off a body before it is the player's however the fight ends.
signal gold_dropped(index: int, amount: float)
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
## A treasure chest's tile: the mimic alone, on the ordinary clock. `MapBuilder.has_chest` decides
## where one stands; the mimic is the only enemy it ever fields.
const CHEST := {"enemies": 1, "seconds": SECONDS, "elite_every": 1, "boss_last": true}
const MIMIC := "Mimic"
## A chest is a coin toss: MIMIC_UNIQUE of the time it holds one unique and nothing else, and
## otherwise MIMIC_ROLLS pieces of gear, each certain and rolled the ordinary way.
const MIMIC_UNIQUE := 0.5
const MIMIC_ROLLS := 4
## The most pieces one body can leave off its own chance: a find rolls again, and the find after it
## rolls again, until a roll misses or this many have fallen. The cap is what keeps a drop rate at
## `LootTable.chance_for`'s ceiling -- which a boss reaches -- from rolling for ever.
const MOST_DROPS := 4
## The ice wall round the land: one body, a long clock, and far more health than its ring would give
## anything else -- it is the check on whether the player is ready for the land past it.
const WALL := {"enemies": 1, "seconds": 60.0, "elite_every": 1, "boss_last": true}
const WALL_NAME := "The Ice Wall"
## What the wall's health is multiplied by on top of its boss body. The dial for how hard the wall is,
## and a steep one with cliffs: `tests/balance_wall.gd` plays it out -- 33 is about 850 kills, 34 already 1600.
const WALL_HP := 33.0
## What every wall already fallen multiplies the health of everything behind it by -- the whole land it
## opened as well as the next wall, through `base_hp`. So the land past the first wall is ten times the
## land inside it and the wall on ring 21 is ten times the one on 11, the one on 31 a hundred.
##
## The land needs the step as much as the wall does: felling a wall means about forty times the damage
## a second that the land inside it asks for (a wall is `WALL_HP` over a boss body, some 930 commons,
## in a minute), and a band of ten rings only grows by `HP_GROWTH ^ 10`, about five. Without the step
## everything behind a fallen wall died to one click for ever. With it, a wall is crossed with roughly
## four times the power the new band's first ring wants, the band's own curve eats that, and the next
## wall is again the same forty-times check -- every band the same shape as the first.
##
## The first wall is a day's farming; the second is meant to be out of reach of farming altogether --
## at 1 it was twenty hours' worth, or two with the right uniques on.
const WALL_GROWTH := 10.0
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
## keeps a tile's worth of experience growing slowly enough for `PlayerLevel.xp_to_next` to pace it -- see there.
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
## The health each of them starts with, in the same order. Always as long as `lineup`. Whole numbers
## in doubles rather than ints: health climbs exponentially with the walk and would pass int64 a few
## hundred hexes out on a map that has no edge.
var health: PackedFloat64Array = []

## The tile this is fought on. Kept because a farm run picks its enemies as it goes and every one
## of them is sized against the distance from the middle of the map.
var cell := Vector2i.ZERO
## Whether the enemies never run out: no count to beat and no clock to beat it in.
var endless := false

## Which one is out, from 0. Reaches `enemies` once the last of a tile fight is down; endlessly it is
## simply the number already slain.
var index := 0
## The current enemy's remaining health.
var hp := 0.0
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
## rng behind it -- so unlike the drops this is simply a sum, and the verdict reads it off here. A
## whole number in a double, for the reason `health` is.
var gold := 0.0
## What this fight has earned in experience: a sum, like `gold`. An int, because experience is linear
## in the tile's level rather than exponential in the walk and has nowhere near int64 to climb.
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
## do. Five decide what a blow does to the body in front of the player; the rest decide what it
## leaves when it goes down.
## The ceiling on crit chance: crits stay something that happens sometimes, however much gear is
## piled up. A chance over certainty is every hit critting, which is a crit meaning nothing.
const CRIT_CAP := 100.0
var damage: float = BARE_DAMAGE
var crit_chance := 0.0
var crit_damage := 0.0
## Swings a second the weapon takes on its own. Zero with nothing equipped, so a bare-handed fight is
## exactly the clicking game this was before gear meant anything.
var attack_speed := 0.0
## What a blow leaves behind, as a percentage of it: 20 means the body goes on losing a fifth of that
## blow every second it stands there. A mace's, and nothing else's. Wounds do not stack -- a blow
## either deepens the one wound or does nothing to it -- so a fast weapon cannot pile them up.
var bleed := 0.0
## The broad finder, as a percentage: 50 is half again as much of everything a body leaves. It lifts
## how often gear falls (`LootTable.roll`, where the cap on a chance already lives) and how often a
## unique does, and it lifts the purse and the orb roll beside the two narrow stats below -- which
## each lift one thing only, and carry the bigger numbers for it. Where it meets one of them it is
## **added** to it, the way two global percents add rather than compounding.
var drop_rate := 0.0
## What the player's skills and jewellery add to what a body leaves, all three in percent: how far up
## the rarity ramp a find is pushed, how much fuller a purse is, and how much more often an orb falls.
var item_rarity := 0.0
var gold_find := 0.0
var orb_find := 0.0

## How much of the next automatic swing has been earned. Only runs while an enemy is standing there
## to be hit, so a slow weapon loses nothing to a walk-in and cannot bank swings through a death.
var _swing := 0.0

## Damage a second the body in front of the player is losing to the wound the last blow left: the
## deepest one it has taken, never a sum of them. It belongs to that body and to no other, so it is
## cleared with `_struck` as the next one comes on and a body that gets back up gets up whole.
var _bleed := 0.0

## Whether crits go the player's way. Unseeded on purpose, like `loot_rng` and for the same reason:
## the tile's enemies are fixed before the player arrives, but how a given attempt goes is not.
var crit_rng := RandomNumberGenerator.new()

## The terrain the fight is on. It picked the enemies, and it picks the backdrop they are drawn on.
var env := ""
## Whether an elite is promised a drop. The main scene turns it on only while the Broken Sword has not
## dropped, so what the promise hands over is always that sword.
var guarantee_elite := false
## Whether the next piece of gear to fall is `LootTable.FIRST_DROP`, always common and level 1. The main scene turns it on until the player's
## first drop (`Inventory.first_sword_taken`), and the first drop here spends it.
var first_sword := false

## Whether every body drops something. Nothing in the game turns this on: it is for the tests and the
## screenshot scripts, which want a pouch with several things in it and would otherwise have to grind
## out the hundred-odd kills a 3% chance takes to get there. It goes through LootTable's `guaranteed`
## like the promised elite drop does, so what falls is rolled the ordinary way -- the certainty is
## about getting something, not about what.
var always_drop := false

## The same knob for orbs, and separate from `always_drop` because the two rates are separate: a test
## about crafting wants orbs and no gear, and a test about the pouch wants gear and no orbs.
var always_orb := false

## Kills this fight has to make before orbs can drop: what is left of `OrbTable.FIRST_ORB_KILLS` for
## this player. The main scene sets it; zero, the default, means orbs drop from the first body.
var orbs_after := 0

## What changes how this fight plays rather than a number, by effect id (`Inventory.effects()`): the
## capstone skills the player has learned and the uniques they are wearing. A worn unique is one entry
## a piece, so two of one ring are two entries. A fight nobody tells has none.
var effects: Array = []

## The unique roll, on a generator of its own for the reason `orb_rng` is: a rate tuned apart from the
## gear's should not shift it by drawing from the same stream.
var unique_rng := RandomNumberGenerator.new()
## Kills this fight has to make before a unique can fall: what is left of
## `UniqueTable.FIRST_UNIQUE_KILLS` for this player. The main scene sets it, as it sets `orbs_after`.
## Until it does, none can: a fight nobody tells anything is the fight it always was, so every test
## that counts what a body leaves counts what it always counted.
const NO_UNIQUES := -1
var uniques_after := NO_UNIQUES

## The Knucklebone Ring's streak: clicks made within `KNUCKLE_WINDOW` of the one before, and how long
## ago the last one was. A click counts whether or not it lands, or every walk-in would break it.
const KNUCKLE_WINDOW := 1.0
const KNUCKLE_STEP := 0.02
const KNUCKLE_MOST := 25
var _click_streak := 0
var _since_click := 0.0
## What a blow has to leave an enemy under, as a share of its health, for each effect that finishes
## it. They add: the Assassin capstone and the Headsman together kill under 35%.
const EXECUTE_SHARE := {"execute": 0.1, "headsman": 0.25}
## What the last killing blow did past the body's health, which Cleave carries into the next one.
var _overkill := 0.0

## The Gambler's Die, on a generator of its own so a test can pin what it rolls.
var gamble_rng := RandomNumberGenerator.new()
## What the rest of the uniques are tuned by. One place, so a card's sentence and the fight agree.
const BERSERK_MORE := 2.0        ## a click, per Berserker's Band
const METRONOME_MORE := 2.0      ## the weapon's own swing
const GLASS_MORE := 1.0
const GLASS_CLOCK := 4.0 / 3.0   ## how fast the Glass Edge spends the clock
const HOME_MORE := 1.0
const GAMBLE := [0.01, 3.0]
const ASCETIC_MORE := 0.15       ## per bare socket
const LAST_GASP_MORE := 2.0
const LAST_GASP_SECONDS := 5.0
const OVERCRIT := 2.0            ## crit damage a point of crit chance past the cap becomes
const DOMINO_SHARE := 0.2
const MOMENTUM_MORE := 0.02      ## per kill
const MOMENTUM_MOST := 1.0
const PACKMULE_MORE := 0.01      ## per piece in the bag
const RIPOSTE_CAP := 75.0
const HEARTWOOD_HEALTH := 100.0  ## health a second on the clock
const HEARTWOOD_MOST := 10.0
const MAGPIE_CHANCE := 0.05
const HEATSTROKE_SHARE := 0.02   ## of its health a second
const GRAZING_MORE := 2          ## enemies
const GIANTSBANE := 3.0
const RESTLESS_CHANCE := 0.1
## What `arm` read that only a unique asks about: block chance for Riposte, and the two counts the
## fight cannot see for itself (`Inventory.stats()` puts them in).
var block_chance := 0.0
var _bare_sockets := 0
var _bag_pieces := 0
## About the enemy that is out: whether it has taken a blow, whether one of them was a crit, whether
## it has already risen once. Cleared as the next one comes on.
var _struck := false
var _crit_landed := false
var _has_risen := false
## Whether the body going down now was felled by its first blow (Dominoes) and whether it gets back
## up (Restless dead), and how many have: a risen body is fought in the slot it died in, so the
## lineup and the pips never change length, and `kills` adds these on.
var _domino := false
var _rise := false
var _rose := 0
## How many enemies Grazing put on the front of the lineup, and whether Flush out brought the elite
## to the head of it. `tier_for` reads both, so it goes on agreeing with what `wear` built.
var _lead := 0
var _elite_first := false


## The profile for an area variant, falling back to the ordinary fight: a variant this build has no
## entry for is open land as far as the fight is concerned, which is what the backdrop does too.
static func profile_for(variant: String) -> Dictionary:
	return PROFILES.get(variant, ORDINARY)


## The fight waiting on `cell`, whose terrain is `env` and whose `variant` is what the world put
## there. Commons with an elite at each pitch, drawn from the enemies that live on that terrain and
## seeded from the cell, so the tile always fields the same fight.
static func for_tile(cell: Vector2i, env: String, variant := "", chest := false) -> Encounter:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["combat", cell])
	var fight := Encounter.new()
	fight.env = env
	fight.cell = cell
	if chest:
		fight._take_profile(CHEST)
		fight.lineup.append(MIMIC)
		fight.health.append(hp_of(MIMIC, cell))
	else:
		fight._take_profile(profile_for(variant))
		for i in fight.enemies:
			fight._append_enemy(rng)
	fight.hp = fight.health[0]
	return fight


## The ice wall's tile: the wall alone, fought on the ice whatever land lies under it.
static func for_wall(cell: Vector2i) -> Encounter:
	var fight := Encounter.new()
	fight.env = "ice"
	fight.cell = cell
	fight._take_profile(WALL)
	fight.lineup.append(WALL_NAME)
	# `WALL_GROWTH` is not applied here: `hp_of` already carries a step for every wall inside this one,
	# and a wall's own ring counts none of itself, so the wall on ring 21 comes out ten times this one.
	fight.health.append(roundf(hp_of(WALL_NAME, cell) * WALL_HP))
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
	# Flush out swapped the head of the lineup with its first elite slot.
	var first_elite := _lead + elite_every - 1
	if _elite_first and (position == 0 or position == first_elite):
		return EnemyRoster.Tier.ELITE if position == 0 else EnemyRoster.Tier.COMMON
	# Grazing's extra bodies stand in front of the rhythm, not in it.
	if position < _lead:
		return EnemyRoster.Tier.COMMON
	if (position - _lead) % elite_every == elite_every - 1:
		return EnemyRoster.Tier.ELITE
	return EnemyRoster.Tier.COMMON


## Whether one of the home pieces' second rules holds on this ground: `clause` is its bare id, and what
## arrives in `effects` is "<clause>:<env>" (`UniqueTable.clause_of`, and `Equipment.effects` for a
## Pilgrim's set).
func _clause(clause: String) -> bool:
	return ("%s:%s" % [clause, env]) in effects


## What the player is wearing and has learned, told to the fight before it starts -- before `arm`,
## which reads some of it, and before `start`, because two of the home pieces reshape the lineup.
## Setting `effects` by hand does everything but that reshaping, which is what most tests want.
func wear(worn: Array) -> void:
	effects = worn
	if endless or lineup.is_empty() or lineup[0] == MIMIC or lineup[0] == WALL_NAME:
		return
	# Grazing: more bodies on the same clock, on the front so the fight still ends on its elite.
	# Seeded from the cell like the lineup itself, so the tile fields the same herd every time.
	if _clause("grazing") and _lead == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["grazing", cell])
		for i in GRAZING_MORE:
			var picked := EnemyRoster.pick(env, EnemyRoster.Tier.COMMON, rng)
			lineup.insert(0, picked)
			health.insert(0, hp_of(picked, cell))
		_lead = GRAZING_MORE
		enemies += GRAZING_MORE
	# Flush out: open land only. A settlement is a set piece and keeps its order and its boss.
	var first_elite := _lead + elite_every - 1
	if _clause("flush_out") and not boss_last and not _elite_first and first_elite < lineup.size():
		var name := lineup[0]
		var worth := health[0]
		lineup[0] = lineup[first_elite]
		health[0] = health[first_elite]
		lineup[first_elite] = name
		health[first_elite] = worth
		_elite_first = true
	hp = health[0]


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
static func hp_of(enemy_name: String, cell: Vector2i) -> float:
	return maxf(1.0, roundf(base_hp(cell) * EnemyRoster.hp_modifier(enemy_name)))


## The health of an ordinary common body on this tile, before the enemy's own multiplier. A whole
## number, but a double rather than an int: the map has no edge and this is exponential in the walk,
## so an int64 overflowed a few hundred hexes out.
##
## Two terms: the smooth walk out from the middle, and a step for every wall already behind the cell.
## The step is what makes the land a wall opens a frontier again -- see `WALL_GROWTH`.
static func base_hp(cell: Vector2i) -> float:
	return maxf(1.0, roundf(BASE_HP * pow(HP_GROWTH, HexGrid.distance(MapBuilder.CENTER, cell))
			* pow(WALL_GROWTH, walls_inside(cell))))


## How many walls stand between the middle of the map and `cell`. A wall's own ring counts none of
## itself -- it is the edge of the land inside it -- and every ring past it counts that wall and the
## ones before. So it is the wall rings' own arithmetic, ceiling rather than floor, which agrees with
## the floor exactly on a wall ring (11 -> 0, 21 -> 1, 31 -> 2) and steps up on the first ring past one.
static func walls_inside(cell: Vector2i) -> int:
	return maxi(0, ceili(float(HexGrid.distance(MapBuilder.CENTER, cell)
			- MapBuilder.START_LAND_RADIUS - 1) / float(MapBuilder.WALL_STEP)))


## What an ordinary common body on this tile is carrying, before its own multiplier. Grows with the
## walk both ways at once: a step adds GOLD_PER_STEP and multiplies by GOLD_GROWTH.
##
## The distance is the smooth one `base_hp` uses and not the banded `MapBuilder.level_of` -- a purse
## is what this body was worth, and two tiles at opposite ends of one level band are not worth the
## same. At the very middle no steps have been taken, so this is BASE_GOLD exactly.
static func base_gold(cell: Vector2i) -> float:
	return gold_at_steps(HexGrid.distance(MapBuilder.CENTER, cell))


## The same purse asked of a walk rather than of a tile: what an ordinary common body `steps` out from
## the middle of the map is carrying. Split out of `base_gold` so a price can be quoted in bodies
## without a cell to point at -- `TownPrices` reads it at the first step of a level band.
##
## Whole gold in a double, the way `base_hp` is: a purse is exponential in the walk too, and every
## price in the game is quoted off this one.
static func gold_at_steps(steps: int) -> float:
	return maxf(1.0, roundf((BASE_GOLD + GOLD_PER_STEP * maxi(steps, 0)) * pow(GOLD_GROWTH, maxi(steps, 0))))


## What one enemy is carrying: the tile's purse times what the body was worth to kill. The same
## `hp_modifier` its health is built from, so a thing that took four times the clicking hands over
## four times the gold and nobody has to keep a second table in step with the first. Floored at 1,
## which is what keeps a slime (half an ordinary body) from rounding away to nothing.
static func gold_of(enemy_name: String, cell: Vector2i) -> float:
	return maxf(1.0, roundf(base_gold(cell) * EnemyRoster.hp_modifier(enemy_name)))


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


## What the nameplate calls the ground a boss holds, by environment.
const TITLE_GROUND := {
	"desert": "Dunes", "dirt": "Barrens", "forest": "Deepwood",
	"grass": "Meadows", "ice": "Frost", "mountains": "Peaks",
}
const BOSS_TITLES: Array[String] = ["Scourge", "Terror", "Warden", "Bane", "Tyrant"]
const ELITE_TITLES: Array[String] = [
	"Savage", "Ancient", "Grim", "Rabid", "Hulking", "Vicious", "Dread", "Feral",
]


## What the enemy out now is called beyond its name: a word in front of an elite's ("Savage"), a line
## under a boss's ("Scourge of the Dunes"), nothing for a common. Seeded from the cell and the slot, so
## a tile's elite is always the same one -- and for show only: a bounty counts `enemy_name()`.
func enemy_title() -> String:
	if index >= lineup.size():
		return ""
	var pick := hash(["title", cell, index])
	match EnemyRoster.tier_of(lineup[index]):
		EnemyRoster.Tier.ELITE:
			return ELITE_TITLES[pick % ELITE_TITLES.size()]
		EnemyRoster.Tier.BOSS:
			return "%s of the %s" % [BOSS_TITLES[pick % BOSS_TITLES.size()],
					TITLE_GROUND.get(env, "Wilds")]
	return ""


## The health the current enemy started with, for drawing a bar against `hp`.
func enemy_max_hp() -> float:
	return 0.0 if index >= lineup.size() else health[index]


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
	return index + _rose


## A click. Takes a point off the enemy in front of the player, and kills it at zero. Ignored while
## one is running in or dying, and once the fight is over. Returns whether it landed.
func hit() -> bool:
	# The Metronome's price: the player's own hand does nothing. The click still counts towards a
	# Knucklebone streak, which is the one thing clicking is good for beside it.
	var landed := false if "metronome" in effects else _strike(false)
	if "knucklebone" in effects:
		_click_streak = mini(_click_streak + 1, KNUCKLE_MOST)
		_since_click = 0.0
	return landed


## What the player's gear is worth, from `Equipment.totals()`. Called before the fight starts; a
## fight nobody arms is a bare-handed one, which is what every test that does not care gets.
func arm(stats: Dictionary) -> void:
	damage = maxf(BARE_DAMAGE, roundf(float(stats.get("damage", 0.0))) + BARE_DAMAGE)
	# Clamped, because a chance is not a quantity: eight pieces each adding crit chance can total
	# more than certainty, and a save written before LootTable.CHANCE_STATS holds pieces that do it on
	# their own. Past the cap every hit crit, which is a crit meaning nothing.
	var raw_crit := float(stats.get("crit_chance", 0.0))
	crit_chance = clampf(raw_crit, 0.0, CRIT_CAP)
	crit_damage = float(stats.get("crit_damage", 0.0))
	# The Overflowing Chalice: what the clamp above throws away is kept as crit damage.
	if "overcrit" in effects:
		crit_damage += maxf(0.0, raw_crit - CRIT_CAP) * OVERCRIT
	block_chance = clampf(float(stats.get("block_chance", 0.0)), 0.0, RIPOSTE_CAP)
	_bare_sockets = maxi(0, int(stats.get("bare_sockets", 0)))
	_bag_pieces = maxi(0, int(stats.get("bag_pieces", 0)))
	# Heartwood Plate: health buys clock, and stops buying it at HEARTWOOD_MOST -- health grows with
	# every level, and a clock that grew with it would be no clock. A run has none to add to.
	if "heartwood" in effects and not endless:
		seconds += minf(floorf(float(stats.get("health", 0.0)) / HEARTWOOD_HEALTH), HEARTWOOD_MOST)
		time_left = seconds
	attack_speed = maxf(0.0, float(stats.get("attack_speed", 0.0)))
	bleed = maxf(0.0, float(stats.get("bleed", 0.0)))
	drop_rate = maxf(0.0, float(stats.get("drop_rate", 0.0)))
	item_rarity = maxf(0.0, float(stats.get("item_rarity", 0.0)))
	gold_find = maxf(0.0, float(stats.get("gold_find", 0.0)))
	orb_find = maxf(0.0, float(stats.get("orb_find", 0.0)))


## One blow, from a click or from the weapon swinging itself. Takes `damage` off the enemy in front
## of the player, crits at `crit_chance`, and kills it at zero. Ignored while one is running in or
## dying, and once the fight is over. Returns whether it landed.
func _strike(automatic: bool, riposte := false) -> bool:
	if finished or phase != Phase.WAITING:
		return false
	var crit := crit_chance > 0.0 and crit_rng.randf() * 100.0 < crit_chance
	var first := not _struck
	_struck = true
	# The Duelist's Buckler: the first blow an enemy takes is a crit, whoever swung it.
	if first and "opening_strike" in effects:
		crit = true
	_crit_landed = _crit_landed or crit
	# Crit damage is what a crit adds, not what it multiplies to: 50 means half again, the way Path
	# of Exile's crit multiplier reads once you take its base 100 off.
	var dealt := maxf(1.0, roundf(damage * (1.0 + crit_damage / 100.0))) if crit else damage
	var big := EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON
	# Stonebreaker's Giantsbane is Giant Slayer made bigger on its own ground, not a second one on top.
	if big and _clause("giantsbane"):
		dealt *= GIANTSBANE
	elif big and "giant_slayer" in effects:
		dealt *= 2
	# Everything the uniques add to a blow, summed and applied once -- see `_unique_more`.
	dealt = maxf(1.0, roundf(dealt * (1.0 + _unique_more(automatic))))
	# The Gambler's Die is not more damage but a different blow every time, so it stands outside that.
	if "gamble" in effects:
		dealt = maxf(1.0, roundf(dealt * gamble_rng.randf_range(GAMBLE[0], GAMBLE[1])))
	hp -= dealt
	# Execute takes what is left once it is a sliver, so the last hits of a big body are not wasted.
	var finish := 0.0
	for effect: String in EXECUTE_SHARE:
		if effect in effects:
			finish += float(EXECUTE_SHARE[effect])
	if hp > 0 and hp < enemy_max_hp() * finish:
		hp = 0.0
	hit_landed.emit(dealt, crit, automatic)
	enemy_hit.emit(hp)
	if hp <= 0:
		# Dominoes: felled by the first blow it took, so it chains through Cleave's carried damage.
		_domino = first and "domino" in effects
		_kill()
	else:
		# The mace's Bleed: the body goes on losing this share of the blow every second it stands.
		# The deeper wound wins and nothing adds, so what a mace is worth is the size of one blow and
		# not how many of them land -- a weapon that swung twice as fast would otherwise bleed twice
		# as hard for free.
		_bleed = maxf(_bleed, dealt * bleed / 100.0)
		# Bulwark: the chance to block is the chance to swing again at once. Never off its own extra blow.
		if not riposte and "riposte" in effects and crit_rng.randf() * 100.0 < block_chance:
			_strike(automatic, true)
	return true


## What the worn uniques add to a blow, as a share: 2.0 is three times the damage. **One sum**, the
## way `Equipment.totals` adds its global percents, and for the same reason: twenty-odd uniques that
## each multiplied would let a stack of them outrun the map, and every one would beat any crafted
## piece in its socket. Added, a full stack is worth a stretch of frontier and no more.
func _unique_more(automatic: bool) -> float:
	var more := 0.0
	if automatic:
		more += METRONOME_MORE * effects.count("metronome")
	else:
		more += BERSERK_MORE * effects.count("berserk")
		# The streak is the hand's: the weapon's own swings are not what it rewards.
		more += KNUCKLE_STEP * _click_streak * effects.count("knucklebone")
	if ("home:" + env) in effects:
		more += HOME_MORE
	if not endless:
		# Both are paid for in clock, and a run has none: there they are worth nothing.
		if "glass_edge" in effects:
			more += GLASS_MORE
		if "last_gasp" in effects and time_left <= LAST_GASP_SECONDS:
			more += LAST_GASP_MORE
	if "ascetic" in effects:
		more += ASCETIC_MORE * _bare_sockets
	if "momentum" in effects:
		more += minf(MOMENTUM_MORE * kills(), MOMENTUM_MOST)
	if "packmule" in effects:
		more += PACKMULE_MORE * _bag_pieces
	return more


## The enemy that is out goes down, and everything it was carrying is handed over. Apart from
## `_strike` because a blow is not the only thing that kills: Heatstroke does it with none.
func _kill() -> void:
	var big := EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON
	phase = Phase.DYING
	phase_left = DEATH
	_swing = 0.0
	_overkill = -hp if "cleave" in effects else 0.0
	# Restless dead: an ordinary body, once, one time in ten. Drawn only while worn.
	_rise = not big and not _has_risen and _clause("restless") and loot_rng.randf() < RESTLESS_CHANCE
	enemy_died.emit(index)
	# The only path to a death, which is why drops survive a loss for free: nothing is rolled
	# when the clock runs out.
	# The tile's level is the ceiling on what can fall here, not what falls -- the drop rolls its
	# own level under it, so fighting deeper improves the odds rather than the prize.
	# A mimic holds a unique or MIMIC_ROLLS certain pieces, never both. The unique ignores the
	# kill count uniques otherwise wait for; a ground with no pool falls back to the gear.
	var mimic := lineup[index] == MIMIC
	var chest_unique: Item = null
	if mimic and loot_rng.randf() < MIMIC_UNIQUE:
		chest_unique = UniqueTable.roll(lineup[index], env, unique_rng, MapBuilder.level_of(cell),
				drop_rate, true)
	var rolls := MIMIC_ROLLS if mimic else 1
	# The Tithe: no ordinary gear at all, from anything.
	if "tithe" in effects or chest_unique != null:
		rolls = 0
	for roll in rolls:
		var certain: bool = always_drop or mimic or (roll == 0
				and ((guarantee_elite and on_elite()) or (big and "trophy" in effects)))
		var dropped := LootTable.roll(lineup[index], loot_rng, certain, MapBuilder.level_of(cell),
				drop_rate, item_rarity)
		# Lucky Wound: a body that took a crit rolls again and leaves the better of the two.
		if _crit_landed and "lucky_wound" in effects:
			dropped = _better(dropped, LootTable.roll(lineup[index], loot_rng, certain,
					MapBuilder.level_of(cell), drop_rate, item_rarity))
		var found := 0
		while dropped != null:
			if first_sword:
				first_sword = false
				dropped = Item.rolled(LootTable.FIRST_DROP, ItemRarity.Rarity.COMMON, loot_rng)
			loot_dropped.emit(index, dropped)
			found += 1
			# A find that beat the chance rolls again, at the same chance and never guaranteed, up to
			# MOST_DROPS: a lucky body leaves a second piece and now and then a fourth. A certain roll --
			# `always_drop`, a mimic, the elite's promise, Trophy Hunter -- does not, because it beat
			# nothing: the promise is one piece.
			dropped = null if certain or found >= MOST_DROPS else LootTable.roll(lineup[index],
					loot_rng, false, MapBuilder.level_of(cell), drop_rate, item_rarity)
	# Every body carries one, which is the whole difference between gold and gear: nine kills in
	# ten leave nothing, and all ten leave this.
	# Gold find lifts the purse here rather than inside `gold_of`, which is what the body is worth
	# and is read by things that have no player in them -- a town's prices are quoted off it.
	# Drop rate finds everything, so it is in this sum too, **added** to gold find the way two global
	# percents add: 20 and 30 are half again as much gold, not 56% more.
	var purse := maxf(1.0, roundf(gold_of(lineup[index], cell)
			* (1.0 + (gold_find + drop_rate) / 100.0)))
	# Two Tithes add (five times, not nine), the way two global modifiers do.
	purse *= 1.0 + 2.0 * effects.count("tithe")
	# Drawn only while Jackpot is learned, so a player without it rolls loot exactly as before.
	if "jackpot" in effects and loot_rng.randf() < 0.1:
		purse *= 5
	# The Magpie's Band: now and then the purse is a piece of gear instead. The Tithe wins where
	# both are worn -- no ordinary gear means none -- and the purse stays a purse.
	if "magpie" in effects and not "tithe" in effects and loot_rng.randf() < MAGPIE_CHANCE:
		purse = 0.0
		loot_dropped.emit(index, LootTable.roll(lineup[index], loot_rng, true,
				MapBuilder.level_of(cell), drop_rate, item_rarity))
	if purse > 0.0:
		gold += purse
		gold_dropped.emit(index, purse)
	var worth := xp_of(lineup[index], cell)
	xp += worth
	xp_dropped.emit(index, worth)
	# A unique, beside the gear and not from its table: any body can carry one, off the pool of the
	# ground it stood on. Through `loot_dropped` like any find, so the pouch, the bag and the
	# verdict need no second path.
	# None before the player's 100th kill, and pure chance after it.
	var boss := EnemyRoster.tier_of(lineup[index]) == EnemyRoster.Tier.BOSS
	# A mimic's unique chance is its coin toss above, and nothing on top of it.
	if chest_unique != null:
		loot_dropped.emit(index, chest_unique)
	elif not mimic and uniques_after != NO_UNIQUES and index >= uniques_after:
		var found := UniqueTable.roll(lineup[index], env, unique_rng, MapBuilder.level_of(cell),
				drop_rate)
		if found != null:
			loot_dropped.emit(index, found)
	# The Hourglass: a second back for anything but a boss, and never past what the fight began
	# with, so the clock can be held but not banked. A run has no clock to give to.
	if "hourglass" in effects and not endless and not boss:
		time_left = minf(seconds, time_left + 1.0)
	# A third draw, on its own generator and its own curve. Beside the gear rather than instead
	# of it: a body that left a sword can leave an orb too, which is what makes the two rates
	# independent numbers rather than one number split.
	# Drop rate adds to orb find here for the reason it adds to gold find above, and `chance_for` is
	# handed the sum rather than taught about a second stat.
	var orb := ""
	if always_orb or index >= orbs_after:
		orb = OrbTable.roll(lineup[index], orb_rng, always_orb, orb_find + drop_rate)
	if not orb.is_empty():
		var count := 2 if "transmute" in effects and orb_rng.randf() < 0.25 else 1
		for i in count:
			orbs[orb] = int(orbs.get(orb, 0)) + 1
			orb_dropped.emit(index, orb)


## The better of two finds, either of which may be nothing: the higher rarity, then the higher level.
static func _better(a: Item, b: Item) -> Item:
	if a == null or b == null:
		return b if a == null else a
	if a.rarity != b.rarity:
		return a if a.rarity > b.rarity else b
	return a if a.level >= b.level else b


## Runs the clock, and the walking-in and dying that the clock runs through. Called every frame by
## CombatScene; tests drive it themselves.
func advance(delta: float) -> void:
	if finished:
		return
	if not endless:
		var spent := delta
		# Rimeplate's Frozen clock: a walk-in costs nothing.
		if _clause("frozen_clock") and phase == Phase.WALKING_IN:
			spent -= minf(delta, phase_left)
		# The Glass Edge's price.
		if "glass_edge" in effects:
			spent *= GLASS_CLOCK
		time_left = maxf(time_left - spent, 0.0)
	_since_click += delta
	if _since_click > KNUCKLE_WINDOW:
		_click_streak = 0
	while not finished and phase != Phase.WAITING and delta > 0.0:
		# A phase that ends part-way through the frame hands the rest of the frame to the next one.
		if delta < phase_left:
			phase_left -= delta
			break
		delta -= phase_left
		_advance_phase()
	_swing_weapon(delta)
	# The weapon has swung; now what is already in the body. The Sunscorched Cowl's Heatstroke takes
	# its share of the body's health, and a mace's wound takes its share of the blow that opened it.
	if _clause("heatstroke"):
		_wear_down(enemy_max_hp() * HEATSTROKE_SHARE, delta)
	_wear_down(_bleed, delta)
	if not endless and time_left <= 0.0 and not finished:
		_finish(false)


## A body wearing down with nobody touching it, at `a_second` damage a second: the heat and the bleed
## are the same thing off different numbers, so they go through one place. Only while it is standing
## -- one walking in or already going down takes none of it, the way an automatic swing lands on
## neither -- and a death this way was nobody's blow, so Dominoes cannot come of it.
func _wear_down(a_second: float, delta: float) -> void:
	if a_second <= 0.0 or finished or phase != Phase.WAITING or delta <= 0.0:
		return
	hp -= a_second * delta
	enemy_hit.emit(maxf(hp, 0.0))
	if hp <= 0.0:
		_domino = false
		_kill()


## The weapon swinging on its own, `attack_speed` times a second. Only earns while an enemy is
## standing there to be hit, so nothing accrues through a walk-in or a death and a fast weapon
## cannot arrive at the next body with a fistful of banked swings.
func _swing_weapon(delta: float) -> void:
	# The Berserker's Band: the weapon never swings on its own.
	if attack_speed <= 0.0 or finished or phase != Phase.WAITING or "berserk" in effects:
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
	_struck = false
	_crit_landed = false
	_bleed = 0.0
	# Restless dead: the body gets back up where it fell, at half of what it was, and is killed and
	# paid for again. The slot does not move, so the lineup and the pips stay the length they were.
	if _rise:
		_rise = false
		_has_risen = true
		_rose += 1
		hp = maxf(1.0, roundf(health[index] * 0.5) - _overkill)
		_overkill = 0.0
		_domino = false
		phase = Phase.WALKING_IN
		phase_left = WALK_IN
		enemy_coming.emit(index, lineup[index], hp)
		return
	_has_risen = false
	index += 1
	if index >= lineup.size():
		if not endless:
			_finish(true)
			return
		# The next one is decided the moment the last one falls, so a run never runs dry.
		_append_enemy(roster_rng)
	# Dominoes first, then whatever Cleave carried: a fifth of the body, and then the blow's change.
	var fresh := health[index]
	if _domino:
		fresh = roundf(fresh * (1.0 - DOMINO_SHARE))
		_domino = false
	hp = maxf(1.0, fresh - _overkill)
	_overkill = 0.0
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
