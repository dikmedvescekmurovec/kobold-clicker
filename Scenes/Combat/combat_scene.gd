class_name CombatScene
extends CanvasLayer
## Draws one Encounter: the player on the left, the tile's enemies walking in one at a time from the
## right, and a click striking whichever is standing there. When it is over, a
## panel says whether the lineup was beaten and lists what it dropped.
##
## Everything below the HUD is built in code, so the .tscn stays a stub the editor can hold open --
## the same convention as main_scene._build_ui and HexMap._ready. The scene owns no rules: it asks
## the Encounter what is happening and shows it.
##
## It is a CanvasLayer rather than a scene of its own, so the main scene can put a fight in front of
## the map without unloading it. The map holds a whole generated world in memory that a scene change
## would throw away.
##
## How far through the fight the player is is said by the KillPips bar over the clock and nowhere
## else: a pip an enemy in its tier colour, draining from the left as the enemies go down. A
## number saying the same thing is the one thing on that panel a player mid-fight has no time to read.

## The fight is over. `won` says whether the tile was taken.
signal finished(won: bool)
## Retry under a lost verdict: leave as `finished(false)` would, and open the same tile's fight again.
signal retry
## A find that is being kept. This, and not `Encounter.loot_dropped`, is what the rest of the game
## hears: the autodiscard rule is applied here and nowhere else, so the counter and the bag can never
## come to different answers about what a fight found.
signal loot_kept(index: int, item: Item)
## A find thrown away on sight by the player's own rule. It is counted and named here for whoever is
## keeping the promise of a first elite drop, and it is never drawn.
signal loot_discarded(index: int, item: Item)
## A find the player threw away by hand, from the verdict panel.
signal drop_discarded(item: Item)
## The loot popup or the verdict has come up in the middle of the window. The main scene puts its bag
## away, which would otherwise stand over either: the pages are drawn on a layer above the fight's.
signal panel_up
## A body's purse. Re-emitted from `Encounter.gold_dropped` rather than left for the main scene to
## hear directly, for the reason `loot_kept` is: the fight is the one thing downstream listens to,
## so the first rule that is ever applied to gold has one place to live.
signal gold_gained(amount: float)
## An orb off a body. Re-emitted from `Encounter.orb_dropped` for the reason `gold_gained` is: the
## fight is the one thing downstream listens to. Nothing here can refuse it -- there is no cap and no
## rule that filters currency -- so unlike a find it has no `kept`/`discarded` pair.
signal orb_gained(orb: String)
## A rune off a body in Gollux's cave (`Encounter.rune_dropped`), for the main scene to put in the
## inventory: the dungeon has no ledger.
signal rune_gained(rune: String)
## A body's experience, re-emitted from `Encounter.xp_dropped` for `gold_gained`'s reason. Emitted the
## moment the body falls, so the ledger is right however the player leaves.
signal xp_gained(amount: int)
## The last gem of one body's experience has reached the character panel. What the panel's bar fills
## on, so it visibly fills as the gems land rather than before they have set off.
signal xp_absorbed(amount: int)

## Where the fighters stand, as a share of the viewport: on the near ground every backdrop paints.
const GROUND := 0.86
const PLAYER_X := 0.24
const ENEMY_X := 0.72
## How tall an ordinary fighter stands, as a share of the viewport height. Sheets vary wildly (a
## slime frame is 32x25, a Demon Boss 162x148), so nobody is drawn at their sheet's scale -- they are
## drawn at the size the roster says their body is.
const ACTOR_HEIGHT := 0.33
## And never taller than this share of its width, so on a window held upright the two stay apart
## rather than filling it up to the shoulders. Across a monitor the height is always the lesser.
const ACTOR_WIDE := 0.3
## What each Size band is worth against that, so a slime is knee-high and a boss looms.
const SIZE_HEIGHT := {
	EnemyRoster.Size.TINY: 0.45,
	EnemyRoster.Size.SMALL: 0.80,
	EnemyRoster.Size.MEDIUM: 1.00,
	EnemyRoster.Size.LARGE: 1.25,
	EnemyRoster.Size.HUGE: 1.55,
}
## The meta a piece lying on the ground keeps its throw's tween under, so a pick-up can cut it short.
const THROWN := &"thrown"
## The light the fighters stand in down the dungeon, a colour they are pulled toward by
## `SCENE_LIGHT` (a multiply, so a little goes a long way).
const CAVE_HAZE := Color("8a7fa0")
## How far the fighters are pulled toward the light they stand in: the cave's gloom or the sky's.
const SCENE_LIGHT := 0.4
## Where an enemy starts its run-in, past the right edge.
const OFFSCREEN_X := 1.15
## A place's backdrop is layers that slide past at their own speeds while an enemy walks in
## (`backdrop_layers`), each drawn on the fighters' 384x216 grid and repeating round its width
## (`AI-sprites-generator/sideview.py`): at the back the sky, which is the player's clock's
## (`SKY_HOURS`); then the land, in bands from the farthest; then the ground. The ground is one per
## environment and variant: the strip the fight stands on across its foot, the strip's top where
## GROUND puts the fighters' feet, and what stands on it or behind it.
const AREA_PATH := "res://Assets/Area/%s_%s_%d.png"
## A place's land, numbered from the farthest band (environment, layout, band). The same under every
## variant of a layout. As many bands as there are files.
const LAND_PATH := "res://Assets/Area/land/%s_%d_%d.png"
const SKY_PATH := "res://Assets/Area/sky/%s.png"
## Which sky the hours bring: each entry the hour (the player's own, 0-23) it comes up at. Before the
## first, it is still the last.
const SKY_HOURS := [[5, "morning"], [10, "noon"], [14, "alpine"], [17, "golden"], [19, "twilight"],
		[21, "night"]]
## What each sky's light does to the land under it, a multiply on every layer but the sky's own, and
## to the fighters `SCENE_LIGHT` of the way. Must agree with `sideview.LIGHT`.
const SKY_LIGHT := {
	"morning": Color.WHITE,
	"noon": Color.WHITE,
	"alpine": Color.WHITE,
	"golden": Color(1.0, 0.86, 0.74),
	"twilight": Color(0.74, 0.68, 0.9),
	"night": Color(0.45, 0.52, 0.72),
}
## How fast the land's farthest and nearest bands slide, as shares of the ground's: the sky stands
## still and the ground goes at `WALK_SPEED`. Must agree with `sideview.speeds`.
const BAND_SLOWEST := 0.2
const BAND_FASTEST := 0.6
## How many ways each place was drawn. A village is four villages: the same environment and the same
## tier, built four ways, so two towns on one map are not the same picture twice. Must agree with
## `sideview.LAYOUTS` in the generator; `_test_backdrops` sweeps every path to hold it.
## Changing it re-rolls which backdrop each tile fights on, which is harmless -- nothing is saved
## about the one it had.
const AREA_LAYOUTS := 4
## What to draw when the world asks for a place that has no art: a fight always has a backdrop.
const AREA_FALLBACK := "res://Assets/Area/grass_plain_1.png"
## The dungeon's backdrop is not one picture but the cave's layers (`tools/cave_dungeon.py`), numbered
## from the front as the pack numbers them: 1 is the rock nearest the eye, which stands **in front of
## the fighters**, and 7 the flat dark behind everything. (The pack's 0 is all of them put together.)
const CAVE_PATH := "res://Assets/Area/cave/%d.png"
const CAVE_NEAREST := 1
const CAVE_FARTHEST := 7
## Where the fighters stand down there: on the cave's floor, which lies lower than a backdrop's grass
## band, with their feet just behind the top of the nearest rock.
const CAVE_GROUND := 0.915
## Held upright (`UITheme.narrow`) the fight stands this far down the window rather than at its foot,
## where a backdrop covering a tall window puts its ground: the whole scene is lifted to put it there
## (`_lift`), each layer's own bottom `UNDERFOOT_ROWS` repeating under it to the window's foot
## (`_underfoot`), and the enemy's nameplate stands `PLATE_UNDER` panel pixels under the feet.
const GROUND_UPRIGHT := 0.6
const UNDERFOOT_ROWS := 16
const PLATE_UNDER := 16.0
## Backdrop pixels a second the ground (or the cave's nearest rock) slides while the hero walks on to
## the next enemy. Each layer behind it goes slower and the farthest not at all, which is the whole
## of the depth.
const WALK_SPEED := 90.0
const ATTACK_SOUND := preload("res://Assets/Player/attack.mp3")
## A blow landing on the enemy, over the swing: the punch for bare hands and a blade, `BLUNT_HIT` for a
## weapon of a `BLUNT` kind (the user's ruling, 2026-10-02).
const HIT_SOUND := preload("res://Sounds/universfield-punch-03-352040.mp3")
const BLUNT_HIT := preload("res://Sounds/Sfx/blunt_hit.ogg")
## A crit, in place of the blow: blunt for bare hands and a `BLUNT` weapon, a slash for every blade --
## with `GENERAL_CRIT` over the slash (the user's pairing, 2026-10-06).
const BLUNT_CRIT := preload("res://Sounds/Sfx/blunt_crit.ogg")
const SLASH_CRIT := preload("res://Sounds/Sfx/slash_crit.ogg")
const GENERAL_CRIT := preload("res://Sounds/Sfx/general_crit.ogg")
## The kinds of weapon (`LootTable.KINDS`) that strike blunt.
const BLUNT := ["mace"]
## A body going down.
const DEATH_SOUND := preload("res://Sounds/universfield-character-fall-impact-352287.mp3")
## An enemy's blow that took time off the clock; a dodged or blocked one is silent.
const STRUCK_SOUND := preload("res://Sounds/Sfx/player_hit.ogg")
## A lost fight's verdict (`_on_finished`). A won one is silent: its fanfare was annoying (the user's
## ruling, 2026-10-02).
const DEFEAT_SOUND := preload("res://Sounds/Sfx/defeat.ogg")
## A find landing (`drop_sound_of`), each a pool of takes: a unique its own, every other piece one
## (the user's ruling, 2026-10-06).
const DROP_SOUNDS := {
	"unique": [preload("res://Sounds/Sfx/unique_drop.ogg")],
	"gear": [preload("res://Sounds/Sfx/item_drop.ogg")],
}
## A coin landing: every one a purse throws, each as it lands (the user's ask), quiet for it.
const COIN_SOUND := preload("res://Sounds/Sfx/coin_drop.ogg")
const ORB_DROP_SOUND := preload("res://Sounds/Sfx/orb_drop.ogg")
## How far a drop -- a find, a coin or an orb -- is pitched up or down, at random, each time it lands.
const DROP_PITCH := 1.04
## A body's experience reaching the bar (`xp_absorbed`).
const XP_SOUNDS := [preload("res://Sounds/Sfx/xp_1.ogg"), preload("res://Sounds/Sfx/xp_2.ogg"),
		preload("res://Sounds/Sfx/xp_3.ogg"), preload("res://Sounds/Sfx/xp_4.ogg"), preload("res://Sounds/Sfx/xp_5.ogg")]
## Where a swing re-triggered mid-swing cuts back in: past the wind-up, at the blow. Two frames at
## CombatActor.FPS is 0.2s, so the picture and the sound come back in at the same instant -- move one
## and move the other.
const SWING_RESTART_FRAME := 2
const SWING_RESTART_SECONDS := 0.2

