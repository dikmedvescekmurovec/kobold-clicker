extends "res://tests/inventory_base.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   python tests/run_all.py inventory_uniques
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.


func _run() -> void:
	_clear_save()
	_check(_test_drops_scroll() == true, "drops scroll tests ran to the end")
	_check(_test_fight_ledger() == true, "fight ledger tests ran to the end")
	_check(_test_unique_items() == true, "unique item tests ran to the end")
	_check(await _test_unique_stats() == true, "unique stat tests ran to the end")
	_check(_test_attribute_uniques() == true, "attribute unique tests ran to the end")
	_check(_test_rank_four_uniques() == true, "rank IV unique tests ran to the end")
	_check(await _test_collection() == true, "collection log tests ran to the end")
	_check(await _test_achievements() == true, "achievement tests ran to the end")
	_check(await _test_character_page() == true, "character page tests ran to the end")
	_check(await _test_character_sheet() == true, "character sheet tests ran to the end")
	_check(await _test_item_generator() == true, "item generator tests ran to the end")
	_clear_save()
	_report("inventory: uniques")


func _test_unique_items() -> bool:
	_clear_save()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var axe := Item.rolled_unique("headsman", rng, 7)
	_check(axe.rarity == ItemRarity.Rarity.UNIQUE and axe.type == "Wooden Sword" and axe.level == 7,
			"a Headsman is a level-7 unique sword")
	_check(axe.display_name() == "Headsman" and not axe.effect_text().is_empty(), "with a name and a rule of its own")
	_check(axe.base_stats() == Item.scaled_stats("Wooden Sword", 7), "and a sword's numbers at its level")
	var ids := []
	for mod in axe.mods:
		ids.append(mod["id"])
		var band := ModifierTable.band_for(str(mod["id"]), axe.tier_of(mod))
		_check(int(mod["value"]) >= int(band[0]) and int(mod["value"]) <= int(band[1]),
				"%s rolled inside its band" % mod["id"])
	_check(ids == UniqueTable.UNIQUES["headsman"]["mods"], "it carries its row's modifiers, in order (%s)" % [ids])
	_check(Item.rolled_unique("headsman", rng, 7).mods.map(func(m: Dictionary) -> String: return m["id"]) == ids,
			"and so does every other Headsman")

	var back := Item.from_dict(JSON.parse_string(JSON.stringify(axe.to_dict())))
	_check(back != null and back.unique == "headsman" and back.rarity == ItemRarity.Rarity.UNIQUE
			and back.level == 7 and back.mods == axe.mods, "it survives the save")
	# Stat by stat: the save sorts its keys, and two dictionaries in a different order are not `==`.
	for stat: String in axe.effective_stats():
		_check(is_equal_approx(float(back.effective_stats().get(stat, -1.0)), float(axe.effective_stats()[stat])),
				"its %s survives too" % stat)
	var retired := axe.to_dict()
	retired["unique"] = "a unique nobody wrote"
	_check(Item.from_dict(retired) == null, "one this build no longer has is dropped by name")
	_check(not _piece(ItemRarity.Rarity.RARE, 3).to_dict().has("unique"), "an ordinary piece's save says nothing of it")

	for orb: String in OrbTable.ORBS:
		_check(OrbTable.can_apply(orb, axe) == (orb in ["Orb of Divinity", "Orb of Chaos"]), "%s on a unique" % orb)
	_check(not OrbTable.why_not("Orb of Alchemy", axe).is_empty(), "and the refusal is said")
	OrbTable.apply("Orb of Chaos", axe, rng)
	_check(axe.mods.map(func(m: Dictionary) -> String: return m["id"]) == ids, "Chaos moves the tiers and nothing else")
	OrbTable.apply("Orb of Divinity", axe, rng)
	_check(axe.mods.map(func(m: Dictionary) -> String: return m["id"]) == ids, "Divine moves the values and nothing else")

	var ring := Item.rolled_unique("the_tithe", rng, 5)
	_check(ring.effective_stats().get("gold_find", 0.0) > 0.0, "The Tithe's gold find is a stat it is worth")
	var bag := _hero()
	for id: String in ["knucklebone_ring", "knucklebone_ring", "meadowstriders"]:
		var piece := Item.rolled_unique(id, rng, 3)
		bag.items.append(piece)
		_check(bag.equip(piece, bag.equipment.sockets_for(piece)[0]), "%s goes on" % id)
	var effects := bag.effects()
	_check(effects.count("knucklebone") == 2 and "home:grass" in effects,
			"what is worn reaches the fight (%s)" % [effects])
	_check(Inventory.new().effects().is_empty(), "and bare hands change nothing")

	# Found is found, and the log is saved with everything else.
	_check(bag.note_unique("headsman") and not bag.note_unique("headsman"), "a unique is logged once")
	_check(not bag.note_unique("a unique nobody wrote") and not bag.note_unique(""), "and only a real one")
	bag.save(TEST_PATH)
	var loaded := Inventory.load_from(TEST_PATH)
	_check(loaded.uniques_found == ["headsman"], "the log survives the save (%s)" % [loaded.uniques_found])
	_check(loaded.equipment.effects().count("knucklebone") == 2, "and so does what is worn")

	# Every unique in the log is worth a percent of damage, worn or not.
	var worn: float = bag.equipment.totals(bag.skills.flat(), bag.skills.percent())["damage"]
	_check(bag.collection_bonus() == UniqueTable.COLLECTION_DAMAGE and worn > 0.0
			and is_equal_approx(float(bag.stats()["damage"]), worn * 1.01), "one found is 1% more damage")
	bag.note_unique("rimeplate")
	_check(is_equal_approx(float(bag.stats()["damage"]), worn * 1.02), "and two are 2%")

	# The ledger is what writes the log, as a unique lands, in any fight.
	var tile_bag := Inventory.new()
	FightLedger.new(tile_bag, TEST_PATH).add_loot(Item.rolled_unique("rimeplate", rng, 2))
	_check(tile_bag.uniques_found == ["rimeplate"], "a tile fight logs a unique as it lands")
	var run_bag := Inventory.new()
	FightLedger.new(run_bag, TEST_PATH, true).add_loot(Item.rolled_unique("stonebreaker", rng, 2))
	_check(run_bag.uniques_found == ["stonebreaker"], "and so does a run")
	_clear_save()
	return true


