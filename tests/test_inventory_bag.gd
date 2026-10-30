extends "res://tests/inventory_base.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   python tests/run_all.py inventory_bag
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.


func _run() -> void:
	_clear_save()
	_check(_test_kinds() == true, "kind tests ran to the end")
	_check(_test_level_rolls() == true, "level roll tests ran to the end")
	_check(_test_item_levels() == true, "item level tests ran to the end")
	_check(_test_bag_order() == true, "bag order tests ran to the end")
	_check(_test_capacity() == true, "capacity tests ran to the end")
	_check(_test_autodiscard() == true, "autodiscard tests ran to the end")
	_check(_test_loot_filter() == true, "loot filter tests ran to the end")
	_check(_test_stones() == true, "skill stone tests ran to the end")
	_check(await _test_bag_filter() == true, "bag filter tests ran to the end")
	_check(_test_deltas() == true, "delta tests ran to the end")
	_check(_test_upgrade_mark() == true, "upgrade mark tests ran to the end")
	_check(await _test_comparing() == true, "comparison tests ran to the end")
	_check(_test_attribute_requirements() == true, "attribute requirement tests ran to the end")
	_check(await _test_heirlooms() == true, "heirloom tests ran to the end")
	_check(_test_mod_tiers() == true, "modifier tier tests ran to the end")
	_clear_save()
	_report("inventory: bag")


## The heirlooms: the second stash and doll, how a piece gets there, what the two dolls add up to,
## which uniques count which side, what is left when the world is, and the page they are kept on.
func _test_heirlooms() -> bool:
	_clear_save()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	# Straight onto the doll: these pieces are fixtures for the heirlooms' rules, and past
	# `LootTable.NEEDS_FROM` the player's Equip would ask for attributes nobody here wears.
	var wear := func(side: Inventory, piece: Item) -> void:
		side.items.append_array(side.equipment.equip(side.equipment.sockets_for(piece)[0], piece))
		_check(piece in side.equipment.items(), "%s goes on" % piece.display_name())
	var ring_of := func(percent: int) -> Item:
		var ring := Item.new()
		ring.type = "Gold Ring"
		ring.stats = Item.scaled_stats(ring.type, 1)
		ring.mods = [{"id": "global_increased_damage", "value": percent}]
		return ring

	# A modifier carried to another level keeps its place in the band.
	for id: String in ["increased_damage", "added_damage", "global_increased_damage"]:
		var deep := ModifierTable.band_for(id, 20)
		var shallow := ModifierTable.band_for(id, 1)
		_check(ModifierTable.rescaled(id, deep[0], 20, 1) == shallow[0]
				and ModifierTable.rescaled(id, deep[1], 20, 1) == shallow[1],
				"%s: the ends of one band are the ends of the other" % id)
		_check(ModifierTable.rescaled(id, deep[0] - 5, 20, 1) == shallow[0]
				and ModifierTable.rescaled(id, deep[1] * 2, 20, 1) == shallow[1],
				"%s: a value outside its band is held to it" % id)
		var middle := ModifierTable.rescaled(id, (int(deep[0]) + int(deep[1])) / 2, 20, 1)
		_check(middle >= shallow[0] and middle <= shallow[1], "%s: the middle stays inside (%d)" % [id, middle])

	# What the end of a world does to one piece.
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 12)
	var ids := sword.mods.map(func(mod: Dictionary) -> String: return mod["id"])
	sword.mods[0]["locked"] = true
	sword.transcend()
	_check(sword.level == 1 and sword.safe_level == 12 and sword.stats == Item.scaled_stats("Wooden Sword", 1),
			"level 1, the base stats of a level 1, and 12 remembered")
	_check(sword.mods.map(func(mod: Dictionary) -> String: return mod["id"]) == ids
			and sword.rarity == ItemRarity.Rarity.ELITE and not sword.locked_mod().is_empty(),
			"the same lines, the same rarity, the same lock")
	for mod in sword.mods:
		var band := ModifierTable.band_for(mod["id"], 1)
		_check(mod["value"] >= band[0] and mod["value"] <= band[1],
				"%s is back in level 1's band (%d)" % [mod["id"], mod["value"]])
	sword.level = 4
	sword.transcend()
	_check(sword.safe_level == 12, "a short run takes nothing off what it remembers")
	_check(Item.from_dict(sword.to_dict()).safe_level == 12
			and not _piece(ItemRarity.Rarity.COMMON, 1).to_dict().has("safe_level"),
			"it is saved with the piece, and only where there is one")

	# A wall is counted once.
	var bag := Inventory.new()
	_check(not bag.credit_walls(0) and bag.walls_credited == 0, "no wall, nothing counted")
	_check(bag.credit_walls(2) and bag.walls_credited == 2, "two walls down are two, as an old save finds")
	_check(not bag.credit_walls(2) and bag.walls_credited == 2, "asked again, nothing more")
	_check(bag.credit_walls(3) and bag.walls_credited == 3, "and the next wall is one more")

	# Making one: from the bag, or straight off the doll with the bag full, and never a broken piece.
	var from_bag := _piece(ItemRarity.Rarity.RARE, 7)
	var worn := _piece(ItemRarity.Rarity.RARE, 9)
	var ruined := _piece(ItemRarity.Rarity.RARE, 3)
	ruined.broken = true
	wear.call(bag, worn)
	bag.items.append(from_bag)
	bag.items.append(ruined)
	_check(not bag.can_make_heirloom(ruined), "a broken piece is refused")
	_check(not bag.can_make_heirloom(_piece(ItemRarity.Rarity.RARE, 1)), "and so is a piece the player does not hold")
	_check(bag.make_heirloom(from_bag) and not bag.items.has(from_bag) and bag.stash().items.has(from_bag),
			"a bag piece leaves the bag for the stash")
	while not bag.is_full():
		bag.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	_check(bag.make_heirloom(worn) and bag.equipment.worn.is_empty() and bag.stash().items.has(worn)
			and bag.total() == Inventory.CAPACITY, "a worn piece comes off the doll past a full bag, which is left alone")
	_check(worn.level == 9, "and nothing about the piece has moved")

	# The save, and a file from before there were heirlooms.
	_check(bag.stash().remove(worn) and bag.stash().equipment.equip(Equipment.Socket.WEAPON, worn).is_empty(),
			"an heirloom goes on the heirlooms' doll")
	_check(bag.save(TEST_PATH), "it saves")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.stash().total() == 1 and back.stash().items[0].level == 7
			and back.stash().items[0].rarity == ItemRarity.Rarity.RARE, "the stash comes back")
	_check(back.stash().equipment.items().size() == 1 and back.stash().equipment.items()[0].level == 9,
			"and so does the heirlooms' doll")
	_check(back.walls_credited == 3, "with the walls counted")
	var old := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 13, "items": [], "gold": 5}))
	old.close()
	var before := Inventory.load_from(TEST_PATH)
	_check(before.stash().total() == 0 and before.walls_credited == 0,
			"a version 13 save has none, and no wall counted")

	# Two dolls. Flats add; each doll's global percents are a multiplier of their own.
	var both := _hero()
	wear.call(both, _piece(ItemRarity.Rarity.COMMON, 5))
	var one_sword: float = both.stats()["damage"]
	wear.call(both.stash(), _piece(ItemRarity.Rarity.COMMON, 5))
	_check(is_equal_approx(both.stats()["damage"], one_sword * 2.0), "a sword on each doll is both swords")
	wear.call(both, ring_of.call(20))
	wear.call(both.stash(), ring_of.call(20))
	_check(is_equal_approx(both.stats()["damage"], one_sword * 2.0 * 1.2 * 1.2),
			"20%% on each doll is x1.44 (%s)" % both.stats()["damage"])
	var one_doll := _hero()
	wear.call(one_doll, _piece(ItemRarity.Rarity.COMMON, 5))
	wear.call(one_doll, ring_of.call(20))
	wear.call(one_doll, ring_of.call(20))
	_check(is_equal_approx(one_doll.stats()["damage"], one_sword * 1.4), "where two on one doll are x1.4")
	_check(is_equal_approx(both.equipment.totals()["damage"], one_sword * 1.2),
			"and a doll asked alone still answers for itself alone")

	# A count is its own side's.
	var counted := Inventory.new()
	wear.call(counted, _piece(ItemRarity.Rarity.COMMON, 1))
	wear.call(counted.stash(), Item.rolled_unique("ascetics_cord", rng, 1))
	_check(counted.stats()["bare_sockets"] == Equipment.NAMES.size() - 1,
			"the cord on the heirlooms' doll counts that doll's bare places (%d)" % counted.stats()["bare_sockets"])
	wear.call(counted, Item.rolled_unique("ascetics_cord", rng, 1))
	_check(counted.stats()["bare_sockets"] == (Equipment.NAMES.size() - 1) + (Equipment.NAMES.size() - 2),
			"and one on each counts both")
	wear.call(counted.stash(), Item.rolled_unique("packmule", rng, 1))
	counted.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	counted.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	counted.stash().items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	_check(counted.stats()["bag_pieces"] == 1, "the harness on the heirlooms' doll counts the stash and not the bag")

	# A stat is the player's: the helm on one doll is paid for armour on the other.
	var spiked := _hero()
	wear.call(spiked, _piece(ItemRarity.Rarity.COMMON, 5))
	var bare_damage: float = spiked.stats()["damage"]
	var helm := Item.rolled_unique("spiked_helm", rng, 5)
	helm.stats["armor"] = 0.0
	helm.mods.clear()
	wear.call(spiked.stash(), helm)
	var plate := Item.new()
	plate.type = "Wooden Armour"
	plate.stats = {"armor": 1000.0}
	wear.call(spiked, plate)
	_check(is_equal_approx(spiked.stats()["damage"],
			bare_damage + 1000.0 * UniqueTable.dial("spiked_helm", "share") / 100.0),
			"the helm among the heirlooms reads the ordinary doll's armour (%s)" % spiked.stats()["damage"])

	# Each doll's home piece is its own, and the sack pays from either.
	var split := Inventory.new()
	wear.call(split, Item.rolled_unique("meadowstriders", rng, 1))
	wear.call(split.stash(), Item.rolled_unique("rimeplate", rng, 1))
	_check(split.effects() == ["home:grass", "home:ice"], "a home piece on each doll is two lone pieces (%s)"
			% [split.effects()])
	var junk := _piece(ItemRarity.Rarity.RARE, 8)
	_check(split.salvage(junk) == 0.0, "no sack, no salvage")
	wear.call(split.stash(), Item.rolled_unique("rag_and_bone_sack", rng, 1))
	_check(split.salvage(junk) > 0.0, "the sack among the heirlooms pays for what the bag throws away")

	# What is left when the world is.
	var leaving := Inventory.new()
	leaving.gold = 5000.0
	leaving.level = 20
	leaving.kills = 900
	leaving.tips = ["first_item"]
	leaving.note_unique("spiked_helm")
	leaving.add_orb(OrbTable.orbs()[0], 3)
	leaving.walls_credited = 2
	leaving.items.append(_piece(ItemRarity.Rarity.ELITE, 20))
	var held := _piece(ItemRarity.Rarity.RARE, 15)
	var on_doll := _piece(ItemRarity.Rarity.RARE, 18)
	leaving.stash().items.append(held)
	wear.call(leaving.stash(), on_doll)
	var next := leaving.transcended()
	_check(next.gold == 0.0 and next.level == 1 and next.total() == 0 and next.total_orbs() == 0
			and next.equipment.worn.is_empty() and next.walls_credited == 0, "the world's things stay in it")
	_check(next.kills == 900 and next.tips == ["first_item"] and next.uniques_found == ["spiked_helm"]
			and next.first_sword_taken and next.first_orb_taken, "what the player knows goes along")
	_check(next.stash().total() == 1 and next.stash().items[0].level == 1 and next.stash().items[0].safe_level == 15,
			"the stash goes along, at level 1")
	var still_on: Item = next.stash().equipment.items()[0]
	_check(still_on.level == 1 and still_on.safe_level == 18, "and the heirlooms' doll stays dressed")
	_check(next.raise_heirlooms(16) and next.stash().items[0].level == 15 and still_on.level == 16,
			"both climb with the land charted, the stash's and the doll's, each no further than it had been")
	_check(held.level == 15 and on_doll.level == 18, "the inventory that was left is untouched, should the write fail")

	# A save from when there were super orbs (or a version 14 save's picks) reads with nothing lost.
	leaving.save(TEST_PATH)
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	old_save["super_orbs"] = 2
	old_save["heirloom_picks"] = 2
	SafeFile.write(TEST_PATH, JSON.stringify(old_save))
	var problem: Array = []
	var read := Inventory.load_from(TEST_PATH, problem)
	_check(problem.is_empty() and read.stash().total() == 1, "a save holding super orbs still reads")
	_clear_save()
	_check(_test_curses() == true, "curse tests ran to the end")
	_check(_test_more_curses() == true, "second batch curse tests ran to the end")

	# The pages. The ordinary bag makes no heirloom; a transcension's does, at its foot, and writes
	# nothing: the whole transcension is one write, and the main scene's.
	var owner := Inventory.new()
	owner.tips.append(BagPage.SKIP_CONFIRM + "discard_heirloom")
	var treasure := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 6)
	owner.items.append(treasure)
	var bag_page := BagPage.new(owner, TEST_PATH, 2.0)
	root.add_child(bag_page)
	await process_frame
	bag_page._select_item(0)
	_check(_deep_button(bag_page, "Make heirloom") == null, "the bag itself makes no heirloom")
	bag_page.queue_free()
	var made: Array = []
	var choosing := BagPage.new(owner, "", 2.0, false, true)
	choosing.heirloom_made.connect(func(item: Item) -> void: made.append(item))
	root.add_child(choosing)
	await process_frame
	_check(_deep_button(choosing, "Make heirloom").disabled, "with nothing open its Make heirloom is dead")
	choosing._select_item(0)
	var make := _deep_button(choosing, "Make heirloom")
	_check(not make.disabled and _deep_button(choosing, "Equip") == null and _deep_button(choosing, "Discard") == null,
			"an open piece can be made one, and there is nothing else to do with it")
	make.pressed.emit()
	_check(owner.items.has(treasure) and choosing._confirm != null, "which asks first")
	_deep_button(choosing._confirm, "Keep").pressed.emit()
	_check(owner.stash().items.has(treasure) and made == [treasure],
			"and Keep does it")
	_check(not FileAccess.file_exists(TEST_PATH), "and writes nothing")
	choosing.queue_free()
	# The black screen asks for a name for it, which it goes by from then on, through the save as well.
	var black := TranscendPage.new(owner, 2.0)
	root.add_child(black)
	await process_frame
	black._name_heirloom(treasure)
	var naming: Array = black.get_children().filter(func(child: Node) -> bool: return child is TextPrompt)
	_check(naming.size() == 1, "making one asks for its name")
	(naming[0] as TextPrompt).entered.emit("  Fang ")
	var named := Item.from_dict(treasure.to_dict())
	_check(treasure.display_name() == "Fang" and named.nickname == "Fang" and named.base_name() == "Wooden Sword",
			"and the name it is given is its name, in the save too")
	(naming[0] as TextPrompt).entered.emit("Wooden Sword")
	_check(treasure.nickname.is_empty(), "its own name is no name")
	black.queue_free()

	# No tray over the heirlooms on the black screen.
	var heirlooms := BagPage.new(owner, "", 2.0, true, true)
	root.add_child(heirlooms)
	await process_frame
	_check(not heirlooms._orb_tray.visible and heirlooms._orb_tray.get_child_count() == 0,
			"the black screen's heirlooms have no orbs to press")
	heirlooms.queue_free()
	var page := BagPage.new(owner, TEST_PATH, 2.0, true)
	root.add_child(page)
	await process_frame
	_check(_by_tooltip(page, "Auto") == null and _by_tooltip(page._sections, "Discard ") == null,
			"an heirloom's level has no Auto and no bin")
	page.shop(PackedStringArray([TownServices.GEAR]))
	page._select_item(0)
	_check(_deep_button(page, "Sell") == null and _deep_button(page, "Discard") != null,
			"no counter buys one: Discard stays Discard")
	_deep_button(page, "Discard").pressed.emit()
	_check(owner.stash().items.has(treasure) and page._confirm != null,
			"throwing one away asks, even with the question ticked away")
	_deep_button(page._confirm, "Discard").pressed.emit()
	_check(owner.stash().total() == 0, "gone")
	page.queue_free()
	await process_frame
	return true


