class_name RuneTable
extends RefCounted
## The six runes, the third wall's unlock with Gollux (`WallUnlocks.RUNES`, the user's design 2026-10-09):
## dropped only in his cave, and spent on a charted tile to juice its farm runs. What each does, how often
## a body down there carries one, and the rules over the work they leave on a tile.
##
## A tile's rune work is one Dictionary (`Inventory.runed`, by world spot): `mods`, the modifiers runes
## gave it -- {id, tier, left} each, a `TileMods` row --, `depth`, one count of kills left a Depth rune,
## and `ascent`, the Ascent rune's kills left (0: none). **Runes never touch the tile's own modifiers**
## (the user's): Shifting, Upheaval and Stillness work on what runes gave it alone. **Everything a rune
## does lasts `KILLS` kills on the tile, each modifier, each Depth and the Ascent on its own count** (the
## user's), counted in a farm run (`count_kill`) -- never a camp, which carries none of it.
##
## Like the orbs, a count by name in the inventory and never an `Item`; unlike them, a tile and not a
## piece is what one is spent on. `can_apply` / `apply` / `why_not` are three faces of one rule, as
## `OrbTable`'s are.

## What each does, how often one is drawn against the others, and its colour: the crystal it wears
## (`icon`, a stand-in until the runes have art of their own) and the beam it falls in.
const RUNES := {
	"Rune of Shifting": {"weight": 6, "glow": Color("0098dc"),
		"does": "Rerolls the tiers of the modifiers runes gave a tile."},
	"Rune of Upheaval": {"weight": 6, "glow": Color("93388f"),
		"does": "Rerolls the modifiers runes gave a tile into different ones."},
	"Rune of Unrest": {"weight": 10, "glow": Color("f5555d"),
		"does": "Gives a tile a new modifier."},
	"Rune of Stillness": {"weight": 6, "glow": Color("5ac54f"),
		"does": "Takes away a modifier a rune gave a tile."},
	"Rune of Depth": {"weight": 8, "glow": Color("ed7614"),
		"does": "Makes a tile's enemies a level higher."},
	"Rune of Ascent": {"weight": 3, "glow": Color("ffc825"),
		"does": "Makes a tile's enemies ascended: what they drop may be ascended."},
}
const SHIFTING := "Rune of Shifting"
const UPHEAVAL := "Rune of Upheaval"
const UNREST := "Rune of Unrest"
const STILLNESS := "Rune of Stillness"
const DEPTH := "Rune of Depth"
const ASCENT := "Rune of Ascent"
## How many kills on the tile each thing a rune did lasts (the user's, 2026-10-09).
const KILLS := 100
## The highest tier Shifting deals a modifier; a `once` row stays at I.
const MOST_TIER := 3
## How often a body in the cave carries a rune, by what it was: Gollux always.
const CHANCE := {
	EnemyRoster.Tier.COMMON: 0.04,
	EnemyRoster.Tier.ELITE: 0.2,
	EnemyRoster.Tier.BOSS: 1.0,
}
## The crystal every rune wears for now, tinted its colour and set in a 16 px square (`icon`).
const CRYSTAL := "res://Assets/UI/ui_icon_crystal.png"
const ICON_SIDE := 16

static var _icons := {}


static func names() -> Array:
	return RUNES.keys()


static func has(rune: String) -> bool:
	return RUNES.has(rune)


## The rune's picture: the crystal mark multiplied by its colour, its dark edge kept, in a 16 px square
## so the orb tray's 16 px icon draws it pixel for pixel. Made once.
static func icon(rune: String) -> Texture2D:
	if not _icons.has(rune):
		var mark := (load(CRYSTAL) as Texture2D).get_image()
		if mark.is_compressed():
			mark.decompress()
		mark.convert(Image.FORMAT_RGBA8)
		var tint: Color = RUNES[rune]["glow"]
		var square := Image.create_empty(ICON_SIDE, ICON_SIDE, false, Image.FORMAT_RGBA8)
		var at := (Vector2i(ICON_SIDE, ICON_SIDE) - mark.get_size()) / 2
		for y in mark.get_height():
			for x in mark.get_width():
				var pixel := mark.get_pixel(x, y)
				square.set_pixel(at.x + x, at.y + y, Color(pixel.r * tint.r, pixel.g * tint.g, pixel.b * tint.b, pixel.a))
		_icons[rune] = ImageTexture.create_from_image(square)
	return _icons[rune]


