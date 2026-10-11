class_name TownPage
extends Control
## The settlement the player stands in, on the right edge in the tile panel's place: a tab a counter,
## and under the open tab what that counter has -- a vendor's six squares with their prices, the
## smith's two prices for the piece the bag has open, the board's postings, the fortuneteller's spells.
## Buying is here; selling is the bag's, beside it. The rules are `Scenes/Town/`'s, and why the page is
## laid out as it is is `Scenes/Town/DESIGN.md`. It hangs straight off a `CanvasLayer`, so it carries
## `UITheme.theme()` itself.

signal closed
## Another counter was opened: the bag beside the page sells only what the open one buys.
signal tab_changed(service: String)
## The piece open off the shelf, or null for the shelf itself. Null again after every deed: that is how
## the bag hears the purse, the grid or the tray moved, and it keeps what it has open.
signal offer_changed(item: Item)
## The fortuneteller was paid to put the star over the chest on `cell`. The star is the main scene's.
signal chest_bought(cell: Vector2i)
## A bounty or a cleared board paid this piece, said before the bag or the log hears of it, so the main
## scene can raise the banner a unique new to the log gets.
signal item_claimed(item: Item)
## This much experience was paid and is already banked: the main scene fills the bar with it.
signal xp_claimed(amount: int)
## A bounty on `enemy` was handed in and all it paid is already in the purse, the tray and the bag:
## `orbs` is name -> count, `piece` null for none.
signal bounty_paid(enemy: String, gold: float, xp: int, orbs: Dictionary, piece: Item)
## The board's Reward was pressed: the main scene puts a cleared board's three options back up.
signal choice_asked
## A posting was taken on and saved.
signal bounty_accepted
## The roads lifted settlements out of the dark: the map has changed and wants saving.
signal towns_revealed
## A spell aimed at the map was asked for, at `price`, in the town on `spot`. Nothing is charged or
## written here: the main scene does both, and marks that town's drawer, once land has been chosen.
signal spell_aimed(reading: String, price: float, spot: Vector2i)
## The way out's question was answered yes. Nothing is charged: the purse is left behind anyway.
signal transcend_pressed

## The shelf is three squares across, and that sets `BODY_WIDTH`, the page's width: a budget shared
## with the bag and the doll, not taste (`Scenes/Town/DESIGN.md`, "Making the counter obvious").
const STOCK_COLS := 3
const STOCK_GAP := 8
## A square and the price under it. Wider than the square: the price sets it.
const STOCK_CELL := ItemSlot.SIDE + 4
const BODY_WIDTH := STOCK_COLS * STOCK_CELL + (STOCK_COLS - 1) * STOCK_GAP
const ROW_GAP := 8
## The coin beside a price on a square: half the sprite's 16, a whole-number step.
const PRICE_COIN := 8

const TAB_GAP := 2
## A tab's width and the open one's height; a shut one stands `TAB_RISE` lower. `TAB_CORNER` rounds a
## tab's two top corners.
const TAB_SIDE := 22
const TAB_RISE := 3
const TAB_CORNER := 2
const TAB_SHUT := Color(Palette.SLOT_TAN, 0.45)
const TAB_SHUT_HOVER := Color(Palette.SLOT_TAN, 0.8)
## Each counter's mark on its tab (`tab_mark`): `TAB_MARK` % [its name here, "brown" or "green"].
const TAB_ICONS := {
	TownServices.BOUNTIES: "scroll",
	TownServices.GEAR: "sword",
	TownServices.ORBS: "gem",
	TownServices.SMITH: "anvil",
	TownServices.FORTUNE: "crystal",
}
const TAB_MARK := "res://Assets/UI/ui_icon_%s_%s.png"
## Not the tabs': how far a row that cannot be taken now is faded -- a posting while another bounty is
## out, and `TranscendPage`'s curse the skulls cannot pay for.
const TAB_REST := Color(1, 1, 1, 0.55)

## Every service there is gets a tab. One added there with no counter here is a logged error (`_fill`).
const COUNTERS := TownServices.ORDER

const FORTUNE_ICONS := {
	FortuneTeller.ROADS: "res://Assets/Fortune/roads.png",
	FortuneTeller.TREASURE: "res://Assets/Fortune/treasure.png",
	FortuneTeller.APPRAISE: "res://Assets/Fortune/appraise.png",
	FortuneTeller.SCOUR: "res://Assets/Fortune/scour.png",
	FortuneTeller.HOMECOMING: "res://Assets/Fortune/homecoming.png",
	FortuneTeller.TRANSCEND: "res://Assets/Fortune/transcend.png",
	# A stand-in: the retired Relic reading's badge, which is a unique's mark on a bounty card too.
	FortuneTeller.BANISH: "res://Assets/Fortune/relic.png",
}
## A spell's 16 px mark is drawn doubled, a whole-number step.
const SPELL_SIDE := 32
## A live spell square under the cursor: a gold stylebox grown `HOVER_GLOW` px past it and drawn behind
## the mark, so a rim of light shows round it, and the mark lifted by `HOVER_LIFT`.
const HOVER_GLOW := 3
const HOVER_GLOW_COLOR := Color(Palette.GOLD, 0.85)
const HOVER_LIFT := Color(1.2, 1.2, 1.2)

## A spell square's tooltip: what the spell does, as an outcome -- no name before it, never how it is
## asked for and never how often it was (the user's rule, 2026-09-25).
const FORTUNE_TIPS := {
	FortuneTeller.ROADS: "Brings every settlement between the ice walls around you, "
			+ "and the land beside it, out of the fog",
	FortuneTeller.TREASURE: "Puts a star over the nearest chest you have not seen. It stays until that chest is opened",
	FortuneTeller.APPRAISE: "Lists every modifier the open item can roll, "
			+ "the range it rolls in at the item's level, and how often it comes up",
	FortuneTeller.SCOUR: "Brings a tile and the two rings of land around it, nineteen tiles, out of the fog",
	FortuneTeller.HOMECOMING: "Moves you to a settlement or the Gollux cave you have already charted",
	FortuneTeller.TRANSCEND: "Ends this world and starts a new one, worth far more",
	# Nothing of the doubling (the user's, 2026-10-10): the price under the square says it has climbed.
	FortuneTeller.BANISH: "Keeps a unique you choose from dropping in this world",
}

## `SKIP_TOLD + reading` in `inventory.tips`: that reading's answer was ticked "Don't show this again".
const SKIP_TOLD := "skip_told_"
const TOLD_WIDTH := 180.0
## What stands round her answer's scroll inside the window: its title bar, its padding, and the Dismiss
## and the tick under it.
const TOLD_CHROME := 100.0
const TOLD_PANEL := "Panel"
## The banishing screen's arrow back to her spells, named for the tests.
const BANISH_BACK := "Back"

## Her warning before the way out is taken, in her own voice. It never says what waits (the user's).
const TRANSCEND_LINES := [
	"The ice takes this world back, and you wake up in another.",
	"You'll lose the bag, the gold, the orbs, the levels and the land. You'll say it was worth it. They always do.",
]

