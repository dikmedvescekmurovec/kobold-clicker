extends "res://tests/inventory_base.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   python tests/run_all.py inventory_gear
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.


func _run() -> void:
	_clear_save()
	_check(_test_items() == true, "item tests ran to the end")
	_check(_test_slot_locks() == true, "slot lock tests ran to the end")
	_check(_test_sockets() == true, "socket tests ran to the end")
	_check(_test_totals() == true, "stat total tests ran to the end")
	_check(_test_wearing() == true, "wearing tests ran to the end")
	_check(_test_two_handed() == true, "two-handed tests ran to the end")
	_check(_test_chances() == true, "drop-chance tests ran to the end")
	_check(_test_rarity_tables() == true, "rarity table tests ran to the end")
	_check(_test_rarity_rolls() == true, "rarity roll tests ran to the end")
	_check(_test_modifier_tables() == true, "modifier table tests ran to the end")
	_check(_test_modifier_rolls() == true, "modifier roll tests ran to the end")
	_check(_test_deeper_pools() == true, "deeper pool tests ran to the end")
	_check(_test_defence_pools() == true, "helmet, body and offhand pool tests ran to the end")
	_check(_test_rolls() == true, "drop tests ran to the end")
	_check(_test_a_fight_drops() == true, "fight drop tests ran to the end")
	_check(_test_drops_cascade() == true, "cascading drop tests ran to the end")
	_check(_test_the_promised_elite() == true, "promised elite tests ran to the end")
	_check(_test_promised_finds() == true, "promised find tests ran to the end")
	_check(_test_counts() == true, "counting tests ran to the end")
	_clear_save()
	_report("inventory: gear")


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
		_check(int(LootTable.ITEMS[item]["weight"]) > 0 or item in [LootTable.FIRST_DROP, LootTable.BROKEN_TORCH]
				or LootTable.slot_of(item) == SkillTree.SLOT, item + " can come up at all")
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
		# bare key, a global on a base stat takes its PERCENT's place rather than saying the same thing
		# beside it, and one no GLOBAL modifier names is a permission nothing can use.
		var pool := ModifierTable.pool_for(item)
		for stat: String in LootTable.globals_of(item):
			_check(LootTable.STAT_LABELS.has(stat), "%s has no label for global %s" % [item, stat])
			for id: String in pool:
				var rolled: Dictionary = ModifierTable.MODS[id]
				_check(not (rolled["kind"] == ModifierTable.Kind.PERCENT and rolled["stat"] == stat),
						"%s scales %s globally and rolls %s beside it" % [item, stat, id])
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
	var boot := Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng)
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
	var bag := _hero()
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
		tight.add(_plain("Leather Boots"))
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
		packed.add(_plain("Leather Boots"))
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
		# A torch may roll it too, the map's piece; only a boot shows it.
		"move_speed": ["boot", "greaves", "torch", "broken_torch"],
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
		# A signed one is worth something either side of nothing (`_test_defence_pools`).
		_check(int(band[0]) > 0 or mod.get("signed", false), id + " is worth something")
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
			# A skill stone's lines are listed by id (`SkillTree.LINES`), not let on by a gate.
			carried = carried or id in SkillTree.LINES.get(item, {})
		# Unless it is one of the ones held back on purpose, which have to be named rather than
		# inferred: a modifier nothing can roll is dead weight, and a dormant one is a system waiting.
		var held_back: bool = id in ModifierTable.DORMANT or id in ModifierTable.UNIQUE_ONLY
		_check(carried or held_back, "%s names %s, which no item can roll" % [id, stat])
		# A dormant line may pass a piece's gate; it is the pools that leave it out.
		var pooled := false
		for item in LootTable.items():
			pooled = pooled or id in ModifierTable.pool_for(item)
		_check(not (pooled and held_back), "%s is listed as held back and can be rolled" % id)
		_check(not ModifierTable.line({"id": id, "value": int(band[1])}).is_empty(), id + " writes a line")
	_check(ModifierTable.line({"id": "nonsense", "value": 1}).is_empty(), "an unknown modifier writes nothing")

	# Every pool has to be deep enough to fill the largest band and the one line more an Orb of Expansion
	# adds to it, or an elite piece comes up short.
	for item in LootTable.items():
		var most := int(ItemRarity.band(ItemRarity.Rarity.ELITE, item)[1]) + 1
		var pool := ModifierTable.pool_for(item)
		_check(pool.size() >= most,
				"%s can only carry %d modifiers, short of %d" % [item, pool.size(), most])
	return true


