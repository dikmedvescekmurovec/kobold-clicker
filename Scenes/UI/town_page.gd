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
## so its Sell button is live only at the gear merchant's.
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
## A bounty on `enemy` was handed in and everything it paid is already in the purse, the tray and the
## bag: `orbs` is name -> count and `piece` null for none. The main scene says so, as a fight's
## verdict does.
signal bounty_paid(enemy: String, gold: float, xp: int, orbs: Dictionary, piece: Item)
## The board's Reward was pressed: the main scene puts the three options of a cleared board back up.
signal choice_asked
## The roads lifted settlements out of the dark: the map has changed and wants saving.
signal towns_revealed
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
const STOCK_GAP := 8
## A shelf square and the price under it. Four panel pixels wider than `ItemSlot.SIDE`, because what
## sets this is the price and not the square: a coin and four figures at Pixellari's 16 px come to
## just over forty, and a price is no use to anybody cut off after three.
const STOCK_CELL := ItemSlot.SIDE + 4
const BODY_WIDTH := STOCK_COLS * STOCK_CELL + (STOCK_COLS - 1) * STOCK_GAP
const TAB_GAP := 2
## A tab's width and the open one's height. Every mark stands centred on one, so a small mark (the
## fortuneteller's) takes as much of the row as a wide one. A shut tab stands `TAB_RISE` lower, which
## is what puts the open one in front of the rest; `TAB_CORNER` rounds a tab's two top corners.
const TAB_SIDE := 22
const TAB_RISE := 3
const TAB_CORNER := 2
## A shut tab's face and the same under the cursor: the tan every socket is, washed out, so the row
## reads as cards standing behind the page and the open one as the page itself.
const TAB_SHUT := Color(Palette.SLOT_TAN, 0.45)
const TAB_SHUT_HOVER := Color(Palette.SLOT_TAN, 0.8)
## The coin beside a price on a square, at half the sprite's own 16 -- a whole-number step, the way
## the orb tray halves its icons. Full size it would take a fifth of the shelf's width and leave a
## four-figure price nowhere to go.
const PRICE_COIN := 8
## How far apart the page's own rows sit. Everything under the tabs scrolls and the buttons are pinned,
## so the column's height is no longer what sets this: 8 is air, where the 4 it was made the counter
## read as one block.
const ROW_GAP := 8

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
	TownServices.FORTUNE: "crystal",
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
	FortuneTeller.APPRAISE: "res://Assets/Fortune/appraise.png",
	FortuneTeller.SCOUR: "res://Assets/Fortune/scour.png",
	FortuneTeller.HOMECOMING: "res://Assets/Fortune/homecoming.png",
	FortuneTeller.TRANSCEND: "res://Assets/Fortune/transcend.png",
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

## What each of the fortuneteller's squares says when hovered, after its name: what the spell does,
## as an outcome -- never how it is asked for (the user's rule, 2026-09-25).
const FORTUNE_TIPS := {
	FortuneTeller.ROADS: "Brings every settlement between the ice walls around you, and the land beside it, out of the fog",
	FortuneTeller.TREASURE: "Puts a star over the nearest chest you have not seen. It stays until that chest is opened",
	FortuneTeller.APPRAISE: "Lists every modifier the open item can roll, the range it rolls in at the item's level, and how often it comes up",
	FortuneTeller.SCOUR: "Brings a tile and the two rings of land around it, nineteen tiles, out of the fog",
	FortuneTeller.HOMECOMING: "Moves you to a settlement or the Gollux cave you have already charted",
	FortuneTeller.TRANSCEND: "Ends this world and starts a new one, worth far more",
}
## What stands over each half of her list. A reading is asked again and again at a climbing price; a
## great spell is one a settlement. Two words each: the rule itself is in every square's tooltip, and
## a sentence on the page is what this page never writes.
const FORTUNE_HEADINGS := {
	"common": "Readings",
	"great": "Great spells",
}

## What goes in front of a reading's id in `inventory.tips` once its answer's "Don't show this again"
## has been ticked, and how wide her answer is set.
const SKIP_TOLD := "skip_told_"
const TOLD_WIDTH := 180.0
## What stands round her answer inside the window: its title bar, its padding, and the Dismiss and the
## tick under it. The answer scrolls in what the window has left after these.
const TOLD_CHROME := 100.0
const TOLD_PANEL := "Panel"

