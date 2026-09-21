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
## The page has measured itself again, and `right_edge` may have moved: the sheet beside the bag
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
const AUTO_ICON := "res://Assets/UI/ui_icon_filter.png"
const CLEAR_ICON := "res://Assets/UI/ui_icon_trash.png"
const SELL_ICON := "res://Assets/UI/ui_icon_coins.png"
const SWAP_ICON := "res://Assets/UI/ui_icon_swap.png"
## Hide points back at the bag the comparison folds into, Show out to where it opens.
const HIDE_ICON := "res://Assets/UI/ui_icon_caret_left.png"
const SHOW_ICON := "res://Assets/UI/ui_icon_caret_right.png"
const AUTO_HELD := Color(0.6, 0.6, 0.6)
## What goes in front of a question's id in `inventory.tips` once the player has said not to ask it
## again, how wide the question is set, and its tick box: the node's name and the mark it wears.
const SKIP_CONFIRM := "skip_confirm_"
const CONFIRM_WIDTH := 150.0
const TICK_NAME := "Tick"
const TICK: Array[String] = [
	"......#",
	".....##",
	"#...##.",
	"##.##..",
	".###...",
	"..#....",
]
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
## The smallest whole number that keeps 40 px sockets on the head, chest and feet from touching.
const DOLL_SCALE := 3.0
## The comparison is as wide as the bag, so the two stat blocks wrap alike.
const WORN_WIDTH := WIDTH
## And what it gives way to while the bag stands in a town, where a third panel wants the same window.
## A 1152 px window at ui_scale 2 is 576 panel pixels. It was sized when the bag was five squares
## wide (240 with its margins), which with `WORN_GAP` 6 and the town page's 160 left 170 for this
## panel and 146 inside it. At four squares the bag takes 195 and there is slack to spare.
## ponytail: kept at 146 rather than re-laid; the counter's special case in `_show_compare` can go
## if this is raised to WORN_WIDTH and a ring's heading still fits beside Swap and Hide.
## See `Scenes/Town/DESIGN.md`.
const SHOP_WORN_WIDTH := 146.0
## The air between the bag panel and the sheet.
const WORN_GAP := 6.0
## How much of the window's height the bag takes on a transcension's black screen.
const TRANSCEND_HEIGHT := 0.7
## Each socket's centre in the doll sprite's own pixels, before DOLL_SCALE. Measured off the sprite:
## head y 0-16 on x 14-27, chest y 17-33, feet y 34-45, shield hand x 0-8, sword hand x 37-40. The
## jewellery sits in a row below the figure.
const DOLL_SOCKETS := {
	Equipment.Socket.HELMET: Vector2(21, 8),
	Equipment.Socket.OFFHAND: Vector2(4, 26),
	Equipment.Socket.BODY: Vector2(21, 25),
	Equipment.Socket.WEAPON: Vector2(38, 25),
	Equipment.Socket.BOOTS: Vector2(21, 41),
	Equipment.Socket.RING_LEFT: Vector2(4, 58),
	Equipment.Socket.AMULET: Vector2(21, 58),
	Equipment.Socket.RING_RIGHT: Vector2(38, 58),
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
## piece opens to no Equip and no Discard and **Make heirloom** stands at the foot in the tray's
## place; over the heirlooms it is the super orbs (`SuperOrbTable`), which are the tray.
var _transcending := false
var _make_button: Button
var _save_path: String
var _ui_scale: float

## What the counter the bag is standing at buys, by `TownServices` name -- the town page's open tab
## and not everything the town offers, so the gear merchant's Sell button and the orb vendor's tray
## are never both live at once. Empty everywhere else, which is what leaves Discard as Discard and the
## tray as crafting alone.
var _services: PackedStringArray = []
## That town's cell, which is what an orb is worth there.
var _town_cell := Vector2i.ZERO
## The piece the counter beside the bag has open for sale, or null. It is not in the bag and never
## becomes selected here; all it does is point the comparison at what buying it would replace.
var _offered: Item

var _panel: VBoxContainer
var _count: Label
var _gold: Label
var _scroll: ScrollContainer
## One heading, rule and grid per level, highest first. Each square carries its item's `bag_index`.
var _sections: VBoxContainer
## The stat block: lines that scroll, and buttons under them that do not.
var _detail: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail_rows: VBoxContainer
## The open bag item as an index into `inventory.items`, or -1. At most one of this and
## `_worn_selected` is set: both open into the grid's place.
var _selected := -1
## The open worn piece as an `Equipment.Socket`, or -1.
var _worn_selected := -1
## Which of the sockets the open piece fits is the one judged and the one Equip fills: an index into
## `sockets_for`, moved by the comparison's Swap and back to the emptiest with every new selection.
var _socket_pick := 0
## The sheet put away, doll or comparison, leaving `_show_button` in its place. Kept for the session, not saved.
var _compare_hidden := false
## Stands against the bag's edge where the hidden comparison was, and brings it back.
var _show_button: Button
var _drag_from := Vector2.ZERO
var _drag_scroll := 0
var _dragged := 0.0

var _worn_panel: PanelContainer
var _worn_body: VBoxContainer
## The doll, while the sheet is showing it rather than a comparison.
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
	_count = UITheme.label()
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_count)
	var coin := TextureRect.new()
	coin.texture = Coins.icon()
	coin.custom_minimum_size = Vector2(Coins.SIZE, Coins.SIZE)
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	top.add_child(coin)
	# Slate rather than GOLD: amber on cream is too weak a pairing.
	_gold = UITheme.label("", Palette.SLATE)
	top.add_child(_gold)

	# Wheel scrolling is the container's, dragging is `_on_grid_input`'s; no bar is drawn.
	_scroll = _scroll_box()
	_scroll.gui_input.connect(_on_grid_input)
	rows.add_child(_scroll)
	_sections = UITheme.vbox(SLOT_GAP, WIDTH)
	_scroll.add_child(_sections)

	_detail = UITheme.vbox(2, WIDTH)
	_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail.hide()
	rows.add_child(_detail)
	_detail_scroll = _scroll_box()
	_detail.add_child(_detail_scroll)
	_detail_rows = UITheme.vbox(2, WIDTH)
	_detail_scroll.add_child(_detail_rows)

	# The tray comes after both expanding children, so it is a footer under whichever is up.
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

	# After the sheet: it hangs over the sheet for most of the tray, and tree order decides who is on top.
	_orb_card = OrbCard.new()
	_orb_card.scale = Vector2(_ui_scale, _ui_scale)
	_orb_card.hide()
	add_child(_orb_card)

	# However the bag goes away -- its X, another page, a fight -- an orb must not stay on the cursor.
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_armed = "")
	refresh()


