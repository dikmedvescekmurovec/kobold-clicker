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
## Nor MapSave.SAVE_PATH, for the same reason and one more: these pin a seed, and a pinned seed
## that differs from a save is a request for another world, which replaces it on the first write.
const TEST_MAP_PATH := "user://test_inventory_map.json"
## Enough rolls that a rate lands within a percent or so of the chance behind it. Most of these
## come back empty on purpose -- what is being measured is how often anything falls at all.
const ROLLS := 20000
## Enough *guaranteed* rolls to measure what a drop looks like when there is one. Far fewer are
## needed than above because every one of them lands: going through a common's 3% gate threw 97
## rolls in 100 away and left a rare step's share as mostly noise.
const SHAPE_ROLLS := 4000


func _run() -> void:
	_clear_save()
	_check(_test_items() == true, "item tests ran to the end")
	_check(_test_kinds() == true, "kind tests ran to the end")
	_check(_test_slot_locks() == true, "slot lock tests ran to the end")
	_check(_test_drops_scroll() == true, "drops scroll tests ran to the end")
	_check(_test_sockets() == true, "socket tests ran to the end")
	_check(_test_totals() == true, "stat total tests ran to the end")
	_check(_test_wearing() == true, "wearing tests ran to the end")
	_check(await _test_key_clicks() == true, "key click tests ran to the end")
	_check(_test_two_handed() == true, "two-handed tests ran to the end")
	_check(_test_chances() == true, "drop-chance tests ran to the end")
	_check(_test_rarity_tables() == true, "rarity table tests ran to the end")
	_check(_test_rarity_rolls() == true, "rarity roll tests ran to the end")
	_check(_test_modifier_tables() == true, "modifier table tests ran to the end")
	_check(_test_modifier_rolls() == true, "modifier roll tests ran to the end")
	_check(_test_rolls() == true, "drop tests ran to the end")
	_check(_test_a_fight_drops() == true, "fight drop tests ran to the end")
	_check(_test_drops_cascade() == true, "cascading drop tests ran to the end")
	_check(_test_the_promised_elite() == true, "promised elite tests ran to the end")
	_check(_test_counts() == true, "counting tests ran to the end")
	_check(_test_level_rolls() == true, "level roll tests ran to the end")
	_check(_test_item_levels() == true, "item level tests ran to the end")
	_check(_test_saving() == true, "saving tests ran to the end")
	_check(_test_orb_tables() == true, "orb table tests ran to the end")
	_check(_test_orb_verbs() == true, "orb verb tests ran to the end")
	_check(_test_locks_and_breaks() == true, "lock and break tests ran to the end")
	_check(_test_orb_saving() == true, "orb saving tests ran to the end")
	_check(_test_player_level() == true, "player level tests ran to the end")
	_check(_test_bag_order() == true, "bag order tests ran to the end")
	_check(_test_capacity() == true, "capacity tests ran to the end")
	_check(_test_autodiscard() == true, "autodiscard tests ran to the end")
	_check(_test_deltas() == true, "delta tests ran to the end")
	_check(await _test_comparing() == true, "comparison tests ran to the end")
	# Checked the same way as the rest: a script error aborts the function and returns null, which
	# would otherwise be a suite that quietly stopped halfway and still said it passed.
	_check(await _test_the_map_keeps_what_dropped() == true, "map drop tests ran to the end")
	_check(await _test_a_farm_run_holds_its_loot() == true, "farm run tests ran to the end")
	_check(await _test_a_rule_keeps_finds_off_the_screen() == true, "autodiscard fight tests ran to the end")
	_check(await _test_crafting_from_the_bag() == true, "crafting tests ran to the end")
	_check(await _test_tips() == true, "tip tests ran to the end")
	_check(_test_fight_ledger() == true, "fight ledger tests ran to the end")
	_check(_test_unique_table() == true, "unique table tests ran to the end")
	_check(_test_unique_items() == true, "unique item tests ran to the end")
	_check(await _test_unique_stats() == true, "unique stat tests ran to the end")
	_check(await _test_collection() == true, "collection log tests ran to the end")
	_check(await _test_character_page() == true, "character page tests ran to the end")
	_check(await _test_item_generator() == true, "item generator tests ran to the end")
	_check(await _test_heirlooms() == true, "heirloom tests ran to the end")
	_check(_test_super_orbs() == true, "super orb tests ran to the end")
	_check(_test_mod_tiers() == true, "modifier tier tests ran to the end")
	_clear_save()
	_report("inventory")


func _clear_save() -> void:
	for path in [TEST_PATH, TEST_MAP_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Every item has art on disk at the size the panel draws it, a weight that can come up, and stats
## the panel knows how to write.
func _test_items() -> bool:
	var items := LootTable.items()
	_check(not items.is_empty(), "there is something to find")
	# The dev tick puts a replaced base's old picture back and leaves a base that never had another alone.
	Settings.old_icons = true
	if Settings.show_old_icons():
		_check(LootTable.icon_path("Iron Helmet") == LootTable.OLD_ROOT + "Iron Helmet.png",
				"the old-icons tick shows the Iron Helmet it replaced")
		_check(LootTable.icon_path("Masterwork Helm") == LootTable.ROOT + "Masterwork Helm.png",
				"a base never replaced keeps its own icon under the tick")
	Settings.old_icons = false
	_check(LootTable.icon_path("Iron Helmet") == LootTable.ROOT + "Iron Helmet.png",
			"without the tick the Iron Helmet is the new one")
	for item in items:
		var path := LootTable.icon_path(item)
		_check(ResourceLoader.exists(path), "missing icon " + path)
		var icon := LootTable.icon(item)
		_check(icon != null, item + " has an icon")
		if icon != null:
			_check(icon.get_size() == Vector2(32, 32), "%s is %s, not 32x32" % [item, icon.get_size()])
		_check(int(LootTable.ITEMS[item]["weight"]) > 0 or item in [LootTable.FIRST_DROP, LootTable.BROKEN_TORCH],
				item + " can come up at all")
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
		# And the same three questions of the globals: a stat with no label reaches the block as a
		# bare key, a global on a base stat would say the same thing a PERCENT already says, and one
		# no GLOBAL modifier names is a permission nothing can use.
		for stat: String in LootTable.globals_of(item):
			_check(LootTable.STAT_LABELS.has(stat), "%s has no label for global %s" % [item, stat])
			_check(not stats.has(stat),
					"%s scales %s globally and has it as a base stat" % [item, stat])
			var has_global := false
			for id: String in ModifierTable.MODS:
				var mod: Dictionary = ModifierTable.MODS[id]
				has_global = has_global or (mod["kind"] == ModifierTable.Kind.GLOBAL
						and mod["stat"] == stat)
			_check(has_global, "%s can scale %s globally, but nothing global rolls it" % [item, stat])
	return true


## Every socket takes something, every item type has a socket to go in, and the two that are not
## one-to-one behave: a ring fits either hand, and a shield and a torch compete for the one offhand.
func _test_sockets() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sockets := Equipment.sockets()
	_check(sockets.size() == 8, "there are eight sockets, not %d" % sockets.size())
	for socket: Equipment.Socket in sockets:
		_check(Equipment.NAMES.has(socket) and Equipment.LABELS.has(socket)
				and Equipment.TAKES.has(socket), "socket %d is named, labelled and takes something" % socket)
		var takers := PackedStringArray()
		for type in LootTable.items():
			if LootTable.slot_of(type) == Equipment.TAKES[socket]:
				takers.append(type)
		_check(not takers.is_empty(), "nothing fits the %s socket" % Equipment.LABELS[socket])
	# No two sockets share a save name, or one would quietly overwrite the other on disk.
	var names := {}
	for socket: Equipment.Socket in sockets:
		_check(not names.has(Equipment.NAMES[socket]), "two sockets are saved as the same name")
		names[Equipment.NAMES[socket]] = true

	var gear := Equipment.new()
	var ring := Item.rolled("Gold Ring", ItemRarity.Rarity.COMMON, rng)
	_check(gear.sockets_for(ring).size() == 2, "a ring fits two sockets")
	_check(Equipment.fits(Equipment.Socket.RING_LEFT, ring), "and either of them")
	_check(not Equipment.fits(Equipment.Socket.WEAPON, ring), "but not the weapon hand")
	var boot := Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng)
	_check(gear.equip(Equipment.Socket.HELMET, boot).is_empty()
			and gear.item_at(Equipment.Socket.HELMET) == null, "a boot will not go on the head")

	# The shared offhand: a shield and a torch both fit it, and the second one in displaces the first.
	var shield := Item.rolled("Wooden Shield", ItemRarity.Rarity.COMMON, rng)
	var torch := Item.rolled("Wooden Torch", ItemRarity.Rarity.COMMON, rng)
	_check(gear.sockets_for(shield) == [Equipment.Socket.OFFHAND], "a shield fits only the offhand")
	_check(gear.sockets_for(torch) == [Equipment.Socket.OFFHAND], "and so does a torch")
	gear.equip(Equipment.Socket.OFFHAND, shield)
	var swapped := gear.equip(Equipment.Socket.OFFHAND, torch)
	_check(swapped.size() == 1 and swapped[0] == shield, "the torch puts the shield back")
	_check(gear.item_at(Equipment.Socket.OFFHAND) == torch, "and takes its place")
	_check(gear.unequip(Equipment.Socket.OFFHAND) == torch, "and comes off again")
	_check(gear.unequip(Equipment.Socket.OFFHAND) == null, "an empty socket gives nothing back")
	return true


## What a set adds up to, and that wearing is a move rather than a copy.
func _test_totals() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var gear := Equipment.new()
	_check(gear.totals().is_empty(), "wearing nothing is worth nothing")

	# A common sword is its base stats exactly: no modifiers to fold in.
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng)
	gear.equip(Equipment.Socket.WEAPON, sword)
	var base: Dictionary = LootTable.stats_of("Wooden Sword")
	for stat: String in base:
		_check(is_equal_approx(gear.totals()[stat], float(base[stat])),
				"a plain sword is worth its %s" % stat)

	# Two rings add. This is the whole reason the tables put a stat on more than one piece.
	var two := Equipment.new()
	two.equip(Equipment.Socket.RING_LEFT, Item.rolled("Gold Ring", ItemRarity.Rarity.COMMON, rng))
	two.equip(Equipment.Socket.RING_RIGHT, Item.rolled("Gold Ring", ItemRarity.Rarity.COMMON, rng))
	var one: float = float(LootTable.stats_of("Gold Ring")["gold_find"])
	_check(is_equal_approx(two.totals()["gold_find"], one * 2.0), "two rings are worth two rings")

	# Flat before percent, which is the only order that makes both modifiers worth having.
	var rolled := Item.new()
	rolled.type = "Wooden Sword"
	# A piece carries its own numbers now, so one built by hand has to be given them; at level 1 they
	# are the table as written, which is what this arithmetic is stated against.
	rolled.stats = Item.scaled_stats("Wooden Sword", 1)
	rolled.mods = [{"id": "added_damage", "value": 2}, {"id": "increased_damage", "value": 20}]
	_check(is_equal_approx(rolled.effective_stats()["damage"], (1.0 + 2.0) * 1.2),
			"a sword adds before it scales, not after")
	# A flat modifier on an affix gives the piece a stat it has no base for at all.
	var affixed := Item.new()
	affixed.type = "Wooden Sword"
	affixed.mods = [{"id": "added_strength", "value": 5}]
	_check(not LootTable.has_stat("Wooden Sword", "strength"), "a sword has no strength of its own")
	_check(is_equal_approx(affixed.effective_stats()["strength"], 5.0), "and carries it anyway")

	# The attributes are a fifth of a percent a point: strength of the set's damage, dexterity of its
	# swings, intelligence of the experience a kill pays.
	var bag := Inventory.new()
	var own := Item.new()
	own.type = "Wooden Sword"
	own.stats = Item.scaled_stats("Wooden Sword", 1)
	bag.equipment.equip(Equipment.Socket.WEAPON, own)
	var plain := bag.stats()
	own.mods = [{"id": "added_strength", "value": 10}, {"id": "added_dexterity", "value": 5},
			{"id": "added_intelligence", "value": 20}]
	var gifted := bag.stats()
	_check(is_equal_approx(gifted["damage"], plain["damage"] * 1.02), "ten strength is 2% more damage")
	_check(is_equal_approx(float(gifted.get("attack_speed", 0.0)), float(plain.get("attack_speed", 0.0)) * 1.01),
			"five dexterity is 1% more swings")
	_check(is_equal_approx(float(gifted.get("xp_more", 0.0)), 4.0), "twenty intelligence is 4% more experience")

	# A save's player-wide lines come back as the FLAT ones they were folded into, flags and all but a
	# perfect one's; a piece already holding that line keeps its own.
	var saved := Item.rolled("Gold Ring", ItemRarity.Rarity.COMMON, rng).to_dict()
	saved["mods"] = [{"id": "walk_speed", "value": 5}, {"id": "fight_clock", "value": 3, "locked": true},
			{"id": "added_item_rarity", "value": 12}, {"id": "item_rarity", "value": 7, "perfect": true}]
	var back := Item.from_dict(saved)
	_check(back.mods.map(func(mod: Dictionary) -> String: return mod["id"])
			== ["added_move_speed", "added_fight_clock", "added_item_rarity"], "the old ids are renamed (%s)" % [back.mods])
	_check(int(back.mods[0]["value"]) == 5 and int(back.mods[1]["value"]) == 30 and back.mods[1].get("locked", false)
			and int(back.mods[2]["value"]) == 12, "the clock counts tenths, and the lock holds")

	# A global belongs to the set, not to the piece: the ring carrying it is worth no damage at all,
	# and what it scales is the sword's. Two of them add before they scale, the way the panel reads.
	var worn := Equipment.new()
	var blade := Item.new()
	blade.type = "Wooden Sword"
	blade.stats = Item.scaled_stats("Wooden Sword", 1)
	var ring := Item.new()
	ring.type = "Gold Ring"
	ring.stats = Item.scaled_stats("Gold Ring", 1)
	ring.mods = [{"id": "global_increased_damage", "value": 20}]
	_check(not ring.effective_stats().has("damage"), "a ring with increased damage has no damage")
	_check(is_equal_approx(float(ring.global_percents()["damage"]), 20.0), "it asks it of the set")
	worn.equip(Equipment.Socket.WEAPON, blade)
	worn.equip(Equipment.Socket.RING_LEFT, ring)
	var blade_damage: float = float(blade.effective_stats()["damage"])
	_check(is_equal_approx(worn.totals()["damage"], blade_damage * 1.2),
			"and the sword is what it scales")
	var other := Item.new()
	other.type = "Gold Ring"
	other.stats = Item.scaled_stats("Gold Ring", 1)
	other.mods = [{"id": "global_increased_damage", "value": 30}]
	worn.equip(Equipment.Socket.RING_RIGHT, other)
	_check(is_equal_approx(worn.totals()["damage"], blade_damage * 1.5),
			"two globals add rather than compound")
	# A global with nothing to scale scales nothing, rather than conjuring a stat out of a percentage.
	var bare := Equipment.new()
	bare.equip(Equipment.Socket.RING_LEFT, ring)
	_check(is_equal_approx(float(bare.totals().get("damage", 0.0)), 0.0),
			"increased damage is worth nothing bare-handed")
	return true


