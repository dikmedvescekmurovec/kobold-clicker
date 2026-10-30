class_name Item
extends RefCounted
## One dropped piece: its type, rarity, level, rolled stats and modifiers, what the smith, the orbs and
## a transcension leave on it, its lines and its save. Nothing stacks: every drop is its own object,
## and the inventory and a fight's summary both hold that one object.
##
## A piece is frozen as it is rolled: its level and `stats` are stored and saved, never read off the
## tables again. Only `level_up` and `transcend` move them; an orb changes rarity and modifiers alone.

var type: String   ## a key of LootTable.ITEMS
var rarity: ItemRarity.Rarity = ItemRarity.Rarity.COMMON
var level := 1
## One Dictionary a modifier, in the order they were drawn. Every key past the first two is written only
## where it says something, so a rolled line and a saved one are the same dictionary:
##   "id"       String: a key of `ModifierTable.MODS`.
##   "value"    int: the number it rolled.
##   "under"    int: how many tiers under its band level it sits (`tier_of`); absent at the top tier.
##   "locked"   true: the smith's lock, which every orb works around (`locked_mod`).
##   "bound"    true: the Orb of Binding's (gone with the super orbs, 2026-10-30; a piece keeps it), the
##              same (`held_fast` is either).
##   "at"       int: the level a held-fast line's band is read at (`band_level`), frozen with its number.
##   "perfect"  true: the Orb of Perfection's (gone likewise), kept at the top of its band (`refresh_perfect`).
##   "peak"     int: the best tier an heirloom's line has had (`transcend`), which it climbs back to.
var mods: Array[Dictionary] = []
## Its base stats, scaled by its level as it was rolled (`scaled_stats`) and stored: what keeps a held
## piece the piece it was.
var stats: Dictionary = {}
## A smith's upgrade that went wrong: worn and sold as ever (for half), and nothing changes it again.
var broken := false
## A key of `UniqueTable.UNIQUES`, or "" for an ordinary piece. `type` is still its base piece: its
## slot, its base stats, what a smith's upgrade does to them.
var unique := ""
## The level an heirloom had when its world was last left, 0 for a piece that never was one. It climbs
## back there by itself as the land is charted (`Inventory.raise_heirlooms`), and the smith will not
## take it there sooner (`Blacksmith.can_upgrade`).
var safe_level := 0
## Its pluses (`ascend`: Lean Pickings, the Lone Heir, a bounty's piece), written "+2" after its name: its
## modifiers are read `PLUS_LEVELS` levels higher for each (`mod_level`); its base stats do not move.
var plus := 0
## The Orb of Expansion's (gone with the super orbs, 2026-10-30; a piece keeps it): one modifier more
## than its rarity allows.
var extra_slot := false
## The player's padlock: a level's Sell all and bin pass it by (`Inventory.discard_level`). Not the
## smith's Lock, which holds one modifier (`locked_mod`).
var locked := false
## What the player called it as it was made an heirloom (`TranscendPage`), written in its name's place.
var nickname := ""
## A skill stone's tier, at least 1 on a stone and 0 on everything else (`is_stone`): the deepest it
## may sit in the skill tree (`SkillTree.can_place`) and which of its base's lines it may roll
## (`SkillTree.lines_for`). Its lines' bands are its level's, as gear's are (the user's, 2026-10-09).
var stone_tier := 0
## A skill stone's child slots, 0 to 3: a stone with none is a leaf.
var connectors := 0
## Which of `SkillTree.CAPSTONES` this stone is, or "" for every other piece. A capstone's lines are
## its row's, and no orb touches it.
var capstone := ""

## What one `plus` is worth to a piece's modifiers, in item levels. A dial, unplayed.
const PLUS_LEVELS := 3