## The bar behind the clock and its fill. The enemy's health is a HealthBar now -- a generated
## sprite frame with a drawn fill -- so the only thing borrowed back from it here is the red, which
## the crit numbers and the end of the clock's ramp are both keyed to.
const BAR_BACK := Color(Palette.INK, 0.85)
const BAR_HEALTH := HealthBar.FILL
const BAR_TIME := Palette.LEAF_LT
## How thick a dark border the clock is given, in panel pixels. The HUD stands on the arena itself
## rather than on a wood panel, so what is behind it is a backdrop -- a snow field, a desert noon, a
## night sky -- and a bar with no border round it disappears into about half of them.
const BAR_BORDER := 2
## How thick an outline the HUD's own words carry -- the place's name and level, and the clock's
## number -- for the same reason. Pixellari is a pixel font, so this is kept to a whole multiple of
## the pixel.
const LABEL_OUTLINE := 4
## How tall the clock's bar is drawn, in panel pixels. Taller than it was: it stands under a pip bar
## whose crown stands 13 px, and a six-pixel ribbon under that reads as an afterthought.
const CLOCK_HEIGHT := 8
## Where the clock's colour turns. Above CLOCK_GREEN it is simply green -- a fight that has barely
## started must not look like one in trouble -- then it ambers through the middle and reddens over
## the last stretch. Shares of the clock, not seconds, so a fight with a longer clock than its
## neighbour's -- a settlement's minute -- ambers at the same place in it.
const CLOCK_GREEN := 0.6
const CLOCK_AMBER := 0.3
## The loot counter's face, as the bag fills. It is the brown square the map's corner buttons wear,
## so this is a tint multiplied over that art rather than a colour painted on it: FACE_BROWN is what
## ui_kit.py draws (the base step of `ui_btn_brown_normal`) and FACE_DANGER is the pack's own red, the
## key its danger button is played in -- so an empty bag's counter matches the other square
## buttons and a full one reads as a warning. Gold sits between
## them, and it is a ramp rather than a step at some number of items for the reason the clock ramps:
## it is read out of the corner of an eye, and a reddening counter says go and throw something away
## a good deal earlier than one that changes all at once.
const FACE_BROWN := Palette.BUTTON_BROWN
const FACE_DANGER := Color("c42430")

## The number that floats off a hit: how long it lives, how far it climbs, how far either side of the
## enemy it may start, and the two sizes it is drawn at. Pixellari renders cleanly at whole multiples
## of its native 16, so the two sizes are 2x and 3x rather than anything between -- a crit is half
## again as tall as an ordinary hit, which is a difference read at a glance and without the number
## having to be counted against its neighbours.
const DAMAGE_TIME := 0.7
const DAMAGE_RISE := 40.0
const DAMAGE_SPREAD := 28.0
const DAMAGE_FONT := 32
const CRIT_FONT := 48
## A crit is the game's own damage red, the colour the enemy's health bar empties in, rather than
## GOLD -- gold is the unique item step and reads as a reward, and a crit is not one.
const CRIT_COLOR := BAR_HEALTH
## What the clock turns as an enemy's blow lands on it, and how long it takes to fade back. Over-bright
## red rather than a colour, because it is multiplied over the clock's own ramp.
const CLOCK_STRUCK := Color(2.2, 0.6, 0.6)
const CLOCK_STRUCK_TIME := 0.35
## Where what a blow did to the clock rises from, as a share of a fighter's height: over the hero's head.
const STRUCK_HEIGHT := 1.05
## Where up the enemy the number starts, as a share of its height. Low on the body, so the whole
## rise is read against the enemy it came off rather than against the sky over it.
const DAMAGE_HEIGHT := 0.45
## The arc everything a body drops is thrown on -- the coins of its purse, the gear off it and the
## orbs. How long the arc takes, how high it goes and how far to either side it may land, all in
## screen pixels. The spread is wider than the damage numbers' because a coin is small and three of
## them landing on one spot reads as one coin.
const THROW_TIME := 0.5
const THROW_RISE := 70.0
const THROW_SPREAD := 90.0
## How long each coin after the first is held back, so a rich body does not throw its whole purse as
## one lump. A find is thrown alone, so it never waits.
const THROW_STAGGER := 0.06
## And what happens after it lands: it lies there for a while and then goes. Something that vanished
## the instant it landed would not be seen at all. The node frees itself at the end of it, so nothing
## piles up on the ground however long a run goes on.
const THROW_FADE := 0.4
const COIN_REST := 0.5
## A find lies there longer than a coin before it too flies into the counter: it is the thing worth
## looking at, it lands once where a purse lands ten, and it is the only sight of it until the
## player opens the counter.
const FIND_REST := 3.0
## Experience does not lie on the ground: its gems pop out of the body and fly into the character
## panel's bar. How long the pop takes, how high it goes and how far to either side it may land.
const XP_POP_TIME := 0.35
const XP_POP_RISE := 50.0
const XP_POP_SPREAD := 50.0
## How long a gem takes to reach the panel, and the share of that at the end over which it shrinks
## and fades into the bar.
const XP_FLY_TIME := 0.6
const XP_FADE_SHARE := 0.3
## The gem is six pixels; at the panel's own scale it is a speck against a backdrop, so it is drawn
## this many times larger again -- whole numbers only, for the reason `zoom` is.
const XP_GEM_SCALE := 2
const XP_GEM := preload("res://Assets/UI/xp_gem.png")
## The verdict's kill mark: two swords crossed, in the brown a mark bare on the cream wears. It was the
## Last Gasp's own skull, and a skull is also what a curse costs and what marks an elite.
const KILLS_MARK := preload("res://Assets/UI/ui_icon_kills_brown.png")
## What the nameplate says a tier in: the colour of the name -- the pips' and the health bar's own
## green and gold -- and the mark either side of it, cut cream by tools/ui_kit.py.
const TIER_COLOUR := {
	EnemyRoster.Tier.COMMON: Palette.BONE,
	EnemyRoster.Tier.ELITE: Palette.LEAF_LT,
	EnemyRoster.Tier.BOSS: Palette.GOLD,
}
const TIER_MARK := {
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_icon_skull.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_icon_crown.png"),
}
## A boss's name is written at twice Pixellari's native size, the one other size it stays crisp at,
## and pops in from BOSS_POP times that over BOSS_POP_TIME, white before it is gold.
const NAME_FONT := 16
const BOSS_FONT := 32
const BOSS_POP := 1.5
const BOSS_POP_TIME := 0.35
## The marks on the HUD's square buttons, drawn by tools/ui_kit.py to match the map's bag and skills.
const SACK_ICON := preload("res://Assets/UI/ui_icon_sack.png")
const FLAG_ICON := preload("res://Assets/UI/ui_icon_flag.png")
## How far to either side a find may land. Narrower than the coins' spread, because one sprite has
## nothing to be told apart from and a find belongs by the body that dropped it.
const FIND_SPREAD := 40.0
## The beam standing over a find (`LootBeam`): a pillar of light in the rarity's colour, so what came
## off the body is read without a word on it, and taller the rarer it is. A child of the sprite, so the
## arc carries it; it shoots up once the find has landed, its foot at the bottom of the icon.
## How big a find is drawn by rarity, so the rarer it is the more it shows; a good orb is drawn at the
## rarity its beam borrows, and a plain one (`-1`) as uncommon. The rarer is also drawn over the
## commoner where they land on each other (`z_index` climbs with the rarity).
const FIND_SIZE := {
	-1: 1.0,
	ItemRarity.Rarity.COMMON: 0.85,
	ItemRarity.Rarity.UNCOMMON: 1.0,
	ItemRarity.Rarity.RARE: 1.2,
	ItemRarity.Rarity.ELITE: 1.4,
	ItemRarity.Rarity.UNIQUE: 1.75,
}
## What a landed blow does to the body it lands on: a white flash (modulate over 1 brightens), a
## squash on its feet, and how long both take to come back.
const HIT_FLASH := Color(2.5, 2.5, 2.5)
const HIT_SQUASH := Vector2(1.12, 0.88)
const HIT_TIME := 0.12
## How high the player hops on a swing, in screen pixels, and how long the hop takes: a click that
## re-triggers a swing mid-animation would otherwise show nothing at all when it is spammed.
const SWING_HOP := 6.0
const SWING_HOP_TIME := 0.16
## How far the arena rattles, in screen pixels: a crit, an ordinary death, and an elite's or a boss's.
## The backdrop is drawn BACKDROP_BLEED larger than the window so a shake never shows its edge.
const SHAKE_CRIT := 4.0
const SHAKE_ELITE := 8.0
const SHAKE_BOSS := 14.0
const BACKDROP_BLEED := 1.05
## How long the game freezes on a kill, by tier. Short: a freeze is felt rather than seen, and a
## ten-kill fight freezes ten times.
const STOP_KILL := 0.04
const STOP_ELITE := 0.08
const STOP_BOSS := 0.15
## The burst a body goes out in.
const DEATH_PIXELS := 28
## A find at ELITE or better slows the fight to STOP_RARE_SPEED for STOP_RARE real seconds, so the
## beam coming up is watched rather than glimpsed.
const STOP_RARE := 0.6
## A unique slows it much further and for longer, then eases back over STOP_UNIQUE_EASE: the drop the
## whole game is about, watched land and shoot its beam up in slow motion.
const STOP_UNIQUE := 1.6
const STOP_UNIQUE_SPEED := 0.1
const STOP_UNIQUE_EASE := 0.8
const STOP_RARE_SPEED := 0.25
## A damage number arrives this much larger than it settles, over DAMAGE_POP, and drifts sideways by
## up to DAMAGE_DRIFT as it climbs.
const DAMAGE_POP_SCALE := 1.6
const DAMAGE_POP := 0.12
const DAMAGE_DRIFT := 24.0
## Coins lie for COIN_REST, then fly into the loot counter over COIN_FLY.
const COIN_FLY := 0.45
## How bright the counter flashes as a coin reaches it.
const BUMP_FLASH := Color(1.6, 1.6, 1.6)
## How far the HUD's panels stand off the window edge, in screen pixels.
const HUD_MARGIN := 8.0

var fight: Encounter
## The cell being fought for, so the main scene knows what was won.
var cell: Vector2i
## What the world put on that cell -- "plain", "road", "village", "town" or "fortress". The
## environment comes from the encounter; together they name the backdrop.
var area_variant := "plain"
## Which of that place's layouts this fight is on. `begin` takes 0 to mean "whichever this cell
## fights on", which is what the game always wants; the screenshot script passes one explicitly.
var area_layout := 1
## Which sky is over it (`SKY_LIGHT`'s names). `begin` takes "" to mean the player's clock's, which
## is what the game always wants; the screenshot scripts pass one explicitly.
var area_sky := "morning"
## What this place is called, as the map named it when the player first saw it. Set before `begin`,
## the way `bag_room` and `autodiscard` are, because the HUD is built inside it. Empty is allowed
## and means a fight with no map behind it -- the tests and the screenshot scripts -- which then
## says the level alone.
var place := ""
## Where on the screen experience gems fly to -- the character panel's bar, which stands on a layer
## above this one. Negative means nowhere, and the gems fade where they popped.
var xp_target := Vector2(-1, -1)
## How far down the window the top-centre column stands, in screen pixels: `HUD_MARGIN`, but under the
## character panel on a window too narrow for the two side by side. The main scene's, like `xp_target`.
var hud_top := HUD_MARGIN

var _ui_scale := 2.0
## One of the backdrop's pixels, in scene pixels: what the fighters' scale is snapped to.
var _pixel := 0.0
## The backdrop and both fighters, which is what a shake rattles -- the HUD stays still over it.
var _arena: Node2D
## The backdrop's layers from the back -- a place's or the cave's -- and the share of `WALK_SPEED` each
## slides at.
var _layers: Array[Sprite2D] = []
var _rates: Array[float] = []
## What the bodies have thrown and is lying on the ground, or still in the air on its way there. It
## goes by with the ground as the hero walks on (`_scroll`), and a piece the hero reaches is picked
## up there and then (`_pick_up`), whatever was left of its rest. Each piece carries its throw's
## tween as `THROWN`.
var _ground_drops: Node2D
## The gold half of the HUD's heading, which the dungeon rewrites floor by floor.
var _level_label: Label
var _player: CombatActor
var _enemy: CombatActor
## The enemy's own scale, which a squash springs back to, and the tween doing it.
var _enemy_scale := Vector2.ONE
var _enemy_hit: Tween
var _sound: AudioStreamPlayer
var _hit_sound: AudioStreamPlayer
var _crit_sound: AudioStreamPlayer
## `GENERAL_CRIT` for a blade, null otherwise.
var _crit_layer: AudioStreamPlayer
var _death_sound: AudioStreamPlayer
var _struck_sound: AudioStreamPlayer
## `DROP_SOUNDS`' keys -> each one's player.
var _drop_sounds := {}
var _coin_sound: AudioStreamPlayer
var _orb_sound: AudioStreamPlayer
var _xp_sound: AudioStreamPlayer

