class_name Encounter
extends RefCounted
## The rules of one fight, no nodes: enemies come out one at a time (run in, stand to be hit, die)
## against one clock. `CombatScene` draws it; a test plays one with `hit()` and `advance(delta)`.
## The rules that span functions are the folder's CLAUDE.md; a comment here marks where one bites.

## Running in, not yet in reach. `start()` announces the first.
signal enemy_coming(index: int, enemy_name: String, hp: float)
## Arrived, and can be hit.
signal enemy_spawned(index: int, enemy_name: String, hp: float)
signal enemy_hit(hp_left: float)
## What the player's blow did (`automatic`: the weapon swung it); `enemy_hit` is what the enemy has left.
signal hit_landed(amount: float, crit: bool, automatic: bool)
## Before the body's loot is rolled; `kill_paid` after all of it has gone out.
signal enemy_died(index: int)
signal kill_paid(index: int)
signal loot_dropped(index: int, item: Item)
signal gold_dropped(index: int, amount: float)
signal orb_dropped(index: int, orb: String)
signal rune_dropped(index: int, rune: String)
signal xp_dropped(index: int, amount: int)
## An enemy struck the clock for `taken` seconds, after armour and block: none where `dodged`, and none
## where `blocked`, block having taken the whole of what armour left.
signal player_hit(taken: float, dodged: bool, blocked: bool)
signal won()
signal lost()

const ENEMIES := 10
const ELITE_EVERY := 10
const SECONDS := 30.0
## The most seconds the gear's Fight Clock adds: beside Heartwood's own cap, not inside it.
const CLOCK_MOST := 8.0

## A fight's shape, by what the world put on the tile (`PROFILES`, keyed by `MapBuilder.area_variant`).
const ORDINARY := {"enemies": ENEMIES, "seconds": SECONDS, "elite_every": ELITE_EVERY, "boss_last": false}
const SETTLEMENT := {"enemies": 15, "seconds": 60.0, "elite_every": 5, "boss_last": true}
## A chest's tile (`MapBuilder.has_chest`): the mimic alone.
const CHEST := {"enemies": 1, "seconds": SECONDS, "elite_every": 1, "boss_last": true}
const MIMIC := "Mimic"
## A chest holds one unique and nothing else MIMIC_UNIQUE of the time, otherwise MIMIC_ROLLS certain pieces.
const MIMIC_UNIQUE := 0.5
const MIMIC_ROLLS := 4
## The most pieces one body leaves off its own chance. Without it a chance at
## `LootTable.chance_for`'s ceiling, which a boss reaches, would roll for ever.
const MOST_DROPS := 4
const WALL := {"enemies": 1, "seconds": 60.0, "elite_every": 1, "boss_last": true}
const WALL_NAME := "The Ice Wall"
## The first three walls' health over a boss body's: the dial for how hard a wall is.
const WALL_HP := 28.0
## What every wall already fallen multiplies the health behind it by: WALL_GROWTH for the next wall
## (`hp_of(.., WALL_GROWTH)`), LAND_GROWTH for the land's bodies (the user's, 2026-09-27). Why the land
## steps at all, and what the dials were tried at: DESIGN.md, "encounter.gd".
const WALL_GROWTH := 2.2
const LAND_GROWTH := 10.0
## From the fourth wall on (`walls_inside` of LATE_WALL_FROM) a wall is this many ordinary common bodies
## of the ring just inside it, and WALL_HP and WALL_GROWTH stop applying (the user's, 2026-10-09).
const LATE_WALL_BODIES := 150.0
const LATE_WALL_FROM := 3
## The dungeon: a block of fifteen floors that repeats for ever, Gollux on the last.
const DUNGEON := {"enemies": 15, "seconds": 60.0, "elite_every": 5, "boss_last": true}
## Where its creatures live (`EnemyRoster`) and what is drawn behind them: no land on the map.
const DUNGEON_ENV := "cave"
## A floor's health over the one above it: nine times a depth, slower than the walls' sixteen (the
## user's, 2026-10-03).
const DUNGEON_GROWTH := 1.1578
## What the first Gollux's health is rounded to (`gollux_hp`).
const GOLLUX_ROUND := 500000.0
## A floor's health by its tier, and nothing of the roster's sizes. Gollux is his depth's wall (`gollux_hp`).
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
## An ordinary body's health beside the start: ten are a minute of steady clicking with nothing on.
const BASE_HP := 7
## What one hex step out from the middle multiplies it by.
const HP_GROWTH := 1.18
## Base health set by hand for a circle of land, by the walls inside it: an ordinary body on its first
## ring, the rest scaling with it (`hp_tuning`). The user's (2026-09-28): 10k where the formula gave 26.7k.
const CIRCLE_HP := {2: 10000.0}

## A purse is `(BASE_GOLD + GOLD_PER_STEP * steps) * GOLD_GROWTH ^ steps` (`gold_at_steps`). GOLD_GROWTH
## is set near `LootTable.LEVEL_GROWTH`, not HP_GROWTH: a purse keeps pace with the gear that kills for
## it. Every price in town is quoted off this curve (`TownPrices`), so moving it moves them all.
const BASE_GOLD := 1.0
const GOLD_PER_STEP := 1.0
const GOLD_GROWTH := 1.12

## Experience of an ordinary body per level of its tile. Linear in the banded `MapBuilder.level_of` on
## purpose: the bands widen, so an exponent per hex step would compound with the square of the level
## and soon pay a whole level a body. `PlayerLevel.xp_to_next` paces it.
const XP_PER_LEVEL := 1.0

## What a click does with nothing equipped: the floor under `damage`.
const BARE_DAMAGE := 1
## Seconds an enemy spends running in, before it can be hit.
const WALK_IN := 0.6

## Seconds between a standing enemy's blows at the clock. The first comes a whole interval after it
## arrives, so a body killed quickly never lands one.
const ATTACK_EVERY := {
	EnemyRoster.Tier.COMMON: 1.0,
	EnemyRoster.Tier.ELITE: 2.0,
	EnemyRoster.Tier.BOSS: 4.0,
}
## A blow's size against a common's. Matched to ATTACK_EVERY, so every tier costs bare skin the same
## seconds a second and what differs is the shape: armour is a share, block a flat amount.
const HIT_TIER := {
	EnemyRoster.Tier.COMMON: 1.0,
	EnemyRoster.Tier.ELITE: 2.0,
	EnemyRoster.Tier.BOSS: 4.0,
}
## Seconds a common's blow takes off the clock at the very middle (`hit_of`).
const HIT_SECONDS := 0.25
## What a blow grows by a ring, and by a wall behind the cell. Slower than health on purpose: armour
## is a share, and cannot keep up with a blow that grows as health does (the user's, 2026-09-28).
const HIT_GROWTH := 1.1
const HIT_WALL_GROWTH := 1.5
## A rating's share of any blow is `rating / (rating + K)` (`_share`): K is half, nothing is the whole.
const ARMOUR_K := 50.0
const DODGE_K := 50.0
## The most `elite_ward`, `tile_ward` and `less_health` each come to: a "less" that reached the whole
## would be no blow, no modifier and no body.
const WARD_MOST := 75.0
## Seconds a recoup takes to come back, and a burn to burn out. Both are written in their lines' text
## (`ModifierTable.MODS`): change them together.
const RECOUP_SECONDS := 4.0
const BURN_SECONDS := 3.0
## Seconds a death plays out, before the next enemy comes on.
const DEATH := 0.5

## The uniques' and capstones' numbers that no rank moves. A ranked one is the unique's own row
## (`UniqueTable`, read through `_dial`), so a card's sentence and the fight agree.
const GLASS_MORE := 1.0          ## the Glass World's; the Glass Edge's is its rank's
const GLASS_CLOCK := 4.0 / 3.0   ## how fast the Glass Edge spends the clock
const GAMBLE_LEAST := 0.01       ## the Gambler's Die's worst blow; its best is its rank's
const LAST_GASP_MORE := 2.0
const MOMENTUM_MORE := 0.02      ## per kill
const MOMENTUM_MOST := 1.0
const HEARTWOOD_ARMOUR := 50.0   ## armour a second on the clock
const AFTERIMAGE_SECONDS := 1.0  ## the most a dodge wins back, of what blows have taken
const SECOND_WIND_SECONDS := 5.0 ## given back once a fight, as the clock runs out
const EXECUTE_SHARE := 0.1       ## of its health a blow must leave a body under, Execute; the Headsman's adds
const GIANT_SLAYER_TIMES := 2.0  ## a blow at an elite or a boss, Giant Slayer
const SHIELD_WALL_TIMES := 2.0   ## block against an elite's or a boss's blow, Shield Wall
const JACKPOT_CHANCE := 0.1      ## of purses that are JACKPOT_TIMES as full, Jackpot
const JACKPOT_TIMES := 5.0
const TWO_ORBS_CHANCE := 0.25    ## of orbs that fall as two, the Alchemist's `transmute`
const MAGPIE_CHANCE := 0.05
## The lines a unique gains at rank IV (`UniqueTable`'s `peak` says each in words).
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
## The world's curses. `Curses` writes its sentences' figures from these: never type one in twice.
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