## The attribute uniques: the points added up over both dolls, the Echo, the Crown and the Brand, and
## what each of the others turns them into. The blows the Patchwork Coat, the Purist's Seal and the
## Brawler's Wraps change are `test_combat`'s.
func _test_attribute_uniques() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var wear := func(bag: Inventory, piece: Item) -> void:
		bag.items.append(piece)
		_check(bag.equip(piece, bag.equipment.sockets_for(piece)[0]), "%s goes on" % piece.display_name())
	var lined := func(piece: Item, lines: Dictionary) -> Item:
		piece.mods = []
		for id: String in lines:
			piece.mods.append({"id": id, "value": lines[id]})
		return piece
	var unique := func(id: String, lines := {}) -> Item:
		return lined.call(Item.rolled_unique(id, rng, 1), lines)
	var ring := func(lines: Dictionary) -> Item:
		var piece := Item.new()
		piece.type = "Iron Band"
		piece.stats = Item.scaled_stats(piece.type, 1)
		return lined.call(piece, lines)
	var armed := func(rings: Array) -> Inventory:
		var bag := _hero()
		wear.call(bag, _piece(ItemRarity.Rarity.COMMON, 5))
		for lines: Dictionary in rings:
			wear.call(bag, ring.call(lines))
		return bag

	# Both dolls add up, and the Echo counts the heirlooms' doll again.
	var bag: Inventory = armed.call([{"added_strength": 30, "added_intelligence": 10}])
	var heir := bag.stash()
	wear.call(heir, ring.call({"added_strength": 20, "added_dexterity": 40}))
	_check(bag.attributes() == {"strength": 50.0, "dexterity": 40.0, "intelligence": 10.0},
			"both dolls' attributes add up (%s)" % bag.attributes())
	_check(bag.stats()["strength"] == 50.0, "and the stats carry the sum")
	wear.call(bag, unique.call("heirlooms_echo"))
	_check(bag.attributes() == {"strength": 70.0, "dexterity": 80.0, "intelligence": 10.0},
			"the Echo counts the heirlooms' doll twice (%s)" % bag.attributes())

	# The two counts, over all sixteen pieces: the Echo carries lines of its own no longer.
	_check(bag.stats()["attribute_lines"] == 4 and bag.stats()["pure_pieces"] == 2,
			"four attribute lines, and the sword and the Echo without one (%s, %s)"
			% [bag.stats()["attribute_lines"], bag.stats()["pure_pieces"]])

	# The Crown of Accord: five times over while the lowest is within a tenth of the highest.
	var even: Inventory = armed.call([{"added_strength": 100, "added_dexterity": 95, "added_intelligence": 91}])
	wear.call(even, unique.call("crown_of_accord"))
	_check(even.attributes() == {"strength": 500.0, "dexterity": 475.0, "intelligence": 455.0},
			"the Crown counts balanced attributes five times (%s)" % even.attributes())
	var uneven: Inventory = armed.call([{"added_strength": 100, "added_dexterity": 95, "added_intelligence": 89}])
	wear.call(uneven, unique.call("crown_of_accord"))
	_check(uneven.attributes()["strength"] == 100.0, "and nothing once one falls behind")

	# The Zealot's Brand: the two lower counted as the highest, times its rank's number.
	var zeal: Inventory = armed.call([{"added_strength": 30, "added_dexterity": 60, "added_intelligence": 10}])
	wear.call(zeal, unique.call("zealots_brand"))
	var lifted := 60.0 * UniqueTable.dial("zealots_brand", "times", 1)
	_check(zeal.attributes() == {"strength": lifted, "dexterity": 60.0, "intelligence": lifted},
			"the Brand brings the lower two up to the highest (%s)" % zeal.attributes())
	_check(zeal.stats()["strength"] == lifted and zeal.stats()["dexterity"] == 60.0, "and so do the stats")
	_check(zeal.gear_attributes() == {"strength": 30.0, "dexterity": 60.0, "intelligence": 10.0},
			"while what the gear adds up to is what it always was")
	zeal.achievements["zealots_brand"] = UniqueTable.PEAK
	_check(zeal.attributes()["strength"] == 60.0 * UniqueTable.dial("zealots_brand", "times", UniqueTable.PEAK),
			"and at rank IV to its rank's times the highest (%s)" % zeal.attributes())

	# The Scholar's Circlet: intelligence gives damage at five times the rate, and no experience.
	var reader: Inventory = armed.call([{"added_intelligence": 50}])
	var plain: float = reader.stats()["damage"]
	_check(reader.stats()["xp_more"] == 10.0, "fifty intelligence is 10%% experience (%s)" % reader.stats()["xp_more"])
	wear.call(reader, unique.call("scholars_circlet"))
	_check(is_equal_approx(reader.stats()["damage"], plain * 1.5) and not reader.stats().has("xp_more"),
			"and under the Circlet 50%% damage instead (%s from %s)" % [reader.stats()["damage"], plain])
	_check(reader.attribute_gift("intelligence", 50.0) == ["damage", 50.0], "which the character page is told")

	# The Sage's Abacus: a percent more of every skill for every five intelligence.
	var sage: Inventory = armed.call([{"added_intelligence": 50}])
	wear.call(sage, unique.call("sages_abacus"))
	_check(is_equal_approx(sage.skill_worth(), 1.1), "fifty intelligence, skills 10%% stronger (%s)" % sage.skill_worth())

	# The four that turn points into another stat.
	var ogre: Inventory = armed.call([{"added_strength": 100}])
	var weak: float = ogre.stats()["damage"]
	wear.call(ogre, unique.call("ogres_knuckle"))
	_check(is_equal_approx(ogre.stats()["damage"] - weak, 10.0 * 1.2),
			"the Knuckle adds a tenth of the strength as flat damage (%s)" % (ogre.stats()["damage"] - weak))
	var fencer: Inventory = armed.call([{"added_dexterity": 50}])
	wear.call(fencer, unique.call("fencers_signet"))
	_check(fencer.stats()["time_on_hit"] == 5.0, "fifty dexterity is half a second of time on hit")
	var butcher: Inventory = armed.call([{"added_strength": 100}])
	wear.call(butcher, unique.call("butchers_cleaver"))
	_check(butcher.stats()["bleed"] == 5.0,
			"a hundred strength is 5%% bleed on the Cleaver (%s)" % butcher.stats().get("bleed"))
	var quick: Inventory = armed.call([{"added_dexterity": 50}])
	wear.call(quick, unique.call("quickdraw_boots"))
	_check(quick.stats()["spawn_speed"] == 50.0, "and fifty dexterity is 50%% spawn speed on the boots")

	# Every one of them reads its number at the rank the player has earned, and the card says the same.
	var at := func(id: String, key: String) -> float: return UniqueTable.dial(id, key, UniqueTable.PEAK)
	for bag_of: Inventory in [ogre, fencer, butcher, quick, reader, sage, even, bag]:
		for id: String in Achievements.ACHIEVEMENTS:
			bag_of.achievements[id] = UniqueTable.PEAK
	_check(is_equal_approx(ogre.stats()["damage"] - weak, 100.0 * at.call("ogres_knuckle", "share") / 100.0 * 1.2),
			"the Knuckle at IV (%s)" % (ogre.stats()["damage"] - weak))
	_check(fencer.stats()["time_on_hit"] == 50.0 / at.call("fencers_signet", "dexterity"), "the Signet at IV")
	_check(butcher.stats()["bleed"] == 100.0 / at.call("butchers_cleaver", "strength"), "the Cleaver at IV")
	_check(quick.stats()["spawn_speed"] == 50.0 * at.call("quickdraw_boots", "times"), "the Boots at IV")
	_check(reader.attribute_gift("intelligence", 50.0) == ["damage", 10.0 * at.call("scholars_circlet", "times")],
			"the Circlet at IV")
	_check(is_equal_approx(sage.skill_worth(), 1.0 + 50.0 / at.call("sages_abacus", "intelligence") / 100.0),
			"the Abacus at IV (%s)" % sage.skill_worth())
	_check(even.attributes()["strength"] == 100.0 * at.call("crown_of_accord", "times"), "the Crown at IV")
	# The Echo at III: past it, the plus it lifts the heirlooms by is `_test_rank_four_uniques`'.
	bag.achievements["heirlooms_echo"] = 3
	var again := UniqueTable.dial("heirlooms_echo", "times", 3) - 1.0
	_check(bag.attributes() == {"strength": 50.0 + 20.0 * again, "dexterity": 40.0 + 40.0 * again, "intelligence": 10.0},
			"the Echo at III (%s)" % bag.attributes())
	UniqueTable.ranks = {"ogres_knuckle": UniqueTable.PEAK}
	_check(Item.rolled_unique("ogres_knuckle", rng, 1).effect_text() == UniqueTable.effect_text("ogres_knuckle",
			UniqueTable.PEAK)
			and UniqueTable.effect_text("ogres_knuckle",
					UniqueTable.PEAK).contains("%d%%" % int(at.call("ogres_knuckle", "share"))),
			"and its card writes the rank's number")
	_check(UniqueTable._written(3.0) == "3" and UniqueTable._written(2.5) == "2.5",
			"a whole number is written without a point, and a half with one")
	_check(UniqueTable.effect_text("sages_abacus", 0).contains("every 5/4/3/2 intelligence")
			and UniqueTable.effect_text("hourglass_amulet", 0).contains("puts 1/1.5/2/3 seconds back"),
			"rank 0 writes every rank's numbers, four sentences at IV's wording")
	UniqueTable.ranks = {}
	return true


