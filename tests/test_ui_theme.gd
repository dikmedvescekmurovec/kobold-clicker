extends "res://tests/harness.gd"
## Headless checks for the 9-slice UI theme. Run from the project folder:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/test_ui_theme.gd

func _run() -> void:
	var theme := UITheme.build()
	_check(_test_sheet() == true, "sheet JSON tests ran to the end")
	_check(_test_panels(theme) == true, "panel tests ran to the end")
	_check(_test_buttons(theme) == true, "button tests ran to the end")
	_check(_test_icon_faces(theme) == true, "icon face tests ran to the end")
	_check(_test_icon_buttons(theme) == true, "icon button tests ran to the end")
	_check(_test_bare_buttons(theme) == true, "bare button tests ran to the end")
	_check(_test_titled_panel() == true, "titled panel tests ran to the end")
	_check(_test_controls(theme) == true, "live control tests ran to the end")
	_check(_test_orb_tray() == true, "orb tray tests ran to the end")
	_check(_test_health_bar() == true, "health bar tests ran to the end")
	_check(_test_character_panel() == true, "character panel tests ran to the end")
	_check(await _test_item_card() == true, "item card tests ran to the end")
	_check(_test_cursors() == true, "cursor tests ran to the end")
	_check(_test_tip_card() == true, "tip card tests ran to the end")
	_check(_test_dialogue_box() == true, "dialogue box tests ran to the end")
	_check(_test_accordion() == true, "accordion tests ran to the end")
	_check(await _test_settings_scroll() == true, "settings scroll tests ran to the end")
	_check(_test_table_rows() == true, "table row tests ran to the end")
	_check(_test_palette() == true, "palette tests ran to the end")
	_check(await _test_responsive() == true, "responsive layout tests ran to the end")
	_check(await _test_fingers() == true, "finger tests ran to the end")
	_report("UI theme")


## The interface is in ENDESGA 64: every colour the code draws with and every pixel of the theme sheet.
## And a word on the cream can be read: a body line to 4.5:1, a unique's name at 16 px to 3:1.
func _test_palette() -> bool:
	var e64: Array = Palette.E64
	var constants: Dictionary = (Palette as Script).get_script_constant_map()
	for name: String in constants:
		if constants[name] is Color:
			_check((constants[name] as Color).to_html(false) in e64,
					"Palette.%s is in ENDESGA 64 (%s)" % [name, (constants[name] as Color).to_html(false)])
	var sheet: Image = (load(UITheme.SHEET_JSON.get_base_dir().path_join("ui_sheet.png")) as Texture2D).get_image()
	var stray := {}
	for y in sheet.get_height():
		for x in sheet.get_width():
			var pixel := sheet.get_pixel(x, y)
			if pixel.a > 0.0 and not pixel.to_html(false) in e64:
				stray[pixel.to_html(false)] = true
	_check(stray.is_empty(), "every pixel of the theme sheet is in ENDESGA 64 (%s)" % [stray.keys().slice(0, 5)])
	for name: String in ["TEXT", "TEXT_SOFT", "SLOT_TAN_DK", "LEAF", "ICE_DK", "RUST", "BRICK"]:
		var ratio := _contrast(constants[name], Palette.PANEL_CREAM)
		_check(ratio >= 4.5, "Palette.%s reads on the cream as a body line (%.2f:1)" % [name, ratio])
	for colour: Color in ItemRarity.TEXT_COLORS.values():
		_check(_contrast(colour, Palette.PANEL_CREAM) >= 3.0, "a rarity's name reads on the cream (%s)" % colour.to_html(false))
	return true


## WCAG's contrast ratio between two colours.
func _contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


func _luminance(c: Color) -> float:
	var channel := func(v: float) -> float: return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * channel.call(c.r) + 0.7152 * channel.call(c.g) + 0.0722 * channel.call(c.b)


## A value too long to share a line with its name drops under it rather than squeezing the name
## into a word a line; one that fits stays beside it.
func _test_table_rows() -> bool:
	var fits := UITheme.table_row("Damage", "14", false, 200.0)
	var long := UITheme.table_row("increased Attack Speed T95", "+607K(416K-997K)%", false, 200.0)
	_check(fits.get_child(0) is HBoxContainer, "a short value sits beside its name")
	_check(long.get_child(0) is VBoxContainer, "a long one drops under it")
	# A modifier's row (`ItemDetails.fill`): the whole sentence, and the tier alone in the value column.
	var mod := UITheme.table_row("+607K(416K-997K)% increased Attack Speed", "T95", false, 200.0)
	_check(mod.get_child(0).get_child(0).text.begins_with("+607K") and mod.find_child(UITheme.TABLE_VALUE,
			true, false).text == "T95", "a modifier is one sentence with its tier beside it")
	fits.free()
	long.free()
	mod.free()
	return true


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
	# Off UITheme's own table rather than off a list written twice: a family the theme asks for and
	# the sheet does not hold is exactly what the count below is here to catch.
	for variation: String in UITheme.BUTTONS:
		for state: String in UITheme.STATES:
			expected.append("ui_btn_%s_%s_%s" % [UITheme.BUTTONS[variation][0],
					UITheme.BUTTONS[variation][1], state])
	for variation: String in UITheme.ICON_FACES:
		for state: String in UITheme.STATES:
			expected.append("%s_%s" % [UITheme.ICON_FACES[variation], state])
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
		var pad := UITheme.BAR_MARGIN.x if variation in ["HeaderBar", UITheme.DANGER_BAR] else UITheme.PANEL_MARGIN
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


