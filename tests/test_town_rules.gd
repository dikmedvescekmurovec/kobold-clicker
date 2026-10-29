extends "res://tests/town_base.gd"
## Headless checks for the towns: which counters a settlement has, what a thing is worth over one, the
## selling the bag does while it stands at one, and the drawer all of it is saved in. Run from the
## project folder:
##   python tests/run_all.py town_rules


func _run() -> void:
	_check(_test_services() == true, "service tests ran to the end")
	_check(_test_prices() == true, "price tests ran to the end")
	_check(_test_state() == true, "town state tests ran to the end")
	_check(_test_save() == true, "save tests ran to the end")
	_check(_test_stock() == true, "stock tests ran to the end")
	_check(_test_stock_rolls() == true, "stock roll tests ran to the end")
	_check(_test_smith() == true, "blacksmith tests ran to the end")
	_check(_test_bounties() == true, "bounty board tests ran to the end")
	_check(_test_board_tiers() == true, "board tier tests ran to the end")
	_check(_test_bounty_kills() == true, "bounty kill tests ran to the end")
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	_report("town: rules")


## The tiers: a board and a fortuneteller everywhere, then one of the three trades in a village, two in a
## town and all three in a fortress -- and the same answer every time for the same spot.
func _test_services() -> bool:
	_check(TownServices.services_for(-1, Vector2i.ZERO, WORLD_SEED).is_empty(),
			"a tile with no town offers nothing")
	var drawn := {TownServices.GEAR: 0, TownServices.ORBS: 0, TownServices.SMITH: 0}
	var lacked := {TownServices.GEAR: 0, TownServices.ORBS: 0, TownServices.SMITH: 0}
	for y in SPOTS:
		for x in SPOTS:
			var spot := Vector2i(x, y)
			var village := TownServices.services_for(TownWorld.Tier.SMALL, spot, WORLD_SEED)
			var town := TownServices.services_for(TownWorld.Tier.MEDIUM, spot, WORLD_SEED)
			for place: PackedStringArray in [village, town]:
				_check(TownServices.BOUNTIES in place and TownServices.FORTUNE in place,
						"%s has a board and a fortuneteller (%s)" % [spot, place])
			var village_trades: Array = TownServices.TRADES.filter(func(t: String) -> bool: return t in village)
			var town_trades: Array = TownServices.TRADES.filter(func(t: String) -> bool: return t in town)
			_check(village.size() == 3 and village_trades.size() == 1,
					"%s as a village has one trade (%s)" % [spot, village])
			_check(town.size() == 4 and town_trades.size() == 2,
					"%s as a town has two trades (%s)" % [spot, town])
			for trade: String in village_trades:
				drawn[trade] += 1
			for trade: String in TownServices.TRADES:
				if not trade in town:
					lacked[trade] += 1
			# Seed-stable: nothing is written down, so walking back has to find the same counters.
			_check(village == TownServices.services_for(TownWorld.Tier.SMALL, spot, WORLD_SEED)
					and town == TownServices.services_for(TownWorld.Tier.MEDIUM, spot, WORLD_SEED),
					"%s offers the same counters twice" % spot)
	for trade: String in TownServices.TRADES:
		_check(drawn[trade] > 0 and lacked[trade] > 0,
				"%s turns up as a village's one trade and as a town's missing one (%s, %s)" % [trade, drawn, lacked])

	var fortress := TownServices.services_for(TownWorld.Tier.FORTRESS, Vector2i(3, 4), WORLD_SEED)
	_check(fortress.size() == 5 and TownServices.SMITH in fortress and TownServices.FORTUNE in fortress,
			"a fortress has all five (%s)" % fortress)
	# Listed in one order, so a town reads the same way twice and the page's tabs never shuffle.
	var order := PackedStringArray()
	for service: String in TownServices.ORDER:
		if service in fortress:
			order.append(service)
	_check(order == fortress, "services come back in ORDER (%s)" % [fortress])
	for service: String in TownServices.ORDER:
		_check(not TownServices.label(service).is_empty(), "%s is named" % service)
	_check(TownServices.label("retired_counter").is_empty(), "a counter this build has no name for is unnamed")

	# Another seed is another world, and the villages in it are not all the same errand.
	var moved := 0
	for y in SPOTS:
		for x in SPOTS:
			if TownServices.services_for(TownWorld.Tier.SMALL, Vector2i(x, y), WORLD_SEED) \
					!= TownServices.services_for(TownWorld.Tier.SMALL, Vector2i(x, y), WORLD_SEED + 1):
				moved += 1
	_check(moved > SPOTS * SPOTS * 0.2, "another world deals its villages other vendors (%d of %d)"
			% [moved, SPOTS * SPOTS])
	return true


## Everything is quoted in bodies, so every price has to climb with the level the body stands at, and
## a piece's price with its rarity on top of that.
func _test_prices() -> bool:
	_check(TownPrices.gold_at_level(1) == Encounter.gold_at_steps(0), "level 1 is the middle of the map")
	_check(TownPrices.gold_at_level(4) == Encounter.gold_at_steps(3 * MapBuilder.LEVEL_TILES),
			"level n starts n - 1 bands out")
	_check(Encounter.base_gold(Vector2i.ZERO) == Encounter.gold_at_steps(0),
			"a cell's purse is still the walk's purse")
	_check(Encounter.base_gold(TOWN_CELL) == Encounter.gold_at_steps(HexGrid.distance(
			MapBuilder.CENTER, TOWN_CELL)), "and at a distance too")
	for level in range(1, 12):
		_check(TownPrices.gold_at_level(level + 1) > TownPrices.gold_at_level(level),
				"a body is worth more at level %d than at %d" % [level + 1, level])

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	_check(TownPrices.sell_price(null) == 0, "nothing is worth nothing")
	var last := 0.0
	for rarity: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON,
			ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
		var piece := Item.rolled("Wooden Sword", rarity, rng, 6)
		var price := TownPrices.sell_price(piece)
		_check(price > last, "a %s sells for more than the step under it (%d over %d)"
				% [piece.rarity_name(), price, last])
		last = price
	var low := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 2)
	var high := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 9)
	_check(TownPrices.sell_price(high) > TownPrices.sell_price(low),
			"a deeper piece sells for more (%d over %d)" % [TownPrices.sell_price(high),
			TownPrices.sell_price(low)])
	_check(TownPrices.sell_total([low, high]) == TownPrices.sell_price(low) + TownPrices.sell_price(high),
			"a handful is worth the sum of it")
	_check(TownPrices.sell_total([]) == 0, "an empty handful is worth nothing")

	for orb: String in OrbTable.ORBS:
		var value := TownPrices.orb_value(orb, TOWN_CELL)
		_check(value > 0, "%s is worth something" % orb)
		_check(TownPrices.orb_value(orb, Vector2i(30, 0)) > value, "%s is worth more out deep" % orb)
	_check(TownPrices.orb_value("Orb of Nothing", TOWN_CELL) == 0, "an orb this build has no weight for is worth nothing")
	return true


