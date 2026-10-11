class_name ItemSlot
extends Panel
## One item as a square: its icon on a tan socket under its rarity's frame, with its corner marks. Every
## place that shows a piece draws this one, so a rare piece makes the same square in the bag, on the
## doll, on a shelf and among a fight's finds.
##
## The socket is a StyleBoxFlat, and that is the art, not a stand-in: the pack draws an inventory slot
## as one flat tan square. The rarity frame is ours (`tools/item_frames.py`), laid over the icon.

## The square, and the icon inside it.
const SIDE := 40
const ICON := 32
## How solid an empty socket's mark is drawn: faint enough to read as nothing being there.
const EMPTY_MARK_ALPHA := 0.35
const SHINE := preload("res://Scenes/UI/shine.gdshader")
## How many times a square glints after it is drawn, before it lies still.
const SHINES := 2
## Every square with a card to write (a piece, or a `hint`) is in this group, which is how `ItemCard`
## finds the one under the cursor without any square having to take the mouse.
const GROUP := "item_slots"
## The child that is the rarity's frame (`ItemRarity.frame`); a common square has none.
const FRAME_NAME := "Frame"
## The child `keep_shining` adds.
const GLINT_NAME := "Glint"
## What a `shadow` square's icon is multiplied by: dark enough to read as not held, light enough to tell
## what it is (the user's, 2026-09-30: at 0.35 every unfound unique was "way too dark").
const SHADOW := Color(0.65, 0.65, 0.65)
## The socket under a piece the log knows of and the player has not found: faint, so it reads as
## within reach without looking held.
const KNOWN_SOCKET := Color(1, 1, 1, 0.4)
const GREY := preload("res://Scenes/UI/grey.gdshader")
static var _grey: ShaderMaterial
## A locked piece's padlock (`Item.locked`), in the corner across from its `+n`: bone (`#`) over an ink
## outline (`o`), as the `+n` is. Its child is named `LOCK_NAME`.
const LOCK: Array[String] = [
	"..ooo..",
	".o###o.",
	"o#ooo#o",
	"o#o.o#o",
	"ooooooo",
	"o#####o",
	"o##o##o",
	"o#####o",
	"ooooooo",
]
const LOCK_NAME := "Lock"
static var _lock: ImageTexture

## What the square holds (null for an empty socket) and whether it is the one its page has open.
var item: Item
var selected := false
## What `ItemCard` writes beside this square instead of the piece itself, as `hint.call(rows, width)`:
## a square of the collection log or the achievements, the skill tree's root, a unique to banish.
var hint := Callable()


## Every square is deaf to the mouse: the grid it sits in is in a ScrollContainer that has to see every
## press to tell a drag from a click, and a square that swallowed the press would break every drag that
## started on one. Whoever owns the grid works out which square was pressed from where the cursor is.
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(held: Item, open := false, translucent := false) -> void:
	item = held
	selected = open
	add_to_group(GROUP)
	custom_minimum_size = Vector2(SIDE, SIDE)
	var socket := ItemRarity.slot_style(item.rarity, selected, translucent)
	# A frameless piece gets a one-pixel edge, or a common reads as an empty socket beside the framed ones.
	if item.frame() == null:
		socket = socket.duplicate()
		socket.set_border_width_all(1)
		socket.border_color = Palette.SLOT_TAN_DK
	add_theme_stylebox_override("panel", socket)
	tooltip_text = "%s (%s, level %d)" % [item.display_name(), item.rarity_label(), item.level]
	# Child 0, placed by hand: the square and the icon are both fixed, so a container has nothing to do.
	var icon := _picture(item.icon())
	icon.custom_minimum_size = Vector2(ICON, ICON)
	icon.position = Vector2(SIDE - ICON, SIDE - ICON) / 2.0
	# Rare and better glint as they are drawn, so the good pieces catch the eye across the bag.
	if item.rarity >= ItemRarity.Rarity.RARE:
		_shine(icon, ICON, 3.0)
	add_child(icon)
	# The frame goes over the icon, not under it: its caps reach in past the icon's margin.
	var ring := item.frame()
	if ring != null:
		var frame := _picture(ring)
		frame.name = FRAME_NAME
		# Its caps and a unique's crest stand up into the gutter over the square.
		frame.position.y = -ItemRarity.FRAME_HEAD
		# A unique's frame glints as well as its icon, and faster.
		if item.rarity == ItemRarity.Rarity.UNIQUE and Settings.animations != Settings.Anim.NONE:
			_shine(frame, SIDE, 2.0)
		add_child(frame)
	# Last, over the frame, in the orb tray's corner numeral.
	if item.plus > 0:
		add_child(OrbSlot.count_label("+%d" % item.plus))
	if item.locked:
		var lock := _picture(lock_texture())
		lock.name = LOCK_NAME
		lock.position = Vector2(1, SIDE - LOCK.size() - 1)
		add_child(lock)


