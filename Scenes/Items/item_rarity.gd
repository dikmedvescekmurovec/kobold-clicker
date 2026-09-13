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
## UNIQUE is hand-crafted and ignores all of this. It has its slot, a colour and a zero in every row
## of TIER_WEIGHTS, so it can never be rolled, and the tests hold that until the chunk that writes it.

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

## What a dead enemy's tier is worth, as integer weights out of a thousand -- so a weight is its own
## percentage with the point moved, and nobody has to divide to read the table. Common rabble
## practically never carries anything above uncommon; a boss is the only thing worth hunting for an
## elite piece, and even then it is one drop in thirty.
const TIER_WEIGHTS := {
	EnemyRoster.Tier.COMMON: {
		Rarity.COMMON: 880, Rarity.UNCOMMON: 110, Rarity.RARE: 9, Rarity.ELITE: 1, Rarity.UNIQUE: 0,
	},
	EnemyRoster.Tier.ELITE: {
		Rarity.COMMON: 650, Rarity.UNCOMMON: 280, Rarity.RARE: 62, Rarity.ELITE: 8, Rarity.UNIQUE: 0,
	},
	EnemyRoster.Tier.BOSS: {
		Rarity.COMMON: 400, Rarity.UNCOMMON: 380, Rarity.RARE: 190, Rarity.ELITE: 30, Rarity.UNIQUE: 0,
	},
}

## How many modifiers each step carries, low and high inclusive.
const MOD_COUNT := {
	Rarity.COMMON: [0, 0],
	Rarity.UNCOMMON: [1, 2],
	Rarity.RARE: [3, 4],
	Rarity.ELITE: [5, 6],
	Rarity.UNIQUE: [0, 0],
}

## The border around an item's square, which sits on a dark socket.
const BORDER_COLORS := {
	Rarity.COMMON: Palette.STONE_LT,
	Rarity.UNCOMMON: Palette.LEAF_LT,
	Rarity.RARE: Palette.ICE,
	Rarity.ELITE: Palette.LILAC,
	Rarity.UNIQUE: Palette.GOLD,
}

## The same step written as text on the bone panel, where the lighter half of the ramp disappears.
const TEXT_COLORS := {
	Rarity.COMMON: Palette.SLATE,
	Rarity.UNCOMMON: Palette.LEAF,
	Rarity.RARE: Palette.ICE_DK,
	Rarity.ELITE: Palette.LILAC,
	Rarity.UNIQUE: Palette.GOLD,
}

## The socket every item square is drawn on, and how thick a rarity's border is on it. One panel
## pixel is an exact two on screen at ui_scale 2, so the border never lands on half a pixel.
##
## The pack draws an inventory slot as one flat tan square on the cream panel, with nothing but a
## gutter between it and the next, which is why these are opaque colours rather than a dark film over
## whatever is behind. The square being looked at sinks to the pack's wood face rather than lighting
## up: the panel behind it is cream, so anything lighter than the socket would disappear into it.
const SOCKET := Palette.SLOT_TAN
const SELECTED_SOCKET := Palette.SLOT_TAN_DK
const BORDER := 1

## Style boxes are built once and kept, the way LootTable keeps its icons: the panel rebuilds every
## square whenever something drops, and five boxes an item forever is waste for nothing.
static var _styles := {}


## The rarity of something a `tier` enemy was carrying. `rng` belongs to the caller.
static func roll(tier: EnemyRoster.Tier, rng: RandomNumberGenerator) -> Rarity:
	var weights: Dictionary = TIER_WEIGHTS[tier]
	var total := 0
	for step: Rarity in weights:
		total += int(weights[step])
	var pick := rng.randi_range(0, total - 1)
	for step: Rarity in weights:
		# A step weighted zero is stepped over for free, which is all that keeps uniques out.
		pick -= int(weights[step])
		if pick < 0:
			return step
	return Rarity.COMMON


## How many modifiers this step carries this time. The draw happens even where the band is a single
## number, so how much of the stream a drop eats does not depend on which rarity it rolled.
static func mod_count(rarity: Rarity, rng: RandomNumberGenerator) -> int:
	var band: Array = MOD_COUNT[rarity]
	return rng.randi_range(int(band[0]), int(band[1]))


## "rare", for the save file and for the stat block.
static func name_of(rarity: Rarity) -> String:
	return NAMES[rarity]


## The step a save names, or -1 when it names something this build has never heard of.
static func from_name(text: String) -> int:
	for step: Rarity in NAMES:
		if NAMES[step] == text:
			return step
	return -1


## The face of an item square: a dark socket, and a border for uncommon and better. A common square
## has no border at all, which is what makes a coloured one mean something.
static func slot_style(rarity: Rarity, selected := false) -> StyleBoxFlat:
	var key := [rarity, selected]
	if _styles.has(key):
		return _styles[key]
	var box := StyleBoxFlat.new()
	box.bg_color = SELECTED_SOCKET if selected else SOCKET
	box.set_corner_radius_all(0)
	# The default soft edge fringes into a smear once the panel is scaled up.
	box.anti_aliasing = false
	if rarity != Rarity.COMMON:
		box.set_border_width_all(BORDER)
		box.border_color = BORDER_COLORS[rarity]
	_styles[key] = box
	return box