## A fresh drop with its rarity's handful of modifiers. A skill stone's `tier` (1 at the least) and
## `child_slots` are set before the draw, since the tier says which lines it may roll.
static func rolled(item_type: String, item_rarity: ItemRarity.Rarity, rng: RandomNumberGenerator,
		item_level := 1, tier := 1, child_slots := 0) -> Item:
	var item := Item.new()
	item.type = item_type
	item.rarity = item_rarity
	item.level = maxi(1, item_level)
	if LootTable.slot_of(item_type) == SkillTree.SLOT:
		item.stone_tier = maxi(1, tier)
		item.connectors = clampi(child_slots, 0, SkillTree.MOST_CONNECTORS)
	item.stats = scaled_stats(item_type, item.level)
	item.mods = ModifierTable.roll(item_type, ItemRarity.mod_count(item_rarity, rng, item_type), rng,
			item.mod_level(), item.stone_tier)
	return item


## A fresh unique: its base piece's stats at `item_level` and the modifiers its row names, always
## those and in that order, only their values rolled.
static func rolled_unique(id: String, rng: RandomNumberGenerator, item_level := 1) -> Item:
	var item := _rolled_row(UniqueTable.UNIQUES[id], rng, item_level)
	item.unique = id
	return item


## A fresh capstone: a leaf of its base at `tier`, its lines its row's, as a unique's are.
static func rolled_capstone(id: String, tier: int, rng: RandomNumberGenerator, item_level := 1) -> Item:
	var item := _rolled_row(SkillTree.CAPSTONES[id], rng, item_level)
	item.capstone = id
	item.stone_tier = maxi(1, tier)
	return item


## A piece of UNIQUE rarity off a hand-written row: its `base` at `item_level`, and each of its `mods`
## rolled in that level's band.
static func _rolled_row(row: Dictionary, rng: RandomNumberGenerator, item_level: int) -> Item:
	var item := Item.new()
	item.type = row["base"]
	item.rarity = ItemRarity.Rarity.UNIQUE
	item.level = maxi(1, item_level)
	item.stats = scaled_stats(item.type, item.level)
	for mod_id: String in row["mods"]:
		item.mods.append(ModifierTable.rolled_mod(mod_id, rng, item.level))
	return item


## A piece's base stats at `item_level`: the level first and its kind's and material's power after
## (`LootTable.power_of`), the one place that order is decided. Stored as the number it displays, a
## rate to one decimal and everything else whole, so the save round-trips exactly.
static func scaled_stats(item_type: String, item_level: int) -> Dictionary:
	var out := {}
	var table := LootTable.stats_of(item_type)
	for stat: String in table:
		var raw := LootTable.scale(stat, float(table[stat]), item_level)
		raw *= LootTable.power_of(item_type, stat)
		# ponytail: a stat is rounded through a whole int, which passes int64 near item level 370 -- far
		# past where a monster's health would have; `roundf` then.
		out[stat] = snappedf(raw, 0.1) if stat in LootTable.RATE_STATS else float(roundi(raw))
	return out


## What the end of a world does to an heirloom: level 1 and the base stats of a fresh roll there, with
## `safe_level` the best it has ever been. Each tiered line's best tier is kept as `"peak"` and the
## line drops only as far as level 1 makes it, its number keeping its place in the band. The one hand
## that moves a held-fast line (its `"at"` with it). Rarity, locks, `broken` and `unique` do not move.
func transcend() -> void:
	safe_level = maxi(safe_level, level)
	var was := mods.map(tier_of)
	level = 1
	for i in mods.size():
		var mod := mods[i]
		if mod.has("at"):
			mod["at"] = mod_level()
		if ModifierTable.tiered(str(mod["id"])):
			mod["peak"] = maxi(int(mod.get("peak", 0)), int(was[i]))
			_set_tier(mod, int(was[i]), mini(int(mod["peak"]), band_level(mod)))
	refresh_perfect()
	stats = scaled_stats(type, 1)


