class_name ItemRarity
extends RefCounted
## The five rarity steps and their tables. Rarity decides how many modifiers a piece carries and
## nothing else: base stats are the gear type's. Apart from `Item` and never naming it: `Item` reads
## these tables, and a const naming another class's enum is where Godot's cycle checker bites.

enum Rarity { COMMON, UNCOMMON, RARE, ELITE, UNIQUE }

## What a save holds: names, never enum positions.
const NAMES := {
	Rarity.COMMON: "common",
	Rarity.UNCOMMON: "uncommon",
	Rarity.RARE: "rare",
	Rarity.ELITE: "elite",
	Rarity.UNIQUE: "unique",
}
## What the screen says (`label_of`). The elite step is "Epic" since 2026-09-30: "elite" is the
## enemies' word, and "an elite sword" read as one an elite had dropped.
const LABELS := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.ELITE: "Epic",
	Rarity.UNIQUE: "Unique",
}

## Enemy tier -> each step's weight out of a thousand. UNIQUE has none and must have none: `roll` never
## gives one (`UniqueTable.roll` does, beside the gear). `test_inventory._test_rarity_tables` holds the
## curve's shape as the tier rises: the plain step falling, both top steps and the average step climbing.
const TIER_WEIGHTS := {
	EnemyRoster.Tier.COMMON: {
		Rarity.COMMON: 750, Rarity.UNCOMMON: 210, Rarity.RARE: 35, Rarity.ELITE: 5,
	},
	EnemyRoster.Tier.ELITE: {
		Rarity.COMMON: 500, Rarity.UNCOMMON: 350, Rarity.RARE: 120, Rarity.ELITE: 30,
	},
	EnemyRoster.Tier.BOSS: {
		Rarity.COMMON: 250, Rarity.UNCOMMON: 400, Rarity.RARE: 250, Rarity.ELITE: 100,
	},
}

## How far up a tile's range a rarity's level starts, as a share of the ceiling (`roll_level`).
const LEVEL_FLOOR := {
	Rarity.COMMON: 0.0,
	Rarity.UNCOMMON: 0.2,
	Rarity.RARE: 0.4,
	Rarity.ELITE: 0.6,
	Rarity.UNIQUE: 0.8,
}

## How many modifiers each step carries, low and high inclusive.
const MOD_COUNT := {
	Rarity.COMMON: [0, 0],
	Rarity.UNCOMMON: [1, 2],
	Rarity.RARE: [3, 4],
	Rarity.ELITE: [5, 6],
	Rarity.UNIQUE: [0, 0],
}
## A skill stone's: one line a step (the user's, 2026-10-08). `band` picks between the two.
const STONE_MOD_COUNT := {
	Rarity.COMMON: [0, 0],
	Rarity.UNCOMMON: [1, 1],
	Rarity.RARE: [2, 2],
	Rarity.ELITE: [3, 3],
	Rarity.UNIQUE: [0, 0],
}

## Each step's colour on the socket, a hue apiece.
const BORDER_COLORS := {
	Rarity.COMMON: Palette.STONE_LT,
	Rarity.UNCOMMON: Palette.ICE,
	Rarity.RARE: Palette.LILAC,
	Rarity.ELITE: Palette.BRICK,
	Rarity.UNIQUE: Palette.GOLD,
}
## The same steps as text on the bone panel, where the lighter half of that ramp disappears.
const TEXT_COLORS := {
	Rarity.COMMON: Palette.SLATE,
	Rarity.UNCOMMON: Palette.ICE_DK,
	Rarity.RARE: Palette.LILAC,
	Rarity.ELITE: Palette.BRICK,
	Rarity.UNIQUE: Palette.GOLD_TEXT,
}

## The socket every item square is drawn on, opaque, and the one being looked at: darker, since on the
## cream panel anything lighter than the socket would disappear.
const SOCKET := Palette.SLOT_TAN
const SELECTED_SOCKET := Palette.SLOT_TAN_DK
## The frame round a square above common, drawn by `tools/item_frames.py` (the user's design,
## 2026-10-04); a unique's is its rank's (`UNIQUE_FRAMES`, 0 a starter's). A frame is the square's
## width and `FRAME_HEAD` taller: its caps and crest stand up into the gutter over the square, never
## past its sides, where a scroll as wide as the grid would clip them.
const FRAMES := "res://Assets/UI/item_frame_%s.png"
const UNIQUE_FRAMES := "res://Assets/UI/item_frame_unique_%d.png"
const FRAME_HEAD := 4
## A framed socket's chamfer (`corner_detail` 1), so no tan shows outside the ring: exactly the three
## pixels a corner the ring leaves clear.
const FRAME_CORNER := 3
## How solid a socket on the equipment doll is: the figure under it must still read as a figure.
const SOCKET_ALPHA := 0.55

