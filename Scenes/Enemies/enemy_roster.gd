class_name EnemyRoster
extends RefCounted
## Every enemy the game can spawn, the terrain it lives on and where its sprite sheets are.
##
## One entry per folder under Assets/Enemies. `environments` names the environments of
## hex_tileset.json, so an enemy is only ever placed on terrain that was drawn for it, and `tier`
## separates the wandering rabble from the things worth a fight. Health is not written per enemy:
## `size` and `tier` multiply into it, so the whole curve is tuned from SIZE_HP and TIER_HP rather
## than by editing thirty numbers. How often an enemy turns up is the other way round: `weight` is
## written on each entry, because being numerous has little to do with being big -- goblins come in
## packs, a mimic waits alone, a dragon is a set piece. The sheet names differ from pack to
## pack (RUN vs WALK vs MOVE, "ATTACK 1" vs ATTACK1), so each entry spells its own out rather than
## guessing from the folder; an animation a pack does not have is an empty string.
##
## Kobold Warrior stayed in Assets/Potential and is deliberately absent, as is the blue slime the six
## environment slimes are recoloured from.

enum Tier {
	COMMON,  ## Wandering encounters, the bulk of a walk.
	ELITE,   ## Rarer, tougher, usually a caster or a beast.
	BOSS,    ## One-off fights; never rolled as filler.
}

## How much room the creature takes on a tile, measured off the trimmed idle frame rather than judged:
## TINY under 1000 px², SMALL under 2000, MEDIUM under 4000, LARGE under 6000, HUGE above it.
## Flying Eye is the one entry that overrides its measurement -- the frame is nearly all wingspan.
enum Size { TINY, SMALL, MEDIUM, LARGE, HUGE }

## Which way a pack drew its creature. The packs do not agree -- most face left, nine face right --
## so every entry says, read off its own idle frames, and CombatActor mirrors the ones that need it
## rather than mirroring the lot. An enemy that comes in facing away from the player is the bug this
## exists to stop.
enum Facing { LEFT, RIGHT }

## Animations every entry names, in the order a fight uses them. IDLE and WALK always exist.
const ANIMATIONS := ["idle", "walk", "attack", "hurt", "death"]

## What a body of each size is worth in health. A slime dies to a poke; a huge one soaks four times
## what an ordinary humanoid does.
const SIZE_HP := {
	Size.TINY: 0.5,
	Size.SMALL: 0.8,
	Size.MEDIUM: 1.0,
	Size.LARGE: 1.4,
	Size.HUGE: 2.0,
}

## What the tier is worth on top of the body. Bosses are meant to be unreasonable: the largest of them
## carries 48 times a slime's health, so one is never a fight the player wanders into by accident.
const TIER_HP := {
	Tier.COMMON: 1.0,
	Tier.ELITE: 3.0,
	Tier.BOSS: 12.0,
}

const ROOT := "res://Assets/Enemies/"

## `frame` is how the pack's sheets are sliced and `bounds` the part of a frame the creature uses across
## every one of its animations, so one shared crop keeps it still when the animation changes and centres it
## on its spot -- the same trick PlayerToken.BOUNDS plays for the player. Both are measured, not guessed:
## the frame width is the smallest divisor of every sheet width in the pack where each frame boundary falls
## on a fully transparent column, which is what test_enemies.gd re-checks against the sprites.
##
## `weight` is how much of a tile's draw this enemy takes against the others living there -- see `pick`.
## Whole numbers on one absolute scale, not one scale per tier: commons run 30 to 100, elites 8 to 20,
## bosses 1 to 4. The bands never overlap, so a draw that asks for any tier at all still mostly turns up
## rabble, and the ratios inside a band are what actually shows: a slime for every two goblins.
##
## folder -> tier, size, weight, facing, environments, the sprite directory under ROOT, and the sheet file per animation.
## The six slimes are the packs shipped as separate frames, so their sheets are empty and `frames`
## names the "<prefix><n>.png" series instead. They share one frame size and one crop because they are
## one creature recoloured: AI-sprites-generator/slimes.py swaps the blue pack under
## Assets/Enemies/Slime onto each environment's palette ramp, so each slime is the colour of the
## ground it lives on and appears on that terrain alone. The blue original stays as the generator's
## source and is deliberately absent here, the way Kobold Warrior is.
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
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
		"sheets": {"idle": "IDLE.png", "walk": "FLYING.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
		"sheets": {"idle": "IDLE_MOVE.png", "walk": "IDLE_MOVE.png", "attack": "ATTACk.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
	# Lives in no environment: it is never drawn for a lineup, only put alone on a chest tile
	# (`Encounter.for_tile`). A boss and sized HUGE on purpose rather than by measurement, so the
	# one body carries a boss's health and drop odds.
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
	# The ice wall round the land (`MapBuilder.is_wall`), fought alone like the mimic and living nowhere.
	# One still picture, so it stands for idle and walk and the rest are left out.
	"The Ice Wall": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"weight": 1,
		"faces": Facing.LEFT,
		"environments": [],
		"dir": "The Wall",
		"frame": Vector2i(96, 96),
		"bounds": Rect2i(4, 3, 88, 90),
		"sheets": {"idle": "pixellab-A-tall-wall-of-ice--Like-the-g-1789766464814.png", "walk": "pixellab-A-tall-wall-of-ice--Like-the-g-1789766464814.png", "attack": "", "hurt": "", "death": ""},
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
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
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
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
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
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
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
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
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
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
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
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
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
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
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
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "MELEE ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	# The dungeon's own, all Admurin's and all cut by `tools/cave_dungeon.py`, which prints each frame and
	# crop. They live in the cave and nowhere on the map, so no tile ever fields one.
	"Rat": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"weight": 80,
		"faces": Facing.RIGHT,
		"environments": ["cave"],
		"dir": "Rat",
		"frame": Vector2i(64, 64),
		"bounds": Rect2i(23, 33, 22, 15),
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
		"bounds": Rect2i(22, 22, 21, 26),
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
		"bounds": Rect2i(24, 18, 27, 30),
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
		"bounds": Rect2i(17, 25, 30, 23),
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
		"bounds": Rect2i(19, 31, 27, 17),
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
		"bounds": Rect2i(26, 24, 20, 40),
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
		"bounds": Rect2i(16, 16, 31, 32),
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
		"bounds": Rect2i(16, 16, 31, 32),
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
		"bounds": Rect2i(35, 65, 73, 63),
		# The pack draws him no death: he bursts like anybody else.
		"sheets": {"idle": "idle.png", "walk": "walk.png", "attack": "attack.png", "hurt": "hurt.png"},
	},
}


