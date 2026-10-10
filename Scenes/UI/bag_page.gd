class_name BagPage
extends Control
## The bag against the left edge, with the character sheet standing beside it and the orb tray at its
## foot. Showing or hiding this node opens or closes all of it. Design notes in Scenes/DESIGN.md.
##
## Children, in draw order: the bag panel, the sheet, then the orb card, which overhangs the sheet.

## The bag's X was pressed.
signal closed
## The piece the bag has open changed, bag item or worn, and null when it went back to the grid.
## Whoever is standing beside the bag acts on what is open in it -- the blacksmith's counter does.
signal selection_changed(item: Item)
## `orb` went into a piece, ordinary or super. The main scene lights the hover card with it
## (`ItemCard.shine`), the card being where the piece is read.
signal crafted(orb: String)
## The page has measured itself again, and `column_origin` may have moved: the sheet beside the bag
## comes, goes and changes face with what is open.
signal laid_out
## The orb in hand changed, "" for none. The town page greys its shelf by it, as the grid is greyed.
signal held_changed(orb: String)
## A piece was made an heirloom, which only a transcension's page can do (`TranscendPage`).
signal heirloom_made(item: Item)

## Four squares to a row: the narrowest a level's heading fits with its Auto and Clear marks beside
## it. The gutter is the pack's own seven-to-one square-to-gutter proportion.
const GRID_COLS := 4
const SLOT_GAP := ItemSlot.SIDE / 7
## Fixed, so the panel keeps its width as the bag fills.
## The marks on a level's two buttons, and how far Auto's face is darkened while it is held down.
## Bare on the cream, so the pack's own brown cut of each mark; Auto's struck-through chest turns green while it
## is on, as the pack turns its open tab green.
const AUTO_ICON := "res://Assets/UI/ui_icon_auto_brown.png"
const AUTO_ON_ICON := "res://Assets/UI/ui_icon_auto_green.png"
const CLEAR_ICON := "res://Assets/UI/ui_icon_trash_brown.png"
const SELL_ICON := "res://Assets/UI/ui_icon_coins_brown.png"
const COUNT_ICON := "res://Assets/UI/ui_icon_chest_brown.png"
const SWAP_ICON :="res://Assets/UI/ui_icon_swap.png"
## Hide points back at the bag the doll folds into, Show out to where it opens.
## The filter's folder tabs over the grid (the user's pick of tools/qa/bag_filter_m1_b.png, 2026-10-07):
## "" for everything, then each `LootTable.slot_of`, with its mark and its name -- the skill stones'
## last (the user's, 2026-10-09). The town page's tabs, `FILTER_TAB` wide -- the least a mark and the face's
## margins come to -- and `FILTER_GAP` apart, so nine stand in `WIDTH`.
const FILTERS := {
	"": ["slot_all", "All items"],
	"weapon": ["sword", "Weapons"],
	"offhand": ["slot_offhand", "Offhands"],
	"helmet": ["slot_helmet", "Helmets"],
	"body": ["slot_body", "Body armour"],
	"boots": ["slot_boots", "Boots"],
	"ring": ["slot_ring", "Rings"],
	"amulet": ["slot_amulet", "Amulets"],
	SkillTree.SLOT: ["slot_stone", "Skill nodes"],
}
const FILTER_MARK := "res://Assets/UI/ui_icon_%s_%s.png"
const FILTER_TAB := 18
const FILTER_GAP := 1
const HIDE_ICON := "res://Assets/UI/ui_icon_caret_left.png"
const SHOW_ICON := "res://Assets/UI/ui_icon_caret_right.png"
## An orb taking to a piece, a super orb's included -- its knock and its swell together, the user's
## pairing; one that has nothing to do to it is silent.
const ORB_APPLIED_SOUNDS := [preload("res://Sounds/Sfx/orb_applied.ogg"),
		preload("res://Sounds/Sfx/orb_applied_layer.ogg")]
## A piece put on or taken off.
const EQUIP_SOUND := preload("res://Sounds/Sfx/equip.ogg")
## What goes in front of a question's id in `inventory.tips` once the player has said not to ask it
## again, how wide the question is set, and its tick box: the node's name and the mark it wears.
const SKIP_CONFIRM := "skip_confirm_"
## The one question whose tick is remembered in `Settings.uniques` as the answer given, not in the save.
const UNIQUES := "uniques"
const CONFIRM_WIDTH := 150.0
const TICK_NAME := "Tick"
## What a question's panel is called inside its holder, which the win's wash would otherwise push off
## child 0 -- and which is how `_place_confirm` and the shrink find it.
const CONFIRM_PANEL := "Panel"
const TICK: Array[String] = [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
]
## A square's upgrade arrow (`is_upgrade`): leaf over an ink outline, so it reads on any frame; and
## the child's name, which is how a test finds it.
const UPGRADE: Array[String] = [
	"...o...",
	"..o#o..",
	".o###o.",
	"o#####o",
	"oo###oo",
	".o###o.",
	".ooooo.",
]
const UPGRADE_NAME := "Upgrade"
static var _upgrade_texture: ImageTexture
## The chevron in the middle of the tray's rule, there once the runes are (`_trays_hidden`): pointing down
## while the runes and the orbs stand under it, up while they are folded away.
const CHEVRON: Array[String] = [
	"#.....#",
	"##...##",
	".##.##.",
	"..###..",
	"...#...",
]
static var _chevrons: Array[ImageTexture] = []
## How many squares short of the cap the count turns rust.
const NEARLY_FULL := 4
const WIDTH := GRID_COLS * ItemSlot.SIDE + (GRID_COLS - 1) * SLOT_GAP
## All six orbs in one row across WIDTH; the whole-pixel gap leaves under a gap's worth of slack,
## which the centred tray splits (test_ui_theme holds the arithmetic).
const ORB_COLS := 6
const ORB_GAP := (WIDTH - ORB_COLS * OrbSlot.SIDE) / (ORB_COLS - 1)
## How far a press may travel, in panel pixels, and still be a click rather than a drag.
const DRAG_THRESHOLD := 4.0
## The outline round the square a dragged piece would drop into (`_process`): the gold the tree's lit
## lines are drawn in, a pixel outside the square so it hides none of it; and the node's name, which is
## how a test finds it.
const DROP_MARK := Palette.GOLD
const DROP_MARK_NAME := "DropMark"

const DOLL_TEXTURE := preload("res://Assets/UI/ui_doll.png")
const SOCKET_RING_TEXTURE := preload("res://Assets/UI/ui_socket_ring.png")
const SOCKET_AMULET_TEXTURE := preload("res://Assets/UI/ui_socket_amulet.png")
## The doll is drawn at the item icons' own pixel size: a 128 px figure (`tools/ui_kit.py`'s `doll()`) standing
## where the pack's 43x46 one stood at 3x.
const DOLL_SCALE := 1.0
## The air between the bag panel and the sheet.
const WORN_GAP := 6.0
## How much of the window's height the bag takes on a transcension's black screen.
const TRANSCEND_HEIGHT := 0.7
## How many rows of the grid a room held upright has to leave showing (`least_height`).
const LEAST_ROWS := 2
## Each socket's centre in the doll sprite's own pixels, before DOLL_SCALE. The places the pack's figure had
## at 3x, kept when the pixellab doll replaced it (2026-09-23), which was generated and fitted to sit under them:
## head, chest and feet down the middle, the shield at the left edge and the sword hand at the right. The
## jewellery sits in a row below the figure. Rows and columns are one 51 px grid.
const DOLL_SOCKETS := {
	Equipment.Socket.HELMET: Vector2(63, 24),
	Equipment.Socket.OFFHAND: Vector2(12, 75),
	Equipment.Socket.BODY: Vector2(63, 75),
	Equipment.Socket.WEAPON: Vector2(114, 75),
	Equipment.Socket.BOOTS: Vector2(63, 126),
	Equipment.Socket.RING_LEFT: Vector2(12, 177),
	Equipment.Socket.AMULET: Vector2(63, 177),
	Equipment.Socket.RING_RIGHT: Vector2(114, 177),
}

## Whose grid and whose doll this page is: the player's inventory, or -- on the heirlooms' page --
## the stash inside it (`Inventory.stash`), which is an inventory too and so needs no second page.
var inventory: Inventory
## The player's inventory whichever page this is: the purse, the orbs, the tips, the super orbs, and the
## one thing that is ever saved. The same object as `inventory` on the ordinary bag.
var _purse: Inventory
## Whether this is the heirlooms' page. An heirloom is not sold, not thrown away by the level and not
## filtered as it arrives; thrown away one at a time it is, and that always asks first.
var _heirlooms := false
## Whether this page stands on the black screen of a transcension (`TranscendPage`) rather than
## against the left edge: centred, written to no file -- the whole transcension is one write, made
## when it is over -- and there for one thing. Over the bag that is choosing the piece to keep, so a
## selected piece gets no Equip and no Discard and **Make heirloom** stands at the foot in the tray's
## place; over the heirlooms it is the super orbs (`SuperOrbTable`), which are the tray.
var _transcending := false
## Whether this is the black screen's skill stones page (`TranscendPage`): only the stones in the bag,
## the ordinary orbs left over in the tray, and the skill tree in the doll's place, where a stone open in
## the bag is placed (`_show_tree`).
var _stones := false
## Its skill tree's zoom (`SkillTreeView.zoom`), kept while the page draws the tree again.
var _tree_zoom := 0
var _make_button: Button
var _save_path: String
var _ui_scale: float

## What the counter the bag is standing at buys, by `TownServices` name -- the town page's open tab
## and not everything the town offers, so only the gear merchant turns Discard into Sell. Empty
## everywhere else. Orbs are never bought back: the tray is crafting alone at every counter.
var _services: PackedStringArray = []

