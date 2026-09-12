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

## Side of the terrain swatch shown next to each environment percentage, in sprite pixels.
const ENV_ICON := 16
const ENV_ICON_SIZE := Vector2i(ENV_ICON, ENV_ICON)

var towns: TownWorld
var view: MapBuilder

@onready var map: HexMap = $HexMap
@onready var camera: Camera2D = $Camera2D

var _discover_button: Button
var _move_button: Button
var _env_rows: VBoxContainer
var _panel: PanelContainer


func _ready() -> void:
	var used_world_seed := world_seed if world_seed != 0 else randi()
	var used_map_seed := map_seed if map_seed != 0 else randi()
	towns = TownWorld.generate(used_world_seed)
	view = MapBuilder.create(map, towns, map_origin, used_map_seed)
	print("World seed %d (%d towns), map seed %d, first town at cell %s" % [
			used_world_seed, towns.towns().size(), used_map_seed, view.start_town - map_origin])
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

	_panel = PanelContainer.new()
	_panel.theme = UITheme.theme()
	_panel.theme_type_variation = "WoodPanel"
	_panel.scale = Vector2(ui_scale, ui_scale)
	_panel.hide()
	layer.add_child(_panel)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	_panel.add_child(rows)

	var header := HBoxContainer.new()
	rows.add_child(header)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close := _button("X", "WoodButton", "Close and deselect the tile")
	close.disabled = false
	close.pressed.connect(_on_close_pressed)
	header.add_child(close)

	var text_panel := PanelContainer.new()
	text_panel.theme_type_variation = "TextPanel"
	rows.add_child(text_panel)
	_env_rows = VBoxContainer.new()
	_env_rows.add_theme_constant_override("separation", 4)
	_env_rows.custom_minimum_size = Vector2(ENV_ICON + 46, 0)
	text_panel.add_child(_env_rows)

	# An expanding spacer pushes the button to the bottom of the full-height panel.
	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_child(filler)

	# Two steps to reach new land: look at the tile next to you, then walk onto it.
	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	rows.add_child(buttons)
	_discover_button = _button("Discover", "WoodButton", "Look at the tile next to you and what lies behind it")
	_discover_button.pressed.connect(_on_discover_pressed)
	buttons.add_child(_discover_button)
	_move_button = _button("Move here", "WoodButton", "Walk to the selected tile")
	_move_button.pressed.connect(_on_move_pressed)
	buttons.add_child(_move_button)

	get_viewport().size_changed.connect(_layout_ui)
	_layout_ui.call_deferred()


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


func _button(text: String, variation: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.tooltip_text = tooltip
	button.disabled = true
	return button


func _layout_ui() -> void:
	# The panel is scaled by `ui_scale`, so it is sized in sprite pixels: a height of view/ui_scale
	# fills the window exactly. Its contents keep their own heights and stack from the top.
	var view_size := Vector2(get_viewport().get_visible_rect().size)
	var width := _panel.get_combined_minimum_size().x
	_panel.size = Vector2(width, view_size.y / ui_scale)
	_panel.position = Vector2(view_size.x - width * ui_scale, 0.0)


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


## Discovering a tile next to the player takes the grey off it, shows what lies behind it, and sends the
## player walking onto it.
func _on_discover_pressed() -> void:
	var cell := map.selected_cell
	print("Discovered %s, showing %d tile(s) behind it; walking there" % [cell, view.discover(cell)])
	_update_buttons()


## The player walks to the tile; both buttons stay disabled until they get there.
func _on_move_pressed() -> void:
	var cell := map.selected_cell
	print("Walking to %s, %d tile(s) away" % [cell, view.route_to(cell).size()])
	view.move_to(cell)
	_update_buttons()


func _on_player_arrived(cell: Vector2i) -> void:
	print("Arrived at %s" % cell)
	_update_buttons()


## A tile is either something to look at or somewhere to go, and neither while the player is walking.
func _update_buttons() -> void:
	var cell := map.selected_cell
	_discover_button.disabled = not view.can_discover(cell)
	_move_button.disabled = not view.can_move_to(cell)


## The X closes the panel and drops the selection, so nothing stays outlined on the map.
func _on_close_pressed() -> void:
	_panel.hide()
	map.deselect()
	_update_buttons()