## What the current enemy is doing. Hits only land while it is WAITING.
enum Phase { WALKING_IN, WAITING, DYING, OVER }

## The fight's shape (`_take_profile`). `enemies` and `seconds` mean nothing while `endless`.
var enemies := ENEMIES
var seconds := SECONDS
var elite_every := ELITE_EVERY
var boss_last := false
## The enemies in the order they come out, and the health each starts with (always as long). Whole
## numbers in doubles, as `hp` and `gold` are: exponential in the walk, they passed int64 a few hundred
## hexes out.
var lineup: PackedStringArray = []
var health: PackedFloat64Array = []
var cell := Vector2i.ZERO
var env := ""             ## the terrain: it picks the enemies and the backdrop
var endless := false      ## a farm run: no count and no clock. False in the dungeon
var dungeon := false
var first_floor := 0      ## the floor the dungeon's first body stands on, from 0; nought in any other fight

var index := 0            ## which enemy is out, from 0: how many are slain
var hp := 0.0             ## the current enemy's
var phase := Phase.WALKING_IN
var phase_left := WALK_IN ## seconds left of the walking-in or dying under way
var time_left := SECONDS  ## seconds on the clock; untouched while `endless`
var finished := false     ## for a loss as well as a win
var victory := false

## What this fight has earned: sums, and orb name -> how many.
var gold := 0.0
var xp := 0
var orbs := {}

## Unseeded on purpose (a RandomNumberGenerator seeds itself): these belong to the attempt, not to the
## tile. Tests seed them. One a roll, so a rate tuned apart from another cannot shift it by drawing
## more or fewer numbers off a shared stream.
var loot_rng := RandomNumberGenerator.new()
var orb_rng := RandomNumberGenerator.new()
var unique_rng := RandomNumberGenerator.new()
var stone_rng := RandomNumberGenerator.new()
var roster_rng := RandomNumberGenerator.new()
var elite_rng := RandomNumberGenerator.new()
var crit_rng := RandomNumberGenerator.new()
var gamble_rng := RandomNumberGenerator.new()

## What the player is worth (`Inventory.stats()`, gear and skills together), read by `arm`. Percents
## unless said.
var damage: float = BARE_DAMAGE  ## what a blow takes off a body, before everything that multiplies it
const CRIT_CAP := 100.0
const BEGINNERS_LUCK := 25.0  ## the crit chance Beginner's Luck sets, whatever the gear says
var crit_chance := 0.0
var crit_damage := 0.0    ## what a crit adds, not what it multiplies to: 50 is half again
## The most swings a second, after everything that multiplies them (the user's dial, 2026-10-03).
const SWING_CAP := 10.0
var attack_speed := 0.0   ## swings a second the weapon takes on its own
var bleed := 0.0          ## a mace's: of a blow, lost again every second the body stands (`_bleed`)
## The broad finder; **added** to `gold_find` and `orb_find` where it meets them.
var drop_rate := 0.0
var item_rarity := 0.0
var gold_find := 0.0
var orb_find := 0.0
## The weapon's lines (`gear_more`).
var click_damage := 0.0
var swing_damage := 0.0
var elite_damage := 0.0
var first_blow := 0.0
var double_strike := 0.0  ## the chance a blow lands twice
var elite_chance := 0.0   ## how often a common comes on as an elite instead (`_promote`)
## The helmet's, the body's and the offhand's lines.
var blow_delay := 0.0     ## how much later an enemy's first blow comes
var elite_ward := 0.0     ## less of an elite's or a boss's blow
var tile_ward := 0.0      ## less of a tile modifier's bite
var less_health := 0.0    ## less health on every body
var camp_more := 0.0      ## what a camp pays more (`Camp.make`)
var extra_enemies := 0    ## a count: bodies more or fewer in a tile fight
var thorns := 0.0         ## of `damage`, struck back at a blow that lands
var recoup := 0.0         ## of what a blow took, coming back over RECOUP_SECONDS
var parry := 0.0          ## crit chance a dodge hands the next blow
var burn := 0.0           ## of a blow, burning on over BURN_SECONDS
var time_on_block := 0.0  ## seconds a blow the block stops whole wins back
## What keeps a blow off the clock (`taken`): two ratings, then seconds off each blow, then seconds a
## landed hit wins back.
var armor := 0.0
var dodge := 0.0
var block := 0.0
var time_on_hit := 0.0
var xp_more := 0.0        ## the gear's, the tile's and the world's, added
var spawn_speed := 0.0    ## the share of the walk-in the gear takes off, 0-100
var walk_in := WALK_IN    ## seconds an enemy of this fight spends running in
## What only a unique asks about, and the fight cannot see for itself (`Inventory.stats()` puts them in).
var _bare_sockets := 0
var _bag_pieces := 0
var _strength := 0.0
var _dexterity := 0.0
var _attribute_lines := 0
var _pure_pieces := 0     ## pieces worn with no attribute line

## What the main scene tells a fight as it opens it. Every default is the fight as it was before the
## thing existed, so one built by hand (the tests, the screenshot scripts) plays and drops as it did.

## What changes how the fight plays rather than a number, by effect id (`Inventory.effects()`): learned
## capstones, worn uniques (one entry a piece, so two of one ring are two) and the world's curses.
var effects: Array = []
## Unique id -> the player's rank of it, 1..`UniqueTable.PEAK`; one not named is at rank I.
var ranks := {}
var strikes := false      ## whether the enemies strike the clock at all
## The finds a new player's first kills are scripted to leave (the user's, 2026-10-10) -> the lifetime
## kills each falls between: after the first and by the second, the last one certain (`_due`).
const SWORD := "sword"
const TRANSMUTE := "transmute"
const AUGMENT := "augment"
const UNIQUE := "unique"
const NODE := "node"
const PROMISED := {SWORD: [0, 10], TRANSMUTE: [10, 20], AUGMENT: [20, 30], UNIQUE: [100, 120], NODE: [150, 170]}
## The orb that spends each orb promise.
const ORB_PROMISES := {OrbTable.FIRST_ORB: TRANSMUTE, OrbTable.SECOND_ORB: AUGMENT}
## The promises still owed (`Inventory.promised`), and the player's lifetime kills as the fight opened.
var promised: Array = []
var kills_before := 0
var orbs_after := 0       ## kills this fight makes before an orb can drop
## The deepest wall ever broken: which orbs can drop (`OrbTable.unlocked`).
var walls_down := OrbTable.EVERY_WALL
const NO_UNIQUES := -1
var uniques_after := NO_UNIQUES  ## kills this fight makes before a unique can fall; NO_UNIQUES: never
var unlocked: Array = []  ## the only uniques a body can carry (`Achievements.unlocked`)
## Whether a body can leave a skill node. On once the first sword has dropped: a stone before it would
## spend that promise (`FightLedger.add_loot`).
var stone_drops := false
var runes_drop := false   ## whether a body in the dungeon may carry a rune
## Dev (`Settings.even_loot`): one find off every body but a chest at this chance, every rarity alike.
const EVEN_LOOT_CHANCE := 1.0 / 3.0
var even_loot := false
## `TileMods` ids, one listed twice being its second tier; a run's runes' modifiers ride with the tile's.
var mods: Array = []
## A farm run's Depth runes still working: each a level on what drops and on a body's experience
## (`_level`), and `MapBuilder.LEVEL_TILES` rings further out for its health and purse.
var deeper := 0
var ascended := false     ## the Ascent rune: a find may fall ascended, as Lean Pickings' do (`_lean`)

## Set by nothing in the game: for the tests and the screenshot scripts. Every body leaves a piece
## (LootTable's `guaranteed`, so what falls is rolled the ordinary way), an orb, an elite a certain piece.
var always_drop := false
var always_orb := false
var guarantee_elite := false

## What this fight did, for the achievements: counts (`_count`) and the best of each streak (`_best`).
var tally := {}
var _dry := 0             ## blows since a crit, of those that could have crit
var _one_blow := 0        ## kills in a row by a first blow or by Dominoes' carry

## The Knucklebone Ring's streak: clicks made within KNUCKLE_WINDOW of the one before. A click counts
## whether or not it lands, or every walk-in would break it.
const KNUCKLE_WINDOW := 1.0
var _click_streak := 0
var _since_click := 0.0
## The hand's allowance (`click`; the user's dials, 2026-10-03): it fills at CLICK_CAP a second on the
## fight's own time and holds CLICK_BURST. Not a least gap between clicks, which would halve a steady
## sixteen a second to eight.
const CLICK_CAP := 15.0
const CLICK_BURST := 3.0
var _clicks_left := CLICK_BURST