## What she says before the way out is taken, in the list's place, over the button that takes it.
const TRANSCEND_LINES := [
	"The ice will take this world back, and you will wake in another.",
	"Your bag, gold, orbs, levels and this land are lost. What waits on the other side is worth far more.",
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
## The bag's orb card, for the orb vendor's squares (`_card_for`).
var _orb_card: OrbCard
var craft_held: Callable
## What the last blow of the hammer did, when it is worth saying out loud. A break is the one thing
## that happens on this page the player did not ask for, so it is said rather than left to be noticed.
var _smith_note := ""
## The smith's strike, which survives the counter being drawn again: seconds into the one playing (-1
## when he stands still), strikes pressed for while it played, still owed, and the face the bench on
## screen now shows. An owed strike starts `SWING_OVERLAP` frames before the one playing would end.
const SWING_OVERLAP := 3
## The anvil's ring as the hammer meets it -- on the strike's third frame -- and the crack of a piece
## it breaks in its place.
const STRIKE_LANDS := 2 * DialogueBox.FRAME_TIME
const ANVIL_SOUND := preload("res://Sounds/Sfx/anvil_hit.ogg")
const BREAK_SOUND := preload("res://Sounds/Sfx/anvil_break.ogg")
var _swing_clock := -1.0
var _swings_owed := 0
var _smith_face: AtlasTexture
## Her answer, over the whole window while it is up (null otherwise), and the scroll it is written in.
var _told: Control
var _told_scroll: ScrollContainer
## The counter's one scroll and what it holds, kept through every redraw (`_scrolled` empties and
## refills them) so a purchase, a blow or an orb picked up leaves it where the player had it; another
## counter or another piece off the shelf puts it back at the top (`_scroll_for`).
var _scroll: ScrollContainer
var _scroll_lines: VBoxContainer
var _scroll_for := []
## The last reading cast whose answer is not shown any more (ticked "Don't show this again"): the page
## says it in one line under her grids instead, until another counter is opened.
var _cast := ""
## The town's world spot, which a spell aimed at the map is cast from, and the nearest unseen chest as the town was
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
	_scroll = UITheme.scroll()
	_rows.add_child(_scroll)
	_scroll_lines = UITheme.vbox(0, BODY_WIDTH)
	# At least as tall as the scroll, so a row that asks to expand (an accepted bounty's card) can.
	_scroll_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Room over the first row inside the scroll, which clips: a shelf's squares wear frames that stand
	# `FRAME_HEAD` above them.
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
	_cast = ""
	_close_told()
	_near_chest = view.nearest_chest(true) if view != null else HexMap.NO_CELL
	_title.text = town_name if not town_name.is_empty() else "Town"
	_drawer = inventory.towns.visit(spot)
	# The shelves are filled once and the board whenever all its work has been handed in. Both are
	# asked, so not `or`, which would skip the board whenever the shelves had news.
	var stocked := VendorStock.restock(_drawer, tier, cell, _stock_rng, inventory.walls_credited)
	var posted := BountyBoard.restock(_drawer, _board_land(), cell, _stock_rng, inventory.walls_credited)
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
	_scroll_for = []
	_close_offer(false)


## Which counter is open, for whoever is standing the bag beside it.
func open_tab() -> String:
	return _open_tab


## Whether this town has `service`'s counter at all, open or not.
func has_counter(service: String) -> bool:
	return service in _tabs


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


## Where the main scene stands the page, in window pixels: empty for the whole window. Held upright,
## the top of it, over the bag.
var area := Rect2()


## Full window height against the right edge, where the tile panel stands when no town is open.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.RIGHT, layout)


func _fill() -> void:
	UITheme.clear(_rows, _scroll)
	UITheme.clear(_scroll_lines)
	_scroll.hide()
	# Folder tabs standing on a line: the line runs under every shut tab, through the gaps and out to
	# the page's edge, and breaks under the open one, which is drawn in the page's own cream -- so the
	# counter below reads as that tab's page. No gap between the tabs and the line: they are one thing.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 0)
	tabs.custom_minimum_size.x = BODY_WIDTH
	_rows.add_child(tabs)
	var group := ButtonGroup.new()
	for service: String in _tabs:
		if tabs.get_child_count() > 0:
			tabs.add_child(_tab_line(TAB_GAP))
		var tab := UITheme.button("", UITheme.BARE_BUTTON, TownServices.label(service))
		tab.icon = tab_mark(service, service == _open_tab)
		_tab_faces(tab, service == _open_tab)
		tab.toggle_mode = true
		tab.button_group = group
		tab.button_pressed = service == _open_tab
		tab.pressed.connect(_on_tab_pressed.bind(service))
		tabs.add_child(tab)
	var rest := _tab_line(0)
	rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(rest)
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
	body.add_child(_shelf())
	if _open_tab == TownServices.ORBS:
		body.add_child(UITheme.section("Trade up"))
		body.add_child(_upscales())
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
				grid.add_child(_sold_square(ItemSlot.SIDE))
				continue
			var price := TownPrices.orb_value(orb, _cell)
			# The tray's own square, so an orb is the same square wherever it is: lit when the purse
			# can cover it and grey when it cannot, which is the state it already draws for "held but
			# no use to you". A grey one still takes the cursor and says why in its tooltip.
			var square := OrbSlot.make(orb, 1, inventory.gold >= price, false, ItemSlot.SIDE)
			# The bag's own card for it, with the price where the bag says how to use one.
			_card_for(square, "%s gold%s" % [BigNumber.format(price),
					"" if inventory.gold >= price else ". " + _why_not(price, false)],
					Palette.TEXT_SOFT if inventory.gold >= price else Palette.RUST)
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


## The orb vendor's trades: every unlocked orb but the first, each for `OrbTable.UPSCALE_COST` of the
## orb before it in the tray, with that orb and the count under it where a price would be. Lit while
## the player holds enough.
func _upscales() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = STOCK_COLS
	grid.add_theme_constant_override("h_separation", STOCK_GAP)
	grid.add_theme_constant_override("v_separation", STOCK_GAP)
	for orb: String in OrbTable.unlocked(inventory.walls_credited):
		var from := OrbTable.upscale_from(orb)
		if from.is_empty():
			continue
		var held := inventory.orb_count(from)
		var enough := held >= OrbTable.UPSCALE_COST
		var square := OrbSlot.make(orb, 1, enough, false, ItemSlot.SIDE)
		_card_for(square, "Trade %d %s for one" % [OrbTable.UPSCALE_COST, from],
				Palette.TEXT_SOFT if enough else Palette.RUST)
		square.pressed.connect(_on_upscale)
		# Priced the way gold is, with the orb it costs standing in the coin's place.
		grid.add_child(_cost_cell(square, str(OrbTable.UPSCALE_COST), OrbTable.icon(from), enough,
				OrbSlot.ICON))
	return grid


## A box under the counter's name for whatever is too tall for the page, with `gap` between its rows.
## Everything added to it scrolls and everything added to `_rows` after it stays pinned below -- which
## is how an open piece's modifiers can run past the foot of the window while its Buy button cannot.
## No bar is drawn, the way the bag's own stat block draws none.
func _scrolled(gap: int) -> VBoxContainer:
	_rows.move_child(_scroll, _rows.get_child_count() - 1)
	_scroll.show()
	_scroll_lines.add_theme_constant_override("separation", gap)
	if [_open_tab, _offer] != _scroll_for:
		_scroll_for = [_open_tab, _offer]
		_scroll.scroll_vertical = 0
	return _scroll_lines


## One square with what it costs under it. The price is on the shelf rather than behind a click
## because six squares with no numbers on them are six questions, and a shop that has to be opened
## six times to be read is a shop nobody reads.
func _price_cell(square: Control, price: float) -> VBoxContainer:
	return _cost_cell(square, BigNumber.format(price), Coins.icon(), inventory.gold >= price)


## A square with a cost under it: `mark` (a coin at `PRICE_COIN`, or the orb a trade takes at the
## tray's size, since an orb at 8 is a speck of colour and not an orb) and the
## figure beside it, the pair centred under the square in the body font -- so every counter's cells
## are the one cell, and a four-figure price sits inside its column instead of running into the next.
## The figure is brick while `ok` is false: what the purse cannot cover is read off the shelf at a
## glance, not only off a tooltip.
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
	# Clipped rather than allowed to push: gold grows with the walk, and a seven-figure price out at the
	# frontier would widen the shelf into the panel beside it. A clipped Label has no width of its own,
	# so it is given the figure's, up to what the cell has left. The whole number is in the square's
	# tooltip and on the Buy button.
	label.clip_text = true
	var wide := UITheme.theme().get_font("font", "SmallLabel").get_string_size(figure,
			HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.SMALL_FONT_SIZE).x
	label.custom_minimum_size.x = minf(ceilf(wide), room)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(label)
	cell.add_child(row)
	return cell


## A counter's tab as a folder tab: framed on three sides in the socket's dark brown with its top
## corners rounded. A shut one stands lower, washed in tan, with the line it stands on for a bottom
## edge; the open one stands full height in the page's own cream with no bottom edge, so it runs on
## into the counter under it -- a state read off the row at a glance, where the green mark alone was
## a colour change on twelve pixels.
static func _tab_faces(tab: Button, lit: bool) -> void:
	tab.custom_minimum_size = Vector2(TAB_SIDE, TAB_SIDE if lit else TAB_SIDE - TAB_RISE)
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


## One tab's face. Square pixels: no anti-aliasing on the rounded corners, which at `ui_scale` 2 would
## blur them into the cream. The mark sits a pixel off the top so it is centred on what shows of the
## tab rather than on the line under it.
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
	face.anti_aliasing = false
	face.set_content_margin_all(2)
	return face


## A stretch of the line the tabs stand on: between two tabs (`width`) or out to the page's edge.
static func _tab_line(width: float) -> Panel:
	var line := Panel.new()
	var edge := StyleBoxFlat.new()
	edge.bg_color = Color.TRANSPARENT
	edge.border_color = Palette.SLOT_TAN_DK
	edge.border_width_bottom = 1
	line.add_theme_stylebox_override("panel", edge)
	line.custom_minimum_size.x = width
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


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
	var buy := UITheme.priced_button("Buy", price, UITheme.GO_BUTTON,
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
## board is worth walking up to -- the lands that monster lives on, which `BountyList` writes so that a
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
	var heading := UITheme.section("Tier " + Achievements.RANK_NAMES[BountyBoard.board_tier(_drawer)])
	body.add_child(heading)
	# How far the board is to its reward, at the heading's end: a round pip lit for each posting handed
	# in, and the gift in the last place, lit while a cleared board's reward waits.
	var board := BountyBoard.bounties(_drawer)
	if not board.is_empty():
		var done := board.filter(func(b: Dictionary) -> bool: return bool(b.get(BountyBoard.DONE, false))).size()
		var waiting := not pending_choice().is_empty()
		var pips := KillPips.new(board.size())
		pips.show_board(done, waiting)
		pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pips.mouse_filter = Control.MOUSE_FILTER_PASS
		pips.tooltip_text = ("Your reward is waiting" if waiting
				else "%d of %d handed in. Clear the board for a reward" % [done, board.size()])
		heading.add_child(pips)
	# A cleared board's reward put away untaken is brought back from here, at the head of the board.
	if not pending_choice().is_empty():
		var reward := UITheme.button("Reward", "SmallGoButton", "Choose your reward for clearing this board")
		reward.pressed.connect(choice_asked.emit)
		body.add_child(reward)
	var posted := 0
	var active_at := BountyBoard.active_spot(inventory.towns)
	var busy := not active_at.is_empty()
	# Work taken on at another board heads this one: which bounty is out, and where it is handed in --
	# a board that only said "no" left the player to go and find out both.
	if busy and active_at != TownState.key(_spot):
		var away := BountyList.row(BountyBoard.active(inventory.towns), view, BODY_WIDTH, false,
				"Taken at %s. Claim it there." % _town_at(active_at))
		body.add_child(away)
	# The one taken on here first, then the rest -- still shown while work is out, dimmed and with Accept
	# grey, so the player can see what is waiting for them to come back.
	var postings := BountyBoard.bounties(_drawer).filter(func(b: Dictionary) -> bool:
			return BountyBoard.is_active(b))
	postings.append_array(BountyBoard.bounties(_drawer).filter(func(b: Dictionary) -> bool:
			return not BountyBoard.is_active(b) and not bool(b.get(BountyBoard.DONE, false))))
	for bounty: Dictionary in postings:
		posted += 1
		var taken := BountyBoard.is_active(bounty)
		var row := BountyList.row(bounty, view, BODY_WIDTH, false,
				"Accepted." if taken and not BountyBoard.ready(bounty) else "")
		var action: Button
		if not taken:
			action = UITheme.button("Accept", "SmallGoButton",
					"Hand in the bounty you have taken first" if busy else "Take this work on")
			action.disabled = busy
			if busy:
				row.modulate = TAB_REST
			action.pressed.connect(_on_accept_pressed.bind(bounty))
		# The one thing this board can do that the journal cannot: pay. A bounty is handed in where it
		# was taken on, so the button is here and nowhere else. The figure is on the card above it and
		# in the tooltip: beside Info there is no room for a reward that grows with the walk.
		elif BountyBoard.ready(bounty):
			var gold := float(bounty.get(BountyBoard.GOLD, 0))
			var prize := BountyBoard.reward_text(bounty)
			var xp := int(bounty.get(BountyBoard.XP, 0))
			action = UITheme.priced_button("Claim", gold, "SmallGoButton", "Hand this in for %s gold%s%s"
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
	if posted == 0 and not busy:
		body.add_child(_sign("Nothing is posted here now."))


## What the town whose drawer is filed under `at` is called, off the map that named it.
func _town_at(at: String) -> String:
	var called := "" if view == null else view.name_of(TownState.spot(at) - view.origin)
	return called if not called.is_empty() else "another town"


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
	var piece := BountyBoard.reward_item(bounty, _cell, _stock_rng, Achievements.unlocked(inventory))
	if piece != null:
		item_claimed.emit(piece)
		inventory.note_unique(piece.unique)
		inventory.add(piece)
	# The last one handed in clears the board, which offers its reward and raises the town's tier, and
	# brings new work there and then -- in that order, so the new work is posted at the new tier.
	BountyBoard.clear(_drawer, _cell, _stock_rng, Achievements.unlocked(inventory), inventory.walls_credited)
	BountyBoard.restock(_drawer, _board_land(), _cell, _stock_rng, inventory.walls_credited)
	print("Claimed the bounty on %s for %s gold, %d experience and %s" % [str(bounty.get(BountyBoard.ENEMY, "")),
			BigNumber.format(reward), xp, orbs])
	var counted := {}
	for orb: String in orbs:
		counted[orb] = int(counted.get(orb, 0)) + 1
	bounty_paid.emit(str(bounty.get(BountyBoard.ENEMY, "")), reward, xp, counted, piece)
	inventory.save(_save_path)
	_fill()
	layout()
	# Nothing is open, but the bag still has to hear: the purse it draws and the tray it counts have
	# both just moved.
	offer_changed.emit(null)


## The options this town's cleared board has offered and the player has not taken (`BountyBoard.choice`).
func pending_choice() -> Array:
	return BountyBoard.choice(_drawer)


## Why option `index` of the cleared board cannot be taken now, or "": a piece needs room in the bag.
func why_not_take(index: int) -> String:
	var offered := pending_choice()
	if index < 0 or index >= offered.size():
		return "Nothing to take"
	return _why_not(0.0, offered[index].has(BountyBoard.CHOICE_ITEM))


## Takes option `index` of the cleared board, the claim's way: a piece is said before the log and the bag
## hear of it, orbs go to the tray, gold to the purse and experience to the bar. The other two are gone.
## False when it was refused.
func take_choice(index: int) -> bool:
	if not why_not_take(index).is_empty():
		return false
	var option := BountyBoard.take_choice(_drawer, index)
	var piece: Item = option.get(BountyBoard.CHOICE_ITEM)
	if piece != null:
		item_claimed.emit(piece)
		inventory.note_unique(piece.unique)
		inventory.add(piece)
		print("Took %s for clearing the board" % piece.display_name())
	elif option.has(BountyBoard.CHOICE_GOLD):
		inventory.gold += float(option[BountyBoard.CHOICE_GOLD])
		print("Took %s gold for clearing the board" % BigNumber.format(float(option[BountyBoard.CHOICE_GOLD])))
	elif option.has(BountyBoard.CHOICE_XP):
		inventory.add_xp(int(option[BountyBoard.CHOICE_XP]))
		xp_claimed.emit(int(option[BountyBoard.CHOICE_XP]))
		print("Took %d experience for clearing the board" % int(option[BountyBoard.CHOICE_XP]))
	else:
		inventory.add_orb(str(option[BountyBoard.CHOICE_ORB]), int(option[BountyBoard.CHOICE_COUNT]))
		print("Took %d %s for clearing the board" % [int(option[BountyBoard.CHOICE_COUNT]),
				option[BountyBoard.CHOICE_ORB]])
	inventory.save(_save_path)
	_fill()
	layout()
	offer_changed.emit(null)
	return true


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
	VendorStock.reroll(_drawer, _shelf_key(), _tier, _cell, _stock_rng, inventory.walls_credited)
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
		_rows.add_child(_sign(_smith_note, Palette.BRICK))
	if _bag_piece == null:
		_fill_idle_smith()
		return
	# The piece on the anvil, written out as an offer is: what an upgrade rolls again is its modifiers,
	# so they are what is worth reading while the hammer is up -- and watching them change after a blow
	# is the whole of what the blow bought. It scrolls; the buttons stay pinned at the foot.
	var body := _scrolled(ROW_GAP)
	_smith_bench(body, ItemSlot.make(_bag_piece))
	var details := UITheme.vbox(2, BODY_WIDTH)
	body.add_child(details)
	ItemDetails.fill(details, _bag_piece, BODY_WIDTH, [], false, false)
	var cap := _upgrade_cap()
	var up_price := TownPrices.upgrade_price(_bag_piece)
	var up_why := _smith_why_not(Blacksmith.why_not_upgrade(_bag_piece, cap), up_price)
	# What the press would buy and what it risks, over the button, and only while it can be pressed:
	# the level it goes from and to on the left, the risk on the right in the colour a loss is.
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
			% [_bag_piece.level + 1, BigNumber.format(up_price)], _on_upgrade_pressed, UITheme.GO_BUTTON))
	var lock_price := TownPrices.lock_price(_bag_piece)
	var lock_why := _smith_why_not(Blacksmith.why_not_lock(_bag_piece), lock_price)
	_rows.add_child(_smith_button("Lock", lock_price, lock_why,
			"Pin one of its modifiers for good, for %s gold" % BigNumber.format(lock_price),
			_on_lock_pressed))


## The smith with nothing held up to him: the empty square a piece would stand on beside himself at
## his anvil, and his two services with what each does and the least it costs on anything the player
## has -- so the tab says what he is for before a piece is picked, rather than one line sending the
## player off to the bag to find out.
func _fill_idle_smith() -> void:
	var body := _scrolled(ROW_GAP)
	_smith_bench(body, ItemSlot.empty("Open an item in your bag or on your doll", tab_mark(TownServices.SMITH, false)))
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


## The top of the smith's counter, whether a piece is open or not: `square` -- the empty anvil square,
## or the open piece -- on the left, by the anvil he is drawn with, and the smith on the right. The
## portrait rests on its first frame; an Upgrade or a Lock plays his strike once (`_strike`).
func _smith_bench(body: VBoxContainer, square: Control) -> void:
	var bench := HBoxContainer.new()
	bench.add_theme_constant_override("separation", ROW_GAP)
	bench.alignment = BoxContainer.ALIGNMENT_CENTER
	square.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bench.add_child(square)
	var socket := PanelContainer.new()
	var style := BountyList.flat(Palette.SLOT_TAN, 0)
	style.content_margin_left = DialogueBox.SOCKET_PAD.x
	style.content_margin_top = DialogueBox.SOCKET_PAD.y
	style.content_margin_right = DialogueBox.SOCKET_PAD.z
	style.content_margin_bottom = DialogueBox.SOCKET_PAD.w
	socket.add_theme_stylebox_override("panel", style)
	var strip: Texture2D = load(DialogueBox.PORTRAITS % "blacksmith")
	var face := AtlasTexture.new()
	face.atlas = strip
	face.region = Rect2(0, 0, strip.get_width(), DialogueBox.PORTRAIT_HEIGHT)
	var picture := TextureRect.new()
	picture.texture = face
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	socket.add_child(picture)
	bench.add_child(socket)
	body.add_child(bench)
	_smith_face = face
	_show_swing()


## An Upgrade or a Lock went through: he strikes now, or once the strike playing is nearly done, and
## `sound` rings out as the hammer lands -- at once when he does not move.
func _strike(sound: AudioStream) -> void:
	if Settings.animations == Settings.Anim.NONE:
		Juice.sound(sound)
		return
	create_tween().tween_callback(func() -> void: Juice.sound(sound)).set_delay(STRIKE_LANDS)
	if _swing_clock >= 0.0:
		_swings_owed += 1
	else:
		_swing_clock = 0.0


func _process(delta: float) -> void:
	if _swing_clock < 0.0:
		return
	_swing_clock += delta
	var end := _swing_frames() - (SWING_OVERLAP if _swings_owed > 0 else 0)
	if _swing_clock >= end * DialogueBox.FRAME_TIME:
		if _swings_owed > 0:
			_swings_owed -= 1
			_swing_clock = 0.0
		else:
			_swing_clock = -1.0
	_show_swing()


func _swing_frames() -> int:
	return maxi(1, _smith_face.atlas.get_height() / DialogueBox.PORTRAIT_HEIGHT) if _smith_face != null else 1


## The frame the strike is on, or the first while he stands still.
func _show_swing() -> void:
	if _smith_face != null:
		var frame := int(_swing_clock / DialogueBox.FRAME_TIME) if _swing_clock >= 0.0 else 0
		_smith_face.region.position.y = mini(frame, _swing_frames() - 1) * DialogueBox.PORTRAIT_HEIGHT


## One of the smith's services on his idle counter: its name, the least it costs on any piece in
## `prices` (none when nothing the player has can take it), and what it does.
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


## One of the smith's two, with the coin and the price on it the way a Buy carries them, and the
## reason in its tooltip when it is dead.
func _smith_button(text: String, price: float, refused: String, tooltip: String,
		action: Callable, variation := "LightButton") -> Button:
	var button := UITheme.priced_button(text, price, variation,
			refused if not refused.is_empty() else tooltip)
	button.disabled = not refused.is_empty()
	button.pressed.connect(action)
	if refused.is_empty():
		Cursors.wear(button, Cursors.HAMMER)
	return button


## The fortuneteller's table: what she can be asked, each with its price, and under it one line naming
## the last spell cast whose answer the player said not to show again. Her answers are popups (`_tell`),
## and so is the way out's question (`_ask_way_out`).
func _fill_fortune() -> void:
	var body := _scrolled(ROW_GAP)
	# Her spells on the shelf's own grid, each with its price under it: what she sells is bought the way
	# everything else in a town is, and words in a column read as a menu rather than a shop. Two grids,
	# because her list is in two halves and which half a spell is in is its whole rule: a reading is
	# asked as often as it is paid for, a great spell is one a settlement. Why a square is dead is only ever in
	# its tooltip.
	body.add_child(_spell_grid(FORTUNE_HEADINGS["common"], FortuneTeller.COMMON))
	# The way out stands with the great spells, as a square of its own, once a wall has fallen: before
	# that there is nothing yet to take along (the user, 2026-09-25, in place of a full-width button).
	var great: Array = FortuneTeller.GREAT.duplicate()
	if view != null and view.walls_fallen() > 0:
		great.append(FortuneTeller.TRANSCEND)
	body.add_child(_spell_grid(FORTUNE_HEADINGS["great"], great))
	if not _cast.is_empty():
		_rows.add_child(_sign("You cast %s." % FortuneTeller.LABELS[_cast], Palette.TEXT_SOFT))


## What she said, over the whole window as the bag's questions are (`BagPage._ask`): a titled panel
## with the reading's name on its bar, the answer in a scroll, and Dismiss and "Don't show this again"
## under it, in reach from the moment it opens however long the answer is. A ticked Dismiss writes
## `SKIP_TOLD + reading` into `inventory.tips`, and from then on that reading answers with one line on
## the page instead (`_cast`). The appraisal offers no tick: its table is the whole of what was bought.
func _tell(reading: String) -> void:
	_close_told()
	var can_skip := reading != FortuneTeller.APPRAISE
	if can_skip and SKIP_TOLD + reading in inventory.tips:
		_cast = reading
		return
	_cast = ""
	var body := _open_told(FortuneTeller.LABELS[reading])
	_answer(reading, _told_scroll.get_child(0))

	var dismiss := UITheme.button("Dismiss", "LightButton", "")
	dismiss.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(dismiss)
	var skip := BagPage.check_box("Don't show this again")
	skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	skip.visible = can_skip
	body.add_child(skip)
	dismiss.pressed.connect(func() -> void:
		if (skip.get_node(BagPage.TICK_NAME) as Button).button_pressed:
			inventory.tips.append(SKIP_TOLD + reading)
			inventory.save(_save_path)
		_leave_told())
	# A reading is something bought, so it comes up as a reward does: the wash and the sparks.
	_show_told(true)


## One of her popups, empty: a holder over the whole window, a titled panel with no X -- like a reward's,
## its way out is at its foot (and Escape) -- and a scroll in `_told_scroll` for what she says. Returns
## the body, for the buttons that go under the scroll.
func _open_told(title: String) -> VBoxContainer:
	_close_told()
	_told = Control.new()
	_told.size = get_viewport_rect().size
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


## The way out, asked before it is done: what is lost and what it costs, over Cancel and Transcend. The
## price is only on the square that brought the player here; the button carries the coin and no figure,
## as Claim does. A short purse greys the deed, never the asking.
func _ask_way_out() -> void:
	var body := _open_told(FortuneTeller.LABELS[FortuneTeller.TRANSCEND])
	var lines: VBoxContainer = _told_scroll.get_child(0)
	for line: String in TRANSCEND_LINES:
		lines.add_child(BountyList.wrapped(line, TOLD_WIDTH))
	var price := _fortune_price(FortuneTeller.TRANSCEND)
	var answers := HBoxContainer.new()
	answers.add_theme_constant_override("separation", ROW_GAP)
	body.add_child(answers)
	var cancel := UITheme.button("Cancel", "LightButton", "Stay in this world")
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_leave_told)
	answers.add_child(cancel)
	var refused := _why_not(price, false)
	var leave := UITheme.priced_button("Transcend", price, "LightButton", refused if not refused.is_empty()
			else "Leave this world for %s gold" % BigNumber.format(price), false)
	leave.disabled = not refused.is_empty()
	leave.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	leave.pressed.connect(func() -> void:
		_close_told()
		transcend_pressed.emit())
	answers.add_child(leave)
	_show_told(false)