## An icon face is a stretched 9-slice like a lettered button, but padded equally on all four sides:
## the claim is that one wearing a square mark comes out square, whatever the mark is.
func _test_icon_faces(theme: Theme) -> bool:
	for variation: String in UITheme.ICON_FACES:
		_check(theme.get_type_variation_base(variation) == "Button", "%s is a Button" % variation)
		for state: String in UITheme.STATES:
			var sprite_name: String = "%s_%s" % [UITheme.ICON_FACES[variation], state]
			_check(_is_nine_slice(theme.get_stylebox(state, variation), sprite_name, variation) == true,
					"%s %s is a tiled 9-slice" % [variation, state])
		var normal := theme.get_stylebox("normal", variation)
		_check(normal.content_margin_left == UITheme.ICON_FACE_MARGIN
				and normal.content_margin_right == UITheme.ICON_FACE_MARGIN
				and normal.content_margin_top == UITheme.ICON_FACE_MARGIN
				and normal.content_margin_bottom == UITheme.ICON_FACE_MARGIN,
				"%s pads its mark the same on all four sides" % variation)
		var pressed := theme.get_stylebox("pressed", variation)
		_check(pressed.content_margin_top == normal.content_margin_top + 1, "%s sinks when pressed" % variation)
		_check(pressed.content_margin_bottom == normal.content_margin_bottom - 1,
				"%s keeps its height when pressed" % variation)

	# The marks themselves, and the size a button wearing one comes out at. Both are cut on one
	# square by tools/ui_kit.py precisely so the corner's two buttons are the same size; a Button
	# takes its minimum from its icon, so an untrimmed mark would be the end of that.
	# The main scene has no class_name, so its constants are read off the script resource itself.
	var scene := preload("res://Scenes/main_scene.gd")
	var side := 0
	for path: String in [scene.CHEST_ICON, scene.STAR_ICON]:
		var texture: Texture2D = load(path)
		_check(texture != null, "%s is on disk" % path)
		if texture == null:
			continue
		_check(texture.get_width() == texture.get_height(), "%s is a square" % path)
		_check(side == 0 or texture.get_width() == side, "%s is the size the other marks are" % path)
		side = texture.get_width()
	var button := Button.new()
	button.theme = theme
	button.theme_type_variation = UITheme.ICON_FACES.keys()[0]
	button.icon = load(scene.CHEST_ICON)
	button.expand_icon = false
	root.add_child(button)
	var wanted := side + 2 * UITheme.ICON_FACE_MARGIN
	_check(button.get_combined_minimum_size() == Vector2(wanted, wanted),
			"an icon face comes out square (%s)" % button.get_combined_minimum_size())
	button.queue_free()
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


## A bare button is empty boxes round a mark: no face at all, the pixel of sink every face has when
## pressed, a lift under the cursor and a fade when dead. And the marks it wears are on disk in the
## pack's brown -- the cream ones are for the brown faces and wash out on the cream -- with a green
## for each tab, which is the open one.
func _test_bare_buttons(theme: Theme) -> bool:
	var bare := UITheme.BARE_BUTTON
	_check(theme.get_type_variation_base(bare) == "Button", "a bare button is a Button")
	for state: String in UITheme.STATES:
		_check(theme.get_stylebox(state, bare) is StyleBoxEmpty, "a bare button has no %s face" % state)
	var normal := theme.get_stylebox("normal", bare)
	var pressed := theme.get_stylebox("pressed", bare)
	_check(pressed.content_margin_top == normal.content_margin_top + 1
			and pressed.content_margin_bottom == normal.content_margin_bottom - 1, "it sinks when pressed")
	_check(theme.get_color("icon_hover_color", bare).r > 1.0, "hover lifts the mark")
	_check(theme.get_color("icon_disabled_color", bare).a < 1.0, "dead fades it")
	for service: String in TownPage.COUNTERS:
		var rest := TownPage.tab_mark(service, false)
		var lit := TownPage.tab_mark(service, true)
		_check(rest != null and lit != null and rest != lit, "%s has a brown mark and a green one" % service)
	for path: String in [BagPage.AUTO_ICON, BagPage.AUTO_ON_ICON, BagPage.CLEAR_ICON, BagPage.SELL_ICON]:
		_check(ResourceLoader.exists(path), "%s is cut" % path)
	var button := Button.new()
	button.theme = theme
	button.theme_type_variation = bare
	button.icon = load(BagPage.AUTO_ICON)
	button.expand_icon = false
	root.add_child(button)
	var wanted: Vector2 = button.icon.get_size() + Vector2.ONE * 2 * UITheme.BARE_MARGIN
	_check(button.get_combined_minimum_size() == wanted,
			"a bare button is its mark and its margin (%s)" % button.get_combined_minimum_size())
	button.queue_free()
	return true