var inventory: Inventory
## The main scene's map, set from outside. The board and the fortuneteller read it; with none she
## refuses every spell and the board posts nothing.
var view: MapBuilder
## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()
## The bag's own `craft_held(item, written)`, set from outside (see `_held`).
var craft_held: Callable
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _title: Label
var _rows: VBoxContainer
## The town: its cell (what everything here is priced against), its world spot (where a spell aimed at
## the map is cast from), its `TownWorld.Tier` (what a Restock stocks the shelf as) and its drawer in
## the save (`TownState.visit`), written in place so a purchase is saved with the purse it came out of.
var _cell := Vector2i.ZERO
var _spot := Vector2i.ZERO
var _tier := -1
var _drawer := {}
## The nearest unseen chest as the town was walked into: finding it scans the whole map, and the
## player does not move while the page is up.
var _near_chest := HexMap.NO_CELL
## The counters with a tab, in `TownServices.ORDER`, and which of them is open.
var _tabs: PackedStringArray = []
var _open_tab := ""
## The piece off the shelf the page has open, and the square it stands on there.
var _offer: Item
var _offer_at := -1
## What the bag has open, carried or worn (`bag_changed`): the piece the smith works on.
var _bag_piece: Item
## The orb the bag has in hand ("" for none, `orb_held`): a press on a shelf piece spends it there
## through `craft_held` instead of opening the piece. The orb, the purse and the save stay the bag's.
var _held := ""
var _orb_card: OrbCard
## That the hammer broke the piece now up, said on the page: the one thing here nobody asked for.
var _smith_note := ""
var _swing := SmithSwing.new()
## Her answer over the whole window (null while none is up), and the scroll it is written in.
var _told: Control
var _told_scroll: ScrollContainer
## The counter's one scroll and what it holds, kept through every redraw so a deed leaves it where the
## player had it. `_scroll_for` is what it was last filled for: anything else puts it back at the top.
var _scroll: ScrollContainer
var _scroll_lines: VBoxContainer
var _scroll_for := []
## The last reading cast whose answer is ticked away: said in one line under her grids instead.
var _cast := ""
## Her banishing's screen is up in her list's place; the unique picked on it ("" for none); and where
## the press on its grid went down (one that travels is a finger scrolling).
var _banishing := false
var _banish_pick := ""
var _banish_press := Vector2.INF
## What a shelf is rolled with and a break drawn against. Unseeded: a test that wants a known one
## seeds it.
var _stock_rng := RandomNumberGenerator.new()
var _smith_rng := RandomNumberGenerator.new()


func _init(player_inventory: Inventory, save_path: String, ui_scale: float) -> void:
	inventory = player_inventory
	_save_path = save_path
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Town", "Leave the town", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	_title = UITheme.title_of(_panel)
	_rows = UITheme.body_of(_panel)
	_rows.add_theme_constant_override("separation", ROW_GAP)
	# Her answer goes with the page however it goes: left up, it would still hold every hotkey and
	# banner that asks `telling`.
	visibility_changed.connect(func() -> void:
		if not is_visible_in_tree():
			_close_told())
	_scroll = UITheme.scroll()
	_rows.add_child(_scroll)
	_scroll_lines = UITheme.vbox(0, BODY_WIDTH)
	# At least as tall as the scroll, so a row that asks to expand (an accepted bounty's card) can.
	_scroll_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# The scroll clips, and a shelf square's frame stands `FRAME_HEAD` above it.
	var headroom := MarginContainer.new()
	headroom.add_theme_constant_override("margin_top", ItemRarity.FRAME_HEAD)
	headroom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	headroom.add_child(_scroll_lines)
	_scroll.add_child(headroom)
	# After the panel, so it is drawn over it.
	_orb_card = OrbCard.new()
	_orb_card.scale = Vector2(_ui_scale, _ui_scale)
	_orb_card.hide()
	add_child(_orb_card)


## Redraws the page for the town at `cell`, whose world spot is `spot` and whose tier is a
## `TownWorld.Tier`. A service with no counter here gets no tab. This is also the one place a town's
## shelves are first stocked and its board posted.
func open(town_name: String, services: PackedStringArray, cell: Vector2i, spot: Vector2i,
		tier: int) -> void:
	_cell = cell
	_spot = spot
	_tier = tier
	_put_away()
	_near_chest = view.nearest_chest(true) if view != null else HexMap.NO_CELL
	_title.text = town_name if not town_name.is_empty() else "Town"
	_drawer = inventory.towns.visit(spot)
	# Both are asked, so not `or`, which would skip the board whenever the shelves had news.
	var stocked := VendorStock.restock(_drawer, tier, cell, _stock_rng, inventory.walls_ever())
	var posted := BountyBoard.restock(_drawer, _board_land(), cell, _stock_rng, inventory.walls_ever())
	if stocked or posted:
		inventory.save(_save_path)
	_tabs = PackedStringArray()
	for service: String in services:
		if service in COUNTERS:
			_tabs.append(service)
	if not (_open_tab in _tabs):
		_open_tab = "" if _tabs.is_empty() else _tabs[0]
	# Nothing is open in the bag until it says so.
	_bag_piece = null
	_scroll_for = []
	_close_offer(false)


func open_tab() -> String:
	return _open_tab


func has_counter(service: String) -> bool:
	return service in _tabs


## The bag beside the counter changed what it has open. Selling and discarding both close what was
## open, so this is also how the counter hears the bag and the purse moved: a Buy greyed by a full bag
## comes back live as a piece is sold from under it.
func bag_changed(open_piece: Item) -> void:
	if not visible:
		return
	_bag_piece = open_piece
	_smith_note = ""
	_refresh()


## The bag picked an orb up or put it down: the shelf greys what it cannot go into.
func orb_held(orb: String) -> void:
	_held = orb if craft_held.is_valid() else ""
	redraw()


## Draws the open counter again, for a change made off this page (a bounty given up on the journal).
func redraw() -> void:
	if visible:
		_refresh()


func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.RIGHT, layout)
	_place_told()


func _process(delta: float) -> void:
	_swing.tick(delta)


func _refresh() -> void:
	_fill()
	layout()


## The end of every deed that moved the purse, the tray or the bag: saved, drawn again, and the bag
## told to draw itself again (`offer_changed`).
func _deed_done() -> void:
	inventory.save(_save_path)
	_refresh()
	offer_changed.emit(null)


## A new town or another counter puts away what the last one was saying.
func _put_away() -> void:
	_smith_note = ""
	_cast = ""
	_banishing = false
	_close_told()


## Why the purse or the bag refuses this, or "" when neither does. `needs_room` is for what goes in
## the bag, which is never added to when full (`Scenes/Town/CLAUDE.md`); an orb is a count and needs none.
func _why_not(price: float, needs_room: bool) -> String:
	if inventory.gold < price:
		return "Not enough gold"
	if needs_room and inventory.is_full():
		return "The bag is full"
	return ""


func _fill() -> void:
	UITheme.clear(_rows, _scroll)
	UITheme.clear(_scroll_lines)
	_scroll.hide()
	_rows.add_child(_tab_row())
	if _open_tab.is_empty():
		_rows.add_child(_sign("Nobody here is trading yet."))
		return
	# The open counter is named in words too -- but not over a piece held up to the smith, whose name
	# heads him.
	if not (_open_tab == TownServices.SMITH and _bag_piece != null):
		_rows.add_child(UITheme.label(TownServices.label(_open_tab)))
	match _open_tab:
		TownServices.BOUNTIES:
			_fill_board()
		TownServices.SMITH:
			_fill_smith()
		TownServices.FORTUNE:
			_fill_fortune()
		TownServices.GEAR, TownServices.ORBS:
			if _offer != null:
				_fill_offer()
			else:
				_fill_vendor()
		_:
			# A service this page was never taught: said, never drawn as a gear shelf with a Restock.
			push_error("TownPage has no counter for \"%s\"" % _open_tab)


## The tabs and the line they stand on, one thing with no gap: the line runs under every shut tab,
## through the gaps and out to the page's edge, and breaks under the open one.
func _tab_row() -> HBoxContainer:
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	tabs.custom_minimum_size.x = BODY_WIDTH
	var group := ButtonGroup.new()
	for service: String in _tabs:
		if tabs.get_child_count() > 0:
			tabs.add_child(tab_line(TAB_GAP))
		var lit := service == _open_tab
		var tab := UITheme.button("", UITheme.BARE_BUTTON, TownServices.label(service))
		tab.icon = tab_mark(service, lit)
		tab_faces(tab, lit)
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = lit
		tab.pressed.connect(_on_tab_pressed.bind(service))
		tabs.add_child(tab)
	var rest := tab_line(0)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(rest)
	return tabs


func _on_tab_pressed(service: String) -> void:
	_open_tab = service
	_put_away()
	_close_offer(true)
	tab_changed.emit(service)


