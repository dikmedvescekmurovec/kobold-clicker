extends "res://tests/inventory_base.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   python tests/run_all.py inventory_saving
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.


func _run() -> void:
	_clear_save()
	_check(await _test_key_clicks() == true, "key click tests ran to the end")
	_check(await _test_drag_and_drop() == true, "drag and drop tests ran to the end")
	_check(_test_saving() == true, "saving tests ran to the end")
	_check(await _test_the_map_keeps_what_dropped() == true, "map drop tests ran to the end")
	_check(await _test_a_farm_run_holds_its_loot() == true, "farm run tests ran to the end")
	_check(await _test_a_rule_keeps_finds_off_the_screen() == true, "autodiscard fight tests ran to the end")
	_clear_save()
	_report("inventory: saving")


## The save has to round trip, and every way of being broken has to come back empty rather than loud.
func _test_saving() -> bool:
	_clear_save()
	_check(Inventory.load_from(TEST_PATH).total() == 0, "no file yet means nothing held")

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var inventory := Inventory.new()
	inventory.add(Item.rolled("Wooden Shield", ItemRarity.Rarity.ELITE, rng))
	inventory.add(Item.rolled("Wooden Armour", ItemRarity.Rarity.UNCOMMON, rng))
	inventory.add(Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng))
	inventory.gold = 1234
	_check(inventory.save(TEST_PATH), "the inventory saved")

	var loaded := Inventory.load_from(TEST_PATH)
	_check(loaded.total() == inventory.total(),
			"everything came back: %d of %d" % [loaded.total(), inventory.total()])
	for i in mini(loaded.total(), inventory.total()):
		_check(_fingerprint(loaded.items[i]) == _fingerprint(inventory.items[i]),
				"item %d came back as it went in: %s" % [i, _fingerprint(loaded.items[i])])
	_check(not loaded.first_sword_taken, "and the promised sword, still owed")
	_check(loaded.gold == 1234, "and the purse, at %d" % loaded.gold)
	# The ledger spends the sword on any drop, as it banks.
	var ledger := FightLedger.new(loaded, TEST_PATH)
	ledger.add_loot(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng))
	_check(Inventory.load_from(TEST_PATH).first_sword_taken, "a drop spends the promised sword")
	_check(not Inventory.load_from(TEST_PATH).first_orb_taken, "and the promised orb is still owed")
	var orb_ledger := FightLedger.new(Inventory.load_from(TEST_PATH), TEST_PATH)
	orb_ledger.add_orb("Orb of Alchemy")
	_check(not Inventory.load_from(TEST_PATH).first_orb_taken, "another orb does not spend it")
	orb_ledger.add_orb(OrbTable.FIRST_ORB)
	_check(Inventory.load_from(TEST_PATH).first_orb_taken, "a Transmutation does")

	# An item written by hand, to pin the file's shape rather than only its round trip.
	var one := Item.from_dict({"type": "Wooden Sword", "rarity": "rare",
			"mods": [{"id": "increased_damage", "value": 14}]})
	_check(one != null and one.rarity == ItemRarity.Rarity.RARE and one.mods.size() == 1,
			"a hand-written item reads")
	_check(Item.from_dict({"type": "Rusty Spoon", "rarity": "rare"}) == null, "a retired item is skipped")
	_check(Item.from_dict({"type": "Wooden Sword", "rarity": "legendary"}) == null,
			"so is a rarity this build has never heard of")
	_check(Item.from_dict("not a dictionary") == null, "and so is nonsense")
	var pruned := Item.from_dict({"type": "Wooden Sword", "rarity": "rare",
			"mods": [{"id": "retired_modifier", "value": 3}, {"id": "added_damage", "value": 2}]})
	_check(pruned != null and pruned.mods.size() == 1,
			"a retired modifier costs the item a line, not its place")

	# A save someone has been editing.
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string("{ not json at all")
	file.close()
	var problem: Array = []
	_check(Inventory.load_from(TEST_PATH, problem).total() == 0, "a corrupt save reads as empty instead of failing")
	_check(not problem.is_empty(), "and says why, so the scene can refuse to play over it")
	_check(FileAccess.get_file_as_string(TEST_PATH) == "{ not json at all", "and is left on disk untouched")

	# A save from a build that does not exist yet: refused rather than guessed at, so whatever wrote
	# it can still read it.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 99, "items": []}')
	file.close()
	problem = []
	_check(Inventory.load_from(TEST_PATH, problem).total() == 0, "a save from the future reads as empty")
	_check(not problem.is_empty(), "and is a refusal too")

	# A file that parses and is no save at all -- no version, and not the first shape either -- is not
	# an empty bag to be saved over.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"name": "something else"}')
	file.close()
	problem = []
	_check(Inventory.load_from(TEST_PATH, problem).total() == 0 and not problem.is_empty(),
			"a file that is not a save is refused, not read as an empty one")

	# A write is whole or not at all: it goes to a .tmp that is renamed over the save, and a .tmp
	# left alone by a crash between the two halves of that rename is the save, and is put back.
	_check(Inventory.new().save(TEST_PATH) and not FileAccess.file_exists(TEST_PATH + SafeFile.TMP),
			"a finished write leaves no .tmp behind")
	DirAccess.rename_absolute(TEST_PATH, TEST_PATH + SafeFile.TMP)
	problem = []
	Inventory.load_from(TEST_PATH, problem)
	_check(problem.is_empty() and FileAccess.file_exists(TEST_PATH)
			and not FileAccess.file_exists(TEST_PATH + SafeFile.TMP), "a lone .tmp is recovered as the save")

	# The shape this game kept before items had rarities.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 1, "first_elite_taken": true, "counts": '
			+ '{"Rusty Spoon": 5, "Leather Boot": 2, "Wooden Armor": 1, "Wooden Sword": "lots"}}')
	file.close()
	var migrated := Inventory.load_from(TEST_PATH)
	_check(migrated.total() == 3, "an old save's items came across, %d of them" % migrated.total())
	_check(migrated.count("Leather Boots") == 2 and migrated.count("Wooden Armour") == 1,
			"as what they are called now, under the names it knew them by")
	_check(migrated.items[0].stats == LootTable.stats_of(migrated.items[0].type), "each worth what the table says")
	_check(migrated.lost.count("Rusty Spoon") == 5, "and the pieces there no longer are, each said")
	_check(migrated.first_sword_taken, "and a save from before the Broken Sword never gets one")
	_check(migrated.first_orb_taken, "nor the promised orb")
	for item in migrated.items:
		_check(item.rarity == ItemRarity.Rarity.COMMON and item.mods.is_empty(),
				"an item from before rarities is a plain common")
	_check(migrated.save(TEST_PATH), "and it saves again")
	var text := FileAccess.get_file_as_string(TEST_PATH)
	_check(text.contains('"version": %d' % Inventory.VERSION), "in the shape this build writes")

	# The shape from before anything could be worn. Its whole save is bag, and the player starts
	# bare-handed: there is nothing to convert, which is the point of checking it.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 2, "first_elite_taken": false, "items": ' +
			'[{"type": "Wooden Sword", "rarity": "rare", "mods": []}]}')
	file.close()
	var from_v2 := Inventory.load_from(TEST_PATH)
	_check(from_v2.total() == 1, "a save from before equipment keeps its items")
	_check(from_v2.equipment.worn.is_empty(), "and wears nothing")

	# The rules go with the bag, and a save from before them has none -- an absent key and an empty
	# list read the same, which is what makes the migration nothing at all.
	var ruled := Inventory.new()
	ruled.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4))
	ruled.set_autodiscard(2, true)
	ruled.set_autodiscard(5, true)
	_check(ruled.save(TEST_PATH), "an inventory with rules saves")
	var ruled_back := Inventory.load_from(TEST_PATH)
	_check(ruled_back.autodiscards(2) and ruled_back.autodiscards(5),
			"and its rules come back")
	_check(not ruled_back.autodiscards(4), "only the ones that were set")
	_check(ruled_back.total() == 1, "with its items")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 4, "first_elite_taken": false, "items": ' +
			'[{"type": "Wooden Sword", "rarity": "rare", "level": 3, "mods": []}]}')
	file.close()
	var from_v4 := Inventory.load_from(TEST_PATH)
	_check(from_v4.total() == 1 and from_v4.autodiscard.is_empty(),
			"a save from before the rules keeps its items and carries none")

	# The purse goes the same way: a save from before gold simply has none, and an absent key reads as
	# an empty one rather than as a reason to start the bag over.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 5, "first_elite_taken": false, "autodiscard": [3], "items": ' +
			'[{"type": "Wooden Sword", "rarity": "rare", "level": 3, "mods": []}]}')
	file.close()
	var from_v5 := Inventory.load_from(TEST_PATH)
	_check(from_v5.total() == 1 and from_v5.autodiscards(3),
			"a save from before gold keeps its items and its rules")
	_check(from_v5.gold == 0, "and comes back empty-handed, not at %d" % from_v5.gold)
	# A hand-edited purse: nonsense is stepped over and a debt is not a thing the game can hold.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": %d, "gold": -50, "items": []}' % Inventory.VERSION)
	file.close()
	_check(Inventory.load_from(TEST_PATH).gold == 0, "a negative purse reads as none")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": %d, "gold": "loads", "items": []}' % Inventory.VERSION)
	file.close()
	_check(Inventory.load_from(TEST_PATH).gold == 0, "and so does one that is not a number")

	# The play clock goes the way the purse does: it round-trips, and a save from before it has none.
	var played := Inventory.new()
	played.play_seconds = 125.5
	_check(played.save(TEST_PATH), "an inventory with time on the clock saves")
	_check(is_equal_approx(Inventory.load_from(TEST_PATH).play_seconds, 125.5), "and its clock comes back")
	_check(played.transcended().play_seconds == played.play_seconds, "a transcension carries the clock over")
	# The depths of the dungeon the player has won are kept the same way, and are the player's too.
	played.dungeon_depth = 37
	played.save(TEST_PATH)
	_check(Inventory.load_from(TEST_PATH).dungeon_depth == 37, "the depths won in the dungeon come back")
	_check(played.transcended().dungeon_depth == 37, "and a transcension carries it over")
	# Before the leaderboard a save counted depths alone: its floors are theirs, Golluxes and all.
	_check(Inventory.load_from(TEST_PATH).dungeon_floors == 37 * Encounter.DUNGEON.enemies,
			"a save with no floors has beaten its depths' floors")
	played.dungeon_floors = 37 * Encounter.DUNGEON.enemies + 14
	played.save(TEST_PATH)
	_check(Inventory.load_from(TEST_PATH).dungeon_floors == played.dungeon_floors
			and played.transcended().dungeon_floors == played.dungeon_floors,
			"the floors beaten come back and are carried over")
	# So is how far the land has ever reached, which bounds every world's cave.
	_check(played.farthest_land == MapBuilder.START_LAND_RADIUS and not played.reach(MapBuilder.START_LAND_RADIUS),
			"no land further than the start's before a wall falls")
	_check(played.reach(30) and not played.reach(20) and played.farthest_land == 30, "the furthest reach only rises")
	# And the deepest tile charted, a leaderboard's score: the start's level 1 is no news.
	_check(not played.chart(1) and played.chart(9) and not played.chart(5) and played.deepest_level == 9,
			"the deepest tile charted only rises")
	played.save(TEST_PATH)
	var kept := Inventory.load_from(TEST_PATH)
	_check(kept.farthest_land == 30 and kept.deepest_level == 9, "they come back off the save")
	_check(played.transcended().farthest_land == 30 and played.transcended().deepest_level == 9,
			"and a transcension carries them over")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 24, "items": []}')
	file.close()
	kept = Inventory.load_from(TEST_PATH)
	_check(kept.farthest_land == MapBuilder.START_LAND_RADIUS,
			"a save from before it has been no further than the start's land")
	_check(kept.deepest_level == 1, "nor charted deeper than the start's tile")
	_check(kept.hero() == Inventory.DEFAULT_NAME, "and an unnamed character, as a save before names is")

	# The character's name: trimmed, cut to its most, never nothing, kept and carried like the kills.
	_check(played.hero() == Inventory.DEFAULT_NAME, "a character nobody has named is the default")
	_check(not played.rename("   ") and played.hero() == Inventory.DEFAULT_NAME, "a blank name changes nothing")
	_check(played.rename("  Cobalt ") and played.hero() == "Cobalt", "a name is trimmed")
	_check(not played.rename("Cobalt"), "and the same name again changes nothing")
	played.rename("x".repeat(Inventory.NAME_MOST + 5))
	_check(played.hero().length() == Inventory.NAME_MOST, "a long name is cut to %d letters" % Inventory.NAME_MOST)
	played.rename("Cobalt")
	played.save(TEST_PATH)
	_check(Inventory.load_from(TEST_PATH).hero() == "Cobalt" and played.transcended().hero() == "Cobalt",
			"the name comes back off the save and is carried through a transcension")
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 15, "items": []}')
	file.close()
	_check(Inventory.load_from(TEST_PATH).play_seconds == 0.0, "a save from before the clock has played no time")

	# A bag over the cap comes back whole and overencumbered: nothing is ever destroyed to fit it.
	var bloated := Inventory.new()
	for i in Inventory.CAPACITY + 5:
		bloated.items.append(_piece(ItemRarity.Rarity.COMMON, 6))
	_check(bloated.save(TEST_PATH), "an over-full save is written")
	var heavy := Inventory.load_from(TEST_PATH)
	_check(heavy.total() == Inventory.CAPACITY + 5 and heavy.encumbered(),
			"and comes back whole, overencumbered")
	_clear_save()
	return true


