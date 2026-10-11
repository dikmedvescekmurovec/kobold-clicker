class_name EnemyRoster
extends RefCounted
## Every enemy the game can spawn (`ENEMIES`), one entry per folder under Assets/Enemies. Kobold Warrior
## (Assets/Potential) and the blue slime the six are recoloured from are absent on purpose.

## BOSS: one-off fights, never rolled as filler.
enum Tier { COMMON, ELITE, BOSS }

## The area of the trimmed idle frame, measured: TINY under 1000 px², SMALL under 2000, MEDIUM under
## 4000, LARGE under 6000, HUGE above. Flying Eye overrides its own: the frame is nearly all wingspan.
enum Size { TINY, SMALL, MEDIUM, LARGE, HUGE }

## Which way the pack drew its creature, read off its idle frames. `CombatActor` mirrors only RIGHT, so
## nobody walks in facing away.
enum Facing { LEFT, RIGHT }

## In the order a fight uses them. Idle and walk always exist.
const ANIMATIONS := ["idle", "walk", "attack", "hurt", "death"]

## `hp_modifier` is SIZE_HP x TIER_HP, 0.5 (a slime) to 24 (a HUGE boss): health is tuned from these two
## tables, never written per enemy.
const SIZE_HP := {
	Size.TINY: 0.5,
	Size.SMALL: 0.8,
	Size.MEDIUM: 1.0,
	Size.LARGE: 1.4,
	Size.HUGE: 2.0,
}
const TIER_HP := {
	Tier.COMMON: 1.0,
	Tier.ELITE: 3.0,
	Tier.BOSS: 12.0,
}

const ROOT := "res://Assets/Enemies/"

## The six slimes' `frames`: their packs ship a file a frame, so `sheets` is empty and this names each
## "<prefix><n>.png" series (`frame_paths`). One creature recoloured to its ground's palette ramp
## (AI-sprites-generator/slimes.py), which is why they also share a frame and a crop.
const SLIME_FRAMES := {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-",
		"hurt": "slime-hurt-", "death": "slime-die-"}

