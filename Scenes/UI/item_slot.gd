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
## What a `shadow` square is multiplied by: dark enough to read as not held, light enough to tell what it is.
const SHADOW := Color(0.35, 0.35, 0.35)

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
	add_theme_stylebox_override("panel", ItemRarity.slot_style(item.rarity, selected, translucent))
	tooltip_text = "%s (%s, level %d)" % [item.display_name(), item.rarity_name(), item.level]
	var icon := TextureRect.new()
	icon.texture = item.icon()
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centred by hand: the square is fixed and the icon is fixed, so there is nothing for a container
	# to work out.
	icon.position = Vector2(SIDE - ICON, SIDE - ICON) / 2.0
	# Rare and better glint now and then, so the good pieces catch the eye across the bag.
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


## The glint on `target`: `SHINES` sweeps, one a `period`, and then it lies still. The tween is bound
## to the square, so it waits for the square to be in the tree and dies with it.
func _shine(target: TextureRect, side: int, period: float) -> void:
	var glint := ShaderMaterial.new()
	glint.shader = SHINE
	glint.set_shader_parameter("side", float(side))
	target.material = glint
	create_tween().set_loops(SHINES).tween_method(
		func(at: float) -> void: glint.set_shader_parameter("progress", at), 0.0, 1.0, period)


## The square for `item`, ready to be put in a grid or a row.
static func make(item: Item, selected := false, translucent := false) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.setup(item, selected, translucent)
	return slot


## A piece the player has not found, for the collection log, lying still, with `hint` for the card to
## say in the piece's place. One a fortuneteller has shown them (`known`) is the whole square darkened
## (`SHADOW`); any other is its outline in black on a plain socket, with no ring to give its rarity away.
static func shadow(item: Item, says: Callable, known := false) -> ItemSlot:
	var slot := make(item)
	slot.hint = says
	slot.tooltip_text = "Not found yet"
	# No glint: that is what a piece in hand does.
	for part: Node in slot.get_children():
		(part as TextureRect).material = null
	if known:
		slot.modulate = SHADOW
		return slot
	var frame := slot.get_node_or_null(FRAME_NAME)
	if frame != null:
		slot.remove_child(frame)
		frame.free()
	(slot.get_child(0) as TextureRect).modulate = Color.BLACK
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
