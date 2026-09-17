extends "res://tests/harness.gd"
## Headless checks for the towns: which counters a settlement has, what a thing is worth over one, the
## selling the bag does while it stands at one, and the drawer all of it is saved in. Run from the
## project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_town.gd

## Never Inventory.SAVE_PATH: these tests write and delete, and that is the player's own save.
const TEST_PATH := "user://test_town.json"
## Nor MapSave.SAVE_PATH, for the same reason and one more: this pins a seed, and a pinned seed that
## differs from a save is a request for another world, which replaces it on the first write.
const TEST_MAP_PATH := "user://test_town_map.json"
## The corner of the world the village rolls are read over: enough spots that a village's coin lands
## both ways and that another seed visibly deals other vendors.
const SPOTS := 20
## The tile the priced things are bought and sold on, ten steps out: deep enough that a level band is
## worth real gold and the rounding at the middle of the map is behind us.
const TOWN_CELL := Vector2i(10, 0)


func _run() -> void:
	_check(_test_services() == true, "service tests ran to the end")
	_check(_test_prices() == true, "price tests ran to the end")
	_check(_test_state() == true, "town state tests ran to the end")
	_check(_test_save() == true, "save tests ran to the end")
	_check(_test_stock() == true, "stock tests ran to the end")
	_check(_test_stock_rolls() == true, "stock roll tests ran to the end")
	_check(_test_smith() == true, "blacksmith tests ran to the end")
	_check(_test_bounties() == true, "bounty board tests ran to the end")
	_check(_test_bounty_kills() == true, "bounty kill tests ran to the end")
	await _test_selling()
	await _test_buying()
	await _test_smithing()
	await _test_board()
	await _test_entering()
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	_report("town")