## Tiers: the same average a modifier always had, a top about twice what it was, and a tier that
## moves with the piece's level and with nothing else.
func _test_mod_tiers() -> bool:
	var falloff := ModifierTable.TIER_FALLOFF
	for id: String in ["increased_damage", "global_increased_damage", "added_armor", "added_crit", "added_damage"]:
		for level: int in [1, 5, 20]:
			var sum := 0.0
			var weights := 0.0
			for tier in range(1, level + 1):
				var band := ModifierTable.band_for(id, tier)
				sum += pow(falloff, level - tier) * (int(band[0]) + int(band[1])) / 2.0
				weights += pow(falloff, level - tier)
			var old := _old_band(id, level)
			var target := (float(old[0]) + float(old[1])) / 2.0
			_check(absf(sum / weights - target) <= maxf(0.5, target * 0.02),
					"%s at level %d averages what it did: %.1f against %.1f" % [id, level, sum / weights, target])
	_check(ModifierTable.band_for("increased_damage", 1) == ModifierTable.MODS["increased_damage"]["range"],
			"and tier 1 is the band as written")

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var total := 0.0
	for i in 2000:
		var mod := ModifierTable.rolled_mod("increased_damage", rng, 20)
		var under := int(mod.get("under", 0))
		_check(under >= 0 and under < 20 and (under > 0) == mod.has("under"), "a tier from 1 to the level: %s" % mod)
		total += int(mod["value"])
	var old_20 := _old_band("increased_damage", 20)
	var target_20 := (float(old_20[0]) + float(old_20[1])) / 2.0
	_check(absf(total / 2000.0 - target_20) < target_20 * 0.05,
			"two thousand rolls average what they did: %.1f against %.1f" % [total / 2000.0, target_20])
	for id: String in ["added_fight_clock", "added_gold_find"]:
		_check(not ModifierTable.tiered(id) and not ModifierTable.rolled_mod(id, rng, 20).has("under"),
				"%s has one band, and so no tier" % id)

	# A Divine moves the number and never the tier; the smith moves neither.
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 20)
	var unders := sword.mods.map(func(mod: Dictionary) -> int: return int(mod.get("under", 0)))
	for i in 10:
		OrbTable.apply("Orb of Divinity", sword, rng)
	_check(sword.mods.map(func(mod: Dictionary) -> int: return int(mod.get("under", 0))) == unders,
			"a Divine keeps every tier")
	for mod in sword.mods:
		var band := ModifierTable.band_for(str(mod["id"]), sword.tier_of(mod))
		_check(int(mod["value"]) >= int(band[0]) and int(mod["value"]) <= int(band[1]),
				"and rolls inside it: %s in %s" % [mod, band])
	var tiers := sword.mods.map(sword.tier_of)
	var values := sword.mods.map(func(mod: Dictionary) -> int: return int(mod["value"]))
	_check(Blacksmith.upgrade(sword, 99, _never_breaks()), "the hammer lands")
	_check(sword.mods.map(sword.tier_of) == tiers
			and sword.mods.map(func(mod: Dictionary) -> int: return int(mod["value"])) == values,
			"an upgrade is a level and leaves every tier and number")

	# A line saved before there were tiers keeps its number and is given the tier that holds it.
	var saved := sword.to_dict()
	saved["mods"] = [{"id": "increased_damage", "value": roundi(old_20[0])}]
	var old_piece := Item.from_dict(saved)
	var line: Dictionary = old_piece.mods[0]
	var fitted := ModifierTable.band_for("increased_damage", old_piece.tier_of(line))
	_check(int(line["value"]) == roundi(old_20[0]) and int(line.get("under", 0)) > 0
			and int(fitted[0]) <= int(line["value"]) and int(line["value"]) <= int(fitted[1]),
			"an old line keeps its number, in a tier that holds it: %s in %s" % [line, fitted])
	_check(Item.from_dict(old_piece.to_dict()).mods == old_piece.mods, "and the save keeps the tier")
	_check(old_piece.mod_lines(true)[0].ends_with(" T%d" % old_piece.tier_of(line))
			and not old_piece.mod_lines()[0].contains(" T"), "which only a detailed line writes")
	return true