## The lines the weapons, the rings and the amulets gained (2026-10-07): who may roll each, the global
## that takes a ring's own percent's place, and the amulet's line of all three attributes.
func _test_deeper_pools() -> bool:
	var weapon_lines := ["added_click_damage", "added_swing_damage", "added_elite_damage", "added_first_blow",
		"added_double_strike"]
	var ring_lines := ["added_gold_find", "added_elite_chance", "global_increased_crit",
		"global_increased_crit_damage"]
	var amulet_lines := ["added_all_attributes", "global_increased_bleed", "global_increased_time_on_hit"]
	for item in LootTable.items():
		var pool := ModifierTable.pool_for(item)
		var slot := LootTable.slot_of(item)
		# A skill stone's pool is its base's (`_test_stones`), whichever socket's lines those are.
		if slot == SkillTree.SLOT:
			continue
		for lines: Array in [[weapon_lines, "weapon"], [ring_lines, "ring"], [amulet_lines, "amulet"]]:
			for id: String in lines[0]:
				_check((id in pool) == (slot == lines[1]), "%s %s %s" % [item, "rolls" if slot == lines[1] else "never rolls", id])
		# Lines they share with other pieces: every ring rolls time on hit, orbs and experience (a helmet
		# and a torch do too, `_test_defence_pools`), every amulet the set's defence.
		var shared := {"ring": ["added_time_on_hit", "added_orb_find", "added_experience"],
			"amulet": ["global_increased_armor", "global_increased_dodge"]}
		for id: String in shared.get(slot, []):
			_check(id in pool, "%s rolls %s" % [item, id])
		# Bleed is the mace's alone, both shapes of it.
		var mace := LootTable.kind_of(item) == "mace"
		for id: String in ["increased_bleed", "added_bleed"]:
			_check((id in pool) == mace, "%s %s %s" % [item, "rolls" if mace else "never rolls", id])
	# The Iron Band and the Jade Ring scale their own stat for the whole set, and so not for themselves.
	for pair: Array in [["Iron Band", "armor"], ["Jade Ring", "dodge"]]:
		var pool := ModifierTable.pool_for(pair[0])
		_check(("global_increased_" + pair[1]) in pool and not ("increased_" + pair[1]) in pool,
				"the %s's %s is the set's" % pair)
	_check("increased_armor" in ModifierTable.pool_for("Wooden Shield"), "and a shield still scales its own")

	# All Attributes: a point of each, a line of the Patchwork Coat's count, and no stat of its own.
	var amulet := Item.new()
	amulet.type = "Ruby Amulet"
	amulet.stats = Item.scaled_stats(amulet.type, 1)
	amulet.mods = [{"id": "added_all_attributes", "value": 3}, {"id": "added_strength", "value": 2}]
	var player := _hero()
	player.equipment.equip(Equipment.Socket.AMULET, amulet)
	var points := player.attributes()
	_check(points["strength"] == 5.0 and points["dexterity"] == 3.0 and points["intelligence"] == 3.0,
			"all three take the line (%s)" % points)
	_check(player.gear_attributes() == points, "and the achievements read it the same")
	var stats := player.stats()
	_check(stats["strength"] == 5.0 and not stats.has(Inventory.ALL_ATTRIBUTES),
			"the fight sees each attribute and never the line itself (%s)" % [stats.keys()])
	_check(stats["attribute_lines"] == 2 and stats["pure_pieces"] == 0, "it counts as an attribute line")
	return true