## A titled panel's body is the headed cut, which has no top frame under the bar; its title is inked
## for the green; and the wobbles fall along its left, right and foot, clear of the corners, and
## never on a card too short to hold one.
func _test_titled_panel() -> bool:
	var panel := UITheme.titled_panel("Title", "close", func() -> void: pass)
	root.add_child(panel)
	var body: PanelContainer = panel.get_child(1)
	_check(body.theme_type_variation == "HeadedPanel", "the body under a bar is the headed cut")
	var headed := UITheme.theme().get_stylebox("panel", "HeadedPanel") as StyleBoxTexture
	var plain := UITheme.theme().get_stylebox("panel", "TextPanel") as StyleBoxTexture
	_check(headed.get_texture_margin(SIDE_TOP) < plain.get_texture_margin(SIDE_TOP),
			"the headed body's top is thinner than a frame: a drop line and a tan row")
	_check(headed.get_texture_margin(SIDE_LEFT) == plain.get_texture_margin(SIDE_LEFT),
			"and its sides are the same frame")
	_check(UITheme.title_of(panel).get_theme_color("font_color") == Palette.INK, "the title is inked")
	_check(body.draw.get_connections().size() == 1, "the body draws its wobbles")
	var bar: PanelContainer = panel.get_child(0)
	_check(bar.draw.get_connections().size() == 1, "and so does the bar")
	var on_bar := UITheme.notch_places(Vector2(130, 20), true)
	_check(on_bar.size() == 2 and on_bar.all(func(place: Array) -> bool: return place[1].y == 0.0),
			"a bar's wobbles run along its top (%d)" % on_bar.size())
	var size := Vector2(120, 150)
	var sides := {"left": 0, "right": 0, "bottom": 0}
	for place: Array in UITheme.notch_places(size):
		var rect := Rect2(place[1], (place[0] as Texture2D).get_size())
		_check(Rect2(Vector2.ZERO, size).encloses(rect), "a wobble lies on the panel (%s)" % rect)
		_check(rect.position.y >= UITheme.NOTCH_START or rect.end.y == size.y, "and clear of the top corners")
		if rect.position.x == 0.0:
			sides["left"] += 1
		elif rect.end.x == size.x:
			sides["right"] += 1
		if rect.end.y == size.y:
			sides["bottom"] += 1
	_check(sides["left"] >= 2 and sides["right"] >= 2 and sides["bottom"] >= 2,
			"a tall panel wobbles on all three edges (%s)" % sides)
	var short := UITheme.notch_places(Vector2(60, 24))
	_check(short.size() == 1 and short[0][1].y + short[0][0].get_size().y == 24.0,
			"a short card wobbles only at its foot (%d)" % short.size())
	panel.queue_free()
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
## The card that stands beside a hovered piece: it finds the square under the cursor without the
## square taking the mouse, keeps quiet about the open one and about one scrolled out of its box.
func _test_item_card() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var sword := Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng)
	var box := ScrollContainer.new()
	box.position = Vector2(100, 100)
	box.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	root.add_child(box)
	var column := VBoxContainer.new()
	box.add_child(column)
	var seen := ItemSlot.make(sword)
	var below := ItemSlot.make(sword)
	column.add_child(seen)
	column.add_child(below)
	var open := ItemSlot.make(sword, true)
	open.position = Vector2(300, 100)
	open.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	root.add_child(open)
	var card := ItemCard.new(2.0)
	root.add_child(card)
	await process_frame
	await process_frame
	_check(seen.mouse_filter == Control.MOUSE_FILTER_IGNORE, "a square still takes no mouse")
	var raised := Item.from_dict(sword.to_dict())
	raised.plus = 2
	var marked := ItemSlot.make(raised)
	_check(not seen.get_children().any(func(n: Node) -> bool: return n is Label)
			and (marked.get_child(marked.get_child_count() - 1) as Label).text == "+2",
			"a piece with a plus wears it on its corner, one without wears nothing")
	marked.free()
	_check(card.slot_at(Vector2(110, 110)) == seen, "the square under the cursor is found")
	_check(card.slot_at(below.get_global_rect().get_center()) == null,
			"one scrolled out of its box is not")
	_check(card.slot_at(Vector2(310, 110)) == open, "the open piece has a card too: nothing else says what it is")
	_check(card.slot_at(Vector2(5, 5)) == null, "and bare window is nothing")
	_check(card.hovered(Vector2(110, 110), false) == seen, "a hovered square gets its card")
	_check(card.hovered(Vector2(110, 110), true) == null, "a press puts the card away")
	_check(card.hovered(Vector2(110, 110), false) == null, "and letting go does not bring it back")
	_check(card.hovered(Vector2(112, 112), false) == null, "nor does moving about on the same piece")
	_check(card.hovered(Vector2(5, 5), false) == null and card.hovered(Vector2(110, 110), false) == seen,
			"until the cursor has been somewhere else")
	_check(card.theme_type_variation == "TextPanel" and card.mouse_filter == Control.MOUSE_FILTER_IGNORE,
			"it is a cream panel that never takes a press")
	# The second card, under Alt: what is worn where the hovered piece would go.
	_check(card.worn_for(sword) == null, "nothing to hold a piece against with no equipment")
	card.equipment = Equipment.new()
	_check(card.worn_for(sword) == null, "or with nothing on")
	_check(card.bare_for(sword), "which Alt says in so many words, rather than doing nothing")
	_check(card.bare_text(sword) == "Nothing is equipped in the weapon slot", "naming the socket it means")
	var other := Item.rolled("Wooden Sword", ItemRarity.Rarity.COMMON, rng)
	card.equipment.worn[Equipment.Socket.WEAPON] = other
	_check(card.worn_for(sword) == other, "a worn sword is what a hovered sword is held against")
	_check(card.worn_for(other) == null, "and the worn piece is not held against itself")
	_check(not card.bare_for(sword) and not card.bare_for(other),
			"and a taken socket, or the worn piece itself, is not called bare")
	# The keys at the card's foot: Alt while the card can answer it, and whatever the square names.
	for key: String in ItemCard.KEY_ICONS:
		_check(ResourceLoader.exists(ItemCard.KEY_ICONS[key]), "the %s key is cut" % key)
	var row := ItemCard.key_row({"alt": "compare", "shift": "equip"})
	_check(row.get_child_count() == 2 and row.get_child(0).get_child(0) is TextureRect
			and (row.get_child(0).get_child(1) as Label).text == "compare"
			and (row.get_child(1).get_child(1) as Label).text == "equip",
			"a key row is a picture and a word a key, each pair a box that wraps whole")
	_check((row.get_child(0).get_child(0) as TextureRect).texture.get_size() == Vector2(18, 12),
			"the picture at the key's own size")
	_check(row.custom_minimum_size.x == ItemCard.WIDTH, "wrapping inside the card")
	seen.set_meta(ItemCard.KEYS, {"ctrl": "discard"})
	_check(card.hints_for(seen, false) == {"alt": "compare", "ctrl": "discard"},
			"over a bag square the foot names Alt and the square's own key")
	_check(card.hints_for(seen, true) == {"ctrl": "discard"},
			"held, Alt is answered by the second card and leaves the foot")
	var worn_square := ItemSlot.make(other)
	_check(card.hints_for(worn_square, false) == {}, "the worn piece itself has no Alt to offer")
	worn_square.free()
	row.free()
	for node: Node in [box, open, card]:
		node.queue_free()
	return true


