extends "res://tests/inventory_base.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   python tests/run_all.py inventory_orbs
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.


func _run() -> void:
	_clear_save()
	_check(_test_orb_tables() == true, "orb table tests ran to the end")
	_check(_test_orb_verbs() == true, "orb verb tests ran to the end")
	_check(_test_wall_unlocks() == true, "wall unlock tests ran to the end")
	_check(_test_runes() == true, "rune tests ran to the end")
	_check(_test_locks_and_breaks() == true, "lock and break tests ran to the end")
	_check(_test_orb_saving() == true, "orb saving tests ran to the end")
	_check(_test_player_level() == true, "player level tests ran to the end")
	_check(await _test_crafting_from_the_bag() == true, "crafting tests ran to the end")
	_check(await _test_a_finger_selects_first() == true, "finger crafting tests ran to the end")
	_check(await _test_tips() == true, "tip tests ran to the end")
	_check(await _test_first_steps() == true, "first step tests ran to the end")
	_check(_test_unique_table() == true, "unique table tests ran to the end")
	_check(_test_rarity_frames() == true, "rarity frame tests ran to the end")
	_clear_save()
	_report("inventory: orbs")


## The orb tables themselves: six orbs, six icons that resolve, and a drop curve that runs the
## right way round. Nothing here crafts anything -- this is the file being well formed.
func _test_orb_tables() -> bool:
	_check(OrbTable.ORBS.size() == 6, "there are six orbs")
	for orb: String in OrbTable.ORBS:
		_check(ResourceLoader.exists(OrbTable.icon_path(orb)),
				"%s has an icon at %s" % [orb, OrbTable.icon_path(orb)])
		_check(OrbTable.icon(orb) != null, "%s loads its icon" % orb)
		_check(int(OrbTable.ORBS[orb]["weight"]) > 0, "%s can be drawn" % orb)
		# The card reads it out as a sentence, so it has to be one.
		_check(OrbTable.describe(orb).ends_with("."), "%s describes itself in a sentence" % orb)
	# The same shape LootTable's curve has, and the same ceiling: a chance cannot pass certainty.
	_check(OrbTable.chance_for("Skeleton Warrior") > 0.0, "a common body can carry an orb")
	for enemy: String in EnemyRoster.names():
		_check(OrbTable.chance_for(enemy) <= 1.0, "%s cannot exceed certainty" % enemy)
	# Weighted draws land on every orb eventually and never outside the table.
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var seen := {}
	for i in 4000:
		var orb := OrbTable.roll("Skeleton Warrior", rng, true)
		_check(OrbTable.ORBS.has(orb), "a drawn orb is one of the six")
		seen[orb] = true
	_check(seen.size() == 6, "every orb can be drawn, saw %d" % seen.size())
	# The deepest wall ever broken unlocks them two at a time, in the tray's order, for a body and a shelf alike.
	for walls in 3:
		var pool := OrbTable.unlocked(walls)
		_check(pool == OrbTable.orbs().slice(0, 2 * walls + 2), "%d walls unlock %s" % [walls, pool])
		var drawn := {}
		for i in 2000:
			drawn[OrbTable.roll("Skeleton Warrior", rng, true, 0.0, walls)] = true
			drawn[OrbTable.roll_favoured(rng, walls)] = true
		_check(drawn.size() == pool.size() and drawn.keys().all(func(orb: String) -> bool: return orb in pool),
				"with %d walls down only those drop: %s" % [walls, drawn.keys()])
	_check(OrbTable.unlocked(0) == ["Orb of Transmutation", "Orb of Augmentation"]
			and OrbTable.unlocked(1).slice(2) == ["Orb of Alchemy", "Orb of Divinity"]
			and OrbTable.unlocked(5).slice(4) == ["Orb of Chaos", "Orb of Exaltation"],
			"no wall, then Alchemy and Divinity, then Chaos and Exaltation")
	return true


## The walls' ladder (the user's, 2026-10-09), read off the deepest wall ever broken so a transcension
## keeps it: the orbs two a wall, Gollux and the runes at the third, distant charting at the fourth, two
## root branches at the fifth, the filter at the sixth, the abilities at the seventh, a branch a wall
## after -- and the root's slots set as a save loads, before its tree, so a stone out on a branch the
## walls opened comes back.
func _test_wall_unlocks() -> bool:
	var player := Inventory.new()
	_check(player.walls_ever() == 0, "a fresh player has broken no wall")
	player.farthest_land = MapBuilder.START_LAND_RADIUS + MapBuilder.WALL_STEP - 1
	_check(player.walls_ever() == 0, "nor has land short of a whole wall's step")
	player.farthest_land = MapBuilder.START_LAND_RADIUS + 3 * MapBuilder.WALL_STEP
	_check(player.walls_ever() == 3 and player.transcended().walls_ever() == 3,
			"three walls ever, and a transcension keeps them")
	var opens := {WallUnlocks.GOLLUX: 3, WallUnlocks.RUNES: 3, WallUnlocks.DISTANT: 4, WallUnlocks.FILTER: 6,
			WallUnlocks.ABILITIES: 7}
	for id: String in opens:
		_check(not WallUnlocks.has(opens[id] - 1, id) and WallUnlocks.has(opens[id], id)
				and WallUnlocks.has(opens[id] + 5, id), "%s opens at wall %d and stays open" % [id, opens[id]])
	var branches := []
	for walls in 11:
		branches.append(WallUnlocks.root_branches(walls))
	_check(branches == [1, 1, 1, 2, 2, 3, 3, 3, 4, 5, 6],
			"the root's branches: one, one more at the third and fifth walls and a wall from the eighth (%s)" % [branches])
	var hours := []
	for walls in 4:
		hours.append(WallUnlocks.camp_hours(walls))
	_check(hours == [1, 2, 3, 4], "a camp holds an hour, and an hour more a wall (%s)" % [hours])
	_check(player.capacity() == Inventory.CAPACITY + 3 * WallUnlocks.BAG_SLOTS_A_WALL
			and player.transcended().capacity() == player.capacity()
			and Inventory.new().capacity() == Inventory.CAPACITY and player.stash().capacity() == Inventory.CAPACITY,
			"the bag holds a wall's squares more a wall ever broken, the heirlooms' stash none (%d)" % player.capacity())
	var hour := "+1 camp hour"
	var slots := "+%d bag slots" % WallUnlocks.BAG_SLOTS_A_WALL
	var named := func(wall: int) -> Array:
		return WallUnlocks.of_wall(wall).map(func(unlock: Dictionary) -> String: return unlock["name"])
	_check(named.call(0).is_empty() and named.call(1) == ["Orb of Alchemy", "Orb of Divinity", hour, slots]
			and named.call(2) == ["Orb of Chaos", "Orb of Exaltation", hour, slots]
			and named.call(3) == ["Gollux", "Runes", "+1 skill branch", hour, slots]
			and named.call(4) == ["Distant charting", hour, slots] and named.call(5) == ["+1 skill branch", hour, slots]
			and named.call(6) == ["Item filter", hour, slots] and named.call(7) == ["Abilities", hour, slots]
			and named.call(9) == ["+1 skill branch", hour, slots],
			"each wall's panel names what it opens (%s, %s)" % [named.call(3), named.call(9)])
	for wall in range(1, 10):
		for unlock: Dictionary in WallUnlocks.of_wall(wall):
			_check(load(unlock["icon"]) != null and not str(unlock["tip"]).is_empty(),
					"%s has a mark and a tooltip" % unlock["name"])

	# The root's slots: a stone on the third branch, out on a fifth wall, comes back off the save.
	player.farthest_land = MapBuilder.START_LAND_RADIUS + 5 * MapBuilder.WALL_STEP
	SkillTree.root_slots = WallUnlocks.root_branches(player.walls_ever())
	var stone := _node("Dexterity Node", "global_increased_attack_speed")
	_check(player.skills.place(stone, "2").is_empty() and player.skills.stones.has("2"),
			"three branches take a stone on the third")
	player.save(TEST_PATH)
	SkillTree.root_slots = SkillTree.ROOT_CONNECTORS
	var back := Inventory.load_from(TEST_PATH)
	_check(SkillTree.root_slots == 3 and back.skills.stones.has("2"),
			"the save sets the root's slots before its tree, so the stone stays")
	_check(back.reach(MapBuilder.START_LAND_RADIUS + 8 * MapBuilder.WALL_STEP) and SkillTree.root_slots == 4,
			"an eighth wall's land grows the root again")
	Inventory.load_from("user://no_such_save.json")
	_check(SkillTree.root_slots == SkillTree.ROOT_CONNECTORS, "and a fresh start is the root's one")
	SkillTree.root_slots = SkillTree.ROOT_CONNECTORS
	return true


