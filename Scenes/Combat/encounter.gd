class_name Encounter
extends RefCounted
## One tile's fight: a lineup of enemies against one clock -- or a farm run,
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
## The clock is the only way to lose, and the enemies strike at it: a body left standing hits every
## `ATTACK_EVERY` of its tier and each blow takes seconds off (`taken`), which the player's armour,
## dodge and block cut down and time on hit wins back. Beat the lineup inside `seconds` and the tile
## is charted; run out and nothing happens, the tile stays grey and can be tried again. A tile's
## lineup is seeded from its cell, so the same tile always fields the same fight, the way everything
## else about a tile is decided before the player ever reaches it.
##
## A farm run (`farm()`) is `endless`: the lineup grows an enemy at a time and is never done, the
## clock never runs, and the only ways out are `stop()` and `give_up()`. Nothing about it is seeded
## from the cell -- a tile always fields the same lineup, and never the same run twice. It keeps the
## tile's elite rhythm and never its boss.
##
## The dungeon (`for_dungeon()`) is the third kind, and measures one thing: damage. It has a clock and
## a lineup that never ends, each floor a body with `DUNGEON_GROWTH` times the health of the one above
## it, in depths of fifteen floors with Gollux on the last. A depth is only ever won by killing him
## (`depth()`, `cleared()`), and the next descent begins under the last one won. Nothing in it strikes
## and it pays nothing.
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
## An enemy struck the clock: `taken` seconds came off it after armour and block, or none at all
## because the player dodged or because block took the whole of what armour left.
signal player_hit(taken: float, dodged: bool, blocked: bool)
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
## The most the gear's Fight Clock adds to it, in seconds: two top rolls. Beside Heartwood's own cap,
## not inside it -- the two are different pieces spent on the same thing.
const CLOCK_MOST := 8.0

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
## and a steep one with cliffs: 28 was about 1000 kills at five clicks a second, 30 already 1200. It was
## 33 until weapons stopped gaining a whole point of damage a level (`LootTable.LEVEL_FLAT`, 2026-09-27).
const WALL_HP := 28.0
## What every wall already fallen multiplies the health of everything behind it by -- the whole land it
## opened as well as the next wall, through `base_hp`. The step lands on top of the walk, so with the
## band's own `HP_GROWTH ^ WALL_STEP` a wall is some sixteen times the one before it (walls on rings
## 12, 24, 36 since 2026-09-28; the figures this used to quote were for rings 11, 21, 31).
##
## The land needs the step as much as the wall does: felling a wall means about forty times the damage
## a second that the land inside it asks for (a wall is `WALL_HP` over a boss body, some 930 commons,
## in a minute), and a band of `WALL_STEP` rings only grows by `HP_GROWTH ^ WALL_STEP`, about seven. Without the step
## everything behind a fallen wall died to one click for ever. With it, a wall is crossed with roughly
## fourteen times the power the new band's first ring wants, the band's own curve eats that, and the
## next wall is again the same forty-times check -- every band the same shape as the first.
##
## The first wall is a day's farming; the second is the gate a transcension is for -- a third of a
## million health, where at 10 it was 1.79e6 and no farming ever reached it. It was 2.8 until the
## weapons' damage step came down (2026-09-27); 2.2 gives the frontier past the wall and the second
## wall back what they asked of a farmed set before.
##
## Since 2026-09-27 it is the step for the **wall and the blows** only: the bodies' health behind a
## wall steps by LAND_GROWTH instead (the user's ruling: the wall is right, the land past it too soft).
const WALL_GROWTH := 2.2
## What every wall already fallen multiplies the *health* of the bodies behind it by (`base_hp`'s
## default): the first tile past a felled wall is ten times the land inside it, on top of the walk
## (the user's ruling, 2026-09-27). The walls themselves and the size of a blow (`hit_of`) keep
## WALL_GROWTH, so this moves the land past a wall and nothing else.
const LAND_GROWTH := 10.0
## The dungeon: a block of fifteen floors that repeats for ever, an elite every fifth and a boss on
## the fifteenth, against one minute. `enemies` is the block, which is what the HUD's bar stands.
const DUNGEON := {"enemies": 15, "seconds": 60.0, "elite_every": 5, "boss_last": true}
## Where its creatures live (`EnemyRoster`) and what is drawn behind them: no land on the map.
const DUNGEON_ENV := "cave"
## What one floor down multiplies a body's health by: a depth is fifteen of them, so the next Gollux
## wants about fifteen times the damage the last one did. The dial for how far apart the depths are.
const DUNGEON_GROWTH := 1.2
## What a floor's body is worth by its tier, and nothing else about it: the roster's sizes and its
## own tiers are for land, where a boss is 24 bodies -- here that would be a wall every fifteenth
## floor that every score piled up against. A rat and a crab on one floor are the same health.
const DUNGEON_TIER_HP := {
	EnemyRoster.Tier.COMMON: 1.0,
	EnemyRoster.Tier.ELITE: 2.0,
	EnemyRoster.Tier.BOSS: 5.0,
}
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
## Base health set by hand for a circle of land, by the walls inside it (`walls_inside`): an
## ordinary body on its first ring has this, and the rest of the circle scales with it
## (`hp_tuning`). A circle not listed keeps the formula's. The user's (2026-09-28): 10k between the
## second wall and the third, where the formula gave about 26.7k.
const CIRCLE_HP := {2: 10000.0}

