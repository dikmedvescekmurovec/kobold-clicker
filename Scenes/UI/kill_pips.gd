class_name KillPips
extends HBoxContainer
## How far through a fight the player is, as a row of pips -- a pip an enemy, its shape its tier: a
## round one for the rabble, a bone skull for an elite, a crowned skull for a boss. Each kill spends the
## leftmost pip -- the same shape in dark grey, so a dead skull still reads as one -- and the bar drains
## left to right, the skull or crown parked at the far end being the elite or, on a settlement tile, the
## boss still to be fought.
##
## The pips are the user's design (2026-10-03), drawn by `tools/pips.py` at the interface's own pixel, one
## size for every bar: the fight's and a bounty board's (`show_board`). Every sprite is `WIDTH` across,
## the round one centred in it, so they stand side by side with no gap and a bar's width is arithmetic
## on its count (`width_for`). How many pips the bar has is settled when it is built, because a fight's
## length is the tile's rather than the game's -- a settlement fields fifteen where open land fields ten.
##
## The fights mean different things by the same bar, and the readings belong in one place:
##
## * A tile fight is exactly its lineup long, so the bar is that lineup draining once.
## * A farm run never ends, so the bar is the cycle between elites -- one bar is a block of
##   `Encounter.elite_every` with the elite last. It drains, and refills when that elite falls.
## * The dungeon never ends either, and its bar is its block of fifteen floors with the boss last.
##   A descent begun part-way down a block opens on a bar already part drained.
##
## **No bar shows more than `SHOWN` (10) pips** (the user's, 2026-10-03). A longer one -- a settlement's
## fifteen, a dungeon block -- shows the nine from the enemy being fought and a caret pointing right for
## the rest (`MORE`), and moves on a pip a kill, the one just killed dropping off the left; once its last
## ten are in view the caret goes and those ten drain where they stand.

## How many pips an ordinary tile's bar stands: Encounter.ENEMIES for its fight, and the length of an
## ordinary farm run's cycle, which is Encounter.ELITE_EVERY. They are the same number and this is
## it -- what a bar built without being told anything comes out at.
const SLOTS := 10

## A pip's width in panel pixels: what every sprite measures. Written down rather than read off them
## because the HUD sizes its clock bar to a bar's width before the bar exists; `_init` checks the
## sprites still say the same thing.
const WIDTH := 9
## The most pips a bar shows, and what stands in the last place while more are still to come.
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


## The pip for `tier`, lit or spent.
static func texture(tier: EnemyRoster.Tier, spent := false) -> Texture2D:
	return TEXTURES[tier][int(spent)]


## How wide a bar of `slots` pips comes out, in panel pixels -- never more than `SHOWN` of them. The HUD
## asks before the bar exists, so it is arithmetic on the measurements rather than anything read off a
## built bar.
static func width_for(slots: int) -> int:
	return mini(slots, SHOWN) * WIDTH


## A bar `slots` pips long -- the fight's lineup, a run's cycle between elites, a board's postings. Built
## once and never resized: a fight does not change shape half way through. As tall as the crown,
## whether or not one is in it, so the clock under the bar never moves.
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
## gift in the last place, lit while a cleared board's reward `waiting` -- the last hand-in clears the
## board, so the gift is what it lights.
func show_board(done: int, waiting: bool) -> void:
	for i in _pips.size() - 1:
		_pips[i].texture = texture(EnemyRoster.Tier.COMMON, i >= done)
	_pips[-1].texture = GIFT[int(not waiting)]


## Redraws the bar from the fight. Cheap enough to call every frame, which is what the HUD does --
## a farm run's lineup grows with no signal to say so, so there is nothing to listen to.
func show_fight(fight: Encounter) -> void:
	# Which block. A tile fight has one bar's worth and starts at nought; a farm run's bar is the cycle
	# it is in, so it refills the moment the last of the block goes down.
	var slots := _slots
	var base := 0
	if fight.endless or fight.dungeon:
		# Counted in floors, which for a run are its kills: `first_floor` is nought everywhere but the
		# dungeon. A block begun part-way down starts before the lineup does, and those pips are spent.
		base = ((fight.first_floor + fight.index) / slots) * slots - fight.first_floor
	# A bar longer than it shows starts at the enemy being fought -- the killed have dropped off the
	# left -- until its last `SHOWN` are in view, and while it has not got there the caret is last.
	var start := clampi(fight.index - base, 0, maxi(slots - SHOWN, 0))
	var more := start < slots - SHOWN
	for i in _pips.size():
		if more and i == SHOWN - 1:
			_pips[i].texture = MORE
			continue
		var at := base + start + i
		# A floor before the descent began was rabble -- the boss ends the block -- and asking the
		# lineup for a negative place would read it from the end.
		var tier := Encounter.tier_in(fight, at) if at >= 0 else EnemyRoster.Tier.COMMON
		_pips[i].texture = texture(tier, at < fight.index)
