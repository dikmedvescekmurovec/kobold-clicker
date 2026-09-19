class_name Item
extends RefCounted
## One dropped thing: what it is, how good it is, and what it happens to carry.
##
## Items stopped stacking when they started rolling modifiers -- two Wooden Swords are no longer the
## same sword, so every drop is its own object and the inventory is a list of them.
##
## A piece is frozen the moment it is rolled. Its level, its rolled modifiers and its scaled base
## stats are all worked out once and stored on it, so it is worth exactly the same on every load
## for as long as it is held, whatever happens to the tables afterwards. LootTable is where a new
## piece is rolled from and still owns the slot, the icon, the affix list and the labels; it is not
## where a piece already in the bag gets its numbers. The one hand that moves a level afterwards is
## the fortress smith (`Blacksmith`), and it moves the base stats with it, to exactly what
## `scaled_stats` would have rolled there.
##
## A drop is one object with two references -- the main scene's inventory and the fight's summary
## both point at it. That is fine while nothing changes an item after it falls; the first verb that
## does (identifying, upgrading, enchanting) has to know both views move together.

var type: String   ## a key of LootTable.ITEMS
var rarity: ItemRarity.Rarity = ItemRarity.Rarity.COMMON
## How deep the tile was that gave this up. Scales everything the piece is worth, and is rolled
## under what that tile allowed rather than handed out at it.
var level := 1
## [{"id": String, "value": int}], in the order they were drawn. One of them may carry
## `"locked": true`, which the smith puts there and every orb then works around.
var mods: Array[Dictionary] = []
## The piece's own numbers, scaled by its level when it was rolled. Stored rather than worked out
## on demand: that is what keeps a held piece the piece it was.
var stats: Dictionary = {}
## A smith's upgrade that went wrong. A broken piece is worn and sold as it always was -- for half --
## and nothing may change it again: no orb, no upgrade, no lock.
var broken := false
## Which unique this is -- a key of `UniqueTable.UNIQUES` -- or "" for every ordinary piece. `type` is
## still its base piece, so its slot, its base stats and what a smith's upgrade does to them need no
## second answer.
var unique := ""
## The level an heirloom had when the world was last left behind, 0 for every piece that never was one.
## The smith walks it back up to here without a chance of breaking it (`Blacksmith.break_chance`).
var safe_level := 0


## A fresh drop: the piece, its rarity, its level, and however many modifiers that rarity carries.
## Everything it is worth is settled here and never again.
static func rolled(item_type: String, item_rarity: ItemRarity.Rarity, rng: RandomNumberGenerator,
		item_level := 1) -> Item:
	var item := Item.new()
	item.type = item_type
	item.rarity = item_rarity
	item.level = maxi(1, item_level)
	item.stats = scaled_stats(item_type, item.level)
	item.mods = ModifierTable.roll(item_type, ItemRarity.mod_count(item_rarity, rng), rng, item.level)
	return item


## A unique, fresh off a body: its base piece's numbers at `item_level`, and the modifiers its row
## names -- always those, in that order -- each at a value rolled in the band any modifier rolls in.
static func rolled_unique(id: String, rng: RandomNumberGenerator, item_level := 1) -> Item:
	var row: Dictionary = UniqueTable.UNIQUES[id]
	var item := Item.new()
	item.unique = id
	item.type = row["base"]
	item.rarity = ItemRarity.Rarity.UNIQUE
	item.level = maxi(1, item_level)
	item.stats = scaled_stats(item.type, item.level)
	for mod_id: String in row["mods"]:
		item.mods.append({"id": mod_id, "value": ModifierTable.reroll_value(mod_id, rng, item.level)})
	return item


## The piece's own numbers, scaled by its level and then by what its kind and its material are worth
## (`LootTable.power_of`). Worked out once, when it is rolled.
##
## The level first and the power after, which is the one place that order is decided: a level adds a
## flat step as well as multiplying, so a dagger written weaker in the table would have caught a
## sword up by level 10. This way it is 60% of one at every level.
##
## Stored as the number it displays: a rate keeps one decimal because it is read as one, and
## everything else is whole. So a sword gains a clean point of damage a level, the stat block and
## the fight can never disagree, and what goes into the save comes back out of it exactly rather
## than as a float that has been through a text round trip.
static func scaled_stats(item_type: String, item_level: int) -> Dictionary:
	var out := {}
	var table := LootTable.stats_of(item_type)
	for stat: String in table:
		var raw := LootTable.scale(stat, float(table[stat]), item_level)
		raw *= LootTable.power_of(item_type, stat)
		out[stat] = snappedf(raw, 0.1) if stat in LootTable.RATE_STATS else float(roundi(raw))
	return out


