extends "res://tests/harness.gd"
## Headless checks for the skill tree: the starter tree, what a path is and where a stone may stand, how
## points are earned and spent, what the stones add up to and how that stacks with gear, the paid reset,
## placing stones on the black screen, the save, the capstones' effects, the page and its radial
## drawing, what the Fortune stats do to a drop, and how stones drop. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_skills.gd

## Never Inventory.SAVE_PATH: these tests write and delete, and that is the player's own save.
const TEST_PATH := "user://test_skills.json"
const SHAPE_ROLLS := 6000


func _run() -> void:
	_check(_test_starter() == true, "starter tests ran to the end")
	_check(_test_paths() == true, "path tests ran to the end")
	_check(_test_spending() == true, "spending tests ran to the end")
	_check(_test_stacking() == true, "stacking tests ran to the end")
	_check(_test_respec() == true, "reset tests ran to the end")
	_check(_test_placing() == true, "placing tests ran to the end")
	_check(_test_save() == true, "save tests ran to the end")
	_check(_test_effects() == true, "effect tests ran to the end")
	_check(await _test_page() == true, "page tests ran to the end")
	_check(_test_layout() == true, "layout tests ran to the end")
	_check(_test_rarity() == true, "rarity tests ran to the end")
	_check(_test_gold_and_orbs() == true, "gold and orb find tests ran to the end")
	_check(_test_stone_drops() == true, "stone drop tests ran to the end")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	_report("skill")


## A stone of `type` made by hand: `tier`, `connectors`, and `lines` as [id, value] pairs.
func _stone(type: String, tier: int, connectors := 0, lines := []) -> Item:
	var stone := Item.new()
	stone.type = type
	stone.rarity = ItemRarity.Rarity.RARE
	stone.stone_tier = tier
	stone.connectors = connectors
	stone.stats = Item.scaled_stats(type, 1)
	for line: Array in lines:
		stone.mods.append({"id": line[0], "value": line[1]})
	return stone


## Every hero starts with the root and, in its one slot, a dexterity stone: an uncommon leaf of tier 1.
func _test_starter() -> bool:
	var skills := Skills.new()
	_check(SkillTree.ROOT_CONNECTORS == 1 and skills.stones.keys() == ["0"],
			"one stone in the root's one slot (%s)" % [skills.stones.keys()])
	var want := {"0": ["Dexterity Node", "global_increased_attack_speed"]}
	for path: String in want:
		var stone: Item = skills.stones[path]
		_check(stone.type == want[path][0] and stone.stone_tier == 1 and stone.connectors == 0
				and stone.rarity == ItemRarity.Rarity.UNCOMMON, "%s is a tier-1 uncommon leaf" % stone.type)
		_check(stone.mods.size() == 1 and stone.mods[0]["id"] == want[path][1] and stone.mods[0]["value"] == 1,
				"%s carries its one line (%s)" % [stone.type, stone.mod_lines()])
		_check(float(stone.base_stats()[SkillTree.base_of(stone)]) == 5.0, "and 5 of its attribute")
	_check(skills.attributes() == {"strength": 0.0, "dexterity": 0.0, "intelligence": 0.0},
			"with no point spent the tree adds no attribute")
	_check(skills.flat().is_empty() and skills.percent().is_empty(), "and adds nothing else")
	_check(Skills.new().stones["0"] != skills.stones["0"], "every tree's stones are its own")
	return true


## A slot is a path, and a stone stands only where a slot is, no deeper than its tier.
func _test_paths() -> bool:
	_check(SkillTree.depth_of("") == 0 and SkillTree.depth_of("2") == 1 and SkillTree.depth_of("2.1.0") == 3,
			"depth is the number of steps")
	_check(SkillTree.parent_of("2.1.0") == "2.1" and SkillTree.parent_of("2") == "", "the parent is a step up")
	_check(SkillTree.index_of("2.1") == 1 and SkillTree.child_of("2", 1) == "2.1" and SkillTree.child_of("", 0) == "0",
			"and a child a connector down")
	_check(SkillTree.branch_of("2.1.0") == "2" and SkillTree.branch_of("1") == "1", "the branch is the first step")

	var stones := {"0": _stone("Strength Node", 1, 2)}
	_check(SkillTree.exists("0", stones) and SkillTree.exists("0.1", stones), "the root's and a stone's slots exist")
	_check(not SkillTree.exists("1", stones), "but the root has one")
	_check(not SkillTree.exists("0.2", stones), "and none past a stone's connectors")
	_check(not SkillTree.exists("0.0.0", stones), "nor under an empty slot")
	for bad: String in ["", "3", "1.", "a", "1..0", "-1"]:
		_check(not SkillTree.exists(bad, stones), "%s is no slot" % bad)
	var deep := _stone("Dexterity Node", 2)
	_check(SkillTree.can_place(deep, "0", stones) and SkillTree.can_place(deep, "0.0", stones),
			"a tier-2 stone stands at depth 1 or 2")
	stones["0.0"] = _stone("Strength Node", 2, 1)
	_check(not SkillTree.can_place(deep, "0.0.0", stones), "and never at 3")
	_check(SkillTree.can_place(_stone("Dexterity Node", 3), "0.0.0", stones), "where a tier-3 one may")
	_check(not SkillTree.can_place(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, RandomNumberGenerator.new()),
			"0", stones), "a sword is no stone")
	return true


