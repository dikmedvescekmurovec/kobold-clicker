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
## A rune off a body in Gollux's cave (`RuneTable`), once the third wall has opened them (`runes_drop`).
signal rune_dropped(index: int, rune: String)
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
## From the fourth wall on, a wall is this many ordinary common bodies of the ring just inside it,
## and WALL_HP and WALL_GROWTH stop applying (the user's, 2026-10-09): the land stepping by
## LAND_GROWTH and the wall by WALL_GROWTH left the sixth wall weaker than one body beside it.
const LATE_WALL_BODIES := 150.0
## `walls_inside` of the first wall LATE_WALL_BODIES sizes: the fourth has three inside it.
const LATE_WALL_FROM := 3
## The dungeon: a block of fifteen floors that repeats for ever, an elite every fifth and a boss on
## the fifteenth, against one minute. `enemies` is the block, which is what the HUD's bar stands.
const DUNGEON := {"enemies": 15, "seconds": 60.0, "elite_every": 5, "boss_last": true}
## Where its creatures live (`EnemyRoster`) and what is drawn behind them: no land on the map.
const DUNGEON_ENV := "cave"
## What one floor down multiplies a body's health by: a depth is fifteen of them, so the next Gollux
## wants nine times the damage the last one did (1.1578 ^ 15 = 9.0) -- slower than the walls' sixteen
## (the user's, 2026-10-03). The dial for how far apart the depths are.
const DUNGEON_GROWTH := 1.1578
## What the first Gollux's health is rounded to (`gollux_hp`).
const GOLLUX_ROUND := 500000.0
## What a floor's body is worth by its tier, and nothing else about it: the roster's sizes and its
## own tiers are for land. A rat and a crab on one floor are the same health. Gollux is not here: he is
## his depth's wall (`gollux_hp`).
const DUNGEON_TIER_HP := {
	EnemyRoster.Tier.COMMON: 1.0,
	EnemyRoster.Tier.ELITE: 2.0,
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
## Seconds a common's blow takes off the clock at the very middle, before the walk out multiplies it
## (`hit_of`). The dial for how much defence matters at all.
const HIT_SECONDS := 0.25
## What a blow grows by a ring, and a step for every wall behind the cell: their own, not health's
## HP_GROWTH and WALL_GROWTH, because armour is a share and a share can only keep up with a blow that
## grows slowly (the user's, 2026-09-28: 244 armour takes a common's blow on ring 25 to about 1 s).
const HIT_GROWTH := 1.1
const HIT_WALL_GROWTH := 1.5
## Armour and dodge are ratings, and a rating is a flat share of every blow whatever its size:
## `rating / (rating + K)`, so K of it is half, 9K is 90%, and no amount of it ever reaches the whole
## -- which is what lets both grow with the level for ever with no cap. The two dials for what a
## point of each is worth.
const ARMOUR_K := 50.0
const DODGE_K := 50.0
## The most the helmet's three "less" lines come to -- less off an elite's blow, less of a tile
## modifier, less health -- because a "less" that reached the whole would be no blow, no modifier and no
## body. Three quarters is four times the damage, or a quarter of the blow.
const WARD_MOST := 75.0
## How long a blow's recoup takes to come back, and a burn to burn out. Both are in their lines' text
## (`ModifierTable.MODS`), so a change here is a change there.
const RECOUP_SECONDS := 4.0
const BURN_SECONDS := 3.0
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
## Beginner's Luck: the crit chance it sets, whatever the gear says.
const BEGINNERS_LUCK := 25.0
var damage: float = BARE_DAMAGE
var crit_chance := 0.0
var crit_damage := 0.0
## Swings a second the weapon takes on its own. Zero with nothing equipped, so a bare-handed fight is
## exactly the clicking game this was before gear meant anything.
var attack_speed := 0.0
## The ceiling on `attack_speed`, after everything that multiplies it (the user's dial, 2026-10-03):
## past about ten a second the swings, numbers and sounds are a smear, and the hand's share of the
## damage -- clicks over clicks and swings -- falls under a third at an attentive five clicks.
const SWING_CAP := 10.0
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
## The weapon's own lines, in percent: more of a click, of a swing, of a blow at an elite or a boss and
## of the first blow a body takes -- one sum, `gear_more` -- and the chance a blow lands twice.
var click_damage := 0.0
var swing_damage := 0.0
var elite_damage := 0.0
var first_blow := 0.0
var double_strike := 0.0
## The rings' Elite Chance, in percent: how often a common comes on as an elite of its ground instead
## (`_promote`). Drawn on a generator of its own, and only while there is any, so nobody else's stream
## moves; unseeded, because which bodies come on promoted belongs to the attempt, as the loot does.
var elite_chance := 0.0
var elite_rng := RandomNumberGenerator.new()
## The helmet's, the body's and the offhand's lines (`arm`), all percents but the count and the seconds:
## how much later an enemy's first blow comes, how much less an elite's or a boss's takes, how much of
## a tile modifier's bite is gone, how much less health every body has (the three "less" ones held to
## `WARD_MOST`), what a camp pays more, bodies more or fewer in a tile fight, a share of `damage`
## struck back at a blow that lands, a share of what a blow took coming back over `RECOUP_SECONDS`
## (held to certainty), crit chance a dodge hands the next blow, a share of a blow burning on over
## `BURN_SECONDS`, and seconds a blow the block stops whole wins back.
var blow_delay := 0.0
var elite_ward := 0.0
var tile_ward := 0.0
var less_health := 0.0
var camp_more := 0.0
var extra_enemies := 0
var thorns := 0.0
var recoup := 0.0
var parry := 0.0
var burn := 0.0
var time_on_block := 0.0
## Whether `arm` has shaped the lineup already rolled -- its count, its health, its elite chance
## (`_shape`) -- which it does once however often it runs.
var _promoted := false
## What a dodge handed the next blow in crit chance (`parry`), spent by whichever blow comes next.
var _parry := 0.0
## The burn on the body in front of the player: damage a second, and the seconds it has left. The
## deepest one, refreshed by every blow, cleared with the body like `_bleed`.
var _burn := 0.0
var _burn_left := 0.0
## What the blows are still owed back (`recoup`): one [seconds left, a second] a blow.
var _recouping: Array = []

## How much of the next automatic swing has been earned. Only runs while an enemy is standing there
## to be hit, so a slow weapon loses nothing to a walk-in and cannot bank swings through a death.
var _swing := 0.0

## Damage a second the body in front of the player is losing to the wound the last blow left: the
## deepest one it has taken, never a sum of them. It belongs to that body and to no other, so it is
## cleared with `_blows` as the next one comes on.
var _bleed := 0.0

## Whether crits go the player's way. Unseeded on purpose, like `loot_rng` and for the same reason:
## the tile's enemies are fixed before the player arrives, but how a given attempt goes is not.
var crit_rng := RandomNumberGenerator.new()

## The terrain the fight is on. It picked the enemies, and it picks the backdrop they are drawn on.
var env := ""
## Whether an elite is promised a drop. Nothing in the game turns this on (it was the Broken Sword's
## promise until 2026-10-10, which is `PROMISED`'s now): like `always_drop`, it is for the tests and the
## screenshot scripts.
var guarantee_elite := false

## The finds a new player's first kills are scripted to leave (the user's, 2026-10-10) -> the lifetime
## kills each falls between: after the first of its pair and by the second, every kill of them as likely
## as the next and the last one certain (`_due`). The Broken Sword (`LootTable.FIRST_DROP`), then the
## orbs to craft it with in the order they are used (`OrbTable.FIRST_ORB`, `SECOND_ORB`), then the first
## unique (`UniqueTable.FIRST_UNIQUE`) and the first skill node (`SkillTree.first`).
const SWORD := "sword"
const TRANSMUTE := "transmute"
const AUGMENT := "augment"
const UNIQUE := "unique"
const NODE := "node"
const PROMISED := {SWORD: [0, 10], TRANSMUTE: [10, 20], AUGMENT: [20, 30], UNIQUE: [100, 120], NODE: [150, 170]}
## The orb that spends each orb promise.
const ORB_PROMISES := {OrbTable.FIRST_ORB: TRANSMUTE, OrbTable.SECOND_ORB: AUGMENT}
## The promises this player is still owed (`Inventory.promised`) and the kills they had made as the
## fight opened, which a promise's kills are counted from. The main scene sets both; each is spent here
## by the find it is. While the sword is owed any piece of gear that falls is it, common and level 1, so
## it is the player's first whatever the table rolled; while the node is, no other node falls. A fight
## nobody tells is owed nothing.
var promised: Array = []
var kills_before := 0

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

## The deepest wall ever broken (`Inventory.walls_ever`), which decides the orbs that can drop here
## (`OrbTable.unlocked`). The main scene sets it; a fight nobody tells drops every orb.
var walls_down := OrbTable.EVERY_WALL

## What changes how this fight plays rather than a number, by effect id (`Inventory.effects()`): the
## capstone skills the player has learned and the uniques they are wearing. A worn unique is one entry
## a piece, so two of one ring are two entries. A fight nobody tells has none.
var effects: Array = []
## The player's rank of each unique, id -> 1..`UniqueTable.PEAK` (`Achievements.ranks`), which every
## ranked rule reads its number at (`_dial`). A unique it does not name is at rank I, so a fight nobody
## tells is the rank I fight.
var ranks := {}

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
## Whether a body can leave a skill stone (`SkillTree.roll`), drawn on a generator of its own for the
## reason `orb_rng` is. The main scene turns it on once the first sword has dropped -- a stone before it
## would spend that promise (`FightLedger.add_loot`) -- and a fight nobody tells drops none, so every
## test that counts what a body leaves counts what it always did.
var stone_drops := false
var stone_rng := RandomNumberGenerator.new()
## The uniques the player has unlocked (`Achievements.unlocked`), the only ones a body can carry. The
## main scene sets it; a fight nobody tells has none, on the same terms as `uniques_after`.
var unlocked: Array = []

## What this fight did, for the achievements (`Achievements.record`): counts, and the best of each
## streak (`_best`). It stays on the fight and the main scene reads it as the fight ends, so the camp --
## which plays fights of its own to price a night -- counts nothing.
var tally := {}
var _dry := 0
var _one_blow := 0

## The Knucklebone Ring's streak: clicks made within `KNUCKLE_WINDOW` of the one before, and how long
## ago the last one was. A click counts whether or not it lands, or every walk-in would break it.
const KNUCKLE_WINDOW := 1.0
var _click_streak := 0
var _since_click := 0.0
## The hand's allowance (`click`), the user's dials (2026-10-03): it fills at `CLICK_CAP` a second on the
## fight's own time and holds `CLICK_BURST`, so a hand at sixteen a second loses one click in sixteen
## and an autoclicker gets `CLICK_CAP`. Not a least gap between clicks: a hand's gaps wander, and a
## gap of a fifteenth of a second would halve a steady sixteen to eight.
const CLICK_CAP := 15.0
const CLICK_BURST := 3.0
var _clicks_left := CLICK_BURST
## What a blow has to leave an enemy under, as a share of its health, for the Assassin capstone to
## finish it; the Headsman's share (`UniqueTable`) adds to it.
const EXECUTE_SHARE := 0.1
## What the last killing blow did past the body's health, which Cleave carries into the next one.
var _overkill := 0.0
## What Dominoes carries into the next body: its rank's share of what a one-blow kill had left over,
## dealt as that body takes its stand -- and a body it fells passes its own leftover on.
var _carried := 0.0

## The Gambler's Die, on a generator of its own so a test can pin what it rolls.
var gamble_rng := RandomNumberGenerator.new()
## What the uniques are tuned by where a rank does not move it. The ranked numbers are the unique's own
## row (`UniqueTable`, read through `_dial`), so a card's sentence and the fight agree.
const GLASS_MORE := 1.0          ## the Glass World's; the Glass Edge's is its rank's
const GLASS_CLOCK := 4.0 / 3.0   ## how fast the Glass Edge spends the clock
const GAMBLE_LEAST := 0.01       ## the Gambler's Die's worst blow; its best is its rank's
const LAST_GASP_MORE := 2.0
const MOMENTUM_MORE := 0.02      ## per kill
const MOMENTUM_MOST := 1.0
const HEARTWOOD_ARMOUR := 50.0   ## armour a second on the clock
const AFTERIMAGE_SECONDS := 1.0  ## the most a dodge wins back, of what blows have taken
const SECOND_WIND_SECONDS := 5.0 ## given back once a fight, as the clock runs out
const MAGPIE_CHANCE := 0.05
## What the lines a unique gains at rank IV are tuned by (`UniqueTable`'s `peak` says each in words).
const SERPENT_KEPT := 0.5        ## of the built chance a crit leaves, Serpent's Eye
const SPIKES_BACK := 0.1         ## of the armour a blow dodged or blocked whole sends back, Spiked Helm
const OGRE_EXECUTE_STRENGTH := 100.0  ## strength a percent of Execute, Ogre's Knuckle
const OGRE_EXECUTE_MOST := 25.0  ## and the most percent it comes to
const HOME_XP := 100.0           ## more experience on grass, Meadowstriders
const HOME_PURSE := 2.0          ## what a desert purse is multiplied by, Sunscorched Cowl
const HOME_CLOCK := 0.5          ## how fast the clock runs on ice, Rimeplate
const HOME_ORBS := 2.0           ## what the orb chance on dirt is multiplied by, Gravedigger's Charm
const ASCETIC_DODGE := 0.05      ## dodge chance a bare place, Ascetic's Cord
const DODGE_MOST := 0.9          ## and the most it may lift the chance to
const DOMINO_BIG := 0.5          ## of the carry an elite or a boss takes, Dominoes
const HOURGLASS_BOSS := 5.0      ## seconds a boss kill puts back, Hourglass Amulet
const BERSERK_EVERY := 10        ## clicks that land, one of which strikes twice, Berserker's Band
const CHALICE_TWICE := 0.1       ## of crits that strike twice, Overflowing Chalice
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
## Runes on a farm run's tile (`RuneTable`, the user's 2026-10-09; never a camp): `deeper` levels higher
## for every Depth still working -- each as `MapBuilder.LEVEL_TILES` rings further out for a body's health
## and purse, and a level for its experience and for what it drops (`_level`) -- and `ascended`, what
## drops falling ascended as Lean Pickings' do. Their modifiers ride in `mods` with the tile's own.
var deeper := 0
var ascended := false
## Whether a body in the cave may carry a rune: the third wall's unlock, which the main scene says.
var runes_drop := false
## The elite pace before any modifier set it, which `forget_mod` goes back to.
var _base_elite_every := 0
## Seconds an enemy of this fight spends running in: `WALK_IN`, or longer in a Mire, or shorter for
## what the gear's spawn speed takes off it -- none at all at 100%.
var walk_in := WALK_IN
## The gear's share of the walk-in taken off, 0-100.
var spawn_speed := 0.0
## What the tile and the world add to every body's health, to every blow and to how often one comes,
## as shares: **one sum each**, the way `unique_more` is, so a Thick-skinned tile under Iron Foes is
## +110% and not +140%.
var _hp_more := 0.0
var _hit_more := 0.0
var _attack_more := 0.0
## More experience off every body, in percent: the tile's and the world's, added.
var xp_more := 0.0
## Whether `wear` has already taken the curses on, which it must do once however often it is called.
var _cursed := false
## Whether `wear` has already sent the Dreadmask's commons away, which it must do once as well.
var _dreaded := false
## The seconds `arm` last added to the clock for the gear, so arming again moves it by the difference.
var _clock_more := 0.0
## What keeps a blow off the clock (`taken`, `_struck_by`): two ratings, seconds off each blow, and
## seconds a landed hit of the player's wins back of what the blows took.
var armor := 0.0
var dodge := 0.0
var block := 0.0
var time_on_hit := 0.0
## Seconds the enemies' blows have taken off the clock and time on hit has not yet won back. Time on
## hit heals this and nothing else, so it can undo a blow and never the clock's own running.
var wounds := 0.0
## How many of the fight's saves -- the Guard tree's Second Wind, a Worry Stone -- have been spent.
var _saves_used := 0
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
## About the enemy that is out: how many blows it has taken, and whether the last blow was a crit
## (so, once it is down, whether a crit felled it -- a wound's death clears it). Cleared as the next
## one comes on.
var _blows := 0
var _crit_kill := false
## The Serpent's Eye's crit chance, built by every blow that did not crit and spent by the one that
## does. Kept for the whole fight, across bodies, so a run carries it from one enemy to the next.
var _serpent := 0.0
## Whether the body going down now was felled by its first blow, which is what Dominoes carries from.
var _domino := false
## Rank IV's say about one body: whether its first blow has been blocked (Heartwood Plate), whether
## it died of its wound (Butcher's Cleaver), and the health an execution took (Headsman).
var _walled := false
var _bled_out := false
var _executed := 0.0
## Clicks that have landed, for the Berserker's Band at IV: every `BERSERK_EVERY`th strikes twice.
var _hand_blows := 0


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


## The first Gollux's health: the second ice wall's, whatever the wall is tuned to, rounded to the
## nearest `GOLLUX_ROUND` and never under it (the user's, 2026-10-03).
static func gollux_hp() -> float:
	var wall := for_wall(MapBuilder.CENTER + Vector2i(MapBuilder.START_LAND_RADIUS + 1 + MapBuilder.WALL_STEP, 0)).hp
	return maxf(GOLLUX_ROUND, snappedf(wall, GOLLUX_ROUND))


## The depth the player is in, from 1. It moves only as a Gollux goes down: he is the last floor of
## his depth, so the floor after him is the first of the next.
func depth() -> int:
	return (first_floor + index) / enemies + 1


## How many depths this descent has won: the Golluxes it has killed.
func cleared() -> int:
	return depth() - 1 - first_floor / enemies


## A farm run on `cell`: the same enemies the tile's terrain fields, coming forever, with no clock
## and no count. It ends when the player says so. `deeper` is the Depth runes on it (`RuneTable`).
##
## It keeps the tile's own elite rhythm -- a run on a town throws one up every five -- and never its
## boss: a boss is what a set piece ends on, and a run does not end.
static func farm(cell: Vector2i, env: String, variant := "", mods: Array = [], deeper := 0) -> Encounter:
	var fight := Encounter.new()
	fight.env = env
	fight.cell = cell
	fight.endless = true
	# Before the first body, whose health it lifts: the Depth runes on the tile.
	fight.deeper = deeper
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
	_base_elite_every = elite_every
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


## The health `enemy` starts this fight with: `_raw_health_of`, less the helmet's Enemy Health Reduction --
## on every body there is, the wall's and the dungeon's too, since everything worn reaches them.
func _health_of(enemy: String, position := -1) -> float:
	return maxf(1.0, roundf(_raw_health_of(enemy, position) * (1.0 - less_health / 100.0)))


## The health `enemy` starts this fight with before the gear has a say: what the tile makes it worth
## (`hp_of`), more for whatever the tile and the world add. The ice wall answers to `WALL_HP` and the
## Long Winter and to nothing else -- it is the check on the player, and a tile's modifier is not what
## it checks.
func _raw_health_of(enemy: String, position := -1) -> float:
	if dungeon:
		# The floor and the tier and nothing else: no tile's modifier and no world's curse reaches down
		# here. Asked as a body joins, the floor is how many are already built; `_take_curses`, sizing
		# them again, says which.
		var floor_at := first_floor + (health.size() if position < 0 else position)
		if EnemyRoster.tier_of(enemy) == EnemyRoster.Tier.BOSS:
			# Gollux: the first is the second ice wall, and each after it a depth's growth on.
			return roundf(gollux_hp() * pow(DUNGEON_GROWTH, floor_at - (enemies - 1)))
		return maxf(1.0, roundf(BASE_HP * pow(DUNGEON_GROWTH, floor_at)
				* float(DUNGEON_TIER_HP[EnemyRoster.tier_of(enemy)])))
	if enemy == WALL_NAME:
		# `hp_of` at WALL_GROWTH carries a step for every wall inside this one, and a wall's own ring
		# counts none of itself, so the second wall comes out WALL_GROWTH times the first on top of
		# the band's walk. Not LAND_GROWTH: that is the land's.
		var walls := walls_inside(cell)
		var wall_hp := hp_of(enemy, cell, WALL_GROWTH) * WALL_HP
		if walls >= LATE_WALL_FROM:
			var inside := MapBuilder.CENTER + Vector2i(HexGrid.distance(MapBuilder.CENTER, cell) - 1, 0)
			wall_hp = base_hp(inside) * hp_tuning(walls) * LATE_WALL_BODIES
		return roundf(wall_hp * (LONG_WINTER_HP if Curses.effect(Curses.LONG_WINTER) in effects else 1.0))
	var more := 1.0 + _hp_more
	if enemy == MIMIC and Curses.effect(Curses.HUNGRY_MIMICS) in effects:
		more += HUNGRY_HP
	return maxf(1.0, roundf(hp_of(enemy, cell) * more * pow(HP_GROWTH, MapBuilder.LEVEL_TILES * deeper)))


## The level of what drops here and what a body's experience is counted at: the tile's, and a level
## more for every Depth rune working on it.
func _level() -> int:
	return MapBuilder.level_of(cell) + deeper


## A rune's modifier has worn off mid-run (`RuneTable.count_kill`): one listing of `id` -- a tier -- leaves
## the fight, and what it shaped is shaped again from the next body on. What it paid goes at the next
## `arm`, which the main scene calls.
func forget_mod(id: String) -> void:
	var at := mods.find(id)
	if at < 0:
		return
	mods.remove_at(at)
	var row: Dictionary = TileMods.MODS[id]
	_hp_more -= float(row.get("hp", 0.0))
	_hit_more -= float(row.get("hit", 0.0))
	_attack_more -= float(row.get("attack", 0.0))
	if row.has("elite_every"):
		elite_every = int(TileMods.value(id, "elite_every", mods.count(id))) if id in mods else _base_elite_every


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
	if position % elite_every == elite_every - 1:
		return EnemyRoster.Tier.ELITE
	return EnemyRoster.Tier.COMMON


## What the player is wearing and has learned, and the rank of each unique (`ranks`), told to the fight
## before it starts -- before `arm`, which reads some of it. Setting `effects` by hand does everything
## but take the curses on, which is what most tests want.
func wear(worn: Array, unique_ranks := {}) -> void:
	effects = worn
	ranks = unique_ranks
	_take_dread()
	_take_curses()


## The Dreadmask: its number of commons fewer, less one for every ice wall inside the tile, taken off
## the front of the lineup so the elites and the boss still come, and never the last body standing.
## A fight on the land only -- a farm run has no count to shorten and the dungeon's depths are its own.
func _take_dread() -> void:
	if _dreaded or endless or dungeon or not "dread" in effects:
		return
	_dreaded = true
	var fewer := int(_dial("dreadmask", "fewer")) - walls_inside(cell)
	var at := 0
	while fewer > 0 and at < lineup.size() and lineup.size() > 1:
		if EnemyRoster.tier_of(lineup[at]) == EnemyRoster.Tier.COMMON:
			lineup.remove_at(at)
			health.remove_at(at)
			fewer -= 1
		else:
			at += 1
	enemies = lineup.size()
	hp = health[0]


## One of a worn unique's numbers at the rank this fight was told (`ranks`), rank I if it was told none.
func _dial(id: String, key: String) -> float:
	return UniqueTable.dial(id, key, int(ranks.get(id, 1)))


## Whether the player has `id` at rank IV, where it gains its last line (`UniqueTable.peak_text`).
## Asked beside whether it is worn, never instead of it.
func _peak(id: String) -> bool:
	return int(ranks.get(id, 1)) >= UniqueTable.PEAK


## Whether this fight is on a home piece's own ground with that piece worn at rank IV.
func _home_peak() -> bool:
	return ("home:" + env) in effects and _peak(UniqueTable.home_piece(env))


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
	_promote(lineup.size() - 1)


## Elite Chance: the common at `at` comes on as an elite of its ground instead, sized as one. Never in the
## dungeon, whose floors are counted, and with no chance nothing is drawn. Whether it was.
func _promote(at: int) -> bool:
	if dungeon or elite_chance <= 0.0 or EnemyRoster.tier_of(lineup[at]) != EnemyRoster.Tier.COMMON \
			or elite_rng.randf() * 100.0 >= elite_chance:
		return false
	var picked := EnemyRoster.pick(env, EnemyRoster.Tier.ELITE, elite_rng)
	if picked.is_empty():
		return false
	lineup[at] = picked
	health[at] = _health_of(picked, at)
	return true


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
	return index


## A click: one blow (`_strike`) at the enemy in front of the player. Ignored while one is running in
## or dying, and once the fight is over. Returns whether it landed.
func hit() -> bool:
	# The Metronome's price: the player's own hand does nothing. The click still counts towards a
	# Knucklebone streak, which is the one thing clicking is good for beside it.
	var landed := false if "metronome" in effects or _cursed_with(Curses.PACIFIST_HANDS) \
			else _strike(false)
	if "knucklebone" in effects:
		_click_streak += 1
	_count("clicks")
	_since_click = 0.0
	return landed


## A click from the player's hand: `hit()`, unless the hand has outrun its allowance (`CLICK_CAP`). One
## past it is no click at all -- no blow, no streak, no count. The camp and the tests call `hit()`.
func click() -> bool:
	if _clicks_left < 1.0:
		return false
	_clicks_left -= 1.0
	return hit()


## What the player's gear and skills are worth, from `Inventory.stats()`. Called before the fight starts,
## and again whenever the gear changes in the bag mid-fight, so everything here is worked out afresh
## from `stats` and the clock moves by the difference. A fight nobody arms is a bare-handed one, which
## is what every test that does not care gets.
func arm(stats: Dictionary) -> void:
	damage = maxf(BARE_DAMAGE, roundf(float(stats.get("damage", 0.0))) + BARE_DAMAGE)
	# Clamped, because a chance is not a quantity: eight pieces each adding crit chance can total
	# more than certainty, and a save written before LootTable.CHANCE_STATS holds pieces that do it on
	# their own. Past the cap every hit crit, which is a crit meaning nothing.
	var raw_crit := BEGINNERS_LUCK if "beginners_luck" in effects else float(stats.get("crit_chance", 0.0))
	crit_chance = clampf(raw_crit, 0.0, CRIT_CAP)
	crit_damage = float(stats.get("crit_damage", 0.0))
	# The Overflowing Chalice: what the clamp above throws away is kept as crit damage.
	if "overcrit" in effects:
		crit_damage += maxf(0.0, raw_crit - CRIT_CAP) * _dial("overflowing_chalice", "times")
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
	blow_delay = maxf(0.0, float(stats.get("blow_delay", 0.0)))
	elite_ward = clampf(float(stats.get("elite_ward", 0.0)), 0.0, WARD_MOST)
	tile_ward = clampf(float(stats.get("tile_ward", 0.0)), 0.0, WARD_MOST)
	less_health = clampf(float(stats.get("less_health", 0.0)), 0.0, WARD_MOST)
	camp_more = maxf(0.0, float(stats.get("camp_earnings", 0.0)))
	extra_enemies = roundi(float(stats.get("extra_enemies", 0.0)))
	thorns = maxf(0.0, float(stats.get("thorns", 0.0)))
	recoup = clampf(float(stats.get("recoup", 0.0)), 0.0, 100.0)
	parry = maxf(0.0, float(stats.get("parry", 0.0)))
	burn = maxf(0.0, float(stats.get("burn", 0.0)))
	time_on_block = maxf(0.0, LootTable.seconds_of("time_on_block", float(stats.get("time_on_block", 0.0))))
	# Heartwood Plate: armour buys clock, and stops buying it at its rank's most -- armour grows with
	# every level, and a clock that grew with it would be no clock. A run has none to add to.
	var more := 0.0
	if "heartwood" in effects and not endless:
		more += minf(floorf(armor / HEARTWOOD_ARMOUR), _dial("heartwood_plate", "most"))
	# The Fight Clock on the gear, on the same terms: capped, and nothing on a run.
	var clock := LootTable.seconds_of("fight_clock", float(stats.get("fight_clock", 0.0)))
	if clock > 0.0 and not endless:
		more += minf(clock, CLOCK_MOST)
	# Weaker tile modifiers give back their share of what a Dusk took off the clock.
	if not endless:
		more -= TileMods.total(mods, "seconds") * tile_ward / 100.0
	# By the difference, so arming again mid-fight -- a piece put on in the bag -- gives or takes what
	# changed and never fills the clock again.
	seconds += more - _clock_more
	time_left += more - _clock_more
	_clock_more = more
	attack_speed = maxf(0.0, float(stats.get("attack_speed", 0.0)))
	bleed = maxf(0.0, float(stats.get("bleed", 0.0)))
	drop_rate = maxf(0.0, float(stats.get("drop_rate", 0.0)))
	item_rarity = maxf(0.0, float(stats.get("item_rarity", 0.0)))
	gold_find = maxf(0.0, float(stats.get("gold_find", 0.0)))
	orb_find = maxf(0.0, float(stats.get("orb_find", 0.0)))
	click_damage = maxf(0.0, float(stats.get("click_damage", 0.0)))
	swing_damage = maxf(0.0, float(stats.get("swing_damage", 0.0)))
	elite_damage = maxf(0.0, float(stats.get("elite_damage", 0.0)))
	first_blow = maxf(0.0, float(stats.get("first_blow", 0.0)))
	double_strike = clampf(float(stats.get("double_strike", 0.0)), 0.0, 100.0)
	elite_chance = clampf(float(stats.get("elite_chance", 0.0)), 0.0, 100.0)
	# What is already rolled is shaped once, as the fight is first armed; a run's later bodies are asked
	# as they join (`_append_enemy`).
	if not _promoted:
		_promoted = true
		_shape()
	xp_more = maxf(0.0, float(stats.get("xp_more", 0.0)))
	# Meadowstriders at IV: double experience on grass, added like any other "more".
	if env == "grass" and _home_peak():
		xp_more += HOME_XP
	# The tile's own say, last: what it takes off the player's numbers, and what it pays for the fight
	# it made -- added to the finders like any other percent, so `_kill` has no second path.
	armor *= _tile_factor("armor")
	dodge *= _tile_factor("dodge")
	block *= _tile_factor("block")
	time_on_hit *= _tile_factor("time_on_hit")
	attack_speed = minf(attack_speed * _tile_factor("swing"), SWING_CAP)
	# From the const rather than from `walk_in`, so arming twice does not take the share off twice.
	spawn_speed = clampf(float(stats.get("spawn_speed", 0.0)), 0.0, 100.0)
	walk_in = WALK_IN * _tile_factor("walk_in") * (1.0 - spawn_speed / 100.0)
	if phase == Phase.WALKING_IN:
		phase_left = minf(phase_left, walk_in)
	if _cursed_with(Curses.HOMELAND) and _at_home():
		item_rarity += HOME_RARITY
	var pays := TileMods.WILD_REWARD if Curses.effect(Curses.WILD_TILES) in effects else 1.0
	drop_rate += TileMods.total(mods, "drop_rate") * pays
	item_rarity += TileMods.total(mods, "item_rarity") * pays
	gold_find += TileMods.total(mods, "gold_find") * pays
	xp_more += TileMods.total(mods, "xp") * pays


## What the gear does to the lineup already rolled, once, as the fight is first armed: bodies more or
## fewer (`_take_extra`), a tile's Thick-skinned weakened and every body's health less, then the elite
## chance. Health is sized again only where the gear moved it, so a fight built by hand keeps its own.
func _shape() -> void:
	_take_extra()
	var thinner := tile_ward > 0.0 and TileMods.total(mods, "hp") > 0.0
	if thinner:
		_hp_more -= TileMods.total(mods, "hp") * tile_ward / 100.0
	if thinner or less_health > 0.0:
		for at in range(index, lineup.size()):
			health[at] = _health_of(lineup[at], at)
		if index < lineup.size():
			hp = health[index]
	for at in range(index, lineup.size()):
		if _promote(at) and at == index:
			hp = health[at]


## The body armour's count: commons put on the front of what is left, from the cell's own draw so a
## tile fields the same ones each time, or taken off the front, never the last body standing. A tile's
## fight only -- a run has no count, the dungeon's floors are counted, and a wall or a chest is one body.
func _take_extra() -> void:
	if extra_enemies == 0 or endless or dungeon or index >= lineup.size() or lineup[index] in [WALL_NAME, MIMIC]:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["extra", cell])
	for i in extra_enemies:
		var picked := EnemyRoster.pick(env, EnemyRoster.Tier.COMMON, rng)
		if picked.is_empty():
			break
		lineup.insert(index, picked)
		health.insert(index, _health_of(picked, index))
	var fewer := -extra_enemies
	var at := index
	while fewer > 0 and at < lineup.size() and lineup.size() - index > 1:
		if EnemyRoster.tier_of(lineup[at]) == EnemyRoster.Tier.COMMON:
			lineup.remove_at(at)
			health.remove_at(at)
			fewer -= 1
		else:
			at += 1
	enemies = lineup.size()
	hp = health[index]