## The lines the uniques the inventory answers for gain at rank IV, each against rank III.
func _test_rank_four_uniques() -> bool:
	var iv := UniqueTable.PEAK
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var wear := func(bag: Inventory, piece: Item) -> void:
		bag.items.append(piece)
		_check(bag.equip(piece, bag.equipment.sockets_for(piece)[0]), "%s goes on" % piece.display_name())
	var lined := func(piece: Item, lines: Dictionary) -> Item:
		piece.mods = []
		for id: String in lines:
			piece.mods.append({"id": id, "value": lines[id]})
		return piece
	var ring := func(lines: Dictionary) -> Item:
		var piece := Item.new()
		piece.type = "Iron Band"
		piece.stats = Item.scaled_stats(piece.type, 1)
		return lined.call(piece, lines)
	var at := func(bag: Inventory, id: String, rank: int) -> Inventory:
		bag.achievements[id] = rank
		return bag

	# The Packmule's Harness: the bag holds more.
	var mule := Inventory.new()
	wear.call(mule, lined.call(Item.rolled_unique("packmule", rng, 1), {}))
	for i in Inventory.CAPACITY:
		mule.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	_check(at.call(mule, "packmule", 3).capacity() == Inventory.CAPACITY and mule.is_full(), "a full bag at III")
	_check(at.call(mule, "packmule", iv).capacity() == Inventory.CAPACITY + Inventory.PACKMULE_ROOM
			and not mule.is_full() and mule.room_left() == Inventory.PACKMULE_ROOM, "and room to spare at IV")
	_check(mule.stash().capacity() == Inventory.CAPACITY, "the heirlooms' stash is not the bag")

	# The Patchwork Coat: any piece may be worn, while the Coat stays on.
	var motley := Inventory.new()
	wear.call(motley, Item.rolled_unique("patchwork_coat", rng, 1))
	var deep := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 20)
	motley.items.append(deep)
	_check(not at.call(motley, "patchwork_coat", 3).why_not_equip(deep, Equipment.Socket.WEAPON).is_empty(),
			"a deep sword asks for its strength at III")
	_check(at.call(motley, "patchwork_coat", iv).why_not_equip(deep, Equipment.Socket.WEAPON).is_empty(),
			"and not at IV")
	var plate := Item.rolled("Wooden Armour", ItemRarity.Rarity.COMMON, rng, 20)
	motley.items.append(plate)
	_check(not motley.why_not_equip(plate, Equipment.Socket.BODY).is_empty(),
			"but a piece that takes the Coat off asks all the same")

	# The Giant's Leafwrap: any piece may be worn while it stays on, at no rank, as the Coat at IV.
	var giant := Inventory.new()
	var wrap := Item.rolled_unique("giants_leafwrap", rng, 1)
	var heavy := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 20)
	giant.items.append(heavy)
	_check(not giant.why_not_equip(heavy, Equipment.Socket.WEAPON).is_empty(), "a deep sword asks for its strength")
	wear.call(giant, wrap)
	_check(giant.why_not_equip(heavy, Equipment.Socket.WEAPON).is_empty(), "and not under the Leafwrap")
	var mail := Item.rolled("Wooden Armour", ItemRarity.Rarity.COMMON, rng, 20)
	giant.items.append(mail)
	_check(not giant.why_not_equip(mail, Equipment.Socket.BODY).is_empty(),
			"but a piece that takes the Leafwrap off asks all the same")

	# The Hoardheart: a tenth more damage for every digit of the gold held.
	var hoarder := _hero()
	wear.call(hoarder, Item.rolled_unique("hoardheart", rng, 1))
	hoarder.gold = 0.0
	var poor := float(hoarder.stats()["damage"])
	hoarder.gold = 1000.0
	_check(hoarder.gold_digits() == 4 and is_equal_approx(float(hoarder.stats()["damage"]),
			poor * (1.0 + 4.0 * Inventory.HOARD_DIGIT / 100.0)), "a thousand gold is four digits of damage")
	hoarder.gold = 999.0
	_check(hoarder.gold_digits() == 3, "and 999 three")

	# The Heirloom's Echo: every heirloom one plus higher, its lines with it -- the piece itself untouched.
	var lowest := int(ModifierTable.band_for("added_strength", 1)[0])
	var echoed := _hero()
	var heir: Item = ring.call({"added_strength": lowest})
	wear.call(echoed.stash(), heir)
	wear.call(echoed, lined.call(Item.rolled_unique("heirlooms_echo", rng, 1), {}))
	var times := UniqueTable.dial("heirlooms_echo", "times", iv)
	var before: float = at.call(echoed, "heirlooms_echo", 3).attributes()["strength"]
	var lifted: float = at.call(echoed, "heirlooms_echo", iv).attributes()["strength"]
	_check(before == lowest * UniqueTable.dial("heirlooms_echo", "times", 3) and lifted > lowest * times
			and int(heir.mods[0]["value"]) == lowest and heir.plus == 0,
			"the Echo at IV lifts the heirloom a plus in the count alone (%s, %s)" % [before, lifted])

	# The Purist's Seal: a pure piece's lines count a quarter higher.
	var pure := Inventory.new()
	var sword: Item = lined.call(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 1), {"added_damage": 20})
	wear.call(pure, sword)
	wear.call(pure, lined.call(Item.rolled_unique("purists_seal", rng, 1), {}))
	var plain_damage: float = at.call(pure, "purists_seal", 3).stats()["damage"]
	var purer: float = at.call(pure, "purists_seal", iv).stats()["damage"]
	_check(purer > plain_damage and int(sword.mods[0]["value"]) == 20,
			"the Seal at IV counts the sword's line higher, and leaves it as it is (%s, %s)" % [plain_damage, purer])

	# The Rag and Bone Sack: now and then an orb as well.
	var sack := Inventory.new()
	wear.call(sack, Item.rolled_unique("rag_and_bone_sack", rng, 1))
	for rank in [3, iv]:
		at.call(sack, "rag_and_bone_sack", rank)
		var draws := RandomNumberGenerator.new()
		draws.seed = WORLD_SEED
		var orbs := 0
		for i in 400:
			var orb := sack.salvage_orb(draws)
			orbs += int(not orb.is_empty())
			_check(orb.is_empty() or OrbTable.ORBS.has(orb), "a real orb (%s)" % orb)
		_check((orbs == 0) == (rank != iv) and orbs < 60, "orbs from the Sack at rank %d: %d of 400" % [rank, orbs])

	# The Sage's Abacus: every stone holding a point counts one rank higher.
	var sage := Inventory.new()
	sage.skills.stones["0"] = _node("Dexterity Node", "global_increased_attack_speed")
	sage.skills.ranks["0"] = 1
	_check(not sage.skills.percent().is_empty(), "a stone holding a point adds a percent")
	for stat: String in sage.skills.percent():
		_check(sage.skills.percent(1)[stat] == 2.0 * sage.skills.percent()[stat],
				"a rank more is the rank's again (%s)" % stat)
	wear.call(sage, lined.call(Item.rolled_unique("sages_abacus", rng, 1), {}))
	_check(at.call(sage, "sages_abacus", iv).stats() != at.call(sage, "sages_abacus", 3).stats(),
			"and the Abacus at IV hands the fight that")

	# The Fencer's Signet and the Scholar's Circlet: dexterity to dodge, intelligence to crit damage.
	var fencer := _hero()
	wear.call(fencer, ring.call({"added_dexterity": 50, "added_intelligence": 50}))
	wear.call(fencer, lined.call(Item.rolled_unique("fencers_signet", rng, 1), {}))
	wear.call(fencer, lined.call(Item.rolled_unique("scholars_circlet", rng, 1), {}))
	at.call(fencer, "fencers_signet", 3)
	at.call(fencer, "scholars_circlet", 3)
	var dodged := float(fencer.stats().get("dodge", 0.0))
	var sharp := float(fencer.stats().get("crit_damage", 0.0))
	at.call(fencer, "fencers_signet", iv)
	at.call(fencer, "scholars_circlet", iv)
	_check(fencer.stats()["dodge"] - dodged == 50.0
			and fencer.stats()["crit_damage"] - sharp == 50.0 / Inventory.SCHOLAR_CRIT,
			"both at IV and neither at III (%s, %s)" % [fencer.stats().get("dodge"), fencer.stats().get("crit_damage")])

	# The Quickdraw Boots: Spawn Speed past 100% is attack speed.
	var quick := _hero()
	wear.call(quick, lined.call(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 1), {}))
	wear.call(quick, ring.call({"added_dexterity": 150}))
	wear.call(quick, lined.call(Item.rolled_unique("quickdraw_boots", rng, 1), {}))
	var slow: float = at.call(quick, "quickdraw_boots", 3).stats()["attack_speed"]
	var spawn: float = quick.stats()["spawn_speed"]
	var fast: float = at.call(quick, "quickdraw_boots", iv).stats()["attack_speed"]
	var spawn_iv: float = quick.stats()["spawn_speed"]
	_check(is_equal_approx(fast, slow * (1.0 + (spawn_iv - 100.0) / 100.0)) and spawn > 100.0,
			"the Boots at IV turn Spawn Speed past 100%% into attack speed (%s from %s)" % [fast, slow])

	# The Crown of Accord: attributes a fifth apart count.
	var crown := _hero()
	wear.call(crown, ring.call({"added_strength": 100, "added_dexterity": 85, "added_intelligence": 85}))
	wear.call(crown, lined.call(Item.rolled_unique("crown_of_accord", rng, 1), {}))
	_check(at.call(crown, "crown_of_accord", 3).attributes()["strength"] == 100.0, "85 of 100 is too far at III")
	_check(at.call(crown, "crown_of_accord", iv).attributes()["strength"]
			== 100.0 * UniqueTable.dial("crown_of_accord", "times", iv), "and near enough at IV")

	# The Zealot's Brand: every attribute's gift a quarter more.
	var zeal := Inventory.new()
	wear.call(zeal, lined.call(Item.rolled_unique("zealots_brand", rng, 1), {}))
	var gift: float = at.call(zeal, "zealots_brand", 3).attribute_gift("strength", 100.0)[1]
	_check(at.call(zeal, "zealots_brand", iv).attribute_gift("strength", 100.0)[1] == gift * Inventory.ZEALOT_GIFT,
			"the Brand at IV")

	# The card writes the rank IV line once it is reached, and not before.
	var metro := Item.rolled_unique("metronome", rng, 1)
	var rows := VBoxContainer.new()
	UniqueTable.ranks = {"metronome": 3}
	ItemDetails.fill(rows, metro, 150.0)
	_check(metro.peak_text().is_empty() and not _said_by(rows).contains(UniqueTable.peak_text("metronome")),
			"no rank IV line at III")
	UniqueTable.ranks = {"metronome": iv}
	ItemDetails.fill(rows, metro, 150.0)
	_check(metro.peak_text() == UniqueTable.peak_text("metronome") and _said_by(rows).contains(metro.peak_text())
			and _said_by(rows).contains("Rank IV"), "and the line and the rank at IV")
	UniqueTable.ranks = {}
	rows.free()
	return true


## The uniques that are about the player rather than the fight: the Spiked Helm's armour, the two counts
## `stats` hands the fight, the Rag and Bone Sack, and what a Pilgrim's set of home pieces tells it.
func _test_unique_stats() -> bool:
	_clear_save()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var wear := func(bag: Inventory, piece: Item) -> void:
		bag.items.append(piece)
		_check(bag.equip(piece, bag.equipment.sockets_for(piece)[0]), "%s goes on" % piece.display_name())

	# Spikes: a hundredth of the armour, in with the flat damage so a global percent scales it.
	var bag := _hero()
	wear.call(bag, _piece(ItemRarity.Rarity.COMMON, 5))
	var ring := Item.new()
	ring.type = "Gold Ring"
	ring.stats = Item.scaled_stats(ring.type, 1)
	ring.mods = [{"id": "global_increased_damage", "value": 50}]
	wear.call(bag, ring)
	var without: float = bag.stats()["damage"]
	var helm := Item.rolled_unique("spiked_helm", rng, 5)
	helm.stats["armor"] = 1000.0
	helm.mods.clear()
	wear.call(bag, helm)
	var armour: float = bag.equipment.totals()["armor"]
	var spikes := UniqueTable.dial("spiked_helm", "share") / 100.0
	_check(is_equal_approx(bag.stats()["damage"], without + armour * spikes * 1.5),
			"its share of the armour, scaled like any flat damage (%s from %s)" % [bag.stats()["damage"], without])

	# The two counts the fight cannot see for itself.
	_check(bag.stats()["bare_sockets"] == Equipment.NAMES.size() - 3, "three sockets filled, the rest bare")
	bag.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	bag.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	_check(bag.stats()["bag_pieces"] == 2, "and two pieces in the bag")

	# The Rag and Bone Sack: its rank's share of what a trader gives, and only while it is worn.
	var junk := _piece(ItemRarity.Rarity.RARE, 8)
	_check(bag.salvage(junk) == 0.0, "nothing is paid for rubbish without the sack")
	wear.call(bag, Item.rolled_unique("rag_and_bone_sack", rng, 5))
	var paid := bag.salvage(junk)
	var share := UniqueTable.dial("rag_and_bone_sack", "share") / 100.0
	_check(paid == maxf(1.0, roundf(TownPrices.sell_price(junk) * share)) and paid < TownPrices.sell_price(junk),
			"its share of the trader's price (%s of %s)" % [paid, TownPrices.sell_price(junk)])
	bag.achievements["rag_and_bone_sack"] = UniqueTable.PEAK
	_check(bag.salvage(junk) == maxf(1.0, roundf(TownPrices.sell_price(junk)
			* UniqueTable.dial("rag_and_bone_sack", "share", UniqueTable.PEAK) / 100.0)), "and more at rank IV")
	bag.achievements.erase("rag_and_bone_sack")
	# A run's salvage reaches the purse like any gold; the bag pays for its own discards at once.
	FightLedger.new(bag, TEST_PATH, true).add_gold(paid)
	_check(bag.gold == paid, "a run pays its salvage into the purse")
	var page := BagPage.new(bag, TEST_PATH, 2.0)
	root.add_child(page)
	await process_frame
	bag.items.append(junk)
	page._on_discard_pressed(junk)
	_check(bag.gold == paid * 2.0 and not bag.items.has(junk), "the bag's Discard pays too")
	var level_one := bag.count_at(1)
	page._drop_level(1, false)
	_check(level_one == 2 and bag.gold > paid * 2.0 and bag.count_at(1) == 0, "and so does a level's bin")
	page.queue_free()

	# A home piece is at home on its own ground and nowhere else, alone or beside another: there is no set.
	var homes := Inventory.new()
	wear.call(homes, Item.rolled_unique("meadowstriders", rng, 1))
	_check(homes.effects() == ["home:grass"], "one piece, one ground (%s)" % [homes.effects()])
	wear.call(homes, Item.rolled_unique("rimeplate", rng, 1))
	_check(homes.effects().size() == 2 and "home:grass" in homes.effects() and "home:ice" in homes.effects(),
			"two pieces, each its own ground and nothing more (%s)" % [homes.effects()])
	# And it wears the unique's gold, frame and all, like every other.
	var home := Item.rolled_unique("rimeplate", rng, 1)
	_check(home.border_color() == Palette.GOLD and home.text_color() == ItemRarity.TEXT_COLORS[ItemRarity.Rarity.UNIQUE]
			and home.frame() != null, "a home piece is a unique in gold")
	_clear_save()
	return true