## The whole way through: a fight in the real scene, the drops it hands over, the grid that shows
## them, the stat block behind a square, and the file they end up in.
func _test_the_map_keeps_what_dropped() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	_check(main.inventory.total() == 0, "a first run starts with nothing")
	_check(not main._bag_button.visible and not main._skills_button.visible,
			"a first run has no corner buttons: nothing for them to open yet")
	main.inventory.tips.append("first_orb")
	main._show_corner(true)
	_check(main._bag_button.visible, "the items button is on the map once its tip is seen")
	_check(_bag_squares(main).is_empty(), "and the bag is empty")

	main._on_bag_pressed()
	_check(main.bag_page.visible and main._bag_button.visible, "the panel opens and the button stays")
	var sheet: Control = main.bag_page._worn_panel
	_check(main._bag_button.position.x >= sheet.position.x + sheet.size.x * main.ui_scale,
			"standing clear of the page, beside it")
	_check(is_equal_approx(main._bag_button.position.y, sheet.position.y),
			"and level with the top of the sheet it stands beside")
	main.bag_page._on_fold_pressed()
	var caret: Control = main.bag_page._show_button
	_check(is_equal_approx(main._bag_button.position.x, caret.position.x)
			and main._bag_button.position.y > caret.position.y,
			"with the sheet folded away, the column stands under its caret")
	main.bag_page._on_fold_pressed()
	# The bag takes the character panel's corner, so the panel goes to the other one, mirrored -- its
	# position is then its right edge -- with the button over it, clear of the column.
	await process_frame
	_check(main._character_slid_right and main._character.has_meta("moving"), "sliding in from that side")
	var drawn: Rect2 = main._character.get_transform() * Rect2(Vector2.ZERO, main._character.size)
	var safe := UITheme.safe_rect(main.get_viewport())
	_check(main._character.visible and main._character.mirrored
			and is_equal_approx(drawn.end.x, safe.end.x - main.CHARACTER_EDGE.x),
			"while the bag is up the character panel stands mirrored in the top-right corner (%s)" % drawn)
	_check(main._character_button.visible and main._character_button.get_rect() == drawn,
			"and can still be pressed")
	_check(main._bag_button.get_global_rect().end.x < drawn.position.x, "clear of the corner column")
	main.inventory.tips.append("level_up")
	main._show_corner(true)
	_check(is_equal_approx(main._skills_button.position.x, main._bag_button.position.x)
			and main._skills_button.position.y > main._bag_button.position.y, "the buttons are a column")
	main._on_skills_pressed()
	_check(main.skills_page.visible and not main.bag_page.visible, "and one press goes from page to page")
	_check(main._character.visible and main._character.mirrored,
			"the skill tree sends the character panel to the top-right too")
	_check(main._bag_button.position.x >= main.skills_page.get_child(0).size.x * main.ui_scale,
			"the column standing beside that one now")
	main._on_settings_pressed()
	_check(not main._character.visible and not main._character_button.visible,
			"any other page covers the character panel's corner")
	main._on_settings_pressed()
	_check(not main.settings_page.visible and main._character_button.visible, "a page's own button puts it away")
	main.inventory.tips.erase("level_up")
	main.inventory.tips.erase("opened_skills")
	main._on_bag_pressed()
	_check(main.bag_page._panel.position.x == UITheme.EDGE * main.ui_scale,
			"and stands EDGE off the left edge")
	_check(not main.bag_page._actions.visible, "with no buttons until a square is clicked")
	main._on_left_page_closed()
	_check(not main.bag_page.visible and main._bag_button.visible, "closing it gives the button back")
	_check(main._character.visible and not main._character.mirrored
			and main._character.position == safe.position + main.CHARACTER_EDGE,
			"and the character panel its own corner")

	# The equipment page: its own panel beside the item panel, eight sockets, all empty.
	main._on_bag_pressed()
	await process_frame
	_check(_socket_squares(main).size() == Equipment.sockets().size(),
			"the doll has %d sockets, not %d"
			% [Equipment.sockets().size(), _socket_squares(main).size()])
	_check(main.bag_page.visible, "the character sheet opens with the bag")
	_check(main.bag_page._worn_panel.position.x >= main.bag_page._panel.size.x * main.ui_scale,
			"and stands outside the item panel, not inside it")

	# The sockets are placed by hand on the silhouette, which is the one thing here no layout code
	# would catch going wrong: a socket with no spot would pile up at the origin, and two that
	# overlap would leave one of them unclickable wherever they cross.
	for socket: Equipment.Socket in Equipment.sockets():
		_check(main.bag_page.DOLL_SOCKETS.has(socket),
				"the %s socket has nowhere to sit on the doll" % Equipment.LABELS[socket])
	var placed := {}
	for socket: Equipment.Socket in main.bag_page.DOLL_SOCKETS:
		var spot: Vector2 = main.bag_page._socket_spot(socket)
		_check(spot.x >= 0.0 and spot.y >= 0.0,
				"the %s socket hangs off the page at %s" % [Equipment.LABELS[socket], spot])
		var box := Rect2(spot, Vector2(ItemSlot.SIDE, ItemSlot.SIDE))
		for other: Equipment.Socket in placed:
			_check(not box.intersects(placed[other]), "the %s and %s sockets overlap"
					% [Equipment.LABELS[socket], Equipment.LABELS[other]])
		placed[socket] = box
	# And the page is big enough to hold every one of them.
	for socket: Equipment.Socket in placed:
		var box: Rect2 = placed[socket]
		_check(box.end.x <= main.bag_page._doll.custom_minimum_size.x
				and box.end.y <= main.bag_page._doll.custom_minimum_size.y,
				"the %s socket runs off the page" % Equipment.LABELS[socket])

	# Wearing a sword through the panel: out of the bag, into the socket, and worth something.
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng)
	main.inventory.add(sword)
	main.bag_page._select_item(0)
	await process_frame
	_check(main.bag_page._actions.visible, "the sword's buttons come up")
	main.bag_page._on_equip_pressed(sword, Equipment.Socket.WEAPON)
	await process_frame
	_check(main.inventory.total() == 0, "wearing it takes it out of the bag")
	_check(main.inventory.equipment.item_at(Equipment.Socket.WEAPON) == sword, "and puts it on")
	var armed := Encounter.for_tile(Vector2i(1, 0), "grass")
	armed.arm(main.inventory.equipment.totals())
	_check(armed.damage > Encounter.BARE_DAMAGE, "and a fight now hits for more than a bare fist")
	_check(armed.attack_speed > 0.0, "with the weapon swinging on its own")

	# And off again, back to where it came from.
	main.bag_page._select_socket(Equipment.Socket.WEAPON)
	await process_frame
	_check(main.bag_page._actions.visible and _deep_button(main.bag_page._actions, "Unequip") != null,
			"a worn piece opens the same way, to Unequip")
	main.bag_page._on_unequip_pressed(Equipment.Socket.WEAPON)
	await process_frame
	_check(main.inventory.total() == 1 and main.inventory.items[0] == sword, "taking it off gives it back")
	_check(main.inventory.equipment.worn.is_empty(), "and leaves the socket empty")
	main.inventory.items.clear()
	main.inventory.save(TEST_PATH)
	main.bag_page._select_item(-1)

	# A first fight, whose elite is promised a drop. Choosing its tile puts the bag away: a tile chosen
	# has the screen to itself.
	_check(main.bag_page.visible, "the bag is up as the tile is chosen")
	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	main.map.select_cell(target)
	_check(not main._left_page_up() and main._panel.visible,
			"choosing a tile closes the page and brings the tile's panel up")
	main.inventory.tips.append("level_up")
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main._bag_button.visible and main._settings_button.visible and main._skills_button.visible
			and main._character_button.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and main._character_button.disabled, "a fight leaves the corner buttons, but not the character's")
	_check(main._character.xp_hover.is_visible_in_tree()
			and main._character.xp_hover.mouse_filter == Control.MOUSE_FILTER_PASS,
			"the experience bar's tooltip stays over a fight, letting every press through to the swing")
	var fight: Encounter = main._combat.fight
	_check(fight.promised == Encounter.PROMISED.keys() and fight.kills_before == 0,
			"a new player's first fight is owed every promised find")
	fight.loot_rng.seed = WORLD_SEED
	_play(fight)
	var combat: CombatScene = main._combat
	# A charting fight banks each purse as it lands, the way it banks each find: it is over in a
	# minute, and closing the game halfway through must not cost either.
	_check(fight.gold > 0, "the fight earned something: %d" % fight.gold)
	_check(main.inventory.gold == fight.gold,
			"and the purse has it already: %d of %d" % [main.inventory.gold, fight.gold])
	_check(Inventory.load_from(TEST_PATH).gold == fight.gold, "so does the file on disk")
	# The verdict's sums count up from nothing; they are read once they have.
	await create_timer(Juice.COUNT_DELAY + Juice.COUNT_TIME + 0.1).timeout
	_check(combat._gold_row.visible and combat._gold_label.text == "%d" % fight.gold,
			"and the verdict says so: %s" % combat._gold_label.text)
	_check(combat._kills_label.text == str(fight.kills()),
			"beside the bodies: %s" % combat._kills_label.text)
	_check(combat._result_drops.count() == combat._drops.size(),
			"the fight's panel shows everything that fell: %d of %d" % [
					combat._result_drops.count(), combat._drops.size()])
	_check(combat._loot_button.text == str(combat._drops.size()),
			"and so does the counter in the corner")

	# The hover card has to stand over the fight, or a find under the verdict has none to show.
	await process_frame
	await process_frame
	var cards: Array[Node] = main._character.get_parent().get_children().filter(
			func(node: Node) -> bool: return node is ItemCard)
	_check(cards.size() == 1 and (cards[0].get_parent() as CanvasLayer).layer > combat.layer,
			"the item card is drawn over the fight")
	_check(cards.size() == 1 and (cards[0] as ItemCard).slot_at(
			combat._result_drops._grid.get_child(0).get_child(0).get_global_rect().get_center()) != null,
			"and finds the first drop under the cursor")

	# A drop on that panel opens what it actually is, and goes back again.
	var dropped: Item = combat._drops[0]
	combat._result_drops.inspect(0)
	await process_frame
	_check(combat._result_drops.inspecting(), "clicking a drop opens it in the grid's place")
	var lines := PackedStringArray()
	for line: Node in _labels_under(combat._result_drops):
		lines.append((line as Label).text)
	_check(dropped.display_name() in lines, "which names the item")
	_check("%s · Level %d" % [dropped.rarity_label(), dropped.level] in lines,
			"and its rarity and level")
	for text in dropped.mod_lines():
		_check(text in lines, "and every modifier it carries: " + text)
	combat._result_drops.inspect(-1)
	await process_frame
	_check(not combat._result_drops.inspecting(), "and Back returns to the verdict")
	main._combat._on_back_pressed()
	await process_frame

	_check(main.inventory.total() == main.ledger.drops.size(),
			"everything the fight dropped was kept: %d of %d" % [
					main.inventory.total(), main.ledger.drops.size()])
	_check(main.inventory.count(LootTable.FIRST_DROP) == 1, "the promised sword fell")
	_check(main.inventory.first_sword_taken, "and is not promised again")
	_check(main.bag_page._gold.text == BigNumber.format(main.inventory.gold),
			"the bag's footer says what is in the purse: %s" % main.bag_page._gold.text)
	_check(main._bag_button.visible, "the button is back with the map")
	_check(main._tip_panel != null, "and the first find has a pop-up")

	# The grid holds one square per item, and a square opens what that item is.
	main._on_bag_pressed()
	await process_frame
	var squares := _bag_squares(main)
	_check(squares.size() == main.inventory.total(),
			"the sections hold every item: %d of %d" % [squares.size(), main.inventory.total()])
	main.bag_page._select_item(0)
	await process_frame
	_check(main.bag_page._actions.visible, "clicking a square stands its buttons beside it")
	var newest: Item = main.inventory.items[0]
	# The grid stays up, the clicked square is the one drawn dark, and the buttons stand beside it,
	# clear of the square; the hover card says what the piece is.
	var dark: Array = _bag_squares(main).filter(func(s: ItemSlot) -> bool: return s.selected)
	_check(dark.size() == 1 and dark[0].item == newest and dark[0].is_visible_in_tree(),
			"which is the one square drawn selected, in a grid still showing")
	_check(dark.size() == 1 and not dark[0].get_global_rect().intersects(
			Rect2(main.bag_page._actions.global_position,
				main.bag_page._actions.size * main.bag_page._actions.scale)),
			"with the buttons beside the square rather than over it")
	_check(dark.size() == 1 and dark[0].get_meta(ItemCard.BESIDE, null) == main.bag_page._actions,
			"and the hover card told to stand past them")
	_check(_deep_button(main.bag_page._actions, "Equip") != null
			and _deep_button(main.bag_page._actions, "Discard") != null, "Equip and Discard")
	main.bag_page._select_item(-1)
	await process_frame
	_check(not main.bag_page._actions.visible, "and they go away again")

	# The hand-written gesture: a press that stays put opens a square, one that travels scrolls the
	# grid and opens nothing. Driven straight at the handler, because a headless run has no mouse.
	var first: Control = _bag_squares(main)[0]
	var on_first := _square_spot(first)
	_press(main, on_first, true)
	_press(main, on_first, false)
	await process_frame
	_check(main.bag_page._actions.visible, "a press that stays put is a click")
	main.bag_page._select_item(-1)
	# A finger's: a mouse's press that travels from a square lifts the piece (`_test_drag_and_drop`).
	Cursors.touched = true
	_press(main, on_first, true)
	_drag(main, on_first, BagPage.DRAG_THRESHOLD * 4.0)
	_press(main, on_first, false)
	Cursors.touched = false
	await process_frame
	_check(not main.bag_page._actions.visible, "a finger's press that travels is a drag, and opens nothing")

	# Sections. Two levels means two grids with a heading each, and a square in the second section is
	# the case the flat-grid arithmetic this replaced would have got wrong.
	main.inventory.items.clear()
	main.inventory.add(_piece(ItemRarity.Rarity.COMMON, 1))
	var deeper := _piece(ItemRarity.Rarity.RARE, 6)
	main.inventory.add(deeper)
	main.bag_page._select_item(-1)
	await process_frame
	var grids := 0
	var headings := PackedStringArray()
	for section: Node in main.bag_page._sections.get_children():
		if section is GridContainer:
			grids += 1
		elif section is HBoxContainer:
			for label: Node in section.get_children():
				if label is Label:
					headings.append((label as Label).text)
	_check(grids == 2, "two levels held means two sections, not %d" % grids)
	_check("Level 6" in headings and "Level 1" in headings, "each under its own level")
	_check(headings[0] == "Level 6", "highest first")
	var squares_now := _bag_squares(main)
	_check(squares_now.size() == 2, "with one square each")
	_check(squares_now[0].get_meta("bag_index", -1) == main.inventory.items.find(deeper),
			"and the deeper piece is the first square")
	var second: Control = squares_now[1]
	# Read before the click: opening a square rebuilds the sections, and the square that was clicked
	# is gone by the time the answer is checked.
	var second_index: int = second.get_meta("bag_index", -1)
	main.bag_page._on_clicked(_square_spot(second))
	await process_frame
	_check(main.bag_page._selected == second_index,
			"a click in the second section opens that section's item")

	# Throwing one away by hand, from the bag.
	main.bag_page._select_item(main.inventory.items.find(deeper))
	await process_frame
	main.bag_page._on_discard_pressed(deeper)
	await process_frame
	_check(not main.inventory.items.has(deeper), "Discard takes the piece out of the bag")
	_check(_bag_squares(main).size() == 1, "and off the panel")
	_check(not Inventory.load_from(TEST_PATH).items.has(deeper), "and off the disk")

	# A level with a rule on it and nothing in it keeps its heading, which is the only place the rule
	# can be turned off again.
	main.bag_page._on_autodiscard_toggled(true, 9)
	await process_frame
	_check(main.inventory.autodiscards(9), "the Auto button sets the rule")
	_check(Inventory.load_from(TEST_PATH).autodiscards(9), "and writes it")
	var empty_heading := false
	for section: Node in main.bag_page._sections.get_children():
		if not (section is HBoxContainer):
			continue
		for label: Node in section.get_children():
			# "Level 9" in red while the rule is on, because the toggle's pressed face is far too
			# quiet to read a state off.
			if label is Label and (label as Label).text == "Level 9" \
					and (label as Label).get_theme_color("font_color") == Palette.BRICK:
				empty_heading = true
	_check(empty_heading, "a level with a rule and no items still has its heading")
	# The bin asks first, and Cancel leaves the level alone.
	var held: int = main.inventory.total()
	_press_bin(main)
	_check(main.bag_page._confirm != null and main.inventory.total() == held,
			"the bin asks before it throws a level away")
	_confirm_button(main, "Cancel").pressed.emit()
	_check(main.bag_page._confirm == null and main.inventory.total() == held, "Cancel keeps the level")
	# Escape is that Cancel, and the bag under the question stays up.
	_press_bin(main)
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(main.bag_page._confirm == null and main.inventory.total() == held and main.bag_page.visible,
			"Escape cancels the question and nothing else")
	# With a piece selected, Escape clears the selection and leaves the bag up; the next press closes it.
	main.bag_page._select_item(0)
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(main.bag_page._selected == -1 and main.bag_page.visible,
			"Escape on a selected piece deselects it and keeps the bag up")
	# The first find's pop-ups are still queued over the bag, and Escape would answer them first.
	for i in main.TIPS.size():
		if main._tip_panel == null:
			break
		main._on_tip_closed()
	Input.parse_input_event(escape)
	await process_frame
	await process_frame
	_check(not main.bag_page.visible, "and the next Escape closes the bag")
	main._on_bag_pressed()
	await process_frame
	# Yes with the box ticked empties it, and the question is not asked again.
	_press_bin(main)
	var box: Button = main.bag_page._confirm.find_child(BagPage.TICK_NAME, true, false)
	_check(box != null, "the question carries its tick box")
	box.button_pressed = true
	_confirm_button(main, "Discard").pressed.emit()
	await process_frame
	_check(main.inventory.total() == 0, "Clear empties a level")
	_check(Inventory.load_from(TEST_PATH).tips.has(BagPage.SKIP_CONFIRM + "clear"),
			"and not being asked again is written down")
	main.bag_page._ask("clear", "", "", "", "LightButton", func() -> void: pass)
	_check(main.bag_page._confirm == null, "so the next press asks nothing")
	main.bag_page._on_autodiscard_toggled(false, 9)

	# A unique among the handful is a second question: the ordinary pieces go on the first answer
	# (which the tick above now skips), the unique stays and is asked about by name.
	var unique_rng := RandomNumberGenerator.new()
	unique_rng.seed = WORLD_SEED
	var relic := Item.rolled_unique(UniqueTable.ids()[0], unique_rng, 5)
	main.inventory.add(relic)
	main.inventory.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, unique_rng, 5))
	main.bag_page.refresh()
	await process_frame
	_press_bin(main)
	_check(main.inventory.total() == 1 and main.inventory.items.has(relic),
			"the bin takes the ordinary pieces and leaves the unique")
	_check(main.bag_page._confirm != null and _confirm_button(main, "Don't discard") != null
			and relic.display_name() in _confirm_text(main), "and asks about it by name")
	_confirm_button(main, "Don't discard").pressed.emit()
	_check(main.bag_page._confirm == null and main.inventory.items.has(relic),
			"Don't discard leaves it in the bag")
	# Ticked beside Discard, the answer is kept in the settings rather than the question skipped.
	_press_bin(main)
	(main.bag_page._confirm.find_child(BagPage.TICK_NAME, true, false) as Button).button_pressed = true
	_confirm_button(main, "Discard").pressed.emit()
	await process_frame
	_check(main.inventory.total() == 0, "Discard throws the unique away")
	_check(Settings.uniques == Settings.Uniques.SELL and not main.inventory.tips.any(
			func(tip: String) -> bool: return tip.ends_with(BagPage.UNIQUES)),
			"and the ticked answer is Sell from now on, in the settings and not the save")
	main.inventory.add(Item.rolled_unique(UniqueTable.ids()[0], unique_rng, 5))
	main.bag_page.refresh()
	await process_frame
	_press_bin(main)
	_check(main.inventory.total() == 0 and main.bag_page._confirm == null,
			"under Sell the unique goes with the rest, unasked")
	Settings.uniques = Settings.Uniques.KEEP
	main.inventory.add(Item.rolled_unique(UniqueTable.ids()[0], unique_rng, 5))
	main.inventory.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, unique_rng, 5))
	main.bag_page.refresh()
	await process_frame
	_press_bin(main)
	_check(main.inventory.total() == 1 and main.bag_page._confirm == null
			and not main.inventory.items[0].unique.is_empty(), "under Keep it stays, unasked")
	main.bag_page._on_discard_pressed(main.inventory.items[0])   # saved, as the check below reads the disk
	Settings.uniques = Settings.Uniques.ASK
	await process_frame

	var saved := Inventory.load_from(TEST_PATH)
	_check(saved.total() == main.inventory.total(), "the file on disk holds the same count")
	for i in mini(saved.total(), main.inventory.total()):
		_check(_fingerprint(saved.items[i]) == _fingerprint(main.inventory.items[i]),
				"and the same item %d, modifiers and all" % i)
	_check(saved.first_sword_taken, "the promise is remembered across a restart")

	# A second fight is on its own merits. The player walks onto the tile before it opens.
	var next_cell := HexGrid.neighbor(target, HexGrid.Edge.E)
	main.map.select_cell(next_cell)
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(main._combat != null, "a second fight starts")
	if main._combat != null:
		_check(Encounter.SWORD not in main._combat.fight.promised
				and Encounter.TRANSMUTE in main._combat.fight.promised
				and main._combat.fight.kills_before == main.inventory.kills,
				"the second fight is owed the rest, counted from the kills made")
		main._combat.fight.give_up()
		main._combat._on_back_pressed()
		await process_frame
	main.queue_free()
	return true


