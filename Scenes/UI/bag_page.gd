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
## A held orb went into a piece where it lies (`_armed`). The main scene lets the hover card speak
## again on it: the press that crafted would otherwise have put the card away with the result unread.
signal crafted
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
const HIDE_ICON := "res://Assets/UI/ui_icon_caret_left.png"
const SHOW_ICON := "res://Assets/UI/ui_icon_caret_right.png"
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
## How many squares short of the cap the count turns rust.
const NEARLY_FULL := 4
const WIDTH := GRID_COLS * ItemSlot.SIDE + (GRID_COLS - 1) * SLOT_GAP
## All six orbs in one row across WIDTH; the whole-pixel gap leaves under a gap's worth of slack,
## which the centred tray splits (test_ui_theme holds the arithmetic).
const ORB_COLS := 6
const ORB_GAP := (WIDTH - ORB_COLS * OrbSlot.SIDE) / (ORB_COLS - 1)
## How far a press may travel, in panel pixels, and still be a click rather than a drag.
const DRAG_THRESHOLD := 4.0

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
## jewellery sits in a row below the figure.
const DOLL_SOCKETS := {
	Equipment.Socket.HELMET: Vector2(63, 24),
	Equipment.Socket.OFFHAND: Vector2(12, 78),
	Equipment.Socket.BODY: Vector2(63, 75),
	Equipment.Socket.WEAPON: Vector2(114, 75),
	Equipment.Socket.BOOTS: Vector2(63, 123),
	Equipment.Socket.RING_LEFT: Vector2(12, 174),
	Equipment.Socket.AMULET: Vector2(63, 174),
	Equipment.Socket.RING_RIGHT: Vector2(114, 174),
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
var _make_button: Button
var _save_path: String
var _ui_scale: float

## What the counter the bag is standing at buys, by `TownServices` name -- the town page's open tab
## and not everything the town offers, so only the gear merchant turns Discard into Sell. Empty
## everywhere else. Orbs are never bought back: the tray is crafting alone at every counter.
var _services: PackedStringArray = []

var _panel: VBoxContainer
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

## The question standing over the page (`_ask`), or null.
var _confirm: Control

var _orb_rule: ColorRect
var _orb_tray: HBoxContainer
var _orb_card: OrbCard
## What a spent orb rolls with. Unseeded: a test that wants a known answer seeds it.
var _craft_rng := RandomNumberGenerator.new()
## The orb pressed with no piece open, or "". The next square or worn socket pressed is crafted with
## it where it lies, unopened, and it stays held while any are left. Opening a piece, a press on
## bare panel, the same orb again, Escape or the bag going away puts it down. While it is held it is
## the cursor, at the 32 px it is cut at -- which is the tray's 16 at `ui_scale` 2.
var _armed := "":
	set(orb):
		if orb == _armed:
			return
		_armed = orb
		var mark: Texture2D = null if orb == "" else OrbTable.icon(orb)
		Cursors.hold(mark)
		held_changed.emit(orb)


func _init(player_inventory: Inventory, save_path: String, ui_scale: float, heirlooms := false,
		transcending := false) -> void:
	_purse = player_inventory
	_heirlooms = heirlooms
	_transcending = transcending
	inventory = player_inventory.stash() if heirlooms else player_inventory
	_save_path = save_path
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Heirlooms" if _heirlooms else "Items",
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

	# Wheel scrolling is the container's, dragging is `_on_grid_input`'s; no bar is drawn.
	_scroll = UITheme.scroll()
	_scroll.gui_input.connect(_on_grid_input)
	# The buttons beside the selected square move with it.
	_scroll.get_v_scroll_bar().value_changed.connect(func(_at: float) -> void: _place_actions())
	rows.add_child(_scroll)
	_sections = UITheme.vbox(SLOT_GAP, WIDTH)
	_scroll.add_child(_sections)

	# The tray comes after the grid, so it is a footer under it.
	_orb_rule = UITheme.rule()
	rows.add_child(_orb_rule)
	_orb_tray = HBoxContainer.new()
	_orb_tray.add_theme_constant_override("separation", ORB_GAP)
	_orb_tray.alignment = BoxContainer.ALIGNMENT_CENTER
	_orb_tray.custom_minimum_size = Vector2(WIDTH, 0)
	rows.add_child(_orb_tray)
	if _transcending and not _heirlooms:
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
	var width := _panel.get_combined_minimum_size().x
	if _worn_panel.visible and room.size.x < (width + WORN_GAP + _worn_panel.size.x + 2 * UITheme.EDGE) * _ui_scale:
		_stack(room, width)
	else:
		_side_by_side(room, width)
	# The caret heads the column of corner buttons that stands beside the page, so it sits at the top.
	_show_button.size = _show_button.get_combined_minimum_size()
	_show_button.position = Vector2(_worn_panel.position.x, _panel.position.y + WORN_GAP * _ui_scale)
	_place_actions()
	_place_confirm()
	laid_out.emit()


## The bag against the room's left edge (centred in a narrow window, and on a transcension's screen)
## and the sheet or its caret beside it, the sheet centred down the room.
func _side_by_side(room: Rect2, width: float) -> void:
	_panel.size = Vector2(width, room.size.y / _ui_scale - 2 * UITheme.EDGE)
	_panel.position = room.position + Vector2.ONE * UITheme.EDGE * _ui_scale
	var beside: Control = (_worn_panel if _worn_panel.visible
			else _show_button if _show_button.visible else null)
	var both := width + (0.0 if beside == null else WORN_GAP + beside.get_combined_minimum_size().x)
	if _transcending:
		_panel.size.y = floorf(_panel.size.y * TRANSCEND_HEIGHT)
		_panel.position = (room.position + (room.size - Vector2(both, _panel.size.y) * _ui_scale) / 2.0).floor()
	elif UITheme.narrow(get_viewport_rect().size, _ui_scale):
		_panel.position.x = floorf(room.position.x + (room.size.x - both * _ui_scale) / 2.0)
	_worn_panel.position = Vector2(_panel.position.x + (_panel.size.x + WORN_GAP) * _ui_scale,
			room.position.y + (room.size.y - _worn_panel.size.y * _ui_scale) / 2.0)


## The least height, in window pixels, the page needs in a room `across` window pixels wide: the bag
## with `LEAST_ROWS` rows of its grid showing, and the sheet too where it would have to stand over it.
## A town held upright gives its counter what is left (the main scene's `_layout_ui`).
func least_height(across: float) -> float:
	var width := _panel.get_combined_minimum_size().x
	var tall := _panel.get_combined_minimum_size().y + LEAST_ROWS * (ItemSlot.SIDE + SLOT_GAP) + 2 * UITheme.EDGE
	_worn_panel.size = _worn_panel.get_combined_minimum_size()
	if _worn_panel.visible and across < (width + WORN_GAP + _worn_panel.size.x + 2 * UITheme.EDGE) * _ui_scale:
		tall += _worn_panel.size.y + WORN_GAP
	return tall * _ui_scale


## The sheet over the bag, both centred across the room, and the bag taking what the sheet leaves.
func _stack(room: Rect2, width: float) -> void:
	_worn_panel.position = Vector2(floorf(room.position.x + (room.size.x - _worn_panel.size.x * _ui_scale) / 2.0),
			room.position.y + UITheme.EDGE * _ui_scale)
	var top := _worn_panel.position.y + (_worn_panel.size.y + WORN_GAP) * _ui_scale
	_panel.size = Vector2(width, (room.end.y - top) / _ui_scale - UITheme.EDGE)
	_panel.position = Vector2(floorf(room.position.x + (room.size.x - width * _ui_scale) / 2.0), top)


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
		by_level.get_or_add(inventory.items[i].level, []).append(i)
	for level: int in inventory.levels():
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
	var held := inventory.count_at(level)
	var selling := _buys(TownServices.GEAR)
	var worth := TownPrices.sell_total(inventory.items.filter(
			func(item: Item) -> bool: return item.level == level)) if selling else 0.0
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


## A right click anywhere puts a held orb down, as Escape does. `_input` rather than `_unhandled_input`:
## a press over a panel is handled by the panel and would never reach the other.
func _input(event: InputEvent) -> void:
	if _armed != "" and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_armed = ""
		refresh()


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
		return item.level == level and not item.unique.is_empty())
	if Settings.uniques != Settings.Uniques.ASK or uniques.is_empty():
		return
	var names := ", ".join(uniques.map(func(item: Item) -> String: return item.display_name()))
	var question := "%s %s unique. %s %s as well?" % [names, "is" if uniques.size() == 1 else "are",
			"Sell" if selling else "Discard", "it" if uniques.size() == 1 else "them"]
	_ask(UNIQUES, "Uniques", question, "Sell" if selling else "Discard",
			"LightButton" if selling else "LightDangerButton", deed.bind(level, true), true,
			"Don't sell" if selling else "Don't discard")