## The counter's scroll, with `gap` between its rows. What is added to the box returned scrolls; what
## is added to `_rows` after this call stays pinned under it, in reach.
func _scrolled(gap: int) -> VBoxContainer:
	_rows.move_child(_scroll, _rows.get_child_count() - 1)
	_scroll.show()
	_scroll_lines.add_theme_constant_override("separation", gap)
	if [_open_tab, _offer, _banishing] != _scroll_for:
		_scroll_for = [_open_tab, _offer, _banishing]
		_scroll.scroll_vertical = 0
	return _scroll_lines


## The foot of a screen standing in a counter's place: the arrow back, then its one verb. Returns the arrow.
func _back_row(tooltip: String, on_back: Callable, verb: Button) -> Button:
	var row := HBoxContainer.new()
	var back := UITheme.back_button(tooltip)
	back.pressed.connect(on_back)
	row.add_child(back)
	verb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(verb)
	_rows.add_child(row)
	return back


static func tab_mark(service: String, lit: bool) -> Texture2D:
	return load(TAB_MARK % [TAB_ICONS[service], "green" if lit else "brown"])


## Dresses `tab` as a folder tab `side` wide (the bag's filter tabs and the leaderboards' wear it too),
## framed on three sides. A shut one stands lower, washed in tan, on the line; the open one stands full
## height in the page's own cream with no bottom edge, so it runs on into the counter under it.
static func tab_faces(tab: Button, lit: bool, side := TAB_SIDE) -> void:
	tab.custom_minimum_size = Vector2(side, TAB_SIDE if lit else TAB_SIDE - TAB_RISE)
	tab.size_flags_vertical = Control.SIZE_SHRINK_END
	tab.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if lit:
		var face := _tab_face(Color.TRANSPARENT, false)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			tab.add_theme_stylebox_override(state, face)
		return
	var shut := _tab_face(TAB_SHUT, true)
	for state: String in ["normal", "pressed", "hover_pressed", "disabled"]:
		tab.add_theme_stylebox_override(state, shut)
	tab.add_theme_stylebox_override("hover", _tab_face(TAB_SHUT_HOVER, true))
	tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


static func _tab_face(fill: Color, floor_line: bool) -> StyleBoxFlat:
	var face := StyleBoxFlat.new()
	face.bg_color = fill
	face.border_color = Palette.SLOT_TAN_DK
	face.border_width_left = 1
	face.border_width_top = 1
	face.border_width_right = 1
	face.border_width_bottom = 1 if floor_line else 0
	face.corner_radius_top_left = TAB_CORNER
	face.corner_radius_top_right = TAB_CORNER
	# Square pixels: anti-aliased, the rounded corners blur into the cream at `ui_scale` 2.
	face.anti_aliasing = false
	face.set_content_margin_all(2)
	return face


## A stretch of the line the tabs stand on: between two tabs (`width`) or out to the page's edge.
static func tab_line(width: float) -> Panel:
	var line := Panel.new()
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color.TRANSPARENT
	edge.border_color = Palette.SLOT_TAN_DK
	edge.border_width_bottom = 1
	line.add_theme_stylebox_override("panel", edge)
	line.custom_minimum_size.x = width
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func _sign(text: String, color: Variant = null) -> Label:
	return BountyList.wrapped(text, BODY_WIDTH, color)


## The shelf's grid, which her spells and the banishing stand on too.
static func _grid(h_gap := STOCK_GAP) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = STOCK_COLS
	grid.add_theme_constant_override("h_separation", h_gap)
	grid.add_theme_constant_override("v_separation", STOCK_GAP)
	return grid


## A button gold moves through that does `action`. While `refused` says why not it is dead and that is
## its tooltip, never a line on the page; otherwise `tooltip` is.
static func _priced(word: String, price: float, variation: String, refused: String, tooltip: String,
		action: Callable, figure := true) -> Button:
	var button := UITheme.priced_button(word, price, variation,
			tooltip if refused.is_empty() else refused, figure)
	button.disabled = not refused.is_empty()
	button.pressed.connect(action)
	return button


static func _left_press(event: InputEvent) -> bool:
	return event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed


# ---- the vendors' shelves

## A vendor's counter: the shelf in the scroll -- the orb vendor's trades under it -- and Restock
## pinned at the foot.
func _fill_vendor() -> void:
	var body := _scrolled(ROW_GAP)
	if _open_tab == TownServices.ORBS:
		body.add_child(_orb_shelf())
		body.add_child(UITheme.section("Trade up"))
		body.add_child(_upscales())
	else:
		body.add_child(_item_shelf())
	var price := _reroll_price()
	_rows.add_child(_priced("Restock", price, "LightButton", _why_not(price, false),
			"Clear this shelf for new stock. Each time costs twice the last", _on_reroll_pressed))


## The gear vendor's six squares. A bought one stays on the shelf with nothing on it.
func _item_shelf() -> GridContainer:
	var grid := _grid()
	var shelf := VendorStock.items(_drawer)
	for at in shelf.size():
		var item: Item = shelf[at]
		if item == null:
			grid.add_child(_sold_square())
			continue
		# A bag square takes no mouse, so the cell round it is what is pressed.
		var cell := _price_cell(ItemSlot.make(item), TownPrices.buy_price(item))
		# Grey, as the bag's grid greys, where the orb in the player's hand has nothing to do.
		if _held != "" and not OrbTable.can_apply(_held, item):
			cell.get_child(0).modulate = OrbSlot.DIM
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		Cursors.wear(cell, Cursors.HAND)
		cell.gui_input.connect(_on_shelf_input.bind(at))
		grid.add_child(cell)
	return grid


## The orb vendor's six squares, each lit while the purse can cover it.
func _orb_shelf() -> GridContainer:
	var grid := _grid()
	var orbs := VendorStock.orbs(_drawer)
	for at in orbs.size():
		var orb := orbs[at]
		if orb.is_empty():
			grid.add_child(_sold_square())
			continue
		var price := TownPrices.orb_value(orb, _cell)
		var short := _why_not(price, false)
		var note := "%s gold%s" % [BigNumber.format(price), "" if short.is_empty() else ". " + short]
		grid.add_child(_price_cell(_orb_square(orb, short.is_empty(), note, _on_buy_orb.bind(at)), price))
	return grid


## The orb vendor's trades: every unlocked orb but the first, each for `OrbTable.UPSCALE_COST` of the
## orb before it in the tray. That orb and the count stand where a price would, at the tray's size
## (an orb at `PRICE_COIN` is a speck of colour).
func _upscales() -> GridContainer:
	var grid := _grid()
	for orb: String in OrbTable.unlocked(inventory.walls_ever()):
		var from := OrbTable.upscale_from(orb)
		if from.is_empty():
			continue
		var enough := inventory.orb_count(from) >= OrbTable.UPSCALE_COST
		var square := _orb_square(orb, enough, "Trade %d %s for one" % [OrbTable.UPSCALE_COST, from], _on_upscale)
		grid.add_child(_cost_cell(square, str(OrbTable.UPSCALE_COST), OrbTable.icon(from), enough, OrbSlot.ICON))
	return grid


## One orb on a shelf, as the tray's own square at an item's size: lit while `ok` and grey otherwise,
## though a grey one still takes the cursor. Hovered, it shows the orb's card as the bag does, with
## `note` as its last line where the bag says how to use one. Pressed, it calls `on_press(orb)`.
func _orb_square(orb: String, ok: bool, note: String, on_press: Callable) -> OrbSlot:
	var square := OrbSlot.make(orb, 1, ok, false, ItemSlot.SIDE)
	square.hovered.connect(func(which: String) -> void:
		_orb_card.fill(which, inventory.orb_count(which), note, Palette.TEXT_SOFT if ok else Palette.RUST)
		_orb_card.show()
		# Twice: the first pass measures labels that have not laid out yet.
		_place_orb_card(square)
		_place_orb_card.call_deferred(square))
	square.unhovered.connect(_orb_card.hide)
	# A square freed under the cursor (a purchase redraws the tab) takes the card with it.
	square.tree_exiting.connect(_orb_card.hide)
	square.pressed.connect(on_press)
	return square


