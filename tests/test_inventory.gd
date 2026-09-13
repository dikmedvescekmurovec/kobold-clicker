extends "res://tests/harness.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_inventory.gd
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.

## A lambda captures what it can see by value, and a PackedStringArray is a value too, so everything
## these tests collect from a signal is gathered in an Array, which is shared rather than copied.
## Never Inventory.SAVE_PATH: these tests write and delete, and that is the player's own save.
const TEST_PATH := "user://test_inventory.json"
## Enough rolls that a rate lands within a percent or so of the chance behind it.
const ROLLS := 20000


func _run() -> void:
	_clear_save()
	_check(_test_items() == true, "item tests ran to the end")
	_check(_test_slot_locks() == true, "slot lock tests ran to the end")
	_check(_test_chances() == true, "drop-chance tests ran to the end")
	_check(_test_rarity_tables() == true, "rarity table tests ran to the end")
	_check(_test_rarity_rolls() == true, "rarity roll tests ran to the end")
	_check(_test_modifier_tables() == true, "modifier table tests ran to the end")
	_check(_test_modifier_rolls() == true, "modifier roll tests ran to the end")
	_check(_test_rolls() == true, "drop tests ran to the end")
	_check(_test_a_fight_drops() == true, "fight drop tests ran to the end")
	_check(_test_the_promised_elite() == true, "promised elite tests ran to the end")
	_check(_test_counts() == true, "counting tests ran to the end")
	_check(_test_saving() == true, "saving tests ran to the end")
	await _test_the_map_keeps_what_dropped()
	_clear_save()
	_report("inventory")


func _clear_save() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))


## Every item has art on disk at the size the panel draws it, a weight that can come up, and stats
## the panel knows how to write.
func _test_items() -> bool:
	var items := LootTable.items()
	_check(not items.is_empty(), "there is something to find")
	for item in items:
		var path := LootTable.icon_path(item)
		_check(ResourceLoader.exists(path), "missing icon " + path)
		var icon := LootTable.icon(item)
		_check(icon != null, item + " has an icon")
		if icon != null:
			_check(icon.get_size() == Vector2(32, 32), "%s is %s, not 32x32" % [item, icon.get_size()])
		_check(int(LootTable.ITEMS[item]["weight"]) > 0, item + " can come up at all")
		var stats := LootTable.stats_of(item)
		_check(not stats.is_empty(), item + " is worth something")
		for stat: String in stats:
			# A stat with no label would reach the stat block as a bare key.
			_check(LootTable.STAT_LABELS.has(stat), "%s has no label for %s" % [item, stat])
			_check(not LootTable.stat_line(stat, stats[stat]).is_empty(), stat + " writes a line")
		for stat: String in LootTable.affixes_of(item):
			_check(LootTable.STAT_LABELS.has(stat), "%s has no label for affix %s" % [item, stat])
			_check(not stats.has(stat),
					"%s lists %s as an affix and as a base stat" % [item, stat])
			# An affix is only reachable through a FLAT modifier -- a PERCENT one needs the base
			# stat, which an affix by definition is not. One with none is dead weight in the table.
			var reachable := false
			for id: String in ModifierTable.MODS:
				var mod: Dictionary = ModifierTable.MODS[id]
				reachable = reachable or (mod["kind"] == ModifierTable.Kind.FLAT
						and mod["stat"] == stat)
			_check(reachable, "%s can carry %s, but nothing flat rolls it" % [item, stat])
	return true


## The stats that belong to one piece and must stay there. Offence on the weapon is the rule the
## whole table is built on -- damage anywhere else and the sword stops being the interesting slot --
## and the other two are locked by what the piece is: you walk in boots and you block with a thing
## you hold. Pinned here so a later widening of the tables cannot quietly undo the design.
func _test_slot_locks() -> bool:
	var locked := {
		"damage": ["Wooden Sword"],
		"move_speed": ["Leather Boot"],
		"block_chance": ["Wooden Shield", "Wooden Torch"],
	}
	for stat: String in locked:
		var found := PackedStringArray()
		for item in LootTable.items():
			if LootTable.can_roll(item, stat):
				found.append(item)
		var want: Array = locked[stat]
		_check(found.size() == want.size(), "%s is on %s, not %s" % [stat, found, want])
		for item: String in want:
			_check(item in found, "%s should be on %s" % [stat, item])
	return true


