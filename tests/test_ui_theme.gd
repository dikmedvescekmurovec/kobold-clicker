extends SceneTree
## Headless checks for the 9-slice UI theme. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_ui_theme.gd

var _failures := 0


func _initialize() -> void:
	# The root only enters the tree after _initialize, so nodes added here would not get _ready yet.
	_run.call_deferred()


func _run() -> void:
	var theme := UITheme.build()
	# A script error aborts a test function and makes it return null instead of true.
	_check(_test_sheet() == true, "sheet JSON tests ran to the end")
	_check(_test_panels(theme) == true, "panel tests ran to the end")
	_check(_test_buttons(theme) == true, "button tests ran to the end")
	_check(_test_controls(theme) == true, "live control tests ran to the end")
	if _failures == 0:
		print("All UI theme tests passed")
	else:
		printerr("%d UI theme check(s) failed" % _failures)
	quit(1 if _failures else 0)


func _test_sheet() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))
	var meta: Dictionary = data["meta"]
	var slice := int(meta["slice"])
	var size := int(meta["sprite_size"][0])
	_check(slice * 3 == size, "the sprite is three slices wide")
	_check(Vector2i(int(meta["min_size"][0]), int(meta["min_size"][1])) == Vector2i(slice, slice) * 2,
			"the minimum size is two slices")

	var sheet: Texture2D = load(UITheme.SHEET_JSON.get_base_dir().path_join(meta["image"]))
	var sheet_size := Vector2i(int(meta["sheet_size"][0]), int(meta["sheet_size"][1]))
	_check(sheet != null and sheet.get_size() == Vector2(sheet_size), "the sheet matches its declared size")

	var names := {}
	for sprite: Dictionary in data["sprites"]:
		names[sprite["name"]] = true
		var region := Rect2i(sprite["x"], sprite["y"], sprite["w"], sprite["h"])
		_check(region.size == Vector2i(size, size), "%s is %dx%d" % [sprite["name"], size, size])
		_check(Rect2i(Vector2i.ZERO, sheet_size).encloses(region), "%s lies inside the sheet" % sprite["name"])

	var expected: Array[String] = ["ui_panel_white", "ui_panel_wood"]
	for surface: String in ["wood", "light"]:
		for variant: String in ["normal", "danger"]:
			for state: String in UITheme.STATES:
				expected.append("ui_btn_%s_%s_%s" % [surface, variant, state])
	for name: String in expected:
		_check(names.has(name), "the sheet has %s" % name)
	_check(names.size() == expected.size(), "the sheet has exactly %d sprites" % expected.size())
	return true


func _test_panels(theme: Theme) -> bool:
	for variation: String in UITheme.PANELS:
		_check(theme.get_type_variation_base(variation) == "PanelContainer", "%s is a PanelContainer" % variation)
		var box := theme.get_stylebox("panel", variation)
		_check(_is_nine_slice(box, variation) == true, "%s is a tiled 9-slice" % variation)
		_check(box.content_margin_left == UITheme.PANEL_MARGIN, "%s pads its contents" % variation)
	return true


func _test_buttons(theme: Theme) -> bool:
	for variation: String in UITheme.BUTTONS:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		for state: String in UITheme.STATES:
			_check(theme.has_stylebox(state, variation), "%s has a %s style" % [variation, state])
			_check(_is_nine_slice(theme.get_stylebox(state, variation), variation) == true,
					"%s %s is a tiled 9-slice" % [variation, state])
		# Pressed inverts the bevel, so its label sits one pixel lower than in any other state.
		var normal := theme.get_stylebox("normal", variation)
		var pressed := theme.get_stylebox("pressed", variation)
		_check(pressed.content_margin_top == normal.content_margin_top + 1, "%s sinks when pressed" % variation)
		_check(pressed.content_margin_bottom == normal.content_margin_bottom - 1,
				"%s keeps its height when pressed" % variation)
		_check(theme.has_color("font_disabled_color", variation), "%s dims its label when disabled" % variation)
	return true


## The theme has to work on real nodes, not just as a resource.
func _test_controls(theme: Theme) -> bool:
	var slice := int(JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))["meta"]["slice"])
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.theme_type_variation = "WoodPanel"
	root.add_child(panel)
	var button := Button.new()
	button.theme_type_variation = "LightDangerButton"
	panel.add_child(button)
	_check(button.get_theme_stylebox("normal") == theme.get_stylebox("normal", "LightDangerButton"),
			"a child button resolves its variation through the panel's theme")
	_check(button.get_combined_minimum_size().x <= 3 * slice,
			"an empty button fits in one sprite width (%s)" % button.get_combined_minimum_size())
	panel.queue_free()
	return true


func _is_nine_slice(box: StyleBox, what: String) -> bool:
	var textured := box as StyleBoxTexture
	if textured == null:
		_check(false, "%s uses a StyleBoxTexture" % what)
		return false
	var slice := int(JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))["meta"]["slice"])
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_check(textured.get_texture_margin(side) == slice, "%s has a %d px texture margin" % [what, slice])
	_check(textured.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			and textured.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE,
			"%s tiles rather than stretches" % what)
	_check(textured.texture is AtlasTexture, "%s draws from the shared sheet" % what)
	return true


func _check(ok: bool, what: String) -> void:
	if not ok:
		_failures += 1
		printerr("FAIL: " + what)