## A farm run's finds go into the bag as they land, as every fight's do, and the bag can be opened
## over the fight to see them; a run still writes to disk only as it ends, since it could go an hour.
func _test_a_farm_run_holds_its_loot() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	# Farming asks nothing about where the player stands, only that the tile is already theirs.
	var here := MapBuilder.CENTER
	var next_door := HexGrid.neighbor(here, HexGrid.Edge.E)
	_check(main.view.can_farm(here), "the tile under the player can be farmed")
	_check(not main.view.can_farm(next_door), "and one that has not been taken cannot")
	# The bag's button is there once the first find has been spoken of; and no tip about the run
	# itself, which Escape would close before anything else.
	main.inventory.tips.append_array(["first_item", "first_farm"])
	main.map.select_cell(here)
	main._on_farm_pressed()
	_check(main._combat != null, "a run starts")
	if main._combat == null:
		main.queue_free()
		return true
	var fight: Encounter = main._combat.fight
	var combat: CombatScene = main._combat
	_check(fight.endless, "and it is endless")
	_check(combat._terminate != null, "with a way out of it on the screen")
	_check(main._bag_button.visible and main._settings_button.visible and not main._skills_button.visible,
			"and the corner buttons it has earned left standing")
	fight.loot_rng.seed = WORLD_SEED
	# Every body carries something, so three finds is three kills. What is under test is where a
	# run's finds go, not how often one falls -- at the real 3% this would be a hundred-odd kills.
	fight.always_drop = true

	var guard := 0
	while main.ledger.drops.size() < 3 and guard < 2000:
		guard += 1
		if not fight.hit():
			fight.advance(1.0 / 8.0)
	_check(main.ledger.drops.size() >= 3, "a run long enough turns up several things: %d"
			% main.ledger.drops.size())
	_check(not fight.finished, "and it is still going")
	_check(main.inventory.total() == main.ledger.drops.size(),
			"every one of them in the bag already: %d" % main.inventory.total())
	_check(fight.gold > 0 and main.inventory.gold == fight.gold,
			"and the gold in the purse: %s of %s" % [main.inventory.gold, fight.gold])
	_check(not FileAccess.file_exists(TEST_PATH), "but nothing written to disk while the run goes on")
	_check(combat._loot_button.text == str(main.ledger.drops.size()),
			"the counter has been keeping score all along")

	# The counter opens a summary of the same finds, and nothing in it throws one away.
	combat._on_loot_pressed()
	await process_frame
	_check(combat._loot_panel.visible, "the counter opens the popup")
	_check(combat._loot_drops.count() == main.ledger.drops.size(), "holding every find")
	_check(not combat._loot_drops.discardable, "as a summary: the bag is where a find is thrown away")
	combat.close_loot()
	await process_frame
	_check(not combat._loot_panel.visible, "and Close puts it away")

	# The bag opens over the run, on a layer above the fight's, and of the rest of the corner only the settings come with it.
	main._on_bag_pressed()
	await process_frame
	_check(main.bag_page.visible and main._combat == combat, "the bag opens over the run")
	_check(main._ui_layer.layer > combat.layer, "drawn over the fight")
	_check(not main._skills_button.visible and main._settings_button.visible,
			"with the other pages earned so far beside it")
	# A piece put on mid-fight counts from the next blow.
	var bare: float = fight.damage
	var sword := _piece(ItemRarity.Rarity.RARE, 1)
	main.inventory.add(sword)
	main.bag_page.refresh()
	main.bag_page._on_equip_pressed(sword, Equipment.Socket.WEAPON)
	await process_frame
	_check(main.inventory.equipment.item_at(Equipment.Socket.WEAPON) == sword, "a sword put on from the bag")
	_check(fight.damage > bare, "hits harder at once: %s over %s" % [fight.damage, bare])
	# Escape is the bag's while it is up: it closes the page and leaves the run going.
	var escape := InputEventAction.new()
	escape.action = "ui_cancel"
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	_check(not main.bag_page.visible and not fight.finished, "Escape puts the bag away and not the run")
	# The bag and the loot popup never stand together: each puts the other away.
	main._on_bag_pressed()
	combat._on_loot_pressed()
	await process_frame
	_check(combat._loot_panel.visible and not main.bag_page.visible, "the popup puts the bag away")
	main._on_bag_pressed()
	await process_frame
	_check(main.bag_page.visible and not combat._loot_panel.visible, "and the bag the popup")

	# Terminating is the end of the run, and the moment it is written down.
	var found: Array[Item] = main.ledger.drops.duplicate()
	var earned: float = main.inventory.gold
	combat._on_terminate_pressed()
	await process_frame
	_check(fight.finished and fight.victory, "terminating ends the run, and not as a loss")
	_check(not main.bag_page.visible and not main._bag_button.visible and not main._settings_button.visible,
			"the verdict puts the bag and its button away, and the settings'")
	main._combat._on_back_pressed()
	await process_frame
	var saved := Inventory.load_from(TEST_PATH)
	_check(saved.total() == found.size(), "the file on disk holds every find: %d of %d" % [saved.total(), found.size()])
	_check(saved.gold == earned, "and the gold with them: %s of %s" % [saved.gold, earned])
	_check(main.bag_page._gold.text == BigNumber.format(earned),
			"the bag's footer says so: %s" % main.bag_page._gold.text)

	# Nothing about the map moved. A run is fought on a tile that is already the player's.
	_check(main.view.charted(here), "the tile stays the player's")
	_check(not main.view.charted(next_door), "and the run charted nothing")
	_check(main._bag_button.visible and main._settings_button.visible, "the corner is back with the map")
	main.queue_free()
	return true


