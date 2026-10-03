class_name SkillsPage
extends Control
## The skills page against the left edge: the free points over the three trees side by side, each with
## a Reset that buys its points back for gold, and a card beside the skill under the cursor,
## placed as `ItemCard` is. A press held on a skill keeps putting points in until it is let go or the
## skill refuses one. Showing or hiding this node opens or closes the whole page.
##
## The point that fills the last tree bursts them all (`Skills.burst`), and the page plays it: every
## skill glints as a unique does, trembles harder and harder as if something were building inside it,
## pops, and lies black, and then the fresh trees come up out of the black. It is played whenever the
## page is up over full trees, so a game shut mid-burst plays it again rather than losing it.

## The page's X was pressed.
signal closed
## Redrawn, and the points to spend may have moved with it.
signal changed

## The gap between the trees, in panel pixels.
const TREE_GAP := 20
## How long a press on a skill is held before points go in by themselves, and then the gap between
## them: it starts at `HOLD_FIRST` and shrinks by `HOLD_SPEEDUP` a point down to `HOLD_FASTEST`, so a
## few points can still be counted out by hand and a long hold runs (twelve a second after about two seconds).
const HOLD_DELAY := 0.4
const HOLD_FIRST := 0.3
const HOLD_SPEEDUP := 0.85
const HOLD_FASTEST := 0.08
## The burst, in seconds: glinting alone, then trembling (up to `BURST_SHAKE_MOST` panel pixels, and
## warming towards `BURST_HEAT`), the pop (swelling to `BURST_POP_SCALE` and back while going black),
## lying black, and the new trees rising out of it.
const BURST_GLINT := 2.0
const BURST_GLINT_PERIOD := 1.0
const BURST_SHAKE := 1.6
const BURST_SHAKE_MOST := 3.0
const BURST_HEAT := Color(1.6, 1.4, 1.1)
const BURST_POP := 0.15
const BURST_POP_SCALE := 1.4
const BURST_DARK := 0.8
const BURST_RISE := 0.6

var inventory: Inventory
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _points: Label
## The trees, as many to a row as the page's room takes: all three across a monitor, fewer in a window
## too narrow for them. Held upright they stand one at a time instead (`_switcher`).
var _trees: HFlowContainer
var _scroll: ScrollContainer
## Held upright (`UITheme.narrow`): the arrows either side of the name of the one tree up, `_shown`,
## which stand in for the scroll three trees would need -- the user's call: scrolling trees felt off.
var _switcher: HBoxContainer
var _shown_name: Label
var _shown := 0
var _skill_views := {}
var _respec_buttons := {}
var _card: SkillCard
## The skill a held press is putting points into, "" while none is. Held here and not on the slot,
## because every point redraws the tree and frees the slot that was pressed.
var _held := ""
## Under a finger (`Cursors.touched`): the skill whose card a tap has put up, which the next tap learns.
var _read := ""
var _hold_timer: Timer
var _hold_gap := HOLD_FIRST
## While the trees are bursting, and nothing on the page may be pressed.
var _bursting := false


