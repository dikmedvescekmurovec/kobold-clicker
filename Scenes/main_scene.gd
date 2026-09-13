extends Node2D

## Seeds for the town world and the rendered map. 0 picks a random seed each run; the used seeds are printed.
@export var world_seed := 0
@export var map_seed := 0
## World spot shown at the map's center cell (0, 0), which is the middle of the screen. The row must be even.
@export var map_origin := Vector2i(128, 128)
## Whole-number pixel zoom, so sprite pixels stay square: 3 draws every sprite pixel as 3x3 on screen.
@export var zoom := 3.0
## The same for the UI panel. Pixellari only renders cleanly at its native 16 px, so the way to make
## the interface smaller is to draw its pixels smaller, not to shrink the font.
@export var ui_scale := 2.0
## Where the collection log is kept. The tests and the screenshot scripts point this somewhere else
## before the scene enters the tree, so they never read or overwrite the player's own inventory.
@export var inventory_path := Inventory.SAVE_PATH

## Side of the terrain swatch shown next to each environment percentage, in sprite pixels.
const ENV_ICON := 16
const ENV_ICON_SIZE := Vector2i(ENV_ICON, ENV_ICON)
## The item grid: four squares to a row with a little air between them. ItemSlot decides how big a
## square is; this is only how they are laid out. The gutter is the UI pack's own proportion -- it
## lays its slots out seven parts square to one part gutter -- so the grid reads as the pack's even
## though the square is sized by the gear art rather than by the pack.
const GRID_COLS := 4
const SLOT_GAP := ItemSlot.SIDE / 7
## How far a press may travel and still count as a click rather than a drag of the list. In panel
## pixels, so half what it would be on screen at ui_scale 2 -- the same rule HexMap uses to tell a
## pan from a tile click.
const BAG_DRAG_THRESHOLD := 4.0

var towns: TownWorld
var view: MapBuilder
## Everything the player has picked up, loaded from `inventory_path` and written back as it grows.
var inventory: Inventory

@onready var map: HexMap = $HexMap
@onready var camera: Camera2D = $Camera2D

var _discover_button: Button
var _move_button: Button
var _env_rows: VBoxContainer
var _panel: VBoxContainer
## The left-hand collection log, the button that opens it, and the rows inside it.
var _bag_panel: VBoxContainer
var _bag_button: Button

var _bag_scroll: ScrollContainer
var _bag_grid: GridContainer
var _bag_detail: VBoxContainer
## Which item's stat block is open, as an index into the inventory, or -1 for none. Kept across a
## refresh so a drop landing while it is open does not slam it shut.
var _bag_selected := -1
## Where a press on the grid started and how far it has travelled since.
var _bag_drag_from := Vector2.ZERO
var _bag_drag_scroll := 0
var _bag_dragged := 0.0
## What the fight in front of the map has turned up so far, for the line printed when it ends.
var _fight_drops: Array[Item] = []
## The fight in front of the map, while there is one.
var _combat: CombatScene


func _ready() -> void:
	var used_world_seed := world_seed if world_seed != 0 else randi()
	var used_map_seed := map_seed if map_seed != 0 else randi()
	towns = TownWorld.generate(used_world_seed)
	view = MapBuilder.create(map, towns, map_origin, used_map_seed)
	print("World seed %d (%d towns), map seed %d, first town at cell %s" % [
			used_world_seed, towns.towns().size(), used_map_seed, view.start_town - map_origin])
	inventory = Inventory.load_from(inventory_path)
	map.tile_clicked.connect(_on_tile_clicked)
	map.dragged.connect(_on_map_dragged)
	view.arrived.connect(_on_player_arrived)
	_build_ui()
	camera.zoom = Vector2(zoom, zoom)
	camera.position = map.ground_layer.map_to_local(Vector2i.ZERO)


## The camera keeps up with the walking player, so they never walk off screen. Standing still, it only moves
## where the player drags it.
func _process(_delta: float) -> void:
	if view.walking:
		camera.position = _clamp_to_map(map.player.position)