## A level the player is done with never reaches them: not the bag, not the counter, not either
## list. It is counted, and the count is said once at the end -- which is the whole of "noted, but
## not shown". And a bag with no room says so while the run is going, in time to do something about it.
func _test_a_rule_keeps_finds_off_the_screen() -> bool:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	main.map_path = TEST_MAP_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	# Everything this tile can drop is at a level the player has finished with. A tile's ceiling is
	# its level, so ruling out every level up to it rules out the lot.
	var here := MapBuilder.CENTER
	for level in range(1, MapBuilder.level_of(here) + LootTable.TIER_LEVEL.values().max() + 1):
		main.inventory.set_autodiscard(level, true)
	# And the bag is full, so the warning has something to say.
	for i in Inventory.CAPACITY:
		main.inventory.items.append(_piece(ItemRarity.Rarity.ELITE, 99))
	main.map.select_cell(here)
	# One over the cap and no fight can start: the buttons grey and the handlers refuse.
	var extra := _piece(ItemRarity.Rarity.COMMON, 1)
	main.inventory.items.append(extra)
	main._update_buttons()
	_check(main._farm_button.disabled and main._chart_button.disabled,
			"an overencumbered player cannot fight")
	_check(main._farm_button.tooltip_text == main.ENCUMBERED_TIP % main.inventory.capacity(), "and the button says why")
	main._on_farm_pressed()
	_check(main._combat == null, "and pressing Farm anyway opens nothing")
	main.inventory.remove(extra)
	main._process(0.0)
	_check(not main._farm_button.disabled, "back at the cap the button comes back by itself")
	main._on_farm_pressed()
	_check(main._combat != null, "a run starts")
	if main._combat == null:
		main.queue_free()
		return true
	var fight: Encounter = main._combat.fight
	var combat: CombatScene = main._combat
	fight.loot_rng.seed = WORLD_SEED
	# An orb is thrown out of a body exactly as a find is, and no autodiscard rule filters one -- so
	# the arena is not empty of *everything*, it is empty of finds. Counted rather than seeded away:
	# what lands is the run's own business, and the check below subtracts it.
	var orbs: Array = []
	fight.orb_dropped.connect(func(_index: int, _orb: String) -> void: orbs.append(true))
	# As above: every body carries something, so the rule has something to throw away at once.
	fight.always_drop = true
	_check(combat.bag_room == 0, "a full bag leaves the fight no room")
	# Which is said by the counter's own face and nowhere else.
	combat._refresh()
	_check(combat._loot_filled == 1.0, "the counter's face is at the red end of its ramp")

	var guard := 0
	while combat._auto_discarded < 3 and guard < 2000:
		guard += 1
		if not fight.hit():
			fight.advance(1.0 / 8.0)
	_check(combat._auto_discarded >= 3, "the rule threw several away: %d" % combat._auto_discarded)
	# None of them touched anything the player can see.
	_check(main.ledger.drops.is_empty(), "none of them reached the ledger")
	_check(combat._drops.is_empty(), "or the fight's own list")
	_check(combat._loot_button.text == "0" and not combat._loot_button.disabled,
			"the counter never moved, and still opens")
	_check(combat._loot_drops.count() == 0 and combat._result_drops.count() == 0,
			"and neither list has a square in it")
	_check(combat._finds_shown == orbs.size(),
			"nothing but the orbs was thrown into the arena (%d against %d)"
			% [combat._finds_shown, orbs.size()])
	_check(main.inventory.total() == Inventory.CAPACITY, "and the bag is exactly as it was")
	# The rule is about finds. A purse is a number rather than a square, so nothing filters it and a
	# run that kept nothing still earned its way.
	_check(fight.gold > 0, "the gold came all the same: %s" % fight.gold)

	# Said once, at the end, as a number.
	var thrown := combat._auto_discarded
	combat._on_terminate_pressed()
	await process_frame
	await process_frame
	_check(combat._auto_label.visible, "the verdict says what the rule threw away")
	_check(combat._auto_label.text == "%d items discarded automatically" % thrown,
			"as a count and nothing more: %s" % combat._auto_label.text)
	main._combat._on_back_pressed()
	await process_frame
	_check(main.inventory.total() == Inventory.CAPACITY, "the run banked nothing, because it kept nothing")
	_check(main.inventory.gold > 0, "but it banked its gold: %d" % main.inventory.gold)
	main.queue_free()
	return true