var _panel: VBoxContainer
var _filter_tabs: HBoxContainer
## Which of `FILTERS` the grid shows. Kept while the game runs, never saved.
var _filter := ""
var _count: Label
var _gold: Label
var _scroll: ScrollContainer
## One heading, rule and grid per level, highest first. Each square carries its item's `bag_index`.
var _sections: VBoxContainer
## The buttons beside the selected square (Equip and Sell or Discard; Unequip on a doll socket), a
## cream card placed by `ItemCard.beside` and following the grid as it scrolls (`_place_actions`).
## The square says what it is through the hover card; the card beside it only says what can be done.
var _actions: PanelContainer
var _action_box: VBoxContainer
## The selected bag item as an index into `inventory.items`, or -1. At most one of this and
## `_worn_selected` is set: both darken their square and stand `_actions` beside it.
var _selected := -1
## Each piece's rarity when the bag was last sorted (Item -> rarity), which the grid sorts by: an orb
## that lifts a piece leaves it where the cursor is until the bag is shut or a town's tab changes.
var _sorted_as := {}
## The open worn piece as an `Equipment.Socket`, or -1.
var _worn_selected := -1
## Which of the sockets the selected piece fits is the one Equip fills: an index into `sockets_for`,
## moved by the Swap beside a ring and back to the emptiest with every new selection.
var _socket_pick := 0
## The doll put away, leaving `_show_button` in its place. Kept for the session, not saved.
var _doll_hidden := false
## Stands against the bag's edge where the hidden doll was, and brings it back.
var _show_button: Button
var _drag_from := Vector2.ZERO
var _drag_scroll := 0
var _dragged := 0.0

var _worn_panel: PanelContainer
var _worn_body: VBoxContainer
## The doll, while the sheet is not folded away.
var _doll: Control
## The stones page's tree, in the doll's place, or null.
var _tree: SkillTreeView

## The question standing over the page (`_ask`), or null.
var _confirm: Control

## The rule over the tray, `_fold_button` in its middle.
var _orb_rule: HBoxContainer
var _fold_button: Button
## The runes and the orbs folded away under the grid by the chevron. Kept for the session, not saved.
var _trays_hidden := false
## The six runes over the orbs, once one has been found: picked up as an orb is, and pressed on a tile of
## the map rather than a piece (`rune_on`). The ordinary bag's alone.
var _rune_tray: HBoxContainer
var _orb_tray: HBoxContainer
var _orb_card: OrbCard
## What a spent orb rolls with. Unseeded: a test that wants a known answer seeds it.
var _craft_rng := RandomNumberGenerator.new()
## The orb pressed with no piece open, or "". The next square or worn socket pressed is crafted with
## it where it lies, unopened, and it stays held while any are left. Opening a piece, a press on
## anything but a piece or the tray (`_input`), the same orb again, Escape, a right click or the bag
## going away puts it down. While it is held it is the cursor, at the 32 px it is cut at -- which is
## the tray's 16 at `ui_scale` 2.
var _armed := "":
	set(orb):
		if orb == _armed:
			return
		_armed = orb
		var mark: Texture2D = null if orb == "" else SuperOrbTable.icon(orb) if SuperOrbTable.has(orb) \
				else RuneTable.icon(orb) if RuneTable.has(orb) else OrbTable.icon(orb)
		# A rune's mark is made at the tray's 16, an orb's cut at 32.
		Cursors.hold(mark, 2 if RuneTable.has(orb) else 1)
		held_changed.emit(orb)

## A left press off any piece put the held orb down, and the bag waits for its release to redraw.
var _put_down := false
## The piece on the cursor (`_lift`) until the drag ends, or null: the doll's sockets and the tree's
## slots it cannot go in are dimmed for it.
var _lifted: Item
## The outline on the square `_lifted` would drop into, or null.
var _drop_mark: Panel


func _init(player_inventory: Inventory, save_path: String, ui_scale: float, heirlooms := false,
		transcending := false, stones := false) -> void:
	_purse = player_inventory
	_heirlooms = heirlooms
	_transcending = transcending
	_stones = stones
	inventory = player_inventory.stash() if heirlooms else player_inventory
	_save_path = save_path
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Skill nodes" if _stones else "Heirlooms" if _heirlooms else "Items",
			"Back" if _transcending else "Close the heirlooms" if _heirlooms
			else "Close the item panel", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var rows := UITheme.body_of(_panel)

	# How full it is and the purse, the two things true of the whole bag, on one line at the top.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SLOT_GAP)
	top.custom_minimum_size = Vector2(WIDTH, 0)
	rows.add_child(top)
	# The corner button's chest in front of the count, so "12 / 40" says what it counts.
	if not _heirlooms:
		var chest := TextureRect.new()
		chest.texture = load(COUNT_ICON)
		chest.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		top.add_child(chest)
	_count = UITheme.label()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var coin := TextureRect.new()
	coin.texture = Coins.icon()
	coin.custom_minimum_size = Vector2(Coins.SIZE, Coins.SIZE)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(coin)
	# Slate rather than GOLD: amber on cream is too weak a pairing.
	_gold = UITheme.label("", Palette.TEXT_SOFT)
	top.add_child(_gold)
	_filter_tabs = HBoxContainer.new()
	_filter_tabs.add_theme_constant_override("separation", 0)
	rows.add_child(_filter_tabs)

	# Wheel scrolling is the container's, dragging is `_on_grid_input`'s; no bar is drawn. A worn piece
	# dragged off the doll is dropped here.
	_scroll = UITheme.scroll()
	_scroll.gui_input.connect(_on_grid_input)
	_scroll.set_drag_forwarding(Callable(), _can_drop_in_bag, _drop_in_bag)
	# The buttons beside the selected square move with it.
	_scroll.get_v_scroll_bar().value_changed.connect(func(_at: float) -> void: _place_actions())
	rows.add_child(_scroll)
	_sections = UITheme.vbox(SLOT_GAP, WIDTH)
	_scroll.add_child(_sections)

	# The tray comes after the grid, so it is a footer under it: the rule with the chevron in its middle,
	# then the runes over the orbs.
	_orb_rule = HBoxContainer.new()
	_orb_rule.add_theme_constant_override("separation", 0)
	rows.add_child(_orb_rule)
	for half in 2:
		var line := UITheme.rule()
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_orb_rule.add_child(line)
		if half == 0:
			_fold_button = UITheme.button("", UITheme.BARE_BUTTON, "")
			_fold_button.pressed.connect(_on_trays_pressed)
			_orb_rule.add_child(_fold_button)
	for tray in 2:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", ORB_GAP)
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.custom_minimum_size = Vector2(WIDTH, 0)
		rows.add_child(row)
		if tray == 0:
			_rune_tray = row
		else:
			_orb_tray = row
	if _transcending and not _heirlooms and not _stones:
		_make_button = UITheme.button("Make heirloom", "LightButton", "")
		_make_button.pressed.connect(_on_make_pressed)
		rows.add_child(_make_button)

	_worn_body = UITheme.vbox(SLOT_GAP)
	_worn_panel = PanelContainer.new()
	_worn_panel.theme_type_variation = "WoodPanel"
	_worn_panel.scale = Vector2(_ui_scale, _ui_scale)
	_worn_panel.add_child(_worn_body)
	add_child(_worn_panel)
	_show_button = UITheme.icon_button(load(SHOW_ICON), "Show what is equipped", _ui_scale)
	_show_button.pressed.connect(_on_fold_pressed)
	_show_button.hide()
	add_child(_show_button)

	# After the bag and the sheet, over whichever holds the selected square.
	_actions = PanelContainer.new()
	_actions.theme_type_variation = "TextPanel"
	_actions.scale = Vector2(_ui_scale, _ui_scale)
	_actions.hide()
	_action_box = UITheme.vbox(2)
	_actions.add_child(_action_box)
	add_child(_actions)

	# After the sheet: it hangs over the sheet for most of the tray, and tree order decides who is on top.
	_orb_card = OrbCard.new()
	_orb_card.scale = Vector2(_ui_scale, _ui_scale)
	_orb_card.hide()
	add_child(_orb_card)

	# However the bag goes away -- its X, another page, a fight -- an orb must not stay on the cursor.
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_armed = ""
			_sorted_as.clear())
	refresh()


## Opens on the grid, never on a stat block left over from last time, and sorted afresh (a town's
## tab changing comes through here too, by `shop`).
func open() -> void:
	_sorted_as.clear()
	_close_confirm()
	_selected = -1
	_worn_selected = -1
	_armed = ""
	refresh()


## Stands the bag at a counter that buys `services`, or takes it away from one with none. The bag is
## where a sale happens rather than a second grid on the town page: what the player wants to sell is
## already laid out here, and two grids of the same items is two places to hunt through.
func shop(services: PackedStringArray) -> void:
	_services = services
	open()


## The counter beside the bag opened a piece off its shelf, or put it back, or sold it: the purse,
## the grid and the tray are all redrawn by the same call. The bag draws nothing of the piece itself;
## what wearing it would replace is read off the hover card under Alt, as for any square.
func offer(_item: Item) -> void:
	refresh()


## Whether the town the bag is standing in buys this. False everywhere outside one.
func _buys(service: String) -> bool:
	# No counter buys an heirloom, so beside one Discard stays Discard and a level has no coins.
	if _heirlooms and service == TownServices.GEAR:
		return false
	return service in _services


func refresh_gold() -> void:
	_gold.text = BigNumber.format(_purse.gold)


## Where the main scene stands the page, in window pixels: empty for the whole window. Held upright in a
## town, the foot of it, under the counter.
var area := Rect2()


## The bag stretched to its room's height, and the sheet centred against its right edge. At a
## transcension the two stand in the middle of the window instead, the bag `TRANSCEND_HEIGHT` of it.
## Where the room is too narrow for the sheet beside the bag (a phone held upright), it stands over it.
func layout() -> void:
	var room := area if area.has_area() else get_viewport_rect()
	_worn_panel.size = _worn_panel.get_combined_minimum_size()
	_show_button.size = _show_button.get_combined_minimum_size()
	if UITheme.narrow(get_viewport_rect().size, _ui_scale):
		_sheet(room)
	else:
		_side_by_side(room, _panel.get_combined_minimum_size().x)
	_place_actions()
	_place_confirm()
	laid_out.emit()