## The runes (`RuneTable`, the user's 2026-10-09): what a cave body carries, and what each does to a
## tile's rune work -- never to its own modifiers -- with every modifier, every Depth and the Ascent on
## a count of its own that runs out, and the inventory holding the runes and the work through a save.
func _test_runes() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7070
	for rune: String in RuneTable.names():
		var picture := RuneTable.icon(rune)
		_check(picture != null and picture.get_size() == Vector2(RuneTable.ICON_SIDE, RuneTable.ICON_SIDE),
				"%s has a %d px picture" % [rune, RuneTable.ICON_SIDE])
	_check(RuneTable.roll("Gollux", rng) != "", "Gollux always carries a rune")
	var drawn := {}
	var none := 0
	for i in 3000:
		var rune := RuneTable.roll("Rat", rng)
		if rune.is_empty():
			none += 1
		else:
			drawn[rune] = true
	_check(none > 2000 and drawn.size() == RuneTable.RUNES.size(), "a common body seldom does, and any rune can fall")

	# What Unrest may give: only what a farm run feels, none the tile has, none a modifier on it refuses.
	var farmed := TileMods.MODS.keys().filter(func(id: String) -> bool: return TileMods.MODS[id].get("farm", false))
	_check(RuneTable.pool([], RuneTable.fresh()) == Array(farmed), "a bare tile may take any modifier a farm run feels")
	_check(not "thick_skinned" in RuneTable.pool(["thick_skinned"], RuneTable.fresh()), "but none it has of its own")
	var barren := RuneTable.fresh()
	barren["mods"].append({"id": "barren", "tier": 1, "left": RuneTable.KILLS})
	_check(not "gilded" in RuneTable.pool([], barren) and not "barren" in RuneTable.pool([], barren),
			"nor one a rune already gave it, nor one that will not stand beside it")

	var work := RuneTable.fresh()
	var own := ["thick_skinned"]
	for rune: String in [RuneTable.SHIFTING, RuneTable.UPHEAVAL, RuneTable.STILLNESS]:
		_check(not RuneTable.can_apply(rune, own, work), "%s does nothing to a tile no rune has touched" % rune)
	_check(RuneTable.apply(RuneTable.UNREST, own, work, rng) and RuneTable.apply(RuneTable.UNREST, own, work, rng),
			"Unrest gives a modifier, twice")
	var ids: Array = work["mods"].map(func(mod: Dictionary) -> String: return mod["id"])
	_check(ids.size() == 2 and ids[0] != ids[1] and not "thick_skinned" in ids
			and work["mods"].all(func(mod: Dictionary) -> bool: return mod["tier"] == 1 and mod["left"] == RuneTable.KILLS),
			"two new ones, at tier I, on full counts, none the tile's own (%s)" % [ids])
	for i in 20:
		RuneTable.apply(RuneTable.SHIFTING, own, work, rng)
		for mod: Dictionary in work["mods"]:
			var once: bool = TileMods.MODS[mod["id"]].get("once", false)
			_check(mod["tier"] >= 1 and mod["tier"] <= (1 if once else RuneTable.MOST_TIER),
					"Shifting deals %s a tier it may have (%d)" % [mod["id"], mod["tier"]])
	work["mods"][0]["left"] = 40
	RuneTable.apply(RuneTable.UPHEAVAL, own, work, rng)
	_check(work["mods"].size() == 2 and work["mods"][0]["left"] == 40 and not "thick_skinned" in RuneTable.mods_of(work),
			"Upheaval keeps how many and how long, never the tile's own")
	RuneTable.apply(RuneTable.STILLNESS, own, work, rng)
	_check(work["mods"].size() == 1, "Stillness takes one away whole")
	RuneTable.apply(RuneTable.DEPTH, own, work, rng)
	RuneTable.apply(RuneTable.DEPTH, own, work, rng)
	_check(RuneTable.deeper(work) == 2, "Depth stacks")
	_check(RuneTable.apply(RuneTable.ASCENT, own, work, rng) and not RuneTable.can_apply(RuneTable.ASCENT, own, work),
			"Ascent works once")

	# Every count on its own: the modifier at 1 goes at the next kill, the rest go on.
	work["mods"][0]["left"] = 1
	work["depth"][0] = 1
	var gone := RuneTable.count_kill(work)
	_check(gone["mods"].size() == 1 and gone["depth"] == 1 and not gone["ascent"] and RuneTable.any_gone(gone)
			and work["mods"].is_empty() and RuneTable.deeper(work) == 1 and RuneTable.ascended(work),
			"a kill runs out what was at its last, and only that")
	work["ascent"] = 1
	work["depth"][0] = 5
	gone = RuneTable.count_kill(work)
	_check(gone["ascent"] and not RuneTable.ascended(work) and work["depth"] == [4],
			"the Ascent runs out on its own count")

	# The inventory: held like orbs, spent only where one does something, and both kept by the save.
	var player := Inventory.new()
	var spot := Vector2i(130, 131)
	player.add_rune(RuneTable.UNREST, 2)
	player.add_rune(RuneTable.STILLNESS)
	player.add_rune("Rune of Nothing")
	_check(player.rune_count(RuneTable.UNREST) == 2 and not player.runes.has("Rune of Nothing"),
			"runes are counted by name")
	_check(not player.use_rune(RuneTable.STILLNESS, spot, [], rng) and player.rune_count(RuneTable.STILLNESS) == 1
			and not player.has_runes(spot), "one that would do nothing is not spent")
	_check(player.use_rune(RuneTable.UNREST, spot, [], rng) and player.rune_count(RuneTable.UNREST) == 1
			and player.has_runes(spot) and player.rune_work(spot)["mods"].size() == 1, "one that does is spent on its tile")
	_check(player.use_rune(RuneTable.STILLNESS, spot, [], rng) and not player.runes.has(RuneTable.STILLNESS),
			"and the last of one is gone from the count")
	player.use_rune(RuneTable.UNREST, spot, [], rng)
	player.rune_state(Vector2i(1, 1))
	player.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(back.runes.is_empty() and back.rune_work(spot)["mods"] == player.rune_work(spot)["mods"]
			and not back.has_runes(Vector2i(1,
					1)), "the save keeps the work still going, and no tile with none (%s)" % [back.runed])
	_check(player.transcended().runed.is_empty() and player.transcended().runes.is_empty(),
			"a transcension leaves both with the world")
	return true


