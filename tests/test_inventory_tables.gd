extends "res://tests/inventory_base.gd"
## Headless checks for the loot table, the rarities and modifiers a drop rolls, the inventory and its
## save file. Run from the project folder:
##   python tests/run_all.py inventory_tables
## The rolls are played with a seeded RandomNumberGenerator rather than a scene, and the save tests
## write to their own file so the player's own inventory is never touched.


func _run() -> void:
	_clear_save()
	_check(_test_weighted_picks() == true, "weighted pick tests ran to the end")
	_check(_test_orb_rules() == true, "orb rule tests ran to the end")
	_check(_test_golden_save() == true, "golden save tests ran to the end")
	_check(_test_wrong_types() == true, "wrong type tests ran to the end")
	_check(_test_lost_on_load() == true, "lost on load tests ran to the end")
	_check(_test_failed_write() == true, "failed write tests ran to the end")
	_check(_test_renames() == true, "rename tests ran to the end")
	_check(_test_achievement_keys() == true, "achievement key tests ran to the end")
	_check(_test_effects_are_read() == true, "effect id tests ran to the end")
	_check(_test_each_orb_and_rune_acts() == true, "orb and rune branch tests ran to the end")
	_check(_test_rule_numbers() == true, "rule number tests ran to the end")
	_clear_save()
	_report("inventory: tables")


## Every weighted pick -- a kind of gear, a modifier, an orb, a rarity, a rune, a tile's modifier, a
## node's connectors -- is that one walk: the same seed draws the same things and leaves the generator
## where the walk leaves it, so no seeded roll moves when one of them is rewritten.
func _test_weighted_picks() -> bool:
	var weights := func(rows: Array) -> Array:
		return rows.map(func(row: Dictionary) -> int: return int(row["weight"]))
	# Each is [what is drawn, the table's own draw, the walk over the same weights].
	var picks := []
	var kind := func(rng: RandomNumberGenerator) -> Variant: return LootTable.roll_kind(rng)
	var kind_walked := func(rng: RandomNumberGenerator) -> Variant:
		return LootTable.KINDS.keys()[_walk(weights.call(LootTable.KINDS.values()), rng)]
	picks.append(["a kind of gear", kind, kind_walked])
	var slots := func(rng: RandomNumberGenerator) -> Variant: return SkillTree._connectors(rng)
	var slots_walked := func(rng: RandomNumberGenerator) -> Variant: return _walk(SkillTree.CONNECTOR_WEIGHTS, rng)
	picks.append(["a node's connectors", slots, slots_walked])
	for pool: Array in [["Wooden Sword", 0], ["Gold Ring", 0], ["Strength Node", 1],
			["Dexterity Node", SkillTree.MOST_TIER]]:
		var tier: int = pool[1]
		var lines := ModifierTable.pool_for(pool[0], tier)
		var line := func(rng: RandomNumberGenerator) -> Variant: return ModifierTable._weighted(lines, rng, tier)
		var line_walked := func(rng: RandomNumberGenerator) -> Variant:
			return lines[_walk(Array(lines).map(func(id: String) -> int: return ModifierTable.weight_of(id, tier)), rng)]
		picks.append(["a line of a %s at tier %d" % pool, line, line_walked])
	for walls in OrbTable.EVERY_WALL + 1:
		var orbs := OrbTable.unlocked(walls)
		var orb := func(rng: RandomNumberGenerator) -> Variant: return OrbTable._weighted(rng, walls)
		var orb_walked := func(rng: RandomNumberGenerator) -> Variant:
			return orbs[_walk(orbs.map(func(named: String) -> int: return int(OrbTable.ORBS[named]["weight"])), rng)]
		picks.append(["an orb behind %d walls" % walls, orb, orb_walked])
	for tier: EnemyRoster.Tier in ItemRarity.TIER_WEIGHTS:
		for lift: float in [0.0, 35.0]:
			var table := ItemRarity.weights_for(tier, lift)
			var rarity := func(rng: RandomNumberGenerator) -> Variant: return ItemRarity.roll(tier, rng, lift)
			var rarity_walked := func(rng: RandomNumberGenerator) -> Variant: return table.keys()[_walk(table.values(), rng)]
			picks.append(["a rarity off tier %d at %d%% rarity" % [tier, lift], rarity, rarity_walked])
	for enemy: String in ["Gollux", "Rat"]:
		var rune := func(rng: RandomNumberGenerator) -> Variant: return RuneTable.roll(enemy, rng)
		var rune_walked := func(rng: RandomNumberGenerator) -> Variant:
			if rng.randf() >= float(RuneTable.CHANCE[EnemyRoster.tier_of(enemy)]):
				return ""
			return RuneTable.names()[_walk(weights.call(RuneTable.RUNES.values()), rng)]
		picks.append(["a rune off %s" % enemy, rune, rune_walked])
	var given := RuneTable.pool([], RuneTable.fresh())
	var mod := func(rng: RandomNumberGenerator) -> Variant: return RuneTable._drawn(given, rng)
	var mod_walked := func(rng: RandomNumberGenerator) -> Variant:
		return given[_walk(given.map(func(id: String) -> int: return int(TileMods.MODS[id]["weight"])), rng)]
	picks.append(["a tile's modifier", mod, mod_walked])
	for pick: Array in picks:
		var drawn := RandomNumberGenerator.new()
		var walked := RandomNumberGenerator.new()
		drawn.seed = WORLD_SEED
		walked.seed = WORLD_SEED
		var same := true
		for i in 3000:
			same = same and pick[1].call(drawn) == pick[2].call(walked)
		_check(same and drawn.state == walked.state, "%s is drawn by the one walk" % pick[0])
	return true