## The smith's upgrade, and an heirloom's climb with the land: one level, the base stats of a fresh
## roll there, and every modifier kept at its tier and number (the user's ruling) -- but an heirloom's
## line climbs a tier a level back towards its `"peak"`, never past what the level allows, its number
## keeping its place in the band. Held-fast lines read their band at `"at"` and do not move.
func level_up() -> void:
	var was := mods.map(tier_of)
	level += 1
	for i in mods.size():
		var mod := mods[i]
		if held_fast(mod) or bool(mod.get("perfect", false)) or not ModifierTable.tiered(str(mod["id"])):
			continue
		_set_tier(mod, int(was[i]), maxi(int(was[i]), mini(int(mod.get("peak", 0)), mod_level())))
	stats = scaled_stats(type, level)
	refresh_perfect()


## Puts a line at `tier` (1 to its band level), its number as far up that band as it stood in `from`'s.
## The one place a line is put at a tier by hand.
func _set_tier(mod: Dictionary, from: int, tier: int) -> void:
	tier = clampi(tier, 1, band_level(mod))
	mod.erase("under")
	if band_level(mod) > tier:
		mod["under"] = band_level(mod) - tier
	mod["value"] = ModifierTable.rescaled(str(mod["id"]), int(mod["value"]), from, tier)


## The level its modifiers' bands are read at. Everything that rolls, rerolls or writes a band for a
## piece already made asks this, never `level`. A skill stone's tier lifts nothing (the user's,
## 2026-10-09).
func mod_level() -> int:
	return level + plus * PLUS_LEVELS


func is_stone() -> bool:
	return stone_tier > 0


## One plus more: every modifier keeps its place in its band as the band moves up `PLUS_LEVELS`
## levels, and a held-fast line stays where it was held. What Lean Pickings does to a find as it
## falls, and the Lone Heir to the heirloom made.
func ascend() -> void:
	var was := mods.map(tier_of)
	plus += 1
	for i in mods.size():
		var mod := mods[i]
		if held_fast(mod):
			continue
		mod["value"] = ModifierTable.rescaled(str(mod["id"]), int(mod["value"]), int(was[i]), tier_of(mod))
	refresh_perfect()


## Puts every perfected modifier at the top of the top tier as it now stands. Called by whatever moves
## `mod_level`: the smith's upgrade, a plus, the end of a world.
func refresh_perfect() -> void:
	for mod in mods:
		if bool(mod.get("perfect", false)):
			mod.erase("under")
			mod["value"] = int(ModifierTable.band_for(str(mod["id"]), tier_of(mod))[1])


## Whether an orb must leave this modifier as it is: the smith's lock, or a binding.
static func held_fast(mod: Dictionary) -> bool:
	return bool(mod.get("locked", false)) or bool(mod.get("bound", false))


## Holds `mods[index]` fast under `flag` ("locked" or "bound"): its number and the band it is read
## in stop moving with the piece. A line already held keeps the band it was first held at.
func hold(index: int, flag: String) -> void:
	var mod := mods[index]
	mod[flag] = true
	mod["at"] = int(mod.get("at", mod_level()))


## The level this modifier's band is read at: where it was held fast, else the piece's own.
func band_level(mod: Dictionary) -> int:
	return int(mod.get("at", mod_level()))


## The tier this modifier's band is read at (`ModifierTable.band_for`): `"under"` below its band
## level. Anything that reads or rerolls the band of a line on a made piece asks this.
func tier_of(mod: Dictionary) -> int:
	return maxi(1, band_level(mod) - int(mod.get("under", 0)))


## One more modifier it could take beside `held` (its own lines, or those kept of them), or {} when
## there is none left: rolled at `mod_level` and drawn at its `stone_tier`, as every new line on a made
## piece is.
func extra_mod(held: Array[Dictionary], rng: RandomNumberGenerator) -> Dictionary:
	return ModifierTable.add_one(type, held, rng, mod_level(), stone_tier)


## What the panel calls it: the player's name for it or `base_name`, and its plus.
func display_name() -> String:
	var named := base_name() if nickname.is_empty() else nickname
	return named if plus <= 0 else "%s +%d" % [named, plus]


