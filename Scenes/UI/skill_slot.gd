class_name SkillSlot
extends Control
## One skill in a tree: the pack's framed icon, and how many points are in it.
##
## The pack's icons carry their own square frame, so there is no tan socket behind them the way an
## item or an orb has one -- a second frame around a frame is exactly what the pack does not draw.
##
## Four states, each read at a glance across a tree of ten:
##
##   locked     -- the tree's locked mark, a padlock on its frame, greyed: nothing leads here yet
##   open       -- the icon, greyed: it can be learned, and has not been
##   learning   -- the icon in full colour, with its count
##   maxed      -- the same, ringed in gold: nothing more to put in it
##
## It takes the mouse, unlike an item square: the skills page scrolls nothing, so there is no drag to
## protect, and the square is both the click target and what the card describes.

## The icon is 16 px and drawn twice that, a whole number for the reason `zoom` is.
const ICON := 16
const SIDE := ICON * 2
## How far the count hangs off the square's bottom-right corner -- OrbSlot's reason: a 16 px numeral
## laid inside a 32 px icon covers half of it.
const COUNT_OVERHANG := 4
## An open skill with no points in it. OrbSlot's grey, so "you could, and have not" reads the same on
## both pages.
const DIM := OrbSlot.DIM
## The ring round a skill with every point in it, in panel pixels.
const RING := 2

signal pressed(id: String)
signal hovered(id: String)
signal unhovered()

var id := ""
var _maxed := false
var _icon: TextureRect


## Draws skill `which` holding `rank` points. `open` is whether anything leads to it.
func setup(which: String, rank: int, open: bool) -> void:
	id = which
	var entry := SkillTree.node(which)
	var most := int(entry["max_rank"])
	_maxed = rank >= most
	custom_minimum_size = Vector2(SIDE, SIDE)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	if open and not _maxed:
		Cursors.wear(self, Cursors.HAND)

	_icon = TextureRect.new()
	# Mode before texture and size, for the reason OrbSlot gives: a TextureRect's size is clamped to
	# its texture until `expand_mode` says otherwise.
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.texture = SkillTree.icon(which) if open else SkillTree.locked_icon(SkillTree.tree_of(which))
	_icon.custom_minimum_size = Vector2(SIDE, SIDE)
	_icon.size = Vector2(SIDE, SIDE)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Locked and open alike: only a skill with a point in it is lit, so learning one is what brings it up in colour
	# (the user's call, 2026-09-25; a locked badge left bright outshone the skills that could be taken).
	if not open or rank <= 0:
		_icon.modulate = DIM
	add_child(_icon)

	# Written on every open skill, nothing learned included: "0/5" is what says a skill holds five,
	# which is the whole of how a player tells a root from the end of a chain before spending.
	if open:
		var tally := Label.new()
		tally.theme_type_variation = "PanelLabel"
		tally.text = "%d/%d" % [rank, most]
		tally.add_theme_color_override("font_color", Palette.GOLD if _maxed else Palette.BONE)
		tally.add_theme_color_override("font_outline_color", Palette.INK)
		tally.add_theme_constant_override("outline_size", 4)
		tally.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tally.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		tally.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		tally.set_anchors_preset(Control.PRESET_FULL_RECT)
		tally.offset_left = -COUNT_OVERHANG * 2
		tally.offset_right = COUNT_OVERHANG
		tally.offset_bottom = COUNT_OVERHANG
		add_child(tally)

	mouse_entered.connect(func() -> void: hovered.emit(id))
	mouse_exited.connect(func() -> void: unhovered.emit())


## The gold ring, outside the icon's own frame so it adds to the pack's art rather than painting on it.
func _draw() -> void:
	if _maxed:
		draw_rect(Rect2(Vector2(-RING, -RING), size + Vector2(RING, RING) * 2), Palette.GOLD, false, RING)


## A press is passed on whatever state the skill is in: whether it takes a point is `Skills`' to
## decide, and a press that does nothing still leaves the card saying why.
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Accepted first: the press redraws the tree, and a slot out of the tree cannot accept, which
		# let the press through to the map under the page.
		accept_event()
		pressed.emit(id)


static func make(which: String, rank: int, open: bool) -> SkillSlot:
	var slot := SkillSlot.new()
	slot.setup(which, rank, open)
	return slot
