class_name SkillTreeView
extends Control
## The player's skill tree, drawn round its root the way the user sketched it (2026-10-08): the root in
## the middle, its branch going straight down (three, down, up-left and up-right, until the root had one
## slot), and every stone's connectors fanning out across the wedge of the circle its branch is given. A ring a tier, each wider than the
## last and pushed out further wherever its squares would touch.
##
## A stone is its base's small disc, no numeral, and a capstone its badge (`SkillTree.node_icon`, the
## user's, 2026-10-09), round the user's grey stone as the root; the slots a stone's connectors leave
## open are that grey stone small. A stone is still an item square (`ItemSlot.bare`), so the card under
## the cursor is the bag's. The squares take no mouse, for the bag's reason; this Control hears the
## presses and says which slot (`slot_pressed`). Two looks: the skills page's (`ranked`), a light behind
## whatever a point can go into, the points on the corner of a stone that holds more than one, ink lines
## into the stones learned and the stones with none faded; and the black screen's, where an empty slot
## wears the tier its depth asks and a stone in the hand rings the slots it may go in and fades the rest.
## Faded, never darkened, so a stone keeps its base's colour (the review of 2026-10-09). The skills
## page's light is the user's (2026-10-10, in place of the gold ring it had): grey behind the root, its
## base's colour behind a stone (`_light`, `glow_of`), the root's breathing until the player's first
## point ever is spent (`teaching`, the tree's tutorial) -- and a point going in flashes its node's card
## in the same colour (`SkillsPage.learned`), so the root has a card of its own too (`_write_root`), not
## a tooltip.
##
## Everything stands on `_canvas`, which `fit` scales down by whole window pixels when the tree is
## bigger than the room it has, so the squares stay as sharp as the rest of the game -- but for the words
## on the corners, which stand over it in `_marks` at the page's own size whatever the tree is drawn at. The player zooms it
## the same whole steps (the user's, 2026-10-09): the wheel and a trackpad's pinch about the point under
## the cursor, as the map does, and `zoom_buttons` about the middle; a tree bigger than its box is
## dragged about, so a press on a square counts when it lets go without having moved.

## A press on a stone or an empty slot, by path (`SkillTree`); never the root.
signal slot_pressed(path: String)
## The player zoomed: the page gives the tree its new room (`fit` keeps `zoom`).
signal zoomed
## A press held on the skills page has let go after pressing at least once (`repeating`).
signal hold_ended

## The most of the circle a branch off the root is given: the third each had when the root had three
## slots, so a lone branch hangs below the root and none of its lines cross it.
const BRANCH_WEDGE := TAU / 3.0
## The air left between any two slots, in the tree's pixels.
const GAP := 10
## The line between a stone and what hangs off it.
const LINE := 2
## How far a square's light, its ring and its count reach past it, kept clear round the edge (`TEACH_REACH`:
## the scroll the tree stands in would cut the outermost lights off).
const MARGIN := 8
## A slot standing back: an empty one, and on the black screen whatever the stone in the hand cannot go
## in, the root too. The lines stop at a slot's edge, so none shows through.
const FAINT := Color(1, 1, 1, 0.45)
## A stone on the skills page holding no point yet: back, but less than an empty slot, so its base's
## colour still tells it from one at the smallest the tree is drawn.
const UNLEARNED := Color(1, 1, 1, 0.7)
## The ring round a slot the stone in the hand can go into on the black screen, empty or taking the place
## of the stone there, drawn a pixel clear of it. The skills page wore it round whatever a point could go
## into until 2026-10-10, when the user took it off for the light alone.
const RING := Palette.GOLD
const RING_GAP := 1.5
## The tier a depth asks of the stone put there, on each empty slot the stone in the hand is too shallow
## for: the numerals the bag's carved stones wear, so a "II" in the hand reads against the "III" it cannot
## take. Never on a placed stone, where it would only crowd the tree.
const NUMERALS := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX"]
## The closest zoom, in window pixels a tree pixel for every step of `ui_scale`: 2 is twice the page's own.
const ZOOM_MOST := 2
## How far a trackpad's two fingers spread (or close, by its inverse) to step the zoom once: the map's.
const PINCH_STEP := 1.3
## A press held still on the skills page presses again and again (the user's ask, 2026-10-09): the first
## after `HOLD_DELAY` seconds, each after that `HOLD_SPEEDUP` of the wait before, down to `HOLD_FASTEST`.
const HOLD_DELAY := 0.4
const HOLD_SPEEDUP := 0.85
const HOLD_FASTEST := 0.03
## The light behind a slot a point can go into on the skills page, and behind its card as one goes in
## (`glow_of`): a stone's base's colour, and grey for the root -- white was not seen on the cream (the
## user's, 2026-10-10). ENDESGA 64's middle grey: the paler `STONE_LT` was as hard to see as the white,
## and `SLATE` read as a shadow.
const GLOWS := {"strength": Palette.BRICK_LT, "dexterity": Palette.LEAF_LT, "intelligence": Palette.ICE}
const ROOT_GLOW := Color("858585")
const NODE_GLOW := preload("res://Scenes/UI/node_glow.gdshader")
## How solid a slot's light is against its edge, and how far past the slot it falls away, in tree pixels:
## a small mark, only to tell what a point can go into from what it cannot (the user's, 2026-10-10).
const GLOW_ALPHA := 0.7
const GLOW_REACH := 5.0
## The root's light while it shows a new player where their first point goes (`teaching`): how solid, how
## far, and how much of it breathes away and back.
const TEACH_ALPHA := 0.9
const TEACH_REACH := 8.0
const TEACH_PULSE := 0.7