func _clear_level(level: int, uniques: bool) -> void:
	var gone := inventory.discard_level(level, uniques)
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
	var gone := inventory.discard_level(level, uniques)
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
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged += absf(event.relative.y)
		_scroll.scroll_vertical = _drag_scroll - int(event.position.y - _drag_from.y)


## Opens the square under `at` (in the sections' own space), or closes the block on bare panel. Under
## Shift or Ctrl the square is opened and its own button pressed for it (`_press_action`).
func _on_clicked(at: Vector2, shift := false, ctrl := false) -> void:
	for section: Node in _sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Control in section.get_children():
			if Rect2((section as Control).position + slot.position, slot.size).has_point(at):
				var index: int = slot.get_meta("bag_index", -1)
				if _armed != "":
					_craft(_armed, inventory.items[index])
				elif shift or ctrl:
					_select_item(index)
					_press_action(shift)
				else:
					_select_item(-1 if index == _selected else index)
				return
	_select_item(-1)


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


## Every change of selection puts a held orb down: with a piece open the tray crafts on that piece.
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
				"Sell this to the merchant for %s gold" % BigNumber.format(price))
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
		_save()
	_select_item(-1)


func _on_unequip_pressed(socket: Equipment.Socket) -> void:
	if inventory.unequip(socket):
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
	UITheme.clear(_worn_body)
	# In a town the page on the far edge needs the room, and the doll is the one thing on this side
	# that can go without taking a decision with it: nothing is worn while the bag is being emptied
	# over a counter. **The smith is the exception:** he works on a worn piece as readily as a carried
	# one, so there the doll is the decision, and it is how the player hands him what they are wearing.
	_worn_panel.visible = _services.is_empty() or TownServices.SMITH in _services
	# Hidden, the whole sheet goes and only the way back to it stays.
	_show_button.visible = _doll_hidden and _worn_panel.visible
	if _show_button.visible:
		_worn_panel.hide()
	elif _worn_panel.visible:
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