## A level is a point, a point is a rank, a stone opens once the stone above it holds one, and a stone
## holds one rank and its "+N ranks" more. Its lines count once a rank.
func _test_spending() -> bool:
	var skills := Skills.new()
	skills.stones["0"] = _stone("Strength Node", 1, 1, [["added_damage", 2], ["added_stone_ranks", 1]])
	skills.stones["0.0"] = _stone("Strength Node", 2, 0, [["global_increased_damage", 10]])
	_check(Skills.earned(1) == 0 and Skills.earned(5) == 4, "a point a level past the first")
	_check(SkillTree.most_ranks(skills.stones["0"]) == 2 and SkillTree.most_ranks(skills.stones["0.0"]) == 1,
			"a stone takes one rank and its ranks line more")
	_check(not skills.rank_up("0.0", 5) and skills.why_not("0.0", 5) == "Needs a point in the node before it",
			"a stone opens once the one above it holds a point")
	_check(skills.rank_up("0", 5) and skills.rank_up("0", 5), "two into a stone of two ranks")
	_check(skills.why_not("0", 5) == SkillTree.FULL and not skills.rank_up("0", 5), "and no third")
	_check(skills.rank_up("0.0", 5), "and now the one under it opens")
	_check(skills.points(5) == 1 and skills.spent() == 3, "three of four spent")
	_check(skills.why_not("", 2) == "No skill points left", "a level with nothing left refuses")
	_check(skills.why_not("0.0.0", 5) == "No node here", "where no stone stands takes nothing")

	# Read off the stones' own lines, never restated, so a retune moves both sides together.
	var flat: Dictionary = skills.flat()
	_check(is_equal_approx(flat["damage"], 2.0 * 2), "a flat line counts once a rank (%s)" % flat)
	_check(not flat.has(SkillTree.RANKS_STAT) and not flat.has("strength"),
			"never the stone's ranks, and the attributes are counted apart")
	_check(is_equal_approx(skills.percent()["damage"], 10.0), "a global line goes to the percents")
	_check(is_equal_approx(skills.attributes()["strength"], 5.0 * 3),
			"strength is every rank's of the stones' (%s)" % skills.attributes())
	# The Abacus at IV and a helmet's line: ranks more, on every stone holding a point and on one base's.
	_check(is_equal_approx(skills.flat(1)["damage"], 2.0 * 3), "a rank more on every stone holding one")
	_check(is_equal_approx(skills.flat(0, {"strength": 2})["damage"], 2.0 * 4), "two more on the strength stones")
	_check(skills.flat(0, {"dexterity": 2})["damage"] == flat["damage"], "and none from another base's")
	skills.ranks.erase("0.0")
	_check(not skills.percent().has("damage"), "a stone with no point adds nothing, however many it is lent")

	# The root (the user's, 2026-10-09): no most, so every point the level has earned, each a point of
	# damage and a percent more of it, and no attribute; the stones under it open without it.
	var rooted := Skills.new()
	_check(rooted.flat().is_empty() and rooted.percent().is_empty(), "a root with no point adds nothing")
	for i in Skills.earned(6):
		rooted.rank_up("", 6)
	_check(rooted.rank_of("") == Skills.earned(6) and rooted.why_not("", 6) == "No skill points left",
			"the root takes every point there is, and is never full (%d)" % rooted.rank_of(""))
	_check(rooted.why_not("", 7).is_empty() and rooted.rank_up("", 7), "a level more is a point more in it")
	_check(is_equal_approx(rooted.flat()["damage"], SkillTree.ROOT_DAMAGE * 6)
			and is_equal_approx(rooted.percent()["damage"], SkillTree.ROOT_PERCENT * 6),
			"each point a point of damage and a percent more (%s, %s)" % [rooted.flat(), rooted.percent()])
	_check(rooted.attributes().values().max() == 0.0 and rooted.effects().is_empty(), "and nothing else")
	_check(rooted.why_not("0", 8).is_empty(), "the stone under it opens without a point in it")
	var saved := Skills.from_dict(rooted.tree_dict(), rooted.ranks, 7)
	_check(saved.rank_of("") == 6, "its points are saved (%d)" % saved.rank_of(""))
	_check(Skills.from_dict(rooted.tree_dict(), rooted.ranks, 5).ranks.is_empty(),
			"and handed back with the rest when the level cannot pay for them")
	return true