## Achievements: each unlocks one unique into the drops, reached by a count or a figure off the player;
## a fight is counted by `record` -- its feats only on a tile fight -- and what is earned is saved,
## carried through a transcension, announced and listed on its page. And the starters' own numbers.
func _test_achievements() -> bool:
	_clear_save()
	# The table: every unique is a starter or has exactly one achievement, never both -- but a lair's,
	# which its boss alone drops, is neither.
	for id: String in UniqueTable.UNIQUES:
		if UniqueTable.is_lair(id):
			_check(not id in Achievements.STARTERS and not Achievements.ACHIEVEMENTS.has(id),
					"%s, a lair's, is neither a starter nor an achievement's" % id)
			continue
		_check((id in Achievements.STARTERS) != Achievements.ACHIEVEMENTS.has(id),
				"%s is either a starter or unlocked by an achievement" % id)
	for id: String in Achievements.ACHIEVEMENTS:
		var row: Dictionary = Achievements.ACHIEVEMENTS[id]
		_check(UniqueTable.UNIQUES.has(id) and int(row["tier"]) in [1, 2, 3, 4] and not str(row["name"]).is_empty(),
				"%s is a whole row" % id)
		# Four ranks, each asking more than the last, and each said in full.
		var need: Array = row["need"]
		_check(need.size() == UniqueTable.PEAK and float(need[0]) > 0.0, "%s asks one number a rank" % id)
		for rank in range(1, UniqueTable.PEAK + 1):
			if rank > 1:
				_check(float(need[rank - 1]) > float(need[rank - 2]), "%s asks more at rank %d" % [id, rank])
			var said := Achievements.text(id, rank)
			_check(not said.is_empty() and not said.contains("{"), "%s says what rank %d asks (%s)" % [id, rank, said])
	_check(Achievements.STARTERS.size() == 8, "eight starters, one a socket")

	# A count earns at its need, and not before.
	var player := Inventory.new()
	_check(Achievements.unlocked(player) == Achievements.STARTERS, "a new player has the starters and no more")
	var first := int(Achievements.need_at("duelists_buckler", 1))
	player.tick("crits", first - 1)
	_check(Achievements.earn(player).is_empty(), "one crit short earns nothing")
	player.tick("crits")
	_check(Achievements.earn(player) == ["duelists_buckler"] and "duelists_buckler" in Achievements.unlocked(player)
			and player.achievements_new == ["duelists_buckler"] and Achievements.rank(player, "duelists_buckler") == 1,
			"the last earns the Duelist's Buckler at rank I, once")
	_check(Achievements.earn(player).is_empty(), "and it is not earned twice")
	# It climbs a rank at each need, several at once where the count already stood past them, and no
	# further than the last.
	player.achievements_new.clear()
	player.tick("crits", int(Achievements.need_at("duelists_buckler", 2)) - first)
	_check(Achievements.earn(player) == ["duelists_buckler"] and Achievements.rank(player, "duelists_buckler") == 2
			and player.achievements_new == ["duelists_buckler"], "the next need is rank II, and new again")
	player.tick("crits", int(Achievements.need_at("duelists_buckler", UniqueTable.PEAK)) * 10)
	_check(Achievements.earn(player) == ["duelists_buckler"]
			and Achievements.rank(player, "duelists_buckler") == UniqueTable.PEAK, "a count past the last is rank IV at once")
	_check(Achievements.earn(player).is_empty(), "and nothing climbs past it")
	_check(Achievements.ranks(player) == {"duelists_buckler": UniqueTable.PEAK}, "which is what a fight is told")
	# A figure off the player: strength worn.
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var ring := Item.rolled("Iron Band", ItemRarity.Rarity.COMMON, rng, 1)
	ring.mods = [{"id": "added_strength", "value": int(Achievements.need_at("ogres_knuckle", 1))}]
	player.add(ring)
	player.equip(ring, player.equipment.sockets_for(ring)[0])
	_check("ogres_knuckle" in Achievements.earn(player), "the strength it asks, worn, earns the Ogre's Knuckle")
	# Into the Dark: the furthest wall ever broken, read off how far the land has reached.
	player.reach(MapBuilder.START_LAND_RADIUS + 2 * MapBuilder.WALL_STEP)
	_check(not "nightwalkers" in Achievements.earn(player), "the second wall is not the third")
	player.reach(MapBuilder.START_LAND_RADIUS + 3 * MapBuilder.WALL_STEP)
	_check("nightwalkers" in Achievements.earn(player) and Achievements.rank(player, "nightwalkers") == 1,
			"the third wall earns the Nightwalkers")
	_check(Achievements.text("nightwalkers", UniqueTable.PEAK) == "Break the sixth ice wall.",
			"and rank IV asks for the sixth (%s)" % Achievements.text("nightwalkers", UniqueTable.PEAK))
	# The boots reach the map through the inventory, from either doll, at the rank earned.
	_check(player.dark_reach() == 1, "no boots, one step")
	var boots := Item.rolled_unique("nightwalkers", rng, 1)
	player.stash().items.append(boots)
	player.stash().equip(boots, Equipment.Socket.BOOTS)
	_check(player.dark_reach() == int(UniqueTable.dial("nightwalkers", "tiles", 1)),
			"rank I's reach on the heirlooms' doll")
	player.achievements["nightwalkers"] = 3
	_check(player.dark_reach() == int(UniqueTable.dial("nightwalkers", "tiles", 3)), "and rank III's at rank III")
	player.stash().unequip(Equipment.Socket.BOOTS)
	player.achievements["nightwalkers"] = 1

	# A fight: its counts on a run and a tile fight both, its streaks and feats on a tile fight only.
	var run := Encounter.farm(Vector2i(3, 0), "grass")
	run.tally = {"crit_kills": 5, "dry_streak": 40, "clicks": 0}
	run.index = 7
	run.victory = true
	Achievements.record(player, run)
	_check(player.tally.get("crit_kills") == 5 and player.tally.get("kills:grass") == 7
			and not player.tally.has("dry_streak"), "a run counts its kills and crits, not its streaks (%s)" % [player.tally])
	# Dreaded: the kills on every ground together.
	player.tick("kills:forest", int(Achievements.need_at("dreadmask", 1)) - 8)
	_check(not "dreadmask" in Achievements.earn(player), "one kill short earns nothing")
	player.tick("kills:dirt")
	_check("dreadmask" in Achievements.earn(player), "and the last, on another ground, earns the Dreadmask")
	var wall := Encounter.for_wall(Vector2i(11, 0))
	wall.tally = {"dry_streak": 40}
	wall.victory = true
	wall.time_left = wall.seconds
	Achievements.record(player, wall)
	_check(player.tally.get("dry_streak") == 40 and player.tally.get("wall_no_clicks") == 1
			and player.tally.get("wall_half_clock") == 1 and not player.tally.has("wall_last_second"),
			"a wall broken without a click, and with the clock untouched, is two feats (%s)" % [player.tally])
	var lost := Encounter.for_wall(Vector2i(11, 0))
	lost.victory = false
	lost.time_left = 0.5
	Achievements.record(player, lost)
	_check(not player.tally.has("wall_last_second"), "a wall not broken is no feat")
	_check("metronome" in Achievements.earn(player) and Achievements.is_unlocked(player, "metronome"),
			"and a feat unlocks its unique")
	# By a Hair: a wall broken with under a second on the clock.
	var close := Encounter.for_wall(Vector2i(11, 0))
	close.tally = {"clicks": 3}
	close.victory = true
	close.time_left = 0.5
	Achievements.record(player, close)
	_check(player.tally.get("wall_last_second") == 1 and "last_gasp" in Achievements.earn(player),
			"a wall broken with under a second left earns the Last Gasp")
	# A feat is kept as the furthest wall out it was done at: the second wall's ring is its rank II.
	var second := Encounter.for_wall(Vector2i(MapBuilder.START_LAND_RADIUS + 1 + MapBuilder.WALL_STEP, 0))
	second.tally = {}
	second.victory = true
	second.time_left = second.seconds
	Achievements.record(player, second)
	Achievements.record(player, wall)
	_check(player.tally.get("wall_no_clicks") == 2 and Achievements.earn(player).has("metronome")
			and Achievements.rank(player, "metronome") == 2, "the second wall is rank II, and the first takes nothing back")
	# Clean Sweep: ten one-blow kills in a row in one tile fight, counted by the walls behind the land.
	for case: Array in [[Vector2i(4, 0), 0], [Vector2i(MapBuilder.START_LAND_RADIUS + 2, 0), 1]]:
		var sweep := Encounter.for_tile(case[0], "grass")
		sweep.tally = {"domino_streak": Achievements.DOMINO_STREAK}
		var sweeper := Inventory.new()
		Achievements.record(sweeper, sweep)
		_check(int(sweeper.tally.get("domino_wall", 0)) == case[1], "a sweep at %s is past %d walls" % case)
	# The walls ever broken are counted as they are paid for, in any world.
	var mason := Inventory.new()
	mason.credit_walls(2)
	mason.credit_walls(3)
	_check(mason.tally.get("walls") == 3 and mason.transcended().tally.get("walls") == 3,
			"every wall broken is counted once, and the count outlives the world")

	# Saved, carried through a transcension, and an old save has earned nothing.
	player.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(back.achievements == player.achievements and back.tally == player.tally
			and back.achievements_new == player.achievements_new, "what was earned and counted survives the save")
	var next := player.transcended()
	_check(next.achievements == player.achievements and next.tally.get("crit_kills") == 5
			and next.tally.get("transcended") == 1, "and a transcension, which it counts")
	var old := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 27, "uniques_found": ["metronome"]}))
	old.close()
	var older := Inventory.load_from(TEST_PATH)
	_check(older.achievements.is_empty() and older.tally.is_empty() and older.uniques_found == ["metronome"]
			and not Achievements.is_unlocked(older, "metronome"),
			"a version 27 save earned nothing: its find stays in the log and must be earned again")
	# Version 28 kept a list: every one of it rank I, and the walls down in its world the lifetime count.
	var listed := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	listed.store_string(JSON.stringify({"version": 28, "achievements": ["metronome", "no_such_feat"],
			"achievements_new": ["metronome"], "walls_credited": 3, "tally": {"walls": 1, "crits": 7}}))
	listed.close()
	var ranked := Inventory.load_from(TEST_PATH)
	_check(ranked.achievements == {"metronome": 1} and ranked.achievements_new == ["metronome"]
			and ranked.tally.get("walls") == 3 and ranked.tally.get("crits") == 7,
			"a version 28 save's achievements are rank I, and its walls count (%s, %s)" % [ranked.achievements, ranked.tally])
	var climbed := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	climbed.store_string(JSON.stringify({"version": Inventory.VERSION, "achievements": {"metronome": 9, "bulwark": 0}}))
	climbed.close()
	_check(Inventory.load_from(TEST_PATH).achievements == {"metronome": UniqueTable.PEAK},
			"a rank off the end of the table is held to it, and none at all is nothing earned")

	# The figures read off the player: what the gear adds up to, not what the Brand makes of it.
	var zealot := Inventory.new()
	var focus := Item.rolled("Iron Band", ItemRarity.Rarity.COMMON, rng, 1)
	focus.mods = [{"id": "added_strength", "value": 250}]
	zealot.add(focus)
	zealot.equip(focus, zealot.equipment.sockets_for(focus)[0])
	var brand := Item.rolled_unique("zealots_brand", rng, 1)
	brand.mods = []
	zealot.add(brand)
	zealot.equip(brand, zealot.equipment.sockets_for(brand)[0])
	var figures := Achievements.state(zealot)
	_check(zealot.attributes()["dexterity"] > 0.0 and figures["dexterity"] == 0.0 and figures["zealot"] == 250.0
			and figures["accord"] == 0.0, "the Brand counts for the fight and not for an ask (%s)" % [figures])
	# Mastery: the stones standing in the skill tree.
	var scholar := Inventory.new()
	_check(Achievements.state(scholar)["mastery"] == 0.0, "a new hero's tree holds no stone")
	var stones := RandomNumberGenerator.new()
	scholar.add(Item.rolled("Strength Node", ItemRarity.Rarity.COMMON, stones, 1, 1, 3))
	scholar.place_stone(scholar.items[0], "0")
	for i in 3:
		scholar.add(Item.rolled("Dexterity Node", ItemRarity.Rarity.COMMON, stones, 1, 2, 2 if i == 0 else 0))
		scholar.place_stone(scholar.items[-1], "0.%d" % i)
	for i in 2:
		scholar.add(Item.rolled("Intelligence Node", ItemRarity.Rarity.COMMON, stones, 1, 3))
		scholar.place_stone(scholar.items[-1], "0.0.%d" % i)
	_check(Achievements.state(scholar)["mastery"] == 6.0
			and Achievements.state(scholar)["mastery"] >= Achievements.need_at("sages_abacus", 1),
			"five more under it, three deep (%s)" % Achievements.state(scholar)["mastery"])
	_check(Achievements.state(Inventory.new())["carried"] == 0.0, "and a bag is counted piece by piece")

	# The starters' own numbers, read by `stats()`.
	var starter := _hero()
	var bare := starter.stats()
	for id: String in ["squires_blade", "couriers_boots", "novices_cap"]:
		var piece := Item.rolled_unique(id, rng, 1)
		piece.mods = []
		starter.add(piece)
		starter.equip(piece, starter.equipment.sockets_for(piece)[0])
	var worn := starter.stats()
	_check(float(worn.get("damage", 0.0)) >= float(bare.get("damage", 0.0)) + Inventory.SQUIRE_DAMAGE,
			"the Squire's Blade adds its damage (%s)" % worn.get("damage"))
	_check(float(worn.get("spawn_speed", 0.0)) == Inventory.COURIER_SPAWN, "the Courier's Boots their spawn speed")
	_check(float(worn.get("xp_more", 0.0)) == Inventory.NOVICE_XP, "the Novice's Cap its experience")
	starter.level = Inventory.NOVICE_UNTIL
	_check(float(starter.stats().get("xp_more", 0.0)) == 0.0, "until the level it stops at")

	# The page, the button and the banner.
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	_clear_save()
	root.add_child(main)
	await process_frame
	_check(not main._achievements_button.visible, "no achievements button before the first")
	var asked := int(Achievements.need_at("duelists_buckler", 1))
	main.inventory.tick("crits", asked)
	main.inventory.save(TEST_PATH)
	await process_frame
	await process_frame
	_check(main.inventory.achievements == {"duelists_buckler": 1}, "a save that reaches one earns it")
	_check(main.banner.panel != null and _said_by(main.banner.panel).contains("Sharp Eye")
			and _said_by(main.banner.panel).contains("Unlocks Duelist's Buckler"),
			"on a banner naming it and its unique")
	_check(Inventory.load_from(TEST_PATH).achievements == {"duelists_buckler": 1}, "and it is saved")
	_check(UniqueTable.ranks == {"duelists_buckler": 1}, "and the cards write its unique at that rank")
	_check(main._achievements_button.visible and main._flashes.has("opened_achievements"), "its button comes on, pulsing")
	main.banner.close()
	# The next rank is a banner of its own: the rank reached, and the unique's rule at its new numbers.
	main.inventory.tick("crits", int(Achievements.need_at("duelists_buckler", 2)) - asked)
	main.inventory.save(TEST_PATH)
	await process_frame
	await process_frame
	var risen := _said_by(main.banner.panel) if main.banner.panel != null else ""
	_check(Achievements.rank(main.inventory, "duelists_buckler") == 2 and risen.contains("Rank up")
			and risen.contains("Sharp Eye II") and risen.contains(UniqueTable.effect_text("duelists_buckler", 2)),
			"a rank climbed raises its own banner (%s)" % risen)
	_check(UniqueTable.ranks == {"duelists_buckler": 2}, "and the cards follow it")
	main.banner.close()
	main._on_achievements_pressed()
	await process_frame
	_check(main.achievements_page.visible and main.inventory.achievements_new == ["duelists_buckler"]
			and not main._flashes.has("opened_achievements"), "the page opens and the pulse stops for good")
	var tiles: Array = main.achievements_page.find_children("*", "ItemSlot", true, false)
	var glinting := tiles.filter(func(s: ItemSlot) -> bool: return s.has_node(ItemSlot.GLINT_NAME))
	_check(glinting.size() == 1 and glinting[0].item.unique == "duelists_buckler"
			and tiles.all(func(s: ItemSlot) -> bool: return (s.get_child(0) as TextureRect).material == null),
			"only the new one glints (%d)" % glinting.size())
	_check(tiles.size() == Achievements.ACHIEVEMENTS.size(), "one square an achievement (%d)" % tiles.size())
	_check(_by_name(tiles.map(func(slot: ItemSlot) -> String:
			return str(Achievements.ACHIEVEMENTS[slot.item.unique]["name"]))), "the squares stand by the achievement's name")
	var buckler: ItemSlot = tiles.filter(func(s: ItemSlot) -> bool: return s.item.unique == "duelists_buckler")[0]
	var unique_card := VBoxContainer.new()
	(buckler.get_meta(ItemCard.ALT_CARD) as Callable).call(unique_card, 150.0)
	_check(_said_by(unique_card).contains("Duelist's Buckler")
			and buckler.get_meta(ItemCard.KEYS) == {"alt": "Duelist's Buckler"},
			"under Alt a square shows the unique it unlocks, and its key names it (%s)" % _said_by(unique_card))
	unique_card.free()
	# A locked one's says what it is about and nothing it does: its name, its hint, "Locked".
	var drumroll: ItemSlot = tiles.filter(func(s: ItemSlot) -> bool: return s.item.unique == "knucklebone_ring")[0]
	var locked_card := VBoxContainer.new()
	(drumroll.get_meta(ItemCard.ALT_CARD) as Callable).call(locked_card, 150.0)
	var locked_said := _said_by(locked_card)
	_check(locked_said.contains("Knucklebone Ring") and locked_said.contains(UniqueTable.hint("knucklebone_ring"))
			and locked_said.contains("Locked") and not locked_said.contains(UniqueTable.effect_text("knucklebone_ring"))
			and not locked_said.contains("Level"), "a locked unique's card hides what it does (%s)" % locked_said)
	locked_card.free()
	var numeral := RegEx.create_from_string("[0-9]")
	_check(Achievements.ACHIEVEMENTS.keys().all(func(id: String) -> bool:
			return not UniqueTable.hint(id).is_empty() and numeral.search(UniqueTable.hint(id)) == null),
			"every unique an achievement unlocks has a hint, and no number in it")
	var lit := tiles.filter(func(slot: ItemSlot) -> bool: return slot.modulate == Color.WHITE)
	_check(lit.size() == 1 and lit[0].item.unique == "duelists_buckler", "the earned one lit, the rest dimmed")
	_check(_said_by(lit[0]).contains("II"), "with its rank on its corner (%s)" % _said_by(lit[0]))
	_check(tiles.all(func(slot: ItemSlot) -> bool: return slot.hint.is_valid()), "and each writes its own card")
	# Each square's foot shows how far it is toward its next rank: the earned one partway to III, one
	# never worked at empty.
	var toward := func(unique: String) -> Array:
		var slot: ItemSlot = tiles.filter(func(s: ItemSlot) -> bool: return s.item.unique == unique)[0]
		var trough: ColorRect = slot.find_child(AchievementsPage.PROGRESS_NAME, false, false)
		return [(trough.get_child(0) as ColorRect).size.x, trough.size.x]
	var partway: Array = toward.call("duelists_buckler")
	_check(partway[0] > 0.0 and partway[0] < partway[1], "the earned square's bar is partway (%s)" % [partway])
	_check(toward.call("knucklebone_ring")[0] == 0.0, "and an untouched one's is empty")
	var bar: Label = main.achievements_page.find_child(AchievementsPage.SHARE_NAME, true, false)
	_check(bar.text == "%d%%" % roundi(200.0 / (Achievements.ACHIEVEMENTS.size() * UniqueTable.PEAK)),
			"the bar says how much is earned, rank by rank (%s)" % bar.text)
	var rows := VBoxContainer.new()
	AchievementsPage.write_card(rows, 150.0, main.inventory, "knucklebone_ring", Achievements.state(main.inventory))
	var said := _said_by(rows)
	_check(said.contains("Drumroll") and said.contains(Achievements.text("knucklebone_ring", 1))
			and said.contains("0 / %s" % BigNumber.format(Achievements.need_at("knucklebone_ring", 1)))
			and not said.contains("/ IV"), "a square's card says what and how far (%s)" % said)
	AchievementsPage.write_card(rows, 150.0, main.inventory, "duelists_buckler", Achievements.state(main.inventory))
	said = _said_by(rows)
	_check(said.contains("II / IV") and said.contains(Achievements.text("duelists_buckler", 3)),
			"an earned one's says its rank and asks the next (%s)" % said)
	rows.free()
	_check(glinting[0].has_node(ItemSlot.GLINT_NAME), "and it glints on until hovered")
	# Closed without a hover: the page closing is seeing it.
	main._on_left_page_closed()
	await process_frame
	_check(main.inventory.achievements_new.is_empty() and Inventory.load_from(TEST_PATH).achievements_new.is_empty(),
			"closing the page stills it, and that is saved")
	# A corner key presses its button: O opens the settings (always there) in the page's place, and the
	# button's tip card names the key. A key whose button has not come yet does nothing: K, before a level.
	var key := InputEventKey.new()
	key.keycode = KEY_K
	key.pressed = true
	main._unhandled_input(key)
	await process_frame
	_check(not main._skills_button.visible and not main.skills_page.visible, "K does nothing before the skills are earned")
	key.keycode = KEY_O
	main._unhandled_input(key)
	await process_frame
	_check(main.settings_page.visible and not main.achievements_page.visible, "O opens the settings in the other's place")
	_check(str(main._settings_button.get_meta(TipCard.KEY, "")) == "o"
			and ResourceLoader.exists(TipCard.KEY_PICTURE % "o"), "and its card shows the O key")
	key.shift_pressed = true
	key.keycode = KEY_Y
	main._unhandled_input(key)
	await process_frame
	_check(not main.achievements_page.visible, "but not with a modifier held, which is the item card's")
	# Dev: Skill points +10 is ten levels, and the ten points they earn, saved.
	var free: int = main.inventory.skills.points(main.inventory.level)
	main.settings_page.points_pressed.emit()
	_check(main.inventory.skills.points(main.inventory.level) == free + 10
			and Inventory.load_from(TEST_PATH).level == main.inventory.level, "Skill points +10 gives ten, saved")
	main._on_left_page_closed()
	main.queue_free()
	await process_frame
	_clear_save()
	return true