## Done once each, however often `wear` and `arm` run: `_take_curses`, `_take_dread`, `_shape`.
var _cursed := false
var _dreaded := false
var _promoted := false
var _base_elite_every := 0  ## the elite pace before any modifier set it, which `forget_mod` goes back to
## What the tile and the world add to every body's health, to every blow and to how often one comes,
## as shares: **one sum each**, so a Thick-skinned tile under Iron Foes is +110% and not +140%.
var _hp_more := 0.0
var _hit_more := 0.0
var _attack_more := 0.0
var _clock_more := 0.0    ## the seconds `arm` last added to the clock for the gear
## Seconds the enemies' blows have taken off the clock and nothing has yet won back (`_win_back`).
var wounds := 0.0
var _recouping: Array = []  ## what the blows are still owed back: one [seconds left, a second] a blow
var _saves_used := 0      ## Second Winds and Worry Stones spent
var _swing := 0.0         ## how much of the next automatic swing has been earned
var _parry := 0.0         ## crit chance a dodge handed the next blow
var _serpent := 0.0       ## the Serpent's Eye's built crit chance; kept across bodies
var _hand_blows := 0      ## clicks that have landed, for the Berserker's Band at IV

## About the body that is out; cleared as the next comes on (`_advance_phase`).
var _attack := 0.0        ## how far it is towards its next blow
var _blows := 0           ## how many blows it has taken
var _crit_kill := false   ## whether the last blow was a crit: once it is down, whether a crit felled it
var _walled := false      ## its first blow has been blocked (Heartwood Plate at IV)
var _bled_out := false    ## it died of its wound (Butcher's Cleaver at IV)
var _bleed := 0.0         ## damage a second from the deepest wound it has taken, never a sum of them
var _burn := 0.0          ## damage a second from the deepest burn, lit again by every blow
var _burn_left := 0.0     ## and the seconds that has left
## What its death hands the next body (`_kill`).
var _domino := false      ## it fell to its first blow
var _carried := 0.0       ## Dominoes' share of what that blow had left over
var _overkill := 0.0      ## what Cleave carries
var _executed := 0.0      ## the health a rank IV Headsman's execution took


static func profile_for(variant: String) -> Dictionary:
	return PROFILES.get(variant, ORDINARY)


## The fight waiting on `cell`, seeded from it. A chest's is the mimic alone, and carries no modifiers.
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


## The ice wall alone, fought on the ice whatever land lies under it.
static func for_wall(cell: Vector2i) -> Encounter:
	var fight := Encounter.new()
	fight.env = "ice"
	fight.cell = cell
	fight._take_profile(WALL)
	fight.lineup.append(WALL_NAME)
	fight.health.append(fight._health_of(WALL_NAME))
	fight.hp = fight.health[0]
	return fight


## The dungeon, begun at the top of the depth under the `won` the player already has, with a whole
## clock. The descent goes on past its Gollux into the depth after, on what is left of it.
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
## nearest GOLLUX_ROUND and never under it (the user's, 2026-10-03).
static func gollux_hp() -> float:
	var second_wall := MapBuilder.START_LAND_RADIUS + 1 + MapBuilder.WALL_STEP
	var wall := for_wall(MapBuilder.CENTER + Vector2i(second_wall, 0)).hp
	return maxf(GOLLUX_ROUND, snappedf(wall, GOLLUX_ROUND))


## The depth the player is in, from 1. It moves only as a Gollux, the last floor of his depth, goes down.
func depth() -> int:
	return (first_floor + index) / enemies + 1


## How many depths this descent has won.
func cleared() -> int:
	return depth() - 1 - first_floor / enemies


## A farm run: the tile's elite rhythm and never its boss. `deeper` is the Depth runes on the tile.
static func farm(cell: Vector2i, env: String, variant := "", mods: Array = [], deeper := 0) -> Encounter:
	var fight := Encounter.new()
	fight.env = env
	fight.cell = cell
	fight.endless = true
	# Before the first body, whose health it lifts.
	fight.deeper = deeper
	fight.elite_every = int(profile_for(variant)["elite_every"])
	fight._take_mods(TileMods.farmable(mods))
	fight._append_enemy(fight.roster_rng)
	fight.hp = fight.health[0]
	return fight


func _take_profile(profile: Dictionary) -> void:
	enemies = int(profile["enemies"])
	seconds = float(profile["seconds"])
	elite_every = int(profile["elite_every"])
	boss_last = bool(profile["boss_last"])
	time_left = seconds


## The tile's say over the shape of its fight: after the profile, before the lineup is rolled. Its say
## over the player's numbers, and its pay, wait for `arm`.
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


## The health `enemy` starts this fight with: `_raw_health_of` less the helmet's `less_health`, which
## is on every body, the wall's and the dungeon's too. `position` is its place in the lineup; with
## none, as a body joins, it is the end.
func _health_of(enemy: String, position := -1) -> float:
	return maxf(1.0, roundf(_raw_health_of(enemy, position) * (1.0 - less_health / 100.0)))


## Before the gear has a say: `hp_of`, more for whatever the tile and the world add. The dungeon
## answers to its floor and tier alone, and the ice wall to WALL_HP and the Long Winter alone.
func _raw_health_of(enemy: String, position := -1) -> float:
	if dungeon:
		var floor_at := first_floor + (health.size() if position < 0 else position)
		if EnemyRoster.tier_of(enemy) == EnemyRoster.Tier.BOSS:
			# Gollux: the first is `gollux_hp`, and each after it a depth's growth on.
			return roundf(gollux_hp() * pow(DUNGEON_GROWTH, floor_at - (enemies - 1)))
		return maxf(1.0, roundf(BASE_HP * pow(DUNGEON_GROWTH, floor_at)
				* float(DUNGEON_TIER_HP[EnemyRoster.tier_of(enemy)])))
	if enemy == WALL_NAME:
		# No growth term of its own: `hp_of` at WALL_GROWTH already steps for every wall inside this one.
		var walls := walls_inside(cell)
		var wall_hp := hp_of(enemy, cell, WALL_GROWTH) * WALL_HP
		if walls >= LATE_WALL_FROM:
			var inside := MapBuilder.CENTER + Vector2i(HexGrid.distance(MapBuilder.CENTER, cell) - 1, 0)
			wall_hp = base_hp(inside) * hp_tuning(walls) * LATE_WALL_BODIES
		return roundf(wall_hp * (LONG_WINTER_HP if _cursed_with(Curses.LONG_WINTER) else 1.0))
	var more := 1.0 + _hp_more - _softened("hp")
	if enemy == MIMIC and _cursed_with(Curses.HUNGRY_MIMICS):
		more += HUNGRY_HP
	return maxf(1.0, roundf(hp_of(enemy, cell) * more * pow(HP_GROWTH, MapBuilder.LEVEL_TILES * deeper)))


## Sizes the bodies from `from` on again, the one standing there with them. Call it only where
## something moved health, so a fight built by hand keeps the health it was given.
func _size_again(from: int) -> void:
	for at in range(from, lineup.size()):
		health[at] = _health_of(lineup[at], at)
	if from < lineup.size():
		hp = health[from]


## The level of what drops here and what a body's experience is counted at.
func _level() -> int:
	return MapBuilder.level_of(cell) + deeper


## A rune's modifier has worn off mid-run (`RuneTable.count_kill`): one listing of `id` -- a tier --
## leaves, and what it shaped is shaped again from the next body on. What it paid goes at the next
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
		elite_every = int(TileMods.value(id, "elite_every", mods.count(id))) if id in mods \
				else _base_elite_every


## What the world's curses do to the shape of the fight, once: `wear` hands them over after the lineup
## was rolled, so under one that moves health the bodies are sized again.
func _take_curses() -> void:
	if _cursed:
		return
	_cursed = true
	if _cursed_with(Curses.IRON_FOES):
		_hp_more += IRON_HP
	if _cursed_with(Curses.BLOODTHIRST):
		_hit_more += BLOODTHIRST_HIT
	if _cursed_with(Curses.SHORT_DAYS) and not endless:
		seconds = maxf(1.0, seconds - SHORT_DAYS)
		time_left = seconds
	if [Curses.IRON_FOES, Curses.HUNGRY_MIMICS, Curses.LONG_WINTER].any(_cursed_with):
		_size_again(0)