## `can_apply` and `why_not` are one rule: an orb a piece takes has no reason against it, an orb it
## refuses has one, and nothing and an orb nobody has heard of are refused without a word.
func _test_orb_rules() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var pieces: Array[Item] = [null]
	for rarity: ItemRarity.Rarity in [ItemRarity.Rarity.COMMON, ItemRarity.Rarity.UNCOMMON, ItemRarity.Rarity.RARE,
			ItemRarity.Rarity.ELITE]:
		for type: String in ["Wooden Sword", "Gold Ring", "Strength Node"]:
			var piece := Item.rolled(type, rarity, rng, 6, 2, 1)
			pieces.append(piece)
			# The same piece with room for one more, with no line at all, expanded, and broken.
			var short := Item.from_dict(piece.to_dict())
			short.mods.pop_back()
			var bare := Item.from_dict(piece.to_dict())
			bare.mods.clear()
			var wide := Item.from_dict(piece.to_dict())
			wide.extra_slot = true
			var ruined := Item.from_dict(piece.to_dict())
			ruined.broken = true
			pieces.append_array([short, bare, wide, ruined])
	var lineless := Item.rolled_unique("squires_blade", rng, 4)
	lineless.mods.clear()
	pieces.append_array([Item.rolled_unique("squires_blade", rng, 4), lineless, Item.rolled_capstone("titan", 2, rng, 4)])
	for orb: String in OrbTable.orbs() + ["Orb of Nothing"]:
		for piece: Item in pieces:
			var named := "nothing" if piece == null else "%s %s (%d lines%s)" % [piece.rarity_name(),
					piece.display_name(), piece.mods.size(), ", broken" if piece.broken else ""]
			_check(OrbTable.can_apply(orb, piece) == _orb_took(orb, piece), "%s on %s is taken as it was" % [orb, named])
			var silent: bool = piece == null or not OrbTable.ORBS.has(orb)
			_check(OrbTable.why_not(orb, piece).is_empty() == (silent or _orb_took(orb, piece)),
					"%s on %s has a reason only where it is refused" % [orb, named])
	return true