var _hud: Control
var _clock: VBoxContainer
var _clock_fill: ColorRect
var _clock_label: Label
var _tally: VBoxContainer
var _pips: KillPips
var _enemy_panel: VBoxContainer
var _enemy_label: Label
var _enemy_marks: Array[TextureRect] = []
var _enemy_title: Label
## How much larger than it belongs the nameplate is drawn this frame: 1 but for a boss's entrance.
var _plate_pop := 1.0
var _plate_tween: Tween
## The player's hop on a swing, so a swing landing mid-hop starts it over rather than stacking.
var _hop: Tween
var _enemy_bar: HealthBar
## The same health as the bar, in numbers, under it.
var _enemy_hp_label: Label
var _result: VBoxContainer
## The air between the clock's column and a verdict that would otherwise reach up over it.
const RESULT_GAP := 4
var _result_summary: VBoxContainer
## The coin beside the verdict's gold, which spins while the figure counts up.
var _gold_coin: TextureRect
var _result_label: Label
var _result_detail: Label
## Where the fight's drops are listed, under the verdict.
var _result_drops: DropsView
## The bag in the corner: what the run has turned up so far, and the popup it opens.
var _loot_button: Button
var _loot_panel: VBoxContainer
var _loot_drops: DropsView
## The popup's sums, kept current while it is open.
var _loot_gold: Label
var _loot_xp: Label
var _loot_kills: Label
## How many finds this fight has thrown into the arena -- gear and orbs both. Nothing is drawn from
## it: the sprites free themselves, and what anybody wants to know is whether something was announced
## at all, which is what `test_inventory` asks of an autodiscarded find.
var _finds_shown := 0
## Leaves a farm run. Only built for one -- a tile fight is left by beating it or running out.
var _terminate: Button
var _gave_up := false
## What this fight has turned up, in the order it fell. Autodiscarded finds are not in here.
var _drops: Array[Item] = []
## How many finds the bag can still take before the player is overencumbered, or -1
## when nobody has said -- a fight with no bag behind it, which is what the screenshot scripts run.
## The scene owns no rules here: it is handed a number and it draws it.
var bag_room := -1
## How many the bag holds in all (`Inventory.capacity`), which the counter's face is a share of.
var bag_size := Inventory.CAPACITY
## Asked of each find: whether the player has told the game to leave it behind -- its level's rule or
## the loot filter (`Inventory.leaves_behind`). An unset Callable keeps everything, so a fight nobody
## has told anything behaves as it always did.
var autodiscard := Callable()
## Asked as Escape is pressed: whether a page of the main scene's (the bag) stands over the fight. The
## key is then the page's -- an orb put down, a selection cleared, the page closed -- never Terminate.
var page_up := Callable()
## Whether a won tile fight takes its loot and leaves by itself, `AUTO_COLLECT_SECONDS` after its verdict
## is up, as Collect would: the main scene's, while the Nightwalkers are worn or distant charting is open
## (the fourth wall's, the user's 2026-10-09), so a way into the dark or across seen land is
## fought through with nobody at the keys. A Timer child, so a pause (a tip) holds it and a scene freed
## first takes it along.
var auto_collect := false
const AUTO_COLLECT_SECONDS := 1.5
## The kind of weapon the hero swings (`LootTable.KINDS`), "" bare-handed: the main scene's, set before
## `begin`, which picks the blow and the crit a hit lands with.
var weapon_kind := ""
## How many finds that rule has thrown away. Said once, at the end, and never drawn as a square:
## the whole point of the rule is not having to look at them.
var _auto_discarded := 0
## The counter's four faces, one per button state, each a copy of the theme's own box that this
## scene is free to tint. And the fill they are tinted for, so they are only touched when it moves.
var _loot_faces: Array[StyleBox] = []
var _loot_filled := -1.0
## The line under the verdict's drops saying how many the rule threw away.
var _auto_label: Label
## And the one over it saying what the fight earned. Gold is said once, at the end: it is not a find
## to be chosen between, so there is nothing to open and nothing to decide while the fight is on.
## The coin beside it goes with it, so the row is what is shown and hidden.
var _gold_label: Label
var _kills_label: Label
var _collect: Button
var _lost_row: HBoxContainer
var _gold_row: HBoxContainer
## What the fight earned in experience, the gem and the number, shown beside the purse.
var _xp_label: Label
var _xp_row: HBoxContainer


## Starts the fight for `cell`. `ui_scale` matches the map's, so the panels are the same size, and
## `variant` is what the world put on the tile, which picks the backdrop with the encounter's terrain.
## `layout` 0 is the cell's own and `sky` "" the clock's.
func begin(encounter: Encounter, for_cell: Vector2i, ui_scale: float, variant := "plain",
		layout := 0, sky := "") -> void:
	fight = encounter
	# No Control lies over the arena, so the cursor there is the default one: a press is a swing.
	Input.set_default_cursor_shape(Cursors.SWORD)
	cell = for_cell
	area_variant = variant
	area_layout = layout if layout > 0 else layout_for(for_cell)
	area_sky = sky if SKY_LIGHT.has(sky) else sky_at(Time.get_datetime_dict_from_system().hour)
	_ui_scale = ui_scale
	fight.enemy_coming.connect(_on_enemy_coming)
	fight.enemy_spawned.connect(_on_enemy_spawned)
	fight.enemy_hit.connect(_on_enemy_hit)
	fight.hit_landed.connect(_on_hit_landed)
	fight.player_hit.connect(_on_player_hit)
	fight.enemy_died.connect(_on_enemy_died)
	fight.loot_dropped.connect(_on_loot_dropped)
	fight.gold_dropped.connect(_on_gold_dropped)
	fight.orb_dropped.connect(_on_orb_dropped)
	fight.rune_dropped.connect(_on_rune_dropped)
	fight.xp_dropped.connect(_on_xp_dropped)
	fight.won.connect(_on_finished.bind(true))
	fight.lost.connect(_on_finished.bind(false))
	_build()
	fight.start()
	_refresh()


func _process(delta: float) -> void:
	if fight == null or fight.finished:
		return
	fight.advance(delta)
	_scroll(delta)
	_slide_enemy()
	_refresh()


## A click anywhere in the arena is a swing. The fail state is the clock, so asking the player to
## hit a moving sprite as well would be a second difficulty on top of the one the fight is about.
##
## Escape is the fight's own X: the loot popup if it is up, else Terminate on a run, else Back under a
## verdict. A tile fight is given up only by its button, so a stray Escape cannot throw one away. With
## the bag up over the fight (`page_up`) the key is the bag's.
func _unhandled_input(event: InputEvent) -> void:
	if (fight != null and event.is_action_pressed("ui_cancel")
			and not (page_up.is_valid() and page_up.call())):
		get_viewport().set_input_as_handled()
		if _loot_panel.visible:
			close_loot()
		elif fight.finished:
			_leave(_on_back_pressed)
		elif fight.endless:
			_on_terminate_pressed()
		return
	if fight == null or fight.finished:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		get_viewport().set_input_as_handled()
		# Swings whether or not the hand's allowance lets the blow through, so a click past the cap
		# still feels heard.
		_swing()
		fight.click()
		_refresh()


## A place's backdrop as its layers from the back, each `[texture, rate]` -- the share of
## `WALK_SPEED` it slides at: the sky, still; the land's bands from `BAND_SLOWEST` to
## `BAND_FASTEST`; the ground, at the whole of it. Terrain the art does not cover falls back to the
## fallback's place rather than failing: a fight with no picture behind it would be unplayable, and
## a missing file is a build problem, not a reason to lose the tile. So does a sky with no name.
static func backdrop_layers(env: String, variant: String, layout: int, sky: String) -> Array:
	layout = clampi(layout, 1, AREA_LAYOUTS)
	var ground := AREA_PATH % [env, variant, layout]
	if not ResourceLoader.exists(ground):
		push_warning("No backdrop for %s/%s/%d" % [env, variant, layout])
		ground = AREA_FALLBACK
		var named := ground.get_file().get_basename().split("_")
		env = named[0]
		layout = int(named[2])
	var bands: Array[Texture2D] = []
	while ResourceLoader.exists(LAND_PATH % [env, layout, bands.size() + 1]):
		bands.append(load(LAND_PATH % [env, layout, bands.size() + 1]))
	var out := [[load(SKY_PATH % (sky if SKY_LIGHT.has(sky) else SKY_HOURS[0][1])), 0.0]]
	for i in bands.size():
		out.append([bands[i], lerpf(BAND_SLOWEST, BAND_FASTEST, i / maxf(1.0, bands.size() - 1.0))])
	out.append([load(ground), 1.0])
	return out


## The sky over a fight that opens at `hour` (0-23, the player's own clock): the last of
## `SKY_HOURS` to have come up, and before the first of them the last, still up from the night before.
static func sky_at(hour: int) -> String:
	var sky: String = SKY_HOURS[-1][1]
	for entry in SKY_HOURS:
		if hour >= int(entry[0]):
			sky = entry[1]
	return sky


## One layer of a backdrop: a region of a texture that repeats, so sliding the region along (`_scroll`)
## is land with no end to it. Placed by `fit_layer`.
static func layer_sprite(art: Texture2D) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = art
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	sprite.region_rect = Rect2(Vector2.ZERO, art.get_size())
	return sprite


## Scales and centres a layer to cover `view` whatever its shape, `bleed` over so a shake never shows
## an edge; the ground band stays across the bottom. Returns one of its pixels in screen pixels.
static func fit_layer(sprite: Sprite2D, view: Vector2, bleed: float) -> float:
	var art := Vector2(sprite.texture.get_size())
	var cover := maxf(view.x / art.x, view.y / art.y) * bleed
	sprite.scale = Vector2(cover, cover)
	sprite.position = (view - art * cover) / 2.0
	return cover


## Which of a place's layouts a cell fights on. Seeded from the cell, like the tile's enemies, so a
## tile always fights on the same backdrop however many times it is attempted -- and under its own
## tag, so which picture is behind the fight has nothing to do with who walks into it.
static func layout_for(for_cell: Vector2i) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["backdrop", for_cell])
	return rng.randi_range(1, AREA_LAYOUTS)


func _size() -> Vector2:
	return Vector2(get_viewport().get_visible_rect().size)


# ---- building