## [rarity, selected, translucent] -> its style box, built once.
static var _styles := {}


## How strongly increased item rarity lifts each step: its weight is multiplied by 1 + rarity% x this.
## UNIQUE has no weight to lift, so its step multiplies `UniqueTable.chance_for` instead: 1, the drop
## rate's own strength (the user's, 2026-09-28).
const RARITY_STEP := {
	Rarity.COMMON: 0,
	Rarity.UNCOMMON: 1,
	Rarity.RARE: 2,
	Rarity.ELITE: 3,
	Rarity.UNIQUE: 1,
}
## What the weights are blown up by once a rarity bonus is in play, so the lift survives whole
## numbers: a 15 weight lifted 3% is 15.45.
const RARITY_PRECISION := 100


## The rarity of something a `tier` enemy was carrying. `rarity` is the player's increased item rarity
## in percent; at none the table is drawn exactly as written, draw for draw.
static func roll(tier: EnemyRoster.Tier, rng: RandomNumberGenerator, rarity := 0.0) -> Rarity:
	var weights := weights_for(tier, rarity)
	return weights.keys()[LootTable.weighted_index(weights.values(), rng)]


## A tier's weights with `rarity` percent increased item rarity applied. The table itself at nothing.
static func weights_for(tier: EnemyRoster.Tier, rarity := 0.0) -> Dictionary:
	var weights: Dictionary = TIER_WEIGHTS[tier]
	if rarity <= 0.0:
		return weights
	var lifted := {}
	for step: Rarity in weights:
		lifted[step] = roundi(int(weights[step]) * RARITY_PRECISION
				* (1.0 + rarity / 100.0 * int(RARITY_STEP[step])))
	return lifted


## The level one drop comes out at: evenly from its rarity's floor up to `ceiling`, and always from 1
## to `ceiling`, however low the tile.
static func roll_level(rarity: Rarity, ceiling: int, rng: RandomNumberGenerator) -> int:
	var top := maxi(1, ceiling)
	return rng.randi_range(clampi(ceili(top * float(LEVEL_FLOOR[rarity])), 1, top), top)


## How many modifiers this step carries this time. Drawn even where the band is one number, so how
## much of the stream a drop eats does not depend on its rarity.
static func mod_count(rarity: Rarity, rng: RandomNumberGenerator, item_type := "") -> int:
	var count := band(rarity, item_type)
	return rng.randi_range(int(count[0]), int(count[1]))


## The fewest and most modifiers a piece of `item_type` carries at this step: a skill stone's table, or
## everything else's.
static func band(rarity: Rarity, item_type := "") -> Array:
	var stone := LootTable.ITEMS.has(item_type) and LootTable.slot_of(item_type) == SkillTree.SLOT
	return (STONE_MOD_COUNT if stone else MOD_COUNT)[rarity]


static func name_of(rarity: Rarity) -> String:
	return NAMES[rarity]


static func label_of(rarity: Rarity) -> String:
	return LABELS[rarity]


## The step a save names, or -1 when it names something this build has never heard of.
static func from_name(text: String) -> int:
	for step: Rarity in NAMES:
		if NAMES[step] == text:
			return step
	return -1


## The frame an item square wears; null for a common one. `rank` is a unique's (0 a starter's, up to
## `UniqueTable.PEAK`); a square with no piece behind it (a bounty's promise) wears rank I's.
static func frame(rarity: Rarity, rank := 1) -> Texture2D:
	if rarity == Rarity.COMMON:
		return null
	if rarity == Rarity.UNIQUE:
		return load(UNIQUE_FRAMES % clampi(rank, 0, 4))
	return load(FRAMES % NAMES[rarity])


## The face of an item square: the socket alone, since the frame is art laid over it (`frame`). A
## framed one's corners are cut back to the ring's (`FRAME_CORNER`); a translucent one is the doll's.
static func slot_style(rarity: Rarity, selected := false, translucent := false) -> StyleBoxFlat:
	var key := [rarity, selected, translucent]
	if _styles.has(key):
		return _styles[key]
	var box := StyleBoxFlat.new()
	box.bg_color = SELECTED_SOCKET if selected else SOCKET
	if translucent:
		box.bg_color.a = SOCKET_ALPHA
	box.set_corner_radius_all(0 if rarity == Rarity.COMMON else FRAME_CORNER)
	box.corner_detail = 1
	# The default soft edge smears once the panel is scaled up.
	box.anti_aliasing = false
	_styles[key] = box
	return box