## name -> tier, size, weight, faces, environments, dir (under ROOT), frame, bounds, sheets.
## `environments` are hex_tileset.json's; with none an enemy is never drawn for a lineup.
## `weight` is its share of `pick`'s draw, whole numbers on one scale for every tier: commons 30 to 100,
## elites 8 to 20, bosses 1 to 4, bands that never overlap.
## `frame` is how the sheets are sliced and `bounds` the one crop every animation shares, so the creature
## stays put as the animation changes. Both are measured, never guessed: the folder's CLAUDE.md says
## how, and test_enemies.gd re-checks them against the sprites.
## `sheets` is the file per animation, spelled out because the packs name theirs differently; one a
## pack lacks is "" or left out.
const ENEMIES := {
	"Baby Dragon": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 10,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Baby Dragon/Sprites/outline",
		"frame": Vector2i(158, 125),
		"bounds": Rect2i(40, 36, 77, 88),
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Centaur": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 12,
		"faces": Facing.LEFT,
		"environments": ["grass", "dirt", "desert", "forest"],
		"dir": "Centaur/Sprite",
		"frame": Vector2i(100, 100),
		"bounds": Rect2i(0, 1, 89, 94),
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Cerberus": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"weight": 3,
		"faces": Facing.RIGHT,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Cerberus/New Version/Sprites/outline",
		"frame": Vector2i(128, 128),
		"bounds": Rect2i(20, 26, 106, 71),
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Cyclops": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"weight": 3,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Cyclops/New Version/Sprites/outline",
		"frame": Vector2i(245, 128),
		"bounds": Rect2i(26, 25, 140, 91),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Demon Boss": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 1,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "mountains"],
		"dir": "Demon Boss/Sprites/with_outline",
		"frame": Vector2i(162, 148),
		"bounds": Rect2i(2, 24, 160, 123),
		"sheets": {"idle": "IDLE.png", "walk": "FLYING.png", "attack": "ATTACK.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Dragon": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 2,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Dragon/Sprites/with_outline",
		"frame": Vector2i(144, 96),
		"bounds": Rect2i(10, 10, 134, 77),
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Dwarf Warrior": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 40,
		"faces": Facing.LEFT,
		"environments": ["dirt", "ice", "mountains"],
		"dir": "Dwarf Warrior/Sprite",
		"frame": Vector2i(100, 100),
		"bounds": Rect2i(7, 27, 61, 55),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Flying Eye": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 20,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Flying Eye/Sprites/outline",
		"frame": Vector2i(150, 150),
		"bounds": Rect2i(17, 16, 108, 117),
		# The pack has no idle: it hovers, so MOVE stands in for both.
		"sheets": {"idle": "MOVE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Gargoyle": {
		"tier": Tier.ELITE,
		"size": Size.LARGE,
		"weight": 8,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "mountains"],
		"dir": "Gargoyle/New Version/Sprites/outline",
		"frame": Vector2i(144, 96),
		"bounds": Rect2i(10, 4, 129, 92),
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK 1.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Goblin": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 80,
		"faces": Facing.LEFT,
		"environments": ["grass", "dirt", "forest", "mountains"],
		"dir": "Goblin/Sprites/with_outline",
		"frame": Vector2i(116, 78),
		"bounds": Rect2i(16, 8, 91, 63),
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Gryphon": {
		"tier": Tier.BOSS,
		"size": Size.MEDIUM,
		"weight": 3,
		"faces": Facing.RIGHT,
		"environments": ["grass", "desert", "ice", "mountains"],
		"dir": "Gryphon/NEW VERSION/Sprites/with_outline",
		"frame": Vector2i(112, 103),
		"bounds": Rect2i(12, 20, 96, 80),
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK 1.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Harpy": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 50,
		"faces": Facing.LEFT,
		"environments": ["desert", "ice", "mountains"],
		"dir": "Harpy/Sprite",
		"frame": Vector2i(100, 100),
		"bounds": Rect2i(7, 8, 90, 79),
		# One sheet covers hovering and flying, and the attack file is spelled ATTACk.
		"sheets": {"idle": "IDLE_MOVE.png", "walk": "IDLE_MOVE.png", "attack": "ATTACk.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Headless Horseman": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 2,
		"faces": Facing.LEFT,
		"environments": ["grass", "dirt", "ice", "forest"],
		"dir": "Headless Horseman/Sprites/outline",
		"frame": Vector2i(150, 150),
		"bounds": Rect2i(7, 19, 129, 118),
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Huge Knight": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 1,
		"faces": Facing.RIGHT,
		"environments": ["grass", "dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Huge Knight/Sprites/outline",
		"frame": Vector2i(237, 187),
		"bounds": Rect2i(4, 6, 222, 172),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Imp": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 70,
		"faces": Facing.RIGHT,
		"environments": ["grass", "dirt", "desert", "mountains"],
		"dir": "Imp/Sprites/outline",
		"frame": Vector2i(128, 48),
		"bounds": Rect2i(33, 5, 95, 41),
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Lizardman": {
		"tier": Tier.COMMON,
		"size": Size.MEDIUM,
		"weight": 30,
		"faces": Facing.RIGHT,
		"environments": ["dirt", "desert", "forest"],
		"dir": "Lizardman/New Version/Sprites/outline",
		"frame": Vector2i(144, 96),
		"bounds": Rect2i(35, 7, 87, 85),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Masked Orc": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 60,
		"faces": Facing.LEFT,
		"environments": ["grass", "dirt", "desert", "forest"],
		"dir": "Masked Orc/Sprites",
		"frame": Vector2i(150, 80),
		"bounds": Rect2i(13, 13, 103, 59),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Medusa": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 10,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Medusa/Sprite",
		"frame": Vector2i(150, 125),
		"bounds": Rect2i(11, 52, 112, 57),
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	# Only ever put alone on a chest tile (`Encounter.for_tile`). A boss and HUGE on purpose, not by
	# measurement, so the one body carries a boss's health and drop odds.
	"Mimic": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 1,
		"faces": Facing.RIGHT,
		"environments": [],
		"dir": "Mimic/Sprite",
		"frame": Vector2i(158, 125),
		"bounds": Rect2i(26, 13, 99, 83),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	# The ice wall round the land (`MapBuilder.is_wall`), fought alone like the mimic. One still picture
	# stands for idle and walk.
	"The Ice Wall": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 1,
		"faces": Facing.LEFT,
		"environments": [],
		"dir": "The Wall",
		"frame": Vector2i(96, 96),
		"bounds": Rect2i(4, 3, 88, 90),
		"sheets": {"idle": "pixellab-A-tall-wall-of-ice--Like-the-g-1789766464814.png",
				"walk": "pixellab-A-tall-wall-of-ice--Like-the-g-1789766464814.png", "attack": "", "hurt": "", "death": ""},
	},
	"Minotaur": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"weight": 4,
		"faces": Facing.RIGHT,
		"environments": ["grass", "dirt", "forest", "mountains"],
		"dir": "Minotaur/Sprites/with_outline",
		"frame": Vector2i(128, 128),
		"bounds": Rect2i(11, 9, 113, 110),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Poison Skull": {
		"tier": Tier.COMMON,
		"size": Size.MEDIUM,
		"weight": 30,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "forest"],
		"dir": "Poison Skull/Sprite",
		"frame": Vector2i(150, 100),
		"bounds": Rect2i(1, 40, 107, 55),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Pyromancer": {
		"tier": Tier.ELITE,
		"size": Size.SMALL,
		"weight": 16,
		"faces": Facing.RIGHT,
		"environments": ["dirt", "desert", "mountains"],
		"dir": "Pyromancer/Sprites",
		"frame": Vector2i(100, 100),
		"bounds": Rect2i(27, 10, 62, 75),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Satyr Archer": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 40,
		"faces": Facing.LEFT,
		"environments": ["grass", "forest", "mountains"],
		"dir": "Satyr Archer/Sprite",
		"frame": Vector2i(125, 100),
		"bounds": Rect2i(5, 28, 80, 51),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Skeleton Mage": {
		"tier": Tier.ELITE,
		"size": Size.LARGE,
		"weight": 10,
		"faces": Facing.RIGHT,
		"environments": ["dirt", "desert", "ice", "mountains"],
		"dir": "Skeleton Mage/Sprites/outline",
		"frame": Vector2i(128, 128),
		"bounds": Rect2i(18, 33, 110, 79),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Skeleton Warrior": {
		"tier": Tier.COMMON,
		"size": Size.MEDIUM,
		"weight": 50,
		"faces": Facing.LEFT,
		"environments": ["grass", "dirt", "desert", "ice", "mountains"],
		"dir": "Skeleton Warrior/Sprites/with_outline",
		"frame": Vector2i(89, 78),
		"bounds": Rect2i(5, 0, 84, 77),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	"Desert Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.LEFT,
		"environments": ["desert"],
		"dir": "Desert Slime",
		"frame": Vector2i(32, 25),
		"bounds": Rect2i(0, 4, 31, 20),
		"sheets": {},
		"frames": SLIME_FRAMES,
	},
	"Dirt Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.LEFT,
		"environments": ["dirt"],
		"dir": "Dirt Slime",
		"frame": Vector2i(32, 25),
		"bounds": Rect2i(0, 4, 31, 20),
		"sheets": {},
		"frames": SLIME_FRAMES,
	},
	"Forest Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.LEFT,
		"environments": ["forest"],
		"dir": "Forest Slime",
		"frame": Vector2i(32, 25),
		"bounds": Rect2i(0, 4, 31, 20),
		"sheets": {},
		"frames": SLIME_FRAMES,
	},
	"Grass Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.LEFT,
		"environments": ["grass"],
		"dir": "Grass Slime",
		"frame": Vector2i(32, 25),
		"bounds": Rect2i(0, 4, 31, 20),
		"sheets": {},
		"frames": SLIME_FRAMES,
	},
	"Ice Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.LEFT,
		"environments": ["ice"],
		"dir": "Ice Slime",
		"frame": Vector2i(32, 25),
		"bounds": Rect2i(0, 4, 31, 20),
		"sheets": {},
		"frames": SLIME_FRAMES,
	},
	"Mountain Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.LEFT,
		"environments": ["mountains"],
		"dir": "Mountain Slime",
		"frame": Vector2i(32, 25),
		"bounds": Rect2i(0, 4, 31, 20),
		"sheets": {},
		"frames": SLIME_FRAMES,
	},
	"Stone Golem": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"weight": 3,
		"faces": Facing.LEFT,
		"environments": ["dirt", "desert", "ice", "mountains"],
		"dir": "Stone Golem/new version/Sprites/outline",
		"frame": Vector2i(220, 96),
		"bounds": Rect2i(0, 8, 156, 76),
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Werewolf": {
		"tier": Tier.ELITE,
		"size": Size.LARGE,
		"weight": 8,
		"faces": Facing.RIGHT,
		"environments": ["grass", "dirt", "ice", "forest", "mountains"],
		"dir": "Werewolf/Sprites/outline",
		"frame": Vector2i(158, 125),
		"bounds": Rect2i(30, 42, 123, 74),
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Witch": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 14,
		"faces": Facing.LEFT,
		"environments": ["dirt", "ice", "forest", "mountains"],
		"dir": "Witch/Sprite",
		"frame": Vector2i(125, 125),
		"bounds": Rect2i(42, 37, 68, 84),
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Wizard": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 14,
		"faces": Facing.LEFT,
		"environments": ["grass", "dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Wizard/Sprites/with_outline",
		"frame": Vector2i(128, 78),
		"bounds": Rect2i(26, 9, 102, 57),
		# The pack splits its attack in two; the melee swing is the one a tile fight uses.
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "MELEE ATTACK.png", "hurt": "HURT.png",
				"death": "DEATH.png"},
	},
	# The dungeon's own, cut by `tools/cave_dungeon.py`, which prints each frame and crop. "cave" is no
	# land on the map, so no tile ever fields one.
	"Rat": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 80,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Rat",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(22, 32, 24, 17),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Bat": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 70,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Bat",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(21, 21, 23, 28),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Pebble": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 60,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Pebble",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(23, 17, 29, 32),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Spiked Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 100,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Spiked Slime",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(16, 24, 32, 25),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Crab": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 50,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Crab",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(18, 30, 29, 19),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Skull": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"weight": 40,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Skull",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(25, 23, 22, 41),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Golem": {
		"tier": Tier.ELITE,
		"size": Size.SMALL,
		"weight": 20,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Golem",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(15, 15, 33, 34),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Armored Golem": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"weight": 12,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Armored Golem",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(15, 15, 33, 34),
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png", "death": "death.png"},
	},
	"Gollux": {
		"tier": Tier.BOSS,
		# Measured he is HUGE, but he is as wide as he is tall and at that size stood on his own nameplate.
		"size": Size.LARGE,
		"weight": 1,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Gollux",
		"frame": Vector2i(128, 128),
		"bounds": Rect2i(34, 64, 75, 64),
		# The pack draws him no death: he bursts like anybody else.
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png"},
	},
}