## Shift and Ctrl on a click: the square's own button pressed for it -- Equip or Unequip, Discard --
## and the keys a square says it answers to, for the card's foot.
func _test_key_clicks() -> bool:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4)
	var boot := Item.rolled("Leather Boots", ItemRarity.Rarity.RARE, rng, 4)
	inventory.add(sword)
	inventory.add(boot)
	var page := BagPage.new(inventory, TEST_PATH, 1.0)
	root.add_child(page)
	await process_frame
	var main := {"bag_page": page}
	var squares := _bag_squares(main)
	_check(squares.size() == 2 and squares.all(func(s: Control) -> bool:
			return s.get_meta(ItemCard.KEYS, {}) == {"shift": "equip", "ctrl": "discard"}),
			"a bag square answers to Shift for Equip and Ctrl for Discard")
	var sword_square: Control = squares.filter(func(s: ItemSlot) -> bool: return s.item == sword)[0]
	page._on_clicked(_square_spot(sword_square), true, false)
	await process_frame
	_check(inventory.equipment.item_at(Equipment.Socket.WEAPON) == sword, "a Shift-click wears the piece")
	_check(page._selected == -1 and not page._actions.visible, "and the bag has nothing open after it")
	var sockets := _socket_squares(main)
	var worn: Array = sockets.filter(func(s: Control) -> bool:
			return s.get_meta("socket") == Equipment.Socket.WEAPON)
	_check(worn.size() == 1 and worn[0].get_meta(ItemCard.KEYS, {}) == {"shift": "unequip"},
			"the worn square answers to Shift for Unequip")
	var bare: Array = sockets.filter(func(s: Control) -> bool:
			return s.get_meta("socket") == Equipment.Socket.HELMET)
	_check(bare.size() == 1 and not bare[0].has_meta(ItemCard.KEYS), "and a bare socket to nothing")
	_click_doll(page, worn[0].position + worn[0].size / 2.0, true)
	await process_frame
	_check(inventory.equipment.item_at(Equipment.Socket.WEAPON) == null and sword in inventory.items,
			"a Shift-click on the doll takes the piece off")
	# With the bag full, Unequip is grey: the click opens the socket and moves nothing.
	page._on_clicked(_square_spot(_bag_squares(main).filter(
			func(s: ItemSlot) -> bool: return s.item == sword)[0]), true, false)
	await process_frame
	while not inventory.is_full():
		inventory.add(Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng, 1))
	page.refresh()
	await process_frame
	worn = _socket_squares(main).filter(func(s: Control) -> bool:
			return s.get_meta("socket") == Equipment.Socket.WEAPON)
	_click_doll(page, worn[0].position + worn[0].size / 2.0, true)
	await process_frame
	_check(inventory.equipment.item_at(Equipment.Socket.WEAPON) == sword,
			"a full bag leaves a Shift-clicked worn piece on")
	_check(page._worn_selected == Equipment.Socket.WEAPON and page._actions.visible,
			"with the socket open and its grey button showing why")
	var unequip := _deep_button(page._actions, "Unequip")
	_check(unequip != null and unequip.disabled, "which is Unequip, grey")
	# Ctrl throws away.
	var count := inventory.total()
	var boot_square: Control = _bag_squares(main).filter(
			func(s: ItemSlot) -> bool: return s.item == boot)[0]
	page._on_clicked(_square_spot(boot_square), false, true)
	await process_frame
	_check(inventory.total() == count - 1 and not (boot in inventory.items),
			"a Ctrl-click throws the piece away")
	# A transcension's bag has no buttons, so its squares name no keys and a modified click opens only.
	var choosing := BagPage.new(inventory, "", 1.0, false, true)
	root.add_child(choosing)
	await process_frame
	main.bag_page = choosing
	var chooser_squares := _bag_squares(main)
	_check(not chooser_squares.is_empty() and chooser_squares.all(
			func(s: Control) -> bool: return not s.has_meta(ItemCard.KEYS)),
			"a transcension's squares answer to no key")
	count = inventory.total()
	choosing._on_clicked(_square_spot(chooser_squares[0]), false, true)
	await process_frame
	_check(inventory.total() == count, "and a Ctrl-click there throws nothing away")
	page.queue_free()
	choosing.queue_free()
	await process_frame
	return true


