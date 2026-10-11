class_name SmithSwing
extends RefCounted
## The smith at `TownPage`'s bench: his portrait, and the hammer strike an Upgrade or a Lock runs. The
## page keeps one and ticks it, so the strike's clock outlives the counter being drawn again. A blow
## needs a piece open, which draws no bench: the strike is heard, and seen only if that piece is put
## away mid-swing.

## An owed strike starts this many frames before the one playing would end.
const OVERLAP := 3
## The hammer meets the anvil on the strike's third frame, which is when its sound plays.
const LANDS := 2 * DialogueBox.FRAME_TIME
const ANVIL_SOUND := preload("res://Sounds/Sfx/anvil_hit.ogg")
const BREAK_SOUND := preload("res://Sounds/Sfx/anvil_break.ogg")

## Seconds into the strike playing (-1 while he stands still), and the strikes pressed for meanwhile.
var clock := -1.0
var owed := 0
## The portrait last built: null until the bench is first drawn, and a strike is one frame long then.
var _face: AtlasTexture


## His portrait on its tan socket, on the frame the strike is at.
func portrait() -> PanelContainer:
	var socket := PanelContainer.new()
	var style := BountyList.flat(Palette.SLOT_TAN, 0)
	style.content_margin_left = DialogueBox.SOCKET_PAD.x
	style.content_margin_top = DialogueBox.SOCKET_PAD.y
	style.content_margin_right = DialogueBox.SOCKET_PAD.z
	style.content_margin_bottom = DialogueBox.SOCKET_PAD.w
	socket.add_theme_stylebox_override("panel", style)
	var strip: Texture2D = load(DialogueBox.PORTRAITS % "blacksmith")
	_face = AtlasTexture.new()
	_face.atlas = strip
	_face.region = Rect2(0, 0, strip.get_width(), DialogueBox.PORTRAIT_HEIGHT)
	var picture := TextureRect.new()
	picture.texture = _face
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	socket.add_child(picture)
	_show()
	return socket


## He strikes now, or once the strike playing is nearly done. `sound` plays as the hammer lands, on a
## tween of `host`'s -- or at once when nothing is animated, and he does not move then.
func strike(sound: AudioStream, host: Node) -> void:
	if Settings.animations == Settings.Anim.NONE:
		Juice.sound(sound)
		return
	host.create_tween().tween_callback(func() -> void: Juice.sound(sound)).set_delay(LANDS)
	if clock >= 0.0:
		owed += 1
	else:
		clock = 0.0


## Called every frame by the page.
func tick(delta: float) -> void:
	if clock < 0.0:
		return
	clock += delta
	var end := frames() - (OVERLAP if owed > 0 else 0)
	if clock >= end * DialogueBox.FRAME_TIME:
		if owed > 0:
			owed -= 1
			clock = 0.0
		else:
			clock = -1.0
	_show()


## How many frames one strike is.
func frames() -> int:
	return maxi(1, _face.atlas.get_height() / DialogueBox.PORTRAIT_HEIGHT) if _face != null else 1


func _show() -> void:
	if _face != null:
		var frame := int(clock / DialogueBox.FRAME_TIME) if clock >= 0.0 else 0
		_face.region.position.y = mini(frame, frames() - 1) * DialogueBox.PORTRAIT_HEIGHT