## Wearing something is a move: it leaves the bag, and comes back when it comes off.
func _test_wearing() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var bag := Inventory.new()
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng)
	bag.add(sword)
	bag.add(Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng))
	_check(bag.total() == 2, "two swords in the bag")
	_check(bag.equip(sword, Equipment.Socket.WEAPON), "one goes on")
	_check(bag.total() == 1, "and is out of the bag")
	_check(bag.equipment.item_at(Equipment.Socket.WEAPON) == sword, "and on the player")
	# Equipping over something hands the old piece back rather than losing it.
	_check(bag.equip(bag.items[0], Equipment.Socket.WEAPON), "the other goes on over it")
	_check(bag.total() == 1 and bag.items[0] == sword, "and the first is back in the bag")
	_check(not bag.equip(sword, Equipment.Socket.BOOTS), "a sword will not go on the feet")
	_check(bag.total() == 1, "and a refused equip takes nothing out of the bag")
	_check(bag.unequip(Equipment.Socket.WEAPON), "what is worn comes off")
	_check(bag.total() == 2, "back into the bag")
	_check(not bag.unequip(Equipment.Socket.WEAPON), "and an empty socket comes off no further")

	# A worn set survives the save, sockets and all.
	bag.equip(bag.items[0], Equipment.Socket.WEAPON)
	bag.equip(Item.rolled("Gold Ring", ItemRarity.Rarity.ELITE, rng), Equipment.Socket.RING_RIGHT)
	bag.items.append(Item.rolled("Gold Ring", ItemRarity.Rarity.ELITE, rng))
	bag.equip(bag.items[bag.total() - 1], Equipment.Socket.RING_RIGHT)
	_check(bag.save(TEST_PATH), "a worn set saves")
	var read := Inventory.load_from(TEST_PATH)
	_check(read.equipment.worn.size() == bag.equipment.worn.size(), "and comes back worn")
	for socket: Equipment.Socket in bag.equipment.worn:
		_check(_fingerprint(read.equipment.item_at(socket))
				== _fingerprint(bag.equipment.item_at(socket)), "the same piece in the same socket")
	_check(read.total() == bag.total(), "with the bag as it was")

	# A piece saved into a socket it no longer fits is dropped rather than worn wrongly.
	var wrong := Equipment.from_dict({"boots": {"type": "Wooden Sword", "rarity": "common", "mods": []}})
	_check(wrong.worn.is_empty(), "a sword saved onto the feet does not come back")
	_clear_save()
	return true


## A piece that needs both hands. Putting one on costs the offhand and putting anything in the offhand
## costs the whole of it, which makes it the one swap that is not one piece for one piece -- so the
## bag has to have room for what comes off, and the comparison has to count all of it.
func _test_two_handed() -> bool:
	const GREAT := "Wooden Greatsword"
	_check(LootTable.two_handed(GREAT), "a greatsword takes both hands")
	_check(not LootTable.two_handed("Wooden Sword"), "and a sword leaves one free")

	# On over a sword and a shield: it is told first, and then both come back into the bag.
	var bag := Inventory.new()
	var sword := _plain("Wooden Sword")
	var shield := _plain("Wooden Shield")
	var great := _plain(GREAT)
	for piece: Item in [sword, shield, great]:
		bag.add(piece)
	bag.equip(sword, Equipment.Socket.WEAPON)
	bag.equip(shield, Equipment.Socket.OFFHAND)
	var coming := bag.equipment.displaced_by(Equipment.Socket.WEAPON, great)
	_check(coming.size() == 2 and coming.has(sword) and coming.has(shield),
			"a greatsword going on costs the sword and the shield")
	_check(bag.equip(great, Equipment.Socket.WEAPON), "and it goes on")
	_check(bag.equipment.item_at(Equipment.Socket.WEAPON) == great
			and bag.equipment.item_at(Equipment.Socket.OFFHAND) == null,
			"filling the weapon hand and emptying the other")
	_check(bag.total() == 2 and bag.items.has(sword) and bag.items.has(shield),
			"with both back in the bag")
	_check(bag.equipment.two_handed_worn(), "and the offhand closed while it is worn")

	# And back the other way: something in the offhand has nowhere to go but the weapon hand.
	_check(bag.equip(shield, Equipment.Socket.OFFHAND), "a shield goes on over a greatsword")
	_check(bag.equipment.item_at(Equipment.Socket.OFFHAND) == shield
			and bag.equipment.item_at(Equipment.Socket.WEAPON) == null,
			"and takes the greatsword off with it")
	_check(bag.items.has(great) and bag.total() == 2, "which is back in the bag")

	# What the set is worth is the weapon alone: there is no hand left for the offhand's numbers.
	var gear := Equipment.new()
	gear.equip(Equipment.Socket.OFFHAND, _plain("Wooden Shield"))
	gear.equip(Equipment.Socket.WEAPON, _plain(GREAT))
	_check(gear.worn.size() == 1, "a greatsword worn is one piece on the player, not two")
	var totals := gear.totals()
	for stat: String in LootTable.stats_of("Wooden Shield"):
		_check(not totals.has(stat), "the shield's %s is off the set under a greatsword" % stat)

	# Two coming off for one going on, so the bag has to have a square spare -- and refusing leaves
	# everything exactly where it was, rather than destroying a piece to make room.
	var tight := Inventory.new()
	var blade := _plain("Wooden Sword")
	var guard := _plain("Wooden Shield")
	tight.equipment.equip(Equipment.Socket.WEAPON, blade)
	tight.equipment.equip(Equipment.Socket.OFFHAND, guard)
	var heavy := _plain(GREAT)
	tight.add(heavy)
	while not tight.is_full():
		tight.add(_plain("Leather Boot"))
	_check(not tight.can_equip(heavy, Equipment.Socket.WEAPON), "a full bag has nowhere to put the two")
	_check(not tight.equip(heavy, Equipment.Socket.WEAPON), "so the swap is refused")
	_check(tight.total() == Inventory.CAPACITY and tight.items.has(heavy),
			"and the greatsword is still in the bag")
	_check(tight.equipment.item_at(Equipment.Socket.WEAPON) == blade
			and tight.equipment.item_at(Equipment.Socket.OFFHAND) == guard,
			"with both hands as they were")
	tight.remove(tight.items[tight.total() - 1])
	_check(tight.equip(heavy, Equipment.Socket.WEAPON), "one square free is room enough")
	_check(tight.total() == Inventory.CAPACITY and tight.items.has(blade) and tight.items.has(guard),
			"and the bag comes back exactly full")

	# A one-handed swap is still one for one, so a full bag is no obstacle to it at all.
	var packed := Inventory.new()
	var spare := _plain("Wooden Sword")
	packed.add(spare)
	while not packed.is_full():
		packed.add(_plain("Leather Boot"))
	packed.equipment.equip(Equipment.Socket.WEAPON, _plain("Wooden Sword"))
	_check(packed.equip(spare, Equipment.Socket.WEAPON), "a one-handed swap needs no free square")
	_check(packed.total() == Inventory.CAPACITY, "and leaves the bag as full as it was")

	# A save holding both is a save that has drifted. The weapon is what the player chose.
	var drifted := Equipment.from_dict({
		"weapon": _plain(GREAT).to_dict(),
		"offhand": _plain("Wooden Shield").to_dict(),
	})
	_check(drifted.item_at(Equipment.Socket.WEAPON) != null, "a saved greatsword comes back on")
	_check(drifted.item_at(Equipment.Socket.OFFHAND) == null,
			"and the offhand saved beside it is dropped")

	# The comparison, checked against the only thing it can honestly mean: what the set is worth after
	# the swap, less what it was worth before. Both directions, because neither is one for one.
	_swap_reads_true([["Wooden Sword", Equipment.Socket.WEAPON],
			["Wooden Shield", Equipment.Socket.OFFHAND]], GREAT, Equipment.Socket.WEAPON,
			"a greatsword over a sword and a shield")
	_swap_reads_true([[GREAT, Equipment.Socket.WEAPON]], "Wooden Shield", Equipment.Socket.OFFHAND,
			"a shield over a greatsword")
	return true


## What `ItemDetails.deltas` says one swap is worth, against what `Equipment.totals` actually comes to
## before and after making it. `worn` is [type, socket] pairs. Plain pieces on both sides, so the set's
## GLOBAL percents -- which a delta knows nothing about -- have nothing to say either way.
func _swap_reads_true(worn: Array, type: String, socket: Equipment.Socket, what: String) -> void:
	var gear := Equipment.new()
	for pair: Array in worn:
		gear.equip(pair[1], _plain(pair[0]))
	var judged := _plain(type)
	var change := ItemDetails.deltas(judged, gear.displaced_by(socket, judged))
	var before := gear.totals()
	gear.equip(socket, judged)
	var after := gear.totals()
	for stat: String in change:
		var moved: float = float(after.get(stat, 0.0)) - float(before.get(stat, 0.0))
		_check(is_equal_approx(float(change[stat]), moved),
				"%s: %s reads %s and the player moved %s" % [what, stat, change[stat], moved])
	# And nothing the swap really moved is left off the page.
	for stat: String in before.keys() + after.keys():
		var moved: float = float(after.get(stat, 0.0)) - float(before.get(stat, 0.0))
		if LootTable.delta_shows(stat, moved):
			_check(change.has(stat), "%s: %s moved by %s and the page said nothing" % [what, stat, moved])


## A piece of one kind at one level with nothing rolled on top: the table's own numbers, which is
## what lets what a swap is worth be checked against what the set adds up to.
func _plain(type: String, level := 1) -> Item:
	var item := Item.new()
	item.type = type
	item.rarity = ItemRarity.Rarity.COMMON
	item.level = level
	item.stats = Item.scaled_stats(type, level)
	return item


## The stats that belong to one kind of piece and must stay there. Offence on the weapons is the rule
## the whole table is built on -- damage anywhere else and what is held stops being the interesting
## slot -- and the rest are locked by what the piece is: you walk in boots, you block with a thing you
## hold, only a mace leaves a wound and only a torch lights the way. Said by kind rather than by name,
## because a kind's four materials are one piece with four prices on it. Pinned here so a later
## widening of the tables cannot quietly undo the design.
func _test_slot_locks() -> bool:
	# The kinds allowed the stat at all, base stat or affix.
	var locked := {
		# Base damage is still what is held, but the jewellery carries damage as an affix -- what is
		# locked is where a click's damage *comes from*, not everything that can add to it.
		"damage": ["sword", "dagger", "mace", "greatsword", "broken_sword", "gold_ring", "iron_band", "jade_ring",
			"opal_ring", "pearl_ring",
			"ruby_amulet", "gold_amulet", "emerald_amulet"],
		"move_speed": ["boot", "greaves"],
		"block": ["shield", "buckler", "torch", "broken_torch"],
		"bleed": ["mace"],
		"sight": ["torch", "broken_torch"],
	}
	# And the kinds whose own numbers it is, which for four of them is narrower than the line above:
	# a ring may roll flat damage and a torch may roll flat block, and neither shows any.
	var shows := {
		"damage": ["sword", "dagger", "mace", "greatsword", "broken_sword"],
		"move_speed": ["boot", "greaves"],
		"block": ["shield", "buckler"],
		"bleed": ["mace"],
		"sight": ["torch", "broken_torch"],
	}
	for stat: String in locked:
		var carries := {}
		var wears := {}
		for item in LootTable.items():
			var kind := str(LootTable.ITEMS[item]["kind"])
			if LootTable.can_roll(item, stat):
				carries[kind] = true
			if LootTable.has_stat(item, stat):
				wears[kind] = true
		for pair: Array in [[carries, locked[stat], "carry"], [wears, shows[stat], "show"]]:
			var found: Array = (pair[0] as Dictionary).keys()
			var want: Array = pair[1]
			_check(found.size() == want.size(),
					"the kinds that %s %s are %s, not %s" % [pair[2], stat, found, want])
			for kind: String in want:
				_check(kind in found, "%s should %s %s" % [kind, pair[2], stat])
	# The torch is Sight and nothing else: what it used to show it merely carries now.
	_check(LootTable.stats_of("Wooden Torch").keys() == ["sight"],
			"a torch shows Sight alone (%s)" % [LootTable.stats_of("Wooden Torch").keys()])
	return true