## The tier that belongs at `position`, which a run may not have filled yet (the HUD's pips). The
## dungeon counts in floors and its block comes round for ever: Gollux on the last of every depth.
func tier_for(position: int) -> EnemyRoster.Tier:
	var at := (first_floor + position) if dungeon else position
	var last := (at % enemies == enemies - 1) if dungeon else (boss_last and position == enemies - 1)
	if last:
		return EnemyRoster.Tier.BOSS
	return EnemyRoster.Tier.ELITE if at % elite_every == elite_every - 1 else EnemyRoster.Tier.COMMON


## What the player is wearing and has learned, and the rank of each unique: before `arm`, which reads
## some of it. Setting `effects` by hand does everything but take the curses on.
func wear(worn: Array, unique_ranks := {}) -> void:
	effects = worn
	ranks = unique_ranks
	_take_dread()
	_take_curses()


## The Dreadmask, once: its rank's number of commons fewer, less one for every ice wall inside the tile.
func _take_dread() -> void:
	if _dreaded or endless or dungeon or not "dread" in effects:
		return
	_dreaded = true
	_thin(int(_dial("dreadmask", "fewer")) - walls_inside(cell), 0)


## Takes up to `fewer` commons off the lineup from `from` on, and never the last body left there.
func _thin(fewer: int, from: int) -> void:
	var at := from
	while fewer > 0 and at < lineup.size() and lineup.size() - from > 1:
		if EnemyRoster.tier_of(lineup[at]) == EnemyRoster.Tier.COMMON:
			lineup.remove_at(at)
			health.remove_at(at)
			fewer -= 1
		else:
			at += 1
	enemies = lineup.size()
	hp = health[from]


## One of a worn unique's numbers at the rank this fight was told.
func _dial(id: String, key: String) -> float:
	return UniqueTable.dial(id, key, int(ranks.get(id, 1)))


## Whether the player has `id` at rank IV, where it gains its last line (`UniqueTable.peak_text`).
## Asked beside whether it is worn, never instead of it.
func _peak(id: String) -> bool:
	return int(ranks.get(id, 1)) >= UniqueTable.PEAK


## Whether this fight is on a home piece's own ground with that piece worn at rank IV.
func _home_peak() -> bool:
	return ("home:" + env) in effects and _peak(UniqueTable.home_piece(env))


## The tier of whatever stands at `at`: the roster's where that enemy has been rolled, the position's
## for the far end of a run's lineup.
static func tier_in(fight: Encounter, at: int) -> EnemyRoster.Tier:
	if at < fight.lineup.size():
		return EnemyRoster.tier_of(fight.lineup[at])
	return fight.tier_for(at)


func _append_enemy(rng: RandomNumberGenerator) -> void:
	var tier := tier_for(lineup.size())
	var picked := EnemyRoster.pick(env, tier, rng)
	if picked.is_empty():
		# Only on terrain that is not real: test_enemies holds one of every tier for every environment.
		push_error("No tier %d enemy lives on %s" % [tier, env])
		picked = EnemyRoster.names()[0]
	lineup.append(picked)
	health.append(_health_of(picked))
	_promote(lineup.size() - 1)


## Elite Chance: the common at `at` comes on as an elite of its ground instead, sized as one. Never in
## the dungeon, whose floors are counted, and with no chance nothing is drawn. Returns whether it did.
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


## Announces the first enemy, so whoever is drawing the fight can put it on the field.
func start() -> void:
	enemy_coming.emit(index, lineup[index], hp)


## What one enemy is worth on this tile: `base_hp` times its own size and tier
## (`EnemyRoster.hp_modifier`) and its circle's tuning, which the ice wall, with WALL_HP, never takes.
static func hp_of(enemy_name: String, cell: Vector2i, step := LAND_GROWTH) -> float:
	var tuned := 1.0 if enemy_name == WALL_NAME else hp_tuning(walls_inside(cell))
	return maxf(1.0, roundf(base_hp(cell, step) * EnemyRoster.hp_modifier(enemy_name) * tuned))


## What this circle's bodies are multiplied by: its base health (the dev balancing page's number, else
## `baseline_hp`) over the formula's own (`circle_base_hp`).
static func hp_tuning(walls: int) -> float:
	var wanted := Settings.hp_base(walls)
	if wanted <= 0.0:
		wanted = baseline_hp(walls)
	return wanted / circle_base_hp(walls)


## The base health a circle has with nothing set on the balancing page.
static func baseline_hp(walls: int) -> float:
	return float(CIRCLE_HP.get(walls, circle_base_hp(walls)))


## The formula's health for an ordinary body on the first ring of the circle with `walls` walls
## inside it: the middle tile inside the first wall, the ring past the wall's own after that.
static func circle_base_hp(walls: int) -> float:
	var ring := 0 if walls == 0 else MapBuilder.START_LAND_RADIUS + 2 + (walls - 1) * MapBuilder.WALL_STEP
	return base_hp(MapBuilder.CENTER + Vector2i(ring, 0))


## The health of an ordinary common body on this tile: the smooth walk out from the middle, and `step`
## for every wall already behind the cell -- LAND_GROWTH for a body, WALL_GROWTH for a wall.
static func base_hp(cell: Vector2i, step := LAND_GROWTH) -> float:
	return maxf(1.0, roundf(BASE_HP * pow(HP_GROWTH, HexGrid.distance(MapBuilder.CENTER, cell))
			* pow(step, walls_inside(cell))))


## How many walls stand between the middle of the map and `cell`. A wall's own ring counts none of
## itself: ceiling rather than floor, which agrees with the floor on a wall ring (12 -> 0, 24 -> 1,
## 36 -> 2) and steps up on the first ring past one.
static func walls_inside(cell: Vector2i) -> int:
	return maxi(0, ceili(float(HexGrid.distance(MapBuilder.CENTER, cell)
			- MapBuilder.START_LAND_RADIUS - 1) / float(MapBuilder.WALL_STEP)))


## What an ordinary common body on this tile is carrying. Off the smooth distance and not the banded
## `MapBuilder.level_of`: two tiles at opposite ends of one level band are not worth the same.
static func base_gold(cell: Vector2i) -> float:
	return gold_at_steps(HexGrid.distance(MapBuilder.CENTER, cell))


## The same purse asked of a walk, so a price can be quoted with no cell to point at (`TownPrices`).
static func gold_at_steps(steps: int) -> float:
	var walked := maxi(steps, 0)
	return maxf(1.0, roundf((BASE_GOLD + GOLD_PER_STEP * walked) * pow(GOLD_GROWTH, walked)))


## What one enemy is carrying: the tile's purse times the `hp_modifier` its health is built from. No
## player in it -- the finders are added in `_drop_purse` -- because a town's prices are quoted off it.
static func gold_of(enemy_name: String, cell: Vector2i) -> float:
	return maxf(1.0, roundf(base_gold(cell) * EnemyRoster.hp_modifier(enemy_name)))


static func base_xp(cell: Vector2i) -> int:
	return maxi(1, roundi(XP_PER_LEVEL * MapBuilder.level_of(cell)))


static func xp_of(enemy_name: String, cell: Vector2i) -> int:
	return maxi(1, roundi(base_xp(cell) * EnemyRoster.hp_modifier(enemy_name)))


## The name of the enemy that is out, or "" once the fight is over.
func enemy_name() -> String:
	return "" if index >= lineup.size() else lineup[index]


func _tier() -> EnemyRoster.Tier:
	return EnemyRoster.tier_of(lineup[index])


## What the nameplate calls the ground a boss holds, by environment.
const TITLE_GROUND := {
	"desert": "Dunes", "dirt": "Barrens", "forest": "Deepwood",
	"grass": "Meadows", "ice": "Frost", "mountains": "Peaks", DUNGEON_ENV: "Deep",
}
const BOSS_TITLES: Array[String] = ["Scourge", "Terror", "Warden", "Bane", "Tyrant"]
const ELITE_TITLES: Array[String] = [
	"Savage", "Ancient", "Grim", "Rabid", "Hulking", "Vicious", "Dread", "Feral",
]


## A word in front of an elite's name ("Savage"), a line under a boss's ("Scourge of the Dunes"),
## nothing for a common. Seeded from the cell and the slot, and for show only: a bounty counts
## `enemy_name()`.
func enemy_title() -> String:
	if index >= lineup.size():
		return ""
	var pick := hash(["title", cell, first_floor + index])
	match _tier():
		EnemyRoster.Tier.ELITE:
			return ELITE_TITLES[pick % ELITE_TITLES.size()]
		EnemyRoster.Tier.BOSS:
			return "%s of the %s" % [BOSS_TITLES[pick % BOSS_TITLES.size()],
					TITLE_GROUND.get(env, "Wilds")]
	return ""


func enemy_max_hp() -> float:
	return 0.0 if index >= lineup.size() else health[index]


func on_elite() -> bool:
	return index < lineup.size() and _tier() == EnemyRoster.Tier.ELITE