## Her answer to `reading`, written into `lines`.
func _answer(reading: String, lines: VBoxContainer) -> void:
	match reading:
		FortuneTeller.ROADS:
			# That they are all on the map, and no more: where each one lies is the map's to show.
			lines.add_child(BountyList.wrapped("Every settlement between these walls is now on your map.",
					TOLD_WIDTH))
		FortuneTeller.TREASURE:
			lines.add_child(BountyList.wrapped("A star now stands over the nearest chest you have not seen.",
					TOLD_WIDTH))
			lines.add_child(BountyList.wrapped("It stays until that chest is opened.", TOLD_WIDTH,
					Palette.TEXT_SOFT))
		FortuneTeller.APPRAISE:
			lines.add_child(ItemDetails.line(_bag_piece.display_name(), _bag_piece.text_color(), TOLD_WIDTH))
			# What the table is, since a column of lines and percentages says nothing on its own: the
			# base's whole pool, not what this piece has.
			lines.add_child(BountyList.wrapped("Every modifier a %s can roll" % _bag_piece.type, TOLD_WIDTH,
					Palette.TEXT_SOFT))
			lines.add_child(UITheme.rule(TOLD_WIDTH))
			# Its own box: the answer's row gap would pull the table's stripes apart.
			var table := UITheme.vbox(0)
			lines.add_child(table)
			for row in FortuneTeller.odds(_bag_piece):
				table.add_child(_odds_row(row, table.get_child_count() % 2 == 1, TOLD_WIDTH))