## Flat first, then the gear's globals, then the tree's percents, as a separate multiplier.
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

	# A stone of two ranks through the inventory and into a fight, its strength with it.
	var inventory := Inventory.new()
	inventory.level = 10
	inventory.equipment = worn
	inventory.skills.stones["0"] = _stone("Strength Node", 1, 0,
			[["added_damage", 3], ["global_increased_damage", 10], ["added_stone_ranks", 1]])
	inventory.skills.ranks = {"0": 2}
	var strength := float(inventory.attributes()["strength"])
	_check(is_equal_approx(strength, 5.0 * 2), "the tree's strength reaches the hero (%s)" % strength)
	var fight := Encounter.for_tile(Vector2i(1, 0), "grass")
	fight.arm(inventory.stats())
	var want := roundi((sword + 6.0) * 1.2 * 1.2 * (1.0 + Inventory.attribute_bonus(strength) / 100.0)) \
			+ Encounter.BARE_DAMAGE
	_check(fight.damage == want, "a fight hits for gear and stones together (%d, want %d)" % [fight.damage, want])
	return true


## A reset takes every point back, for gold the level grows; refused when the purse is short.
func _test_respec() -> bool:
	var inventory := Inventory.new()
	inventory.level = 6
	_check(inventory.respec_cost() == 0.0 and not inventory.respec(), "nothing spent is nothing to reset")
	for path: String in ["0", "", ""]:
		inventory.rank_up_skill(path)
	var cost := inventory.respec_cost()
	_check(cost == SkillTree.respec_cost(6, 3) and cost > 0.0, "three points cost what the table says")
	inventory.gold = cost - 1.0
	_check(not inventory.respec() and inventory.skills.spent() == 3, "a short purse resets nothing")
	inventory.gold = cost
	_check(inventory.respec() and inventory.skills.spent() == 0 and inventory.gold == 0.0, "a full one takes it all back")
	_check(SkillTree.respec_cost(20, 3) > SkillTree.respec_cost(6, 3), "and costs more the higher the level")
	return true


## On the black screen: a stone out of the bag into a slot it fits, what stood there and every stone under
## a connector the new one lacks back into the bag, whole; and the new world keeps the tree and none of
## the bag's stones or the points.
func _test_placing() -> bool:
	var skills := Skills.new()
	skills.stones["0"] = _stone("Strength Node", 1, 3)
	skills.stones["0.0"] = _stone("Strength Node", 2, 1)
	skills.stones["0.0.0"] = _stone("Intelligence Node", 3)
	skills.stones["0.2"] = _stone("Dexterity Node", 2)
	skills.ranks = {"0": 1, "0.0": 1, "0.2": 1}
	var leaf := _stone("Dexterity Node", 1)
	var refused := skills.place(leaf, "0.0")
	_check(refused == [leaf] and skills.stones["0.0"] != leaf, "a tier-1 stone is handed back from depth 2")
	var narrow := _stone("Intelligence Node", 1, 1)
	var old_one: Item = skills.stones["0"]
	var past: Item = skills.stones["0.2"]
	var out := skills.place(narrow, "0")
	_check(skills.stones["0"] == narrow and not skills.ranks.has("0"), "the new stone stands there, no point in it")
	_check(out == [old_one, past], "out comes the old one and the stone past the one connector (%d)" % out.size())
	_check(skills.stones.has("0.0") and skills.stones.has("0.0.0"), "what hangs off the kept connector stays, whole")
	_check(not skills.stones.has("0.2") and not skills.ranks.has("0.2"), "and the rest goes, its point with it")
	var bare := skills.place(_stone("Dexterity Node", 1), "0")
	_check(bare.size() == 3 and not skills.stones.has("0.0.0"), "a leaf takes a whole subtree out under it")

	var inventory := Inventory.new()
	inventory.level = 4
	var found := _stone("Strength Node", 1, 2)
	var spare := _stone("Intelligence Node", 1)
	inventory.add(found)
	inventory.add(spare)
	inventory.rank_up_skill("0")
	var was: Item = inventory.skills.stones["0"]
	_check(not inventory.place_stone(_stone("Dexterity Node", 1), "0"), "only a stone from the bag")
	_check(inventory.place_stone(found, "0") and inventory.items.has(was) and not inventory.items.has(found),
			"the bag's stone goes in and the old one comes out to the bag")
	var next := inventory.transcended()
	_check(next.skills.stones["0"].type == "Strength Node" and next.skills.stones["0"].connectors == 2,
			"the new world keeps the tree")
	_check(next.skills.stones["0"] != found, "as a copy")
	_check(next.skills.ranks.is_empty() and not next.items.has(spare) and next.items.is_empty(),
			"but not its points, nor a stone left in the bag")
	return true


