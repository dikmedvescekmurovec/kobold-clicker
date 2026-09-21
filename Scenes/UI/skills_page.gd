class_name SkillsPage
extends Control
## The skills page against the left edge: the free points over the three trees side by side, each with
## a Reset that buys its points back for gold, and a card beside the skill under the cursor,
## placed as `ItemCard` is. Once every tree is full, **Transcend trees** beside the points takes every point
## for good and makes every skill stronger (`Skills.transcend`); it asks by turning into "Sure?", the
## way the bounty journal's Cancel does. Showing or hiding this node opens or closes the whole page.

## The page's X was pressed.
signal closed

## The gap between the trees, in panel pixels.
const TREE_GAP := 20

var inventory: Inventory
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _points: Label
var _skill_views := {}
var _respec_buttons := {}
var _card: SkillCard
var _transcend: Button

const TRANSCEND := "Transcend trees"
const SURE := "Sure?"


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
	# The points, and beside them the way to transcend the trees: up here, because the page is as tall
	# as a 648 px window lets it be and there is no room under the resets.
	var top := HBoxContainer.new()
	rows.add_child(top)
	_points = UITheme.label()
	_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_points.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(_points)
	_transcend = UITheme.button(TRANSCEND, "WoodDangerButton", "Every skill back to nothing and every "
			+ "point spent for good. Every skill is %d%% stronger from then on, in every world"
			% roundi(SkillTree.TRANSCEND_GAIN * 100))
	_transcend.pressed.connect(_on_transcend_pressed)
	top.add_child(_transcend)

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
		var reset := UITheme.priced_button("Reset", 0.0, "LightButton",
				"Take back every point in %s, for gold" % name_label.text)
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
	var times := inventory.skills.transcended
	if times > 0:
		_points.text += ", skills +%d" % times
	_points.add_theme_color_override("font_color", Palette.LEAF if free > 0 else Palette.SLATE)
	for tree: String in _skill_views:
		_skill_views[tree].fill(tree, inventory.skills.ranks)
		var reset: Button = _respec_buttons[tree]
		var spent := inventory.skills.spent(tree)
		var cost := inventory.respec_cost(tree)
		UITheme.set_price(reset, cost if spent > 0 else 0.0)
		reset.disabled = spent <= 0 or inventory.gold < cost
	_transcend.text = TRANSCEND
	_transcend.visible = inventory.skills.can_transcend()
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


## The first press asks, the second does it.
func _on_transcend_pressed() -> void:
	if _transcend.text != SURE:
		_transcend.text = SURE
		return
	if not inventory.skills.transcend():
		return
	inventory.save(_save_path)
	print("Transcended the skill trees (%d)" % inventory.skills.transcended)
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
	_card.fill(id, inventory.skills, inventory.level, inventory.skill_worth())
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
