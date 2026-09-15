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
## where a piece already in the bag gets its numbers.
##
## A drop is one object with two references -- the main scene's inventory and the fight's summary
## both point at it. That is fine while nothing changes an item after it falls; the first verb that
## does (identifying, upgrading, enchanting) has to know both views move together.

var type: String   ## a key of LootTable.ITEMS
var rarity: ItemRarity.Rarity = ItemRarity.Rarity.COMMON
## How deep the tile was that gave this up. Scales everything the piece is worth, and is rolled
## under what that tile allowed rather than handed out at it.
var level := 1
## [{"id": String, "value": int}], in the order they were drawn.
var mods: Array[Dictionary] = []
## The piece's own numbers, scaled by its level when it was rolled. Stored rather than worked out
## on demand: that is what keeps a held piece the piece it was.
var stats: Dictionary = {}


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


## The piece's own numbers, scaled by its level. Worked out once, when it is rolled.
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
		out[stat] = snappedf(raw, 0.1) if stat in LootTable.RATE_STATS else float(roundi(raw))
	return out


## What the panel calls it. A method rather than reading `type`, because a unique will want a name of
## its own and this is where that seam belongs.
func display_name() -> String:
	return type


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


func rarity_name() -> String:
	return ItemRarity.name_of(rarity)


func text_color() -> Color:
	return ItemRarity.TEXT_COLORS[rarity]


func icon() -> Texture2D:
	return LootTable.icon(type)


## "Damage 5", "Crit Chance 5%" -- what the item is worth before anything on top.
func stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var stats := base_stats()
	for stat: String in stats:
		lines.append(LootTable.stat_line(stat, stats[stat]))
	return lines


## "+14% increased Damage", "+6% item find" -- in the order they rolled.
func mod_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for mod in mods:
		var line := ModifierTable.line(mod)
		if not line.is_empty():
			lines.append(line)
	return lines


## The save's shape. The rarity goes in by name: an enum value is only a position, and slipping a new
## step in between two others would quietly reinterpret every save on disk.
func to_dict() -> Dictionary:
	return {
		"type": type,
		"rarity": rarity_name(),
		"level": level,
		"stats": stats.duplicate(),
		"mods": mods.duplicate(true),
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
	var item := Item.new()
	item.type = item_type
	item.rarity = step
	item.level = maxi(1, int(saved.get("level", 1)))
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
			item.mods.append({"id": id, "value": int(entry.get("value", 0))})
	return item
