class_name BagPage
extends Control
## The bag against the left edge, the sheet beside it (the doll; on the stones page the skill tree) and
## the orb and rune trays at its foot. Built four ways by `_init`'s flags: the bag, the heirlooms, and
## a transcension's bag and stones page. What each does and why: "bag_page.gd" in Scenes/UI/DESIGN.md
## and the rules it points to; how the bag came to be this way: Scenes/DESIGN.md.

signal closed
## The open piece changed, bag item or worn; null when none is open.
signal selection_changed(item: Item)
## An orb went into a piece.
signal crafted(orb: String)
## The page measured itself again: `column_origin` may have moved.
signal laid_out
## The orb in hand changed, "" for none.
signal held_changed(orb: String)
signal heirloom_made(item: Item)

## Four to a row is the narrowest a level's heading fits beside its two marks; the gutter is the pack's
## own 7:1 square to gutter.
const GRID_COLS := 4
const SLOT_GAP := ItemSlot.SIDE / 7
const AUTO_ICON := "res://Assets/UI/ui_icon_auto_brown.png"
const AUTO_ON_ICON := "res://Assets/UI/ui_icon_auto_green.png"
const CLEAR_ICON := "res://Assets/UI/ui_icon_trash_brown.png"
const SELL_ICON := "res://Assets/UI/ui_icon_coins_brown.png"
const COUNT_ICON := "res://Assets/UI/ui_icon_chest_brown.png"
const HIDE_ICON := "res://Assets/UI/ui_icon_caret_left.png"
const SHOW_ICON := "res://Assets/UI/ui_icon_caret_right.png"
## The meta on the Equip button of `sockets_for(item)`'s first socket, which Shift-click presses.
const EMPTIEST := "emptiest"
## Filter tab -> [mark, tooltip], in tab order: "" shows everything, the rest are `LootTable.slot_of`
## values, the stones' last (the user's, 2026-10-09). Nine tabs `FILTER_TAB` wide and `FILTER_GAP`
## apart fit `WIDTH`.
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
## Filled with a tab's mark and "green" (the open tab) or "brown".
const FILTER_MARK := "res://Assets/UI/ui_icon_%s_%s.png"
const FILTER_TAB := 18
const FILTER_GAP := 1
## Played together: the user's pairing.
const ORB_APPLIED_SOUNDS := [preload("res://Sounds/Sfx/orb_applied.ogg"),
		preload("res://Sounds/Sfx/orb_applied_layer.ogg")]
const EQUIP_SOUND := preload("res://Sounds/Sfx/equip.ogg")
## `SKIP_CONFIRM + id` in `inventory.tips` (the save): question `id` is not asked again.
const SKIP_CONFIRM := "skip_confirm_"
## The one question whose tick keeps the answer given, in `Settings.uniques`, not in the save.
const UNIQUES := "uniques"
const CONFIRM_WIDTH := 150.0
## The tick box's node name: how `_ask`, the other pages and the tests read it.
const TICK_NAME := "Tick"
## A question's panel inside its holder, found by name (`_close_confirm`): a win's wash would push it
## off child 0.
const CONFIRM_PANEL := "Panel"
const TICK: Array[String] = [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
]
## A square's upgrade arrow (`is_upgrade`): `#` leaf over an `o` ink outline, so it reads on any frame.
const UPGRADE: Array[String] = [
	"...o...",
	"..o#o..",
	".o###o.",
	"o#####o",
	"oo###oo",
	".o###o.",
	".ooooo.",
]
## The arrow's node name: how a test finds it.
const UPGRADE_NAME := "Upgrade"
static var _upgrade_texture: ImageTexture
## The trays' fold mark (`_fold_button`): as drawn while they stand under it, flipped while folded away.
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
## Six orbs in one row across `WIDTH` (`test_ui_theme` holds the arithmetic).
const ORB_COLS := 6
const ORB_GAP := (WIDTH - ORB_COLS * OrbSlot.SIDE) / (ORB_COLS - 1)
## How far a press may travel, in panel pixels, and still be a click rather than a drag.
const DRAG_THRESHOLD := 4.0
## The outline round the square a dragged piece would drop into (`_process`), a pixel outside it, and
## its node name: how a test finds it.
const DROP_MARK := Palette.GOLD
const DROP_MARK_NAME := "DropMark"

## The air between the bag panel and the sheet.
const WORN_GAP := 6.0
## How much of the room's height the bag takes on a transcension's black screen.
const TRANSCEND_HEIGHT := 0.7
## How many rows of the grid a room held upright has to leave showing (`least_height`).
const LEAST_ROWS := 2
## Held upright at a counter, the tabs down the panel's right edge (`tabbed`; the user's sketch, 2026-10-29):
## [mark, tooltip] each, the grid's and the doll's. The open one is cream, breaking the frame `FRAME`
## columns deep and standing `TAB_OUT` past it; a shut one is tan against the frame, `TAB_SHUT_OUT` past it.
const SIDE_TABS := [["chest", "Items"], ["slot_body", "Equipment"]]
## As deep as the frame's wobble patches (`ui_notch_right_*`), which reach that far in.
const FRAME := 7
const TAB_OUT := 20
const TAB_SHUT_OUT := 18
## How far under the title bar the first tab hangs, and the air between the two.
const TAB_DROP := 6
const TAB_GAP := 1
## a is the frame's outline, d its shade, c the cream, f a shut tab's fill. The open tab's first `FRAME`
## columns lie over the frame: clear on its top and foot rows, so the frame turns into the tab's outline.
const TAB_OPEN: Array[String] = [".......aa.", "ccccccccda", "ccccccccda", "cccccccdda", ".......aa."]
const TAB_SHUT: Array[String] = ["aaa.", "afda", "afda", "adda", "aaa."]

## Whose grid and doll this page shows: the player's inventory, or on the heirlooms' page the stash
## inside it (`Inventory.stash`).
var inventory: Inventory
## Always the player's inventory: the gold, the orbs, the tips, and the one thing saved.
var _purse: Inventory
## The heirlooms' page: nothing is sold or thrown away by the level, and a Discard always asks.
var _heirlooms := false
## On `TranscendPage`'s black screen: centred, and written to no file (`_save`). Over the bag a piece
## gets no buttons and Make heirloom stands in the tray's place; over the heirlooms there is no tray.
var _transcending := false
## The black screen's stones page: only the bag's stones, the ordinary orbs, and the skill tree in the
## doll's place (`_show_tree`).
var _stones := false
## The tree's `SkillTreeView.zoom`, kept while the page draws it again.
var _tree_zoom := 0
var _make_button: Button
var _save_path: String
var _ui_scale: float
## The room the main scene hands the page, in window pixels; empty is the whole window.
var area := Rect2()

## What the counter the bag stands at buys, by `TownServices` name: the town page's open tab, not
## everything the town offers. Empty outside a town.
var _services: PackedStringArray = []

var _panel: VBoxContainer
var _filter_tabs: HBoxContainer
## A key of `FILTERS`. The session's, never saved.
var _filter := ""
var _count: Label
var _gold: Label
var _scroll: ScrollContainer
## A heading, then a grid, per level, highest first. Each square carries its item's `bag_index` meta.
var _sections: VBoxContainer
## The selected square's buttons, a cream card stood beside it (`_place_actions`).
var _actions: PanelContainer
var _action_box: VBoxContainer
## The selected bag item's index in `inventory.items`, or -1. At most one of this and `_worn_selected`
## is set.
var _selected := -1
## Item -> its rarity when the bag was last sorted, which the grid sorts by: a piece an orb lifts stays
## under the cursor until the bag is shut or opened again (`open`).
var _sorted_as := {}
## The open worn piece's `Equipment.Socket`, or -1.
var _worn_selected := -1
## The doll put away, leaving `_show_button` where it stood. The session's, never saved.
var _doll_hidden := false
var _show_button: Button
## Held upright at a counter (the main scene's `_layout_ui`): no sheet over the bag, the doll the Equipment
## tab's instead, drawn in the grid's place.
var tabbed := false:
	set(on):
		if on == tabbed:
			return
		tabbed = on
		if is_node_ready():
			refresh()