## Window pixels a tree pixel the player has zoomed to, or 0 for `fit`'s own choice. Kept across redraws.
var zoom := 0

## The slots drawn, path -> Control: an `ItemSlot` for a stone and the root, the bare mark for an empty slot.
var squares := {}
## Whether the root's light is the tutorial's, strong and breathing: the skills page's, until the
## player's first point ever is spent (`Inventory.FIRST_POINT`). Set before `fill`.
var teaching := false
## The skills page's lights, path -> Polygon2D, one behind the root and each stone, shown by `fill`.
var _lights := {}
var _canvas: Control
## Over the canvas and never scaled with it: the words on the slots' corners (`_mark_corner`).
var _marks: Control
var _skills: Skills
var _ranked := true
## The skill points to spend, which decide where the skills page's lights go.
var _points := 0
## The paths something can go into: lit on the skills page (`_lights`), ringed on the black screen (`RING`).
var _rings: Array[String] = []
## Path -> the centre of its square, the root's at the origin.
var _centres := {}
## What the squares were built for: the root's slots and the stones, path -> Item (`fill`).
var _shape := []
## Where the origin stands on the canvas.
var _origin := Vector2.ZERO
var _ui_scale := 1.0
## A press: where it went down, and how far it has moved since (a drag past `BagPage.DRAG_THRESHOLD`
## pans, and lets go as no press at all).
var _press_at := Vector2.INF
var _dragged := 0.0
## A trackpad's pinch gathered since its last step.
var _magnified := 1.0
## Seconds until a held press presses again, INF while none is held, and the wait it was last given.
var _hold_left := INF
var _hold_every := HOLD_DELAY
## Whether the press held down has pressed already, so letting go presses nothing more.
var repeating := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_tree)
	add_child(_canvas)
	_marks = Control.new()
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)
	# The whole of whatever box it stands in, the tree centred in it (`_centre`).
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	resized.connect(_centre)


## Draws `skills`' tree: `ranked` the skills page's look, with `points` to spend, otherwise the black
## screen's, where `held` (a stone in the hand, or null) rings the slots it may go in.
func fill(skills: Skills, ranked := true, held: Item = null, points := 0) -> void:
	_skills = skills
	_ranked = ranked
	_points = points
	UITheme.clear(_marks)
	_rings = []
	# A point spent moves neither the root's slots nor what stands in them, so it only re-dresses the
	# squares: building hundreds again on every point of a held press is what made a grown tree crawl.
	var shape := [SkillTree.root_slots, skills.stones.duplicate()]
	if shape != _shape:
		_shape = shape
		_build()
	for path: String in squares:
		var square: Control = squares[path]
		square.modulate = Color.WHITE
		_dress(square, path, skills.stones.get(path), held)
	# The skills page's lights, up behind whatever a point can go into. The root's is the tree's tutorial:
	# strong and breathing until a new player's first point is spent (still where nothing is to move), and
	# the same small mark as any other after.
	for path: String in _lights:
		(_lights[path] as Polygon2D).hide()
	for path: String in _rings:
		if _lights.has(path):
			(_lights[path] as Polygon2D).show()
	if _lights.has(""):
		var glow := (_lights[""] as Polygon2D).material as ShaderMaterial
		glow.set_shader_parameter("colour", Color(ROOT_GLOW, TEACH_ALPHA if teaching else GLOW_ALPHA))
		glow.set_shader_parameter("reach", TEACH_REACH if teaching else GLOW_REACH)
		glow.set_shader_parameter("pulse",
				TEACH_PULSE if teaching and Settings.animations != Settings.Anim.NONE else 0.0)
	_canvas.queue_redraw()
	_scaled(_canvas.scale.x)