## The two tables have to cover every enemy in the roster, or a kill would crash looking itself up.
## This is what stops a new enemy being added with a size or tier the loot table has never heard of.
func _test_chances() -> bool:
	for name in EnemyRoster.names():
		var chance := LootTable.chance_for(name)
		_check(chance > 0.0 and chance <= 1.0, "%s drops with a real chance, not %f" % [name, chance])
	# What the player is wearing lifts it, and the ceiling still holds: +100% drop rate is twice as
	# much gear, and no amount of it makes a body drop more often than always.
	for name in EnemyRoster.names():
		var plain := LootTable.chance_for(name)
		var doubled := LootTable.chance_for(name, 100.0)
		_check(is_equal_approx(doubled, minf(plain * 2.0, 1.0)),
				"%s drops twice as often at +100%% drop rate" % name)
		_check(doubled <= 1.0, "%s cannot drop more often than always" % name)
		_check(is_equal_approx(LootTable.chance_for(name, 0.0), plain), "and nothing is nothing")
	_check(is_equal_approx(LootTable.chance_for("Grass Slime", 900.0),
			minf(LootTable.chance_for("Grass Slime") * 10.0, 1.0)), "a pile of it still stops at 1")

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
			if step == ItemRarity.Rarity.UNIQUE:
				continue
			_check(row.has(step), "tier %d has a weight for rarity %d" % [tier, step])
			total += int(row[step])
		_check(total > 0, "tier %d can roll something" % tier)
		# Uniques are `UniqueTable.roll`'s, beside the gear: a weight here would be a second way in.
		_check(not row.has(ItemRarity.Rarity.UNIQUE), "tier %d cannot roll a unique" % tier)

	# Better enemies carry better things: as the tier rises the weight moves up the ramp. Said as
	# the average step rather than band by band, because the middle of a ramp does not have to
	# climb -- an uncommon is a good drop off a rat and a disappointment off a boss, so its mass is
	# meant to rise and then move on to rare. Only the ends are one-directional: the plain step
	# falls the whole way and the top two climb the whole way.
	var tiers := [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]
	for i in tiers.size() - 1:
		var low: Dictionary = ItemRarity.TIER_WEIGHTS[tiers[i]]
		var high: Dictionary = ItemRarity.TIER_WEIGHTS[tiers[i + 1]]
		_check(int(low[ItemRarity.Rarity.COMMON]) > int(high[ItemRarity.Rarity.COMMON]),
				"a tier %d body drops more plain gear than a tier %d one" % [i, i + 1])
		for step: ItemRarity.Rarity in [ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
			_check(int(low[step]) < int(high[step]),
					"a tier %d body drops fewer of rarity %d than a tier %d one" % [i, step, i + 1])
		_check(_mean_step(tiers[i]) < _mean_step(tiers[i + 1]),
				"a tier %d body carries better things than a tier %d one: %.2f against %.2f"
						% [i, i + 1, _mean_step(tiers[i]), _mean_step(tiers[i + 1])])
	return true


## How good a tier's drops are on average, as a position on the rarity ramp: 0 if it only ever
## dropped plain gear, 3 if every piece were elite. The one number that says "better enemies
## carry better things" without caring which band the weight is sitting in.
func _mean_step(tier: EnemyRoster.Tier) -> float:
	var row: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
	var total := 0
	var sum := 0
	for step: ItemRarity.Rarity in row:
		total += int(row[step])
		sum += int(row[step]) * int(step)
	return float(sum) / maxi(total, 1)


## How far a measured share may sit from the share behind it before it means something. Three
## standard errors, so a band's own thinness sets its own margin: a step worth 45% of drops scatters
## far more in absolute terms than one worth 1.5%, and holding both to one flat number either lets
## the thin one drift unnoticed or fails the fat one on nothing. The floor is for a weight of zero,
## where the error is zero and the count still has to be exactly right.
func _tolerance(want: float, samples: int) -> float:
	return maxf(3.0 * sqrt(want * (1.0 - want) / samples), 0.002)


## What share of a tier's drops one rarity step is worth, straight off the table. Every share a
## test holds a roll to comes from here, so retuning the curve retunes what is expected of it
## rather than leaving a number written in a test to go quietly stale.
func _rarity_share(tier: EnemyRoster.Tier, step: ItemRarity.Rarity) -> float:
	var row: Dictionary = ItemRarity.TIER_WEIGHTS[tier]
	var total := 0
	for weight: int in row.values():
		total += weight
	return float(int(row[step])) / maxi(total, 1)


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
		var stat: String = mod["stat"]
		_check(LootTable.STAT_LABELS.has(stat), "%s names %s, which has no label" % [id, stat])
		# A modifier for a stat nothing carries could never be rolled: dead weight in the table. A
		# PERCENT one needs a piece with the base stat; a FLAT one only needs one allowed to carry it.
		var carried := false
		for item in LootTable.items():
			match mod["kind"]:
				ModifierTable.Kind.PERCENT:
					carried = carried or LootTable.has_stat(item, stat)
				ModifierTable.Kind.GLOBAL:
					carried = carried or LootTable.can_globalize(item, stat)
				_:
					carried = carried or LootTable.can_roll(item, stat)
		# Unless it is one of the ones held back on purpose, which have to be named rather than
		# inferred: a modifier nothing can roll is dead weight, and a dormant one is a system waiting.
		var held_back: bool = id in ModifierTable.DORMANT or id in ModifierTable.UNIQUE_ONLY
		_check(carried or held_back, "%s names %s, which no item can roll" % [id, stat])
		_check(not (carried and held_back), "%s is listed as held back and can be rolled" % id)
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

	# How often anything falls at all. The empty rolls are the whole point of this loop, so it is
	# the one place that goes through the chance gate.
	var dropped := 0
	for i in ROLLS:
		if LootTable.roll(enemy, rng) != null:
			dropped += 1
	var rate := float(dropped) / ROLLS
	var chance := LootTable.chance_for(enemy)
	_check(absf(rate - chance) < 0.01, "%s dropped at %.3f, not its %.3f" % [enemy, rate, chance])

	# And what one looks like when it lands. Every roll here is guaranteed, so every roll counts
	# towards the answer instead of 97 in 100 being thrown away by a gate this loop is not
	# measuring -- which is both quicker and enough samples for the thin steps to mean anything.
	var mix := {}
	var rarities := {}
	for i in SHAPE_ROLLS:
		var item := LootTable.roll(enemy, rng, true)
		_check(item != null, "a guaranteed roll always drops something")
		if item == null:
			break
		_check(item.type in LootTable.items(), "rolled a real item, not " + item.type)
		# A weight belongs to a kind, so what is measured against it is how often the kind came up.
		# This tile is level 1, where only the plainest material of each is unlocked at all.
		_check(int(LootTable.ITEMS[item.type]["tier"]) == 0,
				"a level-1 drop is the plainest of its kind, not " + item.type)
		mix[LootTable.ITEMS[item.type]["kind"]] = int(mix.get(LootTable.ITEMS[item.type]["kind"], 0)) + 1
		rarities[item.rarity] = int(rarities.get(item.rarity, 0)) + 1

	var total_weight := 0
	for kind: String in LootTable.KINDS:
		total_weight += int(LootTable.KINDS[kind]["weight"])
	for kind: String in LootTable.KINDS:
		var share := float(mix.get(kind, 0)) / SHAPE_ROLLS
		var want := float(LootTable.KINDS[kind]["weight"]) / total_weight
		_check(absf(share - want) < _tolerance(want, SHAPE_ROLLS),
				"%s came up %.3f of the time, not %.3f" % [kind, share, want])

	# Deep ground deals better materials, and never one the piece's own level has not unlocked -- the
	# level is the piece's, so a poor roll out at the frontier is still a wooden sword.
	var tiers := {}
	for i in SHAPE_ROLLS:
		var item := LootTable.roll(enemy, rng, true, 30)
		var row: Dictionary = LootTable.ITEMS[item.type]
		var levels: Array = LootTable.KINDS[row["kind"]].get("tier_levels", LootTable.TIER_MIN_LEVEL)
		_check(item.level >= int(levels[int(row["tier"])]),
				"a level-%d %s is under the level %d its material needs"
						% [item.level, item.type, levels[row["tier"]]])
		tiers[int(row["tier"])] = true
	_check(tiers.has(LootTable.TIER_MIN_LEVEL.size() - 1),
			"deep ground deals the best materials (%s)" % [tiers.keys()])
	_check(tiers.has(0), "and its shallower rolls still deal the plainest")

	# The circles hold the materials to their walls, whatever the level: a ring's circle, and a boss
	# on the last ring inside a wall -- two levels over its tile -- never dealing the next circle's.
	for ring: Array in [[0, 1], [10, 1], [11, 2], [20, 2], [21, 3], [31, 4]]:
		_check(MapBuilder.circle_of(Vector2i(int(ring[0]), 0)) == int(ring[1]),
				"ring %d is circle %d (%d)" % [ring[0], ring[1], MapBuilder.circle_of(Vector2i(int(ring[0]), 0))])
	var boss := ""
	for body: String in EnemyRoster.ENEMIES:
		if EnemyRoster.tier_of(body) == EnemyRoster.Tier.BOSS:
			boss = body
			break
	# The circle's last tile level, the one the next circle's first ring shares.
	var best := [0, 0, 0]
	for circle: int in [1, 2, 3]:
		var edge := MapBuilder.level_of(Vector2i(MapBuilder.START_LAND_RADIUS + (circle - 1) * MapBuilder.WALL_STEP, 0))
		for i in 1000:
			var piece := LootTable.roll(boss, rng, true, edge, 0.0, 0.0, circle)
			best[circle - 1] = maxi(best[circle - 1], int(LootTable.ITEMS[piece.type]["tier"]))
	_check(best == [1, 3, 4], "the best material inside each wall is the second, the fourth, the masterwork (%s)" % [best])
	var blazing := 0
	for i in 1000:
		blazing += 1 if LootTable.roll(boss, rng, true, 5, 0.0, 0.0, 1).type == "Blazing Torch" else 0
	_check(blazing == 0, "no Blazing Torch inside the first wall (%d of 1000)" % blazing)

	# The run's first find: a fight told to drop a sword drops one, once, and then goes back to the table.
	for attempt in 20:
		var first := Encounter.for_tile(Vector2i(2, 2), "grass")
		first.loot_rng.seed = attempt
		first.always_drop = true
		first.first_sword = true
		var found: Array[Item] = []
		first.loot_dropped.connect(func(_index: int, item: Item) -> void: found.append(item))
		_play(first)
		_check(found.size() > 1 and found[0].type == LootTable.FIRST_DROP,
				"the first drop is a Broken Sword, not %s" % (found[0].type if found else "nothing"))
		if found:
			_check(found[0].stats == {"damage": 1.0} and found[0].level == 1
					and found[0].rarity == ItemRarity.Rarity.COMMON,
					"and it is a common level 1 with 1 Damage and nothing else (%s)" % [found[0].stats])
			var some_orb_fits := false
			for orb: String in OrbTable.ORBS:
				some_orb_fits = some_orb_fits or OrbTable.can_apply(orb, found[0])
			_check(some_orb_fits, "and an orb still works on it")
		_check(not first.first_sword, "and the promise is spent")
	var kinds := {}
	for attempt in 20:
		var fight := Encounter.for_tile(Vector2i(2, 2), "grass")
		fight.loot_rng.seed = attempt
		fight.always_drop = true
		fight.first_sword = true
		fight.loot_dropped.connect(func(index: int, item: Item) -> void:
			if index > 0:
				kinds[LootTable.ITEMS[item.type]["kind"]] = true)
		_play(fight)
	_check(kinds.size() > 1, "and the drops after it go back to the table")

	# What common rabble is worth, every step of it, held to the table's own numbers rather than to
	# a line written here that goes stale the moment the curve is retuned.
	for step: ItemRarity.Rarity in ItemRarity.TIER_WEIGHTS[EnemyRoster.Tier.COMMON]:
		var share := float(rarities.get(step, 0)) / SHAPE_ROLLS
		var want := _rarity_share(EnemyRoster.Tier.COMMON, step)
		_check(absf(share - want) < _tolerance(want, SHAPE_ROLLS),
				"common rabble dropped rarity %d %.3f of the time, not the table's %.3f"
						% [step, share, want])
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


## A find rolls again: a body that beat the chance leaves a second piece now and then, and never more
## than `Encounter.MOST_DROPS`. A certain drop rolls nothing after it.
func _test_drops_cascade() -> bool:
	# Drop rate enough to pin `chance_for` at its ceiling, where every follow-up lands: every body
	# leaves exactly the cap, which is also what proves the chain ends at all.
	var counts := _drops_per_body(1.0e6, false)
	_check(counts.size() == Encounter.ENEMIES, "every body left something (%d of %d)"
			% [counts.size(), Encounter.ENEMIES])
	var capped := true
	for index: int in counts:
		capped = capped and int(counts[index]) == Encounter.MOST_DROPS
	_check(capped, "a certain chance leaves exactly %d pieces a body (%s)"
			% [Encounter.MOST_DROPS, counts])

	# And a middling one: some bodies leave one piece, some two or more, none more than the cap.
	var many := {}
	for attempt in 20:
		for count: int in _drops_per_body(1500.0, false, attempt).values():
			many[count] = int(many.get(count, 0)) + 1
	_check(many.has(1) and many.has(2), "a find rolls again (%s)" % [many])
	var over := 0
	for count: int in many:
		over += int(many[count]) if count > Encounter.MOST_DROPS else 0
	_check(over == 0, "and never past the cap (%s)" % [many])

	# A promised drop is one piece: it beat nothing, so nothing follows it.
	var promised := _drops_per_body(0.0, true)
	var singles := true
	for index: int in promised:
		singles = singles and int(promised[index]) == 1
	_check(singles, "a guaranteed drop rolls nothing after it (%s)" % [promised])
	return true


## How many pieces each body of one seeded tile fight left, by the slot it stood in.
func _drops_per_body(drop_rate: float, certain: bool, seed_value := WORLD_SEED) -> Dictionary:
	var fight := Encounter.for_tile(Vector2i(2, 2), "grass")
	fight.loot_rng.seed = seed_value
	fight.always_drop = certain
	fight.arm({"damage": 1.0e9, "drop_rate": drop_rate})
	var counts := {}
	fight.loot_dropped.connect(func(index: int, _item: Item) -> void:
		counts[index] = int(counts.get(index, 0)) + 1)
	_play(fight)
	return counts


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
	file.store_string('{"version": 1, "first_elite_taken": true, "counts": {"Rusty Spoon": 5, "Leather Boot": 2}}')
	file.close()
	var migrated := Inventory.load_from(TEST_PATH)
	_check(migrated.total() == 2, "an old save's items came across, %d of them" % migrated.total())
	_check(migrated.count("Leather Boot") == 2, "as what they were")
	_check(migrated.first_sword_taken, "and a save from before the Broken Sword never gets one")
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
	_check(not main._character_button.visible, "while the page covers the character panel's corner")
	main.inventory.tips.append("level_up")
	main._show_corner(true)
	_check(is_equal_approx(main._skills_button.position.x, main._bag_button.position.x)
			and main._skills_button.position.y > main._bag_button.position.y, "the buttons are a column")
	main._on_skills_pressed()
	_check(main.skills_page.visible and not main.bag_page.visible, "and one press goes from page to page")
	_check(main._bag_button.position.x >= main.skills_page.get_child(0).size.x * main.ui_scale,
			"the column standing beside that one now")
	main._on_skills_pressed()
	_check(not main.skills_page.visible and main._character_button.visible, "a page's own button puts it away")
	main.inventory.tips.erase("level_up")
	main.inventory.tips.erase("opened_skills")
	main._on_bag_pressed()
	_check(main.bag_page._panel.position.x == UITheme.EDGE * main.ui_scale,
			"and stands EDGE off the left edge")
	_check(not main.bag_page._actions.visible, "with no buttons until a square is clicked")
	main._on_left_page_closed()
	_check(not main.bag_page.visible and main._bag_button.visible, "closing it gives the button back")

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
	main._on_left_page_closed()

	# A first fight, whose elite is promised a drop.
	var target := HexGrid.neighbor(MapBuilder.CENTER, HexGrid.Edge.E)
	main.map.select_cell(target)
	main._on_chart_pressed()
	main.map.player.finish_walk()
	_check(not main._bag_button.visible, "the button is out of the way of the fight")
	var fight: Encounter = main._combat.fight
	_check(fight.guarantee_elite, "the first elite is promised a drop")
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
	_check("%s · level %d" % [dropped.rarity_name(), dropped.level] in lines,
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
	_check(main.inventory.total() > 0, "the promised elite paid out")
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
	_press(main, on_first, true)
	_drag(main, on_first, BagPage.DRAG_THRESHOLD * 4.0)
	_press(main, on_first, false)
	await process_frame
	_check(not main.bag_page._actions.visible, "a press that travels is a drag, and opens nothing")

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
			# "Level 9 auto" while the rule is on: the heading says the rule in a word, because the
			# toggle's pressed face is far too quiet to read a state off.
			if label is Label and (label as Label).text == "Level 9 auto":
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
		_check(not main._combat.fight.guarantee_elite, "the second fight promises nothing")
		main._combat.fight.give_up()
		main._combat._on_back_pressed()
		await process_frame
	main.queue_free()
	return true


## A farm run's finds wait in the pouch and go into the bag in one write when the run ends. It is
## the one place the game holds loot back, and the reason is that a run has no end of its own: a
## charting fight is over in a minute and writes each find as it lands, and a run could go an hour.
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
	_check(not main._bag_button.visible, "and the bag out of the way, as in any fight")
	fight.loot_rng.seed = WORLD_SEED
	# Every body carries something, so three finds is three kills. What is under test is where a
	# run's finds wait, not how often one falls -- at the real 3% this would be a hundred-odd kills.
	fight.always_drop = true

	var guard := 0
	while main.ledger.drops.size() < 3 and guard < 2000:
		guard += 1
		if not fight.hit():
			fight.advance(1.0 / 8.0)
	_check(main.ledger.drops.size() >= 3, "a run long enough turns up several things: %d"
			% main.ledger.drops.size())
	_check(not fight.finished, "and it is still going")
	_check(main.inventory.total() == 0, "none of which is in the bag yet: %d" % main.inventory.total())
	_check(not FileAccess.file_exists(TEST_PATH), "and nothing has been written to disk")
	# The gold waits with them, and for the same reason: a run has no end of its own to write at.
	_check(main.ledger.gold > 0, "the run has earned something: %d" % main.ledger.gold)
	_check(main.ledger.gold == fight.gold, "and the fight agrees what: %d" % fight.gold)
	_check(main.inventory.gold == 0, "none of it in the purse yet: %d" % main.inventory.gold)
	_check(combat._loot_button.text == str(main.ledger.drops.size()),
			"the counter has been keeping score all along")

	# The counter opens the same list the verdict shows, and one of them opens properly.
	combat._on_loot_pressed()
	await process_frame
	_check(combat._loot_panel.visible, "the counter opens the popup")
	_check(combat._loot_drops.count() == main.ledger.drops.size(), "holding every find")
	var found: Item = main.ledger.drops[0]
	combat._loot_drops.inspect(0)
	await process_frame
	_check(combat._loot_drops.inspecting(), "and a square in it opens the item")
	var lines := PackedStringArray()
	for line: Node in _labels_under(combat._loot_drops):
		lines.append((line as Label).text)
	_check(found.display_name() in lines, "which names it")
	_check("%s · level %d" % [found.rarity_name(), found.level] in lines,
			"and its rarity and level")
	# Throwing one away from the popup, which is the promised way out of a run that has found more
	# than the bag can hold. The run is still holding its pouch, so this is the whole of it.
	var before: int = main.ledger.drops.size()
	var doomed: Item = main.ledger.drops[0]
	combat._loot_drops.inspect(0)
	combat._loot_drops._on_discard_pressed()
	await process_frame
	_check(not main.ledger.drops.has(doomed), "Discard takes a find out of the run's pouch")
	_check(main.ledger.drops.size() == before - 1, "and only that one")
	_check(combat._drops.size() == main.ledger.drops.size(), "the fight agrees about what is left")
	_check(combat._loot_button.text == str(main.ledger.drops.size()), "and so does the counter")
	_check(main.inventory.total() == 0, "nothing was in the bag to take it out of")

	combat._on_loot_closed()
	await process_frame
	_check(not combat._loot_panel.visible, "and Close puts it away")

	# Terminating is the end of the run, and the moment the pouch goes into the bag.
	var pouch: Array[Item] = main.ledger.drops.duplicate()
	var earned: float = main.ledger.gold
	combat._on_terminate_pressed()
	await process_frame
	_check(fight.finished and fight.victory, "terminating ends the run, and not as a loss")
	main._combat._on_back_pressed()
	await process_frame
	_check(main.inventory.total() == pouch.size(),
			"every find the run made went into the bag at once: %d of %d"
					% [main.inventory.total(), pouch.size()])
	for i in mini(main.inventory.total(), pouch.size()):
		_check(_fingerprint(main.inventory.items[i]) == _fingerprint(pouch[i]),
				"and it is the same item %d, modifiers and all" % i)
	_check(main.inventory.gold == earned,
			"and so did its gold, in one go: %d of %d" % [main.inventory.gold, earned])
	_check(main.ledger.gold == 0, "leaving the pouch empty, so the next run starts from nothing")
	_check(main.bag_page._gold.text == BigNumber.format(earned),
			"the bag's footer says so: %s" % main.bag_page._gold.text)
	var saved := Inventory.load_from(TEST_PATH)
	_check(saved.total() == pouch.size(), "the file on disk holds them too")
	_check(saved.gold == earned, "and the gold with them: %d of %d" % [saved.gold, earned])

	# Nothing about the map moved. A run is fought on a tile that is already the player's.
	_check(main.view.charted(here), "the tile stays the player's")
	_check(not main.view.charted(next_door), "and the run charted nothing")
	_check(main._bag_button.visible, "the bag is back with the map")
	main.queue_free()
	return true


## A level the player is done with never reaches them: not the pouch, not the counter, not either
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
	_check(main._farm_button.tooltip_text == main.ENCUMBERED_TIP, "and the button says why")
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
	# Which is said by the counter's own face and nowhere else until it is opened: the warning is a
	# line inside its panel now, not a sign standing in the arena.
	combat._refresh()
	_check(not combat._warning.is_visible_in_tree(), "the warning stays inside the counter's panel")
	_check(combat._loot_filled == 1.0, "and the counter's face is at the red end of its ramp")
	combat._on_loot_pressed()
	_check(combat._warning.visible, "opening the counter is what says why")
	combat._on_loot_closed()

	var guard := 0
	while combat._auto_discarded < 3 and guard < 2000:
		guard += 1
		if not fight.hit():
			fight.advance(1.0 / 8.0)
	_check(combat._auto_discarded >= 3, "the rule threw several away: %d" % combat._auto_discarded)
	# None of them touched anything the player can see.
	_check(main.ledger.drops.is_empty(), "none of them reached the pouch")
	_check(combat._drops.is_empty(), "or the fight's own list")
	_check(combat._loot_button.text == "0" and combat._loot_button.disabled,
			"the counter never moved")
	_check(combat._loot_drops.count() == 0 and combat._result_drops.count() == 0,
			"and neither list has a square in it")
	_check(combat._finds_shown == orbs.size(),
			"nothing but the orbs was thrown into the arena (%d against %d)"
			% [combat._finds_shown, orbs.size()])
	_check(main.inventory.total() == Inventory.CAPACITY, "and the bag is exactly as it was")
	# The rule is about finds. A purse is a number rather than a square, so nothing filters it and a
	# run that kept nothing still earned its way.
	_check(main.ledger.gold > 0, "the gold came all the same: %d" % main.ledger.gold)

	# Said once, at the end, as a number.
	var thrown := combat._auto_discarded
	combat._on_terminate_pressed()
	await process_frame
	await process_frame
	_check(combat._auto_label.visible, "the verdict says what the rule threw away")
	_check(combat._auto_label.text == "%d finds discarded automatically" % thrown,
			"as a count and nothing more: %s" % combat._auto_label.text)
	main._combat._on_back_pressed()
	await process_frame
	_check(main.inventory.total() == Inventory.CAPACITY, "the run banked nothing, because it kept nothing")
	_check(main.inventory.gold > 0, "but it banked its gold: %d" % main.inventory.gold)
	main.queue_free()
	return true


## Presses the first level heading's bin, found by its tooltip as the mark has no words.
func _press_bin(main: Node) -> void:
	for button: Button in main.bag_page._sections.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with("Throw away the") and not button.disabled:
			button.pressed.emit()
			return


## A button of the question standing over the bag, by its words.
func _confirm_button(main: Node, text: String) -> Button:
	for button: Button in main.bag_page._confirm.find_children("", "Button", true, false):
		if button.text == text:
			return button
	return null


## Everything the question standing over the bag says, in one string.
func _confirm_text(main: Node) -> String:
	var said := PackedStringArray()
	for label: Label in main.bag_page._confirm.find_children("", "Label", true, false):
		said.append(label.text)
	return " ".join(said)


## Every square the bag is showing, in the order the sections lay them out. The grid is no longer one
## rectangle, so a test asking what the bag holds has to walk the sections the way the click does.
## `main` is anything with a `bag_page`: the scene, or a Dictionary standing in for one.
func _bag_squares(main) -> Array:
	var squares := []
	for section: Node in main.bag_page._sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Node in section.get_children():
			squares.append(slot)
	return squares


## Shift and Ctrl on a click: the square's own button pressed for it -- Equip or Unequip, Discard --
## and the keys a square says it answers to, for the card's foot.
func _test_key_clicks() -> bool:
	var inventory := Inventory.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 4)
	var boot := Item.rolled("Leather Boot", ItemRarity.Rarity.RARE, rng, 4)
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
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.shift_pressed = true
	press.position = worn[0].position + worn[0].size / 2.0
	page._on_doll_input(press)
	await process_frame
	_check(inventory.equipment.item_at(Equipment.Socket.WEAPON) == null and sword in inventory.items,
			"a Shift-click on the doll takes the piece off")
	# With the bag full, Unequip is grey: the click opens the socket and moves nothing.
	page._on_clicked(_square_spot(_bag_squares(main).filter(
			func(s: ItemSlot) -> bool: return s.item == sword)[0]), true, false)
	await process_frame
	while not inventory.is_full():
		inventory.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 1))
	page.refresh()
	await process_frame
	worn = _socket_squares(main).filter(func(s: Control) -> bool:
			return s.get_meta("socket") == Equipment.Socket.WEAPON)
	press.position = worn[0].position + worn[0].size / 2.0
	page._on_doll_input(press)
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