func _test_state() -> bool:
	var state := TownState.new()
	var spot := Vector2i(130, 128)
	_check(not state.visited(spot), "a town nobody has walked into is unvisited")
	state.visit(spot)
	_check(state.visited(spot), "and visited once they have")
	_check(state.towns.size() == 1 and state.visit(spot) is Dictionary, "a second visit is the same drawer")
	_check(TownState.key(spot) == "130,128", "a spot is filed under its own coordinates")
	_check(not state.visited(Vector2i(128, 130)), "and x,y is not y,x")

	var back := TownState.from_dict(state.to_dict())
	_check(back.visited(spot) and back.towns.size() == 1, "a town state round-trips")
	_check(TownState.from_dict("nonsense").towns.is_empty(), "the wrong shape is no towns")
	_check(TownState.from_dict({"1,1": "nonsense"}).towns.is_empty(), "and so is the wrong shape inside")
	return true


func _test_save() -> bool:
	var inventory := Inventory.new()
	inventory.towns.visit(Vector2i(128, 128))
	inventory.towns.visit(Vector2i(133, 128))
	_check(inventory.save(TEST_PATH), "saved")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.towns.visited(Vector2i(128, 128)) and back.towns.visited(Vector2i(133, 128)),
			"both towns come back")
	_check(not back.towns.visited(Vector2i(1, 1)), "and nothing else does")

	# A version 9 save has no towns at all, and comes back having visited none.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 9, "gold": 40, "items": []}')
	file.close()
	var problem: Array = []
	var old := Inventory.load_from(TEST_PATH, problem)
	_check(problem.is_empty(), "a version 9 save still loads (%s)" % [problem])
	_check(old.gold == 40, "with what it was carrying")
	_check(old.towns.towns.is_empty(), "and no town visited")
	return true


## What a vendor has on its shelf: six of each, the same six under the same seed, a bought square
## that stays empty, and a restock that comes when it is paid for and at no other time.
func _test_stock() -> bool:
	var drawer := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	_check(VendorStock.items(drawer).is_empty() and VendorStock.orbs(drawer).is_empty(),
			"a town nobody has walked into has nothing on its shelves")
	_check(VendorStock.restock(drawer, TownWorld.Tier.SMALL, TOWN_CELL, rng),
			"the shelves are filled on the way in")
	var items := VendorStock.items(drawer)
	var orbs := VendorStock.orbs(drawer)
	_check(items.size() == VendorStock.SIZE, "six pieces (%d)" % items.size())
	_check(orbs.size() == VendorStock.SIZE, "six orbs (%d)" % orbs.size())
	for at in VendorStock.SIZE:
		_check(items[at] != null and LootTable.ITEMS.has((items[at] as Item).type),
				"square %d holds a piece the game has" % at)
		_check(OrbTable.ORBS.has(orbs[at]), "orb square %d holds an orb the game has (%s)" % [at, orbs[at]])

	# The same seed deals the same shelf: a shelf is rolled once and written down, and what is written
	# down has to be the same thing twice or there is nothing to test and nothing to save.
	var twin := {}
	var twin_rng := RandomNumberGenerator.new()
	twin_rng.seed = WORLD_SEED
	VendorStock.restock(twin, TownWorld.Tier.SMALL, TOWN_CELL, twin_rng)
	_check(twin[VendorStock.ITEMS] == drawer[VendorStock.ITEMS], "the same seed deals the same pieces")
	_check(twin[VendorStock.ORBS] == drawer[VendorStock.ORBS], "and the same orbs")

	# Bought, and empty until the restock -- the square stays, so what is gone is as plain as what is left.
	VendorStock.take(drawer, VendorStock.ITEMS, 2)
	VendorStock.take(drawer, VendorStock.ORBS, 5)
	_check(VendorStock.items(drawer).size() == VendorStock.SIZE
			and VendorStock.items(drawer)[2] == null, "a bought piece leaves its square empty")
	_check(VendorStock.orbs(drawer).size() == VendorStock.SIZE
			and VendorStock.orbs(drawer)[5].is_empty(), "and so does a bought orb")
	_check(VendorStock.items(drawer)[3] != null, "the square beside it is untouched")

	_check(not VendorStock.restock(drawer, TownWorld.Tier.SMALL, TOWN_CELL, rng),
			"walking in again stocks nothing")
	_check(VendorStock.items(drawer)[2] == null, "so the bought square is still empty")

	# Paid for: fresh shelves now, each one twice the last.
	var first_price := TownPrices.reroll_price(TOWN_CELL, VendorStock.rerolls(drawer, VendorStock.ITEMS))
	_check(VendorStock.rerolls(drawer, VendorStock.ITEMS) == 0 and first_price > 0,
			"a first reroll has a price (%d)" % first_price)
	var before: Array = (drawer[VendorStock.ITEMS] as Array).duplicate(true)
	var orbs_before: Array = (drawer[VendorStock.ORBS] as Array).duplicate(true)
	VendorStock.reroll(drawer, VendorStock.ITEMS, TownWorld.Tier.SMALL, TOWN_CELL, rng)
	_check(VendorStock.items(drawer)[2] != null, "a paid reroll fills the empty square")
	_check(drawer[VendorStock.ITEMS] != before, "with different stock")
	_check(VendorStock.rerolls(drawer, VendorStock.ITEMS) == 1, "and is counted")
	# The two vendors are two counters: the orb shelf is neither restocked nor made dearer by it.
	_check(drawer[VendorStock.ORBS] == orbs_before and VendorStock.orbs(drawer)[5].is_empty(),
			"the orb shelf is left exactly as it was")
	_check(VendorStock.rerolls(drawer, VendorStock.ORBS) == 0, "and its price has not moved")
	VendorStock.reroll(drawer, VendorStock.ORBS, TownWorld.Tier.SMALL, TOWN_CELL, rng)
	_check(not VendorStock.orbs(drawer)[5].is_empty() and VendorStock.rerolls(drawer, VendorStock.ORBS) == 1,
			"which has a count of its own")
	_check(VendorStock.rerolls(drawer, VendorStock.ITEMS) == 1, "that does not touch the gear shelf's")
	_check(TownPrices.reroll_price(TOWN_CELL, 1) == roundf(first_price * TownPrices.REROLL_GROWTH),
			"the next costs twice as much")
	var sixth := pow(TownPrices.REROLL_GROWTH, 5)
	_check(absf(TownPrices.reroll_price(TOWN_CELL, 5) - first_price * sixth) <= sixth,
			"and the sixth that growth five times over")
	var kept := Inventory.new()
	kept.towns.visit(Vector2i(130, 128)).merge(drawer.duplicate(true))
	kept.save(TEST_PATH)
	_check(VendorStock.rerolls(Inventory.load_from(TEST_PATH).towns.visit(Vector2i(130, 128)),
			VendorStock.ITEMS) == 1, "and closing the game does not forgive what the town has been paid")

	# A hand-edited or half-written shelf is no shelf, never a guess at one.
	_check(VendorStock.items({VendorStock.ITEMS: "nonsense"}).is_empty(), "the wrong shape is no stock")
	_check(VendorStock.items({VendorStock.ITEMS: [null, null]}).is_empty(), "and so is the wrong count")
	_check(VendorStock.orbs({VendorStock.ORBS: ["Orb of Nothing", "", "", "", "", ""]})[0].is_empty(),
			"an orb this build no longer has reads as an empty square")

	# The shelf goes in the save with the town it belongs to.
	var inventory := Inventory.new()
	inventory.towns.visit(Vector2i(130, 128)).merge(drawer.duplicate(true))
	_check(inventory.save(TEST_PATH), "saved with the shelf in it")
	var back := Inventory.load_from(TEST_PATH).towns.visit(Vector2i(130, 128))
	_check(VendorStock.items(back).size() == VendorStock.SIZE, "six pieces come back")
	_check(VendorStock.orbs(back) == VendorStock.orbs(drawer), "the same orbs come back")
	var first: Item = VendorStock.items(back)[0]
	var was: Item = VendorStock.items(drawer)[0]
	_check(first.type == was.type and first.rarity == was.rarity and first.level == was.level
			and first.mods == was.mods, "a piece off the shelf is the same piece after a save")
	return true