## Enemies still to beat, the one out now included. Meaningless while `endless`.
func remaining() -> int:
	return enemies - index


func kills() -> int:
	return index


## A click: one blow at the enemy out, unless the hand is stilled. It is counted, and towards a
## Knucklebone streak, whether or not it lands. Returns whether it landed.
func hit() -> bool:
	var landed := false if _hand_stilled() else _strike(false)
	if "knucklebone" in effects:
		_click_streak += 1
	_count("clicks")
	_since_click = 0.0
	return landed


## The Metronome's price, and Pacifist Hands': the player's own hand does nothing.
func _hand_stilled() -> bool:
	return "metronome" in effects or _cursed_with(Curses.PACIFIST_HANDS)


## A click from the player's hand: `hit()`, unless the hand has outrun its allowance, where it is no
## click at all -- no blow, no streak, no count. Only the scene calls it.
func click() -> bool:
	if _clicks_left < 1.0:
		return false
	_clicks_left -= 1.0
	return hit()


## The stats `arm` reads straight onto the field of the same name -> the most each may be; none is ever
## under nought. Through `set`, so there is no `armor = ` to find: a new plain stat is a row here.
const ARM_STATS := {
	"armor": INF, "dodge": INF, "attack_speed": INF, "bleed": INF, "drop_rate": INF, "item_rarity": INF,
	"gold_find": INF, "orb_find": INF, "click_damage": INF, "swing_damage": INF, "elite_damage": INF,
	"first_blow": INF, "blow_delay": INF, "thorns": INF, "parry": INF, "burn": INF, "xp_more": INF,
	"elite_ward": WARD_MOST, "tile_ward": WARD_MOST, "less_health": WARD_MOST,
	"recoup": 100.0, "double_strike": 100.0, "elite_chance": 100.0, "spawn_speed": 100.0,
}
## And the ones kept in tenths on the gear (`LootTable.SECONDS_STATS`), where the fight wants seconds.
const ARM_SECONDS: Array[String] = ["block", "time_on_hit", "time_on_block"]


## What the player's gear and skills are worth, from `Inventory.stats()`. It may run again mid-fight
## (the gear changed in the bag), so everything here starts from `stats`, never from what the last
## `arm` left. A fight nobody arms is a bare-handed one.
func arm(stats: Dictionary) -> void:
	for key: String in ARM_STATS:
		assert(key in self, "ARM_STATS names no field: " + key)
		set(key, clampf(float(stats.get(key, 0.0)), 0.0, float(ARM_STATS[key])))
	for key: String in ARM_SECONDS:
		assert(key in self, "ARM_SECONDS names no field: " + key)
		set(key, maxf(0.0, LootTable.seconds_of(key, float(stats.get(key, 0.0)))))
	damage = maxf(BARE_DAMAGE, roundf(float(stats.get("damage", 0.0))) + BARE_DAMAGE)
	# Clamped: a chance is not a quantity, and eight pieces can total more than certainty.
	var raw_crit := BEGINNERS_LUCK if "beginners_luck" in effects else float(stats.get("crit_chance", 0.0))
	crit_chance = clampf(raw_crit, 0.0, CRIT_CAP)
	crit_damage = float(stats.get("crit_damage", 0.0))
	# The Overflowing Chalice: what the clamp above throws away is kept as crit damage.
	if "overcrit" in effects:
		crit_damage += maxf(0.0, raw_crit - CRIT_CAP) * _dial("overflowing_chalice", "times")
	camp_more = maxf(0.0, float(stats.get("camp_earnings", 0.0)))
	extra_enemies = roundi(float(stats.get("extra_enemies", 0.0)))
	_bare_sockets = maxi(0, int(stats.get("bare_sockets", 0)))
	_bag_pieces = maxi(0, int(stats.get("bag_pieces", 0)))
	_strength = maxf(0.0, float(stats.get("strength", 0.0)))
	_dexterity = maxf(0.0, float(stats.get("dexterity", 0.0)))
	_attribute_lines = maxi(0, int(stats.get("attribute_lines", 0)))
	_pure_pieces = maxi(0, int(stats.get("pure_pieces", 0)))
	# The gear's seconds on the clock, none of them on a run: Heartwood Plate's (armour buys clock, to
	# its rank's most, or a clock that grew with armour would be no clock), the Fight Clock's, and what
	# `tile_ward` gives back of a Dusk. Moved by the difference, so arming again never refills the clock.
	var more := 0.0
	if not endless:
		if "heartwood" in effects:
			more += minf(floorf(armor / HEARTWOOD_ARMOUR), _dial("heartwood_plate", "most"))
		more += clampf(LootTable.seconds_of("fight_clock", float(stats.get("fight_clock", 0.0))), 0.0, CLOCK_MOST)
		more -= TileMods.total(mods, "seconds") * tile_ward / 100.0
	seconds += more - _clock_more
	time_left += more - _clock_more
	_clock_more = more
	# A run's later bodies are asked as they join (`_append_enemy`).
	if not _promoted:
		_promoted = true
		_shape()
	# Meadowstriders at IV.
	if env == "grass" and _home_peak():
		xp_more += HOME_XP
	# The tile's own say, last: what it takes off the player's numbers, and what it pays -- added to
	# the finders like any other percent, so the drops have no second path.
	armor *= _tile_factor("armor")
	dodge *= _tile_factor("dodge")
	block *= _tile_factor("block")
	time_on_hit *= _tile_factor("time_on_hit")
	attack_speed = minf(attack_speed * _tile_factor("swing"), SWING_CAP)
	walk_in = WALK_IN * _tile_factor("walk_in") * (1.0 - spawn_speed / 100.0)
	if phase == Phase.WALKING_IN:
		phase_left = minf(phase_left, walk_in)
	if _cursed_with(Curses.HOMELAND) and _at_home():
		item_rarity += HOME_RARITY
	var wild := _cursed_with(Curses.WILD_TILES)
	drop_rate += TileMods.paid(TileMods.total(mods, "drop_rate"), wild)
	item_rarity += TileMods.paid(TileMods.total(mods, "item_rarity"), wild)
	gold_find += TileMods.paid(TileMods.total(mods, "gold_find"), wild)
	xp_more += TileMods.paid(TileMods.total(mods, "xp"), wild)


## What the gear does to the lineup already rolled, once, as the fight is first armed: bodies more or
## fewer, health sized again only where the gear moved it, then the elite chance.
func _shape() -> void:
	_take_extra()
	if _softened("hp") > 0.0 or less_health > 0.0:
		_size_again(index)
	for at in range(index, lineup.size()):
		if _promote(at) and at == index:
			hp = health[at]


## The body armour's count: commons put on the front of what is left, from the cell's own draw so a
## tile fields the same ones each time, or taken off it. A tile's fight only: a run has no count, the
## dungeon's floors are counted, and a wall or a chest is one body.
func _take_extra() -> void:
	if extra_enemies == 0 or endless or dungeon or index >= lineup.size() \
			or lineup[index] in [WALL_NAME, MIMIC]:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["extra", cell])
	for i in extra_enemies:
		var picked := EnemyRoster.pick(env, EnemyRoster.Tier.COMMON, rng)
		if picked.is_empty():
			break
		lineup.insert(index, picked)
		health.insert(index, _health_of(picked, index))
	_thin(-extra_enemies, index)


## A tile modifier's factor on one of the player's numbers, less the share of its bite `tile_ward`
## takes back: half the armour under a Piercing tile at 50% is three quarters.
func _tile_factor(key: String) -> float:
	return 1.0 + (TileMods.factor(mods, key) - 1.0) * (1.0 - tile_ward / 100.0)


## What `tile_ward` takes back of an added lift the tile put on (`hp`, `hit`, `attack`). Asked where
## the lift is used, so a modifier that leaves the fight (`forget_mod`) takes its share of this with it.
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


## Whether the weapon swings on its own at all: the one answer to it.
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
	var step := loot_rng.randi_range(ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNIQUE)
	if step == ItemRarity.Rarity.UNIQUE:
		var found := _roll_unique(unlocked, true)
		if found != null:
			return found
		step = ItemRarity.Rarity.ELITE
	return LootTable.roll(lineup[index], loot_rng, true, _level(), 0.0, 0.0, step)


## The drop rate a gear roll is handed: the player's, or half the finished chance under Lean Pickings.
func _gear_rate() -> float:
	return _lifted(drop_rate, LEAN_LESS) if _cursed_with(Curses.LEAN_PICKINGS) else drop_rate


func _roll_gear(certain: bool) -> Item:
	return LootTable.roll(lineup[index], loot_rng, certain, _level(), _gear_rate(), item_rarity)