## The tiers: a board everywhere, one vendor in a village, both in a town, both and a smith in a
## fortress -- and the same answer every time for the same spot.
func _test_services() -> bool:
	_check(TownServices.services_for(-1, Vector2i.ZERO, WORLD_SEED).is_empty(),
			"a tile with no town offers nothing")
	var vendors := {TownServices.GEAR: 0, TownServices.ORBS: 0}
	for y in SPOTS:
		for x in SPOTS:
			var spot := Vector2i(x, y)
			var village := TownServices.services_for(TownWorld.Tier.SMALL, spot, WORLD_SEED)
			_check(TownServices.BOUNTIES in village, "%s has a board" % spot)
			_check(village.size() == 2, "%s has a board and one vendor (%s)" % [spot, village])
			var vendor := TownServices.GEAR if TownServices.GEAR in village else TownServices.ORBS
			_check(vendor in village, "%s names its one vendor" % spot)
			vendors[vendor] += 1
			# Seed-stable: nothing is written down, so walking back has to find the same counter.
			_check(village == TownServices.services_for(TownWorld.Tier.SMALL, spot, WORLD_SEED),
					"%s offers the same village twice" % spot)
	_check(vendors[TownServices.GEAR] > 0 and vendors[TownServices.ORBS] > 0,
			"both vendors turn up across the world (%s)" % [vendors])

	var town := TownServices.services_for(TownWorld.Tier.MEDIUM, Vector2i(3, 4), WORLD_SEED)
	_check(town.size() == 3 and TownServices.GEAR in town and TownServices.ORBS in town
			and not (TownServices.SMITH in town), "a town has both vendors and no smith (%s)" % town)
	var fortress := TownServices.services_for(TownWorld.Tier.FORTRESS, Vector2i(3, 4), WORLD_SEED)
	_check(fortress.size() == 4 and TownServices.SMITH in fortress, "a fortress has all four (%s)" % fortress)
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
	_check(TownPrices.gold_at_level(4) == Encounter.gold_at_steps(6), "level n starts at the nth triangle")
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

	# An orb's price is the other way up from its drop rate: what nobody sees is what nobody sells.
	var commonest := ""
	var rarest := ""
	for orb: String in OrbTable.ORBS:
		if commonest.is_empty() or int(OrbTable.ORBS[orb]["weight"]) > int(OrbTable.ORBS[commonest]["weight"]):
			commonest = orb
		if rarest.is_empty() or int(OrbTable.ORBS[orb]["weight"]) < int(OrbTable.ORBS[rarest]["weight"]):
			rarest = orb
	_check(TownPrices.orb_value(rarest, TOWN_CELL) > TownPrices.orb_value(commonest, TOWN_CELL) * 2,
			"the rarest orb is worth several of the commonest (%d over %d)"
			% [TownPrices.orb_value(rarest, TOWN_CELL), TownPrices.orb_value(commonest, TOWN_CELL)])
	for orb: String in OrbTable.ORBS:
		var value := TownPrices.orb_value(orb, TOWN_CELL)
		_check(value > 0, "%s is worth something" % orb)
		_check(TownPrices.orb_sell_price(orb, TOWN_CELL)
				== maxf(1.0, roundf(value * TownPrices.SELL_SHARE)), "%s sells at the share" % orb)
		_check(TownPrices.orb_sell_price(orb, TOWN_CELL) < value,
				"%s is never bought back for what it fetched" % orb)
		_check(TownPrices.orb_value(orb, Vector2i(30, 0)) > value, "%s is worth more out deep" % orb)
	_check(TownPrices.orb_value("Orb of Nothing", TOWN_CELL) == 0, "an orb this build has no weight for is worth nothing")
	_check(TownPrices.orb_sell_price("Orb of Nothing", TOWN_CELL) == 0, "and fetches nothing")
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
## that stays empty, and a restock that comes when the kills say so and not before.
func _test_stock() -> bool:
	var drawer := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	_check(VendorStock.items(drawer).is_empty() and VendorStock.orbs(drawer).is_empty(),
			"a town nobody has walked into has nothing on its shelves")
	_check(VendorStock.kills_left(drawer, 40) == 0, "and is due a stocking the moment someone does")
	_check(VendorStock.restock(drawer, TownWorld.Tier.SMALL, TOWN_CELL, 40, rng),
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
	VendorStock.restock(twin, TownWorld.Tier.SMALL, TOWN_CELL, 40, twin_rng)
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

	var stocked := 40
	_check(VendorStock.kills_left(drawer, stocked) == VendorStock.RESTOCK_KILLS,
			"the whole count stands right after a stocking")
	_check(not VendorStock.restock(drawer, TownWorld.Tier.SMALL, TOWN_CELL,
			stocked + VendorStock.RESTOCK_KILLS - 1, rng), "one kill short is no restock")
	_check(VendorStock.kills_left(drawer, stocked + VendorStock.RESTOCK_KILLS - 1) == 1,
			"and the count says how short")
	_check(VendorStock.items(drawer)[2] == null, "so the bought square is still empty")

	# Or paid for: fresh shelves now, each one twice the last, and the free restock neither moved nor
	# charged for.
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
	_check(TownPrices.reroll_price(TOWN_CELL, 5) > first_price * 30, "and the sixth thirty times")
	_check(VendorStock.kills_left(drawer, stocked + VendorStock.RESTOCK_KILLS - 1) == 1,
			"paying does not move the free restock")
	VendorStock.take(drawer, VendorStock.ITEMS, 2)
	VendorStock.take(drawer, VendorStock.ORBS, 5)
	_check(VendorStock.restock(drawer, TownWorld.Tier.SMALL, TOWN_CELL,
			stocked + VendorStock.RESTOCK_KILLS, rng), "and at the count it restocks")
	_check(VendorStock.items(drawer)[2] != null and not VendorStock.orbs(drawer)[5].is_empty(),
			"which fills the empty squares")
	_check(VendorStock.rerolls(drawer, VendorStock.ITEMS) == 1 and VendorStock.rerolls(drawer, VendorStock.ORBS) == 1,
			"and a free restock does not forgive what the town has been paid")
	var kept := Inventory.new()
	kept.towns.visit(Vector2i(130, 128)).merge(drawer.duplicate(true))
	kept.save(TEST_PATH)
	_check(VendorStock.rerolls(Inventory.load_from(TEST_PATH).towns.visit(Vector2i(130, 128)),
			VendorStock.ITEMS) == 1, "nor does closing the game")
	_check(VendorStock.kills_left(drawer, stocked + VendorStock.RESTOCK_KILLS) == VendorStock.RESTOCK_KILLS,
			"and starts the count again")

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
	_check(VendorStock.kills_left(back, stocked + VendorStock.RESTOCK_KILLS)
			== VendorStock.RESTOCK_KILLS, "and so does when it was stocked")
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

	# An upgrade is exactly a fresh roll's base stats at the new level, and nothing else moves.
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3)
	var mods_before := piece.mods.duplicate(true)
	_check(Blacksmith.can_upgrade(piece, cap), "a piece under the cap can be upgraded")
	_check(Blacksmith.why_not_upgrade(piece, cap).is_empty(), "and nothing is said against it")
	_check(Blacksmith.upgrade(piece, cap, safe), "the hammer lands")
	_check(piece.level == 4, "the piece is a level higher (%d)" % piece.level)
	_check(piece.stats == Item.scaled_stats("Wooden Sword", 4),
			"with exactly the base stats a fresh roll at that level would carry")
	_check(piece.mods == mods_before, "and the modifiers it already had, at the values they rolled")
	_check(not piece.broken, "nothing broke")

	# The cap is the ground's, so the smith cannot walk a piece past the frontier.
	var topped := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, cap)
	_check(not Blacksmith.can_upgrade(topped, cap), "a piece at the cap is refused")
	_check(not Blacksmith.why_not_upgrade(topped, cap).is_empty(), "with a reason")
	_check(not Blacksmith.upgrade(topped, cap, safe) and topped.level == cap and not topped.broken,
			"and nothing moves")
	_check(not Blacksmith.can_upgrade(null, cap) and Blacksmith.why_not_upgrade(null, cap).is_empty(),
			"a piece that is not there is refused without a fuss")

	# A break: the level and the stats stand, and the piece takes no more work of any kind.
	var ruined := Item.rolled("Leather Boot", ItemRarity.Rarity.RARE, rng, 5)
	var ruined_stats := ruined.base_stats()
	var ruined_mods := ruined.mods.duplicate(true)
	_check(not Blacksmith.upgrade(ruined, cap, doomed), "the hammer broke it")
	_check(ruined.broken, "and the piece carries it")
	_check(ruined.level == 5 and ruined.base_stats() == ruined_stats,
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
	var bare := Item.rolled("Wooden Armor", ItemRarity.Rarity.COMMON, rng, 3)
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

	# Prices: both climb with the level, and a lock is a great many upgrades.
	for level in range(1, 12):
		var low := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level)
		var high := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level + 1)
		_check(TownPrices.upgrade_price(high) > TownPrices.upgrade_price(low),
				"an upgrade costs more at level %d than at %d" % [level + 1, level])
		_check(TownPrices.lock_price(high) > TownPrices.lock_price(low),
				"and so does a lock")
		_check(TownPrices.lock_price(low) > TownPrices.upgrade_price(low) * 10,
				"a lock is worth ten upgrades and more at level %d" % level)
	_check(TownPrices.upgrade_price(null) == 0 and TownPrices.lock_price(null) == 0,
			"nothing costs nothing to work on")

	# And a piece the hammer ruined is still worth selling, for half of what it was.
	var whole := Item.rolled("Ruby Amulet", ItemRarity.Rarity.RARE, rng, 7)
	var was_worth := TownPrices.sell_price(whole)
	whole.broken = true
	_check(absf(TownPrices.sell_price(whole) * 2.0 - was_worth) <= 1.0,
			"a broken piece fetches half (%d of %d)" % [TownPrices.sell_price(whole), was_worth])
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
	_check(BountyBoard.bounties({VendorStock.STOCKED_AT: 0}).is_empty(),
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
		_check(need == (BountyBoard.NEED_ELITE if tier == EnemyRoster.Tier.ELITE
				else BountyBoard.NEED_COMMON), "%s asks for its tier's count (%d)" % [enemy, need])
		_check(int(bounty[BountyBoard.HAVE]) == 0, "%s starts at nothing" % enemy)
		_check(not bool(bounty[BountyBoard.DONE]), "and is not handed in")
		_check(float(bounty[BountyBoard.GOLD]) == maxf(1.0, roundf(Encounter.gold_of(enemy, TOWN_CELL)
				* need * BountyBoard.REWARD_MULT)), "%s pays what its bodies are worth" % enemy)
		_check((not str(bounty[BountyBoard.ORB]).is_empty()) == (tier == EnemyRoster.Tier.ELITE),
				"only the elite posting carries an orb (%s)" % enemy)
	_check(tiers[EnemyRoster.Tier.COMMON] == BountyBoard.COMMONS
			and tiers[EnemyRoster.Tier.ELITE] == BountyBoard.ELITES,
			"two of the rabble and one elite (%s)" % [tiers])
	_check(str(posted[0][BountyBoard.ENEMY]) != str(posted[1][BountyBoard.ENEMY]),
			"and the two commons are not the same monster twice")

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
	_check(BountyBoard.accept(state, first), "the first posting is accepted")
	_check(BountyBoard.active(state) == first, "and is the work that is out")
	_check(not BountyBoard.accept(state, second), "a second cannot be taken on beside it")
	_check(not BountyBoard.is_active(second), "and stays unaccepted")
	# Only on land as deep as the town that asked: the doorstep does not count towards a deep board.
	var depth := int(first[BountyBoard.LEVEL])
	_check(depth == MapBuilder.level_of(TOWN_CELL), "a posting carries its town's level (%d)" % depth)
	first[BountyBoard.LEVEL] = 4
	_check(not BountyBoard.count_kill(state, target, 1, 3), "a kill on shallower land does not count")
	_check(BountyBoard.count_kill(state, target, 1, 4), "one on land of the town's level does")
	_check(BountyBoard.count_kill(state, target, 1, 9), "and so does one deeper")
	first[BountyBoard.HAVE] = 0
	first[BountyBoard.LEVEL] = depth
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

	# The restock keeps the accepted work exactly as it was and posts fresh work over the rest.
	_check(BountyBoard.accept(state, working), "with that handed in, the next can be accepted")
	BountyBoard.count_kill(state, str(working[BountyBoard.ENEMY]), 2)
	var carried := int(working[BountyBoard.HAVE])
	_check(carried == 2, "the other common has two against it (%d)" % carried)
	_check(BountyBoard.restock(town, envs, TOWN_CELL, rng), "the restock posts the empty square again")
	var after := BountyBoard.bounties(town)
	_check(after.size() == BountyBoard.COMMONS + BountyBoard.ELITES,
			"the board is full again (%d)" % after.size())
	var kept := 0
	for bounty: Dictionary in after:
		_check(not bool(bounty[BountyBoard.DONE]), "nothing on it is already handed in")
		if str(bounty[BountyBoard.ENEMY]) == str(working[BountyBoard.ENEMY]):
			kept += 1
			_check(int(bounty[BountyBoard.HAVE]) == carried, "the work in progress kept its progress")
	_check(kept == 1, "and is still the posting it was")

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


## The bank-or-pouch rule, on the boards: a tile fight counts a body as it falls, a run holds its own
## until it banks, and banking twice cannot count one goblin twice.
func _test_bounty_kills() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var inventory := Inventory.new()
	var spot := Vector2i(130, 128)
	var drawer := inventory.towns.visit(spot)
	BountyBoard.restock(drawer, PackedStringArray(["grass"]), TOWN_CELL, rng)
	BountyBoard.accept(inventory.towns, BountyBoard.bounties(drawer)[0])
	var target := str(BountyBoard.bounties(drawer)[0][BountyBoard.ENEMY])

	var charting := FightLedger.new(inventory, TEST_PATH)
	charting.add_kill(target)
	_check(_have(drawer, 0) == 1, "a charting fight counts a body as it falls (%d)" % _have(drawer, 0))
	_check(_have(Inventory.load_from(TEST_PATH).towns.visit(spot), 0) == 1, "and writes it down at once")

	# The ledger carries the tile's level to the board, both ways in.
	BountyBoard.bounties(drawer)[0][BountyBoard.LEVEL] = 5
	var shallow := FightLedger.new(inventory, TEST_PATH)
	shallow.tile_level = 4
	shallow.add_kill(target)
	_check(_have(drawer, 0) == 1, "a body on land shallower than the town counts for nothing")
	var shallow_run := FightLedger.new(inventory, TEST_PATH, true)
	shallow_run.tile_level = 4
	shallow_run.add_kill(target)
	shallow_run.bank()
	_check(_have(drawer, 0) == 1, "and neither does a run's")

	var run := FightLedger.new(inventory, TEST_PATH, true)
	run.tile_level = 5
	for i in 3:
		run.add_kill(target)
	_check(_have(drawer, 0) == 1, "a run's bodies wait in its pouch (%d)" % _have(drawer, 0))
	_check(run.bank(), "the run banks")
	_check(_have(drawer, 0) == 4, "and they all count at once (%d)" % _have(drawer, 0))
	_check(not run.bank(), "a second bank has nothing to do")
	_check(_have(drawer, 0) == 4, "and counts nothing twice (%d)" % _have(drawer, 0))
	_check(_have(Inventory.load_from(TEST_PATH).towns.visit(spot), 0) == 4, "the run's kills were saved")
	return true


## How far along the posting in square `at` of a town's board is.
func _have(drawer: Dictionary, at: int) -> int:
	var posted := BountyBoard.bounties(drawer)
	return 0 if at >= posted.size() else int((posted[at] as Dictionary).get(BountyBoard.HAVE, 0))


## A seeded stream whose very next `randf` does or does not break a piece. `seed` rewinds the stream,
## so the draw probed here is the draw the smith will make.
func _stream_that(breaks: bool) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for seed_value in 500:
		rng.seed = seed_value
		if (rng.randf() < Blacksmith.BREAK_CHANCE) == breaks:
			rng.seed = seed_value
			return rng
	_check(false, "no seed found whose first draw %s" % ["breaks" if breaks else "holds"])
	return rng


## The bag standing at a counter: what the gear merchant's button does, what the orb vendor's tray
## does, and that neither of them is the other.
func _test_selling() -> void:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4)
	inventory.add(piece)
	inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.RARE, rng, 4))
	inventory.add_orb("Orb of Chaos", 3)
	var page := BagPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame

	# Out of a town nothing has changed: the piece is thrown away, not sold.
	page._select_item(inventory.items.find(piece))
	_check(_deep_button(page._detail, "Discard") != null, "outside a town a piece is discarded")
	_check(_deep_button(page._detail, "Sell") == null, "and there is nothing to sell it to")
	_check(page._sections.get_child(0).get_children().any(func(child: Node) -> bool:
			return child is Button and (child as Button).tooltip_text.begins_with("Throw away the")),
			"and a level is cleared")

	# At the gear merchant the same two buttons buy instead.
	page.shop(PackedStringArray([TownServices.GEAR]), TOWN_CELL)
	page._select_item(inventory.items.find(piece))
	var sell := _deep_button(page._detail, "Sell")
	_check(sell != null and _deep_button(page._detail, "Discard") == null,
			"at the merchant the piece is sold rather than thrown away")
	_check(_button(page._sections.get_child(0), "Sell all") != null, "and a level is sold at once")
	var price := TownPrices.sell_price(piece)
	if sell != null:
		sell.pressed.emit()
	_check(inventory.gold == price and price > 0, "the purse holds the price (%d, want %d)"
			% [inventory.gold, price])
	_check(inventory.items.find(piece) == -1, "and the piece is gone from the bag")

	# An orb cannot be sold over a gear counter.
	var held := inventory.orb_count("Orb of Chaos")
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == held and inventory.gold == price,
			"the gear merchant does not buy orbs")

	# At the orb vendor the tray sells and the gear button is gone.
	page.shop(PackedStringArray([TownServices.ORBS]), TOWN_CELL)
	page._select_item(0)
	_check(_deep_button(page._detail, "Discard") != null and _deep_button(page._detail, "Sell") == null,
			"the orb vendor does not buy gear")
	page._select_item(-1)
	var orb_price := TownPrices.orb_sell_price("Orb of Chaos", TOWN_CELL)
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == held - 1, "one orb left the tray")
	_check(inventory.gold == price + orb_price and orb_price > 0,
			"and the purse holds its price (%d, want %d)" % [inventory.gold, price + orb_price])

	# With a piece open the tray is the crafting tray it has always been, vendor or not.
	page._select_item(0)
	var in_hand := inventory.orb_count("Orb of Chaos")
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == in_hand - 1,
			"a piece open makes the tray craft rather than sell")
	_check(inventory.gold == price + orb_price, "and nothing was paid for the orb it spent")

	# A board is a counter for work, not for goods: nothing is bought or sold over one.
	page.shop(PackedStringArray([TownServices.BOUNTIES]), TOWN_CELL)
	page._select_item(0)
	_check(_deep_button(page._detail, "Discard") != null and _deep_button(page._detail, "Sell") == null,
			"over a bounty board a piece is thrown away rather than sold")
	page._select_item(-1)
	var carried := inventory.orb_count("Orb of Chaos")
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == carried, "and the board buys no orbs either")

	# Leaving the town puts every one of those back.
	page.shop(PackedStringArray())
	page._select_item(0)
	_check(_deep_button(page._detail, "Discard") != null and _deep_button(page._detail, "Sell") == null,
			"outside a town Discard is Discard again")
	page.queue_free()
	await process_frame