## What a piece asks before it goes on (`LootTable.requirement`, `Inventory.why_not_equip`): nothing
## up to `NEEDS_FROM` or on jewellery, its kind's attribute past it, met by both dolls but never by
## the piece itself or by what the swap takes off.
func _test_attribute_requirements() -> bool:
	var past := LootTable.NEEDS_FROM + 5
	_check(LootTable.requirement("Wooden Sword", LootTable.NEEDS_FROM).is_empty(), "nothing asked up to the grace")
	_check(LootTable.requirement("Gold Ring", past).is_empty(), "jewellery asks nothing")
	_check(LootTable.requirement("Bone Knife", past)[0] == "dexterity"
			and LootTable.requirement("Wooden Torch", past)[0] == "intelligence", "each kind asks its own")
	var needs: int = LootTable.requirement("Wooden Sword", past)[1]
	_check(needs > 0 and LootTable.requirement("Wooden Sword", past + 1)[1] > needs, "and more a level")
	var strong := func(points: int) -> Item:
		var ring := Item.new()
		ring.type = "Iron Band"
		ring.stats = Item.scaled_stats(ring.type, 1)
		ring.mods = [{"id": "added_strength", "value": points}]
		return ring

	var bag := Inventory.new()
	var sword := _piece(ItemRarity.Rarity.COMMON, past)
	bag.items.append(sword)
	_check(bag.why_not_equip(sword, Equipment.Socket.WEAPON) == "Needs %d Strength" % needs
			and not bag.equip(sword, Equipment.Socket.WEAPON), "a bare player cannot wear it")
	sword.mods = [{"id": "added_strength", "value": needs}]
	_check(not bag.can_equip(sword, Equipment.Socket.WEAPON), "its own strength does not lift it")
	bag.equipment.equip(Equipment.Socket.RING_LEFT, strong.call(needs))
	_check(bag.equip(sword, Equipment.Socket.WEAPON), "a ring's strength does")
	# A second sword asking the same, over a first that carries the strength: the swap takes it off.
	var worn := Inventory.new()
	var carrier := _piece(ItemRarity.Rarity.COMMON, 1)
	carrier.mods = [{"id": "added_strength", "value": needs}]
	worn.equipment.equip(Equipment.Socket.WEAPON, carrier)
	var next := _piece(ItemRarity.Rarity.COMMON, past)
	worn.items.append(next)
	_check(not worn.can_equip(next, Equipment.Socket.WEAPON), "what the swap takes off does not count")
	# Both dolls: a ring among the heirlooms meets the bag's piece, and the bag's ring an heirloom's.
	var two := Inventory.new()
	two.stash().equipment.equip(Equipment.Socket.RING_LEFT, strong.call(needs))
	var mine := _piece(ItemRarity.Rarity.COMMON, past)
	two.items.append(mine)
	_check(two.can_equip(mine, Equipment.Socket.WEAPON), "the heirlooms' strength counts for the bag")
	var heir := Inventory.new()
	heir.equipment.equip(Equipment.Socket.RING_LEFT, strong.call(needs))
	var kept := _piece(ItemRarity.Rarity.COMMON, past)
	heir.stash().items.append(kept)
	_check(heir.stash().can_equip(kept, Equipment.Socket.WEAPON), "and the bag's for the heirlooms")
	_check(heir.equipment.worn.size() == 1 and two.stash().equipment.worn.size() == 1,
			"asking takes nothing off either doll")
	return true

## The bag's green arrow: something gained and nothing lost against what Equip would take off.
func _test_upgrade_mark() -> bool:
	# Level 5 and under: those ask for no attribute (`LootTable.requirement`), so only the stats decide.
	var player := Inventory.new()
	var worn := player.equipment
	var low := _piece(ItemRarity.Rarity.COMMON, 1)
	_check(BagPage.is_upgrade(low, player), "anything beats a bare socket")
	var mid := _piece(ItemRarity.Rarity.COMMON, 3)
	worn.equip(Equipment.Socket.WEAPON, mid)
	_check(not BagPage.is_upgrade(low, player), "a weaker sword is no upgrade")
	_check(BagPage.is_upgrade(_piece(ItemRarity.Rarity.COMMON, 5), player), "a stronger one is")
	_check(not BagPage.is_upgrade(_piece(ItemRarity.Rarity.COMMON, 3), player), "an equal one gains nothing")
	_check(not BagPage.is_upgrade(mid, player), "and the worn piece is never its own upgrade")
	# Stronger, but it asks for Strength the player does not have: Equip would refuse it, so no arrow.
	var heavy := _piece(ItemRarity.Rarity.COMMON, 20)
	_check(not LootTable.requirement(heavy.type, heavy.level).is_empty()
			and not BagPage.is_upgrade(heavy, player), "nor is one the player cannot put on")
	return true


## The bag is read level-major, for the player looking for a piece.
func _test_bag_order() -> bool:
	var bag := Inventory.new()
	# Added oldest first. Two at level 5, so the tie-break inside a rarity is exercised too.
	var l5_common_old := _piece(ItemRarity.Rarity.COMMON, 5)
	var l5_common_new := _piece(ItemRarity.Rarity.COMMON, 5)
	var l5_rare := _piece(ItemRarity.Rarity.RARE, 5)
	var l9_common := _piece(ItemRarity.Rarity.COMMON, 9)
	var l2_elite := _piece(ItemRarity.Rarity.ELITE, 2)
	for piece: Item in [l5_common_old, l5_common_new, l5_rare, l9_common, l2_elite]:
		bag.add(piece)

	var read: Array[Item] = []
	for i in bag.order():
		read.append(bag.items[i])
	_check(read == [l9_common, l5_rare, l5_common_new, l5_common_old, l2_elite],
			"the bag reads by level, then rarity, then newest first")
	_check(bag.levels() == [9, 5, 2], "and the sections run highest level first")
	_check(bag.count_at(5) == 3 and bag.count_at(9) == 1 and bag.count_at(1) == 0,
			"with the right number in each")

	# An orb lifts the older common past the rare, but the open bag sorts by what it was.
	l5_common_old.rarity = ItemRarity.Rarity.ELITE
	read.clear()
	for i in bag.order({l5_common_old: ItemRarity.Rarity.COMMON}):
		read.append(bag.items[i])
	_check(read == [l9_common, l5_rare, l5_common_new, l5_common_old, l2_elite],
			"a piece held at its old rarity keeps its place")
	_check(bag.items[bag.order()[1]] == l5_common_old, "and sorted afresh it moves up")
	return true


## The bag has a bottom to it, and going past it destroys nothing: it overencumbers the player.
func _test_capacity() -> bool:
	var bag := Inventory.new()
	for i in Inventory.CAPACITY:
		bag.add(_piece(ItemRarity.Rarity.RARE, 5))
	_check(bag.total() == Inventory.CAPACITY, "the bag fills to the cap")
	_check(bag.is_full() and bag.room_left() == 0, "and says it is full")
	_check(not bag.encumbered(), "which is not yet too heavy")

	var common := _piece(ItemRarity.Rarity.COMMON, 9)
	bag.add(common)
	_check(bag.total() == Inventory.CAPACITY + 1 and bag.items.has(common),
			"a find past the cap goes in all the same")
	_check(bag.encumbered() and bag.room_left() == 0, "and leaves the player overencumbered")

	# A swap takes one out for one back, so an over-full bag may still make it; a two-hander that
	# hands two back may not.
	var worn_blade := _piece(ItemRarity.Rarity.RARE, 4)
	bag.equipment.equip(Equipment.Socket.WEAPON, worn_blade)
	_check(bag.can_equip(bag.items[0], Equipment.Socket.WEAPON), "an over-full bag can still swap one for one")
	bag.remove(common)
	bag.equipment.unequip(Equipment.Socket.WEAPON)
	_check(not bag.encumbered(), "back at the cap the weight is gone")

	# Taking a piece off is the one thing the player can do that grows the bag, so it refuses rather
	# than destroying something to make room for a piece they only wanted a closer look at.
	var worn := _piece(ItemRarity.Rarity.RARE, 4)
	bag.equipment.equip(Equipment.Socket.WEAPON, worn)
	_check(bag.is_full(), "the bag is still full")
	_check(not bag.unequip(Equipment.Socket.WEAPON), "a full bag refuses to take a piece back")
	_check(bag.equipment.item_at(Equipment.Socket.WEAPON) == worn, "so it stays on")
	bag.remove(bag.items[0])
	_check(bag.unequip(Equipment.Socket.WEAPON), "with one square free it comes off")
	_check(bag.equipment.item_at(Equipment.Socket.WEAPON) == null and bag.items.has(worn),
			"and is in the bag")
	return true


## The loot filter, the sixth wall's (`Inventory.leaves_behind`, `Settings.filter_*`): nothing until the
## wall has fallen in some world, then the least rarity, material and level and ascended pieces only --
## never a unique, a kind with one material never short of one, a skill stone by its rarity alone -- and
## a level's own rule all along.
func _test_loot_filter() -> bool:
	var player := Inventory.new()
	var plain := _piece(ItemRarity.Rarity.COMMON, 3)
	Settings.filter_rarity = ItemRarity.Rarity.RARE
	Settings.filter_level = 10
	_check(not player.leaves_behind(plain), "before the sixth wall the filter is not there")
	player.set_autodiscard(3, true)
	_check(player.leaves_behind(plain), "but a level's own rule always is")
	player.set_autodiscard(3, false)
	player.farthest_land = MapBuilder.START_LAND_RADIUS + 6 * MapBuilder.WALL_STEP
	Settings.filter_rarity = 0
	Settings.filter_level = 1
	_check(not player.leaves_behind(plain), "a filter keeping everything leaves nothing")

	Settings.filter_rarity = ItemRarity.Rarity.RARE
	var rare := _piece(ItemRarity.Rarity.RARE, 3)
	_check(player.leaves_behind(plain) and not player.leaves_behind(rare), "under the least rarity it is left")
	var unique := _piece(ItemRarity.Rarity.UNIQUE, 1)
	_check(not player.leaves_behind(unique), "a unique never is")
	Settings.filter_rarity = 0

	Settings.filter_level = 5
	_check(player.leaves_behind(plain) and not player.leaves_behind(_piece(ItemRarity.Rarity.COMMON, 5)),
			"under the least level it is left")
	Settings.filter_level = 1

	Settings.filter_material = 2
	var steel := _piece(ItemRarity.Rarity.COMMON, 6)
	steel.type = "Steel Sword"
	var ring := _piece(ItemRarity.Rarity.COMMON, 6)
	ring.type = "Gold Ring"
	_check(player.leaves_behind(plain) and not player.leaves_behind(steel),
			"a wooden sword is short of steel, a steel one is not")
	_check(not player.leaves_behind(ring), "jewellery has one material and is never short of one")
	# A kind that names its own levels is worth the material of each: the torch's three are the
	# plainest's, steel's and the masterwork's, and the greaves begin at iron.
	var made := func(type: String) -> Item:
		var item := _piece(ItemRarity.Rarity.COMMON, 6)
		item.type = type
		return item
	_check(player.leaves_behind(made.call("Wooden Torch")) and not player.leaves_behind(made.call("Blazing Torch"))
			and player.leaves_behind(made.call("Iron Greaves")) and not player.leaves_behind(made.call("Steel Greaves")),
			"a Blazing Torch and Steel Greaves are steel's, a Wooden Torch and Iron Greaves short of it")
	Settings.filter_material = LootTable.TIER_MIN_LEVEL.size() - 1
	_check(player.leaves_behind(made.call("Blazing Torch")) and not player.leaves_behind(made.call("Masterwork Torch"))
			and not player.leaves_behind(made.call("Masterwork Greaves"))
			and not player.leaves_behind(made.call("Masterwork Sword")),
			"and masterwork only keeps the Masterwork Torch with every other masterwork")
	Settings.filter_material = 0

	Settings.filter_ascended = true
	var ascended := _piece(ItemRarity.Rarity.COMMON, 3)
	ascended.plus = 1
	_check(player.leaves_behind(plain) and not player.leaves_behind(ascended), "ascended only keeps a +1")
	var stone := _node("Dexterity Node", "global_increased_attack_speed")
	_check(not player.leaves_behind(stone), "a skill stone answers to the rarity alone")
	Settings.filter_rarity = ItemRarity.Rarity.RARE
	_check(player.leaves_behind(stone), "and an uncommon one is under rare")
	Settings.filter_rarity = 0
	Settings.filter_ascended = false
	return true