## What a body is carrying, on a tile next to the start. An ordinary common one at the very middle
## of the map is worth exactly BASE_GOLD, which is where the whole curve is pinned.
const BASE_GOLD := 1.0
## The linear half of how a purse grows with the walk: this much more gold a hex step, before the
## exponent. It is what keeps the first few tiles from all paying the same, where an exponent barely
## moves.
const GOLD_PER_STEP := 1.0
## And the exponential half. Set near LootTable.LEVEL_GROWTH rather than near HP_GROWTH, so a purse
## keeps pace with the gear that has to kill for it rather than with the health it has to get
## through. Every price in town is quoted off this curve (`TownPrices`), so moving it moves them all.
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

## How often a standing enemy strikes the clock, by tier: the rabble fast, a boss slow. The first blow
## comes a whole interval after it arrives, so a body killed quickly never lands one -- damage is the
## first defence there is.
const ATTACK_EVERY := {
	EnemyRoster.Tier.COMMON: 1.0,
	EnemyRoster.Tier.ELITE: 2.0,
	EnemyRoster.Tier.BOSS: 4.0,
}
## What one blow is worth against a common's, by tier. Set against ATTACK_EVERY so every tier takes
## the same seconds a second off an unarmoured player: the big ones hit rarer and harder, which is
## what makes armour (a share) and block (a flat amount) answer them differently.
const HIT_TIER := {
	EnemyRoster.Tier.COMMON: 1.0,
	EnemyRoster.Tier.ELITE: 2.0,
	EnemyRoster.Tier.BOSS: 4.0,
}
## Seconds a common's blow takes off the clock on a tile next to the start, before the walk out
## multiplies it the way it multiplies health (`hit_of`). The dial for how much defence matters at
## all.
const HIT_SECONDS := 0.25
## Armour and dodge are ratings, and a rating is a flat share of every blow whatever its size:
## `rating / (rating + K)`, so K of it is half, 9K is 90%, and no amount of it ever reaches the whole
## -- which is what lets both grow with the level for ever with no cap. The two dials for what a
## point of each is worth.
const ARMOUR_K := 50.0
const DODGE_K := 50.0
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

## Whether this is the dungeon: a clock like a tile's, a lineup that grows like a run's.
var dungeon := false
## The floor the dungeon's first body stands on, from 0: the top of the depth the descent begins in.
## Nought in every other fight.
var first_floor := 0

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
## `arm()` rather than looked up per swing. Five decide what a blow does to the body in front of the
## player, the defence further down decides what the body's blows do to the clock, and the rest decide
## what it leaves when it goes down. The attributes are read by `Inventory.stats()`, and here only by
## the Brawler's Wraps.
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

## Whether the first body to fall here leaves `OrbTable.FIRST_ORB`, past `orbs_after` and the chance.
## The main scene turns it on for every fight after the player's first until that orb has dropped
## (`Inventory.first_orb_taken`), and the first kill here spends it.
var first_orb := false

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
## Dev (`Settings.even_loot`, handed over by the main scene): every body but a chest has one chance in
## three of one find, and common, uncommon, rare, elite and unique are all as likely -- in place of the
## real gear and unique rolls, so every rarity's drop can be looked at without farming for it.
const EVEN_LOOT_CHANCE := 1.0 / 3.0
var even_loot := false

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
const SERPENT_STEP := 5.0        ## crit chance a blow that did not crit adds, per Serpent's Eye
const DOMINO_SHARE := 0.2
const MOMENTUM_MORE := 0.02      ## per kill
const MOMENTUM_MOST := 1.0
const PACKMULE_MORE := 0.01      ## per piece in the bag
const PATCHWORK_MORE := 0.02     ## per attribute line worn
const PURIST_MORE := 0.10        ## per piece worn without one
const BRAWLER_MORE := 0.01       ## per point of strength on a click, of dexterity on a swing
const HEARTWOOD_ARMOUR := 50.0   ## armour a second on the clock
const HEARTWOOD_MOST := 10.0
const AFTERIMAGE_SECONDS := 1.0  ## the most a dodge wins back, of what blows have taken
const SECOND_WIND_SECONDS := 5.0 ## given back once a fight, as the clock runs out
const MAGPIE_CHANCE := 0.05
const HEATSTROKE_SHARE := 0.02   ## of its health a second
const GRAZING_MORE := 2          ## enemies
const GIANTSBANE := 3.0
const RESTLESS_CHANCE := 0.1
## What the world's curses are tuned by (`Curses`, which writes the same figures in words).
const IRON_HP := 0.6             ## more health, added to a tile's own `hp`
const SHORT_DAYS := 8.0          ## seconds off every clock
const BLOODTHIRST_HIT := 0.75    ## more of every blow, added to a tile's own `hit`
const HUNGRY_HP := 2.0           ## more health on a mimic: three times over
const HUNGRY_ROLLS := 6          ## in MIMIC_ROLLS' place
const LONG_WINTER_HP := 2.0      ## what the ice wall's health is multiplied by
const LEAN_LESS := 0.5           ## what is left of the chance of gear
const LEAN_PLUS := [0.10, 0.01]  ## a find that is +1, and one that is +2
const PAUPER_PURSE := 0.5
const LESSONS_XP := 0.25         ## what is left of every body's experience
const BERSERK_WORLD_MORE := 1.0  ## a click, under Berserker's World: beside the Band's in one sum
const RAW_ORBS := 3.0            ## what the chance of an orb is multiplied by under Raw Finds
const HOME_RARITY := 80.0        ## item rarity on the Homeland's two lands
const HOME_UNIQUES := 3.0        ## and what the chance of a unique is multiplied by there
const FOG_UNIQUES := 2.0         ## what the chance of a unique is multiplied by