## The other half of a counter: the shelf on the town page. What it costs, what it refuses, and what
## a purchase moves.
func _test_buying() -> void:
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
	page._on_shelf_input(_press(), 0)
	_check(page._offer != null and page._offer.type == offered.type, "pressing a square opens the piece")
	var price := TownPrices.buy_price(offered)
	_check(price > TownPrices.sell_price(offered),
			"a vendor asks more than it pays (%d over %d)" % [price, TownPrices.sell_price(offered)])
	var buy := _button(page._rows, "Buy")
	_check(buy != null and buy.text == "Buy %d" % price, "the button carries the price (%s)"
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
	_check(block != null and buy != null and buy.get_index() > block.get_index(),
			"with the Buy button pinned under them")

	# A short purse buys nothing, and the button says so rather than letting the press through.
	_check(buy != null and buy.disabled, "with an empty purse the button is dead")
	if buy != null:
		buy.pressed.emit()
	page._on_buy_item()
	_check(inventory.gold == 0 and inventory.total() == 0, "and nothing moved")
	_check(VendorStock.items(drawer)[0] != null, "the piece is still on the shelf")

	# Nor does a full bag: `Inventory.add` would destroy the worst piece in it to make room.
	inventory.gold = price * 4
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	while not inventory.is_full():
		inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 1))
	page._fill()
	buy = _button(page._rows, "Buy")
	_check(buy != null and buy.disabled, "a full bag kills the button too")
	page._on_buy_item()
	_check(inventory.total() == Inventory.CAPACITY and inventory.gold == price * 4,
			"and buying into one changes nothing")

	# Room and gold both: the piece crosses, the purse pays and the square empties.
	inventory.remove(inventory.items[0])
	page._fill()
	buy = _button(page._rows, "Buy")
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
	page._on_buy_orb(orb, 0)
	_check(inventory.orb_count(orb) == 0 and not VendorStock.orbs(drawer)[0].is_empty(),
			"a short purse buys no orb either")
	inventory.gold = orb_price
	page._on_buy_orb(orb, 0)
	_check(inventory.orb_count(orb) == 1 and inventory.gold == 0,
			"paid for one orb (%d held, %d left)" % [inventory.orb_count(orb), inventory.gold])
	_check(VendorStock.orbs(drawer)[0].is_empty(), "and its square is empty")
	_check(TownPrices.orb_sell_price(orb, TOWN_CELL) < orb_price,
			"what it sells back for is less than it cost")
	page.queue_free()
	await process_frame