## The six verbs, each against a piece it should take and a piece it should refuse. The rule under
## all of them: rarity and modifiers may move, level and base stats may not.
func _test_orb_verbs() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242

	# --- Transmutation: a common becomes an uncommon carrying uncommon's band ---
	var common := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 5)
	var was_level := common.level
	var was_stats := common.base_stats()
	_check(OrbTable.can_apply("Orb of Transmutation", common), "a common can be transmuted")
	_check(OrbTable.apply("Orb of Transmutation", common, rng), "transmutation lands")
	_check(common.rarity == ItemRarity.Rarity.UNCOMMON, "transmutation makes it uncommon")
	var band: Array = ItemRarity.MOD_COUNT[ItemRarity.Rarity.UNCOMMON]
	_check(common.mods.size() >= int(band[0]) and common.mods.size() <= int(band[1]),
			"transmutation rolls uncommon's own band, got %d" % common.mods.size())
	# The rule that holds for every one of the six, checked here where a piece has just changed as
	# much as an orb can change it.
	_check(common.level == was_level, "an orb never moves a piece's level")
	_check(common.base_stats() == was_stats, "an orb never moves a piece's base stats")
	var magic := Item.rolled("Wooden Shield", ItemRarity.Rarity.UNCOMMON, rng, 3)
	_check(OrbTable.can_apply("Orb of Transmutation", magic), "an uncommon can be transmuted again")
	_check(OrbTable.apply("Orb of Transmutation", magic, rng), "and the reroll lands")
	_check(magic.rarity == ItemRarity.Rarity.UNCOMMON, "a transmuted uncommon stays uncommon")
	# The first craft is a sure thing: a common Broken Sword transmuted carries "+1 Damage" alone, on
	# any seed. Its own generator, so the draws below are what they were.
	var sure_rng := RandomNumberGenerator.new()
	for seed_value in 20:
		sure_rng.seed = seed_value
		var first := Item.rolled(LootTable.FIRST_DROP, ItemRarity.Rarity.COMMON, sure_rng)
		OrbTable.apply("Orb of Transmutation", first, sure_rng)
		_check(first.rarity == ItemRarity.Rarity.UNCOMMON and first.mods.size() == 1
				and first.mods[0] == {"id": "added_damage", "value": 1},
				"a Broken Sword's first transmutation is +1 Damage alone, got %s" % [first.mods])

	# --- Alchemy: straight to rare from below, a reroll at rare, refused above ---
	var climbing := Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng, 2)
	_check(OrbTable.apply("Orb of Alchemy", climbing, rng), "alchemy lands on a common")
	_check(climbing.rarity == ItemRarity.Rarity.RARE, "alchemy makes it rare in one step")
	_check(OrbTable.apply("Orb of Alchemy", climbing, rng), "alchemy rerolls a rare")
	_check(climbing.rarity == ItemRarity.Rarity.RARE, "and it stays rare")
	# Down as well as up (the user's ruling, 2026-10-02): a rarity orb makes its own rarity from above, and
	# the piece carries what that rarity allows.
	var falling := Item.rolled("Leather Boots", ItemRarity.Rarity.ELITE, rng, 2)
	_check(OrbTable.apply("Orb of Transmutation", falling, rng), "transmutation lands on an epic")
	_check(falling.rarity == ItemRarity.Rarity.UNCOMMON
			and falling.mods.size() <= int(ItemRarity.MOD_COUNT[ItemRarity.Rarity.UNCOMMON][1]) + int(falling.extra_slot),
			"and makes it uncommon, with an uncommon's modifiers")

	# --- Exalted: straight to elite, a reroll at elite, and never as far as unique ---
	_check(OrbTable.apply("Orb of Exaltation", climbing, rng), "exalted lands on a rare")
	_check(climbing.rarity == ItemRarity.Rarity.ELITE, "exalted makes it elite")
	_check(OrbTable.apply("Orb of Exaltation", climbing, rng), "exalted rerolls an elite")
	_check(climbing.rarity == ItemRarity.Rarity.ELITE, "and it stays elite, never unique")
	_check(OrbTable.apply("Orb of Alchemy", climbing, rng) and climbing.rarity == ItemRarity.Rarity.RARE,
			"alchemy takes an elite back down to rare")
	var bare := Item.rolled("Wooden Armour", ItemRarity.Rarity.COMMON, rng, 1)
	_check(not OrbTable.can_apply("Orb of Chaos", bare), "a common has nothing to chaos")

	# --- Augmentation: any rarity with room, and a common has none ---
	_check(not OrbTable.can_apply("Orb of Augmentation", bare), "a common cannot be augmented")
	var rare := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 6)
	var rare_cap := int(ItemRarity.MOD_COUNT[ItemRarity.Rarity.RARE][1])
	while rare.mods.size() < rare_cap:
		var had := rare.mods.size()
		_check(OrbTable.apply("Orb of Augmentation", rare, rng), "augmentation lands while there is room")
		_check(rare.mods.size() == had + 1, "augmentation adds exactly one modifier")
	_check(not OrbTable.can_apply("Orb of Augmentation", rare), "a full rare refuses an augmentation")

	# --- Chaos: the ids stay, the tiers move, and every number sits in its new tier's band ---
	var chaos := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 12)
	var chaos_ids := PackedStringArray()
	for mod in chaos.mods:
		chaos_ids.append(str(mod["id"]))
	var tiers_moved := false
	for attempt in 20:
		var before_tiers := []
		for mod in chaos.mods:
			before_tiers.append(chaos.tier_of(mod))
		_check(OrbTable.apply("Orb of Chaos", chaos, rng), "chaos lands")
		for i in chaos.mods.size():
			if chaos.tier_of(chaos.mods[i]) != int(before_tiers[i]):
				tiers_moved = true
	var chaos_after := PackedStringArray()
	for mod in chaos.mods:
		chaos_after.append(str(mod["id"]))
		var chaos_band := ModifierTable.band_for(str(mod["id"]), chaos.tier_of(mod))
		_check(int(mod["value"]) >= int(chaos_band[0]) and int(mod["value"]) <= int(chaos_band[1]),
				"a chaosed %s sits in its new band" % mod["id"])
	_check(chaos_ids == chaos_after, "chaos keeps every modifier it found")
	_check(tiers_moved, "chaos moves a tier at least once in twenty tries")
	_check(chaos.rarity == ItemRarity.Rarity.ELITE, "chaos keeps the rarity")

	# --- Divine: the ids stay, the numbers may move, and stay inside the band ---
	var divine := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 9)
	var before_ids := PackedStringArray()
	for mod in divine.mods:
		before_ids.append(str(mod["id"]))
	_check(OrbTable.can_apply("Orb of Divinity", divine), "a piece with modifiers can be divined")
	var moved := false
	for attempt in 20:
		var before_values := []
		for mod in divine.mods:
			before_values.append(int(mod["value"]))
		_check(OrbTable.apply("Orb of Divinity", divine, rng), "divine lands")
		for i in divine.mods.size():
			if int(divine.mods[i]["value"]) != int(before_values[i]):
				moved = true
	var after_ids := PackedStringArray()
	for mod in divine.mods:
		after_ids.append(str(mod["id"]))
	_check(before_ids == after_ids, "divine keeps every modifier it found")
	_check(moved, "divine moves a value at least once in twenty tries")
	for mod in divine.mods:
		var mod_band := ModifierTable.band_for(str(mod["id"]), divine.tier_of(mod))
		_check(int(mod["value"]) >= int(mod_band[0]) and int(mod["value"]) <= int(mod_band[1]),
				"a divined %s stays in its band" % mod["id"])
	_check(not OrbTable.can_apply("Orb of Divinity", bare), "a bare common has nothing to divine")

	# `why_not` is the exact complement of `can_apply`, for every orb against every piece the suite
	# has in hand -- so the card can ask one question rather than two and never go silent.
	for orb: String in OrbTable.ORBS:
		for piece: Item in [common, magic, climbing, bare, rare, chaos, divine]:
			var quiet := OrbTable.why_not(orb, piece).is_empty()
			_check(quiet == OrbTable.can_apply(orb, piece),
					"%s explains itself on a %s %s" % [orb, piece.rarity_name(), piece.type])
	# Nothing at all is refused without a fuss rather than crashing.
	_check(not OrbTable.can_apply("Orb of Chaos", null), "an orb refuses a piece that is not there")
	_check(OrbTable.why_not("Orb of Chaos", null).is_empty(), "and has nothing to say about it")
	return true