## The golden save (`GOLDEN`) loads whole, loses nothing, and comes back out of a save as it went in,
## field for field. It is what says that a change to a table or to the save's shape still reads the
## saves already out there: it fails when a name is retired with no `RENAMED` entry, or a field is
## moved with no migration, and that is its job.
func _test_golden_save() -> bool:
	var problem: Array = []
	var loaded := Inventory.load_from(GOLDEN, problem)
	_check(problem.is_empty(), "the golden save is read (%s)" % [problem])
	_check(loaded.lost.is_empty(), "and nothing it holds is lost (%s)" % [loaded.lost])
	_check(loaded.save(TEST_PATH), "it is saved again")
	var again := Inventory.load_from(TEST_PATH, problem)
	_check(problem.is_empty() and again.lost.is_empty(), "and that reads back whole too (%s, %s)" % [problem, again.lost])
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(TEST_PATH))
	# What every write stamps afresh: the hour, and the build that wrote it.
	for key: String in ["saved_at", "version"]:
		golden.erase(key)
	for difference: String in _differences(golden, written, "save"):
		_check(false, difference)
	SkillTree.root_slots = SkillTree.ROOT_CONNECTORS
	_clear_save()
	return true


## The golden save with each of its fields in turn written as the wrong kind of thing: as nothing,
## which no reader of a number, a flag, a list or a table takes unasked, and as one other -- a word, a
## number, a flag, a list, a table, turn about. A save edited by hand still loads, or says why it
## cannot; it never stops half-read with nothing said, which is an empty bag about to be written over
## the player's.
func _test_wrong_types() -> bool:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var places: Array = []
	_places(golden, [], {}, places)
	_check(places.size() > golden.size(), "the fields of a save are walked, the nested ones too (%d)" % places.size())
	var others := ["junk", 7, true, [], {}]
	for at: int in places.size():
		var place: Array = places[at]
		for wrong: Variant in [null, others[at % others.size()]]:
			var save: Dictionary = golden.duplicate(true)
			var holder: Variant = save
			for step: Variant in place.slice(0, -1):
				holder = holder[step]
			holder[place[-1]] = wrong
			var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
			file.store_string(JSON.stringify(save))
			file.close()
			_check(Inventory.load_from(TEST_PATH) != null, "%s written as %s still loads, or is refused" % [
					".".join(place.map(func(step: Variant) -> String: return str(step))), JSON.stringify(wrong)])
	# The one field whose kind says how to read all the rest: a version that is no number is a refusal.
	var unversioned: Dictionary = golden.duplicate(true)
	unversioned["version"] = "34"
	var edited := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	edited.store_string(JSON.stringify(unversioned))
	edited.close()
	var problem: Array = []
	_check(Inventory.load_from(TEST_PATH, problem).total() == 0 and not problem.is_empty(),
			"a version that is not a number is refused, never read as the first shape and saved over")
	SkillTree.root_slots = SkillTree.ROOT_CONNECTORS
	_clear_save()
	return true


