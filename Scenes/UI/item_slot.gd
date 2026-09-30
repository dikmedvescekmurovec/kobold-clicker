class_name ItemSlot
extends Panel
## One item, drawn as a square: its icon on a dark socket, ringed in its rarity's colour.
##
## Both places that show an item use this one -- the inventory grid and the panel at the end of a
## fight -- so the square a rare piece makes in the popup is the same square it makes in the bag.
## Written apart from either of them because the moment it is written twice the two drift, which is
## exactly what the user asked to avoid.
##
## The socket is drawn with a StyleBoxFlat rather than cut from art, the same call
## combat_scene._bar makes for its health bars. That is not a stand-in for the pack's slot: the pack
## draws an inventory slot as one flat tan square with a gutter around it and nothing else, so a
## rectangle in its colours is the art. The rarity frame is ours -- the pack has no notion of one --
## drawn by `tools/item_frames.py` and laid over the icon as the square's last child.
##
## It takes no mouse input at all. The grid it sits in is inside a ScrollContainer that has to see
## every press to tell a drag from a click, and a square that swallowed the press would break every
## drag that started on one -- which is most of them. Whoever owns the grid works out which square
## was clicked from where the cursor is.

## The square, and the icon inside it: 32 px of gear with a little air around it.
const SIDE := 40
const ICON := 32
## How solid an empty socket's mark is drawn. Faint enough to read as nothing being there.
const EMPTY_MARK_ALPHA := 0.35
const SHINE := preload("res://Scenes/UI/shine.gdshader")
## How many times a square glints after it is drawn, before it lies still.
const SHINES := 2
## Every square holding a piece is in this group, which is how `ItemCard` finds the one under the
## cursor without any square having to take the mouse.
const GROUP := "item_slots"
## The child that is the rarity's frame (`ItemRarity.frame`); a common square has none.
const FRAME_NAME := "Frame"
## The child `keep_shining` adds.
const GLINT_NAME := "Glint"
## What a `shadow` square is multiplied by: dark enough to read as not held, light enough to tell what it is.
## 0.35 until 2026-09-30, when the user found every unfound unique "way too dark" to make out.
const SHADOW := Color(0.65, 0.65, 0.65)
## The socket under a piece the log knows of and the player has not found: faint, so it reads as
## within reach without looking held.
const KNOWN_SOCKET := Color(1, 1, 1, 0.4)
const GREY := preload("res://Scenes/UI/grey.gdshader")
static var _grey: ShaderMaterial

## What the square holds (null for an empty socket) and whether it is the one its page has open.
var item: Item
var selected := false
## What `ItemCard` writes beside this square instead of the piece itself, as `hint.call(rows, width)`.
## Only a `shadow` carries one.
var hint := Callable()