func _build() -> void:
	var view := _size()
	var arena := Node2D.new()
	arena.name = "Arena"
	add_child(arena)
	_arena = arena

	if fight != null and fight.dungeon:
		_build_cave(arena, view)
	else:
		var backdrop := backdrop_layers(fight.env if fight != null else "", area_variant, area_layout,
				area_sky)
		for i in backdrop.size():
			# The sky's light falls on everything but the sky.
			_add_layer(arena, view, backdrop[i][0], backdrop[i][1]).modulate = 					SKY_LIGHT[area_sky] if i > 0 else Color.WHITE

	var light := Color.WHITE.lerp(_light(), SCENE_LIGHT)
	_player = CombatActor.new()
	_player.name = "Player"
	arena.add_child(_player)
	_player.setup_player(_actor_height(view), _snap(view))
	_player.self_modulate = light
	_player.position = Vector2(view.x * PLAYER_X, view.y * _ground())
	_player.animation_finished.connect(func() -> void: _player.play("idle"))

	_enemy = CombatActor.new()
	_enemy.name = "Enemy"
	_enemy.self_modulate = light
	arena.add_child(_enemy)
	# The cave's nearest rock goes on after them both, so it is what they stand behind.
	if fight != null and fight.dungeon:
		_add_cave_layer(arena, view, CAVE_NEAREST)

	_ground_drops = Node2D.new()
	_ground_drops.name = "Drops"
	add_child(_ground_drops)

	_sound = AudioStreamPlayer.new()
	_sound.bus = Settings.SFX_BUS
	_sound.stream = ATTACK_SOUND
	add_child(_sound)
	_hit_sound = _sfx_player(BLUNT_HIT if weapon_kind in BLUNT else HIT_SOUND)
	var blade := weapon_kind != "" and weapon_kind not in BLUNT
	_crit_sound = _sfx_player(SLASH_CRIT if blade else BLUNT_CRIT)
	if blade:
		_crit_layer = _sfx_player(GENERAL_CRIT)
	_death_sound = _sfx_player(DEATH_SOUND)
	_struck_sound = _sfx_player(STRUCK_SOUND)
	for key: String in DROP_SOUNDS:
		_drop_sounds[key] = _sfx_player(Juice.takes(DROP_SOUNDS[key], DROP_PITCH))
	_coin_sound = _sfx_player(Juice.takes([COIN_SOUND], DROP_PITCH))
	_orb_sound = _sfx_player(Juice.takes([ORB_DROP_SOUND], DROP_PITCH))
	_xp_sound = _sfx_player(Juice.takes(XP_SOUNDS))
	xp_absorbed.connect(_xp_sound.play.unbind(1))

	_build_hud()


func _sfx_player(stream: AudioStream) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = Settings.SFX_BUS
	player.stream = stream
	player.max_polyphony = 4
	add_child(player)
	return player


## The light the fighters stand in: the cave's gloom, or the sky's.
func _light() -> Color:
	if fight != null and fight.dungeon:
		return CAVE_HAZE
	return SKY_LIGHT.get(area_sky, Color.WHITE)


## How tall an ordinary fighter stands in `view`, in screen pixels (`ACTOR_HEIGHT`, `ACTOR_WIDE`).
func _actor_height(view: Vector2) -> float:
	return minf(view.y * ACTOR_HEIGHT, view.x * ACTOR_WIDE)


## What a fighter's scale is snapped to: the backdrop's pixel, or half of it on a window held upright,
## whose backdrop is blown up to cover its height and would otherwise draw no fighter smaller than a
## giant. Half, so the two still share a grid.
func _snap(view: Vector2) -> float:
	return _pixel / 2.0 if UITheme.narrow(view, _ui_scale) else _pixel


## Where the fighters' feet are, as a share of the view's height: on the backdrop's ground line, or held
## upright `GROUND_UPRIGHT`, the scene lifted to meet them.
func _ground() -> float:
	return GROUND_UPRIGHT if UITheme.narrow(_size(), _ui_scale) else _art_ground()


## Where a backdrop covering the view draws its ground line, as a share of the view's height.
func _art_ground() -> float:
	return CAVE_GROUND if fight != null and fight.dungeon else GROUND


## How far above where `fit_layer` puts it every layer is drawn, in screen pixels: none across a monitor.
func _lift(view: Vector2) -> float:
	return (_art_ground() - _ground()) * view.y


## The cave behind the fighters, back to front; `_build` adds the nearest rock once they are in.
func _build_cave(arena: Node2D, view: Vector2) -> void:
	for n in range(CAVE_FARTHEST, CAVE_NEAREST, -1):
		_add_cave_layer(arena, view, n)


## One layer of the cave, numbered from the nearest, sliding the faster the nearer it is.
func _add_cave_layer(arena: Node2D, view: Vector2, n: int) -> void:
	_add_layer(arena, view, load(CAVE_PATH % n),
			float(CAVE_FARTHEST - n) / (CAVE_FARTHEST - CAVE_NEAREST))


## Lays a backdrop layer on the arena over what is there, sliding at `rate` of `WALK_SPEED`. Every
## layer is drawn on the same grid, so any of them gives the pixel the fighters snap to.
func _add_layer(arena: Node2D, view: Vector2, art: Texture2D, rate: float) -> Sprite2D:
	var sprite := layer_sprite(art)
	_pixel = fit_layer(sprite, view, BACKDROP_BLEED)
	sprite.position.y -= _lift(view)
	arena.add_child(sprite)
	_layers.append(sprite)
	_rates.append(rate)
	_underfoot(sprite, view, rate)
	return sprite


## A lifted layer stops short of the window's foot: its own bottom rows (`UNDERFOOT_ROWS`) repeat on down
## from its foot to the window's, a child drawn straight after it and sliding with it.
func _underfoot(layer: Sprite2D, view: Vector2, rate: float) -> void:
	var foot := layer.position.y + layer.texture.get_height() * layer.scale.y
	if foot >= view.y:
		return
	var art := layer.texture.get_image()
	var rows := art.get_region(Rect2i(0, art.get_height() - UNDERFOOT_ROWS, art.get_width(), UNDERFOOT_ROWS))
	var under := layer_sprite(ImageTexture.create_from_image(rows))
	under.position = Vector2(0.0, art.get_height())
	under.region_rect.size.y = ceilf((view.y - foot) / layer.scale.y)
	layer.add_child(under)
	_layers.append(under)
	_rates.append(rate)


## The hero walking on: while the next body is coming in the backdrop slides past, the nearest layer
## fastest and the farthest not at all, and what lies on the ground goes with the ground. Only for
## show, so it asks the animation level, and the fight knows nothing of it. Each layer is wrapped
## round its width, which is where it repeats anyway.
func _scroll(delta: float) -> void:
	if fight.phase != Encounter.Phase.WALKING_IN or Settings.animations == Settings.Anim.NONE 			or not _walks_on():
		return
	for i in _layers.size():
		var region := _layers[i].region_rect
		region.position.x = fposmod(region.position.x + WALK_SPEED * delta * _rates[i], region.size.x)
		_layers[i].region_rect = region
	# Brought back home whenever the ground is bare, so a run of hours never piles up an offset.
	if _ground_drops.get_child_count() == 0:
		_ground_drops.position.x = 0.0
	_ground_drops.position.x -= WALK_SPEED * delta * _pixel
	var reach := _player.position.x + _player.drawn_size().x / 2.0
	for thing: Node2D in _ground_drops.get_children():
		if thing.has_meta(THROWN) and thing.global_position.x <= reach:
			_pick_up(thing)


## Whether the hero walks on to meet each enemy: everywhere but a settlement, which he holds,
## standing his ground while its defenders come at him over a backdrop that stays still.
func _walks_on() -> bool:
	return Encounter.PROFILES.get(area_variant) != Encounter.SETTLEMENT


## A piece the hero has walked into: whatever was left of its throw and its rest is cut short, and it
## goes into the counter at once. Only the picture: what it is worth was banked as it dropped.
func _pick_up(thing: Node2D) -> void:
	var arc: Tween = thing.get_meta(THROWN)
	if arc.is_valid():
		arc.kill()
	_fly_to_counter(thing)