func _init(player_inventory: Inventory, save_path: String, ui_scale: float) -> void:
	inventory = player_inventory
	_save_path = save_path
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel("Skills", "Close the skills panel", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var rows := UITheme.body_of(_panel)
	_points = UITheme.label()
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(_points)
	# The previous tree's arrow, the name, the next's: the item generator's stepper.
	_switcher = HBoxContainer.new()
	for step: int in [-1, 1]:
		var turn := UITheme.button("", "BrownIconButton", "Previous tree" if step < 0 else "Next tree")
		turn.icon = load(BagPage.HIDE_ICON if step < 0 else BagPage.SHOW_ICON)
		turn.pressed.connect(_turn.bind(step))
		_switcher.add_child(turn)
	_shown_name = UITheme.label()
	_shown_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shown_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_switcher.add_child(_shown_name)
	_switcher.move_child(_shown_name, 1)
	_switcher.hide()
	rows.add_child(_switcher)

	# Scrolled under the points, which stay pinned: the trees fit a 648 px window and no more.
	# Padded by what a skill draws past its square (the ring, the count), which the scroll would clip.
	_scroll = UITheme.scroll()
	rows.add_child(_scroll)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", SkillSlot.RING)
	pad.add_theme_constant_override("margin_right", SkillSlot.COUNT_OVERHANG)
	# Across the page, which a long points line can make wider than a tree, so the tree centres in it.
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.add_child(pad)
	_trees = HFlowContainer.new()
	# Centred, one tree or three, in a page as wide as a phone held upright.
	_trees.alignment = FlowContainer.ALIGNMENT_CENTER
	_trees.add_theme_constant_override("h_separation", TREE_GAP)
	_trees.add_theme_constant_override("v_separation", TREE_GAP)
	pad.add_child(_trees)
	for tree: String in SkillTree.trees():
		var column := UITheme.vbox(4)
		_trees.add_child(column)
		var name_label := UITheme.label(SkillTree.TREES[tree]["label"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var view := SkillTreeView.new()
		view.node_pressed.connect(_on_skill_pressed)
		view.node_hovered.connect(_on_skill_hovered)
		view.node_unhovered.connect(func() -> void:
			_read = ""
			_hide_card())
		column.add_child(view)
		_skill_views[tree] = view
		# Small, so the widest figure BigNumber writes still leaves it narrower than the tree: wider, it
		# widened the column and wrapped a tree onto the next row as the price grew under a held press.
		var reset := UITheme.priced_button("Reset", 0.0, "SmallButton",
				"Take back every point in %s, for gold" % name_label.text)
		reset.pressed.connect(_on_respec_pressed.bind(tree))
		column.add_child(reset)
		_respec_buttons[tree] = reset

	_hold_timer = Timer.new()
	_hold_timer.timeout.connect(_on_hold_tick)
	add_child(_hold_timer)
	visibility_changed.connect(_stop_holding)

	# Last, so it draws over the page.
	_card = SkillCard.new()
	_card.scale = Vector2(_ui_scale, _ui_scale)
	_card.hide()
	add_child(_card)
	open()


## Redraws the page from the inventory: levels and gold both move while it is shut.
func open() -> void:
	# Shut and opened again mid-burst: the burst is still playing on these very slots.
	if _bursting:
		return
	changed.emit()
	var free := inventory.skills.points(inventory.level)
	_points.text = "%d skill point%s" % [free, "" if free == 1 else "s"]
	if inventory.skills.bursts > 0:
		_points.text += ", %d per rank" % inventory.skills.rank_cost()
	_points.add_theme_color_override("font_color", Palette.LEAF if free > 0 else Palette.TEXT_SOFT)
	for tree: String in _skill_views:
		_skill_views[tree].fill(tree, inventory.skills.ranks)
		var reset: Button = _respec_buttons[tree]
		var spent := inventory.skills.spent(tree)
		var cost := inventory.respec_cost(tree)
		UITheme.set_price(reset, cost if spent > 0 else 0.0)
		reset.disabled = spent <= 0 or inventory.gold < cost
	# Whatever the cursor was over has just been redrawn.
	_hide_card()
	# Deferred, so a page opened over full trees is up before they burst.
	if inventory.skills.can_burst() and not _bursting:
		_burst.call_deferred()


## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()


## Full window height against the left edge.
func layout() -> void:
	# Held upright one tree stands at a time, named between the arrows and with nothing to scroll;
	# otherwise every tree, wrapping at what the room leaves them, and never at less than one tree.
	var narrow := UITheme.narrow(get_viewport_rect().size, _ui_scale)
	_switcher.visible = narrow
	_scroll.vertical_scroll_mode = (ScrollContainer.SCROLL_MODE_DISABLED if narrow
			else ScrollContainer.SCROLL_MODE_SHOW_NEVER)
	_shown_name.text = SkillTree.TREES[SkillTree.trees()[_shown]]["label"]
	for i in _trees.get_child_count():
		var column := _trees.get_child(i) as Control
		column.visible = not narrow or i == _shown
		# Its own name, which the switcher says in its place.
		(column.get_child(0) as Control).visible = not narrow
	_trees.custom_minimum_size.x = 0.0
	if not narrow:
		var room := area if area.has_area() else get_viewport_rect()
		var across := -float(TREE_GAP)
		for column: Control in _trees.get_children():
			across += column.get_combined_minimum_size().x + TREE_GAP
		var chrome := _panel.get_combined_minimum_size().x - _trees.get_combined_minimum_size().x
		_trees.custom_minimum_size.x = minf(across, room.size.x / _ui_scale - 2 * UITheme.EDGE - chrome)
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)


## An arrow beside the tree's name: the next tree round, or the one before.
func _turn(step: int) -> void:
	_shown = posmod(_shown + step, _trees.get_child_count())
	_hide_card()
	layout()


## One point into a skill. A refused press does nothing: the card already says why.
func _on_skill_pressed(id: String) -> void:
	# A finger has no hover: its first tap on a skill is what puts the card up, and the next learns it.
	if Cursors.touched and _read != id:
		_read = id
		return
	if _bursting or not inventory.rank_up_skill(id):
		return
	inventory.save(_save_path)
	print("Learned %s (%d/%d)" % [SkillTree.node(id)["name"], inventory.skills.rank_of(id),
			SkillTree.node(id)["max_rank"]])
	open()
	_held = id
	_hold_gap = HOLD_FIRST
	_hold_timer.start(HOLD_DELAY)


## Another point into the held skill, saved once the press ends rather than every tick.
func _on_hold_tick() -> void:
	if not inventory.rank_up_skill(_held):
		_stop_holding()
		return
	_hold_timer.start(_hold_gap)
	_hold_gap = maxf(_hold_gap * HOLD_SPEEDUP, HOLD_FASTEST)
	open()


## A release anywhere ends the hold: the slot pressed is gone, so it cannot be the one to hear it.
func _input(event: InputEvent) -> void:
	if not _held.is_empty() and event is InputEventMouseButton 			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_stop_holding()


func _stop_holding() -> void:
	_hold_timer.stop()
	if _held.is_empty():
		return
	print("Held %s to %d" % [SkillTree.node(_held)["name"], inventory.skills.rank_of(_held)])
	_held = ""
	inventory.save(_save_path)


func _on_respec_pressed(tree: String) -> void:
	var cost := inventory.respec_cost(tree)
	if not inventory.respec(tree):
		return
	inventory.save(_save_path)
	print("Reset %s for %s gold" % [tree, BigNumber.format(cost)])
	open()


## Every tree full: the burst played over them, and then `_burn` does it. Nothing while the page is
## shut -- opening it is what plays it.
func _burst() -> void:
	if _bursting or not is_visible_in_tree() or not inventory.skills.can_burst():
		return
	_bursting = true
	_stop_holding()
	_hide_card()
	for tree: String in _respec_buttons:
		_respec_buttons[tree].disabled = true
	if Settings.animations == Settings.Anim.NONE:
		_burn()
		return
	var slots: Array[SkillSlot] = []
	for tree: String in _skill_views:
		for slot: SkillSlot in _skill_views[tree].get_children():
			slots.append(slot)
			slot.glint(BURST_GLINT_PERIOD)
			slot.pivot_offset = slot.size / 2.0
	var tween := create_tween()
	tween.tween_interval(BURST_GLINT)
	tween.tween_method(_tremble.bind(slots), 0.0, 1.0, BURST_SHAKE)
	tween.tween_callback(_pop.bind(slots))
	tween.tween_interval(BURST_POP + BURST_DARK)
	tween.tween_callback(_burn)


## The pressure building, `at` 0 to 1: each skill a whole number of pixels off its place, further and
## hotter as it grows.
func _tremble(at: float, slots: Array[SkillSlot]) -> void:
	for slot in slots:
		var push := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * BURST_SHAKE_MOST * at * at
		slot.position = SkillTreeView.corner_of(slot.id) + push.round()
		slot.modulate = Color.WHITE.lerp(BURST_HEAT, at)


## Every skill swells, sparks and goes black, and the lines between them with it.
func _pop(slots: Array[SkillSlot]) -> void:
	for slot in slots:
		slot.position = SkillTreeView.corner_of(slot.id)
		slot.stop_glint()
		slot.scale = Vector2.ONE * BURST_POP_SCALE
		var pop := slot.create_tween().set_parallel()
		pop.tween_property(slot, "scale", Vector2.ONE, BURST_POP)
		pop.tween_property(slot, "modulate", Color.BLACK, BURST_POP)
		Juice.burst(slot.get_parent(), SkillTreeView.centre_of(slot.id), Palette.GOLD, 10, 90.0, 2.0, 0.5, 150.0)
	for tree: String in _skill_views:
		_skill_views[tree].create_tween().tween_property(_skill_views[tree], "self_modulate", Color.BLACK, BURST_POP)


## The burst itself: the trees burnt, saved, and drawn fresh, rising out of the black.
func _burn() -> void:
	inventory.skills.burst()
	inventory.save(_save_path)
	print("The skill trees burst (%d), a rank now %d points" % [inventory.skills.bursts, inventory.skills.rank_cost()])
	_bursting = false
	open()
	for tree: String in _skill_views:
		var view: SkillTreeView = _skill_views[tree]
		view.self_modulate = Color.WHITE
		if Settings.animations != Settings.Anim.NONE:
			view.modulate = Color.BLACK
			view.create_tween().tween_property(view, "modulate", Color.WHITE, BURST_RISE)


## Placed now and again deferred: the first pass measures labels that have not laid out yet.
func _on_skill_hovered(id: String, slot: SkillSlot) -> void:
	_card.fill(id, inventory.skills, inventory.level, inventory.skill_worth(), inventory.why_not_skill(id))
	_card.show()
	_place_card(slot.get_global_rect())
	_place_card.call_deferred(slot.get_global_rect())


func _hide_card() -> void:
	_card.hide()


## Beside the skill, the way `ItemCard` stands beside a square.
func _place_card(anchor: Rect2) -> void:
	if not _card.visible:
		return
	var card := _card.get_combined_minimum_size() * _ui_scale
	_card.position = ItemCard.beside(anchor, card, get_viewport_rect().size, ItemCard.GAP * _ui_scale)