## The two marks a blacksmith leaves on a piece, read against the orbs. A **lock** has to survive all
## six, and a **break** has to stop all six -- and what a reroll leaves behind is a draw rather
## than a rule until it has been drawn a few thousand times, so the lock is walked through random
## orbs over many seeds rather than through one example of each.
func _test_locks_and_breaks() -> bool:
	const RUNS := 200
	const BLOWS := 12
	var rng := RandomNumberGenerator.new()
	var orbs := OrbTable.orbs()
	var landed := {}
	for run in RUNS:
		rng.seed = run
		# Half start uncommon and half rare, so every rarity orb meets a lock from below and from above.
		var start := ItemRarity.Rarity.UNCOMMON if run % 2 == 0 else ItemRarity.Rarity.RARE
		var piece := Item.rolled("Wooden Sword", start, rng, 7)
		_check(Blacksmith.lock(piece, rng), "a piece with modifiers takes a lock")
		var pinned := piece.locked_mod().duplicate()
		for blow in BLOWS:
			var orb: String = orbs[rng.randi_range(0, orbs.size() - 1)]
			if not OrbTable.can_apply(orb, piece):
				continue
			_check(OrbTable.apply(orb, piece, rng), "%s lands" % orb)
			landed[orb] = int(landed.get(orb, 0)) + 1
			var still := piece.locked_mod()
			_check(str(still.get("id", "")) == str(pinned["id"]),
					"%s leaves the locked modifier where it found it" % orb)
			# Divine is the one that would move it, and the one this is really asking about.
			_check(int(still.get("value", -1)) == int(pinned["value"]),
					"%s leaves the locked value alone" % orb)
			var locks := 0
			for mod in piece.mods:
				if bool(mod.get("locked", false)):
					locks += 1
			_check(locks == 1, "there is exactly one lock after a %s" % orb)
			# The lock is one of the rarity's handful and never an extra on top of it.
			_check(piece.mods.size() <= int(ItemRarity.MOD_COUNT[piece.rarity][1]),
					"%s keeps a %s piece inside its own ceiling (%d mods)"
					% [orb, piece.rarity_name(), piece.mods.size()])
			# No orb takes a piece down a rarity, so a locked piece is never a common and never
			# transmuted: a common carrying a modifier is a contradiction in MOD_COUNT.
			_check(piece.rarity != ItemRarity.Rarity.COMMON, "a locked piece never lands on common")
	# The walk has to have actually used the orbs it is meant to be testing.
	for orb: String in OrbTable.orbs():
		_check(int(landed.get(orb, 0)) > 0, "%s was tried against a lock (%s)" % [orb, landed])
	rng.seed = WORLD_SEED
	var pinned_piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 5)
	_check(Blacksmith.lock(pinned_piece, rng), "an elite takes a lock")

	# Item says which line is the locked one, and the block writes that one in a base stat's ink
	# among the rust -- with no word for it on the line.
	_check(pinned_piece.mod_lines().count(pinned_piece.locked_line()) == 1,
			"exactly one line is the locked one (%s)" % [pinned_piece.mod_lines()])
	_check(not "locked" in " ".join(pinned_piece.mod_lines()), "and no line spells it out")
	var written := VBoxContainer.new()
	ItemDetails.fill(written, pinned_piece, 150.0)
	var inked := 0
	# A modifier's row is the line Item wrote, whole.
	for line: Label in written.find_children("*", "Label", true, false):
		if line.text in pinned_piece.mod_lines() and line.get_theme_color("font_color") == Palette.TEXT:
			_check(line.text == pinned_piece.locked_line(), "only the locked modifier is in ink: %s" % line.text)
			inked += 1
	_check(inked == 1, "the block writes the locked modifier in ink")
	written.free()

	# A broken piece is out of the game as far as the orbs are concerned, and each of the six says so.
	var ruined := Item.rolled("Leather Boots", ItemRarity.Rarity.RARE, rng, 4)
	var was_mods := ruined.mods.duplicate(true)
	var was_rarity := ruined.rarity
	ruined.broken = true
	for orb: String in OrbTable.ORBS:
		_check(not OrbTable.can_apply(orb, ruined), "%s refuses a broken piece" % orb)
		_check(not OrbTable.why_not(orb, ruined).is_empty(), "%s says why" % orb)
		_check(not OrbTable.apply(orb, ruined, rng), "%s does nothing to one" % orb)
	_check(ruined.mods == was_mods and ruined.rarity == was_rarity,
			"a broken piece comes through all six untouched")
	_check(not Blacksmith.can_lock(ruined), "and the smith will not lock it either")

	# Both marks go into the save, and a piece written before there was a smith reads as whole.
	var back := Item.from_dict(ruined.to_dict())
	_check(back != null and back.broken, "broken round-trips")
	_check(back.to_dict() == ruined.to_dict(), "and the broken piece round-trips exactly")
	var copy := Item.from_dict(pinned_piece.to_dict())
	_check(copy != null and copy.locked_mod() == pinned_piece.locked_mod(),
			"the lock comes back on the line it was on")
	_check(copy.to_dict() == pinned_piece.to_dict(), "and the locked piece round-trips exactly")
	var plain := Item.rolled("Wooden Shield", ItemRarity.Rarity.UNCOMMON, rng, 2)
	var old := plain.to_dict()
	old.erase("broken")
	_check(not Item.from_dict(old).broken, "a save with no word on it reads as whole")
	return true


## The orbs through the save, and their standing apart from the bag: not counted against the cap,
## not trimmed with it, and dropped by name when a build no longer has them.
func _test_player_level() -> bool:
	_check(PlayerLevel.xp_to_next(1) == PlayerLevel.BASE_KILLS * Encounter.base_xp(MapBuilder.CENTER),
			"the first level costs BASE_KILLS bodies in the middle of the map")
	for level in range(1, 40):
		_check(PlayerLevel.xp_to_next(level + 1) > PlayerLevel.xp_to_next(level),
				"level %d costs more than level %d" % [level + 1, level])
	var short := PlayerLevel.add(1, 0, PlayerLevel.xp_to_next(1) - 1)
	_check(short["level"] == 1 and short["gained"] == 0, "one short of a level is no level")
	var exact := PlayerLevel.add(1, 0, PlayerLevel.xp_to_next(1))
	_check(exact["level"] == 2 and exact["xp"] == 0, "reaching the threshold levels up")
	var over := PlayerLevel.xp_to_next(1) + PlayerLevel.xp_to_next(2) + 3
	var twice := PlayerLevel.add(1, 0, over)
	_check(twice["level"] == 3 and twice["gained"] == 2 and twice["xp"] == 3,
			"overflow carries, and pays for two levels: %s" % [twice])

	_clear_save()
	var bag := Inventory.new()
	_check(bag.level == 1 and bag.xp == 0, "a new player is level 1 with nothing")
	_check(bag.add_xp(over) == 2, "the bag levels twice")
	_check(bag.save(TEST_PATH), "the levelled player saved")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.level == 3 and back.xp == 3, "level and experience came back: %d, %d" % [back.level, back.xp])

	# A version 7 save knew nothing about levels.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 7, "gold": 5, "items": []}')
	file.close()
	var old := Inventory.load_from(TEST_PATH)
	_check(old.level == 1 and old.xp == 0 and old.gold == 5, "a version 7 save comes back at level 1")
	# A hand-edited file comes back obeying the curve.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": %d, "level": -4, "xp": %d, "items": []}'
			% [Inventory.VERSION, PlayerLevel.xp_to_next(1) + 1])
	file.close()
	var edited := Inventory.load_from(TEST_PATH)
	_check(edited.level == 2 and edited.xp == 1, "a bad level is clamped and spare experience paid out")
	_clear_save()
	return true