## `texture` as a child for a square, deaf to the mouse as the square is. `scaled` is for one drawn at
## another size than its own.
static func _picture(texture: Texture2D, scaled := false) -> TextureRect:
	var made := TextureRect.new()
	if scaled:
		# Before the texture and any size: a TextureRect's least size is its texture's until
		# `expand_mode` says otherwise, and a size already clamped to that does not shrink back.
		made.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		made.stretch_mode = TextureRect.STRETCH_SCALE
		made.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	made.texture = texture
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## The padlock, drawn once: the square's corner mark and the bag's Lock button wear it.
static func lock_texture() -> ImageTexture:
	if _lock == null:
		_lock = ImageTexture.create_from_image(UITheme.stamp(LOCK, {"#": Palette.BONE, "o": Palette.INK}))
	return _lock


## The glint on `target`: `sweeps` of it (0: without end), one a `period`. The tween is bound to
## `target`, so it waits for it to be in the tree and dies with it.
static func _shine(target: TextureRect, side: int, period: float, sweeps := SHINES) -> void:
	var glint := ShaderMaterial.new()
	glint.shader = SHINE
	glint.set_shader_parameter("side", float(side))
	target.material = glint
	target.create_tween().set_loops(sweeps).tween_method(
		func(at: float) -> void: glint.set_shader_parameter("progress", at), 0.0, 1.0, period)


## Takes the glint off the icon and the frame: on a log page only what is new glints.
func still() -> void:
	(get_child(0) as TextureRect).material = null
	var frame := get_node_or_null(FRAME_NAME) as TextureRect
	if frame != null:
		frame.material = null


## Glints without end until the card is first written beside it (the cursor coming onto it), and then
## calls `seen`: something new on a log page. The page being closed is the other way it stops, and
## that is the page's to say.
func shine_until_hovered(seen: Callable) -> void:
	keep_shining()
	var write := hint
	hint = func(rows: VBoxContainer, width: float) -> void:
		write.call(rows, width)
		stop_shining()
		seen.call()


## Glints over the icon without end, until `stop_shining`: a copy of the icon carries the glint,
## straight over the icon and under the frame and whatever is on the corners.
func keep_shining() -> void:
	var glint := _picture(item.icon())
	glint.name = GLINT_NAME
	glint.position = Vector2(SIDE - ICON, SIDE - ICON) / 2.0
	add_child(glint)
	move_child(glint, 1)
	_shine(glint, ICON, 1.5, 0)


func stop_shining() -> void:
	var glint := get_node_or_null(GLINT_NAME)
	if glint != null:
		glint.queue_free()


static func make(item: Item, selected := false, translucent := false) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.setup(item, selected, translucent)
	return slot


