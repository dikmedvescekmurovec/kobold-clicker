class_name LootBeam
## The beam that stands over a find lying in the arena: a small flame in the rarity's own colour.
##
## Its own class beside `Coins` and for the same reason -- the sheet's geometry is measured rather
## than guessed, it is built once and shared, and a fight throws a great many of them.
##
## The art is the "Mini Falem" effect out of the bought pack under `Assets/Potential/Effects`, cut by
## `tools/loot_beam.py`. The pack ships nine colourways and this takes the **white** one, which is
## what lets one sheet serve the whole rarity ramp: `modulate` multiplies, so white times a rarity
## colour is exactly that colour, where any other colourway would come back muddied. The same reason
## the game keeps no second table of rarity colours anywhere else.
##
## The pack draws it as a comet flying to the right -- a bright head with its trail behind it -- so it
## is turned a quarter turn to stand up, and then the head is the top of the beam and the trail is
## what licks up off the ground. That is a rotation rather than a re-export: turning the pixels would
## put the sheet out of step with the pack it came from, and nothing else about it needs changing.

const SHEET := preload("res://Assets/Effects/loot_beam.png")

## One frame, square, and how many of them. Measured off the cut: fifteen 16 px frames in one row.
## Re-cut at another size or another length, this is what `test_combat` fails on.
const SIZE := 16
const FRAMES := 15
## Frames a second. Fast: it is a flame rather than a turning coin, and a slow one reads as a
## flicker in a lamp instead of as something burning.
const FPS := 15.0
## The quarter turn that stands the comet up. Anticlockwise, so the bright head ends up at the top.
const RISE := -PI / 2.0

static var _frames: SpriteFrames


## The flame, looping.
static func frames() -> SpriteFrames:
	if _frames == null:
		var built := SpriteFrames.new()
		built.rename_animation("default", "burn")
		built.set_animation_speed("burn", FPS)
		built.set_animation_loop("burn", true)
		for i in FRAMES:
			var atlas := AtlasTexture.new()
			atlas.atlas = SHEET
			atlas.region = Rect2(i * SIZE, 0, SIZE, SIZE)
			built.add_frame("burn", atlas)
		_frames = built
	return _frames


## A beam standing in `colour`, ready to be hung behind whatever it is burning off. `alpha` is how
## solid it is drawn; the caller owns that, because how loud a beam should be is a question about the
## arena it stands in rather than about the sheet.
static func make(colour: Color, alpha: float, scale: float) -> AnimatedSprite2D:
	var beam := AnimatedSprite2D.new()
	beam.sprite_frames = frames()
	beam.rotation = RISE
	beam.scale = Vector2(scale, scale)
	beam.modulate = Color(colour.r, colour.g, colour.b, alpha)
	# Behind the thing it burns off, so the piece stays the picture and the beam is what says it is
	# worth picking up.
	beam.z_index = -1
	beam.play("burn")
	return beam
