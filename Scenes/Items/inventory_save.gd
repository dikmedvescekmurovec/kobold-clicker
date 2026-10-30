class_name InventorySave
extends RefCounted
## The shape of `Inventory`'s save file: what `Inventory.save` writes and `Inventory.load_from` reads.
## A file missing, half-written, hand-edited or from a retired build must never stop the game starting.
## Names go on disk, never enum positions. A field of the wrong kind reads as absent: `int(null)` and a
## loop over what is no list raise, so each goes through `Inventory._whole` / `_flag`, a helper at the
## foot of this file, or a `typeof` check. A name this build has not got is left out and named in `lost`.
##
## What each `Inventory.VERSION` added, and how a save from before it reads. Where nothing is said the
## key is absent and reads as the field's default, none:
##  1  `counts` (type -> how many held) and no `version` (`_read_counts`)
##  2  `items`   3  `equipped`   4  an item's `level` and `stats` (`Item.from_dict`)   5  `autodiscard`
##  6  `gold`   7  `orbs`   8  `level`, `xp`   9  `skills` (not read since 33)   10  `towns`
## 11  `uniques_found`   12  `fortunes`
## 13  `first_sword_taken`, absent read as taken: the save is under way. `first_elite_taken` is ignored
## 14  `heirlooms`, `walls_credited` (none counted, so `credit_walls` counts an old save's walls down)
##     and `heirloom_picks`, 15's `super_orbs`: both ignored since the super orbs went (2026-10-30)
## 16  `play_seconds`   17  `camp`   18  `curses`
## 19  `skill_sunk`, `skill_transcends` (gone at 24, ignored)   20  `homeland`, `uniques_doubled`
## 21  `skull_budget` (ignored since 2026-10-03: only Gollux pays skulls)   22  `dungeon_depth`
## 23  `saved_at` for `camp`: an older save camped somewhere counts from that camp's `since`
## 25  `farthest_land` (an older save learns it off the map, the main scene's `_credit_walls`);
##     `seeing_stone` is ignored
## 26  `dungeon_floors`: an older save has beaten the floors of the depths it won and none past them
## 27  `first_orb_taken`, absent read as taken
## 28  `achievements` (a list), `achievements_new`, `tally`
## 29  `achievements` id -> rank: a list is rank I of each, and `tally.walls` starts at `walls_credited`
## 30  `skill_bursts` (not read since 33)   31  `name`
## 32  `deepest_level` (an older save learns it off the map at start-up)
## 33  `skill_tree`, `skill_ranks` for `skills` and `skill_bursts`: an older save has the root alone
##     and every point its level earned free
## 34  `runes`, `runed`
## 35  `characters` (the heroes bought) and `character` (the one in use): an older save is the kobold alone


## Writes `inventory` to `path`, whole or not at all (`SafeFile`), stamped `stamp` (unix time). Whether
## it got there.
static func write(inventory: Inventory, path: String, stamp: float) -> bool:
	var stash := inventory.stash()
	var as_saved := func(item: Item) -> Dictionary: return item.to_dict()
	# Indented, so a person can read and edit the save.
	return SafeFile.write(path, JSON.stringify({
		"version": Inventory.VERSION,
		"first_sword_taken": inventory.first_sword_taken,
		"first_orb_taken": inventory.first_orb_taken,
		"tips": inventory.tips,
		"name": inventory.hero_name,
		"characters": inventory.owned_characters,
		"character": inventory.character,
		"gold": inventory.gold,
		"kills": inventory.kills,
		"play_seconds": inventory.play_seconds,
		"dungeon_depth": inventory.dungeon_depth,
		"dungeon_floors": inventory.dungeon_floors,
		"farthest_land": inventory.farthest_land,
		"deepest_level": inventory.deepest_level,
		"level": inventory.level,
		"xp": inventory.xp,
		"skill_tree": inventory.skills.tree_dict(),
		"skill_ranks": inventory.skills.ranks.duplicate(),
		"towns": inventory.towns.to_dict(),
		"orbs": inventory.orbs,
		"runes": inventory.runes,
		"runed": _worked(inventory.runed),
		"items": inventory.items.map(as_saved),
		"equipped": inventory.equipment.to_dict(),
		"autodiscard": inventory.autodiscard,
		"uniques_found": inventory.uniques_found,
		"uniques_new": inventory.uniques_new,
		"fortunes": inventory.fortunes,
		"saved_at": stamp,
		"heirlooms": {"items": stash.items.map(as_saved), "equipped": stash.equipment.to_dict()},
		"walls_credited": inventory.walls_credited,
		"curses": inventory.curses,
		"homeland": inventory.homeland,
		"uniques_doubled": inventory.uniques_doubled,
		"achievements": inventory.achievements,
		"achievements_new": inventory.achievements_new,
		"tally": inventory.tally,
	}, "\t"))