## A shelf is a better class of luck than the ground around it. Over enough rolls the vendor's
## rarities and its levels both have to beat what an ordinary body on the same tile hands over --
## that is the whole of what "favourably rolled" means, and it is the only thing worth paying for.
func _test_stock_rolls() -> bool:
	const ROLLS := 400
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var body := ""
	for name: String in EnemyRoster.names():
		if EnemyRoster.tier_of(name) == EnemyRoster.Tier.COMMON:
			body = name
			break
	_check(not body.is_empty(), "there is an ordinary body to read the shelf against")
	var shelf_rarity := 0
	var shelf_level := 0
	var ceiling := MapBuilder.level_of(TOWN_CELL) + int(LootTable.TIER_LEVEL[EnemyRoster.Tier.BOSS])
	for i in ROLLS:
		var piece := VendorStock.roll_item(TownWorld.Tier.MEDIUM, TOWN_CELL, rng)
		shelf_rarity += piece.rarity
		shelf_level += piece.level
		_check(piece.level <= ceiling and piece.level >= 1,
				"a shelf piece stays under what the ground allows (%d over %d)" % [piece.level, ceiling])
		# And is made of something the town's tile level has unlocked, whatever the piece's own level:
		# no counter deals a material the ground under it could not.
		var row: Dictionary = LootTable.ITEMS[piece.type]
		var levels: Array = LootTable.KINDS[row["kind"]].get("tier_levels", LootTable.TIER_MIN_LEVEL)
		_check(MapBuilder.level_of(TOWN_CELL) >= int(levels[int(row["tier"])]),
				"a %s is past what a level-%d town deals (%d)"
						% [piece.type, MapBuilder.level_of(TOWN_CELL), levels[row["tier"]]])
	var drop_rarity := 0
	var drop_level := 0
	for i in ROLLS:
		var piece := LootTable.roll(body, rng, true, MapBuilder.level_of(TOWN_CELL))
		drop_rarity += piece.rarity
		drop_level += piece.level
	_check(shelf_rarity > drop_rarity, "the shelf out-rarities the ground (%d over %d)"
			% [shelf_rarity, drop_rarity])
	_check(shelf_level > drop_level, "and out-levels it (%d over %d)" % [shelf_level, drop_level])

	# The orbs lean the same way, and by the same two draws rather than by a table of their own.
	var favoured := 0
	var plain := 0
	for i in ROLLS:
		favoured += int(OrbTable.ORBS[OrbTable.roll_favoured(rng)]["weight"])
		plain += int(OrbTable.ORBS[OrbTable._weighted(rng)]["weight"])
	_check(favoured < plain, "a vendor's orbs are rarer than what falls (%d under %d)" % [favoured, plain])
	return true