## The collection log: a button that is not there until there is something to log, a page of squares
## that says what a found one is, where it is carried and only where a missing one hides -- and the
## banner a unique new to the log raises when it drops, with the two ways it goes away again.
func _test_collection() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	await process_frame
	main._check_tips()
	_check(not main._collection_button.visible, "no collection button before the first unique")
	main.inventory.note_unique("metronome")
	main._check_tips()
	_check(main._collection_button.visible and main._flashes.has("opened_collection"), "it comes on, pulsing")
	_check("first_unique" in main.inventory.tips and main._tip_panel != null, "with a word about what was found")
	main._on_tip_closed()
	main.inventory.achievements["rimeplate"] = 1
	main._on_collection_pressed()
	await process_frame
	_check(main.collection_page.visible and main._collection_button.visible, "the page opens, its button beside it")
	_check(not main._flashes.has("opened_collection"), "opening the log stills the button for good")
	var squares: Array = main.collection_page.find_children("*", "ItemSlot", true, false)
	var logged: Array = squares.map(
			func(slot: ItemSlot) -> String: return str(UniqueTable.UNIQUES[slot.item.unique]["name"]))
	var starting := Achievements.STARTERS.size()
	_check(squares.slice(0, starting).all(func(slot: ItemSlot) -> bool: return slot.item.unique in Achievements.STARTERS)
			and _by_name(logged.slice(0, starting)) and _by_name(logged.slice(starting)),
			"the log is the starters, then the rest, each by name")
	var fresh: Array = squares.filter(func(slot: ItemSlot) -> bool: return slot.has_node(ItemSlot.GLINT_NAME))
	_check(fresh.size() == 1 and fresh[0].item.unique == "metronome", "the new find glints (%d)" % fresh.size())
	var shining := 0
	for square: ItemSlot in squares:
		var frame := square.get_node_or_null(ItemSlot.FRAME_NAME) as TextureRect
		var icon := square.get_child(0) as TextureRect
		if (frame != null and frame.material != null) or (icon.material is ShaderMaterial
				and (icon.material as ShaderMaterial).shader == ItemSlot.SHINE):
			shining += 1
	_check(shining == 0, "and nothing else on the page does (%d)" % shining)
	fresh[0].hint.call(VBoxContainer.new(), 100.0)
	await process_frame
	_check(not fresh[0].has_node(ItemSlot.GLINT_NAME), "hovering it stills its glint")
	_check(Inventory.load_from(TEST_PATH).uniques_new.is_empty(), "and that is saved")
	main.inventory.note_unique("brawlers_wraps")
	main._show_corner(true)
	_check(not main._flashes.has("opened_collection"), "a later find does not start it again")
	main.inventory.uniques_found.erase("brawlers_wraps")
	main.inventory.uniques_new.erase("brawlers_wraps")
	_check(squares.size() == UniqueTable.UNIQUES.size(), "one square a unique (%d)" % squares.size())
	var achievement_card := VBoxContainer.new()
	var earned: ItemSlot = squares.filter(func(s: ItemSlot) -> bool: return s.item.unique == "duelists_buckler")[0]
	(earned.get_meta(ItemCard.ALT_CARD) as Callable).call(achievement_card, 150.0)
	_check(_said_by(achievement_card).contains(str(Achievements.ACHIEVEMENTS["duelists_buckler"]["name"]))
			and earned.get_meta(ItemCard.KEYS) == {"alt": "achievement"},
			"and in the log Alt shows the achievement that unlocks it (%s)" % _said_by(achievement_card))
	achievement_card.free()
	_check(squares.filter(func(s: ItemSlot) -> bool: return s.has_meta(ItemCard.ALT_CARD)).size()
			== Achievements.ACHIEVEMENTS.size(), "every square but a starter's")
	# The foot, under the scroll: what the log adds and how full it is, in the body font.
	var bonus: Label = main.collection_page.find_child(CollectionPage.BONUS_NAME, true, false)
	var tally: Label = main.collection_page.find_child(CollectionPage.COUNT_NAME, true, false)
	_check(bonus.text == "+%d%% Damage" % main.inventory.collection_bonus(),
			"the damage it adds is always written (%s)" % bonus.text)
	_check(tally.text == "Found 1 of %d" % UniqueTable.UNIQUES.size(), "beside how much of it is found (%s)" % tally.text)
	var scrolls: Array = main.collection_page.find_children("*", "ScrollContainer", true, false)
	_check(not scrolls[0].is_ancestor_of(bonus) and bonus.theme_type_variation == "SmallLabel"
			and tally.theme_type_variation == "SmallLabel", "both small, and outside what scrolls")
	_check(is_equal_approx(main.collection_page._panel.get_combined_minimum_size().x,
			main.bag_page._panel.get_combined_minimum_size().x), "and the foot's words do not widen the page past the bag's")
	var shown := 0
	for square: ItemSlot in squares:
		var id: String = square.item.unique
		var found := id == "metronome"
		var told := not found and Achievements.is_unlocked(main.inventory, id)
		shown += int(found)
		# Every square writes its card through the hint now: a found one so it still says where the
		# piece is carried, a locked one so it says what unlocks it.
		_check(square.hint.is_valid(), "%s: the card is written by the hint" % id)
		var icon: TextureRect = square.get_child(0)
		_check((icon.modulate == ItemSlot.SHADOW) == told, "%s: darkened only while unlocked and not found" % id)
		_check((icon.material is ShaderMaterial and (icon.material as ShaderMaterial).shader == ItemSlot.GREY)
				== told, "%s: and greyed only then" % id)
		_check((square.self_modulate == ItemSlot.KNOWN_SOCKET) == told, "%s: on a faint socket then" % id)
		_check((icon.modulate == Color.BLACK) == (not found and not told),
				"%s: a black outline only while locked" % id)
		_check((square.get_node_or_null(ItemSlot.FRAME_NAME) == null) == (not found),
				"%s: a missing one has no ring" % id)
		_check((square.get_theme_stylebox("panel") is StyleBoxEmpty) == (not found and not told),
				"%s: and a locked one no socket" % id)
	_check(shown == 1, "the found one is drawn as itself")
	# The hint says only "Locked" of a locked piece, and what it is once it is unlocked -- and never
	# where it is carried: every unique is carried on every ground.
	for peeked: bool in [false, true]:
		var rows := VBoxContainer.new()
		CollectionPage.write_hint(rows, 150.0, CollectionPage.specimen("rimeplate") if peeked else null)
		var said := ""
		for label: Node in rows.find_children("*", "Label", true, false):
			said += (label as Label).text + " "
		_check(said.contains("Rimeplate") == peeked and said.contains("Locked") == (not peeked)
				and not said.contains("Frost Hunter"),
				"a hint says it is locked, and what it is once it is unlocked (%s: %s)" % [peeked, said])
		# A found piece's card says nothing of being found, nor where anything is carried.
		_check(not said.contains("Found") and not said.contains("Not found yet") and not said.contains("Nearest:")
				and not said.contains("Carried by"), "and nothing about being found or where (%s)" % said)
		rows.free()
	# An unlocked piece not yet found says so under itself: its grey square alone was read as held.
	var unfound := VBoxContainer.new()
	CollectionPage.write_hint(unfound, 150.0, CollectionPage.specimen("rimeplate"), true, false)
	var unfound_said := ""
	for label: Node in unfound.find_children("*", "Label", true, false):
		unfound_said += (label as Label).text + " "
	_check(unfound_said.contains("Rimeplate") and unfound_said.contains("Not found yet")
			and not unfound_said.contains("Locked"), "an unlocked piece not found says so (%s)" % unfound_said)
	unfound.free()
	# The found square's own card is the same block, so the log reads alike either way.
	var held_rows := VBoxContainer.new()
	for square: ItemSlot in squares:
		if square.item.unique == "metronome":
			square.hint.call(held_rows, 150.0)
	var held := ""
	for label: Node in held_rows.find_children("*", "Label", true, false):
		held += (label as Label).text + " "
	# The Metronome was found and is not unlocked: an old save's find, which must be earned again.
	_check(held.contains("Metronome") and held.contains("Locked") and not held.contains("Hands Off"),
			"a found square that is locked says so and no more (%s)" % held)
	held_rows.free()
	# The settings page's dev tick draws the lot as found. A static, so it is put back.
	Settings.all_uniques = true
	main.collection_page.open()
	await process_frame
	squares = main.collection_page.find_children("*", "ItemSlot", true, false)
	var found := func(square: ItemSlot) -> bool:
		return square.modulate == Color.WHITE and square.get_node_or_null(ItemSlot.FRAME_NAME) != null
	_check(squares.size() == UniqueTable.UNIQUES.size() and squares.all(found),
			"the dev setting shows every unique as found (%d)" % squares.size())
	Settings.all_uniques = false
	main.inventory.uniques_new.append("metronome")
	main._on_left_page_closed()
	_check(not main.collection_page.visible and main._collection_button.visible, "the X puts it away")
	_check(main.inventory.uniques_new.is_empty() and Inventory.load_from(TEST_PATH).uniques_new.is_empty(),
			"and a new find it closes over unhovered is seen, and that is saved")
	# The banner: raised by a unique the log has never held, and by nothing else.
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.seed = 7
	main._on_loot_dropped(0, Item.rolled_unique("stonebreaker", drop_rng, 5))
	await process_frame
	_check(main.banner.panel != null, "a unique new to the log raises its banner")
	_check(main.banner.head.get_child_count() == 2, "its X up at once")
	# A swing lands on the fight, never on the banner.
	var swing := InputEventMouseButton.new()
	swing.button_index = MOUSE_BUTTON_LEFT
	swing.pressed = true
	main._input(swing)
	_check(main.banner.panel != null, "a swing leaves it up")
	# The mouse on it holds it past its seconds (a headless run has no mouse to move, so it is asked).
	_check(main.banner.over(main.banner.panel.get_global_rect().get_center()) and not main.banner.over(Vector2.ZERO),
			"the mouse is on it over its middle and off it in the corner")
	await create_timer(Banner.HOLD + 0.1).timeout
	_check(main.banner.panel == null, "and it goes by itself after its seconds with the mouse off it")
	# Under a finger it never goes by itself: only a tap off it, once its seconds are up.
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	tap.device = InputEvent.DEVICE_ID_EMULATION
	main._input(tap)
	main._on_loot_dropped(0, Item.rolled_unique("brawlers_wraps", drop_rng, 5))
	await process_frame
	main._input(tap)
	_check(main.banner.panel != null, "under a finger a tap off it before its seconds leaves it up")
	await create_timer(Banner.HOLD + 0.1).timeout
	_check(main.banner.panel != null, "and it never goes by itself")
	tap.position = main.banner.panel.get_global_rect().get_center()
	main._input(tap)
	_check(main.banner.panel != null, "a tap on it leaves it up")
	tap.position = Vector2.ZERO
	main._input(tap)
	_check(main.banner.panel == null, "a tap off it after its seconds puts it down")
	main._input(swing)
	_check(not Cursors.touched, "a mouse press puts the finger's rule away")
	main._on_loot_dropped(0, Item.rolled_unique("stonebreaker", drop_rng, 5))
	_check(main.banner.panel == null, "a second copy of one already logged raises nothing")
	main._on_loot_dropped(0, LootTable.roll("Baby Dragon", drop_rng, true, 5))
	_check(main.banner.panel == null, "and an ordinary find raises nothing")
	main._on_loot_dropped(0, Item.rolled_unique("headsman", drop_rng, 5))
	await process_frame
	(main.banner.head.get_child(1) as BaseButton).pressed.emit()
	_check(main.banner.panel == null, "and its X puts it down early")
	main.queue_free()
	_clear_save()
	return true


