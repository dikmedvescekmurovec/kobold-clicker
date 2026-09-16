class_name HealthBar
extends Control
## The health of whatever is standing in front of the player, as a bordered trough with the frame the
## tier earns -- a plain wall for a common, a green gem bracketed into each end for an elite, a gold
## crown for a boss. The kill pips beside it have always spoken in tiers and the nameplate did not,
## which is the gap this closes: what is standing there is read off the frame before the name is.
##
## The parts are generated rather than cut. AI-sprites-generator/hpbar.py draws them and
## build_hpbar.py writes them into Assets/UI/, loose, the way the pip parts go in -- the bought packs
## have a flat capsule and a glossy sheared bar and nothing with an elite's frame or a boss's, which
## is the whole point of this one.
##
## Assembled here from three parts rather than shipped as one sprite, for the reason KillPips is:
## one sprite would fix the bar's length. A left cap, SEGMENTS pieces of track and a right cap, butted
## together with no separation.
##
## The fill is the one thing still drawn. A sprite fill would arrive in fixed steps -- which is what
## CombatScene turned the bought bars down for -- so the red stays a ColorRect laid over the channel,
## free to be any width. It is snapped to whole sprite pixels all the same: a bar whose end lands half
## way through a pixel is the one place this could stop looking like pixel art.

## How many panel pixels one sprite pixel is drawn at. Whole numbers only, for the reason `zoom` is,
## and the same two the pip bar above it uses -- the two stand in one column and a bar drawn at a
## different pixel to the one over it reads as a different interface.
const PIXEL := 2

## The art's own geometry, from hpbar.py. Written down here rather than measured off the textures
## because the fill has to be placed before anything has been laid out, and checked in `_init` so a
## rebuilt sheet that moved them says so at once instead of drawing the red in the wrong place.
const HEIGHT := 8
const SEGMENTS := 13
## Where the channel is and how deep, in sprite pixels: rows 2 to 5, between the two rims.
const CHANNEL_TOP := 2
const CHANNEL_HEIGHT := 4
## How much channel there is to fill. A cap's last column is a channel column, so this is the track
## run plus one column at each end -- and it is the same number in every tier, which is the point:
## the ornament grows outward and the trough never moves, so a full bar means one thing whoever is
## standing there.
const TROUGH := 2 + 4 * SEGMENTS

## The red the trough empties in. Defined here rather than on CombatScene because this is the bar it
## belongs to; the fight borrows it back for the crit numbers and for the end of the clock's ramp.
const FILL := Color("c4453a")

## The three parts, each in the three tier colourways, keyed by tier so "which frame is which tier"
## is stated once. There is no empty colourway, unlike the pips: a bar with nothing standing behind
## it is hidden rather than drained.
const CAP_L := {
	EnemyRoster.Tier.COMMON: preload("res://Assets/UI/ui_hpbar_cap_l_common.png"),
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_hpbar_cap_l_elite.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_hpbar_cap_l_boss.png"),
}
const CAP_R := {
	EnemyRoster.Tier.COMMON: preload("res://Assets/UI/ui_hpbar_cap_r_common.png"),
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_hpbar_cap_r_elite.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_hpbar_cap_r_boss.png"),
}
const TRACK := {
	EnemyRoster.Tier.COMMON: preload("res://Assets/UI/ui_hpbar_track_common.png"),
	EnemyRoster.Tier.ELITE: preload("res://Assets/UI/ui_hpbar_track_elite.png"),
	EnemyRoster.Tier.BOSS: preload("res://Assets/UI/ui_hpbar_track_boss.png"),
}

## The pieces, in the order they are butted together, and the red over them.
var _cap_l: TextureRect
var _cap_r: TextureRect
var _tracks: Array[TextureRect] = []
var _fill: ColorRect
## What is drawn now, so the textures are only swapped when the tier actually changes. -1 is "nothing
## yet", which is what makes the first `show_health` do the work.
var _tier := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The parts sit in a row of their own so the fill can be placed over them by hand: a container
	# would lay the fill out beside the track rather than on top of it.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_cap_l = _part(row, CAP_L[EnemyRoster.Tier.COMMON])
	for _i in SEGMENTS:
		_tracks.append(_part(row, TRACK[EnemyRoster.Tier.COMMON]))
	_cap_r = _part(row, CAP_R[EnemyRoster.Tier.COMMON])

	_fill = ColorRect.new()
	_fill.color = FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	# The art has to still be what the constants above say it is, or the red lands off the channel.
	for tier in TRACK:
		assert(TRACK[tier].get_width() == 4, "a track piece is not 4 px wide")
		assert(TRACK[tier].get_height() == HEIGHT, "a track piece is not HEIGHT tall")
		assert(CAP_L[tier].get_height() == HEIGHT and CAP_R[tier].get_height() == HEIGHT,
				"a cap is not HEIGHT tall")
		assert(CAP_L[tier].get_width() == CAP_R[tier].get_width(), "the two caps differ in width")
		assert(_trough_of(tier) == TROUGH, "tier %d leaves %d px of channel, not TROUGH (%d)"
				% [tier, _trough_of(tier), TROUGH])


## One piece, blown up to PIXEL through its minimum size rather than the node's `scale`, so the row
## lays the pieces out at the size they are drawn and they still butt together.
func _part(row: HBoxContainer, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = texture.get_size() * PIXEL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rect)
	return rect


## How much channel a tier's parts leave between their two caps, in sprite pixels. A cap's own last
## column is channel, which is the one column at each end that makes this the same in all three.
func _trough_of(tier: int) -> int:
	return 2 + SEGMENTS * TRACK[tier].get_width()


## Draws the bar at `share` of full, wearing `tier`'s frame. Cheap enough to call every frame, which
## is what the HUD does -- the textures are only touched when the tier changes, and the rest is one
## rectangle's width.
func show_health(tier: EnemyRoster.Tier, share: float) -> void:
	if tier != _tier:
		_tier = tier
		_cap_l.texture = CAP_L[tier]
		_cap_r.texture = CAP_R[tier]
		for piece in _tracks:
			piece.texture = TRACK[tier]
		for piece in [_cap_l, _cap_r] as Array[TextureRect]:
			piece.custom_minimum_size = piece.texture.get_size() * PIXEL
		custom_minimum_size = Vector2(width_of(tier), HEIGHT * PIXEL)
		# The ornament grows outward, so where the channel starts moves with it even though how long
		# it is does not.
		_fill.position = Vector2((_cap_l.texture.get_width() - 1) * PIXEL, CHANNEL_TOP * PIXEL)
	# Snapped to whole sprite pixels, and never to nothing while anything is still standing: an enemy
	# on its last hit point has to show a sliver, or the bar says it is already dead.
	var pixels := clampi(roundi(TROUGH * share), 0, TROUGH)
	if pixels == 0 and share > 0.0:
		pixels = 1
	_fill.size = Vector2(pixels * PIXEL, CHANNEL_HEIGHT * PIXEL)


## How wide a tier's bar comes out, in panel pixels. The HUD has no use for it, but the caller that
## centres the nameplate does, and so does the test that holds the three apart.
static func width_of(tier: EnemyRoster.Tier) -> int:
	return (CAP_L[tier].get_width() + SEGMENTS * TRACK[tier].get_width()
			+ CAP_R[tier].get_width()) * PIXEL