func _test_orb_tray() -> bool:
	var cols: int = BagPage.ORB_COLS
	var gap: int = BagPage.ORB_GAP
	var width: int = BagPage.WIDTH
	var assembled := cols * OrbSlot.SIDE + (cols - 1) * gap
	_check(assembled <= width and width - assembled < cols - 1,
			"six orbs and their gaps come to %d, not the grid's %d" % [assembled, width])
	_check(cols == OrbTable.ORBS.size(),
			"the tray has a square for each of the %d orbs" % OrbTable.ORBS.size())
	_check(gap > 0, "the squares do not touch")
	_check(OrbSlot.ICON * 2 == ItemSlot.ICON,
			"an orb is drawn at exactly half the size it is cut at, so its pixels stay square")
	_check(OrbSlot.SIDE > OrbSlot.ICON, "an orb square has a gutter round its icon")
	# Every orb builds into a live square, and the three states are three different pictures. That
	# last part is the whole of what the tray communicates, and it is the one thing a table of names
	# cannot tell us: an orb never found, one held but useless here, and one ready to spend have to
	# be told apart at a glance in a row of six.
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


## The nameplate's health bar, held the way the orb tray and the pip bar are: it is assembled from
## generated parts against constants written down before anything is laid out, so what can go wrong
## is arithmetic rather than appearance. Two things matter beyond the parts fitting together.
##
## The trough has to be the same length in all three tiers, because the fill is a share of it: if a
## boss's channel were shorter, half a bar would mean a different number of hit points depending on
## what walked in. And the ornament has to actually grow, which is the whole promise of the elite and
## boss frames and the one part of "more intricate" that can be stated as a number.
func _test_health_bar() -> bool:
	var tiers: Array = [EnemyRoster.Tier.COMMON, EnemyRoster.Tier.ELITE, EnemyRoster.Tier.BOSS]
	var caps: Array[int] = []
	var troughs := {}
	for tier: EnemyRoster.Tier in tiers:
		var cap_l: Texture2D = HealthBar.CAP_L[tier]
		var cap_r: Texture2D = HealthBar.CAP_R[tier]
		var track: Texture2D = HealthBar.TRACK[tier]
		caps.append(int(cap_l.get_width()))
		# Every part is one height, or the row they are butted into would step.
		for part: Texture2D in [cap_l, cap_r, track]:
			_check(part.get_height() == HealthBar.HEIGHT,
					"a tier %d part is %d tall, not HEIGHT" % [tier, part.get_height()])
		_check(cap_l.get_width() == cap_r.get_width(), "tier %d's two caps differ in width" % tier)
		_check(track.get_width() == 4, "tier %d's track is not the 4 px the trough maths assumes" % tier)
		# A cap's last column is a channel column, which is the one at each end.
		troughs[2 + HealthBar.SEGMENTS * track.get_width()] = true
		_check(HealthBar.width_of(tier)
				== (cap_l.get_width() + HealthBar.SEGMENTS * track.get_width() + cap_r.get_width())
				* HealthBar.PIXEL, "tier %d's width_of agrees with its parts" % tier)
	_check(troughs.size() == 1 and troughs.has(HealthBar.TROUGH),
			"every tier leaves TROUGH (%d) px of channel: found %s" % [HealthBar.TROUGH, troughs.keys()])
	_check(caps == [3, 9, 13] and caps[0] < caps[1] and caps[1] < caps[2],
			"the ornament grows common to elite to boss: caps are %s" % [caps])
	_check(HealthBar.CHANNEL_TOP + HealthBar.CHANNEL_HEIGHT < HealthBar.HEIGHT,
			"the channel leaves a rim under it as well as over it")

	# And a live bar: the pieces are laid out at the size they are drawn, the fill sits on the
	# channel, and it never says nothing while something is still standing.
	var bar := HealthBar.new()
	bar.show_health(EnemyRoster.Tier.COMMON, 1.0)
	var common_width := bar.custom_minimum_size.x
	_check(common_width == HealthBar.width_of(EnemyRoster.Tier.COMMON),
			"a common bar measures its own width")
	for part: TextureRect in ([bar._cap_l, bar._cap_r] as Array[TextureRect]) + bar._tracks:
		_check(part.custom_minimum_size == part.texture.get_size() * HealthBar.PIXEL,
				"every piece is laid out at PIXEL, not scaled after the fact")
	_check(bar._fill.size == Vector2(HealthBar.TROUGH * HealthBar.PIXEL,
			HealthBar.CHANNEL_HEIGHT * HealthBar.PIXEL), "a full bar fills the whole channel")
	_check(bar._fill.position.y == HealthBar.CHANNEL_TOP * HealthBar.PIXEL,
			"the fill sits on the channel rather than over the rim")
	bar.show_health(EnemyRoster.Tier.COMMON, 0.0)
	_check(bar._fill.size.x == 0.0, "an empty bar shows no red at all")
	bar.show_health(EnemyRoster.Tier.COMMON, 0.001)
	_check(bar._fill.size.x == HealthBar.PIXEL,
			"an enemy on its last hit point still shows a sliver")
	# Changing tier moves where the channel starts but not how long it is, and widens the bar.
	bar.show_health(EnemyRoster.Tier.BOSS, 1.0)
	_check(bar.custom_minimum_size.x > common_width, "a boss's bar is wider than a common's")
	_check(bar._fill.size.x == HealthBar.TROUGH * HealthBar.PIXEL,
			"a boss's full bar is exactly as much red as a common's")
	_check(bar._fill.position.x
			== (HealthBar.CAP_L[EnemyRoster.Tier.BOSS].get_width() - 1) * HealthBar.PIXEL,
			"the fill moved in behind the boss's ornament")
	bar.free()
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