## What the piece is, whatever the player calls it: its base, or a unique's own name.
func base_name() -> String:
	if not capstone.is_empty():
		return str(SkillTree.CAPSTONES[capstone]["name"])
	return type if unique.is_empty() else str(UniqueTable.UNIQUES[unique]["name"])


## What a unique or a capstone changes about a fight, a unique's numbers at the player's rank of it
## (`UniqueTable.shown_rank`); "" for any other piece.
func effect_text() -> String:
	if not capstone.is_empty():
		return str(SkillTree.CAPSTONES[capstone]["effect_text"])
	return "" if unique.is_empty() else UniqueTable.effect_text(unique, UniqueTable.shown_rank(unique))


## The line a unique gains at rank IV, once the player has reached it (the user's call); "" before.
func peak_text() -> String:
	if unique.is_empty() or UniqueTable.shown_rank(unique) < UniqueTable.PEAK:
		return ""
	return UniqueTable.peak_text(unique)


## A copy of `stats`, so no caller edits the piece through it.
func base_stats() -> Dictionary:
	return stats.duplicate()


## What the piece is worth with its own modifiers folded in. FLAT first, then PERCENT scaling the sum:
## "+2 Damage" and "+20% increased Damage" on 1 make (1 + 2) * 1.2. A FLAT line may name a stat the
## piece has none of, so a stat can appear that `base_stats` never had. A GLOBAL line is not folded in:
## it is a share of the set, and `Equipment.totals` applies it.
func effective_stats() -> Dictionary:
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


## What the piece asks of the set: stat -> the percent its GLOBAL modifiers sum to (two of +10% are
## +20%, never compounded).
func global_percents() -> Dictionary:
	var out := {}
	for mod in mods:
		var entry: Dictionary = ModifierTable.MODS.get(mod.get("id", ""), {})
		if entry.get("kind") == ModifierTable.Kind.GLOBAL:
			out[entry["stat"]] = float(out.get(entry["stat"], 0.0)) + float(mod["value"])
	return out


## The modifier the smith has pinned, or {}. The dictionary itself, not a copy.
func locked_mod() -> Dictionary:
	for mod in mods:
		if bool(mod.get("locked", false)):
			return mod
	return {}


func rarity_name() -> String:
	return ItemRarity.name_of(rarity)


func rarity_label() -> String:
	return ItemRarity.label_of(rarity)


func text_color() -> Color:
	return ItemRarity.TEXT_COLORS[rarity]


func border_color() -> Color:
	return ItemRarity.BORDER_COLORS[rarity]


## The frame its square wears (`ItemRarity.frame`); null for a common piece.
func frame() -> Texture2D:
	return ItemRarity.frame(rarity, frame_rank())


## The rank a unique's frame shows: the player's, read as the square is drawn, and 0 for a starter.
func frame_rank() -> int:
	return UniqueTable.shown_rank(unique) if UniqueTable.is_ranked(unique) else 0


func icon() -> Texture2D:
	if not capstone.is_empty():
		return SkillTree.icon(capstone)
	return LootTable.icon(type, stone_tier) if unique.is_empty() else UniqueTable.icon(unique)


## Its base stats, written: "5 Damage", "5% Crit Chance".
func stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var stats := base_stats()
	for stat: String in stats:
		lines.append(LootTable.stat_line(stat, stats[stat]))
	return lines


## Its modifiers, written, in the order they rolled. `detailed` puts each line's band beside its
## number and its tier at the end, "+14(8-20)% increased Damage T7"; a line held fast while the level
## moved can sit under its band. No word marks the smith's lock (`locked_line`).
func mod_lines(detailed := false) -> PackedStringArray:
	var lines := PackedStringArray()
	for mod in mods:
		var line := _mod_line(mod, detailed)
		if not line.is_empty():
			lines.append(line)
	return lines


## The one of `mod_lines` the smith has pinned; "" with no lock. No piece carries two modifiers that
## write the same sentence, so the text is enough to find it by.
func locked_line(detailed := false) -> String:
	return _mod_line(locked_mod(), detailed)


