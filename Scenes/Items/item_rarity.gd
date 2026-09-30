class_name ItemRarity
extends RefCounted
## How good a dropped item is, and how often each step comes up.
##
## The five steps and their tables live in a file of their own rather than on Item, for two reasons.
## The plain one is that an instance and its tuning are different things, the way EnemyRoster's
## tables are separate from the enemy that is out. The technical one is that a const in one class
## that names another class's enum is where Godot's cycle checker bites: Item reads these tables, so
## these tables must never mention Item.
##
## Rarity decides how many modifiers an item carries and nothing else. Base stats belong to the gear
## type, so a common sword and an elite sword hit the same -- the elite one simply carries more on
## top. That is also why nothing here has to know what an item is.
##
## UNIQUE is hand-crafted and ignores all of this. It has its name, its colours and its level floor,
## and no place in TIER_WEIGHTS: `roll` never gives one, because `UniqueTable.roll` is what does,
## beside the gear and on odds of its own.

enum Rarity { COMMON, UNCOMMON, RARE, ELITE, UNIQUE }

## Saved and shown by name rather than by number. An enum value is only a position: inserting a step
## between two others would silently reinterpret every save on disk, and a name cannot.
const NAMES := {
	Rarity.COMMON: "common",
	Rarity.UNCOMMON: "uncommon",
	Rarity.RARE: "rare",
	Rarity.ELITE: "elite",
	Rarity.UNIQUE: "unique",
}
## What each step is called on the screen (`label_of`).
const LABELS := {
	Rarity.COMMON: "Common",
	Rarity.UNCOMMON: "Uncommon",
	Rarity.RARE: "Rare",
	Rarity.ELITE: "Epic",
	Rarity.UNIQUE: "Unique",
}

## What a dead enemy's tier is worth, as integer weights out of a thousand -- so a weight is its own
## percentage with the point moved, and nobody has to divide to read the table. Rabble carries plain
## gear three times in four, a rare piece one drop in thirty and an elite one in two hundred; a boss
## is the one body more likely than not to carry something with a modifier on it. The weight moves
## *up* the ramp as the tier rises. The one thing the curve is held to is that shape:
## `test_inventory._test_rarity_tables` fails if the plain step ever stops falling, if either top
## step stops climbing, or if the average step stops rising.
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

## How far up a tile's range a rarity starts, as a share of the ceiling.
##
## A drop's level is rolled evenly up to what the tile allows, so a common piece can come out
## anywhere in the range. A better one cannot come out at the bottom: a rare piece worth nothing is
## the one find that manages to be a disappointment, so rarity lifts the floor and a good roll is
## good on both counts at once.
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

## The border around an item's square, which sits on a dark socket. Cold to hot -- grey, blue, lilac,
## brick, gold -- so every step is a hue of its own and the order needs no convention to be read.
const BORDER_COLORS := {
	Rarity.COMMON: Palette.STONE_LT,
	Rarity.UNCOMMON: Palette.ICE,
	Rarity.RARE: Palette.LILAC,
	Rarity.ELITE: Palette.BRICK,
	Rarity.UNIQUE: Palette.GOLD,
}
## The same step written as text on the bone panel, where the lighter half of the ramp disappears.
const TEXT_COLORS := {
	Rarity.COMMON: Palette.SLATE,
	Rarity.UNCOMMON: Palette.ICE_DK,
	Rarity.RARE: Palette.LILAC,
	Rarity.ELITE: Palette.BRICK,
	Rarity.UNIQUE: Palette.GOLD,
}

## The socket every item square is drawn on.
##
## The pack draws an inventory slot as one flat tan square on the cream panel, with nothing but a
## gutter between it and the next, which is why these are opaque colours rather than a dark film over
## whatever is behind. The square being looked at sinks to the pack's wood face rather than lighting
## up: the panel behind it is cream, so anything lighter than the socket would disappear into it.
const SOCKET := Palette.SLOT_TAN
const SELECTED_SOCKET := Palette.SLOT_TAN_DK
## The frame round a square, one a step above common, drawn by `tools/item_frames.py` at the square's
## own 40 px with a clear middle: a bevel, then studs, then filigree, then a unique's gems and crest.
const FRAMES := "res://Assets/UI/item_frame_%s.png"
## How solid a socket on the equipment doll is. Enough to read as a square to drop something into,
## little enough that the figure underneath still reads as a figure.
const SOCKET_ALPHA := 0.55