## What the tile itself does to the fight (`TileMods`, by id): land past the second wall, told to
## `for_tile` and `farm` by whoever opens the fight. A fight nobody tells has none.
var mods: Array = []
## Seconds an enemy of this fight spends running in: `WALK_IN`, or longer in a Mire, or shorter for
## what the gear's spawn speed takes off it -- none at all at 100%.
var walk_in := WALK_IN
## The gear's share of the walk-in taken off, 0-100.
var spawn_speed := 0.0
## What the tile and the world add to every body's health, to every blow and to how often one comes,
## as shares: **one sum each**, the way `_unique_more` is, so a Thick-skinned tile under Iron Foes is
## +110% and not +140%.
var _hp_more := 0.0
var _hit_more := 0.0
var _attack_more := 0.0
## More experience off every body, in percent: the tile's and the world's, added.
var xp_more := 0.0
## Whether `wear` has already taken the curses on, which it must do once however often it is called.
var _cursed := false
## What keeps a blow off the clock (`taken`, `_struck_by`): two ratings, seconds off each blow, and
## seconds a landed hit of the player's wins back of what the blows took.
var armor := 0.0
var dodge := 0.0
var block := 0.0
var time_on_hit := 0.0
## Seconds the enemies' blows have taken off the clock and time on hit has not yet won back. Time on
## hit heals this and nothing else, so it can undo a blow and never the clock's own running.
var wounds := 0.0
## Whether the Guard tree's Second Wind has been spent this fight.
var _second_wind_used := false
## How far the enemy standing there is towards its next blow. Cleared as each one comes on.
var _attack := 0.0
## Whether the enemies strike the clock at all. The main scene turns it on for every fight it opens;
## off, a fight is the one it was before they did, which is what the tests that time a clock to the
## second and the screenshot scripts want -- the same bargain as `uniques_after`.
var strikes := false
## What `arm` read that only a unique asks about: the two counts the fight cannot see for itself
## (`Inventory.stats()` puts them in).
var _bare_sockets := 0
var _bag_pieces := 0
## And what the attribute uniques read: the counted strength and dexterity (Brawler's Wraps), the
## attribute lines worn (Patchwork Coat) and the pieces worn without one (Purist's Seal).
var _strength := 0.0
var _dexterity := 0.0
var _attribute_lines := 0
var _pure_pieces := 0
## About the enemy that is out: whether it has taken a blow, whether one of them was a crit, whether
## it has already risen once. Cleared as the next one comes on.
var _struck := false
var _crit_landed := false
## The Serpent's Eye's crit chance, built by every blow that did not crit and spent by the one that
## does. Kept for the whole fight, across bodies, so a run carries it from one enemy to the next.
var _serpent := 0.0
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
static func for_tile(cell: Vector2i, env: String, variant := "", chest := false,
		mods: Array = []) -> Encounter:
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
		fight._take_mods(mods)
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
	fight.health.append(fight._health_of(WALL_NAME))
	fight.hp = fight.health[0]
	return fight


## The dungeon, begun under the `won` depths the player already has: at the top of the next one, with
## a whole clock. The descent goes on past its Gollux into the depth after, on what is left of it.
static func for_dungeon(won := 0) -> Encounter:
	var fight := Encounter.new()
	fight.env = DUNGEON_ENV
	fight.dungeon = true
	fight._take_profile(DUNGEON)
	fight.first_floor = maxi(0, won) * fight.enemies
	fight._append_enemy(fight.roster_rng)
	fight.hp = fight.health[0]
	return fight


## The depth the player is in, from 1. It moves only as a Gollux goes down: he is the last floor of
## his depth, so the floor after him is the first of the next.
func depth() -> int:
	return (first_floor + index) / enemies + 1


## How many depths this descent has won: the Golluxes it has killed.
func cleared() -> int:
	return depth() - 1 - first_floor / enemies


## A farm run on `cell`: the same enemies the tile's terrain fields, coming forever, with no clock
## and no count. It ends when the player says so.
##
## It keeps the tile's own elite rhythm -- a run on a town throws one up every five -- and never its
## boss: a boss is what a set piece ends on, and a run does not end.
static func farm(cell: Vector2i, env: String, variant := "", mods: Array = []) -> Encounter:
	var fight := Encounter.new()
	fight.env = env
	fight.cell = cell
	fight.endless = true
	fight.elite_every = int(profile_for(variant)["elite_every"])
	# Only what can bite with no clock and nothing striking it, reward and all.
	fight._take_mods(TileMods.farmable(mods))
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


## Takes on what the tile does to its own fight, after the profile and before the lineup is rolled:
## the numbers that shape it. What they do to the player's numbers, and what they pay, waits for `arm`.
func _take_mods(carried: Array) -> void:
	mods = carried
	var last := false
	for id: String in mods:
		var mod: Dictionary = TileMods.MODS[id]
		enemies += int(mod.get("enemies", 0))
		if mod.has("elite_every"):
			elite_every = int(TileMods.value(id, "elite_every", mods.count(id)))
		last = last or bool(mod.get("elite_last", false))
	if last:
		elite_every = enemies
	seconds = maxf(1.0, seconds + TileMods.total(mods, "seconds"))
	time_left = seconds
	_hp_more += TileMods.total(mods, "hp")
	_hit_more += TileMods.total(mods, "hit")
	_attack_more += TileMods.total(mods, "attack")
	walk_in = WALK_IN * TileMods.factor(mods, "walk_in")
	phase_left = walk_in


