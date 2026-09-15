class_name KillPips
extends HBoxContainer
## How far through a fight the player is, as one bar of ten pips -- a pip an enemy, drawn in that
## enemy's tier colour: brown for a common, green for an elite, gold for a boss. The bar starts full
## and each kill empties the leftmost pip, so it drains left to right and the green pip parked at the
## far end is the elite still to be fought.
##
## The bought "Pixel UI pack 3" capsule ships five pips long, so the bar is not a sprite: it is
## assembled here from the three parts tools/ui_kit.py cuts off it -- a head, nine bodies and a tail,
## butted together with no separation. The pack lays that capsule out on a rigid 4 px segment pitch,
## which is the whole reason a ten-pip one can be built from a five-pip one; ui_kit.py holds the
## measurements.
##
## The two fights mean different things by the same bar, and both readings belong in one place:
##
## * A tile fight is exactly SLOTS long, so the bar is its lineup draining once.
## * A farm run never ends, so the bar is the cycle between elites -- ELITE_EVERY is SLOTS, so a
##   cycle is a block of ten with the elite last. It drains, and refills when that elite falls.
##
## A dead pip takes the pack's own undivided grey rather than a darkened pip, which is how the pack
## drains its own bars: the gone part is one smooth run, and what is counted is what is left.

## How many pips stand in the bar: Encounter.ENEMIES for a tile fight, and the length of a farm run's
## cycle, which is Encounter.ELITE_EVERY. They are the same number and this is it.
const SLOTS := 10
## How many panel pixels one sprite pixel is drawn at. Whole numbers only, for the reason `zoom` is:
## half a pixel is not square. Two, because the bar is the thing the player reads mid-fight and the
## art is small -- at one it is a ribbon.
const PIXEL := 2
## How wide the assembled bar comes out, in panel pixels: a 5 px head, nine 4 px bodies and a 3 px
## tail, each drawn at PIXEL. Written down rather than measured at runtime because the HUD sizes its
## clock bar to match before the pips exist; `_init` checks the parts still add up to it.
const WIDTH := 44 * PIXEL

## The three parts, each in the three tier colourways and in the empty grey. Keyed by tier so the
## rule "which colour is which tier" is stated once; `EMPTY` is what a pip whose enemy is down takes.
const EMPTY := "empty"
const HEAD := {
	EnemyRoster.Tier.COMMON: preload("res://Assets/UI/ui_pip_head_common.png"),
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_pip_head_elite.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_pip_head_boss.png"),
	EMPTY: preload("res://Assets/UI/ui_pip_head_empty.png"),
}
const BODY := {
	EnemyRoster.Tier.COMMON: preload("res://Assets/UI/ui_pip_body_common.png"),
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_pip_body_elite.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_pip_body_boss.png"),
	EMPTY: preload("res://Assets/UI/ui_pip_body_empty.png"),
}
const TAIL := {
	EnemyRoster.Tier.COMMON: preload("res://Assets/UI/ui_pip_tail_common.png"),
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_pip_tail_elite.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_pip_tail_boss.png"),
	EMPTY: preload("res://Assets/UI/ui_pip_tail_empty.png"),
}

## The ten pips, and the piece that closes the bar off after them.
var _pips: Array[TextureRect] = []
var _tail: TextureRect


func _init() -> void:
	# No separation at all: the parts are cut to butt together into one capsule, and a gap of even a
	# pixel would break it back into ten bars -- which is what this replaced.
	add_theme_constant_override("separation", 0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in SLOTS:
		_pips.append(_part(HEAD[EMPTY] if i == 0 else BODY[EMPTY]))
	_tail = _part(TAIL[EMPTY])
	var built: int = HEAD[EMPTY].get_width() + (SLOTS - 1) * BODY[EMPTY].get_width() + TAIL[EMPTY].get_width()
	assert(built * PIXEL == WIDTH, "the pip parts add up to %d, not WIDTH (%d)" % [built * PIXEL, WIDTH])


## One piece of the bar, blown up to PIXEL. Scaled through the minimum size rather than the node's
## `scale`, so the container lays the pieces out at the size they are drawn and they still butt
## together; the project draws every texture nearest, so the pixels stay square.
func _part(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = texture.get_size() * PIXEL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


## Redraws the bar from the fight. Cheap enough to call every frame, which is what the HUD does --
## a farm run's lineup grows with no signal to say so, so there is nothing to listen to.
func show_fight(fight: Encounter) -> void:
	# Which ten. A tile fight has one bar's worth and starts at nought; a farm run's bar is the cycle
	# it is in, so it refills the moment the tenth of the last block goes down.
	var base := 0
	if fight.endless:
		base = (fight.index / SLOTS) * SLOTS
	# Variant, not String: a live pip's key is an EnemyRoster.Tier and a dead one's is EMPTY, and the
	# dictionaries above are keyed by both.
	var last: Variant = EMPTY
	for i in SLOTS:
		var at := base + i
		var key: Variant = EMPTY if at < fight.index else _tier_at(fight, at)
		_pips[i].texture = HEAD[key] if i == 0 else BODY[key]
		last = key
	# The bar closes in whatever is at its end, so a full bar ends green and a spent one ends grey.
	_tail.texture = TAIL[last]


## The tier of the enemy at `at`. Asked of the roster where that enemy exists, because that is what
## actually walked in; asked of the position otherwise, which is the only answer available for a farm
## run's pips whose enemies have not been rolled yet. Encounter.tier_at is the rule the lineup was
## built to, so the two agree -- test_combat pins that.
func _tier_at(fight: Encounter, at: int) -> EnemyRoster.Tier:
	if at < fight.lineup.size():
		return EnemyRoster.tier_of(fight.lineup[at])
	return Encounter.tier_at(at)