## A unique out of `pool`. A `certain` one draws no chance, so `rate` is nothing to it.
func _roll_unique(pool: Array, certain: bool, rate := 0.0) -> Item:
	return UniqueTable.roll(lineup[index], pool, unique_rng, _level(), rate, certain, item_rarity)


## Lean Pickings' other half, and the Ascent rune's whole: a find that falls may fall already ascended.
## Drawn only under the curse or on an ascended tile, so nobody else's loot stream moves.
func _lean(item: Item) -> Item:
	if item == null or not (_cursed_with(Curses.LEAN_PICKINGS) or ascended):
		return item
	var roll := loot_rng.randf()
	var plus := 2 if roll < LEAN_PLUS[1] else 1 if roll < LEAN_PLUS[0] + LEAN_PLUS[1] else 0
	for i in plus:
		item.ascend()
	return item


## One blow, from a click or from the weapon swinging itself. Nothing while an enemy is running in or
## dying, or once the fight is over; returns whether it landed. `riposte` is the Bulwark's answer to a
## blow block stopped whole, at its rank's share of a swing. `average_blow` is this averaged: change
## what a blow deals here and change it there.
func _strike(automatic: bool, riposte := false) -> bool:
	if finished or phase != Phase.WAITING:
		return false
	# Beginner's Luck sets the chance outright: the Serpent's Eye and a dodge have nothing to build on.
	var chance := crit_chance if "beginners_luck" in effects \
			else minf(crit_chance + _serpent + _parry, CRIT_CAP)
	_parry = 0.0
	var crit := chance > 0.0 and crit_rng.randf() * 100.0 < chance
	var first := _blows == 0
	_blows += 1
	var big := _tier() != EnemyRoster.Tier.COMMON
	# The Duelist's Buckler: the first blows an enemy takes are crits, whoever swung them. The Bulwark
	# at IV: its answer is always one.
	var opening := "opening_strike" in effects and _blows <= _dial("duelists_buckler", "blows")
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
	# The Duelist's Buckler at IV adds crit damage twice with an opening blow on an elite or a boss.
	var crit_more := crit_damage * (2.0 if opening and big and _peak("duelists_buckler") else 1.0)
	var dealt := maxf(1.0, roundf(damage * (1.0 + crit_more / 100.0))) if crit else damage
	if "giant_slayer" in effects and big:
		dealt *= GIANT_SLAYER_TIMES
	# The two sums, each applied once: the gear's just before the uniques', never inside it.
	dealt *= 1.0 + gear_more(automatic, big, first)
	dealt = maxf(1.0, roundf(dealt * (1.0 + unique_more(automatic))))
	if riposte:
		dealt = maxf(1.0, roundf(dealt * _dial("bulwark", "share") / 100.0))
	# Two blows' worth: every tenth click that lands under the Berserker's Band at IV, one crit in ten
	# under the Overflowing Chalice at IV, and Double Strike. The last two are drawn only where there is
	# a chance, so no one else's crits move.
	if not automatic and "berserk" in effects and _peak("berserkers_band"):
		_hand_blows += 1
		if _hand_blows % BERSERK_EVERY == 0:
			dealt *= 2.0
	if crit and "overcrit" in effects and _peak("overflowing_chalice") and crit_rng.randf() < CHALICE_TWICE:
		dealt *= 2.0
	if double_strike > 0.0 and crit_rng.randf() * 100.0 < double_strike:
		dealt *= 2.0
	# The Gambler's Die is a different blow every time, not more damage, so it stands outside the sums.
	# At IV the first blow on each enemy is drawn twice and the better kept.
	if "gamble" in effects:
		var top := _dial("gamblers_die", "top")
		var worth := gamble_rng.randf_range(GAMBLE_LEAST, top)
		if first and _peak("gamblers_die"):
			worth = maxf(worth, gamble_rng.randf_range(GAMBLE_LEAST, top))
		dealt = maxf(1.0, roundf(dealt * worth))
	hp -= dealt
	# Execute takes what is left once it is a sliver; the Ogre's Knuckle at IV makes strength Execute too.
	var finish := EXECUTE_SHARE if "execute" in effects else 0.0
	if "headsman" in effects:
		finish += _dial("headsman", "share") / 100.0
	if "ogre" in effects and _peak("ogres_knuckle"):
		finish += minf(_strength / OGRE_EXECUTE_STRENGTH, OGRE_EXECUTE_MOST) / 100.0
	if hp > 0 and hp < enemy_max_hp() * finish:
		if "headsman" in effects and _peak("headsman"):
			_executed = hp
		hp = 0.0
	hit_landed.emit(dealt, crit, automatic)
	enemy_hit.emit(hp)
	if hp <= 0:
		_domino = first and "domino" in effects
		if crit:
			_count("crit_kills")
		_one_blow = _one_blow + 1 if first else 0
		_best("domino_streak", _one_blow)
		_kill(automatic)
	else:
		# Only where the body survived, and the deeper wound wins and nothing adds: or a weapon
		# swinging twice as fast would bleed twice as hard for free. The burn likewise.
		_bleed = maxf(_bleed, dealt * bleed / 100.0)
		if burn > 0.0:
			_burn = maxf(_burn, dealt * burn / 100.0 / BURN_SECONDS)
			_burn_left = BURN_SECONDS
	if not endless:
		_win_back(time_on_hit)
	return true


## `_strike` averaged, against a common body as the fight starts: its crits, `gear_more` and
## `unique_more`, Double Strike, the Band's tenth click and the Chalice's doubled crit at IV, and the
## Gambler's Die's mean -- but no streak built, no kill made, no clock run low, and nothing of Giant
## Slayer, Elite Damage or First Blow Damage. `automatic` is the weapon's swing; a click is the hand's.
func average_blow(automatic: bool) -> float:
	if not automatic and _hand_stilled():
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
## bleed and the burn that leaves. Nothing where it does not swing at all.
func per_second() -> float:
	return average_blow(true) * (attack_speed + bleed / 100.0 + burn / 100.0 / BURN_SECONDS) \
			if swings() else 0.0


## What the weapon's lines add to a blow, as a share. `big`: at an elite or a boss. `first`: the first
## blow a body takes. **One sum**, beside `unique_more` and never inside it.
func gear_more(automatic: bool, big: bool, first: bool) -> float:
	var more := swing_damage if automatic else click_damage
	if big:
		more += elite_damage
	if first:
		more += first_blow
	return more / 100.0


## What the worn uniques, and the curses that are a unique's rule, add to a blow, as a share: 2.0 is
## three times the damage. **One sum**: a new damage unique adds a line here, never a multiplier of
## its own.
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
		var points := _dexterity if automatic else _strength
		if _peak("brawlers_wraps"):
			points = _strength + _dexterity
		more += _dial("brawlers_wraps", "more") / 100.0 * points * effects.count("brawler")
	return more


## The enemy that is out goes down: the one path to a death, apart from `_strike` because a wound and
## Dominoes' carry kill with no blow. `swung`: the weapon's own swing felled it, which the Metronome at
## IV answers with the next swing ready the moment the next body stands.
func _kill(swung := false) -> void:
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
	if not dungeon:
		_pay()
	# The dungeon pays nothing, from anything -- an Hourglass second down here would be a clock that
	# never ran out -- but a rune, once the third wall has opened them.
	elif runes_drop:
		var rune := RuneTable.roll(lineup[index], loot_rng)
		if not rune.is_empty():
			rune_dropped.emit(index, rune)
	kill_paid.emit(index)


## Everything a body on the land leaves. Keep its steps in this order: it is the order their
## generators are drawn in and their signals go out. Nothing is rolled when the clock runs out, which
## is why drops survive a loss for free.
func _pay() -> void:
	var mimic := lineup[index] == MIMIC
	var big := _tier() != EnemyRoster.Tier.COMMON
	var boss := _tier() == EnemyRoster.Tier.BOSS
	# A chest holds a unique or its certain gear, never both. The unique ignores the kill count uniques
	# otherwise wait for; a ground with no pool falls back to the gear.
	var chest_unique: Item = null
	if mimic and loot_rng.randf() < MIMIC_UNIQUE:
		chest_unique = _roll_unique(unlocked, true)
	# No ordinary gear at all: under the Tithe (at IV an elite's and a boss's still fall), on a Gilded
	# tile, and on the Homeland's other four lands -- but never a chest or the wall, which are no land's.
	var abroad := _cursed_with(Curses.HOMELAND) and not _at_home() and not mimic \
			and lineup[index] != WALL_NAME
	var tithe := "tithe" in effects and not (big and _peak("the_tithe"))
	var no_gear := tithe or "gilded" in mods or abroad
	_drop_gear(mimic, big, no_gear or chest_unique != null)
	_drop_purse(no_gear)
	# Hard Lessons is a "less": what is left once every "more" has been added. A Depth rune's level
	# counts the way the tile's own does: experience is so much a level.
	var lessons := LESSONS_XP if _cursed_with(Curses.HARD_LESSONS) else 1.0
	var worth := maxi(1, roundi(xp_of(lineup[index], cell) * float(_level()) / MapBuilder.level_of(cell)
			* (1.0 + xp_more / 100.0) * lessons))
	xp += worth
	xp_dropped.emit(index, worth)
	_drop_unique(mimic, boss, chest_unique)
	# The Hourglass: its rank's seconds back for anything but a boss -- and at IV a boss's own -- and
	# never past what the fight began with, so the clock can be held but not banked. A run has none.
	if "hourglass" in effects and not endless:
		if not boss:
			time_left = minf(seconds, time_left + _dial("hourglass_amulet", "seconds"))
		elif _peak("hourglass_amulet"):
			time_left = minf(seconds, time_left + HOURGLASS_BOSS)
	_drop_orb()
	_drop_stone()