## Built in code so the scene file stays untouched while the Godot editor has it open.
## The side panel is laid out in sprite pixels and scaled by `ui_scale`. It stays hidden until a
## tile is selected, and _layout_ui keeps it flush against the right edge, running the full height
## of the window, whenever that window resizes.
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "UI"
	add_child(layer)

	_panel = _titled_panel("Tile", "Close and deselect the tile", _on_close_pressed)
	_panel.scale = Vector2(ui_scale, ui_scale)
	_panel.hide()
	layer.add_child(_panel)
	var rows := _body_of(_panel)

	_env_rows = VBoxContainer.new()
	_env_rows.add_theme_constant_override("separation", 4)
	_env_rows.custom_minimum_size = Vector2(ENV_ICON + 46, 0)
	rows.add_child(_env_rows)

	# An expanding spacer pushes the button to the bottom of the full-height panel.
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(filler)

	# Two steps to reach new land: look at the tile next to you, then walk onto it.
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	rows.add_child(buttons)
	_discover_button = _button("Discover", "LightButton", "Look at the tile next to you and what lies behind it")
	_discover_button.pressed.connect(_on_discover_pressed)
	buttons.add_child(_discover_button)
	_move_button = _button("Move here", "LightButton", "Walk to the selected tile")
	_move_button.pressed.connect(_on_move_pressed)
	buttons.add_child(_move_button)

	_build_bag(layer)

	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui.call_deferred()