func _test_orb_saving() -> bool:
	_clear_save()
	var bag := Inventory.new()
	bag.add_orb("Orb of Chaos", 3)
	bag.add_orb("Orb of Divinity")
	_check(bag.orb_count("Orb of Chaos") == 3, "three chaos orbs went in")
	_check(bag.orb_count("Orb of Alchemy") == 0, "an orb never found counts zero")
	_check(bag.total_orbs() == 4, "four orbs in all")
	# A name this build does not have is not a count it keeps.
	bag.add_orb("Orb of Nonsense", 5)
	_check(bag.total_orbs() == 4, "an orb that does not exist is not added")

	# Spending: one at a time, and never past empty.
	_check(bag.spend_orb("Orb of Divinity"), "the last divine is spent")
	_check(bag.orb_count("Orb of Divinity") == 0, "and is gone")
	_check(not bag.orbs.has("Orb of Divinity"), "an emptied orb leaves no entry behind")
	_check(not bag.spend_orb("Orb of Divinity"), "there is no second one to spend")

	# The cap is the bag's, and orbs are not in the bag.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in Inventory.CAPACITY:
		bag.add(Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng, 1))
	_check(bag.is_full(), "the bag is full of boots")
	_check(bag.total() == Inventory.CAPACITY, "orbs are not counted against the cap")
	bag.add_orb("Orb of Chaos")
	_check(bag.orb_count("Orb of Chaos") == 4 and not bag.encumbered(), "and orbs weigh nothing")

	_check(bag.save(TEST_PATH), "the bag with orbs in it saved")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.orb_count("Orb of Chaos") == 4, "the chaos orbs came back")
	_check(back.total_orbs() == 4, "and nothing else came with them")
	_check(back.orbs == bag.orbs, "the orbs round-trip exactly")

	# A version 6 file has no orbs at all, and reads as none rather than as a refusal.
	var older := {
		"version": 6, "first_elite_taken": false, "gold": 12,
		"items": [], "equipped": {}, "autodiscard": [],
	}
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(older, "\t"))
	file = null
	var legacy := Inventory.load_from(TEST_PATH)
	_check(legacy.total_orbs() == 0, "a version 6 save comes back with no orbs")
	_check(legacy.gold == 12, "and keeps everything it did have")

	# A hand-edited file naming an orb this build has retired loses that line and keeps the rest.
	var edited := {
		"version": Inventory.VERSION, "first_elite_taken": false, "gold": 0,
		"items": [{"type": "Wooden Armor", "rarity": "common", "level": 1},
				{"type": "Leather Boot", "rarity": "common", "level": 1}], "equipped": {}, "autodiscard": [],
		"orbs": {"Orb of Chaos": 2, "Orb of Scouring": 9, "Orb of Divinity": -4, "Orb of Alteration": 3,
				"Orb of Transmutation": 1, "Orb of Exalted": 2},
	}
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(edited, "\t"))
	file = null
	var pruned := Inventory.load_from(TEST_PATH)
	_check(pruned.orb_count("Orb of Chaos") == 2, "a known orb survives the read")
	_check(pruned.orb_count("Orb of Transmutation") == 4, "a retired Alteration reads as Transmutation")
	_check(pruned.orb_count("Orb of Exaltation") == 2, "an Orb of Exalted reads as the Orb of Exaltation")
	_check(pruned.total_orbs() == 8, "an unknown orb is dropped and a negative one reads as none")
	_check(pruned.items.map(func(item: Item) -> String: return item.type) == ["Wooden Armour", "Leather Boots"],
			"a piece saved under its old name comes back under its new one")
	_clear_save()
	return true


