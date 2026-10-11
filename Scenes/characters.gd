class_name Characters
## The heroes a player can be: the kobold everyone starts as, and the ones bought on `RosterPage`. A table
## and nothing else: it names no other class, so `Inventory`, `CombatActor` and `PlayerToken` all name it.
##
## A row is the hero's shown `name`, the `frame` its sheets are cut into and `feet`, the column of a frame
## the middle of its feet stands in (the user's own marks, 2026-10-11): what a map token is stood by.
## `stand` is the box a hero is scaled and stood by where that is not simply what its idle draws: a spear
## or a banner held up is not its height, and one that floats is stood by the ground under it.
## A hero's files are `ROOT/<id>/<file>.png`, each frame the whole crop (`tools/characters.py` cuts them and
## prints the rows) -- but the kobold's, whose art is where it always was: his row names each file, and
## `bounds`, the crop of his wide frames.
##
## **An id is what a save holds: never rename one.**

const FIRST := "kobold"
const ROOT := "res://Assets/Characters/"
## A hero's sheets, by the name a fight plays each under.
const ANIMATIONS: Array[String] = ["idle", "walk", "attack"]
const ROSTER := {
	"kobold": {"name": "Kobold", "frame": Vector2i(148, 96), "feet": 61, "bounds": Rect2i(1, 29, 115, 62),
		"idle": "res://Assets/Player/idle.png", "walk": "res://Assets/Player/run.png",
		"attack": "res://Assets/Player/attack.png", "portrait": "res://Assets/NPC/player.png",
		"face": "res://Assets/UI/ui_char_portrait.png"},
	"knight_1": {"name": "Knight", "frame": Vector2i(64, 46), "feet": 31},
	"knight_2": {"name": "Mace Knight", "frame": Vector2i(85, 58), "feet": 30},
	"knight_3": {"name": "Lancer", "frame": Vector2i(87, 78), "feet": 29, "stand": Rect2i(6, 33, 45, 44)},
	"samurai": {"name": "Samurai", "frame": Vector2i(121, 71), "feet": 35},
	"samurai_archer": {"name": "Samurai Archer", "frame": Vector2i(122, 105), "feet": 60,
		"stand": Rect2i(28, 34, 47, 70)},
	"samurai_commander": {"name": "Samurai Commander", "frame": Vector2i(109, 95), "feet": 51,
		"stand": Rect2i(18, 25, 56, 69)},
	"man_1": {"name": "Swordsman", "frame": Vector2i(98, 78), "feet": 32},
	"man_2": {"name": "Ronin", "frame": Vector2i(106, 84), "feet": 55},
	"man_3": {"name": "Spearman", "frame": Vector2i(119, 86), "feet": 51},
	"karasu_tengu": {"name": "Karasu Tengu", "frame": Vector2i(123, 91), "feet": 63},
	"kitsune": {"name": "Kitsune", "frame": Vector2i(90, 86), "feet": 46},
	"yamabushi_tengu": {"name": "Yamabushi Tengu", "frame": Vector2i(123, 97), "feet": 56},
	"orc_warrior_brown": {"name": "Brown Orc", "frame": Vector2i(108, 83), "feet": 43},
	"orc_warrior_green": {"name": "Green Orc", "frame": Vector2i(108, 83), "feet": 53},
	"orc_woman": {"name": "Orc Huntress", "frame": Vector2i(91, 87), "feet": 40},
	"satyr_1": {"name": "Faun", "frame": Vector2i(60, 79), "feet": 29},
	"satyr_2": {"name": "Satyr Shaman", "frame": Vector2i(104, 93), "feet": 44, "stand": Rect2i(18, 21, 48, 71)},
	"satyr_3": {"name": "Satyr", "frame": Vector2i(59, 80), "feet": 30},
	"skeleton_1": {"name": "Skeleton Archer", "frame": Vector2i(60, 45), "feet": 19},
	"skeleton_2": {"name": "Skeleton Warrior", "frame": Vector2i(78, 46), "feet": 35},
	"skeleton_3": {"name": "Skeleton Spearman", "frame": Vector2i(80, 66), "feet": 29,
		"stand": Rect2i(9, 25, 35, 40)},
	"black_werewolf": {"name": "Black Werewolf", "frame": Vector2i(124, 91), "feet": 71},
	"red_werewolf": {"name": "Red Werewolf", "frame": Vector2i(124, 91), "feet": 63},
	"white_werewolf": {"name": "White Werewolf", "frame": Vector2i(124, 91), "feet": 61},
	"demon_1": {"name": "Evil Eye", "frame": Vector2i(56, 74), "feet": 24, "stand": Rect2i(6, 1, 44, 72)},
	"demon_2": {"name": "Demon", "frame": Vector2i(104, 89), "feet": 37},
	"demon_3": {"name": "Imp", "frame": Vector2i(75, 60), "feet": 36},
	"huge_mushroom": {"name": "Huge Mushroom", "frame": Vector2i(74, 65), "feet": 27},
	"goblin_king": {"name": "Goblin King", "frame": Vector2i(68, 60), "feet": 27},
	"vampire_bat": {"name": "Vampire Bat", "frame": Vector2i(66, 58), "feet": 26},
	"mega_boss": {"name": "Hell Knight", "frame": Vector2i(187, 126), "feet": 58,
		"stand": Rect2i(21, 21, 115, 104)},
}


static func ids() -> Array:
	return ROSTER.keys()


static func has(id: String) -> bool:
	return ROSTER.has(id)


static func name_of(id: String) -> String:
	return ROSTER[id]["name"]


static func frame(id: String) -> Vector2i:
	return ROSTER[id]["frame"]


## The part of a frame every animation of the hero is drawn from.
static func bounds(id: String) -> Rect2i:
	return ROSTER[id].get("bounds", Rect2i(Vector2i.ZERO, frame(id)))


static func feet(id: String) -> int:
	return ROSTER[id]["feet"]


## The row's own standing box, or an empty one where it is whatever the idle draws.
static func stand(id: String) -> Rect2i:
	return ROSTER[id].get("stand", Rect2i())


## `file` is an animation's name, "portrait" (`DialogueBox`'s strip), "face" (the corner panel's) or
## "badge" (`MapPointer`'s).
static func path(id: String, file: String) -> String:
	return ROSTER[id].get(file, "%s%s/%s.png" % [ROOT, id, file])
