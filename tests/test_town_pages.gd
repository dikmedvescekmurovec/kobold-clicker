extends "res://tests/town_base.gd"
## Headless checks for the towns: which counters a settlement has, what a thing is worth over one, the
## selling the bag does while it stands at one, and the drawer all of it is saved in. Run from the
## project folder:
##   python tests/run_all.py town_pages


func _run() -> void:
	_check(_test_fortune() == true, "fortuneteller tests ran to the end")
	_check(await _test_selling() == true, "selling tests ran to the end")
	_check(await _test_buying() == true, "buying tests ran to the end")
	_check(await _test_orb_on_a_shelf() == true, "orb on a shelf tests ran to the end")
	_check(await _test_smithing() == true, "smithing tests ran to the end")
	_check(await _test_board() == true, "board tests ran to the end")
	_check(await _test_entering() == true, "entering tests ran to the end")
	_check(await _test_fortune_page() == true, "fortune page tests ran to the end")
	_check(await _test_curses_the_world_feels() == true, "curses the world feels tests ran to the end")
	_check(await _test_tree_builder() == true, "tree builder tests ran to the end")
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	_report("town: pages")


## The bag standing at a counter: what the gear merchant's button does, what the orb vendor's tray
## does, and that neither of them is the other.
func _test_selling() -> bool:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4)
	inventory.add(piece)
	inventory.add(Item.rolled("Leather Boots", ItemRarity.Rarity.RARE, rng, 4))
	inventory.add_orb("Orb of Chaos", 3)
	var page := BagPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame

	# Out of a town nothing has changed: the piece is thrown away, not sold.
	page._select_item(inventory.items.find(piece))
	_check(_deep_button(page._actions, "Discard") != null, "outside a town a piece is discarded")
	_check(_deep_button(page._actions, "Sell") == null, "and there is nothing to sell it to")
	_check(page._sections.get_child(0).get_children().any(func(child: Node) -> bool:
			return child is Button and (child as Button).tooltip_text.begins_with("Discard ")),
			"and a level is cleared")

	# At the gear merchant the same two buttons buy instead.
	page.shop(PackedStringArray([TownServices.GEAR]))
	page._select_item(inventory.items.find(piece))
	var sell := _deep_button(page._actions, "Sell")
	_check(sell != null and _deep_button(page._actions, "Discard") == null,
			"at the merchant the piece is sold rather than thrown away")
	_check(page._sections.get_child(0).get_children().any(func(child: Node) -> bool:
			return child is Button and (child as Button).tooltip_text.begins_with("Sell ")),
			"and a level is sold at once")
	var price := TownPrices.sell_price(piece)
	if sell != null:
		sell.pressed.emit()
	_check(inventory.gold == price and price > 0, "the purse holds the price (%d, want %d)"
			% [inventory.gold, price])
	_check(inventory.items.find(piece) == -1, "and the piece is gone from the bag")
	# A Ctrl-click sells too, and the square says so for the card's foot.
	await process_frame
	var boot_square: Control = page._sections.get_children().filter(
			func(n: Node) -> bool: return n is GridContainer)[0].get_child(0)
	_check(boot_square.get_meta(ItemCard.KEYS, {}) == {"shift": "equip", "ctrl": "sell"},
			"at the merchant a square answers to Ctrl for Sell")
	var boot: Item = (boot_square as ItemSlot).item
	page._on_clicked((boot_square.get_parent() as Control).position + boot_square.position
			+ boot_square.size / 2.0, false, true)
	_check(inventory.items.find(boot) == -1 and inventory.gold == price + TownPrices.sell_price(boot),
			"a Ctrl-click sells the piece")
	# Put back for the checks below, which count the purse and the bag as they were.
	inventory.add(boot)
	inventory.gold = price
	# Never sell greys the piece's own Sell, and a Ctrl-click passes it by.
	boot.locked = true
	page._select_item(inventory.items.find(boot))
	var locked_sell := _deep_button(page._actions, "Sell")
	_check(locked_sell != null and locked_sell.disabled, "a piece under Never sell cannot be sold")
	page._press_action(false)
	_check(inventory.items.has(boot) and inventory.gold == price, "and a Ctrl-click leaves it")
	boot.locked = false
	page._select_item(-1)
	page.refresh()

	# Sell all takes the ordinary pieces over the counter and asks about a unique among them on its
	# own; Sell on that question sells it for its own price.
	var relic := Item.rolled_unique(UniqueTable.ids()[0], rng, 4)
	inventory.add(relic)
	page.refresh()
	await process_frame
	for button: Button in page._sections.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with("Sell "):
			button.pressed.emit()
			break
	var sell_all := _deep_button(page._confirm, "Sell")
	if sell_all != null:
		sell_all.pressed.emit()
	_check(inventory.gold == price + TownPrices.sell_price(boot) and inventory.items.size() == 1
			and inventory.items[0] == relic,
			"Sell all sells the ordinary pieces and keeps the unique (%d, want %d)"
			% [inventory.gold, price + TownPrices.sell_price(boot)])
	_check(page._confirm != null and _deep_button(page._confirm, "Don't sell") != null,
			"and asks whether to sell the unique too")
	var relic_price := TownPrices.sell_price(relic)
	var sell_relic := _deep_button(page._confirm, "Sell")
	if sell_relic != null:
		sell_relic.pressed.emit()
	_check(inventory.items.is_empty() and inventory.gold == price + TownPrices.sell_price(boot) + relic_price,
			"Sell on that question sells it for its price")
	inventory.add(boot)
	inventory.gold = price
	page.refresh()

	# An orb cannot be sold over a gear counter.
	var held := inventory.orb_count("Orb of Chaos")
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == held and inventory.gold == price,
			"the gear merchant does not buy orbs")

	# The orb vendor buys neither gear nor orbs: a press with no piece open picks the orb up.
	page.shop(PackedStringArray([TownServices.ORBS]))
	page._select_item(0)
	_check(_deep_button(page._actions, "Discard") != null and _deep_button(page._actions, "Sell") == null,
			"the orb vendor does not buy gear")
	page._select_item(-1)
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == held and inventory.gold == price,
			"nor orbs")
	_check(page._armed == "Orb of Chaos", "the press picked the orb up")
	page._on_orb_pressed("Orb of Chaos")

	# With a piece open the press shuts it and picks the orb up, vendor or not: never a sale, never a craft.
	page._select_item(0)
	page._on_orb_pressed("Orb of Chaos")
	_check(page._selected == -1 and page._armed == "Orb of Chaos",
			"a piece open is shut and the orb picked up instead")
	_check(inventory.orb_count("Orb of Chaos") == held and inventory.gold == price,
			"and nothing was spent or paid for it")
	page._on_orb_pressed("Orb of Chaos")

	# A board is a counter for work, not for goods: nothing is bought or sold over one.
	page.shop(PackedStringArray([TownServices.BOUNTIES]))
	page._select_item(0)
	_check(_deep_button(page._actions, "Discard") != null and _deep_button(page._actions, "Sell") == null,
			"over a bounty board a piece is thrown away rather than sold")
	page._select_item(-1)
	var carried := inventory.orb_count("Orb of Chaos")
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == carried, "and the board buys no orbs either")

	# Leaving the town puts every one of those back.
	page.shop(PackedStringArray())
	page._select_item(0)
	_check(_deep_button(page._actions, "Discard") != null and _deep_button(page._actions, "Sell") == null,
			"outside a town Discard is Discard again")
	page.queue_free()
	await process_frame
	return true


## An orb in the bag's hand, spent on a piece still on the shelf: the two pages wired as the main
## scene wires them. The piece is changed where it stands, written into the town's drawer, and priced
## as what it has become; nothing is opened and nothing is bought.
func _test_orb_on_a_shelf() -> bool:
	var inventory := Inventory.new()
	var bag := BagPage.new(inventory, TEST_PATH, 1.0)
	var page := TownPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(bag)
	root.add_child(page)
	page.craft_held = bag.craft_held
	bag.held_changed.connect(page.orb_held)
	await process_frame
	page._stock_rng.seed = WORLD_SEED
	page.open("Testholm", PackedStringArray([TownServices.GEAR]), TOWN_CELL, Vector2i(140, 128),
			TownWorld.Tier.MEDIUM)
	bag.shop(PackedStringArray([TownServices.GEAR]))
	var drawer := inventory.towns.visit(Vector2i(140, 128))
	# A common piece put on the shelf by hand, so transmutation has something to do whatever was rolled.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	VendorStock.put(drawer, 0, Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 3))
	var before := TownPrices.buy_price(VendorStock.items(drawer)[0])
	inventory.add_orb("Orb of Transmutation", 2)

	bag._on_orb_pressed("Orb of Transmutation")
	_check(page._held == "Orb of Transmutation", "the counter hears which orb is in hand")
	page._on_shelf_input(_press(), 0)
	var after: Item = VendorStock.items(drawer)[0]
	_check(after.rarity == ItemRarity.Rarity.UNCOMMON, "the shelf piece came up uncommon where it stood")
	_check(inventory.orb_count("Orb of Transmutation") == 1, "for one orb")
	_check(page._offer == null and inventory.items.is_empty(), "and was neither opened nor bought")
	_check(TownPrices.buy_price(after) > before, "the vendor asks more for what it has become")
	var saved: Item = VendorStock.items(Inventory.load_from(TEST_PATH).towns.visit(Vector2i(140, 128)))[0]
	_check(saved.rarity == ItemRarity.Rarity.UNCOMMON, "and the save holds the shelf as it now stands")
	# A broken piece is one no orb can touch: a press there costs nothing and still opens nothing.
	var ruined := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3)
	ruined.broken = true
	VendorStock.put(drawer, 0, ruined)
	page._on_shelf_input(_press(), 0)
	_check(inventory.orb_count("Orb of Transmutation") == 1 and page._offer == null,
			"a refused shelf piece spends nothing")
	# Put down, a press opens the piece again; and the bag going away puts it down.
	bag._on_orb_pressed("Orb of Transmutation")
	page._on_shelf_input(_press(), 0)
	_check(page._offer != null, "with no orb in hand a press opens the piece as before")
	bag._on_orb_pressed("Orb of Transmutation")
	bag.hide()
	_check(bag._armed == "" and page._held == "", "hiding the bag puts the orb down")
	bag.queue_free()
	page.queue_free()
	await process_frame
	return true