## A click on a filled socket opens it; a second click on the open one closes it.
func _on_doll_input(event: InputEvent) -> void:
	Cursors.over_squares(_doll, event, _armed != "")
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed):
		return
	var press := event as InputEventMouseButton
	for slot: Control in _doll.get_children():
		if not slot.has_meta("socket") or not Rect2(slot.position, slot.size).has_point(event.position):
			continue
		var socket: Equipment.Socket = slot.get_meta("socket")
		# The offhand square is the two-hander's other half while one is worn, so a press there opens
		# the weapon rather than nothing: what it draws is what it answers for.
		if socket == Equipment.Socket.OFFHAND and inventory.equipment.two_handed_worn():
			socket = Equipment.Socket.WEAPON
		if inventory.equipment.item_at(socket) == null:
			continue
		if _armed != "":
			_craft(_armed, inventory.equipment.item_at(socket))
		elif press.shift_pressed or press.ctrl_pressed:
			_select_socket(socket)
			_press_action(press.shift_pressed)
		else:
			_select_socket(-1 if socket == _worn_selected else socket)
		return


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


## Every orb held, lit; with a piece open, only the ones that can do something to it stay lit.
func refresh_orbs() -> void:
	UITheme.clear(_orb_tray)
	var against := _open_piece()
	if _transcending:
		# Over the bag there is no tray at all, and over the heirlooms it is the super orbs: one count
		# for the six of them (said in the corner, `_count`), so no square wears a number.
		_orb_tray.visible = _heirlooms
		_orb_rule.visible = _heirlooms
		for orb: String in SuperOrbTable.orbs() if _heirlooms else []:
			var slot := OrbSlot.make(orb, mini(_purse.super_orbs, 1),
					against != null and SuperOrbTable.can_apply(orb, against))
			slot.pressed.connect(_on_super_orb_pressed)
			slot.hovered.connect(_on_orb_hovered.bind(slot))
			slot.unhovered.connect(_hide_orb_card)
			_orb_tray.add_child(slot)
		_hide_orb_card()
		return
	# No tray until the first orb; once seen it stays, even with every orb spent.
	_orb_tray.visible = _purse.total_orbs() > 0 or "first_orb" in _purse.tips
	_orb_rule.visible = _orb_tray.visible
	for orb: String in OrbTable.orbs():
		var slot := OrbSlot.make(orb, _purse.orb_count(orb),
				against == null or OrbTable.can_apply(orb, against), orb == _armed)
		slot.pressed.connect(_on_orb_pressed)
		slot.hovered.connect(_on_orb_hovered.bind(slot))
		slot.unhovered.connect(_hide_orb_card)
		_orb_tray.add_child(slot)
	# The square it described has just been freed.
	_hide_orb_card()