## The bag against the room's left edge (centred on a transcension's screen) and the sheet or its caret
## beside it, the sheet centred down the room.
func _side_by_side(room: Rect2, width: float) -> void:
	_panel.size = Vector2(width, room.size.y / _ui_scale - 2 * UITheme.EDGE)
	_panel.position = room.position + Vector2.ONE * UITheme.EDGE * _ui_scale
	var beside: Control = (_worn_panel if _worn_panel.visible
			else _show_button if _show_button.visible else null)
	var both := width + (0.0 if beside == null else WORN_GAP + beside.get_combined_minimum_size().x)
	if _transcending:
		_panel.size.y = _transcend_height(room)
		_panel.position = (room.position + (room.size - Vector2(both, _panel.size.y) * _ui_scale) / 2.0).floor()
	_worn_panel.position = Vector2(_panel.position.x + (_panel.size.x + WORN_GAP) * _ui_scale,
			room.position.y + (room.size.y - _worn_panel.size.y * _ui_scale) / 2.0)
	if _stones:
		# The tree's panel is the bag's twin: level with it and as tall.
		_worn_panel.position.y = _panel.position.y
		_worn_panel.size.y = maxf(_worn_panel.size.y, _panel.size.y)
	# The caret heads the column of corner buttons that stands beside the page, so it sits at the top.
	_show_button.position = Vector2(_worn_panel.position.x, _panel.position.y + WORN_GAP * _ui_scale)


## Held upright (`UITheme.narrow`): the bag a sheet along the foot of the room (`UITheme.dock`: centred,
## as tall as its grid and never more than half the window), and straight over it the doll's sheet,
## centred too -- or, folded away, the caret that brings it back, over the bag's right end.
func _sheet(room: Rect2) -> void:
	var over: Control = (_worn_panel if _worn_panel.visible
			else _show_button if _show_button.visible else null)
	var lift := 0.0 if over == null else (over.size.y + WORN_GAP) * _ui_scale
	UITheme.dock(_panel, Rect2(room.position.x, room.position.y + lift, room.size.x, room.size.y - lift),
			_ui_scale, UITheme.Dock.LEFT, layout)
	_worn_panel.position = Vector2(floorf(room.position.x + (room.size.x - _worn_panel.size.x * _ui_scale) / 2.0),
			_panel.position.y - lift)
	_show_button.position = _panel.position + Vector2((_panel.size.x - _show_button.size.x) * _ui_scale, -lift)


## The least height, in window pixels, the page needs held upright: the bag with `LEAST_ROWS` rows of
## its grid showing, and the sheet over it. A town gives its counter what is left (`_layout_ui`).
func least_height() -> float:
	var tall := _panel.get_combined_minimum_size().y + LEAST_ROWS * (ItemSlot.SIDE + SLOT_GAP) + 2 * UITheme.EDGE
	if _worn_panel.visible:
		tall += _worn_panel.get_combined_minimum_size().y + WORN_GAP
	return tall * _ui_scale


## Where a column of buttons beside the page begins, in window pixels: `gap` past the sheet beside
## the bag and level with its top; under the caret that brings the sheet back, in line with it; or
## `gap` past the bag itself at `top` where there is neither.
func column_origin(gap: float, top: float) -> Vector2:
	if _worn_panel.visible:
		return Vector2(_worn_panel.position.x + (_worn_panel.size.x + gap) * _ui_scale,
				_worn_panel.position.y)
	if _show_button.visible:
		return Vector2(_show_button.position.x,
				_show_button.position.y + (_show_button.size.y + gap) * _ui_scale)
	return Vector2(_panel.position.x + (_panel.size.x + gap) * _ui_scale, top)


## The bag panel's top-left corner in window pixels: the origin but on a transcension's screen, where
## `TranscendPage` stands its way back beside it.
func panel_corner() -> Vector2:
	return _panel.position


## Everything redrawn from the inventory, reopening whatever was open.
func refresh() -> void:
	# Cleared at once: the click hit-test walks these children, and a queued square is still one.
	UITheme.clear(_sections)
	var by_level := {}
	for item in inventory.items:
		if not _sorted_as.has(item):
			_sorted_as[item] = item.rarity
	for i in inventory.order(_sorted_as):
		if _shows(inventory.items[i]):
			by_level.get_or_add(inventory.items[i].level, []).append(i)
	_fill_tabs()
	for level: int in inventory.levels():
		# Under a filter a level holding nothing of its slot is left out -- but never one holding nothing at all.
		if not by_level.has(level) and inventory.count_at(level) > 0:
			continue
		_sections.add_child(_section_heading(level))
		# A level with a rule and no items keeps its heading, the only place the rule can be undone.
		if not by_level.has(level):
			continue
		var grid := GridContainer.new()
		grid.columns = GRID_COLS
		grid.add_theme_constant_override("h_separation", SLOT_GAP)
		grid.add_theme_constant_override("v_separation", SLOT_GAP)
		_sections.add_child(grid)
		for i: int in by_level[level]:
			var slot := ItemSlot.make(inventory.items[i], i == _selected)
			slot.set_meta("bag_index", i)
			if not _bag_keys().is_empty():
				slot.set_meta(ItemCard.KEYS, _bag_keys())
			if i == _selected:
				slot.set_meta(ItemCard.BESIDE, _actions)
			_dim_for_orb(slot, inventory.items[i])
			# Not on the way out of a world: there the bag is only being chosen from.
			if not _transcending and is_upgrade(inventory.items[i], inventory):
				slot.add_child(_upgrade_mark())
			grid.add_child(slot)
	_count.text = ("%d to spend" % _purse.super_orbs if _heirlooms and _transcending
			else "" if _heirlooms
			else "%d / %d" % [inventory.total(), inventory.capacity()])
	# Rust a few squares early: a full bag is a fight throwing finds away, and that should be seen coming.
	_count.add_theme_color_override("font_color", Palette.RUST
			if not _heirlooms and inventory.total() >= inventory.capacity() - NEARLY_FULL
			else Palette.TEXT_SOFT)
	refresh_gold()
	refresh_orbs()
	_refresh_make()
	_refresh_worn()
	UITheme.clear(_action_box)
	if _selected >= 0 and _selected < inventory.total():
		_show_item(_selected)
	elif _worn_selected >= 0 and inventory.equipment.item_at(_worn_selected) != null:
		_show_worn(_worn_selected)
	# Placed once the buttons have measured themselves.
	_place_actions.call_deferred()


## Whether the filter lets this piece into the grid.
func _shows(item: Item) -> bool:
	if _stones:
		return item.is_stone()
	return _filter.is_empty() or LootTable.slot_of(item.type) == _filter


## The filter's folder tabs, built again with the grid: the open one's face and mark change with it.
## A selected piece the filter hides stays selected (its buttons put away with no square to stand by).
func _fill_tabs() -> void:
	UITheme.clear(_filter_tabs)
	# The stones page is one kind already.
	_filter_tabs.visible = not _stones
	if _stones:
		return
	for slot: String in FILTERS:
		if _filter_tabs.get_child_count() > 0:
			_filter_tabs.add_child(TownPage.tab_line(FILTER_GAP))
		var tab := UITheme.button("", UITheme.BARE_BUTTON, FILTERS[slot][1])
		tab.icon = load(FILTER_MARK % [FILTERS[slot][0], "green" if slot == _filter else "brown"])
		TownPage.tab_faces(tab, slot == _filter, FILTER_TAB)
		tab.pressed.connect(func() -> void:
			_filter = slot
			refresh())
		_filter_tabs.add_child(tab)
	var rest := TownPage.tab_line(0)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_filter_tabs.add_child(rest)