## The other half of a counter: the shelf on the town page. What it costs, what it refuses, and what
## a purchase moves.
func _test_buying() -> bool:
	var inventory := Inventory.new()
	var page := TownPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame
	page._stock_rng.seed = WORLD_SEED
	page.open("Testholm", PackedStringArray([TownServices.GEAR, TownServices.ORBS]),
			TOWN_CELL, Vector2i(130, 128), TownWorld.Tier.MEDIUM)
	_check(page.open_tab() == TownServices.GEAR, "the gear counter is open first (%s)" % page.open_tab())
	_check(inventory.towns.visited(Vector2i(130, 128)), "walking in wrote the town down")
	var drawer := inventory.towns.visit(Vector2i(130, 128))
	_check(VendorStock.items(drawer).size() == VendorStock.SIZE, "with six pieces on its shelf")

	# A piece off the shelf opens the way a piece in the bag does, with a price on the button.
	var offered: Item = VendorStock.items(drawer)[0]
	# The card beside a hovered square goes away with the press and stays away. Every redraw makes
	# new squares and `VendorStock.items` makes new pieces, so it is the place that is remembered.
	var card := ItemCard.new(1.0)
	root.add_child(card)
	# Asked by hand below: left running, it would ask about the real cursor every frame and forget.
	card.set_process(false)
	await process_frame
	var spot := Vector2.ZERO
	for square: ItemSlot in get_nodes_in_group(ItemSlot.GROUP):
		if page.is_ancestor_of(square):
			spot = square.get_global_rect().get_center()
			break
	_check(card.hovered(spot, false) != null, "a shelf square has its card")
	card.hovered(spot, true)
	page._on_shelf_input(_press(), 0)
	await process_frame
	_check(card.hovered(spot, false) == null, "and a press on it puts the card away")
	page._close_offer(true)
	await process_frame
	_check(card.hovered(spot + Vector2.ONE, false) == null, "even with the shelf back under the cursor")
	card.queue_free()
	page._on_shelf_input(_press(), 0)
	_check(page._offer != null and page._offer.type == offered.type, "pressing a square opens the piece")
	var price := TownPrices.buy_price(offered)
	_check(price > TownPrices.sell_price(offered),
			"a vendor asks more than it pays (%d over %d)" % [price, TownPrices.sell_price(offered)])
	var buy := _deep_button(page._rows, "Buy")
	_check(buy != null and buy.text == "Buy" and UITheme.price_of(buy) == BigNumber.format(price),
			"the button carries the price (%s)"
			% [buy.text if buy != null else "no button"])

	# The lines scroll and the buttons under them do not, the way the bag's stat block works: an elite
	# off a deep shelf carries six modifiers and is taller than a counter three squares wide, and a
	# Buy pushed off the foot of the page cannot be pressed.
	var block: ScrollContainer = null
	for child: Node in page._rows.get_children():
		if child is ScrollContainer:
			block = child
	_check(block != null and block.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED,
			"an open offer's lines scroll")
	_check(block != null and buy != null and buy.get_parent().get_index() > block.get_index(),
			"with the Buy button pinned under them")

	# A short purse buys nothing, and the button says so rather than letting the press through.
	_check(buy != null and buy.disabled, "with an empty purse the button is dead")
	if buy != null:
		buy.pressed.emit()
	page._on_buy_item()
	_check(inventory.gold == 0 and inventory.total() == 0, "and nothing moved")
	_check(VendorStock.items(drawer)[0] != null, "the piece is still on the shelf")

	# Nor does a full bag: `Inventory.add` would push it over the cap and overencumber the player.
	inventory.gold = price * 4
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	while not inventory.is_full():
		inventory.add(Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng, 1))
	page._fill()
	buy = _deep_button(page._rows, "Buy")
	_check(buy != null and buy.disabled, "a full bag kills the button too")
	page._on_buy_item()
	_check(inventory.total() == Inventory.CAPACITY and inventory.gold == price * 4,
			"and buying into one changes nothing")

	# Room and gold both: the piece crosses, the purse pays and the square empties.
	inventory.remove(inventory.items[0])
	page._fill()
	buy = _deep_button(page._rows, "Buy")
	_check(buy != null and not buy.disabled, "with room and gold the button is live")
	page._on_buy_item()
	_check(inventory.gold == price * 3, "the purse paid the price (%d, want %d)"
			% [inventory.gold, price * 3])
	_check(inventory.total() == Inventory.CAPACITY, "the piece is in the bag")
	_check(inventory.items[inventory.total() - 1].type == offered.type, "and it is the piece bought")
	_check(VendorStock.items(drawer)[0] == null, "the square it stood on is empty")
	_check(VendorStock.items(drawer).size() == VendorStock.SIZE, "and the shelf still has six squares")
	_check(page._offer == null, "the shelf is back up")
	_check(Inventory.load_from(TEST_PATH).gold == price * 3, "and the purchase was saved")

	# The orb counter: a count rather than a thing, so a full bag has nothing to say about it.
	page._on_tab_pressed(TownServices.ORBS)
	var orb := VendorStock.orbs(drawer)[0]
	var orb_price := TownPrices.orb_value(orb, TOWN_CELL)
	inventory.gold = 0
	# Hovered, a shelf orb shows the bag's orb card, with its price and why it cannot be had.
	page._fill()
	var shelf_orbs := page._rows.find_children("*", "OrbSlot", true, false)
	(shelf_orbs[0] as OrbSlot).hovered.emit((shelf_orbs[0] as OrbSlot).orb)
	var card_text := " ".join(page._orb_card.find_children("*", "Label", true, false).map(
			func(label: Label) -> String: return label.text))
	_check(page._orb_card.visible and OrbTable.describe(orb) in card_text
			and BigNumber.format(orb_price) in card_text and "Not enough gold" in card_text,
			"a shelf orb's card says what it does, its price and why not: %s" % card_text)
	(shelf_orbs[0] as OrbSlot).unhovered.emit()
	_check(not page._orb_card.visible, "and goes when the cursor does")
	page._on_buy_orb(orb, 0)
	_check(inventory.orb_count(orb) == 0 and not VendorStock.orbs(drawer)[0].is_empty(),
			"a short purse buys no orb either")
	# Made taller than the page, so there is somewhere to scroll to.
	page._scroll_lines.custom_minimum_size.y = 4000
	await process_frame
	page._scroll.scroll_vertical = 100
	inventory.gold = orb_price
	page._on_buy_orb(orb, 0)
	_check(inventory.orb_count(orb) == 1 and inventory.gold == 0,
			"paid for one orb (%d held, %d left)" % [inventory.orb_count(orb), inventory.gold])
	_check(VendorStock.orbs(drawer)[0].is_empty(), "and its square is empty")
	await process_frame
	_check(page._scroll.scroll_vertical == 100,
			"and the shelf is still scrolled where it was (%d)" % page._scroll.scroll_vertical)
	page._on_tab_pressed(TownServices.GEAR)
	page._on_tab_pressed(TownServices.ORBS)
	_check(page._scroll.scroll_vertical == 0, "another counter starts at the top")
	page._scroll_lines.custom_minimum_size.y = 0

	# Trading up: three of the orb before it in the tray for one, and nothing short of three.
	inventory.orbs = {"Orb of Transmutation": 2}
	page._on_upscale("Orb of Augmentation")
	_check(inventory.orb_count("Orb of Transmutation") == 2 and inventory.orb_count("Orb of Augmentation") == 0,
			"two orbs trade up to nothing")
	inventory.add_orb("Orb of Transmutation", 2)
	page._on_upscale("Orb of Augmentation")
	_check(inventory.orb_count("Orb of Transmutation") == 1 and inventory.orb_count("Orb of Augmentation") == 1,
			"three trade up to one of the next")
	page._on_upscale("Orb of Transmutation")
	_check(inventory.orb_count("Orb of Transmutation") == 1, "and nothing trades up to the first")
	_check(Inventory.load_from(TEST_PATH).orb_count("Orb of Augmentation") == 1, "and the trade was saved")
	page.queue_free()
	await process_frame
	return true