## Every socket square on the doll, or nothing at all while the doll is folded away. It is
## the same list `_on_doll_input` hit-tests against, and whether it is empty is how a test tells the
## page's two states apart.
func _socket_squares(main) -> Array:
	var squares := []
	if main.bag_page._doll == null:
		return squares
	for slot: Node in main.bag_page._doll.get_children():
		if slot.has_meta("socket"):
			squares.append(slot)
	return squares


## Every line of text on a node and everything under it, which is how a test reads a stat block
## whose lines are nested in columns rather than laid flat.
func _texts(node: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if node is Label:
		out.append((node as Label).text)
	for child: Node in node.get_children():
		out.append_array(_texts(child))
	return out


## The middle of a square in the sections' own space -- which is the space `_on_bag_clicked` works
## in. A square's own position is its grid's, so its section has to be added back on.
func _square_spot(slot: Control) -> Vector2:
	return (slot.get_parent() as Control).position + slot.position + slot.size / 2.0


## The heirlooms: the second stash and doll, how a piece gets there, what the two dolls add up to,
## which uniques count which side, what is left when the world is, and the page they are kept on.
func _test_heirlooms() -> bool:
	_clear_save()
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var wear := func(side: Inventory, piece: Item) -> void:
		side.items.append(piece)
		_check(side.equip(piece, side.equipment.sockets_for(piece)[0]), "%s goes on" % piece.display_name())
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
	_check(Item.from_dict(sword.to_dict()).safe_level == 12 and not _piece(ItemRarity.Rarity.COMMON, 1).to_dict().has("safe_level"),
			"it is saved with the piece, and only where there is one")

	# Super orbs: a wall pays once.
	var bag := Inventory.new()
	_check(not bag.credit_walls(0) and bag.super_orbs == 0, "no wall, no orb")
	_check(bag.credit_walls(2) and bag.super_orbs == 2, "two walls down is two orbs, as an old save finds")
	_check(not bag.credit_walls(2) and bag.super_orbs == 2, "asked again, nothing more")
	_check(bag.credit_walls(3) and bag.super_orbs == 3, "and the next wall pays one")

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
	_check(bag.super_orbs == 3 and worn.level == 9, "no orb is spent on it, and nothing about the piece has moved")

	# The save, and a file from before there were heirlooms.
	_check(bag.stash().equip(worn, Equipment.Socket.WEAPON), "an heirloom goes on the heirlooms' doll")
	bag.super_orbs = 4
	_check(bag.save(TEST_PATH), "it saves")
	var back := Inventory.load_from(TEST_PATH)
	_check(back.stash().total() == 1 and back.stash().items[0].level == 7
			and back.stash().items[0].rarity == ItemRarity.Rarity.RARE, "the stash comes back")
	_check(back.stash().equipment.items().size() == 1 and back.stash().equipment.items()[0].level == 9,
			"and so does the heirlooms' doll")
	_check(back.super_orbs == 4 and back.walls_credited == 3, "with the orbs and the walls paid for")
	var old := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	old.store_string(JSON.stringify({"version": 13, "items": [], "gold": 5}))
	old.close()
	var before := Inventory.load_from(TEST_PATH)
	_check(before.stash().total() == 0 and before.super_orbs == 0 and before.walls_credited == 0,
			"a version 13 save has none, and no wall paid for")

	# Two dolls. Flats add; each doll's global percents are a multiplier of their own.
	var both := Inventory.new()
	wear.call(both, _piece(ItemRarity.Rarity.COMMON, 5))
	var one_sword: float = both.stats()["damage"]
	wear.call(both.stash(), _piece(ItemRarity.Rarity.COMMON, 5))
	_check(is_equal_approx(both.stats()["damage"], one_sword * 2.0), "a sword on each doll is both swords")
	wear.call(both, ring_of.call(20))
	wear.call(both.stash(), ring_of.call(20))
	_check(is_equal_approx(both.stats()["damage"], one_sword * 2.0 * 1.2 * 1.2),
			"20%% on each doll is x1.44 (%s)" % both.stats()["damage"])
	var one_doll := Inventory.new()
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
	var spiked := Inventory.new()
	wear.call(spiked, _piece(ItemRarity.Rarity.COMMON, 5))
	var bare_damage: float = spiked.stats()["damage"]
	var helm := Item.rolled_unique("spiked_helm", rng, 5)
	helm.stats["armor"] = 0.0
	helm.mods.clear()
	wear.call(spiked.stash(), helm)
	var plate := Item.new()
	plate.type = "Wooden Armor"
	plate.stats = {"armor": 1000.0}
	wear.call(spiked, plate)
	_check(is_equal_approx(spiked.stats()["damage"], bare_damage + 1000.0 * Inventory.SPIKES_SHARE),
			"the helm among the heirlooms reads the ordinary doll's armour (%s)" % spiked.stats()["damage"])

	# A set is made inside one doll, and the sack pays from either.
	var split := Inventory.new()
	wear.call(split, Item.rolled_unique("meadowstriders", rng, 1))
	wear.call(split.stash(), Item.rolled_unique("rimeplate", rng, 1))
	_check(split.effects().size() == 4 and not ("grazing:ice" in split.effects()),
			"a home piece on each doll is two lone pieces (%s)" % [split.effects()])
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
	leaving.super_orbs = 2
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
			and next.first_sword_taken and next.super_orbs == 2, "what the player knows goes along")
	_check(next.stash().total() == 1 and next.stash().items[0].level == 1 and next.stash().items[0].safe_level == 15,
			"the stash goes along, at level 1")
	var still_on: Item = next.stash().equipment.items()[0]
	_check(still_on.level == 1 and still_on.safe_level == 18, "and the heirlooms' doll stays dressed")
	_check(held.level == 15 and on_doll.level == 18, "the inventory that was left is untouched, should the write fail")

	# A version 14 save's unspent picks are orbs now.
	leaving.save(TEST_PATH)
	var old_save: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	old_save["heirloom_picks"] = old_save["super_orbs"]
	old_save.erase("super_orbs")
	old_save["version"] = 14
	SafeFile.write(TEST_PATH, JSON.stringify(old_save))
	_check(Inventory.load_from(TEST_PATH).super_orbs == 2, "a version 14 save's picks are read as orbs")
	_clear_save()
	_check(_test_curses() == true, "curse tests ran to the end")
	_check(_test_more_curses() == true, "second batch curse tests ran to the end")

	# The pages. The ordinary bag makes no heirloom; a transcension's does, at its foot, and writes
	# nothing: the whole transcension is one write, and the main scene's.
	var owner := Inventory.new()
	owner.super_orbs = 1
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
	_check(owner.stash().items.has(treasure) and made == [treasure] and owner.super_orbs == 1,
			"and Keep does it, for no orb")
	_check(not FileAccess.file_exists(TEST_PATH), "and writes nothing")
	choosing.queue_free()

	# Over the heirlooms the tray is the super orbs: an aimed one asks which line, the rest whether.
	var upgrading := BagPage.new(owner, "", 2.0, true, true)
	root.add_child(upgrading)
	await process_frame
	_check(upgrading._orb_tray.get_child_count() == SuperOrbTable.orbs().size(), "six super orbs in the tray")
	upgrading._select_item(0)
	upgrading._on_super_orb_pressed(SuperOrbTable.PERFECTION)
	_check(upgrading._confirm != null and _deep_button(upgrading._confirm,
			ModifierTable.line(treasure.mods[0])) != null, "Perfection asks which modifier")
	_deep_button(upgrading._confirm, ModifierTable.line(treasure.mods[0])).pressed.emit()
	_check(bool(treasure.mods[0].get("perfect", false)) and owner.super_orbs == 0, "and spends the orb on it")
	upgrading._on_super_orb_pressed(SuperOrbTable.ASCENSION)
	_check(upgrading._confirm == null and treasure.plus == 0, "with none left nothing happens")
	_check(not FileAccess.file_exists(TEST_PATH), "and none of it is written")
	upgrading.queue_free()
	var page := BagPage.new(owner, TEST_PATH, 2.0, true)
	root.add_child(page)
	await process_frame
	_check(_by_tooltip(page, "Auto") == null and _by_tooltip(page, "Throw away the") == null,
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


## What each super orb does to a piece, and what it leaves there for the ordinary orbs and the smith.
## What a modifier's band was at an item level before there were tiers, worked out here rather than
## asked of `ModifierTable`: the mean the tiers have to keep.
func _old_band(id: String, level: int) -> Array:
	var entry: Dictionary = ModifierTable.MODS[id]
	var band: Array = entry["range"]
	if entry["kind"] == ModifierTable.Kind.FLAT:
		var step := float(entry.get("level_flat", LootTable.LEVEL_FLAT.get(entry["stat"], 0.0)))
		return [LootTable.scale(entry["stat"], float(band[0]), level, step),
				LootTable.scale(entry["stat"], float(band[1]), level, step)]
	var grow := pow(LootTable.LEVEL_GROWTH, level - 1)
	return [float(band[0]) * grow, float(band[1]) * grow]


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
	var lift := float(ModifierTable.band_for("increased_damage", 30)[1]) / float(_old_band("increased_damage", 30)[1])
	_check(lift > 1.8 and lift < 2.1, "the top tier is about twice the old top (x%.2f)" % lift)
	_check(ModifierTable.band_for("increased_damage", 1) == [8, 20], "and tier 1 is the band as written")

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var total := 0.0
	var tops := 0
	for i in 2000:
		var mod := ModifierTable.rolled_mod("increased_damage", rng, 20)
		var under := int(mod.get("under", 0))
		_check(under >= 0 and under < 20 and (under > 0) == mod.has("under"), "a tier from 1 to the level: %s" % mod)
		tops += int(under == 0)
		total += int(mod["value"])
	var old_20 := _old_band("increased_damage", 20)
	var target_20 := (float(old_20[0]) + float(old_20[1])) / 2.0
	_check(absf(total / 2000.0 - target_20) < target_20 * 0.05,
			"two thousand rolls average what they did: %.1f against %.1f" % [total / 2000.0, target_20])
	_check(tops > 100 and tops < 400, "and the top tier is a tenth of them or so (%d)" % tops)
	for id: String in ["added_fight_clock", "added_gold_find"]:
		_check(not ModifierTable.tiered(id) and not ModifierTable.rolled_mod(id, rng, 20).has("under"),
				"%s has one band, and so no tier" % id)

	# A Divine moves the number and never the tier; the smith takes the tier up with the level.
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 20)
	var unders := sword.mods.map(func(mod: Dictionary) -> int: return int(mod.get("under", 0)))
	for i in 10:
		OrbTable.apply("Orb of Divine", sword, rng)
	_check(sword.mods.map(func(mod: Dictionary) -> int: return int(mod.get("under", 0))) == unders,
			"a Divine keeps every tier")
	for mod in sword.mods:
		var band := ModifierTable.band_for(str(mod["id"]), sword.tier_of(mod))
		_check(int(mod["value"]) >= int(band[0]) and int(mod["value"]) <= int(band[1]),
				"and rolls inside it: %s in %s" % [mod, band])
	var tiers := sword.mods.map(sword.tier_of)
	_check(Blacksmith.upgrade(sword, 99, _never_breaks()), "the hammer lands")
	_check(sword.mods.map(sword.tier_of) == tiers.map(func(tier: int) -> int: return tier + 1),
			"an upgrade is a tier as well as a level")

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


