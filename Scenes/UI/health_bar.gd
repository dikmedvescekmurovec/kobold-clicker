class_name HealthBar
extends Control
## The enemy's health: a trough in the frame its tier earns (a plain wall for a common, a green gem in
## each end for an elite, a gold crown for a boss). Butted together, with no separation, from a left
## cap, `SEGMENTS` pieces of track and a right cap, as `KillPips` is, since one sprite would fix the
## bar's length; the parts are drawn by AI-sprites-generator/hpbar.py and written into Assets/UI/ by
## build_hpbar.py. The fill alone is drawn here: a sprite fill would arrive in fixed steps, so the red
## is a ColorRect free to be any width, snapped to whole sprite pixels all the same.

## Panel pixels a sprite pixel is drawn at: whole, so it stays square.
const PIXEL := 2

## The art's own geometry in sprite pixels, from hpbar.py. Written down because the fill is placed
## before anything has been laid out; `_init` asserts the sprites still measure it.
const HEIGHT := 8
const SEGMENTS := 13
## The channel: rows 2 to 5, between the two rims.
const CHANNEL_TOP := 2
const CHANNEL_HEIGHT := 4
## How much channel there is to fill: the track run and each cap's last column. The same in every tier
## (the ornament grows outward and the trough never moves), so a full bar means one thing whoever
## stands there.
const TROUGH := 2 + 4 * SEGMENTS

## The game's health red: the fight borrows it for the crit numbers and the end of the clock's ramp.
const FILL := Color("c42430")
## What a blow took off stands in a pale bar behind the red for `GHOST_HOLD` seconds, then drains at
## `GHOST_SPEED` channel pixels a second, so how big a hit was is read off the bar.
const GHOST := Palette.SLOT_TAN
const GHOST_HOLD := 0.25
const GHOST_SPEED := 60.0

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

var _cap_l: TextureRect
var _cap_r: TextureRect
var _tracks: Array[TextureRect] = []
var _fill: ColorRect
var _ghost: ColorRect
## How many channel pixels the ghost covers, fractional so it drains smoothly, and how long it still
## holds before it starts to.
var _ghost_pixels := 0.0
var _ghost_wait := 0.0
## The red's width last drawn, in channel pixels.
var _shown := 0
## The tier whose textures are up, or -1 before the first `show_health`.
var _tier := -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The parts stand in a row of their own, so the fill can be placed over them by hand: a container
	# would lay it out beside the track.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	_cap_l = _part(row, CAP_L[EnemyRoster.Tier.COMMON])
	for _i in SEGMENTS:
		_tracks.append(_part(row, TRACK[EnemyRoster.Tier.COMMON]))
	_cap_r = _part(row, CAP_R[EnemyRoster.Tier.COMMON])

	_ghost = ColorRect.new()
	_ghost.color = GHOST
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ghost)

	_fill = ColorRect.new()
	_fill.color = FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	for tier in TRACK:
		assert(TRACK[tier].get_width() == 4, "a track piece is not 4 px wide")
		assert(TRACK[tier].get_height() == HEIGHT, "a track piece is not HEIGHT tall")
		assert(CAP_L[tier].get_height() == HEIGHT and CAP_R[tier].get_height() == HEIGHT,
				"a cap is not HEIGHT tall")
		assert(CAP_L[tier].get_width() == CAP_R[tier].get_width(), "the two caps differ in width")
		assert(_trough_of(tier) == TROUGH, "tier %d leaves %d px of channel, not TROUGH (%d)"
				% [tier, _trough_of(tier), TROUGH])


## One piece, blown up to `PIXEL` through its minimum size, not the node's `scale`, so the row lays the
## pieces out at the size they are drawn and they still butt together.
func _part(row: HBoxContainer, texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.custom_minimum_size = texture.get_size() * PIXEL
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(rect)
	return rect


## How much channel a tier's parts leave between their two caps, in sprite pixels.
func _trough_of(tier: int) -> int:
	return 2 + SEGMENTS * TRACK[tier].get_width()


## Draws the bar at `share` of full, wearing `tier`'s frame. Called every frame by the HUD: the
## textures are touched only when the tier changes.
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
		# The ornament grows outward, so where the channel starts moves with the tier.
		_fill.position = Vector2((_cap_l.texture.get_width() - 1) * PIXEL, CHANNEL_TOP * PIXEL)
	# Never to nothing while anything is still standing: an enemy on its last hit point shows a sliver,
	# or the bar says it is already dead.
	var pixels := clampi(roundi(TROUGH * share), 0, TROUGH)
	if pixels == 0 and share > 0.0:
		pixels = 1
	_fill.size = Vector2(pixels * PIXEL, CHANNEL_HEIGHT * PIXEL)
	_ghost.position = _fill.position
	# A bar that grew is a new body walking in: the ghost starts where it does. One that shrank has
	# been hit, and the ghost holds where it was before it follows -- but only a ghost that had caught
	# up starts a hold. One already holding or draining carries on, so a steady stream of blows cannot
	# keep it pinned.
	if pixels > _ghost_pixels:
		_ghost_pixels = pixels
	elif pixels < _shown and _ghost_pixels <= _shown:
		_ghost_wait = GHOST_HOLD
	_shown = pixels
	_draw_ghost()


func _process(delta: float) -> void:
	if _ghost_pixels <= _shown:
		return
	if _ghost_wait > 0.0:
		_ghost_wait -= delta
		return
	_ghost_pixels = maxf(_ghost_pixels - GHOST_SPEED * delta, _shown)
	_draw_ghost()


## Snapped to whole sprite pixels, like the red in front of it.
func _draw_ghost() -> void:
	_ghost.size = Vector2(roundi(_ghost_pixels) * PIXEL, CHANNEL_HEIGHT * PIXEL)


## How wide a tier's bar is, in panel pixels.
static func width_of(tier: EnemyRoster.Tier) -> int:
	return (CAP_L[tier].get_width() + SEGMENTS * TRACK[tier].get_width()
			+ CAP_R[tier].get_width()) * PIXEL