## A level the player is done with: cleared once, and then told not to come back.
func _test_autodiscard() -> bool:
	var bag := Inventory.new()
	for level in [3, 3, 7]:
		bag.add(_piece(ItemRarity.Rarity.COMMON, level))
	_check(not bag.autodiscards(3), "nothing is autodiscarded to begin with")

	bag.set_autodiscard(3, true)
	_check(bag.autodiscards(3) and not bag.autodiscards(7), "a rule covers one level")
	bag.set_autodiscard(3, true)
	_check(bag.autodiscard.size() == 1, "and setting it twice is setting it once")
	# The rule is about what arrives. What is already held is the other button's business, and a rule
	# that emptied the section would leave a player who meant "no more of these" short three pieces.
	_check(bag.count_at(3) == 2, "turning a rule on leaves what is already held alone")

	bag.set_autodiscard(3, false)
	_check(not bag.autodiscards(3), "and it can be turned off again")
	bag.set_autodiscard(3, true)

	var gone := bag.discard_level(3)
	_check(gone.size() == 2 and bag.count_at(3) == 0, "Clear empties exactly that level")
	_check(bag.count_at(7) == 1, "and leaves the others")
	# The section survives its items, or the rule would have nowhere left to be turned off.
	_check(bag.levels() == [7, 3], "a level with a rule and nothing in it keeps its heading")
	bag.set_autodiscard(3, false)
	_check(bag.levels() == [7], "and loses it once the rule goes too")

	# A locked piece is passed by, and stays locked across a save.
	var kept := _piece(ItemRarity.Rarity.COMMON, 7)
	kept.locked = true
	bag.add(kept)
	gone = bag.discard_level(7)
	_check(gone.size() == 1 and bag.items == [kept], "Clear and Sell all leave a locked piece")
	_check(Item.from_dict(kept.to_dict()).locked, "and the lock is saved")
	_check(not Item.from_dict(gone[0].to_dict()).locked, "an unlocked one reads back unlocked")
	return true


## Skill nodes as items (the user's, 2026-10-08): carried and crafted like gear and never worn. A stone's
## tier lifts its lines and picks its disc, its connectors are saved with it, and a capstone is a leaf
## of unique rarity whose lines are its row's and which no orb touches.
func _test_stones() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	# Each base's pool is its own list (`SkillTree.LINES`), unlocked a tier at a time, never the lines
	# any piece of gear may carry; ranks are on every base from tier I and drawn less the deeper it is.
	for type: String in SkillTree.BASES:
		var first := ModifierTable.pool_for(type, 1)
		var deepest := ModifierTable.pool_for(type, SkillTree.MOST_TIER)
		_check("added_stone_ranks" in first, "%s may roll ranks from tier I" % type)
		_check(first.size() < deepest.size(), "%s unlocks lines as its tier deepens" % type)
		for id in first:
			_check(id in deepest, "%s keeps %s at a deeper tier" % [type, id])
		for id in deepest:
			_check(ModifierTable.MODS[id]["kind"] != ModifierTable.Kind.PERCENT,
					"%s rolls no percent of its own (%s)" % [type, id])
		_check(ModifierTable.pool_for(type, 0).is_empty(), "%s below tier I has nothing to roll" % type)
	for tier in range(2, SkillTree.MOST_TIER + 1):
		_check(ModifierTable.weight_of("added_stone_ranks", tier) < ModifierTable.weight_of("added_stone_ranks", tier - 1),
				"ranks are drawn less at tier %d than at %d" % [tier, tier - 1])
	_check(ModifierTable.weight_of("added_damage", 1) == ModifierTable.weight_of("added_damage", 9),
			"and no other line's weight moves with the tier")
	# The ranks line is tiered, its band written by the tier: the table's `range` at T1, and `per_tier`
	# more on each end a tier past it.
	_check(ModifierTable.tiered("added_stone_ranks"), "the ranks line has tiers")
	var ranks: Dictionary = ModifierTable.MODS["added_stone_ranks"]
	for tier: int in [1, 2, 5, 26]:
		var band := [int(ranks["range"][0]) + int(ranks["per_tier"][0]) * (tier - 1),
				int(ranks["range"][1]) + int(ranks["per_tier"][1]) * (tier - 1)]
		_check(ModifierTable.band_for("added_stone_ranks", tier) == band,
				"ranks at T%d roll %s" % [tier, ModifierTable.band_for("added_stone_ranks", tier)])
	_check("added_spawn_speed" in ModifierTable.pool_for("Dexterity Node")
			and not "added_spawn_speed" in ModifierTable.pool_for("Strength Node"),
			"spawn speed is the dexterity stone's, not every stone's")
	_check("added_fight_clock" in ModifierTable.pool_for("Dexterity Node")
			and not "added_fight_clock" in ModifierTable.pool_for("Intelligence Node"),
			"and so is the fight clock")
	# An orb draws from what the stone's tier unlocks, as the drop does.
	var shallow := Item.rolled("Strength Node", ItemRarity.Rarity.ELITE, rng, 4, 1, 0)
	for i in 20:
		OrbTable._reroll_at(shallow, ItemRarity.Rarity.ELITE, rng)
		for mod in shallow.mods:
			_check(SkillTree.LINES["Strength Node"][mod["id"]] == 1, "an orb on a tier I stone rolls %s" % mod["id"])
	# So does every other hand that gives a stone a line -- the drop, a reroll round a line held fast, an
	# Augmentation: each hands on the stone's tier, and none the whole pool.
	var held := Item.rolled("Strength Node", ItemRarity.Rarity.ELITE, rng, 4, 1, 0)
	held.hold(0, "bound")
	var roomy := Item.rolled("Strength Node", ItemRarity.Rarity.ELITE, rng, 4, 1, 0)
	for i in 20:
		OrbTable._reroll_at(held, ItemRarity.Rarity.ELITE, rng)
		roomy.mods.pop_back()
		_check(OrbTable.apply("Orb of Augmentation", roomy, rng), "a tier I stone takes an Augmentation")
		for made: Item in [held, roomy, Item.rolled("Strength Node", ItemRarity.Rarity.ELITE, rng, 4, 1, 0)]:
			for mod in made.mods:
				_check(SkillTree.LINES["Strength Node"][mod["id"]] == 1, "a tier I stone is given %s" % mod["id"])

	var stone := Item.rolled("Strength Node", ItemRarity.Rarity.RARE, rng, 4, 3, 2)
	_check(stone.is_stone() and stone.stone_tier == 3 and stone.connectors == 2, "a stone keeps its shape")
	_check(stone.mod_level() == stone.level, "its lines read their bands at its level, whatever its tier")
	_check(stone.mods.size() == 2, "a rare stone carries two lines (%d)" % stone.mods.size())
	_check(stone.icon() == LootTable.icon("Strength Node", 3)
			and LootTable.icon_path("Strength Node", 3).ends_with("str_3.png"), "and wears its tier's disc")
	_check(SkillTree.shape_text(stone) == "Tier 3 · 2 connectors", SkillTree.shape_text(stone))
	var back := Item.from_dict(stone.to_dict())
	_check(back != null and back.stone_tier == 3 and back.connectors == 2 and back.mods == stone.mods,
			"a stone reads back the stone it was")
	var saved_as_stone := stone.to_dict()
	saved_as_stone["type"] = "Strength Stone"
	_check(Item.from_dict(saved_as_stone).type == "Strength Node", "and one saved under its old name is a node now")
	_check(not Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng).is_stone(), "a sword is no stone")

	# The orbs work on a stone as on gear, to a stone's count: one line a step.
	var crafted := Item.rolled("Dexterity Node", ItemRarity.Rarity.UNCOMMON, rng, 1)
	_check(crafted.stone_tier == 1 and crafted.mods.size() == 1, "a stone is tier 1 at the least")
	_check(not OrbTable.can_apply("Orb of Augmentation", crafted), "an uncommon stone's one line is all it holds")
	_check(OrbTable.apply("Orb of Exaltation", crafted, rng) and crafted.mods.size() == 3,
			"an Exaltation makes it epic, with three (%d)" % crafted.mods.size())
	_check(OrbTable.apply("Orb of Divinity", crafted, rng), "and a Divine rerolls it")

	# A capstone: a leaf of its base at unique rarity, its row's lines, its old badge, and no orb at all.
	var cap := Item.rolled_capstone("titan", 2, rng, 5)
	_check(cap.rarity == ItemRarity.Rarity.UNIQUE and cap.connectors == 0 and cap.type == "Strength Node"
			and cap.stone_tier == 2, "a capstone is a unique-rarity leaf of its base")
	_check(cap.mods.map(func(mod: Dictionary) -> String: return mod["id"]) == SkillTree.CAPSTONES["titan"]["mods"],
			"carrying its row's lines")
	_check(cap.display_name() == "Titan" and not cap.effect_text().is_empty() and cap.icon() == SkillTree.icon("titan"),
			"under its own name, rule and badge")
	for orb: String in OrbTable.ORBS:
		_check(not OrbTable.can_apply(orb, cap) and not OrbTable.why_not(orb, cap).is_empty(),
				"%s leaves a capstone alone" % orb)
	var cap_back := Item.from_dict(cap.to_dict())
	_check(cap_back != null and cap_back.capstone == "titan" and cap_back.stone_tier == 2
			and cap_back.rarity == ItemRarity.Rarity.UNIQUE, "a capstone reads back whole")
	var retired := cap.to_dict()
	retired["capstone"] = "retired"
	_check(Item.from_dict(retired) == null, "and one this build no longer has goes whole")

	# Never an heirloom, spared by the bin with the uniques, and nothing worn for the card to compare with.
	var bag := Inventory.new()
	bag.add(stone)
	bag.add(cap)
	_check(not bag.can_make_heirloom(stone), "a stone is never an heirloom")
	bag.discard_level(5, false)
	_check(bag.items.has(cap), "the bin spares a capstone with the uniques")
	var card := ItemCard.new(1.0)
	card.equipment = bag.equipment
	_check(card.worn_for(stone) == null, "a stone has nothing worn to compare against")
	card.free()
	return true


