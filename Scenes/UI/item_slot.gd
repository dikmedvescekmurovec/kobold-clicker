class_name ItemSlot
extends Panel
## One item, drawn as a square: its icon on a dark socket, ringed in its rarity's colour.
##
## Both places that show an item use this one -- the inventory grid and the panel at the end of a
## fight -- so the square a rare piece makes in the popup is the same square it makes in the bag.
## Written apart from either of them because the moment it is written twice the two drift, which is
## exactly what the user asked to avoid.
##
## The socket and the border are drawn with a StyleBoxFlat rather than cut from art, the same call
## combat_scene._bar makes for its health bars. That is not a stand-in for the pack's slot: the pack
## draws an inventory slot as one flat tan square with a gutter around it and nothing else, so a
## rectangle in its colours is the art. The rarity border is ours -- the pack has no notion of one --
## and a StyleBoxFlat draws it in the same call, where a sprite would need a second layer over it.
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


func setup(item: Item, selected := false, translucent := false) -> void:
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
		var shine := ShaderMaterial.new()
		shine.shader = SHINE
		shine.set_shader_parameter("side", float(ICON))
		icon.material = shine
	add_child(icon)


## The square for `item`, ready to be put in a grid or a row.
static func make(item: Item, selected := false, translucent := false) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.setup(item, selected, translucent)
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
