class_name Doll
extends Control
## The figure on the bag's sheet under its eight socket squares. It lays them out and says which is
## under a point; what a press, a drop or a held orb does to one is `BagPage`'s, which also dresses
## the squares for what is selected, held or on the cursor.

const TEXTURE := preload("res://Assets/UI/ui_doll.png")
## The figure at the item icons' own pixel size (whole scales only).
const SCALE := 1.0
## Each socket's centre in the sprite's own pixels, before `SCALE`, on one 51 px grid. The figure was
## drawn to sit under these places, so moving one means redrawing it; `test_inventory` holds the
## squares apart and on the page.
const SOCKETS := {
	Equipment.Socket.HELMET: Vector2(63, 24),
	Equipment.Socket.OFFHAND: Vector2(12, 75),
	Equipment.Socket.BODY: Vector2(63, 75),
	Equipment.Socket.WEAPON: Vector2(114, 75),
	Equipment.Socket.BOOTS: Vector2(63, 126),
	Equipment.Socket.RING_LEFT: Vector2(12, 177),
	Equipment.Socket.AMULET: Vector2(63, 177),
	Equipment.Socket.RING_RIGHT: Vector2(114, 177),
}
## The faint mark an empty jewellery socket wears; the figure explains the other sockets.
const MARKS := {
	Equipment.Socket.RING_LEFT: preload("res://Assets/UI/ui_socket_ring.png"),
	Equipment.Socket.RING_RIGHT: preload("res://Assets/UI/ui_socket_ring.png"),
	Equipment.Socket.AMULET: preload("res://Assets/UI/ui_socket_amulet.png"),
}

## Socket -> its square: an `ItemSlot` that takes no mouse and carries the socket as its "socket" meta.
var squares := {}
var _equipment: Equipment


func _init(equipment: Equipment, selected: int) -> void:
	_equipment = equipment
	var figure := TextureRect.new()
	figure.texture = TEXTURE
	figure.scale = Vector2(SCALE, SCALE)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.position = origin()
	add_child(figure)
	for socket: Equipment.Socket in SOCKETS:
		squares[socket] = _square(socket, socket == selected)
		add_child(squares[socket])
	custom_minimum_size = extent()


## The doll's size: the figure and every socket square.
static func extent() -> Vector2:
	var art: Vector2 = TEXTURE.get_size() * SCALE + origin()
	for socket: Equipment.Socket in SOCKETS:
		art = art.max(spot(socket) + Vector2(ItemSlot.SIDE, ItemSlot.SIDE))
	return art


## One socket: its piece, or its faint mark, translucent so the figure shows through.
func _square(socket: Equipment.Socket, chosen: bool) -> ItemSlot:
	var item := _equipment.item_at(socket)
	var slot: ItemSlot
	if item != null:
		slot = ItemSlot.make(item, chosen, true)
	elif socket == Equipment.Socket.OFFHAND and _equipment.two_handed_worn():
		# The hand is not empty, it is full of the weapon: the socket wears that weapon's icon as its
		# faint mark, so it reads as taken rather than as somewhere left to fill (`worn_at`).
		var weapon := _equipment.item_at(Equipment.Socket.WEAPON)
		slot = ItemSlot.empty("%s takes both hands" % weapon.display_name(), weapon.icon(), chosen, true)
	else:
		slot = ItemSlot.empty(Equipment.LABELS[socket], MARKS.get(socket), chosen, true)
	slot.position = spot(socket)
	slot.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	slot.set_meta("socket", socket)
	return slot


## How far the figure is pushed right and down so no socket hangs off the page.
static func origin() -> Vector2:
	var least := Vector2.ZERO
	for socket: Equipment.Socket in SOCKETS:
		least = least.min(_corner(socket))
	return -least


## A socket square's top-left before the figure is shifted to fit.
static func _corner(socket: Equipment.Socket) -> Vector2:
	return (SOCKETS[socket] * SCALE - Vector2(ItemSlot.SIDE, ItemSlot.SIDE) / 2.0).floor()


## A socket square's top-left on the doll.
static func spot(socket: Equipment.Socket) -> Vector2:
	return _corner(socket) + origin()


## The socket under `at` (the doll's own pixels), filled or not, or -1.
func socket_at(at: Vector2) -> int:
	for socket: int in squares:
		if Rect2(squares[socket].position, squares[socket].size).has_point(at):
			return socket
	return -1


## The socket whose piece is drawn under `at`, or -1 over an empty one or bare doll. While a two-hander
## is worn the offhand square answers for the weapon: what a square draws is what it answers for.
func worn_at(at: Vector2) -> int:
	var socket := socket_at(at)
	if socket == Equipment.Socket.OFFHAND and _equipment.two_handed_worn():
		socket = Equipment.Socket.WEAPON
	return socket if socket >= 0 and _equipment.item_at(socket) != null else -1