## The bag's filter tabs: a slot's tab shows only that slot's pieces and the levels holding one, and a
## level's bin under it takes only what it stands over.
func _test_bag_filter() -> bool:
	_clear_save()
	var piece := func(type: String, level: int) -> Item:
		var item := _piece(ItemRarity.Rarity.COMMON, level)
		item.type = type
		return item
	var bag := Inventory.new()
	for row: Array in [["Iron Sword", 3], ["Gold Ring", 3], ["Gold Ring", 7], ["Iron Helmet", 5]]:
		bag.add(piece.call(row[0], row[1]))
	var gone := bag.discard_level(3, true, "ring")
	_check(gone.size() == 1 and gone[0].type == "Gold Ring" and bag.count_at(3) == 1,
			"a level's discard given a slot takes only that slot's pieces")
	bag.add(piece.call("Gold Ring", 3))
	bag.set_autodiscard(9, true)

	var page := BagPage.new(bag, TEST_PATH, 2.0)
	root.add_child(page)
	await process_frame
	var tabs: Array = page._filter_tabs.get_children().filter(func(n: Node) -> bool: return n is Button)
	_check(tabs.size() == BagPage.FILTERS.size(), "a tab a filter")
	_check(page._filter_tabs.get_combined_minimum_size().x <= BagPage.WIDTH, "and they fit the bag's width")
	var shown := func() -> Array:
		return page._sections.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is ItemSlot) \
				.map(func(slot: ItemSlot) -> String: return slot.item.type)
	var headings := func() -> int:
		return page._sections.get_children().filter(func(n: Node) -> bool: return n is HBoxContainer).size()
	_check(shown.call().size() == 4 and headings.call() == 4, "every piece and level with nothing picked")

	tabs.filter(func(b: Button) -> bool: return b.tooltip_text == "Rings")[0].pressed.emit()
	await process_frame
	_check(shown.call() == ["Gold Ring", "Gold Ring"], "Rings shows the rings alone (%s)" % [shown.call()])
	# Levels 7 and 3 hold one; 5 holds only a helmet and goes; 9 holds nothing but a rule and stays.
	_check(headings.call() == 3, "and the levels holding one, and a rule's empty level")
	page._drop_level(3, false)
	_check(bag.count_at(3) == 1 and bag.items.any(func(i: Item) -> bool: return i.type == "Iron Sword"),
			"a level's bin under the filter leaves what it hides")

	tabs = page._filter_tabs.get_children().filter(func(n: Node) -> bool: return n is Button)
	tabs.filter(func(b: Button) -> bool: return b.tooltip_text == "All items")[0].pressed.emit()
	await process_frame
	_check(shown.call().size() == 3, "All items brings every piece back")

	# The skill stones' tab, the last: the stones alone.
	bag.add(Item.rolled("Dexterity Node", ItemRarity.Rarity.COMMON, RandomNumberGenerator.new(), 3))
	page.refresh()
	tabs = page._filter_tabs.get_children().filter(func(n: Node) -> bool: return n is Button)
	tabs.filter(func(b: Button) -> bool: return b.tooltip_text == "Skill nodes")[0].pressed.emit()
	await process_frame
	_check(shown.call() == ["Dexterity Node"], "Skill nodes shows the stones alone (%s)" % [shown.call()])
	page.queue_free()
	_clear_save()
	return true


## What level a drop comes out at: evenly anywhere up to what the tile allows, with rarity lifting
## the floor. The ceiling is what a tile is worth and not what it pays -- which is the reason to
## fight the same ground more than once.
func _test_level_rolls() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var steps := ItemRarity.NAMES.keys()
	for step: ItemRarity.Rarity in steps:
		_check(ItemRarity.LEVEL_FLOOR.has(step), "rarity %d has a level floor" % step)

	# Never outside the range, at any ceiling and any rarity. A ceiling of 1 is the case that would
	# break a floor allowed to climb past the top, and it is the middle of the map.
	for ceiling in range(1, 21):
		for step: ItemRarity.Rarity in steps:
			for i in 200:
				var level := ItemRarity.roll_level(step, ceiling, rng)
				_check(level >= 1 and level <= ceiling,
						"rarity %d rolled level %d under a ceiling of %d" % [step, level, ceiling])
				_check(level >= clampi(ceili(ceiling * float(ItemRarity.LEVEL_FLOOR[step])), 1, ceiling),
						"rarity %d rolled level %d, under its own floor at ceiling %d"
								% [step, level, ceiling])

	# Even, which is what makes a deep tile a chase rather than a payout: every level in the range
	# comes up, and no level is favoured beyond what this many draws can scatter.
	var ceiling := 8
	var seen := {}
	for i in ROLLS:
		var level := ItemRarity.roll_level(ItemRarity.Rarity.COMMON, ceiling, rng)
		seen[level] = int(seen.get(level, 0)) + 1
	var want := 1.0 / ceiling
	for level in range(1, ceiling + 1):
		_check(seen.has(level), "a common piece can roll level %d of %d" % [level, ceiling])
		var share := float(seen.get(level, 0)) / ROLLS
		_check(absf(share - want) < _tolerance(want, ROLLS),
				"level %d came up %.3f of the time, not the even %.3f" % [level, share, want])

	# The floors climb with rarity, so a better piece is never worth less for having rolled well.
	var floors: Array[float] = []
	for step: ItemRarity.Rarity in steps:
		floors.append(float(ItemRarity.LEVEL_FLOOR[step]))
	for i in floors.size() - 1:
		_check(floors[i] <= floors[i + 1], "rarity %d starts no higher up the range than %d" % [i, i + 1])
	_check(floors[0] == 0.0, "a common piece can roll the bottom of the range")

	# A body's drop: never past its tile and its tier, but a common body now and then one level past
	# its tile outright -- and only that one.
	for tier: EnemyRoster.Tier in LootTable.TIER_LEVEL:
		var most := 0
		for i in ROLLS:
			most = maxi(most, LootTable.drop_level(tier, 3, ItemRarity.Rarity.COMMON, rng))
		var want_most := 3 + maxi(int(LootTable.TIER_LEVEL[tier]), 1 if tier == EnemyRoster.Tier.COMMON else 0)
		_check(most == want_most, "a tier-%d body on a level-3 tile drops up to %d, not %d" % [tier, want_most, most])
	return true


## What a level is worth to a piece, and the promise that a piece never changes once it is rolled.
func _test_item_levels() -> bool:
	for stat: String in LootTable.STAT_LABELS:
		_check(LootTable.LEVEL_FLAT.has(stat), "%s says what a level is worth to it" % stat)

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED

	# A level-1 piece is the piece the table describes times whatever its kind and its material are
	# worth, and nothing else: a level adds nothing at level 1, so what is left is the power alone.
	for type in LootTable.items():
		var plain := Item.rolled(type, ItemRarity.Rarity.COMMON, rng, 1)
		_check(plain.level == 1, "%s rolled at level 1 is level 1" % type)
		for stat: String in LootTable.stats_of(type):
			var raw := float(LootTable.stats_of(type)[stat]) * LootTable.power_of(type, stat)
			var want := snappedf(raw, 0.1) if stat in LootTable.RATE_STATS else float(roundi(raw))
			_check(is_equal_approx(float(plain.base_stats()[stat]), want),
					"a level-1 %s has %s %s, not %s" % [type, stat, plain.base_stats()[stat], want])

	# And a deeper one follows the curve, on a stat that starts small and one that starts large.
	for level in range(1, 21):
		var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level)
		_check(sword.level == level, "a sword rolled at level %d says so" % level)
		for stat: String in ["damage", "crit_damage"]:
			var want := LootTable.scale(stat, float(LootTable.stats_of("Wooden Sword")[stat]), level)
			_check(is_equal_approx(float(sword.base_stats()[stat]), float(roundi(want))),
					"a level-%d sword has %s %s, not the curve's %.2f"
							% [level, stat, sword.base_stats()[stat], want])
		# Damage is whole and gains a point about every two and a half levels (`LEVEL_FLAT`): never
		# less than the level before, always more than two levels back.
		var damage: float = sword.base_stats()["damage"]
		_check(is_equal_approx(damage, float(roundi(damage))), "a level-%d sword's damage is whole" % level)
		if level > 1:
			var under := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level - 1)
			_check(damage >= float(under.base_stats()["damage"]),
					"a level-%d sword hits no softer than a level-%d one" % [level, level - 1])
		if level > 2:
			var lower := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level - 2)
			_check(damage > float(lower.base_stats()["damage"]),
					"a level-%d sword hits harder than a level-%d one" % [level, level - 2])
		# A rate keeps its decimal, because it is read as one.
		var speed: float = sword.base_stats()["attack_speed"]
		_check(is_equal_approx(speed, snappedf(speed, 0.1)), "a level-%d sword's attack speed is a tenth" % level)

	# A probability may not be multiplied by a level. Every chance stat grows by its flat step alone,
	# so a deep set of gear cannot add up past certainty and make every hit a crit.
	for stat: String in LootTable.CHANCE_STATS:
		# Sight, the fight clock, the count of enemies and a tree's ranks are the ones in the list that
		# are not probabilities: tiles, seconds, bodies and ranks, there so that a level cannot multiply them.
		_check(stat in LootTable.PERCENT_STATS or stat in ["sight", "fight_clock", "extra_enemies",
				"strength_stones", "intelligence_stones", "dexterity_stones", "stone_ranks"],
				"%s is written as a percentage" % stat)
		for level in [1, 10, 40]:
			var want := 5.0 + float(LootTable.LEVEL_FLAT[stat]) * float(level - 1)
			_check(is_equal_approx(LootTable.scale(stat, 5.0, level), want),
					"%s at level %d is %.1f, not %.1f" % [stat, level, LootTable.scale(stat, 5.0, level), want])
	var deep_sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 30)
	_check(float(deep_sword.base_stats()["crit_chance"]) < Encounter.CRIT_CAP,
			"a level-30 sword's crit chance (%s%%) is still a chance" % deep_sword.base_stats()["crit_chance"])

	# The promise: once a piece is rolled it is that piece for good.
	var kept := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 6)
	var before := kept.base_stats().duplicate()
	var _other := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 19)
	_check(kept.base_stats() == before, "rolling another sword leaves the first one alone")
	var handed := kept.base_stats()
	handed["damage"] = 999.0
	_check(kept.base_stats() == before, "editing what base_stats() hands back leaves the item alone")
	var table_damage: Variant = LootTable.stats_of("Wooden Sword")["damage"]
	_check(table_damage == 1, "and the table itself was never written into: damage %s" % table_damage)

	# Modifiers grow with the level too, each kind its own way.
	for level in [1, 12]:
		var ring := Item.rolled("Gold Ring", ItemRarity.Rarity.ELITE, rng, level)
		for mod in ring.mods:
			var entry: Dictionary = ModifierTable.MODS[mod["id"]]
			var band: Array = entry["range"]
			var value := int(mod["value"])
			_check(value == roundi(value), "every modifier value is whole: %s" % mod)
			match entry["kind"]:
				ModifierTable.Kind.FLAT, ModifierTable.Kind.PERCENT, ModifierTable.Kind.GLOBAL:
					# In the band of the tier it drew; what the tiers add up to is `_test_mod_tiers`'.
					var tier_band := ModifierTable.band_for(mod["id"], ring.tier_of(mod))
					_check(ring.tier_of(mod) <= level and value >= int(tier_band[0]) and value <= int(tier_band[1]),
							"%s rolled %d at level %d, outside its tier's %s" % [mod["id"], value, level, tier_band])
				_:
					_check(value >= int(band[0]) and value <= int(band[1]),
							"a player buff keeps its written band: %s rolled %d" % [mod["id"], value])

	# Through the save and back, unchanged.
	var deep := Item.rolled("Ruby Amulet", ItemRarity.Rarity.RARE, rng, 14)
	var read := Item.from_dict(deep.to_dict())
	_check(read != null, "a levelled item round-trips")
	if read != null:
		_check(read.level == deep.level, "with its level: %d against %d" % [read.level, deep.level])
		_check(read.base_stats() == deep.base_stats(), "and every stat exactly, not nearly")
		_check(read.mods == deep.mods, "and every modifier")

	# A save from before pieces carried their own numbers: level 1, and the tables unscaled, which is
	# exactly what such a piece was worth on the day it was written.
	var old := Item.from_dict({"type": "Wooden Sword", "rarity": "common", "mods": []})
	_check(old != null, "an item with no level still loads")
	if old != null:
		_check(old.level == 1, "as a level-1 piece")
		_check(old.base_stats() == LootTable.stats_of("Wooden Sword"), "carrying the table as written")

	# And a piece saved with a stat its kind has since lost keeps it. A ring found today shows no Time
	# on Hit; one already on a finger is frozen, and what the file holds is what it is worth.
	var ringed := Item.from_dict({"type": "Gold Ring", "rarity": "common", "level": 1,
			"stats": {"drop_rate": 5.0, "time_on_hit": 1.0}, "mods": []})
	_check(ringed != null, "a Gold Ring from an older save loads")
	if ringed != null:
		_check(is_equal_approx(float(ringed.base_stats().get("time_on_hit", 0.0)), 1.0),
				"with the Time on Hit it was found with")
		_check(is_equal_approx(float(ringed.base_stats().get("drop_rate", 0.0)), 5.0), "and its drop rate")
	_check(not LootTable.stats_of("Gold Ring").has("time_on_hit"), "though a ring found today has none")
	# A stat the game no longer has at all is dropped on the way in, and a kind it no longer has
	# drops the whole piece: that is the migration for the health and the mage's gear that went.
	var gone := Item.from_dict({"type": "Wooden Armour", "rarity": "common", "level": 1,
			"stats": {"armor": 5.0, "health": 10.0}, "mods": [{"id": "added_health", "value": 8}]})
	_check(gone != null and gone.base_stats() == {"armor": 5.0} and gone.mods.is_empty(),
			"a retired stat and a retired modifier are dropped")
	_check(Item.from_dict({"type": "Linen Robe", "rarity": "common", "level": 1}) == null,
			"and a retired kind is dropped whole")
	return true