## Her answer's scroll, as tall as the answer or as what the window leaves; `Juice.popup` keeps it centred.
func _place_told() -> void:
	if _told == null:
		return
	var view_size := get_viewport_rect().size
	_told.size = view_size
	var lines: Control = _told_scroll.get_child(0)
	_told_scroll.custom_minimum_size.y = minf(lines.get_combined_minimum_size().y,
			view_size.y / _ui_scale - TOLD_CHROME)


## Whether one of her answers (or the way out's question) stands over the window, for a banner to wait behind.
func telling() -> bool:
	return _told != null


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


## One half of her list: a heading, a rule under it and that half's squares on the shelf's own grid.
func _spell_grid(heading: String, readings: Array) -> VBoxContainer:
	var box := UITheme.vbox(ROW_GAP, BODY_WIDTH)
	box.add_child(UITheme.section(heading))
	var grid := GridContainer.new()
	grid.columns = STOCK_COLS
	grid.add_theme_constant_override("h_separation", STOCK_GAP)
	grid.add_theme_constant_override("v_separation", STOCK_GAP)
	for reading: String in readings:
		var square := _spell_square(reading)
		# The roads, once bought in this town, say so where the price was, and no coin.
		grid.add_child(_cost_cell(square, "Bought", null, true) if _roads_bought(reading)
				else _price_cell(square, _fortune_price(reading)))
	box.add_child(grid)
	return box


