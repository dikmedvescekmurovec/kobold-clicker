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
	_check(_test_slot_locks() == true, "slot lock tests ran to the end")
	_check(_test_sockets() == true, "socket tests ran to the end")
	_check(_test_totals() == true, "stat total tests ran to the end")
	_check(_test_wearing() == true, "wearing tests ran to the end")
	_check(_test_chances() == true, "drop-chance tests ran to the end")
	_check(_test_rarity_tables() == true, "rarity table tests ran to the end")
	_check(_test_rarity_rolls() == true, "rarity roll tests ran to the end")
	_check(_test_modifier_tables() == true, "modifier table tests ran to the end")
	_check(_test_modifier_rolls() == true, "modifier roll tests ran to the end")
	_check(_test_rolls() == true, "drop tests ran to the end")
	_check(_test_a_fight_drops() == true, "fight drop tests ran to the end")
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
	_check(gear.equip(Equipment.Socket.HELMET, boot) == null
			and gear.item_at(Equipment.Socket.HELMET) == null, "a boot will not go on the head")

	# The shared offhand: a shield and a torch both fit it, and the second one in displaces the first.
	var shield := Item.rolled("Wooden Shield", ItemRarity.Rarity.COMMON, rng)
	var torch := Item.rolled("Wooden Torch", ItemRarity.Rarity.COMMON, rng)
	_check(gear.sockets_for(shield) == [Equipment.Socket.OFFHAND], "a shield fits only the offhand")
	_check(gear.sockets_for(torch) == [Equipment.Socket.OFFHAND], "and so does a torch")
	gear.equip(Equipment.Socket.OFFHAND, shield)
	_check(gear.equip(Equipment.Socket.OFFHAND, torch) == shield, "the torch puts the shield back")
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
	var one: float = float(LootTable.stats_of("Gold Ring")["drop_rate"])
	_check(is_equal_approx(two.totals()["drop_rate"], one * 2.0), "two rings are worth two rings")

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