## A level's heading, one line: its name in the body font, the rule running on from it, Auto (a chest struck through,
## which stays down while the level is being thrown away as it drops) and Clear (a bin: drop what is
## held). The name used to be Pixellari over a rule of its own, which cost three levels most of a row.
func _section_heading(level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	# The rule is said in red: the toggle's pressed face is too quiet to read a state off.
	var ruled := inventory.autodiscards(level)
	var title := UITheme.label("Level %d" % level, Palette.BRICK if ruled else Palette.TEXT_SOFT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	var line := UITheme.rule()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(line)
	# An heirloom never arrives by dropping and is never thrown away by the handful: no marks. Nor on
	# the way out of a world, where the bag is only being chosen from.
	if _heirlooms or _transcending:
		return row

	var auto := UITheme.button("", UITheme.BARE_BUTTON,
			("Continue" if ruled else "Stop") + " collecting level %d loot" % level)
	# Held down is a pixel lower -- and green as well, because that pixel alone is a press being
	# watched and not a state being read off a column of headings.
	auto.icon = load(AUTO_ON_ICON if ruled else AUTO_ICON)
	auto.toggle_mode = true
	auto.button_pressed = ruled
	auto.toggled.connect(_on_autodiscard_toggled.bind(level))
	row.add_child(auto)

	# In a town that buys gear the same button sells the handful instead of destroying it: it is the
	# same act -- being done with a level -- and the merchant is simply a better way to do it.
	# What the press would take: a locked piece stays, and so does whatever the filter hides.
	var loose := inventory.items.filter(
			func(item: Item) -> bool: return item.level == level and not item.locked and _shows(item))
	var held := loose.size()
	var selling := _buys(TownServices.GEAR)
	var worth := TownPrices.sell_total(loose) if selling else 0.0
	# A mark either way, coins for selling and a bin for discarding; the tooltip says the sum.
	var things := "item" if held == 1 else "items"
	var clear := UITheme.button("", UITheme.BARE_BUTTON,
			"Sell %d level %d %s for %s gold" % [held, level, things, BigNumber.format(worth)] if selling
			else "Discard %d level %d %s" % [held, level, things])
	clear.icon = load(SELL_ICON if selling else CLEAR_ICON)
	clear.disabled = held == 0
	# Both ask first: a whole level goes in one press, and neither can be taken back.
	if selling:
		clear.pressed.connect(_ask.bind("sell", "Sell all", clear.tooltip_text + "?", "Sell",
				"LightButton", _on_sell_level_pressed.bind(level)))
	else:
		clear.pressed.connect(_ask.bind("clear", "Discard", clear.tooltip_text + "?", "Discard",
				"LightDangerButton", _on_clear_level_pressed.bind(level)))
	row.add_child(clear)
	return row


## Asks before `deed` is done, over everything else on the page, unless the player has ticked this
## question's "Don't show this again" -- which is kept per question (`id`) in `inventory.tips`, the
## save's list of what the player has already been told, and only a Yes writes it (`_remember`, where
## the `UNIQUES` question keeps either answer instead). `can_skip` false is a question that is asked
## every time and offers no tick: an heirloom is runs of work. `no` is the first button's face.
func _ask(id: String, title: String, question: String, verb: String, variation: String,
		deed: Callable, can_skip := true, no := "Cancel") -> void:
	if can_skip and SKIP_CONFIRM + id in _purse.tips:
		deed.call()
		return
	_close_confirm()
	# The whole window, so nothing under the question can be pressed while it is up.
	_confirm = Control.new()
	_confirm.size = get_viewport_rect().size
	add_child(_confirm)
	# Over every other page too: held upright the town's counter stands over the bag, and the question
	# is centred across both.
	move_to_front()
	# No X, as a reward's panel has none: its buttons and Escape are the way out.
	var panel := UITheme.titled_panel(title, "", Callable())
	panel.name = CONFIRM_PANEL
	_confirm.add_child(panel)
	var body := UITheme.body_of(panel)
	var asked := UITheme.label(question, null, true)
	asked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asked.custom_minimum_size.x = CONFIRM_WIDTH
	body.add_child(asked)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", SLOT_GAP)
	body.add_child(buttons)
	var skip := check_box("Don't show this again")
	var ticked := func() -> bool: return (skip.get_node(TICK_NAME) as Button).button_pressed
	for made: Button in [UITheme.button(no, "LightButton", ""), UITheme.button(verb, variation, "")]:
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(made)
	buttons.get_child(0).pressed.connect(func() -> void:
		_remember(id, ticked.call(), false)
		_close_confirm())
	buttons.get_child(1).pressed.connect(func() -> void:
		_remember(id, ticked.call(), true)
		_close_confirm()
		deed.call())
	# Built either way, so the Yes above has a tick to read; only shown where it may be ticked.
	skip.visible = can_skip
	body.add_child(skip)
	Juice.popup(_confirm, panel, _ui_scale)


## A ticked "Don't show this again". The uniques' question keeps the answer given -- Sell or Keep --
## in the settings, where it can be changed back; every other question only ever stops being asked,
## on a Yes, in the save (written by the deed's own save). Escape and the X read no tick.
func _remember(id: String, ticked: bool, yes: bool) -> void:
	if not ticked:
		return
	if id == UNIQUES:
		Settings.uniques = Settings.Uniques.SELL if yes else Settings.Uniques.KEEP
		Settings.save()
	elif yes:
		_purse.tips.append(SKIP_CONFIRM + id)


## The window was resized under a question: the holder is made to cover it again and the question put
## back in its middle. `Juice.popup` keeps it there as its contents settle.
func _place_confirm() -> void:
	if _confirm == null:
		return
	_confirm.size = get_viewport_rect().size
	Juice.centre(_confirm.get_node(CONFIRM_PANEL), _confirm.size)


## Escape on a question is its Cancel, and the press stops here: the page under it stays up. With no
## question up the key is left for the main scene, which closes the pages.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	if _confirm != null:
		get_viewport().set_input_as_handled()
		_close_confirm()
	elif _armed != "":
		# A held orb is put down the same way, and the bag stays up.
		get_viewport().set_input_as_handled()
		_armed = ""
		refresh()
	elif _open_piece() != null:
		# And so is a selected piece: one press clears it, the next closes the bag.
		get_viewport().set_input_as_handled()
		_select_item(-1)


## A right click anywhere puts a held orb down, as Escape does, and so does a left press on anything
## but a piece or the tray -- the map, a button, bare panel -- which still goes on to do its own work:
## so that press is not redrawn under (a heading's button freed before its release lands), and the
## bag is redrawn once the release has been and gone (`_put_down`). Not under a question, whose Use
## spends the orb. `_input` rather than `_unhandled_input`: a press over a panel is handled by the
## panel and would never reach the other.
func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	if _put_down and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_put_down = false
		refresh.call_deferred()
	if _armed == "" or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_armed = ""
		refresh()
	elif event.button_index == MOUSE_BUTTON_LEFT and _confirm == null \
			and ItemCard.square_at(get_tree(), event.position) == null and not _over_tray(event.position) \
			and not (RuneTable.has(_armed) and _off_the_bag()):
		# A rune goes on the map: a press on bare map is the map's (`rune_on`), and keeps it in hand.
		_armed = ""
		_put_down = true


## Whether the cursor is on nothing of this page's: bare map, or the tile panel a finger's first tap on
## a tile puts up over the bag (the main scene's `_on_cell_aimed`), whose X goes back to the bag with the
## rune still in hand.
func _off_the_bag() -> bool:
	var over := get_viewport().gui_get_hovered_control()
	return over == null or not is_ancestor_of(over)


func _over_tray(at: Vector2) -> bool:
	return (_orb_tray.get_children() + _rune_tray.get_children()).any(func(orb: Control) -> bool:
		return orb.is_visible_in_tree() and orb.get_global_rect().has_point(at))


## Whether one of the page's questions stands over the window, for a banner to wait behind.
func asking() -> bool:
	return _confirm != null


## The question shrinks away, as a reward's panel does, then goes. It is let go of at once, so a deed
## that follows an answer -- or the next question -- never finds the old one in its way.
func _close_confirm() -> void:
	if _confirm == null:
		return
	var holder := _confirm
	_confirm = null
	Juice.pop_out(holder.get_node(CONFIRM_PANEL), holder.queue_free)


## A tick box as the rest of the interface would draw one: the brown button face, small, held down
## with a cream tick on it while it is on -- the way Auto holds. The row's words press it too. Named
## `TICK_NAME` so whoever wants its state (`_ask`, a test) can find it.
static func check_box(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	var marks: Array[ImageTexture] = []
	for ticked: bool in [false, true]:
		# The blank is the tick's size, so the face does not change size as it is pressed.
		var image := Image.create(TICK[0].length(), TICK.size(), false, Image.FORMAT_RGBA8)
		for y in TICK.size() if ticked else 0:
			for x in TICK[y].length():
				if TICK[y][x] == "#":
					image.set_pixel(x, y, UITheme.FONT_COLOR)
		marks.append(ImageTexture.create_from_image(image))
	var box := UITheme.button("", "BrownIconButton", "")
	box.name = TICK_NAME
	box.toggle_mode = true
	box.icon = marks[0]
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.toggled.connect(func(on: bool) -> void: box.icon = marks[int(on)])
	row.add_child(box)
	var words := UITheme.label(text, null, true)
	words.mouse_filter = Control.MOUSE_FILTER_STOP
	words.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			box.button_pressed = not box.button_pressed)
	row.add_child(words)
	return row


## Touches nothing already held: that is Clear's job.
func _on_autodiscard_toggled(on: bool, level: int) -> void:
	inventory.set_autodiscard(level, on)
	_save()
	_select_item(-1)


func _on_clear_level_pressed(level: int) -> void:
	_drop_level(level, false)


func _on_sell_level_pressed(level: int) -> void:
	_drop_level(level, true)


## The level's ordinary pieces go at once. Its uniques go with them under the settings' Sell, stay
## under Keep, and under Ask are a second question of their own, naming them -- whose Don't sell (or
## Escape, or the X) leaves them where they are, and whose tick keeps the answer given (`_remember`).
func _drop_level(level: int, selling: bool) -> void:
	var deed := _sell_level if selling else _clear_level
	deed.call(level, Settings.uniques == Settings.Uniques.SELL)
	var uniques := inventory.items.filter(func(item: Item) -> bool:
		return item.level == level and item.rarity == ItemRarity.Rarity.UNIQUE and not item.locked and _shows(item))
	if Settings.uniques != Settings.Uniques.ASK or uniques.is_empty():
		return
	var names := ", ".join(uniques.map(func(item: Item) -> String: return item.display_name()))
	var question := "%s %s unique. %s %s as well?" % [names, "is" if uniques.size() == 1 else "are",
			"Sell" if selling else "Discard", "it" if uniques.size() == 1 else "them"]
	_ask(UNIQUES, "Uniques", question, "Sell" if selling else "Discard",
			"LightButton" if selling else "LightDangerButton", deed.bind(level, true), true,
			"Don't sell" if selling else "Don't discard")


func _clear_level(level: int, uniques: bool) -> void:
	var gone := inventory.discard_level(level, uniques, _filter)
	print("Discarded %d item(s) at level %d" % [gone.size(), level])
	# The Rag and Bone Sack pays for what is thrown away, which is nothing unless it is worn.
	for item: Item in gone:
		_purse.gold += _purse.salvage(item)
		_purse.add_orb(_purse.salvage_orb())
	_purse.tick("discarded", gone.size())
	_save()
	_select_item(-1)


## A whole level over the counter. The price is summed off what `discard_level` hands back, so the
## purse is paid for exactly what left the bag rather than for what was in it a moment ago.
func _sell_level(level: int, uniques: bool) -> void:
	var gone := inventory.discard_level(level, uniques, _filter)
	var paid := TownPrices.sell_total(gone)
	_purse.sell_for(paid)
	print("Sold %d item(s) at level %d for %s gold"
			% [gone.size(), level, BigNumber.format(paid)])
	_save()
	_select_item(-1)


## A press that stays put clicks the square under it; one that travels drags the list. The squares
## ignore the mouse so a drag starting on one still reaches here.
func _on_grid_input(event: InputEvent) -> void:
	Cursors.over_squares(_scroll, event, _armed != "")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position
			_drag_scroll = _scroll.scroll_vertical
			_dragged = 0.0
		elif _dragged < (Cursors.TOUCH_SLOP if Cursors.touched else DRAG_THRESHOLD):
			_on_clicked(event.position + Vector2(0.0, _scroll.scroll_vertical),
					event.shift_pressed, event.ctrl_pressed)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
			and not get_viewport().gui_is_dragging():
		_dragged += event.relative.length()
		# A mouse's press that travels from a piece lifts it; from bare panel, or a finger's, it scrolls.
		var index := _index_at(_drag_from + Vector2(0.0, _drag_scroll)) if _lifts() else -1
		if index < 0:
			_scroll.scroll_vertical = _drag_scroll - int(event.position.y - _drag_from.y)
		elif _dragged >= DRAG_THRESHOLD:
			_lift(inventory.items[index])


## Opens the square under `at` (in the sections' own space), or closes the block on bare panel. Under
## Shift or Ctrl the square is opened and its own button pressed for it (`_press_action`).
func _on_clicked(at: Vector2, shift := false, ctrl := false) -> void:
	var index := _index_at(at)
	if index < 0:
		_select_item(-1)
	elif _armed != "":
		_orb_on(inventory.items[index])
	elif shift or ctrl:
		_select_item(index)
		_press_action(shift)
	else:
		_select_item(-1 if index == _selected else index)


## The bag index of the square under `at` (in the sections' own space), or -1 on bare panel.
func _index_at(at: Vector2) -> int:
	for section: Node in _sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Control in section.get_children():
			if Rect2((section as Control).position + slot.position, slot.size).has_point(at):
				return slot.get_meta("bag_index", -1)
	return -1


## Whether a press that travels from a piece lifts it (`_lift`) rather than scrolling: a mouse's alone,
## since a finger's drag is the only scroll it has; never with an orb in the hand, nor on the bag a
## transcension only chooses from, where a piece has nowhere to go.
func _lifts() -> bool:
	return not Cursors.touched and _armed == "" and not (_transcending and not _heirlooms and not _stones)


## `item` onto the cursor, its own square centred under it, for the doll, the bag or the stones page's
## tree to take (`set_drag_forwarding` on each). Whatever was open shuts, so no buttons stand beside a
## piece being dragged (the user's, 2026-10-09: they are a click's), and what cannot take it is dimmed
## until the drag ends (`_lifted`). The square leaves `ItemSlot.GROUP`, or the hover card would read it
## rather than whatever it is held over.
func _lift(item: Item) -> void:
	var square := ItemSlot.make(item)
	square.remove_from_group(ItemSlot.GROUP)
	square.scale = Vector2(_ui_scale, _ui_scale)
	square.position = -Vector2.ONE * ItemSlot.SIDE * _ui_scale / 2.0
	var preview := Control.new()
	preview.theme = UITheme.theme()
	preview.add_child(square)
	force_drag(item, preview)
	_lifted = item
	_select_item(-1)


## A drag over, dropped or not: nothing is dimmed for it any more.
func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _lifted != null:
		_lifted = null
		_refresh_worn()


## The square a drop would land in, outlined (`DROP_MARK`) while a piece is on the cursor: followed every
## frame from where the mouse is, since nothing tells a socket the cursor has left it mid-drag.
func _process(_delta: float) -> void:
	var host: Control = _drop_square() if _lifted != null else null
	if is_instance_valid(_drop_mark) and _drop_mark.get_parent() == host:
		return
	if is_instance_valid(_drop_mark):
		_drop_mark.queue_free()
	_drop_mark = null
	if host == null:
		return
	var outline := StyleBoxFlat.new()
	outline.draw_center = false
	outline.set_border_width_all(1)
	outline.set_expand_margin_all(1)
	outline.border_color = DROP_MARK
	outline.anti_aliasing = false
	_drop_mark = Panel.new()
	_drop_mark.name = DROP_MARK_NAME
	_drop_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drop_mark.add_theme_stylebox_override("panel", outline)
	_drop_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(_drop_mark)


## The square under the mouse that would take `_lifted` were it let go now -- a doll socket, or a slot of
## the stones page's tree inside the box it scrolls in -- or null.
func _drop_square() -> Control:
	if _doll != null and _doll.is_visible_in_tree():
		var at := _doll.get_local_mouse_position()
		if _can_drop_on_doll(at, _lifted):
			return _socket_square_at(at)
	if _tree != null and _tree.is_visible_in_tree() \
			and (_tree.get_parent() as Control).get_global_rect().has_point(get_global_mouse_position()):
		var at := _tree.get_local_mouse_position()
		if _can_drop_on_tree(at, _lifted, _tree):
			return _tree.squares[_tree.slot_at(at)]
	return null


## A bag piece held over the doll: worn at the socket under it wherever Equip could put it there
## (`Inventory.can_equip`, every refusal the button's).
func _can_drop_on_doll(at: Vector2, data: Variant) -> bool:
	var socket := _socket_at(at)
	return data is Item and socket >= 0 and inventory.items.has(data) and inventory.can_equip(data, socket)


func _drop_on_doll(at: Vector2, data: Variant) -> void:
	_on_equip_pressed(data, _socket_at(at))


## A worn piece held over the bag: taken off as Unequip would, so never into a full bag.
func _can_drop_in_bag(_at: Vector2, data: Variant) -> bool:
	return data is Item and inventory.equipment.worn.find_key(data) != null and not inventory.is_full()


func _drop_in_bag(_at: Vector2, data: Variant) -> void:
	_on_unequip_pressed(inventory.equipment.worn.find_key(data))


## A bag stone held over the tree's slot: placed there as a press on the slot with it open would.
func _can_drop_on_tree(at: Vector2, data: Variant, view: SkillTreeView) -> bool:
	var path: Variant = view.slot_at(at)
	return data is Item and path is String and inventory.items.has(data) \
			and SkillTree.can_place(data, path, _purse.skills.stones)


func _drop_on_tree(at: Vector2, data: Variant, view: SkillTreeView) -> void:
	_place(data, view.slot_at(at))


## Which keys a click on a bag square answers to, for the card's foot: nothing on a transcension's
## bag, whose squares have no buttons.
func _bag_keys() -> Dictionary:
	if _transcending and not _heirlooms:
		return {}
	return {"shift": "equip", "ctrl": "sell" if _buys(TownServices.GEAR) else "discard"}


## A Shift-click's Equip or Unequip, a Ctrl-click's Sell or Discard: the open square's own button,
## pressed, so every refusal (a full bag, a socket that will not take it) and every question (an
## heirloom's Discard) is the button's as ever. A grey button leaves the square open with the reason
## on it.
func _press_action(shift: bool) -> void:
	var verbs := ["Equip", "Unequip"] if shift else ["Sell", "Discard"]
	for button: Node in _action_box.get_children():
		if button is Button and not (button as Button).disabled 				and verbs.any(func(verb: String) -> bool: return (button as Button).text.begins_with(verb)):
			(button as Button).pressed.emit()
			return


## Every change of selection puts a held orb down: an open piece and an orb in the hand never stand
## together, and an orb is only ever spent by pressing a piece with it held.
func _select_item(index: int) -> void:
	_socket_pick = 0
	_selected = index
	_worn_selected = -1
	_armed = ""
	refresh()
	selection_changed.emit(_open_piece())


## -1 closes it.
func _select_socket(socket: int) -> void:
	_armed = ""
	_worn_selected = socket
	_selected = -1
	refresh()
	selection_changed.emit(_open_piece())


## A bag item's buttons: Equip (into the emptiest socket it fits) over Sell or Discard, beside its
## square. No Back: the square pressed again, or bare panel, is the way out.
func _show_item(index: int) -> void:
	var item := inventory.items[index]
	var open_sockets := inventory.equipment.sockets_for(item)
	# Choosing what to keep: the world is ending, and there is nothing else to do with a piece.
	if _transcending and not _heirlooms:
		return
	if not open_sockets.is_empty():
		var socket: Equipment.Socket = open_sockets[_socket_pick % open_sockets.size()]
		# Everything the press would take off, named: a two-hander hands back the offhand as well, and
		# the tooltip is the only place the player is told so before pressing.
		var coming_off := PackedStringArray()
		for piece: Item in inventory.equipment.displaced_by(socket, item):
			coming_off.append(piece.display_name())
		# Greyed rather than destroying a piece to make room for what comes off -- `_unequip_button`'s
		# rule, and the reason is in the tooltip as it is there.
		var refusal := inventory.why_not_equip(item, socket)
		var full := not refusal.is_empty()
		var equip := UITheme.button("Equip", "LightButton", refusal if full
				else "Wear this in the %s slot%s" % [Equipment.LABELS[socket].to_lower(),
					"" if coming_off.is_empty()
					else ", putting %s back in the bag" % ", ".join(coming_off)])
		equip.disabled = full
		equip.pressed.connect(_on_equip_pressed.bind(item, socket))
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_box.add_child(equip)
		# Only a ring has a second finger to go on: Swap turns Equip to the other one, and its tooltip
		# says what that would take off.
		if open_sockets.size() > 1:
			var swap := UITheme.button("", "BrownIconButton", "Equip over the other ring instead")
			swap.icon = load(SWAP_ICON)
			swap.pressed.connect(_on_swap_pressed)
			_action_box.add_child(swap)
	# In a town that buys gear, the button that got rid of a piece sells it instead: one button in one
	# place, so there is never a Discard sitting next to a Sell for the player to press by mistake.
	# No confirmation either way: two clicks deep already, and asking twice teaches clicking through.
	if _buys(TownServices.GEAR):
		var price := TownPrices.sell_price(item)
		var sell := UITheme.priced_button("Sell", price, "LightButton",
				"Never sell is on" if item.locked
				else "Sell this to the merchant for %s gold" % BigNumber.format(price))
		sell.disabled = item.locked
		sell.pressed.connect(_on_sell_pressed.bind(item))
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_box.add_child(sell)
	else:
		var discard := UITheme.button("Discard", "LightDangerButton", "Discard this for good")
		# An heirloom is asked about every time, with no tick to stop the asking.
		if _heirlooms:
			discard.pressed.connect(_ask.bind("discard_heirloom", "Discard",
					"Discard %s for good? The choice that made it an heirloom does not come back."
					% item.display_name(), "Discard", "LightDangerButton",
					_on_discard_pressed.bind(item), false))
		else:
			discard.pressed.connect(_on_discard_pressed.bind(item))
		discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_box.add_child(discard)
	# The padlock, held down and green while the piece is locked, as Auto is (the pressed pixel alone is
	# too quiet): a level's Sell all and bin pass it by. Never "Lock", which is the smith's on a
	# modifier. Not on the heirlooms, which are never thrown away by the handful.
	if not _heirlooms:
		var lock := UITheme.button("Never sell", UITheme.GO_BUTTON if item.locked else "LightButton",
				"Let Sell all and the bin take this again" if item.locked
				else "Sell all and the bin pass this by")
		lock.icon = ItemSlot.lock_texture()
		lock.toggle_mode = true
		lock.button_pressed = item.locked
		lock.toggled.connect(_on_lock_toggled.bind(item))
		lock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_action_box.add_child(lock)


func _on_lock_toggled(on: bool, item: Item) -> void:
	item.locked = on
	_save()
	refresh()


## A worn piece's one button. No Discard: the cap is the bag's alone, so nothing pushes the player to
## destroy what they wear.
func _show_worn(socket: Equipment.Socket) -> void:
	if _transcending and not _heirlooms:
		return
	var unequip := _unequip_button(_on_unequip_pressed.bind(socket))
	unequip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_box.add_child(unequip)


## The buttons stood beside the selected square, bag or doll, or put away: with nothing selected,
## with nothing to press (a transcension's bag), or while the square is scrolled out of the grid.
func _place_actions() -> void:
	var square := _selected_square()
	var shown := square != null and _action_box.get_child_count() > 0
	if shown and square.has_meta("bag_index"):
		shown = _scroll.get_global_rect().has_point(square.get_global_rect().get_center())
	_actions.visible = shown
	if not shown:
		return
	_actions.reset_size()
	# Beside a doll socket the card keeps to the page: past the sheet stands a town's own panel, which
	# would cover it, so there it flips left over the figure instead.
	var window := get_viewport_rect().size
	if square.has_meta("socket"):
		window.x = _worn_panel.position.x + _worn_panel.size.x * _ui_scale
	_actions.position = ItemCard.beside(square.get_global_rect(),
			_actions.get_combined_minimum_size() * _ui_scale, window, ItemCard.GAP * _ui_scale)


## The square the selection points at, in the grid or on the doll, or null.
func _selected_square() -> Control:
	if _selected >= 0:
		for section: Node in _sections.get_children():
			if section is GridContainer:
				for slot: Control in section.get_children():
					if slot.get_meta("bag_index", -1) == _selected:
						return slot
	elif _worn_selected >= 0 and _doll != null:
		for slot: Node in _doll.get_children():
			if slot.get_meta("socket", -1) == _worn_selected:
				return slot
	return null


## Make heirloom, at the foot of a transcension's bag: live while the piece that is open, bag piece
## or worn, can be made one.
func _refresh_make() -> void:
	if _make_button == null:
		return
	var item := _open_piece()
	_make_button.disabled = not _purse.can_make_heirloom(item)
	_make_button.tooltip_text = ("Open the item you would keep" if item == null
			else Blacksmith.BROKEN if item.broken else "Keep this when the world is left behind")


func _on_make_pressed() -> void:
	var item := _open_piece()
	if item != null:
		_ask("heirloom", "Heirloom", "Make %s an heirloom? It is the one item of this world you keep."
				% item.display_name(), "Keep", "LightButton", _on_heirloom_pressed.bind(item), false)


func _on_heirloom_pressed(item: Item) -> void:
	if not _purse.make_heirloom(item):
		return
	print("Made %s (%s, level %d) an heirloom" % [item.display_name(), item.rarity_name(), item.level])
	_select_item(-1)
	heirloom_made.emit(item)


## What the page changed, written down -- but for a transcension's pages, which have no file: all
## that is done on the black screen is one write, and `main_scene` makes it when the screen is left.
func _save() -> void:
	if not _save_path.is_empty():
		_purse.save(_save_path)


## Greyed on a full bag rather than destroying something to make room.
func _unequip_button(action: Callable) -> Button:
	var full := inventory.is_full()
	var button := UITheme.button("Unequip", "LightButton",
			"The bag is full" if full else "Take this off and put it back in the bag")
	button.disabled = full
	button.pressed.connect(action)
	return button


func _on_equip_pressed(item: Item, socket: Equipment.Socket) -> void:
	if inventory.equip(item, socket):
		Juice.sound(EQUIP_SOUND)
		_save()
	_select_item(-1)


func _on_unequip_pressed(socket: Equipment.Socket) -> void:
	if inventory.unequip(socket):
		Juice.sound(EQUIP_SOUND)
		_save()
	_select_socket(-1)


func _on_discard_pressed(item: Item) -> void:
	if inventory.remove(item):
		print("Discarded %s (%s, level %d)" % [item.type, item.rarity_name(), item.level])
		_purse.gold += _purse.salvage(item)
		_purse.add_orb(_purse.salvage_orb())
		_purse.tick("discarded")
		_save()
	_select_item(-1)


## One piece over the counter. Priced and taken out first, paid for second, so a piece that was no
## longer in the bag can never be paid for twice.
func _on_sell_pressed(item: Item) -> void:
	var price := TownPrices.sell_price(item)
	if inventory.remove(item):
		_purse.sell_for(price)
		print("Sold %s (%s, level %d) for %s gold"
				% [item.type, item.rarity_name(), item.level, BigNumber.format(price)])
		_save()
	_select_item(-1)


## The sheet redrawn: the doll, whatever is selected. What a selected piece would replace is never
## written here -- the hover card says it under Alt -- so selecting a piece leaves the doll standing.
func _refresh_worn() -> void:
	_doll = null
	_tree = null
	UITheme.clear(_worn_body)
	# The doll stands at every counter (the user's, 2026-10-07): what is worn is what a shelf piece or a
	# sale is weighed against, and the smith takes a worn piece off it. Hidden, the whole sheet goes and
	# only the way back to it stays.
	_worn_panel.visible = not _doll_hidden
	_show_button.visible = _doll_hidden
	if _worn_panel.visible:
		if _stones:
			_show_tree()
		else:
			_show_doll()
	# Measured again deferred: a container's minimum is only right once it has laid out its new children.
	layout()
	layout.call_deferred()


## The eight sockets laid over the figure by hand, translucent so the body shows through.
func _show_doll() -> void:
	_worn_panel.theme_type_variation = "WoodPanel"
	_worn_body.custom_minimum_size = Vector2.ZERO
	_doll = Control.new()
	var figure := TextureRect.new()
	figure.texture = DOLL_TEXTURE
	figure.scale = Vector2(DOLL_SCALE, DOLL_SCALE)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.position = _doll_origin()
	_doll.add_child(figure)
	var art: Vector2 = DOLL_TEXTURE.get_size() * DOLL_SCALE + _doll_origin()
	for socket: Equipment.Socket in DOLL_SOCKETS:
		art = art.max(_socket_spot(socket) + Vector2(ItemSlot.SIDE, ItemSlot.SIDE))
	_doll.custom_minimum_size = art
	_doll.gui_input.connect(_on_doll_input)
	_doll.set_drag_forwarding(Callable(), _can_drop_on_doll, _drop_on_doll)
	for socket: Equipment.Socket in DOLL_SOCKETS:
		var item := inventory.equipment.item_at(socket)
		var chosen := _worn_selected == socket
		var slot: ItemSlot
		if item != null:
			slot = ItemSlot.make(item, chosen, true)
			if not (_transcending and not _heirlooms):
				slot.set_meta(ItemCard.KEYS, {"shift": "unequip"})
		elif socket == Equipment.Socket.OFFHAND and inventory.equipment.two_handed_worn():
			# The hand is not empty, it is full of the weapon. So the socket wears that weapon's own
			# icon as its faint mark, the way a bare ring socket wears the pack's ring: it reads as
			# taken rather than as somewhere left to fill.
			var weapon := inventory.equipment.item_at(Equipment.Socket.WEAPON)
			slot = ItemSlot.empty("%s takes both hands" % weapon.display_name(), weapon.icon(),
					chosen, true)
		else:
			slot = ItemSlot.empty(Equipment.LABELS[socket], _socket_mark(socket), chosen, true)
		slot.position = _socket_spot(socket)
		slot.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
		slot.set_meta("socket", socket)
		if chosen:
			slot.set_meta(ItemCard.BESIDE, _actions)
		_dim_for_orb(slot, item)
		# A bag piece on the cursor: every socket it cannot be dropped on, as its Equip there would refuse.
		if _lifted != null and inventory.items.has(_lifted) and not inventory.can_equip(_lifted, socket):
			slot.modulate = OrbSlot.DIM
		_doll.add_child(slot)
	# Hide, in the corner the figure leaves empty. Anchored and grown leftwards because a button's
	# size is not known until the theme reaches it.
	var fold := UITheme.button("", "BrownIconButton", "Hide what is equipped")
	fold.icon = load(HIDE_ICON)
	fold.anchor_left = 1.0
	fold.anchor_right = 1.0
	fold.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fold.pressed.connect(_on_fold_pressed)
	_doll.add_child(fold)
	_worn_body.add_child(_doll)


## The skill tree in the doll's place, on the black screen's stones page: the stone open in the bag
## rings the slots it may go in (`SkillTree.can_place`), a press on one puts it there and what that
## pushes out comes back to the bag (`Inventory.place_stone`), and an orb in the hand goes into the
## placed stone pressed. Under a bar of its own on the cream, the bag's twin rather than the doll's wood,
## as tall as the bag beside it (`_side_by_side`) or held upright the room above it (`_tree_height`),
## and the tree scaled into that.
func _show_tree() -> void:
	_worn_panel.theme_type_variation = ""
	_worn_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_worn_body.custom_minimum_size = Vector2.ZERO
	# The stone on the cursor, else the one open in the bag.
	var held := _lifted if _lifted != null else _open_piece()
	var view := SkillTreeView.new()
	_tree = view
	view.zoom = _tree_zoom
	view.slot_pressed.connect(_on_tree_pressed)
	view.set_drag_forwarding(Callable(), _can_drop_on_tree.bind(view), _drop_on_tree.bind(view))
	view.fill(_purse.skills, false, held if held != null and held.is_stone() else null)
	for path: String in view.squares:
		if _purse.skills.stones.has(path):
			_dim_for_orb(view.squares[path], _purse.skills.stones[path])
	var framed := UITheme.titled_panel(SkillsPage.TITLE, "", Callable())
	framed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# No X, but as tall a bar as the bag's beside it, which has one.
	(framed.get_child(0).get_child(0) as Control).custom_minimum_size.y = UITheme.icon_size("CloseButton").y
	(framed.get_child(1) as Control).size_flags_vertical = Control.SIZE_EXPAND_FILL
	_worn_body.add_child(framed)
	var body := UITheme.body_of(framed)
	# Thin bars once zoomed past its box, as on the skills page.
	var scroll := UITheme.scroll()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_child(view)
	# The − and + float over the tree's top-right corner rather than take a row of the height it needs:
	# a whole window pixel a tree pixel is the step `fit` takes, and a row's worth was often one.
	var over := MarginContainer.new()
	over.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(over)
	over.add_child(scroll)
	var zoom := SkillTreeView.zoom_buttons(view)
	zoom.size_flags_horizontal = Control.SIZE_SHRINK_END
	zoom.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(zoom)
	# The bar and the frame: the panel less what stands in the scroll's place, the floating − and + included.
	var outer := framed.get_combined_minimum_size()
	var chrome := outer - over.get_combined_minimum_size()
	var room := area if area.has_area() else get_viewport_rect()
	var most := Vector2(room.size.x / _ui_scale - 2 * UITheme.EDGE, _tree_height(room)) - chrome
	if not UITheme.narrow(get_viewport_rect().size, _ui_scale):
		most.x -= _panel.get_combined_minimum_size().x + WORN_GAP
	scroll.custom_minimum_size = view.fit(most, _ui_scale).min(most)
	# Zoomed, it scrolls in the same box; kept, so the next redraw draws it at the same zoom.
	view.zoomed.connect(func() -> void: _tree_zoom = view.zoom)


## Panel pixels the tree's panel may stand: across a window the bag's height on the black screen; held
## upright what is left above the bag once it is docked (`UITheme.dock`: as tall as it holds, half the
## window at most).
func _tree_height(room: Rect2) -> float:
	var window := get_viewport_rect().size
	if not UITheme.narrow(window, _ui_scale):
		return _transcend_height(room)
	var bag := minf(UITheme.natural_height(_panel), minf(room.size.y, window.y / 2.0) / _ui_scale - 2 * UITheme.EDGE)
	return room.size.y / _ui_scale - 2 * UITheme.EDGE - bag - WORN_GAP


## The bag's height on the black screen across a window: `TRANSCEND_HEIGHT` of what the edges leave.
func _transcend_height(room: Rect2) -> float:
	return floorf((room.size.y / _ui_scale - 2 * UITheme.EDGE) * TRANSCEND_HEIGHT)


## A press on the tree's slot `path`: an orb in the hand goes into the stone placed there; otherwise the
## stone open in the bag goes in, if it may. The black screen saves nothing until the world is left.
func _on_tree_pressed(path: String) -> void:
	var placed: Item = _purse.skills.stones.get(path)
	if _armed != "":
		if placed != null:
			_orb_on(placed)
		return
	_place(_open_piece(), path)


## `stone` into the tree at `path`, if it may stand there: pressed there while open, or dropped there.
func _place(stone: Item, path: String) -> void:
	if stone == null or not _purse.place_stone(stone, path):
		return
	print("Placed %s at %s" % [stone.display_name(), path])
	_select_item(-1)


## How far the doll is pushed right and down so no socket hangs off the page.
func _doll_origin() -> Vector2:
	var least := Vector2.ZERO
	for socket: Equipment.Socket in DOLL_SOCKETS:
		least = least.min(_socket_corner(socket))
	return -least.min(Vector2.ZERO)


## A socket square's top-left before the doll is shifted to fit.
func _socket_corner(socket: Equipment.Socket) -> Vector2:
	return (DOLL_SOCKETS[socket] * DOLL_SCALE - Vector2(ItemSlot.SIDE, ItemSlot.SIDE) / 2.0).floor()


func _socket_spot(socket: Equipment.Socket) -> Vector2:
	return _socket_corner(socket) + _doll_origin()


## The faint mark an empty ring or amulet socket carries; the figure explains the rest.
func _socket_mark(socket: Equipment.Socket) -> Texture2D:
	if socket == Equipment.Socket.AMULET:
		return SOCKET_AMULET_TEXTURE
	if socket in [Equipment.Socket.RING_LEFT, Equipment.Socket.RING_RIGHT]:
		return SOCKET_RING_TEXTURE
	return null


## A click on a filled socket opens it; a second click on the open one closes it. Counted as it lets go,
## as the grid's is, so that a mouse's press that travels lifts the piece instead (`_lift`).
func _on_doll_input(event: InputEvent) -> void:
	Cursors.over_squares(_doll, event, _armed != "")
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
			and not get_viewport().gui_is_dragging():
		_dragged += event.relative.length()
		var lifted := _worn_at(_drag_from)
		if lifted >= 0 and _lifts() and _dragged >= DRAG_THRESHOLD:
			_lift(inventory.equipment.item_at(lifted))
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Before anything redraws the doll out of the tree: freed under its own press, it would let the press
	# through to the map behind it (`OrbSlot`'s reason).
	_doll.accept_event()
	var press := event as InputEventMouseButton
	if press.pressed:
		_drag_from = press.position
		_dragged = 0.0
		return
	var socket := _worn_at(press.position)
	if socket < 0 or _dragged >= (Cursors.TOUCH_SLOP if Cursors.touched else DRAG_THRESHOLD):
		return
	if _armed != "":
		_orb_on(inventory.equipment.item_at(socket))
	elif press.shift_pressed or press.ctrl_pressed:
		_select_socket(socket)
		_press_action(press.shift_pressed)
	else:
		_select_socket(-1 if socket == _worn_selected else socket)


## The doll's socket under `at` (the doll's own pixels), filled or not, or -1.
func _socket_at(at: Vector2) -> int:
	var square := _socket_square_at(at)
	return -1 if square == null else square.get_meta("socket")


## The doll's socket square under `at`, or null.
func _socket_square_at(at: Vector2) -> Control:
	for slot: Control in _doll.get_children():
		if slot.has_meta("socket") and Rect2(slot.position, slot.size).has_point(at):
			return slot
	return null


## The socket whose piece is drawn under `at`, or -1 over an empty one or bare doll. The offhand square is
## the two-hander's other half while one is worn, so it answers for the weapon: what it draws is what it
## answers for.
func _worn_at(at: Vector2) -> int:
	var socket := _socket_at(at)
	if socket == Equipment.Socket.OFFHAND and inventory.equipment.two_handed_worn():
		socket = Equipment.Socket.WEAPON
	return socket if socket >= 0 and inventory.equipment.item_at(socket) != null else -1


func _on_swap_pressed() -> void:
	_socket_pick += 1
	refresh()


func _on_fold_pressed() -> void:
	_doll_hidden = not _doll_hidden
	refresh()


## The piece the bag has open, bag item or worn, or null on the grid.
func _open_piece() -> Item:
	if _selected >= 0 and _selected < inventory.total():
		return inventory.items[_selected]
	if _worn_selected >= 0:
		return inventory.equipment.item_at(_worn_selected)
	return null


## Every orb held, lit, whatever is open: an orb is picked up, never spent on the open piece -- the
## super orbs too, since 2026-10-03 (the user's: "first click orb, then gear").
func refresh_orbs() -> void:
	UITheme.clear(_orb_tray)
	UITheme.clear(_rune_tray)
	_rune_tray.hide()
	_fold_button.hide()
	if _transcending and not _stones:
		# Over the bag there is no tray at all, and over the heirlooms it is the super orbs: one count
		# for the six of them (said in the corner, `_count`), so no square wears a number.
		_orb_tray.visible = _heirlooms
		_orb_rule.visible = _heirlooms
		for orb: String in SuperOrbTable.orbs() if _heirlooms else []:
			_orb_tray.add_child(_tray_slot(orb, mini(_purse.super_orbs, 1)))
		_hide_orb_card()
		return
	# No tray until the first orb; once seen it stays, even with every orb spent. The runes the same, over
	# it and in the bag alone -- and with them the chevron that folds both away.
	var orbs := _purse.total_orbs() > 0 or "first_orb" in _purse.tips
	var runes := not (_heirlooms or _transcending) \
			and (not _purse.runes.is_empty() or Inventory.FIRST_RUNE in _purse.tips)
	_orb_rule.visible = orbs or runes
	_fold_button.visible = runes
	_fold_button.icon = _chevron(_trays_hidden)
	_fold_button.tooltip_text = "Show the orbs and runes" if _trays_hidden else "Hide the orbs and runes"
	_orb_tray.visible = orbs and not _trays_hidden
	_rune_tray.visible = runes and not _trays_hidden
	for orb: String in OrbTable.orbs():
		_orb_tray.add_child(_tray_slot(orb, _purse.orb_count(orb)))
	for rune: String in RuneTable.names() if runes else []:
		_rune_tray.add_child(_tray_slot(rune, _purse.rune_count(rune)))
	# The square it described has just been freed.
	_hide_orb_card()


func _tray_slot(orb: String, count: int) -> OrbSlot:
	var slot := OrbSlot.make(orb, count, true, orb == _armed)
	slot.picks_up = true
	slot.pressed.connect(_on_orb_pressed)
	slot.hovered.connect(_on_orb_hovered.bind(slot))
	slot.unhovered.connect(_hide_orb_card)
	return slot


## `CHEVRON` in the button brown, pointing up when `up`. Made once.
static func _chevron(up: bool) -> ImageTexture:
	if _chevrons.is_empty():
		for flip: bool in [false, true]:
			var image := Image.create(CHEVRON[0].length(), CHEVRON.size(), false, Image.FORMAT_RGBA8)
			for y in CHEVRON.size():
				for x in CHEVRON[y].length():
					if CHEVRON[y][x] == "#":
						image.set_pixel(x, y, Palette.BUTTON_BROWN)
			if flip:
				image.flip_y()
			_chevrons.append(ImageTexture.create_from_image(image))
	return _chevrons[int(up)]


func _on_trays_pressed() -> void:
	_trays_hidden = not _trays_hidden
	refresh()


## The rune in hand pressed on the map's tile at world `spot`, which carries `own` modifiers: spent there
## where it does something (`Inventory.use_rune`), saved, and kept in hand while any are left, as an orb
## is. Whether it was spent.
func rune_on(spot: Vector2i, own: Array) -> bool:
	if not RuneTable.has(_armed) or not _purse.use_rune(_armed, spot, own, _craft_rng):
		return false
	print("Spent %s on %s" % [_armed, spot])
	_save()
	if _purse.rune_count(_armed) <= 0:
		_armed = ""
	refresh_orbs()
	_orb_applied()
	return true


## Picks the orb up (`_armed`), and a second press puts it down; the next piece pressed is crafted with
## it (`_craft`). With a piece open the press shuts it first (the user's rule, 2026-10-01): an orb is
## never spent on the open piece. Orbs are never sold: a vendor only sells them.
func _on_orb_pressed(orb: String) -> void:
	if _count_of(orb) <= 0:
		return
	if _open_piece() != null:
		# Which puts down whatever was held, so the press always picks this one up.
		_select_item(-1)
	_armed = "" if orb == _armed else orb
	refresh()


## How many of `orb` the player has to spend: the one count all six super orbs share, or the orb's (or
## the rune's) own.
func _count_of(orb: String) -> int:
	return _purse.super_orbs if SuperOrbTable.has(orb) else _purse.rune_count(orb) if RuneTable.has(orb) \
			else _purse.orb_count(orb)


## A held super orb pressed on a piece. An aimed one asks which modifier, the only question any of them
## asks; the rest are spent at once, as an ordinary orb is.
func _super_press(orb: String, item: Item) -> void:
	if _purse.super_orbs <= 0 or not SuperOrbTable.can_apply(orb, item):
		return
	if not SuperOrbTable.aimed(orb):
		_super_craft(orb, item, -1)
		return
	_close_confirm()
	_confirm = Control.new()
	_confirm.size = get_viewport_rect().size
	add_child(_confirm)
	# Over every other page too: held upright the town's counter stands over the bag, and the question
	# is centred across both.
	move_to_front()
	var panel := UITheme.titled_panel(orb, "", Callable())
	panel.name = CONFIRM_PANEL
	_confirm.add_child(panel)
	var body := UITheme.body_of(panel)
	body.add_child(UITheme.label("Which modifier?", null, true))
	for i in item.mods.size():
		var line := UITheme.button(ModifierTable.line(item.mods[i]), "LightButton", "")
		line.custom_minimum_size.x = CONFIRM_WIDTH
		line.disabled = not SuperOrbTable.can_aim(orb, item, i)
		line.pressed.connect(func() -> void:
			_close_confirm()
			_super_craft(orb, item, i))
		body.add_child(line)
	# With no X the way back out is a button of its own, as every other question's Cancel is.
	var cancel := UITheme.button("Cancel", "LightButton", "")
	cancel.pressed.connect(_close_confirm)
	body.add_child(cancel)
	Juice.popup(_confirm, panel, _ui_scale)


## Applied first and spent second, as every orb is. Not saved: see `_save`.
func _super_craft(orb: String, item: Item, index: int) -> void:
	if _purse.super_orbs <= 0 or not SuperOrbTable.apply(orb, item, _craft_rng, index):
		return
	_purse.super_orbs -= 1
	print("Spent %s on %s (%s, level %d)" % [orb, item.display_name(), item.rarity_name(), item.level])
	if _purse.super_orbs <= 0:
		_armed = ""
	refresh()
	_orb_applied()
	crafted.emit(orb)


## The held orb on a piece that is not the bag's -- one off a vendor's shelf. `written` is called
## between the change and the save, so whoever owns the piece writes it down in the same write the
## orb is spent in.
func craft_held(item: Item, written: Callable) -> void:
	if _armed != "":
		_craft(_armed, item, written)


## The held orb pressed on one of the player's own pieces: in the bag, worn, or a stone in the tree.
## Under a finger the first tap only puts the piece's card up, and the next spends the orb
## (`Cursors.applies`): with no hover, a tap is the only way the piece is read first.
func _orb_on(item: Item) -> void:
	if Cursors.applies(item):
		_craft(_armed, item)


## An orb that would take a piece down a rarity asks first, with a tick to stop asking (the user's,
## 2026-10-02): one misplaced Transmutation is an epic gone. Anything else is done at once.
func _craft(orb: String, item: Item, written := Callable()) -> void:
	if SuperOrbTable.has(orb):
		_super_press(orb, item)
		return
	var to: int = OrbTable.RARITY_OF.get(orb, item.rarity)
	if to < item.rarity and OrbTable.can_apply(orb, item):
		_ask("lower_rarity", orb, "Make the %s %s %s? It cannot be taken back." % [
				item.rarity_label().to_lower(), item.display_name(), ItemRarity.label_of(to).to_lower()],
				"Use", "LightDangerButton", _apply_orb.bind(orb, item, written))
		return
	_apply_orb(orb, item, written)


## Applied first and spent second: nothing is spent when the orb has nothing to do to the piece.
func _apply_orb(orb: String, item: Item, written: Callable) -> void:
	if not OrbTable.apply(orb, item, _craft_rng):
		return
	if written.is_valid():
		written.call()
	_purse.spend_orb(orb)
	if orb == "Orb of Chaos":
		_purse.tick("chaos")
	_save()
	print("Spent %s on %s (%s, level %d)" % [orb, item.display_name(), item.rarity_name(), item.level])
	if _purse.orb_count(_armed) <= 0:
		_armed = ""
	refresh()
	_orb_applied()
	crafted.emit(orb)


func _orb_applied() -> void:
	for layer: AudioStream in ORB_APPLIED_SOUNDS:
		Juice.sound(layer)


## Whether wearing `item` loses nothing and gains something: against what Equip would take off (the
## emptiest socket it fits, both hands for a two-hander), and against nothing on a bare socket. A swap
## that trades one stat for another gets no mark -- that is the Alt card's to weigh, and most swaps are.
## Nor does a piece Equip would refuse (`Inventory.can_equip`: the attribute it asks for, above all):
## an arrow over a greyed Equip is a promise the next press breaks.
static func is_upgrade(item: Item, player: Inventory) -> bool:
	var equipment := player.equipment
	if item in equipment.worn.values():
		return false
	var sockets := equipment.sockets_for(item)
	if sockets.is_empty() or not player.can_equip(item, sockets[0]):
		return false
	var changes := ItemDetails.deltas(item, equipment.displaced_by(sockets[0], item)).values()
	return not changes.is_empty() and changes.all(func(change: float) -> bool: return change >= 0.0)


## The green arrow in a square's top-right corner that says `is_upgrade`, drawn from `UPGRADE`.
static func _upgrade_mark() -> TextureRect:
	if _upgrade_texture == null:
		var image := Image.create(UPGRADE[0].length(), UPGRADE.size(), false, Image.FORMAT_RGBA8)
		for y in UPGRADE.size():
			for x in UPGRADE[y].length():
				match UPGRADE[y][x]:
					"#": image.set_pixel(x, y, Palette.LEAF_LT)
					"o": image.set_pixel(x, y, Palette.INK)
		_upgrade_texture = ImageTexture.create_from_image(image)
	var mark := TextureRect.new()
	mark.name = UPGRADE_NAME
	mark.texture = _upgrade_texture
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = Vector2(ItemSlot.SIDE - UPGRADE[0].length() - 1, 1)
	return mark


## A square the held orb can do nothing to goes as grey as an orb with nothing to do (`OrbSlot.DIM`).
func _dim_for_orb(slot: Control, item: Item) -> void:
	if _armed != "" and item != null and not (SuperOrbTable.can_apply(_armed, item) if SuperOrbTable.has(_armed)
			else OrbTable.can_apply(_armed, item)):
		slot.modulate = OrbSlot.DIM


## Placed now and again deferred: the first pass measures labels that have not laid out yet.
func _on_orb_hovered(orb: String, slot: OrbSlot) -> void:
	_orb_card.fill(orb, _count_of(orb))
	_orb_card.show()
	_place_orb_card(slot.get_global_rect())
	_place_orb_card.call_deferred(slot.get_global_rect())


func _hide_orb_card() -> void:
	_orb_card.hide()


## Above the square: the screen edge is on one side of the tray and the sheet on the other.
func _place_orb_card(anchor: Rect2) -> void:
	if not _orb_card.visible:
		return
	var card := _orb_card.get_combined_minimum_size() * _ui_scale
	var spot := Vector2(anchor.position.x, anchor.position.y - card.y - SLOT_GAP * _ui_scale)
	_orb_card.position = spot.clamp(Vector2.ZERO, (get_viewport_rect().size - card).max(Vector2.ZERO))