## The character page: a press on the character panel's corner opens it, and it says what the player
## adds up to -- the attributes in their rings, every other stat that is something, none that is nothing.
## The dev generator: the piece asked for, free orbs through OrbTable's own gate, and into the bag
## as a piece the page no longer holds.
func _test_item_generator() -> bool:
	_clear_save()
	var bag := Inventory.new()
	var page := ItemGenerator.new(bag, TEST_PATH, func() -> void: pass)
	page.theme = UITheme.theme()
	root.add_child(page)
	await process_frame
	page.pick("helm", 3, 12)
	_check(page.item.type == "Golden Helm" and page.item.level == 12,
			"the generator makes the tier and level it was asked for")
	_check(page.item.rarity == ItemRarity.Rarity.COMMON and page.item.mods.is_empty(), "a fresh piece is a bare common")
	_check(not page.spend("Orb of Augmentation"), "an orb with nothing to do to the piece is refused")
	_check(page.spend("Orb of Transmutation") and page.item.rarity == ItemRarity.Rarity.UNCOMMON,
			"a free orb does what the bag's does")
	var made := page.item
	_check(page.add_to_bag() and bag.items == [made], "Add to bag puts the piece in the bag")
	_check(page.item != made and page.item.type == made.type, "and the page takes up a fresh piece of the same type")
	_check(Inventory.load_from(TEST_PATH).items.size() == 1, "and it is saved")
	while not bag.is_full():
		bag.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, RandomNumberGenerator.new()))
	_check(not page.add_to_bag() and bag.items.size() == Inventory.CAPACITY, "a full bag takes nothing and loses nothing")
	page.queue_free()
	await process_frame
	return true