func _build() -> void:
	UITheme.clear(_canvas)
	squares = {}
	_lights = {}
	_centres = _layout(_skills.stones)
	var low := Vector2.INF
	var high := -Vector2.INF
	for path: String in _centres:
		var half := Vector2.ONE * _side(path, _skills.stones) / 2.0
		low = low.min(_centres[path] - half)
		high = high.max(_centres[path] + half)
	_origin = Vector2.ONE * MARGIN - low
	_canvas.size = high - low + Vector2.ONE * MARGIN * 2.0
	for path: String in _centres:
		var square := _square(path)
		square.position = (_origin + _centres[path] - Vector2.ONE * _side(path, _skills.stones) / 2.0).round()
		_canvas.add_child(square)
		squares[path] = square
		# Only what takes a point has a light, and only the skills page spends them.
		if _ranked and square is ItemSlot:
			_lights[path] = _light(path, square)
			_canvas.add_child(_lights[path])


func _square(path: String) -> Control:
	var stone: Item = _skills.stones.get(path)
	var mark := _mark(path, _skills.stones)
	var square: Control
	if stone != null or path.is_empty():
		square = ItemSlot.bare(stone, mark, Callable() if stone != null else _write_root)
		# A press here is a point, read on the card it is under.
		if _ranked:
			square.set_meta(ItemCard.STAYS, true)
	else:
		square = TextureRect.new()
		(square as TextureRect).texture = mark
		square.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return square


## A slot's look. The black screen's: with a stone in the hand, a ring where it may go and everything
## else faint, the empty slots too deep for it wearing the tier they ask; with none, the empty slots faint. The skills page's: a light
## where a point may go, the root included (`_rings`, lit by `fill`), an empty slot faint and a stone holding no point less so,
## and on a corner the points in it -- a stone's only where it can hold more than one, the root's once
## it holds any.
func _dress(square: Control, path: String, stone: Item, held: Item) -> void:
	var empty := stone == null and not path.is_empty()
	if not _ranked:
		if held != null and SkillTree.can_place(held, path, _skills.stones):
			_rings.append(path)
		elif held != null or empty:
			square.modulate = FAINT
		# Every slot there is that a stone cannot take is one too deep for it.
		var depth := SkillTree.depth_of(path)
		if held != null and empty and not path in _rings and depth <= NUMERALS.size():
			_mark_corner(path, NUMERALS[depth - 1])
		return
	if empty:
		square.modulate = FAINT
		return
	var rank := _skills.rank_of(path)
	if SkillTree.can_rank(path, _skills.stones, _skills.ranks, _points):
		_rings.append(path)
	if path.is_empty():
		if rank > 0:
			_mark_corner(path, str(rank))
		return
	if rank == 0:
		square.modulate = UNLEARNED
	var most := SkillTree.most_ranks(stone)
	if most > 1:
		_mark_corner(path, "%d/%d" % [rank, most])


## The light behind the slot at `path`, hidden until `fill` says a point can go in: `node_glow.gdshader`
## in the slot's colour, hugging a disc's art (a pixel inside its square) or a capstone's badge, and
## drawn behind the lines and the squares.
func _light(path: String, square: Control) -> Polygon2D:
	var inset := 0.0 if _is_badge(path) else 1.0
	var card := square.custom_minimum_size - Vector2.ONE * inset * 2.0
	var glow := ShaderMaterial.new()
	glow.shader = NODE_GLOW
	glow.set_shader_parameter("colour", Color(glow_of(_skills.stones.get(path)), GLOW_ALPHA))
	glow.set_shader_parameter("box", card)
	glow.set_shader_parameter("corner", 0.0 if _is_badge(path) else card.x / 2.0)
	glow.set_shader_parameter("reach", GLOW_REACH)
	var light := Polygon2D.new()
	# As far as the strongest light gets, the root's while it teaches.
	var box := Rect2(Vector2.ZERO, card).grow(TEACH_REACH)
	light.polygon = PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end,
			Vector2(box.position.x, box.end.y)])
	light.material = glow
	light.position = square.position + Vector2.ONE * inset
	light.show_behind_parent = true
	light.hide()
	return light