## The health `enemy` starts this fight with: what the tile makes it worth (`hp_of`), more for whatever
## the tile and the world add. The ice wall answers to `WALL_HP` and the Long Winter and to nothing
## else -- it is the check on the player, and a tile's modifier is not what it checks.
func _health_of(enemy: String, position := -1) -> float:
	if dungeon:
		# The floor and the tier and nothing else: no tile's modifier and no world's curse reaches down
		# here. Asked as a body joins, the floor is how many are already built; `_take_curses`, sizing
		# them again, says which.
		var at := health.size() if position < 0 else position
		return maxf(1.0, roundf(BASE_HP * pow(DUNGEON_GROWTH, first_floor + at)
				* float(DUNGEON_TIER_HP[EnemyRoster.tier_of(enemy)])))
	if enemy == WALL_NAME:
		# `hp_of` at WALL_GROWTH carries a step for every wall inside this one, and a wall's own ring
		# counts none of itself, so the second wall comes out WALL_GROWTH times the first on top of
		# the band's walk. Not LAND_GROWTH: that is the land's.
		return roundf(hp_of(enemy, cell, WALL_GROWTH) * WALL_HP
				* (LONG_WINTER_HP if Curses.effect(Curses.LONG_WINTER) in effects else 1.0))
	var more := 1.0 + _hp_more
	if enemy == MIMIC and Curses.effect(Curses.HUNGRY_MIMICS) in effects:
		more += HUNGRY_HP
	return maxf(1.0, roundf(hp_of(enemy, cell) * more))


## What the world's curses do to the shape of the fight, once: `wear` hands them over with the rest of
## `effects`, after the lineup was rolled, so every body already out is sized again.
func _take_curses() -> void:
	if _cursed:
		return
	_cursed = true
	if Curses.effect(Curses.IRON_FOES) in effects:
		_hp_more += IRON_HP
	if Curses.effect(Curses.BLOODTHIRST) in effects:
		_hit_more += BLOODTHIRST_HIT
	if Curses.effect(Curses.SHORT_DAYS) in effects and not endless:
		seconds = maxf(1.0, seconds - SHORT_DAYS)
		time_left = seconds
	# Only where a curse moved a body's health: a fight built by hand keeps the health it was given.
	for curse: String in [Curses.IRON_FOES, Curses.HUNGRY_MIMICS, Curses.LONG_WINTER]:
		if Curses.effect(curse) in effects:
			for i in lineup.size():
				health[i] = _health_of(lineup[i], i)
			hp = health[0]
			break


## What tier belongs at `position` in this fight's lineup: the boss that ends a set piece, an elite
## every `elite_every`, a common otherwise. Asked of the position rather than of an enemy, so it can
## answer for a place a farm run has not filled yet -- which is how the HUD's bar draws the pips of
## a cycle before their enemies exist.
func tier_for(position: int) -> EnemyRoster.Tier:
	if dungeon:
		# The block comes round for ever, counted in floors: Gollux on the fifteenth of every depth.
		var floor_at := first_floor + position
		if floor_at % enemies == enemies - 1:
			return EnemyRoster.Tier.BOSS
		return EnemyRoster.Tier.ELITE if floor_at % elite_every == elite_every - 1 \
				else EnemyRoster.Tier.COMMON
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
	_take_curses()
	if endless or dungeon or lineup.is_empty() or lineup[0] == MIMIC or lineup[0] == WALL_NAME:
		return
	# Grazing: more bodies on the same clock, on the front so the fight still ends on its elite.
	# Seeded from the cell like the lineup itself, so the tile fields the same herd every time.
	if _clause("grazing") and _lead == 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash(["grazing", cell])
		for i in GRAZING_MORE:
			var picked := EnemyRoster.pick(env, EnemyRoster.Tier.COMMON, rng)
			lineup.insert(0, picked)
			health.insert(0, _health_of(picked))
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
## `_append_enemy` builds the lineup to `tier_for` -- and test_combat pins that they do.
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
	health.append(_health_of(picked))


## Announces the first enemy, so whoever is drawing the fight can put it on the field. Safe to call
## more than once; a fight that is never started simply never announces anyone.
func start() -> void:
	enemy_coming.emit(index, lineup[index], hp)


## What one enemy is worth on this tile: an ordinary body grows with the distance from the middle of
## the map, and the enemy's own size and tier multiply it (a slime halves it, an elite trebles it).
## The settings' balancing page scales a body by the walls inside its tile; the ice wall has `WALL_HP`.
static func hp_of(enemy_name: String, cell: Vector2i, step := LAND_GROWTH) -> float:
	var tuned := 1.0 if enemy_name == WALL_NAME else hp_tuning(walls_inside(cell))
	return maxf(1.0, roundf(base_hp(cell, step) * EnemyRoster.hp_modifier(enemy_name) * tuned))


