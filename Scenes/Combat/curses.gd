class_name Curses
extends RefCounted
## The curses a player may take into a new world: any whose skulls add up to no more than the player's
## `Inventory.skull_allowance` (Gollux's depths won), chosen on the black screen of a transcension (`TranscendPage`), each a
## handicap on the whole world for a bonus on the whole world.
## A table and nothing else -- `Inventory.curses` holds the ids, `Inventory.effects()` hands each to
## the fight as `"curse:<id>"` (`effect`), where it is one `if` like a worn unique's, and
## `Inventory.stats()` adds a row's `stats`, so what a curse pays in numbers is on the character page
## with everything else.
##
## **A row's two sentences are written to be understood, not to fit:** the table that shows them
## (`TranscendPage`) wraps and scrolls, and there will be more rows. Say the whole rule, with the number
## and what it is against ("two super orbs, not one").
##
## A curse takes from one side of the game and pays on another, so none of them nets to nothing.
## `skulls` is how hard it is, and what it costs of the budget (`fits`).

const IRON_FOES := "iron_foes"
const SHORT_DAYS := "short_days"
const NO_REST := "no_rest"
const HUNGRY_MIMICS := "hungry_mimics"
const BLOODTHIRST := "bloodthirst"
const LEAN_PICKINGS := "lean_pickings"
const PAUPER := "pauper"
const WILD_TILES := "wild_tiles"
const THICK_FOG := "thick_fog"
const LONG_WINTER := "long_winter"
const HARD_LESSONS := "hard_lessons"
const PACIFIST_HANDS := "pacifist_hands"
const BERSERKERS_WORLD := "berserkers_world"
const GLASS_WORLD := "glass_world"
const RAW_FINDS := "raw_finds"
const HOMELAND := "homeland"
const SPECIALIST := "specialist"
const RESTLESS := "restless"
const FORGOTTEN := "forgotten"
const RING_OF_WALLS := "ring_of_walls"
const LONE_HEIR := "lone_heir"
const NO_SECOND_CHANCES := "no_second_chances"

## What a fight is told beside `effect(HOMELAND)`: one entry a land that still leaves gear, as
## `"homeland:<env>"` (`Inventory.homeland`, chosen by the main scene as the world begins).
const HOME_PREFIX := "homeland:"