## The bag: a button in the top-left corner and the panel it opens, built the same way as the tile
## panel opposite and flush against the other edge. Inside it, every item the world has handed over
## as a grid of squares, and under that whatever one is being looked at.
func _build_bag(layer: CanvasLayer) -> void:
	_bag_button = _button("Items", "WoodButton", "What the monsters have dropped")
	# It stands on the map rather than inside a panel, so it carries the theme itself: a variation
	# means nothing to a Control with no themed ancestor.
	_bag_button.theme = UITheme.theme()
	_bag_button.disabled = false
	_bag_button.scale = Vector2(ui_scale, ui_scale)
	_bag_button.position = Vector2(8, 8)
	_bag_button.pressed.connect(_on_bag_pressed)
	layer.add_child(_bag_button)

	_bag_panel = _titled_panel("Items", "Close the item panel", _on_bag_closed)
	_bag_panel.scale = Vector2(ui_scale, ui_scale)
	_bag_panel.hide()
	layer.add_child(_bag_panel)
	var rows := _body_of(_bag_panel)

	# The grid scrolls but never shows a bar: Godot's own would sit against the pixel art badly, and
	# drawing one is an art job of its own. The wheel is the ScrollContainer's; dragging is ours. It
	# sits straight on the cream body, the way the pack lays its own inventory out -- a panel inside
	# the panel would be a second frame around the same squares.
	_bag_scroll = ScrollContainer.new()
	_bag_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_bag_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	_bag_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_scroll.gui_input.connect(_on_bag_grid_input)
	rows.add_child(_bag_scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = GRID_COLS
	_bag_grid.add_theme_constant_override("h_separation", SLOT_GAP)
	_bag_grid.add_theme_constant_override("v_separation", SLOT_GAP)
	# Fixed, so the panel does not change width as the bag fills.
	_bag_grid.custom_minimum_size = Vector2(
			GRID_COLS * ItemSlot.SIDE + (GRID_COLS - 1) * SLOT_GAP, 0)
	_bag_scroll.add_child(_bag_grid)

	# What one item is. It takes the grid's place rather than sitting under it: the panel is only as
	# tall as the window, and an elite piece carrying six modifiers would squeeze the squares down to
	# a sliver. Nothing floats, so nothing new can cover the map.
	_bag_detail = VBoxContainer.new()
	_bag_detail.add_theme_constant_override("separation", 2)
	_bag_detail.custom_minimum_size = Vector2(_bag_grid.custom_minimum_size.x, 0)
	_bag_detail.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_detail.hide()
	rows.add_child(_bag_detail)
	_refresh_bag()


## The bag: one square per item held, newest first, because the thing just picked up is the thing
## being looked for. An empty bag says so rather than showing a blank rectangle.
func _refresh_bag() -> void:
	for child: Node in _bag_grid.get_children():
		child.queue_free()
	var held := inventory.items
	for i in range(held.size() - 1, -1, -1):
		_bag_grid.add_child(ItemSlot.make(held[i], i == _bag_selected))
	if _bag_selected >= 0 and _bag_selected < held.size():
		_show_item(_bag_selected)
	else:
		_hide_item()


## A press that stays put is a click on whatever square is under it; a press that travels drags the
## list. The same rule HexMap uses to tell a tile click from a pan, for the same reason: one gesture
## should not need a second button. Everything arrives here rather than at the squares themselves,
## because a square that took the press would break every drag that began on one.
func _on_bag_grid_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_bag_drag_from = event.position
			_bag_drag_scroll = _bag_scroll.scroll_vertical
			_bag_dragged = 0.0
		elif _bag_dragged < BAG_DRAG_THRESHOLD:
			# The event is in the scroll container's own space, so how far the grid has been scrolled
			# is what turns it into a spot on the grid.
			_on_bag_clicked(event.position + Vector2(0.0, _bag_scroll.scroll_vertical))
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		_bag_dragged += absf(event.relative.y)
		_bag_scroll.scroll_vertical = _bag_drag_scroll - int(event.position.y - _bag_drag_from.y)


## Opens the square under `at`, or closes the stat block when the click landed on bare grid. The
## squares take no input, so which one was hit is worked out from where the cursor is.
func _on_bag_clicked(at: Vector2) -> void:
	for slot: Control in _bag_grid.get_children():
		if not Rect2(slot.position, slot.size).has_point(at):
			continue
		# The grid is drawn newest first, so its children run backwards through the inventory.
		var index := inventory.total() - 1 - slot.get_index()
		_select_item(-1 if index == _bag_selected else index)
		return
	_select_item(-1)


func _select_item(index: int) -> void:
	_bag_selected = index
	_refresh_bag()


## What one item is, shown in the grid's place. ItemDetails writes the lines, so an item reads the
## same here as it does on the panel at the end of a fight.
func _show_item(index: int) -> void:
	ItemDetails.fill(_bag_detail, inventory.items[index], _bag_grid.custom_minimum_size.x)
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_detail.add_child(filler)
	# Light, not wood: it stands on the white panel, and the theme pairs them that way round.
	var back := _button("Back", "LightButton", "Back to everything you are carrying")
	back.disabled = false
	back.pressed.connect(_select_item.bind(-1))
	_bag_detail.add_child(back)
	_bag_scroll.hide()
	_bag_detail.show()


func _hide_item() -> void:
	_bag_detail.hide()
	_bag_scroll.show()


## One row per environment on the tile: a swatch of that terrain, then its share of the tile.
func _show_environments(weights: Dictionary) -> void:
	for child: Node in _env_rows.get_children():
		child.queue_free()
	var envs := weights.keys()
	envs.sort_custom(func(a: String, b: String) -> bool: return weights[a] > weights[b])
	for env: String in envs:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_env_icon(env))
		var percent := Label.new()
		percent.theme_type_variation = "PanelLabel"
		percent.text = "%d%%" % round(weights[env] * 100.0)
		percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(percent)
		_env_rows.add_child(row)


## A swatch cut from the middle of that environment's own tile on the hex sheet, so the icon always
## shows the terrain the player sees on the map and there is no second set of art to keep in step.
func _env_icon(env: String) -> TextureRect:
	var source := map.tileset.tile_set.get_source(HexTileset.SOURCE_ID) as TileSetAtlasSource
	var tile_size := map.tileset.tile_size
	@warning_ignore("integer_division")  # 56 and 64 less 16 are both even, so the swatch is centred
	var origin := map.tileset.atlas_coords("env_%s_v1" % env) * tile_size + (tile_size - ENV_ICON_SIZE) / 2
	var atlas := AtlasTexture.new()
	atlas.atlas = source.texture
	atlas.region = Rect2(origin, ENV_ICON_SIZE)
	var icon := TextureRect.new()
	icon.texture = atlas
	icon.custom_minimum_size = Vector2(ENV_ICON_SIZE)
	return icon