## Whether Hide may fold the doll away: never until the main scene's first steps are all taken (`_tutored`),
## which may light a worn piece under a shade that covers Show (the user's, 2026-10-30).
var foldable := true:
	set(on):
		if on == foldable:
			return
		foldable = on
		_doll_hidden = _doll_hidden and on
		if is_node_ready():
			refresh()
## The Equipment tab open. The session's, never saved.
var _equipment_tab := false
## Items and Equipment (`SIDE_TABS`), shown only while `tabbed`.
var _side_tabs: Array[Button] = []
## The press being followed, the grid's or the doll's: where it began, the grid's scroll then, and how
## far it has travelled.
var _drag_from := Vector2.ZERO
var _drag_scroll := 0
var _dragged := 0.0

var _worn_panel: PanelContainer
var _worn_body: VBoxContainer
## The doll, or null while the sheet is folded away or holds the tree.
var _doll: Doll
## The stones page's tree, or null.
var _tree: SkillTreeView

## The question standing over the page (`_ask`), or null.
var _confirm: Control

## The rule over the trays, `_fold_button` (the chevron) in its middle.
var _orb_rule: HBoxContainer
var _fold_button: Button
## The trays folded away by the chevron. The session's, never saved.
var _trays_hidden := false
var _rune_tray: HBoxContainer
var _orb_tray: HBoxContainer
var _orb_card: OrbCard
## What a spent orb rolls with. Unseeded: a test that wants a known answer seeds it.
var _craft_rng := RandomNumberGenerator.new()
## The orb or rune in hand, or "". Only ever assign it: the setter makes it the cursor and
## tells the listeners. What picks it up and puts it down: DESIGN.md, "Use an orb one way".
var _armed := "":
	set(orb):
		if orb == _armed:
			return
		_armed = orb
		var mark: Texture2D = null if orb == "" else RuneTable.icon(orb) if RuneTable.has(orb) else OrbTable.icon(orb)
		# A rune's mark is made at the tray's 16, an orb's cut at 32.
		Cursors.hold(mark, 2 if RuneTable.has(orb) else 1)
		_show_held_card()
		held_changed.emit(orb)

## A left press off any piece put the held orb down, and the redraw waits for its release (`_input`).
var _put_down := false
## The piece on the cursor (`_lift`) until the drag ends, or null: what cannot take it is dimmed.
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
	_build_top(rows)
	# The wheel is the scroll's own, a drag `_on_grid_input`'s; a worn piece off the doll drops here.
	_scroll = UITheme.scroll()
	_scroll.gui_input.connect(_on_grid_input)
	_scroll.set_drag_forwarding(Callable(), _can_drop_in_bag, _drop_in_bag)
	_scroll.get_v_scroll_bar().value_changed.connect(func(_at: float) -> void: _place_actions())
	rows.add_child(_scroll)
	_sections = UITheme.vbox(SLOT_GAP, WIDTH)
	_scroll.add_child(_sections)
	_build_trays(rows)
	if _choosing():
		_make_button = UITheme.button("Make heirloom", "LightButton", "")
		_make_button.pressed.connect(_on_make_pressed)
		rows.add_child(_make_button)

	_worn_body = UITheme.vbox(SLOT_GAP)
	_worn_panel = PanelContainer.new()
	if _stones:
		# The tree's own titled panel is the frame: the bag's twin, not the doll's wood.
		_worn_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		_worn_panel.theme_type_variation = "WoodPanel"
	_worn_panel.scale = Vector2(_ui_scale, _ui_scale)
	_worn_panel.add_child(_worn_body)
	add_child(_worn_panel)
	_show_button = UITheme.icon_button(load(SHOW_ICON), "Show what is equipped", _ui_scale)
	_show_button.pressed.connect(_on_fold_pressed)
	_show_button.hide()
	add_child(_show_button)
	for tab: Array in SIDE_TABS:
		var button := UITheme.button("", UITheme.BARE_BUTTON, tab[1])
		button.scale = Vector2(_ui_scale, _ui_scale)
		button.pressed.connect(_open_side_tab.bind(tab == SIDE_TABS[1]))
		add_child(button)
		_side_tabs.append(button)

	# Tree order is draw order: the buttons over whichever panel holds the selected square, then the
	# orb card, which overhangs the sheet.
	_actions = PanelContainer.new()
	_actions.theme_type_variation = "TextPanel"
	_actions.scale = Vector2(_ui_scale, _ui_scale)
	_actions.hide()
	_action_box = UITheme.vbox(2)
	_actions.add_child(_action_box)
	add_child(_actions)
	_orb_card = OrbCard.new()
	_orb_card.scale = Vector2(_ui_scale, _ui_scale)
	_orb_card.hide()
	add_child(_orb_card)

	# However the bag goes away (its X, another page, a fight), no orb stays on the cursor and no
	# question stays asked where nobody can answer it (`asking`).
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_armed = ""
			_sorted_as.clear()
			_close_confirm())
	refresh()