## In the table's order.
static func names() -> PackedStringArray:
	return PackedStringArray(ENEMIES.keys())


static func tier_of(name: String) -> Tier:
	return ENEMIES[name]["tier"]


static func size_of(name: String) -> Size:
	return ENEMIES[name]["size"]


static func facing_of(name: String) -> Facing:
	return ENEMIES[name]["faces"]


## What an encounter's base health is multiplied by for this enemy.
static func hp_modifier(name: String) -> float:
	return SIZE_HP[size_of(name)] * TIER_HP[tier_of(name)]


static func weight_of(name: String) -> int:
	return ENEMIES[name]["weight"]


## One frame of a sheet, or one file of a frame-per-file pack.
static func frame_size(name: String) -> Vector2i:
	return ENEMIES[name]["frame"]


static func bounds_of(name: String) -> Rect2i:
	return ENEMIES[name]["bounds"]


## 0 when the pack has no such animation.
static func frame_count(name: String, animation: String) -> int:
	var path := sheet_path(name, animation)
	if path.is_empty():
		return frame_paths(name, animation).size()
	# Asked of the texture: reading the sheet back as an image was slow, five times a spawn.
	var sheet: Texture2D = load(path)
	return 0 if sheet == null else sheet.get_width() / frame_size(name).x


## A sheet's pixels, only ever to measure it (`portrait`, `CombatActor._standing_rect`): drawing uses
## AtlasTexture regions. A texture has no readable image under --headless, hence the file.
static func sheet_image(path: String) -> Image:
	var texture: Texture2D = load(path)
	var image := texture.get_image() if texture else null
	if image == null or image.is_empty():
		image = Image.load_from_file(path)
	if image != null and image.is_compressed():
		image.decompress()
	return image