## Opens on the grid, never on a stat block left over from last time.
func open() -> void:
	_close_confirm()
	_selected = -1
	_worn_selected = -1
	_armed = ""
	refresh()


## Stands the bag at a counter that buys `services`, or takes it away from one with none. The bag is
## where a sale happens rather than a second grid on the town page: what the player wants to sell is
## already laid out here, and two grids of the same items is two places to hunt through.
func shop(services: PackedStringArray, town_cell := Vector2i.ZERO) -> void:
	_services = services
	_town_cell = town_cell
	_offered = null
	open()


## Points the comparison at what the counter has open for sale, and redraws around it -- so a piece
## on a vendor's shelf is judged against what is worn, which is the question a shop is read to
## answer. null puts it back to the bag's own selection, and a purchase arrives the same way: the
## purse, the grid and the tray are all redrawn by the same call.
func offer(item: Item) -> void:
	_offered = item
	_socket_pick = 0
	refresh()


## Whether the town the bag is standing in buys this. False everywhere outside one.
func _buys(service: String) -> bool:
	# No counter buys an heirloom, so beside one Discard stays Discard and a level has no coins.
	if _heirlooms and service == TownServices.GEAR:
		return false
	return service in _services


func refresh_gold() -> void:
	_gold.text = BigNumber.format(_purse.gold)