## The body's gear: one roll, a chest's certain several, or `none`.
func _drop_gear(mimic: bool, big: bool, none: bool) -> void:
	var rolls := 1
	if mimic:
		rolls = HUNGRY_ROLLS if _cursed_with(Curses.HUNGRY_MIMICS) else MIMIC_ROLLS
	if none:
		rolls = 0
	if even_loot and not mimic:
		rolls = 0
		if loot_rng.randf() < EVEN_LOOT_CHANCE:
			loot_dropped.emit(index, _even_find())
	# The Broken Sword's kill, asked whatever `rolls` came to: a certain piece, which the swap below
	# makes the sword.
	var sword := _due(SWORD, loot_rng)
	for roll in rolls:
		# Certain: the sword, Trophy Hunter's big bodies, a forest elite under the Hunter's Lantern at IV.
		var certain: bool = always_drop or mimic or (roll == 0
				and (sword or (guarantee_elite and on_elite()) or (big and "trophy" in effects)
				or (on_elite() and env == "forest" and _home_peak())))
		var dropped := _roll_gear(certain)
		# Lucky Wound: a body felled by a crit rolls its rank's number of times and leaves the best.
		if _crit_kill and "lucky_wound" in effects:
			for again in int(_dial("lucky_wound", "rolls")) - 1:
				dropped = _better(dropped, _roll_gear(certain))
		var found := 0
		while dropped != null:
			if SWORD in promised:
				# While the sword is owed any gear that falls is it, common and level 1.
				promised.erase(SWORD)
				dropped = Item.rolled(LootTable.FIRST_DROP, ItemRarity.Rarity.COMMON, loot_rng)
			else:
				dropped = _lean(_raw(dropped))
			loot_dropped.emit(index, dropped)
			found += 1
			# A find that beat the chance rolls again, never certain, up to MOST_DROPS. A certain roll
			# does not, because it beat nothing: the promise is one piece.
			dropped = null if certain or found >= MOST_DROPS else _roll_gear(false)


## The purse every body carries. Drop rate is **added** to gold find, the way two global percents add:
## 20 and 30 are half again as much gold, not 56% more.
func _drop_purse(no_gear: bool) -> void:
	var purse := maxf(1.0, roundf(gold_of(lineup[index], cell)
			* (1.0 + (gold_find + drop_rate) / 100.0) * pow(GOLD_GROWTH, MapBuilder.LEVEL_TILES * deeper)))
	# Two Tithes add (at rank I five times, not nine), the way two global modifiers do.
	purse *= 1.0 + (_dial("the_tithe", "times") - 1.0) * effects.count("tithe")
	# The Sunscorched Cowl at IV.
	if env == "desert" and _home_peak():
		purse *= HOME_PURSE
	# Drawn only while Jackpot is learned, so a player without it rolls loot exactly as before.
	if "jackpot" in effects and loot_rng.randf() < JACKPOT_CHANCE:
		purse *= JACKPOT_TIMES
	# The Magpie's Band: now and then the purse is a piece of gear instead -- but never where no
	# ordinary gear falls, and there the purse stays a purse.
	if "magpie" in effects and not no_gear and loot_rng.randf() < MAGPIE_CHANCE:
		purse = 0.0
		loot_dropped.emit(index, _lean(_raw(_roll_gear(true))))
	if purse > 0.0 and _cursed_with(Curses.PAUPER):
		purse = maxf(1.0, roundf(purse * PAUPER_PURSE))
	if "barren" in mods:
		purse = 0.0
	if purse > 0.0:
		gold += purse
		gold_dropped.emit(index, purse)


## A unique, beside the gear and not from its table. A chest's is its toss and nothing on top; then
## the promised first; then, past `uniques_after`, the chance.
func _drop_unique(mimic: bool, boss: bool, chest_unique: Item) -> void:
	if chest_unique != null:
		loot_dropped.emit(index, _lean(chest_unique))
	elif mimic or even_loot:
		return
	elif _due(UNIQUE, unique_rng):
		promised.erase(UNIQUE)
		loot_dropped.emit(index, _lean(_roll_unique([UniqueTable.FIRST_UNIQUE], true)))
	elif uniques_after != NO_UNIQUES and index >= uniques_after:
		# Thick Fog's pay, and the Homeland's on its own two lands: factors on the finished chance.
		var lucky := (FOG_UNIQUES if _cursed_with(Curses.THICK_FOG) else 1.0) \
				* (HOME_UNIQUES if _cursed_with(Curses.HOMELAND) and _at_home() else 1.0)
		var rate := _lifted(drop_rate, lucky)
		var found := _roll_unique(unlocked, false, rate)
		# A second chance, never a second unique: a boss in the mountains under Stonebreaker at IV, and
		# a crit kill under the Lucky Wound at IV.
		if found == null and ((boss and env == "mountains" and _home_peak())
				or (_crit_kill and "lucky_wound" in effects and _peak("lucky_wound"))):
			found = _roll_unique(unlocked, false, rate)
		if found != null:
			# Luck got there first: the promise is a first unique, and this is one.
			promised.erase(UNIQUE)
			loot_dropped.emit(index, _lean(found))


## An orb, beside the gear rather than instead of it: the two promised ones first, then, past
## `orbs_after`, the chance. Drop rate is added to orb find, and `OrbTable.chance_for` handed the sum.
func _drop_orb() -> void:
	var orb := ""
	if _due(TRANSMUTE, orb_rng):
		orb = OrbTable.FIRST_ORB
	elif _due(AUGMENT, orb_rng):
		orb = OrbTable.SECOND_ORB
	elif always_orb or index >= orbs_after:
		# Raw Finds, and the Gravedigger's Charm at IV on dirt: factors on the finished chance.
		var lucky := (RAW_ORBS if _cursed_with(Curses.RAW_FINDS) else 1.0) \
				* (HOME_ORBS if env == "dirt" and _home_peak() else 1.0)
		orb = OrbTable.roll(lineup[index], orb_rng, always_orb, _lifted(orb_find + drop_rate, lucky),
				walls_down)
	if orb.is_empty():
		return
	# Either promise is spent by its orb, however that came.
	promised.erase(ORB_PROMISES.get(orb))
	var count := 2 if "transmute" in effects and orb_rng.randf() < TWO_ORBS_CHANCE else 1
	for i in count:
		orbs[orb] = int(orbs.get(orb, 0)) + 1
		orb_dropped.emit(index, orb)


## A skill node. Not gear, so nothing that keeps gear from falling keeps it. None falls before the
## promised first, which is no roll at all.
func _drop_stone() -> void:
	if _due(NODE, stone_rng):
		promised.erase(NODE)
		loot_dropped.emit(index, SkillTree.first(lineup[index], stone_rng, _level()))
	elif stone_drops and NODE not in promised:
		var stone := SkillTree.roll(lineup[index], stone_rng, _level(), drop_rate, item_rarity)
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


## The better of two finds, either of which may be null: the higher rarity, then the higher level.
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
		# What the blows took coming back, before the clock runs: paid after it, a share still owed
		# left a sliver on a clock that had run out, every frame, and the fight could not be lost.
		if not _recouping.is_empty():
			_recoup(delta)
		# The Glass Edge's price, and the Glass World's: each is a third faster, and both are both.
		var spent := delta * pow(GLASS_CLOCK, _glass())
		# Rimeplate at IV: on ice the clock runs slower.
		if env == "ice" and _home_peak():
			spent *= HOME_CLOCK
		# Past nothing for the rest of this step, so whatever is won back inside it pays the whole of
		# what ran first; the verdict at the foot is what stops it at nothing.
		time_left -= spent
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
	_wear_down(_bleed, delta, true)
	if _burn_left > 0.0:
		var burning := minf(delta, _burn_left)
		_burn_left -= burning
		_wear_down(_burn, burning)
	if endless or finished or time_left > 0.0:
		return
	time_left = 0.0
	# Second Wind and the Worry Stone: once a fight each, the two adding up, the clock gets back
	# SECOND_WIND_SECONDS rather than running out -- but none is spent where the last body is already
	# going down, which wins the fight (`_end`).
	if not _winning() and _saves_used < effects.count("second_wind") + effects.count("worry_stone"):
		_saves_used += 1
		time_left = SECOND_WIND_SECONDS
	else:
		# A descent is not lost, only over: the floor it reached is the whole of it.
		_end(dungeon)