## The smith's counter on the page: which settlements have one, that it acts on the piece the bag has
## open and on nothing else, and what a press moves.
func _test_smithing() -> bool:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var page := TownPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame
	page._stock_rng.seed = WORLD_SEED
	var spot := Vector2i(130, 128)

	# Only a fortress has one, which is `TownServices`' rule read off the page that has to obey it.
	for tier: int in [TownWorld.Tier.SMALL, TownWorld.Tier.MEDIUM, TownWorld.Tier.FORTRESS]:
		page.open("Testholm", TownServices.services_for(tier, spot, WORLD_SEED), TOWN_CELL, spot, tier)
		_check((TownServices.SMITH in page._tabs) == (tier == TownWorld.Tier.FORTRESS),
				"a %d has a smith tab only if it is a fortress (%s)" % [tier, page._tabs])
		# The board is the one counter every settlement has, so every one of them carries its tab.
		_check(TownServices.BOUNTIES in page._tabs, "and every one of them has a board tab")
	page._on_tab_pressed(TownServices.SMITH)
	_check(page.open_tab() == TownServices.SMITH, "the smith's tab is open")
	_check(_button(page._rows, "Upgrade") == null and _button(page._rows, "Lock") == null,
			"with nothing open in the bag there is nothing to press")
	var named := func() -> bool:
		return page._rows.get_children().any(func(c: Node) -> bool:
			return c is Label and (c as Label).text == TownServices.label(TownServices.SMITH))
	_check(named.call(), "and the counter is named")

	# A piece held up to him: both prices on their buttons, and a purse that cannot cover either.
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 1)
	inventory.add(piece)
	page.bag_changed(piece)
	# Its name heads the counter.
	_check(not named.call(), "over a piece the counter is not named")
	_check(page._upgrade_cap() == MapBuilder.circle_level(TOWN_CELL),
			"the cap is this circle's deepest land (%d)" % page._upgrade_cap())
	# Every tile in a circle shares it: the first circle's deepest land is its outer ring.
	_check(MapBuilder.circle_level(Vector2i(1, 0)) == MapBuilder.level_of(
			Vector2i(MapBuilder.START_LAND_RADIUS, 0)), "the first circle is gated by its outer ring")
	var price := TownPrices.upgrade_price(piece)
	var upgrade := _button(page._rows, "Upgrade")
	var lock := _button(page._rows, "Lock")
	_check(upgrade != null and upgrade.text == "Upgrade" and UITheme.price_of(upgrade) == BigNumber.format(price),
			"the hammer carries its price (%s)" % [upgrade.text if upgrade != null else "no button"])
	_check(lock != null and lock.text == "Lock"
			and UITheme.price_of(lock) == BigNumber.format(TownPrices.lock_price(piece)),
			"and so does the lock (%s)" % [lock.text if lock != null else "no button"])
	_check(upgrade != null and upgrade.disabled and lock != null and lock.disabled,
			"an empty purse kills both")
	page._on_upgrade_pressed()
	page._on_lock_pressed()
	_check(piece.level == 1 and piece.locked_mod().is_empty() and inventory.gold == 0,
			"and nothing was done on the way past the button")
	_check(page._swing.clock < 0.0, "and the smith did not strike for it")

	# With the gold, the hammer lands: the piece moves, the purse pays and the save is written.
	inventory.gold = price * 3
	page._smith_rng = _stream_that(false)
	page._fill()
	upgrade = _button(page._rows, "Upgrade")
	_check(upgrade != null and not upgrade.disabled, "with the gold the hammer is live")
	page._on_upgrade_pressed()
	_check(piece.level == 2, "the piece came back a level higher (%d)" % piece.level)
	_check(page._swing.clock == 0.0 and page._swing.owed == 0, "and the smith strikes")
	_check(inventory.gold == price * 2, "the purse paid (%d, want %d)" % [inventory.gold, price * 2])
	_check(Inventory.load_from(TEST_PATH).items[0].level == 2, "and the upgrade was saved")

	# A break spends the gold all the same, says so on the page, and greys everything after it. The
	# purse is filled again first: a level up is a dearer hammer, which is the point of the curve.
	var broke_price := TownPrices.upgrade_price(piece)
	_check(broke_price > price, "the next level costs more (%d over %d)" % [broke_price, price])
	inventory.gold = broke_price * 2
	var before_break := inventory.gold
	page._smith_rng = _stream_that(true)
	page._on_upgrade_pressed()
	_check(piece.broken and piece.level == 2, "the hammer broke it and left the level alone")
	# Pressed mid-strike: owed, and begun SmithSwing.OVERLAP frames before the first would have ended.
	_check(page._swing.owed == 1, "a press mid-strike waits its turn")
	page._process((page._swing.frames() - SmithSwing.OVERLAP) * DialogueBox.FRAME_TIME + 0.001)
	_check(page._swing.owed == 0 and page._swing.clock == 0.0,
			"and starts %d frames before the first ends" % SmithSwing.OVERLAP)
	_check(inventory.gold == before_break - broke_price,
			"and the gold went anyway (%d, want %d)" % [inventory.gold, before_break - broke_price])
	_check(not page._smith_note.is_empty(), "the page says what happened (%s)" % page._smith_note)
	_check(_button(page._rows, "Upgrade").disabled and _button(page._rows, "Lock").disabled,
			"and both of the smith's buttons are dead")
	_check(Inventory.load_from(TEST_PATH).items[0].broken, "the break was saved")

	# Carried or worn is all one to him: a piece is locked without being stripped off first -- one
	# modifier pinned, and a second lock refused.
	var worn := Item.rolled("Leather Helmet", ItemRarity.Rarity.RARE, rng, 2)
	inventory.add(worn)
	inventory.equip(worn, Equipment.Socket.HELMET)
	inventory.gold = TownPrices.lock_price(worn) * 2
	page.bag_changed(worn)
	_check(page._smith_note.is_empty(), "a new piece clears what the hammer did to the last one")
	lock = _button(page._rows, "Lock")
	_check(lock != null and not lock.disabled, "a worn piece is his to work on")
	var lock_price := TownPrices.lock_price(worn)
	var purse := inventory.gold
	page._on_lock_pressed()
	_check(not worn.locked_mod().is_empty(), "a modifier is pinned")
	_check(inventory.gold == purse - lock_price, "the purse paid the lock (%d, want %d)"
			% [inventory.gold, purse - lock_price])
	_check(_deep_button(page._rows, "Lock").disabled, "and the button is dead for a second one")
	var saved: Item = Inventory.load_from(TEST_PATH).equipment.item_at(Equipment.Socket.HELMET)
	_check(saved != null and not saved.locked_mod().is_empty(),
			"the lock was saved with the worn piece")
	# And the hammer reaches one on the doll too.
	inventory.gold = TownPrices.upgrade_price(worn) * 2
	page._smith_rng = _stream_that(false)
	page._fill()
	page._on_upgrade_pressed()
	_check(worn.level == 3, "a worn piece came back a level higher (%d)" % worn.level)
	page.queue_free()
	await process_frame
	return true


## The board on the page: the tab a town opens on, reading it being what takes the work on, and the
## Claim that pays for it -- once, and only for a posting that is finished.
func _test_board() -> bool:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var page := TownPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame
	page._stock_rng.seed = WORLD_SEED
	var spot := Vector2i(130, 128)
	# Posted by hand, because a page with no map behind it knows no land to post from -- which is the
	# rule itself: a board only ever wants monsters that live somewhere the player can walk to.
	BountyBoard.restock(inventory.towns.visit(spot), PackedStringArray(["grass"]), TOWN_CELL, rng)
	# The elite posting is taken on before walking in: accepted work is what a restock keeps, and this
	# page has no land to post anything else from.
	var bounty: Dictionary = BountyBoard.bounties(inventory.towns.visit(spot))[2]
	_check(BountyBoard.accept(inventory.towns, bounty), "the elite posting is accepted")
	page.open("Testholm", TownServices.services_for(TownWorld.Tier.SMALL, spot, WORLD_SEED),
			TOWN_CELL, spot, TownWorld.Tier.SMALL)
	_check(page.open_tab() == TownServices.BOUNTIES,
			"a town opens on its board (%s)" % page.open_tab())
	var drawer := inventory.towns.visit(spot)
	_check(BountyBoard.seen(drawer), "the board has been read")
	_check(BountyBoard.seen(Inventory.load_from(TEST_PATH).towns.visit(spot)),
			"and that is written down the moment it is drawn")
	_check(BountyBoard.active(inventory.towns) == bounty, "walking in did not wipe the work taken on")
	_check(_deep_button(page._rows, "Claim") == null, "nothing on it can be handed in yet")
	_check(_deep_button(page._rows, "Show") == null, "and the board carries no Show")
	# The heading's row: a round pip a posting but the last, and the gift, dark until a reward waits.
	var row := _deep_pips(page._rows)
	_check(row != null and row._pips.size() == 3 and row._pips[-1].texture == KillPips.GIFT[1]
			and row._pips[0].texture == KillPips.texture(EnemyRoster.Tier.COMMON, true),
			"the heading ends in a dark gift after two dark pips")
	drawer[BountyBoard.CHOICE] = [{BountyBoard.CHOICE_GOLD: 10.0}]
	page.redraw()
	row = _deep_pips(page._rows)
	_check(row != null and row._pips[-1].texture == KillPips.GIFT[0], "and the gift lights while a reward waits")
	drawer.erase(BountyBoard.CHOICE)
	page.redraw()

	# Worked off, and handed in: the purse, the orb, the piece and the save all move once.
	var reward := int(bounty[BountyBoard.GOLD])
	var orbs := BountyBoard.orbs_of(bounty)
	var xp_reward := int(bounty[BountyBoard.XP])
	var levelled := PlayerLevel.add(inventory.level, inventory.xp, xp_reward)
	_check(orbs.size() == int(BountyBoard.ORBS[EnemyRoster.Tier.ELITE]) and xp_reward > 0,
			"the elite posting carries its orbs and experience (%s, %d)" % [orbs, xp_reward])
	bounty[BountyBoard.ITEM] = {"kind": "sword", "rarity": "elite", "plus": 1}
	BountyBoard.count_kill(inventory.towns, str(bounty[BountyBoard.ENEMY]),
			int(bounty[BountyBoard.NEED]))
	# A promised piece needs room: over a full bag the Claim is grey and a press pays nothing.
	while not inventory.is_full():
		inventory.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng))
	page._fill()
	var claim := _deep_button(page._rows, "Claim")
	_check(claim != null and claim.disabled and claim.tooltip_text == "The bag is full",
			"a promised piece cannot be claimed into a full bag (%s)" % [claim.tooltip_text if claim else "no button"])
	page._on_claim_pressed(bounty)
	_check(inventory.gold == 0 and not bool(bounty[BountyBoard.DONE]), "and a press pays nothing")
	inventory.items.clear()
	page._fill()
	claim = _deep_button(page._rows, "Claim")
	_check(claim != null and not claim.disabled and claim.tooltip_text.contains(BigNumber.format(reward))
			and claim.tooltip_text.ends_with("and an epic sword +1"),
			"the finished one carries its reward (%s)" % [claim.tooltip_text if claim != null else "no button"])
	if claim != null:
		claim.pressed.emit()
	_check(inventory.gold == reward and reward > 0,
			"the purse holds the reward (%d, want %d)" % [inventory.gold, reward])
	var orbs_paid := orbs.all(func(orb: String) -> bool: return inventory.orb_count(orb) == orbs.count(orb))
	_check(orbs_paid, "and the orbs came with it")
	_check(inventory.level == int(levelled["level"]) and inventory.xp == int(levelled["xp"]),
			"and the experience (%d)" % xp_reward)
	_check(inventory.items.size() == 1 and inventory.items[0].rarity == ItemRarity.Rarity.ELITE
			and inventory.items[0].plus == 1 and str(LootTable.ITEMS[inventory.items[0].type]["kind"]) == "sword",
			"and so did the elite sword +1 (%s)"
			% [inventory.items[0].display_name() if inventory.items.size() == 1 else inventory.items.size()])
	_check(Inventory.load_from(TEST_PATH).items.size() == 1, "which was saved with the hand-in")
	_check(Inventory.load_from(TEST_PATH).gold == reward, "the hand-in was saved")
	_check(_deep_button(page._rows, "Claim") == null, "the posting is off the board")
	page._on_claim_pressed(bounty)
	_check(inventory.gold == reward and orbs.all(func(orb: String) -> bool:
			return inventory.orb_count(orb) == orbs.count(orb)), "and pays nothing a second time")
	page.queue_free()
	await process_frame
	return true