## The smith's own rules, with no interface in front of them: what an upgrade does to a piece, what
## the cap is for, what a break leaves behind, and what either costs.
func _test_smith() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var cap := MapBuilder.level_of(TOWN_CELL) + int(LootTable.TIER_LEVEL[EnemyRoster.Tier.BOSS])
	_check(cap > 2, "the ground out here allows more than a level or two (%d)" % cap)
	# Two streams, found by asking rather than by pinning a magic number: setting `seed` rewinds, so
	# the draw that was probed is the draw the upgrade will make.
	var safe := _stream_that(false)
	var doomed := _stream_that(true)

	# An upgrade is the base stats of a fresh roll at the new level, and the modifiers left as they were.
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3)
	var mods_before := piece.mods.duplicate(true)
	# A line no level moves (spawn speed, the clock) has no tiers, and its "tier" is only the level.
	var tiered := piece.mods.filter(func(mod: Dictionary) -> bool: return ModifierTable.tiered(str(mod["id"])))
	var tiers_before := tiered.map(piece.tier_of)
	_check(Blacksmith.can_upgrade(piece, cap), "a piece under the cap can be upgraded")
	_check(Blacksmith.why_not_upgrade(piece, cap).is_empty(), "and nothing is said against it")
	_check(Blacksmith.upgrade(piece, cap, safe), "the hammer lands")
	_check(piece.level == 4, "the piece is a level higher (%d)" % piece.level)
	_check(piece.stats == Item.scaled_stats("Wooden Sword", 4),
			"with exactly the base stats a fresh roll at that level would carry")
	var pick := func(mods: Array, key: String) -> Array: return mods.map(func(mod: Dictionary): return mod[key])
	_check(pick.call(piece.mods, "id") == pick.call(mods_before, "id")
			and pick.call(piece.mods, "value") == pick.call(mods_before, "value"),
			"carrying the modifiers it already had, at the numbers they had")
	_check(not tiered.is_empty() and tiered.map(piece.tier_of) == tiers_before, "and at the tiers they had")
	_check(not piece.broken, "nothing broke")

	# A locked line is what the lock is bought for: the hammer leaves its number where it was.
	var pinned_piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3)
	_check(Blacksmith.lock(pinned_piece, rng), "a line is pinned before the blow")
	var held := pinned_piece.locked_mod().duplicate(true)
	_check(Blacksmith.upgrade(pinned_piece, cap, safe), "the hammer lands on it")
	_check(pinned_piece.locked_mod() == held, "and the locked line keeps the value it was locked at")

	# The cap is the ground's, so the smith cannot walk a piece past the frontier.
	var topped := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, cap)
	_check(not Blacksmith.can_upgrade(topped, cap), "a piece at the cap is refused")
	_check(not Blacksmith.why_not_upgrade(topped, cap).is_empty(), "with a reason")
	_check(not Blacksmith.upgrade(topped, cap, safe) and topped.level == cap and not topped.broken,
			"and nothing moves")
	_check(not Blacksmith.can_upgrade(null, cap) and Blacksmith.why_not_upgrade(null, cap).is_empty(),
			"a piece that is not there is refused without a fuss")

	# A break: the level and the stats stand, and the piece takes no more work of any kind.
	var ruined := Item.rolled("Leather Boots", ItemRarity.Rarity.RARE, rng, 3)
	var ruined_stats := ruined.base_stats()
	var ruined_mods := ruined.mods.duplicate(true)
	_check(not Blacksmith.upgrade(ruined, cap, doomed), "the hammer broke it")
	_check(ruined.broken, "and the piece carries it")
	_check(ruined.level == 3 and ruined.base_stats() == ruined_stats,
			"a break moves neither the level nor the stats")
	_check(ruined.mods == ruined_mods, "nor the modifiers")
	_check(not Blacksmith.can_upgrade(ruined, cap) and not Blacksmith.can_lock(ruined),
			"and a broken piece takes no more work")
	_check(Blacksmith.why_not_upgrade(ruined, cap) == Blacksmith.BROKEN
			and Blacksmith.why_not_lock(ruined) == Blacksmith.BROKEN, "each of which says so")

	# One in twenty, near enough, over enough blows to say so.
	const BLOWS := 2000
	var breaks := 0
	for i in BLOWS:
		var subject := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 1)
		if not Blacksmith.upgrade(subject, 99, rng):
			breaks += 1
		_check(subject.broken == (subject.level == 1), "a blow either raised it or broke it")
	_check(breaks > BLOWS * Blacksmith.BREAK_CHANCE * 0.6
			and breaks < BLOWS * Blacksmith.BREAK_CHANCE * 1.4,
			"the hammer breaks about one in twenty (%d of %d)" % [breaks, BLOWS])

	# The lock: one to a piece, drawn by the smith, and nothing at all on a piece with no modifiers.
	var bare := Item.rolled("Wooden Armour", ItemRarity.Rarity.COMMON, rng, 3)
	_check(not Blacksmith.can_lock(bare), "a bare common has nothing to lock")
	_check(not Blacksmith.why_not_lock(bare).is_empty(), "and says so")
	_check(not Blacksmith.lock(bare, rng) and bare.mods.is_empty(), "and stays bare")
	var elite := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 6)
	_check(Blacksmith.can_lock(elite), "a piece carrying modifiers can have one locked")
	_check(Blacksmith.lock(elite, rng), "the smith pins one")
	var pinned := elite.locked_mod()
	_check(not pinned.is_empty() and pinned in elite.mods, "onto a modifier the piece carries")
	_check(not Blacksmith.can_lock(elite), "a second lock is refused")
	_check(not Blacksmith.why_not_lock(elite).is_empty(), "with a reason of its own")
	_check(not Blacksmith.lock(elite, rng), "and does nothing")
	var locked_count := 0
	for mod in elite.mods:
		if bool(mod.get("locked", false)):
			locked_count += 1
	_check(locked_count == 1, "one lock, not two (%d)" % locked_count)
	# Which line it lands on is the smith's draw, so over a handful of pieces it is not always the first.
	var places := {}
	for i in 40:
		var subject := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 6)
		Blacksmith.lock(subject, rng)
		places[subject.mods.find(subject.locked_mod())] = true
	_check(places.size() > 1, "the smith picks the line rather than always the first (%s)" % [places])

	# Prices: both climb with the level, and a lock is the same number of upgrades wherever it is bought.
	for level in range(1, 12):
		var low := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level)
		var high := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level + 1)
		_check(TownPrices.upgrade_price(high) > TownPrices.upgrade_price(low),
				"an upgrade costs more at level %d than at %d" % [level + 1, level])
		_check(TownPrices.lock_price(high) > TownPrices.lock_price(low),
				"and so does a lock")
		# Each is its dial in bodies at the piece's level, rounded to a whole coin.
		_check(absf(TownPrices.lock_price(low) * TownPrices.UPGRADE_BODIES
				- TownPrices.upgrade_price(low) * TownPrices.LOCK_BODIES)
				<= (TownPrices.UPGRADE_BODIES + TownPrices.LOCK_BODIES) / 2.0,
				"a lock is as many upgrades at level %d as its dial is of theirs" % level)
	_check(TownPrices.upgrade_price(null) == 0 and TownPrices.lock_price(null) == 0,
			"nothing costs nothing to work on")

	# And a piece the hammer ruined is still worth selling, for half of what it was.
	var whole := Item.rolled("Ruby Amulet", ItemRarity.Rarity.RARE, rng, 7)
	var was_worth := TownPrices.sell_price(whole)
	whole.broken = true
	_check(absf(TownPrices.sell_price(whole) * 2.0 - was_worth) <= 1.0,
			"a broken piece fetches half (%d of %d)" % [TownPrices.sell_price(whole), was_worth])

	# An heirloom out of a world that has ended climbs back to the level it had by itself, with the land
	# charted, and the smith will not take it there sooner.
	var heirloom := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 6)
	var peaks := heirloom.mods.map(heirloom.tier_of)
	heirloom.transcend()
	_check(heirloom.level == 1 and heirloom.safe_level == 6, "an heirloom comes back at level 1, remembering 6")
	_check(heirloom.mods.all(func(mod: Dictionary) -> bool: return heirloom.tier_of(mod) == 1),
			"its lines at level 1's one tier")
	_check(not Blacksmith.can_upgrade(heirloom, 99)
			and Blacksmith.why_not_upgrade(heirloom, 99) == "It climbs to level 6 on its own",
			"and under that the smith will not touch it")
	var heir := Inventory.new()
	heir.stash().items.append(heirloom)
	_check(not heir.raise_heirlooms(1) and heirloom.level == 1, "land of level 1 leaves it where it is")
	for level in range(2, 7):
		_check(heir.raise_heirlooms(level) and heirloom.level == level, "land of level %d takes it there" % level)
		_check(heirloom.mods.map(heirloom.tier_of) == peaks.map(func(peak: int) -> int: return mini(peak, level)),
				"each line a tier nearer the one it had, as far as level %d allows" % level)
	_check(not heir.raise_heirlooms(99) and heirloom.level == 6, "and no further than it had been")
	_check(not heirloom.broken and heirloom.stats == Item.scaled_stats("Wooden Sword", 6),
			"whole, and worth what a fresh level 6 is")
	_check(Item.from_dict(heirloom.to_dict()).mods == heirloom.mods, "and the save remembers the tiers")
	_check(Blacksmith.can_upgrade(heirloom, 99), "past it the smith takes it on")
	doomed = _stream_that(true)
	_check(not Blacksmith.upgrade(heirloom, 99, doomed) and heirloom.broken and heirloom.level == 6,
			"and the blow past it can break it")
	heirloom.transcend()
	_check(not heir.raise_heirlooms(6) and heirloom.level == 1, "and a broken one climbs no more")
	return true