func _build_hud() -> void:
	var hud := Control.new()
	hud.name = "HUD"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.theme = UITheme.theme()
	# Over everything the fight throws -- finds (`z_index` climbing with the rarity) and their beams,
	# coins, gems, numbers, bursts -- so nothing is ever drawn across the HUD or its popups.
	hud.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	add_child(hud)
	_hud = hud

	# Top middle: where the fight is and how it is going -- the place's name and level over the bar
	# of pips draining as the enemies go down, and the clock under it. The
	# bar goes first because it is the fight -- the clock is what the fight is measured against, and
	# a measure belongs under the thing it measures. No panel behind them -- the two are what the
	# player watches and a panel only puts furniture round them -- so each carries its own dark
	# border instead, which is what has to read on a backdrop rather than on wood. Centred because
	# with the panel gone there is no corner to hang off, and the fighters are the left and right of
	# the screen. A farm run keeps only the bar: it has no clock to spend, and its bar cycles
	# between elites rather than draining once.
	_tally = VBoxContainer.new()
	_tally.add_theme_constant_override("separation", 6)
	_tally.scale = Vector2(_ui_scale, _ui_scale)
	_tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_tally)
	# Over the lot, what the player is fighting for: the tile's name and its level. Two labels rather
	# than one line of text so the two read as two things -- a name in bone and a number in gold --
	# without a punctuation glyph between them that Pixellari may not draw. It never changes while
	# the fight is on, so it is filled here and never refreshed.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	header.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tally.add_child(header)
	if not place.is_empty():
		header.add_child(_hud_label(place, Palette.BONE))
	_level_label = _hud_label("Level %d" % MapBuilder.level_of(cell), Palette.GOLD)
	header.add_child(_level_label)
	# As many pips as this fight has enemies -- fifteen on a settlement tile, ten on open land -- or,
	# for a run, the cycle it repeats between elites.
	var slots: int = fight.elite_every if fight.endless else fight.enemies
	_pips = KillPips.new(slots)
	_pips.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tally.add_child(_pips)
	_clock = VBoxContainer.new()
	_clock.add_theme_constant_override("separation", 2)
	_clock.visible = not fight.endless
	_clock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tally.add_child(_clock)
	# The border is drawn outside the track, so the track is cut to leave the whole thing exactly as
	# wide as the pip bar above it: the two are one column and a pixel out would show.
	var clock_bar := _bar(KillPips.width_for(slots) - 2 * BAR_BORDER, CLOCK_HEIGHT, BAR_TIME)
	_clock_fill = clock_bar.get_child(0)
	_clock.add_child(_outlined(clock_bar, BAR_BORDER))
	# The number under its own bar, so the two bars stay next to each other and the clock still
	# reads as one thing rather than a number wedged between them.
	_clock_label = _hud_label("", BAR_TIME)
	_clock_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_clock.add_child(_clock_label)

	# Bottom right: what the run has turned up. It is a Control standing in the arena, so it eats the
	# click that lands on it rather than letting it through as a swing -- which is what is wanted
	# here, and exactly why the main scene hides its own corner button while a fight is on.
	_loot_button = _square_button(SACK_ICON)
	_loot_button.scale = Vector2(_ui_scale, _ui_scale)
	_loot_button.tooltip_text = "What this run has turned up"
	_loot_button.pressed.connect(_on_loot_pressed)
	# Its face is the whole of what the HUD says about how full the bag is. A copy of the theme's own
	# box per state, tinted rather than repainted, so the bevel stays the pack's and only its colour
	# moves -- and the tint lands on the box alone, so the newest find's icon and the count beside it
	# keep their own colours.
	for state: String in UITheme.STATES:
		var face: StyleBox = UITheme.theme().get_stylebox(state, "BrownIconButton").duplicate()
		_loot_faces.append(face)
		_loot_button.add_theme_stylebox_override(state, face)
	hud.add_child(_loot_button)
	# The dungeon turns nothing up, so it has no counter to show and no finds under its verdict.
	_loot_button.visible = not fight.dungeon
	_refresh_loot_button()
	_tint_loot_button()

	# Leaving a farm run. Up in the top-right corner: the player is clicking hard and fast at the
	# enemy in the middle of the screen, and the button that ends the run has to be somewhere a stray
	# one cannot reach -- which is now a corner rather than the bottom middle, that being where the
	# enemy's health went.
	# A tile fight has one too: giving up is a loss, with what already dropped kept as any loss keeps it.
	_terminate = _square_button(FLAG_ICON)
	_terminate.scale = Vector2(_ui_scale, _ui_scale)
	_terminate.tooltip_text = ("End the run and keep everything it turned up" if fight.endless
			else "End the descent here" if fight.dungeon
			else "Give up the fight and keep what it already turned up")
	_terminate.pressed.connect(_on_terminate_pressed)
	hud.add_child(_terminate)

	# Centred on the bottom edge: the enemy's name and health, standing on the arena with no panel
	# behind them -- the same as the place's name and the clock on the top edge, and for the same
	# reason. These are what the player watches; a panel only puts furniture round them. So the name
	# is written the way that one is, in bone with the dark outline that is what carries a word over a
	# snowfield or a noon desert, and the bar brings its own border already.
	_enemy_panel = VBoxContainer.new()
	_enemy_panel.scale = Vector2(_ui_scale, _ui_scale)
	_enemy_panel.add_theme_constant_override("separation", 2)
	hud.add_child(_enemy_panel)
	# The name between two marks, the banner an elite or a boss walks in under; a common has none.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enemy_panel.add_child(name_row)
	_enemy_label = _hud_label("", Palette.BONE)
	for side in 2:
		var mark := TextureRect.new()
		mark.stretch_mode = TextureRect.STRETCH_SCALE
		mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_enemy_marks.append(mark)
		name_row.add_child(mark)
		if side == 0:
			name_row.add_child(_enemy_label)
	# A boss's second line, in the body font with the same outline.
	_enemy_title = _hud_label("", Palette.BONE)
	_enemy_title.theme_type_variation = "SmallLabel"
	_enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_panel.add_child(_enemy_title)
	# The frame this wears is the enemy's tier, so it changes as the lineup walks in. It is wider for
	# an elite and wider still for a boss, which the column simply grows to hold -- _place_corners
	# centres it and has no opinion about how wide it is.
	_enemy_bar = HealthBar.new()
	_enemy_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_enemy_panel.add_child(_enemy_bar)
	# What the bar says, in figures: the share alone cannot tell a sliver that is one hit from one
	# that is fifty. Body text under the bar, the way the boss's title sits over it.
	_enemy_hp_label = _hud_label("", Palette.BONE)
	_enemy_hp_label.theme_type_variation = "SmallLabel"
	_enemy_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_panel.add_child(_enemy_hp_label)

	# The verdict, hidden until there is one: the pages' own panel, its word on the green bar and no X
	# (the way out is the button at its foot, which `_on_finished` picks).
	_result = UITheme.titled_panel("", "", Callable())
	_result.scale = Vector2(_ui_scale, _ui_scale)
	_result.hide()
	_result.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_result)
	var verdict := UITheme.body_of(_result)
	verdict.add_theme_constant_override("separation", 8)

	# What happened, and what it left. Swapped out for one item's details when a square is clicked,
	# rather than growing the panel: a piece with six modifiers is taller than the verdict itself.
	_result_summary = VBoxContainer.new()
	_result_summary.add_theme_constant_override("separation", 8)
	verdict.add_child(_result_summary)
	_result_label = UITheme.title_of(_result)
	_result_detail = _label("")
	_result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_summary.add_child(_result_detail)
	# What the fight earned, over the finds: gold, experience and bodies in one row, each a bare
	# number behind its mark. In the panel's own colour -- Palette.GOLD is the unique item step, and
	# spending it here would put one colour on a currency and on an item's name in the same panel.
	# Centred by the row shrinking to its contents: HORIZONTAL_ALIGNMENT_CENTER centres text inside a
	# label and says nothing about where the label itself sits in the column.
	var sums := _sums_row(_result_summary)
	_gold_label = _sum(sums, Coins.icon(), Vector2(Coins.SIZE, Coins.SIZE))
	_gold_row = _gold_label.get_parent()
	_gold_row.hide()
	_gold_coin = _gold_row.get_child(0)
	# The experience beside the purse, in the same row: both are sums, and both are never nothing.
	_xp_label = _sum(sums, XP_GEM, Vector2(XP_GEM.get_width(), XP_GEM.get_height()) * XP_GEM_SCALE)
	_xp_row = _xp_label.get_parent()
	_xp_row.hide()
	# The bodies, as a count behind a skull. The pack's 32 px skull at half size, the orb tray's 2:1.
	_kills_label = _sum(sums, KILLS_MARK, Vector2(Coins.SIZE, Coins.SIZE))
	# What the fight left behind, under the sums: the finds on the bag's light panel and the orbs in a
	# row under them. Kept even when it was lost, so this is where that promise is visibly kept.
	_result_drops = DropsView.new()
	_result_drops.discardable = true
	_result_drops.discarded.connect(_on_drop_discarded)
	_result_drops.resized_contents.connect(_centre_result)
	_result_summary.add_child(_result_drops)
	# What the player's own rule threw away, as a number and nothing else. It is said here because a
	# run that quietly found half as much as it did would be a run the player cannot read.
	_auto_label = _label("")
	_auto_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Quieter than the verdict without being another colour: the panel is wood, and the dark half of
	# the palette that reads on the bone one disappears into it -- it is a footnote, not a finding.
	_auto_label.modulate = Color(1.0, 1.0, 1.0, 0.6)
	_auto_label.hide()
	_result_summary.add_child(_auto_label)
	# The way out, which `_on_finished` picks by how it went. A won tile and an ended run leave by the
	# word Collect, which says what the press is for where an arrow only says leave; a lost one has
	# nothing to collect, so it gets the arrow and, beside it, another go at the same tile.
	# Light buttons: the panel is cream now, and wood buttons are for wood.
	_collect = UITheme.button("Collect", "LightButton", "Take it all back to the map")
	_collect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_collect.pressed.connect(_leave.bind(_on_back_pressed))
	_result_summary.add_child(_collect)
	_lost_row = HBoxContainer.new()
	_lost_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_result_summary.add_child(_lost_row)
	var back := UITheme.back_button("Back to the map")
	back.pressed.connect(_leave.bind(_on_back_pressed))
	_lost_row.add_child(back)
	var again := UITheme.button("Retry", "LightButton", "Fight for this tile again")
	again.pressed.connect(_leave.bind(retry.emit))
	_lost_row.add_child(again)

	# The same list again, on its own panel, for the counter in the corner to open mid-fight: a
	# summary and nothing more, since every find is in the bag already and the bag is where it is
	# handled (the user's ruling, 2026-10-02). Built as the verdict is -- the word on the green bar, the sums, the finds and orbs, the way out
	# at the foot -- so the haul mid-fight and the haul at the end read as the same panel.
	_loot_panel = UITheme.titled_panel("Loot", "", Callable())
	_loot_panel.scale = Vector2(_ui_scale, _ui_scale)
	_loot_panel.hide()
	_loot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(_loot_panel)
	var found := UITheme.body_of(_loot_panel)
	found.add_theme_constant_override("separation", 8)
	# The sums so far, every one shown even at nothing: a fight that has found no gear yet still has
	# a purse, experience and bodies to show for itself, and that row is the whole panel then.
	var so_far := _sums_row(found)
	_loot_gold = _sum(so_far, Coins.icon(), Vector2(Coins.SIZE, Coins.SIZE))
	_loot_xp = _sum(so_far, XP_GEM, Vector2(XP_GEM.get_width(), XP_GEM.get_height()) * XP_GEM_SCALE)
	_loot_kills = _sum(so_far, KILLS_MARK, Vector2(Coins.SIZE, Coins.SIZE))
	_loot_drops = DropsView.new()
	_loot_drops.resized_contents.connect(_centre_loot)
	found.add_child(_loot_drops)
	var close := UITheme.button("Close", "LightButton", "Back to the fight")
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(close_loot)
	found.add_child(close)


## One row of a fight's earnings, centred by shrinking to what it holds: HORIZONTAL_ALIGNMENT_CENTER
## centres text inside a label and says nothing about where the label itself sits in the column.
func _sums_row(into: Container) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	into.add_child(row)
	return row


## One sum in that row: a bare number behind its mark. The mode goes on before the texture, or the
## minimum stays the texture's (see OrbSlot).
func _sum(row: HBoxContainer, icon: Texture2D, size: Vector2) -> Label:
	var pair := HBoxContainer.new()
	pair.add_theme_constant_override("separation", 6)
	row.add_child(pair)
	var mark := TextureRect.new()
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.texture = icon
	mark.custom_minimum_size = size
	pair.add_child(mark)
	var label := _label("")
	pair.add_child(label)
	return label


## A brown square with a cream mark, the same button as the map's bag and skills. The loot counter
## also writes its count on it, so the words are cream to match the mark.
func _square_button(icon: Texture2D) -> Button:
	var button := Button.new()
	button.theme_type_variation = "BrownIconButton"
	button.icon = icon
	button.expand_icon = false
	for item: String in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(item, Palette.PANEL_CREAM)
	button.add_theme_color_override("font_disabled_color", UITheme.DISABLED_FONT_COLOR)
	return button


## A word standing on the arena rather than on a panel: its own colour, and the dark outline that is
## what makes it readable over a snowfield or a noon desert.
func _hud_label(text: String, colour: Color) -> Label:
	var label := _label(text)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", LABEL_OUTLINE)
	label.add_theme_color_override("font_outline_color", Palette.INK)
	return label


