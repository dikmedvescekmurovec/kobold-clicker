class_name TownPage
extends Control
## The settlement the player is standing in, as a panel on the right edge in the tile panel's place:
## what the town is, one tab per counter it has, and under the open tab the six things that counter
## has for sale.
##
## A counter is two halves and the page is only one of them. **Buying** happens here, because a
## vendor's shelf is the vendor's; **selling** happens in the bag on the other edge, because what the
## player wants to sell is already laid out there and a second grid of the same items would be a
## second place to hunt through. So a tab is six squares with their prices under a Buy heading, and
## the bag's own Sell button is what says where the selling is done.
##
## The smith is the same arrangement with no shelf at all: he works on whatever the bag has open, and
## his tab is the two prices for it and the reasons he will not. The board is the third shape again:
## three postings that say who to kill, what it pays and where that monster lives, with a Claim on a
## finished one. The fortuneteller is the fourth: two grids of what she can be asked, each square with
## its price, and what she said in their place once one has been paid for (`FortuneTeller`).
##
## Built like `SkillsPage`: it takes the inventory and the save path, `open()` redraws it, `layout()`
## fits it to the window, `closed` is its X, and it carries `UITheme.theme()` itself because it hangs
## straight off a `CanvasLayer`.

## The page's X was pressed.
signal closed
## Another counter was opened. The bag beside the page buys what *this* counter buys and nothing else,
## so the orb vendor's tray and the gear merchant's Sell button are never both live at once.
signal tab_changed(service: String)
## What the page has open off the shelf, or null when it is showing the shelf itself. The bag beside
## it redraws around this: what wearing it would replace is the hover card's under Alt, and a purchase
## reaches the purse, the grid and the tray the same way.
signal offer_changed(item: Item)
## The fortuneteller was paid to put the star over the chest on `cell`. The star is the main scene's.
signal chest_bought(cell: Vector2i)
## A bounty handed in paid this piece, said before the bag or the log hears of it, so the main scene
## can raise the banner a unique new to the log gets off a body.
signal item_claimed(item: Item)
## A bounty handed in paid this much experience, already banked: the main scene fills the bar with it.
signal xp_claimed(amount: int)
## The roads lifted settlements out of the dark: the map has changed and wants saving.
signal towns_revealed
## The relic reading showed the unique `id`: the main scene raises the collection log's banner over it.
signal relic_shown(id: String)
## A spell that is aimed at the map was asked for, at `price`, in the town on `spot`. Nothing has been
## charged and nothing is written down: choosing the land happens on the map, which is the main
## scene's, and so does the paying -- and the marking of that town's drawer -- once land has been
## chosen. The scour and the road home are both bought this way.
signal spell_aimed(reading: String, price: float, spot: Vector2i)
## The way out of the world was asked for, and the question under it answered yes. Nothing has been
## charged and nothing need be: the purse is one of the things left behind. The main scene does it.
signal transcend_pressed

## How wide the page's contents run before they wrap, in panel pixels. It shares a 1152 px window
## with the bag and the doll beside it, so this is a width budget rather than a matter of taste
## -- and it is settled by the shelf: three squares across and the gutters between them, which is
## what makes a price readable under each one. See `Scenes/Town/DESIGN.md`.
const STOCK_COLS := 3
const STOCK_GAP := 4
## A shelf square and the price under it. Four panel pixels wider than `ItemSlot.SIDE`, because what
## sets this is the price and not the square: a coin and four figures at Pixellari's 16 px come to
## just over forty, and a price is no use to anybody cut off after three.
const STOCK_CELL := ItemSlot.SIDE + 4
const BODY_WIDTH := STOCK_COLS * STOCK_CELL + (STOCK_COLS - 1) * STOCK_GAP
const TAB_GAP := 4
## The coin beside a price on a square, at half the sprite's own 16 -- a whole-number step, the way
## the orb tray halves its icons. Full size it would take a fifth of the shelf's width and leave a
## four-figure price nowhere to go.
const PRICE_COIN := 8
## How far apart the page's own rows sit. Tighter than the 6 the pages on the other edge use: a
## counter is a full column -- tabs, name, heading, shelf, prices and two lines under it -- and all of
## it has to reach the foot of a 648 px window without going past it.
const ROW_GAP := 4

## What each counter wears on its tab. A mark rather than a word, so a fortress's five stand in one
## row: in words they took two, and the second row was what pushed the gear tab past the window's
## foot. The full name is the heading under them and the tab's tooltip. The marks stand bare on the
## cream as the pack's craft tabs do, in the pack's brown, and the open one alone is green
## (`tab_mark`) -- which is all the pack changes on its open tab.
const TAB_ICONS := {
	TownServices.BOUNTIES: "scroll",
	TownServices.GEAR: "sword",
	TownServices.ORBS: "gem",
	TownServices.SMITH: "anvil",
	TownServices.FORTUNE: "help",
}
const TAB_MARK := "res://Assets/UI/ui_icon_%s_%s.png"
## How far a choice that is not the one picked is faded, so the picked one is read off a row of them
## at a glance: the settings' three-way rows, and a curse the skulls cannot pay for.
const TAB_REST := Color(1, 1, 1, 0.55)

## The counters this build has actually built, and so the only ones that get a tab: a service not
## named here is listed in the tile panel and given none, which is how a town would advertise a
## counter this build has not built yet without offering a tab that does nothing.
const COUNTERS := [TownServices.BOUNTIES, TownServices.GEAR, TownServices.ORBS, TownServices.SMITH,
		TownServices.FORTUNE]

