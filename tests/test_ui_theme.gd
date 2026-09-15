extends "res://tests/harness.gd"
## Headless checks for the 9-slice UI theme. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_ui_theme.gd

func _run() -> void:
	var theme := UITheme.build()
	_check(_test_sheet() == true, "sheet JSON tests ran to the end")
	_check(_test_panels(theme) == true, "panel tests ran to the end")
	_check(_test_buttons(theme) == true, "button tests ran to the end")
	_check(_test_icon_buttons(theme) == true, "icon button tests ran to the end")
	_check(_test_controls(theme) == true, "live control tests ran to the end")
	_check(_test_orb_tray() == true, "orb tray tests ran to the end")
	_report("UI theme")


func _test_sheet() -> bool:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))
	var meta: Dictionary = data["meta"]
	var sheet: Texture2D = load(UITheme.SHEET_JSON.get_base_dir().path_join(meta["image"]))
	var sheet_size := Vector2i(int(meta["sheet_size"][0]), int(meta["sheet_size"][1]))
	_check(sheet != null and sheet.get_size() == Vector2(sheet_size), "the sheet matches its declared size")

	var names := {}
	for sprite: Dictionary in data["sprites"]:
		names[sprite["name"]] = true
		var region := Rect2i(sprite["x"], sprite["y"], sprite["w"], sprite["h"])
		_check(Rect2i(Vector2i.ZERO, sheet_size).encloses(region), "%s lies inside the sheet" % sprite["name"])
		# The margins are what makes a sprite a nine-slice: they have to leave a centre to tile.
		var margin: Dictionary = sprite["margin"]
		_check(int(margin["left"]) + int(margin["right"]) < region.size.x
				and int(margin["top"]) + int(margin["bottom"]) < region.size.y,
				"%s keeps a centre between its margins" % sprite["name"])

	var expected: Array[String] = []
	for variation: String in UITheme.PANELS:
		expected.append(UITheme.PANELS[variation])
	for surface: String in ["wood", "light"]:
		for variant: String in ["normal", "danger"]:
			for state: String in UITheme.STATES:
				expected.append("ui_btn_%s_%s_%s" % [surface, variant, state])
	for variation: String in UITheme.ICON_BUTTONS:
		for state: String in UITheme.STATES:
			expected.append("%s_%s" % [UITheme.ICON_BUTTONS[variation], state])
	for name: String in expected:
		_check(names.has(name), "the sheet has %s" % name)
	_check(names.size() == expected.size(), "the sheet has exactly %d sprites" % expected.size())
	return true


func _test_panels(theme: Theme) -> bool:
	for variation: String in UITheme.PANELS:
		_check(theme.get_type_variation_base(variation) == "PanelContainer", "%s is a PanelContainer" % variation)
		var box := theme.get_stylebox("panel", variation)
		_check(_is_nine_slice(box, UITheme.PANELS[variation], variation) == true,
				"%s is a tiled 9-slice" % variation)
		# The bar is trim rather than a container, so it pads its title far less than a panel does.
		var pad := UITheme.BAR_MARGIN.x if variation == "HeaderBar" else UITheme.PANEL_MARGIN
		_check(box.content_margin_left == pad, "%s pads its contents" % variation)
	return true


func _test_buttons(theme: Theme) -> bool:
	for variation: String in UITheme.BUTTONS:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		var surface: String = UITheme.BUTTONS[variation][0]
		var variant: String = UITheme.BUTTONS[variation][1]
		for state: String in UITheme.STATES:
			_check(theme.has_stylebox(state, variation), "%s has a %s style" % [variation, state])
			var sprite_name := "ui_btn_%s_%s_%s" % [surface, variant, state]
			_check(_is_nine_slice(theme.get_stylebox(state, variation), sprite_name, variation) == true,
					"%s %s is a tiled 9-slice" % [variation, state])
		# Pressed inverts the bevel, so its label sits one pixel lower than in any other state.
		var normal := theme.get_stylebox("normal", variation)
		var pressed := theme.get_stylebox("pressed", variation)
		_check(pressed.content_margin_top == normal.content_margin_top + 1, "%s sinks when pressed" % variation)
		_check(pressed.content_margin_bottom == normal.content_margin_bottom - 1,
				"%s keeps its height when pressed" % variation)
		_check(theme.has_color("font_disabled_color", variation), "%s dims its label when disabled" % variation)
	return true


## An icon button is drawn, not stretched: no texture margin, no content margin, and the four states
## are the one sprite the pack drew plus the three the pack's own rules give it.
func _test_icon_buttons(theme: Theme) -> bool:
	for variation: String in UITheme.ICON_BUTTONS:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		var size := UITheme.icon_size(variation)
		_check(size.x > 0 and size.y > 0, "%s knows how big it is (%s)" % [variation, size])
		for state: String in UITheme.STATES:
			var box := theme.get_stylebox(state, variation) as StyleBoxTexture
			_check(box != null, "%s %s draws from the sheet" % [variation, state])
			if box == null:
				continue
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_check(box.get_texture_margin(side) == 0,
						"%s %s is never sliced" % [variation, state])
				_check(box.get_content_margin(side) <= 0,
						"%s %s pads nothing" % [variation, state])
			_check(box.texture.region.size == Vector2(size),
					"%s %s is the size the pack drew" % [variation, state])
	return true