## Every enemy name, in the order they are written above.
static func names() -> PackedStringArray:
	var all := PackedStringArray()
	for name: String in ENEMIES:
		all.append(name)
	return all


static func tier_of(name: String) -> Tier:
	return ENEMIES[name]["tier"]


static func size_of(name: String) -> Size:
	return ENEMIES[name]["size"]


## Which way the pack's art points, before anything mirrors it.
static func facing_of(name: String) -> Facing:
	return ENEMIES[name]["faces"]


## What to multiply an encounter's base health by for this enemy: its body times its tier. Ranges from
## 0.5 (the slime) to 24.0 (Huge Knight, Demon Boss): a boss is 48 slimes on the same tile.
static func hp_modifier(name: String) -> float:
	return SIZE_HP[size_of(name)] * TIER_HP[tier_of(name)]


## How much of a tile's draw this enemy takes up, against the others that live on the same terrain.
static func weight_of(name: String) -> int:
	return ENEMIES[name]["weight"]


## The size of one frame on this enemy's sheets, and of each of its files for a frame-per-file pack.
static func frame_size(name: String) -> Vector2i:
	return ENEMIES[name]["frame"]


## The part of a frame worth drawing, shared by all of the enemy's animations.
static func bounds_of(name: String) -> Rect2i:
	return ENEMIES[name]["bounds"]


## How many frames an animation has: its sheet's width over the frame width, or the files on disk for a
## frame-per-file pack. 0 when the pack has no such animation.
static func frame_count(name: String, animation: String) -> int:
	var path := sheet_path(name, animation)
	if path.is_empty():
		return frame_paths(name, animation).size()
	var image := _sheet_image(path)
	return 0 if image == null else image.get_width() / frame_size(name).x


## Sheets are read as images only to measure and check them; drawing uses AtlasTexture regions instead.
## Textures have no readable image under --headless, so fall back to the file, as HexTileset does.
static func _sheet_image(path: String) -> Image:
	var texture: Texture2D = load(path)
	var image := texture.get_image() if texture else null
	if image == null or image.is_empty():
		image = Image.load_from_file(path)
	if image != null and image.is_compressed():
		image.decompress()
	return image


static func environments_of(name: String) -> PackedStringArray:
	return PackedStringArray(ENEMIES[name]["environments"])


## The enemies that can appear on `env`, optionally narrowed to one tier. Pass no tier for all of them.
static func in_environment(env: String, tier: Variant = null) -> PackedStringArray:
	var found := PackedStringArray()
	for name: String in ENEMIES:
		if not env in ENEMIES[name]["environments"]:
			continue
		if tier != null and ENEMIES[name]["tier"] != tier:
			continue
		found.append(name)
	return found


## Picks one enemy for `env`, or "" when that terrain has none of that tier. `rng` decides, weighted by
## `weight`, so a terrain's small fry crowd out its rarer company instead of every candidate being
## equally likely. Laying the weights end to end and walking them keeps the draw a pure function of one
## `randi_range`, so a seeded fight stays the same fight however the weights are retuned.
static func pick(env: String, tier: Variant, rng: RandomNumberGenerator) -> String:
	var candidates := in_environment(env, tier)
	if candidates.is_empty():
		return ""
	var total := 0
	for name in candidates:
		total += weight_of(name)
	var roll := rng.randi_range(0, total - 1)
	for name in candidates:
		roll -= weight_of(name)
		if roll < 0:
			return name
	return candidates[candidates.size() - 1]


## The sheet of one animation, e.g. sheet_path("Goblin", "walk"). "" when the pack lacks it, and for
## the frame-per-file packs, which frame_paths covers instead.
static func sheet_path(name: String, animation: String) -> String:
	var entry: Dictionary = ENEMIES[name]
	var sheet: String = entry["sheets"].get(animation, "")
	var dir: String = entry["dir"]
	return "" if sheet.is_empty() else ROOT + dir + "/" + sheet


## The frames of one animation for a pack shipped as separate files, in order; empty for sheet packs.
## Stops at the first number that has no file, so the pack's own frame count decides the length.
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


## The enemy standing still, as one picture: the first idle frame cut down to the pixels it uses. Not
## `bounds`, which is the union of every animation and leaves a creature with a long swing small in
## the middle of its own portrait. Null when the pack has no idle.
static func portrait(name: String) -> AtlasTexture:
	var path := sheet_path(name, "idle")
	var cell := Rect2i(Vector2i.ZERO, frame_size(name))
	if path.is_empty():
		var files := frame_paths(name, "idle")
		if files.is_empty():
			return null
		path = files[0]
	var image := _sheet_image(path)
	if image == null:
		return null
	var used := image.get_region(cell).get_used_rect()
	var atlas := AtlasTexture.new()
	atlas.atlas = load(path)
	atlas.region = Rect2(used if used.size != Vector2i.ZERO else cell)
	return atlas