## Crafting as the player does it: the real panel, the real tray, an orb picked up and a square pressed
## with it. The tables are checked above; this is the wiring -- that the tray never spends on the open
## piece, what a press does to the piece and to the count, and the card's light.
func _test_crafting_from_the_bag() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 4)
	main.inventory.add(sword)
	main.inventory.add_orb("Orb of Transmutation", 2)
	main.inventory.add_orb("Orb of Divinity", 1)
	main._on_bag_pressed()
	main.bag_page._select_item(0)
	for i in 2:
		await process_frame

	# A piece open greys nothing in the tray: no orb is spent on it, so every one held can be picked up.
	var live: Array = main.bag_page._orb_tray.get_children() \
			.filter(func(slot: OrbSlot) -> bool: return slot._live).map(func(slot: OrbSlot) -> String: return slot.orb)
	_check(live == ["Orb of Transmutation", "Orb of Divinity"],
			"with a piece open every orb held stays lit, got %s" % [live])
	_check(main.bag_page._orb_tray.get_child_count() == OrbTable.ORBS.size(),
			"the tray draws every orb, held or not")

	# Pressed with the sword open: the sword is shut and the orb picked up instead, nothing spent.
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	_check(main.bag_page._selected == -1 and not main.bag_page._actions.visible,
			"an orb pressed with a piece open shuts the piece")
	_check(main.bag_page._armed == "Orb of Transmutation", "and is picked up in its place")
	_check(sword.rarity == ItemRarity.Rarity.COMMON and main.inventory.orb_count("Orb of Transmutation") == 2,
			"without being spent on the piece that was open")

	# The square pressed with it, exactly as a click on it does it.
	var craft := func(piece: Item) -> void:
		var square: ItemSlot = _bag_squares(main).filter(func(s: ItemSlot) -> bool: return s.item == piece)[0]
		main.bag_page._on_clicked(_square_spot(square))
	craft.call(sword)
	for i in 2:
		await process_frame
	_check(sword.rarity == ItemRarity.Rarity.UNCOMMON, "the sword came up uncommon")
	_check(not sword.mods.is_empty(), "and carries modifiers")
	_check(main.inventory.orb_count("Orb of Transmutation") == 1, "one orb was spent")
	_check(main.bag_page._armed == "Orb of Transmutation", "and the orb is still in hand while any are left")
	_check(_card_lit(main) == OrbTable.ORBS["Orb of Transmutation"].glow,
			"the hover card is lit from behind in the orb's colour")

	# Alchemy takes it to rare. Then a press that does nothing must not cost the player the orb: broken,
	# the sword is a piece every orb refuses. The square is grey and ignores the click; the handler is
	# checked too, because the guarantee is apply first and spend only if it landed.
	main.inventory.add_orb("Orb of Alchemy")
	main.bag_page._on_orb_pressed("Orb of Alchemy")
	_check(main.bag_page._armed == "Orb of Alchemy", "another orb pressed takes the first one's place")
	craft.call(sword)
	_check(sword.rarity == ItemRarity.Rarity.RARE, "alchemy made it rare")
	sword.broken = true
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	craft.call(sword)
	_check(main.inventory.orb_count("Orb of Transmutation") == 1, "a refused orb is not spent")
	_check(sword.rarity == ItemRarity.Rarity.RARE, "and the piece did not change again")
	sword.broken = false

	# Divine works now that there are modifiers to reroll.
	main.bag_page._on_orb_pressed("Orb of Divinity")
	craft.call(sword)
	for i in 2:
		await process_frame
	_check(sword.rarity == ItemRarity.Rarity.RARE, "divine kept the rarity")
	_check(main.inventory.orb_count("Orb of Divinity") == 0, "the divine orb was spent")

	# An orb that would take a piece down a rarity asks first, and nothing moves until it is answered:
	# Cancel keeps the piece and the orb, Use with the tick spends it and stops the asking.
	main.inventory.add_orb("Orb of Transmutation", 2)
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	craft.call(sword)
	_check(main.bag_page._confirm != null and sword.rarity == ItemRarity.Rarity.RARE
			and main.inventory.orb_count("Orb of Transmutation") == 3, "transmuting a rare asks first")
	_check("uncommon" in _confirm_text(main), "and says what it will make of it (%s)" % _confirm_text(main))
	_confirm_button(main, "Cancel").pressed.emit()
	_check(sword.rarity == ItemRarity.Rarity.RARE and main.inventory.orb_count("Orb of Transmutation") == 3,
			"Cancel keeps the piece and the orb")
	craft.call(sword)
	(main.bag_page._confirm.find_child(BagPage.TICK_NAME, true, false) as Button).button_pressed = true
	_confirm_button(main, "Use").pressed.emit()
	_check(sword.rarity == ItemRarity.Rarity.UNCOMMON and main.inventory.orb_count("Orb of Transmutation") == 2,
			"Use takes it down and spends the orb")
	await process_frame
	sword.rarity = ItemRarity.Rarity.RARE
	craft.call(sword)
	_check(main.bag_page._confirm == null and sword.rarity == ItemRarity.Rarity.UNCOMMON
			and main.inventory.orb_count("Orb of Transmutation") == 1, "and with the tick it is never asked again")
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	# The tray is drawn again by that, and the card below is placed off its squares.
	for i in 2:
		await process_frame

	# The card says what it is looking at, in all three of the states it can find an orb in. Hovered
	# over the last square rather than the first, because that is the one the card cannot fit beside:
	# it is placed at the square's own x and is wider than the tray's right-hand end has room for, so
	# it hangs out over the character sheet standing against the bag panel.
	var last_orb: OrbSlot = main.bag_page._orb_tray.get_child(main.bag_page._orb_tray.get_child_count() - 1)
	main.bag_page._on_orb_hovered(last_orb.orb, last_orb)
	_check(main.bag_page._orb_card.visible, "hovering puts the card up")
	# Placed once by the hover and again deferred, so it is measured after the labels have laid out.
	for i in 2:
		await process_frame
	var card_right: float = (main.bag_page._orb_card.get_global_position().x
			+ main.bag_page._orb_card.size.x * main.ui_scale)
	# Two checks that only mean anything together: the card really does reach across into the sheet's
	# column, and it is the later child of the layer, which is the whole of what decides which of the
	# two the player sees where they meet. Compared across rather than as whole rectangles, because
	# whether they also meet up and down is a question about the height of the window.
	_check(card_right > _panel_right(main.bag_page._panel, main.ui_scale),
			"the card for the last orb reaches past the bag panel")
	_check(card_right > main.bag_page._worn_panel.get_global_position().x,
			"and into the character sheet's column")
	_check(main.bag_page._orb_card.get_index() > main.bag_page._worn_panel.get_index(),
			"so it is drawn after the sheet, which cannot then cover it")
	main.bag_page._orb_card.hide()
	_check(not main.bag_page._orb_card.visible, "and leaving takes it down")

	# Everything crafted goes through the save unchanged, which is the whole point of a piece being
	# frozen: what came back is what was put in, orbs and all.
	var before := sword.to_dict()
	main.inventory.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(back.orb_count("Orb of Transmutation") == 1, "the unspent orb survived the save")
	_check(back.orb_count("Orb of Divinity") == 0, "the spent one did not come back")
	_check(back.items.size() == 1, "the sword came back")
	_check(back.items[0].to_dict() == before, "the crafted sword round-trips exactly")

	# From the grid: the orb picked up with nothing open, and the piece pressed where it lies. The sword
	# broken first, so the grid holds a square the orb can do nothing to.
	var plain := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 4)
	main.inventory.add(plain)
	sword.broken = true
	main.bag_page._select_item(-1)
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	await process_frame
	_check(main.bag_page._armed == "Orb of Transmutation", "an orb pressed with nothing open is held")
	_check(main.inventory.orb_count("Orb of Transmutation") == 1, "and not spent by being picked up")
	var squares := _bag_squares(main)
	var plain_square: Control = squares.filter(func(s: ItemSlot) -> bool: return s.item == plain)[0]
	var sword_square: Control = squares.filter(func(s: ItemSlot) -> bool: return s.item == sword)[0]
	_check(sword_square.modulate == OrbSlot.DIM and plain_square.modulate == Color.WHITE,
			"the square it can do nothing to is grey and the other is not")
	_check(main._item_card.lights(plain_square) and not main._item_card.lights(sword_square),
			"and only the one it would go into lights the card")
	# A press on the grey one costs nothing and opens nothing; the orb is still held.
	main.bag_page._on_clicked(_square_spot(sword_square))
	_check(main.inventory.orb_count("Orb of Transmutation") == 1 and main.bag_page._selected == -1
			and main.bag_page._armed != "", "a refused piece spends nothing and stays shut")
	plain_square = _bag_squares(main).filter(func(s: ItemSlot) -> bool: return s.item == plain)[0]
	main.bag_page._on_clicked(_square_spot(plain_square))
	await process_frame
	_check(plain.rarity == ItemRarity.Rarity.UNCOMMON, "the piece pressed next came up uncommon")
	_check(main.inventory.orb_count("Orb of Transmutation") == 0, "the orb was spent")
	_check(main.bag_page._selected == -1 and not main.bag_page._actions.visible, "without the piece being opened")
	# The last light was Divinity's; this one is the Transmutation's.
	_check(_card_lit(main) == OrbTable.ORBS["Orb of Transmutation"].glow, "and the card lit up for it")
	_check(main.bag_page._armed == "", "the last of an orb puts it down")
	# Opening a piece puts a held orb down too: an open piece and an orb in hand never stand together.
	main.inventory.add_orb("Orb of Divinity", 2)
	main.bag_page._on_orb_pressed("Orb of Divinity")
	main.bag_page._on_orb_pressed("Orb of Divinity")
	_check(main.bag_page._armed == "", "the same orb again puts it down")
	main.bag_page._on_orb_pressed("Orb of Divinity")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	main.bag_page._input(right)
	_check(main.bag_page._armed == "" and main.inventory.orb_count("Orb of Divinity") == 2,
			"a right click puts it down too, unspent")
	# So does a left press on anything but a piece or the tray, which leave it in hand.
	main.bag_page._on_orb_pressed("Orb of Divinity")
	var left := InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	left.pressed = true
	for spot: Vector2 in [_bag_squares(main)[0].get_global_rect().get_center(),
			main.bag_page._orb_tray.get_child(0).get_global_rect().get_center()]:
		left.position = spot
		main.bag_page._input(left)
	_check(main.bag_page._armed == "Orb of Divinity", "a press on a piece or the tray keeps the orb in hand")
	left.position = Vector2(1, 1)
	main.bag_page._input(left)
	_check(main.bag_page._armed == "", "a left press anywhere else puts it down")
	left.pressed = false
	main.bag_page._input(left)
	await process_frame
	_check(not main.bag_page._put_down, "and the bag is redrawn once the press is released")
	main.bag_page._on_orb_pressed("Orb of Divinity")
	main.bag_page._select_item(0)
	_check(main.bag_page._armed == "", "and so does opening a piece")

	main.queue_free()
	await process_frame
	_clear_save()
	return true
## Under a finger whatever a held orb or rune is pressed on is selected by the first tap and takes it on
## the next (`Cursors.applies`): a piece keeps the orb unspent, and a tile puts its panel up over the bag.
func _test_a_finger_selects_first() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 4)
	main.inventory.add(sword)
	main.inventory.add_orb("Orb of Transmutation", 2)
	main.inventory.add_rune(RuneTable.UNREST)
	main._on_bag_pressed()
	for i in 2:
		await process_frame
	var bag: BagPage = main.bag_page
	var tap := func() -> void:
		Cursors.taps += 1
		var square: ItemSlot = _bag_squares(main).filter(func(s: ItemSlot) -> bool: return s.item == sword)[0]
		bag._on_clicked(_square_spot(square))

	Cursors.touched = true
	bag._on_orb_pressed("Orb of Transmutation")
	tap.call()
	_check(sword.rarity == ItemRarity.Rarity.COMMON and main.inventory.orb_count("Orb of Transmutation") == 2
			and bag._armed == "Orb of Transmutation", "a finger's first tap on a piece spends no orb")
	tap.call()
	_check(sword.rarity == ItemRarity.Rarity.UNCOMMON and main.inventory.orb_count("Orb of Transmutation") == 1,
			"the next tap on it spends it")

	var ground: Vector2i = main.view.best_farm()
	bag._on_orb_pressed(RuneTable.UNREST)
	Cursors.taps += 1
	main._on_cell_aimed(ground)
	_check(main.tile_panel.panel.visible and bag.visible and main.map.selected_cell == ground
			and bag._armed == RuneTable.UNREST and main.inventory.rune_count(RuneTable.UNREST) == 1,
			"a finger's first tap on a tile puts its panel up over the bag, the rune still in hand")
	_check(main.tile_panel.panel.get_index() > bag.get_index(), "in front of the bag, which is drawn after it otherwise")
	Cursors.taps += 1
	main._on_cell_aimed(ground)
	_check(main.inventory.rune_count(RuneTable.UNREST) == 0 and main.inventory.has_runes(main.view.origin + ground),
			"and the next tap there spends it")
	Cursors.touched = false
	main.queue_free()
	return true