## What each of her readings wears on its square. Placeholder art, cut by `tools/ui_kit.py` off the
## skill icons' pack in the one colourway neither tree uses: purple is hers.
const FORTUNE_ICONS := {
	FortuneTeller.ROADS: "res://Assets/Fortune/roads.png",
	FortuneTeller.TREASURE: "res://Assets/Fortune/treasure.png",
	FortuneTeller.QUARRY: "res://Assets/Fortune/quarry.png",
	FortuneTeller.RELIC: "res://Assets/Fortune/relic.png",
	FortuneTeller.APPRAISE: "res://Assets/Fortune/appraise.png",
	FortuneTeller.SCOUR: "res://Assets/Fortune/scour.png",
	FortuneTeller.HOMECOMING: "res://Assets/Fortune/homecoming.png",
}
## A spell's mark, at the 16 px it is drawn at doubled -- a whole-number step, as a skill's is.
const SPELL_SIDE := 32
## The halo a live square wears while the cursor is on it, in panel pixels, and how far its mark
## lifts under it. The pack draws no hover face for a loose mark, so this is a `StyleBoxFlat` in the
## gold everything precious in this game is lit in, grown past the square by `expand_margin` and
## drawn behind the mark -- so what shows is a rim of light around it rather than a frame on it.
const HOVER_GLOW := 3
const HOVER_GLOW_COLOR := Color(Palette.GOLD, 0.85)
const HOVER_LIFT := Color(1.2, 1.2, 1.2)

## What each of the fortuneteller's squares says when hovered.
const FORTUNE_TIPS := {
	FortuneTeller.ROADS: "Where the nearest village, town and fortress lie, and every settlement in this ring of land",
	FortuneTeller.TREASURE: "A star that points at the nearest chest until it is opened",
	FortuneTeller.QUARRY: "Where the monster of your bounty lives",
	FortuneTeller.RELIC: "One unique you have not found, and where it is carried",
	FortuneTeller.APPRAISE: "What the piece open in your bag can roll, and how often",
	FortuneTeller.SCOUR: "Uncover a patch of the map you choose",
	FortuneTeller.HOMECOMING: "Stand again in a town you have already walked to",
	FortuneTeller.TRANSCEND: "Leave this world for a new one",
}
## What stands over each half of her list. A reading is asked again and again at a climbing price; a
## great spell is one a settlement. Two words each: the rule itself is in every square's tooltip, and
## a sentence on the page is what this page never writes.
const FORTUNE_HEADINGS := {
	"common": "Readings",
	"great": "Great spells",
}

## What she says before the way out is taken, in the list's place, over the button that takes it.
const TRANSCEND_LINES := [
	"The ice will take this world back, and you will wake in another.",
	"All you have made here is lost: your bag, your gold, your levels, this land. What waits on the other side is worth far more.",
]

var inventory: Inventory
## The map the town stands on, set from outside the way the fight's is. The board needs it and only
## the board does: where a monster lives is a question about the land, and the answer is a tile's name
## and a cell to put the map on.
var view: MapBuilder
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _title: Label
var _rows: VBoxContainer
## The town's own cell, which is what everything on its shelves is priced against.
var _cell := Vector2i.ZERO
## Its `TownWorld.Tier`, which is what a paid reroll stocks the shelves as.
var _tier := -1
## That town's drawer in the save, where its shelves live. `TownState.visit` hands it over and it is
## written in place, so a purchase is saved with the purse it came out of.
var _drawer := {}
## A counter's mark: the pack's brown, or green for the open tab.
static func tab_mark(service: String, lit: bool) -> Texture2D:
	return load(TAB_MARK % [TAB_ICONS[service], "green" if lit else "brown"])


## The counters with a tab, in `TownServices.ORDER`, and which of them is open.
var _tabs: PackedStringArray = []
var _open_tab := ""
## The piece off the shelf the page has open, and which square it stands on. A piece rather than an
## index into the shelf, because it is what `ItemDetails` is reading.
var _offer: Item
var _offer_at := -1
## What the bag has open, which is the piece the smith works on -- a piece in the grid or one off the
## doll beside it, never one off a shelf. It arrives through `bag_changed`.
var _bag_piece: Item
## The orb the bag has in hand ("" for none, `orb_held`), and the bag's own `craft_held`, set from
## outside: a press on a shelf piece spends that orb on it instead of opening it. The orb, the purse
## and the save stay the bag's.
var _held := ""
var craft_held: Callable
## What the last blow of the hammer did, when it is worth saying out loud. A break is the one thing
## that happens on this page the player did not ask for, so it is said rather than left to be noticed.
var _smith_note := ""
## Which of the fortuneteller's readings is written on the page in the list's place ("" for the
## list), and the unique she showed when it is the relic.
var _said := ""
var _relic := ""
## How many settlements the last telling of the roads lifted out of the dark.
var _revealed := 0
## The town's world spot, which the roads are measured from, and the nearest unseen chest as the town was
## walked into -- the player does not move while the page is up, and finding it scans the whole map.
var _spot := Vector2i.ZERO
var _near_chest := HexMap.NO_CELL
## What a shelf is rolled with. Unseeded, the way the bag's crafting rng is: a test that wants a
## known shelf seeds it.
var _stock_rng := RandomNumberGenerator.new()
## And what the smith's break is drawn against, for the same reason and in the same way.
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


## Redraws the page for the town at `cell`, whose world spot is `spot` and whose tier is a
## `TownWorld.Tier`. Services this build has no counter for are dropped rather than shown as a dead
## tab, and the tabs open the page: what tier of settlement it is went the way of every other row
## that was not paying for itself once the shelf wanted the room (`Scenes/Town/DESIGN.md`).
##
## This is also where a town's shelves are filled, the first time it is walked into. After that a
## shelf is new only when Restock is paid for.
func open(town_name: String, services: PackedStringArray, cell: Vector2i, spot: Vector2i,
		tier: int) -> void:
	_cell = cell
	_spot = spot
	_tier = tier
	_said = ""
	_near_chest = view.nearest_chest(true) if view != null else HexMap.NO_CELL
	_title.text = town_name if not town_name.is_empty() else "Town"
	_drawer = inventory.towns.visit(spot)
	# The shelves are filled once and the board whenever all its work has been handed in. Both are
	# asked, so not `or`, which would skip the board whenever the shelves had news.
	var stocked := VendorStock.restock(_drawer, tier, cell, _stock_rng)
	var posted := BountyBoard.restock(_drawer, _board_land(), cell, _stock_rng)
	if stocked or posted:
		inventory.save(_save_path)
	_tabs = PackedStringArray()
	for service: String in services:
		if service in COUNTERS:
			_tabs.append(service)
	if not (_open_tab in _tabs):
		_open_tab = "" if _tabs.is_empty() else _tabs[0]
	# Nothing is open in the bag until it says so, and last town's hammer blow is not news here.
	_bag_piece = null
	_smith_note = ""
	_close_offer(false)


