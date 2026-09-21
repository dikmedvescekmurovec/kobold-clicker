class_name ItemDetails
extends RefCounted
## What one item is, written out: its name and rarity in that rarity's colour, what the piece itself
## is worth, and then whatever it rolled on top.
##
## Every place that inspects an item fills its panel from here -- the bag, the fight's own panel
## when a drop is clicked, a shelf, the cards -- for the same reason ItemSlot draws both of their squares: an item that
## reads one way in one place and another way in the other is two things to keep in step, and they
## would not stay in step.
##
## It fills a VBoxContainer rather than returning a panel, so each caller keeps its own frame, its
## own width and its own way back. The lines want a bone background: the darker half of the rarity
## ramp is chosen to be read on the white panel, not on wood.

## Empties `rows` and writes `item` into it. `width` is what a line may use before it wraps.
##
## What a smith has left on a piece reads here and so reads everywhere a piece is shown: "Broken"
## under its rarity, and the locked modifier (`Item.locked_line`) in ink among the rust.
##
## `against` is what this one would replace, when there is anything: it adds a block, first under the
## name, saying what wearing this would gain or lose, which is the question the bag is actually being read to answer.
## A list rather than one piece, because a greatsword takes the offhand off with the weapon.
static func fill(rows: VBoxContainer, item: Item, width: float, against: Array[Item] = []) -> void:
	for child: Node in rows.get_children():
		child.queue_free()
	rows.add_child(line(item.display_name(), item.text_color(), width))
	# Rarity and level on one line: they are the two things that say what a piece is worth, and they
	# are rolled together off the same body. A piece that needs both hands says so here as well: it
	# costs a socket, which is as much a part of what it is worth as its level is.
	rows.add_child(line("%s · level %d%s" % [item.rarity_name(), item.level,
			" · Two-handed" if LootTable.two_handed(item.type) else ""],
			item.text_color(), width, true))
	# Under what the piece is, because that is what it now is: still worn, still sold, and never to be
	# changed again. In the colour a loss is written in, so it is not read as a line it rolled.
	if item.broken:
		rows.add_child(line("Broken", Palette.RUST, width, true))
	# An heirloom on its way back up: how far the smith can take it for nothing but gold.
	elif item.safe_level > item.level:
		rows.add_child(line("Cannot break until level %d" % item.safe_level, Palette.SLATE, width, true))
	# What a unique is worn for, straight under what it is: the one line on the block that is a rule
	# rather than a number. In the pack's wood brown and not the unique's own gold, which carries a
	# name at 16 px and is too pale on cream for a sentence at 10.
	if not item.effect_text().is_empty():
		rows.add_child(line(item.effect_text(), Palette.SLOT_TAN_DK, width, true))
	# What its set does, in the set's own green -- which is also the colour of its name and its frame.
	if item.is_set():
		rows.add_child(line(item.set_text(), ItemRarity.SET_TEXT, width, true))
	# Three blocks of [text, colour], each under a rule of its own and
	# drawn as a table (name left, number right): what the swap is worth, what the
	# piece is, what it rolled. The swap goes first, straight under the name: it is the answer the
	# block is opened for, and an elite carrying six modifiers is taller than the panel -- last, it
	# would be the one thing the player had to scroll to find.
	var blocks: Array[Array] = [[], [], []]
	if not against.is_empty():
		var change := deltas(item, against)
		for stat: String in change:
			# Leaf for a gain and rust for a loss. Every stat the game has is better the larger it
			# is, so the sign carries the whole meaning and no table is needed to say which way is
			# up; one that ever inverted would need one here, and there is none.
			blocks[0].append([LootTable.stat_delta(stat, change[stat]),
					Palette.LEAF if change[stat] > 0.0 else Palette.RUST])
	for text in item.stat_lines():
		blocks[1].append([text, Palette.INK])
	# The locked one in a base stat's ink: it is as fixed as they are, and under the rule that parts
	# the two it cannot be taken for one of them.
	# A perfected one in the wood brown a unique's rule wears: the one line as good as it can be.
	var pinned := item.fast_lines(Settings.item_details)
	var perfect := item.perfect_lines(Settings.item_details)
	for text in item.mod_lines(Settings.item_details):
		blocks[2].append([text, Palette.INK if text in pinned
				else Palette.SLOT_TAN_DK if text in perfect else Palette.RUST])
	for block in blocks:
		if block.is_empty():
			continue
		rows.add_child(UITheme.rule())
		# A box of its own with no gap, so the stripes of `UITheme.table_row` lie against each other.
		var table := UITheme.vbox(0)
		rows.add_child(table)
		for entry: Array in block:
			# Every line an item writes opens with its number (`LootTable.stat_line`, `stat_delta`,
			# `ModifierTable.line`): the first word is the row's value and the rest is its name.
			var text: String = entry[0]
			var number := text.get_slice(" ", 0)
			table.add_child(UITheme.table_row(text.substr(number.length() + 1), number,
					table.get_child_count() % 2 == 1, width, entry[1], entry[1]))


## What wearing `item` instead of `against` would change: stat -> the signed difference.
##
## `against` is everything the swap takes off (`Equipment.displaced_by`) added up, not merely the
## piece in the socket being filled: a greatsword costs the sword *and* the shield, and a shield put
## on over a greatsword costs the whole of the greatsword. One piece is the ordinary case, and it
## reads exactly as it always did.
##
## Worked out from `effective_stats` rather than the base tables, because that is what the piece is
## actually worth once its own modifiers are folded in -- and a flat modifier can put a stat on one
## side that the other has none of at all, which is why this runs over the union of both.
##
## A plain Dictionary rather than a list of Labels, so what the comparison says can be checked
## without building an interface to read it off.
static func deltas(item: Item, against: Array[Item]) -> Dictionary:
	var mine := item.effective_stats()
	var theirs := {}
	for piece: Item in against:
		var stats := piece.effective_stats()
		for stat: String in stats:
			theirs[stat] = float(theirs.get(stat, 0.0)) + float(stats[stat])
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


## One line of it; `small` sets it in the body font, which is everything under the name.
static func line(text: String, color: Color, width: float, small := false) -> Label:
	var label := Label.new()
	label.theme_type_variation = "SmallLabel" if small else "PanelLabel"
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
