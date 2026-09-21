class_name Curses
extends RefCounted
## The curses a player may take into a new world: up to `MOST`, chosen on the black screen of a
## transcension (`TranscendPage`), each a handicap on the whole world for a bonus on the whole world.
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
## `skulls` is how hard it is, for the player to read; nothing counts them.

const MOST := 3

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
		"text": "A mimic has three times the health.", "reward": "A beaten chest holds six pieces of gear, not four."},
	BLOODTHIRST: {"name": "Bloodthirst", "skulls": 2,
		"text": "Enemies hit 75% harder.", "reward": "+30% item rarity",
		"stats": {"item_rarity": 30.0}},
	LEAN_PICKINGS: {"name": "Lean Pickings", "skulls": 2,
		"text": "Gear drops half as often.", "reward": "One find in ten drops as a +1 piece, and one in a hundred as +2."},
	PAUPER: {"name": "Pauper", "skulls": 2,
		"text": "Every purse is halved.", "reward": "+40% experience",
		"stats": {"xp_more": 40.0}},
	WILD_TILES: {"name": "Wild Tiles", "skulls": 2,
		"text": "Tile modifiers start past the first wall, not the second, and every tile has one more.",
		"reward": "Every tile modifier pays 10% more."},
	THICK_FOG: {"name": "Thick Fog", "skulls": 2,
		"text": "-1 Sight. You begin with a Broken Torch, which gives it back while held.", "reward": "Unique items drop twice as often."},
	# A "less" on the finished experience, after every "more" has been added (`Encounter.LESSONS_XP`);
	# the doubling is `Inventory.skill_worth`, read by `stats()` and by the skill's card.
	HARD_LESSONS: {"name": "Hard Lessons", "skulls": 2,
		"text": "Enemies give 75% less experience.", "reward": "Every skill point is worth double."},
	LONG_WINTER: {"name": "Long Winter", "skulls": 3,
		"text": "The ice wall has twice the health.", "reward": "Every ice wall pays two super orbs, not one."},
}


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