## The whole thing in the scene: standing on a town, going in, and coming back out.
func _test_entering() -> bool:
	# From nothing: the suites before this one have been writing to the same scratch save, and this one
	# is about what a player who has never stood in a town finds.
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	# Any button made after the scene clicks; one held down on its own clicks as a toggle, a tab as a button.
	var tick := Button.new()
	tick.toggle_mode = true
	main.add_child(tick)
	tick.pressed.emit()
	_check(main.sounds.toggle.playing and not main.sounds.button.playing, "a toggle clicks as a toggle")
	var tab := Button.new()
	tab.toggle_mode = true
	tab.button_group = ButtonGroup.new()
	main.add_child(tab)
	tab.pressed.emit()
	_check(main.sounds.button.playing, "a tab clicks as a button")
	tick.queue_free()
	tab.queue_free()
	main.inventory.gold += 10.0
	_check(not main.sounds.coins.playing, "gold coming in is no purchase")
	main.inventory.gold -= 10.0
	_check(main.sounds.coins.playing, "gold going out is one")
	main.sounds.coins.stop()
	main.inventory.sell_for(10.0)
	_check(main.sounds.coins.playing, "and so is a sale")

	var town: Vector2i = main.view.start_town - main.view.origin
	_check(main.view.town_tier(town) == TownWorld.Tier.SMALL, "the start town is a village")
	_check(main.view.town_tier(MapBuilder.CENTER) == -1, "and the middle of the map is not a town")
	_check(not main._bounty_button.visible, "no journal in the corner before a board has been read")

	_check(main.view.envs_within(MapBuilder.CENTER, BountyBoard.BOUNTY_RANGE).size() > 0,
			"there is land around the middle of the map to post monsters from")

	main.view.reveal_all()
	main.map.select_cell(town)
	_check(not main.view.can_visit(town), "a town the player is not standing on cannot be entered")
	_check(main.tile_panel.town_button.visible, "but its button is there, to walk in by")

	# Stood on, which with charted is the whole of what a visit takes.
	main.view.player_cell = town
	main.map.set_player_cell(town)
	main.map.select_cell(town)
	main.tile_panel.update_buttons()
	_check(main.view.can_visit(town), "standing on a charted town, it can be entered")
	_check(main.tile_panel.town_button.visible, "and the button is there")
	# A heading, then a row per counter: its mark and its name.
	var rows: Array[Node] = main.tile_panel.service_rows.get_children().slice(1)
	_check(rows.size() > 0, "the tile panel shows a row for what is traded here")
	for row: Node in rows:
		_check(row.get_child(0) is TextureRect and (row.get_child(1) as Label).text != "",
				"and each row names its counter beside its mark")
	_check(main.tile_panel.level_label.text.begins_with(TilePanel.SETTLEMENT_KINDS[main.view.town_tier(town)] + " · "),
			"and the line under the name says what kind of place it is (%s)" % main.tile_panel.level_label.text)

	# Standing on a charted settlement is what the first tip about towns waits for, and reading its
	# board is what the second one waits for.
	_check(main._tip_due("first_town"), "standing on a charted town, the tip about towns is due")
	_check(not main._tip_due("first_accept"), "and the smith's about taking work on is not")

	main._on_town_pressed()
	await process_frame
	_check(not main._tip_due("first_accept"), "nor once the board is read, with nothing taken on")
	_check("first_town" in main.inventory.tips, "the one about towns is marked seen once shown")
	_check(Inventory.load_from(TEST_PATH).tips.has("first_town"), "and written down")
	while main._tip_panel != null:
		main._on_tip_closed()
	await process_frame
	_check(main.town_page.visible, "the town page is up")
	_check(not main.tile_panel.panel.visible, "in the tile panel's place")
	_check(main.bag_page.visible, "with the bag beside it")
	_check(main.inventory.towns.visited(main.view.origin + town), "and the town is in the save")
	var services := TownServices.services_for(TownWorld.Tier.SMALL, main.view.origin + town,
			main.towns.seed_value)
	var vendor := TownServices.GEAR if TownServices.GEAR in services else TownServices.ORBS
	_check(main.town_page.open_tab() == TownServices.BOUNTIES,
			"a town opens on its board, the counter every settlement has (%s)" % [services])
	# The bag sells to the town's merchant from any tab: at the board beside him, the mark that sells a
	# level must not throw it away for nothing. A town with no merchant buys nothing there.
	_check(main.bag_page._buys(TownServices.GEAR) == (TownServices.GEAR in services)
			and not main.bag_page._buys(TownServices.ORBS), "over which the bag sells only to a merchant the town has")
	_check(BountyBoard.bounties(main.inventory.towns.visit(main.view.origin + town)).size()
			== BountyBoard.COMMONS + BountyBoard.ELITES, "and the board has its three postings")
	main.town_page._on_tab_pressed(vendor)
	_check(main.bag_page._buys(vendor), "at the village's one vendor the bag is standing at the counter")
	_check(main.bag_page._worn_panel.visible, "and the doll stands beside it")
	# The map is still clickable behind the page, and the tile panel shares that edge with it.
	main.map.select_cell(MapBuilder.CENTER)
	_check(not main.tile_panel.panel.visible, "clicking the map does not put the tile panel over the town")
	_check(main.town_page.visible, "which is still up")
	main.map.select_cell(town)

	# Every page goes when a fight opens, this one with them.
	var env: String = main.map.get_tile_info(town).get("env", "")
	main._open_fight(Encounter.for_tile(town, env, main.view.area_variant(town)), town, false)
	await process_frame
	_check(not main.town_page.visible and not main.bag_page.visible, "a fight puts every page away")
	main._combat.fight.give_up()
	main._combat._on_back_pressed()
	await process_frame

	# And back in, then out by the X, which puts the tile panel back.
	main.map.select_cell(town)
	main.tile_panel.update_buttons()
	main._on_town_pressed()
	await process_frame
	main.town_page.closed.emit()
	await process_frame
	_check(not main.town_page.visible and not main.bag_page.visible, "the X closes both")
	_check(main.tile_panel.panel.visible, "and the tile panel has its edge back")
	_check(not main.bag_page._buys(TownServices.GEAR) and not main.bag_page._buys(TownServices.ORBS),
			"the bag is not a shop any more")

	# Enter town from afar: the player walks there, and the town opens as they arrive.
	main.view.player_cell = MapBuilder.CENTER
	main.map.set_player_cell(MapBuilder.CENTER)
	main.map.select_cell(town)
	main._on_town_pressed()
	_check(main.view.walking and not main.town_page.visible, "Enter town on a town away from the player walks there first")
	main.map.select_cell(MapBuilder.CENTER)
	main.map.player.finish_walk()
	_check(main.view.player_cell == town and main.town_page.visible and main._town_cell == town,
			"and the town opens on arrival, whatever was clicked on the way")
	main.town_page.closed.emit()
	await process_frame
	main.map.select_cell(town)
	main.tile_panel.update_buttons()

	# The journal: a corner button of its own once a board has been read, listing the same postings
	# away from the town, with the lands the monster lives on.
	_check(main._bounty_button.visible, "the journal is in the corner once a board has been read")
	# Accepting is pressing the board's own button, and it shuts the rest until that one is handed in.
	main._on_town_pressed()
	main.town_page._on_tab_pressed(TownServices.BOUNTIES)
	await process_frame
	var board_lands: Node = main.town_page._rows.find_child(BountyList.LANDS_NAME, true, false)
	_check(board_lands != null and board_lands.is_visible_in_tree() and board_lands.get_child_count() > 0,
			"the board's cards show where the monster lives, with no button to press first")
	_check(_deep_button(main.town_page._rows, "Info") == null, "and have no Info")
	# The longest common name at a tier III board's count, with a two-figure level badge beside it.
	var widest := BountyList.row({BountyBoard.ENEMY: "Skeleton Warrior", BountyBoard.NEED: 12,
			BountyBoard.LEVEL: 99}, main.view, TownPage.BODY_WIDTH)
	main.town_page._rows.add_child(widest)
	await process_frame
	var name_width: float = widest.find_child(BountyList.LEVEL_NAME, true, false).get_parent() \
			.get_child(0).get_combined_minimum_size().x + BountyList.CARD_PAD * 2
	_check(widest.get_combined_minimum_size().x <= maxf(TownPage.BODY_WIDTH, name_width),
			"a level badge goes under a long name rather than widening the card (%.0f)"
			% widest.get_combined_minimum_size().x)
	widest.queue_free()
	var accept :=_deep_button(main.town_page._rows, "Accept")
	_check(accept != null and not accept.disabled, "a posting on the board can be accepted")
	if accept != null:
		accept.pressed.emit()
	await process_frame
	_check(not BountyBoard.active(main.inventory.towns).is_empty(), "which takes it on")
	_check(not BountyBoard.active(Inventory.load_from(TEST_PATH).towns).is_empty(), "and is saved")
	_check(main._tip_panel is DialogueBox and "first_accept" in main.inventory.tips
			and Inventory.load_from(TEST_PATH).tips.has("first_accept"),
			"and the first one taken on has the smith speak of the board's reward, once and saved")
	while main._tip_panel != null:
		main._on_tip_closed()
	var others: Array = main.town_page._rows.find_children("", "Button", true, false).filter(
			func(b: Button) -> bool: return b.text == "Accept")
	_check(not others.is_empty() and others.all(func(b: Button) -> bool: return b.disabled),
			"and the others stay on the board, refused until it is handed in")
	main.town_page.closed.emit()
	await process_frame
	main._on_bounty_pressed()
	await process_frame
	_check(main.bounty_page.visible, "and it opens the bounty page")
	# Which lands it lives on, for nothing -- and never which tile: finding one is the map's business.
	var accepted: String = BountyBoard.active(main.inventory.towns)[BountyBoard.ENEMY]
	var lands: Node = main.bounty_page.find_child(BountyList.LANDS_NAME, true, false)
	_check(lands != null and lands.visible and lands.is_visible_in_tree()
			and lands.get_child_count() == EnemyRoster.environments_of(accepted).size(),
			"the journal shows a swatch for every land the monster lives on")
	if lands != null and lands.get_child_count() > 0:
		var first_land: String = EnemyRoster.environments_of(accepted)[0]
		_check((lands.get_child(0) as Control).tooltip_text == HexTileset.env_name(first_land),
				"and each swatch names its land on hover")
	_check(not _said(main.bounty_page).contains("Nearest"), "and names no tile")
	_check(_deep_button(main.bounty_page, "Show") == null, "nor has a Show to take the map to one")
	var out: Dictionary = BountyBoard.active(main.inventory.towns)
	var chip: Node = main.bounty_page.find_child(BountyList.LEVEL_NAME, true, false)
	_check(chip != null and _said(chip).strip_edges() == "Lv %d" % int(out[BountyBoard.LEVEL])
			and not _said(main.bounty_page).contains("On level"),
			"the level a kill must fall on is a badge by the name, not a sentence")
	_check(_deep_button(main.bounty_page, "Claim at") == null, "an unfinished bounty has nothing to claim")
	# Finished: the journal's button names the town and shows it on the map, and no sentence says so.
	out[BountyBoard.HAVE] = out[BountyBoard.NEED]
	main.bounty_page.open()
	var claim_at := _deep_button(main.bounty_page, "Claim at")
	_check(claim_at != null and claim_at.text == "Claim at " + main.view.name_of(town)
			and not _said(main.bounty_page).contains("Finished"),
			"a finished one has a Claim at its town, and says no more (%s)" % _said(main.bounty_page))
	if claim_at != null:
		claim_at.pressed.emit()
	await process_frame
	_check(main.map.selected_cell == town and main.tile_panel.panel.visible and not main.bounty_page.visible,
			"which puts the page away and the town's tile panel up")
	out[BountyBoard.HAVE] = 0
	main._on_left_page_closed()
	main.inventory.gold = 1.0e9
	main.map.select_cell(town)
	main._on_town_pressed()
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	await process_frame
	# Her tab opened for the first time, she explains herself, a page a click -- after any tip the
	# fights on the way here earned, which come first.
	var hers: Array = []
	for tip: Array in main.TIPS:
		if tip[0] == "first_fortune":
			hers = tip[2]
	while main._tip_panel != null and not (main._tip_panel is DialogueBox and main._tip_panel._pages == hers):
		main._on_tip_closed()
	_check(main._tip_panel is DialogueBox and "first_fortune" in main.inventory.tips,
			"the first time her tab opens, the fortuneteller speaks")
	var box := main._tip_panel as DialogueBox
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_check(box.typing() and box._words.visible_characters < box._words.text.length(),
			"her words come in a letter at a time")
	box._gui_input(click)
	_check(not box.typing() and box._words.visible_characters == -1 and box._page == 0,
			"a click finishes the page without turning it")
	box._gui_input(click)
	_check(box._page == 1 and box.typing(), "and the next click turns it")
	var pages: int = box._pages.size()
	while box._page < pages - 1 or box.typing():
		box._gui_input(click)
	_check(main._tip_panel == box and box._words.text == box._pages[pages - 1],
			"she is still there on the last page")
	box._gui_input(click)
	_check(main._tip_panel == null, "and the click after it lets her go")
	main.town_page._on_tab_pressed(TownServices.BOUNTIES)
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	_check(main._tip_panel == null, "and she says it only once")
	main.queue_free()
	await process_frame
	return true