## A tile modifier's factor on one of the player's numbers, less the share of its bite the helmet's
## Tile Modifier Reduction takes back: half the armour under a Piercing tile at 50% is three quarters.
func _tile_factor(key: String) -> float:
	return 1.0 + (TileMods.factor(mods, key) - 1.0) * (1.0 - tile_ward / 100.0)


## What the helmet's Tile Modifier Reduction takes back of an added lift the tile put on (`hit`, `attack`).
func _softened(key: String) -> float:
	return TileMods.total(mods, key) * tile_ward / 100.0


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
	var level := _level()
	var step := loot_rng.randi_range(ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNIQUE)
	if step == ItemRarity.Rarity.UNIQUE:
		var found := UniqueTable.roll(lineup[index], unlocked, unique_rng, level, 0.0, true)
		if found != null:
			return found
		step = ItemRarity.Rarity.ELITE
	return LootTable.roll(lineup[index], loot_rng, true, level, 0.0, 0.0, step)


## The drop rate a gear roll is handed: the player's, or half the finished chance under Lean Pickings.
func _gear_rate() -> float:
	return _lifted(drop_rate, LEAN_LESS) if Curses.effect(Curses.LEAN_PICKINGS) in effects else drop_rate


## Lean Pickings' other half, and the Ascent rune's whole: a find that falls may fall already ascended.
## Drawn only under the curse or on an ascended tile, so nobody else's loot rolls as it did not before.
func _lean(item: Item) -> Item:
	if item == null or not (Curses.effect(Curses.LEAN_PICKINGS) in effects or ascended):
		return item
	var roll := loot_rng.randf()
	var plus := 2 if roll < LEAN_PLUS[1] else 1 if roll < LEAN_PLUS[0] + LEAN_PLUS[1] else 0
	for i in plus:
		item.ascend()
	return item