## The sheet writes what the fight is armed with -- never an empty frame, a cap where a number stopped,
## where a number comes from -- what changed since the last look, and what changes a fight.
func _test_character_sheet() -> bool:
	# Every stat a piece can carry stands in one of the page's tables, so a new one is never left off.
	var tabled := []
	for heading: String in CharacterPage.GROUPS:
		tabled.append_array(CharacterPage.GROUPS[heading])
	for stat: String in LootTable.STAT_LABELS:
		_check(stat in tabled or CharacterPage.ATTRIBUTES.has(stat) or stat in [Inventory.ALL_ATTRIBUTES, "stone_ranks"],
				"%s has a table on the character page" % stat)

	# A fresh hero: a blow, a clock and a sight, and what a click does at the head.
	var page := CharacterPage.new(Inventory.new(), 1.0)
	root.add_child(page)
	_check(_sheet_value(page, "damage") == "1", "a bare hand does 1 (%s)" % _sheet_value(page, "damage"))
	_check(_sheet_value(page, "fight_clock") == "30.0s",
			"the clock is the fight's (%s)" % _sheet_value(page, "fight_clock"))
	_check(_sheet_value(page, "sight") == str(Inventory.BASE_SIGHT), "and the sight the base")
	_check(page.find_child("armor", true, false) == null, "armour at nothing is no row")
	var click: Label = page.find_child(CharacterPage.PER_CLICK, true, false)
	var idle: Label = page.find_child(CharacterPage.PER_SECOND, true, false)
	_check(click != null and click.text == "1" and idle != null and idle.text == "0",
			"with no swing a second does nothing and a click does its 1")
	_check(UITheme.title_of(page._panel).text == CharacterPage.TITLE and page._title.text == "Adventurer",
			"the bar says what the page is, and the card whose it is")
	_check(_sheet_value(page, "kills") == "0" and page.find_child("depth", true, false) == null,
			"the kills are counted under Misc from the first, the depth once one is won")
	page.inventory.play_seconds = 3725.0
	await process_frame
	_check(_sheet_value(page, "time") == "1h 2m", "and the time played, kept moving while the page is up (%s)"
			% _sheet_value(page, "time"))
	page.queue_free()

	# Geared past the crit cap: the fight's numbers, capped, signed and sourced.
	var hero := Inventory.new()
	var blade := Item.new()
	blade.type = "Wooden Sword"
	blade.stats = {"damage": 9.0, "crit_chance": 150.0, "crit_damage": 50.0, "attack_speed": 2.0}
	hero.equipment.equip(Equipment.Socket.WEAPON, blade)
	page = CharacterPage.new(hero, 1.0)
	root.add_child(page)
	_check(_sheet_value(page, "damage") == "10", "the bare hand is on top of the gear (%s)" % _sheet_value(page, "damage"))
	_check("Bare hands +1" in (page.find_child("damage", true, false) as Control).tooltip_text, "and says so")
	_check(_sheet_value(page, "crit_chance") == "100%", "crit chance stops where the fight stops it")
	_check("At most 100%" in (page.find_child("crit_chance", true, false) as Control).tooltip_text,
			"and its tooltip says where")
	_check(_sheet_value(page, "crit_damage") == "+50%", "what a crit adds carries its sign")
	# 10 a blow, every blow a crit adding half: 15, twice a second.
	var second: Label = page.find_child(CharacterPage.PER_SECOND, true, false)
	_check(second != null and second.text == "30", "a swinging weapon heads the page with a second of it (%s)"
			% (second.text if second != null else "none"))
	var each: Label = page.find_child(CharacterPage.PER_CLICK, true, false)
	_check(each != null and each.text == "15", "and a click is the same average blow (%s)"
			% (each.text if each != null else "none"))
	_check(each != null and (each.get_parent() as Control).tooltip_text.is_empty()
			and (each.get_parent().get_child(0) as Label).text.ends_with("(avg)"),
			"each says it is an average in its name, with no tooltip")
	hero.dungeon_depth = 3
	hero.kills = 1234
	page.open()
	_check(_sheet_value(page, "depth") == "3" and _sheet_value(page, "kills") == "1,234",
			"a depth won and the kills are rows under Misc")

	# A change since the last look is written beside the number; put away, the next look starts again.
	blade.stats["damage"] = 19.0
	page.open()
	var change: Label = page.find_child("damage", true, false).find_child(CharacterPage.CHANGE_NAME, true, false)
	_check(change != null and change.text == "+10", "a number that moved says by how much (%s)"
			% (change.text if change != null else "none"))
	_check(change != null and change.get_theme_color("font_color") == Palette.LEAF, "in leaf, for more")
	page.hide()
	page.show()
	page.open()
	_check(page.find_child("damage", true, false).find_child(CharacterPage.CHANGE_NAME, true, false) == null,
			"and once the page has been put away it is the new mark")
	blade.stats["bleed"] = 20.0
	page.open()
	var bleed := page.find_child("bleed", true, false)
	_check(bleed != null and bleed.find_child(CharacterPage.CHANGE_NAME, true, false) == null,
			"a stat that was nothing is a new row, not a change")

	# The uniques worn and the capstones learned, which change a fight rather than a number.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var luck := Item.rolled_unique("beginners_luck", rng, 1)
	hero.equipment.equip(hero.equipment.sockets_for(luck)[0], luck)
	var assassin := Item.rolled_capstone("assassin", 1, rng)
	hero.skills.stones["1"] = assassin
	hero.skills.ranks["1"] = 1
	page.open()
	var squares := page.find_children("*", "Panel", true, false).filter(func(n: Node) -> bool: return n is ItemSlot)
	_check(squares.size() == 2 and (squares[0] as ItemSlot).item == luck
			and squares[0].has_meta(ItemCard.NO_COMPARE), "a worn unique is a square held against nothing")
	_check((squares[1] as ItemSlot).item == assassin and squares[1].has_meta(ItemCard.NO_COMPARE),
			"and a capstone holding a point another")
	_check(_sheet_value(page, "crit_chance") == "25%", "Beginner's Luck's crit chance is the one the fight uses")
	page.queue_free()

	# The curses: open until the page has been looked at and put away once this session, then folded.
	CharacterPage._curses_shown = false
	var cursed := Inventory.new()
	cursed.curses.assign([Curses.WILD_TILES])
	page = CharacterPage.new(cursed, 1.0)
	root.add_child(page)
	var folds := func() -> Array:
		return page.find_children("*", "VBoxContainer", true, false).filter(func(n: Node) -> bool: return n is Accordion)
	_check((folds.call()[0] as Accordion).is_open(), "the curses stand open the first time")
	# Built standing up, as no page in the game is: shown is what makes putting it away a look.
	page.hide()
	page.show()
	page.hide()
	page.show()
	page.open()
	_check(not (folds.call()[0] as Accordion).is_open(), "and folded once they have been seen")
	(folds.call()[0] as Accordion).toggle()
	page.hide()
	page.show()
	page.open()
	_check((folds.call()[0] as Accordion).is_open(), "opened again, they stay open")
	page.queue_free()
	await process_frame
	return true