## The two tables have to cover every enemy in the roster, or a kill would crash looking itself up.
## This is what stops a new enemy being added with a size or tier the loot table has never heard of.
func _test_chances() -> bool:
	for name in EnemyRoster.names():
		var chance := LootTable.chance_for(name)
		_check(chance > 0.0 and chance <= 1.0, "%s drops with a real chance, not %f" % [name, chance])
	# Tier and size both only ever push the chance up.
	var tiers := [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]
	for i in tiers.size() - 1:
		_check(LootTable.TIER_CHANCE[tiers[i]] < LootTable.TIER_CHANCE[tiers[i + 1]],
				"tier %d drops less often than tier %d" % [i, i + 1])
	var sizes := [EnemyRoster.Size.TINY, EnemyRoster.Size.SMALL, EnemyRoster.Size.MEDIUM,
			EnemyRoster.Size.LARGE, EnemyRoster.Size.HUGE]
	for i in sizes.size() - 1:
		_check(LootTable.SIZE_CHANCE[sizes[i]] < LootTable.SIZE_CHANCE[sizes[i + 1]],
				"a size %d body carries less than a size %d one" % [i, i + 1])

	# The tuning guard: what a real fight is worth, summed over real lineups. Drops are meant to be
	# rare -- about one item every third fight -- so this is what catches a table nudged too far.
	# Rarity changes what drops, never whether, so none of it touches this number; the promised first
	# elite is a one-off and sits outside it too.
	var fights := 0
	var expected := 0.0
	for env: String in SheetMeta.env_adjacency():
		for i in 5:
			var fight := Encounter.for_tile(Vector2i(i, i * 2), env)
			fights += 1
			for enemy in fight.lineup:
				expected += LootTable.chance_for(enemy)
	var per_fight := expected / fights
	print("Expected drops per fight: %.2f" % per_fight)
	_check(per_fight > 0.2 and per_fight < 0.6, "a fight is worth %.2f drops, outside 0.2 to 0.6" % per_fight)
	return true


