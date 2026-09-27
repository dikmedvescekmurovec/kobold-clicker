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
	_check(_test_fortune() == true, "fortuneteller tests ran to the end")
	await _test_selling()
	await _test_buying()
	await _test_orb_on_a_shelf()
	await _test_smithing()
	await _test_board()
	await _test_entering()
	await _test_fortune_page()
	await _test_curses_the_world_feels()
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
			_check(village.size() == 3 and TownServices.FORTUNE in village,
					"%s has a board, one vendor and a fortuneteller (%s)" % [spot, village])
			var vendor := TownServices.GEAR if TownServices.GEAR in village else TownServices.ORBS
			_check(vendor in village, "%s names its one vendor" % spot)
			vendors[vendor] += 1
			# Seed-stable: nothing is written down, so walking back has to find the same counter.
			_check(village == TownServices.services_for(TownWorld.Tier.SMALL, spot, WORLD_SEED),
					"%s offers the same village twice" % spot)
	_check(vendors[TownServices.GEAR] > 0 and vendors[TownServices.ORBS] > 0,
			"both vendors turn up across the world (%s)" % [vendors])

	var town := TownServices.services_for(TownWorld.Tier.MEDIUM, Vector2i(3, 4), WORLD_SEED)
	_check(town.size() == 4 and TownServices.GEAR in town and TownServices.ORBS in town
			and TownServices.FORTUNE in town and not (TownServices.SMITH in town),
			"a town has both vendors, a fortuneteller and no smith (%s)" % town)
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
	_check(TownPrices.reroll_price(TOWN_CELL, 5) > first_price * 30, "and the sixth thirty times")
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
		# And is made of something its own level has unlocked: a vendor hands its level to the draw,
		# so no counter deals a material the ground under it could not.
		var row: Dictionary = LootTable.ITEMS[piece.type]
		var levels: Array = LootTable.KINDS[row["kind"]].get("tier_levels", LootTable.TIER_MIN_LEVEL)
		_check(piece.level >= int(levels[int(row["tier"])]),
				"a level-%d %s is under the level its material needs (%d)"
						% [piece.level, piece.type, levels[row["tier"]]])
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

	# An upgrade is exactly a fresh roll at the new level: the base stats, and the modifiers' numbers
	# rerolled in their bands at that level. Only the lines themselves stay.
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3)
	var mods_before := piece.mods.duplicate(true)
	_check(Blacksmith.can_upgrade(piece, cap), "a piece under the cap can be upgraded")
	_check(Blacksmith.why_not_upgrade(piece, cap).is_empty(), "and nothing is said against it")
	_check(Blacksmith.upgrade(piece, cap, safe), "the hammer lands")
	_check(piece.level == 4, "the piece is a level higher (%d)" % piece.level)
	_check(piece.stats == Item.scaled_stats("Wooden Sword", 4),
			"with exactly the base stats a fresh roll at that level would carry")
	var ids_before := mods_before.map(func(mod: Dictionary) -> String: return str(mod["id"]))
	var ids_after := piece.mods.map(func(mod: Dictionary) -> String: return str(mod["id"]))
	_check(ids_after == ids_before, "carrying the modifiers it already had")
	for mod: Dictionary in piece.mods:
		var band := ModifierTable.band_for(str(mod["id"]), piece.tier_of(mod))
		_check(int(mod["value"]) >= int(band[0]) and int(mod["value"]) <= int(band[1]),
				"%s rerolled inside its band at the new level (%d in %d-%d)"
				% [mod["id"], int(mod["value"]), int(band[0]), int(band[1])])
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

	# An heirloom out of a world that has ended is walked back up to the level it had for nothing but
	# gold: the doomed stream, which breaks anything else on its first blow, never touches it.
	var heirloom := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 6)
	heirloom.transcend()
	_check(heirloom.level == 1 and heirloom.safe_level == 6, "an heirloom comes back at level 1, remembering 6")
	_check(Blacksmith.break_chance(heirloom) == 0.0, "and under that the hammer cannot break it")
	for level in range(2, 7):
		doomed.seed = doomed.seed
		_check(Blacksmith.upgrade(heirloom, 99, doomed) and heirloom.level == level,
				"level %d lands whatever the draw" % level)
	_check(not heirloom.broken and heirloom.stats == Item.scaled_stats("Wooden Sword", 6),
			"whole, and worth what a fresh level 6 is")
	_check(Blacksmith.break_chance(heirloom) == Blacksmith.BREAK_CHANCE, "past it the hammer is the hammer")
	doomed = _stream_that(true)
	_check(not Blacksmith.upgrade(heirloom, 99, doomed) and heirloom.broken and heirloom.level == 6,
			"and the blow past it can break it")
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
		_check(need == (BountyBoard.NEED_ELITE if tier == EnemyRoster.Tier.ELITE
				else BountyBoard.NEED_COMMON), "%s asks for its tier's count (%d)" % [enemy, need])
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
	# The ascension ladder: at least +1 a quarter of the time, +2 a twentieth, and a tenth as often past
	# the list, for ever.
	_check(BountyBoard.plus_of(0.3) == 0 and BountyBoard.plus_of(0.2) == 1 and BountyBoard.plus_of(0.04) == 2
			and BountyBoard.plus_of(0.005) == 3 and BountyBoard.plus_of(0.0005) == 4
			and BountyBoard.plus_of(0.00005) == 5 and BountyBoard.plus_of(0.000005) == 6,
			"a promised piece climbs the ascension ladder")
	_check(BountyBoard.plus_of(0.0) > 6, "and a draw of nothing still ends (%d)" % BountyBoard.plus_of(0.0))
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
			== "an elite sword +1" and BountyBoard.reward_text({BountyBoard.ITEM:
			{"kind": "", "rarity": "unique", "plus": 0}}) == "a unique piece"
			and BountyBoard.reward_text({}).is_empty(), "and the promise is put into words")
	# The piece itself, rolled at the hand-in, is what was promised and no more.
	var sworn := {BountyBoard.ENEMY: "Imp", BountyBoard.ITEM: {"kind": "sword", "rarity": "elite", "plus": 1}}
	var paid := BountyBoard.reward_item(sworn, TOWN_CELL, rng)
	_check(paid != null and str(LootTable.ITEMS[paid.type]["kind"]) == "sword"
			and paid.rarity == ItemRarity.Rarity.ELITE and paid.plus == 1 and paid.unique.is_empty()
			and paid.level >= 1 and paid.level <= MapBuilder.level_of(TOWN_CELL) + 1,
			"an elite sword +1 is what the hand-in pays (%s)" % [paid.display_name() if paid else "nothing"])
	sworn[BountyBoard.ITEM] = {"kind": "", "rarity": "unique", "plus": 0}
	paid = BountyBoard.reward_item(sworn, TOWN_CELL, rng)
	_check(paid != null and not paid.unique.is_empty() and paid.rarity == ItemRarity.Rarity.UNIQUE
			and paid.plus == 0, "a unique promised is a unique paid (%s)" % [paid.display_name() if paid else "nothing"])
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

	# What each ledger says of its bodies, gathered in an Array: a lambda captures by value.
	var said := []
	var hear := func(ledger: FightLedger) -> void:
		ledger.bounty_counted.connect(func(enemy: String, have: int, need: int) -> void:
			said.append([enemy, have, need]))
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
	shallow_run.bank()
	_check(_have(drawer, 0) == 1, "and neither does a run's")
	_check(said.size() == 1, "and neither is said (%s)" % [said])

	var run := FightLedger.new(inventory, TEST_PATH, true)
	hear.call(run)
	run.tile_level = 5
	for i in 3:
		run.add_kill(target)
	_check(_have(drawer, 0) == 1, "a run's bodies wait in its pouch (%d)" % _have(drawer, 0))
	_check(said.slice(1) == [[target, 2, 5], [target, 3, 5], [target, 4, 5]],
			"but each is said as it falls, counted on top of the board's (%s)" % [said])
	_check(run.bank(), "the run banks")
	_check(_have(drawer, 0) == 4, "and they all count at once (%d)" % _have(drawer, 0))
	_check(said.size() == 4, "banking says nothing over again (%s)" % [said])
	_check(not run.bank(), "a second bank has nothing to do")
	_check(_have(drawer, 0) == 4, "and counts nothing twice (%d)" % _have(drawer, 0))
	_check(_have(Inventory.load_from(TEST_PATH).towns.visit(spot), 0) == 4, "the run's kills were saved")

	# The body that fills the job is said with `have == need`; one past it is nothing to say.
	var last := FightLedger.new(inventory, TEST_PATH, true)
	hear.call(last)
	last.tile_level = 5
	last.add_kill(target)
	last.add_kill(target)
	_check(said.slice(4) == [[target, 5, 5]], "the filling body is said and the one past it is not (%s)" % [said])
	last.bank()
	_check(_have(drawer, 0) == 5, "and the board stops at the job (%d)" % _have(drawer, 0))
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
	_check(_deep_button(page._actions, "Discard") != null, "outside a town a piece is discarded")
	_check(_deep_button(page._actions, "Sell") == null, "and there is nothing to sell it to")
	_check(page._sections.get_child(0).get_children().any(func(child: Node) -> bool:
			return child is Button and (child as Button).tooltip_text.begins_with("Throw away the")),
			"and a level is cleared")

	# At the gear merchant the same two buttons buy instead.
	page.shop(PackedStringArray([TownServices.GEAR]))
	page._select_item(inventory.items.find(piece))
	var sell := _deep_button(page._actions, "Sell")
	_check(sell != null and _deep_button(page._actions, "Discard") == null,
			"at the merchant the piece is sold rather than thrown away")
	_check(page._sections.get_child(0).get_children().any(func(child: Node) -> bool:
			return child is Button and (child as Button).tooltip_text.begins_with("Sell the")),
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
	page.refresh()

	# Sell all takes the ordinary pieces over the counter and asks about a unique among them on its
	# own; Sell on that question sells it for its own price.
	var relic := Item.rolled_unique(UniqueTable.ids()[0], rng, 4)
	inventory.add(relic)
	page.refresh()
	await process_frame
	for button: Button in page._sections.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with("Sell the"):
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

	# With a piece open the tray is the crafting tray it has always been, vendor or not.
	page._select_item(0)
	var in_hand := inventory.orb_count("Orb of Chaos")
	page._on_orb_pressed("Orb of Chaos")
	_check(inventory.orb_count("Orb of Chaos") == in_hand - 1,
			"a piece open makes the tray craft rather than sell")
	_check(inventory.gold == price, "and nothing was paid for the orb it spent")

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


## An orb in the bag's hand, spent on a piece still on the shelf: the two pages wired as the main
## scene wires them. The piece is changed where it stands, written into the town's drawer, and priced
## as what it has become; nothing is opened and nothing is bought.
func _test_orb_on_a_shelf() -> void:
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
	# A rare is past what it makes: a press there costs nothing and still opens nothing.
	VendorStock.put(drawer, 0, Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3))
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
	_check(buy != null and buy.text == "Buy" and UITheme.price_of(buy) == "%d" % price, "the button carries the price (%s)"
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
		inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 1))
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
	page._on_buy_orb(orb, 0)
	_check(inventory.orb_count(orb) == 0 and not VendorStock.orbs(drawer)[0].is_empty(),
			"a short purse buys no orb either")
	inventory.gold = orb_price
	page._on_buy_orb(orb, 0)
	_check(inventory.orb_count(orb) == 1 and inventory.gold == 0,
			"paid for one orb (%d held, %d left)" % [inventory.orb_count(orb), inventory.gold])
	_check(VendorStock.orbs(drawer)[0].is_empty(), "and its square is empty")

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
	_check(upgrade != null and upgrade.text == "Upgrade" and UITheme.price_of(upgrade) == "%d" % price,
			"the hammer carries its price (%s)" % [upgrade.text if upgrade != null else "no button"])
	_check(lock != null and lock.text == "Lock" and UITheme.price_of(lock) == "%d" % TownPrices.lock_price(piece),
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

	# Carried or worn is all one to him: a piece is locked without being stripped off first -- one
	# modifier pinned, and a second lock refused.
	var worn := Item.rolled("Leather Helmet", ItemRarity.Rarity.RARE, rng, 3)
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
	_check(_button(page._rows, "Lock").disabled, "and the button is dead for a second one")
	var saved: Item = Inventory.load_from(TEST_PATH).equipment.item_at(Equipment.Socket.HELMET)
	_check(saved != null and not saved.locked_mod().is_empty(),
			"the lock was saved with the worn piece")
	# And the hammer reaches one on the doll too.
	inventory.gold = TownPrices.upgrade_price(worn) * 2
	page._smith_rng = _stream_that(false)
	page._fill()
	page._on_upgrade_pressed()
	_check(worn.level == 4, "a worn piece came back a level higher (%d)" % worn.level)
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
	_check(claim != null and claim.disabled and claim.tooltip_text == "Your bag is full.",
			"a promised piece cannot be claimed into a full bag (%s)" % [claim.tooltip_text if claim else "no button"])
	page._on_claim_pressed(bounty)
	_check(inventory.gold == 0 and not bool(bounty[BountyBoard.DONE]), "and a press pays nothing")
	inventory.items.clear()
	page._fill()
	claim = _deep_button(page._rows, "Claim")
	_check(claim != null and not claim.disabled and claim.tooltip_text.contains(str(reward))
			and claim.tooltip_text.ends_with("and an elite sword +1"),
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
			"and so did the elite sword +1 (%s)" % [inventory.items[0].display_name() if inventory.items.size() == 1 else inventory.items.size()])
	_check(Inventory.load_from(TEST_PATH).items.size() == 1, "which was saved with the hand-in")
	_check(Inventory.load_from(TEST_PATH).gold == reward, "the hand-in was saved")
	_check(_deep_button(page._rows, "Claim") == null, "the posting is off the board")
	page._on_claim_pressed(bounty)
	_check(inventory.gold == reward and orbs.all(func(orb: String) -> bool:
			return inventory.orb_count(orb) == orbs.count(orb)), "and pays nothing a second time")
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
	# A heading, then a row per counter: its mark and its name.
	var rows: Array[Node] = main._service_rows.get_children().slice(1)
	_check(rows.size() > 0, "the tile panel shows a row for what is traded here")
	for row: Node in rows:
		_check(row.get_child(0) is TextureRect and (row.get_child(1) as Label).text != "",
				"and each row names its counter beside its mark")
	_check(main._level_label.text.begins_with(main.SETTLEMENT_KINDS[main.view.town_tier(town)] + " · "),
			"and the line under the name says what kind of place it is (%s)" % main._level_label.text)

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
	var others: Array = main.town_page._rows.find_children("", "Button", true, false).filter(
			func(b: Button) -> bool: return b.text == "Accept")
	_check(not others.is_empty() and others.all(func(b: Button) -> bool: return b.disabled),
			"and the others stay on the board, refused until it is handed in")
	main.town_page.closed.emit()
	await process_frame
	main._on_bounty_pressed()
	await process_frame
	_check(main.bounty_page.visible, "and it opens the bounty page")
	# Where it lives is a fortuneteller's to sell: until she is paid the journal has no Show, and once
	# she is, the board opens on the card with the land on it and the journal can point at it.
	_check(_deep_button(main.bounty_page, "Show") == null, "which does not say where it lives for nothing")
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
	await process_frame
	_check(not _dead(main, FortuneTeller.QUARRY), "the fortuneteller will say where a bounty's monster lives")
	_ask(main, FortuneTeller.QUARRY)
	await process_frame
	_check(BountyBoard.located(BountyBoard.active(main.inventory.towns)), "which is written on the posting")
	_check(BountyBoard.located(BountyBoard.active(Inventory.load_from(TEST_PATH).towns)), "and saved")
	_check(main.inventory.gold < 1.0e9, "and paid for")
	var quarry: String = BountyBoard.active(main.inventory.towns)[BountyBoard.ENEMY]
	_check(main.town_page.open_tab() == TownServices.FORTUNE and main.town_page._told != null
			and _said(main.town_page._told).contains(quarry), "and told in a popup, over her own counter")
	main.town_page._close_told()
	await process_frame
	_check(_dead(main, FortuneTeller.QUARRY), "and is not sold twice")
	main.town_page.closed.emit()
	await process_frame
	main._on_bounty_pressed()
	await process_frame
	var shown := _deep_button(main.bounty_page, "Show")
	_check(shown != null, "after which the journal says where to find what is wanted")
	if shown != null:
		shown.pressed.emit()
		await process_frame
	_check(not main.bounty_page.visible, "Show puts the page away")
	_check(main.view.seen(main.map.selected_cell), "and selects a tile the player has seen")
	_check(main._panel.visible, "with the tile panel on it, which is where the walking is done from")
	main.queue_free()
	await process_frame


## The fortuneteller's rules, with no interface: the peek, the odds, the prices and the patch a scour takes.
func _test_fortune() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var found := [UniqueTable.ids()[0]]
	var shown := []
	for i in UniqueTable.ids().size() - 1:
		var id := FortuneTeller.peek(found, shown, rng)
		_check(not id.is_empty() and not (id in found) and not (id in shown),
				"a peek is a unique neither found nor shown (%s)" % id)
		shown.append(id)
	_check(FortuneTeller.peek(found, shown, rng).is_empty(), "and there is none left when all are known")

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
	_check(ModifierTable.band_line("increased_damage", 1) == "+8-20% increased Damage",
			"a band is written the way its modifier is (%s)" % ModifierTable.band_line("increased_damage", 1))
	_check(ModifierTable.line({"id": "added_fight_clock", "value": 30}) == "+3.0s Fight Clock",
			"and a rolled line still reads as it did")
	var relic := Item.rolled_unique(UniqueTable.ids()[0], rng)
	_check(FortuneTeller.odds(relic).is_empty() and FortuneTeller.why_not_appraise(relic) == FortuneTeller.WRITTEN,
			"a unique's lines are its own, so there is nothing to read")
	_check(not FortuneTeller.why_not_appraise(null).is_empty(), "and nothing to read with no piece open")

	# Her list is in two halves and every spell is in exactly one of them -- the lists are written out
	# separately, so this is what holds them together.
	var halves := (FortuneTeller.COMMON + FortuneTeller.GREAT + [FortuneTeller.STONE, FortuneTeller.TRANSCEND]).duplicate()
	halves.sort()
	var every := FortuneTeller.READINGS.duplicate()
	every.sort()
	_check(halves == every, "every spell is a reading or a great spell and never both (%s)" % [halves])

	# The stone's hot and cold: its bands, coldest first, by the steps to the cave.
	var bands := []
	for steps in [0, 2, 3, 5, 6, 10, 11, 16, 17, 60]:
		bands.append(FortuneTeller.warmth(steps))
	_check(bands == [4, 4, 3, 3, 2, 2, 1, 1, 0, 0], "the stone burns within two steps and is cold past sixteen (%s)" % [bands])

	for reading: String in FortuneTeller.READINGS:
		_check(TownPrices.FORTUNE_BODIES.has(reading) and FortuneTeller.LABELS.has(reading),
				"%s has a price and a name" % reading)
		# The way out and the stone are priced on the ground behind the first wall, wherever they are asked for.
		if reading == FortuneTeller.TRANSCEND or reading == FortuneTeller.STONE:
			_check(TownPrices.fortune_price(reading, TOWN_CELL) == TownPrices.fortune_price(reading, Vector2i(1, 0)),
					"%s costs the same in every town" % reading)
			_check(TownPrices.fortune_price(reading, TOWN_CELL) == roundf(TownPrices.FORTUNE_BODIES[reading]
					* Encounter.gold_at_steps(MapBuilder.START_LAND_RADIUS + 2)),
					"and is bodies on the second ring of the land behind the first wall")
			continue
		_check(TownPrices.fortune_price(reading, TOWN_CELL) > TownPrices.fortune_price(reading, Vector2i(1, 0)),
				"%s is dearer in a deeper town" % reading)
		# And dearer again every time it has been asked for, whichever half it is in: what stops a
		# reading being asked for ever is the price, and `fortune_price` is the one place that knows.
		_check(TownPrices.fortune_price(reading, TOWN_CELL, 3) == roundf(TownPrices.fortune_price(reading,
				TOWN_CELL) * pow(TownPrices.FORTUNE_GROWTH, 3)),
				"%s doubles with every casting" % reading)
	_check(TownPrices.fortune_price("retired_reading", TOWN_CELL) == 0.0, "a reading this build lacks costs nothing")

	var patch := FortuneTeller.scour_cells(Vector2i(3, 3))
	_check(patch.size() == 19 and Vector2i(3, 3) in patch, "a scour takes nineteen tiles round the one chosen")

	# What she sold the player is saved with the player, and comes back as it was written.
	var inventory := Inventory.new()
	inventory.fortunes[FortuneTeller.CHEST] = [12, 34]
	inventory.fortunes[FortuneTeller.PEEKED] = ["rimeplate"]
	FortuneTeller.note_cast(inventory.fortunes, FortuneTeller.RELIC)
	FortuneTeller.note_cast(inventory.fortunes, FortuneTeller.RELIC)
	inventory.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(FortuneTeller.chest(back.fortunes) == Vector2i(12, 34)
			and FortuneTeller.cast(back.fortunes, FortuneTeller.RELIC) == 2
			and FortuneTeller.peeked(back.fortunes) == ["rimeplate"], "what she sold survives the save (%s)" % [back.fortunes])
	_check(FortuneTeller.chest({}) == TownWorld.NO_SPOT and FortuneTeller.cast({}, FortuneTeller.RELIC) == 0,
			"and a save that bought nothing has nothing")

	# A great spell is one a settlement, which is the drawer's key and not the player's count.
	var drawer := {}
	_check(not FortuneTeller.asked(drawer, FortuneTeller.SCOUR), "a town that has cast nothing is asked nothing")
	drawer[FortuneTeller.ASKED + FortuneTeller.SCOUR] = true
	_check(FortuneTeller.asked(drawer, FortuneTeller.SCOUR)
			and not FortuneTeller.asked(drawer, FortuneTeller.HOMECOMING),
			"and one spent here says nothing about the next")

	# Only work that is out can be asked about, and only once.
	var state := TownState.new()
	var posting := {BountyBoard.ENEMY: "Slime", BountyBoard.NEED: 3, BountyBoard.HAVE: 0}
	state.visit(Vector2i(1, 1))[BountyBoard.BOUNTIES] = [posting]
	_check(not BountyBoard.locate(posting), "a posting not taken on cannot be located")
	BountyBoard.accept(state, posting)
	_check(BountyBoard.locate(posting) and BountyBoard.located(posting), "an accepted one can")
	_check(not BountyBoard.locate(posting), "once")
	var kept := TownState.from_dict(state.to_dict())
	_check(BountyBoard.located(BountyBoard.active(kept)), "and it is saved with the town")
	return true


## Her table in a town, through the main scene: the roads, the star, a relic, a piece read, and the
## two great spells -- each paid for, written down, the readings dearer every time and the great
## spells refused in the town that has cast one.
func _test_fortune_page() -> void:
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
		# Her squares on the two grids; the way out is on neither while every wall still stands.
		if reading == FortuneTeller.TRANSCEND:
			_check(_spell(main, reading) == null, "the way out is not offered yet")
			continue
		if reading == FortuneTeller.STONE:
			_check(_spell(main, reading) == null, "nor the stone, with no cave in this world to feel for")
			continue
		_check(_spell(main, reading) != null, "she offers %s" % reading)
	_check(_dead(main, FortuneTeller.QUARRY), "no bounty is out, so there is none to find")
	_check(_dead(main, FortuneTeller.APPRAISE), "and no piece is open to read")

	# The roads: three sentences, and free in this town from then on.
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
	purse = main.inventory.gold
	_ask(main, FortuneTeller.ROADS)
	await process_frame
	_check(main.inventory.gold == purse, "and told again for nothing")
	_check(main.town_page._told == null and _said(main.town_page._rows).contains("You cast Roads"),
			"and, not to be shown again, said in one line (%s)" % _said(main.town_page._rows))
	_check(TownPage.SKIP_TOLD + FortuneTeller.ROADS in Inventory.load_from(TEST_PATH).tips, "and saved")

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
	main.view._states[chest] = MapBuilder.State.CHARTED
	main._sync_chest()
	_check(main._chest_pointer.target == HexMap.NO_CELL and FortuneTeller.chest(main.inventory.fortunes)
			== TownWorld.NO_SPOT, "an opened chest takes its star with it")
	main.town_page.redraw()
	await process_frame
	_check(not _dead(main, FortuneTeller.TREASURE), "and the star can be bought again")
	_check(_price(main, FortuneTeller.TREASURE) == TownPrices.fortune_price(FortuneTeller.TREASURE, town)
			* TownPrices.FORTUNE_GROWTH, "for double what the first one cost")

	# A relic: shown on her page, and on the log's card from then on.
	_ask(main, FortuneTeller.RELIC)
	await process_frame
	var peeked := FortuneTeller.peeked(main.inventory.fortunes)
	_check(peeked.size() == 1, "one relic is shown")
	var named: String = UniqueTable.UNIQUES[peeked[0]]["name"]
	_check(main.town_page._told == null and main._banner != null and _said(main._banner).contains(named),
			"by name, on the unique's banner rather than a popup (%s)" % named)
	_check(main._banner_closable and _deep_button(main._banner, "") != null, "with its X up at once")
	main._close_banner()
	await process_frame
	# A reading is sold as often as it is paid for, and every telling doubles the next one's price.
	_check(not _dead(main, FortuneTeller.RELIC), "a second relic can be asked for")
	_check(_price(main, FortuneTeller.RELIC) == TownPrices.fortune_price(FortuneTeller.RELIC, town)
			* TownPrices.FORTUNE_GROWTH, "at double the price")

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
			and _price(main, FortuneTeller.APPRAISE) == TownPrices.fortune_price(FortuneTeller.APPRAISE, town)
			* TownPrices.FORTUNE_GROWTH, "and the same piece is read again, dearer")
	main.town_page.bag_changed(null)
	await process_frame

	# The Seeing Stone: sold once this world has a cave, once and for good.
	main.inventory.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP
	main._credit_walls()
	main.town_page.redraw()
	await process_frame
	var stone_price := TownPrices.fortune_price(FortuneTeller.STONE, town)
	_check(_spell(main, FortuneTeller.STONE) != null and not _dead(main, FortuneTeller.STONE)
			and _price(main, FortuneTeller.STONE) == stone_price, "with a cave in the world, she sells the stone")
	purse = main.inventory.gold
	_ask(main, FortuneTeller.STONE)
	await process_frame
	_check(main.inventory.seeing_stone and main.inventory.gold == purse - stone_price
			and Inventory.load_from(TEST_PATH).seeing_stone, "bought, paid for and saved")
	_check(main.town_page._told != null and _said(main.town_page._told).contains("Seeing Stone is yours"),
			"and she says it is the player's for good")
	_check(FortuneTeller.cast(main.inventory.fortunes, FortuneTeller.STONE) == 0, "a thing sold, not a reading cast")
	main.town_page._close_told()
	main.town_page.redraw()
	await process_frame
	_check(_spell(main, FortuneTeller.STONE) == null, "and never sold again")

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
	_ask(main, FortuneTeller.HOMECOMING)
	await process_frame
	_check(not main.town_page.visible and main.map.aim_radius == 0,
			"the road home closes the town and aims at one tile")
	purse = main.inventory.gold
	main._on_cell_aimed(dark)
	_check(main.view.player_cell == town and main.inventory.gold == purse,
			"land that is no charted settlement is refused")
	main._on_cell_aimed(other)
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
	main.inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 5))
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
	_check(asked != null and "lost" in _said(asked) and not "heirloom" in _said(asked)
			and BigNumber.format(TownPrices.fortune_price(FortuneTeller.TRANSCEND, town)) in _said(asked),
			"in a popup that warns of what is lost and what it costs, not of what is won")
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
	# Five skulls to spend on the black screen, more than the one wall down earns: the budget is read as
	# the screen opens.
	main.inventory.skull_budget = 5
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
	black._create_page._select_item(main.inventory.items.find(kept))
	black._create_page._on_make_pressed()
	_deep_button(black._create_page._confirm, "Keep").pressed.emit()
	await process_frame
	_check(main.inventory.stash().items.has(kept) and black._choice.visible
			and _deep_button(black, "Create an heirloom").disabled, "one piece is kept, and only one")
	_deep_button(black, "Upgrade an heirloom").pressed.emit()
	black._upgrade_page._select_item(0)
	black._upgrade_page._on_super_orb_pressed(SuperOrbTable.ASCENSION)
	_deep_button(black._upgrade_page._confirm, "Use").pressed.emit()
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
	for id: String in [Curses.THICK_FOG, Curses.NO_REST]:
		(black._curse_face.find_child(id, true, false) as Button).toggled.emit(true)
		await process_frame
	var winter := black._curse_face.find_child(Curses.LONG_WINTER, true, false) as Button
	_check(main.inventory.pending_curses.size() == 2 and winter.disabled
			and not (black._curse_face.find_child(Curses.IRON_FOES, true, false) as Button).disabled
			and not (black._curse_face.find_child(Curses.NO_REST, true, false) as Button).disabled
			and "Skulls: 3 of 5" in _said(black._curse_face),
			"three skulls of five taken: a curse of three greys, one of one does not")
	winter.toggled.emit(true)
	await process_frame
	_check(main.inventory.pending_curses.size() == 2, "and a greyed one pressed anyway is refused")
	(black._curse_face.find_child(Curses.NO_REST, true, false) as Button).toggled.emit(false)
	await process_frame
	(black._curse_face.find_child(Curses.LONG_WINTER, true, false) as Button).toggled.emit(true)
	await process_frame
	_check(main.inventory.pending_curses == [Curses.THICK_FOG, Curses.LONG_WINTER],
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
	_check(after.curses == [Curses.THICK_FOG, Curses.LONG_WINTER], "the new world is under what was chosen (%s)" % [after.curses])
	_check(after.total() == 1 and after.items[0].type == LootTable.BROKEN_TORCH, "and the fog's torch is in its bag")
	# The scene would have been loaded again; here it is only told it may not write the old world back.
	main.queue_free()
	await process_frame


## Every Label's text under `parent`, run together, for a test that asks what a page says.
func _said(parent: Node) -> String:
	var text := ""
	for child: Node in parent.get_children():
		if child is Label and not child.is_queued_for_deletion():
			text += (child as Label).text + " "
		text += _said(child)
	return text


## The first Button under `parent` whose label starts with `text`, or null. The blocks are built fresh
## on every refresh, so a test finds its button rather than holding one.
func _button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text.begins_with(text):
			return child
	return null


## The same, anywhere under `parent`: a board's rows sit in a scroll inside a box inside the page.
## One of the fortuneteller's spell squares, by reading, or null when it is not on her grid.
func _spell(main: Node, reading: String) -> Control:
	return main.town_page._rows.find_child(reading, true, false)


## Whether she is refusing that reading: a square she will not read is greyed and takes no press.
func _dead(main: Node, reading: String) -> bool:
	var square := _spell(main, reading)
	return square != null and square.modulate == OrbSlot.DIM


## What one of her squares says it costs, read off the price under it.
func _price(main: Node, reading: String) -> float:
	return main.town_page._fortune_price(reading)


## Whether the town on `spot` has cast `reading` and so will not cast it again.
func _spent(main: Node, spot: Vector2i, reading: String) -> bool:
	return FortuneTeller.asked(main.inventory.towns.visit(spot), reading)


## A left click on one of her squares, which is how a reading is asked for.
func _ask(main: Node, reading: String) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	_spell(main, reading).gui_input.emit(click)


func _deep_button(parent: Node, text: String) -> Button:
	for child: Node in parent.get_children():
		if child is Button and (child as Button).text.begins_with(text):
			return child
		var found := _deep_button(child, text)
		if found != null:
			return found
	return null


## Three curses the main scene has a hand in: the Ring of Walls moves where the next wall stands,
## the Homeland's lands are chosen as the world's map first exists, and under No Second Chances a
## lost tile is a lost world -- the black screen, with no heirloom to be made on it.
func _test_curses_the_world_feels() -> void:
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
	_check(_deep_button(black, "Create an heirloom").disabled and "lost" in _said(black),
			"and a world lost that way makes no heirloom")
	black.finish()
	await process_frame
	var after := Inventory.load_from(TEST_PATH)
	_check(after.curses.is_empty() and after.stash().total() == 0 and after.total() == 0,
			"the next world begins under nothing, with nothing")
	_check(after.skull_budget == 0, "and eight skulls carried into a lost world earn none (%d)" % after.skull_budget)
	main.queue_free()
	await process_frame
	_clear_scratch()


func _clear_scratch() -> void:
	for scratch in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(scratch):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