## The smith's counter on the page: which settlements have one, that it acts on the piece the bag has
## open and on nothing else, and what a press moves.
func _test_smithing() -> void:
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

	# A piece held up to him: both prices on their buttons, and a purse that cannot cover either.
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3)
	inventory.add(piece)
	page.bag_changed(piece)
	_check(page._upgrade_cap() == MapBuilder.level_of(TOWN_CELL)
			+ int(LootTable.TIER_LEVEL[EnemyRoster.Tier.BOSS]),
			"the cap is what a boss on this ground could drop (%d)" % page._upgrade_cap())
	var price := TownPrices.upgrade_price(piece)
	var upgrade := _button(page._rows, "Upgrade")
	var lock := _button(page._rows, "Lock")
	_check(upgrade != null and upgrade.text == "Upgrade %d" % price,
			"the hammer carries its price (%s)" % [upgrade.text if upgrade != null else "no button"])
	_check(lock != null and lock.text == "Lock %d" % TownPrices.lock_price(piece),
			"and so does the lock (%s)" % [lock.text if lock != null else "no button"])
	_check(upgrade != null and upgrade.disabled and lock != null and lock.disabled,
			"an empty purse kills both")
	page._on_upgrade_pressed()
	page._on_lock_pressed()
	_check(piece.level == 3 and piece.locked_mod().is_empty() and inventory.gold == 0,
			"and nothing was done on the way past the button")

	# With the gold, the hammer lands: the piece moves, the purse pays and the save is written.
	inventory.gold = price * 3
	page._smith_rng = _stream_that(false)
	page._fill()
	upgrade = _button(page._rows, "Upgrade")
	_check(upgrade != null and not upgrade.disabled, "with the gold the hammer is live")
	page._on_upgrade_pressed()
	_check(piece.level == 4, "the piece came back a level higher (%d)" % piece.level)
	_check(inventory.gold == price * 2, "the purse paid (%d, want %d)" % [inventory.gold, price * 2])
	_check(Inventory.load_from(TEST_PATH).items[0].level == 4, "and the upgrade was saved")

	# A break spends the gold all the same, says so on the page, and greys everything after it. The
	# purse is filled again first: a level up is a dearer hammer, which is the point of the curve.
	var broke_price := TownPrices.upgrade_price(piece)
	_check(broke_price > price, "the next level costs more (%d over %d)" % [broke_price, price])
	inventory.gold = broke_price * 2
	var before_break := inventory.gold
	page._smith_rng = _stream_that(true)
	page._on_upgrade_pressed()
	_check(piece.broken and piece.level == 4, "the hammer broke it and left the level alone")
	_check(inventory.gold == before_break - broke_price,
			"and the gold went anyway (%d, want %d)" % [inventory.gold, before_break - broke_price])
	_check(not page._smith_note.is_empty(), "the page says what happened (%s)" % page._smith_note)
	_check(_button(page._rows, "Upgrade").disabled and _button(page._rows, "Lock").disabled,
			"and both of the smith's buttons are dead")
	_check(Inventory.load_from(TEST_PATH).items[0].broken, "the break was saved")

	# He works out of the bag: a worn piece is refused however good the purse is.
	var worn := Item.rolled("Leather Helmet", ItemRarity.Rarity.RARE, rng, 3)
	inventory.add(worn)
	inventory.equip(worn, Equipment.Socket.HELMET)
	inventory.gold = TownPrices.lock_price(worn) * 2
	page.bag_changed(worn)
	_check(page._smith_note.is_empty(), "a new piece clears what the hammer did to the last one")
	_check(_button(page._rows, "Upgrade").disabled and _button(page._rows, "Lock").disabled,
			"a worn piece is not the smith's to work on")
	page._on_lock_pressed()
	_check(worn.locked_mod().is_empty(), "and nothing was pinned to it")

	# In the bag, with the gold: one modifier pinned, and a second lock refused.
	inventory.unequip(Equipment.Socket.HELMET)
	page.bag_changed(worn)
	lock = _button(page._rows, "Lock")
	_check(lock != null and not lock.disabled, "off his back it is his to work on")
	var lock_price := TownPrices.lock_price(worn)
	var purse := inventory.gold
	page._on_lock_pressed()
	_check(not worn.locked_mod().is_empty(), "a modifier is pinned")
	_check(inventory.gold == purse - lock_price, "the purse paid the lock (%d, want %d)"
			% [inventory.gold, purse - lock_price])
	_check(_button(page._rows, "Lock").disabled, "and the button is dead for a second one")
	var saved: Item = Inventory.load_from(TEST_PATH).items.back()
	_check(saved != null and not saved.locked_mod().is_empty(), "the lock was saved with the piece")
	page.queue_free()
	await process_frame