## Every rarity has to be spelled, coloured and banded, and every tier needs a row -- a missing key
## here is a crash on the day a rarity is added, rather than a line missing from a panel.
func _test_rarity_tables() -> bool:
	var steps := ItemRarity.NAMES.keys()
	_check(steps.size() == 5, "there are five rarities, not %d" % steps.size())
	for step: ItemRarity.Rarity in steps:
		_check(not ItemRarity.name_of(step).is_empty(), "rarity %d is named" % step)
		_check(ItemRarity.from_name(ItemRarity.name_of(step)) == step, "a rarity name reads back")
		_check(ItemRarity.MOD_COUNT.has(step), "rarity %d says how many modifiers it carries" % step)
		_check(ItemRarity.BORDER_COLORS.has(step), "rarity %d has a border colour" % step)
		_check(ItemRarity.TEXT_COLORS.has(step), "rarity %d has a text colour" % step)
	_check(ItemRarity.from_name("legendary") < 0, "a rarity nobody has heard of reads as nothing")

	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
		_check(ItemRarity.TIER_WEIGHTS.has(tier), "tier %d rolls a rarity" % tier)
		var row: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
		var total := 0
		for step: ItemRarity.Rarity in steps:
			_check(row.has(step), "tier %d has a weight for rarity %d" % [tier, step])
			total += int(row[step])
		_check(total > 0, "tier %d can roll something" % tier)
		# Uniques are hand-crafted and belong to a later chunk. This is what fails loudly and
		# usefully on the day they are switched on.
		_check(int(row[ItemRarity.Rarity.UNIQUE]) == 0, "tier %d cannot roll a unique" % tier)

	# Better enemies carry better things: plain gear falls away and every good step climbs.
	var tiers := [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]
	for i in tiers.size() - 1:
		var low: Dictionary = ItemRarity.TIER_WEIGHTS[tiers[i]]
		var high: Dictionary = ItemRarity.TIER_WEIGHTS[tiers[i + 1]]
		_check(int(low[ItemRarity.Rarity.COMMON]) > int(high[ItemRarity.Rarity.COMMON]),
				"a tier %d body drops more plain gear than a tier %d one" % [i, i + 1])
		for step: ItemRarity.Rarity in [ItemRarity.Rarity.UNCOMMON, ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
			_check(int(low[step]) < int(high[step]),
					"a tier %d body drops fewer of rarity %d than a tier %d one" % [i, step, i + 1])
	return true


## The rolled rarities follow the table, and how many modifiers an item carries follows its rarity.
func _test_rarity_rolls() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for tier: EnemyRoster.Tier in [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]:
		var row: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
		var total := 0
		for step: ItemRarity.Rarity in row:
			total += int(row[step])
		var seen := {}
		for i in ROLLS:
			var step := ItemRarity.roll(tier, rng)
			seen[step] = int(seen.get(step, 0)) + 1
		for step: ItemRarity.Rarity in row:
			var share := float(seen.get(step, 0)) / ROLLS
			var want := float(row[step]) / total
			_check(absf(share - want) < 0.01,
					"tier %d rolled rarity %d at %.3f, not %.3f" % [tier, step, share, want])
		_check(not seen.has(ItemRarity.Rarity.UNIQUE), "tier %d never rolled a unique" % tier)

	for step: ItemRarity.Rarity in ItemRarity.MOD_COUNT:
		var band: Array = ItemRarity.MOD_COUNT[step]
		for i in 500:
			var count := ItemRarity.mod_count(step, rng)
			_check(count >= int(band[0]) and count <= int(band[1]),
					"rarity %d asked for %d modifiers, outside %s" % [step, count, band])
	_check(ItemRarity.MOD_COUNT[ItemRarity.Rarity.COMMON] == [0, 0], "a common carries nothing extra")
	return true


## Every modifier has to be drawable, name a stat something actually has, and write a line.
func _test_modifier_tables() -> bool:
	for id: String in ModifierTable.MODS:
		var mod: Dictionary = ModifierTable.MODS[id]
		_check(int(mod["weight"]) > 0, id + " can be drawn at all")
		var band: Array = mod["range"]
		_check(int(band[0]) <= int(band[1]), id + " rolls in a real range")
		_check(int(band[0]) > 0, id + " is worth something")
		if mod["kind"] == ModifierTable.Kind.PLAYER:
			_check(not str(mod["line"]).is_empty(), id + " says what it does")
			continue
		var stat: String = mod["stat"]
		_check(LootTable.STAT_LABELS.has(stat), "%s names %s, which has no label" % [id, stat])
		# A modifier for a stat nothing carries could never be rolled: dead weight in the table. A
		# PERCENT one needs a piece with the base stat; a FLAT one only needs one allowed to carry it.
		var carried := false
		for item in LootTable.items():
			if mod["kind"] == ModifierTable.Kind.PERCENT:
				carried = carried or LootTable.has_stat(item, stat)
			else:
				carried = carried or LootTable.can_roll(item, stat)
		_check(carried, "%s names %s, which no item can roll" % [id, stat])
		_check(not ModifierTable.line({"id": id, "value": int(band[1])}).is_empty(), id + " writes a line")
	_check(ModifierTable.line({"id": "nonsense", "value": 1}).is_empty(), "an unknown modifier writes nothing")

	# Every pool has to be deep enough to fill the largest band, or an elite piece comes up short.
	var most: int = ItemRarity.MOD_COUNT[ItemRarity.Rarity.ELITE][1]
	for item in LootTable.items():
		var pool := ModifierTable.pool_for(item)
		_check(pool.size() >= most,
				"%s can only carry %d modifiers, short of %d" % [item, pool.size(), most])
	return true


## What a rolled item carries: never twice the same, never a stat it hasn't got, always in range.
func _test_modifier_rolls() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for item_type in LootTable.items():
		var stats := LootTable.stats_of(item_type)
		for step: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON,
				ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
			var band: Array = ItemRarity.MOD_COUNT[step]
			for i in 200:
				var item := Item.rolled(item_type, step, rng)
				_check(item.mods.size() >= int(band[0]) and item.mods.size() <= int(band[1]),
						"%s (%s) carries %d modifiers, outside %s" % [
								item_type, item.rarity_name(), item.mods.size(), band])
				var seen := {}
				for mod in item.mods:
					var id: String = mod["id"]
					_check(not seen.has(id), "%s carries %s twice" % [item_type, id])
					seen[id] = true
					var entry: Dictionary = ModifierTable.MODS[id]
					var range_band: Array = entry["range"]
					_check(typeof(mod["value"]) == TYPE_INT, id + " rolled a whole number")
					_check(mod["value"] >= int(range_band[0]) and mod["value"] <= int(range_band[1]),
							"%s rolled %d, outside %s" % [id, mod["value"], range_band])
					# The rule the whole table turns on: a PERCENT modifier scales a base stat, so the
					# piece must have one; a FLAT one only has to be allowed to carry the stat.
					if entry["kind"] == ModifierTable.Kind.PERCENT:
						_check(stats.has(entry["stat"]),
								"%s rolled %s, scaling a base stat it hasn't got" % [item_type, id])
					elif entry["kind"] == ModifierTable.Kind.FLAT:
						_check(LootTable.can_roll(item_type, entry["stat"]),
								"%s rolled %s for a stat it cannot carry" % [item_type, id])
				_check(item.mod_lines().size() == item.mods.size(), "every modifier writes its line")
				_check(item.stat_lines().size() == stats.size(), "every base stat writes its line")
	return true


## A drop gives nothing or a real item, at the rate and in the mix the tables say.
func _test_rolls() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var enemy := "Skeleton Warrior"   # common, medium: a plain body to measure against
	var dropped := 0
	var mix := {}
	var rarities := {}
	for i in ROLLS:
		var item := LootTable.roll(enemy, rng)
		if item == null:
			continue
		dropped += 1
		_check(item.type in LootTable.items(), "rolled a real item, not " + item.type)
		mix[item.type] = int(mix.get(item.type, 0)) + 1
		rarities[item.rarity] = int(rarities.get(item.rarity, 0)) + 1

	var rate := float(dropped) / ROLLS
	var chance := LootTable.chance_for(enemy)
	_check(absf(rate - chance) < 0.01, "%s dropped at %.3f, not its %.3f" % [enemy, rate, chance])

	var total_weight := 0
	for item: String in LootTable.ITEMS:
		total_weight += int(LootTable.ITEMS[item]["weight"])
	for item: String in LootTable.ITEMS:
		var share := float(mix.get(item, 0)) / maxi(dropped, 1)
		var want := float(LootTable.ITEMS[item]["weight"]) / total_weight
		_check(absf(share - want) < 0.05, "%s came up %.2f of the time, not %.2f" % [item, share, want])

	# What common rabble is worth: almost all plain gear, and an elite piece practically never.
	var elite_share := float(rarities.get(ItemRarity.Rarity.ELITE, 0)) / maxi(dropped, 1)
	_check(elite_share < 0.005, "common rabble dropped elite gear %.3f of the time" % elite_share)
	_check(not rarities.has(ItemRarity.Rarity.UNIQUE), "and never a unique")

	# The same seed gives the same run, which is what lets the rest of these tests be sure of anything.
	_check(_drops_of(7) == _drops_of(7), "a seeded fight drops the same twice")
	return true


## A tile's ten are the tile's, but what they carry is not: re-fighting the same tile has to be able
## to give something else, or what is collected would only say which tiles were fought.
func _test_a_fight_drops() -> bool:
	var seen := {}
	for attempt in 20:
		var fight := Encounter.for_tile(Vector2i(4, 2), "grass")
		fight.loot_rng.seed = attempt
		var drops: Array[Item] = []
		fight.loot_dropped.connect(func(_index: int, item: Item) -> void: drops.append(item))
		_play(fight)
		seen[_fingerprint_all(drops)] = true
	_check(seen.size() > 1, "the same tile can drop different things on a second attempt")

	# A fight lost part way keeps what it already dropped, and rolls nothing on the way out.
	var lost := Encounter.for_tile(Vector2i(4, 2), "grass")
	lost.loot_rng.seed = 1
	lost.guarantee_elite = true
	var kept: Array[Item] = []
	lost.loot_dropped.connect(func(_index: int, item: Item) -> void: kept.append(item))
	for i in 3:
		while lost.phase != Encounter.Phase.WAITING and not lost.finished:
			lost.advance(0.05)
		while lost.hit():
			pass
	var before := kept.size()
	lost.advance(Encounter.SECONDS)
	_check(lost.finished and not lost.victory, "the clock ran out")
	_check(kept.size() == before, "losing drops nothing more")
	return true


## The first elite is promised a drop, and only the elite, and only while it is promised.
func _test_the_promised_elite() -> bool:
	for attempt in 100:
		var fight := Encounter.for_tile(Vector2i(2, 2), "grass")
		fight.loot_rng.seed = attempt
		fight.guarantee_elite = true
		var elite_drops: Array[Item] = []
		fight.loot_dropped.connect(func(index: int, item: Item) -> void:
			if index == Encounter.ENEMIES - 1:
				elite_drops.append(item))
		_play(fight)
		_check(elite_drops.size() == 1, "the promised elite dropped once, not %d times" % elite_drops.size())

	# Without the promise, the elite is as stingy as it is written to be.
	var without: Array[Item] = []
	for attempt in 100:
		var fight := Encounter.for_tile(Vector2i(2, 2), "grass")
		fight.loot_rng.seed = attempt
		fight.loot_dropped.connect(func(index: int, item: Item) -> void:
			if index == Encounter.ENEMIES - 1:
				without.append(item))
		_play(fight)
	_check(without.size() < 100, "an unpromised elite does not always drop (%d of 100 did)" % without.size())
	return true


func _test_counts() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var inventory := Inventory.new()
	_check(inventory.count("Wooden Sword") == 0, "an unseen item is counted as none")
	_check(inventory.total() == 0, "an empty inventory holds nothing")
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng)
	inventory.add(sword)
	inventory.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng))
	inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng))
	_check(inventory.count("Wooden Sword") == 2, "two swords are two")
	_check(inventory.total() == 3, "three things in all")
	_check(inventory.items[0].rarity == ItemRarity.Rarity.RARE, "and each is its own item")
	_check(inventory.remove(sword), "an item can be taken back out")
	_check(inventory.total() == 2 and inventory.count("Wooden Sword") == 1, "and then it is gone")
	return true