func _place_orb_card(square: OrbSlot) -> void:
	if not _orb_card.visible or not is_instance_valid(square) or not square.is_inside_tree():
		return
	_orb_card.reset_size()
	_orb_card.position = ItemCard.beside(square.get_global_rect(),
			_orb_card.get_combined_minimum_size() * _ui_scale, get_viewport_rect().size, ItemCard.GAP * _ui_scale)


func _price_cell(square: Control, price: float) -> VBoxContainer:
	return _cost_cell(square, BigNumber.format(price), Coins.icon(), inventory.gold >= price)


## Every priced square on the page is this one cell: `square`, and centred under it `mark` at
## `mark_side` (null for none) beside `figure` in the body font, brick while `ok` is false.
func _cost_cell(square: Control, figure: String, mark: Texture2D, ok: bool,
		mark_side := PRICE_COIN) -> VBoxContainer:
	var cell := UITheme.vbox(2, STOCK_CELL)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(square)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room := float(STOCK_CELL)
	if mark != null:
		var icon := BountyList.icon(mark, mark_side)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(icon)
		room -= mark_side + 2
	var label := UITheme.label(figure, Palette.TEXT_SOFT if ok else Palette.BRICK, true)
	# Clipped, never pushing: a seven-figure price would widen the shelf into the panel beside it. A
	# clipped Label has no width of its own, so it gets the figure's, up to what the cell has left.
	label.clip_text = true
	var wide := UITheme.theme().get_font("font", "SmallLabel").get_string_size(figure,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SMALL_FONT_SIZE).x
	label.custom_minimum_size.x = minf(ceilf(wide), room)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	cell.add_child(row)
	return cell


## A bought square: the bare socket with no price under it, in a cell of its own so the shelf keeps
## its three columns.
static func _sold_square() -> VBoxContainer:
	var cell := UITheme.vbox(2, STOCK_CELL)
	var square := Panel.new()
	square.custom_minimum_size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_theme_stylebox_override("panel", ItemRarity.slot_style(ItemRarity.Rarity.COMMON))
	square.tooltip_text = "Bought. Restock fills the shelf again"
	cell.add_child(square)
	return cell


## The piece picked up off the shelf, written out as the bag writes one, over Back and Buy.
func _fill_offer() -> void:
	ItemDetails.fill(_scrolled(2), _offer, BODY_WIDTH)
	var price := TownPrices.buy_price(_offer)
	_back_row("Back to what the vendor has", _close_offer.bind(true),
			_priced("Buy", price, UITheme.GO_BUTTON, _why_not(price, true),
			"Buy this and put it in your bag for %s gold" % BigNumber.format(price), _on_buy_item))


## Which of the drawer's two shelves the open tab is.
func _shelf_key() -> String:
	return VendorStock.ORBS if _open_tab == TownServices.ORBS else VendorStock.ITEMS


## What Restock costs on the open shelf now: dearer every time, for good.
func _reroll_price() -> float:
	return TownPrices.reroll_price(_cell, VendorStock.rerolls(_drawer, _shelf_key()))


## A press on a shelf piece's cell: it opens the piece, or with an orb in hand spends the orb on it
## where it stands.
func _on_shelf_input(event: InputEvent, at: int) -> void:
	if not _left_press(event):
		return
	accept_event()  # Before the redraw frees the cell, which would let the press through to the map.
	var shelf := VendorStock.items(_drawer)
	if at < 0 or at >= shelf.size() or shelf[at] == null:
		return
	if _held != "":
		# Under a finger the first tap only puts the piece's card up -- asked by its place on the shelf,
		# which makes its pieces anew every time it is drawn. The shelf is drawn again when the orb
		# lands, which a question about lowering the piece may put off.
		if Cursors.applies("shelf:%d" % at):
			craft_held.call(shelf[at], func() -> void:
				VendorStock.put(_drawer, at, shelf[at])
				redraw())
		return
	_offer = shelf[at]
	_offer_at = at
	_refresh()
	offer_changed.emit(_offer)


## Back to the shelf. `tell` is false while `open` rebuilds the page: whoever opened it is about to
## point the bag at this counter anyway.
func _close_offer(tell: bool) -> void:
	_offer = null
	_offer_at = -1
	_refresh()
	if tell:
		offer_changed.emit(null)


## One piece over the counter, paid for and taken off the shelf together. The grey button's refusals
## are checked again here, for a caller that cannot see the button.
func _on_buy_item() -> void:
	var price := TownPrices.buy_price(_offer)
	if _offer == null or not _why_not(price, true).is_empty():
		return
	inventory.gold -= price
	inventory.add(_offer)
	VendorStock.take(_drawer, VendorStock.ITEMS, _offer_at)
	print("Bought %s (%s, level %d) for %s gold"
			% [_offer.type, _offer.rarity_name(), _offer.level, BigNumber.format(price)])
	inventory.save(_save_path)
	_close_offer(true)


func _on_buy_orb(orb: String, at: int) -> void:
	var price := TownPrices.orb_value(orb, _cell)
	if not _why_not(price, false).is_empty():
		return
	inventory.gold -= price
	inventory.add_orb(orb)
	VendorStock.take(_drawer, VendorStock.ORBS, at)
	print("Bought %s for %s gold" % [orb, BigNumber.format(price)])
	_deed_done()


## `OrbTable.UPSCALE_COST` of the orb before this one traded for one of it. No gold changes hands.
func _on_upscale(orb: String) -> void:
	var from := OrbTable.upscale_from(orb)
	if from.is_empty() or inventory.orb_count(from) < OrbTable.UPSCALE_COST \
			or orb not in OrbTable.unlocked(inventory.walls_ever()):
		return
	for i in OrbTable.UPSCALE_COST:
		inventory.spend_orb(from)
	inventory.add_orb(orb)
	print("Traded %d %s for one %s" % [OrbTable.UPSCALE_COST, from, orb])
	_deed_done()


## The open vendor's shelf only: the other shelf and the board are not touched.
func _on_reroll_pressed() -> void:
	var price := _reroll_price()
	if inventory.gold < price:
		return
	inventory.gold -= price
	VendorStock.reroll(_drawer, _shelf_key(), _tier, _cell, _stock_rng, inventory.walls_ever())
	print("Restocked the %s shelf for %s gold" % [_shelf_key(), BigNumber.format(price)])
	_deed_done()


# ---- the board

## The board: its tier and pips, a cleared board's Reward, work taken at another board, then the open
## postings as `BountyList` writes them -- the one taken on here first, and while any work is out the
## rest dimmed with Accept grey.
func _fill_board() -> void:
	# Having read a board is what puts the journal in the corner, so it is written down as it is drawn.
	if BountyBoard.see(_drawer):
		inventory.save(_save_path)
	var body := _scrolled(ROW_GAP)
	var board := BountyBoard.bounties(_drawer)
	var waiting := not pending_choice().is_empty()
	body.add_child(_board_heading(board, waiting))
	if waiting:
		var reward := UITheme.button("Reward", "SmallGoButton", "Choose your reward for clearing this board")
		reward.pressed.connect(choice_asked.emit)
		body.add_child(reward)
	var active_at := BountyBoard.active_spot(inventory.towns)
	var busy := not active_at.is_empty()
	if busy and active_at != TownState.key(_spot):
		body.add_child(BountyList.row(BountyBoard.active(inventory.towns), view, BODY_WIDTH,
				"Taken at %s. Claim it there." % _town_at(active_at)))
	var postings := board.filter(func(b: Dictionary) -> bool: return BountyBoard.is_active(b))
	postings.append_array(board.filter(func(b: Dictionary) -> bool:
			return not BountyBoard.is_active(b) and not bool(b.get(BountyBoard.DONE, false))))
	for bounty: Dictionary in postings:
		var taken := BountyBoard.is_active(bounty)
		var row := BountyList.row(bounty, view, BODY_WIDTH,
				"Accepted." if taken and not BountyBoard.ready(bounty) else "")
		var action: Button
		if not taken:
			action = UITheme.button("Accept", "SmallGoButton",
					"Hand in the bounty you have taken first" if busy else "Take this work on")
			action.disabled = busy
			if busy:
				row.modulate = TAB_REST
			action.pressed.connect(_on_accept_pressed.bind(bounty))
		elif BountyBoard.ready(bounty):
			action = _claim_button(bounty)
		if action != null:
			action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			BountyList.actions_of(row).add_child(action)
		body.add_child(row)
	if postings.is_empty() and not busy:
		body.add_child(_sign("Nothing is posted here now."))