## One blow, from a click or from the weapon swinging itself. Takes `damage` off the enemy in front
## of the player, crits at `crit_chance`, and kills it at zero. Ignored while one is running in or
## dying, and once the fight is over. Returns whether it landed. `riposte` is the Bulwark's answer to a
## blow block stopped whole, which lands at its rank's share of a swing.
func _strike(automatic: bool, riposte := false) -> bool:
	if finished or phase != Phase.WAITING:
		return false
	# Beginner's Luck sets the chance outright, so the Serpent's Eye and a dodge have nothing to build on.
	var chance := crit_chance if "beginners_luck" in effects \
			else minf(crit_chance + _serpent + _parry, CRIT_CAP)
	_parry = 0.0
	var crit := chance > 0.0 and crit_rng.randf() * 100.0 < chance
	var first := _blows == 0
	_blows += 1
	var big := EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON
	# The Duelist's Buckler: the first blows an enemy takes are crits, whoever swung them.
	var opening := "opening_strike" in effects and _blows <= _dial("duelists_buckler", "blows")
	# The Bulwark at IV: its answer is always a crit.
	if opening or (riposte and _peak("bulwark")):
		crit = true
	if crit:
		_count("crits")
		_dry = 0
	# Cold Streak's: only a blow that could have crit is one without a crit. At no chance at all every
	# blow would be, and the first fight would earn every rank (the user's ruling, 2026-10-02).
	elif chance > 0.0:
		_dry += 1
		_best("dry_streak", _dry)
	# The Serpent's Eye: one on each doll builds twice as fast, and at IV a crit keeps some of it.
	if "serpent" in effects:
		if crit:
			_serpent = _serpent * SERPENT_KEPT if _peak("serpents_eye") else 0.0
		else:
			_serpent += _dial("serpents_eye", "step") * effects.count("serpent")
	_crit_kill = crit
	# Crit damage is what a crit adds, not what it multiplies to: 50 means half again, the way Path
	# of Exile's crit multiplier reads once you take its base 100 off. The Duelist's Buckler at IV adds
	# it twice with an opening blow on an elite or a boss.
	var crit_more := crit_damage * (2.0 if opening and big and _peak("duelists_buckler") else 1.0)
	var dealt := maxf(1.0, roundf(damage * (1.0 + crit_more / 100.0))) if crit else damage
	if "giant_slayer" in effects and big:
		dealt *= 2
	# What the weapon's lines add to this kind of blow, and then everything the uniques add -- each
	# summed and applied once, `gear_more` and `unique_more`.
	dealt *= 1.0 + gear_more(automatic, big, first)
	dealt = maxf(1.0, roundf(dealt * (1.0 + unique_more(automatic))))
	if riposte:
		dealt = maxf(1.0, roundf(dealt * _dial("bulwark", "share") / 100.0))
	# Two blows' worth, now and then: every tenth click that lands under the Berserker's Band at IV, and
	# one crit in ten under the Overflowing Chalice at IV (drawn only then, so no one else's crits move).
	if not automatic and "berserk" in effects and _peak("berserkers_band"):
		_hand_blows += 1
		if _hand_blows % BERSERK_EVERY == 0:
			dealt *= 2.0
	if crit and "overcrit" in effects and _peak("overflowing_chalice") and crit_rng.randf() < CHALICE_TWICE:
		dealt *= 2.0
	# Double Strike: the blow lands twice, drawn only where there is a chance, like the Chalice's.
	if double_strike > 0.0 and crit_rng.randf() * 100.0 < double_strike:
		dealt *= 2.0
	# The Gambler's Die is not more damage but a different blow every time, so it stands outside that.
	# At IV the first blow on each enemy is drawn twice and the better kept.
	if "gamble" in effects:
		var top := _dial("gamblers_die", "top")
		var worth := gamble_rng.randf_range(GAMBLE_LEAST, top)
		if first and _peak("gamblers_die"):
			worth = maxf(worth, gamble_rng.randf_range(GAMBLE_LEAST, top))
		dealt = maxf(1.0, roundf(dealt * worth))
	hp -= dealt
	# Execute takes what is left once it is a sliver, so the last hits of a big body are not wasted.
	# The Ogre's Knuckle at IV makes strength Execute as well, to a most.
	var finish := EXECUTE_SHARE if "execute" in effects else 0.0
	if "headsman" in effects:
		finish += _dial("headsman", "share") / 100.0
	if "ogre" in effects and _peak("ogres_knuckle"):
		finish += minf(_strength / OGRE_EXECUTE_STRENGTH, OGRE_EXECUTE_MOST) / 100.0
	if hp > 0 and hp < enemy_max_hp() * finish:
		# The Headsman at IV: what the execution took for nothing goes on into the next body, as Cleave's does.
		if "headsman" in effects and _peak("headsman"):
			_executed = hp
		hp = 0.0
	hit_landed.emit(dealt, crit, automatic)
	enemy_hit.emit(hp)
	if hp <= 0:
		# Dominoes: felled by the first blow it took, so what the blow had left over carries on.
		_domino = first and "domino" in effects
		if crit:
			_count("crit_kills")
		_one_blow = _one_blow + 1 if first else 0
		_best("domino_streak", _one_blow)
		_kill(automatic)
	else:
		# The mace's Bleed: the body goes on losing this share of the blow every second it stands.
		# The deeper wound wins and nothing adds, so what a mace is worth is the size of one blow and
		# not how many of them land -- a weapon that swung twice as fast would otherwise bleed twice
		# as hard for free.
		_bleed = maxf(_bleed, dealt * bleed / 100.0)
		# The torch's Burn: its share of the blow over `BURN_SECONDS`, the deepest one, lit again by
		# every blow.
		if burn > 0.0:
			_burn = maxf(_burn, dealt * burn / 100.0 / BURN_SECONDS)
			_burn_left = BURN_SECONDS
	# Time on hit: a landed blow wins back what the enemies' blows took, and never more. A run has no
	# clock to win back.
	if not endless and wounds > 0.0 and time_on_hit > 0.0:
		var back := minf(time_on_hit, wounds)
		wounds -= back
		time_left += back
	return true