## One reading on her grid: its mark, lit by a halo while the cursor is on it, and what she will not
## read greyed and dead with the reason in its tooltip -- the shelf's rule, where a piece the purse
## cannot cover greys where it stands. `_price_cell` puts the price under what this returns. No name
## over it (the user's call, 2026-09-25): the badges carry the spell, and the tooltip says what it does.
func _spell_square(reading: String) -> Control:
	var refused := _fortune_why_not(reading)
	# A Panel rather than the mark itself, because what the hover lights is a stylebox: the mark is
	# its child and fills it.
	var square := Panel.new()
	# Named after the reading, which is how the tests pick one square out of the six.
	square.name = reading
	square.custom_minimum_size = Vector2(SPELL_SIDE, SPELL_SIDE)
	square.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	square.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	# What a reading does, with no name before it (the user's call, 2026-09-25). Not how often it has
	# been asked: the price under it already says it has climbed.
	square.tooltip_text = refused if not refused.is_empty() else FORTUNE_TIPS[reading]
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
	if not refused.is_empty():
		# OrbSlot's grey, so "you could, and cannot now" reads the same here as on the orb tray.
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
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
				and event.pressed):
			square.accept_event()  # Before the redraw frees it, which would let the press through to the map.
			_on_reading_pressed(reading))
	return square