func _test_character_page() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	await process_frame
	var blade := Item.new()
	blade.type = "Wooden Sword"
	blade.stats = {"damage": 5.0, "strength": 12.0}
	main.inventory.equipment.equip(Equipment.Socket.WEAPON, blade)
	_check(main._character_button.visible, "the corner can be pressed on the map")
	_check(main._character_button.size.x > 0.0, "and it has the panel's size (%s)" % main._character_button.size)
	main._character_button.pressed.emit()
	await process_frame
	_check(main.character_page.visible and not main._character_button.visible, "the page takes the corner")
	var strength: Label = main.character_page.find_child("strength", true, false)
	_check(strength != null and strength.text == "12", "strength is on its disc, the blade's")
	var said := ""
	for label: Node in main.character_page.find_children("*", "Label", true, false):
		said += (label as Label).text + "|"
	# 5 and 2.4% for the strength is 5.12, which the fight rounds before the bare hand's 1 goes on top.
	var damage: Node = main.character_page.find_child("damage", true, false)
	_check(said.contains("Damage|") and damage != null
			and (damage.find_child(UITheme.TABLE_VALUE, true, false) as Label).text == "6",
			"a stat that is something is a row, and its number is what a blow does (%s)" % said)
	_check(not said.contains("Armour"), "and one that is nothing is not")
	# The pencil puts the game's own text box up, holding the name as it is; what is typed and submitted
	# is the character's. The page wears the name on its bar, as the corner and the hero's tips do.
	var pencils: Array = main.character_page.find_children("", "Button", true, false).filter(
			func(b: Button) -> bool: return b.tooltip_text == "Rename")
	_check(pencils.size() == 1, "the pencil stands beside the name")
	pencils[0].pressed.emit()
	await process_frame
	var prompts: Array = main._ui_layer.get_children().filter(func(n: Node) -> bool: return n is TextPrompt)
	_check(prompts.size() == 1 and prompts[0]._field.text == main.inventory.hero(),
			"the pencil puts up a text box holding the name")
	prompts[0]._field.text = "  Cobalt  "
	prompts[0]._field.text_submitted.emit(prompts[0]._field.text)
	_check(main.inventory.hero() == "Cobalt" and Inventory.load_from(TEST_PATH).hero() == "Cobalt",
			"a name typed in is the character's, and saved")
	_check(main.character_page._title.text == "Cobalt", "the page's bar says it")
	# The corner wears no name (2026-10-03): where it stood is what a click does, as the page heads
	# itself, read again off the save the name was written in.
	await process_frame
	_check(main._character._click_label.text == BigNumber.format(main.character_page._now[CharacterPage.PER_CLICK]),
			"the corner says what a click does, as the page does (%s)" % main._character._click_label.text)
	main._on_name_entered("")
	_check(main.inventory.hero() == "Cobalt", "an empty answer leaves the name as it was")
	main._on_left_page_closed()
	_check(not main.character_page.visible and main._character_button.visible, "the X puts it away")
	main.queue_free()
	_clear_save()
	return true


## The ledger on its own, with no scene: every gain reaches the inventory as it lands; a tile fight
## writes each one down and a run writes at `bank_kills`, as it ends.
func _test_fight_ledger() -> bool:
	_clear_save()
	var sword := Item.new()
	sword.type = LootTable.ITEMS.keys()[0]
	var orb: String = OrbTable.ORBS.keys()[0]

	var bag := Inventory.new()
	var tile := FightLedger.new(bag, TEST_PATH)
	tile.add_loot(sword)
	tile.add_gold(7)
	tile.add_orb(orb)
	tile.add_xp(1)
	var on_disk := Inventory.load_from(TEST_PATH)
	_check(bag.items.has(sword) and bag.gold == 7 and bag.orb_count(orb) == 1 and bag.xp + bag.level > 1,
			"a tile fight banks every gain as it lands")
	_check(on_disk.total() == 1 and on_disk.gold == 7 and on_disk.first_sword_taken, "and writes it down")
	_check(tile.discard(sword) and bag.total() == 0, "a find thrown away comes back out of the bag")
	_check(not tile.discard(sword), "and one no longer there is not thrown away twice")

	_clear_save()
	bag = Inventory.new()
	var run := FightLedger.new(bag, TEST_PATH, true)
	run.add_loot(sword)
	run.add_gold(7)
	run.add_orb(orb)
	run.add_xp(1)
	_check(bag.items.has(sword) and bag.gold == 7 and bag.orb_count(orb) == 1 and bag.first_sword_taken,
			"a run puts what it earns in the bag at once")
	_check(not FileAccess.file_exists(TEST_PATH), "and writes none of it while it goes on")
	run.bank_kills(1)
	var written := Inventory.load_from(TEST_PATH)
	_check(written.total() == 1 and written.gold == 7 and written.kills == 1, "until its kills are banked, in one write")
	_clear_save()
	return true


## A long haul scrolls rather than running the verdict off the screen; a short one shows whole.
func _test_drops_scroll() -> bool:
	var view := DropsView.new()
	var few: Array[Item] = [_piece(ItemRarity.Rarity.COMMON, 1), _piece(ItemRarity.Rarity.RARE, 2)]
	view.fill(few)
	_check(view._scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"one row shows whole, with nothing to scroll")
	var many: Array[Item] = []
	for i in 30:
		many.append(_piece(ItemRarity.Rarity.COMMON, 1))
	view.fill(many)
	_check(view._scroll.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
			and view._scroll.custom_minimum_size.y < 8 * ItemSlot.SIDE,
			"thirty drops are cut to a scrolling window: %s" % view._scroll.custom_minimum_size.y)
	# An orb under the cursor puts the bag's own orb card up, saying what it does.
	view.fill(few, {"Orb of Transmutation": 2})
	(view._orbs.get_child(0) as OrbSlot).hovered.emit("Orb of Transmutation")
	_check(view._orb_card.visible and _labels_under(view._orb_card).any(func(line: Label) -> bool:
			return line.text == OrbTable.describe("Orb of Transmutation")), "a found orb's card says what it does")
	view.free()
	return true