## The tiles runes are still working on: the only ones saved.
static func _worked(runed: Dictionary) -> Dictionary:
	var kept := {}
	for key: String in runed:
		if RuneTable.working(runed[key]):
			kept[key] = runed[key]
	return kept


## `Inventory.load_from`: the inventory in `path`, or an empty one where there is no file or -- with the
## reason appended to `problem` -- one that cannot be honoured. What it could not keep is said in the log.
static func read(path: String, problem: Array) -> Inventory:
	# The skill tree's root has its own one slot until a save says how far the land has reached, so a
	# missing file -- a Reset -- starts from that.
	SkillTree.root_slots = WallUnlocks.root_branches(0)
	SafeFile.recover(path)
	var inventory := Inventory.new()
	if not FileAccess.file_exists(path):
		return inventory
	var why := _fill(inventory, path)
	if not why.is_empty():
		problem.append(why)
		return Inventory.new()
	if not inventory.lost.is_empty():
		print("Inventory: %s holds %d thing(s) this build cannot keep, gone at the next save: %s"
				% [path, inventory.lost.size(), ", ".join(PackedStringArray(inventory.lost))])
	return inventory


## Reads the file at `path` into a fresh `inventory`. Why the file cannot be honoured, or "".
static func _fill(inventory: Inventory, path: String) -> String:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return "it cannot be read"
	# A JSON instance rather than JSON.parse_string, which pushes an engine error of its own.
	var reader := JSON.new()
	if reader.parse(text) != OK or typeof(reader.data) != TYPE_DICTIONARY:
		return "it is not a save file"
	var data: Dictionary = reader.data
	# No version is the first shape there was, which held `counts`; with neither it is some other file.
	if not data.has("version") and not data.has("counts"):
		return "it is not a save file"
	# A version that is no number is a shape nobody can say: read as the first, it would hand back an
	# empty bag to be saved over the player's.
	var stamp: Variant = data.get("version", 1)
	if typeof(stamp) not in [TYPE_INT, TYPE_FLOAT]:
		return "it does not say which version of the game wrote it"
	var version := int(stamp)
	# Guessing at a newer build's shape is how a save gets eaten; left alone, that build still reads it.
	if version > Inventory.VERSION:
		return "it was written by a newer version of the game (%d)" % version
	if version >= 2 and typeof(data.get("items", [])) != TYPE_ARRAY:
		return "it has no list of items"
	inventory.first_sword_taken = Inventory._flag(data.get("first_sword_taken"), true)
	inventory.first_orb_taken = Inventory._flag(data.get("first_orb_taken"), true)
	for tip: Variant in _list(data.get("tips")):
		inventory.tips.append(str(tip))
	if version < 2:
		_read_counts(inventory, _dict(data.get("counts")))
	else:
		_read_fields(inventory, data, version)
	return ""