## One modifier she read off a piece: the line with its band on the left, how often it comes up on the right.
func _odds_row(row: Dictionary, striped: bool, width: float) -> PanelContainer:
	var line := UITheme.table_row(str(row["line"]), "%.1f%%" % float(row["share"]), striped,
			width, null, Palette.TEXT_SOFT)
	var share: Label = line.find_child(UITheme.TABLE_VALUE, true, false)
	share.tooltip_text = "Weight %d" % int(row["weight"])
	share.mouse_filter = Control.MOUSE_FILTER_STOP
	return line


## What a spell costs here, off the town's level.
func _fortune_price(reading: String) -> float:
	return TownPrices.fortune_price(reading, _cell)


## Whether this town has sold the roads already: once a town, as a great spell is.
func _roads_bought(reading: String) -> bool:
	return reading == FortuneTeller.ROADS and FortuneTeller.asked(_drawer, reading)


## Why she will not give this spell, or "" when she will. A great spell is sold once a settlement; a
## reading is sold as often as it is paid for.
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
		FortuneTeller.TRANSCEND:
			# Asking is free and is where the price is said; the Transcend in her question is what a
			# short purse greys, and the price under the square is brick.
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
		_ask_way_out()
		return
	inventory.gold -= price
	match reading:
		FortuneTeller.ROADS:
			# The one drawer key a reading still writes: this town has sold the roads, and sells them no more.
			_drawer[FortuneTeller.ASKED + reading] = true
			if view.reveal_ring_towns(_cell) > 0:
				towns_revealed.emit()
		FortuneTeller.TREASURE:
			var spot := view.origin + _near_chest
			inventory.fortunes[FortuneTeller.CHEST] = [spot.x, spot.y]
			chest_bought.emit(_near_chest)
	print("The fortuneteller read %s for %s gold" % [reading, BigNumber.format(price)])
	inventory.save(_save_path)
	_tell(reading)
	_fill()
	layout()
	# Nothing is open, but the bag still has to hear: the purse it draws has just moved.
	offer_changed.emit(null)