## The board's tier, ending in its pips: a round one lit for each posting handed in, and the gift in
## the last place, lit while a cleared board's reward waits.
func _board_heading(board: Array, waiting: bool) -> HBoxContainer:
	var heading := UITheme.section("Tier " + Achievements.RANK_NAMES[BountyBoard.board_tier(_drawer)])
	if board.is_empty():
		return heading
	var done := board.filter(func(b: Dictionary) -> bool:
			return bool(b.get(BountyBoard.DONE, false))).size()
	var pips := KillPips.new(board.size())
	pips.show_board(done, waiting)
	pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pips.mouse_filter = Control.MOUSE_FILTER_PASS
	pips.tooltip_text = ("Your reward is waiting" if waiting
			else "%d of %d handed in. Clear the board for a reward" % [done, board.size()])
	heading.add_child(pips)
	return heading


## A finished posting's Claim. Its figure is on the card above and in the tooltip: a small button has
## no room for a reward that grows with the walk. A promised piece needs room in the bag.
func _claim_button(bounty: Dictionary) -> Button:
	var gold := float(bounty.get(BountyBoard.GOLD, 0))
	var prize := BountyBoard.reward_text(bounty)
	var xp := int(bounty.get(BountyBoard.XP, 0))
	return _priced("Claim", gold, "SmallGoButton", _why_not(0.0, not prize.is_empty()),
			"Hand this in for %s gold%s%s" % [BigNumber.format(gold), "" if xp == 0 else ", %d experience" % xp,
			"" if prize.is_empty() else " and " + prize], _on_claim_pressed.bind(bounty), false)


## What the town whose drawer is filed under `at` is called, off the map that named it.
func _town_at(at: String) -> String:
	var called := "" if view == null else view.name_of(TownState.spot(at) - view.origin)
	return called if not called.is_empty() else "another town"


## The land around the town: a board posts only what lives where the player can walk to.
func _board_land() -> PackedStringArray:
	if view == null:
		return PackedStringArray()
	return view.envs_within(_cell, BountyBoard.BOUNTY_RANGE)


## The uniques a bounty or a cleared board may hand over: the unlocked ones less what she has banished.
func _dropping() -> Array:
	return FortuneTeller.dropping(Achievements.unlocked(inventory), inventory.fortunes)


## A piece the board pays, in the one order: said, then the log hears, then the bag.
func _hand_over(piece: Item) -> void:
	item_claimed.emit(piece)
	inventory.note_unique(piece.unique)
	inventory.add(piece)


func _on_accept_pressed(bounty: Dictionary) -> void:
	if not BountyBoard.accept(inventory.towns, bounty):
		return
	print("Accepted the bounty on %s" % str(bounty.get(BountyBoard.ENEMY, "")))
	inventory.save(_save_path)
	_refresh()
	bounty_accepted.emit()


## One bounty handed in. It pays exactly once -- `claim` is what refuses the second press -- and the
## posting stays on the board, spent, until the restock fills its place.
func _on_claim_pressed(bounty: Dictionary) -> void:
	if not BountyBoard.item_of(bounty).is_empty() and inventory.is_full():
		return
	if not BountyBoard.claim(bounty):
		return
	var enemy := str(bounty.get(BountyBoard.ENEMY, ""))
	var reward := float(bounty.get(BountyBoard.GOLD, 0))
	var orbs := BountyBoard.orbs_of(bounty)
	var xp := int(bounty.get(BountyBoard.XP, 0))
	inventory.gold += reward
	for orb: String in orbs:
		inventory.add_orb(orb)
	if xp > 0:
		inventory.add_xp(xp)
		xp_claimed.emit(xp)
	var piece := BountyBoard.reward_item(bounty, _cell, _stock_rng, _dropping())
	if piece != null:
		_hand_over(piece)
	# `clear` before `restock`: the last one handed in clears the board, which offers its reward and
	# raises the town's tier, and the new work is posted at the new tier.
	BountyBoard.clear(_drawer, _cell, _stock_rng, _dropping(), inventory.walls_ever())
	BountyBoard.restock(_drawer, _board_land(), _cell, _stock_rng, inventory.walls_ever())
	print("Claimed the bounty on %s for %s gold, %d experience and %s"
			% [enemy, BigNumber.format(reward), xp, orbs])
	var counted := {}
	for orb: String in orbs:
		counted[orb] = int(counted.get(orb, 0)) + 1
	bounty_paid.emit(enemy, reward, xp, counted, piece)
	_deed_done()


## The options this town's cleared board has offered and the player has not taken (`BountyBoard.choice`).
func pending_choice() -> Array:
	return BountyBoard.choice(_drawer)


## Why option `index` of the cleared board cannot be taken now, or "": a piece needs room in the bag.
func why_not_take(index: int) -> String:
	var offered := pending_choice()
	if index < 0 or index >= offered.size():
		return "Nothing to take"
	return _why_not(0.0, offered[index].has(BountyBoard.CHOICE_ITEM))


## Takes option `index` of the cleared board; the other two are gone. False when it was refused.
func take_choice(index: int) -> bool:
	if not why_not_take(index).is_empty():
		return false
	var option := BountyBoard.take_choice(_drawer, index)
	var piece: Item = option.get(BountyBoard.CHOICE_ITEM)
	if piece != null:
		_hand_over(piece)
		print("Took %s for clearing the board" % piece.display_name())
	elif option.has(BountyBoard.CHOICE_GOLD):
		var gold := float(option[BountyBoard.CHOICE_GOLD])
		inventory.gold += gold
		print("Took %s gold for clearing the board" % BigNumber.format(gold))
	elif option.has(BountyBoard.CHOICE_XP):
		var xp := int(option[BountyBoard.CHOICE_XP])
		inventory.add_xp(xp)
		xp_claimed.emit(xp)
		print("Took %d experience for clearing the board" % xp)
	else:
		var count := int(option[BountyBoard.CHOICE_COUNT])
		inventory.add_orb(str(option[BountyBoard.CHOICE_ORB]), count)
		print("Took %d %s for clearing the board" % [count, option[BountyBoard.CHOICE_ORB]])
	_deed_done()
	return true


# ---- the smith

## The smith's counter. With a piece open in the bag: that piece written out whole in the scroll, so
## what a blow changes is watched where it changes, and Upgrade over Lock pinned at the foot -- no
## square, no smith and no counter name (the user's, 2026-10-07).
func _fill_smith() -> void:
	if not _smith_note.is_empty():
		_rows.add_child(_sign(_smith_note, Palette.BRICK))
	if _bag_piece == null:
		_fill_idle_smith()
		return
	var details := UITheme.vbox(2, BODY_WIDTH)
	_scrolled(ROW_GAP).add_child(details)
	ItemDetails.fill(details, _bag_piece, BODY_WIDTH)
	var cap := _upgrade_cap()
	var up_price := TownPrices.upgrade_price(_bag_piece)
	var up_why := _smith_why_not(Blacksmith.why_not_upgrade(_bag_piece, cap), up_price)
	# Only while the blow can be struck: the level it goes from and to, and the risk in a loss's colour.
	if up_why.is_empty():
		var odds := HBoxContainer.new()
		var step := UITheme.label("Level %d → %d of %d" % [_bag_piece.level, _bag_piece.level + 1, cap],
				Palette.TEXT_SOFT, true)
		step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		odds.add_child(step)
		odds.add_child(UITheme.label("Break %d%%" % roundi(Blacksmith.BREAK_CHANCE * 100.0), Palette.BRICK, true))
		_rows.add_child(odds)
	_rows.add_child(_smith_button("Upgrade", up_price, up_why,
			"Take this to level %d for %s gold. Its modifiers stay as they are"
			% [_bag_piece.level + 1, BigNumber.format(up_price)], _on_upgrade_pressed, "SmallGoButton"))
	var lock_price := TownPrices.lock_price(_bag_piece)
	var lock_why := _smith_why_not(Blacksmith.why_not_lock(_bag_piece), lock_price)
	_rows.add_child(_smith_button("Lock", lock_price, lock_why,
			"Pin one of its modifiers for good, for %s gold" % BigNumber.format(lock_price),
			_on_lock_pressed))