## The fortuneteller's rules, with no interface: the odds, the prices and the patch a scour takes.
func _test_fortune() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 5)
	var odds := FortuneTeller.odds(sword)
	var pool := ModifierTable.pool_for("Wooden Sword")
	var share := 0.0
	for row in odds:
		share += float(row["share"])
		_check(str(row["id"]) in pool, "%s is something a sword can roll" % row["id"])
		_check(not str(row["line"]).is_empty(), "and is written out")
	_check(odds.size() == pool.size() and absf(share - 100.0) < 0.001,
			"the odds are the whole pool and add up to a hundred (%f)" % share)
	_check(odds[0]["weight"] >= odds[-1]["weight"], "commonest first")
	var band: Array = ModifierTable.band_for("increased_damage", 1)
	var written := ModifierTable.line({"id": "increased_damage", "value": int(band[0])})
	if int(band[1]) != int(band[0]):
		written = written.replace(str(int(band[0])), "%d-%d" % [int(band[0]), int(band[1])])
	_check(ModifierTable.band_line("increased_damage", 1) == written and str(int(band[0])) in written,
			"a band is written the way its modifier is (%s)" % ModifierTable.band_line("increased_damage", 1))
	_check(ModifierTable.line({"id": "added_fight_clock", "value": 30}) == "+3.0s Fight Clock",
			"and a rolled line still reads as it did")
	var relic := Item.rolled_unique(UniqueTable.ids()[0], rng)
	_check(FortuneTeller.odds(relic).is_empty() and FortuneTeller.why_not_appraise(relic) == FortuneTeller.WRITTEN,
			"a unique's lines are its own, so there is nothing to read")
	_check(not FortuneTeller.why_not_appraise(null).is_empty(), "and nothing to read with no piece open")

	# Her list is in two halves and every spell is in exactly one of them -- the lists are written out
	# separately, so this is what holds them together.
	var halves := (FortuneTeller.COMMON + FortuneTeller.GREAT
			+ [FortuneTeller.TRANSCEND, FortuneTeller.BANISH]).duplicate()
	halves.sort()
	var every := FortuneTeller.READINGS.duplicate()
	every.sort()
	_check(halves == every,
			"every spell is a reading, a great spell, the way out or the banishing, and never two (%s)" % [halves])

	# How near the cave feels: a band warmer at each of `WARMTH_STEPS`, coldest past the first of them.
	var reaches: Array = FortuneTeller.WARMTH_STEPS
	_check(FortuneTeller.WARMTH.size() == reaches.size() + 1 and FortuneTeller.warmth(0) == reaches.size(),
			"the cave has a name for every band, and is at its warmest stood on")
	for warmer in reaches.size():
		_check(FortuneTeller.warmth(int(reaches[warmer])) == warmer + 1
				and FortuneTeller.warmth(int(reaches[warmer]) + 1) == warmer,
				"the cave is a band colder one step past %d" % reaches[warmer])

	for reading: String in FortuneTeller.READINGS:
		_check(TownPrices.FORTUNE_BODIES.has(reading) and FortuneTeller.LABELS.has(reading),
				"%s has a price and a name" % reading)
		# The way out and the banishing are priced on the ground behind the first wall, wherever they are asked for.
		if reading in [FortuneTeller.TRANSCEND, FortuneTeller.BANISH]:
			_check(TownPrices.fortune_price(reading, TOWN_CELL) == TownPrices.fortune_price(reading, Vector2i(1, 0)),
					"%s costs the same in every town" % reading)
			_check(TownPrices.fortune_price(reading, TOWN_CELL) == roundf(TownPrices.FORTUNE_BODIES[reading]
					* Encounter.gold_at_steps(MapBuilder.START_LAND_RADIUS + 2)),
					"and is bodies on the second ring of the land behind the first wall")
			continue
		_check(TownPrices.fortune_price(reading, TOWN_CELL) > TownPrices.fortune_price(reading, Vector2i(1, 0)),
				"%s is dearer in a deeper town" % reading)
	_check(TownPrices.fortune_price("retired_reading", TOWN_CELL) == 0.0, "a reading this build lacks costs nothing")

	var patch := FortuneTeller.scour_cells(Vector2i(3, 3))
	var rings := FortuneTeller.SCOUR_RADIUS
	_check(patch.size() == 1 + 3 * rings * (rings + 1) and Vector2i(3, 3) in patch,
			"a scour takes the tile chosen and every ring of its reach (%d tiles)" % patch.size())

	# The banishing: each one paid for doubles the next, a banished unique is out of the drops until it is
	# brought back, what was paid stays paid, and she always leaves some to find.
	var first := TownPrices.fortune_price(FortuneTeller.BANISH, TOWN_CELL)
	var fourfold := pow(TownPrices.FORTUNE_GROWTH, 3)
	_check(absf(TownPrices.fortune_price(FortuneTeller.BANISH, TOWN_CELL, 3) - first * fourfold) <= fourfold,
			"the fourth banishing costs three doublings of the first")
	var told := {}
	var hunted: Array = UniqueTable.ids().slice(0, FortuneTeller.BANISH_LEAVES + 2)
	_check(FortuneTeller.dropping(hunted, told) == hunted and FortuneTeller.banishes(told) == 0,
			"nothing is banished until she is paid")
	FortuneTeller.banish(told, hunted[0])
	_check(FortuneTeller.dropping(hunted, told) == hunted.slice(1),
			"a banished unique is out of the drops and the rest are not")
	_check(not FortuneTeller.why_not_banish(hunted[0], hunted, told).is_empty(), "and is not banished twice")
	FortuneTeller.banish(told, hunted[1])
	_check(not FortuneTeller.why_not_banish(hunted[2], hunted, told).is_empty(),
			"she leaves %d to find" % FortuneTeller.BANISH_LEAVES)
	FortuneTeller.restore(told, hunted[0])
	_check(FortuneTeller.dropping(hunted, told).has(hunted[0]) and FortuneTeller.banishes(told) == 2,
			"one brought back drops again, and what was paid stays paid")
	_check(FortuneTeller.why_not_banish(hunted[2], hunted, told).is_empty(), "which is room for another")

	# What she sold the player is saved with the player, and comes back as it was written.
	var inventory := Inventory.new()
	inventory.fortunes[FortuneTeller.CHEST] = [12, 34]
	FortuneTeller.banish(inventory.fortunes, hunted[0])
	inventory.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(FortuneTeller.chest(back.fortunes) == Vector2i(12, 34),
			"what she sold survives the save (%s)" % [back.fortunes])
	_check(FortuneTeller.banished(back.fortunes) == [hunted[0]] and FortuneTeller.banishes(back.fortunes) == 1,
			"and so does what she banished")
	_check(FortuneTeller.banished(inventory.transcended().fortunes).is_empty(), "which ends with the world")
	_check(FortuneTeller.chest({}) == TownWorld.NO_SPOT, "and a save that bought nothing has nothing")

	# A great spell is one a settlement, which is the drawer's key and not the player's count.
	var drawer := {}
	_check(not FortuneTeller.asked(drawer, FortuneTeller.SCOUR), "a town that has cast nothing is asked nothing")
	drawer[FortuneTeller.ASKED + FortuneTeller.SCOUR] = true
	_check(FortuneTeller.asked(drawer, FortuneTeller.SCOUR)
			and not FortuneTeller.asked(drawer, FortuneTeller.HOMECOMING),
			"and one spent here says nothing about the next")
	return true