## The first shape, type -> how many held: that many plain commons with no modifiers (a rarity would be
## power for having played earlier), read as any saved piece is, so a type since renamed is the piece
## it is now and each carries the table's numbers.
static func _read_counts(inventory: Inventory, counts: Dictionary) -> void:
	var saved := []
	for type: Variant in counts:
		for i in Inventory._whole(counts[type]):
			saved.append({"type": type, "rarity": ItemRarity.NAMES[ItemRarity.Rarity.COMMON]})
	inventory.items = _pieces(saved, inventory.lost)


## Every field of a version 2 save or later, **in this order**: it is the order `lost` is said in, and
## the comments say which reads lean on an earlier one.
static func _read_fields(inventory: Inventory, data: Dictionary, version: int) -> void:
	var lost := inventory.lost
	inventory.items = _pieces(data.get("items"), lost)
	inventory.equipment = Equipment.from_dict(data.get("equipped", {}), lost)
	for level: Variant in _list(data.get("autodiscard")):
		if typeof(level) in [TYPE_INT, TYPE_FLOAT]:
			inventory.set_autodiscard(int(level), true)
	# A negative purse in a hand-edited file is nothing, not a debt.
	inventory.gold = maxf(0.0, _number(data.get("gold")))
	inventory.kills = _whole_of(data, "kills")
	inventory.play_seconds = maxf(0.0, _number(data.get("play_seconds")))
	inventory.dungeon_depth = _whole_of(data, "dungeon_depth")
	# A version 25 save counted only depths: its floors are theirs, the Golluxes included.
	inventory.dungeon_floors = _whole_of(data, "dungeon_floors",
			inventory.dungeon_depth * Encounter.DUNGEON.enemies)
	inventory.farthest_land = _whole_of(data, "farthest_land", MapBuilder.START_LAND_RADIUS)
	# Before the tree, which keeps a stone only in a slot the root has.
	SkillTree.root_slots = WallUnlocks.root_branches(inventory.walls_ever())
	inventory.deepest_level = _whole_of(data, "deepest_level", 1)
	var called: Variant = data.get("name", "")
	if typeof(called) == TYPE_STRING:
		inventory.rename(called)
	# Experience already worth a level is paid out, so the file comes back obeying the curve.
	inventory.level = _whole_of(data, "level", 1)
	inventory.add_xp(_whole_of(data, "xp"))
	# After the level: what a save may have spent is counted off it.
	inventory.skills = Skills.from_dict(data.get("skill_tree", null), data.get("skill_ranks", {}),
			inventory.level, lost)
	inventory.towns = TownState.from_dict(data.get("towns", {}))
	# A renamed orb (`OrbTable.RENAMED`) is counted under its name now.
	var currency := _dict(data.get("orbs"))
	for orb: Variant in currency:
		var named := OrbTable.current(str(orb))
		if OrbTable.ORBS.has(named):
			inventory.add_orb(named, Inventory._whole(currency[orb]))
		else:
			lost.append(str(orb))
	var found_runes := _dict(data.get("runes"))
	for rune: Variant in found_runes:
		if RuneTable.has(str(rune)):
			inventory.add_rune(str(rune), Inventory._whole(found_runes[rune]))
		else:
			lost.append(str(rune))
	var worked := _dict(data.get("runed"))
	for key: Variant in worked:
		var state := RuneTable.from_dict(worked[key], lost)
		if RuneTable.working(state):
			inventory.runed[str(key)] = state
	# Before the curses are read: `note_unique` would count each twice in a Forgotten world.
	for id: Variant in _list(data.get("uniques_found")):
		if not UniqueTable.UNIQUES.has(str(id)):
			lost.append(str(id))
		inventory.note_unique(str(id))
	# `note_unique` called each one new: only what the save says is, and only what is also found.
	inventory.uniques_new.clear()
	for id: Variant in _list(data.get("uniques_new")):
		if inventory.uniques_found.has(str(id)):
			inventory.uniques_new.append(str(id))
	inventory.fortunes = _dict(data.get("fortunes"))
	# A version 22 save has no `saved_at`: one camped by hand counts from that camp, any other from never.
	inventory.saved_at = _number(data.get("saved_at", _dict(data.get("camp")).get("since", 0.0)))
	var heir := _dict(data.get("heirlooms"))
	inventory.stash().items = _pieces(heir.get("items"), lost)
	inventory.stash().equipment = Equipment.from_dict(heir.get("equipped", {}), lost)
	inventory.walls_credited = _whole_of(data, "walls_credited")
	var cursed := _list(data.get("curses"))
	inventory.curses = Curses.known(cursed)
	for curse: Variant in cursed:
		if not Curses.CURSES.has(curse):
			lost.append(str(curse))
	# A homeland that is no land's name simply never matches a fight's.
	inventory.homeland.append_array(_strings(data.get("homeland")))
	for id: String in _strings(data.get("uniques_doubled")):
		if UniqueTable.UNIQUES.has(id) and not inventory.uniques_doubled.has(id):
			inventory.uniques_doubled.append(id)
	# A version 28 save kept a list, every one of it rank I; since then a rank each, held to I..IV.
	var earned: Variant = data.get("achievements")
	for id: String in _strings(earned):
		if Achievements.ACHIEVEMENTS.has(id):
			inventory.achievements[id] = 1
		else:
			lost.append(id)
	var ranked := _dict(earned)
	for id: Variant in ranked:
		if not Achievements.ACHIEVEMENTS.has(str(id)):
			lost.append(str(id))
		elif Inventory._whole(ranked[id]) >= 1:
			inventory.achievements[str(id)] = mini(Inventory._whole(ranked[id]), UniqueTable.PEAK)
	for id: String in _strings(data.get("achievements_new")):
		if inventory.achievements.has(id) and not inventory.achievements_new.has(id):
			inventory.achievements_new.append(id)
	var counted := _dict(data.get("tally"))
	for key: Variant in counted:
		if typeof(counted[key]) in [TYPE_INT, TYPE_FLOAT]:
			inventory.keep_best(str(key), float(counted[key]))
	# A version 28 save counted no wall ever broken: this world's are where the lifetime count starts.
	if version < 29 and inventory.walls_credited > int(inventory.tally.get("walls", 0)):
		inventory.tally["walls"] = inventory.walls_credited
	for id: String in _strings(data.get("characters")):
		if not Characters.has(id):
			lost.append(id)
		inventory.buy_character(id)
	# After the heroes bought: a pick that is not owned, or is no hero's name at all, is the first.
	var being: Variant = data.get("character")
	if typeof(being) == TYPE_STRING:
		inventory.use_character(being)


