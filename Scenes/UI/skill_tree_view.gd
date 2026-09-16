class_name SkillTreeView
extends Control
## One tree, laid out the way it was sketched: its skills on SkillTree's grid of rows and columns, and
## a line from every skill down to each skill it leads to.
##
## Placed by hand rather than by containers, for the reason the character sheet's sockets are: no
## container says "under both of those, in the middle". The lines are drawn by this Control, which
## Godot draws before its children, so they run under the icons rather than across them.

## The gaps between squares, in panel pixels. Wide enough for a line to read as a line between two
## framed icons, and for a count hanging off one square to clear the next. The rows are tighter than
## the columns because height is what the page is short of: five rows have to fit a 648 px window at
## `ui_scale` 2 with the title, the points and both resets.
const GAP_X := 14
const GAP_Y := 9
## The line, in panel pixels: ink where nothing leads down it yet, gold where the skill above has a
## point, so the path a player has taken reads down the tree before a single count is read.
const LINE := 2

signal node_pressed(id: String)
signal node_hovered(id: String, slot: SkillSlot)
signal node_unhovered()

var tree := ""
var _ranks := {}


## Builds `which` for the learned `ranks`. Called again to redraw; nothing here remembers anything
## the ranks do not say.
func fill(which: String, ranks: Dictionary) -> void:
	tree = which
	_ranks = ranks
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	custom_minimum_size = Vector2(
			SkillTree.COLS * SkillSlot.SIDE + (SkillTree.COLS - 1) * GAP_X,
			SkillTree.ROWS * SkillSlot.SIDE + (SkillTree.ROWS - 1) * GAP_Y + SkillSlot.COUNT_OVERHANG)
	var nodes := SkillTree.nodes_of(which)
	for id: String in nodes:
		var slot := SkillSlot.make(id, int(ranks.get(id, 0)), SkillTree.is_open(id, ranks))
		slot.position = corner_of(id)
		slot.pressed.connect(func(pressed_id: String) -> void: node_pressed.emit(pressed_id))
		slot.hovered.connect(func(hovered_id: String) -> void: node_hovered.emit(hovered_id, slot))
		slot.unhovered.connect(func() -> void: node_unhovered.emit())
		add_child(slot)
	queue_redraw()


## The top-left corner of a skill's square.
static func corner_of(id: String) -> Vector2:
	var entry := SkillTree.node(id)
	return Vector2(int(entry["col"]) * (SkillSlot.SIDE + GAP_X), int(entry["row"]) * (SkillSlot.SIDE + GAP_Y))


static func centre_of(id: String) -> Vector2:
	return corner_of(id) + Vector2(SkillSlot.SIDE, SkillSlot.SIDE) / 2.0


func _draw() -> void:
	if tree.is_empty():
		return
	var nodes := SkillTree.nodes_of(tree)
	for id: String in nodes:
		for parent: String in nodes[id]["parents"]:
			var lit := int(_ranks.get(parent, 0)) > 0
			draw_line(centre_of(parent), centre_of(id), Palette.GOLD if lit else Palette.INK, LINE)
