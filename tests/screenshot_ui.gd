extends SceneTree
## Renders the UI kit for a visual check: the main scene's panel over the map, then a board showing
## every button state at three sizes, including the 16x16 minimum. Needs a window (no --headless):
##   Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/screenshot_ui.gd

const WORLD_SEED := 12345
const MAP_SEED := 1
## The board is drawn at 2x rather than the scene's 3x so all four states of every variation fit in
## one 1152x648 window, at the 16x16 minimum and at a realistic button size.
const UI_SCALE := 2
const SIZES := [Vector2(16, 16), Vector2(100, 26)]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _shoot_main_scene()
	await _shoot_board()
	quit()


## The kit in place: the wooden panel over the generated map, as the player sees it.
func _shoot_main_scene() -> void:
	var main: Node = load("res://Scenes/main_scene.tscn").instantiate()
	main.world_seed = WORLD_SEED
	main.map_seed = MAP_SEED
	root.add_child(main)
	for i in 3:
		await process_frame
	# Select the centre tile, which is what opens the side panel.
	main.map.select_cell(Vector2i.ZERO)
	for i in 2:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.save_png("user://ui_in_scene.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_in_scene.png"))

	# A 3x crop of the panel itself, to inspect the borders pixel by pixel.
	var panel: Control = main._panel
	var rect := Rect2i(Rect2(panel.position, panel.get_combined_minimum_size() * panel.scale))
	rect = rect.grow(8).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(rect)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png("user://ui_panel_crop.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_panel_crop.png"))
	main.queue_free()
	await process_frame


## Every variation and state, at three sizes, on the surface each one is meant to stand on.
func _shoot_board() -> void:
	var theme := UITheme.theme()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	var backdrop := ColorRect.new()
	backdrop.color = Color("1c1e28")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(backdrop)

	var board := VBoxContainer.new()
	board.theme = theme
	board.scale = Vector2(UI_SCALE, UI_SCALE)
	board.position = Vector2(8, 8)
	board.add_theme_constant_override("separation", 6)
	layer.add_child(board)
	for panel_variation: String in ["WoodPanel", "TextPanel"]:
		var surface := "wood" if panel_variation == "WoodPanel" else "light"
		var panel := PanelContainer.new()
		panel.theme_type_variation = panel_variation
		board.add_child(panel)
		var rows := VBoxContainer.new()
		rows.add_theme_constant_override("separation", 4)
		panel.add_child(rows)
		for variation: String in UITheme.BUTTONS:
			if UITheme.BUTTONS[variation][0] != surface:
				continue
			for size: Vector2 in SIZES:
				var line := HBoxContainer.new()
				line.add_theme_constant_override("separation", 4)
				rows.add_child(line)
				for state: String in UITheme.STATES:
					line.add_child(_sample(variation, state, size))
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://ui_kit.png")
	print("Saved ", ProjectSettings.globalize_path("user://ui_kit.png"))


## Godot only shows hover and pressed on real input, so force each state with draw_mode overrides:
## a disabled button draws disabled, and for hover/pressed we draw the stylebox behind a plain label.
func _sample(variation: String, state: String, size: Vector2) -> Control:
	if state == "normal" or state == "disabled":
		var button := Button.new()
		button.theme_type_variation = variation
		button.text = "" if size.x < 40 else state
		button.disabled = state == "disabled"
		button.custom_minimum_size = size
		return button
	var box := Panel.new()
	box.add_theme_stylebox_override("panel", UITheme.theme().get_stylebox(state, variation))
	box.custom_minimum_size = size
	if size.x >= 40:
		var label := Label.new()
		label.text = state
		label.add_theme_color_override("font_color", UITheme.theme().get_color("font_color", variation))
		label.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
		box.add_child(label)
	return box