## The count and the purse on one line, then the filter's tabs.
func _build_top(rows: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", SLOT_GAP)
	top.custom_minimum_size = Vector2(WIDTH, 0)
	rows.add_child(top)
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
	_gold = UITheme.label("", Palette.TEXT_SOFT)
	top.add_child(_gold)
	_filter_tabs = HBoxContainer.new()
	_filter_tabs.add_theme_constant_override("separation", 0)
	rows.add_child(_filter_tabs)


## The footer under the grid: the rule with the chevron in its middle, then the runes over the orbs.
func _build_trays(rows: VBoxContainer) -> void:
	_orb_rule = HBoxContainer.new()
	_orb_rule.add_theme_constant_override("separation", 0)
	rows.add_child(_orb_rule)
	_orb_rule.add_child(_long_rule())
	_fold_button = UITheme.button("", UITheme.BARE_BUTTON, "")
	_fold_button.pressed.connect(func() -> void:
		_trays_hidden = not _trays_hidden
		refresh())
	_orb_rule.add_child(_fold_button)
	_orb_rule.add_child(_long_rule())
	_rune_tray = _tray_row()
	rows.add_child(_rune_tray)
	_orb_tray = _tray_row()
	rows.add_child(_orb_tray)


## A rule that takes what its row has left, level with the row's middle.
static func _long_rule() -> ColorRect:
	var line := UITheme.rule()
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return line


static func _tray_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", ORB_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.custom_minimum_size = Vector2(WIDTH, 0)
	return row


## Whether this is the bag a transcension only chooses its heirloom from.
func _choosing() -> bool:
	return _transcending and not _heirlooms and not _stones


## Whether a piece here gets no buttons and names no keys: a transcension's bag and its stones page.
func _buttonless() -> bool:
	return _transcending and not _heirlooms


## Nothing open or held, and sorted afresh. A town's tab changing comes through here too (`shop`).
func open() -> void:
	_sorted_as.clear()
	_close_confirm()
	_selected = -1
	_worn_selected = -1
	_armed = ""
	refresh()


## Stands the bag at a counter that buys `services`, or with none takes it away from one.
func shop(services: PackedStringArray) -> void:
	_services = services
	open()


## The counter's redraw of the bag: a piece opened off its shelf, put back or bought. The bag draws
## nothing of the piece itself.
func offer(_item: Item) -> void:
	refresh()


## Whether the counter the bag stands at buys this: the one place that asks. No counter buys an heirloom.
func _buys(service: String) -> bool:
	if _heirlooms and service == TownServices.GEAR:
		return false
	return service in _services


func refresh_gold() -> void:
	_gold.text = BigNumber.format(_purse.gold)


func layout() -> void:
	var room := _room()
	_worn_panel.size = _worn_panel.get_combined_minimum_size()
	_show_button.size = _show_button.get_combined_minimum_size()
	if _narrow():
		_sheet(room)
	else:
		_side_by_side(room)
	_place_side_tabs()
	_place_actions()
	laid_out.emit()


func _room() -> Rect2:
	return area if area.has_area() else get_viewport_rect()


func _narrow() -> bool:
	return UITheme.narrow(get_viewport_rect().size, _ui_scale)


## What stands by the bag: the sheet, or folded away the caret that brings it back.
func _beside() -> Control:
	return _worn_panel if _worn_panel.visible else _show_button if _show_button.visible else null


## Across a window: the bag against the room's left edge, the sheet beside it and centred down the
## room. On a transcension's screen the two stand in the room's middle, the bag `TRANSCEND_HEIGHT` of it.
func _side_by_side(room: Rect2) -> void:
	UITheme.dock(_panel, room, _ui_scale)
	var beside := _beside()
	var both := _panel.size.x + (0.0 if beside == null else WORN_GAP + beside.get_combined_minimum_size().x)
	if _transcending:
		_panel.size.y = _transcend_height(room)
		_panel.position = (room.position
				+ (room.size - Vector2(both, _panel.size.y) * _ui_scale) / 2.0).floor()
	_worn_panel.position = Vector2(_panel.position.x + (_panel.size.x + WORN_GAP) * _ui_scale,
			room.position.y + (room.size.y - _worn_panel.size.y * _ui_scale) / 2.0)
	if _stones:
		# The tree's panel is the bag's twin: level with it and as tall.
		_worn_panel.position.y = _panel.position.y
		_worn_panel.size.y = maxf(_worn_panel.size.y, _panel.size.y)
	# The caret heads the column of corner buttons that stands beside the page, so it sits at the top.
	_show_button.position = Vector2(_worn_panel.position.x, _panel.position.y + WORN_GAP * _ui_scale)


## Held upright: the bag a sheet along the foot of the room (`UITheme.dock`) and the doll's sheet
## centred straight over it; or, folded away, its caret over the bag's right end.
func _sheet(room: Rect2) -> void:
	var over := _beside()
	var lift := 0.0 if over == null else (over.size.y + WORN_GAP) * _ui_scale
	UITheme.dock(_panel, Rect2(room.position.x, room.position.y + lift, room.size.x, room.size.y - lift),
			_ui_scale, UITheme.Dock.LEFT, layout)
	# Over a counter it is pinned to the top of the window (the user's, 2026-10-29), not along its room's foot.
	if tabbed:
		_panel.position.y = room.position.y + UITheme.EDGE * _ui_scale
	_worn_panel.position = Vector2(
			floorf(room.position.x + (room.size.x - _worn_panel.size.x * _ui_scale) / 2.0),
			_panel.position.y - lift)
	_show_button.position = _panel.position + Vector2(
			(_panel.size.x - _show_button.size.x) * _ui_scale, -lift)


## The tabs down the panel's right edge under its title bar, the open one over the frame.
func _place_side_tabs() -> void:
	var at := _panel.position + Vector2(_panel.size.x - FRAME,
			(_panel.get_child(0) as Control).size.y + TAB_DROP) * _ui_scale
	for tab: Button in _side_tabs:
		var lit := (tab == _side_tabs[1]) == _equipment_tab
		tab.reset_size()
		tab.position = at + Vector2(0.0 if lit else FRAME - 1.0, 0.0) * _ui_scale
		at.y += (tab.size.y + TAB_GAP) * _ui_scale


## The least height, in window pixels, the page needs held upright: `LEAST_ROWS` of the grid, and the
## sheet over the bag. A town gives its counter what is left (the main scene's `_layout_ui`).
func least_height() -> float:
	var rows := float(LEAST_ROWS * (ItemSlot.SIDE + SLOT_GAP))
	if tabbed:
		# What either tab needs, so a turn of them never asks the counter for more: the doll stands in the
		# grid's place and the filter's.
		var filter := (_filter_tabs.get_combined_minimum_size().y
				+ UITheme.body_of(_panel).get_theme_constant("separation"))
		rows = maxf(rows, Doll.extent().y - filter) + (filter if _wearing() else 0.0)
	var tall := _panel.get_combined_minimum_size().y + rows + 2 * UITheme.EDGE
	if _worn_panel.visible:
		tall += _worn_panel.get_combined_minimum_size().y + WORN_GAP
	return tall * _ui_scale


## Where a column of buttons beside the page begins, in window pixels: `gap` past the sheet and level
## with its top; under the caret that brings the sheet back, in line with it; or `gap` past the bag
## itself at `top` where there is neither.
func column_origin(gap: float, top: float) -> Vector2:
	if _worn_panel.visible:
		return Vector2(_worn_panel.position.x + (_worn_panel.size.x + gap) * _ui_scale,
				_worn_panel.position.y)
	if _show_button.visible:
		return Vector2(_show_button.position.x,
				_show_button.position.y + (_show_button.size.y + gap) * _ui_scale)
	return Vector2(_panel.position.x + (_panel.size.x + gap) * _ui_scale, top)


## The bag panel's top-left corner in window pixels (`TranscendPage` stands its way back beside it).
func panel_corner() -> Vector2:
	return _panel.position


## Everything redrawn from the inventory, whatever was open still open.
func refresh() -> void:
	_fill_tabs()
	_fill_grid()
	_count.text = ("" if _heirlooms
			else "%d / %d" % [inventory.total(), inventory.capacity()])
	_count.add_theme_color_override("font_color", Palette.RUST
			if not _heirlooms and inventory.total() >= inventory.capacity() - NEARLY_FULL
			else Palette.TEXT_SOFT)
	refresh_gold()
	refresh_orbs()
	_refresh_make()
	_dress_side_tabs()
	_refresh_worn()
	UITheme.clear(_action_box)
	if _selected >= 0 and _selected < inventory.total():
		_show_item(_selected)
	elif _worn_selected >= 0 and inventory.equipment.item_at(_worn_selected) != null:
		_show_worn(_worn_selected)
	# Placed once the buttons have measured themselves.
	_place_actions.call_deferred()


func _fill_grid() -> void:
	UITheme.clear(_sections)
	# The doll stands in the grid's place (`_refresh_worn`).
	if _wearing():
		return
	for item in inventory.items:
		if not _sorted_as.has(item):
			_sorted_as[item] = item.rarity
	var by_level := {}
	for i in inventory.order(_sorted_as):
		if _shows(inventory.items[i]):
			by_level.get_or_add(inventory.items[i].level, []).append(i)
	var keys := _bag_keys()
	for level: int in inventory.levels():
		# A filter leaves out a level holding none of its slot, but never one holding nothing at all:
		# a level under a rule keeps its heading, the only place the rule can be undone.
		if not by_level.has(level) and inventory.count_at(level) > 0:
			continue
		_sections.add_child(_section_heading(level))
		if not by_level.has(level):
			continue
		var grid := GridContainer.new()
		grid.columns = GRID_COLS
		grid.add_theme_constant_override("h_separation", SLOT_GAP)
		grid.add_theme_constant_override("v_separation", SLOT_GAP)
		_sections.add_child(grid)
		for i: int in by_level[level]:
			var item := inventory.items[i]
			var slot := ItemSlot.make(item, i == _selected)
			slot.set_meta("bag_index", i)
			if not keys.is_empty():
				slot.set_meta(ItemCard.KEYS, keys)
			if i == _selected:
				slot.set_meta(ItemCard.BESIDE, _actions)
			_dim_for_orb(slot, item)
			# No arrow on the way out of a world: there the bag is only being chosen from.
			if not _transcending and is_upgrade(item, inventory):
				slot.add_child(_upgrade_mark())
			grid.add_child(slot)


## Whether the filter lets this piece into the grid.
func _shows(item: Item) -> bool:
	if _stones:
		return item.is_stone()
	return _filter.is_empty() or LootTable.slot_of(item.type) == _filter


## Built again with the grid: the open tab's face and mark change with it. None on the stones page,
## which is one kind already; hidden, but built, over the doll (`least_height` measures them).
func _fill_tabs() -> void:
	UITheme.clear(_filter_tabs)
	_filter_tabs.visible = not _stones and not _wearing()
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


## A level's heading on one line: its name, a rule, then Auto and the bin (DESIGN.md: "Give a level's
## heading marks, not words"). No marks on the heirlooms' page or a transcension's.
func _section_heading(level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	var ruled := inventory.autodiscards(level)
	# A level under the rule is named in red: the toggle's pressed face is too quiet to read a state off.
	var title := UITheme.label("Level %d" % level, Palette.BRICK if ruled else Palette.TEXT_SOFT, true)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)
	row.add_child(_long_rule())
	if _heirlooms or _transcending:
		return row
	var auto := UITheme.button("", UITheme.BARE_BUTTON,
			("Continue" if ruled else "Stop") + " collecting level %d loot" % level)
	auto.icon = load(AUTO_ON_ICON if ruled else AUTO_ICON)
	auto.toggle_mode = true
	auto.button_pressed = ruled
	auto.toggled.connect(_on_autodiscard_toggled.bind(level))
	row.add_child(auto)
	row.add_child(_clear_button(level))
	return row


## A level's bin, or at a counter that buys gear the coins that sell it. Either asks first.
func _clear_button(level: int) -> Button:
	var loose := _loose(level)
	var held := loose.size()
	var selling := _buys(TownServices.GEAR)
	var things := "item" if held == 1 else "items"
	var clear := UITheme.button("", UITheme.BARE_BUTTON,
			"Sell %d level %d %s for %s gold" % [held, level, things,
				BigNumber.format(TownPrices.sell_total(loose))] if selling
			else "Discard %d level %d %s" % [held, level, things])
	clear.icon = load(SELL_ICON if selling else CLEAR_ICON)
	clear.disabled = held == 0
	clear.pressed.connect(_ask.bind("sell" if selling else "clear", "Sell all" if selling else "Discard",
			clear.tooltip_text + "?", "Sell" if selling else "Discard",
			"LightButton" if selling else "LightDangerButton", _drop_level.bind(level, selling)))
	return clear


## What a level's bin or Sell all would take: a locked piece stays, and so does whatever the filter hides.
func _loose(level: int) -> Array:
	return inventory.items.filter(
			func(item: Item) -> bool: return item.level == level and not item.locked and _shows(item))


## Asks before `deed` is done, unless question `id` has been ticked away (`SKIP_CONFIRM`). `can_skip`
## false is a question asked every time, with no tick; `no` is the first button's face.
func _ask(id: String, title: String, question: String, verb: String, variation: String,
		deed: Callable, can_skip := true, no := "Cancel") -> void:
	if can_skip and SKIP_CONFIRM + id in _purse.tips:
		deed.call()
		return
	var panel := _open_confirm(title)
	var body := UITheme.body_of(panel)
	var asked := UITheme.label(question, null, true)
	asked.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	asked.custom_minimum_size.x = CONFIRM_WIDTH
	body.add_child(asked)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", SLOT_GAP)
	body.add_child(buttons)
	# Built even where it is not offered, so the verb has a tick to read.
	var skip := check_box("Don't show this again")
	skip.visible = can_skip
	body.add_child(skip)
	var tick: Button = skip.get_node(TICK_NAME)
	for yes: bool in [false, true]:
		var made := UITheme.button(verb if yes else no, variation if yes else "LightButton", "")
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Answered once: a button can still be pressed while the question shrinks away, and a second
		# press of the verb would do the deed again.
		made.pressed.connect(func() -> void:
			if Juice.leaving(panel):
				return
			_remember(id, tick.button_pressed, yes)
			_close_confirm()
			if yes:
				deed.call())
		buttons.add_child(made)
	Juice.popup(_confirm, panel, _ui_scale)


## An empty question panel in a fresh holder (`_confirm`), in the place of whatever question was up.
## The caller fills it, then brings it up: `Juice.popup(_confirm, panel, _ui_scale)`.
func _open_confirm(title: String) -> VBoxContainer:
	_close_confirm()
	_confirm = Control.new()
	add_child(_confirm)
	# Held upright the town's counter stands over the bag, and the question is centred across both.
	move_to_front()
	var panel := UITheme.titled_panel(title, "", Callable())
	panel.name = CONFIRM_PANEL
	_confirm.add_child(panel)
	return panel


## A ticked "Don't show this again". The uniques' question keeps the answer given, Sell or Keep, in the
## settings; any other only ever stops being asked, on a Yes, in the save (written by the deed's own
## save). Escape reads no tick.
func _remember(id: String, ticked: bool, yes: bool) -> void:
	if not ticked:
		return
	if id == UNIQUES:
		Settings.uniques = Settings.Uniques.SELL if yes else Settings.Uniques.KEEP
		Settings.save()
	elif yes:
		_purse.tips.append(SKIP_CONFIRM + id)


## Escape is a question's Cancel, else puts a held orb down, else shuts the open piece, and each time
## the page stays up; only a bare bag leaves the key to the main scene, which closes the page.
func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event.is_action_pressed("ui_cancel"):
		return
	if _confirm != null:
		_close_confirm()
	elif _armed != "":
		_armed = ""
		refresh()
	elif _open_piece() != null:
		_select_item(-1)
	else:
		return
	get_viewport().set_input_as_handled()


## A right click anywhere puts a held orb down, and so does a left press on anything but a piece or the
## tray. That press still goes on to do its own work, so nothing is redrawn under it (a heading's
## button would be freed before its release lands) until its release (`_put_down`). Not under a
## question, whose Use spends the orb. `_input`, not `_unhandled_input`: a panel eats a press over it.
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


## Whether a question stands over the window: the main scene holds banners and hotkeys behind it.
func asking() -> bool:
	return _confirm != null


## The question shrinks away, then goes. Let go of at once, so a deed that follows an answer, or the
## next question, never finds the old one.
func _close_confirm() -> void:
	if _confirm == null:
		return
	var holder := _confirm
	_confirm = null
	Juice.pop_out(holder.get_node(CONFIRM_PANEL), holder.queue_free)


## A tick box and its words, which press it too: a small toggled `BrownIconButton` named `TICK_NAME`,
## a cream tick on it while it is on.
static func check_box(text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	# The blank is the tick's size, so the face does not change size as it is pressed.
	var marks: Array[ImageTexture] = []
	for inks: Dictionary in [{}, {"#": UITheme.FONT_COLOR}]:
		marks.append(ImageTexture.create_from_image(UITheme.stamp(TICK, inks)))
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
			words.accept_event()  # Before the tick, which may redraw the row out of the tree (the curses).
			box.button_pressed = not box.button_pressed)
	row.add_child(words)
	return row


## Touches nothing already held: that is the bin's job.
func _on_autodiscard_toggled(on: bool, level: int) -> void:
	inventory.set_autodiscard(level, on)
	_save()
	_select_item(-1)


## A level's bin (or Sell all), once asked. The ordinary pieces go at once. The uniques go with them
## under the settings' Sell, stay under Keep, and under Ask are a second question, by name: its Don't
## sell or Escape leaves them, and its tick keeps the answer given (`_remember`).
func _drop_level(level: int, selling: bool) -> void:
	_take_level(level, selling, Settings.uniques == Settings.Uniques.SELL)
	var uniques := _loose(level).filter(
			func(item: Item) -> bool: return item.rarity == ItemRarity.Rarity.UNIQUE)
	if Settings.uniques != Settings.Uniques.ASK or uniques.is_empty():
		return
	var names := ", ".join(uniques.map(func(item: Item) -> String: return item.display_name()))
	var verb := "Sell" if selling else "Discard"
	var question := "%s %s unique. %s %s as well?" % [names, "is" if uniques.size() == 1 else "are",
			verb, "it" if uniques.size() == 1 else "them"]
	_ask(UNIQUES, "Uniques", question, verb, "LightButton" if selling else "LightDangerButton",
			_take_level.bind(level, selling, true), true, "Don't sell" if selling else "Don't discard")


## What the open filter shows of a level, sold or thrown away. Paid from what `discard_level` hands
## back, so the purse is paid for exactly what left the bag.
func _take_level(level: int, selling: bool, uniques: bool) -> void:
	var gone := inventory.discard_level(level, uniques, _filter)
	if selling:
		var paid := TownPrices.sell_total(gone)
		_purse.sell_for(paid)
		print("Sold %d item(s) at level %d for %s gold" % [gone.size(), level, BigNumber.format(paid)])
	else:
		print("Discarded %d item(s) at level %d" % [gone.size(), level])
		_salvaged(gone)
	_save()
	_select_item(-1)


## Gear thrown away pays `Inventory.salvage`, which is nothing unless the Rag and Bone Sack is worn.
func _salvaged(gone: Array[Item]) -> void:
	for item: Item in gone:
		_purse.gold += _purse.salvage(item)
		_purse.add_orb(_purse.salvage_orb())
	_purse.tick("discarded", gone.size())


## A press that stays put clicks the square under it; one that travels scrolls the grid, or lifts the
## piece it began on (`_lifts`).
func _on_grid_input(event: InputEvent) -> void:
	Cursors.over_squares(_scroll, event, _armed != "")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_from = event.position
			_drag_scroll = _scroll.scroll_vertical
			_dragged = 0.0
		elif _dragged < _slop():
			_on_clicked(event.position + Vector2(0.0, _scroll.scroll_vertical),
					event.shift_pressed, event.ctrl_pressed)
	elif _travelling(event):
		_dragged += event.relative.length()
		var index := _index_at(_drag_from + Vector2(0.0, _drag_scroll)) if _lifts() else -1
		if index < 0:
			_scroll.scroll_vertical = _drag_scroll - int(event.position.y - _drag_from.y)
		elif _dragged >= DRAG_THRESHOLD:
			_lift(inventory.items[index])


## Whether `event` is the mouse moving with its left button down and nothing on the cursor yet.
func _travelling(event: InputEvent) -> bool:
	return event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 \
			and not get_viewport().gui_is_dragging()


## How far a press may travel, in panel pixels, and still be a click: a finger wobbles more.
func _slop() -> float:
	return Cursors.TOUCH_SLOP if Cursors.touched else DRAG_THRESHOLD


## A click at `at` (the sections' own space): a held orb goes into the square under it, a bare click
## opens or shuts it, and on bare panel shuts whatever is open. Under Shift or Ctrl the square is
## opened and its own button pressed for it (`_press_action`).
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


## Every square of the grid, level after level.
func _squares() -> Array[Node]:
	var squares: Array[Node] = []
	for section: Node in _sections.get_children():
		if section is GridContainer:
			squares.append_array(section.get_children())
	return squares


## The bag index of the square under `at` (in the sections' own space), or -1 on bare panel.
func _index_at(at: Vector2) -> int:
	for slot: Control in _squares():
		if Rect2((slot.get_parent() as Control).position + slot.position, slot.size).has_point(at):
			return slot.get_meta("bag_index", -1)
	return -1


## Whether a press that travels from a piece lifts it (`_lift`) rather than scrolls: a mouse's alone,
## a finger's drag being the only scroll it has; never with an orb in hand, nor on the bag a
## transcension only chooses from, where a piece has nowhere to go.
func _lifts() -> bool:
	return not Cursors.touched and _armed == "" and not _choosing()


## `item` onto the cursor, its square centred under it, for the doll, the bag or the stones page's tree
## to take. Whatever was open shuts: no buttons stand beside a piece being dragged (the user's,
## 2026-10-09). The square leaves `ItemSlot.GROUP`, or the hover card would read it rather than
## whatever it is held over.
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


## Keeps the outline (`DROP_MARK`) on the square a drop would land in: found every frame from the
## mouse, since nothing tells a socket the cursor has left it mid-drag.
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


## The square under the mouse that would take `_lifted` were it let go now: a doll socket, or a slot of
## the stones page's tree inside the box it scrolls in. Null with neither.
func _drop_square() -> Control:
	if _doll != null and _doll.is_visible_in_tree():
		var at := _doll.get_local_mouse_position()
		if _can_drop_on_doll(at, _lifted):
			return _doll.squares[_doll.socket_at(at)]
	if _tree != null and _tree.is_visible_in_tree() \
			and (_tree.get_parent() as Control).get_global_rect().has_point(get_global_mouse_position()):
		var at := _tree.get_local_mouse_position()
		if _can_drop_on_tree(at, _lifted):
			return _tree.squares[_tree.slot_at(at)]
	return null


## The three places a lifted piece drops (`set_drag_forwarding`). Each drop calls the button's own
## handler, so every refusal is the button's.
func _can_drop_on_doll(at: Vector2, data: Variant) -> bool:
	var socket := _doll.socket_at(at)
	return data is Item and socket >= 0 and inventory.items.has(data) and inventory.can_equip(data, socket)


func _drop_on_doll(at: Vector2, data: Variant) -> void:
	_on_equip_pressed(data, _doll.socket_at(at))


func _can_drop_in_bag(_at: Vector2, data: Variant) -> bool:
	return data is Item and inventory.equipment.worn.find_key(data) != null and not inventory.is_full()


func _drop_in_bag(_at: Vector2, data: Variant) -> void:
	_on_unequip_pressed(inventory.equipment.worn.find_key(data))


func _can_drop_on_tree(at: Vector2, data: Variant) -> bool:
	var path: Variant = _tree.slot_at(at)
	return data is Item and path is String and inventory.items.has(data) \
			and SkillTree.can_place(data, path, _purse.skills.stones)


func _drop_on_tree(at: Vector2, data: Variant) -> void:
	_place(data, _tree.slot_at(at))


## Which keys a click on a bag square answers to, for the hover card's foot.
func _bag_keys() -> Dictionary:
	if _buttonless():
		return {}
	return {"shift": "equip", "ctrl": "sell" if _buys(TownServices.GEAR) else "discard"}


## A Shift-click's Equip or Unequip, a Ctrl-click's Sell or Discard: the open square's own button,
## pressed, so every refusal and every question is the button's. A grey button leaves the square open
## with the reason on it.
func _press_action(shift: bool) -> void:
	var verbs := ["Equip", "Unequip"] if shift else ["Sell", "Discard"]
	var buttons := _action_box.get_children()
	# A ring's Shift-click goes on the emptiest finger, whichever of its two buttons that is.
	for button: Node in buttons:
		if button.has_meta(EMPTIEST):
			buttons.push_front(button)
			break
	for button: Node in buttons:
		if button is Button and not (button as Button).disabled \
				and verbs.any(func(verb: String) -> bool: return (button as Button).text.begins_with(verb)):
			(button as Button).pressed.emit()
			return


## -1 shuts whatever is open.
func _select_item(index: int) -> void:
	_select(index, -1)


## -1 shuts whatever is open.
func _select_socket(socket: int) -> void:
	_select(-1, socket)


## Every change of selection puts a held orb down: an open piece and an orb in hand never stand together.
func _select(index: int, socket: int) -> void:
	_selected = index
	_worn_selected = socket
	_armed = ""
	refresh()
	selection_changed.emit(_open_piece())


## A bag item's buttons, stacked: Equip (a ring's two), Sell or Discard, Never sell. No Back: the
## square pressed again, or bare panel, is the way out.
func _show_item(index: int) -> void:
	if _buttonless():
		return
	var item := inventory.items[index]
	_add_equip(item)
	# One button, Sell or Discard, never both. Neither asks (but an heirloom's Discard, every time):
	# two clicks deep already, and asking twice teaches clicking through.
	if _buys(TownServices.GEAR):
		var price := TownPrices.sell_price(item)
		var sell := UITheme.priced_button("Sell", price, "LightButton",
				"Never sell is on" if item.locked
				else "Sell this to the merchant for %s gold" % BigNumber.format(price))
		sell.disabled = item.locked
		sell.pressed.connect(_on_sell_pressed.bind(item))
		_add_action(sell)
	else:
		var discard := UITheme.button("Discard", "LightDangerButton", "Discard this for good")
		if _heirlooms:
			discard.pressed.connect(_ask.bind("discard_heirloom", "Discard",
					"Discard %s for good? The choice that made it an heirloom does not come back."
					% item.display_name(), "Discard", "LightDangerButton",
					_on_discard_pressed.bind(item), false))
		else:
			discard.pressed.connect(_on_discard_pressed.bind(item))
		_add_action(discard)
	if not _heirlooms:
		# "Never sell", never "Lock", which is the smith's word. Green while on, as Auto is.
		var lock := UITheme.button("Never sell", UITheme.GO_BUTTON if item.locked else "LightButton",
				"Let Sell all and the bin take this again" if item.locked
				else "Sell all and the bin pass this by")
		lock.icon = ItemSlot.lock_texture()
		lock.toggle_mode = true
		lock.button_pressed = item.locked
		lock.toggled.connect(_on_lock_toggled.bind(item))
		_add_action(lock)


## Equip, one a socket the piece fits: a ring gets Equip left over Equip right, always in that order
## (the user's pick, 2026-10-29, over a Swap that turned one Equip between fingers).
func _add_equip(item: Item) -> void:
	var sockets := inventory.equipment.sockets_for(item)
	var in_order := sockets.duplicate()
	in_order.sort()
	for socket: Equipment.Socket in in_order:
		# The tooltip is the only place the player is told what the press takes off before pressing: a
		# two-hander hands back the offhand as well.
		var coming_off := PackedStringArray()
		for piece: Item in inventory.equipment.displaced_by(socket, item):
			coming_off.append(piece.display_name())
		# Greyed, with the reason, rather than destroying a piece to make room for what comes off.
		var refusal := inventory.why_not_equip(item, socket)
		var label: String = Equipment.LABELS[socket]
		var face := "Equip" if sockets.size() == 1 else "Equip " + label.get_slice(" ", 0).to_lower()
		var equip := UITheme.button(face, "LightButton", refusal if not refusal.is_empty()
				else "Wear this in the %s slot%s" % [label.to_lower(),
					"" if coming_off.is_empty() else ", putting %s back in the bag" % ", ".join(coming_off)])
		equip.disabled = not refusal.is_empty()
		equip.pressed.connect(_on_equip_pressed.bind(item, socket))
		if socket == sockets[0]:
			equip.set_meta(EMPTIEST, true)
		_add_action(equip)


func _add_action(button: Button) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_box.add_child(button)


func _on_lock_toggled(on: bool, item: Item) -> void:
	item.locked = on
	_save()
	refresh()


## A worn piece's one button, greyed on a full bag rather than destroying something to make room. No
## Discard: the cap is the bag's alone, so nothing pushes the player to destroy what they wear.
func _show_worn(socket: Equipment.Socket) -> void:
	if _buttonless():
		return
	var full := inventory.is_full()
	var unequip := UITheme.button("Unequip", "LightButton",
			"The bag is full" if full else "Take this off and put it back in the bag")
	unequip.disabled = full
	unequip.pressed.connect(_on_unequip_pressed.bind(socket))
	_add_action(unequip)


## The buttons stood beside the selected square, bag or doll, or put away: with nothing selected, with
## nothing to press, or while the square is scrolled out of the grid.
func _place_actions() -> void:
	var square := _selected_square()
	var shown := square != null and _action_box.get_child_count() > 0
	if shown and _scroll.is_ancestor_of(square):
		shown = _scroll.get_global_rect().has_point(square.get_global_rect().get_center())
	_actions.visible = shown
	if not shown:
		return
	_actions.reset_size()
	# Beside a doll socket the card keeps to the page: past the sheet stands a town's own panel, which
	# would cover it, so there it flips left over the figure instead. Tabbed, the town is under the bag.
	var window := get_viewport_rect().size
	if square.has_meta("socket") and not tabbed:
		window.x = _worn_panel.position.x + _worn_panel.size.x * _ui_scale
	_actions.position = ItemCard.beside(square.get_global_rect(),
			_actions.get_combined_minimum_size() * _ui_scale, window, ItemCard.GAP * _ui_scale)


## The square the selection points at, in the grid or on the doll, or null.
func _selected_square() -> Control:
	if _selected >= 0:
		for slot: Control in _squares():
			if slot.get_meta("bag_index", -1) == _selected:
				return slot
	elif _worn_selected >= 0 and _doll != null:
		return _doll.squares.get(_worn_selected)
	return null


## Make heirloom, at the foot of a transcension's bag: live while the open piece, bag or worn, can be
## made one.
func _refresh_make() -> void:
	if _make_button == null:
		return
	var item := _open_piece()
	_make_button.disabled = not _purse.can_make_heirloom(item)
	_make_button.tooltip_text = ("Open the item you would keep" if item == null
			else "This item is broken" if item.broken else "Keep this when the world is left behind")


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


## Every write the page makes. Nothing without a path: a transcension's pages have none, the main scene
## making that one write as the black screen is left.
func _save() -> void:
	if not _save_path.is_empty():
		_purse.save(_save_path)


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
		_salvaged([item])
		_save()
	_select_item(-1)


## Priced and taken out first, paid for second, so a piece no longer in the bag is never paid for.
func _on_sell_pressed(item: Item) -> void:
	var price := TownPrices.sell_price(item)
	if inventory.remove(item):
		_purse.sell_for(price)
		print("Sold %s (%s, level %d) for %s gold"
				% [item.type, item.rarity_name(), item.level, BigNumber.format(price)])
		_save()
	_select_item(-1)


## The sheet redrawn: the doll (the stones page's tree), or folded away only the caret that brings it
## back. What a selected piece would replace is never written here: that is the hover card's, under Alt.
func _refresh_worn() -> void:
	_doll = null
	_tree = null
	UITheme.clear(_worn_body)
	_worn_panel.visible = not _doll_hidden and not tabbed
	_show_button.visible = _doll_hidden and not tabbed
	if _wearing():
		UITheme.clear(_sections)
		_show_doll(_sections)
	elif _worn_panel.visible:
		if _stones:
			_show_tree()
		else:
			_show_doll(_worn_body)
	# Measured again deferred: a container's minimum is only right once it has laid out its new children.
	layout()
	layout.call_deferred()


## The doll into `holder`, its squares dressed for what is selected, held or on the cursor, and Hide in its
## corner on the sheet; centred in the grid's place, where the tab is the way back.
func _show_doll(holder: VBoxContainer) -> void:
	_doll = Doll.new(inventory.equipment, _worn_selected)
	_doll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_doll.gui_input.connect(_on_doll_input)
	_doll.set_drag_forwarding(Callable(), _can_drop_on_doll, _drop_on_doll)
	for socket: Equipment.Socket in _doll.squares:
		var slot: ItemSlot = _doll.squares[socket]
		var item := inventory.equipment.item_at(socket)
		if item != null and not _buttonless():
			slot.set_meta(ItemCard.KEYS, {"shift": "unequip"})
		if socket == _worn_selected:
			slot.set_meta(ItemCard.BESIDE, _actions)
		_dim_for_orb(slot, item)
		# A bag piece on the cursor dims every socket its Equip would refuse.
		if _lifted != null and inventory.items.has(_lifted) and not inventory.can_equip(_lifted, socket):
			slot.modulate = OrbSlot.DIM
	holder.add_child(_doll)
	if holder != _worn_body or not foldable:
		return
	# Hide, in the corner the figure leaves empty. Anchored and grown leftwards because a button's
	# size is not known until the theme reaches it.
	var fold := UITheme.button("", "BrownIconButton", "Hide what is equipped")
	fold.icon = load(HIDE_ICON)
	fold.anchor_left = 1.0
	fold.anchor_right = 1.0
	fold.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	fold.pressed.connect(_on_fold_pressed)
	_doll.add_child(fold)


## The skill tree in the doll's place, on the stones page: under a bar of its own, and scaled into the
## room `_tree_height` leaves it. What its presses and drops do: `_on_tree_pressed`, `_place`.
func _show_tree() -> void:
	# The stone on the cursor, else the one open in the bag, rings the slots it may go in.
	var held := _lifted if _lifted != null else _open_piece()
	var view := SkillTreeView.new()
	_tree = view
	view.zoom = _tree_zoom
	view.slot_pressed.connect(_on_tree_pressed)
	view.set_drag_forwarding(Callable(), _can_drop_on_tree, _drop_on_tree)
	view.fill(_purse.skills, false, held if held != null and held.is_stone() else null)
	for path: String in view.squares:
		if _purse.skills.stones.has(path):
			_dim_for_orb(view.squares[path], _purse.skills.stones[path])
	var framed := UITheme.titled_panel(SkillsPage.TITLE, "", Callable())
	framed.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# No X, but as tall a bar as the bag's beside it, which has one.
	(UITheme.title_of(framed).get_parent() as Control).custom_minimum_size.y = UITheme.icon_size("CloseButton").y
	_worn_body.add_child(framed)
	# Thin bars once zoomed past its box, as on the skills page.
	var scroll := UITheme.scroll()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.add_child(view)
	# The − and + float over the tree's top-right corner: a row of their own would take height the tree
	# needs, and often the whole step `fit` scales by.
	var over := MarginContainer.new()
	over.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.body_of(framed).add_child(over)
	over.add_child(scroll)
	var zoom := SkillTreeView.zoom_buttons(view)
	zoom.size_flags_horizontal = Control.SIZE_SHRINK_END
	zoom.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	zoom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over.add_child(zoom)
	# The bar and the frame: the panel less what stands in the scroll's place, the − and + included.
	var chrome := framed.get_combined_minimum_size() - over.get_combined_minimum_size()
	var room := _room()
	var most := Vector2(room.size.x / _ui_scale - 2 * UITheme.EDGE, _tree_height(room)) - chrome
	if not _narrow():
		most.x -= _panel.get_combined_minimum_size().x + WORN_GAP
	scroll.custom_minimum_size = view.fit(most, _ui_scale).min(most)
	# Kept, so the next redraw draws the tree at the same zoom.
	view.zoomed.connect(func() -> void: _tree_zoom = view.zoom)


## Panel pixels the tree's panel may stand: across a window the bag's height on the black screen; held
## upright what is left above the bag once it is docked (`UITheme.dock`: as tall as it holds, half the
## window at most).
func _tree_height(room: Rect2) -> float:
	if not _narrow():
		return _transcend_height(room)
	var most := minf(room.size.y, get_viewport_rect().size.y / 2.0) / _ui_scale - 2 * UITheme.EDGE
	return room.size.y / _ui_scale - 2 * UITheme.EDGE - minf(UITheme.natural_height(_panel), most) - WORN_GAP


## The bag's height on the black screen across a window: `TRANSCEND_HEIGHT` of what the edges leave.
func _transcend_height(room: Rect2) -> float:
	return floorf((room.size.y / _ui_scale - 2 * UITheme.EDGE) * TRANSCEND_HEIGHT)


## A press on the tree's slot `path`: an orb in hand goes into the stone placed there; otherwise the
## stone open in the bag goes in, if it may.
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


## A click on a filled socket opens it, a second shuts it. Counted as it lets go, as the grid's is, so
## that a mouse's press that travels lifts the piece instead (`_lift`).
func _on_doll_input(event: InputEvent) -> void:
	Cursors.over_squares(_doll, event, _armed != "")
	if _travelling(event):
		_dragged += event.relative.length()
		var lifted := _doll.worn_at(_drag_from)
		if lifted >= 0 and _lifts() and _dragged >= DRAG_THRESHOLD:
			_lift(inventory.equipment.item_at(lifted))
		return
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Before anything redraws the doll out of the tree: freed under its own press, it would let the
	# press through to the map behind it.
	_doll.accept_event()
	var press := event as InputEventMouseButton
	if press.pressed:
		_drag_from = press.position
		_dragged = 0.0
		return
	var socket := _doll.worn_at(press.position)
	if socket < 0 or _dragged >= _slop():
		return
	if _armed != "":
		_orb_on(inventory.equipment.item_at(socket))
	elif press.shift_pressed or press.ctrl_pressed:
		_select_socket(socket)
		_press_action(press.shift_pressed)
	else:
		_select_socket(-1 if socket == _worn_selected else socket)


func _on_fold_pressed() -> void:
	_doll_hidden = not _doll_hidden
	refresh()


## Whether the doll stands in the grid's place: `tabbed`, with the Equipment tab open.
func _wearing() -> bool:
	return tabbed and _equipment_tab


## Items or Equipment: what was open shuts, as at any other change of selection.
func _open_side_tab(equipment: bool) -> void:
	_equipment_tab = equipment
	_select(-1, -1)


## The tabs' faces and marks for which is open (`TAB_OPEN`, `TAB_SHUT`), a shut one lit cream under the mouse.
func _dress_side_tabs() -> void:
	for i in _side_tabs.size():
		var tab := _side_tabs[i]
		tab.visible = tabbed
		var lit := (i == 1) == _equipment_tab
		tab.icon = load(FILTER_MARK % [SIDE_TABS[i][0], "green" if lit else "brown"])
		var wide := FRAME + TAB_OUT if lit else 1 + TAB_SHUT_OUT
		# The mark in the middle of what stands past the frame, short of the right edge's two columns.
		var left := (FRAME if lit else 1) + floorf((wide - (FRAME if lit else 1) - 2 - tab.icon.get_width()) / 2.0)
		var top := floorf((TownPage.TAB_SIDE - tab.icon.get_height()) / 2.0)
		for state: String in UITheme.STATES:
			var rows := TAB_OPEN if lit else TAB_SHUT
			var face := StyleBoxTexture.new()
			face.texture = ImageTexture.create_from_image(UITheme.stamp(rows, {"a": Palette.TEXT,
					"d": Palette.TEXT_SOFT, "c": Palette.PANEL_CREAM,
					"f": Palette.PANEL_CREAM if state == "hover" else Palette.SLOT_TAN}))
			face.texture_margin_left = rows[0].length() - 3
			face.texture_margin_right = 2
			face.texture_margin_top = 1
			face.texture_margin_bottom = 2
			face.content_margin_left = left
			face.content_margin_right = wide - left - tab.icon.get_width()
			face.content_margin_top = top
			face.content_margin_bottom = TownPage.TAB_SIDE - top - tab.icon.get_height()
			tab.add_theme_stylebox_override(state, face)


## The piece the bag has open, bag item or worn, or null.
func _open_piece() -> Item:
	if _selected >= 0 and _selected < inventory.total():
		return inventory.items[_selected]
	if _worn_selected >= 0:
		return inventory.equipment.item_at(_worn_selected)
	return null


## Where `item` stands, its grid square or its socket on the doll, or null: what a first step lights
## (`main_scene._step_target`), as are `action`, `tray_square` and `orb_in_hand`.
func square_of(item: Item) -> Control:
	for slot: Node in _squares():
		if (slot as ItemSlot).item == item:
			return slot
	if _doll != null:
		for socket: Equipment.Socket in _doll.squares:
			if inventory.equipment.item_at(socket) == item:
				return _doll.squares[socket]
	return null


## The open piece's button that reads `text`, or null.
func action(text: String) -> Button:
	for button: Node in _action_box.get_children():
		if button is Button and (button as Button).text == text:
			return button
	return null


## The tray's square for `orb`, or null.
func tray_square(orb: String) -> Control:
	for slot: Node in _orb_tray.get_children():
		if (slot as OrbSlot).orb == orb:
			return slot
	return null


## The orb in hand, or "".
func orb_in_hand() -> String:
	return _armed


## The trays redrawn: every orb lit whatever is open, since an orb is picked up, never spent on the
## open piece.
func refresh_orbs() -> void:
	UITheme.clear(_orb_tray)
	UITheme.clear(_rune_tray)
	_rune_tray.hide()
	_fold_button.hide()
	# The square the card described has just been freed.
	_show_held_card()
	if _transcending and not _stones:
		# No tray over a transcension's bag or its heirlooms.
		_orb_tray.hide()
		_orb_rule.hide()
		return
	# No tray until the first orb; once seen it stays, even with every orb spent. The runes the same,
	# on the ordinary bag alone, and with them the chevron that folds both rows away.
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


func _tray_slot(orb: String, count: int) -> OrbSlot:
	var slot := OrbSlot.make(orb, count, true, orb == _armed)
	slot.picks_up = true
	slot.pressed.connect(_on_orb_pressed)
	slot.hovered.connect(_on_orb_hovered.bind(slot))
	slot.unhovered.connect(_show_held_card)
	return slot


## `CHEVRON` in the button brown, flipped to point up when `up`. Made once.
static func _chevron(up: bool) -> ImageTexture:
	if _chevrons.is_empty():
		for flip: bool in [false, true]:
			var image := UITheme.stamp(CHEVRON, {"#": Palette.BUTTON_BROWN})
			if flip:
				image.flip_y()
			_chevrons.append(ImageTexture.create_from_image(image))
	return _chevrons[int(up)]


## The rune in hand pressed on the map's tile at world `spot`, which carries `own` modifiers (the main
## scene calls this): spent where it does something (`Inventory.use_rune`), saved, and kept in hand
## while any are left, as an orb is. Returns whether it was spent.
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


## A press in the tray picks the orb up, or puts the held one down. With a piece open it shuts the
## piece first (the user's rule, 2026-10-01): an orb is never spent on the open piece.
func _on_orb_pressed(orb: String) -> void:
	if _count_of(orb) <= 0:
		return
	if _open_piece() != null:
		# Which puts down whatever was held, so the press always picks this one up.
		_select_item(-1)
	_armed = "" if orb == _armed else orb
	refresh()


## How many of `orb` (or the rune) the player has to spend.
func _count_of(orb: String) -> int:
	return _purse.rune_count(orb) if RuneTable.has(orb) else _purse.orb_count(orb)


## The held orb on a piece that is not the bag's: one off a vendor's shelf. `written` is called between
## the change and the save, so whoever owns the piece writes it down in the same write the orb is
## spent in.
func craft_held(item: Item, written: Callable) -> void:
	if _armed != "":
		_craft(_armed, item, written)


## The held orb pressed on one of the player's own pieces: in the bag, worn, or a stone in the tree.
## Under a finger the first tap only puts the piece's card up, and the next spends the orb
## (`Cursors.applies`).
func _orb_on(item: Item) -> void:
	if Cursors.applies(item):
		_craft(_armed, item)


## An orb that would take a piece down a rarity asks first, with a tick to stop asking (the user's,
## 2026-10-02): one misplaced Transmutation is an epic gone. Anything else is done at once.
func _craft(orb: String, item: Item, written := Callable()) -> void:
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
	_spent(orb, item, _purse.orb_count(_armed))


## What follows an orb going into `item`, `left` of the held one remaining: put down with the last,
## the page redrawn, heard and told (`crafted`).
func _spent(orb: String, item: Item, left: int) -> void:
	print("Spent %s on %s (%s, level %d)" % [orb, item.display_name(), item.rarity_name(), item.level])
	if left <= 0:
		_armed = ""
	refresh()
	_orb_applied()
	crafted.emit(orb)


## Silent where the orb had nothing to do: only a spent one is heard.
func _orb_applied() -> void:
	for layer: AudioStream in ORB_APPLIED_SOUNDS:
		Juice.sound(layer)


## Whether wearing `item` loses nothing and gains something against what Equip would take off (the
## emptiest socket it fits, both hands for a two-hander; nothing on a bare socket). A swap that trades
## one stat for another gets no mark, and nor does a piece Equip would refuse (`Inventory.can_equip`):
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


## The arrow in a square's top-right corner that says `is_upgrade`.
static func _upgrade_mark() -> TextureRect:
	if _upgrade_texture == null:
		_upgrade_texture = ImageTexture.create_from_image(
				UITheme.stamp(UPGRADE, {"#": Palette.LEAF_LT, "o": Palette.INK}))
	var mark := TextureRect.new()
	mark.name = UPGRADE_NAME
	mark.texture = _upgrade_texture
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.position = Vector2(ItemSlot.SIDE - UPGRADE[0].length() - 1, 1)
	return mark


## A square the held orb can do nothing to goes as grey as an orb with nothing to do.
func _dim_for_orb(slot: Control, item: Item) -> void:
	if _armed != "" and item != null and not OrbTable.can_apply(_armed, item):
		slot.modulate = OrbSlot.DIM


## Placed now and again deferred: the first pass measures labels that have not laid out yet.
func _on_orb_hovered(orb: String, slot: OrbSlot) -> void:
	_orb_card.fill(orb, _count_of(orb))
	_orb_card.show()
	_place_orb_card(slot.get_global_rect())
	_place_orb_card.call_deferred(slot.get_global_rect())


## Under a finger the orb in hand keeps its card up, centred at the window's top, clear of the pieces it
## is pressed on (the user's, 2026-10-29); otherwise the card goes. A held finger's read of another orb
## stands it by that square until the finger lifts.
func _show_held_card() -> void:
	if _orb_card == null:
		return
	if not Cursors.touched or _armed == "":
		_orb_card.hide()
		return
	_orb_card.fill(_armed, _count_of(_armed))
	_orb_card.show()
	_place_held_card()
	_place_held_card.call_deferred()


## Where the held orb's card at the window's top ends (`_show_held_card`), in window pixels, or 0.
func held_card_bottom() -> float:
	return _orb_card.get_global_rect().end.y if _orb_card.visible and Cursors.touched and _armed != "" else 0.0


func _place_held_card() -> void:
	if not _orb_card.visible or _armed == "":
		return
	var card := _orb_card.get_combined_minimum_size() * _ui_scale
	_orb_card.global_position = Vector2(roundf((get_viewport_rect().size.x - card.x) / 2.0),
			SLOT_GAP * _ui_scale)


## Above the square: the screen edge is on one side of the tray and the sheet on the other.
func _place_orb_card(anchor: Rect2) -> void:
	if not _orb_card.visible:
		return
	var card := _orb_card.get_combined_minimum_size() * _ui_scale
	var spot := Vector2(anchor.position.x, anchor.position.y - card.y - SLOT_GAP * _ui_scale)
	_orb_card.position = spot.clamp(Vector2.ZERO, (get_viewport_rect().size - card).max(Vector2.ZERO))
