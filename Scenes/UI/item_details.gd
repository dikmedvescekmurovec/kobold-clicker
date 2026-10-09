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

const PEAK_ICON := "res://Assets/UI/ui_icon_trophy.png"
## The bar over a piece's name that says how far it is to its next plus: its name, for tests, and its
## height in panel pixels, the 1 px rim of the trough included.
const ASCENSION_BAR := "AscensionBar"
const ASCENSION_HEIGHT := 4
## What the row for a modifier the piece has room for and has not rolled says.
const OPEN_ROW := "—"
## The crest cut off a unique's frame (`Item.frame`): its spikes and wings, the ring's top edge under
## them from `CREST_EDGE` down, and the point under that.
const CREST_REGION := Rect2(9, 0, 22, 8)
const CREST_EDGE := 4


## How far `item` is to its next plus, as the bar over its name: a socket's tan, filling with its brown.
static func _ascension_bar(item: Item, width: float) -> ColorRect:
	var trough := ColorRect.new()
	trough.name = ASCENSION_BAR
	trough.color = Palette.SLOT_TAN
	trough.custom_minimum_size = Vector2(width, ASCENSION_HEIGHT)
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	fill.color = Palette.SLOT_TAN_DK
	fill.position = Vector2.ONE
	fill.size = Vector2(floorf((width - 2.0) * float(item.ascension) / item.ascension_cost()), ASCENSION_HEIGHT - 2)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.add_child(fill)
	return trough


## The unique frame's top edge laid across the card, two rows of `Palette.FRAME_GOLD`: over a unique's
## rule with the crest standing on it at the player's rank of the piece, under the rule bare.
static func _gold_rule(item: Item, crest: bool) -> Control:
	var rule := Control.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top := CREST_EDGE if crest else 0
	rule.custom_minimum_size.y = CREST_REGION.size.y if crest else 2
	for row in 2:
		var edge := ColorRect.new()
		edge.color = Palette.FRAME_GOLD if row == 0 else Palette.FRAME_GOLD_DK
		edge.anchor_right = 1.0
		edge.offset_top = top + row
		edge.offset_bottom = top + row + 1
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.add_child(edge)
	if crest:
		var cut := AtlasTexture.new()
		cut.atlas = item.frame()
		cut.region = CREST_REGION
		var mark := TextureRect.new()
		mark.texture = cut
		mark.anchor_left = 0.5
		mark.anchor_right = 0.5
		mark.offset_left = -CREST_REGION.size.x / 2.0
		mark.offset_right = CREST_REGION.size.x / 2.0
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rule.add_child(mark)
	return rule