## Her table in a town, through the main scene: the roads, the star, a relic, a piece read, and the
## two great spells -- each paid for, written down, the readings dearer every time and the great
## spells refused in the town that has cast one.
func _test_fortune_page() -> bool:
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame
	_check(main._chest_pointer.target == HexMap.NO_CELL, "no star points at a chest for nothing")

	# Into the start village without charting the map, so there is still dark to scour and chests in it.
	var town: Vector2i = main.view.start_town - main.view.origin
	main.view._show(town, MapBuilder.State.CHARTED)
	main.view.player_cell = town
	main.map.set_player_cell(town)
	main.map.select_cell(town)
	main.inventory.gold = 1.0e12
	main._on_town_pressed()
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	await process_frame
	for reading: String in FortuneTeller.READINGS:
		# Her squares on the two grids; the way out is on neither while every wall still stands, nor
		# the banishing while only the starters are unlocked.
		if reading in [FortuneTeller.TRANSCEND, FortuneTeller.BANISH]:
			_check(_spell(main, reading) == null, "%s is not offered yet" % reading)
			continue
		_check(_spell(main, reading) != null, "she offers %s" % reading)
	_check(_dead(main, FortuneTeller.APPRAISE), "no piece is open to read")
	# The dev's switch offers the banishing at once, in a debug build only; put back after.
	Settings.banish_now = true
	main.town_page.redraw()
	await process_frame
	_check((_spell(main, FortuneTeller.BANISH) != null) == OS.is_debug_build(),
			"under the dev's switch the banishing is offered from the start")
	Settings.banish_now = false
	main.town_page.redraw()
	await process_frame

	# The roads: three sentences, and not sold in this town again.
	var purse: float = main.inventory.gold
	_ask(main, FortuneTeller.ROADS)
	await process_frame
	_check(main.inventory.gold < purse, "the roads are paid for")
	_check(main.town_page._told != null and _said(main.town_page._told).contains("on your map"),
			"and told in a popup (%s)" % (_said(main.town_page._told) if main.town_page._told != null else "none"))
	_check(_deep_button(main.town_page._told, "Dismiss") != null, "with its Dismiss in reach")
	# Dismissed with its tick: that reading's answer is one line on the page from then on.
	main.town_page._told.find_child(BagPage.TICK_NAME, true, false).button_pressed = true
	_deep_button(main.town_page._told, "Dismiss").pressed.emit()
	await process_frame
	_check(main.town_page._told == null, "a Dismiss puts it away")
	_check(TownPage.SKIP_TOLD + FortuneTeller.ROADS in Inventory.load_from(TEST_PATH).tips, "and saved")
	_check(_dead(main, FortuneTeller.ROADS) and _said(_spell(main, FortuneTeller.ROADS).get_parent())
			.contains("Bought"), "the roads, bought here, are greyed with Bought where the price was")

	# The star.
	var chest: Vector2i = main.view.nearest_chest(true)
	_check(chest != HexMap.NO_CELL and not main.view.seen(chest),
			"there is a chest out there on this seed that the player has not seen")
	_ask(main, FortuneTeller.TREASURE)
	await process_frame
	_check(main._chest_pointer.target == chest, "the star is put over the nearest chest")
	# And up from that moment, whatever is open over it: it stood down for the tile panel, which is up
	# whenever a tile is selected, and a star bought that way was never seen short of a restart.
	_check(main._chest_pointer.visible, "and it is up at once, under the open town")
	_check(FortuneTeller.chest(Inventory.load_from(TEST_PATH).fortunes) == main.view.origin + chest, "and saved")
	_check(_dead(main, FortuneTeller.TREASURE), "and not sold again while it is out")
	# Dismissed with its tick: that reading's answer is one line on the page from then on.
	main.town_page._told.find_child(BagPage.TICK_NAME, true, false).button_pressed = true
	_deep_button(main.town_page._told, "Dismiss").pressed.emit()
	await process_frame
	main.view._states[chest] = MapBuilder.State.CHARTED
	main._sync_chest()
	_check(main._chest_pointer.target == HexMap.NO_CELL and FortuneTeller.chest(main.inventory.fortunes)
			== TownWorld.NO_SPOT, "an opened chest takes its star with it")
	main.town_page.redraw()
	await process_frame
	_check(not _dead(main, FortuneTeller.TREASURE), "and the star can be bought again")
	_check(_price(main, FortuneTeller.TREASURE) == TownPrices.fortune_price(FortuneTeller.TREASURE, town),
			"for what the first one cost")
	_ask(main, FortuneTeller.TREASURE)
	await process_frame
	_check(main.town_page._told == null and _said(main.town_page._rows).contains("You cast Treasure"),
			"and, not to be shown again, said in one line (%s)" % _said(main.town_page._rows))

	# A piece read: the bag's open piece, as the smith's is.
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, RandomNumberGenerator.new())
	main.inventory.items.append(sword)
	main.town_page.bag_changed(sword)
	await process_frame
	_ask(main, FortuneTeller.APPRAISE)
	await process_frame
	_check(main.town_page._told != null and _said(main.town_page._told).contains("increased Damage"),
			"a sword's odds are read out")
	_check(not main.town_page._told.find_child(BagPage.TICK_NAME, true, false).get_parent().visible,
			"and the appraisal can never be put out of sight")
	main.town_page._close_told()
	main.town_page.bag_changed(null)
	await process_frame
	_check(_dead(main, FortuneTeller.APPRAISE), "and with no piece open there is nothing to read")
	main.town_page.bag_changed(sword)
	await process_frame
	_check(not _dead(main, FortuneTeller.APPRAISE)
			and _price(main, FortuneTeller.APPRAISE) == TownPrices.fortune_price(FortuneTeller.APPRAISE, town),
			"and the same piece is read again, at the same price")
	main.town_page.bag_changed(null)
	await process_frame

	# A world with a cave in it, as the rest of her spells are asked in: put down beside a breach in the first wall by
	# hand, Gollux's own unlock being the third wall's (`WallUnlocks.GOLLUX`).
	main.inventory.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	main.view.place_cave(Vector2i(MapBuilder.START_LAND_RADIUS + 1, 0))
	main._save_map()
	main._credit_walls()
	main.town_page.redraw()
	await process_frame

	# The scour: the town closes, the map is aimed at, Escape costs nothing, a click pays once.
	_ask(main, FortuneTeller.SCOUR)
	await process_frame
	_check(not main.town_page.visible and main.map.aim_radius == FortuneTeller.SCOUR_RADIUS,
			"the scour closes the town and aims at the map")
	purse = main.inventory.gold
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	main._unhandled_input(right)
	_check(main.map.aim_radius == -1 and main.inventory.gold == purse
			and not _spent(main, main.view.start_town, FortuneTeller.SCOUR), "put away by a right click, it costs nothing")
	main._on_spell_aimed(FortuneTeller.SCOUR, TownPrices.fortune_price(FortuneTeller.SCOUR, town),
			main.view.start_town)
	main._on_cell_aimed(Vector2i(9000, 9000))
	_check(main.map.aim_radius != -1 and main.inventory.gold == purse, "land the map has not made is refused")
	var dark := HexMap.NO_CELL
	for cell: Vector2i in main.view._tiles:
		if not main.view.seen(cell) and HexGrid.distance(cell, town) > 4:
			dark = cell
			break
	var charted_before: bool = main.view.charted(town)
	main._on_cell_aimed(dark)
	await process_frame
	_check(main.view.seen(dark) and not main.view.charted(dark), "the chosen land comes out of the dark, uncharted")
	_check(main.inventory.gold < purse and _spent(main, main.view.start_town, FortuneTeller.SCOUR),
			"paid for and spent in the town that sold it")
	_check(main.map.aim_radius == -1, "and the aim is put away")
	_check(main.view.charted(town) == charted_before, "charted land is left as it was")
	var reloaded := MapSave.load_from(TEST_MAP_PATH, [], MapSave.fingerprint(main.map.tileset))
	_check(reloaded != null and reloaded.states.get(dark, -1) == MapBuilder.State.UNCHARTED,
			"the map is written down with it")
	main.map.select_cell(town)
	main._on_town_pressed()
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	await process_frame
	_check(_dead(main, FortuneTeller.SCOUR), "and this town will not cast it twice")

	# Homecoming: one tile aimed at, and it has to be a settlement the player has charted.
	var other := HexMap.NO_CELL
	for cell: Vector2i in main.view._tiles:
		if cell != town and main.view.town_tier(cell) != -1 and main.view.is_land(cell):
			other = cell
			break
	_check(other != HexMap.NO_CELL, "this seed has a second settlement")
	_check(_dead(main, FortuneTeller.HOMECOMING), "with none of them charted there is nowhere to go")
	main.view._show(other, MapBuilder.State.CHARTED)
	main.town_page.redraw()
	await process_frame
	# Under a finger her square is read by the first tap and cast by the next (`Cursors.applies`).
	Cursors.touched = true
	_ask(main, FortuneTeller.HOMECOMING)
	_check(main.town_page.visible and main.map.aim_radius == -1, "a finger's first tap on a spell only reads it")
	Cursors.taps += 1
	_ask(main, FortuneTeller.HOMECOMING)
	Cursors.touched = false
	await process_frame
	_check(not main.town_page.visible and main.map.aim_radius == 0,
			"the road home closes the town and aims at one tile")
	purse = main.inventory.gold
	main._on_cell_aimed(dark)
	_check(main.view.player_cell == town and main.inventory.gold == purse,
			"land that is no charted settlement is refused")
	# And so is the land it is aimed at: the first tap only chooses the tile.
	Cursors.touched = true
	Cursors.taps += 1
	main._on_cell_aimed(other)
	_check(main.view.player_cell == town and main.inventory.gold == purse and main.map.aim_radius == 0,
			"a finger's first tap on the land aimed at casts nothing")
	Cursors.taps += 1
	main._on_cell_aimed(other)
	Cursors.touched = false
	await process_frame
	_check(main.view.player_cell == other and main.map.player.cell == other, "the chosen town is walked to in no time")
	_check(main.inventory.gold < purse and _spent(main, main.view.start_town, FortuneTeller.HOMECOMING),
			"paid for and spent where it was bought")
	_check(main.map.aim_radius == -1, "and the aim is put away")
	main.map.select_cell(other)
	main._on_town_pressed()
	main.town_page._on_tab_pressed(TownServices.FORTUNE)
	await process_frame
	_check(not _dead(main, FortuneTeller.SCOUR), "and a great spell one town has cast is offered by the next")

	# The banishing: on her list once enough uniques are unlocked, a screen of its own in her list's
	# place, where one is picked, paid for at a price that doubles, and brought back for nothing.
	for id: String in UniqueTable.ids():
		if Achievements.unlocked(main.inventory).size() >= FortuneTeller.BANISH_FROM:
			break
		if not id in Achievements.STARTERS:
			main.inventory.achievements[id] = 1
	main.town_page.redraw()
	await process_frame
	_check(_spell(main, FortuneTeller.BANISH) != null and not _dead(main, FortuneTeller.BANISH),
			"she offers the banishing once %d uniques are unlocked" % FortuneTeller.BANISH_FROM)
	_ask(main, FortuneTeller.BANISH)
	await process_frame
	var page: TownPage = main.town_page
	var squares := page._rows.find_children("", "ItemSlot", true, false)
	_check(_spell(main, FortuneTeller.ROADS) == null and squares.size() == FortuneTeller.BANISH_FROM,
			"its screen stands in her list's place, a square an unlocked unique (%d)" % squares.size())
	_check(_deep_button(page._rows, "Banish").disabled, "with nothing picked there is nothing to banish")
	var outcast: String = (squares[0] as ItemSlot).item.unique
	var banish_price := _price(main, FortuneTeller.BANISH)
	page._on_banish_picked(outcast)
	for i in 2:
		await process_frame
	_check(main._item_card.visible and main._item_card._shown.item.unique == outcast,
			"the picked unique's card stands up with the cursor off it")
	_check(UITheme.price_of(_deep_button(page._rows, "Banish")) == BigNumber.format(banish_price)
			and _deep_button(page._rows, "Banish").tooltip_text.is_empty(),
			"and the button says what it costs, and nothing in a tooltip")
	purse = main.inventory.gold
	_deep_button(page._rows, "Banish").pressed.emit()
	await process_frame
	_check(main.inventory.gold == purse - banish_price
			and FortuneTeller.banished(Inventory.load_from(TEST_PATH).fortunes) == [outcast],
			"banished, paid for and saved")
	_check(not FortuneTeller.dropping(Achievements.unlocked(main.inventory), main.inventory.fortunes).has(outcast),
			"and out of the drops")
	_check(page._banishing and _deep_button(page._rows, "Banish").disabled
			and _price(main, FortuneTeller.BANISH) > banish_price,
			"the screen stays for the next one, nothing picked, at a dearer price")
	purse = main.inventory.gold
	page._on_banish_picked(outcast)
	await process_frame
	_check(_deep_button(page._rows, "Banish") == null and _deep_button(page._rows, "Restore").tooltip_text.is_empty(),
			"a banished one picked is not banished again, and Restore wears no tooltip")
	_deep_button(page._rows, "Restore").pressed.emit()
	await process_frame
	_check(main.inventory.gold == purse and FortuneTeller.banished(main.inventory.fortunes).is_empty()
			and _price(main, FortuneTeller.BANISH) > banish_price,
			"brought back for nothing, and what was paid stays paid")
	# At her floor the button is dead and its tooltip says so -- the one thing it ever says.
	var unlocked: Array = Achievements.unlocked(main.inventory)
	main.inventory.fortunes[FortuneTeller.BANISHED] = unlocked.slice(FortuneTeller.BANISH_LEAVES)
	page._on_banish_picked(unlocked[0])
	await process_frame
	_check(_deep_button(page._rows, "Banish").disabled
			and _deep_button(page._rows, "Banish").tooltip_text == "You need at least %d uniques in the drop pool"
			% FortuneTeller.BANISH_LEAVES,
			"at her floor the button says why (%s)" % _deep_button(page._rows, "Banish").tooltip_text)
	main.inventory.fortunes.erase(FortuneTeller.BANISHED)
	page._on_banish_picked(unlocked[0])
	main.inventory.gold = 1.0
	page.redraw()
	await process_frame
	_check(_deep_button(page._rows, "Banish").disabled and _deep_button(page._rows, "Banish").tooltip_text.is_empty(),
			"and a short purse greys it and says nothing")
	main.inventory.gold = purse
	var arrow: Button = page._rows.find_child(TownPage.BANISH_BACK, true, false)
	_check(arrow.tooltip_text.is_empty(), "the arrow back wears no tooltip")
	arrow.pressed.emit()
	await process_frame
	_check(not page._banishing and _spell(main, FortuneTeller.ROADS) != null,
			"and the arrow is the way back to her spells")

	# The way out: on her list once a wall is down, a question first, then the black screen where one
	# piece is kept and the wall's orb is spent, and then everything but the heirlooms and what the
	# player knows is gone, and the map with it.
	main.view.land_radius += MapBuilder.WALL_STEP
	main._credit_walls()
	_check(main.inventory.super_orbs == 1, "a wall down is a super orb to spend")
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var kept := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 5)
	main.inventory.add(kept)
	main.inventory.add(Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng, 5))
	main.inventory.kills = 321
	main.town_page.redraw()
	await process_frame
	_check(_spell(main, FortuneTeller.TRANSCEND) != null and not _dead(main, FortuneTeller.TRANSCEND),
			"she offers the way out once a wall has fallen, as a square among the great spells")
	_check(_deep_button(main.town_page._rows, "Transcend") == null, "and no button of its own")
	_ask(main, FortuneTeller.TRANSCEND)
	await process_frame
	_check(FileAccess.file_exists(TEST_MAP_PATH) and main.inventory.gold > 0.0,
			"the first press only asks")
	var asked: Node = main.town_page._told
	_check(asked != null and "lose" in _said(asked) and not "heirloom" in _said(asked),
			"in a popup that warns of what is lost, not of what is won")
	_check(UITheme.price_of(_deep_button(asked, "Transcend")).is_empty(), "its Transcend a coin and no figure")
	main.town_page._close_told()
	var full_purse: float = main.inventory.gold
	main.inventory.gold = 1.0
	main.town_page.redraw()
	await process_frame
	_check(not _dead(main, FortuneTeller.TRANSCEND), "a short purse does not grey the asking")
	_ask(main, FortuneTeller.TRANSCEND)
	await process_frame
	_check(_deep_button(main.town_page._told, "Transcend").disabled, "only the deed")
	main.town_page._close_told()
	main.inventory.gold = full_purse
	_ask(main, FortuneTeller.TRANSCEND)
	await process_frame
	# Six skulls to spend on the black screen, six depths of the dungeon won (a wall earns none): the
	# budget is read as the screen opens.
	main.inventory.dungeon_depth = 6
	var written := FileAccess.get_file_as_string(TEST_PATH)
	_deep_button(main.town_page._told, "Transcend").pressed.emit()
	await process_frame
	var black: TranscendPage = main._transcend_page
	_check(black != null and not main.town_page.visible and FileAccess.file_exists(TEST_MAP_PATH),
			"the second goes to the black screen, and the world is still there behind it")
	black._show_choice()
	_check(not _deep_button(black, "Create an heirloom").disabled and _deep_button(black, "Upgrade an heirloom").disabled,
			"an heirloom can be made, and with none held there is nothing to upgrade")
	_deep_button(black, "Create an heirloom").pressed.emit()
	_check(not black._swap.visible, "with no heirloom held the crown under the arrow is not there")
	black._create_page._select_item(main.inventory.items.find(kept))
	black._create_page._on_make_pressed()
	_deep_button(black._create_page._confirm, "Keep").pressed.emit()
	await process_frame
	_check(main.inventory.stash().items.has(kept) and black._choice.visible
			and _deep_button(black, "Create an heirloom").disabled, "one piece is kept, and only one")
	# With one held, the make-an-heirloom screen's crown turns to the heirlooms and its chest back.
	black._open(black._create_page, true)
	await process_frame
	_check(black._swap.visible and black._swap.tooltip_text == "Your heirlooms", "the crown stands under the arrow")
	black._swap.pressed.emit()
	await process_frame
	_check(black._upgrade_page.visible and not black._create_page.visible and black._swap.visible
			and black._swap.tooltip_text == "Items", "and turns the page to the heirlooms, the chest to go back")
	black._swap.pressed.emit()
	_check(black._create_page.visible and not black._upgrade_page.visible, "which turns it back to the items")
	black._show_choice()
	_check(not black._swap.visible, "and the choice has neither")
	_deep_button(black, "Upgrade an heirloom").pressed.emit()
	black._upgrade_page._on_orb_pressed(SuperOrbTable.ASCENSION)
	black._upgrade_page._craft(black._upgrade_page._armed, kept)
	_check(kept.plus == 1 and main.inventory.super_orbs == 0, "and the wall's orb goes into it")
	_check(FileAccess.get_file_as_string(TEST_PATH) == written and FileAccess.file_exists(TEST_MAP_PATH),
			"none of which has been written: a game closed here never left")
	black._show_choice()
	await process_frame
	# The curses: a third card, a row each, as many skulls as the budget, and nothing of it written until
	# the way on.
	_deep_button(black, "Take on a curse").pressed.emit()
	await process_frame
	_check(black._curse_face != null and not black._choice.visible and black._back.visible,
			"the third card opens the curses, with the arrow back")
	for id: String in [Curses.THICK_FOG, Curses.NO_REST, Curses.BLOODTHIRST]:
		(black._curse_face.find_child(id, true, false) as Button).toggled.emit(true)
		await process_frame
	var winter := black._curse_face.find_child(Curses.LONG_WINTER, true, false) as Button
	_check(main.inventory.pending_curses.size() == 3 and winter.disabled
			and not (black._curse_face.find_child(Curses.IRON_FOES, true, false) as Button).disabled
			and not (black._curse_face.find_child(Curses.NO_REST, true, false) as Button).disabled
			and "Skulls: 5 of 6" in _said(black._curse_face),
			"five skulls of six taken: a curse of three greys, one of one does not")
	winter.toggled.emit(true)
	await process_frame
	_check(main.inventory.pending_curses.size() == 3, "and a greyed one pressed anyway is refused")
	(black._curse_face.find_child(Curses.BLOODTHIRST, true, false) as Button).toggled.emit(false)
	await process_frame
	(black._curse_face.find_child(Curses.LONG_WINTER, true, false) as Button).toggled.emit(true)
	await process_frame
	_check(main.inventory.pending_curses == [Curses.THICK_FOG, Curses.NO_REST, Curses.LONG_WINTER],
			"one let go makes room again, to the last skull")
	_check(main.inventory.curses.is_empty() and FileAccess.get_file_as_string(TEST_PATH) == written,
			"the world being left is under none of them, and nothing is written")
	black._show_choice()
	await process_frame
	_check("Thick Fog" in _said(black._choice) and "Long Winter" in _said(black._choice), "the card says what was taken")
	_deep_button(black, "Enter the new world").pressed.emit()
	await process_frame
	_check(not FileAccess.file_exists(TEST_MAP_PATH), "the way on leaves the world: the map is gone")
	var after := Inventory.load_from(TEST_PATH)
	_check(after.gold == 0.0 and after.level == 1
			and after.items.all(func(item: Item) -> bool: return item.type == LootTable.BROKEN_TORCH),
			"the purse, the bag and the levels stay behind")
	_check(after.stash().total() == 1 and after.stash().items[0].level == 1
			and after.stash().items[0].safe_level == 5 and after.stash().items[0].plus == 1,
			"the heirloom goes along, +1, at level 1 and remembering 5")
	_check(after.kills == 321 and after.first_sword_taken and "first_town" in after.tips,
			"and so does what the player knows, so no helping hand is dealt twice")
	_check(after.walls_credited == 0, "the new world's walls have paid nothing yet")
	_check(after.curses == [Curses.NO_REST, Curses.THICK_FOG, Curses.LONG_WINTER],
			"the new world is under what was chosen (%s)" % [after.curses])
	_check(after.total() == 1 and after.items[0].type == LootTable.BROKEN_TORCH, "and the fog's torch is in its bag")
	# The scene would have been loaded again; here it is only told it may not write the old world back.
	main.queue_free()
	await process_frame
	return true