## The smith's own refusal, or the one the page owns: a purse that cannot pay. Carried or worn is all
## one to him -- `_bag_piece` is whatever the bag page has open, and that is the player's own piece
## either way -- so a set that is being worn is improved without stripping it off first.
func _smith_why_not(rule: String, price: float) -> String:
	if not rule.is_empty():
		return rule
	return _why_not(price, false)


## The deepest level the smith here may take a piece to: the level of the deepest land in this town's
## wall circle (`MapBuilder.circle_level`), 3 inside the first wall -- a boss's tier rode on top of it
## until the user's 2026-10-03. Gated by the circle, not the town's own tile, so every fortress
## between the same two walls works to the same ceiling.
func _upgrade_cap() -> int:
	return MapBuilder.circle_level(_cell)


## One blow of the hammer. The gold goes whichever way it falls -- that is what the break chance is --
## and the piece stays where it is either way, a level better or ruined for good.
func _on_upgrade_pressed() -> void:
	var cap := _upgrade_cap()
	var price := TownPrices.upgrade_price(_bag_piece)
	if not _smith_why_not(Blacksmith.why_not_upgrade(_bag_piece, cap), price).is_empty():
		return
	inventory.gold -= price
	var upgraded := Blacksmith.upgrade(_bag_piece, cap, _smith_rng)
	_strike(ANVIL_SOUND if upgraded else BREAK_SOUND)
	if upgraded:
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
	_strike(ANVIL_SOUND)
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