## Which counter is open, for whoever is standing the bag beside it.
func open_tab() -> String:
	return _open_tab


## The bag beside the counter changed what it has open -- which, because selling and discarding both
## close what was open, is also how the counter hears that the bag and the purse have moved. What is
## up is drawn again, so a Buy greyed out for a full bag comes back live the moment a piece is sold
## out from under it, and the smith is pointed at whatever the player is holding up to him.
func bag_changed(open_piece: Item) -> void:
	if not visible:
		return
	_bag_piece = open_piece
	# What the hammer did belongs to the piece it did it to, and that piece is no longer the one up.
	_smith_note = ""
	# And so does what she read off it.
	if _said == FortuneTeller.APPRAISE:
		_said = ""
	_fill()
	layout()


## The bag picked an orb up or put it down: the shelf is greyed by it.
func orb_held(orb: String) -> void:
	_held = orb if craft_held.is_valid() else ""
	if visible:
		_fill()
		layout()


## Draws the open counter again, for a change made off this page (a bounty given up on the journal).
func redraw() -> void:
	if visible:
		_fill()
		layout()


## Full window height against the right edge, where the tile panel stands when no town is open.
func layout() -> void:
	var view_size := get_viewport_rect().size
	var width := _panel.get_combined_minimum_size().x
	_panel.size = Vector2(width, view_size.y / _ui_scale - 2 * UITheme.EDGE)
	_panel.position = Vector2(view_size.x - (width + UITheme.EDGE) * _ui_scale, UITheme.EDGE * _ui_scale)


func _fill() -> void:
	UITheme.clear(_rows)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", TAB_GAP)
	_rows.add_child(tabs)
	var group := ButtonGroup.new()
	for service: String in _tabs:
		var tab := UITheme.button("", UITheme.BARE_BUTTON, TownServices.label(service))
		tab.icon = tab_mark(service, service == _open_tab)
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = service == _open_tab
		tab.pressed.connect(_on_tab_pressed.bind(service))
		tabs.add_child(tab)
	_rows.add_child(UITheme.rule(BODY_WIDTH))
	if _open_tab.is_empty():
		_rows.add_child(_sign("Nobody here is trading yet."))
		return
	# The open counter is named in words as well as by the tab that is down: the pack presses a button
	# by drawing it a pixel lower, which is right for a press you are watching and far too quiet for a
	# state you are reading off a row of them.
	_rows.add_child(UITheme.label(TownServices.label(_open_tab)))
	if _open_tab == TownServices.BOUNTIES:
		_fill_board()
		return
	if _open_tab == TownServices.SMITH:
		_fill_smith()
		return
	if _open_tab == TownServices.FORTUNE:
		_fill_fortune()
		return
	if _offer != null:
		_fill_offer()
		return
	# The shelf and the lines under it scroll, because tabs, a heading, six squares and their prices
	# and an open piece's lines are more than a 648 px window has room for. The tabs and the
	# counter's name stay pinned above, so what moves is the counter's own contents.
	var body := _scrolled(ROW_GAP)
	body.add_child(UITheme.label("Buy"))
	body.add_child(_shelf())
	# New stock now, for gold: pinned at the page's foot, under the scroll, where every counter keeps its buttons -- this shelf only, and dearer every time for good: the town remembers.
	var price := TownPrices.reroll_price(_cell, VendorStock.rerolls(_drawer, _shelf_key()))
	var short := _why_not(price, false)
	var reroll := UITheme.priced_button("Restock", price, "LightButton",
			short if not short.is_empty()
			else "Clear this shelf for new stock. Each time costs twice the last")
	reroll.disabled = not short.is_empty()
	reroll.pressed.connect(_on_reroll_pressed)
	_rows.add_child(reroll)


## The six squares. A bought one stays on the shelf with nothing on it, so what is gone is as plain
## as what is left and the restock has somewhere to land.
func _shelf() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = STOCK_COLS
	grid.add_theme_constant_override("h_separation", STOCK_GAP)
	grid.add_theme_constant_override("v_separation", STOCK_GAP)
	if _open_tab == TownServices.ORBS:
		var orbs := VendorStock.orbs(_drawer)
		for at in orbs.size():
			var orb := orbs[at]
			if orb.is_empty():
				grid.add_child(_sold_square(OrbSlot.SIDE))
				continue
			var price := TownPrices.orb_value(orb, _cell)
			# The tray's own square, so an orb is the same square wherever it is: lit when the purse
			# can cover it and grey when it cannot, which is the state it already draws for "held but
			# no use to you". A grey one still takes the cursor and says why in its tooltip.
			var square := OrbSlot.make(orb, 1, inventory.gold >= price)
			square.tooltip_text = "%s, %s gold%s" % [orb, BigNumber.format(price),
					"" if inventory.gold >= price else ". " + _why_not(price, false)]
			square.pressed.connect(_on_buy_orb.bind(at))
			grid.add_child(_price_cell(square, price))
		return grid
	var shelf := VendorStock.items(_drawer)
	for at in shelf.size():
		var item: Item = shelf[at]
		if item == null:
			grid.add_child(_sold_square(ItemSlot.SIDE))
			continue
		# A bag square takes no mouse input, so the cell around it is what is pressed. There is no
		# scroll under this grid to protect a drag from, which is the whole reason that rule exists.
		var cell := _price_cell(ItemSlot.make(item), TownPrices.buy_price(item))
		# Grey, as the bag's grid greys, where the orb in the player's hand has nothing to do.
		if _held != "" and not OrbTable.can_apply(_held, item):
			cell.get_child(0).modulate = OrbSlot.DIM
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		Cursors.wear(cell, Cursors.HAND)
		cell.gui_input.connect(_on_shelf_input.bind(at))
		grid.add_child(cell)
	return grid