## What one blow does on average as `_strike` deals it, against a common body as the fight starts: its
## crits, everything the uniques and curses add (`unique_more`), the Berserker's Band's tenth click and
## the Overflowing Chalice's doubled crit at IV, the weapon's click or swing damage and its double
## strike, and the Gambler's Die's mean -- but no streak built, no kill made, no clock run low, and
## nothing of Giant Slayer or Elite Damage, which are for elites, or of First Blow Damage. `automatic`
## is the weapon's swing; a click is the hand's, and does nothing where the hand does nothing (`hit`).
## Next to `_strike` so the two move together: the character page's damage per click and per second.
func average_blow(automatic: bool) -> float:
	if not automatic and ("metronome" in effects or _cursed_with(Curses.PACIFIST_HANDS)):
		return 0.0
	var crits := crit_chance / 100.0 * crit_damage / 100.0
	if "overcrit" in effects and _peak("overflowing_chalice"):
		crits += crit_chance / 100.0 * CHALICE_TWICE * (1.0 + crit_damage / 100.0)
	var blow := damage * (1.0 + crits) * (1.0 + gear_more(automatic, false, false)) \
			* (1.0 + unique_more(automatic)) * (1.0 + double_strike / 100.0)
	if not automatic and "berserk" in effects and _peak("berserkers_band"):
		blow *= 1.0 + 1.0 / BERSERK_EVERY
	if "gamble" in effects:
		blow *= (GAMBLE_LEAST + _dial("gamblers_die", "top")) / 2.0
	return blow