static func environments_of(name: String) -> PackedStringArray:
	return PackedStringArray(ENEMIES[name]["environments"])


## The enemies living on `env`, of one `tier` or (null) of every tier, in the table's order.
static func in_environment(env: String, tier: Variant = null) -> PackedStringArray:
	var found := PackedStringArray()
	for name: String in ENEMIES:
		if not env in ENEMIES[name]["environments"]:
			continue
		if tier != null and ENEMIES[name]["tier"] != tier:
			continue
		found.append(name)
	return found


## One enemy for `env`, drawn by `weight`, or "" when that terrain has none of that tier. The walk every
## table draws by, so a draw is a pure function of one `randi_range` and a seeded fight stays the same
## fight.
static func pick(env: String, tier: Variant, rng: RandomNumberGenerator) -> String:
	var candidates := in_environment(env, tier)
	if candidates.is_empty():
		return ""
	var weights := Array(candidates).map(func(name: String) -> int: return weight_of(name))
	return candidates[LootTable.weighted_index(weights, rng)]


## "" when the pack lacks the animation, and for a frame-per-file pack (`frame_paths`).
static func sheet_path(name: String, animation: String) -> String:
	var entry: Dictionary = ENEMIES[name]
	var sheet: String = entry["sheets"].get(animation, "")
	var dir: String = entry["dir"]
	return "" if sheet.is_empty() else ROOT + dir + "/" + sheet


## A frame-per-file pack's files for one animation, in order, up to the first number with no file;
## empty for a sheet pack.
static func frame_paths(name: String, animation: String) -> PackedStringArray:
	var entry: Dictionary = ENEMIES[name]
	var frames := PackedStringArray()
	if not entry.has("frames"):
		return frames
	var prefix: String = entry["frames"].get(animation, "")
	if prefix.is_empty():
		return frames
	var dir: String = entry["dir"]
	var n := 0
	while true:
		var path := ROOT + dir + "/" + prefix + str(n) + ".png"
		if not ResourceLoader.exists(path):
			break
		frames.append(path)
		n += 1
	return frames


## The first idle frame cut to the pixels it uses, or null when the pack has no idle. Not `bounds`: the
## union of every animation leaves a creature with a long swing small in its own portrait.
static func portrait(name: String) -> AtlasTexture:
	var path := sheet_path(name, "idle")
	var cell := Rect2i(Vector2i.ZERO, frame_size(name))
	if path.is_empty():
		var files := frame_paths(name, "idle")
		if files.is_empty():
			return null
		path = files[0]
	var image := sheet_image(path)
	if image == null:
		return null
	var used := image.get_region(cell).get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(used if used.size != Vector2i.ZERO else cell)
	return atlas
