extends "res://tests/harness.gd"
## Headless checks for the skill trees: their tables, how points are earned and spent, how skills
## combine with gear, the paid reset, the save, and what the Fortune stats do to a drop. Run from the
## project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_skills.gd

## Never Inventory.SAVE_PATH: these tests write and delete, and that is the player's own save.
const TEST_PATH := "user://test_skills.json"
const SHAPE_ROLLS := 6000


func _run() -> void:
	_check(_test_tables() == true, "table tests ran to the end")
	_check(_test_spending() == true, "spending tests ran to the end")
	_check(_test_stacking() == true, "stacking tests ran to the end")
	_check(_test_respec() == true, "reset tests ran to the end")
	_check(_test_save() == true, "save tests ran to the end")
	_check(_test_overranks() == true, "overrank tests ran to the end")
	_check(_test_hold() == true, "held press tests ran to the end")
	_check(_test_rarity() == true, "rarity tests ran to the end")
	_check(_test_gold_and_orbs() == true, "gold and orb find tests ran to the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_report("skill")


## Every tree is the sketch: one root, parents that exist and sit higher, strength paid for in depth.
func _test_tables() -> bool:
	_check(SkillTree.trees() == ["power", "fortune", "guard"], "three trees, power first")
	var seen := {}
	for tree: String in SkillTree.trees():
		var nodes := SkillTree.nodes_of(tree)
		_check(nodes.size() == 10, "%s has the sketch's ten skills" % tree)
		_check(SkillTree.capacity(tree) == 23, "%s holds 23 points" % tree)
		_check(ResourceLoader.exists(SkillTree.ICON_ROOT + str(SkillTree.TREES[tree]["locked"]) + ".png"),
				"%s has its locked mark" % tree)
		var roots := 0
		var cells := {}
		for id: String in nodes:
			_check(not seen.has(id), "%s is named once across every tree" % id)
			seen[id] = true
			var entry: Dictionary = nodes[id]
			var parents: Array = entry["parents"]
			if parents.is_empty():
				roots += 1
			var cell := Vector2i(int(entry["col"]), int(entry["row"]))
			_check(not cells.has(cell), "%s has its own place in the grid" % id)
			cells[cell] = true
			_check(cell.x >= 0 and cell.x < SkillTree.COLS and cell.y >= 0 and cell.y < SkillTree.ROWS,
					"%s is inside the grid" % id)
			for parent: String in parents:
				_check(nodes.has(parent), "%s leads from %s, in its own tree" % [id, parent])
				if nodes.has(parent):
					# Parents above is what rules out a cycle: every edge points down.
					_check(int(nodes[parent]["row"]) < int(entry["row"]), "%s sits under %s" % [id, parent])
					_check(int(nodes[parent]["max_rank"]) >= int(entry["max_rank"]),
							"%s holds no more than %s" % [id, parent])
			_check(ResourceLoader.exists(SkillTree.ICON_ROOT + id + ".png"), "%s has an icon" % id)
			_check(not SkillTree.describe(id).is_empty(), "%s says what it does" % id)
			for kind: String in ["flat", "percent"]:
				for stat: String in entry[kind]:
					_check(LootTable.STAT_LABELS.has(stat), "%s names %s, which has a label" % [id, stat])
		_check(roots == 1, "%s has one root" % tree)
	return true


func _test_spending() -> bool:
	var skills := Skills.new()
	_check(skills.points(1) == 0, "level 1 has no points")
	_check(skills.points(5) == 4, "a point a level past the first")
	_check(not skills.rank_up("sharpened_edge", 1), "nothing to spend at level 1")
	_check(skills.why_not("sharpened_edge", 1) == "No skill points left", "and it says so")

	_check(not skills.rank_up("keen_eye", 20), "a side skill is shut before its root")
	_check(skills.why_not("keen_eye", 20).begins_with("Needs a point in"), "and it says what it needs")
	_check(skills.rank_up("sharpened_edge", 20), "the root takes a point")
	_check(skills.why_not("keen_eye", 20) == "Needs 3 points in Power",
			"a row down wants three points in the tree (%s)" % skills.why_not("keen_eye", 20))
	skills.rank_up("sharpened_edge", 20)
	_check(not skills.rank_up("keen_eye", 20), "two is not enough")
	skills.rank_up("sharpened_edge", 20)
	_check(skills.rank_up("keen_eye", 20), "three opens the side skill")
	# Either parent is enough for the skill in the middle.
	_check(not SkillTree.is_open("quick_hands", {}), "the other side stays shut until its root is in")
	_check(not skills.rank_up("battle_rhythm", 20), "the middle wants six")
	skills.rank_up("sharpened_edge", 20)
	skills.rank_up("sharpened_edge", 20)
	_check(skills.rank_up("battle_rhythm", 20), "the middle opens off one side alone")
	_check(skills.points(20) == 12, "seven spent of nineteen")
	_check(skills.rank_of("sharpened_edge") == 5, "the root fills to five")
	_check(not skills.rank_up("sharpened_edge", 20), "and no further")
	_check(skills.why_not("sharpened_edge", 20) == SkillTree.FULL, "which it says")
	_check(skills.spent("power") == 7 and skills.spent("fortune") == 0, "spent is counted per tree")

	# The capstone row wants twelve points in its tree before it.
	for id in ["keen_eye", "keen_eye", "battle_rhythm", "might"]:
		skills.rank_up(id, 20)
	_check(skills.spent("power") == 11 and skills.rank_up("might", 20), "eleven, then a twelfth")
	skills.ranks.erase("might")
	skills.ranks["deadly_strikes"] = 1
	_check(not skills.rank_up("assassin", 20), "a capstone is shut at eleven")
	skills.rank_up("deadly_strikes", 20)
	_check(skills.rank_up("assassin", 20), "and open at twelve")
	_check(skills.effects() == ["execute"], "a learned capstone is an effect (%s)" % [skills.effects()])

	# A level-3 player has two points: the third is refused wherever it is aimed.
	var poor := Skills.new()
	_check(poor.rank_up("scavenger", 3) and poor.rank_up("scavenger", 3), "two points at level 3")
	_check(not poor.rank_up("scavenger", 3), "and not a third")
	_check(poor.points(3) == 0, "none left")
	return true


## Flat first, then the gear's globals, then the skills' percents, as a separate multiplier.
func _test_stacking() -> bool:
	var worn := Equipment.new()
	var blade := Item.new()
	blade.type = "Wooden Sword"
	blade.stats = Item.scaled_stats("Wooden Sword", 1)
	var ring := Item.new()
	ring.type = "Gold Ring"
	ring.stats = Item.scaled_stats("Gold Ring", 1)
	ring.mods = [{"id": "global_increased_damage", "value": 20}]
	worn.equip(Equipment.Socket.WEAPON, blade)
	worn.equip(Equipment.Socket.RING_LEFT, ring)
	var sword := float(blade.effective_stats()["damage"])

	_check(worn.totals() == worn.totals({}, {}), "no skills is the set alone")
	var flat_only := worn.totals({"damage": 3.0}, {})
	_check(is_equal_approx(flat_only["damage"], (sword + 3.0) * 1.2), "a skill's flat damage is scaled by the ring")
	var both := worn.totals({"damage": 3.0}, {"damage": 10.0})
	_check(is_equal_approx(both["damage"], (sword + 3.0) * 1.2 * 1.1),
			"and the skill's percent multiplies on top rather than adding to the ring's")
	_check(not is_equal_approx(both["damage"], (sword + 3.0) * 1.3), "it does not add to the ring's")

	# The tree's own sums.
	var skills := Skills.new()
	skills.ranks = {"sharpened_edge": 3, "keen_eye": 1, "battle_rhythm": 2, "titan": 1, "might": 1}
	# Read off the table rather than restated, so a retune moves both sides together.
	var per := func(id: String, kind: String) -> float:
		return float(SkillTree.node(id)[kind].get("damage", 0.0))
	var want_flat: float = per.call("sharpened_edge", "flat") * 3 + per.call("titan", "flat") \
			+ per.call("might", "flat")
	var want_percent: float = per.call("battle_rhythm", "percent") * 2 + per.call("titan", "percent")
	_check(want_flat > 0.0 and want_percent > 0.0, "the picked skills carry flat and percent damage")
	_check(is_equal_approx(skills.flat()["damage"], want_flat), "flat damage is ranks times per point")
	_check(is_equal_approx(skills.percent()["damage"], want_percent), "percents add inside the tree")

	# Through the inventory and into a fight.
	var inventory := Inventory.new()
	inventory.level = 10
	inventory.equipment = worn
	inventory.skills = skills
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	fight.arm(inventory.stats())
	var want := roundi((sword + want_flat) * 1.2 * (1.0 + want_percent / 100.0)) + Encounter.BARE_DAMAGE
	_check(fight.damage == want, "a fight hits for gear and skills together (%d, want %d)" % [fight.damage, want])
	return true


func _test_respec() -> bool:
	var inventory := Inventory.new()
	inventory.level = 10
	_check(not inventory.respec("power"), "nothing spent is nothing to reset")
	for i in 3:
		inventory.skills.rank_up("sharpened_edge", inventory.level)
	inventory.skills.rank_up("scavenger", inventory.level)
	var cost := inventory.respec_cost("power")
	_check(cost == SkillTree.respec_cost(10, 3) and cost > 0, "a reset costs gold (%d)" % cost)
	_check(SkillTree.respec_cost(20, 3) > cost, "and more as the player levels")
	inventory.gold = cost - 1
	_check(not inventory.respec("power"), "refused one gold short")
	_check(inventory.skills.spent("power") == 3 and inventory.gold == cost - 1, "and nothing moved")
	inventory.gold = cost + 7
	_check(inventory.respec("power"), "paid for")
	_check(inventory.gold == 7, "the price came out of the purse")
	_check(inventory.skills.spent("power") == 0, "every Power point is back")
	_check(inventory.skills.rank_of("scavenger") == 1, "and Fortune was not touched")
	_check(inventory.skills.points(10) == 8, "the refund is exact")
	return true


func _test_save() -> bool:
	var inventory := Inventory.new()
	inventory.level = 12
	inventory.skills.rank_up("scavenger", 12)
	inventory.skills.rank_up("scavenger", 12)
	inventory.skills.rank_up("scavenger", 12)
	inventory.skills.rank_up("appraiser", 12)
	inventory.skills.rank_up("appraiser", 12)
	_check(inventory.save(TEST_PATH), "saved")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.skills.ranks == inventory.skills.ranks, "the skills come back as they were")
	_check(back.skills.points(back.level) == 6, "with the same points free")

	# A version 8 save has no skills, and every level's point comes back to spend.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 8, "level": 6, "xp": 0, "items": []}')
	file.close()
	var old := Inventory.load_from(TEST_PATH)
	_check(old.skills.ranks.is_empty() and old.skills.points(old.level) == 5, "a version 8 save learns nothing")

	# Unknown names go, ranks over the most are cut down.
	var tidy := Skills.from_dict({"scavenger": 9, "retired_skill": 2, "appraiser": "lots"}, 30)
	_check(tidy.ranks == {"scavenger": 5}, "a drifted save is pruned (%s)" % [tidy.ranks])
	# More spent than the level earned, or a point nothing leads to: all of it comes back.
	_check(Skills.from_dict({"scavenger": 5}, 3).ranks.is_empty(), "overspending refunds everything")
	_check(Skills.from_dict({"collector": 1}, 30).ranks.is_empty(), "an orphaned point refunds everything")
	_check(Skills.from_dict({"sharpened_edge": 5, "keen_eye": 1, "battle_rhythm": 1, "might": 1,
			"titan": 1}, 30).ranks.is_empty(), "a capstone held on too few points refunds everything")
	_check(Skills.from_dict("nonsense", 30).ranks.is_empty(), "the wrong shape is nothing learned")
	return true