## Three curses the main scene has a hand in: the Ring of Walls moves where the next wall stands,
## the Homeland's lands are chosen as the world's map first exists, and under No Second Chances a
## lost tile is a lost world -- the black screen, with no heirloom to be made on it.
func _test_curses_the_world_feels() -> bool:
	_clear_scratch()
	var cursed := Inventory.new()
	cursed.curses = [Curses.RING_OF_WALLS, Curses.HOMELAND, Curses.NO_SECOND_CHANCES]
	cursed.first_sword_taken = true
	cursed.items.append(Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, RandomNumberGenerator.new(), 3))
	cursed.save(TEST_PATH)
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	_check(main.view.wall_step == MapBuilder.RING_OF_WALLS_STEP, "the Ring of Walls is told to the map")
	var home: Array = main.inventory.homeland
	_check(home.size() == 2 and home[0] == main.view.env_at(MapBuilder.CENTER) and home[0] != home[1],
			"the Homeland is the land the start stands on and one other %s" % [home])
	_check(Inventory.load_from(TEST_PATH).homeland == main.inventory.homeland, "and is saved as it is chosen")
	main._settle_homeland()
	_check(main.inventory.homeland == home, "asked again, it stays what it was")

	# A wall down opens five rings, not ten, and is counted as one wall.
	var radius: int = main.view.land_radius
	main.view._break_wall()
	_check(main.view.land_radius == radius + MapBuilder.RING_OF_WALLS_STEP and main.view.walls_fallen() == 1,
			"a fallen wall opens five rings (%d)" % main.view.land_radius)
	_check(Encounter.walls_inside(Vector2i(radius + 2, 0)) == 1, "and the land past it is as hard as it ever was")

	# The lost fight: banked, and then the black screen with nothing to keep.
	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	main.map.select_cell(target)
	main._on_chart_pressed()
	main.map.player.finish_walk()
	main._combat.fight.give_up()
	main._combat.retry.emit()
	await process_frame
	_check(main._combat == null and main._transcend_page != null, "a lost tile ends the world, Retry or no")
	var black: TranscendPage = main._transcend_page
	black._show_choice()
	_check(_deep_button(black, "Create an heirloom").disabled and "lost" in _said(black).to_lower(),
			"and a world lost that way makes no heirloom")
	black.finish()
	await process_frame
	var after := Inventory.load_from(TEST_PATH)
	_check(after.curses.is_empty() and after.stash().total() == 0 and after.total() == 0,
			"the next world begins under nothing, with nothing")
	main.queue_free()
	await process_frame
	_clear_scratch()
	return true