## The kinds and their materials: how the drops are split between them, what a kind's power is worth
## against another's, what a material is worth on top of it, and the promise that the eight pieces the
## game shipped with are worth exactly what they always were.
func _test_kinds() -> bool:
	# What each slot was worth before there were kinds. Widening the table must not quietly change
	# which socket the player is filling -- only which of that socket's pieces turns up.
	var was := {"helmet": 3, "boots": 4, "weapon": 3, "offhand": 6, "body": 2, "ring": 2, "amulet": 1}
	var weights := {}
	var total := 0
	var was_total := 0
	for slot: String in was:
		was_total += int(was[slot])
	for kind: String in LootTable.KINDS:
		var slot := str(LootTable.KINDS[kind]["slot"])
		var weight := int(LootTable.KINDS[kind]["weight"])
		if slot == SkillTree.SLOT:
			continue
		_check(weight > 0 or kind in ["broken_sword", "broken_torch"], "%s can come up at all" % kind)
		weights[slot] = int(weights.get(slot, 0)) + weight
		total += weight
	_check(weights.size() == was.size(), "there are still seven slots (%s)" % [weights.keys()])
	for slot: String in was:
		var share := float(weights.get(slot, 0)) / total
		var want := float(was[slot]) / was_total
		_check(is_equal_approx(share, want),
				"the %s slot is %.4f of what drops, not the %.4f it always was" % [slot, share, want])

	# A kind's power is what makes a dagger a dagger: one base damage, three weapons out of it.
	var blades := {}
	for type: String in ["Bone Knife", "Wooden Sword", "Wooden Greatsword"]:
		blades[type] = float(Item.scaled_stats(type, 10)["damage"])
	_check(blades["Bone Knife"] < blades["Wooden Sword"]
			and blades["Wooden Sword"] < blades["Wooden Greatsword"],
			"a dagger hits under a sword hits under a greatsword: %s" % [blades])
	_check(LootTable.two_handed("Wooden Greatsword") and not LootTable.two_handed("Wooden Sword"),
			"and only the greatsword takes both hands")

	# A kind found in more than one material asks for an attribute past the first circle (`requirement`):
	# one with none would be the one piece of its level that goes on for nothing.
	for kind: String in LootTable.KINDS:
		if (LootTable.KINDS[kind]["tiers"] as Array).size() > 1:
			_check(LootTable.KINDS[kind].get("needs", "") in SkillTree.ATTRIBUTES, "%s asks for an attribute" % kind)

	# A piece's material is the one its own unlock level names, whichever place it has in its kind's
	# list: what its power and the loot filter read.
	for type in LootTable.items():
		var row: Dictionary = LootTable.ITEMS[type]
		var levels: Array = LootTable.KINDS[row["kind"]].get("tier_levels", LootTable.TIER_MIN_LEVEL)
		_check(int(row["material"]) == LootTable.TIER_MIN_LEVEL.find(int(levels[row["tier"]])),
				"%s is the material found from level %d (%d)" % [type, levels[row["tier"]], row["material"]])

	# A material is more of every quantity and no more of a chance or a rate: a steel shield holds
	# more armour than a wooden one and blocks exactly as often. Read at level 20, where a dagger's
	# damage is big enough that a fifth of it survives the rounding to whole points.
	for kind: String in LootTable.KINDS:
		if LootTable.KINDS[kind].has("tier_stats"):
			continue   # the torch, which writes each material's Sight out rather than multiplying it
		var tiers: Array = LootTable.KINDS[kind]["tiers"]
		for tier in range(1, tiers.size()):
			var under := Item.scaled_stats(str(tiers[tier - 1]), 20)
			var over := Item.scaled_stats(str(tiers[tier]), 20)
			for stat: String in under:
				var held: bool = stat in LootTable.CHANCE_STATS or stat in LootTable.RATE_STATS
				if held:
					_check(is_equal_approx(float(over[stat]), float(under[stat])),
							"%s has the same %s as %s" % [tiers[tier], stat, tiers[tier - 1]])
				else:
					_check(float(over[stat]) > float(under[stat]),
							"%s is worth more %s than %s" % [tiers[tier], stat, tiers[tier - 1]])

	# The torch is the one kind a level says nothing to at all: it shows how far it lights the way,
	# and only the material moves that.
	for level in [1, 30]:
		_check(Item.scaled_stats("Wooden Torch", level) == {"sight": 1.0},
				"a level-%d Wooden Torch is 1 Sight (%s)"
						% [level, Item.scaled_stats("Wooden Torch", level)])
		_check(Item.scaled_stats("Blazing Torch", level) == {"sight": 2.0},
				"a level-%d Blazing Torch is 2 Sight (%s)"
						% [level, Item.scaled_stats("Blazing Torch", level)])

	# The pieces the game shipped with are the plainest of their kind and carry no power of their own,
	# so every one of them is worth exactly what it was before any of this. The torch is not among
	# them: it gave up what it showed before (energy shield and regen, both since retired, and crit damage) for Sight.
	for level in [1, 10, 30]:
		for type: String in ["Leather Helmet", "Leather Boots", "Wooden Sword", "Wooden Shield",
				"Wooden Armour", "Gold Ring", "Ruby Amulet"]:
			var stats := Item.scaled_stats(type, level)
			for stat: String in stats:
				var raw := LootTable.scale(stat, float(LootTable.stats_of(type)[stat]), level)
				var want := snappedf(raw, 0.1) if stat in LootTable.RATE_STATS else float(roundi(raw))
				_check(is_equal_approx(float(stats[stat]), want),
						"a level-%d %s has %s %s, not the %s the curve alone gives it"
								% [level, type, stats[stat], stat, want])

	# Item rarity is the jewellery's line and nobody else's, and gold find's band is written flat so
	# that The Tithe reads the same at level 30 as at level 1.
	for type in LootTable.items():
		var jewel: bool = LootTable.slot_of(type) in ["ring", "amulet"] or type == "Intelligence Node"
		_check(("added_item_rarity" in ModifierTable.pool_for(type)) == jewel,
				"%s %s roll item rarity" % [type, "should" if jewel else "should not"])
	_check(ModifierTable.band_for("added_gold_find", 30) == ModifierTable.band_for("added_gold_find", 1),
			"gold find's band is the same at level 30 as at level 1 (%s)"
					% [ModifierTable.band_for("added_gold_find", 30)])
	return true


## What the difference between two pieces comes to, with no scene to read it off. The union of both
## sides, the sign, and that a difference too small to print is left out rather than shown as zero.
func _test_deltas() -> bool:
	var better := Item.new()
	better.type = "Wooden Sword"
	better.rarity = ItemRarity.Rarity.RARE
	better.level = 1
	better.stats = {"damage": 20.0, "crit_chance": 6.0, "armor": 5.0}
	var worse := Item.new()
	worse.type = "Wooden Sword"
	worse.rarity = ItemRarity.Rarity.COMMON
	worse.level = 1
	worse.stats = {"damage": 12.0, "crit_chance": 6.0, "dodge": 30.0}

	# What the swap takes off is a list now, because a two-hander takes two pieces off for one going on.
	var off: Array[Item] = [worse]
	var change := ItemDetails.deltas(better, off)
	_check(change.get("damage") == 8.0, "a stat both have is the difference: %s" % change.get("damage"))
	_check(change.get("armor") == 5.0, "a stat only the new piece has is the whole of it")
	_check(change.get("dodge") == -30.0, "and one only the old piece has is the whole of it, lost")
	_check(not change.has("crit_chance"), "a stat that does not move is not mentioned at all")

	# Nothing rounds to zero on the line, either. An "+0 Armour" line says a stat changed and then
	# says it did not, so the pieces are compared as the numbers the player can actually see.
	var hair := Item.new()
	hair.type = "Wooden Sword"
	hair.rarity = ItemRarity.Rarity.COMMON
	hair.level = 1
	hair.stats = {"damage": 12.4, "attack_speed": 1.02}
	var hair_worse := Item.new()
	hair_worse.type = "Wooden Sword"
	hair_worse.rarity = ItemRarity.Rarity.COMMON
	hair_worse.level = 1
	hair_worse.stats = {"damage": 12.0, "attack_speed": 1.0}
	var hairs: Array[Item] = [hair_worse]
	_check(ItemDetails.deltas(hair, hairs).is_empty(),
			"a difference too small to print is left out")

	# And the spelling, which lives beside stat_line for the reason stat_line gives.
	_check(LootTable.stat_delta("damage", 8.0) == "+8 Damage", "a gain is written with its sign")
	_check(LootTable.stat_delta("dodge", -30.0) == "-30 Dodge", "and a loss with its own")
	_check(LootTable.stat_delta("block", 3.0) == "+0.3s Block", "and seconds say they are seconds")
	_check(LootTable.stat_line("time_on_hit", 12.0) == "1.2s Time on Hit", "kept in tenths, written in seconds")
	_check(ModifierTable.line({"id": "added_block", "value": 2}) == "+0.2s Block", "a roll the same way")
	_check(LootTable.stat_delta("crit_chance", 3.0) == "+3% Crit Chance", "a percentage keeps its sign")
	_check(LootTable.stat_delta("attack_speed", 0.3) == "+0.3/s Attack Speed", "and so does a rate")
	_check(LootTable.stat_line("damage", 5.0) == "5 Damage", "a base stat leads with its number too")
	return true