## The character panel: every bar lies inside the frame, the portrait inside it too, and the XP bar
## empties by whole sprite pixels, never to nothing while there is anything to show.
func _test_character_panel() -> bool:
	var frame := CharacterPanel.FRAME.get_size()
	var portrait := CharacterPanel.PORTRAIT.get_size()
	_check(Vector2(CharacterPanel.PORTRAIT_AT) + portrait <= frame, "the portrait fits in the frame")
	for bar: String in CharacterPanel.BARS:
		var texture: Texture2D = load(CharacterPanel.ROOT + "ui_char_bar_%s.png" % bar)
		_check(texture != null, "the %s bar exists" % bar)
		var end := Vector2(CharacterPanel.BARS[bar]) + texture.get_size()
		_check(end.x <= frame.x and end.y <= frame.y, "the %s bar lies inside the frame" % bar)
	var gem: Texture2D = load("res://Assets/UI/xp_gem.png")
	_check(gem != null and gem.get_size() == Vector2(6, 6), "the gem is the 6 px cut")

	var panel := CharacterPanel.new()
	root.add_child(panel)
	var full: int = roundi(load(CharacterPanel.ROOT + "ui_char_bar_xp.png").get_width())
	_check(panel.shown_pixels("xp") == 0, "no experience shows no bar")
	_check(panel.shown_pixels("hp") == roundi(load(CharacterPanel.ROOT + "ui_char_bar_hp.png").get_width()),
			"health stands full")
	# A level deep enough that one point is far under half a pixel, which would round to nothing.
	panel.set_state(10, 1)
	_check(panel.shown_pixels("xp") == 1, "one point still shows one pixel")
	panel.set_state(1, PlayerLevel.xp_to_next(1) / 2)
	_check(absi(panel.shown_pixels("xp") - full / 2) <= 1, "half shows half: %d of %d"
			% [panel.shown_pixels("xp"), full])
	_check(panel.absorb(PlayerLevel.xp_to_next(1)) == 1 and panel.level == 2, "absorbing a level levels up")
	_check(panel.size.y > frame.y * CharacterPanel.PIXEL, "the name line stands over the frame")
	_check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "the panel never takes the mouse")
	panel.queue_free()
	return true