## A box under the counter's name for whatever is too tall for the page, with `gap` between its rows.
## Everything added to it scrolls and everything added to `_rows` after it stays pinned below -- which
## is how an open piece's modifiers can run past the foot of the window while its Buy button cannot.
## No bar is drawn, the way the bag's own stat block draws none.
func _scrolled(gap: int) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_child(scroll)
	var lines := UITheme.vbox(gap, BODY_WIDTH)
	# At least as tall as the scroll, so a row that asks to expand (an accepted bounty's card) can.
	lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(lines)
	return lines


## One square with what it costs under it. The price is on the shelf rather than behind a click
## because six squares with no numbers on them are six questions, and a shop that has to be opened
## six times to be read is a shop nobody reads.
func _price_cell(square: Control, price: float) -> VBoxContainer:
	var cell := UITheme.vbox(2, STOCK_CELL)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.add_child(square)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Nothing to pay carries no coin, the way a priced button with no price does: the roads, once
	# bought in a town, are told again for free, and a coin beside a nought reads as a price of zero
	# gold rather than as no price at all.
	if price <= 0.0:
		var free := UITheme.label("Free", Palette.TEXT_SOFT)
		free.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(free)
		cell.add_child(row)
		return cell
	var coin := TextureRect.new()
	# Set before the texture and the size: a TextureRect's minimum is its own texture until
	# `expand_mode` says otherwise, so a 16 px coin asked for 8 comes back 16.
	coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	coin.texture = Coins.icon()
	coin.custom_minimum_size = Vector2(PRICE_COIN, PRICE_COIN)
	coin.size = Vector2(PRICE_COIN, PRICE_COIN)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(coin)
	# Clipped rather than allowed to push: gold grows with the walk, and a six-figure price out at the
	# frontier would widen the shelf into the panel beside it. The whole number is in the square's
	# tooltip and on the Buy button.
	var label := UITheme.label(BigNumber.format(price), Palette.TEXT_SOFT)
	label.clip_text = true
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	cell.add_child(row)
	return cell


## A square whose thing has been bought: the socket it stood on, at that shelf's own size, with
## nothing on it and no price under it. In a cell of its own so the shelf keeps its three columns
## however much of it has been sold.
static func _sold_square(side: float) -> VBoxContainer:
	var cell := UITheme.vbox(2, STOCK_CELL)
	var square := Panel.new()
	square.custom_minimum_size = Vector2(side, side)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_theme_stylebox_override("panel", ItemRarity.slot_style(ItemRarity.Rarity.COMMON))
	square.tooltip_text = "Bought. Restock fills the shelf again"
	cell.add_child(square)
	return cell


## The piece the player has picked up off the shelf, written out the way the bag writes one, with
## Buy and Back under it. The same `ItemDetails` block, so a piece reads the same on a shelf as it
## does in the bag, and the hover card's Alt is doing the rest of the work.
func _fill_offer() -> void:
	ItemDetails.fill(_scrolled(2), _offer, BODY_WIDTH)

	var price := TownPrices.buy_price(_offer)
	var refused := _why_not(price, true)
	var buy := UITheme.priced_button("Buy", price, "LightButton",
			refused if not refused.is_empty()
			else "Buy this and put it in your bag for %s gold" % BigNumber.format(price))
	buy.disabled = not refused.is_empty()
	buy.pressed.connect(_on_buy_item)
	buy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# One row, the arrow first, as under a piece open in the bag (`BagPage._action_row`).
	var row := HBoxContainer.new()
	var back := UITheme.back_button("Back to what the vendor has")
	back.pressed.connect(_close_offer.bind(true))
	row.add_child(back)
	row.add_child(buy)
	_rows.add_child(row)


## The board. Three postings, each saying who, how far along, what it pays and -- the whole reason a
## board is worth walking up to -- where that monster lives, which `BountyList` writes so that a
## posting reads the same here as it does on the journal ten tiles away.
##
## Each posting carries **Accept**, and only one bounty anywhere may be out at a time: kills count
## against the accepted one and nothing else, and the rest are refused until it is handed in. A
## handed-in posting stays on the board, spent, until all three are in and new work is posted.
func _fill_board() -> void:
	# Having read a board is what puts the journal in the corner, so it is written down as it is drawn.
	if BountyBoard.see(_drawer):
		inventory.save(_save_path)
	var body := _scrolled(ROW_GAP)
	var posted := 0
	# With work out, the board shows that and nothing else: the rest cannot be taken, so they are
	# noise until it is handed in -- and when it was taken in another town, this board says so.
	var busy := not BountyBoard.active(inventory.towns).is_empty()
	for bounty: Dictionary in BountyBoard.bounties(_drawer):
		if bool(bounty.get(BountyBoard.DONE, false)) or (busy and not BountyBoard.is_active(bounty)):
			continue
		posted += 1
		# No Show here: the board is where work is taken on, and the journal is where it is followed.
		var taken := BountyBoard.is_active(bounty)
		var row := BountyList.row(bounty, view, BODY_WIDTH, Callable(),
				"Accepted." if taken and not BountyBoard.ready(bounty) else "")
		var action: Button
		if not taken:
			action = UITheme.button("Accept", "LightButton", "Take this work on")
			action.pressed.connect(_on_accept_pressed.bind(bounty))
		# The one thing this board can do that the journal cannot: pay. A bounty is handed in where it
		# was taken on, so the button is here and nowhere else. The figure is on the card above it and
		# in the tooltip: beside Info there is no room for a reward that grows with the walk.
		elif BountyBoard.ready(bounty):
			var gold := float(bounty.get(BountyBoard.GOLD, 0))
			var prize := BountyBoard.reward_text(bounty)
			var xp := int(bounty.get(BountyBoard.XP, 0))
			action = UITheme.priced_button("Claim", gold, "LightButton", "Hand this in for %s gold%s%s"
					% [BigNumber.format(gold), "" if xp == 0 else ", %d experience" % xp,
						"" if prize.is_empty() else " and " + prize], false)
			# A promised piece has to go in the bag, which the vendor's own rule refuses on a full one.
			var why := _why_not(0.0, not prize.is_empty())
			if not why.is_empty():
				action.disabled = true
				action.tooltip_text = why
			action.pressed.connect(_on_claim_pressed.bind(bounty))
		if action != null:
			action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			BountyList.actions_of(row).add_child(action)
		body.add_child(row)
	if posted == 0:
		body.add_child(_sign("Hand in the bounty you have taken first." if busy
				else "Nothing is posted here now."))