## The one path for damage nobody dealt, at `a_second` a second: a wound (`bleeding`), a burn, thorns,
## the Spiked Helm. Only while the body is standing, and a death this way was nobody's blow, so no
## crit, no unique's more and no Dominoes come of it.
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


## The enemy standing there striking the clock, once every `_attack_every()`. Never the ice wall,
## which is a check on damage and nothing else.
func _be_struck(delta: float) -> void:
	if not strikes or endless or dungeon or finished or phase != Phase.WAITING or delta <= 0.0 \
			or lineup[index] == WALL_NAME:
		return
	# Last Gasp at IV: in its last seconds the enemies hold their blows.
	if "last_gasp" in effects and _peak("last_gasp") and time_left <= _dial("last_gasp", "seconds"):
		return
	var every := _attack_every()
	_attack += delta
	while _attack >= every and phase == Phase.WAITING and not finished:
		_attack -= every
		# A Savage tile and the Bloodthirst make each blow bigger, less what `tile_ward` takes back.
		_struck_by(hit_of(lineup[index], cell) * (1.0 + _hit_more - _softened("hit")))


## Its tier's ATTACK_EVERY, sooner on a Frenzied tile, less what `tile_ward` takes back.
func _attack_every() -> float:
	return ATTACK_EVERY[_tier()] / (1.0 + _attack_more - _softened("attack"))


## One blow at the clock: dodged whole, or cut by armour and then block and taken off `time_left`.
## Apart from `_be_struck` so a test can land one blow of a size it chose.
func _struck_by(hit: float) -> void:
	# The Heartwood Plate at IV: every enemy's first blow is blocked whole, before any dodge is rolled
	# -- a block like any other, so the Bulwark answers it and it is counted.
	var walled := not _walled and "heartwood" in effects and _peak("heartwood_plate")
	if walled:
		_walled = true
	# Drawn for every blow that gets this far, on the crits' generator and whatever the chance: unlike
	# a crit or a Double Strike, a dodge nobody has still moves the stream.
	elif crit_rng.randf() < dodge_chance():
		if "afterimage" in effects:
			_win_back(AFTERIMAGE_SECONDS)
		# The buckler's line: the best of what dodges handed the next blow.
		_parry = maxf(_parry, parry)
		player_hit.emit(0.0, true, false)
		_spikes_back()
		return
	var big := index < lineup.size() and _tier() != EnemyRoster.Tier.COMMON
	var stops := block * (SHIELD_WALL_TIMES if big and "shieldwall" in effects else 1.0)
	var lost := 0.0 if walled else taken(hit, stops)
	if big:
		lost *= 1.0 - elite_ward / 100.0
	# Only what the clock still had to lose is a wound: a blow on a clock that has run out takes
	# nothing, so there is nothing of it to win back, and no defence can bank time.
	var off := clampf(time_left, 0.0, lost)
	time_left -= off
	wounds += off
	if off > 0.0 and recoup > 0.0:
		var owed := off * recoup / 100.0
		_recouping.append([owed, owed / RECOUP_SECONDS])
	_count("blows_taken")
	if lost <= 0.0:
		_count("blocked")
	player_hit.emit(lost, false, lost <= 0.0)
	# Bulwark: a blow block stops entirely is answered at once, by the weapon's own swing at its share.
	if lost <= 0.0 and "riposte" in effects:
		_strike(true, true)
	if lost <= 0.0:
		_win_back(time_on_block)
		_spikes_back()
	# Thorns answer a blow that landed, blocked or not.
	if thorns > 0.0:
		_wear_down(damage * thorns / 100.0, 1.0)


## `most` seconds back on the clock out of what the blows took (`wounds`), never more, so nothing is
## banked. Everything that wins clock back goes through here.
func _win_back(most: float) -> void:
	var back := minf(most, wounds)
	if back <= 0.0:
		return
	wounds -= back
	time_left += back


## What the blows are owed back by `recoup`, a second's share of each at a time.
func _recoup(delta: float) -> void:
	for owed: Array in _recouping:
		var give := minf(float(owed[0]), float(owed[1]) * delta)
		owed[0] = float(owed[0]) - give
		_win_back(give)
	_recouping = _recouping.filter(func(owed: Array) -> bool: return float(owed[0]) > 0.0)


## The Spiked Helm at IV: a blow dodged or blocked whole sends a share of the armour back into the body.
func _spikes_back() -> void:
	if "spikes" in effects and _peak("spiked_helm"):
		_wear_down(armor * SPIKES_BACK, 1.0)


## What a blow of `hit` seconds takes off the clock once it lands: armour takes its share, then block
## (or `blocked` in its place) takes its seconds off what is left. 100 seconds against 90% armour and
## 10 block is nothing.
func taken(hit: float, blocked := -1.0) -> float:
	var kept := hit * (1.0 - _share(armor, ARMOUR_K))
	return maxf(0.0, kept - (block if blocked < 0.0 else blocked))


## The chance, 0 to 1, that the player steps out of a blow altogether. The Ascetic's Cord at IV adds a
## little a bare place, never lifting it past DODGE_MOST.
func dodge_chance() -> float:
	var chance := _share(dodge, DODGE_K)
	if "ascetic" in effects and _peak("ascetics_cord"):
		chance = minf(chance + ASCETIC_DODGE * _bare_sockets, maxf(chance, DODGE_MOST))
	return chance


static func _share(rating: float, k: float) -> float:
	if rating <= 0.0:
		return 0.0
	return rating / (rating + k)


## Seconds one blow from this enemy is worth on this tile, before the player's defence. The tile's and
## its tier's alone: a slime and a giant of one tier take the same off the clock.
static func hit_of(enemy_name: String, cell: Vector2i) -> float:
	return HIT_SECONDS * pow(HIT_GROWTH, HexGrid.distance(MapBuilder.CENTER, cell)) \
			* pow(HIT_WALL_GROWTH, walls_inside(cell)) * float(HIT_TIER[EnemyRoster.tier_of(enemy_name)])


## The weapon swinging on its own, earning only while an enemy stands to be hit: nothing banks through
## a walk-in or a death.
func _swing_weapon(delta: float) -> void:
	if not swings() or finished or phase != Phase.WAITING:
		return
	_swing += delta * attack_speed
	while _swing >= 1.0 and phase == Phase.WAITING and not finished:
		_swing -= 1.0
		_strike(true)


## Ends the fight at once, however much of it is left. For tests and for leaving early.
func give_up() -> void:
	_end(false)


## Ends a run on the player's say-so. Not a loss: a run cannot be lost.
func stop() -> void:
	_end(true)


## Ends the fight where it stands, for the clock running out, `stop` and `give_up`. A body already
## going down fell before the end came, so it is counted whatever the frame rate, and where it was the
## last of a tile's the fight is won. Counted here and not by `_advance_phase`, which would announce
## the next enemy, and draw one on a run's generator, as the fight ends.
func _end(win: bool) -> void:
	if finished:
		return
	win = win or _winning()
	if phase == Phase.DYING:
		index += 1
	_finish(win)


## Whether the body going down is the last of a tile's fight, whose death wins it.
func _winning() -> bool:
	return phase == Phase.DYING and not endless and not dungeon and index + 1 >= lineup.size()


## The walking-in or dying that just ran out: the enemy either takes its stand or leaves the field.
func _advance_phase() -> void:
	if phase == Phase.WALKING_IN:
		phase = Phase.WAITING
		# The helmet's `blow_delay`: the first blow waits its share of an interval longer.
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
		_append_enemy(roster_rng)
	# What Cleave carried comes off the body before it is out; it never fells one.
	hp = maxf(1.0, health[index] - _overkill)
	_overkill = 0.0
	# Dominoes carries into a common, and into an elite or a boss only at IV, and then half.
	if _tier() != EnemyRoster.Tier.COMMON:
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
	# A step may have run the clock under nothing before the last death played out (`advance`).
	time_left = maxf(time_left, 0.0)
	if win:
		won.emit()
	else:
		lost.emit()


func _count(key: String, n := 1) -> void:
	tally[key] = int(tally.get(key, 0)) + n


## A streak's length, kept in `tally` only where it is the longest this fight has seen.
func _best(key: String, streak: int) -> void:
	tally[key] = maxi(int(tally.get(key, 0)), streak)