## Every tree full: a skill goes past its most, each rank past it dearer by its row's weight, and the
## numbers grow while the capstone's effect stays the one rule.
func _test_overranks() -> bool:
	var full := SkillTree.capacity("power") + SkillTree.capacity("fortune") + SkillTree.capacity("guard")
	var level := full + 1
	var skills := Skills.new()
	for tree: String in ["power", "fortune"]:
		_fill(skills, tree, level)
	_check(skills.why_not("titan", level) == SkillTree.FULL, "no rank past the most while a tree has room")
	_fill(skills, "guard", level)
	_check(skills.points(level) == 0, "every tree full takes every point at level %d" % level)
	_check(skills.why_not("titan", level) == "No skill points left", "then only the points are missing")

	_check(SkillTree.rank_cost("sharpened_edge", 0) == 1 and SkillTree.rank_cost("titan", 0) == 1,
			"a rank up to the most is a point")
	_check(SkillTree.rank_cost("sharpened_edge", 5) == 1 and SkillTree.rank_cost("sharpened_edge", 6) == 2,
			"past the root's most: 1, then 2")
	_check(SkillTree.rank_cost("titan", 1) == 6 and SkillTree.rank_cost("titan", 2) == 12,
			"past a capstone: 6, then 12")
	_check(SkillTree.points_for("titan", 3) == 1 + 6 + 12, "the costs add up (%d)" % SkillTree.points_for("titan", 3))
	for id: String in SkillTree.nodes_of("power"):
		var paid := 0
		for rank in 8:
			paid += SkillTree.rank_cost(id, rank)
		_check(SkillTree.points_for(id, 8) == paid, "%s: points_for is the sum of rank_cost" % id)

	var damage := float(skills.flat()["damage"])
	var boost := float(skills.percent()["damage"])
	_check(skills.why_not("titan", level + 5) == "Needs 6 skill points", "five points are not enough (%s)"
			% skills.why_not("titan", level + 5))
	_check(skills.rank_up("titan", level + 6) and skills.points(level + 6) == 0, "six buy it")
	_check(skills.rank_of("titan") == 2, "Titan holds two")
	_check(float(skills.flat()["damage"]) == damage + 2 and float(skills.percent()["damage"]) == boost + 15,
			"and adds its numbers again")
	_check(skills.effects().count("giant_slayer") == 1, "but its effect once")
	_check(skills.rank_up("sharpened_edge", level + 7) and skills.rank_up("sharpened_edge", level + 9),
			"the root past its most for 1, then 2")

	# A Reset gives every point back, the overranks' too, and the other trees keep theirs.
	var inventory := Inventory.new()
	inventory.level = level + 9
	inventory.skills = skills
	inventory.gold = 1e30
	_check(inventory.respec("fortune") and skills.points(inventory.level) == SkillTree.capacity("fortune"),
			"a reset of a plain tree gives its points back")
	_check(skills.rank_of("titan") == 2 and skills.why_not("titan", 1000) == SkillTree.FULL,
			"Titan keeps its rank, and no more go past until every tree is full again")

	# The save keeps a full tree's overranks and cuts a rank past the most anywhere else.
	_check(inventory.save(TEST_PATH), "saved")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.skills.ranks == skills.ranks, "overranks survive the save (%s)" % [back.skills.ranks])
	_check(Skills.from_dict({"scavenger": 9}, 99).ranks == {"scavenger": 5}, "a tree not full is cut down")
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 23, "level": inventory.level, "xp": 0, "items": [],
		"skills": inventory.skills.to_dict(), "skill_sunk": 69, "skill_transcends": 1}))
	file.close()
	var legacy := Inventory.load_from(TEST_PATH)
	_check(legacy.skills.points(legacy.level) == skills.points(inventory.level),
			"a version 23 save's sunk points are free again")
	return true