## What this circle's bodies are multiplied by: its base health (the balancing page's number, else
## `baseline_hp`) over the formula's own (`circle_base_hp`).
static func hp_tuning(walls: int) -> float:
	var wanted := Settings.hp_base(walls)
	if wanted <= 0.0:
		wanted = baseline_hp(walls)
	return wanted / circle_base_hp(walls)


## The base health a circle has with nothing set on the balancing page: `CIRCLE_HP`'s, else the formula's.
static func baseline_hp(walls: int) -> float:
	return float(CIRCLE_HP.get(walls, circle_base_hp(walls)))


## The formula's health for an ordinary body on the first ring of the circle with `walls` walls
## inside it: the middle tile inside the first wall, the ring past the wall's own after that.
static func circle_base_hp(walls: int) -> float:
	var ring := 0 if walls == 0 else MapBuilder.START_LAND_RADIUS + 2 + (walls - 1) * MapBuilder.WALL_STEP
	return base_hp(MapBuilder.CENTER + Vector2i(ring, 0))


## The health of an ordinary common body on this tile, before the enemy's own multiplier. A whole
## number, but a double rather than an int: the map has no edge and this is exponential in the walk,
## so an int64 overflowed a few hundred hexes out.
##
## Two terms: the smooth walk out from the middle, and a step for every wall already behind the cell.
## The step is what makes the land a wall opens a frontier again -- `LAND_GROWTH` for a body's health,
## `WALL_GROWTH` for the wall and for the size of a blow, which pass it as `step`.
static func base_hp(cell: Vector2i, step := LAND_GROWTH) -> float:
	return maxf(1.0, roundf(BASE_HP * pow(HP_GROWTH, HexGrid.distance(MapBuilder.CENTER, cell))
			* pow(step, walls_inside(cell))))


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
	"grass": "Meadows", "ice": "Frost", "mountains": "Peaks", DUNGEON_ENV: "Deep",
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
	var pick := hash(["title", cell, first_floor + index])
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


## A click: one blow (`_strike`) at the enemy in front of the player. Ignored while one is running in
## or dying, and once the fight is over. Returns whether it landed.
func hit() -> bool:
	# The Metronome's price: the player's own hand does nothing. The click still counts towards a
	# Knucklebone streak, which is the one thing clicking is good for beside it.
	var landed := false if "metronome" in effects or _cursed_with(Curses.PACIFIST_HANDS) \
			else _strike(false)
	if "knucklebone" in effects:
		_click_streak = mini(_click_streak + 1, KNUCKLE_MOST)
		_since_click = 0.0
	return landed


## What the player's gear and skills are worth, from `Inventory.stats()`. Called before the fight starts; a
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
	armor = maxf(0.0, float(stats.get("armor", 0.0)))
	dodge = maxf(0.0, float(stats.get("dodge", 0.0)))
	# Both are kept in tenths on the gear (`LootTable.SECONDS_STATS`); the fight wants seconds.
	block = maxf(0.0, LootTable.seconds_of("block", float(stats.get("block", 0.0))))
	time_on_hit = maxf(0.0, LootTable.seconds_of("time_on_hit", float(stats.get("time_on_hit", 0.0))))
	_bare_sockets = maxi(0, int(stats.get("bare_sockets", 0)))
	_bag_pieces = maxi(0, int(stats.get("bag_pieces", 0)))
	_strength = maxf(0.0, float(stats.get("strength", 0.0)))
	_dexterity = maxf(0.0, float(stats.get("dexterity", 0.0)))
	_attribute_lines = maxi(0, int(stats.get("attribute_lines", 0)))
	_pure_pieces = maxi(0, int(stats.get("pure_pieces", 0)))
	# Heartwood Plate: armour buys clock, and stops buying it at HEARTWOOD_MOST -- armour grows with
	# every level, and a clock that grew with it would be no clock. A run has none to add to.
	if "heartwood" in effects and not endless:
		seconds += minf(floorf(armor / HEARTWOOD_ARMOUR), HEARTWOOD_MOST)
		time_left = seconds
	# The Fight Clock on the gear, on the same terms: capped, and nothing on a run.
	var clock := LootTable.seconds_of("fight_clock", float(stats.get("fight_clock", 0.0)))
	if clock > 0.0 and not endless:
		seconds += minf(clock, CLOCK_MOST)
		time_left = seconds
	attack_speed = maxf(0.0, float(stats.get("attack_speed", 0.0)))
	bleed = maxf(0.0, float(stats.get("bleed", 0.0)))
	drop_rate = maxf(0.0, float(stats.get("drop_rate", 0.0)))
	item_rarity = maxf(0.0, float(stats.get("item_rarity", 0.0)))
	gold_find = maxf(0.0, float(stats.get("gold_find", 0.0)))
	orb_find = maxf(0.0, float(stats.get("orb_find", 0.0)))
	xp_more = maxf(0.0, float(stats.get("xp_more", 0.0)))
	# The tile's own say, last: what it takes off the player's numbers, and what it pays for the fight
	# it made -- added to the finders like any other percent, so `_kill` has no second path.
	armor *= TileMods.factor(mods, "armor")
	dodge *= TileMods.factor(mods, "dodge")
	block *= TileMods.factor(mods, "block")
	time_on_hit *= TileMods.factor(mods, "time_on_hit")
	attack_speed *= TileMods.factor(mods, "swing")
	# From the const rather than from `walk_in`, so arming twice does not take the share off twice.
	spawn_speed = clampf(float(stats.get("spawn_speed", 0.0)), 0.0, 100.0)
	walk_in = WALK_IN * TileMods.factor(mods, "walk_in") * (1.0 - spawn_speed / 100.0)
	if phase == Phase.WALKING_IN:
		phase_left = minf(phase_left, walk_in)
	if _cursed_with(Curses.HOMELAND) and _at_home():
		item_rarity += HOME_RARITY
	var pays := TileMods.WILD_REWARD if Curses.effect(Curses.WILD_TILES) in effects else 1.0
	drop_rate += TileMods.total(mods, "drop_rate") * pays
	item_rarity += TileMods.total(mods, "item_rarity") * pays
	gold_find += TileMods.total(mods, "gold_find") * pays
	xp_more += TileMods.total(mods, "xp") * pays