## The colour a slot is lit in, and its card as a point goes into it: grey for the root, which is no
## stone, and a stone's base's.
static func glow_of(stone: Item) -> Color:
	return ROOT_GLOW if stone == null else GLOWS[SkillTree.base_of(stone)]


## `text` hung off the corner of the slot at `path` the way an orb's count is, in `_marks`: at the
## page's size however small the tree is drawn, and never faded with the slot. Placed by `_place_marks`.
func _mark_corner(path: String, text: String) -> void:
	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_meta("path", path)
	var words := OrbSlot.count_label(text)
	# Wider than a small slot, it grows off the corner it is aligned to rather than away from it.
	words.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	words.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.add_child(words)
	_marks.add_child(holder)


func _place_marks() -> void:
	for holder: Control in _marks.get_children():
		var square: Control = squares[holder.get_meta("path")]
		holder.position = _canvas.position + square.position * _canvas.scale
		holder.size = square.get_combined_minimum_size() * _canvas.scale


## What stands at `path`: the root's grey stone, a placed stone's node (`SkillTree.node_icon`), or the
## grey stone small where nothing is placed yet.
static func _mark(path: String, stones: Dictionary) -> Texture2D:
	if path.is_empty():
		return SkillTree.icon("root")
	return SkillTree.node_icon(stones[path]) if stones.has(path) else SkillTree.icon(SkillTree.EMPTY_NODE)


## How wide the slot at `path` is drawn: its mark's own size, every one of them square.
static func _side(path: String, stones: Dictionary) -> float:
	return _mark(path, stones).get_width()


## Every slot to draw -- the root's, and under each stone its connectors -- placed round the root:
## path -> its centre. A slot's children split its wedge by the slots at the ends of what hangs off each
## (`leaves`), so a long arm takes the room it needs and a deep tree grows as wide as its ends, not
## three times wider a ring; the root's have a share of the circle each, `BRANCH_WEDGE` at the most, the
## first straight down. Each ring stands a gap past the last, and further where two slots side by side on
## it would come within a gap, each as far round as it is drawn (`_room`). Worked out, never searched
## for: a tree of hundreds of stones took seconds pushed out two pixels at a time (2026-10-09).
static func _layout(stones: Dictionary) -> Dictionary:
	# Every slot, shallowest first, which is round each ring in turn.
	var order := [""]
	var children := {}
	var next := 0
	while next < order.size():
		var path: String = order[next]
		children[path] = range(SkillTree.connectors_of(path, stones)).map(
				func(i: int) -> String: return SkillTree.child_of(path, i))
		order.append_array(children[path])
		next += 1
	var leaves := {}
	for i in range(order.size() - 1, -1, -1):
		var path: String = order[i]
		leaves[path] = maxi(1, children[path].reduce(
				func(sum: int, child: String) -> int: return sum + leaves[child], 0))
	var angle := {"": PI / 2.0}
	var wedge := {"": TAU}
	var rings: Array = [[]]
	for path: String in order:
		var count: int = children[path].size()
		var from := float(angle[path]) - float(wedge[path]) / 2.0
		for i in count:
			var child: String = children[path][i]
			if path.is_empty():
				wedge[child] = minf(TAU / count, BRANCH_WEDGE)
				angle[child] = PI / 2.0 + i * float(wedge[child])
			else:
				wedge[child] = float(wedge[path]) * leaves[child] / leaves[path]
				angle[child] = from + float(wedge[child]) / 2.0
				from += float(wedge[child])
			var depth := SkillTree.depth_of(child)
			if rings.size() <= depth:
				rings.append([])
			rings[depth].append(child)
	var centres := {"": Vector2.ZERO}
	var radius := 0.0
	var room_before := _room("", stones)
	for depth in range(1, rings.size()):
		var ring: Array = rings[depth]
		var room: float = ring.map(func(path: String) -> float: return _room(path, stones)).max()
		# Clear of every slot on the ring before, wherever round it they stand...
		radius += room_before + room + GAP
		# ...and of the slots either side on its own, the last of the first the long way round.
		if ring.size() > 1:
			for i in ring.size():
				var a: String = ring[i]
				var b: String = ring[(i + 1) % ring.size()]
				var apart := fposmod(float(angle[b]) - float(angle[a]), TAU)
				radius = maxf(radius, (_room(a, stones) + _room(b, stones) + GAP) / (2.0 * sin(apart / 2.0)))
		for path: String in ring:
			centres[path] = Vector2.from_angle(angle[path]) * radius
		room_before = room
	return centres