## A save that names what this build has not got -- a piece, a unique, a capstone, a modifier, a stat,
## an orb, a rune, a rune's modifier, a curse, a found unique, an achievement -- and a piece that no
## longer goes where it was: it loads without them, as it always did, and says which they were
## (`Inventory.lost`). The next save writes them away, so a name retired with no `RENAMED` entry shows
## in the log before it is gone. A unique or a capstone whose base has gone is not among them: it is the
## piece its row names now.
func _test_lost_on_load() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 3).to_dict()
	var spoon: Dictionary = sword.duplicate(true)
	spoon["type"] = "Rusty Spoon"
	var relic := Item.rolled_unique("squires_blade", rng, 3).to_dict()
	relic["unique"] = "retired_relic"
	var keystone := Item.rolled_capstone("titan", 1, rng, 3).to_dict()
	keystone["capstone"] = "retired_keystone"
	var lined: Dictionary = sword.duplicate(true)
	lined["mods"].append({"id": "retired_line", "value": 3})
	lined["stats"]["retired_stat"] = 5
	var node := Item.rolled("Strength Node", ItemRarity.Rarity.COMMON, rng, 1).to_dict()
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": Inventory.VERSION,
		"items": [sword, spoon, relic, keystone, lined],
		# A sword does not go on the head, and the root has no sixth slot.
		"equipped": {"weapon": spoon, "helmet": sword},
		"heirlooms": {"items": [spoon]},
		"skill_tree": {"0": spoon, "5": node},
		"orbs": {"Orb of Sorcery": 2, "Orb of Chaos": 1},
		"runes": {"Rune of Nothing": 1, RuneTable.DEPTH: 1},
		"runed": {"1,1": {"mods": [{"id": "retired_ground", "tier": 1, "left": 5}], "depth": [5]}},
		"curses": ["retired_curse", Curses.THICK_FOG],
		"uniques_found": ["retired_relic", "squires_blade"],
		"achievements": {"retired_feat": 1, "duelists_buckler": 1}}))
	file.close()
	var problem: Array = []
	var loaded := Inventory.load_from(TEST_PATH, problem)
	var lost: Array = Array(loaded.lost)
	lost.sort()
	var want := ["Rusty Spoon", "Rusty Spoon", "Rusty Spoon", "Rusty Spoon", "retired_relic", "retired_relic",
			"retired_keystone", "retired_line on Wooden Sword", "retired_stat on Wooden Sword", "Wooden Sword",
			"Strength Node at 5", "Orb of Sorcery", "Rune of Nothing", "retired_ground", "retired_curse", "retired_feat"]
	want.sort()
	_check(problem.is_empty() and lost == want,
			"what the save names and the build has not is said, each once (%s)" % [lost])
	_check(loaded.total() == 2 and loaded.items[1].mods.size() == sword["mods"].size()
			and not loaded.items[1].stats.has("retired_stat"), "and the bag holds what it always would have")
	_check(loaded.equipment.worn.is_empty() and loaded.stash().items.is_empty() and loaded.skills.stones.is_empty()
			and loaded.orbs.keys() == ["Orb of Chaos"] and loaded.runes.keys() == [RuneTable.DEPTH]
			and RuneTable.mods_of(loaded.rune_work(Vector2i(1, 1))).is_empty() and RuneTable.deeper(loaded.rune_work(Vector2i(1,
					1))) == 1
			and loaded.curses == [Curses.THICK_FOG] and loaded.uniques_found == ["squires_blade"]
			and loaded.achievements == {"duelists_buckler": 1}, "and so does everything else")

	# A unique, or a capstone, saved on a base the table has since dropped: its row says what it is now.
	var moved := Item.rolled_unique("squires_blade", rng, 3).to_dict()
	moved["type"] = "Rusty Spoon"
	var named: Array = []
	var back := Item.from_dict(moved, named)
	_check(back != null and back.type == UniqueTable.UNIQUES["squires_blade"]["base"] and back.unique == "squires_blade"
			and named.is_empty(), "a unique whose saved base is gone is the piece its row names")
	var stone := Item.rolled_capstone("titan", 1, rng, 3).to_dict()
	stone["type"] = "Strength Pebble"
	back = Item.from_dict(stone, named)
	_check(back != null and back.type == SkillTree.CAPSTONES["titan"]["base"] and back.is_stone() and named.is_empty(),
			"and a capstone likewise")
	_clear_save()
	return true


## A write that does not get there is no save: the hour it would have stamped is not kept, so a camp
## is never paid from a save that is not on the disk. What follows the player (`save_written`) hears of
## it all the same, since the player has changed whether or not the disk took it.
func _test_failed_write() -> bool:
	_clear_save()
	var player := Inventory.new()
	var heard := []
	player.save_written.connect(func() -> void: heard.append(true))
	var nowhere := "user://no_such_folder/inventory.json"
	_check(not player.save(nowhere) and player.saved_at == 0.0, "a write that fails stamps no hour")
	_check(heard.size() == 1, "and is still said, for the fight and the corner to follow the player")
	_check(player.save(TEST_PATH) and player.saved_at > 0.0 and heard.size() == 2, "a write that lands stamps its own")
	var stamped := player.saved_at
	player.saved_at = stamped - 100.0
	_check(not player.save(nowhere) and player.saved_at == stamped - 100.0,
			"and a later failure leaves that hour as it was")
	_clear_save()
	return true