func _cursed_with(curse: String) -> bool:
	return Curses.effect(curse) in effects


## Whether this fight is on one of the Homeland's two lands.
func _at_home() -> bool:
	return (Curses.HOME_PREFIX + env) in effects


## How many things are spending the clock for damage: the Glass Edge, the Glass World, or both.
func _glass() -> int:
	return effects.count("glass_edge") + int(_cursed_with(Curses.GLASS_WORLD))


## Whether the weapon swings on its own at all: it has a speed, and neither the Berserker's Band nor
## the Berserker's World has stilled it.
func swings() -> bool:
	return attack_speed > 0.0 and not "berserk" in effects and not _cursed_with(Curses.BERSERKERS_WORLD)


## Raw Finds: a piece of gear falls as a common with nothing on it. Never a unique.
func _raw(item: Item) -> Item:
	if item != null and item.unique.is_empty() and _cursed_with(Curses.RAW_FINDS):
		item.rarity = ItemRarity.Rarity.COMMON
		item.mods = []
	return item


## `rate` as the lift that multiplies the finished chance by `factor`: a finder is a percent added to
## 100, so half the chance at +20% is -40%, and twice it is +140%.
static func _lifted(rate: float, factor: float) -> float:
	return (100.0 + rate) * factor - 100.0


## The dev's even loot: one find at a rarity drawn evenly from common to unique. A ground with no
## unique pool gives an elite in the unique's place.
func _even_find() -> Item:
	var level := MapBuilder.level_of(cell)
	var step := loot_rng.randi_range(ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNIQUE)
	if step == ItemRarity.Rarity.UNIQUE:
		var found := UniqueTable.roll(lineup[index], env, unique_rng, level, 0.0, true)
		if found != null:
			return found
		step = ItemRarity.Rarity.ELITE
	return LootTable.roll(lineup[index], loot_rng, true, level, 0.0, 0.0, step)


## The drop rate a gear roll is handed: the player's, or half the finished chance under Lean Pickings.
func _gear_rate() -> float:
	return _lifted(drop_rate, LEAN_LESS) if Curses.effect(Curses.LEAN_PICKINGS) in effects else drop_rate


## Lean Pickings' other half: a find that falls may fall already ascended. Drawn only under the
## curse, so nobody else's loot rolls as it did not before.
func _lean(item: Item) -> Item:
	if item == null or not Curses.effect(Curses.LEAN_PICKINGS) in effects:
		return item
	var roll := loot_rng.randf()
	var plus := 2 if roll < LEAN_PLUS[1] else 1 if roll < LEAN_PLUS[0] + LEAN_PLUS[1] else 0
	for i in plus:
		item.ascend()
	return item