## An heirloom carried out of a world that has ended: level 1 again, with the base stats a fresh roll
## there would carry and every modifier put where it stood in its band, at level 1's band. What it
## was is remembered as `safe_level`, and the best it has ever been rather than the last, so a short
## run never costs a piece what a long one earned. Rarity, locks, `broken` and `unique` do not move.
func transcend() -> void:
	safe_level = maxi(safe_level, level)
	for mod in mods:
		mod["value"] = ModifierTable.rescaled(str(mod["id"]), int(mod["value"]), level, 1)
	level = 1
	stats = scaled_stats(type, 1)


## What the panel calls it. A method rather than reading `type`, because a unique has a name of its
## own and this is where that seam belongs.
func display_name() -> String:
	return type if unique.is_empty() else str(UniqueTable.UNIQUES[unique]["name"])


## The sentence saying what a unique changes about a fight, or "" for a piece that changes nothing.
func effect_text() -> String:
	return "" if unique.is_empty() else UniqueTable.effect_text(unique)


## What the piece is worth before anything it rolled -- as it was rolled, not as the table reads
## today. Duplicated on the way out so no caller can edit another item's numbers through it.
func base_stats() -> Dictionary:
	return stats.duplicate()


## What this piece is actually worth with its own modifiers folded in: stat -> number.
##
## Flat first, then percent, which is the order Path of Exile adds in and the only one that makes
## "+2 Damage" and "+20% increased Damage" on one sword worth (1 + 2) * 1.2 rather than 1 * 1.2 + 2.
## A flat modifier can name a stat the piece has none of -- that is what an affix is -- so a stat
## can appear here that `base_stats` never had. A percent one never can: the pool only offers it
## where there is a base stat to scale.
##
## A GLOBAL modifier is not folded in here at all, and falls through both passes for that reason: it
## is a percentage of what the whole set is worth rather than of anything this piece is, so the one
## place it can mean anything is `Equipment.totals`. Folded in here, a ring's "+14% increased Damage"
## would scale the damage a ring has, which is none.
func effective_stats() -> Dictionary:
	# Taken once: it is a copy now, not a lookup, so asking twice a stat would be real work.
	var out := {}
	var base := base_stats()
	for stat: String in base:
		out[stat] = float(base[stat])
	for mod in mods:
		var entry: Dictionary = ModifierTable.MODS.get(mod.get("id", ""), {})
		if entry.get("kind") == ModifierTable.Kind.FLAT:
			out[entry["stat"]] = float(out.get(entry["stat"], 0.0)) + float(mod["value"])
	for mod in mods:
		var entry: Dictionary = ModifierTable.MODS.get(mod.get("id", ""), {})
		if entry.get("kind") == ModifierTable.Kind.PERCENT:
			out[entry["stat"]] = float(out.get(entry["stat"], 0.0)) * (1.0 + float(mod["value"]) / 100.0)
	return out


## What this piece asks of the *set*: stat -> the percent its GLOBAL modifiers come to. Summed
## rather than compounded, for the reason `Equipment.totals` adds rather than multiplies -- two rings
## of +10% are +20%, which is the arithmetic a player does in their head.
func global_percents() -> Dictionary:
	var out := {}
	for mod in mods:
		var entry: Dictionary = ModifierTable.MODS.get(mod.get("id", ""), {})
		if entry.get("kind") == ModifierTable.Kind.GLOBAL:
			out[entry["stat"]] = float(out.get(entry["stat"], 0.0)) + float(mod["value"])
	return out


## The one modifier a smith has pinned to this piece, or {} when none is. The dictionary itself, not
## a copy: whoever holds it holds the modifier, which is how the orbs put it back where they found it.
func locked_mod() -> Dictionary:
	for mod in mods:
		if bool(mod.get("locked", false)):
			return mod
	return {}


func rarity_name() -> String:
	return ItemRarity.name_of(rarity)


func text_color() -> Color:
	return ItemRarity.SET_TEXT if is_set() else ItemRarity.TEXT_COLORS[rarity]


func border_color() -> Color:
	return ItemRarity.SET_BORDER if is_set() else ItemRarity.BORDER_COLORS[rarity]


## The frame its square wears: its rarity's, or the set's green one. Null for a common piece.
func frame() -> Texture2D:
	return load(ItemRarity.FRAMES % ItemRarity.SET) if is_set() else ItemRarity.frame(rarity)


## Whether this is one piece of a set -- a unique in every way but the green it wears.
func is_set() -> bool:
	return not set_text().is_empty()


## What its set does, as the card says it under the piece's own rule. "" for a piece of no set.
func set_text() -> String:
	return "" if unique.is_empty() else UniqueTable.set_text(unique)


func icon() -> Texture2D:
	return LootTable.icon(type) if unique.is_empty() else UniqueTable.icon(unique)


## "5 Damage", "5% Crit Chance" -- what the item is worth before anything on top.
func stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var stats := base_stats()
	for stat: String in stats:
		lines.append(LootTable.stat_line(stat, stats[stat]))
	return lines