## A first find and a first level each put up one pop-up, once, and bring on the corner button they
## are about, pulsing until it is pressed.
func _test_tips() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	await process_frame
	_check(not main._bag_button.visible and not main._skills_button.visible, "no corner buttons at first")
	main._check_tips()
	_check(main._tip_panel == null and main._tip_queue.is_empty(), "and nothing to say")
	main.bag_page.refresh_orbs()
	_check(not main.bag_page._orb_tray.visible, "no orb tray before the first orb")
	main.inventory.add_orb("Orb of Chaos")
	main.bag_page.refresh_orbs()
	_check(main.bag_page._orb_tray.visible, "and one once an orb is held")
	main.inventory.orbs.clear()
	main.bag_page.refresh_orbs()
	_check(not main.bag_page._orb_tray.visible, "gone again if it was never seen and none is held")
	# The runes stand over the orbs once one is found, and the chevron on the rule folds both away.
	var bag: BagPage = main.bag_page
	_check(not bag._rune_tray.visible and not bag._fold_button.visible, "no runes before the first")
	main.inventory.add_rune(RuneTable.UNREST)
	bag.refresh_orbs()
	_check(bag._rune_tray.visible and bag._rune_tray.get_child_count() == RuneTable.names().size()
			and bag._fold_button.visible, "the first rune brings the runes' row and the chevron")
	bag._fold_button.pressed.emit()
	_check(not bag._rune_tray.visible and bag._fold_button.visible, "the chevron folds them away")
	bag._fold_button.pressed.emit()
	_check(bag._rune_tray.visible, "and brings them back")
	# Picked up in the bag and pressed on a tile: the map is aimed at while one is held.
	var ground: Vector2i = main.view.best_farm()
	bag._on_orb_pressed(RuneTable.UNREST)
	_check(ground != HexMap.NO_CELL and main.map.aim_radius == 0, "a rune in hand aims the map")
	main._on_cell_aimed(ground)
	_check(main.inventory.rune_count(RuneTable.UNREST) == 0 and main.inventory.has_runes(main.view.origin + ground)
			and main.map.aim_radius == -1, "it is spent on the tile pressed, and the last one puts the aim away")
	bag.refresh_orbs()
	_check(bag._rune_tray.visible, "the row stays once a rune has been found")

	main.inventory.add(_piece(ItemRarity.Rarity.COMMON, 1))
	main.inventory.level = 2
	main._check_tips()
	_check(main._tip_panel != null and main._tip_queue.size() == 1, "two tips: one up, one waiting")
	_check(main._bag_button.visible and main._skills_button.visible, "both buttons come on")
	_check(main._flashes.has("opened_bag") and main._flashes.has("skill_point"), "both pulsing")
	_check(Inventory.load_from(TEST_PATH).tips.has("level_up"), "and the tips are saved")
	main._on_tip_closed()
	_check(main._tip_panel != null and main._tip_queue.is_empty(), "closing one shows the next")
	main._on_tip_closed()
	main._check_tips()
	_check(main._tip_panel == null, "and none comes twice")

	# The chest's red pip is for a first of its kind alone, until the bag is next up.
	var pip: CanvasItem = main._bag_button.get_node(^"New")
	_check(pip.visible, "a first find puts the red pip on the bag")
	main._on_bag_pressed()
	_check(not pip.visible, "and the bag opened puts it out")
	main._on_bag_pressed()
	main.inventory.add(_piece(ItemRarity.Rarity.COMMON, 1))
	main._mark_new()
	_check(not main.bag_page.visible and not pip.visible, "a second find is no first: no pip")
	main.inventory.add_orb("Orb of Chaos")
	main._check_tips()
	main._on_tip_closed()
	_check(pip.visible, "the first orb puts it back")
	main._on_bag_pressed()
	main._on_bag_pressed()
	main.inventory.add(_node("Strength Node", "added_damage"))
	main._check_tips()
	_check("first_stone" in main.inventory.tips and main._tip_panel != null and pip.visible,
			"and so does the first skill node, with a word from the hero")
	main._on_tip_closed()
	main._on_bag_pressed()
	_check(not pip.visible and Inventory.load_from(TEST_PATH).tips.has(main.SEEN + "first_item"),
			"until the bag is up again, and what was looked at is saved")
	_check(not main._flashes.has("opened_bag") and main._bag_button.modulate == Color.WHITE,
			"pressing the bag stops its pulse")
	_check(main._flashes.has("skill_point"), "while the star keeps pulsing")
	main.inventory.level = 1
	main.skills_page.open()
	_check(not main._flashes.has("skill_point") and main._skills_button.modulate == Color.WHITE,
			"until no point is left to spend")

	# The web build's changelog: every version, newest first, packed into the export, and every one the
	# player has not seen shown once, together.
	var versions: Array = Changelog.versions()
	_check(versions.size() >= 3, "CHANGELOG.md names its versions (%d)" % versions.size())
	var rows: Array = []
	for version: Dictionary in versions:
		var sections: Array = version["sections"]
		_check(str(version["version"]).begins_with("v") and not str(version["date"]).is_empty()
				and not sections.is_empty() and sections.all(func(s: Array) -> bool: return not s[1].is_empty()),
				"%s has its date and what changed" % version["version"])
		for section: Array in sections:
			rows.append_array(section[1].filter(func(item: Variant) -> bool: return item is Array))
	_check(rows.size() > 2 and rows.all(func(cells: Array) -> bool:
			return cells.size() == 2 and not str(cells[0]).is_empty() and not str(cells[0]).begins_with("-")),
			"a table's rows are two cells each, its |---| row dropped (%d)" % rows.size())
	_check(FileAccess.get_file_as_string("res://export_presets.cfg").contains("CHANGELOG.md"),
			"and the web build packs it")
	var names: Array = versions.map(func(v: Dictionary) -> String: return v["version"])
	# The version headings the popup up holds, top to bottom.
	var shown := func() -> Array:
		var texts: Array = main._tip_panel.find_children("*", "Label", true, false).map(
				func(l: Label) -> String: return l.text)
		return texts.filter(func(text: String) -> bool: return text in names)
	Settings.changelog_seen = ""
	main._show_changelog()
	_check(main._tip_panel != null and shown.call().size() == versions.size()
			and Settings.changelog_seen == versions[0]["version"], "a player who has seen none sees every version")
	main._on_tip_closed()
	main._show_changelog()
	_check(main._tip_panel == null, "and never again until there is a newer one")
	Settings.changelog_seen = versions[2]["version"]
	main._show_changelog()
	_check(main._tip_panel != null and shown.call() == [versions[0]["version"], versions[1]["version"]],
			"one who saw an older one sees every version since, newest first")
	main._on_tip_closed()
	Settings.changelog_seen = ""
	main.queue_free()
	_clear_save()
	return true


## A tip's step (`SPOTLIGHTS`): once its words are read, everything but the next thing to press is shaded,
## a press there falls through, and the shade moves on with the step until it is taken.
func _test_first_steps() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	await process_frame
	var lit := func() -> Control:
		main._spotlight()
		return null if main._spot == null else main._spot.target
	var sword := _piece(ItemRarity.Rarity.COMMON, 1)
	main.inventory.add(sword)
	main.inventory.level = 2
	main._check_tips()
	_check(lit.call() == null, "nothing shaded while the hero is still talking")
	while main._tip_panel != null:
		main._on_tip_closed()
	_check(lit.call() == main._bag_button, "the first find leaves only the bag lit")
	var spot: Spotlight = main._spot
	_check(not spot._has_point(main._bag_button.get_global_rect().get_center())
			and spot._has_point(main.get_viewport().get_visible_rect().end - Vector2.ONE),
			"a press on the bag falls through, one anywhere else is eaten")
	main._on_bag_pressed()
	_check(lit.call() == main.bag_page.square_of(sword), "then the piece")
	main.bag_page._select_item(main.inventory.items.find(sword))
	# The buttons' card is placed deferred (`BagPage._place_actions`).
	await process_frame
	var equip: Button = main.bag_page.action("Equip")
	_check(equip != null and lit.call() == equip, "then its Equip")
	equip.pressed.emit()
	_check(lit.call() == main._skills_button and "step_equip" not in main.inventory.tips
			and main._spot == spot, "worn, the shade moves on to the level's point")
	main._on_skills_pressed()
	_check(lit.call() == main.skills_page.square(""), "then the tree's root")
	main.skills_page._on_stone_pressed("")
	_check(lit.call() == null and "step_point" not in main.inventory.tips, "and the point spent, the shade goes")

	main._on_skills_pressed()
	main.inventory.add_orb(OrbTable.FIRST_ORB)
	main._check_tips()
	main._on_tip_closed()
	_check(lit.call() == main._bag_button, "the first orb: the bag")
	main._on_bag_pressed()
	_check(lit.call() == main.bag_page.tray_square(OrbTable.FIRST_ORB), "then the orb")
	main.bag_page._on_orb_pressed(OrbTable.FIRST_ORB)
	_check(lit.call() == main.bag_page.square_of(sword) and sword in main.inventory.equipment.worn.values(),
			"then the piece worn")
	main.bag_page._craft(OrbTable.FIRST_ORB, sword)
	_check(lit.call() == null and Inventory.load_from(TEST_PATH).tips.all(
			func(id: String) -> bool: return not id.begins_with("step_")), "and the orb spent, every step is saved taken")

	# The tip heard and no step owed, as in a save from before there were steps: nothing is forced.
	main.inventory.add_orb(OrbTable.FIRST_ORB)
	_check(lit.call() == null, "a tip heard with no step owed shades nothing")
	main.queue_free()
	_clear_save()
	return true