## The board with no interface in front of it: who it posts and where they live, what a posting pays,
## when a kill counts against one, and what a hand-in and a restock do to it.
func _test_bounties() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var envs := PackedStringArray(["grass"])
	var drawer := {}
	_check(BountyBoard.bounties(drawer).is_empty(), "a board nobody has walked up to has nothing on it")
	_check(not BountyBoard.seen(drawer), "and has not been read")
	_check(BountyBoard.bounties({VendorStock.ITEMS: []}).is_empty(),
			"a town saved before there were boards has none")
	_check(BountyBoard.restock(drawer, envs, TOWN_CELL, rng), "the board is posted with the shelves")

	var posted := BountyBoard.bounties(drawer)
	_check(posted.size() == BountyBoard.COMMONS + BountyBoard.ELITES,
			"three postings (%d)" % posted.size())
	var tiers := {EnemyRoster.Tier.COMMON: 0, EnemyRoster.Tier.ELITE: 0}
	for bounty: Dictionary in posted:
		var enemy := str(bounty[BountyBoard.ENEMY])
		_check(EnemyRoster.ENEMIES.has(enemy), "%s is an enemy the game has" % enemy)
		_check(enemy != Encounter.MIMIC, "the mimic is never posted: it lives nowhere")
		var tier := EnemyRoster.tier_of(enemy)
		_check(tier != EnemyRoster.Tier.BOSS, "%s is not a boss" % enemy)
		tiers[tier] = int(tiers.get(tier, 0)) + 1
		var lives := false
		for env: String in EnemyRoster.environments_of(enemy):
			lives = lives or env in envs
		_check(lives, "%s lives on the land around the town" % enemy)
		var need := int(bounty[BountyBoard.NEED])
		_check(need == int(BountyBoard.TIER_NEED_ELITE[0] if tier == EnemyRoster.Tier.ELITE
				else BountyBoard.TIER_NEED_COMMON[0]), "%s asks for its tier's count (%d)" % [enemy, need])
		_check(int(bounty[BountyBoard.HAVE]) == 0, "%s starts at nothing" % enemy)
		_check(not bool(bounty[BountyBoard.DONE]), "and is not handed in")
		_check(float(bounty[BountyBoard.GOLD]) == maxf(1.0, roundf(Encounter.gold_of(enemy, TOWN_CELL)
				* BountyBoard.reward_of(tier))), "%s pays what its bodies are worth" % enemy)
		_check(int(bounty[BountyBoard.XP]) == Encounter.xp_of(enemy, TOWN_CELL) * BountyBoard.xp_reward_of(tier),
				"%s pays its bodies' experience" % enemy)
		_check(BountyBoard.orbs_of(bounty).size() == int(BountyBoard.ORBS[tier]),
				"%s pays its tier's orbs (%s)" % [enemy, BountyBoard.orbs_of(bounty)])
		var promise := BountyBoard.item_of(bounty)
		if not promise.is_empty():
			var kind := str(promise[BountyBoard.ITEM_KIND])
			var unique := str(promise[BountyBoard.ITEM_RARITY]) == "unique"
			_check(unique == kind.is_empty() and (unique or LootTable.KINDS.has(kind)),
					"a promised piece is a kind the game has, or a unique with none (%s)" % [promise])
			_check(int(promise[BountyBoard.ITEM_PLUS]) >= 0, "and is ascended no times or more")
	_check(tiers[EnemyRoster.Tier.COMMON] == BountyBoard.COMMONS
			and tiers[EnemyRoster.Tier.ELITE] == BountyBoard.ELITES,
			"two of the rabble and one elite (%s)" % [tiers])
	_check(str(posted[0][BountyBoard.ENEMY]) != str(posted[1][BountyBoard.ENEMY]),
			"and the two commons are not the same monster twice")

	# What a board promises over many postings: pieces, uniques among them, and ascended ones.
	var promised := {"items": 0, "uniques": 0, "plus": 0, "elite_items": 0, "elites": 0}
	var many := RandomNumberGenerator.new()
	many.seed = WORLD_SEED
	for i in 200:
		var fresh := {}
		BountyBoard.restock(fresh, envs, TOWN_CELL, many)
		for bounty: Dictionary in BountyBoard.bounties(fresh):
			var promise := BountyBoard.item_of(bounty)
			var elite := EnemyRoster.tier_of(str(bounty[BountyBoard.ENEMY])) == EnemyRoster.Tier.ELITE
			promised["elites"] += int(elite)
			if promise.is_empty():
				continue
			promised["items"] += 1
			promised["elite_items"] += int(elite)
			promised["uniques"] += int(str(promise[BountyBoard.ITEM_RARITY]) == "unique")
			promised["plus"] += int(promise[BountyBoard.ITEM_PLUS])
	_check(promised["items"] > 0 and promised["uniques"] > 0 and promised["plus"] > 0,
			"boards promise pieces, uniques among them, and ascended ones (%s)" % [promised])
	_check(promised["elite_items"] == promised["elites"], "every elite posting promises a piece (%s)" % [promised])
	# The ascension ladder: a draw under the nth of `PLUS_CHANCES` is at least +n, and past the list every
	# step is `PLUS_TAIL` as likely as the one before, for ever.
	var ladder: Array[float] = []
	ladder.assign(BountyBoard.PLUS_CHANCES)
	for step in 3:
		ladder.append(ladder[-1] * BountyBoard.PLUS_TAIL)
	_check(BountyBoard.plus_of(ladder[0]) == 0, "a draw that clears no step of the ladder is no ascension")
	for step in ladder.size() - 1:
		var draw := (ladder[step] + ladder[step + 1]) / 2.0
		var cleared := ladder.filter(func(chance: float) -> bool: return draw < chance).size()
		_check(BountyBoard.plus_of(draw) == cleared, "a draw of %s is ascended once a step it clears (%d, not %d)"
				% [draw, cleared, BountyBoard.plus_of(draw)])
	_check(BountyBoard.plus_of(0.0) > ladder.size(), "and a draw of nothing still ends (%d)" % BountyBoard.plus_of(0.0))
	# An older save's single orb name reads as a list.
	var old := {BountyBoard.BOUNTIES: [{BountyBoard.ORB: "Orb of Alteration"}, {BountyBoard.ORB: ""}]}
	var read := BountyBoard.bounties(old)
	_check(BountyBoard.orbs_of(read[0]) == ["Orb of Transmutation"] and BountyBoard.orbs_of(read[1]).is_empty(),
			"a saved orb name is read back as a list (%s)" % [read])
	_check(BountyBoard.item_of({BountyBoard.ITEM: {"kind": "sword", "rarity": "elite", "plus": 1}}).size() == 3
			and BountyBoard.item_of({BountyBoard.ITEM: {"kind": "hat", "rarity": "elite", "plus": 0}}).is_empty()
			and BountyBoard.item_of({BountyBoard.ITEM: {"kind": "sword", "rarity": "mythic", "plus": 0}}).is_empty()
			and BountyBoard.item_of({BountyBoard.ITEM: {"kind": "sword", "rarity": "unique", "plus": 0}}).is_empty()
			and BountyBoard.item_of({}).is_empty(),
			"a promise this build cannot keep is no promise")
	_check(BountyBoard.reward_text({BountyBoard.ITEM: {"kind": "sword", "rarity": "elite", "plus": 1}})
			== "an epic sword +1" and BountyBoard.reward_text({BountyBoard.ITEM:
			{"kind": "", "rarity": "unique", "plus": 0}}) == "a unique item"
			and BountyBoard.reward_text({}).is_empty(), "and the promise is put into words")
	# The piece itself, rolled at the hand-in, is what was promised and no more.
	var sworn := {BountyBoard.ENEMY: "Imp", BountyBoard.ITEM: {"kind": "sword", "rarity": "elite", "plus": 1}}
	var paid := BountyBoard.reward_item(sworn, TOWN_CELL, rng)
	_check(paid != null and str(LootTable.ITEMS[paid.type]["kind"]) == "sword"
			and paid.rarity == ItemRarity.Rarity.ELITE and paid.plus == 1 and paid.unique.is_empty()
			and paid.level >= 1 and paid.level <= VendorStock.ceiling(TOWN_CELL, EnemyRoster.tier_of("Imp")),
			"an elite sword +1 is what the hand-in pays (%s)" % [paid.display_name() if paid else "nothing"])
	sworn[BountyBoard.ITEM] = {"kind": "", "rarity": "unique", "plus": 0}
	paid = BountyBoard.reward_item(sworn, TOWN_CELL, rng)
	_check(paid != null and not paid.unique.is_empty() and paid.rarity == ItemRarity.Rarity.UNIQUE
			and paid.plus == 0, "a unique promised is a unique paid (%s)" % [paid.display_name() if paid else "nothing"])
	# Only one the player has unlocked, as a body would drop.
	var unlocked_only := true
	for i in 40:
		unlocked_only = unlocked_only and BountyBoard.reward_item(sworn, TOWN_CELL, rng, ["metronome"]).unique == "metronome"
		unlocked_only = unlocked_only and str(BountyBoard.reward_item(sworn, TOWN_CELL, rng).unique) in Achievements.STARTERS
	_check(unlocked_only, "and it is always one the player has unlocked")
	_check(BountyBoard.reward_item({BountyBoard.ENEMY: "Imp"}, TOWN_CELL, rng) == null,
			"and a posting that promised none pays none")

	# A board is rolled and so is written down, which means the same seed has to post the same work.
	var twin := {}
	var twin_rng := RandomNumberGenerator.new()
	twin_rng.seed = WORLD_SEED
	BountyBoard.restock(twin, envs, TOWN_CELL, twin_rng)
	_check(twin[BountyBoard.BOUNTIES] == drawer[BountyBoard.BOUNTIES],
			"the same seed posts the same three")
	var bare := {}
	_check(not BountyBoard.restock(bare, PackedStringArray(), TOWN_CELL, rng),
			"a town with no land around it posts nothing")
	_check(BountyBoard.bounties(bare).is_empty(), "and its board stays bare")

	# Kills count against the one posting the player has accepted, and against nothing before that.
	var state := TownState.new()
	var spot := Vector2i(130, 128)
	var town := state.visit(spot)
	town.merge(drawer.duplicate(true))
	var target := str(BountyBoard.bounties(town)[0][BountyBoard.ENEMY])
	_check(not BountyBoard.any_seen(state), "no board read yet")
	_check(not BountyBoard.count_kill(state, target), "so a kill counts nowhere")
	_check(_have(town, 0) == 0, "and the posting stands at nothing")
	_check(BountyBoard.see(town), "the player reads the board")
	_check(not BountyBoard.see(town), "which is news exactly once")
	_check(BountyBoard.any_seen(state), "and is what puts the journal in the corner")
	_check(not BountyBoard.count_kill(state, target), "reading is not accepting: still nothing counts")
	var first: Dictionary = BountyBoard.bounties(town)[0]
	var second: Dictionary = BountyBoard.bounties(town)[1]
	_check(BountyBoard.active(state).is_empty(), "no work is out")
	_check(BountyBoard.active_spot(state).is_empty(), "and no town has any out")
	_check(BountyBoard.accept(state, first), "the first posting is accepted")
	_check(BountyBoard.active(state) == first, "and is the work that is out")
	_check(state.towns[BountyBoard.active_spot(state)] == town, "and its town is the one that posted it")
	_check(BountyBoard.takes(first, target) and not BountyBoard.takes(first, "nobody")
			and not BountyBoard.takes({}, target), "a posting wants its own monster and nothing else")
	_check(not BountyBoard.accept(state, second), "a second cannot be taken on beside it")
	_check(not BountyBoard.is_active(second), "and stays unaccepted")
	# Only on land as deep as the town that asked: the doorstep does not count towards a deep board.
	var depth := int(first[BountyBoard.LEVEL])
	_check(depth == MapBuilder.level_of(TOWN_CELL), "a posting carries its town's level (%d)" % depth)
	first[BountyBoard.LEVEL] = 4
	_check(not BountyBoard.count_kill(state, target, 1, 3), "a kill on shallower land does not count")
	_check(BountyBoard.count_kill(state, target, 1, 4), "one on land of the town's level does")
	_check(BountyBoard.count_kill(state, target, 1, 9), "and so does one deeper")
	first[BountyBoard.LEVEL] = depth
	# Giving work up puts it back on the board with nothing done, and frees the player for another.
	_check(BountyBoard.abandon(first), "the accepted bounty can be given up")
	_check(BountyBoard.active(state).is_empty() and _have(town, 0) == 0,
			"which leaves no work out and loses its kills")
	_check(not BountyBoard.abandon(first), "and cannot be given up twice")
	_check(BountyBoard.accept(state, first), "it can be taken on again")
	_check(BountyBoard.count_kill(state, target, 3), "three of them count now")
	_check(_have(town, 0) == 3, "against the posting that wants them (%d)" % _have(town, 0))
	_check(_have(town, 1) == 0, "and not against the one that does not")
	_check(not BountyBoard.count_kill(state, str(second[BountyBoard.ENEMY])),
			"a posting not accepted makes no progress")
	_check(not BountyBoard.count_kill(state, "Nobody At All"),
			"a monster no board wants counts nowhere")

	# Progress is a job of work, not a tally: it stops at what was asked for.
	var need := int(BountyBoard.bounties(town)[0][BountyBoard.NEED])
	BountyBoard.count_kill(state, target, need * 2)
	_check(_have(town, 0) == need, "progress stops at the count asked for (%d)" % _have(town, 0))
	_check(not BountyBoard.count_kill(state, target), "and a finished posting counts no further")

	# Handing in: only a finished one, and only once.
	var finished: Dictionary = BountyBoard.bounties(town)[0]
	var working: Dictionary = BountyBoard.bounties(town)[1]
	_check(BountyBoard.ready(finished), "a posting worked off is ready to hand in")
	_check(not BountyBoard.ready(working), "one still being worked on is not")
	_check(not BountyBoard.claim(working), "and cannot be handed in")
	_check(not BountyBoard.accept(state, working), "a finished bounty still blocks the next until handed in")
	_check(BountyBoard.claim(finished), "the finished one is handed in")
	_check(not BountyBoard.claim(finished), "exactly once")
	_check(not BountyBoard.ready(finished), "and is not waiting to be paid again")

	# New work comes when the old work is all handed in, and not a posting sooner.
	_check(not BountyBoard.cleared(town), "one handed in of three is not a cleared board")
	_check(not BountyBoard.restock(town, envs, TOWN_CELL, rng), "so nothing new is posted over it")
	_check(BountyBoard.bounties(town)[0] == finished, "and the board is as it was")
	for bounty: Dictionary in BountyBoard.bounties(town):
		if bool(bounty[BountyBoard.DONE]):
			continue
		_check(BountyBoard.accept(state, bounty), "with the last handed in, the next can be accepted")
		BountyBoard.count_kill(state, str(bounty[BountyBoard.ENEMY]), int(bounty[BountyBoard.NEED]))
		_check(BountyBoard.claim(bounty), "and handed in in its turn")
	_check(BountyBoard.cleared(town), "all three handed in is a cleared board")
	_check(BountyBoard.restock(town, envs, TOWN_CELL, rng), "which is what brings new work")
	var after := BountyBoard.bounties(town)
	_check(after.size() == BountyBoard.COMMONS + BountyBoard.ELITES,
			"the board is full again (%d)" % after.size())
	for bounty: Dictionary in after:
		_check(not bool(bounty[BountyBoard.DONE]) and int(bounty[BountyBoard.HAVE]) == 0,
				"and everything on it is fresh")
	BountyBoard.accept(state, after[0])
	BountyBoard.count_kill(state, str(after[0][BountyBoard.ENEMY]), 3)
	var carried := int(after[0][BountyBoard.HAVE])
	_check(carried == 3, "the new work taken on has three against it (%d)" % carried)

	# The board goes in the save with the town it belongs to, kills and all.
	var inventory := Inventory.new()
	inventory.towns.towns = state.towns
	_check(inventory.save(TEST_PATH), "saved with the board in it")
	var back := Inventory.load_from(TEST_PATH).towns.visit(spot)
	_check(BountyBoard.seen(back), "it is still a board the player has read")
	_check(BountyBoard.bounties(back).size() == BountyBoard.COMMONS + BountyBoard.ELITES,
			"with its three postings")
	var saved_active := BountyBoard.active(Inventory.load_from(TEST_PATH).towns)
	_check(int(saved_active.get(BountyBoard.HAVE, -1)) == carried,
			"and the accepted one's progress (%d)" % int(saved_active.get(BountyBoard.HAVE, -1)))
	return true