## The smith with nothing held up to him: the bench, where to pick a piece, and his two services with
## the least each costs on anything carried or worn that he would take.
func _fill_idle_smith() -> void:
	var body := _scrolled(ROW_GAP)
	body.add_child(_smith_bench())
	body.add_child(_sign("Open an item in your bag or on your doll.", Palette.TEXT_SOFT))
	body.add_child(UITheme.rule(BODY_WIDTH))
	var cap := _upgrade_cap()
	var pieces := inventory.items + inventory.equipment.items()
	_smith_service(body, "Upgrade",
			pieces.filter(func(p: Item) -> bool: return Blacksmith.can_upgrade(p, cap))
				.map(func(p: Item) -> float: return TownPrices.upgrade_price(p)))
	_smith_service(body, "Lock",
			pieces.filter(func(p: Item) -> bool: return Blacksmith.can_lock(p))
				.map(func(p: Item) -> float: return TownPrices.lock_price(p)))


## The empty square a piece would stand on, wearing the anvil, beside the smith's portrait.
func _smith_bench() -> HBoxContainer:
	var bench := HBoxContainer.new()
	bench.add_theme_constant_override("separation", ROW_GAP)
	bench.alignment = BoxContainer.ALIGNMENT_CENTER
	var square := ItemSlot.empty("Open an item in your bag or on your doll", tab_mark(TownServices.SMITH, false))
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bench.add_child(square)
	bench.add_child(_swing.portrait())
	return bench


## One of the smith's services on his idle counter: its name and "from" the least of `prices`, or the
## name alone when nothing the player has can take it.
func _smith_service(body: VBoxContainer, title: String, prices: Array) -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 2)
	var name_label := UITheme.label(title)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	if not prices.is_empty():
		var least: float = prices.min()
		head.add_child(UITheme.label("from", Palette.TEXT_SOFT, true))
		head.add_child(BountyList.icon(Coins.icon(), PRICE_COIN))
		head.add_child(UITheme.label(BigNumber.format(least),
				Palette.TEXT_SOFT if inventory.gold >= least else Palette.BRICK, true))
	body.add_child(head)


## One of the smith's two buttons, wearing the hammer for a cursor while it is live.
func _smith_button(text: String, price: float, refused: String, tooltip: String,
		action: Callable, variation := "SmallButton") -> Button:
	var button := _priced(text, price, variation, refused, tooltip, action)
	if refused.is_empty():
		Cursors.wear(button, Cursors.HAMMER)
	return button


## The smith's own refusal (`rule`), or a purse that cannot pay. Carried or worn is all one to him.
func _smith_why_not(rule: String, price: float) -> String:
	if not rule.is_empty():
		return rule
	return _why_not(price, false)


## The level the smith here may take a piece to: the deepest land of this town's wall circle, so every
## fortress between the same two walls works to the same ceiling.
func _upgrade_cap() -> int:
	return MapBuilder.circle_level(_cell)


## One blow of the hammer. The gold goes whichever way it falls, and the piece stays where it is, a
## level better or broken for good.
func _on_upgrade_pressed() -> void:
	var cap := _upgrade_cap()
	var price := TownPrices.upgrade_price(_bag_piece)
	if not _smith_why_not(Blacksmith.why_not_upgrade(_bag_piece, cap), price).is_empty():
		return
	inventory.gold -= price
	var upgraded := Blacksmith.upgrade(_bag_piece, cap, _smith_rng)
	_swing.strike(SmithSwing.ANVIL_SOUND if upgraded else SmithSwing.BREAK_SOUND, self)
	_smith_note = "" if upgraded else "The hammer broke it."
	print(("Upgraded %s to level %d for %s gold" if upgraded else "Broke %s at level %d for %s gold")
			% [_bag_piece.display_name(), _bag_piece.level, BigNumber.format(price)])
	_deed_done()


## One modifier pinned, drawn by the smith rather than chosen. Never breaks anything.
func _on_lock_pressed() -> void:
	var price := TownPrices.lock_price(_bag_piece)
	if not _smith_why_not(Blacksmith.why_not_lock(_bag_piece), price).is_empty():
		return
	inventory.gold -= price
	if not Blacksmith.lock(_bag_piece, _smith_rng):
		return
	_swing.strike(SmithSwing.ANVIL_SOUND, self)
	print("Locked %s on %s for %s gold" % [ModifierTable.line(_bag_piece.locked_mod()),
			_bag_piece.display_name(), BigNumber.format(price)])
	_deed_done()


# ---- the fortuneteller

## Her table: her spells on the shelf's own grid in two halves, each square with its price under it,
## and pinned under them one line naming the last spell cast whose answer is ticked away.
func _fill_fortune() -> void:
	if _banishing:
		_fill_banish()
		return
	var body := _scrolled(ROW_GAP)
	body.add_child(_spell_grid("Readings", FortuneTeller.COMMON))
	var great: Array = FortuneTeller.GREAT.duplicate()
	# The way out is a square among the great spells, once a wall has fallen (the user's, 2026-09-25).
	if view != null and view.walls_fallen() > 0:
		great.append(FortuneTeller.TRANSCEND)
	if _unlocked().size() >= FortuneTeller.BANISH_FROM or Settings.banish_unlocked():
		great.append(FortuneTeller.BANISH)
	body.add_child(_spell_grid("Great spells", great))
	if not _cast.is_empty():
		_rows.add_child(_sign("You cast %s." % FortuneTeller.LABELS[_cast], Palette.TEXT_SOFT))


## One half of her list: its heading over that half's squares.
func _spell_grid(heading: String, readings: Array) -> VBoxContainer:
	var box := UITheme.vbox(ROW_GAP, BODY_WIDTH)
	box.add_child(UITheme.section(heading))
	var grid := _grid()
	for reading: String in readings:
		var square := _spell_square(reading)
		# The roads, once bought in this town, say so where the price was, and no coin.
		grid.add_child(_cost_cell(square, "Bought", null, true) if _roads_bought(reading)
				else _price_cell(square, _fortune_price(reading)))
	box.add_child(grid)
	return box


## One spell on her grid: its mark with no name over it (the user's, 2026-09-25), named for its
## reading, which is how the tests find it. A live one is lit by a halo under the cursor; one she
## refuses is greyed and deaf, the reason in its tooltip.
func _spell_square(reading: String) -> Control:
	var refused := _fortune_why_not(reading)
	# A Panel, not the mark itself: what the hover lights is a stylebox, and the mark fills it.
	var square := Panel.new()
	square.name = reading
	square.custom_minimum_size = Vector2(SPELL_SIDE, SPELL_SIDE)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	square.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	square.tooltip_text = refused if not refused.is_empty() else FORTUNE_TIPS[reading]
	# A finger's first tap reads a spell and the next casts it (`Cursors.applies`), so under one the
	# words come up with the tap and stay.
	if Cursors.touched:
		square.set_meta(TipCard.NOW, true)
	var icon := TextureRect.new()
	# Mode before texture: a TextureRect's minimum is its texture until `expand_mode` says otherwise.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = load(FORTUNE_ICONS[reading])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_child(icon)
	if not refused.is_empty():
		square.modulate = OrbSlot.DIM
		return square
	Cursors.wear(square, Cursors.HAND)
	var glow := StyleBoxFlat.new()
	glow.bg_color = HOVER_GLOW_COLOR
	glow.set_expand_margin_all(HOVER_GLOW)
	square.mouse_entered.connect(func() -> void:
		square.add_theme_stylebox_override("panel", glow)
		icon.modulate = HOVER_LIFT)
	square.mouse_exited.connect(func() -> void:
		square.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		icon.modulate = Color.WHITE)
	square.gui_input.connect(func(event: InputEvent) -> void:
		if _left_press(event):
			square.accept_event()  # Before the redraw frees it, which would let the press through to the map.
			if Cursors.applies("spell:" + reading):
				_on_reading_pressed(reading))
	return square


