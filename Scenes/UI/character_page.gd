class_name CharacterPage
extends Control
## What the player adds up to, as a page against the left edge headed "Character": a card of who they
## are (the portrait beside the name with its pencil, the level and its experience, and the three
## attributes as chips under them), the damage they do a second and a click, this world's curses, what
## changes how a fight plays (the uniques worn and the capstones learned), and every other stat that is
## something, in tables -- the kills and the depth won last, under Misc.
##
## **The numbers are the fight's** (`_numbers`): a fight armed off `Inventory.stats()` the way the main
## scene arms one, so the bare hand, the caps and the base clock and sight are in them -- the page says
## what a blow does, not what the gear adds up to. Where a number comes from is its row's tooltip, and
## a number that has moved since the page was last put away carries the difference beside it.
##
## Built like the other left-hand pages (`CollectionPage`): `open()` redraws it, `layout()` fits it to
## the window, `closed` is its X. It changes nothing and so saves nothing: the pencil beside the name
## only asks the main scene to rename the character (`rename_pressed`).

## The page's X was pressed.
signal closed
## The pencil beside the name was pressed: the main scene asks for a new one (`TextPrompt`).
signal rename_pressed

## What the page's bar says; the character's own name heads its card.
const TITLE := "Character"
## The pencil's mark, in the pack's brown.
const PENCIL_ICON := preload("res://Assets/UI/ui_icon_pencil_brown.png")
## The air between the name and its pencil.
const NAME_GAP := 4

## The three attributes, in the order they stand, and the colour of each one's chip.
const ATTRIBUTES := {
	"strength": Palette.BRICK,
	"intelligence": Palette.ICE_DK,
	"dexterity": Palette.LEAF,
}
## The tables, each under its heading, in the order they stand: every stat `LootTable.STAT_LABELS`
## names but the attributes, which are the chips, and their line of all three, which is in them
## (`test_inventory` holds that, so a new stat is never left off), and under Misc the counts of how far
## they have come.
const GROUPS := {
	"Offence": ["damage", "crit_chance", "crit_damage", "attack_speed", "bleed", "burn", "click_damage",
		"swing_damage", "elite_damage", "first_blow", "double_strike", "parry", "thorns", "less_health"],
	"Defence": ["armor", "dodge", "block", "time_on_hit", "time_on_block", "recoup", "blow_delay",
		"elite_ward", "tile_ward", "fight_clock"],
	"Rewards": ["drop_rate", "item_rarity", "gold_find", "orb_find", "xp_more", "elite_chance", "camp_earnings"],
	"Utility": ["spawn_speed", "move_speed", "sight", "extra_enemies", "strength_stones", "dexterity_stones",
		"intelligence_stones"],
	"Misc": ["kills", "depth", "time"],
}
## What a row is called where `LootTable.STAT_LABELS` does not say.
const LABELS := {"kills": "Kills", "depth": "Depth won", "time": "Time played"}
## The rows written even at nothing, because every hero has some: a blow, a clock, a sight, a count of
## kills, the time played. So a fresh hero's page is never an empty frame.
const ALWAYS := ["damage", "fight_clock", "sight", "kills", "time"]
## What is a bonus on what the hero already has, written with its sign: what a crit adds, a finder's
## lift, a faster walk. A chance or a share of something is written bare.
const SIGNED := ["crit_damage", "move_speed", "drop_rate", "item_rarity", "gold_find", "orb_find", "xp_more",
	"click_damage", "swing_damage", "elite_damage", "first_blow", "camp_earnings", "extra_enemies",
	"strength_stones", "intelligence_stones", "dexterity_stones", "parry"]