func _test_super_orbs() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 10)
	for orb: String in SuperOrbTable.orbs():
		_check(ResourceLoader.exists(OrbTable.ROOT + orb + ".png"), "%s has an icon" % orb)
		_check(not OrbTable.ORBS.has(orb), "%s is no ordinary orb: it never drops and is never sold" % orb)
		_check(not SuperOrbTable.can_apply(orb, null), "%s does nothing to nothing" % orb)

	# Ascension: +1, every modifier kept at its place in a band three levels up, again and again.
	var before := sword.mods.duplicate(true)
	_check(SuperOrbTable.apply(SuperOrbTable.ASCENSION, sword, rng) and sword.plus == 1
			and sword.mod_level() == 10 + Item.PLUS_LEVELS and sword.level == 10, "+1 lifts the modifiers' level, not the piece's")
	for i in sword.mods.size():
		var id: String = sword.mods[i]["id"]
		_check(sword.mods[i]["value"] == ModifierTable.rescaled(id, before[i]["value"],
				maxi(1, 10 - int(before[i].get("under", 0))), sword.tier_of(sword.mods[i])),
				"%s moved with its band" % id)
	_check(sword.display_name() == "Wooden Sword +1", "and it is written after the name")
	_check(SuperOrbTable.apply(SuperOrbTable.ASCENSION, sword, rng) and sword.plus == 2, "and it can be done again")
	_check(Item.from_dict(sword.to_dict()).plus == 2 and not _piece(ItemRarity.Rarity.RARE, 1).to_dict().has("plus"),
			"saved with the piece, and only where there is one")

	# Perfection: the top of the band, through a Divine, the smith and the end of a world.
	_check(not SuperOrbTable.apply(SuperOrbTable.PERFECTION, sword, rng), "an aimed orb needs a line to aim at")
	_check(SuperOrbTable.apply(SuperOrbTable.PERFECTION, sword, rng, 0), "Perfection takes a modifier")
	var perfect_id: String = sword.mods[0]["id"]
	var top := func() -> int: return int(ModifierTable.band_for(perfect_id, sword.mod_level())[1])
	_check(sword.mods[0]["value"] == top.call(), "which goes to the top of its band")
	_check(not SuperOrbTable.can_aim(SuperOrbTable.PERFECTION, sword, 0), "and is not perfected twice")
	for i in 10:
		OrbTable.apply("Orb of Divine", sword, rng)
	_check(sword.mods[0]["value"] == top.call(), "a Divine leaves it there")
	_check(Blacksmith.upgrade(sword, 99, _never_breaks()) and sword.mods[0]["value"] == top.call(),
			"the smith's upgrade carries it to the new top")
	SuperOrbTable.apply(SuperOrbTable.ASCENSION, sword, rng)
	_check(sword.mods[0]["value"] == top.call(), "so does another +1")
	sword.transcend()
	_check(sword.plus == 3 and sword.mod_level() == 1 + 3 * Item.PLUS_LEVELS
			and sword.mods[0]["value"] == top.call(), "and the end of a world keeps the plus and the top")
	_check(sword.perfect_lines() == PackedStringArray([ModifierTable.line(sword.mods[0])]),
			"its line is known to whoever writes it")

	# Binding: a second lock beside the smith's, once, and no orb moves either.
	sword.hold(1, "locked")
	_check(not SuperOrbTable.can_aim(SuperOrbTable.BINDING, sword, 1), "a locked line is not bound as well")
	_check(SuperOrbTable.apply(SuperOrbTable.BINDING, sword, rng, 2), "Binding locks another")
	_check(not SuperOrbTable.can_apply(SuperOrbTable.BINDING, sword), "once per piece")
	_check(not SuperOrbTable.can_aim(SuperOrbTable.REPLACEMENT, sword, 2), "and Replacement leaves it alone")
	var fast := [sword.mods[1].duplicate(), sword.mods[2].duplicate()]
	for i in 20:
		OrbTable.apply("Orb of Chaos", sword, rng)
		OrbTable.apply("Orb of Divine", sword, rng)
		_check(sword.mods.has(fast[0]) and sword.mods.has(fast[1]), "both locks survive a Chaos and a Divine")
	_check(sword.fast_lines().size() == 2, "and both are written in ink")

	# A held line keeps its band as well as its number: Ascension walks past it, a world's end does not.
	var written := sword.fast_lines(true)
	var bound: Dictionary = sword.mods.filter(func(mod: Dictionary) -> bool: return mod.get("bound", false))[0]
	var held := bound.duplicate()
	SuperOrbTable.apply(SuperOrbTable.ASCENSION, sword, rng)
	_check(bound == held and sword.fast_lines(true) == written, "an Ascension leaves a held line, band and all")
	_check(Item.from_dict(sword.to_dict()).fast_lines(true) == written, "and the save keeps its band")
	var heir := Item.from_dict(sword.to_dict())
	heir.transcend()
	var moved: Dictionary = heir.mods.filter(func(mod: Dictionary) -> bool: return mod.get("bound", false))[0]
	_check(moved["at"] == heir.mod_level() and moved["value"] == ModifierTable.rescaled(
			str(held["id"]), int(held["value"]), sword.tier_of(held), heir.tier_of(moved)),
			"the end of a world carries it to the new band, and holds it there")

	# Expansion: one past the rarity's most, once, and a reroll keeps the room.
	var most := int(ItemRarity.MOD_COUNT[ItemRarity.Rarity.ELITE][1])
	while sword.mods.size() < most:
		OrbTable.apply("Orb of Augmentation", sword, rng)
	_check(not OrbTable.can_apply("Orb of Augmentation", sword), "a full elite takes no more")
	_check(SuperOrbTable.apply(SuperOrbTable.EXPANSION, sword, rng) and sword.mods.size() == most + 1,
			"until it is expanded")
	_check(not SuperOrbTable.can_apply(SuperOrbTable.EXPANSION, sword), "once per piece")
	_check(Item.from_dict(sword.to_dict()).extra_slot, "saved with the piece")
	_check(not SuperOrbTable.can_apply(SuperOrbTable.EXPANSION, _piece(ItemRarity.Rarity.COMMON, 1)),
			"a common stays bare")

	# Replacement: another line in that place, never the same one.
	var plain := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 5)
	var ids := plain.mods.map(func(mod: Dictionary) -> String: return mod["id"])
	_check(SuperOrbTable.apply(SuperOrbTable.REPLACEMENT, plain, rng, 0) and not plain.mods[0]["id"] in ids
			and plain.mods.size() == ids.size(), "Replacement puts a new line where the old one was")

	# Mending: the one cure, and the one orb a broken piece takes.
	_check(not SuperOrbTable.can_apply(SuperOrbTable.MENDING, plain), "a whole piece needs no mending")
	plain.broken = true
	_check(not SuperOrbTable.can_apply(SuperOrbTable.ASCENSION, plain), "a broken piece takes no other orb")
	_check(SuperOrbTable.apply(SuperOrbTable.MENDING, plain, rng) and not plain.broken, "Mending makes it whole")

	# A unique's lines are its own: values may move, the lines may not.
	var unique := Item.rolled_unique(UniqueTable.UNIQUES.keys()[0], rng, 5)
	for orb: String in [SuperOrbTable.REPLACEMENT, SuperOrbTable.EXPANSION, SuperOrbTable.BINDING]:
		_check(not SuperOrbTable.can_apply(orb, unique), "%s is refused by a unique" % orb)
	_check(unique.mods.is_empty() or SuperOrbTable.can_apply(SuperOrbTable.ASCENSION, unique), "+1 is not")
	return true