## Every one of `mod_lines` no orb can move (locked or bound), for whoever writes them in a base
## stat's ink.
func fast_lines(detailed := false) -> PackedStringArray:
	return _lines_where(held_fast, detailed)


## And the perfected ones, which are written in a colour of their own.
func perfect_lines(detailed := false) -> PackedStringArray:
	return _lines_where(func(mod: Dictionary) -> bool: return bool(mod.get("perfect", false)), detailed)


func _lines_where(wanted: Callable, detailed: bool) -> PackedStringArray:
	var lines := PackedStringArray()
	for mod in mods:
		if wanted.call(mod):
			lines.append(_mod_line(mod, detailed))
	return lines


func _mod_line(mod: Dictionary, detailed: bool) -> String:
	var line := ModifierTable.line(mod)
	if detailed and not line.is_empty():
		# The band goes hard against the line's first number and ahead of its unit: "+4(1-4)s",
		# "come 30(20-40)% later". The number may be `BigNumber`'s "1.23M" or "1.23e36". The band is written
		# the way the number is (`ModifierTable.amount`) less the unit; a signed one as its reach ("±2"),
		# and a band of one number not at all.
		var number := RegEx.create_from_string("[+-]?[0-9][0-9.]*(e[0-9]+|[A-Z][a-z]?)?").search(line)
		var id := str(mod["id"])
		var band := ModifierTable.band_for(id, tier_of(mod))
		if number != null and band[0] != band[1]:
			var written := "±%d" % int(band[1]) if ModifierTable.MODS[id].get("signed", false) else "%s-%s" % [
					ModifierTable.amount(id, int(band[0])).trim_suffix("s"), ModifierTable.amount(id, int(band[1])).trim_suffix("s")]
			line = "%s(%s)%s" % [line.substr(0, number.get_end()), written, line.substr(number.get_end())]
			# The tier last, where the row's name ends; a modifier with one band at every tier has none.
			if ModifierTable.tiered(id):
				line += " T%d" % tier_of(mod)
	return line


## The save's shape. The rarity goes in by name, and every optional field only where it is set.
func to_dict() -> Dictionary:
	var out := {
		"type": type,
		"rarity": rarity_name(),
		"level": level,
		"stats": stats.duplicate(),
		# Deep: each line is a dictionary of its own.
		"mods": mods.duplicate(true),
		"broken": broken,
	}
	if not unique.is_empty():
		out["unique"] = unique
	if safe_level > 0:
		out["safe_level"] = safe_level
	if plus > 0:
		out["plus"] = plus
	if extra_slot:
		out["extra_slot"] = true
	if locked:
		out["locked"] = true
	if not nickname.is_empty():
		out["nickname"] = nickname
	if is_stone():
		out["stone_tier"] = stone_tier
	if connectors > 0:
		out["connectors"] = connectors
	if not capstone.is_empty():
		out["capstone"] = capstone
	return out


## An item read back, or null where the save names a piece, a rarity, a unique or a capstone this
## build has not got. A modifier or a stat it has not got is dropped and the piece kept. Whatever is
## not kept is named in `lost` (`Inventory.load_from`); a number or a flag a hand-edited file wrote as
## anything else reads as none.
static func from_dict(data: Variant, lost: Array = []) -> Item:
	var item := _read(data, lost)
	if item == null:
		lost.append(str(data.get("unique", data.get("capstone", data.get("type", "an item with no name"))))
				if data is Dictionary else "an item that cannot be read")
	return item