## `stats` is what `Inventory.stats()` adds while the curse is on; `xp_more` is read by `Encounter.arm`
## and by nothing else. What is not a number is written where it is done, and named in the row's text.
const CURSES := {
	IRON_FOES: {"name": "Iron Foes", "skulls": 1,
		"text": "Every enemy has 60% more health.", "reward": "+40% gold find",
		"stats": {"gold_find": 40.0}},
	SHORT_DAYS: {"name": "Short Days", "skulls": 1,
		"text": "Every fight has 8 seconds less on the clock.", "reward": "+20% drop rate",
		"stats": {"drop_rate": 20.0}},
	NO_REST: {"name": "No Rest", "skulls": 1,
		"text": "You cannot set up camp.", "reward": "+25% experience",
		"stats": {"xp_more": 25.0}},
	HUNGRY_MIMICS: {"name": "Hungry Mimics", "skulls": 1,
		"text": "A mimic has three times the health.", "reward": "A beaten chest holds six items, not four."},
	BLOODTHIRST: {"name": "Bloodthirst", "skulls": 2,
		"text": "Enemies hit 75% harder.", "reward": "+30% item rarity",
		"stats": {"item_rarity": 30.0}},
	LEAN_PICKINGS: {"name": "Lean Pickings", "skulls": 2,
		"text": "Gear drops half as often.", "reward": "One item in ten drops +1, and one in a hundred +2."},
	PAUPER: {"name": "Pauper", "skulls": 2,
		"text": "Enemies drop half as much gold.", "reward": "+40% experience",
		"stats": {"xp_more": 40.0}},
	WILD_TILES: {"name": "Wild Tiles", "skulls": 2,
		"text": "Tile modifiers start past the first wall, not the second, and every tile has one more.",
		"reward": "Every tile modifier pays 10% more."},
	THICK_FOG: {"name": "Thick Fog", "skulls": 2,
		"text": "-2 Sight. You begin with a Broken Torch, which gives one back while held.", "reward": "Unique items drop twice as often."},
	# A "less" on the finished experience, after every "more" has been added (`Encounter.LESSONS_XP`);
	# the doubling is `Inventory.skill_worth`, read by `stats()`.
	HARD_LESSONS: {"name": "Hard Lessons", "skulls": 2,
		"text": "Enemies give 75% less experience.", "reward": "Every skill point is worth double."},
	# Three uniques' rules made a whole world's. **Each adds to its unique where both are had** (the
	# user's ruling): the curse and the piece are two entries in the same sum.
	PACIFIST_HANDS: {"name": "Pacifist Hands", "skulls": 2, "not_with": [BERSERKERS_WORLD],
		"text": "Your clicks deal no damage.",
		"reward": "+1.5/s Attack Speed, and your weapon swings twice as fast on its own."},
	BERSERKERS_WORLD: {"name": "Berserker's World", "skulls": 2, "not_with": [PACIFIST_HANDS],
		"text": "Your weapon never swings on its own, and you cannot set up camp.",
		"reward": "Clicks deal double damage. A Berserker's Band adds to it."},
	GLASS_WORLD: {"name": "Glass World", "skulls": 2,
		"text": "Every fight clock runs a third faster.",
		"reward": "+100% damage in every fight that has a clock. The Glass Edge adds to it."},
	RAW_FINDS: {"name": "Raw Finds", "skulls": 2,
		"text": "Every item drops as a common, with no modifiers. Uniques are untouched.",
		"reward": "Orbs drop three times as often."},
	HOMELAND: {"name": "Homeland", "skulls": 2,
		"text": "Only two kinds of land leave gear: the kind you start on, and one other. Chests and the ice wall still pay.",
		"reward": "On those two, +80% item rarity, and uniques drop three times as often."},
	SPECIALIST: {"name": "Specialist", "skulls": 2,
		"text": "Only one branch of the skill tree may hold points.",
		"reward": "Every skill point is worth 50% more."},
	RESTLESS: {"name": "Restless", "skulls": 1,
		"text": "A camp is full after 2 hours, not 8.",
		"reward": "A camp pays double for every hour."},
	FORGOTTEN: {"name": "Forgotten", "skulls": 2,
		"text": "The collection log adds no damage in this world.",
		"reward": "Every unique first found in this world counts twice in the log, for good."},
	LONG_WINTER: {"name": "Long Winter", "skulls": 3,
		"text": "The ice wall has twice the health.", "reward": "Every ice wall pays two super orbs, not one."},
	RING_OF_WALLS: {"name": "Ring of Walls", "skulls": 3,
		"text": "An ice wall stands every 6 rings, not every 12.",
		"reward": "Every wall still pays its super orb, so there are twice as many to earn."},
	LONE_HEIR: {"name": "Lone Heir", "skulls": 3,
		"text": "Only one heirloom may be worn. The rest come off as the world begins.",
		"reward": "The heirloom you make at the end of this world is made +1."},
	NO_SECOND_CHANCES: {"name": "No Second Chances", "skulls": 3,
		"text": "Losing the fight for a tile ends the world at once, and a world lost that way leaves no heirloom.",
		"reward": "Every ice wall pays one more super orb."},
}


## Whether `id` may be taken beside what is already `taken`: a row's `not_with` names the ones it
## cannot stand with -- clicks that do nothing and a weapon that never swings is a world nobody can
## play.
static func allowed(id: String, taken: Array) -> bool:
	for other: String in CURSES[id].get("not_with", []):
		if other in taken:
			return false
	return true


## How many skulls `taken` costs, together.
static func skulls_of(taken: Array) -> int:
	var sum := 0
	for id: String in taken:
		sum += int(CURSES[id]["skulls"])
	return sum


## Whether `id` may be added to `taken` under `budget` skulls: it fits what is left, and stands with
## the rest (`allowed`).
static func fits(id: String, taken: Array, budget: int) -> bool:
	return skulls_of(taken) + int(CURSES[id]["skulls"]) <= budget and allowed(id, taken)


## What the fight is told for one, in `Encounter.effects`.
static func effect(id: String) -> String:
	return "curse:" + id


## The ids of `saved` this build still knows, in the table's order: names go on disk, and a retired
## one is dropped on load rather than guessed at.
static func known(saved: Array) -> Array[String]:
	var out: Array[String] = []
	for id: String in CURSES:
		if id in saved:
			out.append(id)
	return out