## Every live button that joins the tree points; one that chose a cursor keeps it, a dead one keeps
## the arrow, and a tile for every shape is there to be drawn.
func _test_cursors() -> bool:
	Cursors.install(self, 2)
	for shape: int in Cursors.SHAPES:
		_check(ResourceLoader.exists(Cursors.TILE % Cursors.SHAPES[shape][0]), "shape %d has its tile" % shape)
	var plain := Button.new()
	var smith := Button.new()
	Cursors.wear(smith, Cursors.HAMMER)
	var dead := Button.new()
	dead.disabled = true
	for button: Button in [plain, smith, dead]:
		root.add_child(button)
	_check(plain.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "a button gets the hand")
	_check(smith.mouse_default_cursor_shape == Control.CURSOR_BUSY, "a chosen cursor is kept")
	_check(dead.mouse_default_cursor_shape == Control.CURSOR_ARROW, "a dead button keeps the arrow")
	for button: Button in [plain, smith, dead]:
		button.queue_free()
	# A press tilts the picture about the tile's bottom right corner; the hotspot keeps its place.
	var pair: Array = Cursors._drawn[Cursors.HAND]
	var pad: Vector2 = (pair[2].get_size() - pair[0].get_size()) / 2.0
	_check(pair[3] == pair[1] + pad, "the tilted hand clicks where the straight one does")
	_check(pair[2].get_image().get_used_rect().size != pair[0].get_image().get_used_rect().size, "and it is turned")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	Cursors.twitch(self, press)
	_check(Cursors._twitched == Input.get_current_cursor_shape(), "a press twitches the cursor under it")
	Cursors.put_away()
	_check(Cursors._twitched == -1, "and putting the cursors away forgets it")
	return true