## A board's tier, kept by its town, and what clearing a board offers: three options of different kinds,
## each the kind it says it is, only orbs the world has unlocked, and one taken while the rest go.
func _test_board_tiers() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var envs := PackedStringArray(["grass"])
	var drawer := {}
	_check(BountyBoard.board_tier(drawer) == 1, "a town's board starts at tier I")
	_check(not BountyBoard.clear(drawer, TOWN_CELL, rng), "a board with nothing on it is not cleared for a reward")
	_check(not drawer.has(BountyBoard.CHOICE) and BountyBoard.board_tier(drawer) == 1, "and pays nothing")
	BountyBoard.restock(drawer, envs, TOWN_CELL, rng)
	_check(not BountyBoard.clear(drawer, TOWN_CELL, rng), "nor is one with work still on it")
	_check(BountyBoard.choice(drawer).is_empty() and BountyBoard.board_tier(drawer) == 1, "which pays nothing either")
	for tier: int in [2, 3, 3]:
		for bounty: Dictionary in BountyBoard.bounties(drawer):
			bounty[BountyBoard.DONE] = true
		_check(BountyBoard.clear(drawer, TOWN_CELL, rng), "a board handed in whole is cleared")
		_check(BountyBoard.board_tier(drawer) == tier, "and the town's board is tier %d (%d)"
				% [tier, BountyBoard.board_tier(drawer)])
		_check(BountyBoard.choice(drawer).size() == BountyBoard.CHOICES, "and three are offered for it")
		BountyBoard.restock(drawer, envs, TOWN_CELL, rng)
	# The next board is posted at the new tier, asking more.
	for bounty: Dictionary in BountyBoard.bounties(drawer):
		var elite := EnemyRoster.tier_of(str(bounty[BountyBoard.ENEMY])) == EnemyRoster.Tier.ELITE
		_check(int(bounty[BountyBoard.NEED]) == int(BountyBoard.TIER_NEED_ELITE[2] if elite
				else BountyBoard.TIER_NEED_COMMON[2]), "a tier III posting asks tier III's count")
	# And pays more, for the same monster on the same land.
	for enemy: String in ["Imp", BountyBoard.bounties(drawer)[2][BountyBoard.ENEMY]]:
		var tier := EnemyRoster.tier_of(enemy)
		var low := BountyBoard._posting(enemy, tier, TOWN_CELL, rng, OrbTable.EVERY_WALL, 1)
		var high := BountyBoard._posting(enemy, tier, TOWN_CELL, rng, OrbTable.EVERY_WALL, 3)
		_check(float(high[BountyBoard.GOLD]) > float(low[BountyBoard.GOLD])
				and int(high[BountyBoard.XP]) > int(low[BountyBoard.XP])
				and BountyBoard.orbs_of(high).size() > BountyBoard.orbs_of(low).size(),
				"a tier III %s pays more gold, experience and orbs than a tier I one" % enemy)

	# What is offered, over many clears: each option the kind it is, no two of a kind, and orbs only as
	# far as the walls have unlocked them.
	var ceiling := maxi(1, MapBuilder.level_of(TOWN_CELL) + int(LootTable.TIER_LEVEL[EnemyRoster.Tier.BOSS]))
	var seen := {}
	for walls: int in [0, 1, 2]:
		for tier: int in [1, 2, 3]:
			for i in 30:
				var stored := BountyBoard.roll_choice(tier, TOWN_CELL, rng, Achievements.STARTERS, walls)
				var kinds := {}
				for option: Dictionary in BountyBoard.choice({BountyBoard.CHOICE: stored}):
					var kind := _choice_kind(option, tier, ceiling, walls)
					kinds[kind] = true
					seen[kind] = true
				_check(stored.size() == BountyBoard.CHOICES and kinds.size() == BountyBoard.CHOICES
						and not kinds.has(""), "three options of three good kinds (%s)" % [kinds.keys()])
	_check(seen.size() == BountyBoard.CHOICE_KINDS.size(), "and every kind turns up (%s)" % [seen.keys()])
	# Lucky is the best of its draws: a material drawn sixty-four times over is the best the level has
	# but once in a million, and one draw is an even draw.
	var lucky := {}
	var plain := {}
	for i in 20:
		lucky[LootTable.tier_at("sword", 9, rng, 64)] = true
		plain[LootTable.tier_at("sword", 9, rng)] = true
	_check(lucky.keys() == ["Masterwork Sword"] and plain.size() > 1,
			"a lucky draw keeps the best material (%s), a plain one any (%s)" % [lucky.keys(), plain.keys()])

	# The offer goes in the save with its town, and one taken lets the rest go.
	var inventory := Inventory.new()
	var spot := Vector2i(130, 128)
	inventory.towns.visit(spot).merge(drawer.duplicate(true))
	_check(inventory.save(TEST_PATH), "saved with the offer in it")
	var back := Inventory.load_from(TEST_PATH).towns.visit(spot)
	var before := BountyBoard.choice(drawer)
	var after := BountyBoard.choice(back)
	_check(after.size() == before.size() and BountyBoard.board_tier(back) == 3, "the offer and the tier come back")
	for i in after.size():
		var piece: Item = after[i].get(BountyBoard.CHOICE_ITEM)
		_check((piece.display_name() if piece else str(after[i])) == (before[i][BountyBoard.CHOICE_ITEM].display_name()
				if before[i].has(BountyBoard.CHOICE_ITEM) else str(before[i])), "option %d as it was" % i)
	_check(BountyBoard.take_choice(back, BountyBoard.CHOICES).is_empty()
			and BountyBoard.choice(back).size() == after.size(),
			"an option that is not there is not taken, and nothing goes")
	var taken := BountyBoard.take_choice(back, 1)
	_check(not taken.is_empty() and BountyBoard.choice(back).is_empty(), "one taken, and the others are gone")
	_check(BountyBoard.take_choice(back, 0).is_empty(), "so nothing more can be taken")
	_check(BountyBoard.choice({BountyBoard.CHOICE: [{BountyBoard.CHOICE_ORB: "Orb of Nothing",
			BountyBoard.CHOICE_COUNT: 3},
			{BountyBoard.CHOICE_ITEM: "not a piece"}, "nor this"]}).is_empty(), "an offer this build cannot read is none")
	return true