## Every name a save may still say (`RENAMED`: the pieces', the modifiers' and the orbs') leads to a
## name this build has, in one step, and is itself no longer one. A rename that points at nothing, at
## another rename, or that shadows a live name loses what it was written to keep.
func _test_renames() -> bool:
	var tables := {
		"piece": [LootTable.RENAMED, LootTable.ITEMS],
		"modifier": [ModifierTable.RENAMED, ModifierTable.MODS],
		"orb": [OrbTable.RENAMED, OrbTable.ORBS],
	}
	for what: String in tables:
		var renamed: Dictionary = tables[what][0]
		var live: Dictionary = tables[what][1]
		_check(not renamed.is_empty(), "the %ss have renames to check" % what)
		for old: String in renamed:
			# A modifier's is [what it became, what its number is multiplied by].
			var now := str(renamed[old][0]) if renamed[old] is Array else str(renamed[old])
			_check(live.has(now), "the %s %s is %s now, which there is" % [what, old, now])
			_check(not live.has(old), "the %s %s is no longer a name of its own" % [what, old])
			_check(not renamed.has(now), "the %s %s reaches %s in one step" % [what, old, now])
	return true


## Every achievement's `key` is a number something keeps: a figure `state` reads off the player, a
## count or a streak a fight tallies (`COUNTS`, `STREAKS`, which the fight has to count under that very
## name), the kills on a ground there is, a feat of a broken wall, or a `tick`, a `keep_best` or a
## fight's `_best` somewhere in the game. A key nothing writes is an achievement nobody can earn, and
## nothing else would say so.
func _test_achievement_keys() -> bool:
	var scripts := _scripts()
	var kept := {}
	var writes := RegEx.create_from_string("\\b(?:tick|_count|_best|keep_best)\\((?:\\w+, )?\"([\\w:]+)\"")
	for path: String in scripts:
		for found: RegExMatch in writes.search_all(scripts[path]):
			kept[found.get_string(1)] = true
	for key: String in Achievements.COUNTS + Achievements.STREAKS:
		_check(kept.has(key), "a fight counts %s under that name" % key)
	for found: RegExMatch in RegEx.create_from_string("\"(wall_\\w+)\":").search_all(
			scripts["res://Scenes/Items/achievements.gd"]):
		kept[found.get_string(1)] = true
	var known := Achievements.state(Inventory.new())
	var grounds := SheetMeta.env_adjacency()
	for id: String in Achievements.ACHIEVEMENTS:
		var key := str(Achievements.ACHIEVEMENTS[id]["key"])
		_check(known.has(key) or kept.has(key) or (key.begins_with("kills:") and grounds.has(key.trim_prefix("kills:"))),
				"%s asks for %s, which something keeps" % [id, key])
	return true


## Every unique's `effect`, and every capstone's, is read somewhere outside its own table. The id is a
## plain string wherever it is asked for, so one misspelt never errors: it is only a rule that never
## fires.
func _test_effects_are_read() -> bool:
	var scripts := _scripts()
	for table: Array in [["res://Scenes/Items/unique_table.gd", UniqueTable.UNIQUES],
			["res://Scenes/Skills/skill_tree.gd", SkillTree.CAPSTONES]]:
		var others := scripts.duplicate()
		_check(others.erase(table[0]), "%s is where its own table is" % table[0])
		var source := "\n".join(others.values())
		for id: String in table[1]:
			var effect := str(table[1][id]["effect"])
			# The Wayfarer's Torch has no rule; a home piece's is read with its ground on the end.
			_check(effect.is_empty() or source.contains("\"%s\"" % effect) or source.contains("\"%s:\"" % effect),
					"%s's effect, %s, is read somewhere" % [id, effect])
	return true