## Style boxes are built once and kept, the way LootTable keeps its icons: the panel rebuilds every
## square whenever something drops, and five boxes an item forever is waste for nothing.
static var _styles := {}


## How strongly increased item rarity lifts each step: a step's weight is multiplied by
## 1 + rarity% x this. Common is never lifted, so the odds move up the ramp rather than every step
## growing alike, and the rarer a step the harder it is pushed. Unique has no weight to lift, so its
## step multiplies `UniqueTable.chance_for` instead, off the ramp: 1, the drop rate's own strength.
const RARITY_STEP := {
	Rarity.COMMON: 0,
	Rarity.UNCOMMON: 1,
	Rarity.RARE: 2,
	Rarity.ELITE: 3,
	Rarity.UNIQUE: 1,
}
## What the weights are blown up by once a rarity bonus is in play, so the lift survives being kept in
## whole numbers: a 15 weight lifted 3% is 15.45, which would round straight back to 15.
const RARITY_PRECISION := 100


## The rarity of something a `tier` enemy was carrying. `rng` belongs to the caller. `rarity` is the
## player's increased item rarity in percent; at nothing the table is drawn exactly as written, draw
## for draw, so a player who has learned nothing sees the same drops a seed always gave.
static func roll(tier: EnemyRoster.Tier, rng: RandomNumberGenerator, rarity := 0.0) -> Rarity:
	var weights := weights_for(tier, rarity)
	var total := 0
	for step: Rarity in weights:
		total += int(weights[step])
	var pick := rng.randi_range(0, total - 1)
	for step: Rarity in weights:
		pick -= int(weights[step])
		if pick < 0:
			return step
	return Rarity.COMMON


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


## The level one dropped piece comes out at: somewhere from its rarity's floor up to `ceiling`,
## evenly. The ceiling is what the tile allows and not what it pays -- farming a tile is how the top
## of its range is eventually rolled, which is the whole reason to fight the same ground twice.
##
## Always at least 1 and never above the ceiling, however low the tile is: on a level-1 tile every
## rarity's floor clamps back down to 1, so the middle of the map cannot produce an impossible roll.
static func roll_level(rarity: Rarity, ceiling: int, rng: RandomNumberGenerator) -> int:
	var top := maxi(1, ceiling)
	return rng.randi_range(clampi(ceili(top * float(LEVEL_FLOOR[rarity])), 1, top), top)


## How many modifiers this step carries this time. The draw happens even where the band is a single
## number, so how much of the stream a drop eats does not depend on which rarity it rolled.
static func mod_count(rarity: Rarity, rng: RandomNumberGenerator) -> int:
	var band: Array = MOD_COUNT[rarity]
	return rng.randi_range(int(band[0]), int(band[1]))


## "rare", for the save file. What the player reads is `label_of`.
static func name_of(rarity: Rarity) -> String:
	return NAMES[rarity]


## "Rare", as the player reads it. Apart from the save's `NAMES` since the elite step is shown as epic
## (2026-09-30): "elite" is the enemies' word, and "an elite sword" read as one an elite had dropped.
static func label_of(rarity: Rarity) -> String:
	return LABELS[rarity]


## The step a save names, or -1 when it names something this build has never heard of.
static func from_name(text: String) -> int:
	for step: Rarity in NAMES:
		if NAMES[step] == text:
			return step
	return -1


## The frame an item square wears, or null for a common one -- which is what makes a frame mean
## something.
static func frame(rarity: Rarity) -> Texture2D:
	return null if rarity == Rarity.COMMON else load(FRAMES % NAMES[rarity])


## The face of an item square: the socket alone. What rings an uncommon or better piece is drawn art
## laid over it (`frame`), so the box is the same for every rarity and `rarity` only keys the cache.
static func slot_style(rarity: Rarity, selected := false, translucent := false) -> StyleBoxFlat:
	var key := [rarity, selected, translucent]
	if _styles.has(key):
		return _styles[key]
	var box := StyleBoxFlat.new()
	box.bg_color = SELECTED_SOCKET if selected else SOCKET
	if translucent:
		# An equipment socket is laid over the doll, and an opaque square would hide the very part of
		# the body it names. The pack's own equipment screen does the same: its sockets are washes
		# over the figure, not holes cut out of it.
		box.bg_color.a = SOCKET_ALPHA
	box.set_corner_radius_all(0)
	# The default soft edge fringes into a smear once the panel is scaled up.
	box.anti_aliasing = false
	_styles[key] = box
	return box
