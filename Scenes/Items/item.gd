class_name Item
extends RefCounted
## One dropped thing: what it is, how good it is, and what it happens to carry.
##
## Items stopped stacking when they started rolling modifiers -- two Wooden Swords are no longer the
## same sword, so every drop is its own object and the inventory is a list of them.
##
## Only three things are ever stored: the type, the rarity and the rolled modifiers. Base stats are
## looked up from LootTable every time rather than copied in, so retuning a sword retunes every sword
## already held, and nothing in a save file can go stale against the tables.
##
## A drop is one object with two references -- the main scene's inventory and the fight's summary
## both point at it. That is fine while nothing changes an item after it falls; the first verb that
## does (identifying, upgrading, enchanting) has to know both views move together.

var type: String   ## a key of LootTable.ITEMS
var rarity: ItemRarity.Rarity = ItemRarity.Rarity.COMMON
## [{"id": String, "value": int}], in the order they were drawn.
var mods: Array[Dictionary] = []


## A fresh drop: the piece, its rarity, and however many modifiers that rarity carries.
static func rolled(item_type: String, item_rarity: ItemRarity.Rarity, rng: RandomNumberGenerator) -> Item:
	var item := Item.new()
	item.type = item_type
	item.rarity = item_rarity
	item.mods = ModifierTable.roll(item_type, ItemRarity.mod_count(item_rarity, rng), rng)
	return item


## What the panel calls it. A method rather than reading `type`, because a unique will want a name of
## its own and this is where that seam belongs.
func display_name() -> String:
	return type


## The piece's own stats, the same for every copy of it.
func base_stats() -> Dictionary:
	return LootTable.stats_of(type)


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
	return {"type": type, "rarity": rarity_name(), "mods": mods.duplicate(true)}


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