## Empties `rows` and writes `item` into it. `width` is what a line may use before it wraps.
##
## What a smith has left on a piece reads here and so reads everywhere a piece is shown: "Broken"
## under its rarity, and the locked modifier (`Item.locked_line`) in ink among the rust.
##
## `against` is what this one would replace, when there is anything: it adds a block, first under the
## name, saying what wearing this would gain or lose, which is the question the bag is actually being read to answer.
## A list rather than one piece, because a greatsword takes the offhand off with the weapon.
##
## `every_rank` (the collection log under detailed descriptions) writes a ranked unique's rule with
## every rank's numbers, "5/4/3/2", and its rank IV line greyed behind a trophy until it is reached.
static func fill(rows: VBoxContainer, item: Item, width: float, against: Array[Item] = [],
		every_rank := false) -> void:
	for child: Node in rows.get_children():
		child.queue_free()
	# On its way to the next plus, over the name the plus is written after: the Orbs of Ascension fed
	# in against what that plus takes (`Item.ascension_cost`), a socket's tan filling with its brown.
	if item.plus > 0 or item.ascension > 0:
		rows.add_child(_ascension_bar(item, width))
	rows.add_child(line(item.display_name(), item.text_color(), width))
	# Rarity and level on one line: they are the two things that say what a piece is worth, and they
	# are rolled together off the same body. A piece that needs both hands says so here as well: it
	# costs a socket, which is as much a part of what it is worth as its level is. So does a unique's
	# rank, which is the player's and moves every number its rule writes.
	var ranked := not item.unique.is_empty() and UniqueTable.is_ranked(item.unique)
	# In the soft ink for every rarity: the name over it carries the rarity's colour, which at 10 px on
	# cream is too pale to read a line by (2026-09-30). A named heirloom says here what it is underneath.
	rows.add_child(line("%s%s · Level %d%s%s" % [item.rarity_label(),
			"" if item.nickname.is_empty() else " " + item.base_name(), item.level,
			" · Two-handed" if LootTable.two_handed(item.type) else "",
			" · Rank %s" % Achievements.RANK_NAMES[UniqueTable.shown_rank(item.unique)] if ranked else ""],
			Palette.TEXT_SOFT, width, true))
	# A skill stone's shape: how deep it may sit and how many stones hang off it.
	if item.is_stone():
		rows.add_child(line(SkillTree.shape_text(item), Palette.TEXT_SOFT, width, true))
	# What it asks before it goes on. Not coloured by whether it is met: this block knows no player,
	# and a greyed Equip says it where it matters.
	var needs := LootTable.requirement(item.type, item.level)
	if not needs.is_empty():
		rows.add_child(line("Requires %d %s" % [needs[1], LootTable.STAT_LABELS[needs[0]]],
				Palette.TEXT_SOFT, width, true))
	# Under what the piece is, because that is what it now is: still worn, still sold, and never to be
	# changed again. In the colour a loss is written in, so it is not read as a line it rolled.
	if item.broken:
		rows.add_child(line("Broken", Palette.RUST, width, true))
	# An heirloom on its way back up: how far it climbs by itself as the land is charted.
	elif item.safe_level > item.level:
		rows.add_child(line("Climbs to level %d" % item.safe_level, Palette.TEXT_SOFT, width, true))
	# What a unique is worn for, straight under what it is: the one line on the block that is a rule
	# rather than a number. Set between two gold lines, the top edge of its square's frame with the
	# crest on the first (the user's, 2026-10-07: written as the modifiers were, it read as one of
	# them), in ink, since the gold carries a name at 16 px and is too pale on cream for one at 10.
	every_rank = every_rank and ranked
	var rule := UniqueTable.effect_text(item.unique, 0) if every_rank else item.effect_text()
	if not rule.is_empty():
		rows.add_child(_gold_rule(item, true))
		rows.add_child(line(rule, Palette.TEXT, width, true))
	# And what it gained at rank IV, in the same ink: it is as much the piece's rule as the first.
	if not item.peak_text().is_empty():
		rows.add_child(line(item.peak_text(), Palette.TEXT, width, true))
	# Not reached yet: "<trophy> IV: the line", greyed the way a dead button is -- the mark faded as a
	# bare one's, the words in a disabled face's colour.
	elif every_rank and not UniqueTable.peak_text(item.unique).is_empty():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)
		var trophy := TextureRect.new()
		trophy.texture = load(PEAK_ICON)
		trophy.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		trophy.modulate = UITheme.BARE_DISABLED
		# Beside the sentence's first line, however many it wraps to.
		trophy.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(trophy)
		row.add_child(line("%s: %s" % [Achievements.RANK_NAMES[UniqueTable.PEAK], UniqueTable.peak_text(item.unique)],
				UITheme.DISABLED_FONT_COLOR, width - trophy.texture.get_width() - 2, true))
		rows.add_child(row)
	# The gold line under the rule stands in for the first table's rule.
	var ruled := not rule.is_empty()
	if ruled:
		rows.add_child(_gold_rule(item, false))
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
		blocks[1].append([text, Palette.TEXT])
	# The locked one in a base stat's ink: it is as fixed as they are, and under the rule that parts
	# the two it cannot be taken for one of them.
	# A perfected one in leaf, apart from the rust the rest are written in: as good as it can be.
	var pinned := item.fast_lines(Settings.item_details)
	var perfect := item.perfect_lines(Settings.item_details)
	for text in item.mod_lines(Settings.item_details):
		blocks[2].append([text, Palette.TEXT if text in pinned
				else Palette.LEAF if text in perfect else Palette.RUST])
	# A modifier the rarity still has room for, as a row with nothing on it but a dash greyed as a dead
	# button's face: a piece one short reads apart from a full one without a word. Not on a broken
	# piece, which no orb can fill.
	if not item.broken:
		for _open in OrbTable.room(item) - item.mods.size():
			blocks[2].append([OPEN_ROW, UITheme.DISABLED_FONT_COLOR])
	# A detailed modifier line ends on its tier ("T95"), which stands apart at the row's right end.
	var tier := RegEx.create_from_string(" (T[0-9]+)$")
	for index in blocks.size():
		var block: Array = blocks[index]
		if block.is_empty():
			continue
		if not ruled:
			rows.add_child(UITheme.rule())
		ruled = false
		# A box of its own with no gap, so the stripes of `UITheme.table_row` lie against each other.
		var table := UITheme.vbox(0)
		rows.add_child(table)
		for entry: Array in block:
			var text: String = entry[0]
			var striped := table.get_child_count() % 2 == 1
			if index < 2:
				# A stat line opens with its number (`LootTable.stat_line`, `stat_delta`): the first word
				# is the row's value and the rest is its name.
				var number := text.get_slice(" ", 0)
				table.add_child(UITheme.table_row(text.substr(number.length() + 1), number, striped, width,
						entry[1], entry[1]))
				continue
			# A modifier is a sentence ("+5% to Crit Damage", "+8% increased Damage") and is read as one,
			# on one row; only its tier, under detailed descriptions, stands apart at the right.
			var found := tier.search(text)
			table.add_child(UITheme.table_row(text if found == null else text.substr(0, found.get_start()),
					"" if found == null else found.get_string(1), striped, width, entry[1], entry[1]))


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