## A piece the player has not found, for the collection log, lying still, with `says` (`hint`) for the
## card to write in the piece's place. One unlocked and not found (`known`) is the piece darkened
## (`SHADOW`) and drained of its colour (`GREY`) on a faint socket; any other is its outline in black
## with no socket. Neither wears a ring.
static func shadow(item: Item, says: Callable, known := false) -> ItemSlot:
	var slot := make(item)
	slot.hint = says
	slot.tooltip_text = "Not found yet"
	var frame := slot.get_node_or_null(FRAME_NAME)
	if frame != null:
		slot.remove_child(frame)
		frame.free()
	var icon := slot.get_child(0) as TextureRect
	# No glint: that is what a piece in hand does.
	icon.material = null
	if known:
		# No ring (the user's call, 2026-09-28). The socket's own drawing is `self_modulate`, so the icon
		# over it is not faded with it. Grey as well as dark: darkened alone, only the ring told a found
		# square from an unfound one, and darker still was the user's "way too dark".
		slot.self_modulate = KNOWN_SOCKET
		icon.modulate = SHADOW
		if _grey == null:
			_grey = ShaderMaterial.new()
			_grey.shader = GREY
		icon.material = _grey
		return slot
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	icon.modulate = Color.BLACK
	return slot


## A piece drawn as `mark` alone at the mark's own size, with no socket, ring or corner marks: the skill
## tree's small stones (`SkillTreeView`). In `GROUP` like any square, so the card writes it and the hand
## shows over it. The tree's root is no piece: with no `item`, `says` is what its card writes (`hint`).
static func bare(item: Item, mark: Texture2D, says := Callable()) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.item = item
	slot.hint = says
	slot.add_to_group(GROUP)
	slot.custom_minimum_size = mark.get_size()
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if item != null:
		slot.tooltip_text = item.display_name()
	slot.add_child(_picture(mark))
	return slot


## A piece promised and not yet rolled (a bounty's reward): `mark` on the socket in `rarity`'s frame,
## with `+n` on the corner if it is ascended. Not in `GROUP`, since there is no piece for the card to
## write; `label` is its tooltip. `side` is `SIDE` or half of it: at half, `ui_scale` 2 draws the icon
## and the frame at their own pixels, the way the orb tray draws 32 px orbs at 16.
static func teaser(mark: Texture2D, rarity: ItemRarity.Rarity, plus: int, label: String,
		side := SIDE) -> ItemSlot:
	var icon_side := ICON * side / SIDE
	var slot := ItemSlot.new()
	slot.custom_minimum_size = Vector2(side, side)
	var socket := ItemRarity.slot_style(rarity)
	if side != SIDE and rarity != ItemRarity.Rarity.COMMON:
		# The corners are cut back as the frame is drawn, at its scale.
		socket = socket.duplicate()
		socket.set_corner_radius_all(maxi(1, roundi(ItemRarity.FRAME_CORNER * float(side) / SIDE)))
	slot.add_theme_stylebox_override("panel", socket)
	slot.tooltip_text = label
	# Scaled: a 16 px mark is asked to stand at the icon's 32.
	var icon := _picture(mark, true)
	icon.position = Vector2(side - icon_side, side - icon_side) / 2.0
	icon.size = Vector2(icon_side, icon_side)
	slot.add_child(icon)
	var ring := ItemRarity.frame(rarity)
	if ring != null:
		var frame := _picture(ring, true)
		frame.name = FRAME_NAME
		# The art's own proportions, standing up over the square as an `ItemSlot`'s does.
		var head := ItemRarity.FRAME_HEAD * float(side) / SIDE
		frame.position.y = -head
		frame.size = Vector2(side, side + head)
		slot.add_child(frame)
	if plus > 0:
		slot.add_child(OrbSlot.count_label("+%d" % plus))
	return slot


## An empty socket on the equipment panel. `mark` is the pack's own faint drawing of what belongs
## there, for the sockets a body does not explain: which of two squares under the doll takes a ring.
static func empty(label: String, mark: Texture2D = null, selected := false, translucent := false) -> ItemSlot:
	var slot := ItemSlot.new()
	slot.custom_minimum_size = Vector2(SIDE, SIDE)
	slot.add_theme_stylebox_override("panel",
			ItemRarity.slot_style(ItemRarity.Rarity.COMMON, selected, translucent))
	slot.tooltip_text = label
	if mark != null:
		var icon := _picture(mark)
		# Dimmed, not drawn in another colour: anything solid enough to read as an item is too solid.
		icon.modulate = Color(1, 1, 1, EMPTY_MARK_ALPHA)
		icon.position = (Vector2(SIDE, SIDE) - mark.get_size()) / 2.0
		slot.add_child(icon)
	return slot
