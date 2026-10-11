class_name ItemDetails
extends RefCounted
## One item written out: its name in its rarity's colour, what it is, a unique's rule, then tables of
## what a swap would change, its base stats and its modifiers. Every place that inspects an item fills
## from here (the cards, a drop opened in the fight's panel, a shelf, the smith), so a piece reads the
## same everywhere. It fills a VBoxContainer the caller owns, so each keeps its own frame, width and way
## back. The lines are picked to be read on cream (`TextPanel`), never on wood.

const PEAK_ICON := "res://Assets/UI/ui_icon_trophy.png"
## The bar over a piece's name that says how far it is to its next plus: its name, for tests, and its
## height in panel pixels, the 1 px rim of the trough included.
const ASCENSION_BAR := "AscensionBar"
const ASCENSION_HEIGHT := 4
## The line under a piece's name (its rarity, its level and what else it is), by name, for whoever adds
## to it (the card under Alt's "· worn"): the bar stands before the name on some pieces, so it is no
## fixed child.
const RARITY_LINE := "Rarity"
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
## `against` is everything wearing this would take off (a list: a greatsword takes the offhand off with
## the weapon); given any, the first table says what the swap would gain or lose.
## `every_rank` (the collection log under detailed descriptions) writes a ranked unique's rule with
## every rank's numbers, "5/4/3/2", and its rank IV line greyed behind a trophy until it is reached.
static func fill(rows: VBoxContainer, item: Item, width: float, against: Array[Item] = [],
		every_rank := false) -> void:
	UITheme.clear(rows)
	# Over the name the plus is written after.
	if item.plus > 0 or item.ascension > 0:
		rows.add_child(_ascension_bar(item, width))
	rows.add_child(line(item.display_name(), item.text_color(), width))
	# One line for what the piece is: its rarity, a named heirloom's base, its level, both hands (a socket
	# is as much of what it costs as its level) and a unique's rank. In the soft ink for every rarity:
	# the rarity's own colour at 10 px on cream is too pale to read a line by.
	var ranked := not item.unique.is_empty() and UniqueTable.is_ranked(item.unique)
	var rarity := line("%s%s · Level %d%s%s" % [item.rarity_label(),
			"" if item.nickname.is_empty() else " " + item.base_name(), item.level,
			" · Two-handed" if LootTable.two_handed(item.type) else "",
			" · Rank %s" % Achievements.RANK_NAMES[UniqueTable.shown_rank(item.unique)] if ranked else ""],
			Palette.TEXT_SOFT, width, true)
	rarity.name = RARITY_LINE
	rows.add_child(rarity)
	# A skill stone's shape: how deep it may sit and how many stones hang off it.
	if item.is_stone():
		rows.add_child(line(SkillTree.shape_text(item), Palette.TEXT_SOFT, width, true))
	# Not coloured by whether it is met: this block knows no player, and a greyed Equip says it.
	var needs := LootTable.requirement(item.type, item.level)
	if not needs.is_empty():
		rows.add_child(line("Requires %d %s" % [needs[1], LootTable.STAT_LABELS[needs[0]]],
				Palette.TEXT_SOFT, width, true))
	# In a loss's colour, so it is not read as a line the piece rolled.
	if item.broken:
		rows.add_child(line("Broken", Palette.RUST, width, true))
	# An heirloom on its way back up: how far it climbs by itself as the land is charted.
	elif item.safe_level > item.level:
		rows.add_child(line("Climbs to level %d" % item.safe_level, Palette.TEXT_SOFT, width, true))
	# A unique's rule, between two gold lines (the user's, 2026-10-07: written as the modifiers were, it
	# read as one of them) and in ink: gold carries a name at 16 px and is too pale on cream at 10.
	every_rank = every_rank and ranked
	var rule := UniqueTable.effect_text(item.unique, 0) if every_rank else item.effect_text()
	if not rule.is_empty():
		rows.add_child(_gold_rule(item, true))
		rows.add_child(line(rule, Palette.TEXT, width, true))
	# What it gained at rank IV, as much the piece's rule as the first.
	if not item.peak_text().is_empty():
		rows.add_child(line(item.peak_text(), Palette.TEXT, width, true))
	# Not reached yet: "<trophy> IV: the line", greyed as a dead button is -- the mark faded as a bare
	# one's, the words in a disabled face's colour.
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
	# Three tables of [text, colour] rows, each under a rule of its own: what the swap is worth, what the
	# piece is, what it rolled. The swap goes first: it is what the block is opened for, and under an
	# elite's six modifiers it would be the one thing the player had to scroll to find.
	var blocks: Array[Array] = [[], [], []]
	if not against.is_empty():
		var change := deltas(item, against)
		for stat: String in change:
			# Leaf for a gain and rust for a loss: every stat the game has is better the larger it is, so
			# the sign carries the whole meaning. One that ever inverted would need a table here.
			blocks[0].append([LootTable.stat_delta(stat, change[stat]),
					Palette.LEAF if change[stat] > 0.0 else Palette.RUST])
	for text in item.stat_lines():
		blocks[1].append([text, Palette.TEXT])
	# A modifier no orb can move in a base stat's ink (it is as fixed as they are), a perfected one in
	# leaf, the rest in rust.
	var pinned := item.fast_lines(Settings.item_details)
	var perfect := item.perfect_lines(Settings.item_details)
	for text in item.mod_lines(Settings.item_details):
		blocks[2].append([text, Palette.TEXT if text in pinned
				else Palette.LEAF if text in perfect else Palette.RUST])
	# A row holding only a dash, greyed as a dead button's face, for each modifier the rarity still has
	# room for: a piece one short reads apart from a full one. Not on a broken piece, which no orb can fill.
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
			var value := ""
			if index < 2:
				# A stat line opens with its number (`LootTable.stat_line`, `stat_delta`): the first word
				# is the row's value and the rest is its name.
				value = text.get_slice(" ", 0)
				text = text.substr(value.length() + 1)
			else:
				# A modifier is a sentence ("+8% increased Damage"), read as one on one row; only its
				# tier stands apart.
				var found := tier.search(text)
				if found != null:
					value = found.get_string(1)
					text = text.substr(0, found.get_start())
			table.add_child(UITheme.table_row(text, value, table.get_child_count() % 2 == 1, width,
					entry[1], entry[1]))


## What wearing `item` instead of `against` would change: stat -> the signed difference. `against` is
## everything the swap takes off (`Equipment.displaced_by`), added up. Worked out from `effective_stats`
## (what a piece is worth with its own modifiers folded in) over the union of both sides, since a flat
## modifier can put a stat on one side that the other has none of. A plain Dictionary, so what the
## comparison says can be checked without building an interface to read it off.
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


## `UITheme.label` wrapping at `width`; `small` sets it in the body font, which is everything under the name.
static func line(text: String, color: Color, width: float, small := false) -> Label:
	var label := UITheme.label(text, color, small)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0)
	return label
