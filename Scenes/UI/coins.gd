class_name Coins
## The coin's picture, and how many coins an amount throws. Only the coins in the air spin (`frames`); a
## coin beside a number is still (`icon`).

const SHEET := preload("res://Assets/coin4_16x16.png")

## Measured off the pixels, never off the sheet's width: 180 px is eleven 16 px cells and 4 px of slack,
## and the last two cells are empty (`test_combat._test_coins` fails on a sheet exported otherwise).
const SIZE := 16
const FRAMES := 9
## Frames a second.
const FPS := 12.0
## The most coins one body throws: past ten they overlap into a smear.
const MOST := 10

static var _icon: AtlasTexture
static var _frames: SpriteFrames


## How many coins `amount` throws: 1 + floor(log10), never more than `MOST`. Counted in whole tens, never
## with `log()`: log(1000) / log(10) is 2.999999999999999 in doubles, which floors to three coins for a
## thousand gold instead of four.
static func count_for(amount: float) -> int:
	var count := 1
	var left := maxf(amount, 1.0)
	while left >= 10.0 and count < MOST:
		left /= 10.0
		count += 1
	return count


static func icon() -> AtlasTexture:
	if _icon == null:
		_icon = _region(0)
	return _icon


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