## Whose words the tip card writes: Godot's own rule, since it stands in for Godot's tooltip.
func _test_tip_card() -> bool:
	var row := HBoxContainer.new()
	row.tooltip_text = "the row"
	var plain := Control.new()
	plain.mouse_filter = Control.MOUSE_FILTER_PASS
	var named := Button.new()
	named.tooltip_text = "the button"
	var silent := Button.new()
	for child: Control in [plain, named, silent]:
		row.add_child(child)
	root.add_child(row)
	_check(TipCard.text_of(named, Vector2.ZERO) == "the button", "a Control's own tooltip is what is written")
	_check(TipCard.text_of(plain, Vector2.ZERO) == "the row", "one with none, that lets the mouse through, speaks for its parent")
	_check(TipCard.text_of(silent, Vector2.ZERO) == "", "and one that stops the mouse says nothing")
	_check(TipCard.text_of(null, Vector2.ZERO) == "", "as does bare map")
	_check(float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")) > 1000.0,
			"Godot's own tooltip is out of reach, so nothing is said twice")
	row.queue_free()

	# The character page's attribute discs say what a point does, under the cursor on the disc itself.
	var worn := Inventory.new()
	var page := CharacterPage.new(worn, 1.0)
	root.add_child(page)
	for stat: String in CharacterPage.ATTRIBUTES:
		var disc := page.find_child(stat, true, false).get_parent() as Control
		var said := TipCard.text_of(disc, disc.get_global_rect().get_center())
		_check(LootTable.STAT_LABELS[stat] in said and "Yours add" in said, "the %s disc says what it does: %s" % [stat, said])
	page.queue_free()
	return true


## The hero's portrait stands on the left of his words, everyone else's on the right, and every
## speaker has a portrait cut.
func _test_dialogue_box() -> bool:
	for speaker: String in ["fortuneteller", "blacksmith", DialogueBox.PLAYER]:
		var art: Texture2D = load(DialogueBox.PORTRAITS % speaker)
		_check(art != null and art.get_height() % DialogueBox.PORTRAIT_HEIGHT == 0
				and art.get_height() > DialogueBox.PORTRAIT_HEIGHT,
				"%s's portrait is frames of one height, stacked" % speaker)
		var box := DialogueBox.new(speaker, ["words"], art, speaker == DialogueBox.PLAYER)
		var row: HBoxContainer = box._panel.get_child(0)
		var first_is_face := row.get_child(0) is PanelContainer
		_check(first_is_face == (speaker == DialogueBox.PLAYER),
				"%s's portrait stands on the %s" % [speaker, "left" if first_is_face else "right"])
		box.free()
	return true


## A section folds and opens on a press, and one built again under the same id stays as it was left.
func _test_accordion() -> bool:
	var section := Accordion.new("Stats", "test:accordion")
	_check(section.is_open() and section.body.visible, "a section starts open")
	section.toggle()
	_check(not section.body.visible, "a press folds it")
	var again := Accordion.new("Stats", "test:accordion")
	_check(not again.is_open(), "and the page drawn again keeps it folded")
	again.toggle()
	var third := Accordion.new("Stats", "test:accordion")
	_check(third.is_open(), "until it is opened")
	for made: Node in [section, again, third]:
		made.free()
	return true


## A page with more rows than the window holds stays inside it and scrolls: the settings, whose dev
## rows run past a 648 px window's foot in a debug build.
func _test_settings_scroll() -> bool:
	var was := root.size
	root.size = Vector2i(1152, 648)
	var page := SettingsPage.new(2.0)
	root.add_child(page)
	await process_frame
	page.layout()
	await process_frame
	var scroll: ScrollContainer = page.find_children("*", "ScrollContainer", true, false)[0]
	_check(page._panel.position.y + page._panel.size.y * 2.0 <= 648.0,
			"the settings stay inside the window (%s)" % page._panel.size)
	_check(scroll.is_ancestor_of(page._rows), "and their rows are in a scroll")
	if OS.is_debug_build():
		_check(page._rows.size.y > scroll.size.y, "which has more to show than room (%s > %s)"
				% [page._rows.size.y, scroll.size.y])
	page.free()
	root.size = was
	return true


