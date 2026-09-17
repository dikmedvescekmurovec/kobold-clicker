class_name Coins
## The coin: the picture gold is said with, and the rule for how many of them a purse is worth.
##
## Three places want it -- the bag's footer, the fight's verdict and the burst a body throws out --
## and the sheet's geometry is measured rather than guessed, so it lives in one place for the reason
## KillPips owns its pip parts. The two UI rows take a single resting frame; only the coins in the
## air spin, because a widget that never stops moving is furniture that fidgets.

const SHEET := preload("res://Assets/coin4_16x16.png")

## One frame, square. Measured off the pixels: the sheet is 180 px wide, which is eleven 16 px cells
## with 4 px of slack on the end, and the last two cells are fully transparent -- so the spin is the
## first nine and the sheet's width says nothing useful about it. Re-exported at another size this
## is what `test_combat._test_coins` fails on.
const SIZE := 16
const FRAMES := 9
## Frames a second. Nine frames at twelve is a turn every three quarters of a second, slow enough to
## read as a coin rather than as a flicker.
const FPS := 12.0
## The most coins one body throws, however fat the purse. Ten is already a spray; past that they
## overlap into a smear and cost a frame for nothing.
const MOST := 10

## Built once and kept: a coin is drawn in three places and there are ten kills to a fight.
static var _icon: AtlasTexture
static var _frames: SpriteFrames


## How many coins a purse throws out: 1 + log10 of it, floored, and never more than `MOST`. One coin
## up to nine gold, two up to ninety-nine, three up to nine hundred and ninety-nine.
##
## Counted in whole tens rather than written with `log()`, which is the same answer and cannot be
## off by one: log(1000) / log(10) comes back as 2.999999999999999 in doubles, and floored that is a
## thousand gold throwing three coins instead of four.
##
## The count used to run uncapped, because the decade was the cap while an int was the ceiling: seven
## coins at a million, nineteen at the top of int64. A purse is a float now, so 1e300 would throw
## three hundred and one -- `MOST` is the burst a body can actually be seen to spill.
static func count_for(amount: float) -> int:
	var count := 1
	var left := maxf(amount, 1.0)
	while left >= 10.0 and count < MOST:
		left /= 10.0
		count += 1
	return count


## The coin at rest: the first frame, for the two places gold is written as a number.
static func icon() -> AtlasTexture:
	if _icon == null:
		_icon = _region(0)
	return _icon


## The spin, looping, for the coins in the air.
static func frames() -> SpriteFrames:
	if _frames == null:
		var built := SpriteFrames.new()
		built.rename_animation("default", "spin")
		built.set_animation_speed("spin", FPS)
		built.set_animation_loop("spin", true)
		for i in FRAMES:
			built.add_frame("spin", _region(i))
		_frames = built
	return _frames


static func _region(frame: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(frame * SIZE, 0, SIZE, SIZE)
	return atlas