## The theme has to work on real nodes, not just as a resource.
func _test_controls(theme: Theme) -> bool:
	var panel := PanelContainer.new()
	panel.theme = theme
	panel.theme_type_variation = "WoodPanel"
	root.add_child(panel)
	var button := Button.new()
	button.theme_type_variation = "LightDangerButton"
	panel.add_child(button)
	_check(button.get_theme_stylebox("normal") == theme.get_stylebox("normal", "LightDangerButton"),
			"a child button resolves its variation through the panel's theme")
	_check(button.get_combined_minimum_size().x <= _sprite("ui_btn_light_danger_normal")["w"],
			"an empty button fits in one sprite width (%s)" % button.get_combined_minimum_size())
	panel.queue_free()
	return true


## The sheet entry `sprite_name` describes, so a margin is checked against the JSON rather than
## against a number repeated here.
func _sprite(sprite_name: String) -> Dictionary:
	for sprite: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(UITheme.SHEET_JSON))["sprites"]:
		if sprite["name"] == sprite_name:
			return sprite
	_check(false, "the sheet has %s" % sprite_name)
	return {"w": 0, "h": 0, "margin": {"left": 0, "top": 0, "right": 0, "bottom": 0}}


func _is_nine_slice(box: StyleBox, sprite_name: String, what: String) -> bool:
	var textured := box as StyleBoxTexture
	if textured == null:
		_check(false, "%s uses a StyleBoxTexture" % what)
		return false
	var margin: Dictionary = _sprite(sprite_name)["margin"]
	var sides := {SIDE_LEFT: "left", SIDE_TOP: "top", SIDE_RIGHT: "right", SIDE_BOTTOM: "bottom"}
	for side: Side in sides:
		_check(textured.get_texture_margin(side) == int(margin[sides[side]]),
				"%s takes its %s margin from the sheet" % [what, sides[side]])
	_check(textured.axis_stretch_horizontal == StyleBoxTexture.AXIS_STRETCH_MODE_TILE
			and textured.axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE,
			"%s tiles rather than stretches" % what)
	_check(textured.texture is AtlasTexture, "%s draws from the shared sheet" % what)
	return true


## The orb tray is exactly as wide as the bag's grid, and every icon it draws is the size it is drawn
## at. Held here the way KillPips asserts its own parts still add up: the row is assembled from eight
## fixed squares and a gap worked out from what is left over, so a change to either number that broke
## the arithmetic would show as a tray a few pixels out rather than as anything that looks wrong.
func _test_orb_tray() -> bool:
	# The main scene has no class_name -- it is a scene's script, not a type anything constructs --
	# so its constants are read off the script resource itself.
	var scene := preload("res://Scenes/main_scene.gd")
	var cols: int = scene.ORB_COLS
	var gap: int = scene.ORB_GAP
	var width: int = scene.BAG_WIDTH
	var assembled := cols * OrbSlot.SIDE + (cols - 1) * gap
	_check(assembled == width,
			"eight orbs and their gaps come to %d, not the grid's %d" % [assembled, width])
	_check(cols == OrbTable.ORBS.size(),
			"the tray has a square for each of the %d orbs" % OrbTable.ORBS.size())
	_check(gap > 0, "the squares do not touch")
	_check(OrbSlot.ICON * 2 == ItemSlot.ICON,
			"an orb is drawn at exactly half the size it is cut at, so its pixels stay square")
	_check(OrbSlot.SIDE > OrbSlot.ICON, "an orb square has a gutter round its icon")
	# Every orb builds into a live square, and the three states are three different pictures. That
	# last part is the whole of what the tray communicates, and it is the one thing a table of names
	# cannot tell us: an orb never found, one held but useless here, and one ready to spend have to
	# be told apart at a glance in a row of eight.
	for orb: String in OrbTable.orbs():
		var ghost := OrbSlot.make(orb, 0, true)
		var dim := OrbSlot.make(orb, 2, false)
		var lit := OrbSlot.make(orb, 2, true)
		for slot: OrbSlot in [ghost, dim, lit]:
			_check(slot.custom_minimum_size == Vector2(OrbSlot.SIDE, OrbSlot.SIDE),
					"%s builds a %d square" % [orb, OrbSlot.SIDE])
			_check(slot.mouse_filter == Control.MOUSE_FILTER_STOP,
					"%s takes the mouse, unlike an item square" % orb)
		# Approximately: a Color's components are single-precision, so they never compare equal to a
		# double literal on the nose.
		_check(is_equal_approx(ghost._icon.modulate.a, ItemSlot.EMPTY_MARK_ALPHA),
				"%s never found is drawn faint" % orb)
		_check(lit._icon.modulate.is_equal_approx(Color.WHITE),
				"%s ready to spend is drawn plain" % orb)
		_check(dim._icon.modulate.is_equal_approx(OrbSlot.DIM),
				"%s held but useless is drawn grey" % orb)
		_check(dim._icon.modulate != ghost._icon.modulate,
				"%s tells 'not yours' from 'not for this' " % orb)
		# A count past one is drawn and a count of one is not -- seven squares wearing a 1 would be
		# seven numbers saying nothing.
		_check(_labels_in(OrbSlot.make(orb, 1, true)) == 0, "%s held once wears no count" % orb)
		_check(_labels_in(OrbSlot.make(orb, 2, true)) == 1, "%s held twice wears a count" % orb)
		for slot: OrbSlot in [ghost, dim, lit]:
			slot.free()
	return true


## How many Labels a square is carrying, which is how the count is checked for without reaching for
## a node path that would break the moment the square is built differently.
func _labels_in(slot: OrbSlot) -> int:
	var found := 0
	for child: Node in slot.get_children():
		if child is Label:
			found += 1
	slot.free()
	return found