## The land around the town, which is every monster a board may post: a target has to live somewhere
## the player can walk to, and what the map actually generated is the only honest answer to that.
func _board_land() -> PackedStringArray:
	if view == null:
		return PackedStringArray()
	return view.envs_within(_cell, BountyBoard.BOUNTY_RANGE)


func _on_accept_pressed(bounty: Dictionary) -> void:
	if not BountyBoard.accept(inventory.towns, bounty):
		return
	print("Accepted the bounty on %s" % str(bounty.get(BountyBoard.ENEMY, "")))
	inventory.save(_save_path)
	_fill()
	layout()


## One bounty handed in. It pays exactly once -- `claim` is what refuses the second press -- and the
## posting stays on the board, spent, until the restock fills its place.
func _on_claim_pressed(bounty: Dictionary) -> void:
	if not BountyBoard.item_of(bounty).is_empty() and inventory.is_full():
		return
	if not BountyBoard.claim(bounty):
		return
	var reward := float(bounty.get(BountyBoard.GOLD, 0))
	var orbs := BountyBoard.orbs_of(bounty)
	var xp := int(bounty.get(BountyBoard.XP, 0))
	inventory.gold += reward
	for orb: String in orbs:
		inventory.add_orb(orb)
	if xp > 0:
		inventory.add_xp(xp)
		xp_claimed.emit(xp)
	# The promised piece, rolled now: the log hears of a unique as it would off a body.
	var piece := BountyBoard.reward_item(bounty, _cell, _stock_rng)
	if piece != null:
		item_claimed.emit(piece)
		inventory.note_unique(piece.unique)
		inventory.add(piece)
	# The last one handed in is what brings new work, there and then.
	BountyBoard.restock(_drawer, _board_land(), _cell, _stock_rng)
	print("Claimed the bounty on %s for %s gold, %d experience and %s" % [str(bounty.get(BountyBoard.ENEMY, "")),
			BigNumber.format(reward), xp, orbs])
	inventory.save(_save_path)
	_fill()
	layout()
	# Nothing is open, but the bag still has to hear: the purse it draws and the tray it counts have
	# both just moved.
	offer_changed.emit(null)


## Which of the drawer's two shelves the open tab is.
func _shelf_key() -> String:
	return VendorStock.ORBS if _open_tab == TownServices.ORBS else VendorStock.ITEMS


## New stock bought rather than waited for: the open vendor's shelf only, at that vendor's own price.
## The other shelf and the board are not touched.
func _on_reroll_pressed() -> void:
	var price := TownPrices.reroll_price(_cell, VendorStock.rerolls(_drawer, _shelf_key()))
	if inventory.gold < price:
		return
	inventory.gold -= price
	VendorStock.reroll(_drawer, _shelf_key(), _tier, _cell, _stock_rng)
	print("Restocked the %s shelf for %s gold" % [_shelf_key(), BigNumber.format(price)])
	inventory.save(_save_path)
	_fill()
	layout()
	offer_changed.emit(null)


## The smith's counter. He has no shelf: what he works on is the piece the bag page has open, carried
## or worn. No fight can be on while the page is up, so the piece is nobody else's to hold.
##
## The two prices, and what an upgrade would make of the piece and what it risks. Why a button is
## grey is in that button's tooltip and nowhere else on the page.
func _fill_smith() -> void:
	if not _smith_note.is_empty():
		_rows.add_child(_sign(_smith_note, Palette.RUST))
	if _bag_piece == null:
		_rows.add_child(_sign("Open a piece you are carrying or wearing and he will work on it."))
		return
	_rows.add_child(ItemDetails.line(_bag_piece.display_name(), _bag_piece.text_color(), BODY_WIDTH))
	# Air that takes the slack, so the buttons stand at the page's foot as every counter's do.
	var slack := Control.new()
	slack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_rows.add_child(slack)
	var cap := _upgrade_cap()
	var up_price := TownPrices.upgrade_price(_bag_piece)
	var up_why := _smith_why_not(Blacksmith.why_not_upgrade(_bag_piece, cap), up_price)
	_rows.add_child(_smith_button("Upgrade", up_price, up_why,
			"Take this to level %d for %s gold. Its modifiers are rolled again at that level, except any he has locked"
			% [_bag_piece.level + 1, BigNumber.format(up_price)], _on_upgrade_pressed))
	# What the press would buy and what it risks, and only while it can be pressed.
	if up_why.is_empty():
		var risk := Blacksmith.break_chance(_bag_piece)
		_rows.add_child(_sign("Level %d of %d. %s" % [_bag_piece.level + 1, cap,
				"%d%% to break." % roundi(risk * 100.0) if risk > 0.0
				else "Cannot break until level %d." % _bag_piece.safe_level], Palette.TEXT_SOFT))
	var lock_price := TownPrices.lock_price(_bag_piece)
	var lock_why := _smith_why_not(Blacksmith.why_not_lock(_bag_piece), lock_price)
	_rows.add_child(_smith_button("Lock", lock_price, lock_why,
			"Pin one of its modifiers for good, for %s gold" % BigNumber.format(lock_price),
			_on_lock_pressed))


## One of the smith's two, with the coin and the price on it the way a Buy carries them, and the
## reason in its tooltip when it is dead.
func _smith_button(text: String, price: float, refused: String, tooltip: String,
		action: Callable) -> Button:
	var button := _priced_button(text, price, refused, tooltip, action)
	if refused.is_empty():
		Cursors.wear(button, Cursors.HAMMER)
	return button