## How far from its middle a slot needs the gap kept: a disc's half, and a capstone's square badge out to
## its corners, so no two squares' boxes meet however they line up.
static func _room(path: String, stones: Dictionary) -> float:
	var half := _side(path, stones) / 2.0
	return half * sqrt(2.0) if stones.has(path) and not (stones[path] as Item).capstone.is_empty() else half


## Under the squares: the lines, each stopping at the edges of the two slots it joins so a faint slot
## shows none through it -- on the skills page ink into a stone holding a point (gold could not be seen on
## the cream, the user's, 2026-10-09) and tan into any other,
## on the black screen ink, and faint into an empty slot on either -- then the black screen's rings.
func _draw_tree() -> void:
	for path: String in _centres:
		if path.is_empty():
			continue
		var parent := SkillTree.parent_of(path)
		var from := _at(parent)
		var to := _at(path)
		var along := (to - from).normalized()
		var colour := Palette.INK
		if _ranked:
			colour = Palette.INK if _skills.rank_of(path) > 0 and _skills.stones.has(path) else Palette.SLOT_TAN_DK
		if not _skills.stones.has(path):
			colour.a = FAINT.a
		_canvas.draw_line(from + along * _reach(parent, along), to - along * _reach(path, along), colour, LINE)
	if _ranked:
		return
	for path: String in _rings:
		var half := _side(path, _skills.stones) / 2.0 + RING_GAP
		if _is_badge(path):
			_canvas.draw_rect(Rect2(_at(path) - Vector2.ONE * half, Vector2.ONE * half * 2.0), RING, false, 1.0)
		else:
			_canvas.draw_arc(_at(path), half, 0.0, TAU, 48, RING, 1.0)


## The middle of the slot at `path` as drawn, its square's whole pixels and all.
func _at(path: String) -> Vector2:
	var square: Control = squares[path]
	return square.position + square.get_combined_minimum_size() / 2.0


## How far from a slot's middle its edge is, `along` a line: a disc's radius, less the pixel its art
## leaves clear, or a capstone's badge, which is square.
func _reach(path: String, along: Vector2) -> float:
	var half := _side(path, _skills.stones) / 2.0
	return half / maxf(absf(along.x), absf(along.y)) if _is_badge(path) else half - 1.0


func _is_badge(path: String) -> bool:
	return _skills.stones.has(path) and not (_skills.stones[path] as Item).capstone.is_empty()


## Scales the tree into `room` (the tree's parent's pixels, which are `ui_scale` window pixels each):
## its own size when it fits, else the largest whole number of window pixels a tree pixel that does,
## and at worst one, past which the page scrolls. Returns that size, which is the box the page stands
## it in: once the player has zoomed (`zoom`), it is drawn at theirs and scrolls in the same box.
func fit(room: Vector2, ui_scale: float) -> Vector2:
	_ui_scale = maxf(1.0, roundf(ui_scale))
	var pixels := int(_ui_scale)
	var room_rect := Rect2(Vector2.ZERO, room)
	while pixels > 1 and not room_rect.encloses(Rect2(Vector2.ZERO, _canvas.size * pixels / _ui_scale)):
		pixels -= 1
	var box := (_canvas.size * pixels / _ui_scale).ceil()
	_scaled((clampi(zoom, 1, _most()) if zoom > 0 else pixels) / _ui_scale)
	return box


## One whole step closer (`step` 1) or further (-1), about `at` (this Control's own pixels; the middle of
## what the scroll it stands in shows, by default), which stays where it was on screen.
func zoom_by(step: int, at := Vector2.INF) -> void:
	var now := roundi(_canvas.scale.x * _ui_scale)
	var to := clampi(now + step, 1, _most())
	if to == now:
		return
	var box := get_parent() as ScrollContainer
	if at == Vector2.INF:
		at = (box.size / 2.0 - position) if box != null else size / 2.0
	var held := (at - _canvas.position) / _canvas.scale
	var on_screen := at + position
	zoom = to
	_scaled(to / _ui_scale)
	zoomed.emit()
	if box != null:
		# Once the scroll has taken the new size in, put the point back under where it was.
		_hold_point(box, held, on_screen)