## A generator whose first draw is as high as a draw gets, so the smith's hammer never breaks a piece.
func _never_breaks() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	for seed_value in 1000:
		rng.seed = seed_value
		var state := rng.state
		if rng.randf() > Blacksmith.BREAK_CHANCE:
			rng.state = state
			return rng
	return rng


## The first live Button anywhere under `parent` whose face starts with `text`, or null. Pages are
## built fresh on every refresh, so a test finds its button rather than holding one.
func _deep_button(parent: Node, text: String) -> Button:
	for button: Button in parent.find_children("", "Button", true, false):
		if button.text.begins_with(text) and not button.is_queued_for_deletion():
			return button
	return null


## The same, by what its tooltip starts with: a level's marks have no words on them.
func _by_tooltip(parent: Node, text: String) -> Button:
	for button: Button in parent.find_children("", "Button", true, false):
		if button.tooltip_text.begins_with(text) and not button.is_queued_for_deletion():
			return button
	return null


## An item built to order, for the tests that care about where a piece sorts rather than what it
## rolled. `Item.rolled` needs a generator and rolls modifiers; these want neither.
func _piece(rarity: ItemRarity.Rarity, level: int) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = level
	item.stats = Item.scaled_stats(item.type, level)
	return item


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
	return true


## Every Label anywhere under `node`, so a test can read what a panel actually says without knowing
## how it is stacked.
func _labels_under(node: Node) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in node.get_children():
		if child is Label:
			found.append(child)
		found.append_array(_labels_under(child))
	return found


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
		# Damage is a whole point a level, which is the reason the flat step exists at all.
		var damage: float = sword.base_stats()["damage"]
		_check(is_equal_approx(damage, float(roundi(damage))), "a level-%d sword's damage is whole" % level)
		if level > 1:
			var under := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, level - 1)
			_check(damage > float(under.base_stats()["damage"]),
					"a level-%d sword hits harder than a level-%d one" % [level, level - 1])
		# A rate keeps its decimal, because it is read as one.
		var speed: float = sword.base_stats()["attack_speed"]
		_check(is_equal_approx(speed, snappedf(speed, 0.1)), "a level-%d sword's attack speed is a tenth" % level)

	# A probability may not be multiplied by a level. Every chance stat grows by its flat step alone,
	# so a deep set of gear cannot add up past certainty and make every hit a crit.
	for stat: String in LootTable.CHANCE_STATS:
		# Sight and the fight clock are the two in the list that are not probabilities: a number of
		# tiles and a number of seconds, there so that a level cannot multiply either.
		_check(stat in LootTable.PERCENT_STATS or stat in ["sight", "fight_clock"],
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
	var gone := Item.from_dict({"type": "Wooden Armor", "rarity": "common", "level": 1,
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

	# A material is more of every quantity and no more of a chance or a rate: a steel shield holds
	# more armour than a wooden one and blocks exactly as often.
	for kind: String in LootTable.KINDS:
		if LootTable.KINDS[kind].has("tier_stats"):
			continue   # the torch, which writes each material's Sight out rather than multiplying it
		var tiers: Array = LootTable.KINDS[kind]["tiers"]
		for tier in range(1, tiers.size()):
			var under := Item.scaled_stats(str(tiers[tier - 1]), 10)
			var over := Item.scaled_stats(str(tiers[tier]), 10)
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
		for type: String in ["Leather Helmet", "Leather Boot", "Wooden Sword", "Wooden Shield",
				"Wooden Armor", "Gold Ring", "Ruby Amulet"]:
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
		var jewel: bool = LootTable.slot_of(type) in ["ring", "amulet"]
		_check(("added_item_rarity" in ModifierTable.pool_for(type)) == jewel,
				"%s %s roll item rarity" % [type, "should" if jewel else "should not"])
	_check(ModifierTable.band_for("added_gold_find", 30) == ModifierTable.band_for("added_gold_find", 1),
			"gold find's band is the same at level 30 as at level 1 (%s)"
					% [ModifierTable.band_for("added_gold_find", 30)])
	return true


## A mouse button going down or coming up on the grid, in the panel's own coordinates.
func _press(main: Node, at: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.position = at
	main.bag_page._on_grid_input(event)


## The cursor moving `by` pixels down the grid with the button held.
func _drag(main: Node, from: Vector2, by: float) -> void:
	var event := InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = from + Vector2(0, by)
	event.relative = Vector2(0, by)
	main.bag_page._on_grid_input(event)


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

	# Two rings worn and a third selected: Swap beside Equip turns it to the other finger.
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
	_check(main.bag_page._socket_pick == 0, "a ring goes on the left finger first")
	var swap := _by_tooltip(main.bag_page._actions, "Equip over the other ring")
	_check(swap != null, "with a Swap beside Equip")
	if swap != null:
		swap.pressed.emit()
	_check(main.bag_page._socket_pick == 1, "which turns Equip to the right one")
	_check(_by_tooltip(main.bag_page._actions, "Equip over the other ring") != null,
			"and is still there to turn it back")
	main.bag_page._select_item(main.inventory.items.find(strong))
	_check(_by_tooltip(main.bag_page._actions, "Equip over the other ring") == null,
			"a sword has one socket and no Swap")
	main.bag_page._select_item(main.inventory.items.find(rings[2]))
	_check(main.bag_page._socket_pick == 0, "and a new selection starts on the emptiest finger again")
	_by_tooltip(main.bag_page._actions, "Equip over the other ring").pressed.emit()
	_deep_button(main.bag_page._actions, "Equip").pressed.emit()
	_check(main.inventory.equipment.item_at(Equipment.Socket.RING_RIGHT) == rings[2]
			and main.inventory.equipment.item_at(Equipment.Socket.RING_LEFT) == rings[0],
			"and Equip replaces the ring Swap turned to")

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
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = offhand.position + offhand.size / 2.0
		main.bag_page._on_doll_input(press)
		_check(main.bag_page._worn_selected == Equipment.Socket.WEAPON,
				"and a press on it opens the greatsword")
	main._on_left_page_closed()
	main.queue_free()
	_clear_save()
	return true


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

	# --- Alchemy: straight to rare from below, a reroll at rare, refused above ---
	var climbing := Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 2)
	_check(OrbTable.apply("Orb of Alchemy", climbing, rng), "alchemy lands on a common")
	_check(climbing.rarity == ItemRarity.Rarity.RARE, "alchemy makes it rare in one step")
	_check(OrbTable.apply("Orb of Alchemy", climbing, rng), "alchemy rerolls a rare")
	_check(climbing.rarity == ItemRarity.Rarity.RARE, "and it stays rare")
	_check(not OrbTable.can_apply("Orb of Transmutation", climbing), "no orb lowers a rare to uncommon")
	_check(not OrbTable.why_not("Orb of Transmutation", climbing).is_empty(),
			"a refused transmutation says why")

	# --- Exalted: straight to elite, a reroll at elite, and never as far as unique ---
	_check(OrbTable.apply("Orb of Exalted", climbing, rng), "exalted lands on a rare")
	_check(climbing.rarity == ItemRarity.Rarity.ELITE, "exalted makes it elite")
	_check(OrbTable.apply("Orb of Exalted", climbing, rng), "exalted rerolls an elite")
	_check(climbing.rarity == ItemRarity.Rarity.ELITE, "and it stays elite, never unique")
	_check(not OrbTable.can_apply("Orb of Alchemy", climbing), "alchemy refuses an elite")
	var bare := Item.rolled("Wooden Armor", ItemRarity.Rarity.COMMON, rng, 1)
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
	_check(OrbTable.can_apply("Orb of Divine", divine), "a piece with modifiers can be divined")
	var moved := false
	for attempt in 20:
		var before_values := []
		for mod in divine.mods:
			before_values.append(int(mod["value"]))
		_check(OrbTable.apply("Orb of Divine", divine, rng), "divine lands")
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
	_check(not OrbTable.can_apply("Orb of Divine", bare), "a bare common has nothing to divine")

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
		# Half start uncommon: nothing lowers a rarity, so that is the only way Transmutation meets a lock.
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
	for number: Label in written.find_children(UITheme.TABLE_VALUE, "Label", true, false):
		# A table row is its name and then its number; turned round it is the line Item wrote.
		var text := "%s %s" % [number.text, (number.get_parent().get_child(0) as Label).text]
		if text in pinned_piece.mod_lines() and number.get_theme_color("font_color") == Palette.TEXT:
			_check(text == pinned_piece.locked_line(), "only the locked modifier is in ink: %s" % text)
			inked += 1
	_check(inked == 1, "the block writes the locked modifier in ink")
	written.free()

	# A broken piece is out of the game as far as the orbs are concerned, and each of the six says so.
	var ruined := Item.rolled("Leather Boot", ItemRarity.Rarity.RARE, rng, 4)
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
	bag.add_orb("Orb of Divine")
	_check(bag.orb_count("Orb of Chaos") == 3, "three chaos orbs went in")
	_check(bag.orb_count("Orb of Alchemy") == 0, "an orb never found counts zero")
	_check(bag.total_orbs() == 4, "four orbs in all")
	# A name this build does not have is not a count it keeps.
	bag.add_orb("Orb of Nonsense", 5)
	_check(bag.total_orbs() == 4, "an orb that does not exist is not added")

	# Spending: one at a time, and never past empty.
	_check(bag.spend_orb("Orb of Divine"), "the last divine is spent")
	_check(bag.orb_count("Orb of Divine") == 0, "and is gone")
	_check(not bag.orbs.has("Orb of Divine"), "an emptied orb leaves no entry behind")
	_check(not bag.spend_orb("Orb of Divine"), "there is no second one to spend")

	# The cap is the bag's, and orbs are not in the bag.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in Inventory.CAPACITY:
		bag.add(Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 1))
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
		"items": [], "equipped": {}, "autodiscard": [],
		"orbs": {"Orb of Chaos": 2, "Orb of Scouring": 9, "Orb of Divine": -4, "Orb of Alteration": 3,
				"Orb of Transmutation": 1},
	}
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(edited, "\t"))
	file = null
	var pruned := Inventory.load_from(TEST_PATH)
	_check(pruned.orb_count("Orb of Chaos") == 2, "a known orb survives the read")
	_check(pruned.orb_count("Orb of Transmutation") == 4, "a retired Alteration reads as Transmutation")
	_check(pruned.total_orbs() == 6, "an unknown orb is dropped and a negative one reads as none")
	_clear_save()
	return true