## `UITheme.priced_button` wired up: dead with the reason in its tooltip when `refused` says one.
func _priced_button(text: String, price: float, refused: String, tooltip: String,
		action: Callable, figure := true) -> Button:
	var button := UITheme.priced_button(text, price, "LightButton",
			refused if not refused.is_empty() else tooltip, figure)
	button.disabled = not refused.is_empty()
	button.pressed.connect(action)
	return button


## The fortuneteller's table: what she can be asked, each with its price -- or, once one has been
## paid for, what she said, with the arrow back to the list under it the way an open shelf piece has.
## The star and the bounty's land are not said here: one is on the map and the other on the card.
func _fill_fortune() -> void:
	var body := _scrolled(ROW_GAP)
	if _said.is_empty():
		# Her spells on the shelf's own grid, each with its price under it: what she sells is bought
		# the way everything else in a town is, and words in a column read as a menu rather than a shop.
		# Two grids, because her list is in two halves and which half a spell is in is its whole rule:
		# a reading is asked again for double, a great spell is one a settlement. The heading says
		# which is which; why a square is dead is still only ever in its tooltip.
		body.add_child(_spell_grid(FORTUNE_HEADINGS["common"], FortuneTeller.COMMON))
		body.add_child(_spell_grid(FORTUNE_HEADINGS["great"], FortuneTeller.GREAT))
		# The way out is not on her grid until a wall has fallen: there is nothing yet to take along.
		# It keeps its word and the full width under the six -- it is not a spell, and a square beside
		# them would read as one. The coin and no figure, as Claim has it: six figures beside that word
		# widen the page into the panel beside it. She says the price when asked.
		if view != null and view.walls_fallen() > 0:
			var out_of_here := _priced_button(FortuneTeller.LABELS[FortuneTeller.TRANSCEND],
					_fortune_price(FortuneTeller.TRANSCEND), _fortune_why_not(FortuneTeller.TRANSCEND),
					FORTUNE_TIPS[FortuneTeller.TRANSCEND],
					_on_reading_pressed.bind(FortuneTeller.TRANSCEND), false)
			out_of_here.custom_minimum_size.x = BODY_WIDTH
			body.add_child(out_of_here)
		return
	match _said:
		FortuneTeller.ROADS:
			for line in FortuneTeller.road_lines(view.towns, _spot):
				body.add_child(_sign(line))
			body.add_child(_sign("%d more settlements in this ring come out of the dark." % _revealed
					if _revealed > 0 else "Every settlement in this ring is already known."))
		FortuneTeller.RELIC:
			CollectionPage.write_hint(body, BODY_WIDTH, _relic, view, CollectionPage.specimen(_relic))
		FortuneTeller.APPRAISE:
			body.add_child(ItemDetails.line(_bag_piece.display_name(), _bag_piece.text_color(), BODY_WIDTH))
			body.add_child(UITheme.rule(BODY_WIDTH))
			# Its own box: the scroll's row gap would pull the table's stripes apart.
			var table := UITheme.vbox(0)
			body.add_child(table)
			for row in FortuneTeller.odds(_bag_piece):
				table.add_child(_odds_row(row, table.get_child_count() % 2 == 1))
		FortuneTeller.TRANSCEND:
			for line: String in TRANSCEND_LINES:
				body.add_child(_sign(line))
			body.add_child(_sign("She asks %s gold." % BigNumber.format(_fortune_price(_said)), Palette.TEXT_SOFT))
	var back := UITheme.back_button("Back to what she can be asked")
	back.pressed.connect(_on_reading_closed)
	if _said != FortuneTeller.TRANSCEND:
		_rows.add_child(back)
		return
	# The question's two answers in one row at the foot, the way an open shelf piece has Back and Buy.
	var answers := HBoxContainer.new()
	answers.add_child(back)
	# The coin and no figure, as Claim has it: the price was on the button that brought the player
	# here, and six figures beside the arrow would widen the page into the panel beside it.
	var price := _fortune_price(_said)
	var refused := _why_not(price, false)
	var leave := UITheme.priced_button("Transcend", price, "LightButton", refused if not refused.is_empty()
			else "Leave this world for %s gold" % BigNumber.format(price), false)
	leave.disabled = not refused.is_empty()
	leave.pressed.connect(transcend_pressed.emit)
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	answers.add_child(leave)
	_rows.add_child(answers)


## One half of her list: a heading, a rule under it and that half's squares on the shelf's own grid.
func _spell_grid(heading: String, readings: Array) -> VBoxContainer:
	var box := UITheme.vbox(ROW_GAP, BODY_WIDTH)
	# A bare heading, the way a vendor's "Buy" is: a rule under each of the two would cost the page
	# the row its second grid's prices need.
	box.add_child(UITheme.label(heading))
	var grid := GridContainer.new()
	grid.columns = STOCK_COLS
	grid.add_theme_constant_override("h_separation", STOCK_GAP)
	grid.add_theme_constant_override("v_separation", STOCK_GAP)
	for reading: String in readings:
		grid.add_child(_price_cell(_spell_square(reading), _fortune_price(reading)))
	box.add_child(grid)
	return box