## A second of the weapon on its own, hands off: its average swing as often as it swings, and the
## bleed and the burn that leaves. Nothing where it does not swing at all. The character page's headline
## and the character panel's line, beside `average_blow(false)`, a click.
func per_second() -> float:
	return average_blow(true) * (attack_speed + bleed / 100.0 + burn / 100.0 / BURN_SECONDS) \
			if swings() else 0.0


## What the weapon's lines add to a blow, as a share: the hand's Click Damage or the weapon's own Swing
## Damage, Elite Damage on an elite or a boss (`big`), and First Blow Damage on the first blow a body
## takes (`first`). **One sum**, as `unique_more` is and beside it: a gear line is not a unique's.
func gear_more(automatic: bool, big: bool, first: bool) -> float:
	var more := swing_damage if automatic else click_damage
	if big:
		more += elite_damage
	if first:
		more += first_blow
	return more / 100.0


## What the worn uniques add to a blow, as a share: 2.0 is three times the damage. **One sum**, the
## way `Equipment.totals` adds its global percents, and for the same reason: twenty-odd uniques that
## each multiplied would let a stack of them outrun the map, and every one would beat any crafted
## piece in its socket. Added, a full stack is worth a stretch of frontier and no more.
func unique_more(automatic: bool) -> float:
	var more := 0.0
	if automatic:
		more += (_dial("metronome", "times") - 1.0) * effects.count("metronome")
	else:
		more += (_dial("berserkers_band", "times") - 1.0) * effects.count("berserk")
		if _cursed_with(Curses.BERSERKERS_WORLD):
			more += BERSERK_WORLD_MORE
	# The streak is the hand's: the weapon's own swings are not what it rewards -- until rank IV, where
	# the full bonus reaches them too.
	if "knucklebone" in effects:
		var most := _dial("knucklebone_ring", "most")
		var bonus := minf(_dial("knucklebone_ring", "step") * _click_streak, most)
		if not automatic or (bonus >= most and _peak("knucklebone_ring")):
			more += bonus / 100.0 * effects.count("knucklebone")
	if ("home:" + env) in effects:
		more += _dial(UniqueTable.home_piece(env), "times") - 1.0
	# The clock pieces are paid for in clock, and a run has none: there they are worth nothing -- but
	# the Glass Edge at IV pays where no clock runs as well.
	if not endless or _peak("glass_edge"):
		more += (_dial("glass_edge", "times") - 1.0) * effects.count("glass_edge")
	if not endless:
		if _cursed_with(Curses.GLASS_WORLD):
			more += GLASS_MORE
		if "last_gasp" in effects and time_left <= _dial("last_gasp", "seconds"):
			more += LAST_GASP_MORE
	if "ascetic" in effects:
		more += _dial("ascetics_cord", "more") / 100.0 * _bare_sockets
	if "momentum" in effects:
		more += minf(MOMENTUM_MORE * kills(), MOMENTUM_MOST)
	if "packmule" in effects:
		more += _dial("packmule", "more") / 100.0 * _bag_pieces
	if "patchwork" in effects:
		more += _dial("patchwork_coat", "more") / 100.0 * _attribute_lines * effects.count("patchwork")
	if "purist" in effects:
		more += _dial("purists_seal", "more") / 100.0 * _pure_pieces * effects.count("purist")
	if "brawler" in effects:
		# Strength on the hand and dexterity on the weapon -- and at IV both on both.
		var points := _strength + _dexterity if _peak("brawlers_wraps") else (_dexterity if automatic else _strength)
		more += _dial("brawlers_wraps", "more") / 100.0 * points * effects.count("brawler")
	return more