## The tree and its points go into the save and come back; a save from before the tree starts from the
## starter with every point free, and points that overspend or that nothing leads to are handed back.
func _test_save() -> bool:
	var inventory := Inventory.new()
	inventory.level = 5
	inventory.skills.stones["0"] = _stone("Strength Node", 2, 1, [["added_stone_ranks", 2]])
	inventory.skills.stones["0.0"] = _stone("Intelligence Node", 2)
	inventory.skills.ranks = {"0": 3, "0.0": 1}
	_check(inventory.save(TEST_PATH), "saved")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.skills.tree_dict() == inventory.skills.tree_dict(), "the tree comes back stone for stone")
	_check(back.skills.ranks == {"0": 3, "0.0": 1}, "and its points (%s)" % back.skills.ranks)

	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	data.erase("skill_tree")
	data.erase("skill_ranks")
	data["skills"] = {"sharpened_edge": 3}
	data["skill_bursts"] = 1
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	var old := Inventory.load_from(TEST_PATH)
	_check(old.skills.tree_dict() == Skills.new().tree_dict() and old.skills.points(5) == 4,
			"a save from before the tree is the starter, every point free")

	var loose := Skills.from_dict(inventory.skills.tree_dict(), {"0.0": 1}, 5)
	_check(loose.ranks.is_empty(), "a point nothing leads to hands every point back")
	var greedy := Skills.from_dict(inventory.skills.tree_dict(), {"0": 3, "0.0": 1}, 3)
	_check(greedy.ranks.is_empty(), "and so does more than the level earned")
	var capped := Skills.from_dict(inventory.skills.tree_dict(), {"0": 9}, 20)
	_check(capped.ranks == {"0": 3}, "a rank past a stone's most is cut to it")
	var tree := inventory.skills.tree_dict()
	tree.erase("0")
	_check(not Skills.from_dict(tree, {}, 5).stones.has("0.0"), "a stone whose parent is gone goes with it")
	return true


## A capstone holding a point is its effect, once however many are placed; one with none is nothing.
func _test_effects() -> bool:
	var rng := RandomNumberGenerator.new()
	var inventory := Inventory.new()
	inventory.level = 10
	inventory.skills.stones["0"] = _stone("Strength Node", 1, 2)
	inventory.skills.stones["0.0"] = Item.rolled_capstone("titan", 2, rng)
	inventory.skills.stones["0.1"] = Item.rolled_capstone("titan", 2, rng)
	inventory.rank_up_skill("0")
	_check(not "giant_slayer" in inventory.effects(), "a capstone with no point does nothing")
	inventory.rank_up_skill("0.0")
	inventory.rank_up_skill("0.1")
	_check(inventory.effects().count("giant_slayer") == 1, "two give their effect once (%s)" % [inventory.effects()])
	return true