## The stats that belong to one piece and must stay there. Offence on the weapon is the rule the
## whole table is built on -- damage anywhere else and the sword stops being the interesting slot --
## and the other two are locked by what the piece is: you walk in boots and you block with a thing
## you hold. Pinned here so a later widening of the tables cannot quietly undo the design.
func _test_slot_locks() -> bool:
	var locked := {
		# Base damage is still the sword's, but the jewellery carries damage as an affix now -- what
		# is locked is where a click's damage *comes from*, not everything that can add to it.
		"damage": ["Wooden Sword", "Gold Ring", "Ruby Amulet"],
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
			_check(row.has(step), "tier %d has a weight for rarity %d" % [tier, step])
			total += int(row[step])
		_check(total > 0, "tier %d can roll something" % tier)
		# Uniques are hand-crafted and belong to a later chunk. This is what fails loudly and
		# usefully on the day they are switched on.
		_check(int(row[ItemRarity.Rarity.UNIQUE]) == 0, "tier %d cannot roll a unique" % tier)

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
		if mod["kind"] == ModifierTable.Kind.PLAYER:
			_check(not str(mod["line"]).is_empty(), id + " says what it does")
			continue
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
		_check(carried or id in ModifierTable.DORMANT,
				"%s names %s, which no item can roll" % [id, stat])
		_check(not (carried and id in ModifierTable.DORMANT),
				"%s is listed as dormant and can be rolled" % id)
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
		mix[item.type] = int(mix.get(item.type, 0)) + 1
		rarities[item.rarity] = int(rarities.get(item.rarity, 0)) + 1

	var total_weight := 0
	for item: String in LootTable.ITEMS:
		total_weight += int(LootTable.ITEMS[item]["weight"])
	for item: String in LootTable.ITEMS:
		var share := float(mix.get(item, 0)) / SHAPE_ROLLS
		var want := float(LootTable.ITEMS[item]["weight"]) / total_weight
		_check(absf(share - want) < 0.05, "%s came up %.2f of the time, not %.2f" % [item, share, want])

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
	inventory.gold = 1234
	_check(inventory.save(TEST_PATH), "the inventory saved")

	var loaded := Inventory.load_from(TEST_PATH)
	_check(loaded.total() == inventory.total(),
			"everything came back: %d of %d" % [loaded.total(), inventory.total()])
	for i in mini(loaded.total(), inventory.total()):
		_check(_fingerprint(loaded.items[i]) == _fingerprint(inventory.items[i]),
				"item %d came back as it went in: %s" % [i, _fingerprint(loaded.items[i])])
	_check(loaded.first_elite_taken, "and so did the promised elite")
	_check(loaded.gold == 1234, "and the purse, at %d" % loaded.gold)

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
	_check(migrated.first_elite_taken, "and it is still remembered")
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

	# A bag from before the cap, or one edited by hand. It comes back obeying the cap, because a bag
	# allowed over it in one place is a bag every other rule in the game has to check for.
	var bloated := Inventory.new()
	for i in Inventory.CAPACITY + 5:
		bloated.items.append(_piece(
				ItemRarity.Rarity.RARE if i >= 5 else ItemRarity.Rarity.COMMON, 6))
	_check(bloated.save(TEST_PATH), "an over-full save is written")
	var trimmed := Inventory.load_from(TEST_PATH)
	_check(trimmed.total() == Inventory.CAPACITY, "and comes back at the cap")
	var kept_commons := 0
	for item in trimmed.items:
		if item.rarity == ItemRarity.Rarity.COMMON:
			kept_commons += 1
	_check(kept_commons == 0, "having dropped the worst of it")
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
	_check(main.bag_page.visible and not main._bag_button.visible, "the panel takes the button's place")
	_check(is_zero_approx(main.bag_page._panel.position.x), "and sits against the left edge")
	_check(not main.bag_page._detail.visible, "with no stat block until a square is clicked")
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
	_check(main.bag_page._detail.visible, "the sword's stat block opens")
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
	_check(main.bag_page._detail.visible, "a worn piece opens the same way")
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
	_check(combat._gold_row.visible and combat._gold_label.text == "+%d" % fight.gold,
			"and the verdict says so: %s" % combat._gold_label.text)
	_check(combat._result_drops.count() == combat._drops.size(),
			"the fight's panel shows everything that fell: %d of %d" % [
					combat._result_drops.count(), combat._drops.size()])
	_check(combat._loot_button.text == str(combat._drops.size()),
			"and so does the counter in the corner")

	# A drop on that panel opens what it actually is, and goes back again.
	await process_frame
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
	_check(main.inventory.first_elite_taken, "and is not promised again")
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
	_check(main.bag_page._detail.visible, "clicking a square opens its stat block")
	var newest: Item = main.inventory.items[0]
	# Read out of the whole block, not off its direct children: the lines live inside the scroll that
	# keeps a long piece from pushing Equip off the bottom of the panel.
	var block := _texts(main.bag_page._detail)
	_check(newest.display_name() in block, "which names the item")
	_check("%s · level %d" % [newest.rarity_name(), newest.level] in block,
			"and its rarity and level")
	main.bag_page._select_item(-1)
	await process_frame
	_check(not main.bag_page._detail.visible, "and it closes again")

	# The hand-written gesture: a press that stays put opens a square, one that travels scrolls the
	# grid and opens nothing. Driven straight at the handler, because a headless run has no mouse.
	var first: Control = _bag_squares(main)[0]
	var on_first := _square_spot(first)
	_press(main, on_first, true)
	_press(main, on_first, false)
	await process_frame
	_check(main.bag_page._detail.visible, "a press that stays put is a click")
	main.bag_page._select_item(-1)
	_press(main, on_first, true)
	_drag(main, on_first, BagPage.DRAG_THRESHOLD * 4.0)
	_press(main, on_first, false)
	await process_frame
	_check(not main.bag_page._detail.visible, "a press that travels is a drag, and opens nothing")

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
	main._on_chart_pressed()
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


## Every square the bag is showing, in the order the sections lay them out. The grid is no longer one
## rectangle, so a test asking what the bag holds has to walk the sections the way the click does.
func _bag_squares(main: Node) -> Array:
	var squares := []
	for section: Node in main.bag_page._sections.get_children():
		if not (section is GridContainer):
			continue
		for slot: Node in section.get_children():
			squares.append(slot)
	return squares


## Every socket square on the doll, or nothing at all when the comparison has taken its place. It is
## the same list `_on_doll_input` hit-tests against, and whether it is empty is how a test tells the
## page's two states apart.
func _socket_squares(main: Node) -> Array:
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


## An item built to order, for the tests that care about where a piece sorts rather than what it
## rolled. `Item.rolled` needs a generator and rolls modifiers; these want neither.
func _piece(rarity: ItemRarity.Rarity, level: int) -> Item:
	var item := Item.new()
	item.type = "Wooden Sword"
	item.rarity = rarity
	item.level = level
	item.stats = Item.scaled_stats(item.type, level)
	return item


## The bag is read one way and emptied another, and both are checked here: level-major for the
## player looking for a piece, rarity-major for the game deciding what has to go.
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

	var doomed: Array[Item] = []
	for i in bag.worst_first():
		doomed.append(bag.items[i])
	_check(doomed == [l5_common_old, l5_common_new, l9_common, l5_rare, l2_elite],
			"and empties by rarity, then level, then oldest first")

	# The whole reason there are two: the plainest piece goes first even though it is not the lowest,
	# and the level-2 elite outlives the level-9 common.
	var backwards := bag.order().duplicate()
	backwards.reverse()
	_check(backwards != bag.worst_first(),
			"the two orders are not one reversed -- level-major to read, rarity-major to destroy")
	_check(bag.levels() == [9, 5, 2], "and the sections run highest level first")
	_check(bag.count_at(5) == 3 and bag.count_at(9) == 1 and bag.count_at(1) == 0,
			"with the right number in each")
	return true


## The bag has a bottom to it, and the worst is what falls out of it.
func _test_capacity() -> bool:
	var bag := Inventory.new()
	var destroyed: Array[Item] = []
	for i in Inventory.CAPACITY:
		destroyed = bag.add(_piece(ItemRarity.Rarity.RARE, 5))
	_check(bag.total() == Inventory.CAPACITY, "the bag fills to the cap")
	_check(destroyed.is_empty(), "with nothing destroyed on the way")
	_check(bag.is_full() and bag.room_left() == 0, "and says it is full")

	# A common falling into a bag of rares is the worst thing in it, so it is what goes. Nothing is
	# lost that was better than what arrived, which is the whole promise.
	var common := _piece(ItemRarity.Rarity.COMMON, 9)
	destroyed = bag.add(common)
	_check(destroyed == [common], "a find worse than everything held is what gets destroyed")
	_check(bag.total() == Inventory.CAPACITY and not bag.items.has(common),
			"and the bag is unchanged")

	var elite := _piece(ItemRarity.Rarity.ELITE, 1)
	destroyed = bag.add(elite)
	_check(destroyed.size() == 1 and destroyed[0].rarity == ItemRarity.Rarity.RARE,
			"a find better than the worst held destroys that one instead")
	_check(bag.items.has(elite), "and is kept")

	# Five at once, into a bag that is already at the cap.
	var over := Inventory.new()
	for i in Inventory.CAPACITY + 5:
		over.add(_piece(ItemRarity.Rarity.RARE if i >= 5 else ItemRarity.Rarity.COMMON, 3))
	_check(over.total() == Inventory.CAPACITY, "five too many leaves the cap")
	var commons := 0
	for item in over.items:
		if item.rarity == ItemRarity.Rarity.COMMON:
			commons += 1
	_check(commons == 0, "and the five commons are the five that went")

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

	# A level-1 piece is exactly the piece the table describes: nothing about the game as it was moved.
	for type in LootTable.items():
		var plain := Item.rolled(type, ItemRarity.Rarity.COMMON, rng, 1)
		_check(plain.level == 1, "%s rolled at level 1 is level 1" % type)
		for stat: String in LootTable.stats_of(type):
			_check(is_equal_approx(float(plain.base_stats()[stat]), float(LootTable.stats_of(type)[stat])),
					"a level-1 %s still has %s %s" % [type, stat, LootTable.stats_of(type)[stat]])

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
		_check(stat in LootTable.PERCENT_STATS, "%s is written as a percentage" % stat)
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
				ModifierTable.Kind.FLAT:
					# The stat's own per-level step, unless the entry names a smaller one of its own --
					# which `added_damage` does, its band being sized for a piece that has no damage.
					var step: float = float(entry.get("level_flat",
							LootTable.LEVEL_FLAT.get(entry["stat"], 0.0)))
					var low := maxi(1, roundi(LootTable.scale(entry["stat"], float(band[0]), level, step)))
					var high := maxi(1, roundi(LootTable.scale(entry["stat"], float(band[1]), level, step)))
					_check(value >= low and value <= high,
							"%s rolled %d at level %d, outside %d-%d" % [mod["id"], value, level, low, high])
				ModifierTable.Kind.PERCENT, ModifierTable.Kind.GLOBAL:
					var grow := pow(LootTable.LEVEL_GROWTH, level - 1)
					_check(value >= maxi(1, roundi(int(band[0]) * grow))
							and value <= maxi(1, roundi(int(band[1]) * grow)),
							"%s rolled %d at level %d, outside its multiplied band" % [mod["id"], value, level])
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
	worse.stats = {"damage": 12.0, "crit_chance": 6.0, "health": 30.0}

	var change := ItemDetails.deltas(better, worse)
	_check(change.get("damage") == 8.0, "a stat both have is the difference: %s" % change.get("damage"))
	_check(change.get("armor") == 5.0, "a stat only the new piece has is the whole of it")
	_check(change.get("health") == -30.0, "and one only the old piece has is the whole of it, lost")
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
	_check(ItemDetails.deltas(hair, hair_worse).is_empty(),
			"a difference too small to print is left out")

	# And the spelling, which lives beside stat_line for the reason stat_line gives.
	_check(LootTable.stat_delta("damage", 8.0) == "Damage +8", "a gain is written with its sign")
	_check(LootTable.stat_delta("health", -30.0) == "Health -30", "and a loss with its own")
	_check(LootTable.stat_delta("crit_chance", 3.0) == "Crit Chance +3%", "a percentage keeps its sign")
	_check(LootTable.stat_delta("attack_speed", 0.3) == "Attack Speed +0.3/s", "and so does a rate")
	return true


func _line_of(item: Item) -> String:
	return "%s · level %d" % [item.rarity_name(), item.level]


## The side-by-side: what is selected in the bag, and what it would replace on the page beside it.
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
	var beside := _texts(main.bag_page._worn_body)
	_check("Equipped · %s" % Equipment.LABELS[Equipment.Socket.WEAPON] in beside,
			"selecting a sword names the socket it would go in: %s" % beside)
	_check(weak.display_name() in beside, "and shows the sword already in it")
	_check("%s · level %d" % [weak.rarity_name(), weak.level] in beside, "with its rarity and level")
	_check(_socket_squares(main).is_empty(), "and the doll is out of the way while it does")

	# The comparison is the piece beside it and nothing else: the stat block says what the selected
	# piece is, never what the swap would be worth in signed numbers.
	var change := ItemDetails.deltas(strong, weak)
	_check(change.has("damage") and change["damage"] > 0.0, "the better sword hits harder")
	var block := _texts(main.bag_page._detail)
	_check(strong.display_name() in block, "the block names the piece that is open: %s" % block)
	for stat: String in change:
		_check(not (LootTable.stat_delta(stat, change[stat]) in block),
				"and says nothing about what %s would do: %s" % [stat, block])

	# Taking the worn piece off from here keeps the piece being judged open -- it is the whole point
	# of standing them side by side, and the index it sits at has just moved.
	main.bag_page._on_compare_unequip_pressed(strong, Equipment.Socket.WEAPON)
	for i in 2:
		await process_frame
	_check(main.inventory.equipment.item_at(Equipment.Socket.WEAPON) == null, "Unequip takes it off")
	_check(main.inventory.items.has(weak), "and gives it back to the bag")
	_check(main.bag_page._selected == main.inventory.items.find(strong),
			"and the sword being judged is still the one open")
	_check("Nothing worn" in _texts(main.bag_page._worn_body), "with an empty socket beside it")

	# A boot on the feet is not what a sword would replace: the page compares against the socket the
	# Equip button targets and nothing else.
	var boot := Item.new()
	boot.type = "Leather Boot"
	boot.rarity = ItemRarity.Rarity.COMMON
	boot.level = 1
	boot.stats = Item.scaled_stats(boot.type, 1)
	main.inventory.add(boot)
	main.inventory.equip(boot, Equipment.Socket.BOOTS)
	main.bag_page._select_item(main.inventory.items.find(strong))
	for i in 2:
		await process_frame
	var still := _texts(main.bag_page._worn_body)
	_check("Nothing worn" in still, "a worn boot leaves the weapon socket empty")
	_check(not (boot.display_name() in still), "and is not what the sword is compared against")

	# Two rings worn and a third open: Swap turns the page to the other finger, and Equip with it.
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
	_check(_line_of(rings[0]) in _texts(main.bag_page._worn_body), "a ring is judged against the left one first")
	main.bag_page._on_swap_pressed()
	_check(_line_of(rings[1]) in _texts(main.bag_page._worn_body), "Swap turns to the right one")
	main.bag_page._on_fold_pressed()
	var folded := _texts(main.bag_page._worn_body)
	_check(not main.bag_page._worn_panel.visible and main.bag_page._show_button.visible,
			"Hide takes the whole panel away and leaves Show in its place")
	_check(not (_line_of(rings[1]) in folded), "Hide folds the block away: %s" % folded)
	main.bag_page._on_fold_pressed()
	for button: Button in main.bag_page._detail.find_children("", "Button", true, false):
		if button.text == "Equip":
			button.pressed.emit()
	_check(main.inventory.equipment.item_at(Equipment.Socket.RING_RIGHT) == rings[2]
			and main.inventory.equipment.item_at(Equipment.Socket.RING_LEFT) == rings[0],
			"and Equip replaces the ring that was showing")

	main.bag_page._select_item(-1)
	await process_frame
	_check(_socket_squares(main).size() == Equipment.sockets().size(),
			"closing the block brings the doll back, with every socket on it")
	# The doll folds away by the same flag, so it stays put away when a piece is opened.
	main.bag_page._on_fold_pressed()
	_check(not main.bag_page._worn_panel.visible and main.bag_page._show_button.visible,
			"Hide takes the doll away too and leaves Show in its place")
	main.bag_page._select_item(0)
	_check(not main.bag_page._worn_panel.visible, "and the comparison stays hidden with it")
	main.bag_page._on_fold_pressed()
	main.bag_page._select_item(-1)
	_check(main.bag_page._worn_panel.visible and not main.bag_page._show_button.visible,
			"Show brings the doll back")
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
	_check(not OrbTable.can_apply("Orb of Transmutation", common), "an uncommon cannot be transmuted")
	_check(not OrbTable.why_not("Orb of Transmutation", common).is_empty(),
			"a refused transmutation says why")

	var magic := Item.rolled("Wooden Shield", ItemRarity.Rarity.UNCOMMON, rng, 3)

	# --- Alteration: rerolls an uncommon, and it stays uncommon ---
	_check(OrbTable.can_apply("Orb of Alteration", magic), "an uncommon can be altered")
	_check(OrbTable.apply("Orb of Alteration", magic, rng), "alteration lands")
	_check(magic.rarity == ItemRarity.Rarity.UNCOMMON, "alteration keeps the rarity")

	# --- Alchemy: one step at a time, and never as far as unique ---
	var climbing := Item.rolled("Leather Boot", ItemRarity.Rarity.COMMON, rng, 2)
	var steps := 0
	while OrbTable.can_apply("Orb of Alchemy", climbing):
		var before_rarity := climbing.rarity
		_check(OrbTable.apply("Orb of Alchemy", climbing, rng), "alchemy lands")
		_check(climbing.rarity == before_rarity + 1, "alchemy steps exactly one rarity")
		steps += 1
		_check(steps <= 8, "alchemy terminates")
	_check(climbing.rarity == ItemRarity.Rarity.ELITE, "alchemy stops at elite")
	_check(climbing.rarity != ItemRarity.Rarity.UNIQUE, "alchemy can never reach unique")

	# --- Chaos: rerolls at any rarity above common, keeping it ---
	_check(OrbTable.can_apply("Orb of Chaos", climbing), "an elite can be chaosed")
	_check(OrbTable.apply("Orb of Chaos", climbing, rng), "chaos lands")
	_check(climbing.rarity == ItemRarity.Rarity.ELITE, "chaos keeps the rarity")
	var bare := Item.rolled("Wooden Armor", ItemRarity.Rarity.COMMON, rng, 1)
	_check(not OrbTable.can_apply("Orb of Chaos", bare), "a common has nothing to chaos")

	# --- Exalted: any rarity with room, and a common has none ---
	_check(not OrbTable.can_apply("Orb of Exalted", bare), "a common cannot be exalted")
	var rare := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 6)
	var rare_cap := int(ItemRarity.MOD_COUNT[ItemRarity.Rarity.RARE][1])
	while rare.mods.size() < rare_cap:
		_check(OrbTable.apply("Orb of Exalted", rare, rng), "exalt lands while there is room")
	_check(not OrbTable.can_apply("Orb of Exalted", rare), "a full rare refuses an exalt")

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
		var mod_band := ModifierTable.band_for(str(mod["id"]), divine.level)
		_check(int(mod["value"]) >= int(mod_band[0]) and int(mod["value"]) <= int(mod_band[1]),
				"a divined %s stays in its band" % mod["id"])
	_check(not OrbTable.can_apply("Orb of Divine", bare), "a bare common has nothing to divine")

	# `why_not` is the exact complement of `can_apply`, for every orb against every piece the suite
	# has in hand -- so the card can ask one question rather than two and never go silent.
	for orb: String in OrbTable.ORBS:
		for piece: Item in [common, magic, climbing, bare, rare, divine]:
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
		# Half start uncommon: nothing lowers a rarity, so that is the only way Alteration meets a lock.
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
			_check(not OrbTable.can_apply("Orb of Transmutation", piece),
					"and so is never offered a transmutation")
	# The walk has to have actually used the orbs it is meant to be testing.
	for orb: String in ["Orb of Chaos", "Orb of Alchemy", "Orb of Alteration", "Orb of Divine"]:
		_check(int(landed.get(orb, 0)) > 0, "%s was tried against a lock (%s)" % [orb, landed])
	rng.seed = WORLD_SEED
	var pinned_piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.ELITE, rng, 5)
	_check(Blacksmith.lock(pinned_piece, rng), "an elite takes a lock")

	# The line says so wherever a piece is written out, because Item writes it rather than a panel.
	var marked := 0
	for text in pinned_piece.mod_lines():
		if "(locked)" in text:
			marked += 1
	_check(marked == 1, "exactly one line says it is locked (%s)" % [pinned_piece.mod_lines()])

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
	bag.trim()
	_check(bag.orb_count("Orb of Chaos") == 4, "trimming a full bag never touches the orbs")

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
		"orbs": {"Orb of Chaos": 2, "Orb of Scouring": 9, "Orb of Divine": -4},
	}
	file = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(edited, "\t"))
	file = null
	var pruned := Inventory.load_from(TEST_PATH)
	_check(pruned.orb_count("Orb of Chaos") == 2, "a known orb survives the read")
	_check(pruned.total_orbs() == 2, "an unknown orb is dropped and a negative one reads as none")
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
	_check(main.bag_page._selected == 0, "the block stayed open on the same piece")
	_check(main.bag_page._detail.visible, "and is still showing")

	# That orb now has nothing to do, and pressing it again must not cost the player the second one.
	# The square is grey and ignores the click; the handler is checked too, because the guarantee is
	# apply first and spend only if it landed.
	main.bag_page._on_orb_pressed("Orb of Transmutation")
	_check(main.inventory.orb_count("Orb of Transmutation") == 1, "a refused orb is not spent")
	_check(sword.rarity == ItemRarity.Rarity.UNCOMMON, "and the piece did not change again")

	# Divine is lit now that there are modifiers to reroll.
	main.bag_page._on_orb_pressed("Orb of Divine")
	for i in 2:
		await process_frame
	_check(sword.rarity == ItemRarity.Rarity.UNCOMMON, "divine kept the rarity")
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
	_check(main._flashes.has("opened_bag") and main._flashes.has("opened_skills"), "both pulsing")
	_check(Inventory.load_from(TEST_PATH).tips.has("level_up"), "and the tips are saved")
	main._on_tip_closed()
	_check(main._tip_panel != null and main._tip_queue.is_empty(), "closing one shows the next")
	main._on_tip_closed()
	main._check_tips()
	_check(main._tip_panel == null, "and none comes twice")

	main._on_bag_pressed()
	_check(not main._flashes.has("opened_bag") and main._bag_button.modulate == Color.WHITE,
			"pressing the bag stops its pulse")
	_check(main._flashes.has("opened_skills"), "while the star keeps pulsing")
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
	tile.add_loot(sword, true)
	tile.add_gold(7)
	tile.add_orb(orb)
	tile.add_xp(1)
	var on_disk := Inventory.load_from(TEST_PATH)
	_check(bag.items.has(sword) and bag.gold == 7 and bag.orb_count(orb) == 1 and bag.xp + bag.level > 1,
			"a tile fight banks every gain as it lands")
	_check(on_disk.total() == 1 and on_disk.gold == 7 and on_disk.first_elite_taken, "and writes it down")
	_check(tile.pending_xp() == 0 and not tile.bank(), "so it has nothing pending and nothing to bank")
	_check(tile.discard(sword) and bag.total() == 0, "a find thrown away comes back out of the bag")

	bag = Inventory.new()
	var run := FightLedger.new(bag, TEST_PATH, true)
	run.add_loot(sword, false)
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