## Crafting as the player does it: the real panel, the real tray, and a square pressed. The tables
## are checked above; this is the wiring -- which orbs the tray offers against the piece that is
## open, what a press does to the piece and to the count, and that the block it was pressed from is
## still open on the same piece afterwards.
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
	main.inventory.add_orb("Orb of Divine", 1)
	main._on_bag_pressed()
	main.bag_page._select_item(0)
	for i in 2:
		await process_frame

	# The tray with a common piece open: one of the two held orbs has something to do and the other
	# has not, which is the whole of what the lit/grey split says.
	var lit: Array = []
	var grey: Array = []
	for child: Node in main.bag_page._orb_tray.get_children():
		var orb: String = child.orb
		if main.inventory.orb_count(orb) <= 0:
			continue
		if OrbTable.can_apply(orb, sword):
			lit.append(orb)
		else:
			grey.append(orb)
	_check(lit == ["Orb of Transmutation"], "only transmutation is lit on a common, got %s" % [lit])
	_check(grey == ["Orb of Divine"], "divine is grey on a common, got %s" % [grey])
	_check(main.bag_page._orb_tray.get_child_count() == OrbTable.ORBS.size(),
			"the tray draws every orb, held or not")

	# Pressed, exactly as a click on the square does it.
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	for i in 2:
		await process_frame
	_check(sword.rarity == ItemRarity.Rarity.UNCOMMON, "the sword came up uncommon")
	_check(not sword.mods.is_empty(), "and carries modifiers")
	_check(main.inventory.orb_count("Orb of Transmutation") == 1, "one orb was spent")
	# Crafting adds nothing and removes nothing, so the selection is still the same piece -- which is
	# what lets the player watch a piece change rather than go hunting for it again.
	_check(main.bag_page._selected == 0, "the selection stayed on the same piece")
	_check(main.bag_page._actions.visible, "and its buttons are still showing")

	# Alchemy takes it to rare, and then Transmutation has nothing to do: no orb lowers a rarity, and
	# pressing it must not cost the player the second one. The square is grey and ignores the click;
	# the handler is checked too, because the guarantee is apply first and spend only if it landed.
	main.inventory.add_orb("Orb of Alchemy")
	main.bag_page._on_orb_pressed("Orb of Alchemy")
	_check(sword.rarity == ItemRarity.Rarity.RARE, "alchemy made it rare")
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	_check(main.inventory.orb_count("Orb of Transmutation") == 1, "a refused orb is not spent")
	_check(sword.rarity == ItemRarity.Rarity.RARE, "and the piece did not change again")

	# Divine is lit now that there are modifiers to reroll.
	main.bag_page._on_orb_pressed("Orb of Divine")
	for i in 2:
		await process_frame
	_check(sword.rarity == ItemRarity.Rarity.RARE, "divine kept the rarity")
	_check(main.inventory.orb_count("Orb of Divine") == 0, "the divine orb was spent")

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
	var card_right: float = main.bag_page._orb_card.get_global_position().x + main.bag_page._orb_card.size.x * main.ui_scale
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
	main.bag_page._hide_orb_card()
	_check(not main.bag_page._orb_card.visible, "and leaving takes it down")

	# Everything crafted goes through the save unchanged, which is the whole point of a piece being
	# frozen: what came back is what was put in, orbs and all.
	var before := sword.to_dict()
	main.inventory.save(TEST_PATH)
	var back := Inventory.load_from(TEST_PATH)
	_check(back.orb_count("Orb of Transmutation") == 1, "the unspent orb survived the save")
	_check(back.orb_count("Orb of Divine") == 0, "the spent one did not come back")
	_check(back.items.size() == 1, "the sword came back")
	_check(back.items[0].to_dict() == before, "the crafted sword round-trips exactly")

	# The other way round: the orb first, with nothing open, and then the piece where it lies.
	var plain := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng, 4)
	main.inventory.add(plain)
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
	# A press on the grey one costs nothing and opens nothing; the orb is still held.
	main.bag_page._on_clicked(_square_spot(sword_square))
	_check(main.inventory.orb_count("Orb of Transmutation") == 1 and main.bag_page._selected == -1
			and main.bag_page._armed != "", "a refused piece spends nothing and stays shut")
	var told: Array = []
	main.bag_page.crafted.connect(func() -> void: told.append(true))
	plain_square = _bag_squares(main).filter(func(s: ItemSlot) -> bool: return s.item == plain)[0]
	main.bag_page._on_clicked(_square_spot(plain_square))
	await process_frame
	_check(plain.rarity == ItemRarity.Rarity.UNCOMMON, "the piece pressed next came up uncommon")
	_check(main.inventory.orb_count("Orb of Transmutation") == 0, "the orb was spent")
	_check(main.bag_page._selected == -1 and not main.bag_page._actions.visible, "without the piece being opened")
	_check(told.size() == 1, "and the hover card was told to speak again")
	_check(main.bag_page._armed == "", "the last of an orb puts it down")
	# Opening a piece puts a held orb down too: from there the tray crafts on what is open.
	main.inventory.add_orb("Orb of Divine", 2)
	main.bag_page._on_orb_pressed("Orb of Divine")
	main.bag_page._on_orb_pressed("Orb of Divine")
	_check(main.bag_page._armed == "", "the same orb again puts it down")
	main.bag_page._on_orb_pressed("Orb of Divine")
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	main.bag_page._input(right)
	_check(main.bag_page._armed == "" and main.inventory.orb_count("Orb of Divine") == 2,
			"a right click puts it down too, unspent")
	main.bag_page._on_orb_pressed("Orb of Divine")
	main.bag_page._select_item(0)
	_check(main.bag_page._armed == "", "and so does opening a piece")

	main.queue_free()
	await process_frame
	_clear_save()
	return true
## The right-hand edge of a panel on the UI layer, in window pixels.
func _panel_right(panel: Control, ui_scale: float) -> float:
	return panel.get_global_position().x + panel.size.x * ui_scale


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

	main._on_bag_pressed()
	_check(not main._flashes.has("opened_bag") and main._bag_button.modulate == Color.WHITE,
			"pressing the bag stops its pulse")
	_check(main._flashes.has("skill_point"), "while the star keeps pulsing")
	main.inventory.level = 1
	main.skills_page.open()
	_check(not main._flashes.has("skill_point") and main._skills_button.modulate == Color.WHITE,
			"until no point is left to spend")
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
		_check(not str(row["name"]).is_empty() and not str(row["effect_text"]).is_empty(),
				"%s has a name and says what it does" % id)
		_check(not UniqueTable.effect_of(id).is_empty(), "%s changes something" % id)
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
		for env: String in row["envs"]:
			_check(env in envs, "%s is found on %s, which is real ground" % [id, env])
		if row["effect"] == "home":
			_check(row["envs"] == [row["home"]], "%s is found on the ground it is for" % id)
	for env in envs:
		_check(UniqueTable.pool_for(env).size() >= 2, "%s has uniques to hunt (%s)" % [env, UniqueTable.pool_for(env)])
	for mod_id: String in ModifierTable.UNIQUE_ONLY:
		var used := false
		for id: String in UniqueTable.UNIQUES:
			used = used or mod_id in UniqueTable.UNIQUES[id]["mods"]
		_check(used, "%s is held back for a unique that carries it" % mod_id)
	return true


## One unique: rolled, worn, saved, crafted and thrown away like the piece it is -- and unlike one.
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
		_check(OrbTable.can_apply(orb, axe) == (orb in ["Orb of Divine", "Orb of Chaos"]), "%s on a unique" % orb)
	_check(not OrbTable.why_not("Orb of Alchemy", axe).is_empty(), "and the refusal is said")
	OrbTable.apply("Orb of Chaos", axe, rng)
	_check(axe.mods.map(func(m: Dictionary) -> String: return m["id"]) == ids, "Chaos moves the tiers and nothing else")
	OrbTable.apply("Orb of Divine", axe, rng)
	_check(axe.mods.map(func(m: Dictionary) -> String: return m["id"]) == ids, "Divine moves the values and nothing else")

	var ring := Item.rolled_unique("the_tithe", rng, 5)
	_check(ring.effective_stats().get("gold_find", 0.0) > 0.0, "The Tithe's gold find is a stat it is worth")
	var bag := Inventory.new()
	for id: String in ["knucklebone_ring", "knucklebone_ring", "meadowstriders"]:
		var piece := Item.rolled_unique(id, rng, 3)
		bag.items.append(piece)
		_check(bag.equip(piece, bag.equipment.sockets_for(piece)[0]), "%s goes on" % id)
	var effects := bag.effects()
	_check(effects.count("knucklebone") == 2 and "home:grass" in effects, "what is worn reaches the fight (%s)" % [effects])
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

	# The ledger is what writes the log: at once for a tile fight, at the bank for a run.
	var tile_bag := Inventory.new()
	FightLedger.new(tile_bag, TEST_PATH).add_loot(Item.rolled_unique("rimeplate", rng, 2))
	_check(tile_bag.uniques_found == ["rimeplate"], "a tile fight logs a unique as it lands")
	var run_bag := Inventory.new()
	var run := FightLedger.new(run_bag, TEST_PATH, true)
	run.add_loot(Item.rolled_unique("stonebreaker", rng, 2))
	_check(run_bag.uniques_found.is_empty(), "a run holds it in the pouch")
	run.bank()
	_check(run_bag.uniques_found == ["stonebreaker"], "and logs it at the bank")
	_clear_save()
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
	var bag := Inventory.new()
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
	_check(is_equal_approx(bag.stats()["damage"], without + armour * Inventory.SPIKES_SHARE * 1.5),
			"a hundredth of the armour, scaled like any flat damage (%s from %s)" % [bag.stats()["damage"], without])

	# The two counts the fight cannot see for itself.
	_check(bag.stats()["bare_sockets"] == Equipment.NAMES.size() - 3, "three sockets filled, the rest bare")
	bag.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	bag.items.append(_piece(ItemRarity.Rarity.COMMON, 1))
	_check(bag.stats()["bag_pieces"] == 2, "and two pieces in the bag")

	# The Rag and Bone Sack: a quarter of what a trader gives, and only while it is worn.
	var junk := _piece(ItemRarity.Rarity.RARE, 8)
	_check(bag.salvage(junk) == 0.0, "nothing is paid for rubbish without the sack")
	wear.call(bag, Item.rolled_unique("rag_and_bone_sack", rng, 5))
	var paid := bag.salvage(junk)
	_check(paid == maxf(1.0, roundf(TownPrices.sell_price(junk) * 0.25)) and paid < TownPrices.sell_price(junk),
			"a quarter of the trader's price (%s of %s)" % [paid, TownPrices.sell_price(junk)])
	# A run pouches it like any gold; the bag pays for its own discards at once.
	var run := FightLedger.new(bag, TEST_PATH, true)
	run.add_gold(paid)
	_check(bag.gold == 0.0, "a run holds its salvage in the pouch")
	run.bank()
	_check(bag.gold == paid, "and banks it")
	var page := BagPage.new(bag, TEST_PATH, 2.0)
	root.add_child(page)
	await process_frame
	bag.items.append(junk)
	page._on_discard_pressed(junk)
	_check(bag.gold == paid * 2.0 and not bag.items.has(junk), "the bag's Discard pays too")
	var level_one := bag.count_at(1)
	page._on_clear_level_pressed(1)
	_check(level_one == 2 and bag.gold > paid * 2.0 and bag.count_at(1) == 0, "and so does a level's bin")
	page.queue_free()

	# One home piece is at home on its own ground. Two or more are a Pilgrim's set: every piece's rule
	# on every piece's ground, and each ground named once so the damage never stacks.
	var pilgrim := Inventory.new()
	wear.call(pilgrim, Item.rolled_unique("meadowstriders", rng, 1))
	_check(pilgrim.effects() == ["home:grass", "grazing:grass"], "one piece, one ground (%s)" % [pilgrim.effects()])
	wear.call(pilgrim, Item.rolled_unique("rimeplate", rng, 1))
	var two := pilgrim.effects()
	for id: String in ["home:grass", "home:ice", "grazing:grass", "grazing:ice", "frozen_clock:grass", "frozen_clock:ice"]:
		_check(two.count(id) == 1, "two pieces share their grounds: %s (%s)" % [id, two])
	_check(two.size() == 6, "and nothing else")
	# No two home pieces share a socket, so the whole set can be worn and everywhere is home.
	for id: String in ["hunters_lantern", "sunscorched_cowl", "stonebreaker", "gravediggers_charm"]:
		wear.call(pilgrim, Item.rolled_unique(id, rng, 1))
	var six := pilgrim.effects()
	for env: String in ["grass", "forest", "desert", "ice", "mountains", "dirt"]:
		_check(six.count("home:" + env) == 1, "all six: %s is home, once" % env)
		for clause: String in ["grazing", "flush_out", "heatstroke", "frozen_clock", "giantsbane", "restless"]:
			_check(("%s:%s" % [clause, env]) in six, "all six: %s on %s" % [clause, env])
	var slots := {}
	for id: String in UniqueTable.UNIQUES:
		if UniqueTable.UNIQUES[id]["effect"] == "home":
			var slot := LootTable.slot_of(UniqueTable.UNIQUES[id]["base"])
			_check(not slots.has(slot), "%s and %s do not fight over the %s socket" % [id, slots.get(slot, ""), slot])
			slots[slot] = id
	# Every home row says so on its card, and no other row does.
	for id: String in UniqueTable.UNIQUES:
		_check((UniqueTable.set_text(id) == UniqueTable.PILGRIM_TEXT) == (UniqueTable.UNIQUES[id]["effect"] == "home"),
				"%s's card mentions the Pilgrim's set only if it is a home piece" % id)
	# A set piece is a unique in green, frame and all; any other unique stays gold.
	var home := Item.rolled_unique("rimeplate", rng, 1)
	_check(home.rarity == ItemRarity.Rarity.UNIQUE and home.is_set(), "a home piece is a unique and a set piece")
	_check(home.border_color() == ItemRarity.SET_BORDER and home.text_color() == ItemRarity.SET_TEXT
			and home.frame() != null, "and wears the set's green, with a frame of its own")
	_check(Item.rolled_unique("snowball", rng, 1).border_color() == Palette.GOLD, "a plain unique stays gold")
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
	_check(main._collection_button.visible and main._flashes.has("new_unique"), "it comes on, pulsing")
	_check("first_unique" in main.inventory.tips and main._tip_panel != null, "with a word about what was found")
	main._on_tip_closed()
	main.inventory.fortunes[FortuneTeller.PEEKED] = ["rimeplate"]
	main._on_collection_pressed()
	await process_frame
	_check(main.collection_page.visible and main._collection_button.visible, "the page opens, its button beside it")
	_check(main._flashes.has("new_unique"), "still pulsing while the find is not looked at")
	var squares: Array = main.collection_page.find_children("*", "ItemSlot", true, false)
	var fresh: Array = squares.filter(func(slot: ItemSlot) -> bool: return slot.has_node(ItemSlot.GLINT_NAME))
	_check(fresh.size() == 1 and fresh[0].item.unique == "metronome", "the new find glints (%d)" % fresh.size())
	fresh[0].hint.call(VBoxContainer.new(), 100.0)
	await process_frame
	_check(not main._flashes.has("new_unique") and not fresh[0].has_node(ItemSlot.GLINT_NAME),
			"hovering it stills both")
	_check(Inventory.load_from(TEST_PATH).uniques_new.is_empty(), "and that is saved")
	_check(squares.size() == UniqueTable.UNIQUES.size(), "one square a unique (%d)" % squares.size())
	# The foot, under the scroll: what the log adds and how full it is, in the body font.
	var bonus: Label = main.collection_page.find_child(CollectionPage.BONUS_NAME, true, false)
	var tally: Label = main.collection_page.find_child(CollectionPage.COUNT_NAME, true, false)
	_check(bonus.text == "+%d%% Damage" % main.inventory.collection_bonus(), "the damage it adds is always written (%s)" % bonus.text)
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
		var told := id == "rimeplate"
		shown += int(found)
		# Every square writes its card through the hint now: a found one so it still says where the
		# piece is carried, a missing one so it says nothing else.
		_check(square.hint.is_valid(), "%s: the card is written by the hint" % id)
		_check((square.modulate == ItemSlot.SHADOW) == told, "%s: darkened only once a fortuneteller has shown it" % id)
		var icon: TextureRect = square.get_child(0)
		_check((icon.modulate == Color.BLACK) == (not found and not told),
				"%s: a black outline only while nobody has shown it" % id)
		_check((square.get_node_or_null(ItemSlot.FRAME_NAME) == null) == (not found and not told),
				"%s: and no ring to give its rarity away" % id)
	_check(shown == 1, "the found one is drawn as itself")
	# The hint says nothing of the piece or its ground until a fortuneteller has shown it, and both
	# after -- and where it is carried stays on the card once the piece is found, which is the one
	# place a second copy or the rest of a set can be looked up.
	for state: Array in [[false, false], [true, false], [true, true]]:
		var peeked: bool = state[0]
		var found: bool = state[1]
		var rows := VBoxContainer.new()
		CollectionPage.write_hint(rows, 150.0, "rimeplate", main.view,
				CollectionPage.specimen("rimeplate") if peeked else null, found)
		var said := ""
		for label: Node in rows.find_children("*", "Label", true, false):
			said += (label as Label).text + " "
		_check(said.contains("Rimeplate") == peeked and said.contains("Nearest:") == peeked,
				"a hint says what and where only once it has been peeked (%s: %s)" % [peeked, said])
		if peeked:
			_check(said.contains("Found") == found and said.contains("Not found yet") == (not found),
					"and whether it is held (found %s: %s)" % [found, said])
		rows.free()
	# The found square's own card is the same block, so the log reads alike either way.
	var held_rows := VBoxContainer.new()
	for square: ItemSlot in squares:
		if square.item.unique == "metronome":
			square.hint.call(held_rows, 150.0)
	var held := ""
	for label: Node in held_rows.find_children("*", "Label", true, false):
		held += (label as Label).text + " "
	_check(held.contains("Found") and not held.contains("Not found yet") and held.contains("Nearest:"),
			"a found square still says where the piece is carried (%s)" % held)
	held_rows.free()
	# The settings page's dev tick draws the lot as found. A static, so it is put back.
	Settings.all_uniques = true
	main.collection_page.open()
	await process_frame
	squares = main.collection_page.find_children("*", "ItemSlot", true, false)
	_check(squares.size() == UniqueTable.UNIQUES.size() and squares.all(
			func(square: ItemSlot) -> bool: return square.modulate == Color.WHITE and square.get_node_or_null(ItemSlot.FRAME_NAME) != null),
			"the dev setting shows every unique as found (%d)" % squares.size())
	Settings.all_uniques = false
	main._on_left_page_closed()
	_check(not main.collection_page.visible and main._collection_button.visible, "the X puts it away")
	# The banner: raised by a unique the log has never held, and by nothing else.
	var drop_rng := RandomNumberGenerator.new()
	drop_rng.seed = 7
	main._on_loot_dropped(0, Item.rolled_unique("stonebreaker", drop_rng, 5))
	await process_frame
	_check(main._banner != null, "a unique new to the log raises its banner")
	_check(not main._banner_closable and main._banner_head.get_child_count() == 1,
			"with no way to put it down for the first five seconds")
	# A click inside those five seconds says the player is fighting, so it goes at the end of them.
	main._banner_clicked = true
	main._on_banner_held(main._banner)
	_check(main._banner == null, "a player who was clicking has it taken away at the end of them")
	main._on_loot_dropped(0, Item.rolled_unique("stonebreaker", drop_rng, 5))
	_check(main._banner == null, "a second copy of one already logged raises nothing")
	main._on_loot_dropped(0, LootTable.roll("Baby Dragon", drop_rng, true, 5))
	_check(main._banner == null, "and an ordinary find raises nothing")
	# Nobody clicked: it grows an X instead of going, and stays until it is pressed or a swing lands.
	main._on_loot_dropped(0, Item.rolled_unique("headsman", drop_rng, 5))
	await process_frame
	main._on_banner_held(main._banner)
	_check(main._banner != null and main._banner_closable
			and main._banner_head.get_child_count() == 2,
			"a player who sat still gets an X, and it stays")
	var swing := InputEventMouseButton.new()
	swing.button_index = MOUSE_BUTTON_LEFT
	swing.pressed = true
	main._input(swing)
	_check(main._banner == null, "and the next swing puts it down")
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
	_check(page.item.type == "Golden Helm" and page.item.level == 12, "the generator makes the tier and level it was asked for")
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
	_check(strength != null and strength.text == "12", "strength is on its disc")
	var said := ""
	for label: Node in main.character_page.find_children("*", "Label", true, false):
		said += (label as Label).text + "|"
	_check(said.contains("Damage|5|"), "a stat that is something is a row, name then number (%s)" % said)
	_check(not said.contains("Armour"), "and one that is nothing is not")
	main._on_left_page_closed()
	_check(not main.character_page.visible and main._character_button.visible, "the X puts it away")
	main.queue_free()
	_clear_save()
	return true