## The page draws the tree, a press on a stone puts a point in it, and the Reset takes them back.
func _test_page() -> bool:
	var inventory := Inventory.new()
	inventory.level = 3
	var page := SkillsPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame
	var view: SkillTreeView = page._view
	_check(view.squares.keys().size() == 2 and view.squares.has(""), "the root and its one stone")
	_check(view._rings.has("") and view._rings.has("0") and view.squares["0"].modulate == SkillTreeView.UNLEARNED,
			"with points to spend the root and the stone are ringed, the stone faint while it holds none")
	_check(view._marks.get_child_count() == 0, "a stone of one rank and a root holding nothing carry no number")
	view.slot_pressed.emit("0")
	_check(inventory.skills.rank_of("0") == 1, "a press is a point")
	_check(page._points.text == "1 skill point", page._points.text)
	inventory.gold = 1.0e9
	page.open()
	page._reset.pressed.emit()
	_check(inventory.skills.spent() == 0, "and the Reset takes it back")
	_check(page._scroll.custom_minimum_size.x >= BagPage.WIDTH, "a small tree's page is the bag's width at the least")

	# Zoom: whole window pixels a tree pixel, from one to `ZOOM_MOST` times the scale, by the buttons and
	# the wheel, and kept when the page draws the tree again.
	var pixels := func() -> int: return roundi(view._canvas.scale.x * 1.0)
	_check(pixels.call() == 1, "the starter fits at the page's own size")
	var buttons := page._panel.find_children("*", "Button", true, false)
	var across := page._scroll.custom_minimum_size.x
	(buttons.filter(func(b: Button) -> bool: return b.tooltip_text == "Zoom in")[0] as Button).pressed.emit()
	_check(pixels.call() == 2 and view.zoom == 2, "+ zooms in a whole step")
	_check(page._scroll.custom_minimum_size.x == across, "and the page keeps its width, the tree scrolling in it")
	view.zoom_by(1)
	_check(pixels.call() == SkillTreeView.ZOOM_MOST, "and no closer than the most")
	page.open()
	_check(pixels.call() == 2, "a redraw keeps it")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	view._gui_input(wheel)
	view._gui_input(wheel)
	_check(pixels.call() == 1, "the wheel zooms out, and no further than one")

	# A press counts as it lets go, and a drag presses nothing.
	var stone: Control = view.squares["0"]
	var on := view._canvas.position + (stone.position + stone.get_combined_minimum_size() / 2.0) * view._canvas.scale
	var pressed: Array = []
	view.slot_pressed.connect(func(path: String) -> void: pressed.append(path))
	var left := func(down: bool) -> InputEventMouseButton:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = on
		return event
	view._gui_input(left.call(true))
	_check(pressed.is_empty(), "nothing as a press goes down")
	view._gui_input(left.call(false))
	_check(pressed == ["0"], "and the stone as it lets go (%s)" % [pressed])
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(BagPage.DRAG_THRESHOLD * 3.0, 0.0)
	view._gui_input(left.call(true))
	view._gui_input(drag)
	view._gui_input(left.call(false))
	_check(pressed == ["0"], "a drag presses nothing (%s)" % [pressed])
	# The root takes a press on this page, and says what its points add up to under the cursor.
	var middle: Control = view.squares[""]
	var centre := view._canvas.position + (middle.position + middle.get_combined_minimum_size() / 2.0) * view._canvas.scale
	for down: bool in [true, false]:
		var event: InputEventMouseButton = left.call(down)
		event.position = centre
		view._gui_input(event)
	_check(pressed == ["0", ""], "a press on the root is the root's (%s)" % [pressed])
	_check("+%d Damage" % inventory.skills.rank_of("") in view._get_tooltip(centre),
			view._get_tooltip(centre))
	page.queue_free()
	await process_frame
	return true


## Round the root: its first branch straight down, the other two up either side; no two squares touching
## however the tree grows; and a tree too big for its room drawn a whole window pixel a pixel smaller.
func _test_layout() -> bool:
	var skills := Skills.new()
	var view := SkillTreeView.new()
	view.fill(skills)
	var at := func(path: String) -> Vector2:
		var square: Control = view.squares[path]
		return square.position + square.get_combined_minimum_size() / 2.0
	_check(at.call("0").y > at.call("").y and is_equal_approx(at.call("0").x, at.call("").x),
			"the root's one branch goes straight down")
	# Every slot under full stones of three connectors, three deep under the one branch.
	for path: String in ["0", "0.0", "0.1", "0.2", "0.0.0", "0.0.1", "0.0.2", "0.1.0", "0.1.1", "0.1.2",
			"0.2.0", "0.2.1", "0.2.2"]:
		skills.stones[path] = _stone("Strength Node", 3, 3)
	view.fill(skills)
	var below := view.squares.keys().all(func(path: String) -> bool:
		return path.is_empty() or at.call(path).y > at.call("").y)
	_check(below, "a lone branch keeps its third of the circle and hangs below the root, crossing nothing")
	# Each slot at its own size: the root's grey stone whole, the stones and the empty slots small.
	var boxes: Array = view.squares.values().map(func(square: Control) -> Rect2:
		return Rect2(square.position, square.get_combined_minimum_size()))
	var crowded := 0
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			if (boxes[i] as Rect2).intersects(boxes[j]):
				crowded += 1
	_check(boxes.size() == 1 + 1 + 3 + 9 + 27 and crowded == 0,
			"%d slots and none on another (%d)" % [boxes.size(), crowded])
	_check((view.squares[""] as Control).get_combined_minimum_size().x
			> (view.squares["0"] as Control).get_combined_minimum_size().x, "the root stands bigger than a stone")
	_check(view.squares["0"] is ItemSlot and (view.squares["0"] as ItemSlot).item == skills.stones["0"],
			"and a stone is still a square the card can write")
	var whole := view.custom_minimum_size
	var fitted := view.fit(whole / 2.0, 4.0)
	_check(fitted.x <= whole.x / 2.0 + 1.0 and is_equal_approx(view._canvas.scale.x * 4.0, roundf(view._canvas.scale.x * 4.0)),
			"too big, it shrinks a whole window pixel at a time (%s)" % view._canvas.scale)
	view.free()
	return true


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