## Every window gets the largest whole scale that leaves the 576x324 budget, a window held upright is
## the narrow one, a card with no room either side stands under its anchor, a page docks against its
## room's edge (centred when narrow), and a bag with no room for the doll beside it stands it on top.
func _test_responsive() -> bool:
	_check(UITheme.pick_scale(Vector2(1152, 648)) == 2.0, "the default window is drawn at 2")
	_check(UITheme.pick_scale(Vector2(2340, 1080)) == 3.0, "a phone on its side at 3")
	_check(UITheme.pick_scale(Vector2(1080, 2340)) == 3.0, "and held upright at 3 as well")
	_check(UITheme.pick_scale(Vector2(2048, 1536)) == 3.0, "a 4:3 tablet at what its long side allows")
	_check(UITheme.pick_scale(Vector2(1024, 768)) == 1.0, "and a small window never under 1")
	_check(not UITheme.narrow(Vector2(1152, 648), 2.0) and not UITheme.narrow(Vector2(2340, 1080), 3.0),
			"a window on its side is laid out as ever")
	_check(UITheme.narrow(Vector2(1080, 2340), 3.0), "one held upright is narrow")

	var window := Vector2(360, 780)
	var anchor := Rect2(100, 100, 40, 40)
	_check(ItemCard.beside(Rect2(10, 100, 40, 40), Vector2(150, 90), window, 4) == Vector2(54, 100),
			"a card with room beside its anchor stands beside it")
	_check(ItemCard.beside(anchor, Vector2(300, 90), window, 4) == Vector2(0, 144),
			"with room on neither side, it stands under it, clamped to the window")
	_check(ItemCard.beside(Rect2(100, 700, 40, 40), Vector2(300, 90), window, 4).y == 606.0,
			"and over it where the foot is too near")

	var page := Control.new()
	root.add_child(page)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(100, 50)
	page.add_child(panel)
	var whole := root.get_visible_rect().size
	UITheme.dock(panel, Rect2(), 2.0)
	_check(panel.position == Vector2.ONE * UITheme.EDGE * 2.0
			and panel.size == Vector2(100, whole.y / 2.0 - 2 * UITheme.EDGE),
			"an empty room is the whole window: the page full height against the left edge")
	UITheme.dock(panel, Rect2(), 2.0, UITheme.Dock.RIGHT)
	_check(panel.position.x == whole.x - (100 + UITheme.EDGE) * 2.0, "or the right")
	var room := Rect2(0, 200, whole.x, 400)
	UITheme.dock(panel, room, 2.0)
	_check(panel.position.y == 200 + UITheme.EDGE * 2.0 and panel.size.y == 200 - 2 * UITheme.EDGE,
			"a room given is the height it takes")
	# At 4 the headless window is under the budget across: narrow, and centred.
	UITheme.dock(panel, Rect2(), 4.0, UITheme.Dock.RIGHT)
	_check(panel.position.x == floorf((whole.x - 100 * 4.0) / 2.0), "a narrow window centres it")
	page.queue_free()

	var bag := BagPage.new(Inventory.new(), "", 2.0)
	root.add_child(bag)
	await process_frame
	bag.area = Rect2(0, 0, 330 * 2.0, whole.y)
	bag.layout()
	var worn: Control = bag._worn_panel
	_check(worn.visible and worn.position.y + worn.size.y * 2.0 <= bag._panel.position.y,
			"a room too narrow for the doll beside the bag puts it on top")
	bag.area = Rect2()
	bag.layout()
	_check(worn.position.x > bag._panel.position.x and worn.position.y > bag._panel.position.y,
			"and the whole window has it beside the bag again")
	bag.queue_free()
	return true


## A finger has no hover: the flag says which the last press was, a tap shows a square's card rather
## than muting it, an orb's first tap reads it and only the second presses it, and a tooltip is asked
## for by a finger held down rather than a cursor at rest.
func _test_fingers() -> bool:
	var tap := InputEventMouseButton.new()
	tap.device = InputEvent.DEVICE_ID_EMULATION
	Cursors.feel(tap)
	_check(Cursors.touched, "a mouse press Godot made up from a finger is a finger's")
	var click := InputEventMouseButton.new()
	Cursors.feel(click)
	_check(not Cursors.touched, "and a real one is the mouse's again")

	var rng := RandomNumberGenerator.new()
	rng.seed = WORLD_SEED
	var square := ItemSlot.make(Item.rolled("Wooden Sword", ItemRarity.Rarity.RARE, rng))
	square.position = Vector2(100, 100)
	square.size = Vector2(ItemSlot.SIDE, ItemSlot.SIDE)
	root.add_child(square)
	var card := ItemCard.new(2.0)
	root.add_child(card)
	var orb := OrbSlot.make("Orb of Transmutation", 3, true)
	root.add_child(orb)
	await process_frame
	var presses: Array = []
	orb.pressed.connect(func(which: String) -> void: presses.append(which))
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true

	Cursors.touched = true
	_check(card.hovered(Vector2(110, 110), true) == null, "a finger down shows no card, as a press never did")
	_check(card.hovered(Vector2(110, 110), false) == square, "but lifted, the square it tapped has its card")
	orb._gui_input(down)
	_check(presses.is_empty(), "a first tap on an orb puts its card up and spends nothing")
	orb._gui_input(down)
	_check(presses.size() == 1, "the second presses it")
	var tip := TipCard.new(2.0)
	root.add_child(tip)
	var info := Control.new()
	info.set_meta(TipCard.NOW, true)
	var plain := Control.new()
	_check(tip._asking(info), "an info mark answers a finger at once")
	_check(not tip._asking(plain), "anything else waits for a finger held on it")

	Cursors.touched = false
	_check(card.hovered(Vector2(110, 110), true) == null and card.hovered(Vector2(110, 110), false) == null,
			"with the mouse, a press still puts the card away until the cursor has moved")
	_check(tip._asking(plain), "and a tooltip waits for a cursor at rest")
	info.free()
	plain.free()
	for made: Node in [square, card, orb, tip]:
		made.queue_free()
	return true