## The bag stretched to the window's height, and the sheet centred against its right edge. At a
## transcension the two stand in the middle of the window instead, the bag `TRANSCEND_HEIGHT` of it.
func layout() -> void:
	var view_size := get_viewport_rect().size
	_panel.size = Vector2(_panel.get_combined_minimum_size().x, view_size.y / _ui_scale)
	_panel.position = Vector2.ZERO
	_worn_panel.size = _worn_panel.get_combined_minimum_size()
	if _transcending:
		_panel.size.y = floorf(_panel.size.y * TRANSCEND_HEIGHT)
		var beside: Control = (_worn_panel if _worn_panel.visible
				else _show_button if _show_button.visible else null)
		var width := _panel.size.x + (0.0 if beside == null else WORN_GAP + beside.size.x)
		_panel.position = ((view_size - Vector2(width, _panel.size.y) * _ui_scale) / 2.0).floor()
	_worn_panel.position = Vector2(_panel.position.x + (_panel.size.x + WORN_GAP) * _ui_scale,
			(view_size.y - _worn_panel.size.y * _ui_scale) / 2.0)
	_show_button.size = _show_button.get_combined_minimum_size()
	_show_button.position = Vector2(_worn_panel.position.x,
			(view_size.y - _show_button.size.y * _ui_scale) / 2.0)
	_place_confirm()
	laid_out.emit()


## Where the page ends, in window pixels: past the sheet beside the bag, or past the caret that
## brings it back, or at the bag itself where there is neither.
func right_edge() -> float:
	var last: Control = (_worn_panel if _worn_panel.visible
			else _show_button if _show_button.visible else _panel)
	return last.position.x + last.size.x * _ui_scale


## The bag panel's top-left corner in window pixels: the origin but on a transcension's screen, where
## `TranscendPage` stands its way back beside it.
func panel_corner() -> Vector2:
	return _panel.position


## Where the sheet beside the bag begins, in window pixels, so what stands past it can stand level
## with it; `fallback` while the sheet is away.
func sheet_top(fallback: float) -> float:
	return _worn_panel.position.y if _worn_panel.visible else fallback


static func _scroll_box() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return scroll


## Everything redrawn from the inventory, reopening whatever was open.
func refresh() -> void:
	# Cleared at once: the click hit-test walks these children, and a queued square is still one.
	UITheme.clear(_sections)
	var by_level := {}
	for i in inventory.order():
		by_level.get_or_add(inventory.items[i].level, []).append(i)
	for level: int in inventory.levels():
		_sections.add_child(_section_heading(level))
		_sections.add_child(UITheme.rule())
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
			_dim_for_orb(slot, inventory.items[i])
			grid.add_child(slot)
	_count.text = ("%d to spend" % _purse.super_orbs if _heirlooms and _transcending
			else str(inventory.total()) if _heirlooms
			else "%d / %d" % [inventory.total(), Inventory.CAPACITY])
	_count.add_theme_color_override("font_color", Palette.RUST if inventory.is_full() else Palette.SLATE)
	refresh_gold()
	refresh_orbs()
	_refresh_make()
	_refresh_worn()
	if _selected >= 0 and _selected < inventory.total():
		_show_item(_selected)
	elif _worn_selected >= 0 and inventory.equipment.item_at(_worn_selected) != null:
		_show_worn(_worn_selected)
	else:
		_hide_item()