## A body in the cave: the rune it carries, or "". Drawn by the runes' weights.
static func roll(enemy: String, rng: RandomNumberGenerator) -> String:
	if rng.randf() >= float(CHANCE[EnemyRoster.tier_of(enemy)]):
		return ""
	var total := 0
	for rune: String in RUNES:
		total += int(RUNES[rune]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for rune: String in RUNES:
		pick -= int(RUNES[rune]["weight"])
		if pick < 0:
			return rune
	return ""


## A tile with no rune work on it.
static func fresh() -> Dictionary:
	return {"mods": [], "depth": [], "ascent": 0}


## The rune work on a tile as the fight reads it: each modifier listed once a tier, as `TileMods` lists
## a tile's own.
static func mods_of(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for mod: Dictionary in state.get("mods", []):
		for i in int(mod["tier"]):
			out.append(str(mod["id"]))
	return out


## How many levels higher the tile's enemies are: one a Depth rune still working.
static func deeper(state: Dictionary) -> int:
	return (state.get("depth", []) as Array).size()


static func ascended(state: Dictionary) -> bool:
	return int(state.get("ascent", 0)) > 0


## Whether any rune is still working on the tile.
static func working(state: Dictionary) -> bool:
	return not mods_of(state).is_empty() or deeper(state) > 0 or ascended(state)


## The modifiers a rune could give a tile carrying `own` (its own, as the fight is told them) and the
## rune work in `state`: only the ones a farm run feels (`TileMods` `farm`), since a farm run is the only
## fight a charted tile has, none already on it, and none a modifier on it will not stand beside.
static func pool(own: Array, state: Dictionary) -> Array[String]:
	var on: Array = own + mods_of(state)
	var out: Array[String] = []
	for id: String in TileMods.MODS:
		var row: Dictionary = TileMods.MODS[id]
		if not bool(row.get("farm", false)) or id in on:
			continue
		var clash := false
		for other: String in on:
			if other in row.get("not_with", []) or id in TileMods.MODS[other].get("not_with", []):
				clash = true
		if not clash:
			out.append(id)
	return out


## Why `rune` would do nothing to a tile carrying `own` and `state`, or "" when it would do something.
static func why_not(rune: String, own: Array, state: Dictionary) -> String:
	var given: Array = state.get("mods", [])
	match rune:
		SHIFTING, STILLNESS, UPHEAVAL:
			if given.is_empty():
				return "No rune has given this tile a modifier"
		UNREST:
			if pool(own, state).is_empty():
				return "There is no other modifier to give it"
		ASCENT:
			if ascended(state):
				return "Its enemies are already ascended"
	return ""


static func can_apply(rune: String, own: Array, state: Dictionary) -> bool:
	return why_not(rune, own, state).is_empty()


## Spends `rune` on a tile carrying `own` and `state`, changing `state`. Whether it did anything.
static func apply(rune: String, own: Array, state: Dictionary, rng: RandomNumberGenerator) -> bool:
	if not can_apply(rune, own, state):
		return false
	var given: Array = state["mods"]
	match rune:
		SHIFTING:
			for mod: Dictionary in given:
				mod["tier"] = 1 if _once(mod["id"]) else rng.randi_range(1, MOST_TIER)
		UPHEAVAL:
			# Each into one it is not, kept to its tier where its new row allows one, on its own count --
			# or itself again where nothing else may stand beside the rest.
			var kept: Array = []
			for mod: Dictionary in given:
				var choices := pool(own, {"mods": kept}).filter(func(id: String) -> bool: return id != mod["id"])
				if choices.is_empty():
					choices = [mod["id"]]
				var id: String = _drawn(choices, rng)
				kept.append({"id": id, "tier": 1 if _once(id) else int(mod["tier"]), "left": int(mod["left"])})
			state["mods"] = kept
		UNREST:
			given.append({"id": _drawn(pool(own, state), rng), "tier": 1, "left": KILLS})
		STILLNESS:
			given.remove_at(rng.randi_range(0, given.size() - 1))
		DEPTH:
			(state["depth"] as Array).append(KILLS)
		ASCENT:
			state["ascent"] = KILLS
	return true


## One kill on the tile: every count goes down one, and what runs out comes off. What came off, for the
## fight that is running to forget: {"mods": the rows gone, "depth": how many Depths, "ascent": whether
## the Ascent did}.
static func count_kill(state: Dictionary) -> Dictionary:
	var gone := {"mods": [], "depth": 0, "ascent": false}
	var kept: Array = []
	for mod: Dictionary in state.get("mods", []):
		mod["left"] = int(mod["left"]) - 1
		if int(mod["left"]) > 0:
			kept.append(mod)
		else:
			gone["mods"].append(mod)
	state["mods"] = kept
	var depths: Array = []
	for left: int in state.get("depth", []):
		if left - 1 > 0:
			depths.append(left - 1)
		else:
			gone["depth"] += 1
	state["depth"] = depths
	if int(state.get("ascent", 0)) > 0:
		state["ascent"] = int(state["ascent"]) - 1
		gone["ascent"] = int(state["ascent"]) == 0
	return gone


## Whether `count_kill`'s answer took anything off.
static func any_gone(gone: Dictionary) -> bool:
	return not (gone["mods"] as Array).is_empty() or int(gone["depth"]) > 0 or bool(gone["ascent"])


## A tile's rune work read back off a save: only rows that still exist and counts that make sense.
static func from_dict(data: Variant) -> Dictionary:
	var state := fresh()
	if typeof(data) != TYPE_DICTIONARY:
		return state
	for mod: Variant in data.get("mods", []):
		if typeof(mod) == TYPE_DICTIONARY and TileMods.MODS.has(str(mod.get("id", ""))):
			state["mods"].append({"id": str(mod["id"]), "tier": clampi(int(mod.get("tier", 1)), 1, MOST_TIER),
					"left": clampi(int(mod.get("left", KILLS)), 1, KILLS)})
	for left: Variant in data.get("depth", []):
		if typeof(left) in [TYPE_INT, TYPE_FLOAT] and int(left) > 0:
			state["depth"].append(mini(int(left), KILLS))
	var ascent: Variant = data.get("ascent", 0)
	state["ascent"] = clampi(int(ascent), 0, KILLS) if typeof(ascent) in [TYPE_INT, TYPE_FLOAT] else 0
	return state


static func _once(id: String) -> bool:
	return bool(TileMods.MODS[id].get("once", false))


## One of `ids`, by the weight its `TileMods` row is drawn at.
static func _drawn(ids: Array, rng: RandomNumberGenerator) -> String:
	var total := 0
	for id: String in ids:
		total += int(TileMods.MODS[id]["weight"])
	var pick := rng.randi_range(0, total - 1)
	for id: String in ids:
		pick -= int(TileMods.MODS[id]["weight"])
		if pick < 0:
			return id
	return ids[-1]