## Every orb in the table does something to a piece that can take any of them, and every rune to a
## tile that can: it changes it, or it is refused with a reason. A row no branch of `apply` knows would
## otherwise be spent on nothing, or greyed with nothing said.
func _test_each_orb_and_rune_acts() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	for orb: String in OrbTable.ORBS:
		var acted := false
		# A few goes: a reroll may land where it stood.
		for attempt in 20:
			var piece := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng, 6)
			piece.mods.pop_back()
			var before := piece.to_dict()
			var reason := OrbTable.why_not(orb, piece)
			acted = acted or (piece.to_dict() != before if OrbTable.apply(orb, piece, rng) else not reason.is_empty())
		_check(acted, "%s changes a rare sword with room on it, or says why not" % orb)
	var given: Array = RuneTable.pool([], RuneTable.fresh()).filter(
			func(id: String) -> bool: return not TileMods.MODS[id].get("once", false))
	for rune: String in RuneTable.RUNES:
		var acted := false
		for attempt in 20:
			var work := RuneTable.fresh()
			work["mods"].append({"id": given[0], "tier": 1, "left": RuneTable.KILLS})
			var before := work.duplicate(true)
			var reason := RuneTable.why_not(rune, [], work)
			acted = acted or (work != before if RuneTable.apply(rune, [], work, rng) else not reason.is_empty())
		_check(acted, "%s changes a tile a rune has worked, or says why not" % rune)
	return true


## The numbers a unique's card says in words of its own, where the rule reads them off a constant of
## `Inventory`'s: the starters' and the lines gained at rank IV. Each sentence has to say its
## constant, so tuning one without rewriting the other is caught here.
func _test_rule_numbers() -> bool:
	# A share written as a word: one in so many.
	var shares := {4: "a quarter", 5: "a fifth", 10: "a tenth", 20: "in twenty"}
	var counts := {10: "ten"}
	var one_in := func(share: float) -> String: return str(shares.get(roundi(1.0 / share), "?"))
	var said := {
		"squires_blade": [UniqueTable.effect_text("squires_blade"), "%d more damage" % Inventory.SQUIRE_DAMAGE],
		"couriers_boots": [UniqueTable.effect_text("couriers_boots"), "+%d%% Spawn Speed" % Inventory.COURIER_SPAWN],
		"novices_cap": [UniqueTable.effect_text("novices_cap"), "under level %d" % Inventory.NOVICE_UNTIL],
		"crown_of_accord": [UniqueTable.effect_text("crown_of_accord"),
				"within %s of" % one_in.call(1.0 - Inventory.ACCORD_WITHIN)],
		"crown_of_accord at IV": [UniqueTable.peak_text("crown_of_accord"), "%s instead of %s" % [
				one_in.call(1.0 - Inventory.ACCORD_WITHIN_PEAK), one_in.call(1.0 - Inventory.ACCORD_WITHIN)]],
		"zealots_brand at IV": [UniqueTable.peak_text("zealots_brand"), "%s more" % one_in.call(Inventory.ZEALOT_GIFT - 1.0)],
		"purists_seal at IV": [UniqueTable.peak_text("purists_seal"), "%s higher" % one_in.call(Inventory.PURIST_MODS - 1.0)],
		"rag_and_bone_sack at IV": [UniqueTable.peak_text("rag_and_bone_sack"),
				"One item %s" % one_in.call(Inventory.SALVAGE_ORB)],
		"scholars_circlet at IV": [UniqueTable.peak_text("scholars_circlet"),
				"Every %s intelligence" % counts.get(roundi(Inventory.SCHOLAR_CRIT), "?")],
		"packmule at IV": [UniqueTable.peak_text("packmule"), "%d more items" % Inventory.PACKMULE_ROOM],
	}
	for id: String in said:
		_check(str(said[id][0]).contains(said[id][1]), "%s says \"%s\": %s" % [id, said[id][1], said[id][0]])
	# "Double" is all of it again.
	_check(UniqueTable.effect_text("novices_cap").begins_with("Double experience") == (Inventory.NOVICE_XP == 100.0),
			"the Novice's Cap says double while it is")
	return true