## Selecting a piece: the doll stays, the worn piece is the hover card's to show under Alt, and a ring
## gets a Swap beside its Equip.
func _test_comparing() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	var weak := _piece(ItemRarity.Rarity.COMMON, 1)
	var strong := _piece(ItemRarity.Rarity.RARE, 9)
	main.inventory.add(weak)
	main.inventory.equip(weak, Equipment.Socket.WEAPON)
	main.inventory.add(strong)
	main._on_bag_pressed()
	for i in 2:
		await process_frame
	_check(not _socket_squares(main).is_empty(), "with nothing selected the page is the doll")

	main.bag_page._select_item(main.inventory.items.find(strong))
	for i in 2:
		await process_frame
	_check(not _socket_squares(main).is_empty() and main.bag_page._worn_panel.visible,
			"selecting a sword leaves the doll standing")
	var block := _texts(main.bag_page)
	_check(not (weak.display_name() in block), "and writes nothing about the sword it would replace: %s" % block)
	# That is the hover card's to say, under Alt.
	var cards: Array[Node] = main._character.get_parent().get_children().filter(
			func(node: Node) -> bool: return node is ItemCard)
	_check(cards.size() == 1 and (cards[0] as ItemCard).worn_for(strong) == weak,
			"Alt on the card holds the sword up against the one worn")
	# Nothing on the page says what the swap would be worth in signed numbers either.
	var replaced: Array[Item] = [weak]
	var change := ItemDetails.deltas(strong, replaced)
	_check(change.has("damage") and change["damage"] > 0.0, "the better sword hits harder")
	for stat: String in change:
		_check(not (LootTable.stat_delta(stat, change[stat]) in block),
				"and the page says nothing about what %s would do: %s" % [stat, block])

	# Two rings worn and a third selected: Equip left over Equip right, each onto its own finger.
	var rings: Array[Item] = []
	for level in [2, 3, 4]:
		var ring := Item.new()
		ring.type = "Gold Ring"
		ring.rarity = ItemRarity.Rarity.COMMON
		ring.level = level
		ring.stats = Item.scaled_stats(ring.type, level)
		main.inventory.add(ring)
		rings.append(ring)
	main.inventory.equip(rings[0], Equipment.Socket.RING_LEFT)
	main.inventory.equip(rings[1], Equipment.Socket.RING_RIGHT)
	main.bag_page._select_item(main.inventory.items.find(rings[2]))
	var faces: Array = main.bag_page._action_box.get_children().map(func(button: Node) -> String:
			return (button as Button).text)
	_check(faces.slice(0, 2) == ["Equip left", "Equip right"] and not faces.has("Equip"),
			"a ring has Equip left over Equip right: %s" % [faces])
	var right: Button = main.bag_page.action("Equip right")
	_check(right != null and rings[1].display_name() in right.tooltip_text,
			"each naming the ring it takes off")
	main.bag_page._select_item(main.inventory.items.find(strong))
	_check(main.bag_page.action("Equip") != null and main.bag_page.action("Equip left") == null,
			"a sword has the one Equip")
	main.bag_page._select_item(main.inventory.items.find(rings[2]))
	main.bag_page.action("Equip right").pressed.emit()
	_check(main.inventory.equipment.item_at(Equipment.Socket.RING_RIGHT) == rings[2]
			and main.inventory.equipment.item_at(Equipment.Socket.RING_LEFT) == rings[0],
			"and Equip right replaces the right ring")
	# With the right finger bare, Shift-click takes it, though Equip left stands first.
	main.inventory.unequip(Equipment.Socket.RING_RIGHT)
	main.bag_page._select_item(main.inventory.items.find(rings[1]))
	main.bag_page._press_action(true)
	_check(main.inventory.equipment.item_at(Equipment.Socket.RING_RIGHT) == rings[1]
			and main.inventory.equipment.item_at(Equipment.Socket.RING_LEFT) == rings[0],
			"Shift-click puts a ring on the emptiest finger")

	main.bag_page._select_item(-1)
	await process_frame
	_check(_socket_squares(main).size() == Equipment.sockets().size(),
			"clearing the selection leaves the doll standing, with every socket on it")
	# The doll folds away by the same flag, so it stays put away when a piece is opened.
	main.bag_page._on_fold_pressed()
	_check(not main.bag_page._worn_panel.visible and main.bag_page._show_button.visible,
			"Hide takes the doll away too and leaves Show in its place")
	main.bag_page._select_item(0)
	_check(not main.bag_page._worn_panel.visible, "and the doll stays hidden with a piece selected")
	main.bag_page._on_fold_pressed()
	main.bag_page._select_item(-1)
	_check(main.bag_page._worn_panel.visible and not main.bag_page._show_button.visible,
			"Show brings the doll back")

	# A greatsword closes the offhand, and the doll says so: that socket is drawn wearing the weapon's
	# own icon faded rather than left looking like somewhere to fill, and a press on it opens the piece
	# that is actually in that hand.
	var heavy := _plain("Wooden Greatsword")
	main.inventory.add(heavy)
	main.inventory.equip(heavy, Equipment.Socket.WEAPON)
	main.bag_page._select_item(-1)
	await process_frame
	var offhand: Control = null
	for slot: Control in _socket_squares(main):
		if slot.get_meta("socket") == Equipment.Socket.OFFHAND:
			offhand = slot
	_check(offhand != null and offhand.get_child_count() > 0,
			"the offhand socket is drawn taken while a greatsword is worn")
	if offhand != null:
		_click_doll(main.bag_page, offhand.position + offhand.size / 2.0)
		_check(main.bag_page._worn_selected == Equipment.Socket.WEAPON,
				"and a click on it opens the greatsword")
	# A real click, through the viewport: the doll is redrawn under it, and a Control freed in its own
	# gui_input never marks the event handled, so the map behind it took the click.
	for slot: Control in _socket_squares(main):
		if slot.get_meta("socket") != Equipment.Socket.WEAPON:
			continue
		var at: Vector2 = slot.get_global_transform_with_canvas() * (slot.size / 2.0)
		for down: bool in [true, false]:
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = down
			click.position = at
			click.global_position = at
			root.push_input(click, true)
			if down:
				_check(not main.map._pressing, "a press on the doll never reaches the map")
		_check(main.bag_page._worn_selected == -1, "and letting go closes the piece")
	main._on_left_page_closed()
	main.queue_free()
	_clear_save()
	return true


## The world's curses as the inventory keeps them: chosen for the world to come and the next world's
## only once it is transcended into, saved by name, paid in `stats()` and told to the fight by
## `effects()`. What each does to a fight is test_combat's.
func _test_curses() -> bool:
	_clear_save()
	var leaving := Inventory.new()
	leaving.curses = [Curses.IRON_FOES]
	leaving.pending_curses = [Curses.THICK_FOG, Curses.BLOODTHIRST, "one this build never had"]
	_check(Curses.effect(Curses.IRON_FOES) in leaving.effects()
			and not Curses.effect(Curses.THICK_FOG) in leaving.effects(),
			"the fight hears of the world's curses, and not of the ones only chosen")
	_check(float(leaving.stats().get("gold_find", 0.0)) == float(Curses.CURSES[Curses.IRON_FOES]["stats"]["gold_find"]),
			"and Iron Foes pays its gold find in the stats")
	var next := leaving.transcended()
	_check(next.curses == [Curses.BLOODTHIRST, Curses.THICK_FOG] and next.pending_curses.is_empty(),
			"the chosen ones are the next world's, the old world's are left in it (%s)" % [next.curses])
	var paid := 0.0
	for curse: String in next.curses:
		paid += float(Curses.CURSES[curse].get("stats", {}).get("item_rarity", 0.0))
	_check(paid > 0.0 and float(next.stats().get("item_rarity", 0.0)) == paid
			and float(next.stats().get("gold_find", 0.0)) == 0.0, "with what they pay")
	_check(next.total() == 1 and next.items[0].type == LootTable.BROKEN_TORCH
			and float(next.items[0].effective_stats().get("sight", 0.0)) == 1.0 and next.items[0].mods.is_empty(),
			"the Thick Fog's world begins with a Broken Torch: a ring of sight and nothing else")
	_check(next.equip(next.items[0], Equipment.Socket.OFFHAND) and float(next.stats().get("sight", 0.0)) == 1.0,
			"which goes in the offhand and sees")
	_check(leaving.transcended().total() == 1 and Inventory.new().transcended().total() == 0,
			"and a world under no fog begins with nothing")
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for roll in 3000:
		var dropped := LootTable.roll("Goblin", rng, true, 30)
		_check(dropped.type != LootTable.BROKEN_TORCH, "no roll ever deals a Broken Torch")

	# Saved by name, and an older save is a world under none.
	next.save(TEST_PATH)
	_check(Inventory.load_from(TEST_PATH).curses == next.curses, "the curses come back off the save")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	old_save["curses"] = ["thick_fog", "retired_curse", 7]
	SafeFile.write(TEST_PATH, JSON.stringify(old_save))
	_check(Inventory.load_from(TEST_PATH).curses == [Curses.THICK_FOG], "one this build does not know is dropped by name")
	old_save.erase("curses")
	old_save["version"] = 17
	SafeFile.write(TEST_PATH, JSON.stringify(old_save))
	var problem := []
	_check(Inventory.load_from(TEST_PATH, problem).curses.is_empty() and problem.is_empty(),
			"a version 17 save is a world under none")
	_clear_save()

	# Hard Lessons' pay: every skill point counts double, flat and percent alike.
	var student := Inventory.new()
	student.level = 10
	student.skills.stones["0"] = _node("Strength Node", "added_damage")
	_check(student.skills.rank_up("0", student.level), "a point goes into a strength stone")
	var taught := float(student.stats().get("damage", 0.0))
	student.curses = [Curses.HARD_LESSONS]
	_check(taught > 0.0 and float(student.stats().get("damage", 0.0)) == taught * 2.0 and student.skill_worth() == 2,
			"under Hard Lessons the point is worth double (%s against %s)" % [student.stats().get("damage", 0.0), taught])
	_check(Inventory.new().skill_worth() == 1, "and nothing doubles it without the curse")
	_check(student.effects().count(Curses.effect(Curses.HARD_LESSONS)) == 1, "the fight hears of it once")

	# The Long Winter's and the Ring of Walls' pay: more damage for every wall down in this world, the
	# two one multiplier.
	var winter := Inventory.new()
	winter.equipment.equip(Equipment.Socket.WEAPON, _piece(ItemRarity.Rarity.COMMON, 1))
	var bare := float(winter.stats()["damage"])
	winter.curses = [Curses.LONG_WINTER]
	_check(is_equal_approx(float(winter.stats()["damage"]), bare), "with no wall down the Long Winter pays nothing")
	winter.credit_walls(2)
	var per := Curses.WINTER_WALL_DAMAGE * 2
	_check(is_equal_approx(float(winter.stats()["damage"]), bare * (1.0 + per / 100.0)),
			"two walls down are +%d%% damage" % per)
	winter.curses = [Curses.LONG_WINTER, Curses.RING_OF_WALLS]
	per = (Curses.WINTER_WALL_DAMAGE + Curses.RING_WALL_DAMAGE) * 2
	_check(is_equal_approx(float(winter.stats()["damage"]), bare * (1.0 + per / 100.0)),
			"and the Ring of Walls' adds to it")
	_check(winter.transcended().walls_credited == 0, "a new world starts with none down")

	# An ascended find: one plus more, every modifier still in its place in the band.
	var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 10)
	var before: Array = piece.mods.duplicate(true)
	var tiers: Array = piece.mods.map(piece.tier_of)
	_check(not before.is_empty(), "a rare has modifiers to move")
	piece.ascend()
	_check(piece.plus == 1 and piece.mod_level() == 10 + Item.PLUS_LEVELS, "ascending is one plus (%d)" % piece.plus)
	# In its own tier's band: a modifier rolled under the top moves from that tier to the same tier
	# of the lifted piece, not from the top band to the top band.
	for i in before.size():
		_check(int(piece.mods[i]["value"]) == ModifierTable.rescaled(str(before[i]["id"]), int(before[i]["value"]),
				int(tiers[i]), piece.tier_of(piece.mods[i])), "%s keeps its place in the band" % before[i]["id"])
	return true


