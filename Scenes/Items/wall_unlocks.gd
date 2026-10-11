class_name WallUnlocks
extends RefCounted
## What breaking each ice wall opens for good (the user's ladder, 2026-10-09). Every unlock is read
## off the deepest wall ever broken, in any world (`Inventory.walls_ever`), so a transcension takes
## none back. Walls 1 and 2 are the orbs', two each (`OrbTable.unlocked`), and are not in `WALL`.

const GOLLUX := "gollux"
const RUNES := "runes"
const DISTANT := "distant"
const FILTER := "filter"
const ABILITIES := "abilities"

## The wall that opens each.
const WALL := {GOLLUX: 3, RUNES: 3, DISTANT: 4, FILTER: 6, ABILITIES: 7}
## The walls short of `BRANCH_FROM` that each add a branch to the skill tree's root; from `BRANCH_FROM`
## on, every wall adds one.
const BRANCH_WALLS := [3, 5]
const BRANCH_FROM := 8

## How each is written on the wall's panel: its name, its mark (`Scenes/UI/` 14 px marks or a 32 px
## picture, drawn at 16), and the line its tooltip reads.
const SHOWN := {
	GOLLUX: {"name": "Gollux", "icon": "res://Assets/UI/ui_icon_skull.png",
			"tip": "His cave appears in every world"},
	RUNES: {"name": "Runes", "icon": "res://Assets/UI/ui_icon_crystal_brown.png",
			"tip": "Dropped in Gollux's cave, they give a charted tile modifiers"},
	DISTANT: {"name": "Distant charting", "icon": "res://Assets/UI/ui_icon_flag.png",
			"tip": "Chart any tile you can see, fighting for every tile on the way"},
	FILTER: {"name": "Item filter", "icon": "res://Assets/UI/ui_icon_filter_brown.png",
			"tip": "Leave behind the loot you do not want"},
	ABILITIES: {"name": "Abilities", "icon": "res://Assets/UI/ui_icon_star.png",
			"tip": "Skill nodes that put a button in the fight"},
}
const BRANCH_ICON := "res://Assets/Skills/root.png"


static func has(walls: int, id: String) -> bool:
	return walls >= int(WALL[id])


## How many branches hang off the skill tree's root with `walls` broken (`SkillTree.root_slots`).
static func root_branches(walls: int) -> int:
	return (SkillTree.ROOT_CONNECTORS + BRANCH_WALLS.filter(func(wall: int) -> bool: return walls >= wall).size()
			+ maxi(0, walls - BRANCH_FROM + 1))


## What the `wall`th wall opens, in the order its panel lists it: {name, icon, tip} each. None for a
## wall short of the first, which a Ring of Walls' half wall can be.
static func of_wall(wall: int) -> Array:
	if wall < 1:
		return []
	var shown := []
	for orb: String in OrbTable.unlocked(wall).slice(OrbTable.unlocked(wall - 1).size()):
		shown.append({"name": orb, "icon": OrbTable.icon_path(orb), "tip": OrbTable.ORBS[orb]["does"]})
	for id: String in WALL:
		if WALL[id] == wall:
			shown.append(SHOWN[id])
	var more := root_branches(wall) - root_branches(wall - 1)
	if more > 0:
		shown.append({"name": "+%d skill branch%s" % [more, "es" if more > 1 else ""], "icon": BRANCH_ICON,
				"tip": "The skill tree's root takes %d more node%s" % [more, "s" if more > 1 else ""]})
	return shown