## The ledger on the boards: every fight counts a body as it falls; a tile fight writes it down at once
## and a run as its kills are banked.
func _test_bounty_kills() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var inventory := Inventory.new()
	var spot := Vector2i(130, 128)
	var drawer := inventory.towns.visit(spot)
	BountyBoard.restock(drawer, PackedStringArray(["grass"]), TOWN_CELL, rng)
	BountyBoard.accept(inventory.towns, BountyBoard.bounties(drawer)[0])
	var target := str(BountyBoard.bounties(drawer)[0][BountyBoard.ENEMY])
	# A job of five, whatever the board's own dial asks for: the counts below are this test's.
	BountyBoard.bounties(drawer)[0][BountyBoard.NEED] = 5

	# What each ledger says of its bodies, gathered in an Array: a lambda captures by value.
	var said := []
	var too_low := []
	var hear := func(ledger: FightLedger) -> void:
		ledger.bounty_counted.connect(func(enemy: String, have: int, need: int) -> void:
			said.append([enemy, have, need]))
		ledger.bounty_too_low.connect(func(enemy: String, level: int) -> void:
			too_low.append([enemy, level]))
	var charting := FightLedger.new(inventory, TEST_PATH)
	hear.call(charting)
	charting.add_kill("nobody")
	_check(said.is_empty(), "a body the bounty does not want is nothing to say")
	charting.add_kill(target)
	_check(_have(drawer, 0) == 1, "a charting fight counts a body as it falls (%d)" % _have(drawer, 0))
	_check(said == [[target, 1, 5]], "and says what the bounty stands at (%s)" % [said])
	_check(_have(Inventory.load_from(TEST_PATH).towns.visit(spot), 0) == 1, "and writes it down at once")

	# The ledger carries the tile's level to the board, both ways in.
	BountyBoard.bounties(drawer)[0][BountyBoard.LEVEL] = 5
	var shallow := FightLedger.new(inventory, TEST_PATH)
	hear.call(shallow)
	shallow.tile_level = 4
	shallow.add_kill(target)
	_check(_have(drawer, 0) == 1, "a body on land shallower than the town counts for nothing")
	var shallow_run := FightLedger.new(inventory, TEST_PATH, true)
	hear.call(shallow_run)
	shallow_run.tile_level = 4
	shallow_run.add_kill(target)
	_check(_have(drawer, 0) == 1, "and neither does a run's")
	_check(said.size() == 1, "and neither is said to count (%s)" % [said])
	_check(too_low == [[target, 5], [target, 5]], "but each is said to be too low, with the level wanted (%s)" % [too_low])
	shallow.add_kill("nobody")
	_check(too_low.size() == 2, "and a body the bounty does not want is not")

	var run := FightLedger.new(inventory, TEST_PATH, true)
	hear.call(run)
	run.tile_level = 5
	for i in 3:
		run.add_kill(target)
	_check(_have(drawer, 0) == 4, "a run's bodies count as they fall (%d)" % _have(drawer, 0))
	_check(said.slice(1) == [[target, 2, 5], [target, 3, 5], [target, 4, 5]],
			"and each is said as it falls (%s)" % [said])
	_check(_have(Inventory.load_from(TEST_PATH).towns.visit(spot), 0) == 1, "but nothing is written while the run goes on")
	run.bank_kills(3)
	_check(_have(Inventory.load_from(TEST_PATH).towns.visit(spot), 0) == 4, "until its kills are banked")

	# The body that fills the job is said with `have == need`; one past it is nothing to say.
	var last := FightLedger.new(inventory, TEST_PATH, true)
	hear.call(last)
	last.tile_level = 5
	last.add_kill(target)
	last.add_kill(target)
	_check(said.slice(4) == [[target, 5, 5]], "the filling body is said and the one past it is not (%s)" % [said])
	_check(_have(drawer, 0) == 5, "and the board stops at the job (%d)" % _have(drawer, 0))
	shallow.add_kill(target)
	_check(too_low.size() == 2, "and once it is filled, a shallow body is nothing to say either")
	return true