## The lines the helmets, the body armour and the offhands gained (2026-10-07): who may roll each, each
## written as what it does and never as a name, the count of enemies either side of nothing, and a tree's
## ranks reaching the skills.
func _test_defence_pools() -> bool:
	var own := {
		"helmet": ["added_blow_delay", "added_elite_ward", "added_tile_ward", "added_less_health",
			"added_strength_stones", "added_dexterity_stones", "added_intelligence_stones"],
		"body": ["added_camp_earnings", "added_enemies", "added_thorns", "added_recoup"],
	}
	var held := {"buckler": ["added_parry"], "shield": ["added_time_on_block"],
		"torch": ["added_burn"], "broken_torch": ["added_burn"]}
	for item in LootTable.items():
		var pool := ModifierTable.pool_for(item)
		var slot := LootTable.slot_of(item)
		var kind := LootTable.kind_of(item)
		if slot == SkillTree.SLOT:
			continue
		for lines_slot: String in own:
			for id: String in own[lines_slot]:
				_check((id in pool) == (slot == lines_slot),
						"%s %s %s" % [item, "rolls" if slot == lines_slot else "never rolls", id])
		for id: String in ["added_parry", "added_time_on_block", "added_burn"]:
			var mine: bool = id in held.get(kind, [])
			_check((id in pool) == mine, "%s %s %s" % [item, "rolls" if mine else "never rolls", id])
		# Experience on a helmet and a torch beside the rings; a torch's move speed and orbs.
		if slot == "helmet" or kind in ["torch", "broken_torch"]:
			_check("added_experience" in pool, "%s rolls experience" % item)
		if kind in ["torch", "broken_torch"]:
			_check("added_move_speed" in pool and "added_orb_find" in pool, "%s rolls move speed and orbs" % item)

	# Each says what it does, its number in its place, and none opens on a name and a colon.
	var lines := {
		"added_blow_delay": [20, "Enemies' first blows come 20% later"],
		"added_elite_ward": [15, "15% less time lost to elites' and bosses' blows"],
		"added_tile_ward": [25, "Tile modifiers are 25% weaker"],
		"added_less_health": [8, "Enemies have 8% less health"],
		"added_strength_stones": [1, "+1 rank to every Strength Node holding a point"],
		"added_camp_earnings": [20, "Camps earn 20% more"],
		"added_enemies": [1, "+1 enemy in each fight"],
		"added_thorns": [30, "Blows that land on you strike back for 30% of your damage"],
		"added_recoup": [20, "20% of the time a blow takes comes back over 4 seconds"],
		"added_parry": [40, "A dodged blow adds 40% crit chance to your next blow"],
		"added_burn": [20, "Blows burn for 20% of their damage over 3 seconds"],
		"added_time_on_block": [3, "A blow your block stops entirely wins back 0.3s"],
	}
	for id: String in lines:
		var written := ModifierTable.line({"id": id, "value": lines[id][0]})
		_check(written == lines[id][1], "%s reads \"%s\"" % [id, written])
		_check(not RegEx.create_from_string("^[A-Z][A-Za-z' ]*:").search(written), "%s opens on no name" % id)
	_check(ModifierTable.line({"id": "added_enemies", "value": -2}) == "-2 enemies in each fight", "fewer reads as fewer")
	# The count's band is the table's: as far either way as `range` says, and as `wide` says from `wide_from`.
	var count: Dictionary = ModifierTable.MODS["added_enemies"]
	var wide := int(count["wide_from"])
	var near := int(count["range"][1])
	var far := int(count["wide"][1])
	var reach_line := func(reach: int) -> String:
		return "±%d %s in each fight" % [reach, "enemy" if reach == 1 else "enemies"]
	_check(ModifierTable.band_line("added_enemies", 1) == reach_line.call(near)
			and ModifierTable.band_line("added_enemies", wide) == reach_line.call(far),
			"the fortuneteller reads a count as its reach (%s)" % ModifierTable.band_line("added_enemies", wide))
	_check(ModifierTable.band_line("added_blow_delay", 1) == "Enemies' first blows come %d-%d%% later"
			% ModifierTable.MODS["added_blow_delay"]["range"], "and a sentence with its band in the number's place")

	# The count: its band either way, the wide one from its wide tier, never none, held to a band as a world ends.
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for tier: int in [1, wide - 1, wide, wide + 20]:
		var reach := far if tier >= wide else near
		var seen := {}
		for i in 400:
			var value := ModifierTable.reroll_value("added_enemies", rng, tier)
			seen[value] = true
		var want := range(-reach, reach + 1)
		want.erase(0)
		var got := seen.keys()
		got.sort()
		_check(got == want, "tier %d rolls %s (%s)" % [tier, want, got])
	_check(ModifierTable.rescaled("added_enemies", far, wide, 1) == near
			and ModifierTable.rescaled("added_enemies", -far, wide, 1) == -near,
			"the wide band either way is the narrow one either way back at the first level")
	var body := Item.new()
	body.type = "Steel Plate"
	body.level = wide
	body.stats = Item.scaled_stats(body.type, wide)
	body.mods = [{"id": "added_enemies", "value": -far}, {"id": "added_blow_delay", "value": 30}]
	var detailed := body.mod_lines(true)
	_check(detailed[0].begins_with("%d(±%d) enemies in each fight T" % [-far, far]),
			"a detailed count shows its reach (%s)" % detailed[0])

	# A base's ranks: on every stone of that base holding a point, none of another's, both dolls.
	var player := Inventory.new()
	player.level = 2
	player.skills.stones["0"] = _node("Strength Node", "added_damage")
	player.rank_up_skill("0")
	var damage := func() -> float:
		var tree := player._tree()
		return float(player.skills.flat(tree[0], tree[1]).get("damage", 0.0))
	var before: float = damage.call()
	var helm := Item.new()
	helm.type = "Leather Helmet"
	helm.stats = Item.scaled_stats(helm.type, 1)
	helm.mods = [{"id": "added_intelligence_stones", "value": 1}]
	player.equipment.equip(Equipment.Socket.HELMET, helm)
	_check(before > 0.0 and damage.call() == before, "another base's rank adds nothing to the strength stone")
	helm.mods = [{"id": "added_strength_stones", "value": 1}]
	_check(damage.call() == before * 2.0, "a strength rank doubles its one rank (%s, %s)" % [before, damage.call()])
	player.stash().equipment.equip(Equipment.Socket.HELMET, Item.from_dict(helm.to_dict()))
	_check(damage.call() == before * 3.0, "and the heirlooms' helmet's rank as well")
	# A helmet saved with a rank on one of the old trees reads as the base that took the tree's place.
	var old := helm.to_dict()
	old["mods"] = [{"id": "added_power_skills", "value": 1}]
	_check(Item.from_dict(old).mods[0]["id"] == "added_strength_stones", "a Power rank saved is a strength stone's")
	return true