## A panel the way the UI pack draws one: a green title bar with the title on it and an X at its
## right end, and a cream body under it running the rest of the height. The two are separate panels
## stacked in a VBox rather than one sprite, because the pack's headered panel fixes its bar at 13 px
## and Pixellari needs 16 to stay legible -- see the note in tools/ui_kit.py. Stacked, the bar grows
## to whatever the title needs and the body takes the rest.
##
## The X sits on the map side of the panel, where the hand already is. The caller fills the body,
## which `_body_of` hands back.
func _titled_panel(title_text: String, tooltip: String, on_close: Callable) -> VBoxContainer:
	var stack := VBoxContainer.new()
	stack.theme = UITheme.theme()
	stack.add_theme_constant_override("separation", 0)

	var bar := PanelContainer.new()
	bar.theme_type_variation = "HeaderBar"
	stack.add_child(bar)
	var header := HBoxContainer.new()
	bar.add_child(header)
	var title := Label.new()
	title.theme_type_variation = "PanelLabel"
	title.text = title_text
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(title)
	# The pack's own close button: a drawn X rather than the letter typed on a green button, so it is
	# placed at the size the pack drew it and asks the theme what that is.
	var close := _button("", "CloseButton", tooltip)
	close.disabled = false
	close.custom_minimum_size = Vector2(UITheme.icon_size("CloseButton"))
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(on_close)
	header.add_child(close)

	var body := PanelContainer.new()
	body.theme_type_variation = "TextPanel"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(body)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	body.add_child(rows)
	return stack


## Where a titled panel's contents go: the VBox inside its body, which is the second child.
func _body_of(panel: VBoxContainer) -> VBoxContainer:
	return panel.get_child(1).get_child(0)