## The save has to round trip, and every way of being broken has to come back empty rather than loud.
func _test_saving() -> bool:
	_clear_save()
	_check(Inventory.load_from(TEST_PATH).total() == 0, "no file yet means nothing held")

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var inventory := Inventory.new()
	inventory.add(Item.rolled("Wooden Shield", ItemRarity.Rarity.ELITE, rng))
	inventory.add(Item.rolled("Wooden Armor", ItemRarity.Rarity.UNCOMMON, rng))
	inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng))
	inventory.first_elite_taken = true
	_check(inventory.save(TEST_PATH), "the inventory saved")

	var loaded := Inventory.load_from(TEST_PATH)
	_check(loaded.total() == inventory.total(),
			"everything came back: %d of %d" % [loaded.total(), inventory.total()])
	for i in mini(loaded.total(), inventory.total()):
		_check(_fingerprint(loaded.items[i]) == _fingerprint(inventory.items[i]),
				"item %d came back as it went in: %s" % [i, _fingerprint(loaded.items[i])])
	_check(loaded.first_elite_taken, "and so did the promised elite")

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
	_check(Inventory.load_from(TEST_PATH).total() == 0, "a corrupt save starts empty instead of failing")

	# A save from a build that does not exist yet: refused rather than guessed at, so whatever wrote
	# it can still read it.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 99, "items": []}')
	file.close()
	_check(Inventory.load_from(TEST_PATH).total() == 0, "a save from the future starts empty")

	# The shape this game kept before items had rarities.
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string('{"version": 1, "first_elite_taken": true, "counts": {"Rusty Spoon": 5, "Leather Boot": 2}}')
	file.close()
	var migrated := Inventory.load_from(TEST_PATH)
	_check(migrated.total() == 2, "an old save's items came across, %d of them" % migrated.total())
	_check(migrated.count("Leather Boot") == 2, "as what they were")
	_check(migrated.first_elite_taken, "and it is still remembered")
	for item in migrated.items:
		_check(item.rarity == ItemRarity.Rarity.COMMON and item.mods.is_empty(),
				"an item from before rarities is a plain common")
	_check(migrated.save(TEST_PATH), "and it saves again")
	var text := FileAccess.get_file_as_string(TEST_PATH)
	_check(text.contains('"version": 2'), "in the shape this build writes")
	_clear_save()
	return true