func _hold_point(box: ScrollContainer, held: Vector2, on_screen: Vector2) -> void:
	await get_tree().process_frame
	var there := _canvas.position + held * _canvas.scale - on_screen
	box.scroll_horizontal = roundi(there.x)
	box.scroll_vertical = roundi(there.y)


func _most() -> int:
	return int(_ui_scale) * ZOOM_MOST


## A − and a + for `view`, for whoever has no wheel (a finger) or wants one.
static func zoom_buttons(view: SkillTreeView) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	for step: int in [-1, 1]:
		var button := UITheme.button("-" if step < 0 else "+", "SmallButton",
				"Zoom out" if step < 0 else "Zoom in")
		button.pressed.connect(view.zoom_by.bind(step))
		row.add_child(button)
	return row


func _scaled(by: float) -> void:
	_canvas.scale = Vector2.ONE * by
	custom_minimum_size = (_canvas.size * by).ceil()
	_centre()


## In the middle of whatever box it is given, across and down, with the corners' words over it.
func _centre() -> void:
	_canvas.position = ((size - custom_minimum_size).max(Vector2.ZERO) / 2.0).floor()
	_place_marks()


func _gui_input(event: InputEvent) -> void:
	Cursors.over_squares(self, event, Cursors.holding())
	if event is InputEventMagnifyGesture:
		_magnified *= event.factor
		if absf(log(_magnified)) >= log(PINCH_STEP):
			zoom_by(int(signf(_magnified - 1.0)), event.position)
			_magnified = 1.0
		accept_event()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if event.pressed:
			zoom_by(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_press_at = event.position
			_dragged = 0.0
			# Only a point is pressed again: on the black screen a press places a stone or spends an orb.
			_hold_left = HOLD_DELAY if _ranked else INF
			_hold_every = HOLD_DELAY
		else:
			if _press_at != Vector2.INF and _dragged < _slop() and not repeating:
				_press(_press_at)
			_press_at = Vector2.INF
			_end_hold()
	elif event is InputEventMouseMotion and _press_at != Vector2.INF \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_dragged += event.relative.length()
		var box := get_parent() as ScrollContainer
		if _dragged >= _slop():
			_hold_left = INF
			if box != null:
				box.scroll_horizontal -= roundi(event.relative.x)
				box.scroll_vertical -= roundi(event.relative.y)
		accept_event()


## A press held still presses again each time its wait runs out, one press a frame at most.
func _process(delta: float) -> void:
	if _hold_left == INF:
		return
	if not is_visible_in_tree():
		_end_hold()
		return
	_hold_left -= delta
	if _hold_left <= 0.0:
		repeating = true
		_hold_every = maxf(_hold_every * HOLD_SPEEDUP, HOLD_FASTEST)
		_hold_left = _hold_every
		_press(_press_at)


func _end_hold() -> void:
	_hold_left = INF
	if repeating:
		repeating = false
		hold_ended.emit()


## How far a press may travel and still be one: a finger's slop, or the bag's threshold.
func _slop() -> float:
	return Cursors.TOUCH_SLOP if Cursors.touched else BagPage.DRAG_THRESHOLD


## The square under `at` (this Control's own pixels), pressed: the root only on the skills page, where
## it takes points.
func _press(at: Vector2) -> void:
	var path: Variant = slot_at(at)
	if path != null and (_ranked or not path.is_empty()):
		slot_pressed.emit(path)


## The path of the slot under `at` (this Control's own pixels), or null. The bag's too, for a stone
## dropped on the tree.
func slot_at(at: Vector2) -> Variant:
	var on_tree := (at - _canvas.position) / _canvas.scale
	for path: String in squares:
		var square: Control = squares[path]
		if Rect2(square.position, square.get_combined_minimum_size()).has_point(on_tree):
			return path
	return null


## The root's card, written where a stone's would be (`ItemSlot.hint`): the points in it and what they
## add up to.
func _write_root(rows: VBoxContainer, width: float) -> void:
	var rank := _skills.rank_of("")
	for text: String in ["%d point%s" % [rank, "" if rank == 1 else "s"],
			"+%d Damage" % roundi(SkillTree.ROOT_DAMAGE * rank),
			"+%d%% increased Damage" % roundi(SkillTree.ROOT_PERCENT * rank)]:
		rows.add_child(ItemDetails.line(text, Palette.TEXT, width, true))