## One reading on her grid: its name over its mark, lit by a halo while the cursor is on it, and what
## she will not read greyed and dead with the reason in its tooltip -- the shelf's rule, where a piece
## the purse cannot cover greys where it stands. `_price_cell` puts the price under what this returns.
func _spell_square(reading: String) -> Control:
	var refused := _fortune_why_not(reading)
	var cell := UITheme.vbox(2, STOCK_CELL)
	# The name over the mark, in the body font so the longest of them fits a shelf square's width:
	# the art is a placeholder and says nothing on its own, and six pictures whose words are only in
	# their tooltips are six questions -- which is the shelf's own reason for writing its prices out.
	# A refused reading keeps its name in full: what it is has not changed, only whether she will read it.
	var title := UITheme.label(FortuneTeller.LABELS[reading], null, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Clipped rather than allowed to push, as a shelf price is: a name wider than its square would
	# widen the whole column, and through the grid the page, into the panel beside it.
	title.clip_text = true
	title.custom_minimum_size.x = STOCK_CELL
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(title)

	# A Panel rather than the mark itself, because what the hover lights is a stylebox: the mark is
	# its child and fills it.
	var square := Panel.new()
	# Named after the reading, which is how the tests pick one square out of the six.
	square.name = reading
	square.custom_minimum_size = Vector2(SPELL_SIDE, SPELL_SIDE)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	square.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# What a reading is, and -- once it has been asked for -- how often, which is the whole of why the
	# price under it is not the one the player remembers paying.
	var tip: String = FORTUNE_TIPS[reading]
	var times := FortuneTeller.cast(inventory.fortunes, reading)
	if times > 0:
		tip += ". Asked %d time%s" % [times, "" if times == 1 else "s"]
	square.tooltip_text = refused if not refused.is_empty() else tip
	var icon := TextureRect.new()
	# Mode before texture and size, for the reason `_price_cell`'s coin gives: a TextureRect's minimum
	# is its own texture until `expand_mode` says otherwise.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = load(FORTUNE_ICONS[reading])
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	square.add_child(icon)
	cell.add_child(square)
	if not refused.is_empty():
		# OrbSlot's grey, so "you could, and cannot now" reads the same here as on the orb tray. On
		# the square alone: the name above it stays lit, since a spell nobody can cast is still a
		# spell the player is reading about.
		square.modulate = OrbSlot.DIM
		return cell
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
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed):
			_on_reading_pressed(reading))
	return cell


## One modifier she read off a piece: the line with its band on the left, how often it comes up on the right.
func _odds_row(row: Dictionary, striped: bool) -> PanelContainer:
	var line := UITheme.table_row(str(row["line"]), "%.1f%%" % float(row["share"]), striped,
			BODY_WIDTH, null, Palette.TEXT_SOFT)
	var share: Label = line.find_child(UITheme.TABLE_VALUE, true, false)
	share.tooltip_text = "Weight %d" % int(row["weight"])
	share.mouse_filter = Control.MOUSE_FILTER_STOP
	return line


## What a spell costs here: the town's level, doubled once for every time this world has heard the
## reading already. The roads, once told in this town, are told again for nothing -- they are read off
## the world, and the world has not moved -- and a free telling is not a casting, so it never moves
## the count either.
func _fortune_price(reading: String) -> float:
	if reading == FortuneTeller.ROADS and FortuneTeller.asked(_drawer, reading):
		return 0.0
	return TownPrices.fortune_price(reading, _cell, FortuneTeller.cast(inventory.fortunes, reading))


## Why she will not give this spell, or "" when she will. A great spell is sold once a settlement; a
## reading is sold as often as it is paid for.
func _fortune_why_not(reading: String) -> String:
	if view == null:
		return "She sees nothing here."
	if reading in FortuneTeller.GREAT and FortuneTeller.asked(_drawer, reading):
		return "That spell is spent here."
	match reading:
		FortuneTeller.TREASURE:
			var told := FortuneTeller.chest(inventory.fortunes)
			if told != TownWorld.NO_SPOT and view.has_chest(told - view.origin):
				return "The star is already out."
			if _near_chest == HexMap.NO_CELL:
				return "She sees no hidden chest."
		FortuneTeller.QUARRY:
			var bounty := BountyBoard.active(inventory.towns)
			if bounty.is_empty():
				return "No bounty is out."
			if BountyBoard.located(bounty):
				return "Already told."
		FortuneTeller.RELIC:
			if FortuneTeller.hidden(inventory.uniques_found,
					FortuneTeller.peeked(inventory.fortunes)).is_empty():
				return "Every relic is known."
		FortuneTeller.APPRAISE:
			var why := FortuneTeller.why_not_appraise(_bag_piece)
			if not why.is_empty():
				return why
		FortuneTeller.HOMECOMING:
			if view.homes().is_empty():
				return "You have found nowhere else to stand."
		FortuneTeller.TRANSCEND:
			# Asking is free and is where the price is said; the button under her answer is what a
			# short purse greys.
			return ""
	return _why_not(_fortune_price(reading), false)


## One spell asked for. Paid for and written down together, the way a purchase is -- all but the two
## that are aimed at the map, which are paid for once land has been chosen (`spell_aimed`).
func _on_reading_pressed(reading: String) -> void:
	if not _fortune_why_not(reading).is_empty():
		return
	var price := _fortune_price(reading)
	if reading in FortuneTeller.GREAT:
		spell_aimed.emit(reading, price, _spot)
		return
	# Asked for, not done: she says what it costs the player first, and the button under that is the deed.
	if reading == FortuneTeller.TRANSCEND:
		_said = reading
		_fill()
		layout()
		return
	inventory.gold -= price
	# A reading's count is what doubles its price, and only a paid telling moves it: the roads told
	# again for nothing in a town that has already bought them are the same sentence, not a casting.
	if price > 0.0:
		FortuneTeller.note_cast(inventory.fortunes, reading)
	match reading:
		FortuneTeller.ROADS:
			# The one drawer key a reading still writes, and it means the opposite of a great spell's:
			# this town has paid for the roads, so it tells them again for nothing from now on.
			_drawer[FortuneTeller.ASKED + reading] = true
			_revealed = view.reveal_ring_towns(_cell)
			if _revealed > 0:
				towns_revealed.emit()
			_said = reading
		FortuneTeller.TREASURE:
			var spot := view.origin + _near_chest
			inventory.fortunes[FortuneTeller.CHEST] = [spot.x, spot.y]
			chest_bought.emit(_near_chest)
		FortuneTeller.QUARRY:
			BountyBoard.locate(BountyBoard.active(inventory.towns))
		FortuneTeller.RELIC:
			var shown := FortuneTeller.peeked(inventory.fortunes)
			_relic = FortuneTeller.peek(inventory.uniques_found, shown, _stock_rng)
			shown.append(_relic)
			inventory.fortunes[FortuneTeller.PEEKED] = shown
			relic_shown.emit(_relic)
			_said = reading
		FortuneTeller.APPRAISE:
			_said = reading
	print("The fortuneteller read %s for %s gold" % [reading, BigNumber.format(price)])
	inventory.save(_save_path)
	# The land is said on the bounty's own card, so that is where the player is taken to read it.
	if reading == FortuneTeller.QUARRY:
		_on_tab_pressed(TownServices.BOUNTIES)
		return
	_fill()
	layout()
	# Nothing is open, but the bag still has to hear: the purse it draws has just moved.
	offer_changed.emit(null)