## What a spell costs here, off the town's level -- the banishing's doubled for each one paid for.
func _fortune_price(reading: String) -> float:
	return TownPrices.fortune_price(reading, _cell,
			FortuneTeller.banishes(inventory.fortunes) if reading == FortuneTeller.BANISH else 0)


## Whether this town has sold the roads already: once a town, as a great spell is.
func _roads_bought(reading: String) -> bool:
	return reading == FortuneTeller.ROADS and FortuneTeller.asked(_drawer, reading)


## Why she will not give this spell, or "" when she will.
func _fortune_why_not(reading: String) -> String:
	if view == null:
		return "She sees nothing here"
	if reading in FortuneTeller.GREAT and FortuneTeller.asked(_drawer, reading):
		return "That spell is spent here"
	if _roads_bought(reading):
		return "Already bought here"
	match reading:
		FortuneTeller.TREASURE:
			var told := FortuneTeller.chest(inventory.fortunes)
			if told != TownWorld.NO_SPOT and view.has_chest(told - view.origin):
				return "The star is already out"
			if _near_chest == HexMap.NO_CELL:
				return "She sees no hidden chest"
		FortuneTeller.APPRAISE:
			var why := FortuneTeller.why_not_appraise(_bag_piece)
			if not why.is_empty():
				return why
		FortuneTeller.HOMECOMING:
			if view.homes().is_empty():
				return "You have found nowhere else to stand"
		FortuneTeller.TRANSCEND, FortuneTeller.BANISH:
			# Never greyed: asking is free. A short purse greys the Transcend in her question, and the
			# banishing's screen is also where one is brought back, for nothing.
			return ""
	return _why_not(_fortune_price(reading), false)


## One spell asked for. The two aimed at the map are paid for there (`spell_aimed`), the way out only
## asks and the banishing opens its screen; any other is paid for and written down here, together.
func _on_reading_pressed(reading: String) -> void:
	if not _fortune_why_not(reading).is_empty():
		return
	var price := _fortune_price(reading)
	if reading in FortuneTeller.GREAT:
		spell_aimed.emit(reading, price, _spot)
		return
	if reading == FortuneTeller.TRANSCEND:
		_ask_way_out()
		return
	if reading == FortuneTeller.BANISH:
		_banishing = true
		_banish_pick = ""
		_refresh()
		return
	inventory.gold -= price
	match reading:
		FortuneTeller.ROADS:
			# The one drawer key a reading still writes: this town has sold the roads, and sells them no more.
			_drawer[FortuneTeller.ASKED + reading] = true
			if view.reveal_ring_towns(_cell) > 0:
				# A chest the roads brought into sight is no longer one she may point at.
				_near_chest = view.nearest_chest(true)
				towns_revealed.emit()
		FortuneTeller.TREASURE:
			var spot := view.origin + _near_chest
			inventory.fortunes[FortuneTeller.CHEST] = [spot.x, spot.y]
			chest_bought.emit(_near_chest)
	print("The fortuneteller read %s for %s gold" % [reading, BigNumber.format(price)])
	inventory.save(_save_path)
	_tell(reading)
	_refresh()
	offer_changed.emit(null)


# ---- her answers: popups over the whole window

## Whether one of her answers (or the way out's question) stands over the window, for a banner to wait behind.
func telling() -> bool:
	return _told != null


## What she said to a reading just paid for, as a popup built the way `BagPage._ask` is: the answer in
## a scroll, with Dismiss and "Don't show this again" in reach under it however long it is. A ticked
## Dismiss writes `SKIP_TOLD + reading` into `inventory.tips`, and from then on that reading answers in
## one line on the page (`_cast`). The appraisal offers no tick: its table is the whole of what was bought.
func _tell(reading: String) -> void:
	_close_told()
	var can_skip := reading != FortuneTeller.APPRAISE
	if can_skip and SKIP_TOLD + reading in inventory.tips:
		_cast = reading
		return
	_cast = ""
	var body := _open_told(FortuneTeller.LABELS[reading])
	_answer(reading, _told_scroll.get_child(0))
	var panel: Control = _told.get_node(TOLD_PANEL)
	var dismiss := UITheme.button("Dismiss", "LightButton", "")
	dismiss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(dismiss)
	var skip := BagPage.check_box("Don't show this again")
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.visible = can_skip
	body.add_child(skip)
	dismiss.pressed.connect(func() -> void:
		# Once: pressed again as the answer shrinks away, a ticked Dismiss would write its reading twice.
		if Juice.leaving(panel):
			return
		if (skip.get_node(BagPage.TICK_NAME) as Button).button_pressed:
			inventory.tips.append(SKIP_TOLD + reading)
			inventory.save(_save_path)
		_leave_told())
	# A reading is something bought, so it comes up as a reward does: the wash and the sparks.
	_show_told(true)


## The way out, asked before it is done: her warning over Cancel and Transcend. The price is only on
## the square that brought the player here; the button carries the coin and no figure, as Claim does.
## A short purse greys the deed, never the asking.
func _ask_way_out() -> void:
	var body := _open_told(FortuneTeller.LABELS[FortuneTeller.TRANSCEND])
	var lines: VBoxContainer = _told_scroll.get_child(0)
	for line: String in TRANSCEND_LINES:
		lines.add_child(_told_line(line))
	var price := _fortune_price(FortuneTeller.TRANSCEND)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", ROW_GAP)
	body.add_child(answers)
	var cancel := UITheme.button("Cancel", "LightButton", "Stay in this world")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_leave_told)
	answers.add_child(cancel)
	var panel: Control = _told.get_node(TOLD_PANEL)
	var take := func() -> void:
		# Not once Cancel has answered: the question takes a moment to shrink away, its buttons with it.
		if Juice.leaving(panel):
			return
		_close_told()
		transcend_pressed.emit()
	var leave := _priced("Transcend", price, "LightButton", _why_not(price, false),
			"Leave this world for %s gold" % BigNumber.format(price), take, false)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers.add_child(leave)
	# A warning, not a reward: no wash.
	_show_told(false)


## One of her popups, empty: a holder for the whole window, a titled panel with no X -- like a
## reward's, its way out is at its foot (and Escape) -- and a scroll in `_told_scroll` for what she
## says. Returns the body, for the buttons that go under the scroll.
func _open_told(title: String) -> VBoxContainer:
	_close_told()
	_told = Control.new()
	add_child(_told)
	# Over the bag too, which a window held upright stands under this page (`BagPage._ask` does the same).
	move_to_front()
	var panel := UITheme.titled_panel(title, "", Callable())
	panel.name = TOLD_PANEL
	_told.add_child(panel)
	var body := UITheme.body_of(panel)
	_told_scroll = UITheme.scroll()
	body.add_child(_told_scroll)
	_told_scroll.add_child(UITheme.vbox(ROW_GAP, TOLD_WIDTH))
	return body


## Brings the popup `_open_told` built up, the rewards' way.
func _show_told(win: bool) -> void:
	Juice.popup(_told, _told.get_node(TOLD_PANEL), _ui_scale, win)
	# Twice: a wrapped label only knows how tall it is once it has been laid out once.
	_place_told()
	_place_told.call_deferred()


## Her answer's scroll, as tall as the answer or as what the window leaves, measured again at every
## `layout()`. A window made smaller leaves the scroll less, and a panel never shrinks to what it
## holds by itself.
func _place_told() -> void:
	if _told == null:
		return
	var lines: Control = _told_scroll.get_child(0)
	var tall := minf(lines.get_combined_minimum_size().y, get_viewport_rect().size.y / _ui_scale - TOLD_CHROME)
	var less := tall < _told_scroll.custom_minimum_size.y
	_told_scroll.custom_minimum_size.y = tall
	if less:
		(_told.get_node(TOLD_PANEL) as Control).reset_size()