static func _read(data: Variant, lost: Array) -> Item:
	if typeof(data) != TYPE_DICTIONARY:
		return null
	var saved: Dictionary = data
	var item_type := LootTable.current(str(saved.get("type", "")))
	var step := ItemRarity.from_name(str(saved.get("rarity", "")))
	if step < 0:
		return null
	# A unique's piece is the one its row names now, whatever base the save wrote.
	var unique_id := str(saved.get("unique", ""))
	if not unique_id.is_empty():
		if not UniqueTable.UNIQUES.has(unique_id):
			return null
		item_type = UniqueTable.UNIQUES[unique_id]["base"]
		step = ItemRarity.Rarity.UNIQUE
	# A capstone likewise, by its row.
	var capstone_id := str(saved.get("capstone", ""))
	if not capstone_id.is_empty():
		if not SkillTree.CAPSTONES.has(capstone_id):
			return null
		item_type = SkillTree.CAPSTONES[capstone_id]["base"]
		step = ItemRarity.Rarity.UNIQUE
	# Asked last: a unique's or a capstone's piece is its row's, not the one the save wrote.
	if not LootTable.ITEMS.has(item_type):
		return null
	var item := Item.new()
	item.unique = unique_id
	item.capstone = capstone_id
	if LootTable.slot_of(item_type) == SkillTree.SLOT:
		item.stone_tier = maxi(1, Inventory._whole(saved.get("stone_tier")))
		item.connectors = clampi(Inventory._whole(saved.get("connectors")), 0, SkillTree.MOST_CONNECTORS)
	item.type = item_type
	item.rarity = step
	item.level = maxi(1, Inventory._whole(saved.get("level")))
	# Absent is whole: every save from before there was a smith.
	item.broken = Inventory._flag(saved.get("broken"))
	item.safe_level = maxi(0, Inventory._whole(saved.get("safe_level")))
	item.plus = maxi(0, Inventory._whole(saved.get("plus")))
	item.extra_slot = Inventory._flag(saved.get("extra_slot"))
	item.locked = Inventory._flag(saved.get("locked"))
	if saved.get("nickname") is String:
		item.nickname = saved["nickname"]
	# A save from before pieces carried their own numbers has none: such a piece was worth the table's,
	# unscaled.
	var saved_stats: Variant = saved.get("stats", null)
	if typeof(saved_stats) == TYPE_DICTIONARY:
		for stat: Variant in saved_stats:
			if not LootTable.STAT_LABELS.has(str(stat)):
				lost.append("%s on %s" % [stat, item_type])
			elif typeof(saved_stats[stat]) in [TYPE_INT, TYPE_FLOAT]:
				item.stats[str(stat)] = float(saved_stats[stat])
	else:
		item.stats = LootTable.stats_of(item_type).duplicate()
	var saved_mods: Variant = saved.get("mods", [])
	if typeof(saved_mods) == TYPE_ARRAY:
		# The level and the plus are read by here: a line saved before tiers is fitted at `band_level`.
		for entry: Variant in saved_mods:
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var id := str(entry.get("id", ""))
			var value := Inventory._whole(entry.get("value"))
			# A retired id is the line it was folded into (`ModifierTable.RENAMED`), dropped where the piece
			# already holds that line. It is never carried over as perfect: its number is not the new band's top.
			var renamed: Array = ModifierTable.RENAMED.get(id, [])
			if not renamed.is_empty():
				id = renamed[0]
				value *= int(renamed[1])
				if item.mods.any(func(held: Dictionary) -> bool: return held["id"] == id):
					continue
			if not ModifierTable.MODS.has(id):
				lost.append("%s on %s" % [id, item_type])
				continue
			var mod := {"id": id, "value": value}
			# Flags are written only where true, so a rolled line and a loaded one compare with ==.
			for flag: String in ["locked", "bound"] + ([] if not renamed.is_empty() else ["perfect"]):
				if Inventory._flag(entry.get(flag)):
					mod[flag] = true
			for key: String in ["at", "peak"]:
				if typeof(entry.get(key)) in [TYPE_INT, TYPE_FLOAT]:
					mod[key] = int(entry[key])
			# A line saved before there were tiers is given the highest tier that holds its number; asked on
			# every load, which is safe, since a top-tier line fits the top again. A perfect line is the top.
			var under := Inventory._whole(entry.get("under"))
			if not entry.has("under") and not mod.has("perfect"):
				under = ModifierTable.fit_under(id, int(mod["value"]), item.band_level(mod))
			if under > 0:
				mod["under"] = under
			item.mods.append(mod)
	return item