## Skill nodes fall on a roll of their own (`SkillTree.roll`): a tier no deeper than the ground allows,
## lines lifted by it, now and then a capstone -- a unique-rarity leaf carrying its row's lines -- and
## none at all from a fight nobody told to drop them.
func _test_stone_drops() -> bool:
	# Each tier lasts a level longer than the one before: 1, 2-3, 4-6, 7-10, 11-15...
	var reach := []
	for level in range(1, 12):
		reach.append(SkillTree.deepest(level))
	_check(reach == [1, 2, 2, 3, 3, 3, 4, 4, 4, 4, 5] and SkillTree.deepest(100000) == SkillTree.MOST_TIER,
			"the ground sets the deepest tier (%s)" % [reach])
	var enemy: String = Encounter.for_tile(Vector2i(4, 2), "grass").lineup[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var level := 10
	var tiers := {}
	var capstones := 0
	var stones := 0
	for i in SHAPE_ROLLS:
		var stone := SkillTree.roll(enemy, rng, level, 1.0e6)
		if stone == null:
			continue
		stones += 1
		tiers[stone.stone_tier] = true
		_check(stone.is_stone() and stone.stone_tier >= 1 and stone.stone_tier <= SkillTree.deepest(level),
				"a stone's tier is one the ground allows (%d)" % stone.stone_tier)
		_check(stone.connectors >= 0 and stone.connectors <= SkillTree.MOST_CONNECTORS, "and its connectors 0 to 3")
		_check(stone.mod_level() == stone.level and stone.mods.all(func(mod: Dictionary) -> bool:
				return stone.tier_of(mod) <= stone.level), "its lines' tiers are its level's, never more")
		if stone.capstone.is_empty():
			_check(stone.type in SkillTree.BASES and stone.rarity != ItemRarity.Rarity.UNIQUE,
					"an ordinary stone is one of the three bases")
			continue
		capstones += 1
		_check(stone.rarity == ItemRarity.Rarity.UNIQUE and stone.connectors == 0
				and stone.mods.size() == (SkillTree.CAPSTONES[stone.capstone]["mods"] as Array).size(),
				"a capstone is a unique-rarity leaf with its row's lines")
	_check(tiers.size() == SkillTree.deepest(level), "every tier the ground allows turns up (%s)" % [tiers.keys()])
	_check(stones > 0 and stones < SHAPE_ROLLS, "a stone is a chance, not a certainty (%d)" % stones)
	_check(capstones > 0 and capstones * 4 < stones, "and a capstone a rare one (%d of %d)" % [capstones, stones])

	# A fight drops stones only once told to.
	for told: bool in [false, true]:
		var fight := Encounter.for_tile(Vector2i(4, 2), "grass")
		fight.arm({"damage": 1.0e9, "drop_rate": 1.0e6})
		fight.stone_drops = told
		fight.stone_rng.seed = WORLD_SEED
		var found := [0]
		fight.loot_dropped.connect(func(_index: int, item: Item) -> void:
			if item.is_stone():
				found[0] += 1)
		_play_out(fight)
		_check((found[0] > 0) == told, "a fight %s stones (%d)" % ["drops" if told else "never drops", found[0]])
	return true


func _play_out(fight: Encounter) -> void:
	fight.start()
	for i in 200000:
		if fight.finished:
			return
		if not fight.hit():
			fight.advance(0.05)
