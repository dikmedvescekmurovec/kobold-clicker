class_name SkillsPage
extends Control
## The skills page against the left edge: the free points over the two trees side by side, each with
## a Reset that buys its points back for gold, and a card beside the page for the skill under the
## cursor. Showing or hiding this node opens or closes the whole page.

## The page's X was pressed.
signal closed

## The gap between the two trees, in panel pixels.
const TREE_GAP := 20

var inventory: Inventory
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _points: Label
var _skill_views := {}
var _respec_buttons := {}
var _card: SkillCard


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

	var trees := HBoxContainer.new()
	trees.add_theme_constant_override("separation", TREE_GAP)
	rows.add_child(trees)
	for tree: String in SkillTree.trees():
		var column := UITheme.vbox(4)
		trees.add_child(column)
		var name_label := UITheme.label(SkillTree.TREES[tree]["label"])
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(name_label)
		var view := SkillTreeView.new()
		view.node_pressed.connect(_on_skill_pressed)
		view.node_hovered.connect(_on_skill_hovered)
		view.node_unhovered.connect(_hide_card)
		column.add_child(view)
		_skill_views[tree] = view
		var reset := UITheme.button("", "LightButton", "Take back every point in %s, for gold" % name_label.text)
		reset.icon = Coins.icon()
		reset.pressed.connect(_on_respec_pressed.bind(tree))
		column.add_child(reset)
		_respec_buttons[tree] = reset

	# Last, so it draws over the page.
	_card = SkillCard.new()
	_card.scale = Vector2(_ui_scale, _ui_scale)
	_card.hide()
	add_child(_card)
	open()


## Redraws the page from the inventory: levels and gold both move while it is shut.
func open() -> void:
	var free := inventory.skills.points(inventory.level)
	_points.text = "%d skill point%s" % [free, "" if free == 1 else "s"]
	_points.add_theme_color_override("font_color", Palette.LEAF if free > 0 else Palette.SLATE)
	for tree: String in _skill_views:
		_skill_views[tree].fill(tree, inventory.skills.ranks)
		var reset: Button = _respec_buttons[tree]
		var spent := inventory.skills.spent(tree)
		var cost := inventory.respec_cost(tree)
		reset.text = "Reset %s" % BigNumber.format(cost) if spent > 0 else "Reset"
		reset.disabled = spent <= 0 or inventory.gold < cost
	# Whatever the cursor was over has just been redrawn.
	_hide_card()


## Full window height against the left edge.
func layout() -> void:
	_panel.size = Vector2(_panel.get_combined_minimum_size().x, get_viewport_rect().size.y / _ui_scale)
	_panel.position = Vector2.ZERO


## One point into a skill. A refused press does nothing: the card already says why.
func _on_skill_pressed(id: String) -> void:
	if not inventory.skills.rank_up(id, inventory.level):
		return
	inventory.save(_save_path)
	print("Learned %s (%d/%d)" % [SkillTree.node(id)["name"], inventory.skills.rank_of(id),
			SkillTree.node(id)["max_rank"]])
	open()


func _on_respec_pressed(tree: String) -> void:
	var cost := inventory.respec_cost(tree)
	if not inventory.respec(tree):
		return
	inventory.save(_save_path)
	print("Reset %s for %s gold" % [tree, BigNumber.format(cost)])
	open()


## Placed now and again deferred: the first pass measures labels that have not laid out yet.
func _on_skill_hovered(id: String, slot: SkillSlot) -> void:
	_card.fill(id, inventory.skills, inventory.level)
	_card.show()
	_place_card(slot.get_global_rect())
	_place_card.call_deferred(slot.get_global_rect())


func _hide_card() -> void:
	_card.hide()


## Beside the page, level with the skill, so the card never hides the tree it is read against.
func _place_card(anchor: Rect2) -> void:
	if not _card.visible:
		return
	var card := _card.get_combined_minimum_size() * _ui_scale
	var page_right := _panel.position.x + _panel.size.x * _ui_scale
	var spot := Vector2(page_right + BagPage.SLOT_GAP * _ui_scale, anchor.position.y)
	_card.position = spot.clamp(Vector2.ZERO, (get_viewport_rect().size - card).max(Vector2.ZERO))
