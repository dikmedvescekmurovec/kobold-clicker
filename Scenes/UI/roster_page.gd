class_name RosterPage
extends Control
## The heroes on the left edge, under a bar reading Characters: every hero of `Characters` as a square in
## one grid, the ones not bought dimmed, and beside it the picked one standing as a fight draws it, over
## its name and the one press it can take -- Buy, then Select. Buying costs nothing yet. The page saves
## what it changes and says `changed`.

const TITLE := "Characters"
## The picked hero's box beside the grid, in panel pixels: as wide as the 324 px a window held upright
## leaves beside the bag's own width, as tall as the tallest hero (the Hell Knight under his flames) at
## a fight's size, the feet `FLOOR` up from its foot.
const STAGE := Vector2(112, 132)
const FLOOR := 5.0
const GAP := 6
## The square of the hero in use wears an edge this thick, named for the tests.
const USING_EDGE := 2
const USING_NAME := "Using"

signal closed
## A hero was bought or picked, and saved: the main scene dresses the map's token and the corner in it.
signal changed

var inventory: Inventory
## Where the main scene stands the page, in window pixels: empty for the whole window.
var area := Rect2()
var _save_path: String
var _ui_scale: float
var _panel: VBoxContainer
var _grid: GridContainer
var _actor: CombatActor
var _name: Label
var _deed: Button
## The hero shown beside the grid: the one in use as the page opens.
var _picked := Characters.FIRST
var _press := Vector2.INF


func _init(player_inventory: Inventory, save_path: String, ui_scale: float) -> void:
	inventory = player_inventory
	_save_path = save_path
	_ui_scale = ui_scale
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UITheme.theme()


func _ready() -> void:
	_panel = UITheme.titled_panel(TITLE, "Close the characters", closed.emit)
	_panel.scale = Vector2(_ui_scale, _ui_scale)
	add_child(_panel)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", GAP)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UITheme.body_of(_panel).add_child(columns)
	var scroll := UITheme.scroll()
	columns.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = BagPage.GRID_COLS
	_grid.add_theme_constant_override("h_separation", BagPage.SLOT_GAP)
	_grid.add_theme_constant_override("v_separation", BagPage.SLOT_GAP)
	# Pass, not stop: the scroll under it has to see a finger's drag (`_on_grid_input`).
	_grid.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid.gui_input.connect(_on_grid_input)
	Cursors.wear(_grid, Cursors.HAND)
	scroll.add_child(_grid)
	var side := UITheme.vbox(GAP, STAGE.x)
	columns.add_child(side)
	var stage := Panel.new()
	stage.add_theme_stylebox_override("panel", BountyList.flat(Palette.SLOT_TAN, 0))
	stage.custom_minimum_size = STAGE
	stage.clip_contents = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(stage)
	# The fight's own fighter, so the page draws what a fight will. A container leaves a Node2D where it is put.
	_actor = CombatActor.new()
	_actor.position = Vector2(STAGE.x / 2.0, STAGE.y - FLOOR)
	stage.add_child(_actor)
	_name = UITheme.label()
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# A wrapping label with no width wraps at nothing on its first pass, and the page stood taller than
	# the window until it was laid out again.
	_name.custom_minimum_size.x = STAGE.x
	side.add_child(_name)
	var air := Control.new()
	air.size_flags_vertical = Control.SIZE_EXPAND_FILL
	air.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.add_child(air)
	_deed = UITheme.button("Buy", UITheme.GO_BUTTON, "")
	_deed.pressed.connect(_on_deed_pressed)
	side.add_child(_deed)
	open()


## Redraws the page from the inventory, the hero in use the one shown.
func open() -> void:
	pick(inventory.character)


## Shows the hero `id` beside the grid, with what can be done about it.
func pick(id: String) -> void:
	_picked = id
	UITheme.clear(_grid)
	for hero: String in Characters.ids():
		_grid.add_child(_square(hero))
	_actor.setup_player(_fight_tall(), 1.0, id)
	_name.text = Characters.name_of(id)
	var using := id == inventory.character
	_deed.text = "Select" if inventory.owns(id) else "Buy"
	_deed.disabled = using
	_deed.tooltip_text = "In use" if using else ""
	if is_inside_tree():
		layout()


## Full window height against the left edge, where the other pages stand.
func layout() -> void:
	UITheme.dock(_panel, area, _ui_scale, UITheme.Dock.LEFT, layout)


## A fight's fighter in backdrop pixels (`CombatScene._actor_height` of its 216 px tall view).
static func _fight_tall() -> float:
	return 216.0 * CombatScene.ACTOR_HEIGHT / CombatScene.BACKDROP_BLEED


## One hero's square: the map badge's picture at its own pixels, dimmed until the hero is bought, the
## socket darkened under the one shown and edged round the one in use.
func _square(id: String) -> ItemSlot:
	var face: Texture2D = load(Characters.path(id, "badge"))
	var square := ItemSlot.teaser(face, ItemRarity.Rarity.COMMON, 0, Characters.name_of(id))
	square.name = id
	if id == _picked:
		square.add_theme_stylebox_override("panel", ItemRarity.slot_style(ItemRarity.Rarity.COMMON, true))
	var icon := square.get_child(0) as TextureRect
	icon.size = face.get_size()
	icon.position = (square.custom_minimum_size - icon.size) / 2.0
	if not inventory.owns(id):
		icon.modulate = OrbSlot.DIM
	if id == inventory.character:
		var edge := StyleBoxFlat.new()
		edge.draw_center = false
		edge.set_border_width_all(USING_EDGE)
		edge.border_color = Palette.LEAF
		edge.anti_aliasing = false
		var mark := Panel.new()
		mark.name = USING_NAME
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_theme_stylebox_override("panel", edge)
		mark.set_anchors_preset(Control.PRESET_FULL_RECT)
		square.add_child(mark)
	return square


## A press on the grid, whose squares take no mouse. It counts as it lets go, and not one that travelled:
## the grid is longer than the page, and under a finger a drag is how it is scrolled.
func _on_grid_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or press.button_index != MOUSE_BUTTON_LEFT:
		return
	if press.pressed:
		_press = press.global_position
		return
	var travelled := press.global_position.distance_to(_press) / _ui_scale
	_press = Vector2.INF
	if travelled >= (Cursors.TOUCH_SLOP if Cursors.touched else BagPage.DRAG_THRESHOLD):
		return
	for square: Control in _grid.get_children():
		if square.get_global_rect().has_point(press.global_position):
			_grid.accept_event()  # Before the redraw frees it, which would let the release through to the map.
			pick(String(square.name))
			return


## Buys the hero shown, or once bought makes it the one the player is.
func _on_deed_pressed() -> void:
	var owned := inventory.owns(_picked)
	if not (inventory.use_character(_picked) if owned else inventory.buy_character(_picked)):
		return
	if not _save_path.is_empty():
		inventory.save(_save_path)
	print("%s %s" % ["Now playing as" if owned else "Bought", Characters.name_of(_picked)])
	pick(_picked)
	changed.emit()