## Dismiss and Escape: the answer shrinks away, then goes. It is let go of at once, so the page under
## it can be pressed again the moment it starts to leave.
func _leave_told() -> void:
	if _told == null:
		return
	var holder := _told
	_told = null
	_told_scroll = null
	Juice.pop_out(holder.get_node(TOLD_PANEL), holder.queue_free)


## Gone at once, with no shrink: a new town, another counter, or another answer taking its place.
func _close_told() -> void:
	if _told != null:
		remove_child(_told)
		_told.queue_free()
		_told = null
		_told_scroll = null


## Escape on her answer is its Dismiss, reading no tick, and the press stops here: the town stays up.
func _unhandled_input(event: InputEvent) -> void:
	if _told != null and is_visible_in_tree() and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_leave_told()


static func _told_line(text: String, color: Variant = null) -> Label:
	return BountyList.wrapped(text, TOLD_WIDTH, color)


func _answer(reading: String, lines: VBoxContainer) -> void:
	match reading:
		FortuneTeller.ROADS:
			# That they are all on the map, and no more: where each one lies is the map's to show.
			lines.add_child(_told_line("There. Every settlement between these walls is on your map. "
					+ "You'll walk past half of them anyway."))
		FortuneTeller.TREASURE:
			lines.add_child(_told_line("There's a star over the nearest chest you haven't seen. "
					+ "Come back when you want another."))
			lines.add_child(_told_line("It stays until you open it. I don't do refunds.", Palette.TEXT_SOFT))
		FortuneTeller.APPRAISE:
			lines.add_child(ItemDetails.line(_bag_piece.display_name(), _bag_piece.text_color(), TOLD_WIDTH))
			# What the table is -- the base's whole pool, not what this piece has.
			lines.add_child(_told_line("%s: every modifier it can roll" % _bag_piece.type, Palette.TEXT_SOFT))
			lines.add_child(UITheme.rule(TOLD_WIDTH))
			# Its own box: the answer's row gap would pull the table's stripes apart.
			var table := UITheme.vbox(0)
			lines.add_child(table)
			for row in FortuneTeller.odds(_bag_piece):
				table.add_child(_odds_row(row, table.get_child_count() % 2 == 1, TOLD_WIDTH))


## One modifier she read off a piece: the line with its band on the left, how often it comes up on the right.
func _odds_row(row: Dictionary, striped: bool, width: float) -> PanelContainer:
	var line := UITheme.table_row(str(row["line"]), "%.1f%%" % float(row["share"]), striped,
			width, null, Palette.TEXT_SOFT)
	var share: Label = line.find_child(UITheme.TABLE_VALUE, true, false)
	share.tooltip_text = "Weight %d" % int(row["weight"])
	share.mouse_filter = Control.MOUSE_FILTER_STOP
	return line


# ---- her banishing

## The banishing's screen, in her list's place as a shelf piece's is in the shelf's (the user's,
## 2026-10-10): every unlocked unique by name where a shelf's squares stand, a banished one greyed, and
## pinned at the foot the arrow back beside Banish with what the next one costs -- or Restore, for
## nothing, while a banished one is picked. It stays through as many as the player pays for.
func _fill_banish() -> void:
	var ids := _unlocked()
	ids.sort_custom(func(a: String, b: String) -> bool:
		return str(UniqueTable.UNIQUES[a]["name"]).naturalnocasecmp_to(
				str(UniqueTable.UNIQUES[b]["name"])) < 0)
	var gone := FortuneTeller.banished(inventory.fortunes)
	# The shelf's own pitch with no price cell round a square, centred as its squares are in theirs.
	var grid := _grid(STOCK_CELL - ItemSlot.SIDE + STOCK_GAP)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	# Pass, not stop: the scroll under it has to see a finger's drag (`_on_banish_input`).
	grid.mouse_filter = Control.MOUSE_FILTER_PASS
	for id: String in ids:
		var piece := CollectionPage.specimen(id)
		var slot := ItemSlot.make(piece, id == _banish_pick)
		slot.still()
		slot.hint = CollectionPage.write_hint.bind(piece, true)
		# What a unique is is its own card's to say, past the whole page: never over the squares still
		# to be looked at. The picked square keeps it up while the cursor goes to the button.
		slot.set_meta(ItemCard.BESIDE, _panel)
		if id == _banish_pick:
			slot.set_meta(ItemCard.PINNED, true)
		if gone.has(id):
			slot.modulate = OrbSlot.DIM
		grid.add_child(slot)
	grid.gui_input.connect(_on_banish_input.bind(grid))
	_scrolled(ROW_GAP).add_child(grid)

	# The verb on the small face: at Pixellari's 16 px the word, a six-figure price and the coin beside
	# the arrow ran the page past `BODY_WIDTH`.
	var verb: Button
	if gone.has(_banish_pick):
		verb = UITheme.button("Restore", "SmallButton", "")
		verb.pressed.connect(_on_restore_pressed)
	else:
		var price := _fortune_price(FortuneTeller.BANISH)
		# No tooltip but her floor's (the user's, 2026-10-10): the word and the price are on the button,
		# and a dead one with nothing picked or a short purse says nothing.
		verb = UITheme.priced_button("Banish", price, "SmallButton",
				FortuneTeller.why_not_banish(_banish_pick, _unlocked(), inventory.fortunes))
		verb.disabled = not _banish_why_not(price).is_empty()
		verb.pressed.connect(_on_banish_pressed)
	var to_spells := func() -> void:
		_banishing = false
		_refresh()
	# The arrow has no tooltip either (the user's, 2026-10-10).
	_back_row("", to_spells, verb).name = BANISH_BACK


## The uniques this build has that the player has unlocked: what she counts before she offers the
## banishing, and the squares its screen shows.
func _unlocked() -> Array:
	return UniqueTable.pool_for(Achievements.unlocked(inventory))


## Why Banish is dead, or "" when it is not: nothing picked, her own refusal, or a short purse. Only
## her floor is ever said, in the button's tooltip; the rest only grey it.
func _banish_why_not(price: float) -> String:
	if _banish_pick.is_empty():
		return "Pick a unique"
	var why := FortuneTeller.why_not_banish(_banish_pick, _unlocked(), inventory.fortunes)
	return why if not why.is_empty() else _why_not(price, false)


## A press on the banishing's grid, whose squares take no mouse. It counts as it lets go, and not one
## that travelled: the grid is longer than the page, and under a finger a drag is how it is scrolled.
func _on_banish_input(event: InputEvent, grid: Control) -> void:
	Cursors.over_squares(grid, event)
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if press.pressed:
		_banish_press = press.global_position
		return
	var travelled := press.global_position.distance_to(_banish_press) / _ui_scale
	_banish_press = Vector2.INF
	if travelled >= (Cursors.TOUCH_SLOP if Cursors.touched else BagPage.DRAG_THRESHOLD):
		return
	var slot := ItemCard.square_at(get_tree(), press.global_position)
	if slot != null and grid.is_ancestor_of(slot):
		grid.accept_event()  # Before the redraw frees it, which would let the release through to the map.
		_on_banish_picked(slot.item.unique)


## One unique picked on the banishing's screen, or put down again by a second press.
func _on_banish_picked(id: String) -> void:
	_banish_pick = "" if id == _banish_pick else id
	_refresh()


func _on_banish_pressed() -> void:
	var price := _fortune_price(FortuneTeller.BANISH)
	if not _banish_why_not(price).is_empty():
		return
	inventory.gold -= price
	FortuneTeller.banish(inventory.fortunes, _banish_pick)
	print("The fortuneteller banished %s for %s gold" % [_banish_pick, BigNumber.format(price)])
	_after_banish()


func _on_restore_pressed() -> void:
	FortuneTeller.restore(inventory.fortunes, _banish_pick)
	_after_banish()


## Nothing picked, and the screen stays for the next one.
func _after_banish() -> void:
	_banish_pick = ""
	_deed_done()