func _label(text: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = "PanelLabel"
	label.text = text
	return label


## A blow landing. An automatic swing plays the animation and the sound the way a click does, so a
## weapon working on its own looks like the player is doing it rather than like the enemy losing
## health for no reason. A click has already played both -- it plays them whether or not it lands,
## because a swing that hit nothing is still feedback that the click was heard.
func _on_hit_landed(amount: float, crit: bool, automatic: bool) -> void:
	if automatic:
		_swing()
	_show_damage(amount, crit)
	_jolt_enemy()
	(_crit_sound if crit else _hit_sound).play()
	if crit and _crit_layer != null:
		_crit_layer.play()
	if crit:
		Juice.shake(_arena, SHAKE_CRIT)


## The body taking a blow: a white flash and a squash onto its feet, both springing back. A blow
## landing mid-jolt starts it over rather than stacking on it.
func _jolt_enemy() -> void:
	if _enemy_hit != null and _enemy_hit.is_valid():
		_enemy_hit.kill()
	_enemy.modulate = HIT_FLASH
	_enemy.scale = _enemy_scale * HIT_SQUASH
	_enemy_hit = create_tween().set_parallel(true)
	_enemy_hit.tween_property(_enemy, "modulate", Color.WHITE, HIT_TIME)
	_enemy_hit.tween_property(_enemy, "scale", _enemy_scale, HIT_TIME) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The player swinging, whether they clicked for it or the weapon did it for them. A swing landing on
## top of one still running does not start over from the wind-up -- it cuts back in at the blow, so
## clicking faster than the animation reads as a run of blows rather than as a stuck first frame.
## One decision serves both halves: the animation's state is what the sound's offset is read from, so
## the two can never disagree about whether this is a fresh swing.
func _swing() -> void:
	var again := _player.is_playing() and _player.animation == "attack"
	_player.play_once("attack", SWING_RESTART_FRAME)
	_sound.play(SWING_RESTART_SECONDS if again else 0.0)
	_hop_player()


## A small hop on the spot with every swing, so spamming clicks shows a bounce even when the attack
## animation is only being cut back to its blow frame.
func _hop_player() -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	if _hop != null and _hop.is_valid():
		_hop.kill()
	var ground := _size().y * _ground()
	_player.position.y = ground
	_hop = create_tween()
	_hop.tween_property(_player, "position:y", ground - SWING_HOP, SWING_HOP_TIME / 2.0) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop.tween_property(_player, "position:y", ground, SWING_HOP_TIME / 2.0) 			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The number that floats off the enemy. This is the only place the player can read what their gear
## is worth: everything else about a hit looks the same whether it took one point off or nine.
func _show_damage(amount: float, crit: bool) -> void:
	var written := BigNumber.format(amount)
	_float_text((written + "!") if crit else written, CRIT_COLOR if crit else Palette.BONE,
			CRIT_FONT if crit else DAMAGE_FONT, ENEMY_X, 1.25 if crit else 1.0)


## What an enemy's blow did to the clock, over the player the way a damage number is over the enemy:
## the seconds it took in the clock's own red, or the word for a blow that took nothing. The enemy
## swings for it, and a blow that cost something flashes the clock, which is where it was paid.
func _on_player_hit(taken: float, dodged: bool, blocked: bool) -> void:
	if _enemy != null and _enemy.sprite_frames != null:
		_enemy.play_once("attack")
	# Over the player's head and outlined: the words stand on the sky and the hero rather than on an
	# enemy's plain body, and nothing up there is a panel for them to climb into.
	if dodged:
		_float_text("Dodge", Palette.BONE, DAMAGE_FONT, PLAYER_X, 1.0, STRUCK_HEIGHT, true)
	elif blocked:
		_float_text("Block", Palette.BONE, DAMAGE_FONT, PLAYER_X, 1.0, STRUCK_HEIGHT, true)
	else:
		_float_text("-%ss" % _seconds_written(taken), BAR_HEALTH, DAMAGE_FONT, PLAYER_X, 1.0,
				STRUCK_HEIGHT, true)
		_flash_clock()
		_struck_sound.play()


## Seconds as a blow's number says them: a tenth while it is small enough for a tenth to matter.
static func _seconds_written(seconds: float) -> String:
	return "%.1f" % seconds if seconds < 100.0 else BigNumber.format(seconds)


## The clock showing it has just been struck: red over its own colour, fading back. Not behind the
## animation level -- it is how a player without the numbers sees that the time went.
func _flash_clock() -> void:
	if _clock == null or fight.endless:
		return
	_clock.modulate = CLOCK_STRUCK
	create_tween().tween_property(_clock, "modulate", Color.WHITE, CLOCK_STRUCK_TIME)


## A word or a number rising off one of the fighters: across at `across` of the view, `height` of a
## fighter up from the ground, popping in at `pop` times its settled size, and with the HUD's dark
## outline where it asks for one. Everything that floats off a fight comes through here.
func _float_text(text: String, colour: Color, font_size: int, across: float, pop := 1.0,
		height := DAMAGE_HEIGHT, outlined := false) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	# LOW keeps the number and its rise, without the pop or the wander.
	var lively := Settings.animations == Settings.Anim.DEFAULT
	var label := _hud_label(text, colour) if outlined else _label(text)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_font_size_override("font_size", font_size)
	label.z_index = 1
	label.scale = Vector2(_ui_scale, _ui_scale)
	add_child(label)
	# Started a little to the side of centre each time, so a fast weapon does not stack its numbers
	# into one illegible pile.
	var view := _size()
	# Off the body rather than off the head: the enemy's name and health sit above it, and a number
	# climbing into that panel is unreadable against it.
	# Centred on that spot across rather than started at it: a crit is three times the width the
	# number used to be, so a left corner pinned to the enemy would hang it off the far side. Only
	# across -- the top stays on the anchor, because DAMAGE_HEIGHT is chosen so the whole rise from
	# there clears the name panel. The width is asked of the font rather than read off the label,
	# which has not been laid out yet.
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x * _ui_scale
	var from := Vector2(view.x * across + randf_range(-DAMAGE_SPREAD, DAMAGE_SPREAD) - width * 0.5,
			view.y * _ground() - _actor_height(view) * height)
	# Pops in large about its own middle and settles, which is what makes a number land rather than
	# appear. The pivot is in the label's own unscaled pixels, and scaling about it moves the corner,
	# so `from` is shifted back by what the settled scale would move it.
	label.pivot_offset = Vector2(width / _ui_scale, font_size) / 2.0
	from += label.pivot_offset * (_ui_scale - 1.0)
	label.position = from
	if lively:
		label.scale = Vector2(_ui_scale, _ui_scale) * DAMAGE_POP_SCALE * pop
	var float_up := create_tween()
	float_up.set_parallel(true)
	float_up.tween_property(label, "scale", Vector2(_ui_scale, _ui_scale), DAMAGE_POP) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var drift := randf_range(-DAMAGE_DRIFT, DAMAGE_DRIFT) if lively else 0.0
	float_up.tween_property(label, "position", from + Vector2(drift, -DAMAGE_RISE), DAMAGE_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	float_up.tween_property(label, "modulate:a", 0.0, DAMAGE_TIME).set_ease(Tween.EASE_IN)
	float_up.chain().tween_callback(label.queue_free)


## Where a body's droppings come from: the middle of the enemy standing there. Rather than ENEMY_X
## the way a damage number is, because a drop lands the same frame the enemy dies and so comes off
## the thing the player just killed. The walked-in position is the fallback for the case where there
## is no sprite -- a fight the tests drive with nobody on the field.
func _drop_origin() -> Vector2:
	var view := _size()
	if _enemy != null and _enemy.sprite_frames != null:
		return _enemy.position - Vector2(0, _enemy.drawn_size().y * 0.5)
	return Vector2(view.x * ENEMY_X, view.y * _ground() - _actor_height(view) * DAMAGE_HEIGHT)


## Throws one thing out of the body: an arc onto the ground, a rest where it landed, and a fade.
## Written once because everything a body drops is thrown the same way -- the coins of its purse, the
## gear off it and the orbs -- which is the whole of this change: a kill's takings land in the arena
## rather than being announced in a corner.
##
## `index` is which of a burst this is, so a rich body does not throw its whole purse as one lump;
## `spread` is how far to either side it may land and `rest` how long it lies there.
##
## `collect` is called after the rest instead of the fade, for something that goes somewhere rather
## than lying there -- coins and finds, which fly into the counter.
func _throw(node: Node2D, index: int, from: Vector2, spread: float, rest: float,
		collect := Callable()) -> void:
	node.z_index = 1
	node.scale = Vector2(_ui_scale, _ui_scale)
	# On the ground, which may have gone by since it was last bare: `from` is a place on the screen.
	node.position = from - _ground_drops.position
	_ground_drops.add_child(node)
	var to := node.position.x + randf_range(-spread, spread)
	var top := from.y - THROW_RISE
	# An arc, not a rise: across at a steady rate while the height goes up and comes back down.
	# Two hops on y rather than one tween of the whole position, which is what makes it a jump
	# rather than a slide.
	# The hold-back is a delay on each of the three rather than an interval in front of them,
	# because they all run together and a parallel tween's steps are timed from its own start.
	var delay := index * THROW_STAGGER
	var arc := create_tween()
	arc.set_parallel(true)
	arc.tween_property(node, "position:x", to, THROW_TIME).set_delay(delay)
	arc.tween_property(node, "position:y", top, THROW_TIME / 2.0) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	arc.tween_property(node, "position:y", _size().y * _ground(), THROW_TIME / 2.0) \
			.set_delay(delay + THROW_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	node.set_meta(THROWN, arc)
	# It lies where it fell and then goes.
	arc.chain().tween_interval(rest)
	arc.set_parallel(false)
	if collect.is_valid():
		arc.tween_callback(collect.bind(node))
		return
	arc.tween_property(node, "modulate:a", 0.0, THROW_FADE)
	arc.tween_callback(node.queue_free)


## A coin or a find that has lain its moment, or been picked up, flies into the loot counter,
## gathering speed and shrinking, and the counter flashes as it lands. It leaves the ground for the
## screen, so the walk no longer carries it. A find leaves its beam behind on the ground, to sink back
## into it (`LootBeam.collapse`), drawn at the find's depth as it was.
func _fly_to_counter(thing: Node2D) -> void:
	thing.remove_meta(THROWN)
	for beam: Node2D in thing.get_children():
		beam.z_index = thing.z_index
		beam.reparent(_ground_drops)
		LootBeam.collapse(beam)
	thing.reparent(self)
	var into := _loot_button.position + _loot_button.size * _ui_scale / 2.0
	var fly := create_tween()
	fly.set_parallel(true)
	fly.tween_property(thing, "position", into, COIN_FLY).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.tween_property(thing, "scale", thing.scale * 0.5, COIN_FLY)
	fly.chain().tween_callback(thing.queue_free)
	fly.tween_callback(_bump_counter)


## A brightening rather than a swell: `_place_corners` pins the counter by its top-left corner every
## frame, and scaling it about its middle would walk it off the corner.
func _bump_counter() -> void:
	_loot_button.modulate = BUMP_FLASH
	create_tween().tween_property(_loot_button, "modulate", Color.WHITE, HIT_TIME * 2.0)


## The purse coming off a body, as coins thrown out of it. `Coins.count_for` decides how many, so a
## richer body visibly pays more without the arena filling up -- the count is the log of the amount,
## not the amount. They are the only thing thrown that spins: a coin is drawn turning and gear is not.
func _show_coins(amount: float) -> void:
	# The amount has already gone to the ledger; the coins only say so. LOW says it with one, and NONE
	# with one coin's ring and nothing to see.
	if Settings.animations == Settings.Anim.NONE:
		_land(_coin_sound)
		return
	var from := _drop_origin()
	for i in Coins.count_for(amount) if Settings.animations == Settings.Anim.DEFAULT else 1:
		var coin := AnimatedSprite2D.new()
		coin.sprite_frames = Coins.frames()
		coin.play("spin")
		_throw(coin, i, from, THROW_SPREAD, COIN_REST, _fly_to_counter)
		_land(_coin_sound, i * THROW_STAGGER)


## A body's experience, as gems that pop out of it and fly into the character panel. As many as a
## purse of the same size throws coins, for the same reason. `xp_absorbed` goes out with the last one
## to arrive, carrying the whole amount, so the bar takes it in one step as the burst lands.
func _show_xp(amount: int) -> void:
	# With nothing thrown the bar still has to fill, so it takes the amount now.
	if Settings.animations == Settings.Anim.NONE:
		xp_absorbed.emit(amount)
		return
	var from := _drop_origin()
	var count := Coins.count_for(amount) if Settings.animations == Settings.Anim.DEFAULT else 1
	for i in count:
		var gem := Sprite2D.new()
		gem.texture = XP_GEM
		gem.z_index = 1
		gem.scale = Vector2.ONE * _ui_scale * XP_GEM_SCALE
		gem.position = from
		add_child(gem)
		var landed := Vector2(from.x + randf_range(-XP_POP_SPREAD, XP_POP_SPREAD), from.y)
		var tween := create_tween()
		tween.tween_interval(i * THROW_STAGGER)
		# Up and out, the first half of a throw -- a gem never comes back down.
		tween.set_parallel(true)
		tween.tween_property(gem, "position:x", landed.x, XP_POP_TIME)
		tween.tween_property(gem, "position:y", from.y - XP_POP_RISE, XP_POP_TIME) 				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.set_parallel(false)
		if xp_target.x >= 0.0:
			# Then into the bar, gathering speed, shrinking and fading over the last stretch.
			var fade := XP_FLY_TIME * XP_FADE_SHARE
			tween.tween_property(gem, "position", xp_target, XP_FLY_TIME) 					.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.parallel().tween_property(gem, "scale", gem.scale * 0.5, fade) 					.set_delay(XP_FLY_TIME - fade)
			tween.parallel().tween_property(gem, "modulate:a", 0.0, fade).set_delay(XP_FLY_TIME - fade)
		else:
			tween.tween_property(gem, "modulate:a", 0.0, THROW_FADE)
		if i == count - 1:
			tween.tween_callback(func() -> void: xp_absorbed.emit(amount))
		tween.tween_callback(gem.queue_free)


## A find coming off a body: its own icon, thrown the way the purse is and drawn at `rarity`'s
## `FIND_SIZE`, with that rarity's `LootBeam` standing over it in `glow`. A `rarity` that stands none
## (`LootBeam.has`) is drawn plain.
##
## No name on it. What a find *is* is read in the counter and its list, where there is room for the
## word and time to read it; what the arena has to say is that the body left something, and the
## picture says that the moment it lands.
func _show_find(picture: Texture2D, rarity: int = -1, glow := Color.WHITE) -> void:
	if Settings.animations == Settings.Anim.NONE:
		return
	_finds_shown += 1
	var find := Sprite2D.new()
	find.texture = picture
	var size: float = FIND_SIZE[rarity]
	if LootBeam.has(rarity):
		# The beam is sized on its own, so the find's size is taken back off it -- and handed over as
		# the piece it has to cover instead. Drawn in the fighters' pixels, in the beam's own units.
		var pillar := LootBeam.make(rarity, glow, THROW_TIME, picture.get_size() * Vector2(0.5, 1.0) * size,
				_snap(_size()) / _ui_scale)
		pillar.position = Vector2(0, picture.get_height() / 2.0)
		pillar.scale = Vector2.ONE / size
		find.add_child(pillar)
	_throw(find, 0, _drop_origin(), FIND_SPREAD, FIND_REST, _fly_to_counter)
	find.scale *= size
	find.z_index = 1 + maxi(rarity, 0)


## A track with a fill inside it. The fill is the first child, and its width is set as things change.
## Drawn rather than cut from Assets/bars.png, whose bars come in seven fixed steps in a glossier
## style than the rest of the interface.
func _bar(width: int, height: int, fill: Color) -> Control:
	var track := ColorRect.new()
	track.color = BAR_BACK
	track.custom_minimum_size = Vector2(width, height)
	var bar := ColorRect.new()
	bar.color = fill
	bar.size = Vector2(width, height)
	bar.position = Vector2.ZERO
	track.add_child(bar)
	return track


## A dark border round something, so it reads on whatever the arena puts behind it. A PanelContainer
## rather than a rectangle behind a rectangle: its content margins are the border, so the thing
## inside is laid out and measured without anyone working the inset out twice.
func _outlined(inner: Control, border: int) -> PanelContainer:
	var box := StyleBoxFlat.new()
	box.bg_color = Palette.INK
	box.content_margin_left = border
	box.content_margin_right = border
	box.content_margin_top = border
	box.content_margin_bottom = border
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", box)
	panel.add_child(inner)
	return panel


## What colour the clock is at `share` of its time left: the green it starts at, through the
## palette's gold, to the red a hit lands in. A ramp rather than a switch at some number of seconds
## -- the player is watching the colour out of the corner of an eye, and a bar that is already going
## amber says "hurry" a good deal earlier than one that turns red all at once.
func _clock_color(share: float) -> Color:
	if share >= CLOCK_GREEN:
		return BAR_TIME
	if share >= CLOCK_AMBER:
		return Palette.GOLD.lerp(BAR_TIME, (share - CLOCK_AMBER) / (CLOCK_GREEN - CLOCK_AMBER))
	return BAR_HEALTH.lerp(Palette.GOLD, maxf(share, 0.0) / CLOCK_AMBER)


# ---- drawing what the encounter is doing

## Puts the enemy that is on its way onto the field, off screen and running.
func _on_enemy_coming(_index: int, enemy_name: String, _hp: float) -> void:
	if enemy_name.is_empty():
		_enemy.hide()
		return
	var view := _size()
	_enemy.show()
	var band: float = SIZE_HEIGHT[EnemyRoster.size_of(enemy_name)]
	if _enemy_hit != null and _enemy_hit.is_valid():
		_enemy_hit.kill()
	_enemy.modulate = Color.WHITE
	_enemy.setup_enemy(enemy_name, _actor_height(view) * band, _snap(view), fight.on_elite())
	_enemy_scale = _enemy.scale
	_enemy.position = Vector2(view.x * OFFSCREEN_X, view.y * _ground())
	_enemy.play("walk")
	# The hero walks on to meet it, and the backdrop goes by (`_scroll`) -- but holds a settlement.
	if Settings.animations != Settings.Anim.NONE and _walks_on():
		_player.play("walk")
	_dress_nameplate()


## Writes the nameplate for whoever is walking in: the name in its tier's colour between that tier's
## marks, an elite's title in front of it, a boss's under it at twice the size -- and a boss's plate
## pops in white. Here rather than in `_refresh` because none of it changes while the enemy stands.
func _dress_nameplate() -> void:
	var tier := Encounter.tier_in(fight, fight.index)
	var boss := tier == EnemyRoster.Tier.BOSS
	var title := fight.enemy_title()
	_enemy_label.text = fight.enemy_name() if boss or title.is_empty() \
			else "%s %s" % [title, fight.enemy_name()]
	_enemy_label.add_theme_font_size_override("font_size", BOSS_FONT if boss else NAME_FONT)
	_enemy_title.text = title
	_enemy_title.visible = boss
	for mark in _enemy_marks:
		mark.texture = TIER_MARK.get(tier)
		mark.visible = mark.texture != null
		# A skull stays the bone it is cut in -- tinted green it sank into every meadow -- and only a
		# crown is gilded.
		mark.modulate = Palette.GOLD if boss else Color.WHITE
		if mark.visible:
			mark.custom_minimum_size = mark.texture.get_size() * (2 if boss else 1)
	if _plate_tween != null and _plate_tween.is_valid():
		_plate_tween.kill()
	_plate_pop = 1.0
	_tint_nameplate(TIER_COLOUR[tier])
	if boss and Settings.animations == Settings.Anim.DEFAULT:
		_plate_tween = create_tween().set_parallel()
		_plate_tween.tween_property(self, "_plate_pop", 1.0, BOSS_POP_TIME).from(BOSS_POP) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_plate_tween.tween_method(_tint_nameplate, Color.WHITE, TIER_COLOUR[tier], BOSS_POP_TIME)


func _tint_nameplate(colour: Color) -> void:
	_enemy_label.add_theme_color_override("font_color", colour)
	_slide_enemy()


## Runs the enemy in over the walk-in, then leaves it standing.
func _slide_enemy() -> void:
	if fight.finished or fight.index >= fight.lineup.size():
		return
	var view := _size()
	var home := view.x * ENEMY_X
	if fight.phase == Encounter.Phase.WALKING_IN:
		# A walk-in of nothing (spawn speed at its cap) is over before the view sees it.
		var left := fight.phase_left / fight.walk_in if fight.walk_in > 0.0 else 0.0
		_enemy.position.x = lerpf(home, view.x * OFFSCREEN_X, left)
	else:
		_enemy.position.x = home


func _refresh() -> void:
	if fight == null:
		return
	var view := _size()
	# A farm run has no clock; its bar is the whole of what the HUD says.
	if not fight.endless:
		var seconds := ceili(fight.time_left)
		_clock_label.text = "%d:%02d" % [seconds / 60, seconds % 60]
		var share := clampf(fight.time_left / fight.seconds, 0.0, 1.0)
		_clock_fill.size.x = _clock_fill.get_parent().size.x * share
		# The number goes with the bar. They are one clock, and the colour is the part of it read
		# without looking straight at it.
		var tint := _clock_color(share)
		_clock_fill.color = tint
		_clock_label.add_theme_color_override("font_color", tint)
	if fight.dungeon:
		_level_label.text = "Depth %d" % fight.depth()
	_pips.show_fight(fight)
	_place_corners(view)
	if _loot_panel.visible:
		_refresh_loot_sums()

	if fight.index >= fight.lineup.size() or fight.finished:
		_enemy_panel.hide()
		return
	_enemy_panel.show()
	var share := fight.hp / maxf(fight.enemy_max_hp(), 1.0)
	# Encounter.tier_in rather than on_elite(): the pips beside this bar colour themselves through the
	# same call, so the frame over the enemy and the pip standing for it can never disagree.
	_enemy_bar.show_health(Encounter.tier_in(fight, fight.index), maxf(share, 0.0))
	# Through BigNumber, like every other growing quantity, and rounded up for the reason the bar
	# never empties to nothing: anything still standing reads as at least 1.
	_enemy_hp_label.text = "%s / %s" % [BigNumber.format(ceilf(maxf(fight.hp, 0.0))),
			BigNumber.format(ceilf(fight.enemy_max_hp()))]


func _on_enemy_spawned(_index: int, _enemy_name: String, _hp: float) -> void:
	_enemy.play("idle")
	# Arrived; a swing struck up on the way in plays out.
	if _player.animation == "walk":
		_player.play("idle")
	_slide_enemy()


## A blow the enemy survived flinches it -- unless it is swinging at the clock, which a flinch would cut
## off before the blow it stands for had been seen. The flash and the squash still say the hit landed.
func _on_enemy_hit(hp_left: float) -> void:
	if hp_left > 0 and not (_enemy.is_playing() and _enemy.animation == "attack"):
		_enemy.play_once("hurt")


## A body going down: it bursts in its own colour, and the game holds its breath for a moment --
## longer, and with the arena rattling, the bigger the thing that fell.
func _on_enemy_died(index: int) -> void:
	_enemy.play_once("death")
	_death_sound.play()
	if Settings.animations != Settings.Anim.NONE:
		var burst := Juice.burst(self, _drop_origin(), _enemy.tint(), DEATH_PIXELS, 220.0,
				3.0 * _ui_scale, 0.6, 500.0)
		burst.z_index = 1
	match Encounter.tier_in(fight, index):
		EnemyRoster.Tier.BOSS:
			Juice.shake(_arena, SHAKE_BOSS, 0.4)
			Juice.hit_stop(get_tree(), STOP_BOSS)
		EnemyRoster.Tier.ELITE:
			Juice.shake(_arena, SHAKE_ELITE, 0.3)
			Juice.hit_stop(get_tree(), STOP_ELITE)
		_:
			Juice.hit_stop(get_tree(), STOP_KILL)


## The one place a find is looked at. One the player has said to leave behind is counted and passed on to
## whoever is keeping the elite promise, and that is all that happens to it: it does not join
## `_drops`, does not move the counter, is never thrown into the arena and appears in neither list.
## Everything else goes on exactly as it did, and leaves by `loot_kept`.
func _on_loot_dropped(index: int, item: Item) -> void:
	# A rule is about ordinary gear: a unique -- or a capstone -- is never thrown away unseen.
	if item.rarity != ItemRarity.Rarity.UNIQUE and autodiscard.is_valid() and bool(autodiscard.call(item)):
		_auto_discarded += 1
		loot_discarded.emit(index, item)
		return
	_drops.append(item)
	_refresh_loot_button()
	if _loot_panel.visible:
		_fill_loot()
	# Below rare is thrown plain (`LootBeam.LOOKS`): a beam means "this one is worth stopping for",
	# and one on everything would mean nothing.
	#
	# The ring's colour rather than the text's. They are the two halves of the same ramp and the
	# choice between them is what is behind the colour: the text half was picked to be read on the
	# bone panel, and a find is thrown against a snowfield or a noon desert, which is exactly what the
	# square's border colour was picked for.
	_show_find(item.icon(), item.rarity, item.border_color())
	_land(_drop_sounds[drop_sound_of(item)])
	# The best finds slow the fight, so the beam coming up is watched rather than glimpsed.
	if item.rarity == ItemRarity.Rarity.UNIQUE:
		Juice.hit_stop(get_tree(), STOP_UNIQUE, STOP_UNIQUE_SPEED, STOP_UNIQUE_EASE)
	elif item.rarity == ItemRarity.Rarity.ELITE:
		Juice.hit_stop(get_tree(), STOP_RARE, STOP_RARE_SPEED)
	loot_kept.emit(index, item)


## A body's purse: coins out of it, and the amount on to whoever is keeping the ledger. The running
## total still lives on the Encounter and the verdict still reads it at the end -- what the coins say
## is that something was earned here, which is the half of it a number at the end of the fight cannot
## tell the player while they are fighting.
func _on_gold_dropped(_index: int, amount: float) -> void:
	_show_coins(amount)
	gold_gained.emit(amount)


## Which of `DROP_SOUNDS` a find lands with: a unique its own boom, anything else the one gear sound.
static func drop_sound_of(item: Item) -> String:
	return "unique" if item.rarity == ItemRarity.Rarity.UNIQUE else "gear"


## A drop's sound as it lands: a throw's length on (and `after` more, for one held back in a burst), on
## a tween, so a unique's slow motion slows it with the find and a tip that holds the fight holds it too
## -- or at once, when nothing is thrown at all.
func _land(sound: AudioStreamPlayer, after := 0.0) -> void:
	if Settings.animations == Settings.Anim.NONE:
		sound.play()
	else:
		create_tween().tween_callback(sound.play).set_delay(THROW_TIME + after)


## A body's experience: gems off it, and the amount on to the ledger straight away.
func _on_xp_dropped(_index: int, amount: int) -> void:
	_show_xp(amount)
	xp_gained.emit(amount)


## A find thrown away by hand from the verdict. The popup shows the same drops, so it is filled again too.
func _on_drop_discarded(item: Item) -> void:
	_drops.erase(item)
	_refresh_loot_button()
	_fill_loot()
	_result_drops.fill(_drops, fight.orbs)
	drop_discarded.emit(item)


## The counter's face: green through gold to red as the bag fills, the way the clock ramps as it runs out. Nobody having
## said (`bag_room` at -1) is an empty bag: a fight with no bag behind it has nothing to warn about.
func _tint_loot_button() -> void:
	var fill := 0.0 if bag_room < 0 else clampf(1.0 - float(bag_room) / maxi(bag_size, 1), 0.0, 1.0)
	if is_equal_approx(fill, _loot_filled):
		return
	_loot_filled = fill
	var want := (FACE_BROWN.lerp(Palette.GOLD, fill / 0.5) if fill <= 0.5
			else Palette.GOLD.lerp(FACE_DANGER, (fill - 0.5) / 0.5))
	# A tint multiplies, so what the boxes are given is the colour wanted divided by the colour the
	# pack drew -- worked out that way round so the constants above are the colours that are seen.
	var tint := Color(want.r / FACE_BROWN.r, want.g / FACE_BROWN.g, want.b / FACE_BROWN.b)
	for face: StyleBox in _loot_faces:
		(face as StyleBoxTexture).modulate_color = tint


## The counter in the corner: the sack and how many finds there are. Always live, even at 0: the
## popup also says the purse, experience and bodies so far.
func _refresh_loot_button() -> void:
	_loot_button.text = str(_drops.size())


## The popup's finds and orbs, and no panel for them at all while there are neither.
func _fill_loot() -> void:
	_loot_drops.fill(_drops, fight.orbs)
	_loot_drops.visible = not (_drops.is_empty() and fight.orbs.is_empty())


## The bottom of the top-centre column -- place, pips and clock -- in screen pixels. For anything the
## main scene stands over a fight and has to keep off the HUD, which is what `_place_corners` placed.
func hud_bottom() -> float:
	return _tally.position.y + _tally.get_combined_minimum_size().y * _ui_scale


## The bottom of the top-right corner's Terminate flag, in screen pixels: the character panel stands
## under it while the bag is up over the fight.
func corner_bottom() -> float:
	return _terminate.position.y + _terminate.get_combined_minimum_size().y * _ui_scale


## Puts the HUD's corners where they belong. Done every frame rather than anchored, because every
## one of them is scaled by `_ui_scale` and an anchor knows nothing about that.
func _place_corners(view: Vector2) -> void:
	# The clock and the pips stand in the middle of the top edge. Placed here rather than anchored
	# for the same reason as the rest: the column is scaled by _ui_scale and an anchor knows nothing
	# about that.
	var tally := _tally.get_combined_minimum_size() * _ui_scale
	_tally.position = Vector2((view.x - tally.x) / 2.0, hud_top)
	# The corners keep to the safe part of the window: on a phone, clear of a notch and its rounded corners.
	var safe := UITheme.safe_rect(get_viewport())
	# The enemy's nameplate centred on the bottom edge, under the fight rather than in it: the health
	# of whatever is standing there is the one thing read continuously, and the middle of the bottom
	# edge is where the eye is already going -- it is directly under the pip bar and the clock, so the
	# whole of how the fight is going reads down one column. Centred rather than aligned to an edge
	# because an elite's brackets and a boss's crown widen the panel, and growing it evenly either
	# side keeps the channel where it was, which is what HealthBar's own TROUGH is for.
	_enemy_panel.scale = Vector2.ONE * _ui_scale * _plate_pop
	var plate := _enemy_panel.get_combined_minimum_size() * _enemy_panel.scale
	var plate_y := safe.end.y - plate.y - HUD_MARGIN
	# Held upright the fight stands mid-window, and its nameplate under its feet, not at the window's foot.
	if UITheme.narrow(view, _ui_scale):
		plate_y = view.y * _ground() + PLATE_UNDER * _ui_scale
	_enemy_panel.position = Vector2((view.x - plate.x) / 2.0, plate_y)
	# The counter in the bottom right, out at the corner so the nameplate has the middle.
	var loot := _loot_button.get_combined_minimum_size() * _ui_scale
	_loot_button.position = Vector2(safe.end.x - loot.x - HUD_MARGIN, safe.end.y - loot.y - HUD_MARGIN)
	_tint_loot_button()
	if _terminate != null:
		var leave := _terminate.get_combined_minimum_size() * _ui_scale
		_terminate.position = Vector2(safe.end.x - leave.x - HUD_MARGIN, safe.position.y + HUD_MARGIN)


## An orb off a body, thrown out of it the way a find is. Plain, but for a good orb, which stands the
## beam of the rarity `OrbTable` names for it, in the orb's own colour.
func _on_orb_dropped(_index: int, orb: String) -> void:
	var beam: int = OrbTable.ORBS[orb].get("beam", -1)
	_show_find(OrbTable.icon(orb), beam, OrbTable.ORBS[orb].get("glow", Color.WHITE))
	_land(_orb_sound)
	if _loot_panel.visible:
		_fill_loot()
	orb_gained.emit(orb)


## A rune off a body in the cave, thrown out of it as an orb is, in the rare's beam and its own colour.
func _on_rune_dropped(_index: int, rune: String) -> void:
	_show_find(RuneTable.icon(rune), ItemRarity.Rarity.RARE, RuneTable.RUNES[rune]["glow"])
	_land(_orb_sound)
	rune_gained.emit(rune)


func _on_loot_pressed() -> void:
	_fill_loot()
	_refresh_loot_sums()
	_loot_panel.show()
	Juice.pop_in(_loot_panel, _ui_scale)
	_centre_loot()
	panel_up.emit()


func _refresh_loot_sums() -> void:
	_loot_gold.text = BigNumber.format(fight.gold)
	_loot_xp.text = BigNumber.format(fight.xp)
	_loot_kills.text = str(fight.kills())


func close_loot() -> void:
	_loot_panel.hide()


## The run ends because the player says so, which is the only way a farm run ends at all. A tile
## fight ended that way is given up: a loss, told apart from running out of time under the verdict.
func _on_terminate_pressed() -> void:
	# A descent is ended as a run is: neither is lost, and the floor it reached stands.
	if fight.endless or fight.dungeon:
		fight.stop()
	else:
		_gave_up = true
		fight.give_up()


func _on_finished(won: bool) -> void:
	Input.set_default_cursor_shape(Cursors.ARROW)
	_refresh()
	_enemy_panel.hide()
	if won:
		_enemy.hide()
	# A farm run is not won or lost, only ended, so it is told what it did rather than how it went.
	if fight.endless:
		_result_label.text = "Run ended"
	elif fight.dungeon:
		_result_label.text = "Depth %d" % fight.depth()
	else:
		_result_label.text = "Success" if won else "Failed"
	# Only a loss has anything to add: the word says a win, and a run has no second line. A descent's
	# is whether it got any deeper, which only a dead Gollux makes it.
	var lost := not won and not fight.endless
	if lost:
		Juice.sound(DEFEAT_SOUND)
	_result_detail.text = "Given up" if _gave_up else "Out of time"
	if fight.dungeon:
		_result_detail.text = "Gollux still stands" if fight.cleared() == 0 \
				else "Gollux fell" if fight.cleared() == 1 else "Gollux fell %d times" % fight.cleared()
		# There is nothing to collect: the dungeon pays nothing.
		_result_drops.hide()
		_collect.text = "Leave"
		_collect.tooltip_text = "Back to the map"
	_result_detail.visible = lost or fight.dungeon
	# A tile lost is headed red, not in the green a win wears; a descent ends rather than fails.
	UITheme.danger_bar(_result, lost and not fight.dungeon)
	_collect.visible = not lost
	_lost_row.visible = lost
	_loot_panel.hide()
	panel_up.emit()
	if fight.gold > 0.0:
		_gold_row.show()
		Juice.count_up(_gold_label, fight.gold, _gold_coin)
	if fight.xp > 0:
		_xp_row.show()
		Juice.count_up(_xp_label, float(fight.xp))
	Juice.count_up(_kills_label, float(fight.kills()))
	if _auto_discarded > 0:
		_auto_label.text = ("1 item discarded automatically" if _auto_discarded == 1
				else "%d items discarded automatically" % _auto_discarded)
		_auto_label.show()
	# The way out of a run goes with the run. Leaving it standing under the verdict would put two
	# buttons on the screen for the one thing left to do.
	if _terminate != null:
		_terminate.hide()
	_result_drops.fill(_drops, fight.orbs)
	_result.show()
	Juice.pop_in(_result, _ui_scale)
	Juice.reveal(_result_drops.pieces())
	if won and auto_collect and not fight.endless and not fight.dungeon:
		var wait := Timer.new()
		wait.one_shot = true
		wait.wait_time = AUTO_COLLECT_SECONDS
		# `pop_out` leaves once however often it is asked, so a Collect pressed first wins.
		wait.timeout.connect(_leave.bind(_on_back_pressed))
		add_child(wait)
		wait.start()
	await _centre_result()
	# A loss is not celebrated; a win, an ended run and a descent are.
	if not lost:
		Juice.celebrate(_hud, _result, _ui_scale, (_result.get_child(0) as Control).size.y)


## Shrinks the verdict away, then does what its button was for.
func _leave(then: Callable) -> void:
	Juice.pop_out(_result, then)


## The panel is only as big as what it holds, and what it holds changes when a drop is opened, so it
## is put back in the middle every time -- after a frame, once it knows its new size.
## Kept off the clock and the pips, which say how the fight ended: a panel that would reach up over
## them is put down under them instead -- but never off the foot of the window, so a run's tall
## verdict still shows its Collect and overlaps the column rather than losing its button.
func _centre_result() -> void:
	await get_tree().process_frame
	_fit_window(_result, _result_drops)
	Juice.centre(_result, _size())
	var top := _result.position.y + _result.pivot_offset.y * (1.0 - _ui_scale)
	var bottom := top + _result.get_combined_minimum_size().y * _ui_scale
	var room := _size().y - RESULT_GAP * _ui_scale - bottom
	var drop := minf(hud_bottom() + RESULT_GAP * _ui_scale - top, room)
	if drop > 0.0:
		_result.position.y += drop


## The loot popup, centred the same way and for the same reason.
func _centre_loot() -> void:
	await get_tree().process_frame
	_fit_window(_loot_panel, _loot_drops)
	Juice.centre(_loot_panel, _size())


## A popup taller than the window gives up rows of its finds until it fits, and they scroll: a run's
## pouch with the full-bag warning over it once ran its title off the top of a 648 px window.
func _fit_window(panel: Control, drops: DropsView) -> void:
	var over := panel.get_combined_minimum_size().y - (_size().y / _ui_scale - 2.0 * RESULT_GAP)
	if over > 0.0 and drops.visible:
		drops.fit_rows(over)
	# And never bigger than what it holds: a find opened is shorter than the grid it was opened from, and
	# the panel kept the grid's height under its button until this.
	panel.reset_size()


func _on_back_pressed() -> void:
	finished.emit(fight.victory)