## The rows the fight holds to a most (`Encounter.WARD_MOST`, certainty for the recoup), read off the
## fight (its fields of the same names) rather than the gear, so the page says what the hero has.
const HELD := ["elite_ward", "tile_ward", "less_health", "recoup"]
## The two headline numbers' keys in `_now`, and the names of their values' Labels.
const PER_SECOND := "per_second"
const PER_CLICK := "per_click"
const HEADLINES := {PER_SECOND: "Damage per second (avg)", PER_CLICK: "Damage per click (avg)"}
## The Label a change since the last look is written in, set into its row between the name and the number.
const CHANGE_NAME := "Change"
## A heading's id for `Accordion`, which keeps what is folded by it.
const SECTION_ID := "character:%s"
const CURSES := "Curses"
const EFFECTS := "Effects"
## A chip: the air round its number, the least it is across (so a 0 is not a sliver), its corners.
const CHIP_PAD := Vector2i(4, 1)
const CHIP_LEAST := 12
const CHIP_CORNER := 4
const CHIP_GAP := 8
const PORTRAIT_SCALE := 2
## The header card's padding and the air between its portrait and its lines.
const CARD_PAD := 4
const CARD_GAP := 8

## Whether the curses have been shown open this session: from the first time the page is put away
## over them they start folded, so the stats, which change, have the page's top and the curses, which
## do not, are a press away (the user's sheet review, 2026-10-03). Opened again, they stay open.
static var _curses_shown := false

var inventory: Inventory
var _ui_scale: float
var _panel: VBoxContainer
## The character's name at the head of the card, which every `open()` writes.
var _title: Label
var _rows: VBoxContainer
## Every number the page writes now, by stat (`_numbers`), and what they were when the page was last
## put away -- or built: the difference between the two is written beside a number that moved.
var _now := {}
var _seen := {}
## Whether the page has been up since it was built, which is what makes putting it away a look.
var _looked := false
## The time played's number, kept moving while the page is up so it does not sit still as it is read.
var _played: Label