## The enemy that is out goes down, and everything it was carrying is handed over. Apart from
## `_strike` because a blow is not the only thing that kills: a wound does it with none, and so does
## what Dominoes carries into a body as it takes its stand. `swung` is whether the weapon's own swing
## felled it, which the Metronome at IV answers with the next swing the moment the next body stands.
func _kill(swung := false) -> void:
	var big := EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON
	phase = Phase.DYING
	phase_left = DEATH
	_swing = 1.0 if swung and "metronome" in effects and _peak("metronome") else 0.0
	# What the killing blow had past the body's health: Cleave carries the whole of it, Dominoes its
	# rank's share where the body fell to its first blow, and the Headsman at IV what an execution took.
	var over := maxf(0.0, -hp)
	_overkill = (over if "cleave" in effects else 0.0) + _executed
	_executed = 0.0
	_carried = over * _dial("dominoes", "share") / 100.0 if _domino else 0.0
	_domino = false
	enemy_died.emit(index)
	# The dungeon pays nothing, from anything: no gear, purse, experience, unique or orb, and no
	# Hourglass second either, which down here would be a clock that never ran out -- but a rune, the
	# one thing only it has, once the third wall has opened them.
	if dungeon:
		if runes_drop:
			var rune := RuneTable.roll(lineup[index], loot_rng)
			if not rune.is_empty():
				rune_dropped.emit(index, rune)
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
		chest_unique = UniqueTable.roll(lineup[index], unlocked, unique_rng, _level(),
				drop_rate, true)
	var rolls := 1
	if mimic:
		rolls = HUNGRY_ROLLS if Curses.effect(Curses.HUNGRY_MIMICS) in effects else MIMIC_ROLLS
	# The Tithe, and a Gilded tile: no ordinary gear at all, from anything -- but at IV the Tithe lets
	# an elite's and a boss's through. And the Homeland's other four lands -- but never a chest or the
	# wall, which are no land's.
	var abroad := _cursed_with(Curses.HOMELAND) and not _at_home() and not mimic \
			and lineup[index] != WALL_NAME
	var tithe := "tithe" in effects and not (big and _peak("the_tithe"))
	var no_gear := tithe or "gilded" in mods or abroad
	if no_gear or chest_unique != null:
		rolls = 0
	if even_loot and not mimic:
		rolls = 0
		if loot_rng.randf() < EVEN_LOOT_CHANCE:
			loot_dropped.emit(index, _even_find())
	var gear_rate := _gear_rate()
	# The Broken Sword's kill: a certain piece, which the swap below makes the sword.
	var sword := _due(SWORD, loot_rng)
	for roll in rolls:
		# Promised: the sword, Trophy Hunter's big bodies, and a forest elite under the Hunter's Lantern
		# at IV.
		var certain: bool = always_drop or mimic or (roll == 0
				and (sword or (guarantee_elite and on_elite()) or (big and "trophy" in effects)
				or (on_elite() and env == "forest" and _home_peak())))
		var dropped := LootTable.roll(lineup[index], loot_rng, certain, _level(),
				gear_rate, item_rarity)
		# Lucky Wound: a body felled by a crit rolls its rank's number of times and leaves the best.
		if _crit_kill and "lucky_wound" in effects:
			for again in int(_dial("lucky_wound", "rolls")) - 1:
				dropped = _better(dropped, LootTable.roll(lineup[index], loot_rng, certain,
						_level(), gear_rate, item_rarity))
		var found := 0
		while dropped != null:
			if SWORD in promised:
				promised.erase(SWORD)
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
					loot_rng, false, _level(), gear_rate, item_rarity)
	# Every body carries one, which is the whole difference between gold and gear: nine kills in
	# ten leave nothing, and all ten leave this.
	# Gold find lifts the purse here rather than inside `gold_of`, which is what the body is worth
	# and is read by things that have no player in them -- a town's prices are quoted off it.
	# Drop rate finds everything, so it is in this sum too, **added** to gold find the way two global
	# percents add: 20 and 30 are half again as much gold, not 56% more.
	var purse := maxf(1.0, roundf(gold_of(lineup[index], cell)
			* (1.0 + (gold_find + drop_rate) / 100.0) * pow(GOLD_GROWTH, MapBuilder.LEVEL_TILES * deeper)))
	# Two Tithes add (at rank I five times, not nine), the way two global modifiers do.
	purse *= 1.0 + (_dial("the_tithe", "times") - 1.0) * effects.count("tithe")
	# The Sunscorched Cowl at IV: a desert purse is twice as full.
	if env == "desert" and _home_peak():
		purse *= HOME_PURSE
	# Drawn only while Jackpot is learned, so a player without it rolls loot exactly as before.
	if "jackpot" in effects and loot_rng.randf() < 0.1:
		purse *= 5
	# The Magpie's Band: now and then the purse is a piece of gear instead. The Tithe wins where
	# both are worn -- no ordinary gear means none -- and the purse stays a purse.
	if "magpie" in effects and not no_gear and loot_rng.randf() < MAGPIE_CHANCE:
		purse = 0.0
		loot_dropped.emit(index, _lean(_raw(LootTable.roll(lineup[index], loot_rng, true,
				_level(), drop_rate, item_rarity))))
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
	# A Depth rune's level counts the way the tile's own does: experience is so much a level.
	var worth := maxi(1, roundi(xp_of(lineup[index], cell) * float(_level()) / MapBuilder.level_of(cell)
			* (1.0 + xp_more / 100.0) * lessons))
	xp += worth
	xp_dropped.emit(index, worth)
	# A unique, beside the gear and not from its table: any body can carry one, off the pool of what
	# the player has unlocked. Through `loot_dropped` like any find, so the pouch, the bag and the
	# verdict need no second path.
	# None before the player's 100th kill, then the promised first (`PROMISED`), and pure chance after it.
	var boss := EnemyRoster.tier_of(lineup[index]) == EnemyRoster.Tier.BOSS
	# A mimic's unique chance is its coin toss above, and nothing on top of it.
	if chest_unique != null:
		loot_dropped.emit(index, _lean(chest_unique))
	elif not mimic and not even_loot and _due(UNIQUE, unique_rng):
		# The first unique, promised: the one row, at a level the ground's as any unique's is.
		promised.erase(UNIQUE)
		loot_dropped.emit(index, _lean(UniqueTable.roll(lineup[index], [UniqueTable.FIRST_UNIQUE],
				unique_rng, _level(), 0.0, true)))
	elif not mimic and not even_loot and uniques_after != NO_UNIQUES and index >= uniques_after:
		# Thick Fog's pay, and the Homeland's on its own two lands: factors on the finished chance,
		# whatever the drop rate already made of it.
		var lucky := (FOG_UNIQUES if _cursed_with(Curses.THICK_FOG) else 1.0) \
				* (HOME_UNIQUES if _cursed_with(Curses.HOMELAND) and _at_home() else 1.0)
		var unique_rate := _lifted(drop_rate, lucky)
		var found := UniqueTable.roll(lineup[index], unlocked, unique_rng, _level(),
				unique_rate, false, item_rarity)
		# A second chance, never a second unique: a boss in the mountains under Stonebreaker at IV, and a
		# crit kill under the Lucky Wound at IV.
		if found == null and ((boss and env == "mountains" and _home_peak())
				or (_crit_kill and "lucky_wound" in effects and _peak("lucky_wound"))):
			found = UniqueTable.roll(lineup[index], unlocked, unique_rng, _level(),
					unique_rate, false, item_rarity)
		if found != null:
			# Luck got there first: the promise is a first unique, and this is one.
			promised.erase(UNIQUE)
			loot_dropped.emit(index, _lean(found))
	# The Hourglass: its rank's seconds back for anything but a boss -- and at IV a boss's own -- and
	# never past what the fight began with, so the clock can be held but not banked. A run has no clock
	# to give to.
	if "hourglass" in effects and not endless:
		if not boss:
			time_left = minf(seconds, time_left + _dial("hourglass_amulet", "seconds"))
		elif _peak("hourglass_amulet"):
			time_left = minf(seconds, time_left + HOURGLASS_BOSS)
	# A third draw, on its own generator and its own curve. Beside the gear rather than instead
	# of it: a body that left a sword can leave an orb too, which is what makes the two rates
	# independent numbers rather than one number split.
	# Drop rate adds to orb find here for the reason it adds to gold find above, and `chance_for` is
	# handed the sum rather than taught about a second stat.
	# The two promised ones first, through `orbs_after` and the chance.
	var orb := ""
	if _due(TRANSMUTE, orb_rng):
		orb = OrbTable.FIRST_ORB
	elif _due(AUGMENT, orb_rng):
		orb = OrbTable.SECOND_ORB
	elif always_orb or index >= orbs_after:
		# Raw Finds, and the Gravedigger's Charm at IV on dirt: factors on the finished chance.
		orb = OrbTable.roll(lineup[index], orb_rng, always_orb, _lifted(orb_find + drop_rate,
				(RAW_ORBS if _cursed_with(Curses.RAW_FINDS) else 1.0)
				* (HOME_ORBS if env == "dirt" and _home_peak() else 1.0)), walls_down)
	if not orb.is_empty():
		# Either promise is spent by its orb, however that came.
		promised.erase(ORB_PROMISES.get(orb))
		var count := 2 if "transmute" in effects and orb_rng.randf() < 0.25 else 1
		for i in count:
			orbs[orb] = int(orbs.get(orb, 0)) + 1
			orb_dropped.emit(index, orb)
	# A fourth: a skill stone, gear's chance in a share, on its own generator. Not gear, so neither a
	# curse nor a unique that keeps gear from falling keeps it.
	# None before the promised first, which is no roll at all.
	if _due(NODE, stone_rng):
		promised.erase(NODE)
		loot_dropped.emit(index, SkillTree.first(lineup[index], stone_rng, _level()))
	elif stone_drops and NODE not in promised:
		var stone := SkillTree.roll(lineup[index], stone_rng, _level(), drop_rate,
				item_rarity)
		if stone != null:
			loot_dropped.emit(index, stone)