## The whole way through: a fight in the real scene, the drops it hands over, the grid that shows
## them, the stat block behind a square, and the file they end up in.
func _test_the_map_keeps_what_dropped() -> void:
	_clear_save()
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = 1
	main.inventory_path = TEST_PATH
	root.add_child(main)
	for i in 3:
		await process_frame

	_check(main.inventory.total() == 0, "a first run starts with nothing")
	_check(main._bag_button.visible, "the items button is on the map")
	_check(main._bag_grid.get_child_count() == 0, "and the bag is empty")

	main._on_bag_pressed()
	_check(main._bag_panel.visible and not main._bag_button.visible, "the panel takes the button's place")
	_check(is_zero_approx(main._bag_panel.position.x), "and sits against the left edge")
	_check(not main._bag_detail.visible, "with no stat block until a square is clicked")
	main._on_bag_closed()
	_check(not main._bag_panel.visible and main._bag_button.visible, "closing it gives the button back")

	# A first fight, whose elite is promised a drop.
	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	main.map.select_cell(target)
	main._on_discover_pressed()
	_check(not main._bag_button.visible, "the button is out of the way of the fight")
	var fight: Encounter = main._combat.fight
	_check(fight.guarantee_elite, "the first elite is promised a drop")
	fight.loot_rng.seed = WORLD_SEED
	_play(fight)
	var combat: CombatScene = main._combat
	_check(combat._result_drops.get_child_count() > 0, "the fight's panel shows what fell")

	# A drop on that panel opens what it actually is, and goes back again.
	await process_frame
	var dropped: Item = combat._drops[0]
	combat._inspect_drop(0)
	await process_frame
	_check(combat._result_inspect.visible and not combat._result_summary.visible,
			"clicking a drop opens it in the verdict's place")
	var lines := PackedStringArray()
	for line: Node in combat._result_inspect_rows.get_children():
		if line is Label:
			lines.append((line as Label).text)
	_check(dropped.display_name() in lines, "which names the item")
	_check(dropped.rarity_name() in lines, "and its rarity")
	for text in dropped.mod_lines():
		_check(text in lines, "and every modifier it carries: " + text)
	combat._inspect_drop(-1)
	await process_frame
	_check(combat._result_summary.visible and not combat._result_inspect.visible,
			"and Back returns to the verdict")
	main._combat._on_back_pressed()
	await process_frame

	_check(main.inventory.total() == main._fight_drops.size(),
			"everything the fight dropped was kept: %d of %d" % [
					main.inventory.total(), main._fight_drops.size()])
	_check(main.inventory.total() > 0, "the promised elite paid out")
	_check(main.inventory.first_elite_taken, "and is not promised again")
	_check(main._bag_button.visible, "the button is back with the map")

	# The grid holds one square per item, and a square opens what that item is.
	main._on_bag_pressed()
	await process_frame
	_check(main._bag_grid.get_child_count() == main.inventory.total(),
			"the grid holds every item: %d of %d" % [
					main._bag_grid.get_child_count(), main.inventory.total()])
	main._select_item(0)
	await process_frame
	_check(main._bag_detail.visible, "clicking a square opens its stat block")
	var newest: Item = main.inventory.items[0]
	var block := PackedStringArray()
	for line: Node in main._bag_detail.get_children():
		if line is Label:
			block.append((line as Label).text)
	_check(newest.display_name() in block, "which names the item")
	_check(newest.rarity_name() in block, "and its rarity")
	main._select_item(-1)
	await process_frame
	_check(not main._bag_detail.visible, "and it closes again")

	# The hand-written gesture: a press that stays put opens a square, one that travels scrolls the
	# grid and opens nothing. Driven straight at the handler, because a headless run has no mouse.
	var first: Control = main._bag_grid.get_child(0)
	var on_first := first.position + first.size / 2.0
	_press(main, on_first, true)
	_press(main, on_first, false)
	await process_frame
	_check(main._bag_detail.visible, "a press that stays put is a click")
	main._select_item(-1)
	_press(main, on_first, true)
	_drag(main, on_first, main.BAG_DRAG_THRESHOLD * 4.0)
	_press(main, on_first, false)
	await process_frame
	_check(not main._bag_detail.visible, "a press that travels is a drag, and opens nothing")

	var saved := Inventory.load_from(TEST_PATH)
	_check(saved.total() == main.inventory.total(), "the file on disk holds the same count")
	for i in mini(saved.total(), main.inventory.total()):
		_check(_fingerprint(saved.items[i]) == _fingerprint(main.inventory.items[i]),
				"and the same item %d, modifiers and all" % i)
	_check(saved.first_elite_taken, "the promise is remembered across a restart")

	# A second fight is on its own merits. Winning the first sent the player walking onto the tile,
	# and nothing can be fought for while they are on their way, so let them arrive first.
	main.map.player.finish_walk()
	await process_frame
	var next_cell := HexGrid.neighbor(target, HexGrid.Edge.E)
	main.map.select_cell(next_cell)
	main._on_discover_pressed()
	_check(main._combat != null, "a second fight starts")
	if main._combat != null:
		_check(not main._combat.fight.guarantee_elite, "the second fight promises nothing")
		main._combat.fight.give_up()
		main._combat._on_back_pressed()
		await process_frame
	main.queue_free()