## The board on the page: the tab a town opens on, reading it being what takes the work on, and the
## Claim that pays for it -- once, and only for a posting that is finished.
func _test_board() -> void:
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

	# Worked off, and handed in: the purse, the orb and the save all move once.
	var reward := int(bounty[BountyBoard.GOLD])
	var orb := str(bounty[BountyBoard.ORB])
	_check(not orb.is_empty(), "the elite posting carries an orb (%s)" % orb)
	BountyBoard.count_kill(inventory.towns, str(bounty[BountyBoard.ENEMY]),
			int(bounty[BountyBoard.NEED]))
	page._fill()
	var claim := _deep_button(page._rows, "Claim")
	_check(claim != null and claim.text == "Claim %d" % reward,
			"the finished one carries its reward (%s)" % [claim.text if claim != null else "no button"])
	if claim != null:
		claim.pressed.emit()
	_check(inventory.gold == reward and reward > 0,
			"the purse holds the reward (%d, want %d)" % [inventory.gold, reward])
	_check(inventory.orb_count(orb) == 1, "and the orb came with it")
	_check(Inventory.load_from(TEST_PATH).gold == reward, "the hand-in was saved")
	_check(_deep_button(page._rows, "Claim") == null, "the posting is off the board")
	page._on_claim_pressed(bounty)
	_check(inventory.gold == reward and inventory.orb_count(orb) == 1, "and pays nothing a second time")
	page.queue_free()
	await process_frame