## The bag's orb card on `square` while the cursor is over it, with `note` as its last line where the
## bag says how to use one. Beside the square, as `TipCard` stands; placed again deferred, since the
## first pass measures labels that have not laid out yet. A square freed under the cursor (the tab
## redrawn by a purchase) takes the card with it.
func _card_for(square: OrbSlot, note: String, tone: Color) -> void:
	square.hovered.connect(func(orb: String) -> void:
		_orb_card.fill(orb, inventory.orb_count(orb), note, tone)
		_orb_card.show()
		_place_orb_card(square)
		_place_orb_card.call_deferred(square))
	square.unhovered.connect(_orb_card.hide)
	square.tree_exiting.connect(_orb_card.hide)


func _place_orb_card(square: OrbSlot) -> void:
	if not _orb_card.visible or not is_instance_valid(square) or not square.is_inside_tree():
		return
	_orb_card.reset_size()
	_orb_card.position = ItemCard.beside(square.get_global_rect(),
			_orb_card.get_combined_minimum_size() * _ui_scale, get_viewport_rect().size, ItemCard.GAP * _ui_scale)


## Why this cannot be bought, or "" when it can. The bag's refusal is not a nicety: `Inventory.add`
## on a full bag destroys the worst piece in it, so buying into one would be paying a vendor to throw
## something away. An orb passes `needs_room` false -- orbs are counts, outside the cap entirely.
func _why_not(price: float, needs_room: bool) -> String:
	if inventory.gold < price:
		return "Your purse is short"
	if needs_room and inventory.is_full():
		return "The bag is full"
	return ""


## Opens the square that was pressed. The cell takes the press because the square inside it does not.
func _on_shelf_input(event: InputEvent, at: int) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed):
		return
	accept_event()  # Before the redraw frees the cell, which would let the press through to the map.
	var shelf := VendorStock.items(_drawer)
	if at < 0 or at >= shelf.size() or shelf[at] == null:
		return
	# With an orb in hand the press spends it on the piece where it stands, the player's gamble on a
	# piece that is not theirs yet: the price under it is read off the rarity and moves with it. The
	# shelf is drawn again when the orb lands, which a question about lowering it may put off.
	if _held != "":
		craft_held.call(shelf[at], func() -> void:
			VendorStock.put(_drawer, at, shelf[at])
			redraw())
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


## `OrbTable.UPSCALE_COST` of the orb before this one traded for one of it. No gold changes hands.
func _on_upscale(orb: String) -> void:
	var from := OrbTable.upscale_from(orb)
	if from.is_empty() or inventory.orb_count(from) < OrbTable.UPSCALE_COST \
			or orb not in OrbTable.unlocked(inventory.walls_credited):
		return
	for i in OrbTable.UPSCALE_COST:
		inventory.spend_orb(from)
	inventory.add_orb(orb)
	print("Traded %d %s for one %s" % [OrbTable.UPSCALE_COST, from, orb])
	inventory.save(_save_path)
	_fill()
	layout()
	offer_changed.emit(null)


func _on_tab_pressed(service: String) -> void:
	_open_tab = service
	_smith_note = ""
	_cast = ""
	_close_told()
	_close_offer(true)
	tab_changed.emit(service)


## A wrapped line of the page's own width. Word wrapping rather than the refusal panel's arbitrary
## kind: these are sentences, not file paths.
static func _sign(text: String, color: Variant = null) -> Label:
	var label := UITheme.label(text, color, true)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = BODY_WIDTH
	return label