## A mouse button going down or coming up on the grid, in the panel's own coordinates.
func _press(main: Node, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	main._on_bag_grid_input(event)


## The cursor moving `by` pixels down the grid with the button held.
func _drag(main: Node, from: Vector2, by: float) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = from + Vector2(0, by)
	event.relative = Vector2(0, by)
	main._on_bag_grid_input(event)


## One item as a string, so two of them can be compared across a save.
func _fingerprint(item: Item) -> String:
	var parts := PackedStringArray()
	for mod in item.mods:
		parts.append("%s:%d" % [mod["id"], mod["value"]])
	return "%s|%s|%s" % [item.type, item.rarity_name(), ", ".join(parts)]


func _fingerprint_all(items: Array[Item]) -> String:
	var parts := PackedStringArray()
	for item in items:
		parts.append(_fingerprint(item))
	return " / ".join(parts)


## What one seeded fight drops, in order, as one string to compare.
func _drops_of(seed_value: int) -> String:
	var fight := Encounter.for_tile(Vector2i(1, 1), "grass")
	fight.loot_rng.seed = seed_value
	var drops: Array[Item] = []
	fight.loot_dropped.connect(func(_index: int, item: Item) -> void: drops.append(item))
	_play(fight)
	return _fingerprint_all(drops)


## Beats a fight without a scene: hit when there is something to hit, let the clock run otherwise.
func _play(fight: Encounter) -> void:
	var guard := 0
	while not fight.finished and guard < 10000:
		guard += 1
		if not fight.hit():
			fight.advance(1.0 / 8.0)