## A press held on a skill keeps learning it until the skill is full or the press is let go, and the
## points are saved when it ends.
func _test_hold() -> bool:
	var inventory := Inventory.new()
	inventory.level = 4
	var page := SkillsPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	page._on_skill_pressed("sharpened_edge")
	_check(inventory.skills.rank_of("sharpened_edge") == 1 and page._held == "sharpened_edge",
			"a press learns a point and holds")
	page._on_hold_tick()
	_check(inventory.skills.rank_of("sharpened_edge") == 2, "a tick learns another")
	_check(is_equal_approx(page._hold_timer.wait_time, SkillsPage.HOLD_FIRST)
			and page._hold_gap < SkillsPage.HOLD_FIRST, "slowly at first, and quicker each point")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	page._input(release)
	_check(page._held.is_empty() and page._hold_timer.is_stopped(), "a release lets go")
	_check(Inventory.load_from(TEST_PATH).skills.rank_of("sharpened_edge") == 2, "and saves the points")
	page._on_skill_pressed("sharpened_edge")
	page._on_hold_tick()
	_check(inventory.skills.rank_of("sharpened_edge") == 3 and page._held.is_empty(),
			"a refused point ends the hold on its own")
	page.free()
	return true


## Every skill of `tree` learned, row by row, which is an order the rules always allow.
func _fill(skills: Skills, tree: String, level: int) -> void:
	var nodes := SkillTree.nodes_of(tree)
	for row in SkillTree.ROWS:
		for id: String in nodes:
			if int(nodes[id]["row"]) == row:
				while skills.rank_up(id, level):
					pass