## One blow, from a click or from the weapon swinging itself. Takes `damage` off the enemy in front
## of the player, crits at `crit_chance`, and kills it at zero. Ignored while one is running in or
## dying, and once the fight is over. Returns whether it landed.
func _strike(automatic: bool) -> bool:
	if finished or phase != Phase.WAITING:
		return false
	var chance := minf(crit_chance + _serpent, CRIT_CAP)
	var crit := chance > 0.0 and crit_rng.randf() * 100.0 < chance
	var first := not _struck
	_struck = true
	# The Duelist's Buckler: the first blow an enemy takes is a crit, whoever swung it.
	if first and "opening_strike" in effects:
		crit = true
	# The Serpent's Eye: one on each doll builds twice as fast.
	if "serpent" in effects:
		_serpent = 0.0 if crit else _serpent + SERPENT_STEP * effects.count("serpent")
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
	# Time on hit: a landed blow wins back what the enemies' blows took, and never more. A run has no
	# clock to win back.
	if not endless and wounds > 0.0 and time_on_hit > 0.0:
		var back := minf(time_on_hit, wounds)
		wounds -= back
		time_left += back
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
		if _cursed_with(Curses.BERSERKERS_WORLD):
			more += BERSERK_WORLD_MORE
		# The streak is the hand's: the weapon's own swings are not what it rewards.
		more += KNUCKLE_STEP * _click_streak * effects.count("knucklebone")
	if ("home:" + env) in effects:
		more += HOME_MORE
	if not endless:
		# Both are paid for in clock, and a run has none: there they are worth nothing.
		more += GLASS_MORE * _glass()
		if "last_gasp" in effects and time_left <= LAST_GASP_SECONDS:
			more += LAST_GASP_MORE
	if "ascetic" in effects:
		more += ASCETIC_MORE * _bare_sockets
	if "momentum" in effects:
		more += minf(MOMENTUM_MORE * kills(), MOMENTUM_MOST)
	if "packmule" in effects:
		more += PACKMULE_MORE * _bag_pieces
	more += PATCHWORK_MORE * _attribute_lines * effects.count("patchwork")
	more += PURIST_MORE * _pure_pieces * effects.count("purist")
	more += BRAWLER_MORE * (_dexterity if automatic else _strength) * effects.count("brawler")
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
	# The dungeon pays nothing, from anything: no gear, purse, experience, unique or orb, and no
	# Hourglass second either, which down here would be a clock that never ran out.
	if dungeon:
		return
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
	var rolls := 1
	if mimic:
		rolls = HUNGRY_ROLLS if Curses.effect(Curses.HUNGRY_MIMICS) in effects else MIMIC_ROLLS
	# The Tithe, and a Gilded tile: no ordinary gear at all, from anything.
	# And the Homeland's other four lands -- but never a chest or the wall, which are no land's.
	var abroad := _cursed_with(Curses.HOMELAND) and not _at_home() and not mimic \
			and lineup[index] != WALL_NAME
	var no_gear := "tithe" in effects or "gilded" in mods or abroad
	if no_gear or chest_unique != null:
		rolls = 0
	if even_loot and not mimic:
		rolls = 0
		if loot_rng.randf() < EVEN_LOOT_CHANCE:
			loot_dropped.emit(index, _even_find())
	var gear_rate := _gear_rate()
	for roll in rolls:
		var certain: bool = always_drop or mimic or (roll == 0
				and ((guarantee_elite and on_elite()) or (big and "trophy" in effects)))
		var dropped := LootTable.roll(lineup[index], loot_rng, certain, MapBuilder.level_of(cell),
				gear_rate, item_rarity)
		# Lucky Wound: a body that took a crit rolls again and leaves the better of the two.
		if _crit_landed and "lucky_wound" in effects:
			dropped = _better(dropped, LootTable.roll(lineup[index], loot_rng, certain,
					MapBuilder.level_of(cell), gear_rate, item_rarity))
		var found := 0
		while dropped != null:
			if first_sword:
				first_sword = false
				dropped = Item.rolled(LootTable.FIRST_DROP, ItemRarity.Rarity.COMMON, loot_rng)
			else:
				dropped = _lean(_raw(dropped))
			loot_dropped.emit(index, dropped)
			found += 1
			# A find that beat the chance rolls again, at the same chance and never guaranteed, up to
			# MOST_DROPS: a lucky body leaves a second piece and now and then a fourth. A certain roll --
			# `always_drop`, a mimic, the elite's promise, Trophy Hunter -- does not, because it beat
			# nothing: the promise is one piece.
			dropped = null if certain or found >= MOST_DROPS else LootTable.roll(lineup[index],
					loot_rng, false, MapBuilder.level_of(cell), gear_rate, item_rarity)
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
	if "magpie" in effects and not no_gear and loot_rng.randf() < MAGPIE_CHANCE:
		purse = 0.0
		loot_dropped.emit(index, _lean(_raw(LootTable.roll(lineup[index], loot_rng, true,
				MapBuilder.level_of(cell), drop_rate, item_rarity))))
	# The Pauper's curse, and a Barren tile, where a body carries nothing at all.
	if purse > 0.0 and Curses.effect(Curses.PAUPER) in effects:
		purse = maxf(1.0, roundf(purse * PAUPER_PURSE))
	if "barren" in mods:
		purse = 0.0
	if purse > 0.0:
		gold += purse
		gold_dropped.emit(index, purse)
	# Hard Lessons is a "less": what is left of the experience once every "more" has been added.
	var lessons := LESSONS_XP if Curses.effect(Curses.HARD_LESSONS) in effects else 1.0
	var worth := maxi(1, roundi(xp_of(lineup[index], cell) * (1.0 + xp_more / 100.0) * lessons))
	xp += worth
	xp_dropped.emit(index, worth)
	# A unique, beside the gear and not from its table: any body can carry one, off the pool of the
	# ground it stood on. Through `loot_dropped` like any find, so the pouch, the bag and the
	# verdict need no second path.
	# None before the player's 100th kill, and pure chance after it.
	var boss := EnemyRoster.tier_of(lineup[index]) == EnemyRoster.Tier.BOSS
	# A mimic's unique chance is its coin toss above, and nothing on top of it.
	if chest_unique != null:
		loot_dropped.emit(index, _lean(chest_unique))
	elif not mimic and not even_loot and uniques_after != NO_UNIQUES and index >= uniques_after:
		# Thick Fog's pay, and the Homeland's on its own two lands: factors on the finished chance,
		# whatever the drop rate already made of it.
		var lucky := (FOG_UNIQUES if _cursed_with(Curses.THICK_FOG) else 1.0) \
				* (HOME_UNIQUES if _cursed_with(Curses.HOMELAND) and _at_home() else 1.0)
		var unique_rate := _lifted(drop_rate, lucky)
		var found := UniqueTable.roll(lineup[index], env, unique_rng, MapBuilder.level_of(cell),
				unique_rate, false, item_rarity)
		if found != null:
			loot_dropped.emit(index, _lean(found))
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
	if first_orb:
		first_orb = false
		orb = OrbTable.FIRST_ORB
	elif always_orb or index >= orbs_after:
		orb = OrbTable.roll(lineup[index], orb_rng, always_orb, _lifted(orb_find + drop_rate,
				RAW_ORBS if _cursed_with(Curses.RAW_FINDS) else 1.0))
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
		# And in the dungeon neither does a death: a floor's comings and goings are the same second for
		# everybody, and charged for they would be most of what a strong descent is scored on.
		if (_clause("frozen_clock") and phase == Phase.WALKING_IN) \
				or (dungeon and phase != Phase.WAITING):
			spent -= minf(delta, phase_left)
		# The Glass Edge's price, and the Glass World's: each is a third faster, and both are both.
		spent *= pow(GLASS_CLOCK, _glass())
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
	_be_struck(delta)
	# The weapon has swung; now what is already in the body. The Sunscorched Cowl's Heatstroke takes
	# its share of the body's health, and a mace's wound takes its share of the blow that opened it.
	if _clause("heatstroke"):
		_wear_down(enemy_max_hp() * HEATSTROKE_SHARE, delta)
	_wear_down(_bleed, delta)
	if not endless and time_left <= 0.0 and not finished:
		# Second Wind: once a fight, the clock gets back what the capstone says rather than running out.
		if "second_wind" in effects and not _second_wind_used:
			_second_wind_used = true
			time_left = SECOND_WIND_SECONDS
		else:
			# A descent is not lost, only over: the floor it reached is the whole of it.
			_finish(dungeon)


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


