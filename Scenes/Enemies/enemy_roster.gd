class_name EnemyRoster
extends RefCounted
## Every enemy the game can spawn, the terrain it lives on and where its sprite sheets are.
##
## One entry per folder under Assets/Enemies. `environments` names the environments of
## hex_tileset.json, so an enemy is only ever placed on terrain that was drawn for it, and `tier`
## separates the wandering rabble from the things worth a fight. Health is not written per enemy:
## `size` and `tier` multiply into it, so the whole curve is tuned from SIZE_HP and TIER_HP rather
## than by editing thirty numbers. The sheet names differ from pack to
## pack (RUN vs WALK vs MOVE, "ATTACK 1" vs ATTACK1), so each entry spells its own out rather than
## guessing from the folder; an animation a pack does not have is an empty string.
##
## Kobold Warrior stayed in Assets/Potential and is deliberately absent.

enum Tier {
	COMMON,  ## Wandering encounters, the bulk of a walk.
	ELITE,   ## Rarer, tougher, usually a caster or a beast.
	BOSS,    ## One-off fights; never rolled as filler.
}

## How much room the creature takes on a tile, measured off the trimmed idle frame rather than judged:
## TINY under 1000 px², SMALL under 2000, MEDIUM under 4000, LARGE under 6000, HUGE above it.
## Flying Eye is the one entry that overrides its measurement — the frame is nearly all wingspan.
enum Size { TINY, SMALL, MEDIUM, LARGE, HUGE }

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

## folder -> tier, size, environments, the sprite directory under ROOT, and the sheet file per animation.
## Slime is the one pack shipped as separate frames, so its sheets are empty and `frames` names the
## "<prefix><n>.png" series instead.
const ENEMIES := {
	"Baby Dragon": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Baby Dragon/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Centaur": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["grass", "dirt", "desert", "forest"],
		"dir": "Centaur/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Cerberus": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Cerberus/New Version/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Cyclops": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Cyclops/New Version/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Demon Boss": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"environments": ["dirt", "desert", "mountains"],
		"dir": "Demon Boss/Sprites/with_outline",
		"sheets": {"idle": "IDLE.png", "walk": "FLYING.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Dragon": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"environments": ["dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Dragon/Sprites/with_outline",
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Dwarf Warrior": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"environments": ["dirt", "ice", "mountains"],
		"dir": "Dwarf Warrior/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Flying Eye": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Flying Eye/Sprites/outline",
		# The pack has no idle: it hovers, so MOVE stands in for both.
		"sheets": {"idle": "MOVE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Gargoyle": {
		"tier": Tier.ELITE,
		"size": Size.LARGE,
		"environments": ["dirt", "desert", "mountains"],
		"dir": "Gargoyle/New Version/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Goblin": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"environments": ["grass", "dirt", "forest", "mountains"],
		"dir": "Goblin/Sprites/with_outline",
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Gryphon": {
		"tier": Tier.BOSS,
		"size": Size.MEDIUM,
		"environments": ["grass", "desert", "ice", "mountains"],
		"dir": "Gryphon/NEW VERSION/Sprites/with_outline",
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Harpy": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"environments": ["desert", "ice", "mountains"],
		"dir": "Harpy/Sprite",
		# One sheet covers hovering and flying, and the attack file is spelled ATTACk.
		"sheets": {"idle": "IDLE_MOVE.png", "walk": "IDLE_MOVE.png", "attack": "ATTACk.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Headless Horseman": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"environments": ["grass", "dirt", "ice", "forest"],
		"dir": "Headless Horseman/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Huge Knight": {
		"tier": Tier.BOSS,
		"size": Size.HUGE,
		"environments": ["grass", "dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Huge Knight/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Imp": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"environments": ["grass", "dirt", "desert", "mountains"],
		"dir": "Imp/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Lizardman": {
		"tier": Tier.COMMON,
		"size": Size.MEDIUM,
		"environments": ["dirt", "desert", "forest"],
		"dir": "Lizardman/New Version/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Masked Orc": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"environments": ["grass", "dirt", "desert", "forest"],
		"dir": "Masked Orc/Sprites",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Medusa": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Medusa/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Mimic": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["dirt", "desert", "forest", "mountains"],
		"dir": "Mimic/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Minotaur": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"environments": ["grass", "dirt", "forest", "mountains"],
		"dir": "Minotaur/Sprites/with_outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Poison Skull": {
		"tier": Tier.COMMON,
		"size": Size.MEDIUM,
		"environments": ["dirt", "desert", "forest"],
		"dir": "Poison Skull/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Pyromancer": {
		"tier": Tier.ELITE,
		"size": Size.SMALL,
		"environments": ["dirt", "desert", "mountains"],
		"dir": "Pyromancer/Sprites",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Satyr Archer": {
		"tier": Tier.COMMON,
		"size": Size.SMALL,
		"environments": ["grass", "forest", "mountains"],
		"dir": "Satyr Archer/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Skeleton Mage": {
		"tier": Tier.ELITE,
		"size": Size.LARGE,
		"environments": ["dirt", "desert", "ice", "mountains"],
		"dir": "Skeleton Mage/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Skeleton Warrior": {
		"tier": Tier.COMMON,
		"size": Size.MEDIUM,
		"environments": ["grass", "dirt", "desert", "ice", "mountains"],
		"dir": "Skeleton Warrior/Sprites/with_outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK 1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Slime": {
		"tier": Tier.COMMON,
		"size": Size.TINY,
		"environments": ["grass", "dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Slime/Individual Sprites",
		"sheets": {},
		"frames": {"idle": "slime-idle-", "walk": "slime-move-", "attack": "slime-attack-", "hurt": "slime-hurt-", "death": "slime-die-"},
	},
	"Stone Golem": {
		"tier": Tier.BOSS,
		"size": Size.LARGE,
		"environments": ["dirt", "desert", "ice", "mountains"],
		"dir": "Stone Golem/new version/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Werewolf": {
		"tier": Tier.ELITE,
		"size": Size.LARGE,
		"environments": ["grass", "dirt", "ice", "forest", "mountains"],
		"dir": "Werewolf/Sprites/outline",
		"sheets": {"idle": "IDLE.png", "walk": "RUN.png", "attack": "ATTACK1.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Witch": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["dirt", "ice", "forest", "mountains"],
		"dir": "Witch/Sprite",
		"sheets": {"idle": "IDLE.png", "walk": "MOVE.png", "attack": "ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
	},
	"Wizard": {
		"tier": Tier.ELITE,
		"size": Size.MEDIUM,
		"environments": ["grass", "dirt", "desert", "ice", "forest", "mountains"],
		"dir": "Wizard/Sprites/with_outline",
		# The pack splits its attack in two; the melee swing is the one a tile fight uses.
		"sheets": {"idle": "IDLE.png", "walk": "WALK.png", "attack": "MELEE ATTACK.png", "hurt": "HURT.png", "death": "DEATH.png"},
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


## What to multiply an encounter's base health by for this enemy: its body times its tier. Ranges from
## 0.5 (the slime) to 24.0 (Huge Knight, Demon Boss), so a base of 20 HP spans 10 to 480.
static func hp_modifier(name: String) -> float:
	return SIZE_HP[size_of(name)] * TIER_HP[tier_of(name)]


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


## Picks one enemy for `env`, or "" when that terrain has none of that tier. `rng` decides.
static func pick(env: String, tier: Variant, rng: RandomNumberGenerator) -> String:
	var candidates := in_environment(env, tier)
	if candidates.is_empty():
		return ""
	return candidates[rng.randi_range(0, candidates.size() - 1)]


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