func _test_rarity() -> bool:
	# At nothing the table is drawn exactly as it always was, draw for draw.
	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = WORLD_SEED
	b.seed = WORLD_SEED
	var same := true
	for i in 500:
		var tier: EnemyRoster.Tier = [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS][i % 3]
		if ItemRarity.roll(tier, a) != ItemRarity.roll(tier, b, 0.0):
			same = false
	_check(same, "no rarity bonus changes nothing")

	for tier: EnemyRoster.Tier in ItemRarity.TIER_WEIGHTS:
		var lifted := ItemRarity.weights_for(tier, 50.0)
		_check(not lifted.has(ItemRarity.Rarity.UNIQUE), "a bonus never reaches uniques")
		var plain := ItemRarity.weights_for(tier, 0.0)
		var total_plain := 0.0
		var total_lifted := 0.0
		for step: ItemRarity.Rarity in plain:
			total_plain += int(plain[step])
			total_lifted += int(lifted[step])
		var common_share := int(lifted[ItemRarity.Rarity.COMMON]) / total_lifted
		var plain_share := int(plain[ItemRarity.Rarity.COMMON]) / total_plain
		_check(common_share < plain_share, "a bonus shrinks the common share")
		var elite_share := int(lifted[ItemRarity.Rarity.ELITE]) / total_lifted
		_check(elite_share > int(plain[ItemRarity.Rarity.ELITE]) / total_plain, "and grows the elite one")

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var plain_mean := 0.0
	var lifted_mean := 0.0
	for i in SHAPE_ROLLS:
		plain_mean += ItemRarity.roll(EnemyRoster.Tier.COMMON, rng)
		lifted_mean += ItemRarity.roll(EnemyRoster.Tier.COMMON, rng, 60.0)
	_check(lifted_mean > plain_mean * 1.1, "a rarity bonus lifts the average step (%.3f vs %.3f)"
			% [lifted_mean / SHAPE_ROLLS, plain_mean / SHAPE_ROLLS])
	return true


func _test_gold_and_orbs() -> bool:
	_check(OrbTable.chance_for("Skeleton Warrior", 50.0) > OrbTable.chance_for("Skeleton Warrior"),
			"orb find lifts the orb chance")
	_check(OrbTable.chance_for("Skeleton Warrior", 1e9) <= 1.0, "never past certainty")

	var cell := Vector2i(8, 0)
	var plain := Encounter.for_tile(cell, "grass")
	var rich := Encounter.for_tile(cell, "grass")
	rich.arm({"gold_find": 100.0, "item_rarity": 20.0, "orb_find": 10.0})
	_check(is_equal_approx(rich.gold_find, 100.0) and is_equal_approx(rich.item_rarity, 20.0)
			and is_equal_approx(rich.orb_find, 10.0), "a fight reads the Fortune stats")
	_play_out(plain)
	_play_out(rich)
	_check(plain.gold > 0 and rich.gold >= plain.gold * 2 - plain.enemies,
			"doubled gold find doubles the purse (%d vs %d)" % [rich.gold, plain.gold])
	return true


func _play_out(fight: Encounter) -> void:
	fight.start()
	for i in 200000:
		if fight.finished:
			return
		if not fight.hit():
			fight.advance(0.05)