## The black screen's skill tree (the user's, 2026-10-08): its card counts the bag's stones, the page shows
## them alone, a stone opened lights the slots it fits, a press on one places it -- the stone it pushes
## out back in the bag -- and an orb in the hand goes into a placed stone.
func _test_tree_builder() -> bool:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var found := Item.rolled("Strength Node", ItemRarity.Rarity.UNCOMMON, rng, 3, 2, 2)
	inventory.add(found)
	inventory.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng))
	inventory.add_orb("Orb of Exaltation")
	# A stone already standing in the root's one slot, for the new one to push out.
	var old := Item.new()
	old.type = "Dexterity Node"
	old.stone_tier = 1
	old.stats = Item.scaled_stats(old.type, 1)
	inventory.skills.stones["0"] = old
	var black := TranscendPage.new(inventory, 1.0)
	root.add_child(black)
	await process_frame
	black._show_choice()
	_check("1 to place" in _said(black), "the card counts the bag's one stone")
	_deep_button(black, "Skill tree").pressed.emit()
	await process_frame
	var page: BagPage = black._stones_page
	var squares := func() -> Array:
		return page._sections.find_children("*", "", true, false).filter(
				func(node: Node) -> bool: return node is ItemSlot and (node as ItemSlot).item != null)
	_check(page.visible and squares.call().size() == 1 and squares.call()[0].item == found,
			"the page shows the stone and not the sword")
	var view := func() -> SkillTreeView:
		return page._worn_body.find_children("*", "", true, false).filter(
				func(node: Node) -> bool: return node is SkillTreeView)[0]
	page._select_item(inventory.items.find(found))
	var lit: Array = view.call().squares.keys().filter(func(path: String) -> bool:
		return not path.is_empty() and view.call().squares[path].modulate == Color.WHITE)
	lit.sort()
	_check(lit == ["0"], "a tier-2 stone lights the root's one slot (%s)" % [lit])
	_check(view.call()._rings == ["0"], "and rings it")
	view.call().slot_pressed.emit("0")
	_check(inventory.skills.stones["0"] == found and inventory.items.has(old) and not inventory.items.has(found),
			"pressed, it stands there and the stone it took the place of is back in the bag")
	_check(view.call().squares.has("0.0") and view.call().squares.has("0.1"), "with its two slots under it")
	_check(view.call()._marks.get_child_count() == 0, "with nothing in the hand no slot says its tier")
	page._select_item(inventory.items.find(old))
	var numerals: Array = view.call()._marks.get_children().map(func(holder: Control) -> String:
		return (holder.get_child(0) as Label).text)
	_check(numerals == ["II", "II"] and view.call()._rings == ["0"],
			"a tier-1 stone in the hand rings the one slot it fits, the two too deep for it saying II (%s)" % [numerals])
	page._on_orb_pressed("Orb of Exaltation")
	view.call().slot_pressed.emit("0")
	_check(found.rarity == ItemRarity.Rarity.ELITE and inventory.orb_count("Orb of Exaltation") == 0,
			"an orb in the hand goes into the stone placed there")
	black.queue_free()
	await process_frame
	return true