## Drag and drop through the viewport, as a mouse does it: a bag piece let go over a socket it does not
## fit stays in the bag, over one it fits is worn, and a worn piece let go over the bag is taken off; on
## the black screen's stones page a stone let go over a slot of the tree is placed there.
func _test_drag_and_drop() -> bool:
	var window := root.size
	root.size = Vector2i(1152, 648)
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4)
	inventory.add(sword)
	var page := BagPage.new(inventory, TEST_PATH, 2.0)
	root.add_child(page)
	await process_frame
	var main := {"bag_page": page}
	var socket_spot := func(socket: Equipment.Socket) -> Vector2:
		for slot: Control in _socket_squares(main):
			if slot.get_meta("socket") == socket:
				return _middle(slot)
		return Vector2.INF
	var marks := func(on: Node) -> Array[Node]:
		return on.find_children(BagPage.DROP_MARK_NAME, "", true, false)
	var dimmed := func(socket: Equipment.Socket) -> bool:
		return _socket_squares(main).any(func(slot: Control) -> bool:
				return slot.get_meta("socket") == socket and slot.modulate == OrbSlot.DIM)
	await _mouse_drag(_middle(_bag_squares(main)[0]), socket_spot.call(Equipment.Socket.HELMET),
			func() -> void:
				_check(page._selected == -1 and not page._actions.visible,
						"a piece being dragged is not opened, and no buttons stand beside it")
				_check(dimmed.call(Equipment.Socket.HELMET) and not dimmed.call(Equipment.Socket.WEAPON),
						"the sockets it cannot go in are dimmed, the one it can is not")
				_check(marks.call(page).is_empty(), "and the helmet it is over, which will not take it, is not outlined"))
	await process_frame
	_check(sword in inventory.items and inventory.equipment.worn.is_empty(),
			"a sword let go over the helmet stays in the bag")
	_check(not root.gui_is_dragging(), "and the drag is over")
	_check(not dimmed.call(Equipment.Socket.HELMET), "and nothing is dimmed after it")
	await _mouse_drag(_middle(_bag_squares(main)[0]), socket_spot.call(Equipment.Socket.WEAPON),
			func() -> void:
				var outlined: Array = marks.call(page)
				_check(outlined.size() == 1 and outlined[0].get_parent().get_meta("socket", -1)
						== Equipment.Socket.WEAPON, "over the weapon hand, which will take it, that socket is outlined"))
	await process_frame
	_check(inventory.equipment.item_at(Equipment.Socket.WEAPON) == sword and sword not in inventory.items,
			"let go over the weapon hand it is worn")
	_check(marks.call(page).is_empty(), "and the outline goes with the drag")
	await _mouse_drag(socket_spot.call(Equipment.Socket.WEAPON), _middle(page._scroll))
	await process_frame
	_check(sword in inventory.items and inventory.equipment.worn.is_empty(),
			"a worn piece let go over the bag is taken off")
	page.queue_free()

	var stone := Item.new()
	stone.type = "Strength Node"
	stone.rarity = ItemRarity.Rarity.RARE
	stone.stone_tier = 1
	stone.connectors = 2
	stone.stats = Item.scaled_stats(stone.type, 1)
	inventory.add(stone)
	var starter := _node("Dexterity Node", "global_increased_attack_speed")
	inventory.skills.stones["0"] = starter
	var stones := BagPage.new(inventory, "", 2.0, false, true, true)
	root.add_child(stones)
	await process_frame
	main.bag_page = stones
	var tree_view := func() -> SkillTreeView:
		return stones.find_children("*", "SkillTreeView", true, false)[0]
	var spot: Control = tree_view.call().squares["0"]
	await _mouse_drag(_middle(_bag_squares(main)[0]),
			spot.get_global_transform_with_canvas() * (spot.get_combined_minimum_size() / 2.0),
			func() -> void:
				var squares: Dictionary = tree_view.call().squares
				_check(squares[""].modulate == SkillTreeView.FAINT and squares["0"].modulate == Color.WHITE
						and tree_view.call()._rings.has("0"),
						"over the tree the root is faint for a dragged stone, the slot it fits ringed")
				_check(not marks.call(squares["0"]).is_empty(), "and the slot under it is outlined"))
	await process_frame
	_check(inventory.skills.stones["0"] == stone and starter in inventory.items and stone not in inventory.items,
			"a stone let go over the tree's slot is placed, and the one it replaces comes back to the bag")
	_check(tree_view.call().squares[""].modulate == Color.WHITE, "and the root is lit again after")
	stones.queue_free()
	var back := InputEventMouseMotion.new()
	Input.parse_input_event(back)
	await process_frame
	root.size = window
	return true