func setup(held: Item, open := false, translucent := false) -> void:
	item = held
	selected = open
	add_to_group(GROUP)
	custom_minimum_size = Vector2(SIDE, SIDE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var socket := ItemRarity.slot_style(item.rarity, selected, translucent)
	# A frameless piece gets a one-pixel edge, or a common reads as an empty socket beside the framed ones.
	if item.frame() == null:
		socket = socket.duplicate()
		socket.set_border_width_all(1)
		socket.border_color = Palette.SLOT_TAN_DK
	add_theme_stylebox_override("panel", socket)
	tooltip_text = "%s (%s, level %d)" % [item.display_name(), item.rarity_label(), item.level]
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centred by hand: the square is fixed and the icon is fixed, so there is nothing for a container
	# to work out.
	icon.position = Vector2(SIDE - ICON, SIDE - ICON) / 2.0
	# Rare and better glint as they are drawn, so the good pieces catch the eye across the bag.
	if item.rarity >= ItemRarity.Rarity.RARE:
		_shine(icon, ICON, 3.0)
	add_child(icon)
	# The frame goes over the icon, not under it: its corners reach in past the icon's margin.
	var ring := item.frame()
	if ring != null:
		var frame := TextureRect.new()
		frame.name = FRAME_NAME
		frame.texture = ring
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# A unique's frame glints as well as its icon, and faster.
		if item.rarity == ItemRarity.Rarity.UNIQUE and Settings.animations != Settings.Anim.NONE:
			_shine(frame, SIDE, 2.0)
		add_child(frame)
	# Last, over the frame, in the orb tray's corner numeral: every square that shows a piece is this one.
	if item.plus > 0:
		add_child(OrbSlot.count_label("+%d" % item.plus))


## The glint on `target`: `SHINES` sweeps, one a `period`, and then it lies still. The tween is bound
## to the square, so it waits for the square to be in the tree and dies with it.
func _shine(target: TextureRect, side: int, period: float) -> void:
	var glint := ShaderMaterial.new()
	glint.shader = SHINE
	glint.set_shader_parameter("side", float(side))
	target.material = glint
	create_tween().set_loops(SHINES).tween_method(
		func(at: float) -> void: glint.set_shader_parameter("progress", at), 0.0, 1.0, period)


## Glints over the icon without end, until `stop_shining`: a unique new to the collection log. A copy
## of the icon over it carries the glint, so the tween dies with the copy.
func keep_shining() -> void:
	var glint := TextureRect.new()
	glint.name = GLINT_NAME
	glint.texture = item.icon()
	glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glint.position = Vector2(SIDE - ICON, SIDE - ICON) / 2.0
	var shader := ShaderMaterial.new()
	shader.shader = SHINE
	shader.set_shader_parameter("side", float(ICON))
	glint.material = shader
	add_child(glint)
	glint.create_tween().set_loops().tween_method(
		func(at: float) -> void: shader.set_shader_parameter("progress", at), 0.0, 1.0, 1.5)


func stop_shining() -> void:
	var glint := get_node_or_null(GLINT_NAME)
	if glint != null:
		glint.queue_free()


## The square for `item`, ready to be put in a grid or a row.
static func make(item: Item, selected := false, translucent := false) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.setup(item, selected, translucent)
	return slot


## A piece the player has not found, for the collection log, lying still, with `hint` for the card to
## say in the piece's place. One unlocked and not found (`known`) is the piece darkened (`SHADOW`) and
## drained of its colour (`GREY`) on a faint socket; any other is its outline in black with no socket.
## Neither wears a ring.
static func shadow(item: Item, says: Callable, known := false) -> ItemSlot:
	var slot := make(item)
	slot.hint = says
	slot.tooltip_text = "Not found yet"
	var frame := slot.get_node_or_null(FRAME_NAME)
	if frame != null:
		slot.remove_child(frame)
		frame.free()
	# No glint: that is what a piece in hand does.
	(slot.get_child(0) as TextureRect).material = null
	if known:
		# The piece darkened on a faint socket, and no ring (the user's call, 2026-09-28): the socket's
		# own drawing is `self_modulate`, so the icon over it is not faded with it. Grey as well as dark:
		# darkened alone, a found square and an unfound one were told apart by the ring, which is too
		# little -- and darker was the user's "way too dark", so the colour goes instead.
		slot.self_modulate = KNOWN_SOCKET
		var icon := slot.get_child(0) as TextureRect
		icon.modulate = SHADOW
		if _grey == null:
			_grey = ShaderMaterial.new()
			_grey.shader = GREY
		icon.material = _grey
		return slot
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	(slot.get_child(0) as TextureRect).modulate = Color.BLACK
	return slot


## A piece promised and not yet rolled -- a bounty's reward: `mark` on the socket in `rarity`'s frame,
## with `+n` on the corner if it is ascended. Not an `ItemSlot` in `GROUP`, since there is no piece
## for the card to write; `label` is its tooltip. `side` is `SIDE` or half of it: at half, `ui_scale` 2
## draws the icon and the frame at their own pixels, the way the orb tray draws 32 px orbs at 16.
static func teaser(mark: Texture2D, rarity: ItemRarity.Rarity, plus: int, label: String,
		side := SIDE) -> ItemSlot:
	var icon_side := ICON * side / SIDE
	var slot := ItemSlot.new()
	slot.custom_minimum_size = Vector2(side, side)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel", ItemRarity.slot_style(rarity))
	slot.tooltip_text = label
	var icon := TextureRect.new()
	# Set before the texture and the size: a 16 px mark is asked to stand at the icon's 32.
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.texture = mark
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = Vector2(side - icon_side, side - icon_side) / 2.0
	icon.size = Vector2(icon_side, icon_side)
	slot.add_child(icon)
	var ring := ItemRarity.frame(rarity)
	if ring != null:
		var frame := TextureRect.new()
		frame.name = FRAME_NAME
		frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		frame.stretch_mode = TextureRect.STRETCH_SCALE
		frame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		frame.texture = ring
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.size = Vector2(side, side)
		slot.add_child(frame)
	if plus > 0:
		slot.add_child(OrbSlot.count_label("+%d" % plus))
	return slot


## An empty socket on the equipment panel: the same square with nothing in it.
##
## `mark` is the pack's own faint drawing of what belongs there, and only the sockets a body does not
## explain get one. Where the weapon goes is obvious from the hand it is beside; which of two squares
## under the doll takes a ring is not, and the pack drew marks for exactly those.
static func empty(label: String, mark: Texture2D = null, selected := false, translucent := false) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.custom_minimum_size = Vector2(SIDE, SIDE)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_theme_stylebox_override("panel",
			ItemRarity.slot_style(ItemRarity.Rarity.COMMON, selected, translucent))
	slot.tooltip_text = label
	if mark != null:
		var icon := TextureRect.new()
		icon.texture = mark
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Dimmed rather than drawn in another colour: the mark has to read as the absence of an item,
		# and anything solid enough to read as an item is too solid.
		icon.modulate = Color(1, 1, 1, EMPTY_MARK_ALPHA)
		icon.position = (Vector2(SIDE, SIDE) - mark.get_size()) / 2.0
		slot.add_child(icon)
	return slot