func _on_reading_closed() -> void:
	_said = ""
	_fill()
	layout()


## The smith's own refusal, or the one the page owns: a purse that cannot pay. Carried or worn is all
## one to him -- `_bag_piece` is whatever the bag page has open, and that is the player's own piece
## either way -- so a set that is being worn is improved without stripping it off first.
func _smith_why_not(rule: String, price: float) -> String:
	if not rule.is_empty():
		return rule
	return _why_not(price, false)


## The deepest level the smith here may take a piece to: what a boss on this ground could drop, which
## is the ceiling a vendor's shelf already rolls under. So no counter in a town walks a piece past the
## frontier the player has actually fought their way to.
func _upgrade_cap() -> int:
	return maxi(1, MapBuilder.level_of(_cell) + int(LootTable.TIER_LEVEL[EnemyRoster.Tier.BOSS]))


## One blow of the hammer. The gold goes whichever way it falls -- that is what the break chance is --
## and the piece stays where it is either way, a level better or ruined for good.
func _on_upgrade_pressed() -> void:
	var cap := _upgrade_cap()
	var price := TownPrices.upgrade_price(_bag_piece)
	if not _smith_why_not(Blacksmith.why_not_upgrade(_bag_piece, cap), price).is_empty():
		return
	inventory.gold -= price
	if Blacksmith.upgrade(_bag_piece, cap, _smith_rng):
		_smith_note = ""
		print("Upgraded %s to level %d for %s gold"
				% [_bag_piece.display_name(), _bag_piece.level, BigNumber.format(price)])
	else:
		_smith_note = "The hammer broke it."
		print("Broke %s at level %d for %s gold"
				% [_bag_piece.display_name(), _bag_piece.level, BigNumber.format(price)])
	_smith_done()


## One modifier pinned, drawn by the smith rather than chosen. Never breaks anything.
func _on_lock_pressed() -> void:
	var price := TownPrices.lock_price(_bag_piece)
	if not _smith_why_not(Blacksmith.why_not_lock(_bag_piece), price).is_empty():
		return
	inventory.gold -= price
	if not Blacksmith.lock(_bag_piece, _smith_rng):
		return
	print("Locked %s on %s for %s gold" % [ModifierTable.line(_bag_piece.locked_mod()),
			_bag_piece.display_name(), BigNumber.format(price)])
	_smith_done()


## After either blow: the save, the counter and the bag. `offer_changed` with nothing off the shelf is
## how the bag is told to draw itself again -- it keeps the piece it has open, which is the piece that
## has just changed under the player's eyes, and the purse it draws has just moved too.
func _smith_done() -> void:
	inventory.save(_save_path)
	_fill()
	layout()
	offer_changed.emit(null)


## Why this cannot be bought, or "" when it can. The bag's refusal is not a nicety: `Inventory.add`
## on a full bag destroys the worst piece in it, so buying into one would be paying a vendor to throw
## something away. An orb passes `needs_room` false -- orbs are counts, outside the cap entirely.
func _why_not(price: float, needs_room: bool) -> String:
	if inventory.gold < price:
		return "Your purse is short."
	if needs_room and inventory.is_full():
		return "Your bag is full."
	return ""


## Opens the square that was pressed. The cell takes the press because the square inside it does not.
func _on_shelf_input(event: InputEvent, at: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	var shelf := VendorStock.items(_drawer)
	if at < 0 or at >= shelf.size() or shelf[at] == null:
		return
	# With an orb in hand the press spends it on the piece where it stands, the player's gamble on a
	# piece that is not theirs yet: the price under it is read off the rarity and moves with it.
	if _held != "":
		craft_held.call(shelf[at], VendorStock.put.bind(_drawer, at, shelf[at]))
		_fill()
		layout()
		return
	_offer = shelf[at]
	_offer_at = at
	_fill()
	layout()
	offer_changed.emit(_offer)


## Back to the shelf. `tell` is false while the page is being rebuilt from scratch, where whoever
## opened it is about to point the bag at this counter anyway.
func _close_offer(tell: bool) -> void:
	_offer = null
	_offer_at = -1
	_fill()
	layout()
	if tell:
		offer_changed.emit(null)


## One piece over the counter. Paid for and taken off the shelf together, and refused outright on a
## short purse or a full bag -- the button is already grey, and this is the same rule where a caller
## cannot see one.
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


## One orb over the counter. Counted in rather than added to the bag, so nothing can refuse it but
## the purse.
func _on_buy_orb(orb: String, at: int) -> void:
	var price := TownPrices.orb_value(orb, _cell)
	if not _why_not(price, false).is_empty():
		return
	inventory.gold -= price
	inventory.add_orb(orb)
	VendorStock.take(_drawer, VendorStock.ORBS, at)
	print("Bought %s for %s gold" % [orb, BigNumber.format(price)])
	inventory.save(_save_path)
	_fill()
	layout()
	# Nothing is open, but the bag still has to hear: the purse it draws and the tray it counts have
	# both just moved.
	offer_changed.emit(null)


func _on_tab_pressed(service: String) -> void:
	_open_tab = service
	_smith_note = ""
	_said = ""
	_close_offer(true)
	tab_changed.emit(service)


## A wrapped line of the page's own width. Word wrapping rather than the refusal panel's arbitrary
## kind: these are sentences, not file paths.
static func _sign(text: String, color: Variant = null) -> Label:
	var label := UITheme.label(text, color, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = BODY_WIDTH
	return label
