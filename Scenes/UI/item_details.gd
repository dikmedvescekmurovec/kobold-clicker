class_name ItemDetails
extends RefCounted
## What one item is, written out: its name and rarity in that rarity's colour, what the piece itself
## is worth, and then whatever it rolled on top.
##
## Both places that inspect an item fill their panel from here -- the bag, and the fight's own panel
## when a drop is clicked -- for the same reason ItemSlot draws both of their squares: an item that
## reads one way in one place and another way in the other is two things to keep in step, and they
## would not stay in step.
##
## It fills a VBoxContainer rather than returning a panel, so each caller keeps its own frame, its
## own width and its own way back. The lines want a bone background: the darker half of the rarity
## ramp is chosen to be read on the white panel, not on wood.

## The rule drawn between what the piece is and what it rolled.
const RULE_HEIGHT := 1


## Empties `rows` and writes `item` into it. `width` is what a line may use before it wraps -- the
## font is only legible at its native 16 px, so a long modifier has to wrap rather than shrink.
static func fill(rows: VBoxContainer, item: Item, width: float) -> void:
	for child: Node in rows.get_children():
		child.queue_free()
	rows.add_child(line(item.display_name(), item.text_color(), width))
	rows.add_child(line(item.rarity_name(), item.text_color(), width))
	var rule := ColorRect.new()
	rule.color = Palette.SLATE
	rule.custom_minimum_size = Vector2(0, RULE_HEIGHT)
	rows.add_child(rule)
	for text in item.stat_lines():
		rows.add_child(line(text, Palette.INK, width))
	for text in item.mod_lines():
		rows.add_child(line(text, Palette.RUST, width))


## One line of it.
static func line(text: String, color: Color, width: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