## What a rolled item carries: never twice the same, never a stat it hasn't got, always in range.
func _test_modifier_rolls() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for item_type in LootTable.items():
		var stats := LootTable.stats_of(item_type)
		for step: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON,
				ItemRarity.Rarity.RARE, ItemRarity.Rarity.ELITE]:
			var band: Array = ItemRarity.band(step, item_type)
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
					var range_band: Array = ModifierTable.band_for(id, item.tier_of(mod)) if item.is_stone() \
							else entry["range"]
					_check(typeof(mod["value"]) == TYPE_INT, id + " rolled a whole number")
					_check(mod["value"] >= int(range_band[0]) and mod["value"] <= int(range_band[1]),
							"%s rolled %d, outside %s" % [id, mod["value"], range_band])
					# The rule the whole table turns on: a PERCENT modifier scales a base stat, so the
					# piece must have one; a FLAT one only has to be allowed to carry the stat.
					if entry["kind"] == ModifierTable.Kind.PERCENT:
						_check(stats.has(entry["stat"]),
								"%s rolled %s, scaling a base stat it hasn't got" % [item_type, id])
					elif item.is_stone():
						_check(id in SkillTree.lines_for(item_type, item.stone_tier),
								"a tier %d %s rolled %s, which it has not unlocked" % [item.stone_tier, item_type, id])
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

	# A kind whose first material a level-1 piece has not reached (the greaves) is dealt as its slot's
	# plainest piece, so its weight is that kind's here.
	var total_weight := 0
	var weight_of := {}
	for kind: String in LootTable.KINDS:
		var weight := int(LootTable.KINDS[kind]["weight"])
		total_weight += weight
		var dealt := kind
		if LootTable.first_level(kind) > 1:
			dealt = str(LootTable.ITEMS[LootTable._first_of_slot(str(LootTable.KINDS[kind]["slot"]))]["kind"])
		weight_of[dealt] = int(weight_of.get(dealt, 0)) + weight
	_check(LootTable.tier_at("greaves", 2, rng) == "Leather Boots"
			and LootTable.tier_at("greaves", 3, rng) == "Iron Greaves"
			and int(LootTable.ITEMS["Iron Greaves"]["material"]) == int(LootTable.ITEMS["Iron Helmet"]["material"]),
			"the greaves begin at iron, worth iron's step, and under it are dealt as a Leather Boots")
	for kind: String in LootTable.KINDS:
		var share := float(mix.get(kind, 0)) / SHAPE_ROLLS
		var want := float(weight_of.get(kind, 0)) / total_weight
		_check(absf(share - want) < _tolerance(want, SHAPE_ROLLS),
				"%s came up %.3f of the time, not %.3f" % [kind, share, want])

	# The tile's level picks the material, never the piece's own: every material its level has
	# unlocked, the plainest among them, and nothing past -- a boss's piece two levels over the tile
	# included. A material every two levels: 1-2 the first, 3-4 the first two, on to all five from 9.
	for ring: Array in [[0, 1], [11, 1], [12, 2], [23, 2], [24, 3], [36, 4]]:
		_check(MapBuilder.circle_of(Vector2i(int(ring[0]), 0)) == int(ring[1]),
				"ring %d is circle %d (%d)" % [ring[0], ring[1], MapBuilder.circle_of(Vector2i(int(ring[0]), 0))])
	var boss := ""
	for body: String in EnemyRoster.ENEMIES:
		if EnemyRoster.tier_of(body) == EnemyRoster.Tier.BOSS:
			boss = body
			break
	for tile_level in range(1, 11):
		var seen := {}
		for i in 1000:
			var piece := LootTable.roll(boss, rng, true, tile_level)
			var row: Dictionary = LootTable.ITEMS[piece.type]
			var kind: Dictionary = LootTable.KINDS[row["kind"]]
			if not kind.has("tier_levels") and kind["tiers"].size() == 5:
				seen[int(row["tier"])] = true
		var want := range(mini(int((tile_level - 1) / 2.0), 4) + 1)
		var got := seen.keys()
		got.sort()
		_check(got == want, "a level-%d tile deals materials %s, not %s" % [tile_level, want, got])

	# The run's first find: a fight told to drop a sword drops one, once, and then goes back to the table.
	for attempt in 20:
		var first := Encounter.for_tile(Vector2i(2, 2), "grass")
		first.loot_rng.seed = attempt
		first.always_drop = true
		first.promised = [Encounter.SWORD]
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
		_check(Encounter.SWORD not in first.promised, "and the promise is spent")
	var kinds := {}
	for attempt in 20:
		var fight := Encounter.for_tile(Vector2i(2, 2), "grass")
		fight.loot_rng.seed = attempt
		fight.always_drop = true
		fight.promised = [Encounter.SWORD]
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