## Whether the body going down is the one that leaves `promise` (`PROMISED`): owed, past the kills it
## waits for, and the draw -- one chance in however many of its kills are left, so each is as likely as
## the next and the last is certain, as is any after it that a fight runs on into. Drawn only for a
## promise owed, so a fight owed nothing rolls as it always did.
func _due(promise: String, rng: RandomNumberGenerator) -> bool:
	if promise not in promised:
		return false
	var kill := kills_before + index + 1
	return kill > int(PROMISED[promise][0]) \
			and rng.randi_range(kill, maxi(kill, int(PROMISED[promise][1]))) == kill


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
		# The Glass Edge's price, and the Glass World's: each is a third faster, and both are both.
		spent *= pow(GLASS_CLOCK, _glass())
		# Rimeplate at IV: on ice the clock runs slower.
		if env == "ice" and _home_peak():
			spent *= HOME_CLOCK
		time_left = maxf(time_left - spent, 0.0)
	_since_click += delta
	_clicks_left = minf(_clicks_left + delta * CLICK_CAP, CLICK_BURST)
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
	# The weapon has swung; now what is already in the body: a mace's wound takes its share of the
	# blow that opened it, and a torch's burn its share until it burns out.
	_wear_down(_bleed, delta, true)
	if _burn_left > 0.0:
		var burning := minf(delta, _burn_left)
		_burn_left -= burning
		_wear_down(_burn, burning)
	# And what the blows took coming back, before the clock is asked whether it ran out.
	if not endless and not _recouping.is_empty():
		_recoup(delta)
	if not endless and time_left <= 0.0 and not finished:
		# Second Wind and the Worry Stone: once a fight each, the clock gets back SECOND_WIND_SECONDS
		# rather than running out, and the two add up.
		if _saves_used < effects.count("second_wind") + effects.count("worry_stone"):
			_saves_used += 1
			time_left = SECOND_WIND_SECONDS
		else:
			# A descent is not lost, only over: the floor it reached is the whole of it.
			_finish(dungeon)


## A body wearing down with nobody touching it, at `a_second` damage a second. Only while it is
## standing -- one walking in or already going down takes none of it, the way an automatic swing lands
## on neither -- and a death this way was nobody's blow, so Dominoes cannot come of it.
func _wear_down(a_second: float, delta: float, bleeding := false) -> void:
	if a_second <= 0.0 or finished or phase != Phase.WAITING or delta <= 0.0:
		return
	hp -= a_second * delta
	enemy_hit.emit(maxf(hp, 0.0))
	if hp <= 0.0:
		_domino = false
		_crit_kill = false
		_one_blow = 0
		_bled_out = bleeding
		if bleeding:
			_count("bleed_kills")
		_kill()


