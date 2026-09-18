class_name CharacterPage
extends Control
## What the player adds up to, as a page against the left edge: the portrait beside level, experience
## and kills, the three attributes as numbers on coloured discs, and under them every other stat that
## is not nothing as a table, names on the left and numbers on the right -- `Inventory.stats()`, which
## is exactly what a fight is armed with.
##
## Built like the other left-hand pages (`CollectionPage`): `open()` redraws it, `layout()` fits it to
## the window, `closed` is its X. It changes nothing and so saves nothing.

## The page's X was pressed.
signal closed

## The three attributes, in the order they stand, and the colour of each one's disc.
const ATTRIBUTES := {
	"strength": Palette.BRICK,
	"intelligence": Palette.ICE_DK,
	"dexterity": Palette.LEAF,
}
const DISC_SIDE := 32
const DISC_BORDER := 2
const DISC_GAP := 16
const PORTRAIT_SCALE := 2
## The header card's padding and the air between its portrait and its lines.
const CARD_PAD := 4
const CARD_GAP := 8

var inventory: Inventory
var _ui_scale: float
var _panel: VBoxContainer
var _rows: VBoxContainer


func _init(player_inventory: Inventory, ui_scale: float) -> void:
	inventory = player_inventory
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel(CharacterPanel.PLAYER_NAME, "Close", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	# Scrolled, like the log: a late set carries more stats than a 648 px window holds.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.body_of(_panel).add_child(scroll)
	_rows = UITheme.vbox(BountyList.ROW_GAP, BagPage.WIDTH)
	scroll.add_child(_rows)
	open()


## Redraws the page: who, then the attributes, then the rest as a table.
func open() -> void:
	UITheme.clear(_rows)
	var totals := inventory.stats()
	_rows.add_child(_who())
	_rows.add_child(UITheme.label("Attributes", Palette.SLATE))
	var discs := HBoxContainer.new()
	discs.alignment = BoxContainer.ALIGNMENT_CENTER
	discs.add_theme_constant_override("separation", DISC_GAP)
	for stat: String in ATTRIBUTES:
		discs.add_child(_disc(stat, float(totals.get(stat, 0.0))))
	_rows.add_child(discs)

	_rows.add_child(UITheme.label("Stats", Palette.SLATE))
	# A framed block of its own: the page's row gap is for cards, and would pull a table apart.
	var table := PanelContainer.new()
	table.add_theme_stylebox_override("panel", BountyList.flat(Color.TRANSPARENT, 1))
	var body := UITheme.vbox(0)
	table.add_child(body)
	_rows.add_child(table)
	for stat: String in LootTable.STAT_LABELS:
		var value := float(totals.get(stat, 0.0))
		if ATTRIBUTES.has(stat) or value <= 0.0:
			continue
		body.add_child(UITheme.table_row(LootTable.STAT_LABELS[stat], LootTable.stat_value(stat, value),
				body.get_child_count() % 2 == 1, 0.0, Palette.SLOT_TAN_DK, Palette.INK))
	# Already inside the damage figure above, and nothing else on the page says where it came from.
	if inventory.collection_bonus() > 0:
		body.add_child(UITheme.table_row("Collection", "+%d%% Damage" % inventory.collection_bonus(),
				body.get_child_count() % 2 == 1, 0.0, Palette.SLOT_TAN_DK, Palette.SLATE))


## The card at the head of the page: the portrait on a socket, and beside it the level, the
## experience towards the next as the bounty's own bar, and the kills.
func _who() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", BountyList.flat(Color.TRANSPARENT, CARD_PAD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", CARD_GAP)
	card.add_child(row)
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
	var heading := HBoxContainer.new()
	var level := UITheme.label("Level %d" % inventory.level)
	level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(level)
	var kills := UITheme.label("%d kills" % inventory.kills, Palette.SLATE, true)
	kills.size_flags_vertical = Control.SIZE_SHRINK_END
	heading.add_child(kills)
	lines.add_child(heading)
	# What the card has left once the socket, the gap and both paddings are paid for.
	var bar_width: float = BagPage.WIDTH - portrait.custom_minimum_size.x - CARD_GAP - CARD_PAD * 4 - 2
	lines.add_child(BountyList.progress_bar(inventory.xp, PlayerLevel.xp_to_next(inventory.level), bar_width))
	lines.add_child(UITheme.label("Experience", Palette.SLATE, true))
	row.add_child(lines)
	return card


## One attribute: its total on a disc of its colour, its name under it.
func _disc(stat: String, value: float) -> VBoxContainer:
	var column := UITheme.vbox(2)
	var disc := PanelContainer.new()
	var box := StyleBoxFlat.new()
	box.bg_color = ATTRIBUTES[stat]
	box.border_color = (ATTRIBUTES[stat] as Color).darkened(0.4)
	box.set_border_width_all(DISC_BORDER)
	box.set_corner_radius_all(DISC_SIDE / 2)
	# Hard edges: a smoothed disc beside pixel art reads as a different game.
	box.anti_aliasing = false
	disc.add_theme_stylebox_override("panel", box)
	disc.custom_minimum_size = Vector2(DISC_SIDE, DISC_SIDE)
	disc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Bone with an ink outline, as the numbers over the map are: it has to read on all three colours.
	var number := UITheme.label(BigNumber.format(roundf(value)), Palette.BONE)
	number.name = stat
	number.add_theme_color_override("font_outline_color", Palette.INK)
	number.add_theme_constant_override("outline_size", 4)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	disc.add_child(number)
	column.add_child(disc)
	var label := UITheme.label(LootTable.STAT_LABELS[stat], Palette.SLATE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return column


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x, get_viewport_rect().size.y / _ui_scale)
	_panel.position = Vector2.ZERO