## The enemy standing there striking the clock, once every `ATTACK_EVERY` of its tier. Only in a
## fight with a clock to strike, and never the ice wall, which is a check on damage and nothing else.
func _be_struck(delta: float) -> void:
	if not strikes or endless or dungeon or finished or phase != Phase.WAITING or delta <= 0.0 			or lineup[index] == WALL_NAME:
		return
	# A Frenzied tile brings the blows round sooner; a Savage one and the Bloodthirst make each bigger.
	var every: float = ATTACK_EVERY[EnemyRoster.tier_of(lineup[index])] / (1.0 + _attack_more)
	_attack += delta
	while _attack >= every and phase == Phase.WAITING and not finished:
		_attack -= every
		_struck_by(hit_of(lineup[index], cell) * (1.0 + _hit_more))


## One blow at the clock: dodged whole, or cut by armour and then block and taken off `time_left`.
## Split from `_be_struck` so a test can land one blow of a size it chose.
func _struck_by(hit: float) -> void:
	if crit_rng.randf() < dodge_chance():
		# Afterimage: a dodge wins back some of what the blows took, never more, so it banks nothing.
		if "afterimage" in effects:
			var back := minf(AFTERIMAGE_SECONDS, wounds)
			wounds -= back
			time_left += back
		player_hit.emit(0.0, true, false)
		return
	# Shield Wall: block counts double against an elite's or a boss's blow.
	var big := index < lineup.size() and EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON
	var lost := taken(hit, block * (2.0 if big and "shieldwall" in effects else 1.0))
	time_left = maxf(time_left - lost, 0.0)
	wounds += lost
	player_hit.emit(lost, false, lost <= 0.0)
	# Bulwark: a blow block stops entirely is answered at once, by the weapon's own swing.
	if lost <= 0.0 and "riposte" in effects:
		_strike(true)


## What a blow of `hit` seconds takes off the clock once it lands: armour takes its share, then block
## takes its seconds off what is left. 100 seconds against 90% armour and 10 block is nothing.
func taken(hit: float, blocked := -1.0) -> float:
	var kept := hit * (1.0 - _share(armor, ARMOUR_K))
	return maxf(0.0, kept - (block if blocked < 0.0 else blocked))


## The chance, 0 to 1, that the player steps out of a blow altogether, whatever its size.
func dodge_chance() -> float:
	return _share(dodge, DODGE_K)


## A rating's share of any blow: `rating / (rating + k)`. Never the whole, however high.
static func _share(rating: float, k: float) -> float:
	if rating <= 0.0:
		return 0.0
	return rating / (rating + k)


## How many seconds one blow from this enemy is worth on this tile, before the player's defence: a
## common's HIT_SECONDS, grown with the walk as its health is and stepped by `WALL_GROWTH` at a wall
## (not the land's `LAND_GROWTH`: a body past a wall is tougher, not harder-hitting), and
## multiplied by what its tier's blow is worth. The size of the body does not come into it -- a slime
## and a giant of one tier take the same off the clock.
static func hit_of(enemy_name: String, cell: Vector2i) -> float:
	return HIT_SECONDS * base_hp(cell, WALL_GROWTH) / BASE_HP * float(HIT_TIER[EnemyRoster.tier_of(enemy_name)])


## The weapon swinging on its own, `attack_speed` times a second. Only earns while an enemy is
## standing there to be hit, so nothing accrues through a walk-in or a death and a fast weapon
## cannot arrive at the next body with a fistful of banked swings.
func _swing_weapon(delta: float) -> void:
	# The Berserker's Band: the weapon never swings on its own.
	if not swings() or finished or phase != Phase.WAITING:
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
	_attack = 0.0
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
		phase_left = walk_in
		enemy_coming.emit(index, lineup[index], hp)
		return
	_has_risen = false
	index += 1
	if index >= lineup.size():
		if not endless and not dungeon:
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
	phase_left = walk_in
	enemy_coming.emit(index, lineup[index], hp)


func _finish(win: bool) -> void:
	finished = true
	victory = win
	phase = Phase.OVER
	if win:
		won.emit()
	else:
		lost.emit()