## The second batch of curses as the inventory keeps them: what they do to the stats, the skills, the
## log, the heirlooms' doll and the walls' pay, and what two of them write into the save.
func _test_more_curses() -> bool:
	_clear_save()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED

	# Pacifist Hands: the hands swing for themselves, so even bare ones do, and a camp can be held.
	var pacifist := Inventory.new()
	_check(float(pacifist.stats().get("attack_speed", 0.0)) == 0.0, "bare hands swing at nothing of their own")
	pacifist.curses = [Curses.PACIFIST_HANDS]
	_check(is_equal_approx(float(pacifist.stats()["attack_speed"]), Inventory.PACIFIST_SWINGS * Inventory.PACIFIST_FASTER),
			"under Pacifist Hands they swing (%s a second)" % pacifist.stats()["attack_speed"])

	# The Specialist: one branch, and every point worth half again -- added to Hard Lessons', never compounded.
	# The root has one slot today (`SkillTree.ROOT_CONNECTORS`), so two branches are stood in by hand: the
	# rule is the branch's, whatever the root holds.
	var student := Inventory.new()
	student.level = 10
	var first := "1"
	var second := "2"
	student.skills.stones[first] = _node("Strength Node", "added_damage")
	student.skills.stones[second] = _node("Intelligence Node", "added_crit")
	_check(student.rank_up_skill(first), "a point goes into the first branch")
	_check(student.why_not_skill(second).is_empty(), "and without the curse the second branch is open")
	student.curses = [Curses.SPECIALIST]
	_check("Specialist" in student.why_not_skill(second) and not student.rank_up_skill(second)
			and student.skills.rank_of(second) == 0,
			"a Specialist is refused a second branch (%s)" % student.why_not_skill(second))
	student.curses = []
	student.skills.ranks.erase(first)
	student.skills.stones["1"].mods.append({"id": "added_stone_ranks", "value": 1})
	student.curses = [Curses.SPECIALIST]
	_check(student.rank_up_skill(first) and not "Specialist" in student.why_not_skill(first),
			"and never the branch already begun")
	_check(student.rank_up_skill("") and student.why_not_skill(first).is_empty(),
			"the root is on no branch: a Specialist puts points in it beside the one begun")
	_check(is_equal_approx(student.skill_worth(), 1.5), "every point is worth half again")
	student.curses = [Curses.HARD_LESSONS, Curses.SPECIALIST]
	_check(is_equal_approx(student.skill_worth(), 2.5), "and beside Hard Lessons the two add (%s)" % student.skill_worth())

	# Forgotten: no damage off the log this world, and its new finds count twice from the next one on.
	var ids := UniqueTable.ids()
	var collector := Inventory.new()
	collector.note_unique(ids[0])
	var was := collector.collection_bonus()
	collector.curses = [Curses.FORGOTTEN]
	_check(was == UniqueTable.COLLECTION_DAMAGE and collector.collection_bonus() == 0, "the Forgotten's log adds nothing")
	_check(collector.note_unique(ids[1]) and collector.uniques_doubled == [ids[1]], "a find made under it is marked")
	var remembered := collector.transcended()
	_check(remembered.collection_bonus() == 3 * UniqueTable.COLLECTION_DAMAGE,
			"and counts twice in every world after (%d%%)" % remembered.collection_bonus())

	# Lone Heir: the world begins with the heirlooms' doll bare, one may go on, and the heirloom made
	# at its end is made +1.
	var heir := Inventory.new()
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 5)
	var boots := Item.rolled("Leather Boots", ItemRarity.Rarity.RARE, rng, 5)
	for piece: Item in [sword, boots]:
		heir.stash().items.append(piece)
		_check(heir.stash().equip(piece, heir.stash().equipment.sockets_for(piece)[0]), "%s goes on" % piece.type)
	heir.pending_curses = [Curses.LONE_HEIR]
	var lone := heir.transcended()
	_check(lone.stash().equipment.worn.is_empty() and lone.stash().total() == 2, "the Lone Heir's doll begins bare")
	var one: Item = lone.stash().items[0]
	var other: Item = lone.stash().items[1]
	_check(lone.stash().equip(one, lone.stash().equipment.sockets_for(one)[0]), "one heirloom goes on")
	var socket: Equipment.Socket = lone.stash().equipment.sockets_for(other)[0]
	_check("Lone Heir" in lone.stash().why_not_equip(other, socket) and not lone.stash().equip(other, socket),
			"and a second is refused (%s)" % lone.stash().why_not_equip(other, socket))
	var same_socket := Item.rolled(one.type, ItemRarity.Rarity.COMMON, rng, 1)
	lone.stash().items.append(same_socket)
	_check(lone.stash().can_equip(same_socket, lone.stash().equipment.sockets_for(same_socket)[0]),
			"but the one worn can be swapped for another")
	_check(lone.most_worn == -1 and heir.stash().most_worn == -1,
			"the ordinary doll, and an uncursed world's heirlooms, wear what they like")
	var kept := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 8)
	lone.items.append(kept)
	_check(lone.make_heirloom(kept) and kept.plus == 1, "the heirloom made at the end of that world is +1")
	var plain_kept := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 8)
	heir.items.append(plain_kept)
	_check(heir.make_heirloom(plain_kept) and plain_kept.plus == 0, "and no other world's is")

	# The skulls are Gollux's alone: walls broken and curses carried pay none, each depth won is one
	# skull, and the depth and its skulls are kept through a transcension.
	var climber := Inventory.new()
	climber.walls_credited = 3
	climber.curses = [Curses.BLOODTHIRST, Curses.IRON_FOES]
	_check(climber.skull_allowance() == 0, "three walls and three skulls carried earn nothing")
	var delver := Inventory.new()
	delver.walls_credited = 1
	delver.dungeon_depth = 4
	delver.curses = [Curses.BLOODTHIRST, Curses.IRON_FOES, Curses.LONG_WINTER]
	_check(delver.skull_allowance() == 4 and delver.transcended().skull_allowance() == 4,
			"four depths won are four skulls, and again in the next world (%d)" % delver.skull_allowance())
	_check(Curses.skulls_of([Curses.LONG_WINTER, Curses.IRON_FOES]) == 4
			and Curses.fits(Curses.IRON_FOES, [Curses.LONG_WINTER], 4)
			and not Curses.fits(Curses.BLOODTHIRST, [Curses.LONG_WINTER], 4)
			and not Curses.fits(Curses.BERSERKERS_WORLD, [Curses.PACIFIST_HANDS], 99),
			"a curse fits the skulls left, and still not beside one it cannot stand with")

	# No Second Chances pays in loot, as a row's `stats`.
	var gambler := Inventory.new()
	var plain_stats := gambler.stats()
	gambler.curses = [Curses.NO_SECOND_CHANCES]
	_check(float(gambler.stats().get("drop_rate", 0.0)) == float(plain_stats.get("drop_rate", 0.0)) + 40.0
			and float(gambler.stats().get("item_rarity", 0.0)) == float(plain_stats.get("item_rarity", 0.0)) + 40.0,
			"No Second Chances adds drop rate and item rarity")

	# The Homeland's lands reach the fight, and both new lists come back off the save.
	var settler := Inventory.new()
	settler.curses = [Curses.HOMELAND]
	settler.homeland = ["grass", "forest"]
	settler.uniques_found = [ids[0]]
	settler.uniques_doubled = [ids[0]]
	_check(Curses.HOME_PREFIX + "forest" in settler.effects() and Curses.effect(Curses.HOMELAND) in settler.effects(),
			"the fight is told which lands are home")
	settler.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(back.homeland == settler.homeland and back.uniques_doubled == settler.uniques_doubled, "both lists are saved")
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	old_save["uniques_doubled"] = [ids[0], ids[0], "no such unique", 4]
	old_save.erase("homeland")
	old_save["version"] = 19
	SafeFile.write(TEST_PATH, JSON.stringify(old_save))
	var older := Inventory.load_from(TEST_PATH)
	_check(older.homeland.is_empty() and older.uniques_doubled == [ids[0]],
			"a version 19 save has no homeland, and junk is dropped")
	_check(settler.transcended().homeland.is_empty(), "the next world chooses its own")
	_clear_save()
	return true
