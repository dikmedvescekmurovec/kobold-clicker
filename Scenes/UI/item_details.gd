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

## Empties `rows` and writes `item` into it. `width` is what a line may use before it wraps -- the
## font is only legible at its native 16 px, so a long modifier has to wrap rather than shrink.
##
## What a smith has left on a piece reads here and so reads everywhere a piece is shown: "Broken"
## under its rarity, and the word on the locked modifier's own line, which `Item.mod_lines` puts there.
##
## `against` is the piece this one would replace, when there is one: it adds a last block saying what
## wearing this would gain or lose, which is the question the bag is actually being read to answer.
static func fill(rows: VBoxContainer, item: Item, width: float, against: Item = null) -> void:
	for child: Node in rows.get_children():
		child.queue_free()
	rows.add_child(line(item.display_name(), item.text_color(), width))
	# Rarity and level on one line: they are the two things that say what a piece is worth, and they
	# are rolled together off the same body.
	rows.add_child(line("%s · level %d" % [item.rarity_name(), item.level], item.text_color(), width))
	# Under what the piece is, because that is what it now is: still worn, still sold, and never to be
	# changed again. In the colour a loss is written in, so it is not read as a line it rolled.
	if item.broken:
		rows.add_child(line("Broken", Palette.RUST, width))
	rows.add_child(UITheme.rule())
	# What the swap is worth goes first, straight under the name, and what the piece is follows it.
	# It is the answer the block is opened for, and an elite carrying six modifiers is taller than
	# the panel -- last, it would be the one thing the player had to scroll to find.
	if against != null:
		var change := deltas(item, against)
		if not change.is_empty():
			for stat: String in change:
				# Leaf for a gain and rust for a loss. Every stat the game has is better the larger it
				# is, so the sign carries the whole meaning and no table is needed to say which way is
				# up; one that ever inverted would need one here, and there is none.
				rows.add_child(line(LootTable.stat_delta(stat, change[stat]),
						Palette.LEAF if change[stat] > 0.0 else Palette.RUST, width))
			rows.add_child(UITheme.rule())
	for text in item.stat_lines():
		rows.add_child(line(text, Palette.INK, width))
	for text in item.mod_lines():
		rows.add_child(line(text, Palette.RUST, width))


## What wearing `item` instead of `against` would change: stat -> the signed difference.
##
## Worked out from `effective_stats` rather than the base tables, because that is what the piece is
## actually worth once its own modifiers are folded in -- and a flat modifier can put a stat on one
## side that the other has none of at all, which is why this runs over the union of both.
##
## A plain Dictionary rather than a list of Labels, so what the comparison says can be checked
## without building an interface to read it off.
static func deltas(item: Item, against: Item) -> Dictionary:
	var mine := item.effective_stats()
	var theirs := against.effective_stats()
	var out := {}
	for stat: String in mine:
		out[stat] = float(mine[stat]) - float(theirs.get(stat, 0.0))
	for stat: String in theirs:
		if not mine.has(stat):
			out[stat] = -float(theirs[stat])
	for stat: String in out.keys():
		if not LootTable.delta_shows(stat, out[stat]):
			out.erase(stat)
	return out


## One line of it.
static func line(text: String, color: Color, width: float) -> Label:
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