## "+14% increased Damage", "+6% item find" -- in the order they rolled. The smith's lock is not a
## word on the line: `locked_line` says which one it is, and whoever draws them writes that one in
## the ink a base stat wears, as fixed as they are.
##
## `detailed` puts the band the value rolled in at this piece's level beside it, "+14(8-20)% increased Damage":
## what a Divine could make of it. A smith's upgrade lifts the level and not the roll, so a value can
## sit under its band, which is the truth about it.
func mod_lines(detailed := false) -> PackedStringArray:
	var lines := PackedStringArray()
	for mod in mods:
		var line := _mod_line(mod, detailed)
		if not line.is_empty():
			lines.append(line)
	return lines


## The one of `mod_lines` the smith has pinned, spelled as it is there; "" with no lock. No piece
## carries two modifiers that write the same sentence, so the text is enough to find it by.
func locked_line(detailed := false) -> String:
	return _mod_line(locked_mod(), detailed)


func _mod_line(mod: Dictionary, detailed: bool) -> String:
	var line := ModifierTable.line(mod)
	if detailed and not line.is_empty():
		# Every modifier's line opens with its number, so the band goes hard against it and ahead
		# of its unit: "+4(1-4)s". The number may be `BigNumber`'s "1.23e6".
		var number := RegEx.create_from_string("^\\+[0-9.e]+").search(line)
		if number != null:
			line = "%s(%d-%d)%s" % ([number.get_string()] + ModifierTable.band_for(str(mod["id"]), level)
					+ [line.substr(number.get_end())])
	return line


## The save's shape. The rarity goes in by name: an enum value is only a position, and slipping a new
## step in between two others would quietly reinterpret every save on disk.
func to_dict() -> Dictionary:
	var out := _to_dict()
	# Written only where it is true, the way a lock is, so an ordinary piece's save does not change.
	if not unique.is_empty():
		out["unique"] = unique
	if safe_level > 0:
		out["safe_level"] = safe_level
	return out


func _to_dict() -> Dictionary:
	return {
		"type": type,
		"rarity": rarity_name(),
		"level": level,
		"stats": stats.duplicate(),
		# Deep, so a modifier's lock goes into the save on the line it belongs to.
		"mods": mods.duplicate(true),
		"broken": broken,
	}


## An item read back, or null when the save names a piece or a rarity this build no longer has -- the
## same pruning the inventory has always done by name. A modifier that no longer exists is gentler:
## the item keeps its place and simply loses that line, because a retired item is a ghost with no art
## while a retired modifier is just one line fewer.
static func from_dict(data: Variant) -> Item:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var saved: Dictionary = data
	var item_type := str(saved.get("type", ""))
	if not LootTable.ITEMS.has(item_type):
		return null
	var step := ItemRarity.from_name(str(saved.get("rarity", "")))
	if step < 0:
		return null
	# A unique this build no longer has goes the way a retired piece does: by name, and whole. One whose
	# base has been moved keeps the base its row names now.
	var unique_id := str(saved.get("unique", ""))
	if not unique_id.is_empty():
		if not UniqueTable.UNIQUES.has(unique_id):
			return null
		item_type = UniqueTable.UNIQUES[unique_id]["base"]
		step = ItemRarity.Rarity.UNIQUE
	var item := Item.new()
	item.unique = unique_id
	item.type = item_type
	item.rarity = step
	item.level = maxi(1, int(saved.get("level", 1)))
	# Absent is whole, which is what every save written before there was a smith to break one means.
	item.broken = bool(saved.get("broken", false))
	item.safe_level = maxi(0, int(saved.get("safe_level", 0)))
	# A save written before pieces carried their own numbers has none to read, and what such a
	# piece was worth when it was written is exactly the table unscaled -- so that is what it keeps.
	var saved_stats: Variant = saved.get("stats", null)
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for stat: Variant in saved_stats:
			if LootTable.STAT_LABELS.has(str(stat)):
				item.stats[str(stat)] = float(saved_stats[stat])
	else:
		item.stats = LootTable.stats_of(item_type).duplicate()
	var saved_mods: Variant = saved.get("mods", [])
	if typeof(saved_mods) == TYPE_ARRAY:
		# JSON hands back untyped arrays of untyped dictionaries, so the typed one is built entry by
		# entry, and every number crosses through int() the way the counts always did.
		for entry: Variant in saved_mods:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id := str(entry.get("id", ""))
			if not ModifierTable.MODS.has(id):
				continue
			var mod := {"id": id, "value": int(entry.get("value", 0))}
			# Written only where it is true, so a rolled modifier and a saved one are the same
			# dictionary and nothing has to strip a false out of the comparison.
			if bool(entry.get("locked", false)):
				mod["locked"] = true
			item.mods.append(mod)
	return item