## A level's heading: its name, Auto (a funnel that stays down while the level is being thrown away
## as it drops) and Clear (a bin: drop what is held).
func _section_heading(level: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", SLOT_GAP)
	# The rule is said in words and colour: the toggle's pressed face is too quiet to read a state off.
	var ruled := inventory.autodiscards(level)
	var title := UITheme.label("Level %d auto" % level if ruled else "Level %d" % level,
			Palette.RUST if ruled else Palette.SLATE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	# An heirloom never arrives by dropping and is never thrown away by the handful: no marks. Nor on
	# the way out of a world, where the bag is only being chosen from.
	if _heirlooms or _transcending:
		return row

	var auto := UITheme.button("", "BrownIconButton",
			"Auto is on: what is found at level %d is thrown away. Press to stop" % level if ruled
			else "Auto: throw away everything found at level %d from now on" % level)
	auto.icon = load(AUTO_ICON)
	auto.toggle_mode = true
	auto.button_pressed = ruled
	# Held down is the pack's pressed face, a pixel lower -- and darkened as well, because that pixel
	# alone is a press being watched and not a state being read off a column of headings.
	if ruled:
		auto.self_modulate = AUTO_HELD
	auto.toggled.connect(_on_autodiscard_toggled.bind(level))
	row.add_child(auto)

	# In a town that buys gear the same button sells the handful instead of destroying it: it is the
	# same act -- being done with a level -- and the merchant is simply a better way to do it.
	var held := inventory.count_at(level)
	var selling := _buys(TownServices.GEAR)
	var worth := TownPrices.sell_total(inventory.items.filter(
			func(item: Item) -> bool: return item.level == level)) if selling else 0.0
	# A mark either way, coins for selling and a bin for throwing away; the tooltip says the sum.
	var clear := UITheme.button("", "BrownIconButton",
			"Sell the %d item(s) held at level %d for %s gold"
			% [held, level, BigNumber.format(worth)] if selling
			else "Throw away the %d item(s) held at level %d" % [held, level])
	clear.icon = load(SELL_ICON if selling else CLEAR_ICON)
	clear.disabled = held == 0
	# Both ask first: a whole level goes in one press, and neither can be taken back.
	if selling:
		clear.pressed.connect(_ask.bind("sell", "Sell all", clear.tooltip_text + "?", "Sell",
				"LightButton", _on_sell_level_pressed.bind(level)))
	else:
		clear.pressed.connect(_ask.bind("clear", "Throw away", clear.tooltip_text + "?", "Discard",
				"LightDangerButton", _on_clear_level_pressed.bind(level)))
	row.add_child(clear)
	return row


## Asks before `deed` is done, over everything else on the page, unless the player has ticked this
## question's "Don't show this again" -- which is kept per question (`id`) in `inventory.tips`, the
## save's list of what the player has already been told, and only a Yes writes it. `can_skip` false is
## a question that is asked every time and offers no tick: an heirloom is runs of work.
func _ask(id: String, title: String, question: String, verb: String, variation: String,
		deed: Callable, can_skip := true) -> void:
	if can_skip and SKIP_CONFIRM + id in _purse.tips:
		deed.call()
		return
	_close_confirm()
	# The whole window, so nothing under the question can be pressed while it is up.
	_confirm = Control.new()
	_confirm.size = get_viewport_rect().size
	add_child(_confirm)
	var panel := UITheme.titled_panel(title, "Cancel", _close_confirm)
	panel.scale = Vector2(_ui_scale, _ui_scale)
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
	for made: Button in [UITheme.button("Cancel", "LightButton", ""), UITheme.button(verb, variation, "")]:
		made.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		buttons.add_child(made)
	buttons.get_child(0).pressed.connect(_close_confirm)
	buttons.get_child(1).pressed.connect(func() -> void:
		if (skip.get_node(TICK_NAME) as Button).button_pressed:
			_purse.tips.append(SKIP_CONFIRM + id)   # written by the deed's own save
		_close_confirm()
		deed.call())
	# Built either way, so the Yes above has a tick to read; only shown where it may be ticked.
	skip.visible = can_skip
	body.add_child(skip)
	# Twice: a wrapped label only knows how tall it is once it has been laid out once.
	_place_confirm()
	_place_confirm.call_deferred()


func _place_confirm() -> void:
	if _confirm == null:
		return
	_confirm.size = get_viewport_rect().size
	var panel: Control = _confirm.get_child(0)
	panel.size = panel.get_combined_minimum_size()
	panel.position = ((_confirm.size - panel.size * _ui_scale) / 2.0).floor()


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


## A right click anywhere puts a held orb down, as Escape does. `_input` rather than `_unhandled_input`:
## a press over a panel is handled by the panel and would never reach the other.
func _input(event: InputEvent) -> void:
	if _armed != "" and event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_armed = ""
		refresh()


func _close_confirm() -> void:
	if _confirm != null:
		remove_child(_confirm)
		_confirm.queue_free()
		_confirm = null


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
	var gone := inventory.discard_level(level)
	print("Discarded %d item(s) at level %d" % [gone.size(), level])
	# The Rag and Bone Sack pays for what is thrown away, which is nothing unless it is worn.
	for item: Item in gone:
		_purse.gold += _purse.salvage(item)
	_save()
	_select_item(-1)


## A whole level over the counter. The price is summed off what `discard_level` hands back, so the
## purse is paid for exactly what left the bag rather than for what was in it a moment ago.
func _on_sell_level_pressed(level: int) -> void:
	var gone := inventory.discard_level(level)
	var paid := TownPrices.sell_total(gone)
	_purse.gold += paid
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
		elif _dragged < DRAG_THRESHOLD:
			_on_clicked(event.position + Vector2(0.0, _scroll.scroll_vertical))
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged += absf(event.relative.y)
		_scroll.scroll_vertical = _drag_scroll - int(event.position.y - _drag_from.y)


## Opens the square under `at` (in the sections' own space), or closes the block on bare panel.
func _on_clicked(at: Vector2) -> void:
	for section: Node in _sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Control in section.get_children():
			if Rect2((section as Control).position + slot.position, slot.size).has_point(at):
				var index: int = slot.get_meta("bag_index", -1)
				if _armed != "":
					_craft(_armed, inventory.items[index])
				else:
					_select_item(-1 if index == _selected else index)
				return
	_select_item(-1)


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


## A bag item's block, with Back, Equip (into the emptiest socket it fits) and Discard in one row:
## stacked, the three of them were a quarter of the page.
func _show_item(index: int) -> void:
	var item := inventory.items[index]
	var open_sockets := inventory.equipment.sockets_for(item)
	_fill_detail(item)
	var actions := _action_row(_select_item.bind(-1))
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
		var full := not inventory.can_equip(item, socket)
		var equip := UITheme.button("Equip", "LightButton", "The bag is full" if full
				else "Wear this in the %s socket%s" % [Equipment.LABELS[socket].to_lower(),
					"" if coming_off.is_empty()
					else ", putting %s back in the bag" % ", ".join(coming_off)])
		equip.disabled = full
		equip.pressed.connect(_on_equip_pressed.bind(item, socket))
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(equip)
	# In a town that buys gear, the button that got rid of a piece sells it instead: one button in one
	# place, so there is never a Discard sitting next to a Sell for the player to press by mistake.
	# No confirmation either way: two clicks deep already, and asking twice teaches clicking through.
	if _buys(TownServices.GEAR):
		var price := TownPrices.sell_price(item)
		var sell := UITheme.priced_button("Sell", price, "LightButton",
				"Sell this to the merchant for %s gold" % BigNumber.format(price))
		sell.pressed.connect(_on_sell_pressed.bind(item))
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(sell)
	else:
		var discard := UITheme.button("Discard", "LightDangerButton", "Throw this away for good")
		# An heirloom is asked about every time, with no tick to stop the asking.
		if _heirlooms:
			discard.pressed.connect(_ask.bind("discard_heirloom", "Throw away",
					"Throw away %s for good? The choice that made it an heirloom does not come back."
					% item.display_name(), "Discard", "LightDangerButton",
					_on_discard_pressed.bind(item), false))
		else:
			discard.pressed.connect(_on_discard_pressed.bind(item))
		discard.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(discard)


## A worn piece's block. No Discard: the cap is the bag's alone, so nothing pushes the player to
## destroy what they wear.
func _show_worn(socket: Equipment.Socket) -> void:
	_fill_detail(inventory.equipment.item_at(socket))
	var actions := _action_row(_select_socket.bind(-1))
	if _transcending and not _heirlooms:
		return
	var unequip := _unequip_button(_on_unequip_pressed.bind(socket))
	unequip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(unequip)


## Make heirloom, at the foot of a transcension's bag: live while the piece that is open, bag piece
## or worn, can be made one.
func _refresh_make() -> void:
	if _make_button == null:
		return
	var item := _open_piece()
	_make_button.disabled = not _purse.can_make_heirloom(item)
	_make_button.tooltip_text = ("Open the piece you would keep" if item == null
			else Blacksmith.BROKEN if item.broken else "Keep this when the world is left behind")


func _on_make_pressed() -> void:
	var item := _open_piece()
	if item != null:
		_ask("heirloom", "Heirloom", "Make %s an heirloom? It is the one piece of this world you keep."
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


## The lines go inside the scroll and the buttons outside it, so Equip is never scrolled away.
func _fill_detail(item: Item) -> void:
	UITheme.clear(_detail, _detail_scroll)
	ItemDetails.fill(_detail_rows, item, WIDTH)
	_detail_scroll.scroll_vertical = 0


## The row under an open piece, begun with Back at its own width; what is added after it should
## expand to share the rest.
func _action_row(back_action: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	var back := UITheme.back_button("Back to everything you are carrying")
	back.pressed.connect(back_action)
	row.add_child(back)
	_detail.add_child(row)
	_scroll.hide()
	_detail.show()
	return row


func _hide_item() -> void:
	_detail.hide()
	_scroll.show()


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
		_save()
	_select_item(-1)


## One piece over the counter. Priced and taken out first, paid for second, so a piece that was no
## longer in the bag can never be paid for twice.
func _on_sell_pressed(item: Item) -> void:
	var price := TownPrices.sell_price(item)
	if inventory.remove(item):
		_purse.gold += price
		print("Sold %s (%s, level %d) for %s gold"
				% [item.type, item.rarity_name(), item.level, BigNumber.format(price)])
		_save()
	_select_item(-1)


## The sheet redrawn: the comparison while a bag item is open, the doll otherwise.
func _refresh_worn() -> void:
	_doll = null
	UITheme.clear(_worn_body)
	# What is being judged: the counter's piece first, because the shelf is where the player is
	# looking while one is open there, and the bag's own selection otherwise.
	var judged := _offered
	if judged == null and _selected >= 0 and _selected < inventory.total():
		judged = inventory.items[_selected]
	# On a transcension's screen the sheet is always the doll: a worn piece is as good a choice as a
	# carried one, and nothing there is being weighed against what is worn.
	if _transcending:
		judged = null
	# In a town the page on the far edge needs the room, and the doll is the one thing on this side
	# that can go without taking a decision with it: the comparison is what says whether to sell, and
	# nothing is worn while the bag is being emptied over a counter. **The smith is the exception:**
	# he works on a worn piece as readily as a carried one, so there the doll is the decision, and it
	# is how the player hands him what they are wearing.
	_worn_panel.visible = (judged != null or _services.is_empty()
			or TownServices.SMITH in _services)
	# Hidden, the whole sheet goes, doll or comparison, and only the way back to it stays.
	_show_button.visible = _compare_hidden and _worn_panel.visible
	if _show_button.visible:
		_worn_panel.hide()
	elif judged != null:
		_show_compare(judged)
	elif _worn_panel.visible:
		_show_doll()
	# The two states differ in size. Measured again deferred: a container's minimum is only right once
	# it has laid out its new children.
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
		else:
			_select_socket(-1 if socket == _worn_selected else socket)
		return


## What the open item would replace: the socket Equip targets, so the page shows exactly what
## pressing it would take off.
func _show_compare(item: Item) -> void:
	var open_sockets := inventory.equipment.sockets_for(item)
	if open_sockets.is_empty():
		_show_doll()
		return
	_worn_panel.theme_type_variation = "TextPanel"
	var width: float = SHOP_WORN_WIDTH if not _services.is_empty() else WORN_WIDTH
	_worn_body.custom_minimum_size = Vector2(width, 0)
	var socket: Equipment.Socket = open_sockets[_socket_pick % open_sockets.size()]
	# Swap and Hide sit beside the heading where there is room for them. At a counter there is not --
	# heading and marks together run past `SHOP_WORN_WIDTH` -- so there they take a row under the rule.
	var heading := UITheme.vbox(2)
	var title := HBoxContainer.new()
	var label := UITheme.label("Equipped · %s" % Equipment.LABELS[socket], Palette.SLATE)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_child(label)
	heading.add_child(title)
	heading.add_child(UITheme.rule(width))
	_worn_body.add_child(heading)
	var tools := title
	if not _services.is_empty():
		tools = HBoxContainer.new()
		tools.alignment = BoxContainer.ALIGNMENT_END
		_worn_body.add_child(tools)
	# Only a ring has a second finger to go on. Swap moves Equip with it (`_show_item` reads the same
	# pick), so the page still shows exactly what pressing Equip would take off.
	if open_sockets.size() > 1:
		var swap := UITheme.button("", "BrownIconButton", "Look at the other ring, and equip over that one")
		swap.icon = load(SWAP_ICON)
		swap.pressed.connect(_on_swap_pressed)
		tools.add_child(swap)
	var fold := UITheme.button("", "BrownIconButton", "Hide what is equipped")
	fold.icon = load(HIDE_ICON)
	fold.pressed.connect(_on_fold_pressed)
	tools.add_child(fold)
	# What the press would take off, which is the socket's own piece and, for a two-hander, the offhand
	# with it -- so the page never says "Nothing worn" over a greatsword the swap would cost. Each
	# block carries the Unequip that belongs to *it*, or the second one would take the wrong piece off.
	var losing := inventory.equipment.displaced_by(socket, item)
	if losing.is_empty():
		_worn_body.add_child(ItemDetails.line("Nothing worn", Palette.SLATE, width))
		return
	for piece: Item in losing:
		# Its own box: ItemDetails.fill empties whatever it is given.
		var column := UITheme.vbox(2)
		ItemDetails.fill(column, piece, width)
		_worn_body.add_child(column)
		var from: Equipment.Socket = inventory.equipment.worn.find_key(piece)
		_worn_body.add_child(_unequip_button(_on_compare_unequip_pressed.bind(item, from)))


func _on_swap_pressed() -> void:
	_socket_pick += 1
	refresh()


func _on_fold_pressed() -> void:
	_compare_hidden = not _compare_hidden
	refresh()


## Keeps the judged piece open, found again by identity: the piece coming back moves every index.
func _on_compare_unequip_pressed(item: Item, socket: Equipment.Socket) -> void:
	if inventory.unequip(socket):
		_save()
	_select_item(inventory.items.find(item))


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
	# With a vendor beside the bag and no piece open, the square is a sale; with a piece open it is a
	# craft, exactly as it always was. So standing in a town never costs the player the crafting tray,
	# and closing the piece they have open is the whole of how they switch between the two.
	# Anywhere else a press with no piece open picks the orb up (`_armed`), and a second one puts it down.
	if item == null:
		if _buys(TownServices.ORBS):
			_sell_orb(orb)
		else:
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
	add_child(_confirm)
	var panel := UITheme.titled_panel(orb, "Cancel", _close_confirm)
	panel.scale = Vector2(_ui_scale, _ui_scale)
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
	_place_confirm()
	_place_confirm.call_deferred()


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
	_save()
	print("Spent %s on %s (%s, level %d)" % [orb, item.display_name(), item.rarity_name(), item.level])
	if _purse.orb_count(_armed) <= 0:
		_armed = ""
	refresh()
	if _open_piece() == null:
		crafted.emit()


## A square the held orb can do nothing to goes as grey as an orb with nothing to do (`OrbSlot.DIM`).
func _dim_for_orb(slot: Control, item: Item) -> void:
	if _armed != "" and item != null and not OrbTable.can_apply(_armed, item):
		slot.modulate = OrbSlot.DIM


## One orb over the counter. Spent first and paid second, the way crafting applies first and spends
## second: `spend_orb` is false when there is none to spend, so nothing is ever paid for an orb the
## player does not have.
func _sell_orb(orb: String) -> void:
	var price := TownPrices.orb_sell_price(orb, _town_cell)
	if not _purse.spend_orb(orb):
		return
	_purse.gold += price
	print("Sold %s for %s gold" % [orb, BigNumber.format(price)])
	_save()
	refresh()


## What a vendor beside the bag pays for one of these, and 0 where none does -- which is what the card
## reads to decide whether to quote a price or count what is held.
func _orb_price(orb: String) -> float:
	return TownPrices.orb_sell_price(orb, _town_cell) if _buys(TownServices.ORBS) else 0.0


## Placed now and again deferred: the first pass measures labels that have not laid out yet.
func _on_orb_hovered(orb: String, slot: OrbSlot) -> void:
	_orb_card.fill(orb, _purse.super_orbs if SuperOrbTable.has(orb) else _purse.orb_count(orb),
			_open_piece(), _orb_price(orb))
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