## The pieces of a saved list this build can keep; the rest are named in `lost` (`Item.from_dict`).
static func _pieces(saved: Variant, lost: Array) -> Array[Item]:
	var out: Array[Item] = []
	for entry: Variant in _list(saved):
		var item := Item.from_dict(entry, lost)
		if item != null:
			out.append(item)
	return out


## The whole number saved under `key`, at least `least` (never negative): what a missing or mistyped
## one reads as.
static func _whole_of(data: Dictionary, key: String, least := 0) -> int:
	return maxi(least, Inventory._whole(data.get(key)))


## A saved number read back, or 0 where a hand-edited file holds anything else.
static func _number(value: Variant) -> float:
	return float(value) if typeof(value) in [TYPE_INT, TYPE_FLOAT] else 0.0


## A saved list or dictionary read back, or an empty one where a hand-edited file holds anything else.
static func _list(saved: Variant) -> Array:
	return saved if typeof(saved) == TYPE_ARRAY else []


static func _dict(saved: Variant) -> Dictionary:
	return saved if typeof(saved) == TYPE_DICTIONARY else {}


## The strings in a saved list, and nothing else a hand-edited file put there.
static func _strings(saved: Variant) -> Array[String]:
	var out: Array[String] = []
	for entry: Variant in _list(saved):
		if typeof(entry) == TYPE_STRING:
			out.append(entry)
	return out