## A left click, for the squares that are worked out from a press rather than pressed themselves.
func _press() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event


## The whole thing in the scene: standing on a town, going in, and coming back out.
func _test_entering() -> void:
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

	var town: Vector2i = main.view.start_town - main.view.origin
	_check(main.view.town_tier(town) == TownWorld.Tier.SMALL, "the start town is a village")
	_check(main.view.town_tier(MapBuilder.CENTER) == -1, "and the middle of the map is not a town")
	_check(not main._bounty_button.visible, "no journal in the corner before a board has been read")

	# Where a monster lives is only ever somewhere the player has been shown: never a cell still under
	# the fog, and a charted one before a merely seen one at the same distance, because a charted tile
	# can be farmed where a seen one is only somewhere to head for. Measured from where the player
	# stands, which at the start is the middle of the map. Two neighbours of the start are given land
	# of their own for it, and given it back afterwards.
	var ring := HexGrid.neighbors(MapBuilder.CENTER)
	var was := [main.view._envs[ring[0]], main.view._envs[ring[1]]]
	var made_up := PackedStringArray(["bounty_test_land"])
	main.view._envs[ring[0]] = made_up[0]
	main.view._envs[ring[1]] = made_up[0]
	main.view._states[ring[1]] = MapBuilder.State.CHARTED
	_check(main.view.nearest_env(made_up) == ring[1],
			"a charted tile is offered before a seen one the same distance out")
	main.view._states[ring[1]] = MapBuilder.State.UNCHARTED
	_check(main.view.nearest_env(made_up) in ring,
			"a seen tile is offered when no charted one has that land")
	main.view._states.erase(ring[0])
	main.view._states.erase(ring[1])
	_check(main.view.nearest_env(made_up) == HexMap.NO_CELL,
			"and land nobody has laid eyes on is never offered")
	main.view._envs[ring[0]] = was[0]
	main.view._envs[ring[1]] = was[1]
	main.view._states[ring[0]] = MapBuilder.State.UNCHARTED
	main.view._states[ring[1]] = MapBuilder.State.UNCHARTED
	_check(main.view.envs_within(MapBuilder.CENTER, BountyBoard.BOUNTY_RANGE).size() > 0,
			"there is land around the middle of the map to post monsters from")

	main.view.reveal_all()
	main.map.select_cell(town)
	_check(not main.view.can_visit(town), "a town the player is not standing on cannot be entered")
	_check(not main._town_button.visible, "so there is no button for it")

	# Stood on, which with charted is the whole of what a visit takes.
	main.view.player_cell = town
	main.map.set_player_cell(town)
	main.map.select_cell(town)
	main._update_buttons()
	_check(main.view.can_visit(town), "standing on a charted town, it can be entered")
	_check(main._town_button.visible, "and the button is there")
	var marks: Node = main._service_rows.get_child(main._service_rows.get_child_count() - 1)
	_check(marks.get_child_count() > 0, "the tile panel shows a mark for what is traded here")
	for mark: Control in marks.get_children():
		_check(mark.tooltip_text != "", "and each mark says what it is when pointed at")

	# A settlement is never where a monster lives, not even the one the player is standing in: the
	# board would otherwise answer "where does it live" with the ground under their own feet. The town
	# and the middle of the map are given one made-up land between them, and the middle has to win.
	var town_was: String = main.view._envs[town]
	var mid_was: String = main.view._envs[MapBuilder.CENTER]
	main.view._envs[town] = made_up[0]
	main.view._envs[MapBuilder.CENTER] = made_up[0]
	_check(main.view.nearest_env(made_up, MapBuilder.level_of(MapBuilder.CENTER) + 1) == HexMap.NO_CELL,
			"land shallower than the bounty asks for is never pointed at")
	_check(main.view.nearest_env(made_up) == MapBuilder.CENTER,
			"a settlement is never offered as where a monster lives, the one underfoot least of all")
	main.view._envs[town] = town_was
	main.view._envs[MapBuilder.CENTER] = mid_was

	# Standing on a charted settlement is what the first tip about towns waits for, and reading its
	# board is what the second one waits for.
	_check(main._tip_due("first_town"), "standing on a charted town, the tip about towns is due")
	_check(not main._tip_due("first_bounty"), "and the one about the board is not, unread")

	main._on_town_pressed()
	await process_frame
	_check(main._tip_due("first_bounty"), "drawing the board is reading it, so that tip comes due")
	_check("first_town" in main.inventory.tips and "first_bounty" in main.inventory.tips,
			"both are marked seen once they are shown")
	_check(Inventory.load_from(TEST_PATH).tips.has("first_bounty"), "and written down")
	while main._tip_panel != null:
		main._on_tip_closed()
	await process_frame
	_check(main.town_page.visible, "the town page is up")
	_check(not main._panel.visible, "in the tile panel's place")
	_check(main.bag_page.visible, "with the bag beside it")
	_check(main.inventory.towns.visited(main.view.origin + town), "and the town is in the save")
	var services := TownServices.services_for(TownWorld.Tier.SMALL, main.view.origin + town,
			main.towns.seed_value)
	var vendor := TownServices.GEAR if TownServices.GEAR in services else TownServices.ORBS
	_check(main.town_page.open_tab() == TownServices.BOUNTIES,
			"a town opens on its board, the counter every settlement has (%s)" % [services])
	_check(not main.bag_page._buys(vendor), "over which the bag sells nothing")
	_check(BountyBoard.bounties(main.inventory.towns.visit(main.view.origin + town)).size()
			== BountyBoard.COMMONS + BountyBoard.ELITES, "and the board has its three postings")
	main.town_page._on_tab_pressed(vendor)
	_check(main.bag_page._buys(vendor), "at the village's one vendor the bag is standing at the counter")
	_check(not main.bag_page._worn_panel.visible, "the doll gives its room to the page")
	# The map is still clickable behind the page, and the tile panel shares that edge with it.
	main.map.select_cell(MapBuilder.CENTER)
	_check(not main._panel.visible, "clicking the map does not put the tile panel over the town")
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
	main._update_buttons()
	main._on_town_pressed()
	await process_frame
	main.town_page.closed.emit()
	await process_frame
	_check(not main.town_page.visible and not main.bag_page.visible, "the X closes both")
	_check(main._panel.visible, "and the tile panel has its edge back")
	_check(not main.bag_page._buys(TownServices.GEAR) and not main.bag_page._buys(TownServices.ORBS),
			"the bag is not a shop any more")

	# The journal: a corner button of its own once a board has been read, listing the same postings
	# away from the town, and a Show that puts the map on the land the monster lives on.
	_check(main._bounty_button.visible, "the journal is in the corner once a board has been read")
	# Accepting is pressing the board's own button, and it shuts the rest until that one is handed in.
	main._on_town_pressed()
	main.town_page._on_tab_pressed(TownServices.BOUNTIES)
	await process_frame
	var accept :=_deep_button(main.town_page._rows, "Accept")
	_check(accept != null and not accept.disabled, "a posting on the board can be accepted")
	if accept != null:
		accept.pressed.emit()
	await process_frame
	_check(not BountyBoard.active(main.inventory.towns).is_empty(), "which takes it on")
	_check(not BountyBoard.active(Inventory.load_from(TEST_PATH).towns).is_empty(), "and is saved")
	_check(_deep_button(main.town_page._rows, "Accept") == null,
			"and the others leave the board until it is handed in")
	main.town_page.closed.emit()
	await process_frame
	main._on_bounty_pressed()
	await process_frame
	_check(main.bounty_page.visible, "and it opens the bounty page")
	var shown := _deep_button(main.bounty_page, "Show")
	_check(shown != null, "which says where to find what is wanted")
	if shown != null:
		shown.pressed.emit()
		await process_frame
	_check(not main.bounty_page.visible, "Show puts the page away")
	_check(main.view.seen(main.map.selected_cell), "and selects a tile the player has seen")
	_check(main._panel.visible, "with the tile panel on it, which is where the walking is done from")
	main.queue_free()
	await process_frame


## The first Button under `parent` whose label starts with `text`, or null. The blocks are built fresh
## on every refresh, so a test finds its button rather than holding one.
func _button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text.begins_with(text):
			return child
	return null


## The same, anywhere under `parent`: a board's rows sit in a scroll inside a box inside the page.
func _deep_button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text.begins_with(text):
			return child
		var found := _deep_button(child, text)
		if found != null:
			return found
	return null
