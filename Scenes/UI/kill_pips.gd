class_name KillPips
extends HBoxContainer
## A row of pips, one an enemy and its shape its tier (round for the rabble, a bone skull for an elite, a
## crowned skull for a boss): the fight's kill bar (`show_fight`) and a bounty board's row
## (`show_board`). Each kill spends the leftmost pip, which keeps its shape in dark grey. The user's
## design (2026-10-03), drawn by `tools/pips.py`, every sprite `WIDTH` across, so they butt with no gap.
##
## What a bar stands for, settled as it is built:
## * a tile fight: its whole lineup, draining once;
## * a farm run, which never ends: the cycle between elites (`Encounter.elite_every`, the elite last),
##   refilled when that elite falls;
## * the dungeon: its block of floors with the boss last, which a descent begun part-way down a block
##   opens part drained.
##
## **No bar shows more than `SHOWN` pips** (the user's, 2026-10-03). A longer one shows the nine from
## the enemy being fought and `MORE`, moving on a pip a kill; once its last ten are in view the caret
## goes and those ten drain where they stand.

## An ordinary bar: `Encounter.ENEMIES` for a tile's fight and `Encounter.ELITE_EVERY` for a farm run's
## cycle, the same number.
const SLOTS := 10

## A pip's width in panel pixels. Written down, not read off the sprites, because the HUD sizes its clock
## bar to a bar's width before the bar exists; `_init` asserts the sprites still measure it.
const WIDTH := 9
## The most pips a bar shows, and the caret in the last place while more are still to come.
const SHOWN := 10
const MORE := preload("res://Assets/UI/ui_pip_more.png")
## What a bounty board's row ends in: a gift, lit then spent (the user's pick, 2026-10-03).
const GIFT := [preload("res://Assets/UI/ui_pip_reward.png"), preload("res://Assets/UI/ui_pip_reward_spent.png")]

## Every pip, by tier, lit then spent.
const TEXTURES := {
	EnemyRoster.Tier.COMMON: [preload("res://Assets/UI/ui_pip_common.png"),
			preload("res://Assets/UI/ui_pip_common_spent.png")],
	EnemyRoster.Tier.ELITE: [preload("res://Assets/UI/ui_pip_elite.png"),
			preload("res://Assets/UI/ui_pip_elite_spent.png")],
	EnemyRoster.Tier.BOSS: [preload("res://Assets/UI/ui_pip_boss.png"),
			preload("res://Assets/UI/ui_pip_boss_spent.png")],
}

var _pips: Array[TextureRect] = []
## How many pips the bar stands for, shown or not.
var _slots := 1


static func texture(tier: EnemyRoster.Tier, spent := false) -> Texture2D:
	return TEXTURES[tier][int(spent)]


## How wide a bar of `slots` pips is, in panel pixels.
static func width_for(slots: int) -> int:
	return mini(slots, SHOWN) * WIDTH


## Built once and never resized. As tall as the crown whether or not one is in it, so the clock under
## the bar never moves.
func _init(slots := SLOTS) -> void:
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = texture(EnemyRoster.Tier.BOSS).get_height()
	_slots = maxi(slots, 1)
	for i in mini(_slots, SHOWN):
		var pip := TextureRect.new()
		pip.texture = texture(EnemyRoster.Tier.COMMON)
		pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pip)
		_pips.append(pip)
	for tier: EnemyRoster.Tier in TEXTURES:
		assert(texture(tier).get_width() == WIDTH and texture(tier, true).get_width() == WIDTH
				and MORE.get_width() == WIDTH and GIFT[0].get_width() == WIDTH,
				"the pip sprites no longer measure %d across" % WIDTH)


## A bounty board's row: a round pip a posting but the last, lit as postings are handed in, and the
## gift in the last place, lit while a cleared board's reward is `waiting` (the last hand-in clears the
## board, so the gift is what it lights).
func show_board(done: int, waiting: bool) -> void:
	for i in _pips.size() - 1:
		_pips[i].texture = texture(EnemyRoster.Tier.COMMON, i >= done)
	_pips[-1].texture = GIFT[int(not waiting)]


## Redraws the bar from the fight. Called every frame by the HUD: a farm run's lineup grows with no
## signal to say so.
func show_fight(fight: Encounter) -> void:
	var slots := _slots
	# Where the bar's block starts in the lineup: nought for a tile fight, which has one bar's worth.
	var base := 0
	if fight.endless or fight.dungeon:
		# Counted in floors, which for a run are its kills: `first_floor` is nought everywhere but the
		# dungeon. A block begun part-way down starts before the lineup does, and those pips are spent.
		base = ((fight.first_floor + fight.index) / slots) * slots - fight.first_floor
	# A bar longer than it shows starts at the enemy being fought, until its last `SHOWN` are in view;
	# while it has not got there the caret is last.
	var start := clampi(fight.index - base, 0, maxi(slots - SHOWN, 0))
	var more := start < slots - SHOWN
	for i in _pips.size():
		if more and i == SHOWN - 1:
			_pips[i].texture = MORE
			continue
		var at := base + start + i
		# A floor before the descent began was rabble (the boss ends the block), and asking the lineup
		# for a negative place would read it from the end.
		var tier := Encounter.tier_in(fight, at) if at >= 0 else EnemyRoster.Tier.COMMON
		_pips[i].texture = texture(tier, at < fight.index)