## Applied first and spent second, so an orb with nothing to do is never consumed. The selection
## survives: crafting adds nothing to the bag and takes nothing out.
func _on_orb_pressed(orb: String) -> void:
	var item := _open_piece()
	if _purse.orb_count(orb) <= 0:
		return
	# A press with no piece open picks the orb up (`_armed`), and a second one puts it down. Orbs are
	# never sold: a vendor only sells them.
	if item == null:
		_armed = "" if orb == _armed else orb
		refresh()
		return
	_craft(orb, item)


## A super orb pressed with a piece open. An aimed one asks which modifier, and that answer is the
## only question it asks; the rest ask whether, every time: a wall was broken for each.
func _on_super_orb_pressed(orb: String) -> void:
	var item := _open_piece()
	if _purse.super_orbs <= 0 or not SuperOrbTable.can_apply(orb, item):
		return
	if not SuperOrbTable.aimed(orb):
		_ask("super_orb", orb, "Use it on %s? It cannot be taken back." % item.display_name(),
				"Use", "LightButton", _super_craft.bind(orb, item, -1), false)
		return
	_close_confirm()
	_confirm = Control.new()
	_confirm.size = get_viewport_rect().size
	add_child(_confirm)
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
	refresh()


## The held orb on a piece that is not the bag's -- one off a vendor's shelf. `written` is called
## between the change and the save, so whoever owns the piece writes it down in the same write the
## orb is spent in.
func craft_held(item: Item, written: Callable) -> void:
	if _armed != "":
		_craft(_armed, item, written)


## Applied first and spent second: nothing is spent when the orb has nothing to do to the piece.
func _craft(orb: String, item: Item, written := Callable()) -> void:
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
	if _open_piece() == null:
		crafted.emit()


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
	if _armed != "" and item != null and not OrbTable.can_apply(_armed, item):
		slot.modulate = OrbSlot.DIM


## Placed now and again deferred: the first pass measures labels that have not laid out yet.
func _on_orb_hovered(orb: String, slot: OrbSlot) -> void:
	_orb_card.fill(orb, _purse.super_orbs if SuperOrbTable.has(orb) else _purse.orb_count(orb),
			_open_piece())
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