func _init(player_inventory: Inventory, ui_scale: float) -> void:
	inventory = player_inventory
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel(TITLE, "Close", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	# Scrolled, like the log: a late set carries more stats than a 648 px window holds.
	var scroll := UITheme.scroll()
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(BountyList.ROW_GAP, BagPage.WIDTH)
	scroll.add_child(_rows)
	open()
	_seen = _now.duplicate()
	visibility_changed.connect(_on_visibility_changed)


## Redraws the page: who, the headline, the curses, the effects, then the tables.
func open() -> void:
	UITheme.clear(_rows)
	var totals := inventory.stats()
	var fight := armed(inventory, totals)
	_now = _numbers(totals, fight)
	_rows.add_child(_who(totals))
	_rows.add_child(_headline())
	if not inventory.curses.is_empty():
		_curses()
	_effects()
	for heading: String in GROUPS:
		_table(heading, totals, fight)


func _process(_delta: float) -> void:
	if visible and is_instance_valid(_played):
		_played.text = _text("time", inventory.play_seconds)


## Put away: what the page read becomes what the next look is measured from, and the curses, once seen
## open this session, start folded.
func _on_visibility_changed() -> void:
	if visible:
		_looked = true
		return
	_seen = _now.duplicate()
	if _looked and not inventory.curses.is_empty() and not _curses_shown:
		_curses_shown = true
		Accordion.fold(SECTION_ID % CURSES)


## A fight armed the way the main scene arms one, with no lineup: what a blow, a crit, a swing and the
## clock come to once the bare hand, the caps and the uniques that move a number are counted. The
## character panel's numbers off a fight, too (`main_scene._show_damage`).
static func armed(owner: Inventory, totals: Dictionary) -> Encounter:
	var fight := Encounter.new()
	# Not `wear`, which takes the Dreadmask and the curses on over a lineup this fight has not got.
	fight.effects = owner.effects()
	fight.ranks = Achievements.ranks(owner)
	fight.arm(totals)
	return fight


## Every number the page writes, by stat: the fight's where the fight reads one, so the page says what
## the hero has rather than what the gear adds up to. Block, time on hit and the clock are in tenths, as
## the gear keeps them (`LootTable.SECONDS_STATS`).
func _numbers(totals: Dictionary, fight: Encounter) -> Dictionary:
	var out := {}
	for heading: String in GROUPS:
		for stat: String in GROUPS[heading]:
			out[stat] = float(totals.get(stat, 0.0))
	out["damage"] = fight.damage
	out["crit_chance"] = fight.crit_chance
	out["crit_damage"] = fight.crit_damage
	out["attack_speed"] = fight.attack_speed
	out["spawn_speed"] = fight.spawn_speed
	out["double_strike"] = fight.double_strike
	out["elite_chance"] = fight.elite_chance
	out["xp_more"] = fight.xp_more
	for stat: String in HELD:
		out[stat] = float(fight.get(stat))
	out["fight_clock"] = fight.seconds * 10.0
	out["sight"] = float(inventory.sight())
	out["kills"] = float(inventory.kills)
	out["depth"] = float(inventory.dungeon_depth)
	out["time"] = inventory.play_seconds
	out[PER_SECOND] = fight.per_second()
	out[PER_CLICK] = fight.average_blow(false)
	return out


## A heading that folds what is under it, added to the page; returns what to fill.
func _section(title: String) -> VBoxContainer:
	var section := Accordion.new(title, SECTION_ID % title, BountyList.ROW_GAP)
	_rows.add_child(section)
	return section.body


## The card at the head of the page: the portrait on a socket, and beside it the character's name with
## its pencil, the level and the experience towards the next as a bar with its count under it; under
## them the three attributes as chips.
func _who(totals: Dictionary) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", BountyList.flat(Color.TRANSPARENT, CARD_PAD))
	var column := UITheme.vbox(CARD_PAD)
	card.add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	column.add_child(row)
	var socket := PanelContainer.new()
	socket.add_theme_stylebox_override("panel", BountyList.flat(Palette.SLOT_TAN, CARD_PAD))
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var portrait := TextureRect.new()
	# Before the texture and the size: a TextureRect's minimum is its texture until this says otherwise.
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.texture = CharacterPanel.PORTRAIT
	portrait.custom_minimum_size = CharacterPanel.PORTRAIT.get_size() * PORTRAIT_SCALE
	socket.add_child(portrait)
	row.add_child(socket)
	var lines := UITheme.vbox(2)
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# What the card has left once the socket, the gap and both paddings are paid for.
	var room: float = BagPage.WIDTH - portrait.custom_minimum_size.x - CARD_GAP - CARD_PAD * 4 - 2
	lines.add_child(_name_row(room))
	lines.add_child(UITheme.label("Level %d" % inventory.level, Palette.TEXT, true))
	var need := PlayerLevel.xp_to_next(inventory.level)
	lines.add_child(BountyList.progress_bar(inventory.xp, need, room, false))
	lines.add_child(UITheme.label("%s / %s XP" % [BigNumber.format(float(inventory.xp)),
			BigNumber.format(float(need))], Palette.TEXT_SOFT, true))
	row.add_child(lines)
	column.add_child(UITheme.rule())
	var chips := HBoxContainer.new()
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.add_theme_constant_override("separation", CHIP_GAP)
	for stat: String in ATTRIBUTES:
		chips.add_child(_chip(stat, float(totals.get(stat, 0.0))))
	column.add_child(chips)
	return card


## The character's name, the one heading in the card, with the pencil straight after it. A name past
## the `room` the pencil leaves is cut with an ellipsis, as the corner panel cuts it.
func _name_row(room: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", NAME_GAP)
	_title = UITheme.label(inventory.hero())
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(_title)
	var pencil := UITheme.button("", UITheme.BARE_BUTTON, "Rename")
	pencil.icon = PENCIL_ICON
	pencil.focus_mode = Control.FOCUS_NONE
	pencil.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pencil.pressed.connect(rename_pressed.emit)
	row.add_child(pencil)
	var face := UITheme.theme().get_stylebox("normal", UITheme.BARE_BUTTON)
	room -= NAME_GAP + PENCIL_ICON.get_width() + face.get_margin(SIDE_LEFT) + face.get_margin(SIDE_RIGHT)
	# Measured off the theme: the label is not in the tree yet, and a trimmed label asks for no width.
	var font := UITheme.theme().get_font("font", "PanelLabel")
	var width := ceilf(font.get_string_size(_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FONT_SIZE).x)
	_title.custom_minimum_size.x = minf(width, room)
	return row


## One attribute: its total on a chip of its colour, its name under it. Small, because a point is worth
## little (`Inventory.ATTRIBUTE_PERCENT`) and what the number is mostly for is the equip requirement.
func _chip(stat: String, value: float) -> VBoxContainer:
	var column := UITheme.vbox(1)
	var chip := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = ATTRIBUTES[stat]
	box.border_color = (ATTRIBUTES[stat] as Color).darkened(0.4)
	box.set_border_width_all(1)
	box.set_corner_radius_all(CHIP_CORNER)
	# Hard edges: a smoothed chip beside pixel art reads as a different game.
	box.anti_aliasing = false
	box.content_margin_left = CHIP_PAD.x
	box.content_margin_right = CHIP_PAD.x
	box.content_margin_top = CHIP_PAD.y
	box.content_margin_bottom = CHIP_PAD.y
	chip.add_theme_stylebox_override("panel", box)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Through to the column, whose tooltip says what the attribute does (`TipCard.text_of`).
	chip.mouse_filter = Control.MOUSE_FILTER_PASS
	# Bone in the body font: all three colours are dark enough to carry it without an outline.
	var number := UITheme.label(BigNumber.format(roundf(value)), Palette.BONE, true)
	number.name = stat
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.custom_minimum_size.x = CHIP_LEAST
	chip.add_child(number)
	column.add_child(chip)
	var label := UITheme.label(LootTable.STAT_LABELS[stat], Palette.TEXT_SOFT, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	# What a point is worth, off the same `attribute_gift` the fight's numbers are, so the Scholar's
	# Circlet turning intelligence to damage says so here too.
	var gift := inventory.attribute_gift(stat, value)
	column.tooltip_text = "Each point of %s adds %.1f%% more %s\nYours add +%.1f%%" % [LootTable.STAT_LABELS[stat],
			inventory.attribute_gift(stat, 1.0)[1], LootTable.STAT_LABELS[gift[0]], gift[1]]
	return column


## The two numbers the rest add up to, on their own under the card, each an average off every stat the
## fight reads (`Encounter.average_blow`) and saying so: what a second of the weapon swinging does,
## hands off, and what a click does.
func _headline() -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", BountyList.flat(UITheme.TABLE_STRIPE, CARD_PAD))
	var rows := UITheme.vbox(2)
	box.add_child(rows)
	rows.add_child(_headline_row(PER_SECOND))
	rows.add_child(_headline_row(PER_CLICK))
	return box


## One headline: its name small, the change since the last look, and the number in Pixellari. The name
## wraps where a long figure and its change leave it no room, as a table row's does.
func _headline_row(key: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", UITheme.TABLE_GAP)
	var name_cell := UITheme.label(HEADLINES[key], Palette.TEXT_SOFT, true)
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(name_cell)
	var change := _change(key)
	if change != null:
		change.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(change)
	var value := UITheme.label(_text(key, _now[key]))
	value.name = key
	row.add_child(value)
	return row


## What this world is under, straight under the headline: at the foot it would be under the fold. Each
## its name with what it costs and pays written under it, as the tile panel writes a modifier; the
## numbers a curse pays are in the tables (`Inventory.stats`).
func _curses() -> void:
	var cursed := _section(CURSES)
	for id: String in inventory.curses:
		var curse: Dictionary = Curses.CURSES[id]
		# A block of its own at the tile panel's gap: the page's row gap would pull the lines apart.
		var block := UITheme.vbox(2)
		block.add_child(UITheme.label(str(curse["name"]), Palette.RUST))
		block.add_child(ItemDetails.line(str(curse["text"]), Palette.TEXT, BagPage.WIDTH, true))
		block.add_child(ItemDetails.line(str(curse["reward"]), Palette.LEAF, BagPage.WIDTH, true))
		# The one curse whose terms were dealt and not written: which two lands are home.
		if id == Curses.HOMELAND and not inventory.homeland.is_empty():
			block.add_child(ItemDetails.line("Your lands: %s." % " and ".join(inventory.homeland.map(
					func(env: String) -> String: return env.capitalize())), Palette.TEXT_SOFT, BagPage.WIDTH, true))
		cursed.add_child(block)


## What changes how a fight plays rather than a number: every unique worn on either doll, then every
## capstone in the skill tree holding a point, each as its square (its card under the cursor, held
## against nothing -- an heirloom's doll is not the one Alt compares with, and a stone has none). Left
## out while there is none.
func _effects() -> void:
	var pieces := (inventory.equipment.items() + inventory.stash().equipment.items()).filter(
			func(piece: Item) -> bool: return not piece.unique.is_empty())
	for path: String in inventory.skills._stones_held():
		var stone: Item = inventory.skills.stones[path]
		if not stone.capstone.is_empty():
			pieces.append(stone)
	if pieces.is_empty():
		return
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	flow.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	_section(EFFECTS).add_child(flow)
	for piece: Item in pieces:
		var slot := ItemSlot.make(piece)
		slot.set_meta(ItemCard.NO_COMPARE, true)
		flow.add_child(slot)


## One heading's stats as a table, each that is something -- or that every hero has (`ALWAYS`) -- a row
## named for its stat: the name, the change since the last look, the number, and where it comes from as
## its tooltip. A heading with none of its stats is left out. Something is anything but nothing: the
## body armour's count of enemies can be fewer.
func _table(heading: String, totals: Dictionary, fight: Encounter) -> void:
	var shown: Array = GROUPS[heading].filter(func(stat: String) -> bool:
			return stat in ALWAYS or float(_now[stat]) != 0.0)
	if shown.is_empty():
		return
	# A framed block of its own: the page's row gap is for cards, and would pull a table apart.
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", BountyList.flat(Color.TRANSPARENT, 1))
	var body := UITheme.vbox(0)
	table.add_child(body)
	_section(heading).add_child(table)
	for stat: String in shown:
		var row := UITheme.table_row(str(LABELS.get(stat, LootTable.STAT_LABELS.get(stat, stat))),
				_text(stat, _now[stat]), body.get_child_count() % 2 == 1, 0.0, Palette.SLOT_TAN_DK, Palette.TEXT)
		row.name = stat
		row.tooltip_text = _sources(stat, totals, fight)
		if stat == "time":
			_played = row.find_child(UITheme.TABLE_VALUE, true, false)
		var change := _change(stat)
		if change != null:
			var cells := row.get_child(0)
			cells.add_child(change)
			cells.move_child(change, 1)
		body.add_child(row)


## `value` of `stat` as the page writes it: the stat's own way (`LootTable.stat_value`; a count as a plain
## number), with its sign where it is a bonus (`SIGNED`).
static func _text(stat: String, value: float) -> String:
	if stat in HEADLINES:
		return BigNumber.format(value)
	if stat == "time":
		return _spent(value)
	var text := LootTable.stat_value(stat, value)
	return "+" + text if stat in SIGNED and value > 0.0 else text


## The difference from what `stat` read the last time the page was put away, in leaf for more and brick
## for less -- every stat here is better higher -- or null where nothing that shows has moved. Nor for a
## stat that was nothing then: its whole number is the change, and "+10% 10%" says it twice.
func _change(stat: String) -> Label:
	# The time played moves every second, and would always say so.
	if stat == "time" or float(_seen.get(stat, 0.0)) == 0.0 or _text(stat, _now[stat]) == _text(stat, _seen[stat]):
		return null
	var moved: float = _now[stat] - _seen[stat]
	if not LootTable.delta_shows(stat, moved):
		return null
	var text := BigNumber.format(moved, true)
	if stat in LootTable.RATE_STATS:
		text = "%+.1f/s" % moved
	elif stat in LootTable.SECONDS_STATS:
		text = LootTable.seconds_text(moved, true)
	elif stat in LootTable.PERCENT_STATS:
		text += "%"
	var label := UITheme.label(text, Palette.LEAF if moved > 0.0 else Palette.BRICK, true)
	label.name = CHANGE_NAME
	return label


## `seconds` played as words: hours once there are any, and seconds until then, so a fresh game's line
## moves while it is watched.
static func _spent(seconds: float) -> String:
	var whole := int(seconds)
	if whole >= 3600:
		return "%dh %dm" % [whole / 3600, whole % 3600 / 60]
	return "%dm %ds" % [whole / 60, whole % 60]


## Where a row's number comes from, for its tooltip: what a rating buys, what sits on top of the gear
## and the skills -- the bare hand, the collection, an attribute's share, the base clock and sight -- and
## the cap a number stopped at. Empty where it is the gear and the skills alone.
func _sources(stat: String, totals: Dictionary, fight: Encounter) -> String:
	var lines: Array[String] = []
	var raw := float(totals.get(stat, 0.0))
	match stat:
		"damage":
			lines.append("Bare hands +%d" % Encounter.BARE_DAMAGE)
			if inventory.collection_bonus() > 0:
				lines.append("Collection +%d%%" % inventory.collection_bonus())
		"crit_chance":
			if "beginners_luck" not in fight.effects and raw > Encounter.CRIT_CAP:
				lines.append("At most %s%%" % BigNumber.format(Encounter.CRIT_CAP))
		"attack_speed":
			if fight.attack_speed >= Encounter.SWING_CAP:
				lines.append("At most %.1f/s" % Encounter.SWING_CAP)
		"spawn_speed", "double_strike", "elite_chance", "recoup":
			if raw > 100.0:
				lines.append("At most 100%")
		"elite_ward", "tile_ward", "less_health":
			if raw > Encounter.WARD_MOST:
				lines.append("At most %s%%" % BigNumber.format(Encounter.WARD_MOST))
		"armor":
			lines.append("%d%% off every blow" % roundi((1.0 - fight.taken(1.0, 0.0)) * 100.0))
		"dodge":
			lines.append("%d%% of blows dodged" % roundi(fight.dodge_chance() * 100.0))
		"fight_clock":
			lines.append("Base %s" % LootTable.seconds_text(Encounter.SECONDS * 10.0))
			if fight.seconds > Encounter.SECONDS:
				lines.append("Gear %s" % LootTable.seconds_text((fight.seconds - Encounter.SECONDS) * 10.0, true))
			if LootTable.seconds_of(stat, raw) > Encounter.CLOCK_MOST:
				lines.append("Gear at most %s" % LootTable.seconds_text(Encounter.CLOCK_MOST * 10.0, true))
		"sight":
			lines.append("Base %d" % (0 if Curses.THICK_FOG in inventory.curses else Inventory.BASE_SIGHT))
			if raw > 0.0:
				lines.append("Gear +%d" % roundi(raw))
	# The attributes' shares, off the same `attribute_gift` the totals are.
	for attribute: String in ATTRIBUTES:
		var gift := inventory.attribute_gift(attribute, float(totals.get(attribute, 0.0)))
		if gift[0] == stat and float(gift[1]) > 0.0:
			lines.append("%s +%.1f%%" % [LootTable.STAT_LABELS[attribute], gift[1]])
	return "\n".join(lines)


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)