## The bank-or-pouch rule on its own, with no scene: a tile fight banks each gain as it lands and a
## run holds all of it until `bank`, which is safe to call twice.
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
	_check(tile.pending_xp() == 0 and not tile.bank(), "so it has nothing pending and nothing to bank")
	_check(tile.discard(sword) and bag.total() == 0, "a find thrown away comes back out of the bag")

	bag = Inventory.new()
	var run := FightLedger.new(bag, TEST_PATH, true)
	run.add_loot(sword)
	run.add_gold(7)
	run.add_orb(orb)
	run.add_xp(1)
	_check(bag.total() == 0 and bag.gold == 0 and bag.total_orbs() == 0, "a run holds what it earns")
	_check(run.pending_xp() == 1 and run.room_left() == Inventory.CAPACITY - 1,
			"and counts its pouch against the panel and the bag's room")
	_check(run.bank() and bag.items.has(sword) and bag.gold == 7 and bag.orb_count(orb) == 1,
			"banking empties the pouch into the bag")
	_check(not run.bank() and bag.gold == 7 and bag.total() == 1, "and a second call repeats none of it")
	_check(Inventory.load_from(TEST_PATH).gold == 7, "in one write")

	bag = Inventory.new()
	var purse := FightLedger.new(bag, TEST_PATH, true)
	purse.add_gold(3)
	_check(purse.bank() and bag.gold == 3, "a run that found only gold is still paid")
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
	_check(Curses.effect(Curses.IRON_FOES) in leaving.effects() and not Curses.effect(Curses.THICK_FOG) in leaving.effects(),
			"the fight hears of the world's curses, and not of the ones only chosen")
	_check(float(leaving.stats().get("gold_find", 0.0)) == 40.0, "and Iron Foes pays its gold find in the stats")
	var next := leaving.transcended()
	_check(next.curses == [Curses.BLOODTHIRST, Curses.THICK_FOG] and next.pending_curses.is_empty(),
			"the chosen ones are the next world's, the old world's are left in it (%s)" % [next.curses])
	_check(float(next.stats().get("item_rarity", 0.0)) == 30.0 and float(next.stats().get("gold_find", 0.0)) == 0.0,
			"with what they pay")
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

	# Hard Lessons' pay: every skill point counts double, flat and percent alike, and the card says so.
	var student := Inventory.new()
	student.level = 10
	_check(student.skills.rank_up("sharpened_edge", student.level), "a point goes into Sharpened Edge")
	var taught := float(student.stats().get("damage", 0.0))
	student.curses = [Curses.HARD_LESSONS]
	_check(taught > 0.0 and float(student.stats().get("damage", 0.0)) == taught * 2.0 and student.skill_worth() == 2,
			"under Hard Lessons the point is worth double (%s against %s)" % [student.stats().get("damage", 0.0), taught])
	_check(SkillTree.describe("sharpened_edge", student.skill_worth()) == SkillTree.describe("sharpened_edge", 2)
			and Inventory.new().skill_worth() == 1, "and the card describes two points for one")
	_check(student.effects().count(Curses.effect(Curses.HARD_LESSONS)) == 1, "the fight hears of it once")

	# The Long Winter's pay: a wall twice as hard is worth two.
	var winter := Inventory.new()
	winter.curses = [Curses.LONG_WINTER]
	_check(winter.credit_walls(1) and winter.super_orbs == 2, "a wall under the Long Winter pays two orbs")
	_check(not winter.credit_walls(1) and winter.credit_walls(3) and winter.super_orbs == 6, "every one of them, once")

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
	view.free()
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

	# The Specialist: one tree, and every point worth half again -- added to Hard Lessons', never compounded.
	var student := Inventory.new()
	student.level = 10
	var trees := SkillTree.trees()
	var first := str(SkillTree.nodes_of(trees[0]).keys()[0])
	var second := ""
	for id: String in SkillTree.nodes_of(trees[1]):
		if SkillTree.node(id)["parents"].is_empty():
			second = id
			break
	_check(student.rank_up_skill(first), "a point goes into the first tree")
	_check(student.why_not_skill(second).is_empty(), "and without the curse the second tree is open")
	student.curses = [Curses.SPECIALIST]
	_check("Specialist" in student.why_not_skill(second) and not student.rank_up_skill(second)
			and student.skills.spent(trees[1]) == 0, "a Specialist is refused a second tree (%s)" % student.why_not_skill(second))
	_check(not "Specialist" in student.why_not_skill(first), "and never the tree already begun")
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
	var boots := Item.rolled("Leather Boot", ItemRarity.Rarity.RARE, rng, 5)
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
	_check(lone.most_worn == -1 and heir.stash().most_worn == -1, "the ordinary doll, and an uncursed world's heirlooms, wear what they like")
	var kept := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 8)
	lone.items.append(kept)
	_check(lone.make_heirloom(kept) and kept.plus == 1, "the heirloom made at the end of that world is +1")
	var plain_kept := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 8)
	heir.items.append(plain_kept)
	_check(heir.make_heirloom(plain_kept) and plain_kept.plus == 0, "and no other world's is")

	# The skull budget: this world's depth plus the skulls carried in, never lower than it was, and
	# nothing at all from a world lost to No Second Chances.
	var climber := Inventory.new()
	climber.walls_credited = 3
	climber.curses = [Curses.BLOODTHIRST, Curses.IRON_FOES]
	_check(climber.skulls_earned() == 6 and climber.transcended().skull_budget == 6,
			"three walls carrying three skulls earn six (%d)" % climber.skulls_earned())
	climber.skull_budget = 9
	_check(climber.skulls_earned() == 9, "and a budget already past that stays where it is")
	climber.skull_budget = 2
	_check(climber.skulls_earned(true) == 2 and climber.transcended(true).skull_budget == 2,
			"a lost world raises nothing")
	var ringed := Inventory.new()
	ringed.walls_credited = 6
	ringed.curses = [Curses.RING_OF_WALLS]
	_check(ringed.skulls_earned() == 6, "six walls five rings apart are three deep: 3 + 3 (%d)" % ringed.skulls_earned())
	climber.skull_budget = 7
	climber.save(TEST_PATH)
	_check(Inventory.load_from(TEST_PATH).skull_budget == 7, "and the budget comes back off the save")
	_check(Curses.skulls_of([Curses.LONG_WINTER, Curses.IRON_FOES]) == 4
			and Curses.fits(Curses.IRON_FOES, [Curses.LONG_WINTER], 4)
			and not Curses.fits(Curses.BLOODTHIRST, [Curses.LONG_WINTER], 4)
			and not Curses.fits(Curses.BERSERKERS_WORLD, [Curses.PACIFIST_HANDS], 99),
			"a curse fits the skulls left, and still not beside one it cannot stand with")

	# No Second Chances: one more orb a wall, added to the Long Winter's.
	var gambler := Inventory.new()
	gambler.curses = [Curses.NO_SECOND_CHANCES]
	_check(gambler.credit_walls(1) and gambler.super_orbs == 2, "a wall under No Second Chances pays two")
	gambler.curses = [Curses.LONG_WINTER, Curses.NO_SECOND_CHANCES]
	_check(gambler.credit_walls(2) and gambler.super_orbs == 5, "and three under both")

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
	_check(older.homeland.is_empty() and older.uniques_doubled == [ids[0]], "a version 19 save has no homeland, and junk is dropped")
	_check(settler.transcended().homeland.is_empty(), "the next world chooses its own")
	_clear_save()
	return true