## The enemy standing there striking the clock, once every `ATTACK_EVERY` of its tier. Only in a
## fight with a clock to strike, and never the ice wall, which is a check on damage and nothing else.
func _be_struck(delta: float) -> void:
	if not strikes or endless or dungeon or finished or phase != Phase.WAITING or delta <= 0.0 			or lineup[index] == WALL_NAME:
		return
	# Last Gasp at IV: in its last seconds the enemies hold their blows.
	if "last_gasp" in effects and _peak("last_gasp") and time_left <= _dial("last_gasp", "seconds"):
		return
	# A Savage tile and the Bloodthirst make each blow bigger, less what weaker tile modifiers take back.
	var every := _attack_every()
	_attack += delta
	while _attack >= every and phase == Phase.WAITING and not finished:
		_attack -= every
		_struck_by(hit_of(lineup[index], cell) * (1.0 + _hit_more - _softened("hit")))


## How often the enemy out now strikes: its tier's `ATTACK_EVERY`, sooner on a Frenzied tile, less what
## weaker tile modifiers take back.
func _attack_every() -> float:
	return ATTACK_EVERY[EnemyRoster.tier_of(lineup[index])] / (1.0 + _attack_more - _softened("attack"))


## One blow at the clock: dodged whole, or cut by armour and then block and taken off `time_left`.
## Split from `_be_struck` so a test can land one blow of a size it chose.
func _struck_by(hit: float) -> void:
	# The Heartwood Plate at IV: every enemy's first blow is blocked whole, before any dodge is rolled --
	# a block like any other, so the Bulwark answers it and it is counted.
	var walled := not _walled and "heartwood" in effects and _peak("heartwood_plate")
	if walled:
		_walled = true
	elif crit_rng.randf() < dodge_chance():
		# Afterimage: a dodge wins back some of what the blows took, never more, so it banks nothing.
		if "afterimage" in effects:
			_win_back(AFTERIMAGE_SECONDS)
		# The buckler's line: the next blow carries the crit chance, the best of what dodges handed it.
		_parry = maxf(_parry, parry)
		player_hit.emit(0.0, true, false)
		_spikes_back()
		return
	# Shield Wall: block counts double against an elite's or a boss's blow.
	var big := index < lineup.size() and EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON
	var lost := 0.0 if walled else taken(hit, block * (2.0 if big and "shieldwall" in effects else 1.0))
	# The helmet's Elite Blow Reduction: a share less of whatever got through from an elite or a boss.
	if big:
		lost *= 1.0 - elite_ward / 100.0
	time_left = maxf(time_left - lost, 0.0)
	wounds += lost
	# The body's Recoup: a share of it coming back evenly over the next few seconds (`_recoup`).
	if lost > 0.0 and recoup > 0.0:
		var owed := lost * recoup / 100.0
		_recouping.append([owed, owed / RECOUP_SECONDS])
	_count("blows_taken")
	if lost <= 0.0:
		_count("blocked")
	player_hit.emit(lost, false, lost <= 0.0)
	# Bulwark: a blow block stops entirely is answered at once, by the weapon's own swing at its share.
	if lost <= 0.0 and "riposte" in effects:
		_strike(true, true)
	if lost <= 0.0:
		# The shield's Time on Block: such a blow wins back what earlier ones took.
		_win_back(time_on_block)
		_spikes_back()
	# The body's Thorns: a blow that landed, blocked or not, hits back a share of the damage -- nobody's
	# blow (`_wear_down`), so no crit, no unique's more and no Dominoes come of it.
	if thorns > 0.0:
		_wear_down(damage * thorns / 100.0, 1.0)


## Seconds back on the clock out of what the blows took (`wounds`), never more, so nothing is banked.
func _win_back(seconds: float) -> void:
	var back := minf(seconds, wounds)
	if back <= 0.0:
		return
	wounds -= back
	time_left += back


## What the blows are owed back by `recoup`, a second's share of each at a time, out of the wounds.
func _recoup(delta: float) -> void:
	for owed: Array in _recouping:
		var give := minf(float(owed[0]), float(owed[1]) * delta)
		owed[0] = float(owed[0]) - give
		_win_back(give)
	_recouping = _recouping.filter(func(owed: Array) -> bool: return float(owed[0]) > 0.0)


## The Spiked Helm at IV: a blow dodged or blocked whole sends a share of the armour back into the body
## -- nobody's blow (`_wear_down`), so no crit, no unique's more and no Dominoes come of it.
func _spikes_back() -> void:
	if "spikes" in effects and _peak("spiked_helm"):
		_wear_down(armor * SPIKES_BACK, 1.0)


## What a blow of `hit` seconds takes off the clock once it lands: armour takes its share, then block
## takes its seconds off what is left. 100 seconds against 90% armour and 10 block is nothing.
func taken(hit: float, blocked := -1.0) -> float:
	var kept := hit * (1.0 - _share(armor, ARMOUR_K))
	return maxf(0.0, kept - (block if blocked < 0.0 else blocked))


## The chance, 0 to 1, that the player steps out of a blow altogether, whatever its size. The
## Ascetic's Cord at IV adds a little a bare place, never lifting it past `DODGE_MOST`.
func dodge_chance() -> float:
	var chance := _share(dodge, DODGE_K)
	if "ascetic" in effects and _peak("ascetics_cord"):
		chance = minf(chance + ASCETIC_DODGE * _bare_sockets, maxf(chance, DODGE_MOST))
	return chance


## A rating's share of any blow: `rating / (rating + k)`. Never the whole, however high.
static func _share(rating: float, k: float) -> float:
	if rating <= 0.0:
		return 0.0
	return rating / (rating + k)


## How many seconds one blow from this enemy is worth on this tile, before the player's defence: a
## common's HIT_SECONDS, grown by `HIT_GROWTH` a ring and stepped by `HIT_WALL_GROWTH` at a wall
## (far slower than health: a body past a wall is tougher, not much harder-hitting), and
## multiplied by what its tier's blow is worth. The size of the body does not come into it -- a slime
## and a giant of one tier take the same off the clock.
static func hit_of(enemy_name: String, cell: Vector2i) -> float:
	return HIT_SECONDS * pow(HIT_GROWTH, HexGrid.distance(MapBuilder.CENTER, cell)) \
			* pow(HIT_WALL_GROWTH, walls_inside(cell)) * float(HIT_TIER[EnemyRoster.tier_of(enemy_name)])


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
		# The helmet's Enemy First Blow Delay: the first blow waits its share of an interval longer.
		_attack = -_attack_every() * blow_delay / 100.0
		enemy_spawned.emit(index, lineup[index], hp)
		_take_carried()
		return
	_blows = 0
	_crit_kill = false
	_walled = false
	# The Butcher's Cleaver at IV: a body that died of its wound hands it to the next.
	if not (_bled_out and "butcher" in effects and _peak("butchers_cleaver")):
		_bleed = 0.0
	_bled_out = false
	_burn = 0.0
	_burn_left = 0.0
	_attack = 0.0
	index += 1
	if index >= lineup.size():
		if not endless and not dungeon:
			_finish(true)
			return
		# The next one is decided the moment the last one falls, so a run never runs dry.
		_append_enemy(roster_rng)
	# What Cleave carried comes off the body before it is out; it never fells one.
	hp = maxf(1.0, health[index] - _overkill)
	_overkill = 0.0
	# Dominoes carries into a common, and into an elite or a boss only at IV, and then half.
	if EnemyRoster.tier_of(lineup[index]) != EnemyRoster.Tier.COMMON:
		_carried *= DOMINO_BIG if _peak("dominoes") else 0.0
	phase = Phase.WALKING_IN
	phase_left = walk_in
	enemy_coming.emit(index, lineup[index], hp)


## Dominoes' carry, dealt to the body that has just taken its stand. A body it fells falls then and
## there as a one-blow kill, and passes its own leftover on at the same share.
func _take_carried() -> void:
	if _carried <= 0.0 or finished:
		return
	hp -= _carried
	_carried = 0.0
	enemy_hit.emit(maxf(hp, 0.0))
	if hp <= 0.0:
		_crit_kill = false
		_domino = "domino" in effects
		_one_blow += 1
		_best("domino_streak", _one_blow)
		_kill()


func _finish(win: bool) -> void:
	finished = true
	victory = win
	phase = Phase.OVER
	if win:
		won.emit()
	else:
		lost.emit()


## One more of `key` in this fight's `tally`.
func _count(key: String, n := 1) -> void:
	tally[key] = int(tally.get(key, 0)) + n


## A streak's length, kept in `tally` only where it is the longest this fight has seen.
func _best(key: String, streak: int) -> void:
	tally[key] = maxi(int(tally.get(key, 0)), streak)