## The uniques' table: every row is a piece the game can actually make, find and draw.
func _test_unique_table() -> bool:
	var envs := PackedStringArray()
	for env: String in SheetMeta.env_adjacency():
		envs.append(env)
	for id: String in UniqueTable.UNIQUES:
		var row: Dictionary = UniqueTable.UNIQUES[id]
		_check(LootTable.ITEMS.has(row["base"]), "%s is a real piece (%s)" % [id, row["base"]])
		# A unique is a rule -- but for the Wayfarer's Torch, a starter the user asked for as a plain stat
		# stick, which says nothing because it does nothing but carry its three lines.
		var stick := id == "wayfarers_torch"
		_check(not str(row["name"]).is_empty() and UniqueTable.effect_text(id).is_empty() == stick,
				"%s has a name and says what it does" % id)
		# A unique an achievement unlocks has four ranks of numbers, and its sentence writes each of them.
		_check(UniqueTable.is_ranked(id) == Achievements.ACHIEVEMENTS.has(id), "%s has ranks only if it is earned" % id)
		for key: String in row.get("ranks", {}):
			_check(row["ranks"][key].size() == UniqueTable.PEAK, "%s's %s has a number a rank" % [id, key])
		for rank in range(1, UniqueTable.PEAK + 1):
			var said := UniqueTable.effect_text(id, rank)
			_check(not said.contains("{") and not said.contains("}"), "%s says every number at rank %d (%s)" % [id, rank, said])
		_check(not row.has("clause"), "%s has no second rule of a set" % id)
		_check(UniqueTable.effect_of(id).is_empty() == stick, "%s changes something" % id)
		_check(UniqueTable.icon(id) != null and UniqueTable.icon(id).get_size() == Vector2(32, 32),
				"%s has a 32 px picture" % id)
		var mods: Array = row["mods"]
		_check(mods.size() >= 1 and mods.size() <= UniqueTable.MOST_MODS,
				"%s carries a few modifiers, not an elite's (%d)" % [id, mods.size()])
		for mod_id: String in mods:
			_check(ModifierTable.MODS.has(mod_id), "%s names %s, which exists" % [id, mod_id])
			var entry: Dictionary = ModifierTable.MODS.get(mod_id, {})
			if entry.get("kind") == ModifierTable.Kind.PERCENT:
				_check(LootTable.has_stat(row["base"], entry["stat"]),
						"%s's %s has a %s to scale" % [id, mod_id, entry["stat"]])
		# A PERCENT and a GLOBAL on one stat write the same sentence, which on a hand-written piece
		# reads as a mistake: every line a unique shows has to be a different line.
		var increased := []
		for mod_id: String in mods:
			var entry: Dictionary = ModifierTable.MODS.get(mod_id, {})
			if entry.get("kind") in [ModifierTable.Kind.PERCENT, ModifierTable.Kind.GLOBAL]:
				_check(not entry["stat"] in increased, "%s says 'increased %s' once" % [id, entry["stat"]])
				increased.append(entry["stat"])
		# Only a home piece has a ground, and only its damage is tied to it: every unique drops anywhere.
		_check(row.has("home") == (row["effect"] == "home") and (not row.has("home") or row["home"] in envs),
				"%s names a ground only as a home piece, and a real one" % id)
		_check(not row.has("envs"), "%s is not tied to any other ground" % id)
		if row.has("home"):
			_check(UniqueTable.home_piece(row["home"]) == id, "%s is the one piece at home on %s" % [id, row["home"]])
	_check(UniqueTable.pool_for(Achievements.STARTERS) == Achievements.STARTERS,
			"the starters are there to hunt from the first")
	for mod_id: String in ModifierTable.UNIQUE_ONLY:
		var used := false
		for id: String in UniqueTable.UNIQUES:
			used = used or mod_id in UniqueTable.UNIQUES[id]["mods"]
		_check(used, "%s is held back for a unique that carries it" % mod_id)
	return true


## One unique: rolled, worn, saved, crafted and thrown away like the piece it is -- and unlike one.
## The frame a square wears: none for a common, its rarity's otherwise, and a unique's crest at the
## player's rank of it (a starter's has none), standing up over the square and never past its sides,
## on a socket cut back where the ring rounds the corner.
func _test_rarity_frames() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	_check(_piece(ItemRarity.Rarity.COMMON, 3).frame() == null, "a common wears no frame")
	for rarity: ItemRarity.Rarity in [ItemRarity.Rarity.UNCOMMON, ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
		var frame := _piece(rarity, 3).frame()
		_check(frame != null and frame.get_width() == ItemSlot.SIDE
				and frame.get_height() == ItemSlot.SIDE + ItemRarity.FRAME_HEAD,
				"%s: its frame is the square's width and stands up over it" % ItemRarity.NAMES[rarity])
	var ranked := Item.rolled_unique("metronome", rng, 1)
	var paths := []
	for rank in range(1, UniqueTable.PEAK + 1):
		UniqueTable.ranks = {"metronome": rank}
		paths.append(ranked.frame().resource_path)
		_check(ranked.frame() == ItemRarity.frame(ItemRarity.Rarity.UNIQUE, rank),
				"a unique at rank %d wears that rank's crest" % rank)
	UniqueTable.ranks = {}
	_check(paths.size() == UniqueTable.PEAK and paths.all(func(path: String) -> bool: return paths.count(path) == 1),
			"every rank its own (%s)" % [paths])
	_check(ranked.frame() == ItemRarity.frame(ItemRarity.Rarity.UNIQUE, 1), "and with no rank earned, rank I's")
	var starter := Item.rolled_unique(Achievements.STARTERS[0], rng, 1)
	_check(starter.frame() == ItemRarity.frame(ItemRarity.Rarity.UNIQUE, 0) and not starter.frame() in
			range(1, UniqueTable.PEAK + 1).map(
					func(rank: int) -> Texture2D: return ItemRarity.frame(ItemRarity.Rarity.UNIQUE, rank)),
			"a starter, which has no rank, wears none of theirs")
	var square := ItemSlot.make(ranked)
	var ring := square.get_node(ItemSlot.FRAME_NAME) as TextureRect
	_check(ring.position == Vector2(0, -ItemRarity.FRAME_HEAD),
			"the square's frame stands up over it, flush with its sides")
	_check((square.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left == ItemRarity.FRAME_CORNER,
			"on a socket cut back at the corners")
	var plain := ItemSlot.make(_piece(ItemRarity.Rarity.COMMON, 3))
	_check((plain.get_theme_stylebox("panel") as StyleBoxFlat).corner_radius_top_left == 0, "and a common's square")
	square.free()
	plain.free()
	return true