func _button(text: String, variation: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.tooltip_text = tooltip
	button.disabled = true
	return button


## Both panels are scaled by `ui_scale`, so they are sized in sprite pixels: a height of
## view/ui_scale fills the window exactly. Their contents keep their own heights and stack from the
## top. The tile panel is flush against the right edge, the item panel against the left; the button
## that opens it keeps its corner.
func _layout_ui() -> void:
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	var height := view_size.y / ui_scale
	var width := _panel.get_combined_minimum_size().x
	_panel.size = Vector2(width, height)
	_panel.position = Vector2(view_size.x - width * ui_scale, 0.0)
	_bag_panel.size = Vector2(_bag_panel.get_combined_minimum_size().x, height)
	_bag_panel.position = Vector2.ZERO


func _on_tile_clicked(cell: Vector2i, info: Dictionary) -> void:
	_update_buttons()
	_panel.show()
	_layout_ui()
	var spot := map_origin + cell
	var weights: Dictionary = info["environments"]
	var parts := PackedStringArray()
	for env: String in weights:
		parts.append("%s %.1f%%" % [env, weights[env] * 100])
	var line := "Clicked %s (world %s): %s | %s" % [cell, spot, info["name"], ", ".join(parts)]
	if towns.has_town(spot):
		line += " | town connected to %s" % [towns.connections(spot)]
	print(line)
	_show_environments(weights)


## Dragging moves the camera the other way, so the map follows the cursor.
func _on_map_dragged(relative: Vector2) -> void:
	camera.position = _clamp_to_map(camera.position - relative / camera.zoom.x)


## Keeps the camera over the map, on the middle of the outermost tiles.
func _clamp_to_map(to: Vector2) -> Vector2:
	var first := map.ground_layer.map_to_local(view.rect.position)
	var last := map.ground_layer.map_to_local(view.rect.end - Vector2i.ONE)
	return to.clamp(first, last)


## A tile has to be taken before it can be discovered: ten of whatever lives on it, inside a minute.
## Winning discovers it as before; losing leaves the map exactly as it was, free to try again.
func _on_discover_pressed() -> void:
	var cell := map.selected_cell
	if not view.can_discover(cell):
		return
	var env: String = map.get_tile_info(cell).get("env", "")
	print("Fighting for %s (%s)" % [cell, env])
	var fight := Encounter.for_tile(cell, env)
	# Until the player has seen their first drop, the elite that ends the fight is promised one.
	fight.guarantee_elite = not inventory.first_elite_taken
	fight.loot_dropped.connect(_on_loot_dropped)
	_fight_drops.clear()
	_combat = load("res://Scenes/Combat/combat_scene.tscn").instantiate()
	_combat.finished.connect(_on_combat_finished.bind(cell))
	add_child(_combat)
	_combat.begin(fight, cell, ui_scale)
	# The map keeps its state but stops running, so nothing walks on underneath the fight.
	map.hide()
	map.process_mode = Node.PROCESS_MODE_DISABLED
	_panel.hide()
	# The button has to go, not just be covered: a Control takes the mouse before the fight sees it,
	# so one left in that corner would quietly eat the player's swings.
	_bag_panel.hide()
	_bag_button.hide()


## Back from the fight. The tile is discovered only if it was won; either way the map comes back
## exactly as it was left.
func _on_combat_finished(won: bool, cell: Vector2i) -> void:
	_combat.queue_free()
	_combat = null
	map.process_mode = Node.PROCESS_MODE_INHERIT
	map.show()
	_bag_button.show()
	var turned_up := PackedStringArray()
	for drop in _fight_drops:
		turned_up.append("%s (%s)" % [drop.type, drop.rarity_name()])
	print("The fight turned up: %s" % ["nothing" if turned_up.is_empty() else ", ".join(turned_up)])
	if won:
		print("Discovered %s, showing %d tile(s) behind it; walking there" % [cell, view.discover(cell)])
	else:
		print("Lost the fight for %s; it stays undiscovered" % cell)
	if map.selected_cell != HexMap.NO_CELL:
		_panel.show()
	_update_buttons()


## The player walks to the tile; both buttons stay disabled until they get there.
func _on_move_pressed() -> void:
	var cell := map.selected_cell
	print("Walking to %s, %d tile(s) away" % [cell, view.move_to(cell).size()])
	_update_buttons()


func _on_player_arrived(cell: Vector2i) -> void:
	print("Arrived at %s" % cell)
	_update_buttons()


## A tile is either something to look at or somewhere to go, and neither while the player is walking.
func _update_buttons() -> void:
	var cell := map.selected_cell
	_discover_button.disabled = not view.can_discover(cell)
	_move_button.disabled = not view.can_move_to(cell)


## A kill left something behind. It is the player's whatever the fight does next, so it is written
## to disk as it lands rather than at the end: closing the game mid-fight cannot cost a find.
func _on_loot_dropped(index: int, item: Item) -> void:
	inventory.add(item)
	_fight_drops.append(item)
	if index == Encounter.ENEMIES - 1:
		inventory.first_elite_taken = true
	inventory.save(inventory_path)
	_refresh_bag()
	print("Dropped %s (%s, %d modifier(s))" % [item.type, item.rarity_name(), item.mods.size()])


## The panel takes the button's place while it is open, so the corner never holds both.
func _on_bag_pressed() -> void:
	# Always opens on the grid: a stat block left over from last time is not what was asked for.
	_bag_selected = -1
	_refresh_bag()
	_layout_ui()
	_bag_panel.show()
	_bag_button.hide()


func _on_bag_closed() -> void:
	_bag_panel.hide()
	_bag_button.show()


## The X closes the panel and drops the selection, so nothing stays outlined on the map.
func _on_close_pressed() -> void:
	_panel.hide()
	map.deselect()
	_update_buttons()