## What a new player's first kills are scripted to leave (`Encounter.PROMISED`): each once, on one of
## its own kills -- any of them, the last for certain -- and only while it is owed (`Inventory.promised`).
## The kills are read off the table, so retuning them moves nothing here.
func _test_promised_finds() -> bool:
	var sword: Array = Encounter.PROMISED[Encounter.SWORD]
	var first: Array = Encounter.PROMISED[Encounter.TRANSMUTE]
	var second: Array = Encounter.PROMISED[Encounter.AUGMENT]
	var unique: Array = Encounter.PROMISED[Encounter.UNIQUE]
	var node: Array = Encounter.PROMISED[Encounter.NODE]
	var sword_kills := {}
	var early := 30
	for attempt in 30:
		# The sword is the first piece of gear, by the last of its kills, and one sword only.
		var armed := _owed_run([Encounter.SWORD], int(sword[0]), attempt)
		var gear: Array = []
		armed.loot_dropped.connect(func(index: int, item: Item) -> void: gear.append([index + 1, item.type]))
		_kill_more(armed, int(sword[1]) - int(sword[0]))
		_check(not gear.is_empty() and gear[0][1] == LootTable.FIRST_DROP,
				"the Broken Sword is the first piece, inside its kills: %s" % [gear])
		_check(gear.filter(func(found: Array) -> bool: return found[1] == LootTable.FIRST_DROP).size() == 1
				and Encounter.SWORD not in armed.promised, "once, and the promise is spent")
		if not gear.is_empty():
			sword_kills[gear[0][0]] = true

		# The two orbs in their order, each inside its own kills, through the gate that holds every other.
		var crafted := _owed_run([Encounter.TRANSMUTE, Encounter.AUGMENT], 0, attempt)
		crafted.orbs_after = 1000000
		var orbs: Array = []
		crafted.orb_dropped.connect(func(index: int, orb: String) -> void: orbs.append([index + 1, orb]))
		_kill_more(crafted, int(second[1]) + early)
		_check(orbs.size() == 2 and orbs[0][1] == OrbTable.FIRST_ORB and orbs[1][1] == OrbTable.SECOND_ORB,
				"a Transmutation and then an Augmentation, and nothing else: %s" % [orbs])
		if orbs.size() == 2:
			_check(orbs[0][0] > first[0] and orbs[0][0] <= first[1] and orbs[1][0] > second[0]
					and orbs[1][0] <= second[1], "each inside its own kills: %s" % [orbs])
		_check(crafted.promised.is_empty(), "and both promises are spent")

		# The last of a promise's kills is certain.
		var last := _owed_run([Encounter.TRANSMUTE], int(first[1]) - 1, attempt)
		last.orbs_after = 1000000
		var last_orbs: Array = []
		last.orb_dropped.connect(func(_index: int, orb: String) -> void: last_orbs.append(orb))
		_kill_more(last, 1)
		_check(last_orbs == [OrbTable.FIRST_ORB], "the last of its kills leaves it for certain: %s" % [last_orbs])

		# The first unique is the one row, with no luck in it.
		var lucky := _owed_run([Encounter.UNIQUE], int(unique[0]), attempt)
		var uniques: Array = []
		lucky.loot_dropped.connect(func(index: int, item: Item) -> void:
			if not item.unique.is_empty():
				uniques.append([index + 1, item.unique]))
		_kill_more(lucky, int(unique[1]) - int(unique[0]) + early)
		_check(uniques.size() == 1 and uniques[0][1] == UniqueTable.FIRST_UNIQUE
				and uniques[0][0] <= int(unique[1]) - int(unique[0]),
				"the promised unique falls inside its kills, once: %s" % [uniques])

		# No node before the promised one, which is a common Strength Node with every connector; the
		# table's own come after it. A drop rate that makes a node one body in four where it may fall.
		var taught := _owed_run([Encounter.NODE], int(node[0]) - early, attempt)
		taught.stone_drops = true
		taught.drop_rate = 1.0e6
		var nodes: Array = []
		taught.loot_dropped.connect(func(index: int, item: Item) -> void:
			if item.is_stone():
				nodes.append([index + 1, item]))
		_kill_more(taught, early + int(node[1]) - int(node[0]) + early)
		_check(nodes.size() > 1, "the promised node falls, and others after it (%d)" % nodes.size())
		if not nodes.is_empty():
			var stone: Item = nodes[0][1]
			_check(nodes[0][0] > early and nodes[0][0] <= early + int(node[1]) - int(node[0]),
					"no node before the promised one's kills: the first at %d" % nodes[0][0])
			_check(stone.type == SkillTree.BASES[0] and stone.rarity == ItemRarity.Rarity.COMMON
					and stone.connectors == SkillTree.MOST_CONNECTORS and stone.capstone.is_empty()
					and stone.stone_tier >= 1, "and it is a common Strength Node with every connector")
	_check(sword_kills.size() > 1, "the sword falls on any of its kills, not one of them (%s)" % [sword_kills.keys()])

	# What a player is still owed: never had, and its kills not run out.
	var hero := Inventory.new()
	_check(hero.promised() == Encounter.PROMISED.keys(), "a new player is owed every one")
	hero.kills = int(first[1])
	_check(Encounter.TRANSMUTE not in hero.promised() and Encounter.AUGMENT in hero.promised(),
			"a promise whose kills have run out is owed no longer")
	var ledger := FightLedger.new(hero, TEST_PATH, true)
	ledger.add_orb(OrbTable.SECOND_ORB)
	_check(Encounter.AUGMENT not in hero.promised(), "an Augmentation spends its promise")
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	ledger.add_loot(SkillTree.first(Encounter.farm(MapBuilder.CENTER, "grass").lineup[0], rng))
	_check(hero.promised() == [Encounter.UNIQUE], "a node its own, and any find the sword's: %s" % [hero.promised()])
	ledger.add_loot(Item.rolled_unique("snowball", rng, 1))
	_check(hero.promised().is_empty(), "and any unique in the collection log the first unique's")
	_check(Inventory.new().transcended().promised().is_empty(), "a second world is owed none")
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
	inventory.add(Item.rolled("Leather Boots", ItemRarity.Rarity.COMMON, rng))
	_check(inventory.count("Wooden Sword") == 2, "two swords are two")
	_check(inventory.total() == 3, "three things in all")
	_check(inventory.items[0].rarity == ItemRarity.Rarity.RARE, "and each is its own item")
	_check(inventory.remove(sword), "an item can be taken back out")
	_check(inventory.total() == 2 and inventory.count("Wooden Sword") == 1, "and then it is gone")
	return true
